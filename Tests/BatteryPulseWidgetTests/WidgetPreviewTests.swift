#if os(macOS)
import AppKit
import BatteryCore
import Foundation
import SwiftUI
import Testing
import WidgetKit

@testable import BatteryPulseWidget

/// Renders the Battery widget into PNGs for review (TCI-10; the look check, plan-0.7.0 §6.1): CI
/// uploads `build/widget-previews/`, and nothing here fails on how they look.
///
/// - `sheet-*.png` are contact sheets, one per question of the look check, each picture
///   captioned; `sheet-modes-*` holds every rendering mode in light and dark.
/// - `battery-<family>-<scene>[-<mode>][-dark][-ru].png` are the single widgets: full colour, light
///   and English unless the name says otherwise. English, light and full colour keep W-3a's names,
///   so two runs can be compared file by file.
///
/// Approximate: WidgetKit's container, its margins and the desktop aren't simulated. In the
/// accented and vibrant modes the views take their own branches (no colours, the glyph in the
/// accent group), but the system's white tint, desaturation and background removal are left out,
/// so those pictures say "approx" and show a plain desktop behind the widget; Session R decides
/// those modes on the Mac. Russian uses the catalog's table that CI compiles before the tests
/// (`build/widget-strings/ru.lproj`, as scripts/build-app.sh compiles it); without it, only
/// English is drawn.
@MainActor
struct WidgetPreviewTests {
    nonisolated static let repository = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
    static let output = repository.appendingPathComponent("build/widget-previews", isDirectory: true)
    nonisolated static let strings = repository.appendingPathComponent("build/widget-strings", isDirectory: true)

    /// A widget's size on the Mac, in points [approximate].
    static func points(_ size: WidgetSize) -> CGSize {
        switch size {
        case .small: CGSize(width: 170, height: 170)
        case .medium: CGSize(width: 364, height: 170)
        case .large: CGSize(width: 364, height: 382)
        case .extraLarge, .extraLargePortrait: CGSize(width: 768, height: 382)
        }
    }

    static let families: [WidgetSize] = [.small, .medium, .large, .extraLarge]

    static func fileName(_ size: WidgetSize) -> String {
        size == .extraLarge ? "extra-large" : size.rawValue
    }

    static func title(_ size: WidgetSize) -> String {
        switch size {
        case .small: "Small"
        case .medium: "Medium"
        case .large: "Large"
        case .extraLarge, .extraLargePortrait: "Extra large"
        }
    }

    // MARK: Languages and looks

    enum Language: String, CaseIterable, Sendable {
        case english, russian

        var locale: Locale { Locale(identifier: self == .english ? "en_US" : "ru_RU") }
        var suffix: String { self == .english ? "" : "-ru" }
        var name: String { self == .english ? "English" : "Russian" }

        /// The language's compiled table as a bundle of its own, whose strings file is at its top;
        /// `nil` for English, whose keys are its text.
        var bundle: Bundle? { self == .english ? nil : WidgetPreviewTests.russian }

        /// The widget's formatter in the language, with its table's unit symbols.
        var formatter: BatteryFormatter {
            guard let bundle else { return BatteryFormatter(locale: locale) }
            func symbol(_ key: String) -> String { bundle.localizedString(forKey: key, value: nil, table: nil) }
            return BatteryFormatter(
                locale: locale,
                symbols: BatteryFormatter.UnitSymbols(
                    watts: symbol("W"), milliampHours: symbol("mAh"), volts: symbol("V"), millivolts: symbol("mV"),
                    milliamps: symbol("mA"), amps: symbol("A")))
        }
    }

    nonisolated static let russian = Bundle(url: strings.appendingPathComponent("ru.lproj", isDirectory: true))

    /// The languages drawn: Russian only when its table was compiled.
    static var languages: [Language] {
        russian == nil ? [.english] : Language.allCases
    }

    /// A rendering mode and an appearance.
    struct Look {
        var mode: WidgetRenderingMode
        var dark: Bool

        var isStandard: Bool { mode == .fullColor && !dark }

        var name: String {
            let mode =
                switch mode {
                case .accented: "-accented-approx"
                case .vibrant: "-vibrant-approx"
                default: ""
                }
            return mode + (dark ? "-dark" : "")
        }

