@preconcurrency import AVFoundation
import Darwin
import FluidAudio
import Foundation

private let fluidAudioRevision = "c7246f4dc78d05f75cdfc5a550cd72ced0c658bf"
private let modelRevision = "7dd20fe6b1797d35f5e3307e8b1732d9a178edfe"

private struct Options {
    let audioURL: URL
    let modelDirectory: URL
    let localeIdentifier: String
    let reference: String?
    let outputURL: URL?
    let cancelAfterMilliseconds: UInt64?

    static func parse(_ arguments: [String]) throws -> Options {
        var values: [String: String] = [:]
        var index = 0
        while index < arguments.count {
            let key = arguments[index]
            guard key.hasPrefix("--"), index + 1 < arguments.count else {
                throw PrototypeError.usage("Unexpected argument: \(key)")
            }
            values[key] = arguments[index + 1]
            index += 2
        }

        guard let audioPath = values["--audio"] else {
            throw PrototypeError.usage("Missing --audio <path>")
        }
        guard let modelPath = values["--model-dir"] else {
            throw PrototypeError.usage("Missing --model-dir <path>")
        }
        let cancellation = values["--cancel-after-ms"].flatMap(UInt64.init)
        return Options(
            audioURL: URL(fileURLWithPath: audioPath),
            modelDirectory: URL(fileURLWithPath: modelPath, isDirectory: true),
            localeIdentifier: values["--locale"] ?? "en-US",
            reference: values["--reference"],
            outputURL: values["--output"].map(URL.init(fileURLWithPath:)),
            cancelAfterMilliseconds: cancellation
        )
    }
}

private enum PrototypeError: LocalizedError {
    case usage(String)
    case noPreparedEngine
    case emptyTranscript

    var errorDescription: String? {
        switch self {
        case let .usage(message):
            "\(message)\n\nUsage: ParakeetFinalOnStop --audio <path> --model-dir <path> [--locale en-US] [--reference <text>] [--output <json>] [--cancel-after-ms <milliseconds>]"
        case .noPreparedEngine:
            "The Parakeet engine was not prepared."
        case .emptyTranscript:
            "Parakeet returned no deliverable text."
        }
    }
}

private struct SessionContext: Sendable {
    let identifier: UUID
    let localeIdentifier: String
}

private final class CompletedCapture: @unchecked Sendable {
    private let lock = NSLock()
    private var storage: [Float]

    init(samples: [Float]) {
        storage = samples
    }

    func takeForFinalization() -> [Float] {
        lock.lock()
        defer { lock.unlock() }
        let samples = storage
        storage.removeAll(keepingCapacity: false)
        return samples
    }

    var retainedSampleCount: Int {
        lock.lock()
        defer { lock.unlock() }
        return storage.count
    }
}

private struct RawTranscript: Sendable {
    let sessionIdentifier: UUID
    let localeIdentifier: String
    let text: String
    let engineProcessingSeconds: TimeInterval
    let confidence: Float
    let audioDurationSeconds: TimeInterval
}

private protocol FinalOnStopSpeechEngine: Sendable {
    func prepare() async throws -> TimeInterval
    func finish(capture: CompletedCapture, session: SessionContext) async throws -> RawTranscript
    func cancel() async
}

private actor ParakeetFinalOnStopEngine: FinalOnStopSpeechEngine {
    private let modelDirectory: URL
    private var manager: AsrManager?
    private var activeTask: Task<ASRResult, Error>?
    private var activeGeneration: UUID?

    init(modelDirectory: URL) {
        self.modelDirectory = modelDirectory
    }

    func prepare() async throws -> TimeInterval {
        let started = ContinuousClock.now
        let models = try await AsrModels.load(
            from: modelDirectory,
            version: .v3,
            encoderPrecision: .int8V2
        )
        let manager = AsrManager(
            config: ASRConfig(
                tdtConfig: TdtConfig(blankId: AsrModelVersion.v3.blankId),
                encoderHiddenSize: AsrModelVersion.v3.encoderHiddenSize
            )
        )
        try await manager.loadModels(models)
        self.manager = manager
        return elapsedSeconds(since: started)
    }

    func finish(capture: CompletedCapture, session: SessionContext) async throws -> RawTranscript {
        guard let manager else { throw PrototypeError.noPreparedEngine }
        let samples = capture.takeForFinalization()
        let generation = UUID()
        activeGeneration = generation

        let task = Task {
            var decoderState = TdtDecoderState.make(decoderLayers: await manager.decoderLayerCount)
            return try await manager.transcribe(samples, decoderState: &decoderState)
        }
        activeTask = task

        defer {
            activeTask = nil
            if activeGeneration == generation {
                activeGeneration = nil
            }
        }

        let result = try await task.value
        guard activeGeneration == generation, !task.isCancelled else {
            throw CancellationError()
        }
        let text = result.text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { throw PrototypeError.emptyTranscript }

        return RawTranscript(
            sessionIdentifier: session.identifier,
            localeIdentifier: session.localeIdentifier,
            text: text,
            engineProcessingSeconds: result.processingTime,
            confidence: result.confidence,
            audioDurationSeconds: result.duration
        )
    }

    func cancel() {
        activeGeneration = nil
        activeTask?.cancel()
    }
}

