import Foundation
import BatteryCore
import BatteryKit

let usage = """
    Usage: bpulse [--json | --raw] [--watch [seconds]]

      (no options)    Human-readable battery report
      --json          Parsed snapshot as JSON (one compact object per line with --watch)
      --raw           Raw IOKit dictionaries as an XML property list — attach this to bug
                      reports; it is also the test fixture format
      --watch [sec]   Repeat every N seconds (default 2) until interrupted
      -h, --help      Show this help

    Exit status: 0 on success, 1 on bad usage, 2 if no battery was found.
    """

enum OutputFormat {
    case text, json, raw
}

struct Options {
    var format = OutputFormat.text
    var watchInterval: Double?
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
            fromPropertyList: PropertyValue.dictionary(reading.rawCapture).foundationValue,
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
guard let provider = SystemBattery.makeProvider() else {
    fail("bpulse: battery information is not available on this platform.", code: 2)
}

let clearsScreen = options.format == .text && isatty(STDOUT_FILENO) != 0
repeat {
    guard let reading = provider.read() else {
        fail("bpulse: no internal battery found.", code: 2)
    }
    let output = try render(reading, as: options.format, compact: options.watchInterval != nil)
    if clearsScreen, options.watchInterval != nil {
        print("\u{1B}[H\u{1B}[2J", terminator: "")
    }
    print(output)
    fflush(nil) // `stdout` is a global C var, which Swift 6 rejects; nil flushes all streams.

    if let interval = options.watchInterval {
        try await Task.sleep(for: .seconds(interval))
    }
} while options.watchInterval != nil
