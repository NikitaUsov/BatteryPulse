#if os(macOS)
import AppKit
import BatteryCore
import CoreGraphics
import Foundation
import SwiftUI
import Testing
import WidgetKit

@testable import BatteryPulseWidget

/// The widgets in BatteryPulse's own language, which the feed carries (W-15), drawn while this
/// process runs in English, through the root views' own content and a feed the reader's decoder
/// read: what a Mac in English shows once BatteryPulse alone is set to Russian.
///
/// - `language-<kind>-<family>-<scene>-feed-ru.png`: Russian from the feed, the Mac in English with
///   the US region, so the numbers keep the region's formats, as the app's do.
/// - `sheet-language-feed-<kind>-<family>.png`: each scene in English without a feed (0.7.0's
///   widget), in Russian from the feed, and where Russian from the feed on a Russian Mac differs
///   from 0.7.0's Russian render, drawn from the Russian table directly (``WidgetPreviewTests``):
///   in red, with the share of pixels in its caption and the log, for the layout check.
///
/// Russian needs the table CI compiles before the tests (`build/widget-strings`); without it,
/// nothing is drawn.
@MainActor
struct WidgetLanguagePreviewTests {
    typealias Scene = WidgetPreviewTests.Scene
    typealias AccessoryScene = AccessoriesWidgetPreviewTests.Scene

    /// The extension's localizations, as its bundle lists them.
    static let localizations = ["en", "ru"]
    static let englishMac = Locale(identifier: "en_US")
    static let russianMac = Locale(identifier: "ru_RU")

    /// CI's compiled tables, with the `en.lproj` scripts/build-app.sh makes when the catalog
    /// compiles none for its source language; `nil` without the Russian table.
    static func tables() throws -> URL? {
        let tables = WidgetPreviewTests.strings
        guard WidgetPreviewTests.russian != nil else { return nil }
        try FileManager.default.createDirectory(
            at: tables.appendingPathComponent("en.lproj", isDirectory: true), withIntermediateDirectories: true)
        return tables
    }

    /// The language a feed written with `languages` chooses, as the widget reads it: through the
    /// reader's decoder.
    static func table(_ languages: [String]?, mac: Locale, tables: URL) throws -> WidgetLanguageTable {
        let state = try languages.map { languages in
            let feed = WidgetFeed(
                writtenAt: Date(timeIntervalSince1970: Date.now.timeIntervalSince1970.rounded(.down)),
                languages: languages, recordsHistory: true, readsDevices: false)
            let data = try WidgetFeed.encoded(feed)
            return WidgetFeedState(data: data, now: .now)
        }
        return WidgetLanguageTable.chosen(
            by: state, localizations: localizations, development: "en", resources: tables, mac: mac)
    }

    // MARK: The choice

    /// Each language from its own table, English's included, never the extension's own tables,
    /// which follow the Mac's language; without a feed, or with one the reader turns down, the
    /// extension's own.
    @Test func eachLanguageDrawsFromItsOwnTable() throws {
        guard let tables = try Self.tables() else { return }
        let english = try Self.table(["en"], mac: Self.russianMac, tables: tables)
        #expect(english.localization == "en")
        let englishStrings = try #require(english.strings)
        #expect(englishStrings.bundleURL.lastPathComponent == "en.lproj")
        #expect(englishStrings.localizedString(forKey: "Charging", value: nil, table: nil) == "Charging")
        #expect(english.formatter.symbols == BatteryFormatter.UnitSymbols.english)
        #expect(english.locale?.region?.identifier == "RU")

        let russian = try Self.table(["ru-RU", "en"], mac: Self.englishMac, tables: tables)
        #expect(russian.localization == "ru")
        let russianStrings = try #require(russian.strings)
        #expect(russianStrings.localizedString(forKey: "Charging", value: nil, table: nil) != "Charging")
        #expect(russian.formatter.symbols.watts == russianStrings.localizedString(forKey: "W", value: nil, table: nil))
        #expect(russian.locale?.language.languageCode?.identifier == "ru")
        #expect(russian.locale?.region?.identifier == "US")

        #expect(try Self.table(["de", "en"], mac: Self.englishMac, tables: tables).localization == "en")
        let none = try Self.table(nil, mac: Self.englishMac, tables: tables)
        #expect(none.localization == nil && none.strings == nil && none.locale == nil)
        #expect(none.formatter == BatteryFormatter.widget)
        let rejected = WidgetLanguageTable.chosen(
            by: .rejected(.futureDate), localizations: Self.localizations, development: "en", resources: tables)
        #expect(rejected.localization == nil && rejected.strings == nil)
        // A folder that is missing: the extension's own language.
        let missing = WidgetLanguageTable.make("de", resources: tables)
        #expect(missing.localization == nil && missing.strings == nil)
    }

    // MARK: The pictures

    static let batteryScenes: [Scene] = [
        WidgetPreviewTests.onBattery, WidgetPreviewTests.charging, WidgetPreviewTests.timeLeft,
        WidgetPreviewTests.customPower, WidgetPreviewTests.customHealth, WidgetPreviewTests.noBattery,
    ]
    static let accessoryScenes: [AccessoryScene] = [
        AccessoriesWidgetPreviewTests.all, AccessoriesWidgetPreviewTests.fullEarbuds,
        AccessoriesWidgetPreviewTests.none,
    ]

