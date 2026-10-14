#if os(macOS)
import AppKit
import BatteryCore
import Foundation
import Observation

/// Checks GitHub for a newer release: once a day when enabled, and whenever the user asks.
///
/// The only network request BatteryPulse makes. It asks GitHub for the latest release and sends
/// nothing about the Mac beyond a User-Agent with the app's version.
@MainActor
@Observable
final class UpdateChecker {
    enum Status: Equatable {
        case idle
        case checking
        case upToDate
        case available(ReleaseInfo)
        case failed
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

    // swift-format-ignore: NeverForceUnwrap
    static let endpoint = URL(string: "https://api.github.com/repos/NikitaUsov/BatteryPulse/releases/latest")!

    init(bundle: Bundle = .main) {
        let version = bundle.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String
        currentVersion = version.flatMap(AppVersion.init) ?? AppVersion(parts: [0, 0, 0])
        lastCheck = UserDefaults.standard.object(forKey: AppSettings.lastUpdateCheckKey) as? Date
    }

    /// Starts the daily automatic check (a no-op while the setting is off).
    func startAutomaticChecks() {
        guard schedule == nil else { return }
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
        guard AppSettings.checksForUpdates,
            UpdatePolicy.isCheckDue(lastCheck: lastCheck, now: Date())
        else { return }
        await check(userInitiated: false)
    }

    private func check(userInitiated: Bool) async {
        guard status != .checking else { return }
        status = .checking
        do {
            let release = try await Self.fetchLatest(currentVersion: currentVersion)
            lastCheck = Date()
            UserDefaults.standard.set(lastCheck, forKey: AppSettings.lastUpdateCheckKey)
            let skipped = UserDefaults.standard.string(forKey: AppSettings.skippedVersionKey).flatMap(AppVersion.init)
            if UpdatePolicy.shouldOffer(
                release, current: currentVersion, skipped: skipped, userInitiated: userInitiated)
            {
                status = .available(release)
                pendingRelease = release
                if !userInitiated { showWindow?() }
            } else {
                status = userInitiated ? .upToDate : .idle
            }
        } catch {
            status = userInitiated ? .failed : .idle
        }
    }

    private static func fetchLatest(currentVersion: AppVersion) async throws -> ReleaseInfo {
        var request = URLRequest(url: endpoint, timeoutInterval: 20)
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        request.setValue("2022-11-28", forHTTPHeaderField: "X-GitHub-Api-Version")
        request.setValue("BatteryPulse/\(currentVersion)", forHTTPHeaderField: "User-Agent")
        let (data, response) = try await URLSession.shared.data(for: request)
        guard (response as? HTTPURLResponse)?.statusCode == 200 else { throw URLError(.badServerResponse) }
        return try ReleaseInfo.parse(gitHubJSON: data)
    }
}
#endif
