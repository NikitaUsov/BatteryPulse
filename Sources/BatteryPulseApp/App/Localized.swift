#if os(macOS)
import BatteryCore
import BatteryKit
import Foundation
import SwiftUI

// User-visible wording lives in Resources/Localizable.xcstrings (English source, Russian).
// Conventions: literal keys are the English text; interpolations are always pre-formatted
// Strings (so every placeholder is %@), and numbers go through BatteryFormatter.app.

extension BatteryFormatter {
    /// The app's formatter, built once: the user's region, which it follows when it changes in
    /// System Settings, and the catalog's unit symbols, looked up once per launch like the rest of
    /// the app's language.
    static let app = BatteryFormatter(
        locale: .autoupdatingCurrent,
        symbols: UnitSymbols(
            watts: String(localized: "W", comment: "Unit symbol: watts"),
            milliampHours: String(localized: "mAh", comment: "Unit symbol: milliampere-hours"),
            volts: String(localized: "V", comment: "Unit symbol: volts"),
            millivolts: String(localized: "mV", comment: "Unit symbol: millivolts"),
            milliamps: String(localized: "mA", comment: "Unit symbol: milliamperes"),
            amps: String(localized: "A", comment: "Unit symbol: amperes")))
}

/// Localized phrases built from battery state.
enum Phrases {
    static func state(_ s: BatterySnapshot) -> String {
        if s.chargeState == .notCharging, s.isOptimizedChargingEngaged == true {
            return String(localized: "Charging on hold")
        }
        return state(s.chargeState)
    }

    /// The charge state of any battery. iPhones and iPads report no optimized hold, so "Charging
    /// on hold" stays the Mac's.
    static func state(_ state: ChargeState) -> String {
        switch state {
        case .charging: String(localized: "Charging")
        case .discharging: String(localized: "On battery")
        case .charged: String(localized: "Fully charged")
        case .notCharging: String(localized: "Not charging")
        case .unknown: String(localized: "Unknown")
        }
    }

    /// Why an iPhone or iPad couldn't be read, worded for the person holding it. `name` is the
    /// device's name as the page shows it. The English `IDeviceProblem.description` stays for
    /// `bpulse`.
    static func deviceProblem(_ problem: IDeviceProblem, name: String, connection: IDeviceConnection?) -> String {
        switch problem {
        case .notTrusted:
            String(
                localized:
                    "“\(name)” doesn't trust this Mac. Unlock it and tap Trust; if no prompt appears, select it in Finder once."
            )
        case .locked:
            String(localized: "Unlock “\(name)” to read its battery.")
        case .unreachable, .transportFailed:
            if connection == .wifi {
                String(
                    localized:
                        "“\(name)” didn't answer. Keep it unlocked and on the same Wi-Fi network as this Mac, or connect it by cable."
                )
            } else {
                String(localized: "“\(name)” didn't answer. Check the cable and try again.")
            }
        case .sessionFailed, .relayUnavailable:
            String(localized: "BatteryPulse couldn't read “\(name)”. Try again in a moment.")
        case .noBattery:
            String(localized: "“\(name)” didn't report a battery.")
        }
    }

    /// Why no device can be listed: the framework is missing for good, or listing failed.
    static func deviceUnavailable(_ error: IDeviceError) -> String {
        switch error {
        case .frameworkUnavailable:
            String(localized: "This Mac can't read iPhones and iPads: Apple's device support isn't available.")
        case .subscriptionFailed, .deviceNotFound, .timedOut:
            String(localized: "BatteryPulse couldn't look for devices. Try again in a moment.")
        }
    }

    /// "Charging at 31.3 W" / "Discharging at 7.5 W", or just the state.
    static func stateWithPower(_ s: BatterySnapshot, _ f: BatteryFormatter) -> String {
        guard let watts = s.batteryPowerWatts, abs(watts) >= BatteryPresentation.powerFlowDeadBandWatts else {
            return state(s)
        }
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

    /// The words on Clear's warning badge for a health tier: the condition macOS reports, or what
    /// the tier means when only the capacity (below 80 %) warns.
    static func healthWarning(_ tier: BatteryPresentation.LevelTier, condition raw: String?) -> String {
        if let raw, raw != "Normal", raw != "Good", let text = condition(raw) { return text }
        return condition(for: tier)
    }

    /// A health tier in the words of a battery condition: an iPhone's or iPad's condition, which
    /// comes from its capacity alone, and a Mac's warning when only its capacity warns.
    static func condition(for tier: BatteryPresentation.LevelTier) -> String {
        switch tier {
        case .normal: String(localized: "Normal", comment: "Battery condition")
        case .low: String(localized: "Service Recommended", comment: "Battery condition")
        case .critical: String(localized: "Check Battery", comment: "Battery condition")
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

    // MARK: Accessories

    /// What kind of accessory; also its name when it reports none.
    static func accessoryKind(_ kind: AccessoryKind) -> String {
        switch kind {
        case .keyboard: String(localized: "Keyboard")
        case .mouse: String(localized: "Mouse")
        case .trackpad: String(localized: "Trackpad")
        case .headphones: String(localized: "Headphones")
        case .speaker: String(localized: "Speaker")
        case .gameController: String(localized: "Game Controller")
        case .hearingAid: String(localized: "Hearing Aid")
        case .other: String(localized: "Accessory")
        }
    }

    /// The accessory's name, or its kind when it reports none.
    static func accessoryName(_ accessory: AccessoryBattery) -> String {
        accessory.name.isEmpty ? accessoryKind(accessory.kind) : accessory.name
    }

    /// "Keyboard · Bluetooth": the kind and the connection, which reads the same in every language.
    static func accessoryDetails(_ accessory: AccessoryBattery) -> String {
        [accessoryKind(accessory.kind), accessory.transport.displayName].compactMap { $0 }.joined(separator: " · ")
    }

    /// A part's label. A combined part next to a case is both earbuds; alone it is the battery.
    static func accessoryPart(_ role: AccessoryPartRole, hasParts: Bool) -> String {
        switch role {
        case .left: return String(localized: "Left")
        case .right: return String(localized: "Right")
        case .case: return String(localized: "Case")
        case .combined:
            if hasParts { return String(localized: "Earbuds") }
            return String(localized: "Battery")
        case .single, .other: return String(localized: "Battery")
        }
    }

    /// The state worth naming next to a part's charge, or `nil` while it simply drains.
    static func accessoryStatus(_ part: AccessoryPart) -> String? {
        if part.isCharging { return String(localized: "Charging") }
        if part.isOffline { return String(localized: "Last known charge") }
        if part.isOnExternalPower { return String(localized: "Connected to power") }
        return nil
    }
}

extension WindowLook {
    var title: LocalizedStringKey {
        switch self {
        case .standard: "Standard"
        case .frosted: "Frosted"
        case .translucent: "Translucent"
        case .clear: "Clear"
        }
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
#endif
