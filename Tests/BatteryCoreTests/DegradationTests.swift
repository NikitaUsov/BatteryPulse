import Foundation
import Testing

@testable import BatteryCore

/// NEW-10's degradation half (RD C9): each private or moved source missing gives an explanation,
/// never a blank or a crash. The sources are MobileDevice, `IOPSCopyPowerSourcesByType(4)`, the
/// SMC's keys and the registry entries below `AppleSmartBattery`.
///
/// The first two take a feature away, and the page that has it says why: these tests read the
/// phrase from the view's source and its Russian translation from the catalog, since the views
/// only build on macOS. The other two are each other's fallback for the temperature and the
/// cells, and the registry's own entry for the live voltage and current: one missing changes no
/// reading's presence. Both missing leave the temperature and the cells out without a word, a gap
/// that needs a string of its own (C9).
@Suite struct DegradationTests {
    /// The real captures with both the SMC's keys and the registry children.
    static let completeCaptures: [Fixture] = [.m5OnBatterySMC, .m5PluggedIn10s, .m5Unplugged]

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
        let labels = BatteryReport.lines(for: s).map(\.label)
        #expect(["Temperature", "Cells", "Battery power"].allSatisfy(labels.contains))
    }

    /// Both gone, the temperature and the cells are left out, with no "0" in their place and
    /// nothing else lost. The menu bar shows its icon instead of a temperature it can't show.
    /// The pages leave the rows out without a word: E-2's gap for C9, which adds the explanation.
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
        let labels = BatteryReport.lines(for: s).map(\.label)
        #expect(!labels.contains("Temperature"))
        #expect(!labels.contains("Cells"))
        #expect(labels.contains("Health"))

        let temperatureOnly = MenuBarContent(showsIcon: false, showsCharge: false, showsTemperature: true)
        let title = temperatureOnly.title(for: s, formatter: BatteryFormatter(locale: Locale(identifier: "en_US")))
        #expect(title.isEmpty)
        #expect(temperatureOnly.showsIcon(title: title))
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
