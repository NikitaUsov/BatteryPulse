import Foundation

// The platform-independent half of the read-only SMC client: the wire format, value decoding and
// the battery plausibility checks. The IOKit calls live in BatteryKit; everything here is tested
// on Linux against byte captures.

/// A four-character SMC key or type code, held the way the SMC wants it: an integer whose most
/// significant byte is the first character (`TB0T` is 0x5442_3054). On a little-endian host the
/// bytes in memory are reversed, so the ASCII bytes are never copied into the key field.
public struct SMCFourCC: Hashable, Sendable, Comparable, CustomStringConvertible {
    public let rawValue: UInt32

    public init(rawValue: UInt32) { self.rawValue = rawValue }

    public init?(validating text: String) {
        let bytes = Array(text.utf8)
        guard bytes.count == 4, bytes.allSatisfy({ (0x20...0x7E).contains($0) }) else { return nil }
        rawValue = bytes.reduce(0) { $0 << 8 | UInt32($1) }
    }

    public var description: String {
        String(decoding: [24, 16, 8, 0].map { UInt8(truncatingIfNeeded: rawValue >> $0) }, as: UTF8.self)
    }

    public static func < (lhs: SMCFourCC, rhs: SMCFourCC) -> Bool { lhs.rawValue < rhs.rawValue }
}

extension SMCFourCC: ExpressibleByStringLiteral {
    public init(stringLiteral value: String) {
        guard let code = SMCFourCC(validating: value) else {
            preconditionFailure("Not a four-character SMC code: \(value)")
        }
        self = code
    }
}

/// `SMCParamStruct` as raw bytes at fixed offsets, so Swift's struct layout never matters (a
/// plain Swift mirror of the C struct is 76 bytes, which the driver rejects). Field order and
/// types follow Apple's definition in PowerManagement (`pmconfigd/PrivateLib.c`, "defined by
/// AppleSMC.kext") with natural C alignment:
///
///     offset size field
///          0    4 key                     UInt32 four-character code
///          4    6 vers                    {major, minor, build, reserved: UInt8; release: UInt16}
///         12   16 pLimitData              {version, length: UInt16; cpu, gpu, mem: UInt32}
///         28    4 keyInfo.dataSize        UInt32
///         32    4 keyInfo.dataType        UInt32 four-character code
///         36    1 keyInfo.dataAttributes  UInt8
///         40    1 result                  UInt8, see SMCResult
///         41    1 status                  UInt8
///         42    1 data8                   UInt8, the command
///         44    4 data32                  UInt32, the index for getKeyFromIndex
///         48   32 bytes                   payload
///         80      total
///
/// Integer fields are host-endian; every Mac that runs macOS 27 is little-endian.
public enum SMCParamBlock {
    public static let size = 80
    public static let payloadCapacity = 32

    enum Offset {
        static let key = 0
        static let dataSize = 28
        static let dataType = 32
        static let attributes = 36
        static let result = 40
        static let data8 = 42
        static let data32 = 44
        static let bytes = 48
    }

    /// The read-only commands sent in `data8`. 6 (write a key) is deliberately absent.
    public enum Command: UInt8, Sendable {
        case readKey = 5
        case getKeyFromIndex = 8
        case getKeyInfo = 9
    }

    public static func request(
        _ command: Command, key: SMCFourCC = SMCFourCC(rawValue: 0), dataSize: UInt32 = 0, index: UInt32 = 0
    ) -> [UInt8] {
        var block = [UInt8](repeating: 0, count: size)
        store(key.rawValue, at: Offset.key, in: &block)
        store(dataSize, at: Offset.dataSize, in: &block)
        block[Offset.data8] = command.rawValue
        store(index, at: Offset.data32, in: &block)
        return block
    }

