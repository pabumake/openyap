import XCTest
@testable import OpenYap

final class AppVersionInfoTests: XCTestCase {
    func testReadsVersionAndBuildFromBundleDictionary() {
        let version = AppVersionInfo.from(infoDictionary: [
            "CFBundleShortVersionString": "1.2.3",
            "CFBundleVersion": "42"
        ])

        XCTAssertEqual(version.displayName, "Version 1.2.3 (42)")
        XCTAssertEqual(version.compactDisplayName, "v1.2.3 (42)")
    }

    func testUsesSafeDefaultsWhenMetadataIsMissing() {
        XCTAssertEqual(
            AppVersionInfo.from(infoDictionary: [:]),
            AppVersionInfo(marketingVersion: "0.0.0", buildNumber: "0")
        )
    }

    func testCurrentLinksUseTrustedHTTPSEndpoints() {
        XCTAssertEqual(AppLinks.current.releasesURL.host, "github.com")
        XCTAssertEqual(AppLinks.current.updateFeedURL.absoluteString, "https://pabumake.github.io/openyap/appcast.xml")
    }

    func testAppBundleRequiresSignedPromptedUpdates() {
        let info = Bundle.main.infoDictionary

        XCTAssertEqual(info?["SUFeedURL"] as? String, AppLinks.current.updateFeedURL.absoluteString)
        XCTAssertEqual(info?["SUPublicEDKey"] as? String, "n/N7vrOCRMwHYm+pVafKTu0FWnp466unUYVOOmn0cRY=")
        XCTAssertEqual(info?["SURequireSignedFeed"] as? Bool, true)
        XCTAssertEqual(info?["SUVerifyUpdateBeforeExtraction"] as? Bool, true)
        XCTAssertEqual(info?["SUAllowsAutomaticUpdates"] as? Bool, false)
        XCTAssertEqual(info?["SUEnableAutomaticChecks"] as? Bool, true)
        XCTAssertEqual(info?["SUEnableSystemProfiling"] as? Bool, false)
        XCTAssertEqual(info?["SUScheduledCheckInterval"] as? Int, 86_400)
    }
}
