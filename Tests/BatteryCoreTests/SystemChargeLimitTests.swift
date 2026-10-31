import Foundation
import Testing

@testable import BatteryCore

/// macOS's Charge Limit holding the charge (``SystemChargeLimit``): bit 24 of `NotChargingReason`,
/// on external power, not charging, read from the real capture at an 80 % limit.
@Suite struct SystemChargeLimitTests {
    static let held = 0x0100_0000

    /// The capture's raw dictionaries, with `change` applied to AppleSmartBattery's.
    static func capture(_ change: (inout PropertyDictionary) -> Void = { _ in }) throws -> PropertyDictionary {
        var capture = try fixtureDictionary(Fixture.m5ChargeLimit.rawValue)
        var smartBattery = try #require(capture[BatteryReading.CaptureKey.smartBattery]?.dictionaryValue)
        change(&smartBattery)
        capture[BatteryReading.CaptureKey.smartBattery] = .dictionary(smartBattery)
        return capture
    }

    static func snapshot(_ capture: PropertyDictionary) -> BatterySnapshot {
        BatteryReading(rawCapture: capture, timestamp: Fixture.timestamp).snapshot
    }

    @Test func theCaptureIsAtTheLimit() throws {
        let reading = try Fixture.m5ChargeLimit.reading()
        // Bit 24, in AppleSmartBattery's ChargerData and in its AppleChargerData child.
        let top = try #require(reading.smartBattery["ChargerData"]?.dictionaryValue)
        #expect(top["NotChargingReason"]?.intValue == Self.held)
        #expect(RegistryChildren.chargerData(in: reading.smartBattery)["NotChargingReason"]?.intValue == Self.held)
        #expect(SystemChargeLimit.heldBit == Self.held)

        let s = reading.snapshot
        #expect(s.notChargingReason == Self.held)
        #expect(s.isExternalPowerConnected == true)
        #expect(s.chargeState == .notCharging)
        #expect(s.isOptimizedChargingEngaged == nil)
        #expect(s.chargePercent == 80)
        #expect(s.chargingCurrentMA == 0)
        #expect(s.isAtSystemChargeLimit)
        #expect(WidgetStateWord(s) == .chargedToLimit)
    }

    /// The other real captures (charging with reason 0; on battery, just plugged in and just
    /// unplugged with 0x80) and the hand-written ones are not at the limit.
    @Test(arguments: Fixture.allCases.filter { $0 != .m5ChargeLimit })
    func theOtherCapturesAreNot(_ fixture: Fixture) throws {
        let s = try fixture.snapshot()
        #expect(!s.isAtSystemChargeLimit)
        #expect((s.notChargingReason ?? 0) & Self.held == 0)
    }

    @Test func onBatteryTheBitIsNotTheLimit() throws {
        let s = Self.snapshot(
            try Self.capture {
                $0["ExternalConnected"] = .bool(false)
                $0["AppleRawExternalConnected"] = .bool(false)
            })
        #expect(s.notChargingReason == Self.held)
        #expect(s.isExternalPowerConnected == false)
        #expect(!s.isAtSystemChargeLimit)
        #expect(WidgetStateWord(s) == .onBattery)

        var unknown = try Fixture.m5ChargeLimit.snapshot()
        unknown.isExternalPowerConnected = nil
        #expect(!unknown.isAtSystemChargeLimit)
    }

    @Test func fullyChargedIsNotTheLimit() throws {
        let s = Self.snapshot(try Self.capture { $0["FullyCharged"] = .bool(true) })
        #expect(s.notChargingReason == Self.held)
        #expect(s.chargeState == .charged)
        #expect(!s.isAtSystemChargeLimit)
        #expect(WidgetStateWord(s) == .fullyCharged)
    }

    /// The parser's plug-in rule runs first: an SMC charge current at its threshold or above is
    /// charging, whatever the bit says.
    @Test func aMeasuredChargeCurrentIsCharging() throws {
        let pluggedIn = try fixtureDictionary(Fixture.m5PluggedIn10s.rawValue)
        let charging = try #require(pluggedIn[BatteryReading.CaptureKey.smc]?.dictionaryValue?["B0AC"])
        var capture = try Self.capture()
        var smc = try #require(capture[BatteryReading.CaptureKey.smc]?.dictionaryValue)
        smc["B0AC"] = charging
        capture[BatteryReading.CaptureKey.smc] = .dictionary(smc)

        let s = Self.snapshot(capture)
        let current = try #require(SMCBattery.liveElectrical(in: smc)?.currentMA)
        #expect(current >= MacPowerParser.chargingCurrentThresholdMA)
        #expect(s.notChargingReason == Self.held)
        #expect(s.chargeState == .charging)
        #expect(!s.isAtSystemChargeLimit)
        #expect(WidgetStateWord(s) == .charging)
    }

