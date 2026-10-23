import Foundation

/// What the app knows about one iPhone or iPad in this session: memory only, never written.
public struct IDeviceSession: Sendable, Equatable {
    /// The interfaces of the last list that found the device; `[]` means not attached.
    public var connections: [IDeviceConnection] = []
    /// When a list last found the device.
    public var listedAt: Date?
    /// From this session's latest capture, even one without a battery (lockdown answers before
    /// a session, so an untrusted device still has a name and a model).
    public var identity: IDeviceIdentity?
    /// This session's latest successful read.
    public var battery: IDeviceBattery?
    public var readAt: Date?
    /// The interface that read went over (the capture's `Connection`).
    public var readConnection: IDeviceConnection?
    /// The latest USB termination of an iPhone or iPad that no arrival followed within the debounce.
    /// IOKit doesn't say which device left, so every session gets it.
    public var usbTerminatedAt: Date?
    /// The latest read attempt, successful or not.
    public var lastAttempt: Date?
    /// Why the latest attempt failed; `nil` after a success.
    public var problem: IDeviceProblem?
    public var consecutiveFailures = 0
    public var isReading = false
    /// A capture from this session is in memory (Copy Report).
    public var hasCapture = false

    public init() {}
}

/// When the app reads an iPhone or iPad by itself. Wi-Fi is never read automatically: those reads
/// are slow, wake the device's radio and are unverified; only Refresh and Check Again read it.
public enum IDeviceReadPolicy {
    /// While battery history is recorded: under ``HistoryPolicy/maximumGap``, so charging curves
    /// draw as lines.
    public static let backgroundInterval: TimeInterval = 5 * 60
    /// While the device's page is on screen.
    public static let visibleInterval: TimeInterval = 60
    /// The quick retries after a failure: the user usually unlocks or taps Trust right after
    /// plugging in.
    public static let retryDelays: [TimeInterval] = [20, 60]
    /// USB events closer together than this lead to one list.
    public static let attachDebounce: TimeInterval = 1.5
    /// usbmuxd can register a device a moment after IOKit reports it: a list that disagrees
    /// with a USB event is confirmed by another one this much later.
    public static let confirmDelay: TimeInterval = 5
    /// A Devices page lists again when the last list is older than this.
    public static let listMaxAge: TimeInterval = 60
    /// A Wi-Fi attachment seen in a list counts as connected this long; there is no detach event.
    public static let wifiPresenceLifetime: TimeInterval = 10 * 60

    /// When the next automatic read of this device is due, or nil for none.
    ///
    /// Only a device on USB is read by itself, and never while a read is running. The first
    /// read is due at once. After a failure come the quick retries; then a retryable problem
    /// follows the cadence of a successful read: every minute while the page is visible, every
    /// 5 minutes while history is recorded, otherwise never.
    public static func nextRead(
        _ session: IDeviceSession, isVisible: Bool, recordsHistory: Bool, now: Date
    ) -> Date? {
        guard !session.isReading, IDeviceRoster.connection(of: session, now: now) == .usb else { return nil }
        guard let lastAttempt = session.lastAttempt else { return .distantPast }
        let cadence = isVisible ? visibleInterval : (recordsHistory ? backgroundInterval : nil)
        if let problem = session.problem {
            let failures = max(1, session.consecutiveFailures)
            if failures <= retryDelays.count { return lastAttempt.addingTimeInterval(retryDelays[failures - 1]) }
            guard isRetryable(problem) else { return nil }
        }
        return cadence.map { lastAttempt.addingTimeInterval($0) }
    }

    /// Locked, unreachable, session, relay and transport failures (except time-outs): yes.
    /// notTrusted and noBattery: no (only the quick retries). A time-out stalls the monitor
    /// instead, until the user acts.
    public static func isRetryable(_ problem: IDeviceProblem) -> Bool {
        switch problem {
        case .notTrusted, .noBattery: false
        case .locked: true
        case .unreachable(let status), .sessionFailed(let status), .relayUnavailable(let status),
            .transportFailed(let status):
            status != .timedOut
        }
    }

