import Foundation

/// The `com.apple.mobile.diagnostics_relay` lockdown service: plist requests, plist replies.
///
/// A request `{Request: IORegistry, EntryClass: <class>}` is answered with
/// `{Status: Success, Diagnostics: {IORegistry: {<the entry's properties>}}}`, or with `Status`
/// `Failure` (no such entry) or `UnknownRequest`. Replies carry no request ID, so a connection
/// is never reused after a send or receive failure. `{Request: Goodbye}` ends the conversation.
public enum DiagnosticsRelay {
    public static let service = "com.apple.mobile.diagnostics_relay"
    /// The lockdown domain with the charge iOS shows (`BatteryCurrentCapacity`).
    public static let batteryDomain = "com.apple.mobile.battery"

    /// Battery entry classes, in order: the gauge's own class, then its superclass, which every
    /// power source registers under.
    public static let batteryClasses = ["AppleSmartBattery", "IOPMPowerSource"]
    /// Entries asked for after the battery. iOS 27 moved the temperature (and on iPad the design
    /// and nominal capacity) from the battery to the pack; banks and charger data are recorded
    /// to see what else moved.
    public static let childClasses = ["AppleSmartBatteryPack", "AppleSmartBatteryBank", "AppleChargerData"]
    public static let packClass = "AppleSmartBatteryPack"

    public static func registryRequest(entryClass: String) -> PropertyDictionary {
        ["Request": .string("IORegistry"), "EntryClass": .string(entryClass)]
    }

    public static let goodbye: PropertyDictionary = ["Request": .string("Goodbye")]

    /// `Success`, `Failure` or `UnknownRequest`.
    public static func status(of reply: PropertyDictionary) -> String? {
        reply["Status"]?.stringValue
    }

    /// The registry entry in a successful `IORegistry` reply.
    public static func registryEntry(in reply: PropertyDictionary) -> PropertyDictionary? {
        guard status(of: reply) == "Success" else { return nil }
        return reply["Diagnostics"]?.dictionaryValue?["IORegistry"]?.dictionaryValue
    }
}

/// Everything one battery read of an iPhone or iPad returned, kept verbatim: identity values,
/// the lockdown battery domain, each diagnostics relay request with its reply, and the status of
/// every call. `bpulse --device <n> --raw` writes it, redacted, in the fixture format
/// (``rawCapture``).
public struct IDeviceCapture: Sendable, Equatable {
    /// Lockdown identity values (`DeviceName`, `DeviceClass`, `ProductType`, `ProductVersion`,
    /// `BuildVersion`, `HardwareModel`), plus `Connection` (`USB`/`Wi-Fi`) and `UniqueDeviceID`.
    public var device: PropertyDictionary
    /// `AMDeviceIsPaired`: whether this Mac holds a pairing record for the device.
    public var isPaired: Bool?
    /// The `com.apple.mobile.battery` domain (`BatteryCurrentCapacity`, `BatteryIsCharging`, …).
    public var lockdownBattery: PropertyDictionary
    /// Diagnostics relay requests and replies, in order.
    public var exchanges: [Exchange]
    /// Calls made and their status, in order. Sends and receives appear only when they fail.
    public var steps: [Step]

    public init(
        device: PropertyDictionary = [:],
        isPaired: Bool? = nil,
        lockdownBattery: PropertyDictionary = [:],
        exchanges: [Exchange] = [],
        steps: [Step] = []
    ) {
        self.device = device
        self.isPaired = isPaired
        self.lockdownBattery = lockdownBattery
        self.exchanges = exchanges
        self.steps = steps
    }

    public struct Exchange: Sendable, Equatable {
        public var request: PropertyDictionary
        /// `nil` when sending or receiving failed.
        public var reply: PropertyDictionary?

        public init(request: PropertyDictionary, reply: PropertyDictionary?) {
            self.request = request
            self.reply = reply
        }
    }

    public struct Step: Sendable, Equatable {
        public enum Call: String, Sendable, CaseIterable {
            case connect = "Connect"
            case validatePairing = "ValidatePairing"
            case startSession = "StartSession"
            case startService = "StartService"
            case send = "Send"
            case receive = "Receive"
            case closeService = "CloseService"
            case stopSession = "StopSession"
            case disconnect = "Disconnect"
        }

