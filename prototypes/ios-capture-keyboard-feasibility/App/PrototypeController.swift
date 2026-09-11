import ActivityKit
import AVFAudio
import Foundation
import UIKit

@MainActor
final class PrototypeController: ObservableObject {
    @Published private(set) var snapshot: PrototypeSnapshot
    @Published private(set) var eventLog: [String] = []
    @Published private(set) var keyboardHeartbeatIsFresh = false
    @Published private(set) var scenePhase = "unknown"

    private let audioEngine = AVAudioEngine()
    private var inputTapInstalled = false
    private var pollTimer: Timer?
    private var lastHandledCommandID: UUID?
    private var activity: Activity<PrototypeActivityAttributes>?
    private var lastPeriodicWrite = Date.distantPast
    private var lastCaptureDrivenPoll = Date.distantPast

    init() {
        if let saved = try? PrototypeBridge.readSnapshot() {
            snapshot = saved
            if [.preparing, .capturing, .finalizing].contains(saved.state) {
                snapshot.state = .failed
                snapshot.liveActivityIsActive = false
                snapshot.lastEvent = "Recovered an interrupted active session after relaunch"
                snapshot.updatedAt = Date()
                try? PrototypeBridge.writeSnapshot(snapshot)
            }
        } else {
            snapshot = .idle
        }
        log("Containing app initialized")
        Task {
            await dismissAllLiveActivities(finalState: "discarded after relaunch")
        }
    }

