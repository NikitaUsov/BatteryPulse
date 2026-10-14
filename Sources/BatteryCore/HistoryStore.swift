import Foundation

/// Battery history on disk, as JSON Lines:
/// - `samples/YYYY-MM-DD.jsonl`: minute samples, one file per UTC day, so a time zone change
///   can't mix days up. Old days are dropped by deleting their file; nothing is rewritten.
/// - `days.jsonl`: one summary per local day, kept for good.
public actor HistoryStore {
    public let directory: URL
    private var samplesDirectory: URL { directory.appendingPathComponent("samples") }
    private var daysURL: URL { directory.appendingPathComponent("days.jsonl") }
    /// The single file used before samples were split by day.
    private var legacySamplesURL: URL { directory.appendingPathComponent("samples.jsonl") }

    private var lastSample: HistorySample?
    private var hasLoadedLastSample = false
    private var prunedThrough: String?
    private var days: [String: HistoryDay]?
    /// What `days.jsonl` holds, to tell whether a summary changed enough to write right away.
    private var writtenDays: [String: HistoryDay] = [:]
    private var lastDaysWrite: Date?

    /// Capacities in mAh move by a few units every few minutes; a day's summary is saved at
    /// most this often unless its health or cycle count changed.
    public static let daysWriteInterval: TimeInterval = 60 * 60

    /// The current time, injectable for tests.
    private let now: @Sendable () -> Date

    public init(directory: URL, now: @escaping @Sendable () -> Date = { Date() }) {
        self.directory = directory
        self.now = now
    }

    /// `~/Library/Application Support/<bundle identifier>/History`.
    public static func defaultDirectory(bundleIdentifier: String?) -> URL {
        let base =
            FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        return base.appendingPathComponent(bundleIdentifier ?? "BatteryPulse").appendingPathComponent("History")
    }

    /// The UTC day a sample is filed under.
    static func fileDay(for date: Date) -> String {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC") ?? calendar.timeZone
        return HistoryDay.key(for: date, calendar: calendar)
    }

    // MARK: - Samples

    /// Records `sample` if ``HistoryPolicy`` says it adds something; returns whether it did.
    @discardableResult
    public func record(_ sample: HistorySample) throws -> Bool {
        try migrateLegacySamples()
        if !hasLoadedLastSample {
            lastSample = try latestSample()
            hasLoadedLastSample = true
        }
        guard HistoryPolicy.shouldRecord(sample, after: lastSample) else { return false }
        let day = Self.fileDay(for: sample.time)
        try append(sample, to: sampleURL(day))
        lastSample = sample
        if prunedThrough != day {
            // Relative to the clock as well as the sample, so a sample from a clock set far ahead
            // can't delete the real history.
            let reference = min(sample.time, now())
            try prune(before: Self.fileDay(for: reference.addingTimeInterval(-HistoryPolicy.retention)))
            prunedThrough = day
        }
        return true
    }

    /// Samples from `start` up to `end`, oldest first. Reads only the days in that range.
    public func samples(from start: Date, to end: Date = .distantFuture) throws -> [HistorySample] {
        try migrateLegacySamples()
        let first = Self.fileDay(for: start)
        let last = end == .distantFuture ? "9999-12-31" : Self.fileDay(for: end)
        return try sampleDays().filter { $0 >= first && $0 <= last }
            .flatMap { try readLines(HistorySample.self, from: sampleURL($0)) }
            .filter { $0.time >= start && $0.time <= end }
            .sorted { $0.time < $1.time }
    }

    public func samples(since start: Date) throws -> [HistorySample] {
        try samples(from: start)
    }

    private func sampleURL(_ day: String) -> URL {
        samplesDirectory.appendingPathComponent(day + ".jsonl")
    }

    /// Days with a sample file, oldest first.
    private func sampleDays() throws -> [String] {
        guard FileManager.default.fileExists(atPath: samplesDirectory.path) else { return [] }
        return try FileManager.default.contentsOfDirectory(atPath: samplesDirectory.path)
            .filter { $0.hasSuffix(".jsonl") }
            .map { String($0.dropLast(".jsonl".count)) }
            .filter { $0.count == 10 }
            .sorted()
    }

    /// The newest sample, ignoring days after tomorrow: those come from a clock that was set ahead.
    private func latestSample() throws -> HistorySample? {
        let latestPlausibleDay = Self.fileDay(for: now().addingTimeInterval(24 * 60 * 60))
        for day in try sampleDays().reversed() where day <= latestPlausibleDay {
            if let last = try readLines(HistorySample.self, from: sampleURL(day)).max(by: { $0.time < $1.time }) {
                return last
            }
        }
        return nil
    }

    /// The newest day files are always kept, however old: a single sample from a clock set far
    /// ahead (which moves the sample's date and `now` together) can't push the real ones out.
    static let keptDayFiles = Int(HistoryPolicy.retention / (24 * 60 * 60)) + 1

    /// Deletes the files of days before `day`, except the newest ``keptDayFiles``.
    private func prune(before day: String) throws {
        for old in try sampleDays().dropLast(Self.keptDayFiles) where old < day {
            try FileManager.default.removeItem(at: sampleURL(old))
        }
    }

    /// Splits the old single samples file into day files, once.
    private func migrateLegacySamples() throws {
        guard FileManager.default.fileExists(atPath: legacySamplesURL.path) else { return }
        let samples = try readLines(HistorySample.self, from: legacySamplesURL)
        try FileManager.default.createDirectory(at: samplesDirectory, withIntermediateDirectories: true)
        for (day, group) in Dictionary(grouping: samples, by: { Self.fileDay(for: $0.time) }) {
            try writeLines(group.sorted { $0.time < $1.time }, to: sampleURL(day))
        }
        try FileManager.default.removeItem(at: legacySamplesURL)
    }

    // MARK: - Daily summaries

    /// Keeps the day's summary. It is written right away for a new day or a change in health or
    /// cycle count, and otherwise at most every ``daysWriteInterval``.
    public func record(_ day: HistoryDay, at now: Date = Date()) throws {
        var days = try loadDays()
        guard days[day.day] != day else { return }
        days[day.day] = day
        self.days = days
        let written = writtenDays[day.day]
        let significant =
            written == nil || written?.healthPercent != day.healthPercent || written?.cycleCount != day.cycleCount
        let due = lastDaysWrite.map { now.timeIntervalSince($0) >= Self.daysWriteInterval || now < $0 } ?? true
        if significant || due {
            try writeDays(days)
            lastDaysWrite = now
        }
    }

    /// Writes any summary that is still only in memory.
    public func flush() throws {
        guard let days, days != writtenDays else { return }
        try writeDays(days)
    }

    /// One summary per day, oldest first.
    public func dailySummaries() throws -> [HistoryDay] {
        try loadDays().values.sorted { $0.day < $1.day }
    }

    private func loadDays() throws -> [String: HistoryDay] {
        if let days { return days }
        // Later lines for the same day replace earlier ones.
        var loaded: [String: HistoryDay] = [:]
        for day in try readLines(HistoryDay.self, from: daysURL) { loaded[day.day] = day }
        days = loaded
        writtenDays = loaded
        return loaded
    }

    /// Rewrites `days.jsonl` with one line per day, atomically.
    private func writeDays(_ days: [String: HistoryDay]) throws {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try writeLines(days.values.sorted { $0.day < $1.day }, to: daysURL)
        writtenDays = days
    }

    public func clear() throws {
        for url in [samplesDirectory, daysURL, legacySamplesURL] where FileManager.default.fileExists(atPath: url.path)
        {
            try FileManager.default.removeItem(at: url)
        }
        lastSample = nil
        hasLoadedLastSample = true
        prunedThrough = nil
        days = [:]
        writtenDays = [:]
    }

    // MARK: - Files

    private static func encoder() -> JSONEncoder {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        return encoder
    }

    private func append(_ value: some Encodable, to url: URL) throws {
        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        var line = try Self.encoder().encode(value)
        line.append(0x0A)
        if let handle = try? FileHandle(forUpdating: url) {
            defer { try? handle.close() }
            let end = try handle.seekToEnd()
            // A write cut short (power loss, crash) leaves a line without its newline; end it so
            // the new record isn't glued to it and lost too.
            if end > 0 {
                try handle.seek(toOffset: end - 1)
                if try handle.read(upToCount: 1) != Data([0x0A]) { line.insert(0x0A, at: 0) }
                try handle.seekToEnd()
            }
            try handle.write(contentsOf: line)
        } else {
            try line.write(to: url, options: .atomic)
        }
    }

    private func writeLines(_ values: [some Encodable], to url: URL) throws {
        let encoder = Self.encoder()
        var data = Data()
        for value in values {
            data.append(try encoder.encode(value))
            data.append(0x0A)
        }
        try data.write(to: url, options: .atomic)
    }

    /// Reads a JSON Lines file, skipping lines that don't decode (a write cut short by a crash).
    private func readLines<T: Decodable>(_ type: T.Type, from url: URL) throws -> [T] {
        guard FileManager.default.fileExists(atPath: url.path) else { return [] }
        let data = try Data(contentsOf: url)
        let decoder = JSONDecoder()
        return data.split(separator: 0x0A).compactMap { try? decoder.decode(T.self, from: Data($0)) }
    }
}