    @Test func theBitAmongOthersIsStillTheLimit() throws {
        var s = try Fixture.m5ChargeLimit.snapshot()
        for reason in [Self.held | 0x80, Self.held | 0x1000, Self.held | 0x1000_0000] {
            s.notChargingReason = reason
            #expect(s.isAtSystemChargeLimit, "\(reason)")
            #expect(WidgetStateWord(s) == .chargedToLimit)
        }
        // Other bits without it stay "Not charging".
        for reason in [0, 0x80, 0x1000, 0x0080_0000, 0x0200_0000, nil] {
            s.notChargingReason = reason
            #expect(!s.isAtSystemChargeLimit, "\(String(describing: reason))")
            #expect(WidgetStateWord(s) == .notCharging)
        }
    }

    /// Optimized Battery Charging's flag names its cause, while bit 24 may be shared: its hold
    /// wins, and reads "Charging on hold".
    @Test func theOptimizedHoldWins() throws {
        var s = try Fixture.m5ChargeLimit.snapshot()
        s.isOptimizedChargingEngaged = true
        #expect(!s.isAtSystemChargeLimit)
        #expect(WidgetStateWord(s) == .chargingOnHold)
        s.isOptimizedChargingEngaged = false
        #expect(s.isAtSystemChargeLimit)
        #expect(WidgetStateWord(s) == .chargedToLimit)
    }

    /// The hold can start with no change of the charge state, so the motion key has a part of its
    /// own for it, and the Overview's sentence and Power's row move with it.
    @Test func theMotionKeyChangesWithTheHoldAlone() throws {
        let held = try Fixture.m5ChargeLimit.snapshot()
        var notHeld = held
        notHeld.notChargingReason = 0x80
        #expect(held.chargeState == notHeld.chargeState)
        let heldKey = BatteryMotionKey(held)
        let notHeldKey = BatteryMotionKey(notHeld)
        #expect(heldKey.isAtSystemChargeLimit)
        #expect(!notHeldKey.isAtSystemChargeLimit)
        #expect(heldKey != notHeldKey)
        var same = notHeldKey
        same.isAtSystemChargeLimit = true
        #expect(same == heldKey, "only the hold differs")
        #expect(!BatteryMotionKey(nil).isAtSystemChargeLimit)
    }

    // MARK: The widget

    static func plan(
        _ snapshot: BatterySnapshot, _ size: WidgetSize,
        _ configuration: BatteryWidgetConfiguration = BatteryWidgetConfiguration()
    ) throws -> BatteryWidgetLayout {
        let entry = try #require(WidgetTimelinePlan(snapshot: snapshot, at: snapshot.timestamp).entries.first)
        let plan = WidgetLayoutPlan.make(
            size: size, configuration: configuration, snapshot: snapshot, entry: entry,
            formatter: BatteryFormatter(locale: Locale(identifier: "en_US")), timeZone: .gmt)
        guard case .battery(let layout) = plan else {
            Issue.record("No battery in \(plan)")
            throw CancellationError()
        }
        return layout
    }

    /// The state line reads "Charged to limit" in every size, Automatic included, and VoiceOver's
    /// charge element reads it with the charge.
    @Test(arguments: WidgetSize.allCases)
    func theStateLineSaysIt(_ size: WidgetSize) throws {
        let layout = try Self.plan(try Fixture.m5ChargeLimit.snapshot(), size)
        #expect(layout.lines.first == .state(.chargedToLimit))
        #expect(layout.level.state == .chargedToLimit)
        #expect(layout.chargeLabel.keys == ["Battery charge: %@, %@", "Charged to limit"])
        #expect(layout.level.text == BatteryFormatter(locale: Locale(identifier: "en_US")).percent(80))
        #expect(layout.chargeLabel.text { $0 } == "Battery charge: \(layout.level.text), Charged to limit")
    }

    /// The field reads "Reached" while the limit holds the charge and is dropped otherwise, like
    /// any value the reading lacks.
    @Test func theFieldShowsOnlyWhileTheLimitHolds() throws {
        let formatter = BatteryFormatter(locale: Locale(identifier: "en_US"))
        let held = try Fixture.m5ChargeLimit.snapshot()
        let row = try #require(WidgetRow(.systemChargeLimit, snapshot: held, time: nil, formatter: formatter))
        #expect(row.value == .reached)
        #expect(row.tier == .normal)
        #expect(row.cue == nil)
        #expect(row.spokenLabel == .phrases([.key("Charge limit"), .key("Reached")]))
        for fixture in Fixture.allCases where fixture != .m5ChargeLimit {
            let s = try fixture.snapshot()
            #expect(WidgetRow(.systemChargeLimit, snapshot: s, time: nil, formatter: formatter) == nil, "\(fixture)")
        }
        var optimized = held
        optimized.isOptimizedChargingEngaged = true
        #expect(WidgetRow(.systemChargeLimit, snapshot: optimized, time: nil, formatter: formatter) == nil)
    }

