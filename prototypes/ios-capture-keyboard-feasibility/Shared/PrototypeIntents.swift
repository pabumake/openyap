import AppIntents
import Foundation

struct StartPrototypeCaptureIntent: AudioRecordingIntent {
    static let title: LocalizedStringResource = "Start OpenYap Prototype Capture"
    static let description = IntentDescription("Starts a measured OpenYap capture in the containing app.")
    static let openAppWhenRun = true

    func perform() async throws -> some IntentResult {
        let sessionID = UUID()
        try PrototypeBridge.writeCommand(
            PrototypeCommand(
                commandID: UUID(),
                sessionID: sessionID,
                action: .start,
                requestedAt: Date(),
                source: "AudioRecordingIntent"
            )
        )
        return .result()
    }
}
struct StopPrototypeCaptureIntent: LiveActivityIntent {
    static let title: LocalizedStringResource = "Stop OpenYap Prototype Capture"
    static let description = IntentDescription("Stops the matching prototype capture.")

    @Parameter(title: "Session identifier")
    var sessionID: String

    init() {
        sessionID = ""
    }

    init(sessionID: String) {
        self.sessionID = sessionID
    }

    func perform() async throws -> some IntentResult {
        guard let identifier = UUID(uuidString: sessionID) else { return .result() }
        try PrototypeBridge.writeCommand(
            PrototypeCommand(
                commandID: UUID(),
                sessionID: identifier,
                action: .stop,
                requestedAt: Date(),
                source: "Live Activity"
            )
        )
        return .result()
    }
}
