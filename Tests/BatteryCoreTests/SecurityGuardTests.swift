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
/// - starting a process outside the installer, or signalling one outside the widget refresher;
/// - a `URLSession` made outside `UpdateNetwork`, or the version count's URL taken outside the
///   update checker.
///
/// The SMC client itself makes one call, with selector 2 (``smcClientCallsOnlySelectorTwo()``);
/// `SMCTests` pins its commands to the three reads (5, 8 and 9).
///
/// The escapes from the compiler's checks are listed too, each where it is today: the
/// `@unchecked Sendable` types, `nonisolated(unsafe)`, and strict memory safety's `@safe`, which
/// vouches for a type that keeps a pointer. The targets built with strict memory safety mark
/// every other unsafe use `unsafe`, and nothing silences the check
/// (``strictMemorySafetyTargets``).
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
                    "BatterySource/MacAccessoryProvider.swift": .max,
                ],
                message: "dlopen/dlsym only for MobileDevice and the accessory power sources"),
            // SEC-03: the update traffic goes through `UpdateNetwork`'s ephemeral sessions, which
            // cache nothing on disk and keep automatic checks off Low Data Mode.
            Placement(
                literals: ["URLSession"],
                pattern: words(#/\bURLSession\s*\.\s*shared\b/#),
                allowed: [:],
                message: "URLSession.shared caches on disk; use UpdateNetwork's sessions"),
            // W-13: with `.shared` banned, `UpdateNetwork`'s two sessions are the only ones, so
            // every request is update traffic with their configuration.
            Placement(
                literals: ["URLSession"],
                pattern: words(#/\bURLSession\s*(?:\.\s*init\s*)?\(/#),
                allowed: ["BatteryPulseApp/Updates/UpdateChecker.swift": 2],
                message: "a new URLSession; use UpdateNetwork's sessions"),
            // W-13: the version count is requested in one place, the automatic update check.
            Placement(
                literals: ["VersionCounterPolicy"],
                pattern: words(#/\bVersionCounterPolicy\s*\.\s*url\b/#),
                allowed: ["BatteryPulseApp/Updates/UpdateChecker.swift": 1],
                message: "the version count's URL only in the update checker"),
            Placement(
                literals: ["IOServiceOpen", "IOConnect"],
                pattern: words(#/\bIOServiceOpen\b|\bIOConnect\w+/#),
                allowed: ["BatterySource/SMCClient.swift": .max],
                message: "an IOKit user client only in the SMC client"),
            Placement(
                literals: ["IORegistryEntrySetCFPropert"],
                pattern: words(#/\bIORegistryEntrySetCFPropert(?:y|ies)\b/#),
                allowed: [:],
                message: "the I/O Registry is only read"),
            // SW-05: work leaves the caller's actor through `@concurrent` functions. The one
            // detached task left is the installer's fire-and-forget cleanup of a previous copy.
            Placement(
                literals: ["detached"],
                pattern: words(#/\bTask\s*\.\s*detached\b/#),
                allowed: ["BatteryPulseApp/Updates/UpdateInstaller.swift": 1],
                message: "Task.detached; offload with a @concurrent function"),
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
            // SW-R6: the four types whose safety the compiler can't check, each saying why: a C
            // function table, two that C callbacks reach, and a pair of immutable images.
            Placement(
                literals: ["@unchecked"],
                pattern: words(#/@unchecked\s+Sendable\b/#),
                allowed: [
                    "BatteryKit/MobileDevice/MobileDeviceLibrary.swift": 1,
                    "BatteryKit/MobileDevice/MobileDeviceTransport.swift": 1,
                    "BatteryKit/MobileDevice/USBDeviceWatcher.swift": 1,
                    "BatteryPulseApp/MenuBar/BatteryIconView.swift": 1,
                ],
                message: "@unchecked Sendable; use a checked Sendable (Mutex, a let) or an actor"),
            // The observers' tokens, which the remover reads from any thread (SystemNotifications).
            Placement(
                literals: ["nonisolated", "unowned"],
                pattern: words(#/\b(?:nonisolated|unowned)\s*\(\s*unsafe\s*\)/#),
                allowed: ["BatterySource/SystemNotifications.swift": 1],
                message: "nonisolated(unsafe) or unowned(unsafe); use a Mutex, a Sendable value or an actor"),
            // SW-13: the types that keep a C function address or a pointer behind a safe
            // interface, each saying why.
            Placement(
                literals: ["@safe"],
                pattern: words(#/@safe\b/#),
                allowed: [
                    "BatteryKit/MobileDevice/MobileDeviceLibrary.swift": 1,
                    "BatteryKit/MobileDevice/MobileDeviceTransport.swift": 1,
                    "BatteryKit/MobileDevice/USBDeviceWatcher.swift": 1,
                    "BatterySource/MacAccessoryProvider.swift": 1,
                ],
                message: "@safe; mark each unsafe use `unsafe` with its reason instead"),
            Placement(
                literals: ["StrictMemorySafety"],
                pattern: words(#/\bStrictMemorySafety\b/#),
                allowed: [:],
                message: "StrictMemorySafety silenced; mark each unsafe use `unsafe` with its reason"),
        ]
    }

    /// The targets that build with strict memory safety: the parsers of untrusted input
    /// (BatteryCore, bpulse) and the system bindings (BatterySource, BatteryKit).
    static let strictMemorySafetyTargets = ["BatteryCore", "BatterySource", "BatteryKit", "bpulse"]

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

    /// Every folder of `Sources` is a target the scan lists, so a new target can't escape the
    /// guards: ``scansEveryTarget()`` only checks the listed ones.
    @Test func everySourceFolderIsAListedTarget() throws {
        let folders = try FileManager.default.contentsOfDirectory(
            at: SourceScanner.sources, includingPropertiesForKeys: [.isDirectoryKey]
        )
        .filter { (try? $0.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true }
        .map(\.lastPathComponent)
        #expect(folders.sorted() == (SourceScanner.targets + SourceScanner.otherTargets).sorted())
    }

    @Test func allowListedFilesExist() {
        for path in Self.placements.flatMap(\.allowed.keys) {
            #expect(
                FileManager.default.fileExists(atPath: SourceScanner.sources.appendingPathComponent(path).path),
                "\(path)")
        }
    }

    /// SEC-03: no request goes through the shared session.
    @Test func noSharedURLSession() {
        #expect(flags("let (data, response) = try await URLSession.shared.data(for: request)"))
        #expect(flags("let session = URLSession .shared", path: "BatteryPulseApp/Updates/UpdateChecker.swift"))
        #expect(!flags("let (data, _) = try await UpdateNetwork.user.data(for: request)"))
        #expect(!flags("let session = URLSession(configuration: .ephemeral)", path: Self.updateChecker))
    }

    private static let updateChecker = "BatteryPulseApp/Updates/UpdateChecker.swift"

    /// W-13: `UpdateNetwork`'s two sessions are the only ones.
    @Test func sessionsOnlyInUpdateNetwork() {
        let sessions = "static let user = URLSession(configuration: configuration(automatic: false))\n"
        #expect(!flags(sessions + sessions, path: Self.updateChecker))
        #expect(flags(sessions + sessions + sessions, path: Self.updateChecker))
        #expect(flags(sessions, path: "BatteryPulseApp/Updates/UpdateInstaller.swift"))
        #expect(flags("let session = URLSession.init(configuration: .default)", path: "BatteryCore/Updates.swift"))
        #expect(!flags("let configuration = URLSessionConfiguration.ephemeral"))
        #expect(!flags("func fetch(session: URLSession) async throws -> Data"))
        #expect(!flags("let task = session.dataTask(with: request)"))
    }

    /// W-13: the version count's URL is taken once, by the update checker.
    @Test func versionCountURLInOnePlace() {
        let request = "guard let url = VersionCounterPolicy.url(for: currentVersion) else { return }\n"
        #expect(!flags(request, path: Self.updateChecker))
        #expect(flags(request + request, path: Self.updateChecker))
        #expect(flags(request, path: "BatteryPulseApp/Updates/UpdateInstaller.swift"))
        #expect(flags(request, path: "BatteryPulseApp/App/BatteryPulseApp.swift"))
        #expect(!flags("let due = VersionCounterPolicy.shouldCount(enabled: on, frequency: frequency)"))
        #expect(!flags("let urlString = VersionCounterPolicy.urlString", path: "BatteryCore/Updates.swift"))
    }

    /// The SMC client's one user-client call: `IOConnectCallStructMethod` with selector 2
    /// (`kSMCHandleYPCEvent`), which carries the read commands that `SMCTests` pins.
    @Test func smcClientCallsOnlySelectorTwo() throws {
        let code = try #require(
            try SourceScanner.allFiles.get().first { $0.path == "BatterySource/SMCClient.swift" }
        ).code
        let calls = SourceScanner.calls(named: Self.words(#/\bIOConnect\w+/#), in: code)
        #expect(calls.map(\.name) == ["IOConnectCallStructMethod"])
        #expect(calls.first?.topLevelArguments.dropFirst().first == "Self.selector")
        #expect(code.contains(Self.words(#/\bstatic\s+let\s+selector\s*:\s*UInt32\s*=\s*2\b/#)))
    }

    /// SW-05: one detached task, the installer's leftover cleanup.
    @Test func oneDetachedTask() {
        let installer = "BatteryPulseApp/Updates/UpdateInstaller.swift"
        let detached = "Task.detached(name: \"x\", priority: .utility) { work() }\n"
        #expect(!flags(detached, path: installer))
        #expect(flags(detached + detached, path: installer))
        #expect(flags(detached, path: "BatteryPulseApp/Main/MainView.swift"))
        #expect(!flags("Task(name: \"x\") { await work() }", path: "BatteryPulseApp/Main/MainView.swift"))
    }

    private static let somewhere = "BatterySource/MacBatteryProvider.swift"

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
        "nonisolated(unsafe) let tokens = names.map { $0 }",
        "unowned(unsafe) let owner: Owner",
        "@safe final class Box { private var pointer: UnsafeMutableRawPointer? }",
        "@diagnose(StrictMemorySafety, as: ignored, reason: \"audited\") func read() {}",
        "let session = URLSession(configuration: .ephemeral)",
        "let session = URLSession .init(configuration: configuration)",
        "let url = VersionCounterPolicy.url(for: version)",
        "let url = VersionCounterPolicy . url(for: version)",
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
        "let name = unsafe String(cString: pointer)",
        "nonisolated let safeArea = 1",
        "@safeAreaPadding var inset = 0",
    ])
    func allows(source: String) {
        #expect(!flags(source), "\(Self.violations(in: source, path: Self.somewhere))")
    }

    @Test func eachAPIIsAllowedOnlyWhereItIsToday() {
        #expect(!flags("dlsym(handle, name)", path: "BatteryKit/MobileDevice/MobileDeviceLibrary.swift"))
        #expect(!flags("dlopen(path, RTLD_NOW)", path: "BatterySource/MacAccessoryProvider.swift"))
        #expect(flags("dlopen(path, RTLD_NOW)", path: "BatterySource/SMCClient.swift"))
        #expect(!flags("IOServiceOpen(service, task, 0, &port)", path: "BatterySource/SMCClient.swift"))
        #expect(flags("IOServiceOpen(service, task, 0, &port)", path: "BatteryKit/MobileDevice/USBDeviceWatcher.swift"))
        #expect(flags("IOServiceOpen(service, task, 0, &port)", path: "BatterySource/MacBatteryProvider.swift"))
        #expect(flags("IORegistryEntrySetCFProperty(entry, key, value)", path: "BatterySource/SMCClient.swift"))
        #expect(!flags("let process = Process()", path: "BatteryPulseApp/Updates/UpdateInstaller.swift"))
        #expect(flags("let process = Process()", path: "bpulse/main.swift"))
        #expect(!flags("kill(pid, SIGTERM)", path: "BatteryPulseApp/App/WidgetRefresher.swift"))
        #expect(flags("kill(pid, SIGTERM)", path: "BatteryPulseApp/Updates/UpdateInstaller.swift"))
    }

    /// SW-R6: four `@unchecked Sendable` types, one in each listed file.
    @Test func fourUncheckedSendableTypes() {
        let allowed = Self.placements.first { $0.message.hasPrefix("@unchecked") }?.allowed ?? [:]
        #expect(allowed.values.reduce(0, +) == 4)
        let watcher = "final class DownloadWatcher: @unchecked Sendable {}"
        #expect(flags(watcher, path: "BatteryPulseApp/Updates/UpdateInstaller.swift"))
        let sink = "final class MobileDeviceSink: @unchecked Sendable {}\n"
        #expect(!flags(sink, path: "BatteryKit/MobileDevice/MobileDeviceTransport.swift"))
        #expect(flags(sink + sink, path: "BatteryKit/MobileDevice/MobileDeviceTransport.swift"))
        #expect(!flags("final class DownloadWatcher: Sendable {}"))
    }

    /// SW-13: four `@safe` types, one in each listed file: the accessory function's address, the
    /// MobileDevice function table, a device link's service connection and the USB watch's port.
    @Test func fourSafeTypes() {
        let allowed = Self.placements.first { $0.message.hasPrefix("@safe") }?.allowed ?? [:]
        #expect(allowed.values.reduce(0, +) == 4)
        let link = "@safe\nfinal class MobileDeviceLink {}\n"
        #expect(!flags(link, path: "BatteryKit/MobileDevice/MobileDeviceTransport.swift"))
        #expect(flags(link + link, path: "BatteryKit/MobileDevice/MobileDeviceTransport.swift"))
        #expect(flags(link, path: "BatteryKit/IDeviceMonitor.swift"))
    }

    /// SW-13: the targets that build with strict memory safety are exactly the listed ones, so a
    /// target can't lose the check unnoticed.
    @Test func strictMemorySafetyTargetsAreTheListedOnes() throws {
        let manifest = SourceScanner.sources.deletingLastPathComponent().appendingPathComponent("Package.swift")
        let text = try String(contentsOf: manifest, encoding: .utf8)
        // `codeOnly` blanks string literals, so a target's name is read from `text` at the same
        // offsets (as in `IsolationGuardTests`).
        let code = SourceScanner.codeOnly(text)
        let targets = SourceScanner.calls(named: Self.words(#/\.(?:executableTarget|testTarget|target)\b/#), in: code)
        var strict: [String] = []
        for target in targets where target.arguments.contains(".strictMemorySafety()") {
            let offset = code.distance(from: code.startIndex, to: target.arguments.startIndex)
            let start = text.index(text.startIndex, offsetBy: offset)
            let arguments = text[start...].prefix(target.arguments.count)
            strict.append(arguments.firstMatch(of: #/name:\s*"(\w+)"/#).map { String($0.output.1) } ?? "?")
        }
        #expect(targets.count >= 8)
        #expect(strict.sorted() == Self.strictMemorySafetyTargets.sorted())
    }

    @Test func reportsLineNumbers() {
        let violations = Self.violations(in: "let a = 1\n// dlopen\nlet h = dlopen(p, 0)\n", path: "X.swift")
        #expect(violations == ["X.swift:3: dlopen/dlsym only for MobileDevice and the accessory power sources"])
    }
}
