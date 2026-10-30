import Foundation
import Testing

/// Keeps the app's actor isolation where `Package.swift` and the code put it (WP-10).
///
/// BatteryPulseApp runs on the main actor by default (`defaultIsolation(MainActor.self)`), and no
/// other target does: the widget stays nonisolated because WidgetKit calls its timeline provider
/// on threads of its own. Scanning the app's Swift files with comments and string literals blanked
/// out (``SourceScanner/files``), it fails on:
/// - a `@MainActor` in the app other than the four ``mainActorSites``, the places default
///   isolation doesn't reach: a closure property's function type, and a task started in a
///   `@Sendable` closure;
/// - an ``offMain`` declaration that lost its `nonisolated`: code that a framework calls on its
///   own threads, or that runs off the main actor, would otherwise turn main-actor without a
///   diagnostic and trap at run time, or hop to the main actor and block it.
@Suite struct IsolationGuardTests {
    /// The `@MainActor`s the app keeps, by path relative to `Sources/`: how each starts, from the
    /// attribute on, with whitespace runs collapsed.
    static let mainActorSites: [String: [String]] = [
        // A main-actor function type: the pages call it to show a device in History.
        "BatteryPulseApp/Main/MainView.swift": ["@MainActor (DeviceKey) -> Void", "@MainActor (DeviceKey) -> Void"],
        "BatteryPulseApp/Main/DeviceView.swift": ["@MainActor (DeviceKey) -> Void"],
        // Inside the appearance observation's `@Sendable` change handler, whose tasks don't
        // inherit the default isolation.
        "BatteryPulseApp/App/WindowLook.swift": ["@MainActor in SystemAppearance.shared.update()"],
    ]

    /// A declaration that must stay `nonisolated` in the app.
    struct OffMain: Sendable, CustomTestStringConvertible {
        /// Relative to `Sources/`.
        var path: String
        /// As written, with whitespace runs collapsed.
        var declaration: String
        /// How often the declaration appears in the file.
        var count = 1
        var reason: String

        var testDescription: String { declaration }
    }

    static let offMain = [
        OffMain(
            path: "BatteryPulseApp/Updates/UpdateInstaller.swift", declaration: "nonisolated enum UpdateInstallSteps",
            reason:
                "verify and replace are @concurrent; mounting, the code signature check and the tools' termination handlers must not drift onto the main actor"
        ),
        OffMain(
            path: "BatteryPulseApp/Updates/UpdateInstaller.swift",
            declaration: "private nonisolated final class DownloadWatcher",
            reason: "URLSession calls it on its delegate queue"),
        OffMain(
            path: "BatteryPulseApp/App/WidgetRefresher.swift",
            declaration: "nonisolated static func endExtensionBeforeSwap()",
            reason:
                "the installer's @concurrent swap awaits it; on the main actor the swap would wait behind the UI's work"
        ),
        OffMain(
            path: "BatteryPulseApp/App/WidgetRefresher.swift",
            declaration: "private nonisolated static func extensionProcesses()",
            reason: "the process scan that endExtensionBeforeSwap runs off the main actor"),
        OffMain(
            path: "BatteryPulseApp/App/WidgetRefresher.swift",
            declaration: "private nonisolated static let extensionExecutable",
            reason: "the scan reads it off the main actor, and a static of a main-actor type is main-actor"),
        OffMain(
            path: "BatteryPulseApp/App/WidgetRefresher.swift", declaration: "private nonisolated enum PlacedWidgets",
            reason:
                "its @concurrent function asks WidgetKit for the placed widgets off the main actor, so the WidgetCenter it calls never crosses actors"
        ),
        OffMain(
            path: "BatteryPulseApp/MenuBar/BatteryIconView.swift",
            declaration: "private nonisolated final class AppearanceVariants",
            reason: "it draws in an NSImage drawing handler, which AppKit calls whenever it draws"),
        OffMain(
            path: "BatteryPulseApp/MenuBar/BatteryIconView.swift",
            declaration: "private nonisolated static func adaptiveImage(",
            reason: "it forms that drawing handler, which would otherwise inherit the main actor"),
        OffMain(
            path: "BatteryPulseApp/App/BatteryNotifier.swift",
            declaration: "extension BatteryNotifier: nonisolated UNUserNotificationCenterDelegate",
            reason: "UserNotifications calls its delegate on a queue of its own"),
        OffMain(
            path: "BatteryPulseApp/App/BatteryNotifier.swift", declaration: "nonisolated func userNotificationCenter(",
            count: 2, reason: "the delegate's two methods"),
        OffMain(
            path: "BatteryPulseApp/Main/RawValueText.swift", declaration: "nonisolated enum RawValueText",
            reason: "the Raw Data table is built off the main actor"),
        OffMain(
            path: "BatteryPulseApp/Main/History/HistoryView.swift",
            declaration: "private nonisolated struct HistoryLoad",
            reason: "History reads and builds its charts off the main actor"),
        OffMain(
            path: "BatteryPulseApp/Main/History/HistoryView.swift", declaration: "nonisolated enum HistorySource",
            reason: "the History load compares it off the main actor"),
        OffMain(
            path: "BatteryPulseApp/App/Diagnostics.swift", declaration: "nonisolated enum Diagnostics",
            reason: "the work off the main actor logs and measures"),
        OffMain(
            path: "BatteryPulseApp/App/Diagnostics.swift", declaration: "nonisolated var signpostName",
            reason: "the page.switch signpost names its page"),
        OffMain(
            path: "BatteryPulseApp/App/Localized.swift", declaration: "nonisolated static let app = BatteryFormatter(",
            reason: "the Raw Data table formats its values off the main actor"),
        OffMain(
            path: "BatteryPulseApp/Main/Components/Card.swift", declaration: "private nonisolated enum CardGroupSpace",
            reason: "a @Sendable geometry transform reads it"),
        OffMain(
            path: "BatteryPulseApp/Welcome/AppIconView.swift", declaration: "private nonisolated struct PulseLine",
            reason: "Shape's requirements are nonisolated: SwiftUI may ask for the path off the main actor"),
    ]

