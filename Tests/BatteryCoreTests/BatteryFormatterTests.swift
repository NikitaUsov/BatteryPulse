import Foundation
import Testing

@testable import BatteryCore

@Suite struct BatteryFormatterTests {
    private let english = BatteryFormatter(locale: Locale(identifier: "en_US"))
    private let russian = BatteryFormatter(locale: Locale(identifier: "ru_RU")) { unit in
        switch unit {
        case .watts: "Вт"
        case .milliampHours: "мА·ч"
        case .volts: "В"
        case .milliamps: "мА"
        }
    }

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
        #expect(plain(russian.watts(-10.34, signed: true)) == "−10,3 Вт")
        #expect(plain(english.watts(32.66, signed: true)) == "+32.7 W")
        #expect(plain(english.watts(60)) == "60.0 W")
        #expect(plain(english.watts(-0.04, signed: true)) == "0.0 W", "no sign on values that round to zero")
    }

    @Test func capacityAndElectrical() {
        #expect(plain(english.milliampHours(5862)) == "5,862 mAh")
        #expect(plain(russian.milliampHours(5862)) == "5 862 мА·ч")
        #expect(plain(english.volts(millivolts: 12176)) == "12.18 V")
        #expect(plain(russian.volts(millivolts: 12176)) == "12,18 В")
        #expect(plain(english.milliamps(-612, signed: true)) == "−612 mA")
    }

    @Test func durations() {
        #expect(plain(english.duration(minutes: 342)) == "5 hr, 42 min")
        #expect(plain(russian.duration(minutes: 342)) == "5 ч 42 мин")
        #expect(plain(english.duration(minutes: 42)) == "42 min")
    }
}
