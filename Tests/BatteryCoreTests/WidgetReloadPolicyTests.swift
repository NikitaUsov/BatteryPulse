import Foundation
import Testing

@testable import BatteryCore

struct WidgetReloadPolicyTests {
    static let start = Date(timeIntervalSince1970: 1_800_000_000)

    /// One reading `seconds` from the start; `minutes` is macOS's time to empty (or to full).
    struct Step {
        var percent: Double
        var state: ChargeState = .discharging
        var plugged = false
        var minutes: Int? = nil
        var seconds: TimeInterval
    }

    /// Feeds readings to one policy.
    static func reloads(_ steps: [Step]) -> [Bool] {
        var policy = WidgetReloadPolicy()
        return steps.map { step in
            var s = BatterySnapshot(timestamp: start)
            s.chargePercent = step.percent
            s.chargeState = step.state
            s.isExternalPowerConnected = step.plugged
            s.timeToEmptyMinutes = step.state == .discharging ? step.minutes : nil
            s.timeToFullMinutes = step.state == .charging ? step.minutes : nil
            return policy.shouldReload(for: s, at: start.addingTimeInterval(step.seconds))
        }
    }

    @Test func firstReadingReloads() {
        #expect(Self.reloads([Step(percent: 80, seconds: 0), Step(percent: 80, seconds: 3600)]) == [true, false])
    }

    @Test func plugAndStateChangesReloadAtOnce() {
        let result = Self.reloads([
            Step(percent: 80, seconds: 0), Step(percent: 80, state: .charging, plugged: true, seconds: 1),
            Step(percent: 80, state: .notCharging, plugged: true, seconds: 2), Step(percent: 80, seconds: 3),
        ])
        #expect(result == [true, true, true, true])
    }

    @Test func percentNeedsBothAStepAndTime() {
        let result = Self.reloads([
            Step(percent: 80, seconds: 0),
            // Three points down, but too soon.
            Step(percent: 77, seconds: 600),
            // A quarter of an hour later, but only two points from what the widget shows.
            Step(percent: 78, seconds: 900),
            Step(percent: 77, seconds: 900),
            Step(percent: 75, seconds: 1200),
        ])
        #expect(result == [true, false, false, true, false])
    }

    /// The first estimate after unplugging comes a minute or so after the reload for the unplug.
    @Test func theFirstEstimateReloadsAtOnce() {
        let result = Self.reloads([
            Step(percent: 100, state: .charged, plugged: true, seconds: 0),
            Step(percent: 100, seconds: 10),
            Step(percent: 100, minutes: 500, seconds: 70),
            Step(percent: 100, minutes: 505, seconds: 130),
        ])
        #expect(result == [true, true, true, false])
    }

    /// The maintainer's widget read "Lasts until about 17:15" while the app said 16:39: the
    /// estimate had moved by half an hour since the widget's reading.
    @Test func aMovedEstimateReloadsAfterTheInterval() {
        let result = Self.reloads([
            Step(percent: 100, minutes: 505, seconds: 0),
            // The clock time moved 39 minutes earlier, but too soon.
            Step(percent: 100, minutes: 465, seconds: 60),
            Step(percent: 99, minutes: 451, seconds: 900),
            // Half an hour later, but the clock time moved only 9 minutes from the shown one.
            Step(percent: 98, minutes: 430, seconds: 2700),
        ])
        #expect(result == [true, false, true, false])
    }
}
