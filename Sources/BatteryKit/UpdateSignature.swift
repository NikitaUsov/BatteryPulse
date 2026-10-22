#if canImport(CryptoKit)
import BatteryCore
import CryptoKit
import Foundation

/// Verifies the Ed25519 signature that the release workflow makes over each DMG
/// (`scripts/sign-update.swift`). Ad-hoc code signing proves only that a bundle is intact, not
/// who built it, so this signature is what lets the app trust an update it installs itself.
public struct UpdateSignatureVerifier: Sendable {
    /// The raw 32-byte public keys; a signature by any of them is valid.
    private let publicKeys: [Data]

    /// Trusts each entry of `publicKeysBase64` that is a raw 32-byte Curve25519 signing key in
    /// base64 and ignores the others; `nil` when none is.
    public init?(publicKeysBase64: [String]) {
        let keys = ReleaseSigning.rawKeys(publicKeysBase64).filter {
            (try? Curve25519.Signing.PublicKey(rawRepresentation: $0)) != nil
        }
        guard !keys.isEmpty else { return nil }
        publicKeys = keys
    }

    /// The keys BatteryPulse's releases are signed with, ``ReleaseSigning/publicKeys``.
    public static let release = UpdateSignatureVerifier(publicKeysBase64: ReleaseSigning.publicKeys)

    /// Whether `signature` (64 bytes) is one of the keys' signature of exactly `data`.
    public func isValid(signature: Data, for data: Data) -> Bool {
        guard signature.count == 64 else { return false }
        return publicKeys.contains { raw in
            guard let key = try? Curve25519.Signing.PublicKey(rawRepresentation: raw) else { return false }
            return key.isValidSignature(signature, for: data)
        }
    }

    /// The SHA-256 of `data` in lowercase hex, to compare with GitHub's asset digest.
    public static func sha256Hex(of data: Data) -> String {
        UpdateIntegrity.hex(SHA256.hash(data: data))
    }
}
#endif
