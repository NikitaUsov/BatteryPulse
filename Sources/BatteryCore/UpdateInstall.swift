import Foundation

/// Why BatteryPulse can't install an update itself, or why an installation stopped. Every case
/// leaves the installed copy as it was (except ``relaunchFailed``, which comes after the swap);
/// ``fallback`` says what the Software Update window offers instead.
public enum UpdateInstallError: Error, Sendable, Equatable, CaseIterable {
    // Checked before Install and Relaunch is offered.
    /// A build without a version (CI artifacts, `swift run`).
    case developmentBuild
    /// macOS runs this copy from a random read-only location (App Translocation), because it
    /// was opened where it was downloaded instead of from a folder the user moved it to.
    case translocated
    /// This account can't change the app or the folder it is in.
    case folderNotWritable
    /// The release has no DMG or no signature to check it with (releases before 0.4.0).
    case notSigned
    /// The release isn't newer than the running version.
    case notNewer

    // While installing.
    case downloadFailed
    /// The DMG doesn't match GitHub's digest: a broken or incomplete download.
    case digestMismatch
    /// The DMG's signature doesn't verify with ``ReleaseSigning/publicKey``.
    case badSignature
    case mountFailed
    /// The DMG has no BatteryPulse.app, or one with another bundle identifier or version.
    case unexpectedBundle
    /// The new copy's code signature (ad-hoc, sealing its contents) doesn't validate.
    case invalidCodeSignature
    /// The copy couldn't be made next to the app, or the two couldn't be swapped (another
    /// volume, a file system without swapping renames, or macOS refused).
    case replaceFailed
    /// The new version is in place but couldn't be opened; the user has to open it.
    case relaunchFailed

    /// A network failure is worth another try; the other checks would fail the same way again.
    public var isRetryable: Bool { self == .downloadFailed }

    /// The DMG failed a check that shows it is the release workflow's, or has no signature to
    /// check. The app can't tell a broken release from a forged one, so it never offers that DMG.
    public var isIntegrityFailure: Bool {
        switch self {
        case .notSigned, .digestMismatch, .badSignature, .unexpectedBundle, .invalidCodeSignature: true
        case .developmentBuild, .translocated, .folderNotWritable, .notNewer, .downloadFailed, .mountFailed,
            .replaceFailed, .relaunchFailed:
            false
        }
    }

    /// What the window offers when the app doesn't install the update itself.
    public var fallback: UpdateFallback {
        if isIntegrityFailure { return .releasePage }
        return self == .relaunchFailed ? .none : .downloadDMG
    }
}

/// The way forward when BatteryPulse doesn't install an update itself.
public enum UpdateFallback: Sendable, Equatable {
    /// The DMG in the browser: nothing says it isn't genuine, the app just can't install it here.
    case downloadDMG
    /// A warning and the release page, never the DMG: offering the file the app refused would
    /// steer the user past the check.
    case releasePage
    /// Nothing: the update is already installed.
    case none
}

/// Checks for the downloaded DMG that need no platform frameworks.
public enum UpdateIntegrity {
    public enum DigestCheck: Sendable, Equatable {
        case matches
        case mismatch
        /// No digest to compare with: an older asset, or an algorithm other than SHA-256.
        case unavailable
    }

    /// Compares a SHA-256 in hex with GitHub's asset digest, `sha256:<64 hex digits>`. A
    /// malformed SHA-256 digest counts as a mismatch, so the check fails closed.
    public static func check(sha256Hex: String, against digest: String?) -> DigestCheck {
        guard let digest = digest?.trimmingCharacters(in: .whitespacesAndNewlines), !digest.isEmpty else {
            return .unavailable
        }
        let parts = digest.split(separator: ":", maxSplits: 1, omittingEmptySubsequences: false)
        guard parts.count == 2, parts[0].lowercased() == "sha256" else { return .unavailable }
        let expected = parts[1].lowercased()
        guard expected.count == 64, expected.allSatisfy(\.isHexDigit) else { return .mismatch }
        return expected == sha256Hex.lowercased() ? .matches : .mismatch
    }

    /// Bytes as lowercase hex, the form of GitHub's digests.
    public static func hex(_ bytes: some Sequence<UInt8>) -> String {
        let digits = Array("0123456789abcdef")
        var text = ""
        for byte in bytes {
            text.append(digits[Int(byte >> 4)])
            text.append(digits[Int(byte & 0x0F)])
        }
        return text
    }