    public struct Reply: Sendable, Equatable {
        public var key: SMCFourCC
        public var result: UInt8
        /// Meaningful only in a getKeyInfo reply: a readKey reply leaves the size at 0 on Apple
        /// silicon, so the payload is sized from the earlier getKeyInfo.
        public var info: SMCKeyInfo
        public var payload: [UInt8]
    }

    public static func reply(from block: [UInt8]) -> Reply? {
        guard block.count == size else { return nil }
        return Reply(
            key: SMCFourCC(rawValue: load(Offset.key, from: block)),
            result: block[Offset.result],
            info: SMCKeyInfo(
                size: load(Offset.dataSize, from: block),
                type: SMCFourCC(rawValue: load(Offset.dataType, from: block)),
                attributes: block[Offset.attributes]
            ),
            payload: Array(block[Offset.bytes..<Offset.bytes + payloadCapacity])
        )
    }

    private static func store(_ value: UInt32, at offset: Int, in block: inout [UInt8]) {
        for index in 0..<4 { block[offset + index] = UInt8(truncatingIfNeeded: value >> (8 * index)) }
    }

    private static func load(_ offset: Int, from block: [UInt8]) -> UInt32 {
        (0..<4).reduce(0) { $0 | UInt32(block[offset + $1]) << (8 * $1) }
    }
}

/// The `result` byte: success, error and key-not-found from Apple's PowerManagement source, the
/// rest as the SMC protocol is commonly documented.
public enum SMCResult: UInt8, Sendable {
    case success = 0x00
    case error = 0x01
    case commCollision = 0x80
    case spuriousData = 0x81
    case badCommand = 0x82
    case badParameter = 0x83
    case keyNotFound = 0x84
    case notReadable = 0x85
    case notWritable = 0x86
    case keySizeMismatch = 0x87
    case framingError = 0x88
    case badArgument = 0x89
    case timeout = 0xB7
    case keyIndexRange = 0xB8
}

public struct SMCKeyInfo: Sendable, Equatable {
    public var size: UInt32
    public var type: SMCFourCC
    public var attributes: UInt8

    public init(size: UInt32, type: SMCFourCC, attributes: UInt8) {
        self.size = size
        self.type = type
        self.attributes = attributes
    }

    /// Attribute bit 0x80.
    public var isReadable: Bool { attributes & 0x80 != 0 }

    /// On Apple silicon, values with attribute bit 0x04 set are little-endian and the rest
    /// big-endian (`#KEY`, and one byte-reversed float in Linux's key list). Seen on one M4 Max, so
    /// decoded values are still checked for plausibility.
    public var byteOrder: SMCByteOrder { attributes & 0x04 != 0 ? .little : .big }
}

public enum SMCByteOrder: Sendable {
    case little, big
}

public enum SMCValueDecoder {
    /// Decodes a numeric value. `order` overrides the key's ``SMCKeyInfo/byteOrder`` for
    /// integers, `flt ` and `ioft`; `sp78` and `fpe2` are big-endian by definition.
    public static func number(_ payload: [UInt8], info: SMCKeyInfo, order: SMCByteOrder? = nil) -> Double? {
        let count = Int(info.size)
        guard count > 0, count <= payload.count else { return nil }
        let bytes = Array(payload.prefix(count))
        let order = order ?? info.byteOrder
        switch info.type.description {
        case "flt ":
            guard count == 4 else { return nil }
            let value = Float(bitPattern: UInt32(truncatingIfNeeded: unsigned(bytes, order)))
            // A subnormal value is never a real reading: it is what a sentinel such as NaN or
            // 100.0 becomes in the wrong byte order. Through the float's shortest decimal form:
            // 3.836 rather than 3.8359999656677246.
            guard value.isFinite, !value.isSubnormal else { return nil }
            return Double(value.description) ?? Double(value)
        case "ioft":
            guard count == 8 else { return nil }
            return Double(Int64(bitPattern: unsigned(bytes, order))) / 65_536
        case "ui8 ", "ui16", "ui32", "ui64":
            guard count <= 8 else { return nil }
            return Double(unsigned(bytes, order))
        case "si8 ", "si16", "si32", "si64":
            guard count <= 8 else { return nil }
            return Double(signed(bytes, order))
        case "flag":
            return bytes[0] == 0 ? 0 : 1
        case "sp78":
            guard count == 2 else { return nil }
            return Double(signed(bytes, .big)) / 256
        case "fpe2":
            guard count == 2 else { return nil }
            return Double(unsigned(bytes, .big)) / 4
        default:
            return nil
        }
    }

