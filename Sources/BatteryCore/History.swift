import Foundation

/// Why a sample was taken outside the regular minute, so a gap before it can be explained.
public enum HistoryEvent: String, Sendable, Codable {
    /// The first sample after BatteryPulse started: before it, the app wasn't running.
    case launch
    /// The first sample after the Mac woke: before it, the Mac slept.
    case wake
}

/// One recorded moment of the battery. Stored one per line as compact JSON.
public struct HistorySample: Sendable, Equatable, Codable {
    public var time: Date
    public var event: HistoryEvent?
    public var percent: Double?
    public var state: ChargeState
    public var isExternalPowerConnected: Bool?
    /// Into the battery: positive while charging, negative while discharging.
    public var batteryWatts: Double?
    public var systemLoadWatts: Double?
    public var temperatureCelsius: Double?
    /// The gauge's remaining and full-charge capacity, for rates that don't depend on the
    /// whole-number percentage.
    public var remainingMAh: Int?
    public var fullChargeMAh: Int?

    public init(
        time: Date, event: HistoryEvent? = nil, percent: Double?, state: ChargeState,
        isExternalPowerConnected: Bool? = nil, batteryWatts: Double? = nil, systemLoadWatts: Double? = nil,
        temperatureCelsius: Double? = nil, remainingMAh: Int? = nil, fullChargeMAh: Int? = nil
    ) {
        self.time = time
        self.event = event
        self.percent = percent
        self.state = state
        self.isExternalPowerConnected = isExternalPowerConnected
        self.batteryWatts = batteryWatts
        self.systemLoadWatts = systemLoadWatts
        self.temperatureCelsius = temperatureCelsius
        self.remainingMAh = remainingMAh
        self.fullChargeMAh = fullChargeMAh
    }

    public init(_ snapshot: BatterySnapshot, at time: Date, event: HistoryEvent? = nil) {
        self.init(
            time: time,
            event: event,
            percent: snapshot.chargePercent,
            state: snapshot.chargeState,
            isExternalPowerConnected: snapshot.isExternalPowerConnected,
            batteryWatts: snapshot.batteryPowerWatts.map { ($0 * 100).rounded() / 100 },
            systemLoadWatts: snapshot.systemLoadWatts.map { ($0 * 100).rounded() / 100 },
            temperatureCelsius: snapshot.temperatureCelsius.map { ($0 * 10).rounded() / 10 },
            remainingMAh: snapshot.currentCapacityMAh,
            fullChargeMAh: snapshot.fullChargeCapacityMAh
        )
    }

    /// On battery: by the external-power flag, or by the charge state when that is missing.
    public var isOnBattery: Bool {
        isExternalPowerConnected.map { !$0 } ?? (state == .discharging)
    }

    // Short keys and whole seconds keep a day of minute samples around 150 KB.
    enum CodingKeys: String, CodingKey {
        case time = "t", event = "e", percent = "p", state = "s", isExternalPowerConnected = "x"
        case batteryWatts = "b", systemLoadWatts = "l", temperatureCelsius = "c"
        case remainingMAh = "r", fullChargeMAh = "f"
    }

    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        time = Date(timeIntervalSince1970: try c.decode(Double.self, forKey: .time))
        event = try? c.decodeIfPresent(HistoryEvent.self, forKey: .event)
        percent = try c.decodeIfPresent(Double.self, forKey: .percent)
        state = (try? c.decodeIfPresent(ChargeState.self, forKey: .state)) ?? .unknown
        isExternalPowerConnected = try c.decodeIfPresent(Bool.self, forKey: .isExternalPowerConnected)
        batteryWatts = try c.decodeIfPresent(Double.self, forKey: .batteryWatts)
        systemLoadWatts = try c.decodeIfPresent(Double.self, forKey: .systemLoadWatts)
        temperatureCelsius = try c.decodeIfPresent(Double.self, forKey: .temperatureCelsius)
        remainingMAh = try c.decodeIfPresent(Int.self, forKey: .remainingMAh)
        fullChargeMAh = try c.decodeIfPresent(Int.self, forKey: .fullChargeMAh)
    }

    public func encode(to encoder: any Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(time.timeIntervalSince1970.rounded(), forKey: .time)
        try c.encodeIfPresent(event, forKey: .event)
        try c.encodeIfPresent(percent, forKey: .percent)
        try c.encode(state, forKey: .state)
        try c.encodeIfPresent(isExternalPowerConnected, forKey: .isExternalPowerConnected)
        try c.encodeIfPresent(batteryWatts, forKey: .batteryWatts)
        try c.encodeIfPresent(systemLoadWatts, forKey: .systemLoadWatts)
        try c.encodeIfPresent(temperatureCelsius, forKey: .temperatureCelsius)
        try c.encodeIfPresent(remainingMAh, forKey: .remainingMAh)
        try c.encodeIfPresent(fullChargeMAh, forKey: .fullChargeMAh)
    }
}

