import Foundation

/// Locale-aware formatting for the app's UI. The CLI and "Copy Report" stay in English through
/// ``BatteryReport``, so bug reports read the same for everyone.
///
/// Numbers, percentages and durations use Foundation format styles. Unit symbols come from the
/// caller, so the app can localize them through its String Catalog (`Measurement` formatting is
/// not available in swift-corelibs-foundation, where this type is tested).
///
/// A plain value: two formatters with the same locale and symbols are equal, so a view that takes
/// one can be compared with its previous inputs.
public struct BatteryFormatter: Sendable, Equatable {
    /// The symbol written after each unit's numbers.
    public struct UnitSymbols: Sendable, Equatable {
        public var watts: String
        public var milliampHours: String
        public var volts: String
        public var millivolts: String
        public var milliamps: String
        public var amps: String

        public init(
            watts: String, milliampHours: String, volts: String, millivolts: String, milliamps: String, amps: String
        ) {
            self.watts = watts
            self.milliampHours = milliampHours
            self.volts = volts
            self.millivolts = millivolts
            self.milliamps = milliamps
            self.amps = amps
        }

        /// "W", "mAh", "V", "mV", "mA" and "A".
        public static let english = UnitSymbols(
            watts: "W", milliampHours: "mAh", volts: "V", millivolts: "mV", milliamps: "mA", amps: "A")
    }

    public var locale: Locale
    public var symbols: UnitSymbols

    public init(locale: Locale = .current, symbols: UnitSymbols = .english) {
        self.locale = locale
        self.symbols = symbols
    }

    /// `91` → "91%" (en) or "91 %" (ru).
    public func percent(_ value: Double, fractionDigits: Int = 0) -> String {
        (value / 100).formatted(.percent.precision(.fractionLength(fractionDigits)).locale(locale))
    }

    /// `-10.34` → "−10.3 W" (en); Russian uses a decimal comma and its own unit symbol.
    public func watts(_ value: Double, fractionDigits: Int = 1, signed: Bool = false) -> String {
        withUnit(number(value, fractionDigits: fractionDigits, signed: signed), symbols.watts)
    }

    /// `5862` → "5,862 mAh" (en); Russian groups digits with a space.
    public func milliampHours(_ value: Int) -> String {
        withUnit(value.formatted(.number.locale(locale)), symbols.milliampHours)
    }

    /// `12176` mV → "12.18 V".
    public func volts(millivolts: Int, fractionDigits: Int = 2) -> String {
        withUnit(number(Double(millivolts) / 1000, fractionDigits: fractionDigits), symbols.volts)
    }

    /// `6` → "6 mV", for small differences such as the spread between cells.
    public func millivolts(_ value: Int) -> String {
        withUnit(value.formatted(.number.locale(locale)), symbols.millivolts)
    }

    /// `2990` mA → "2.99 A".
    public func amps(milliamps: Int, fractionDigits: Int = 2) -> String {
        withUnit(number(Double(milliamps) / 1000, fractionDigits: fractionDigits), symbols.amps)
    }

    /// `-612` → "−612 mA".
    public func milliamps(_ value: Int, signed: Bool = false) -> String {
        withUnit(number(Double(value), fractionDigits: 0, signed: signed), symbols.milliamps)
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

    /// `31.24` → "31.2 °C"; with no fraction digits, "31 °C".
    public func celsius(_ value: Double, fractionDigits: Int = 1) -> String {
        number(value, fractionDigits: fractionDigits) + "\u{00A0}°C"
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

    private func withUnit(_ number: String, _ symbol: String) -> String {
        number + "\u{00A0}" + symbol
    }
}
