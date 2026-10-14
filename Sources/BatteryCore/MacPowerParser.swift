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

    static func redactingSerialNumbers(in dictionary: PropertyDictionary) -> PropertyDictionary {
        var result = dictionary
        for (key, value) in dictionary {
            switch value {
            case .string where key.localizedCaseInsensitiveContains("serial"):
                result[key] = .string(redactedPlaceholder)
            case .dictionary(let nested):
                result[key] = .dictionary(redactingSerialNumbers(in: nested))
            case .array(let items):
                result[key] = .array(items.map { item in
                    guard case .dictionary(let nested) = item else { return item }
                    return .dictionary(redactingSerialNumbers(in: nested))
                })
            default:
                break
            }
        }
        return result
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
/// Intel Macs report `CurrentCapacity`/`MaxCapacity` in mAh; Apple Silicon reports them in
/// percent and moves the mAh values to `AppleRawCurrentCapacity`/`AppleRawMaxCapacity`.
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

        // Capacity
        let registryCurrent = sb["CurrentCapacity"]?.intValue
        let registryMax = sb["MaxCapacity"]?.intValue
        let registryUsesMAh = (registryMax ?? 0) > 100
        s.currentCapacityMAh = sb["AppleRawCurrentCapacity"]?.intValue
            ?? (registryUsesMAh ? registryCurrent : nil)
        s.fullChargeCapacityMAh = sb["AppleRawMaxCapacity"]?.intValue
            ?? (registryUsesMAh ? registryMax : nil)
        s.nominalChargeCapacityMAh = sb["NominalChargeCapacity"]?.intValue
        s.designCapacityMAh = sb["DesignCapacity"]?.intValue ?? batteryData["DesignCapacity"]?.intValue
        s.cycleCount = sb["CycleCount"]?.intValue ?? batteryData["CycleCount"]?.intValue
        s.designCycleCount = sb["DesignCycleCount9C"]?.intValue ?? sb["DesignCycleCount70"]?.intValue
        s.healthCondition = ps["BatteryHealthCondition"]?.stringValue ?? ps["BatteryHealth"]?.stringValue
        s.permanentFailureStatus = sb["PermanentFailureStatus"]?.intValue

        // Charge percent: prefer the power-source value, which is what the menu bar shows.
        if let current = ps["Current Capacity"]?.intValue, let max = ps["Max Capacity"]?.intValue, max > 0 {
            s.chargePercent = percent(current, of: max)
        } else if let current = registryCurrent, let max = registryMax, max > 0 {
            s.chargePercent = percent(current, of: max)
        }

        // State
        let isCharging = ps["Is Charging"]?.boolValue ?? sb["IsCharging"]?.boolValue
        let isFullyCharged = sb["FullyCharged"]?.boolValue ?? ps["Is Charged"]?.boolValue
        s.isExternalPowerConnected = sb["ExternalConnected"]?.boolValue
            ?? ps["Power Source State"]?.stringValue.map { $0 == "AC Power" }
        s.chargeState = chargeState(
            isCharging: isCharging,
            isExternalPowerConnected: s.isExternalPowerConnected,
            isFullyCharged: isFullyCharged
        )
        s.isOptimizedChargingEngaged = ps["Optimized Battery Charging Engaged"]?.boolValue

        switch s.chargeState {
        case .discharging:
            s.timeToEmptyMinutes = validMinutes(ps["Time to Empty"]?.intValue)
                ?? validMinutes(sb["AvgTimeToEmpty"]?.intValue)
        case .charging:
            s.timeToFullMinutes = validMinutes(ps["Time to Full Charge"]?.intValue)
                ?? validMinutes(sb["AvgTimeToFull"]?.intValue)
        case .charged, .notCharging, .unknown:
            break
        }

        // Electrical
        s.voltageMV = sb["Voltage"]?.intValue ?? batteryData["Voltage"]?.intValue
            ?? sb["AppleRawBatteryVoltage"]?.intValue
        s.amperageMA = sb["Amperage"]?.intValue
        s.instantAmperageMA = sb["InstantAmperage"]?.intValue
        s.cellVoltagesMV = (batteryData["CellVoltage"] ?? sb["CellVoltage"])?
            .arrayValue?.compactMap(\.intValue).filter { $0 > 0 } ?? []
        s.temperatureCelsius = sb["Temperature"]?.intValue.flatMap(celsius(fromCentidegrees:))

        // Charger & telemetry
        s.chargingCurrentMA = chargerData["ChargingCurrent"]?.intValue
        s.chargingVoltageMV = chargerData["ChargingVoltage"]?.intValue
        s.notChargingReason = chargerData["NotChargingReason"]?.intValue
        s.systemPowerInMW = telemetry["SystemPowerIn"]?.intValue
        s.systemLoadMW = telemetry["SystemLoad"]?.intValue
        if s.isExternalPowerConnected != false {
            s.adapter = adapter(from: adapterDetails.isEmpty
                ? sb["AdapterDetails"]?.dictionaryValue ?? [:]
                : adapterDetails)
        }

        // Identity
        s.deviceName = sb["DeviceName"]?.stringValue
        s.manufacturer = sb["Manufacturer"]?.stringValue
        s.serialNumber = sb["Serial"]?.stringValue
            ?? sb["BatterySerialNumber"]?.stringValue
            ?? ps["Hardware Serial Number"]?.stringValue
        s.manufactureDate = smartBatteryDate(sb["ManufactureDate"]?.intValue)

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

    static func validMinutes(_ minutes: Int?) -> Int? {
        guard let minutes, minutes > 0, minutes < invalidMinutes else { return nil }
        return minutes
    }

    static func percent(_ value: Int, of max: Int) -> Double {
        min(100, Swift.max(0, Double(value) / Double(max) * 100))
    }

    /// `Temperature` is reported in hundredths of a degree Celsius.
    static func celsius(fromCentidegrees raw: Int) -> Double? {
        let celsius = Double(raw) / 100
        return (-40...150).contains(celsius) ? celsius : nil
    }

    /// Smart Battery Data spec date: `(year - 1980) << 9 | month << 5 | day`.
    static func smartBatteryDate(_ raw: Int?) -> DateComponents? {
        guard let raw, raw > 0 else { return nil }
        let day = raw & 0x1F
        let month = (raw >> 5) & 0x0F
        let year = 1980 + (raw >> 9)
        guard (1...31).contains(day), (1...12).contains(month), (2000...2100).contains(year) else {
            return nil
        }
        return DateComponents(year: year, month: month, day: day)
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
