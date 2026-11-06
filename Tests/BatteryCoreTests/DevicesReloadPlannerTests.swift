import Foundation
import Testing

@testable import BatteryCore

/// When the app reloads the iPhone & iPad kind: a new reading that moved a device's charge 3
/// points, changed its state or read a device for the first time, at most every 15 minutes.
struct DevicesReloadPlannerTests {
    typealias Reason = WidgetReloadPlanner.Reason
    typealias Day = WidgetReloadPlannerTests.Day

    static func at(minutes: Double) -> Date {
        WidgetReloadPlannerTests.at(minutes: minutes)
    }

    static func device(
        _ key: DeviceKey, percent: Double? = 50, state: ChargeState = .discharging, minutes: Double = 0
    ) -> RememberedDevice {
        RememberedDevice(
            id: key, identity: IDeviceIdentity(name: "iPhone", deviceClass: "iPhone"),
            battery: IDeviceBattery(chargePercent: percent, chargeState: state), at: at(minutes: minutes))
    }

    static let phone = WidgetFeed.sampleKey("1")
    static let pad = WidgetFeed.sampleKey("2")

    /// Feeds `(minutes, devices)` to one planner; the first is its start value.
    static func devices(_ steps: [(Double, [RememberedDevice])]) -> [Reason?] {
        var planner = WidgetReloadPlanner()
        return steps.map { minutes, devices in planner.devices(devices, at: at(minutes: minutes)) }
    }

    /// The start value is recorded without a reload; a 3-point move, a state change and a device
    /// read for the first time reload; a smaller move doesn't.
    @Test func aNewReadingReloadsWhenItMovedEnough() {
        let result = Self.devices([
            (0, [Self.device(Self.phone, percent: 50)]),
            (20, [Self.device(Self.phone, percent: 52)]),
            (40, [Self.device(Self.phone, percent: 53)]),
            (60, [Self.device(Self.phone, percent: 53, state: .charging)]),
            (80, [Self.device(Self.phone, percent: 53, state: .charging), Self.device(Self.pad, percent: 90)]),
            (100, [Self.device(Self.phone, percent: 53, state: .charging), Self.device(Self.pad, percent: 90)]),
            // A charge the reading lost counts as a change, and so does one it found.
            (120, [Self.device(Self.phone, percent: nil, state: .charging), Self.device(Self.pad, percent: 90)]),
            (140, [Self.device(Self.phone, percent: 60, state: .charging), Self.device(Self.pad, percent: 90)]),
        ])
        #expect(result == [nil, nil, .reading, .reading, .reading, nil, .reading, .reading])
    }

    /// At most every 15 minutes: a change that waited reloads at the first evaluation after the
    /// interval, if the reading still differs from what the kind showed.
    @Test func aReadingReloadsAtMostEveryQuarterHour() {
        let result = Self.devices([
            (0, [Self.device(Self.phone, percent: 20, state: .charging)]),
            (5, [Self.device(Self.phone, percent: 25, state: .charging)]),
            (10, [Self.device(Self.phone, percent: 30, state: .charging)]),
            (15, [Self.device(Self.phone, percent: 35, state: .charging)]),
            (20, [Self.device(Self.phone, percent: 40, state: .charging)]),
            (25, [Self.device(Self.phone, percent: 45, state: .charging)]),
            // Back within a step of what it showed before the interval was up: nothing to reload.
            (30, [Self.device(Self.phone, percent: 41, state: .charging)]),
            (35, [Self.device(Self.phone, percent: 41, state: .charging)]),
            (40, [Self.device(Self.phone, percent: 45, state: .charging)]),
        ])
        #expect(result == [nil, .reading, nil, nil, .reading, nil, nil, nil, .reading])
    }

