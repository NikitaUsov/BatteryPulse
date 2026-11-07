import Foundation
import Testing

@testable import BatteryCore

/// Health's summary (``HealthSummary``): the condition macOS reports, the maximum capacity and the
/// cycles, label beside value, in English and in the catalog's Russian; and Clear's badge, which
/// names a low capacity as a fact and says "Service Recommended" only when macOS does.
@Suite struct HealthSummaryTests {
    typealias Language = WidgetTextBudgetTests.Language

    /// A key's text in `language`; a key missing from the catalog fails the test.
    static func localize(_ language: Language) -> (String) -> String {
        { key in (try? WidgetTextBudgetTests.text(key, language)).flatMap { $0 } ?? key }
    }

    /// The rows as label and value, in `language`.
    static func rows(_ s: BatterySnapshot, _ language: Language) throws -> [(label: String, value: String)] {
        let f = try WidgetTextBudgetTests.formatter(language)
        let localize = Self.localize(language)
        return HealthSummary.rows(for: s, formatter: f).map { (localize($0.labelKey), $0.valueText(localize)) }
    }

    static func badge(_ s: BatterySnapshot, _ language: Language) throws -> String? {
        HealthSummary.warningText(
            for: s, formatter: try WidgetTextBudgetTests.formatter(language), Self.localize(language))
    }

    /// `english` in `language`: the catalog's words for a key, the text itself for none.
    static func words(_ english: String, _ language: Language) -> String {
        localize(language)(english)
    }

    /// `format` with its placeholders filled in turn by `values`.
    static func fill(_ format: String, _ values: String...) -> String {
        var text = format
        for value in values {
            guard let placeholder = text.range(of: "%@") else { break }
            text.replaceSubrange(placeholder, with: value)
        }
        return text
    }

    /// A battery with `condition`, a maximum capacity of `capacity` percent of a 5,760 mAh design,
    /// and `cycles` out of `rated`.
    static func snapshot(
        condition: String? = nil, capacity: Double = 100, cycles: Int? = 52, rated: Int? = 1000
    ) -> BatterySnapshot {
        var s = BatterySnapshot(timestamp: Fixture.timestamp)
        s.healthCondition = condition
        s.designCapacityMAh = 5760
        s.nominalChargeCapacityMAh = Int((5760 * capacity / 100).rounded())
        s.cycleCount = cycles
        s.designCycleCount = rated
        return s
    }

    static let labels = ["Condition", "Maximum capacity", "Cycle count"]

    // MARK: The rows

