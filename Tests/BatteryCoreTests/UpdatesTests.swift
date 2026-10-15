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

    @Test func checksFollowTheChosenFrequency() {
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let day: TimeInterval = 86_400
        func due(_ ago: TimeInterval?, _ frequency: UpdateFrequency) -> Bool {
            UpdatePolicy.isCheckDue(lastCheck: ago.map { now.addingTimeInterval(-$0) }, now: now, frequency: frequency)
        }
        #expect(due(nil, .daily))
        #expect(!due(3600, .daily))
        #expect(due(day, .daily))
        #expect(due(-3600, .daily), "clock moved back")
        #expect(!due(6 * day, .weekly))
        #expect(due(7 * day, .weekly))
        #expect(!due(29 * day, .monthly))
        #expect(due(30 * day, .monthly))
        #expect(due(-3600, .monthly), "clock moved back")
        #expect(!due(nil, .never))
        #expect(!due(365 * day, .never))
    }

    @Test func frequencyFollowsTheOldSwitchUntilChosen() {
        #expect(UpdateFrequency.stored(nil, legacyEnabled: nil) == .daily)
        #expect(UpdateFrequency.stored(nil, legacyEnabled: true) == .daily)
        #expect(UpdateFrequency.stored(nil, legacyEnabled: false) == .never)
        #expect(UpdateFrequency.stored("weekly", legacyEnabled: false) == .weekly)
        #expect(UpdateFrequency.stored("hourly", legacyEnabled: nil) == .daily)
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

    @Test func notesWithWindowsLineEndingsKeepTheirLines() {
        #expect(ReleaseNotes.inlineMarkdown("## Install\r\n\r\n- One\r- Two") == "**Install**\n\n- One\n- Two")
    }

    /// 0.3.1's notes, wrapped at 96 columns, showed line breaks mid-sentence in 0.3.0.
    @Test func wrappedLinesOfAParagraphOrListItemAreJoined() {
        let notes = """
            ## What's new in 0.3.1

            Fixes from the first run on a MacBook Air M5:

            - **Power page:** while charging, the requested charge voltage is labeled as per cell (a
              MacBook Air M5 asks for 4.47 V per cell).
            - **Compact window:** long labels are no longer cut off.

            1. Download **BatteryPulse.dmg** below and open it.
            2. Drag **BatteryPulse** onto
               **Applications**.

            Line one with a break  
            line two
            > A quote
            > continued
            ```
            code
              stays
            ```
            ## What's Changed
            * BatteryPulse 0.3.1 by @NikitaUsov in https://github.com/NikitaUsov/BatteryPulse/pull/6
            """
        #expect(
            ReleaseNotes.inlineMarkdown(notes) == """
                **What's new in 0.3.1**

                Fixes from the first run on a MacBook Air M5:

                - **Power page:** while charging, the requested charge voltage is labeled as per cell (a \
                MacBook Air M5 asks for 4.47 V per cell).
                - **Compact window:** long labels are no longer cut off.

                1. Download **BatteryPulse.dmg** below and open it.
                2. Drag **BatteryPulse** onto **Applications**.

                Line one with a break  
                line two
                > A quote
                > continued
                ```
                code
                  stays
                ```
                **What's Changed**
                * BatteryPulse 0.3.1 by @NikitaUsov in https://github.com/NikitaUsov/BatteryPulse/pull/6
                """)
    }

    @Test func whatsNewOnlyAfterAnUpdate() {
        let features = AppVersion("0.3.0")!
        func shows(_ lastSeen: String?, _ current: String) -> Bool {
            UpdatePolicy.showsWhatsNew(
                lastSeen: lastSeen.flatMap(AppVersion.init), current: AppVersion(current)!, features: features)
        }
        #expect(!shows(nil, "0.3.0"), "fresh install")
        #expect(shows("0.2.0", "0.3.0"))
        #expect(!shows("0.3.0", "0.3.0"))
        #expect(shows("0.2.0", "0.3.1"), "skipped 0.3.0")
        #expect(!shows("0.3.0", "0.3.1"), "bug-fix release")
        #expect(!shows("0.2.0", "0.2.5"), "features not in this build")
    }
}
