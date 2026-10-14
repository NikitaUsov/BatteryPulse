import Foundation

extension BatterySnapshot {
    /// Full-charge capacity relative to design capacity, in percent — macOS's "Maximum Capacity".
    ///
    /// Uses the nominal capacity when available (matches System Settings on Apple Silicon),
    /// otherwise the gauge's measured full-charge capacity.
    public var healthPercent: Double? {
        guard let design = designCapacityMAh, design > 0,
              let full = nominalChargeCapacityMAh ?? fullChargeCapacityMAh
        else { return nil }
        return Double(full) / Double(design) * 100
    }

    /// Capacity lost relative to design, in percent.
    public var wearPercent: Double? {
        healthPercent.map { max(0, 100 - $0) }
    }

    /// Share of the rated cycle life already used (1.0 = rated cycles reached).
    public var cycleLifeUsed: Double? {
        guard let cycles = cycleCount, let rated = designCycleCount, rated > 0 else { return nil }
        return Double(cycles) / Double(rated)
    }

    /// Power flowing into (+) or out of (−) the battery, in watts.
    public var batteryPowerWatts: Double? {
        guard let voltage = voltageMV, let amperage = amperageMA else { return nil }
        return Double(voltage) * Double(amperage) / 1_000_000
    }

    public var systemPowerInWatts: Double? { systemPowerInMW.map { Double($0) / 1000 } }
    public var systemLoadWatts: Double? { systemLoadMW.map { Double($0) / 1000 } }

    /// Difference between the highest and lowest cell voltage. A growing spread hints at an
    /// ageing or unbalanced pack.
    public var cellVoltageSpreadMV: Int? {
        guard cellVoltagesMV.count > 1, let low = cellVoltagesMV.min(), let high = cellVoltagesMV.max() else {
            return nil
        }
        return high - low
    }

    /// The OS estimate when available, otherwise derived from remaining capacity and current.
    public var estimatedTimeToEmptyMinutes: Int? {
        if let timeToEmptyMinutes { return timeToEmptyMinutes }
        guard chargeState == .discharging,
              let capacity = currentCapacityMAh,
              let amperage = amperageMA, amperage < -Self.minimumMeaningfulCurrentMA
        else { return nil }
        return Int((Double(capacity) / Double(-amperage) * 60).rounded())
    }

    /// The OS estimate when available, otherwise derived from missing capacity and current.
    /// The derived value is optimistic: charging slows down near full (constant-voltage phase).
    public var estimatedTimeToFullMinutes: Int? {
        if let timeToFullMinutes { return timeToFullMinutes }
        guard chargeState == .charging,
              let capacity = currentCapacityMAh, let full = fullChargeCapacityMAh, full > capacity,
              let amperage = amperageMA, amperage > Self.minimumMeaningfulCurrentMA
        else { return nil }
        return Int((Double(full - capacity) / Double(amperage) * 60).rounded())
    }

    /// Below this, current readings are noise and time estimates explode.
    static let minimumMeaningfulCurrentMA = 10
}