    static func unsigned(_ bytes: [UInt8], _ order: SMCByteOrder) -> UInt64 {
        let ordered = order == .big ? bytes : bytes.reversed()
        return ordered.reduce(0) { $0 << 8 | UInt64($1) }
    }

    static func signed(_ bytes: [UInt8], _ order: SMCByteOrder) -> Int64 {
        let shift = UInt64(64 - 8 * bytes.count)
        return Int64(bitPattern: unsigned(bytes, order) << shift) >> shift
    }
}

/// One key's metadata and payload as read from the SMC.
public struct SMCRawValue: Sendable, Equatable {
    public var key: SMCFourCC
    public var info: SMCKeyInfo
    public var payload: [UInt8]

    public init(key: SMCFourCC, info: SMCKeyInfo, payload: [UInt8]) {
        self.key = key
        self.info = info
        self.payload = payload
    }

    /// The value as a number, in the key's own unit.
    public var number: Double? { SMCValueDecoder.number(payload, info: info) }

    enum CaptureField {
        static let type = "DataType"
        static let size = "DataSize"
        static let attributes = "Attributes"
        static let bytes = "Bytes"
    }

    /// The entry in the `AppleSMC` dictionary of a raw capture.
    public var captureValue: PropertyValue {
        .dictionary([
            CaptureField.type: .string(info.type.description),
            CaptureField.size: .int(Int64(info.size)),
            CaptureField.attributes: .int(Int64(info.attributes)),
            CaptureField.bytes: .data(Data(payload)),
        ])
    }

    public init?(key: String, captureValue: PropertyValue) {
        guard let code = SMCFourCC(validating: key), let d = captureValue.dictionaryValue,
            let type = d[CaptureField.type]?.stringValue.flatMap({ SMCFourCC(validating: $0) }),
            let size = d[CaptureField.size]?.intValue, (1...SMCParamBlock.payloadCapacity).contains(size),
            case .data(let bytes)? = d[CaptureField.bytes], bytes.count >= size
        else { return nil }
        let attributes = d[CaptureField.attributes]?.intValue ?? 0
        self.init(
            key: code,
            info: SMCKeyInfo(size: UInt32(size), type: type, attributes: UInt8(truncatingIfNeeded: attributes)),
            payload: Array(bytes.prefix(size)))
    }
}

/// The battery keys BatteryPulse reads and how it interprets them. Each value has to be
/// physically plausible: when the attribute-derived byte order gives nonsense the other order is
/// tried, and if neither fits the value is dropped rather than shown.
public enum SMCBattery {
    public static let plausibleCellVoltage = 2_500...4_700

