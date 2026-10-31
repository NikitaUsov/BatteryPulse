import Foundation

/// The three files History can export.
public enum HistoryExportKind: String, Sendable, CaseIterable {
    /// The minute readings, as CSV.
    case samplesCSV
    /// The daily battery health, as CSV.
    case daysCSV
    /// Both lists in one JSON document.
    case json

    public var fileExtension: String { self == .json ? "json" : "csv" }

    /// The word in the file name.
    var fileNameWord: String {
        switch self {
        case .samplesCSV: "samples"
        case .daysCSV: "days"
        case .json: "history"
        }
    }

    var needsSamples: Bool { self != .daysCSV }
    var needsDays: Bool { self != .samplesCSV }
}

/// The separators of a CSV file. Both dialects quote like RFC 4180, end lines with CRLF and
/// start with a header row.
public struct CSVDialect: Sendable, Equatable {
    public var fieldSeparator: Character
    public var decimalSeparator: Character

    public init(fieldSeparator: Character, decimalSeparator: Character) {
        self.fieldSeparator = fieldSeparator
        self.decimalSeparator = decimalSeparator
    }

    /// RFC 4180: a comma between fields and a decimal point.
    public static let standard = CSVDialect(fieldSeparator: ",", decimalSeparator: ".")
    /// A semicolon between fields and a decimal comma: what spreadsheets open by double-click
    /// where the region writes decimals with a comma.
    public static let decimalComma = CSVDialect(fieldSeparator: ";", decimalSeparator: ",")

    /// The dialect spreadsheets in `locale`'s region expect.
    public static func preferred(for locale: Locale) -> CSVDialect {
        locale.decimalSeparator == "," ? .decimalComma : .standard
    }
}

/// What a history belongs to. It has no field for the owner's device name or any identifier:
/// exported files get shared.
public struct HistoryExportSource: Sendable, Equatable {
    public enum Kind: String, Sendable {
        case mac, iPhone, iPad
    }

    public var kind: Kind
    /// "iPhone18,2"; nil for the Mac.
    public var productType: String?
    /// The system's marketing name ("iPhone 17 Pro Max"), which can be localized; nil for the Mac.
    public var modelName: String?
    /// "27.0.1"; for a device, the version it had when it was last seen.
    public var osVersion: String?

    public init(kind: Kind, productType: String? = nil, modelName: String? = nil, osVersion: String? = nil) {
        self.kind = kind
        self.productType = productType
        self.modelName = modelName
        self.osVersion = osVersion
    }

    /// This Mac, with `ProcessInfo.processInfo.operatingSystemVersion`.
    public static func mac(_ version: OperatingSystemVersion?) -> HistoryExportSource {
        HistoryExportSource(kind: .mac, osVersion: version.map(versionString))
    }

    /// A remembered iPhone or iPad, from the fields its record keeps. It takes no name and no key.
    public static func device(
        deviceClass: String?, productType: String?, modelName: String?, osVersion: String?
    ) -> HistoryExportSource {
        HistoryExportSource(
            kind: deviceClass == "iPad" ? .iPad : .iPhone, productType: productType, modelName: modelName,
            osVersion: osVersion)
    }

    /// "27.0" or "27.0.1".
    static func versionString(_ version: OperatingSystemVersion) -> String {
        let parts =
            [version.majorVersion, version.minorVersion] + (version.patchVersion > 0 ? [version.patchVersion] : [])
        return parts.map(String.init).joined(separator: ".")
    }

    /// "Mac", "iPhone-17-Pro-Max": the model name when it is plain ASCII, with every run of
    /// other characters turned into one "-"; otherwise (a localized name, or none) the kind.
    public var fileNameComponent: String {
        guard kind != .mac else { return "Mac" }
        guard let modelName, modelName.unicodeScalars.allSatisfy(\.isASCII) else { return kind.rawValue }
        var result = ""
        var pendingDash = false
        for scalar in modelName.unicodeScalars {
            if CharacterSet.alphanumerics.contains(scalar) {
                if pendingDash, !result.isEmpty { result.append("-") }
                pendingDash = false
                result.unicodeScalars.append(scalar)
            } else {
                pendingDash = true
            }
        }
        return result.isEmpty ? kind.rawValue : result
    }
}

/// The envelope of a JSON export.
public struct HistoryExportInfo: Sendable, Equatable {
    public var exportedAt: Date
    /// "BatteryPulse 0.6.0 (12)", or "bpulse".
    public var generator: String?
    /// Unknown when bpulse reads a folder it was given.
    public var source: HistoryExportSource?

