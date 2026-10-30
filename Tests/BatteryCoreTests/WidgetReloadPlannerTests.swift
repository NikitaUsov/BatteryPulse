import Foundation
import Testing

@testable import BatteryCore

struct WidgetReloadPlannerTests {
    typealias Day = WidgetReloadPolicyTests.Day
    typealias Reason = WidgetReloadPlanner.Reason

    static let start = WidgetReloadPolicyTests.start

    static func at(minutes: Double) -> Date {
        start.addingTimeInterval(minutes * 60)
    }

    /// A reading on battery that nothing else changes.
    static func snapshot(
        percent: Double = 80, lowPower: Bool = false, thermal: ThermalState = .nominal, condition: String? = nil,
        temperature: Double? = 30, adapter: PowerAdapter? = nil
    ) -> BatterySnapshot {
        BatterySnapshot(
            timestamp: start, chargePercent: percent, chargeState: .discharging, isExternalPowerConnected: false,
            healthCondition: condition, temperatureCelsius: temperature, adapter: adapter,
            isLowPowerModeEnabled: lowPower, thermalState: thermal)
    }

    /// Feeds `(minutes, snapshot)` to one planner; the first is its start value.
    static func battery(_ steps: [(Double, BatterySnapshot)]) -> [Reason?] {
        var planner = WidgetReloadPlanner()
        return steps.map { minutes, snapshot in planner.battery(snapshot, at: at(minutes: minutes)) }
    }

    // MARK: The first evaluation

    /// The value the app finds at its start is what the widget shows: the planner records it
    /// without a reload. The first real change reloads once.
    @Test func theStartValueIsRecordedWithoutAReload() {
        let charging = BatterySnapshot(
            timestamp: Self.start, chargePercent: 80, chargeState: .charging, isExternalPowerConnected: true)
        #expect(
            Self.battery([(0, Self.snapshot()), (1, Self.snapshot()), (2, charging), (3, charging)])
                == [nil, nil, .policy, nil])

