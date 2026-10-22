import Foundation
import Testing

@testable import BatteryCore

@Suite struct UpdateInstallTests {
    /// Trimmed from the real response for BatteryPulse 0.3.1, plus the signature asset that
    /// releases attach from 0.4.0 on.
    private let signedJSON = Data(
        #"""
        {
          "tag_name": "v0.4.0",
          "name": "BatteryPulse 0.4.0",
          "body": "Notes",
          "html_url": "https://github.com/NikitaUsov/BatteryPulse/releases/tag/v0.4.0",
          "draft": false,
          "prerelease": false,
          "published_at": "2026-10-15T07:03:00Z",
          "assets": [
            {
              "name": "BatteryPulse.dmg",
              "size": 4873216,
              "digest": "sha256:59fff861facd4a3522e23c3f7fdd26d1f8f4a35a25fcb231531465e7f93aa4dd",
              "browser_download_url": "https://github.com/NikitaUsov/BatteryPulse/releases/download/v0.4.0/BatteryPulse.dmg"
            },
            {
              "name": "BatteryPulse.dmg.sig",
              "size": 89,
              "digest": "sha256:0000000000000000000000000000000000000000000000000000000000000000",
              "browser_download_url": "https://github.com/NikitaUsov/BatteryPulse/releases/download/v0.4.0/BatteryPulse.dmg.sig"
            }
          ]
        }
        """#.utf8)

    /// A release from before GitHub's digests and the signature: only the DMG, `digest` null.
    private let unsignedJSON = Data(
        #"""
        {
          "tag_name": "v0.2.0",
          "html_url": "https://github.com/NikitaUsov/BatteryPulse/releases/tag/v0.2.0",
          "assets": [
            {
              "name": "BatteryPulse.dmg",
              "digest": null,
              "browser_download_url": "https://github.com/NikitaUsov/BatteryPulse/releases/download/v0.2.0/BatteryPulse.dmg"
            }
          ]
        }
        """#.utf8)

    private static let v031 = AppVersion(parts: [0, 3, 1])
    private static let v040 = AppVersion(parts: [0, 4, 0])

    @Test func parsesTheDigestSizeAndSignatureAsset() throws {
        let release = try ReleaseInfo.parse(gitHubJSON: signedJSON)
        #expect(release.downloadURL?.lastPathComponent == "BatteryPulse.dmg")
        #expect(release.downloadDigest == "sha256:59fff861facd4a3522e23c3f7fdd26d1f8f4a35a25fcb231531465e7f93aa4dd")
        #expect(release.downloadSize == 4_873_216)
        #expect(release.signatureURL?.absoluteString.hasSuffix("/v0.4.0/BatteryPulse.dmg.sig") == true)
    }

    @Test func releasesWithoutDigestOrSignatureStillParse() throws {
        let release = try ReleaseInfo.parse(gitHubJSON: unsignedJSON)
        #expect(release.version == AppVersion("0.2.0"))
        #expect(release.downloadURL != nil)
        #expect(release.downloadDigest == nil)
        #expect(release.downloadSize == nil)
        #expect(release.signatureURL == nil)
        // No assets at all.
        let bare = #"{"tag_name": "v0.1.0", "html_url": "https://example.com/r"}"#
        let noAssets = try ReleaseInfo.parse(gitHubJSON: Data(bare.utf8))
        #expect(noAssets.downloadURL == nil && noAssets.signatureURL == nil)
    }

    @Test func comparesTheSHA256WithGitHubsDigest() {
        let hash = "59fff861facd4a3522e23c3f7fdd26d1f8f4a35a25fcb231531465e7f93aa4dd"
        func check(_ digest: String?, _ sha: String = hash) -> UpdateIntegrity.DigestCheck {
            UpdateIntegrity.check(sha256Hex: sha, against: digest)
        }
        #expect(check("sha256:" + hash) == .matches)
        #expect(check("SHA256:" + hash.uppercased()) == .matches)
        #expect(check(" sha256:\(hash)\n") == .matches)
        #expect(check("sha256:" + hash, hash.uppercased()) == .matches)
        #expect(check("sha256:" + String(repeating: "0", count: 64)) == .mismatch)
        #expect(check("sha256:" + hash.dropLast()) == .mismatch, "too short")
        #expect(check("sha256:" + hash.dropLast() + "g") == .mismatch, "not hex")
        #expect(check("sha256:") == .mismatch)
        #expect(check(nil) == .unavailable)
        #expect(check("") == .unavailable)
        #expect(check("sha512:abcd") == .unavailable)
        #expect(check(hash) == .unavailable, "no algorithm")
    }

    @Test func formatsBytesAsLowercaseHex() {
        #expect(UpdateIntegrity.hex([0x00, 0x0F, 0xA0, 0xFF]) == "000fa0ff")
        #expect(UpdateIntegrity.hex([UInt8]()) == "")
    }

    @Test func readsTheSignatureFile() {
        let signature = Data((0..<64).map { UInt8($0) })
        let file = Data((signature.base64EncodedString() + "\n").utf8)
        #expect(UpdateIntegrity.signature(fromSigFile: file) == signature)
        #expect(UpdateIntegrity.signature(fromSigFile: Data(signature.base64EncodedString().utf8)) == signature)
        let short = Data(Data(count: 63).base64EncodedString().utf8)
        #expect(UpdateIntegrity.signature(fromSigFile: short) == nil)
        #expect(UpdateIntegrity.signature(fromSigFile: Data("not base64!".utf8)) == nil)
        #expect(UpdateIntegrity.signature(fromSigFile: Data()) == nil)
        #expect(UpdateIntegrity.signature(fromSigFile: Data(repeating: 0x41, count: 4096)) == nil)
    }

    @Test func theReleaseKeysAreRawCurve25519Keys() {
        #expect(!ReleaseSigning.publicKeys.isEmpty)
        #expect(ReleaseSigning.rawKeys(ReleaseSigning.publicKeys).count == ReleaseSigning.publicKeys.count)
        // The key every release since 0.4.0 is signed with stays trusted; dropping it is the last
        // step of a rotation (scripts/sign-update.swift --help).
        #expect(ReleaseSigning.publicKeys.contains("R3LDmkmupenX1gnEnR7n+gEllH8oIDbWODJoGJ/m+dg="))
    }

    @Test func malformedKeyEntriesAreIgnored() {
        let first = Data(repeating: 1, count: 32)
        let second = Data(repeating: 2, count: 32)
        let entries = [
            "", "not base64", Data(count: 31).base64EncodedString(), Data(count: 33).base64EncodedString(),
            first.base64EncodedString(), " " + second.base64EncodedString() + " ", first.base64EncodedString(),
        ]
        #expect(ReleaseSigning.rawKeys(entries) == [first, second])
        #expect(ReleaseSigning.rawKeys([]).isEmpty)
    }

    @Test func installsOnlyFromAWritableUntranslocatedRelease() throws {
        let release = try ReleaseInfo.parse(gitHubJSON: signedJSON)
        let app = "/Applications/BatteryPulse.app"
        func blocker(
            _ release: ReleaseInfo, current: AppVersion = UpdateInstallTests.v031, path: String = app,
            canWrite: Bool = true
        ) -> UpdateInstallError? {
            UpdateInstallPolicy.blocker(release: release, current: current, bundlePath: path, canWrite: canWrite)
        }
        #expect(blocker(release) == nil)
        #expect(blocker(release, path: "/Users/me/Applications/BatteryPulse.app") == nil)
        #expect(blocker(release, current: UpdateInstallPolicy.unversioned) == .developmentBuild)
        #expect(
            blocker(release, path: "/private/var/folders/x/T/AppTranslocation/1234-5678/d/BatteryPulse.app")
                == .translocated)
        #expect(blocker(release, current: Self.v040) == .notNewer)
        #expect(blocker(release, current: AppVersion(parts: [0, 5])) == .notNewer)
        #expect(blocker(release, canWrite: false) == .folderNotWritable)
        #expect(blocker(release, path: "/usr/local/bin/BatteryPulse") == .folderNotWritable)

        let old = try ReleaseInfo.parse(gitHubJSON: unsignedJSON)
        #expect(blocker(old, current: AppVersion(parts: [0, 1])) == .notSigned)
        var insecure = release
        insecure.signatureURL = URL(string: "http://example.com/BatteryPulse.dmg.sig")
        #expect(blocker(insecure) == .notSigned)
        var noImage = release
        noImage.downloadURL = nil
        #expect(blocker(noImage) == .notSigned)
    }

    @Test func checksTheCopyTakenOutOfTheDMG() {
        let id = "io.github.nikitausov.BatteryPulse"
        func check(_ identifier: String?, _ version: String?, current: AppVersion = UpdateInstallTests.v031)
            -> UpdateInstallError?
        {
            UpdateInstallPolicy.checkStagedBundle(
                identifier: identifier, version: version, expectedIdentifier: id, release: Self.v040, current: current)
        }
        #expect(check(id, "0.4.0") == nil)
        #expect(check(id, "0.4") == nil)
        #expect(check(id + ".Widget", "0.4.0") == .unexpectedBundle)
        #expect(check(nil, "0.4.0") == .unexpectedBundle)
        #expect(check(id, "0.4.1") == .unexpectedBundle)
        #expect(check(id, "0.3.1") == .unexpectedBundle)
        #expect(check(id, nil) == .unexpectedBundle)
        #expect(check(id, "0.4.0", current: Self.v040) == .notNewer)
        #expect(
            UpdateInstallPolicy.checkStagedBundle(
                identifier: "", version: "0.4.0", expectedIdentifier: "", release: Self.v040, current: Self.v031)
                == .unexpectedBundle)
    }

    /// An older release never replaces a newer copy, even signed with the release key: it isn't
    /// offered, Install and Relaunch isn't, and a DMG whose app is older than the one running, or
    /// than the release it came with, is refused before the swap.
    @Test func refusesADowngrade() throws {
        let release = try ReleaseInfo.parse(gitHubJSON: signedJSON)
        let newer = AppVersion(parts: [0, 5])
        #expect(!UpdatePolicy.shouldOffer(release, current: newer, skipped: nil, userInitiated: true))
        #expect(
            UpdateInstallPolicy.blocker(
                release: release, current: newer, bundlePath: "/Applications/BatteryPulse.app", canWrite: true)
                == .notNewer)
        let id = "io.github.nikitausov.BatteryPulse"
        func check(_ version: String, release: AppVersion, current: AppVersion) -> UpdateInstallError? {
            UpdateInstallPolicy.checkStagedBundle(
                identifier: id, version: version, expectedIdentifier: id, release: release, current: current)
        }
        #expect(check("0.4.0", release: Self.v040, current: newer) == .notNewer)
        #expect(check("0.4.0", release: Self.v040, current: Self.v040) == .notNewer)
        #expect(check("0.3.1", release: Self.v040, current: Self.v031) == .unexpectedBundle)
        #expect(check("0.4.0", release: Self.v040, current: Self.v031) == nil)
    }

    @Test func mountsReadOnlyWithoutFinder() {
        let arguments = UpdateInstallPolicy.attachArguments(image: "/tmp/a b/BatteryPulse.dmg", mountPoint: "/tmp/m")
        #expect(arguments.first == "attach")
        #expect(arguments[1] == "/tmp/a b/BatteryPulse.dmg")
        for flag in ["-nobrowse", "-readonly", "-noautoopen"] {
            #expect(arguments.contains(flag))
        }
        let mountPoint = arguments.firstIndex(of: "-mountpoint")
        #expect(mountPoint.map { arguments[$0 + 1] } == "/tmp/m")
        #expect(UpdateInstallPolicy.detachArguments(mountPoint: "/tmp/m", force: false) == ["detach", "/tmp/m"])
        #expect(
            UpdateInstallPolicy.detachArguments(mountPoint: "/tmp/m", force: true) == ["detach", "/tmp/m", "-force"])
    }

    /// Runs the relaunch script with a stand-in for `open` that records its arguments, using a
    /// path that would break any quoting.
    @Test func relaunchPassesThePathUntouched() throws {
        let folder = FileManager.default.temporaryDirectory
            .appendingPathComponent("relaunch-test-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: folder) }
        let record = folder.appendingPathComponent("arguments.txt")
        let opener = folder.appendingPathComponent("open.sh")
        try Data("#!/bin/sh\nprintf '%s\\n' \"$@\" > \"\(record.path)\"\n".utf8).write(to: opener)
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: opener.path)

        let appPath = #"/Applications/My "Battery" $(touch x); Pulse's.app"#
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/sh")
        // No process has this ID, so the script doesn't wait.
        var arguments = UpdateInstallPolicy.relaunchArguments(
            appPath: appPath, processID: Int32.max, opener: opener.path)
        // The app's script gives the old process a second more; the test runs it without that pause.
        #expect(arguments[1].contains("sleep 1; exec"))
        arguments[1] = arguments[1].replacingOccurrences(of: "sleep 1;", with: "sleep 0;")
        process.arguments = arguments
        try process.run()
        process.waitUntilExit()
        #expect(process.terminationStatus == 0)
        let recorded = try String(contentsOf: record, encoding: .utf8)
        #expect(recorded == "-n\n" + appPath + "\n")
    }

    @Test func deletesOnlyThePreviousVersion() {
        let running = "/Applications/BatteryPulse.app"
        func leftover(_ recorded: String?) -> String? {
            UpdateInstallPolicy.leftoverToDelete(recorded: recorded, runningBundlePath: running)
        }
        let old = "/private/var/folders/ab/T/TemporaryItems/NSIRD_BatteryPulse_x/BatteryPulse.app"
        #expect(leftover(old) == old)
        #expect(leftover("/Users/me/x/./y/../BatteryPulse.app") == "/Users/me/x/BatteryPulse.app")
        #expect(leftover(nil) == nil)
        #expect(leftover("") == nil)
        #expect(leftover("relative/BatteryPulse.app") == nil)
        #expect(leftover("/private/var/folders/ab/T") == nil, "not an app")
        #expect(leftover(running) == nil)
        #expect(leftover("/Applications/x/../BatteryPulse.app") == nil, "the running app, spelled differently")
        #expect(leftover(running + "/Contents/PlugIns/BatteryPulseWidget.appex/x.app") == nil, "inside it")
        #expect(leftover("/.app") == nil)
        #expect(
            UpdateInstallPolicy.leftoverToDelete(
                recorded: "/Volumes/X/Apps.app", runningBundlePath: "/Volumes/X/Apps.app/Contents/x.app") == nil,
            "around it")
    }

    @Test func errorsSayWhatComesNext() {
        #expect(UpdateInstallError.downloadFailed.isRetryable)
        #expect(!UpdateInstallError.badSignature.isRetryable)
        #expect(UpdateInstallPolicy.signatureAssetName(for: "BatteryPulse.dmg") == "BatteryPulse.dmg.sig")
    }

    /// After a failed integrity check, or for a release without a signature, the window offers
    /// only the release page, never the DMG the app refused.
    @Test func everyErrorMapsToItsFallback() {
        let expected: [UpdateInstallError: UpdateFallback] = [
            .developmentBuild: .downloadDMG,
            .translocated: .downloadDMG,
            .folderNotWritable: .downloadDMG,
            .notSigned: .releasePage,
            .notNewer: .downloadDMG,
            .downloadFailed: .downloadDMG,
            .digestMismatch: .releasePage,
            .badSignature: .releasePage,
            .mountFailed: .downloadDMG,
            .unexpectedBundle: .releasePage,
            .invalidCodeSignature: .releasePage,
            .replaceFailed: .downloadDMG,
            .relaunchFailed: .none,
        ]
        #expect(Set(expected.keys) == Set(UpdateInstallError.allCases))
        for error in UpdateInstallError.allCases {
            #expect(error.fallback == expected[error], "\(error)")
            #expect(error.isIntegrityFailure == (expected[error] == .releasePage), "\(error)")
        }
        // An integrity failure is never worth another try.
        #expect(!UpdateInstallError.allCases.contains { $0.isIntegrityFailure && $0.isRetryable })
    }

    @Test func theBrowserOpensOnlyGitHubPages() throws {
        func opens(_ string: String) throws -> URL {
            ReleaseLinks.browserURL(for: try #require(URL(string: string)))
        }
        let page = "https://github.com/NikitaUsov/BatteryPulse/releases/tag/v0.4.0"
        let download = "https://github.com/NikitaUsov/BatteryPulse/releases/download/v0.4.0/BatteryPulse.dmg"
        #expect(try opens(page).absoluteString == page)
        #expect(try opens(download).absoluteString == download)
        #expect(
            try opens("HTTPS://GitHub.com/NikitaUsov/BatteryPulse").absoluteString.lowercased().hasPrefix(
                "https://github.com/"))
        // A repository that moved still opens: no exact prefix is pinned.
        #expect(try opens("https://github.com/someone/Renamed/releases").absoluteString.hasSuffix("/Renamed/releases"))
        let relative = try #require(URL(string: "releases/tag/v1", relativeTo: URL(string: "https://github.com/a/b/")))
        #expect(ReleaseLinks.browserURL(for: relative).absoluteString == "https://github.com/a/b/releases/tag/v1")

        for refused in [
            "http://github.com/NikitaUsov/BatteryPulse/releases",
            "file:///Applications/BatteryPulse.app",
            "someapp://github.com/x",
            "x-apple.systempreferences:com.apple.Localization-Settings.extension",
            "https://example.com/BatteryPulse.dmg",
            "https://github.com.example.com/x",
            "https://objects.githubusercontent.com/x",
            "https://github.com@example.com/x",
        ] {
            #expect(try opens(refused) == ReleaseChannel.releasesPage, "\(refused)")
        }
    }
}