    func startPolling() {
        guard pollTimer == nil else { return }
        pollBridge()
        pollTimer = Timer.scheduledTimer(withTimeInterval: 0.25, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.pollBridge()
            }
        }
    }

    func startFromApp() {
        let sessionID = UUID()
        Task {
            await startCapture(sessionID: sessionID, source: "Containing app")
        }
    }

    func stopFromApp() {
        guard let sessionID = snapshot.sessionID else { return }
        Task {
            await stopCapture(sessionID: sessionID, source: "Containing app")
        }
    }

    func cancelFromApp() {
        guard let sessionID = snapshot.sessionID else { return }
        Task {
            await cancelCapture(sessionID: sessionID, source: "Containing app")
        }
    }

    func copyRecoveryText() {
        guard let text = snapshot.deliveryText else { return }
        UIPasteboard.general.string = text
        snapshot.recoveryCopyWasCreated = true
        updateSnapshot(event: "Recovery copy created from containing app")
    }

    func resetPrototype() {
        guard ![.preparing, .capturing, .finalizing].contains(snapshot.state) else {
            log("Reset rejected while a session is active")
            return
        }
        try? PrototypeBridge.clear()
        lastHandledCommandID = nil
        snapshot = .idle
        eventLog.removeAll()
        snapshot.liveActivityIsActive = false
        updateSnapshot(event: "Prototype state reset")
        Task {
            await dismissAllLiveActivities(finalState: "reset")
        }
    }

    func handleOpenURL(_ url: URL) {
        log("Containing app opened from \(url.scheme ?? "unknown") URL")
        pollBridge()
    }

    func recordScenePhase(_ phase: String) {
        scenePhase = phase
        log("Containing app scene phase: \(phase)")
        updateSnapshot(event: "Scene phase changed to \(phase)", addToLog: false)
    }

    var evidenceText: String {
        let session = snapshot.sessionID?.uuidString ?? "none"
        let lines = [
            "Session: \(session)",
            "State: \(snapshot.state.rawValue)",
            String(format: "Elapsed: %.1f seconds", snapshot.elapsedSeconds),
            "Audio buffers: \(snapshot.audioBufferCount)",
            "Live Activity active: \(snapshot.liveActivityIsActive)",
            "Keyboard heartbeat fresh: \(keyboardHeartbeatIsFresh)",
            "Stale rejections: \(snapshot.staleRejectionCount)",
            "Recovery copy created: \(snapshot.recoveryCopyWasCreated)",
            "Scene phase: \(scenePhase)",
            "",
            "Events:",
        ] + eventLog
        return lines.joined(separator: "\n")
    }

    private func pollBridge() {
        refreshKeyboardPresence()

        if snapshot.state == .capturing, let startedAt = snapshot.captureStartedAt {
            snapshot.elapsedSeconds = Date().timeIntervalSince(startedAt)
            if Date().timeIntervalSince(lastPeriodicWrite) >= 1 {
                lastPeriodicWrite = Date()
                updateSnapshot(event: snapshot.lastEvent, addToLog: false)
                Task {
                    await updateLiveActivity()
                }
            }
        }

        do {
            guard let command = try PrototypeBridge.readCommand(),
                  command.commandID != lastHandledCommandID else { return }
            lastHandledCommandID = command.commandID
            handle(command)
        } catch {
            log("Bridge command read failed: \(error)")
        }
    }

    private func handle(_ command: PrototypeCommand) {
        switch command.action {
        case .start:
            guard ![.preparing, .capturing, .finalizing].contains(snapshot.state) else {
                reject(command, reason: "another session is active")
                return
            }
            Task {
                await startCapture(sessionID: command.sessionID, source: command.source)
            }
        case .stop:
            guard command.sessionID == snapshot.sessionID, snapshot.state == .capturing else {
                reject(command, reason: "Stop did not match the active capturing session")
                return
            }
            Task {
                await stopCapture(sessionID: command.sessionID, source: command.source)
            }
        case .cancel:
            guard command.sessionID == snapshot.sessionID,
                  [.preparing, .capturing, .finalizing].contains(snapshot.state) else {
                reject(command, reason: "Cancel did not match an active session")
                return
            }
            Task {
                await cancelCapture(sessionID: command.sessionID, source: command.source)
            }
        case .markDelivered:
            guard command.sessionID == snapshot.sessionID,
                  snapshot.state == .awaitingDelivery else {
                reject(command, reason: "Delivery did not match an awaiting session")
                return
            }
            snapshot.state = .delivering
            updateSnapshot(event: "Keyboard began a delivery attempt")
            snapshot.state = .delivered
            updateSnapshot(event: "Keyboard reported insertion into the host text field")
        }
    }

    private func reject(_ command: PrototypeCommand, reason: String) {
        snapshot.staleRejectionCount += 1
        updateSnapshot(
            event: "Rejected \(command.action.rawValue) from \(command.source): \(reason)"
        )
    }

    private func startCapture(sessionID: UUID, source: String) async {
        snapshot = PrototypeSnapshot(
            sessionID: sessionID,
            state: .requested,
            updatedAt: Date(),
            captureStartedAt: nil,
            elapsedSeconds: 0,
            audioBufferCount: 0,
            deliveryText: nil,
            lastEvent: "Activation received from \(source)",
            staleRejectionCount: snapshot.staleRejectionCount,
            liveActivityIsActive: false,
            recoveryCopyWasCreated: false
        )
        updateSnapshot(event: "Activation received from \(source)")
        snapshot.state = .preparing
        updateSnapshot(event: "Requesting microphone and audio session")

        let permissionGranted = await requestMicrophonePermission()
        guard permissionGranted else {
            snapshot.state = .failed
            updateSnapshot(event: "Microphone permission denied")
            return
        }

        do {
            let audioSession = AVAudioSession.sharedInstance()
            try audioSession.setCategory(.record, mode: .measurement, options: [.allowBluetoothHFP])
            try audioSession.setActive(true)

            let input = audioEngine.inputNode
            let format = input.inputFormat(forBus: 0)
            guard format.sampleRate > 0, format.channelCount > 0 else {
                throw PrototypeAudioError.inputUnavailable
            }
            input.installTap(onBus: 0, bufferSize: 1024, format: format) { [weak self] _, _ in
                Task { @MainActor in
                    self?.recordAudioBuffer()
                }
            }
            inputTapInstalled = true
            audioEngine.prepare()
            try audioEngine.start()

            snapshot.captureStartedAt = Date()
            snapshot.state = .capturing
            updateSnapshot(event: "Capture started; audio is not retained")
            await startLiveActivity(sessionID: sessionID)
        } catch {
            teardownAudio()
            snapshot.state = .failed
            updateSnapshot(event: "Capture failed: \(error.localizedDescription)")
        }
    }

    private func stopCapture(sessionID: UUID, source: String) async {
        guard snapshot.sessionID == sessionID, snapshot.state == .capturing else { return }
        snapshot.state = .finalizing
        updateSnapshot(event: "Stop accepted from \(source)")
        teardownAudio()

        let duration = snapshot.elapsedSeconds
        snapshot.deliveryText = String(
            format: "OpenYap prototype captured %.1f seconds across %d audio buffers.",
            duration,
            snapshot.audioBufferCount
        )
        snapshot.state = .awaitingDelivery
        await endLiveActivity(finalState: "awaiting delivery")

        refreshKeyboardPresence()
        if !keyboardHeartbeatIsFresh, let deliveryText = snapshot.deliveryText {
            UIPasteboard.general.string = deliveryText
            snapshot.recoveryCopyWasCreated = true
            updateSnapshot(event: "Keyboard was absent; containing app created a recovery copy")
        } else {
            updateSnapshot(event: "Delivery text is awaiting the active keyboard")
        }
    }

    private func cancelCapture(sessionID: UUID, source: String) async {
        guard snapshot.sessionID == sessionID else { return }
        teardownAudio()
        snapshot.state = .cancelled
        snapshot.deliveryText = nil
        await endLiveActivity(finalState: "cancelled")
        updateSnapshot(event: "Session cancelled from \(source)")
    }

    private func requestMicrophonePermission() async -> Bool {
        await withCheckedContinuation { continuation in
            AVAudioApplication.requestRecordPermission { granted in
                continuation.resume(returning: granted)
            }
        }
    }

    private func recordAudioBuffer() {
        guard snapshot.state == .capturing else { return }
        snapshot.audioBufferCount += 1
        if Date().timeIntervalSince(lastCaptureDrivenPoll) >= 0.25 {
            lastCaptureDrivenPoll = Date()
            pollBridge()
        }
    }

    private func teardownAudio() {
        if audioEngine.isRunning {
            audioEngine.stop()
        }
        if inputTapInstalled {
            audioEngine.inputNode.removeTap(onBus: 0)
            inputTapInstalled = false
        }
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    private func startLiveActivity(sessionID: UUID) async {
        await dismissAllLiveActivities(finalState: "replaced by a new session")
        guard ActivityAuthorizationInfo().areActivitiesEnabled else {
            updateSnapshot(event: "Live Activities are disabled in device settings")
            return
        }
        do {
            let attributes = PrototypeActivityAttributes(sessionID: sessionID.uuidString)
            let content = ActivityContent(
                state: PrototypeActivityAttributes.ContentState(
                    state: snapshot.state.rawValue,
                    elapsedSeconds: Int(snapshot.elapsedSeconds),
                    startedAt: snapshot.captureStartedAt
                ),
                staleDate: nil
            )
            activity = try Activity.request(attributes: attributes, content: content)
            snapshot.liveActivityIsActive = true
            updateSnapshot(event: "Live Activity started")
        } catch {
            updateSnapshot(event: "Live Activity failed: \(error.localizedDescription)")
        }
    }

    private func updateLiveActivity() async {
        guard let activity else { return }
        let content = ActivityContent(
            state: PrototypeActivityAttributes.ContentState(
                state: snapshot.state.rawValue,
                elapsedSeconds: Int(snapshot.elapsedSeconds),
                startedAt: snapshot.captureStartedAt
            ),
            staleDate: nil
        )
        await activity.update(content)
    }

    private func endLiveActivity(finalState: String) async {
        await dismissAllLiveActivities(finalState: finalState)
    }

    private func dismissAllLiveActivities(finalState: String) async {
        let content = ActivityContent(
            state: PrototypeActivityAttributes.ContentState(
                state: finalState,
                elapsedSeconds: Int(snapshot.elapsedSeconds),
                startedAt: nil
            ),
            staleDate: nil
        )
        for existingActivity in Activity<PrototypeActivityAttributes>.activities {
            await existingActivity.end(content, dismissalPolicy: .immediate)
        }
        activity = nil
        snapshot.liveActivityIsActive = false
    }

    private func refreshKeyboardPresence() {
        guard let presence = try? PrototypeBridge.readKeyboardPresence() else {
            keyboardHeartbeatIsFresh = false
            return
        }
        keyboardHeartbeatIsFresh = presence.isVisible && Date().timeIntervalSince(presence.updatedAt) < 2
    }

    private func updateSnapshot(event: String, addToLog: Bool = true) {
        snapshot.updatedAt = Date()
        snapshot.lastEvent = event
        if addToLog {
            log(event)
        }
        do {
            try PrototypeBridge.writeSnapshot(snapshot)
        } catch {
            log("Snapshot write failed: \(error)")
        }
    }

    private func log(_ message: String) {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss.SSS"
        let line = "\(formatter.string(from: Date()))  \(message)"
        print("[OpenYapPrototype] \(line)")
        eventLog.insert(line, at: 0)
        if eventLog.count > 80 {
            eventLog.removeLast(eventLog.count - 80)
        }
    }
}

enum PrototypeAudioError: Error {
    case inputUnavailable
}
