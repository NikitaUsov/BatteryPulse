import Foundation
import Testing

@testable import BatteryCore

@Suite struct UpdatesTests {
    @Test func versionsParseAndCompare() throws {
        #expect(AppVersion("0.3.0")?.description == "0.3.0")
        #expect(AppVersion("v0.2.0") == AppVersion("0.2"))
        #expect(AppVersion("0.3.0-beta.1")?.description == "0.3.0")
        #expect(AppVersion("abc") == nil)
        #expect(AppVersion("") == nil)
        #expect(AppVersion("1..2") == nil)
        let v020 = try #require(AppVersion("0.2.0"))
        #expect(v020 < AppVersion("0.2.1")!)
        #expect(v020 < AppVersion("0.10")!)
        #expect(AppVersion("1.0")! > AppVersion("0.99.9")!)
        #expect(Set([AppVersion("0.2")!, AppVersion("0.2.0")!]).count == 1)
    }

    /// Trimmed from the real response for BatteryPulse 0.2.0.
    private let latestJSON = Data(
        #"""
        {
          "tag_name": "v0.2.0",
          "name": "BatteryPulse 0.2.0",
          "body": "## Install\n\nRequires a Mac with Apple silicon and macOS 27 or later.",
          "html_url": "https://github.com/NikitaUsov/BatteryPulse/releases/tag/v0.2.0",
          "draft": false,
          "prerelease": false,
          "published_at": "2026-10-14T18:52:36Z",
          "assets": [
            {
              "name": "BatteryPulse.dmg",
              "browser_download_url": "https://github.com/NikitaUsov/BatteryPulse/releases/download/v0.2.0/BatteryPulse.dmg"
            }
          ]
        }
        """#.utf8)

    @Test func parsesTheGitHubRelease() throws {
        let release = try ReleaseInfo.parse(gitHubJSON: latestJSON)
        #expect(release.version == AppVersion("0.2.0"))
        #expect(release.title == "BatteryPulse 0.2.0")
        #expect(release.notes.hasPrefix("## Install"))
        #expect(release.pageURL.absoluteString.hasSuffix("/releases/tag/v0.2.0"))
        #expect(release.downloadURL?.lastPathComponent == "BatteryPulse.dmg")
        #expect(release.publishedAt == Date(timeIntervalSince1970: 1_792_003_956))
    }

    @Test func rejectsWhatIsNotAStableRelease() {
        #expect(throws: ReleaseInfo.ParseError.notARelease) {
            try ReleaseInfo.parse(gitHubJSON: Data(#"{"message": "Not Found"}"#.utf8))
        }
        let prerelease = String(decoding: latestJSON, as: UTF8.self)
            .replacingOccurrences(of: #""prerelease": false"#, with: #""prerelease": true"#)
        #expect(throws: ReleaseInfo.ParseError.draftOrPrerelease) {
            try ReleaseInfo.parse(gitHubJSON: Data(prerelease.utf8))
        }
    }

    @Test func checksRunOnceADay() {
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        #expect(UpdatePolicy.isCheckDue(lastCheck: nil, now: now))
        #expect(!UpdatePolicy.isCheckDue(lastCheck: now.addingTimeInterval(-3600), now: now))
        #expect(UpdatePolicy.isCheckDue(lastCheck: now.addingTimeInterval(-86_400), now: now))
        #expect(UpdatePolicy.isCheckDue(lastCheck: now.addingTimeInterval(3600), now: now), "clock moved back")
    }

    @Test func offersOnlyNewerVersionsAndRespectsSkipping() throws {
        let release = try ReleaseInfo.parse(gitHubJSON: latestJSON)
        let v010 = AppVersion("0.1.0")!
        #expect(UpdatePolicy.shouldOffer(release, current: v010, skipped: nil, userInitiated: false))
        #expect(!UpdatePolicy.shouldOffer(release, current: AppVersion("0.2.0")!, skipped: nil, userInitiated: true))
        #expect(!UpdatePolicy.shouldOffer(release, current: v010, skipped: AppVersion("0.2.0"), userInitiated: false))
        #expect(UpdatePolicy.shouldOffer(release, current: v010, skipped: AppVersion("0.2.0"), userInitiated: true))
        #expect(UpdatePolicy.shouldOffer(release, current: v010, skipped: AppVersion("0.1.5"), userInitiated: false))
    }

    @Test func headingsBecomeBoldLines() {
        let notes = "## Install\n\nRequires macOS 27.\n### First launch\n#hashtag stays"
        #expect(
            ReleaseNotes.inlineMarkdown(notes)
                == "**Install**\n\nRequires macOS 27.\n**First launch**\n#hashtag stays")
    }

    @Test func whatsNewOnlyAfterAnUpdate() {
        #expect(!UpdatePolicy.showsWhatsNew(lastSeen: nil, current: AppVersion("0.3.0")!), "fresh install")
        #expect(UpdatePolicy.showsWhatsNew(lastSeen: AppVersion("0.2.0"), current: AppVersion("0.3.0")!))
        #expect(!UpdatePolicy.showsWhatsNew(lastSeen: AppVersion("0.3.0"), current: AppVersion("0.3.0")!))
    }
}