/// The battery's condition on one day, kept for good to show its aging.
public struct HistoryDay: Sendable, Equatable, Codable {
    /// Local calendar day, "2026-10-14".
    public var day: String
    public var healthPercent: Double?
    /// Unclamped ratio to design capacity (a new battery holds over 100 %).
    public var capacityToDesignPercent: Double?
    public var nominalChargeCapacityMAh: Int?
    public var fullChargeCapacityMAh: Int?
    public var cycleCount: Int?

    public init(
        day: String, healthPercent: Double? = nil, capacityToDesignPercent: Double? = nil,
        nominalChargeCapacityMAh: Int? = nil, fullChargeCapacityMAh: Int? = nil, cycleCount: Int? = nil
    ) {
        self.day = day
        self.healthPercent = healthPercent
        self.capacityToDesignPercent = capacityToDesignPercent
        self.nominalChargeCapacityMAh = nominalChargeCapacityMAh
        self.fullChargeCapacityMAh = fullChargeCapacityMAh
        self.cycleCount = cycleCount
    }

    public init(_ snapshot: BatterySnapshot, day: String) {
        self.init(
            day: day,
            healthPercent: snapshot.healthPercent.map { ($0 * 10).rounded() / 10 },
            capacityToDesignPercent: snapshot.capacityToDesignPercent.map { ($0 * 10).rounded() / 10 },
            nominalChargeCapacityMAh: snapshot.nominalChargeCapacityMAh,
            fullChargeCapacityMAh: snapshot.fullChargeCapacityMAh,
            cycleCount: snapshot.cycleCount
        )
    }

    /// "2026-10-14" for `date` in `calendar`'s time zone. The key is always a Gregorian date,
    /// whatever calendar the user has chosen, so stored keys stay comparable for good.
    public static func key(for date: Date, calendar: Calendar = .current) -> String {
        let c = gregorian(in: calendar.timeZone).dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", c.year ?? 0, c.month ?? 0, c.day ?? 0)
    }

    /// Noon of the day, for plotting.
    public func date(calendar: Calendar = .current) -> Date? {
        let parts = day.split(separator: "-").compactMap { Int($0) }
        guard parts.count == 3 else { return nil }
        return Self.gregorian(in: calendar.timeZone).date(
            from: DateComponents(year: parts[0], month: parts[1], day: parts[2], hour: 12))
    }

    static func gregorian(in timeZone: TimeZone) -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        return calendar
    }
}

/// When to write a sample: about once a minute, plus right away when something changes.
public enum HistoryPolicy {
    public static let interval: TimeInterval = 60
    /// Minute samples are kept this long; daily summaries are kept for good.
    public static let retention: TimeInterval = 10 * 24 * 60 * 60
    /// A longer silence means the Mac slept or the app wasn't running: no line across it.
    public static let maximumGap: TimeInterval = 10 * 60

    public static func shouldRecord(_ sample: HistorySample, after last: HistorySample?) -> Bool {
        guard let last, sample.event == nil else { return true }
        let elapsed = sample.time.timeIntervalSince(last.time)
        if elapsed >= interval || elapsed < 0 { return true }
        let changed =
            sample.state != last.state || sample.isExternalPowerConnected != last.isExternalPowerConnected
            || abs((sample.percent ?? 0) - (last.percent ?? 0)) >= 1
        return changed && elapsed >= 10
    }
}

/// Figures for a stretch of history. Intervals longer than ``HistoryPolicy/maximumGap`` (sleep,
/// or BatteryPulse not running) count for nothing.
public struct HistoryStatistics: Sendable, Equatable {
    /// Average drop in charge per hour while on battery; `nil` until there is enough to go on
    /// (``minimumDrainTime`` on battery and ``minimumDrainPercent`` used), because the whole-number
    /// percentage makes short stretches misleading.
    public var averageDrainPercentPerHour: Double?
    public var timeOnBattery: TimeInterval
    /// Energy the battery delivered, in watt-hours, including any drawn while plugged in.
    public var energyFromBatteryWattHours: Double
    /// Times the Mac was plugged in; an unplug shorter than ``sessionMergeGap`` doesn't start a
    /// new session, and a held charge (Optimized Charging) doesn't either.
    public var chargingSessions: Int

    public static let minimumDrainTime: TimeInterval = 30 * 60
    public static let minimumDrainPercent = 3.0
    public static let sessionMergeGap: TimeInterval = 2 * 60

