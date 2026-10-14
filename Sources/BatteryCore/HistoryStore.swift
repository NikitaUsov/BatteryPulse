import Foundation

/// Battery history on disk: minute samples for the last ten days and a summary per day, as JSON
/// Lines files that are only appended to, except when old samples are trimmed.
public actor HistoryStore {
    public let directory: URL
    private var samplesURL: URL { directory.appendingPathComponent("samples.jsonl") }
    private var daysURL: URL { directory.appendingPathComponent("days.jsonl") }
    private var lastSample: HistorySample?
    private var lastTrim: Date?
    private var days: [String: HistoryDay]?

    public init(directory: URL) {
        self.directory = directory
    }

    /// `~/Library/Application Support/<bundle identifier>/History`.
    public static func defaultDirectory(bundleIdentifier: String?) -> URL {
        let base =
            FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        return base.appendingPathComponent(bundleIdentifier ?? "BatteryPulse").appendingPathComponent("History")
    }

    /// Records `sample` if ``HistoryPolicy`` says it adds something; returns whether it did.
    @discardableResult
    public func record(_ sample: HistorySample) throws -> Bool {
        if lastSample == nil { lastSample = try readSamples().last }
        guard HistoryPolicy.shouldRecord(sample, after: lastSample) else { return false }
        try append(sample, to: samplesURL)
        lastSample = sample
        if lastTrim.map({ sample.time.timeIntervalSince($0) > 60 * 60 }) ?? true {
            try trim(before: sample.time.addingTimeInterval(-HistoryPolicy.retention))
            lastTrim = sample.time
        }
        return true
    }

    /// Saves the day's summary when it differs from what is stored for that day.
    public func record(_ day: HistoryDay) throws {
        var days = try loadDays()
        guard days[day.day] != day else { return }
        days[day.day] = day
        self.days = days
        try append(day, to: daysURL)
    }

    public func samples(since start: Date) throws -> [HistorySample] {
        try readSamples().filter { $0.time >= start }
    }

    /// One summary per day, oldest first.
    public func dailySummaries() throws -> [HistoryDay] {
        try loadDays().values.sorted { $0.day < $1.day }
    }

    public func clear() throws {
        for url in [samplesURL, daysURL] where FileManager.default.fileExists(atPath: url.path) {
            try FileManager.default.removeItem(at: url)
        }
        lastSample = nil
        days = [:]
    }

    // MARK: - Files

    private func append(_ value: some Encodable, to url: URL) throws {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        var line = try encoder.encode(value)
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

    /// Reads a JSON Lines file, skipping lines that don't decode (a write cut short by a crash).
    private func readLines<T: Decodable>(_ type: T.Type, from url: URL) throws -> [T] {
        guard FileManager.default.fileExists(atPath: url.path) else { return [] }
        let data = try Data(contentsOf: url)
        let decoder = JSONDecoder()
        return data.split(separator: 0x0A).compactMap { try? decoder.decode(T.self, from: Data($0)) }
    }

    private func readSamples() throws -> [HistorySample] {
        try readLines(HistorySample.self, from: samplesURL).sorted { $0.time < $1.time }
    }

    private func loadDays() throws -> [String: HistoryDay] {
        if let days { return days }
        // Later lines for the same day replace earlier ones.
        var loaded: [String: HistoryDay] = [:]
        for day in try readLines(HistoryDay.self, from: daysURL) { loaded[day.day] = day }
        days = loaded
        return loaded
    }

    /// Drops samples older than `cutoff`, rewriting the file atomically.
    private func trim(before cutoff: Date) throws {
        let samples = try readSamples()
        guard let first = samples.first, first.time < cutoff else { return }
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        var data = Data()
        for sample in samples where sample.time >= cutoff {
            data.append(try encoder.encode(sample))
            data.append(0x0A)
        }
        try data.write(to: samplesURL, options: .atomic)
    }
}
