#if os(macOS)
import AppKit
import BatteryCore
import BatteryKit
import CoreServices
import Foundation
import Observation
import Security
import os

/// Installs an update from inside the app, so the user doesn't download the DMG and replace the
/// app by hand.
///
/// It downloads the DMG and its signature into Caches, checks the DMG against GitHub's digest
/// and the release key (``ReleaseSigning``), mounts it read-only, copies the new app next to
/// this one on the same volume, checks the copy's bundle identifier, version and code
/// signature, swaps the two bundles in one atomic rename, and relaunches. The previous version
/// is deleted at the next launch. Files the app downloads itself aren't quarantined (the
/// Info.plist has no `LSFileQuarantineEnabled`), so the new version opens without Open Anyway.
///
/// Every failure leaves the installed app untouched. The window then offers the browser download,
/// or only the release page after a failed integrity check (``UpdateFallback``).
@MainActor
@Observable
final class UpdateInstaller {
    enum Phase: Equatable {
        case idle
        /// The fraction downloaded, or `nil` while the size is unknown.
        case downloading(Double?)
        case verifying
        case installing
        case relaunching
        case failed(UpdateInstallError)
    }

    private(set) var phase: Phase = .idle

    /// The app's installer, so quitting can wait for an install in progress.
    private(set) static weak var current: UpdateInstaller?

    let currentVersion: AppVersion
    private let bundleURL: URL
    private let bundleIdentifier: String
    @ObservationIgnored private var work: Task<Void, Never>?
    @ObservationIgnored private var isQuitting = false

    init(currentVersion: AppVersion, bundle: Bundle = .main) {
        self.currentVersion = currentVersion
        bundleURL = bundle.bundleURL.resolvingSymlinksInPath()
        bundleIdentifier = bundle.bundleIdentifier ?? ""
        Self.current = self
    }

    var isBusy: Bool {
        switch phase {
        case .downloading, .verifying, .installing, .relaunching: true
        case .idle, .failed: false
        }
    }

    /// Only the download can be stopped; once checked, the update goes in.
    var canCancel: Bool {
        switch phase {
        case .downloading: true
        case .idle, .verifying, .installing, .relaunching, .failed: false
        }
    }

    /// The last attempt failed in a way worth repeating (the network).
    var canRetry: Bool {
        switch phase {
        case .failed(let error): error.isRetryable
        case .idle, .downloading, .verifying, .installing, .relaunching: false
        }
    }

    /// Why this copy can't install `release` itself, or `nil` when Install and Relaunch can be
    /// offered.
    func blocker(for release: ReleaseInfo) -> UpdateInstallError? {
        let fileManager = FileManager.default
        let canWrite =
            fileManager.isWritableFile(atPath: bundleURL.path)
            && fileManager.isWritableFile(atPath: bundleURL.deletingLastPathComponent().path)
        return UpdateInstallPolicy.blocker(
            release: release, current: currentVersion, bundlePath: bundleURL.path, canWrite: canWrite)
    }

    func install(_ release: ReleaseInfo) {
        guard !isBusy else { return }
        if let blocker = blocker(for: release) {
            phase = .failed(blocker)
            return
        }
        phase = .downloading(nil)
        work = Task { await run(release) }
    }

    func cancel() {
        guard canCancel else { return }
        work?.cancel()
    }

    /// Called when the app quits. A download stops and a checked update isn't installed, but an
    /// install already under way finishes, so no disk image stays mounted and no half-copied app
    /// is left behind; the new version then opens next time instead of relaunching now.
    func finishBeforeQuitting() async {
        isQuitting = true
        // Relaunching is the install's own quit: its task is done but for that call.
        guard phase != .relaunching else { return }
        cancel()
        await work?.value
    }

    /// Back to the start after a failure, or when the update is dismissed.
    func reset() {
        guard !isBusy else { return }
        phase = .idle
    }

    /// Deletes what an earlier update left behind: the previous version, swapped out to a
    /// temporary folder, and the downloads. Called at launch, never while that version runs.
    static func cleanUpAfterUpdate(bundle: Bundle = .main) {
        let defaults = UserDefaults.standard
        let recorded = defaults.string(forKey: AppSettings.updateLeftoverKey)
        defaults.removeObject(forKey: AppSettings.updateLeftoverKey)
        let leftover = UpdateInstallPolicy.leftoverToDelete(
            recorded: recorded, runningBundlePath: bundle.bundleURL.resolvingSymlinksInPath().path)
        let identifier = bundle.bundleIdentifier ?? ""
        Task.detached(priority: .utility) {
            UpdateInstallSteps.removeLeftovers(leftover: leftover, bundleIdentifier: identifier)
        }
    }

