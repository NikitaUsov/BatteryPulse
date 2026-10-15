import Foundation

/// How the Developer section presents a raw IORegistry or IOPS value.
public enum RawValueKind: String, Sendable, CaseIterable {
    case milliampHours, millivolts, milliamps, milliwatts, percent
    /// Energy per one-second telemetry sample in µWh, shown as power (1 µWh/s = 3.6 mW).
    case microwattHoursPerSecond
    /// Degrees Celsius.
    case celsius
    /// Hundredths of a degree Celsius, the unit of the gauge's `Temperature`.
    case centidegreesCelsius
    /// Tenths of a kelvin, the Smart Battery unit the SMC's `B0AT` uses.
    case decikelvin
    case minutes, seconds, unixTime
    case boolean, count, hex, flags
    /// USB Power Delivery Power Data Object: one voltage/current offer of a USB-C source.
    case usbPDO
    /// USB Power Delivery Request Data Object: the offer the Mac requested.
    case usbRDO
    case text, identifier, other
}

/// A raw value that stands for a state rather than a quantity.
public enum RawSentinel: String, Sendable {
    /// For example `65535` minutes to full while not charging.
    case notAvailable
    /// IOPS reports `-1` minutes while macOS is still estimating.
    case calculating
    /// An empty slot, a zero timestamp, or "no override".
    case none
}

/// A raw value turned into something a person can read. The app adds localized words and units.
public enum DecodedRawValue: Sendable, Equatable {
    case milliampHours(Int)
    case millivolts(Int)
    case milliamps(Int)
    case milliwatts(Int)
    case percent(Double)
    case celsius(Double)
    case minutes(Int)
    case seconds(Int)
    case date(Date)
    case boolean(Bool)
    /// A code shown in hexadecimal; `setBits` lists the bits that are on, for bitfields.
    case bits(UInt64, setBits: [Int])
    case powerDataObject(USBPowerDataObject)
    case requestDataObject(USBRequestDataObject)
    case sentinel(RawSentinel)
}

public enum RawValueDecoder {
    /// Decodes `value` as `kind`. Returns `nil` when decoding would add nothing to the raw value
    /// (counts, text, identifiers) or the value doesn't have the expected type.
    public static func decode(
        _ value: PropertyValue, as kind: RawValueKind, sentinels: [Int64: RawSentinel] = [:]
    ) -> DecodedRawValue? {
        if case .int(let number) = value, let sentinel = sentinels[number] {
            return .sentinel(sentinel)
        }
        switch kind {
        case .milliampHours: return value.intValue.map(DecodedRawValue.milliampHours)
        case .millivolts: return value.intValue.map(DecodedRawValue.millivolts)
        case .milliamps: return value.intValue.map(DecodedRawValue.milliamps)
        case .milliwatts: return value.intValue.map(DecodedRawValue.milliwatts)
        case .microwattHoursPerSecond:
            return value.intValue.map { .milliwatts(Int((Double($0) * 3.6).rounded())) }
        case .percent: return value.doubleValue.map(DecodedRawValue.percent)
        case .celsius: return value.doubleValue.map(DecodedRawValue.celsius)
        case .centidegreesCelsius: return value.doubleValue.map { .celsius($0 / 100) }
        case .decikelvin: return value.doubleValue.map { .celsius((($0 / 10 - 273.15) * 100).rounded() / 100) }
        case .minutes: return value.intValue.map(DecodedRawValue.minutes)
        case .seconds: return value.intValue.map(DecodedRawValue.seconds)
        case .unixTime:
            guard let seconds = value.intValue else { return nil }
            return seconds > 0 ? .date(Date(timeIntervalSince1970: TimeInterval(seconds))) : .sentinel(.none)
        case .boolean: return value.boolValue.map(DecodedRawValue.boolean)
        case .hex, .flags:
            guard let bits = unsignedBits(value) else { return nil }
            return .bits(bits, setBits: kind == .flags ? setBits(of: bits) : [])
        case .usbPDO:
            guard let bits = unsignedBits(value) else { return nil }
            return USBPowerDataObject(rawValue: UInt32(truncatingIfNeeded: bits)).map(DecodedRawValue.powerDataObject)
                ?? .sentinel(.none)
        case .usbRDO:
            guard let bits = unsignedBits(value) else { return nil }
            return USBRequestDataObject(rawValue: UInt32(truncatingIfNeeded: bits)).map(
                DecodedRawValue.requestDataObject) ?? .sentinel(.none)
        case .count, .text, .identifier, .other:
            return nil
        }
    }

