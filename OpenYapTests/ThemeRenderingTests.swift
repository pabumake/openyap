import AppKit
import SwiftUI
import XCTest
@testable import OpenYap

@MainActor
final class ThemeRenderingTests: XCTestCase {
    func testThemeInjectionDoesNotPaintBehindTransparentFloatingContent() throws {
        for theme in AppTheme.allCases {
            let view = RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(theme.palette.base)
                .frame(width: 40, height: 40)
                .openYapTheme(theme)

            let representation = try XCTUnwrap(render(view, size: NSSize(width: 40, height: 40)))
            let corner = try XCTUnwrap(representation.colorAt(x: 0, y: 0))
            let center = try XCTUnwrap(representation.colorAt(x: 20, y: 20))

            XCTAssertEqual(corner.alphaComponent, 0, accuracy: 0.01, "Theme: \(theme.title)")
            XCTAssertGreaterThan(center.alphaComponent, 0.95, "Theme: \(theme.title)")
        }
    }

    private func render<V: View>(_ view: V, size: NSSize) -> NSBitmapImageRep? {
        let hostingView = NSHostingView(rootView: view)
        hostingView.frame = NSRect(origin: .zero, size: size)
        guard let representation = hostingView.bitmapImageRepForCachingDisplay(in: hostingView.bounds) else {
            return nil
        }
        hostingView.cacheDisplay(in: hostingView.bounds, to: representation)
        return representation
    }
}
