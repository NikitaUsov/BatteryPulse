import Foundation
import Testing

@testable import BatteryCore

/// What VoiceOver reads on the Battery widget (``WidgetAccessibility``), for every family and
/// layout on the M5 captures, in English and in the catalog's Russian: one element per block and
/// row, each with a label that carries its value, no symbol read by its name, and every word that
/// colour or a symbol says also said in words.
struct WidgetAccessibilityTests {
    typealias Language = WidgetTextBudgetTests.Language

    /// A key's text in `language`, as the widget's bundle localizes it.
    static func localize(_ language: Language) -> (String) -> String {
        { key in (try? WidgetTextBudgetTests.text(key, language)).flatMap { $0 } ?? key }
    }

    /// The configurations every family is checked with: Automatic, each main value and visual, and
    /// a Custom layout of every field.
    static let configurations: [BatteryWidgetConfiguration] =
        [BatteryWidgetConfiguration()]
        + BatteryWidgetMain.allCases.map { BatteryWidgetConfiguration(main: $0) }
        + BatteryWidgetVisual.allCases.map { BatteryWidgetConfiguration(visual: $0) }
        + [
            BatteryWidgetConfiguration(layout: .custom, details: BatteryWidgetField.allCases),
            BatteryWidgetConfiguration(
                layout: .custom, statusLines: [], details: [.state, .time, .lowPowerMode, .condition], time: .timeLeft,
                colors: .monochrome, updateTime: .always),
            BatteryWidgetConfiguration(layout: .custom, main: .batteryPower, details: []),
        ]

    /// The captures, and the same Mac in the attention row's states.
    static func snapshots() throws -> [BatterySnapshot] {
        var snapshots = try Fixture.allCases.map { try $0.snapshot() }
        var serviced = try Fixture.m5OnBattery.snapshot()
        serviced.healthCondition = "Service Recommended"
        var hot = try Fixture.m5Charging.snapshot()
        hot.thermalState = .critical
        var unknownCondition = try Fixture.m5OnBatterySMC.snapshot()
        unknownCondition.healthCondition = "Permanent Battery Failure"
        snapshots += [serviced, hot, unknownCondition]
        return snapshots
    }

    struct Case: CustomStringConvertible {
        var size: WidgetSize
        var configuration: BatteryWidgetConfiguration
        var snapshot: BatterySnapshot
        var language: Language
        var plan: WidgetLayoutPlan
        var description: String {
            "\(size) \(configuration.layout) \(configuration.main) \(language) \(snapshot.chargeState)"
                + " \(snapshot.healthCondition ?? "-") \(snapshot.thermalState.map { "\($0)" } ?? "-")"
        }
    }

    static func cases() throws -> [Case] {
        var cases: [Case] = []
        for language in Language.allCases {
            let formatter = try WidgetTextBudgetTests.formatter(language)
            for snapshot in try snapshots() {
                let entry = try #require(WidgetTimelinePlan(snapshot: snapshot, at: snapshot.timestamp).entries.first)
                for size in WidgetSize.allCases {
                    for configuration in configurations {
                        let plan = WidgetLayoutPlan.make(
                            size: size, configuration: configuration, snapshot: snapshot, entry: entry,
                            formatter: formatter, timeZone: TimeZone(secondsFromGMT: 3 * 3600)!)
                        cases.append(
                            Case(
                                size: size, configuration: configuration, snapshot: snapshot, language: language,
                                plan: plan))
                    }
                }
            }
        }
        return cases
    }

    /// Parts of the SF Symbols' names the widget draws ("battery.75percent"), and VoiceOver's names
    /// for the battery symbols ("Three-Quarter-Charged Battery"), which no label may contain.
    static var symbolWords: Regex<Substring> {
        #/battery\.\d|percent|exclamationmark|thermometer|-charged battery|bolt/#
    }

