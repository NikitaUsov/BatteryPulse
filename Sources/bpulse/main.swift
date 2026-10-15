import BatteryCore
import BatteryKit
import Foundation

let usage = """
    Usage: bpulse [--json | --raw] [--watch [seconds]] [--input capture.plist]
           bpulse --smc
           bpulse --devices
           bpulse --device <n> [--json | --raw]
           bpulse --accessories [--json | --raw]
           bpulse --export csv|json [--days] [--decimal-comma] [--history <folder>]

      (no options)      Human-readable battery report
      --json            Parsed snapshot as JSON (one compact object per line with --watch)
      --raw             Raw IOKit dictionaries as an XML property list, serial numbers
                        redacted — attach this to bug reports; it is also the test fixture format
      --watch [sec]     Repeat every N seconds (default 2, max 86400) until interrupted
      --input <file>    Read a capture saved with --raw (a Mac's, a device's or the
                        accessories') instead of this Mac's battery
      --smc             List the SMC's battery and charger keys with their types, and the raw
                        bytes and values of the battery keys (B0*, BC*, BN*, TB*, SBA*) (macOS);
                        read-only, for finding the keys on a new Mac model
      --devices         List the iPhones and iPads connected by USB or Wi-Fi, numbered (macOS);
                        devices whose names aren't read in time (10 s each, 30 s in all) are
                        listed as "Unknown device"
      --device <n>      Battery report of device n from --devices, with the same ID (macOS); no
                        other device is contacted. The device must trust this Mac: unlock it and
                        tap Trust. With --raw: everything the device returned as an XML property
                        list, serial numbers, identifiers and the device's name redacted; with
                        --json: the parsed battery
      --accessories     Batteries of the accessories connected to this Mac (Bluetooth keyboards,
                        mice, trackpads, headphones) as macOS reports them (macOS). With --raw: the
                        power-source dictionaries as an XML property list, identifiers and names
                        replaced; with --json: the parsed list
      --export csv|json The battery history BatteryPulse recorded (everything it keeps), on
                        standard output. csv: the minute readings; with --days, the daily battery
                        health. json: both. CSV uses commas and decimal points; --decimal-comma
                        uses semicolons and decimal commas, as spreadsheets expect where decimals
                        are written with a comma. Times are in the current time zone (TZ)
      --history <folder>
                        Export this history folder instead of BatteryPulse's own
                        (~/Library/Application Support/io.github.nikitausov.BatteryPulse/History)
      -h, --help        Show this help

    Exit status: 0 on success, 1 on bad usage or unreadable input, 2 if no battery was found
    (or no device, or the device couldn't be read, or no accessory reports a battery, or there is
    no history folder to export).
    """

enum OutputFormat {
    case text, json, raw, smc
}

struct Options {
    var format = OutputFormat.text
    var watchInterval: Double?
    var inputPath: String?
    var listsDevices = false
    /// 1-based, as `--devices` numbers them.
    var deviceNumber: Int?
    /// "csv" or "json".
    var exportFormat: String?
    var exportsDays = false
    var usesDecimalComma = false
    var historyPath: String?
    var listsAccessories = false

    var readsDevice: Bool { listsDevices || deviceNumber != nil }

    var exportKind: HistoryExportKind? {
        switch exportFormat {
        case "csv": exportsDays ? .daysCSV : .samplesCSV
        case "json": .json
        default: nil
        }
    }
}