    // MARK: - Steps

    private func run(_ release: ReleaseInfo) async {
        let identifier = bundleIdentifier
        do {
            guard let imageURL = release.downloadURL, let signatureURL = release.signatureURL else {
                throw UpdateInstallError.notSigned
            }
            let folder = try UpdateInstallSteps.prepareDownloadFolder(bundleIdentifier: identifier)
            let signature = try await fetchSignature(signatureURL)
            let image = folder.appendingPathComponent("BatteryPulse.dmg")
            try await download(imageURL, to: image, expectedSize: release.downloadSize)
            try Task.checkCancellation()

            phase = .verifying
            let digest = release.downloadDigest
            try await Task.detached(priority: .userInitiated) {
                try UpdateInstallSteps.verify(image: image, signature: signature, digest: digest)
            }.value
            try Task.checkCancellation()
            if isQuitting { throw CancellationError() }

            phase = .installing
            let target = bundleURL
            let version = release.version
            let current = currentVersion
            let previous = try await Task.detached(priority: .userInitiated) {
                try await UpdateInstallSteps.replace(
                    target: target, image: image, identifier: identifier, release: version, current: current)
            }.value
            // The running process still uses the previous version's files; it goes at the next launch.
            UserDefaults.standard.set(previous.path, forKey: AppSettings.updateLeftoverKey)
            if !isQuitting { relaunch() }
        } catch {
            UpdateInstallSteps.removeDownloads(bundleIdentifier: identifier)
            if error is CancellationError {
                phase = .idle
            } else {
                let failure = error as? UpdateInstallError ?? .downloadFailed
                let version = release.version.description
                let reason = String(describing: failure)
                UpdateInstallSteps.log.error(
                    "Installing \(version, privacy: .public) failed: \(reason, privacy: .public)")
                phase = .failed(failure)
            }
        }
    }

    private func fetchSignature(_ url: URL) async throws -> Data {
        let result: (Data, URLResponse)
        do {
            result = try await URLSession.shared.data(for: request(url))
        } catch {
            throw Self.downloadError(error)
        }
        guard (result.1 as? HTTPURLResponse)?.statusCode == 200 else { throw UpdateInstallError.downloadFailed }
        guard let signature = UpdateIntegrity.signature(fromSigFile: result.0) else {
            throw UpdateInstallError.badSignature
        }
        return signature
    }

    private func download(_ url: URL, to destination: URL, expectedSize: Int64?) async throws {
        let watcher = DownloadWatcher()
        // Polls the transfer, since the async download API reports no progress of its own.
        let progress = Task { [weak self] in
            while !Task.isCancelled {
                if let self, case .downloading = self.phase {
                    self.phase = .downloading(watcher.fraction(expectedSize: expectedSize))
                }
                try? await Task.sleep(for: .milliseconds(200))
            }
        }
        defer { progress.cancel() }
        let result: (URL, URLResponse)
        do {
            result = try await URLSession.shared.download(for: request(url), delegate: watcher)
        } catch {
            throw Self.downloadError(error)
        }
        let (location, response) = result
        guard (response as? HTTPURLResponse)?.statusCode == 200 else {
            try? FileManager.default.removeItem(at: location)
            throw UpdateInstallError.downloadFailed
        }
        do {
            try? FileManager.default.removeItem(at: destination)
            try FileManager.default.moveItem(at: location, to: destination)
        } catch {
            throw UpdateInstallError.downloadFailed
        }
    }

    private func request(_ url: URL) -> URLRequest {
        var request = URLRequest(url: url, timeoutInterval: 60)
        request.setValue("BatteryPulse/\(currentVersion)", forHTTPHeaderField: "User-Agent")
        return request
    }

    private static func downloadError(_ error: any Error) -> any Error {
        if error is CancellationError || (error as? URLError)?.code == .cancelled || Task.isCancelled {
            return CancellationError()
        }
        return UpdateInstallError.downloadFailed
    }

