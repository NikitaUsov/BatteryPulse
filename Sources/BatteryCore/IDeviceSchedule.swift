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
            if !session.connections.isEmpty, !session.connections.contains(.usb), let listedAt = session.listedAt {
                let expiry = listedAt.addingTimeInterval(wifiPresenceLifetime)
                if expiry > now { consider(expiry) }
            }
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
    /// USB beats Wi-Fi; a Wi-Fi sighting older than wifiPresenceLifetime doesn't count.
    public static func connection(of session: IDeviceSession, now: Date) -> IDeviceConnection? {
        if session.connections.contains(.usb) { return .usb }
        guard let listedAt = session.listedAt,
            now.timeIntervalSince(listedAt) < IDeviceReadPolicy.wifiPresenceLifetime
        else { return nil }
        if session.connections.contains(.wifi) { return .wifi }
        return session.connections.isEmpty ? nil : .unknown
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
