import Foundation

struct AppVersionInfo: Equatable, Sendable {
    let marketingVersion: String
    let buildNumber: String

    var displayName: String {
        "Version \(marketingVersion) (\(buildNumber))"
    }

    var compactDisplayName: String {
        "v\(marketingVersion) (\(buildNumber))"
    }

    static var current: AppVersionInfo {
        from(infoDictionary: Bundle.main.infoDictionary ?? [:])
    }

    static func from(infoDictionary: [String: Any]) -> AppVersionInfo {
        AppVersionInfo(
            marketingVersion: infoDictionary["CFBundleShortVersionString"] as? String ?? "0.0.0",
            buildNumber: infoDictionary["CFBundleVersion"] as? String ?? "0"
        )
    }
}

struct AppLinks: Equatable, Sendable {
    let repositoryURL: URL
    let changelogURL: URL
    let releasesURL: URL
    let updateFeedURL: URL

    static let current = AppLinks(
        repositoryURL: URL(string: "https://github.com/pabumake/openyap")!,
        changelogURL: URL(string: "https://raw.githubusercontent.com/pabumake/openyap/main/CHANGELOG.md")!,
        releasesURL: URL(string: "https://github.com/pabumake/openyap/releases")!,
        updateFeedURL: URL(string: "https://pabumake.github.io/openyap/appcast.xml")!
    )
}
