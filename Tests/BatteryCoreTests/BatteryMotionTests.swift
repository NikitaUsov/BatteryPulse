import BatteryCore
import Foundation
import Testing

@Suite struct BatteryMotionTests {
    // MARK: MotionPolicy

    @Test(
        arguments: [
            // reduceMotion, prefersCrossFade, isVisible, reducesResources
            //     → level, allowsMovement, allowsFlourish
            (false, false, true, false, MotionPolicy.Level.full, true, true),
            (false, false, true, true, .full, true, false),
            (true, false, true, false, .fade, false, false),
            (false, true, true, false, .fade, false, false),
            (true, true, true, true, .fade, false, false),
            (false, false, false, false, .none, false, false),
            (true, false, false, false, .none, false, false),
            (false, false, false, true, .none, false, false),
        ])
    func policyTable(
        reduceMotion: Bool, prefersCrossFade: Bool, isVisible: Bool, reducesResources: Bool,
        level: MotionPolicy.Level, allowsMovement: Bool, allowsFlourish: Bool
    ) {
        let policy = MotionPolicy(
            reduceMotion: reduceMotion, prefersCrossFade: prefersCrossFade, isVisible: isVisible,
            reducesResources: reducesResources)
        #expect(policy.level == level)
        #expect(policy.allowsMovement == allowsMovement)
        #expect(policy.allowsFlourish == allowsFlourish)
    }

    @Test func defaultPolicyAnimatesFully() {
        #expect(MotionPolicy().level == .full)
        #expect(MotionPolicy().allowsMovement)
        #expect(MotionPolicy().allowsFlourish)
    }

    /// Low Power Mode keeps functional movement (a row sliding in with its event) and drops only
    /// the extras; Reduce Motion drops all movement, so layout changes snap and only fades stay.
    @Test func movementFollowsReduceMotionNotLowPowerMode() {
        #expect(MotionPolicy(reducesResources: true).allowsMovement)
        #expect(!MotionPolicy(reduceMotion: true).allowsMovement)
        #expect(!MotionPolicy(prefersCrossFade: true).allowsMovement)
        #expect(!MotionPolicy(isVisible: false).allowsMovement)
    }

    /// Every extra moves something, so none plays where movement isn't allowed.
    @Test(arguments: [false, true], [false, true])
    func flourishImpliesMovement(reduceMotion: Bool, reducesResources: Bool) {
        for isVisible in [false, true] {
            let policy = MotionPolicy(
                reduceMotion: reduceMotion, isVisible: isVisible, reducesResources: reducesResources)
            #expect(!policy.allowsFlourish || policy.allowsMovement)
        }
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

    @Test(arguments: [0.0, 0.01, -0.01, 0.049, -0.049, 0.06, -0.06, 0.1, -0.1, 0.149, -0.149])
    func flowIsIdleInTheDeadBand(watts: Double) {
        #expect(BatteryMotionKey.Flow(batteryWatts: watts) == .idle)
    }

    @Test func flowDirection() {
        let band = BatteryPresentation.powerFlowDeadBandWatts
        #expect(BatteryMotionKey.Flow(batteryWatts: nil) == .idle)
        #expect(BatteryMotionKey.Flow(batteryWatts: band) == .intoBattery)
        #expect(BatteryMotionKey.Flow(batteryWatts: -band) == .outOfBattery)
        #expect(BatteryMotionKey.Flow(batteryWatts: 4.7) == .intoBattery)
        #expect(BatteryMotionKey.Flow(batteryWatts: -7.5) == .outOfBattery)
    }

    /// The dead band covers the currents the app already treats as noise (below 10 mA) at the
    /// pack voltages of a MacBook, so they never turn the arrow.
    @Test(arguments: [11_000, 12_900, 13_200])
    func deadBandCoversCurrentNoise(voltageMV: Int) {
        for amperageMA in [-10, -9, -5, -3, 3, 5, 9, 10] {
            let s = BatterySnapshot(
                timestamp: .now, chargePercent: 80, chargeState: .notCharging, isExternalPowerConnected: true,
                voltageMV: voltageMV, amperageMA: amperageMA)
            #expect(BatteryMotionKey(s).flow == .idle, "\(amperageMA) mA at \(voltageMV) mV")
            #expect(BatteryMotionKey(s).batteryArrowPointsIntoBattery, "\(amperageMA) mA at \(voltageMV) mV")
        }
    }

    @Test func noiseAroundZeroKeepsTheKey() throws {
        // A full battery on the adapter reads a few mA either way.
        var full = try Fixture.m5Charging.snapshot()
        full.chargeState = .charged
        full.chargePercent = 100
        full.voltageMV = 12_900
        full.amperageMA = 3
        #expect(BatteryMotionKey(full).flow == .idle)
        // Readings around -4 mA straddled the earlier 0.05 W band at this voltage and turned
        // the arrow on every other reading.
        for amperageMA in [-2, -5, -3, -4, 0, 1, -1, 9, -9] {
            var next = full
            next.amperageMA = amperageMA
            #expect(BatteryMotionKey(next) == BatteryMotionKey(full), "\(amperageMA) mA")
        }
    }

    /// Past the noise the arrow and its value follow the battery again: a trickle charge near
    /// full, or the battery helping the adapter.
    @Test func smallRealFlowsLeaveTheDeadBand() throws {
        var s = try Fixture.m5Charging.snapshot()
        s.voltageMV = 12_900
        s.amperageMA = 15
        #expect(BatteryMotionKey(s).flow == .intoBattery)
        #expect(BatteryMotionKey(s).batteryArrowPointsIntoBattery)
        s.amperageMA = -15
        #expect(BatteryMotionKey(s).flow == .outOfBattery)
        #expect(!BatteryMotionKey(s).batteryArrowPointsIntoBattery)
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
