#if canImport(CryptoKit)
import BatteryCore
import CryptoKit
import Foundation

/// The app's ``DeviceKeyDeriving``: the first 128 bits of HMAC-SHA256 of the UDID under the
/// per-install secret (``DeviceStore/secret()``). The same device keeps its key across launches,
/// so its history re-attaches, while a key reveals nothing about the UDID and two installs can't
/// correlate their keys. The message and the hex form are ``DeviceKeyDerivation``'s.
public struct HMACDeviceKeyDeriver: DeviceKeyDeriving {
    private let secret: Data

    public init(secret: Data) {
        self.secret = secret
    }

    public func key(forIdentifier udid: String) -> DeviceKey {
        let code = HMAC<SHA256>.authenticationCode(
            for: DeviceKeyDerivation.message(forIdentifier: udid), using: SymmetricKey(data: secret))
        // SHA-256 always gives 32 bytes, so the key always exists.
        return DeviceKeyDerivation.key(fromAuthenticationCode: code) ?? .demo
    }
}
#endif