    /// `\b` as in most regex engines (see `MotionGuardTests`).
    private static func words(_ regex: Regex<Substring>) -> Regex<Substring> {
        regex.wordBoundaryKind(.simple)
    }

    /// `text` with every run of whitespace turned into one space.
    static func collapsed(_ text: some StringProtocol) -> String {
        text.split(whereSeparator: \.isWhitespace).joined(separator: " ")
    }

    /// The `@MainActor` attributes in `code`, a source already blanked by
    /// ``SourceScanner/codeOnly(_:)``, each with what follows it on its line.
    static func mainActors(inCode code: String) -> [String] {
        guard code.contains("@MainActor") else { return [] }
        return code.matches(of: words(#/@MainActor\b[^\n]*/#)).map { collapsed($0.output) }
    }

    /// Every rule `code` breaks as the file at `path`, as "path: message".
    static func violations(inCode code: String, path: String) -> [String] {
        var found: [String] = []
        let sites = mainActorSites[path] ?? []
        let attributes = mainActors(inCode: code)
        if attributes.count != sites.count {
            found.append(
                "\(path): \(attributes.count) @MainActor, expected \(sites.count); the app is main-actor by default")
        }
        // Each kept site takes one attribute, so two identical sites need two matching ones.
        var unmatched = attributes
        for site in sites {
            if let index = unmatched.firstIndex(where: { $0.hasPrefix(site) }) {
                unmatched.remove(at: index)
            } else {
                found.append("\(path): the kept @MainActor \"\(site)\" is gone")
            }
        }
        let text = collapsed(code)
        for rule in offMain where rule.path == path {
            let count = text.ranges(of: rule.declaration).count
            if count != rule.count {
                found.append("\(path): \"\(rule.declaration)\" \(count) times, expected \(rule.count): \(rule.reason)")
            }
        }
        return found
    }

    // MARK: Tests

    /// One case per app file, so a failure names the file.
    @Test(arguments: ((try? SourceScanner.files.get()) ?? []).filter { $0.path.hasPrefix("BatteryPulseApp/") })
    func appKeepsItsIsolation(_ file: SourceScanner.File) {
        let violations = Self.violations(inCode: file.code, path: file.path)
        #expect(violations.isEmpty, "\(violations.joined(separator: "\n"))")
    }

    /// Four `@MainActor`s, in files the scan reads, like every file with an off-main declaration;
    /// so the per-file test above has cases, and a moved file can't drop out of it unnoticed.
    @Test func listedFilesAreScanned() throws {
        #expect(Self.mainActorSites.values.map(\.count).reduce(0, +) == 4)
        let scanned = Set(try SourceScanner.files.get().map(\.path))
        for path in Set(Self.mainActorSites.keys).union(Self.offMain.map(\.path)) {
            #expect(scanned.contains(path), "\(path)")
        }
    }

    /// Only the app's target sets a default isolation, and it is the main actor.
    @Test func onlyTheAppIsMainActorByDefault() throws {
        let manifest = SourceScanner.sources.deletingLastPathComponent().appendingPathComponent("Package.swift")
        let text = try String(contentsOf: manifest, encoding: .utf8)
        // `codeOnly` blanks string literals, so a target's name is read from `text` at the same
        // offsets.
        let code = SourceScanner.codeOnly(text)
        let targets = SourceScanner.calls(named: Self.words(#/\.(?:executableTarget|testTarget|target)\b/#), in: code)
        var isolated: [String] = []
        for target in targets where target.arguments.contains("defaultIsolation") {
            let offset = code.distance(from: code.startIndex, to: target.arguments.startIndex)
            let start = text.index(text.startIndex, offsetBy: offset)
            let arguments = text[start...].prefix(target.arguments.count)
            isolated.append(arguments.firstMatch(of: #/name:\s*"(\w+)"/#).map { String($0.output.1) } ?? "?")
            #expect(target.arguments.contains(".defaultIsolation(MainActor.self)"))
        }
        #expect(targets.count >= 8)
        #expect(isolated == ["BatteryPulseApp"])
    }

    @Test func countsTheAttributesInCodeOnly() {
        let source = """
            // @MainActor in a comment
            let text = "@MainActor in a string"
            @MainActor
            final class A {}
            let action: @MainActor (DeviceKey) -> Void
            Task { @MainActor in update() }
            @MainActorish var notIt = 0
            """
        let attributes = Self.mainActors(inCode: SourceScanner.codeOnly(source))
        #expect(attributes == ["@MainActor", "@MainActor (DeviceKey) -> Void", "@MainActor in update() }"])
    }

    @Test func flagsANewMainActor() {
        let path = "BatteryPulseApp/App/Motion.swift"
        #expect(Self.violations(inCode: "final class SystemPowerState {}", path: path).isEmpty)
        #expect(!Self.violations(inCode: "@MainActor\nfinal class SystemPowerState {}", path: path).isEmpty)
        #expect(!Self.violations(inCode: "@MainActor static func start() {}", path: path).isEmpty)
    }

    @Test func flagsAMissingKeptSite() {
        let path = "BatteryPulseApp/App/WindowLook.swift"
        let kept = "Task { @MainActor in SystemAppearance.shared.update() }"
        #expect(Self.violations(inCode: kept, path: path).isEmpty)
        // `Task {` there would be nonisolated: the hop must name the main actor.
        #expect(!Self.violations(inCode: "Task { SystemAppearance.shared.update() }", path: path).isEmpty)
        // Moved to another kind of site: same count, wrong place.
        #expect(!Self.violations(inCode: "@MainActor final class SystemAppearance {}", path: path).isEmpty)
        // Two identical sites need two matches: one of them turned into a type annotation fails.
        let pages = "BatteryPulseApp/Main/MainView.swift"
        let property = "let showInHistory: @MainActor (DeviceKey) -> Void\n"
        #expect(Self.violations(inCode: property + property, path: pages).isEmpty)
        #expect(!Self.violations(inCode: property + "@MainActor final class Pages {}", path: pages).isEmpty)
    }

    @Test func flagsALostNonisolated() {
        let path = "BatteryPulseApp/Main/RawValueText.swift"
        #expect(Self.violations(inCode: "nonisolated enum RawValueText {}", path: path).isEmpty)
        #expect(Self.violations(inCode: "nonisolated  enum\n RawValueText {}", path: path).isEmpty)
        #expect(!Self.violations(inCode: "enum RawValueText {}", path: path).isEmpty)
        let notifier = "BatteryPulseApp/App/BatteryNotifier.swift"
        let conformance = "extension BatteryNotifier: nonisolated UNUserNotificationCenterDelegate {"
        let method = "nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter) {}\n"
        #expect(Self.violations(inCode: conformance + method + method + "}", path: notifier).isEmpty)
        #expect(
            !Self.violations(inCode: conformance + method + "func userNotificationCenter() {}}", path: notifier).isEmpty
        )
    }
}
