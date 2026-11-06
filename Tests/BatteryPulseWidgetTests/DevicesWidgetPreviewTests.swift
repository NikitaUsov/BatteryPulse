#if os(macOS)
import BatteryCore
import Foundation
import SwiftUI
import Testing
import WidgetKit

@testable import BatteryPulseWidget

/// Renders the iPhone & iPad widget into PNGs for Look 2 (plan-0.7.1 §6.1), beside the other
/// widgets' (``WidgetPreviewTests``, whose frame, languages and sheets these reuse), in English and
/// Russian, light and dark. The devices and their names are made up: Demo Mode's iPhone values,
/// never anyone's own.
///
/// - `devices-<family>-<scene>[-ru].png` are the single widgets, full colour and light;
/// - `sheet-look2-<n>-<subject>[-dark][-ru].png` are Look 2's sheets, one per question: 1 every
///   Show choice in small, medium and large; 2 the read time, "Updated 14:05" or the date (the
///   default) beside a self-updating "… ago"; 3 the states; 4 the edit sheet's words, in English
///   beside Russian;
/// - `sheet-look2-modes-<family>[-ru].png` holds every rendering mode in light and dark.
@MainActor
struct DevicesWidgetPreviewTests {
    typealias Language = WidgetPreviewTests.Language
    typealias Look = WidgetPreviewTests.Look
    typealias Picture = WidgetPreviewTests.Picture

    static let families: [WidgetSize] = [.small, .medium, .large]
    static var now: Date { WidgetPreviewTests.date }

    static func key(_ last: Character) -> DeviceKey {
        DeviceKey(rawValue: String(repeating: "0", count: 31) + String(last)) ?? .demo
    }

    /// A made-up device read `minutes` before the pictures' moment.
    static func device(
        _ last: Character, _ name: String?, model: String?, deviceClass: String, percent: Int?, _ state: ChargeState,
        minutes: Double, capacity: Int = 95, cycles: Int = 278, temperature10: Int = 312
    ) -> WidgetFeed.Device {
        WidgetFeed.Device(
            key: key(last), name: name, model: model, deviceClass: deviceClass, percent: percent, state: state,
            maximumCapacity: capacity, cycleCount: cycles, temperature10: temperature10,
            readAt: now.addingTimeInterval(-minutes * 60))
    }

    /// Five sample devices, the most recently read first, as the app writes them: an owner's
    /// names, model names and one with neither.
    static let samples: [WidgetFeed.Device] = [
        device(
            "1", "Anna's iPhone", model: "iPhone 17 Pro Max", deviceClass: "iPhone", percent: 65, .charging, minutes: 4),
        device(
            "2", nil, model: "iPad Air", deviceClass: "iPad", percent: 82, .discharging, minutes: 47, capacity: 98,
            cycles: 61, temperature10: 287),
        device(
            "3", "Work iPhone", model: "iPhone 16", deviceClass: "iPhone", percent: 14, .discharging, minutes: 6 * 60,
            capacity: 88, cycles: 642, temperature10: 301),
        device(
            "4", "Kitchen iPad", model: "iPad", deviceClass: "iPad", percent: 100, .charged, minutes: 30 * 60,
            capacity: 91, cycles: 402, temperature10: 276),
        device("5", nil, model: nil, deviceClass: "iPad", percent: nil, .unknown, minutes: 4 * 24 * 60),
    ]

    static func feed(
        _ devices: [WidgetFeed.Device]? = samples, readsDevices: Bool = true, writtenMinutesAgo: Double = 2
    ) -> WidgetFeed {
        WidgetFeed(
            writtenAt: now.addingTimeInterval(-writtenMinutesAgo * 60), languages: ["en"], recordsHistory: true,
            readsDevices: readsDevices, devices: devices)
    }

    /// What a picture shows: a configuration and the feed the widget read.
    struct Scene {
        var name: String
        var title: String
        var configuration = DevicesWidgetConfiguration()
        var feed: WidgetFeed?
    }