    /// IORegistry stores 32-bit registers as signed numbers (`FamilyCode` -536854518 is
    /// 0xE000400A), so negative 32-bit values are reinterpreted as unsigned.
    static func unsignedBits(_ value: PropertyValue) -> UInt64? {
        guard case .int(let number) = value else { return nil }
        if number >= 0 { return UInt64(number) }
        if number >= Int64(Int32.min) { return UInt64(UInt32(bitPattern: Int32(number))) }
        return UInt64(bitPattern: number)
    }

    static func setBits(of value: UInt64) -> [Int] {
        (0..<64).filter { value & (1 << UInt64($0)) != 0 }
    }
}

/// A USB Power Delivery Power Data Object (USB PD 3.1, section 6.4.1): one voltage and current
/// a USB-C power source offers.
public enum USBPowerDataObject: Sendable, Equatable {
    case fixed(voltageMV: Int, maxCurrentMA: Int)
    case variable(minVoltageMV: Int, maxVoltageMV: Int, maxCurrentMA: Int)
    case battery(minVoltageMV: Int, maxVoltageMV: Int, maxPowerMW: Int)
    /// Programmable Power Supply (PPS) augmented PDO.
    case programmable(minVoltageMV: Int, maxVoltageMV: Int, maxCurrentMA: Int)
    /// Adjustable Voltage Supply and future augmented PDOs, not decoded further.
    case otherAugmented(UInt32)

    /// `nil` for an empty slot (`0`).
    public init?(rawValue: UInt32) {
        guard rawValue != 0 else { return nil }
        func field(_ high: UInt32, _ low: UInt32) -> Int {
            Int((rawValue >> low) & ((1 << (high - low + 1)) - 1))
        }
        switch rawValue >> 30 {
        case 0b00:
            self = .fixed(voltageMV: field(19, 10) * 50, maxCurrentMA: field(9, 0) * 10)
        case 0b01:
            self = .battery(
                minVoltageMV: field(19, 10) * 50, maxVoltageMV: field(29, 20) * 50, maxPowerMW: field(9, 0) * 250)
        case 0b10:
            self = .variable(
                minVoltageMV: field(19, 10) * 50, maxVoltageMV: field(29, 20) * 50, maxCurrentMA: field(9, 0) * 10)
        default:
            if field(29, 28) == 0 {
                self = .programmable(
                    minVoltageMV: field(15, 8) * 100, maxVoltageMV: field(24, 17) * 100,
                    maxCurrentMA: field(6, 0) * 50)
            } else {
                self = .otherAugmented(rawValue)
            }
        }
    }

    /// Maximum power of a fixed offer, in milliwatts.
    public var maxPowerMW: Int? {
        if case .fixed(let voltage, let current) = self { return voltage * current / 1000 }
        if case .battery(_, _, let power) = self { return power }
        return nil
    }
}

/// A USB Power Delivery Request Data Object for a fixed or variable supply (USB PD 3.1,
/// section 6.4.2): which offer the sink chose and how much current it asked for.
public struct USBRequestDataObject: Sendable, Equatable {
    /// 1-based position of the requested PDO in the source's list.
    public var objectPosition: Int
    public var operatingCurrentMA: Int
    public var maxCurrentMA: Int

    public init(objectPosition: Int, operatingCurrentMA: Int, maxCurrentMA: Int) {
        self.objectPosition = objectPosition
        self.operatingCurrentMA = operatingCurrentMA
        self.maxCurrentMA = maxCurrentMA
    }

    /// `nil` when no contract is active (`0`).
    public init?(rawValue: UInt32) {
        let position = Int(rawValue >> 28)
        guard position > 0 else { return nil }
        objectPosition = position
        operatingCurrentMA = Int((rawValue >> 10) & 0x3FF) * 10
        maxCurrentMA = Int(rawValue & 0x3FF) * 10
    }
}