func parseOptions(_ arguments: [String]) -> Options? {
    var options = Options()
    var remaining = arguments[...]
    while let argument = remaining.popFirst() {
        switch argument {
        case "--json": options.format = .json
        case "--raw": options.format = .raw
        case "--smc": options.format = .smc
        case "--watch":
            if let next = remaining.first, let seconds = Double(next) {
                // `Duration.seconds` traps on inf and values beyond ~1e19 s.
                guard seconds.isFinite, seconds > 0, seconds <= 86_400 else { return nil }
                options.watchInterval = seconds
                remaining.removeFirst()
            } else {
                options.watchInterval = 2
            }
        case "--input":
            guard let path = remaining.popFirst() else { return nil }
            options.inputPath = path
        case "--export":
            guard let format = remaining.popFirst(), format == "csv" || format == "json" else { return nil }
            options.exportFormat = format
        case "--days": options.exportsDays = true
        case "--decimal-comma": options.usesDecimalComma = true
        case "--history":
            guard let path = remaining.popFirst() else { return nil }
            options.historyPath = path
        case "--devices": options.listsDevices = true
        case "--accessories": options.listsAccessories = true
        case "--device":
            guard let next = remaining.popFirst(), let number = Int(next), number > 0 else { return nil }
            options.deviceNumber = number
        default: return nil
        }
    }
    if options.exportFormat != nil {
        // An export reads only the history: no other output, input or device.
        guard options.format == .text, options.watchInterval == nil, options.inputPath == nil, !options.readsDevice,
            !options.listsAccessories
        else { return nil }
    }
    // --days and --decimal-comma shape a CSV export; --history names what to export.
    guard options.exportFormat == "csv" || !(options.exportsDays || options.usesDecimalComma),
        options.exportFormat != nil || options.historyPath == nil
    else { return nil }
    if options.readsDevice {
        // A device is read once, live: no --watch, --input or --smc.
        guard options.watchInterval == nil, options.inputPath == nil, options.format != .smc else { return nil }
        // --devices only lists.
        guard !options.listsDevices || (options.deviceNumber == nil && options.format == .text) else { return nil }
    }
    if options.listsAccessories {
        // Accessories are read once, live, on their own: no --watch, --input, --smc or device.
        guard options.watchInterval == nil, options.inputPath == nil, options.format != .smc, !options.readsDevice
        else { return nil }
    }
    return options
}

