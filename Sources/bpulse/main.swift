import BatteryCore
import BatteryKit
import Foundation

let usage = """
    Usage: bpulse [--json | --raw] [--watch [seconds]] [--input capture.plist]
           bpulse --smc
           bpulse --devices
           bpulse --device <n> [--json | --raw]

      (no options)      Human-readable battery report
      --json            Parsed snapshot as JSON (one compact object per line with --watch)
      --raw             Raw IOKit dictionaries as an XML property list, serial numbers
                        redacted — attach this to bug reports; it is also the test fixture format
      --watch [sec]     Repeat every N seconds (default 2, max 86400) until interrupted
      --input <file>    Read a capture saved with --raw (a Mac's or a device's) instead of this
                        Mac's battery
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
      -h, --help        Show this help

    Exit status: 0 on success, 1 on bad usage or unreadable input, 2 if no battery was found
    (or no device, or the device couldn't be read).
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

    var readsDevice: Bool { listsDevices || deviceNumber != nil }
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
        case "--devices": options.listsDevices = true
        case "--device":
            guard let next = remaining.popFirst(), let number = Int(next), number > 0 else { return nil }
            options.deviceNumber = number
        default: return nil
        }
    }
    if options.readsDevice {
        // A device is read once, live: no --watch, --input or --smc.
        guard options.watchInterval == nil, options.inputPath == nil, options.format != .smc else { return nil }
        // --devices only lists.
        guard !options.listsDevices || (options.deviceNumber == nil && options.format == .text) else { return nil }
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

// A capture of an iPhone or iPad (`--device <n> --raw`) is rendered once.
if let path = options.inputPath, let capture = IDeviceCapture(rawCapture: loadCapture(at: path)) {
    try renderDevice(capture, as: options.format)
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