        var title: String {
            let mode =
                switch mode {
                case .accented: "Accented (approx.)"
                case .vibrant: "Vibrant (approx.)"
                default: "Full colour"
                }
            return mode + (dark ? ", dark" : ", light")
        }

        static var standard: Look { Look(mode: .fullColor, dark: false) }
        static var all: [Look] {
            [WidgetRenderingMode.fullColor, .accented, .vibrant].flatMap { mode in
                [false, true].map { Look(mode: mode, dark: $0) }
            }
        }
    }

    // MARK: Scenes

    /// What a picture shows: a battery, a configuration and the timeline's moment.
    struct Scene: Sendable {
        var name: String
        var title: String
        var snapshot: BatterySnapshot?
        var configuration = BatteryWidgetConfiguration()
        /// The reading is 50 minutes old: the timeline's stale entry.
        var stale = false
    }

    /// The reading's time: now, as the time left counts from the moment the view draws.
    static let date = Date.now

    static func battery(_ scenario: DemoScenario, minutesAgo: Double = 0) -> BatterySnapshot? {
        scenario.battery?.reading(at: date.addingTimeInterval(-minutesAgo * 60)).snapshot
    }

    static func scene(
        _ name: String, _ title: String, _ scenario: DemoScenario?,
        _ configuration: BatteryWidgetConfiguration = BatteryWidgetConfiguration()
    ) -> Scene {
        Scene(name: name, title: title, snapshot: scenario.flatMap { battery($0) }, configuration: configuration)
    }

    static func with(_ change: (inout BatteryWidgetConfiguration) -> Void) -> BatteryWidgetConfiguration {
        var configuration = BatteryWidgetConfiguration()
        change(&configuration)
        return configuration
    }

