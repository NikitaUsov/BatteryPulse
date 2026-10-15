import Foundation

/// How BatteryPulse names a remembered iPhone or iPad on disk: a keyed hash of its UDID, so a
/// folder or file never reveals the identifier and two installs can't correlate their keys.
///
/// Real keys are 32 lowercase hex characters (``DeviceKeyDerivation``). Any key is 1–64
/// characters of `[0-9a-z-]`, so it is always a safe folder name. ``demo`` is reserved for Demo
/// Mode's simulated iPhone and never collides with a real key.
public struct DeviceKey: RawRepresentable, Hashable, Codable, Sendable, CustomStringConvertible {
    public let rawValue: String

    public init?(rawValue: String) {
        guard Self.isValid(rawValue) else { return nil }
        self.rawValue = rawValue
    }

    public init?(_ rawValue: String) {
        self.init(rawValue: rawValue)
    }

    /// For constants known to be valid.
    private init(unchecked rawValue: String) {
        self.rawValue = rawValue
    }

    /// Demo Mode's simulated iPhone.
    public static let demo = DeviceKey(unchecked: "demo")

    public var description: String { rawValue }

    static func isValid(_ value: String) -> Bool {
        let bytes = value.utf8
        guard (1...64).contains(bytes.count) else { return false }
        return bytes.allSatisfy { (0x30...0x39).contains($0) || (0x61...0x7A).contains($0) || $0 == 0x2D }
    }
}

/// Turns a UDID into a ``DeviceKey``. The app's implementation is an HMAC with a per-install
/// secret (CryptoKit, in BatteryKit); tests use a plain mapping.
public protocol DeviceKeyDeriving: Sendable {
    func key(forIdentifier udid: String) -> DeviceKey
}

/// The parts of the key derivation that don't need CryptoKit: the message that is
/// authenticated and the hex form of the result.
public enum DeviceKeyDerivation {
    /// Changing it gives every device a new key and orphans its history.
    static let messagePrefix = "BatteryPulse device v1\n"

    /// `"BatteryPulse device v1\n"` followed by the UDID in upper case, as UTF-8; the case of
    /// the UDID doesn't matter.
    public static func message(forIdentifier udid: String) -> Data {
        Data((messagePrefix + udid.uppercased()).utf8)
    }

    /// Lowercase hex of the first 16 bytes; nil when fewer than 16 bytes are given.
    public static func key(fromAuthenticationCode bytes: some Sequence<UInt8>) -> DeviceKey? {
        let first = Array(bytes.prefix(16))
        guard first.count == 16 else { return nil }
        let digits = Array("0123456789abcdef")
        var hex = ""
        hex.reserveCapacity(32)
        for byte in first {
            hex.append(digits[Int(byte >> 4)])
            hex.append(digits[Int(byte & 0x0F)])
        }
        return DeviceKey(rawValue: hex)
    }
}
