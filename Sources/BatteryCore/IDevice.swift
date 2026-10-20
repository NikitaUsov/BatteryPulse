import Foundation

/// How an iPhone or iPad is attached to the Mac (MobileDevice's interface type).
public enum IDeviceConnection: String, Sendable, Codable, CaseIterable {
    case usb = "USB"
    case wifi = "Wi-Fi"
    case unknown = "Unknown"

    /// Interface types: 1 USB, 2 network. 3 is a companion proxy (an Apple Watch reached through
    /// its iPhone), which is never read; 0 is unknown.
    public init(interfaceType: Int) {
        switch interfaceType {
        case 1: self = .usb
        case 2: self = .wifi
        default: self = .unknown
        }
    }

    /// The companion-proxy interface type, never read.
    public static let companionProxyInterfaceType = 3
}

/// An iPhone or iPad attached to the Mac, as listed by `bpulse --devices`.
public struct IDeviceInfo: Sendable, Equatable, Identifiable {
    /// The device's UDID. Never printed or written to a capture; see ``redactedIdentifier``.
    public var id: String
    /// The name the owner gave the device (`DeviceName`).
    public var name: String?
    /// Model identifier such as `iPhone18,2` (`ProductType`).
    public var productType: String?
    /// OS version such as `27.0.1` (`ProductVersion`).
    public var productVersion: String?
    /// `iPhone`, `iPad`, `iPod` … (`DeviceClass`).
    public var deviceClass: String?
    /// Every interface the device is attached on, USB first.
    public var connections: [IDeviceConnection]
    /// Whether this Mac holds a pairing record for the device (`AMDeviceIsPaired`); `nil` when
    /// unknown.
    public var isPaired: Bool?

    public init(
        id: String,
        name: String? = nil,
        productType: String? = nil,
        productVersion: String? = nil,
        deviceClass: String? = nil,
        connections: [IDeviceConnection] = [],
        isPaired: Bool? = nil
    ) {
        self.id = id
        self.name = name
        self.productType = productType
        self.productVersion = productVersion
        self.deviceClass = deviceClass
        self.connections = connections
        self.isPaired = isPaired
    }

    /// Enough of the UDID to tell two devices apart in a terminal: its last four characters.
    public var redactedIdentifier: String {
        Self.redactedIdentifier(id)
    }

    public static func redactedIdentifier(_ identifier: String) -> String {
        let trimmed = identifier.trimmingCharacters(in: .whitespaces)
        guard trimmed.count >= 8 else { return "…" }
        return "…" + trimmed.suffix(4)
    }

    /// "iPadOS" for an iPad, "iOS" otherwise.
    public var osName: String {
        Self.osName(deviceClass: deviceClass)
    }

    static func osName(deviceClass: String?) -> String {
        deviceClass == "iPad" ? "iPadOS" : "iOS"
    }
}

/// The device list printed by `bpulse --devices` and used by `--device <n>`.
public enum IDeviceList {
    /// A stable order, so `--device <n>` in a later run means the device `--devices` printed as
    /// n: by identifier alone. The identifier is known without connecting to a device, so the
    /// order holds when a device's name can't be read, and `--device <n>` finds its device
    /// without connecting to the others. Arrival order changes from run to run.
    public static func sorted(_ devices: [IDeviceInfo]) -> [IDeviceInfo] {
        devices.sorted { $0.id < $1.id }
    }

    /// One numbered line per device, numbered from 1.
    public static func text(_ devices: [IDeviceInfo]) -> String {
        devices.enumerated().map { index, device in
            "\(index + 1). " + line(for: device)
        }
        .joined(separator: "\n")
    }

    /// "Nikita's iPhone · iPhone18,2 · iOS 27.0.1 · USB + Wi-Fi · ID …801C".
    public static func line(for device: IDeviceInfo) -> String {
        var parts = [nonEmpty(device.name) ?? "Unknown device"]
        if let model = nonEmpty(device.productType) { parts.append(model) }
        if let version = nonEmpty(device.productVersion) { parts.append("\(device.osName) \(version)") }
        if !device.connections.isEmpty {
            parts.append(device.connections.map(\.rawValue).joined(separator: " + "))
        }
        parts.append(identifierLabel(device.id))
        var line = parts.joined(separator: " · ")
        if device.isPaired == false { line += "\n   Not trusted: " + IDeviceProblem.trustAdvice }
        return line
    }

