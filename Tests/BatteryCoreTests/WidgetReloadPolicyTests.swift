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

    /// One awake day (E15), a snapshot a minute from 07:00 to 23:00, fed to the policy unchanged:
    /// unplugged at 07:00, 12:00 and 18:00, plugged in at 10:00, 13:00 and 22:00; 8 %/h on battery
    /// and 30 %/h charging, up to 80 %, where the state becomes "not charging". macOS's estimate
    /// arrives a minute after each plug change and follows the rate.
    struct Day {
        static let awakeHours = 16
        static let wake = 7 * 60
        static let unplugs: Set = [7 * 60, 12 * 60, 18 * 60]
        static let plugs: Set = [10 * 60, 13 * 60, 22 * 60]
        static let limit = 80

        /// Minutes since midnight, and the snapshot then.
        var minutes: [Int] = []
        var snapshots: [BatterySnapshot] = []

        init() {
            // In sixtieths of a percent, so the rates are whole steps a minute.
            var charge = Self.limit * 60
            var pluggedIn = false
            var changedAt = Self.wake
            for minute in Self.wake..<(Self.wake + Self.awakeHours * 60) {
                if Self.unplugs.contains(minute) || Self.plugs.contains(minute) {
                    pluggedIn = Self.plugs.contains(minute)
                    changedAt = minute
                }
                let percent = Double(charge) / 60
                let state: ChargeState =
                    !pluggedIn ? .discharging : charge < Self.limit * 60 ? .charging : .notCharging
                var snapshot = BatterySnapshot(timestamp: WidgetReloadPolicyTests.start)
                snapshot.chargePercent = percent
                snapshot.chargeState = state
                snapshot.isExternalPowerConnected = pluggedIn
                if minute > changedAt {
                    switch state {
                    case .discharging: snapshot.timeToEmptyMinutes = Int((percent / 8 * 60).rounded())
                    case .charging:
                        snapshot.timeToFullMinutes = Int(((Double(Self.limit) - percent) / 30 * 60).rounded())
                    default: break
                    }
                }
                minutes.append(minute)
                snapshots.append(snapshot)
                switch state {
                case .discharging: charge -= 8
                case .charging: charge = min(charge + 30, Self.limit * 60)
                default: break
                }
            }
        }
    }

    @Test func aDayStaysWithinThePolicysOwnMaximum() {
        let day = Day()
        var policy = WidgetReloadPolicy()
        let midnight = Self.start
        let reloads = zip(day.minutes, day.snapshots).map { minute, snapshot in
            policy.shouldReload(for: snapshot, at: midnight.addingTimeInterval(Double(minute) * 60))
        }
        let indices = day.snapshots.indices
        let plugChanges = indices.filter {
            Day.unplugs.contains(day.minutes[$0]) || Day.plugs.contains(day.minutes[$0])
        }
        let stateChanges = indices.filter { index in
            guard index > 0 else { return true }
            let (now, before) = (day.snapshots[index], day.snapshots[index - 1])
            return now.chargeState != before.chargeState
                || now.isExternalPowerConnected != before.isExternalPowerConnected
        }
        let otherStateChanges = Set(stateChanges).subtracting(plugChanges)
        let arrivals = indices.filter { index in
            index > 0 && WidgetTimelinePlan.estimateMinutes(day.snapshots[index - 1]) == nil
                && WidgetTimelinePlan.estimateMinutes(day.snapshots[index]) != nil
        }
        let movements = indices.filter { reloads[$0] && !stateChanges.contains($0) && !arrivals.contains($0) }

        // The day as the plan defines it: six plug changes, and the charge reaching 80 % twice.
        #expect(plugChanges.count == 6)
        #expect(otherStateChanges.count == 2)
        // Per plug change: the state reload, and at most one for the estimate's arrival.
        #expect(plugChanges.allSatisfy { reloads[$0] })
        for (start, end) in zip(plugChanges, plugChanges.dropFirst() + [indices.endIndex]) {
            #expect(arrivals.filter { (start..<end).contains($0) && reloads[$0] }.count <= 1)
        }
        // At most four movement reloads in any hour.
        for index in indices {
            let hour = day.minutes[index]..<(day.minutes[index] + 60)
            #expect(movements.filter { hour.contains(day.minutes[$0]) }.count <= 4)
        }
        let total = reloads.filter { $0 }.count
        #expect(total <= 2 * plugChanges.count + otherStateChanges.count + 4 * Day.awakeHours)
    }
}
