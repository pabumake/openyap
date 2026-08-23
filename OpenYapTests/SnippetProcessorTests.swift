import Foundation
import XCTest
@testable import OpenYap

final class SnippetProcessorTests: XCTestCase {
    func testExpandsCaseInsensitiveTriggerInsideSentenceAndPreservesPunctuation() {
        let snippet = definition(trigger: "my email", expansion: "pabu@example.com")

        let result = SnippetProcessor.apply(
            to: "Send it to MY EMAIL, please.",
            locale: Locale(identifier: "en_US"),
            snippets: [snippet]
        )

        XCTAssertEqual(result.text, "Send it to pabu@example.com, please.")
        XCTAssertEqual(result.replacements.first?.kind, .snippet)
        XCTAssertEqual(result.replacements.first?.occurrenceCount, 1)
    }

    func testDoesNotMatchTriggerInsideAnotherWord() {
        let snippet = definition(trigger: "sign", expansion: "Regards")

        let result = SnippetProcessor.apply(
            to: "Please assign this.",
            locale: Locale(identifier: "en_US"),
            snippets: [snippet]
        )

        XCTAssertEqual(result.text, "Please assign this.")
        XCTAssertTrue(result.replacements.isEmpty)
    }

    func testLongestOverlappingTriggerWins() {
        let short = definition(trigger: "my", expansion: "SHORT")
        let long = definition(trigger: "my address", expansion: "LONG")

        let result = SnippetProcessor.apply(
            to: "Use my address.",
            locale: Locale(identifier: "en_US"),
            snippets: [short, long]
        )

        XCTAssertEqual(result.text, "Use LONG.")
        XCTAssertEqual(result.replacements.count, 1)
        XCTAssertEqual(result.replacements.first?.sourceID, long.id)
    }

    func testExpansionIsLiteralAndIsNotProcessedAgain() {
        let outer = definition(trigger: "my signature", expansion: "Regards,\nmy email")
        let inner = definition(trigger: "my email", expansion: "pabu@example.com")

        let result = SnippetProcessor.apply(
            to: "my signature",
            locale: Locale(identifier: "en_US"),
            snippets: [outer, inner]
        )

        XCTAssertEqual(result.text, "Regards,\nmy email")
        XCTAssertEqual(result.replacements.count, 1)
        XCTAssertEqual(result.replacements.first?.sourceID, outer.id)
    }

    func testCountsRepeatedOccurrencesAndHonorsLanguageScope() {
        let english = definition(trigger: "my link", expansion: "https://example.com", scope: .english)

        let englishResult = SnippetProcessor.apply(
            to: "my link and my link",
            locale: Locale(identifier: "en_US"),
            snippets: [english]
        )
        let germanResult = SnippetProcessor.apply(
            to: "my link",
            locale: Locale(identifier: "de_DE"),
            snippets: [english]
        )

        XCTAssertEqual(englishResult.text, "https://example.com and https://example.com")
        XCTAssertEqual(englishResult.replacements.first?.occurrenceCount, 2)
        XCTAssertEqual(germanResult.text, "my link")
        XCTAssertTrue(germanResult.replacements.isEmpty)
    }

    func testPipelineAppliesWordListBeforeSnippetExpansion() async {
        let rule = CorrectionRuleDefinition(
            id: UUID(),
            recognizedText: "mail address",
            replacementText: "my email",
            languageScope: .english
        )
        let snippet = definition(trigger: "my email", expansion: "pabu@example.com")
        let pipeline = TranscriptPreparationPipeline()

        let result = await pipeline.prepare(
            rawTranscript: "mail address",
            locale: Locale(identifier: "en_US"),
            smartFormattingEnabled: false,
            terms: [],
            rules: [rule],
            snippets: [snippet]
        )

        XCTAssertEqual(result.formattedText, "mail address")
        XCTAssertEqual(result.wordListText, "my email")
        XCTAssertEqual(result.initialDeliveryText, "pabu@example.com")
        XCTAssertEqual(result.appliedReplacements.map(\.kind), [.correction, .snippet])
    }

    private func definition(
        trigger: String,
        expansion: String,
        scope: LexiconLanguageScope = .any
    ) -> SnippetDefinition {
        SnippetDefinition(
            id: UUID(),
            triggerText: trigger,
            expansionText: expansion,
            languageScope: scope
        )
    }
}
