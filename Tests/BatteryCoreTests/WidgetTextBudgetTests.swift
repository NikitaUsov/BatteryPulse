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
        // Capped at 100% like System Settings.
        case .maximumCapacity: [f.percent(100)]
        case .cycleLifeUsed: [f.percent(100), f.percent(999)]
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
        case .averageDrain: try perHour(f.percent(99.9, fractionDigits: 1), language)
        // The system's own text, one field in a line's place (hours, or minutes under an hour).
        case .timeOnBattery:
            [systemDuration(minutes: 59, [.minutes], language), systemDuration(minutes: 23 * 60, [.hours], language)]
        }
    }

    /// A duration in full words, as the system's self-updating offset writes it ("59 minutes")
    /// [estimate: Foundation's own wide units in the language].
    static func systemDuration(minutes: Int, _ units: Set<Duration.UnitsFormatStyle.Unit>, _ language: Language)
        -> String
    {
        var style = Duration.UnitsFormatStyle(allowedUnits: units, width: .wide)
        style.locale = language.locale
        return Duration.seconds(minutes * 60).formatted(style)
    }

    /// "%@ per hour" with `value`, in `language`.
    static func perHour(_ value: String, _ language: Language) throws -> [String] {
        try [text("%@ per hour", language)].compactMap { $0?.replacingOccurrences(of: "%@", with: value) }
    }

    /// The time on battery in a tile, which has room for both fields.
    static func timeOnBatteryTile(_ language: Language) -> String {
        systemDuration(minutes: 23 * 60 + 59, [.hours, .minutes], language)
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
        /// The text's width, when it isn't in the caption.
        var points: Double?
        var description: String {
            "\"\(text)\" (\(Int((points ?? WidgetTextBudget.width(text)).rounded())) pt) in \(place)"
        }
    }

    /// Each main value's widest, formatted. A maximum capacity with its tier's symbol beside it has
    /// two digits, narrower than 100% alone.
    static func widestMain(_ kind: BatteryWidgetMain, _ f: BatteryFormatter) -> [String] {
        switch kind {
        case .charge, .maximumCapacity: [f.percent(100)]
        case .temperature: [f.celsius(88.8)]
        case .batteryPower: [f.watts(-88.8, signed: true), f.watts(88.8, signed: true)]
        }
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
                // The main value, on one line at full size at its kind's point size.
                for kind in BatteryWidgetMain.allCases {
                    let pointSize = kind.pointSize(in: size)
                    for value in widestMain(kind, f) {
                        let width = Budget.mainWidth(value, pointSize: pointSize)
                        if !Budget.fits(width, in: Budget.lineWidth(size)) {
                            overflows.append(
                                Overflow(
                                    text: value, place: "the main value at \(pointSize) pt, \(size)", points: width))
                        }
                    }
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
                // The details: a label and its value on one line, in the one form the place shows
                // the label in whatever the value (``BatteryWidgetField/labelForm(in:locale:)``):
                // the field's label, its shorter one, or none, a word that says what it is alone;
                // a tile's label on one line over its value on up to two.
                for field in BatteryWidgetField.allCases where field != .time {
                    let labels = try choices([WidgetKeys.label(field), field.shortLabelKey], language)
                    for value in try widestValues(field, language) {
                        let place = Budget.detailWidth(size)
                        switch size {
                        case .small, .medium:
                            let shown = try Self.label(
                                field, field.labelForm(in: size, locale: language.locale), language)
                            let fits =
                                shown.map { Budget.fits(Self.before(field, value, size) + Budget.width($0), in: place) }
                                ?? oneLine([value], place)
                            check(fits, "\(shown ?? "") \(value)", "a detail, \(size)")
                        case .large, .extraLarge, .extraLargePortrait:
                            let tile = field == .timeOnBattery ? Self.timeOnBatteryTile(language) : value
                            check(oneLine([labels[0]], place), labels[0], "a tile's label, \(size)")
                            check(Budget.lines(tile, width: place, .title3) <= 2, tile, "a tile's value, \(size)")
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
        // The line under a feed's last data once it is old, on one line across a chart's place:
        // the whole width of the History widget and of the large Battery widget's chart.
        for language in Language.allCases {
            let outdated = try choices([HistoryWidgetEmptyReason.outdatedKey], language)
            for size in [WidgetSize.medium, .large] {
                check(
                    oneLine(outdated, Budget.contentWidth(size)), outdated.last ?? "",
                    "a chart's old-data line, \(size)")
            }
        }
        // The History widget, medium and large, the whole width: the chart's name beside its
        // latest value, and in large the period's figures as rows of a label and its value, each on
        // one line: the last 24 hours' or 7 days', whose time on battery has three digits of hours.
        for language in Language.allCases {
            let f = try formatter(language)
            for size in [WidgetSize.medium, .large] {
                let place = Budget.contentWidth(size)
                for series in HistoryWidgetSeries.allCases {
                    let title = try choices([series.titleKey], language)
                    let latest = series.valueLabel(series == .cycleCount ? 9_999 : -88.8, f)
                    check(
                        oneLine(title, after: Budget.width(latest) + Budget.gap(.medium), place),
                        "\(title.last ?? "") \(latest)", "the History chart's header, \(size)")
                }
                let statistics = [
                    (
                        HistoryWidgetStatistic.Kind.averageDrain,
                        try perHour(f.percent(99.9, fractionDigits: 1), language)
                    ),
                    (.onBattery, [f.duration(minutes: 23 * 60 + 59), f.duration(minutes: 7 * 24 * 60 - 1)]),
                    (.chargingSessions, ["9,999"]),
                ]
                for (kind, values) in statistics where size == .large {
                    let label = try choices([kind.labelKey], language)
                    for value in values {
                        check(
                            oneLine(label, after: Budget.width(value) + Budget.gap(.medium), place),
                            "\(label.last ?? "") \(value)", "a History figure, \(size)")
                    }
                }
            }
        }
        // The iPhone & iPad widget: one device's state and read time, each on a line of small's
        // width (the block is as wide in medium and larger in large); a row of All, its state
        // beside its read time across the row, after its symbol's column; its messages, the
        // Russian in as many lines as the English, in every family.
        for language in Language.allCases {
            let states = try [WidgetStateWord.charging, .onBattery, .fullyCharged, .notCharging, .unknown].compactMap {
                try text(WidgetKeys.state($0), language)
            }
            // The widest day: one late in each month, in the language's own abbreviations.
            let utc = TimeZone(identifier: "UTC") ?? .gmt
            let days = (0..<12).map { month in
                DeviceWidgetRow.readTime(
                    Date(timeIntervalSince1970: 1_769_558_400 + Double(month) * 30.5 * 24 * 3600), at: .distantFuture,
                    locale: language.locale, timeZone: utc)
            }
            let dates = [language.clock] + days
            let updated = try choices(["Updated %@"], language).flatMap { format in
                dates.map { format.replacingOccurrences(of: "%@", with: $0) }
            }
            for line in states + updated {
                check(oneLine([line], Budget.lineWidth(.small)), line, "a device's line, small")
            }
            // One device's details in medium: rows beside its block, the medium Battery widget's
            // place, each label in the form that place shows (Look 2's answer added cycle count and
            // temperature to maximum capacity).
            for field in DevicesWidgetPlan.detailFields(.medium) {
                let shown = try Self.label(field, field.labelForm(in: .medium, locale: language.locale), language)
                for value in try widestValues(field, language) {
                    let fits =
                        shown.map {
                            Budget.fits(
                                Self.before(field, value, .medium) + Budget.width($0), in: Budget.detailWidth(.medium))
                        } ?? oneLine([value], Budget.detailWidth(.medium))
                    check(fits, "\(shown ?? "") \(value)", "a device's detail, medium")
                }
            }
            let row = Budget.contentWidth(.medium) - 20 - 8
            for state in states {
                for time in updated {
                    check(
                        oneLine([time], after: Budget.width(state) + Budget.gap(.medium), row), "\(state) \(time)",
                        "a device's row")
                }
            }
        }
        // Small's line under an old feed's last reading has two lines, in both languages.
        for language in Language.allCases {
            let line = try choices([HistoryWidgetEmptyReason.outdatedKey], language)
            let width = Budget.contentWidth(.small) * (language == .russian ? Budget.margin : 1)
            for text in line {
                check(Budget.lines(text, width: width) <= 2, text, "a device's old-data line, small")
            }
        }
        for reason in DevicesWidgetEmptyReason.allCases {
            for size in [WidgetSize.small, .medium, .large] {
                let place = Budget.contentWidth(size)
                let english = Budget.lines(reason.messageKey, width: place)
                let russian = try text(reason.messageKey, .russian).map {
                    Budget.lines($0, width: place * Budget.margin)
                }
                check(
                    russian == english, try text(reason.messageKey, .russian) ?? "",
                    "a device message of \(english) lines, \(size)")
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
        // The History widget's and the large Battery widget's chart: medium and large only.
        let historyMessages = HistoryWidgetEmptyReason.allCases.map {
            (keys: [$0.messageKey] as [String?], style: Budget.Style.caption)
        }
        for size in WidgetSize.allCases where size == .medium || size == .large {
            let place = Budget.contentWidth(size)
            for message in historyMessages {
                func shown(_ language: Language) throws -> Int {
                    let words = try choices(message.keys, language)
                    let width = language == .russian ? place * Budget.margin : place
                    return words.map { Budget.lines($0, width: width, message.style) }.first ?? 0
                }
                let english = try shown(.english)
                let russian = try shown(.russian)
                let text = try text(message.keys[0] ?? "", .russian) ?? ""
                check(russian == english && english == 1, text, "a History message of \(english) lines, \(size)")
            }
        }
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

    /// What comes before a detail's label on its line: its value (medium's with tabular digits),
    /// a tier's symbol and the gap.
    static func before(_ field: BatteryWidgetField, _ value: String, _ size: WidgetSize) -> Double {
        WidgetTextBudget.width(value, monospacedDigits: size == .medium)
            + (hasCue(field) ? WidgetTextBudget.cueWidth : 0)
            + WidgetTextBudget.gap(size)
    }

    /// The label `form` shows of `field` in `language`; `nil` for none.
    static func label(_ field: BatteryWidgetField, _ form: WidgetLabelForm, _ language: Language) throws -> String? {
        switch form {
        case .full: try text(WidgetKeys.label(field), language)
        case .short: try field.shortLabelKey.flatMap { try text($0, language) }
        case .none: nil
        }
    }

    /// Look 1's pre-answer: one label per place. Each one-line place of each language shows the
    /// first form of a field's label that fits beside every widest value the place can show, and
    /// keeps it whatever the value is: the table in ``BatteryWidgetField/labelForm(in:locale:)`` is
    /// that choice, derived here from the budget.
    @Test(arguments: Language.allCases)
    func eachPlaceShowsOneLabelWhateverTheValue(_ language: Language) throws {
        for size in [WidgetSize.small, .medium] {
            let place = WidgetTextBudget.detailWidth(size)
            for field in BatteryWidgetField.allCases where field != .time {
                let values = try Self.widestValues(field, language)
                func fits(_ form: WidgetLabelForm) throws -> Bool {
                    guard let label = try Self.label(field, form, language) else {
                        return values.allSatisfy { WidgetTextBudget.fits(WidgetTextBudget.width($0), in: place) }
                    }
                    return values.allSatisfy {
                        WidgetTextBudget.fits(Self.before(field, $0, size) + WidgetTextBudget.width(label), in: place)
                    }
                }
                let expected: WidgetLabelForm =
                    try fits(.full) ? .full : field.shortLabelKey != nil && fits(.short) ? .short : .none
                #expect(field.labelForm(in: size, locale: language.locale) == expected, "\(field), \(size)")
            }
        }
        // Tiles have a line of their own for the label.
        for field in BatteryWidgetField.allCases {
            #expect(field.labelForm(in: .large, locale: language.locale) == .full)
        }
    }

    /// The forms 0.7.1's pictures show: the medium Battery widget's Time on battery is its shorter
    /// Unplugged in Russian beside any value, and small's Average drain "Drain" in English.
    @Test func theRussianTimeOnBatteryIsShortInMedium() {
        let russian = Locale(identifier: "ru_RU")
        #expect(BatteryWidgetField.timeOnBattery.labelForm(in: .medium, locale: russian) == .short)
        #expect(BatteryWidgetField.averageDrain.labelForm(in: .small, locale: Locale(identifier: "en_US")) == .short)
        #expect(BatteryWidgetField.maximumCapacity.labelForm(in: .small, locale: Locale(identifier: "en_US")) == .full)
        #expect(BatteryWidgetField.state.labelForm(in: .small, locale: russian) == .none)
        // A language without a table of its own is laid out as English.
        #expect(
            BatteryWidgetField.timeOnBattery.labelForm(in: .medium, locale: Locale(identifier: "de_DE"))
                == BatteryWidgetField.timeOnBattery.labelForm(in: .medium, locale: Locale(identifier: "en_US")))
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
        // Small's battery power at 34 points: the Russian, wider than the line, shrank.
        let power = try Self.formatter(.russian).watts(38, signed: true)
        #expect(Budget.mainWidth(power, pointSize: 34) > Budget.lineWidth(.small))
        #expect(Budget.fits(Budget.mainWidth(power, pointSize: 34), in: Budget.lineWidth(.medium)))
    }

    /// The main value's face matches CI's pictures of 0.7's battery power at 34 points, where the
    /// value had room (medium's charge block), within 2 %: half the pictures' ink widths plus the
    /// side bearings.
    @Test(arguments: [(Language.english, 134.8), (.russian, 141.5)])
    func theMainFaceMatchesThePictures(language: Language, measured: Double) throws {
        let text = try Self.formatter(language).watts(38, signed: true)
        let width = WidgetTextBudget.mainWidth(text, pointSize: 34)
        #expect(abs(width - measured) <= measured * 0.02, "\(text): \(width) against \(measured)")
    }

    /// The main value's size doesn't depend on the language, and small and medium keep 0.6.x's 34
    /// points for the charge.
    @Test func theMainValueKeepsItsSizes() {
        #expect(BatteryWidgetMain.charge.pointSize(in: .small) == 34)
        #expect(BatteryWidgetMain.charge.pointSize(in: .medium) == 34)
        #expect(BatteryWidgetMain.batteryPower.pointSize(in: .small) == 31)
        #expect(BatteryWidgetMain.batteryPower.pointSize(in: .medium) == 34)
        #expect(BatteryWidgetMain.allCases.allSatisfy { $0.pointSize(in: .large) == 40 })
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
        // The main value's digits are tabular: every digit is as wide.
        #expect(Budget.mainWidth("11", pointSize: 34) == Budget.mainWidth("88", pointSize: 34))
    }
}
