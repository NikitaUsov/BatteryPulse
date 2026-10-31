#if os(macOS)
import AppKit
import BatteryCore
import CoreGraphics
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
/// - `sheet-charge-limit[-ru].png` is the second look's (§6.1b): the Battery widget while the
///   Charge Limit holds the charge, Automatic beside 0.6.1's widget and Custom with its detail.
/// - `battery-0.6.1-<family>-<scene>[-ru].png` are 0.6.1's widget from the same reading
///   (``Widget061View``), and `diff-0.6.1-to-0.7-<family>-<scene>[-ru].png` mark in red each pixel
///   0.7's small and medium Automatic changed, for the look check's first question; the log lists
///   the share of pixels that changed.
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
    // The Charge Limit's hold: "Charged to limit" in the state line, and Custom's "Charge limit"
    // detail.
    static let chargedToLimit = scene("automatic-charged-to-limit", "Charged to limit", .systemChargeLimit)
    static let customSystemChargeLimit = scene(
        "custom-charge-limit", "Custom: the Charge limit detail", .systemChargeLimit,
        BatteryWidgetConfiguration(
            layout: .custom, details: [.systemChargeLimit, .adapter, .systemLoad, .maximumCapacity]))
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
        onBattery, charging, low, critical, full, onHold, chargedToLimit, customSystemChargeLimit, old, serviced, hot,
        ring, ringCharging, ringLow, ringHealth, drawn, drawnCharging, drawnLow, drawnFull,
        health, temperature, power, monochromeLow, monochromeCritical, monochromeServiced, timeLeft,
        timeLeftCharging, customPower, customHealth, customMonochrome, customTime, customEvery, customEmpty,
        noBattery, noInformation,
    ]

    /// The scenes drawn in every rendering mode and appearance.
    static let modeScenes: [Scene] = [onBattery, low, serviced, ringCharging, drawnCharging, noBattery]

    // MARK: Drawing

    /// The pictures' time zone.
    static let timeZone = TimeZone(identifier: "UTC") ?? .gmt

    /// The timeline entry a scene shows.
    static func moment(_ scene: Scene) -> WidgetTimelinePlan.Entry {
        scene.stale
            ? WidgetTimelinePlan.Entry(date: date, showsEstimate: false, isStale: true)
            : WidgetTimelinePlan.Entry(date: date, showsEstimate: true)
    }

    /// The widget as it draws `scene` in `size`, `look` and `language`, in its place.
    static func widget(_ scene: Scene, _ size: WidgetSize, _ look: Look, _ language: Language) -> some View {
        let entry = BatteryEntry(snapshot: scene.snapshot, moment: moment(scene), configuration: scene.configuration)
        return framed(
            BatteryWidgetView(entry: entry, size: size, formatter: language.formatter, timeZone: timeZone), size, look,
            language)
    }

    /// 0.6.1's widget as it drew `scene`'s battery in `size`, small or medium, in full colour and
    /// light, in its place.
    static func widget061(_ scene: Scene, _ size: WidgetSize, _ language: Language) -> some View {
        framed(
            Widget061View(
                snapshot: scene.snapshot, date: date, showsEstimate: moment(scene).showsEstimate, size: size,
                locale: language.locale, timeZone: timeZone),
            size, .standard, language)
    }

    /// `content` in a widget's place: its margins, size and container, in `look` and `language`.
    static func framed(_ content: some View, _ size: WidgetSize, _ look: Look, _ language: Language) -> some View {
        let frame = points(size)
        return
            content
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

    /// `view` at twice its size in points.
    static func render(_ view: some View, _ name: String) throws -> CGImage {
        let renderer = ImageRenderer(content: view)
        renderer.scale = 2
        return try #require(renderer.cgImage, "\(name)")
    }

    static func writePNG(_ image: CGImage, _ name: String) throws {
        try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
        let png = try #require(NSBitmapImageRep(cgImage: image).representation(using: .png, properties: [:]))
        try png.write(to: output.appendingPathComponent("\(name).png"))
    }

    static func write(_ view: some View, _ name: String) throws {
        try writePNG(render(view, name), name)
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
        var width: CGFloat
        var view: AnyView
    }

    static func picture(
        _ scene: Scene, _ size: WidgetSize, _ language: Language, look: Look = .standard, caption: String? = nil
    ) -> Picture {
        Picture(
            caption: caption ?? "\(title(size)) · \(scene.title)", width: points(size).width,
            view: AnyView(widget(scene, size, look, language)))
    }

    /// 0.6.1's widget, then 0.7's, for `scene` in `size`.
    static func pair(_ scene: Scene, _ size: WidgetSize, _ language: Language) -> [Picture] {
        [
            Picture(
                caption: "0.6.1 · \(title(size)) · \(scene.title)", width: points(size).width,
                view: AnyView(widget061(scene, size, language))),
            picture(scene, size, language, caption: "0.7 · \(title(size)) · \(scene.title)"),
        ]
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
                            // As wide as the picture, so the columns stay aligned.
                            Text(verbatim: picture.caption)
                                .font(.system(size: 12))
                                .foregroundStyle(Color(white: 0.25))
                                .fixedSize(horizontal: false, vertical: true)
                                .frame(width: picture.width, alignment: .leading)
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
                "1-small-and-medium-automatic", "1. Small and medium, Automatic: 0.6.1 on the left, 0.7 on the right",
                questionOneScenes.map { scene in [WidgetSize.small, .medium].flatMap { pair(scene, $0, l) } }
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

    // MARK: The second look

    /// The second look's sheet (plan-0.7.0 §6.1b): small and medium Automatic at the Charge Limit
    /// beside 0.6.1's widget, which said "Not charging", large, and Custom with the "Charge limit"
    /// detail in each declared family.
    static func systemChargeLimitRows(_ l: Language) -> [[Picture]] {
        [
            [WidgetSize.small, .medium].flatMap { pair(chargedToLimit, $0, l) },
            [picture(chargedToLimit, .large, l), picture(customSystemChargeLimit, .medium, l)],
            [picture(customSystemChargeLimit, .small, l), picture(customSystemChargeLimit, .large, l)],
        ]
    }

    @Test(arguments: Language.allCases)
    func rendersTheChargeLimitSheet(_ language: Language) throws {
        guard Self.languages.contains(language) else { return }
        try Self.write(
            Self.sheet(
                "The Battery widget at the Charge Limit: Automatic, then Custom's detail — \(language.name)",
                Self.systemChargeLimitRows(language)),
            "sheet-charge-limit\(language.suffix)")
    }

    // MARK: Against 0.6.1

    /// The look check's first question: small and medium Automatic, which keep 0.6.1's look but
    /// for the plan's intended changes (§7.3: "tomorrow", the attention row, "Updated", the empty
    /// state's words, the symbol beside a low charge) and, in Russian, the second look's "80%"
    /// where 0.6.1 wrote "80 %".
    static let questionOneScenes: [Scene] = [
        onBattery, charging, low, critical, full, onHold, old, serviced, hot, noBattery,
    ]

    /// 0.6.1's small and medium widget beside 0.7's Automatic, and where their pixels differ.
    @Test(arguments: Language.allCases)
    func rendersTheChangesSince061(_ language: Language) throws {
        guard Self.languages.contains(language) else { return }
        var rows: [[Picture]] = []
        for scene in Self.questionOneScenes {
            var row: [Picture] = []
            for size in [WidgetSize.small, .medium] {
                let name = "\(Self.fileName(size))-\(scene.name)\(language.suffix)"
                let old = try Self.render(Self.widget061(scene, size, language), "battery-0.6.1-\(name)")
                let new = try Self.render(Self.widget(scene, size, .standard, language), "battery-\(name)")
                try Self.writePNG(old, "battery-0.6.1-\(name)")
                let diff = try #require(PixelDiff(old, new), "\(name): the two pictures' pixels aren't comparable")
                try Self.write(diff.view, "diff-0.6.1-to-0.7-\(name)")
                let caption = "\(Self.title(size)) · \(scene.title): \(diff.summary)"
                print("Look check question 1, \(language.name): \(caption)")
                row.append(Picture(caption: caption, width: Self.points(size).width, view: AnyView(diff.view)))
            }
            rows.append(row)
        }
        try Self.write(
            Self.sheet("1. Where 0.7 differs from 0.6.1, in red — \(language.name)", rows),
            "sheet-1b-pixel-diff-against-0.6.1\(language.suffix)")
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

/// Where two pictures of the same size differ: the newer one faded, with each pixel that differs
/// in red. A pixel differs when any of its channels is off by more than 2 of 255.
struct PixelDiff {
    let changed: Int
    let total: Int
    let view: AnyView

    /// `nil` when the pictures' sizes or pixel formats differ.
    @MainActor init?(_ old: CGImage, _ new: CGImage) {
        let width = old.width
        let height = old.height
        let bytesPerPixel = old.bitsPerPixel / 8
        guard width == new.width, height == new.height, old.bitsPerPixel == new.bitsPerPixel,
            old.bytesPerRow == new.bytesPerRow, old.bitmapInfo == new.bitmapInfo, old.bitsPerComponent == 8,
            new.bitsPerComponent == 8, bytesPerPixel > 0,
            let oldData = old.dataProvider?.data, let newData = new.dataProvider?.data
        else { return nil }
        let a = [UInt8](oldData as Data)
        let b = [UInt8](newData as Data)
        guard a.count >= height * old.bytesPerRow, b.count >= height * old.bytesPerRow else { return nil }
        var mask = [UInt8](repeating: 0, count: width * height * 4)
        var changed = 0
        for y in 0..<height {
            for x in 0..<width {
                let offset = y * old.bytesPerRow + x * bytesPerPixel
                let differs = (offset..<offset + bytesPerPixel).contains { abs(Int(a[$0]) - Int(b[$0])) > 2 }
                guard differs else { continue }
                changed += 1
                // Opaque red, premultiplied RGBA.
                let pixel = (y * width + x) * 4
                mask[pixel] = 255
                mask[pixel + 3] = 255
            }
        }
        guard let space = CGColorSpace(name: CGColorSpace.sRGB),
            let provider = CGDataProvider(data: Data(mask) as CFData),
            let marks = CGImage(
                width: width, height: height, bitsPerComponent: 8, bitsPerPixel: 32, bytesPerRow: width * 4,
                space: space, bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue),
                provider: provider, decode: nil, shouldInterpolate: false, intent: .defaultIntent)
        else { return nil }
        self.changed = changed
        self.total = width * height
        self.view = AnyView(
            ZStack {
                Color.white
                Image(decorative: new, scale: 2).interpolation(.none).opacity(0.3)
                Image(decorative: marks, scale: 2).interpolation(.none)
            }
            .frame(width: CGFloat(width) / 2, height: CGFloat(height) / 2))
    }

    /// "1.2 % of the pixels differ", or "the same pixels".
    var summary: String {
        guard changed > 0 else { return "the same pixels" }
        let share = (Double(changed) / Double(total) * 100).formatted(
            .number.precision(.fractionLength(1)).locale(Locale(identifier: "en_US")))
        return "\(share) % of the pixels differ"
    }
}
#endif