private struct DownstreamOutcome: Sendable {
    let deliveryText: String
    let stateTrace: [String]
}

private actor DownstreamBoundaryProbe {
    func accept(_ transcript: RawTranscript) -> DownstreamOutcome {
        // The prototype deliberately does not duplicate the production formatter,
        // history store, or delivery agent. This probe checks that FluidAudio ends
        // at one raw-transcript value and that the existing downstream order stays
        // outside the engine adapter.
        DownstreamOutcome(
            deliveryText: transcript.text,
            stateTrace: [
                "finalizing",
                "raw transcript",
                "preparing text",
                "history entry",
                "awaiting delivery",
                "delivery attempt",
            ]
        )
    }
}

private struct PrototypeReport: Codable {
    let timestamp: Date
    let hostArchitecture: String
    let hardwareModel: String
    let physicalMemoryBytes: UInt64
    let operatingSystem: String
    let fluidAudioRevision: String
    let modelRevision: String
    let encoderPrecision: String
    let modelPackageBytes: Int64
    let audioFile: String
    let localeIdentifier: String
    let audioDurationSeconds: TimeInterval
    let modelLoadSeconds: TimeInterval
    let stopToFinalSeconds: TimeInterval?
    let stopToTerminalSeconds: TimeInterval?
    let engineProcessingSeconds: TimeInterval?
    let realTimeFactor: Float?
    let peakResidentMemoryBytes: Int64
    let confidence: Float?
    let rawTranscript: String?
    let deliveryText: String?
    let wordErrorRate: Double?
    let stateTrace: [String]
    let captureSamplesRetainedAfterRun: Int
    let cancelled: Bool
    let error: String?
    let energyMeasurement: String
}

@main
private struct ParakeetPrototype {
    static func main() async {
        do {
            let options = try Options.parse(Array(CommandLine.arguments.dropFirst()))
            let report = await run(options)
            let data = try encode(report)
            if let outputURL = options.outputURL {
                try FileManager.default.createDirectory(
                    at: outputURL.deletingLastPathComponent(),
                    withIntermediateDirectories: true
                )
                try data.write(to: outputURL, options: .atomic)
            }
            FileHandle.standardOutput.write(data)
            FileHandle.standardOutput.write(Data("\n".utf8))
            if report.error != nil { exit(2) }
        } catch {
            FileHandle.standardError.write(Data("\(error.localizedDescription)\n".utf8))
            exit(64)
        }
    }