    public init(exportedAt: Date, generator: String?, source: HistoryExportSource?) {
        self.exportedAt = exportedAt
        self.generator = generator
        self.source = source
    }
}

/// History as CSV or JSON for spreadsheets and scripts. Numbers and times are written with
/// integer arithmetic: no locale, no grouping, an ASCII minus, the same bytes on every platform.
///
/// Compatibility: columns and keys are only ever appended. A rename, a removal or a change of
/// meaning bumps ``formatVersion`` and is called out in the release notes.
public enum HistoryExport {
    public static let formatName = "BatteryPulse history"
    public static let formatVersion = 1

    public static let sampleColumns = [
        "time", "localTime", "event", "chargePercent", "chargeState", "isExternalPowerConnected",
        "batteryWatts", "systemLoadWatts", "temperatureCelsius", "remainingMAh", "fullChargeMAh",
    ]
    public static let dayColumns = [
        "day", "healthPercent", "capacityToDesignPercent", "nominalChargeCapacityMAh", "fullChargeCapacityMAh",
        "cycleCount",
    ]
    /// Units of the keys that have one, sorted by key.
    public static let units: [(key: String, unit: String)] = [
        ("batteryWatts", "W"), ("capacityToDesignPercent", "%"), ("chargePercent", "%"),
        ("fullChargeCapacityMAh", "mAh"), ("fullChargeMAh", "mAh"), ("healthPercent", "%"),
        ("nominalChargeCapacityMAh", "mAh"), ("remainingMAh", "mAh"), ("systemLoadWatts", "W"),
        ("temperatureCelsius", "°C"),
    ]

    /// Fraction digits kept per column (trailing zeros are dropped).
    enum Digits {
        static let percent = 2
        static let watts = 2
        static let celsius = 1
        static let dayPercent = 1
    }

    /// The file. `dialect` applies to the CSV kinds only. Times are written in `timeZone`, with
    /// the offset each instant had there.
    public static func data(
        _ kind: HistoryExportKind, samples: [HistorySample], days: [HistoryDay], dialect: CSVDialect = .standard,
        info: HistoryExportInfo, timeZone: TimeZone
    ) -> Data {
        var buffer = ExportBuffer()
        switch kind {
        case .samplesCSV: samplesCSV(samples, dialect: dialect, timeZone: timeZone, to: &buffer)
        case .daysCSV: daysCSV(days, dialect: dialect, to: &buffer)
        case .json: json(samples: samples, days: days, info: info, timeZone: timeZone, to: &buffer)
        }
        return Data(buffer.bytes)
    }

    /// Reads everything `store` keeps that `kind` holds, then builds the file, off the caller's actor.
    @concurrent
    public static func data(
        _ kind: HistoryExportKind, from store: HistoryStore, dialect: CSVDialect = .standard,
        info: HistoryExportInfo, timeZone: TimeZone
    ) async throws -> Data {
        let samples = kind.needsSamples ? try await store.samples(from: .distantPast) : []
        let days = kind.needsDays ? try await store.dailySummaries() : []
        return data(kind, samples: samples, days: days, dialect: dialect, info: info, timeZone: timeZone)
    }

    /// "BatteryPulse-Mac-samples-2026-10-15.csv": the export's day in `timeZone`, a Gregorian date.
    public static func fileName(
        _ kind: HistoryExportKind, source: HistoryExportSource?, date: Date, timeZone: TimeZone
    ) -> String {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        let parts = [
            "BatteryPulse", source?.fileNameComponent ?? "History", kind.fileNameWord,
            HistoryDay.key(for: date, calendar: calendar),
        ]
        return parts.joined(separator: "-") + "." + kind.fileExtension
    }

    // MARK: - CSV