    /// Registers the new version with Launch Services, starts a shell that opens it once this
    /// process is gone, and quits.
    private func relaunch() {
        phase = .relaunching
        // Updates the registration even if the modification date looks unchanged.
        let status = LSRegisterURL(bundleURL as CFURL, true)
        if status != 0 {
            UpdateInstallSteps.log.error("LSRegisterURL failed: \(status, privacy: .public)")
        }
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/sh")
        process.arguments = UpdateInstallPolicy.relaunchArguments(
            appPath: bundleURL.path, processID: ProcessInfo.processInfo.processIdentifier)
        process.standardInput = FileHandle.nullDevice
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice
        do {
            try process.run()
        } catch {
            let reason = String(describing: error)
            UpdateInstallSteps.log.error("Couldn't start the relaunch: \(reason, privacy: .public)")
            phase = .failed(.relaunchFailed)
            return
        }
        // Not right here: this runs inside the install task, on the main queue, and the quit waits
        // for the delegate's reply in a nested run loop that can't run main-actor work queued
        // behind this call. From the run loop, after the task has ended, it can.
        NSApp.perform(#selector(NSApplication.terminate(_:)), with: nil, afterDelay: 0, inModes: [.common])
    }
}

extension UpdateInstallError {
    /// What went wrong, for the Software Update window.
    var message: String {
        switch self {
        case .developmentBuild: String(localized: "Development builds can't install updates.")
        case .translocated:
            String(
                localized:
                    "To install updates from BatteryPulse itself, move it to the Applications folder and open it from there."
            )
        case .folderNotWritable:
            String(localized: "BatteryPulse can't replace itself in its folder, so install the update from the DMG.")
        case .notSigned: String(localized: "This release isn't signed, so BatteryPulse can't install it.")
        case .notNewer: String(localized: "This version isn't newer than the one you have.")
        case .downloadFailed:
            String(localized: "The update couldn't be downloaded. Check your internet connection.")
        case .digestMismatch: String(localized: "The downloaded file is damaged.")
        case .badSignature: String(localized: "The update's signature isn't valid, so it wasn't installed.")
        case .mountFailed: String(localized: "The downloaded disk image couldn't be opened.")
        case .unexpectedBundle:
            String(localized: "The disk image doesn't contain the expected version of BatteryPulse.")
        case .invalidCodeSignature: String(localized: "The new version's code signature isn't valid.")
        case .replaceFailed: String(localized: "BatteryPulse couldn't replace the installed copy.")
        case .relaunchFailed:
            String(
                localized:
                    "The update is installed, but BatteryPulse couldn't relaunch. Quit BatteryPulse and open it again.")
        }
    }

    /// Why Install and Relaunch isn't offered, when the user can change that.
    var reason: String? {
        switch self {
        case .translocated, .folderNotWritable: message
        case .developmentBuild, .notSigned, .notNewer, .downloadFailed, .digestMismatch, .badSignature, .mountFailed,
            .unexpectedBundle, .invalidCodeSignature, .replaceFailed, .relaunchFailed:
            nil
        }
    }
}

/// Hands the progress of a download made with `URLSession.download(for:delegate:)` to the main
/// actor, which polls it.
private final class DownloadWatcher: NSObject, URLSessionTaskDelegate, @unchecked Sendable {
    private let lock = NSLock()
    private var task: URLSessionTask?

    func urlSession(_ session: URLSession, didCreateTask task: URLSessionTask) {
        lock.withLock { self.task = task }
    }

    /// The fraction received, or `nil` before the size is known.
    func fraction(expectedSize: Int64?) -> Double? {
        guard let task = lock.withLock({ self.task }) else { return nil }
        let reported = task.countOfBytesExpectedToReceive
        let expected = reported > 0 ? reported : (expectedSize ?? 0)
        guard expected > 0 else { return nil }
        return min(1, Double(task.countOfBytesReceived) / Double(expected))
    }
}

/// The installation steps that touch the disk; they run off the main actor.
enum UpdateInstallSteps {
    static let log = Logger(subsystem: "io.github.nikitausov.BatteryPulse", category: "update")