    /// The 64-byte Ed25519 signature in a `.sig` file as `scripts/sign-update.swift` writes it:
    /// base64 and a line break.
    public static func signature(fromSigFile data: Data) -> Data? {
        guard data.count <= 1024, let text = String(data: data, encoding: .utf8) else { return nil }
        let base64 = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let signature = Data(base64Encoded: base64), signature.count == 64 else { return nil }
        return signature
    }
}

/// When the app may replace itself, and the commands it runs to do so.
public enum UpdateInstallPolicy {
    /// The version builds without one get: they never install updates.
    public static let unversioned = AppVersion(parts: [0, 0, 0])

    /// The release asset with the signature of `assetName`.
    public static func signatureAssetName(for assetName: String) -> String {
        assetName + ".sig"
    }

    /// Why this copy can't install `release` itself, or `nil` when it can. `canWrite` says whether
    /// this account may change the app bundle and the folder it is in.
    public static func blocker(
        release: ReleaseInfo, current: AppVersion, bundlePath: String, canWrite: Bool
    ) -> UpdateInstallError? {
        if current == unversioned { return .developmentBuild }
        if isTranslocated(bundlePath) { return .translocated }
        guard release.version > current else { return .notNewer }
        guard release.downloadURL?.scheme == "https", release.signatureURL?.scheme == "https" else {
            return .notSigned
        }
        guard bundlePath.hasSuffix(".app"), canWrite else { return .folderNotWritable }
        return nil
    }

    /// macOS runs a quarantined app opened from where it was downloaded from a randomized
    /// read-only path. There is no API to tell; the path is the evidence.
    public static func isTranslocated(_ bundlePath: String) -> Bool {
        bundlePath.contains("/AppTranslocation/")
    }

    /// Checks the Info.plist values of the copy taken out of the DMG before it replaces this one:
    /// the same app, exactly the release's version, and newer than the running one.
    public static func checkStagedBundle(
        identifier: String?, version: String?, expectedIdentifier: String, release: AppVersion, current: AppVersion
    ) -> UpdateInstallError? {
        guard !expectedIdentifier.isEmpty, identifier == expectedIdentifier,
            let version = version.flatMap(AppVersion.init), version == release
        else { return .unexpectedBundle }
        return release > current ? nil : .notNewer
    }

    /// `hdiutil` arguments that mount the DMG read-only at a private mount point, without a
    /// Finder window, a sidebar entry or opening anything.
    public static func attachArguments(image: String, mountPoint: String) -> [String] {
        ["attach", image, "-nobrowse", "-readonly", "-noautoopen", "-mountpoint", mountPoint]
    }

    public static func detachArguments(mountPoint: String, force: Bool) -> [String] {
        ["detach", mountPoint] + (force ? ["-force"] : [])
    }

    /// `/bin/sh` arguments that open the updated app once this process has quit: wait up to
    /// about 10 seconds for `processID` to exit, give it a second more, then open a new
    /// instance. The path is passed as an argument, never inside the script, so no character in
    /// it can change the command.
    public static func relaunchArguments(
        appPath: String, processID: Int32, opener: String = "/usr/bin/open"
    ) -> [String] {
        let script =
            #"i=0; while kill -0 "$2" 2>/dev/null && [ "$i" -lt 50 ]; do sleep 0.2; i=$((i + 1)); done; "#
            + #"sleep 1; exec "$3" -n "$1""#
        return ["-c", script, "sh", appPath, String(processID), opener]
    }

    /// The previous version that an update swapped out, to delete at the next launch: only an
    /// absolute path to an app bundle that is neither the running app nor inside or around it.
    public static func leftoverToDelete(recorded: String?, runningBundlePath: String) -> String? {
        guard let recorded, recorded.hasPrefix("/") else { return nil }
        let leftover = standardized(recorded)
        let running = standardized(runningBundlePath)
        guard leftover.hasSuffix(".app"), leftover.split(separator: "/").count >= 2,
            leftover != running, !running.hasPrefix(leftover + "/"), !leftover.hasPrefix(running + "/")
        else { return nil }
        return leftover
    }

    private static func standardized(_ path: String) -> String {
        var components: [Substring] = []
        for component in path.split(separator: "/") {
            switch component {
            case ".": continue
            case "..": _ = components.popLast()
            default: components.append(component)
            }
        }
        return "/" + components.joined(separator: "/")
    }
}
