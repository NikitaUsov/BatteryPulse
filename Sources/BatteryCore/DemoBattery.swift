import Foundation

/// A simulated battery for Demo Mode.
///
/// A handful of parameters expand into the same raw dictionaries macOS 27 publishes on a
/// MacBook Air M5 (`AppleSmartBattery`, the IOPS power source and the adapter details), and
/// those go through the real parser. Every page, the menu bar and the Developer table therefore
/// work on the demo exactly as on real data.
public struct DemoBattery: Sendable, Equatable {
    /// Charge as macOS shows it.
    public var percent: Double
    /// `nil` when nothing is plugged in.
    public var adapter: DemoAdapter?
    public var isCharging: Bool
    public var isFullyCharged = false
    /// Optimized Battery Charging is holding the charge.
    public var isOptimizedHold = false
    /// Power into the battery: positive while charging, negative while discharging.
    public var batteryWatts: Double
    public var systemLoadWatts: Double
    /// Minutes to empty or to full; `nil` while macOS is still calculating.
    public var minutesRemaining: Int?
    /// Nominal capacity relative to design capacity, unclamped like the real gauge.
    public var healthPercent: Double = 104
    public var cycleCount = 48
    /// IOPS battery condition; `nil` means normal (macOS publishes no key then).
    public var condition: String?
    public var isLowPowerModeEnabled = false
    public var thermalState: ThermalState = .nominal

    public init(
        percent: Double,
        adapter: DemoAdapter? = nil,
        isCharging: Bool = false,
        batteryWatts: Double,
        systemLoadWatts: Double,
        minutesRemaining: Int?
    ) {
        self.percent = percent
        self.adapter = adapter
        self.isCharging = isCharging
        self.batteryWatts = batteryWatts
        self.systemLoadWatts = systemLoadWatts
        self.minutesRemaining = minutesRemaining
    }

    static let designCapacityMAh = 5760
    /// Roughly the energy of the MacBook Air battery, for time estimates.
    static let energyWattHours = 70.0

    /// A copy with `change` applied.
    public func with(_ change: (inout DemoBattery) -> Void) -> DemoBattery {
        var copy = self
        change(&copy)
        return copy
    }

    /// The battery with small, repeatable changes in power, so live values keep moving.
    public func varied(_ tick: Int) -> DemoBattery {
        var copy = self
        let wobble = sin(Double(tick) * 1.3) * 0.04 + sin(Double(tick) * 0.37) * 0.02
        copy.batteryWatts = batteryWatts * (1 + wobble)
        // On battery the Mac's load is exactly what the battery delivers; on the adapter the
        // load moves on its own and the adapter covers the difference.
        copy.systemLoadWatts = adapter == nil ? -copy.batteryWatts : systemLoadWatts * (1 + wobble * 1.5)
        return copy
    }

