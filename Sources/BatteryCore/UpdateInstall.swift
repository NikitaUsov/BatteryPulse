import Foundation

/// Why BatteryPulse can't install an update itself, or why an installation stopped. Every case
/// leaves the installed copy as it was (except ``relaunchFailed``, which comes after the swap);
/// ``fallback`` says what the Software Update window offers instead.
public enum UpdateInstallError: Error, Sendable, Hashable {
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
    /// The DMG's signature doesn't verify with any of ``ReleaseSigning/publicKeys``.
    case badSignature
    case mountFailed
    /// The DMG has no BatteryPulse.app, or one with another bundle identifier or version, or
    /// without a readable `LSMinimumSystemVersion`.
    case unexpectedBundle
    /// The new copy's code signature (ad-hoc, sealing its contents) doesn't validate.
    case invalidCodeSignature
    /// The new copy's `LSMinimumSystemVersion`, `minimum`, is above the running macOS, which
    /// wouldn't open it.
    case needsNewerMacOS(minimum: AppVersion)
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
            .needsNewerMacOS, .replaceFailed, .relaunchFailed:
            false
        }
    }

    /// What the window offers when the app doesn't install the update itself.
    public var fallback: UpdateFallback {
        switch self {
        case .relaunchFailed: .none
        // The update is genuine, but the DMG wouldn't help here: the release page says what the
        // update needs.
        case .needsNewerMacOS: .releasePage
        default: isIntegrityFailure ? .releasePage : .downloadDMG
        }
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
///
/// The updater's boundaries:
/// - **Who made the update:** only an Ed25519 signature by one of ``ReleaseSigning/publicKeys``
///   lets the app install a DMG. GitHub's digest shows only that the download is intact, so the
///   hosts the DMG and its signature come from aren't filtered: the signature is the authority.
/// - **After a failed check:** the app never offers the refused DMG, only the release page
///   (``UpdateFallback/releasePage``), and the browser opens only `https` pages on github.com
///   (``ReleaseLinks``).
/// - **Release notes:** anyone who can publish a release can write them, and they stay editable,
///   so a link in them opens only over `https`, on any host (``ReleaseNotes/isAllowedLink(_:)``).
/// - **Which version:** the copy taken out of the DMG must be this app at exactly the release's
///   version, and newer than the running one, so an older signed release can't be installed
///   over a newer one, and it must run on this Mac's macOS, so an update can't leave an app that
///   macOS won't open
///   (``checkStagedBundle(identifier:version:minimumSystemVersion:expectedIdentifier:release:current:system:)``).
/// - **Not a boundary:** another process of the same user. It could change the DMG between the
///   check and the mount, or the new copy between the check and the swap, but it can replace the
///   app anyway, so the updater doesn't try to defend against it.
/// - **Quarantine:** the app clears it on the new copy, and the Info.plist has no
///   `LSFileQuarantineEnabled`, so the new version opens without Open Anyway.
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
    /// the same app, exactly the release's version, newer than the running one, and an
    /// `LSMinimumSystemVersion` that `system`, the running macOS (``runningSystem``), meets. A
    /// copy without a readable `LSMinimumSystemVersion` (``minimumSystem(_:)``) isn't what the
    /// release workflow builds: `build-app.sh` always writes one.
    public static func checkStagedBundle(
        identifier: String?, version: String?, minimumSystemVersion: String?, expectedIdentifier: String,
        release: AppVersion, current: AppVersion, system: AppVersion
    ) -> UpdateInstallError? {
        guard !expectedIdentifier.isEmpty, identifier == expectedIdentifier,
            let version = version.flatMap(AppVersion.init), version == release,
            let minimum = minimumSystem(minimumSystemVersion)
        else { return .unexpectedBundle }
        guard release > current else { return .notNewer }
        return minimum > system ? .needsNewerMacOS(minimum: minimum) : nil
    }

    /// An `LSMinimumSystemVersion` value: one to three numbers of ASCII digits separated by dots,
    /// as in `27.0` or `27.1.2`. `nil` for a missing, empty or malformed value, which the check
    /// refuses: unlike ``AppVersion/init(_:)``, nothing around the numbers is ignored.
    public static func minimumSystem(_ value: String?) -> AppVersion? {
        guard let value else { return nil }
        let parts = value.split(separator: ".", omittingEmptySubsequences: false)
        let numbers = parts.compactMap { part in
            part.allSatisfy { ("0"..."9").contains($0) } ? Int(part) : nil
        }
        guard (1...3).contains(parts.count), numbers.count == parts.count else { return nil }
        return AppVersion(parts: numbers)
    }

    /// The version of the running system (macOS, on a Mac), which a staged copy's
    /// `LSMinimumSystemVersion` must not be above.
    public static var runningSystem: AppVersion {
        let version = ProcessInfo.processInfo.operatingSystemVersion
        return AppVersion(parts: [version.majorVersion, version.minorVersion, version.patchVersion])
    }

    /// The tool the installer attaches, inspects and ejects the DMG with. Since macOS 26 it
    /// attaches disk images itself (`diskutil image`), and macOS 27 marks `hdiutil attach` and
    /// `detach` deprecated in its favour. Updaters up to 0.6.1 used `hdiutil`.
    public static let diskutil = "/usr/sbin/diskutil"

    /// `diskutil` arguments that attach the DMG read-only at a private mount point, without a
    /// Finder window or a sidebar entry, in the order of `diskutil image attach`'s usage. The
    /// options are the ones macOS 27's deprecation warning maps `hdiutil attach -nobrowse
    /// -readonly -mountpoint` to. `diskutil image attach` has no counterpart of `hdiutil`'s
    /// `-noautoopen`, and the DMG isn't marked to open a window. It has none of `-noverify`
    /// either, and needs none: the DMG's digest and signature were checked before it is attached.
    public static func attachArguments(image: String, mountPoint: String) -> [String] {
        ["image", "attach", "--readOnly", "--mountPoint", mountPoint, "--mountOptions", "nobrowse", image]
    }

    /// `diskutil` arguments that print what is mounted at `mountPoint` as a property list, for
    /// ``imageDisk(info:mountPoint:)``.
    public static func infoArguments(mountPoint: String) -> [String] {
        ["info", "-plist", mountPoint]
    }

    /// Ejects the image mounted at `mountPoint`. That also detaches the image's own disk, below
    /// the APFS container its volume sits on (CI's install step checks it).
    public static func detachArguments(mountPoint: String) -> [String] {
        ["eject", mountPoint]
    }

    /// The commands, in order, that detach the image when ``detachArguments(mountPoint:)`` failed
    /// because a file on the volume is still open: unmount every volume of `disk`, the image's
    /// own disk, by force, then eject it. Older `diskutil` versions take `force` only for
    /// `unmount` and `unmountDisk`, not for `eject`.
    public static func forcedDetachArguments(disk: String) -> [[String]] {
        [["unmountDisk", "force", disk], ["eject", disk]]
    }

    /// The disk image's own whole disk (`disk4`) from the property list that
    /// ``infoArguments(mountPoint:)`` prints, for ``forcedDetachArguments(disk:)``. `nil` unless
    /// a volume of a disk image is mounted at exactly `mountPoint`; `/private/var` and `/var`
    /// count as the same. An APFS volume sits on a synthesized container whose one physical
    /// store is a partition of the image's disk; any other volume is a partition of it.
    public static func imageDisk(info: Data, mountPoint: String) -> String? {
        guard mountPoint.hasPrefix("/"), let disk = try? PropertyListDecoder().decode(DiskInfo.self, from: info),
            let mounted = disk.mountPoint, withoutPrivate(mounted) == withoutPrivate(mountPoint),
            disk.busProtocol == "Disk Image"
        else { return nil }
        let partition: String?
        if let stores = disk.physicalStores {
            guard stores.count == 1 else { return nil }
            partition = stores[0].identifier
        } else {
            partition = disk.parentWholeDisk
        }
        return partition.flatMap(wholeDisk(of:))
    }

    /// The keys of `diskutil info -plist` that ``imageDisk(info:mountPoint:)`` reads.
    private struct DiskInfo: Decodable {
        struct PhysicalStore: Decodable {
            var identifier: String?

            enum CodingKeys: String, CodingKey {
                case identifier = "APFSPhysicalStore"
            }
        }

        var mountPoint: String?
        var busProtocol: String?
        var physicalStores: [PhysicalStore]?
        var parentWholeDisk: String?

        enum CodingKeys: String, CodingKey {
            case mountPoint = "MountPoint"
            case busProtocol = "BusProtocol"
            case physicalStores = "APFSPhysicalStores"
            case parentWholeDisk = "ParentWholeDisk"
        }
    }

    /// `disk4` for `disk4` or `disk4s1`, and `nil` for anything else.
    private static func wholeDisk(of identifier: String) -> String? {
        guard identifier.hasPrefix("disk") else { return nil }
        let numbers = identifier.dropFirst(4).split(separator: "s", omittingEmptySubsequences: false)
        guard (1...2).contains(numbers.count),
            numbers.allSatisfy({ !$0.isEmpty && $0.allSatisfy { ("0"..."9").contains($0) } })
        else { return nil }
        return "disk" + numbers[0]
    }

    /// `/var`, `/tmp` and `/etc` are links into `/private`, and a mount point is reported resolved.
    private static func withoutPrivate(_ path: String) -> String {
        path.hasPrefix("/private/") ? String(path.dropFirst("/private".count)) : path
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
