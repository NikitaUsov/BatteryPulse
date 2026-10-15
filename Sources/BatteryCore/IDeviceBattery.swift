import Foundation

/// The battery of an iPhone or iPad, read from its `AppleSmartBattery` registry entry over the
/// diagnostics relay. Units are in the property names, as in ``BatterySnapshot``.
///
/// Every field is optional: a value the device doesn't publish stays `nil` rather than being
/// guessed. Checked against an iPhone 17 Pro Max on iOS 27.0.1 and its Settings → Battery.
public struct IDeviceBattery: Sendable, Equatable, Codable {
    /// The registry class that answered (`AppleSmartBattery`, else `IOPMPowerSource`).
    public var source: String?

    /// Charge as iOS shows it, 0...100: the lockdown battery domain's `BatteryCurrentCapacity`,
    /// else the entry's `CurrentCapacity` / `MaxCapacity`.
    public var chargePercent: Double?
    public var chargeState: ChargeState
    public var isExternalPowerConnected: Bool?

    /// Remaining charge measured by the gauge (`BatteryData.RemainingCapacity`, before iOS 27
    /// `AppleRawCurrentCapacity`).
    public var currentCapacityMAh: Int?
    /// What the battery holds when full, measured by the gauge (`BatteryData.FullChargeCapacity`,
    /// before iOS 27 `AppleRawMaxCapacity`).
    public var fullChargeCapacityMAh: Int?
    public var nominalChargeCapacityMAh: Int?
    public var designCapacityMAh: Int?
    /// "Maximum Capacity" as iOS Settings shows it: the device's own figure (`MaximumCapacityPercent`,
    /// or iOS 27's `LifetimeData.NccpFiltered`), else nominal ÷ design capacity, capped at 100 %.
    /// On an iPhone 17 Pro Max with iOS 27.0.1, Settings showed 95 %, `NccpFiltered` was 95 and
    /// 4800 ÷ 5030 mAh is 95.4 %; full charge ÷ design (97.9 %) is not what iOS shows.
    public var maximumCapacityPercent: Double?
    /// When the battery was first used (`DateOfFirstUse`), which iOS Settings shows as the month.
    public var firstUseDate: Date?

    public var cycleCount: Int?
    /// Cycles the battery is rated for, when the gauge publishes it (`DesignCycleCount9C`).
    public var designCycleCount: Int?

    public var temperatureCelsius: Double?
    public var voltageMV: Int?
    /// Averaged current; negative while discharging.
    public var amperageMA: Int?
    /// Instantaneous current; negative while discharging.
    public var instantAmperageMA: Int?
    public var cellVoltagesMV: [Int]

    public var adapter: PowerAdapter?

    /// The gauge's error text (`ErrorCondition`), such as "Cell Check Fault"; absent when
    /// the battery is fine.
    public var errorCondition: String?
    /// Non-zero when the gauge has latched a permanent failure (`PermanentFailureStatus`).
    public var permanentFailureStatus: Int?

    public init(
        source: String? = nil,
        chargePercent: Double? = nil,
        chargeState: ChargeState = .unknown,
        isExternalPowerConnected: Bool? = nil,
        currentCapacityMAh: Int? = nil,
        fullChargeCapacityMAh: Int? = nil,
        nominalChargeCapacityMAh: Int? = nil,
        designCapacityMAh: Int? = nil,
        maximumCapacityPercent: Double? = nil,
        firstUseDate: Date? = nil,
        cycleCount: Int? = nil,
        designCycleCount: Int? = nil,
        temperatureCelsius: Double? = nil,
        voltageMV: Int? = nil,
        amperageMA: Int? = nil,
        instantAmperageMA: Int? = nil,
        cellVoltagesMV: [Int] = [],
        adapter: PowerAdapter? = nil,
        errorCondition: String? = nil,
        permanentFailureStatus: Int? = nil
    ) {
        self.source = source
        self.chargePercent = chargePercent
        self.chargeState = chargeState
        self.isExternalPowerConnected = isExternalPowerConnected
        self.currentCapacityMAh = currentCapacityMAh
        self.fullChargeCapacityMAh = fullChargeCapacityMAh
        self.nominalChargeCapacityMAh = nominalChargeCapacityMAh
        self.designCapacityMAh = designCapacityMAh
        self.maximumCapacityPercent = maximumCapacityPercent
        self.firstUseDate = firstUseDate
        self.cycleCount = cycleCount
        self.designCycleCount = designCycleCount
        self.temperatureCelsius = temperatureCelsius
        self.voltageMV = voltageMV
        self.amperageMA = amperageMA
        self.instantAmperageMA = instantAmperageMA
        self.cellVoltagesMV = cellVoltagesMV
        self.adapter = adapter
        self.errorCondition = errorCondition
        self.permanentFailureStatus = permanentFailureStatus
    }
}