    // Automatic: 0.6.x's widget in small and medium, which a placed widget keeps.
    static let onBattery = scene("automatic-on-battery", "On battery", .onBattery)
    static let charging = scene("automatic-charging", "Charging", .charging)
    static let low = scene("automatic-low", "Low", .lowBattery)
    static let critical = scene("automatic-critical", "Critical", .criticalBattery)
    static let full = scene("automatic-fully-charged", "Fully charged", .fullyCharged)
    static let onHold = scene("automatic-charging-on-hold", "Charging on hold", .optimizedHold)
    static let old = Scene(
        name: "automatic-reading-old", title: "Reading 50 minutes old", snapshot: battery(.onBattery, minutesAgo: 50),
        stale: true)
    // The attention row: a condition other than Normal, and heat.
    static let serviced = scene("automatic-service-recommended", "Service Recommended", .wornBattery)
    static let hot = scene("automatic-heat", "High heat", .heavyLoad)
    // The main visuals.
    static let ring = scene("visual-ring", "Ring, on battery", .onBattery, with { $0.visual = .ring })
    static let ringCharging = scene("visual-ring-charging", "Ring, charging", .charging, with { $0.visual = .ring })
    static let ringLow = scene("visual-ring-low", "Ring, low", .lowBattery, with { $0.visual = .ring })
    static let drawn = scene(
        "visual-drawn-battery", "Drawn battery, on battery", .onBattery, with { $0.visual = .drawnBattery })
    static let drawnCharging = scene(
        "visual-drawn-battery-charging", "Drawn battery, charging", .charging, with { $0.visual = .drawnBattery })
    static let drawnLow = scene(
        "visual-drawn-battery-low", "Drawn battery, low", .lowBattery, with { $0.visual = .drawnBattery })
    static let drawnFull = scene(
        "visual-drawn-battery-fully-charged", "Drawn battery, fully charged", .fullyCharged,
        with { $0.visual = .drawnBattery })
    // The main values.
    static let health = scene(
        "main-maximum-capacity", "Main value: maximum capacity", .wornBattery, with { $0.main = .maximumCapacity })
    static let temperature = scene(
        "main-temperature", "Main value: temperature", .onBattery, with { $0.main = .temperature })
    static let power = scene(
        "main-battery-power", "Main value: battery power", .charging, with { $0.main = .batteryPower })
    static let ringHealth = scene(
        "visual-ring-maximum-capacity", "Ring, maximum capacity", .wornBattery,
        with {
            $0.visual = .ring
            $0.main = .maximumCapacity
        })
    // The colours.
    static let monochromeLow = scene(
        "colors-monochrome-low", "Monochrome, low", .lowBattery, with { $0.colors = .monochrome })
    static let monochromeCritical = scene(
        "colors-monochrome-critical", "Monochrome, critical", .criticalBattery, with { $0.colors = .monochrome })
    static let monochromeServiced = scene(
        "colors-monochrome-service-recommended", "Monochrome, Service Recommended", .wornBattery,
        with { $0.colors = .monochrome })
    // The time.
    static let timeLeft = scene("time-left", "Time left, on battery", .onBattery, with { $0.time = .timeLeft })
    static let timeLeftCharging = scene(
        "time-left-charging", "Time left, charging", .charging, with { $0.time = .timeLeft })
    // Custom.
    static let customPower = scene(
        "custom-power", "Custom: battery power and power details", .charging,
        BatteryWidgetConfiguration(
            layout: .custom, main: .batteryPower, details: [.adapter, .adapterInput, .systemLoad, .voltage]))
    static let customHealth = scene(
        "custom-health-time-left", "Custom: health, time left", .onBattery,
        BatteryWidgetConfiguration(
            layout: .custom, main: .maximumCapacity,
            details: [.cycleCount, .cycleLifeUsed, .remainingCapacity, .condition, .cellBalance], time: .timeLeft))
    static let customMonochrome = scene(
        "custom-monochrome-always", "Custom: monochrome, update time always", .lowBattery,
        BatteryWidgetConfiguration(
            layout: .custom, statusLines: [.state], details: [.time, .lowPowerMode], colors: .monochrome,
            updateTime: .always))
    static let customTime = scene(
        "custom-time-detail", "Custom: the time as a detail", .charging,
        BatteryWidgetConfiguration(layout: .custom, statusLines: [.state], details: [.time]))
    static let customEvery = scene(
        "custom-every-detail", "Custom: every detail, in order", .charging,
        BatteryWidgetConfiguration(
            layout: .custom, details: BatteryWidgetField.allCases.filter { $0 != .state && $0 != .time }))
    static let customEmpty = scene(
        "custom-empty", "Custom: no details", .onBattery, BatteryWidgetConfiguration(layout: .custom))
    // The empty states.
    static let noBattery = scene("no-battery", "No battery (a desktop Mac)", nil)
    static let noInformation = withoutLevel(scene("no-information", "No battery information", .onBattery))

    static func withoutLevel(_ scene: Scene) -> Scene {
        var scene = scene
        scene.snapshot?.chargePercent = nil
        return scene
    }

    static let scenes: [Scene] = [
        onBattery, charging, low, critical, full, onHold, old, serviced, hot,
        ring, ringCharging, ringLow, ringHealth, drawn, drawnCharging, drawnLow, drawnFull,
        health, temperature, power, monochromeLow, monochromeCritical, monochromeServiced, timeLeft,
        timeLeftCharging, customPower, customHealth, customMonochrome, customTime, customEvery, customEmpty,
        noBattery, noInformation,
    ]

    /// The scenes drawn in every rendering mode and appearance.
    static let modeScenes: [Scene] = [onBattery, low, serviced, ringCharging, drawnCharging, noBattery]

    // MARK: Drawing

    /// The widget as it draws `scene` in `size`, `look` and `language`, in its place.
    static func widget(_ scene: Scene, _ size: WidgetSize, _ look: Look, _ language: Language) -> some View {
        let frame = points(size)
        let moment =
            scene.stale
            ? WidgetTimelinePlan.Entry(date: date, showsEstimate: false, isStale: true)
            : WidgetTimelinePlan.Entry(date: date, showsEstimate: true)
        let entry = BatteryEntry(snapshot: scene.snapshot, moment: moment, configuration: scene.configuration)
        return BatteryWidgetView(
            entry: entry, size: size, formatter: language.formatter, timeZone: TimeZone(identifier: "UTC") ?? .gmt
        )
        .padding(16)
        .frame(width: frame.width, height: frame.height)
        .background { backdrop(look) }
        .clipShape(.rect(cornerRadius: 22, style: .continuous))
        .environment(\.widgetRenderingMode, look.mode)
        .environment(\.colorScheme, look.dark ? .dark : .light)
        .environment(\.locale, language.locale)
        .environment(\.widgetStrings, language.bundle)
    }

