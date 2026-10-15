import Foundation

extension BatteryReading {
    /// Parses the dictionaries macOS exposes about the internal battery.
    ///
    /// - Parameters:
    ///   - smartBattery: `AppleSmartBattery` IORegistry properties, with its children under
    ///     ``RegistryChildren/childrenKey``.
    ///   - powerSource: `IOPSGetPowerSourceDescription` of the internal battery.
    ///   - adapterDetails: `IOPSCopyExternalPowerAdapterDetails`.
    ///   - smc: battery keys read from the SMC (``SMCBattery/capture(_:)``).
    public init(
        smartBattery: PropertyDictionary,
        powerSource: PropertyDictionary = [:],
        adapterDetails: PropertyDictionary = [:],
        smc: PropertyDictionary = [:],
        timestamp: Date
    ) {
        self.init(
            snapshot: MacPowerParser.snapshot(
                smartBattery: smartBattery,
                powerSource: powerSource,
                adapterDetails: adapterDetails,
                smc: smc,
                timestamp: timestamp
            ),
            smartBattery: smartBattery,
            powerSource: powerSource,
            adapterDetails: adapterDetails,
            smc: smc
        )
    }
}

// MARK: - Raw capture

extension BatteryReading {
    /// Top-level keys of a raw capture (`bpulse --raw`), which is also the test fixture format.
    public enum CaptureKey {
        public static let smartBattery = "AppleSmartBattery"
        public static let powerSource = "PowerSource"
        public static let adapterDetails = "AdapterDetails"
        public static let smc = "AppleSMC"
    }

    /// The raw dictionaries bundled into one property list. `AppleSMC` is left out when the SMC
    /// wasn't read, so older captures and new ones look the same.
    public var rawCapture: PropertyDictionary {
        var capture: PropertyDictionary = [
            CaptureKey.smartBattery: .dictionary(smartBattery),
            CaptureKey.powerSource: .dictionary(powerSource),
            CaptureKey.adapterDetails: .dictionary(adapterDetails),
        ]
        if !smc.isEmpty { capture[CaptureKey.smc] = .dictionary(smc) }
        return capture
    }

    /// ``rawCapture`` with serial numbers replaced, safe to attach to public bug reports.
    public var redactedRawCapture: PropertyDictionary {
        Self.redactingSerialNumbers(in: rawCapture)
    }

    static let redactedPlaceholder = "REDACTED"

    /// Opaque gauge blobs that can embed manufacturing identifiers.
    static let redactedKeys: Set<String> = ["ManufacturerData", "MfgData"]

    static func redactingSerialNumbers(in dictionary: PropertyDictionary) -> PropertyDictionary {
        var result: PropertyDictionary = [:]
        for (key, value) in dictionary {
            // Serials appear as strings, integers (`FirmwareSerialNumber`, adapter `SerialNumber`)
            // or data, so match on the key, not the value type.
            let isSensitive = key.lowercased().contains("serial") || redactedKeys.contains(key)
            result[key] = isSensitive ? .string(redactedPlaceholder) : redactingSerialNumbers(in: value)
        }
        return result
    }

    static func redactingSerialNumbers(in value: PropertyValue) -> PropertyValue {
        switch value {
        case .dictionary(let nested): .dictionary(redactingSerialNumbers(in: nested))
        case .array(let items): .array(items.map(redactingSerialNumbers(in:)))
        default: value
        }
    }

    /// Re-parses a raw capture produced by ``rawCapture``.
    public init(rawCapture: PropertyDictionary, timestamp: Date) {
        self.init(
            smartBattery: rawCapture[CaptureKey.smartBattery]?.dictionaryValue ?? [:],
            powerSource: rawCapture[CaptureKey.powerSource]?.dictionaryValue ?? [:],
            adapterDetails: rawCapture[CaptureKey.adapterDetails]?.dictionaryValue ?? [:],
            smc: rawCapture[CaptureKey.smc]?.dictionaryValue ?? [:],
            timestamp: timestamp
        )
    }
}

/// Maps macOS power dictionaries onto ``BatterySnapshot``.
///
/// macOS 27 (checked on a MacBook Air M5) keeps the gauge's mAh values in the `BatteryData`
/// sub-dictionary (`RemainingCapacity`, `FullChargeCapacity`, `NominalChargeCapacity`,
/// `DesignCapacity`); top-level `CurrentCapacity`/`MaxCapacity` are percentages. The temperature,
/// cell voltages and charger targets moved to child entries (``RegistryChildren``), with the SMC
/// (``SMCBattery``) as a second source for the cells. Earlier Apple silicon releases exposed
/// `AppleRawCurrentCapacity`/`AppleRawMaxCapacity`, `Temperature` and `CellVoltage` at the top
/// level; those remain as fallbacks.
enum MacPowerParser {
    /// IORegistry's "unknown" marker for minute counters.
    static let invalidMinutes = 65535