    private static func run(_ options: Options) async -> PrototypeReport {
        let session = SessionContext(identifier: UUID(), localeIdentifier: options.localeIdentifier)
        var loadSeconds: TimeInterval = 0
        var audioDuration: TimeInterval = 0
        var stopToFinal: TimeInterval?
        var stopToTerminal: TimeInterval?
        var engineProcessing: TimeInterval?
        var confidence: Float?
        var rawText: String?
        var deliveryText: String?
        var stateTrace = ["requested", "preparing", "capturing"]
        var capture: CompletedCapture?
        var cancelled = false
        var failure: String?
        var finalizationStarted: ContinuousClock.Instant?

        do {
            let samples = try AudioConverter().resampleAudioFile(options.audioURL)
            audioDuration = Double(samples.count) / 16_000
            let completedCapture = CompletedCapture(samples: samples)
            capture = completedCapture

            let engine = ParakeetFinalOnStopEngine(modelDirectory: options.modelDirectory)
            loadSeconds = try await engine.prepare()
            stateTrace.append("finalizing")
            let stopClock = ContinuousClock.now
            finalizationStarted = stopClock
            let finishTask = Task {
                try await engine.finish(capture: completedCapture, session: session)
            }
            if let delay = options.cancelAfterMilliseconds {
                try await Task.sleep(for: .milliseconds(delay))
                await engine.cancel()
                cancelled = true
            }
            let transcript = try await finishTask.value
            stopToFinal = elapsedSeconds(since: stopClock)
            stopToTerminal = stopToFinal
            engineProcessing = transcript.engineProcessingSeconds
            confidence = transcript.confidence
            rawText = transcript.text

            let downstream = await DownstreamBoundaryProbe().accept(transcript)
            deliveryText = downstream.deliveryText
            stateTrace = Array(stateTrace.dropLast()) + downstream.stateTrace
        } catch is CancellationError {
            stopToTerminal = finalizationStarted.map { elapsedSeconds(since: $0) }
            failure = "Finalization was cancelled. No raw transcript reached text preparation, history, or delivery."
            stateTrace.append("cancelled")
        } catch {
            stopToTerminal = finalizationStarted.map { elapsedSeconds(since: $0) }
            failure = error.localizedDescription
            stateTrace.append("failed")
        }

        let retainedSamples = capture?.retainedSampleCount ?? 0
        capture = nil
        return PrototypeReport(
            timestamp: Date(),
            hostArchitecture: architecture(),
            hardwareModel: systemControlString("hw.model") ?? "unknown",
            physicalMemoryBytes: ProcessInfo.processInfo.physicalMemory,
            operatingSystem: ProcessInfo.processInfo.operatingSystemVersionString,
            fluidAudioRevision: fluidAudioRevision,
            modelRevision: modelRevision,
            encoderPrecision: "int8-v2",
            modelPackageBytes: directorySize(options.modelDirectory),
            audioFile: options.audioURL.path,
            localeIdentifier: options.localeIdentifier,
            audioDurationSeconds: audioDuration,
            modelLoadSeconds: loadSeconds,
            stopToFinalSeconds: stopToFinal,
            stopToTerminalSeconds: stopToTerminal,
            engineProcessingSeconds: engineProcessing,
            realTimeFactor: engineProcessing.flatMap { $0 > 0 ? Float(audioDuration / $0) : nil },
            peakResidentMemoryBytes: peakResidentMemoryBytes(),
            confidence: confidence,
            rawTranscript: rawText,
            deliveryText: deliveryText,
            wordErrorRate: options.reference.flatMap { reference in
                rawText.map { wordErrorRate(reference: reference, hypothesis: $0) }
            },
            stateTrace: stateTrace,
            captureSamplesRetainedAfterRun: retainedSamples,
            cancelled: cancelled,
            error: failure,
            energyMeasurement: "Not measured. macOS rejected Instruments Power Profiler; use sudo powermetrics around a representative run."
        )
    }
}

private func elapsedSeconds(since instant: ContinuousClock.Instant) -> TimeInterval {
    let duration = instant.duration(to: .now)
    return Double(duration.components.seconds) + Double(duration.components.attoseconds) / 1e18
}

private func encode(_ report: PrototypeReport) throws -> Data {
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
    encoder.dateEncodingStrategy = .iso8601
    return try encoder.encode(report)
}

private func architecture() -> String {
    var info = utsname()
    uname(&info)
    return withUnsafePointer(to: &info.machine) {
        $0.withMemoryRebound(to: CChar.self, capacity: 1) { String(cString: $0) }
    }
}

private func systemControlString(_ name: String) -> String? {
    var size = 0
    guard sysctlbyname(name, nil, &size, nil, 0) == 0, size > 0 else { return nil }
    var bytes = [CChar](repeating: 0, count: size)
    guard sysctlbyname(name, &bytes, &size, nil, 0) == 0 else { return nil }
    return String(
        decoding: bytes.prefix { $0 != 0 }.map { UInt8(bitPattern: $0) },
        as: UTF8.self
    )
}

private func peakResidentMemoryBytes() -> Int64 {
    var usage = rusage()
    guard getrusage(RUSAGE_SELF, &usage) == 0 else { return 0 }
    return Int64(usage.ru_maxrss)
}

private func directorySize(_ root: URL) -> Int64 {
    guard let enumerator = FileManager.default.enumerator(
        at: root,
        includingPropertiesForKeys: [.fileSizeKey, .isRegularFileKey]
    ) else { return 0 }
    var total: Int64 = 0
    for case let url as URL in enumerator {
        guard let values = try? url.resourceValues(forKeys: [.fileSizeKey, .isRegularFileKey]),
              values.isRegularFile == true
        else { continue }
        total += Int64(values.fileSize ?? 0)
    }
    return total
}

private func wordErrorRate(reference: String, hypothesis: String) -> Double {
    let expected = normalizedWords(reference)
    let actual = normalizedWords(hypothesis)
    guard !expected.isEmpty else { return actual.isEmpty ? 0 : 1 }

    var previous = Array(0...actual.count)
    for (row, expectedWord) in expected.enumerated() {
        var current = [row + 1]
        for (column, actualWord) in actual.enumerated() {
            let substitution = previous[column] + (expectedWord == actualWord ? 0 : 1)
            current.append(min(current[column] + 1, previous[column + 1] + 1, substitution))
        }
        previous = current
    }
    return Double(previous[actual.count]) / Double(expected.count)
}

private func normalizedWords(_ text: String) -> [String] {
    text.lowercased()
        .components(separatedBy: CharacterSet.alphanumerics.inverted)
        .filter { !$0.isEmpty }
}
