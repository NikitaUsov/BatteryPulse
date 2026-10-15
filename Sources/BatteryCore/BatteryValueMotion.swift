import Foundation

// Decisions behind the battery value views (Overview, Power and Health) that don't depend on
// SwiftUI: which way the power-flow arrow points, when the battery counts as newly full, the
// capacity bars and when the Developer option "Glass Cards" applies. They live here so they are
// tested on Linux; the views only map them to animations and drawing.

extension BatteryMotionKey {
    /// Which way the Overview's battery arrow points: into the battery while it takes power, out
    /// of it (toward the Mac) while it gives power. Inside the dead band (full, held, or no
    /// reading) the arrow rests where power would go: into the battery on external power, toward
    /// the Mac otherwise. Noise around 0 W therefore never turns it.
    public var batteryArrowPointsIntoBattery: Bool {
        switch flow {
        case .intoBattery: true
        case .outOfBattery: false
        case .idle: isPluggedIn
        }
    }

    /// Whether a change of charge state from `old` to `new` is the battery reaching full: the
    /// state turning to ``ChargeState/charged`` from any other. A battery that is already full
    /// when a view appears is not an event.
    public static func reachedFull(from old: ChargeState?, to new: ChargeState?) -> Bool {
        new == .charged && old != .charged
    }
}

/// One bar of the capacity card: remaining, full-charge or design capacity on a shared scale.
public struct CapacityBar: Sendable, Equatable, Identifiable {
    public enum Kind: Sendable, Hashable, CaseIterable {
        case remaining, fullCharge, design
    }

    public var kind: Kind
    public var capacityMAh: Int
    /// The kind, so a bar keeps its identity when another one appears or goes away.
    public var id: Kind { kind }

    public init(kind: Kind, capacityMAh: Int) {
        self.kind = kind
        self.capacityMAh = capacityMAh
    }

    /// Remaining, full-charge and design capacity, in that order, for the values `s` has.
    public static func bars(for s: BatterySnapshot) -> [CapacityBar] {
        bars(remainingMAh: s.currentCapacityMAh, fullChargeMAh: s.fullChargeCapacityMAh, designMAh: s.designCapacityMAh)
    }

    /// The bars for capacities from any battery (a Mac's, an iPhone's), in the same order.
    public static func bars(remainingMAh: Int?, fullChargeMAh: Int?, designMAh: Int?) -> [CapacityBar] {
        let values: [(Kind, Int?)] = [
            (.remaining, remainingMAh),
            (.fullCharge, fullChargeMAh),
            (.design, designMAh),
        ]
        return values.compactMap { kind, value in value.map { CapacityBar(kind: kind, capacityMAh: $0) } }
    }

    /// The bars' common scale: the largest value, and never below 1 mAh.
    public static func scale(of bars: [CapacityBar]) -> Double {
        Double(max(1, bars.map(\.capacityMAh).max() ?? 1))
    }
}

/// How a content card is drawn.
public enum CardSurface: Sendable, Equatable {
    /// The standard fill. Apple keeps Liquid Glass out of the content layer, so this is the
    /// default.
    case standard
    /// Liquid Glass: the Developer option "Glass Cards", an experiment.
    case glass

    /// The stored option counts only while the Developer section is on (turning the section off
    /// keeps the value but ignores it), and never under Reduce Transparency, where the cards keep
    /// their opaque standard fill.
    public init(glassCardsOption: Bool, showsDeveloperSection: Bool, reduceTransparency: Bool) {
        self = glassCardsOption && showsDeveloperSection && !reduceTransparency ? .glass : .standard
    }
}
