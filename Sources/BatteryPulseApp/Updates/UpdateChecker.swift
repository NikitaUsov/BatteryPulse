#if os(macOS)
import AppKit
import BatteryCore
import Foundation
import Observation

/// Checks GitHub for a newer release: once a day when enabled, and whenever the user asks.
///
/// The only network request BatteryPulse makes. It asks GitHub for the latest release and sends
/// nothing about the Mac beyond a User-Agent with the app's version (URLSession adds the
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
    var isUnversioned: Bool { currentVersion == AppVersion(parts: [0, 0, 0]) }

    // swift-format-ignore: NeverForceUnwrap
    static let endpoint = URL(string: "https://api.github.com/repos/NikitaUsov/BatteryPulse/releases/latest")!

    init(bundle: Bundle = .main) {
        let version = bundle.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String
        currentVersion = version.flatMap(AppVersion.init) ?? AppVersion(parts: [0, 0, 0])
        lastCheck = UserDefaults.standard.object(forKey: AppSettings.lastUpdateCheckKey) as? Date
    }

    /// Starts the daily automatic check (a no-op while the setting is off).
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

    /// Hides the update until the next daily check.
    func dismiss() {
        pendingRelease = nil
        status = .idle
    }

    func download(_ release: ReleaseInfo) {
        NSWorkspace.shared.open(release.downloadURL ?? release.pageURL)
        dismiss()
    }

    private func checkIfDue() async {
        // Only the first scheduled tick may open the window, whether or not it checks.
        defer { mayOpenWindow = false }
        guard AppSettings.checksForUpdates,
            UpdatePolicy.isCheckDue(lastCheck: lastCheck, now: Date()),
            rateLimitedUntil.map({ Date() >= $0 }) ?? true
        else { return }
        await check(userInitiated: false)
    }

    private func check(userInitiated: Bool) async {
        guard status != .checking else { return }
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
        var request = URLRequest(url: endpoint, timeoutInterval: 20)
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
