import AppKit
import SwiftUI
import Testing
@testable import TimeZoneNative

@Suite("Interface rendering")
@MainActor
struct RenderingTests {
    @Test("The menu-bar panel renders at its intended size")
    func panelRenders() throws {
        let suiteName = "TimeZoneNative.RenderingTests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defaults.removePersistentDomain(forName: suiteName)
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let model = AppModel(defaults: defaults)
        let view = ContentView()
            .environmentObject(model)
            .frame(width: 300, height: 581)

        let hostingView = NSHostingView(rootView: view)
        hostingView.frame = NSRect(x: 0, y: 0, width: 300, height: 581)
        hostingView.layoutSubtreeIfNeeded()

        let bitmap = try #require(
            hostingView.bitmapImageRepForCachingDisplay(in: hostingView.bounds)
        )
        hostingView.cacheDisplay(in: hostingView.bounds, to: bitmap)

        #expect(bitmap.pixelsWide == 600)
        #expect(bitmap.pixelsHigh == 1_162)

        if let outputPath = ProcessInfo.processInfo.environment["TIMEZONE_RENDER_PREVIEW"],
           let png = bitmap.representation(using: .png, properties: [:]) {
            try png.write(to: URL(fileURLWithPath: outputPath), options: .atomic)
        }
    }
}
