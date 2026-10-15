import BatteryCore
import Foundation
import Testing

@Suite struct BatteryMotionTests {
    // MARK: MotionPolicy

    @Test(
        arguments: [
            // reduceMotion, prefersCrossFade, isVisible, reducesResources → level, allowsFlourish
            (false, false, true, false, MotionPolicy.Level.full, true),
            (false, false, true, true, .full, false),
            (true, false, true, false, .fade, false),
            (false, true, true, false, .fade, false),
            (true, true, true, true, .fade, false),
            (false, false, false, false, .none, false),
            (true, false, false, false, .none, false),
            (false, false, false, true, .none, false),
        ])
    func policyTable(
        reduceMotion: Bool, prefersCrossFade: Bool, isVisible: Bool, reducesResources: Bool,
        level: MotionPolicy.Level, allowsFlourish: Bool
    ) {
        let policy = MotionPolicy(
            reduceMotion: reduceMotion, prefersCrossFade: prefersCrossFade, isVisible: isVisible,
            reducesResources: reducesResources)
        #expect(policy.level == level)
        #expect(policy.allowsFlourish == allowsFlourish)
    }

    @Test func defaultPolicyAnimatesFully() {
        #expect(MotionPolicy().level == .full)
        #expect(MotionPolicy().allowsFlourish)
    }

    // MARK: BatteryMotionKey

    /// What a 2 s reading changes on an otherwise steady battery.
    private static func nextReading(after s: BatterySnapshot) -> BatterySnapshot {
        var next = s
        next.timestamp = s.timestamp.addingTimeInterval(2)
        next.gaugeUpdatedAt = s.gaugeUpdatedAt.map { $0.addingTimeInterval(20) } ?? s.timestamp
        next.voltageMV = s.voltageMV.map { $0 - 14 }
        next.amperageMA = s.amperageMA.map { $0 + ($0 < 0 ? -37 : 37) }
        next.instantAmperageMA = s.instantAmperageMA.map { $0 + 52 }
        next.temperatureCelsius = (s.temperatureCelsius ?? 30) + 0.4
        next.cellVoltagesMV = s.cellVoltagesMV.map { $0 - 3 }
        next.timeToEmptyMinutes = s.timeToEmptyMinutes.map { $0 - 3 }
        next.timeToFullMinutes = s.timeToFullMinutes.map { $0 - 1 }
        next.currentCapacityMAh = s.currentCapacityMAh.map { $0 - 2 }
        next.systemLoadMW = s.systemLoadMW.map { $0 + 830 }
        next.systemPowerInMW = s.systemPowerInMW.map { $0 + 610 }
        next.adapterEfficiencyLossMW = s.adapterEfficiencyLossMW.map { $0 + 40 }
        return next
    }

    @Test(arguments: [Fixture.m5OnBattery, .m5Charging, .m5OnBatterySMC, .m5PluggedIn10s, .m5Unplugged])
    func keyIgnoresLiveValues(fixture: Fixture) throws {
        let snapshot = try fixture.snapshot()
        let next = Self.nextReading(after: snapshot)
        #expect(next != snapshot)
        #expect(BatteryMotionKey(next) == BatteryMotionKey(snapshot))
    }

    @Test func keyFromRealCaptures() throws {
        let onBattery = BatteryMotionKey(try Fixture.m5OnBattery.snapshot())
        #expect(onBattery.percent == 70)
        #expect(onBattery.tier == .normal)
        #expect(!onBattery.isPluggedIn)
        #expect(onBattery.chargeState == .discharging)
        #expect(onBattery.symbolName == "battery.75percent")
        #expect(onBattery.flow == .outOfBattery)
        #expect(!onBattery.isLowPowerMode)

        let charging = BatteryMotionKey(try Fixture.m5Charging.snapshot())
        #expect(charging.percent == 70)
        #expect(charging.isPluggedIn)
        #expect(charging.chargeState == .charging)
        #expect(charging.symbolName == "battery.100percent.bolt")
        #expect(charging.flow == .intoBattery)
    }

