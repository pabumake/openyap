@preconcurrency import AVFoundation
import AudioToolbox
import Foundation
import Speech

enum SpeechEngineError: LocalizedError {
    case microphoneDenied
    case speechUnavailable
    case unsupportedLocale(String)
    case missingAudioFormat

    var errorDescription: String? {
        switch self {
        case .microphoneDenied:
            "Microphone access is off. Enable it in System Settings > Privacy & Security > Microphone."
        case .speechUnavailable:
            "Apple's on-device transcription model is unavailable on this Mac."
        case let .unsupportedLocale(identifier):
            "The speech model does not support \(identifier)."
        case .missingAudioFormat:
            "OpenYap could not configure a compatible microphone format."
        }
    }
}

actor AppleSpeechEngine {
    typealias UpdateHandler = @MainActor @Sendable (_ text: String, _ isFinal: Bool) -> Void

    private let audioEngine = AVAudioEngine()
    private var analyzer: SpeechAnalyzer?
    private var inputContinuation: AsyncStream<AnalyzerInput>.Continuation?
    private var analysisTask: Task<Void, Error>?
    private var resultTask: Task<Void, Never>?
    private let audioInputCatalog = AudioInputDeviceCatalog()

    func start(
        locale requestedLocale: Locale,
        inputSelection: AudioInputSelection,
        onUpdate: @escaping UpdateHandler
    ) async throws -> AudioInputDevice {
        guard SpeechTranscriber.isAvailable else {
            throw SpeechEngineError.speechUnavailable
        }

        let permission = await microphonePermission()
        guard permission else { throw SpeechEngineError.microphoneDenied }

        guard let locale = await SpeechTranscriber.supportedLocale(equivalentTo: requestedLocale) else {
            throw SpeechEngineError.unsupportedLocale(requestedLocale.identifier)
        }

        let transcriber = SpeechTranscriber(locale: locale, preset: .progressiveTranscription)
        if let request = try await AssetInventory.assetInstallationRequest(supporting: [transcriber]) {
            try await request.downloadAndInstall()
        }
        _ = try? await AssetInventory.reserve(locale: locale)

        let inputDevice = try audioInputCatalog.resolve(inputSelection)
        try selectInputDevice(inputDevice)

        let analyzer = SpeechAnalyzer(modules: [transcriber])
        let inputNode = audioEngine.inputNode
        let naturalFormat = inputNode.outputFormat(forBus: 0)
        guard let analysisFormat = await SpeechAnalyzer.bestAvailableAudioFormat(
            compatibleWith: [transcriber],
            considering: naturalFormat
        ) else {
            throw SpeechEngineError.missingAudioFormat
        }

        try await analyzer.prepareToAnalyze(in: analysisFormat)
        let pair = AsyncStream<AnalyzerInput>.makeStream()
        inputContinuation = pair.continuation
        self.analyzer = analyzer

        resultTask = Task {
            do {
                for try await result in transcriber.results {
                    let text = String(result.text.characters)
                    await onUpdate(text, result.isFinal)
                }
            } catch {
                // analyzeSequence reports the same failure to its caller.
            }
        }

        analysisTask = Task {
            _ = try await analyzer.analyzeSequence(pair.stream)
        }

        let converter = AVAudioConverter(from: naturalFormat, to: analysisFormat)
        let continuation = pair.continuation
        inputNode.installTap(onBus: 0, bufferSize: 2_048, format: naturalFormat) { buffer, _ in
            let converted = Self.convert(buffer, with: converter, outputFormat: analysisFormat)
            guard let converted else { return }
            continuation.yield(AnalyzerInput(buffer: converted))
        }

        audioEngine.prepare()
        try audioEngine.start()
        return inputDevice
    }

    func stop() async throws {
        audioEngine.inputNode.removeTap(onBus: 0)
        audioEngine.stop()
        inputContinuation?.finish()
        inputContinuation = nil

        try await analyzer?.finalizeAndFinishThroughEndOfInput()
        if let analysisTask {
            try await analysisTask.value
        }
        await resultTask?.value
        clearTasks()
    }

    func cancel() async {
        if audioEngine.isRunning {
            audioEngine.inputNode.removeTap(onBus: 0)
            audioEngine.stop()
        }
        inputContinuation?.finish()
        await analyzer?.cancelAndFinishNow()
        analysisTask?.cancel()
        resultTask?.cancel()
        clearTasks()
    }

    private func clearTasks() {
        analyzer = nil
        analysisTask = nil
        resultTask = nil
    }

    private func microphonePermission() async -> Bool {
        switch AVCaptureDevice.authorizationStatus(for: .audio) {
        case .authorized:
            true
        case .notDetermined:
            await AVCaptureDevice.requestAccess(for: .audio)
        default:
            false
        }
    }

    private func selectInputDevice(_ device: AudioInputDevice) throws {
        audioEngine.reset()
        guard let audioUnit = audioEngine.inputNode.audioUnit else {
            throw AudioInputDeviceError.couldNotSelectDevice(device.name)
        }
        var deviceID = device.coreAudioID
        let status = AudioUnitSetProperty(
            audioUnit,
            kAudioOutputUnitProperty_CurrentDevice,
            kAudioUnitScope_Global,
            0,
            &deviceID,
            UInt32(MemoryLayout<AudioDeviceID>.size)
        )
        guard status == noErr else {
            throw AudioInputDeviceError.couldNotSelectDevice(device.name)
        }
    }

    nonisolated private static func convert(
        _ input: AVAudioPCMBuffer,
        with converter: AVAudioConverter?,
        outputFormat: AVAudioFormat
    ) -> AVAudioPCMBuffer? {
        guard input.format != outputFormat else { return input }
        guard let converter else { return nil }

        let ratio = outputFormat.sampleRate / input.format.sampleRate
        let capacity = AVAudioFrameCount((Double(input.frameLength) * ratio).rounded(.up))
        guard let output = AVAudioPCMBuffer(pcmFormat: outputFormat, frameCapacity: capacity) else {
            return nil
        }

        let provider = ConversionInput(buffer: input)
        var conversionError: NSError?
        let status = converter.convert(to: output, error: &conversionError) { _, inputStatus in
            guard let input = provider.take() else {
                inputStatus.pointee = .noDataNow
                return nil
            }
            inputStatus.pointee = .haveData
            return input
        }
        guard status != .error, conversionError == nil else { return nil }
        return output
    }
}

private final class ConversionInput: @unchecked Sendable {
    private let lock = NSLock()
    private var buffer: AVAudioPCMBuffer?

    init(buffer: AVAudioPCMBuffer) {
        self.buffer = buffer
    }

    func take() -> AVAudioPCMBuffer? {
        lock.lock()
        defer { lock.unlock() }
        defer { buffer = nil }
        return buffer
    }
}
