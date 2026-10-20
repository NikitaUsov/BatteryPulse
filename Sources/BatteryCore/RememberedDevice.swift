import Foundation

/// What lockdown says about a device, before any session: even a device that doesn't trust this
/// Mac has a name and a model. `REDACTED` or empty values are `nil`.
public struct IDeviceIdentity: Sendable, Equatable {
    /// The name the owner gave the device.
    public var name: String?
    /// `iPhone`, `iPad`.
    public var deviceClass: String?
    /// `iPhone18,2`.
    public var productType: String?
    public var osVersion: String?

    public init(name: String? = nil, deviceClass: String? = nil, productType: String? = nil, osVersion: String? = nil) {
        self.name = name
        self.deviceClass = deviceClass
        self.productType = productType
        self.osVersion = osVersion
    }

    public init(capture: IDeviceCapture) {
        func value(_ key: String) -> String? {
            guard let text = IDeviceList.nonEmpty(capture.device[key]?.stringValue),
                text != BatteryReading.redactedPlaceholder
            else { return nil }
            return text
        }
        self.init(
            name: value(IDeviceCapture.Key.name), deviceClass: value("DeviceClass"),
            productType: value("ProductType"), osVersion: value("ProductVersion"))
    }

    /// "iPadOS" for an iPad, "iOS" otherwise.
    public var osName: String { IDeviceInfo.osName(deviceClass: deviceClass) }
}

/// An iPhone or iPad BatteryPulse has read, kept in `devices.json` so its page and history stay
/// when it is unplugged.
///
/// Never stored: the UDID, the ECID, serial numbers (the adapter's included), the pack's `UUID`
/// or raw captures. The owner's device name is kept, because the user needs it as the label.
public struct RememberedDevice: Sendable, Equatable, Codable, Identifiable {
    public var id: DeviceKey
    public var name: String?
    public var deviceClass: String?
    public var productType: String?
    public var osVersion: String?
    public var firstSeen: Date
    public var lastSeen: Date
    public var lastConnection: IDeviceConnection?
    public var lastRead: Date?
    /// As stored: without the adapter's serial number (``storable(_:)``).
    public var battery: IDeviceBattery?

    public init(id: DeviceKey, identity: IDeviceIdentity, battery: IDeviceBattery, at date: Date) {
        self.id = id
        name = identity.name
        deviceClass = identity.deviceClass
        productType = identity.productType
        osVersion = identity.osVersion
        firstSeen = date
        lastSeen = date
        lastRead = date
        self.battery = Self.storable(battery)
    }

    /// Identity refreshed (non-nil fields only), battery and lastRead replaced; firstSeen kept.
    public func updated(identity: IDeviceIdentity, battery: IDeviceBattery, at date: Date) -> RememberedDevice {
        var device = self
        device.name = identity.name ?? name
        device.deviceClass = identity.deviceClass ?? deviceClass
        device.productType = identity.productType ?? productType
        device.osVersion = identity.osVersion ?? osVersion
        device.battery = Self.storable(battery)
        device.lastRead = date
        device.lastSeen = max(lastSeen, date)
        return device
    }

    public func seen(over connection: IDeviceConnection, at date: Date) -> RememberedDevice {
        var device = self
        device.lastConnection = connection
        device.lastSeen = max(lastSeen, date)
        return device
    }

    /// `battery` without what identifies it (the adapter's serial number).
    public static func storable(_ battery: IDeviceBattery) -> IDeviceBattery {
        var battery = battery
        battery.adapter?.serialNumber = nil
        return battery
    }

    public var identity: IDeviceIdentity {
        IDeviceIdentity(name: name, deviceClass: deviceClass, productType: productType, osVersion: osVersion)
    }

    /// "iPadOS" for an iPad, "iOS" otherwise.
    public var osName: String { IDeviceInfo.osName(deviceClass: deviceClass) }
}

/// `devices.json`: the remembered devices and the format's version.
public struct RememberedDeviceFile: Sendable, Equatable, Codable {
    public static let currentVersion = 1
    public var version: Int
    public var devices: [RememberedDevice]

    public init(version: Int = Self.currentVersion, devices: [RememberedDevice]) {
        self.version = version
        self.devices = devices
    }
}
