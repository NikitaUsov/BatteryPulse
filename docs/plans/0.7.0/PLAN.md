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

**Sources and how they are cited**

| Short | Source |
|---|---|
| R:n | `docs/ROADMAP.md`, line n |
| UG:n, RM:n | `docs/USER_GUIDE.md`, `README.md`, line n |
| file:line | a file in `Sources`, `Tests`, `scripts`, `Resources` or `.github` |
| CL | `CLAUDE.md` (it wins over every other source) |
| P2 | the verified 0.6.2 plan, `docs/plans/0.6.2/PLAN.md`: section, package (`WP-…`), spike (`W0-…`), widget package (`W-…`) or question (`Q-…`) |
| RD | the roadmap to 1.0, `docs/plans/1.0/ROADMAP.md`: section, criterion (`C…`), decision (`M-…`) or new item (`NEW-…`) |
| INV | `docs/plans/1.0/INVENTORY.md`, by row ID (`FEA-06` …) |
| P1, PB | the 0.6.1 plan and playbook, `6aec4d2:docs/plans/0.6.1/` (in PR 11's history) |
| HIG | https://developer.apple.com/design/human-interface-guidelines/widgets |
| NOTES27 | the macOS 27 release notes, https://developer.apple.com/documentation/macos-release-notes/macos-27-release-notes |

- **Revision:** R, UG, RM, CL and file:line refer to `eebf748` on `claude/nice-faraday-k08mhb`, which
  is v0.6.1 (`7622373`) plus the 0.6.2 plan. 0.6.2 will move files (WP-15) and edit most app files
  (WP-10), so W-0 re-resolves every file:line at the v0.6.2 tag before code starts.
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
  tooling), W-13 (the anonymous version count), S-1 (`bpulse`'s JSON), R-1 (docs riders), K-1 (the
  backup key) and C-1 (0.6.2 carry-overs).
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
      update. Three states differ on purpose: an end on a later day reads "tomorrow"; the attention
      row shows for an abnormal condition or high heat (in small it replaces the time line); and
      "Updated %@" shows once the reading is over 45 minutes old (§7.3).
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
  - **The Accessories widget,** if 0.6.2's W0-4 showed the sandbox can read accessory batteries
    (P2 §8.4).
- **Conditional (stretch):** the data feed and the History and iPhone & iPad widgets (W-5 to W-7).
  - They run only if W0-3 passed with candidate A or A′ and the MVP leaves budget. The other two
    conditions hold since 2026-10-22: Q-W3 is yes, and M-1 (the paid account) is no, so the feed
    is their only route (there is no App Group without the account).
  - If W0-3 passed but they miss 0.7.0, they go to 1.1 on the feed, not 0.7.x (RD §3.2, §4.1). If
    W0-3 failed, they are not possible without the paid account (RD §4.2).
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
    renders. A second look of about 3 minutes follows W-8 (§6.1b).
  - **Session R, about 83 minutes on the M5** with the release candidate.
  - **A logged day** of normal use with the candidate installed. It is passive, and its end takes
    about 10 minutes (F12 runs then, §6.3).
  - **The after-publishing check,** about 13 minutes, plus a passive 10-minute wait for W-13's count.
  - **The backup key** (M-9): about 5 minutes in Terminal, any time before C1 (§14).
  - If 0.6.2's Session A never ran its widget spikes, there is a 35-minute spike sitting first
    (W-0S, §2.3).
  - If 0.6.2 left any of WP-18's Xcode items, they run whenever Xcode is open, from Claude's
    step-by-step list (C-1; Xcode is installed on the M5, Q-B7).
- **Budget** [estimate]: about 28-31 implementation and review runs, plus 3 for fixing forward. The
  never-cut set is about 23-26 runs (§7.2). The stretch adds 8-9.
- **Not in 0.7** (RD §4.1): Refresh buttons, extra-large portrait, the dashboard, per-row links,
  choosing specific accessories, and "why it isn't charging" as a widget field (W-9; FEA-15 to
  FEA-20).

---

## 2. Inputs and dependencies on 0.6.2

### 2.1 What 0.7 takes from 0.6.2, and what it does if that is missing

