#if os(macOS)
import AppKit
import BatteryCore
import BatteryKit
import Foundation
import Observation

/// Checks GitHub for a newer release: as often as the user chose, and whenever they ask.
///
/// The only network request BatteryPulse makes on its own; the other is downloading an update
/// the user chose to install (``UpdateInstaller``). It asks GitHub for the latest release and
/// sends nothing about the Mac beyond a User-Agent with the app's version (URLSession adds the
/// language). Builds without a version (CI, `swift run`) never check on their own.
@MainActor
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
    /// The user asked while an automatic check was running; its result is theirs.
    @ObservationIgnored private var userIsWaiting = false
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
        schedule = Task { [weak self] in
            // Let launch finish first.
            try? await Task.sleep(for: .seconds(20))
            while !Task.isCancelled {
                await self?.checkIfDue()
                try? await Task.sleep(for: .seconds(6 * 60 * 60))
            }
        }
    }

    /// Checks now and shows the result in the Software Update window.
    func checkNow() {
        showWindow?()
        // The window shows the installation in progress instead.
        guard !installer.isBusy else { return }
        if status == .checking {
            userIsWaiting = true
            return
        }
        Task { await check(userInitiated: true) }
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
        guard UpdatePolicy.isCheckDue(lastCheck: lastCheck, now: Date(), frequency: AppSettings.updateFrequency),
            rateLimitedUntil.map({ Date() >= $0 }) ?? true
        else { return }
        await check(userInitiated: false)
    }

    private func check(userInitiated: Bool) async {
        // A check would replace the release being installed in the window.
        guard status != .checking, !installer.isBusy else { return }
        let interval = Diagnostics.begin("update.check", trigger: userInitiated ? "user" : "automatic")
        defer { interval.end() }
        installer.reset()
        status = .checking
        userIsWaiting = userIsWaiting || userInitiated
        defer { userIsWaiting = false }
        do {
            let release = try await Self.fetchLatest(currentVersion: currentVersion)
            recordCheck()
            let skipped = UserDefaults.standard.string(forKey: AppSettings.skippedVersionKey).flatMap(AppVersion.init)
            if UpdatePolicy.shouldOffer(
                release, current: currentVersion, skipped: skipped, userInitiated: userIsWaiting)
            {
                status = .available(release)
                pendingRelease = release
                if !userIsWaiting, mayOpenWindow { showWindow?() }
            } else {
                status = userIsWaiting ? .upToDate : .idle
            }
        } catch CheckError.noReleases {
            recordCheck()
            status = userIsWaiting ? .upToDate : .idle
        } catch CheckError.rateLimited(let until) {
            rateLimitedUntil = until ?? Date().addingTimeInterval(60 * 60)
            status = userIsWaiting ? .rateLimited : .idle
        } catch {
            status = userIsWaiting ? .failed : .idle
        }
    }

    private func recordCheck() {
        lastCheck = Date()
        UserDefaults.standard.set(lastCheck, forKey: AppSettings.lastUpdateCheckKey)
    }

    private static func fetchLatest(currentVersion: AppVersion) async throws -> ReleaseInfo {
        // GitHub lets caches keep this answer for a minute; Check Now right after a release would
        // otherwise still hear about the previous one. Checks are at most daily, so nothing is lost.
        var request = URLRequest(url: endpoint, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 20)
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        request.setValue("2022-11-28", forHTTPHeaderField: "X-GitHub-Api-Version")
        request.setValue("BatteryPulse/\(currentVersion)", forHTTPHeaderField: "User-Agent")
        let (data, response) = try await URLSession.shared.data(for: request)
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
#endif
