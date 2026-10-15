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
        #expect(plan.entries == [.init(date: Self.start, showsEstimate: true)])
        #expect(plan.nextReload == Self.minutes(30))
        #expect(WidgetTimelinePlan(snapshot: nil, at: Self.start).nextReload == Self.minutes(30))
    }

    @Test func aLongEstimateOutlastsTheTimeline() {
        let plan = Self.plan(.discharging, timeToEmptyMinutes: 600)
        #expect(plan.entries == [.init(date: Self.start, showsEstimate: true)])
        #expect(plan.nextReload == Self.minutes(30))
    }

    /// The maintainer's widget read "Full at 17:39" half an hour after it was full.
    @Test func anEstimateEndingBeforeTheReloadIsDroppedThen() {
        let plan = Self.plan(.charging, timeToFullMinutes: 12)
        #expect(
            plan.entries == [
                .init(date: Self.start, showsEstimate: true), .init(date: Self.minutes(12), showsEstimate: false),
            ])
        #expect(plan.nextReload == Self.minutes(12))
    }

    @Test func aShortEstimateStillWaitsTheMinimumBeforeReloading() {
        let plan = Self.plan(.charging, timeToFullMinutes: 2)
        #expect(plan.entries.last == .init(date: Self.minutes(2), showsEstimate: false))
        #expect(plan.nextReload == Self.minutes(5))
    }

    @Test func anEstimateThatHasRunOutIsNotShown() {
        let plan = Self.plan(.charging, timeToFullMinutes: 0)
        #expect(plan.entries == [.init(date: Self.start, showsEstimate: false)])
        #expect(plan.nextReload == Self.minutes(5))
    }

    /// Only the estimate that matches the state counts: a stale time to full while on battery
    /// doesn't shorten the timeline.
    @Test func theEstimateFollowsTheChargeState() {
        let plan = Self.plan(.discharging, timeToFullMinutes: 3, timeToEmptyMinutes: 300)
        #expect(plan.entries.count == 1)
        #expect(plan.nextReload == Self.minutes(30))
    }
}
