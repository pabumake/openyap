import Foundation
import XCTest
@testable import OpenYap

final class LexiconProcessorTests: XCTestCase {
    func testCorrectionUsesWholeTokenBoundariesAndCanonicalCase() {
        let rule = CorrectionRuleDefinition(
            id: UUID(),
            recognizedText: "open yap",
            replacementText: "OpenYap",
            languageScope: .english
        )

        let result = LexiconProcessor.apply(
            to: "OPEN YAP works, but open yapping stays.",
            locale: Locale(identifier: "en_US"),
            terms: [],
            rules: [rule]
        )

        XCTAssertEqual(result.text, "OpenYap works, but open yapping stays.")
        XCTAssertEqual(result.replacements.first?.occurrenceCount, 1)
        XCTAssertEqual(result.replacements.first?.kind, .correction)
    }

    func testTermNormalizesCapitalization() {
        let term = LexiconTermDefinition(
            id: UUID(),
            canonicalText: "OpenYap",
            languageScope: .any
        )

        let result = LexiconProcessor.apply(
            to: "openyap and OpenYap",
            locale: Locale(identifier: "de_DE"),
            terms: [term],
            rules: []
        )

        XCTAssertEqual(result.text, "OpenYap and OpenYap")
        XCTAssertEqual(result.replacements.first?.occurrenceCount, 1)
        XCTAssertEqual(result.replacements.first?.kind, .term)
    }

    func testLanguageScopeExcludesOtherLanguage() {
        let rule = CorrectionRuleDefinition(
            id: UUID(),
            recognizedText: "flow",
            replacementText: "Flow",
            languageScope: .english
        )

        let result = LexiconProcessor.apply(
            to: "flow",
            locale: Locale(identifier: "de_DE"),
            terms: [],
            rules: [rule]
        )

        XCTAssertEqual(result.text, "flow")
        XCTAssertTrue(result.replacements.isEmpty)
    }

    func testLongestPhraseRunsFirst() {
        let short = CorrectionRuleDefinition(
            id: UUID(),
            recognizedText: "open",
            replacementText: "Closed",
            languageScope: .any
        )
        let long = CorrectionRuleDefinition(
            id: UUID(),
            recognizedText: "open yap",
            replacementText: "OpenYap",
            languageScope: .any
        )

        let result = LexiconProcessor.apply(
            to: "open yap",
            locale: Locale(identifier: "en_US"),
            terms: [],
            rules: [short, long]
        )

        XCTAssertEqual(result.text, "OpenYap")
    }
}
