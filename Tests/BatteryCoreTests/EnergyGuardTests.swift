import BatteryCore
import Foundation
import Testing

/// Keeps the energy rules of CLAUDE.md in every target, Darwin code included (C4).
///
/// Scans every Swift file of `Sources` with comments and string literals blanked out
/// (``SourceScanner/allFiles``). It fails on:
/// - EN-1: a `sleep(for:)` without a `tolerance:` of at least a tenth of the interval, unless it
///   is one of the four ``oneShots``, and `sleep(nanoseconds:)`, which takes no tolerance. The
///   tolerance lets macOS fire the wake-up together with others;
/// - EN-2: a timer (`Timer`, a Combine timer, `DispatchSourceTimer`), and `asyncAfter` outside
///   the iPhone and iPad transport's timeouts: wake-ups come from tasks that sleep;
/// - EN-8: `beginActivity`, a power assertion or `performExpiringActivity` outside the installer,
///   whose one activity is user-initiated and ended by a `defer`;
/// - EN-11: a widget reload outside `WidgetRefresher`, which asks `WidgetReloadPlanner`.
@Suite struct EnergyGuardTests {
    /// A sleep without a tolerance: it runs once per user action, or in a terminal.
    struct OneShot: Sendable {
        /// Relative to `Sources/`.
        var path: String
        /// The `for:` argument, as written.
        var interval: String
        var reason: String
    }

    static let oneShots = [
        OneShot(
            path: "BatteryPulseApp/Main/MainView.swift", interval: ".seconds(1.5)",
            reason: "Copy Report's \"Copied\" label, once per click"),
        OneShot(
            path: "BatteryPulseApp/App/WidgetRefresher.swift", interval: ".seconds(1)",
            reason: "the wait after ending the previous widget extension, once after an update or a language change"),
        OneShot(
            path: "bpulse/main.swift", interval: ".seconds(interval)",
            reason: "bpulse --watch: the interval the user typed, while it runs in a terminal"),
        OneShot(
            path: "bpulse/Record.swift", interval: "CaptureRecorder.sampleInterval",
            reason: "bpulse --record: a sample every 5 s while the user records"),
    ]

    /// Constants from other files that intervals use, in seconds.
    static let constants: [String: Double] = ["HistoryPolicy.interval": HistoryPolicy.interval]

