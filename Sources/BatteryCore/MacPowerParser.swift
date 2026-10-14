import Foundation

extension BatteryReading {
    /// Parses the three dictionaries macOS exposes about the internal battery.
    ///
    /// - Parameters:
    ///   - smartBattery: `AppleSmartBattery` IORegistry properties.
    ///   - powerSource: `IOPSGetPowerSourceDescription` of the internal battery.
    ///   - adapterDetails: `IOPSCopyExternalPowerAdapterDetails`.
    public init(
        smartBattery: PropertyDictionary,
        powerSource: PropertyDictionary = [:],
        adapterDetails: PropertyDictionary = [:],
        timestamp: Date
    ) {
        self.init(
            snapshot: MacPowerParser.snapshot(
                smartBattery: smartBattery,
                powerSource: powerSource,
                adapterDetails: adapterDetails,
                timestamp: timestamp
            ),
            smartBattery: smartBattery,
            powerSource: powerSource,
            adapterDetails: adapterDetails
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
    }

    /// The raw dictionaries bundled into one property list.
    public var rawCapture: PropertyDictionary {
        [
            CaptureKey.smartBattery: .dictionary(smartBattery),
            CaptureKey.powerSource: .dictionary(powerSource),
            CaptureKey.adapterDetails: .dictionary(adapterDetails),
        ]
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
            timestamp: timestamp
        )
    }
}

/// Maps macOS power dictionaries onto ``BatterySnapshot``.
///
/// macOS 27 (checked on a MacBook Air M5) keeps the gauge's mAh values in the `BatteryData`
/// sub-dictionary (`RemainingCapacity`, `FullChargeCapacity`, `NominalChargeCapacity`,
/// `DesignCapacity`); top-level `CurrentCapacity`/`MaxCapacity` are percentages. Earlier Apple
/// Silicon releases exposed `AppleRawCurrentCapacity`/`AppleRawMaxCapacity`, `Temperature` and
/// `CellVoltage` at the top level; those remain as fallbacks.
enum MacPowerParser {
    /// IORegistry's "unknown" marker for minute counters.
    static let invalidMinutes = 65535

    static func snapshot(
        smartBattery sb: PropertyDictionary,
        powerSource ps: PropertyDictionary,
        adapterDetails: PropertyDictionary,
        timestamp: Date
    ) -> BatterySnapshot {
        let batteryData = sb["BatteryData"]?.dictionaryValue ?? [:]
        let chargerData = sb["ChargerData"]?.dictionaryValue ?? [:]
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
        s.healthCondition =
            ps["BatteryHealthCondition"]?.stringValue ?? ps["BatteryHealth"]?.stringValue
            ?? (ps.isEmpty ? nil : "Normal")
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
        s.temperatureCelsius = sb["Temperature"]?.intValue.flatMap(celsius(fromCentidegrees:))

        // Charger & telemetry
        s.chargingCurrentMA = chargerData["ChargingCurrent"]?.intValue
        s.chargingVoltageMV = chargerData["ChargingVoltage"]?.intValue
        s.notChargingReason = chargerData["NotChargingReason"]?.intValue
        s.slowChargingReason = chargerData["SlowChargingReason"]?.intValue
        s.systemPowerInMW = telemetry["SystemPowerIn"]?.intValue
        s.systemLoadMW = telemetry["SystemLoad"]?.intValue
        s.adapterEfficiencyLossMW = telemetry["AdapterEfficiencyLoss"]?.intValue
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

    static func adapter(from d: PropertyDictionary) -> PowerAdapter? {
        let adapter = PowerAdapter(
            watts: d["Watts"]?.intValue,
            voltageMV: d["Voltage"]?.intValue ?? d["AdapterVoltage"]?.intValue,
            currentMA: d["Current"]?.intValue,
            name: d["Name"]?.stringValue,
            manufacturer: d["Manufacturer"]?.stringValue,
            adapterDescription: d["Description"]?.stringValue,
            serialNumber: d["SerialString"]?.stringValue ?? d["SerialNumber"]?.stringValue,
            isWireless: d["IsWireless"]?.boolValue
        )
        // A stale or empty entry (no wattage, no name) means nothing is plugged in.
        guard (adapter.watts ?? 0) > 0 || adapter.name != nil else { return nil }
        return adapter
    }
}