    /// Cells in series (`ui8`; `si8 ` on a MacBook Air M5).
    public static let cellCountKey: SMCFourCC = "BNCB"
    public static let cellVoltageKeys: [SMCFourCC] = ["BC1V", "BC2V", "BC3V", "BC4V"]
    /// Cell voltages as floats (`flt `). A MacBook Air M5 on macOS 27 reports them in volts
    /// (`SBA1` 3.836 with `BC1V` at 3836 mV); millivolt values are accepted too.
    public static let floatCellVoltageKeys: [SMCFourCC] = ["SBA1", "SBA2", "SBA3", "SBA4"]
    /// Battery-area temperature sensors (`flt `, °C). Not the battery's temperature: Linux labels
    /// `TB0T` "Battery Hotspot", they read up to 3 °C off the gauge on an M4 Max, and were reported
    /// clearly wrong on a MacBook Neo under macOS 27 (on a MacBook Air M5 `TB0T` and `TB1T` matched
    /// the pack and `TB2T` read 1.1 °C low).
    /// Shown in Raw Data only.
    public static let temperatureKeys: [SMCFourCC] = ["TB0T", "TB1T", "TB2T", "TB3T"]
    /// The gauge's own temperature, in tenths of a kelvin like the Smart Battery `Temperature()`
    /// command: 3069 on a MacBook Air M5 is 33.75 °C, with the pack reporting 33.69 °C.
    public static let gaugeTemperatureKey: SMCFourCC = "B0AT"
    static let plausibleTemperature: ClosedRange<Double> = -20...85

    /// Every key the app reads: read-only, battery-related and safe to read repeatedly. The pack
    /// voltage (`B0AV`) and current (`B0AC`) are the live electrical readings; the cell voltages
    /// and the gauge temperature feed the snapshot when the IORegistry lacks them. The area
    /// sensors are shown in Raw Data.
    public static let keys: [SMCFourCC] =
        [cellCountKey, "B0AV", "B0AC", gaugeTemperatureKey] + cellVoltageKeys + floatCellVoltageKeys
        + temperatureKeys

    /// A key's value for display, in its own unit except for the float cell voltages, which are
    /// shown in mV like the integer ones. The cell voltages and temperatures are decoded in the
    /// byte order that gives a plausible reading, as the snapshot does, and are `nil` when no
    /// order does; other keys follow their attribute bits.
    public static func displayNumber(_ value: SMCRawValue) -> Double? {
        let isCell = cellVoltageKeys.contains(value.key) || floatCellVoltageKeys.contains(value.key)
        guard isCell || temperatureKeys.contains(value.key) || value.key == gaugeTemperatureKey else {
            return value.number
        }
        for order in [nil, SMCByteOrder.little, .big] {
            guard let number = SMCValueDecoder.number(value.payload, info: value.info, order: order) else { continue }
            if isCell {
                if let millivolts = cellMillivolts(number, key: value.key) { return Double(millivolts) }
            } else if value.key == gaugeTemperatureKey {
                if celsius(decikelvin: number) != nil { return number }
            } else if plausibleTemperature.contains(number), number == 0 || abs(number) >= 0.005 {
                // A tiny non-zero value is a wrong byte order (999.9 reversed is -1e-22), not 0 °C.
                // To 0.01 °C: the sensors' floats sit an ulp or two off (TB0T 33.699997 on an M5).
                return (number * 100).rounded() / 100
            }
        }
        return nil
    }

    /// A decoded cell voltage in mV, or `nil` when it isn't a plausible one. Float keys may be in
    /// volts. Checked as a Double first: a float read in the wrong byte order can be far beyond
    /// Int's range, and converting it would trap.
    static func cellMillivolts(_ value: Double, key: SMCFourCC) -> Int? {
        guard value.isFinite, abs(value) < 1e9 else { return nil }
        let millivolts = Int((floatCellVoltageKeys.contains(key) && value < 10 ? value * 1000 : value).rounded())
        return plausibleCellVoltage.contains(millivolts) ? millivolts : nil
    }

    /// °C from tenths of a kelvin, or `nil` when implausible for a battery.
    static func celsius(decikelvin: Double) -> Double? {
        let celsius = ((decikelvin / 10 - 273.15) * 100).rounded() / 100
        return plausibleTemperature.contains(celsius) ? celsius : nil
    }

