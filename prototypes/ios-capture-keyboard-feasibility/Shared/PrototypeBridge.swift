import Foundation

enum PrototypeBridgeError: Error, CustomStringConvertible {
    case appGroupUnavailable

    var description: String {
        switch self {
        case .appGroupUnavailable:
            return "App Group container unavailable. Confirm provisioning and keyboard Full Access."
        }
    }
}
enum PrototypeBridge {
    static let appGroupIdentifier = "group.dev.pabu.openyap"

    private static let commandFilename = "prototype-command.json"
    private static let snapshotFilename = "prototype-snapshot.json"
    private static let presenceFilename = "prototype-keyboard-presence.json"

    static func writeCommand(_ command: PrototypeCommand) throws {
        try write(command, filename: commandFilename)
    }

    static func readCommand() throws -> PrototypeCommand? {
        try read(PrototypeCommand.self, filename: commandFilename)
    }

    static func writeSnapshot(_ snapshot: PrototypeSnapshot) throws {
        try write(snapshot, filename: snapshotFilename)
    }

    static func readSnapshot() throws -> PrototypeSnapshot? {
        try read(PrototypeSnapshot.self, filename: snapshotFilename)
    }

    static func writeKeyboardPresence(_ presence: PrototypeKeyboardPresence) throws {
        try write(presence, filename: presenceFilename)
    }

    static func readKeyboardPresence() throws -> PrototypeKeyboardPresence? {
        try read(PrototypeKeyboardPresence.self, filename: presenceFilename)
    }

    static func clear() throws {
        let container = try containerURL()
        for filename in [commandFilename, snapshotFilename, presenceFilename] {
            try? FileManager.default.removeItem(at: container.appendingPathComponent(filename))
        }
    }

    private static func containerURL() throws -> URL {
        guard let url = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: appGroupIdentifier
        ) else {
            throw PrototypeBridgeError.appGroupUnavailable
        }
        return url
    }

    private static func write<Value: Encodable>(_ value: Value, filename: String) throws {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(value)
        try data.write(to: try containerURL().appendingPathComponent(filename), options: .atomic)
    }

    private static func read<Value: Decodable>(_ type: Value.Type, filename: String) throws -> Value? {
        let url = try containerURL().appendingPathComponent(filename)
        guard FileManager.default.fileExists(atPath: url.path) else { return nil }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(type, from: Data(contentsOf: url))
    }
}