    /// "ID …801C": the identifier as the list and the device report show it.
    static func identifierLabel(_ identifier: String) -> String {
        "ID " + IDeviceInfo.redactedIdentifier(identifier)
    }

    static func nonEmpty(_ value: String?) -> String? {
        guard let value, !value.trimmingCharacters(in: .whitespaces).isEmpty else { return nil }
        return value
    }
}

/// A status code returned by a MobileDevice call (`mach_error_t`): 0 is success, errors are
/// `0xE80000xx`.
public struct IDeviceStatus: RawRepresentable, Sendable, Hashable, CustomStringConvertible {
    public var rawValue: UInt32

    public init(rawValue: UInt32) {
        self.rawValue = rawValue
    }

    /// From a C return value; the framework's codes don't fit a signed 32-bit integer.
    public init(code: Int32) {
        self.init(rawValue: UInt32(bitPattern: code))
    }

    public var isSuccess: Bool { rawValue == 0 }

    public static let success = IDeviceStatus(rawValue: 0)
    /// Used when a call reported success but returned nothing usable.
    public static let missingResult = IDeviceStatus(rawValue: 0xFFFF_FFFF)

    public static let noResources = IDeviceStatus(rawValue: 0xE800_0003)
    public static let notConnected = IDeviceStatus(rawValue: 0xE800_000B)
    public static let timedOut = IDeviceStatus(rawValue: 0xE800_000C)
    public static let passwordProtected = IDeviceStatus(rawValue: 0xE800_001A)
    public static let invalidHostID = IDeviceStatus(rawValue: 0xE800_001C)
    public static let sessionActive = IDeviceStatus(rawValue: 0xE800_001D)
    public static let sessionInactive = IDeviceStatus(rawValue: 0xE800_001E)
    public static let invalidService = IDeviceStatus(rawValue: 0xE800_0022)
    public static let missingPairRecord = IDeviceStatus(rawValue: 0xE800_0025)
    public static let sendMessageFailed = IDeviceStatus(rawValue: 0xE800_002D)
    public static let receiveMessageFailed = IDeviceStatus(rawValue: 0xE800_002E)
    public static let muxError = IDeviceStatus(rawValue: 0xE800_0035)
    public static let invalidPairRecord = IDeviceStatus(rawValue: 0xE800_005C)
    public static let serviceProhibited = IDeviceStatus(rawValue: 0xE800_005D)
    public static let pairingProhibited = IDeviceStatus(rawValue: 0xE800_0082)
    public static let deviceDisconnected = IDeviceStatus(rawValue: 0xE800_0084)
    public static let userDeniedPairing = IDeviceStatus(rawValue: 0xE800_0095)
    public static let pairingDialogPending = IDeviceStatus(rawValue: 0xE800_0096)

    /// The framework's names for the codes a battery read can meet.
    static let names: [IDeviceStatus: String] = [
        .noResources: "kAMDNoResourcesError",
        .notConnected: "kAMDNotConnectedError",
        .timedOut: "kAMDTimeOutError",
        .passwordProtected: "kAMDPasswordProtectedError",
        .invalidHostID: "kAMDInvalidHostIDError",
        .sessionActive: "kAMDSessionActiveError",
        .sessionInactive: "kAMDSessionInactiveError",
        .invalidService: "kAMDInvalidServiceError",
        .missingPairRecord: "kAMDMissingPairRecordError",
        .sendMessageFailed: "kAMDSendMessageError",
        .receiveMessageFailed: "kAMDReceiveMessageError",
        .muxError: "kAMDMuxError",
        .invalidPairRecord: "kAMDInvalidPairRecordError",
        .serviceProhibited: "kAMDServiceProhibitedError",
        .pairingProhibited: "kAMDPairingProhibitedError",
        .deviceDisconnected: "kAMDDeviceDisconnectedError",
        .userDeniedPairing: "kAMDUserDeniedPairingError",
        .pairingDialogPending: "kAMDPairingDialogResponsePendingError",
    ]

    public var name: String? { Self.names[self] }

    /// "0xE800001A kAMDPasswordProtectedError", or "0x0" for success.
    public var description: String {
        let hex = "0x" + String(rawValue, radix: 16, uppercase: true)
        return name.map { hex + " " + $0 } ?? hex
    }

    /// Codes meaning the device doesn't trust this Mac (yet).
    static let trustProblems: Set<IDeviceStatus> = [
        .invalidHostID, .missingPairRecord, .invalidPairRecord, .userDeniedPairing, .pairingDialogPending,
        .pairingProhibited,
    ]
}
