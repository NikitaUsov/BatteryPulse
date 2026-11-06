import Foundation
import Testing

@testable import BatteryCore

/// W-6's review: Clear History and recording off rewrite the feed at once, and so do reads off and
/// Forget, but a placed widget kept showing what they removed until its own timeline's reload. The
/// kinds that show the removed section now reload once the rewrite is done, at once within their
/// immediate reasons' shared minimum, and a removal that waited at the next evaluation after it.
struct RemovalReloadPlannerTests {
    static func at(minutes: Double) -> Date {
        WidgetReloadPlannerTests.at(minutes: minutes)
    }

    /// The history's removal reloads the large Battery widget and the History widget; the devices'
    /// the iPhone & iPad widget. The Accessories widget shows neither.
    @Test func aRemovalReloadsTheKindsThatShowIt() {
        var planner = WidgetReloadPlanner()
        #expect(
            planner.removal(of: .history, at: Self.at(minutes: 0)) == [
                .init(.battery, .removal), .init(.history, .removal),
            ])
        #expect(planner.removal(of: .devices, at: Self.at(minutes: 0)).map(\.kind) == [.devices])
        #expect(WidgetReloadPlanner.Reason.removal.rawValue == "removal")
    }

    /// Within 5 minutes of the kind's last immediate reload, a removal waits, and reloads at the
    /// first evaluation after the minimum, once; nothing reloads on its own in between.
    @Test func aRemovalWithinTheMinimumWaitsForTheNextEvaluation() {
        var planner = WidgetReloadPlanner()
        #expect(planner.removal(of: .devices, at: Self.at(minutes: 0)).map(\.kind) == [.devices])
        #expect(planner.removal(of: .devices, at: Self.at(minutes: 2)).map(\.kind) == [])
        #expect(planner.pendingReloads(at: Self.at(minutes: 4)).map(\.kind) == [])
        #expect(planner.pendingReloads(at: Self.at(minutes: 5)).map(\.kind) == [.devices])
        #expect(planner.pendingReloads(at: Self.at(minutes: 6)).map(\.kind) == [])
        // Each kind has its own minimum: the history's removal doesn't wait for the devices'.
        #expect(planner.removal(of: .history, at: Self.at(minutes: 6)).map(\.kind) == [.battery, .history])
    }

    /// The Battery kind's removal shares the minimum of its five immediate reasons: a Low Power
    /// Mode flip right before it makes it wait, and it makes the next flip wait.
    @Test func theBatteryKindsRemovalSharesItsImmediateMinimum() {
        var planner = WidgetReloadPlanner()
        let off = WidgetReloadPlannerTests.snapshot()
        let on = WidgetReloadPlannerTests.snapshot(lowPower: true)
        #expect(planner.battery(off, at: Self.at(minutes: 0)) == nil)
        #expect(planner.battery(on, at: Self.at(minutes: 1)) == .lowPowerMode)
        #expect(planner.removal(of: .history, at: Self.at(minutes: 2)).map(\.kind) == [.history])
        #expect(planner.pendingReloads(at: Self.at(minutes: 6)).map(\.kind) == [.battery])
        #expect(planner.battery(off, at: Self.at(minutes: 7)) == nil)
        #expect(planner.battery(off, at: Self.at(minutes: 11)) == .lowPowerMode)
    }

    /// Clear History and recording off take the history out; recording on, a plug change and the
    /// routine write take nothing out, and a device's read is told apart by its caller.
    @Test func whichWritesRemove() {
        typealias Reason = WidgetFeed.WriteReason
        #expect(Reason.historyCleared.removes(recordsHistory: true) == [.history])
        #expect(Reason.recording.removes(recordsHistory: false) == [.history])
        #expect(Reason.recording.removes(recordsHistory: true) == [])
        for reason in [Reason.step, .devices, .plug, .demoEnded, .language] {
            #expect(reason.removes(recordsHistory: false) == [], "\(reason)")
        }
    }

    /// Reads off and a device gone take devices out of the feed; a new reading or a new device
    /// doesn't.
    @Test func whichDeviceChangesRemove() {
        func content(_ keys: [Character], reads: Bool = true, percent: Double = 50) -> WidgetFeed.DevicesContent {
            WidgetFeed.DevicesContent(
                readsDevices: reads,
                remembered: keys.map { DevicesReloadPlannerTests.device(WidgetFeed.sampleKey($0), percent: percent) },
                modelNames: [:])
        }
        let two = content(["1", "2"])
        #expect(content(["1"]).removesDevices(since: two))
        #expect(content(["1", "2"], reads: false).removesDevices(since: two))
        #expect(!content(["1", "2", "3"]).removesDevices(since: two))
        #expect(!content(["1", "2"], percent: 80).removesDevices(since: two))
        #expect(!content(["1", "2"]).removesDevices(since: content([], reads: false)))
    }
}
