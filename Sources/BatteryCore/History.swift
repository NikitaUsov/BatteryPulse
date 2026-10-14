import Foundation

/// One recorded moment of the battery. Stored one per line as compact JSON.
public struct HistorySample: Sendable, Equatable, Codable {
    public var time: Date
    public var percent: Double?
    public var state: ChargeState
    public var isExternalPowerConnected: Bool?
    /// Into the battery: positive while charging, negative while discharging.
    public var batteryWatts: Double?
    public var systemLoadWatts: Double?
    public var temperatureCelsius: Double?

    public init(
        time: Date, percent: Double?, state: ChargeState, isExternalPowerConnected: Bool? = nil,
        batteryWatts: Double? = nil, systemLoadWatts: Double? = nil, temperatureCelsius: Double? = nil
    ) {
        self.time = time
        self.percent = percent
        self.state = state
        self.isExternalPowerConnected = isExternalPowerConnected
        self.batteryWatts = batteryWatts
        self.systemLoadWatts = systemLoadWatts
        self.temperatureCelsius = temperatureCelsius
    }

    public init(_ snapshot: BatterySnapshot, at time: Date) {
        self.init(
            time: time,
            percent: snapshot.chargePercent,
            state: snapshot.chargeState,
            isExternalPowerConnected: snapshot.isExternalPowerConnected,
            batteryWatts: snapshot.batteryPowerWatts.map { ($0 * 100).rounded() / 100 },
            systemLoadWatts: snapshot.systemLoadWatts.map { ($0 * 100).rounded() / 100 },
            temperatureCelsius: snapshot.temperatureCelsius.map { ($0 * 10).rounded() / 10 }
        )
    }

    // Short keys and whole seconds keep a day of minute samples around 100 KB.
    enum CodingKeys: String, CodingKey {
        case time = "t", percent = "p", state = "s", isExternalPowerConnected = "x"
        case batteryWatts = "b", systemLoadWatts = "l", temperatureCelsius = "c"
    }

    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        time = Date(timeIntervalSince1970: try c.decode(Double.self, forKey: .time))
        percent = try c.decodeIfPresent(Double.self, forKey: .percent)
        state = try c.decodeIfPresent(ChargeState.self, forKey: .state) ?? .unknown
        isExternalPowerConnected = try c.decodeIfPresent(Bool.self, forKey: .isExternalPowerConnected)
        batteryWatts = try c.decodeIfPresent(Double.self, forKey: .batteryWatts)
        systemLoadWatts = try c.decodeIfPresent(Double.self, forKey: .systemLoadWatts)
        temperatureCelsius = try c.decodeIfPresent(Double.self, forKey: .temperatureCelsius)
    }

    public func encode(to encoder: any Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(time.timeIntervalSince1970.rounded(), forKey: .time)
        try c.encodeIfPresent(percent, forKey: .percent)
        try c.encode(state, forKey: .state)
        try c.encodeIfPresent(isExternalPowerConnected, forKey: .isExternalPowerConnected)
        try c.encodeIfPresent(batteryWatts, forKey: .batteryWatts)
        try c.encodeIfPresent(systemLoadWatts, forKey: .systemLoadWatts)
        try c.encodeIfPresent(temperatureCelsius, forKey: .temperatureCelsius)
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

    /// "2026-10-14" for `date` in `calendar`'s time zone.
    public static func key(for date: Date, calendar: Calendar = .current) -> String {
        let c = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", c.year ?? 0, c.month ?? 0, c.day ?? 0)
    }

    /// Noon of the day, for plotting.
    public func date(calendar: Calendar = .current) -> Date? {
        let parts = day.split(separator: "-").compactMap { Int($0) }
        guard parts.count == 3 else { return nil }
        return calendar.date(from: DateComponents(year: parts[0], month: parts[1], day: parts[2], hour: 12))
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
        guard let last else { return true }
        let elapsed = sample.time.timeIntervalSince(last.time)
        if elapsed >= interval || elapsed < 0 { return true }
        let changed =
            sample.state != last.state || sample.isExternalPowerConnected != last.isExternalPowerConnected
            || abs((sample.percent ?? 0) - (last.percent ?? 0)) >= 1
        return changed && elapsed >= 10
    }
}

/// Figures for a stretch of history.
public struct HistoryStatistics: Sendable, Equatable {
    /// Average drop in charge per hour while on battery.
    public var averageDrainPercentPerHour: Double?
    public var timeOnBattery: TimeInterval
    /// Energy the battery delivered while on battery, in watt-hours.
    public var energyFromBatteryWattHours: Double
    /// Times the Mac started charging.
    public var chargingSessions: Int

    public init(samples: [HistorySample]) {
        var drop = 0.0
        var onBattery: TimeInterval = 0
        var energy = 0.0
        var sessions = 0
        for (previous, sample) in zip(samples, samples.dropFirst()) {
            if sample.state == .charging, previous.state != .charging { sessions += 1 }
            let elapsed = sample.time.timeIntervalSince(previous.time)
            guard elapsed > 0, elapsed <= HistoryPolicy.maximumGap,
                previous.state == .discharging, sample.state == .discharging
            else { continue }
            onBattery += elapsed
            if let before = previous.percent, let after = sample.percent { drop += max(0, before - after) }
            if let watts = previous.batteryWatts, watts < 0 { energy += -watts * elapsed / 3600 }
        }
        averageDrainPercentPerHour = onBattery >= 15 * 60 ? drop / (onBattery / 3600) : nil
        timeOnBattery = onBattery
        energyFromBatteryWattHours = energy
        chargingSessions = sessions
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
