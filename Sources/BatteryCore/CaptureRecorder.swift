import Foundation

/// The parts of a raw capture that describe the charging state, compared between readings to
/// find the moments worth keeping (`bpulse --record`). Live values (voltage, current, capacity,
/// temperatures, gauge timestamps, the SMC) are left out, so they never trigger a capture.
public struct ChargeStateFingerprint: Equatable, Sendable {
    /// Path → normalized value. A path is the capture's own key path, dot-separated, with array
    /// indices in brackets (`AppleSmartBattery.IORegistryEntryChildren[1].ChargerData.NotChargingReason`).
    public let values: [String: String]

    public init(_ reading: BatteryReading) {
        let roots: PropertyDictionary = [
            BatteryReading.CaptureKey.smartBattery: .dictionary(reading.smartBattery),
            BatteryReading.CaptureKey.powerSource: .dictionary(reading.powerSource),
            BatteryReading.CaptureKey.adapterDetails: .dictionary(reading.adapterDetails),
        ]
        var values: [String: String] = [:]
        for path in Self.watchedPaths {
            var value: PropertyValue? = .dictionary(roots)
            for key in path.split(separator: ".") {
                value = value?.dictionaryValue?[String(key)]
            }
            if let text = value.flatMap(Self.normalized) { values[path] = text }
        }
        for root in [BatteryReading.CaptureKey.smartBattery, BatteryReading.CaptureKey.powerSource] {
            if let value = roots[root] { Self.collectWatchedNames(in: value, path: root, key: root, into: &values) }
        }
        for key in reading.powerSource.keys {
            let path = BatteryReading.CaptureKey.powerSource + "." + key
            if values[path] == nil { values[path] = Self.present }
        }
        self.values = values
    }

    /// The paths whose values differ, sorted by path; a path missing on one side reads "absent".
    public func changes(from old: ChargeStateFingerprint) -> [Change] {
        Set(values.keys).union(old.values.keys).sorted().compactMap { path in
            let before = old.values[path] ?? Self.absent
            let after = values[path] ?? Self.absent
            return before == after ? nil : Change(path: path, old: before, new: after)
        }
    }

    public struct Change: Equatable, Sendable, CustomStringConvertible {
        public let path: String
        public let old: String
        public let new: String

        /// "AppleSmartBattery.IsCharging: true → false"
        public var description: String { "\(path): \(old) → \(new)" }
    }

    /// Always compared, where present; never demoted (see ``CaptureRecorder``).
    static let watchedPaths: Set<String> = [
        "AppleSmartBattery.ExternalConnected",
        "AppleSmartBattery.AppleRawExternalConnected",
        "AppleSmartBattery.IsCharging",
        "AppleSmartBattery.FullyCharged",
        "AppleSmartBattery.ChargerData.IsCharging",
        "AppleSmartBattery.BatteryData.FullyCharged",
        "AppleSmartBattery.PowerDistribution.IPDChargingAllowed",
        "PowerSource.Power Source State",
        "PowerSource.Is Charging",
        "PowerSource.Is Charged",
        "PowerSource.Is Finishing Charge",
        "PowerSource.Optimized Battery Charging Engaged",
        "PowerSource.LPM Active",
        "AdapterDetails.Watts",
    ]

    /// Scalar keys anywhere below `AppleSmartBattery` (its children included) and `PowerSource`
    /// whose name contains one of these (case-insensitive) are compared too, so a key that a new
    /// macOS adds for the charge limit is caught without knowing its name.
    static let watchedNameParts = ["reason", "inhibit", "limit", "hold"]

    /// Counters that match ``watchedNameParts`` but change continuously.
    static let ignoredKeys: Set<String> = ["TimeChargingThermallyLimited"]

    /// The value of a top-level `PowerSource` key that is only compared by its presence.
    static let present = "present"
    static let absent = "absent"

