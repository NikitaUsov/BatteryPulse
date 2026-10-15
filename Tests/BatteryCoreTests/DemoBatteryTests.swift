import Foundation
import Testing

@testable import BatteryCore

@Suite struct DemoBatteryTests {
    private let now = Date(timeIntervalSince1970: 1_800_000_000)

    private func snapshot(_ scenario: DemoScenario) throws -> BatterySnapshot {
        try #require(scenario.battery).reading(at: now).snapshot
    }

    @Test(arguments: [
        (DemoScenario.charging, ChargeState.charging, 34.0, BatteryPresentation.LevelTier.normal),
        (.onBattery, .discharging, 78, .normal),
        (.lowBattery, .discharging, 17, .low),
        (.criticalBattery, .discharging, 6, .critical),
        (.fullyCharged, .charged, 100, .normal),
        (.optimizedHold, .notCharging, 80, .normal),
        (.justPluggedIn, .charging, 52, .normal),
        (.wornBattery, .discharging, 64, .normal),
        (.heavyLoad, .discharging, 58, .normal),
        (.slowCharger, .charging, 41, .normal),
        (.lowPowerMode, .discharging, 23, .normal),
    ])
    func scenariosParseIntoTheirState(
        scenario: DemoScenario, state: ChargeState, percent: Double, tier: BatteryPresentation.LevelTier
    ) throws {
        let s = try snapshot(scenario)
        #expect(s.chargeState == state)
        #expect(s.chargePercent == percent)
        #expect(BatteryPresentation.levelTier(for: s) == tier)
        #expect(s.isExternalPowerConnected == (scenario.battery?.adapter != nil))
        #expect(s.designCycleCount == 1000)
        #expect(s.isTimeRemainingCalculating == (scenario == .justPluggedIn))
    }

    @Test func demoAccessoriesParse() throws {
        let accessories = AccessoryParser.accessories(from: DemoAccessories.sources)
        #expect(accessories.map(\.kind) == [.keyboard, .mouse, .headphones])
        let mouse = try #require(accessories.first { $0.kind == .mouse })
        let level = try #require(mouse.level)
        #expect(BatteryPresentation.levelTier(percent: Double(level.percent), isCharging: level.isCharging) == .low)
        let buds = try #require(accessories.last)
        #expect(buds.parts.map(\.role) == [.left, .right, .case])
        #expect(buds.parts.map(\.percent) == [64, 61, 90])
        #expect(buds.parts.last?.isCharging == true)
        #expect(buds.symbolName == "airpods")
        // Product names only: no "Anna's AirPods".
        #expect(!accessories.contains { $0.name.contains("'") || $0.name.contains("\u{2019}") })
    }

    @Test func noBatteryScenarioHasNoReading() {
        #expect(DemoScenario.noBattery.battery == nil)
    }

    @Test func chargingShowsTheAdapterAndItsProfiles() throws {
        let s = try snapshot(.charging)
        let adapter = try #require(s.adapter)
        #expect(adapter.watts == 60)
        #expect(adapter.profiles.map(\.voltageMV) == [5000, 9000, 15000, 20000])
        #expect(adapter.activeProfile?.voltageMV == 20000)
        #expect(s.timeToFullMinutes == 72)
        #expect(try #require(s.batteryPowerWatts) > 37)
        #expect(try #require(s.systemPowerInWatts) > 46)
    }

    @Test func specialStates() throws {
        let worn = try snapshot(.wornBattery)
        #expect(worn.healthCondition == "Service Recommended")
        #expect(BatteryPresentation.healthTier(for: worn) == .low)
        #expect(try #require(worn.cycleLifeUsed) > 1)

        let fresh = try snapshot(.onBattery)
        #expect(fresh.healthCondition == "Normal")
        #expect(fresh.healthPercent == 100)
        #expect(try #require(fresh.capacityToDesignPercent) > 103)

        #expect(try snapshot(.optimizedHold).isOptimizedChargingEngaged == true)
        #expect(try snapshot(.lowPowerMode).isLowPowerModeEnabled == true)
        #expect(try snapshot(.heavyLoad).thermalState == .serious)
        #expect(try #require(try snapshot(.heavyLoad).batteryPowerWatts) < -33)
        #expect(try snapshot(.slowCharger).adapter?.watts == 15)
    }

