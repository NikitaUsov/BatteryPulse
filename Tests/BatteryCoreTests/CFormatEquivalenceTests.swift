import Foundation
import Testing

@testable import BatteryCore

/// BatteryCore prints integers without `String(format:)`, which Darwin's Foundation marks unsafe.
/// The replacements must print exactly what the C formats printed, because the reports, the raw
/// table and the history file names are frozen.
@Suite struct CFormatEquivalenceTests {
    @Test(arguments: [1, 0x4, 0x1A2B, 0xE800_002E, 0xFFFF_FFFF, 0x1_0000_0001, -1])
    func hexMatchesUppercaseX(_ value: Int) {
        #expect(BatteryReport.hex(value) == String(format: "0x%X", value))
    }

    @Test func bytesMatchTwoDigitLowercaseX() {
        let bytes: [UInt8] = [0, 1, 0x0F, 0x10, 0xAB, 0xFF]
        let expected = "<" + bytes.map { String(format: "%02x", $0) }.joined() + ">"
        #expect(PropertyValue.data(Data(bytes)).description == expected)
    }

    @Test(arguments: [(1, 1, 1), (987, 6, 5), (2027, 1, 15), (2026, 12, 31), (10_000, 10, 10)])
    func dayKeysMatchZeroPaddedD(_ year: Int, _ month: Int, _ day: Int) throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try #require(TimeZone(identifier: "UTC"))
        let date = try #require(calendar.date(from: DateComponents(year: year, month: month, day: day, hour: 12)))
        #expect(HistoryDay.key(for: date, calendar: calendar) == String(format: "%04d-%02d-%02d", year, month, day))
    }

    @Test(arguments: [0.0, 0.05, 0.15, 2.675, -3.25, 12.34, 99.95, 1e9])
    func fixedPointKeepsCRounding(_ value: Double) {
        for digits in 0...2 {
            #expect(BatteryReport.fixed(value, digits) == String(format: "%.\(digits)f", value))
        }
    }
}
