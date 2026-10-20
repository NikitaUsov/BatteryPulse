import BatteryCore
import Testing

@testable import bpulse

/// `parseOptions` decides the exit status 1 ("bad usage") of bpulse's frozen contract. Every
/// vector here records 0.6.0's behaviour; `nil` is bad usage. The top-level code of `main.swift`
/// never runs under tests, so nothing here reads its globals (`usage`, `arguments`, `options`).
@Suite struct OptionParsingTests {
    struct Case: Sendable, CustomTestStringConvertible {
        let arguments: [String]
        let expected: Options?

        init(_ arguments: [String], _ expected: Options?) {
            self.arguments = arguments
            self.expected = expected
        }

        var testDescription: String { arguments.isEmpty ? "(no options)" : arguments.joined(separator: " ") }
    }

    static let accepted = [
        Case([], Options()),
        Case(["--json"], Options(format: .json)),
        Case(["--raw"], Options(format: .raw)),
        Case(["--smc"], Options(format: .smc)),
        // The last output format wins.
        Case(["--json", "--raw"], Options(format: .raw)),
        Case(["--watch"], Options(watchInterval: 2)),
        Case(["--watch", "5"], Options(watchInterval: 5)),
        Case(["--watch", "0.5", "--json"], Options(format: .json, watchInterval: 0.5)),
        Case(["--watch", "86400"], Options(watchInterval: 86_400)),
        // A value that isn't a number is the next option.
        Case(["--watch", "--json"], Options(format: .json, watchInterval: 2)),
        Case(["--input", "capture.plist"], Options(inputPath: "capture.plist")),
        Case(
            ["--input", "capture.plist", "--raw", "--watch", "1"],
            Options(format: .raw, watchInterval: 1, inputPath: "capture.plist")),
        Case(["--record", "folder"], Options(recordFolder: "folder")),
        Case(["--devices"], Options(listsDevices: true)),
        Case(["--device", "1"], Options(deviceNumber: 1)),
        Case(["--device", "2", "--json"], Options(format: .json, deviceNumber: 2)),
        Case(["--raw", "--device", "3"], Options(format: .raw, deviceNumber: 3)),
        Case(["--accessories"], Options(listsAccessories: true)),
        Case(["--accessories", "--json"], Options(format: .json, listsAccessories: true)),
        Case(["--accessories", "--raw"], Options(format: .raw, listsAccessories: true)),
        Case(["--export", "csv"], Options(exportFormat: "csv")),
        Case(["--export", "json"], Options(exportFormat: "json")),
        Case(
            ["--export", "csv", "--days", "--decimal-comma", "--history", "folder"],
            Options(exportFormat: "csv", exportsDays: true, usesDecimalComma: true, historyPath: "folder")),
        Case(["--history", "folder", "--export", "json"], Options(exportFormat: "json", historyPath: "folder")),
        // The parser takes these; the top-level code then rejects them with status 1.
        Case(["--smc", "--watch"], Options(format: .smc, watchInterval: 2)),
        Case(["--smc", "--input", "capture.plist"], Options(format: .smc, inputPath: "capture.plist")),
    ]

    static let rejected: [[String]] = [
        // Unknown options and missing values.
        ["--unknown"], ["json"], ["--input"], ["--record"], ["--history"], ["--export"], ["--device"],
        // A recording takes no output format, --watch, input, device, export or accessories.
        ["--record", "folder", "--json"], ["--record", "folder", "--raw"], ["--record", "folder", "--smc"],
        ["--record", "folder", "--watch"], ["--record", "folder", "--input", "capture.plist"],
        ["--record", "folder", "--devices"], ["--record", "folder", "--device", "1"],
        ["--record", "folder", "--export", "csv"], ["--record", "folder", "--accessories"],
        // An export reads only the history.
        ["--export", "xml"], ["--export", "csv", "--json"], ["--export", "csv", "--watch"],
        ["--export", "csv", "--input", "capture.plist"], ["--export", "csv", "--devices"],
        ["--export", "json", "--device", "1"], ["--export", "csv", "--accessories"],
        // --days and --decimal-comma shape a CSV export; --history names an export's folder.
        ["--days"], ["--decimal-comma"], ["--export", "json", "--days"], ["--export", "json", "--decimal-comma"],
        ["--history", "folder"], ["--history", "folder", "--json"],
        // A device is read once, live; --devices only lists.
        ["--devices", "--json"], ["--devices", "--raw"], ["--devices", "--device", "1"],
        ["--devices", "--watch"], ["--device", "1", "--watch"], ["--device", "1", "--input", "capture.plist"],
        ["--device", "1", "--smc"],
        ["--device", "0"], ["--device", "-1"], ["--device", "one"],
        // Accessories are read once, live, on their own.
        ["--accessories", "--device", "1"], ["--accessories", "--devices"], ["--accessories", "--watch"],
        ["--accessories", "--input", "capture.plist"], ["--accessories", "--smc"],
        // `Duration.seconds` traps on inf and values beyond about 1e19 s.
        ["--watch", "0"], ["--watch", "-1"], ["--watch", "inf"], ["--watch", "nan"], ["--watch", "86401"],
        ["--watch", "1e20"],
        // Not a number, so "abc" is read as an option.
        ["--watch", "abc"],
    ]

    @Test(arguments: accepted)
    func accepts(_ test: Case) {
        #expect(parseOptions(test.arguments) == test.expected)
    }

    @Test(arguments: rejected)
    func rejects(_ arguments: [String]) {
        #expect(parseOptions(arguments) == nil)
    }

    @Test(arguments: [
        (["--export", "csv"], HistoryExportKind.samplesCSV),
        (["--export", "csv", "--days"], .daysCSV),
        (["--export", "json"], .json),
    ])
    func exportKinds(_ arguments: [String], _ kind: HistoryExportKind) {
        #expect(parseOptions(arguments)?.exportKind == kind)
    }

    @Test func noExportWithoutExportOption() {
        #expect(parseOptions([])?.exportKind == nil)
        #expect(parseOptions(["--json"])?.exportKind == nil)
    }

    @Test func devicesAreReadForBothDeviceOptions() {
        #expect(parseOptions(["--devices"])?.readsDevice == true)
        #expect(parseOptions(["--device", "1"])?.readsDevice == true)
        #expect(parseOptions(["--accessories"])?.readsDevice == false)
    }
}