    static func snapshot(
        smartBattery sb: PropertyDictionary,
        powerSource ps: PropertyDictionary,
        adapterDetails: PropertyDictionary,
        smc: PropertyDictionary = [:],
        timestamp: Date
    ) -> BatterySnapshot {
        let batteryData = sb["BatteryData"]?.dictionaryValue ?? [:]
        // The charger's own entry first: on macOS 27 the top-level `ChargerData` lacks the targets.
        let chargerData = RegistryChildren.chargerData(in: sb).merging(
            sb["ChargerData"]?.dictionaryValue ?? [:], uniquingKeysWith: { child, _ in child })
        let telemetry = sb["PowerTelemetryData"]?.dictionaryValue ?? [:]

        var s = BatterySnapshot(timestamp: timestamp)

        // Capacity (mAh)
        s.currentCapacityMAh =
            batteryData["RemainingCapacity"]?.intValue ?? sb["AppleRawCurrentCapacity"]?.intValue
        s.fullChargeCapacityMAh =
            batteryData["FullChargeCapacity"]?.intValue ?? sb["AppleRawMaxCapacity"]?.intValue
        s.nominalChargeCapacityMAh =
            batteryData["NominalChargeCapacity"]?.intValue ?? sb["NominalChargeCapacity"]?.intValue
        s.designCapacityMAh = batteryData["DesignCapacity"]?.intValue ?? sb["DesignCapacity"]?.intValue
        s.cycleCount = sb["CycleCount"]?.intValue ?? batteryData["CycleCount"]?.intValue
        // IOPS also has `DesignCycleCount`, but it reads 300 on an M5 rated for 1000 cycles.
        s.designCycleCount = sb["DesignCycleCount9C"]?.intValue
        // macOS only publishes a condition when something is wrong; System Information shows
        // "Normal" when the key is absent.
        // An empty condition means normal too.
        let condition = [ps["BatteryHealthCondition"], ps["BatteryHealth"]].lazy
            .compactMap { $0?.stringValue }.first { !$0.isEmpty }
        s.healthCondition = condition ?? (ps.isEmpty ? nil : "Normal")
        s.permanentFailureStatus = sb["PermanentFailureStatus"]?.intValue

        // Charge percent: prefer the power-source value, which is what the menu bar shows.
        if let current = ps["Current Capacity"]?.intValue, let max = ps["Max Capacity"]?.intValue, max > 0 {
            s.chargePercent = percent(current, of: max)
        } else if let current = sb["CurrentCapacity"]?.intValue, let max = sb["MaxCapacity"]?.intValue, max > 0 {
            s.chargePercent = percent(current, of: max)
        }

        // State
        let isCharging = ps["Is Charging"]?.boolValue ?? sb["IsCharging"]?.boolValue
        let isFullyCharged = sb["FullyCharged"]?.boolValue ?? ps["Is Charged"]?.boolValue
        s.isExternalPowerConnected =
            sb["ExternalConnected"]?.boolValue
            ?? ps["Power Source State"]?.stringValue.map { $0 == "AC Power" }
        s.chargeState = chargeState(
            isCharging: isCharging,
            isExternalPowerConnected: s.isExternalPowerConnected,
            isFullyCharged: isFullyCharged
        )
        s.isOptimizedChargingEngaged = ps["Optimized Battery Charging Engaged"]?.boolValue
        s.isLowPowerModeEnabled = ps["LPM Active"]?.boolValue

        switch s.chargeState {
        case .discharging:
            (s.timeToEmptyMinutes, s.isTimeRemainingCalculating) = timeRemaining(
                powerSource: ps["Time to Empty"], gauge: sb["AvgTimeToEmpty"])
        case .charging:
            (s.timeToFullMinutes, s.isTimeRemainingCalculating) = timeRemaining(
                powerSource: ps["Time to Full Charge"], gauge: sb["AvgTimeToFull"])
        case .charged, .notCharging, .unknown:
            break
        }

        // Electrical
        s.voltageMV = sb["Voltage"]?.intValue ?? sb["AppleRawBatteryVoltage"]?.intValue
        s.amperageMA = sb["Amperage"]?.intValue
        s.instantAmperageMA = sb["InstantAmperage"]?.intValue
        s.cellVoltagesMV =
            (batteryData["CellVoltage"] ?? sb["CellVoltage"])?
            .arrayValue?.compactMap(\.intValue).filter { $0 > 0 } ?? []
        if s.cellVoltagesMV.isEmpty { s.cellVoltagesMV = RegistryChildren.cellVoltagesMV(in: sb) }
        if s.cellVoltagesMV.isEmpty {
            s.cellVoltagesMV = SMCBattery.cellVoltagesMV(in: smc, packVoltageMV: s.voltageMV)
        }
        s.temperatureCelsius =
            sb["Temperature"]?.intValue.flatMap(celsius(fromCentidegrees:))
            ?? RegistryChildren.temperatureCelsius(in: sb)
            ?? SMCBattery.temperatureCelsius(in: smc)

        // Charger & telemetry
        s.chargingCurrentMA = chargerData["ChargingCurrent"]?.intValue
        s.chargingVoltageMV = chargerData["ChargingVoltage"]?.intValue
        s.notChargingReason = chargerData["NotChargingReason"]?.intValue
        s.slowChargingReason = chargerData["SlowChargingReason"]?.intValue
        s.systemPowerInMW = telemetry["SystemPowerIn"]?.intValue
        s.systemLoadMW = telemetry["SystemLoad"]?.intValue
        // Not milliwatts: energy lost in the adapter during a one-second sample, in µWh, the same
        // unit as SystemEnergyConsumed (= SystemPowerIn / 3.6). WallEnergyEstimate is their sum,
        // which the real M5 captures match exactly. 1 µWh per second = 3.6 mW.
        s.adapterEfficiencyLossMW = telemetry["AdapterEfficiencyLoss"]?.intValue.map {
            Int((Double($0) * 3.6).rounded())
        }
        if s.isExternalPowerConnected != false {
            s.adapter = adapter(
                from: adapterDetails.isEmpty
                    ? sb["AdapterDetails"]?.dictionaryValue ?? [:]
                    : adapterDetails)
        }

        // Identity
        s.deviceName = sb["DeviceName"]?.stringValue
        s.manufacturer = sb["Manufacturer"]?.stringValue
        s.serialNumber = sb["Serial"]?.stringValue ?? ps["Hardware Serial Number"]?.stringValue
        s.gaugeUpdatedAt = sb["UpdateTime"]?.intValue.flatMap {
            $0 > 0 ? Date(timeIntervalSince1970: TimeInterval($0)) : nil
        }

        return s
    }