    /// The raw dictionaries for this state, parsed into a reading.
    public func reading(at date: Date, gaugeUpdatedAt: Date? = nil) -> BatteryReading {
        let level = Int(percent.rounded())
        let nominal = Int((Double(Self.designCapacityMAh) * healthPercent / 100).rounded())
        let full = Int((Double(nominal) * 0.976).rounded())
        // The gauge keeps a reserve below what macOS shows (an M5 at 87 % reads about 82 %).
        let remaining = Int((Double(full) * min(100, percent * 0.95 + 0.5) / 100).rounded())
        let voltage = 11_300 + Int((percent * 17.5).rounded())
        let amperage = Int((batteryWatts * 1_000_000 / Double(voltage)).rounded())
        let batteryMW = Int((batteryWatts * 1000).rounded())
        let loadMW = Int((systemLoadWatts * 1000).rounded())
        let isExternal = adapter != nil
        let powerInMW = isExternal ? loadMW + max(0, batteryMW) : 0
        let lossMW = isExternal ? powerInMW / 25 : 0
        let inputMV = adapter?.activeProfile.voltageMV ?? 0
        let inputMA = inputMV > 0 ? powerInMW * 1000 / inputMV : 0
        let minutes = minutesRemaining ?? -1
        let gaugeMinutes = minutesRemaining ?? MacPowerParser.invalidMinutes
        let isDischarging = !isExternal
        let updated = Int((gaugeUpdatedAt ?? date).timeIntervalSince1970)

        var smartBattery: PropertyDictionary = [
            "Amperage": .int(Int64(amperage)),
            "AppleRawBatteryVoltage": .int(Int64(voltage)),
            "AppleRawExternalConnected": .bool(isExternal),
            "AtCriticalLevel": .bool(false),
            "AvgTimeToEmpty": .int(Int64(isDischarging ? gaugeMinutes : MacPowerParser.invalidMinutes)),
            "AvgTimeToFull": .int(Int64(isCharging ? gaugeMinutes : MacPowerParser.invalidMinutes)),
            "BatteryData": .dictionary([
                "AvgTimeToEmpty": .int(Int64(isDischarging ? gaugeMinutes : MacPowerParser.invalidMinutes)),
                "BatteryPower": .int(Int64(batteryMW)),
                "CurrentCapacity": .int(Int64(level)),
                "DesignCapacity": .int(Int64(Self.designCapacityMAh)),
                "FullChargeCapacity": .int(Int64(full)),
                "FullyCharged": .int(isFullyCharged ? 1 : 0),
                "MaxCapacity": .int(100),
                "NominalChargeCapacity": .int(Int64(nominal)),
                "RemainingCapacity": .int(Int64(remaining)),
            ]),
            "BatteryInstalled": .bool(true),
            "ChargerData": .dictionary([
                "IsCharging": .int(isCharging ? 1 : 0),
                // On battery the M5 reports 0x80; it is 0 while charging.
                "NotChargingReason": .int(isExternal ? 0 : 128),
                "SlowChargingReason": .int(0),
            ]),
            "CurrentCapacity": .int(Int64(level)),
            "CycleCount": .int(Int64(cycleCount)),
            "DesignCycleCount9C": .int(1000),
            "DeviceName": .string("bq40z651"),
            "ExternalChargeCapable": .bool(isExternal),
            "ExternalConnected": .bool(isExternal),
            "FullyCharged": .bool(isFullyCharged),
            "InstantAmperage": .int(Int64(amperage)),
            "IsCharging": .bool(isCharging),
            "MaxCapacity": .int(100),
            "PowerTelemetryData": .dictionary([
                // µWh per one-second sample, like the real telemetry (see MacPowerParser).
                "AdapterEfficiencyLoss": .int(Int64((Double(lossMW) / 3.6).rounded())),
                "BatteryPower": .int(Int64(batteryMW)),
                "SystemCurrentIn": .int(Int64(inputMA)),
                "SystemLoad": .int(Int64(loadMW)),
                "SystemPowerIn": .int(Int64(powerInMW)),
                "SystemVoltageIn": .int(Int64(inputMV)),
            ]),
            "TimeRemaining": .int(Int64(gaugeMinutes)),
            "UpdateTime": .int(Int64(updated)),
            "Voltage": .int(Int64(voltage)),
            "built-in": .bool(true),
        ]
        if let adapter {
            smartBattery["AdapterDetails"] = .dictionary(adapter.details)
            smartBattery["AppleRawAdapterDetails"] = .array([.dictionary(adapter.details)])
        }

        var powerSource: PropertyDictionary = [
            "Battery Provides Time Remaining": .bool(true),
            "Current": .int(Int64(amperage)),
            "Current Capacity": .int(Int64(level)),
            "Is Charging": .bool(isCharging),
            "Is Finishing Charge": .bool(false),
            "Is Present": .bool(true),
            "LPM Active": .bool(isLowPowerModeEnabled),
            "Max Capacity": .int(100),
            "Name": .string("InternalBattery-0"),
            "Power Source ID": .int(1),
            "Power Source State": .string(isExternal ? "AC Power" : "Battery Power"),
            "Time to Empty": .int(Int64(isDischarging ? minutes : 0)),
            "Time to Full Charge": .int(Int64(isCharging ? minutes : 0)),
            "Transport Type": .string("Internal"),
            "Type": .string("InternalBattery"),
        ]
        if isOptimizedHold {
            powerSource["Optimized Battery Charging Engaged"] = .bool(true)
        }
        if let condition {
            powerSource["BatteryHealthCondition"] = .string(condition)
        }

        var reading = BatteryReading(
            smartBattery: smartBattery,
            powerSource: powerSource,
            adapterDetails: adapter?.details ?? [:],
            timestamp: date
        )
        // The thermal state comes from the system, not from these dictionaries.
        reading.snapshot.thermalState = thermalState
        return reading
    }
}

