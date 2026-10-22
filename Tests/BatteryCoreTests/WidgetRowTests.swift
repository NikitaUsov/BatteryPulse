import Foundation
import Testing

@testable import BatteryCore

struct WidgetRowTests {
    static let formatter = BatteryFormatter(locale: Locale(identifier: "en_US"))

    /// A synthetic battery on power with every value the widget can show.
    static var full: BatterySnapshot {
        var s = BatterySnapshot(timestamp: Date(timeIntervalSince1970: 1_800_000_000))
        s.chargePercent = 62
        s.chargeState = .charging
        s.isExternalPowerConnected = true
        s.timeToFullMinutes = 70
        s.currentCapacityMAh = 2_912
        s.fullChargeCapacityMAh = 4_512
        s.nominalChargeCapacityMAh = 4_700
        s.designCapacityMAh = 4_563
        s.cycleCount = 1_312
        s.designCycleCount = 1_000
        s.healthCondition = "Normal"
        s.voltageMV = 12_176
        s.amperageMA = 2_050
        s.cellVoltagesMV = [4_051, 4_058, 4_047]
        s.temperatureCelsius = 31.24
        s.adapter = PowerAdapter(watts: 70)
        s.systemPowerInMW = 41_200
        s.systemLoadMW = 16_400
        s.isLowPowerModeEnabled = false
        return s
    }

    static func value(_ field: BatteryWidgetField, _ s: BatterySnapshot = full) -> WidgetValue? {
        WidgetRow(field, snapshot: s, time: nil, formatter: formatter)?.value
    }

    @Test func valuesArePreformatted() {
        #expect(Self.value(.state) == .state(.charging))
        #expect(Self.value(.maximumCapacity) == .text("100%"))
        #expect(Self.value(.condition) == .condition(.normal))
        #expect(Self.value(.cycleCount) == .text("1,312"))
        #expect(Self.value(.temperature) == .text("31.2\u{00A0}°C"))
        #expect(Self.value(.adapter) == .text("70\u{00A0}W"))
        #expect(Self.value(.systemLoad) == .text("16.4\u{00A0}W"))
        #expect(Self.value(.batteryPower) == .text("+25.0\u{00A0}W"))
        #expect(Self.value(.adapterInput) == .text("41.2\u{00A0}W"))
        #expect(Self.value(.lowPowerMode) == .onOff(false))
        #expect(Self.value(.remainingCapacity) == .text("2,912\u{00A0}mAh"))
        #expect(Self.value(.cycleLifeUsed) == .text("131%"))
        #expect(Self.value(.cellBalance) == .text("11\u{00A0}mV"))
        #expect(Self.value(.voltage) == .text("12.18\u{00A0}V"))
    }

    @Test func theTimeComesFromThePlanner() {
        let time = WidgetTimeText(direction: .full, end: Self.full.timestamp, form: .timeLeft)
        #expect(Self.value(.time) == nil)
        #expect(WidgetRow(.time, snapshot: Self.full, time: time, formatter: Self.formatter)?.value == .time(time))
    }

    @Test func unavailableValuesHaveNoRow() {
        var s = BatterySnapshot(timestamp: Self.full.timestamp)
        s.chargePercent = 50
        s.chargeState = .discharging
        s.isExternalPowerConnected = false
        // An adapter left in the reading after unplugging, and an idle input, show nothing.
        s.adapter = PowerAdapter(watts: 70)
        s.systemPowerInMW = 0
        let missing = BatteryWidgetField.allCases.filter { Self.value($0, s) == nil }
        #expect(
            missing == [
                .time, .maximumCapacity, .cycleCount, .temperature, .adapter, .systemLoad, .batteryPower,
                .adapterInput, .lowPowerMode, .remainingCapacity, .cycleLifeUsed, .cellBalance, .voltage,
            ])
    }

    /// The real captures: every field the reading has gets a row.
    @Test(arguments: [Fixture.m5OnBattery, .m5Charging, .m5OnBatterySMC])
    func realCapturesHaveTheirRows(_ fixture: Fixture) throws {
        let s = try fixture.snapshot()
        for field in [BatteryWidgetField.state, .maximumCapacity, .condition, .cycleCount, .voltage] {
            #expect(Self.value(field, s) != nil, "\(field)")
        }
    }

    @Test func cycleLifeFallsBackToTheUsualRating() {
        var s = Self.full
        s.designCycleCount = 0
        #expect(Self.value(.cycleLifeUsed, s) == .text("131%"))
        s.cycleCount = 500
        #expect(Self.value(.cycleLifeUsed, s) == .text("50%"))
    }

    @Test func healthAndConditionCarryTheirTiers() throws {
        var s = Self.full
        s.nominalChargeCapacityMAh = 3_500
        let health = try #require(WidgetRow(.maximumCapacity, snapshot: s, time: nil, formatter: Self.formatter))
        #expect(health.tier == .low)
        #expect(health.cue == .low)
        s.healthCondition = "Check Battery"
        let condition = try #require(WidgetRow(.condition, snapshot: s, time: nil, formatter: Self.formatter))
        #expect(condition.value == .condition(.checkBattery))
        #expect(condition.cue == .critical)
    }

    @Test func statesInTheAppsWords() {
        var s = Self.full
        let cases: [(ChargeState, Bool?, WidgetStateWord)] = [
            (.charging, nil, .charging), (.discharging, nil, .onBattery), (.charged, nil, .fullyCharged),
            (.notCharging, true, .chargingOnHold), (.notCharging, false, .notCharging), (.unknown, nil, .unknown),
        ]
        for (state, optimized, word) in cases {
            s.chargeState = state
            s.isOptimizedChargingEngaged = optimized
            #expect(WidgetStateWord(s) == word)
        }
    }

    @Test func conditionsInTheAppsWords() {
        #expect(WidgetCondition(nil) == .normal)
        #expect(WidgetCondition("") == .normal)
        #expect(WidgetCondition("Good") == .normal)
        #expect(WidgetCondition("Service Recommended") == .serviceRecommended)
        #expect(WidgetCondition("Permanent Battery Failure") == .other("Permanent Battery Failure"))
        #expect(WidgetCondition("Permanent Battery Failure").tier == .critical)
    }

    @Test func attentionForHeatThenACondition() {
        var s = Self.full
        #expect(WidgetAttention(s) == nil)
        s.thermalState = .fair
        #expect(WidgetAttention(s) == nil)
        s.healthCondition = "Service Recommended"
        #expect(WidgetAttention(s) == .condition(.serviceRecommended))
        s.thermalState = .serious
        #expect(WidgetAttention(s) == .heat(.serious))
        s.thermalState = .critical
        #expect(WidgetAttention(s) == .heat(.critical))
    }
}