| # | 0.6.2 item (P2) | What 0.7 needs from it | If it failed, was cut or never ran |
|---|---|---|---|
| D-1 | WP-W0's answers. D3 moves them, with §8, §9.1 and the Q-W block, to `docs/plans/0.7.0/widgets.md` (P2 D3) | The row of P2 §8.16 that applies to each spike (§2.2) | **File missing:** main receives only squash merges, so `docs/plans/` never enters main's history (`git log 7622373 -- docs/plans` is empty), and P1 §8 deletes `claude/*` branches after a release. So 0.6.2's D3 is asked, as a request from this plan, to copy into `docs/plans/0.7.0/` before 0.6.2's branches are deleted (the integration branch `claude/nice-faraday-k08mhb`, `claude/062-<pkg>` and `claude/062-spike-widget`): `m5-session.sh`, its swap helper and the whole of P2 Appendix C (not only the W0 rows). Either way the release PR's `refs/pull/<n>/head` keeps them reachable (§14, Q7-8). **Spikes never ran:** W-0S runs them (§2.3) |
| D-2 | K-03, the `BatterySource` target (WP-15 item 1, G-15) | CryptoKit and the device stack out of the widget (about 187 KB, P2 §2.3). `MacAccessoryProvider` sits in the lower target, so W-8 needs no second split (P2 WP-15) | **Nothing blocks.** `MacAccessoryProvider` is in BatteryKit today (`BatteryKit/MacAccessoryProvider.swift`), and the widget can log through its own `Signposts(subsystem:log:)`, which is public (`BatteryKit/Diagnostics.swift`, `public struct Signposts`). **Only size suffers:** G7-10 decides, and if the widget would cross 0.6.1's ceilings, K-03 runs as written in P2 WP-15 before W-3a ("W-0K") |
| D-3 | `-internalize-at-link` on the widget (WP-15 item 2) | About −27 % of the widget's `__text` (P2 WP-15, measured in a native build) | **Less headroom.** G7-10's cut order applies: `Path` instead of Swift Charts, SIZ-07, W-11 cut first |
| D-4 | WP-14a, the nonisolated read (E20) | The widget's async provider reads without the `Task { @MainActor in … }` hops of today (`BatteryPulseWidget.swift:50, 56`; P2 §8.10). WP-14a covers the battery read only: `MacAccessoryProvider` stays `@MainActor` (`BatteryKit/MacAccessoryProvider.swift:14-15`), so W-8's read hops once (W-8 item 4) | **Reverted:** the provider keeps one hop around the synchronous `read()`. `WidgetReadCache` still makes it one read per burst. No blocker |
| D-5 | WP-14b, the registry only when it changes (E4b) | Nothing. The widget makes a new provider for each read (`BatteryPulseWidget.swift:68-70`), so it never takes a cached-registry path | **Either way:** W-3a pins with a source test that the widget never passes a cached-registry scope |
| D-6 | WP-10, main actor by default for the app | 0.7's edits to `WidgetRefresher` and `AppDelegate` are written in the default-isolation style. The widget stays nonisolated (REJ-30; P2 WP-10) | **Reverted:** 0.7's app edits keep explicit `@MainActor`, as v0.6.1 does |
| D-7 | SIZ-04: widget ceilings lowered to the RC plus about 5 % (WP-15 item 4) | 0.7's growth shows in CI, and every raise is a commit of its own (`size-budget.json` "about") | **Not lowered:** 0.6.1's ceilings stand (`scripts/size-budget.json`), with the same rule |
| D-8 | L10N-03: a way to show the widget in Russian (Session A step 3.3) | Session R checks the Russian edit sheet and widgets (§6) | **No method found:** the Russian half is recorded "not checked", never "n". `WidgetTextBudget` (W-1) checks lengths on Linux |
| D-9 | DIS-06: did the 0.6.1 → 0.6.2 in-app update keep placed widgets? (D3's after-publishing check) | The baseline for "placed widgets survive" (G7-2). 0.6.2's A0 already saw one in-app update keep them: 0.6.0 → 0.6.1 through Install and Relaunch kept the desktop widget, which shows the current charge (2026-10-22, Appendix C) | **Lost in 0.6.2 too:** the loss comes from the update, not from configuration (P2 §8.16, the second W0-2 row). The notes then say "add it again if it's gone" |
| D-10 | WP-21's energy numbers (S1, S2, S6, S7) | The baseline for 0.7's widget runs (§10) | **Missing:** 0.7 measures the widget's reads and reloads alone, and the comparison waits for the final 0.9.x energy run (RD C5) |
| D-11 | The 0.6.2 session script: prepare, backup, restore, the swap helper, `send` (P2 §6, WP-21) | W-12 builds 0.7's script from it | **Removed with the plan folder in D3:** the copy D-1 asks for in `docs/plans/0.7.0/`, or 0.6.2's integration branch, `claude/nice-faraday-k08mhb`, if it was kept. If neither exists, W-12 rebuilds the script from 0.6.1's (`6aec4d2:docs/plans/0.6.1/m5-session.sh`) and P2 §6's text (+1 run) |
| D-12 | WP-16, the `diskutil` installer (G-16) | F12 (at the logged day's end, §6.3) tests whichever installer the RC carries | **Reverted to `hdiutil`:** F12 runs as in 0.6.1 |
| D-13 | QUA-05, the Charge Limit capture (optional in 0.6.2) | Nothing in 0.7's code. 0.8's NEW-01 wants it before its freeze; without it, the Charge Limit cause doesn't ship (RD §3.3, §5.1 QUA-05) | **Missing:** Session R offers it as an optional step, W-12's `charge-limit` (RD §3.2) |
| D-14 | 0.6.2's cut list (P2 §7.2: "a cut item moves to 0.7") | — | **Without M5 time:** C-1, the Linux-only lane. **With M5 time:** Session R's optional steps, or the verification matrix (RD §3.2) |
| D-15 | P2 §7.3's frozen list ("Widget. Same kind, look and reload policy.") | 0.7 changes the kind's configuration, its families and the reload policy on purpose (§7.3) | — |
| D-16 | NEW-23: 0.6.2's D3 adds download columns to ROADMAP's Releases table and, a week after publishing, records v0.6.2's DMG and `.sig` counts, printed by 0.6.2's new `scripts/release-stats.swift` (P2 D3; RD §1.2 item 6) | The columns 0.7.0's counts go into (§13 step 8), and the script that prints them. It already looks for `BatteryPulse-count.txt` and prints "—" before v0.7.0 | **Columns missing:** §13 step 8 adds them and fills the earlier releases from the same releases API call (RD §3.1 item 7). **Script missing:** step 8's `gh api` call, once per release |

### 2.2 The spike answers and what 0.7 ships for each

P2 §8.16 holds the fallback for each failed spike. This table adds the outcome "not run" and what
the session checks again.

| Spike (P2 WP-W0) | Pass: 0.7 ships | Fail: 0.7 ships (P2 §8.16) | Not run |
|---|---|---|---|
| **W0-1:** App Intents metadata through a manual `appintentsmetadataprocessor` step | W-2, then the configurable kind | **No configuration.** Preset kinds instead (FEA-13), each a fixed `WidgetLayoutPlan` with no App Intents anywhere, and W-2 dropped: Battery (today's kind and look, plus large and extra large), Battery Health and Power | W-0S |
| **W0-1 (a):** the per-family `size:` overload compiles against macOS 27.0 | Details take up to 1, 4, 8 and 12 per family, written as `IntentCollectionSize(min: 0, max: N)`. Apple documents no meaning for the integer-literal form (exactly N or at most N), so it isn't used (W-3a item 1) | One `IntentCollectionSize(min: 0, max: 12)` for every family (`IntentCollectionSize` has `init(exactly:)` and `init(min:max:)`, https://developer.apple.com/documentation/appintents/intentcollectionsize). The planner drops what doesn't fit, and the parameter's description says so. **My addition**: P2 names no fallback for (a) | W-0S |
| **W0-1 (b):** entity queries run in the ad-hoc extension | Matters only for W-7 (stretch) | W-7 uses an `AppEnum` (most recent, lowest) | — |
| **W0-1 (c):** button performs run | Nothing in 0.7: the buttons are W-9, after 1.0 | — | — |
| **W0-1 (d):** the extracted `Summary` keys | The placeholder rule as it stands, or one reasoned exception limited to the widget's intent files (P2 §8.11) | — | W-2's CI dumps the keys, and the exception is decided then |
| **W0-2:** placed widgets survive SPIKE-C, then SPIKE-W | Configuration on today's kind | **The control keeps them but the configurable kind loses them:** today's kind stays static, with today's look and the new sizes. The configurable widget becomes a new kind, `io.github.nikitausov.BatteryPulse.battery.custom`, and the notes say how to switch. **The control loses them too:** proceed, and the notes say "add the widget again if it's gone" | Not possible: W-0S runs it first (§2.3). Session R step 2 has no control build, so it confirms G7-2's answer but never decides it alone; W-3a keeps a ready branch for the new kind (G7-2) |
| **W0-3:** a file or preference domain the widget can read (A, A′; B as a last resort) | The stretch may run (G7-5); if it misses 0.7.0, 1.1 on the feed (RD §3.2) | The History and iPhone & iPad widgets are not possible without the paid account, which M-1 declined: there is no App Group (RD §4.2). Candidate B is not used: it would carry only unnamed numbers (P2 §8.3), not worth a frozen surface before 1.0 | The stretch goes to 1.1, where W0-3 runs first |
| **W0-4 (1):** accessory batteries from the sandbox | W-8 in the MVP | No Accessories widget in 0.7 | W-0S; without it, no W-8 |
| **W0-4 (2):** the rendering mode per Icon & widget style, Dim widgets and place | Design and check exactly the modes seen | — | Design for all three modes everywhere, and Session R checks every place. The HIG and Apple's other pages disagree about the Mac [conflict], Appendix B |
| **W0-4 (3):** `redactionReasons` and `showsWidgetContainerBackground` | `.privacySensitive()` on names stays a cheap defence (P2 §8.8) | — | Same |
| **W0-4 (4), (5):** what a click delivers; whether `widgetURL` needs a registered scheme | W-3c handles exactly what arrives; a scheme only if needed (G7-9) | A navigation-only scheme (P2 §8.9) | W-3c handles both the URL and the activity. A scheme is registered only if Session R step 8 shows URL clicks don't arrive |
| **W0-5:** VoiceOver on today's widget; Text size | The labels of P2 §8.15, with the wording tuned to what VoiceOver said | — | P2 §8.15 as designed |
| **W0-6:** the offset format prints "2 hours, 13 minutes" and counts down without a reload | Time offers clock time or time left | Time left is dropped. Clock time only, and the Time parameter isn't shipped: a parameter with one case would be a frozen surface for nothing. **Not a fail:** a leading minus ("−2 hours, 13 minutes"). P2's expression uses the default `sign: .automatic`, which signs a date before the anchor (https://developer.apple.com/documentation/swiftui/systemformatstyle/dateoffset). 0.7 writes `Text(.currentDate, format: .offset(to: end, allowedFields: [.hour, .minute], sign: .never))` and re-checks it in Session R step 6 | Same as fail |

### 2.3 If 0.6.2's widget spikes never ran (W-0S)

The design can't be settled on Linux: the edit sheet, the sandbox and placed widgets show only on
the M5 (P2 §9 reason 2). So 0.7 runs the spikes first:
- **What:** P2 WP-W0's spikes on `claude/070-spike-widget`, never merged, adapted to the Mac now
  running 0.6.2:
  - **SPIKE-C** is v0.6.2's code with the version raised, installed over the published 0.6.2
    (P2's SPIKE-C was 0.6.1's code over 0.6.1);
  - **no SPIKE-I:** v0.6.2's code already carries whatever internalize decision 0.6.2 shipped;
  - **SPIKE-W** over SPIKE-C, dispatched after it so its build number is higher (P2 WP-W0
    "Order").
- **Who:** 2 runs [estimate], then a sitting of about 35 minutes: P2 §6 Session A, steps 1, 3 and 4.
- **Then:** W-1 and S-1 can still start (they need no answer). Everything from W-2 on waits for this
  sitting.

### 2.4 Decisions needed before code, as answered on 2026-10-22

| Decision | Needed by | Answer (2026-10-22) | Source |
|---|---|---|---|
| M-1: buy the paid account? | before W-0 ends | **No** (the maintainer): not now, and not planned before 1.0. The stretch rests on W0-3 alone (G7-5), and nothing in 0.7 waits for a signed build (§14) | RD §6 M-1 |
| M-2: an iOS app? | R-1 | **Not in 1.x** (by delegation). R-1 removes the iOS promises (RM:5, RM:14-15, RM:192-206; both issue templates) and updates ROADMAP's Decisions | RD M-2; R:704-706 |
| M-3: charge limiting? | R-1 (one ROADMAP Decisions line) | **Not in 1.x** (by delegation) | RD M-3 |
| M-5: what 1.0 means | R-1 | **Approved as written** (the maintainer, 2026-10-22). Five promises: seen working on the M5 in a packaged build; a week of daily use without a crash; in-app updates from older versions; nothing breaks through 1.x; usable by a non-expert. **No dates:** "this is a hobby project; we release when there is time and desire". No target date, calendar or outer bound; the order of versions and the effort estimates stay, and 1.1 (macOS 28 compatibility) comes after macOS 28 ships, an event, not a date. R-1 condenses it into ROADMAP | RD M-5 |
| M-9: the backup key | K-1 | **Yes** (by delegation). K-1 runs once the maintainer has generated the key; if it doesn't exist by C1, K-1 moves to 0.8 | RD M-9 |
| Q-W1 | W-0 | **Yes** (the maintainer): widgets in 0.7, no 0.6.3 | P2 §10; RD §5.3 |
| Q-W2 to Q-W13; Q7-1 to Q7-7 | W-3a (look and behaviour); the look check (the rest) | **As §14 recommends** (by delegation; Q-W3 yes, following the maintainer's M-1 answer). The look check signs off the looks they lead to (§6.1). Q7-8 was settled earlier | P2 §10; RD §5.3 |
| Q7-9: an anonymous version count | W-13 | **Yes, on by default, announced plainly** (the maintainer). W-13 is the verified design | §14 Q7-9; Appendix B VC-1 to VC-8 |

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
  - intent and `AppEnum` metadata are `static let`, not P2's sample `static var` (W-3a item 1);
  - `PageID` also holds `developer` and `demo`, which `SidebarItem.storageKey` returns
    (`MainView.swift:64-75`), and `WidgetRoute` rejects them (W-1 item 8; P2 §8.6 lists only the
    pages a widget opens);
  - `WidgetTextBudget`'s budgets come from today's widget with its scale factors, because P2 §8.6's
    example budgets are below reused Russian keys (W-1 item 5);
  - the attention row also changes Automatic small and medium, in the states where it shows
    (§7.3; P2 §8.5 places it "in every family and layout").
- **`WidgetChartSummary` moves to W-6.** It has no user in the MVP, and the dead-code rule applies
  (PB §1.6). If W-6 doesn't ship, 0.8's A11Y-01 builds it (RD §3.3).
- **Reuse of the app's labels** in the widget's details. The app's Power page says "System load" and
  "Power from adapter" (`Main/PowerView.swift`), so the widget doesn't add new names for the same
  values.
- **A build-number fix** (§6.5, Appendix B): CI builds carry CI run numbers (258 on 2026-10-22),
  and releases carry the release workflow's own (7 for 0.6.1; ci.yml:135, release.yml:109). Once the
  M5 has run RC-U, the published 0.7.0 would almost certainly have a lower `CFBundleVersion`, and
  WidgetKit caches by `CFBundleVersion` (`build-app.sh:112-113`). So D1 makes both workflows take
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
  intent code. §5 orders the catalog: W-3a, then W-3b, then W-8, then W-13, then W-10.
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
  1. Read 0.6.2's Appendix C (in `docs/plans/0.7.0/widgets.md`, or the copy or kept branch of D-1).
     Fill this plan's Appendix C table "From 0.6.2" with each D-row and each W0 row.
  2. Pick the §2.2 row for each spike, and write the resulting scope into §4's packages as one
     commit to the committed plan.
  3. Re-resolve every file:line of this plan at the v0.6.2 tag. WP-15's git moves and WP-10's edits
     shift most of them.
  4. Check that every decision is still as recorded on 2026-10-22: M-1, M-2, M-3, M-5 (approved,
     no dates), M-9, Q-W1 to Q-W13 and Q7-1 to Q7-9 (§2.4, §14).
  5. Decide W-0S (§2.3) and W-0K (D-2).
  6. **Before 0.6.2's branches are deleted** (the integration branch `claude/nice-faraday-k08mhb`,
     and `claude/062-*`; this is asked of 0.6.2's D3 too): check that
     `docs/plans/0.7.0/` holds 0.6.2's `m5-session.sh`, its swap helper and the whole P2 Appendix C
     (D-1, D-11). If not, read them from the 0.6.2 release PR's `refs/pull/<n>/head` (Q7-8).
- **Acceptance:** Appendix C's "From 0.6.2" table is complete, and every package below names its
  §2.2 row.
- **Effort:** none in runs. W-0S, if needed, is 2 runs plus a 35-minute sitting.

### S-1: `bpulse`'s JSON for scripts: ISO 8601 device dates and `formatVersion` (P1)

- **Source:**
  - CB-02 (P1 §8 Q3; R:554-556; INV QUA-14);
  - NEW-11 (RD §3.2, §5.2);
  - the frozen-outputs rule (R:437-439; PB §3.4 "Public outputs of `bpulse`").
- **Items:**
  1. **Dates:** `renderDevice`'s encoder sets `.iso8601` (`Sources/bpulse/main.swift:189-190`).
     - Today it has no date strategy, so `firstUseDate` prints as seconds since 2001. The Mac's
       `--json` already uses ISO 8601 (`main.swift:161-163`).
     - Only the `bpulse` encoder changes. `IDeviceBattery`'s `Codable` conformance stays as it is,
       because `DeviceStore` persists it with its own ISO 8601 encoder (`DeviceStore.swift:141-149`)
       and storage is frozen.
  2. **`formatVersion`** in every top-level JSON object `bpulse` prints:
     - **Gains it:** `--json`; each compact line of `--watch --json` (`main.swift:162`); `--device
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
  3. **PLT-05:** ROADMAP records that CI keeps building BatteryKit for iOS (ci.yml:130-131) until
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
     - An end beyond tomorrow shows no clock time: valid estimates run up to 65,534 minutes
       (`MacPowerParser.swift:123, 281-284`). An end beyond tomorrow shows no clock time and no
       weekday (Q-W5, decided by delegation, §14).
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
    `demo`, invalid `DeviceKey`s, and `DeviceKey.demo`.
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

### W-2: The App Intents metadata step (P1; drops out if G7-1 fails)

- **Source:** P2 §8.14 W-2, WP-W0's W0-1 (the route and the processor options); INV FEA-08; SIZ-06.
- **Items:**
  1. **The step in `scripts/build-app.sh`,** after the widget's build and before its `codesign`
     (`build-app.sh:203`):
     - Collect the widget module's `.swiftconstvalues` and Swift sources into file lists.
     - Run `xcrun appintentsmetadataprocessor` with the options W0-1 validated, on the unstripped
       binary `$BIN_PATH/BatteryPulseWidget` (P2 W0-1). The bundle's copy (`$WIDGET`, copied at
       `build-app.sh:117`) is stripped at :186 and keeps the same UUID, which the dSYM check at
       :188-197 relies on; the symbol checks at :150-163 read `$BIN_PATH` for the same reason.
     - Write `$APPEX/Contents/Resources/Metadata.appintents`, before :203.
     - Why a step of our own: SwiftPM sets `LM_SKIP_METADATA_EXTRACTION=YES` (P2 Appendix B).
     - No new compiler flag (CL: "no compiler flags of its own").
     - While the widget declares no App Intents type, the step prints a note and skips. W-3a makes
       it unconditional.
  2. **`scripts/appintents-check.swift`:**
     - Reads `extract.actionsdata` and `scripts/widget-manifest.json`.
     - Fails unless every intent, parameter and `AppEnum` case of the manifest is in the metadata.
       The processor can exit 0 without writing (P2 W0-1).
     - Dumps the extracted `Summary` keys for W-10's placeholder decision (W0-1 (d)).
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
- **Effort:** M, 2 runs. **Risk:** medium.
  - The processor's options come from Swift Build's spec (P2 Appendix B, "per the review, not
    re-checked").
  - Xcode 27.1 on the runner (ci.yml:63) must ship the processor [unverified until W0-1].
- **Rollback:** revert. Without metadata the edit sheet is empty, and whether such a widget still
  appears in the gallery is [unverified]. So a revert of W-2 means G7-1's fallback (presets), not a
  configurable widget without metadata.

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
  10. **The W0-2 fallback, prepared** on `claude/070-w3-newkind` and never merged unless G7-2 says
      so: today's kind stays a `StaticConfiguration`, and the configurable widget gets the kind
      `io.github.nikitausov.BatteryPulse.battery.custom`. It is one merge if Session R step 2
      fails.
  11. **CI render previews (TCI-10)**, a review aid and not a gate:
      - A macOS-only test target `BatteryPulseWidgetTests` does `@testable import
        BatteryPulseWidget` and renders each family with `ImageRenderer` into PNG artifacts.
      - `\.widgetFamily` is get-only
        (https://developer.apple.com/documentation/swiftui/environmentvalues/widgetfamily), so a
        test can't set it. The views therefore take a `WidgetSize` input, and only a thin root view
        reads `\.widgetFamily` and maps it; the tests pass each size.
      - A ci.yml step uploads `build/widget-previews/*.png` as an artifact. The workflow only reads
        the repository (`permissions: contents: read`, ci.yml:22-23), so CI never comments on the
        PR: the orchestrator downloads the artifact and posts the pictures (§6.1).
      - [unverified] whether a test can link an executable target that uses `-e _NSExtensionMain`.
        If it can't, the look check moves into Session R (+10 minutes).
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
  - `Tests/BatteryCoreTests/*` (source tests); `Tests/BatteryPulseWidgetTests/*`.
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
- **Rollback:** revert the merge, and with it W-3b and W-8 (revert those first). G7-2's branch is the
  fallback for placed widgets.

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

       These four new reasons share a 5-minute minimum between their reloads; today's policy keeps
       its own rules for plug and state changes. A temperature move of 3 °C waits for the 15-minute
       interval.
     - **Accessories:** a connect or a disconnect reloads at once. A 10-point step waits until 15
       minutes have passed since the kind's last reload.
     - **History and iPhone & iPad:** their policies arrive with W-6 and W-7 (stretch).
     - One planner for every configuration: the app never reads configurations, so it accepts the
       odd reload a widget doesn't need (P2 §8.6).
  2. **`WidgetRefresher` uses the planner** (still the only reload site; EN-11).
     - It observes `monitor.snapshot` (as today, `WidgetRefresher.swift:24-32`) and the
       `AccessoryMonitor`'s list, each in a named task over `Observations { … }.dropFirst()` (CL
       observation rule).
     - The app passes `accessories` in (`App/BatteryPulseApp.swift:33-43`).
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
    so `evaluate()` returns before the planner runs, `WidgetRefresher.swift:74`.)
- **Effort:** M, 2 runs. **Risk:** low-medium. **Rollback:** revert. `WidgetReloadPolicy` alone
  comes back.

### W-3b: Large and extra large, visuals, the attention row, accessibility, rendering modes (P1)

- **Source:** P2 §8.5, §8.7, §8.15, §8.17; INV A11Y-06; HIG; the §2.2 rows for W0-4 (2) and W0-5;
  Q-W4, Q-W10, Q-W13.
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
  5. **Accessibility** (P2 §8.15):
     - **One element per block** (`accessibilityElement(children: .combine)`), with a label built
       from the formatted strings.
     - **The level symbol is hidden** (`accessibilityHidden(true)`). Its bucket can contradict the
       number: `battery.75percent` stands for 63-87 % (`BatteryPresentation.swift:15-20`).
     - **Detail rows** read "label, value".
     - **Text styles,** except the hero number. Values never truncate, and the planner drops a row
       instead.
     - The wording follows what W0-5 heard.
  6. **Rendering modes** (P2 §8.7):
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
  (the large and extra-large plans), `Resources/Localizable.xcstrings`, `scripts/widget-manifest.json`,
  the tests.
- **Guards:** W-1's cue test. The motion guards already cover the widget
  (`MotionGuardTests.swift:9-14, 168-216` per P2 §8.1). W-10 adds the time-text rules.
- **Acceptance:**
  - Both jobs green.
  - PNGs of every family and mode in the PR, for the look check.
  - The manifest lists the new families and cases.
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
     `build-app.sh:105`) usually has no window (P2 §8.9).
     - `AppDelegate.application(_:open:)` takes the URL, through `WidgetRoute(url:)`.
     - `application(_:continue:restorationHandler:)` takes a click without a URL: an
       `NSUserActivity` with the kind and family in its userInfo (P2 §8.2). Its exact type string is
       W0-4 (4)'s answer. It routes by kind to the natural page.
     - The app never imports App Intents (REJ-60), so `widgetConfigurationIntent(of:)` isn't used.
  3. **`WindowOpener.showMainWindow(page:)`** (`App/AppSettings.swift:224-240`):
     - A click with a page opens the main window at that page, because the compact window has no
       pages (Q7-6).
     - The page passes through an `@Observable` request, the way `DemoController.pageRequest` does
       (`MainView.swift:238`).
     - **The request stays pending until it is consumed.** The usual click finds BatteryPulse not
       running or without a window (the widget works without the app, UG:419).
       `WindowOpener.openWindow` is captured only when a view appears (`AppSettings.swift:224-240`,
       `MenuBarLabel.swift:66`), so a URL delivered at launch can find it nil. MainView applies
       `pageRequest` only in `.onChange` without `initial:` (`MainView.swift:238`), so a MainView
       created after the request restores the `@SceneStorage` page instead. So MainView applies the
       request in `.onChange(…, initial: true)` and clears it, and `WindowOpener` retries the open
       once `openWindow` is captured.
     - A device page whose device was forgotten opens the Devices intro.
  4. **The URL scheme, only per G7-9:** `CFBundleURLTypes` in `build-app.sh`'s app Info.plist
     heredoc (`build-app.sh:87-108`), with a name derived from the bundle ID.
     - It is navigation only, and a link never acts.
     - It is a new frozen surface (§7.3).
- **Linux tests:** `WidgetRoute` (W-1), and a source test that `PageID` equals `storageKey`'s
  literals (W-1's pin).
- **Guards:** `SecurityGuardTests` gains a placement: `application(_:open:)`, `onOpenURL` and
  `handlesExternalEvents` appear only in `App/BatteryPulseApp.swift` (the delegate).
- **Files:** `Sources/BatteryPulseApp/App/BatteryPulseApp.swift`, `App/AppSettings.swift`,
  `Main/MainView.swift`, `scripts/build-app.sh` (only with a scheme),
  `Tests/BatteryCoreTests/SecurityGuardTests.swift`.
- **Acceptance:**
  - Both jobs green; the CI launch smoke.
  - Session R step 8: a click opens the right page with BatteryPulse quit, with no window open,
    with the main window open, and with Window to open set to compact.
- **Effort:** M, 2 runs. **Risk:** medium (activation of an agent app with no window).
- **Rollback:** revert. A click then just opens the app, as in 0.6.1.

### W-8: The Accessories widget (conditional MVP: G7-8)

- **Source:** P2 §8.4, §8.5 (Accessories), §8.8; INV FEA-09, FEA-21; W0-4 (1).
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
     - `MacAccessoryProvider` is `@MainActor` (`BatteryKit/MacAccessoryProvider.swift:14-15`), and
       WP-14a makes only the battery read nonisolated (P2 WP-14a item 1). So the read hops to the
       main actor once per burst (`MainActor.run { MacAccessoryProvider().read() }`) from the
       cache's `@concurrent` function. Making it nonisolated is a separate BatterySource change,
       not in 0.7.
  5. **Names** get `.privacySensitive()`.
     - Never `AccessoryBattery.id` anywhere in the widget: it can be brute-forced back to a
       Bluetooth address (`Accessory.swift:120-130`).
     - The MVP has no entity, so no accessory identifier enters a configuration.
  6. **Empty states:**
     - "No accessories with batteries connected", which opens Accessories.
     - When the lowest one goes away, the next lowest shows.
  7. **Gallery previews** come from `DemoAccessories` when none is connected.
- **Guards:** a source test: the widget target calls `MacAccessoryProvider`'s `read()` and never
  `observeChanges(` or `AccessoryMonitor` (P2 §8.8). The `dlsym` lookup stays in the allowed file
  (`SecurityGuardTests.swift:40-46`).
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
  1. **`docs/plans/0.7.0/m5-session.sh`,** built from 0.6.2's script (D-11: the copy in
     `docs/plans/0.7.0/`, or the kept branch): `prepare`, `backup`, `restore`, the swap helper,
     `send`, `day-start`, `day-end`, and the steps of §6.
     - **`charge-limit`** (QUA-05): asks for the limit set in System Settings → Battery [exact menu
       path unverified on macOS 27] and checks that the charge is at least 5 points below it. It
       then starts `caffeinate -i .build/release/bpulse --record` into a new, empty folder under
       `~/bp-070/` (UG:579-583: `caffeinate -i` keeps the Mac awake, and the folder must not hold
       an earlier recording), and beeps when charging stops at the limit.
     - **`hold-watch`** (QUA-06): the same recording overnight under `caffeinate -i`; in the
       morning it says whether an optimized-charging hold was seen (R:76-77) [uncertain: whether
       macOS holds the charge while the Mac is kept awake].
     - **`count-check`** (W-13; §6.4 step 6): after "Quit BatteryPulse", it clears
       `lastCountedVersion` and `lastUpdateCheck`, back-dates `versionFirstLaunch`, opens
       BatteryPulse again, waits for W-13's `update` log line and, 10 minutes later, runs
       `scripts/release-stats.swift`.
     - Fresh backups go to `~/bp-070/R`.
     - It records the Icon & widget style, Dim widgets on desktop, the appearance, the language, the
       24-hour setting, Open at login and BatteryPulse's Check for updates, asking for those it
       can't read.
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
     - `bpulse --accessories --raw` and `pmset -g accps -xml` side by side, when `bpulse` is built.

     It lives in `scripts/`, not in the plan folder, because it outlives 0.7.
  4. **ci.yml:** `bash -n` for both scripts. The plan script's line goes with the folder at D3.
- **Effort:** S-M, 1-2 runs. **Risk:** none to users.

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
- **Today** (at `eebf748`, Appendix B):
  - **The schedule.** `startAutomaticChecks()` (`UpdateChecker.swift:66-76`) wakes 20 s after
    launch, then every 6 h with a 36-minute tolerance.
  - **When a tick checks.** Only when `UpdatePolicy.isCheckDue` says the chosen interval has passed
    and no rate limit holds (`:116-123`, `Updates.swift:190-238`). Never means no check.
  - **The check.** One GET of `api.github.com/…/releases/latest` with `User-Agent:
    BatteryPulse/<version>`, on `UpdateNetwork.automatic` (`:164-215`). That session is ephemeral,
    has no URL cache, and refuses Low Data Mode and expensive networks.
  - **The installer.** It fetches the `.sig`, then the DMG, through their `browser_download_url` on
    `UpdateNetwork.user`, following GitHub's redirect (`UpdateInstaller.swift:184-234`).
  - **Host rules.** `ReleaseLinks` filters only what the browser opens (`Updates.swift:175-188`).
  - **Guards.** `SecurityGuardTests` bans only `URLSession.shared` (`SecurityGuardTests.swift:47-53`).
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
  4. **Riding on the automatic check.** The count runs in `check(userInitiated:)` (`:125-157`), on
     the success path after `recordCheck()` (`:137`), once the offer is decided (`:139-147`), so a
     window waiting on the check never waits for the count:
     - same task, awaited on `UpdateNetwork.automatic`, inside `update.check`'s interval;
     - no new task, sleep, timer or signpost name;
     - it inherits the session's refusal of Low Data Mode and expensive networks;
     - Check Now never counts.
  5. **Grace day.** `versionFirstLaunch` is written when `lastSeenVersion` changes
     (`BatteryPulseApp.swift:56-59`). No count happens until 24 h after it, so the off switch comes
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
     - the type's doc comment (`:8-13`), "The only network request BatteryPulse makes on its own…",
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
    sessions today (:198, :201). With `.shared` already banned, every request goes through them.
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
- **Effort:** S-M, 2 runs [estimate], plus about 3 minutes and a passive 10-minute wait in §6.4.
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
  W-13's `UpdateChecker.swift`, §5). Each keeps its own P2 section as its spec.
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
  - **WP-18** runs in 0.6.2: Xcode is installed on the M5 (Q-B7, 2026-10-22), and the maintainer
    runs it from Claude's step-by-step list. Any item 0.6.2 cuts (or SZ-10's icon, if it wasn't
    signed off) rides in 0.7 the same way, whenever Xcode is open, and nothing waits for it (RD
    §5.1 TCI-05; Session R step 11). The icon ships only on the maintainer's y to its screenshots
    in the four icon styles.
- **Effort:** 0-2 runs [estimate]. Cut first after the stretch.

### Stretch: W-5 (the feed), W-6 (History), W-7 (iPhone & iPad) (conditional: G7-5)

Specified in P2 §8.3, §8.5 (History, iPhone & iPad, feed-only options), §8.8 and §8.14. This plan
adds only:
- **The gate** (RD §3.2): they run only if all of these hold:
  - W0-3 passed with A or A′;
  - Q-W3 is yes (decided 2026-10-22, following the maintainer's M-1 answer);
  - M-1 is no (decided 2026-10-22, by the maintainer);
  - the MVP has merged with budget left.

  If W0-3 passed but the budget ran out, they go to 1.1 on the feed. If W0-3 failed, they are not
  possible without the paid account: there is no App Group (RD §4.2).
- **One type behind the feed reader,** so the feed's location or entitlement can change later
  without touching the views (RD §3.2 engineering notes); an App Group container could take its
  place only if M-1 is ever revisited.
- **The feed's location is not a 1.x promise** (RD C14 item 2): it links an app and a widget of the
  same version, so it may move in a minor release with a line in the notes, and its version 1
  schema only gains fields. This narrows P2 §8.13, which lists "the feed's path" as frozen.
- **The new entitlement** (one read-only home-relative path, or a shared-preference read-only
  exception) goes into `Resources/BatteryPulseWidget.entitlements` and W-1's pin.
  - The posture check compares against that file and passes unchanged (`build-app.sh:296-302`).
  - The guide's privacy text says what the feed holds (DOC-08).
- **`WidgetChartSummary`** lands in W-6, for 0.8's chart descriptors to reuse (RD §3.3 A11Y-01).
- **Effort** [estimate, RD §3.2]: W-5 3 runs, W-6 3, W-7 2-3; the strings ride in W-10.

### W-10: Localization review, guards, docs (P1; merges last)

- **Source:** P2 §8.7, §8.8, §8.11, §8.14 W-10; INV L10N-04, TCI-11, DOC-07; RD §3.2; §8 and §12
  below.
- **Items:**
  1. **Terminology pass** over every key the widget packages added, with Apple's Russian wording
     (CL localization rule). The review lists each new key with its Russian in the PR.
  2. **`LocalizationCatalogTests` review:** the App Intents literal forms landed in W-1 item 11.
     W-10 checks that every intent string the widget packages added is in the catalog, and adds
     the stretch's forms if it ran. Entity titles are verbatim and ignored (stretch only).
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
     (`UpdateViews.swift:398-420`) removes, in the same commit, every 0.6.0 title and detail key
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
  - the new kind strings: `…accessories`, and `…battery.custom` only on G7-2's fallback;
  - the URL scheme, only per G7-9;
  - W-13's three settings keys, `anonymousVersionCount`, `lastCountedVersion` and
    `versionFirstLaunch`, and the asset name `BatteryPulse-count.txt`.

  No other settings key is added, and none is changed.
- **Ceilings** (§9), each raise in a commit of its own that says why.
- **The notes draft** (§13) and the PR with the session checklist.
- **Build numbers, before the candidates** (§6.5): one commit makes `ci.yml` and `release.yml` set
  `BUILD_NUMBER` from one clock that only grows (for example whole minutes since 2026-01-01 UTC at
  build time; the run picks the form), instead of each workflow's own `run_number` (ci.yml:135,
  release.yml:109). A release is then above every earlier CI build, and the next cycle's CI builds
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
- Remove `docs/plans/0.7.0/` and its `bash -n` line.
- Release (§13), then the after-publishing check (§6.4).
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
| A0 | W-0, the intake (orchestrator). W-0S if the spikes never ran | | v0.6.2 published; its D3 |
| A1 | S-1 | R-1 | A0 (M-2, M-3 and M-5 are decided) |
| A2 | W-1 | W-2, which merges after W-1 (it reads W-1's `widget-manifest.json`) | A0 (G7-1); for W-2, W0-1's processor options |
| A3 | W-3a | W-12 | W-1 and W-2 merged |
| A3′ (W-11: Q-W4 offers the drawn battery; skipped if W-11 is cut, §7.2) | W-11 | W-4 | W-3a merged (W-11 then changes the widget target's dependencies on a settled base) |
| A4 | W-3b | W-4, if it didn't run in A3′ | W-3a (the widget files, the catalog); W-11 if it ran |
| **Look check** | the maintainer at his desk, about 15 minutes (§6.1) | | W-3b's PNGs |
| A5 | W-8 (G7-8) | W-3c | W-3b (the catalog, the widget files); W-4 (`BatteryPulseApp.swift`) |
| **Look check 2** | the maintainer, about 3 minutes (§6.1b) | | W-8's PNGs |
| A6 | K-1 (M-9: yes) | W-13 | K-1: the maintainer's backup key (§14 M-9). W-13: A5 (W-3c's `BatteryPulseApp.swift` and `AppSettings.swift`, W-8's catalog) |
| B (G7-5 only) | W-5, then W-6 | W-7, after W-5 | A5 |
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
- **W-3c beside W-8.** W-3c owns `BatteryPulseApp.swift`, `AppSettings.swift`, `MainView.swift` and
  `build-app.sh`; W-8 owns the widget target and the catalog.
- **W-13 in A6, beside K-1.** It edits `BatteryPulseApp.swift` and `AppSettings.swift` after W-4 and
  W-3c, and the catalog after W-8; K-1 touches neither. It merges before W-10, which composes What's
  New around its row, and C-1's E10 rebases over its `UpdateChecker.swift`.
- **The look check runs on W-3b's merged PNGs,** before W-8 and W-10. A look change then costs one
  fix run, not a re-freeze. The Accessories widget's pictures exist only after W-8, so they get
  their own short look (§6.1b) before C1.
- **Catalog order:** W-3a, W-3b, W-8, W-13, W-6 and W-7, then W-10. Each pair in a round has one
  slot that never touches the catalog (W-11, W-4, W-3c, W-12, K-1, S-1, R-1, C-1).

**Files no package shares** (the review checks): `Sources/BatteryPulseWidget/*` (W-3a, W-3b, W-8,
W-6, W-7 in sequence), `App/WidgetRefresher.swift` (W-4, then W-6 and W-7),
`scripts/build-app.sh` (W-2, then W-3a's one line, then W-3c), `App/BatteryPulseApp.swift` (W-4's
init line, W-3c, then W-13), `App/AppSettings.swift` (W-3c, then W-13), `Updates/UpdateViews.swift`
(W-13, then W-10), `Tests/BatteryCoreTests/SecurityGuardTests.swift` (W-3a, W-3c, W-13, then W-10)
and `.github/workflows/release.yml` (W-13, then D1's build-number commit). **Rebase-over only:**
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
- The questions are in plain words. Where the script needs a setting it can't read, it asks once.

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
   with time left as the default, **3** clock time only." (Q-W5, decided by delegation: 1; only
   if W0-6 passed)
7. "The words of the edit sheet (the list below, English and Russian): y = fine, or say which."
   (§8)
8. "The attention row (picture: 'Service Recommended' in the last row, and in small in place of
   the time line): **1** on, **2** never." (Q-W13, decided by delegation: 1; "off by default"
   would need a frozen parameter, so it isn't offered)
9. "'Hide fully charged' in the Accessories widget, off by default: y = keep it, n = leave it out
   of 0.7." (Q7-5, decided by delegation: y; the Accessories pictures come in §6.1b)

**Without an answer:** the decided answers of §14; for question 3 that means no extra large,
because only an explicit 1 or 2 declares a size. **Without PNGs** (W-3a's test target couldn't
link): the check moves into Session R as step 3b (+10 minutes).

### 6.1b The second look (about 3 minutes, after W-8 merges)

A second PR comment holds W-8's PNGs (small, medium and large; G7-8): "y = looks right, or say the
picture's number." Without an answer, y. Without PNGs, Session R step 3 covers it.

### 6.2 Session R (the release candidate, about 83 minutes hands-on)

One script: `bash docs/plans/0.7.0/m5-session.sh <step>` (W-12). Each step says its time.

1. **prepare** (3 min):
   - A fresh backup into `~/bp-070/R`: the app, the defaults domain, Application Support, the
     appearance and the wallpaper.
   - The script records the Icon & widget style, Dim widgets on desktop, the 24-hour setting, Open
     at login and BatteryPulse's Check for updates, asking for those it can't read.
   - It builds `bpulse` (`xcrun swift build -c release --product bpulse`).
   - "Is a small and a medium BatteryPulse widget on your desktop, from 0.6.2? If not, add them
     now." The script saves a screenshot and `pluginkit -mv -i io.github.nikitausov.BatteryPulse.Widget`.
2. **Placed widgets across the update** (8 min; G7-2):
   - The script installs RC-U over 0.6.2 the way `UpdateInstaller` does, and relaunches. It takes
     `pluginkit` and a screenshot after 1 minute and again after 5 minutes.
   - "Compare with the picture that just opened: **1** same, **2** blank or grey, **3** gone,
     **4** different (say what)."
   - **Record:** both screenshots, both `pluginkit` outputs, the answer.
   - This step has no control build, so it confirms G7-2's answer from W0-2 or W-0S and never
     decides it alone (§7.1 G7-2 says what a 2 or 3 leads to).
3. **The gallery, every size** (10 min):
   - "Control-click an empty spot of the desktop → Edit Widgets…, search for BatteryPulse, and add:
     Battery large (and extra large, if it is offered); Accessories small, medium and large (if
     offered)."
   - The script screenshots the desktop after each Return.
   - "Does every new widget look right? y = looks right; n = say the picture's number."
   - **3b**, only if the look check had no PNGs: the look check's questions, on these widgets.
4. **The edit sheet** (16 min):
   1. On the medium Battery widget: "Control-click it → Edit Widget. Set Layout to Custom, choose
      four details you like, set Time to time left (if offered), Colours to monochrome, and Update
      time to always. Click Done. Does the widget show what you chose? y/n."
   2. "Open Edit Widget again. Does it show the choices you made? y/n."
   3. Russian, by the method 0.6.2 confirmed (D-8): the script switches the extension's language
      and ends the extension.
      - "Open Edit Widget. Are all its words Russian? **1** all, **2** some English (say which),
        **3** the sheet didn't change language."
      - A **3** is recorded "not checked", never "n".
      - While the extension is in Russian, the script screenshots every placed widget (1 min).
        Then it switches the language back.
   4. **A parameter added later** (3 min; RD C14 item 5): the script installs RC-P over RC-U
      (RC-U plus one dummy parameter, D1). "Open Edit Widget on the medium widget. Are the choices
      you made in 4.1 still there? y/n." The script then installs RC-U2 for the rest of the
      session. The answer goes to Appendix C, as the evidence for 1.1's added parameters. (Q7-5
      was decided without it: FEA-21 is declared before D1 either way, W-8 item 2.)
   5. "Set the widget back to Automatic." The script screenshots each state.
5. **Rendering modes and places** (14 min; G7-4):
   - The script prints your Icon & widget style and your Dim widgets on desktop setting.
   - "Set System Settings → Desktop & Dock → Dim widgets on desktop to **Always**. Switch System
     Settings → Appearance → Icon & widget style through Default, Dark, Clear and Tinted, pressing
     Return each time." The script screenshots the desktop per style.
   - "Now set Dim widgets on desktop to **Automatically**, and go through the four styles again.
     Each time, click the desktop, then a window, and press Return." The script screenshots the
     desktop twice per style. (Apple's options are Automatically, Always for monochrome and Never
     for full colour, https://support.apple.com/guide/mac-help/mchlp1119/mac.)
   - Then the same with Notification Center open (click the date in the menu bar).
   - "Can you read every widget in every picture, and does a low or 'Service Recommended' state
     still show without colour? y = looks right; n = say the picture's number."
   - "Turn on System Settings → Accessibility → Display → Increase Contrast and press Return; turn
     it off. Then the same for Reduce Transparency." The script screenshots each (3 min). "Can you
     read every widget in these pictures? y = looks right."
   - "Set the style and Dim widgets on desktop back to <values printed at prepare>."
6. **Time and language** (8 min):
   - "Turn System Settings → General → Date & Time → 24-hour time off. Does the widget show
     '4:39 PM'-style times? y/n. Turn it back to how it was."
   - If time left shipped: "Watch a widget set to time left for a minute. Did the minutes go down
     by one? **1** yes, **2** no, **3** it shows seconds, **4** it starts with a minus sign." A 4
     means the `sign: .never` of §2.2 W0-6 is missing: a fix before release.
   - **The version count's setting** (3 min; W-13):
     - The script opens BatteryPulse's Settings → General and screenshots the "Include this Mac in
       the anonymous version count" toggle, on unless you turned it off.
     - "Set Check for updates to Never." The script screenshots the toggle greyed out.
     - The script relaunches BatteryPulse in Russian and takes both screenshots again. "Set Check
       for updates back to <value printed at prepare>." It relaunches BatteryPulse in your
       language.
     - "Are the toggle and its footer readable in both languages, and greyed out under Never?
       y = looks right."
7. **VoiceOver and Text size** (11 min; G7-12):
   - "Press Command-F5 (or hold Command and quickly press Touch ID three times). Click an empty
     spot of the desktop, then press Control-Option-Right Arrow until VoiceOver reads each
     BatteryPulse widget: small, medium, large and Accessories. Write down what it says for the
     small one. Does each widget read as one sentence with the charge, the state and the time?
     y/n." (https://support.apple.com/guide/voiceover/turn-voiceover-on-or-off-vo2682/mac)
   - **In Russian** (2 min): if step 4.3's switch worked, the script switches the extension's
     language again, and you repeat the question for each widget. Otherwise it is recorded "not
     checked". Then the script switches it back. "Press Command-F5 again."
   - "Raise System Settings → Accessibility → Display → Text size. Do the widgets' words grow or
     stay readable? **1** grow, **2** unchanged, **3** cut off (say which). Set it back."
8. **Clicks** (6 min; W-3c, G7-9):
   - "Quit BatteryPulse (its menu bar panel → Quit BatteryPulse), then click the Battery widget.
     Which page opened? **1** Overview, **2** another page (which), **3** nothing opened."
   - "With BatteryPulse running and no BatteryPulse window open, click the Battery widget. Which
     page opened? **1** Overview, **2** another page (which), **3** nothing opened."
   - The same for the Accessories widget (expect Accessories).
   - The same for a Battery widget whose main value is maximum capacity (expect Health).
   - The same once with the main window open, and once with BatteryPulse's own Settings (the gear
     in its menu bar panel, not System Settings) → General → Window to open set to compact
     (expect the main window at the page). Set it back.
   - The script logs the route each click delivered (a URL or an activity; never a full URL in a
     public log).
9. **Plug, unplug and accessories** (6 min):
   - "Unplug the adapter. Did the Battery widget say 'On battery' within a minute? y/n. Plug it in
     again: 'Charging' within a minute? y/n."
   - If accessories are at hand: "Turn the keyboard off (or put the earbuds in their case). Did the
     Accessories widget change within a minute? y/n."
   - **Record:** the `widget.reload` and `widget.timeline` lines with their times, and the per-kind
     counts the app logged from `currentConfigurations()` during steps 2-9 (W-4 item 3). Appendix C
     records whether they match the widgets placed in steps 1 and 3; until they do, an empty answer
     keeps counting as "placed".
10. **F12** runs at the end of the logged day (§6.3), so the logged day starts on a candidate
    installed once and the extension isn't flipped through four versions first.
11. **Optional, any time:**
    - **The Charge Limit capture** (QUA-05, if 0.6.2 missed it):
      `bash docs/plans/0.7.0/m5-session.sh charge-limit` (W-12). The script asks for the limit set
      in System Settings → Battery [exact menu path unverified on macOS 27] and checks that the
      charge is at least 5 points below it. It then starts `caffeinate -i bpulse --record` into a
      new, empty folder under `~/bp-070/` and beeps when charging stops at the limit. Keep the
      adapter in and the lid open. About 2 minutes to set up, then unattended.
    - **The optimized charging hold** (QUA-06): `… m5-session.sh hold-watch` before bed, with the
      adapter in and the lid open. It records overnight under `caffeinate -i` and says in the
      morning whether a hold was seen [uncertain: whether macOS holds the charge while the Mac is
      kept awake].
    - **W-11's pixel check:** `scripts/menu-bar-shots.sh` before and after.
    - **Any of 0.6.2's open checks** that C-1 couldn't carry (D-14): WP-17's page switches, SEC-15's
      timing.
    - **Any WP-18 item 0.6.2 left** (C-1): in Xcode, from Claude's step-by-step list (Xcode is
      installed on the M5, Q-B7). Not timed here: it runs whenever Xcode is open.
12. **Start the logged day** (1 min; G7-11):
    - The script starts the `perf` log stream in the background, as 0.6.1's session did.
    - If the stream may not survive sleep, it also enables
      `sudo log config --subsystem io.github.nikitausov.BatteryPulse --mode "level:debug,persist:debug"`
      for one day and resets it at `day-end` [unverified on macOS 27]. The script asks for your Mac
      password once; nothing shows while you type.
    - "Use your Mac as usual until tomorrow, with the widgets on the desktop."

### 6.3 The logged day, and its end (passive, then about 10 minutes)

- **During the day:** nothing to do.
- **`day-end`:** the script stops the stream and runs `perf-stats` (W-12). It records:
  - per kind, the reload requests, the timelines delivered, the share delivered and the median
    delay (G7-11);
  - the widget's reads, and its total read time per day (§10);
  - crash reports for BatteryPulse and BatteryPulseWidget since prepare, which must be 0 (G7-16);
  - `fault` messages in the subsystem, which must be 0 (G7-16);
  - W-13's `update` lines (optional evidence): if the candidate ran for 24 hours and an automatic
    check was due, one `noCounter` for 0.6.99, which has no release.
- **F12** (5 min; D-12, G7-15), after the measurements and before `restore`: RC-F (built as 0.5.99)
  → Check for Updates → Install and Relaunch. "Did BatteryPulse come back as 0.6.2? y/n."
- Then `send` (the results to the PR) and `restore`:
  - it reinstalls the backed-up 0.6.2, so the after-publishing check runs the real update path;
  - it resets the log configuration;
  - it prompts for what only a hand can reset: the Icon & widget style, Dim widgets on desktop,
    Text size, Increase Contrast, Reduce Transparency, VoiceOver, Open at login, and "remove the
    test widgets you don't want to keep".

### 6.4 After publishing (about 13 minutes, plus a passive 10-minute wait; D3)

From the restored 0.6.2, with the session's small and medium widgets still placed:
1. **The before-picture:** the script takes it, with `pluginkit`, right before Install and Relaunch
   (after `restore`, which goes from RC-U, configurable, back to 0.6.2, static). If a widget is
   blank or gone at that point, add it again from 0.6.2's gallery first, so the picture shows
   working widgets.
2. Check for Updates → Install and Relaunch to 0.7.0. "About shows 0.7.0? y/n." "What's New
   appeared once? y/n." "Does it list 'Anonymous version count'? y/n." (W-13)
3. "Compare your widgets with the picture taken before: **1** same, **2** blank or grey,
   **3** gone, **4** different." The script runs `pluginkit` again.
4. P2 D3's list:
   - History shows the past days;
   - the settings and the menu bar look are unchanged;
   - `codesign -dv --verbose=4` shows `flags=0x10002(adhoc,runtime)`;
   - `xattr -l` shows no quarantine;
   - the login item is still listed if it was on;
   - notification permission is kept.
5. **On a 2 or 4 in step 3, or any other failure:** `gh release edit v0.7.0 --prerelease`, and fix
   forward. **On a 3:** if Session R step 2 also showed "gone", the notes already say "add it
   again"; otherwise the notes are edited to say so, and ROADMAP Stage 1.2 records it. Either way
   it is a documented known limitation, not a reason to wait: with ad-hoc signing through 1.0
   (M-1 is no), no signed build is coming to fix it (RD C3, C7).
6. **The version count** (about 3 minutes, then a passive 10-minute wait; W-13), with Check for
   updates set to anything but Never:
   - "Quit BatteryPulse." `… m5-session.sh count-check` (W-12) runs `defaults delete
     io.github.nikitausov.BatteryPulse lastCountedVersion; defaults delete … lastUpdateCheck;
     defaults write … versionFirstLaunch -date "2026-01-01 00:00:00 +0000"` and opens BatteryPulse
     again. That skips the grace day and makes a check due.
   - The first automatic check runs 20 seconds after launch, and an `update` log line says
     `counted`.
   - About 10 minutes later, `swift scripts/release-stats.swift` shows v0.7.0's
     `BatteryPulse-count.txt` at 1 or more (counts arrive in batches, VC-3).
   - **On `failed`, `noCounter` or no line:** the script prints the logged code. `noCounter` means
     the asset is missing: run the `gh release upload` that `release.yml`'s check names, then
     `count-check` again (the 404 marked this version as counted). Otherwise
     fix forward in a 0.7.x; nothing a user sees depends on the count, so it is no reason for
     `--prerelease`.
7. **In everyday use on the first day:** the widget's charge and "Lasts until" against the popover,
   within 2 points and about 15 minutes (P2 D3, `994c09d`).

### 6.5 Risks the sittings watch

- **Build numbers:**
  - Today CI sets `CFBundleVersion` from ci.yml's run number (ci.yml:135; 258 on 2026-10-22), and
    a release from release.yml's own (`release.yml:109`; 7 for 0.6.1). WidgetKit caches by
    `CFBundleVersion` (`build-app.sh:112-113`), so the published 0.7.0 would almost certainly
    carry a lower number than RC-U, and a stale widget from that cause would be misread as a
    configuration loss in §6.4.
  - **So D1 fixes it** before the candidates: both workflows take the build number from one clock
    that only grows (D1-D3). It is a technical change, and ROADMAP's decisions record it.
- **Text size and desktop widgets:** whether Text size reaches desktop widgets is [unverified]
  (P2 W0-5). A "2 unchanged" in step 7 is not a failure.
- **Ad-hoc signing stays through 1.0** (M-1 is no):
  - A DMG install meets Open Anyway, and a DMG replacement may cost permissions and placed
    widgets (UG:425-426, UG:493-495). These are documented known limitations at 1.0 (RD C3, C7,
    C16), so a loss seen in Session R step 2 or §6.4 is recorded and documented (§12), never
    deferred to a signed build.
  - In-app updates keep the same path as 0.6.x (`UpdateInstaller`), which is what §6.4 tests.

---

## 7. Gates and their defaults; cut line; frozen surfaces

### 7.1 Gates

| Gate | Decides | Measured by | If no measurement comes |
|---|---|---|---|
| **G7-1** configuration | App Intents configuration, or preset kinds | 0.6.2's W0-1 (CI and Session A); W-2's CI check | W0-1 not run: W-0S. W0-1 failed: presets (FEA-13), W-2 dropped |
| **G7-2** placed widgets | today's kind becomes configurable, or the configurable widget gets a new kind | 0.6.2's W0-2 (SPIKE-C, SPIKE-W) or W-0S; Session R step 2 confirms | No W0-2 answer: W-0S (§2.3). If Session R step 2 answers 2 or 3 although W0-2 passed: compare with D-9 (the plain 0.6.1 → 0.6.2 in-app update). If D-9 kept the widgets, merge the fallback branch, dispatch new RC-U and RC-F builds, and repeat Session R steps 1-4 (without 4.4) before D3 (+2 runs, about 35 minutes). If D-9 lost them too, the loss is the update's: ship as designed, and the notes say "add it again"; it stays a documented known limitation at 1.0 (RD C3, C7). **No Session R: no release** (§3) |
| **G7-3** time left | the Time parameter | W0-6; Session R step 6 | Not shipped: clock time only, and the parameter isn't declared |
| **G7-4** rendering modes | which modes are designed and checked where | W0-4 (2); Session R step 5 | All three modes designed; every place checked in Session R |
| **G7-5** stretch | W-5 to W-7 in 0.7 | W0-3 (A or A′); the budget after A5. Q-W3 (yes) and M-1 (no) were decided on 2026-10-22 | W0-3 passed, no budget left: 1.1 on the feed (RD §3.2). W0-3 not run: 1.1, where it runs first. W0-3 failed: not possible without the paid account (RD §4.2) |
| **G7-8** Accessories widget | W-8 | W0-4 (1); Session R steps 3 and 9 | Not in 0.7 |
| **G7-9** URL scheme | register a navigation-only scheme | W0-4 (4), (5); Session R step 8 | No scheme. W-3c handles both the URL and the activity; if step 8 shows URL clicks don't arrive, the scheme is added before release (§7.3) |
| **G7-10** size | ceilings and cuts | the CI size report (§9) | Within 0.6.1's ceilings: a raise in a commit of its own. Above: §9's cut order |
| **G7-11** reload delivery | whether the planner keeps percent-step reloads | the logged day: at least 90 % of the requests delivered per kind (P2 §8.10). Delivered = a `widget.timeline` of that kind before the next request; the median delay is reported (W-12 item 2) | Keep the Linux-tested planner; the measurement joins 0.8's sitting. A share under 90 % drops percent-step reloads only when deliveries are missing entirely, not merely delayed: WidgetKit may postpone a widget nobody can see until it becomes visible (https://developer.apple.com/documentation/widgetkit/keeping-a-widget-up-to-date) |
| **G7-12** accessibility | VoiceOver labels | Session R step 7 | P2 §8.15 as designed; the row stays open in `docs/VERIFICATION.md` |
| **G7-13** Russian edit sheet | — | Session R step 4.3 | "Not checked"; `WidgetTextBudget` covers lengths |
| **G7-14** `bpulse` JSON | S-1 ships | D1's golden diff | Required (Linux); no M5 needed |
| **G7-15** update path | the release | F12 (at the logged day's end, §6.3); §6.4 | F12 fails: as 0.6.2's G-16 (the installer's last good code). §6.4 step 3 shows 2 or 4: `--prerelease`, fix forward |
| **G7-16** crashes and faults | whether the RC can ship | Session R and the logged day's `day-end` count (§6.3) | Any BatteryPulse or BatteryPulseWidget crash report, or any `fault` in the subsystem: no D3. Fix forward, build a new RC and repeat the Session R steps the fix touches |
| **G7-17** placed kinds | whether W-4 filters reloads by `currentConfigurations()` | Session R step 9's per-kind counts (W-4 item 3) | Not shown to match: an empty answer keeps counting as "placed" for Battery |

### 7.2 Cut line

**Never cut:** W-0, S-1, W-1, W-2 (or FEA-13 under G7-1), W-3a, W-3b with large, W-3c, W-4, W-10,
W-12, W-13, and D1-D3. W-13 is the maintainer's decision, so the budget never cuts it; it moves
whole to 0.8 only if review finds a promise of §11 it can't keep.

**Conditional:** W-8 (G7-8), K-1 (M-9 is yes; it needs the maintainer's key by C1), and extra
large (Q-W10; declared only on an explicit 1 or 2 in look-check question 3). W-11 and FEA-21 are in
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
| W-2 | 2 | | W-12 | 1-2 |
| W-3a | 3 | | K-1 | 1 |
| W-3b | 3 | | W-10 | 2 |
| W-4 | 2 | | D1+D3 | 2-3 |
| W-13 | 2 | | | |

- **Totals:** about 28-31 runs, plus 3 to fix forward. The never-cut set is about 23-26.
- **RD §3, §3.2 and §3.3 carry this count,** W-13's 2 runs included (written 2026-10-22). RD's
  first estimate, 18-24 for the MVP, left out D1-D3, the riders (S-1, R-1, K-1), W-11 and the
  extra review run that splitting W-3 costs.
- **Extra work:** W-0S adds 2 runs if needed; C-1 0-2; the stretch 8-9; G7-2's fallback after
  Session R 2 (a new RC); rebuilding the session script if D-11's copy is missing 1.

### 7.3 Frozen surfaces 0.7 changes on purpose, and how the notes say so

PB §3.4's list and P2 §7.3's additions hold, except these intended changes:

| Surface | 0.6.x | 0.7 | Release notes line (§13) |
|---|---|---|---|
| **The Battery widget's kind** `io.github.nikitausov.BatteryPulse.battery` | `StaticConfiguration`, small and medium, one look (`BatteryPulseWidget.swift:17-27`) | The same kind string, now an `AppIntentConfiguration` with families small, medium, large and (per Q-W10) extra large. Automatic keeps small and medium as they were, except: "tomorrow" on a later-day end; the attention row for an abnormal condition or high heat (in small, in place of the time line); and "Updated %@" when the reading is over 45 minutes old | "Your widget keeps its look. Control-click it and choose Edit Widget to pick what it shows" |
| **…on G7-2's fallback** | — | Today's kind stays static, gaining large and extra large; the configurable widget is `…battery.custom` | "To choose what the widget shows, add the new Battery (Custom) widget from the gallery" (wording in the look check) |
| **A new kind**, `io.github.nikitausov.BatteryPulse.accessories` (G7-8) | — | Small, medium, large | "An Accessories widget shows your keyboard's, mouse's and headphones' batteries" |
| **The reload policy** | `WidgetReloadPolicy` (`BatteryPresentation.swift:126-180`) | `WidgetReloadPlanner`: also on Low Power Mode, adapter, condition and thermal changes; only for placed kinds | No line (behaviour inside the budget) |
| **`bpulse --device <n> --json`**, and `--input` of a device capture with `--json` | `firstUseDate` in seconds since 2001 (`main.swift:189-190`) | ISO 8601 strings, like `--json` | "For scripts: `bpulse --device <n> --json` writes dates as ISO 8601 strings, like `bpulse --json`; every JSON object `bpulse` prints now has a `formatVersion` field. `--accessories --json` is unchanged" |
| **`bpulse --json`, `--watch --json`** | No version field | `formatVersion: 1` | (the same line) |
| **Settings keys** (RD C14 item 1) | PB §3.4's list, plus `betaWindowStyles`, plus `openAtLogin` only if 0.6.2 added it (not expected: 0.6.2's A0 saw the login item kept, so WP-16 item 5 has no cause) | **Three added (W-13):** `anonymousVersionCount` (Bool; a missing key means on, and only the toggle writes it), `lastCountedVersion` (String `x.y.z`) and `versionFirstLaunch` (Date). None is changed. Widget configuration lives in macOS's widget configuration, not in our domain | W-13's "Anonymous version count" line (§13 step 2) |
| **Release assets** (RD C14 item 6, the update contract) | `BatteryPulse.dmg`, `BatteryPulse.dmg.sig` and `BatteryPulse-dSYMs.zip` (`release.yml:151`) | Plus `BatteryPulse-count.txt` on every release from v0.7.0, never removed from a published release (W-13) | (the same line) |
| **Update traffic** (`UpdateNetwork`) | Ephemeral sessions without a URL cache; cookies kept in memory while the app runs (VC-5) | No cookies stored or sent (W-13 decision 6) | — |
| **Internet requests** (RD C14 item 8; UG:502-509; RM:120-125) | The update check, and a download the user chose | Plus the version count: once per version, at least 24 h after it first ran, on an automatic check that reached GitHub; never under Never or with the toggle off (W-13) | (the same line) |
| **`@SceneStorage("mainSelection")`** | `SidebarItem.storageKey` strings | The same strings, now `PageID`'s raw values, pinned by a test | — |
| **The app's Info.plist** | No URL types (`build-app.sh:87-108`) | `CFBundleURLTypes` only per G7-9 | No line: a click is the user-visible part |
| **The appex** | Binary, strings, Info.plist | Plus `Contents/Resources/Metadata.appintents` | — |
| **The widget's entitlements** | Sandbox only (`Resources/BatteryPulseWidget.entitlements`) | Unchanged in the MVP. The stretch adds one read-only exception | (stretch) a privacy line (§11) |
| **Storage** | PB §3.4 | Unchanged in the MVP. The stretch adds `Widget/feed.json` | (stretch) the guide's privacy section |
| **`WhatsNew.version`** | 0.6.0 (`UpdateViews.swift:388`) | 0.7.0 (Q7-2) | — |
| **`CFBundleVersion`** (the build number) | each workflow's own `run_number` (ci.yml:135, release.yml:109) | one clock that only grows, in both workflows (D1, §6.5) | No line; About shows the new number (`AboutView.swift:54`) |
| **Signposts** | `widget.reload` (`policy`, `update`) | Plus `widget.timeline` (triggers `battery`, `accessories`) and `widget.reload` `policy.accessories` | — (CL's list) |

**New frozen surfaces 0.7 creates** (P2 §8.13; promised for 1.x in RD C14 item 5):
- the kind strings;
- the intent type names, the parameter names and every `AppEnum` raw value;
- `supportedFamilies` per kind, which are only ever added to;
- Automatic's meaning in each family;
- the `PageID` and `WidgetRoute` strings, and the scheme if there is one;
- W-13's three settings keys, with their meaning (RD C14 item 1);
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
- **Size:** the widget bundle gets the whole compiled catalog (`build-app.sh:118`), so each key
  costs twice in `strings_bytes` (§9).

**New keys (English), by package.** The final wording is settled in the look check (§6.1 question 7)
and W-10's terminology pass. Keys marked (if …) exist only when their option ships.

| Package | New keys |
|---|---|
| W-3a, gallery and intent | "Charge, time remaining and the details you choose." (the gallery description; it replaces "Charge, time remaining and battery health.", which is then removed as unused) · "Choose Battery Details" (the intent's title) · "Choose what the Battery widget shows." (its description) |
| W-3a, parameters | "Layout" · "Main value" · "Main visual" · "Status lines" · "Colors" · "Update time" |
| W-3a, cases | "Automatic" · "Custom" · "Number and symbol" · "Drawn battery" (if W-11) · "Time to full or empty" · "Clock time" · "Time left" (if G7-3) · "Level colors" · "Monochrome" · "When old" · "Always" |
| W-3a, summaries | one `Summary` key per `ParameterSummary` branch (P2 §8.5: Automatic; Custom; Custom in small), worded with W0-1 (d)'s placeholder form [count uncertain: 2-4] |
| W-3a, text | "Lasts until about %@ tomorrow" · "Full at %@ tomorrow" (P2 §8.6) · widget-only short forms of reused keys that are over `WidgetTextBudget` (W-1 item 5), each with its Russian, named in the commit [count unknown until W-1's test runs] |
| W-3b | "Cycle life used" · "Cell balance" (P2 §8.5's catalogue) · panel headings only if the extra-large layout needs words beyond "Battery" and "Power" |
| W-8 | "Batteries of your keyboard, mouse, trackpad and headphones." (gallery) · "Choose Accessories" (intent title) · "Choose which accessory batteries the widget shows." · "Lowest only" · "No accessories with batteries connected" · "Try the Accessories widget" (the Battery widget's no-battery state, if W-8) · "Hide fully charged" (FEA-21, Q7-5; unless cut) |
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
- "Battery charge: %@, %@" (a candidate for the charge block's VoiceOver label);
- the six unit symbols ("W", "mAh", "V", "mV", "mA", "A").

**Count [estimate]:** about 25-35 new keys in the MVP, plus W-13's 4, and about 15-25 more with
the stretch. That is fewer than P2 §8.12's 80-120, because the field labels already exist in the
app.

**Checks:**
- `LocalizationCatalogTests`, extended to the App Intents forms (W-1 item 11), fails on a missing or
  unused key.
- `WidgetTextBudget` (W-1) fails a Russian text that is too long for its slot.
- `scripts/string-tables.swift` checks every table in both bundles (`build-app.sh:123`).
- Session R step 4.3 checks the Russian edit sheet, by D-8's method.

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
  `build-app.sh:119-122`). With roughly 100-150 B per key per table [estimate], that is about
  5-11 KB, less the 0.6.0 What's New keys W-10 removes.
- **W-13:** about 2 KB per string table, so about 4 KB of `strings_bytes` across both bundles
  [estimate: its four keys' English and Russian texts are 2,092 B in UTF-8, the footer the
  longest]. The widget's code is unchanged; it only carries the larger table, as every bundle
  does.

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
    a cheap defence in case macOS ever redacts widgets. W0-4 (3) records whether it does.
- **No hardware-derived identifiers:**
  - `AccessoryBattery.id` never enters the widget (`Accessory.swift:120-130`).
  - In the stretch, a device is identified by its `DeviceKey` string, an HMAC-derived key (CL:
    `DeviceKeys` HMAC), never a UDID or a serial (P2 §8.3, §8.5).
- **Logs:**
  - Triggers are `StaticString` case names; the kind string and any name never go in a log.
  - A click's route logs its case name as `.public` (`overview` … `accessories`, or `device`), and a
    device page's `DeviceKey` only as `.private(mask: .hash)`; never a full URL (CL logging: "a
    device key logs as `.private(mask: .hash)`"; P2 WP-W0 "Logs"). `device:<key>` is a page ID
    (`MainView.swift:74`), so the page ID itself is never logged `.public`.
  - The per-kind counts from `currentConfigurations()` are numbers, logged `.public` (W-4 item 3).
- **The URL scheme,** if registered (G7-9): navigation only. `WidgetRoute(url:)` accepts known pages
  and valid `DeviceKey`s only, and a link never acts (P2 §8.9). Any app or web page could open a
  page of BatteryPulse with it, and nothing more.
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
| `docs/USER_GUIDE.md`, command line (UG:561-663) | `--device --json` dates and `formatVersion` (UG:620, UG:648) | S-1 |
| `docs/USER_GUIDE.md`, privacy (UG:502-509, UG:351-359) | **W-13:** UG:502-509 reworded (the check, the count and a download you chose); a new "Privacy" section with §11's statement; the devices' "Privacy" (UG:351-359) links to it. **With the stretch:** the feed | W-13, W-10 |
| `README.md` | The Widget bullets (RM:84-86, "new in 0.3") list the configurable sizes and Accessories. The iOS promises go (R-1, DOC-09). "Status: early development" stays until 0.9.0 (RD §3.5, DIS-10). **W-13:** RM:120-125 ("The only requests to the internet are…") reworded, and a new "Privacy" section with §11's statement | W-10, R-1, W-13 |
| What's New | `WhatsNew.version` 0.6.0 → 0.7.0 (`UpdateViews.swift:388`), and `WhatsNew.features` replaced with 0.7's 2-3 plus W-13's "Anonymous version count" (Q7-2), which later releases append for anyone coming from before 0.7 (W-13 item 6). Users coming from 0.6.x see it once (`UpdatePolicy.showsWhatsNew`, `Updates.swift:232`) | W-10, W-13 |
| `CLAUDE.md` | **Layout:** `Sources/BatteryCore/Widget/` (the model, planner, routes and manifest); `BatteryArt` if W-11; the widget's intents and their rule. **The build:** the metadata step and `appintents-check.swift`. **Guards:** the new widget rules (time text, placements, routes). **Signposts:** `widget.timeline` and its triggers; `widget.reload`'s `policy.accessories`. **The placeholder exception,** if any. **The URL scheme,** if any. **Energy:** "widget reloads only in `WidgetRefresher`, through `WidgetReloadPolicy`" becomes "… through `WidgetReloadPlanner` (per kind, placed kinds only)". **Logging:** "an app and a BatteryKit twin" (or BatterySource after 0.6.2's WP-22) gains the widget's twin (W-3a item 8). **Layout, BatteryPulseWidget:** "signed with only the app-sandbox entitlement" gains the stretch's read-only exception, only if W-5 ships. **Releases:** the build number from one clock (D1). **W-13:** "Network" gains the version count and "no cookies"; Layout lists `VersionCounter`; Releases names `BatteryPulse-count.txt` | W-10, W-13 |
| `docs/ROADMAP.md` | The 0.7 entry (R:543-556, which promises "every size macOS offers" and History, iPhone and iPad widgets) rewritten to what shipped, then ticked; the History and iPhone & iPad widgets, the portrait size and any family not shipped move to a new 1.1 entry (RD §3.8) that links `docs/plans/1.1/widgets.md` (D3); the Decisions edits of R-1 item 1; the build-number decision (D1); the frozen-outputs decision line (R:437-439) gains "device JSON dates and `formatVersion` shipped in 0.7"; Stage 1.2's widget line (R:202-208) updated from §6.4; Stage 4's WidgetKit line; the "Road to 1.0" section (R-1); "Next: 0.8" (RD §3.3); a "Widgets (0.7)" decisions paragraph (the kinds, Automatic frozen, the planner, the stretch's condition: the feed only, as M-1 is no); the Releases row, whose download counts follow a week later (§13 step 8, NEW-23). **W-13:** already written on 2026-10-22: the Decisions' "Privacy (0.7)", the Principles' Privacy line and the usage paragraph, which W-13's docs pass checks against what shipped; it adds only the Releases table's Count column from 0.7.0 and the "Road to 1.0" lines for C14 items 1, 6 and 8 | W-10, R-1, W-13, D3 |
| `docs/plans/1.0/ROADMAP.md` | Already written on 2026-10-22: C14 items 1, 6 and 8, §1.1, §1.2 item 6, §3, §3.2 and §3.3, §4.3's Telemetry row, NEW-23, NEW-24 and M-11. W-13's docs pass checks them against what shipped | W-13 |
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
     Widget to choose" (or G7-2's fallback line);
   - the Accessories widget (G7-8);
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
   `docs/plans/1.1/widgets.md` holds what 0.7 didn't build (D3). Its `bash -n` line goes with it
   (P2 D3).
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
7. **After publishing** (§6.4, with W-13's count in step 6), with `gh release edit v0.7.0
   --prerelease` as the rollback.
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
his M-1 answer. He delegated every other question here ("do it by best practices, as you see fit"),
so each is decided as its recommended answer, marked "decided by delegation". The looks these
decisions lead to are still signed off in the look check (§6.1), where another
answer changes them. Technical choices are not asked, as agreed in P1 §8 ("Architecture:
delegated"). They include App Intents, the planner, routing, the URL scheme, tests and guards, the
build step and the size sequencing.

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
      readings (the feed, W-5; Q-W3 is yes): in 0.7's stretch if W0-3 passed and the budget
      allows, otherwise 1.1 on the feed. If W0-3 fails, they are not possible without the account
      (RD §4.2).
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
  charge limiting)" from ROADMAP's Decisions.
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

**Charge limiting and an iOS app:** nothing in 0.7 argues for revisiting M-2 or M-3.
- The widget is read-only. There is no Control Center control (REJ-56), and the Mac has no
  accessory widget families (REJ-54).
- An iOS widget (FEA-33) needs the iOS app first.

### The widgets' look and behaviour (P2 §10's Q-W, with 0.7's answers)

- **Q-W1 (when). Decided by the maintainer (2026-10-22): 0.7,** as this plan does. There is no
  0.6.3 with static sizes (FEA-14 not planned; RD §5.3).
- **Q-W2 (which widgets). Decided by delegation:**
  - Battery and Accessories in 0.7.
  - History and iPhone & iPad on the feed, if W0-3 passed (Q-W3), with the 90-day capacity and
    cycles trend offered then. There is no App Group route, because M-1 is no.
  - No preset widgets, unless configuration turns out impossible (G7-1).
- **Q-W3 (BatteryPulse keeps a small copy of recent readings for the widgets). Decided 2026-10-22,
  following the maintainer's M-1 answer (no paid account): yes,** if W0-3 passes. If it fails, the
  History and iPhone & iPad widgets aren't possible without the account (RD §4.2).
- **Q-W4 (look). Decided by delegation:**
  - **Main visual:** offer the number with the level symbol (the default, as today), a number with a
    ring, and a drawn battery like the menu bar's Modern style.
  - **Main value:** charge (the default), maximum capacity, temperature, and battery power with its
    update time.
  - **Colours:** level colours by default.
  - **Large and extra-large details:** as §6.1 question 2 shows. The look check signs them off.
- **Q-W5 (time). Decided by delegation:** clock time by default ("Lasts until about 16:39"), with
  time left ("2 hours, 13 minutes") offered if W0-6 passed. An end two or more days ahead (macOS
  estimates run up to 65,534 minutes) shows no time, rather than a weekday ("Lasts until about
  Friday").
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

### New for 0.7 (2026-10-22: Q7-1 to Q7-7 decided by delegation, as recommended; Q7-8 settled; Q7-9 decided by the maintainer)

- **Q7-1 (gallery names and descriptions): as written.** "Battery: Charge, time remaining and the
  details you choose." and "Accessories: Batteries of your keyboard, mouse, trackpad and
  headphones." The look check shows them with their Russian (question 7).
- **Q7-2 (What's New): yes.** The What's New window shows once after updating to 0.7, with 2-3
  entries plus the version count (configurable widgets; the Accessories widget; clicks open the
  page; and W-13's "Anonymous version count", Q7-9). 0.7 is a feature
  release, as 0.6.0 was; fix releases left it at 0.6.0 (P1 §7 item 1).
- **Q7-3 (your time): as planned.**
  - The plan asks for:
    - the look check at your desk, about 15 minutes, and a second look of about 3 minutes;
    - Session R, about 83 minutes (3 of them for W-13's setting);
    - a logged day of normal use, and about 10 minutes at its end (F12);
    - the after-publishing check, about 13 minutes, plus a passive 10-minute wait for W-13's
      count;
    - the backup key, about 5 minutes (M-9).
  - Session R spends most of its time on the small and medium widgets placed from 0.6.2, and shows
    every new size once.
  - With about no outside users (M-1's evidence), these sittings are where 0.7 is seen working at
    all (RD C2), so they aren't shortened.
- **Q7-4 (if placed widgets don't survive the update): the evidence decides.**
  - Session R step 2 may show your widgets gone or blank after the update.
  - If only the configurable change loses them (W0-2's control kept them): keep your widget as it
    is, and offer the configurable one as a separate gallery entry.
  - If every update loses them: ship as designed, the notes say "add it again", and it is a
    documented known limitation at 1.0 (RD C3, C7).
- **Q7-5 ("Hide fully charged" in the Accessories widget): yes, off by default** (FEA-21, W-8 item
  2). It is declared before D1, because adding it later may reset placed widgets' settings
  [unverified; Session R step 4.4 measures it].
- **Q7-6 (where a click opens): yes.** A click opens the main window at the widget's page, even if
  you prefer the compact window, because the compact window has no pages.
- **Q7-7 (small, Custom): yes.** In the small widget, the one detail you choose takes the place of
  the time line (P2 §8.5), because a small widget has room for one more line only. The alternative
  kept the time line and offered no detail in small.
- **Q7-8 (settled, an engineering call).** 0.6.2's D3 copies its session script, swap helper and
  Appendix C into `docs/plans/0.7.0/` (D-1); the release PR's `refs/pull/<n>/head` keeps them
  reachable either way, so no branch has to be kept for 0.7.
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

---

## Appendix A: traceability of every 0.7 item

**Sources:**
- R at `eebf748`;
- P2 (`docs/plans/0.6.2/PLAN.md`), RD (`docs/plans/1.0/ROADMAP.md`), INV
  (`docs/plans/1.0/INVENTORY.md`);
- P1 and PB at `6aec4d2:docs/plans/0.6.1/` (in PR 11's history).

| Item | Source | 0.7 package or status |
|---|---|---|
| Widget customization (the maintainer's request, 2026-10-22) | R:543-553; P2 §8, §9; RD §3.2 | W-1 to W-4, W-8, W-10 to W-12 |
| FEA-06 configurable Battery widget | P2 §8.5, §8.17, W-3; INV FEA-06 | W-3a, W-3b, W-3c (MVP) |
| FEA-07 widget model in BatteryCore and the pin test | P2 §8.6, §8.13, W-1 | W-1 |
| FEA-08 App Intents metadata step | P2 W-2; W0-1 | W-2 (or dropped under G7-1) |
| FEA-09 Accessories widget | P2 §8.4, §8.5, W-8; W0-4 (1) | W-8 (G7-8) |
| FEA-10, FEA-11, FEA-12 feed, History, iPhone & iPad | P2 W-5 to W-7; RD §3.2 | Stretch (G7-5: W0-3 passed; Q-W3 yes, M-1 no), else 1.1 on the feed; not possible without the paid account if W0-3 failed (RD §4.2) |
| FEA-13 preset kinds | P2 §8.16 row 1 | Only under G7-1's fallback |
| FEA-14 a 0.6.3 with static large sizes | P2 §9; Q-W1 | Not planned (RD §4.2) |
| FEA-15 to FEA-20 (Refresh, portrait, dashboard, per-row links, specific accessories, "why not charging" field) | P2 §9.1 "Later"; RD §4.1 | After 1.0 |
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
| PLT-05 iOS code kept building | ci.yml:130-131; RD M-2 | R-1 (a ROADMAP line) |
| TCI-10 widget render previews | P2 W-3 | W-3a, W-3b |
| TCI-11 widget guard rules | P2 §8.7, §8.8, §8.11 | W-3a, W-3c, W-8, W-10 |
| A11Y-06 widget accessibility | P2 §8.15 | W-3b; Session R step 7 |
| L10N-04 widget localization | P2 §8.11, W-10 | W-1 item 11 (the catalog test's App Intents forms), W-3a, W-3b, W-8, W-10 |
| L10N-05 unit symbols in the widget | P2 §8.6 "Formatter" | W-3a |
| NEW-13 backup key (public half) | RD M-9 (yes, by delegation) | K-1 |
| NEW-18 verification matrix (start) | RD C2, §5.2 | R-1, D3 |
| NEW-22 quick check after macOS 27.x updates | RD §5.2 | W-12 (`scripts/quick-check.sh`) |
| NEW-23 download counts a week after publishing | RD §1.2 item 6, §5.2; the maintainer's question about downloads (2026-10-22); 0.6.2's `scripts/release-stats.swift` | §13 step 8; D-16; §11 |
| Anonymous version count | §14 Q7-9; RD NEW-24, NEW-23, C14 items 1, 6, 8; INV DIS-11 | W-13 |
| M-5's "Road to 1.0" in ROADMAP | RD §3.2 "Before code"; RD M-5 | R-1 (M-5 approved as written: the five promises, no dates) |
| QUA-05 Charge Limit capture | R:145-146; RD §3.2 | Session R optional, if 0.6.2 missed it (W-12's `charge-limit` step) |
| QUA-06 optimized charging hold | R:76-77; INV QUA-06 | Session R optional (W-12's `hold-watch` step, overnight `--record` under `caffeinate -i`) |
| 0.6.2's cut items | P2 §7.2 | C-1 (Linux), Session R optional, or the matrix |
| TCI-05, TCI-06, TCI-07, PLT-03 (Xcode items) | P2 WP-18; RD §5.1; Q-B7 (Xcode is installed on the M5) | Run in 0.6.2, maintainer-run from Claude's step-by-step list; whatever 0.6.2 left rides in 0.7 the same way (C-1; Session R step 11) |
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
| Q7-1 to Q7-9 | this plan | §14 (Q7-1 to Q7-7 decided by delegation, 2026-10-22; Q7-8 settled; Q7-9 decided by the maintainer, W-13) |
| M-1, M-2, M-3, M-5, M-9 | RD §6 | §14 (all decided 2026-10-22; M-5 approved as written, with no dates) |
| 0.6.2's A0: 0.6.0 → 0.6.1 in-app kept the widget and Open at login | P2 Appendix C | D-9; C-1 (WP-16 item 5 has no cause); §7.3 (no `openAtLogin` expected); Appendix C |
| 0.6.2's branches: integration `claude/nice-faraday-k08mhb`, `claude/062-<pkg>`, `claude/062-spike-widget` | P2 §3 | D-1, D-11, W-0 item 6 |
| M-1's consequences: no App Group, no Developer ID work, known limitations at 1.0 | RD §3.4, §4.2, C3, C7, C16 | §1, §2.2 (W0-3), G7-5, the stretch, C-1, §6.5, §12, §14 |
| The build-number risk | ci.yml:135; `release.yml:109`; `build-app.sh:112-113` | Fixed in D1: one growing clock in both workflows (§6.5; this plan's addition) |
| A parameter added to a shipped intent (1.1's History chart, FEA-19) | P2 §8.13; RD C14 item 5 | Session R step 4.4 (RC-P), recorded in Appendix C |
| What 0.7 didn't build | P2 §8.3, §8.5, §8.8; W-5 to W-7, W-9 | Moved to `docs/plans/1.1/widgets.md` at D3 |

---

## Appendix B: facts verified for this plan, conflicts, and what stays unverified

**The repository at `eebf748` (v0.6.1's code):**
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
  - It observes only `monitor.snapshot` (`WidgetRefresher.swift:24-32`) and reloads one kind (:77).
  - It ends the previous extension with `kill` after an update (:44-68), the only allowed signal
    site (`SecurityGuardTests.swift:76-80`).
- **The extension's packaging:**
  - `build-app.sh` copies every `.lproj` into the appex (:118) and signs it with its entitlements
    file (:203).
  - The posture check compares the widget's entitlements to that file (:296-302).
  - The entitlements are the sandbox alone (`Resources/BatteryPulseWidget.entitlements`).
- **Size:** the ceilings are `widget_binary_bytes` 1,450,000, `widget_text_bytes` 990,000,
  `strings_bytes` 251,000, `app_kb` 4,840 and `dmg_bytes` 1,520,000 (`scripts/size-budget.json`).
- **Signposts:** `Signposts` is public with `init(subsystem:log:)`, and BatteryKit's `Diagnostics`
  is internal (`BatteryKit/Diagnostics.swift`). The app has its own twin
  (`App/Diagnostics.swift:9-24`).
- **`bpulse`'s JSON:**
  - the Mac's `--json` uses ISO 8601 (`main.swift:161-163`);
  - the device's JSON sets no date strategy (`main.swift:189-190`);
  - the accessories' JSON is a bare array (`main.swift:208-211`);
  - device storage uses ISO 8601 itself (`DeviceStore.swift:141-149`);
  - `--export json` has `formatVersion` 1 (`HistoryExport.swift:135`).
- **App pieces 0.7 builds on:**
  - `SidebarItem.storageKey` strings (`MainView.swift:64-90`) and `@SceneStorage("mainSelection")`
    (:105);
  - `WindowOpener` (`AppSettings.swift:224-240`);
  - `AppDelegate`, which has no URL or activity handler (`BatteryPulseApp.swift:174-234`);
  - `AccessoryMonitor`, always running (`BatteryPulseApp.swift:32-35`).
- **The drawn-battery painter:** `BatteryIconPainter` and `BatteryIconCanvas` use SwiftUI and
  CoreText in the app target (`BatteryIconView.swift:1-5, 9, 215`).
- **What's New:** `WhatsNew.version` is 0.6.0 (`UpdateViews.swift:388`).
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
  - `MacAccessoryProvider` is `@MainActor` (`MacAccessoryProvider.swift:14-15`).
  - `MacPowerParser.validMinutes` accepts up to 65,534 (`MacPowerParser.swift:123, 281-284`).
  - The heat alert has hysteresis: serious or critical arms it, nominal resets it
    (`BatteryAlerts.swift:104-117`).
  - `WidgetRefresher.evaluate()` returns without a snapshot (`WidgetRefresher.swift:74`).
  - `build-app.sh` copies the widget at :117, strips it at :186 and signs it at :203; English ships
    no string table (:119-122).
  - `ci.yml` only reads the repository (:22-23). The release workflow's `run_number` was 7 for
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
  `BUILD_NUMBER` comes from release.yml's run number (:109) and CI's from its own (ci.yml:135).

**GitHub's REST API (2026-10-22), the usage evidence behind M-1** (§14; RD §1.1):
- DMG downloads across all releases: 14 (0.2.0: 1, 0.3.0: 2, 0.3.1: 4, 0.4.0: 1, 0.5.0: 2, 0.6.0:
  3, 0.6.1: 1, the last a signature check during the release).
- Signature (`.sig`) downloads: 5, a privacy-free proxy for in-app updates.
- Repository page views: 2, by 1 visitor, in 14 days. No stars, forks or outside issues.
- By 14:26 UTC the same day: 15 DMG and 6 `.sig` downloads. Both rose by one on 0.6.1, which
  matches the maintainer's own 0.6.0 → 0.6.1 Install and Relaunch (0.6.2's A0). Table below.

**The update traffic, for W-13** (the repository at `eebf748`, checked 2026-10-22):
- `startAutomaticChecks()` wakes 20 s after launch, then every 6 h with a 36-minute tolerance
  (`UpdateChecker.swift:66-76`). A tick checks only when `UpdatePolicy.isCheckDue` allows and no
  rate limit holds (:116-123; `Updates.swift:190-238`).
- `check(userInitiated:)` (:125-157) records the check at :137 on success and at :149 on
  `noReleases`; the offer is decided at :139-147. The check's GET sets only `Accept`,
  `X-GitHub-Api-Version` and `User-Agent` (:164-191).
- `UpdateNetwork` (:194-215) holds the only two `URLSession(` constructions in `Sources/` (:198,
  :201): ephemeral, `urlCache = nil`, and for automatic checks no constrained or expensive network.
  It sets nothing about cookies.
- The type's doc comment (:8-13) calls the check "the only network request BatteryPulse makes on
  its own".
- The installer fetches the `.sig` and the DMG on `UpdateNetwork.user`, setting only `User-Agent`
  (`UpdateInstaller.swift:184-234`).
- `SecurityGuardTests` bans only `URLSession.shared` (:47-53). `EnergyGuardTests.oneShots` has four
  entries.
- The `WhatsNewPolicy.lastLaunched != current` branch runs once per new version, before
  `markSeen` (`BatteryPulseApp.swift:56-59`).
- The Welcome window embeds `GeneralSettings` (`WelcomeView.swift:32-34`), whose update section is
  `GeneralSettings.swift:79-99`.
- `AppVersion(parts:)` is public. `UpdateInstallPolicy.unversioned` is 0.0.0
  (`UpdateInstall.swift:133`). `Diagnostics.update` is the app's `update` logger
  (`App/Diagnostics.swift:19`).
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
| VC-5 | github.com sets three cookies (`_octo`, `logged_in`, `_gh_sess`) on a release download URL, even when it answers 404. `api.github.com/…/releases/latest` sets none. The ephemeral sessions keep cookies in memory for as long as the app runs (`UpdateChecker.swift:203-215`) | an HTTPS request from the command line, 2026-10-22 | observed |
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

**Conflicts between Apple's sources** [conflict]:
- **Extra-large portrait on the Mac.** The `WidgetFamily` page lists macOS 27.0, "on the Desktop on
  macOS". The HIG's size table lists "System extra large portrait" as not supported on the Mac.
  0.7 doesn't use it, and P2's "later" stands.
- **The accented mode on the Mac.** The HIG's rendering table lists the Mac as "Not supported" for
  accented and "Desktop" for vibrant. The HIG's own text ("On iPhone, iPad, and Mac, the system tints
  primary and accented content white") and Apple's Liquid Glass widget articles (P2 §8.2) say the
  Mac uses accented under the tinted and clear appearances. W0-4 (2) measures; until then, W-3b
  designs for all three modes.

**Not verified here; decided by 0.6.2's spikes or 0.7's sittings:**
- the processor step under SwiftPM (W0-1);
- the per-family `size:` overload against macOS 27.0 (W0-1 (a));
- whether a placed static widget survives the change to `AppIntentConfiguration` (W0-2);
- whether a widget without `Metadata.appintents` still appears in the gallery (W-2's rollback);
- accessory reads from the sandbox (W0-4 (1));
- the rendering mode per Icon & widget style and place (W0-4 (2));
- what a click delivers, and whether a scheme is needed (W0-4 (4), (5));
- whether Text size reaches desktop widgets (W0-5);
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
- the exact System Settings path of the Charge Limit on macOS 27, and whether macOS holds the
  charge while `caffeinate -i` keeps the Mac awake (W-12's `charge-limit` and `hold-watch`);
- the size of `Metadata.appintents` (§9);
- how GitHub computes `download_count`: which requests count, and how one address's downloads
  merge (VC-2, VC-3; W-13 relies only on the documented GET, and §6.4 step 6 sees one count
  arrive);
- the CNIL's exact conditions for exempt audience measurement (VC-8).

---

## Appendix C: facts 0.7 records (filled during the release)

**From 0.6.2** (W-0):

| Fact | Shown by | Decides |
|---|---|---|
| D-1, D-11: where the W0 answers, the whole Appendix C and the session script are (the copy in `docs/plans/0.7.0/`, or the kept branch, Q7-8) | 0.6.2 D3 | W-0, W-12 |
| D-2, D-3: K-03 and internalize shipped; the widget's `__text` and binary at v0.6.2 | 0.6.2 CI | G7-10; W-0K |
| D-4: WP-14a's shape (a nonisolated protocol, or `readNonisolated(scope:)`) | 0.6.2 code | W-3a |
| D-6: WP-10 kept or reverted | 0.6.2 | W-3c, W-4 style |
| D-7: the widget ceilings after 0.6.2's D1 | `size-budget.json` | §9 |
| D-8: the Russian method for the widget | 0.6.2 Session A step 3.3 | Session R step 4.3 |
| D-9: placed widgets after 0.6.1 → 0.6.2 in-app | 0.6.2 D3 | G7-2, Q7-4 |
| D-12: the installer 0.6.2 shipped | 0.6.2 G-16 | F12 at the logged day's end (§6.3) |
| D-13: the Charge Limit capture done or not | 0.6.2 | Session R optional |
| W0-1 to W0-6: each answer, and §2.2's row | 0.6.2 Appendix C | every package |
| D-16: ROADMAP's Releases table has download columns, with v0.6.2's counts; `scripts/release-stats.swift` exists and looks for `BatteryPulse-count.txt` | 0.6.2 D3 | §13 step 8 |
| 0.6.2's A0, the 0.6.1 after-publishing intake: **passed** (recorded 2026-10-22). 0.6.0 → 0.6.1 through Install and Relaunch kept the desktop widget, which shows the current charge, and Open at login kept its state | the maintainer; P2 Appendix C | D-9's baseline; C-1 (WP-16 item 5 has no cause); §7.3 |
| WP-18's Xcode items: what 0.6.2 ran and what it left | 0.6.2 Appendix C | C-1; Session R step 11 |
| M-5's answer: **approved as written, with no dates** (recorded 2026-10-22; every decision is in §14) | the maintainer | R-1 |

**0.7's own:**

| Fact | Shown by | Decides |
|---|---|---|
| The widget's `__text`, binary, `widget_appintents_bytes` and `strings_bytes` per commit | CI | G7-10 |
| `appintents-check`'s counts; the extracted `Summary` keys | CI (W-2, W-3a) | W-10's placeholder rule |
| Whether the render test target links; whether Russian renders | CI (W-3a) | §6.1 |
| The look check's answers 1-9, and the second look's | the PR | W-3b, W-8, §14 |
| Session R steps 2-9, per step: the answers, screenshots, `pluginkit`, the click routes | Session R | G7-2, G7-3, G7-4, G7-8, G7-9, G7-12, G7-13 |
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
