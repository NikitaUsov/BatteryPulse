#if os(macOS)
import BatteryCore
import Foundation
import SwiftUI
import Testing
import WidgetKit

@testable import BatteryPulseWidget

/// Renders the History widget, the large Battery widget's History chart and the two feed details
/// into PNGs for Look 1 (plan-0.7.1 §6.1), beside the other widgets' (``WidgetPreviewTests``, whose
/// frame, languages, rendering modes and sheets these reuse), in English and Russian, light and
/// dark. The feeds are BatteryCore's made-up sample, never anyone's history.
///
/// - `history-<family>-<scene>[-ru].png` are the single History widgets, full colour and light;
/// - `sheet-look1-<n>-<subject>[-dark][-ru].png` are Look 1's sheets, one per question: 1 the
///   History widget in medium and large, every content option; 2 the large Battery widget with
///   its chart and without; 3 the two new details; 4 the states; 5 the edit sheet's new words, in
///   English beside Russian;
/// - `sheet-look1-modes-history-<family>[-ru].png` holds every rendering mode in light and dark.
@MainActor
struct HistoryWidgetPreviewTests {
    typealias Language = WidgetPreviewTests.Language
    typealias Look = WidgetPreviewTests.Look
    typealias Picture = WidgetPreviewTests.Picture

    static let families: [WidgetSize] = [.medium, .large]

    /// What a History picture shows: a configuration and the feed the widget read.
    struct Scene: Sendable {
        var name: String
        var title: String
        var configuration = HistoryWidgetConfiguration()
        var feed: WidgetFeed? = WidgetPreviewTests.sampleFeed
    }

    /// The sample written three hours ago: BatteryPulse hasn't run since.
    nonisolated static let oldFeed = WidgetFeed.sample(at: Date.now.addingTimeInterval(-3 * 60 * 60))
    nonisolated static let recordingOff = WidgetFeed(
        writtenAt: WidgetPreviewTests.sampleFeed.writtenAt, languages: ["en"], recordsHistory: false,
        readsDevices: false)
    /// Recording on, but nothing recorded yet.
    nonisolated static let nothingYet = WidgetFeed(
        writtenAt: WidgetPreviewTests.sampleFeed.writtenAt, languages: ["en"], recordsHistory: true,
        readsDevices: false)

    static func scene(
        _ name: String, _ title: String, _ period: HistoryWidgetPeriod = .day, _ series: HistoryWidgetSeries = .charge,
        statistics: Bool = true, feed: WidgetFeed? = WidgetPreviewTests.sampleFeed
    ) -> Scene {
        Scene(
            name: name, title: title,
            configuration: HistoryWidgetConfiguration(period: period, series: series, showsStatistics: statistics),
            feed: feed)
    }

    // Every content option.
    static let dayCharge = scene("day-charge", "24 hours, charge (the default)")
    static let weekCharge = scene("week-charge", "7 days, charge", .week)
    static let dayPower = scene("day-battery-power", "24 hours, battery power", .day, .batteryPower)
    static let weekPower = scene("week-battery-power", "7 days, battery power", .week, .batteryPower)
    static let dayTemperature = scene("day-temperature", "24 hours, temperature", .day, .temperature)
    static let weekTemperature = scene("week-temperature", "7 days, temperature", .week, .temperature)
    static let capacity = scene("capacity", "90 days, capacity compared with design", .day, .capacityToDesign)
    static let cycles = scene("cycle-count", "90 days, cycle count", .day, .cycleCount)
    static let noStatistics = scene("no-statistics", "Statistics off (large)", statistics: false)
    // The states.
    static let noHistory = scene("no-history-yet", "No History Yet", feed: nothingYet)
    static let off = scene("recording-off", "Recording off", feed: recordingOff)
    static let old = scene("feed-old", "The feed 3 hours old", feed: oldFeed)
    static let noFeed = scene("no-feed", "No feed", feed: nil)

    static let options: [Scene] = [
        dayCharge, weekCharge, dayPower, weekPower, dayTemperature, weekTemperature, capacity, cycles, noStatistics,
    ]
    static let states: [Scene] = [noHistory, off, old, noFeed]
    static let modeScenes: [Scene] = [dayCharge, weekPower, capacity, old]

    /// The History widget as it draws `scene` in `size`, `look` and `language`, in its place.
    static func widget(_ scene: Scene, _ size: WidgetSize, _ look: Look, _ language: Language) -> some View {
        let entry = HistoryEntry(
            feed: scene.feed.map { WidgetFeedState.feed($0) },
            moment: WidgetTimelinePlan.Entry(date: WidgetPreviewTests.date, showsEstimate: false),
            configuration: scene.configuration)
        return WidgetPreviewTests.framed(
            HistoryWidgetView(
                entry: entry, size: size, formatter: language.formatter, timeZone: WidgetPreviewTests.timeZone),
            size, look, language)
    }