    /// Full colour: the widget's container fill over the appearance's background. The other modes
    /// remove the background, so a plain desktop stands in.
    @ViewBuilder static func backdrop(_ look: Look) -> some View {
        if look.mode == .fullColor {
            Rectangle().fill(.background).overlay(Rectangle().fill(.fill.tertiary))
        } else {
            LinearGradient(
                colors: look.dark
                    ? [Color(red: 0.16, green: 0.19, blue: 0.26), Color(red: 0.08, green: 0.09, blue: 0.13)]
                    : [Color(red: 0.62, green: 0.70, blue: 0.80), Color(red: 0.46, green: 0.54, blue: 0.66)],
                startPoint: .top, endPoint: .bottom)
        }
    }

    static func write(_ view: some View, _ name: String) throws {
        try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
        let renderer = ImageRenderer(content: view)
        renderer.scale = 2
        let image = try #require(renderer.cgImage, "\(name)")
        let png = try #require(NSBitmapImageRep(cgImage: image).representation(using: .png, properties: [:]))
        try png.write(to: output.appendingPathComponent("\(name).png"))
    }

    // MARK: Single widgets

    /// Every scene in every family, in full colour and light.
    @Test(arguments: Language.allCases)
    func rendersEveryFamilyAndScene(_ language: Language) throws {
        guard Self.languages.contains(language) else { return }
        for size in Self.families {
            for scene in Self.scenes {
                try Self.write(
                    Self.widget(scene, size, .standard, language),
                    "battery-\(Self.fileName(size))-\(scene.name)\(language.suffix)")
            }
        }
    }

    /// A few scenes in every other rendering mode and appearance.
    @Test(arguments: Language.allCases)
    func rendersEveryModeAndAppearance(_ language: Language) throws {
        guard Self.languages.contains(language) else { return }
        for size in Self.families {
            for scene in Self.modeScenes {
                for look in Look.all where !look.isStandard {
                    try Self.write(
                        Self.widget(scene, size, look, language),
                        "battery-\(Self.fileName(size))-\(scene.name)\(look.name)\(language.suffix)")
                }
            }
        }
    }

    // MARK: Contact sheets

    /// One picture of a sheet, with its caption under it.
    struct Picture {
        var caption: String
        var view: AnyView
    }

    static func picture(
        _ scene: Scene, _ size: WidgetSize, _ language: Language, look: Look = .standard, caption: String? = nil
    ) -> Picture {
        Picture(
            caption: caption ?? "\(title(size)) · \(scene.title)",
            view: AnyView(widget(scene, size, look, language)))
    }

    /// `scenes` as rows, each in `sizes`.
    static func rows(_ scenes: [Scene], _ sizes: [WidgetSize], _ language: Language) -> [[Picture]] {
        scenes.map { scene in sizes.map { picture(scene, $0, language) } }
    }

    /// A sheet: a heading, then rows of captioned pictures, on a neutral grey.
    static func sheet(_ heading: String, _ rows: [[Picture]]) -> some View {
        VStack(alignment: .leading, spacing: 24) {
            Text(verbatim: heading)
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(Color(white: 0.1))
            ForEach(Array(rows.enumerated()), id: \.offset) { _, row in
                HStack(alignment: .top, spacing: 24) {
                    ForEach(Array(row.enumerated()), id: \.offset) { _, picture in
                        VStack(alignment: .leading, spacing: 8) {
                            picture.view
                            Text(verbatim: picture.caption)
                                .font(.system(size: 12))
                                .foregroundStyle(Color(white: 0.25))
                        }
                    }
                }
            }
        }
        .padding(32)
        .background(Color(white: 0.9))
        .environment(\.colorScheme, .light)
    }

