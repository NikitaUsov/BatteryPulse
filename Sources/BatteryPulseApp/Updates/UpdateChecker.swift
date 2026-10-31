#if os(macOS)
import AppKit
import BatteryCore
import BatteryKit
import BatterySource
import Foundation
import Observation
import os

/// Checks GitHub for a newer release: as often as the user chose, and whenever they ask.
///
/// BatteryPulse's requests to the internet all go to GitHub, on ``UpdateNetwork``'s sessions,
/// which keep no cookies. The check asks for the latest release and sends nothing about the Mac
/// beyond a User-Agent with the app's version (URLSession adds the language). Once per version, at
/// least a day after it first ran, an automatic check that reached GitHub also makes the anonymous
/// version count (``VersionCounterPolicy``): it downloads a small file from the version's release,
/// with the same User-Agent and a constant language, and nothing else. The only other request is
/// downloading an update the user chose to install (``UpdateInstaller``). Builds without a version
/// (CI, `swift run`) never check on their own, and Check Now never counts.
@Observable
final class UpdateChecker {
    enum Status: Equatable {
        case idle
        case checking
        case upToDate
        case available(ReleaseInfo)
        case failed
        /// GitHub refused because of its rate limit (60 requests an hour per IP address).
        case rateLimited
    }

    private enum CheckError: Error {
        case rateLimited(until: Date?)
        case noReleases
    }

    /// Result of the last check, shown in the Software Update window.
    private(set) var status: Status = .idle
    /// A release an automatic check found and the user hasn't dismissed; the popover shows it.
    private(set) var pendingRelease: ReleaseInfo?
    private(set) var lastCheck: Date?

    let currentVersion: AppVersion
    /// Installs the release the window offers, from inside the app.
    let installer: UpdateInstaller

    /// Opens the Software Update window; set by the app.
    @ObservationIgnored var showWindow: (() -> Void)?
    @ObservationIgnored private var schedule: Task<Void, Never>?
    /// The check under way, so Check Now can cancel an automatic one and ask on its own session.
    @ObservationIgnored private var running: (kind: UpdateCheckKind, task: Task<Void, Never>)?
    /// Only the first automatic check after launch may open the window; later ones just show
    /// the update in the menu bar popover, so the app never jumps in front of other work.
    @ObservationIgnored private var mayOpenWindow = true
    @ObservationIgnored private var rateLimitedUntil: Date?

    /// A build without a real version: CI artifacts and `swift run`.
    var isUnversioned: Bool { currentVersion == UpdateInstallPolicy.unversioned }

    static let endpoint = ReleaseChannel.latestRelease

    init(bundle: Bundle = .main) {
        let version = bundle.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String
        let current = version.flatMap(AppVersion.init) ?? UpdateInstallPolicy.unversioned
        currentVersion = current
        installer = UpdateInstaller(currentVersion: current, bundle: bundle)
        lastCheck = UserDefaults.standard.object(forKey: AppSettings.lastUpdateCheckKey) as? Date
    }

    /// Starts the automatic checks; each tick checks only when the chosen interval has passed.
    func startAutomaticChecks() {
        guard schedule == nil, !isUnversioned else { return }
        schedule = Task(name: "UpdateChecker.schedule") { [weak self] in
            // Let launch finish first. The tolerances let macOS coalesce these wake-ups with others.
            try? await Task.sleep(for: .seconds(20), tolerance: .seconds(5))
            while !Task.isCancelled {
                await self?.checkIfDue()
                try? await Task.sleep(for: .seconds(6 * 60 * 60), tolerance: .seconds(36 * 60))
            }
        }
    }

    /// Checks now and shows the result in the Software Update window.
    func checkNow() {
        showWindow?()
        // The window shows the installation in progress instead.
        guard !installer.isBusy else { return }
        switch UpdatePolicy.checkNow(during: running?.kind) {
        case .start: break
        case .takeOver: running?.task.cancel()
        case .wait: return
        }
        let task = Task(name: "UpdateChecker.checkNow") { await check(.user) }
        running = (.user, task)
    }

    func skip(_ release: ReleaseInfo) {
        UserDefaults.standard.set(release.version.description, forKey: AppSettings.skippedVersionKey)
        dismiss()
    }