    /// Adds every scalar below `value` whose key matches ``watchedNameParts``. An array's items
    /// count as values of the array's key; data, arrays and dictionaries are never compared
    /// themselves, only walked into.
    private static func collectWatchedNames(
        in value: PropertyValue, path: String, key: String, into values: inout [String: String]
    ) {
        switch value {
        case .dictionary(let dictionary):
            for (childKey, child) in dictionary {
                collectWatchedNames(in: child, path: path + "." + childKey, key: childKey, into: &values)
            }
        case .array(let items):
            for (index, item) in items.enumerated() {
                collectWatchedNames(in: item, path: path + "[\(index)]", key: key, into: &values)
            }
        default:
            let name = key.lowercased()
            guard !ignoredKeys.contains(key), watchedNameParts.contains(where: name.contains),
                let text = normalized(value)
            else { return }
            values[path] = text
        }
    }

    /// The same text on every platform: `PropertyValue` keeps booleans and 0/1 integers apart.
    static func normalized(_ value: PropertyValue) -> String? {
        switch value {
        case .bool(let flag): flag ? "true" : "false"
        case .int(let number): String(number)
        case .double(let number): String(describing: number)
        case .string(let text): CaptureRecorder.singleLine(text)
        case .data, .array, .dictionary: nil
        }
    }
}

/// Decides which raw captures `bpulse --record` keeps and formats its timeline. Pure: the
/// caller reads the battery, passes the time and writes the files.
///
/// A capture is written at the start, just before and after every change of the charging state
/// (``ChargeStateFingerprint``) and after ``defaultHeartbeat`` without one. Changes closer than
/// `minimumSpacing` to the last capture are deferred, and a path found by name (not one of the
/// watched paths) that has caused `flapLimit` captures without a watched path changing no longer
/// causes any, so a key that keeps flipping can't use up `maxCaptures` before the moment that
/// matters. The timeline lists every reading and every change regardless.
public struct CaptureRecorder: Sendable {
    public enum Reason: String, Sendable {
        case start, before, change, heartbeat
    }

    public struct Capture: Equatable, Sendable {
        /// 1-based, in writing order.
        public let number: Int
        public let reason: Reason
        /// When `reading` was taken.
        public let date: Date
        public let reading: BatteryReading

        /// ``CaptureRecorder/fileName(number:reason:date:)``.
        public var fileName: String { CaptureRecorder.fileName(number: number, reason: reason, date: date) }
    }

    public struct Step: Sendable {
        /// None, one, or two (`before` and `change`).
        public let captures: [Capture]
        /// Against the previous reading.
        public let changes: [ChargeStateFingerprint.Change]
        /// No trailing newline.
        public let timelineRow: String
        /// One console line ("21:30:05  85%  AppleSmartBattery.IsCharging: true → false
        /// (captures 0004, 0005)"), or nil when the step has no changes, captures or notices.
        public let summary: String?
        /// Each is given once, such as the capture limit.
        public let notices: [String]
        /// The timeline limit was reached.
        public let isFinished: Bool
    }

    public static let sampleInterval: Duration = .seconds(5)
    /// About 4.5 MB at about 45 KB a capture.
    public static let defaultMaxCaptures = 100
    /// About 69 hours at 5 s, about 7 MB.
    public static let defaultMaxTimelineRows = 50_000
    public static let defaultHeartbeat: TimeInterval = 15 * 60
    public static let defaultMinimumSpacing: TimeInterval = 30
    public static let defaultFlapLimit = 3
    public static let timelineFileName = "timeline.tsv"
    public static let timelineHeader = [
        "time", "percent", "state", "external", "not_charging_reason", "remaining_mAh", "full_mAh", "current_mA",
        "voltage_mV", "charger_request_mA", "system_in_W", "temp_C", "gauge_updated", "captures", "changes",
    ].joined(separator: "\t")

    let maxCaptures: Int
    let maxTimelineRows: Int
    let heartbeat: TimeInterval
    let minimumSpacing: TimeInterval
    let flapLimit: Int
    /// The `time` and `gauge_updated` columns: `2026-10-15T21:30:05+03:00`.
    let timeStyle: Date.ISO8601FormatStyle