    /// Every capture of a Mac gives the three facts in order, as macOS reports them: its condition
    /// ("Normal", since the M5 publishes no condition key and the hand-written captures say
    /// "Good"), the capped capacity, and the cycles out of the rated 1,000.
    @Test(arguments: Fixture.allCases)
    func everyMacCaptureGivesTheThreeFactsInOrder(_ fixture: Fixture) throws {
        let s = try fixture.snapshot()
        let health = try #require(s.healthPercent)
        let cycles = try #require(s.cycleCount)
        #expect(s.designCycleCount == 1000)
        for language in Language.allCases {
            let rows = try Self.rows(s, language)
            #expect(rows.map(\.label) == Self.labels.map { Self.words($0, language) })
            let locale = language.locale
            let count = cycles.formatted(.number.locale(locale))
            let rated = 1000.formatted(.number.locale(locale))
            #expect(
                rows.map(\.value) == [
                    Self.words("Normal", language), try WidgetTextBudgetTests.formatter(language).percent(health),
                    Self.fill(Self.words("%@ of %@", language), count, rated),
                ])
        }
        #expect(try Self.rows(s, .english)[2].value == "\(cycles) of 1,000")
    }

    /// No condition and an empty one read Normal, as macOS shows them; a condition macOS names is
    /// its own word, and one the catalog has no word for is shown as macOS reports it.
    @Test(arguments: [
        (nil as String?, "Normal", true),
        ("", "Normal", true),
        ("Normal", "Normal", true),
        ("Good", "Normal", true),
        ("Fair", "Fair", true),
        ("Poor", "Poor", true),
        ("Check Battery", "Check Battery", true),
        ("Service Recommended", "Service Recommended", true),
        ("Permanent Battery Failure", "Permanent Battery Failure", false),
    ])
    func theConditionIsMacOSsWord(condition: String?, word: String, isCatalogKey: Bool) throws {
        let s = Self.snapshot(condition: condition)
        #expect(try Self.rows(s, .english).first?.value == word)
        let russian = try Self.rows(s, .russian).first?.value
        #expect(russian == (isCatalogKey ? try WidgetTextBudgetTests.text(word, .russian) : word))
        #expect(isCatalogKey == HealthSummary.catalogKeys.contains(word))
    }

    /// Through the parser: the M5 publishes no condition key, and an empty one reads the same.
    @Test func noConditionKeyAndAnEmptyOneReadNormal() throws {
        var capture = try fixtureDictionary(Fixture.m5OnBattery.rawValue)
        var powerSource = try #require(capture[BatteryReading.CaptureKey.powerSource]?.dictionaryValue)
        #expect(powerSource["BatteryHealthCondition"] == nil)
        let absent = BatteryReading(rawCapture: capture, timestamp: Fixture.timestamp).snapshot
        powerSource["BatteryHealthCondition"] = .string("")
        capture[BatteryReading.CaptureKey.powerSource] = .dictionary(powerSource)
        let empty = BatteryReading(rawCapture: capture, timestamp: Fixture.timestamp).snapshot
        for s in [absent, empty] {
            #expect(try Self.rows(s, .english).first?.value == "Normal")
            #expect(try Self.badge(s, .english) == nil)
        }
    }

    /// A new battery holds more than its design capacity; the summary caps it at 100 %, as System
    /// Settings does.
    @Test func aCapacityOverItsDesignShows100() throws {
        let s = Self.snapshot(capacity: 104.3)
        #expect(try #require(s.capacityToDesignPercent) > 104)
        #expect(try Self.rows(s, .english)[1].value == "100%")
        #expect(try Self.rows(s, .russian)[1].value == "100%")
        // The M5's captures, whose design ratio is about 104 %.
        let m5 = try Fixture.m5Charging.snapshot()
        #expect(try #require(m5.capacityToDesignPercent) > 100)
        #expect(try Self.rows(m5, .english)[1].value == "100%")
    }

    /// Without a rated count (none, or 0 as a Mac can report it), the count stands alone.
    @Test(arguments: [nil as Int?, 0])
    func withoutARatedCountTheCountStandsAlone(rated: Int?) throws {
        let s = Self.snapshot(cycles: 1234, rated: rated)
        #expect(try Self.rows(s, .english)[2].value == "1,234")
        #expect(try Self.rows(s, .russian)[2].value == 1234.formatted(.number.locale(Language.russian.locale)))
    }

    /// A fact the battery doesn't report has no row; the condition always has one.
    @Test func aFactTheBatteryLacksHasNoRow() throws {
        #expect(try Self.rows(BatterySnapshot(timestamp: Fixture.timestamp), .english).map(\.label) == ["Condition"])
        var noCycles = Self.snapshot()
        noCycles.cycleCount = nil
        #expect(try Self.rows(noCycles, .english).map(\.label) == ["Condition", "Maximum capacity"])
        var noCapacity = Self.snapshot()
        noCapacity.nominalChargeCapacityMAh = nil
        #expect(try Self.rows(noCapacity, .english).map(\.label) == ["Condition", "Cycle count"])
    }

    // MARK: Clear's badge

    /// Q8-4: a capacity under 80 % that macOS calls Normal is a fact, not "Service Recommended":
    /// the summary says Normal and the capacity, and the badge says the capacity is below 80 %.
    @Test(arguments: [nil as String?, "Normal", "Good", ""])
    func aLowCapacityMacOSCallsNormalIsAFactNotServiceRecommended(condition: String?) throws {
        let s = Self.snapshot(condition: condition, capacity: 79)
        #expect(BatteryPresentation.healthTier(for: s) == .low)
        #expect(try Self.rows(s, .english).map(\.value) == ["Normal", "79%", "52 of 1,000"])
        #expect(try Self.badge(s, .english) == "Maximum capacity below 80%")
        let below = try #require(try WidgetTextBudgetTests.text("Maximum capacity below %@", .russian))
        #expect(try Self.badge(s, .russian) == Self.fill(below, "80%"))
        for language in Language.allCases {
            let words = try Self.rows(s, language).map(\.value) + [try #require(try Self.badge(s, language))]
            let service = Self.words("Service Recommended", language)
            #expect(!words.contains { $0.contains(service) }, "\(language): \(words)")
        }
    }

    /// The condition macOS reports wins, whatever the capacity: its word is the badge, and one the
    /// catalog has no word for reads as macOS reports it.
    @Test(arguments: [
        ("Service Recommended", 74.6),
        ("Service Recommended", 92),
        ("Fair", 90),
        ("Poor", 70),
        ("Check Battery", 100),
        ("Permanent Battery Failure", 95),
    ])
    func theBadgeIsTheConditionMacOSReports(condition: String, capacity: Double) throws {
        let s = Self.snapshot(condition: condition, capacity: capacity)
        #expect(BatteryPresentation.healthTier(for: s) != .normal)
        for language in Language.allCases {
            let word = HealthSummary.catalogKeys.contains(condition) ? Self.words(condition, language) : condition
            #expect(try Self.badge(s, language) == word)
        }
    }

    /// Nothing warns at 80 % and above with a Normal condition, or without a capacity: no badge.
    @Test(arguments: [80.0, 80.4, 100, 104.3])
    func nothingWarnsFrom80Percent(capacity: Double) throws {
        let s = Self.snapshot(condition: "Normal", capacity: capacity)
        #expect(BatteryPresentation.healthTier(for: s) == .normal)
        #expect(try Self.badge(s, .english) == nil)
        var unknown = s
        unknown.nominalChargeCapacityMAh = nil
        #expect(try Self.badge(unknown, .english) == nil)
    }

    /// The badge warns exactly where the colour tier does, at
    /// ``BatteryPresentation/capacityWarningPercent``, and names that number.
    @Test func theBadgeNamesTheTiersThreshold() throws {
        let threshold = BatteryPresentation.capacityWarningPercent
        #expect(threshold == 80)
        let below = Self.snapshot(capacity: threshold - 0.1)
        #expect(BatteryPresentation.healthTier(for: below) == .low)
        let f = try WidgetTextBudgetTests.formatter(.english)
        #expect(try Self.badge(below, .english) == "Maximum capacity below \(f.percent(threshold))")
    }

    // MARK: The catalog

    /// The snapshots every case above reads, the captures and Demo Mode's scenes with them.
    static func snapshots() throws -> [BatterySnapshot] {
        var snapshots = try Fixture.allCases.map { try $0.snapshot() }
        snapshots += DemoScenario.allCases.compactMap { $0.battery?.reading(at: Fixture.timestamp).snapshot }
        for condition in [nil, "", "Fair", "Poor", "Check Battery", "Service Recommended", "Permanent Battery Failure"]
        {
            for capacity in [74.6, 79, 100] {
                snapshots.append(Self.snapshot(condition: condition, capacity: capacity))
                snapshots.append(Self.snapshot(condition: condition, capacity: capacity, rated: nil))
            }
        }
        return snapshots
    }

    /// The list the catalog's check reads is every key the rows and the badge use, each with its
    /// Russian; placeholders are `%@` only, and none is a counted phrase.
    @Test func everyKeyIsListedAndTranslated() throws {
        let f = try WidgetTextBudgetTests.formatter(.english)
        var used: Set<String> = []
        for s in try Self.snapshots() {
            for row in HealthSummary.rows(for: s, formatter: f) {
                used.insert(row.labelKey)
                used.formUnion(row.value.keys)
            }
            used.formUnion(HealthSummary.warning(for: s, formatter: f)?.keys ?? [])
        }
        #expect(used == HealthSummary.catalogKeys)
        for key in HealthSummary.catalogKeys {
            #expect(key.replacing("%@", with: "").firstMatch(of: #/%/#) == nil, "\(key)")
            #expect(try WidgetTextBudgetTests.text(key, .russian)?.isEmpty == false, "\(key)")
        }
    }
}
