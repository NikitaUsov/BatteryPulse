import Foundation

// What VoiceOver reads on the Battery widget, built from the layout plan so it is tested on Linux:
// one element per block and row, each with a label that carries its value, in the order the widget
// shows them. 0.6.1's widget gave VoiceOver nine flat elements, an unnamed level symbol among
// them, and no label paired with its value.
//
// - The charge block is one element, "Battery charge: 70%, On battery", whatever the main value:
//   the level symbol, the ring and the drawn battery all show the charge. The level symbol is
//   hidden, since its bucket can contradict the number (75 % stands for 63-87 %).
// - A main value other than the charge reads "label, value" after it, and so does each row.
// - Every other line under the main value is an element of its own, in order.
// - The attention row names what it is about ("Thermal state, High"), which its symbol says on
//   screen.
//
// The labels are catalog keys with their pre-formatted values; the widget localizes the keys and
// joins an element's phrases with commas, as VoiceOver joins a combined element's parts.

/// A phrase VoiceOver reads: formatted numbers as they are, or a catalog key, keyed by its English
/// text, whose `%@` placeholders take the phrases after it in turn.
public enum WidgetPhrase: Sendable, Equatable {
    /// Numbers and units, or a condition macOS reports in words the app has no key for.
    case verbatim(String)
    case key(String, [WidgetPhrase] = [])

    /// The phrase in one language: each key through `localize`, its placeholders filled in turn.
    func text(_ localize: (String) -> String) -> String {
        switch self {
        case .verbatim(let text):
            return text
        case .key(let key, let arguments):
            let format = localize(key)
            guard !arguments.isEmpty else { return format }
            var text = ""
            var rest = Substring(format)
            for argument in arguments {
                guard let placeholder = rest.range(of: "%@") else { break }
                text += rest[..<placeholder.lowerBound] + argument.text(localize)
                rest = rest[placeholder.upperBound...]
            }
            return text + rest
        }
    }

    /// Every catalog key in the phrase, its arguments' included.
    var keys: [String] {
        switch self {
        case .verbatim: []
        case .key(let key, let arguments): [key] + arguments.flatMap(\.keys)
        }
    }

    /// A catalog sentence ("This Mac has no internal battery."), which ends with its own stop.
    var isSentence: Bool {
        if case .key(let key, _) = self { key.hasSuffix(".") } else { false }
    }
}

/// The label of one VoiceOver element of the widget.
public enum WidgetSpokenLabel: Sendable, Equatable {
    /// Phrases joined with commas: "Maximum capacity, 100%"; after a sentence, with a space: "This
    /// Mac has no internal battery. Try the Accessories widget".
    case phrases([WidgetPhrase])
    /// The time left, which the system counts down in the text itself: that text is the element,
    /// and its label stays the system's.
    case timeLeft(until: Date)
    /// A label's key and the time since a moment, which the system counts up in the text itself:
    /// the element combines the label and that text, as the system reads them.
    case counting(label: String, since: Date)

    /// The label in one language; `nil` for the time left, whose words only the system has.
    public func text(_ localize: (String) -> String) -> String? {
        guard case .phrases(let phrases) = self else { return nil }
        var text = ""
        for (index, phrase) in phrases.enumerated() {
            if index > 0 { text += phrases[index - 1].isSentence ? " " : ", " }
            text += phrase.text(localize)
        }
        return text
    }

    /// Every catalog key the label uses.
    var keys: [String] {
        switch self {
        case .phrases(let phrases): phrases.flatMap(\.keys)
        case .timeLeft: []
        case .counting(let label, _): [label]
        }
    }
}

/// Extra large's two panels, in the order VoiceOver reaches them.
enum WidgetPanel: Sendable, Equatable, CaseIterable {
    case battery, power

    /// The panel's name, which Automatic shows above it.
    var spokenLabel: WidgetSpokenLabel {
        .phrases([.key(self == .battery ? "Battery" : "Power")])
    }
}

/// The widget's VoiceOver elements.
enum WidgetAccessibility {
    /// Every element of `plan`, in the order the widget shows them: the Battery panel's name in
    /// extra large's Automatic, the charge, a main value other than the charge, the lines under it
    /// but the state (which the charge reads), the details, then the Power panel's name and its
    /// details.
    static func elements(_ plan: WidgetLayoutPlan) -> [WidgetSpokenLabel] {
        switch plan {
        case .empty(let reason):
            return [reason.spokenLabel]
        case .battery(let layout):
            var elements: [WidgetSpokenLabel] = []
            if layout.panelHeadings { elements.append(WidgetPanel.battery.spokenLabel) }
            elements.append(layout.chargeLabel)
            if let main = layout.mainLabel { elements.append(main) }
            elements += layout.lines.compactMap(\.spokenLabel)
            elements += layout.details.map(\.spokenLabel)
            if let chart = layout.chart { elements += Self.elements(chart) }
            if !layout.powerDetails.isEmpty {
                if layout.panelHeadings { elements.append(WidgetPanel.power.spokenLabel) }
                elements += layout.powerDetails.map(\.spokenLabel)
            }
            return elements
        }
    }
}