    /// Custom's Details offers it; Automatic's lists keep their details.
    @Test func onlyCustomShowsTheField() throws {
        for size in WidgetSize.allCases {
            #expect(!WidgetLayoutPlan.automatic(size).contains(.systemChargeLimit))
        }
        let held = try Fixture.m5ChargeLimit.snapshot()
        let custom = BatteryWidgetConfiguration(layout: .custom, details: [.systemChargeLimit, .adapter])

        let medium = try Self.plan(held, .medium, custom)
        #expect(medium.details.first == .row(WidgetRow(field: .systemChargeLimit, value: .reached)))
        #expect(
            WidgetAccessibility.elements(.battery(medium)).contains(.phrases([.key("Charge limit"), .key("Reached")])))

        // Small's one detail is a line, in the time line's place.
        let small = try Self.plan(held, .small, custom)
        #expect(small.lines.contains(.detail(WidgetRow(field: .systemChargeLimit, value: .reached))))

        // Off the limit, the row is left out and the next detail moves up.
        var notHeld = held
        notHeld.notChargingReason = 0x80
        let without = try Self.plan(notHeld, .medium, custom)
        let fields = without.details.compactMap { detail -> BatteryWidgetField? in
            guard case .row(let row) = detail else { return nil }
            return row.field
        }
        #expect(fields == [.adapter])
    }

    // MARK: Reloads

    /// The held capture, and the same Mac charging below the limit, just plugged in with bit 7, and
    /// on battery.
    static func states() throws -> (
        held: BatterySnapshot, charging: BatterySnapshot, pluggedIn: BatterySnapshot, onBattery: BatterySnapshot
    ) {
        let held = try Fixture.m5ChargeLimit.snapshot()
        var charging = held
        charging.chargeState = .charging
        charging.notChargingReason = 0
        charging.chargePercent = 79
        var pluggedIn = held
        pluggedIn.notChargingReason = 0x80
        pluggedIn.chargePercent = 78
        var onBattery = pluggedIn
        onBattery.chargeState = .discharging
        onBattery.isExternalPowerConnected = false
        onBattery.adapter = nil
        #expect(!charging.isAtSystemChargeLimit && !pluggedIn.isAtSystemChargeLimit)
        #expect(held.chargePercent == 80)
        return (held, charging, pluggedIn, onBattery)
    }

    /// Feeds one planner a reading per minute from minute 0, the first its start value.
    static func reloads(_ snapshots: [BatterySnapshot]) -> [WidgetReloadPlanner.Reason?] {
        var planner = WidgetReloadPlanner()
        return snapshots.enumerated().map { minute, snapshot in
            planner.battery(snapshot, at: WidgetReloadPolicyTests.start.addingTimeInterval(Double(minute) * 60))
        }
    }

    /// The hold usually starts with charging → not charging, which the policy reloads for at once:
    /// one reload, and an hour at the limit adds none.
    @Test func theHoldStartsWithOneReloadThroughTheStateChange() throws {
        let s = try Self.states()
        let result = Self.reloads([s.charging, s.charging] + Array(repeating: s.held, count: 61))
        #expect(result[2] == .policy)
        #expect(result.compactMap { $0 } == [.policy])
    }

    /// Plugged in at 78 % under an 80 % limit: not charging with bit 7, then bit 24 with no state
    /// change, which is one reload of its own; an hour at the limit adds none.
    @Test func aHoldWithoutAStateChangeReloadsOnce() throws {
        let s = try Self.states()
        #expect(s.pluggedIn.chargeState == s.held.chargeState)
        let result = Self.reloads([s.onBattery, s.pluggedIn, s.held] + Array(repeating: s.held, count: 60))
        #expect(Array(result.prefix(3)) == [nil, .policy, .systemChargeLimit])
        #expect(result.compactMap { $0 } == [.policy, .systemChargeLimit])
    }

    /// The hold ending without a state change reloads too, within the 5 minutes the immediate
    /// reasons share.
    @Test func theHoldsEndSharesTheImmediateInterval() throws {
        let s = try Self.states()
        var lowPower = s.pluggedIn
        lowPower.isLowPowerModeEnabled = true
        var lowPowerHeld = s.held
        lowPowerHeld.isLowPowerModeEnabled = true
        // Low Power Mode at minute 1, the hold at minute 3 (too soon: it waits), then held.
        let result = Self.reloads([
            s.pluggedIn, lowPower, lowPower, lowPowerHeld, lowPowerHeld, lowPowerHeld, lowPowerHeld,
        ])
        #expect(result == [nil, .lowPowerMode, nil, nil, nil, nil, .systemChargeLimit])
        // Back to bit 7 alone, with no state change.
        var planner = WidgetReloadPlanner()
        let start = WidgetReloadPolicyTests.start
        #expect(planner.battery(s.held, at: start) == nil)
        #expect(planner.battery(s.pluggedIn, at: start.addingTimeInterval(60)) == .systemChargeLimit)
    }
}