    static func picture(
        _ scene: Scene, _ size: WidgetSize, _ language: Language, look: Look = .standard, caption: String? = nil
    ) -> Picture {
        Picture(
            caption: caption ?? "\(WidgetPreviewTests.title(size)) · \(scene.title)",
            width: WidgetPreviewTests.points(size).width, view: AnyView(widget(scene, size, look, language)))
    }

    // MARK: The Battery widget

    typealias BatteryScene = WidgetPreviewTests.Scene

    static func battery(
        _ name: String, _ title: String, _ scenario: DemoScenario,
        _ configuration: BatteryWidgetConfiguration = BatteryWidgetConfiguration(),
        feed: WidgetFeed? = WidgetPreviewTests.sampleFeed
    ) -> BatteryScene {
        var scene = WidgetPreviewTests.scene(name, title, scenario, configuration)
        scene.feed = feed
        return scene
    }

    static let chartOnBattery = battery(
        "large-chart-on-battery", "1 · The History chart (the default), on battery", .onBattery)
    static let chartCharging = battery("large-chart-charging", "1 · The History chart, charging", .charging)
    static let rowsOnBattery = battery(
        "large-eight-rows-on-battery", "2 · History chart off: the eight rows", .onBattery,
        BatteryWidgetConfiguration(historyChart: false))
    static let rowsCharging = battery(
        "large-eight-rows-charging", "2 · History chart off, charging", .charging,
        BatteryWidgetConfiguration(historyChart: false))
    static let chartCustom = battery(
        "large-chart-custom", "Custom with the History chart", .onBattery,
        BatteryWidgetConfiguration(
            layout: .custom, main: .batteryPower,
            details: [.averageDrain, .timeOnBattery, .maximumCapacity, .cycleCount, .temperature, .adapter]))
    static let chartOld = battery(
        "large-chart-feed-old", "The History chart, the feed 3 hours old", .onBattery, feed: oldFeed)
    static let chartOff = battery(
        "large-chart-recording-off", "The History chart, recording off", .onBattery, feed: recordingOff)
    static let chartNothing = battery(
        "large-chart-no-history-yet", "The History chart, nothing recorded yet", .onBattery, feed: nothingYet)
    static let chartNoFeed = battery("large-chart-no-feed", "The History chart, no feed", .onBattery, feed: nil)

    /// The two new details, Custom only, beside two of 0.7.0's.
    static let details = BatteryWidgetConfiguration(
        layout: .custom, details: [.averageDrain, .timeOnBattery, .maximumCapacity, .cycleCount])
    static let detailsOnBattery = battery("custom-feed-details-on-battery", "On battery", .onBattery, details)
    static let detailsCharging = battery(
        "custom-feed-details-charging", "Charging: no time on battery", .charging, details)
    static let detailsNoFeed = battery("custom-feed-details-no-feed", "No feed: both —", .onBattery, details, feed: nil)

    static let batteryScenes: [BatteryScene] = [
        chartOnBattery, chartCharging, rowsOnBattery, rowsCharging, chartCustom, chartOld, chartOff, chartNothing,
        chartNoFeed, detailsOnBattery, detailsCharging, detailsNoFeed,
    ]

    static func batteryPicture(_ scene: BatteryScene, _ size: WidgetSize, _ language: Language, look: Look) -> Picture {
        WidgetPreviewTests.picture(scene, size, language, look: look)
    }

    // MARK: Single widgets

    @Test(arguments: Language.allCases)
    func rendersEveryFamilyAndScene(_ language: Language) throws {
        guard WidgetPreviewTests.languages.contains(language) else { return }
        for size in Self.families {
            for scene in Self.options + Self.states {
                try WidgetPreviewTests.write(
                    Self.widget(scene, size, .standard, language),
                    "history-\(WidgetPreviewTests.fileName(size))-\(scene.name)\(language.suffix)")
            }
        }
        for scene in Self.batteryScenes {
            for size in scene.name.hasPrefix("large") ? [WidgetSize.large] : WidgetPreviewTests.families {
                try WidgetPreviewTests.write(
                    WidgetPreviewTests.widget(scene, size, .standard, language),
                    "battery-\(WidgetPreviewTests.fileName(size))-\(scene.name)\(language.suffix)")
            }
        }
    }

    // MARK: Look 1's sheets

    /// `pictures` in rows of `columns`.
    static func rows(_ pictures: [Picture], columns: Int) -> [[Picture]] {
        stride(from: 0, to: pictures.count, by: columns).map { Array(pictures[$0..<min($0 + columns, pictures.count)]) }
    }