    static func chargeState(
        isCharging: Bool?,
        isExternalPowerConnected: Bool?,
        isFullyCharged: Bool?
    ) -> ChargeState {
        if isCharging == true { return .charging }
        switch isExternalPowerConnected {
        case true?: return isFullyCharged == true ? .charged : .notCharging
        case false?: return .discharging
        case nil: return isCharging == false ? .discharging : .unknown
        }
    }

    /// IOPS reports -1 while macOS is still calculating, e.g. for the first minute after
    /// plugging in, when the charge current hasn't settled. Follow macOS and show nothing then;
    /// the gauge's average is only a fallback when IOPS has no value at all.
    static func timeRemaining(powerSource: PropertyValue?, gauge: PropertyValue?) -> (Int?, calculating: Bool) {
        if powerSource?.intValue == -1 { return (nil, true) }
        return (validMinutes(powerSource?.intValue) ?? validMinutes(gauge?.intValue), false)
    }

    static func validMinutes(_ minutes: Int?) -> Int? {
        guard let minutes, minutes > 0, minutes < invalidMinutes else { return nil }
        return minutes
    }

    static func percent(_ value: Int, of max: Int) -> Double {
        // Multiply first: 29 / 100 * 100 would give 28.999999999999996.
        min(100, Swift.max(0, Double(value) * 100 / Double(max)))
    }

    /// `Temperature` is reported in hundredths of a degree Celsius.
    static func celsius(fromCentidegrees raw: Int) -> Double? {
        let celsius = Double(raw) / 100
        return (-40...150).contains(celsius) ? celsius : nil
    }

    static func powerProfile(_ value: PropertyValue) -> PowerProfile? {
        guard let d = value.dictionaryValue,
            let index = d["Index"]?.intValue,
            let voltage = d["MaxVoltage"]?.intValue, voltage > 0,
            let current = d["MaxCurrent"]?.intValue, current > 0
        else { return nil }
        return PowerProfile(index: index, voltageMV: voltage, maxCurrentMA: current)
    }

    static func adapter(from d: PropertyDictionary) -> PowerAdapter? {
        let adapter = PowerAdapter(
            watts: d["Watts"]?.intValue,
            voltageMV: d["Voltage"]?.intValue ?? d["AdapterVoltage"]?.intValue,
            currentMA: d["Current"]?.intValue,
            name: d["Name"]?.stringValue,
            manufacturer: d["Manufacturer"]?.stringValue,
            adapterDescription: d["Description"]?.stringValue,
            serialNumber: d["SerialString"]?.stringValue ?? d["SerialNumber"]?.stringValue,
            isWireless: d["IsWireless"]?.boolValue,
            profiles: (d["UsbHvcMenu"]?.arrayValue ?? []).compactMap(powerProfile).sorted {
                $0.voltageMV < $1.voltageMV
            },
            activeProfileIndex: d["UsbHvcHvcIndex"]?.intValue
        )
        // A stale or empty entry (no wattage, no name) means nothing is plugged in.
        guard (adapter.watts ?? 0) > 0 || adapter.name != nil else { return nil }
        return adapter
    }
}
