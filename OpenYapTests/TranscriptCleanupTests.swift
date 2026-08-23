import Foundation
import XCTest
@testable import OpenYap

final class TranscriptCleanupTests: XCTestCase {
    func testRemovesEnglishHesitationFillers() {
        let result = TranscriptCleanup.removeFillers(
            from: "Um, I think uh we should meet Wednesday.",
            locale: Locale(identifier: "en_US")
        )
        XCTAssertEqual(result, "I think we should meet Wednesday.")
    }

    func testDoesNotRemoveGermanPrepositionUm() {
        let result = TranscriptCleanup.removeFillers(
            from: "Wir treffen uns um drei, ähm, am Bahnhof.",
            locale: Locale(identifier: "de_DE")
        )
        XCTAssertEqual(result, "Wir treffen uns um drei, am Bahnhof.")
    }

    func testRejectsEmptyModelOutput() {
        XCTAssertFalse(TranscriptCleanup.isSafe("", comparedWith: "A useful transcript"))
    }

    func testRejectsLargeModelExpansion() {
        let expanded = String(repeating: "new words ", count: 40)
        XCTAssertFalse(TranscriptCleanup.isSafe(expanded, comparedWith: "Book lunch"))
    }

    func testRejectsMeaningChangingParaphrase() {
        XCTAssertFalse(
            TranscriptCleanup.isSafe(
                "Sure, I'd like to meet you on Wednesday at three.",
                comparedWith: "I think we should meet Tuesday, no, actually Wednesday at three."
            )
        )
    }

    func testRejectsRemovalOfSpeakerUncertainty() {
        XCTAssertFalse(
            TranscriptCleanup.isSafe(
                "We should meet Wednesday at three.",
                comparedWith: "Um, I think we should meet Tuesday, no, actually Wednesday at three."
            )
        )
    }

    func testAcceptsPunctuatedCleanup() {
        XCTAssertTrue(
            TranscriptCleanup.isSafe(
                "Let's meet Wednesday at three.",
                comparedWith: "um let's meet Wednesday at three"
            )
        )
    }
}