        public var call: Call
        public var status: IDeviceStatus

        public init(_ call: Call, _ status: IDeviceStatus) {
            self.call = call
            self.status = status
        }
    }

    /// The status of the first call of this kind, if it was made.
    public func status(of call: Step.Call) -> IDeviceStatus? {
        steps.first { $0.call == call }?.status
    }

    /// A registry entry and the class it was asked for by.
    public struct RegistryEntry: Sendable, Equatable {
        public var className: String
        public var properties: PropertyDictionary
    }

    /// The entry a successful reply returned for this class.
    public func registryEntry(forClass className: String) -> PropertyDictionary? {
        for exchange in exchanges where exchange.request["EntryClass"]?.stringValue == className {
            if let reply = exchange.reply, let entry = DiagnosticsRelay.registryEntry(in: reply) { return entry }
        }
        return nil
    }

    /// The battery's entry: `AppleSmartBattery`, else `IOPMPowerSource`.
    public var batteryEntry: RegistryEntry? {
        for className in DiagnosticsRelay.batteryClasses {
            if let properties = registryEntry(forClass: className) {
                return RegistryEntry(className: className, properties: properties)
            }
        }
        return nil
    }

    /// The connection the read went over.
    public var connection: IDeviceConnection? {
        device[Key.connection]?.stringValue.flatMap(IDeviceConnection.init(rawValue:))
    }
}

// MARK: - Problems

/// Why a read produced no battery, worded for the person holding the device.
public enum IDeviceProblem: Sendable, Equatable, CustomStringConvertible {
    /// The Mac couldn't connect to the device's lockdown service.
    case unreachable(IDeviceStatus)
    /// No pairing record, or the device rejected it. Never fixed by pairing calls of our own:
    /// the person taps Trust on the device, as for Finder.
    case notTrusted(IDeviceStatus?)
    /// Passcode-protected and locked.
    case locked
    case sessionFailed(IDeviceStatus)
    /// The diagnostics relay didn't start.
    case relayUnavailable(IDeviceStatus)
    /// A send or receive failed before the battery entry arrived.
    case transportFailed(IDeviceStatus)
    /// Every reply came back without a battery entry.
    case noBattery

    public static let trustAdvice = "Unlock the device and tap Trust."

    public var description: String {
        switch self {
        case .unreachable(let status):
            "Couldn't connect to the device (\(status)). Check the cable; over Wi-Fi, unlock the device and "
                + "keep it on the same network as this Mac."
        case .notTrusted(let status):
            "The device doesn't trust this Mac" + (status.map { " (\($0))" } ?? "") + ". " + Self.trustAdvice
                + " If no prompt appears, connect it by cable."
        case .locked:
            "The device is locked. Unlock it and try again."
        case .sessionFailed(let status):
            "Couldn't start a session with the device (\(status)). " + Self.trustAdvice
        case .relayUnavailable(let status):
            "The device didn't start its diagnostics service (\(status))."
        case .transportFailed(let status):
            "The device stopped answering (\(status)). Try again; prefer a cable to Wi-Fi."
        case .noBattery:
            "The device answered, but reported no battery."
        }
    }
}

extension IDeviceCapture {
    /// Why this read has no battery entry, or `nil` when it has one.
    public var problem: IDeviceProblem? {
        guard let connect = status(of: .connect) else { return .unreachable(.missingResult) }
        guard connect.isSuccess else { return .unreachable(connect) }

        let session = status(of: .startSession) ?? .missingResult
        if !session.isSuccess, session != .sessionActive {
            for status in [session, status(of: .validatePairing)].compactMap({ $0 }) {
                if status == .passwordProtected { return .locked }
                if IDeviceStatus.trustProblems.contains(status) { return .notTrusted(status) }
            }
            return isPaired == false ? .notTrusted(nil) : .sessionFailed(session)
        }

        let service = status(of: .startService) ?? .missingResult
        guard service.isSuccess else {
            return service == .passwordProtected ? .locked : .relayUnavailable(service)
        }
        if batteryEntry != nil { return nil }
        if let failure = steps.first(where: { ($0.call == .send || $0.call == .receive) && !$0.status.isSuccess }) {
            return .transportFailed(failure.status)
        }
        return .noBattery
    }
}

