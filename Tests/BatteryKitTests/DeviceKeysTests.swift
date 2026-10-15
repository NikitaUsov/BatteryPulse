#if canImport(CryptoKit)
import BatteryCore
import Foundation
import Testing

@testable import BatteryKit

/// The HMAC behind ``DeviceKey``; the vector was computed independently. The UDID is SYNTHETIC.
@Suite struct DeviceKeysTests {
    private static let udid = "00008150-001A2D3C4E5F601C"
    private static let secret = Data(0...31)

    @Test func matchesVector() {
        let key = HMACDeviceKeyDeriver(secret: Self.secret).key(forIdentifier: Self.udid)
        #expect(key.rawValue == "cfa3073fbe82243a2581b4d4ce99245e")
    }

    @Test func caseInsensitiveUDID() {
        let deriver = HMACDeviceKeyDeriver(secret: Self.secret)
        #expect(deriver.key(forIdentifier: Self.udid.lowercased()) == deriver.key(forIdentifier: Self.udid))
    }

    @Test func differentSecretsDiffer() {
        let other = HMACDeviceKeyDeriver(secret: Data(repeating: 7, count: 32)).key(forIdentifier: Self.udid)
        #expect(other != HMACDeviceKeyDeriver(secret: Self.secret).key(forIdentifier: Self.udid))
        #expect(other.rawValue.count == 32)
    }
}
#endif
