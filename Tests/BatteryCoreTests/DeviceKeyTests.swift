import Foundation
import Testing

@testable import BatteryCore

@Suite struct DeviceKeyTests {
    @Test func acceptsHexAndDemo() throws {
        let key = try #require(DeviceKey(rawValue: "cfa3073fbe82243a2581b4d4ce99245e"))
        #expect(key.rawValue == "cfa3073fbe82243a2581b4d4ce99245e")
        #expect(DeviceKey("demo") == DeviceKey.demo)
        #expect(DeviceKey("k-801c") != nil)
    }

    @Test(arguments: ["", "/", "..", "a/b", "../x", "ABC", "abc def", "key.json", String(repeating: "a", count: 65)])
    func rejectsPathCharactersAndEmpty(value: String) {
        #expect(DeviceKey(rawValue: value) == nil)
    }

    @Test func sixtyFourCharactersIsTheLimit() {
        #expect(DeviceKey(rawValue: String(repeating: "a", count: 64)) != nil)
    }

    @Test func codableRoundTrip() throws {
        let key = try #require(DeviceKey("cfa3073fbe82243a2581b4d4ce99245e"))
        let data = try JSONEncoder().encode([key])
        #expect(String(decoding: data, as: UTF8.self) == #"["cfa3073fbe82243a2581b4d4ce99245e"]"#)
        #expect(try JSONDecoder().decode([DeviceKey].self, from: data) == [key])
        #expect(throws: DecodingError.self) {
            try JSONDecoder().decode([DeviceKey].self, from: Data(#"["../x"]"#.utf8))
        }
    }

    @Test func derivationMessageAndHex() throws {
        // SYNTHETIC UDID.
        let lower = DeviceKeyDerivation.message(forIdentifier: "00008150-001a2d3c4e5f601c")
        let upper = DeviceKeyDerivation.message(forIdentifier: "00008150-001A2D3C4E5F601C")
        #expect(lower == upper)
        #expect(String(decoding: upper, as: UTF8.self) == "BatteryPulse device v1\n00008150-001A2D3C4E5F601C")

        let bytes: [UInt8] = Array(0...31)
        let key = try #require(DeviceKeyDerivation.key(fromAuthenticationCode: bytes))
        #expect(key.rawValue == "000102030405060708090a0b0c0d0e0f")
        let high = try #require(DeviceKeyDerivation.key(fromAuthenticationCode: [UInt8](repeating: 0xAB, count: 16)))
        #expect(high.rawValue == String(repeating: "ab", count: 16))
        #expect(DeviceKeyDerivation.key(fromAuthenticationCode: bytes.prefix(15)) == nil)
    }
}

@Suite struct IDeviceModelTests {
    @Test(arguments: [
        ("iPhone18,2" as String?, nil as String?, 1000 as Int?),
        ("iPhone17,5", nil, 1000),
        ("iPhone15,4", nil, 1000),
        ("iPhone15,5", "iPhone", 1000),
        ("iPhone15,3", nil, 500),
        ("iPhone14,5", "iPhone", 500),
        ("iPad12,1", nil, 1000),
        (nil, "iPad", 1000),
        (nil, nil, nil),
        (nil, "iPhone", nil),
        ("Watch7,1", nil, nil),
        ("iPhone", nil, nil),
        ("iPhoneX,1", nil, nil),
        ("iPhone18,2,1", nil, nil),
    ])
    func ratedCycles(productType: String?, deviceClass: String?, expected: Int?) {
        #expect(IDeviceModel.ratedCycles(productType: productType, deviceClass: deviceClass) == expected)
    }

    @Test func symbolNames() {
        #expect(IDeviceModel.symbolName(deviceClass: "iPad") == "ipad")
        #expect(IDeviceModel.symbolName(deviceClass: "iPhone") == "iphone")
        #expect(IDeviceModel.symbolName(deviceClass: nil) == "iphone")
    }
}
