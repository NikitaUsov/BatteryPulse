#if canImport(CryptoKit)
import BatteryCore
import CryptoKit
import Foundation

/// Verifies the Ed25519 signature that the release workflow makes over each DMG
/// (`scripts/sign-update.swift`). Ad-hoc code signing proves only that a bundle is intact, not
/// who built it, so this signature is what lets the app trust an update it installs itself.
public struct UpdateSignatureVerifier: Sendable {
    /// The raw 32-byte public key.
    private let publicKey: Data

    /// `nil` unless `publicKeyBase64` is a raw 32-byte Curve25519 signing key in base64.
    public init?(publicKeyBase64: String) {
        guard let raw = Data(base64Encoded: publicKeyBase64), raw.count == 32,
            (try? Curve25519.Signing.PublicKey(rawRepresentation: raw)) != nil
        else { return nil }
        publicKey = raw
    }

    /// The key BatteryPulse's releases are signed with, ``ReleaseSigning/publicKey``.
    public static let release = UpdateSignatureVerifier(publicKeyBase64: ReleaseSigning.publicKey)

    /// Whether `signature` (64 bytes) is this key's signature of exactly `data`.
    public func isValid(signature: Data, for data: Data) -> Bool {
        guard signature.count == 64,
            let key = try? Curve25519.Signing.PublicKey(rawRepresentation: publicKey)
        else { return false }
        return key.isValidSignature(signature, for: data)
    }

    /// The SHA-256 of `data` in lowercase hex, to compare with GitHub's asset digest.
    public static func sha256Hex(of data: Data) -> String {
        UpdateIntegrity.hex(SHA256.hash(data: data))
    }
}
#endif
