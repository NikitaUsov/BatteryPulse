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
        #expect(english.percent(91) == "91%")
        #expect(russian.percent(91) == "91%")
        #expect(english.percent(104.27, fractionDigits: 1) == "104.3%")
        #expect(russian.percent(104.27, fractionDigits: 1) == "104,3%")
        #expect(russian.percent(99.5, fractionDigits: 1) == "99,5%")
        #expect(russian.percent(80) == "80%")
    }

    /// No space of any kind between the number and the sign, whichever one the locale writes
    /// (Russian, German and French write one, Ukrainian and English none), with the locale's own
    /// digits and separators: the number as ``BatteryFormatter/number(_:fractionDigits:signed:)``
    /// writes it, then the sign.
    @Test(arguments: ["ru_RU", "uk_UA", "de_DE", "fr_FR", "en_US"])
    func percentHasNoSpaceBeforeTheSign(locale identifier: String) throws {
        let formatter = BatteryFormatter(locale: Locale(identifier: identifier))
        for (value, digits) in [(80.0, 0), (100, 0), (5, 0), (99.5, 1), (104.27, 1), (0.25, 2), (12_345.6, 1)] {
            let text = formatter.percent(value, fractionDigits: digits)
            #expect(text == formatter.number(value, fractionDigits: digits) + "%", "\(identifier): \(text)")
            let scalars = Array(text.unicodeScalars)
            let sign = try #require(scalars.firstIndex(of: "%"), "\(identifier): \(text) has no %")
            let before = try #require(sign > 0 ? scalars[sign - 1] : nil, "\(identifier): \(text) starts with %")
            #expect(!before.properties.isWhitespace, "\(identifier): \(text) has a space before %")
            #expect(before.properties.numericType != nil, "\(identifier): \(text) has no digit right before %")
        }
    }

    /// A locale that writes the sign first loses its space too ("% 80" in Basque), and only the
    /// space between two digits stays.
    @Test func closingUpKeepsOnlyDigitGroupSpaces() {
        #expect(BatteryFormatter.closingUp("% 80") == "%80")
        #expect(BatteryFormatter.closingUp("12\u{00A0}345,6\u{00A0}%") == "12\u{00A0}345,6%")
        #expect(BatteryFormatter.closingUp("12\u{202F}345,6\u{202F}%") == "12\u{202F}345,6%")
        #expect(BatteryFormatter.closingUp("99,5\u{2009}%") == "99,5%")
        #expect(BatteryFormatter.closingUp("80%") == "80%")
    }

    /// Percentages are formatted in one place, ``BatteryFormatter/percent(_:fractionDigits:)``,
    /// so none of the app's or the widget's goes back to the locale's space before the sign. The
    /// text reports (``BatteryReport``, `bpulse`'s and Copy Report's English) write their own
    /// fixed "70 %" in string literals, which the scanner blanks.
    @Test func onlyTheFormatterFormatsPercentages() throws {
        let percentStyles = [
            #/\.formatted\(\s*\.percent\b/#,
            #/format:\s*\.percent\b/#,
            #/\.percent\s*\.\s*(?:precision|scale|rounded|grouping|sign|locale|notation|decimalSeparator)\b/#,
            #/\.Percent\b/#,
            #/numberStyle\s*=\s*\.percent\b/#,
            #/\.percentSymbol\b/#,
        ]
        var offenders: [String] = []
        for file in try SourceScanner.allFiles.get() where file.path != "BatteryCore/BatteryFormatter.swift" {
            if percentStyles.contains(where: { file.code.contains($0) }) { offenders.append(file.path) }
        }
        #expect(offenders.isEmpty, "Format percentages through BatteryFormatter.percent: \(offenders)")
        let formatter = try SourceScanner.allFiles.get().first { $0.path == "BatteryCore/BatteryFormatter.swift" }
        #expect(formatter.map { file in percentStyles.contains { file.code.contains($0) } } == true)
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

    /// USB power offers: whole volts without decimals, otherwise only the decimals they need.
    @Test(arguments: [(20000, "20 V", "20 V-ru"), (3300, "3.3 V", "3,3 V-ru"), (3250, "3.25 V", "3,25 V-ru")])
    func compactVolts(millivolts: Int, english expected: String, russian expectedRussian: String) {
        #expect(plain(english.compactVolts(millivolts: millivolts)) == expected)
        #expect(plain(russian.compactVolts(millivolts: millivolts)) == expectedRussian)
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