    /// The earliest time anything automatic happens: a due read or a Wi-Fi sighting expiring.
    public static func nextWake(
        _ sessions: [DeviceKey: IDeviceSession], visible: DeviceKey?, recordsHistory: Bool, now: Date
    ) -> Date? {
        var wake: Date?
        func consider(_ date: Date?) {
            guard let date else { return }
            wake = wake.map { min($0, date) } ?? date
        }
        for (key, session) in sessions {
            consider(nextRead(session, isVisible: key == visible, recordsHistory: recordsHistory, now: now))
            consider(IDeviceRoster.sightingExpiry(of: session, now: now))
        }
        return wake
    }
}

/// One row of the Devices section and the model of its page.
public struct IDeviceEntry: Sendable, Equatable, Identifiable {
    public var id: DeviceKey
    public var isRemembered: Bool
    public var name: String?
    public var deviceClass: String?
    public var productType: String?
    public var osVersion: String?
    /// "iOS" or "iPadOS".
    public var osName: String
    /// `nil` = not connected.
    public var connection: IDeviceConnection?
    /// This session's, else the remembered one.
    public var battery: IDeviceBattery?
    /// This session's read, else the remembered device's last read.
    public var readAt: Date?
    public var lastSeen: Date?
    public var problem: IDeviceProblem?
    public var isReading: Bool
    public var hasCapture: Bool
}

/// Which devices the Devices section shows, and how.
public enum IDeviceRoster {
    /// The connection a device's row and page show, from the newest evidence: USB while
    /// ``isOnUSB(_:)``, else Wi-Fi, then an unknown interface, seen by the latest list or a read
    /// after it less than ``IDeviceReadPolicy/wifiPresenceLifetime`` ago (Wi-Fi has no detach
    /// event). A device the latest list didn't find isn't connected.
    public static func connection(of session: IDeviceSession, now: Date) -> IDeviceConnection? {
        guard !session.connections.isEmpty else { return nil }
        if isOnUSB(session) { return .usb }
        let sightings = latestSightings(of: session)
        if let wifi = sightings.wifi, isFresh(wifi, now: now) { return .wifi }
        if let unknown = sightings.unknown, isFresh(unknown, now: now) { return .unknown }
        return nil
    }

    /// Whether the cable counts: the latest list has USB, and nothing after that list says the
    /// cable left. A USB termination says so; IOKit doesn't say which device left, so a list after
    /// the termination counts again. A successful read over another interface after the
    /// termination says so too, and one over USB after it counts like a list. On a tie the
    /// termination or the read came last: both follow a list.
    public static func isOnUSB(_ session: IDeviceSession) -> Bool {
        guard session.connections.contains(.usb) else { return false }
        guard let terminatedAt = session.usbTerminatedAt else { return true }
        var seen = session.listedAt ?? .distantPast
        var left = terminatedAt
        if let readAt = session.readAt, let read = session.readConnection, readAt >= terminatedAt {
            if read == .usb { seen = max(seen, readAt) } else { left = max(left, readAt) }
        }
        return seen > left
    }

    /// When the connection shown from a Wi-Fi or unknown sighting next changes because a sighting
    /// expires; `nil` on USB, when not connected, or when every sighting has expired.
    public static func sightingExpiry(of session: IDeviceSession, now: Date) -> Date? {
        guard !session.connections.isEmpty, !isOnUSB(session) else { return nil }
        let sightings = latestSightings(of: session)
        return [sightings.wifi, sightings.unknown]
            .compactMap { $0?.addingTimeInterval(IDeviceReadPolicy.wifiPresenceLifetime) }
            .filter { $0 > now }
            .min()
    }

