# BatteryPulse 0.7.0: the plan (widgets you configure)

Written 2026-10-22, the day 0.6.1 was released, for the maintainer. 0.6.2 hasn't started yet. Every
0.6.2 result this plan depends on is named in §2, together with what 0.7 does if that result never
comes.

**Updated the same day with the maintainer's answers (2026-10-22).** No paid Apple Developer Program
account, not now and not planned before 1.0 (M-1), so the History and iPhone & iPad widgets can only
use the feed (Q-W3 is yes) and nothing in 0.7 waits for a signed build. Widgets in 0.7, no 0.6.3
(Q-W1). Xcode is already installed on the M5 (P2 Q-B7). Every other question this plan asks (M-2,
M-3, M-9, Q-W2, Q-W4 to Q-W13, Q7-1 to Q7-7) was delegated ("do it by best practices, as you see
fit") and is decided as its recommended answer; the looks they lead to are still signed off in the
look check (§6.1). The usage evidence behind M-1 (14 DMG downloads across all releases; the users
are, in practice, the maintainer alone) is in §14, and each release now records its download counts
a week after publishing (§13 step 8, NEW-23).

**Updated again the same day with the maintainer's further answers (2026-10-22):**
- **M-5, what 1.0 means: approved as written,** and with no dates: "this is a hobby project; we
  release when there is time and desire" (§2.4, §14). R-1 writes it into ROADMAP.
- **M-1's reason, restated:** he will not pay for an Apple developer account for this app. He is
  willing to spend on development help, not on the account (§14).
- **0.6.2's round A0 passed:** 0.6.0 → 0.6.1 through Install and Relaunch kept the desktop widget,
  which shows the current charge, and Open at login kept its state (D-9, C-1, Appendix C).
- **0.6.2's branches:** its integration branch is `claude/nice-faraday-k08mhb`, its packages are on
  `claude/062-<pkg>`, and its widget spikes on `claude/062-spike-widget` (D-1, D-11, W-0).
- **A new P1 package, W-13: an anonymous version count,** on by default and announced plainly
  (§14 Q7-9). It changes the privacy promise (§11), the settings keys and the update contract's
  release assets (§7.3).
- **A new 0.6.2 tool:** `scripts/release-stats.swift` prints each release's DMG, `.sig` and, from
  0.7.0, `BatteryPulse-count.txt` downloads. §13 step 8 records its numbers.

**Updated 2026-10-23 with 0.6.2's Session A** (the local Claude session on the MacBook Air M5, its
interim report, written while Session A was still running; its final `A.md` came on 2026-10-24,
below; 0.6.2's Appendix C at `0a4580e` records the report's first part, without the W2 retest's
result and the VoiceOver photos, and with W0-6's minutes as 0 where this plan had 6: two readings
of the same countdown at different moments, Appendix C row 5; this plan's findings are in
Appendix C):
- **Every widget spike ran,** so W-0S isn't needed (§2.3). §2.2 now holds each answer and what 0.7
  ships; the fallbacks the answers made unnecessary are gone (the new-kind branch, the presets, the
  registered URL scheme; the activity handler came back with the final report, below).
- **Placed widgets survive** today's kind becoming configurable, with Automatic as their default,
  once the old widget extension is ended before the swap: chronod caches the descriptors by
  `CFBundleVersion`, from whatever extension answers at the version change. 0.6.2's installer ends
  the extension before the swap (WP-16 item 6; D-17), and 0.7's first launch keeps
  `endPreviousExtension()` (W-3a item 10).
- **The edit sheet works at run time** (W0-1), but macOS 27 shows no `ParameterSummary` line, so
  nothing relies on it (W-2, W-3a). **The feed uses candidate A** (W0-3: A and A′ both read the
  app's 55 bytes), **the Accessories widget is in the MVP** (W0-4 (1)), **clicks arrive as a
  `widgetURL`** with the `batterypulse` scheme through `application(_:open:)`, unregistered (W0-4
  (4), (5); the final report adds a second route, below), and **time left ships** with `sign:
  .never` (W0-6). No rendering mode reached the log, so screenshots are the only evidence for it
  (W0-4 (2)).
- **VoiceOver** (W0-5, from the maintainer's photos) walks today's widget as 9 items and reads the
  level symbol's own name instead of the charge. W-3b item 5 turns that into requirements, checked
  by a Linux-tested label builder and a read of the accessibility tree, never by asking the
  maintainer to drive VoiceOver (Session R step 7).
- **A new P1 package, W-14:** the Charge Limit's "Charged to limit" state, in the app, the menu bar
  popover and the Battery widget, as the maintainer asked after Session A's Charge Limit capture
  (§14 Q7-10; G7-18). 0.7 shows only that the limit was reached; the configured percentage is in no
  IOKit or IOPS key, so showing it is 0.8's (W-14 lists the candidates).
- **Session R runs hands-free,** as 0.6.2's Session B does (the maintainer's request, 2026-10-23:
  "Make the tests run by themselves, without me; I can't do two things at once, click and work";
  P2 §10, "The hands-free sessions"). One local Claude Code session on the M5, the CLI with
  computer use, does every hands-on step with 0.6.2's helpers (W-12), and judges the pictures
  itself. His part of Session R, its day's end and the after-publishing check drops from about
  106 minutes to about 12-15 (§6.2-§6.4).

**Updated 2026-10-24 with Session A's final report** (`sessions/A.md`, merged into the integration
branch at `5849d01` with the redacted Charge Limit capture; copied to
`docs/plans/0.7.0/sessions/A.md` at 0.6.2's D3). §2.2 and
Appendix C now hold its final answers, and Appendix C notes each place where it differs from the
interim report:
- **Clicks take two routes** (W0-4 (4)): a `widgetURL` still arrives as a URL, but two clicks on
  the body of SPIKE-W's Test widget, which sets no `widgetURL`, arrived as an `NSUserActivity`
  whose type is the intent's type name (`SpikeWidgetIntent`), with `WGWidgetUserInfoKeyFamily`
  and `WGWidgetUserInfoKeyKind` in its user info and no `webpageURL`. W-3c handles both routes
  (G7-9), through W-1's `WidgetRoute`.
- **The edit sheet stayed English** with the extension's `AppleLanguages` set to Russian, while
  the widgets turned Russian (D-8). The system draws the sheet from the hand-extracted metadata,
  so W-2 item 5 checks that the metadata carries the sheet's strings as catalog keys the widget
  bundle translates, and names the fix; W-10 reviews them, and Session R step 4.3 tries the sheet
  again (G7-13).
- **Text size had no effect** on the widgets at 17 pt (W0-5). Decided: nothing in 0.7 depends on
  it, and Session R step 7 keeps one shot as a record.
- **The accessibility tree is readable and flat:** a System Events read found VoiceOver's 9 items
  as 9 sibling elements (an unlabelled image and 8 separate texts), so W-3b item 5's requirements
  stand and Session R step 7's read has a known route.
- **W0-1 (b) stays unanswered** (the Device chooser was never opened, and A.md doesn't say whether Details' was: its slots stayed "Choose"), so W-3a's review makes the Details
  choice before its merge (§2.2). W0-2's SPIKE-C and SPIKE-I passed, and W0-6 passed in Russian.
- **The Charge Limit** (W-14, G7-18): the redacted capture arrived, and the 80 → 100 → 80 reads
  are the 100 % diff: at 100 % bit 24 clears and charging resumes, and back at 80 % it returns.
  So W-14 has its fixture and its proof before C1; only the Russian screenshot didn't come
  (D-13). powerd's charging plist and `pmset -g battlimit` hold the limit's policy only on AC
  (cleared about 5 minutes after unplugging, back at plug-in), while System Settings'
  `prior.limit` stayed 80 on battery, so W-14's 0.8 candidates are reordered. Right after a
  plug-in `NotChargingReason` read 128 (bit 7), not bit 24, which appears at the hold (W-14 item
  6).

**Sources and how they are cited**

| Short | Source |
|---|---|
| R:n | `docs/ROADMAP.md`, line n |
| UG:n, RM:n | `docs/USER_GUIDE.md`, `README.md`, line n |
| file:line | a file in `Sources`, `Tests`, `scripts`, `Resources` or `.github` |
| CL | `CLAUDE.md` (it wins over every other source) |
| P2 | the verified 0.6.2 plan, its plan folder's `PLAN.md`, removed at 0.6.2's release: section, package (`WP-…`), spike (`W0-…`), widget package (`W-…`) or question (`Q-…`). Its §8, §9 with §9.1, §10's Q-W answers and Appendix C's W0 rows are in `docs/plans/0.7.0/widgets.md`, numbers kept; its whole Appendix C, where 0.6.2's D3 records Session B's results, is in `docs/plans/0.7.0/0.6.2-appendix-c.md`; the rest is readable in the history of the 0.6.2 release PR's head (`refs/pull/12/head`), in the commit before the one that removed the folder |
| RD | the roadmap to 1.0, `docs/plans/1.0/ROADMAP.md`: section, criterion (`C…`), decision (`M-…`) or new item (`NEW-…`) |
| INV | `docs/plans/1.0/INVENTORY.md`, by row ID (`FEA-06` …) |
| P1, PB | the 0.6.1 plan and playbook, `6aec4d2:docs/plans/0.6.1/` (in PR 11's history) |
| HIG | https://developer.apple.com/design/human-interface-guidelines/widgets |
| NOTES27 | the macOS 27 release notes, https://developer.apple.com/documentation/macos-release-notes/macos-27-release-notes |

- **Revision:** R, UG, RM, CL and file:line refer to `eebf748` on `claude/nice-faraday-k08mhb`, which
  is v0.6.1 (`7622373`) plus the 0.6.2 plan. 0.6.2 will move files (WP-15) and edit most app files
  (WP-10), so W-0 re-resolves every file:line at the v0.6.2 tag before code starts. **Re-resolved on
  2026-10-30 (W-0 item 3):** every file:line now refers to the v0.6.2 tag (`0ecca33`); R, UG, RM and
  CL still refer to `eebf748`, which the 0.6.2 release PR's head (`refs/pull/12/head`) keeps
  reachable. Where 0.6.2 changed the code a reference names, a bracketed note says so in place.
- **Apple URLs:** fetched on 2026-10-22 for P2's research; the saved copies are working notes, not in
  the repository.
- **GitHub numbers** (workflow run numbers, release download counts, repository traffic): GitHub's
  REST API (`gh api`), 2026-10-22.

**Marks:**
- **[unverified]:** nobody has checked it.
- **[uncertain]:** the evidence is partial.
- **[conflict]:** two Apple sources disagree (Appendix B).
- **[estimate]:** a planning number, not a measurement.

**IDs:**
- Widget packages keep P2 §8.14's IDs (W-1 to W-10) and their meaning. W-3 is split into W-3a, W-3b
  and W-3c.
- New packages: W-0 (intake), W-11 (the drawn-battery painter), W-12 (the session script and
  tooling), W-13 (the anonymous version count), W-14 (the Charge Limit's "Charged to limit" state),
  S-1 (`bpulse`'s JSON), R-1 (docs riders), K-1 (the backup key) and C-1 (0.6.2 carry-overs).
- 0.7's gates are `G7-…`.
- The facts W-13 rests on are `VC-1` to `VC-8` (Appendix B).
- New maintainer questions are `Q7-…`. P2's `Q-W…` and RD's `M-…` keep their IDs.

This file is English only and names no third-party product, so it can be committed under
`docs/plans/0.7.0/` as is (`LocalizationCatalogTests` scans `docs/`). CLAUDE.md wins over everything
in it.

Contents:
1. At a glance
2. Inputs and dependencies on 0.6.2
3. How every package runs
4. Work packages
5. Order and parallelism
6. The maintainer's sittings: the look check, Session R, the logged day, after publishing
7. Gates and their defaults; cut line; frozen surfaces
8. Localization
9. Size budget
10. Energy: the reload budget and the timeline policy
11. Privacy
12. Docs
13. Release steps
14. The maintainer's questions and their answers
- Appendix A: traceability of every 0.7 item
- Appendix B: facts verified for this plan, conflicts, and what stays unverified
- Appendix C: facts 0.7 records (filled during the release)

---

## 1. At a glance

- **What 0.7 is:** the first feature release since 0.6.0 (R:698), with one headline: **widgets you
  configure** (R:543-553; P2 §8, §9; RD §3.2). It is also where scripts change once: the device
  JSON's dates and a `formatVersion` field (R:554-556; RD §3.2, NEW-11). The rule behind that:
  "within a minor release … a change waits for a version that announces it" (R:437-439).
- **The headline (MVP, never cut):**
  - **The Battery widget becomes configurable**, on today's kind
    `io.github.nikitausov.BatteryPulse.battery` (`BatteryPresentation.swift:115-118`).
    - It comes in small, medium and large. Extra large is added only if the look check approves its
      layout with an explicit answer (Q-W10, decided by delegation: two panels, on that explicit
      yes, §14; without one it isn't declared in 0.7), because the HIG warns against "expanding a
      smaller widget's content to simply fill a larger area".
    - **Automatic** (the default) is today's widget in small and medium, field for field
      (`BatteryPulseWidget.swift:80-150`), so a widget placed by 0.6.x looks the same after the
      update. Four states differ on purpose: an end on a later day reads "tomorrow"; the attention
      row shows for an abnormal condition or high heat (in small it replaces the time line);
      "Updated %@" shows once the reading is over 45 minutes old; and "Charged to limit" replaces
      "Not charging" while the Charge Limit holds the charge (W-14; §7.3).
    - **Custom** lets the user choose:
      - the details for each size (up to 1 in small, 4 in medium, 8 in large, 12 in extra large);
      - the main value and the main visual;
      - clock time or time left;
      - level colours or monochrome;
      - when the update time shows.
    - In every size: an attention row, empty states, a click that opens the matching page,
      VoiceOver, and every rendering mode (P2 §8.5, §8.7, §8.9, §8.15, §8.17).
  - **A reload planner** that reloads only the kinds someone placed, at most as often as today's
    budget plus a little (P2 §8.10).
  - **The Accessories widget:** 0.6.2's W0-4 showed the sandboxed widget can read accessory
    batteries itself (Session A, 2026-10-23; P2 §8.4).
- **The Charge Limit's "at limit" state (W-14; the maintainer's request, 2026-10-23):** while
  macOS's Charge Limit holds the charge (`NotChargingReason` bit 24, on external power, not
  charging), the app (Overview, and Power's "Charge limit: Reached" row), the menu bar popover, the
  compact window and the Battery widget (its state line and a "Charge limit" detail) say "Charged to
  limit". No ring or battery marker and no menu bar icon change in 0.7. The configured percentage
  is in no IOKit or IOPS key, so it waits for 0.8 (W-14 lists the candidates). BatteryPulse only
  reads, and never sets a limit (M-3).
- **Conditional (stretch):** the data feed and the History and iPhone & iPad widgets (W-5 to W-7).
  - W0-3 passed with both candidates (Session A), and the feed uses A (§2.2). They run only if the
    MVP leaves budget. The other two conditions hold since 2026-10-22: Q-W3 is yes, and M-1 (the
    paid account) is no, so the feed is their only route (there is no App Group without the
    account).
  - If they miss 0.7.0, they go to 1.1 on the feed, not 0.7.x (RD §3.2, §4.1).
- **For scripts (S-1):** `bpulse --device <n> --json` writes ISO 8601 dates (CB-02). Every top-level
  JSON object `bpulse` prints gains `formatVersion`. One line in the notes covers both.
- **An anonymous version count (W-13; decided by the maintainer, §14 Q7-9):**
  - Once per installed version, at least 24 hours after that version first ran, an automatic update
    check that reached GitHub also downloads `BatteryPulse-count.txt` from that version's release.
  - Its public download count is the number of Macs that ran the version. No identifier is sent,
    and nothing about the Mac, its battery or its settings. Update traffic keeps no cookies.
  - It is on by default, never runs when Check for updates is Never, and a toggle in Settings →
    General turns it off. What's New, the notes, README and the User Guide say so (§11).
- **Riders:**
  - Docs: the iOS promises leave README, and the bug template asks for the app version and how
    BatteryPulse was installed (DOC-09, DOC-10).
  - ROADMAP gains a "Road to 1.0" section (M-5, approved by the maintainer on 2026-10-22: the five
    promises, and no dates).
  - The verification matrix starts (NEW-18), and so does the quick check after each macOS 27.x
    update (NEW-22).
  - The backup key's public half lands, once the maintainer has generated it (NEW-13; M-9, decided
    by delegation: yes).
  - A week after publishing, 0.7.0's DMG, `.sig` and `BatteryPulse-count.txt` download counts,
    printed by 0.6.2's `scripts/release-stats.swift`, go into ROADMAP's Releases table (NEW-23,
    §13 step 8). W-13's once-per-version download is the app's only part in them.
- **Maintainer time** (§6) [estimate]:
  - **The look check, about 15 minutes at the desk.** No M5 steps: numbered choices on PNGs that CI
    renders. A second look of about 4 minutes follows W-8 and W-14 (§6.1b).
  - **Session R, hands-free, about 6-8 minutes on the M5** at its start, with the release
    candidate, plus 1 minute once before to check the CLI (§6.2; the maintainer's request of
    2026-10-23). One local Claude Code session with computer use does every other step of what was
    about 83 minutes by hand. The accessibility step reads the widgets' tree instead of asking for
    VoiceOver (step 7).
  - **A logged day** of normal use with the candidate installed. It is passive, and its end takes
    about 3-4 minutes: one message, the batch and his yes (F12 runs then, by the session, §6.3).
  - **The after-publishing check,** a short session of its own, about 2 minutes of his time, plus
    a passive 10-minute wait for W-13's count, which the session waits out (§6.4).
  - **The backup key** (M-9): about 5 minutes in Terminal, any time before C1 (§14). It stays his
    alone.
  - **W-12's `charge-limit` step: not needed.** The final `A.md` brought the redacted Charge Limit
    fixture and the 100 % diff (D-13), so the short session it would have taken (about 2 minutes of
    his time) doesn't run for W-14 (G7-18; §6.2 step 11).
  - No spike sitting: 0.6.2's Session A ran the widget spikes (2026-10-23, §2.3).
  - If 0.6.2 left any of WP-18's Xcode items, Session R's GUI phase runs them, as 0.6.2's Session B
    does (C-1; Xcode is installed on the M5, Q-B7).
- **Budget** [estimate]: about 31-34 implementation and review runs, plus 3 for fixing forward. The
  never-cut set is about 28-30 runs (§7.2). The stretch adds 8-9.
- **Not in 0.7** (RD §4.1): Refresh buttons, extra-large portrait, the dashboard, per-row links,
  choosing specific accessories, and "why it isn't charging" as a widget field (W-9; FEA-15 to
  FEA-20), except the Charge Limit's "at limit" state, which W-14 shows. 0.8's NEW-01 keeps the
  other causes; the configured percentage is FEA-35's 0.8 half (RD §3.3).

---

## 2. Inputs and dependencies on 0.6.2

### 2.1 What 0.7 takes from 0.6.2, and what it does if that is missing

| # | 0.6.2 item (P2) | What 0.7 needs from it | If it failed, was cut or never ran |
|---|---|---|---|
| D-1 | WP-W0's answers. D3 moves them, with §8, §9.1 and the Q-W block, to `docs/plans/0.7.0/widgets.md` (P2 D3) | The row of P2 §8.16 that applies to each spike (§2.2) | **Copied at 0.6.2's D3:** main receives only squash merges, so only what the release PR's last commit holds reaches main (through 0.6.1 no plan folder did: `git log 7622373 -- docs/plans` is empty), and P1 §8 deletes `claude/*` branches after a release. So, as this plan asked, 0.6.2's D3 copied into `docs/plans/0.7.0/`, ahead of deleting 0.6.2's branches (the integration branch `claude/nice-faraday-k08mhb`, `claude/062-<pkg>` and `claude/062-spike-widget`): `m5-session.sh`, its swap helper (`swap.swift`), the hands-free helpers (`ui.swift`, `frames.swift`, `SESSION-B.md`, `start-session-b.sh`), the whole of P2 Appendix C as `0.6.2-appendix-c.md` (not only the W0 rows, which `widgets.md` also holds) and Session A's report (`sessions/A.md` with its files in `sessions/A/`). They reach main with 0.6.2's squash merge, and the release PR's `refs/pull/12/head` keeps 0.6.2's whole plan reachable in its history (§14, Q7-8). **Spikes:** they ran in Session A (2026-10-23); its final answers (`docs/plans/0.7.0/sessions/A.md`, 2026-10-24) are in §2.2 and Appendix C |
| D-2 | K-03, the `BatterySource` target (WP-15 item 1, G-15) | CryptoKit and the device stack out of the widget (about 187 KB, P2 §2.3). `MacAccessoryProvider` sits in the lower target, so W-8 needs no second split (P2 WP-15) | **Nothing blocks.** `MacAccessoryProvider` is in BatteryKit today (`BatteryKit/MacAccessoryProvider.swift`), and the widget can log through its own `Signposts(subsystem:log:)`, which is public (`BatteryKit/Diagnostics.swift`, `public struct Signposts`). **Only size suffers:** G7-10 decides, and if the widget would cross 0.6.1's ceilings, K-03 runs as written in P2 WP-15 before W-3a ("W-0K") |
| D-3 | `-internalize-at-link` on the widget (WP-15 item 2) | About −27 % of the widget's `__text` (P2 WP-15, measured in a native build) | **Less headroom.** G7-10's cut order applies: `Path` instead of Swift Charts, SIZ-07, W-11 cut first |
| D-4 | WP-14a, the nonisolated read (E20) | The widget's async provider reads without the `Task { @MainActor in … }` hops of today (`BatteryPulseWidget.swift:50, 56`; P2 §8.10). WP-14a covers the battery read only: `MacAccessoryProvider` stays `@MainActor` (`BatterySource/MacAccessoryProvider.swift:17-19`), so W-8's read hops once (W-8 item 4) | **Reverted:** the provider keeps one hop around the synchronous `read()`. `WidgetReadCache` still makes it one read per burst. No blocker |
| D-5 | WP-14b, the registry only when it changes (E4b) | Nothing. The widget makes a new provider for each read (`BatteryPulseWidget.swift:68-70`), so it never takes a cached-registry path | **Either way:** W-3a pins with a source test that the widget never passes a cached-registry scope |
| D-6 | WP-10, main actor by default for the app | 0.7's edits to `WidgetRefresher` and `AppDelegate` are written in the default-isolation style. The widget stays nonisolated (REJ-30; P2 WP-10) | **Reverted:** 0.7's app edits keep explicit `@MainActor`, as v0.6.1 does |
| D-7 | SIZ-04: widget ceilings lowered to the RC plus about 5 % (WP-15 item 4) | 0.7's growth shows in CI, and every raise is a commit of its own (`size-budget.json` "about") | **Not lowered:** 0.6.1's ceilings stand (`scripts/size-budget.json`), with the same rule |
| D-8 | L10N-03: a way to show the widget in Russian (Session A step 3.3) | Session R checks the Russian edit sheet and widgets (§6). **Answered by the final `A.md`** (W0-2-W-ru: 2, only the widgets; Appendix C row 10): with `AppleLanguages` (ru) in the extension's container preferences and the extension ended, the widgets turned Russian once they redrew (a widget not yet redrawn kept its English, its live minutes too), while the edit sheet stayed English. So the method shows the widgets in Russian, not the sheet: W-2 item 5 checks the sheet's strings, and Session R step 4.3 tries the sheet again (G7-13) | **No method found:** the Russian half is recorded "not checked", never "n". `WidgetTextBudget` (W-1) checks lengths on Linux |
| D-9 | DIS-06: did the 0.6.1 → 0.6.2 in-app update keep placed widgets? (D3's after-publishing check: the section After publishing of `docs/plans/0.7.0/SESSION-B.md`, started from `main` by `start-after-publishing.sh`, Q7-8) | The baseline for "placed widgets survive" (G7-2). 0.6.2's A0 already saw one in-app update keep them: 0.6.0 → 0.6.1 through Install and Relaunch kept the desktop widget, which shows the current charge (2026-10-22, Appendix C). Session A suggests why a static-to-static update keeps them: a descriptor fetched from the old extension is the same static one [inference]; the change to a configurable kind is what needs the old extension ended before the swap (D-17) | **Lost in 0.6.2 too:** the loss comes from the update, not from configuration. The notes then say "add it again if it's gone" |
| D-10 | WP-21's energy numbers (S1, S2, S6, S7) | The baseline for 0.7's widget runs (§10) | **Missing:** 0.7 measures the widget's reads and reloads alone, and the comparison waits for the final 0.9.x energy run (RD C5) |
| D-11 | The 0.6.2 session script: prepare, backup, restore, the swap helper, `send` (P2 §6, WP-21), and its hands-free mode (`ui.swift`, `frames.swift`, `preflight`, `arm`, the split `restore`, the detectors, `SESSION-B.md`; 2026-10-23) | W-12 builds 0.7's script from it, with Session A's fixes: the log count without ndjson's summary line (`9a32e57`) and the widget extension ended before each swap (`56702f9`); W-12 item 1 lists the issues Session A left open. Session R runs hands-free on the same helpers (§6.2) | **Removed with the plan folder in D3, after the copy D-1 names:** `docs/plans/0.7.0/m5-session.sh`, `swap.swift`, `ui.swift`, `frames.swift`, `SESSION-B.md` and `start-session-b.sh` are W-12's starting point, and CI keeps checking them (the queue's dry run, `bash -n`, the helpers' type-checks). If neither that copy nor the 0.6.2 release PR's history (Q7-8) held them, W-12 would rebuild the script from 0.6.1's (`6aec4d2:docs/plans/0.6.1/m5-session.sh`) and P2 §6's text (+1 run), and the hands-free helpers from P2 WP-21's text (+1 run); without them, Session R's steps need his hands again (about 83 minutes, as before the hands-free mode) |
| D-12 | WP-16, the `diskutil` installer (G-16) | F12 (at the logged day's end, §6.3) tests whichever installer the RC carries | **Reverted to `hdiutil`:** F12 runs as in 0.6.1 |
| D-13 | QUA-05, the Charge Limit capture (optional in 0.6.2) | **Done in Session A** (2026-10-23, Appendix C finding 7): with the limit at 80 %, `NotChargingReason` gained bit 24 (0x01000000), and the configured 80 is in no key. **The final `A.md` brought** the redacted `bpulse --raw` capture of the hold (`docs/plans/0.7.0/sessions/A/charge-limit-80.plist`, on the maintainer's approval; W-14's fixture) and the 80 → 100 → 80 reads, a minute after each change: the 100 % diff (bit 24 clears at 100 % and returns at 80 %; Appendix C finding 9; W-14). They are reads rather than the timeline rows this plan asked for, and they settle the same questions. **Not brought:** a screenshot of System Settings → Battery's Charge Limit in Russian, for W-10's terminology pass. The other captures stay on the Mac | **Both came,** so W-12's `charge-limit` step doesn't run for W-14 (§6.2 step 11), and W-14 moves to 0.8 only if its review rejects the capture (G7-18). **No Russian screenshot:** W-10 follows Apple's Russian article, and Session R step 9b confirms |
| D-14 | 0.6.2's cut list (P2 §7.2: "a cut item moves to 0.7") | — | **Without M5 time:** C-1, the Linux-only lane. **With M5 time:** Session R's optional steps, or the verification matrix (RD §3.2) |
| D-15 | P2 §7.3's frozen list ("Widget. Same kind, look and reload policy.") | 0.7 changes the kind's configuration, its families and the reload policy on purpose (§7.3) | — |
| D-16 | NEW-23: 0.6.2's D3 adds download columns to ROADMAP's Releases table and, a week after publishing, records v0.6.2's DMG and `.sig` counts, printed by 0.6.2's new `scripts/release-stats.swift` (P2 D3; RD §1.2 item 6) | The columns 0.7.0's counts go into (§13 step 8), and the script that prints them. It already looks for `BatteryPulse-count.txt` and prints "—" before v0.7.0 | **Columns missing:** §13 step 8 adds them and fills the earlier releases from the same releases API call (RD §3.1 item 7). **Script missing:** step 8's `gh api` call, once per release |
| D-17 | Session A's W0-2 fix, 0.6.2's WP-16 item 6 (P1, never cut): `UpdateInstaller` calls `WidgetRefresher.endExtensionBeforeSwap()` right before `renamex_np` (the session script already ends the extension before each swap, `56702f9`) | A clean 0.6.2 → 0.7.0 Install and Relaunch for placed widgets (G7-2, §6.4). At the version change chronod fetches the widget's descriptors within about 2 ms, from whatever extension is running, and caches them by `CFBundleVersion`; 0.7's first launch comes too late for that (Session A). The installer must end the extension without `endPreviousExtension()`'s follow-up reload a second later (`WidgetRefresher.swift:55-60`), which would start the old extension again before the swap. 0.7's first launch keeps `endPreviousExtension()` (`BatteryPulseApp.swift:58`) for any other path (W-3a item 10) | **Not in 0.6.2:** only the installed version's installer can end the extension before the swap, so 0.7.0 waits for a 0.6.3 that carries only this fix (P1 §7's fix-release steps, about 1 run plus its after-publishing check; Q-W1's "no 0.6.3" was about static widget sizes). 0.7's own installer has the fix either way |
| D-18 | Session A's F5 bug: after the cable is detached, a "didn't answer" banner sits over stale "Connected by cable" values, and a fresh read of the iPad over Wi-Fi is still labelled "Connected by cable" (the label doesn't follow the transport) | Nothing: 0.6.2 fixes it (WP-23, P2) | **Not fixed in 0.6.2:** C-1 carries it. The label follows the transport of the reading shown, with a Linux test where the decision lives in BatteryCore; Session R's optional steps show it on the M5 |

### 2.2 The spike answers and what 0.7 ships for each

0.6.2's Session A ran every spike on 2026-10-23, and its final report
(`docs/plans/0.7.0/sessions/A.md`, 2026-10-24) gives the answers below; Appendix C notes where it
differs from the interim report this table first held. P2 §8.16 held a fallback for each failed
spike; the answers made those fallbacks unnecessary, so this table keeps only what 0.7 ships and
what is still open. The final report reversed one finding, that no `NSUserActivity` arrives (W0-4
(4)), which brings back P2 §8.9's handler for a click without a URL (W-3c item 2), and it added the
edit sheet's English under the extension's Russian (D-8), the accessibility tree and Text size
(W0-5) and the Russian time left (W0-6). W-0 checked each row against the copy of 0.6.2's Appendix
C (`docs/plans/0.7.0/0.6.2-appendix-c.md`, 2026-10-30): every answer below is its final W0 row.
Session B (2026-10-30) ran no spike; its P1 adds where the desktop widget's tree hangs (W0-5).

| Spike (P2 WP-W0) | Session A's answer (final, 2026-10-24) | 0.7 ships | Still open |
|---|---|---|---|
| **W0-1:** App Intents metadata through a manual `appintentsmetadataprocessor` step | **Passed** (CI 2026-10-22; run time in Session A). The edit sheets show the parameters: Battery's (headed "Battery", "BatteryPulse" and the gallery description) has Layout, Main value and Time at 0.6.1's defaults (Automatic, Charge, Clock time), and Custom adds Details, with 4 slots on medium; the test kind's has Main value, Details (4 on medium, more on extra large) and Device (SPIKE-W, #282). Neither sheet shows the `ParameterSummary` line ("Show Charge" appears nowhere) | W-2, then the configurable kind (G7-1). `ParameterSummary` stays for its `When` clauses (Details appears only with Custom), but nothing relies on its sentence: the look check and Session R don't ask about it, and its `Summary` keys are kept plain (§8) | — |
| **W0-1 (a):** the per-family `size:` overload compiles against macOS 27.0 | **Only for entities** (CI, 2026-10-22): no `[AppEnum]` per-family `size:` overload compiles with Xcode 27.1, while an array of an `AppEntity` does; an integer literal per family is recorded as an exact size (min = max). The spike's Details is such an entity array, and its sheet shows 4 slots on medium | Details is an array of an `AppEntity` whose `id` is `BatteryWidgetField`'s frozen raw value and whose `EntityQuery` lists the fields (W-3a item 2), sized `IntentCollectionSize(min: 0, max: N)` with N = 1, 4, 8 and 12 (W-3a item 1) | Whether `init(min:max:)` compiles per family for an entity array: W-3a's first CI build. If it doesn't, the literals stay and W-3a's review decides how an empty Custom list behaves |
| **W0-1 (b):** entity queries run in the ad-hoc extension | **Not answered, final:** no `spike query` line in any segment, because the Device chooser was never opened, and A.md doesn't say whether Details' was (its slots stayed "Choose"; if it was opened, the missing query line counts against the inference below). The Refresh button's perform did run in the extension (W0-1 (c)), so the ad-hoc extension serves App Intents requests, which suggests queries run too [inference] | **Matters for the MVP,** not only W-7: Details' chooser lists the fields through its `EntityQuery` (W0-1 (a)). W-7 uses an `AppEnum` (most recent, lowest), since queries aren't shown to run | W-3a's review chooses before its merge, with nothing more to wait for: G7-1's default, per-slot optional `AppEnum` parameters, or the entity on the inference above, with Session R step 4.1's chooser as its check (a chooser that lists nothing is then a fix before release, by a re-freeze: new RC-U and RC-F, then Session R steps 2-4 again) |
| **W0-1 (c):** button performs run | **Ran, in the widget extension** (`process=widgetExtension`), not in the app | Nothing in 0.7: the buttons are W-9, after 1.0, which now knows where its performs run | — |
| **W0-1 (d):** the extracted `Summary` keys | Not in the final `A.md` either: no step dumped them | The placeholder rule as it stands, or one reasoned exception limited to the widget's intent files (P2 §8.11) | W-2's CI dumps the keys, and the exception is decided then |
| **W0-2:** placed widgets survive SPIKE-C, then SPIKE-W | **Passed, once the old extension is ended before the swap.** SPIKE-C over 0.6.1 and SPIKE-I over SPIKE-C kept the placed small and medium widgets as they were (answers 1; `pluginkit` lists the widget, 0.0.0, from `/Applications`); large and extra large weren't asked, since only small and medium are declared. The first SPIKE-W install (#282, over SPIKE-I) failed: at the version change chronod fetched the descriptors in 2 ms, before SPIKE-W's extension started, from SPIKE-I's still running, and cached version 282 with its one static descriptor. The placed widgets lost Edit Widget, the gallery offered no Test widget, and every reload failed (CHSErrorDomain 1103, "Intent configuration is required but was not provided"); they turned grey only when a chronod restart dropped the cached snapshots. Installed again with the old extension ended (by hand, then W2, run #307, by the script, the extension ended about 20 ms before the swap), chronod fetched both descriptors from the new extension, and the widgets placed under 0.6.1 (small, medium) and under SPIKE-I (medium) redrew in today's look with fresh values, Automatic by default (answers 1). So a widget placed by 0.6.1 survives its kind becoming an `AppIntentConfiguration` when the descriptor fetch reaches the new extension. The reverse race repaired itself (chronod refetches descriptors with unresolved default intents), but a static descriptor cached for a configurable version never qualifies, so it stays until the next version change. Reinstalling 0.6.1 over W2 kept every Battery widget (answer 1); the Test widgets, a kind 0.6.1 lacks, kept W2's last picture | Configuration on today's kind, with Automatic as a placed widget's default (G7-2). 0.6.2's installer ends the extension before the swap (WP-16 item 6; D-17), so 0.6.2 → 0.7 is clean; 0.7's first launch keeps `endPreviousExtension()`; D1's growing build number stays, because chronod caches descriptors by `CFBundleVersion` (W-3a item 10). No new kind and no fallback branch | Session R step 2 and §6.4 confirm; a copy from the DMG over a running extension stays a risk, and doesn't repair itself (§6.5) |
| **W0-3:** a file or preference domain the widget can read (A, A′; B as a last resort) | **Passed with both:** A (the home-relative-path read-only exception) and A′ (the shared-preference read-only exception) each read the app's 55 bytes, under ad-hoc signing on macOS 27. B wasn't tested: SPIKE-W probes only A and A′ | The stretch may run (G7-5), **on candidate A**: `/Library/Application Support/io.github.nikitausov.BatteryPulse/Widget/` (home-relative). Why A, not A′: P2 §8.3's feed is designed as a file, written atomically, 0700 and 0600 like `Devices/`, at most 8-12 KB, rewritten at once on Clear History or Forget, and counted in D1's storage round trip; the exception names one folder, so the widget can read nothing else of ours. A′ would keep that history in a preference domain, cached by cfprefsd in its own files, outside the folders Clear History and Forget manage. A′ stays the fallback behind W-5's one reader type, if a macOS 27.x update denies A (NOTES27 178668601) | A read of data the app wrote while the widget wasn't running: the final `A.md` can't show it, since its lines print the feed's age as `age=Ns`, so it stays with W-5 (its tests, then Session R if W-5 ships). If the budget runs out: 1.1 on A |
| **W0-4 (1):** accessory batteries from the sandbox | **Passed:** the sandboxed widget read them itself ("spike accessories sources=2 accessories=1") | W-8 in the MVP (G7-8) | — |
| **W0-4 (2):** the rendering mode per Icon & widget style, Dim widgets and place | **No data from logs:** no "spike render" line reached the log from any process. Screenshots of the four Icon & widget styles on the desktop (focused and not) and in Notification Center show the widgets redraw per style | Design for all three modes everywhere (W-3b item 6). Screenshots are the only evidence: Session A's, then Session R step 5's (G7-4). Nothing in 0.7 logs the mode | Why the render line never reached the log [uncertain] |
| **W0-4 (3):** `redactionReasons` and `showsWidgetContainerBackground` | **No data:** the same render line carried them | `.privacySensitive()` on names stays a cheap defence (P2 §8.8) | — |
| **W0-4 (4), (5):** what a click delivers; whether `widgetURL` needs a registered scheme | **Two routes, and no scheme needed** (SPIKE-W registers none). A click on a widget with a `widgetURL` (the medium Battery widget) arrives as the URL through the app delegate's `application(_:open:)`: "spike click url scheme=batterypulse page=overview windows=1 active=true", once with no window open and once with the main window open. Two clicks on the body of the Test widget, which sets none, arrived as an `NSUserActivity` through `application(_:continue:restorationHandler:)`: its type is the intent's type name (`SpikeWidgetIntent`), its user info holds `WGWidgetUserInfoKeyFamily` and `WGWidgetUserInfoKeyKind`, and it has no `webpageURL` ("spike click activity type=other … webpageURL=false windows=0 active=true"). The interim report saw no activity | W-3c handles both routes and registers no scheme (G7-9): the URL through `WidgetRoute(url:)`, the activity through `WidgetRoute(activityType:)`, which maps our intent type names to their kind's page (W-1 item 8). W-1's route takes the `batterypulse` scheme seen arriving, and every widget still sets exactly one `widgetURL` (W-3a item 6), so the activity is the fallback for a click without one | A click with BatteryPulse quit: Session R step 8, which also records each click's route. The user info's values (only its keys were logged) [unverified]: the route relies on the activity's type alone |
| **W0-5:** VoiceOver on today's widget; Text size | **VoiceOver, from the maintainer's phone photos** (the test widget on the desktop, in English): focusing the widget reads "In BatteryPulse, widget, 9 items", then "Three-Quarter-Charged Battery, image"; one step inside, "In Three-Quarter-Charged Battery, image, content is empty". So VoiceOver walks the widget as 9 separate items, reads the SF Symbol by its own name (the 75 % bucket, at 80 %) instead of the charge, and announces an empty group. **The tree,** read through System Events (Finder's desktop group holds one group per desktop widget, described "widget"): the medium widget is 9 flat elements, an image with no label or value and 8 separate texts ("83%", "Not charging", then each label and value apart); the small one the image and 2 texts; the Test widget 8 texts and a button, each time-left letter apart from its value. No element pairs a label with its value. **Text size: no effect** at 17 pt, the widgets pixel-identical (answer 2). Russian VoiceOver and the rotor weren't done: driving VoiceOver was too hard for the maintainer | W-3b item 5's requirements: decorative symbols hidden, the charge as its own element whose label carries the value, each row one element, no empty group, a button (W-9's, after 1.0) its own element. A Linux-tested label builder (`WidgetAccessibility`) makes every label, and Session R step 7 reads the tree through the session's `ui` helper or Accessibility Inspector, never by asking the maintainer to drive VoiceOver (G7-12). **Text size, decided:** it doesn't reach desktop widgets, so no layout depends on it; W-3b keeps text styles, and step 7 keeps one shot as a record | Where the tree hangs: Session A's System Events read found the desktop widgets in Finder's desktop group, while Session B's P1 found the widget's host to be NotificationCenter (`com.apple.notificationcenterui`), with a BatteryPulse label in its chain (0.6.2 Appendix C, Session B's preflight row). Step 7 reads the tree in English and Russian |
| **W0-6:** the offset format counts down without a reload | **Passed with `sign: .never`, in English and Russian.** Variant a (the default sign) printed "-2 hours, 0 minutes" (an offset to a later date is signed) and variant b (`sign: .never`) "2 hours, 0 minutes"; 65 s later both had gone down by one ("-1 hour, 59 minutes" and "1 hour, 59 minutes") on the same entry, without a reload. No seconds; a zero minutes field shows, and under an hour the hours field drops ("10 minutes"). Earlier frames read "2 hours, 10 minutes" and "2 hours, 6 minutes". In Russian, once redrawn, b read the Russian for "2 hours 12 minutes" without the comma, and a the same with a minus sign; a widget not yet redrawn kept its English text and English minutes | Time offers clock time or time left (G7-3), written `Text(.currentDate, format: .offset(to: end, allowedFields: [.hour, .minute], sign: .never))` in one helper (W-1 item 4) | — |

### 2.3 If 0.6.2's widget spikes never ran (W-0S): not needed

Session A ran every widget spike on 2026-10-23 (§2.2), so W-0S has no cause, and no spike sitting
comes before 0.7's code. W-1 and S-1 can start at once; W-2 and the widget packages start from §2.2's
answers. The final `A.md` (2026-10-24) kept W0-2's answer and reversed only W0-4 (4)'s "no
`NSUserActivity`" (W-3c item 2 handles both routes); it left W0-1 (b) unanswered, so W-3a's review
makes the Details choice before its merge (§2.2).

### 2.4 Decisions needed before code, as answered on 2026-10-22 (Q7-10 on 2026-10-23)

| Decision | Needed by | Answer (2026-10-22) | Source |
|---|---|---|---|
| M-1: buy the paid account? | before W-0 ends | **No** (the maintainer): not now, and not planned before 1.0. The stretch rests on W0-3 alone (G7-5), and nothing in 0.7 waits for a signed build (§14) | RD §6 M-1 |
| M-2: an iOS app? | R-1 | **Not in 1.x** (by delegation). R-1 removes the iOS promises (RM:5, RM:14-15, RM:192-206; both issue templates) and updates ROADMAP's Decisions | RD M-2; R:704-706 |
| M-3: charge limiting? | R-1 (one ROADMAP Decisions line) | **Not in 1.x** (by delegation; clarified 2026-10-23, §14) | RD M-3 |
| M-5: what 1.0 means | R-1 | **Approved as written** (the maintainer, 2026-10-22). Five promises: seen working on the M5 in a packaged build; a week of daily use without a crash; in-app updates from older versions; nothing breaks through 1.x; usable by a non-expert. **No dates:** "this is a hobby project; we release when there is time and desire". No target date, calendar or outer bound; the order of versions and the effort estimates stay, and 1.1 (macOS 28 compatibility) comes after macOS 28 ships, an event, not a date. R-1 condenses it into ROADMAP | RD M-5 |
| M-9: the backup key | K-1 | **Yes** (by delegation). K-1 runs once the maintainer has generated the key; if it doesn't exist by C1, K-1 moves to 0.8 | RD M-9 |
| Q-W1 | W-0 | **Yes** (the maintainer): widgets in 0.7, no 0.6.3 | P2 §10; RD §5.3 |
| Q-W2 to Q-W13; Q7-1 to Q7-7 | W-3a (look and behaviour); the look check (the rest) | **As §14 recommends** (by delegation; Q-W3 yes, following the maintainer's M-1 answer). The look check signs off the looks they lead to (§6.1). Q7-8 was settled earlier | P2 §10; RD §5.3 |
| Q7-9: an anonymous version count | W-13 | **Yes, on by default, announced plainly** (the maintainer). W-13 is the verified design | §14 Q7-9; Appendix B VC-1 to VC-8 |
| Q7-10: show the Charge Limit (asked 2026-10-23) | W-14 | **Yes, in 0.7** (the maintainer asked for it in the app, the menu bar and the widget). W-14 ships the "at limit" state; the configured percentage and NEW-01's other causes stay in 0.8 | §14 Q7-10; W-14 |

### 2.5 What this plan adds to P2's design

Each addition is technical, so the runs decide it (P1 §8, "Architecture: delegated"):
- **W-3 split into three:** W-3a (configuration, provider, small and medium), W-3b (large, extra
  large, visuals, accessibility, rendering modes) and W-3c (the app side of clicks). Each part stays
  reviewable and revertable, and W-3c can run beside the widget work.
- **The reload planner moves from W-1 to W-4.** W-4 then owns the BatteryCore type and its app hook,
  and runs beside W-3b.
- **`WidgetIntentManifest` in BatteryCore:** one list of the frozen intent, parameter and case
  names. Two checks read it: a Linux test against the widget sources, and W-2's CI check against
  `Metadata.appintents`.
- **The read cache's logic in BatteryCore** (`ReadCoalescer`), tested on Linux with a manual clock.
  The widget keeps only the thin `Mutex`-guarded wrapper.
- **Extra large only with a layout of its own.** The HIG says "avoid expanding a smaller widget's
  content to simply fill a larger area", and a family can be added later without breaking placed
  widgets (P2 §8.13). So extra large ships only if the look check approves it with an explicit
  answer (Q-W10, decided by delegation: two panels, on that explicit yes).
- **This departs from P2 §9.1 and §8.17:** extra large leaves the never-cut set ("Battery in S, M,
  L and XL"), and its recommended Automatic layout is two panels (Battery, Power) instead of P2
  §8.17's bigger Battery with 10 details. Both are the maintainer's look call (§6.1 question 3), and
  RD C1 says the same.
- **Corrections to P2's text, found in review** (each is technical; the packages below carry them):
  - time left uses `sign: .never` (§2.2 W0-6; P2 §8.5's expression signs a future end);
  - Details is an array of an `AppEntity` over the fields, not of `BatteryWidgetField` itself: no
    `[AppEnum]` per-family `size:` overload compiles with Xcode 27.1 (§2.2 W0-1 (a); P2 §8.5);
  - intent and `AppEnum` metadata are `static let`, not P2's sample `static var` (W-3a item 1);
  - `PageID` also holds `developer` and `demo`, which `SidebarItem.storageKey` returns
    (`MainView.swift:64-75`), and `WidgetRoute` rejects them (W-1 item 8; P2 §8.6 lists only the
    pages a widget opens);
  - `WidgetTextBudget`'s budgets come from today's widget with its scale factors, because P2 §8.6's
    example budgets are below reused Russian keys (W-1 item 5);
  - the attention row also changes Automatic small and medium, in the states where it shows
    (§7.3; P2 §8.5 places it "in every family and layout").
- **W-14 takes RD's Charge Limit cause early** (NEW-01 in 0.8, and FEA-20's Charge Limit part in
  1.1), as the maintainer asked once Session A had captured it: the "at limit" state only, with the
  configured percentage left to 0.8. W-14 says why 0.7 and not 0.8, and NEW-01 builds on its
  BatteryCore type.
- **`WidgetChartSummary` moves to W-6.** It has no user in the MVP, and the dead-code rule applies
  (PB §1.6). If W-6 doesn't ship, 0.8's A11Y-01 builds it (RD §3.3).
- **Reuse of the app's labels** in the widget's details. The app's Power page says "System load" and
  "Power from adapter" (`Main/PowerView.swift`), so the widget doesn't add new names for the same
  values.
- **A build-number fix** (§6.5, Appendix B): CI builds carry CI run numbers (258 on 2026-10-22),
  and releases carry the release workflow's own (7 for 0.6.1; ci.yml:201, 407; release.yml:109). Once the
  M5 has run RC-U, the published 0.7.0 would almost certainly have a lower `CFBundleVersion`, and
  WidgetKit caches by `CFBundleVersion` (`build-app.sh:136-137`). So D1 makes both workflows take
  the build number from one clock that only grows (§6.5). [uncertain whether a lower number leaves
  the widget stale; the fix removes the question]

---

## 3. How every package runs (0.6.1's and 0.6.2's practices, kept)

P1 §3.0 and P2 §3 apply in full. In short:

- **Branches:**
  - The integration branch is `claude/070-integration`, from the v0.6.2 tag on `main` (a `claude/`
    name, so CI runs; ci.yml:3-5).
  - Each package gets a worktree and a branch `claude/070-<pkg>`. Spikes and look-check builds go on
    `claude/070-spike-*` and are never merged.
  - At most two agents, never two on one file. Builds use `-j 2`, with no shared `.build`.
- **An implementation run, then a separate review run.** One commit per item where practical.
  - Before each commit: `swift format format -i -r Sources Tests Package.swift scripts`, `swift
    build`, `swift test`, and `swift format lint --strict -r Sources Tests Package.swift scripts`.
  - Every Darwin change needs a green macOS job. Merges are `--no-ff` after both jobs are green.
  - A red integration run is fixed forward at once.
- **Measure first.**
  - **The "before"** is v0.6.2 for size (the CI size report), for reloads (E15's synthetic day,
    `WidgetReloadPolicyTests.swift:82-171`) and for reads (`perf` lines).
  - The widget's numbers are recorded in each commit message: its `__text`, binary,
    `widget_appintents_bytes` and `strings_bytes`.
- **Rules have guard tests.** Each new rule in §4 lands with its `MotionGuardTests`,
  `EnergyGuardTests`, `SecurityGuardTests` or `LocalizationCatalogTests` case, scanning Darwin code
  on Linux.
  - An exception goes on the suite's list with its reason.
  - A new target joins `SourceScanner`'s lists in the same commit (`SourceScanner.swift:33-36`), and
    so does WP-15's test that the folders under `Sources/` equal the scanned targets.
- **Pure decisions in BatteryCore,** tested on Linux. BatteryCore can't import WidgetKit or App
  Intents, so it holds mirrors, and the widget maps them one to one (P2 §8.6).
- **Gates with defaults.**
  - Every M5-dependent decision has a default (§7.1).
  - **One rule is stricter than in 0.6.2:** the headline can't ship unseen. If Session R can't run,
    0.7 waits, because a release whose new widget nobody has rendered on the Mac breaks RD C2 ("seen
    working"). Dates are not gates, and there are no target dates (M-5: "we release when there is
    time and desire").
- **Strings:** only one running package touches `Resources/Localizable.xcstrings` at a time. Every
  package that adds a widget literal adds its key with its Russian in the same commit, because
  `LocalizationCatalogTests` fails otherwise. That holds for the App Intents forms only once the
  test knows them: today its `localizingCall` regex misses `IntentDescription("…")`, `static let
  title: LocalizedStringResource = "…"`, `Summary("…")`, `TypeDisplayRepresentation(name:)` and
  `caseDisplayRepresentations` literals (`LocalizationCatalogTests.swift:19-21`), so a key used only
  there would fail `catalogHasNoLeftovers` (:126-130). W-1 item 11 teaches it those forms before any
  intent code. §5 orders the catalog: W-3a, then W-3b, then W-8, then W-14, then W-13, then W-10.
- **Frozen values are decided before D1.** An `AppEnum` case, a parameter name, a kind string or a
  family can't be removed once a release ships it (P2 §8.13). So an option is cut before the RC,
  never after.
- **Session wording** (P2 §3): every yes or no question means "y = looks right". Comparisons are
  numbered choices. Screenshots and recordings are the evidence. The script reads the logs.
- **The maintainer decides only what he sees or does** (P1 §8): look, behaviour, settings, the
  sittings and the release. On 2026-10-22 he also delegated every open question of this plan ("do
  it by best practices, as you see fit"), except M-5, which he approved, and the version count
  (Q7-9), which he decided; the looks themselves are still his to sign off in the sittings (RD §1.2
  item 8).
- **Facts go to Appendix C** of the committed copy of this plan. At D3, the lasting parts move to
  ROADMAP and the plan folder is removed (P2 D3).

---

## 4. Work packages

**Priorities:**
- **P1:** must ship.
- **P2:** ships if the budget allows.
- **P3:** opportunistic.
- **Conditional:** depends on a gate.

**What each package lists:** source; items; files; BatteryCore decisions with their Linux tests;
guards; acceptance; effort; risk; rollback.

### W-0: Intake (P1, the orchestrator, no code)

- **Source:** P2 D3; P2 Appendix C; RD §3.2 "Before code"; §2 above.
- **Items:**
  1. Read 0.6.2's Appendix C (`docs/plans/0.7.0/0.6.2-appendix-c.md`, D-1; its W0 rows are also in
     `widgets.md`). Session B's results are in that copy, in the rows marked "Session B, second
     attempt, 2026-10-30 (final)", from its report `docs/plans/0.7.0/sessions/B.md`.
     Fill this plan's Appendix C table "From 0.6.2" with each D-row and each W0 row. Session A's
     final answers are already there (2026-10-24, from `docs/plans/0.7.0/sessions/A.md`, merged at
     `5849d01`), and D-13's redacted capture came with them; this item checks that D-17's installer
     fix arrived. **What the final `A.md` brought of what this plan asked:** SPIKE-C's and SPIKE-I's
     W0-2 answers (passed), the offset text in Russian (passed, W0-6), the 80 → 100 → 80 reads (the
     100 % diff, as reads a minute after each change rather than timeline rows), the redacted
     capture, and the Charge Limit's evening reads with their exact values plus the pending ones
     (Appendix C finding 9; FEA-35's 0.8 half). **Not brought:** the Details and Device choosers
     (never opened, so W0-1 (b) stays with W-3a's review, §2.2) and the Russian Charge Limit
     screenshot (D-13).
  2. §2.2 records each spike's final answer and its scope in §4's packages (2026-10-24, checked
     against the final `A.md`, whose one reversed finding, W0-4 (4)'s activity, reopened W-3c's
     click route). It lands as one commit to the committed plan.
  3. Re-resolve every file:line of this plan at the v0.6.2 tag. WP-15's git moves and WP-10's edits
     shift most of them.
  4. Check that every decision is still as recorded on 2026-10-22 and 2026-10-23: M-1, M-2, M-3,
     M-5 (approved, no dates), M-9, Q-W1 to Q-W13 and Q7-1 to Q7-10 (§2.4, §14).
  5. Decide W-0K (D-2). W-0S isn't needed: the spikes ran (§2.3). **Decided 2026-10-30: W-0K isn't
     needed either:** 0.6.2 shipped K-03 (Appendix C, D-2 and D-3).
  6. **Before 0.6.2's branches are deleted** (the integration branch `claude/nice-faraday-k08mhb`,
     and `claude/062-*`; this is asked of 0.6.2's D3 too): check that
     `docs/plans/0.7.0/` holds 0.6.2's `m5-session.sh`, its swap helper (`swap.swift`), the
     hands-free helpers (`ui.swift`, `frames.swift`, `SESSION-B.md`, `start-session-b.sh`), the
     whole P2 Appendix C (`0.6.2-appendix-c.md`) and Session A's report (`sessions/A.md` with its
     files in `sessions/A/`; D-1, D-11), as 0.6.2's D3 copied them. If
     not, read them from the 0.6.2 release PR's `refs/pull/12/head` (Q7-8).
  7. **CI moves to Xcode 27.2 at 0.7's start,** once the `xcode-27` runner image carries it: one
     commit sets `DEVELOPER_DIR` to Xcode 27.2 in `ci.yml` and `release.yml` (both name
     `/Applications/Xcode_27.1.app` today) and fixes any new warning, since both jobs treat
     warnings as errors. 0.6.2 shipped on Xcode 27.1, so its release matched its tested RC.
     - Swift stays 6.4: Xcode 27.2 includes Swift 6.4 and the macOS 27.2 SDK (Apple's Xcode 27.2
       release notes).
     - The 27.2 SDKs for macOS, watchOS, tvOS and visionOS incorrectly report 27.1 as a valid
       deployment target, a known issue (187160501; Apple's Xcode 27.2 release notes). That is
       harmless here: the package targets macOS 27 (`.macOS(.v27)` in `Package.swift`), not 27.1.
     - Session R's RC is the first build on 27.2, so the RC tests the toolchain 0.7.0 ships with.
     - The cloud sessions' Linux toolchain moves with it: `SWIFT_VERSION` in
       `.claude/hooks/session-start.sh` goes from 6.4.1 to 6.4.2 (swift.org publishes 6.4.2 for
       Ubuntu 24.04), in the same commit.
  8. **The widget's language** (0.6.2 Session B's F8-ru). The widget showed English after its
     extension's container `AppleLanguages` was set to Russian and the extension was ended,
     because nothing redrew it: WidgetKit keeps the saved render until a reload, and the step
     took its shots 5 s later. The RC's widget code and its Russian tables equal 0.6.1's, so this
     is a test artifact, recorded "not checked: no redraw". It points at a gap that predates
     0.6.2 [unverified on a Mac]: a language chosen for BatteryPulse alone (Settings → General →
     Language, which writes the app's own domain) most likely never reaches the sandboxed
     widget, and the app never reloads the widget when its language changes. So:
     - **W-4:** the reload planner gains a reason "the app's language changed". The app keeps
       its effective language (`Bundle.main.preferredLocalizations.first`) in its defaults, and
       at a launch where it differs it ends the extension and reloads every placed kind, as a
       version change does (`WidgetRefresher.endPreviousExtension()`). The decision lives in
       BatteryCore with its Linux test.
     - **W-3b, with W-5's feed (or the shared-preference read of the app's `AppleLanguages`
       alone, if W-5 is cut):** the widget picks its `.lproj` from the app's language list at
       each render. That changes the widget's reads or entitlements, so it goes through the
       posture check and Session R.
     - **W-12:** Session R's Russian step switches the language the way a user does (the app's
       language in System Settings → Language & Region → Applications), relaunches the app,
       waits for the reload notice and a new extension process, and only then takes its shots.
       No reload within its timeout is "not checked", never "n".
     - **W-10:** USER_GUIDE § Language says what the widget follows.
  9. **Session B's findings** (0.6.2, 2026-10-30; the findings row of the Appendix C copy):
     - **History over Raw Data's table:** after an AX switch from Raw Data, History showed its
       title, picker and sidebar selection over Raw Data's table for a few seconds. Not a 0.6.2
       regression (`MainView`'s ZStack, `.id(selection)` and opacity transition date from 0.5.0);
       most likely the AppKit-backed table's removal waits for the next window update when no
       pointer moves [inferred]. Session R compares 0.6.1 and the RC with a pointer-free switch,
       and **W-3c**, which owns `MainView.swift`, fixes it if it reproduces.
     - **The session script (W-12):** macOS 27.2 lists no menu bar item window in CGWindowList
       (P11), so S3 and V01-menubar's dark bar and pixel diff need another way; System Settings
       panes by URL open the wrong pane for appearance, desktop and displays (P8); P6, P3 and P5 as
       recorded; the script's desktop clicks leave the click-wallpaper-to-show-desktop state on, and
       computer use leaves a 28×40 pointer overlay at its last click that fails the occlusion check,
       each ended by a click or a move on bare desktop; banners at layer 23 (the Claude desktop
       app's permission banner, a macOS Software Update banner) refused the desktop click and
       blocked five runs, so preflight asks him to quit the Claude desktop app and to postpone
       pending macOS updates before the queue; F8 gets its own redraw (item 8).
     - **WP-18's Xcode items** (SUI-17, SUI-19's timing, SZ-10's icon) didn't run: Xcode asked to
       install system components after the macOS 27.2 update, and the frozen worktree had no
       icon source. **C-1**, in Session R's GUI phase.
     - **The menu bar item on a dark bar** wasn't checked on the RC (P11; the light bar read
       right): **C-1**, Session R's GUI phase, by another way than CGWindowList (W-12).
     - **The hands-free cost** held: about the planned 13-15 minutes of his, plus closing one
       banner (§6.2's estimates stand).
- **Acceptance:** Appendix C's "From 0.6.2" table is complete, and every package below names its
  §2.2 row.
- **Effort:** none in runs, but item 7's commit (and any warning 27.2 adds); item 8's work lands
  in W-4, W-3b, W-12 and W-10, and item 9's in W-3c, W-12 and C-1.

### S-1: `bpulse`'s JSON for scripts: ISO 8601 device dates and `formatVersion` (P1)

- **Source:**
  - CB-02 (P1 §8 Q3; R:554-556; INV QUA-14);
  - NEW-11 (RD §3.2, §5.2);
  - the frozen-outputs rule (R:437-439; PB §3.4 "Public outputs of `bpulse`").
- **Items:**
  1. **Dates:** `renderDevice`'s encoder sets `.iso8601` (`Sources/bpulse/main.swift:190-191`).
     - Today it has no date strategy, so `firstUseDate` prints as seconds since 2001. The Mac's
       `--json` already uses ISO 8601 (`main.swift:162-164`).
     - Only the `bpulse` encoder changes. `IDeviceBattery`'s `Codable` conformance stays as it is,
       because `DeviceStore` persists it with its own ISO 8601 encoder (`DeviceStore.swift:141-149`)
       and storage is frozen.
  2. **`formatVersion`** in every top-level JSON object `bpulse` prints:
     - **Gains it:** `--json`; each compact line of `--watch --json` (`main.swift:163`); `--device
       <n> --json`; and `--input <device capture> --json`.
     - **Unchanged:** `--export json` already has it (`HistoryExport.swift:135`, value 1).
       `--accessories --json` stays a bare array (UG:648-653; RD §3.2: wrapping it would break
       scripts for no gain).
     - **The value:** each newly versioned object starts at 1, and a missing field means 0.6.x's
       shape. A technical choice, documented in UG.
     - **How:** one encoder helper in BatteryCore (`MachineJSON`, a new file) wraps the value. The
       stored `Codable` types stay unchanged.
     - **Copy JSON** (`CaptureFormat.swift:24-31`) uses the same helper, so a bug report's JSON and
       `bpulse --json` keep matching. Recommended, and the run decides; Copy JSON isn't a frozen
       `bpulse` output (PB §3.4).
  3. **UG:** the command-line section documents both changes (UG:620 "`--json` prints the same as
     JSON"; UG:648).
- **Files:** `Sources/bpulse/main.swift`, a new `Sources/BatteryCore/MachineJSON.swift`,
  `Sources/BatteryCore/CaptureFormat.swift`, `Tests/bpulseTests/*`, a new
  `Tests/BatteryCoreTests/MachineJSONTests.swift`, `docs/USER_GUIDE.md` (lines 561-663 only).
- **Linux tests:**
  - The iPhone fixture (`iphone17promax-ios27.0.1-usb.plist`) prints an ISO 8601 `firstUseDate`.
  - Every `--json` object has `formatVersion` 1 as a sorted key.
  - The accessories JSON is still an array.
  - A decoder that ignores unknown keys reads the new output, as an old script would.
- **Acceptance:** D1's golden diff (P1 §5's forms) differs from v0.6.2 in exactly these places:
  - `formatVersion` in every `--json` form;
  - the device fixture's `firstUseDate`.

  Nothing else changes.
- **Effort:** S, 1 run. **Risk:** low. **Rollback:** revert the commit (the notes line goes with
  it).

### R-1: Docs riders (P2; no maintainer time: M-2 and M-5 are decided)

- **Source:** RD §3.2 "Docs riders"; INV DOC-09, DOC-10, PLT-05; RD M-2, M-5, NEW-18.
- **Items:**
  1. **DOC-09** (M-2, decided by delegation: not in 1.x):
     - README loses the iOS 27 badge (RM:5) and "The iOS app comes later" (RM:14-15).
     - README's "What each platform exposes" (RM:192-206) loses its iOS column and the footnote
       ("The planned workaround…", RM:205-206), whose "via analytics import*" cells would
       otherwise point to nothing.
     - The bug template loses "or iOS 27" (`bug_report.yml:23-24`), and
       `.github/ISSUE_TEMPLATE/feature_request.yml:17` offers only macOS (`options: [macOS, iOS]`
       today).
     - ROADMAP keeps Stage 2 under "Not planned".
     - **ROADMAP's Decisions** (R:8-14): "Platforms" becomes "macOS 27 minimum; BatteryKit still
       builds for iOS 27 (PLT-05)"; "Distribution (iOS): undecided" becomes "Not in 1.x (M-2)";
       and, as M-3 decided (by delegation: not in 1.x), "Distribution (macOS)" drops "(and later
       charge limiting)" (R:10-11). That line already records M-1's no (2026-10-22), with Open
       Anyway and the permissions or placed widgets a DMG replacement may lose as 1.0's known
       limitations. ROADMAP's own iOS 27 column (R:48-60) goes in 0.9.0's restructure (RD §3.5).
  2. **DOC-10:** `.github/ISSUE_TEMPLATE/bug_report.yml` asks for the BatteryPulse version (About,
     or Settings → Advanced → Version) and how it was installed (DMG, in-app update, built from
     source).
  3. **PLT-05:** ROADMAP records that CI keeps building BatteryKit for iOS (ci.yml:196-197) until
     that first costs time.
  4. **M-5** (approved by the maintainer, 2026-10-22): RD §2, condensed into a "Road to 1.0"
     section of ROADMAP:
     - the five promises: seen working on the M5 in a packaged build; a week of daily use without
       a crash; in-app updates from older versions; nothing breaks through 1.x; usable by a
       non-expert;
     - C1-C17 in one line each, and the 1.x promises (C14);
     - the order of versions (0.7, 0.8, 0.9.x, 1.0.0, then 1.1 once macOS 28 ships) with their
       effort estimates, and no target date, calendar or outer bound: "this is a hobby project; we
       release when there is time and desire".

     W-13 later rewords the section's lines for C14 items 1, 6 and 8 (settings keys, the update
     contract, privacy), as it changes them.
  5. **NEW-18:** `docs/VERIFICATION.md` starts. It has one row per USER_GUIDE feature, with the
     session and evidence (screenshot or log) from a DMG build, beginning with 0.6.2's evidence.
     0.7's rows are filled at D3. A technical choice of file; English only.
- **Files:** `README.md`, `.github/ISSUE_TEMPLATE/bug_report.yml`,
  `.github/ISSUE_TEMPLATE/feature_request.yml`, `docs/ROADMAP.md`, the new `docs/VERIFICATION.md`.
- **Acceptance:** `LocalizationCatalogTests` (its `docs/` scan) is green. The review checks every
  line against RD.
- **Effort:** S, 1 run. **Risk:** none. **Rollback:** revert.

### W-1: The widget model in BatteryCore (P1; Linux only)

- **Source:** P2 §8.6, §8.13, §8.14 W-1; INV FEA-07; REJ-06, whose condition is now met (RD §4.3).
- **Items:**
  1. **A folder `Sources/BatteryCore/Widget/`.**
     - `BatteryWidgetKind`, `WidgetReloadPolicy` and `WidgetTimelinePlan` move out of
       `BatteryPresentation.swift` (lines 114-238) unchanged, in their own commit (REJ-06's
       condition: "the file is next substantively changed").
     - `WidgetReloadPolicyTests` and `WidgetTimelinePlanTests` stay green, unedited, in the move
       commit. Item 7 then edits `WidgetTimelinePlanTests` on purpose, in its own commit.
  2. **Mirrors and enums with frozen `String` raw values:**
     - `WidgetSize` (small, medium, large, extraLarge, extraLargePortrait) and `WidgetKindID`.
       `WidgetKindID.battery.rawValue == BatteryWidgetKind.battery`.
     - `BatteryWidgetField`, `BatteryWidgetMain`, `BatteryWidgetVisual`, `WidgetLayoutMode`,
       `WidgetStatusLine`, `WidgetTimeStyle`, `WidgetColorStyle`, `WidgetUpdateTimeStyle` (P2's
       `WidgetReadTimeStyle`, renamed after the visible words "Update time"; the raw values are what
       freeze), and `AccessoryWidgetMode` (all, lowest).
     - Only the cases that ship are declared (§3 "Frozen values").
  3. **`WidgetLayoutPlan`**, `automatic(size:)` and `make(kind:size:layout:main:visual:statusLines:fields:snapshot:)`:
     - which fields fit which family, and in what order;
     - drop unavailable values and duplicates of the main value;
     - the attention row in the last slot; in small Automatic, which has no detail slot, it
       replaces the time line;
     - the `.empty(reason)` states;
     - **a non-colour cue** for every tier that isn't normal (low or critical level, low health, an
       abnormal condition) in every colour style. It is a symbol or a word (P2 §8.7; HIG "Convey
       meaning without relying on specific colors").
  4. **`WidgetTimeText`:** clock time or time left.
     - An end on a later local day reads "Lasts until about %@ tomorrow" or "Full at %@ tomorrow"
       (P2 §8.6). With the attention row and "Updated %@" (§7.3), that is one of the intended
       differences from 0.6.1's small and medium look.
     - An end beyond tomorrow shows no clock time and no weekday (Q-W5, decided by delegation,
       §14): valid estimates run up to 65,534 minutes (`MacPowerParser.swift:123, 281-284`).
     - The end comes from the reading's time (`snapshot.timestamp`), never `entry.date`; today's
       view uses `entry.date` (`BatteryPulseWidget.swift:192, 196`), which is harmless only while
       every later entry hides the estimate (item 7).
     - Time left is `Text(.currentDate, format: .offset(to: end, allowedFields: [.hour, .minute],
       sign: .never))`, in one helper (§2.2 W0-6; W-10 item 4).
  5. **`WidgetTextBudget`:** the most characters per slot and family (P2 §8.6).
     - The budgets come from today's widget with its `minimumScaleFactor(0.8)` applied, and the
       widest value per locale: the 24-hour "23:59" for `ru`, "12:59 PM" for `en_US`.
     - P2 §8.6's example budgets are below keys the widget reuses: "Battery power" is 21
       characters in Russian and "Low Power Mode" 22, over a medium label's 20, and "Lasts until
       about %@" with "12:59 PM" is 27, over a small status line's 24 (`Localizable.xcstrings`).
     - A reused key over budget gets a widget-only short key with its Russian (listed in §8),
       instead of a change to the app's settled key.
  6. **`WidgetRow`:** pre-formatted values, with labels kept as keys.
  7. **`WidgetTimelinePlan`, extended:**
     - a stale entry at reading + 45 minutes (`isStale`). Its `showsEstimate` is (the estimate's
       end > the stale entry's date), so an estimate ending between +30 and +45 minutes never shows
       a passed time;
     - at most 3 entries;
     - this commit updates the six assertions on exact entries in `WidgetTimelinePlanTests`
       (lines 24, 31, 38-41, 48, 53 and 77: `entries ==`, `entries.last ==` and `count == 1`);
     - a plan per kind: Battery as today, Accessories 30 minutes, never closer than 15 minutes (P2
       §8.6).
  8. **`PageID` and `WidgetRoute`:**
     - `PageID` has every `SidebarItem.storageKey` string (`MainView.swift:64-75`): `overview`,
       `power`, `health`, `history`, `developer`, `demo`, `devices`, `accessories`, and
       `device:<key>`.
     - `WidgetRoute(url:)` accepts only `overview`, `power`, `health`, `history`, `devices`,
       `accessories` and `device:<valid DeviceKey other than the demo's>`, rejects `developer`
       and `demo`, and builds the URL a widget sets.
     - **Its scheme is `batterypulse`** (`batterypulse://page/<page>`), the form Session A saw
       arrive with no scheme registered (§2.2 W0-4 (4), (5)). `claude/070-w1` chose
       `io.github.nikitausov.batterypulse`; its rebase onto v0.6.2 changes the scheme and its pin in
       one commit, before anything ships it.
     - **`WidgetRoute(activityType:)`:** a click without a `widgetURL` arrives as an
       `NSUserActivity` whose type is the intent's type name (Session A: `SpikeWidgetIntent`, §2.2
       W0-4 (4)). It maps the manifest's intent type names (item 10) to their kind's natural page
       (`BatteryWidgetIntent` → Overview; W-8 adds `AccessoriesWidgetIntent` → Accessories) and
       rejects any other type. It reads no user info, since Session A logged only its keys. The
       rebase adds it in a commit of its own.
  9. **`ReadCoalescer<Value>`:** the pure logic of the widget's read cache. Requests within 5 s share
     one in-flight read and its result; there is a manual clock for tests.
  10. **`WidgetIntentManifest`:**
      - lists every kind string, `supportedFamilies` per kind, intent type name, parameter name and
        `AppEnum` raw value that ships;
      - is exported as `scripts/widget-manifest.json`, which a test keeps equal to the type;
      - is what W-2's CI check reads.
  11. **`LocalizationCatalogTests` learns the App Intents literal forms** (P2 §8.11), before any
      intent code exists: `static (let|var) title: LocalizedStringResource = "…"`, `static (let|var)
      description = IntentDescription("…")` and `IntentDescription("…")`, `@Parameter(title: "…")`,
      `Summary("…")`, `TypeDisplayRepresentation(name: "…")`, `DisplayRepresentation(title: "…")`,
      and `caseDisplayRepresentations` dictionary literals (`[.x: "…"]`), with one test vector per
      form. Moved here from W-10, because each widget package adds its keys in its own commit (§3).
- **Linux tests** (new files under `Tests/BatteryCoreTests/`):
  - **The first test, before W-3a replaces the view:** `automatic(.small)` and `automatic(.medium)`
    equal v0.6.1's widget field for field, on the M5 fixtures and a synthetic battery without a pack
    temperature, in states without the attention row and with a fresh reading.
  - Every family's slot count. Order kept, duplicates and the main value dropped. The attention row
    last. Each `.empty` reason.
  - **The non-colour cue:** for every tier × colour style, the plan's output carries a symbol or a
    word.
  - **`WidgetTimeText`:** UTC+3 and UTC−8, an end after local midnight, and `en_US`, `en_GB` and
    `ru_RU` (12- and 24-hour). An estimate of 3,000 minutes shows no clock time. The end comes from
    the reading's time.
  - **`WidgetTextBudget`:** for every widget key, the catalog's English and Russian text with its
    widest value per locale ("12:59 PM" in `en_US`, "23:59" in `ru`, "−88.8 W", "100 %"), against
    budgets taken from today's widget with its scale factors (item 5). It reads
    `Localizable.xcstrings` on Linux, as `LocalizationCatalogTests` does. A reused key over budget
    fails until its widget-only short key exists.
  - **`WidgetTimelinePlan`:** the stale entry comes after every planned reload, and there are at most
    3 entries. An estimate ending between +30 and +45 minutes isn't shown on the stale entry. The
    stale entry shows the same clock time as the first.
  - **`WidgetRoute`:** round trips; rejects other schemes and hosts, unknown pages, `developer`,
    `demo`, invalid `DeviceKey`s, and `DeviceKey.demo`; each intent type name maps to its kind's
    page, and any other activity type is rejected.
  - **`ReadCoalescer`:** N concurrent requests within 5 s make 1 read; a request after 5 s makes a
    new read; a failed read isn't cached.
  - **`WidgetSurfaceTests`, the frozen-value pin** (P2 §8.13):
    - the kind strings, raw values, `PageID` strings, and the manifest's JSON;
    - the key set of `Resources/BatteryPulseWidget.entitlements`, which is the sandbox alone in the
      MVP;
    - a source scan that `SidebarItem.storageKey`'s literals equal `PageID`'s raw values.

    No test pins these today; 0.6.1's check was D1's `git grep` (P2 §8.13).
- **Files:** `Sources/BatteryCore/BatteryPresentation.swift` (the move),
  `Sources/BatteryCore/Widget/*.swift`, `scripts/widget-manifest.json`,
  `Tests/BatteryCoreTests/Widget*Tests.swift`, `Tests/BatteryCoreTests/LocalizationCatalogTests.swift`
  (item 11).
- **Guards:** none new here. The pin test is W-1's own.
- **Acceptance:** `swift test` on Linux with the new tests, and both CI jobs green. The move commit
  changes no test; item 7's commit changes only the six assertions it names.
- **Effort:** L, 3 runs. **Risk:** low (Linux only). **Rollback:** revert. Nothing ships without
  W-3a.

### W-2: The App Intents metadata step (P1; W0-1 passed, G7-1)

- **Source:** P2 §8.14 W-2, WP-W0's W0-1 (the route and the processor options, which SPIKE-W's CI
  build #282 used and Session A saw work: the edit sheets show every parameter); INV FEA-08; SIZ-06.
- **Items:**
  1. **The step in `scripts/build-app.sh`,** after the widget's build and before its `codesign`
     (`build-app.sh:237`):
     - Collect the widget module's `.swiftconstvalues` and Swift sources into file lists.
     - Run `xcrun appintentsmetadataprocessor` with the options W0-1 validated, on the unstripped
       binary `$BIN_PATH/BatteryPulseWidget` (P2 W0-1). The bundle's copy (`$WIDGET`, copied at
       `build-app.sh:141`) is stripped at :220 and keeps the same UUID, which the dSYM check at
       :222-231 relies on; the symbol checks at :174-187 read `$BIN_PATH` for the same reason.
     - Write `$APPEX/Contents/Resources/Metadata.appintents`, before :237.
     - Why a step of our own: SwiftPM sets `LM_SKIP_METADATA_EXTRACTION=YES` (P2 Appendix B).
     - No new compiler flag (CL: "no compiler flags of its own").
     - While the widget declares no App Intents type, the step prints a note and skips. W-3a makes
       it unconditional.
  2. **`scripts/appintents-check.swift`:**
     - Reads `extract.actionsdata` and `scripts/widget-manifest.json`.
     - Fails unless every intent, parameter and `AppEnum` case of the manifest is in the metadata.
       The processor can exit 0 without writing (P2 W0-1).
     - Dumps the extracted `Summary` keys for W-10's placeholder decision (W0-1 (d)). The keys must
       be in the catalog, although macOS 27's edit sheet doesn't show the summary (§2.2 W0-1).
     - A self-test runs it on a doctored copy that lacks one case, and expects a failure. The
       self-test's input is a committed sample, `scripts/appintents-sample.actionsdata`, taken from
       W0-1's (or W-2's first) CI run.
     - `extract.actionsdata` is an undocumented Apple format that may change with Xcode, so the
       checker fails loudly, naming the problem, on a top-level shape it doesn't know.
  3. **ci.yml:** the macOS job runs the check after packaging. The "Check the verification
     scripts" step gains `swift scripts/appintents-check.swift --self-test`.
  4. **`size-report.sh`:**
     - a row `widget_appintents_bytes`, the size of the `Metadata.appintents` folder;
     - its ceiling in `size-budget.json`, set at the RC plus about 5 % in D1, in a commit of its
       own;
     - it also counts toward `app_kb` (P2 §8.12).
  5. **The edit sheet's strings** (Appendix C row 10; D-8; G7-13). In Session A the widgets followed
     the extension's Russian `AppleLanguages`, but the edit sheet stayed English, although the
     spike's strings had their Russian in the catalog. The system draws the sheet from
     `Metadata.appintents`, so either the hand-extracted metadata doesn't carry those strings in a
     form it localizes, or it resolves them in its own language, not the extension's [unverified
     which]. So:
     - **The check:** `appintents-check` lists every string the sheet shows (the intent's title and
       description, each parameter's title, each `AppEnum` type and case, the Details entity's
       type name, each `Summary`) with the key and table the metadata records, and fails unless
       each is a catalog key with its Russian that the widget bundle's compiled `ru.lproj` table
       holds. If `extract.actionsdata` records resolved text instead of keys, the check fails and
       says so.
     - **The fix, if it fails:** the step passes the processor the localization inputs Swift
       Build's spec gives it (P2 Appendix B) [unverified which], or `build-app.sh` writes the
       intent keys into the table the metadata names, until the check passes, before W-3a merges.
     - **If it passes,** the English sheet came from the method, not the build: Session R step 4.3
       sets BatteryPulse's own language as well, and a sheet still English is "not checked"
       (G7-13), never a failure.
- **Files:** `scripts/build-app.sh`, the new `scripts/appintents-check.swift` and
  `scripts/appintents-sample.actionsdata`, `.github/workflows/ci.yml`, `scripts/size-report.sh`,
  `scripts/size-budget.json`.
- **Guards:** the CI check itself. The posture check is unchanged: the metadata is a resource that
  `codesign` seals, and the entitlements don't change.
- **Acceptance:**
  - Both jobs green.
  - The macOS log shows the step "skipped (no intents)" before W-3a, and "N intents, M parameters, K
    cases" after.
  - The self-test fails on the doctored copy.
  - The check lists the edit sheet's strings with their keys and Russian (item 5).
- **Effort:** M, 2 runs. **Risk:** low-medium.
  - The processor's options come from Swift Build's spec (P2 Appendix B), and SPIKE-W's build
    (#282) on the runner's Xcode 27.1 (ci.yml:94) showed they work (§2.2 W0-1).
  - A later Xcode may change the processor or `extract.actionsdata`; the check fails loudly.
- **Rollback:** revert before W-3a merges. After that, a broken step is fixed forward: without
  metadata the edit sheet is empty, and whether such a widget still appears in the gallery is
  [unverified].

### W-11: The drawn-battery painter, shared with the widget (conditional on Q-W4)

- **Source:** P2 §8.5 (Main visual), §8.14 W-3; RD §4.3 REJ-04 ("a move, not a redesign").
- **Runs:** Q-W4, decided by delegation, offers the drawn battery as a main visual. The look check
  signs off its picture (§6.1 question 4), and W-11 is cut fifth if the budget runs short (§7.2).
- **Items:**
  1. **A SwiftUI-only target,** `BatteryArt` (macOS code inside `#if os(macOS)`, as the app's is).
     - It holds `BatteryIconPainter` and `BatteryIconCanvas`
       (`MenuBar/BatteryIconView.swift:9-236`), moved with `git mv`-style history and access
       changes only. Both are internal with memberwise inits today (:9-14, :215-222), so the move
       makes the types, `paint(in:magnification:)` and explicit inits `public`, and nothing else.
     - `MenuBarIconPreview` (:238-263), which uses the canvas for Settings' tiles, stays in the app.
     - `MenuBarIconRenderer` and `AppearanceVariants` (`BatteryIconView.swift:265-342`), with its
       one `@unchecked Sendable`, stay in the app.
     - The app and the widget depend on `BatteryArt`. It gets `strict` settings and no flags of its
       own.
     - It may use only extension-safe APIs: SwiftUI and CoreText, which the painter already uses
       (`BatteryIconView.swift:1-5`).
     - **Why a target and not a copy:** one painter keeps the widget's battery identical to the
       menu bar's, and `BatteryIconLayout` stays the single geometry (BatteryCore,
       `BatteryIcon.swift`).
  2. **The widget can't read the app's settings** (no shared container, P2 §8.1). So the widget's
     drawn battery is one fixed style: Modern, like macOS 27's (UG; R:240-248).
- **Files:** `Package.swift` (one target, two dependency lines), `Sources/BatteryArt/*` (moved),
  `Sources/BatteryPulseApp/MenuBar/BatteryIconView.swift`,
  `Tests/BatteryCoreTests/SourceScanner.swift` (`targets` gains "BatteryArt"),
  `Tests/BatteryCoreTests/MotionGuardTests.swift` (`menuBarLabelFiles` gains the moved file, so no
  animation can enter it).
- **Guards:**
  - `MotionGuardTests`' menu bar rule keeps covering the painter.
  - WP-15's folder test (P2) sees the new target listed.
- **Acceptance:**
  - Both jobs green.
  - `MenuBarTests` unchanged.
  - `scripts/menu-bar-shots.sh` output identical, pixel for pixel, before and after on the M5 (an
    optional Session R step). Without it, the CI launch smoke and the unchanged code stand in.
- **Effort:** S-M, 1-2 runs. **Risk:** low-medium (the menu bar icon is the most visible element,
  REJ-04).
- **Rollback:** revert. The drawn-battery case is then not declared; this is decided before D1.

### W-3a: The Battery kind becomes configurable: small and medium (P1)

- **Source:** P2 §8.5, §8.6, §8.9, §8.10, §8.14 W-3; INV FEA-06, L10N-05, TCI-10; R:543-553; the
  §2.2 rows for W0-1, W0-2, W0-6.
- **Items:**
  1. **`BatteryWidgetIntent: WidgetConfigurationIntent`** in the widget target, never in BatteryCore
     or the app (P2 §8.11; REJ-60).
     - **Parameters** (P2 §8.5): Layout, Main value, Main visual, Status lines, Details, Time,
       Colors, Update time.
     - Each parameter's `default:` reproduces today's widget, and a placed 0.6.x widget gets
       Automatic.
     - Details shows only when Layout is Custom (`ParameterSummary` `When(\.$layout, .equalTo,
       .custom)`). Its size per family follows the §2.2 row for W0-1 (a): `size:
       [.systemSmall: .init(min: 0, max: 1), .systemMedium: .init(min: 0, max: 4), .systemLarge:
       .init(min: 0, max: 8), .systemExtraLarge: .init(min: 0, max: 12)]`, so the empty default
       and "an empty Custom list means no details" (P2 §8.5) hold whatever the integer-literal
       form means (https://developer.apple.com/documentation/appintents/intentcollectionsize).
       Session A saw both work: Details appears only with Custom, with 4 slots on medium. The
       per-family `size:` exists only for an entity array (§2.2 W0-1 (a)), so Details is
       `[BatteryWidgetDetail]` (item 2); SPIKE-W used integer literals, so `init(min:max:)` per
       family is [untested] until this package's first CI build.
     - **The summary sentence isn't shown** by macOS 27's edit sheet (Session A saw no "Show
       Charge" line). `ParameterSummary` stays because its `When` clauses work, with one plain
       `Summary` per branch; nothing in the widget's design depends on the sentence being seen.
     - The title follows Apple's advice of title case with a verb and a noun: "Choose Battery
       Details" (https://developer.apple.com/documentation/widgetkit/making-a-configurable-widget).
       The wording is checked in the look check.
     - **Intent and `AppEnum` metadata are `static let`:** `title`, `description`,
       `typeDisplayRepresentation` and `caseDisplayRepresentations`. Apple's sample writes `static
       var title: LocalizedStringResource = "…"`, but a stored `static var` is nonisolated global
       mutable state, an error in Swift 6 language mode, which the package uses (`Package.swift:1`,
       tools 6.4). A `static let` satisfies the protocols' `{ get }` requirements.
  2. **`AppEnum`s that map one to one** to W-1's enums, with equal raw values (a source test). The
     case titles come from `caseDisplayRepresentations` literals (`static let`).
     - **Details' entity,** `BatteryWidgetDetail: AppEntity`, because an `AppEnum` array can't be
       sized per family (§2.2 W0-1 (a)). Its `id` is `BatteryWidgetField`'s frozen raw value, its
       `DisplayRepresentation(title:)` the field's catalog label, and its `EntityQuery` lists the
       fields that fit, in the extension, like SPIKE-W's `SpikeDetailQuery`. The pin test covers
       the ids.
     - **Whether the query runs** in the ad-hoc extension is W0-1 (b), which the final `A.md`
       left open (the Device chooser was never opened, and A.md doesn't say whether Details' was: its slots stayed "Choose"). This package's review chooses before its merge:
       G7-1's default, per-slot optional `AppEnum` parameters shown per family with
       `When(widgetFamily:)`, or this entity, on the inference that the extension serves App
       Intents requests (its perform ran there, W0-1 (c)), with Session R step 4.1's chooser as
       the check (§2.2).
  3. **`AppIntentConfiguration(kind: BatteryWidgetKind.battery, intent:, provider:)`:**
     - `.supportedFamilies([.systemSmall, .systemMedium])` here; W-3b adds the rest.
     - `.containerBackground(.fill.tertiary, for: .widget)` as today.
     - The gallery description changes to the new key (§8).
  4. **`AppIntentTimelineProvider`:**
     - `timeline(for:in:)` and `snapshot(for:in:)` are async.
     - They read through `WidgetReadCache`, a `Mutex`-guarded final class over W-1's
       `ReadCoalescer`. There is no `@unchecked Sendable` (`SecurityGuardTests` keeps four).
     - The read is WP-14a's nonisolated entry (D-4), on a `@concurrent` function (CL concurrency).
     - **Gallery previews** (`context.isPreview`) use the real reading when there is one, and
       `DemoBattery` only without a battery.
     - `placeholder(in:)` keeps today's generic sample (`BatteryPulseWidget.swift:39-47`).
  5. **Small and medium views:** Automatic, as in 0.6.1, and Custom.
     - Status lines, time text, colours, update time ("Updated %@", an existing key), empty states.
     - **Today's layout constants are kept:** the 34-pt hero number with `minimumScaleFactor(0.7)`;
       labels with `lineLimit(1)` and `minimumScaleFactor(0.8)`; values with `fixedSize()`
       (`BatteryPulseWidget.swift:117-163`).
  6. **`widgetURL(WidgetRoute(…).url)`:** exactly one per widget, on the natural page (P2 §8.9).
     - Battery → Overview.
     - Battery with maximum capacity as the main value → Health.
     - Battery with temperature or battery power as the main value → Power.
     - An empty state → the page that fixes it.
  7. **`BatteryFormatter.widget`** (L10N-05): `locale: .autoupdatingCurrent`, with `UnitSymbols` from
     the six catalog keys the app uses (`App/Localized.swift:15-23`). Today the widget uses English
     symbols (`BatteryFormatter.swift:33-41`). A Linux source test asserts that the two key sets
     are equal.
  8. **Signposts in the widget:** a widget twin of `Diagnostics` (category `widget` plus the `perf`
     signposts), or BatterySource's after K-03.
     - `widget.timeline`, an interval whose `StaticString` trigger comes from a switch over
       `WidgetKindID`: `battery`, and `accessories` with W-8 (P2 §8.10).
     - The kind string never goes in a trigger.
  9. **W-2's step becomes unconditional,** and the manifest gains the intent.
  10. **Placed widgets across the update** (§2.2 W0-2): a widget placed by 0.6.x keeps its place
      when today's kind becomes this `AppIntentConfiguration`, with Automatic as its default, as
      long as chronod's descriptor fetch at the version change reaches the new extension. So:
      - 0.6.2's `UpdateInstaller` ends the extension right before the swap
        (`WidgetRefresher.endExtensionBeforeSwap()`, WP-16 item 6; D-17); if 0.6.2 has no source
        test that pins the order (the end before `renamex_np`, with no reload between),
        this item adds one, since 0.7's installer carries the same code to 0.8;
      - 0.7's first launch keeps `WidgetRefresher.endPreviousExtension()`
        (`BatteryPulseApp.swift:58`), for an update from an installer without the fix or a copy
        from the DMG;
      - chronod caches descriptors by `CFBundleVersion`, so a descriptor fetched from the wrong
        extension stays cached for that build number. D1's growing build number stays (§6.5), and
        no two builds the M5 installs share a number;
      - a copy from the DMG over a running 0.6.x extension can still cache 0.7's build number with
        the old descriptor, which Session A saw stay until the next version change (chronod's
        refetch skips a static descriptor, and a chronod restart kept it; P2 §8.16), so the guide
        keeps "add it again if it's gone" for that path (§6.5, §12).

      No new kind and no fallback branch: the evidence points at the extension, not at the
      configuration (G7-2).
  11. **CI render previews (TCI-10)**, a review aid and not a gate:
      - A macOS-only test target `BatteryPulseWidgetTests` does `@testable import
        BatteryPulseWidget` and renders each family with `ImageRenderer` into PNG artifacts.
      - `\.widgetFamily` is get-only
        (https://developer.apple.com/documentation/swiftui/environmentvalues/widgetfamily), so a
        test can't set it. The views therefore take a `WidgetSize` input, and only a thin root view
        reads `\.widgetFamily` and maps it; the tests pass each size.
      - A ci.yml step uploads `build/widget-previews/*.png` as an artifact. The workflow only reads
        the repository (`permissions: contents: read`, ci.yml:29-30), so CI never comments on the
        PR: the orchestrator downloads the artifact and posts the pictures (§6.1).
      - [unverified] whether a test can link an executable target that uses `-e _NSExtensionMain`.
        If it can't, the look check moves into Session R (+10 minutes of his answers, §6.1).
      - Russian renders need the compiled tables. The test tries `LocalizedStringResource` with
        `bundle: .atURL` to the build's `ru.lproj` [uncertain]. Otherwise English only, with
        Russian lengths left to `WidgetTextBudget`.
- **Files:**
  - `Sources/BatteryPulseWidget/*`: split into files for the bundle, the intent, the provider, the
    views and the formatter;
  - `Resources/Localizable.xcstrings`; `scripts/build-app.sh` (one line, item 9);
    `scripts/widget-manifest.json`;
  - `Package.swift` (the test target, if it can link; a one-line rebase-over with W-11, §5);
  - `.github/workflows/ci.yml` (the step that uploads the render PNGs; a rebase-over with W-12, §5);
  - `Tests/BatteryCoreTests/*` (source tests, item 10's order test only if 0.6.2 has none);
    `Tests/BatteryPulseWidgetTests/*`.
- **Guards** (P2 §8.7, §8.8; the rest land in W-10):
  - `SecurityGuardTests`: no file API, `dlopen`, `dlsym`, `URLSession` or `Network` in
    `BatteryPulseWidget/`. The MVP widget reads no file of ours.
  - A source test: the widget never passes a cached-registry scope (D-5).
- **Acceptance:**
  - Both jobs green, and W-1's pin test green with the manifest.
  - W-2's check lists the intent.
  - W-1's `automatic` test is unchanged, and the CI PNGs of small and medium Automatic match 0.6.1's
    look.
  - The size report's numbers are in the commit.
- **Effort:** L, 3 runs. **Risk:** medium-high: the first App Intents code, and the edit sheet shows
  only on the M5.
- **Rollback:** revert the merge, and with it W-3b, W-8 and W-14 (revert those first). A placed
  widget then stays the 0.6.x static one.

### W-4: The reload planner (P1)

- **Source:** P2 §8.6 (`WidgetReloadPlanner`), §8.10, §8.14 W-4; INV ENG-16; CL energy rules.
- **Items:**
  1. **`WidgetReloadPlanner` in BatteryCore:**
     - **Battery:** today's `WidgetReloadPolicy` (`BatteryPresentation.swift:126-180`), plus these
       reasons to reload at once:
       - a Low Power Mode flip (`isLowPowerModeEnabled`);
       - a change of the adapter's watts or wireless flag;
       - a change of condition;
       - the thermal state entering serious or critical (`BatterySnapshot.swift:84-85, 58, 42`).
         It has hysteresis, like the app's heat alert (`BatteryAlerts.swift:104-117`): leaving
         reloads only once the state is back at nominal, so a state flapping between fair and
         serious under load reloads once.

       These four new reasons share a 5-minute minimum between their reloads (W-14 adds a fifth,
       a change of `isAtSystemChargeLimit`, W-14 item 6); today's policy keeps its own rules for
       plug and state changes. A temperature move of 3 °C waits for the 15-minute interval.
     - **Accessories:** a connect or a disconnect reloads at once. A 10-point step waits until 15
       minutes have passed since the kind's last reload.
     - **History and iPhone & iPad:** their policies arrive with W-6 and W-7 (stretch).
     - One planner for every configuration: the app never reads configurations, so it accepts the
       odd reload a widget doesn't need (P2 §8.6).
  2. **`WidgetRefresher` uses the planner** (still the only reload site; EN-11).
     - It observes `monitor.snapshot` (as today, `WidgetRefresher.swift:23-31`) and the
       `AccessoryMonitor`'s list, each in a named task over `Observations { … }.dropFirst()` (CL
       observation rule).
     - The app passes `accessories` in (`App/BatteryPulseApp.swift:34-44`).
     - It skips while Demo Mode overrides either monitor (`isOverridden`).
  3. **`currentConfigurations()`** (macOS 15+,
     https://developer.apple.com/documentation/widgetkit/widgetcenter/currentconfigurations()):
     - It reloads only kinds someone placed.
     - The answer is cached in memory. While no reader is placed, it is asked again at a reload
       moment once it is older than 15 minutes: no new wake-up, no new sleep (P2 §8.3).
     - A failure is logged, never dropped with `try?` (CL logging), and counts as "placed".
     - **Unverified for this app:** whether it returns the real placements to an ad-hoc-signed,
       unsandboxed app; no W0 spike checks it. Until Session R step 1 shows it, an empty answer
       counts as "placed" for Battery, and the filter applies only to kinds absent from a
       non-empty answer. Otherwise a silently empty answer would stop every app reload, leaving the
       widgets to their 30-minute timelines.
     - Each answer logs its count per kind as `.public` numbers, for Session R step 1.
  4. **Signposts:** `widget.reload` keeps the trigger `policy` for the Battery kind, so it compares
     with 0.6.1, and adds `policy.accessories` (P2 §8.10).
- **BatteryCore decisions and Linux tests:**
  - E15's synthetic day (`WidgetReloadPolicyTests.swift:82-171`) through the planner. The Battery
    kind's count stays within today's count plus 7 (P2 §8.10).
  - A day test for Accessories (connects, disconnects, a slow drain), and one with every MVP kind
    placed: under 100 app-initiated reloads a day [estimate, P2 §8.10].
  - A Low Power Mode flip, entering serious heat, a return to nominal, and a condition change each
    reload at once, at most once per 5 minutes between them.
  - **A harder day:** E15 plus 2 Low Power Mode flips, a condition change, and a thermal state
    flapping between fair and serious every 2 minutes for an hour, stays within today's count
    plus 7. (E15's own day varies only the charge, the state and external power,
    `WidgetReloadPolicyTests.swift:82-171`.)
  - A 3 °C move waits for the interval.
  - Accessories: a disconnect 5 minutes after a reload reloads at once; a 10-point step 5 minutes
    after one waits.
  - Nothing is reloaded for a kind that is absent from a non-empty `currentConfigurations()`
    answer; an empty answer still reloads Battery.
  - The planner's first evaluation, fed the start value, records without reloading; the first
    real change reloads once.
- **Files:** `Sources/BatteryCore/Widget/WidgetReloadPlanner.swift`,
  `Sources/BatteryPulseApp/App/WidgetRefresher.swift`,
  `Sources/BatteryPulseApp/App/BatteryPulseApp.swift` (the init line),
  `Tests/BatteryCoreTests/WidgetReloadPlannerTests.swift`.
- **Guards:** `EnergyGuardTests` EN-11 keeps one allowed file; its message names the planner.
  Nothing else changes: no sleep, timer or activity is added.
- **Acceptance:**
  - Both jobs green; the day tests.
  - The first-evaluation test above. (The CI launch smoke can't show it: the runner has no battery,
    so `evaluate()` returns before the planner runs, `WidgetRefresher.swift:135`.)
- **Effort:** M, 2 runs. **Risk:** low-medium. **Rollback:** revert. `WidgetReloadPolicy` alone
  comes back.

### W-3b: Large and extra large, visuals, the attention row, accessibility, rendering modes (P1)

- **Source:** P2 §8.5, §8.7, §8.15, §8.17; INV A11Y-06; HIG; the §2.2 rows for W0-4 (2) and W0-5
  (the maintainer's VoiceOver photos and the tree read, Appendix C row 8); Q-W4, Q-W10, Q-W13.
- **Items:**
  1. **`.systemLarge`:** Automatic shows the charge block and 8 details in two columns (P2 §8.17).
  2. **`.systemExtraLarge`, only with Q-W10's explicit approval in the look check** (decided by
     delegation: two panels, on that explicit yes): a layout of its own, not a stretched large.
     - The recommendation (§14) is two panels: Battery (charge, health, cycles, capacity in mAh) and
       Power (adapter, battery power, system load, temperature, Low Power Mode).
     - **Custom** in extra large fills the Battery panel first, then Power, with up to 6 details
       each (12 in all, W-3a item 1).
     - Without an explicit yes (an answer of 2 or 3, or no answer), `.systemExtraLarge` isn't
       declared. A later release can add it without touching placed widgets (P2 §8.13); RD C1
       already says so.
  3. **Main values and visuals** (Q-W4):
     - **Values:** charge, maximum capacity, temperature, and battery power (only with the update
       time, Q-W7).
     - **Visuals:** the number with the level symbol (today), a number with a ring, and the drawn
       battery (with W-11).
     - The ring is a plain `Circle().trim` in the widget: no `Gauge` with animation, and no glass.
  4. **The attention row** (Q-W13, decided by delegation: on, with no parameter):
     - It shows for a condition other than Normal, or a thermal state of High or Critical. Those are
       the app's own words for serious and critical (`App/Localized.swift:159-161`).
     - It takes the last detail slot, with a symbol and words. Small has no detail slot, so there it
       replaces the time line (W-1 item 3), in Automatic too.
     - "Off by default" would need a Bool parameter, a frozen surface (P2 §8.13), so it isn't
       offered: look-check question 8 asks only "on" or "never".
  5. **Accessibility** (P2 §8.15), with W0-5's requirements (§2.2: on today's widget VoiceOver read
     "In BatteryPulse, widget, 9 items", then "Three-Quarter-Charged Battery, image", then "In
     Three-Quarter-Charged Battery, image, content is empty"; the tree behind it is 9 flat
     elements, an unlabelled image and 8 separate texts):
     - **Decorative symbols are hidden** (`accessibilityHidden(true)`): the level symbol, the cue's
       symbol beside its word, device and accessory glyphs. The level symbol's bucket also
       contradicts the number: `battery.75percent` stands for 63-87 %
       (`BatteryPresentation.swift:15-20`). The widget draws SF Symbols only through one
       `decorativeSymbol(_:)` helper that hides them, so no symbol name is ever read.
     - **The charge is its own element whose label carries the value,** for example "Battery charge:
       70 %, On battery" (the menu bar's existing key, `App/Localized.swift:169-172`), with the time
       line after it.
     - **Each row is one element** (`accessibilityElement(children: .combine)`) reading "label,
       value"; an accessory row reads "name, 45 %, charging".
     - **No empty group:** a container either combines its children into one labelled element or
       is left out of the tree; nothing like 0.6.1's "content is empty" remains.
     - **A button stays its own element** (W-9's Refresh, after 1.0; 0.7 has none).
     - **The label builder,** `WidgetAccessibility` in `Sources/BatteryCore/Widget/`, turns the
       layout plan's rows into the ordered elements, each a catalog key with its pre-formatted
       values (W-1's `WidgetRow` keeps labels as keys), so the views only localize and apply them.
       Tested on Linux (below).
     - **Text styles,** except the hero number. Values never truncate, and the planner drops a row
       instead. Text size doesn't reach desktop widgets (no change at 17 pt, §2.2 W0-5), so no
       layout depends on it.
     - **Checked without driving VoiceOver:** Session R step 7 reads the widgets' accessibility tree
       with the session's `ui` helper (AX at each widget's hit-tested frame), or points
       Accessibility Inspector at each widget by computer use (G7-12). The Russian labels are read the same way, with the extension in Russian (D-8).
  6. **Rendering modes** (P2 §8.7), designed for all three everywhere: Session A's render line
     never reached the log, so no mode is known per style or place, only its screenshots (§2.2
     W0-4 (2)). The views log no mode.
     - The glyph is in the accent group, the main value in the default group.
     - `widgetAccentedRenderingMode(.accented)` for glyphs and `.desaturated` for device symbols.
     - Vibrant uses hierarchical styles only.
     - **Colour is never the only signal:** W-1's cue is drawn in every mode.
  7. **CI render previews** for every family × rendering mode × English (and Russian, if W-3a found
     the way).
     - `\.widgetRenderingMode` is settable (`{ get set }`,
       https://developer.apple.com/documentation/swiftui/environmentvalues/widgetrenderingmode), but
       setting it only switches our views' own branches. The system's white tint, desaturation and
       background removal aren't simulated, so the accented and vibrant PNGs are labelled
       "approximate", and Session R step 5 decides those modes.
- **Files:** `Sources/BatteryPulseWidget/*`, `Sources/BatteryCore/Widget/WidgetLayoutPlan.swift`
  (the large and extra-large plans), `Sources/BatteryCore/Widget/WidgetAccessibility.swift` (new),
  `Resources/Localizable.xcstrings`, `scripts/widget-manifest.json`, the tests.
- **Linux tests** (`Tests/BatteryCoreTests/WidgetAccessibilityTests.swift`), for every family ×
  layout on the M5 fixtures, in English and Russian (the catalog read as `WidgetTextBudget` does):
  - the charge element's label contains the formatted charge, and no label contains an SF Symbol
    name (`battery.`, `percent`) or its spoken form;
  - the element count equals the blocks and rows the plan shows (today's medium widget made 9
    flat elements: the symbol and 8 texts);
  - each row's label is "label, value", in the plan's order; no element has an empty label;
  - the state word and the attention row's words appear in the labels, so colour and symbol are
    never the only signal.
- **Guards:** W-1's cue test. A source test: `Image(systemName:` appears in `BatteryPulseWidget/`
  only inside `decorativeSymbol(_:)`, which applies `accessibilityHidden(true)`. The motion guards
  already cover the widget (`MotionGuardTests.swift:9-14, 168-216` per P2 §8.1). W-10 adds the
  time-text rules.
- **Acceptance:**
  - Both jobs green, with the label tests.
  - PNGs of every family and mode in the PR, for the look check.
  - The manifest lists the new families and cases.
  - Session R step 7's tree read matches the builder's labels.
- **Effort:** L, 3 runs. **Risk:** medium (look). **Rollback:** revert. Small and medium remain,
  and families can only be added later, so nothing frozen is lost.

### W-3c: Clicks open the matching page (P1)

- **Source:** P2 §8.9; HIG ("Ensure that a widget interaction opens your app at the right
  location");
  https://developer.apple.com/documentation/widgetkit/linking-to-specific-app-scenes-from-your-widget-or-live-activity;
  the §2.2 rows for W0-4 (4) and (5).
- **Items:**
  1. **`SidebarItem` maps to and from W-1's `PageID`.** `storageKey` returns `page.rawValue` (every
     case has a `PageID`, `developer` and `demo` included), and `SidebarItem` stays a plain enum:
     REJ-12 rejected making it `RawRepresentable`. A widget never routes to `developer` or `demo`
     (W-1 item 8).
     `@SceneStorage("mainSelection")` keeps the same strings (`MainView.swift:105`).
  2. **The app delegate handles clicks,** never a scene modifier. The agent app (`LSUIElement`,
     `build-app.sh:129`) usually has no window (P2 §8.9).
     - `AppDelegate.application(_:open:)` takes the URL, through `WidgetRoute(url:)`. Session A
       saw exactly this: the `widgetURL` arrived there, with no window open and with the main
       window open (§2.2 W0-4 (4), (5)).
     - **The activity route too:** a click on a widget body without a `widgetURL` arrived in
       Session A as an `NSUserActivity` whose type is the intent's type name
       (`SpikeWidgetIntent`), with the family and kind keys in its user info and no `webpageURL`
       (§2.2 W0-4 (4)). So `application(_:continue:restorationHandler:)` takes it through
       `WidgetRoute(activityType:)` (W-1 item 8): the kind's natural page without a
       configuration, since the activity carries none we read, and `false` for any other type.
       Every widget still sets exactly one `widgetURL` (W-3a item 6), so this is the fallback for
       a click the URL misses; it brings back P2 §8.9's handler for a kind-only click.
     - Each click logs how it arrived (`url` or `activity`) and its page as case names (§11),
       never a URL or the activity's values.
     - The app never imports App Intents (REJ-60), so `widgetConfigurationIntent(of:)` isn't used.
  3. **`WindowOpener.showMainWindow(page:)`** (`App/AppSettings.swift:222-238`):
     - A click with a page opens the main window at that page, because the compact window has no
       pages (Q7-6).
     - The page passes through an `@Observable` request, the way `DemoController.pageRequest` does
       (`MainView.swift:238`).
     - **The request stays pending until it is consumed.** The usual click finds BatteryPulse not
       running or without a window (the widget works without the app, UG:419).
       `WindowOpener.openWindow` is captured only when a view appears (`AppSettings.swift:222-238`,
       `MenuBarLabel.swift:66`), so a URL delivered at launch can find it nil. MainView applies
       `pageRequest` only in `.onChange` without `initial:` (`MainView.swift:238`), so a MainView
       created after the request restores the `@SceneStorage` page instead. So MainView applies the
       request in `.onChange(…, initial: true)` and clears it, and `WindowOpener` retries the open
       once `openWindow` is captured.
     - A device page whose device was forgotten opens the Devices intro.
  4. **No URL scheme is registered** (G7-9): the app's Info.plist (`build-app.sh:111-132`) gains no
     `CFBundleURLTypes`. Session A's click arrived with the `batterypulse` scheme unregistered, so
     WidgetKit hands the URL to BatteryPulse without one, and no other app or web page can open a
     BatteryPulse page. The route's `batterypulse://page/…` strings (W-1 item 8) are still frozen
     (§7.3), and a link never acts.
     - Only if Session R step 8 shows a click with BatteryPulse quit opening nothing is a
       navigation-only scheme registered before release (G7-9).
- **Linux tests:** `WidgetRoute` (W-1), and a source test that `PageID` equals `storageKey`'s
  literals (W-1's pin).
- **Guards:** `SecurityGuardTests` gains a placement: `application(_:open:)`,
  `application(_:continue:restorationHandler:)`, `onOpenURL` and `handlesExternalEvents` appear
  only in `App/BatteryPulseApp.swift` (the delegate), and
  `CFBundleURLTypes` nowhere in `scripts/build-app.sh` unless G7-9 adds it (a plain-text read of
  the script, as `HistoryTests.swift:251-256` reads it for the bundle ID, since `SourceScanner`
  covers only the Swift files of `Sources/`).
- **Files:** `Sources/BatteryPulseApp/App/BatteryPulseApp.swift`, `App/AppSettings.swift`,
  `Main/MainView.swift`, `Tests/BatteryCoreTests/SecurityGuardTests.swift`.
- **Acceptance:**
  - Both jobs green; the CI launch smoke.
  - Session R step 8: a click opens the right page with BatteryPulse quit, with no window open,
    with the main window open, and with Window to open set to compact, and each click's route is
    recorded.
- **Effort:** M, 2 runs. **Risk:** medium (activation of an agent app with no window; Session A saw
  the app come forward with `active=true`).
- **Rollback:** revert. A click then just opens the app, as in 0.6.1.

### W-8: The Accessories widget (P1: W0-4 (1) passed; G7-8)

- **Source:** P2 §8.4, §8.5 (Accessories), §8.8; INV FEA-09, FEA-21; W0-4 (1): Session A's
  sandboxed widget read the accessory batteries itself ("sources=2 accessories=1", §2.2).
- **Items:**
  1. **`AccessoriesWidgetIntent`** with `AccessoryWidgetMode`: All, sorted lowest first (the
     default), or Lowest only.
     - The parameter shows only in medium and large (`When(widgetFamily:)`).
     - Small always shows the lowest: the lowest `AccessoryBattery.level`, which leaves out the case
       and offline parts (`Accessory.swift:168` per P2 §8.5).
     - Earbuds appear per part, as the app shows them.
  2. **FEA-21 "Hide fully charged":** a Bool parameter, default off (Q7-5, decided by delegation:
     offered). It is declared before D1, because adding it later may reset placed widgets'
     choices [unverified; Session R step 4.4 measures it on the Battery kind]. The look check
     signs off its words (§6.1 question 9), and it is cut fourth if the budget runs short (§7.2).
  3. **Kind `io.github.nikitausov.BatteryPulse.accessories`,** families small, medium and large.
  4. **The read:** one-shot `MacAccessoryProvider.read()` through a second `WidgetReadCache`.
     - Never `observeChanges(` and never `AccessoryMonitor`, which registers the notify keys
       (P2 §8.8).
     - The app's read takes 0.30 ms at p50 (P2 §2.1, `accessory.read`).
     - `MacAccessoryProvider` is `@MainActor` (`BatterySource/MacAccessoryProvider.swift:17-19`), and
       WP-14a makes only the battery read nonisolated (P2 WP-14a item 1). So the read hops to the
       main actor once per burst (`MainActor.run { MacAccessoryProvider().read() }`) from the
       cache's `@concurrent` function. Making it nonisolated is a separate BatterySource change,
       not in 0.7.
  5. **Names** get `.privacySensitive()`.
     - Never `AccessoryBattery.id` anywhere in the widget: it can be brute-forced back to a
       Bluetooth address (`Accessory.swift:120-130`).
     - The MVP's only entity is W-3a's Details list of fields, so no accessory identifier enters a
       configuration.
  6. **Empty states:**
     - "No accessories with batteries connected", which opens Accessories.
     - When the lowest one goes away, the next lowest shows.
  7. **Gallery previews** come from `DemoAccessories` when none is connected.
- **Guards:** a source test: the widget target calls `MacAccessoryProvider`'s `read()` and never
  `observeChanges(` or `AccessoryMonitor` (P2 §8.8). The `dlsym` lookup stays in the allowed file
  (`SecurityGuardTests.swift:46-52`).
- **Files:** `Sources/BatteryPulseWidget/*`, `Resources/Localizable.xcstrings`,
  `scripts/widget-manifest.json`, `Sources/BatteryCore/Widget/*` (the accessory plan), the tests.
- **Acceptance:**
  - Both jobs green.
  - The PNGs, for the second look (§6.1b).
  - Session R step 9: a disconnect shows within a minute of the reload request [estimate]. W-4
    reloads on a disconnect at once, with no 15-minute wait.
- **Effort:** M, 2 runs. **Risk:** medium. A private source (`IOPSCopyPowerSourcesByType(4)`) may
  change in a macOS 27.x update; the empty state covers it (RD §7).
- **Rollback:** revert before D1. Once shipped, the kind is frozen.

### W-12: The session script, `perf-stats` per kind, the quick check (P1)

- **Source:** P2 WP-21 and §6 (the script's structure); RD NEW-22; INV ENG-17, QUA-16.
- **Items:**
  1. **`docs/plans/0.7.0/m5-session.sh`,** built from 0.6.2's script (D-11: its copy at this very
     path, or the 0.6.2 release PR's history): `prepare`, `backup`, `restore`, the swap helper,
     `send`, `day-start`, `day-end`, and the steps of §6.
     - **0.6.2's hands-free mode, reused** (P2 WP-21; the maintainer's request of 2026-10-23):
       `ui.swift` with its safety rules, `frames.swift`, `preflight` and its proofs, the `arm`
       window, `restore` split into `gui` and `end` halves working from `changes.tsv`, the
       heartbeat, the judgments with pixel checks, the privacy lint in `send` (to
       `claude/070-session-r`, `sessions/R.md`), and the "not checked" fallbacks. The runbook is
       `docs/plans/0.7.0/SESSION-R.md`, built from 0.6.2's `SESSION-B.md` with its rules and
       privacy, plus §6.2's steps and a section per short session (Charge limit, Hold watch and
       After publishing; §6.2, "The short sessions"). What Session B's Appendix C rows show (the
       proofs, the not-valid runs, the `log stream` across sleep, the mode's cost) is applied here
       before D1.
     - **Long calls** (a runbook rule): the Bash tool stops a call after 10 minutes, so a call
       expected to take over 2 minutes passes `timeout: 600000` (step 2's 5-minute shots), and
       anything near 10 minutes or longer runs as a background task the session waits on
       (`count-check`'s 10-minute wait, the charge-limit's wait for the hold and its 10 minutes at
       100 %, F12's wait for the rate limit, `hold-watch`'s night).
     - **New `ui` uses for 0.7's steps:** the gallery's click-to-add and a slow `ui drag` (step 3),
       the edit sheet's controls by computer use with the choices fixed by rule (step 4), the
       clicks at the widgets' hit-tested frames (step 8), the tree read of each widget's subtree
       (step 7), and the Bluetooth disconnect by an AX press (step 9).
     - **Session A's lessons** (Appendix C), kept or fixed here if 0.6.2's script didn't:
       - every swap ends the widget extension first and waits for it (`56702f9`), as 0.6.2's
         installer does (D-17), and logs the extension's pids before and after the swap and any
         CHSErrorDomain 1103 line, for G7-2;
       - log counts leave out ndjson's closing summary line (`9a32e57`);
       - `pmset -g accps -xml` writes one property list per source back to back, so the script
         splits its output before counting (Session A's F5 table read only the first and said
         "not a list");
       - a screen recording stops only by `screencapture -v -V <seconds>`: SIGINT or the end of
         its input loses the movie;
       - no `System Events` window query (Session A's made macOS ask for Accessibility for
         Terminal): windows come from CGWindowList and AX, through `ui`. Accessibility for
         Terminal is the one grant he may have revoked (Screen Recording and Automation stay from
         Session A, P2 §6), kept from Session B or asked again by preflight while the maintainer
         is there, and `restore` reminds him that he may revoke it at the end of the series;
       - `prepare` reads the Charge Limit with `pmset -g battlimit` on the adapter (no IOKit key
         holds it, and `battlimit` holds the limit only on AC, below it too, Appendix C finding
         9), else a shot of System Settings → Battery. A
         step changes it only on his yes, by computer use (or by his hand at two beeps if the
         slider asks for a password), at most 10 minutes at 100 %, and `restore` confirms it is
         back.
     - **`charge-limit`** (QUA-05): not needed for W-14, since the final `A.md` brought the
       redacted capture and the 100 % diff (D-13). W-12 still builds it, because 0.8's FEA-35
       check reads the number's candidates with it, at the limit on AC and then on battery (RD
       §3.3), building `bpulse` from the checkout if `prepare` hasn't (v0.6.2's `--record` is
       enough). It runs from a short local session with computer
       use, as Session R does (its start line and sentence: §6.2, "The short sessions"): the
       maintainer starts it and says yes, with the adapter in, and gives his yes before `send`
       when he is back (about 2 minutes in all). It reads the limit with `pmset -g battlimit` on
       the adapter (which holds it below the limit too, and nothing on battery, Appendix C finding
       9), else from a shot of System Settings → Battery → (i) next
       to Charging, and checks that the charge is at least 5 points below it, so it runs after a
       discharge. It then starts `caffeinate -i .build/release/bpulse --record` into a new, empty
       folder under `~/bp-070/` (UG:579-583: `caffeinate -i` keeps the Mac awake, and the folder
       must not hold an earlier recording), and says whether `NotChargingReason` gained bit 24 when
       charging stops at the limit (as in Session A's reads, W-14). Then the session sets the limit
       to 100 % by computer use in System Settings → Battery → (i) next to Charging → Charge Limit
       (Apple's path, https://support.apple.com/102338 [unverified on macOS 27]), for at most 10
       minutes, and back, confirmed by `pmset -g battlimit` or the same shot. If Session B recorded
       that the slider asks for a password or Touch ID (P2 §6, the start's question on the slider),
       the session never moves it: he moves it at the session's two beeps, to 100 % and back (+1
       min). The script prints the `NotChargingReason`, `IsCharging`, `FullyCharged` and charge rows
       around each change.
     - **`hold-watch`** (QUA-06): the same recording overnight under `caffeinate -i`; in the
       morning it says whether an optimized-charging hold was seen (R:76-77) [uncertain: whether
       macOS holds the charge while the Mac is kept awake].
     - **`count-check`** (W-13; §6.4 step 6): after "Quit BatteryPulse", it clears
       `lastCountedVersion` and `lastUpdateCheck`, back-dates `versionFirstLaunch`, opens
       BatteryPulse again, waits for W-13's `update` log line and, 10 minutes later, runs
       `scripts/release-stats.swift`.
     - Fresh backups go to `~/bp-070/R`.
     - It records the Icon & widget style, Dim widgets on desktop, the appearance, the language, the
       24-hour setting, Open at login and BatteryPulse's Check for updates, reading them as 0.6.2's
       prepare does; a value it can't read is "unknown" and never changed.
  2. **`scripts/perf-stats.swift`:**
     - `widget.timeline` intervals per kind per process;
     - `widget.reload` events per trigger;
     - **delivered against requested per kind over the logged day:** a request counts as
       delivered when a `widget.timeline` of that kind follows before the next request. WidgetKit
       may postpone reloads of a widget nobody can see until it becomes visible
       (https://developer.apple.com/documentation/widgetkit/keeping-a-widget-up-to-date), so a
       delay isn't a refusal. It also reports the median delay;
     - its fixtures `scripts/perf-sample.ndjson` and `.expected`, which CI checks (P2 WP-14b
       Files).
  3. **`scripts/quick-check.sh` (NEW-22), about 5 minutes after each macOS 27.x update:**
     - Devices, Accessories, Raw Data and the widget, with "y = looks right" questions;
     - `bpulse --accessories --raw` and `pmset -g accps -xml` side by side, when `bpulse` is built,
       counting pmset's back-to-back property lists one per source;
     - `NotChargingReason` from `bpulse --json`, so a macOS 27.x update that moves the Charge
       Limit's bit shows (W-14).

     It lives in `scripts/`, not in the plan folder, because it outlives 0.7.
  4. **ci.yml:** `bash -n` for both scripts. The plan script's line goes with the folder at D3.
- **Effort:** M, 2-3 runs (1-2 before the hands-free mode; it adds `SESSION-R.md` with its short
  sessions, the new `ui` uses, the split `restore` and the arm window's step-12 duties). **Risk:**
  none to users.

### W-14: The Charge Limit's "Charged to limit" state (P1; the maintainer's request, 2026-10-23; G7-18)

- **Source:** the maintainer's request after Session A's capture (2026-10-23: show the Charge Limit
  in the app, the menu bar and the widget; §14 Q7-10); Session A's findings 7 and 9 (9: the number's
  candidates and the 100 % diff, final in its `A.md`) and the Charge Limit research of 2026-10-23
  (Appendix C); INV FEA-35 (added 2026-10-23: the state in 0.7, the number in 0.8, RD §3.2, §3.3);
  QUA-05, now captured (D-13); RD NEW-01 (0.8, "Why it isn't charging"), whose
  Charge Limit cause this takes early; FEA-20 (1.1, the widget field), whose Charge Limit part this
  takes early; M-3 (BatteryPulse never sets a limit); Apple's support article on the Charge Limit
  (https://support.apple.com/102338: Apple silicon with macOS 26.4 or later; System Settings →
  Battery → (i) next to Charging → Charge Limit, 80-100 % in steps of 5; the battery menu reads
  "Charged to [%] Limit"; charging resumes after a drop of more than 5 %; an occasional charge to
  100 %; Charge to Full Now).
- **Why 0.7, not 0.8:**
  - **For 0.8:** NEW-01 is 0.8's theme, with its own look sitting and Russian review; the bit rests
    on one capture from one Mac; and the widget field is a frozen raw value.
  - **For 0.7:** the maintainer asked for it explicitly; the cause now has the real capture that
    NEW-01's rule asks for ("a cause shows only when a real fixture proves it"); it reads only keys
    the parser reads today (`notChargingReason`, external power, the charge state), in about 2
    runs; and the widget's field list first ships in 0.7, so the field ships with it.
  - **So 0.7 takes only this state.** NEW-01 keeps the optimized hold, heat and a weak adapter for
    0.8, and builds on W-14's type; the configured percentage is FEA-35's second half, beside it in
    0.8 (RD §3.3); FEA-20's other causes stay in 1.1.
- **What the capture shows** (Session A, 21:37, the limit set to 80 % in System Settings):
  `ChargerData.NotChargingReason` 0 → 16,777,216 (0x01000000, bit 24) in AppleSmartBattery and in
  its child AppleChargerData; `ChargingCurrent` 2,626 → 0; `IsCharging` 1 → 0; `ExternalConnected`
  Yes; `FullyCharged` No; the SMC's `B0AC` and `B0AP` → 0. No key holds the limit itself: 80 appears
  in none of `bpulse --raw`, three `ioreg` dumps, `pmset -g` and `pmset -g batt`, and the Mac's
  battery has no `ChargeLimit` or `OptimizedCharging` key ("Optimized Battery Charging Engaged"
  exists only in the AirPods' entries).
- **What the final `A.md` adds** (Appendix C finding 9): at the hold, `IPDChargingAllowed` 0 and
  `ChargerInhibitReason` 0. **The 100 % diff:** with the limit raised to 100 %, `NotChargingReason`
  read 0 in both places (bit 24 cleared), `IsCharging` 1, `ChargingCurrent` 2,626 and
  `IPDChargingAllowed` 1, and the charge rose; set back to 80 % with the charge at 83 %, bit 24
  returned with `IsCharging` 0, `ChargingCurrent` 0, `IPDChargingAllowed` 0 and
  `ChargerInhibitReason` 0x10001000. So bit 24 is the hold's cause; `IsCharging`, `ChargingCurrent`
  and `IPDChargingAllowed` follow it, and `ChargerInhibitReason` doesn't. **After a plug-in** 8
  points below the limit (72 %), `NotChargingReason` read 128 (bit 7), not bit 24, with no charging
  for the first read; then the Mac charged to 80 % and held there.
- **What 0.7 shows, and what it doesn't:**
  - **The "at limit" state only.** BatteryPulse says the limit was reached, never which limit, and
    never infers that the Charge Limit is off: at 100 % and on battery every candidate source looks
    the same (Session A: no policy in powerd's plist or `battlimit`, and `prior.limit` 80, in
    both).
  - **No ring or battery marker:** the number is unknown, and the widget knows only the current
    charge, so a tick would sit exactly at the end of the fill: an end stop, not a limit marker.
  - **No menu bar icon change:** a tick is unreadable at that size, and macOS's own battery item
    already says it.
  - **`bpulse` unchanged:** `--json` already carries `notChargingReason`, and the text report keeps
    its hex line (`BatteryReport.swift:78-79`), so D1's golden diff stays S-1's.
- **Items:**
  1. **`SystemChargeLimit` in BatteryCore** (a new `Sources/BatteryCore/SystemChargeLimit.swift`).
     The name, and the `systemChargeLimit` names below (the widget field, the Demo scene, 0.8's
     `systemChargeLimitPercent`), keep it apart from the app's own notification threshold,
     `AlertSettings.chargeLimit` and `.chargeLimitReached` ("When charged to",
     `BatteryAlerts.swift:6, 17`): no new identifier is a bare `chargeLimit`, and the words differ.
     - `SystemChargeLimit.heldBit = 0x0100_0000`, bit 24 of `NotChargingReason`, citing the
       capture;
     - `BatterySnapshot.isAtSystemChargeLimit`, a computed property in the same file: the bit is set,
       `isExternalPowerConnected == true`, `chargeState == .notCharging` and
       `isOptimizedChargingEngaged != true`. The SMC plug-in rule (`MacPowerParser.swift:182-188`)
       runs first and turns a measured charge current into `.charging`, so it wins;
     - **no new `ChargeState` case:** `ChargeState` is `Codable` in History and in `bpulse --json`
       (`BatterySnapshot.swift:162`), both frozen (PB §3.4);
     - **precedence,** which the last condition encodes: with `isOptimizedChargingEngaged == true`
       as well (never seen together; the M5 reports that flag for no battery of its own), the
       optimized hold's "Charging on hold" wins, and neither Power's row nor the widget field
       shows: the flag names its cause, while bit 24 may be shared (QUA-06, Risks).
  2. **One state phrase for the app, the popover and the widget:** W-1's `WidgetStateWord` gains
     `chargedToLimit` from the same property, and the app's `Phrases.state(_:)`
     (`App/Localized.swift:28-33`) maps the same decision to "Charged to limit": Apple's
     battery-menu wording ("Charged to [%] Limit") without the number it can't read. The run
     decides whether the app adopts the BatteryCore enum, so the two can't drift apart.
  3. **The app:**
     - **Overview:** the state line reads "Charged to limit", and below it "Charging stopped at the
       Charge Limit set in System Settings → Battery." (NEW-01's pointer; M-3);
     - **Power:** the State row (`Main/PowerView.swift:36`) reads the same, and a new row "Charge
       limit: Reached" shows while the limit holds. Why "Reached" and no percentage: macOS stops
       within a few points of the limit and resumes only after a drop of more than 5 %, so the
       current charge in that row would read as the limit;
     - **the menu bar popover and the compact window:** their state line, through
       `Phrases.stateWithPower` (`MenuBar/PopoverView.swift:149`, `Main/CompactView.swift:72`);
     - **the menu bar icon and label** don't change;
     - **motion:** the state line's change and Overview's new sentence move with `BatteryMotionKey`,
       which gains `isAtSystemChargeLimit` (`BatteryMotion.swift:64-119`), because the hold can
       start with no `chargeState` change (item 6); never keyed on `snapshot` (CL motion);
     - **Raw Data decodes bit 24 as the Charge Limit's hold:** `NotChargingReason`'s glossary line
       (`RawKeyGlossary.swift:543`) keeps "Apple does not document the bits" and adds that bit 24
       is set while the Charge Limit holds the charge, beside the set bits the table already lists
       (`RawValueDecoding.swift:78-80`).
  4. **Demo Mode:** a `DemoScenario.systemChargeLimit` scene (80 %, the 60 W adapter, no current,
     `NotChargingReason` 0x01000000 where `DemoBattery.swift:112` sets it today), with its tone,
     title ("Charge limit"), detail (Overview's sentence) and symbol (`DemoController.swift:281,
     294, 311, 328`) and a tour step on Overview (`DemoController.swift:25-41`), so the look is
     reviewed without the real state. Scenes aren't stored, so the case is free to add. The widget
     reads the real battery, not the demo, so its look comes from CI's PNGs.
  5. **The Battery widget, after W-3b and W-8:**
     - **the state line** reads "Charged to limit" in every layout, Automatic included: an intended
       difference from 0.6.1 in that state (§7.3);
     - **the field** `BatteryWidgetField.systemChargeLimit` (raw value `systemChargeLimit`, frozen;
       in the manifest, Details' entity ids and `WidgetSurfaceTests`), labelled "Charge limit" and
       valued "Reached", shown only while the limit holds (W-1's plan drops unavailable values).
       Offered in Custom's Details; not in Automatic's detail lists (§6.1 question 2's eight stay).
       Its meaning is frozen, its value text isn't: 0.8 can show the percentage in the same field;
     - **accessibility:** the charge element's label takes the state word (W-3b item 5's builder);
     - **no marker** on the ring or the drawn battery, and **no attention row**: the user chose the
       limit.
  6. **Reloads: one reason added to W-4's planner.** The hold usually starts and ends with a change
     of `chargeState` (charging → not charging and back), which today's policy reloads at once
     (`BatteryPresentation.swift:155-169`) and W-4's planner keeps. It can also start without one:
     plugged in at or up to 5 % below the limit, the state goes from discharging to not charging
     with bit 7 (0x80, as `m5-macos27-plugged-in-10s.plist` reads on AC), and bit 24 may follow
     with no state change [unverified within 5 % of the limit: Session A's plug-in at 72 %, 8 points
     below, read bit 7 (128) and not charging first, then charged, and the hold came at 80 %;
     Session R step 9 records it near the limit]. So the planner
     reloads at once when `isAtSystemChargeLimit` changes, a fifth reason under the 5-minute
     minimum W-4's four share (W-4 item 1).
  7. **Docs, W-14's own lines:** UG's Overview and Power text, and its notifications text: the
     app's "When charged to" alert never fires above a lower Charge Limit (a 90 % alert under an
     80 % limit); ROADMAP Stage 1's "a capture at the macOS Charge Limit stop point" (R:145-146)
     ticked with the committed fixture. RD's and INV's lines are already written on 2026-10-23
     (FEA-35, FEA-20, QUA-05, NEW-01, M-3, RD §3.2-§3.3); W-14's docs pass checks them against
     what shipped. CL's macOS 27 layout convention gains "bit 24 (0x01000000) of
     `NotChargingReason` is set while the Charge Limit holds the charge", and its Layout lists
     `SystemChargeLimit`; W-10 checks both against the code.
- **The fixture:** `Tests/BatteryCoreTests/Fixtures/m5-macos27-charge-limit.plist`, from the
  session's `bpulse --raw` capture at the 80 % hold, which came with the final `A.md` on the
  maintainer's approval (`docs/plans/0.7.0/sessions/A/charge-limit-80.plist`, 21:37; serials,
  manufacturer data and `MfgData` read REDACTED; no UDID or device name). W-14 checks it against
  the Fixtures README and commits it under that name, with a row in the README and a case in
  `Fixture.swift` (D-13); a plan folder goes at its release (D-1), so the fixture's copy is what
  ships. With the real capture in hand, no hand-edited stand-in is needed (NEW-01's rule). Only a
  capture that fails the README's check would move W-14 whole to 0.8 (G7-18).
- **BatteryCore decisions and Linux tests** (`Tests/BatteryCoreTests/SystemChargeLimitTests.swift`):
  - the fixture is at the limit, with bit 24 in AppleSmartBattery and in its child;
  - every other M5 fixture and both `synthetic-legacy-*` are not (`m5-macos27-charging` has reason
    0, the on-battery and just-plugged-in captures 0x80);
  - each condition alone ends it: the bit on battery, the bit with `.charged`, and the bit with an
    SMC charge current at or above the plug-in threshold (`.charging`);
  - bit 24 among other bits still means the limit; other bits without it stay "Not charging";
  - the optimized hold flag with bit 24 is not at the limit and reads "Charging on hold";
  - `WidgetStateWord` for each case, and the Demo scene's snapshot is at the limit by the same
    decision;
  - `BatteryMotionKey` differs when only `isAtSystemChargeLimit` changes;
  - the widget plan: `systemChargeLimit` is dropped when the limit doesn't hold and reads "Reached"
    when it does; `WidgetSurfaceTests` pins its raw value;
  - `WidgetTextBudget` covers the new keys in English and Russian, and `LocalizationCatalogTests`
    sees the old glossary line's key removed;
  - the reload planner: the hold's start reloads once, through the state change; a plug-in at 78 %
    under an 80 % limit, bit 7 and then bit 24 with no state change, gives one extra reload; and an
    hour at the limit adds no reload.
- **Keys (§8), listed in English only:** "Charged to limit" · "Charge limit" · "Reached" ·
  "Charging stopped at the Charge Limit set in System Settings → Battery." · the glossary line with
  its added sentence. Each lands with its Russian in W-14's commit (CL). The Russian follows Apple's
  Russian support article for the Charge Limit (https://support.apple.com/ru-ru/102338), which gives
  Apple's terms for Charge Limit, the battery menu's "Charged to [%] Limit" and Charge to Full Now,
  and System Settings → Battery's own string, verified in W-10's terminology pass; D-13's screenshot
  didn't come with the final `A.md`, so Apple's Russian article stands. Session R step 9b only
  confirms it, and a mismatch is a one-key fix forward before D3.
  The catalog's translation of "Charging on hold" (Optimized Charging's hold) is not reused for
  the Charge Limit.
- **Files:** `Sources/BatteryCore/SystemChargeLimit.swift`, `Sources/BatteryCore/Widget/*` (the
  state word, the field, the plan, the planner's reason), `Sources/BatteryCore/DemoBattery.swift`,
  `Sources/BatteryCore/RawKeyGlossary.swift` (one line), `Sources/BatteryCore/BatteryMotion.swift`
  (the key's flag), `Sources/BatteryPulseApp/App/{Localized,DemoController}.swift`,
  `Sources/BatteryPulseApp/Main/{OverviewView,PowerView}.swift`, `Sources/BatteryPulseWidget/*`,
  `Resources/Localizable.xcstrings`, `scripts/widget-manifest.json`, the fixture with its README row
  and `Fixture.swift`, `Tests/BatteryCoreTests/SystemChargeLimitTests.swift`, `CLAUDE.md` (the
  convention and Layout lines, item 7), `docs/USER_GUIDE.md` (Overview, Power and notifications
  only), `docs/ROADMAP.md` (Stage 1's line), `docs/plans/1.0/ROADMAP.md`,
  `docs/plans/1.0/INVENTORY.md` (both checked, item 7).
- **Guards:** none new. `MotionGuardTests` already covers the widget and the menu bar label, and
  the new line moves only with `BatteryMotionKey` (item 3).
- **Acceptance:**
  - Both jobs green, with the fixture test.
  - CI's PNGs of the widget's state line and field, for the second look (§6.1b).
  - Session R step 9b.
- **Effort:** M, 2 runs [estimate]. RD §3 and §3.2 count them beside the 28-31 (FEA-35); RD §3.3
  nets FEA-35's 0.8 number at +1-2 runs, since NEW-01's Charge Limit cause moved here.
- **Risks:**
  - **Bit 24 is undocumented.** It rests on Session A's reads on one M5 (bit 24 at each read of
    the hold, and its clearing at 100 %) plus public reports from other Macs,
    and a macOS 27.x update could move it. W-12's quick check (item 3) and Raw Data show it.
  - **Optimized Charging's hold may set the same bit** [unverified, QUA-06]. The M5 reports that
    hold's flag for no battery of its own, so IOPS can't tell the two holds apart; W-12's
    `hold-watch` records one.
  - **The app's own alert:** "When charged to 90 %" never fires under an 80 % limit; the guide says
    so (item 7).
- **Settled by the 100 % diff** (the final `A.md`, D-13; Appendix C finding 9): bit 24 clears and
  charging resumes when the limit is raised from 80 to 100 %, and it returns when the limit is set
  back to 80 %, so it is the hold's cause and W-14 stays in 0.7. The other keys: `IsCharging`,
  `ChargingCurrent` and `PowerDistribution.IPDChargingAllowed` follow bit 24, and
  `ChargerInhibitReason` read 0 at the hold and 0x10001000 when the limit was set back below the
  charge (the interim report had the charger's inhibit key showing charging inhibited at the
  hold). "Off" (100 %) looks like no limit: `NotChargingReason` 0 and charging, `pmset -g
  battlimit` "No battery level limits set" and no policy in powerd's plist. Still open: Optimized
  Charging's hold (QUA-06, Risks) and a plug-in within 5 % of the limit (item 6).
- **Rollback:** revert before D1. Once shipped, `systemChargeLimit` is frozen; if the bit changes
  meaning, a 0.7.x stops reading it, and the field shows nothing (dropped as unavailable).
- **The configured percentage, 0.8** (FEA-35's second half, RD §3.3, beside NEW-01; nothing of it
  in 0.7). No IOKit or IOPS key holds it (Session A; the research agrees). Session A's final reads
  (Appendix C finding 9) reorder the candidates: powerd's plist and `pmset -g battlimit` hold the
  limit's policy only while the Mac is on AC (both empty from about 5 minutes after unplugging,
  the policy back at plug-in), so they give the active limit, not the setting, and System
  Settings' `prior.limit` kept 80 on battery, so it gains, with its staleness caveat. Best first as
  known today:
  1. **powerd's charging preferences, read as a file, on AC:**
     `/Library/Preferences/com.apple.powerd.charging.plist` (root's, readable by everyone). The
     unsandboxed app reads it as a file: no `Process`, no private framework, no SMC. It holds
     `bootSessionUUID` and `policies`, an `NSKeyedArchiver` archive of `ChargeCtrlPolicy` objects
     with `soclimit` (80), `reason` (`manualChargeLimit`), `drain`, `isEndOfCharge`,
     `noChargeToFull`, `terminated`, `owner` and `token` (an `NSUUID`): the values `battlimit`
     prints. BatteryCore parses it on Linux as plain property lists: it walks the archive's
     `$objects` and `$top` generically and never instantiates the private class, tested with a
     redacted sample. **Only on AC:** powerd rewrote it with no policy about 5 minutes after
     unplugging and with the policy again at plug-in, and with no policy at 100 %. So on AC a
     policy is the active limit and no policy means no limit below 100 %; on battery it says
     nothing, and a missing policy there is unknown, never "off". The widget's sandbox can't read
     it. The format is private and undocumented, and a macOS 27.x update may change it.
  2. **System Settings' prior limit, on battery, with its caveat:** the user defaults domain
     `com.apple.batteryui.charging.mac` has one key, `com.apple.batteryui.charging.mac.prior.limit`,
     which read 80 on battery, while the plist and `battlimit` were empty, but also with the limit
     at 100 %. So it is the last limit set below 100 %, not proof that a limit is on: 0.8 may show
     it on battery only as the limit last set, and on AC the plist wins. It is System Settings' own
     record, so a change made elsewhere may leave it stale.
  3. **The SMC key `CHLT`:** inside the read-only SMC rule (CL: commands 5, 8 and 9 through selector
     2), so no new exception. Seen in one public dump from an M3 Air: it shows the active limit only
     and reads 00 on battery, the plist's AC-only answer through an SMC read. Present on the M5
     (`bpulse --smc` lists `CHLT` with 3 `hex_` bytes and `CHNC` with 8, not `CHLS`), its value
     still unread, since `--smc` prints names only. It needs a small, reviewed `bpulse --smc` value
     read of `CHLT` and `CHNC` first, because a few SMC keys change state when read (bpulse's own
     comment).
  4. **`pmset -g battlimit` through a `Process`:** the plist's policy as undocumented text (two
     entries, `chargeSocLimitSoc` 80, `chargeSocLimitReason` `manualChargeLimit` and the flags;
     "No battery level limits set" at 100 % and on battery), so now only the fallback if the
     file's format changes: a `SecurityGuardTests` exception (today only `UpdateInstaller` starts
     a process), run only when bit 24 changes or on plug-in, never on a poll, and only on AC.
  5. **The private PowerUI framework through `dlopen`:** the configured value in any power state,
     but it contradicts M-3 and needs a new `dlopen` exception; not recommended unless the maintainer
     reopens M-3.

  The sandboxed widget can't read the number itself; it gets it only through the feed (W-5: 0.7's
  stretch, else 1.1). 0.8 then adds a stored `systemChargeLimitPercent: Int?` (nil means unknown,
  never "off"; `--json` gains the key only when it is known), Power's "80 %" or "80 %, reached",
  the field's "80 %", and perhaps the marker, with its own look sitting.

### K-1: The backup release key, public half only (M-9: yes; conditional on the key existing)

- **Source:** RD NEW-13, M-9; CL ("Never ask for or handle the private key").
- **Items:**
  - The maintainer generates the key offline with `swift scripts/sign-update.swift --generate-key`
    (`--help` is the runbook; `sign-update.swift:9-14`) and posts only the public half in the PR
    (§14 M-9 has the steps).
  - K-1 adds it to `ReleaseSigning.publicKeys` (`ReleaseSigning.swift:15-17`).
  - `UpdateInstallTests` (:113-117, the only test that names `ReleaseSigning`) gains:
    `publicKeys.count == 2`, and it contains the new key.
  - `release.yml`'s key check is unchanged: it still checks that the secret's key is in the list.
- **Effort:** S, 1 run. **If the maintainer hasn't generated the key by C1:** moves to 0.8.

### W-13: The anonymous version count (P1; decided by the maintainer, 2026-10-22)

- **Source:**
  - the maintainer's decision of 2026-10-22 (§14 Q7-9): an anonymous version count, on by
    default, announced honestly, to learn how many people use which version;
  - NEW-23, which W-13 extends;
  - RD C14 item 8, the privacy promise W-13 changes, and items 1 and 6 (settings keys, the update
    contract), which it adds to;
  - CL "Network", "Logging" and "Energy";
  - Appendix B VC-1 to VC-8;
  - RD NEW-24; INV DIS-11.
- **Today** (at `eebf748`, Appendix B; file:line at v0.6.2):
  - **The schedule.** `startAutomaticChecks()` (`UpdateChecker.swift:66-76`) wakes 20 s after
    launch, then every 6 h with a 36-minute tolerance.
  - **When a tick checks.** Only when `UpdatePolicy.isCheckDue` says the chosen interval has passed
    and no rate limit holds (`:118-130`, `Updates.swift:190-265`). Never means no check.
  - **The check.** One GET of `api.github.com/…/releases/latest` with `User-Agent:
    BatteryPulse/<version>`, on `UpdateNetwork.automatic` (`:181-233`). That session is ephemeral,
    has no URL cache, and refuses Low Data Mode and expensive networks.
  - **The installer.** It fetches the `.sig`, then the DMG, through their `browser_download_url` on
    `UpdateNetwork.user`, following GitHub's redirect (`UpdateInstaller.swift:183-233`).
  - **Host rules.** `ReleaseLinks` filters only what the browser opens (`Updates.swift:175-188`).
  - **Guards.** `SecurityGuardTests` bans only `URLSession.shared` (`SecurityGuardTests.swift:53-59`).
- **What W-13 does:**
  - **When.** Once per installed version, at least 24 hours after that version first ran on this
    Mac. The trigger is an automatic update check that reached GitHub.
  - **The request.** That check also GETs
    `https://github.com/NikitaUsov/BatteryPulse/releases/download/v<installed>/BatteryPulse-count.txt`
    and ignores the body.
  - **The statistic.** Each release's count of that asset is the number of Macs that ran that
    version with automatic checks and the count on, the maintainer's Mac included. Nothing else is
    sent.
- **Decisions** (technical, so the plan decides them; the maintainer decided the count itself):
  1. **Once per version, not daily.**
     - A daily fetch counts days of use, weighted by each Mac's frequency (daily, weekly or
       monthly). It needs a series of readings to interpret, and it shows GitHub a daily signal
       from each address.
     - Once per version gives a number with one meaning. It is independent of the frequency and
       costs one request per Mac per version.
     - What it can't show is who still runs an old version. The next version's count shows who
       stayed and who updated.
  2. **One asset per release.** Rejected alternatives:
     - one asset per version on a permanent pre-release: clutters Releases and changes an old
       release every time;
     - `releases/latest/download/…`: loses the version;
     - fetching one's own `.sig`: mixes with NEW-23's proxy for in-app installs;
     - API traffic: owners can't see it;
     - our own server, or an outside service: excluded by the maintainer.
  3. **A plain GET that follows the redirect.** This is GitHub's documented download, and the same
     request the installer already makes for the `.sig`. HEAD, or stopping at the redirect, would
     rest on undocumented behaviour (VC-2).
  4. **Riding on the automatic check.** The count runs in `check(userInitiated:)` (`:132-161`) [v0.6.2:
     `check(_:)`, the automatic check in a task of its own, E10], on
     the success path after `recordCheck()` (`:152`), once the offer is decided (`:154-160`), so a
     window waiting on the check never waits for the count:
     - same task, awaited on `UpdateNetwork.automatic`, inside `update.check`'s interval;
     - no new task, sleep, timer or signpost name;
     - it inherits the session's refusal of Low Data Mode and expensive networks;
     - Check Now never counts.
  5. **Grace day.** `versionFirstLaunch` is written when `lastSeenVersion` changes
     (`BatteryPulseApp.swift:57-60`). No count happens until 24 h after it, so the off switch comes
     before the first count.
  6. **No cookies, for all update traffic** (VC-5). Set `httpCookieStorage = nil`,
     `httpShouldSetCookies = false` and `httpCookieAcceptPolicy = .never` on both `UpdateNetwork`
     configurations.
  7. **Headers.** Two, both pinned:
     - `User-Agent: BatteryPulse/<version>`, the same as the check;
     - a constant `Accept-Language: *`, so the request carries no language setting.
  8. **Outcomes:**

     | Answer | What happens |
     |---|---|
     | 200 | counted; marked |
     | 404 | no counter; marked, logged at debug. This is a release without the asset, or a build with no tag, such as RC-U's 0.6.99 |
     | anything else (403, 429, 5xx, a transport error, a cancel) | not marked; tried again at the next due automatic check, with no extra retry |

  9. **Where the setting lives.** In Settings → General, because the Welcome window embeds General
     (`WelcomeView.swift:32-34`), so fresh installs see it at first launch. While Check for updates
     is Never, the toggle is disabled and keeps its value.
  10. **Default on, never written.** A missing key means on, and only the toggle writes it. A later
      release can change the default for everyone who never chose.
- **Items:**
  1. **BatteryCore:**
     - a new file, `VersionCounter.swift`:
       ```swift
       public enum VersionCounterPolicy {
           public static let isOnByDefault = true
           public static let gracePeriod: TimeInterval = 24 * 60 * 60
           public static let introducedIn = AppVersion(parts: [0, 7, 0])
           public static func isEnabled(stored: Bool?) -> Bool
           public static func shouldCount(enabled: Bool, frequency: UpdateFrequency, current: AppVersion,
               lastCounted: AppVersion?, versionSince: Date?, now: Date) -> Bool
           public static func url(for version: AppVersion) -> URL?        // nil unless x.y.z and not 0.0.0
           public static func headers(for version: AppVersion) -> [String: String]
           public enum Outcome: String, Sendable { case counted, noCounter, failed }
           public static func outcome(statusCode: Int?) -> Outcome
           public static func marksCounted(_ outcome: Outcome) -> Bool
           public static func showsAnnouncement(previous: AppVersion?) -> Bool   // previous < 0.7.0
       }
       ```
     - `ReleaseChannel.counterAssetName = "BatteryPulse-count.txt"`, plus `releaseAsset(_:of:)`
       building `…/releases/download/v<x.y.z>/<name>` from `repository`.
  2. **`UpdateNetwork`:** no cookies (decision 6). Its doc comment says so.
  3. **`UpdateChecker`:**
     - the count on the automatic success path;
     - it reads and writes `lastCountedVersion`;
     - log lines through `Diagnostics.update`, using only the outcome's case name and the HTTP or
       `URLError` code as `.public`, never the URL or an error description: counted at `.info`,
       noCounter and failed at `.debug`;
     - the type's doc comment (`:9-14`), "The only network request BatteryPulse makes on its own…",
       is rewritten.
  4. **`AppSettings` and `BatteryPulseApp`:**
     - three keys: `anonymousVersionCount` (Bool, on when missing), `lastCountedVersion` (String
       `x.y.z`) and `versionFirstLaunch` (Date);
     - `versionFirstLaunch` is written in the existing `lastLaunched != current` branch;
     - the previous version is captured for What's New.
  5. **Settings → General:** a new section right after the update section
     (`GeneralSettings.swift:79-99`). It holds the toggle and its footer, and is
     `.disabled(updateFrequency == .never)`.
  6. **What's New:**
     - 0.7.0's list includes "Anonymous version count".
     - Later releases append that row whenever `showsAnnouncement(previous:)` is true, so a jump
       from 0.6.x straight to 0.8 still announces it.
     - W-10 composes the final list and keeps the row.
  7. **Release:**
     - a new `.github/BatteryPulse-count.txt` of at most 1 KB, ASCII, English, saying what it is for
       and how to turn the count off;
     - `release.yml` attaches it (see `release.yml` below);
     - `scripts/release-stats-sample.json` and `.expected` gain a release with
       `BatteryPulse-count.txt`, so CI's diff covers a filled Count column (0.6.2's sample has
       none, WP-19).
  8. **Docs:** listed below.
  9. **Strings:** listed below.
- **Files:**
  - `Sources/BatteryCore/VersionCounter.swift` (new) and `Sources/BatteryCore/Updates.swift`
    (`ReleaseChannel`);
  - `Sources/BatteryPulseApp/Updates/UpdateChecker.swift`, `Updates/UpdateViews.swift`
    (`WhatsNew`);
  - `App/AppSettings.swift`, `App/BatteryPulseApp.swift`, `Settings/GeneralSettings.swift`;
  - `Resources/Localizable.xcstrings`;
  - `.github/BatteryPulse-count.txt` (new), `.github/workflows/release.yml`;
  - `scripts/release-stats-sample.json`, `scripts/release-stats-sample.expected`;
  - `Tests/BatteryCoreTests/VersionCounterTests.swift` (new), `SecurityGuardTests.swift`;
  - `README.md`, `docs/USER_GUIDE.md`, `docs/ROADMAP.md`, `docs/plans/1.0/ROADMAP.md`, `CLAUDE.md`.
- **Linux tests** (`VersionCounterTests`):
  1. On when the stored value is nil; off when it is false.
  2. Never gives no count; daily, weekly and monthly count.
  3. Off gives no count.
  4. Once per version: `lastCounted == current` gives false, and 0.7 equals 0.7.0. 0.7.0 → 0.7.1
     gives true.
  5. Grace:
     - 23 h 59 min gives false; 24 h gives true;
     - a nil `versionSince` gives false;
     - `versionSince` in the future (the clock moved back) gives true, as `isCheckDue` does.
  6. 0.0.0, two-part and four-part versions give a nil URL and no count.
  7. The exact URL for 0.7.0 and 1.2.3.
  8. Outcomes and `marksCounted`:
     - 200 → counted, marked;
     - 404 → noCounter, marked;
     - 403, 429, 500 or nil → failed, not marked.
  9. The headers are exactly `User-Agent` and `Accept-Language`.
  10. `showsAnnouncement`: nil → false; 0.6.2 → true; 0.7.0 → false.
  11. The release workflow attaches the file:
      - `release.yml`'s `gh release create` names `.github/BatteryPulse-count.txt`;
      - the file exists, is 1-1024 bytes and ASCII;
      - its basename equals `counterAssetName`.
- **Guards** (`SecurityGuardTests`, with `catches` cases):
  - **A new session only in `UpdateNetwork`.** `\bURLSession\s*\(` is allowed only in
    `UpdateNetwork`'s file (`Updates/UpdateChecker.swift`), at most 2 matches; those are its two
    sessions today (:216, :219). With `.shared` already banned, every request goes through them.
  - **The count's URL in one place.** `\bVersionCounterPolicy\s*\.\s*url\b` is allowed only in
    `UpdateChecker.swift`, once.
  - **No cookies.** A test checks that `UpdateNetwork`'s blanked source sets `httpCookieStorage =
    nil`, `httpShouldSetCookies = false` and `httpCookieAcceptPolicy = .never`.
  - **Energy.** `EnergyGuardTests` stays as it is: no new sleep or exception, and `oneShots` stays
    at four.
  - **Logs.** The review checks the log lines against CL "Logging" until NEW-12's guard exists
    (0.8).
- **Strings** (English keys; each added with its Russian in the catalog, in the same commit, in
  the catalog's own terms for Check for updates, Never, Settings → General, a release and a
  download):
  - Toggle: "Include this Mac in the anonymous version count"
  - Footer: "Once per version, at least a day after you start using it, an automatic update check
    also downloads a small file from that version's release on GitHub. Its public download count
    shows how many Macs use each version. Nothing else is sent: no identifier and nothing about
    this Mac, its battery or your settings. Nothing is counted when Check for updates is Never."
  - What's New title: "Anonymous version count"
  - What's New detail: "Once per version, BatteryPulse downloads a tiny file from GitHub, so its
    download count shows how many Macs use each version. No identifier and nothing about your Mac
    is sent; GitHub sees only what it sees for the update check. Turn it off in Settings →
    General."
- **`release.yml`:**
  - **Before building:** check that `.github/BatteryPulse-count.txt` exists and is 1-1024 bytes.
  - **Publish:** add it to `gh release create` (`release.yml:151`); the asset is named after its
    basename.
  - **After publishing:** `gh release view "v$VERSION" --json assets` must list it. If not,
    `::error::` names the fix, `gh release upload "v$VERSION" .github/BatteryPulse-count.txt`. No
    Mac counts within 24 h of first running a version, so there is time to fix it.
  - **A comment:** the file is the version count's asset and must never be removed from a published
    release.
- **Docs** (§12 lists them with the other packages' rows):
  - **README:** RM:120-125 ("The only requests to the internet are…") is reworded, and a new
    "Privacy" section holds §11's statement.
  - **USER_GUIDE:**
    - UG:502-509 is reworded: the check, the count and a download you chose.
    - A new "Privacy" section holds §11's statement.
    - The devices' "Privacy" (UG:351-359) links to it.
  - **ROADMAP and RD:** already written on 2026-10-22: ROADMAP's Decisions "Privacy (0.7)", the
    Principles' Privacy line and the usage paragraph; RD C14 items 1, 6 and 8, §1.1, §1.2 item 6,
    §3, §3.2 and §3.3, §4.3's Telemetry row, NEW-23, NEW-24 and M-11. W-13's docs pass checks them
    against what shipped and adds only the Releases table's Count column and the "Road to 1.0"
    lines (for C14 items 1, 6 and 8; R-1 item 4).
  - **CL:**
    - "Network" gains the count and "no cookies".
    - Layout lists `VersionCounter`.
    - Releases names `BatteryPulse-count.txt`.
  - **Release notes:** §13 step 2's line.
- **Acceptance:**
  - Tests green on Linux; the macOS job green with 0 warnings and within the size budget.
  - CI's `release-stats.swift --input scripts/release-stats-sample.json` diff passes, with the
    sample's `BatteryPulse-count.txt` release showing its count in the Count column.
  - Session R step 6: screenshots in English and Russian of Settings → General, showing the toggle
    on, then greyed under Never.
  - §6.4 step 6 (after publishing):
    1. What's New lists the count (§6.4 step 2).
    2. Quit BatteryPulse, run `defaults delete io.github.nikitausov.BatteryPulse
       lastCountedVersion; defaults delete … lastUpdateCheck; defaults write … versionFirstLaunch
       -date "2026-01-01 00:00:00 +0000"`, then open it again (W-12's `count-check` does this).
    3. An `update` log line says `counted`.
    4. About 10 minutes later, the release-stats script shows v0.7.0's count at 1 or more.
  - The logged day (optional): if the RC ran for 24 h, one `noCounter` line for 0.6.99.
  - Review: `git grep` outside this plan's folder finds no remaining "counts and sends nothing",
    "only internet request" or "no telemetry" claim that is now false.
- **Effort:** S-M, 2 runs [estimate], plus about 3 minutes of the after-publishing session's time
  and its 10-minute background wait in §6.4 (none of the maintainer's).
- **Risks:**
  - GitHub changes how it counts: the numbers drift, the app is unaffected.
  - Same-address merging under-counts (VC-3); people clicking the file over-count.
  - A release without the asset is never counted (the 404 marks it). The post-publish step and the
    grace day guard against that.
  - "On by default" can read as telemetry. The announcement, the docs and the file's own text
    answer that (§11).
  - In the EU, a regulator may want opt-in (VC-8, §11).
  - E10 (C-1) cancelling the automatic check only postpones the count.
- **Rollback:**
  - **Before D1:** revert W-13's commits. Nothing shipped, so the keys aren't frozen yet.
  - **After release:**
    - a 0.7.x sets `isOnByDefault = false`, or removes the request;
    - the three keys stay reserved with their meaning;
    - `release.yml` keeps attaching the file while 0.7+ versions may run (a missing file only causes
      a marked 404).

### C-1: 0.6.2 carry-overs that need no M5 time (P3)

- **Source:** P2 §7.2 ("A cut item moves to 0.7"); RD §3.2 "Engineering lane".
- **Scope:** what 0.6.2 cut (P2 §7.2's cut order) that needs no M5 time: WP-20's SEC-18 research
  only; WP-19's P3 items and SW-13; WP-15 item 3 (CI experiments); WP-16 item 4 (E10, rebased over
  W-13's `UpdateChecker.swift`, §5). Each keeps its own P2 section as its spec. Also D-18, if 0.6.2
  didn't fix it: the iPad's connection label follows the transport of the reading shown.
- **Rule:** only items that need no M5 time ride here. The others go elsewhere:
  - **WP-17** (G-17: `page.switch` from the `perf` stream, at least 10 switches per page) and
    **WP-15 item 2** (internalize, which ships only with the RC's F8, G-15) need the M5. They join
    Session R's optional steps; internalize's F8 is Session R step 3 (every family on the RC).
  - **WP-16 item 3** (SEC-15, timed on the M5) joins Session R's optional steps. **Item 5** (the
    login item after an update) has no cause to run: 0.6.2's A0 saw Open at login keep its state
    across 0.6.0 → 0.6.1 (2026-10-22), and §6.4's login-item check confirms it for 0.6.2 → 0.7.0.
  - **WP-20's SEC-08** (Enhanced Security) is not planned: Q-B8 is no, and the Developer ID build
    it waited for won't exist, because M-1 is no (RD §4.2). Nothing in 0.7 waits for a signed
    build.
  - **WP-13 items 4-5** go with a beta style's graduation (FEA-25, RD §4.1). Q-B4, decided by
    delegation: both styles stay beta until the maintainer signs one off in a sitting.
  - **WP-18** runs in 0.6.2: Xcode is installed on the M5 (Q-B7, 2026-10-22), and 0.6.2's Session B
    runs it hands-free (P2 WP-18, 2026-10-23). Any item 0.6.2 cuts (or SZ-10's icon, if it wasn't
    signed off) rides in 0.7 the same way, in Session R's GUI phase, and nothing waits for it (RD
    §5.1 TCI-05; Session R step 11). The icon ships only on the maintainer's y to its screenshots
    in the four icon styles.
- **Effort:** 0-2 runs [estimate]. Cut first after the stretch.

### Stretch: W-5 (the feed), W-6 (History), W-7 (iPhone & iPad) (conditional: G7-5)

Specified in P2 §8.3, §8.5 (History, iPhone & iPad, feed-only options), §8.8 and §8.14. This plan
adds only:
- **The gate** (RD §3.2): they run only if all of these hold:
  - W0-3 passed with A or A′ (it did, with both; the feed uses A, §2.2);
  - Q-W3 is yes (decided 2026-10-22, following the maintainer's M-1 answer);
  - M-1 is no (decided 2026-10-22, by the maintainer);
  - the MVP has merged with budget left.

  If the budget ran out, they go to 1.1 on the feed.
- **One type behind the feed reader,** so the feed's location or entitlement can change later
  without touching the views (RD §3.2 engineering notes): A′, the shared-preference exception, if a
  macOS 27.x update denies A; an App Group container only if M-1 is ever revisited.
- **The feed's location is not a 1.x promise** (RD C14 item 2): it links an app and a widget of the
  same version, so it may move in a minor release with a line in the notes, and its version 1
  schema only gains fields. This narrows P2 §8.13, which lists "the feed's path" as frozen.
- **The new entitlement,** candidate A's one read-only home-relative path
  (`com.apple.security.temporary-exception.files.home-relative-path.read-only` =
  `/Library/Application Support/io.github.nikitausov.BatteryPulse/Widget/`, as SPIKE-W declared
  it), goes into `Resources/BatteryPulseWidget.entitlements` and W-1's pin.
  - The posture check compares against that file and passes unchanged (`build-app.sh:330-336`).
  - The guide's privacy text says what the feed holds (DOC-08).
- **`WidgetChartSummary`** lands in W-6, for 0.8's chart descriptors to reuse (RD §3.3 A11Y-01).
- **Effort** [estimate, RD §3.2]: W-5 3 runs, W-6 3, W-7 2-3; the strings ride in W-10.

### W-10: Localization review, guards, docs (P1; merges last)

- **Source:** P2 §8.7, §8.8, §8.11, §8.14 W-10; INV L10N-04, TCI-11, DOC-07; RD §3.2; §8 and §12
  below.
- **Items:**
  1. **Terminology pass** over every key the widget packages and W-14 added, with Apple's Russian
     wording (CL localization rule). The review lists each new key with its Russian in the PR.
     W-14's keys are checked against Apple's Russian support article for the Charge Limit
     (https://support.apple.com/ru-ru/102338) and System Settings → Battery's own string;
     D-13's screenshot didn't come with the final `A.md`, so the article stands.
     W-10 merges at C1, before Session R, so step 9b's screenshot only confirms it, and a mismatch
     is a one-key fix forward before D3. The catalog's translation of "Charging on hold" is not
     reused for them.
  2. **`LocalizationCatalogTests` review:** the App Intents literal forms landed in W-1 item 11.
     W-10 checks that every intent string the widget packages added is in the catalog, and that
     W-2's list of the edit sheet's strings shows each as a key with its Russian in the widget
     bundle (W-2 item 5), and adds the stretch's forms if it ran. Details' entity titles are the
     catalog's field labels; the stretch's device titles are verbatim and ignored.
  3. **The placeholder rule:** if W-2's dump shows `${name}` keys, one reasoned exception limited to
     the widget's intent files, and CL's "%@ only" sentence names it.
  4. **Guards** (TCI-11):
     - **`MotionGuardTests`** flags, in the widget: `TimelineView(.periodic…)`,
       `TimelineView(.everyMinute)`, `Text(…, style: .timer)`, `.relative` and `.offset`,
       `Text(timerInterval:…)` and `ProgressView(timerInterval:…)`. Those show seconds, a signed
       offset or a per-second countdown
       (https://developer.apple.com/documentation/widgetkit/displaying-dynamic-dates).
     - **The only self-updating text** is one helper file that uses a `SystemFormatStyle` date
       offset whose `allowedFields` has no `.second` and which passes `sign: .never` (REJ-62; §2.2
       W0-6).
     - **`SecurityGuardTests`'** widget placements (W-3a, W-3c, W-8) are reviewed together, and W-5's
       one file-reading file is added if the stretch ran.
  5. **SIZ-07 (P3):** a widget-only string table, only if §9's measurement favours it. It changes
     `string-tables.swift` and the catalog rule, so the review weighs it.
  6. **Docs:** §12's list: CL, USER_GUIDE, README, ROADMAP, What's New (`WhatsNew.version` 0.7.0
     and its features, keeping W-13's "Anonymous version count" row), and the release-notes draft,
     which keeps W-13's line (§13 step 2). Replacing `WhatsNew.features`
     (`UpdateViews.swift:397-419`) removes, in the same commit, every 0.6.0 title and detail key
     that nothing else uses; `catalogHasNoLeftovers` names them.
- **Files:** `Resources/Localizable.xcstrings`, `Tests/BatteryCoreTests/{LocalizationCatalogTests,
  MotionGuardTests, SecurityGuardTests}.swift`, `Sources/BatteryPulseApp/Updates/UpdateViews.swift`
  (What's New), `CLAUDE.md`, `docs/USER_GUIDE.md`, `README.md`, `docs/ROADMAP.md`,
  `.github/release-notes.md`.
- **Acceptance:**
  - Both jobs green.
  - The catalog has every key with its Russian.
  - Every new CL line is checked against the merged code with `git grep`, as WP-12 and WP-22 did.
- **Effort:** M, 2 runs. **Risk:** low.

### D1-D3: Freeze, Session R, release

As P1 §3.5 and P2 D1-D3, with 0.7's differences.

**D1, the freeze:**
- **Golden diff** (P1 §5's forms, against v0.6.2): exactly S-1's intended differences.
- **Storage round trip:** byte-identical; the MVP adds no file. With W-5, `Widget/feed.json` is the
  one new file.
- **The settings-and-identifiers `git grep`** (P1 §5): the new lines are exactly these:
  - the new kind string `…accessories`;
  - no URL scheme (G7-9); only on step 8's fallback, a `CFBundleURLTypes` entry for `batterypulse`;
  - W-13's three settings keys, `anonymousVersionCount`, `lastCountedVersion` and
    `versionFirstLaunch`, and the asset name `BatteryPulse-count.txt`.

  No other settings key is added, and none is changed.
- **Ceilings** (§9), each raise in a commit of its own that says why.
- **The notes draft** (§13) and the PR with the session checklist.
- **Build numbers, before the candidates** (§6.5): one commit makes `ci.yml` and `release.yml` set
  `BUILD_NUMBER` from one clock that only grows (for example whole minutes since 2026-01-01 UTC at
  build time; the run picks the form), instead of each workflow's own `run_number` (ci.yml:201,
  407; release.yml:109). A release is then above every earlier CI build, and the next cycle's CI builds
  are above the release. A release-only offset would fix 0.7.0 but put 0.8's spikes and RCs below
  the installed release, which the session script refuses (P2 WP-W0 "Install"). About shows the
  new number beside the version (`AboutView.swift:54`). ROADMAP's decisions record it.
- **The candidate builds:** RC-U, built as 0.6.99 for the placed-widget update test, and RC-F,
  built as 0.5.99 for F12. Same commit, two dispatches (P2 D1's pattern). Then RC-P (RC-U's commit
  plus one dummy Bool parameter on `BatteryWidgetIntent`, on `claude/070-spike-param`, never
  merged) and RC-U2 (RC-U's commit again, dispatched after RC-P so its build number is higher), for
  Session R step 4.4.

**D2** is Session R and the logged day (§6).

**D3:**
- Apply the answers or the defaults, and record the numbers in Appendix C.
- Move this plan's lasting decisions to ROADMAP, and fill `docs/VERIFICATION.md`'s 0.7 rows.
- Move what 0.7 didn't build to `docs/plans/1.1/widgets.md` (English only) and link it from
  ROADMAP's 1.1 entry, as 0.6.2's D3 did for 0.7 (RD §1.2 item 9): `widgets.md`'s §8.3 (the feed),
  §8.5's History and iPhone & iPad parts, §8.8's feed hardening, W-5 to W-7, W-9, and the Q-W
  answers.
- Remove `docs/plans/0.7.0/` and the ci.yml lines that name it (the Linux job's queue dry run, and
  the `bash -n` lines and the helpers' type-checks in "Check the verification scripts", which 0.6.2's
  D3 pointed at this folder's copies), noting the last commit that still holds it (`<keep>`) for
  §6.4's start line.
- Release (§13), then the after-publishing check (§6.4), started by the line D3 posts on the
  release PR with `<n>` and `<keep>` filled in (§6.2, "The short sessions").
- A week after publishing: the download counts into ROADMAP's Releases table (§13 step 8,
  NEW-23).

---

## 5. Order and parallelism

At most two agents, never two packages on one file, and never two packages on
`Localizable.xcstrings` at once (P2 §3, §5). One-line additions to `Package.swift` and
`.github/workflows/ci.yml` are mechanical rebase-overs, as in P2 §5: the second package to merge
rebases onto the first, and the review checks that nothing else overlaps.

| Round | Slot 1 | Slot 2 | Waits for |
|---|---|---|---|
| A0 | W-0, the intake (orchestrator; Session A ran the spikes, so no W-0S) | | v0.6.2 published; its D3 |
| A1 | S-1 | R-1 | A0 (M-2, M-3 and M-5 are decided) |
| A2 | W-1 | W-2, which merges after W-1 (it reads W-1's `widget-manifest.json`) | A0 (G7-1); for W-2, W0-1's processor options |
| A3 | W-3a | W-12 | W-1 and W-2 merged |
| A3′ (W-11: Q-W4 offers the drawn battery; skipped if W-11 is cut, §7.2) | W-11 | W-4 | W-3a merged (W-11 then changes the widget target's dependencies on a settled base) |
| A4 | W-3b | W-4, if it didn't run in A3′ | W-3a (the widget files, the catalog); W-11 if it ran |
| **Look check** | the maintainer at his desk, about 15 minutes (§6.1) | | W-3b's PNGs |
| A5 | W-8 (G7-8) | W-3c | W-3b (the catalog, the widget files); W-4 (`BatteryPulseApp.swift`) |
| A6 | W-14 (G7-18) | K-1 (M-9: yes) | W-14: A5 (W-8's widget files and catalog) and its fixture (D-13). K-1: the maintainer's backup key (§14 M-9) |
| **Look check 2** | the maintainer, about 4 minutes (§6.1b) | | W-8's and W-14's PNGs |
| A7 | W-13 | | A6 (W-14's catalog and docs); A5 (W-3c's `BatteryPulseApp.swift` and `AppSettings.swift`) |
| B (G7-5 only) | W-5, then W-6 | W-7, after W-5 | A7 (the budget, G7-5; the catalog after W-13) |
| C1 | W-10 (merges last) | C-1 (Linux only) | everything above |
| D1 | freeze RC-U and RC-F | | C1 |
| **Session R** and the logged day | the maintainer (§6.2, §6.3) | | D1 |
| D3 | release; after publishing (§6.4); a week later, the download counts (§13 step 8) | | Session R |

**Why this order:**
- **S-1 and R-1 first.** They need no spike answer and touch no widget file, so the slots work while
  W-0 reads 0.6.2's spike answers (the Q-W questions were decided on 2026-10-22).
- **W-1 before everything widget-side.** Its first test pins v0.6.1's small and medium widget before
  W-3a replaces the view (P2 §8.6).
- **W-4 beside W-3b,** or beside W-11 in A3′. W-4 owns the BatteryCore planner and
  `WidgetRefresher`; W-3b owns the widget target and the catalog; W-11 owns the painter's files.
- **W-11 after W-3a, not beside it.** Both edit `Package.swift`, and W-11 changes the dependencies
  of the widget target W-3a is rebuilding; after W-3a merges, W-11 rebases onto a settled widget.
- **W-3c beside W-8.** W-3c owns `BatteryPulseApp.swift`, `AppSettings.swift` and `MainView.swift`
  (`build-app.sh` only on G7-9's fallback); W-8 owns the widget target and the catalog.
- **W-14 in A6, beside K-1.** It edits the widget target and the catalog after W-8, and the app's
  Overview, Power, `Localized.swift` and `DemoController.swift`, which no other package touches; K-1
  touches none of them. Its widget field needs W-3b's plan and W-8's settled widget files.
- **W-13 in A7, after W-14.** It edits `BatteryPulseApp.swift` and `AppSettings.swift` after W-4 and
  W-3c, and the catalog and the docs after W-14. It merges before W-10, which composes What's New
  around its row, and C-1's E10 rebases over its `UpdateChecker.swift`.
- **The look check runs on W-3b's merged PNGs,** before W-8 and W-10. A look change then costs one
  fix run, not a re-freeze. The Accessories widget's and W-14's pictures exist only after W-8 and
  W-14, so they get their own short look (§6.1b) before C1.
- **Catalog order:** W-3a, W-3b, W-8, W-14, W-13, W-6 and W-7, then W-10. Each pair in a round has
  one slot that never touches the catalog (W-11, W-4, W-3c, W-12, K-1, S-1, R-1, C-1).

**Files no package shares** (the review checks): `Sources/BatteryPulseWidget/*` (W-3a, W-3b, W-8,
W-14, W-6, W-7 in sequence), `Sources/BatteryCore/Widget/*` (W-1, then the widget packages in the
same sequence, with W-4's planner file its own until W-14 adds its one reason),
`docs/USER_GUIDE.md` and `docs/ROADMAP.md` (S-1 and R-1 on separate parts, then W-14, W-13 and
W-10), `App/WidgetRefresher.swift` (W-4, then W-6 and W-7), `scripts/build-app.sh` (W-2, then
W-3a's one line; W-3c only on G7-9's fallback), `App/BatteryPulseApp.swift` (W-4's init line,
W-3c, then W-13), `App/AppSettings.swift` (W-3c, then W-13), `Updates/UpdateViews.swift` (W-13,
then W-10), `Tests/BatteryCoreTests/SecurityGuardTests.swift` (W-3a, W-3c, W-13, then W-10) and
`.github/workflows/release.yml` (W-13, then D1's build-number commit). **Rebase-over only:**
`Package.swift` (W-3a's test target, W-11's target and dependency lines),
`.github/workflows/ci.yml` (W-2, W-3a's PNG upload, W-12's `bash -n` lines), and
`Updates/UpdateChecker.swift` with BatteryCore's `Updates.swift` (W-13, then C-1's E10).

---

## 6. The maintainer's sittings

**Wording** (P2 §3; the lessons of 0.6.1's UR-3 and G10):
- Every yes or no question means **"y = looks right"**.
- Comparisons of looks are **numbered choices**.
- **Screenshots and recordings are the evidence,** not memory.
- **The script reads the logs,** counts crash reports and compares pictures.
- The questions are in plain words. Where the script can't read a setting, it records it as
  "unknown" and never changes it.
- **Hands-free** (the maintainer's request, 2026-10-23; P2 §10, "The hands-free sessions"): on the
  M5, a local Claude Code session with computer use asks these questions of itself (`judge`, with
  written criteria, a default and the script's pixel checks) and does every step a hand did. He is
  asked only for taste and consent, batched into one message with the pictures opened. The look
  checks (§6.1, §6.1b) stay PR comments he can answer from anywhere.

**Installing builds:** every build stays in its DMG, and the script installs it into
`/Applications` the way `UpdateInstaller` does: copy next to the app, swap with
`renamex_np(RENAME_SWAP)`, `lsregister -f`, relaunch (P2 WP-W0 "Install"; R:183-201). So only
`/Applications/BatteryPulse.app` exists, and macOS can't pick up another copy's widget.

### 6.1 The look check (at the desk, about 15 minutes, no M5 steps)

**When:** after W-3b merges.

**What:** the orchestrator downloads CI's PNG artifact (W-3a item 11) and posts the pictures in a PR
comment: every family × rendering mode, in English (and in Russian if W-3a found the way). The
accented and vibrant pictures are marked "approximate" (W-3b item 7). The maintainer answers in the
comment. The questions behind these looks were decided on 2026-10-22 by delegation (§14), so each
question offers the decided answer first and asks him to sign off the look it leads to; another
answer changes it (RD §1.2 item 8).

1. "Small and medium, Automatic, next to 0.6.1's widget (the picture on the left): **1** same,
   **2** different (say what)."
2. "Large: are these the right eight details (maximum capacity, cycle count, temperature, adapter,
   system load, battery power, Low Power Mode, charge in mAh)? y, or say which to swap." (Q-W4)
3. "Extra large: **1** two panels as shown, **2** a bigger copy of large, **3** leave extra large
   out for now (it can come later)." (Q-W10, decided by delegation: 1, if you approve the picture;
   a size can never be removed once shipped, so only an explicit 1 or 2 declares it, and no answer
   means 3)
4. "Main visuals to offer: **1** all three (number and symbol, ring, drawn battery), **2** number
   and symbol plus ring, **3** number and symbol only." (Q-W4, decided by delegation: 1)
5. "Default colours: **1** level colours, as today, **2** monochrome." (Q-W4, decided by
   delegation: 1)
6. "Time: **1** offer clock time and time left, with clock time as the default, **2** the same
   with time left as the default, **3** clock time only." (Q-W5, decided by delegation: 1; W0-6
   passed with `sign: .never`)
7. "The words of the edit sheet (the list below, English and Russian): y = fine, or say which."
   (§8)
8. "The attention row (picture: 'Service Recommended' in the last row, and in small in place of
   the time line): **1** on, **2** never." (Q-W13, decided by delegation: 1; "off by default"
   would need a frozen parameter, so it isn't offered)
9. "'Hide fully charged' in the Accessories widget, off by default: y = keep it, n = leave it out
   of 0.7." (Q7-5, decided by delegation: y; the Accessories pictures come in §6.1b)

**Without an answer:** the decided answers of §14; for question 3 that means no extra large,
because only an explicit 1 or 2 declares a size. **Without PNGs** (W-3a's test target couldn't
link): the check moves into Session R as step 3b (+10 minutes of his answers, in the day-end
batch).

**Pre-answers:** the orchestrator posts question 1 with a pixel diff against 0.6.1's widget and
question 7 with the words checked against the catalog's terms, so he mostly confirms.

### 6.1b The second look (about 4 minutes, after W-8 and W-14 merge)

A second PR comment holds W-8's PNGs (small, medium and large; G7-8) and W-14's: the Battery widget
at the Charge Limit, small and medium Automatic with "Charged to limit" and a Custom medium with the
"Charge limit: Reached" detail. "y = looks right, or say the picture's number." Without an answer,
y. Without PNGs, Session R steps 3 and 9b cover them.

### 6.2 Session R (the release candidate, hands-free; about 6-8 minutes hands-on)

Session R runs as 0.6.2's Session B does (P2 §6; the maintainer's request of 2026-10-23, P2 §10
"The hands-free sessions"). One local Claude Code session on the M5, the CLI in Terminal with
computer use, runs `bash ~/bp-070/R/run/docs/plans/0.7.0/m5-session.sh <step>` (W-12; always by
this full path, which the start line's one allow rule names) and does every step below itself:
- with 0.6.2's helpers (`ui`, `preflight`, the arm window, the split `restore` with `changes.tsv`,
  the heartbeat; W-12 item 1);
- by the script, AX, CGEvent and CGWindowList first, and computer use where those can't reach;
- judging the pictures itself, beside the script's pixel checks.

The maintainer does only what needs a person: the start line and one yes to the list of changes, quitting his own apps, the Focus on and off, the adapter, his password (only if step 12 needs it), the permission prompts, the taste questions,
his typed "day-end", and his yes before `send`. A step that fails records "not checked" or "not
run" with its reason, and its gate takes its default (§7.1). The runbook is
`docs/plans/0.7.0/SESSION-R.md` (W-12), with Session B's rules, privacy and proofs.

**His part:** about 12-15 minutes for Session R, its day's end and the after-publishing check (1
once before, 6-8 at the start, 3-4 at the day's end, 2 after publishing), against about 106 before
(about 83 here, 10 at the day's end, 13 after publishing). Each optional extra below adds a minute,
and step 3b adds 10.

| When | What he does | Time |
|---|---|---|
| Once, any day before (best the same day: the CLI updates itself in between) | Quit Session B's Claude session if it is still open (one Claude session at a time on the Mac). In `~/BatteryPulse`: `claude`; `/mcp` shows `computer-use` enabled (kept per project from Session B; if not, Enable); he asks it to check the start line's flags and variable against this CLI (`claude --help` and its settings documentation), and if one changed, it rewrites the line for him | 1 min |
| The start, in the evening, on the adapter | In `~/BatteryPulse`, he pastes the start line below (his choice; no agent sets a permission mode). First, one yes to the list of changes: Session B's (P2 §6, the yes-list), plus the 24-hour setting, Check for updates, Window to open, BatteryPulse's and its widget extension's language, the edit-sheet choices steps 4 and 8 make, the gallery's new widgets (removed at the end unless he keeps them), and a Bluetooth accessory disconnected and reconnected; the Charge Limit only if step 11 still needs it. Then one approval of the app list; Accessibility for Terminal again if he revoked it after Session B (one prompt, from preflight); any other first-time prompt; quit his own apps. Then step 9's plug: unplug at a beep, plug in at a second beep 70 s later. Last, a Focus on, and he leaves the Mac on the adapter with the lid open | 6-8 min |
| The logged day | He turns the Focus off and uses the Mac as usual (§6.3) | passive |
| The day's end | He writes "day-end". Then the batch (any picture the session answered 3; step 3b's questions only without PNGs) and his yes to `send`, at the Mac. Optionally, at a beep, the earbuds in their case (step 9's accessories half, only if the Bluetooth disconnect didn't work) | 3-4 min (+1; +10 with step 3b) |
| Only if Session B's night showed that a stream dies over sleep | His password in the arm window at the start (step 12's `log config`) and again at the day's end (its reset) | +1 min |

**The start line,** one paste. The flags and the variable are [check on his CLI in the once-before
step]. Single quotes keep the shell from reading the sentence, so it has no backticks or
apostrophes, and `--allowedTools` comes before `--permission-mode`, so its list ends before the
sentence (Session B's shape):

```
DISABLE_AUTOUPDATER=1 claude --allowedTools 'Bash(bash ~/bp-070/R/run/docs/plans/0.7.0/m5-session.sh:*)' --permission-mode auto 'Run the BatteryPulse M5 Session R hands-free: in ~/BatteryPulse run git fetch origin claude/070-integration && git show FETCH_HEAD:docs/plans/0.7.0/SESSION-R.md, then follow that runbook from its first step.'
```

`DISABLE_AUTOUPDATER=1` keeps the CLI from updating itself mid-session, and the one allow rule lets
the session run its script without a prompt per call. If the CLI rejects a flag, the once-before
check runs then (+1 min).

**The short sessions** (step 11's Charge limit and Hold watch, and §6.4's After publishing) start
the same way: the same line with its own worktree in the allow rule (`~/bp-070/C/run`,
`~/bp-070/H/run` and `~/bp-070/D3/run`), which its runbook section makes at the commit it was read
from, and its own sentence. Each sentence names a ref and a path that survive 0.7's cleanup
(`claude/070-integration` lives until the release, and the release PR's `refs/pull/<n>/head` stays
after its branches are deleted). Each session follows Session R's rules, and its results leave the
Mac only after his yes before `send`:
- **Charge limit** (step 11; not needed in 0.7, since the final `A.md` brought the capture and
  the 100 % diff; its section stays in the runbook for 0.8's FEA-35 check, after a discharge):

  > Run the BatteryPulse 0.7 charge-limit capture hands-free: in ~/BatteryPulse run git fetch origin claude/070-integration && git show FETCH_HEAD:docs/plans/0.7.0/SESSION-R.md, then follow its section Charge limit.

- **Hold watch** (step 11, optional; any night before D3, never the logged day's):

  > Run the BatteryPulse 0.7 hold watch hands-free: in ~/BatteryPulse run git fetch origin claude/070-integration && git show FETCH_HEAD:docs/plans/0.7.0/SESSION-R.md, then follow its section Hold watch.

- **After publishing** (§6.4). D3 posts this line on the release PR with `<n>` (the release PR's
  number) and `<keep>` (the last commit that still holds `docs/plans/0.7.0/`, before §13 step 4
  removes it) filled in:

  > Run the BatteryPulse 0.7.0 after-publishing check hands-free: in ~/BatteryPulse run git fetch origin refs/pull/<n>/head && git show <keep>:docs/plans/0.7.0/SESSION-R.md, then follow its section After publishing.

**The order:**
- **The start** (he is there, on the adapter):
  - his yes to the list of changes, first, before anything changes (preflight's proofs included);
  - the frozen worktree `~/bp-070/R/run` at FETCH_HEAD, the commit the runbook was read from (the
    start sentence's `git fetch` and `git show` and `git worktree add ~/bp-070/R/run FETCH_HEAD`
    run under auto mode; every later command goes through the script's one prefix);
  - preflight: P2 §6's proofs, as quick reads where Session B settled them, and P1 again for 0.7's
    kinds;
  - step 1;
  - step 2's install and its first shots, while he gives the approvals;
  - step 9's two beeps;
  - then `mark away`.
- **The GUI phase** (on the adapter, while he is away or asleep; about 2-3 hours [estimate],
  capped at 4):
  - step 2's answer, steps 3 to 8, step 9's accessories half, step 9b, and the step 11 items that
    fit;
  - then `restore gui`;
  - last, the session leaves a summary in his language (on the Mac only; `R.md` stays English):
    an alert first for any setting not confirmed back, then every setting it changed with its
    confirmed value, and a reminder to turn the Focus off. He reads it before he uses the Mac.
- **The logged day** (step 12): the arm window starts the stream and releases the GUI phase's
  display assertion, and the session ends its turn.
- **The day's end** (§6.3), on his "day-end".
- **After publishing** (§6.4): a short session of its own.

**The steps:**

1. **prepare** (the start):
   - A fresh backup into `~/bp-070/R`: the app, the defaults domain, Application Support, the
     appearance and the wallpaper.
   - The script reads the Icon & widget style, Dim widgets on desktop, the 24-hour setting
     (`AppleICUForce24HourTime`, P2 §6's P7), Open at login, BatteryPulse's Check for updates and
     the Charge Limit (`pmset -g battlimit`), as 0.6.2's prepare does; an unread value is
     "unknown" and never changed (W-12 item 1).
   - It builds `bpulse` (`xcrun swift build -c release --product bpulse`).
   - The small and medium widgets placed from 0.6.2: the script saves a screenshot and
     `pluginkit -mv -i io.github.nikitausov.BatteryPulse.Widget`. A missing one is added by
     computer use, and noted.
2. **Placed widgets across the update** (the start, then the GUI phase; G7-2):
   - The script installs RC-U over 0.6.2 the way `UpdateInstaller` does, and relaunches. It takes
     `pluginkit` and a screenshot after 1 minute and again after 5 minutes, while he is still at
     the approvals.
   - In the GUI phase, Claude compares the shots with prepare's, each after the fixed desktop click
     (P2 §6, Session B step 4: Dim widgets reacts to the desktop's focus): **1** same, **2** blank or grey,
     **3** gone, **4** different (say what).
   - **Record:** both screenshots, both `pluginkit` outputs, the answer.
   - Its swap ends the widget extension first, as 0.6.2's installer does (D-17; W-12), and it logs
     the extension's pids before and after and any CHSErrorDomain 1103 line.
   - This step has no control build, so it confirms W0-2's answer and never decides it alone (§7.1
     G7-2 says what a 2 or 3 leads to).
3. **The gallery, every size:**
   - By computer use: Edit Widgets from the desktop's context menu (a Control-click on an empty
     spot), a search for BatteryPulse, and the gallery's click-to-add, then one slow `ui drag` per
     widget: Battery large (and extra large, if it is offered); Accessories small, medium and large
     (if offered).
   - The script screenshots the desktop after each add, and Claude judges each new widget against
     W-3b's and W-8's PNGs: y = looks right; n names the picture.
   - **3b**, only if the look check had no PNGs: the session shoots these widgets for the look
     check's questions, which he answers in the day-end batch (+10 minutes of his).
   - **If it can't:** per widget "not checked". If the gallery's host can't be approved for computer
     use, adding the widgets becomes one hands-on minute at the start.
4. **The edit sheet** (computer use, about 25 actions; the choices follow a fixed rule):
   1. On the medium Battery widget: Edit Widget from its context menu; Layout set to Custom; the
      first four details in the list (with Details as the entity, a chooser that lists the fields is
      W0-1 (b)'s answer); Time set to time left (if offered); Colours monochrome; Update
      time always; Done. Claude checks that the widget shows those choices (y/n).
   2. Edit Widget again: does the sheet show the choices made? y/n.
   3. Russian, by D-8's method, which in Session A reached the widgets but not the sheet: the
      script switches the extension's language and BatteryPulse's own, and ends the extension.
      - Claude opens Edit Widget and reads its words: **1** all Russian, **2** some English (which),
        **3** the sheet didn't change language.
      - A **2** is a fix before release (a string W-2 item 5's check missed). A **3**, as in Session
        A, is recorded "not checked", never "n" (G7-13).
      - While the extension is in Russian, the script reloads every placed widget (one not yet
        redrawn keeps its English, Session A) and screenshots them. Then it switches both languages
        back.
   4. **A parameter added later** (RD C14 item 5): the script installs RC-P over RC-U (RC-U plus one
      dummy parameter, D1). Claude opens Edit Widget on the medium widget: are the choices made in
      4.1 still there? y/n. The script then installs RC-U2 for the rest of the session. The answer
      goes to Appendix C, as the evidence for 1.1's added parameters. (Q7-5 was decided without it:
      FEA-21 is declared before D1 either way, W-8 item 2.)
   5. The widget back to Automatic, by computer use. The script screenshots each state.

   **If it can't:** per sub-step "not checked"; a widget left on Custom is listed for `restore`.
5. **Rendering modes and places** (G7-4):
   - Dim widgets on desktop set to **Always**, then Icon & widget style through Default, Dark,
     Clear and Tinted, by computer use in System Settings (the panes opened by URL, P2 §6's P8).
     The script screenshots the desktop per style.
   - Then Dim widgets on desktop **Automatically**, and the four styles again. Each time the script
     clicks the desktop, then a window (CGEvent), and screenshots the desktop twice per style.
     (Apple's options are Automatically, Always for monochrome and Never for full colour,
     https://support.apple.com/guide/mac-help/mchlp1119/mac.)
   - Then the same with Notification Center open, by an AX click on the clock. Only crops of
     BatteryPulse's widgets are taken: no computer-use screenshot while it is open.
   - Claude judges each picture: can every widget be read, and does a low or "Service Recommended"
     state still show without colour? Each crop's contrast is measured beside the judgment.
   - Increase Contrast on and off, then Reduce Transparency, by computer use (System Settings →
     Accessibility → Display), a shot each, judged the same way.
   - The style and Dim widgets on desktop are set back to prepare's values, and confirmed by the
     defaults read and a shot.
6. **Time and language:**
   - 24-hour time off by computer use (System Settings → General → Date & Time). Claude reads a shot:
     does the widget show '4:39 PM'-style times? y/n. Then it is set back.
   - If time left shipped: two shots of a time-left widget, 65 s apart. **1** the minutes went down
     by one, **2** no, **3** it shows seconds, **4** it starts with a minus sign. A 4 means the
     `sign: .never` of §2.2 W0-6 is missing: a fix before release.
   - **The version count's setting** (W-13):
     - The script opens BatteryPulse's Settings → General and screenshots the "Include this Mac in
       the anonymous version count" toggle, on unless he turned it off.
     - It quits the app, sets Check for updates to Never through defaults, relaunches, and
       screenshots the toggle greyed out.
     - It relaunches BatteryPulse in Russian and takes both screenshots again. Then Check for
       updates goes back to prepare's value, and BatteryPulse back to his language.
     - Claude judges: are the toggle and its footer readable in both languages, and greyed out
       under Never? y = looks right.
7. **Accessibility and Text size** (G7-12). Nobody drives VoiceOver (W0-5: too hard for the
   maintainer); the session reads the tree VoiceOver walks:
   - `ui tree` at each placed BatteryPulse widget's hit-tested frame (small, medium, large and
     Accessories; P1 found the host) records each element's role and label. It prints only the
     subtree inside BatteryPulse's frame. The tree is exposed: Session A read it under Finder's
     desktop group, one group per desktop widget (Appendix C row 8), and `ui` reads it there
     through AX, without a System Events query (W-12 item 1).
   - No new prompt: Terminal holds Accessibility for the session, kept from Session B or granted
     again at the start.
   - The session compares them with W-3b item 5's rules and the label builder's
     (`WidgetAccessibility`) expected labels for the reading shown: no symbol name, the charge as
     one element with its value, one element per row, no empty group.
   - **If the tree can't be read:** Accessibility Inspector (Xcode → Open Developer Tool), pointed
     at each BatteryPulse widget by computer use. The script screenshots the inspector each time.
   - **In Russian:** if step 4.3's switch worked, the script switches the extension's language
     again, reads the tree again and switches it back. Otherwise it is recorded "not checked".
   - Text size, a record only (decided, §2.2 W0-5: at 17 pt Session A saw no change): raised to
     its largest by computer use (System Settings → Accessibility → Display), and a shot: do the
     widgets' words **1** grow, **2** stay unchanged (expected), **3** get cut off (which: a fix
     before release)? Then it is set back.
8. **Clicks** (W-3c, G7-9):
   - The script quits BatteryPulse, then clicks the Battery widget at its frame (CGEvent). From the
     log and a shot: **1** Overview, **2** another page (which), **3** nothing opened.
   - The same with BatteryPulse running and no window open; for the Accessories widget (expect
     Accessories); for a Battery widget whose main value is maximum capacity, set in Edit Widget by
     computer use (expect Health), then set back to Automatic the same way (else listed for
     `restore`); once with the main window open; and once with BatteryPulse's own
     Settings → General → Window to open set to compact through defaults while the app is quit
     (expect the main window at the page), then set back.
   - The script records each click's route and page from the app's line (`url` or `activity`, and
     the page's case; never a full URL in a public log). A click expected on Health that arrives as
     an activity opens Overview, since the activity carries no configuration: a **2** naming the
     route. A **3** with BatteryPulse quit means the unregistered `batterypulse` URL didn't launch
     the app: a navigation-only scheme is then registered before release (G7-9).
9. **Plug, unplug and accessories:**
   - **At the start, with him:** he unplugs at a beep and plugs in at a second beep 70 s later. The
     script screenshots the Battery widget every 10 s and takes `bpulse --json` at the same
     moments. Claude checks that the widget's state matches `bpulse --json`'s within a minute. At
     his 80 % limit, plugging in shows the limit's not-charging state, not "Charging": "Not
     charging" while `NotChargingReason` reads bit 7 (Session A's plug-in read 128 first), then
     "Charged to limit" once bit 24 appears; the step records when it does (W-14 item 6).
   - **Accessories,** in the GUI phase: a connected accessory is disconnected by an AX press in
     System Settings → Bluetooth (no computer-use screenshot of that pane), then reconnected
     [unverified: whether its source leaves `pmset -g accps`]. Did the Accessories widget change
     within a minute? Otherwise his earbuds in their case at the day's end (optional), or "not
     checked".
   - **Record:** the `widget.reload` and `widget.timeline` lines with their times, and the per-kind
     counts the app logged from `currentConfigurations()` during steps 2-9 (W-4 item 3). Appendix C
     records whether they match the widgets placed in steps 1 and 3; until they do, an empty answer
     keeps counting as "placed".
9b. **The Charge Limit** (W-14, G7-18):
    - Demo Mode's Charge limit scene, chosen by AX. The script screenshots Overview, Power, the menu
      bar popover and the compact window, then the same in Russian. Claude checks that they say
      "Charged to limit", with "Charge limit: Reached" on Power. Then Demo Mode is left.
    - If `bpulse --json` shows bit 24 right now (the battery menu would say "Charged to 80% Limit",
      or another number), the script also screenshots the Battery widgets; otherwise their look is
      CI's PNGs (§6.1b).
    - D-13 brought no Russian screenshot of the Charge Limit (the final `A.md`), so: System Settings
      → Battery → (i) next to Charging, with System Settings in Russian [unverified: whether a
      language argument reaches its panes, which run as separate extensions; probably not]. By
      default Apple's Russian article stands, and W-10 took its words from it (W-10 merged at C1). A
      shot that does show Russian confirms them, and a mismatch is a one-key fix forward before D3.
10. **F12** runs at the end of the logged day (§6.3), so the logged day starts on a candidate
    installed once and the extension isn't flipped through four versions first.
11. **Optional:**
    - **The Charge Limit capture and the 100 % diff** (QUA-05): **not needed.** D-13's redacted
      capture and the 80 → 100 → 80 reads came with the final `A.md`, so `bash
      docs/plans/0.7.0/m5-session.sh charge-limit` (W-12) doesn't run in 0.7, here or before C1;
      W-12 keeps it for 0.8's FEA-35 check (RD §3.3).
    - **The optimized charging hold** (QUA-06): `… m5-session.sh hold-watch` on a separate night,
      never the logged day's, from the Hold watch short session (§6.2, "The short sessions"): he
      starts it in the evening and leaves the Mac plugged in with the lid open, and in the morning
      the session says whether a hold was seen [uncertain: whether macOS holds the charge while the
      Mac is kept awake].
    - **W-11's pixel check:** `scripts/menu-bar-shots.sh` before and after, in the GUI phase.
    - **Any of 0.6.2's open checks** that C-1 couldn't carry (D-14): WP-17's page switches, SEC-15's
      timing, in the GUI phase.
    - **Any WP-18 item 0.6.2 left** (C-1): in the GUI phase, as 0.6.2's Session B runs them (P2
      WP-18; Xcode is installed on the M5, Q-B7).
12. **Start the logged day** (G7-11):
    - The arm window starts the `perf` log stream under `nohup`, detached from the window (he may
      close it), and releases the GUI phase's display assertion, so the day runs on a Mac that
      sleeps normally. `perf-stats` reports the stream's gaps.
    - Only if Session B's night showed that a stream dies over sleep (P2 Appendix C):
      `sudo log config --subsystem io.github.nikitausov.BatteryPulse --mode
      "level:debug,persist:debug"` for one day, set at the start with his password in the arm
      window, then `sudo -k`. It is reset at `day-end`, with his password again [unverified on
      macOS 27]. Otherwise there is no `log config` and no password.
    - The session ends its turn; the day starts with the widgets on the desktop.

### 6.3 The logged day, and its end (passive, then about 3-4 minutes)

- **During the day:** nothing to do.
- **The day's end,** on his one message, "day-end":
  - **`day-end`:** the script stops the stream and runs `perf-stats` (W-12). It records:
    - per kind, the reload requests, the timelines delivered, the share delivered and the median
      delay (G7-11);
    - the widget's reads, and its total read time per day (§10);
    - crash reports for BatteryPulse and BatteryPulseWidget since prepare, which must be 0 (G7-16);
    - `fault` messages in the subsystem, which must be 0 (G7-16);
    - W-13's `update` lines (optional evidence): if the candidate ran for 24 hours and an automatic
      check was due, one `noCounter` for 0.6.99, which has no release.
  - **F12** (D-12, G7-15), after the measurements and before `restore`, and after P2 §6 step 6's
    rate check (`curl -s https://api.github.com/rate_limit`: at least 10 unauthenticated requests
    left, else it waits in the background for the reset, at most an hour, while his batch goes
    on, and records "not run: rate-limited" if the limit is still short): RC-F (built as 0.5.99)
    → Check for Updates → Install and Relaunch, by AX presses. The script reads the version: did
    BatteryPulse come back as 0.6.2? y/n.
  - Then his batch and his yes at the Mac, and `send` (to `claude/070-session-r`, through the
    privacy lint).
  - Then `restore end`:
    - it reinstalls the backed-up 0.6.2, so the after-publishing check runs the real update path;
    - it resets the log configuration, if step 12 set it (his password);
    - the session puts back, from `changes.tsv`, each confirmed: the Icon & widget style, Dim
      widgets on desktop, Text size, Increase Contrast, Reduce Transparency, the 24-hour setting,
      Check for updates, Window to open, Open at login, the languages, a widget's choices that
      steps 4 or 8 listed, the Bluetooth accessory (if it stayed disconnected) and the Charge Limit
      (if a step changed it);
    - it removes the test widgets he didn't ask to keep, by computer use;
    - what stays for his hand: at the end of the series, revoking Terminal's
      Accessibility (optional, 10 seconds).

### 6.4 After publishing (a short session, about 2 minutes hands-on, plus a passive 10-minute wait; D3)

From the restored 0.6.2, with the session's small and medium widgets still placed. A short local
session runs the check, started like Session R with the line D3 posts on the release PR (§6.2,
"The short sessions": it reads `SESSION-R.md`'s section After publishing from the release PR's
`refs/pull/<n>/head`, since §13 step 4 has removed the plan folder). His part is the line, the
approvals and, at its end, his yes before `send`: about 2 minutes. A second yes comes only if step
5 asks for one.
1. **The before-picture:** the script takes it, with `pluginkit`, right before Install and Relaunch
   (after `restore`, which goes from RC-U, configurable, back to 0.6.2, static). If a widget is blank
   or gone at that point, computer use adds it again from 0.6.2's gallery first, so the picture shows
   working widgets.
2. Check for Updates → Install and Relaunch to 0.7.0, by AX presses. Claude reads About (0.7.0?
   y/n), whether What's New appeared once (y/n), and whether it lists "Anonymous version count"
   (y/n; W-13).
3. Claude compares the widgets with the before-picture, after the fixed desktop click: **1** same,
   **2** blank or grey, **3** gone, **4** different. The script runs `pluginkit` again, and reads the
   `update` log for 0.6.2's pre-swap line (every `BatteryPulseWidget` process ended, D-17) and any
   CHSErrorDomain 1103 line.
4. P2 D3's list:
   - History shows the past days (a shot);
   - the settings and the menu bar look are unchanged (shots against the before set);
   - `codesign -dv --verbose=4` shows `flags=0x10002(adhoc,runtime)`;
   - `xattr -l` shows no quarantine;
   - the login item is still listed if it was on (`ui tree` on Login Items, which prints only whether
     the row exists);
   - notification permission is kept (a shot of BatteryPulse's Settings → Notifications).
5. **On a 2 or 4 in step 3, or any other failure:** `gh release edit v0.7.0 --prerelease`, on his
   yes, and fix forward. **On a 3:** if Session R step 2 also showed "gone", the notes already say
   "add it again"; otherwise the notes are edited to say so, and ROADMAP Stage 1.2 records it. Either
   way it is a documented known limitation, not a reason to wait: with ad-hoc signing through 1.0
   (M-1 is no), no signed build is coming to fix it (RD C3, C7).
6. **The version count** (about 3 minutes of the session's time, then a passive 10-minute wait;
   W-13), with Check for updates set to anything but Never:
   - The session quits BatteryPulse. `… m5-session.sh count-check` (W-12) runs `defaults delete
     io.github.nikitausov.BatteryPulse lastCountedVersion; defaults delete … lastUpdateCheck;
     defaults write … versionFirstLaunch -date "2026-01-01 00:00:00 +0000"` and opens BatteryPulse
     again. That skips the grace day and makes a check due.
   - The first automatic check runs 20 seconds after launch, and an `update` log line says
     `counted`.
   - About 10 minutes later, `swift scripts/release-stats.swift` shows v0.7.0's
     `BatteryPulse-count.txt` at 1 or more (counts arrive in batches, VC-3). The session waits out
     the 10 minutes as a background wait (W-12's long-call rule: the Bash tool stops a call at 10
     minutes).
   - **On `failed`, `noCounter` or no line:** the script prints the logged code. `noCounter` means
     the asset is missing: run the `gh release upload` that `release.yml`'s check names, then
     `count-check` again (the 404 marked this version as counted). Otherwise
     fix forward in a 0.7.x; nothing a user sees depends on the count, so it is no reason for
     `--prerelease`.
7. **The first day's comparison:** at the short session's end, a click opens the popover, and Claude
   compares the widget's charge and "Lasts until" with it, within 2 points and about 15 minutes (P2
   D3, `994c09d`). His everyday use on the first day stands in for a later look.

### 6.5 Risks the sittings watch

- **Build numbers:**
  - Today CI sets `CFBundleVersion` from ci.yml's run number (ci.yml:201, 407; 258 on 2026-10-22), and
    a release from release.yml's own (`release.yml:109`; 7 for 0.6.1). WidgetKit caches by
    `CFBundleVersion` (`build-app.sh:136-137`), so the published 0.7.0 would almost certainly
    carry a lower number than RC-U, and a stale widget from that cause would be misread as a
    configuration loss in §6.4.
  - **So D1 fixes it** before the candidates: both workflows take the build number from one clock
    that only grows (D1-D3). It is a technical change, and ROADMAP's decisions record it.
- **Text size and desktop widgets:** Session A saw no change at 17 pt (W0-5), so a "2 unchanged"
  in step 7 is expected and not a failure; only a 3 (words cut off) is a fix before release.
- **A DMG copy over a running 0.6.x extension:** chronod may cache 0.7's build number with the old
  static descriptor, as W0-2's first install did, and it doesn't repair itself: chronod's
  refetch covers only descriptors with unresolved default intents, and a chronod restart kept it
  (Session A), so it stays until the next version change (P2 §8.16). The
  in-app path ends the extension first (D-17); the guide keeps "add it again if it's gone" for a
  copy from the DMG (§12).
- **Ad-hoc signing stays through 1.0** (M-1 is no):
  - A DMG install meets Open Anyway, and a DMG replacement may cost permissions and placed
    widgets (UG:425-426, UG:493-495). These are documented known limitations at 1.0 (RD C3, C7,
    C16), so a loss seen in Session R step 2 or §6.4 is recorded and documented (§12), never
    deferred to a signed build.
  - In-app updates keep the same path as 0.6.x (`UpdateInstaller`), which is what §6.4 tests.
- **The hands-free mode** carries 0.6.2's risks (P2 §6, "Risks of the hands-free mode"):
  computer use is a research preview, a stall, posted events resetting HIDIdleTime, the phase's
  length and the warm fanless Air. Session R adds four:
  - **The edit sheet and the gallery by computer use** (about 25 actions in step 4, slow drags in
    step 3): a sheet it can't operate is "not checked" per sub-step, and G7-13 and step 4.4's
    evidence then take their defaults; a gallery it can't reach costs him one hands-on minute at
    the start.
  - **The widget host's tree on 0.7's kinds** may differ from what Session B's P1 found: P1 runs
    again at the start, and the fallback is Accessibility Inspector by computer use, then "not
    checked" (G7-12's default).
  - **A display assertion left on into the logged day** would keep the Mac awake and skew G7-11's
    delivered share. The arm window releases it at step 12 and records the time, and `day-end`
    checks `pmset -g assertions` for any left.
  - **A setting left changed while he uses the Mac** on the logged day: the GUI phase ends with
    `restore gui` and the summary he reads first, with an alert for any setting not confirmed back.

---

## 7. Gates and their defaults; cut line; frozen surfaces

### 7.1 Gates

| Gate | Decides | Measured by | If no measurement comes |
|---|---|---|---|
| **G7-1** configuration | App Intents configuration | **Answered: passed** (W0-1: CI on 2026-10-22, the edit sheets in Session A); W-2's CI check from then on | Configuration ships; presets (FEA-13) are not planned. W0-1 (b) stays open for Details' chooser (the final `A.md` doesn't say whether it was opened): W-3a's review chooses before its merge, per-slot `AppEnum` parameters by default, or the entity checked by Session R step 4.1 (§2.2) |
| **G7-2** placed widgets | today's kind becomes configurable | **Answered: passed** (W0-2: placed widgets survive with Automatic once the old extension is ended before the swap; W2's retest); 0.6.2's pre-swap end (D-17); Session R step 2 and §6.4 confirm | If Session R step 2 or §6.4 answers 2 or 3: check the logs for the pre-swap end and CHSErrorDomain 1103. If 0.6.2's installer didn't end the extension, D-17's 0.6.3 comes first. Otherwise compare with D-9 (the plain 0.6.1 → 0.6.2 in-app update); either way ship as designed, the notes say "add it again if it's gone", and it stays a documented known limitation at 1.0 (RD C3, C7). No new kind. **No Session R: no release** (§3) |
| **G7-3** time left | the Time parameter | **Answered: passed** with `sign: .never` (W0-6); Session R step 6 confirms | A 4 in step 6 (a minus sign) is a fix before release; seconds or no countdown: time left isn't declared, clock time only |
| **G7-4** rendering modes | which modes are designed and checked where | W0-4 (2): no log data, only screenshots (Session A); Session R step 5's screenshots | All three modes designed; every place checked in Session R |
| **G7-5** stretch | W-5 to W-7 in 0.7 | W0-3 **passed** with A and A′ (the feed uses A, §2.2); the budget after A7. Q-W3 (yes) and M-1 (no) were decided on 2026-10-22 | No budget left: 1.1 on the feed (RD §3.2) |
| **G7-8** Accessories widget | W-8 | W0-4 (1) **passed** (the sandboxed widget read them itself); Session R steps 3 and 9 confirm | W-8 ships; if a macOS 27.x update stops the read, its empty state shows (RD §7) |
| **G7-9** URL scheme | register a navigation-only scheme | W0-4 (4), (5) **answered** (the final `A.md`): the `batterypulse` `widgetURL` reaches `application(_:open:)` unregistered, and a click without one arrives as an `NSUserActivity` of the intent's type; Session R step 8 | No scheme registered; W-3c takes both routes. If step 8 shows a click with BatteryPulse quit opening nothing, the scheme is registered before release (§7.3) |
| **G7-10** size | ceilings and cuts | the CI size report (§9) | Within 0.6.1's ceilings: a raise in a commit of its own. Above: §9's cut order |
| **G7-11** reload delivery | whether the planner keeps percent-step reloads | the logged day: at least 90 % of the requests delivered per kind (P2 §8.10). Delivered = a `widget.timeline` of that kind before the next request; the median delay is reported (W-12 item 2) | Keep the Linux-tested planner; the measurement joins 0.8's sitting. A share under 90 % drops percent-step reloads only when deliveries are missing entirely, not merely delayed: WidgetKit may postpone a widget nobody can see until it becomes visible (https://developer.apple.com/documentation/widgetkit/keeping-a-widget-up-to-date) |
| **G7-12** accessibility | the widget's accessibility labels | W0-5's photos set the requirements (W-3b item 5); the label builder's Linux tests; Session R step 7's tree read (the session's `ui` helper, or Accessibility Inspector by computer use), never VoiceOver driven by the maintainer | The Linux tests stand, and the row stays open in `docs/VERIFICATION.md` |
| **G7-13** Russian edit sheet | whether the sheet's strings need W-2's fix | W-2 item 5's check of the metadata's strings (CI); Session R step 4.3 (in Session A, D-8's method reached the widgets, not the sheet) | The check failing: W-2's fix before W-3a merges. Step 4.3 still English with the check passing: "not checked"; `WidgetTextBudget` covers lengths |
| **G7-14** `bpulse` JSON | S-1 ships | D1's golden diff | Required (Linux); no M5 needed |
| **G7-15** update path | the release | F12 (at the logged day's end, §6.3); §6.4 | F12 fails: as 0.6.2's G-16 (the installer's last good code). §6.4 step 3 shows 2 or 4: `--prerelease`, fix forward |
| **G7-16** crashes and faults | whether the RC can ship | Session R and the logged day's `day-end` count (§6.3) | Any BatteryPulse or BatteryPulseWidget crash report, or any `fault` in the subsystem: no D3. Fix forward, build a new RC and repeat the Session R steps the fix touches |
| **G7-17** placed kinds | whether W-4 filters reloads by `currentConfigurations()` | Session R step 9's per-kind counts (W-4 item 3) | Not shown to match: an empty answer keeps counting as "placed" for Battery |
| **G7-18** Charge Limit | W-14 in 0.7 | **Answered: both came with the final `A.md`** (D-13): the redacted capture (`docs/plans/0.7.0/sessions/A/charge-limit-80.plist`, which becomes `m5-macos27-charge-limit.plist`) and the 100 % diff (bit 24 clears at 100 % and returns at 80 %; W-14 "Settled by the 100 % diff"); Session R step 9b | No fixture by C1 (a capture that fails the Fixtures README's check): W-14 moves whole to 0.8 (FEA-35, beside NEW-01), before anything frozen ships |

### 7.2 Cut line

**Never cut:** W-0, S-1, W-1, W-2, W-3a, W-3b with large, W-3c, W-4, W-8 (W0-4 (1) passed), W-10,
W-12, W-13, W-14, and D1-D3. W-13 and W-14 are the maintainer's decisions, so the budget never cuts
them: W-13 moves whole to 0.8 only if review finds a promise of §11 it can't keep, and W-14 only
without its fixture by C1 (G7-18; the capture and the 100 % diff came with the final `A.md`).

**Conditional:** K-1 (M-9 is yes; it needs the maintainer's key by C1), and extra large (Q-W10;
declared only on an explicit 1 or 2 in look-check question 3). W-11 and FEA-21 are in
(Q-W4 and Q7-5, decided by delegation) but are cut early if the budget runs short (below).

**Cut in this order if the budget runs short** (a cut option is cut before D1, §3):
1. the stretch (W-7, W-6, W-5 → 1.1);
2. C-1;
3. SIZ-07;
4. FEA-21;
5. W-11 (the drawn battery isn't offered);
6. extra large (a family can be added later without breaking anything);
7. R-1's NEW-18 file (→ 0.8);
8. K-1 (→ 0.8).

**Effort, in runs [estimate]:**

| Package | Runs | | Package | Runs |
|---|---|---|---|---|
| S-1 | 1 | | W-3c | 2 |
| R-1 | 1 | | W-8 | 2 |
| W-1 | 3 | | W-11 | 1-2 |
| W-2 | 2 | | W-12 | 2-3 |
| W-3a | 3 | | K-1 | 1 |
| W-3b | 3 | | W-10 | 2 |
| W-4 | 2 | | D1+D3 | 2-3 |
| W-13 | 2 | | W-14 | 2 |

- **Totals:** about 31-34 runs, plus 3 to fix forward. The never-cut set is about 28-30 (the total
  without R-1, K-1 and W-11).
- **RD §3 and §3.2 carry 28-31** (W-13's 2 runs included, written 2026-10-22) **plus about 2 for
  W-14** (FEA-35) **and about 1 for the hands-free mode** (W-12, 2026-10-23); RD §3.3 counts
  FEA-35's 0.8 number as +1-2 runs, net of NEW-01's Charge Limit cause. RD's first estimate, 18-24
  for the MVP, left out D1-D3, the riders (S-1, R-1, K-1), W-11 and the extra review run that
  splitting W-3 costs.
- **Extra work:** C-1 0-2; the stretch 8-9; D-17's 0.6.3, only if 0.6.2 shipped without the
  pre-swap end, about 1 plus its after-publishing check; rebuilding the session script if D-11's
  copy is missing 1, plus 1 for the hands-free helpers (D-11). No W-0S and no G7-2 fallback: the
  spikes answered both.

### 7.3 Frozen surfaces 0.7 changes on purpose, and how the notes say so

PB §3.4's list and P2 §7.3's additions hold, except these intended changes:

| Surface | 0.6.x | 0.7 | Release notes line (§13) |
|---|---|---|---|
| **The Battery widget's kind** `io.github.nikitausov.BatteryPulse.battery` | `StaticConfiguration`, small and medium, one look (`BatteryPulseWidget.swift:17-27`) | The same kind string, now an `AppIntentConfiguration` with families small, medium, large and (per Q-W10) extra large. Automatic keeps small and medium as they were, except: "tomorrow" on a later-day end; the attention row for an abnormal condition or high heat (in small, in place of the time line); "Updated %@" when the reading is over 45 minutes old; and "Charged to limit" instead of "Not charging" while the Charge Limit holds the charge (W-14) | "Your widget keeps its look. Control-click it and choose Edit Widget to pick what it shows" |
| **A new kind**, `io.github.nikitausov.BatteryPulse.accessories` (G7-8) | — | Small, medium, large | "An Accessories widget shows your keyboard's, mouse's and headphones' batteries" |
| **The reload policy** | `WidgetReloadPolicy` (`BatteryPresentation.swift:126-180`) | `WidgetReloadPlanner`: also on Low Power Mode, adapter, condition and thermal changes; only for placed kinds | No line (behaviour inside the budget) |
| **`bpulse --device <n> --json`**, and `--input` of a device capture with `--json` | `firstUseDate` in seconds since 2001 (`main.swift:190-191`) | ISO 8601 strings, like `--json` | "For scripts: `bpulse --device <n> --json` writes dates as ISO 8601 strings, like `bpulse --json`; every JSON object `bpulse` prints now has a `formatVersion` field. `--accessories --json` is unchanged" |
| **`bpulse --json`, `--watch --json`** | No version field | `formatVersion: 1` | (the same line) |
| **Settings keys** (RD C14 item 1) | PB §3.4's list, plus `betaWindowStyles`, plus `openAtLogin` only if 0.6.2 added it (not expected: 0.6.2's A0 saw the login item kept, so WP-16 item 5 has no cause) | **Three added (W-13):** `anonymousVersionCount` (Bool; a missing key means on, and only the toggle writes it), `lastCountedVersion` (String `x.y.z`) and `versionFirstLaunch` (Date). **One added (W-4):** `lastSeenLanguage` (String, a localization identifier such as `en` or `ru`; absent until 0.7's first launch, written only when the app's effective language changes, so a launch in another language reloads every placed widget). None is changed. Widget configuration lives in macOS's widget configuration, not in our domain | W-13's "Anonymous version count" line (§13 step 2) |
| **Release assets** (RD C14 item 6, the update contract) | `BatteryPulse.dmg`, `BatteryPulse.dmg.sig` and `BatteryPulse-dSYMs.zip` (`release.yml:151`) | Plus `BatteryPulse-count.txt` on every release from v0.7.0, never removed from a published release (W-13) | (the same line) |
| **Update traffic** (`UpdateNetwork`) | Ephemeral sessions without a URL cache; cookies kept in memory while the app runs (VC-5) | No cookies stored or sent (W-13 decision 6) | — |
| **Internet requests** (RD C14 item 8; UG:502-509; RM:120-125) | The update check, and a download the user chose | Plus the version count: once per version, at least 24 h after it first ran, on an automatic check that reached GitHub; never under Never or with the toggle off (W-13) | (the same line) |
| **`@SceneStorage("mainSelection")`** | `SidebarItem.storageKey` strings | The same strings, now `PageID`'s raw values, pinned by a test | — |
| **The app's Info.plist** | No URL types (`build-app.sh:111-132`) | Still none: the `batterypulse` URL reaches the app unregistered (W0-4 (5)). A navigation-only `CFBundleURLTypes` entry only if Session R step 8 shows a click with BatteryPulse quit opening nothing (G7-9) | No line: a click is the user-visible part |
| **The app's state words** (Overview, Power, the popover, the compact window) | "Not charging" while the Charge Limit holds the charge | "Charged to limit", and Power's "Charge limit: Reached" row (W-14) | W-14's line (§13 step 2) |
| **`ChargeState`** (History files, `bpulse --json`) | Five cases (`charging`, `discharging`, `charged`, `notCharging`, `unknown`; `BatterySnapshot.swift:162-170`) | Unchanged: the Charge Limit's state is a computed property (W-14), so no new case reaches History or `--json` | — |
| **The appex** | Binary, strings, Info.plist | Plus `Contents/Resources/Metadata.appintents` | — |
| **The widget's entitlements** | Sandbox only (`Resources/BatteryPulseWidget.entitlements`) | Unchanged in the MVP. The stretch adds one read-only exception | (stretch) a privacy line (§11) |
| **Storage** | PB §3.4 | Unchanged in the MVP. The stretch adds `Widget/feed.json` | (stretch) the guide's privacy section |
| **`WhatsNew.version`** | 0.6.0 (`UpdateViews.swift:387`) | 0.7.0 (Q7-2) | — |
| **`CFBundleVersion`** (the build number) | each workflow's own `run_number` (ci.yml:201, 407; release.yml:109) | one clock that only grows, in both workflows (D1, §6.5) | No line; About shows the new number (`AboutView.swift:54`) |
| **Signposts** | `widget.reload` (`policy`, `update`) | Plus `widget.timeline` (triggers `battery`, `accessories`) and `widget.reload` `policy.accessories` | — (CL's list) |

**New frozen surfaces 0.7 creates** (P2 §8.13; promised for 1.x in RD C14 item 5):
- the kind strings;
- the intent type names (a click without a `widgetURL` arrives as an activity of that type, W-3c),
  the parameter names, every `AppEnum` raw value, and the Details entity's ids (the field raw
  values, W-14's `systemChargeLimit` included);
- `supportedFamilies` per kind, which are only ever added to;
- Automatic's meaning in each family;
- the `PageID` and `WidgetRoute` strings, with the `batterypulse` scheme (unregistered unless G7-9
  registers it);
- W-13's three settings keys and W-4's `lastSeenLanguage`, with their meaning (RD C14 item 1);
- the release asset `BatteryPulse-count.txt` on every release from v0.7.0 (RD C14 item 6).

W-1's `WidgetSurfaceTests` pins the widget's surfaces, W-13's tests pin the asset's name and
`release.yml`'s attachment, and D1's identifier `git grep` lists the new kind strings and keys.

---

## 8. Localization

**Rules** (CL "Localization"; P2 §8.11):
- **Keys:** every literal is a `LocalizedStringKey` or `String(localized:)`, keyed by its English
  text, with its Russian in `Resources/Localizable.xcstrings`.
- **Placeholders:** `%@` only, unless W0-1 (d) forces one reasoned exception for the widget's
  intent files (W-10).
- **Wording:** Apple's Russian terminology, from System Settings → Battery.
- **No counted phrases:** a label and a number, so no plural variations.
- **Spelling:** the catalog's English follows macOS's US spelling (it has "Optimized charging"), so
  the new keys say "Colors". The docs' prose keeps its own spelling.
- **Where intents live:** App Intents types and their strings live in the widget target only. An
  Apple forum thread reports raw keys showing for intent strings from a package
  (developer.apple.com/forums/thread/806804, via P2 §8.11) [unverified here]; REJ-60.
- **Size:** the widget bundle gets the whole compiled catalog (`build-app.sh:142`), so each key
  costs twice in `strings_bytes` (§9).

**New keys (English), by package.** The final wording is settled in the look check (§6.1 question 7)
and W-10's terminology pass. Keys marked (if …) exist only when their option ships.

| Package | New keys |
|---|---|
| W-3a, gallery and intent | "Charge, time remaining and the details you choose." (the gallery description; it replaces "Charge, time remaining and battery health.", which is then removed as unused) · "Choose Battery Details" (the intent's title) · "Choose what the Battery widget shows." (its description) |
| W-3a, parameters | "Layout" · "Main value" · "Main visual" · "Status lines" · "Colors" · "Update time" |
| W-3a, cases | "Detail" (the Details entity's type name; its items reuse the field labels) · "Automatic" · "Custom" · "Number and symbol" · "Drawn battery" (if W-11) · "Time to full or empty" · "Clock time" · "Time left" (if G7-3) · "Level colors" · "Monochrome" · "When old" · "Always" |
| W-3a, summaries | one `Summary` key per `ParameterSummary` branch (P2 §8.5: Automatic; Custom; Custom in small), worded with W0-1 (d)'s placeholder form [count uncertain: 2-4] |
| W-3a, text | "Lasts until about %@ tomorrow" · "Full at %@ tomorrow" (P2 §8.6) · widget-only short forms of reused keys that are over `WidgetTextBudget` (W-1 item 5), each with its Russian, named in the commit [count unknown until W-1's test runs] |
| W-3b | "Cycle life used" · "Cell balance" (P2 §8.5's catalogue) · panel headings only if the extra-large layout needs words beyond "Battery" and "Power" |
| W-8 | "Batteries of your keyboard, mouse, trackpad and headphones." (gallery) · "Choose Accessories" (intent title) · "Choose which accessory batteries the widget shows." · "Lowest only" · "No accessories with batteries connected" · "Try the Accessories widget" (the Battery widget's no-battery state, if W-8) · "Hide fully charged" (FEA-21, Q7-5; unless cut) |
| W-14 | "Charged to limit" (the state; Apple's battery-menu wording "Charged to [%] Limit" without the number) · "Charge limit" (Power's row, the widget field and the Demo scene's title) · "Reached" (their value in 0.7) · "Charging stopped at the Charge Limit set in System Settings → Battery." (Overview, and the Demo scene's detail) · `NotChargingReason`'s glossary line with its bit 24 sentence (it replaces today's line). The Russian follows Apple's Russian support article for the Charge Limit (https://support.apple.com/ru-ru/102338) and System Settings → Battery's own string, verified at implementation (W-10 item 1); the catalog's translation of "Charging on hold" is not reused |
| W-13 | "Include this Mac in the anonymous version count" (the toggle) · its footer, "Once per version, at least a day after you start using it, …" · "Anonymous version count" (the What's New title) · its detail, "Once per version, BatteryPulse downloads a tiny file from GitHub, …" (W-13 has the full texts). The Russian uses the catalog's own terms for Check for updates, Never, Settings → General, a release and a download |
| W-10, What's New | 2-3 features' titles and details (Q7-2), for example "Widgets you configure" and "Accessories widget", each with a one-sentence detail, beside W-13's row |
| Stretch (W-5 to W-7) | P2 §8.5's History and iPhone & iPad parameters and states, among them "Open BatteryPulse to update" and "This device was forgotten" |

**Reused keys** (already in the catalog with their Russian; checked 2026-10-22 against
`Localizable.xcstrings`, 719 keys):
- "Battery" · "Power" · "Accessories" · "Details" · "Time" · "State" · "Show" · "All" · "Ring"
  (already translated for the menu bar's Ring style, `App/Localized.swift:252`);
- "Charge" · "Maximum capacity" · "Temperature" · "Battery power" · "Condition" · "Cycle count";
- "Adapter" · "System load" · "Power from adapter" · "Low Power Mode" · "Voltage";
- "Remaining capacity" (the "3,912 of 4,512 mAh" row, through "%@ of %@") · "of %@ rated";
- "Thermal state" · "High" · "Critical" (`App/Localized.swift:159-161`) · "Service Recommended" and
  the other conditions;
- "Updated %@" · "Lasts until about %@" · "Full at %@";
- "This Mac has no internal battery." · "No battery information" · "Low battery";
- the state words ("Charging", "On battery", "Fully charged", "Charging on hold", "Not charging");
  "Charging on hold" stays Optimized Charging's, never the Charge Limit's (W-14);
- "Battery charge: %@, %@" (a candidate for the charge block's VoiceOver label);
- the six unit symbols ("W", "mAh", "V", "mV", "mA", "A").

**Count [estimate]:** about 25-35 new keys in the MVP, plus W-13's 4 and W-14's 5, and about 15-25
more with the stretch. That is fewer than P2 §8.12's 80-120, because the field labels already
exist in the app.

**Checks:**
- `LocalizationCatalogTests`, extended to the App Intents forms (W-1 item 11), fails on a missing or
  unused key.
- `WidgetTextBudget` (W-1) fails a Russian text that is too long for its slot.
- `scripts/string-tables.swift` checks every table in both bundles (`build-app.sh:147`).
- W-2's `appintents-check` (item 5) checks that the edit sheet's strings are catalog keys the
  widget bundle translates; Session R step 4.3 tries the sheet in Russian (in Session A, D-8's
  method reached the widgets, not the sheet).

---

## 9. Size budget

**Where it starts** (CI run 39751622292, at `9410861`; P2 §8.1):

| Measure | Today | Ceiling (`size-budget.json`) |
|---|---|---|
| Widget binary | 1,379,808 B | 1,450,000 B |
| Widget `__text` | 943,096 B | 990,000 B |
| String tables, both bundles | 238,124 B (R:457) | 251,000 B |
| Installed app | 4,608 KB (R:453) | 4,840 KB |
| DMG | 1,439,093 B (R:452) | 1,520,000 B |

**0.6.2's effect:**
- K-03 frees about 187 KB of the widget, and internalize about 27 % of its `__text` (P2 §2.3,
  WP-15). Both are [estimate] until 0.6.2's CI numbers exist.
- D1 of 0.6.2 lowers the widget ceilings to its RC plus about 5 % (D-7).

**0.7's growth [estimate, P2 §8.12]:**
- **Widget `__text`:** about 100-250 KB for the views, the App Intents conformances and the
  accessory read.
- **`Metadata.appintents`:** a new row, `widget_appintents_bytes`, with its own ceiling (W-2), size
  [unverified].
- **`strings_bytes`:** about 25-35 new keys × 2 bundles × Russian only (English ships no table,
  `build-app.sh:143-146`). With roughly 100-150 B per key per table [estimate], that is about
  5-11 KB, less the 0.6.0 What's New keys W-10 removes.
- **W-13:** about 2 KB per string table, so about 4 KB of `strings_bytes` across both bundles
  [estimate: its four keys' English and Russian texts are 2,092 B in UTF-8, the footer the
  longest]. The widget's code is unchanged; it only carries the larger table, as every bundle
  does.
- **W-14:** five keys, about 1 KB per string table [estimate], and a few hundred bytes of
  `__text` for the state word and the field.

**Rules:**
1. **Raises:** every raise is a commit of its own that says why (`size-budget.json` "about"), at D1,
   at the RC plus about 5 %.
2. **The outer bound:**
   - The widget stays within **0.6.1's ceilings**: 990,000 B of `__text` and 1,450,000 B of binary.
     If K-03 and internalize shipped, it should fit with room to spare.
   - The DMG stays under 1,520,000 B, and `app_kb` under 4,840 KB. If either would cross,
     G7-10's cuts come first.
3. **Cut order if a bound is crossed:**
   1. charts are always a `Path` (stretch only; Swift Charts only under 15 KB of `__text`, P2
      §8.12);
   2. SIZ-07, a widget-only string table, about half the widget's `.lproj` (P2 §8.12);
   3. W-11;
   4. extra large;
   5. W-0K (K-03 run in 0.7) if 0.6.2 didn't ship it.
4. **Recorded per commit** that touches the widget: `__text`, the binary, `widget_appintents_bytes`
   and `strings_bytes`.

---

## 10. Energy: the reload budget and the timeline policy

**What Apple allows** (https://developer.apple.com/documentation/widgetkit/keeping-a-widget-up-to-date):
- **The budget:** "a daily budget typically includes from 40 to 70 refreshes" for a widget the user
  views often. Each placed widget has its own budget, over a 24-hour window tuned to the user's
  habits.
- **Free reloads:** reloads don't count while the containing app is in the foreground, after an app
  intent performs, or when the locale or "Dynamic Type or Accessibility settings change".
- **What not to request:** "For cases such as system appearance changes or system locale changes,
  don't request a timeline reload from your app".
- **Throttling:** WWDC26 session 277 adds that frequent reloads while the app is in front "might be
  throttled" (P2 §8.2).
- BatteryPulse is an agent app that is rarely in front, so its reloads count.

**The timeline policy:**
- **Battery:** today's plan (`BatteryPresentation.swift:186-238`).
  - It refreshes after 30 minutes, with a 15-minute minimum.
  - An entry at the estimate's end removes the estimate.
  - 0.7 adds a stale entry at reading + 45 minutes, at most 3 entries (W-1). Extra entries cost no
    reload (P2 §8.6).
- **Accessories:** 30 minutes.
- **The stretch's kinds:** History hourly; iPhone & iPad 30 minutes.
- **Never closer than 15 minutes.**
- **Time text:**
  - Clock time stays right between reloads.
  - Time left updates by itself through a `SystemFormatStyle` date offset without seconds and with
    `sign: .never`, at no reload cost (§2.2 W0-6).
  - No `TimelineView` that ticks, no `.timer`, `.relative` or `.offset` text styles, and no
    `Text(timerInterval:…)` or `ProgressView(timerInterval:…)` (W-10's guard).

**The reload budget** (W-4, tested on Linux):
- **Battery:** within today's count for E15's synthetic day plus 7 (P2 §8.10).
  - Today's bound in the test is `2 × plug changes + other state changes + 4 × awake hours`
    (`WidgetReloadPolicyTests.swift:170-171`).
  - P2 §8.1 puts the day at about 40.
- **All MVP kinds placed:** under about 100 app-initiated reloads a day, each kind within its own
  budget.
- **Only placed kinds are reloaded** (`currentConfigurations()`), once Session R shows its answer is
  real; until then an empty answer counts as "placed" (W-4 item 3, G7-17). Demo Mode reloads
  nothing.
- **The new immediate reasons are bounded:** a 5-minute minimum between them, and hysteresis on the
  thermal reason (W-4 item 1).
- **No new wake-up:** the planner is called from the existing observations, and the
  `currentConfigurations()` refresh happens only at a reload moment. No sleep, timer or activity is
  added, so `EnergyGuardTests` stays as it is apart from EN-11's message.

**Reads:**
- **One read per burst,** shared by every kind and instance that reloads together, through
  `WidgetReadCache` with a 5-second window (P2 §8.10).
- **Costs:** a widget read is the registry, children, IOPS, adapter and parse, without the SMC: about
  6.4 ms on the M5 at p50 (P2 §2.1: 4.501 + 1.069 + 0.325 + 0.408 + 0.153 ms). An accessory read is
  about 0.3 ms.
- **Per day [estimate]:** two Battery widgets and one Accessories widget at about 50 timelines each
  make about 150 timelines, which share reads in bursts. That is under 1 second of CPU a day for
  the widget's reads.

**Measured** (Session R, the logged day; G7-11):
- per kind, the reloads requested (`widget.reload`) against the timelines delivered
  (`widget.timeline`), with the median delay. If fewer than 90 % arrive and the rest are missing
  entirely, not merely delayed, the planner drops the percent-step reloads first (P2 §8.10;
  G7-11);
- the widget extension's reads and their total time per day (the `read` intervals in the widget's
  process; 0.6.1's session saw the widget read 2-32 times per process, P2 §2.1);
- `pmset -g assertions | grep -c BatteryPulse` = 0 at `day-end`, as 0.6.2's runs check (P2
  WP-21).

**W-13 adds no wake-up.** The version count rides on a due automatic check: the same task, the same
`update.check` interval and the same network conditions, at most one request per Mac per version.
It adds no sleep, timer, task or signpost name, so `EnergyGuardTests` is unchanged and `oneShots`
stays at four.

0.6.2's S1 and S2 stay the app's budget. 0.7 adds no app energy run of its own: the reload planner
reacts to the same observations and adds no wake-up, and neither does W-13. The final 0.9.x energy run (RD C5) covers the
app with widgets placed.

---

## 11. Privacy

- **The widget has no network:** no `URLSession`, no `Network` and no push (REJ-57; W-3a's guard).
- **The app's internet requests in 0.7** (UG:502-509, reworded by W-13; RD C14 item 8, already reworded):
  the update check (daily, weekly, monthly or never), a download the user chose to install, and
  W-13's version count. All three go only to GitHub, through `UpdateNetwork`'s ephemeral sessions.
- **Usage numbers:** the only usage numbers are GitHub's public download counts (DMG, `.sig`, and
  from 0.7.0 `BatteryPulse-count.txt`), read a week after publishing (§13 step 8, NEW-23). The
  count's request carries no identifier and nothing about the Mac, its battery or its settings.
- **No cookies:** update traffic neither stores nor sends cookies (W-13 decision 6; VC-5).
- **No new file and no new entitlement in the MVP.** The widget reads IOKit, and accessory
  batteries through the one-shot provider. Its entitlements stay the sandbox alone, pinned by W-1.
- **What macOS stores:** the widget's configuration, which holds only the choices of §8's cases. No
  name and no identifier in the MVP.
- **Names:** accessory names (and, in the stretch, device names) get `.privacySensitive()`.
  - Apple documents the `.privacy` redaction only for the Lock Screen and Always On (P2 §8.8). It is
    a cheap defence in case macOS ever redacts widgets; W0-4 (3) logged nothing about it.
- **No hardware-derived identifiers:**
  - `AccessoryBattery.id` never enters the widget (`Accessory.swift:120-130`).
  - In the stretch, a device is identified by its `DeviceKey` string, an HMAC-derived key (CL:
    `DeviceKeys` HMAC), never a UDID or a serial (P2 §8.3, §8.5).
- **Logs:**
  - Triggers are `StaticString` case names; the kind string and any name never go in a log.
  - A click logs how it arrived (`url` or `activity`) and its page's case name as `.public`
    (`overview` … `accessories`, or `device`), and a
    device page's `DeviceKey` only as `.private(mask: .hash)`; never a full URL (CL logging: "a
    device key logs as `.private(mask: .hash)`"; P2 WP-W0 "Logs"). `device:<key>` is a page ID
    (`MainView.swift:74`), so the page ID itself is never logged `.public`.
  - The per-kind counts from `currentConfigurations()` are numbers, logged `.public` (W-4 item 3).
- **No URL scheme is registered** (G7-9): the widget's `batterypulse://` URLs reach BatteryPulse
  through WidgetKit without one (W0-4 (5)), so no other app or web page can open its pages.
  `WidgetRoute(url:)` accepts known pages and valid `DeviceKey`s only, and a link never acts (P2
  §8.9); the activity route opens only our intent types' pages (W-3c). If Session R step 8
  forces a registered scheme, it stays navigation only: any app or web page could then open a
  page of BatteryPulse, and nothing more.
- **The Charge Limit** (W-14): BatteryPulse reads the gauge's reason bit it already reads, and
  nothing about the configured limit; no new source, process or framework.
- **The stretch's feed** (P2 §8.3, §8.8; INV SEC-08, DOC-08):
  - It holds only what the widgets show: no `Devices/key`, no UDID or serial, no Demo data.
  - The folder is 0700, the file 0600, at most 8-12 KB.
  - It is rewritten at once on Clear History, Forget, or turning off device reads or recording.
  - The guide's privacy text lists it.

**The privacy statement** (W-13 puts it, word for word, in new "Privacy" sections of README and
USER_GUIDE):

> **Privacy.** BatteryPulse has no account, no analytics service and no server of its own. Your
> battery readings, history, devices and settings stay on your Mac. It connects to the internet
> only to reach GitHub: to check for updates (daily, weekly, monthly or never, as you choose in
> Settings → General), to download an update you chose to install, and, from 0.7, for an
> anonymous version count. Once per version, at least a day after you start using it, an automatic
> update check also downloads a small file from that version's release on GitHub. GitHub counts
> downloads, and that public count is the only number the developer gets: how many Macs use each
> version. No identifier of any kind is sent, no cookie is kept, and nothing about your Mac, its
> battery or your settings is included. As with any web request, GitHub sees your IP address and
> the app's version, just as it does for the update check, under GitHub's own privacy statement.
> The developer never sees addresses, only totals that anyone can read through GitHub's API. The
> count is on by default, never happens when Check for updates is Never, and turns off with
> **Include this Mac in the anonymous version count** in Settings → General. Reading an iPhone or
> iPad over Wi-Fi (opt-in) stays on your local network.

**Why the count is on by default** (the maintainer's decision, Q7-9; the reasoning behind it):
- **What's sent.** Nothing that identifies a person reaches the maintainer. GitHub already receives
  the same address and version from the update check in the same tick, so the count tells GitHub
  only that the count is on.
- **Why not opt-in.** Few people open Settings, so an opt-in count would measure almost nothing.
- **What makes it honest:**
  - before the count, existing users see the 0.7 release notes in the Software Update window;
  - What's New appears for anyone coming from before 0.7;
  - fresh installs see the setting in the Welcome window;
  - the file itself explains what it is;
  - there is a day's grace before the first count, and a one-click off.
- **Legal position (not legal advice).** The EDPB reads Art. 5(3) ePrivacy broadly (VC-8), so in the
  EU a request like this may fall within its scope. Whether consent is needed depends on an
  exemption. The design matches the CNIL's conditions for audience measurement: users informed, an
  easy objection, aggregate statistics for the publisher only. The exception is GitHub seeing the
  full address, which we can't change. The remaining risk is low for a free hobby app, and turning
  the default off needs no key change (W-13's rollback).

---

## 12. Docs

| Document | Change | Package |
|---|---|---|
| `docs/USER_GUIDE.md`, Widget (UG:408-430) | **Rewritten** (DOC-07): the kinds and their sizes; Edit Widget and what each option does; Automatic keeps the look; clicks open the matching page; the reload rules (UG:419-423, updated: placed kinds only, the new reasons); VoiceOver. "The widget is new…" (UG:428-430) goes. UG:425-426 ("Replacing BatteryPulse with a new version from the DMG removes the widgets") is restated from evidence: R:202-208, D-9, Session R step 2 and §6.4. Whatever the evidence shows stays a documented known limitation at 1.0 (RD C3, C7; M-1 is no, so no signed build will remove it) | W-10 |
| `docs/USER_GUIDE.md`, updates (UG:488-495) | "Widgets may need adding again" kept or narrowed, by the same evidence; permissions after a DMG replacement stay a known limitation (RD C3) | W-10 |
| `docs/USER_GUIDE.md`, Overview, Power and notifications | "Charged to limit" and Power's "Charge limit: Reached" row; that BatteryPulse can't read the limit's percentage; that the app's "When charged to" alert never fires above a lower Charge Limit | W-14 |
| `docs/USER_GUIDE.md`, command line (UG:561-663) | `--device --json` dates and `formatVersion` (UG:620, UG:648) | S-1 |
| `docs/USER_GUIDE.md`, privacy (UG:502-509, UG:351-359) | **W-13:** UG:502-509 reworded (the check, the count and a download you chose); a new "Privacy" section with §11's statement; the devices' "Privacy" (UG:351-359) links to it. **With the stretch:** the feed | W-13, W-10 |
| `README.md` | The Widget bullets (RM:84-86, "new in 0.3") list the configurable sizes and Accessories. The iOS promises go (R-1, DOC-09). "Status: early development" stays until 0.9.0 (RD §3.5, DIS-10). **W-13:** RM:120-125 ("The only requests to the internet are…") reworded, and a new "Privacy" section with §11's statement | W-10, R-1, W-13 |
| What's New | `WhatsNew.version` 0.6.0 → 0.7.0 (`UpdateViews.swift:387`), and `WhatsNew.features` replaced with 0.7's 2-3 plus W-13's "Anonymous version count" (Q7-2), which later releases append for anyone coming from before 0.7 (W-13 item 6). Users coming from 0.6.x see it once (`UpdatePolicy.showsWhatsNew`, `Updates.swift:261`) | W-10, W-13 |
| `CLAUDE.md` | **Layout:** `Sources/BatteryCore/Widget/` (the model, planner, routes and manifest); `BatteryArt` if W-11; the widget's intents and their rule. **The build:** the metadata step and `appintents-check.swift`. **Guards:** the new widget rules (time text, placements, routes). **Signposts:** `widget.timeline` and its triggers; `widget.reload`'s `policy.accessories`. **The placeholder exception,** if any. **Clicks:** the `batterypulse` route, unregistered unless G7-9 registers it, and the activity route for a click without a URL (W-3c). **W-14:** the macOS 27 layout convention gains "bit 24 (0x01000000) of `NotChargingReason` is set while the Charge Limit holds the charge", and Layout lists `SystemChargeLimit`. **Energy:** "widget reloads only in `WidgetRefresher`, through `WidgetReloadPolicy`" becomes "… through `WidgetReloadPlanner` (per kind, placed kinds only)". **Logging:** "an app and a BatteryKit twin" (or BatterySource after 0.6.2's WP-22) gains the widget's twin (W-3a item 8). **Layout, BatteryPulseWidget:** "signed with only the app-sandbox entitlement" gains the stretch's read-only exception, only if W-5 ships. **Releases:** the build number from one clock (D1). **W-13:** "Network" gains the version count and "no cookies"; Layout lists `VersionCounter`; Releases names `BatteryPulse-count.txt` | W-10, W-13, W-14 |
| `docs/ROADMAP.md` | The 0.7 entry (R:543-556, which promises "every size macOS offers" and History, iPhone and iPad widgets) rewritten to what shipped, then ticked; the History and iPhone & iPad widgets, the portrait size and any family not shipped move to a new 1.1 entry (RD §3.8) that links `docs/plans/1.1/widgets.md` (D3); the Decisions edits of R-1 item 1; the build-number decision (D1); the frozen-outputs decision line (R:437-439) gains "device JSON dates and `formatVersion` shipped in 0.7"; Stage 1.2's widget line (R:202-208) updated from §6.4; Stage 4's WidgetKit line; the "Road to 1.0" section (R-1); "Next: 0.8" (RD §3.3); a "Widgets (0.7)" decisions paragraph (the kinds, Automatic frozen, the planner, the stretch's condition: the feed only, as M-1 is no); the Releases row, whose download counts follow a week later (§13 step 8, NEW-23). **W-14:** Stage 1's "a capture at the macOS Charge Limit stop point" (R:145-146) ticked once the fixture is committed. **W-13:** already written on 2026-10-22: the Decisions' "Privacy (0.7)", the Principles' Privacy line and the usage paragraph, which W-13's docs pass checks against what shipped; it adds only the Releases table's Count column from 0.7.0 and the "Road to 1.0" lines for C14 items 1, 6 and 8 | W-10, R-1, W-13, D3 |
| `docs/plans/1.0/ROADMAP.md` | Already written on 2026-10-22: C14 items 1, 6 and 8, §1.1, §1.2 item 6, §3, §3.2 and §3.3, §4.3's Telemetry row, NEW-23, NEW-24 and M-11. W-13's docs pass checks them against what shipped. **W-14:** already written on 2026-10-23 (FEA-35, FEA-20, QUA-05, NEW-01, M-3, §3.2-§3.3: the "at limit" state in 0.7, the configured percentage as FEA-35's 0.8 half with W-14's candidates); W-14's docs pass checks them against what shipped | W-13, W-14 |
| `docs/plans/1.0/INVENTORY.md` | Already written on 2026-10-23: FEA-35 (new), FEA-20, FEA-27, QUA-05, QUA-06 and the Summary's counts. W-14's docs pass checks them against what shipped | W-14 |
| `docs/VERIFICATION.md` | New (R-1); 0.7's rows filled at D3 | R-1, D3 |
| `.github/ISSUE_TEMPLATE/bug_report.yml` | The app version, how it was installed, no iOS | R-1 |
| `.github/ISSUE_TEMPLATE/feature_request.yml` | The platform list offers only macOS (:17) | R-1 |
| `.github/release-notes.md` | §13, with W-13's line (step 2) | W-10, D1 |
| `.github/BatteryPulse-count.txt` | New: ASCII, English, at most 1 KB; what the file is for and how to turn the count off | W-13 |
| `scripts/release-stats-sample.json`, `.expected` | A release with `BatteryPulse-count.txt` and its count, so CI's table diff covers a filled Count column | W-13 |
| `.github/workflows/release.yml` | Checks, attaches and verifies `BatteryPulse-count.txt`, with a comment that it is never removed (W-13); the build number from one clock (D1) | W-13, D1 |

---

## 13. Release steps

1. **Version.** The tag `v0.7.0` sets `VERSION`, and the release run sets `BUILD_NUMBER`
   (`release.yml:93-109`) from the growing clock D1 introduced, so 0.7.0's number is above RC-U's.
2. **Notes:** `.github/release-notes.md` opens with `## What's new in 0.7`. `release.yml` accepts
   "0.7" or "0.7.0" (`release.yml:49-62`), and D1 runs that check on the draft. The notes list only
   what landed:
   - the configurable Battery widget, the sizes it comes in, and "your widget keeps its look; Edit
     Widget to choose";
   - the Accessories widget (G7-8);
   - W-14's line, if it shipped (G7-18): "When the Charge Limit in System Settings → Battery stops
     charging, BatteryPulse now says 'Charged to limit' in the app, its menu bar panel and the
     Battery widget. It can't read the limit's percentage yet.";
   - "clicking a widget opens the matching page";
   - the stretch's widgets, if they shipped, with the privacy line about the feed;
   - "For scripts: …" (S-1's line, §7.3);
   - W-13's line, as written: "**Anonymous version count.** Once per version, at least a day after
     you start using it, an automatic update check also downloads a small file,
     `BatteryPulse-count.txt`, from that version's release; its public download count shows how
     many Macs use each version. Nothing else is sent: no identifier, nothing about your Mac, its
     battery or your settings; GitHub sees your IP address, as it does for the update check. It is
     on by default, never runs when Check for updates is Never, and turns off in Settings →
     General.";
   - if the backup key landed: nothing for users, but ROADMAP records it;
   - if §6.4 or Session R saw widgets gone across the update: "If a widget is gone after the
     update, add it again from the gallery";
   - "Updating from 0.6.2: Install and Relaunch."
3. **ROADMAP:** a Releases row `| 0.7.0 | <date> | … |` (R:691-699), its download counts, Count
   included, left for step 8; §12's changes.
4. **Remove `docs/plans/0.7.0/`** in the last commit, after ROADMAP holds the lasting decisions and
   `docs/plans/1.1/widgets.md` holds what 0.7 didn't build (D3). The ci.yml lines that name it (the
   queue dry run, `bash -n`, the helpers' type-checks) go with it (P2 D3). The commit before it is
   `<keep>`, from which §6.4's short session reads its runbook and script (§6.2, "The short
   sessions").
5. **The PR** `claude/070-integration` → `main`: the D1 draft is marked ready, with the numbers,
   Appendix C and the session results. Both jobs green with 0 warnings. Merged after the
   maintainer's OK.
6. **Tag and release:** `git tag v0.7.0 <merge-sha> && git push origin v0.7.0`, or the workflow by
   hand. The maintainer approves the `release` environment run before any step runs
   (`release.yml:6-9`).
   - `release.yml` checks `.github/BatteryPulse-count.txt` before building, attaches it beside the
     DMG, its `.sig` and the dSYMs, and after publishing checks that the release lists it (W-13).
   - On its `::error::`, run the `gh release upload` it names before anyone has run 0.7.0 for a
     day.
7. **After publishing** (§6.4, with W-13's count in step 6; its start line on the release PR, with
   the PR's number and step 4's `<keep>`, §6.2), with `gh release edit v0.7.0 --prerelease`, on
   his yes, as the rollback.
8. **A week after publishing** (NEW-23; RD §1.2 item 6): run 0.6.2's `swift
   scripts/release-stats.swift`, which prints each release's DMG, `.sig` and
   `BatteryPulse-count.txt` downloads ("—" before v0.7.0). Record v0.7.0's row in ROADMAP's
   Releases table, in a commit of its own, with the Count column W-13 added (D-16 says what to do
   if the download columns or the script are missing; the fallback is `gh api
   repos/{owner}/{repo}/releases/tags/v0.7.0 --jq '.assets[] | "\(.name) \(.download_count)"'`).
   - Each in-app install fetches the `.sig`, so its count is a privacy-free proxy for in-app
     updates.
   - The DMG and `.sig` counts include the maintainer's own downloads and the release's signature
     check, so they are an upper bound on anyone else's.
   - The Count column is the number of Macs that ran 0.7.0 for a day with automatic checks and the
     count on, the maintainer's Mac included (W-13). It keeps growing after the week: a Mac on a
     monthly check counts up to a month after it started the version. Macs behind one shared
     address that count within the same ~10 minutes merge into one (VC-3). So the week-later
     number is a floor.

---

## 14. The maintainer's questions and their answers

**Answered on 2026-10-22.** The maintainer answered M-1 (no), M-5 (approved as written, with no
dates), Q-W1 (yes) and Q7-9 (an anonymous version count, on by default), and Q-W3 (yes) follows from
his M-1 answer. On 2026-10-23 he asked for Q7-10 (show the Charge Limit). He delegated every other
question here ("do it by best practices, as you see fit"), so each is decided as its recommended
answer, marked "decided by delegation". The looks these decisions lead to are still signed off in
the look check (§6.1), where another answer changes them. Technical choices are not asked, as
agreed in P1 §8 ("Architecture: delegated"). They include App Intents, the planner, routing, the
URL scheme, tests and guards, the build step and the size sequencing.

### Before 0.7 starts (RD §6)

- **M-1, the paid developer account. Decided by the maintainer (2026-10-22): no.** Not now, and
  not planned before 1.0. His reasons: a non-commercial hobby project; he will not pay for an Apple
  developer account for this app (he is willing to spend on development help, not on the
  account); and about zero users.
  - **Usage evidence** (GitHub's REST API, 2026-10-22):
    - DMG downloads across all releases: 14 in total (0.2.0: 1, 0.3.0: 2, 0.3.1: 4, 0.4.0: 1,
      0.5.0: 2, 0.6.0: 3, 0.6.1: 1, the last being a signature check during the release);
    - signature (`.sig`) downloads: 5. Each in-app install fetches the `.sig`, so this count is a
      privacy-free proxy for in-app updates;
    - repository page views: 2, by 1 visitor, in 14 days; no stars, forks or outside issues.

    By 14:26 UTC the same day the totals were 15 and 6, after his own 0.6.0 → 0.6.1 in-app update
    (0.6.2's A0; Appendix B). So the users are, in practice, the maintainer alone. From 0.6.2's D3
    on, each release records its counts a week after publishing (§13 step 8, NEW-23), and from
    0.7.0 W-13's version count adds one number per release: the Macs that ran it (Q7-9). 0.7's scope
    stays as planned: its sittings check the Mac the widgets run on, and 1.0's "ready for others"
    scope is unchanged (RD §2; M-5).
  - **For 0.7 this means:**
    - **No App Group.** The History and iPhone & iPad widgets can only use the app-written copy of
      readings (the feed, W-5; Q-W3 is yes). W0-3 passed (Session A), so they come in 0.7's stretch
      if the budget allows, otherwise in 1.1 on the feed.
    - **Nothing waits for a signed build.** Developer ID signing and notarization are not planned:
      gate G-ID, the throwaway spike S-ID and the Developer ID runbook are off the path to 1.0
      (RD §3.4). No Developer ID spike runs during 0.7, and 0.9.0 has no Developer ID item.
    - **Known limitations at 1.0:** Open Anyway on each DMG install, and permissions or placed
      widgets possibly lost when a DMG replaces the app (RD C3, C7, C16). 0.7 records what Session
      R step 2 and §6.4 show, and the guide says it (§12).
    - **Enhanced Security and the package manager's official catalog** stay not planned: both
      needed notarization (RD §4.2).
  - **Kept as background, in case he changes his mind** (RD M-1):
    - An App Group is the documented way for an app and its widget to share data, and it needs a
      Team ID: app groups belong to one development team, and macOS group IDs are `<team
      identifier>.<group name>`
      (https://developer.apple.com/documentation/bundleresources/entitlements/com.apple.security.application-groups;
      P2 §8.2). macOS 27 also denies other teams' containers without a prompt (NOTES27 161835690).
    - A stable signature may keep placed widgets and permissions across updates (R:202-208,
      R:180-181) [unverified for widgets].
- **M-2, an iOS app. Decided by delegation (2026-10-22): not in 1.x.** R-1 removes the iOS
  promises from README (with the iOS column of "What each platform exposes") and both issue
  templates, and ROADMAP's Decisions say "Not in 1.x".
- **M-3, charge limiting. Decided by delegation (2026-10-22): not in 1.x.** R-1 drops "(and later
  charge limiting)" from ROADMAP's Decisions. **Clarified 2026-10-23, by delegation (RD M-3; W-0
  found it on 2026-10-30):** "no private reading of the limit" means no private framework loaded
  into BatteryPulse. A read-only, undocumented source that loads no private code (a registry key, a
  read-only SMC key, a preferences file readable without root, a system command's output) is
  allowed for the display, each with its guard exception and its caveats recorded. W-14's
  candidates for 0.8 already follow it.
- **M-5, what 1.0 means. Approved by the maintainer (2026-10-22), as written** (RD M-5). 1.0 means
  "ready for people other than you":
  - **The five promises:** seen working on the M5 in a packaged build; a week of daily use without
    a crash; in-app updates from older versions; nothing breaks through 1.x; usable by a
    non-expert.
  - **No dates:** "this is a hobby project; we release when there is time and desire". There is no
    target date, no calendar and no outer bound. The order of versions and the effort estimates
    stay; 1.1 (macOS 28 compatibility) comes after macOS 28 ships, an event, not a date.
  - R-1 condenses it into ROADMAP's "Road to 1.0" section (R-1 item 4).
- **M-9, a backup signing key. Decided by delegation (2026-10-22): yes.** Generating the key is
  still yours (about 5 minutes):
  - Read the steps first with `swift scripts/sign-update.swift --help`. Then, in Terminal on your
    Mac (never in a chat), run `swift scripts/sign-update.swift --generate-key`. It prints the new
    private key (`sign-update.swift:9-12`). Keep it only offline (a password-manager entry or a
    printed sheet), never in an issue, a PR or the repository.
  - Print its public half with `read -rs UPDATE_SIGNING_KEY && export UPDATE_SIGNING_KEY && swift
    scripts/sign-update.swift --public-key; unset UPDATE_SIGNING_KEY` (:7-8). Paste the key when the
    cursor waits: nothing shows, and it stays out of the shell history. Post only the printed
    public line in the PR; Claude never sees the private half (CL).
  - **If the key doesn't exist by C1:** K-1 moves to 0.8.

**Charge limiting and an iOS app:** nothing in 0.7 argues for revisiting M-2 or M-3. W-14 only
reads the Charge Limit's state and never sets a limit; of 0.8's candidates for the percentage, the
private PowerUI framework would contradict M-3, so it isn't recommended unless M-3 is reopened.
- The widget is read-only. There is no Control Center control (REJ-56), and the Mac has no
  accessory widget families (REJ-54).
- An iOS widget (FEA-33) needs the iOS app first.

### The widgets' look and behaviour (P2 §10's Q-W, with 0.7's answers)

- **Q-W1 (when). Decided by the maintainer (2026-10-22): 0.7,** as this plan does. There is no
  0.6.3 with static sizes (FEA-14 not planned; RD §5.3).
- **Q-W2 (which widgets). Decided by delegation:**
  - Battery and Accessories in 0.7.
  - History and iPhone & iPad on the feed (Q-W3; W0-3 passed), with the 90-day capacity and
    cycles trend offered then. There is no App Group route, because M-1 is no.
  - No preset widgets: configuration works (W0-1, G7-1).
- **Q-W3 (BatteryPulse keeps a small copy of recent readings for the widgets). Decided 2026-10-22,
  following the maintainer's M-1 answer (no paid account): yes.** W0-3 passed with A and A′, and
  the feed uses A (§2.2).
- **Q-W4 (look). Decided by delegation:**
  - **Main visual:** offer the number with the level symbol (the default, as today), a number with a
    ring, and a drawn battery like the menu bar's Modern style.
  - **Main value:** charge (the default), maximum capacity, temperature, and battery power with its
    update time.
  - **Colours:** level colours by default.
  - **Large and extra-large details:** as §6.1 question 2 shows. The look check signs them off.
- **Q-W5 (time). Decided by delegation:** clock time by default ("Lasts until about 16:39"), with
  time left ("2 hours, 13 minutes") offered, since W0-6 passed with `sign: .never`. An end two or
  more days ahead (macOS estimates run up to 65,534 minutes) shows no time, rather than a weekday
  ("Lasts until about Friday").
- **Q-W6 (update time). Decided by delegation:** "Updated 14:05" only when the reading is old, with
  "Always" offered.
- **Q-W7 (battery power, up to half an hour old in a widget). Decided by delegation:** offered,
  always shown with its update time.
- **Q-W10, 0.7's part (extra large). Decided by delegation:**
  - Two panels (Battery and Power) in 0.7, on your explicit yes in the look check (question 3).
    Otherwise it is left out; it can come later without touching placed widgets.
  - **Without an explicit 1 or 2:** extra large is not declared in 0.7. Families are only ever
    added (P2 §8.13), so it can come in a later release without touching placed widgets; a family
    can never be removed once shipped.
  - The dashboard and the portrait size come after 1.0, only if asked (RD §4.1). Apple's pages
    disagree on whether the portrait size exists on the Mac [conflict], Appendix B.
- **Q-W12 (°F). Decided by delegation:** °C, in the widget as in the app; no app-wide °F (RD
  §3.3).
- **Q-W13 (attention row). Decided by delegation:** on, in every widget (in small in place of the
  time line). "Off by default" would need a frozen parameter, so the choice is on or never
  (look-check question 8).
- **Q-W8, Q-W9, Q-W11. Decided by delegation:** their items come after 1.0 or with the stretch (RD
  §5.3):
  - a click anywhere opens the widget's page;
  - no Refresh button;
  - device names shown, with `.privacySensitive()`, hidden where macOS redacts.

### New for 0.7 (2026-10-22: Q7-1 to Q7-7 decided by delegation, as recommended; Q7-8 settled; Q7-9 decided by the maintainer; 2026-10-23: Q7-10 asked by the maintainer)

- **Q7-1 (gallery names and descriptions): as written.** "Battery: Charge, time remaining and the
  details you choose." and "Accessories: Batteries of your keyboard, mouse, trackpad and
  headphones." The look check shows them with their Russian (question 7).
- **Q7-2 (What's New): yes.** The What's New window shows once after updating to 0.7, with 2-3
  entries plus the version count (configurable widgets; the Accessories widget; clicks open the
  page; and W-13's "Anonymous version count", Q7-9). 0.7 is a feature
  release, as 0.6.0 was; fix releases left it at 0.6.0 (P1 §7 item 1).
- **Q7-3 (your time): as planned, then hands-free** (2026-10-23, on your request "make the tests
  run by themselves, without me"; P2 §10).
  - The plan asks for:
    - the look check at your desk, about 15 minutes, and a second look of about 4 minutes (PR
      comments; without an answer the decided defaults apply);
    - Session R, about 6-8 minutes at its start: one pasted line, one yes, the approvals, two
      beeps for the adapter, plus 1 minute once before to check the CLI (§6.2). The session does
      the rest, about 83 minutes of hand steps before, the accessibility
      step included, which reads the tree instead of asking you to drive VoiceOver;
    - a logged day of normal use, and about 3-4 minutes at its end (one message, the batch, your
      yes; F12 is the session's);
    - the after-publishing check, a short session of about 2 minutes, plus a passive 10-minute wait
      for W-13's count;
    - the backup key, about 5 minutes (M-9).
  - Session R still covers the small and medium widgets placed from 0.6.2 and shows every new size
    once: only who does each step changed.
  - With about no outside users (M-1's evidence), these sittings are where 0.7 is seen working at
    all (RD C2), so no step is dropped: a step the session can't do records "not checked", and its
    gate takes its default.
- **Q7-4 (if placed widgets don't survive the update): the evidence decided.**
  - W0-2 showed placed widgets survive the change to a configurable kind once the old widget
    extension is ended before the swap, which 0.6.2's installer does (D-17). So there is no
    separate gallery entry.
  - If Session R step 2 or §6.4 still shows your widgets gone or blank: ship as designed, the notes
    say "add it again", and it is a documented known limitation at 1.0 (RD C3, C7).
- **Q7-5 ("Hide fully charged" in the Accessories widget): yes, off by default** (FEA-21, W-8 item
  2). It is declared before D1, because adding it later may reset placed widgets' settings
  [unverified; Session R step 4.4 measures it].
- **Q7-6 (where a click opens): yes.** A click opens the main window at the widget's page, even if
  you prefer the compact window, because the compact window has no pages.
- **Q7-7 (small, Custom): yes.** In the small widget, the one detail you choose takes the place of
  the time line (P2 §8.5), because a small widget has room for one more line only. The alternative
  kept the time line and offered no detail in small.
- **Q7-8 (settled, an engineering call).** 0.6.2's D3 copies its session script, swap helper, the
  hands-free helpers (`ui.swift`, `frames.swift`, `SESSION-B.md`, `start-session-b.sh`), Appendix C
  (as `0.6.2-appendix-c.md`) and Session A's report into `docs/plans/0.7.0/` (D-1), and they reach
  main with 0.6.2's squash merge; the release PR's `refs/pull/12/head` keeps 0.6.2's whole plan
  reachable either way, so no branch has to be kept for 0.7. 0.6.2's after-publishing check needs
  neither the script nor a worktree: he runs `git -C ~/BatteryPulse fetch origin main` and `bash
  <(git -C ~/BatteryPulse show FETCH_HEAD:docs/plans/0.7.0/start-after-publishing.sh)`, and the
  short local session it starts (auto mode, no allow rule) follows the section After publishing of
  the copy of `SESSION-B.md`, read from `main`: computer use for the GUI checks, `codesign` and
  `xattr` as its only commands, nothing recorded in git, and a Russian summary he forwards to the
  cloud session, which marks v0.6.2 a prerelease on his yes if a check failed. The copied script
  couldn't run it: outside Session B's worktree it runs as Session A, and `ui` is a Session B
  command.
- **Q7-9 (an anonymous version count). Decided by the maintainer (2026-10-22): yes, on by default,
  announced honestly.** He wants to know how many people use which version. W-13 is the verified
  design:
  - no server of our own, no outside service, no identifier of any kind, and nothing about the
    Mac, its battery or its settings;
  - it rides on the automatic update check, so never when Check for updates is Never, and never
    with the toggle in Settings → General off;
  - once per version, at least a day after the version first ran, so the off switch comes first;
  - What's New, the release notes, README and the User Guide say what is sent, what is not and where
    to turn it off (§11);
  - it is a frozen-surface change announced in a minor release: three settings keys and a release
    asset (§7.3).
- **Q7-10 (show the Charge Limit). Asked by the maintainer (2026-10-23): yes, in the app, the menu
  bar and the widget.** After Session A's capture he asked for it explicitly. W-14 is the design:
  - **0.7 shows the "at limit" state:** "Charged to limit" in Overview, Power ("Charge limit:
    Reached"), the menu bar popover, the compact window and the Battery widget's state line and
    detail, from `NotChargingReason` bit 24 on external power while not charging;
  - **the percentage you set waits for 0.8:** no IOKit or IOPS key holds it, and every other source
    is undocumented, and the two that held it in Session A's reads tell only part: powerd's
    charging preferences file (like `pmset -g battlimit`) holds it only while the Mac is on the
    adapter, and System Settings' prior limit kept 80 on battery but also at 100 %, so it may be
    stale (W-14's candidates);
  - no ring or battery marker and no menu bar icon change in 0.7, since without the number a mark
    would only sit at the end of the fill;
  - it needs a redacted fixture from your capture: it came with Session A's report on your approval
    (2026-10-24), together with the proof that raising the limit clears the bit (G7-18).

---

## Appendix A: traceability of every 0.7 item

**Sources:**
- R at `eebf748`;
- P2 (0.6.2's plan: its §8, §9, Q-W answers and W0 rows in `docs/plans/0.7.0/widgets.md`, its
  whole Appendix C in `docs/plans/0.7.0/0.6.2-appendix-c.md`, the rest in the history of the 0.6.2
  release PR's head, `refs/pull/12/head`), RD (`docs/plans/1.0/ROADMAP.md`), INV
  (`docs/plans/1.0/INVENTORY.md`);
- P1 and PB at `6aec4d2:docs/plans/0.6.1/` (in PR 11's history).

| Item | Source | 0.7 package or status |
|---|---|---|
| Widget customization (the maintainer's request, 2026-10-22) | R:543-553; P2 §8, §9; RD §3.2 | W-1 to W-4, W-8, W-10 to W-12 |
| FEA-06 configurable Battery widget | P2 §8.5, §8.17, W-3; INV FEA-06 | W-3a, W-3b, W-3c (MVP) |
| FEA-07 widget model in BatteryCore and the pin test | P2 §8.6, §8.13, W-1 | W-1 |
| FEA-08 App Intents metadata step | P2 W-2; W0-1 | W-2 (W0-1 passed) |
| FEA-09 Accessories widget | P2 §8.4, §8.5, W-8; W0-4 (1) | W-8 (MVP: W0-4 (1) passed) |
| FEA-10, FEA-11, FEA-12 feed, History, iPhone & iPad | P2 W-5 to W-7; RD §3.2 | Stretch on candidate A (G7-5: W0-3 passed with A and A′; Q-W3 yes, M-1 no), else 1.1 on the feed |
| FEA-13 preset kinds | P2 §8.16 row 1; INV FEA-13 (0.7 only if W0-1 fails) | Not needed: W0-1 passed (G7-1); the final `A.md` didn't reopen W0-1 (§2.2) |
| FEA-14 a 0.6.3 with static large sizes | P2 §9; Q-W1 | Not planned (RD §4.2) |
| FEA-15 to FEA-20 (Refresh, portrait, dashboard, per-row links, specific accessories, "why not charging" field) | P2 §9.1 "Later"; RD §4.1 | After 1.0, except FEA-20's Charge Limit part: W-14 |
| FEA-21 hide fully charged accessories | P2 §8.5 | W-8 (Q7-5: yes, by delegation; cut fourth if short) |
| QUA-14 CB-02 device JSON dates | R:554-556; P1 §8 Q3; AUD-cli-build CB-02 | S-1 |
| NEW-11 `formatVersion` | RD §3.2, §5.2 | S-1 |
| QUA-16 0.7's own M5 session | P2 §8.14 "The 0.7 session checks"; RD §3.2 | §6 (look check, Session R, logged day, after publishing) |
| ENG-16 reload planner | P2 §8.10, W-4 | W-4 |
| ENG-17 reloads delivered, widget energy | P2 §8.10 targets | Session R's logged day; W-12's `perf-stats`; G7-11 |
| SEC-08 widget feed hardening | P2 §8.3, §8.8 | Stretch (W-5) |
| SIZ-06 0.7 size budget | P2 §8.12 | §9; W-2's row; D1's ceilings |
| SIZ-07 widget-only string table | P2 §8.12 | W-10 (P3) |
| DOC-07 widget docs | P2 W-10; UG:408-430 | W-10 |
| DOC-08 privacy text for the feed | RES-security SEC-16; P2 §8.8 | Stretch (W-10 with W-5) |
| DOC-09 iOS promises | RM:5, 14-15, 192-206; `feature_request.yml:17`; R:8-14; RD M-2 | R-1 |
| DOC-10 bug template | `.github/ISSUE_TEMPLATE/bug_report.yml`; RD §3.2 | R-1 |
| PLT-05 iOS code kept building | ci.yml:196-197; RD M-2 | R-1 (a ROADMAP line) |
| TCI-10 widget render previews | P2 W-3 | W-3a, W-3b |
| TCI-11 widget guard rules | P2 §8.7, §8.8, §8.11 | W-3a, W-3c, W-8, W-10 |
| A11Y-06 widget accessibility | P2 §8.15; W0-5 (the maintainer's VoiceOver photos, Session A's tree read and Text size) | W-3b item 5 (the requirements and `WidgetAccessibility`, tested on Linux); Session R step 7 (the tree read) |
| L10N-04 widget localization | P2 §8.11, W-10 | W-1 item 11 (the catalog test's App Intents forms), W-3a, W-3b, W-8, W-10 |
| L10N-05 unit symbols in the widget | P2 §8.6 "Formatter" | W-3a |
| NEW-13 backup key (public half) | RD M-9 (yes, by delegation) | K-1 |
| NEW-18 verification matrix (start) | RD C2, §5.2 | R-1, D3 |
| NEW-22 quick check after macOS 27.x updates | RD §5.2 | W-12 (`scripts/quick-check.sh`) |
| NEW-23 download counts a week after publishing | RD §1.2 item 6, §5.2; the maintainer's question about downloads (2026-10-22); 0.6.2's `scripts/release-stats.swift` | §13 step 8; D-16; §11 |
| Anonymous version count | §14 Q7-9; RD NEW-24, NEW-23, C14 items 1, 6, 8; INV DIS-11 | W-13 |
| M-5's "Road to 1.0" in ROADMAP | RD §3.2 "Before code"; RD M-5 | R-1 (M-5 approved as written: the five promises, no dates) |
| QUA-05 Charge Limit capture | R:145-146; RD §3.2; Session A finding 7 | Captured in Session A (D-13); the redacted fixture and the 100 % diff came with the final `A.md` (G7-18), so W-12's `charge-limit` step doesn't run for W-14 |
| QUA-06 optimized charging hold | R:76-77; INV QUA-06 | Session R optional (W-12's `hold-watch` step, overnight `--record` under `caffeinate -i`) |
| 0.6.2's cut items | P2 §7.2 | C-1 (Linux), Session R optional, or the matrix |
| TCI-05, TCI-06, TCI-07, PLT-03 (Xcode items) | P2 WP-18; RD §5.1; Q-B7 (Xcode is installed on the M5) | TCI-05, TCI-07 and PLT-03: run in 0.6.2 by Session B (hands-free since 2026-10-23); whatever 0.6.2 left rides in 0.7 the same way, in Session R's GUI phase (C-1; Session R step 11). TCI-06 (SUI-18): dropped on 2026-10-23 (P2 WP-18) |
| Q-B4, Q-B8 (0.6.2's answers that reach 0.7) | P2 §10 (decided by delegation, 2026-10-22) | C-1: WP-13 items 4-5 wait for a graduation; WP-20's SEC-08 not planned |
| REJ-04 icon geometry | AUD-core CORE-16; RD §4.3 | Unchanged: W-11 moves the painter, not the geometry |
| REJ-06 widget types out of `BatteryPresentation.swift` | AUD-core CORE-20; RD §4.3 | Taken in W-1 (the condition is met) |
| REJ-12 `SidebarItem` as `RawRepresentable` | AUD-app-views AV-03 | Still rejected: W-3c maps to and from `PageID` |
| REJ-30 main actor by default for the widget | P2 WP-10 | Still rejected: the widget stays nonisolated |
| REJ-53 the app writing into the widget's container | P2 §8.3 | Still rejected |
| REJ-54 to REJ-59 (accessory families, Smart Stack, Control Center, push, pager, thresholds) | P2 §8.2, §8.4, §8.5 | Still rejected |
| REJ-60 App Intents outside the widget target | P2 §8.9, §8.11 | Still rejected: W-3a, W-3c |
| REJ-62 seconds in widget text | P2 §8.7 | Still rejected: W-10's guard |
| Q-W1 to Q-W13 | P2 §10 | §14 (decided 2026-10-22: Q-W1 by the maintainer, the rest by delegation) |
| Q7-1 to Q7-10 | this plan | §14 (Q7-1 to Q7-7 decided by delegation, 2026-10-22; Q7-8 settled; Q7-9 decided by the maintainer, W-13; Q7-10 asked by the maintainer, 2026-10-23, W-14) |
| M-1, M-2, M-3, M-5, M-9 | RD §6 | §14 (all decided 2026-10-22; M-5 approved as written, with no dates) |
| 0.6.2's A0: 0.6.0 → 0.6.1 in-app kept the widget and Open at login | P2 Appendix C | D-9; C-1 (WP-16 item 5 has no cause); §7.3 (no `openAtLogin` expected); Appendix C |
| 0.6.2's branches: integration `claude/nice-faraday-k08mhb`, `claude/062-<pkg>`, `claude/062-spike-widget` | P2 §3 | D-1, D-11, W-0 item 6 |
| M-1's consequences: no App Group, no Developer ID work, known limitations at 1.0 | RD §3.4, §4.2, C3, C7, C16 | §1, §2.2 (W0-3), G7-5, the stretch, C-1, §6.5, §12, §14 |
| The build-number risk | ci.yml:201, 407; `release.yml:109`; `build-app.sh:136-137` | Fixed in D1: one growing clock in both workflows (§6.5; this plan's addition) |
| A parameter added to a shipped intent (1.1's History chart, FEA-19) | P2 §8.13; RD C14 item 5 | Session R step 4.4 (RC-P), recorded in Appendix C |
| FEA-35 the Charge Limit shown, read-only, in the app, the menu bar and the widget (the maintainer's request, 2026-10-23) | §14 Q7-10; INV FEA-35; RD §3.2, §3.3; Session A findings 7 and 9; the Charge Limit research (Appendix C); RD NEW-01, FEA-20 | W-14: the "at limit" state in 0.7 (G7-18); the configured percentage in 0.8 (FEA-35's second half, beside NEW-01, with W-14's candidates) |
| Session A's W0 answers (final, `docs/plans/0.7.0/sessions/A.md`, 2026-10-24) | P2 Appendix C; Appendix C here | §2.2; G7-1 to G7-5, G7-8, G7-9, G7-12, G7-13 |
| The widget extension ended before the swap | Session A's W0-2; P2 WP-16 item 6 | D-17; W-3a item 10; Session R step 2, §6.4 |
| The iPad's connection label after unplugging | Session A's F5; P2 WP-23 | D-18; C-1 if 0.6.2 didn't fix it |
| Session A's script lessons | P2 Appendix C | W-12 item 1 |
| Clicks without a `widgetURL` arrive as an `NSUserActivity` of the intent's type | Session A's W0-4 (4) (Appendix C row 4) | W-1 item 8; W-3c item 2; G7-9; Session R step 8 |
| The edit sheet stayed English under the extension's Russian | Session A's W0-2-W-ru (Appendix C row 10) | W-2 item 5; W-10 item 2; G7-13; Session R step 4.3 |
| What 0.7 didn't build | P2 §8.3, §8.5, §8.8; W-5 to W-7, W-9 | Moved to `docs/plans/1.1/widgets.md` at D3 |

---

## Appendix B: facts verified for this plan, conflicts, and what stays unverified

**The repository at `eebf748` (v0.6.1's code; file:line at v0.6.2):**
- **The widget:**
  - One file of 215 lines and one `StaticConfiguration`, families small and medium
    (`BatteryPulseWidget.swift:17-27`).
  - `Task { @MainActor in … }` in `getSnapshot` and `getTimeline` (:50, :56); a fresh
    `MacBatteryProvider(readsSMC: false)` per read (:68-70).
  - `BatteryFormatter()` with English symbols (:78; `BatteryFormatter.swift:33-41`).
  - The 34-pt hero number with `minimumScaleFactor(0.7)` (:117-120); no accessibility modifiers.
- **The widget's shared types:** the kind string, `WidgetReloadPolicy` and `WidgetTimelinePlan`
  live in `BatteryPresentation.swift:114-238`.
- **`WidgetRefresher`:**
  - It observes only `monitor.snapshot` (`WidgetRefresher.swift:23-31`) and reloads one kind (:138).
  - It ends the previous extension with `kill` after an update (:45-62) [v0.6.2: and before the
    swap, :75-113], the only allowed signal site (`SecurityGuardTests.swift:82-86`).
- **The extension's packaging:**
  - `build-app.sh` copies every `.lproj` into the appex (:142) and signs it with its entitlements
    file (:237).
  - The posture check compares the widget's entitlements to that file (:330-336).
  - The entitlements are the sandbox alone (`Resources/BatteryPulseWidget.entitlements`).
- **Size:** the ceilings are `widget_binary_bytes` 1,450,000, `widget_text_bytes` 990,000,
  `strings_bytes` 251,000, `app_kb` 4,840 and `dmg_bytes` 1,520,000 (`scripts/size-budget.json`).
- **Signposts:** `Signposts` is public with `init(subsystem:log:)`, and BatteryKit's `Diagnostics`
  is internal (`BatteryKit/Diagnostics.swift`). The app has its own twin
  (`App/Diagnostics.swift:10-25`).
- **`bpulse`'s JSON:**
  - the Mac's `--json` uses ISO 8601 (`main.swift:162-164`);
  - the device's JSON sets no date strategy (`main.swift:190-191`);
  - the accessories' JSON is a bare array (`main.swift:209-212`);
  - device storage uses ISO 8601 itself (`DeviceStore.swift:141-149`);
  - `--export json` has `formatVersion` 1 (`HistoryExport.swift:135`).
- **App pieces 0.7 builds on:**
  - `SidebarItem.storageKey` strings (`MainView.swift:64-90`) and `@SceneStorage("mainSelection")`
    (:105);
  - `WindowOpener` (`AppSettings.swift:222-238`);
  - `AppDelegate`, which has no URL or activity handler (`BatteryPulseApp.swift:174-234`);
  - `AccessoryMonitor`, always running (`BatteryPulseApp.swift:33-36`).
- **The drawn-battery painter:** `BatteryIconPainter` and `BatteryIconCanvas` use SwiftUI and
  CoreText in the app target (`BatteryIconView.swift:1-5, 9, 215`).
- **What's New:** `WhatsNew.version` is 0.6.0 (`UpdateViews.swift:387`).
- **The thermal state's words:** "Elevated", "High" and "Critical" (`App/Localized.swift:159-161`).
- **Found in review (2026-10-22):**
  - `LocalizationCatalogTests`' `localizingCall` regex (:19-21) matches `title:\s*"`, a lowercase
    `description(` and `value(`, but not `IntentDescription(`, `= "…"`, `Summary(`,
    `TypeDisplayRepresentation(name:` or dictionary literals; `catalogHasNoLeftovers` (:126-130)
    fails on unused keys.
  - `Package.swift:1` is `swift-tools-version: 6.4`, so every target builds in Swift 6 mode.
  - `SidebarItem.storageKey` also returns `developer` and `demo` (`MainView.swift:64-75`), and
    MainView applies `pageRequest` in `.onChange` without `initial:` (:238).
  - `WidgetTimelinePlanTests` asserts exact entries (:24, 31, 38-41, 48, 53, 77); the view computes
    the estimate's end from `entry.date` (`BatteryPulseWidget.swift:192, 196`).
  - `MacAccessoryProvider` is `@MainActor` (`BatterySource/MacAccessoryProvider.swift:17-19`).
  - `MacPowerParser.validMinutes` accepts up to 65,534 (`MacPowerParser.swift:123, 281-284`).
  - The heat alert has hysteresis: serious or critical arms it, nominal resets it
    (`BatteryAlerts.swift:104-117`).
  - `WidgetRefresher.evaluate()` returns without a snapshot (`WidgetRefresher.swift:135`).
  - `build-app.sh` copies the widget at :141, strips it at :220 and signs it at :237; English ships
    no string table (:143-146).
  - `ci.yml` only reads the repository (:29-30). The release workflow's `run_number` was 7 for
    0.6.1, CI's 258 (`gh api`, 2026-10-22).
  - The key pins are in `UpdateInstallTests.swift:113-117`; `--generate-key` prints a new private
    key and `--help` only the usage and rotation steps (`sign-update.swift:7-14`).
  - README's "What each platform exposes" has an iOS column (RM:192-206), and
    `feature_request.yml:17` offers iOS.
  - The catalog's Russian for "Battery power" is 21 characters, "Low Power Mode" 22, and "Lasts
    until about %@" 21 before its value; "Ring" is already translated.
- **The catalog:** 719 keys. Among them are "Updated %@", "Remaining capacity", "%@ of %@", "of %@
  rated", "This Mac has no internal battery.", "System load" and "Power from adapter". There is no
  "Automatic", "Custom", "Monochrome" or "Time left".
- **The release workflow:** the notes heading accepts "0.7" or "0.7.0" (`release.yml:49-62`).
  `BUILD_NUMBER` comes from release.yml's run number (:109) and CI's from its own (ci.yml:201, 407).

**GitHub's REST API (2026-10-22), the usage evidence behind M-1** (§14; RD §1.1):
- DMG downloads across all releases: 14 (0.2.0: 1, 0.3.0: 2, 0.3.1: 4, 0.4.0: 1, 0.5.0: 2, 0.6.0:
  3, 0.6.1: 1, the last a signature check during the release).
- Signature (`.sig`) downloads: 5, a privacy-free proxy for in-app updates.
- Repository page views: 2, by 1 visitor, in 14 days. No stars, forks or outside issues.
- By 14:26 UTC the same day: 15 DMG and 6 `.sig` downloads. Both rose by one on 0.6.1, which
  matches the maintainer's own 0.6.0 → 0.6.1 Install and Relaunch (0.6.2's A0). Table below.

**The update traffic, for W-13** (the repository at `eebf748`, checked 2026-10-22; file:line at v0.6.2):
- `startAutomaticChecks()` wakes 20 s after launch, then every 6 h with a 36-minute tolerance
  (`UpdateChecker.swift:66-76`). A tick checks only when `UpdatePolicy.isCheckDue` allows and no
  rate limit holds (:118-130; `Updates.swift:190-265`).
- `check(userInitiated:)` (:132-161) [v0.6.2: `check(_:)`, with `noReleases` handled in
  `failed(_:userInitiated:)`] records the check at :152 on success and at :166 on
  `noReleases`; the offer is decided at :154-160. The check's GET sets only `Accept`,
  `X-GitHub-Api-Version` and `User-Agent` (:181-208).
- `UpdateNetwork` (:211-233) holds the only two `URLSession(` constructions in `Sources/` (:216,
  :219): ephemeral, `urlCache = nil`, and for automatic checks no constrained or expensive network.
  It sets nothing about cookies.
- The type's doc comment (:9-14) calls the check "the only network request BatteryPulse makes on
  its own".
- The installer fetches the `.sig` and the DMG on `UpdateNetwork.user`, setting only `User-Agent`
  (`UpdateInstaller.swift:183-233`).
- `SecurityGuardTests` bans only `URLSession.shared` (:53-59). `EnergyGuardTests.oneShots` has four
  entries.
- The `WhatsNewPolicy.lastLaunched != current` branch runs once per new version, before
  `markSeen` (`BatteryPulseApp.swift:57-60`).
- The Welcome window embeds `GeneralSettings` (`WelcomeView.swift:32-34`), whose update section is
  `GeneralSettings.swift:79-99`.
- `AppVersion(parts:)` is public. `UpdateInstallPolicy.unversioned` is 0.0.0
  (`UpdateInstall.swift:133`). `Diagnostics.update` is the app's `update` logger
  (`App/Diagnostics.swift:20`).
- `release.yml`'s `gh release create` attaches the DMG, its `.sig` and the dSYMs zip (:151).
- Today's README and guide say the check and a chosen download are the only internet requests
  (RM:120-125, UG:502-509); ROADMAP's Decisions, Principles and usage paragraph and RD C14 item 8
  already describe the count (written 2026-10-22).

**W-13's facts about GitHub and the law** (2026-10-22):

| ID | Fact | Source | Mark |
|---|---|---|---|
| VC-1 | Every release asset has a `download_count` in the releases API. GitHub documents downloading through `browser_download_url` ("API clients should handle both a 200 or 302 response"). It says nothing about how the count is computed | https://docs.github.com/en/rest/releases/assets ; https://docs.github.com/enterprise/2.3/user/articles/getting-the-download-count-for-your-releases | verified (that the docs say no more) |
| VC-2 | A GET of `browser_download_url` that follows the redirect is counted. In one public experiment on GitHub (13 request modes, 1 MB assets, one run, 2026), these were also counted: HEAD, a GET that stops at the redirect (0 bytes from the asset host), and ranged or aborted GETs. The count is taken on github.com, before the redirect | that experiment's results table | [uncertain]: one self-reported run, and GitHub documents none of it. W-13 uses only the documented GET |
| VC-3 | Counts appear in batches about 10 minutes later. Two downloads from one address inside one batch counted once, so Macs behind one shared address (an office, carrier NAT) that count within the same ~10 minutes merge into one | the same experiment | [uncertain] |
| VC-4 | The download URL is on github.com, not the REST API. Its answers carry no `X-RateLimit-*` headers, while `api.github.com` answers do. The REST limit without a login is 60 requests an hour. GitHub's 2025 limits on anonymous traffic name HTTPS clones, the REST API and raw.githubusercontent.com, not release assets. One request per Mac per version is far below any of these | an HTTPS request from the command line, 2026-10-22; https://docs.github.com/en/rest/using-the-rest-api/rate-limits-for-the-rest-api ; https://github.blog/changelog/2025-05-08-updated-rate-limits-for-unauthenticated-requests/ | observed; GitHub documents no limit for asset downloads |
| VC-5 | github.com sets three cookies (`_octo`, `logged_in`, `_gh_sess`) on a release download URL, even when it answers 404. `api.github.com/…/releases/latest` sets none. The ephemeral sessions keep cookies in memory for as long as the app runs (`UpdateChecker.swift:221-233`) | an HTTPS request from the command line, 2026-10-22 | observed |
| VC-6 | A missing asset or tag answers `404 Not Found` (`text/plain`). Checked with `v0.6.1/BatteryPulse.count` and `v9.9.9/…` | an HTTPS request from the command line, 2026-10-22 | observed |
| VC-7 | Owners get one number per asset, `download_count`, and anyone can read it through the releases API. The traffic API covers page views, clones and referrers, not release downloads | the REST docs | verified; no other per-download data is known |
| VC-8 | **EDPB Guidelines 2/2023 v2.0 (adopted 7 October 2024):** ¶42, identifiers such as the IP address, sent because software tells the device to send them, can fall under Art. 5(3) ePrivacy; ¶53, information produced on the device and sent back to a server counts as "gaining access"; ¶56, falling under Art. 5(3) does not always mean consent is needed, and exemptions are assessed case by case. **CNIL:** anonymous audience measurement is exempt from consent if users are told, can object, and the statistics stay anonymous and serve only the publisher | https://edpb.europa.eu/system/files/2024-10/edpb_guidelines_202302_technical_scope_art_53_eprivacydirective_v2_en_0.pdf ; https://www.cnil.fr/en/sheet-ndeg16-use-analytics-your-websites-and-applications | EDPB: verified from the PDF. CNIL: [uncertain]: the page returned 503 on 2026-10-22, and the conditions come from secondary summaries |

**Release download counts at 14:26 UTC, 2026-10-22** (the baseline for W-13 and for
`scripts/release-stats.swift`):

| Release | DMG | `.sig` |
|---|---|---|
| 0.6.1 | 2 | 2 |
| 0.6.0 | 3 | 3 |
| 0.5.0 | 2 | 1 |
| 0.4.0 | 1 | 0 |
| 0.3.1 | 4 | — |
| 0.3.0 | 2 | — |
| 0.2.0 | 1 | — |

**Apple's documentation** (fetched 2026-10-22; the saved copies are working notes, not in the repository):
- **The budget** (https://developer.apple.com/documentation/widgetkit/keeping-a-widget-up-to-date):
  - "For a widget the user frequently views, a daily budget typically includes from 40 to 70
    refreshes"; each placed widget has its own budget.
  - No budget is counted when "the widget's containing app is in the foreground", when "the widget
    performs an app intent", or when "Dynamic Type or Accessibility settings change".
  - "don't request a timeline reload" for appearance or locale changes.
- **`currentConfigurations()`:** macOS 15.0+,
  `func currentConfigurations() async throws -> [WidgetInfo]`.
- **`systemExtraLargePortrait`:** macOS 27.0, "on the Desktop on macOS"
  (https://developer.apple.com/documentation/widgetkit/widgetfamily/systemextralargeportrait).
- **`IntentCollectionSize`:** `init(exactly:)` and `init(min:max:)`, macOS 14.0+.
- **Displaying dynamic dates**
  (https://developer.apple.com/documentation/widgetkit/displaying-dynamic-dates): `.relative`
  shows "11 min, 14 sec", `.offset` "-11 minutes", `.timer` "15:00".
- **Making a configurable widget**
  (https://developer.apple.com/documentation/widgetkit/making-a-configurable-widget): an intent's
  title is "a title case string that combines a verb with a noun". Its sample's `static var title:
  LocalizedStringResource = …` is a stored static var, which Swift 6 mode rejects; 0.7 uses `static
  let`.
- **`SystemFormatStyle.DateOffset`**
  (https://developer.apple.com/documentation/swiftui/systemformatstyle/dateoffset): `init(to:
  allowedFields:maxFieldCount:sign:)` with `sign` defaulting to `.automatic`, "sign only when date
  is before anchor … '−5 seconds'"; `.never` shows no sign.
- **`\.widgetFamily`** is `{ get }`; **`\.widgetRenderingMode`** is `{ get set }`
  (https://developer.apple.com/documentation/swiftui/environmentvalues/widgetfamily,
  …/widgetrenderingmode).
- **`IntentCollectionSize`** conforms to `ExpressibleByIntegerLiteral`; no page says whether a
  literal means exactly or at most.
- **Displaying dynamic dates** also lists `Text(timerInterval:pauseTime:countsDown:showsHours:)` and
  `ProgressView(timerInterval:countsDown:)`, which count by themselves.
- **App Groups entitlement**
  (https://developer.apple.com/documentation/bundleresources/entitlements/com.apple.security.application-groups):
  groups are "produced by a single development team"; on macOS, `<team identifier>.<group name>`.
- **Apple Support** (fetched 2026-10-22): Desktop & Dock → Dim widgets on desktop offers
  Automatically, Always (monochrome) and Never (full color)
  (https://support.apple.com/guide/mac-help/mchlp1119/mac); VoiceOver turns on with Command-F5, or
  by holding Command and pressing Touch ID three times
  (https://support.apple.com/guide/voiceover/turn-voiceover-on-or-off-vo2682/mac).
- **HIG (widgets):**
  - "Avoid expanding a smaller widget's content to simply fill a larger area."
  - "Ensure that a widget interaction opens your app at the right location."
  - "Convey meaning without relying on specific colors."
  - "Use system functionality to refresh dates and times."
  - Widgets "use smaller margins on the desktop on Mac".
- **NOTES27:** 161835690 (other teams' containers are denied without a prompt), 178668601 (files
  created by other teams' apps may be denied), 184660124 (a process without a bundle ID can't be
  granted access).
- **Apple's Xcode 27.2 release notes**
  (https://developer.apple.com/documentation/xcode-release-notes/xcode-27_2-release-notes,
  fetched 2026-10-30; W-0 item 7): Xcode 27.2 includes Swift 6.4 and SDKs for macOS 27.2 and the
  other 27.2 platforms; a known issue, 187160501: the macOS, watchOS, tvOS and visionOS SDKs in
  Xcode 27.2 incorrectly report 27.1 as a valid deployment target.

**Conflicts between Apple's sources** [conflict]:
- **Extra-large portrait on the Mac.** The `WidgetFamily` page lists macOS 27.0, "on the Desktop on
  macOS". The HIG's size table lists "System extra large portrait" as not supported on the Mac.
  0.7 doesn't use it, and P2's "later" stands.
- **The accented mode on the Mac.** The HIG's rendering table lists the Mac as "Not supported" for
  accented and "Desktop" for vibrant. The HIG's own text ("On iPhone, iPad, and Mac, the system tints
  primary and accented content white") and Apple's Liquid Glass widget articles (P2 §8.2) say the
  Mac uses accented under the tinted and clear appearances. W0-4 (2) logged no mode (Session A had
  only screenshots), so W-3b designs for all three modes and Session R step 5's screenshots
  decide.

**Answered by 0.6.2's Session A** (final, `docs/plans/0.7.0/sessions/A.md`, 2026-10-24; §2.2,
Appendix C): the processor step under SwiftPM (W0-1); the per-family `size:` overload, for entity
arrays only (W0-1 (a)); placed static widgets surviving the change to `AppIntentConfiguration`,
once the old extension is ended before the swap (W0-2); accessory reads from the sandbox (W0-4
(1)); what a click delivers, the URL or, without one, an activity of the intent's type, and that
no scheme is needed (W0-4 (4), (5)); the offset format's sign, in English and Russian (W0-6); that
AX can read the widgets' tree, under Finder's desktop group, and that Text size doesn't reach
desktop widgets at 17 pt (W0-5); that bit 24 of `NotChargingReason` clears when the Charge Limit is
raised to 100 % and returns at 80 % (W-14).

**Not verified here; decided by 0.7's runs and sittings:**
- whether entity queries run in the ad-hoc extension, which Details' chooser needs (W0-1 (b): the
  final `A.md` never opened the Device chooser and doesn't say whether Details' was, so W-3a's review chooses and Session R step 4.1 checks);
- why the edit sheet stayed English under the extension's Russian: the hand-extracted metadata or
  the system's language (W-2 item 5; Session R step 4.3);
- the values of an activity's `WGWidgetUserInfoKeyKind` and `WGWidgetUserInfoKeyFamily` (W-3c
  relies on its type only);
- whether `IntentCollectionSize(min:max:)` compiles per family for an entity array (W-3a item 1);
- whether a widget without `Metadata.appintents` still appears in the gallery (W-2's rollback);
- the rendering mode per Icon & widget style and place: no log data, only screenshots (W0-4 (2));
- which process hosts desktop widgets on macOS 27 (0.6.2 Session B's P1; AX reads their tree under
  Finder's desktop group, Session A, so Session R step 7's read has a route);
- whether a click with BatteryPulse quit launches it through the unregistered scheme (Session R
  step 8);
- whether Optimized Charging's hold sets bit 24 of `NotChargingReason` too (W-14; QUA-06), and when
  bit 24 appears after a plug-in within 5 % of the limit (W-14 item 6; Session R step 9);
- System Settings → Battery's Russian string for the Charge Limit (W-14, W-10);
- whether adding a parameter later resets placed widgets' choices (Session R step 4.4; it decides
  how 1.1 adds parameters, RD C14 item 5);
- whether `currentConfigurations()` returns the real placements to this ad-hoc, unsandboxed app
  (W-4 item 3; Session R step 9);
- whether a test target can link the widget executable with `-e _NSExtensionMain` (W-3a item 11);
- how closely our accented and vibrant branches, set through `\.widgetRenderingMode` in a test,
  match what the system draws (W-3b item 7; Session R step 5);
- whether `log config … persist:debug` keeps a day of `perf` lines on macOS 27 (§6.2 step 12);
- whether a lower `CFBundleVersion` after a CI build leaves the widget stale (§6.5; D1's fix makes
  the question moot);
- the System Settings path of the Charge Limit on macOS 27 (Apple's article gives Battery → (i)
  next to Charging → Charge Limit), and whether macOS holds the charge while `caffeinate -i` keeps
  the Mac awake (W-12's `charge-limit` and `hold-watch`);
- the size of `Metadata.appintents` (§9);
- how GitHub computes `download_count`: which requests count, and how one address's downloads
  merge (VC-2, VC-3; W-13 relies only on the documented GET, and §6.4 step 6 sees one count
  arrive);
- the CNIL's exact conditions for exempt audience measurement (VC-8).

---

## Appendix C: facts 0.7 records (filled during the release)

**From 0.6.2** (W-0; filled on 2026-10-30 from `docs/plans/0.7.0/0.6.2-appendix-c.md`: each D-row of
§2.1, the W0 rows, and Session B's rows marked "Session B, second attempt, 2026-10-30 (final)";
file:line at v0.6.2, `0ecca33`):

| Fact | Shown by | Decides |
|---|---|---|
| D-1, D-11: where the W0 answers, the whole Appendix C, the session script and its hands-free helpers are (the copies in `docs/plans/0.7.0/`: `widgets.md`, `0.6.2-appendix-c.md`, `m5-session.sh` with its helpers, `sessions/A.md`; else the 0.6.2 release PR's history, Q7-8): **all in `docs/plans/0.7.0/` at v0.6.2** (checked 2026-10-30, W-0 item 6): `widgets.md`, `0.6.2-appendix-c.md`, `m5-session.sh`, `swap.swift`, `ui.swift`, `frames.swift`, `SESSION-B.md`, `start-session-b.sh`, `start-after-publishing.sh`, `sessions/A.md` with `sessions/A/` (the four fill crops and `charge-limit-80.plist`), and Session B's report `sessions/B.md`. Against 0.6.2's last plan folder (the tree before `805a157` removed `docs/plans/0.6.2/`), the script, its helpers, the launcher and Session A's report and files are byte for byte the same; `SESSION-B.md` differs only in its After publishing section, which D3 rewrote for the short session (Q7-8). Not copied, and not asked for: Session A's runbook `SESSION.md`, readable at `805a157^` in `refs/pull/12/head`'s history. CI keeps checking the copies (ci.yml:75-82, the queue's dry run; :187-195, `bash -n` and the type-checks). **The branches:** `claude/nice-faraday-k08mhb` and the `claude/062-<pkg>` branches are gone from origin; `claude/062-spike-widget` (`a609487`, SPIKE-W) is the one left, and its code is in no other ref, `refs/pull/12/head` included, so deleting it loses the spike's sources that §2.2, W-2 and W-3a cite (its query, its catalog) unless a tag keeps them | 0.6.2 D3 | W-0, W-12; the branch cleanup (keep SPIKE-W under a tag first) |
| D-2, D-3: K-03 and internalize shipped; the widget's `__text` and binary at v0.6.2: **both shipped** (WP-15 items 1-2; G-15 passed on the RC, Session B's G-15 row below): the widget links BatteryCore and BatterySource only, no CryptoKit (`build-app.sh` fails if it does), and `-internalize-at-link` is on both link lines. **At v0.6.2** (CI run 41078937378, Xcode 27.1, built as 0.0.0): widget binary 778,672 B and `__text` 491,628 B (§9's start: 1,379,808 and 943,096 B), `strings_bytes` 239,574 B, app binary 2,854,688 B and `__text` 1,902,980 B, DMG 1,280,945 B (the published v0.6.2 DMG: 1,280,797 B) | 0.6.2 CI | G7-10: the widget starts at about half of 0.6.1's ceilings (990,000 and 1,450,000 B); **W-0K: not needed** (decided 2026-10-30, W-0 item 5): K-03 shipped, so D-2's rule never runs it, and §9's fifth cut has nothing left to cut |
| D-4: WP-14a's shape (a nonisolated protocol, or `readNonisolated(scope:)`): **shipped as shape B** (the next row); G-14a passed on the RC (Session B's G-10 and G-14a row below). `MacAccessoryProvider` stays `@MainActor` (`BatterySource/MacAccessoryProvider.swift:17-19`) | 0.6.2 code; Session B | W-3a; W-8 item 4 (one hop) |
| D-4, answered 2026-10-22: shape B. `MacBatteryProvider.readNonisolated(scope:)` through `BatteryProvider.nonisolatedReader`; the protocol stays `@MainActor` (0.6.2 plan Appendix C, WP-14a) | 0.6.2 WP-14a | W-3a |
| D-5: WP-14b (E4b): **shipped** with the 5-minute safety net and `RegistryReadPolicy.cachesOnPolls = true` (G-14b passed: Session A's F13 and E3b, Session B's `read cached` p50 0.971 ms and no `registry.missed` in 62 minutes). The widget still makes a new provider and reads the full scope for each read (`BatteryPulseWidget.swift:68-70`) | 0.6.2 Appendix C (WP-14b; Session B's G-14b row) | W-3a's source test (the widget never passes a cached-registry scope) |
| D-6: WP-10 kept or reverted: **kept.** The app runs on the main actor by default, with four `@MainActor`s and its off-main declarations marked `nonisolated` and pinned by `IsolationGuardTests`; G-10 passed on the RC (Session B's G-10 and G-14a row below) | 0.6.2 | W-3c, W-4 style: the default-isolation style, and an off-main declaration joins `IsolationGuardTests`' list |
| D-7: the widget ceilings after 0.6.2's D1: **lowered** (`042033d`) to `widget_binary_bytes` 818,000 B and `widget_text_bytes` 517,000 B (0.6.1's: 1,450,000 and 990,000 B), about 5 % above CI run 40083084958's build (778,672 and 491,628 B); the other ceilings unchanged | `size-budget.json` at v0.6.2 | §9 (each raise a commit of its own; 0.6.1's ceilings stay the outer bound) |
| D-8: the Russian method for the widget: **the extension's `AppleLanguages` reached the widgets, not the edit sheet** (the final `A.md`, W0-2-W-ru: 2; row 10 below). Session B's F8 took its Russian shots 5 s after ending the extension, with no redraw, so they showed the English render: "not checked: no redraw" (W-0 item 8) | 0.6.2 Session A step 3.3; Session B's F8 | Session R step 4.3; W-2 item 5; G7-13; W-0 item 8 (W-4, W-3b, W-12, W-10) |
| D-9: placed widgets after 0.6.1 → 0.6.2 in-app: **recorded** in `0.6.2-appendix-c.md`'s row "After publishing, 2026-10-30 (final)": the maintainer updated to 0.6.2 (8) through Install and Relaunch himself before the session, which therefore didn't see the update or the widget before it; after it, a desktop widget showed the popover's values (his screenshot at 18:23), and About, History, Open at login and Login Items, notifications, `codesign` and `xattr` read right. Beside it, Session B's F12 (the RC's own `diskutil` installer putting 0.6.1 in place over it) kept the placed widgets (answer 1) | 0.6.2 D3's after-publishing check; Session B's F12 | G7-2, Q7-4 |
| D-10: WP-21's energy numbers: **in.** Session A's window (A = 0.6.0, B = 0.6.1; S6 B not valid) and Session B's C against B (C = the RC), on battery, medians of valid runs: S1 C ÷ B 0.50 for energy (137.4 against 277.0 mJ/h) and 0.59 for CPU; S2 0.77 and 0.79; S2 with Low Power Mode 1.03 and 0.92 (one pair); S6 1.03 and 0.98 (one pair, both valid); S10 574.7 mJ/h (C). S7 unchanged: B 157-167 ms, C 157-166 ms to `menuBarReady`, one read before it, no widget reload. Only C ÷ B within one session compares: B's S2 read 884-1,848 mJ/h in Session B against 444-517 in Session A | 0.6.2 Appendix C (Session A's energy window; Session B's C energy and S7 rows) | §10's baseline; RD C5's final run |
| D-12: the installer 0.6.2 shipped: **`diskutil`** (WP-16 items 1-2; G-16 passed: CI's install passes and Session B's F12, its row below) | 0.6.2 G-16 | F12 at the logged day's end (§6.3) tests the `diskutil` installer the RC carries; 0.6.2 → 0.7.0 through Install and Relaunch runs 0.6.2's (§6.4) |
| D-13: the Charge Limit capture: **done in Session A** (finding 7 below). **The final `A.md` brought** the redacted `charge-limit-80.plist` (`docs/plans/0.7.0/sessions/A/`, on the maintainer's approval) and the 80 → 100 → 80 reads (finding 9); **not** the Russian Charge Limit screenshot. Session B found no limit set (100 % at prepare and in the morning) | 0.6.2 Session A; Session B's preflight | G7-18; W-14's fixture; W-10 item 1 (Apple's Russian article stands) |
| D-14: 0.6.2's cut list: **cut or left:** WP-20 (SEC-08 not planned; SEC-18's research not run), WP-18's Xcode items (Session B's WP-18 row below) and SZ-08 (waits for glossary work). **Ran in 0.6.2,** though C-1's scope and rule still list them: WP-19's P3 items (SUI-09 needed no change, SW-21, C2) and SW-13; WP-15 item 2 (internalize shipped, G-15) and item 3 (SZ-14 and SZ-11 measured, not adopted); WP-16 item 3 (SEC-15 timed in Session A, not adopted) and item 4 (E10); WP-17 (G-17's after measured). WP-13 items 3-5 had no evidence (G-13b's shots weren't gathered), so both styles stay beta. ROADMAP's Stage 1.7 at v0.6.2 still lists E10 among its open items (its SEC-15, E10 and SEC-18 line) | 0.6.2 Appendix C; ROADMAP at v0.6.2 | C-1: SEC-18's research only (and D-18 isn't needed); WP-18's leftovers in Session R's GUI phase; none of WP-17, WP-15 item 2 or SEC-15 joins Session R's optional steps; W-10's docs pass (the E10 line) |
| D-15: P2 §7.3's frozen widget ("Same kind, look and reload policy"): **held.** At v0.6.2 the widget's source differs from v0.6.1's only in one import (BatteryKit → BatterySource), and `WidgetReloadPolicy` is unchanged; `WidgetRefresher` gained the pre-swap end (D-17) | 0.6.2 code | §7.3 (0.7's changes start from 0.6.1's widget) |
| D-16: ROADMAP's Releases table has download columns, with v0.6.2's counts; `scripts/release-stats.swift` exists and looks for `BatteryPulse-count.txt`: **the script, yes** (WP-19's `4855705`; it prints "—" for the count before v0.7.0). **The columns, not yet:** at v0.6.2 the Releases table has none, and Stage 1.7's "A week after publishing" item is open (v0.6.2 was published on 2026-10-30) | 0.6.2 D3 | §13 step 8 (if the columns are still missing then, it adds them, D-16's fallback) |
| D-17: 0.6.2's installer ends the widget extension before the swap (WP-16 item 6), with its source test: **arrived.** `UpdateInstaller` awaits `WidgetRefresher.endExtensionBeforeSwap()` right before `renamex_np` (`UpdateInstaller.swift:426-427`; the end itself, `WidgetRefresher.swift:75-113`, reloads nothing), pinned by `UpdateInstallTests.endsTheWidgetExtensionRightBeforeTheSwap` (`UpdateInstallTests.swift:314-328`); the first launch keeps `endPreviousExtension()` (`BatteryPulseApp.swift:57-59`). Session B's F12 ran it on the M5: "1 found, 1 ended by SIGTERM, 0 by SIGKILL, 0 still running, 55 ms", and the placed widgets kept (1). So no 0.6.3 comes first | 0.6.2 code; Session B's F12; §6.4 step 3's log | G7-2; W-3a item 10 (0.6.2 has the order test) |
| D-18: the iPad's connection label follows the transport (WP-23): **fixed in 0.6.2** (`2737b51`): the label takes the newest evidence of the transport (`IDeviceRoster.connection(of:now:)`), with Linux tests in `IDeviceMonitorTests`. Not seen on the M5: Session B's device check was planned out of its second attempt, so WP-23's known edges (1)-(5) stay open | 0.6.2 Appendix C (WP-23) | C-1 doesn't carry it; Session R's optional steps may show it |
| W0-1 (CI, 2026-10-22): **passed:** the hand-run processor puts `Metadata.appintents` in the bundle (`extract.actionsdata` 7,700 B), every App Intents part extracted; no `[AppEnum]` per-family `size:` compiles with Xcode 27.1, an `AppEntity` array does, and an integer literal per family is an exact size (§2.2 W0-1, W0-1 (a)) | 0.6.2 Appendix C | W-2; W-3a items 1-2; G7-1 |
| W0-1 (run time, final): **the edit sheets show the parameters** (Battery: Layout, Main value, Time; Custom adds Details, 4 slots on medium); no `ParameterSummary` line; (c) the Refresh button's perform ran in the extension; (b) **not answered** (the Device chooser was never opened); (d) no `Summary` keys dumped (§2.2 W0-1 (b)-(d); row 2 below) | Session A | W-2; W-3a's review (W0-1 (b)); G7-1 |
| W0-2 (final): **passed once the old extension is ended before the swap;** W2's retest in the installer's order was clean (§2.2 W0-2; row 1 below) | Session A | G7-2; D-17; W-3a item 10 |
| W0-3 (final): **A and A′ both read the app's 55 bytes;** B wasn't tested (SPIKE-W probes only A and A′) (§2.2 W0-3: the feed uses A; row 3 below) | Session A | G7-5; W-5 |
| W0-4 (final): (1) **the sandboxed widget reads accessory batteries itself**; (2)-(3) no render line reached the log, so screenshots only; (4)-(5) **two click routes,** the `widgetURL` through `application(_:open:)` and, for a widget without one, an `NSUserActivity` of the intent's type, with no scheme registered (§2.2 W0-4; row 4 below) | Session A | W-8 (G7-8); W-3b item 6 (G7-4); W-1 item 8, W-3c item 2 (G7-9) |
| W0-5 (final): VoiceOver reads 9 items, the level symbol by its name and an empty group; the tree is 9 flat elements; **Text size has no effect** at 17 pt (§2.2 W0-5; row 8 below). Session B's P1 found the desktop widget's host to be NotificationCenter (`com.apple.notificationcenterui`), with a BatteryPulse label in its chain, where Session A's System Events read found the widgets in Finder's desktop group | Session A; Session B's P1 | W-3b item 5 (G7-12); Session R step 7 |
| W0-6 (final): **`sign: .never` counts down without a reload, in English and Russian** (§2.2 W0-6; row 5 below) | Session A | G7-3; W-1 item 4 |
| 0.6.2's A0, the 0.6.1 after-publishing intake: **passed** (recorded 2026-10-22). 0.6.0 → 0.6.1 through Install and Relaunch kept the desktop widget, which shows the current charge, and Open at login kept its state | the maintainer; P2 Appendix C | D-9's baseline; C-1 (WP-16 item 5 has no cause); §7.3 |
| WP-18's Xcode items: what 0.6.2 ran and what it left: **none ran.** In Session B, Xcode asked to install system components after the macOS 27.2 update (SUI-17 reached no canvas), SUI-19's list of the slowest bodies came back empty, and the frozen worktree had no icon source (SZ-10). All three move to 0.7 | 0.6.2 Appendix C (Session B's WP-18 row) | C-1; Session R step 11 (Xcode's components installed first) |
| M-5's answer: **approved as written, with no dates** (recorded 2026-10-22; every decision is in §14) | the maintainer | R-1 |
| Session B (second attempt, 2026-10-30, final): the run. Hands-free on the MacBook Air M5 with macOS 27.2 (26B123), from the script frozen at `f484e23`, on 0.6.1 (B, build 7), the RC (C, 0.5.99 build 373, CI run 40083655970) and the profiling RC (CP); its report is `docs/plans/0.7.0/sessions/B.md`. The first attempt (2026-10-27) was cancelled with nothing recorded | 0.6.2 Appendix C | the rows below |
| Session B: G-10 and G-14a, V-01 on the RC: **passed** (0 "executor" lines, 0 crash reports; the test banner, Raw Data, History, Demo Mode, Check Now, Clear History and the lid close each worked). **V01-menubar's dark bar: not checked:** on macOS 27.2 the menu bar item has no window in CGWindowList (P11); the light bar read right | Session B | D-4, D-6 (WP-10 and WP-14a shipped); the dark bar: C-1 in Session R's GUI phase, another way than CGWindowList (W-12; W-0 item 9) |
| Session B: G-13a, the 8 glass-sheet cases on the RC: **passed, 8 of 8** (an even graphite grey, no black frame) | Session B | nothing in 0.7 (fill (b) shipped) |
| Session B: G-13b and G-13c: G-13b's evidence wasn't gathered, so **both styles stay beta**; S4w Standard 4248.4 and Clear 4335.8 mJ/h, one run each; Translucent, Frosted and Standard's second run not run (a Software Update banner at layer 23) | Session B | nothing in 0.7 (Q-B4); Translucent's and Frosted's energy stay open (ROADMAP Stage 1.5) |
| Session B: G-14b: **passed** (`read cached` p50 0.971 ms over 409 reads; `registry.missed` 0 in 62 minutes; F13 and E3b again on the sampler) | Session B | D-5 |
| Session B: G-15 and F8: **passed:** the RC's small and medium widgets right in English; **Russian "not checked: no redraw"** (D-8) | Session B | D-2, D-3; W-0 item 8 |
| Session B: G-16 and F12: **passed** (D-17's line; no eject-failure line; at most 1 Finder window in 50 samples, against 1 before; the placed widgets 1) | Session B | D-12, D-17; G7-15's F12 |
| Session B: G-17, page switches on the RC: clicked, p50 (p95) **30.4 ms (53.3)** over 69 switches, each page close to Session A's clicked pass; the profiling RC under `xctrace`, **40.2 ms (70.9)** | Session B | 0.7's before for `page.switch`, clicked and under `xctrace`, which W-3c's `MainView.swift` edits compare with |
| Session B: WP-18: **not run** (the WP-18 row above) | Session B | C-1; Session R step 11 |
| Session B: C energy and S7 (WP-21): D-10's numbers. The idle wake-ups (C: 1,215 an hour in S1, 2,670 in S2) have no named sources | Session B | D-10 |
| Session B: F6: **right on all five pages** against `bpulse --json` of the same minute | Session B | nothing in 0.7 (E4b's mixed-age snapshot reads right) |
| Session B: F9: **passed** on Overview, Settings and the update window; the numbers kept the region's format (5,497, 99.0 %) in the Russian UI, macOS's behaviour for a language chosen per app | Session B | nothing to fix |
| Session B: F11: **passed** (the alert's banner after 4923 ms; BatteryPulse gone from Login Items once Open at login was off) | Session B | §6.4's login-item check stands |
| Session B: sleep hygiene and the night: 0 BatteryPulse lines in `pmset -g assertions`, 0 DarkWake or wake lines naming BatteryPulse over 11 sleeps; the `log stream` **survived** the sleeps (199 lines; 4 gaps over 10 minutes, the longest 17) | Session B | §6.2 step 12: no `sudo log config` |
| Session B: preflight and proofs: P1, P2, P4, P7, P9 and P10 passed; P3 (`-R` after the occlusion check), P5 (P4's method), P6 (the session ends its turn before the queue), P8 (System Settings by computer use from the sidebar) and P11 (no menu bar item window: S3 not run) failed to their fallbacks; the quiet check passed; Terminal keeps Accessibility until Session R (B-keep-ax y); no allow rule added | Session B | W-12; §6.2's preflight |
| Session B: runs not valid and not run: not valid, run 7 (the Claude CLI active), run 17 (the window not clear at the end) and run 25 (touched), each retried; not run, runs 18-21 and 24 (a Software Update banner covered the main window) and S3 (P11); planned out, the burst (S8, P12), memory, WP-23's device check and the optional extras | Session B | W-12: preflight asks him to quit the Claude desktop app and postpone pending macOS updates before the queue |
| Session B: the hands-free cost: **about the planned 13-15 minutes of his,** plus closing one banner; the GUI phase 12:30-13:21, the queue 13:42-15:55; F8 in English and F9's Overview redone; still not checked, V01-menubar's dark bar, F8's four "unsure" answers and WP-18 | Session B | §6.2's estimates stand |
| Session B: the findings for 0.7. **(1)** After an AX switch from Raw Data, History showed its title, picker and selection over Raw Data's table for a few seconds; not a 0.6.2 regression [inferred: the AppKit-backed table's removal waits for a window update]. **(2)** For the session script: P11, P8, P6, P3 and P5 as above; the desktop clicks leave click-wallpaper-to-show-desktop on; computer use leaves a 28×40 pointer overlay that fails the occlusion check; layer-23 banners refused the desktop click and blocked five runs; F8 needs its own redraw. **(3)** The cost (the row above) | Session B; D3's reading of `MainView` | W-0 item 9: (1) W-3c, after Session R's pointer-free comparison; (2) W-12; F8's redraw, W-0 item 8 |

**0.6.2's Session A** (2026-10-23 and 24; the local Claude session on the MacBook Air M5). Final,
from its `A.md` (`docs/plans/0.7.0/sessions/A.md`, merged at `5849d01`). The rows first held its
interim report of 2026-10-23, and each says where the final report differs; row 10 is new:

| Fact | Shown by | Decides |
|---|---|---|
| 1. W0-2: SPIKE-C over 0.6.1 and SPIKE-I over SPIKE-C kept the placed small and medium widgets as they were (answers 1; `pluginkit` lists the widget, 0.0.0, from `/Applications`; large and extra large weren't asked, as only small and medium are declared). The first SPIKE-W install (282, over SPIKE-I, in the installer's order: swap, `lsregister -f`, relaunch) failed: at the version change chronod refetched the descriptors in 2 ms, before SPIKE-W's extension started, from SPIKE-I's still running, and stored its 1 static descriptor as version 282's. The placed widgets lost Edit Widget, the gallery offered no Test widget, and every reload failed with CHSErrorDomain 1103 ("Intent configuration is required but was not provided"); a chronod restart kept the descriptor and dropped the cached snapshots, so the widgets turned grey. With the old extension ended first (by hand at 21:06; then W2, run #307, by the script at 21:45, the extension ended about 20 ms before the swap), chronod fetched both descriptors from the new extension, every reload then succeeded (after two CHSErrorDomain 1050 failures at once on the install by hand, and one NSCocoaErrorDomain 4099 at W2's swap, the old process's connection), under the default intent except the widget edited in the sheets, under its own, and the widgets placed under 0.6.1 (small, medium) and under SPIKE-I (medium) redrew in today's look with fresh values (answers 1). The reverse race (0.6.1 over a running SPIKE-W) repaired itself through chronod's refetch of descriptors with unresolved default intents; a static descriptor cached for a configurable version never qualifies, so it stays until the next version change. Reinstalling 0.6.1 over W2 kept every Battery widget; the Test widgets, a kind 0.6.1 lacks, kept W2's last picture. chronod caches descriptors by `CFBundleVersion`; `WidgetRefresher.endPreviousExtension()` runs only at the new app's launch, too late. Fix: 0.6.2's WP-16 item 6 ends the extension before the swap in `UpdateInstaller`, so 0.6.2 → 0.7 is clean; 0.7's first launch keeps `endPreviousExtension()`. **Differs from the interim report,** which quoted 1103 as "Connection to extension process was invalidated" and had the install itself grey the widgets | Session A; P2 WP-16 item 6 | §2.2 W0-2; G7-2; D-17; W-3a item 10; §6.5 |
| 2. W0-1 at run time: the edit sheets show the parameters. Battery's (headed "Battery", "BatteryPulse" and the gallery description): Layout, Main value and Time at 0.6.1's defaults (Automatic, Charge, Clock time); Custom adds Details, with 4 slots on medium. The test widget's: Main value, Details (4 on medium, more on extra large), Device. Neither shows the `ParameterSummary` line ("Show Charge" nowhere). No entity query line: the Device chooser was never opened, and A.md doesn't say whether Details' was, so W0-1 (b) stays open in the final report too, and no `Summary` keys were dumped (W0-1 (d)) | Session A | §2.2 W0-1, W0-1 (b), (d); W-2, W-3a items 1-2; G7-1 |
| 3. W0-3: the feed's candidates A (the home-relative-path read-only exception) and A′ (the shared-preference read-only exception) both work, 55 bytes read. The log prints the feed's age as `age=Ns`, so it doesn't show whether the app wrote while the widget wasn't running | Session A | §2.2 W0-3 (A, for the reason given there); G7-5 |
| 4. W0-4: the sandboxed widget reads accessory batteries itself (sources=2 accessories=1). The four Icon & widget styles redraw per style (screenshots, on the desktop and in Notification Center), but no render log line reached the log from any process, so rendering-mode data comes from screenshots only. The Refresh button's `perform` ran in the widget extension (3 times). Clicks take two routes, with no scheme registered: the Battery widget's `widgetURL` arrived as `batterypulse://page/overview` through `application(_:open:)`, with no window open and with the main window open (its line counted 1 window both times), and two clicks on the body of the Test widget, which sets no `widgetURL`, arrived as an `NSUserActivity` of the intent's type (`SpikeWidgetIntent`), with `WGWidgetUserInfoKeyFamily` and `WGWidgetUserInfoKeyKind` in its user info, no `webpageURL` and no window open. **Differs from the interim report,** which saw no `NSUserActivity` | Session A | W-8 (G7-8); W-3b item 6 (G7-4); W-9; W-1 item 8, W-3c item 2 (G7-9) |
| 5. W0-6: the offset format counts down without a reload, with `sign: .never`. At 21:17 variant a (the default sign) read "-2 hours, 0 minutes" (an offset to a later date is signed) and variant b "2 hours, 0 minutes"; 65 s later "-1 hour, 59 minutes" and "1 hour, 59 minutes" on the same entry. Earlier frames read "2 hours, 10 minutes" and "2 hours, 6 minutes", and a later tree read "10 minutes": a zero minutes field shows, and the hours field drops under an hour. No seconds. In Russian, once redrawn, b read the Russian for "2 hours 12 minutes" without the comma, and a the same with a minus sign; a widget not yet redrawn kept its English text and English minutes. The interim report's "6 minutes" (the maintainer's photo) and the "0 minutes" of 0.6.2's Appendix C at `0a4580e` are two readings of the same countdown, as the interim note said; the final report has both. The finding, `sign: .never`, stands, and Russian passed | Session A | G7-3; W-1 item 4; W-10's guard; D-8 |
| 6. F5, iPad: the connection label doesn't follow the transport (0.6.2's WP-23, P2, fixes it; else C-1, D-18) | Session A | D-18 |
| 7. Charge Limit (the maintainer set System Settings' Charge Limit to 80 %; read-only captures, files kept on the Mac except the redacted `bpulse --raw` capture of the hold, `charge-limit-80.plist`, which came with the final report on his approval, `docs/plans/0.7.0/sessions/A/`): no `ChargeLimit` or `OptimizedCharging` key for the Mac's battery anywhere (`bpulse --raw`, three `ioreg` dumps, `pmset -g` and `pmset -g batt`). When the limit engaged at 80 %: `ChargerData.NotChargingReason` 0 → 16777216 (0x01000000, bit 24) in AppleSmartBattery and in its child AppleChargerData; `ChargingCurrent` 2626 → 0; `IsCharging` 1 → 0; `ExternalConnected` Yes; `FullyCharged` No; SMC `B0AC` and `B0AP` → 0. The configured 80 appears in no key. "Optimized Battery Charging Engaged" exists only in the AirPods' entries. The final report adds, at the hold (21:37): `pmset -g batt` "AC attached; not charging"; in the charger child `ChargingVoltage` 4296 (4314 while charging), `ChargerInhibitReason` 0 and `ChargerHwIlimBackoffReason` 16 (unchanged); pmset's internal battery "Is Charging" false and "Time to Full Charge" 0; the SMC's `B0UC` and `SBAS` at 80, the charge; `bpulse --smc` lists 43 `CH*` keys with types but no values; below the limit (21:33-21:34) no SMC value was 80 but `B0FI`'s raw bytes (8000). The maintainer explicitly asked to show the Charge Limit in the app, the menu bar and the widget | Session A | W-14; Q7-10; G7-18; D-13 |
| 8. W0-5, VoiceOver (from the maintainer's phone photos, the test widget on the desktop, in English): focusing the widget reads "In BatteryPulse, widget, 9 items", then "Three-Quarter-Charged Battery, image"; one step inside, "In Three-Quarter-Charged Battery, image, content is empty". So VoiceOver walks the widget as 9 separate items, reads the SF Symbol by its own name (the 75 % bucket, at 80 %) instead of the charge, and announces an empty group. **The tree** (the final report), read through System Events: Finder's desktop group holds one group per desktop widget, described "widget", with flat children. The medium widget: an image described "image" with no label or value, then 8 texts ("83%", "Not charging", "Maximum capacity", "100%", "Cycle count", "51", "Temperature", "37.8 °C"), the 9 elements VoiceOver counted; the small one: the image, "83%", "Not charging"; the Test widget: 8 texts and a button, each time-left letter apart from its value. No element pairs a label with its value. **Text size** at 17 pt changed nothing: the widgets stayed pixel-identical to a shot at the usual size (answer 2). Russian VoiceOver and the rotor weren't done: driving VoiceOver was too hard for the maintainer | Session A | W-3b item 5 (decorative symbols hidden, the charge labelled with its value, one element per row, a button its own element, `WidgetAccessibility` tested on Linux); Session R step 7 (a tree read, not VoiceOver, under Finder's desktop group); Text size decided (§2.2 W0-5); G7-12 |
| 9. Charge Limit's number and the 100 % diff (read-only reads, exact values). **At the 80 % hold, on AC** (21:37-22:18): `pmset -g battlimit` (no privileges) prints two entries, `chargeSocLimitSoc` 80, `chargeSocLimitReason` `manualChargeLimit`, `chargeSocLimitDrain` 1, `chargeSocLimitIsEOC` 1, `chargeSocLimitNoChargeToFull` 0, `Terminated` 0; `/Library/Preferences/com.apple.powerd.charging.plist` (root's, readable by everyone) holds `bootSessionUUID` and `policies`, an `NSKeyedArchiver` archive of `ChargeCtrlPolicy` objects with `soclimit` 80, `reason` `manualChargeLimit`, `drain`, `isEndOfCharge`, `noChargeToFull`, `owner`, `terminated` and `token` (an `NSUUID`); `com.apple.batteryui.charging.mac` has one key, `…prior.limit` = 80; `notifyutil -g com.apple.system.powersources.chargingtofulloverride` reads 0; the SMC lists `CHLT` (3 `hex_` bytes) and `CHNC` (8), no `CHLS`, values unread; `NotChargingReason` 16777216, `ChargerInhibitReason` 0, `IPDChargingAllowed` 0. **80 → 100 → 80** (23:44-23:47, a minute after each change): at 100 %, battlimit "No battery level limits set", the plist rewritten with no policy, `prior.limit` still 80, `NotChargingReason` 0 in both places, `IsCharging` 1, `ChargingCurrent` 2626, `IPDChargingAllowed` 1, the charge rising 80 → 83 %; back at 80 %, battlimit and the policy as before (the plist rewritten at 23:47:18), bit 24 again, `IsCharging` 0, `ChargingCurrent` 0, `IPDChargingAllowed` 0 and `ChargerInhibitReason` 268439552 (0x10001000), with the charge above the limit. **On battery** (read 1 h 58 min into the energy window): battlimit "No battery level limits set" and no policy in the plist, which had changed about 5 minutes after unplugging (00:01:28); `prior.limit` 80. **After plug-in** (the adapter logged at 01:56:51, read 5 s later): the plist had changed at 01:56:48, with the policy it had before; battlimit 80 again; `prior.limit` 80; `NotChargingReason` 128 (bit 7, not 24), `IsCharging` false, `ChargingCurrent` 0, `IPDChargingAllowed` 0, which was transient: the gauge's next update (01:57:41) was charging, and from 02:15 the charge held at 80 %. So powerd keeps the limit's policy only while on AC, and the setting survives unplugging. **Differs from the interim report,** which had the file as an archive whose `policies` is an embedded property list (the file is a property list, and `policies` holds the archive), and the charger's inhibit key showing charging inhibited at the hold (`ChargerInhibitReason` read 0 at exactly 80 %; `IPDChargingAllowed` 0 is the key that follows the hold) | Session A | W-14's 0.8 candidates, reordered (the plist on AC, then `prior.limit` on battery with its caveat, then `CHLT`, then `battlimit`); W-14 "Settled by the 100 % diff" and item 6; FEA-35's 0.8 half (RD §3.3); W-12's `prepare`; M-3 unchanged (no PowerUI) |
| 10. The widgets in Russian (W0-2-W-ru: 2), new in the final report: with `AppleLanguages` (ru) in the extension's container preferences and the extension ended, the Battery widgets turned Russian (the Russian words for Not charging, Maximum capacity, Cycle count and Temperature), and the Test widgets once Refresh redrew them; the edit sheet stayed English (Battery, Layout, Main value, Time, Details). The spike's strings have their Russian in its catalog (`claude/062-spike-widget`). So D-8's method reaches the widgets, not the sheet, which the system draws from `Metadata.appintents` | Session A | D-8; W-2 item 5 (the check and the fix); W-10 item 2; Session R step 4.3; G7-13 |

**The Charge Limit research** (2026-10-23; working notes outside the repository, built on Apple's
support article https://support.apple.com/102338 and its Russian version, public captures from
other Macs, and this repository's fixtures):

| Fact | Shown by | Decides |
|---|---|---|
| 0.7 ships the "at limit" state only: bit 24 of `NotChargingReason` with external power and `chargeState == .notCharging` (and no optimized hold flag, which wins), a computed `BatterySnapshot` property in a new BatteryCore file, no new `ChargeState` case (it is `Codable` in History and `--json`, frozen), and a type name that never meets `AlertSettings.chargeLimit` | the research; the M5 fixtures (`charging` reads 0, the on-battery and just-plugged-in captures 0x80) | W-14 items 1-2 |
| Where it shows: Apple's wording "Charged to limit", Power's "Charge limit: Reached", the popover and the compact window through the shared phrase, the widget's state line and its `systemChargeLimit` field; no ring or battery marker (the number is unknown, so a tick would sit at the end of the fill); no menu bar icon change; Raw Data decodes bit 24 as the Charge Limit's hold; `bpulse` unchanged | the research | W-14 items 3-5; §7.3 |
| The configured percentage is in no IOKit or IOPS key. Candidates for 0.8, reordered by Session A's final reads (finding 9), best first: powerd's charging preferences file, read as a file by the unsandboxed app (no `Process`, no private framework, no SMC; a property list whose `policies` is a keyed archive that BatteryCore walks generically on Linux, never instantiating the private class, tested with a redacted sample; private and undocumented, so a macOS 27.x update may change it), which holds the active limit only on AC; System Settings' `prior.limit` in `com.apple.batteryui.charging.mac`, which kept 80 on battery but also at 100 %, so it is the last limit set, possibly stale, for use on battery only; the SMC key `CHLT` (inside the read-only SMC rule; seen once on another Mac: the active limit only, 00 on battery; present on the M5, its value unread; a reviewed `bpulse --smc` value read of `CHLT` and `CHNC` first); `pmset -g battlimit` through `Process` (the plist's policy as undocumented text, AC only; a `SecurityGuardTests` exception; only on bit-24 changes or plug-in), now only the file's fallback; last, the private PowerUI framework (contradicts M-3; not recommended unless M-3 is reopened). The sandboxed widget can read the number only through the feed. "Off" is never inferred: 100 % and on battery look alike | the research; Session A's reads (finding 9) | W-14's 0.8 part; FEA-35's second half (RD §3.3) |
| Localization: Apple's Russian support article (https://support.apple.com/ru-ru/102338) gives Apple's terms for Charge Limit, the battery menu's "Charged to [%] Limit" and Charge to Full Now; the catalog's translation of "Charging on hold" (Optimized Charging's hold) must not be reused. The plan lists English keys only; the Russian is verified at implementation against System Settings' own string | Apple's support article | §8; W-10 item 1 |
| Risks: bit 24 is undocumented (Session A's reads on one M5 plus public reports from other Macs); Optimized Charging's hold may set the same bit (unverified, QUA-06); the app's "When charged to 90 %" alert never fires under an 80 % limit | the research | W-14 "Risks"; UG (W-14 item 7) |
| Settled by the 100 % diff (the final `A.md`, finding 9): bit 24 clears and charging resumes when the limit is raised to 100 %, and it returns when the limit is set back to 80 %; `IsCharging`, `ChargingCurrent` and `IPDChargingAllowed` follow it, `ChargerInhibitReason` doesn't (0 at the hold, 0x10001000 when set back below the charge); 100 % looks like no limit. Still open: whether Optimized Charging's hold sets bit 24 (QUA-06), and when bit 24 appears after a plug-in within 5 % of the limit | the final `A.md` | W-14 "Settled by the 100 % diff" and item 6; G7-18 |

**W-1, done early** (2026-10-22, on `claude/070-w1` at `d59c7e6`, CI green, 624 Linux tests; rebased onto v0.6.2 when 0.7 starts):

| Fact | Shown by | Decides |
|---|---|---|
| BatteryCore's public code is not dead-stripped from either binary on 0.6.1's base: with the widget model public, about 85 KB of `__text` landed in both the app and the widget, and every size ceiling but the export counts failed. Internal declarations nothing uses drop out of a release build. So the model stays `internal` (tests use `@testable import`) until its first client makes each part public: W-3a (layout, rows, time text, options, configuration, `ReadCoalescer`), W-3c (`PageID`, `WidgetRoute`), W-8 (the accessories kind, mode and plan). `-internalize-at-link` is widget-only, so the app still carries every public widget type: W-3a makes public only what the widget reads | CI size reports, runs 39829456560 (public) and 39831829438 (internal) | W-3a, W-3c, W-8; G7-10 |
| `make(size:configuration:snapshot:entry:formatter:timeZone:)` takes a `BatteryWidgetConfiguration` that mirrors the intent one to one | `WidgetLayoutPlan.swift` | W-3a |
| Frozen strings chosen: route URLs `io.github.nikitausov.batterypulse://page/<page>` and `…://page/device/<key>` (the rebase onto v0.6.2 changes the scheme to `batterypulse`, the one Session A saw arrive, W-1 item 8); field raw values `state`, `time`, `maximumCapacity`, `condition`, `cycleCount`, `temperature`, `adapter`, `systemLoad`, `batteryPower`, `adapterInput`, `lowPowerMode`, `remainingCapacity`, `cycleLifeUsed`, `cellBalance`, `voltage`; visuals `symbol`, `ring`, `drawnBattery`. Pinned by `WidgetSurfaceTests` | `WidgetOptions.swift`, `WidgetRoute.swift` | §7.3 frozen surfaces |
| Text budget: no reused key is over budget, so no widget-only short key yet. "Lasts until about %@ tomorrow" with "12:59 PM" is 35 characters, over a line's 30; the tests expect "Lasts until %@ tomorrow" (29). Keys pending their catalog entry (English checked, Russian when W-3a adds them): "Full at %@ tomorrow", "Lasts until %@ tomorrow", "Cycle life used", "Cell balance" | `WidgetTextBudgetTests` | W-3a, W-10 |
| Linux ICU prints en_GB's short time without a leading zero ("2:13"), Darwin "02:13"; the time tests avoid single-digit hours | Linux tests | W-1 tests |
| Open for W-3a (review minors): the shipped 0.6.x view still computes the end as `entry.date + minutes`, so it must switch to `WidgetTimeText` in the same commit that adds the stale entry; with serious heat and an abnormal condition at once, the condition shows nowhere; "tomorrow" is decided at each entry's date, so it can say "tomorrow" up to 30-45 minutes past midnight (an entry at local midnight fixes it); the cue symbol on Automatic small and medium at 20 % or less on battery or below 80 % health is an intended difference §7.3 should list | review of `claude/070-w1` | W-3a; §7.3 |

**W-13 item 1, done early** (2026-10-22, on `claude/070-w13` at `f94e3d1`, CI green; rebased onto v0.6.2 when 0.7 starts):

| Fact | Shown by | Decides |
|---|---|---|
| `VersionCounterPolicy` (internal: on by default, a 24-hour grace period, from 0.7.0, `shouldCount`, `url(for:)`, `headers(for:)`, the outcomes and when they mark the version counted, `showsAnnouncement`) and `ReleaseChannel.releaseAsset`, which builds the same URL GitHub's `browser_download_url` gives (pinned against v0.2.0's DMG). Size unchanged while internal. "Once per version" is `lastCounted != current`: going back to an earlier version counts it again a day after it runs, so a higher-numbered local build, marked by its 404, never blocks a release's count (pinned by a test). 0.0.0 and malformed versions get no URL. `SecurityGuardTests` now allows `URLSession(` only in `UpdateChecker.swift` (at most 2) and `VersionCounterPolicy.url` only there (at most 1) | `VersionCounterTests`, `SecurityGuardTests` | W-13 items 2-9 (the app part: cookies off in `UpdateNetwork`, the request inside `check(userInitiated: false)`, three settings keys, the toggle, What's New, the release asset, docs); W-13's size note |

**The early prep** (W-0, 2026-10-30: the commit messages of each `claude/070-<pkg>` branch beyond
0.6.2's own commits, which `git log origin/claude/070-integration..origin/claude/070-<pkg>` lists
together with 0.6.2's history, since main took 0.6.2 as one squash; each head's CI green). One row
per package, where its text in §4 and what was built differ; each branch still has to move onto
`claude/070-integration` (all but W-13's apply cleanly there, `git merge-tree`):

| Fact | Shown by | Decides |
|---|---|---|
| S-1 (`claude/070-s1` at `1ddbe23`, 4 commits on `f484e23`, CI run 41050642928): as items 1-3 say, except: the encoding moved into two `bpulse` functions, `deviceJSON(_:)` and `accessoriesJSON(_:)`, which `Tests/bpulseTests/JSONOutputTests.swift` renders every fixture through (item 1 named only `renderDevice`'s encoder); `MachineJSON` keeps one version per shape, `snapshotFormatVersion` and `deviceBatteryFormatVersion`, both 1, and adds the key by encoding the value and then `formatVersion` into the same keyed container, which works because `JSONEncoder` returns the container it already made at that path (the commit's note; both CI jobs pass); Copy JSON took the helper, so it carries `formatVersion` too (item 2 left that to the run); the guide also says that lists nothing reported (`cellVoltagesMV`, an adapter's `profiles`) stay empty arrays, and how to recognize a `bpulse` before 0.7 | `claude/070-s1`'s log | S-1's review; D1's golden diff (Copy JSON isn't in it, PB §3.4) |
| R-1 (`claude/070-r1` at `583c67f`, 10 commits on `f484e23`, CI run 41073456878): as items 1-5 say, except: `docs/VERIFICATION.md` starts from 0.6.1's release-candidate session and A0, not from 0.6.2's evidence, and already fills Session B's column (2026-10-30), so 0.7's D3 adds only Session R's; the bug template's version hint also asks for the commit of a self-built copy and says it may read "Development build" (`build-app.sh` takes the version from the latest tag); ROADMAP's Platforms line carries PLT-05's sentence (item 3 in item 1's line); the Road to 1.0 section moves C16's Open Anyway statement to the guide's Known limitations and 1.0's notes, and counts the backup key's 5 minutes on top of 0.7's time. ROADMAP's CI bullet still names Xcode 27.1, which W-0 item 7's commit left for R-1, W-10 or the maintainer | `claude/070-r1`'s log | R-1's review; W-10 (the CI line, if R-1 doesn't take it) |
| W-1 (`claude/070-w1` at `dc9604b`, 18 commits on `f484e23`, CI run 41053094003; the W-1 table above names `d59c7e6`, before its move onto `f484e23` and the two route commits): item 3's `make(kind:size:layout:main:visual:statusLines:fields:snapshot:)` is `make(size:configuration:snapshot:entry:formatter:timeZone:)` over a `BatteryWidgetConfiguration` that mirrors the intent (no kind; the entry, formatter and time zone decide the time text and the stale line), and `automatic(size:)` is `automatic(_:)`, the field list; item 9's `ReadCoalescer<Value>` is `ReadCoalescer<Value: Sendable, Pending: Sendable>`, a plain value in plain fields (11.3 → 7.3 KB) whose caller passes the time to `request(at:start:)` and keeps it behind a `Mutex`, with no clock object; item 4's "Lasts until about %@ tomorrow" is "Lasts until %@ tomorrow" (35 characters with "12:59 PM" against a line's 30), beside "Full at %@ tomorrow"; an abnormal condition is the attention row's alone, so a condition row reads only Normal (W-3a's `ebdefa7` keeps a chosen one while heat holds the attention row); the model stays `internal` until its first client (the W-1 table above). Item 8's scheme and activity route landed as written (`3e0cb4f`, `dc9604b`) | `claude/070-w1`'s log; its review | W-3a, W-3c, W-8 (the signatures they call); §8 (the tomorrow keys) |
| W-2 (`claude/070-w2` at `2ed274f`, 8 commits on W-1's head, CI run 41063699129): item 4's ceiling comes now, a provisional 24,000 B for `widget_appintents_bytes` (the spike's metadata was 14,651 B; 0.7's Battery and Accessories intents come to about 16 KB by the spike's per-part sizes), which D1 replaces with the RC plus about 5 %. Item 2's sample is #282's `extract.actionsdata` (14,598 B), and it answers W0-1 (d): the extracted `Summary` keys name parameters as `${name}` ("Show ${mainValue}", "${layout}"). Item 5's check, run on #282's DMG, found every title, type name and case a catalog key with its Russian in the widget's `ru.lproj`, no table recorded, and only those two summary keys in no catalog: so the English sheet came from the method (item 5's "If it passes"), no fix is needed, and plain `Summary` keys must be in the catalog as written. Beyond the items: a description must be recorded as a key (Xcode 27.1 writes `IntentDescription` as `descriptionMetadata`'s `descriptionText`), the check takes the catalog as its second argument and fails on a resources path that isn't a folder, and the packaging step fails when the processor writes no `extract.actionsdata`. The widget unchanged at its base (CI run 384): `__text` 492,660 B, binary 778,784 B | `claude/070-w2`'s log | G7-13 (no W-2 fix; Session R step 4.3 as item 5 says); W-10's placeholder rule (no `${name}` key ships while the summaries stay plain); D1 (the final ceiling) |
| W-3a (`claude/070-w3a` at `2435519`, 11 commits on W-2's head, CI run 41074910285): Details is the entity `BatteryWidgetDetail`, the W0-1 (b) choice §2.2 leaves to W-3a's review (G7-1's default is per-slot `AppEnum`s), its id the field's raw value, sized `IntentCollectionSize(min: 0, max: 1)`, `4`, `8` and `12` per family, which compiles, so W0-1 (a)'s open question is answered; W0-1 (b) itself waits for Session R step 4.1's chooser. **Left out until their views or keys exist:** Main visual offers only the number and symbol (the ring and the drawn battery, listed in `WidgetSourceTests`' `notOfferedYet`, come with W-3b and W-11), and the Details query leaves out Cycle life used and Cell balance (their labels' keys come with large). Each `ParameterSummary` branch is one plain key ("Automatic layout", "Custom layout"); the title is "Choose Battery Details"; the 21 sheet keys and the new gallery description carry their Russian. **Sizes:** the intent alone took the widget's `__text` from 492,660 to 547,412 B and its binary from 778,784 to 918,352 B (`39e4a6a`), the configurable widget to 643,356 and 1,042,464 B (`7cfa0af`, CI run 41068523987: +31 % and +34 %, over 0.6.2's ceilings), so `f6c879d` raised the ceilings to 676,000 and 1,095,000 B, about 5 % above that build and within 0.6.1's, in W-3a rather than at D1 (§9 rule 1; G7-10 allows it); `widget_appintents_bytes` 12,247 B, `strings_bytes` 243,130 B. **Beyond the items:** item 10 extends 0.6.2's order test (the pre-swap end reloads nothing; the first launch still calls `endPreviousExtension()`); item 11's test target links the executable and renders English only; W-1's review minors are settled (small's time detail is its phrase alone, a chosen condition row stays while heat holds the attention row, each parameter's default is pinned to the 0.6.x widget) | `claude/070-w3a`'s log; CI | W-3a's review (Details' entity, before its merge); §9 and G7-10 (W-3a alone used about 150 KB of §9's 100-250 KB `__text` estimate); W-3b, W-11; the look check (CI's PNGs) |
| W-13 (`claude/070-w13` at `f94e3d1`, 4 commits on `a2f738d`, an earlier 0.6.2 commit, CI run 39838003866): item 1 as the W-13 table above records. What changed around it: E10 shipped in 0.6.2 (D-14), so at v0.6.2 the automatic check runs as `check(.automatic)` in a task of its own, which Check Now may cancel (`UpdateChecker.swift:118-130`); items 2-9 put the count on that path, not in `check(userInitiated: false)`, and §5's "C-1's E10 rebases over W-13's `UpdateChecker.swift`" no longer applies: W-13 builds on E10. Its commits don't apply cleanly on `claude/070-integration`: `SecurityGuardTests.swift` conflicts with v0.6.2's (SW-13's escape placements, BatterySource's paths) | `claude/070-w13`'s log; `git merge-tree` | W-13's move onto the integration branch and items 2-9; §5's E10 note |

**0.7's own:**

| Fact | Shown by | Decides |
|---|---|---|
| The widget's `__text`, binary, `widget_appintents_bytes` and `strings_bytes` per commit | CI | G7-10 |
| `appintents-check`'s counts; the extracted `Summary` keys | CI (W-2, W-3a) | W-10's placeholder rule |
| The edit sheet's strings: their keys and tables in the metadata, and the widget bundle's Russian for each (W-2 item 5) | CI (W-2, W-3a) | G7-13; W-2's fix |
| Whether the render test target links; whether Russian renders | CI (W-3a) | §6.1 |
| The look check's answers 1-9, and the second look's | the PR | W-3b, W-8, §14 |
| Session R steps 2-9b, per step: the answers, screenshots, `pluginkit`, the pre-swap and CHSErrorDomain 1103 lines, the click pages, step 7's accessibility tree (or Inspector screenshots) against the label builder, step 9b's Charge Limit screenshots | Session R | G7-2, G7-3, G7-4, G7-8, G7-9, G7-12, G7-13, G7-18 |
| W-14: the Russian Charge Limit screenshot (the redacted fixture and the 100 % diff came with the final `A.md`, D-13) | Session R step 9b | W-10 item 1 |
| Details' chooser lists the fields (W0-1 (b)), and whether `init(min:max:)` compiled per family | W-3a's review (the choice) and first CI build; Session R step 4.1 (the chooser) | W-3a items 1-2 |
| Step 4.4: whether a parameter added to a shipped intent kept the placed widget's choices | Session R (RC-P) | 1.1's added parameters (RD C14 item 5) |
| Step 9: the per-kind counts from `currentConfigurations()` against the widgets placed | Session R | G7-17; W-4 item 3 |
| Per kind: reloads requested and delivered, the share and the median delay; the widget's reads and their time per day; crash reports; faults; assertions | the logged day | G7-11, G7-16; §10 |
| F12: RC-F came back as 0.6.2 | the logged day's end | G7-15 |
| The golden diff against v0.6.2 | D1 | G7-14 |
| The identifier `git grep` diff | D1 | §7.3 |
| W-13: the toggle on, then greyed under Never, in English and Russian | Session R step 6 (screenshots) | W-13's acceptance |
| W-13 (optional): a `noCounter` line for 0.6.99, if the candidate ran for 24 hours | the logged day | W-13's 404 path |
| After publishing: the steps of §6.4 | D3 | G7-15; ROADMAP Stage 1.2; the guide's known limitations (§12) |
| W-13: What's New lists the count; the `counted` log line; v0.7.0's count at 1 or more about 10 minutes later; `release.yml`'s asset check | §6.4 steps 2 and 6; the release run | W-13's acceptance |
| A week after publishing: v0.7.0's DMG, `.sig` and `BatteryPulse-count.txt` download counts | `scripts/release-stats.swift` (§13 step 8) | ROADMAP's Releases table (NEW-23, W-13) |
