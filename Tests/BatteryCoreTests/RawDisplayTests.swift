import Foundation
import Testing

@testable import BatteryCore

/// The Developer table's prepared text and its filter (playbook UI-10): one search per row finds
/// exactly what 0.6.0's five searches found, ignoring case but never diacritics.
@Suite struct RawDisplayTests {
    private static let formatter = BatteryFormatter(locale: Locale(identifier: "en_US"))

    /// A stand-in for the app's `RawValueText`, which only builds on macOS: the same formatter
    /// calls for the measured values, a plain description for the rest.
    static func decodedText(_ decoded: DecodedRawValue) -> String {
        let f = formatter
        switch decoded {
        case .milliampHours(let value): return f.milliampHours(value)
        case .millivolts(let value): return f.volts(millivolts: value, fractionDigits: 3)
        case .milliamps(let value): return f.milliamps(value)
        case .milliwatts(let value): return f.watts(Double(value) / 1000, fractionDigits: 2)
        case .percent(let value): return f.percent(value)
        case .celsius(let value): return f.celsius(value)
        case .minutes(let value): return f.duration(minutes: value)
        case .seconds(let value): return f.duration(seconds: value)
        default: return String(describing: decoded)
        }
    }

    /// The app looks the English summary up in its catalog; the test bundle has none, so this
    /// costs the lookup and returns the English text.
    static func localizedSummary(_ english: String) -> String {
        Bundle.main.localizedString(forKey: english, value: english, table: nil)
    }

    /// 0.6.0's match: the path, the value, the decoded value's text and the glossary summary in
    /// English and in the app's language, each searched on its own.
    static func matchesFiveWays(
        _ row: RawRow, _ query: String, decoded: (DecodedRawValue) -> String = decodedText,
        summary localized: (String) -> String = localizedSummary
    ) -> Bool {
        if row.path.localizedCaseInsensitiveContains(query) || row.value.localizedCaseInsensitiveContains(query) {
            return true
        }
        if let value = row.decoded, decoded(value).localizedCaseInsensitiveContains(query) {
            return true
        }
        if let summary = row.info?.summary {
            return summary.localizedCaseInsensitiveContains(query)
                || localized(summary).localizedCaseInsensitiveContains(query)
        }
        return false
    }

    private static func display(_ fixture: Fixture) throws -> [RawDisplaySection] {
        RawDisplaySection.sections(
            for: try fixture.reading().redactedRawCapture, decoded: decodedText, summary: localizedSummary)
    }

    @Test(arguments: Fixture.allCases)
    func rowsCarryTheTableText(fixture: Fixture) throws {
        let sections = RawSection.sections(for: try fixture.reading().redactedRawCapture)
        let display = try Self.display(fixture)
        #expect(display.map(\.id) == sections.map(\.id))
        #expect(display.map(\.title) == sections.map(\.title))
        for (shown, section) in zip(display, sections) {
            #expect(shown.rows.map(\.id) == section.rows.map(\.id))
            for (row, raw) in zip(shown.rows, section.rows) {
                #expect(row.path == raw.path)
                #expect(row.value == raw.value)
                #expect(row.decoded == raw.decoded.map(Self.decodedText))
                #expect(row.englishSummary == raw.info?.summary)
                #expect(row.summary == raw.info?.summary.map(Self.localizedSummary))
            }
        }
    }

    /// Every real and synthetic capture, against queries that hit keys, values, decodings and
    /// descriptions, in any case, with spaces around them, or nowhere.
    @Test(arguments: Fixture.allCases)
    func filterMatchesWhat060Matched(fixture: Fixture) throws {
        let sections = RawSection.sections(for: try fixture.reading().redactedRawCapture)
        let display = try Self.display(fixture)
        let queries = [
            "charge", "CHARGE", "Capacity", "mah", "0x", "1", "temp", " design ", "Battery", "voltage",
            "not available", "°C", "%", "min", "BatteryData.", "Amperage\n", "\u{0439}", "nothing-matches-this",
        ]
        for query in queries {
            let trimmed = query.trimmingCharacters(in: .whitespaces)
            let expected = sections.compactMap { section -> [String]? in
                let ids = section.rows.filter { Self.matchesFiveWays($0, trimmed) }.map(\.id)
                return ids.isEmpty ? nil : ids
            }
            let found = RawDisplaySection.filter(display, by: query).map { $0.rows.map(\.id) }
            #expect(found == expected, "\(fixture.rawValue): \(query.debugDescription)")
        }
    }

