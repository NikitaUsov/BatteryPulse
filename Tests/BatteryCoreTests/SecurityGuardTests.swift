import Foundation
import Testing

/// Keeps the APIs that reach past the public, checked surface where they are today, in every
/// target, Darwin code included (SEC-R7; CLAUDE.md lists the guard suites).
///
/// Scans every Swift file of `Sources` with comments and string literals blanked out
/// (``SourceScanner/allFiles``), so the `kill -0` in the installer's relaunch script, a string in
/// BatteryCore, doesn't count. It fails on an API of ``placements`` outside the files listed with
/// it, or more often there than listed, such as:
/// - `dlopen`, `dlsym` or `dlclose` outside the two files that load private symbols: the
///   MobileDevice framework and the accessory power sources;
/// - an IOKit user-client call (`IOServiceOpen`, `IOConnect…`) outside the SMC client, and a
///   registry write anywhere;
/// - starting a process outside the installer, or signalling one outside the widget refresher.
///
/// The SMC client itself makes one call, with selector 2 (``smcClientCallsOnlySelectorTwo()``);
/// `SMCTests` pins its commands to the three reads (5, 8 and 9).
@Suite struct SecurityGuardTests {
    /// An API that may appear only in the listed files, each holding at most so many matches.
    struct Placement {
        /// Every match holds one of these, so a file without any is skipped: a `Regex` is slow on
        /// Linux, and most files use none of the APIs. `catches(source:)` checks the cases.
        var literals: [String]
        var pattern: Regex<Substring>
        /// Paths relative to `Sources/`, each with the most matches it may hold.
        var allowed: [String: Int]
        var message: String
    }

    /// `\b` as in most regex engines (see `MotionGuardTests`).
    private static func words(_ regex: Regex<Substring>) -> Regex<Substring> {
        regex.wordBoundaryKind(.simple)
    }

