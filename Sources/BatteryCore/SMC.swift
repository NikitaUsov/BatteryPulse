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
/// rest from VirtualSMC's `AppleSmc.h`.
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
    /// big-endian (`#KEY`, and one byte-reversed float Asahi lists). Seen on one M4 Max, so
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
            return value.isFinite ? Double(value) : nil
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
            let type = d[CaptureField.type]?.stringValue.flatMap { SMCFourCC(validating: $0) },
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

    /// Cells in series (`ui8`).
    public static let cellCountKey: SMCFourCC = "BNCB"
    public static let cellVoltageKeys: [SMCFourCC] = ["BC1V", "BC2V", "BC3V", "BC4V"]
    /// Cell voltages as floats, reported on earlier Apple silicon.
    public static let floatCellVoltageKeys: [SMCFourCC] = ["SBA1", "SBA2", "SBA3", "SBA4"]
    /// Battery-area temperature sensors (`flt `, °C). Not the battery's temperature: Linux labels
    /// `TB0T` "Battery Hotspot", they read up to 3 °C off the gauge on an M4 Max, and Stats found
    /// them clearly wrong on a MacBook Neo under macOS 27. Shown in Raw Data only.
    public static let temperatureKeys: [SMCFourCC] = ["TB0T", "TB1T", "TB2T", "TB3T"]

    /// Every key the app reads: read-only, battery-related and safe to read repeatedly. Only the
    /// cell voltages feed the snapshot. The pack voltage (`B0AV`), current (`B0AC`), the gauge's
    /// own temperature (`B0AT`, whose unit is still disputed) and the area sensors are shown in
    /// Raw Data.
    public static let keys: [SMCFourCC] =
        [cellCountKey, "B0AV", "B0AC", "B0AT"] + cellVoltageKeys + floatCellVoltageKeys + temperatureKeys

    /// The values of a capture's `AppleSMC` dictionary, sorted by key.
    public static func values(in capture: PropertyDictionary) -> [SMCRawValue] {
        capture.compactMap { SMCRawValue(key: $0.key, captureValue: $0.value) }.sorted { $0.key < $1.key }
    }

    public static func capture(_ values: [SMCRawValue]) -> PropertyDictionary {
        Dictionary(uniqueKeysWithValues: values.map { ($0.key.description, $0.captureValue) })
    }

    /// Cell voltages in mV from `BC1V`… (`ui16`) or else `SBA1`… (`flt `), limited to `BNCB`
    /// cells when it is present. With the pack voltage (AppleSmartBattery `Voltage`) the cells
    /// must add up to it, allowing for the readings not being simultaneous.
    public static func cellVoltagesMV(in capture: PropertyDictionary, packVoltageMV: Int?) -> [Int] {
        let values = Dictionary(uniqueKeysWithValues: Self.values(in: capture).map { ($0.key, $0) })
        let count = values[cellCountKey]?.number.map { Int($0) }.flatMap { (1...4).contains($0) ? $0 : nil }
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
                SMCValueDecoder.number(cell.payload, info: cell.info, order: order).map { Int($0.rounded()) }
            }
            guard millivolts.count == cells.count, millivolts.allSatisfy(plausibleCellVoltage.contains) else {
                continue
            }
            if let pack = packVoltageMV, abs(millivolts.reduce(0, +) - pack) > 50 * cells.count + 100 { continue }
            return millivolts
        }
        return nil
    }
}