    private static func row(path: String, value: PropertyValue = .int(1), summary: String? = nil) -> RawRow {
        RawRow(
            id: "Test:" + path, path: path, key: path, property: value,
            info: summary.map { RawKeyGlossary.Info(.other, $0) }, decoded: nil)
    }

    @Test func ignoresCase() {
        let row = RawDisplayRow(Self.row(path: "DesignCapacity"), decoded: Self.decodedText, summary: { $0 })
        #expect(row.matches("designcapacity"))
        #expect(row.matches("DESIGNCAPACITY"))
        #expect(!row.matches("Design Capacity"))
    }

    /// Russian tells U+0438 from U+0439 and U+0435 from U+0451; a filter that folded diacritics
    /// would match one for the other.
    @Test func keepsDiacritics() {
        // A translated summary with U+0439 and U+0451, and one with U+0438 and U+0435.
        let withMarks = RawDisplayRow(
            Self.row(path: "A", summary: "a"), decoded: Self.decodedText, summary: { _ in "x\u{0439}\u{0451}x" })
        let withoutMarks = RawDisplayRow(
            Self.row(path: "B", summary: "b"), decoded: Self.decodedText, summary: { _ in "x\u{0438}\u{0435}x" })
        // Upper case U+0419 and U+0401 still match their lower case.
        #expect(withMarks.matches("\u{0419}"))
        #expect(withMarks.matches("\u{0401}"))
        #expect(!withMarks.matches("\u{0438}"))
        #expect(!withMarks.matches("\u{0435}"))
        #expect(withoutMarks.matches("\u{0418}"))
        #expect(!withoutMarks.matches("\u{0439}"))
        #expect(!withoutMarks.matches("\u{0451}"))
    }

    /// The joined text puts a line break between the key and the value; a pasted query with one
    /// still matches only inside one text, as 0.6.0's did.
    @Test func lineBreaksNeverJoinTwoTexts() {
        let row = RawDisplayRow(
            Self.row(path: "Key", value: .string("one\ntwo")), decoded: Self.decodedText, summary: { $0 })
        #expect(row.searchText.contains("Key\n"))
        #expect(!row.matches("Key\n"))
        #expect(row.matches("one\ntwo"))
        #expect(row.matches("ONE\n"))
    }

    @Test func emptyQueriesKeepEverything() throws {
        let display = try Self.display(.m5OnBatterySMC)
        #expect(RawDisplaySection.filter(display, by: "") == display)
        #expect(RawDisplaySection.filter(display, by: "   ") == display)
        #expect(RawDisplaySection.filter(display, by: "nothing-matches-this").isEmpty)
    }