    static func samplesCSV(
        _ samples: [HistorySample], dialect: CSVDialect, timeZone: TimeZone, to buffer: inout ExportBuffer
    ) {
        let separator = dialect.fieldSeparator.asciiValue ?? 0x2C
        let decimal = dialect.decimalSeparator.asciiValue ?? 0x2E
        buffer.appendHeader(sampleColumns, separator: separator)
        for sample in samples {
            let offset = timeZone.secondsFromGMT(for: sample.time)
            buffer.appendTime(sample.time, offset: offset, iso: true)
            buffer.append(ascii: separator)
            buffer.appendTime(sample.time, offset: offset, iso: false)
            buffer.append(ascii: separator)
            if let event = sample.event { buffer.appendCSVField(event.rawValue, separator: separator) }
            buffer.append(ascii: separator)
            buffer.appendNumber(sample.percent, fractionDigits: Digits.percent, decimal: decimal)
            buffer.append(ascii: separator)
            buffer.appendCSVField(sample.state.rawValue, separator: separator)
            buffer.append(ascii: separator)
            if let connected = sample.isExternalPowerConnected { buffer.append(ascii: connected ? 0x31 : 0x30) }
            buffer.append(ascii: separator)
            buffer.appendNumber(sample.batteryWatts, fractionDigits: Digits.watts, decimal: decimal)
            buffer.append(ascii: separator)
            buffer.appendNumber(sample.systemLoadWatts, fractionDigits: Digits.watts, decimal: decimal)
            buffer.append(ascii: separator)
            buffer.appendNumber(sample.temperatureCelsius, fractionDigits: Digits.celsius, decimal: decimal)
            buffer.append(ascii: separator)
            if let value = sample.remainingMAh { buffer.appendInteger(value) }
            buffer.append(ascii: separator)
            if let value = sample.fullChargeMAh { buffer.appendInteger(value) }
            buffer.endRecord()
        }
    }

    static func daysCSV(_ days: [HistoryDay], dialect: CSVDialect, to buffer: inout ExportBuffer) {
        let separator = dialect.fieldSeparator.asciiValue ?? 0x2C
        let decimal = dialect.decimalSeparator.asciiValue ?? 0x2E
        buffer.appendHeader(dayColumns, separator: separator)
        for day in days {
            buffer.appendCSVField(day.day, separator: separator)
            buffer.append(ascii: separator)
            buffer.appendNumber(day.healthPercent, fractionDigits: Digits.dayPercent, decimal: decimal)
            buffer.append(ascii: separator)
            buffer.appendNumber(day.capacityToDesignPercent, fractionDigits: Digits.dayPercent, decimal: decimal)
            buffer.append(ascii: separator)
            if let value = day.nominalChargeCapacityMAh { buffer.appendInteger(value) }
            buffer.append(ascii: separator)
            if let value = day.fullChargeCapacityMAh { buffer.appendInteger(value) }
            buffer.append(ascii: separator)
            if let value = day.cycleCount { buffer.appendInteger(value) }
            buffer.endRecord()
        }
    }

    // MARK: - JSON