/// A USB-C power adapter for Demo Mode.
public struct DemoAdapter: Sendable, Equatable {
    public var name: String
    public var manufacturer: String?
    public var watts: Int
    /// The USB Power Delivery voltages it offers; the last one is in use.
    public var profiles: [PowerProfile]

    public var activeProfile: PowerProfile {
        profiles.last ?? PowerProfile(index: 0, voltageMV: 5000, maxCurrentMA: 0)
    }

    /// Like Apple's 60 W USB-C adapter: 5, 9, 15 and 20 V at 3 A.
    public static let usbC60W = DemoAdapter(
        name: "60W USB-C Power Adapter", manufacturer: "Apple Inc.", watts: 60,
        profiles: [(5000, 3000), (9000, 3000), (15000, 3000), (20000, 3000)].enumerated().map {
            PowerProfile(index: $0.offset, voltageMV: $0.element.0, maxCurrentMA: $0.element.1)
        })

    /// A phone charger that only offers 5 V.
    public static let phone15W = DemoAdapter(
        name: "15W USB-C Charger", manufacturer: nil, watts: 15,
        profiles: [PowerProfile(index: 0, voltageMV: 5000, maxCurrentMA: 3000)])

    var details: PropertyDictionary {
        var details: PropertyDictionary = [
            "AdapterVoltage": .int(Int64(activeProfile.voltageMV)),
            "Current": .int(Int64(activeProfile.maxCurrentMA)),
            "Description": .string("pd charger"),
            // 0xE000400A, the family code the M5 reports for USB-C Power Delivery adapters.
            "FamilyCode": .int(-536_854_518),
            "IsWireless": .bool(false),
            "Name": .string(name),
            "UsbHvcHvcIndex": .int(Int64(activeProfile.index)),
            "UsbHvcMenu": .array(
                profiles.map {
                    .dictionary([
                        "Index": .int(Int64($0.index)),
                        "MaxCurrent": .int(Int64($0.maxCurrentMA)),
                        "MaxVoltage": .int(Int64($0.voltageMV)),
                    ])
                }),
            "Watts": .int(Int64(watts)),
        ]
        if let manufacturer {
            details["Manufacturer"] = .string(manufacturer)
        }
        return details
    }
}

/// Ready-made states that show what BatteryPulse does in each situation.
public enum DemoScenario: String, Sendable, CaseIterable, Identifiable {
    case charging, onBattery, lowBattery, criticalBattery, fullyCharged, optimizedHold
    case justPluggedIn, wornBattery, heavyLoad, slowCharger, lowPowerMode, noBattery

    public var id: Self { self }

