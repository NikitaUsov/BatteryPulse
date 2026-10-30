import Foundation
import Testing

@testable import BatteryCore

/// The widget's frozen surfaces: macOS stores placed widgets and their configuration under these
/// strings, so a release can never rename or remove one (it can only add). A change here needs a
/// reason in the commit, and before a release, D1's identifier check.
struct WidgetSurfaceTests {
    @Test func kindStrings() {
        #expect(WidgetKindID.battery.rawValue == BatteryWidgetKind.battery)
        #expect(
            WidgetKindID.allCases.map(\.rawValue) == [
                "io.github.nikitausov.BatteryPulse.battery", "io.github.nikitausov.BatteryPulse.accessories",
            ])
    }

    /// The `widget.timeline` signpost's triggers, which measurements compare by name.
    @Test func timelineSignpostTriggers() {
        #expect(WidgetKindID.allCases.map(\.signpostName.description) == ["battery", "accessories"])
    }

    @Test func sizes() {
        #expect(
            WidgetSize.allCases.map(\.rawValue) == ["small", "medium", "large", "extraLarge", "extraLargePortrait"])
    }

    @Test func choiceRawValues() {
        #expect(
            BatteryWidgetField.allCases.map(\.rawValue) == [
                "state", "time", "maximumCapacity", "condition", "cycleCount", "temperature", "adapter",
                "systemLoad", "batteryPower", "adapterInput", "lowPowerMode", "remainingCapacity", "cycleLifeUsed",
                "cellBalance", "voltage",
            ])
        #expect(
            BatteryWidgetMain.allCases.map(\.rawValue) == ["charge", "maximumCapacity", "temperature", "batteryPower"])
        #expect(BatteryWidgetVisual.allCases.map(\.rawValue) == ["symbol", "ring", "drawnBattery"])
        #expect(WidgetLayoutMode.allCases.map(\.rawValue) == ["automatic", "custom"])
        #expect(WidgetStatusLine.allCases.map(\.rawValue) == ["state", "time"])
        #expect(WidgetTimeStyle.allCases.map(\.rawValue) == ["clockTime", "timeLeft"])
        #expect(WidgetColorStyle.allCases.map(\.rawValue) == ["levelColors", "monochrome"])
        #expect(WidgetUpdateTimeStyle.allCases.map(\.rawValue) == ["whenOld", "always"])
        #expect(AccessoryWidgetMode.allCases.map(\.rawValue) == ["all", "lowest"])
    }

    /// The pages' strings, which `@SceneStorage("mainSelection")` keeps and a click names.
    @Test func pageStrings() {
        #expect(
            PageID.named.map(\.rawValue) == [
                "overview", "power", "health", "history", "developer", "demo", "devices", "accessories",
            ])
        #expect(PageID.devicePrefix == "device:")
        #expect(PageID.device(.demo).rawValue == "device:demo")
    }

    @Test func routeURLs() {
        #expect(WidgetRoute.scheme == "batterypulse")
        let pages: [PageID] = [.overview, .power, .health, .history, .devices, .accessories]
        #expect(
            pages.compactMap { WidgetRoute(page: $0)?.url.absoluteString } == [
                "batterypulse://page/overview", "batterypulse://page/power",
                "batterypulse://page/health", "batterypulse://page/history",
                "batterypulse://page/devices",
                "batterypulse://page/accessories",
            ])
        let key = DeviceKey("0123456789abcdef0123456789abcdef")
        #expect(
            key.flatMap { WidgetRoute(page: .device($0)) }?.url.absoluteString
                == "batterypulse://page/device/0123456789abcdef0123456789abcdef")
    }

    /// The manifest as it ships; a widget package that ships a name adds it here and in the type.
    @Test func manifest() throws {
        let json = """
            {"kinds": [{"kind": "io.github.nikitausov.BatteryPulse.battery", "families": ["small", "medium", "large"],
              "intent": {"type": "BatteryWidgetIntent", "parameters": [
                {"name": "layout", "values": ["automatic", "custom"]},
                {"name": "mainValue", "values": ["charge", "maximumCapacity", "temperature", "batteryPower"]},
                {"name": "mainVisual", "values": ["symbol", "ring", "drawnBattery"]},
                {"name": "statusLines", "values": ["state", "time"]},
                {"name": "details"},
                {"name": "time", "values": ["clockTime", "timeLeft"]},
                {"name": "colors", "values": ["levelColors", "monochrome"]},
                {"name": "updateTime", "values": ["whenOld", "always"]}]}}]}
            """
        #expect(try JSONDecoder().decode(WidgetIntentManifest.self, from: Data(json.utf8)) == .shipping)
    }

    /// The widget's entitlements are the sandbox alone: no App Group, no exception.
    @Test func widgetEntitlements() throws {
        let url = Self.repository.appendingPathComponent("Resources/BatteryPulseWidget.entitlements")
        let plist = try PropertyListSerialization.propertyList(from: Data(contentsOf: url), format: nil)
        let entitlements = try #require(plist as? [String: Any])
        #expect(entitlements.keys.sorted() == ["com.apple.security.app-sandbox"])
        let sandbox = try #require(entitlements["com.apple.security.app-sandbox"])
        #expect(PropertyValue(any: sandbox) == .bool(true))
    }

    /// `SidebarItem.storageKey`'s strings are `PageID`'s, so the two can't drift apart.
    @Test func sidebarStorageKeysArePageIDs() throws {
        let source = try SourceScanner.file("BatteryPulseApp/Main/MainView.swift").text
        let block = try #require(
            source.firstMatch(of: #/var storageKey: String \{(?<body>[\s\S]*?)\n    \}/#)?.output.body)
        let names = block.matches(of: #/case \.\w+: "([^"]*)"/#).map { String($0.output.1) }
        #expect(names == PageID.named.map(\.rawValue))
        #expect(block.contains("case .device(let key): Self.devicePrefix + key.rawValue"))
        let prefix = try #require(source.firstMatch(of: #/static let devicePrefix = "([^"]*)"/#)?.output.1)
        #expect(String(prefix) == PageID.devicePrefix)
    }

    static let repository = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
}
