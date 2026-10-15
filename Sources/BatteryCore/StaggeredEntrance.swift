import Foundation

/// A one-time staggered entrance for a short list, such as the rows of What's New: each row fades
/// in and rises a few points, a moment after the row above it.
///
/// It decorates and nothing more, so it plays only when ``MotionPolicy/allowsFlourish``. Under
/// Reduce Motion, Low Power Mode or in a hidden window the rows are simply there: no stagger, no
/// movement and no fade.
public struct StaggeredEntrance: Sendable, Equatable {
    /// Seconds between the start of one row and the start of the next.
    public static let step = 0.04
    /// The longest any row waits, so a longer list still settles quickly; rows past it start
    /// together.
    public static let maximumDelay = 0.2
    /// Points a row rises while it fades in.
    public static let rise = 6.0

    /// Whether the entrance plays at all.
    public let plays: Bool

    public init(_ policy: MotionPolicy) {
        plays = policy.allowsFlourish
    }

    /// Seconds row `index` (counted from 0) waits before it starts; 0 when the entrance doesn't
    /// play.
    public func delay(forRow index: Int) -> Double {
        guard plays else { return 0 }
        return min(Double(max(0, index)) * Self.step, Self.maximumDelay)
    }

    /// A row's opacity before it has entered: 0 when the entrance plays, otherwise fully shown.
    public var opacityBeforeEntering: Double { plays ? 0 : 1 }

    /// How far below its place a row starts, in points: ``rise`` when the entrance plays.
    public var offsetBeforeEntering: Double { plays ? Self.rise : 0 }
}
