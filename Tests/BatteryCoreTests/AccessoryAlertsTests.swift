import Foundation
import Testing

@testable import BatteryCore

@Suite struct AccessoryAlertsTests {
    private let start = Date(timeIntervalSince1970: 1_800_000_000)
    private let day: TimeInterval = 24 * 60 * 60

    private func mouse(_ percent: Int, charging: Bool = false, id: String = "acc-mouse") -> AccessoryBattery {
        AccessoryBattery(
            id: id, name: "Mouse", kind: .mouse, transport: .bluetooth,
            parts: [AccessoryPart(role: .single, percent: percent, isCharging: charging)])
    }

    private func buds(left: AccessoryPart, right: AccessoryPart, case casePart: AccessoryPart? = nil)
        -> AccessoryBattery
    {
        AccessoryBattery(
            id: "acc-buds", name: "", kind: .headphones, transport: .bluetooth,
            parts: [left, right] + (casePart.map { [$0] } ?? []))
    }

    /// The fired percentages of each step, at threshold 20.
    private func fired(_ steps: [[AccessoryBattery]], state: inout AccessoryAlertState) -> [[Int]] {
        steps.map { AccessoryAlerts.evaluate($0, threshold: 20, now: start, state: &state).fired.map(\.percent) }
    }

    @Test func firesOnceAtThreshold() {
        var state = AccessoryAlertState()
        #expect(fired([[mouse(21)], [mouse(20)], [mouse(19)], [mouse(18)]], state: &state) == [[], [20], [], []])
        #expect(state.firedAt == ["acc-mouse": start])

        var fresh = AccessoryAlertState()
        let changes = AccessoryAlerts.evaluate([mouse(8)], threshold: 20, now: start, state: &fresh)
        #expect(changes.fired == [AccessoryLowBattery(id: "acc-mouse", name: "Mouse", kind: .mouse, percent: 8)])
    }

    @Test func rearmsAfterMarginOrCharging() {
        var state = AccessoryAlertState()
        _ = AccessoryAlerts.evaluate([mouse(18)], threshold: 20, now: start, state: &state)
        #expect(AccessoryAlerts.evaluate([mouse(24)], threshold: 20, now: start, state: &state).rearmed.isEmpty)
        #expect(
            AccessoryAlerts.evaluate([mouse(25)], threshold: 20, now: start, state: &state).rearmed == ["acc-mouse"])
        #expect(state.firedAt.isEmpty)
        #expect(fired([[mouse(20)]], state: &state) == [[20]], "fires again on the next discharge")

        let charging = AccessoryAlerts.evaluate([mouse(12, charging: true)], threshold: 20, now: start, state: &state)
        #expect(charging.rearmed == ["acc-mouse"])
        #expect(charging.fired.isEmpty)
        #expect(fired([[mouse(12)]], state: &state) == [[12]])
    }

    @Test func oneBudChargingStillFires() {
        var state = AccessoryAlertState()
        let accessory = buds(
            left: AccessoryPart(role: .left, percent: 18),
            right: AccessoryPart(role: .right, percent: 70, isCharging: true, isOnExternalPower: true))
        #expect(fired([[accessory]], state: &state) == [[18]])
    }

    @Test func ignoresCaseAndOffline() {
        var state = AccessoryAlertState()
        let loneCase = AccessoryBattery(
            id: "acc-case", name: "", kind: .headphones, transport: .bluetooth,
            parts: [AccessoryPart(role: .case, percent: 5)])
        let offline = AccessoryBattery(
            id: "acc-pad", name: "", kind: .gameController, transport: .bluetoothLE,
            parts: [AccessoryPart(role: .single, percent: 3, isOffline: true)])
        let budsWithEmptyCase = buds(
            left: AccessoryPart(role: .left, percent: 80), right: AccessoryPart(role: .right, percent: 82),
            case: AccessoryPart(role: .case, percent: 2))
        #expect(fired([[loneCase, offline, budsWithEmptyCase]], state: &state) == [[]])
        #expect(state.firedAt.isEmpty)
    }

    @Test func absentAccessoryStaysDisarmed() {
        var state = AccessoryAlertState()
        #expect(fired([[mouse(15)], [], [mouse(15)]], state: &state) == [[15], [], []])
        #expect(state.firedAt.keys.sorted() == ["acc-mouse"])
    }

    @Test func forgetsOldEntriesOutOfSight() {
        var state = AccessoryAlertState()
        state.firedAt = [
            "acc-gone": start.addingTimeInterval(-8 * day),
            "acc-recent": start.addingTimeInterval(-6 * day),
            "acc-mouse": start.addingTimeInterval(-8 * day),
            "acc-future": start.addingTimeInterval(2 * day),
        ]
        _ = AccessoryAlerts.evaluate([mouse(15)], threshold: 20, now: start, state: &state)
        #expect(state.firedAt.keys.sorted() == ["acc-future", "acc-mouse", "acc-recent"])
    }

    @Test func stateIsCodable() throws {
        var state = AccessoryAlertState()
        state.firedAt = ["acc-af63dc4c8601ec8c": start]
        let data = try JSONEncoder().encode(state)
        #expect(try JSONDecoder().decode(AccessoryAlertState.self, from: data) == state)
    }

    @Test func notificationIDsAreOnePerAccessory() {
        #expect(AccessoryAlerts.notificationID(for: "acc-1") == "accessoryLowBattery.acc-1")
        #expect(AccessoryAlerts.notificationID(for: "acc-1") != AccessoryAlerts.notificationID(for: "acc-2"))
    }

    @Test func alertSettingsIncludeAccessories() {
        #expect(AlertSettings(accessoryLowBattery: 20).isAnyEnabled)
        #expect(AlertSettings().accessoryLowBattery == nil)
        #expect(!AlertSettings().isAnyEnabled)
    }

    @Test func batteryAlertsIgnoreTheAccessoryThreshold() {
        var state = AlertState()
        let snapshot = BatterySnapshot(
            timestamp: start, chargePercent: 5, chargeState: .discharging, isExternalPowerConnected: false)
        #expect(
            BatteryAlerts.evaluate(snapshot, settings: AlertSettings(accessoryLowBattery: 30), state: &state).isEmpty)
        #expect(state == AlertState())
    }
}
