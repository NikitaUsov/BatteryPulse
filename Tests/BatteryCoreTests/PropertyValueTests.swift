import Foundation
import Testing

@testable import BatteryCore

@Suite struct PropertyValueTests {
    private func parse(_ body: String) throws -> PropertyDictionary {
        let xml = """
            <?xml version="1.0" encoding="UTF-8"?>
            <plist version="1.0"><dict>\(body)</dict></plist>
            """
        let root = try PropertyListSerialization.propertyList(from: Data(xml.utf8), format: nil)
        return try #require(PropertyValue.dictionary(fromAny: root))
    }

    @Test func unsignedRegistryValuesBecomeSigned() throws {
        // `ioreg -a` prints a discharge current of -1024 mA as 2^64 - 1024.
        let dict = try parse("<key>Amperage</key><integer>18446744073709550592</integer>")
        #expect(dict["Amperage"] == .int(-1024))
        #expect(dict["Amperage"]?.intValue == -1024)
    }

    @Test func booleansAndIntegersStayDistinct() throws {
        let dict = try parse(
            """
            <key>Flag</key><true/>
            <key>One</key><integer>1</integer>
            <key>Real</key><real>1.5</real>
            """)
        #expect(dict["Flag"] == .bool(true))
        #expect(dict["One"] == .int(1))
        #expect(dict["Real"] == .double(1.5))
        // Some IORegistry flags are 0/1 integers; they still read as booleans.
        #expect(dict["One"]?.boolValue == true)
        #expect(dict["Real"]?.intValue == 2)
    }

    @Test func swiftNativeValues() {
        #expect(PropertyValue(any: 5) == .int(5))
        #expect(PropertyValue(any: Int64(-7)) == .int(-7))
        #expect(PropertyValue(any: UInt64.max) == .int(-1))
        #expect(PropertyValue(any: true) == .bool(true))
        #expect(PropertyValue(any: 0) == .int(0))
        #expect(PropertyValue(any: 2.5) == .double(2.5))
        #expect(PropertyValue(any: Date()) == nil)
    }

    @Test func nestedContainers() throws {
        let dict = try parse(
            """
            <key>BatteryData</key><dict>
                <key>CellVoltage</key><array><integer>4100</integer><integer>4101</integer></array>
                <key>Name</key><string>bq</string>
                <key>Blob</key><data>AAEC</data>
            </dict>
            """)
        let battery = try #require(dict["BatteryData"]?.dictionaryValue)
        #expect(battery["CellVoltage"]?.arrayValue?.compactMap(\.intValue) == [4100, 4101])
        #expect(battery["Name"]?.stringValue == "bq")
        #expect(battery["Blob"] == .data(Data([0, 1, 2])))
        #expect(battery["Blob"]?.description == "<000102>")
    }

    @Test func roundTripsThroughPropertyListSerialization() throws {
        let original: PropertyDictionary = [
            "Amperage": .int(-1024),
            "IsCharging": .bool(false),
            "Temperature": .double(31.5),
            "Cells": .array([.int(4100), .int(4101)]),
            "Adapter": .dictionary(["Name": .string("96W"), "Raw": .data(Data([0xFF]))]),
        ]
        let data = try PropertyListSerialization.data(
            fromPropertyList: PropertyValue.dictionary(original).foundationValue,
            format: .xml,
            options: 0
        )
        let root = try PropertyListSerialization.propertyList(from: data, format: nil)
        #expect(PropertyValue.dictionary(fromAny: root) == original)
    }
}