    /// The pack voltage (`B0AV`, mV) and current (`B0AC`, mA, positive while charging) as the SMC
    /// reads them now. The IORegistry copy can be a minute old: on a MacBook Air M5 it still
    /// showed −679 mA 40 s after the adapter was plugged in, while `B0AC` read +1898 mA after 10 s.
    public static func liveElectrical(in capture: PropertyDictionary) -> (voltageMV: Int, currentMA: Int)? {
        let values = Dictionary(uniqueKeysWithValues: Self.values(in: capture).map { ($0.key, $0) })
        guard let voltage = values["B0AV"].flatMap({ plausibleInteger($0, in: plausiblePackVoltage) }),
            let current = values["B0AC"].flatMap({ plausibleInteger($0, in: plausibleCurrent) })
        else { return nil }
        return (voltage, current)
    }

    static let plausiblePackVoltage = 2_500...20_000
    static let plausibleCurrent = -15_000...15_000

    /// An integer reading in the attribute byte order, or else the other one, inside `range`.
    static func plausibleInteger(_ value: SMCRawValue, in range: ClosedRange<Int>) -> Int? {
        for order in [nil, SMCByteOrder.little, .big] {
            if let number = SMCValueDecoder.number(value.payload, info: value.info, order: order),
                number.isFinite, abs(number) < 1e9, range.contains(Int(number))
            {
                return Int(number)
            }
        }
        return nil
    }

    /// The gauge temperature (`B0AT`) in °C, in the byte order that gives a plausible reading.
    public static func temperatureCelsius(in capture: PropertyDictionary) -> Double? {
        guard let value = values(in: capture).first(where: { $0.key == gaugeTemperatureKey }) else { return nil }
        for order in [nil, SMCByteOrder.little, .big] {
            if let number = SMCValueDecoder.number(value.payload, info: value.info, order: order),
                let celsius = celsius(decikelvin: number)
            {
                return celsius
            }
        }
        return nil
    }

    /// The values of a capture's `AppleSMC` dictionary, sorted by key.
    public static func values(in capture: PropertyDictionary) -> [SMCRawValue] {
        capture.compactMap { SMCRawValue(key: $0.key, captureValue: $0.value) }.sorted { $0.key < $1.key }
    }

    public static func capture(_ values: [SMCRawValue]) -> PropertyDictionary {
        Dictionary(uniqueKeysWithValues: values.map { ($0.key.description, $0.captureValue) })
    }

    /// Cell voltages in mV from `BC1V`… (`ui16`) or else `SBA1`… (`flt `, V or mV), limited to `BNCB`
    /// cells when it is present. With the pack voltage (AppleSmartBattery `Voltage`) the cells
    /// must add up to it, allowing for the readings not being simultaneous.
    public static func cellVoltagesMV(in capture: PropertyDictionary, packVoltageMV: Int?) -> [Int] {
        let values = Dictionary(uniqueKeysWithValues: Self.values(in: capture).map { ($0.key, $0) })
        let count = values[cellCountKey]?.number.flatMap { Int(exactly: $0) }.flatMap {
            (1...4).contains($0) ? $0 : nil
        }
        for keys in [cellVoltageKeys, floatCellVoltageKeys] {
            var cells = keys.compactMap { values[$0] }
            if let count {
                guard cells.count >= count else { continue }
                cells = Array(cells.prefix(count))
            }
            if let millivolts = cellVoltages(cells, packVoltageMV: packVoltageMV) { return millivolts }
        }
        return []
    }

    static func cellVoltages(_ cells: [SMCRawValue], packVoltageMV: Int?) -> [Int]? {
        guard !cells.isEmpty else { return nil }
        for order in [nil, SMCByteOrder.little, .big] {
            let millivolts = cells.compactMap { cell in
                SMCValueDecoder.number(cell.payload, info: cell.info, order: order).flatMap {
                    cellMillivolts($0, key: cell.key)
                }
            }
            guard millivolts.count == cells.count else { continue }
            if let pack = packVoltageMV, abs(millivolts.reduce(0, +) - pack) > 50 * cells.count + 100 { continue }
            return millivolts
        }
        return nil
    }
}
