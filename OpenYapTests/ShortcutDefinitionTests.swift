import AppKit
import XCTest
@testable import OpenYap

final class ShortcutDefinitionTests: XCTestCase {
    func testRightOptionPressMatchesDefaultShortcut() {
        XCTAssertTrue(
            ShortcutDefinition.rightOption.matches(
                keyCode: 61,
                eventKind: .flagsChanged,
                modifiers: .option,
                isRepeat: false
            )
        )
    }

    func testRightOptionReleaseDoesNotMatch() {
        XCTAssertFalse(
            ShortcutDefinition.rightOption.matches(
                keyCode: 61,
                eventKind: .flagsChanged,
                modifiers: [],
                isRepeat: false
            )
        )
    }

    func testLeftOptionDoesNotMatchRightOption() {
        XCTAssertFalse(
            ShortcutDefinition.rightOption.matches(
                keyCode: 58,
                eventKind: .flagsChanged,
                modifiers: .option,
                isRepeat: false
            )
        )
    }

    func testExtraModifierDoesNotMatchRightOption() {
        XCTAssertFalse(
            ShortcutDefinition.rightOption.matches(
                keyCode: 61,
                eventKind: .flagsChanged,
                modifiers: [.option, .shift],
                isRepeat: false
            )
        )
    }

    func testCustomKeyCombinationMatchesKeyDown() {
        let shortcut = ShortcutDefinition(
            keyCode: 49,
            modifiersRawValue: NSEvent.ModifierFlags.command.rawValue,
            modifierOnly: false
        )
        XCTAssertTrue(
            shortcut.matches(
                keyCode: 49,
                eventKind: .keyDown,
                modifiers: .command,
                isRepeat: false
            )
        )
    }
}
