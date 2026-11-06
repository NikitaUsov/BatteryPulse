import Foundation

/// The widget's timeline for one reading. The widget shows its estimate as a clock time ("Full
/// at 17:39") so that it stays right between reloads; when that time comes before the timeline's
/// last entry, an entry at that moment drops it, so a time that has passed never stays on screen,
/// and the next reload comes soon after when it falls before the regular one.
///
/// Every timeline ends with a stale entry at the reading's time plus ``staleAge``, after every
/// planned reload: it shows only when WidgetKit postpones the reload, and lets the widget say how
/// old its reading is ("Updated 14:05"). Extra entries cost no reload; a timeline has at most
/// ``maximumEntries``.
public struct WidgetTimelinePlan: Sendable, Equatable {
    /// How often the widget asks for a new reading when the app doesn't ask first; WidgetKit allows
    /// about 40–70 reloads a day.
    public static let refreshInterval: TimeInterval = 30 * 60
    /// The earliest next reload, so an estimate that keeps running out near full charge doesn't
    /// spend the budget: through the taper the time to full can stay at a few minutes for most of
    /// an hour, and a budget spent there delays the app's own reload when the Mac is unplugged.
    public static let minimumReloadInterval: TimeInterval = 15 * 60
    /// When the reading counts as old: a quarter of an hour after the regular reload was due.
    public static let staleAge: TimeInterval = 45 * 60
    /// The reading, the end of its estimate and the stale entry.
    public static let maximumEntries = 3

    public struct Entry: Sendable, Equatable {
        public var date: Date
        public var showsEstimate: Bool
        /// The timeline's last entry, which shows only when the reload it waits for is late.
        public var isStale: Bool

        public init(date: Date, showsEstimate: Bool, isStale: Bool = false) {
            self.date = date
            self.showsEstimate = showsEstimate
            self.isStale = isStale
        }
    }

    public var entries: [Entry]
    public var nextReload: Date

    /// The Battery widget's timeline. `date` is when the widget read `snapshot`; the estimate's end
    /// and the stale entry count from the reading's own time (`snapshot.timestamp`), as the time
    /// text does, so every entry shows the same clock time.
    public init(snapshot: BatterySnapshot?, at date: Date) {
        let regular = date.addingTimeInterval(Self.refreshInterval)
        let soonest = date.addingTimeInterval(Self.minimumReloadInterval)
        let reading = snapshot?.timestamp ?? date
        let stale = max(reading, date).addingTimeInterval(Self.staleAge)
        guard let minutes = snapshot.flatMap(Self.estimateMinutes) else {
            entries = [Entry(date: date, showsEstimate: true), Entry(date: stale, showsEstimate: false, isStale: true)]
            nextReload = regular
            return
        }
        let end = reading.addingTimeInterval(Double(minutes) * 60)
        entries = [Entry(date: date, showsEstimate: end > date)]
        if end > date && end < stale {
            entries.append(Entry(date: end, showsEstimate: false))
        }
        entries.append(Entry(date: stale, showsEstimate: end > stale, isStale: true))
        nextReload =
            if end <= date {
                soonest
            } else if end < regular {
                max(end, soonest)
            } else {
                regular
            }
    }

    /// The Accessories widget's timeline: a new reading every half hour, then the stale entry.
    public static func accessories(at date: Date) -> WidgetTimelinePlan {
        WidgetTimelinePlan(
            entries: [
                Entry(date: date, showsEstimate: false),
                Entry(date: date.addingTimeInterval(staleAge), showsEstimate: false, isStale: true),
            ],
            nextReload: date.addingTimeInterval(refreshInterval))
    }

    /// How often the History widget reads the feed again when the app doesn't ask first: its
    /// series move in steps of 15 minutes and 2 hours.
    public static let historyRefreshInterval: TimeInterval = 60 * 60

    /// The History widget's timeline: the feed as read now, then the moment it turns two hours
    /// old (``WidgetFeed/outdatedAge``), when the widget adds "Open BatteryPulse to update" to its
    /// last data. That entry shows only if WidgetKit postpones the hourly reload that far, and
    /// comes at least ``minimumReloadInterval`` after the first. `writtenAt` is the feed's;
    /// without a feed, one entry.
    public static func history(writtenAt: Date?, at date: Date) -> WidgetTimelinePlan {
        var entries = [Entry(date: date, showsEstimate: false)]
        if let writtenAt {
            let outdated = writtenAt.addingTimeInterval(WidgetFeed.outdatedAge)
            if outdated <= date {
                entries[0].isStale = true
            } else {
                let at = max(outdated, date.addingTimeInterval(minimumReloadInterval))
                entries.append(Entry(date: at, showsEstimate: false, isStale: true))
            }
        }
        return WidgetTimelinePlan(entries: entries, nextReload: date.addingTimeInterval(historyRefreshInterval))
    }

    /// The iPhone & iPad widget's timeline: the feed as read now and a new read every half hour,
    /// as the Accessories widget's, with up to two entries before it: local midnight, when a read
    /// time of today turns into its date, if it comes before the reload; and the moment the feed
    /// turns two hours old (``WidgetFeed/outdatedAge``), when the widget adds "Open BatteryPulse
    /// to update" to its last readings, at least ``minimumReloadInterval`` after the first entry.
    /// Both show only if WidgetKit postpones the reload past them. `writtenAt` is the feed's;
    /// without a feed, the midnight entry alone may follow.
    public static func devices(writtenAt: Date?, at date: Date, timeZone: TimeZone) -> WidgetTimelinePlan {
        let next = date.addingTimeInterval(refreshInterval)
        let outdated = writtenAt?.addingTimeInterval(WidgetFeed.outdatedAge)
        var dates = [date]
        let calendar = HistoryDay.gregorian(in: timeZone)
        if let midnight = calendar.nextDate(
            after: date, matching: DateComponents(hour: 0, minute: 0, second: 0), matchingPolicy: .nextTime),
            midnight < next
        {
            dates.append(midnight)
        }
        var outdatedEntry: Date?
        if let outdated, outdated > date {
            outdatedEntry = max(outdated, date.addingTimeInterval(minimumReloadInterval))
        }
        if let outdatedEntry, !dates.contains(outdatedEntry) { dates.append(outdatedEntry) }
        let entries = dates.sorted().map { entry in
            Entry(
                date: entry, showsEstimate: false,
                isStale: outdated.map { entry >= $0 } == true || entry == outdatedEntry)
        }
        return WidgetTimelinePlan(entries: entries, nextReload: next)
    }

    private init(entries: [Entry], nextReload: Date) {
        self.entries = entries
        self.nextReload = nextReload
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