    static func scene(
        _ name: String, _ title: String, _ show: DevicesWidgetShow = .mostRecent, device: DeviceKey? = nil,
        feed: WidgetFeed? = feed()
    ) -> Scene {
        Scene(
            name: name, title: title, configuration: DevicesWidgetConfiguration(show: show, device: device), feed: feed)
    }

    // Every Show choice.
    static let mostRecent = scene("most-recent", "Most recently read (the default)")
    static let lowest = scene("lowest", "Lowest charge", .lowest)
    static let all = scene("all", "All", .all)
    static let oneDevice = scene("one-device", "One device: the iPad Air", .oneDevice, device: key("2"))
    static let notChosen = scene("one-device-not-chosen", "One device, none chosen yet", .oneDevice)
    static let unnamed = scene("one-device-unnamed", "One device with no name", .oneDevice, device: key("5"))
    static let yesterday = scene("one-device-yesterday", "One device read yesterday", .oneDevice, device: key("4"))
    // The states.
    static let readsOff = scene("reads-off", "Reading off", feed: feed(nil, readsDevices: false))
    static let noDevices = scene("none-remembered", "None remembered", feed: feed([]))
    static let forgotten = scene("forgotten", "A forgotten device", .oneDevice, device: key("9"))
    static let old = scene("feed-old", "The feed 3 hours old", feed: feed(writtenMinutesAgo: 3 * 60))
    static let oldAll = scene("feed-old-all", "All, the feed 3 hours old", .all, feed: feed(writtenMinutesAgo: 3 * 60))
    static let noFeed = scene("no-feed", "No feed", feed: nil)

    static let choices: [Scene] = [mostRecent, lowest, all, oneDevice]
    static let states: [Scene] = [readsOff, noDevices, forgotten, old, oldAll, noFeed]
    static let modeScenes: [Scene] = [mostRecent, lowest, all, old]

    /// The iPhone & iPad widget as it draws `scene` in `size`, `look` and `language`, in its place.
    static func widget(_ scene: Scene, _ size: WidgetSize, _ look: Look, _ language: Language) -> some View {
        let plan = DevicesWidgetPlan.make(
            size: size, configuration: scene.configuration, feed: scene.feed,
            entry: WidgetTimelinePlan.Entry(date: now, showsEstimate: false), formatter: language.formatter,
            timeZone: WidgetPreviewTests.timeZone)
        return WidgetPreviewTests.framed(DevicesWidgetView(plan: plan, size: size), size, look, language)
    }

    static func picture(
        _ scene: Scene, _ size: WidgetSize, _ language: Language, look: Look = .standard, caption: String? = nil
    ) -> Picture {
        Picture(
            caption: caption ?? "\(WidgetPreviewTests.title(size)) · \(scene.title)",
            width: WidgetPreviewTests.points(size).width, view: AnyView(widget(scene, size, look, language)))
    }

