import Foundation

/// Plain-text battery report: used by the `bpulse` CLI and the app's "Copy report" action.
///
/// Formatting is locale-independent so the output is stable in tests and when pasted into
/// bug reports, and it never includes serial numbers. The app renders its own localized UI
/// from ``BatterySnapshot`` directly.
public enum BatteryReport {
    public struct Line: Sendable, Equatable {
        public var label: String
        public var value: String
    }

    public static func lines(for s: BatterySnapshot) -> [Line] {
        var lines: [Line] = []
        func add(_ label: String, _ value: String?) {
            if let value { lines.append(Line(label: label, value: value)) }
        }

        // Charge. No serial number: this text is meant to be pasted into public bug reports.
        add("Battery", joined([s.deviceName, s.manufacturer]))

        if let percent = s.chargePercent {
            var value = "\(fixed(percent, 0)) %"
            if let current = s.currentCapacityMAh, let full = s.fullChargeCapacityMAh {
                value += "  (\(current) of \(full) mAh)"
            }
            add("Charge", value)
        }
        add("State", stateDescription(s))
        if s.isTimeRemainingCalculating {
            add(s.chargeState == .charging ? "Time to full" : "Time to empty", "calculating…")
        } else {
            // OS estimates are shown as is; values derived from capacity and current get "≈".
            add("Time to empty", timeRemaining(os: s.timeToEmptyMinutes, derived: s.estimatedTimeToEmptyMinutes))
            add("Time to full", timeRemaining(os: s.timeToFullMinutes, derived: s.estimatedTimeToFullMinutes))
        }

        if let watts = s.batteryPowerWatts, let voltage = s.voltageMV, let amperage = s.amperageMA {
            add("Battery power", "\(signed(watts, 1)) W  (\(fixed(Double(voltage) / 1000, 2)) V × \(amperage) mA)")
        }

        // Health.
        if let health = s.healthPercent, let ratio = s.capacityToDesignPercent, let design = s.designCapacityMAh {
            let full = s.nominalChargeCapacityMAh ?? s.fullChargeCapacityMAh ?? 0
            var value = "\(fixed(health, 1)) %  (\(full) of \(design) mAh design"
            // macOS caps "Maximum Capacity" at 100 %; show the real ratio when it is higher.
            value += ratio > health ? " = \(fixed(ratio, 1)) %)" : ")"
            add("Health", value)
        }
        add("Condition", s.healthCondition)
        if let failure = s.permanentFailureStatus, failure != 0 {
            add("Permanent failure", hex(failure))
        }
        if let cycles = s.cycleCount {
            if let rated = s.designCycleCount, let used = s.cycleLifeUsed {
                add("Cycles", "\(cycles) of \(rated)  (\(fixed(used * 100, 0)) % of rated life)")
            } else {
                add("Cycles", String(cycles))
            }
        }
        add("Temperature", s.temperatureCelsius.map { "\(fixed($0, 1)) °C" })

        if !s.cellVoltagesMV.isEmpty {
            var value = s.cellVoltagesMV.map(String.init).joined(separator: " / ") + " mV"
            if let spread = s.cellVoltageSpreadMV { value += "  (spread \(spread) mV)" }
            add("Cells", value)
        }

        // Power.
        add("Adapter", s.adapter.map(adapterSummary))
        if let current = s.chargingCurrentMA, let voltage = s.chargingVoltageMV, current > 0, voltage > 0 {
            let perCell = s.isChargingVoltagePerCell ? " per cell" : ""
            add("Charger request", "\(current) mA at \(fixed(Double(voltage) / 1000, 2)) V" + perCell)
        }
        // The gauge reports a "not charging" reason on battery too; it only means something
        // while an adapter is connected.
        if let reason = s.notChargingReason, reason != 0, s.isExternalPowerConnected == true {
            add("Not charging reason", hex(reason))
        }
        if let reason = s.slowChargingReason, reason != 0, s.chargeState == .charging {
            add("Slow charging reason", hex(reason))
        }
        add("System input", s.systemPowerInWatts.flatMap { $0 > 0 ? "\(fixed($0, 1)) W" : nil })
        add("System load", s.systemLoadWatts.map { "\(fixed($0, 1)) W" })
        if s.isExternalPowerConnected == true, let loss = s.adapterEfficiencyLossWatts, loss > 0 {
            add("Adapter loss", "\(fixed(loss, 1)) W")
        }
        add("Optimized charging", s.isOptimizedChargingEngaged.map { $0 ? "holding charge" : "inactive" })

        // System.
        add("Low Power Mode", s.isLowPowerModeEnabled.map { $0 ? "on" : "off" })
        add("Thermal state", s.thermalState?.rawValue)
        return lines
    }

