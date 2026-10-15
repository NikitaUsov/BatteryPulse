import BatteryCore
import Foundation
import Testing

@Suite struct BatteryValueMotionTests {
    // MARK: Power-flow arrow

    @Test func arrowFollowsTheFlow() throws {
        #expect(BatteryMotionKey(try Fixture.m5Charging.snapshot()).batteryArrowPointsIntoBattery)
        #expect(!BatteryMotionKey(try Fixture.m5OnBattery.snapshot()).batteryArrowPointsIntoBattery)
        // Right after plugging in and unplugging, the arrow follows the SMC's current, not the
        // registry's stale one.
        #expect(BatteryMotionKey(try Fixture.m5PluggedIn10s.snapshot()).batteryArrowPointsIntoBattery)
        #expect(!BatteryMotionKey(try Fixture.m5Unplugged.snapshot()).batteryArrowPointsIntoBattery)

        // The battery feeding the Mac while the adapter is connected points out of it.
        var heavyLoad = try Fixture.m5Charging.snapshot()
        heavyLoad.amperageMA = -800
        let key = BatteryMotionKey(heavyLoad)
        #expect(key.isPluggedIn)
        #expect(key.flow == .outOfBattery)
        #expect(!key.batteryArrowPointsIntoBattery)
    }

    @Test func idleArrowRestsWherePowerWouldGo() throws {
        var full = try Fixture.m5Charging.snapshot()
        full.chargeState = .charged
        full.chargePercent = 100
        for milliamps in [3, -2, 0] {
            full.amperageMA = milliamps
            let key = BatteryMotionKey(full)
            #expect(key.flow == .idle)
            #expect(key.batteryArrowPointsIntoBattery, "\(milliamps) mA on the adapter")
        }

        var onBattery = try Fixture.m5OnBattery.snapshot()
        onBattery.amperageMA = 1
        #expect(BatteryMotionKey(onBattery).flow == .idle)
        #expect(!BatteryMotionKey(onBattery).batteryArrowPointsIntoBattery)
        #expect(!BatteryMotionKey(nil).batteryArrowPointsIntoBattery)
    }

    // MARK: Reaching full

    @Test(arguments: [
        (ChargeState.charging, ChargeState.charged, true),
        (.notCharging, .charged, true),
        (.discharging, .charged, true),
        (.charged, .charged, false),
        (.charged, .charging, false),
        (.charged, .discharging, false),
        (.discharging, .charging, false),
        (.charging, .notCharging, false),
    ])
    func reachedFull(old: ChargeState, new: ChargeState, expected: Bool) {
        #expect(BatteryMotionKey.reachedFull(from: old, to: new) == expected)
    }

    @Test func reachedFullWithoutASnapshot() {
        #expect(!BatteryMotionKey.reachedFull(from: .charged, to: nil))
        #expect(!BatteryMotionKey.reachedFull(from: nil, to: .charging))
    }

    // MARK: Capacity bars

    @Test func barsFromARealCapture() throws {
        let s = try Fixture.m5OnBattery.snapshot()
        let bars = CapacityBar.bars(for: s)
        #expect(bars.map(\.kind) == [.remaining, .fullCharge, .design])
        #expect(bars.map(\.capacityMAh) == [s.currentCapacityMAh, s.fullChargeCapacityMAh, s.designCapacityMAh])
        let largest = try #require(bars.map(\.capacityMAh).max())
        #expect(CapacityBar.scale(of: bars) == Double(largest))
    }

    @Test func missingValuesDropTheirBarAndKeepTheOthersIdentity() {
        var s = BatterySnapshot(timestamp: Fixture.timestamp, chargePercent: 50, chargeState: .discharging)
        s.currentCapacityMAh = 2_400
        s.designCapacityMAh = 4_500
        let bars = CapacityBar.bars(for: s)
        #expect(bars.map(\.id) == [.remaining, .design])
        #expect(CapacityBar.scale(of: bars) == 4_500)

        s.fullChargeCapacityMAh = 4_300
        let more = CapacityBar.bars(for: s)
        #expect(more.map(\.id) == [.remaining, .fullCharge, .design])
        #expect(Set(more.map(\.id)).count == more.count)
    }

    @Test func scaleNeverDropsBelowOne() {
        #expect(CapacityBar.scale(of: []) == 1)
        #expect(CapacityBar.scale(of: [CapacityBar(kind: .remaining, capacityMAh: 0)]) == 1)
    }

    // MARK: Glass Cards

    @Test(arguments: [
        // option, Developer section, Reduce Transparency → surface
        (false, false, false, CardSurface.standard),
        (true, false, false, .standard),
        (false, true, false, .standard),
        (true, true, false, .glass),
        (true, true, true, .standard),
        (false, true, true, .standard),
    ])
    func glassCardsApplyOnlyWithTheDeveloperSection(
        option: Bool, showsDeveloper: Bool, reduceTransparency: Bool, surface: CardSurface
    ) {
        #expect(
            CardSurface(
                glassCardsOption: option, showsDeveloperSection: showsDeveloper,
                reduceTransparency: reduceTransparency) == surface)
    }
}