    /// ~/Library/Caches/<bundle id>/Updates, emptied for a new download.
    static func prepareDownloadFolder(bundleIdentifier: String) throws -> URL {
        do {
            let folder = try downloadsFolder(bundleIdentifier: bundleIdentifier)
            try? FileManager.default.removeItem(at: folder)
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            return folder
        } catch {
            throw UpdateInstallError.downloadFailed
        }
    }

    static func removeDownloads(bundleIdentifier: String) {
        guard let folder = try? downloadsFolder(bundleIdentifier: bundleIdentifier) else { return }
        try? FileManager.default.removeItem(at: folder)
    }

    private static func downloadsFolder(bundleIdentifier: String) throws -> URL {
        guard !bundleIdentifier.isEmpty else { throw UpdateInstallError.developmentBuild }
        let caches = try FileManager.default.url(
            for: .cachesDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
        return caches.appendingPathComponent(bundleIdentifier, isDirectory: true)
            .appendingPathComponent("Updates", isDirectory: true)
    }

    /// Checks the downloaded DMG before anything mounts it: GitHub's digest when the release has
    /// one, then the release signature, which must be valid.
    static func verify(image: URL, signature: Data, digest: String?) throws {
        let data: Data
        do {
            data = try Data(contentsOf: image, options: .mappedIfSafe)
        } catch {
            throw UpdateInstallError.downloadFailed
        }
        let hash = UpdateSignatureVerifier.sha256Hex(of: data)
        if UpdateIntegrity.check(sha256Hex: hash, against: digest) == .mismatch {
            throw UpdateInstallError.digestMismatch
        }
        guard let verifier = UpdateSignatureVerifier.release, verifier.isValid(signature: signature, for: data) else {
            throw UpdateInstallError.badSignature
        }
    }

    /// Copies the app out of the verified DMG next to `target` (a temporary folder on the same
    /// volume), checks the copy and swaps it with `target` in one rename. Returns where the
    /// previous version is now.
    static func replace(
        target: URL, image: URL, identifier: String, release: AppVersion, current: AppVersion
    ) async throws -> URL {
        let fileManager = FileManager.default
        let staging: URL
        do {
            staging = try fileManager.url(
                for: .itemReplacementDirectory, in: .userDomainMask, appropriateFor: target, create: true)
        } catch {
            throw UpdateInstallError.replaceFailed
        }
        var swapped = false
        defer {
            if !swapped { try? fileManager.removeItem(at: staging) }
        }
        let staged = staging.appendingPathComponent(target.lastPathComponent, isDirectory: true)

        try await withMountedImage(image) { mountPoint in
            let source = mountPoint.appendingPathComponent("BatteryPulse.app", isDirectory: true)
            let values = try? source.resourceValues(forKeys: [.isDirectoryKey, .isSymbolicLinkKey])
            guard values?.isDirectory == true, values?.isSymbolicLink != true else {
                throw UpdateInstallError.unexpectedBundle
            }
            do {
                try fileManager.copyItem(at: source, to: staged)
            } catch {
                throw UpdateInstallError.replaceFailed
            }
        }

        clearQuarantine(staged)
        try checkBundle(staged, identifier: identifier, release: release, current: current)
        try checkCodeSignature(staged)

        guard renamex_np(staged.path, target.path, UInt32(RENAME_SWAP)) == 0 else {
            let reason = String(cString: strerror(errno))
            log.error("Swapping the app failed: \(reason, privacy: .public)")
            throw UpdateInstallError.replaceFailed
        }
        swapped = true
        return staged
    }

    /// Mounts `image` at a private mount point for `body`, and detaches it afterwards.
    private static func withMountedImage(_ image: URL, _ body: (URL) throws -> Void) async throws {
        let mountPoint = FileManager.default.temporaryDirectory
            .appendingPathComponent("BatteryPulse-update-\(UUID().uuidString)", isDirectory: true)
        do {
            try FileManager.default.createDirectory(at: mountPoint, withIntermediateDirectories: true)
        } catch {
            throw UpdateInstallError.mountFailed
        }
        let arguments = UpdateInstallPolicy.attachArguments(image: image.path, mountPoint: mountPoint.path)
        let status = try? await run(hdiutil, arguments)
        guard status == 0 else {
            // In case it mounted anyway.
            await detach(mountPoint)
            throw UpdateInstallError.mountFailed
        }
        do {
            try body(mountPoint)
        } catch {
            await detach(mountPoint)
            throw error
        }
        await detach(mountPoint)
    }

    private static let hdiutil = "/usr/bin/hdiutil"

    private static func detach(_ mountPoint: URL) async {
        let path = mountPoint.path
        let status = try? await run(hdiutil, UpdateInstallPolicy.detachArguments(mountPoint: path, force: false))
        if status != 0 {
            _ = try? await run(hdiutil, UpdateInstallPolicy.detachArguments(mountPoint: path, force: true))
        }
        // Only an empty folder: never anything still mounted there.
        _ = rmdir(path)
    }

    /// Runs a tool without input or output and returns its exit status.
    private static func run(_ tool: String, _ arguments: [String]) async throws -> Int32 {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: tool)
        process.arguments = arguments
        process.standardInput = FileHandle.nullDevice
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice
        return try await withCheckedThrowingContinuation { continuation in
            process.terminationHandler = { finished in
                continuation.resume(returning: finished.terminationStatus)
            }
            do {
                try process.run()
            } catch {
                process.terminationHandler = nil
                continuation.resume(throwing: error)
            }
        }
    }

