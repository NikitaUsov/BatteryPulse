import Foundation
import Testing

@testable import BatteryCore

struct WidgetReloadPolicyTests {
    /// Feeds readings to one policy; each step is (percent, state, plugged in, seconds from the start).
    static func reloads(_ steps: [(Double, ChargeState, Bool, TimeInterval)]) -> [Bool] {
        let start = Date(timeIntervalSince1970: 1_800_000_000)
        var policy = WidgetReloadPolicy()
        return steps.map { percent, state, plugged, seconds in
            var s = BatterySnapshot(timestamp: start)
            s.chargePercent = percent
            s.chargeState = state
            s.isExternalPowerConnected = plugged
            return policy.shouldReload(for: s, at: start.addingTimeInterval(seconds))
        }
    }

    @Test func firstReadingReloads() {
        #expect(Self.reloads([(80, .discharging, false, 0), (80, .discharging, false, 3600)]) == [true, false])
    }

    @Test func plugAndStateChangesReloadAtOnce() {
        let result = Self.reloads([
            (80, .discharging, false, 0), (80, .charging, true, 1), (80, .notCharging, true, 2),
            (80, .discharging, false, 3),
        ])
        #expect(result == [true, true, true, true])
    }

    @Test func percentNeedsBothAStepAndTime() {
        let result = Self.reloads([
            (80, .discharging, false, 0),
            // Five points down, but too soon.
            (75, .discharging, false, 600),
            // Half an hour later, but only four points from what the widget shows.
            (76, .discharging, false, 1800),
            (75, .discharging, false, 1800),
            (71, .discharging, false, 3600),
        ])
        #expect(result == [true, false, false, true, false])
    }
}
