#if os(macOS)
import BatteryCore
import Foundation

extension BatteryFormatter {
    /// The widget's formatter in the extension's own language, without a feed, built once per
    /// extension process: the user's region, which it follows when it changes in System Settings,
    /// and the catalog's unit symbols, the six keys of the app's `BatteryFormatter.app`
    /// (`WidgetSourceTests` keeps the two lists equal), looked up in the widget bundle's own
    /// tables.
    static let widget = BatteryFormatter(
        locale: .autoupdatingCurrent,
        symbols: UnitSymbols(
            watts: String(localized: "W", comment: "Unit symbol: watts"),
            milliampHours: String(localized: "mAh", comment: "Unit symbol: milliampere-hours"),
            volts: String(localized: "V", comment: "Unit symbol: volts"),
            millivolts: String(localized: "mV", comment: "Unit symbol: millivolts"),
            milliamps: String(localized: "mA", comment: "Unit symbol: milliamperes"),
            amps: String(localized: "A", comment: "Unit symbol: amperes")))

    /// The widget's formatter in the language it draws in (`WidgetLanguageTable`): `locale`'s
    /// numbers, and the same six unit symbols looked up in that language's table, `strings`, as
    /// the previews look them up (`WidgetSourceTests` keeps the keys the app's).
    static func widget(locale: Locale, strings: Bundle) -> BatteryFormatter {
        let symbol = { (key: String) in strings.localizedString(forKey: key, value: nil, table: nil) }
        return BatteryFormatter(
            locale: locale,
            symbols: UnitSymbols(
                watts: symbol("W"), milliampHours: symbol("mAh"), volts: symbol("V"), millivolts: symbol("mV"),
                milliamps: symbol("mA"), amps: symbol("A")))
    }
}
#endif
