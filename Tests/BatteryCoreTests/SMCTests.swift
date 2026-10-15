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

    @Test func floatsInTheWrongOrderNeverTrap() {
        // Little-endian floats whose sum is off the pack voltage: every byte order is tried, and
        // the big-endian reading (about 1e23) must be rejected, not converted to Int.
        let float = SMCKeyInfo(size: 4, type: "flt ", attributes: 0x84)
        let capture = SMCBattery.capture(
            [Float(3812.4), 3810.1, 3811.7].enumerated().map { index, millivolts in
                SMCRawValue(
                    key: SMCBattery.floatCellVoltageKeys[index], info: float,
                    payload: withUnsafeBytes(of: millivolts.bitPattern.littleEndian, Array.init))
            })
        #expect(SMCBattery.cellVoltagesMV(in: capture, packVoltageMV: 11_134) == [])
        // A cell count that doesn't fit an Int is ignored too.
        let huge = SMCRawValue(
            key: "BNCB", info: SMCKeyInfo(size: 8, type: "ui64", attributes: 0x84),
            payload: Array(repeating: 0xFF, count: 8))
        #expect(
            SMCBattery.cellVoltagesMV(in: SMCBattery.capture([huge, Self.cell("BC1V", 4000)]), packVoltageMV: nil) == [
                4000
            ])
    }

    @Test func rawDataShowsCellsInThePlausibleOrder() throws {
        // Attribute bit 0x04 clear says big-endian, but the bytes are little-endian.
        let info = SMCKeyInfo(size: 2, type: "ui16", attributes: 0x80)
        let reading = BatteryReading(
            smartBattery: ["Voltage": .int(3823)], smc: SMCBattery.capture([Self.cell("BC1V", 3823, info: info)]),
            timestamp: Fixture.timestamp)
        let row = try #require(RawSection.sections(for: reading.rawCapture).last?.rows.first)
        #expect(row.decoded == .millivolts(3823))
        // No plausible order: the raw bytes, not a nonsense measurement.
        let garbage = SMCRawValue(key: "BC1V", info: Self.ui16, payload: [0xFF, 0xFF])
        let rows = RawSection.sections(for: [BatteryReading.CaptureKey.smc: .dictionary(SMCBattery.capture([garbage]))])
        #expect(rows.first?.rows.first?.decoded == nil)
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

    @Test func areaSensorsAreNotTheBatteryTemperature() {
        let float = SMCKeyInfo(size: 4, type: "flt ", attributes: 0x84)
        let sensor = SMCRawValue(
            key: "TB0T", info: float, payload: withUnsafeBytes(of: Float(31).bitPattern.littleEndian, Array.init))
        let reading = BatteryReading(
            smartBattery: ["Voltage": .int(12_000)], smc: SMCBattery.capture([sensor]), timestamp: Fixture.timestamp)
        #expect(reading.snapshot.temperatureCelsius == nil)
        // Raw Data still shows it, in °C.
        let row = RawSection.sections(for: reading.rawCapture).last?.rows.first
        #expect(row?.decoded == .celsius(31))
    }

    @Test func floatsFollowTheAttributeByteOrderToo() {
        let bytes = withUnsafeBytes(of: Float(25.5).bitPattern.bigEndian, Array.init)
        #expect(SMCValueDecoder.number(bytes, info: SMCKeyInfo(size: 4, type: "flt ", attributes: 0x80)) == 25.5)
        #expect(
            SMCValueDecoder.number(bytes.reversed(), info: SMCKeyInfo(size: 4, type: "flt ", attributes: 0x84)) == 25.5)
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

    /// MacBook Air M5 on macOS 27: the float cells are in volts, B0AT counts tenths of a kelvin,
    /// and the area sensors read an ulp or two below a round value.
    @Test func realM5Values() throws {
        let reading = try Fixture.m5OnBatterySMC.reading()
        let smc = try #require(reading.rawCapture[BatteryReading.CaptureKey.smc]?.dictionaryValue)
        let section = RawSection.sections(for: [BatteryReading.CaptureKey.smc: .dictionary(smc)]).first
        let rows = Dictionary(uniqueKeysWithValues: (section?.rows ?? []).map { ($0.path, $0) })
        #expect(rows.count == 13)
        #expect(rows["SBA1"]?.property == .int(3836))
        #expect(rows["SBA1"]?.decoded == .millivolts(3836))
        #expect(rows["SBA3"]?.property == .int(3833))
        #expect(rows["BC3V"]?.decoded == .millivolts(3833))
        #expect(rows["B0AT"]?.property == .int(3069))
        #expect(rows["B0AT"]?.decoded == .celsius(33.75))
        #expect(rows["TB0T"]?.property == .double(33.7))
        #expect(rows["TB2T"]?.decoded == .celsius(32.6))
        #expect(rows["B0AC"]?.decoded == .milliamps(-720))
        #expect(rows["B0AV"]?.decoded == .millivolts(11501))
        #expect(rows["BNCB"]?.property == .int(3))
        // The float cells alone give the integer cells' voltages.
        let floats = smc.filter { $0.key.hasPrefix("SBA") || $0.key == "BNCB" }
        #expect(SMCBattery.cellVoltagesMV(in: floats, packVoltageMV: 11_511) == [3836, 3836, 3833])
        let sba1 = try #require(SMCBattery.values(in: smc).first { $0.key == "SBA1" })
        #expect(sba1.number == 3.836)
    }

    @Test func gaugeTemperatureMustBePlausible() {
        func temperature(_ raw: Int) -> Double? {
            SMCBattery.temperatureCelsius(
                in: SMCBattery.capture([
                    SMCRawValue(key: "B0AT", info: Self.ui16, payload: [UInt8(raw & 0xFF), UInt8(raw >> 8)])
                ]))
        }
        #expect(temperature(3067) == 33.55)  // Wattly, M5 MacBook Pro
        #expect(temperature(2731) == -0.05)
        #expect(temperature(31) == nil, "°C, not tenths of a kelvin")
        #expect(temperature(3700) == nil, "96.85 °C")
        // Only when the IORegistry has none.
        let smc = SMCBattery.capture([SMCRawValue(key: "B0AT", info: Self.ui16, payload: [0xFB, 0x0B])])
        let fallback = BatteryReading(smartBattery: [:], smc: smc, timestamp: Fixture.timestamp).snapshot
        #expect(fallback.temperatureCelsius == 33.55)
        let registry = BatteryReading(smartBattery: ["Temperature": .int(3100)], smc: smc, timestamp: Fixture.timestamp)
        #expect(registry.snapshot.temperatureCelsius == 31)
    }

    @Test func floatCellsInVoltsOrMillivolts() {
        let float = SMCKeyInfo(size: 4, type: "flt ", attributes: 0x84)
        func cells(_ values: [Float]) -> PropertyDictionary {
            SMCBattery.capture(
                values.enumerated().map { index, value in
                    SMCRawValue(
                        key: SMCBattery.floatCellVoltageKeys[index], info: float,
                        payload: withUnsafeBytes(of: value.bitPattern.littleEndian, Array.init))
                })
        }
        #expect(SMCBattery.cellVoltagesMV(in: cells([3.9015, 3.899]), packVoltageMV: 7_800) == [3902, 3899])
        #expect(SMCBattery.cellVoltagesMV(in: cells([3901.5, 3899]), packVoltageMV: 7_800) == [3902, 3899])
        #expect(SMCBattery.cellVoltagesMV(in: cells([0.0039, 0.0039]), packVoltageMV: nil) == [])
        // Integer keys are never taken for volts.
        let volts = SMCRawValue(key: "BC1V", info: Self.ui16, payload: [4, 0])
        #expect(SMCBattery.cellVoltagesMV(in: SMCBattery.capture([volts]), packVoltageMV: nil) == [])
    }

    @Test func appReadsOnlyReadOnlyBatteryKeys() {
        #expect(Set(SMCBattery.keys).count == SMCBattery.keys.count)
        #expect(SMCBattery.keys.allSatisfy { ["B", "T", "S"].contains($0.description.first.map(String.init)) })
    }
}