    public init(
        maxCaptures: Int = CaptureRecorder.defaultMaxCaptures,
        maxTimelineRows: Int = CaptureRecorder.defaultMaxTimelineRows,
        heartbeat: TimeInterval = CaptureRecorder.defaultHeartbeat,
        minimumSpacing: TimeInterval = CaptureRecorder.defaultMinimumSpacing,
        flapLimit: Int = CaptureRecorder.defaultFlapLimit,
        timeZone: TimeZone = .current
    ) {
        self.maxCaptures = maxCaptures
        self.maxTimelineRows = maxTimelineRows
        self.heartbeat = heartbeat
        self.minimumSpacing = minimumSpacing
        self.flapLimit = flapLimit
        timeStyle = Date.ISO8601FormatStyle(timeZoneSeparator: .colon, timeZone: timeZone)
    }

    public private(set) var capturesWritten = 0

    private struct Moment: Sendable {
        let reading: BatteryReading
        let fingerprint: ChargeStateFingerprint
        let date: Date
    }

    /// The last reading passed in (a missing reading doesn't replace it).
    private var previous: Moment?
    private var previousWasWritten = false
    /// The reading of the last capture written for its own moment (not a `before`).
    private var lastWritten: Moment?
    /// Captures caused per path found by name, counting only captures no watched path made due.
    private var capturesPerPath: [String: Int] = [:]
    /// Paths that no longer make a capture due.
    private var demotedPaths: Set<String> = []
    private var rowsWritten = 0
    private var gaveCaptureLimitNotice = false

