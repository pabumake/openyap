import AppKit
import Foundation

enum ShortcutEventKind: Sendable {
    case keyDown
    case flagsChanged
}

struct ShortcutDefinition: Codable, Equatable, Sendable {
    let keyCode: UInt16
    let modifiersRawValue: UInt
    let modifierOnly: Bool

    static let rightOption = ShortcutDefinition(
        keyCode: 61,
        modifiersRawValue: NSEvent.ModifierFlags.option.rawValue,
        modifierOnly: true
    )

    var modifiers: NSEvent.ModifierFlags {
        NSEvent.ModifierFlags(rawValue: modifiersRawValue)
            .intersection(.shortcutModifiers)
    }

    var displayName: String {
        if modifierOnly {
            return Self.modifierKeyNames[keyCode] ?? "Modifier \(keyCode)"
        }
        return Self.modifierSymbols(modifiers) + Self.keyName(keyCode)
    }

    func matches(_ event: NSEvent) -> Bool {
        let kind: ShortcutEventKind = event.type == .flagsChanged ? .flagsChanged : .keyDown
        return matches(
            keyCode: event.keyCode,
            eventKind: kind,
            modifiers: event.modifierFlags,
            isRepeat: event.isARepeat
        )
    }

    func matches(
        keyCode eventKeyCode: UInt16,
        eventKind: ShortcutEventKind,
        modifiers eventModifierFlags: NSEvent.ModifierFlags,
        isRepeat: Bool
    ) -> Bool {
        guard eventKeyCode == keyCode, !isRepeat else { return false }
        let eventModifiers = eventModifierFlags.intersection(.shortcutModifiers)
        if modifierOnly {
            return eventKind == .flagsChanged && eventModifiers == modifiers
        }
        return eventKind == .keyDown && eventModifiers == modifiers
    }

    static func capture(from event: NSEvent) -> ShortcutDefinition? {
        let modifiers = event.modifierFlags.intersection(.shortcutModifiers)

        if event.type == .flagsChanged,
           modifierKeyNames[event.keyCode] != nil,
           !modifiers.isEmpty {
            return ShortcutDefinition(
                keyCode: event.keyCode,
                modifiersRawValue: modifiers.rawValue,
                modifierOnly: true
            )
        }

        guard event.type == .keyDown else { return nil }
        return ShortcutDefinition(
            keyCode: event.keyCode,
            modifiersRawValue: modifiers.rawValue,
            modifierOnly: false
        )
    }

    private static let modifierKeyNames: [UInt16: String] = [
        54: "Right Command",
        55: "Left Command",
        56: "Left Shift",
        58: "Left Option",
        59: "Left Control",
        60: "Right Shift",
        61: "Right Option",
        62: "Right Control",
        63: "Fn"
    ]

    private static func modifierSymbols(_ modifiers: NSEvent.ModifierFlags) -> String {
        var value = ""
        if modifiers.contains(.control) { value += "⌃" }
        if modifiers.contains(.option) { value += "⌥" }
        if modifiers.contains(.shift) { value += "⇧" }
        if modifiers.contains(.command) { value += "⌘" }
        if modifiers.contains(.function) { value += "fn " }
        return value
    }

    private static func keyName(_ keyCode: UInt16) -> String {
        switch keyCode {
        case 36: "↩"
        case 48: "⇥"
        case 49: "Space"
        case 51: "⌫"
        case 53: "Esc"
        case 123: "←"
        case 124: "→"
        case 125: "↓"
        case 126: "↑"
        default:
            if let scalar = keyCodeToCharacter[keyCode] { scalar.uppercased() } else { "Key \(keyCode)" }
        }
    }

    private static let keyCodeToCharacter: [UInt16: String] = [
        0: "a", 1: "s", 2: "d", 3: "f", 4: "h", 5: "g", 6: "z", 7: "x",
        8: "c", 9: "v", 11: "b", 12: "q", 13: "w", 14: "e", 15: "r",
        16: "y", 17: "t", 18: "1", 19: "2", 20: "3", 21: "4", 22: "6",
        23: "5", 25: "9", 26: "7", 28: "8", 29: "0", 31: "o", 32: "u",
        34: "i", 35: "p", 37: "l", 38: "j", 40: "k", 45: "n", 46: "m"
    ]
}

private extension NSEvent.ModifierFlags {
    static let shortcutModifiers: NSEvent.ModifierFlags = [.command, .option, .control, .shift, .function]
}
