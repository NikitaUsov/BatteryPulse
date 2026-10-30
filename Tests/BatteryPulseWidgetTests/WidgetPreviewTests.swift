#if os(macOS)
import AppKit
import BatteryCore
import Foundation
import SwiftUI
import Testing

@testable import BatteryPulseWidget

/// Renders the Battery widget's sizes into PNGs for review (TCI-10): CI uploads
/// `build/widget-previews/*.png`, and nothing here fails on how they look. WidgetKit's container,
/// its margins and its accented and vibrant modes aren't simulated, and the text is English: the
/// test bundle has no string tables, so every key shows as its English text.
@MainActor
struct WidgetPreviewTests {
    static let output = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        .appendingPathComponent("build/widget-previews", isDirectory: true)

    /// A widget's size on the Mac, in points [approximate].
    static func points(_ size: WidgetSize) -> CGSize {
        switch size {
        case .small: CGSize(width: 170, height: 170)
        case .medium: CGSize(width: 364, height: 170)
        case .large: CGSize(width: 364, height: 382)
        case .extraLarge, .extraLargePortrait: CGSize(width: 768, height: 382)
        }
    }

    /// What a preview shows: a battery and a configuration.
    struct Scene: Sendable {
        var name: String
        var snapshot: BatterySnapshot?
        var configuration = BatteryWidgetConfiguration()
    }

    static let date = Date(timeIntervalSince1970: 1_800_000_000)

    static func battery(_ scenario: DemoScenario) -> BatterySnapshot? {
        scenario.battery?.reading(at: date).snapshot
    }

    static let scenes: [Scene] = [
        // Automatic: 0.6.x's widget, which a placed widget keeps.
        Scene(name: "automatic-on-battery", snapshot: battery(.onBattery)),
        Scene(name: "automatic-charging", snapshot: battery(.charging)),
        Scene(name: "automatic-low", snapshot: battery(.lowBattery)),
        Scene(name: "automatic-fully-charged", snapshot: battery(.fullyCharged)),
        // The attention row: a condition other than Normal, and heat.
        Scene(name: "automatic-service-recommended", snapshot: battery(.wornBattery)),
        Scene(name: "automatic-heat", snapshot: battery(.heavyLoad)),
        // Custom.
        Scene(
            name: "custom-power", snapshot: battery(.charging),
            configuration: BatteryWidgetConfiguration(
                layout: .custom, main: .batteryPower, details: [.adapter, .adapterInput, .systemLoad, .voltage])),
        Scene(
            name: "custom-health-time-left", snapshot: battery(.onBattery),
            configuration: BatteryWidgetConfiguration(
                layout: .custom, main: .maximumCapacity, details: [.cycleCount, .remainingCapacity, .condition],
                time: .timeLeft)),
        Scene(
            name: "custom-monochrome-always", snapshot: battery(.lowBattery),
            configuration: BatteryWidgetConfiguration(
                layout: .custom, statusLines: [.state], details: [.time, .lowPowerMode], colors: .monochrome,
                updateTime: .always)),
        Scene(
            name: "custom-empty", snapshot: battery(.onBattery),
            configuration: BatteryWidgetConfiguration(layout: .custom)),
        // The empty state of a Mac without a battery.
        Scene(name: "no-battery", snapshot: nil),
    ]

    @Test(arguments: [WidgetSize.small, .medium])
    func renders(_ size: WidgetSize) throws {
        try FileManager.default.createDirectory(at: Self.output, withIntermediateDirectories: true)
        for scene in Self.scenes {
            let entry = BatteryEntry(
                snapshot: scene.snapshot, moment: WidgetTimelinePlan.Entry(date: Self.date, showsEstimate: true),
                configuration: scene.configuration)
            let frame = Self.points(size)
            let view = BatteryWidgetView(
                entry: entry, size: size, formatter: BatteryFormatter(locale: Locale(identifier: "en_US")),
                timeZone: TimeZone(identifier: "UTC") ?? .gmt
            )
            .padding(16)
            .frame(width: frame.width, height: frame.height)
            .background(Color(nsColor: .windowBackgroundColor))
            .environment(\.colorScheme, .light)
            let renderer = ImageRenderer(content: view)
            renderer.scale = 2
            let image = try #require(renderer.cgImage, "\(scene.name), \(size)")
            let png = try #require(NSBitmapImageRep(cgImage: image).representation(using: .png, properties: [:]))
            try png.write(to: Self.output.appendingPathComponent("battery-\(size.rawValue)-\(scene.name).png"))
        }
    }
}
#endif
