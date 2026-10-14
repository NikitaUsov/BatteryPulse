import Foundation

/// One point-in-time reading of the battery and power state.
///
/// Every field is optional: macOS exposes far more than iOS, and the set of IORegistry keys
/// changes between macOS releases (macOS 27 dropped battery temperature and cell voltages). Units are encoded in property names
/// (`MAh` = milliamp-hours, `MV` = millivolts, `MA` = milliamps, `MW` = milliwatts).
public struct BatterySnapshot: Sendable, Equatable, Codable {
    public var timestamp: Date

    // MARK: Charge

    /// State of charge as the OS reports it, 0...100.
    public var chargePercent: Double?
    public var chargeState: ChargeState
    public var isExternalPowerConnected: Bool?
    /// Minutes until empty while discharging, as estimated by the OS.
    public var timeToEmptyMinutes: Int?
    /// Minutes until full while charging, as estimated by the OS.
    public var timeToFullMinutes: Int?
    /// macOS is holding the charge (usually at 80 %) to reduce battery ageing.
    public var isOptimizedChargingEngaged: Bool?

    // MARK: Capacity & health

    public var currentCapacityMAh: Int?
    /// Capacity the battery can hold right now, as measured by the gauge (`AppleRawMaxCapacity`).
    public var fullChargeCapacityMAh: Int?
    /// Gauge's nominal full-charge capacity; on Apple Silicon this backs "Maximum Capacity".
    public var nominalChargeCapacityMAh: Int?
    public var designCapacityMAh: Int?
    public var cycleCount: Int?
    /// Cycles the battery is rated for (1000 on modern MacBooks).
    public var designCycleCount: Int?
    /// OS health verdict, e.g. "Good" or "Service Recommended".
    public var healthCondition: String?
    /// Non-zero when the gauge has latched a permanent failure.
    public var permanentFailureStatus: Int?

    // MARK: Electrical

    public var voltageMV: Int?
    /// Averaged current; negative while discharging.
    public var amperageMA: Int?
    /// Instantaneous current; negative while discharging.
    public var instantAmperageMA: Int?
    public var cellVoltagesMV: [Int]
    public var temperatureCelsius: Double?

    // MARK: Charger & system power

    public var adapter: PowerAdapter?
    /// Current/voltage the charger is asking the battery to accept.
    public var chargingCurrentMA: Int?
    public var chargingVoltageMV: Int?
    /// Raw bitmask explaining why the battery isn't charging while on external power.
    public var notChargingReason: Int?
    /// Raw code explaining why charging is throttled (0 = not throttled).
    public var slowChargingReason: Int?
    /// Power drawn from the adapter by the whole machine (Apple Silicon telemetry).
    public var systemPowerInMW: Int?
    /// Power consumed by the system, regardless of source (Apple Silicon telemetry).
    public var systemLoadMW: Int?
    /// Power lost converting adapter input (Apple Silicon telemetry).
    public var adapterEfficiencyLossMW: Int?

    // MARK: Identity

    public var deviceName: String?
    public var manufacturer: String?
    public var serialNumber: String?

    // MARK: System

    public var isLowPowerModeEnabled: Bool?
    public var thermalState: ThermalState?

