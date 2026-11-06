import Foundation
import Testing

@testable import BatteryCore

/// NEW-10's degradation half (RD C9): each private or moved source missing gives an explanation,
/// never a blank or a crash. The sources are MobileDevice, `IOPSCopyPowerSourcesByType(4)`, the
/// SMC's keys and the registry entries below `AppleSmartBattery`.
///
/// The first two take a feature away, and the page that has it says why: these tests read the
/// phrase from the view's source and its Russian translation from the catalog, since the views
/// only build on macOS. The widgets 0.7.0 and 0.7.1 added don't say why: the Accessories widget
/// shows none connected, and the iPhone & iPad widget the remembered devices' last readings, or
/// with none a cable to connect. The other two are each other's fallback for the temperature and
/// the cells, and the registry's own entry for the live voltage and current: one missing changes no
/// reading's presence. Both missing leave the temperature and the cells out without a word, on the
/// pages and in the Battery widget. The gaps without a word need strings of their own (C9).
@Suite struct DegradationTests {
    /// The real captures with both the SMC's keys and the registry children.
    static let completeCaptures: [Fixture] = [.m5OnBatterySMC, .m5PluggedIn10s, .m5Unplugged, .m5ChargeLimit]

    static let formatter = BatteryFormatter(locale: Locale(identifier: "en_US"))
    static let utc = TimeZone(identifier: "UTC") ?? .current
    static let entry = WidgetTimelinePlan.Entry(date: Fixture.timestamp, showsEstimate: false)

    static func reading(_ fixture: Fixture, without keys: [String]) throws -> BatteryReading {
        var capture = try fixtureDictionary(fixture.rawValue)
        var battery = capture[BatteryReading.CaptureKey.smartBattery]?.dictionaryValue ?? [:]
        for key in keys {
            capture[key] = nil
            battery[key] = nil
        }
        capture[BatteryReading.CaptureKey.smartBattery] = .dictionary(battery)
        return BatteryReading(rawCapture: capture, timestamp: Fixture.timestamp)
    }

    // MARK: - The SMC and the registry children

    @Test(arguments: completeCaptures)
    func withoutTheSMCTheRegistryReadsEverything(_ fixture: Fixture) throws {
        let full = try fixture.snapshot()
        let reading = try Self.reading(fixture, without: [BatteryReading.CaptureKey.smc])
        let s = reading.snapshot
        // The children have the temperature and the cells; the registry's entry the electrical
        // readings, a minute late.
        #expect(s.temperatureCelsius == full.temperatureCelsius)
        #expect(s.cellVoltagesMV == full.cellVoltagesMV)
        #expect(s.voltageMV == reading.smartBattery["Voltage"]?.intValue)
        #expect(s.amperageMA == reading.smartBattery["Amperage"]?.intValue)
        // The Charge Limit's hold is the registry's own.
        #expect(s.isAtSystemChargeLimit == full.isAtSystemChargeLimit)
        let labels = BatteryReport.lines(for: s).map(\.label)
        #expect(["Temperature", "Cells", "Battery power"].allSatisfy(labels.contains))
    }

    @Test(arguments: completeCaptures)
    func withoutTheRegistryChildrenTheSMCReadsEverything(_ fixture: Fixture) throws {
        let full = try fixture.reading()
        let s = try Self.reading(fixture, without: [RegistryChildren.childrenKey]).snapshot
        #expect(s.temperatureCelsius != nil)
        #expect(s.temperatureCelsius == SMCBattery.temperatureCelsius(in: full.smc))
        #expect(s.cellVoltagesMV.count == full.snapshot.cellVoltagesMV.count)
        #expect(s.cellVoltagesMV == SMCBattery.cellVoltagesMV(in: full.smc, packVoltageMV: s.voltageMV))
        // The top-level ChargerData repeats the charger entry's reason.
        #expect(s.isAtSystemChargeLimit == full.snapshot.isAtSystemChargeLimit)
        let labels = BatteryReport.lines(for: s).map(\.label)
        #expect(["Temperature", "Cells", "Battery power"].allSatisfy(labels.contains))
    }

