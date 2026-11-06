import Foundation
import Testing

@testable import BatteryCore

/// Why a Mac on its adapter isn't charging (``NotChargingCause``): a cause only where a real
/// capture proves it, after the plug-in rule and the optimized flag, and Apple's possible reasons
/// where none is proven.
@Suite struct NotChargingCauseTests {
    /// `fixture`'s raw dictionaries with the SMC's charge current (`B0AC`) set to `currentMA`.
    static func capture(_ fixture: Fixture, smcCurrentMA currentMA: Int) throws -> PropertyDictionary {
        var capture = try fixtureDictionary(fixture.rawValue)
        var smc = try #require(capture[BatteryReading.CaptureKey.smc]?.dictionaryValue)
        var current = try #require(smc["B0AC"]?.dictionaryValue)
        // `si16`, little-endian like the M5's own readings.
        let bits = UInt16(bitPattern: Int16(currentMA))
        current["Bytes"] = .data(Data([UInt8(bits & 0xFF), UInt8(bits >> 8)]))
        smc["B0AC"] = .dictionary(current)
        #expect(SMCBattery.liveElectrical(in: smc)?.currentMA == currentMA)
        capture[BatteryReading.CaptureKey.smc] = .dictionary(smc)
        return capture
    }

    static func snapshot(_ capture: PropertyDictionary) -> BatterySnapshot {
        BatteryReading(rawCapture: capture, timestamp: Fixture.timestamp).snapshot
    }

    // MARK: No capture, no cause

