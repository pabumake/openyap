import Foundation
import XCTest
@testable import OpenYap

@MainActor
final class SnippetStoreTests: XCTestCase {
    func testSnippetCanBeSavedEditedDisabledAndDeleted() throws {
        let persistence = try PersistenceController(inMemory: true)
        let store = SnippetStore(container: persistence.container)

        try store.save(
            id: nil,
            triggerText: " my signature ",
            expansionText: "Regards,\nPabu\n",
            scope: .english
        )
        guard let snippet = store.snippets.first else { return XCTFail("Missing saved snippet") }

        XCTAssertEqual(snippet.triggerText, "my signature")
        XCTAssertEqual(snippet.expansionText, "Regards,\nPabu\n")
        XCTAssertEqual(store.definitions(for: Locale(identifier: "en_US")).count, 1)

        try store.save(
            id: snippet.id,
            triggerText: "my sign-off",
            expansionText: snippet.expansionText,
            scope: .any
        )
        guard let edited = store.snippets.first else { return XCTFail("Missing edited snippet") }
        XCTAssertEqual(edited.triggerText, "my sign-off")

        store.setEnabled(edited, isEnabled: false)
        XCTAssertTrue(store.definitions(for: Locale(identifier: "de_DE")).isEmpty)

        store.delete(edited)
        XCTAssertTrue(store.snippets.isEmpty)
    }

    func testRejectsInvalidAndOverlappingDuplicateTriggers() throws {
        let persistence = try PersistenceController(inMemory: true)
        let store = SnippetStore(container: persistence.container)

        XCTAssertThrowsError(try store.save(id: nil, triggerText: " ", expansionText: "Text", scope: .any)) {
            XCTAssertEqual($0 as? SnippetStoreError, .emptyTrigger)
        }
        XCTAssertThrowsError(try store.save(id: nil, triggerText: "trigger", expansionText: " \n", scope: .any)) {
            XCTAssertEqual($0 as? SnippetStoreError, .emptyExpansion)
        }

        try store.save(id: nil, triggerText: "My Address", expansionText: "Berlin", scope: .any)
        XCTAssertThrowsError(try store.save(id: nil, triggerText: "my address", expansionText: "Hamburg", scope: .german)) {
            XCTAssertEqual($0 as? SnippetStoreError, .duplicateTrigger)
        }
    }

    func testSearchMatchesTriggerAndExpansion() throws {
        let persistence = try PersistenceController(inMemory: true)
        let store = SnippetStore(container: persistence.container)
        try store.save(id: nil, triggerText: "my email", expansionText: "pabu@example.com", scope: .any)
        try store.save(id: nil, triggerText: "my address", expansionText: "Berlin", scope: .any)

        XCTAssertEqual(store.matching("EMAIL").map(\.triggerText), ["my email"])
        XCTAssertEqual(store.matching("berlin").map(\.triggerText), ["my address"])
    }
}
