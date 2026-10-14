#if os(macOS)
import BatteryCore
import Foundation

/// Localized text for decoded raw values and glossary summaries in the Developer section.
enum RawValueText {
    static func string(for decoded: DecodedRawValue, _ f: BatteryFormatter = .app) -> String {
        switch decoded {
        case .milliampHours(let value): f.milliampHours(value)
        case .millivolts(let value): f.volts(millivolts: value, fractionDigits: 3)
        case .milliamps(let value): f.milliamps(value)
        case .milliwatts(let value): f.watts(Double(value) / 1000, fractionDigits: 2)
        case .percent(let value): f.percent(value)
        case .celsius(let value): f.celsius(value)
        case .minutes(let value): f.duration(minutes: value)
        case .seconds(let value): f.duration(seconds: value)
        case .date(let date): date.formatted(date: .abbreviated, time: .standard)
        case .boolean(let value): value ? String(localized: "Yes") : String(localized: "No")
        case .bits(let value, let setBits): bits(value, setBits)
        case .powerDataObject(let object): powerDataObject(object, f)
        case .requestDataObject(let object): requestDataObject(object, f)
        case .sentinel(let sentinel): sentinelText(sentinel)
        }
    }

    /// The glossary summary in the app's language; English when the catalog has no entry.
    static func summary(_ english: String) -> String {
        Bundle.main.localizedString(forKey: english, value: english, table: nil)
    }

    private static func bits(_ value: UInt64, _ setBits: [Int]) -> String {
        let hex = "0x" + String(value, radix: 16, uppercase: true)
        guard !setBits.isEmpty else { return hex }
        let list = setBits.map(String.init).joined(separator: ", ")
        return setBits.count == 1
            ? String(localized: "\(hex) (bit \(list))") : String(localized: "\(hex) (bits \(list))")
    }

    private static func powerDataObject(_ object: USBPowerDataObject, _ f: BatteryFormatter) -> String {
        switch object {
        case .fixed(let voltage, let current):
            let volts = volts(voltage, f)
            let amps = f.amps(milliamps: current)
            return String(localized: "Fixed \(volts) × \(amps)")
        case .variable(let minVoltage, let maxVoltage, let current):
            let range = "\(volts(minVoltage, f))–\(volts(maxVoltage, f))"
            let amps = f.amps(milliamps: current)
            return String(localized: "Variable \(range) × \(amps)")
        case .battery(let minVoltage, let maxVoltage, let power):
            let range = "\(volts(minVoltage, f))–\(volts(maxVoltage, f))"
            let watts = f.watts(Double(power) / 1000, fractionDigits: 0)
            return String(localized: "Battery \(range), \(watts)")
        case .programmable(let minVoltage, let maxVoltage, let current):
            let range = "\(volts(minVoltage, f))–\(volts(maxVoltage, f))"
            let amps = f.amps(milliamps: current)
            return String(localized: "PPS \(range) × \(amps)")
        case .otherAugmented(let raw):
            let hex = "0x" + String(raw, radix: 16, uppercase: true)
            return String(localized: "Augmented \(hex)")
        }
    }

    private static func requestDataObject(_ object: USBRequestDataObject, _ f: BatteryFormatter) -> String {
        let position = object.objectPosition.formatted()
        let operating = f.amps(milliamps: object.operatingCurrentMA)
        let maximum = f.amps(milliamps: object.maxCurrentMA)
        return String(localized: "Offer \(position): \(operating), max \(maximum)")
    }

    private static func sentinelText(_ sentinel: RawSentinel) -> String {
        switch sentinel {
        case .notAvailable: String(localized: "Not available")
        case .calculating: String(localized: "Calculating…")
        case .none: String(localized: "None")
        }
    }

    /// Whole volts without decimals ("20 V"), otherwise as many as needed ("3.3 V").
    private static func volts(_ millivolts: Int, _ f: BatteryFormatter) -> String {
        let digits = millivolts % 1000 == 0 ? 0 : millivolts % 100 == 0 ? 1 : 2
        return f.volts(millivolts: millivolts, fractionDigits: digits)
    }
}
#endif
