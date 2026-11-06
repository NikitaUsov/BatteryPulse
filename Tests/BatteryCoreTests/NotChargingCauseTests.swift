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

    // MARK: The text report

    /// The report's "Not charging reason" names a proven cause after the hex; without one the hex
    /// stands alone, and on battery the line stays out.
    @Test func theReportNamesTheCause() throws {
        func line(_ s: BatterySnapshot) -> String? {
            BatteryReport.lines(for: s).first { $0.label == "Not charging reason" }?.value
        }
        let held = try Fixture.m5ChargeLimit.snapshot()
        #expect(line(held) == "0x1000000 (Charge Limit)")
        #expect(BatteryReport.text(for: held).contains("Not charging reason  0x1000000 (Charge Limit)\n"))
        for cause in NotChargingCause.allCases {
            #expect(!BatteryReport.causeName(cause).isEmpty)
        }

        var noCause = held
        noCause.notChargingReason = 0x80
        #expect(line(noCause) == "0x80")
        var optimized = held
        optimized.isOptimizedChargingEngaged = true
        #expect(line(optimized) == "0x1000000")
        var onBattery = held
        onBattery.isExternalPowerConnected = false
        onBattery.chargeState = .discharging
        #expect(line(onBattery) == nil)
        #expect(line(try Fixture.m5OnBattery.snapshot()) == nil)
    }

    // MARK: Raw Data

    /// Raw Data's description of the reason keeps the Charge Limit's bit and adds what the M5's
    /// captures show, 0x80 on battery and right after a plug-in, as an observation: bit 7 gets no
    /// meaning, and neither does bit 12 or the charger's own inhibit reason.
    @Test func rawDataObservesBit7WithoutAMeaning() throws {
        let rows = RawSection.sections(for: try Fixture.m5PluggedIn10s.reading().rawCapture).flatMap(\.rows)
        let reasons = rows.filter { $0.key.hasSuffix("ChargerData.NotChargingReason") }
        #expect(reasons.count == 2)
        for row in reasons {
            #expect(row.decoded == .bits(0x80, setBits: [7]), "\(row.key)")
            let summary = try #require(row.info?.summary)
            #expect(summary.contains("Bit 24 (0x01000000) is set while the Charge Limit holds the charge."))
            #expect(
                summary.hasSuffix(
                    " On the MacBook Air M5 sampled, it reads 0x80 on battery and for the first seconds after plugging in."
                ))
            #expect(!summary.contains("Bit 7") && !summary.contains("Bit 12"))
        }
        let inhibit = try #require(rows.first { $0.key.hasSuffix("ChargerData.ChargerInhibitReason") })
        #expect(inhibit.info?.summary == "Bitfield of reasons the charger itself is inhibited.")
    }

    // MARK: Motion

    /// The cause is a part of the motion key, so the sentence that names it moves once when the
    /// cause comes or goes, even with no other change; the next reading's live values never move it.
    @Test func theMotionKeyFollowsTheCause() throws {
        let held = try Fixture.m5ChargeLimit.snapshot()
        let key = BatteryMotionKey(held)
        #expect(key.notChargingCause == .systemChargeLimit)
        var noCause = held
        noCause.notChargingReason = 0x80
        let other = BatteryMotionKey(noCause)
        #expect(other.notChargingCause == nil)
        #expect(other != key)
        var same = other
        same.notChargingCause = .systemChargeLimit
        #expect(same == key, "only the cause differs")

        var next = held
        next.voltageMV = held.voltageMV.map { $0 + 6 }
        next.amperageMA = 3
        next.systemLoadMW = held.systemLoadMW.map { $0 + 900 }
        #expect(next != held)
        #expect(BatteryMotionKey(next) == key)

        #expect(BatteryMotionKey(nil).notChargingCause == nil)
        #expect(BatteryMotionKey(device: nil).notChargingCause == nil)
    }

    // MARK: Demo Mode

    static func snapshot(_ scenario: DemoScenario) -> BatterySnapshot? {
        scenario.battery?.reading(at: Fixture.timestamp).snapshot
    }

    /// Each cause has a Demo Mode scene that gives it through the real parser, by the same
    /// decision, so its look is reviewed without the real state.
    @Test(arguments: NotChargingCause.allCases)
    func eachCauseHasADemoScene(_ cause: NotChargingCause) {
        #expect(DemoScenario.allCases.contains { Self.snapshot($0)?.notChargingCause == cause })
    }

    /// One scene is on the adapter and not charging with no cause, as the M5 read 10 s after a
    /// plug-in, for the main window's possible reasons; the Charge Limit's scene gives its cause,
    /// and every other scene and animation names nothing.
    @Test func demoModeShowsTheCausesAndNone() throws {
        #expect(Self.snapshot(.systemChargeLimit)?.notChargingCause == .systemChargeLimit)
        let none = try #require(Self.snapshot(.notChargingWithoutCause))
        #expect(none.notChargingReason == 0x80)
        #expect(none.isExternalPowerConnected == true)
        #expect(none.notChargingCause == nil)
        #expect(none.isNotChargingWithoutCause)
        #expect(WidgetStateWord(none) == .notCharging)
        #expect(BatteryReport.lines(for: none).first { $0.label == "Not charging reason" }?.value == "0x80")

        for scenario in DemoScenario.allCases where ![.systemChargeLimit, .notChargingWithoutCause].contains(scenario) {
            #expect(Self.snapshot(scenario)?.notChargingCause == nil, "\(scenario)")
            #expect(Self.snapshot(scenario)?.isNotChargingWithoutCause != true, "\(scenario)")
        }
        for animation in DemoAnimation.allCases {
            for step in 0...20 {
                let s = animation.battery(progress: Double(step) / 20).reading(at: Fixture.timestamp).snapshot
                #expect(s.notChargingCause == nil && !s.isNotChargingWithoutCause, "\(animation) \(step)")
            }
        }
        // Without a cause the reason reads as the M5's: 0x80 on battery, 0 on the adapter.
        #expect(Self.snapshot(.onBattery)?.notChargingReason == 0x80)
        #expect(Self.snapshot(.charging)?.notChargingReason == 0)
        #expect(Self.snapshot(.optimizedHold)?.notChargingReason == 0)
    }
}
