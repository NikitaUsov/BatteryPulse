import Foundation

/// Locale-aware formatting for the app's UI. The CLI and "Copy Report" stay in English through
/// ``BatteryReport``, so bug reports read the same for everyone.
///
/// Numbers, percentages and durations use Foundation format styles. Unit symbols come from the
/// caller, so the app can localize them through its String Catalog (`Measurement` formatting is
/// not available in swift-corelibs-foundation, where this type is tested).
public struct BatteryFormatter: Sendable {
    public enum Unit: Sendable, CaseIterable {
        case watts, milliampHours, volts, milliamps, amps
    }

    public var locale: Locale
    public var symbol: @Sendable (Unit) -> String

    public init(
        locale: Locale = .current,
        symbol: @escaping @Sendable (Unit) -> String = BatteryFormatter.englishSymbol
    ) {
        self.locale = locale
        self.symbol = symbol
    }

    public static func englishSymbol(_ unit: Unit) -> String {
        switch unit {
        case .watts: "W"
        case .milliampHours: "mAh"
        case .volts: "V"
        case .milliamps: "mA"
        case .amps: "A"
        }
    }

    /// `91` → "91%" (en) or "91 %" (ru).
    public func percent(_ value: Double, fractionDigits: Int = 0) -> String {
        (value / 100).formatted(.percent.precision(.fractionLength(fractionDigits)).locale(locale))
    }

    /// `-10.34` → "−10.3 W" (en); Russian uses a decimal comma and its own unit symbol.
    public func watts(_ value: Double, fractionDigits: Int = 1, signed: Bool = false) -> String {
        withUnit(number(value, fractionDigits: fractionDigits, signed: signed), .watts)
    }

    /// `5862` → "5,862 mAh" (en); Russian groups digits with a space.
    public func milliampHours(_ value: Int) -> String {
        withUnit(value.formatted(.number.locale(locale)), .milliampHours)
    }

    /// `12176` mV → "12.18 V".
    public func volts(millivolts: Int, fractionDigits: Int = 2) -> String {
        withUnit(number(Double(millivolts) / 1000, fractionDigits: fractionDigits), .volts)
    }

    /// `2990` mA → "2.99 A".
    public func amps(milliamps: Int, fractionDigits: Int = 2) -> String {
        withUnit(number(Double(milliamps) / 1000, fractionDigits: fractionDigits), .amps)
    }

    /// `-612` → "−612 mA".
    public func milliamps(_ value: Int, signed: Bool = false) -> String {
        withUnit(number(Double(value), fractionDigits: 0, signed: signed), .milliamps)
    }

    /// `342` → "5 hr, 42 min" (en), with the locale's own abbreviations elsewhere.
    public func duration(minutes: Int) -> String {
        var style = Duration.UnitsFormatStyle(allowedUnits: [.hours, .minutes], width: .abbreviated)
        style.locale = locale
        return Duration.seconds(minutes * 60).formatted(style)
    }

    /// `150` → "2 min, 30 sec" (en).
    public func duration(seconds: Int) -> String {
        var style = Duration.UnitsFormatStyle(allowedUnits: [.hours, .minutes, .seconds], width: .abbreviated)
        style.locale = locale
        return Duration.seconds(seconds).formatted(style)
    }

    /// `31.24` → "31.2 °C".
    public func celsius(_ value: Double) -> String {
        number(value, fractionDigits: 1) + "\u{00A0}°C"
    }

    /// Plain number with the locale's separators.
    public func number(_ value: Double, fractionDigits: Int, signed: Bool = false) -> String {
        // Round first so values like -0.04 print as "0.0", not "−0.0" or "+0.0".
        let scale = pow(10, Double(fractionDigits))
        let rounded = (value * scale).rounded() / scale
        let shown = rounded == 0 ? 0 : rounded
        let sign: NumberFormatStyleConfiguration.SignDisplayStrategy =
            signed && shown != 0 ? .always() : .automatic
        return
            shown
            .formatted(.number.precision(.fractionLength(fractionDigits)).sign(strategy: sign).locale(locale))
            .replacingOccurrences(of: "-", with: "\u{2212}")
    }

    private func withUnit(_ number: String, _ unit: Unit) -> String {
        number + "\u{00A0}" + symbol(unit)
    }
}