    public init(
        timestamp: Date,
        chargePercent: Double? = nil,
        chargeState: ChargeState = .unknown,
        isExternalPowerConnected: Bool? = nil,
        timeToEmptyMinutes: Int? = nil,
        timeToFullMinutes: Int? = nil,
        isOptimizedChargingEngaged: Bool? = nil,
        currentCapacityMAh: Int? = nil,
        fullChargeCapacityMAh: Int? = nil,
        nominalChargeCapacityMAh: Int? = nil,
        designCapacityMAh: Int? = nil,
        cycleCount: Int? = nil,
        designCycleCount: Int? = nil,
        healthCondition: String? = nil,
        permanentFailureStatus: Int? = nil,
        voltageMV: Int? = nil,
        amperageMA: Int? = nil,
        instantAmperageMA: Int? = nil,
        cellVoltagesMV: [Int] = [],
        temperatureCelsius: Double? = nil,
        adapter: PowerAdapter? = nil,
        chargingCurrentMA: Int? = nil,
        chargingVoltageMV: Int? = nil,
        notChargingReason: Int? = nil,
        slowChargingReason: Int? = nil,
        systemPowerInMW: Int? = nil,
        systemLoadMW: Int? = nil,
        adapterEfficiencyLossMW: Int? = nil,
        deviceName: String? = nil,
        manufacturer: String? = nil,
        serialNumber: String? = nil,
        isLowPowerModeEnabled: Bool? = nil,
        thermalState: ThermalState? = nil
    ) {
        self.timestamp = timestamp
        self.chargePercent = chargePercent
        self.chargeState = chargeState
        self.isExternalPowerConnected = isExternalPowerConnected
        self.timeToEmptyMinutes = timeToEmptyMinutes
        self.timeToFullMinutes = timeToFullMinutes
        self.isOptimizedChargingEngaged = isOptimizedChargingEngaged
        self.currentCapacityMAh = currentCapacityMAh
        self.fullChargeCapacityMAh = fullChargeCapacityMAh
        self.nominalChargeCapacityMAh = nominalChargeCapacityMAh
        self.designCapacityMAh = designCapacityMAh
        self.cycleCount = cycleCount
        self.designCycleCount = designCycleCount
        self.healthCondition = healthCondition
        self.permanentFailureStatus = permanentFailureStatus
        self.voltageMV = voltageMV
        self.amperageMA = amperageMA
        self.instantAmperageMA = instantAmperageMA
        self.cellVoltagesMV = cellVoltagesMV
        self.temperatureCelsius = temperatureCelsius
        self.adapter = adapter
        self.chargingCurrentMA = chargingCurrentMA
        self.chargingVoltageMV = chargingVoltageMV
        self.notChargingReason = notChargingReason
        self.slowChargingReason = slowChargingReason
        self.systemPowerInMW = systemPowerInMW
        self.systemLoadMW = systemLoadMW
        self.adapterEfficiencyLossMW = adapterEfficiencyLossMW
        self.deviceName = deviceName
        self.manufacturer = manufacturer
        self.serialNumber = serialNumber
        self.isLowPowerModeEnabled = isLowPowerModeEnabled
        self.thermalState = thermalState
    }
}

public enum ChargeState: String, Sendable, Codable, CaseIterable {
    case charging
    case discharging
    /// On external power and full.
    case charged
    /// On external power but held below full (optimized charging, charge limit, heat…).
    case notCharging
    case unknown
}

public enum ThermalState: String, Sendable, Codable, CaseIterable {
    case nominal, fair, serious, critical
}

public struct PowerAdapter: Sendable, Equatable, Codable {
    public var watts: Int?
    public var voltageMV: Int?
    public var currentMA: Int?
    public var name: String?
    public var manufacturer: String?
    public var adapterDescription: String?
    public var serialNumber: String?
    public var isWireless: Bool?

    public init(
        watts: Int? = nil,
        voltageMV: Int? = nil,
        currentMA: Int? = nil,
        name: String? = nil,
        manufacturer: String? = nil,
        adapterDescription: String? = nil,
        serialNumber: String? = nil,
        isWireless: Bool? = nil
    ) {
        self.watts = watts
        self.voltageMV = voltageMV
        self.currentMA = currentMA
        self.name = name
        self.manufacturer = manufacturer
        self.adapterDescription = adapterDescription
        self.serialNumber = serialNumber
        self.isWireless = isWireless
    }
}

/// A snapshot together with the raw dictionaries it was parsed from.
///
/// The raw values back the "everything the OS knows" view and make it easy to capture
/// fixtures from real hardware (`bpulse --raw`).
public struct BatteryReading: Sendable, Equatable {
    public var snapshot: BatterySnapshot
    /// `AppleSmartBattery` IORegistry properties (macOS only).
    public var smartBattery: PropertyDictionary
    /// `IOPSGetPowerSourceDescription` for the internal battery (macOS only).
    public var powerSource: PropertyDictionary
    /// `IOPSCopyExternalPowerAdapterDetails` (macOS only).
    public var adapterDetails: PropertyDictionary

    public init(
        snapshot: BatterySnapshot,
        smartBattery: PropertyDictionary = [:],
        powerSource: PropertyDictionary = [:],
        adapterDetails: PropertyDictionary = [:]
    ) {
        self.snapshot = snapshot
        self.smartBattery = smartBattery
        self.powerSource = powerSource
        self.adapterDetails = adapterDetails
    }
}
