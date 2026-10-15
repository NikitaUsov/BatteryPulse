/// The key that proves an update comes from BatteryPulse's release workflow.
///
/// The release workflow signs each DMG with the private half (the `UPDATE_SIGNING_KEY` secret,
/// `scripts/sign-update.swift`) and attaches the signature as `BatteryPulse.dmg.sig`. The app
/// installs an update itself only when this public key verifies that signature; GitHub's own
/// digest only proves the download is intact, not who made it.
public enum ReleaseSigning {
    /// A raw 32-byte Curve25519 (Ed25519) signing public key, in base64. The release workflow
    /// reads this line to check that its secret belongs to it, so keep it on one line.
    public static let publicKey = "QbxzS5y6fUj0ATQD3LpfeX0KRY00D+/P19wnktSMp0s="
}