    /// Computed: a `Regex` isn't `Sendable`, so it can't be a stored static.
    static var placements: [Placement] {
        [
            Placement(
                literals: ["dlopen", "dlsym", "dlclose"],
                pattern: words(#/\bdl(?:open|sym|close)\b/#),
                allowed: [
                    "BatteryKit/MobileDevice/MobileDeviceLibrary.swift": .max,
                    "BatteryKit/MacAccessoryProvider.swift": .max,
                ],
                message: "dlopen/dlsym only for MobileDevice and the accessory power sources"),
            Placement(
                literals: ["IOServiceOpen", "IOConnect"],
                pattern: words(#/\bIOServiceOpen\b|\bIOConnect\w+/#),
                allowed: ["BatteryKit/SMCClient.swift": .max],
                message: "an IOKit user client only in the SMC client"),
            Placement(
                literals: ["IORegistryEntrySetCFPropert"],
                pattern: words(#/\bIORegistryEntrySetCFPropert(?:y|ies)\b/#),
                allowed: [:],
                message: "the I/O Registry is only read"),
            Placement(
                literals: ["Process", "NSTask", "posix_spawn", "execv"],
                pattern: words(#/\bProcess\b|\bNSTask\b|\bposix_spawn\w*|\bexecv\w*\s*\(/#),
                allowed: ["BatteryPulseApp/Updates/UpdateInstaller.swift": .max],
                message: "a process starts only in the installer"),
            Placement(
                literals: ["kill"],
                pattern: words(#/\b(?:kill|killpg)\s*\(/#),
                allowed: ["BatteryPulseApp/App/WidgetRefresher.swift": .max],
                message: "a process is signalled only by the widget refresher"),
        ]
    }

    /// Every rule broken in `source`, as "path:line: message".
    static func violations(in source: String, path: String) -> [String] {
        violations(inCode: SourceScanner.codeOnly(source), path: path)
    }

    /// Every rule broken in `code`, a source already blanked by ``SourceScanner/codeOnly(_:)``.
    static func violations(inCode code: String, path: String) -> [String] {
        var found: [(String.Index, String)] = []
        for placement in placements where placement.literals.contains(where: { code.contains($0) }) {
            let matches = code.matches(of: placement.pattern)
            let allowed = placement.allowed[path] ?? 0
            guard matches.count > allowed else { continue }
            for match in matches.dropFirst(allowed) {
                found.append((match.range.lowerBound, placement.message))
            }
        }
        return found.sorted { $0.0 < $1.0 }.map { index, message in
            let line = code[..<index].reduce(1) { $1 == "\n" ? $0 + 1 : $0 }
            return "\(path):\(line): \(message)"
        }
    }

    // MARK: Tests

    /// One case per file, so a failure names the file.
    @Test(arguments: (try? SourceScanner.allFiles.get()) ?? [])
    func sourcesKeepRiskyAPIsInPlace(_ file: SourceScanner.File) {
        let violations = Self.violations(inCode: file.code, path: file.path)
        #expect(violations.isEmpty, "\(violations.joined(separator: "\n"))")
    }

    /// The file list behind the cases above covers every target.
    @Test func scansEveryTarget() throws {
        let paths = try SourceScanner.allFiles.get().map(\.path)
        for target in SourceScanner.targets + SourceScanner.otherTargets {
            #expect(paths.contains { $0.hasPrefix(target + "/") }, "\(target)")
        }
        let appAndWidget = try SourceScanner.files.get()
        #expect(paths.count > appAndWidget.count)
    }

    @Test func allowListedFilesExist() {
        for path in Self.placements.flatMap(\.allowed.keys) {
            #expect(
                FileManager.default.fileExists(atPath: SourceScanner.sources.appendingPathComponent(path).path),
                "\(path)")
        }
    }

    /// The SMC client's one user-client call: `IOConnectCallStructMethod` with selector 2
    /// (`kSMCHandleYPCEvent`), which carries the read commands that `SMCTests` pins.
    @Test func smcClientCallsOnlySelectorTwo() throws {
        let code = try #require(
            try SourceScanner.allFiles.get().first { $0.path == "BatteryKit/SMCClient.swift" }
        ).code
        let calls = SourceScanner.calls(named: Self.words(#/\bIOConnect\w+/#), in: code)
        #expect(calls.map(\.name) == ["IOConnectCallStructMethod"])
        #expect(calls.first?.topLevelArguments.dropFirst().first == "Self.selector")
        #expect(code.contains(Self.words(#/\bstatic\s+let\s+selector\s*:\s*UInt32\s*=\s*2\b/#)))
    }

    private static let somewhere = "BatteryKit/MacBatteryProvider.swift"

    private func flags(_ source: String, path: String = somewhere) -> Bool {
        !Self.violations(in: source, path: path).isEmpty
    }

    @Test(arguments: [
        "let handle = dlopen(path, RTLD_NOW | RTLD_LOCAL)",
        "let symbol = dlsym(handle, name)",
        "dlclose(handle)",
        "let status = IOServiceOpen(service, mach_task_self_, 0, &connection)",
        "IOConnectCallStructMethod(port, 2, input, size, output, &outputSize)",
        "IOConnectCallScalarMethod(port, 5, nil, 0, nil, nil)",
        "IORegistryEntrySetCFProperty(entry, key, value)",
        "let process = Process()",
        "let task = NSTask()",
        "posix_spawn(&pid, path, nil, nil, argv, environ)",
        "execv(path, argv)",
        "kill(pid, SIGKILL)",
        "killpg(group, SIGTERM)",
    ])
    func catches(source: String) {
        #expect(flags(source), "\(source)")
        // The literals are in every match, or skipping a file could hide one.
        let code = SourceScanner.codeOnly(source)
        for placement in Self.placements where code.contains(placement.pattern) {
            #expect(placement.literals.contains(where: { code.contains($0) }), "\(placement.message)")
        }
    }

    @Test(arguments: [
        "let info = ProcessInfo.processInfo",
        "let script = \"while kill -0 $2; do sleep 0.2; done\"",
        "// dlopen and Process() in a comment",
        "IOServiceClose(port)",
        "let service = IOServiceGetMatchingService(kIOMainPortDefault, matching)",
        "IORegistryEntryCreateCFProperties(entry, &properties, kCFAllocatorDefault, 0)",
        "let skill = killSwitch(on)",
    ])
    func allows(source: String) {
        #expect(!flags(source), "\(Self.violations(in: source, path: Self.somewhere))")
    }

    @Test func eachAPIIsAllowedOnlyWhereItIsToday() {
        #expect(!flags("dlsym(handle, name)", path: "BatteryKit/MobileDevice/MobileDeviceLibrary.swift"))
        #expect(!flags("dlopen(path, RTLD_NOW)", path: "BatteryKit/MacAccessoryProvider.swift"))
        #expect(flags("dlopen(path, RTLD_NOW)", path: "BatteryKit/SMCClient.swift"))
        #expect(!flags("IOServiceOpen(service, task, 0, &port)", path: "BatteryKit/SMCClient.swift"))
        #expect(flags("IOServiceOpen(service, task, 0, &port)", path: "BatteryKit/MobileDevice/USBDeviceWatcher.swift"))
        #expect(flags("IORegistryEntrySetCFProperty(entry, key, value)", path: "BatteryKit/SMCClient.swift"))
        #expect(!flags("let process = Process()", path: "BatteryPulseApp/Updates/UpdateInstaller.swift"))
        #expect(flags("let process = Process()", path: "bpulse/main.swift"))
        #expect(!flags("kill(pid, SIGTERM)", path: "BatteryPulseApp/App/WidgetRefresher.swift"))
        #expect(flags("kill(pid, SIGTERM)", path: "BatteryPulseApp/Updates/UpdateInstaller.swift"))
    }

    @Test func reportsLineNumbers() {
        let violations = Self.violations(in: "let a = 1\n// dlopen\nlet h = dlopen(p, 0)\n", path: "X.swift")
        #expect(violations == ["X.swift:3: dlopen/dlsym only for MobileDevice and the accessory power sources"])
    }
}
