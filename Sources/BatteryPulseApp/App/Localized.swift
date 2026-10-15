#if os(macOS)
import BatteryCore
import Foundation
import SwiftUI

// User-visible wording lives in Resources/Localizable.xcstrings (English source, Russian).
// Conventions: literal keys are the English text; interpolations are always pre-formatted
// Strings (so every placeholder is %@), and numbers go through BatteryFormatter.app.

extension BatteryFormatter {
    /// Formatter for the current locale with localized unit symbols.
    static var app: BatteryFormatter {
        BatteryFormatter(locale: .current) { unit in
            switch unit {
            case .watts: String(localized: "W", comment: "Unit symbol: watts")
            case .milliampHours: String(localized: "mAh", comment: "Unit symbol: milliampere-hours")
            case .volts: String(localized: "V", comment: "Unit symbol: volts")
            case .millivolts: String(localized: "mV", comment: "Unit symbol: millivolts")
            case .milliamps: String(localized: "mA", comment: "Unit symbol: milliamperes")
            case .amps: String(localized: "A", comment: "Unit symbol: amperes")
            }
        }
    }
}

/// Localized phrases built from battery state.
enum Phrases {
    static func state(_ s: BatterySnapshot) -> String {
        switch s.chargeState {
        case .charging: String(localized: "Charging")
        case .discharging: String(localized: "On battery")
        case .charged: String(localized: "Fully charged")
        case .notCharging:
            s.isOptimizedChargingEngaged == true
                ? String(localized: "Charging on hold") : String(localized: "Not charging")
        case .unknown: String(localized: "Unknown")
        }
    }

    /// "Charging at 31.3 W" / "Discharging at 7.5 W", or just the state.
    static func stateWithPower(_ s: BatterySnapshot, _ f: BatteryFormatter) -> String {
        guard let watts = s.batteryPowerWatts, abs(watts) >= 0.05 else { return state(s) }
        let power = f.watts(abs(watts))
        switch s.chargeState {
        case .charging: return String(localized: "Charging at \(power)")
        case .discharging: return String(localized: "Discharging at \(power)")
        case .charged, .notCharging, .unknown: return state(s)
        }
    }

    /// "5 hr, 42 min left", "Full in 42 min", "Calculating time…"; "≈" marks app estimates.
    static func timeRemaining(_ s: BatterySnapshot, _ f: BatteryFormatter) -> String? {
        if s.isTimeRemainingCalculating { return String(localized: "Calculating time…") }
        switch s.chargeState {
        case .discharging:
            if let minutes = s.timeToEmptyMinutes {
                return String(localized: "\(f.duration(minutes: minutes)) left")
            }
            return s.estimatedTimeToEmptyMinutes.map {
                String(localized: "About \(f.duration(minutes: $0)) left")
            }
        case .charging:
            if let minutes = s.timeToFullMinutes {
                return String(localized: "Full in \(f.duration(minutes: minutes))")
            }
            return s.estimatedTimeToFullMinutes.map {
                String(localized: "Full in about \(f.duration(minutes: $0))")
            }
        case .charged, .notCharging, .unknown:
            return nil
        }
    }

    /// macOS reports "Normal" (our default) or a problem such as "Service Recommended".
    static func condition(_ raw: String?) -> String? {
        switch raw {
        case nil: nil
        case "Normal", "Good": String(localized: "Normal", comment: "Battery condition")
        case "Fair": String(localized: "Fair", comment: "Battery condition")
        case "Poor": String(localized: "Poor", comment: "Battery condition")
        case "Check Battery": String(localized: "Check Battery", comment: "Battery condition")
        case "Service Recommended": String(localized: "Service Recommended", comment: "Battery condition")
        case let other?: other
        }
    }

    static func thermal(_ state: ThermalState) -> String {
        switch state {
        case .nominal: String(localized: "Normal", comment: "Thermal state")
        case .fair: String(localized: "Elevated", comment: "Thermal state")
        case .serious: String(localized: "High", comment: "Thermal state")
        case .critical: String(localized: "Critical", comment: "Thermal state")
        }
    }

    static func onOff(_ value: Bool) -> String {
        value ? String(localized: "On") : String(localized: "Off")
    }

    /// What VoiceOver reads for the menu bar icon: "Battery charge: 70%, Charging".
    static func batteryIcon(_ s: BatterySnapshot?, _ f: BatteryFormatter) -> String {
        guard let s, let percent = s.chargePercent else { return String(localized: "Battery") }
        return String(localized: "Battery charge: \(f.percent(percent)), \(state(s))")
    }

    /// "48 of 1,000".
    static func count(_ value: Int, of total: Int) -> String {
        String(localized: "\(value.formatted()) of \(total.formatted())")
    }
}

extension MenuBarIconStyle {
    var title: LocalizedStringKey {
        switch self {
        case .symbol: "Symbol"
        case .modern: "Modern"
        case .classic: "Classic"
        case .percentageInside: "Percentage Inside"
        case .ring: "Ring"
        }
    }
}

extension BatteryPresentation.LevelTier {
    var color: Color {
        switch self {
        case .normal: .green
        case .low: .orange
        case .critical: .red
        }
    }
}
#endif