extension IDeviceBattery {
    /// Nominal capacity relative to design, in percent, uncapped. One of two candidates for the
    /// figure iOS Settings shows; which one matches is still to be checked on a real device.
    public var nominalToDesignPercent: Double? {
        ratio(nominalChargeCapacityMAh, designCapacityMAh)
    }

    /// Full-charge capacity relative to design, in percent, uncapped.
    public var fullChargeToDesignPercent: Double? {
        ratio(fullChargeCapacityMAh, designCapacityMAh)
    }

    /// Power flowing into (+) or out of (−) the battery, in watts.
    public var batteryPowerWatts: Double? {
        guard let voltage = voltageMV, let amperage = amperageMA else { return nil }
        return Double(voltage) * Double(amperage) / 1_000_000
    }

    private func ratio(_ value: Int?, _ design: Int?) -> Double? {
        guard let value, let design, design > 0 else { return nil }
        return Double(value) / Double(design) * 100
    }
}

/// Maps the `AppleSmartBattery` (or `IOPMPowerSource`) entry of an iPhone or iPad onto
/// ``IDeviceBattery``.
///
/// The keys are those described for iOS 26 (`DesignCapacity`, `NominalChargeCapacity`,
/// `AppleRawMaxCapacity`, `AppleRawCurrentCapacity`, `CurrentCapacity`/`MaxCapacity` in percent,
/// `CycleCount`, `Voltage`/`AppleRawBatteryVoltage`, `Amperage`, `InstantAmperage`, `IsCharging`,
/// `FullyCharged`, `(AppleRaw)ExternalConnected`, `AdapterDetails`, `Temperature` and
/// `VirtualTemperature` in hundredths of a degree Celsius) and for iPadOS 27, which moved
/// `DesignCapacity` and `NominalChargeCapacity` into `BatteryData` and the temperatures into the
/// `AppleSmartBatteryPack` entry's `BatteryData`. A key the device doesn't publish gives `nil`.
public enum IDeviceBatteryParser {
    /// Parses a capture: its battery entry, the pack entry and the lockdown battery domain.
    public static func battery(in capture: IDeviceCapture) -> IDeviceBattery? {
        guard let entry = capture.batteryEntry else { return nil }
        return battery(
            entry: entry.properties,
            pack: capture.registryEntry(forClass: DiagnosticsRelay.packClass) ?? [:],
            lockdown: capture.lockdownBattery,
            source: entry.className
        )
    }

