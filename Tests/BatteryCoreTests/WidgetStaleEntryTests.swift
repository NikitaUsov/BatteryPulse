import Foundation
import Testing

@testable import BatteryCore

/// The stale entry that ends every widget timeline, and the rules it keeps.
struct WidgetStaleEntryTests {
    static let start = WidgetTimelinePlanTests.start

    static func snapshot(_ state: ChargeState, minutes: Int?) -> BatterySnapshot {
        var s = BatterySnapshot(timestamp: start)
        s.chargePercent = 60
        s.chargeState = state
        s.timeToFullMinutes = state == .charging ? minutes : nil
        s.timeToEmptyMinutes = state == .discharging ? minutes : nil
        return s
    }

    /// Every estimate from none to two days, in both directions, and the other states.
    static var plans: [(BatterySnapshot?, WidgetTimelinePlan)] {
        var snapshots: [BatterySnapshot?] = [nil]
        for state in ChargeState.allCases {
            snapshots.append(snapshot(state, minutes: nil))
            for minutes in Array(0...120) + [180, 600, 3_000] {
                snapshots.append(snapshot(state, minutes: minutes))
            }
        }
        return snapshots.map { ($0, WidgetTimelinePlan(snapshot: $0, at: start)) }
    }

    @Test func theStaleEntryComesLastAfterEveryPlannedReload() throws {
        for (snapshot, plan) in Self.plans {
            let stale = try #require(plan.entries.last)
            #expect(stale.isStale, "\(String(describing: snapshot))")
            #expect(stale.date == Self.start.addingTimeInterval(WidgetTimelinePlan.staleAge))
            #expect(stale.date > plan.nextReload)
            #expect(plan.entries.dropLast().allSatisfy { !$0.isStale && $0.date < stale.date })
            #expect(plan.entries.count <= WidgetTimelinePlan.maximumEntries)
            #expect(plan.entries.map(\.date) == plan.entries.map(\.date).sorted())
            #expect(plan.nextReload >= Self.start.addingTimeInterval(WidgetTimelinePlan.minimumReloadInterval))
        }
    }

    /// No entry shows an estimate whose time has passed by the entry's date.
    @Test func noEntryShowsAPassedTime() {
        for (snapshot, plan) in Self.plans {
            guard let snapshot, let minutes = WidgetTimelinePlan.estimateMinutes(snapshot) else { continue }
            let end = snapshot.timestamp.addingTimeInterval(Double(minutes) * 60)
            for entry in plan.entries where entry.showsEstimate {
                #expect(end > entry.date, "\(minutes) min at \(entry.date)")
            }
        }
    }

    /// An estimate that ends after the regular reload but before the stale entry would show a
    /// passed time if WidgetKit postponed the reload: an entry at its end drops it.
    @Test(arguments: [31, 35, 44])
    func anEstimateEndingBetweenTheReloadAndTheStaleEntryIsDropped(minutes: Int) {
        let plan = WidgetTimelinePlan(snapshot: Self.snapshot(.discharging, minutes: minutes), at: Self.start)
        let end = Self.start.addingTimeInterval(Double(minutes) * 60)
        #expect(
            plan.entries == [
                .init(date: Self.start, showsEstimate: true), .init(date: end, showsEstimate: false),
                .init(date: Self.start.addingTimeInterval(45 * 60), showsEstimate: false, isStale: true),
            ])
        #expect(plan.nextReload == Self.start.addingTimeInterval(30 * 60))
    }

    @Test func anEstimateOutlastingTheStaleEntryStillShowsThere() {
        let plan = WidgetTimelinePlan(snapshot: Self.snapshot(.charging, minutes: 46), at: Self.start)
        #expect(plan.entries.count == 2)
        #expect(plan.entries.last?.showsEstimate == true)
    }

    /// The stale entry counts from the reading's time, even when the widget's own clock is a
    /// moment later (a reading shared by a burst of reloads).
    @Test func theStaleEntryCountsFromTheReadingOrLater() {
        var s = Self.snapshot(.discharging, minutes: 600)
        s.timestamp = Self.start.addingTimeInterval(-3)
        let plan = WidgetTimelinePlan(snapshot: s, at: Self.start)
        #expect(plan.entries.last?.date == Self.start.addingTimeInterval(45 * 60))
    }

    @Test func accessoriesReadEveryHalfHour() {
        let plan = WidgetTimelinePlan.accessories(at: Self.start)
        #expect(plan.nextReload == Self.start.addingTimeInterval(30 * 60))
        #expect(plan.nextReload >= Self.start.addingTimeInterval(WidgetTimelinePlan.minimumReloadInterval))
        #expect(plan.entries.map(\.isStale) == [false, true])
        #expect(plan.entries.last?.date == Self.start.addingTimeInterval(45 * 60))
    }
}
