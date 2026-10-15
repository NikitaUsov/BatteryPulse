import BatteryCore

/// SYNTHETIC iPhone and iPad battery data. No real capture of an iOS device exists yet.
///
/// Each dictionary uses only keys that public descriptions of the iOS `AppleSmartBattery` entry,
/// the `AppleSmartBatteryPack` entry and the `com.apple.mobile.battery` lockdown domain name.
/// The values are illustrative: the iPhone's follow a public, trimmed iPhone 11 capture on iOS
/// 26.6, the iPads' public iPad captures on iPadOS 27.0.1. Replace them with real captures from
/// `bpulse --device <n> --raw` once the maintainer has taken them.
enum SyntheticIDevice {
    /// iOS 26 layout: capacities at the top level, `Temperature` on the battery itself,
    /// `Voltage` reading 0 next to `AppleRawBatteryVoltage`.
    static let iPhoneEntry: PropertyDictionary = [
        "AdapterDetails": .dictionary([
            "AdapterVoltage": .int(5000), "Current": .int(2400), "Description": .string("usb host"),
            "IsWireless": .bool(false), "Watts": .int(12),
        ]),
        "Amperage": .int(1476),
        "AppleRawBatteryVoltage": .int(3879),
        "AppleRawCurrentCapacity": .int(219),
        "AppleRawExternalConnected": .bool(true),
        "AppleRawMaxCapacity": .int(2633),
        "AtCriticalLevel": .bool(false),
        "AvgTimeToEmpty": .int(55),
        "BatteryData": .dictionary(["CellVoltage": .array([.int(3879)])]),
        "CurrentCapacity": .int(9),
        "CycleCount": .int(768),
        "DesignCapacity": .int(3092),
        "FullyCharged": .bool(false),
        "InstantAmperage": .int(1460),
        "IsCharging": .bool(true),
        "MaxCapacity": .int(100),
        "NominalChargeCapacity": .int(2564),
        "Serial": .string("F5D0000000000000"),
        "Temperature": .int(3550),
        "TimeRemaining": .int(42),
        "VirtualTemperature": .int(3420),
        "Voltage": .int(0),
    ]

    static let iPhoneLockdownBattery: PropertyDictionary = [
        "BatteryCurrentCapacity": .int(9), "BatteryIsCharging": .bool(true), "ExternalChargeCapable": .bool(true),
        "ExternalConnected": .bool(true), "FullyCharged": .bool(false), "GasGaugeCapability": .bool(true),
        "HasBattery": .bool(true),
    ]

    static let iPhoneDevice: PropertyDictionary = [
        "Connection": .string("USB"), "DeviceClass": .string("iPhone"), "DeviceName": .string("Owner's iPhone"),
        "ProductType": .string("iPhone12,1"), "ProductVersion": .string("26.6"),
        "UniqueDeviceID": .string("00008030-001A2B3C4D5E801C"),
    ]

    /// iPadOS 27 layout: design and nominal capacity in `BatteryData`, no `AppleRawMaxCapacity`,
    /// no temperature on the battery (it moved to the pack).
    static let iPadEntry: PropertyDictionary = [
        "Amperage": .int(2139),
        "BatteryData": .dictionary(["DesignCapacity": .int(7544), "NominalChargeCapacity": .int(7913)]),
        "CurrentCapacity": .int(81),
        "CycleCount": .int(11),
        "ExternalConnected": .bool(true),
        "IsCharging": .bool(true),
        "MaxCapacity": .int(100),
        "Voltage": .int(4164),
    ]

    static let iPadPack: PropertyDictionary = [
        "BatteryData": .dictionary([
            "Temperature": .int(3350), "VirtualTemperature": .int(3350), "Voltage": .int(4164),
        ])
    ]

    /// A second iPad, whose nominal and full-charge capacities differ enough to pin which one
    /// each ratio uses.
    static let agedIPadEntry: PropertyDictionary = [
        "BatteryData": .dictionary([
            "DesignCapacity": .int(7596), "NominalChargeCapacity": .int(6891), "FullChargeCapacity": .int(6700),
        ]),
        "CurrentCapacity": .int(50),
        "MaxCapacity": .int(100),
    ]

    static func reply(_ entry: PropertyDictionary) -> PropertyDictionary {
        ["Status": .string("Success"), "Diagnostics": .dictionary(["IORegistry": .dictionary(entry)])]
    }

    static let failure: PropertyDictionary = ["Status": .string("Failure")]

    static func request(_ entryClass: String) -> PropertyDictionary {
        DiagnosticsRelay.registryRequest(entryClass: entryClass)
    }

    /// The calls of a read that went through, as the reader records them.
    static let successfulSteps: [IDeviceCapture.Step] = [
        .init(.connect, .success), .init(.validatePairing, .success), .init(.startSession, .success),
        .init(.startService, .success), .init(.closeService, .success), .init(.stopSession, .success),
        .init(.disconnect, .success),
    ]

    /// A complete iPhone read: battery, no pack (iOS 26 has none), the other children missing.
    static var iPhoneCapture: IDeviceCapture {
        IDeviceCapture(
            device: iPhoneDevice,
            isPaired: true,
            lockdownBattery: iPhoneLockdownBattery,
            exchanges: [
                .init(request: request("AppleSmartBattery"), reply: reply(iPhoneEntry)),
                .init(request: request("AppleSmartBatteryPack"), reply: failure),
                .init(request: request("AppleSmartBatteryBank"), reply: failure),
                .init(request: request("AppleChargerData"), reply: failure),
                .init(request: DiagnosticsRelay.goodbye, reply: ["Status": .string("Success")]),
            ],
            steps: successfulSteps
        )
    }

    static var iPadCapture: IDeviceCapture {
        IDeviceCapture(
            device: [
                "Connection": .string("Wi-Fi"), "DeviceClass": .string("iPad"), "ProductType": .string("iPad16,8"),
                "ProductVersion": .string("27.0.1"),
            ],
            isPaired: true,
            exchanges: [
                .init(request: request("AppleSmartBattery"), reply: reply(iPadEntry)),
                .init(request: request("AppleSmartBatteryPack"), reply: reply(iPadPack)),
            ],
            steps: successfulSteps
        )
    }
}