    /// The table's source switch works on the prepared sections as on the raw ones.
    @Test func groupsWorkOnTheDisplaySections() throws {
        let display = try Self.display(.m5PluggedIn10s)
        let sections = RawSection.sections(for: try Fixture.m5PluggedIn10s.reading().redactedRawCapture)
        #expect(RawSectionGroup.groups(in: display) == RawSectionGroup.groups(in: sections))
        for group in RawSectionGroup.allCases {
            #expect(
                RawSectionGroup.sections(display, in: group).map(\.id)
                    == RawSectionGroup.sections(sections, in: group).map(\.id))
        }
    }

    // MARK: - The kept table (E19)

    private static func update(
        _ table: inout RawDisplayTable, _ capture: PropertyDictionary, wording: String = "en_US UTC"
    ) -> Int {
        table.update(for: capture, wording: wording, decoded: decodedText, summary: localizedSummary)
    }

    /// Whatever reading came before, the kept table is the table a fresh build makes: every pair
    /// of captures, real and synthetic, in both orders.
    @Test func keptTableMatchesAFreshBuild() throws {
        let captures = try Fixture.allCases.map { try $0.reading().redactedRawCapture }
        for before in captures {
            for capture in captures {
                var table = RawDisplayTable()
                _ = Self.update(&table, before)
                _ = Self.update(&table, capture)
                #expect(
                    table.sections
                        == RawDisplaySection.sections(
                            for: capture, decoded: Self.decodedText, summary: Self.localizedSummary))
            }
        }
    }

    /// The same capture builds nothing again; a changed value builds its section alone.
    @Test func onlyChangedSectionsAreBuiltAgain() throws {
        let capture = try Fixture.m5OnBatterySMC.reading().redactedRawCapture
        let sectionCount = RawSection.sections(for: capture).count
        var table = RawDisplayTable()
        #expect(Self.update(&table, capture) == sectionCount)
        let first = table.sections
        #expect(Self.update(&table, capture) == 0)
        #expect(table.sections == first)

        var changed = capture
        var powerSource = try #require(changed[BatteryReading.CaptureKey.powerSource]?.dictionaryValue)
        powerSource["Current Capacity"] = .int(42)
        changed[BatteryReading.CaptureKey.powerSource] = .dictionary(powerSource)
        #expect(Self.update(&table, changed) == 1)
        let fresh = RawDisplaySection.sections(for: changed, decoded: Self.decodedText, summary: Self.localizedSummary)
        #expect(table.sections == fresh)
        #expect(table.sections.filter { !first.contains($0) }.map(\.id) == [BatteryReading.CaptureKey.powerSource])
    }

    /// A new wording, such as another region, builds every section again.
    @Test func newWordingBuildsEverythingAgain() throws {
        let capture = try Fixture.m5PluggedIn10s.reading().redactedRawCapture
        let sectionCount = RawSection.sections(for: capture).count
        var table = RawDisplayTable()
        #expect(Self.update(&table, capture) == sectionCount)
        #expect(Self.update(&table, capture, wording: "ru_RU UTC") == sectionCount)
        #expect(Self.update(&table, capture, wording: "ru_RU UTC") == 0)
    }

    /// A second entry of a class renumbers the first one's title, so that section is built again
    /// even though its dictionary stayed; a dictionary that empties leaves the table.
    @Test func titlesAndEmptyDictionariesFollowTheCapture() {
        func bank(_ voltage: Int64) -> PropertyValue {
            .dictionary([RegistryChildren.classKey: .string(RegistryChildren.bankClass), "Voltage": .int(voltage)])
        }
        func capture(banks: [PropertyValue], adapter: PropertyDictionary) -> PropertyDictionary {
            [
                BatteryReading.CaptureKey.smartBattery: .dictionary([
                    "Voltage": .int(12_000), RegistryChildren.childrenKey: .array(banks),
                ]),
                BatteryReading.CaptureKey.adapterDetails: .dictionary(adapter),
            ]
        }
        let captures = [
            capture(banks: [bank(4_000)], adapter: ["Watts": .int(70)]),
            capture(banks: [bank(4_000), bank(4_001)], adapter: ["Watts": .int(70)]),
            capture(banks: [bank(4_000)], adapter: [:]),
        ]
        var table = RawDisplayTable()
        for capture in captures {
            _ = Self.update(&table, capture)
            let fresh = RawDisplaySection.sections(
                for: capture, decoded: Self.decodedText, summary: Self.localizedSummary)
            #expect(table.sections == fresh)
        }
        #expect(table.sections.map(\.title) == ["AppleSmartBattery", RegistryChildren.bankClass])
    }
}