extension BatteryWidgetLayout {
    /// The charge block's element, "Battery charge: 70%, On battery" (the menu bar icon's words),
    /// whatever the main value and whether or not the state line shows.
    public var chargeLabel: WidgetSpokenLabel {
        .phrases([.key("Battery charge: %@, %@", [.verbatim(level.text), level.state.phrase])])
    }

    /// The main value's element when it isn't the charge: "Maximum capacity, 100%".
    public var mainLabel: WidgetSpokenLabel? {
        guard let field = main.kind.field else { return nil }
        return .phrases([.key(field.labelKey), .verbatim(main.text)])
    }
}

extension WidgetLine {
    /// The line's element; `nil` for the state, which the charge's element reads.
    public var spokenLabel: WidgetSpokenLabel? {
        switch self {
        case .state: nil
        case .time(let time): time.spokenLabel
        case .updated(let clock): .phrases([.key("Updated %@", [.verbatim(clock)])])
        case .detail(let row): row.spokenLabel
        case .attention(let attention): attention.spokenLabel
        }
    }
}

extension WidgetDetail {
    public var spokenLabel: WidgetSpokenLabel {
        switch self {
        case .row(let row): row.spokenLabel
        case .attention(let attention): attention.spokenLabel
        }
    }
}

extension WidgetRow {
    /// "label, value"; a time row is its phrase alone, as it shows.
    public var spokenLabel: WidgetSpokenLabel {
        switch value {
        case .time(let time): time.spokenLabel
        case .since(let date): .counting(label: field.labelKey, since: date)
        case .text, .state, .condition, .onOff, .reached, .limitReached, .perHour:
            .phrases([.key(field.labelKey)] + value.phrases)
        }
    }
}

extension WidgetValue {
    /// What VoiceOver reads for the value after its label; nothing for a time, which the system's
    /// own text reads.
    var phrases: [WidgetPhrase] {
        switch self {
        case .text(let text): [.verbatim(text)]
        case .state(let word): [word.phrase]
        case .condition(let condition): [condition.phrase]
        case .onOff(let on): [.key(on ? "On" : "Off")]
        case .reached: [.key("Reached")]
        case .limitReached(let text): [.key("%@, reached", [.verbatim(text)])]
        case .perHour(let text): [.key("%@ per hour", [.verbatim(text)])]
        case .time, .since: []
        }
    }
}

extension WidgetAttention {
    /// What it is about, then its words: "Thermal state, High", "Condition, Service Recommended".
    public var spokenLabel: WidgetSpokenLabel {
        switch self {
        case .heat(let state): .phrases([.key("Thermal state"), state.phrase])
        case .condition(let condition): .phrases([.key(BatteryWidgetField.condition.labelKey), condition.phrase])
        }
    }
}

extension WidgetTimeText {
    /// The phrase the widget shows, with its clock time; the time left is the system's own text.
    public var spokenLabel: WidgetSpokenLabel {
        switch form {
        case .clock(let clock, let tomorrow):
            let key =
                switch (direction, tomorrow) {
                case (.full, false): "Full at %@"
                case (.empty, false): "Lasts until about %@"
                case (.full, true): "Full at %@ tomorrow"
                case (.empty, true): "Lasts until %@ tomorrow"
                }
            return .phrases([.key(key, [.verbatim(clock)])])
        case .timeLeft:
            return .timeLeft(until: end)
        }
    }

    /// The shorter phrase a one-line place shows where the phrase doesn't fit at full size, as
    /// ``BatteryWidgetField/shortLabelKey`` does for a label: "Lasts until 12:59 PM tomorrow" is
    /// wider than small's line. `nil` for a phrase that always fits.
    var shortKey: String? {
        guard case .clock(_, tomorrow: true) = form, direction == .empty else { return nil }
        return "Until %@ tomorrow"
    }
}

extension WidgetEmptyReason {
    /// The message the widget shows; its symbol is hidden. Without a battery it points to the
    /// Accessories widget.
    public var spokenLabel: WidgetSpokenLabel {
        switch self {
        case .noBattery: .phrases([.key("This Mac has no internal battery."), .key("Try the Accessories widget")])
        case .noInformation: .phrases([.key("No battery information")])
        }
    }

    /// The shorter message the widget shows when its own doesn't fit one line, as
    /// ``BatteryWidgetField/shortLabelKey`` does for a label. "No battery information" keeps its
    /// Russian, which 0.6.1's widget showed.
    var shortMessageKey: String? {
        switch self {
        case .noBattery: nil
        case .noInformation: "No battery data"
        }
    }
}

// The catalog keys of the words the widget shows, the same keys its views use for them (a macOS
// test compares the two).