    @Test func pluggingInFlipsIsPluggedIn() throws {
        let onBattery = try Fixture.m5OnBattery.snapshot()
        var pluggedIn = onBattery
        pluggedIn.isExternalPowerConnected = true
        let before = BatteryMotionKey(onBattery)
        let after = BatteryMotionKey(pluggedIn)
        #expect(!before.isPluggedIn)
        #expect(after.isPluggedIn)
        #expect(after != before)
        // The rest of the key waits for macOS to report the new state.
        #expect(after.chargeState == before.chargeState)
        #expect(after.flow == before.flow)

        // The real capture taken right after plugging in agrees.
        #expect(BatteryMotionKey(try Fixture.m5PluggedIn10s.snapshot()).isPluggedIn)
        #expect(!BatteryMotionKey(try Fixture.m5Unplugged.snapshot()).isPluggedIn)
    }

    @Test(arguments: [0.0, 0.01, -0.01, 0.049, -0.049])
    func flowIsIdleInTheDeadBand(watts: Double) {
        #expect(BatteryMotionKey.Flow(batteryWatts: watts) == .idle)
    }

    @Test func flowDirection() {
        #expect(BatteryMotionKey.Flow(batteryWatts: nil) == .idle)
        #expect(BatteryMotionKey.Flow(batteryWatts: BatteryPresentation.powerFlowDeadBandWatts) == .intoBattery)
        #expect(BatteryMotionKey.Flow(batteryWatts: 4.7) == .intoBattery)
        #expect(BatteryMotionKey.Flow(batteryWatts: -0.05) == .outOfBattery)
        #expect(BatteryMotionKey.Flow(batteryWatts: -7.5) == .outOfBattery)
    }

    @Test func noiseAroundZeroKeepsTheKey() throws {
        // A full battery on the adapter reads a few mA either way.
        var full = try Fixture.m5Charging.snapshot()
        full.chargeState = .charged
        full.chargePercent = 100
        full.voltageMV = 12_900
        full.amperageMA = 3
        var next = full
        next.amperageMA = -2
        #expect(BatteryMotionKey(full).flow == .idle)
        #expect(BatteryMotionKey(next) == BatteryMotionKey(full))
    }

    @Test func keyChangesOnBatteryEvents() throws {
        let base = try Fixture.m5OnBattery.snapshot()
        let key = BatteryMotionKey(base)

        var percent = base
        percent.chargePercent = 69
        #expect(BatteryMotionKey(percent).percent == 69)
        #expect(BatteryMotionKey(percent) != key)

        var low = base
        low.chargePercent = 20
        #expect(BatteryMotionKey(low).tier == .low)

        var symbol = base
        symbol.chargePercent = 62
        #expect(BatteryMotionKey(symbol).symbolName != key.symbolName)

        var lowPower = base
        lowPower.isLowPowerModeEnabled = true
        #expect(BatteryMotionKey(lowPower).isLowPowerMode)
        #expect(BatteryMotionKey(lowPower) != key)
    }

    @Test func fractionalPercentRoundsLikeTheFormatter() {
        let s = BatterySnapshot(timestamp: .now, chargePercent: 69.6, chargeState: .discharging)
        #expect(BatteryMotionKey(s).percent == 70)
        let half = BatterySnapshot(timestamp: .now, chargePercent: 42.5, chargeState: .discharging)
        #expect(BatteryMotionKey(half).percent == 42)
    }

    @Test func missingSnapshot() {
        let key = BatteryMotionKey(nil)
        #expect(key.percent == nil)
        #expect(key.chargeState == nil)
        #expect(!key.isPluggedIn)
        #expect(key.flow == .idle)
        #expect(key.symbolName == BatteryPresentation.symbolName(for: nil))
    }
}