    /// `reading` is nil when the provider returned nothing this time.
    public mutating func record(_ reading: BatteryReading?, at date: Date) -> Step {
        rowsWritten += 1
        let isFinished = rowsWritten >= maxTimelineRows
        let time = timeStyle.format(date)
        guard let reading else {
            let row = [time] + Array(repeating: Self.unknown, count: 13) + ["no reading"]
            return Step(
                captures: [], changes: [], timelineRow: row.joined(separator: "\t"), summary: nil, notices: [],
                isFinished: isFinished)
        }

        let current = Moment(reading: reading, fingerprint: ChargeStateFingerprint(reading), date: date)
        let changes = previous.map { current.fingerprint.changes(from: $0.fingerprint) } ?? []
        var due: [(reason: Reason, moment: Moment)] = []
        var changesSinceWritten: [ChargeStateFingerprint.Change] = []
        var isDeferred = false
        if let lastWritten {
            changesSinceWritten = relevant(current.fingerprint.changes(from: lastWritten.fingerprint))
            let elapsed = date.timeIntervalSince(lastWritten.date)
            if changesSinceWritten.isEmpty {
                if elapsed >= heartbeat { due.append((.heartbeat, current)) }
            } else if elapsed >= minimumSpacing {
                // The previous reading was the last moment before the change.
                if let previous, !previousWasWritten,
                    !relevant(current.fingerprint.changes(from: previous.fingerprint)).isEmpty
                {
                    due.append((.before, previous))
                }
                due.append((.change, current))
            } else {
                // Past the capture limit nothing follows, so nothing is deferred either.
                isDeferred = capturesWritten < maxCaptures
            }
        } else {
            due.append((.start, current))
        }
        // With fewer slots than captures due, the `before` capture goes first.
        due = Array(due.suffix(max(0, maxCaptures - capturesWritten)))

        var captures: [Capture] = []
        var notices: [String] = []
        for (reason, moment) in due {
            capturesWritten += 1
            captures.append(
                Capture(number: capturesWritten, reason: reason, date: moment.date, reading: moment.reading))
        }
        let wroteCurrent = captures.contains { $0.reason != .before }
        if wroteCurrent { lastWritten = current }
        // A capture that a watched path made due would have been written anyway, so the paths found
        // by name that changed with it (a plug-in changes the charger's reasons) don't count.
        let isCausedByName = !changesSinceWritten.contains { ChargeStateFingerprint.watchedPaths.contains($0.path) }
        if isCausedByName, captures.contains(where: { $0.reason == .change }) {
            for change in changesSinceWritten {
                capturesPerPath[change.path, default: 0] += 1
                if capturesPerPath[change.path] == flapLimit {
                    demotedPaths.insert(change.path)
                    notices.append(
                        "\(change.path) keeps changing; it no longer triggers captures (the timeline still lists it).")
                }
            }
        }
        if capturesWritten >= maxCaptures, !gaveCaptureLimitNotice {
            gaveCaptureLimitNotice = true
            notices.append("Reached \(maxCaptures) captures; only the timeline is written from now on.")
        }
        previous = current
        previousWasWritten = wroteCurrent

        var changeText = changes.map(\.description).joined(separator: "; ")
        if isDeferred { changeText += (changeText.isEmpty ? "" : " ") + "(capture deferred)" }
        let numbers = captures.map { Self.paddedNumber($0.number) }
        let snapshot = reading.snapshot
        let percent = snapshot.chargePercent.flatMap { Int(exactly: $0.rounded()) }.map(String.init)
        let fields: [String?] = [
            time,
            percent,
            snapshot.chargeState.rawValue,
            snapshot.isExternalPowerConnected.map { $0 ? "true" : "false" },
            snapshot.notChargingReason.map(String.init),
            snapshot.currentCapacityMAh.map(String.init),
            snapshot.fullChargeCapacityMAh.map(String.init),
            snapshot.amperageMA.map(String.init),
            snapshot.voltageMV.map(String.init),
            snapshot.chargingCurrentMA.map(String.init),
            snapshot.systemPowerInWatts.map(Self.oneDecimal),
            snapshot.temperatureCelsius.map(Self.oneDecimal),
            snapshot.gaugeUpdatedAt.map(timeStyle.format),
            numbers.isEmpty ? nil : numbers.joined(separator: ","),
            changeText.isEmpty ? nil : changeText,
        ]
        let row = fields.map { $0.map(Self.singleLine).flatMap { $0.isEmpty ? nil : $0 } ?? Self.unknown }

        var summary: String?
        if !changes.isEmpty || !captures.isEmpty || !notices.isEmpty {
            var body = changeText.isEmpty ? captures.map(\.reason.rawValue).joined(separator: ", ") : changeText
            if !numbers.isEmpty {
                let label = numbers.count == 1 ? "capture" : "captures"
                body += (body.isEmpty ? "" : " ") + "(\(label) \(numbers.joined(separator: ", ")))"
            }
            // The clock part of the `time` column.
            let clock = time.split(separator: "T").last.map { String($0.prefix(8)) } ?? time
            summary = [clock, percent.map { $0 + "%" } ?? Self.unknown, body].filter { !$0.isEmpty }
                .joined(separator: "  ")
        }
        return Step(
            captures: captures, changes: changes, timelineRow: row.joined(separator: "\t"), summary: summary,
            notices: notices, isFinished: isFinished)
    }

    /// "0004-20261015T183005Z-change.plist": sorts in order; UTC, so no time zone or DST
    /// ambiguity.
    public static func fileName(number: Int, reason: Reason, date: Date) -> String {
        "\(paddedNumber(number))-\(fileTimeStyle.format(date))-\(reason.rawValue).plist"
    }

    /// `20261015T183005Z`.
    private static let fileTimeStyle = Date.ISO8601FormatStyle(dateSeparator: .omitted, timeSeparator: .omitted)
    private static let unknown = "-"

    /// The changes that can make a capture due: all but the demoted paths.
    private func relevant(_ changes: [ChargeStateFingerprint.Change]) -> [ChargeStateFingerprint.Change] {
        changes.filter { !demotedPaths.contains($0.path) }
    }

    private static func paddedNumber(_ number: Int) -> String {
        let digits = String(number)
        return String(repeating: "0", count: max(0, 4 - digits.count)) + digits
    }

    /// A `.` decimal separator whatever the locale, as C formats it.
    private static func oneDecimal(_ value: Double) -> String {
        BatteryReport.fixed(value, 1)
    }

    /// Tabs and line breaks become spaces, so a value stays in its column and row.
    static func singleLine(_ text: String) -> String {
        String(text.map { $0 == "\t" || $0.isNewline ? " " : $0 })
    }
}
