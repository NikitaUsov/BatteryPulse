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

    /// Keys the widget will add with the packages that use them (the "tomorrow" phrases with the
    /// configurable widget, two field names with the large size). Their English is checked now,
    /// their Russian once they are in the catalog, which moves them out of this list.
    static let pendingKeys: Set<String> = [
        "Full at %@ tomorrow", "Lasts until %@ tomorrow", "Cycle life used", "Cell balance",
    ]

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
        }
    }

    static let stateKeys = WidgetStateWord.allCases.map(WidgetKeys.state)
    static let attentionKeys = ["High", "Critical", "Fair", "Poor", "Check Battery", "Service Recommended"]

    /// The phrases with a clock time, filled.
    static func timeLines(_ language: Language) throws -> [String] {
        let keys = [
            "Full at %@", "Lasts until about %@", "Updated %@", "Full at %@ tomorrow", "Lasts until %@ tomorrow",
        ]
        return try keys.compactMap { try text($0, language)?.replacingOccurrences(of: "%@", with: language.clock) }
    }

    struct Overflow: CustomStringConvertible {
        var text: String
        var place: String
        var description: String { "\"\(text)\" (\(text.count)) in \(place)" }
    }

    /// Everything over budget, in both languages.
    static func overflows() throws -> [Overflow] {
        var overflows: [Overflow] = []
        func check(_ fits: Bool, _ text: String, _ place: String) {
            if !fits { overflows.append(Overflow(text: text, place: place)) }
        }
        for language in Language.allCases {
            let f = try formatter(language)
            for size in WidgetSize.allCases {
                // The main value.
                for value in [f.percent(100), f.celsius(88.8), f.watts(-88.8, signed: true)] {
                    check(WidgetTextBudget.fits(value, in: .main, size: size), value, "the main value, \(size)")
                }
                // The lines under it.
                for line in try stateKeys.compactMap({ try text($0, language) }) + timeLines(language) {
                    check(WidgetTextBudget.fits(line, in: .line, size: size), line, "a line, \(size)")
                }
                // Small's attention row is a line; elsewhere it is a row. Both with a symbol.
                for words in try attentionKeys.compactMap({ try text($0, language) }) {
                    let slot: WidgetTextBudget.Slot = size == .small ? .line : .row
                    check(WidgetTextBudget.fits(words, symbol: true, in: slot, size: size), words, "attention, \(size)")
                }
                // The details: a label and its value; small's one detail is a line of both.
                for field in BatteryWidgetField.allCases where field != .time {
                    guard let label = try text(WidgetKeys.label(field), language) else { continue }
                    for value in try widestValues(field, language) {
                        let fits =
                            size == .small
                            ? WidgetTextBudget.fits("\(label) \(value)", in: .line, size: size)
                            : WidgetTextBudget.fits(label, value: value, in: .row, size: size)
                        check(fits, "\(label) \(value)", "a detail, \(size)")
                    }
                }
                // A time row is its phrase alone.
                for line in try timeLines(language) where size != .small {
                    check(WidgetTextBudget.fits(line, in: .row, size: size), line, "a time row, \(size)")
                }
                // The empty states.
                for key in ["No battery information", "This Mac has no internal battery."] {
                    let message = try #require(try text(key, language))
                    check(WidgetTextBudget.fits(message, in: .message, size: size), message, "a message, \(size)")
                }
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

    /// The budget is the one the plan names: "Lasts until about %@ tomorrow", with "12:59 PM",
    /// is 35 characters, too long for a line under the main value, so the widget's phrase for an
    /// end tomorrow drops "about".
    @Test func theBudgetCatchesALongLine() {
        let long = "Lasts until about 12:59\u{202F}PM tomorrow"
        #expect(!WidgetTextBudget.fits(long, in: .line, size: .small))
        #expect(WidgetTextBudget.fits("Lasts until 12:59\u{202F}PM tomorrow", in: .line, size: .small))
    }

    @Test func budgetsPerSlot() {
        #expect(WidgetTextBudget.width(.line, .small) == 24)
        #expect(WidgetTextBudget.width(.row, .medium) == 29)
        #expect(WidgetTextBudget.width(.row, .large) == 35)
        // 30 characters fill a line at 0.8; the value of a row never shrinks.
        #expect(WidgetTextBudget.fits(String(repeating: "x", count: 30), in: .line, size: .small))
        #expect(!WidgetTextBudget.fits(String(repeating: "x", count: 31), in: .line, size: .small))
        #expect(WidgetTextBudget.fits("Label", value: String(repeating: "9", count: 24), in: .row, size: .medium))
        #expect(!WidgetTextBudget.fits("Label", value: String(repeating: "9", count: 25), in: .row, size: .medium))
    }
}