    /// The sheets of the look check's questions (plan-0.7.0 §6.1), numbered as they are.
    static func lookCheckSheets(_ l: Language) -> [(name: String, heading: String, rows: [[Picture]])] {
        [
            (
                "1-small-and-medium-automatic", "1. Small and medium, Automatic (0.6.x's look)",
                rows([onBattery, charging, low, full, onHold, old], [.small, .medium], l)
            ),
            (
                "2-large-automatic", "2. Large, Automatic: the eight details",
                [
                    [onBattery, charging, low].map { picture($0, .large, l) },
                    [full, serviced, customEvery].map { picture($0, .large, l) },
                ]
            ),
            (
                "3-extra-large-two-panels", "3. Extra large: two panels, Battery and Power (declared only on a yes)",
                [
                    [onBattery, charging].map { picture($0, .extraLarge, l) },
                    [serviced, hot].map { picture($0, .extraLarge, l) },
                    [drawnCharging, customEvery].map { picture($0, .extraLarge, l) },
                ]
            ),
            (
                "4-main-visuals", "4. Main visuals: number and symbol, ring, drawn battery",
                rows([onBattery, ring, drawn, charging, ringCharging, drawnCharging], [.small, .medium, .large], l)
            ),
            (
                "4b-main-values", "4. Main values: charge, maximum capacity, temperature, battery power",
                rows([onBattery, health, ringHealth, temperature, power], [.small, .medium], l)
            ),
            (
                "5-colors", "5. Colors: level colors (the default) and monochrome",
                rows([low, monochromeLow, critical, monochromeCritical, drawnLow, ringLow], [.small, .medium], l)
            ),
            (
                "6-time", "6. Time: clock time (the default) and time left",
                rows([onBattery, timeLeft, charging, timeLeftCharging], [.small, .medium], l)
            ),
            (
                "8-attention-row", "8. The attention row: in the last row, and in small in place of the time line",
                [
                    [serviced, hot].flatMap { s in [WidgetSize.small, .medium].map { picture(s, $0, l) } },
                    [serviced, hot].map { picture($0, .large, l) } + [picture(monochromeServiced, .medium, l)],
                    [serviced, hot].map { picture($0, .extraLarge, l) },
                ]
            ),
            (
                "custom-layouts", "Custom layouts",
                rows(
                    [customPower, customHealth, customMonochrome, customTime, customEmpty], [.small, .medium, .large], l
                )
            ),
            (
                "empty-states", "Empty states",
                [
                    [noBattery, noInformation].flatMap { s in [WidgetSize.small, .medium].map { picture(s, $0, l) } },
                    [noBattery, noInformation].map { picture($0, .large, l) },
                    [picture(noBattery, .extraLarge, l)],
                ]
            ),
        ]
    }

    /// The look check's pictures, one sheet per question, and every rendering mode in light and
    /// dark per family, in each language.
    @Test(arguments: Language.allCases)
    func rendersTheLookCheckSheets(_ language: Language) throws {
        guard Self.languages.contains(language) else { return }
        for sheet in Self.lookCheckSheets(language) {
            try Self.write(
                Self.sheet("\(sheet.heading) — \(language.name)", sheet.rows),
                "sheet-\(sheet.name)\(language.suffix)")
        }
        let scenes = [Self.onBattery, Self.low, Self.serviced, Self.ringCharging, Self.drawnCharging]
        for size in Self.families {
            let rows = Look.all.map { look in
                scenes.map { Self.picture($0, size, language, look: look, caption: "\(look.title) · \($0.title)") }
            }
            let heading = "Rendering modes, \(Self.title(size).lowercased()); accented and vibrant approximate"
            try Self.write(
                Self.sheet("\(heading) — \(language.name)", rows),
                "sheet-modes-\(Self.fileName(size))\(language.suffix)")
        }
    }

    /// CI compiles the Russian table before the tests; when it's there, it must translate, or the
    /// Russian pictures would silently show English.
    @Test func theRussianTableTranslates() throws {
        guard FileManager.default.fileExists(atPath: Self.strings.path) else { return }
        let russian = try #require(Self.russian, "build/widget-strings has no ru.lproj")
        #expect(russian.localizedString(forKey: "Charging", value: nil, table: nil) != "Charging")
        #expect(russian.localizedString(forKey: "Maximum capacity", value: nil, table: nil) != "Maximum capacity")
    }
}
#endif
