import Foundation

enum DictationState: String, Sendable {
    case idle
    case preparing
    case capturing
    case finalizing
    case preparingText
    case awaitingDelivery
    case delivering
    case delivered
    case failed

    var title: String {
        switch self {
        case .idle: "Ready"
        case .preparing: "Preparing speech model"
        case .capturing: "Listening"
        case .finalizing: "Finishing transcript"
        case .preparingText: "Cleaning up transcript"
        case .awaitingDelivery: "Ready to paste"
        case .delivering: "Pasting"
        case .delivered: "Delivered"
        case .failed: "Could not transcribe"
        }
    }
}

struct DictationSession: Identifiable, Sendable {
    let id: UUID
    let localeIdentifier: String
    let startedAt: Date
    var state: DictationState
    var captureStartedAt: Date?
    var captureEndedAt: Date?
    var isPartial: Bool
    var volatileText: String
    var finalSegments: [String]
    var deliveryText: String
    var issue: String?

    init(id: UUID = UUID(), localeIdentifier: String, startedAt: Date = .now) {
        self.id = id
        self.localeIdentifier = localeIdentifier
        self.startedAt = startedAt
        state = .preparing
        isPartial = false
        volatileText = ""
        finalSegments = []
        deliveryText = ""
    }

    var rawTranscript: String {
        finalSegments.joined(separator: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var captureDuration: TimeInterval {
        guard let captureStartedAt else { return 0 }
        return max(0, (captureEndedAt ?? .now).timeIntervalSince(captureStartedAt))
    }
}