    /// Hides the update until the next automatic check.
    func dismiss() {
        pendingRelease = nil
        status = .idle
        installer.reset()
    }

    /// Opens the DMG's download in the browser: the way to update when the app can't install
    /// the update itself.
    func download(_ release: ReleaseInfo) {
        NSWorkspace.shared.open(ReleaseLinks.browserURL(for: release.downloadURL ?? release.pageURL))
        dismiss()
    }

    /// Opens the release's page in the browser instead of its DMG, after the DMG failed a check
    /// that shows who made it (``UpdateFallback/releasePage``).
    func openReleasePage(_ release: ReleaseInfo) {
        NSWorkspace.shared.open(ReleaseLinks.browserURL(for: release.pageURL))
        dismiss()
    }

    private func checkIfDue() async {
        // Only the first scheduled tick may open the window, whether or not it checks.
        defer { mayOpenWindow = false }
        // Check Now's check is under way.
        guard running == nil,
            UpdatePolicy.isCheckDue(lastCheck: lastCheck, now: Date(), frequency: AppSettings.updateFrequency),
            rateLimitedUntil.map({ Date() >= $0 }) ?? true
        else { return }
        // In a task of its own, so Check Now can cancel it without ending the schedule.
        let task = Task(name: "UpdateChecker.automaticCheck") { await check(.automatic) }
        running = (.automatic, task)
        await task.value
    }

    private func check(_ kind: UpdateCheckKind) async {
        // After Check Now took over, `running` is its check.
        defer { if running?.kind == kind { running = nil } }
        // A check would replace the release being installed in the window.
        guard !installer.isBusy else { return }
        let userInitiated = kind == .user
        let interval = Diagnostics.begin("update.check", trigger: userInitiated ? "user" : "automatic")
        defer { interval.end() }
        installer.reset()
        status = .checking
        let session = userInitiated ? UpdateNetwork.user : UpdateNetwork.automatic
        let release: ReleaseInfo
        do {
            release = try await Self.fetchLatest(currentVersion: currentVersion, session: session)
        } catch {
            // A cancelled check was taken over by Check Now, whose own check reports.
            if !Task.isCancelled { failed(error, userInitiated: userInitiated) }
            return
        }
        guard !Task.isCancelled else { return }
        recordCheck()
        let skipped = UserDefaults.standard.string(forKey: AppSettings.skippedVersionKey).flatMap(AppVersion.init)
        if UpdatePolicy.shouldOffer(release, current: currentVersion, skipped: skipped, userInitiated: userInitiated) {
            status = .available(release)
            pendingRelease = release
            if !userInitiated, mayOpenWindow { showWindow?() }
        } else {
            status = userInitiated ? .upToDate : .idle
        }
        // After the offer is decided, so a window waiting on the check never waits for the count.
        if !userInitiated { await countVersionIfDue(session: session) }
    }

