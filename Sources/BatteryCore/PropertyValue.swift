import Foundation

/// A typed, `Sendable` mirror of a property-list value.
///
/// IOKit hands out `CFDictionary` trees; `PropertyListSerialization` hands out `[String: Any]`.
/// Both are normalized into this enum so the parsing code is identical on macOS, iOS and Linux
/// (where tests run against captured `ioreg -a` fixtures).
public enum PropertyValue: Sendable, Hashable {
    case bool(Bool)
    case int(Int64)
    case double(Double)
    case string(String)
    case data(Data)
    case array([PropertyValue])
    case dictionary([String: PropertyValue])
}

public typealias PropertyDictionary = [String: PropertyValue]

// MARK: - Conversion from Foundation / CoreFoundation values

extension PropertyValue {
    /// The deepest nesting of containers converted. IORegistry entries, lockdown values and
    /// diagnostics relay replies are about 6 deep; the limit only bounds the recursion for a
    /// malformed or hostile device reply.
    static let maxDepth = 64

    /// Converts a Foundation property-list object. Unsupported values (e.g. `Date`) yield `nil`,
    /// and so do containers nested deeper than ``maxDepth``: they are dropped from their parent.
    public init?(any value: Any) {
        self.init(any: value, depth: 0)
    }

    private init?(any value: Any, depth: Int) {
        switch value {
        case let string as String:
            self = .string(string)
        case let data as Data:
            self = .data(data)
        case let dictionary as [String: Any]:
            guard depth < Self.maxDepth else { return nil }
            self = .dictionary(dictionary.compactMapValues { PropertyValue(any: $0, depth: depth + 1) })
        case let array as [Any]:
            guard depth < Self.maxDepth else { return nil }
            self = .array(array.compactMap { PropertyValue(any: $0, depth: depth + 1) })
        default:
            guard let number = Self.number(from: value) else { return nil }
            self = number
        }
    }

    /// Converts a `[String: Any]` (e.g. a bridged `CFDictionary`) into a ``PropertyDictionary``.
    public static func dictionary(fromAny value: Any?) -> PropertyDictionary? {
        guard let value, case .dictionary(let dictionary)? = PropertyValue(any: value) else { return nil }
        return dictionary
    }

    private static func number(from value: Any) -> PropertyValue? {
        #if canImport(Darwin)
        // On Darwin every number arrives as NSNumber/CFNumber/CFBoolean, and `as? Bool`
        // succeeds for any 0/1 integer, so inspect the CF type instead of casting.
        guard let number = value as? NSNumber else { return nil }
        let cfNumber = number as CFNumber
        if CFGetTypeID(cfNumber) == CFBooleanGetTypeID() { return .bool(number.boolValue) }
        if CFNumberIsFloatType(cfNumber) { return .double(number.doubleValue) }
        if let signed = value as? Int64 { return .int(signed) }
        if let unsigned = value as? UInt64 { return .int(Int64(bitPattern: unsigned)) }
        return .int(number.int64Value)
        #else
        // swift-corelibs-foundation yields `Bool` for <true/>/<false/> and NSNumber for numbers,
        // but an NSNumber holding 0/1 also casts to Bool — so match the exact dynamic type.
        if type(of: value) == Bool.self, let bool = value as? Bool { return .bool(bool) }
        if let int = value as? Int { return .int(Int64(int)) }
        if let int = value as? Int64 { return .int(int) }
        // IORegistry stores signed quantities such as `Amperage` in 64 bits; `ioreg -a`
        // prints negatives as huge unsigned numbers. Reinterpret the bit pattern.
        if let unsigned = value as? UInt64 { return .int(Int64(bitPattern: unsigned)) }
        if let double = value as? Double { return .double(double) }
        return nil
        #endif
    }
}

// MARK: - Conversion back to Foundation values

extension PropertyValue {
    /// A Foundation property-list object, suitable for `PropertyListSerialization`.
    public var foundationValue: Any {
        switch self {
        case .bool(let value): value
        case .int(let value): value
        case .double(let value): value
        case .string(let value): value
        case .data(let value): value
        case .array(let values): values.map(\.foundationValue)
        case .dictionary(let values): values.mapValues(\.foundationValue)
        }
    }
}

// MARK: - Typed accessors

extension PropertyValue {
    public var intValue: Int? {
        switch self {
        case .int(let value): Int(exactly: value)
        case .double(let value): value.isFinite ? Int(exactly: value.rounded()) : nil
        default: nil
        }
    }

    public var doubleValue: Double? {
        switch self {
        case .int(let value): Double(value)
        case .double(let value): value
        default: nil
        }
    }

    /// Booleans, plus 0/1 integers (some IORegistry flags are stored as numbers).
    public var boolValue: Bool? {
        switch self {
        case .bool(let value): value
        case .int(0): false
        case .int(1): true
        default: nil
        }
    }

    public var stringValue: String? {
        if case .string(let value) = self { return value }
        return nil
    }

    public var arrayValue: [PropertyValue]? {
        if case .array(let value) = self { return value }
        return nil
    }

    public var dictionaryValue: PropertyDictionary? {
        if case .dictionary(let value) = self { return value }
        return nil
    }
}

// MARK: - Display

extension PropertyValue: CustomStringConvertible {
    public var description: String {
        switch self {
        case .bool(let value): value ? "true" : "false"
        case .int(let value): String(value)
        case .double(let value): String(value)
        case .string(let value): value
        // Lowercase, two digits a byte, as C's `%02x` prints them.
        case .data(let value): "<" + UpdateIntegrity.hex(value) + ">"
        case .array(let values): "[" + values.map(\.description).joined(separator: ", ") + "]"
        case .dictionary(let values):
            "{"
                + values.sorted { $0.key < $1.key }
                .map { "\($0.key) = \($0.value)" }
                .joined(separator: "; ") + "}"
        }
    }
}