        var planner = WidgetReloadPlanner()
        let mouse = Self.accessory("mouse", percent: 50)
        #expect(planner.accessories([mouse], at: Self.at(minutes: 0)) == nil)
        #expect(planner.accessories([mouse], at: Self.at(minutes: 1)) == nil)
        #expect(planner.accessories([], at: Self.at(minutes: 2)) == .connection)
        #expect(planner.accessories([], at: Self.at(minutes: 3)) == nil)
    }

    /// At the start the time of the widget's last reload is unknown, so a percent step needn't
    /// wait for the interval.
    @Test func aStepRightAfterTheStartReloads() {
        #expect(Self.battery([(0, Self.snapshot(percent: 80)), (1, Self.snapshot(percent: 77))]) == [nil, .policy])
    }

    // MARK: The new Battery reasons

    /// A Low Power Mode flip, entering serious heat, a return to nominal and a condition change
    /// each reload at once, at most once per 5 minutes between them.
    @Test func immediateReasonsReloadAtOnceAtMostEveryFiveMinutes() {
        let result = Self.battery([
            (0, Self.snapshot()),
            (1, Self.snapshot(lowPower: true)),
            // Too soon after the flip; it waits, and goes through once the 5 minutes have passed.
            (3, Self.snapshot(lowPower: true, thermal: .serious)),
            (5, Self.snapshot(lowPower: true, thermal: .serious)),
            (6, Self.snapshot(lowPower: true, thermal: .serious)),
            (12, Self.snapshot(lowPower: true, thermal: .nominal)),
            (20, Self.snapshot(lowPower: true, condition: "Service Recommended")),
            (21, Self.snapshot(lowPower: false, condition: "Service Recommended")),
            (25, Self.snapshot(lowPower: false, condition: "Service Recommended")),
        ])
        #expect(result == [nil, .lowPowerMode, nil, nil, .heat, .heat, .condition, nil, .lowPowerMode])
    }

    /// A reason that went away while it waited needs no reload.
    @Test func aFlipBackWithinFiveMinutesReloadsNothing() {
        let result = Self.battery([
            (0, Self.snapshot()), (1, Self.snapshot(lowPower: true)), (2, Self.snapshot(lowPower: false)),
            (3, Self.snapshot(lowPower: true)), (7, Self.snapshot(lowPower: true)),
        ])
        #expect(result == [nil, .lowPowerMode, nil, nil, nil])
    }

    /// Critical is as hot as serious, and fair keeps the heat until the state is back at
    /// nominal: a state flapping between fair and serious reloads once on the way in.
    @Test func heatHasHysteresis() {
        let states: [ThermalState] = [.nominal, .fair, .serious, .fair, .serious, .critical, .fair, .serious, .fair]
        var steps = states.enumerated().map { (Double($0.offset * 6), Self.snapshot(thermal: $0.element)) }
        steps.append((60, Self.snapshot(thermal: .nominal)))
        #expect(Self.battery(steps) == [nil, nil, .heat, nil, nil, nil, nil, nil, nil, .heat])
    }

    /// The heat follows every reading, so a change that waited for the 5 minutes still reloads
    /// once they have passed, even with the state at fair by then.
    @Test func aHeatChangeThatWaitedStillReloads() {
        let result = Self.battery([
            (0, Self.snapshot()), (1, Self.snapshot(lowPower: true)),
            (2, Self.snapshot(lowPower: true, thermal: .serious)), (4, Self.snapshot(lowPower: true, thermal: .fair)),
            (6, Self.snapshot(lowPower: true, thermal: .fair)), (7, Self.snapshot(lowPower: true, thermal: .fair)),
            (20, Self.snapshot(lowPower: true, thermal: .nominal)),
        ])
        #expect(result == [nil, .lowPowerMode, nil, nil, .heat, nil, .heat])
    }

    /// A Mac that starts hot shows it already; an unknown state changes nothing.
    @Test func startingHotReloadsOnlyAtNominal() {
        var cooling = Self.snapshot()
        cooling.thermalState = nil
        let result = Self.battery([
            (0, Self.snapshot(thermal: .critical)), (6, Self.snapshot(thermal: .fair)), (12, cooling),
            (18, Self.snapshot(thermal: .nominal)),
        ])
        #expect(result == [nil, nil, nil, .heat])
    }

    @Test func theAdaptersWattsOrWirelessFlagReloadAtOnce() {
        let plugged = BatterySnapshot(
            timestamp: Self.start, chargePercent: 80, chargeState: .charging, isExternalPowerConnected: true,
            adapter: PowerAdapter(watts: 70, isWireless: false))
        var stronger = plugged
        stronger.adapter?.watts = 96
        var wireless = stronger
        wireless.adapter?.isWireless = true
        var renamed = wireless
        renamed.adapter?.name = "Another name"
        let result = Self.battery([(0, plugged), (1, stronger), (7, wireless), (13, renamed)])
        #expect(result == [nil, .adapter, .adapter, nil])
    }

    /// No condition, an empty one and "Normal" read the same.
    @Test func onlyAConditionTheWidgetWordsDifferentlyReloads() {
        let result = Self.battery([
            (0, Self.snapshot(condition: nil)), (6, Self.snapshot(condition: "")),
            (12, Self.snapshot(condition: "Normal")),
            (18, Self.snapshot(condition: "Good")), (24, Self.snapshot(condition: "Service Recommended")),
        ])
        #expect(result == [nil, nil, nil, nil, .condition])
    }

    /// A 3 °C move waits for the 15-minute interval since the kind's last reload, like a percent
    /// step; a smaller one never reloads.
    @Test func aTemperatureMoveWaitsForTheInterval() {
        let result = Self.battery([
            (0, Self.snapshot(temperature: 30)),
            (1, Self.snapshot(lowPower: true, temperature: 30)),
            // Three degrees, but only 9 minutes after the flip's reload.
            (10, Self.snapshot(lowPower: true, temperature: 33)),
            (16, Self.snapshot(lowPower: true, temperature: 33)),
            // 2.5 degrees from the shown 33, long after.
            (60, Self.snapshot(lowPower: true, temperature: 35.5)),
            (61, Self.snapshot(lowPower: true, temperature: nil)),
        ])
        #expect(result == [nil, .lowPowerMode, nil, .temperature, nil, nil])
    }

    /// A percent step after a reload for another reason counts from what that reload showed, and
    /// waits 15 minutes from it.
    @Test func anotherReasonsReloadRecordsWhatThePolicyShows() {
        let result = Self.battery([
            (0, Self.snapshot(percent: 80)), (20, Self.snapshot(percent: 78, lowPower: true)),
            // Three points from the start's 80, one from the 78 the flip showed.
            (25, Self.snapshot(percent: 77, lowPower: true)),
            // Three points from 78, but 10 minutes after the flip's reload; then 15.
            (30, Self.snapshot(percent: 75, lowPower: true)), (35, Self.snapshot(percent: 75, lowPower: true)),
        ])
        #expect(result == [nil, .lowPowerMode, nil, nil, .policy])
    }

    // MARK: Days

    /// The reasons of every evaluation of `snapshots`, taken at `minutes` since midnight.
    static func reloads(_ snapshots: [BatterySnapshot], minutes: [Int]) -> [Reason?] {
        var planner = WidgetReloadPlanner()
        return zip(minutes, snapshots).map { minute, snapshot in
            planner.battery(snapshot, at: at(minutes: Double(minute)))
        }
    }

    /// What 0.6.x's policy, alone, reloads on the same day (E15's count).
    static func policyCount(_ snapshots: [BatterySnapshot], minutes: [Int]) -> Int {
        var policy = WidgetReloadPolicy()
        return zip(minutes, snapshots).count(where: { minute, snapshot in
            policy.shouldReload(for: snapshot, at: at(minutes: Double(minute)))
        })
    }

    /// E15's own bound: `2 × plug changes + other state changes + 4 × awake hours`.
    static let e15Bound = 2 * 6 + 2 + 4 * Day.awakeHours

    /// E15's synthetic day through the planner: within 0.6.x's count plus 7.
    @Test func e15sDayStaysWithinTodaysCountPlusSeven() {
        let day = Day()
        let reasons = Self.reloads(day.snapshots, minutes: day.minutes)
        let today = Self.policyCount(day.snapshots, minutes: day.minutes)
        let count = reasons.count(where: { $0 != nil })
        #expect(reasons.allSatisfy { $0 == nil || $0 == .policy })
        // The same reloads, less the first reading, which the planner records as shown.
        #expect(count == today - 1)
        #expect(count <= today + 7)
        #expect(count <= Self.e15Bound + 7)
    }

    /// E15's day plus two Low Power Mode flips, a condition change, and a thermal state flapping
    /// between fair and serious every 2 minutes for an hour.
    struct HarderDay {
        static let lowPowerOn = 9 * 60 + 30
        static let lowPowerOff = 11 * 60 + 30
        static let flapping = (14 * 60)..<(15 * 60)
        static let conditionChange = 16 * 60 + 30

        var minutes: [Int]
        var snapshots: [BatterySnapshot]

        init() {
            let day = Day()
            minutes = day.minutes
            snapshots = zip(day.minutes, day.snapshots).map { minute, snapshot in
                var snapshot = snapshot
                snapshot.isLowPowerModeEnabled = (Self.lowPowerOn..<Self.lowPowerOff).contains(minute)
                snapshot.thermalState =
                    if Self.flapping.contains(minute) {
                        (minute - Self.flapping.lowerBound) / 2 % 2 == 0 ? .fair : .serious
                    } else {
                        .nominal
                    }
                snapshot.healthCondition = minute >= Self.conditionChange ? "Service Recommended" : "Normal"
                return snapshot
            }
        }
    }

    @Test func aHarderDayStaysWithinTodaysCountPlusSeven() {
        let day = HarderDay()
        let reasons = Self.reloads(day.snapshots, minutes: day.minutes)
        let plain = Day()
        let today = Self.policyCount(plain.snapshots, minutes: plain.minutes)
        let count = reasons.count(where: { $0 != nil })
        #expect(count <= today + 7)
        #expect(count <= Self.e15Bound + 7)
        // Each new reason reloads, the heat once on the way in and once back at nominal.
        let immediate = reasons.compactMap { $0 }.filter { $0 != .policy }
        #expect(immediate.count(where: { $0 == .lowPowerMode }) == 2)
        #expect(immediate.count(where: { $0 == .condition }) == 1)
        #expect(immediate.count(where: { $0 == .heat }) == 2)
        let heat = reasons.indices.filter { reasons[$0] == .heat }.map { day.minutes[$0] }
        #expect(heat.first.map { HarderDay.flapping.contains($0) } == true)
        #expect(heat.last == HarderDay.flapping.upperBound)
    }

    // MARK: Accessories

    static func accessory(
        _ id: String, percent: Int, kind: AccessoryKind = .mouse, parts: [AccessoryPartRole: Int]? = nil
    ) -> AccessoryBattery {
        let parts = (parts ?? [.single: percent]).sorted { $0.key.rawValue < $1.key.rawValue }
            .map { AccessoryPart(role: $0.key, percent: $0.value) }
        return AccessoryBattery(id: "acc-\(id)", name: id, kind: kind, transport: .bluetooth, parts: parts)
    }

    /// A disconnect 5 minutes after a reload reloads at once; a 10-point step 5 minutes after one
    /// waits until 15 minutes have passed.
    @Test func connectionsReloadAtOnceStepsWait() {
        var planner = WidgetReloadPlanner()
        let keyboard = Self.accessory("keyboard", percent: 90, kind: .keyboard)
        func reason(_ accessories: [AccessoryBattery], _ minutes: Double) -> Reason? {
            planner.accessories(accessories, at: Self.at(minutes: minutes))
        }
        #expect(reason([keyboard], 0) == nil)
        #expect(reason([keyboard, Self.accessory("mouse", percent: 60)], 1) == .connection)
        #expect(reason([keyboard], 6) == .connection)
        #expect(reason([Self.accessory("keyboard", percent: 80, kind: .keyboard)], 11) == nil)
        #expect(reason([Self.accessory("keyboard", percent: 80, kind: .keyboard)], 20) == nil)
        #expect(reason([Self.accessory("keyboard", percent: 80, kind: .keyboard)], 21) == .level)
        // Nine points from the shown 80, then ten.
        #expect(reason([Self.accessory("keyboard", percent: 71, kind: .keyboard)], 60) == nil)
        #expect(reason([Self.accessory("keyboard", percent: 70, kind: .keyboard)], 61) == .level)
    }

    /// Any part's step counts; a part that appears or goes away is no step, and the accessory stays
    /// connected.
    @Test func everyPartsLevelCounts() {
        var planner = WidgetReloadPlanner()
        let buds: [AccessoryPartRole: Int] = [.left: 90, .right: 90, .case: 50]
        #expect(planner.accessories([Self.accessory("buds", percent: 0, parts: buds)], at: Self.at(minutes: 0)) == nil)
        let withoutCase: [AccessoryPartRole: Int] = [.left: 85, .right: 85]
        #expect(
            planner.accessories([Self.accessory("buds", percent: 0, parts: withoutCase)], at: Self.at(minutes: 30))
                == nil)
        let leftLow: [AccessoryPartRole: Int] = [.left: 80, .right: 85]
        #expect(
            planner.accessories([Self.accessory("buds", percent: 0, parts: leftLow)], at: Self.at(minutes: 31))
                == .level)
    }

    /// A day of accessories: a keyboard and a mouse all day, draining slowly, and earbuds that
    /// connect three times, draining fast while in use.
    struct AccessoryDay {
        static let sessions = [(8 * 60, 9 * 60 + 30), (12 * 60 + 30, 13 * 60 + 30), (19 * 60, 21 * 60)]

        var minutes: [Int] = []
        var lists: [[AccessoryBattery]] = []

        init() {
            for minute in Day.wake..<(Day.wake + Day.awakeHours * 60) {
                let hours = Double(minute - Day.wake) / 60
                var list = [
                    WidgetReloadPlannerTests.accessory("keyboard", percent: Int(100 - hours), kind: .keyboard),
                    WidgetReloadPlannerTests.accessory("mouse", percent: Int(60 - 2 * hours)),
                ]
                if let session = Self.sessions.first(where: { ($0.0..<$0.1).contains(minute) }) {
                    // 20 % an hour in use, from full: the case charged them in between.
                    let bud = Int(100 - 20 * Double(minute - session.0) / 60)
                    list.append(
                        WidgetReloadPlannerTests.accessory(
                            "buds", percent: 0, kind: .headphones, parts: [.left: bud, .right: bud, .case: 70]))
                }
                minutes.append(minute)
                lists.append(list)
            }
        }
    }

    static func accessoryReloads(_ day: AccessoryDay) -> [Reason?] {
        var planner = WidgetReloadPlanner()
        return zip(day.minutes, day.lists).map { minute, list in
            planner.accessories(list, at: at(minutes: Double(minute)))
        }
    }

    @Test func anAccessoryDayStaysWellWithinItsBudget() {
        let reasons = Self.accessoryReloads(AccessoryDay())
        // Every connect and disconnect, and few steps: the buds' 20 points an hour, the mouse's 2.
        #expect(reasons.count(where: { $0 == .connection }) == 2 * AccessoryDay.sessions.count)
        #expect(reasons.count(where: { $0 == .level }) <= 12)
        // The low end of WidgetKit's daily budget for one widget.
        #expect(reasons.count(where: { $0 != nil }) < 40)
    }

    /// Every MVP kind placed (Battery on the harder day, Accessories): under 100 app-initiated
    /// reloads a day.
    @Test func everyKindPlacedStaysUnderAHundredADay() {
        let battery = HarderDay()
        let batteryCount = Self.reloads(battery.snapshots, minutes: battery.minutes).count(where: { $0 != nil })
        let accessoryCount = Self.accessoryReloads(AccessoryDay()).count(where: { $0 != nil })
        #expect(batteryCount < 70)
        #expect(accessoryCount < 40)
        #expect(batteryCount + accessoryCount < 100)
    }

    // MARK: Launch

    @Test func aLanguageChangeReloadsAtLaunch() {
        let reason = WidgetReloadPlanner.launchReason
        #expect(reason(false, "en", "en") == nil)
        #expect(reason(true, "en", "en") == .update)
        #expect(reason(false, "en", "ru") == .language)
        #expect(reason(true, "ru", "en") == .language)
        // The first launch that stores the language: only the version decides.
        #expect(reason(true, nil, "ru") == .update)
        #expect(reason(false, nil, "ru") == nil)
        #expect(reason(false, "ru", nil) == nil)
        #expect(WidgetReloadPlanner.LaunchReason.language.reloadsAnyway)
        #expect(!WidgetReloadPlanner.LaunchReason.update.reloadsAnyway)
    }

    // MARK: Placements

    /// Nothing is reloaded for a kind a non-empty answer leaves out; an empty answer, a failure and
    /// no answer at all count as every kind placed.
    @Test func onlyANonEmptyAnswerSkipsAKind() {
        var placements = WidgetPlacements()
        #expect(WidgetKindID.allCases.allSatisfy(placements.isPlaced))
        placements.record(answer: [WidgetKindID.battery.rawValue, WidgetKindID.battery.rawValue], at: Self.start)
        #expect(placements.isPlaced(.battery))
        #expect(!placements.isPlaced(.accessories))
        placements.record(
            answer: [WidgetKindID.accessories.rawValue, "io.github.nikitausov.BatteryPulse.other"], at: Self.start)
        #expect(!placements.isPlaced(.battery))
        #expect(placements.isPlaced(.accessories))
        placements.record(answer: [], at: Self.start)
        #expect(placements.isPlaced(.battery))
        #expect(placements.isPlaced(.accessories))
        placements.record(answer: [WidgetKindID.battery.rawValue], at: Self.start)
        placements.recordFailure(at: Self.start)
        #expect(placements.isPlaced(.accessories))
    }

    /// WidgetKit is asked before the first reload, and again only when the answer would skip the
    /// kind that is due and is 15 minutes old.
    @Test func theAnswerIsAskedAgainOnlyWhenItSkipsAndIsOld() {
        var placements = WidgetPlacements()
        #expect(placements.needsAnswer(toReload: .battery, at: Self.start))
        placements.record(answer: [WidgetKindID.battery.rawValue], at: Self.start)
        #expect(!placements.needsAnswer(toReload: .battery, at: Self.at(minutes: 600)))
        #expect(!placements.needsAnswer(toReload: .accessories, at: Self.at(minutes: 14)))
        #expect(placements.needsAnswer(toReload: .accessories, at: Self.at(minutes: 15)))
        // A clock set back can't tell the answer's age.
        #expect(placements.needsAnswer(toReload: .accessories, at: Self.at(minutes: -1)))
        placements.recordFailure(at: Self.start)
        #expect(!placements.needsAnswer(toReload: .accessories, at: Self.at(minutes: 600)))
        placements.record(answer: [], at: Self.start)
        #expect(!placements.needsAnswer(toReload: .accessories, at: Self.at(minutes: 600)))
    }

    @Test func countsPerKind() {
        let battery = WidgetKindID.battery.rawValue
        #expect(WidgetPlacements.counts(in: []) == [.battery: 0, .accessories: 0])
        #expect(
            WidgetPlacements.counts(in: [battery, battery, WidgetKindID.accessories.rawValue, "other"])
                == [.battery: 2, .accessories: 1])
    }
}
