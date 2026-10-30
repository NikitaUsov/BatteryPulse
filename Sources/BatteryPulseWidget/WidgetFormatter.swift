#if os(macOS)
import BatteryCore
import Foundation

extension BatteryFormatter {
    /// The widget's formatter, built once per extension process: the user's region, which it
    /// follows when it changes in System Settings, and the catalog's unit symbols, the six keys of
    /// the app's `BatteryFormatter.app` (`WidgetSourceTests` keeps the two lists equal), looked up
    /// in the widget bundle's own tables.
    static let widget = BatteryFormatter(
        locale: .autoupdatingCurrent,
        symbols: UnitSymbols(
            watts: String(localized: "W", comment: "Unit symbol: watts"),
            milliampHours: String(localized: "mAh", comment: "Unit symbol: milliampere-hours"),
            volts: String(localized: "V", comment: "Unit symbol: volts"),
            millivolts: String(localized: "mV", comment: "Unit symbol: millivolts"),
            milliamps: String(localized: "mA", comment: "Unit symbol: milliamperes"),
            amps: String(localized: "A", comment: "Unit symbol: amperes")))
}
#endif
