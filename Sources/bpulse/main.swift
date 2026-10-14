import BatteryCore
import BatteryKit
import Foundation

let usage = """
    Usage: bpulse [--json | --raw] [--watch [seconds]] [--input capture.plist]

      (no options)      Human-readable battery report
      --json            Parsed snapshot as JSON (one compact object per line with --watch)
      --raw             Raw IOKit dictionaries as an XML property list, serial numbers
                        redacted — attach this to bug reports; it is also the test fixture format
      --watch [sec]     Repeat every N seconds (default 2) until interrupted
      --input <file>    Read a capture saved with --raw instead of this Mac's battery
      -h, --help        Show this help

    Exit status: 0 on success, 1 on bad usage or unreadable input, 2 if no battery was found.
    """

enum OutputFormat {
    case text, json, raw
}

struct Options {
    var format = OutputFormat.text
    var watchInterval: Double?
    var inputPath: String?
}

func parseOptions(_ arguments: [String]) -> Options? {
    var options = Options()
    var remaining = arguments[...]
    while let argument = remaining.popFirst() {
        switch argument {
        case "--json": options.format = .json
        case "--raw": options.format = .raw
        case "--watch":
            if let next = remaining.first, let seconds = Double(next) {
                guard seconds > 0 else { return nil }
                options.watchInterval = seconds
                remaining.removeFirst()
            } else {
                options.watchInterval = 2
            }
        case "--input":
            guard let path = remaining.popFirst() else { return nil }
            options.inputPath = path
        default: return nil
        }
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
        let data = try PropertyListSerialization.data(
            fromPropertyList: PropertyValue.dictionary(reading.redactedRawCapture).foundationValue,
            format: .xml,
            options: 0
        )
        return String(decoding: data, as: UTF8.self)
    }
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
func loadCapture(at path: String) -> BatteryReading {
    do {
        let data = try Data(contentsOf: URL(fileURLWithPath: path))
        let root = try PropertyListSerialization.propertyList(from: data, format: nil)
        guard let capture = PropertyValue.dictionary(fromAny: root) else {
            fail("bpulse: \(path) is not a property list dictionary.", code: 1)
        }
        return BatteryReading(rawCapture: capture, timestamp: Date())
    } catch {
        fail("bpulse: cannot read \(path): \(error.localizedDescription)", code: 1)
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
        reading = loadCapture(at: path)
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
