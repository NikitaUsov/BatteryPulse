import Foundation

/// The keys that prove an update comes from BatteryPulse's release workflow.
///
/// The release workflow signs each DMG with a private key (the `UPDATE_SIGNING_KEY` secret,
/// `scripts/sign-update.swift`) and attaches the signature as `BatteryPulse.dmg.sig`. The app
/// installs an update itself only when one of these public keys verifies that signature; GitHub's
/// own digest only proves the download is intact, not who made it.
public enum ReleaseSigning {
    /// Raw 32-byte Curve25519 (Ed25519) signing public keys in base64. A signature by any of
    /// them is valid, so a new key can be listed one release before the workflow signs with it;
    /// `swift scripts/sign-update.swift --help` has the rotation steps. The release workflow
    /// reads these lines to check that its secret belongs to one of the keys, so keep each key
    /// on its own line.
    public static let publicKeys = [
        "R3LDmkmupenX1gnEnR7n+gEllH8oIDbWODJoGJ/m+dg="  // since 0.4.0
    ]

    /// The keys among `entries` that are 32 bytes in base64, once each and in order. An empty or
    /// malformed entry is ignored, so it can't stop the other keys from verifying.
    public static func rawKeys(_ entries: [String]) -> [Data] {
        var keys: [Data] = []
        for entry in entries {
            guard let key = Data(base64Encoded: entry.trimmingCharacters(in: .whitespaces)), key.count == 32,
                !keys.contains(key)
            else { continue }
            keys.append(key)
        }
        return keys
    }
}
