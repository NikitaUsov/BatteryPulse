// Summarizes BatteryPulse's `perf` log lines, as captured on a Mac with
//
//   log stream --level debug --style ndjson \
//     --predicate 'subsystem == "io.github.nikitausov.BatteryPulse" AND category == "perf"' > perf.ndjson
//
//   swift scripts/perf-stats.swift perf.ndjson
//
// It needs only Foundation, so it also runs on Linux. The app writes two kinds of line
// (App/Diagnostics.swift):
//   perf interval <name> ms=<duration> trigger=<trigger or ->
//   perf event <name> trigger=<trigger or ->
// and the script prints:
//   - per interval name and trigger: the count, and p50 and p95 in ms (nearest rank);
//   - per event name and trigger: the count;
//   - after the rows of a name with more than one trigger, the same over all of them, with the
//     trigger `(all)`: `read`'s four (full, live, cached, cached.slow) together compare with the
//     single `read -` of the builds before 0.6.2;
//   - per process: its reads, the reads before its first menuBarReady, its widget reloads, and the
//     reads of each notify burst. A burst is a run of `refresh trigger=notify` lines less than 1 s
//     apart; its reads are the `read` lines logged between the start of its first refresh and the
//     end of its last.
// Lines that aren't JSON, and messages that aren't perf lines, are skipped.
import Foundation

func fail(_ message: String) -> Never {
    FileHandle.standardError.write(Data("error: \(message)\n".utf8))
    exit(1)
}

/// The fields of one `log stream --style ndjson` entry that the summary uses.
struct LogEntry: Decodable {
    let eventMessage: String?
    let category: String?
    let processID: Int?
    let processImagePath: String?
    let timestamp: String?
}

/// One parsed perf line.
struct PerfLine {
    enum Kind { case interval, event }

    let kind: Kind
    let name: String
    let trigger: String
    /// The interval's duration; nil for an event.
    let milliseconds: Double?
    /// When the line was logged (an interval logs at its end), in seconds since 1970.
    let time: Double
    let processID: Int
    let image: String

    /// The interval's start, or the event's time.
    var start: Double { time - (milliseconds ?? 0) / 1000 }
}

/// Days from 1970-01-01 to a proleptic Gregorian date: the days-from-civil algorithm, which
/// counts in 400-year eras starting on March 1 so that February comes last.
func daysSince1970(year: Int, month: Int, day: Int) -> Int {
    let shiftedYear = month <= 2 ? year - 1 : year
    let era = (shiftedYear >= 0 ? shiftedYear : shiftedYear - 399) / 400
    let yearOfEra = shiftedYear - era * 400
    let dayOfYear = (153 * (month > 2 ? month - 3 : month + 9) + 2) / 5 + day - 1
    let dayOfEra = yearOfEra * 365 + yearOfEra / 4 - yearOfEra / 100 + dayOfYear
    return era * 146_097 + dayOfEra - 719_468
}

/// Parses `log`'s timestamp, such as `2026-10-29 10:00:00.123456+0300`, into seconds since 1970.
func parseTimestamp(_ text: String) -> Double? {
    let parts = text.split(separator: " ")
    guard parts.count == 2 else { return nil }
    let date = parts[0].split(separator: "-").compactMap { Int($0) }
    let clockAndZone = parts[1]
    guard date.count == 3,
        let zoneStart = clockAndZone.lastIndex(where: { $0 == "+" || $0 == "-" })
    else { return nil }
    let clock = clockAndZone[..<zoneStart].split(separator: ":")
    let zone = clockAndZone[clockAndZone.index(after: zoneStart)...]
    guard clock.count == 3, let hour = Int(clock[0]), let minute = Int(clock[1]), let second = Double(clock[2]),
        zone.count == 4, let zoneValue = Int(zone)
    else { return nil }
    let zoneSign = clockAndZone[zoneStart] == "-" ? -1 : 1
    let zoneSeconds = zoneSign * ((zoneValue / 100) * 3600 + (zoneValue % 100) * 60)
    let days = daysSince1970(year: date[0], month: date[1], day: date[2])
    return Double(days * 86_400 + hour * 3600 + minute * 60 - zoneSeconds) + second
}

/// Parses one entry's message, or returns nil when it isn't a perf line.
func parsePerfLine(_ entry: LogEntry) -> PerfLine? {
    guard let message = entry.eventMessage, entry.category == nil || entry.category == "perf",
        let processID = entry.processID, let stamp = entry.timestamp, let time = parseTimestamp(stamp)
    else { return nil }
    let words = message.split(separator: " ").map(String.init)
    guard words.count >= 3, words[0] == "perf" else { return nil }
    var fields: [String: String] = [:]
    for word in words.dropFirst(3) {
        guard let equals = word.firstIndex(of: "=") else { continue }
        fields[String(word[..<equals])] = String(word[word.index(after: equals)...])
    }
    let kind: PerfLine.Kind
    let milliseconds: Double?
    switch words[1] {
    case "interval":
        guard let value = fields["ms"].flatMap(Double.init) else { return nil }
        kind = .interval
        milliseconds = value
    case "event":
        kind = .event
        milliseconds = nil
    default:
        return nil
    }
    let image = entry.processImagePath?.split(separator: "/").last.map(String.init) ?? "?"
    return PerfLine(
        kind: kind, name: words[2], trigger: fields["trigger"] ?? "-", milliseconds: milliseconds, time: time,
        processID: processID, image: image)
}

