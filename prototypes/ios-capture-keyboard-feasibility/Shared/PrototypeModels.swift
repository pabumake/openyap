import ActivityKit
import Foundation

enum PrototypeSessionState: String, Codable, Sendable {
    case idle
    case requested
    case preparing
    case capturing
    case finalizing
    case awaitingDelivery
    case delivering
    case delivered
    case cancelled
    case failed
}
enum PrototypeCommandAction: String, Codable, Sendable {
    case start
    case stop
    case cancel
    case markDelivered
}

struct PrototypeCommand: Codable, Sendable {
    let commandID: UUID
    let sessionID: UUID
    let action: PrototypeCommandAction
    let requestedAt: Date
    let source: String
}

struct PrototypeSnapshot: Codable, Sendable {
    var sessionID: UUID?
    var state: PrototypeSessionState
    var updatedAt: Date
    var captureStartedAt: Date?
    var elapsedSeconds: Double
    var audioBufferCount: Int
    var deliveryText: String?
    var lastEvent: String
    var staleRejectionCount: Int
    var liveActivityIsActive: Bool
    var recoveryCopyWasCreated: Bool

    static var idle: PrototypeSnapshot {
        PrototypeSnapshot(
            sessionID: nil,
            state: .idle,
            updatedAt: Date(),
            captureStartedAt: nil,
            elapsedSeconds: 0,
            audioBufferCount: 0,
            deliveryText: nil,
            lastEvent: "Prototype ready",
            staleRejectionCount: 0,
            liveActivityIsActive: false,
            recoveryCopyWasCreated: false
        )
    }
}

struct PrototypeKeyboardPresence: Codable, Sendable {
    let sessionID: UUID?
    let updatedAt: Date
    let isVisible: Bool
}

struct PrototypeActivityAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        var state: String
        var elapsedSeconds: Int
    }

    let sessionID: String
}