    /// Both gone, the temperature and the cells are left out, with no "0" in their place and
    /// nothing else lost. The menu bar shows its icon instead of a temperature it can't show.
    /// The pages, and the Battery widget set to show them, leave the rows out without a word:
    /// E-2's gap for C9, which adds the explanation.
    @Test(arguments: completeCaptures)
    func withoutEitherTheTemperatureAndTheCellsAreLeftOut(_ fixture: Fixture) throws {
        let full = try fixture.snapshot()
        let s = try Self.reading(fixture, without: [BatteryReading.CaptureKey.smc, RegistryChildren.childrenKey])
            .snapshot
        #expect(s.temperatureCelsius == nil)
        #expect(s.cellVoltagesMV.isEmpty)
        #expect(s.cellVoltageSpreadMV == nil)
        #expect(s.chargePercent == full.chargePercent)
        #expect(s.healthPercent == full.healthPercent)
        #expect(s.cycleCount == full.cycleCount)
        #expect(s.voltageMV != nil)
        #expect(s.isAtSystemChargeLimit == full.isAtSystemChargeLimit)
        let labels = BatteryReport.lines(for: s).map(\.label)
        #expect(!labels.contains("Temperature"))
        #expect(!labels.contains("Cells"))
        #expect(labels.contains("Health"))

        let temperatureOnly = MenuBarContent(showsIcon: false, showsCharge: false, showsTemperature: true)
        let title = temperatureOnly.title(for: s, formatter: Self.formatter)
        #expect(title.isEmpty)
        #expect(temperatureOnly.showsIcon(title: title))

        for field in [BatteryWidgetField.temperature, .cellBalance] {
            #expect(WidgetRow(field, snapshot: full, time: nil, formatter: Self.formatter) != nil, "\(field)")
            #expect(WidgetRow(field, snapshot: s, time: nil, formatter: Self.formatter) == nil, "\(field)")
        }
        #expect(WidgetRow(.maximumCapacity, snapshot: s, time: nil, formatter: Self.formatter) != nil)
    }

    // MARK: - MobileDevice

