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
}
