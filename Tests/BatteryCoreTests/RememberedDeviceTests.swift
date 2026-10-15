import Foundation
import Testing

@testable import BatteryCore

@Suite struct RememberedDeviceTests {
    private static let key = DeviceKey("cfa3073fbe82243a2581b4d4ce99245e") ?? .demo
    private static let start = Date(timeIntervalSince1970: 1_800_000_000)

    /// The real iPhone fixture and its parsed battery.
    static func realIPhone() throws -> (capture: IDeviceCapture, battery: IDeviceBattery) {
        let capture = try RealIDeviceCaptureTests.capture(RealIDeviceCaptureTests.iPhone17ProMax)
        return (capture, try #require(IDeviceBatteryParser.battery(in: capture)))
    }

    @Test func identityFromCapture() throws {
        let identity = IDeviceIdentity(capture: try Self.realIPhone().capture)
        #expect(identity.deviceClass == "iPhone")
        #expect(identity.productType == "iPhone18,2")
        #expect(identity.osVersion == "27.0.1")
        #expect(identity.name == nil, "REDACTED counts as absent")
        #expect(identity.osName == "iOS")

        let named = IDeviceIdentity(capture: SyntheticIDevice.iPhoneCapture)
        #expect(named.name == "Owner's iPhone")
        let empty = IDeviceIdentity(capture: IDeviceCapture(device: ["DeviceName": .string("  ")]))
        #expect(empty == IDeviceIdentity())
    }

    @Test func updateKeepsFirstSeen() throws {
        let battery = try Self.realIPhone().battery
        let first = RememberedDevice(
            id: Self.key, identity: IDeviceIdentity(name: "Phone", deviceClass: "iPhone", productType: "iPhone18,2"),
            battery: battery, at: Self.start)
        #expect(first.firstSeen == Self.start)
        #expect(first.lastRead == Self.start)
        #expect(first.lastConnection == nil)

        var newer = battery
        newer.chargePercent = 70
        let later = Self.start.addingTimeInterval(300)
        let updated = first.updated(identity: IDeviceIdentity(osVersion: "27.1"), battery: newer, at: later)
            .seen(over: .usb, at: later)
        #expect(updated.firstSeen == Self.start)
        #expect(updated.lastSeen == later)
        #expect(updated.lastRead == later)
        #expect(updated.name == "Phone", "a missing name keeps the stored one")
        #expect(updated.osVersion == "27.1")
        #expect(updated.battery?.chargePercent == 70)
        #expect(updated.lastConnection == .usb)
        #expect(updated.osName == "iOS")
    }

    @Test func storableBatteryDropsAdapterSerial() throws {
        var battery = try Self.realIPhone().battery
        battery.adapter?.serialNumber = "SYNTHETIC-SERIAL"
        let stored = RememberedDevice.storable(battery)
        #expect(stored.adapter?.serialNumber == nil)
        #expect(stored.adapter?.watts == battery.adapter?.watts)
        let device = RememberedDevice(id: Self.key, identity: IDeviceIdentity(), battery: battery, at: Self.start)
        #expect(device.battery?.adapter?.serialNumber == nil)
    }
}