    /// The Battery widget as its root draws `scene` in `size` and `language`, in a process in
    /// English: the frame's own locale and words are English's.
    static func battery(_ scene: Scene, _ size: WidgetSize, _ language: WidgetLanguageTable) -> some View {
        let entry = BatteryEntry(
            snapshot: scene.snapshot, moment: WidgetPreviewTests.moment(scene), configuration: scene.configuration,
            language: language)
        return WidgetPreviewTests.framed(
            BatteryWidgetRoot.content(entry, size: size, timeZone: WidgetPreviewTests.timeZone), size, .standard,
            .english)
    }

    /// The Accessories widget as its root draws `scene` in `size` and `language`, in a process in
    /// English.
    static func accessories(_ scene: AccessoryScene, _ size: WidgetSize, _ language: WidgetLanguageTable)
        -> some View
    {
        let date = WidgetPreviewTests.date
        let entry = AccessoriesEntry(
            accessories: scene.accessories, readAt: scene.stale ? date.addingTimeInterval(-50 * 60) : date,
            moment: WidgetTimelinePlan.Entry(date: date, showsEstimate: false, isStale: scene.stale),
            configuration: scene.configuration, language: language)
        return WidgetPreviewTests.framed(
            AccessoriesWidgetRoot.content(entry, size: size, timeZone: WidgetPreviewTests.timeZone), size, .standard,
            .english)
    }

    /// One row of the sheet: English without a feed, Russian from the feed, and the pixels where
    /// Russian from the feed on a Russian Mac differs from 0.7.0's Russian render: none, but for
    /// the time left the system counts down, which may turn a minute between the two pictures.
    static func row(
        _ name: String, _ title: String, _ size: WidgetSize, english: some View, feed: some View,
        feedOnRussianMac: some View, direct: some View, countsDown: Bool = false
    ) throws -> [WidgetPreviewTests.Picture] {
        let width = WidgetPreviewTests.points(size).width
        let label = "\(WidgetPreviewTests.title(size)) · \(title)"
        try WidgetPreviewTests.write(feed, "language-\(name)-feed-ru")
        let old = try WidgetPreviewTests.render(direct, "language-\(name)-direct-ru")
        let new = try WidgetPreviewTests.render(feedOnRussianMac, "language-\(name)-feed-ru-mac-ru")
        let diff = try #require(PixelDiff(old, new), "\(name): the two pictures' pixels aren't comparable")
        print("Language from the feed, \(label): \(diff.summary) against the Russian table drawn directly")
        #expect(countsDown || diff.changed == 0, "\(name): \(diff.summary)")
        return [
            WidgetPreviewTests.Picture(caption: "English, no feed · \(label)", width: width, view: AnyView(english)),
            WidgetPreviewTests.Picture(
                caption: "Russian from the feed, the Mac in English (US) · \(label)", width: width, view: AnyView(feed)),
            WidgetPreviewTests.Picture(
                caption: "Russian from the feed on a Russian Mac against 0.7.0's Russian: \(diff.summary)",
                width: width, view: diff.view),
        ]
    }

    /// The Battery and Accessories widgets in Russian from the feed while the process is English,
    /// beside the English render, and measured against 0.7.0's Russian render: a sheet per kind and
    /// family, each small enough for one PNG.
    @Test func rendersTheWidgetsInTheFeedsLanguage() throws {
        guard let tables = try Self.tables() else { return }
        let russian = try Self.table(["ru"], mac: Self.englishMac, tables: tables)
        let russianOnRussianMac = try Self.table(["ru"], mac: Self.russianMac, tables: tables)
        let english = WidgetLanguageTable.extensionOwn
        for size in WidgetPreviewTests.families {
            let family = WidgetPreviewTests.fileName(size)
            let rows = try Self.batteryScenes.map { scene in
                try Self.row(
                    "battery-\(family)-\(scene.name)", scene.title, size, english: Self.battery(scene, size, english),
                    feed: Self.battery(scene, size, russian),
                    feedOnRussianMac: Self.battery(scene, size, russianOnRussianMac),
                    direct: WidgetPreviewTests.widget(scene, size, .standard, .russian),
                    countsDown: scene.configuration.time == .timeLeft)
            }
            try WidgetPreviewTests.write(
                WidgetPreviewTests.sheet(Self.heading("Battery", size), rows), "sheet-language-feed-battery-\(family)")
        }
        for size in AccessoriesWidgetPreviewTests.families {
            let family = WidgetPreviewTests.fileName(size)
            let rows = try Self.accessoryScenes.map { scene in
                try Self.row(
                    "accessories-\(family)-\(scene.name)", scene.title, size,
                    english: Self.accessories(scene, size, english), feed: Self.accessories(scene, size, russian),
                    feedOnRussianMac: Self.accessories(scene, size, russianOnRussianMac),
                    direct: AccessoriesWidgetPreviewTests.widget(scene, size, .standard, .russian))
            }
            try WidgetPreviewTests.write(
                WidgetPreviewTests.sheet(Self.heading("Accessories", size), rows),
                "sheet-language-feed-accessories-\(family)")
        }
    }

    static func heading(_ kind: String, _ size: WidgetSize) -> String {
        "The \(kind) widget, \(WidgetPreviewTests.title(size).lowercased()), in BatteryPulse's language from the feed, the process in English: English without a feed, Russian from the feed, and Russian from the feed against 0.7.0's Russian"
    }
}
#endif
