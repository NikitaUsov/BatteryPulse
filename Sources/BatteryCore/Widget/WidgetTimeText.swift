import Foundation

/// The time to full or to empty as the widget shows it: a clock time ("Lasts until about 16:39",
/// "Full at 11:00 tomorrow") or the time left, which the widget counts down itself with
/// `Text(.currentDate, format: .offset(to: end, allowedFields: [.hour, .minute], sign: .never))`.
///
/// The end counts from the reading's own time (`snapshot.timestamp`), never an entry's date, so
/// every entry of a timeline shows the same end. Whether it falls today or tomorrow is decided at
/// the entry's date, in the widget's time zone. An end beyond tomorrow shows nothing: macOS's
/// estimates run up to 65,534 minutes, and a weekday ("Lasts until about Friday") says little.
public struct WidgetTimeText: Sendable, Equatable {
    /// Which phrase the widget uses.
    public enum Direction: Sendable, Equatable {
        /// "Full at %@": while charging.
        case full
        /// "Lasts until about %@": on battery.
        case empty
    }

    public enum Form: Sendable, Equatable {
        /// The end's clock time in the widget's locale, and whether it falls on the next local day
        /// ("Full at %@ tomorrow").
        case clock(String, tomorrow: Bool)
        /// The time left until ``WidgetTimeText/end``.
        case timeLeft
    }

    public var direction: Direction
    public var end: Date
    public var form: Form

    public init(direction: Direction, end: Date, form: Form) {
        self.direction = direction
        self.end = end
        self.form = form
    }

    /// The time for an entry at `date`; `nil` without an estimate, once it has passed, or when it
    /// ends after tomorrow.
    public init?(
        snapshot: BatterySnapshot, style: WidgetTimeStyle, at date: Date, locale: Locale, timeZone: TimeZone
    ) {
        guard let minutes = WidgetTimelinePlan.estimateMinutes(snapshot) else { return nil }
        let end = snapshot.timestamp.addingTimeInterval(Double(minutes) * 60)
        guard end > date else { return nil }
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        let days = calendar.dateComponents(
            [.day], from: calendar.startOfDay(for: date), to: calendar.startOfDay(for: end)
        )
        .day
        guard let days, days <= 1 else { return nil }
        self.direction = snapshot.chargeState == .charging ? .full : .empty
        self.end = end
        switch style {
        case .clockTime:
            let clock = end.formatted(
                Date.FormatStyle(
                    date: .omitted, time: .shortened, locale: locale, calendar: calendar, timeZone: timeZone))
            self.form = .clock(clock, tomorrow: days == 1)
        case .timeLeft:
            self.form = .timeLeft
        }
    }
}
