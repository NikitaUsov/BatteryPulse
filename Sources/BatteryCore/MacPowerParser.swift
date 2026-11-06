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
    ///   - timestamp: when the dictionaries were read.
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

    /// - Parameters:
    ///   - dictionary: a raw capture or one of its dictionaries.
    ///   - extraKeys: further keys to replace at any depth, such as device identifiers.
    /// - Returns: `dictionary` with every serial number, gauge blob and `extraKeys` value
    ///   replaced by ``redactedPlaceholder``, at any depth.
    static func redactingSerialNumbers(
        in dictionary: PropertyDictionary, alsoRedacting extraKeys: Set<String> = []
    ) -> PropertyDictionary {
        var result: PropertyDictionary = [:]
        for (key, value) in dictionary {
            // Serials appear as strings, integers (`FirmwareSerialNumber`, adapter `SerialNumber`)
            // or data, so match on the key, not the value type.
            let isSensitive =
                key.lowercased().contains("serial") || redactedKeys.contains(key) || extraKeys.contains(key)
            result[key] =
                isSensitive
                ? .string(redactedPlaceholder) : redactingSerialNumbers(in: value, alsoRedacting: extraKeys)
        }
        return result
    }

    static func redactingSerialNumbers(in value: PropertyValue, alsoRedacting extraKeys: Set<String> = [])
        -> PropertyValue
    {
        switch value {
        case .dictionary(let nested): .dictionary(redactingSerialNumbers(in: nested, alsoRedacting: extraKeys))
        case .array(let items): .array(items.map { redactingSerialNumbers(in: $0, alsoRedacting: extraKeys) })
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
/// (``SMCBattery``) as a second source for the cells and the temperature (`B0AT`). Earlier Apple
/// silicon releases exposed `AppleRawCurrentCapacity`/`AppleRawMaxCapacity`, `Temperature` and
/// `CellVoltage` at the top level; those remain as fallbacks.
enum MacPowerParser {
    /// IORegistry's "unknown" marker for minute counters.
    static let invalidMinutes = 65535

    /// What each kind of key can hold. A value outside its range (0 for a capacity, a negative
    /// count, a 64-bit number in a 32-bit register) is no reading: the key counts as missing, so
    /// what derives from it shows "—" rather than a wrong number. The ranges are wide; every real
    /// capture lies well inside them.
    enum Plausible {
        /// mAh still in the battery: an empty one holds 0.
        static let remainingMAh = 0...100_000
        /// mAh a battery holds when full, or was designed to: never 0.
        static let capacityMAh = 1...100_000
        static let cycles = 0...100_000
        static let ratedCycles = 1...100_000
        static let packVoltageMV = SMCBattery.plausiblePackVoltage
        /// Into (+) or out of (−) the battery.
        static let currentMA = SMCBattery.plausibleCurrent
        /// A 32-bit register: a bit mask or a status code. IORegistry stores one with its top bit
        /// set as a negative number (`FamilyCode`, `RawValueDecoder.unsignedBits`), which is still
        /// a reading: the report shows it unsigned.
        static let register = Int(Int32.min)...Int(UInt32.max)
        /// What the charger asks for; 0 while it asks for nothing.
        static let requestedCurrentMA = 0...15_000
        static let requestedVoltageMV = 0...20_000
        /// System telemetry; the system load can read below 0 just after unplugging.
        static let systemPowerMW = -1_000_000...1_000_000
        /// `AdapterEfficiencyLoss`, in µWh per one-second sample.
        static let lossMicrowattHours = 0...1_000_000
        /// Seconds since 1970, up to 2100.
        static let unixTime = 1...4_102_444_800
        static let adapterWatts = 1...1_000
        /// USB Power Delivery reaches 48 V and 5 A.
        static let adapterVoltageMV = 1...50_000
        static let adapterCurrentMA = 1...10_000
        static let profileIndex = 0...255
    }

    static func snapshot(
        smartBattery sb: PropertyDictionary,
        powerSource ps: PropertyDictionary,
        adapterDetails: PropertyDictionary,
        smc: PropertyDictionary = [:],
        timestamp: Date
    ) -> BatterySnapshot {
        let batteryData = sb["BatteryData"]?.dictionaryValue ?? [:]
        // The charger's own entry first: on macOS 27 the top-level `ChargerData` lacks the targets.
        let chargerEntry = RegistryChildren.chargerData(in: sb)
        let topCharger = sb["ChargerData"]?.dictionaryValue ?? [:]
        func charger(_ key: String, in range: ClosedRange<Int>) -> Int? {
            chargerEntry[key]?.intValue(in: range) ?? topCharger[key]?.intValue(in: range)
        }
        let telemetry = sb["PowerTelemetryData"]?.dictionaryValue ?? [:]

        var s = BatterySnapshot(timestamp: timestamp)

        // Capacity (mAh). A value outside its key's ``Plausible`` range is no reading, as if the
        // key were missing, so the next key in line is used.
        s.currentCapacityMAh =
            batteryData["RemainingCapacity"]?.intValue(in: Plausible.remainingMAh)
            ?? sb["AppleRawCurrentCapacity"]?.intValue(in: Plausible.remainingMAh)
        s.fullChargeCapacityMAh =
            batteryData["FullChargeCapacity"]?.intValue(in: Plausible.capacityMAh)
            ?? sb["AppleRawMaxCapacity"]?.intValue(in: Plausible.capacityMAh)
        s.nominalChargeCapacityMAh =
            batteryData["NominalChargeCapacity"]?.intValue(in: Plausible.capacityMAh)
            ?? sb["NominalChargeCapacity"]?.intValue(in: Plausible.capacityMAh)
        s.designCapacityMAh =
            batteryData["DesignCapacity"]?.intValue(in: Plausible.capacityMAh)
            ?? sb["DesignCapacity"]?.intValue(in: Plausible.capacityMAh)
        s.cycleCount =
            sb["CycleCount"]?.intValue(in: Plausible.cycles)
            ?? batteryData["CycleCount"]?.intValue(in: Plausible.cycles)
        // IOPS also has `DesignCycleCount`, but it reads 300 on an M5 rated for 1000 cycles.
        s.designCycleCount = sb["DesignCycleCount9C"]?.intValue(in: Plausible.ratedCycles)
        // macOS only publishes a condition when something is wrong; System Information shows
        // "Normal" when the key is absent.
        // An empty condition means normal too.
        let condition = [ps["BatteryHealthCondition"], ps["BatteryHealth"]].lazy
            .compactMap { $0?.stringValue }.first { !$0.isEmpty }
        s.healthCondition = condition ?? (ps.isEmpty ? nil : "Normal")
        s.permanentFailureStatus = sb["PermanentFailureStatus"]?.intValue(in: Plausible.register)

        // Charge percent: prefer the power-source value, which is what the menu bar shows.
        if let current = ps["Current Capacity"]?.intValue(in: Plausible.remainingMAh),
            let max = ps["Max Capacity"]?.intValue(in: Plausible.capacityMAh)
        {
            s.chargePercent = percent(current, of: max)
        } else if let current = sb["CurrentCapacity"]?.intValue(in: Plausible.remainingMAh),
            let max = sb["MaxCapacity"]?.intValue(in: Plausible.capacityMAh)
        {
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
        let live = SMCBattery.liveElectrical(in: smc)
        // macOS says "not charging" for about half a minute after the adapter is plugged in,
        // while the SMC already measures the charge current; follow the battery.
        if s.chargeState == .notCharging, isFullyCharged != true, s.isOptimizedChargingEngaged != true,
            let current = live?.currentMA, current >= chargingCurrentThresholdMA
        {
            s.chargeState = .charging
            // macOS has no estimate yet.
            s.isTimeRemainingCalculating = true
        } else {
            setTimeRemaining(&s, powerSource: ps, smartBattery: sb)
        }

        // Electrical: the SMC's live readings, else the gauge's last update in the registry.
        s.voltageMV =
            live?.voltageMV ?? sb["Voltage"]?.intValue(in: Plausible.packVoltageMV)
            ?? sb["AppleRawBatteryVoltage"]?.intValue(in: Plausible.packVoltageMV)
        s.amperageMA = live?.currentMA ?? sb["Amperage"]?.intValue(in: Plausible.currentMA)
        s.instantAmperageMA = sb["InstantAmperage"]?.intValue(in: Plausible.currentMA)
        // 0 is a slot without a cell. Any other implausible value makes the whole list no reading,
        // as for the banks below, rather than a pack with a cell fewer.
        let cells = ((batteryData["CellVoltage"] ?? sb["CellVoltage"])?.arrayValue ?? []).filter { $0.intValue != 0 }
        let cellVoltages = cells.compactMap { $0.intValue(in: SMCBattery.plausibleCellVoltage) }
        s.cellVoltagesMV = cellVoltages.count == cells.count ? cellVoltages : []
        if s.cellVoltagesMV.isEmpty { s.cellVoltagesMV = RegistryChildren.cellVoltagesMV(in: sb) }
        if s.cellVoltagesMV.isEmpty {
            s.cellVoltagesMV = SMCBattery.cellVoltagesMV(in: smc, packVoltageMV: s.voltageMV)
        }
        s.temperatureCelsius =
            sb["Temperature"]?.intValue.flatMap(celsius(fromCentidegrees:))
            ?? RegistryChildren.temperatureCelsius(in: sb)
            ?? SMCBattery.temperatureCelsius(in: smc)

        // Charger & telemetry
        s.chargingCurrentMA = charger("ChargingCurrent", in: Plausible.requestedCurrentMA)
        s.chargingVoltageMV = charger("ChargingVoltage", in: Plausible.requestedVoltageMV)
        s.notChargingReason = charger("NotChargingReason", in: Plausible.register)
        s.slowChargingReason = charger("SlowChargingReason", in: Plausible.register)
        s.systemPowerInMW = telemetry["SystemPowerIn"]?.intValue(in: Plausible.systemPowerMW)
        s.systemLoadMW = telemetry["SystemLoad"]?.intValue(in: Plausible.systemPowerMW)
        // Not milliwatts: energy lost in the adapter during a one-second sample, in µWh, the same
        // unit as SystemEnergyConsumed (= SystemPowerIn / 3.6). WallEnergyEstimate is their sum,
        // which the real M5 captures match exactly. 1 µWh per second = 3.6 mW.
        s.adapterEfficiencyLossMW = telemetry["AdapterEfficiencyLoss"]?.intValue(in: Plausible.lossMicrowattHours).map {
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
        s.gaugeUpdatedAt = sb["UpdateTime"]?.intValue(in: Plausible.unixTime).map {
            Date(timeIntervalSince1970: TimeInterval($0))
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

    /// A battery current at least this large while macOS still says "not charging" means
    /// charging has started.
    static let chargingCurrentThresholdMA = 100

    static func setTimeRemaining(
        _ s: inout BatterySnapshot, powerSource ps: PropertyDictionary, smartBattery sb: PropertyDictionary
    ) {
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
            let index = d["Index"]?.intValue(in: Plausible.profileIndex),
            let voltage = d["MaxVoltage"]?.intValue(in: Plausible.adapterVoltageMV),
            let current = d["MaxCurrent"]?.intValue(in: Plausible.adapterCurrentMA)
        else { return nil }
        return PowerProfile(index: index, voltageMV: voltage, maxCurrentMA: current)
    }

    static func adapter(from d: PropertyDictionary) -> PowerAdapter? {
        let adapter = PowerAdapter(
            watts: d["Watts"]?.intValue(in: Plausible.adapterWatts),
            voltageMV: d["Voltage"]?.intValue(in: Plausible.adapterVoltageMV)
                ?? d["AdapterVoltage"]?.intValue(in: Plausible.adapterVoltageMV),
            currentMA: d["Current"]?.intValue(in: Plausible.adapterCurrentMA),
            name: d["Name"]?.stringValue,
            manufacturer: d["Manufacturer"]?.stringValue,
            adapterDescription: d["Description"]?.stringValue,
            serialNumber: d["SerialString"]?.stringValue ?? d["SerialNumber"]?.stringValue,
            isWireless: d["IsWireless"]?.boolValue,
            profiles: (d["UsbHvcMenu"]?.arrayValue ?? []).compactMap(powerProfile).sorted {
                $0.voltageMV < $1.voltageMV
            },
            activeProfileIndex: d["UsbHvcHvcIndex"]?.intValue(in: Plausible.profileIndex)
        )
        // A stale or empty entry (no wattage, no name) means nothing is plugged in.
        guard (adapter.watts ?? 0) > 0 || adapter.name != nil else { return nil }
        return adapter
    }
}
