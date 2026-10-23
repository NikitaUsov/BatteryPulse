#if os(macOS)
import AppKit
import BatteryCore
import BatteryKit
import CoreServices
import Foundation
import Observation
import Security
import Synchronization
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
        work = Task(name: "UpdateInstaller.install") { await run(release) }
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
        // Fire and forget: launch doesn't wait for the deletion, and nothing needs its result.
        Task.detached(name: "UpdateInstaller.removeLeftovers", priority: .utility) {
            UpdateInstallSteps.removeLeftovers(leftover: leftover, bundleIdentifier: identifier)
        }
    }

    // MARK: - Steps

    private func run(_ release: ReleaseInfo) async {
        // Keeps the app out of App Nap and the Mac from idle sleep from the download to the
        // relaunch; the only activity BatteryPulse ever holds, ended on every way out.
        let activity = ProcessInfo.processInfo.beginActivity(options: .userInitiated, reason: "Installing an update")
        defer { ProcessInfo.processInfo.endActivity(activity) }
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
            try await UpdateInstallSteps.verify(image: image, signature: signature, digest: release.downloadDigest)
            try Task.checkCancellation()
            if isQuitting { throw CancellationError() }

            phase = .installing
            // Once checked, the update goes in: nothing in the swap checks for cancellation, and
            // the shield keeps it that way.
            let previous = try await withTaskCancellationShield {
                try await UpdateInstallSteps.replace(
                    target: bundleURL, image: image, identifier: identifier, release: release.version,
                    current: currentVersion)
            }
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
                Diagnostics.update.error(
                    "Installing \(version, privacy: .public) failed: \(reason, privacy: .public)")
                phase = .failed(failure)
            }
        }
    }

    private func fetchSignature(_ url: URL) async throws -> Data {
        let result: (Data, URLResponse)
        do {
            result = try await UpdateNetwork.user.data(for: request(url))
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
        let progress = Task(name: "UpdateInstaller.downloadProgress") { [weak self] in
            while !Task.isCancelled {
                if let self, case .downloading = self.phase {
                    self.phase = .downloading(watcher.fraction(expectedSize: expectedSize))
                }
                try? await Task.sleep(for: .milliseconds(200), tolerance: .milliseconds(50))
            }
        }
        defer { progress.cancel() }
        let result: (URL, URLResponse)
        do {
            result = try await UpdateNetwork.user.download(for: request(url), delegate: watcher)
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
            Diagnostics.update.error("LSRegisterURL failed: \(status, privacy: .public)")
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
            // An error description can carry a path, so it stays private.
            let reason = String(describing: error)
            Diagnostics.update.error("Couldn't start the relaunch: \(reason, privacy: .private)")
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
/// actor, which polls it. Nonisolated: URLSession calls it on its delegate queue.
private nonisolated final class DownloadWatcher: NSObject, URLSessionTaskDelegate, Sendable {
    private let task = Mutex<URLSessionTask?>(nil)

    func urlSession(_ session: URLSession, didCreateTask task: URLSessionTask) {
        self.task.withLock { $0 = task }
    }

    /// The fraction received, or `nil` before the size is known.
    func fraction(expectedSize: Int64?) -> Double? {
        guard let task = self.task.withLock({ $0 }) else { return nil }
        let reported = task.countOfBytesExpectedToReceive
        let expected = reported > 0 ? reported : (expectedSize ?? 0)
        guard expected > 0 else { return nil }
        return min(1, Double(task.countOfBytesReceived) / Double(expected))
    }
}

/// The installation steps that touch the disk. `verify`, `replace` and `removeLeftovers` run off
/// the main actor; preparing and emptying the downloads folder is quick and runs on the caller's.
/// The steps that can fail throw only an ``UpdateInstallError``; cancellation is checked between
/// them, in the installer's `run`. Nonisolated, unlike the rest of the app, so no step (mounting,
/// the code signature check, the tools' termination handlers) drifts onto the main actor.
nonisolated enum UpdateInstallSteps {
    /// ~/Library/Caches/<bundle id>/Updates, emptied for a new download.
    static func prepareDownloadFolder(bundleIdentifier: String) throws(UpdateInstallError) -> URL {
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
    /// one, then the release signature, which must be valid. `@concurrent`: hashing the DMG and
    /// checking the signature is synchronous work that must not hold the caller's actor.
    @concurrent static func verify(image: URL, signature: Data, digest: String?) async throws(UpdateInstallError) {
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
    /// volume), checks the copy, ends the widget extension and swaps the copy with `target` in one
    /// rename. Returns where the previous version is now. `@concurrent`: the copy, the quarantine
    /// clearing and the strict code signature check are synchronous work that must not hold the
    /// caller's actor.
    @concurrent static func replace(
        target: URL, image: URL, identifier: String, release: AppVersion, current: AppVersion
    ) async throws(UpdateInstallError) -> URL {
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

        try await withMountedImage(image) { mountPoint throws(UpdateInstallError) in
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

        // At the version change WidgetKit asks the widget extension for its descriptors again, so
        // the previous version's extension must be gone by then; an update that failed a check
        // leaves it running.
        await WidgetRefresher.endExtensionBeforeSwap()
        guard renamex_np(staged.path, target.path, UInt32(RENAME_SWAP)) == 0 else {
            let reason = String(cString: strerror(errno))
            Diagnostics.update.error("Swapping the app failed: \(reason, privacy: .public)")
            throw UpdateInstallError.replaceFailed
        }
        swapped = true
        return staged
    }

    /// Mounts `image` at a private mount point for `body`, and detaches it afterwards.
    private static func withMountedImage(
        _ image: URL, _ body: (URL) throws(UpdateInstallError) -> Void
    ) async throws(UpdateInstallError) {
        let mountPoint = FileManager.default.temporaryDirectory
            .appendingPathComponent("BatteryPulse-update-\(UUID().uuidString)", isDirectory: true)
        do {
            try FileManager.default.createDirectory(at: mountPoint, withIntermediateDirectories: true)
        } catch {
            throw UpdateInstallError.mountFailed
        }
        let arguments = UpdateInstallPolicy.attachArguments(image: image.path, mountPoint: mountPoint.path)
        let status = try? await run(UpdateInstallPolicy.diskutil, arguments)
        // The image's own disk, for a forced eject; `nil` when no disk image is mounted there.
        let disk = await imageDisk(mountedAt: mountPoint)
        guard status == 0 else {
            // In case it mounted anyway.
            if disk != nil { await detach(mountPoint, disk: disk) } else { _ = rmdir(mountPoint.path) }
            throw UpdateInstallError.mountFailed
        }
        if disk == nil {
            Diagnostics.update.error("The update's disk image isn't in diskutil info; it can't be ejected by force")
        }
        do {
            try body(mountPoint)
        } catch {
            await detach(mountPoint, disk: disk)
            throw error
        }
        await detach(mountPoint, disk: disk)
    }

    /// Ejects the image at `mountPoint`. When that fails, because a file on the volume is still
    /// open, its volumes are unmounted by force and `disk`, the image's own disk, is ejected.
    private static func detach(_ mountPoint: URL, disk: String?) async {
        let path = mountPoint.path
        let tool = UpdateInstallPolicy.diskutil
        var status = try? await run(tool, UpdateInstallPolicy.detachArguments(mountPoint: path))
        if status != 0, let disk {
            for arguments in UpdateInstallPolicy.forcedDetachArguments(disk: disk) {
                status = try? await run(tool, arguments)
            }
        }
        if status != 0 {
            // -1: diskutil didn't start.
            Diagnostics.update.error("Ejecting the update's disk image failed: \(status ?? -1, privacy: .public)")
        }
        // Only an empty folder: never anything still mounted there.
        _ = rmdir(path)
    }

    /// The image's own disk (``UpdateInstallPolicy/imageDisk(info:mountPoint:)``), or `nil` when
    /// no disk image is mounted at `mountPoint`.
    private static func imageDisk(mountedAt mountPoint: URL) async -> String? {
        let arguments = UpdateInstallPolicy.infoArguments(mountPoint: mountPoint.path)
        guard let info = await output(of: UpdateInstallPolicy.diskutil, arguments) else { return nil }
        return UpdateInstallPolicy.imageDisk(info: info, mountPoint: mountPoint.path)
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

    /// Runs a tool without input and returns what it wrote to standard output, or `nil` when it
    /// couldn't start or exited with an error.
    private static func output(of tool: String, _ arguments: [String]) async -> Data? {
        let process = Process()
        let pipe = Pipe()
        process.executableURL = URL(fileURLWithPath: tool)
        process.arguments = arguments
        process.standardInput = FileHandle.nullDevice
        process.standardOutput = pipe
        process.standardError = FileHandle.nullDevice
        let (exits, exited) = AsyncStream.makeStream(of: Int32.self)
        process.terminationHandler = { finished in
            exited.yield(finished.terminationStatus)
            exited.finish()
        }
        do {
            try process.run()
        } catch {
            return nil
        }
        // Read while the tool runs, so a full pipe can't stall it; the read ends when it exits,
        // since launching closed this process's end of the pipe for writing.
        let data = try? pipe.fileHandleForReading.readToEnd()
        var status: Int32?
        for await code in exits { status = code }
        return status == 0 ? data ?? Data() : nil
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
    private static func checkBundle(
        _ bundle: URL, identifier: String, release: AppVersion, current: AppVersion
    ) throws(UpdateInstallError) {
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
    private static func checkCodeSignature(_ bundle: URL) throws(UpdateInstallError) {
        var code: SecStaticCode?
        guard SecStaticCodeCreateWithPath(bundle as CFURL, [], &code) == errSecSuccess, let code else {
            throw UpdateInstallError.invalidCodeSignature
        }
        let flags = SecCSFlags(rawValue: kSecCSStrictValidate | kSecCSCheckAllArchitectures | kSecCSCheckNestedCode)
        var error: Unmanaged<CFError>?
        let status = SecStaticCodeCheckValidityWithErrors(code, flags, nil, &error)
        guard status == errSecSuccess else {
            // The status is a plain code; the error's description can carry the path, so it stays private.
            let reason = error.map { String(describing: $0.takeRetainedValue()) } ?? "unknown"
            Diagnostics.update.error(
                "The new version's code signature isn't valid (\(status, privacy: .public)): \(reason, privacy: .private)"
            )
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