    static func json(
        samples: [HistorySample], days: [HistoryDay], info: HistoryExportInfo, timeZone: TimeZone,
        to buffer: inout ExportBuffer
    ) {
        let dot: UInt8 = 0x2E
        buffer.append("{\n  \"format\": ")
        buffer.appendJSONString(formatName)
        buffer.append(",\n  \"formatVersion\": ")
        buffer.appendInteger(formatVersion)
        buffer.append(",\n  \"exportedAt\": \"")
        buffer.appendTime(info.exportedAt, offset: timeZone.secondsFromGMT(for: info.exportedAt), iso: true)
        buffer.append("\",\n  \"generator\": ")
        buffer.appendJSONString(info.generator)
        buffer.append(",\n  \"source\": ")
        if let source = info.source {
            buffer.append("{\"kind\": ")
            buffer.appendJSONString(source.kind.rawValue)
            buffer.append(", \"productType\": ")
            buffer.appendJSONString(source.productType)
            buffer.append(", \"modelName\": ")
            buffer.appendJSONString(source.modelName)
            buffer.append(", \"osVersion\": ")
            buffer.appendJSONString(source.osVersion)
            buffer.append("}")
        } else {
            buffer.append("null")
        }
        buffer.append(",\n  \"units\": {")
        for (index, entry) in units.enumerated() {
            if index > 0 { buffer.append(", ") }
            buffer.appendJSONString(entry.key)
            buffer.append(": ")
            buffer.appendJSONString(entry.unit)
        }
        buffer.append("},\n  \"samples\": [")
        for (index, sample) in samples.enumerated() {
            buffer.append(index == 0 ? "\n    {\"time\": \"" : ",\n    {\"time\": \"")
            buffer.appendTime(sample.time, offset: timeZone.secondsFromGMT(for: sample.time), iso: true)
            buffer.append("\", \"event\": ")
            buffer.appendJSONString(sample.event?.rawValue)
            buffer.append(", \"chargePercent\": ")
            buffer.appendJSONNumber(sample.percent, fractionDigits: Digits.percent, decimal: dot)
            buffer.append(", \"chargeState\": ")
            buffer.appendJSONString(sample.state.rawValue)
            buffer.append(", \"isExternalPowerConnected\": ")
            buffer.append(sample.isExternalPowerConnected.map { $0 ? "true" : "false" } ?? "null")
            buffer.append(", \"batteryWatts\": ")
            buffer.appendJSONNumber(sample.batteryWatts, fractionDigits: Digits.watts, decimal: dot)
            buffer.append(", \"systemLoadWatts\": ")
            buffer.appendJSONNumber(sample.systemLoadWatts, fractionDigits: Digits.watts, decimal: dot)
            buffer.append(", \"temperatureCelsius\": ")
            buffer.appendJSONNumber(sample.temperatureCelsius, fractionDigits: Digits.celsius, decimal: dot)
            buffer.append(", \"remainingMAh\": ")
            buffer.appendJSONInteger(sample.remainingMAh)
            buffer.append(", \"fullChargeMAh\": ")
            buffer.appendJSONInteger(sample.fullChargeMAh)
            buffer.append("}")
        }
        buffer.append(samples.isEmpty ? "],\n  \"days\": [" : "\n  ],\n  \"days\": [")
        for (index, day) in days.enumerated() {
            buffer.append(index == 0 ? "\n    {\"day\": " : ",\n    {\"day\": ")
            buffer.appendJSONString(day.day)
            buffer.append(", \"healthPercent\": ")
            buffer.appendJSONNumber(day.healthPercent, fractionDigits: Digits.dayPercent, decimal: dot)
            buffer.append(", \"capacityToDesignPercent\": ")
            buffer.appendJSONNumber(day.capacityToDesignPercent, fractionDigits: Digits.dayPercent, decimal: dot)
            buffer.append(", \"nominalChargeCapacityMAh\": ")
            buffer.appendJSONInteger(day.nominalChargeCapacityMAh)
            buffer.append(", \"fullChargeCapacityMAh\": ")
            buffer.appendJSONInteger(day.fullChargeCapacityMAh)
            buffer.append(", \"cycleCount\": ")
            buffer.appendJSONInteger(day.cycleCount)
            buffer.append("}")
        }
        buffer.append(days.isEmpty ? "]\n}\n" : "\n  ]\n}\n")
    }
}

/// The bytes of an export as they are built.
struct ExportBuffer {
    private(set) var bytes: [UInt8] = []

    mutating func append(ascii byte: UInt8) { bytes.append(byte) }
    mutating func append(_ string: String) { bytes.append(contentsOf: string.utf8) }

    mutating func appendHeader(_ columns: [String], separator: UInt8) {
        for (index, column) in columns.enumerated() {
            if index > 0 { append(ascii: separator) }
            append(column)
        }
        bytes.append(contentsOf: [0x0D, 0x0A])
    }

    mutating func endRecord() {
        bytes.append(contentsOf: [0x0D, 0x0A])
    }

    /// `value` with at least `minimumDigits` digits.
    mutating func appendInteger(_ value: Int, minimumDigits: Int = 1) {
        if value < 0 { append(ascii: 0x2D) }
        let magnitude = value.magnitude
        var divisor: UInt = 1
        var count = 1
        while divisor <= magnitude / 10 {
            divisor *= 10
            count += 1
        }
        for _ in count..<max(count, minimumDigits) { append(ascii: 0x30) }
        var rest = magnitude
        while divisor > 0 {
            bytes.append(UInt8(truncatingIfNeeded: 48 + rest / divisor))
            rest %= divisor
            divisor /= 10
        }
    }

    /// `-5.214` → "-5.21" with 2 digits; trailing zeros dropped, "-0" → "0", nothing for nil,
    /// infinity or NaN (an empty CSV field).
    mutating func appendNumber(_ value: Double?, fractionDigits: Int, decimal: UInt8) {
        guard let value, value.isFinite, abs(value) < 1e15 else { return }
        var scale = 1
        for _ in 0..<fractionDigits { scale *= 10 }
        let scaled = Int((value * Double(scale)).rounded())
        if scaled < 0 { append(ascii: 0x2D) }
        let whole = scaled.magnitude / UInt(scale)
        var fraction = scaled.magnitude % UInt(scale)
        var digits = fractionDigits
        while digits > 0, fraction % 10 == 0 {
            fraction /= 10
            digits -= 1
        }
        appendInteger(Int(whole))
        if digits > 0 {
            append(ascii: decimal)
            appendInteger(Int(fraction), minimumDigits: digits)
        }
    }