func render(_ reading: BatteryReading, as format: OutputFormat, compact: Bool) throws -> String {
    switch format {
    case .text:
        return BatteryReport.text(for: reading.snapshot)
    case .json:
        let encoder = JSONEncoder()
        encoder.outputFormatting = compact ? [.sortedKeys] : [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return String(decoding: try encoder.encode(reading.snapshot), as: UTF8.self)
    case .raw:
        return try xmlPropertyList(reading.redactedRawCapture)
    case .smc:
        return ""
    }
}

func xmlPropertyList(_ dictionary: PropertyDictionary) throws -> String {
    let data = try PropertyListSerialization.data(
        fromPropertyList: PropertyValue.dictionary(dictionary).foundationValue,
        format: .xml,
        options: 0
    )
    return String(decoding: data, as: UTF8.self)
}

/// A device read: the report, the parsed battery as JSON, or the redacted capture. Device
/// problems go to standard error and end with status 2; a raw capture is printed anyway, since
/// its calls and replies show what went wrong.
func renderDevice(_ capture: IDeviceCapture, as format: OutputFormat) throws -> Never {
    let problem = capture.problem
    switch format {
    case .text, .smc:
        print(IDeviceReport.text(for: capture))
        exit(problem == nil && IDeviceBatteryParser.battery(in: capture) != nil ? 0 : 2)
    case .json:
        guard let battery = IDeviceBatteryParser.battery(in: capture) else {
            fail("bpulse: " + (problem?.description ?? "the battery entry has no capacity values."), code: 2)
        }
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        print(String(decoding: try encoder.encode(battery), as: UTF8.self))
        exit(0)
    case .raw:
        print(try xmlPropertyList(capture.redactedRawCapture), terminator: "")
        if let problem { fail("bpulse: " + problem.description, code: 2) }
        exit(0)
    }
}

/// The accessory list, the parsed list as JSON (no identifiers), or the pseudonymized capture.
/// An empty list ends with status 2, except for a raw capture: "nothing connected" is evidence too.
func renderAccessories(_ reading: AccessoryReading, as format: OutputFormat) throws -> Never {
    switch format {
    case .text, .smc:
        print(AccessoryReport.text(for: reading.accessories))
        exit(reading.accessories.isEmpty ? 2 : 0)
    case .json:
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        print(String(decoding: try encoder.encode(reading.accessories), as: UTF8.self))
        exit(0)
    case .raw:
        print(try xmlPropertyList(reading.redactedRawCapture), terminator: "")
        exit(0)
    }
}

/// `--accessories`.
@MainActor
func readAccessories(_ options: Options) throws -> Never {
    guard let provider = SystemAccessories.makeProvider() else {
        fail("bpulse: accessory batteries need macOS.", code: 2)
    }
    guard let reading = provider.read() else {
        fail("bpulse: this version of macOS doesn't report accessory batteries.", code: 2)
    }
    try renderAccessories(reading, as: options.format)
}

/// `--devices` and `--device <n>`.
func readDevices(_ options: Options) async throws -> Never {
    guard let transport = SystemDevices.makeTransport() else {
        fail("bpulse: reading an iPhone or iPad needs macOS.", code: 2)
    }
    let devices: [IDeviceInfo]
    do {
        // The list is ordered by identifier, which needs no connection: `--device <n>` finds
        // device n without connecting to the others, so a device that doesn't answer can't delay
        // it or change the numbering.
        devices = try await transport.devices(readingIdentity: options.deviceNumber == nil)
    } catch {
        fail("bpulse: \(error)", code: 2)
    }
    guard !devices.isEmpty else {
        fail(
            """
            bpulse: no iPhone or iPad found. Connect one by cable, unlock it and tap Trust. For Wi-Fi, \
            first turn on "Show this iPhone when on Wi-Fi" for it in Finder.
            """, code: 2)
    }
    guard let number = options.deviceNumber else {
        print(IDeviceList.text(devices))
        exit(0)
    }
    guard devices.indices.contains(number - 1) else {
        fail("bpulse: there is no device \(number); bpulse --devices lists \(devices.count).", code: 2)
    }
    let capture: IDeviceCapture
    do {
        capture = try await transport.capture(deviceID: devices[number - 1].id)
    } catch {
        fail("bpulse: \(error)", code: 2)
    }
    try renderDevice(capture, as: options.format)
}

/// Writes the recorded history to standard output.
func exportHistory(_ kind: HistoryExportKind, _ options: Options) async -> Never {
    let directory =
        options.historyPath.map { URL(fileURLWithPath: $0) }
        ?? HistoryStore.defaultDirectory(bundleIdentifier: HistoryStore.appBundleIdentifier)
    // A file in its place has nothing to export either.
    var isDirectory: ObjCBool = false
    guard FileManager.default.fileExists(atPath: directory.path, isDirectory: &isDirectory), isDirectory.boolValue
    else {
        fail(
            "bpulse: no history at \(directory.path). BatteryPulse records it while it runs (Settings → Advanced → History).",
            code: 2)
    }
    // Only BatteryPulse's own folder is known to be this Mac's.
    var source: HistoryExportSource?
    #if os(macOS)
    if options.historyPath == nil { source = .mac(ProcessInfo.processInfo.operatingSystemVersion) }
    #endif
    let info = HistoryExportInfo(exportedAt: Date(), generator: "bpulse", source: source)
    do {
        let data = try await HistoryExport.data(
            kind, from: HistoryStore(directory: directory),
            dialect: options.usesDecimalComma ? .decimalComma : .standard, info: info, timeZone: .current)
        try FileHandle.standardOutput.write(contentsOf: data)
    } catch {
        fail("bpulse: cannot export the history: \(error.localizedDescription)", code: 1)
    }
    exit(0)
}

/// Lists the SMC keys that look battery-related. Every listed key's type is read; values only for
/// the battery prefixes, because a few SMC keys change state when read.
@MainActor
func smcKeyList() -> String {
    #if os(macOS)
    let listedPrefixes = ["B", "TB", "SB", "CH", "AC"]
    let readPrefixes = ["B0", "BC", "BN", "TB", "SBA"]
    let smc = SMCClient()
    let count: Int
    do {
        count = try smc.keyCount()
    } catch {
        fail("bpulse: cannot read the SMC key table (\(error)).", code: 2)
    }
    var lines = ["key   type  size  attr  bytes  value"]
    for index in 0..<count {
        guard let key = try? smc.key(at: index), listedPrefixes.contains(where: key.description.hasPrefix),
            let info = try? smc.info(for: key)
        else { continue }
        var fields = [
            key.description, info.type.description, String(info.size), "0x" + String(info.attributes, radix: 16),
        ]
        if readPrefixes.contains(where: key.description.hasPrefix), let value = try? smc.read(key) {
            fields.append(value.payload.map { String(format: "%02x", $0) }.joined())
            fields += value.number.map { [String($0)] } ?? []
        }
        lines.append(fields.joined(separator: "  "))
    }
    return lines.joined(separator: "\n")
    #else
    fail("bpulse: the SMC is only available on macOS.", code: 2)
    #endif
}

func fail(_ message: String, code: Int32) -> Never {
    FileHandle.standardError.write(Data((message + "\n").utf8))
    exit(code)
}

let arguments = Array(CommandLine.arguments.dropFirst())
if arguments.contains("-h") || arguments.contains("--help") {
    print(usage)
    exit(0)
}
guard let options = parseOptions(arguments) else {
    fail(usage, code: 1)
}
if let kind = options.exportKind {
    await exportHistory(kind, options)
}
if options.listsAccessories {
    try readAccessories(options)
}
if options.readsDevice {
    try await readDevices(options)
}
if options.format == .smc {
    guard options.inputPath == nil, options.watchInterval == nil else { fail(usage, code: 1) }
    print(smcKeyList())
    exit(0)
}
func loadCapture(at path: String) -> PropertyDictionary {
    do {
        let data = try Data(contentsOf: URL(fileURLWithPath: path))
        let root = try PropertyListSerialization.propertyList(from: data, format: nil)
        guard let capture = PropertyValue.dictionary(fromAny: root) else {
            fail("bpulse: \(path) is not a property list dictionary.", code: 1)
        }
        return capture
    } catch {
        fail("bpulse: cannot read \(path): \(error.localizedDescription)", code: 1)
    }
}

// A capture of an iPhone or iPad (`--device <n> --raw`) or of accessories (`--accessories --raw`)
// is rendered once; a Mac's is read again on each `--watch` tick below.
if let path = options.inputPath {
    let capture = loadCapture(at: path)
    if let device = IDeviceCapture(rawCapture: capture) {
        try renderDevice(device, as: options.format)
    }
    if let accessories = AccessoryReading(rawCapture: capture) {
        try renderAccessories(accessories, as: options.format)
    }
}

let provider = options.inputPath == nil ? SystemBattery.makeProvider() : nil
if options.inputPath == nil, provider == nil {
    fail("bpulse: battery information is not available on this platform.", code: 2)
}

let clearsScreen = options.format == .text && isatty(STDOUT_FILENO) != 0
repeat {
    let reading: BatteryReading
    if let path = options.inputPath {
        reading = BatteryReading(rawCapture: loadCapture(at: path), timestamp: Date())
    } else if let current = provider?.read() {
        reading = current
    } else {
        fail("bpulse: no internal battery found.", code: 2)
    }
    let output = try render(reading, as: options.format, compact: options.watchInterval != nil)
    if clearsScreen, options.watchInterval != nil {
        print("\u{1B}[H\u{1B}[2J", terminator: "")
    }
    print(output)
    fflush(nil)  // `stdout` is a global C var, which Swift 6 rejects; nil flushes all streams.

    if let interval = options.watchInterval {
        try await Task.sleep(for: .seconds(interval))
    }
} while options.watchInterval != nil