    /// The anonymous version count, on an automatic check that reached GitHub: once per version,
    /// a day after it first ran, and only while the count and automatic checks are on
    /// (``VersionCounterPolicy/shouldCount(enabled:frequency:current:lastCounted:versionSince:now:)``).
    /// It downloads the version's counter file, following GitHub's redirect, and ignores the body.
    /// On the automatic check's session, in its task and its `update.check` interval. A 200 or a
    /// 404 (no counter on the release) is the version done with; any other answer leaves it for the
    /// next due automatic check, with no retry of its own.
    private func countVersionIfDue(session: URLSession) async {
        let defaults = UserDefaults.standard
        guard
            VersionCounterPolicy.shouldCount(
                enabled: AppSettings.countsVersion, frequency: AppSettings.updateFrequency, current: currentVersion,
                lastCounted: defaults.string(forKey: AppSettings.lastCountedVersionKey).flatMap(AppVersion.init),
                versionSince: defaults.object(forKey: AppSettings.versionFirstLaunchKey) as? Date, now: Date()),
            let url = VersionCounterPolicy.url(for: currentVersion)
        else { return }
        var request = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 20)
        for (field, value) in VersionCounterPolicy.headers(for: currentVersion) {
            request.setValue(value, forHTTPHeaderField: field)
        }
        // The final answer's HTTP status, or a URLError's code (negative) when none came.
        let code: Int
        let outcome: VersionCounterPolicy.Outcome
        do {
            let (_, response) = try await session.data(for: request)
            let statusCode = (response as? HTTPURLResponse)?.statusCode
            outcome = VersionCounterPolicy.outcome(statusCode: statusCode)
            code = statusCode ?? 0
        } catch {
            outcome = .failed
            code = (error as? URLError)?.code.rawValue ?? 0
        }
        if VersionCounterPolicy.marksCounted(outcome) {
            defaults.set(currentVersion.description, forKey: AppSettings.lastCountedVersionKey)
        }
        // Only the outcome's case name and the code log as public, never the URL or an error's
        // description.
        switch outcome {
        case .counted:
            Diagnostics.update.info("Version count: \(outcome.rawValue, privacy: .public), \(code, privacy: .public)")
        case .noCounter, .failed:
            Diagnostics.update.debug("Version count: \(outcome.rawValue, privacy: .public), \(code, privacy: .public)")
        }
    }

    private func failed(_ error: any Error, userInitiated: Bool) {
        switch error {
        case CheckError.noReleases:
            recordCheck()
            status = userInitiated ? .upToDate : .idle
        case CheckError.rateLimited(let until):
            rateLimitedUntil = until ?? Date().addingTimeInterval(60 * 60)
            status = userInitiated ? .rateLimited : .idle
        default:
            status = userInitiated ? .failed : .idle
        }
    }

    private func recordCheck() {
        lastCheck = Date()
        UserDefaults.standard.set(lastCheck, forKey: AppSettings.lastUpdateCheckKey)
    }

    private static func fetchLatest(currentVersion: AppVersion, session: URLSession) async throws -> ReleaseInfo {
        // GitHub lets caches keep this answer for a minute; Check Now right after a release would
        // otherwise still hear about the previous one. Checks are at most daily, so nothing is lost.
        var request = URLRequest(url: endpoint, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 20)
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        request.setValue("2022-11-28", forHTTPHeaderField: "X-GitHub-Api-Version")
        request.setValue("BatteryPulse/\(currentVersion)", forHTTPHeaderField: "User-Agent")
        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw URLError(.badServerResponse) }
        switch http.statusCode {
        case 200:
            return try ReleaseInfo.parse(gitHubJSON: data)
        case 404:
            throw CheckError.noReleases
        case 403, 429:
            // `retry-after` in seconds, or `x-ratelimit-reset` as a Unix time.
            let retryAfter = http.value(forHTTPHeaderField: "retry-after").flatMap(TimeInterval.init)
            let reset = http.value(forHTTPHeaderField: "x-ratelimit-reset").flatMap(TimeInterval.init)
            if retryAfter != nil || http.value(forHTTPHeaderField: "x-ratelimit-remaining") == "0" {
                let until =
                    retryAfter.map { Date().addingTimeInterval($0) } ?? reset.map { Date(timeIntervalSince1970: $0) }
                throw CheckError.rateLimited(until: until)
            }
            throw URLError(.badServerResponse)
        default:
            throw URLError(.badServerResponse)
        }
    }
}

/// The sessions of the update traffic. Both are ephemeral and have no URL cache, so a check or
/// a download leaves nothing on disk but the files the installer moves into place itself. Neither
/// keeps or sends cookies: github.com sets some on a release download, even one that answers 404,
/// and in memory they would join every later request while the app runs.
enum UpdateNetwork {
    /// Check Now, the release's signature and its DMG: the user asked, so any network will do.
    /// Check Now during an automatic check cancels it and asks here instead.
    static let user = URLSession(configuration: configuration(automatic: false))
    /// The automatic checks: never over Low Data Mode or an expensive network, such as a phone's
    /// hotspot. Such a check fails at once without counting as done, so the next tick tries again.
    static let automatic = URLSession(configuration: configuration(automatic: true))

    private static func configuration(automatic: Bool) -> URLSessionConfiguration {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.urlCache = nil
        configuration.httpCookieStorage = nil
        configuration.httpShouldSetCookies = false
        configuration.httpCookieAcceptPolicy = .never
        // Without a connection a check fails at once instead of keeping the window waiting; the
        // next tick or Check Now asks again.
        configuration.waitsForConnectivity = false
        if automatic {
            configuration.allowsConstrainedNetworkAccess = false
            configuration.allowsExpensiveNetworkAccess = false
        }
        return configuration
    }
}
#endif