    /// An API that may appear only in the listed files.
    struct Placement {
        /// Every match holds one of these, so a file without any is skipped: a `Regex` is slow on
        /// Linux, and most files use none of the APIs. `catches(source:)` checks the cases.
        var literals: [String]
        var pattern: Regex<Substring>
        var allowed: Set<String>
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
                literals: ["Timer"],
                pattern: words(#/\b(?:NS)?Timer\b|\bCFRunLoopTimer\w*|\bDispatchSourceTimer\b|\bmakeTimerSource\b/#),
                allowed: [],
                message: "a timer; sleep in a task with a tolerance instead"),
            Placement(
                literals: ["asyncAfter"],
                pattern: words(#/\basyncAfter\b/#),
                allowed: ["BatteryKit/IDeviceTransport.swift"],
                message: "asyncAfter; sleep in a task with a tolerance instead"),
            Placement(
                literals: ["beginActivity", "IOPMAssertion", "performExpiringActivity"],
                pattern: words(#/\bbeginActivity\b|\bIOPMAssertion\w*|\bperformExpiringActivity\b/#),
                allowed: ["BatteryPulseApp/Updates/UpdateInstaller.swift"],
                message: "an activity or power assertion outside the installer"),
            Placement(
                literals: ["reloadAllTimelines", "reloadTimelines"],
                pattern: words(#/\breloadAllTimelines\b|\breloadTimelines\b/#),
                allowed: ["BatteryPulseApp/App/WidgetRefresher.swift"],
                message: "a widget reload outside WidgetRefresher and its WidgetReloadPlanner"),
        ]
    }

    // MARK: Tolerances

    /// `expression` with its white space removed, for comparing expressions.
    private static func normalized(_ expression: String) -> String {
        expression.filter { !$0.isWhitespace }
    }

    /// The tolerance's share of the interval, or `nil` if it can't tell. Either the tolerance is
    /// the interval divided by a number (`tick / 10`, `.seconds(s / 10)` for `.seconds(s)`), or
    /// both have values in seconds (``seconds(_:in:)``).
    static func toleranceShare(interval: String, tolerance: String, in code: String) -> Double? {
        let interval = normalized(interval)
        let tolerance = normalized(tolerance)
        if let match = tolerance.wholeMatch(of: #/(.+)/([0-9.]+)/#), String(match.1) == interval {
            return Double(match.2).map { 1 / $0 }
        }
        if let outer = interval.wholeMatch(of: #/(\.\w+)\((.+)\)/#),
            let match = tolerance.wholeMatch(of: #/(\.\w+)\((.+)/([0-9.]+)\)/#),
            match.1 == outer.1, match.2 == outer.2
        {
            return Double(match.3).map { 1 / $0 }
        }
        guard let duration = seconds(interval, in: code), duration > 0,
            let allowance = seconds(tolerance, in: code)
        else { return nil }
        return allowance / duration
    }

    /// The seconds `expression` stands for: a `Duration` such as `.milliseconds(150)` or
    /// `.seconds(6 * 60 * 60)`, a number, a product or quotient of those, a `let` of the same file,
    /// or one of ``constants``; `nil` if it can't tell.
    static func seconds(_ expression: String, in code: String, depth: Int = 0) -> Double? {
        let expression = normalized(expression)
        guard depth < 5, !expression.isEmpty else { return nil }
        // A product or quotient, split at its last top-level operator.
        var level = 0
        for index in expression.indices.reversed() {
            let character = expression[index]
            if character == ")" {
                level += 1
            } else if character == "(" {
                level -= 1
            } else if level == 0, character == "*" || character == "/" {
                guard let left = seconds(String(expression[..<index]), in: code, depth: depth + 1),
                    let right = seconds(
                        String(expression[expression.index(after: index)...]), in: code, depth: depth + 1)
                else { return nil }
                return character == "*" ? left * right : (right == 0 ? nil : left / right)
            }
        }
        if let number = Double(expression.replacing("_", with: "")) { return number }
        if expression == ".zero" || expression == "Duration.zero" { return 0 }
        if let match = expression.wholeMatch(
            of: #/(?:Duration)?\.(seconds|milliseconds|microseconds|nanoseconds)\((.+)\)/#)
        {
            let scale: Double =
                switch match.1 {
                case "seconds": 1
                case "milliseconds": 1e-3
                case "microseconds": 1e-6
                default: 1e-9
                }
            return seconds(String(match.2), in: code, depth: depth + 1).map { $0 * scale }
        }
        if let constant = constants[expression] { return constant }
        // A `let` of this file, such as `static let coalescingWindow: Duration = .milliseconds(150)`.
        guard let name = expression.wholeMatch(of: #/(?:Self\.)?(\w+)/#)?.1,
            let declaration = try? Regex(#"\blet\s+"# + name + #"\s*(?::\s*[\w.]+\s*)?=[ \t]*([^\n]+)"#),
            let value = code.firstMatch(of: declaration.wordBoundaryKind(.simple))?.output[1].substring
        else { return nil }
        return seconds(String(value), in: code, depth: depth + 1)
    }

    // MARK: Rules

    /// Every rule broken in `source`, as "path:line: message".
    static func violations(in source: String, path: String) -> [String] {
        violations(inCode: SourceScanner.codeOnly(source), path: path)
    }

    /// Every rule broken in `code`, a source already blanked by ``SourceScanner/codeOnly(_:)``.
    static func violations(inCode code: String, path: String) -> [String] {
        var found: [(String.Index, String)] = []
        func flag(_ index: String.Index, _ message: String) { found.append((index, message)) }

        // Most files don't sleep; a `Regex` over them is slow on Linux.
        let sleeps = code.contains("sleep") ? SourceScanner.calls(named: words(#/\bsleep/#), in: code) : []
        for call in sleeps {
            if call.argument(labeled: "nanoseconds") != nil {
                flag(call.start, "sleep(nanoseconds:) takes no tolerance; use sleep(for:tolerance:)")
                continue
            }
            // `Thread.sleep(forTimeInterval:)` and a clock closure's `sleep(until)` aren't task sleeps.
            guard let interval = call.argument(labeled: "for") else { continue }
            guard let tolerance = call.argument(labeled: "tolerance") else {
                let isOneShot = oneShots.contains { $0.path == path && normalized($0.interval) == normalized(interval) }
                if !isOneShot {
                    flag(call.start, "sleep(for: \(interval)) needs a tolerance of at least 10 % of the interval")
                }
                continue
            }
            guard let share = toleranceShare(interval: interval, tolerance: tolerance, in: code) else {
                flag(call.start, "can't tell \(tolerance)'s share of \(interval); write it as the interval / 10")
                continue
            }
            if share < 0.1 - 1e-9 {
                let percent = Int((share * 100).rounded())
                flag(call.start, "a tolerance of \(percent) % of the interval; at least 10 %")
            }
        }
        for placement in placements
        where !placement.allowed.contains(path) && placement.literals.contains(where: { code.contains($0) }) {
            for match in code.matches(of: placement.pattern) {
                flag(match.range.lowerBound, placement.message)
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
    func sourcesFollowTheEnergyRules(_ file: SourceScanner.File) {
        let violations = Self.violations(inCode: file.code, path: file.path)
        #expect(violations.isEmpty, "\(violations.joined(separator: "\n"))")
    }

    /// The four one-shots are where the list says, with no tolerance: the list stays current.
    @Test func oneShotsAreTheFourListed() throws {
        #expect(Self.oneShots.count == 4)
        let files = try SourceScanner.allFiles.get()
        for oneShot in Self.oneShots {
            let code = try #require(files.first { $0.path == oneShot.path }, "\(oneShot.path)").code
            let sleeps = SourceScanner.calls(named: Self.words(#/\bsleep/#), in: code).filter { call in
                call.argument(labeled: "for").map(Self.normalized) == Self.normalized(oneShot.interval)
                    && call.argument(labeled: "tolerance") == nil
            }
            #expect(sleeps.count == 1, "\(oneShot.path): \(oneShot.interval)")
        }
    }

    @Test func allowListedFilesExist() {
        for path in Self.placements.flatMap(\.allowed) {
            #expect(
                FileManager.default.fileExists(atPath: SourceScanner.sources.appendingPathComponent(path).path),
                "\(path)")
        }
    }

    /// The installer's activity, if it holds one: user-initiated, ended by a `defer`, so the Mac
    /// can idle-sleep again whichever way the install ends.
    @Test func theInstallersActivityIsUserInitiatedAndEnded() throws {
        let path = "BatteryPulseApp/Updates/UpdateInstaller.swift"
        let code = try #require(try SourceScanner.allFiles.get().first { $0.path == path }).code
        let activities = SourceScanner.calls(named: Self.words(#/\bbeginActivity/#), in: code)
        for activity in activities {
            #expect(activity.argument(labeled: "options") == ".userInitiated")
        }
        let ends = code.matches(of: Self.words(#/\bdefer\s*\{\s*ProcessInfo\.processInfo\.endActivity\s*\(/#))
        #expect(ends.count == activities.count)
    }

    private static let somewhere = "BatteryPulseApp/Main/OverviewView.swift"

    private func flags(_ source: String, path: String = somewhere) -> Bool {
        !Self.violations(in: source, path: path).isEmpty
    }

    @Test(arguments: [
        // EN-1
        "try await Task.sleep(for: .seconds(60))",
        "try await Task.sleep(for: .seconds(60), tolerance: .seconds(5))",
        "try await Task.sleep(for: .seconds(6 * 60 * 60), tolerance: .seconds(30 * 60))",
        "try await clock.sleep(for: interval, tolerance: interval / 20)",
        "try await Task.sleep(for: .milliseconds(500), tolerance: .milliseconds(10))",
        "try await Task.sleep(for: .seconds(1), tolerance: .zero)",
        "try await Task.sleep(for: tick, tolerance: slack)",
        "try await Task.sleep(nanoseconds: 1_000_000_000)",
        // A one-shot's interval in another file.
        "try await Task.sleep(for: .seconds(1.5))",
        // EN-2
        "Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in }",
        "let ticks = Timer.publish(every: 1, on: .main, in: .common).autoconnect()",
        "let source = DispatchSource.makeTimerSource(queue: queue)",
        "var timer: DispatchSourceTimer?",
        "DispatchQueue.main.asyncAfter(deadline: .now() + 1) { refresh() }",
        // EN-8
        "let activity = ProcessInfo.processInfo.beginActivity(options: .background, reason: \"x\")",
        "IOPMAssertionCreateWithName(type, level, name, &id)",
        "ProcessInfo.processInfo.performExpiringActivity(withReason: \"x\") { _ in }",
        // EN-11
        "WidgetCenter.shared.reloadAllTimelines()",
        "WidgetCenter.shared.reloadTimelines(ofKind: kind)",
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
        "try await Task.sleep(for: .seconds(6 * 60 * 60), tolerance: .seconds(36 * 60))",
        "try await Task.sleep(for: .seconds(20), tolerance: .seconds(5))",
        "try await Task.sleep(for: .milliseconds(200), tolerance: .milliseconds(50))",
        "try? await clock.sleep(for: gap, tolerance: gap / 10)",
        "try? await Task.sleep(for: delay, tolerance: delay / 2)",
        "try await Task.sleep(for: .seconds(seconds), tolerance: .seconds(seconds / 10), clock: .continuous)",
        "try await Task.sleep(for: .seconds(HistoryPolicy.interval), tolerance: .seconds(15))",
        """
        static let window: Duration = .milliseconds(150)
        static let slack: Duration = .milliseconds(100)
        func wait() async { try? await clock.sleep(for: Self.window, tolerance: Self.slack) }
        """,
        "Thread.sleep(forTimeInterval: 0.1)",
        "do { try await clock.sleep(until) } catch { return }",
        "func sleep(for duration: Duration, tolerance: Duration?) async throws {}",
        "// Timer.publish and asyncAfter in a comment",
        "Text(\"reloadAllTimelines\")",
        "let info = ProcessInfo.processInfo.thermalState",
        "TimelineView(.everyMinute) { _ in Text(\"x\") }",
    ])
    func allows(source: String) {
        #expect(!flags(source), "\(Self.violations(in: source, path: Self.somewhere))")
    }

    @Test func eachAPIIsAllowedOnlyWhereItIsToday() {
        let asyncAfter = "DispatchQueue.global().asyncAfter(deadline: .now() + timeout) { timedOut() }"
        #expect(!flags(asyncAfter, path: "BatteryKit/IDeviceTransport.swift"))
        #expect(flags(asyncAfter, path: "BatteryKit/IDeviceMonitor.swift"))
        let activity = "let activity = ProcessInfo.processInfo.beginActivity(options: .userInitiated, reason: \"x\")"
        #expect(!flags(activity, path: "BatteryPulseApp/Updates/UpdateInstaller.swift"))
        #expect(flags(activity, path: "BatteryPulseApp/Updates/UpdateChecker.swift"))
        let reload = "WidgetCenter.shared.reloadAllTimelines()"
        #expect(!flags(reload, path: "BatteryPulseApp/App/WidgetRefresher.swift"))
        #expect(flags(reload, path: "BatteryPulseWidget/BatteryPulseWidget.swift"))
        let copied = "try? await Task.sleep(for: .seconds(1.5))"
        #expect(!flags(copied, path: "BatteryPulseApp/Main/MainView.swift"))
        #expect(flags(copied, path: "BatteryPulseApp/Main/PowerView.swift"))
    }

    @Test func toleranceShares() {
        #expect(Self.toleranceShare(interval: "tick", tolerance: "tick / 10", in: "") == 0.1)
        #expect(Self.toleranceShare(interval: ".seconds(s)", tolerance: ".seconds(s / 4)", in: "") == 0.25)
        #expect(Self.toleranceShare(interval: ".seconds(6 * 60 * 60)", tolerance: ".seconds(36 * 60)", in: "") == 0.1)
        #expect(Self.toleranceShare(interval: ".seconds(1)", tolerance: ".milliseconds(250)", in: "") == 0.25)
        #expect(Self.toleranceShare(interval: "tick", tolerance: "other / 10", in: "") == nil)
        #expect(Self.seconds("Duration.milliseconds(1_500)", in: "") == 1.5)
    }

    @Test func reportsLineNumbers() {
        let violations = Self.violations(in: "let a = 1\n// Timer\nlet t = Timer.publish(every: 1)\n", path: "X.swift")
        #expect(violations == ["X.swift:3: a timer; sleep in a task with a tolerance instead"])
    }
}
