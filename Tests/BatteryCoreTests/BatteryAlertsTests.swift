import Foundation
import Testing

@testable import BatteryCore

@Suite struct BatteryAlertsTests {
    private func snapshot(
        _ percent: Double, pluggedIn: Bool, state: ChargeState? = nil, condition: String? = "Normal",
        thermal: ThermalState = .nominal
    ) -> BatterySnapshot {
        var s = BatterySnapshot(
            timestamp: .now, chargePercent: percent,
            chargeState: state ?? (pluggedIn ? .charging : .discharging))
        s.isExternalPowerConnected = pluggedIn
        s.healthCondition = condition
        s.thermalState = thermal
        return s
    }

    /// Runs a sequence of readings and returns the alerts each one raised.
    private func run(_ readings: [BatterySnapshot], _ settings: AlertSettings) -> [[BatteryAlert]] {
        var state = AlertState()
        return readings.map { BatteryAlerts.evaluate($0, settings: settings, state: &state) }
    }

    @Test func chargeLimitFiresOnceUntilUnpluggedOrWellBelow() {
        let settings = AlertSettings(chargeLimit: 80)
        let alerts = run(
            [
                snapshot(78, pluggedIn: true), snapshot(80, pluggedIn: true), snapshot(81, pluggedIn: true),
                snapshot(79, pluggedIn: true),  // still within the margin: no repeat
                snapshot(80, pluggedIn: true),
                snapshot(80, pluggedIn: false),  // unplugged re-arms
                snapshot(80, pluggedIn: true),
            ], settings)
        #expect(alerts == [[], [.chargeLimitReached], [], [], [], [], [.chargeLimitReached]])
    }

    @Test func fullChargeCountsForALimitOf100() {
        let alerts = run([snapshot(99, pluggedIn: true, state: .charged)], AlertSettings(chargeLimit: 100))
        #expect(alerts == [[.chargeLimitReached]])
    }

    @Test func lowBatteryFiresOnceOnBattery() {
        let settings = AlertSettings(lowBattery: 20)
        let alerts = run(
            [
                snapshot(21, pluggedIn: false), snapshot(20, pluggedIn: false), snapshot(19, pluggedIn: false),
                snapshot(19, pluggedIn: true),  // plugging in re-arms
                snapshot(18, pluggedIn: false),
                snapshot(30, pluggedIn: true), snapshot(15, pluggedIn: true),  // never while plugged in
            ], settings)
        #expect(alerts == [[], [.lowBattery], [], [], [.lowBattery], [], []])
    }

    @Test func serviceAndHeatFireOncePerEpisode() {
        let settings = AlertSettings(serviceRecommended: true, highTemperature: true)
        let alerts = run(
            [
                snapshot(50, pluggedIn: false),
                snapshot(50, pluggedIn: false, condition: "Service Recommended", thermal: .serious),
                snapshot(50, pluggedIn: false, condition: "Service Recommended", thermal: .critical),
                snapshot(50, pluggedIn: false, condition: "Service Recommended", thermal: .fair),  // not yet cool
                snapshot(50, pluggedIn: false, condition: "Service Recommended", thermal: .serious),
                snapshot(50, pluggedIn: false, condition: "Normal", thermal: .nominal),
                snapshot(50, pluggedIn: false, condition: "Check Battery", thermal: .serious),
            ], settings)
        #expect(
            alerts == [
                [], [.serviceRecommended, .highTemperature], [], [], [], [], [.serviceRecommended, .highTemperature],
            ])
    }

    @Test func nothingFiresWhenOff() {
        let alerts = run(
            [snapshot(100, pluggedIn: true, condition: "Poor", thermal: .critical), snapshot(5, pluggedIn: false)],
            AlertSettings())
        #expect(alerts == [[], []])
        #expect(!AlertSettings().isAnyEnabled)
    }

    @Test func stateSurvivesARelaunch() throws {
        var state = AlertState()
        _ = BatteryAlerts.evaluate(
            snapshot(85, pluggedIn: true), settings: AlertSettings(chargeLimit: 80), state: &state)
        let restored = try JSONDecoder().decode(AlertState.self, from: JSONEncoder().encode(state))
        var copy = restored
        #expect(
            BatteryAlerts.evaluate(
                snapshot(85, pluggedIn: true), settings: AlertSettings(chargeLimit: 80), state: &copy
            )
            .isEmpty)
    }
}
