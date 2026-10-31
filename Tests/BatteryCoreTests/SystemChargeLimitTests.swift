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
}
