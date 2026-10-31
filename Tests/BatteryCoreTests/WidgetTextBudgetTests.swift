import Foundation
import Testing

@testable import BatteryCore

/// Every text the widget shows, in English and Russian, filled with its widest value, fits its
/// place (``WidgetTextBudget``). A reused key over budget fails here until the widget gets a
/// widget-only short key for it, with its Russian.
struct WidgetTextBudgetTests {
    private static let repository = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()

    private struct Catalog: Decodable {
        struct Entry: Decodable {
            struct Localization: Decodable {
                struct StringUnit: Decodable {
                    var value: String
                }
                var stringUnit: StringUnit
            }
            var localizations: [String: Localization]?
        }
        var strings: [String: Entry]
    }

    private static let catalog: Result<Catalog, any Error> = Result {
        let url = repository.appendingPathComponent("Resources/Localizable.xcstrings")
        return try JSONDecoder().decode(Catalog.self, from: Data(contentsOf: url))
    }

    /// Keys the widget will add with the packages that use them; none now. Their English is checked
    /// at once, their Russian once they are in the catalog, which moves them out of this list.
    static let pendingKeys: Set<String> = []

    enum Language: String, CaseIterable {
        case english, russian

        var locale: Locale { Locale(identifier: self == .english ? "en_US" : "ru_RU") }
        /// The widest clock time: 12-hour in English, 24-hour in Russian.
        var clock: String { self == .english ? "12:59\u{202F}PM" : "23:59" }
    }

    /// `key` in `language`; `nil` for a pending key's Russian.
    static func text(_ key: String, _ language: Language) throws -> String? {
        if language == .english { return key }
        if pendingKeys.contains(key) { return nil }
        let entry = try #require(try catalog.get().strings[key], "\"\(key)\" isn't in the catalog")
        return try #require(entry.localizations?["ru"]?.stringUnit.value, "No Russian for \"\(key)\"")
    }