    /// - Parameters:
    ///   - entry: the battery's registry entry.
    ///   - pack: the `AppleSmartBatteryPack` entry, where iOS 27 keeps the temperature.
    ///   - lockdown: the `com.apple.mobile.battery` lockdown domain.
    /// - Returns: `nil` unless the entry has a positive design, nominal or full-charge capacity,
    ///   so a stray dictionary never becomes a battery.
    public static func battery(
        entry: PropertyDictionary,
        pack: PropertyDictionary = [:],
        lockdown: PropertyDictionary = [:],
        source: String? = nil
    ) -> IDeviceBattery? {
        let data = entry["BatteryData"]?.dictionaryValue ?? [:]
        let packData = pack["BatteryData"]?.dictionaryValue ?? [:]

        /// The first positive value: the entry's `BatteryData` (iOS 27), the entry itself, then
        /// the pack's `BatteryData`.
        func capacity(_ keys: String...) -> Int? {
            for key in keys {
                for source in [data, entry, packData] {
                    if let value = source[key]?.intValue, value > 0 { return value }
                }
            }
            return nil
        }

        var b = IDeviceBattery(source: source)
        b.designCapacityMAh = capacity("DesignCapacity")
        b.nominalChargeCapacityMAh = capacity("NominalChargeCapacity")
        b.fullChargeCapacityMAh = capacity("FullChargeCapacity", "AppleRawMaxCapacity")
        guard b.designCapacityMAh != nil || b.nominalChargeCapacityMAh != nil || b.fullChargeCapacityMAh != nil
        else { return nil }
        b.currentCapacityMAh = capacity("RemainingCapacity", "AppleRawCurrentCapacity")
        let lifetime = [data, packData].compactMap { $0["LifetimeData"]?.dictionaryValue }
        b.maximumCapacityPercent =
            ([entry["MaximumCapacityPercent"], data["MaximumCapacityPercent"]] + lifetime.map { $0["NccpFiltered"] })
            .lazy.compactMap { $0?.doubleValue }.first { (1...100).contains($0) }
            ?? b.nominalToDesignPercent.map { min($0, 100) }
        b.firstUseDate =
            [data["DateOfFirstUse"], packData["DateOfFirstUse"], entry["DateOfFirstUse"]].lazy
            .compactMap { $0?.intValue }.compactMap(firstUseDate(sinceReferenceDate:)).first

        b.cycleCount = (entry["CycleCount"] ?? data["CycleCount"])?.intValue.flatMap { $0 >= 0 ? $0 : nil }
        b.designCycleCount = entry["DesignCycleCount9C"]?.intValue.flatMap { $0 > 0 ? $0 : nil }

        // Charge: what iOS shows first.
        if let percent = lockdown["BatteryCurrentCapacity"]?.intValue, (0...100).contains(percent) {
            b.chargePercent = Double(percent)
        } else if let current = entry["CurrentCapacity"]?.intValue, let max = entry["MaxCapacity"]?.intValue,
            max > 0, current >= 0
        {
            b.chargePercent = MacPowerParser.percent(current, of: max)
        }

        b.isExternalPowerConnected =
            entry["ExternalConnected"]?.boolValue ?? entry["AppleRawExternalConnected"]?.boolValue
            ?? lockdown["ExternalConnected"]?.boolValue
        b.chargeState = MacPowerParser.chargeState(
            isCharging: entry["IsCharging"]?.boolValue ?? lockdown["BatteryIsCharging"]?.boolValue,
            isExternalPowerConnected: b.isExternalPowerConnected,
            isFullyCharged: entry["FullyCharged"]?.boolValue ?? lockdown["FullyCharged"]?.boolValue
        )

        // Electrical. `Voltage` can read 0 on an iPhone.
        b.voltageMV = [entry["Voltage"], entry["AppleRawBatteryVoltage"], packData["Voltage"]].lazy
            .compactMap { $0?.intValue }.first { plausiblePackVoltage.contains($0) }
        b.amperageMA = entry["Amperage"]?.intValue
        b.instantAmperageMA = entry["InstantAmperage"]?.intValue
        let cells = data["CellVoltage"]
        b.cellVoltagesMV = (cells?.arrayValue ?? cells.map { [$0] } ?? []).compactMap(\.intValue)
            .filter { SMCBattery.plausibleCellVoltage.contains($0) }
        // The gauge's sensor first; `VirtualTemperature` is an estimate (on an iPhone 17 Pro Max it
        // read 35.1 °C against the sensor's 36.5 °C) and only fills in when no sensor reads.
        b.temperatureCelsius =
            [
                entry["Temperature"], packData["Temperature"], pack["Temperature"],
                entry["VirtualTemperature"], packData["VirtualTemperature"], pack["VirtualTemperature"],
            ]
            .lazy.compactMap { $0?.intValue }.compactMap(celsius(fromCentidegrees:)).first

        if b.isExternalPowerConnected != false, let details = entry["AdapterDetails"]?.dictionaryValue {
            b.adapter = MacPowerParser.adapter(from: details)
        }

        b.errorCondition = entry["ErrorCondition"]?.stringValue.flatMap { $0.isEmpty ? nil : $0 }
        b.permanentFailureStatus = entry["PermanentFailureStatus"]?.intValue
        return b
    }

    /// `DateOfFirstUse` counts seconds since 2001-01-01, like `Date(timeIntervalSinceReferenceDate:)`;
    /// 0 means "not set". Only dates from the first iPhone on are a reading.
    static func firstUseDate(sinceReferenceDate seconds: Int) -> Date? {
        guard seconds > 0 else { return nil }
        let date = Date(timeIntervalSinceReferenceDate: TimeInterval(seconds))
        return date >= Date(timeIntervalSinceReferenceDate: 189_000_000) ? date : nil  // 2007
    }

    /// One cell, or a few in series; anything else is not a reading.
    static let plausiblePackVoltage = 2_500...20_000

    /// iOS publishes `Temperature` and `VirtualTemperature` in hundredths of a degree Celsius
    /// (macOS publishes its `Temperature` differently, so this conversion is kept separate).
    /// 0 means "no reading".
    static func celsius(fromCentidegrees raw: Int) -> Double? {
        guard raw != 0 else { return nil }
        let celsius = Double(raw) / 100
        return (-40...150).contains(celsius) ? celsius : nil
    }
}