// MARK: - Raw capture

extension IDeviceCapture {
    /// Top-level keys of the capture format. `Calls` holds `{Call, Status}` entries;
    /// `DiagnosticsRelay` holds `{Request, Reply}` entries, `Reply` missing when it failed.
    public enum Key {
        public static let device = "Device"
        public static let isPaired = "IsPaired"
        public static let lockdownBattery = "LockdownBattery"
        public static let relay = "DiagnosticsRelay"
        public static let calls = "Calls"
        public static let request = "Request"
        public static let reply = "Reply"
        public static let call = "Call"
        public static let status = "Status"
        public static let connection = "Connection"
        public static let identifier = "UniqueDeviceID"
        public static let name = "DeviceName"
    }

    /// Keys that identify the device or its owner, replaced at any depth along with serial
    /// numbers. `DeviceName` is only replaced in ``Key/device``: the battery entry's
    /// `DeviceName` names the gauge chip.
    static let identifyingKeys: Set<String> = [
        "UniqueDeviceID", "UniqueChipID", "UDID", "ECID", "WiFiAddress", "BluetoothAddress",
        "EthernetAddress", "IMEI", "MEID", "ICCID", "PhoneNumber",
        // A number that identifies the battery pack (iOS 27, AppleSmartBatteryPack).
        "UUID",
    ]

    public var rawCapture: PropertyDictionary {
        var capture: PropertyDictionary = [
            Key.device: .dictionary(device),
            Key.lockdownBattery: .dictionary(lockdownBattery),
            Key.relay: .array(
                exchanges.map { exchange in
                    var entry: PropertyDictionary = [Key.request: .dictionary(exchange.request)]
                    if let reply = exchange.reply { entry[Key.reply] = .dictionary(reply) }
                    return .dictionary(entry)
                }),
            Key.calls: .array(
                steps.map {
                    .dictionary([Key.call: .string($0.call.rawValue), Key.status: .int(Int64($0.status.rawValue))])
                }),
        ]
        if let isPaired { capture[Key.isPaired] = .bool(isPaired) }
        return capture
    }

    /// ``rawCapture`` without serial numbers, device identifiers or the device's name, safe to
    /// attach to a public bug report or commit as a fixture.
    public var redactedRawCapture: PropertyDictionary {
        var capture = BatteryReading.redactingSerialNumbers(in: rawCapture, alsoRedacting: Self.identifyingKeys)
        if var device = capture[Key.device]?.dictionaryValue, device[Key.name] != nil {
            device[Key.name] = .string(BatteryReading.redactedPlaceholder)
            capture[Key.device] = .dictionary(device)
        }
        return capture
    }

    /// Whether a raw capture is an iPhone/iPad capture rather than a Mac one.
    public static func isDeviceCapture(_ raw: PropertyDictionary) -> Bool {
        raw[Key.relay] != nil || raw[Key.calls] != nil
    }

    /// Re-reads a capture written from ``rawCapture``; `nil` if it isn't a device capture.
    /// Unknown calls are skipped.
    public init?(rawCapture raw: PropertyDictionary) {
        guard Self.isDeviceCapture(raw) else { return nil }
        self.init(
            device: raw[Key.device]?.dictionaryValue ?? [:],
            isPaired: raw[Key.isPaired]?.boolValue,
            lockdownBattery: raw[Key.lockdownBattery]?.dictionaryValue ?? [:],
            exchanges: (raw[Key.relay]?.arrayValue ?? []).compactMap(\.dictionaryValue).compactMap { entry in
                guard let request = entry[Key.request]?.dictionaryValue else { return nil }
                return Exchange(request: request, reply: entry[Key.reply]?.dictionaryValue)
            },
            steps: (raw[Key.calls]?.arrayValue ?? []).compactMap(\.dictionaryValue).compactMap { entry in
                guard let call = entry[Key.call]?.stringValue.flatMap(Step.Call.init(rawValue:)),
                    let code = entry[Key.status]?.intValue, let raw = UInt32(exactly: code)
                else { return nil }
                return Step(call, IDeviceStatus(rawValue: raw))
            }
        )
    }
}