    /// Without the framework, the Devices section and every remembered device's page say that
    /// this Mac can't read iPhones and iPads, and why; neither offers to try again.
    @Test func withoutMobileDeviceTheDevicesPagesSayWhy() throws {
        let phrases = try SourceScanner.file("BatteryPulseApp/App/Localized.swift").text
        let function = try #require(
            phrases.firstMatch(
                of: #/static func deviceUnavailable\(_ error: IDeviceError\) -> String \{(?<body>[\s\S]*?)\n    \}/#))
        let branch = try #require(
            String(function.output.body).firstMatch(
                of: #/case \.frameworkUnavailable:\s*String\(localized: "(?<phrase>(?:[^"\\]|\\.)+)"\)/#))
        try Self.expectTranslated(String(branch.output.phrase))

        let intro = try SourceScanner.file("BatteryPulseApp/Main/DevicesIntroView.swift").code
        #expect(intro.contains("if let unavailable = devices.unavailable"))
        #expect(intro.contains("Phrases.deviceUnavailable(unavailable)"))
        let page = try SourceScanner.file("BatteryPulseApp/Main/DeviceView.swift").code
        #expect(
            page.contains(
                #/if case \.frameworkUnavailable = unavailable \{\s*return ShownProblem\(text: Phrases\.deviceUnavailable\(unavailable\), canRetry: false\)/#
            ))
    }

    /// The iPhone & iPad widget shows what the feed holds: the remembered devices, which the app
    /// writes from `devices.json` whether or not MobileDevice loads. Without the framework, a
    /// remembered device shows its last reading and when it was read; with none remembered, the
    /// widget asks for a cable without saying why (C9's gap).
    @Test func withoutMobileDeviceTheDevicesWidgetShowsTheLastReadings() throws {
        let writer = try SourceScanner.file("BatteryPulseApp/App/WidgetFeedWriter.swift").code
        #expect(writer.contains("AppDevices.monitor.remembered"))

        let key = try #require(DeviceKey("cfa3073fbe82243a2581b4d4ce99245e"))
        let readAt = Fixture.timestamp.addingTimeInterval(-3 * 24 * 60 * 60)
        func plan(_ devices: [WidgetFeed.Device]) -> DevicesWidgetPlan {
            let feed = WidgetFeed(
                writtenAt: Fixture.timestamp, languages: ["en"], recordsHistory: true, readsDevices: true,
                devices: devices)
            return DevicesWidgetPlan.make(
                size: .medium, configuration: DevicesWidgetConfiguration(), feed: feed, entry: Self.entry,
                formatter: Self.formatter, timeZone: Self.utc)
        }
        let device = WidgetFeed.Device(key: key, name: "Phone", percent: 65, state: .discharging, readAt: readAt)
        guard case .devices(let layout) = plan([device]) else {
            Issue.record("a remembered device isn't shown")
            return
        }
        // Read three days before the entry: its charge then, and the day.
        #expect(layout.rows.map(\.charge) == ["65%"])
        #expect(layout.rows.map(\.updated) == ["Jan 12"])

        #expect(plan([]) == .empty(.noDevices))
        try Self.expectTranslated(DevicesWidgetEmptyReason.noDevices.messageKey)
    }

    // MARK: - IOPSCopyPowerSourcesByType

    /// Without the private power-source call, the Accessories page says that this macOS doesn't
    /// report accessory batteries; the popover shows none (the User Guide says so).
    @Test func withoutTheAccessoryCallTheAccessoriesPageSaysWhy() throws {
        let page = try SourceScanner.file("BatteryPulseApp/Main/AccessoriesView.swift").text
        let branch = try #require(
            page.firstMatch(
                of:
                    #/if monitor\.isAvailable == false \{\s*ContentUnavailableView\(\s*"(?<title>[^"]+)",[\s\S]*?description: Text\("(?<description>[^"]+)"\)/#
            ))
        try Self.expectTranslated(String(branch.output.title))
        try Self.expectTranslated(String(branch.output.description))
    }

    /// The Accessories widget calls the same function itself, and reads `nil` without it, which
    /// it can't tell from none connected (W-8): every size says "No accessories with batteries
    /// connected", without saying why (C9's gap).
    @Test(arguments: WidgetSize.allCases)
    func withoutTheAccessoryCallTheAccessoriesWidgetShowsNone(_ size: WidgetSize) throws {
        let plan = AccessoriesWidgetPlan.make(
            size: size, configuration: AccessoriesWidgetConfiguration(), accessories: nil, readAt: Fixture.timestamp,
            entry: Self.entry, formatter: Self.formatter, timeZone: Self.utc)
        #expect(plan == .empty(.noAccessories))
        try Self.expectTranslated(AccessoriesWidgetEmptyReason.noAccessories.messageKey)
    }

    // MARK: - The catalog

    /// Each catalog key's translated Russian text.
    static let russian: Result<[String: String], any Error> = Result {
        let url = SourceScanner.sources.deletingLastPathComponent().appendingPathComponent(
            "Resources/Localizable.xcstrings")
        let root = try JSONSerialization.jsonObject(with: Data(contentsOf: url)) as? [String: Any]
        let strings = root?["strings"] as? [String: Any] ?? [:]
        return strings.compactMapValues { entry in
            let localizations = (entry as? [String: Any])?["localizations"] as? [String: Any]
            let unit = (localizations?["ru"] as? [String: Any])?["stringUnit"] as? [String: Any]
            guard unit?["state"] as? String == "translated" else { return nil }
            return unit?["value"] as? String
        }
    }

    /// `phrase` is a catalog key with a Russian translation: never a blank, in either language.
    static func expectTranslated(_ phrase: String, sourceLocation: SourceLocation = #_sourceLocation) throws {
        #expect(!phrase.trimmingCharacters(in: .whitespaces).isEmpty, sourceLocation: sourceLocation)
        let translation = try russian.get()[phrase]
        #expect(translation?.isEmpty == false, "\(phrase)", sourceLocation: sourceLocation)
    }
}