extension BatteryWidgetField {
    /// The label beside the field's value.
    var labelKey: String {
        switch self {
        case .state: "State"
        case .time: "Time to full or empty"
        case .maximumCapacity: "Maximum capacity"
        case .condition: "Condition"
        case .cycleCount: "Cycle count"
        case .temperature: "Temperature"
        case .adapter: "Adapter"
        case .systemLoad: "System load"
        case .batteryPower: "Battery power"
        case .adapterInput: "Power from adapter"
        case .lowPowerMode: "Low Power Mode"
        case .remainingCapacity: "Remaining capacity"
        case .cycleLifeUsed: "Cycle life used"
        case .cellBalance: "Cell balance"
        case .voltage: "Voltage"
        case .systemChargeLimit: "Charge limit"
        case .averageDrain: "Average drain"
        case .timeOnBattery: "Time on battery"
        }
    }

    /// The shorter label the widget shows where the label and the place's widest value don't fit
    /// one line at full size: the Russian for Maximum capacity beside 100% in medium. Every
    /// language has it, and each place of each language shows one form whatever the value
    /// (``labelForm(in:locale:)``), so the two languages lay out alike even where only one shows
    /// the shorter label; VoiceOver keeps ``labelKey``. `nil` for a label that always fits.
    var shortLabelKey: String? {
        switch self {
        case .maximumCapacity: "Max capacity"
        case .batteryPower: "Battery"
        case .adapterInput: "From adapter"
        case .lowPowerMode: "Low Power"
        case .remainingCapacity: "Remaining"
        case .cycleLifeUsed: "Life used"
        case .cellBalance: "Balance"
        case .averageDrain: "Drain"
        case .timeOnBattery: "Unplugged"
        case .systemChargeLimit: "Limit"
        case .state, .time, .condition, .cycleCount, .temperature, .adapter, .systemLoad, .voltage: nil
        }
    }
}

/// How a one-line place, small's detail or a medium row, labels a field's value: its label, its
/// shorter label (``BatteryWidgetField/shortLabelKey``), or none, the value alone, for words that
/// say what they are (a state).
public enum WidgetLabelForm: Sendable, Equatable {
    case full, short, none
}

extension BatteryWidgetField {
    /// The one form a place shows the field's label in, in `locale`'s language, whatever its
    /// value: the first that fits the place's widest value on one line at full size (a 9,999, a
    /// 99.9% per hour, "23 hours"), so a label never switches with its value's length (Russian's
    /// Time on battery, its shorter Unplugged beside "9 hours" and its full words beside "—", in
    /// 0.7.1's first pictures). `WidgetTextBudgetTests` derives
    /// each entry from the budget and fails on one that differs. Large's and extra large's tiles
    /// have a line of their own for the label, which is always full. A language the widget has no
    /// table for is laid out as English, its development language.
    public func labelForm(in size: WidgetSize, locale: Locale) -> WidgetLabelForm {
        guard size == .small || size == .medium else { return .full }
        let russian = locale.language.languageCode?.identifier == "ru"
        if russian && self == .state { return .none }
        let short: Set<BatteryWidgetField> =
            switch (russian, size) {
            case (false, .small): [.adapterInput, .remainingCapacity, .averageDrain, .systemChargeLimit]
            case (false, _): [.remainingCapacity, .averageDrain]
            case (true, .small):
                [
                    .maximumCapacity, .batteryPower, .adapterInput, .lowPowerMode, .remainingCapacity, .cycleLifeUsed,
                    .cellBalance, .averageDrain, .timeOnBattery, .systemChargeLimit,
                ]
            case (true, _):
                [
                    .maximumCapacity, .batteryPower, .adapterInput, .lowPowerMode, .remainingCapacity, .cycleLifeUsed,
                    .averageDrain, .timeOnBattery, .systemChargeLimit,
                ]
            }
        return short.contains(self) ? .short : .full
    }
}

extension WidgetStateWord {
    var phrase: WidgetPhrase {
        switch self {
        case .charging: .key("Charging")
        case .onBattery: .key("On battery")
        case .fullyCharged: .key("Fully charged")
        case .chargingOnHold: .key("Charging on hold")
        case .chargedToLimit: .key("Charged to limit")
        case .notCharging: .key("Not charging")
        case .unknown: .key("Unknown")
        }
    }
}

extension WidgetCondition {
    /// The app's words for the condition; one it has no words for, as macOS reports it.
    var phrase: WidgetPhrase {
        switch self {
        case .normal: .key("Normal")
        case .fair: .key("Fair")
        case .poor: .key("Poor")
        case .checkBattery: .key("Check Battery")
        case .serviceRecommended: .key("Service Recommended")
        case .other(let raw): .verbatim(raw)
        }
    }

    /// The shorter words a one-line attention row shows when the condition's don't fit at full
    /// size, as ``BatteryWidgetField/shortLabelKey`` does for a label; VoiceOver keeps ``phrase``.
    var shortKey: String? {
        if case .serviceRecommended = self { "Service" } else { nil }
    }
}

extension ThermalState {
    /// The app's words for the thermal state.
    var phrase: WidgetPhrase {
        switch self {
        case .nominal: .key("Normal")
        case .fair: .key("Elevated")
        case .serious: .key("High")
        case .critical: .key("Critical")
        }
    }
}
