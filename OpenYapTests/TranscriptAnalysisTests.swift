import Foundation
import XCTest
@testable import OpenYap

final class TranscriptAnalysisTests: XCTestCase {
    func testWordEditCountIgnoresPunctuationAndCapitalization() {
        XCTAssertEqual(
            TranscriptChangeMetrics.wordEditCount(from: "hello world", to: "Hello, world!"),
            0
        )
    }

    func testWordEditCountTreatsReplacementAsOneEdit() {
        XCTAssertEqual(
            TranscriptChangeMetrics.wordEditCount(from: "meet Tuesday", to: "Meet Wednesday."),
            1
        )
    }

    func testMetricsCountWordsAndExtendedCharacters() {
        let text = "Grüße 👋 OpenYap"
        let metrics = TranscriptMetrics.measure(text, locale: Locale(identifier: "de_DE"))

        XCTAssertEqual(metrics.wordCount, 2)
        XCTAssertEqual(metrics.characterCount, text.count)
    }

    func testDiffKeepsReplacementInReadingOrder() {
        let tokens = TranscriptDiff.tokens(from: "Tuesday", to: "Wednesday")

        XCTAssertEqual(tokens.count, 2)
        guard tokens.count == 2 else { return }
        if case .removed = tokens[0].kind {} else { XCTFail("Expected removed token first") }
        if case .inserted = tokens[1].kind {} else { XCTFail("Expected inserted token second") }
        XCTAssertEqual(tokens.map(\.text), ["Tuesday", "Wednesday"])
    }

    func testDiffPreservesWhitespaceAndPunctuation() {
        let tokens = TranscriptDiff.tokens(from: "Hello world", to: "Hello, world!")
        let rendered = tokens.map(\.text).joined()

        XCTAssertTrue(rendered.contains("Hello"))
        XCTAssertTrue(rendered.contains(","))
        XCTAssertTrue(rendered.contains("!"))
    }
}
