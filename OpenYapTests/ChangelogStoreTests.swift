import Foundation
import XCTest
@testable import OpenYap

@MainActor
final class ChangelogStoreTests: XCTestCase {
    private let links = AppLinks(
        repositoryURL: URL(string: "https://example.com/repository")!,
        changelogURL: URL(string: "https://example.com/CHANGELOG.md")!
    )

    func testUsesRemoteChangelogWhenFetchSucceeds() async {
        let store = ChangelogStore(links: links, fallbackMarkdown: "Bundled") { _ in
            "# Remote"
        }

        await store.refresh()

        XCTAssertEqual(store.markdown, "# Remote")
        XCTAssertEqual(store.source, .github)
        XCTAssertFalse(store.githubUnavailable)
    }

    func testFallsBackToBundledChangelogWhenFetchFails() async {
        let store = ChangelogStore(links: links, fallbackMarkdown: "# Bundled") { _ in
            throw URLError(.notConnectedToInternet)
        }

        await store.refresh()

        XCTAssertEqual(store.markdown, "# Bundled")
        XCTAssertEqual(store.source, .bundled)
        XCTAssertTrue(store.githubUnavailable)
    }
}