    @Test func chargeAnimation() throws {
        let start = DemoAnimation.chargeFromEmpty.battery(progress: 0)
        #expect(start.percent == 2)
        #expect(start.minutesRemaining == nil, "just plugged in: calculating")
        let middle = DemoAnimation.chargeFromEmpty.battery(progress: 0.5)
        #expect(middle.isCharging)
        #expect(try #require(middle.minutesRemaining) > 0)
        let late = DemoAnimation.chargeFromEmpty.battery(progress: 0.95)
        #expect(late.batteryWatts < middle.batteryWatts, "charging tapers near full")
        #expect(DemoAnimation.chargeFromEmpty.battery(progress: 1) == DemoScenario.fullyCharged.battery)
    }

    @Test func timeToFullFallsSteadily() throws {
        var previous = Int.max
        for step in 8...99 {
            let minutes = try #require(
                DemoAnimation.chargeFromEmpty.battery(progress: Double(step) / 100).minutesRemaining)
            #expect(minutes <= previous, "progress \(step) %")
            previous = minutes
        }
        #expect(previous <= 2)
    }

    @Test func onBatteryLoadMatchesBatteryPowerWhileVarying() throws {
        for scenario in DemoScenario.allCases {
            guard let battery = scenario.battery, battery.adapter == nil else { continue }
            for tick in 0..<60 {
                let telemetry = try #require(
                    battery.varied(tick).reading(at: now).smartBattery["PowerTelemetryData"]?.dictionaryValue)
                let load = try #require(telemetry["SystemLoad"]?.intValue)
                let batteryPower = try #require(telemetry["BatteryPower"]?.intValue)
                #expect(abs(load + batteryPower) <= 1, "\(scenario) tick \(tick)")
            }
        }
    }

    @Test func drainAnimationPassesLowAndCritical() {
        let tiers = [0.0, 0.85, 0.95].map {
            BatteryPresentation.levelTier(
                for: DemoAnimation.drainToEmpty.battery(progress: $0).reading(at: now).snapshot)
        }
        #expect(tiers == [.normal, .low, .critical])
        #expect(DemoAnimation.drainToEmpty.battery(progress: 1).percent == 2)
    }

    @Test func demoHasTemperatureCellsAndChargerTargets() throws {
        let charging = try #require(DemoScenario.allCases.compactMap(\.battery).first { $0.isCharging })
        let s = charging.reading(at: now).snapshot
        let temperature = try #require(s.temperatureCelsius)
        #expect((25...45).contains(temperature))
        #expect(s.cellVoltagesMV.count == 3)
        #expect(abs(s.cellVoltagesMV.reduce(0, +) - (s.voltageMV ?? 0)) <= 3)
        #expect((s.chargingCurrentMA ?? 0) > 0)
        let hot = charging.with { $0.thermalState = .serious }.reading(at: now).snapshot
        #expect((hot.temperatureCelsius ?? 0) > temperature)
    }

    @Test func variationIsSmallAndRepeatable() throws {
        let battery = try #require(DemoScenario.onBattery.battery)
        for tick in 0..<50 {
            let varied = battery.varied(tick)
            #expect(varied == battery.varied(tick))
            #expect(abs(varied.batteryWatts / battery.batteryWatts - 1) < 0.07)
            #expect(varied.percent == battery.percent)
        }
    }

    /// The demo must look like real data: every key it produces, the child entries below
    /// AppleSmartBattery included, exists in the real M5 captures, apart from the IOPS keys
    /// macOS only adds in those states.
    @Test func demoKeysExistOnARealMac() throws {
        var realKeys: Set<String> = []
        for fixture in [Fixture.m5OnBattery, .m5Charging, .m5OnBatterySMC] {
            let rows = RawSection.sections(for: try fixture.reading().rawCapture).flatMap(\.rows)
            realKeys.formUnion(rows.map(\.key))
        }
        let stateOnlyKeys: Set<String> = ["IOPS.Optimized Battery Charging Engaged", "IOPS.BatteryHealthCondition"]
        for scenario in DemoScenario.allCases {
            guard let battery = scenario.battery else { continue }
            let rows = RawSection.sections(for: battery.reading(at: now).rawCapture).flatMap(\.rows)
            let invented = Set(rows.map(\.key)).subtracting(realKeys).subtracting(stateOnlyKeys)
            #expect(invented.isEmpty, "\(scenario): \(invented.sorted())")
        }
    }

    /// The demo's charger asks for a per-cell voltage, as a real M5 does.
    @Test func demoChargerRequestsAPerCellVoltage() throws {
        let real = try Fixture.m5OnBatterySMC.snapshot()
        let charging = try #require(DemoScenario.allCases.compactMap(\.battery).first { $0.isCharging })
        #expect(charging.reading(at: now).snapshot.chargingVoltageMV == real.chargingVoltageMV)
    }
}
