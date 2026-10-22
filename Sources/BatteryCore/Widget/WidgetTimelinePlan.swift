import Foundation

/// The widget's timeline for one reading. The widget shows its estimate as a clock time ("Full
/// at 17:39") so that it stays right between reloads; when that time comes before the next reload,
/// a second entry at that moment drops it, so a time that has passed never stays on screen, and
/// the next reload comes soon after.
public struct WidgetTimelinePlan: Sendable, Equatable {
    /// How often the widget asks for a new reading when the app doesn't ask first; WidgetKit allows
    /// about 40–70 reloads a day.
    public static let refreshInterval: TimeInterval = 30 * 60
    /// The earliest next reload, so an estimate that keeps running out near full charge doesn't
    /// spend the budget: through the taper the time to full can stay at a few minutes for most of
    /// an hour, and a budget spent there delays the app's own reload when the Mac is unplugged.
    public static let minimumReloadInterval: TimeInterval = 15 * 60

    public struct Entry: Sendable, Equatable {
        public var date: Date
        public var showsEstimate: Bool

        public init(date: Date, showsEstimate: Bool) {
            self.date = date
            self.showsEstimate = showsEstimate
        }
    }

    public var entries: [Entry]
    public var nextReload: Date

    public init(snapshot: BatterySnapshot?, at date: Date) {
        let regular = date.addingTimeInterval(Self.refreshInterval)
        let soonest = date.addingTimeInterval(Self.minimumReloadInterval)
        guard let minutes = snapshot.flatMap(Self.estimateMinutes) else {
            entries = [Entry(date: date, showsEstimate: true)]
            nextReload = regular
            return
        }
        let end = date.addingTimeInterval(Double(minutes) * 60)
        if end >= regular {
            entries = [Entry(date: date, showsEstimate: true)]
            nextReload = regular
        } else if end <= date {
            entries = [Entry(date: date, showsEstimate: false)]
            nextReload = soonest
        } else {
            entries = [Entry(date: date, showsEstimate: true), Entry(date: end, showsEstimate: false)]
            nextReload = max(end, soonest)
        }
    }

    /// The minutes the widget turns into a clock time: to full while charging, to empty while
    /// discharging; `nil` in the other states and while macOS is still calculating.
    public static func estimateMinutes(_ snapshot: BatterySnapshot) -> Int? {
        switch snapshot.chargeState {
        case .charging: snapshot.estimatedTimeToFullMinutes
        case .discharging: snapshot.estimatedTimeToEmptyMinutes
        case .charged, .notCharging, .unknown: nil
        }
    }
}
