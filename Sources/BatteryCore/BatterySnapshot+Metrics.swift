import Foundation

extension BatterySnapshot {
    /// Full-charge capacity relative to design capacity, in percent, unclamped: a new battery
    /// often holds more than its design capacity (an M5 at 48 cycles reads 104 %).
    ///
    /// Uses the nominal capacity when available (it backs "Maximum Capacity" on Apple Silicon),
    /// otherwise the gauge's measured full-charge capacity.
    public var capacityToDesignPercent: Double? {
        guard let design = designCapacityMAh, design > 0,
            let full = nominalChargeCapacityMAh ?? fullChargeCapacityMAh
        else { return nil }
        return Double(full) / Double(design) * 100
    }

    /// "Maximum Capacity" as macOS shows it: ``capacityToDesignPercent`` capped at 100 %.
    public var healthPercent: Double? {
        capacityToDesignPercent.map { min(100, $0) }
    }

    /// Charge measured by the gauge (remaining / full-charge mAh). It can differ a little from
    /// the macOS percentage, which keeps a reserve and smooths the value.
    public var hardwareChargePercent: Double? {
        guard let current = currentCapacityMAh, let full = fullChargeCapacityMAh, full > 0 else { return nil }
        return min(100, Double(current) / Double(full) * 100)
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
    public var adapterEfficiencyLossWatts: Double? { adapterEfficiencyLossMW.map { Double($0) / 1000 } }

    /// Difference between the highest and lowest cell voltage. A growing spread hints at an
    /// ageing or unbalanced pack.
    public var cellVoltageSpreadMV: Int? {
        guard cellVoltagesMV.count > 1, let low = cellVoltagesMV.min(), let high = cellVoltagesMV.max() else {
            return nil
        }
        return high - low
    }

    /// Whether ``chargingVoltageMV`` is for one cell rather than the whole pack. Apple silicon on
    /// macOS 27 requests it per cell (4470 mV on a MacBook Air M5); a value above any cell's
    /// voltage is for the pack.
    public var isChargingVoltagePerCell: Bool {
        chargingVoltageMV.map { $0 <= Self.maximumCellChargeVoltageMV } ?? false
    }

    static let maximumCellChargeVoltageMV = 5_000

    /// The OS estimate when available, otherwise derived from remaining capacity and current.
    /// `nil` while macOS is still calculating.
    public var estimatedTimeToEmptyMinutes: Int? {
        if let timeToEmptyMinutes { return timeToEmptyMinutes }
        guard !isTimeRemainingCalculating, chargeState == .discharging,
            let capacity = currentCapacityMAh,
            let amperage = amperageMA, amperage < -Self.minimumMeaningfulCurrentMA
        else { return nil }
        return Int((Double(capacity) / Double(-amperage) * 60).rounded())
    }

    /// The OS estimate when available, otherwise derived from missing capacity and current.
    /// `nil` while macOS is still calculating: the current right after plugging in is far
    /// below the settled charge rate. The derived value ignores the constant-voltage taper.
    public var estimatedTimeToFullMinutes: Int? {
        if let timeToFullMinutes { return timeToFullMinutes }
        guard !isTimeRemainingCalculating, chargeState == .charging,
            let capacity = currentCapacityMAh, let full = fullChargeCapacityMAh, full > capacity,
            let amperage = amperageMA, amperage > Self.minimumMeaningfulCurrentMA
        else { return nil }
        return Int((Double(full - capacity) / Double(amperage) * 60).rounded())
    }

    /// Below this, current readings are noise and time estimates explode.
    static let minimumMeaningfulCurrentMA = 10
}
