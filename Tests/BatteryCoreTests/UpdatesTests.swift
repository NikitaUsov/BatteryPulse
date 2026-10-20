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

    /// The links 0.6.0 spelled out one by one, now derived from one repository constant.
    @Test func theReleaseChannelKeepsTheLinks() {
        #expect(
            ReleaseChannel.latestRelease.absoluteString
                == "https://api.github.com/repos/NikitaUsov/BatteryPulse/releases/latest")
        #expect(ReleaseChannel.project.absoluteString == "https://github.com/NikitaUsov/BatteryPulse")
        #expect(ReleaseChannel.releasesPage.absoluteString == "https://github.com/NikitaUsov/BatteryPulse/releases")
        #expect(
            ReleaseChannel.file("docs/USER_GUIDE.md").absoluteString
                == "https://github.com/NikitaUsov/BatteryPulse/blob/main/docs/USER_GUIDE.md")
        #expect(ReleaseChannel.assetName == "BatteryPulse.dmg")
    }

    @Test func notesOpenOnlyHTTPSLinks() throws {
        func allowed(_ string: String) throws -> Bool {
            ReleaseNotes.isAllowedLink(try #require(URL(string: string)))
        }
        #expect(try allowed("https://github.com/NikitaUsov/BatteryPulse/releases"))
        #expect(try allowed("https://developer.apple.com/documentation/swiftui"))
        #expect(try allowed("HTTPS://Example.com/x"))
        let page = try #require(URL(string: "https://github.com/NikitaUsov/BatteryPulse/releases/tag/v0.6.0"))
        #expect(ReleaseNotes.isAllowedLink(try #require(URL(string: "../v0.5.0", relativeTo: page))))
        for refused in [
            "http://github.com/NikitaUsov/BatteryPulse", "file:///System", "someapp://open?x=1",
            "x-apple.systempreferences:com.apple.Localization-Settings.extension", "mailto:someone@example.com",
            "https:no-host",
        ] {
            #expect(try !allowed(refused), "\(refused)")
        }
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

    /// A line that starts with inline code isn't a fence, and a fence closes only with its own
    /// character, at least as many times.
    @Test func onlyAFenceStartsACodeBlock() {
        let notes = """
            Run
            ```bpulse --raw``` to write a capture
            and attach it.
            ## Code
            ~~~swift
            let a = 1
            ```
            not the end
            ~~~
            After the
            fence.
            ````text
            ```
            nested
            ````
            Wrapped
            again.
            ```
            Unclosed
            fence
            """
        #expect(
            ReleaseNotes.inlineMarkdown(notes) == """
                Run ```bpulse --raw``` to write a capture and attach it.
                **Code**
                ~~~swift
                let a = 1
                ```
                not the end
                ~~~
                After the fence.
                ````text
                ```
                nested
                ````
                Wrapped again.
                ```
                Unclosed
                fence
                """)
    }

    /// A trailing backslash is a line break like two trailing spaces; it's dropped when the next
    /// line continues the text, and stays (as GitHub shows it) at the end of a paragraph or item.
    @Test func aTrailingBackslashKeepsTheLineBreak() {
        let notes = #"""
            First line\
            second line
            wrapped.

            One
            two\
            three

            An escaped backslash \\
            doesn't break the line.

            - An item\
              continued
            - Ends an item\
            - Next item

            Ends a paragraph\

            Next.
            """#
        #expect(
            ReleaseNotes.inlineMarkdown(notes) == #"""
                First line
                second line wrapped.

                One two
                three

                An escaped backslash \\ doesn't break the line.

                - An item
                  continued
                - Ends an item\
                - Next item

                Ends a paragraph\

                Next.
                """#)
    }

    /// Below text, an ordered list starts only from 1 (either `1.` or `1)`), as on GitHub; another
    /// number starts an item only where the text's list item or quote ends.
    @Test func aNumberStartsAnOrderedItemOnlyWhereGitHubSeesOne() {
        let notes = """
            Readings match what macOS has shown since
            2020. Older Macs too. Steps:
            1) Download.
            2) Open.

            1. Download **BatteryPulse.dmg**.
            2. Drag **BatteryPulse** onto
               **Applications**.
            3. Open it, as it has worked since
               2024. Still the third step.

            - A bullet since
            2021. A new list, as on GitHub.

            > A quote since
            2019. A list below it.
            """
        #expect(
            ReleaseNotes.inlineMarkdown(notes) == """
                Readings match what macOS has shown since 2020. Older Macs too. Steps:
                1) Download.
                2) Open.

                1. Download **BatteryPulse.dmg**.
                2. Drag **BatteryPulse** onto **Applications**.
                3. Open it, as it has worked since 2024. Still the third step.

                - A bullet since
                2021. A new list, as on GitHub.

                > A quote since
                2019. A list below it.
                """)
    }

    /// A table, with or without the outer pipes, keeps its header, delimiter row and rows.
    @Test func tablesKeepTheirRows() {
        let notes = """
            Keys explained in Raw Data
            Key | Meaning
            --- | :---
            `B0AT` | Battery temperature
            `SBA1` | Cell voltage
            Wrapped text after
            the table.

            | Key | Unit |
            |-----|------|
            | CellVoltage | mV |

            A sentence with a | pipe
            that wraps.
            """
        #expect(
            ReleaseNotes.inlineMarkdown(notes) == """
                Keys explained in Raw Data
                Key | Meaning
                --- | :---
                `B0AT` | Battery temperature
                `SBA1` | Cell voltage
                Wrapped text after the table.

                | Key | Unit |
                |-----|------|
                | CellVoltage | mV |

                A sentence with a | pipe that wraps.
                """)
    }

    /// Lines indented 4 columns past the text they belong to, after a blank line, are code;
    /// an indented line right below text continues it.
    @Test func indentedCodeKeepsItsLines() {
        let notes = """
            Write a capture:

                bpulse --raw > capture.plist
                bpulse --input capture.plist

            Then attach
            the file.

            An indented line
                right after text continues it.

            1. Run:

                   bpulse --smc
                   bpulse --devices

               Both read
               the SMC.

            - An item

                still its text,
                wrapped.
            """
        #expect(
            ReleaseNotes.inlineMarkdown(notes) == """
                Write a capture:

                    bpulse --raw > capture.plist
                    bpulse --input capture.plist

                Then attach the file.

                An indented line right after text continues it.

                1. Run:

                       bpulse --smc
                       bpulse --devices

                   Both read the SMC.

                - An item

                    still its text, wrapped.
                """)
    }

    /// A thematic break keeps its line, and a `=` or `-` line right below text makes that text a
    /// heading, in bold like `##`.
    @Test func breaksAndUnderlinedHeadingsKeepTheirLines() {
        let changelog = "**Full Changelog**: https://github.com/o/r/compare/v1...v2"
        #expect(
            ReleaseNotes.inlineMarkdown("Thanks to everyone who tested the beta.\n---\n" + changelog)
                == "**Thanks to everyone who tested the beta.**\n" + changelog)
        #expect(ReleaseNotes.inlineMarkdown("Highlights\n==========\nA paragraph.") == "**Highlights**\nA paragraph.")
        #expect(ReleaseNotes.inlineMarkdown("---\nText\nwrapped.") == "---\nText wrapped.")
        #expect(ReleaseNotes.inlineMarkdown("Intro\n\n* * *\nText after.") == "Intro\n\n* * *\nText after.")
        #expect(ReleaseNotes.inlineMarkdown("Notes\n---\n2. Two") == "**Notes**\n2. Two")
        let notes = """
            A heading that
            wraps
            ---
            - An item
              ---
            - Ends at a break
            ***
            Text above a break
            ___
            - - -
            ===
            Text and a line
                ---
            indented past a break.
            """
        #expect(
            ReleaseNotes.inlineMarkdown(notes) == """
                **A heading that wraps**
                - **An item**
                - Ends at a break
                ***
                Text above a break
                ___
                - - -
                ===
                Text and a line --- indented past a break.
                """)
    }

    /// Inside a code span a backslash or two spaces at the end of a line are no line break: the
    /// span keeps the backslash and the lines join with a space.
    @Test func aCodeSpanAcrossLinesHasNoLineBreak() {
        #expect(ReleaseNotes.inlineMarkdown("Run `a\\\nb` now.") == "Run `a\\ b` now.")
        let notes = #"""
            Run `bpulse --raw >\
            capture.plist` first.
            Then ``a ` tick\
            inside`` ends\
            here.
            An escaped \`tick\
            breaks.
            """#
        #expect(
            ReleaseNotes.inlineMarkdown(notes) == #"""
                Run `bpulse --raw >\ capture.plist` first. Then ``a ` tick\ inside`` ends
                here. An escaped \`tick
                breaks.
                """#)
        #expect(ReleaseNotes.inlineMarkdown("Two `spaces  \njoined` too.") == "Two `spaces   joined` too.")
    }

    /// A fenced code block in a list item ends with the item, even when its fence isn't closed.
    @Test func aFenceInAListItemEndsWithTheItem() {
        let notes = """
            - Item with a fence that is never closed:
              ```
              code
            - Next item text that
              wraps.

            Paragraph
            ```
            fenced
            ```
            More text
            that wraps.

            1. Run:
               ```
               bpulse --smc

               ```
               Both read
               the SMC.
            2. Next
            """
        #expect(
            ReleaseNotes.inlineMarkdown(notes) == """
                - Item with a fence that is never closed:
                  ```
                  code
                - Next item text that wraps.

                Paragraph
                ```
                fenced
                ```
                More text that wraps.

                1. Run:
                   ```
                   bpulse --smc

                   ```
                   Both read the SMC.
                2. Next
                """)
    }

    /// A heading's closing `#`s are dropped, but only as a run of their own.
    @Test func headingsLoseTheirClosingHashes() {
        let notes = ##"""
            ## Install ##
            ## C#
            ## C# #
            # Title #####
            ### Escaped \#
            ## Path C:\
            """##
        #expect(
            ReleaseNotes.inlineMarkdown(notes) == ##"""
                **Install**
                **C#**
                **C#**
                **Title**
                **Escaped \#**
                **Path C:\\**
                """##)
        #expect(ReleaseNotes.inlineMarkdown("## #\nText") == "\nText")
    }

    /// Trimmed from `.github/release-notes.md` for 0.4.0, which renders as it did before fences,
    /// tables, indented code and hard breaks were told apart.
    @Test func theReleaseNotesRenderAsBefore() {
        let notes = """
            ## What's new in 0.4

            - **Menu bar:** show any mix of the battery icon, charge, battery power and temperature. New
              icon styles are drawn to the exact level — Modern (like macOS 27, the default), Classic,
              Percentage Inside (like macOS 26) and Ring, or the SF Symbol as before.
            - **Install and Relaunch:** from 0.4.0 on, updates install from inside BatteryPulse: it
              downloads the next version, checks its signature, replaces itself and opens again, without
              Open Anyway. Each release now also has `BatteryPulse.dmg.sig`, which you can ignore.
            - **Update checks** daily, weekly, monthly or never (Settings → General).
            - **Raw Data:** temperature sensors no longer show values
              like 33.69999694824219.

            Upgrading from 0.3: install this version from the DMG as before (Open Anyway once); the next
            ones install from the app.

            ### First launch

            BatteryPulse is not notarized by Apple yet, so macOS blocks it the first time you open it:

            1. When macOS says it can't verify BatteryPulse, click **Done** (not *Move to Trash*).
            2. Open **System Settings → Privacy & Security** and scroll down to **Security**.
            3. Next to *"BatteryPulse" was blocked to protect your Mac*, click **Open Anyway** and confirm
               with your password or Touch ID.

            See the [User Guide](https://github.com/NikitaUsov/BatteryPulse/blob/main/docs/USER_GUIDE.md)
            for everything else.
            """
        #expect(
            ReleaseNotes.inlineMarkdown(notes) == """
                **What's new in 0.4**

                - **Menu bar:** show any mix of the battery icon, charge, battery power and temperature. \
                New icon styles are drawn to the exact level — Modern (like macOS 27, the default), \
                Classic, Percentage Inside (like macOS 26) and Ring, or the SF Symbol as before.
                - **Install and Relaunch:** from 0.4.0 on, updates install from inside BatteryPulse: it \
                downloads the next version, checks its signature, replaces itself and opens again, \
                without Open Anyway. Each release now also has `BatteryPulse.dmg.sig`, which you can \
                ignore.
                - **Update checks** daily, weekly, monthly or never (Settings → General).
                - **Raw Data:** temperature sensors no longer show values like 33.69999694824219.

                Upgrading from 0.3: install this version from the DMG as before (Open Anyway once); the \
                next ones install from the app.

                **First launch**

                BatteryPulse is not notarized by Apple yet, so macOS blocks it the first time you open it:

                1. When macOS says it can't verify BatteryPulse, click **Done** (not *Move to Trash*).
                2. Open **System Settings → Privacy & Security** and scroll down to **Security**.
                3. Next to *"BatteryPulse" was blocked to protect your Mac*, click **Open Anyway** and \
                confirm with your password or Touch ID.

                See the [User Guide](https://github.com/NikitaUsov/BatteryPulse/blob/main/docs/USER_GUIDE.md) \
                for everything else.
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
