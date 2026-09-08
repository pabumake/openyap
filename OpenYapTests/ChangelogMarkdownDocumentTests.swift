import Foundation
import XCTest
@testable import OpenYap

final class ChangelogMarkdownDocumentTests: XCTestCase {
    func testParsesCommonChangelogBlocks() {
        let document = ChangelogMarkdownDocument(markdown: """
        # Changelog

        A paragraph with **strong text**.

        - Added one
        - Added two

        3. Third

        > A note

        ```swift
        let enabled = true
        ```

        ---

        | Version | State |
        | --- | --- |
        | 1.0 | Current |
        """)

        XCTAssertEqual(document.blockKinds, [
            .heading(level: 1),
            .paragraph,
            .unorderedList,
            .orderedList(start: 3),
            .blockQuote,
            .codeBlock,
            .thematicBreak,
            .table
        ])
    }

    func testResolvesRelativeHTTPSLinks() {
        let baseURL = URL(string: "https://github.com/pabumake/openyap")!

        XCTAssertEqual(
            ChangelogMarkdownDocument.safeURL(destination: "issues/1", relativeTo: baseURL),
            URL(string: "https://github.com/pabumake/openyap/issues/1")
        )
    }

    func testRejectsUntrustedLinkSchemesAndCredentials() {
        let baseURL = URL(string: "https://github.com/pabumake/openyap/")!

        XCTAssertNil(ChangelogMarkdownDocument.safeURL(destination: "javascript:alert(1)", relativeTo: baseURL))
        XCTAssertNil(ChangelogMarkdownDocument.safeURL(destination: "http://example.com", relativeTo: baseURL))
        XCTAssertNil(ChangelogMarkdownDocument.safeURL(destination: "https://user:pass@example.com", relativeTo: baseURL))
    }
}