    @Test func everyElementHasALabelWithItsValue() throws {
        let cases = try Self.cases()
        #expect(cases.count > 500)
        for c in cases {
            let localize = Self.localize(c.language)
            let elements = WidgetAccessibility.elements(c.plan)
            #expect(!elements.isEmpty, "\(c)")
            for element in elements {
                if let text = element.text(localize) {
                    #expect(!text.trimmingCharacters(in: .whitespaces).isEmpty, "\(c)")
                    #expect(!text.contains("%@"), "\(c): \(text)")
                    #expect(text.lowercased().firstMatch(of: Self.symbolWords) == nil, "\(c): \(text)")
                } else {
                    #expect(element == .timeLeft(until: Self.timeLeftEnd(c.plan) ?? .distantPast), "\(c)")
                }
            }
            guard case .battery(let layout) = c.plan else { continue }
            // The charge's element comes first after a panel's name and carries the charge and the
            // state, whatever the main value.
            let charge = try #require(elements.first { $0 != WidgetPanel.battery.spokenLabel }?.text(localize))
            #expect(charge.contains(layout.level.text), "\(c): \(charge)")
            #expect(charge.contains(layout.level.state.phrase.text(localize)), "\(c): \(charge)")
            if layout.main.kind != .charge {
                #expect(elements.contains { $0.text(localize)?.hasSuffix(", " + layout.main.text) == true }, "\(c)")
            }
        }
    }

