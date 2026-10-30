import Foundation

// What VoiceOver reads on the Battery widget, built from the layout plan so it is tested on Linux:
// one element per block and row, each with a label that carries its value, in the order the widget
// shows them. 0.6.1's widget gave VoiceOver nine flat elements, an unnamed level symbol among
// them, and no label paired with its value.
//
// - The charge block is one element, "Battery charge: 70 %, On battery", whatever the main value:
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
}

/// The label of one VoiceOver element of the widget.
public enum WidgetSpokenLabel: Sendable, Equatable {
    /// Phrases joined with commas: "Maximum capacity, 100 %".
    case phrases([WidgetPhrase])
    /// The time left, which the system counts down in the text itself: that text is the element,
    /// and its label stays the system's.
    case timeLeft(until: Date)

    /// The label in one language; `nil` for the time left, whose words only the system has.
    public func text(_ localize: (String) -> String) -> String? {
        guard case .phrases(let phrases) = self else { return nil }
        return phrases.map { $0.text(localize) }.joined(separator: ", ")
    }

    /// Every catalog key the label uses.
    var keys: [String] {
        guard case .phrases(let phrases) = self else { return [] }
        return phrases.flatMap(\.keys)
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
            if !layout.powerDetails.isEmpty {
                if layout.panelHeadings { elements.append(WidgetPanel.power.spokenLabel) }
                elements += layout.powerDetails.map(\.spokenLabel)
            }
            return elements
        }
    }
}

extension BatteryWidgetLayout {
    /// The charge block's element, "Battery charge: 70 %, On battery" (the menu bar icon's words),
    /// whatever the main value and whether or not the state line shows.
    public var chargeLabel: WidgetSpokenLabel {
        .phrases([.key("Battery charge: %@, %@", [.verbatim(level.text), level.state.phrase])])
    }

    /// The main value's element when it isn't the charge: "Maximum capacity, 100 %".
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
        case .text(let text): .phrases([.key(field.labelKey), .verbatim(text)])
        case .state(let word): .phrases([.key(field.labelKey), word.phrase])
        case .condition(let condition): .phrases([.key(field.labelKey), condition.phrase])
        case .onOff(let on): .phrases([.key(field.labelKey), .key(on ? "On" : "Off")])
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
}

extension WidgetEmptyReason {
    /// The message the widget shows; its symbol is hidden.
    public var spokenLabel: WidgetSpokenLabel {
        switch self {
        case .noBattery: .phrases([.key("This Mac has no internal battery.")])
        case .noInformation: .phrases([.key("No battery information")])
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
        }
    }
}

extension WidgetStateWord {
    var phrase: WidgetPhrase {
        switch self {
        case .charging: .key("Charging")
        case .onBattery: .key("On battery")
        case .fullyCharged: .key("Fully charged")
        case .chargingOnHold: .key("Charging on hold")
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