    public static func text(for snapshot: BatterySnapshot) -> String {
        text(lines(for: snapshot))
    }

    /// The lines as two columns, the values aligned two spaces after the longest label.
    static func text(_ lines: [Line]) -> String {
        let width = lines.map(\.label.count).max() ?? 0
        return
            lines
            .map { $0.label.padding(toLength: width + 2, withPad: " ", startingAt: 0) + $0.value }
            .joined(separator: "\n")
    }

    // MARK: - Formatting helpers

    /// "96 W · USB-C Power Adapter · 20.0 V × 4.80 A", or "connected" when the adapter says
    /// nothing about itself.
    static func adapterSummary(_ adapter: PowerAdapter) -> String {
        var parts: [String] = []
        if let watts = adapter.watts { parts.append("\(watts) W") }
        if let name = adapter.name ?? adapter.adapterDescription { parts.append(name) }
        if let voltage = adapter.voltageMV, let current = adapter.currentMA {
            parts.append("\(fixed(Double(voltage) / 1000, 1)) V × \(fixed(Double(current) / 1000, 2)) A")
        }
        if adapter.isWireless == true { parts.append("wireless") }
        return parts.isEmpty ? "connected" : parts.joined(separator: " · ")
    }

    static func stateDescription(_ s: BatterySnapshot) -> String {
        switch s.chargeState {
        case .charging: "Charging"
        case .discharging: "Discharging"
        case .charged: "Fully charged, on power adapter"
        case .notCharging: "On power adapter, not charging"
        case .unknown: "Unknown"
        }
    }

    static func timeRemaining(os: Int?, derived: Int?) -> String? {
        if let os { return duration(os) }
        return derived.map { "≈ " + duration($0) }
    }

    /// `75` → "1 h 15 min", `40` → "40 min".
    static func duration(_ minutes: Int) -> String {
        let hours = minutes / 60
        let rest = minutes % 60
        return hours > 0 ? "\(hours) h \(rest) min" : "\(rest) min"
    }

    static func fixed(_ value: Double, _ digits: Int) -> String {
        cFormat("%.\(digits)f", value)
    }

    /// Explicit sign, except for values that round to zero ("0.0", not "+0.0" or "-0.0").
    static func signed(_ value: Double, _ digits: Int) -> String {
        let unsigned = fixed(value, digits)
        return Double(unsigned) == 0 ? fixed(0, digits) : cFormat("%+.\(digits)f", value)
    }

    /// "0x1A2B": what C's `0x%X` prints for an `Int`, which is its low 32 bits.
    static func hex(_ value: Int) -> String {
        "0x" + String(UInt32(truncatingIfNeeded: value), radix: 16, uppercase: true)
    }

    /// C's rounding to a fixed number of digits, which nothing else in Foundation matches.
    /// Darwin's Foundation marks `String(format:)` unsafe, since a format that doesn't match its
    /// arguments reads memory it shouldn't; Linux's doesn't. Both callers build a format with a
    /// single `f` conversion for the one `Double`, so this is the one place it is used.
    private static func cFormat(_ format: String, _ value: Double) -> String {
        #if canImport(Darwin)
        return unsafe String(format: format, value)
        #else
        return String(format: format, value)
        #endif
    }

    private static func joined(_ parts: [String?]) -> String? {
        let present = parts.compactMap { $0 }.filter { !$0.isEmpty }
        return present.isEmpty ? nil : present.joined(separator: " · ")
    }
}