    /// One element per block, line and row the plan shows; 0.6.1's medium widget made nine flat
    /// elements (the symbol and eight texts), its small one three.
    @Test func oneElementPerBlockAndRow() throws {
        for c in try Self.cases() {
            let elements = WidgetAccessibility.elements(c.plan)
            switch c.plan {
            case .empty:
                #expect(elements.count == 1, "\(c)")
            case .battery(let layout):
                let headings = layout.panelHeadings ? (layout.powerDetails.isEmpty ? 1 : 2) : 0
                let main = layout.main.kind == .charge ? 0 : 1
                let lines = layout.lines.filter { if case .state = $0 { false } else { true } }.count
                let rows = layout.details.count + layout.powerDetails.count
                #expect(elements.count == headings + 1 + main + lines + rows, "\(c)")
            }
        }
        // The medium widget of 0.6.1's look, with a pack temperature: the charge, the time line
        // and three rows.
        let snapshot = try Fixture.m5OnBatterySMC.snapshot()
        let entry = try #require(WidgetTimelinePlan(snapshot: snapshot, at: snapshot.timestamp).entries.first)
        let formatter = BatteryFormatter(locale: Locale(identifier: "en_US"))
        let medium = WidgetLayoutPlan.make(
            size: .medium, configuration: BatteryWidgetConfiguration(), snapshot: snapshot, entry: entry,
            formatter: formatter, timeZone: .gmt)
        let texts = WidgetAccessibility.elements(medium).compactMap { $0.text { $0 } }
        #expect(texts.count == 5)
        #expect(texts.first?.hasPrefix("Battery charge: ") == true)
        #expect(texts.first?.hasSuffix(", On battery") == true)
        #expect(texts.dropFirst().first?.hasPrefix("Lasts until about ") == true)
        #expect(
            texts.dropFirst(2).map { String($0.prefix { $0 != "," }) } == [
                "Maximum capacity", "Cycle count", "Temperature",
            ])
    }

    /// Each row reads "label, value" in the plan's order; a time row reads its phrase alone.
    @Test func eachRowIsLabelThenValue() throws {
        for c in try Self.cases() {
            guard case .battery(let layout) = c.plan else { continue }
            let localize = Self.localize(c.language)
            let details = layout.details + layout.powerDetails
            let headings = WidgetPanel.allCases.map(\.spokenLabel)
            let elements = WidgetAccessibility.elements(c.plan).filter { !headings.contains($0) }
            #expect(Array(elements.suffix(details.count)) == details.map(\.spokenLabel), "\(c)")
            for detail in layout.details + layout.powerDetails {
                guard case .row(let row) = detail else { continue }
                let text = row.spokenLabel.text(localize)
                switch row.value {
                case .time(let time):
                    #expect(row.spokenLabel == time.spokenLabel)
                case .text(let value):
                    #expect(text == localize(row.field.labelKey) + ", " + value, "\(c)")
                default:
                    #expect(text?.hasPrefix(localize(row.field.labelKey) + ", ") == true, "\(c)")
                }
            }
        }
    }

    /// The state and the attention row are said in words, so colour and symbols are never the only
    /// signal.
    @Test func theStateAndTheAttentionRowAreInWords() throws {
        for c in try Self.cases() {
            guard case .battery(let layout) = c.plan else { continue }
            let localize = Self.localize(c.language)
            let labels = WidgetAccessibility.elements(c.plan).compactMap { $0.text(localize) }.joined(separator: " | ")
            #expect(labels.contains(layout.level.state.phrase.text(localize)), "\(c)")
            guard let attention = WidgetAttention(c.snapshot) else { continue }
            let words =
                switch attention {
                case .heat(let state): state.phrase.text(localize)
                case .condition(let condition): condition.phrase.text(localize)
                }
            #expect(labels.contains(words), "\(c): \(labels)")
        }
    }

    /// Every key a label uses is in the catalog with its Russian.
    @Test func everyKeyIsTranslated() throws {
        var keys: Set<String> = []
        for c in try Self.cases() where c.language == .english {
            keys.formUnion(WidgetAccessibility.elements(c.plan).flatMap(\.keys))
        }
        keys.formUnion(WidgetPanel.allCases.flatMap(\.spokenLabel.keys))
        keys.formUnion(BatteryWidgetField.allCases.map(\.labelKey))
        keys.formUnion(WidgetStateWord.allCases.flatMap(\.phrase.keys))
        keys.formUnion(ThermalState.allCases.flatMap(\.phrase.keys))
        #expect(keys.count > 30)
        for key in keys {
            let russian = try WidgetTextBudgetTests.text(key, .russian)
            #expect(russian?.isEmpty == false, "\(key)")
        }
    }

    /// The labels follow the words the widget shows: its field labels and state words are the keys
    /// the plan's tests read the widget by.
    @Test func theKeysAreTheWidgetsWords() {
        for field in BatteryWidgetField.allCases where field != .time {
            #expect(field.labelKey == WidgetKeys.label(field))
        }
        #expect(BatteryWidgetField.time.labelKey == "Time to full or empty")
        for word in WidgetStateWord.allCases {
            #expect(word.phrase == .key(WidgetKeys.state(word)))
        }
    }

    @Test func phrasesFillTheirPlaceholdersInTurn() {
        let phrase = WidgetPhrase.key("Battery charge: %@, %@", [.verbatim("70\u{00A0}%"), .key("On battery")])
        #expect(phrase.text { $0 } == "Battery charge: 70\u{00A0}%, On battery")
        // Each key through the language's table, its arguments filled in after.
        let shouted = phrase.text { $0.uppercased() }
        #expect(shouted == "BATTERY CHARGE: 70\u{00A0}%, ON BATTERY")
        #expect(phrase.keys == ["Battery charge: %@, %@", "On battery"])
        // Missing arguments leave the placeholder; extra ones are dropped.
        #expect(WidgetPhrase.key("Updated %@").text { $0 } == "Updated %@")
        #expect(WidgetPhrase.key("Charging", [.verbatim("x")]).text { $0 } == "Charging")
        let label = WidgetSpokenLabel.phrases([.key("Cycle count"), .verbatim("48")])
        #expect(label.text { $0 } == "Cycle count, 48")
        #expect(WidgetSpokenLabel.timeLeft(until: .distantFuture).text { $0 } == nil)
    }

    /// A sentence keeps its own stop: the next phrase follows it after a space, never ".,".
    @Test func aSentenceEndsWithItsOwnStop() {
        let noBattery = WidgetEmptyReason.noBattery.spokenLabel
        #expect(noBattery.text { $0 } == "This Mac has no internal battery. Try the Accessories widget")
        let russian = noBattery.text(Self.localize(.russian))
        #expect(russian?.contains(".,") == false)
        #expect(russian?.contains(". ") == true)
        // Only a catalog sentence: a name that ends with a stop is still followed by a comma.
        let named = WidgetSpokenLabel.phrases([.verbatim("Keyboard No."), .verbatim("7")])
        #expect(named.text { $0 } == "Keyboard No., 7")
    }

    /// The time left's end, when the plan counts one down.
    static func timeLeftEnd(_ plan: WidgetLayoutPlan) -> Date? {
        guard case .battery(let layout) = plan else { return nil }
        for line in layout.lines {
            if case .time(let time) = line, time.form == .timeLeft { return time.end }
        }
        for detail in layout.details + layout.powerDetails {
            if case .row(let row) = detail, case .time(let time) = row.value, time.form == .timeLeft { return time.end }
        }
        return nil
    }
}