    mutating func appendJSONNumber(_ value: Double?, fractionDigits: Int, decimal: UInt8) {
        guard let value, value.isFinite, abs(value) < 1e15 else { return append("null") }
        appendNumber(value, fractionDigits: fractionDigits, decimal: decimal)
    }

    mutating func appendJSONInteger(_ value: Int?) {
        if let value { appendInteger(value) } else { append("null") }
    }

    /// ISO 8601 with the offset ("2026-10-14T19:25:00+09:00", "Z" at UTC), or the local time
    /// spreadsheets read as a date ("2026-10-14 19:25:00"). Whole seconds, Gregorian. Nothing for
    /// a time no calendar can hold (a damaged record), which `Int` would trap on.
    mutating func appendTime(_ date: Date, offset: Int, iso: Bool) {
        let interval = date.timeIntervalSince1970.rounded()
        guard abs(interval) < 1e15 else { return }
        let local = Int(interval) + offset
        let days = local >= 0 ? local / 86_400 : (local - 86_399) / 86_400
        let seconds = local - days * 86_400
        let (year, month, day) = Self.civil(fromDays: days)
        appendInteger(year, minimumDigits: 4)
        append(ascii: 0x2D)
        appendInteger(month, minimumDigits: 2)
        append(ascii: 0x2D)
        appendInteger(day, minimumDigits: 2)
        append(ascii: iso ? 0x54 : 0x20)
        appendInteger(seconds / 3600, minimumDigits: 2)
        append(ascii: 0x3A)
        appendInteger(seconds / 60 % 60, minimumDigits: 2)
        append(ascii: 0x3A)
        appendInteger(seconds % 60, minimumDigits: 2)
        guard iso else { return }
        if offset == 0 { return append(ascii: 0x5A) }
        append(ascii: offset < 0 ? 0x2D : 0x2B)
        let minutes = abs(offset) / 60
        appendInteger(minutes / 60, minimumDigits: 2)
        append(ascii: 0x3A)
        appendInteger(minutes % 60, minimumDigits: 2)
    }

    /// Year, month and day of `days` since 1970-01-01 in the proleptic Gregorian calendar.
    static func civil(fromDays days: Int) -> (year: Int, month: Int, day: Int) {
        let z = days + 719_468
        let era = (z >= 0 ? z : z - 146_096) / 146_097
        let dayOfEra = z - era * 146_097
        let yearOfEra = (dayOfEra - dayOfEra / 1460 + dayOfEra / 36_524 - dayOfEra / 146_096) / 365
        let dayOfYear = dayOfEra - (365 * yearOfEra + yearOfEra / 4 - yearOfEra / 100)
        let shiftedMonth = (5 * dayOfYear + 2) / 153
        let day = dayOfYear - (153 * shiftedMonth + 2) / 5 + 1
        let month = shiftedMonth < 10 ? shiftedMonth + 3 : shiftedMonth - 9
        return (yearOfEra + era * 400 + (month <= 2 ? 1 : 0), month, day)
    }

    /// RFC 4180: quoted only when it holds the separator, a quote, CR or LF; quotes doubled.
    mutating func appendCSVField(_ field: String, separator: UInt8) {
        let utf8 = Array(field.utf8)
        guard utf8.contains(where: { $0 == separator || $0 == 0x22 || $0 == 0x0D || $0 == 0x0A }) else {
            return bytes.append(contentsOf: utf8)
        }
        append(ascii: 0x22)
        for byte in utf8 {
            if byte == 0x22 { append(ascii: 0x22) }
            append(ascii: byte)
        }
        append(ascii: 0x22)
    }

    /// A JSON string, or null.
    mutating func appendJSONString(_ string: String?) {
        guard let string else { return append("null") }
        append(ascii: 0x22)
        for byte in string.utf8 {
            switch byte {
            case 0x22: append("\\\"")
            case 0x5C: append("\\\\")
            case 0x0A: append("\\n")
            case 0x0D: append("\\r")
            case 0x09: append("\\t")
            case 0..<0x20:
                append("\\u00")
                let hex = Array("0123456789abcdef".utf8)
                append(ascii: hex[Int(byte >> 4)])
                append(ascii: hex[Int(byte & 0x0F)])
            default: append(ascii: byte)
            }
        }
        append(ascii: 0x22)
    }
}