    /// Every case names a real capture in `Fixtures/` that gives it, so a case can't come without
    /// the capture that proves it.
    @Test(arguments: NotChargingCause.allCases)
    func eachCauseHasTheCaptureThatProvesIt(_ cause: NotChargingCause) throws {
        #expect(!cause.fixture.hasPrefix("synthetic-"), "A hand-written capture proves nothing")
        #expect(
            Bundle.module.url(forResource: cause.fixture, withExtension: "plist", subdirectory: "Fixtures") != nil,
            "Fixtures/\(cause.fixture).plist")
        // A case of `Fixture`, so the other suites read it too.
        let fixture = try #require(Fixture(rawValue: cause.fixture))
        let s = try fixture.snapshot()
        #expect(s.notChargingCause == cause)
        #expect(!s.isNotChargingWithoutCause)
    }

    /// Each capture gives its own cause, if it proves one, and no other: the Charge Limit's gives
    /// the Charge Limit; the others, the hand-written ones included, give none.
    @Test(arguments: Fixture.allCases)
    func eachCaptureGivesOnlyItsOwnCause(_ fixture: Fixture) throws {
        let s = try fixture.snapshot()
        #expect(s.notChargingCause == NotChargingCause.allCases.first { $0.fixture == fixture.rawValue })
        // None of them is on the adapter without charging and without a cause: just plugged in,
        // the SMC already reads the charge current.
        #expect(!s.isNotChargingWithoutCause)
    }

    @Test func theChargeLimitsCaptureIsItsCause() throws {
        let s = try Fixture.m5ChargeLimit.snapshot()
        #expect(s.notChargingCause == .systemChargeLimit)
        #expect(s.isAtSystemChargeLimit)
        #expect(WidgetStateWord(s) == .chargedToLimit)
        #expect(NotChargingCause.systemChargeLimit.fixture == Fixture.m5ChargeLimit.rawValue)
    }

    /// Bit 7 on the adapter is no cause: 10 s after a plug-in the registry still said "not
    /// charging" with 0x80 while the SMC read the charge current. Without the SMC's reading the
    /// state is "Not charging" with no cause, and the main window offers Apple's possible reasons.
    @Test func bit7OnTheAdapterIsNoCause() throws {
        let s = try Fixture.m5PluggedIn10s.snapshot()
        #expect(s.notChargingReason == 0x80)
        #expect(s.isExternalPowerConnected == true)
        #expect(s.chargeState == .charging)
        #expect(s.notChargingCause == nil)
        #expect(!s.isNotChargingWithoutCause)

        var capture = try fixtureDictionary(Fixture.m5PluggedIn10s.rawValue)
        capture[BatteryReading.CaptureKey.smc] = nil
        let registryOnly = Self.snapshot(capture)
        #expect(registryOnly.chargeState == .notCharging)
        #expect(registryOnly.notChargingCause == nil)
        #expect(registryOnly.isNotChargingWithoutCause)
        #expect(WidgetStateWord(registryOnly) == .notCharging)
    }

    // MARK: Precedence

    /// The parser's plug-in rule comes first: an SMC charge current at its threshold is charging,
    /// whatever bit 24 says; just below it, the Charge Limit still holds.
    @Test func aMeasuredChargeCurrentIsChargingWithNoCause() throws {
        let threshold = MacPowerParser.chargingCurrentThresholdMA
        let below = Self.snapshot(try Self.capture(.m5ChargeLimit, smcCurrentMA: threshold - 1))
        #expect(below.chargeState == .notCharging)
        #expect(below.notChargingCause == .systemChargeLimit)

        let at = Self.snapshot(try Self.capture(.m5ChargeLimit, smcCurrentMA: threshold))
        #expect(at.notChargingReason == SystemChargeLimit.heldBit)
        #expect(at.chargeState == .charging)
        #expect(at.notChargingCause == nil)
        #expect(!at.isNotChargingWithoutCause)
    }

    /// Optimized Battery Charging's flag comes next and wins over bit 24: its hold reads "Charging
    /// on hold", which names its own cause, and gives no case until a capture of the Mac's own
    /// battery shows it. Nor does the main window offer the possible reasons there.
    @Test func theOptimizedFlagWinsOverBit24() throws {
        var s = try Fixture.m5ChargeLimit.snapshot()
        s.isOptimizedChargingEngaged = true
        #expect(s.notChargingCause == nil)
        #expect(!s.isNotChargingWithoutCause)
        #expect(WidgetStateWord(s) == .chargingOnHold)
        s.notChargingReason = 0x80
        #expect(s.notChargingCause == nil)
        #expect(!s.isNotChargingWithoutCause)
        s.isOptimizedChargingEngaged = false
        s.notChargingReason = SystemChargeLimit.heldBit
        #expect(s.notChargingCause == .systemChargeLimit)
    }

    /// The bits BatteryPulse doesn't decode name no cause: bit 7, bit 12, the bits beside bit 24,
    /// none at all. On the adapter, not charging, the main window then offers the possible reasons.
    @Test func undecodedBitsNameNoCause() throws {
        var s = try Fixture.m5ChargeLimit.snapshot()
        for reason in [nil, 0, 0x80, 0x1000, 0x0080_0000, 0x0200_0000, 0x1000_0000] {
            s.notChargingReason = reason
            #expect(s.notChargingCause == nil, "\(String(describing: reason))")
            #expect(s.isNotChargingWithoutCause, "\(String(describing: reason))")
            #expect(WidgetStateWord(s) == .notCharging)
        }
        // Bit 24 among others is still the Charge Limit.
        for reason in [SystemChargeLimit.heldBit | 0x80, SystemChargeLimit.heldBit | 0x1000] {
            s.notChargingReason = reason
            #expect(s.notChargingCause == .systemChargeLimit, "\(reason)")
            #expect(!s.isNotChargingWithoutCause)
        }
    }

    /// Each capture in every state, external power, optimized flag and reason.
    static func variations() throws -> [BatterySnapshot] {
        let states: [ChargeState] = [.charging, .discharging, .charged, .notCharging, .unknown]
        let reasons: [Int?] = [nil, 0, 0x80, SystemChargeLimit.heldBit, SystemChargeLimit.heldBit | 0x80]
        var snapshots: [BatterySnapshot] = []
        for fixture in Fixture.allCases {
            var s = try fixture.snapshot()
            for external in [true, false, nil] as [Bool?] {
                s.isExternalPowerConnected = external
                for state in states {
                    s.chargeState = state
                    for optimized in [nil, false, true] as [Bool?] {
                        s.isOptimizedChargingEngaged = optimized
                        for reason in reasons {
                            s.notChargingReason = reason
                            snapshots.append(s)
                        }
                    }
                }
            }
        }
        return snapshots
    }

    /// A cause, or the possible reasons, only on the adapter while not charging: on battery, while
    /// charging, when full or unknown nothing is named, whatever the bits say. And the possible
    /// reasons go exactly with the state word "Not charging", the Charge Limit with "Charged to
    /// limit".
    @Test func onlyNotChargingOnTheAdapterIsExplained() throws {
        for s in try Self.variations() {
            let label = "\(s.chargeState) \(String(describing: s.isExternalPowerConnected))"
            if s.isExternalPowerConnected != true || s.chargeState != .notCharging {
                #expect(s.notChargingCause == nil, "\(label)")
                #expect(!s.isNotChargingWithoutCause, "\(label)")
            }
            #expect(!(s.notChargingCause != nil && s.isNotChargingWithoutCause), "\(label)")
            let word = WidgetStateWord(s)
            #expect(s.isNotChargingWithoutCause == (word == .notCharging && s.isExternalPowerConnected == true))
            #expect((s.notChargingCause == .systemChargeLimit) == (word == .chargedToLimit))
            #expect(s.isAtSystemChargeLimit == (s.notChargingCause == .systemChargeLimit))
        }
    }
}
