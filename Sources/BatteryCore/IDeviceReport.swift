import Foundation

/// Plain-text report of an iPhone or iPad battery read (`bpulse --device <n>`).
///
/// Locale-independent like ``BatteryReport``. Both capacity ratios are printed, because which of
/// them iOS Settings calls "Maximum Capacity" is still to be checked on a real device.
public enum IDeviceReport {
    public static func lines(for capture: IDeviceCapture) -> [BatteryReport.Line] {
        var lines: [BatteryReport.Line] = []
        func add(_ label: String, _ value: String?) {
            if let value { lines.append(BatteryReport.Line(label: label, value: value)) }
        }
        let fixed = BatteryReport.fixed
        let signed = BatteryReport.signed

        add("Device", deviceDescription(capture))
        if let problem = capture.problem {
            add("Problem", problem.description)
            add("Calls", callSummary(capture))
            return lines
        }
        guard let b = IDeviceBatteryParser.battery(in: capture) else {
            add("Problem", "The battery entry has no capacity values.")
            add("Calls", callSummary(capture))
            return lines
        }

        if let percent = b.chargePercent {
            var value = "\(fixed(percent, 0)) %"
            if let current = b.currentCapacityMAh, let full = b.fullChargeCapacityMAh {
                value += "  (\(current) of \(full) mAh)"
            }
            add("Charge", value)
        }
        add("State", stateDescription(b.chargeState))
        add("Maximum capacity", b.maximumCapacityPercent.map { "\(fixed($0, 0)) %  (reported by the device)" })
        add("Design capacity", b.designCapacityMAh.map { "\($0) mAh" })
        add("Nominal capacity", capacity(b.nominalChargeCapacityMAh, ratio: b.nominalToDesignPercent))
        add("Full charge capacity", capacity(b.fullChargeCapacityMAh, ratio: b.fullChargeToDesignPercent))
        if let cycles = b.cycleCount {
            add("Cycles", b.designCycleCount.map { "\(cycles) of \($0)" } ?? String(cycles))
        }
        add("Condition", b.errorCondition)
        if let failure = b.permanentFailureStatus, failure != 0 {
            add("Permanent failure", String(format: "0x%X", failure))
        }
        add("Temperature", b.temperatureCelsius.map { "\(fixed($0, 1)) °C" })
        add("Voltage", b.voltageMV.map { "\(fixed(Double($0) / 1000, 2)) V" })
        if let amperage = b.amperageMA {
            var value = "\(signedInteger(amperage)) mA"
            if let instant = b.instantAmperageMA, instant != amperage {
                value += "  (now \(signedInteger(instant)) mA)"
            }
            add("Current", value)
        }
        add("Battery power", b.batteryPowerWatts.map { "\(signed($0, 1)) W" })
        if !b.cellVoltagesMV.isEmpty {
            add("Cells", b.cellVoltagesMV.map(String.init).joined(separator: " / ") + " mV")
        }
        if let adapter = b.adapter {
            var parts: [String] = []
            if let watts = adapter.watts { parts.append("\(watts) W") }
            if let name = adapter.name ?? adapter.adapterDescription { parts.append(name) }
            if let voltage = adapter.voltageMV, let current = adapter.currentMA {
                parts.append("\(fixed(Double(voltage) / 1000, 1)) V × \(fixed(Double(current) / 1000, 2)) A")
            }
            if adapter.isWireless == true { parts.append("wireless") }
            add("Adapter", parts.isEmpty ? "connected" : parts.joined(separator: " · "))
        }
        add("Source", b.source.map { "\($0) entry, diagnostics relay" })
        return lines
    }

    public static func text(for capture: IDeviceCapture) -> String {
        let lines = lines(for: capture)
        let width = lines.map(\.label.count).max() ?? 0
        return
            lines
            .map { $0.label.padding(toLength: width + 2, withPad: " ", startingAt: 0) + $0.value }
            .joined(separator: "\n")
    }

    /// "iPhone18,2 · iOS 27.0.1 (24A350) · USB · ID …801C"; the owner's device name is left out.
    /// The identifier is shortened as `bpulse --devices` prints it, so the report shows which
    /// listed device was read; a redacted capture (`--raw`) has none to show.
    static func deviceDescription(_ capture: IDeviceCapture) -> String? {
        let device = capture.device
        var parts: [String] = []
        if let model = IDeviceList.nonEmpty(device["ProductType"]?.stringValue) { parts.append(model) }
        if let version = IDeviceList.nonEmpty(device["ProductVersion"]?.stringValue) {
            var value = IDeviceInfo.osName(deviceClass: device["DeviceClass"]?.stringValue) + " " + version
            if let build = IDeviceList.nonEmpty(device["BuildVersion"]?.stringValue) { value += " (\(build))" }
            parts.append(value)
        }
        if let connection = capture.connection { parts.append(connection.rawValue) }
        if let identifier = IDeviceList.nonEmpty(device[IDeviceCapture.Key.identifier]?.stringValue),
            identifier != BatteryReading.redactedPlaceholder
        {
            parts.append(IDeviceList.identifierLabel(identifier))
        }
        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }

    /// "Connect 0x0 · ValidatePairing 0x0 · StartSession 0xE800001A kAMDPasswordProtectedError …".
    static func callSummary(_ capture: IDeviceCapture) -> String? {
        var parts = capture.steps.map { "\($0.call.rawValue) \($0.status)" }
        if let paired = capture.isPaired { parts.insert("IsPaired \(paired ? "yes" : "no")", at: min(1, parts.count)) }
        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }

    /// "+1476", "-612", "0".
    static func signedInteger(_ value: Int) -> String {
        value > 0 ? "+\(value)" : String(value)
    }

    static func capacity(_ value: Int?, ratio: Double?) -> String? {
        guard let value else { return nil }
        guard let ratio else { return "\(value) mAh" }
        return "\(value) mAh  (\(BatteryReport.fixed(ratio, 1)) % of design)"
    }

    static func stateDescription(_ state: ChargeState) -> String {
        switch state {
        case .charging: "Charging"
        case .discharging: "Discharging"
        case .charged: "Fully charged, on power"
        case .notCharging: "On power, not charging"
        case .unknown: "Unknown"
        }
    }
}