    /// Disk images can mount with quarantine applied to what they contain; the copy must open
    /// without Open Anyway, so remove it, the documented way.
    private static func clearQuarantine(_ bundle: URL) {
        var items = [bundle]
        if let enumerator = FileManager.default.enumerator(at: bundle, includingPropertiesForKeys: nil) {
            for case let url as URL in enumerator {
                items.append(url)
            }
        }
        for url in items {
            try? (url as NSURL).setResourceValue(nil, forKey: .quarantinePropertiesKey)
        }
    }

    /// The same app, exactly the release's version, newer than the running one.
    private static func checkBundle(_ bundle: URL, identifier: String, release: AppVersion, current: AppVersion) throws
    {
        let info = infoDictionary(ofBundleAt: bundle)
        if let problem = UpdateInstallPolicy.checkStagedBundle(
            identifier: info?["CFBundleIdentifier"] as? String,
            version: info?["CFBundleShortVersionString"] as? String,
            expectedIdentifier: identifier, release: release, current: current)
        {
            throw problem
        }
    }

    /// The ad-hoc signature seals every file of the app and its widget; any change breaks it.
    private static func checkCodeSignature(_ bundle: URL) throws {
        var code: SecStaticCode?
        guard SecStaticCodeCreateWithPath(bundle as CFURL, [], &code) == errSecSuccess, let code else {
            throw UpdateInstallError.invalidCodeSignature
        }
        let flags = SecCSFlags(rawValue: kSecCSStrictValidate | kSecCSCheckAllArchitectures | kSecCSCheckNestedCode)
        var error: Unmanaged<CFError>?
        guard SecStaticCodeCheckValidityWithErrors(code, flags, nil, &error) == errSecSuccess else {
            let reason = error.map { String(describing: $0.takeRetainedValue()) } ?? "unknown"
            log.error("The new version's code signature isn't valid: \(reason, privacy: .public)")
            throw UpdateInstallError.invalidCodeSignature
        }
    }

    /// Deletes the previous version (only a copy of this app) and the downloads.
    static func removeLeftovers(leftover: String?, bundleIdentifier: String) {
        removeDownloads(bundleIdentifier: bundleIdentifier)
        guard let leftover, !bundleIdentifier.isEmpty else { return }
        let app = URL(fileURLWithPath: leftover, isDirectory: true)
        guard infoDictionary(ofBundleAt: app)?["CFBundleIdentifier"] as? String == bundleIdentifier else { return }
        try? FileManager.default.removeItem(at: app)
        // The temporary folder it was in, if nothing else is there.
        _ = rmdir(app.deletingLastPathComponent().path)
    }

    /// The Info.plist of the app at `bundle`, or `nil` if it can't be read. Read from the file,
    /// not through `Bundle(url:)`, which returns one cached instance per path for the life of
    /// the process.
    private static func infoDictionary(ofBundleAt bundle: URL) -> [String: Any]? {
        let plist = bundle.appendingPathComponent("Contents/Info.plist")
        guard let data = try? Data(contentsOf: plist) else { return nil }
        return (try? PropertyListSerialization.propertyList(from: data, format: nil)) as? [String: Any]
    }
}
#endif