    /// Look 2's second answer, not built: the small widget with a self-updating "… ago" in place of
    /// "Updated %@", drawn here from the system's relative format so the two can be compared.
    static func agoPicture(_ scene: Scene, _ language: Language, look: Look) -> Picture {
        let plan = DevicesWidgetPlan.make(
            size: .small, configuration: scene.configuration, feed: scene.feed,
            entry: WidgetTimelinePlan.Entry(date: now, showsEstimate: false), formatter: language.formatter,
            timeZone: WidgetPreviewTests.timeZone)
        guard case .devices(let layout) = plan, var row = layout.rows.first else {
            return picture(scene, .small, language, look: look)
        }
        let read = scene.feed?.devices?.first { $0.key == row.key }?.readAt ?? now
        let style = Date.RelativeFormatStyle(presentation: .numeric, unitsStyle: .wide).locale(language.locale)
        row.updated = nil
        let view = VStack(alignment: .leading, spacing: 4) {
            DeviceBlock(row: row, roomy: false)
            Text(verbatim: read.formatted(style))
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        return Picture(
            caption: "2 · \(scene.title), counting by itself", width: WidgetPreviewTests.points(.small).width,
            view: AnyView(WidgetPreviewTests.framed(view, .small, look, language)))
    }

    // MARK: Single widgets

    @Test(arguments: Language.allCases)
    func rendersEveryFamilyAndScene(_ language: Language) throws {
        guard WidgetPreviewTests.languages.contains(language) else { return }
        for size in Self.families {
            for scene in Self.choices + [Self.notChosen, Self.unnamed, Self.yesterday] + Self.states {
                try WidgetPreviewTests.write(
                    Self.widget(scene, size, .standard, language),
                    "devices-\(WidgetPreviewTests.fileName(size))-\(scene.name)\(language.suffix)")
            }
        }
    }

    // MARK: Look 2's sheets

    /// Look 2's sheets in `look` and `language`, numbered as its questions are.
    static func lookTwoSheets(_ look: Look, _ l: Language) -> [(name: String, heading: String, rows: [[Picture]])] {
        let appearance = look.dark ? "dark" : "light"
        return [
            (
                "1-show-choices",
                "1. iPhone & iPad, small, medium and large, with sample names: the most recently read, the lowest, all, one chosen (\(appearance))",
                choices.map { scene in families.map { picture(scene, $0, l, look: look) } }
            ),
            (
                "1-one-device-more",
                "1. One device: none chosen yet (the most recently read), one with no name, one read yesterday (\(appearance))",
                [notChosen, unnamed, yesterday].map { scene in families.map { picture(scene, $0, l, look: look) } }
            ),
            (
                "2-read-time",
                "2. When it was read: 1 \"Updated 14:05\", or the date when it isn't today (the default); 2 a self-updating \"… ago\" (\(appearance))",
                [
                    [mostRecent, yesterday].map {
                        picture($0, .small, l, look: look, caption: "1 · \($0.title)")
                    } + [mostRecent, yesterday].map { agoPicture($0, l, look: look) }
                ]
            ),
            (
                "3-states",
                "3. The states: reading off, none remembered, a forgotten device, \"Open BatteryPulse to update\" (\(appearance))",
                [
                    states.map { picture($0, .small, l, look: look) },
                    states.map { picture($0, .medium, l, look: look) },
                ]
            ),
        ]
    }

    /// Look 2's sheets, light and dark, in each language, and every rendering mode per family.
    @Test(arguments: Language.allCases)
    func rendersLookTwosSheets(_ language: Language) throws {
        guard WidgetPreviewTests.languages.contains(language) else { return }
        for look in [Look.standard, Look(mode: .fullColor, dark: true)] {
            for sheet in Self.lookTwoSheets(look, language) {
                try WidgetPreviewTests.write(
                    WidgetPreviewTests.sheet("\(sheet.heading) — \(language.name)", sheet.rows),
                    "sheet-look2-\(sheet.name)\(look.dark ? "-dark" : "")\(language.suffix)")
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
                    "The iPhone & iPad widget's rendering modes, \(family); accented and vibrant approximate — \(language.name)",
                    rows),
                "sheet-look2-modes-\(WidgetPreviewTests.fileName(size))\(language.suffix)")
        }
    }

    /// The edit sheet's and the gallery's words, English beside the Russian the widget's table
    /// holds (Look 2, question 4), and the states' messages.
    static let editSheetWords: [String] = [
        "iPhone and iPad", "The charge of your iPhone and iPad, as BatteryPulse last read it.",
        "Choose iPhone and iPad",
        "Choose which iPhones and iPads the widget shows.", "Show", "Most recently read", "Lowest charge", "All",
        "One device", "Device", "Unknown Device", "Turn on Read iPhone and iPad batteries in BatteryPulse",
        "Connect an iPhone or iPad with a cable", "This device was forgotten", "Open BatteryPulse to update",
        "Updated %@",
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
            Text(verbatim: "4. The edit sheet's and the gallery's words, and the states': English, then Russian")
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
        try WidgetPreviewTests.write(table, "sheet-look2-4-edit-sheet-words")
    }
}
#endif
