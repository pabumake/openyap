import Combine
import Foundation

enum ChangelogSource: Equatable, Sendable {
    case bundled
    case github

    var title: String {
        switch self {
        case .bundled: "Bundled release notes"
        case .github: "Latest from GitHub"
        }
    }
}

@MainActor
final class ChangelogStore: ObservableObject {
    typealias Fetcher = @Sendable (URL) async throws -> String

    @Published private(set) var markdown: String
    @Published private(set) var source: ChangelogSource = .bundled
    @Published private(set) var isLoading = false
    @Published private(set) var githubUnavailable = false

    let links: AppLinks
    private let fallbackMarkdown: String
    private let fetcher: Fetcher

    init(
        links: AppLinks = .current,
        fallbackMarkdown: String? = nil,
        fetcher: @escaping Fetcher = ChangelogStore.fetch
    ) {
        self.links = links
        let bundled = fallbackMarkdown ?? Self.bundledChangelog()
        self.fallbackMarkdown = bundled
        markdown = bundled
        self.fetcher = fetcher
    }

    func refresh() async {
        guard !isLoading else { return }
        isLoading = true
        defer { isLoading = false }
        do {
            let remote = try await fetcher(links.changelogURL)
            guard !remote.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                throw ChangelogError.emptyResponse
            }
            markdown = remote
            source = .github
            githubUnavailable = false
        } catch {
            markdown = fallbackMarkdown
            source = .bundled
            githubUnavailable = true
        }
    }

    private static func bundledChangelog() -> String {
        guard let url = Bundle.main.url(forResource: "CHANGELOG", withExtension: "md"),
              let text = try? String(contentsOf: url, encoding: .utf8)
        else {
            return "# Changelog\n\nRelease notes are not available in this build."
        }
        return text
    }

    private static func fetch(from url: URL) async throws -> String {
        var request = URLRequest(url: url)
        request.timeoutInterval = 10
        request.cachePolicy = .reloadRevalidatingCacheData
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse,
              (200..<300).contains(httpResponse.statusCode)
        else {
            throw ChangelogError.invalidResponse
        }
        guard let text = String(data: data, encoding: .utf8) else {
            throw ChangelogError.invalidText
        }
        return text
    }
}

private enum ChangelogError: Error {
    case emptyResponse
    case invalidResponse
    case invalidText
}
