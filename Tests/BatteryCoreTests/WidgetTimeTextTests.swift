import Foundation
import Testing

@testable import BatteryCore

struct WidgetTimeTextTests {
    /// 2027-01-15 08:00 UTC: 11:00 in UTC+3, 00:00 in UTC−8.
    static let start = Date(timeIntervalSince1970: 1_800_000_000)
    static let plus3 = TimeZone(secondsFromGMT: 3 * 3600)!
    static let minus8 = TimeZone(secondsFromGMT: -8 * 3600)!
    static let enUS = Locale(identifier: "en_US")
    static let enGB = Locale(identifier: "en_GB")
    static let ruRU = Locale(identifier: "ru_RU")

    static func snapshot(_ state: ChargeState, minutes: Int, at date: Date = start) -> BatterySnapshot {
        var s = BatterySnapshot(timestamp: date)
        s.chargePercent = 50
        s.chargeState = state
        s.timeToFullMinutes = state == .charging ? minutes : nil
        s.timeToEmptyMinutes = state == .discharging ? minutes : nil
        return s
    }

    static func text(
        _ state: ChargeState, minutes: Int, at date: Date = start, style: WidgetTimeStyle = .clockTime,
        locale: Locale = enGB, timeZone: TimeZone = plus3
    ) -> WidgetTimeText? {
        WidgetTimeText(
            snapshot: snapshot(state, minutes: minutes), style: style, at: date, locale: locale, timeZone: timeZone)
    }

    /// ICU separates "PM" with a narrow no-break space; the tests read it as a plain space.
    static func plain(_ text: WidgetTimeText?) -> String? {
        guard case .clock(let clock, let tomorrow) = text?.form else { return nil }
        return clock.replacingOccurrences(of: "\u{202F}", with: " ") + (tomorrow ? " tomorrow" : "")
    }

    @Test func clockTimeInTheWidgetsTimeZone() {
        // 08:00 UTC + 10 h 13 min = 18:13 UTC. (Hours under 10 are left out: whether they get a
        // leading zero differs between ICU builds.)
        #expect(Self.plain(Self.text(.discharging, minutes: 613, timeZone: Self.plus3)) == "21:13")
        #expect(Self.plain(Self.text(.discharging, minutes: 613, timeZone: Self.minus8)) == "10:13")
        #expect(Self.text(.discharging, minutes: 133)?.direction == .empty)
        #expect(Self.text(.charging, minutes: 133)?.direction == .full)
    }

    @Test func twelveAndTwentyFourHourLocales() {
        // 08:00 UTC + 13 h 59 min = 21:59 UTC = 13:59 in UTC−8.
        let minutes = 13 * 60 + 59
        #expect(
            Self.plain(Self.text(.charging, minutes: minutes, locale: Self.enUS, timeZone: Self.minus8)) == "1:59 PM")
        #expect(Self.plain(Self.text(.charging, minutes: minutes, locale: Self.enGB, timeZone: Self.minus8)) == "13:59")
        #expect(Self.plain(Self.text(.charging, minutes: minutes, locale: Self.ruRU, timeZone: Self.minus8)) == "13:59")
    }

    /// The edge 0.6.1 got wrong: an end after local midnight is tomorrow's.
    @Test func anEndAfterLocalMidnightIsTomorrow() {
        // 11:00 in UTC+3; 13 h later is 00:00 tomorrow, 12 h 59 min later 23:59 today.
        #expect(Self.plain(Self.text(.discharging, minutes: 12 * 60 + 59, timeZone: Self.plus3)) == "23:59")
        #expect(Self.text(.discharging, minutes: 13 * 60, timeZone: Self.plus3)?.form.isTomorrow == true)
        #expect(Self.plain(Self.text(.discharging, minutes: 23 * 60, timeZone: Self.plus3)) == "10:00 tomorrow")
        #expect(
            Self.plain(Self.text(.charging, minutes: 13 * 60 + 30, locale: Self.enUS, timeZone: Self.plus3))
                == "12:30 AM tomorrow")
        // 00:00 in UTC−8: the same end is still today there.
        #expect(Self.plain(Self.text(.discharging, minutes: 13 * 60, timeZone: Self.minus8)) == "13:00")
        #expect(Self.plain(Self.text(.discharging, minutes: 23 * 60, timeZone: Self.minus8)) == "23:00")
    }

    /// "Tomorrow" is decided at the entry's date: past midnight, the same end is today's.
    @Test func tomorrowIsRelativeToTheEntry() {
        let afterMidnight = Self.start.addingTimeInterval(13 * 3600 + 5 * 60)
        let text = WidgetTimeText(
            snapshot: Self.snapshot(.discharging, minutes: 23 * 60), style: .clockTime, at: afterMidnight,
            locale: Self.enGB, timeZone: Self.plus3)
        #expect(Self.plain(text) == "10:00")
    }

    @Test func anEndBeyondTomorrowShowsNoTime() {
        #expect(Self.text(.discharging, minutes: 3_000) == nil)
        #expect(Self.text(.discharging, minutes: 3_000, style: .timeLeft) == nil)
        #expect(Self.text(.charging, minutes: 65_534) == nil)
        // 11:00 today + 36 h 59 min = 23:59 tomorrow; a minute more is the day after.
        #expect(Self.plain(Self.text(.discharging, minutes: 36 * 60 + 59)) == "23:59 tomorrow")
        #expect(Self.text(.discharging, minutes: 37 * 60) == nil)
    }

    /// The end comes from the reading's time, never the entry's: a later entry shows the same
    /// clock time.
    @Test func theEndComesFromTheReadingsTime() {
        let later = Self.start.addingTimeInterval(45 * 60)
        let first = Self.text(.discharging, minutes: 600)
        let stale = Self.text(.discharging, minutes: 600, at: later)
        #expect(first?.end == Self.start.addingTimeInterval(600 * 60))
        #expect(stale == first)
        #expect(Self.plain(stale) == "21:00")
    }

    @Test func noTimeWithoutAnEstimateOrOnceItHasPassed() {
        #expect(Self.text(.charged, minutes: 30) == nil)
        #expect(Self.text(.notCharging, minutes: 30) == nil)
        #expect(Self.text(.charging, minutes: 0) == nil)
        #expect(Self.text(.charging, minutes: 20, at: Self.start.addingTimeInterval(20 * 60)) == nil)
    }

    @Test func timeLeftKeepsTheEnd() {
        let text = Self.text(.charging, minutes: 133, style: .timeLeft)
        #expect(text == WidgetTimeText(direction: .full, end: Self.start.addingTimeInterval(133 * 60), form: .timeLeft))
    }

    /// The time the stale entry shows is the first entry's, through the timeline's own plan.
    @Test func theStaleEntryShowsTheFirstEntrysClockTime() throws {
        let snapshot = Self.snapshot(.discharging, minutes: 600)
        let plan = WidgetTimelinePlan(snapshot: snapshot, at: Self.start)
        let texts = plan.entries.filter(\.showsEstimate).map {
            WidgetTimeText(snapshot: snapshot, style: .clockTime, at: $0.date, locale: Self.enGB, timeZone: Self.plus3)
        }
        #expect(try #require(plan.entries.last).isStale)
        #expect(texts.count == 2)
        #expect(Set(texts.map(Self.plain)) == ["21:00"])
    }
}

extension WidgetTimeText.Form {
    var isTomorrow: Bool {
        if case .clock(_, let tomorrow) = self { tomorrow } else { false }
    }
}
