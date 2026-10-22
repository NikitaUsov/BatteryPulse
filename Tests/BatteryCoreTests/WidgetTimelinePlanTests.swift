import Foundation
import Testing

@testable import BatteryCore

struct WidgetTimelinePlanTests {
    static let start = Date(timeIntervalSince1970: 1_800_000_000)

    static func plan(_ state: ChargeState, timeToFullMinutes: Int? = nil, timeToEmptyMinutes: Int? = nil)
        -> WidgetTimelinePlan
    {
        var s = BatterySnapshot(timestamp: start)
        s.chargePercent = 90
        s.chargeState = state
        s.timeToFullMinutes = timeToFullMinutes
        s.timeToEmptyMinutes = timeToEmptyMinutes
        return WidgetTimelinePlan(snapshot: s, at: start)
    }

    static func minutes(_ value: Double) -> Date { start.addingTimeInterval(value * 60) }

    @Test func withoutAnEstimateOneEntryAndTheRegularReload() {
        let plan = Self.plan(.charged)
        #expect(
            plan.entries == [
                .init(date: Self.start, showsEstimate: true),
                .init(date: Self.minutes(45), showsEstimate: false, isStale: true),
            ])
        #expect(plan.nextReload == Self.minutes(30))
        #expect(WidgetTimelinePlan(snapshot: nil, at: Self.start).nextReload == Self.minutes(30))
    }

    @Test func aLongEstimateOutlastsTheTimeline() {
        let plan = Self.plan(.discharging, timeToEmptyMinutes: 600)
        #expect(
            plan.entries == [
                .init(date: Self.start, showsEstimate: true),
                .init(date: Self.minutes(45), showsEstimate: true, isStale: true),
            ])
        #expect(plan.nextReload == Self.minutes(30))
    }

    /// The maintainer's widget read "Full at 17:39" half an hour after it was full.
    @Test func anEstimateEndingBeforeTheReloadIsDroppedThen() {
        let plan = Self.plan(.charging, timeToFullMinutes: 20)
        #expect(
            plan.entries == [
                .init(date: Self.start, showsEstimate: true), .init(date: Self.minutes(20), showsEstimate: false),
                .init(date: Self.minutes(45), showsEstimate: false, isStale: true),
            ])
        #expect(plan.nextReload == Self.minutes(20))
    }

    @Test func aShortEstimateStillWaitsTheMinimumBeforeReloading() {
        let plan = Self.plan(.charging, timeToFullMinutes: 2)
        #expect(plan.entries.dropLast().last == .init(date: Self.minutes(2), showsEstimate: false))
        #expect(plan.nextReload == Self.minutes(15))
    }

    @Test func anEstimateThatHasRunOutIsNotShown() {
        let plan = Self.plan(.charging, timeToFullMinutes: 0)
        #expect(
            plan.entries == [
                .init(date: Self.start, showsEstimate: false),
                .init(date: Self.minutes(45), showsEstimate: false, isStale: true),
            ])
        #expect(plan.nextReload == Self.minutes(15))
    }

    /// Through the taper the time to full stays at a few minutes: an hour of it takes at most
    /// four reloads, not one every few minutes.
    @Test func anEstimateThatKeepsRunningOutKeepsWithinTheBudget() {
        var date = Self.start
        var reloads = 0
        while date < Self.minutes(60) {
            var snapshot = BatterySnapshot(timestamp: date)
            snapshot.chargePercent = 98
            snapshot.chargeState = .charging
            snapshot.timeToFullMinutes = 3
            date = WidgetTimelinePlan(snapshot: snapshot, at: date).nextReload
            reloads += 1
        }
        #expect(reloads <= 4)
    }

    /// Only the estimate that matches the state counts: a stale time to full while on battery
    /// doesn't shorten the timeline.
    @Test func theEstimateFollowsTheChargeState() {
        let plan = Self.plan(.discharging, timeToFullMinutes: 3, timeToEmptyMinutes: 300)
        #expect(plan.entries.count == 2)
        #expect(plan.nextReload == Self.minutes(30))
    }
}
