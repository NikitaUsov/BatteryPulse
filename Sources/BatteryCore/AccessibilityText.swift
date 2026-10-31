import Foundation

// What VoiceOver reads for the app's custom components, built here so it is tested on Linux. The
// Power Flow card, the capacity bars and each ring are one element, with a label and a value:
//
// - Power Flow: "Power Flow", then what its nodes and arrows show, in their order; on the M5
//   charging capture "60 W adapter, 18.5 W from the adapter, 14.0 W to the Mac, 4.7 W to the
//   battery, Battery, 70%". The battery's arrow says its direction in words; inside the dead band,
//   where the card shows no value on it, it says nothing.
// - Capacity: "Capacity", then each bar's name and value: "Remaining, 3,896 mAh, Full charge, …".
// - A ring: its title and the number it shows; the cycle ring also says the rated cycles it fills
//   toward ("48 of 1,000").
//
// The words follow the widget's (`WidgetAccessibility`): catalog keys, keyed by their English text,
// whose `%@` placeholders take pre-formatted values. The labels are the words the components show.
// The app localizes the keys and reads a value's phrases joined with commas.

/// What VoiceOver reads for one of the app's custom components: one element's label and value.
public struct AccessibilityText: Sendable, Equatable {
    /// What the element is, as the component's title shows it: "Power Flow".
    public var label: WidgetPhrase
    /// What it shows, phrase by phrase: "60 W adapter", "18.5 W from the adapter", ….
    public var value: [WidgetPhrase]

    /// The label in one language, its keys through `localize`.
    public func labelText(_ localize: (String) -> String) -> String {
        label.text(localize)
    }

    /// The value in one language: its phrases, each through `localize`, joined with commas.
    public func valueText(_ localize: (String) -> String) -> String {
        value.map { $0.text(localize) }.joined(separator: ", ")
    }

    /// Every catalog key the element uses.
    var keys: [String] {
        label.keys + value.flatMap(\.keys)
    }

    /// Every catalog key these elements can use, for the catalog's check: the app reads them
    /// through BatteryCore, so its sources needn't name them.
    public static let catalogKeys: Set<String> = [
        "Power Flow", "Adapter", "%@ adapter", "%@ from the adapter", "%@ to the Mac", "%@ to the battery",
        "%@ from the battery", "Battery", "Capacity", "Remaining", "Full charge", "Design", "Charge",
        "Maximum capacity", "Cycle count", "%@ of %@",
    ]

    /// The Power Flow card: each node's and arrow's value, in the card's order, the battery's arrow
    /// by its direction.
    public static func powerFlow(_ flow: PowerFlowText) -> AccessibilityText {
        var value: [WidgetPhrase] = []
        if flow.showsAdapter {
            value.append(flow.adapterRating.map { .key("%@ adapter", [.verbatim($0)]) } ?? .key("Adapter"))
        }
        if let input = flow.adapterInput {
            value.append(.key("%@ from the adapter", [.verbatim(input)]))
        }
        if let load = flow.macLoad {
            value.append(.key("%@ to the Mac", [.verbatim(load)]))
        }
        if let power = flow.batteryPower {
            value.append(.key(flow.intoBattery ? "%@ to the battery" : "%@ from the battery", [.verbatim(power)]))
        }
        if let charge = flow.charge {
            value += [.key("Battery"), .verbatim(charge)]
        }
        return AccessibilityText(label: .key("Power Flow"), value: value)
    }

    /// The capacity bars, in their order: each bar's name, then its value.
    public static func capacity(_ bars: [CapacityBar], formatter: BatteryFormatter) -> AccessibilityText {
        AccessibilityText(
            label: .key("Capacity"),
            value: bars.flatMap { [.key($0.kind.titleKey), .verbatim(formatter.milliampHours($0.capacityMAh))] })
    }

    /// The charge ring: "Charge", "70 %".
    public static func chargeRing(percent: Double, formatter: BatteryFormatter) -> AccessibilityText {
        AccessibilityText(label: .key("Charge"), value: [.verbatim(formatter.percent(percent))])
    }

    /// The maximum capacity ring: "Maximum capacity", "100 %".
    public static func maximumCapacityRing(percent: Double, formatter: BatteryFormatter) -> AccessibilityText {
        AccessibilityText(label: .key("Maximum capacity"), value: [.verbatim(formatter.percent(percent))])
    }

    /// The cycle ring, which fills toward the rated cycles: "Cycle count", "48 of 1,000".
    public static func cycleRing(count: Int, rated: Int, formatter: BatteryFormatter) -> AccessibilityText {
        let numbers = [count, rated].map { WidgetPhrase.verbatim($0.formatted(.number.locale(formatter.locale))) }
        return AccessibilityText(label: .key("Cycle count"), value: [.key("%@ of %@", numbers)])
    }
}

/// The Power Flow card's values, formatted as its nodes and arrows show them, adapter → Mac →
/// battery (or battery → Mac on battery power); VoiceOver reads them through
/// ``AccessibilityText/powerFlow(_:)``.
public struct PowerFlowText: Sendable, Equatable {
    /// The adapter shows: external power, with an adapter reported.
    public var showsAdapter: Bool
    /// The adapter's rating, "60 W"; `nil` when it reports none, or doesn't show.
    public var adapterRating: String?
    /// What the Mac takes from the adapter, "18.5 W": above 0 W, with the adapter shown.
    public var adapterInput: String?
    /// The Mac's load, "14.0 W", as the system reports it.
    public var macLoad: String?
    /// The battery's power without its sign, "4.7 W"; `nil` inside
    /// ``BatteryPresentation/powerFlowDeadBandWatts``, where the arrow rests.
    public var batteryPower: String?
    /// The battery's arrow points into the battery, or rests that way
    /// (``BatteryMotionKey/batteryArrowPointsIntoBattery``).
    public var intoBattery: Bool
    /// The charge, "70 %".
    public var charge: String?

    public init(_ s: BatterySnapshot, formatter: BatteryFormatter) {
        let key = BatteryMotionKey(s)
        showsAdapter = s.isExternalPowerConnected == true && s.adapter != nil
        adapterRating = showsAdapter ? s.adapter?.watts.map { formatter.watts(Double($0), fractionDigits: 0) } : nil
        adapterInput = showsAdapter ? s.systemPowerInWatts.flatMap { $0 > 0 ? formatter.watts($0) : nil } : nil
        macLoad = s.systemLoadWatts.map { formatter.watts($0) }
        batteryPower = key.flow == .idle ? nil : s.batteryPowerWatts.map { formatter.watts(abs($0)) }
        intoBattery = key.batteryArrowPointsIntoBattery
        charge = s.chargePercent.map { formatter.percent($0) }
    }
}

extension CapacityBar.Kind {
    /// The bar's name, the catalog key the capacity bars show beside it.
    var titleKey: String {
        switch self {
        case .remaining: "Remaining"
        case .fullCharge: "Full charge"
        case .design: "Design"
        }
    }
}
