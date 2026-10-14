import Foundation
import Testing

@testable import BatteryCore

/// Byte captures come from other projects' reads on real Macs: iSMC's raw dumps, Aeolus (M4 Max,
/// macOS 26) and Wattly (M5 MacBook Pro, macOS 27).
struct SMCTests {
    static let ui16 = SMCKeyInfo(size: 2, type: "ui16", attributes: 0x84)

    static func cell(_ key: SMCFourCC, _ millivolts: Int, info: SMCKeyInfo = ui16) -> SMCRawValue {
        SMCRawValue(key: key, info: info, payload: [UInt8(millivolts & 0xFF), UInt8(millivolts >> 8)])
    }

    @Test func fourCharacterCodesAreBigEndianIntegers() {
        #expect(SMCFourCC(validating: "TB0T")?.rawValue == 0x5442_3054)
        #expect(("flt " as SMCFourCC).rawValue == 0x666C_7420)
        #expect(SMCFourCC(rawValue: 0x234B_4559).description == "#KEY")
        #expect(SMCFourCC(validating: "TB0") == nil)
        #expect(SMCFourCC(validating: "TB0Té") == nil)
    }

    @Test func requestPutsFieldsAtTheCOffsets() {
        let block = SMCParamBlock.request(.readKey, key: "B0AV", dataSize: 2, index: 0x0102_0304)
        #expect(block.count == 80)
        #expect(Array(block[0..<4]) == [0x56, 0x41, 0x30, 0x42])  // 'B0AV' as a little-endian UInt32
        #expect(Array(block[28..<32]) == [2, 0, 0, 0])
        #expect(block[42] == 5)
        #expect(Array(block[44..<48]) == [4, 3, 2, 1])
        #expect(
            block.enumerated().allSatisfy {
                [0, 1, 2, 3, 28, 42, 44, 45, 46, 47].contains($0.offset) || $0.element == 0
            })
    }

    @Test func replyDecodesKeyInfoAndPayload() throws {
        var block = [UInt8](repeating: 0, count: 80)
        block.replaceSubrange(0..<4, with: [0x54, 0x30, 0x42, 0x54])  // 'TB0T'
        block.replaceSubrange(28..<32, with: [4, 0, 0, 0])
        block.replaceSubrange(32..<36, with: [0x20, 0x74, 0x6C, 0x66])  // 'flt '
        block[36] = 0x84
        block.replaceSubrange(48..<52, with: [0x60, 0x66, 0xCE, 0x41])
        let reply = try #require(SMCParamBlock.reply(from: block))
        #expect(reply.key == "TB0T")
        #expect(reply.result == 0)
        #expect(reply.info == SMCKeyInfo(size: 4, type: "flt ", attributes: 0x84))
        let celsius = try #require(SMCValueDecoder.number(reply.payload, info: reply.info))
        #expect(abs(celsius - 25.8) < 0.01)  // iSMC, M5 Pro: TB0T bytes 60 66 ce 41
        #expect(SMCParamBlock.reply(from: Array(block.prefix(79))) == nil)
    }

    @Test func integersFollowTheAttributeByteOrder() {
        // Aeolus, M4 Max: #KEY 00 00 0d 39 is 3385 keys (attributes 0x80, big-endian).
        #expect(
            SMCValueDecoder.number([0, 0, 0x0D, 0x39], info: SMCKeyInfo(size: 4, type: "ui32", attributes: 0x80))
                == 3385)
        // B0AV fd 2e is 12029 mV (attributes 0x84, little-endian).
        #expect(SMCValueDecoder.number([0xFD, 0x2E], info: Self.ui16) == 12_029)
    }

    @Test func signedAndFixedPointTypes() {
        #expect(
            SMCValueDecoder.number([0x0E, 0xF8], info: SMCKeyInfo(size: 2, type: "si16", attributes: 0x84)) == -2034)
        #expect(SMCValueDecoder.number([0x1E, 0x80], info: SMCKeyInfo(size: 2, type: "sp78", attributes: 0)) == 30.5)
        #expect(SMCValueDecoder.number([0x00, 0x64], info: SMCKeyInfo(size: 2, type: "fpe2", attributes: 0)) == 25)
        #expect(
            SMCValueDecoder.number(
                [0, 0, 0x19, 0, 0, 0, 0, 0], info: SMCKeyInfo(size: 8, type: "ioft", attributes: 0x84))
                == 25)
        #expect(SMCValueDecoder.number([1], info: SMCKeyInfo(size: 1, type: "flag", attributes: 0x80)) == 1)
        // Unknown types and sizes that don't match the type decode to nothing.
        #expect(SMCValueDecoder.number([1, 2], info: SMCKeyInfo(size: 2, type: "ch8*", attributes: 0x80)) == nil)
        #expect(SMCValueDecoder.number([1, 2], info: SMCKeyInfo(size: 2, type: "flt ", attributes: 0x80)) == nil)
        #expect(SMCValueDecoder.number([1], info: SMCKeyInfo(size: 2, type: "ui16", attributes: 0x84)) == nil)
    }

    @Test func cellsMustBePlausibleAndAddUpToThePack() {
        // Aeolus, M4 Max: 4009 + 4011 + 4009 = B0AV 12029 mV.
        let cells = [Self.cell("BC1V", 4009), Self.cell("BC2V", 4011), Self.cell("BC3V", 4009)]
        let capture = SMCBattery.capture(cells)
        #expect(SMCBattery.cellVoltagesMV(in: capture, packVoltageMV: 12_029) == [4009, 4011, 4009])
        #expect(SMCBattery.cellVoltagesMV(in: capture, packVoltageMV: nil) == [4009, 4011, 4009])
        #expect(SMCBattery.cellVoltagesMV(in: capture, packVoltageMV: 9_000) == [])
    }

    @Test func implausibleByteOrderFallsBackToTheOther() {
        // Attribute bit 0x04 clear says big-endian, which gives nonsense; little-endian fits.
        let info = SMCKeyInfo(size: 2, type: "ui16", attributes: 0x80)
        let capture = SMCBattery.capture([
            Self.cell("BC1V", 3823, info: info), Self.cell("BC2V", 3817, info: info),
            Self.cell("BC3V", 3837, info: info),
        ])
        #expect(SMCBattery.cellVoltagesMV(in: capture, packVoltageMV: 11_477) == [3823, 3817, 3837])
    }

    @Test func cellCountLimitsTheCells() {
        let count = SMCRawValue(key: "BNCB", info: SMCKeyInfo(size: 1, type: "ui8 ", attributes: 0x80), payload: [2])
        let capture = SMCBattery.capture([
            count, Self.cell("BC1V", 4000), Self.cell("BC2V", 4002), Self.cell("BC3V", 4001),
        ])
        #expect(SMCBattery.cellVoltagesMV(in: capture, packVoltageMV: 8_002) == [4000, 4002])
    }

    @Test func floatCellsAreTheSecondChoice() {
        let float = SMCKeyInfo(size: 4, type: "flt ", attributes: 0x84)
        let capture = SMCBattery.capture(
            [Float(3901.5), 3899].enumerated().map { index, millivolts in
                SMCRawValue(
                    key: SMCBattery.floatCellVoltageKeys[index], info: float,
                    payload: withUnsafeBytes(of: millivolts.bitPattern.littleEndian, Array.init))
            })
        #expect(SMCBattery.cellVoltagesMV(in: capture, packVoltageMV: nil) == [3902, 3899])
    }

    @Test func temperatureIsTheMeanOfPlausibleSensors() throws {
        let float = SMCKeyInfo(size: 4, type: "flt ", attributes: 0x84)
        func sensor(_ key: SMCFourCC, _ celsius: Float) -> SMCRawValue {
            SMCRawValue(
                key: key, info: float, payload: withUnsafeBytes(of: celsius.bitPattern.littleEndian, Array.init))
        }
        let capture = SMCBattery.capture([sensor("TB0T", 31), sensor("TB1T", 29), sensor("TB2T", -128)])
        let celsius = try #require(SMCBattery.temperatureCelsius(in: capture))
        #expect(abs(celsius - 30) < 0.001)
        #expect(SMCBattery.temperatureCelsius(in: SMCBattery.capture([sensor("TB0T", 200)])) == nil)
        #expect(SMCBattery.temperatureCelsius(in: [:]) == nil)
    }

    @Test func captureEntriesRoundTripThroughAPropertyList() throws {
        // Wattly, M5 MacBook Pro on macOS 27: B0AT reads 3067.
        let value = SMCRawValue(key: "B0AT", info: Self.ui16, payload: [0xFB, 0x0B])
        let capture = SMCBattery.capture([value])
        let data = try PropertyListSerialization.data(
            fromPropertyList: PropertyValue.dictionary(capture).foundationValue, format: .xml, options: 0)
        let decoded = try #require(
            PropertyValue.dictionary(fromAny: try PropertyListSerialization.propertyList(from: data, format: nil)))
        #expect(SMCBattery.values(in: decoded) == [value])
        #expect(SMCBattery.values(in: decoded).first?.number == 3067)
        // Malformed entries are skipped.
        #expect(SMCBattery.values(in: ["B0AT": .int(3)]) == [])
        #expect(SMCBattery.values(in: ["TOOLONG": value.captureValue]) == [])
    }

    @Test func readingKeepsTheSMCValuesInItsCapture() {
        let smc = SMCBattery.capture([Self.cell("BC1V", 4009)])
        let reading = BatteryReading(smartBattery: ["Voltage": .int(4009)], smc: smc, timestamp: Fixture.timestamp)
        #expect(reading.rawCapture[BatteryReading.CaptureKey.smc] == .dictionary(smc))
        #expect(BatteryReading(rawCapture: reading.rawCapture, timestamp: Fixture.timestamp) == reading)
        #expect(reading.snapshot.cellVoltagesMV == [4009])
        // Without SMC values the capture keeps its old shape.
        #expect(BatteryReading(smartBattery: [:], timestamp: Fixture.timestamp).rawCapture.count == 3)
    }

    @Test func appReadsOnlyReadOnlyBatteryKeys() {
        #expect(Set(SMCBattery.keys).count == SMCBattery.keys.count)
        #expect(SMCBattery.keys.allSatisfy { ["B", "T", "S"].contains($0.description.first.map(String.init)) })
    }
}