    /// Look 1's sheets in `look` and `language`, numbered as its questions are.
    static func lookOneSheets(_ look: Look, _ l: Language) -> [(name: String, heading: String, rows: [[Picture]])] {
        let appearance = look.dark ? "dark" : "light"
        return [
            (
                "1-history-medium", "1. The History widget, medium: every content option (\(appearance))",
                rows(options.map { picture($0, .medium, l, look: look) }, columns: 3)
            ),
            (
                "1-history-large",
                "1. The History widget, large: every content option, the statistics under it (\(appearance))",
                rows(options.map { picture($0, .large, l, look: look) }, columns: 3)
            ),
            (
                "2-battery-large",
                "2. The large Battery widget: 1 the History chart in place of the last two rows (the default, placed widgets too), 2 the eight rows (\(appearance))",
                [
                    [chartOnBattery, chartCharging, chartCustom].map { batteryPicture($0, .large, l, look: look) },
                    [rowsOnBattery, rowsCharging].map { batteryPicture($0, .large, l, look: look) },
                ]
            ),
            (
                "3-new-details", "3. The two new details, Average drain and Time on battery, in Custom (\(appearance))",
                [detailsOnBattery, detailsCharging, detailsNoFeed].map { scene in
                    WidgetPreviewTests.families.map { size in
                        batteryPicture(scene, size, l, look: look)
                    }
                }
            ),
            (
                "4-states",
                "4. The states, in the History widget and in the large Battery widget's chart (\(appearance))",
                [
                    states.map { picture($0, .medium, l, look: look) },
                    states.map { picture($0, .large, l, look: look) },
                    [chartNothing, chartOff, chartOld, chartNoFeed].map { batteryPicture($0, .large, l, look: look) },
                ]
            ),
        ]
    }

    /// Look 1's sheets, light and dark, in each language.
    @Test(arguments: Language.allCases)
    func rendersLookOnesSheets(_ language: Language) throws {
        guard WidgetPreviewTests.languages.contains(language) else { return }
        for look in [Look.standard, Look(mode: .fullColor, dark: true)] {
            for sheet in Self.lookOneSheets(look, language) {
                try WidgetPreviewTests.write(
                    WidgetPreviewTests.sheet("\(sheet.heading) — \(language.name)", sheet.rows),
                    "sheet-look1-\(sheet.name)\(look.dark ? "-dark" : "")\(language.suffix)")
            }
        }
        for size in Self.families {
            let rows = Look.all.map { look in
                Self.modeScenes.map {
                    Self.picture($0, size, language, look: look, caption: "\(look.title) · \($0.title)")
                }
            }
            let family = WidgetPreviewTests.title(size).lowercased()
            try WidgetPreviewTests.write(
                WidgetPreviewTests.sheet(
                    "The History widget's rendering modes, \(family); accented and vibrant approximate — \(language.name)",
                    rows),
                "sheet-look1-modes-history-\(WidgetPreviewTests.fileName(size))\(language.suffix)")
        }
    }

    /// The edit sheet's and the gallery's new words, English beside the Russian the widget's table
    /// holds (Look 1, question 5).
    static let editSheetWords: [String] = [
        "History", "Charge, power or temperature over the last day or week, or capacity and cycles over 90 days.",
        "Choose History",
        "Choose what the History widget shows.", "Period", "24 Hours", "7 Days", "Series", "Charge", "Battery power",
        "Temperature", "Capacity compared with design", "Cycle count", "Statistics", "History chart",
        "Average drain", "Time on battery",
    ]

    @Test func rendersTheEditSheetsWords() throws {
        guard let russian = WidgetPreviewTests.russian else { return }
        let rows = Self.editSheetWords.map { key in
            (key, russian.localizedString(forKey: key, value: nil, table: nil))
        }
        for (key, text) in rows {
            #expect(text != key, "\(key) isn't translated")
        }
        let table = VStack(alignment: .leading, spacing: 10) {
            Text(verbatim: "5. The edit sheet's and the gallery's new words: English, then Russian")
                .font(.system(size: 20, weight: .semibold))
            Grid(alignment: .leading, horizontalSpacing: 32, verticalSpacing: 8) {
                ForEach(Array(rows.enumerated()), id: \.offset) { _, row in
                    GridRow {
                        Text(verbatim: row.0)
                        Text(verbatim: row.1)
                    }
                }
            }
            .font(.system(size: 15))
        }
        .foregroundStyle(Color(white: 0.1))
        .padding(32)
        .background(Color(white: 0.9))
        .environment(\.colorScheme, .light)
        try WidgetPreviewTests.write(table, "sheet-look1-5-edit-sheet-words")
    }
}
#endif