    public init(samples: [HistorySample]) {
        var onBattery: TimeInterval = 0
        var drained = 0.0
        var energy = 0.0
        var sessions = 0
        var lastUnplug: Date?
        // The current unplugged run: where it started and where it has got to.
        var runStart: HistorySample?
        var runEnd: HistorySample?

        func closeRun() {
            if let first = runStart?.percent, let last = runEnd?.percent { drained += first - last }
            runStart = nil
            runEnd = nil
        }

        for (previous, sample) in zip(samples, samples.dropFirst()) {
            // Plug-ins, including across a gap (plugged in while asleep).
            if previous.isOnBattery, !sample.isOnBattery {
                let merged = lastUnplug.map { sample.time.timeIntervalSince($0) < Self.sessionMergeGap } ?? false
                if !merged { sessions += 1 }
            } else if !previous.isOnBattery, sample.isOnBattery {
                lastUnplug = sample.time
            }

            let elapsed = sample.time.timeIntervalSince(previous.time)
            guard elapsed > 0, elapsed <= HistoryPolicy.maximumGap else {
                closeRun()
                continue
            }
            // Trapezoid rule over the power out of the battery.
            if let before = previous.batteryWatts, let after = sample.batteryWatts {
                energy += (max(0, -before) + max(0, -after)) / 2 * elapsed / 3600
            }
            if previous.isOnBattery, sample.isOnBattery {
                onBattery += elapsed
                if runStart == nil { runStart = previous }
                runEnd = sample
            } else {
                closeRun()
            }
        }
        closeRun()

        let enough = onBattery >= Self.minimumDrainTime && drained >= Self.minimumDrainPercent
        averageDrainPercentPerHour = enough ? max(0, drained) / (onBattery / 3600) : nil
        timeOnBattery = onBattery
        energyFromBatteryWattHours = energy
        chargingSessions = sessions
    }
}

/// A stretch on the power adapter, shaded behind the charge line.
public struct HistorySpan: Sendable, Equatable, Identifiable {
    public enum Kind: Sendable, Equatable {
        case charging
        /// Plugged in but not charging: full, or the charge held by macOS.
        case pluggedIn
    }

    public var start: Date
    public var end: Date
    public var kind: Kind
    public var id: Date { start }

    public init(start: Date, end: Date, kind: Kind) {
        self.start = start
        self.end = end
        self.kind = kind
    }

    /// Spans from raw samples (not chart buckets), never across a gap in the record.
    public static func spans(from samples: [HistorySample]) -> [HistorySpan] {
        var spans: [HistorySpan] = []
        for (previous, sample) in zip(samples, samples.dropFirst()) {
            let elapsed = sample.time.timeIntervalSince(previous.time)
            guard !previous.isOnBattery, elapsed > 0, elapsed <= HistoryPolicy.maximumGap else { continue }
            let kind: Kind = previous.state == .charging ? .charging : .pluggedIn
            if let last = spans.last, last.kind == kind, last.end == previous.time {
                spans[spans.count - 1].end = sample.time
            } else {
                spans.append(HistorySpan(start: previous.time, end: sample.time, kind: kind))
            }
        }
        return spans
    }
}

/// Samples prepared for a chart: averaged into buckets and split where the record has gaps.
public struct HistoryPoint: Sendable, Equatable, Identifiable {
    public var time: Date
    public var percent: Double?
    public var batteryWatts: Double?
    public var systemLoadWatts: Double?
    public var temperatureCelsius: Double?
    public var state: ChargeState
    /// Consecutive points share a segment; a new one starts after a gap.
    public var segment: Int

    public var id: Date { time }

    /// The point closest to `date` in time-sorted `points`, found by binary search.
    public static func nearest(in points: [HistoryPoint], to date: Date) -> HistoryPoint? {
        var low = 0
        var high = points.count
        while low < high {
            let middle = (low + high) / 2
            if points[middle].time < date { low = middle + 1 } else { high = middle }
        }
        let candidates = [low - 1, low].filter { points.indices.contains($0) }.map { points[$0] }
        return candidates.min { abs($0.time.timeIntervalSince(date)) < abs($1.time.timeIntervalSince(date)) }
    }

    /// Averages samples into `bucket`-long slots (none for the 24-hour view of minute samples),
    /// and starts a new segment after a gap longer than ``HistoryPolicy/maximumGap``.
    public static func points(from samples: [HistorySample], bucket: TimeInterval? = nil) -> [HistoryPoint] {
        var groups: [[HistorySample]] = []
        for sample in samples {
            if let bucket, let first = groups.last?.first,
                floor(first.time.timeIntervalSince1970 / bucket) == floor(sample.time.timeIntervalSince1970 / bucket)
            {
                groups[groups.count - 1].append(sample)
            } else {
                groups.append([sample])
            }
        }
        var points: [HistoryPoint] = []
        var segment = 0
        var previousSample: Date?
        for group in groups {
            guard let first = group.first, let last = group.last else { continue }
            // Compare real samples, not bucket midpoints, so buckets alone never split a line.
            if let previousSample, first.time.timeIntervalSince(previousSample) > HistoryPolicy.maximumGap {
                segment += 1
            }
            previousSample = last.time
            func mean(_ values: [Double?]) -> Double? {
                let present = values.compactMap { $0 }
                return present.isEmpty ? nil : present.reduce(0, +) / Double(present.count)
            }
            let middle = Date(
                timeIntervalSince1970: (first.time.timeIntervalSince1970 + last.time.timeIntervalSince1970) / 2)
            points.append(
                HistoryPoint(
                    time: middle,
                    percent: mean(group.map(\.percent)),
                    batteryWatts: mean(group.map(\.batteryWatts)),
                    systemLoadWatts: mean(group.map(\.systemLoadWatts)),
                    temperatureCelsius: mean(group.map(\.temperatureCelsius)),
                    state: last.state,
                    segment: segment
                ))
        }
        return points
    }
}
