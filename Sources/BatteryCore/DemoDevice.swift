import Foundation

/// The iPhone Demo Mode shows in the Devices section in place of real devices, so screenshots
/// never show a real owner's device name. Its values follow the real iPhone 17 Pro Max capture
/// (Fixtures/iphone17promax-ios27.0.1-usb.plist) with a 20 W adapter.
public enum DemoDevice {
    public static let entry = IDeviceEntry(
        id: .demo,
        isRemembered: true,
        name: "iPhone",
        deviceClass: "iPhone",
        productType: "iPhone18,2",
        osVersion: "27.0.1",
        osName: "iOS",
        connection: .usb,
        battery: battery,
        readAt: nil,
        lastSeen: nil,
        problem: nil,
        isReading: false,
        hasCapture: false
    )

    static let battery = IDeviceBattery(
        source: "AppleSmartBattery",
        chargePercent: 65,
        chargeState: .charging,
        isExternalPowerConnected: true,
        currentCapacityMAh: 3151,
        fullChargeCapacityMAh: 4922,
        nominalChargeCapacityMAh: 4800,
        designCapacityMAh: 5030,
        maximumCapacityPercent: 95,
        // 2025-10-02, noon UTC.
        firstUseDate: Date(timeIntervalSince1970: 1_759_406_400),
        cycleCount: 278,
        temperatureCelsius: 36.5,
        voltageMV: 4137,
        amperageMA: 2108,
        instantAmperageMA: 2087,
        adapter: PowerAdapter(watts: 20, adapterDescription: "pd charger", isWireless: false)
    )
}
