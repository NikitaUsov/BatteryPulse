import Foundation
import Testing

@testable import BatteryCore

@Suite struct BatteryFormatterTests {
    private let english = BatteryFormatter(locale: Locale(identifier: "en_US"))
    /// Russian number formatting. The unit symbols are stand-ins: the app's real ones live in the
    /// String Catalog, the only place in the repository with Russian text.
    private let russian = BatteryFormatter(
        locale: Locale(identifier: "ru_RU"),
        symbols: .init(
            watts: "W-ru", milliampHours: "mAh-ru", volts: "V-ru", millivolts: "mV-ru", milliamps: "mA-ru", amps: "A-ru"
        ))

    /// Locales differ in which space they use; compare with all of them normalized.
    private func plain(_ text: String) -> String {
        text.replacingOccurrences(of: "\u{00A0}", with: " ").replacingOccurrences(of: "\u{202F}", with: " ")
    }

    @Test func percent() {
        #expect(plain(english.percent(91)) == "91%")
        #expect(plain(russian.percent(91)) == "91 %")
        #expect(plain(english.percent(104.27, fractionDigits: 1)) == "104.3%")
        #expect(plain(russian.percent(104.27, fractionDigits: 1)) == "104,3 %")
    }

    @Test func watts() {
        #expect(plain(english.watts(-10.34, signed: true)) == "−10.3 W")
        #expect(plain(russian.watts(-10.34, signed: true)) == "−10,3 W-ru")
        #expect(plain(english.watts(32.66, signed: true)) == "+32.7 W")
        #expect(plain(english.watts(60)) == "60.0 W")
        #expect(plain(english.watts(-0.04, signed: true)) == "0.0 W", "no sign on values that round to zero")
    }

    @Test func capacityAndElectrical() {
        #expect(plain(english.milliampHours(5862)) == "5,862 mAh")
        #expect(plain(russian.milliampHours(5862)) == "5 862 mAh-ru")
        #expect(plain(english.volts(millivolts: 12176)) == "12.18 V")
        #expect(plain(russian.volts(millivolts: 12176)) == "12,18 V-ru")
        #expect(plain(english.milliamps(-612, signed: true)) == "−612 mA")
        #expect(plain(english.amps(milliamps: 2990)) == "2.99 A")
        #expect(plain(russian.amps(milliamps: 2990)) == "2,99 A-ru")
        #expect(plain(english.volts(millivolts: 20000, fractionDigits: 0)) == "20 V")
        #expect(plain(english.watts(60, fractionDigits: 0)) == "60 W")
        #expect(plain(english.celsius(31.24)) == "31.2 °C")
        #expect(plain(russian.celsius(31.24)) == "31,2 °C")
        #expect(plain(english.celsius(33.69, fractionDigits: 0)) == "34 °C")
    }

    /// A plain value, so views can compare it: equal for the same locale and symbols only.
    @Test func equality() {
        #expect(BatteryFormatter(locale: Locale(identifier: "en_US")) == english)
        #expect(BatteryFormatter(locale: Locale(identifier: "ru_RU")) != english)
        #expect(BatteryFormatter(locale: Locale(identifier: "ru_RU")) != russian)
        #expect(BatteryFormatter().symbols == .english)
        #expect(BatteryFormatter(locale: .autoupdatingCurrent) == BatteryFormatter(locale: .autoupdatingCurrent))
    }

    @Test func durations() {
        #expect(plain(english.duration(minutes: 342)) == "5 hr, 42 min")
        // Foundation's Russian abbreviations for hours and minutes.
        #expect(plain(russian.duration(minutes: 342)) == "5 \u{0447} 42 \u{043C}\u{0438}\u{043D}")
        #expect(plain(english.duration(minutes: 42)) == "42 min")
        #expect(plain(english.duration(seconds: 150)) == "2 min, 30 sec")
        #expect(plain(english.duration(seconds: 30)) == "30 sec")
    }
}