    static func formatter(_ language: Language) throws -> BatteryFormatter {
        guard language == .russian else { return BatteryFormatter(locale: language.locale) }
        func symbol(_ key: String) throws -> String { try #require(try text(key, .russian)) }
        return BatteryFormatter(
            locale: language.locale,
            symbols: .init(
                watts: try symbol("W"), milliampHours: try symbol("mAh"), volts: try symbol("V"),
                millivolts: try symbol("mV"), milliamps: try symbol("mA"), amps: try symbol("A")))
    }

    /// Each field's widest value: a word's key, or formatted numbers.
    static func widestValues(_ field: BatteryWidgetField, _ language: Language) throws -> [String] {
        let f = try formatter(language)
        func words(_ keys: [String]) throws -> [String] { try keys.compactMap { try text($0, language) } }
        return switch field {
        case .state: try words(stateKeys)
        // A time row is its phrase alone; the phrases are checked as lines.
        case .time: []
        case .maximumCapacity, .cycleLifeUsed: [f.percent(100), f.percent(999)]
        // An abnormal condition goes to the attention row, so a condition row reads Normal.
        case .condition: try words(["Normal"])
        case .cycleCount: [9_999.formatted(.number.locale(f.locale))]
        case .temperature: [f.celsius(88.8)]
        case .adapter: [f.watts(240, fractionDigits: 0)]
        case .systemLoad, .adapterInput: [f.watts(88.8)]
        case .batteryPower: [f.watts(-88.8, signed: true)]
        case .lowPowerMode: try words(["On", "Off"])
        case .remainingCapacity: [f.milliampHours(9_999)]
        case .cellBalance: [f.millivolts(999)]
        case .voltage: [f.volts(millivolts: 13_050)]
        case .systemChargeLimit: try words(["Reached"])
        }
    }

    static let stateKeys = WidgetStateWord.allCases.map(WidgetKeys.state)
    static let conditions: [WidgetCondition] = [.fair, .poor, .checkBattery, .serviceRecommended]

    /// The phrases with a clock time, filled, each with the shorter form a one-line place falls
    /// back on.
    static func timeLines(_ language: Language) throws -> [[String]] {
        let times = [
            WidgetTimeText(direction: .full, end: .now, form: .clock("", tomorrow: false)),
            WidgetTimeText(direction: .empty, end: .now, form: .clock("", tomorrow: false)),
            WidgetTimeText(direction: .full, end: .now, form: .clock("", tomorrow: true)),
            WidgetTimeText(direction: .empty, end: .now, form: .clock("", tomorrow: true)),
        ]
        let keys = times.map { [$0.spokenLabel.keys[0], $0.shortKey] } + [["Updated %@"]]
        return try keys.map { choices in
            try Self.choices(choices, language).map { $0.replacingOccurrences(of: "%@", with: language.clock) }
        }
    }

    struct Overflow: CustomStringConvertible {
        var text: String
        var place: String
        var description: String { "\"\(text)\" (\(Int(WidgetTextBudget.width(text).rounded())) pt) in \(place)" }
    }

    /// `keys` in `language`, the full words first, then the shorter ones the widget falls back on.
    static func choices(_ keys: [String?], _ language: Language) throws -> [String] {
        try keys.compactMap { $0 }.compactMap { try text($0, language) }
    }

    /// A tier's symbol may come before the value: maximum capacity's and a condition's.
    static func hasCue(_ field: BatteryWidgetField) -> Bool {
        field == .maximumCapacity || field == .condition
    }

    /// Everything over budget, in both languages.
    static func overflows() throws -> [Overflow] {
        typealias Budget = WidgetTextBudget
        var overflows: [Overflow] = []
        func check(_ fits: Bool, _ text: String, _ place: String) {
            if !fits { overflows.append(Overflow(text: text, place: place)) }
        }
        /// One of `choices` fits on one line `place` points wide after `before` points.
        func oneLine(_ choices: [String], after before: Double = 0, _ place: Double) -> Bool {
            choices.contains { Budget.fits(before + Budget.width($0), in: place) }
        }
        for language in Language.allCases {
            let f = try formatter(language)
            for size in WidgetSize.allCases {
                // The main value, the one place that may shrink.
                for value in [f.percent(100), f.celsius(88.8), f.watts(-88.8, signed: true)] {
                    check(Budget.fitsMain(value), value, "the main value, \(size)")
                }
                // The lines under it, with a phrase's shorter form where its own doesn't fit.
                for line in try stateKeys.compactMap({ try text($0, language) }).map({ [$0] }) + timeLines(language) {
                    check(oneLine(line, Budget.lineWidth(size)), line.last ?? "", "a line, \(size)")
                }
                // The attention row: small's line and medium's row hold one line, with the
                // condition's shorter words where its own don't fit; a tile has two lines.
                let attentions =
                    try ThermalState.allCases.filter { $0 == .serious || $0 == .critical }.map {
                        try choices($0.phrase.keys, language)
                    } + conditions.map { try choices($0.phrase.keys + [$0.shortKey], language) }
                for words in attentions {
                    switch size {
                    case .small, .medium:
                        let fits = oneLine(words, after: Budget.symbolWidth, Budget.detailWidth(size))
                        check(fits, words.last ?? "", "attention, \(size)")
                    case .large, .extraLarge, .extraLargePortrait:
                        let lines = Budget.lines(words[0], width: Budget.detailWidth(size), .title3)
                        check(lines <= 2, words[0], "an attention tile, \(size)")
                    }
                }
                // The details: a label and its value on one line, with the field's shorter label
                // where its own doesn't fit, or a word that says what it is alone; a tile's label
                // on one line over its value on up to two.
                for field in BatteryWidgetField.allCases where field != .time {
                    let labels = try choices([WidgetKeys.label(field), field.shortLabelKey], language)
                    for value in try widestValues(field, language) {
                        let place = Budget.detailWidth(size)
                        switch size {
                        case .small, .medium:
                            let before =
                                Budget.width(value, monospacedDigits: size == .medium)
                                + (hasCue(field) ? Budget.cueWidth : 0) + Budget.gap(size)
                            let alone = (field == .state || field == .condition) && oneLine([value], place)
                            check(
                                oneLine(labels, after: before, place) || alone, "\(labels.last ?? "") \(value)",
                                "a detail, \(size)")
                        case .large, .extraLarge, .extraLargePortrait:
                            check(oneLine([labels[0]], place), labels[0], "a tile's label, \(size)")
                            check(Budget.lines(value, width: place, .title3) <= 2, value, "a tile's value, \(size)")
                        }
                    }
                }
                // Medium's time row is its phrase alone, on one line.
                for line in try timeLines(language) where size == .medium {
                    check(oneLine(line, Budget.detailWidth(size)), line.last ?? "", "a time row, \(size)")
                }
                // The Accessories widget's state under its lowest accessory's name, a line of the
                // whole width, with its shorter words where its own don't fit.
                for status in AccessoryWidgetStatus.allCases {
                    let words = try choices(status.phrase.keys + [status.shortKey], language)
                    check(oneLine(words, Budget.contentWidth(size)), words.last ?? "", "an accessory's state, \(size)")
                }
            }
        }
        // The empty states: the Russian takes as many lines as the English, counted with the
        // margin, and the English without it. A message with shorter words shows the first that
        // fits one line.
        let messages: [(keys: [String?], style: Budget.Style)] = [
            (
                [WidgetEmptyReason.noInformation.spokenLabel.keys[0], WidgetEmptyReason.noInformation.shortMessageKey],
                .caption
            ),
            (["This Mac has no internal battery."], .caption),
            (["Try the Accessories widget"], .caption2),
            (["No accessories with batteries connected"], .caption),
            (["All accessories are fully charged"], .caption),
        ]
        for size in WidgetSize.allCases {
            let place = Budget.contentWidth(size)
            for message in messages {
                func shown(_ language: Language) throws -> Int {
                    let words = try choices(message.keys, language)
                    let width = language == .russian ? place * Budget.margin : place
                    let lines = words.map { Budget.lines($0, width: width, message.style) }
                    return lines.first { $0 == 1 } ?? lines.last ?? 0
                }
                let english = try shown(.english)
                let russian = try shown(.russian)
                let text = try text(message.keys[0] ?? "", .russian) ?? ""
                check(russian == english, text, "a message of \(english) lines, \(size)")
            }
        }
        return overflows
    }

    @Test func everyWidgetTextFitsItsPlace() throws {
        let overflows = try Self.overflows()
        #expect(overflows.isEmpty, "Over budget; give each a widget-only short key: \(overflows)")
    }

    /// A pending key that reached the catalog moves out of ``pendingKeys``, so its Russian is
    /// checked.
    @Test func pendingKeysAreNotInTheCatalogYet() throws {
        let present = Self.pendingKeys.filter { (try? Self.catalog.get().strings[$0]) != nil }
        #expect(present.isEmpty, "Remove from pendingKeys: \(present.sorted())")
    }

    /// The table matches the text of CI's pictures (2x, so half their ink widths plus the side
    /// bearings) within 2 %, in both languages: the medium automatic and small service
    /// recommended scenes of 0.7.
    @Test(arguments: [
        ("Service Recommended", Language.english, 110.5), ("Service Recommended", .russian, 151.0),
        ("Temperature", .english, 61.5), ("Temperature", .russian, 66.0), ("Condition", .english, 46.0),
        ("Condition", .russian, 53.5), ("On battery", .russian, 85.5), ("Maximum capacity", .english, 89.5),
    ])
    func theTableMatchesThePictures(key: String, language: Language, measured: Double) throws {
        let text = try #require(try Self.text(key, language))
        let width = WidgetTextBudget.width(text)
        #expect(abs(width - measured) <= measured * 0.02, "\(text): \(width) against \(measured)")
    }

    /// What 0.7's pictures showed before the parity fixes: the full Russian label beside 100% in
    /// medium's row, the condition's full words beside small's symbol and the 0.7 Russian
    /// message without a battery took more than their places, so they shrank or wrapped.
    @Test func theBudgetCatchesWhatThePicturesShowed() throws {
        typealias Budget = WidgetTextBudget
        let maximumCapacity = try #require(try Self.text("Maximum capacity", .russian))
        let row = Budget.width(maximumCapacity) + Budget.gap(.medium) + Budget.width("100%", monospacedDigits: true)
        #expect(!Budget.fits(row, in: Budget.detailWidth(.medium)))
        #expect(
            Budget.fits(Budget.width("Maximum capacity") + Budget.gap(.medium) + 26, in: Budget.detailWidth(.medium)))
        let service = try #require(try Self.text("Service Recommended", .russian))
        #expect(!Budget.fits(Budget.symbolWidth + Budget.width(service), in: Budget.lineWidth(.small)))
        #expect(Budget.fits(Budget.symbolWidth + Budget.width("Service Recommended"), in: Budget.lineWidth(.small)))
        // 0.7's first Russian, "this Mac has no internal battery", took 3 lines against 2.
        #expect(Budget.lines("This Mac has no internal battery.", width: Budget.contentWidth(.small)) == 2)
    }

    @Test func linesBreakAtSpaces() {
        typealias Budget = WidgetTextBudget
        #expect(Budget.lines("", width: 10) == 1)
        #expect(Budget.lines("word", width: 1) == 1)
        #expect(Budget.lines("a b", width: 1) == 2)
        #expect(Budget.lines("a b", width: Budget.width("a b")) == 1)
        // A no-break space keeps a number with its unit.
        #expect(Budget.lines("12\u{00A0}W", width: 1) == 1)
        #expect(Budget.fits(98, in: 100) && !Budget.fits(98.1, in: 100))
        // The main value shrinks to 0.7: ten characters fill it.
        #expect(Budget.fitsMain(String(repeating: "8", count: 10)))
        #expect(!Budget.fitsMain(String(repeating: "8", count: 11)))
    }
}
