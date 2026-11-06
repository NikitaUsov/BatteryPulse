import Foundation
import Testing

@testable import BatteryCore

/// The widget's own string table (INV SIZ-07): `scripts/widget-strings.swift` keeps the catalog's
/// entries whose keys the widget's sources name as string literals, and the widget extension ships
/// only those. A key the widget looks up that no file there names would draw in English, so every
/// word the widget can show or VoiceOver read must be such a key.
struct WidgetStringsTests {
    /// The folders whose literals name the widget's keys, relative to `Sources/`, as
    /// scripts/build-app.sh and CI pass them to the script.
    static let folders = ["BatteryPulseWidget/", "BatteryCore/Widget/"]

    /// The keys the script keeps: each one-line string literal of the folders' files, an
    /// interpolation counting as `%@`, that is a catalog key.
    static func widgetKeys() throws -> Set<String> {
        var named: Set<String> = []
        for file in try SourceScanner.allFiles.get() where folders.contains(where: file.path.hasPrefix) {
            for match in file.text.matches(of: #/"((?:[^"\\\n]|\\.)*)"/#) {
                named.insert(LocalizationCatalogTests.catalogKey(for: String(match.output.1)))
            }
        }
        return named
    }

    /// Every key of `labels` and of the widget's own words.
    static func keys(_ labels: [WidgetSpokenLabel]) -> Set<String> {
        Set(labels.flatMap(\.keys))
    }

    /// The words the widget can show or read: its sources' localized literals, its VoiceOver labels
    /// over every case the accessibility tests draw, every kind's empty states and plans of the
    /// sample feed, and the words BatteryCore names for its labels, states and accessories.
    static func usedKeys() throws -> Set<String> {
        var used: Set<String> = []
        for file in try SourceScanner.files.get() where file.path.hasPrefix("BatteryPulseWidget/") {
            used.formUnion(
                LocalizationCatalogTests.localizedLiterals(in: file.text).map(LocalizationCatalogTests.catalogKey))
        }
        for c in try WidgetAccessibilityTests.cases() where c.language == .english {
            used.formUnion(keys(WidgetAccessibility.elements(c.plan)))
        }
        let feed = WidgetFeed.sample(at: WidgetChartTests.now)
        let entry = WidgetTimelinePlan.Entry(date: WidgetChartTests.now, showsEstimate: false)
        let f = WidgetChartTests.formatter
        for size in [WidgetSize.small, .medium, .large] {
            for series in HistoryWidgetSeries.allCases {
                let plan = HistoryWidgetPlan.make(
                    size: size, configuration: HistoryWidgetConfiguration(series: series), feed: feed, entry: entry,
                    formatter: f, timeZone: WidgetChartTests.utc)
                used.formUnion(keys(WidgetAccessibility.elements(plan)))
            }
            for show in DevicesWidgetShow.allCases {
                let plan = DevicesWidgetPlan.make(
                    size: size, configuration: DevicesWidgetConfiguration(show: show), feed: feed, entry: entry,
                    formatter: f, timeZone: WidgetChartTests.utc)
                used.formUnion(keys(WidgetAccessibility.elements(plan)))
            }
            let accessories = AccessoryReading(sources: DemoAccessories.sources).accessories
            let plan = AccessoriesWidgetPlan.make(
                size: size, configuration: AccessoriesWidgetConfiguration(), accessories: accessories, readAt: .now,
                entry: WidgetTimelinePlan.Entry(date: .now, showsEstimate: false, isStale: true), formatter: f,
                timeZone: WidgetChartTests.utc)
            used.formUnion(keys(WidgetAccessibility.elements(plan)))
        }
        used.formUnion(keys(HistoryWidgetEmptyReason.allCases.map(\.spokenLabel)))
        used.formUnion(keys(DevicesWidgetEmptyReason.allCases.map(\.spokenLabel)))
        used.formUnion(keys(AccessoriesWidgetEmptyReason.allCases.map(\.spokenLabel)))
        used.formUnion(keys([WidgetEmptyReason.noBattery.spokenLabel, WidgetEmptyReason.noInformation.spokenLabel]))
        used.formUnion([WidgetEmptyReason.noInformation.shortMessageKey].compactMap { $0 })
        used.formUnion(BatteryWidgetField.allCases.flatMap { [$0.labelKey, $0.shortLabelKey].compactMap { $0 } })
        used.formUnion(WidgetStateWord.allCases.flatMap(\.phrase.keys))
        let conditions: [WidgetCondition] = [.normal, .fair, .poor, .checkBattery, .serviceRecommended]
        used.formUnion(conditions.flatMap { $0.phrase.keys + [$0.shortKey].compactMap { $0 } })
        used.formUnion(ThermalState.allCases.flatMap(\.phrase.keys))
        used.formUnion(AccessoryKind.allCases.map(\.titleKey))
        used.formUnion(AccessoryWidgetStatus.allCases.flatMap { $0.phrase.keys + [$0.shortKey].compactMap { $0 } })
        used.formUnion(HistoryWidgetSeries.allCases.map(\.titleKey) + WidgetChartSummary.Span.allCases.map(\.titleKey))
        used.formUnion(HistoryWidgetStatistic.Kind.allCases.map(\.labelKey))
        return used
    }

    /// Every word the widget uses is a literal of the folders, so the widget's own table has it.
    @Test func theWidgetsTableHasEveryWordItUses() throws {
        let missing = try Self.usedKeys().subtracting(Self.widgetKeys())
        #expect(missing.isEmpty, "Name each in the widget's sources or BatteryCore/Widget: \(missing.sorted())")
        #expect(try Self.usedKeys().count > 100)
    }

    static let repository = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()

    /// The table is the widget's: well under half the catalog, and none of the app's own words.
    @Test func theWidgetsTableLeavesTheAppsWordsOut() throws {
        let url = Self.repository.appendingPathComponent("Resources/Localizable.xcstrings")
        let object = try JSONSerialization.jsonObject(with: Data(contentsOf: url)) as? [String: Any]
        let catalog: [String: Any] = try #require(object?["strings"] as? [String: Any])
        let widget = try Self.widgetKeys()
        let kept = catalog.keys.filter { widget.contains($0) }
        #expect(kept.count * 2 < catalog.count, "\(kept.count) of \(catalog.count)")
        for appWord in ["Clear History…", "Raw Data"] {
            #expect(catalog[appWord] != nil && !widget.contains(appWord), "\(appWord)")
        }
    }

    /// The build and CI's previews make the table from the same folders, with the script.
    @Test func theBuildAndThePreviewsUseTheseFolders() throws {
        let invocation =
            "swift scripts/widget-strings.swift Resources/Localizable.xcstrings "
        let folders = Self.folders.map { "Sources/" + $0.dropLast() }.joined(separator: " ")
        for path in ["scripts/build-app.sh", ".github/workflows/ci.yml"] {
            let text = try String(
                contentsOf: Self.repository.appendingPathComponent(path), encoding: .utf8)
            let lines = text.split(separator: "\n").filter { $0.contains(invocation) }
            #expect(lines.count == 1, "\(path)")
            #expect(lines.allSatisfy { $0.hasSuffix(folders) }, "\(path): \(lines)")
        }
    }
}