    /// `nil` for ``noBattery``: a Mac without a battery.
    public var battery: DemoBattery? {
        switch self {
        case .charging:
            DemoBattery(
                percent: 34, adapter: .usbC60W, isCharging: true, batteryWatts: 38, systemLoadWatts: 9,
                minutesRemaining: 72)
        case .onBattery:
            DemoBattery(percent: 78, batteryWatts: -7.6, systemLoadWatts: 7.6, minutesRemaining: 418)
        case .lowBattery:
            DemoBattery(percent: 17, batteryWatts: -9.4, systemLoadWatts: 9.4, minutesRemaining: 71)
        case .criticalBattery:
            DemoBattery(percent: 6, batteryWatts: -11.2, systemLoadWatts: 11.2, minutesRemaining: 21)
        case .fullyCharged:
            DemoBattery(percent: 100, adapter: .usbC60W, batteryWatts: 0, systemLoadWatts: 6.4, minutesRemaining: 0)
                .with { $0.isFullyCharged = true }
        case .optimizedHold:
            DemoBattery(percent: 80, adapter: .usbC60W, batteryWatts: 0, systemLoadWatts: 7.1, minutesRemaining: 0)
                .with { $0.isOptimizedHold = true }
        case .justPluggedIn:
            DemoBattery(
                percent: 52, adapter: .usbC60W, isCharging: true, batteryWatts: 21, systemLoadWatts: 8.3,
                minutesRemaining: nil)
        case .wornBattery:
            DemoBattery(percent: 64, batteryWatts: -8.8, systemLoadWatts: 8.8, minutesRemaining: 187).with {
                $0.healthPercent = 74.6
                $0.cycleCount = 1184
                $0.condition = "Service Recommended"
            }
        case .heavyLoad:
            DemoBattery(percent: 58, batteryWatts: -34.5, systemLoadWatts: 34.5, minutesRemaining: 68)
                .with { $0.thermalState = .serious }
        case .slowCharger:
            DemoBattery(
                percent: 41, adapter: .phone15W, isCharging: true, batteryWatts: 4.2, systemLoadWatts: 8.6,
                minutesRemaining: 512)
        case .lowPowerMode:
            DemoBattery(percent: 23, batteryWatts: -4.3, systemLoadWatts: 4.3, minutesRemaining: 225)
                .with { $0.isLowPowerModeEnabled = true }
        case .noBattery:
            nil
        }
    }
}

/// Animated sequences that run through many states in a few seconds.
public enum DemoAnimation: String, Sendable, CaseIterable, Identifiable {
    /// 2 % to full on the 60 W adapter, with the charge power tapering off near the top.
    case chargeFromEmpty
    /// Full to 2 % on battery, through the low and critical levels.
    case drainToEmpty

    public var id: Self { self }

    public var duration: Duration { .seconds(20) }

    /// The state `progress` (0…1) of the way through.
    public func battery(progress: Double) -> DemoBattery {
        let progress = min(1, max(0, progress))
        switch self {
        case .chargeFromEmpty:
            if progress >= 1, let full = DemoScenario.fullyCharged.battery {
                return full
            }
            let percent = 2 + 98 * progress
            // Constant current up to 80 %, then the charger tapers off.
            let watts = percent < 80 ? 38 : max(3, 38 * (100 - percent) / 20)
            // The estimate uses the full-power rate so it falls steadily instead of stalling
            // while the power tapers.
            let hoursLeft = DemoBattery.energyWattHours * (100 - percent) / 100 / 38
            // Right after plugging in, macOS is still estimating.
            let minutes = progress < 0.08 ? nil : Int((hoursLeft * 60 * 1.15).rounded())
            return DemoBattery(
                percent: percent, adapter: .usbC60W, isCharging: true, batteryWatts: watts, systemLoadWatts: 8,
                minutesRemaining: minutes)
        case .drainToEmpty:
            let percent = 100 - 98 * progress
            let watts = 12.0
            let hoursLeft = DemoBattery.energyWattHours * percent / 100 / watts
            return DemoBattery(
                percent: percent, batteryWatts: -watts, systemLoadWatts: watts,
                minutesRemaining: max(1, Int((hoursLeft * 60).rounded())))
        }
    }
}
