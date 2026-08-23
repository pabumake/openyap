import Foundation
import XCTest
@testable import OpenYap

@MainActor
final class LexiconStoreTests: XCTestCase {
    func testStarterLexiconIsInstalledOnceAndRemainsUserEditable() throws {
        let persistence = try PersistenceController(inMemory: true)
        let store = LexiconStore(container: persistence.container)
        let defaults = try makeDefaults()

        store.installStarterLexiconIfNeeded(defaults: defaults)
        let initialTermCount = store.terms.count
        let initialRuleCount = store.rules.count

        XCTAssertTrue(store.terms.contains { $0.canonicalText == "OpenYap" })
        XCTAssertTrue(store.rules.contains { $0.recognizedText == "airports" && $0.replacementText == "AirPods" })

        store.installStarterLexiconIfNeeded(defaults: defaults)

        XCTAssertEqual(store.terms.count, initialTermCount)
        XCTAssertEqual(store.rules.count, initialRuleCount)

        guard let openYap = store.terms.first(where: { $0.canonicalText == "OpenYap" }) else {
            return XCTFail("Missing OpenYap starter term")
        }
        store.delete(openYap)
        store.installStarterLexiconIfNeeded(defaults: defaults)

        XCTAssertFalse(store.terms.contains { $0.canonicalText == "OpenYap" })
    }

    func testAnyLanguageTermPreventsOverlappingDuplicate() throws {
        let persistence = try PersistenceController(inMemory: true)
        let store = LexiconStore(container: persistence.container)
        try store.saveTerm(id: nil, canonicalText: "OpenYap", scope: .any)

        XCTAssertThrowsError(
            try store.saveTerm(id: nil, canonicalText: "openyap", scope: .english)
        ) { error in
            XCTAssertEqual(error as? LexiconStoreError, .duplicateTerm)
        }
    }

    func testDisabledRuleIsExcludedFromPreparationSnapshot() throws {
        let persistence = try PersistenceController(inMemory: true)
        let store = LexiconStore(container: persistence.container)
        try store.saveRule(
            id: nil,
            recognizedText: "open yap",
            replacementText: "OpenYap",
            scope: .english
        )
        guard let rule = store.rules.first else { return XCTFail("Missing saved rule") }

        store.setEnabled(rule: rule, isEnabled: false)

        XCTAssertTrue(store.ruleDefinitions(for: Locale(identifier: "en_US")).isEmpty)
    }

    private func makeDefaults() throws -> UserDefaults {
        let suite = "LexiconStoreTests.\(UUID().uuidString)"
        guard let defaults = UserDefaults(suiteName: suite) else {
            throw CocoaError(.fileReadUnknown)
        }
        defaults.removePersistentDomain(forName: suite)
        return defaults
    }
}