    /// The newest Wi-Fi and unknown-interface sightings: the latest list's interfaces, and the
    /// interface of a successful read that came after that list.
    private static func latestSightings(of session: IDeviceSession) -> (wifi: Date?, unknown: Date?) {
        var wifi: Date?
        var unknown: Date?
        func saw(_ connection: IDeviceConnection, at date: Date) {
            switch connection {
            case .usb: break
            case .wifi: wifi = max(wifi ?? date, date)
            case .unknown: unknown = max(unknown ?? date, date)
            }
        }
        if let listedAt = session.listedAt {
            for connection in session.connections { saw(connection, at: listedAt) }
        }
        if let read = session.readConnection, let readAt = session.readAt,
            session.listedAt.map({ readAt >= $0 }) ?? true
        {
            saw(read, at: readAt)
        }
        return (wifi, unknown)
    }

    private static func isFresh(_ sighting: Date, now: Date) -> Bool {
        now.timeIntervalSince(sighting) < IDeviceReadPolicy.wifiPresenceLifetime
    }

    /// Remembered devices, plus devices that aren't remembered but have a read attempt this
    /// session (so an unknown Wi-Fi device or a USB device before its first read shows no
    /// nameless row), minus `hidden`. Sorted by name (localizedStandardCompare), then by key.
    public static func entries(
        remembered: [RememberedDevice], sessions: [DeviceKey: IDeviceSession],
        hidden: Set<DeviceKey>, now: Date
    ) -> [IDeviceEntry] {
        var entries: [IDeviceEntry] = []
        var rememberedKeys: Set<DeviceKey> = []
        for device in remembered where !hidden.contains(device.id) && rememberedKeys.insert(device.id).inserted {
            let session = sessions[device.id]
            let identity = session?.identity
            let deviceClass = identity?.deviceClass ?? device.deviceClass
            entries.append(
                IDeviceEntry(
                    id: device.id,
                    isRemembered: true,
                    name: identity?.name ?? device.name,
                    deviceClass: deviceClass,
                    productType: identity?.productType ?? device.productType,
                    osVersion: identity?.osVersion ?? device.osVersion,
                    osName: IDeviceInfo.osName(deviceClass: deviceClass),
                    connection: session.flatMap { connection(of: $0, now: now) },
                    battery: session?.battery ?? device.battery,
                    readAt: session?.readAt ?? device.lastRead,
                    lastSeen: device.lastSeen,
                    problem: session?.problem,
                    isReading: session?.isReading ?? false,
                    hasCapture: session?.hasCapture ?? false
                ))
        }
        for (key, session) in sessions
        where !rememberedKeys.contains(key) && !hidden.contains(key) && session.lastAttempt != nil {
            guard let connection = connection(of: session, now: now) else { continue }
            let identity = session.identity ?? IDeviceIdentity()
            entries.append(
                IDeviceEntry(
                    id: key,
                    isRemembered: false,
                    name: identity.name,
                    deviceClass: identity.deviceClass,
                    productType: identity.productType,
                    osVersion: identity.osVersion,
                    osName: identity.osName,
                    connection: connection,
                    battery: session.battery,
                    readAt: session.readAt,
                    lastSeen: session.listedAt,
                    problem: session.problem,
                    isReading: session.isReading,
                    hasCapture: session.hasCapture
                ))
        }
        return entries.sorted(by: inDisplayOrder)
    }

    /// Named devices first, by name as Finder sorts it, then by key, so rows never jump when a
    /// device connects.
    static func inDisplayOrder(_ lhs: IDeviceEntry, _ rhs: IDeviceEntry) -> Bool {
        switch (lhs.name, rhs.name) {
        case (let left?, let right?):
            let order = left.localizedStandardCompare(right)
            return order == .orderedSame ? lhs.id.rawValue < rhs.id.rawValue : order == .orderedAscending
        case (.some, nil): return true
        case (nil, .some): return false
        case (nil, nil): return lhs.id.rawValue < rhs.id.rawValue
        }
    }
}