/// The nearest-rank percentile of sorted values.
func percentile(_ sorted: [Double], _ fraction: Double) -> Double {
    let rank = Int((fraction * Double(sorted.count)).rounded(.up))
    return sorted[min(max(rank, 1), sorted.count) - 1]
}

/// Left-aligned columns, two spaces apart.
func table(_ rows: [[String]]) -> String {
    var widths: [Int] = []
    for row in rows {
        for (column, cell) in row.enumerated() {
            if column == widths.count { widths.append(0) }
            widths[column] = max(widths[column], cell.count)
        }
    }
    return rows.map { row in
        var line = ""
        for (column, cell) in row.enumerated() {
            line += cell
            if column < row.count - 1 { line += String(repeating: " ", count: widths[column] + 2 - cell.count) }
        }
        return line
    }.joined(separator: "\n")
}

/// The read counts of each notify burst of one process's lines, in time order.
func readsPerNotifyBurst(_ lines: [PerfLine]) -> [Int] {
    let refreshes = lines.filter { $0.kind == .interval && $0.name == "refresh" && $0.trigger == "notify" }
    var bursts: [(start: Double, end: Double)] = []
    for refresh in refreshes {
        if let last = bursts.last, refresh.time - last.end < 1 {
            bursts[bursts.count - 1] = (min(last.start, refresh.start), refresh.time)
        } else {
            bursts.append((refresh.start, refresh.time))
        }
    }
    let reads = lines.filter { $0.kind == .interval && $0.name == "read" }
    return bursts.map { burst in reads.filter { $0.time >= burst.start && $0.time <= burst.end }.count }
}

let arguments = Array(CommandLine.arguments.dropFirst())
guard arguments.count == 1 else { fail("usage: swift scripts/perf-stats.swift <log.ndjson>") }
guard let data = FileManager.default.contents(atPath: arguments[0]) else { fail("can't read \(arguments[0])") }

let decoder = JSONDecoder()
let lines = String(decoding: data, as: UTF8.self).split(whereSeparator: \.isNewline).compactMap { text in
    (try? decoder.decode(LogEntry.self, from: Data(text.utf8))).flatMap(parsePerfLine)
}.enumerated().sorted { ($0.element.time, $0.offset) < ($1.element.time, $1.offset) }.map(\.element)
guard !lines.isEmpty else { fail("no perf lines in \(arguments[0])") }

/// The lines of one name and trigger.
struct Group {
    let name: String
    let trigger: String
    let lines: [PerfLine]
}

/// The trigger of a name's total row.
let allTriggers = "(all)"

/// The lines of one kind, grouped by name and trigger, sorted by both. A name with more than one
/// trigger is followed by a group of all its lines, whose trigger is ``allTriggers``.
func groups(_ kind: PerfLine.Kind) -> [Group] {
    let grouped = Dictionary(grouping: lines.filter { $0.kind == kind }) { "\($0.name) \($0.trigger)" }
    let sorted = grouped.values.map { Group(name: $0[0].name, trigger: $0[0].trigger, lines: $0) }
        .sorted { ($0.name, $0.trigger) < ($1.name, $1.trigger) }
    var result: [Group] = []
    for (index, group) in sorted.enumerated() {
        result.append(group)
        guard index == sorted.count - 1 || sorted[index + 1].name != group.name else { continue }
        let ofName = sorted.filter { $0.name == group.name }
        if ofName.count > 1 {
            result.append(Group(name: group.name, trigger: allTriggers, lines: ofName.flatMap(\.lines)))
        }
    }
    return result
}

var intervalRows = [["name", "trigger", "count", "p50", "p95"]]
for group in groups(.interval) {
    let sorted = group.lines.compactMap(\.milliseconds).sorted()
    intervalRows.append([
        group.name, group.trigger, "\(sorted.count)", String(format: "%.3f", percentile(sorted, 0.5)),
        String(format: "%.3f", percentile(sorted, 0.95)),
    ])
}
var eventRows = [["name", "trigger", "count"]]
for group in groups(.event) {
    eventRows.append([group.name, group.trigger, "\(group.lines.count)"])
}

var processIDs: [Int] = []
for line in lines where !processIDs.contains(line.processID) {
    processIDs.append(line.processID)
}
var processRows = [["pid", "image", "reads", "reads before menuBarReady", "widget reloads", "reads per notify burst"]]
for processID in processIDs {
    let own = lines.filter { $0.processID == processID }
    let reads = own.filter { $0.kind == .interval && $0.name == "read" }
    let ready = own.first { $0.kind == .event && $0.name == "menuBarReady" }
    let readsBeforeReady = ready.map { ready in "\(reads.filter { $0.time < ready.time }.count)" } ?? "-"
    let reloads = own.filter { $0.kind == .event && $0.name == "widget.reload" }.count
    let bursts = readsPerNotifyBurst(own)
    processRows.append([
        "\(processID)", own[0].image, "\(reads.count)", readsBeforeReady, "\(reloads)",
        bursts.isEmpty ? "-" : bursts.map(String.init).joined(separator: " "),
    ])
}

print("intervals (ms)\n\(table(intervalRows))\n")
print("events\n\(table(eventRows))\n")
print("processes\n\(table(processRows))")