    /// Demo Mode's iPhone never counts, and a device no longer remembered only leaves the record:
    /// Forget reloads through the feed's removal.
    @Test func demoAndForgottenDevicesDontReload() {
        let result = Self.devices([
            (0, [Self.device(Self.phone)]),
            (20, [Self.device(Self.phone), Self.device(.demo, percent: 10)]),
            (40, []),
            // Remembered again later, it is new.
            (60, [Self.device(Self.phone)]),
        ])
        #expect(result == [nil, nil, nil, .reading])
    }

    /// A device read every 5 minutes while it is on its cable (`IDeviceSchedule`): two charges a
    /// day from 20 % at a point a minute, full on the cable for the rest of each, and an iPad on
    /// the evening's cable too. The reloads stay well within the kind's budget beside its 48
    /// half-hourly timelines.
    struct DeviceDay {
        static let sessions = [(7 * 60, 9 * 60 + 30), (21 * 60, 23 * 60)]

        var minutes: [Int] = []
        var lists: [[RememberedDevice]] = []

        init() {
            var phonePercent = 20.0
            var lastSession: Int?
            for minute in stride(from: Day.wake, to: Day.wake + Day.awakeHours * 60, by: 5) {
                guard let index = Self.sessions.firstIndex(where: { ($0.0..<$0.1).contains(minute) }) else {
                    continue
                }
                if lastSession != index {
                    phonePercent = 20
                    lastSession = index
                }
                phonePercent = min(100, phonePercent + 5)
                let state: ChargeState = phonePercent < 100 ? .charging : .charged
                var list = [
                    DevicesReloadPlannerTests.device(
                        DevicesReloadPlannerTests.phone, percent: phonePercent, state: state, minutes: Double(minute))
                ]
                if minute >= 12 * 60 {
                    list.append(DevicesReloadPlannerTests.device(DevicesReloadPlannerTests.pad, percent: 70))
                }
                minutes.append(minute)
                lists.append(list)
            }
        }
    }

    static func deviceReloads(_ day: DeviceDay) -> [Reason?] {
        var planner = WidgetReloadPlanner()
        return zip(day.minutes, day.lists).map { minute, list in
            planner.devices(list, at: at(minutes: Double(minute)))
        }
    }

    @Test func aDeviceDayStaysWellWithinItsBudget() {
        let reasons = Self.deviceReloads(DeviceDay())
        #expect(reasons.allSatisfy { $0 == nil || $0 == .reading })
        let count = reasons.count(where: { $0 != nil })
        // A reload per quarter hour of charging at most, and the full charge's state.
        #expect(count >= 6 && count <= 18)
        // Within the low end of WidgetKit's daily budget for one widget, beside its own
        // half-hourly timelines and the feed's writes (``WriteEffectTests/FeedDay``).
        #expect(count + 48 + (WriteEffectTests.feedReloads()[.devices] ?? 0) < 70)
    }

    /// Every kind placed (Battery on the harder day, Accessories, History, iPhone & iPad), with the
    /// feed's writes that reload them (``WriteEffectTests/FeedDay``): under 100 app-initiated
    /// reloads a day.
    @Test func everyKindPlacedStaysUnderAHundredADay() {
        typealias Planner = WidgetReloadPlannerTests
        let battery = WidgetReloadPlannerTests.HarderDay()
        let batteryCount = Planner.reloads(battery.snapshots, minutes: battery.minutes).count(where: { $0 != nil })
        let accessoryCount = Planner.accessoryReloads(Planner.AccessoryDay()).count(where: { $0 != nil })
        let historyCount = Planner.historyReloads(battery.snapshots, minutes: battery.minutes).count(where: {
            $0 != nil
        })
        let deviceCount = Self.deviceReloads(DeviceDay()).count(where: { $0 != nil })
        let feed = WriteEffectTests.feedReloads()
        #expect(deviceCount <= 18)
        #expect(batteryCount + (feed[.battery] ?? 0) < 70)
        #expect(accessoryCount + (feed[.accessories] ?? 0) < 40)
        #expect(batteryCount + accessoryCount + historyCount + deviceCount + feed.values.reduce(0, +) < 100)
    }
}
