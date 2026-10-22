# BatteryPulse 0.6.2: the plan (revised draft for the maintainer)

Revised 2026-10-22 against `9410861` on `claude/nice-faraday-k08mhb`, whose tree equals the v0.6.1
tag (`7622373` on `main`, a squash merge). The first draft was written at `0215b71`.

Inputs:
- `docs/ROADMAP.md` at `9410861`: Stage 1.7, the 0.7 entry and the open checks of every stage.
- The 0.6.1 plan, playbook, research files and session script, which `9410861` removed. Below,
  "PLAN" means `docs/plans/0.6.1/PLAN.md` at `6aec4d2` (`git show 6aec4d2:docs/plans/0.6.1/PLAN.md`);
  "playbook", "research `<file>`" and "the 0.6.1 script" mean the files of the same folder at the
  same revision.
- The M5 session results on PR 11 (comments 6336230779 and 6336318062, 2026-10-22) and the
  maintainer's settled answers from the session chat.
- Apple's documentation (fetched 2026-10-22), the macOS 26 and 27 release notes, WWDC26 session
  277, and the Swift Package Manager 6.4 sources.
- Five independent reviews of the first draft.
- The maintainer's answers of 2026-10-22 (§10), and the release download counts from GitHub's REST
  API the same day (§10, "Usage evidence").

CLAUDE.md wins over all of them.

Hashes cited here that are not on `main` (`0215b71`, `1f9937b`, `11d2ab3`, `647bc74`, `6aaf8ec`,
`6aec4d2`, `9410861`) are in PR 11's history, which GitHub keeps as `refs/pull/11/head`
(`git fetch origin pull/11/head`); `claude/nice-faraday-k08mhb` restarted from `main` after the
merge. The energy baseline build lives on `claude/baseline-0.6.0` (`076873d`), which stays until
0.6.2's D3; the `claude/061-*` package branches go after the 0.6.1 release, as PLAN §8 says.

This file is English only and names no third-party product, so it can be committed under
`docs/plans/0.6.2/` as is (`LocalizationCatalogTests.russianTextOnlyInTheCatalog` scans `docs/`).

Contents:
1. At a glance
2. What the 0.6.1 M5 session settled, and what it left open
3. How every package runs (0.6.1's practices, kept)
4. Work packages
5. Order and parallelism
6. The M5 sessions
7. Gates and their defaults; cut line; frozen surfaces
8. Widget customization: the design (phased: 0.7 MVP, then later)
9. Recommendation: widget customization in 0.7, not 0.6.2; the phases
10. The maintainer's questions and their answers (2026-10-22)
- Appendix A: traceability of every carried item
- Appendix B: facts verified for this plan
- Appendix C: facts 0.6.2 records (filled during the release)

---

## 1. At a glance

- **What 0.6.2 is:** the second maintenance and foundation release, with no new features. It:
  - carries 0.6.1's deferred backlog;
  - fixes the beta window styles' last known bug;
  - runs the energy measurements 0.6.1's session skipped;
  - lays the size and read-path groundwork that widget customization (0.7) needs.
- **Headline items:**
  - **Main actor by default** for the app (WP-10), first, as ROADMAP Stage 1.7 decided. It is
    checked on the M5 in the first sitting, before other packages stack on it.
  - **The read path.** The M5 numbers gate both parts in: `read` p95 is 8.8 ms against E20's 4 ms
    threshold, and the registry is 72 % of a read.
    - Full reads move off the main actor (E20, WP-14a) right after WP-10, and run on the M5 for
      two hours in Session A.
    - The registry is read only when it changes (E4b, WP-14b), but only after Session A has checked
      E4b's premise. Power and Raw Data keep re-reading the registry.
  - **Clear minimizes without a black frame:** an opaque graphite fill, the maintainer's choice
    (Q-B2), checked on screen recordings. Also the evidence that decides whether Translucent and
    Clear leave beta, and each style's energy against Standard (no Low Power Mode fallback, Q-B10).
  - **Widget size:** CryptoKit and the device stack out of the widget (K-03, a `BatterySource`
    target) and `-internalize-at-link` on the widget. Together they free a few hundred KB of the
    widget's `__text`, the headroom 0.7 needs.
  - **The installer** moves to `diskutil image attach` and `diskutil eject`, with the flags the CI
    runner already prints.
  - **Energy against three builds:** the instrumented 0.6.0, 0.6.1 and the RC.
    - The 0.6.0 and 0.6.1 runs happen in Session A's unattended window, and the RC's in Session B.
    - They are judged against the playbook's targets.
    - `pmset -g pslog` covers E3b and E4b's premise.
- **Widget customization:** designed in §8 and phased in §9.1; in 0.7, with no 0.6.3 (Q-W1).
  - **0.7 MVP:** a configurable Battery widget in small, medium and large (extra large on the
    look check's yes, Q-W10), with accessibility, and an Accessories widget if the sandbox allows
    it.
  - **0.7 stretch:** the data feed (Q-W3: yes, if W0-3's candidate A or A′ works), then the
    History and iPhone & iPad widgets.
  - **0.6.2:** only throwaway spikes (W0-1 to W0-6, with a control build) and the size headroom.
- **Maintainer time:** two M5 sittings. Every step has a default for when it doesn't run.
  - **Session A, early:** about 65 minutes hands-on, then a 3-hour unattended window (plug the
    adapter in once, at the 2-hour mark).
  - **Session B, on the release candidate:** about 95 minutes hands-on and about 70 minutes
    unattended.
  - Both include the Xcode items, now that Xcode is installed on the M5 (Q-B7). WP-18's Xcode
    work (about an hour) runs whenever Xcode is open, from Claude's step-by-step list.
- **Decisions (2026-10-22):** no question of §10 stays open. The maintainer answered Q-B2, Q-B7,
  Q-W1 and, through M-1, Q-W3; he delegated the rest ("by best practices"), and each carries its
  recommended answer. M-1, the paid Apple Developer Program account, is no: no App Group (§8.3
  candidate C) and no Enhanced Security spike (WP-20). Usage evidence: 14 DMG downloads across
  every release, so the users are, in effect, the maintainer (§10).
- **Budget:** about 29-32 implementation and review runs plus 3 for fix-forward; the never-cut set
  is about 22-26 (§7.2).

---

## 2. What the 0.6.1 M5 session settled, and what it left open

The session ran on 2026-10-22 on a MacBook Air M5 with macOS 27.0.1. It used build B (0.5.99, CI
run 39492991212) of the RC at `647bc74`. That code is identical to `81dd648`, whose run 39483296558
gave the size numbers; `11d2ab3` only filled in the run numbers. Results are on PR 11.

0.6.1's D3 applied the session's decisions:
- Translucent and Clear moved behind Settings → Advanced → Beta window styles, with a Beta mark on
  their tiles. A 0.6.0 user who chose one keeps it.
- The History hover readout went back to 0.6.0's material.
- Raw Data's source pop-up became a menu button sized to its label.

### 2.1 Numbers (build B, core session; `scripts/perf-stats.swift`)

| Interval | Count | p50 ms | p95 ms | Reading |
|---|---|---|---|---|
| `read` | 699 | 6.268 | 8.789 | 648 app reads and 51 widget-extension reads. E20's gate (full read p95 > 4 ms) **passes** |
| `registry` | 699 | 4.501 | 5.553 | 72 % of a read: E4b is the largest lever |
| `children` | 699 | 1.069 | 1.157 | |
| `smc.power` (B0AV, B0AC) | 594 | 0.481 | 0.918 | E4a works: polls read two keys |
| `smc.other` (the 14 others) | 93 | 2.122 | 2.701 | at most every 60 s |
| `iops` / `adapter` / `parse` | 699 | 0.325 / 0.408 / 0.153 | 0.449 / 0.688 / 0.227 | |
| `refresh poll` | 501 | 6.507 | 8.299 | 501 of the app's 648 reads (77 %) are polls |
| `refresh notify` / `followUp` / `launch` | 93 / 22 / 15 | 6.916 / 6.066 / 7.236 | 9.462 / 8.983 / 7.619 | |
| `refresh history` | 24 | 8.893 | 9.356 | the minute tick when nothing else had read |
| `page.switch` | 15 | 30-65 | up to 70 | n = 1-6 per page: Overview 65 (1), Demo 63 (1), Accessories 49 (1), Health 46 (3), History 37 (6), Power 36 (1), Developer 30 (2). Too few for a p50, so WP-17 takes ≥ 10 per page |
| `history.load day` / `week` | 11 / 4 | 51.6 / 9.9 | 70.0 / 15.1 | the 24-hour view loads 5× slower than 7 days |
| `history.record` | 686 | 0.128 | 11.649 | a long p95 tail |
| `raw.rebuild` / `raw.filter` | 27 / 71 | 4.770 / 0.046 | 6.783 / 2.572 | |
| `accessory.read` | 58 | 0.299 | 0.478 | the app's accessory read (a reference for W0-4 and the Accessories widget) |
| `update.check user` | 3 | 269 | 269 | network |

Events:
- `menuBarReady` fired 15 times, every process with exactly 1 read before it (WP-2a's goal met).
- Reads per notify burst: 1, with three bursts of 2.
- `widget.reload`: 22 by policy and 5 after an update.
- The widget extension read the battery 2-32 times per process.

### 2.2 Answers that need follow-up

| Step | Answer | What 0.6.2 does |
|---|---|---|
| UR-3 | The script asked "Did a black frame appear…? (n: none)". It was the only question where y meant bad. Standard, Light got y; the other 15 cases got n. Most likely a polarity slip. The maintainer's settled report stands: Clear shows a black frame while minimizing and restoring; Translucent doesn't | WP-13 fixes Clear. Session A records the cases on video. From now on, every y/n question means "y = looks right", and look comparisons use numbered choices |
| V1b | **n**: the Clear tile's sky reads differently selected and unselected | WP-13 (the tile picker promises an identical preview either way) |
| V1d | **y**: the menu bar icon looks right next to the system's battery item in both appearances | WP-22 ticks Stage 1.3's light and dark comparison; the rest of Stage 1.3 stays open (§6, optional) |
| V4-materials | **y**: Frosted's and Translucent's sidebar and toolbar are acceptable | Clear's are judged in Session B's shots (Q-B4) |
| G10 | "didn't understand the question" | Nothing: the maintainer had already chosen the accent outline (PLAN §8). Session questions are now plain choices |
| V4 readout | not readable on Standard, Translucent and Clear with the card surface | Fixed in 0.6.1 by the material; Session B's screenshots include it |
| V4 screenshots | 0 of 8 | Session B's set is scripted: the script captures the front window |
| F5, F9 | not run (no section in the PR comments) | Session A runs F5 (accessories, iPhone page) before W0-4; Session B runs F9 (Russian) |
| F12 | failed on the first try (no 0.6.0 offered, 0.5.99 stayed), passed on the second (0.6.0 installed and relaunched) | G22 passed. The first failure was GitHub's limit of 60 unauthenticated API requests an hour per address, used up behind a VPN that shares its address; the app said "GitHub is limiting requests", and the re-run after the limit reset passed (Q-B9, settled). WP-16 keeps the CI install step |
| Energy extras, burst, memory | not run | WP-21: A/B in Session A's unattended window, the RC in Session B |

### 2.3 Gates the numbers now decide

PLAN's gates are written without a hyphen (G10-G22) and appear only as citations of PLAN. 0.6.2's
own gates have a hyphen and are named after their packages (§7.1); the last column maps them.

| Gate (PLAN §3.6) | Decision for 0.6.2 | 0.6.2 gate |
|---|---|---|
| G13 K-03 | Passed in WP-11 (about 187 KB out of the widget); Q6 held it for 0.6.2 → **in** (WP-15) | G-15 |
| G14 E4b | Registry 4.5 of 6.3 ms → **P1** (WP-14b), only if Session A confirms its premise (F13) | G-14b |
| G15 E3b | Needs `pmset -g pslog` for 2 hours on battery and 1 hour charging → Session A's window, then WP-14b | G-14c |
| G16 E20 | p95 8.8 ms > 4 ms → **in** (WP-14a, round A2, right after WP-10) | G-14a |
| G17 SUI-07, -11, -12, E19 | `page.switch` 30-65 ms p50 → **P2** with the SwiftUI instrument (WP-17) | G-17 |
| G18 SEC-15 | Attach timing on the M5 → Session A, with WP-16 | SEC-15 |
| G19 SEC-10 | No hang or crash seen (Q1) → **stays deferred** | none |
| G20 SEC-08 | The in-app update is now possible after publishing, but **not run** (Q-B8: no; Enhanced Security is after 1.0 and not planned without notarization, M-1) | SEC-08 (not run) |
| G21 SZ-10, -11, -14 | SZ-11 and SZ-14 in WP-15 as CI experiments; SZ-10 needs Xcode, which is installed on the M5 (WP-18, maintainer-run; Q-B7) | G-15 (SZ-11, SZ-14); WP-18 (SZ-10) |

---

## 3. How every package runs (0.6.1's practices, kept)

Everything in PLAN §3.0 still applies. The short form:

- **Branches:**
  - The integration branch for 0.6.2 is `claude/062-integration`, from v0.6.1 (`7622373` on
    `main`): a `claude/` name, so CI runs (ci.yml:3-5).
  - Each package gets its own worktree and branch, `claude/062-<pkg>`, from the integration tip.
    Spikes go on `claude/062-spike-*` and are never merged.
  - At most two agents, never two on the same file. Builds use `-j 2`, with no shared `.build`.
- **An implementation run, then a separate review run.** One commit per item where practical.
  - Before each commit, run `swift format format -i -r Sources Tests Package.swift scripts`,
    `swift build`, `swift test` and `swift format lint --strict -r Sources Tests Package.swift
    scripts`.
  - Any Darwin change needs a green macOS job.
  - Merge `--no-ff` after both jobs are green. The next merge waits for the integration run, and a
    red integration run is fixed forward at once.
- **Measure first.** Every optimization has a before and an after, with the stable signpost names.
  - **The "before" is v0.6.1**, which already carries the instrumentation. M5 runs use its
    published DMG; Linux benches (§4a-style) use the tag.
  - CI builds pushes to `main` and `claude/**` only (ci.yml:3-5), not tags. Rebuilding 0.6.1 (a
    profiling build, say) therefore goes through a branch `claude/baseline-0.6.1` at `7622373`, or
    a `workflow_dispatch` run on the tag.
  - **Energy and launch compare three builds:**
    - A = `claude/baseline-0.6.0` (`076873d`), the instrumented 0.6.0 that 0.6.1's session used.
      ci.yml sets no artifact retention, so it is rebuilt from the branch if its artifact has
      expired. v0.6.0 itself (`6133b4f`) has no `perf` lines and no `menuBarReady` (`git grep`
      finds none), so it can't be A.
    - B = v0.6.1's published DMG.
    - C = the RC.
- **Rules have guard tests.** A new rule lands with its `MotionGuardTests`, `EnergyGuardTests` or
  `SecurityGuardTests` case, scanning Darwin code on Linux. An exception goes on the suite's list
  with its reason. A new target joins `SourceScanner`'s lists in the same commit (WP-15).
- **Gates with defaults.** Every M5-dependent decision has a default (§7.1), so a short session
  still ships. A default never ships read-path code that no M5 run has exercised: the CI runner
  has no battery, and its launch smoke logs `No battery` after a 0.06 ms registry lookup. The one
  exception is K-03 without Session B (G-15): it may ship as a move with only access and import
  changes, an empty golden diff and a passing CI smoke.
- **Facts go to Appendix C** in the committed copy of this plan: one line per fact, the job or
  session that showed it, and the item it decides.
- **Strings:** only one running package may touch `Localizable.xcstrings`, and only WP-13 item 5
  does.
  - Graduating either beta style rewords the Advanced footer (`Settings/AdvancedSettings.swift:54-62`)
    and What's New feature 3 (`Updates/UpdateViews.swift:409-411`): new keys with their Russian,
    old keys removed.
  - Graduating both also removes "Beta", "Beta window styles" and the footer
    (`App/Localized.swift:239-242`), because `LocalizationCatalogTests` fails on unused keys.
  - Spike branches add strings only there.
- **Frozen surfaces:** 0.6.1's list (playbook §3.4) plus `betaWindowStyles`, which shipped in 0.6.1.
  §7.3 lists what 0.6.2 may change on purpose.
- **Session wording** (the lesson of UR-3 and G10):
  - Every yes/no question means "y = looks right".
  - Comparisons of looks are numbered choices.
  - Screen recordings and screenshots are the evidence, not memory.
  - The script, not the maintainer, reads logs, counts crash reports and runs Console filters.
- **The maintainer decides only what he sees or does** (PLAN §8, "Architecture: delegated"): look,
  behaviour, settings, the sessions and the release. On 2026-10-22 he delegated this plan's
  remaining questions too (§10). What he still decides is what he sees in the sessions: the fill on
  video, each beta style's graduation, the Icon Composer icon, and the release.

---

## 4. Work packages

IDs continue 0.6.1's numbering, so ROADMAP's "WP-10" keeps its meaning. P1 must ship, P2 ships if
the budget allows, P3 is opportunistic.

### WP-0 (dropped)

Both F11 "n" answers were passes once clarified in the session chat. The notification arrived at
the threshold's 80 % minimum and opened the app, and turning Open at login off worked. There is no
package. Session B's F11 uses a reachable threshold and plainer wording.

### WP-10: Main actor by default for the app (P1, first)

- **Source:** PLAN §3.1 and §6 (SW-04 with V-01), ROADMAP Stage 1.7 ("first"), research `swift.md`
  SW-04 and V-01.
- **Items:**
  - `.defaultIsolation(MainActor.self)` for `BatteryPulseApp` only, in the shared settings style of
    `Package.swift` (PackageDescription 6.2+; one line, no `-Xswiftc`). BatteryCore, BatteryKit,
    bpulse and **the widget** stay nonisolated. The widget is on the rejected list, because
    WidgetKit calls its provider on its own threads.
  - Remove the type, member and static `@MainActor` annotations (35 today). Keep the four that
    default isolation doesn't replace:
    - the three function types `@MainActor (DeviceKey) -> Void` (`Main/MainView.swift:316, 362`;
      `Main/DeviceView.swift:15`);
    - `Task { @MainActor in SystemAppearance.shared.update() }` inside the KVO change handler
      (`App/WindowLook.swift:254`). A `Task {}` inside a `@Sendable` closure stays nonisolated
      (research `swift.md`, SW-04 corrections).
  - Mark the off-main code `nonisolated` explicitly:
    - `nonisolated enum UpdateInstallSteps`, in the same commit, so `withMountedImage` and
      `checkCodeSignature` can't drift onto the main actor (`Updates/UpdateInstaller.swift:339-500`);
    - `DownloadWatcher`, called on URLSession's delegate queue (`UpdateInstaller.swift:318`);
    - `AppearanceVariants`, which backs an `NSImage` drawing handler
      (`MenuBar/BatteryIconView.swift:313-324`);
    - the `UNUserNotificationCenterDelegate` methods, which already are (`BatteryNotifier.swift:228-243`);
    - any `NSViewRepresentable` coordinator callback that AppKit calls off the main thread.
    - `WindowMinimizeReader`'s observers stay isolated, because AppKit posts them on main; the code
      says so.
    - The IOKit and notify callbacks live in BatteryKit (`SystemNotifications.swift:42, 68`), which
      WP-10 doesn't touch.
  - The three `onChange` hops are already gone with SW-09.
- **Files:** `Package.swift` (one hunk), and every app file with `@MainActor` (a mechanical change;
  later packages rebase over it, as WP-1's fix-ups did).
- **Guards:** a `SecurityGuardTests`-style scan pins exactly the four kept `@MainActor` sites (paths
  and count), and checks that each listed off-main type keeps `nonisolated`. This pin lives in
  WP-10 only.
- **Acceptance:**
  - The macOS job is green with 0 warnings, and the CI launch smoke passes.
  - V-01 on the M5, twice: in Session A on SPIKE-A2 (the A2 integration tip), and in Session B on
    the RC.
    - The maintainer: a sample notification received and one clicked, again with the window in
      front; the menu bar icon on light and dark bars; Raw Data, History, Demo Mode, Check Now and
      Clear History; the lid closed for a minute.
    - The script: counts "executor" log lines and new crash reports (§6).
  - V-01's install half is F12: the RC's installer downloads, verifies, mounts, copies and
    relaunches.
  - V-01's post-update half (a new version's first launch: the widget reloaded after an update, the
    login item, notification permission) runs only in D3's after-publishing check, with
    `gh release edit v0.6.2 --prerelease` as the rollback. A local test release can't be built,
    because the app fetches only `releases/latest` (`BatteryCore/Updates.swift:158`; PLAN §4b).
- **Gate:** G-10 (§7.1). **Effort:** M, 3 runs. **Risk:** medium; runtime traps only the M5 shows,
  which is why they are looked for in Session A.

### WP-13: Beta window styles: Clear's minimize fill and the graduation evidence (P1)

- **Source:** the maintainer's settled report (Clear shows a black frame while minimizing and
  restoring); V1b; ROADMAP Stage 1.5's open check (lines 333-339); the Decisions line "no Low Power
  Mode fallback until the energy is measured" (ROADMAP:31-32); CLAUDE.md's Liquid Glass rules.
- **Working hypothesis (unverified, as PLAN's UR-3 already said):**
  - While the window minimizes, `sheetSurface` swaps the glass for a plain fill of the sheet's own
    tint at the tint's opacity (`BatteryCore/WindowLook.swift:211-224`).
  - Clear's tint is near-black (white 0.03) at 65 %, and the minimize animation's snapshot may have
    no desktop under it, so the window turns dark grey to black.
  - Translucent Dark (black at 45 %, `WindowLook.swift:206`) should then darken too; the
    recordings show whether it does.
- **Items:**
  1. **An opaque minimize fill** (P1): **(b), the graphite composite**, the maintainer's choice
     (Q-B2, 2026-10-22). The three candidates were:
     - **(a)** today's fill;
     - **(b)** the tint composited over a mid grey: 0.03 × 0.65 + 0.5 × 0.35 = 0.1945, about 19 %
       white in sRGB-encoded values as `Color(white:opacity:)` uses them, with white text at 12.9:1;
     - **(c)** the window background colour.

     Session A's recordings on SPIKE-A2 check (b) before WP-13 is written, and show whether
     Translucent Dark, which keeps today's fill in them, shows the frame too (§6 step 6).

     In BatteryCore, `WindowLookPolicy.minimizeFill(systemDark:)` returns fill (b), and
     `sheetSurface(systemDark:isMinimized:)` returns `.fill` with it. Extend this to Translucent
     Dark if its recordings show the frame.
     - Linux tests: Clear's fill is opaque and equals 0.1945; white text on it clears 4.5:1;
       Standard and Frosted are unchanged.
     - Rewrite `sheetSurface`'s doc comment (`WindowLook.swift:211-220`), which says the fill is
       "never opaque".
     - The swap still never animates and never survives a restore (`MotionGuardTests` already
       forbids animation in `App/WindowLook.swift`).
     - **Not built: a fill that follows the desktop picture.** Q-B2 chose (b), so the variant stays
       out: an average of the desktop picture (`NSWorkspace.desktopImageURL(for:)`, main thread
       only), decoded in a `@concurrent` function when the window appears and on Space changes,
       opened only from the system's Desktop Pictures folders and `~/Pictures` (elsewhere, macOS's
       consent rules could show a file-access prompt, unverified on macOS 27), cached in memory
       only, never polled.
  2. **V1b:** find why the Clear tile's preview differs when selected (the outline's inset, the fill
     under the preview, or the selection's highlight) and make the preview identical in both states.
     A `MotionGuardTests` case or a review check confirms that the selection changes only the
     outline.
  3. **Graduation evidence** (no code unless the maintainer asks for a change). Session B step 3's
     scripted shots (§6) cover the look items below. The contrast audit (step 3) and Clear's
     shadows in Instruments (step 5) use Xcode, which is installed on the M5 (Q-B7), and the
     energy comes from S4w:
     - The contrast audit with Accessibility Inspector (it ships with Xcode); full screen; the
       graphite tint on the sidebar selection.
     - The inspector and the Demo Mode bar on the sheet; the scroll edge under the title; Form
       section fills and table stripes.
     - Clear's dark appearance staying in its window (Settings stays light).
     - Frosted next to the widget gallery.
     - Clear's shadows in an Instruments recording of the profiling RC (Session B step 5).
     - Each style's energy (S4w, WP-21).

     What Session B doesn't reach stays open in Stage 1.5.
  4. **Stage 1.5 leftovers: not in 0.6.2** (Q-B4, decided by delegation): thicker chart lines and
     wider area fills on the sheet; the content treatment on the Raw Data table. A Session B shot
     answered n for either keeps that style beta, and item 4 waits for a beta style's graduation,
     after 1.0 (FEA-25; `docs/plans/1.0/ROADMAP.md` §4.1; plan-0.7.0 C-1).
  5. **Graduation mechanics**, only on the maintainer's answer (Session B, per style):
     - `isBeta` turns false for that style and its Beta mark goes.
     - The strings change as §3 says, and the toggle hides itself once no beta style is left
       (`Settings/AdvancedSettings.swift`).
     - `WindowLookTests.swift:38`'s `isBeta == usesGlassSheet` expectation changes with it.
     - `betaWindowStyles` stays a frozen key, and a user with the toggle off keeps their stored
       choice.
     - **Low Power Mode (G-13c): no fallback** (Q-B10, decided by delegation, 2026-10-22). S4w
       still compares each style with Standard, and ROADMAP's decision line becomes "none (Q-B10),
       measured in 0.6.2", with the numbers.
- **Files:** `BatteryCore/WindowLook.swift`, `App/WindowLook.swift`, `WindowLookTests`,
  `Settings/PreviewTilePicker.swift` and `Settings/WindowLookSettings.swift` (V1b),
  `Settings/AdvancedSettings.swift`, `Updates/UpdateViews.swift`, `App/Localized.swift`,
  `Resources/Localizable.xcstrings`, `README.md` ("two beta styles"), `docs/USER_GUIDE.md` (147-163,
  and the known issue goes), `.github/release-notes.md`.
- **Acceptance:**
  - Linux tests; the macOS job.
  - Session B: no black frame in the 8 glass-sheet cases (Translucent and Clear × Light and Dark ×
    main and compact window), each recorded.
  - Standard and Frosted are compared with a Notes window minimized the same way: anything also
    seen there is the system's, not WP-13's.
  - The maintainer's plain answers on each style (§6); the fill itself is decided (Q-B2).
- **Gates:** G-13a (the fill), G-13b (graduation), G-13c (Low Power Mode: decided, none).
  **Effort:** S-M, 2-3 runs. **Risk:** low.

### WP-14a: Full reads off the main actor (E20) (P1)

- **Source:** PLAN §6 (E20; G16), research `energy.md` E20; the numbers in §2.1.
- **When:** round A2, after WP-10 merges, because it edits `App/HistoryRecorder.swift`, which WP-10
  also edits. Its build then runs on the M5 in Session A.
- **Items:**
  1. **The provider becomes nonisolated and `Sendable`.**
     - `SMCClient`'s whole mutable state goes behind one `Mutex`: port, key info, missing keys,
       logged failures and `isUnavailable` (`SMCClient.swift:43-50`).
     - `MacBatteryProvider`'s `SMCValueCache` (`MacBatteryProvider.swift:28`) goes behind another
       (WP-14b's cached dictionaries join it later), or the provider becomes an actor if the review
       prefers.
     - No new `@unchecked Sendable` (`SecurityGuardTests` pins four).
     - The synchronous `read(scope:)` stays, so the widget (`BatteryPulseWidget.swift:68-70`) and
       bpulse (`main.swift`, `Record.swift`) keep calling it unchanged.
     - The run decides between two shapes:
       - the `@MainActor` `BatteryProvider` protocol becomes nonisolated, and `IOSBatteryProvider`
         hops to the main actor for `UIDevice` itself;
       - or `MacBatteryProvider` gains a public nonisolated entry, `readNonisolated(scope:)`,
         which the monitor uses now and the widget's async provider in 0.7 (§8.10). The protocol
         (`BatteryProvider.swift:4`) then stays `@MainActor`.

       If the protocol changes, its conformers and callers are adapted.
  2. **The monitor stays `@MainActor`.**
     - `.launch` (exactly one read before `menuBarReady`) and `.manual` (Copy Report,
       `Main/MainView.swift:445-446`, reads `snapshot` straight after) stay synchronous.
     - Every other trigger reads through a `@concurrent` helper and assigns the result in one step
       (UI-2).
     - One read runs at a time, and requests that arrive during it coalesce into one follow-on
       read.
     - Every read carries a generation number that `setOverride` and `stop()` advance. A result
       from an older generation is dropped, such as a read that lands after Demo Mode starts or
       after `stop()`.
     - `HistoryRecorder.recordNow`, already `async`, awaits the read.
  3. **Tests (Linux, manual clock):** a fake provider that suspends, with Demo Mode starting
     mid-read, `stop()` mid-read, two overlapping reads, and coalescing.
- **Files:** `BatteryKit/{MacBatteryProvider, BatteryProvider, SMCClient, BatteryMonitor,
  DemoBatteryProvider, IOSBatteryProvider}.swift`, `App/HistoryRecorder.swift`,
  `BatteryMonitorTests`, `MacBatteryProviderTests`. Also
  `Sources/BatteryPulseWidget/BatteryPulseWidget.swift` and `Sources/bpulse/{main, Record}.swift`,
  only if the protocol's isolation or signature changes.
- **Guards:** `SecurityGuardTests`' `@unchecked` list stays at four.
- **Acceptance:**
  - Linux tests; the golden `bpulse` diff empty; the macOS job.
  - Session A: SPIKE-A2 runs about two hours on the M5 with the `perf` stream on. No executor trap,
    no crash report, and the `read` lines come off the main thread (the `perf` line's thread, or
    the Swift executors track in an `xctrace` recording of SPIKE-A2's profiling DMG; Xcode is
    installed, Q-B7).
  - Session B repeats V-01 on the RC.
- **Gate:** G-14a. **Effort:** M, 2 runs. **Risk:** medium (concurrency in Darwin-only code, which
  only CI compiles).

### WP-14b: The registry only when it changes (E4b), one notify key (E3b) (P1, gated)

- **Source:** PLAN §6 (E4b, E3b; G14, G15), research `energy.md` E4b, E3b and F13; ROADMAP Stage
  1.7.
- **When:** round B1, after Session A has checked the premise. If Session A hasn't run 14 days
  after A2′, B1 starts on the defaults: E4b with the 60-second safety net (G-14b), WP-13 with fill
  (b) on Clear only (Q-B2, G-13a), and E3b keeps both keys (G-14c).
- **Items:**
  1. **E4b's premise (F13), checked first.** powerd posts the public "any" key whenever the
     registry has new data. Session A's ioreg sampler and `pmset -g pslog` test it: every
     `UpdateTime` change in the 10-second samples must have an "any" line within 10 s. If not, E4b
     ships only with a 60-second safety net, or not at all (G-14b).
  2. **E4b's design: two independent decisions per read**, each a pure BatteryCore function tested
     on Linux:
     - **The registry**: the registry, children, IOPS and adapter dictionaries are re-read or
       reused.
     - **The SMC's slow keys**: E4a's `SMCReadPolicy`, unchanged.

     `BatteryReadScope` becomes a struct of the two decisions (or gains a `registry` parameter).
     `.live` and `.full` keep their 0.6.1 meaning for the SMC (`BatteryProvider.swift:26-32`;
     today's choice is `BatteryMonitor.swift:205-210`).

     **One switch:** `RegistryReadPolicy.cachesOnPolls`, a `static let` in BatteryCore (never a
     settings key), turns the registry reuse on or off. With it off, every read re-reads the
     registry exactly as 0.6.1 does. G-14b's "no E4b" is then one commit that sets it to `false`,
     whatever has merged on top (WP-15's moves, SW-13's markers, E20's `Mutex`).
  3. **The registry rule:**
     - Every trigger except `poll` re-reads the registry: `notify`, `followUp`, `launch`, `history`
       (which covers wake), `demo` and `manual`. `RefreshTrigger` has no wake case
       (`Diagnostics.swift:7-21`).
     - A poll re-reads it while a slow-values client is shown, and when the cached registry is
       older than the safety-net age: 5 minutes, or 60 s when F13 failed or wasn't measured
       (G-14b).
     - The slow-values clients are Power and Raw Data (`MainView.swift:248-253`). Power shows
       values that come only or first from the registry and its children: system power in, load,
       adapter loss, charging current and voltage, the not-charging reason, temperature and cell
       voltages (`MacPowerParser.swift:192-217`).
     - The safety net is an age check inside existing reads: no new task and no new sleep, so
       `EnergyGuardTests` is unchanged.
     - E4b saves on the menu bar, panel, compact-window and Overview polls (S2's case). Expected
       on the M5: such a poll goes from about 6.5 ms to about 1 ms.
  4. **A field signal.** When a re-read finds the registry's `UpdateTime` changed although no notify
     arrived since the last re-read, it logs `Diagnostics.event("registry.missed")`, a new event
     name in CLAUDE.md's list. Its count per hour of logged runtime in Session B feeds G-14b
     (pass: at most 1 per hour). SPIKE-A2 predates the event, so Session A answers the same
     question from the pslog and the ioreg samples (F13).
  5. `bpulse` keeps `read()` = everything (frozen output).
  6. **E3b**, one commit, before WP-15 moves the file: drop
     `com.apple.system.powersources.timeremaining` (`MacBatteryProvider.swift:78-81`) and keep the
     comment accurate. Only if Session A's pslog, 2 hours on battery and 1 hour charging, shows
     every `timeremaining` followed by "any" within about 10 ms.
- **Files:** `BatteryKit/{MacBatteryProvider, BatteryProvider, BatteryMonitor, Diagnostics}.swift`,
  a new `BatteryCore/RegistryReadPolicy.swift` (the rule and `cachesOnPolls`),
  `scripts/perf-sample.ndjson` and `.expected` (checked by ci.yml:129), `scripts/perf-stats.swift`
  (a total row per name, so D1 can compare against v0.6.1's `read -`), `BatteryMonitorTests`,
  `SMCTests`, `MacBatteryProviderTests`, a new `RegistryReadPolicyTests`.
- **Guards:** the `read` signpost's trigger names the two decisions, as `StaticString`s (CLAUDE.md's
  signpost list says so):
  - `full`: registry and every SMC key;
  - `live`: registry and the live pair;
  - `cached`: cached registry and the live pair;
  - `cached.slow`: cached registry and every SMC key.

  `SecurityGuardTests` keeps `IOServiceOpen` in `SMCClient` only.
- **Tests (Linux):**
  - Every rule test runs with `cachesOnPolls` on and off; off, every read re-reads the registry.
  - A notify read within 60 s of a full read re-reads the registry, and so does every follow-up.
  - A poll doesn't, unless Power or Raw Data is shown or the cache is 5 minutes old.
  - Merge tests over the M5 fixtures.
- **Acceptance:**
  - Linux tests; the golden diff empty; the macOS job.
  - Session B: `read cached` p50 under 2 ms; F6 shows every page right; plug and unplug within
    0.4's window; at most 1 `registry.missed` per hour of logged runtime.
- **Gates:** G-14b (E4b), G-14c (E3b). **Effort:** M, 2-3 runs. **Risk:** medium (values of different
  ages in one snapshot).

### WP-15: Widget size and the lower target (P1)

- **Source:** PLAN §6 and Appendix C (K-03, G13; "0.6.2 size lever: `-internalize-at-link`";
  SZ-06's attribution; SZ-14), research `size.md`.
- **When:** round B2, after WP-14b merges, because it git-moves WP-14's files.
- **Items:**
  1. **K-03: a lower `BatterySource` target.** The widget depends on it and BatteryCore alone;
     BatteryKit sits on top under its own name, with no `@_exported`.
     - **Contents:** `BatteryProvider`/`BatteryObservation`, `MacBatteryProvider`, `SMCClient`,
       `SystemNotifications`, `IOSBatteryProvider`, `AccessoryProvider`/`MacAccessoryProvider` (so
       0.7's Accessories widget needs no second split), and BatteryKit's `Diagnostics` with
       `Signposts` and `RefreshTrigger`.
     - CryptoKit stays in BatteryKit with `HMACDeviceKeyDeriver` and `UpdateSignatureVerifier`.
     - **Diagnostics:** BatteryKit's `enum Diagnostics` is internal (`Diagnostics.swift:144`) and
       used by files that stay in BatteryKit (`BatteryMonitor`, `AccessoryMonitor`,
       `IDeviceMonitor`, `MobileDevice/MobileDeviceLibrary.swift`). So it becomes `public` in
       BatterySource; ROADMAP rules out `package` access ("`public` stays; no `package` access").
       CLAUDE.md's "an app and a BatteryKit twin" becomes "an app and a BatterySource twin" (WP-22).
     - **Imports:** about 11 source files and 5 test files gain `import BatterySource`:
       - `BatteryKit/{BatteryMonitor, AccessoryMonitor, DemoBatteryProvider, DemoAccessoryProvider,
         IDeviceMonitor, MobileDevice/MobileDeviceLibrary}.swift`;
       - `App/BatteryPulseApp.swift`, `App/Diagnostics.swift` (`Signposts`) and
         `App/HistoryRecorder.swift` (`RefreshTrigger`);
       - the widget, and `bpulse/{main, Record}.swift`;
       - the tests `BatteryMonitorTests`, `AccessoryMonitorTests`, `MacBatteryProviderTests`,
         `MacAccessoryProviderTests` and `DiagnosticsTests`.
     - **Guards move with the files:**
       - `SourceScanner.otherTargets` gains "BatterySource" (`SourceScanner.swift:36`).
       - The allow-list paths `BatteryKit/SMCClient.swift` and `BatteryKit/MacAccessoryProvider.swift`
         (`SecurityGuardTests.swift:43-44, 57`) and `smcClientCallsOnlySelectorTwo`'s path (:157)
         become `BatterySource/…`.
       - A new Linux test checks that the folders under `Sources/` equal `targets + otherTargets`,
         so no future target escapes the guards. `scansEveryTarget` only checks the listed ones.
     - **Test targets:** `BatteryKitTests` gains the `BatterySource` dependency, or a new
       `BatterySourceTests` takes `MacBatteryProviderTests`, `MacAccessoryProviderTests` and
       `DiagnosticsTests`.
  2. **`-internalize-at-link` on the widget:** `-Xswiftc -Xfrontend -Xswiftc -internalize-at-link`
     (a hidden frontend flag in Swift 6.4) on `build-app.sh`'s widget line only, never in the
     manifest.
     - WP-11 measured `__text` 928,452 → 674,756 B (−27 %) in a native build. It is untested with
       Swift Build's prelink and at runtime.
     - Measure it on the app's line too, and adopt it there only with the CI launch smoke and
       Session B's pages (DC-4: nothing reached only through the runtime may be stripped).
  3. **SZ-14** `-dead_strip_dylibs` on the widget and **SZ-11** one LTO experiment: CI numbers
     only; adopt only above 10 % on top of the rest.
  4. **Ceilings:** after the RC, D1 lowers the `widget_*` ceilings to the RC plus about 5 %, in a
     commit of its own that says why, so 0.7's widget growth is visible.
- **Files:** `Package.swift`, the moved files (git moves), the importing files,
  `Tests/BatteryCoreTests/SourceScanner.swift`, `Tests/BatteryCoreTests/SecurityGuardTests.swift`,
  `scripts/build-app.sh` (the widget's line and a linkage check), `scripts/size-budget.json` (D1).
- **Acceptance:**
  - The widget's `__text` and binary size, before and after, in the commit messages. Today, at
    `9410861` (CI run 39751622292): the binary is 1,379,808 B and `__text` 943,096 B.
  - `scansEveryTarget` lists BatterySource, and an `IOServiceOpen` injected into
    `BatterySource/MacBatteryProvider.swift` fails `SecurityGuardTests`.
  - `build-app.sh` fails if `otool -L` of the widget lists CryptoKit.
  - `nm -u` of the widget is recorded for `_dlsym`: informational only, because whether dead
    stripping drops the unused `MacAccessoryProvider` is unverified.
  - For internalize: both lines' build times are recorded; both dSYMs still come from `$BIN_PATH`
    (not `dsymutil`); the app binary's UUID is unchanged by the widget line.
  - The posture check passes and the golden diff is empty.
  - Session A renders the internalized widget (SPIKE-I), and Session B the RC's own widget (F8,
    every family, both languages).
- **Gate:** G-15 (§7.1). **Effort:** M, 3 runs. **Risk:** medium (a widget that doesn't render;
  references only the runtime reaches).

### WP-16: Installer on `diskutil`, attach timing, Check Now (P1/P3)

- **Source:**
  - ROADMAP Stage 1.7;
  - PLAN Appendix C B1, where the hdiutil deprecation warnings were seen on the runner;
  - PLAN §6 (SEC-15, E10);
  - research `security.md` SEC-15 and `energy.md` E10;
  - ROADMAP Stage 1.2 (login item after an update).
- **Items:**
  1. **`UpdateInstallPolicy.attachArguments` and `detachArguments`** (BatteryCore). They start from
     the runner's own mapping, printed by CI run 39751622292's step "Install the way 0.6.0 does,
     then launch":
     - attach: `/usr/sbin/diskutil image attach --mountOptions nobrowse --readOnly --mountPoint
       <dir> <image>`, with the order taken from `diskutil image attach` help, which CI saves to
       Appendix C;
     - detach: `diskutil eject <dir>`.

     Unverified, settled on the runner:
     - an equivalent of today's `-noautoopen` (`UpdateInstall.swift:174-180`, pinned by
       `UpdateInstallTests.swift:205-217`);
     - whether `diskutil eject` of the mount point also detaches the image's own disk (today
       `hdiutil detach` ejected the image's disk while the volume sat on a synthesized APFS
       container).

     Supporting details:
     - Right after attach, `diskutil info -plist <dir>` gives the disk identifier. A BatteryCore
       function parses it, tested on Linux with a fixture captured on CI.
     - **Forced fallback:** `diskutil unmountDisk force <disk>`, then `diskutil eject <disk>`.
       Older `diskutil` usage lists `force` only for `unmount` and `unmountDisk`, not `eject`;
       record the runner's usage text.
     - The app requires macOS 27, and `diskutil image` exists since macOS 26 (ASIF entry of the
       26 release notes).
     - Linux tests pin the arguments. DiskImageKit (new in macOS 27) is no alternative: it covers
       ASIF and raw images for Virtualization.
  2. **The 0.6.1 → 0.6.2 update runs 0.6.1's installer** (`hdiutil`).
     - The CI install-path step keeps 0.6.1's `hdiutil` commands for the shipped contract and is
       renamed "Install the way 0.6.1 does, then launch".
     - It adds a second pass with the new `diskutil` arguments. That pass also holds a file open
       on the volume to exercise the forced path, and checks that no disk image is left attached
       after eject (`diskutil list`).
     - A Linux test checks that the CI pass's arguments equal `UpdateInstallPolicy`'s, so the YAML
       can't drift from the code.
     - Both passes must pass on every macOS run.
  3. **SEC-15:** Session A times `hdiutil attach` against `diskutil image attach` on the real 0.6.1
     DMG, 5 runs each, with and without verification skipping (`-noverify` or its `diskutil`
     equivalent).
     - Adopt the skip only if it saves 100 ms or more. The image is authenticated by digest and
       Ed25519 before it is attached.
  4. **E10 (P3), the remaining half:** Check Now during an automatic check cancels it and starts
     its own check on `UpdateNetwork.user`.
     - Today it waits for the automatic one (`UpdateChecker.swift:83-86`), which Low Data Mode
       refuses at once (`UpdateChecker.swift:205-212`), so the user's Check Now can show a failure
       the user session wouldn't have had. This failure path is inferred from the code, not
       observed.
     - It becomes a Linux-testable decision in `UpdatePolicy` if one is needed.
     - The waiting half is moot since SEC-03 set `waitsForConnectivity = false`.
  5. **Login item after an update (P2, conditional):** only if 0.6.1's after-publishing check shows
     the login item lost.
     - Nothing stores the choice today: the toggle reads `SMAppService.mainApp.status` and
       registers only from the toggle (`App/AppSettings.swift:277-319`), and no key holds it
       (`AppSettings.swift:11-55`).
     - So the toggle also stores the choice in a new key, `openAtLogin`. The key follows the status
       whenever the app reads it (the toggle, launch, becoming active), so a choice made under
       0.6.1, or changed in System Settings, is learned too.
     - On the first launch after a version change (`lastSeenVersion`), before that sync: if the key
       is true and the status is neither `.enabled` nor `.requiresApproval`, the app registers once
       and logs it. A login item already lost by the 0.6.1 → 0.6.2 update can't be recovered.
     - Otherwise WP-22 ticks ROADMAP Stage 1.2.
- **Files:** `BatteryCore/UpdateInstall.swift`, `Updates/UpdateInstaller.swift`,
  `Updates/UpdateChecker.swift` (E10), `App/AppSettings.swift` (item 5),
  `.github/workflows/ci.yml` (the install step), `UpdateInstallTests`.
- **Acceptance:**
  - Tests; both CI install passes.
  - Session B's F12: the RC built as 0.5.99 installs the real 0.6.1 through the `diskutil` path and
    relaunches. F12 runs once, after the script checks GitHub's remaining API requests (Q-B9).
- **Gate:** G-16 (§7.1; default: back to `hdiutil`). **Effort:** S-M, 2 runs. **Risk:** medium (the
  installer first runs for real in 0.6.2 → 0.6.3).

### WP-17: SwiftUI responsiveness on the pages, and the History riders (P2)

- **Source:** PLAN §6 (SUI-07, SUI-11, SUI-12, E19; G17), research `swiftui.md`; `page.switch`
  30-65 ms p50 in §2.1; `history.load day` 51.6 ms and `history.record` p95 11.6 ms; PLAN Appendix
  C B5 (bench B3 inconclusive on Linux).
- **Items, each only where the SwiftUI instrument shows cost:**
  - **SUI-07:** narrow live inputs per subview (Health's identity and capacity sections,
    Overview's static parts) with `Equatable` value inputs. Never move `monitor.snapshot` up to
    `MainView`.
  - **E19:** Raw Data rebuilds only the sections whose source dictionary changed.
  - **SUI-11:** the shorter `ForEach` in the Raw Data table. Drop a per-cell `.help` only if
    measured.
  - **SUI-12:** the vectorized `LinePlot` spike for the power chart, only if the chart updates
    stay orange or red.
  - **History riders:**
    - Rerun bench B3 (`HistoryChartData.make`, 24 h against 7 d, alternated three times) and
      profile `HistoryLoad.read`.
    - Take `history.record`'s p95 from `HistoryRecorder`.
    - Report both in Appendix C. Fix only code in BatteryCore's `HistoryChartData`/`HistoryStore`
      or `Main/History/`.
- **Input:**
  - **Always:** `page.switch` from the `perf` stream, which needs no Xcode. The script names each
    page, the maintainer clicks it, 10 times each (Session A step 8 on SPIKE-A2: before; Session B
    step 5 on the RC: after).
  - **With Xcode (installed on the M5, Q-B7):** the same switches again under Instruments' SwiftUI
    template through `xctrace`. It attaches to the process, which needs a profiling build with
    `get-task-allow` (`build-app.sh:204-219`): SPIKE-A2's and the RC's profiling DMGs (§5 A2′, D1).
    - The script runs `xcrun xctrace record --template SwiftUI --attach BatteryPulse --time-limit
      90s --output <path>` after `xcrun xctrace list templates`, because template names in
      Instruments 27 are unconfirmed.
    - It skips with a note if `xcrun -f xctrace` fails.
  - If the instrument fails, the package does only SUI-11's readability change and the History
    bench.
- **Files:** `Main/{OverviewView, HealthView, PowerView, DeveloperView}.swift`, `Main/History/*`,
  `BatteryCore/{HistoryChartData, HistoryStore}.swift`, `Tests/BatteryCoreTests/Benchmarks.swift`.
- **Acceptance:** `page.switch` p50 over ≥ 10 switches per page, before and after (goal: under
  33 ms, two 60 Hz frames, on every page); body counts per tick before and after, only with the
  instrument.
- **Gate:** G-17 (§7.1). **Effort:** M, 2 runs. **Risk:** low.

### WP-18: Work that needs Xcode on the Mac (P2, maintainer-run)

- **Source:** PLAN §6 (SUI-17, SUI-18, SUI-19, SZ-10; G21); Q-B7 (Xcode is installed on the M5).
- **Items:**
  - **SUI-17:** a 30-minute previews spike. Do previews work in a SwiftPM executable target in
    Xcode 27?
  - **SUI-18:** the SwiftUI Specialist skill exported as a review checklist; nothing from it is
    committed.
  - **SUI-19:** type-check timing of the slowest bodies.
  - **SZ-10:** the Icon Composer icon through `actool`. It changes how the app icon looks in every
    icon style. Decided by delegation (Q-B7): it is prepared and shown in the four icon styles,
    and ships only on the maintainer's y to those screenshots; otherwise it waits for 0.7.
- **Who:** these need Xcode, which is installed on the M5 (Q-B7, 2026-10-22) and which cloud
  sessions don't have. For each item the package prepares a step-by-step list: the commands to
  paste, what to look at, and what to post back on the PR. The maintainer runs it whenever Xcode
  is open; nothing waits for it.
- **Files:** nothing committed, except SZ-10's icon source and an `actool` line in `build-app.sh`,
  only on the maintainer's y to the icon's screenshots.
- **Acceptance:** one Appendix C line per item: previews work, y or n (SUI-17); the type-check ms
  of the 5 slowest bodies (SUI-19); the icon's screenshots in the four icon styles with the
  maintainer's y (SZ-10). SUI-18 leaves only the review checklist.
- **Effort:** S-M of maintainer time. **Risk:** low.

### WP-19: Readability and tooling (P2/P3)

- **Source:** PLAN §6 (SUI-09, SW-21, SW-13, C2, CI pins).
- **Items:**
  - **SW-13 for BatterySource and BatteryKit (P2):** `.strictMemorySafety()` on both targets
    (today only BatteryCore and bpulse have it, `Package.swift:38-45`). Every unsafe IOKit, SMC,
    notify and MobileDevice site is marked `unsafe` with its reason. It runs after WP-15, which
    moves the IOKit, SMC and notify bindings into BatterySource. CLAUDE.md's unsafe-code sentence
    names BatterySource (WP-22).
  - **SUI-09 (P3):** `@State` initialized in one place, kept to `App/`; optionally one
    `AppServices` grouping.
  - **SW-21 (P3):** a DocC build check in CI, only if it costs under a minute.
  - **C2 (P3):** the parser instruction budget, tried once.
  - **CI pins:** review `actions/checkout` v6.1.0 (a lightweight tag on the moving `v6`, with no
    changelog entry at the time) and `upload-artifact` v7.0.2. Move only to a tagged, changelogged
    release, pinned by SHA.
- **Not in 0.6.2:** SZ-08 (only together with glossary work, and none is planned), SEC-10 (no
  evidence).
- **Files:** `Package.swift` (`.strictMemorySafety()` on BatterySource and BatteryKit),
  `Sources/BatterySource/*`, `Sources/BatteryKit/{MobileDevice/*, IDeviceTransport,
  DeviceKeys}.swift` and any other file the compiler flags, `.github/workflows/ci.yml` (pins,
  DocC), `Tests/BatteryCoreTests/SecurityGuardTests.swift` (the escape list); SUI-09 stays in
  `App/`.
- **Acceptance:** 0 warnings on both jobs; every `unsafe` carries a reason comment;
  `SecurityGuardTests`' escape list is updated; each pin is a SHA, with its changelog link in the
  commit message.
- **Effort:** M, 2 runs. **Risk:** low.

### WP-20: Optional security spikes (P3)

- **SEC-08: not run in 0.6.2** (Q-B8, decided by delegation: no). Enhanced Security stays after
  1.0, and is not planned without Developer ID signing and notarization, which need the paid
  account the maintainer declined (M-1, 2026-10-22). The spike's analysis, kept as background: the
  Enhanced Security entitlements on a throwaway build, widget first.
  - Its gate, an in-app update from the published 0.6.1 to a candidate that launches, is possible
    now.
  - On the M5, only memory tagging (checked allocations, soft mode first) and the dyld read-only
    entitlement can be tested without an arm64e build.
  - Platform restrictions need an arm64e slice (a separate `--triple arm64e-apple-macosx27.0`
    experiment).
  - Checked pointer arithmetic (arm64e.x1) needs M6 or later.
  - It would ship only if AMFI accepted the entitlements on an ad-hoc signature, the app and widget
    launched, and V-01 and F8 passed on the build.
- **SEC-18 (research only):** a self-signed code identity for a stable designated requirement
  across updates (login item and notification grants). Without the paid account (M-1: no), it is
  the one route left to grants that survive a DMG replacement; until 0.9.0 weighs it
  (`docs/plans/1.0/ROADMAP.md` §3.5), a lost grant is a documented known limitation.
  - A note for 0.7: it does **not** unlock an App Group. That needs an Apple-issued Team ID in the
    signature or a provisioning profile, and a self-signed identity has neither.
- **Files:** SEC-08's, not used: a new `Resources/BatteryPulse.entitlements` on a throwaway branch
  (the app is signed without one today, `build-app.sh:218`) and `build-app.sh`'s posture check.
  SEC-18 commits nothing.
- **Acceptance:** SEC-18's Appendix C row.
- **When:** SEC-18 in any free slot after B1. **Effort:** S. **Default:** SEC-18 not run; SEC-08
  not run (Q-B8).

### WP-W0: Widget customization spikes (P1 for 0.7's sake; no shipped code)

The unknowns that decide 0.7's design (§8). Every spike lives on `claude/062-spike-widget`, is
never merged, and writes its answer to Appendix C. §8.16 says what 0.7 ships when one fails.

| # | Question | How | Where |
|---|---|---|---|
| W0-1 | Can App Intents metadata reach the widget bundle in a SwiftPM build? | **Partly answered from source:** `swift build` (Swift 6.4) never runs Swift Build's metadata extraction. SwiftPM sets `LM_SKIP_METADATA_EXTRACTION=YES` unconditionally (SwiftPM `release/6.4.0` `Sources/SwiftBuildSupport/SwiftBuildSystem.swift:939-940`), and an executable product isn't a bundle type. Swift Build already emits `*.swiftconstvalues` with the App Intents protocol list. The spike tests only the manual step: `build-app.sh` collects the widget module's `.swiftconstvalues` and Swift sources into file lists, then runs `xcrun appintentsmetadataprocessor` with Swift Build's `AppIntentsMetadata.xcspec` options on the unstripped widget binary. It writes `$APPEX/Contents/Resources/Metadata.appintents` before the widget's `codesign` (`build-app.sh:203`). No new compiler flag (CLAUDE.md: no per-target flags). CI fails if `extract.actionsdata` lacks the intent, because the processor can exit 0 without writing. The spike contains: (a) an `[AppEnum]` parameter with `size: [.systemSmall: 1, .systemMedium: 4, .systemLarge: 8, .systemExtraLarge: 12]`, so compiling against macOS 27.0 settles which overload applies (per-family sizes are macOS 15+, some overloads 27.0 or 27.2); (b) an `AppEntity` parameter whose `EntityQuery` logs when it runs; (c) a `Button(intent:)` whose `perform` logs its process and is followed by a timeline reload; (d) one `ParameterSummary` with a parameter and one `caseDisplayRepresentations`, whose extracted keys are dumped (§8.11) | CI, then Session A |
| W0-2 | Does Edit Widget show the parameters, localized, after strip, `_main`-only exports and `-internalize-at-link`? Does a widget placed by 0.6.1 survive when its kind becomes an `AppIntentConfiguration`, with the Automatic layout? | **Control first:** SPIKE-C (0.6.1's code, version raised) over 0.6.1 with a small and a medium widget placed; `pluginkit -mv -i io.github.nikitausov.BatteryPulse.Widget` and a screenshot before and after. Then SPIKE-I, then SPIKE-W (configurable) over it. The script installs each build the way `UpdateInstaller` does ("Install" below); Install and Relaunch can't reach a spike, because the app fetches only `releases/latest`. Russian edit sheet: see §6. Whether renaming an intent type resets placed configurations is not tested; the names are frozen anyway (§8.13) | Session A |
| W0-3 | Can the sandboxed widget read data the app writes? Three candidates. **A:** `com.apple.security.temporary-exception.files.home-relative-path.read-only` = `/Library/Application Support/io.github.nikitausov.BatteryPulse/Widget/` (leading and trailing slash, as Apple's entitlement reference requires). **A′:** a dedicated preference domain `io.github.nikitausov.BatteryPulse.widgetfeed` (never the settings domain), read through `UserDefaults(suiteName:)` with `com.apple.security.temporary-exception.shared-preference.read-only`. **B:** `notify(3)` state words (64 bits per name, no file, no entitlement). For A and A′, a denial is silent on macOS 27, with no prompt (release notes 161835690 and 178668601); the spike logs the candidate with "feed ok" and the byte count read, or the candidate and its errno (never the path), and also reads data the app wrote while the widget wasn't running. Rejected without a spike: the app writing into the widget's own container. That is another app's data container, denied by default on macOS 27 for a different or absent Team ID (161835690) | SPIKE-W | Session A |
| W0-4 | (1) Can the sandboxed widget read accessory batteries itself (`IOPSCopyPowerSourcesByType(4)` through `MacAccessoryProvider`'s one-shot `read()`)? (2) Which rendering mode does macOS 27 use: on the desktop and in Notification Center, for Appearance → Icon & widget style Default, Dark, Clear and Tinted, each with Desktop & Dock → Dim widgets on desktop = Automatically, the desktop focused and not? (3) Does `showsWidgetContainerBackground` change, and do `redactionReasons` ever say `.privacy`? (4) What does a click deliver? From `NSApplicationDelegate.application(_:continue:restorationHandler:)` the spike app logs the activity type as a case name (`kind` when it equals the widget's kind string, `browsingWeb`, or `other`; an `other` type's raw string goes to the spike app's own defaults for the script, never to the log), the userInfo key names and whether `widgetConfigurationIntent(of:)` returns an intent; from `application(_:open:)`, the route's page ID. It does so with no window open (menu bar only) and with the main window open. (5) Does a `widgetURL` reach the app without a registered URL scheme? | SPIKE-W's widget logs per render; the spike app logs clicks | Session A |
| W0-5 | Accessibility: what does VoiceOver say for today's widget, the bucketed level symbol especially (a 63-87 % charge shows `battery.75percent`, `BatteryPresentation.swift:15-20`)? Does System Settings → Accessibility → Display → Text size change desktop widgets? | VoiceOver on 0.6.1's own widget; the maintainer notes what it says | Session A |
| W0-6 | Time formats: what does `Text(.currentDate, format: .offset(to: end, allowedFields: [.hour, .minute]))` print in English and Russian, and does it change every minute without a reload? | A test kind in SPIKE-W that shows it beside the clock-time line | Session A |

- **Builds:** SPIKE-C (control), SPIKE-I (0.6.1 plus `-internalize-at-link` on the widget), and
  SPIKE-W (the configurable kind plus the test kind, the feed writer and the click logger), all CI
  DMGs.
  - **Order:** dispatch SPIKE-C, then SPIKE-I, then SPIKE-W, so their run numbers increase. CI
    sets `CFBundleVersion` from the run number (ci.yml:135), and WidgetKit caches by it
    (`build-app.sh:112-113`).
  - **Install:** the script refuses a build whose `CFBundleVersion` isn't higher than the
    installed one, except a reinstall of the backed-up 0.6.1. It installs each build the way
    `UpdateInstaller` does (ROADMAP Stage 1.2): copy it next to the app, swap the two with a
    10-line Swift helper beside the script that calls `renamex_np(…, RENAME_SWAP)`, run
    `lsregister -f` on the new copy, relaunch. A plain copy isn't the path 0.7's users take, and
    ROADMAP Stage 1.2 records placed widgets surviving one DMG replacement and not another.
  - **Logs:** spike logs contain only public numbers and case names: the candidate (A, A′, B),
    errno, the byte count read, the userInfo key names and the route's page ID. Never a path, a
    name or a full URL; CLAUDE.md's logging rule holds on a pushed branch too, and a private value
    reads back as `<private>`.
- **Files** (spike branch only): `scripts/build-app.sh` (the metadata step),
  `.github/workflows/ci.yml` (the `extract.actionsdata` check),
  `Resources/BatteryPulseWidget.entitlements`, `Sources/BatteryPulseWidget/*`,
  `App/BatteryPulseApp.swift` (the click logger) and one feed-writer file.
- **Acceptance:** Appendix C holds one answer per row, and §8.16 picks the 0.7 design from them.
- **Effort:** S-M, 3 runs (CI metadata step; spike DMGs; reading the results). **Risk:** none to
  users.

### WP-21: Energy and measurements (P1)

- **Source:** PLAN §4c ("not measured; 0.6.2 session"); ROADMAP Stage 1.6's unticked energy line
  and Stage 1.7's Energy item; Stages 1.4, 1.5, 5 and 6's open energy checks; the energy sentence
  that 0.6.1's notes dropped (`6aaf8ec`); playbook §2 (scenarios S1-S10 and the targets).
- **Items:** extend the session script (`docs/plans/0.6.2/m5-session.sh`, built from the 0.6.1
  script):
  - **Builds:** A = `claude/baseline-0.6.0`, B = v0.6.1's DMG, C = the RC. Each run is 1 minute to
    settle plus 4 minutes of `rusage.swift`, with `caffeinate -d` keeping the display on unless the
    scenario sleeps it.
  - **Setup of every energy run** (playbook §2.3 "Setup"):
    - Every run is on battery. The script refuses to start unless `pmset -g batt` shows Battery
      Power and at least 50 %.
    - It records `lowpowermode` before each run; Low Power Mode is off except in its own run.
    - It asks once per session for: brightness about half, auto-brightness and True Tone off,
      other apps quit, Focus on.
    - In every A, B and C run it records `pmset -g assertions | grep -c BatteryPulse`, which must
      be 0 (playbook §2.3 "Record per scenario" item 1: Preventing Sleep stays No outside an
      install).
  - **Tool check:** `check_tools` points only to https://cli.github.com. The 0.6.1 script's branch
    that names a third-party package manager, and its PATH comment, are dropped
    (`m5-session.sh:44-46, 394-399` at `6aec4d2`).
  - **Session A's window (A and B):**
    - S1 (icon and charge only, no window): A B.
    - S2 (power in the menu bar): A B A B.
    - S2 with Low Power Mode on (6 → 2 reads a minute expected): A B. It needs root for `pmset`:
      the script asks for the password once and keeps the ticket with `sudo -n -v` each minute; if
      the ticket lapses, the run is recorded "not run".
    - S6 (displays asleep with `pmset displaysleepnow`, 10 minutes each): A B.
    - S7: 5 cold launches per build to `menuBarReady`, with the reads before it.
  - **Session A's window, then the A2 build:** SPIKE-A2 with the `perf` stream for about
    110 minutes (E20's field run). `phys_footprint` is taken at its start and end, about 2 hours
    apart. `pmset -g pslog` and the ioreg sampler run all 3 hours.
  - **Session B (C, with B for a same-day pair):**
    - S1: C. S2: B C B C. S2 with Low Power Mode: C.
    - S4w: Overview 5 minutes each in Standard, Translucent and Clear, with Frosted if time allows
      (graduation and G-13c input).
    - S5: the main window covered by a TextEdit window, 5 minutes.
    - S6: C. S7: 5 launches.
    - Burst: 3 unplug and plug cycles, 1 minute apart (S8), hands-on.
    - Memory: History → 7 d three times, `phys_footprint` before and after, hands-on.
    - Devices: an iPhone attached with all windows closed (S9; target under 1 ms/s on average) and
      accessories connected (S10), if at hand.
  - **Pass criteria (playbook §2.7):**
    - S1: wake-ups per hour ≤ 0.6.0, and about 1 read a minute.
    - S2: energy and CPU per hour −50 % against 0.6.0 (E4a, plus E4b if it lands). C against A
      is (C ÷ B in Session B) × (B ÷ A in Session A), per metric. B's figures in the two sessions
      must agree within 15 %, otherwise the result is noise.
    - S6: CPU per hour about equal to S1.
    - S8: 1 read per notify burst, and ≤ 1 widget reload per cycle.
    - Launch: exactly 1 `read` before `menuBarReady`, and p50 ≤ 0.6.0.
    - Memory: no growth across cycles, and the idle footprint ≤ 0.6.0.
    - A difference under 15 % is noise (PLAN §4b), because the runs are shorter than the
      playbook's 30 minutes.
  - **Sleep hygiene (Session B, optional; playbook §2.3 item 7):** after a night with the RC
    installed and the lid closed, `pmset -g log | grep -i -E "DarkWake|Wake from" | grep -i
    batterypulse` must be empty.
  - **Not run, and staying open in Stage 1.4:** S3 (popover open) and the minimized or
    other-Space runs, which need a hand at the keyboard mid-run; the frame-rate check, which needs
    Instruments.
- **Output:**
  - The "Performance baseline (0.6.1 → 0.6.2)" tables in ROADMAP, with energy rows for the first
    time.
  - The 0.6.2 notes' energy line.
  - ROADMAP's "power in the menu bar for an hour" is reworded to the alternated 5-minute runs
    (WP-22).
- **Files:** `docs/plans/0.6.2/m5-session.sh` and its swap helper; one `bash -n` line in ci.yml's
  "Check the verification scripts" step, removed with the folder in D3.
- **Acceptance:** `bash -n` passes in CI, and the `send` comment has a line for every Appendix C
  row the sessions own.
- **Effort:** S-M, 2 runs (script), plus the sessions.

### WP-22: Guards and docs (P1, merges last)

- **Items:** each rule or doc line is conditional on its item and gets one commit (as WP-12 did).
  - **CLAUDE.md:**
    - `BatterySource` in the layout, and "an app and a BatterySource twin";
    - `read`'s four triggers and the `registry.missed` event in the signpost list;
    - E4b's two decisions;
    - E20's isolation (a nonisolated provider; the monitor's `@concurrent` reads);
    - main actor by default for the app;
    - the `diskutil` installer;
    - WindowLook's opaque minimize fill;
    - strict memory safety for BatterySource and BatteryKit.
  - **Guards:** none beyond the packages' own. WP-10 holds the isolation pin, and
    `EnergyGuardTests` stays unchanged because the safety net adds no sleep.
  - **USER_GUIDE:** Clear's known issue removed (if G-13a passes); graduated styles described
    without "beta"; the installer text if it names `hdiutil` anywhere. If E4b lands, one sentence
    in the refresh paragraph (`docs/USER_GUIDE.md:124-132`, which says live values refresh every
    2 seconds): capacities, temperature, cell voltages and adapter details update when macOS
    reports new battery data, and at least every 5 minutes (or the safety-net age that ships);
    Power and Raw Data read them on every refresh.
  - **ROADMAP:**
    - Stage 1.7 ticked, and Stage 1.3's light and dark comparison ticked (V1d).
    - Stage 1.2 ticked if 0.6.1's after-publishing check kept the login item.
    - The window-style Decisions line updated (G-13c).
    - "Performance baseline (0.6.1 → 0.6.2)".
    - Stage 3's "how often the mAh values change", from Session A's ioreg samples; the App Nap
      half stays open.
    - The 0.7 stage with §9.1's phases and CB-02 (D3 adds the link to
      `docs/plans/0.7.0/widgets.md`).
- **Files:** `CLAUDE.md`, `docs/USER_GUIDE.md`, `docs/ROADMAP.md`.
- **Acceptance:** `LocalizationCatalogTests` (its `docs/` scan) is green, and the review confirms
  every new CLAUDE.md line against the merged code with `git grep`.
- **Effort:** M, 2 runs. **Risk:** low.

### D1-D3: Freeze, Session B, release

As PLAN §3.5.
- **D1:**
  - measures (§4a-style Linux benches and code counts against `v0.6.1`);
  - runs the golden, storage and settings diffs. The settings-and-identifiers `git grep` of PLAN
    §5 prints 38 lines at `9410861` (`betaWindowStyles` and an escaped-quote match in
    `scripts/perf-sample.ndjson` are new), and 39 at the RC if WP-16 item 5 added `openAtLogin`;
  - sets the ceilings;
  - drafts the notes (`## What's new in 0.6.2`, checked by CB-06) and opens the draft PR with the
    session checklist. The notes list only user-visible changes, each only if its item landed
    (as PLAN §7 item 2 did):
    - Clear minimizes without a black frame;
    - each style that graduates, or that both stay beta;
    - Check Now no longer fails while an automatic check runs, if E10 lands;
    - Open at login survives updates, if WP-16 item 5 runs;
    - the energy line with the S1 and S2 numbers (WP-21);
    - "Updating from 0.6.1: Install and Relaunch."
  - dispatches the RC as 0.5.99 for F12 and a profiling RC built the way SPIKE-A2's is (§5 A2′;
    Xcode is installed, Q-B7); finalizes the session script.
- **D2** is Session B.
- **D3:**
  - applies the answers or the defaults and records the numbers;
  - before removing the plan folder, moves §8, §9.1, §10's Q-W block with its answers and
    Appendix C's W0 rows to `docs/plans/0.7.0/widgets.md` (English only: `LocalizationCatalogTests`
    scans `docs/`), and links it from ROADMAP's 0.7 stage, so 0.7's plan cites a file that exists;
  - removes `docs/plans/0.6.2/` (and its `bash -n` line in ci.yml) and releases;
  - runs the after-publishing check: PLAN §4b's list at `6aec4d2` with 0.6.2 in place of 0.6.1
    (About shows the new version; History shows the past days; the settings and the menu bar look
    are unchanged; the widget shows a current value; `codesign -dv --verbose=4` shows
    `flags=0x10002(adhoc,runtime)`; `xattr -l` shows no quarantine; `sudo sfltool dumpbtm` still
    lists the login item if it was on; notification permission is kept; on any failure,
    `gh release edit v0.6.2 --prerelease`), plus V-01's post-update half (the widget reloaded
    after the update);
  - in everyday use on the first day, compares the widget's charge and "Lasts until" with the
    popover's (within 2 points and about 15 minutes, `994c09d`);
  - **a week after publishing,** adds DMG and `.sig` download columns to ROADMAP's Releases
    table, fills them for 0.2.0-0.6.1 from `gh api repos/{owner}/{repo}/releases` (§10's counts),
    and records v0.6.2's (`gh api repos/{owner}/{repo}/releases/tags/v0.6.2 --jq '.assets[] |
    "\(.name) \(.download_count)"'`), in a commit of its own. Each in-app install fetches the
    `.sig`, so its count is a privacy-free proxy for in-app updates. The app sends nothing: no
    telemetry is added. Every later release does the same (§10, "Usage evidence").

`WhatsNew.version` stays at 0.6.0 even if a style graduates: a graduation goes in the release notes
only (Q-B5, decided by delegation).

---

## 5. Order and parallelism

At most two agents, and never two packages on one file (mechanical rebase-overs are exempt, as in
0.6.1).

| Round | Slot 1 | Slot 2 | Waits for |
|---|---|---|---|
| A0 | Intake: 0.6.1's after-publishing results (any failure becomes a P1 item) | | the 0.6.1 release |
| A1 | WP-10 | WP-W0's W0-1 (CI metadata step) | A0 |
| A2 | WP-14a (E20) | WP-W0's SPIKE-C, SPIKE-I and SPIKE-W (CI builds on the spike branch) | WP-10 merged (WP-14a edits `HistoryRecorder`); W0-1's answer |
| A2′ | SPIKE-A2: the A2 integration tip plus the Clear fill switch (today's fill or (b), Q-B2), a normal CI build (throwaway branch); the field run, V-01 and the fill recordings need no profiling. Because Xcode is installed (Q-B7), the branch also adds a last step to the macOS job, after "Install the way 0.6.0 does, then launch" (the job's last step today), that runs `PROFILING=1 scripts/build-app.sh` and uploads `build/BatteryPulse-profiling.dmg`; it must come last, because `build-app.sh` starts with `rm -rf build` (`build-app.sh:60`). A profiling build in the package step would fail the job: the signing smoke, the size report and the upload expect `build/BatteryPulse.dmg` (ci.yml:132-171, `size-report.sh:19-20`), and a profiling build writes `BatteryPulse-profiling.dmg` with unstripped binaries (`build-app.sh:31-34, 185-187`) | | WP-14a merged |
| **Session A** | maintainer: about 65 min, then the 3-hour window | | A2′ |
| B1 | WP-14b (E4b, E3b) | WP-13 | Session A (F13, the pslog, the fill recordings), or 14 days after A2′ on the defaults (WP-14b "When") |
| B2 | WP-15 | WP-16 | WP-14b merged (WP-15 git-moves its files and needs `Package.swift` free) |
| B3 | WP-19 (SW-13 on BatterySource's moved files) | WP-17 (with the History riders) | WP-15 merged |
| C1 | WP-21 (script) | WP-22 (merges last) | Phase B |
| D1 | freeze the RC | | C1 |
| **Session B** | maintainer: about 95 min plus about 70 min unattended | | D1 |
| D3 | release | | Session B or its defaults |

- **File ownership:** WP-19's SUI-09 stays in `App/`, and WP-17 in `Main/` and BatteryCore's
  History files.
- **Floating work:** WP-20 (SEC-18 only) takes any free slot after B1. WP-18 runs whenever the
  maintainer has Xcode open, from Claude's step-by-step list, and blocks nothing.

---

## 6. The M5 sessions

Both sessions use one script, `bash docs/plans/0.6.2/m5-session.sh <step>`, built from the 0.6.1
script, with prepare, backup, restore, `send` to the PR and the `perf` log stream.

Every build stays in its DMG, and the script installs it into `/Applications` the way
`UpdateInstaller` does (WP-W0 "Install"), so only `/Applications/BatteryPulse.app` exists and macOS
can't pick up another copy's widget. The wording rules of §3 apply to every question.

**Backup and restore.** The 0.6.1 script kept the first backup for good (`backup_once`,
`m5-session.sh:416-421` at `6aec4d2`), and its restore put back the defaults domain but not
Application Support (`restore_settings` :244-248, `step_restore` :867-876). In 0.6.2:
- Each session's prepare takes a fresh backup into its own folder, `~/bp-062/A` or `~/bp-062/B`.
- Prepare records, and prints: the installed app; the `io.github.nikitausov.BatteryPulse` defaults
  domain; `~/Library/Application Support/io.github.nikitausov.BatteryPulse`; the appearance and the
  wallpaper; `lowpowermode`; and, asked once because the script can't read them reliably, the Icon
  & widget style, Dim widgets on desktop, and whether Open at login is on (it is `SMAppService`
  state, not a defaults key: `App/AppSettings.swift:307-319`).
- Prepare also builds `bpulse` with `xcrun swift build -c release --product bpulse` (`Package.swift`
  needs tools 6.4), next to `perf-stats` and `rusage`. CI uploads only the DMG, the size report,
  the link maps and the dSYMs (ci.yml:165-192), the DMG holds only the app, and the 0.6.1 script
  built only those two tools (`m5-session.sh:211-219`). If the Command Line Tools are older, F5
  records `pmset -g accps -xml` alone, marked "bpulse not built".
- **Restore** (both sessions):
  - reinstalls the backed-up app;
  - runs `defaults delete`, then `defaults import`, for the domain;
  - replaces the Application Support folder with the backup's copy (V-01's Clear History needs
    it; History written during the session goes with it);
  - deletes `…/Widget/`, the `io.github.nikitausov.BatteryPulse.widgetfeed` domain and the
    `AppleLanguages` key in the extension's container preferences;
  - runs `pmset -a lowpowermode <value saved at prepare>` from an EXIT trap, so an interrupted
    session puts it back too (if the sudo ticket has lapsed, it prints the command instead);
  - puts the wallpaper and the appearance back;
  - then prompts for what only a hand can reset: "Turn VoiceOver off (Command-F5)"; "Set Text size
    back"; "Set System Settings → Appearance → Icon & widget style back to <value printed at
    prepare>", and the same for Dim widgets on desktop; "If Open at login was on before the
    session, turn it on again in Settings → General".

### Session A (after A2′; about 65 minutes hands-on, then a 3-hour unattended window)

1. **prepare** (3 min):
   - The script takes Session A's backup into `~/bp-062/A`, records the values above and builds
     `bpulse`.
   - "Is the BatteryPulse widget on your desktop? If not, add a small and a medium one now." A
     screenshot of them is the reference for step 3.
2. **F5** (5 min, on 0.6.1):
   - `bpulse --accessories --raw` (built by prepare) next to `pmset -g accps -xml`, with a
     keyboard on Bluetooth and on its cable, and earbuds in and out of the case.
   - The iPhone page in the packaged app, if an iPhone is at hand: library validation, the Local
     Network prompt, attach and detach.
   - This answers Stage 6's "does macOS 27 hide the accessory list from apps", which W0-4 builds
     on.
3. **Widget spikes** (23 min; W0-2, W0-3, W0-4, W0-6; W0-1's (b) and (c)):
   1. SPIKE-C over 0.6.1. `pluginkit` before and after. "Compare with the picture that just
      opened: 1 same, 2 blank or grey, 3 gone, 4 different (note)."
   2. SPIKE-I over SPIKE-C: the same question for every family (G-15's first input).
   3. SPIKE-W over SPIKE-I:
      - The placed widgets: the same 1-4 question.
      - Edit Widget: the script prints the parameter names it expects; "Are they all there? y/n".
        Then in Russian: the script writes `AppleLanguages (ru)` into the extension's container
        preferences (`~/Library/Containers/io.github.nikitausov.BatteryPulse.Widget/Data/Library/Preferences/`)
        and ends the extension process. Whether the widget and its edit sheet follow is unverified,
        so a miss is recorded as "not checked", never "n".
      - The script reads the spike's log lines: the feed candidates (W0-3), the accessory count
        (W0-4), the entity query and the button (W0-1).
      - Meanwhile: "Note your setting in System Settings → Appearance → Icon & widget style.
        Switch through Default, Dark, Clear and Tinted, with System Settings → Desktop & Dock →
        Dim widgets on desktop on Automatically, clicking the desktop and then a window each time.
        Then set both back." The widget logs its rendering mode per render (W0-4).
      - "Click the date in the menu bar, then Edit Widgets, and add a small BatteryPulse widget.
        Repeat the four styles with Notification Center open." (W0-4)
      - You click the widget with no BatteryPulse window open, then with the main window open
        (W0-4).
      - "Does the test widget show a time left like '2 hours, 13 minutes', in both languages?
        1 yes, 2 with seconds, 3 something else (note)" (W0-6).
      - "Watch the test widget for a minute: did the minutes go down by one? 1 yes, 2 no, 3 it
        shows seconds." (W0-6)
4. **VoiceOver** (4 min; W0-5, on 0.6.1's widget after the script reinstalls it; if a widget is
   blank after that reinstall, remove it and add it again, and note it for W0-2):
   - "Press Command-F5. Click an empty spot of the desktop, then press Control-Option-Right Arrow
     until VoiceOver reads the widget. Note what it says for the battery symbol, or 'not
     reached'. Press Command-F5 again to turn VoiceOver off."
   - "Raise System Settings → Accessibility → Display → Text size. Did the widget's text
     change? 1 yes, 2 no. Then set Text size back to where it was."
5. **V-01 on SPIKE-A2** (12 min; WP-10, WP-14a): the script installs SPIKE-A2 and notes the time.
   - You:
     - "Settings → Notifications → Send Test Notification" (`NotificationSettings.swift:66`),
       and click the banner when it appears. Do it again with the BatteryPulse window in front.
     - The menu bar icon with a light and a dark bar.
     - Raw Data; History; Demo Mode on and off; Check Now; Clear History (your data is backed up).
     - Close the lid for a minute, then open it.
   - The script counts the matches of `log show --start "<prepare time>" --predicate 'process
     BEGINSWITH "BatteryPulse" AND eventMessage CONTAINS[c] "executor"'` and the files under
     `~/Library/Logs/DiagnosticReports/BatteryPulse*` newer than prepare.
6. **Clear's fill** (4 min; WP-13; the fill is decided, Q-B2):
   - On SPIKE-A2, the script sets a hidden defaults key (spike-only, never shipped) to fill (b) for
     Clear, and to today's fill for Translucent Dark.
   - It records each Shift-minimize and restore of Clear Light, Clear Dark and Translucent Dark
     (`screencapture -v`, 6 s), and plays each recording back.
   - For each: "While it shrank into the Dock and came back: 1 like the window, or an even graphite
     grey, 2 a black frame, 3 something else (note)?" A 2 for Translucent Dark extends fill (b) to
     it (WP-13 item 1).
7. **Attach timing** (3 min, unattended): `hdiutil attach` against `diskutil image attach`, with
   and without verification skipping, 5 runs each on the real 0.6.1 DMG. The script also saves
   `diskutil image attach` and `diskutil eject` usage text (SEC-15, WP-16).
8. **Page switches** (14 min; WP-17's before): on SPIKE-A2 with the `perf` stream on, the script
   names each page, you click it, 10 times each. Then, with SPIKE-A2's profiling DMG, the same
   again under `xctrace` (about 10 more minutes; Xcode is installed, Q-B7).
9. **Start the window** (1 min):
   - "Unplug the adapter now and leave the Mac with the lid open."
   - The script asks once for the admin password (the Low Power Mode runs) and once for the
     energy setup (WP-21), and checks that the Mac is on battery with at least 50 %.
   - It starts `caffeinate -i -w <script pid>`, plus `caffeinate -d` during each energy run.
   - It starts `pmset -g pslog` and the ioreg sampler, every 10 s: AppleSmartBattery's
     `UpdateTime` and `BatteryData`'s `RemainingCapacity` (the mAh cadence of ROADMAP Stage 3),
     `PowerTelemetryData`'s `SystemPowerIn`, and the pack entry's `BatteryData` → `Temperature`.
     macOS 27 keeps the temperature there, not in `PowerTelemetryData`
     (`RegistryChildren.swift:53`; the M5 fixtures have no `Temperature` under
     `AppleSmartBattery`).

**The unattended window** (script-driven):
- **0:00-1:10, on battery:** the A/B energy runs (WP-21).
- **1:10-3:00:** SPIKE-A2 with the `perf` stream (E20's field run, memory over about 2 hours).
- **At 2:00:** a sound and an alert, "Plug in the adapter now" (1 minute hands-on). If nobody
  plugs in, the pslog is recorded as battery only, and G-14c keeps both keys.
- **At 3:00:** the script runs restore (above) and `send`, and leaves restore's prompts on screen
  for your return. If a widget is blank afterwards, remove it and add it again.

### Session B (release candidate; about 95 minutes hands-on, about 70 minutes unattended)

1. **prepare** (2 min): a fresh backup into `~/bp-062/B` (above), `bpulse`, then the RC, built as
   0.5.99.
2. **V-01 on the RC** (10 min; WP-10, WP-14a): as Session A's step 5, script-checked.
3. **Beta styles** (35 min; WP-13):
   - The 8 glass-sheet minimize and restore cases (Translucent and Clear × Light and Dark × main
     and compact), each recorded. Standard and Frosted once each next to a minimized Notes window.
     "1 like the window, or an even graphite grey (the chosen fill), 2 a black frame or rectangle,
     3 something else (note)".
   - The screenshot set: 2 wallpapers (bright, busy) × Light and Dark × 3 pages (Overview, History
     with the readout under the pointer, Settings) × Translucent and Clear = 24. The script
     switches wallpaper, appearance and style, and captures the front window (`screencapture -o -l
     <id>`) on Return.
   - The graduation shots (WP-13 item 3), on the bright wallpaper, per beta style × appearance:
     Raw Data with the inspector open; Demo Mode with its bar; History scrolled under the title;
     the main window in full screen (you press Control-Command-F when asked, because a keystroke
     from the script would need Accessibility access for Terminal) = 16. Plus Settings → General
     beside a Clear window in Light, to show the dark appearance stays in its window, and the
     widget gallery behind a Frosted window in Light and Dark: 19 in all, about 5 minutes.
   - The contrast audit with Accessibility Inspector (about 10 minutes; Xcode is installed, Q-B7):
     the script names each beta style, appearance and page (Overview, History, Settings), and you
     run the audit from Claude's step-by-step list and save its report for the script.
   - V1b (scripted): the script opens Settings → General and captures the window (`screencapture
     -o -l <id>`) with Clear unselected and then selected. It compares the tile preview's pixels
     inside the outline; identical pixels pass. You only click the tiles it names.
   - Two plain questions (Q-B2 already chose the fill; Q-B4 says what a style needs first):
     - "From 0.6.2 on, offer Translucent without the Beta window styles setting? y/n."
     - "And Clear? y/n."
4. **F6, F8, F9, F11** (15 min; F11's wait overlaps F6-F9):
   - F11 first: "Plug in the adapter if it isn't." "When charged to" is a picker of 80, 85, 90, 95
     and 100 % (`Settings/NotificationSettings.swift:18-21`), and the alert fires while plugged in
     once the charge reaches it (`BatteryAlerts.swift:70-81`). The script quits the app, writes
     the step to `alertChargeLimit`, deletes the stored `alertState` so the alert starts armed,
     and relaunches. The step:
     - charge 80 % or more: the highest step at or below it, which fires within seconds, as
       0.6.1's F11 did;
     - otherwise the lowest step above the charge, only if the Mac reports charging and that step
       is at most 3 points away; it waits up to 6 minutes for the banner.

     Otherwise, or with no banner in time, F11-alert is recorded as not run.
   - F6: every page on real data (E4b's mixed-age snapshot).
   - F8: the RC's own widget in every family and both languages (G-15). The Russian half uses the
     method Session A confirmed (step 3.3). If none worked, F8-ru is recorded as not checked; the
     widget's strings are unchanged since 0.6.1, and `scripts/string-tables.swift` already checks
     that every translated table has every key. (`WidgetTextBudget`'s length test arrives with 0.7's
     W-1.)
   - F9: Russian (Overview, Settings, the update warning).
   - A relaunch adds one history sample.
   - Login item, in plain words: "Turn Open at login off in Settings → General. Is BatteryPulse gone
     from System Settings → General → Login Items? 1 gone, 2 still listed."
5. **Page switches** (16 min; WP-17's after; WP-13 item 3): on the RC with the `perf` stream on,
   the script names each page, you click it, 10 times each. Then, with the profiling RC (D1), the
   same again under `xctrace` (about 10 minutes; Xcode is installed, Q-B7), followed by 2 minutes
   of the main window in Clear for Clear's shadows, recorded with the template the script picks
   from `xcrun xctrace list templates`.
6. **F12** (5 min; the script first checks GitHub's remaining API requests and asks to turn a VPN off, Q-B9): Check for Updates, then Install and
   Relaunch. The RC's `diskutil` installer installs the real 0.6.1, which relaunches (G-16).
7. **Burst and memory** (10 min, hands-on): 3 unplug and plug cycles, 1 minute apart; History →
   7 d three times.
8. **Energy** (about 70 minutes unattended; WP-21): "Unplug the adapter now." The script asks once
   for the admin password (the Low Power Mode run) and once for the energy setup (WP-21), checks
   that the Mac is on battery with at least 50 %, then runs S1, S2 (B C B C), S2 with Low Power
   Mode, S4w, S5, S6, S7. Devices and accessories (S9, S10) run if at hand.
9. **send**.
10. **restore** (3 min): the restore above, from `~/bp-062/B`. Its prompts include Open at login,
   which F11 turned off.

**Optional, any time** (0.6.0 open checks that stay in their stages):
- the Charge Limit capture, with `bpulse --record` (built by prepare) while charging to the limit
  (Stage 1.1; it also decides §8.5's "why not charging" field);
- sleep hygiene, the night before step 10's restore: with the RC installed and the lid closed
  overnight, the script's `pmset -g log` check (WP-21) finds no wake attributed to BatteryPulse;
- Stage 1.3 (3 min): `scripts/menu-bar-shots.sh` with Increase Contrast and with Reduce
  Transparency, on a display with a notch; the plug state, 100 % on power, and Percentage Inside
  with one, two and three digits;
- Stage 1.4's accessibility pass (2 min each): the Liquid Glass slider at both ends, Reduce Motion,
  Prefer Cross-Fade Transitions, Reduce Transparency, Increase Contrast, Show Borders;
- exported CSV in spreadsheet apps, in a Russian and an English region (Stage 6).

---

## 7. Gates and their defaults; cut line; frozen surfaces

### 7.1 Gates

| Gate | Decides | Measured by | If no measurement comes |
|---|---|---|---|
| G-10 WP-10 | keep the package | V-01 in Session A (SPIKE-A2) and Session B (RC); the CI launch smoke | Fix forward: mark the type or closure the trap names `nonisolated` (or `@Sendable`), in one commit with the macOS job. Revert the merge (`git revert -m 1`) only before B1 starts, because later packages add code that relies on default isolation |
| G-13a Clear's fill | the fill is decided: (b), the graphite composite (Q-B2). The gate decides whether it removes the frame, and whether Translucent Dark takes it too | Session A's recordings and answers; Session B's 8 cases | Ship (b) on Clear; Translucent Dark keeps today's fill |
| G-13b graduation | Translucent and Clear, each | WP-13 item 3's evidence (Session B step 3's shots and contrast audit) and Session B's plain answers. Graduation needs those screenshots answered y and what Q-B4 lists | Stay beta |
| G-13c Low Power Mode | decided: no fallback (Q-B10). The gate only records each style's cost | S4w against Standard | No data: ROADMAP's line reads "none (Q-B10); not measured" |
| G-14a E20 (WP-14a) | reads off the main actor | Session A's field run and V-01 (SPIKE-A2); Session B's V-01 | No M5 run of a build containing E20: before B2, revert E20's commits. After B2 (WP-15 has moved the files, and E4b's caches sit behind E20's `Mutex`), fix forward with one commit that makes the monitor call the synchronous `read(scope:)` for every trigger; a revert then goes in this order: WP-19's SW-13 commits on BatterySource, then E4b's, then E20's. A trap: fix forward as G-10 |
| G-14b E4b (WP-14b) | cached registry on polls | Session A: F13 (pslog against the ioreg samples). Session B: `read cached` p50 < 2 ms, F6 right, plug within 0.4's window, at most 1 `registry.missed` per hour of logged runtime | F13 fails: a 60-s safety net, or no E4b. F13 not measured (Session A, its pslog or its sampler didn't run): E4b ships with a 60-s safety net instead of 5 minutes, and Session B decides by the two Session B criteria, else no E4b. No M5 run of a build containing E4b: no E4b. "No E4b" is one commit that sets `RegistryReadPolicy.cachesOnPolls` to `false` |
| G-14c E3b (WP-14b) | drop `timeremaining` | Session A's pslog, 2 hours on battery and 1 hour charging: every `timeremaining` followed by "any" within ~10 ms | Keep both keys, also when the charging hour didn't run |
| G-15 widget size | K-03 and internalize | SPIKE-I decides whether WP-15 tries internalize; only the RC's own F8 (every family) decides whether it ships | K-03 ships if Session B ran F8 and V-01 on the RC. Without Session B, it ships only as a move with only access and import changes, an empty golden diff and a passing CI smoke (§3's one exception). Internalize ships only with the RC's F8. A blank F8: drop internalize first (one `build-app.sh` line); still blank: revert K-03 with WP-19's SW-13 commits on its files |
| G-16 installer | `diskutil` path | Session B's F12 | Revert to 0.6.1's `hdiutil` code |
| SEC-15 | skip verification on attach | Session A timing: ≥ 100 ms saved | No change |
| SEC-08 | Enhanced Security | not run (Q-B8: no; after 1.0, not planned without notarization, M-1) | Not shipped |
| G-17 | WP-17's changes | `page.switch` from the `perf` stream before and after, ≥ 10 switches per page; the SwiftUI instrument (Xcode is installed, Q-B7) | Only SUI-11's readability change |

### 7.2 Cut line

- **Never cut:** WP-10; SPIKE-A2; WP-13 item 1; WP-14a; WP-14b (unless G-14b's premise fails);
  WP-15 item 1 (K-03); WP-16 items 1-2; WP-W0; WP-21; WP-22; D1-D3.
- **Cut in this order if the budget runs short:** WP-20 (SEC-18; SEC-08 isn't run); WP-19's P3
  items; WP-17; WP-18; WP-15 items 2-3; WP-13 item 5 (item 4 isn't in 0.6.2, Q-B4); WP-16 items
  3-5; WP-19's SW-13. A cut item moves to 0.7.
- **Effort, in runs:**

  | Package | Runs |
  |---|---|
  | WP-10 | 3 |
  | WP-13 | 2-3 |
  | WP-14a | 2 |
  | SPIKE-A2 (the fill switch) | 1 |
  | WP-14b | 2-3 |
  | WP-15 | 3 |
  | WP-16 | 2 |
  | WP-17 | 2 |
  | WP-19 | 2 |
  | WP-20 (SEC-18 only) | 1 |
  | WP-W0 | 3 |
  | WP-21 | 2 |
  | WP-22 | 2 |
  | D1+D3 | 2-3 |

  That is about 29-32 runs plus 3 in reserve (SEC-08 left WP-20 on 2026-10-22, Q-B8). The
  never-cut set is about 22-26. WP-18 is maintainer time, outside the runs.

### 7.3 Frozen surfaces and intended changes

0.6.1's list (playbook §3.4) holds, plus `betaWindowStyles`, including "Widget. Same kind, look
and reload policy."

**Intended, user-visible changes:**
- Clear's minimize fill, (b) (and Translucent Dark's, if its recordings show the frame).
- Any style the maintainer graduates, with the Advanced footer and What's New text reworded
  (`WhatsNew.version` stays 0.6.0, Q-B5). No Low Power Mode fallback comes with it (Q-B10).
- E4b's freshness:
  - If F13 holds, registry values are as fresh as today.
  - If it doesn't, the Power page is unaffected, because it keeps re-reading.
  - Elsewhere, the registry fields (capacities, cycles, temperature, cells, adapter telemetry), and
    a history sample taken right after a cached poll, may be up to the safety-net age old.

**Internal and contract changes:**
- The installer's mount tool. The 0.6.1 → 0.6.2 update itself still uses 0.6.1's `hdiutil`.
- The widget's target graph and size.
- The `read` signpost's triggers and the `registry.missed` event in the `perf` output.
- The settings key `openAtLogin`, only if WP-16 item 5 runs: added, while every existing key keeps
  its name and meaning (`betaWindowStyles` was added the same way in 0.6.1).

**Unchanged:** the widget kind and look, entitlements (SEC-08 isn't run, Q-B8), storage formats,
existing settings keys, `bpulse` output and exit codes, the update assets and keys.

---

## 8. Widget customization: the design (phased: 0.7 MVP, then later)

The maintainer asked for configuration of what the widget shows and what it doesn't, every size,
and anything else worth having, built with 0.6.1's practices. This section is the design. §8.14
lists the packages and §9.1 the phases.

The design rests on five rules:
- pure decisions in BatteryCore, tested on Linux;
- spikes before code;
- frozen identifiers;
- reloads through one planner;
- a placed 0.6.x widget that looks the same after the update.

### 8.1 The widget today

- **Code:** `Sources/BatteryPulseWidget/BatteryPulseWidget.swift` (215 lines).
  - One `StaticConfiguration`, kind `io.github.nikitausov.BatteryPulse.battery`
    (`BatteryWidgetKind.battery`, `BatteryPresentation.swift:115-118`).
  - `systemSmall` shows the charge, the state, and "Full at" or "Lasts until about".
    `systemMedium` adds maximum capacity, cycle count and temperature in a 3-row grid
    (`BatteryPulseWidget.swift:80-150`).
  - `.containerBackground(.fill.tertiary, for: .widget)`, and `widgetAccentable()` on the symbol
    only.
  - Level colours only in full colour.
  - Numeric and symbol content transitions, with opacity under Reduce Motion.
  - No accessibility modifiers, and a fixed 34 pt hero number.
- **Data:** the widget reads IOKit itself (`MacBatteryProvider(readsSMC: false)`), because the
  sandbox can't open the SMC. Ad-hoc signing rules out an App Group, and the paid account that
  would allow one is declined (M-1, 2026-10-22; §8.2), so there is no shared container. It has no
  access to the app's History, devices or settings today.
- **Timeline and reloads:**
  - `WidgetTimelinePlan`: a 30-minute refresh, a 15-minute minimum, and a second entry that drops
    an expired estimate.
  - Reloads come only from `WidgetRefresher` through `WidgetReloadPolicy`. State changes and the
    first estimate reload at once; percent or estimate moves at most every 15 minutes. That is
    about 40 a day in E15's synthetic day, plus one `reloadAllTimelines` after an update.
  - The `widget.reload` triggers are `policy` and `update` (`WidgetRefresher.swift:65, 78`).
- **Packaging:**
  - `build-app.sh` wraps the executable into `PlugIns/BatteryPulseWidget.appex` and copies the
    whole compiled catalog (L118).
  - It signs the extension with `Resources/BatteryPulseWidget.entitlements` (the sandbox only,
    with a "No App Group" comment; `build-app.sh:203`).
  - The posture check fails if the signed entitlements differ from that file or lack the sandbox
    (`build-app.sh:264-301`). It doesn't hard-code a sandbox-only set, so the Linux pin of §8.13
    is what will guard the set.
- **Size:** at `9410861` (CI run 39751622292), the widget binary is 1,379,808 B against a
  1,450,000 B ceiling, and `__text` is 943,096 B against 990,000 B. That is about 47 KB (4.7 %) of
  `__text` headroom.
- **Guards that already cover it:**
  - `MotionGuardTests` scans the widget: no glass, no `repeatForever`, no `TimelineView(.animation…)`
    and no hard-coded animation (`MotionGuardTests.swift:9-14, 168-216`).
  - `EnergyGuardTests` keeps reloads in `WidgetRefresher` (EN-11) and bans `Timer` everywhere.
  - `LocalizationCatalogTests` scans the widget's literals.

### 8.2 What macOS 27 offers (checked against Apple's documentation, 2026-10-22)

| Capability | macOS | Consequence |
|---|---|---|
| `systemSmall`, `systemMedium`, `systemLarge` | 11+ | supported |
| `systemExtraLarge` | 14+ | supported |
| `systemExtraLargePortrait` | **27+** ("on the Desktop on macOS"; WWDC26 session 277) | new; later phase |
| `accessoryCircular`, `accessoryRectangular`, `accessoryInline` | not on macOS | **no accessory families** on the Mac |
| `AppIntentConfiguration`, `WidgetConfigurationIntent`, `IntentCollectionSize` | 14+ | user configuration |
| Per-family array sizes (`IntentParameter` with `size: [IntentWidgetFamily: IntentCollectionSize]`) | 15+ (some overloads 27.0 or 27.2) | W0-1 compiles the one we use |
| `ParameterSummary` `When(widgetFamily:…)` | 14+ | the edit sheet can show different options per size |
| `WidgetRenderingMode` (`fullColor`, `accented`, `vibrant`) | 13+; `widgetAccentedRenderingMode` 15+ | All three apply on the Mac. Which one depends on Appearance → Icon & widget style (Default, Dark, Clear, Tinted) and Desktop & Dock → Dim widgets on desktop (Automatically, Always, Never). Under Clear and Tinted, macOS tints primary and accented content white and removes the background. Notification Center under Clear and Tinted is unverified (W0-4) |
| Interactive `Button(intent:)` and `Toggle(intent:)` | 14+, small to extra large and the portrait size | a perform always reloads the timeline and **doesn't count against the budget** |
| `IntentExecutionTargets` / `allowedExecutionTargets` (`.widgetKitExtension`) | 27+ | intents and entity queries can be kept out of the app process |
| `widgetURL` and `Link` | `Link` in small and larger | one `widgetURL` per widget (more is undefined). A click without a URL delivers an `NSUserActivity` with the kind and family in userInfo, plus `widgetConfigurationIntent(of:)` (14+). URLs reach `application(_:open:)` or `onOpenURL` |
| `SystemFormatStyle.DateOffset` / `.offset(to:allowedFields:)` | 15+ | self-updating time left without seconds: with `[.hour, .minute]`, "1 hour, 5 minutes" |
| Smart Stack relevance (`TimelineEntryRelevance`, `relevance()`) | iOS, iPadOS and watchOS only | **not applicable**; skip |
| `currentConfigurations()` | 15+ | the app can skip reloading kinds no one has placed |
| Reload budget | "typically 40 to 70 refreshes" a day **for a frequently viewed widget**; entries "at least about 5 minutes apart"; a budget per widget; frequent reloads while the app is in front "might be throttled" (WWDC26 session 277) | a desktop widget usually covered by windows may get fewer (§8.10) |
| Push updates (`WidgetPushHandler`) | 26+, needs the push capability (the paid account) | not considered (no paid account, M-1) |
| `privacySensitive(_:)` | 12+ | Apple documents redaction only for the Lock Screen and Always On (iOS, watchOS); no Mac context is documented (§8.8) |
| App Group containers | Allowed only for a Mac App Store app, a `<TeamID>.` group matching the signature's Team ID, or a `group.` ID in a provisioning profile; notarization is no criterion. macOS 27 denies access to other teams' app data and app group containers by default, without a prompt (release notes 161835690) | ruled out: an ad-hoc app has no Team ID, and the paid account that gives one is declined (M-1, 2026-10-22) |

### 8.3 Data sources and the bridge

| Data | Source | Works today? |
|---|---|---|
| Charge, state, estimate, health, condition, cycles, capacities, voltage, temperature (pack sensor), adapter watts, external power, optimized-charging hold, battery power, Mac power use, adapter input, cell voltages (registry and its children) | the widget's own IOKit read | yes |
| Low Power Mode, thermal state | the widget process's `ProcessInfo` | yes |
| Accessory batteries | the widget's own one-shot `MacAccessoryProvider.read()` | **W0-4** |
| History (series, statistics, time on battery) | the app's store | **needs the bridge (W0-3)** |
| iPhone and iPad (last reading) | the app's `devices.json` | **needs the bridge (W0-3)**; MobileDevice never runs in the widget |
| SMC live values (current and voltage within seconds) | the SMC | no (sandbox); not needed at widget cadence |
| Charge limit reached | no source yet (the Charge Limit capture is still open, ROADMAP Stage 1.1) | no |

**The bridge, if W0-3's candidate A works.** The app writes one small file,
`~/Library/Application Support/io.github.nikitausov.BatteryPulse/Widget/feed.json`. The widget's
only new entitlement is read-only access to that folder, never to `Devices/key` or the History
files. The entitlement goes into `Resources/BatteryPulseWidget.entitlements` and its comment. The
posture check passes unchanged, and the Linux pin (§8.13) guards the set.

**Contents:** `WidgetFeed` version 1, at most 8 KB. A Linux test builds the largest possible feed
and checks its size. It holds:
- `writtenAt`;
- `day` and `week` series: a start in UTC and a step of 900 s × 96 or 7,200 s × 84. Each has the
  parallel arrays `percent: [Int?]`, `batteryWatts10: [Int?]` (W × 10), `temperature10: [Int?]`
  (°C × 10) and `plugged: [Bool?]`, from `HistorySample` (`History.swift:12-25`);
- `statistics24h`: `averageDrainPercentPerHour`, `timeOnBattery` and `chargingSessions`, from
  `HistoryStatistics` (`History.swift:217-231, 278`);
- `onBatterySince: Date?`;
- `daily`: up to 90 daily summaries from `HistoryDay` (`History.swift:117`), as a first local day
  and parallel arrays with nulls for missing days: `capacityToDesign10` (× 10, the line of the
  app's "Capacity compared with design" chart, `Main/History/HealthTrendCharts.swift`) and
  `cycleCount`. That is about 1 KB. The largest-feed test decides whether the whole feed still
  fits 8 KB; if not, the limit becomes 12 KB, still well under the reader's 32 KB rejection;
- the remembered devices, at most 8: the `DeviceKey` string as id, name, class, model, charge,
  charging, maximum capacity, cycles and last read time. Never a UDID or serial, and never
  `DeviceKey.demo`;
- accessory levels, only if W0-4 fails.

**Validation:** the reader rejects files over 32 KB, unknown versions, series whose lengths
differ, NaN, and dates more than 10 minutes in the future. It strips control and
bidirectional-override characters from names and caps them at 64 characters. It treats the file as
untrusted input.

**Writes:**
- Atomic, and only when the content changes and a reader kind is placed, at the moments the app
  already reloads widgets: no new wake-ups.
- While the cached `currentConfigurations()` answer says no reader is placed, the app asks again
  at a write moment if that answer is older than 15 minutes. A new widget then gets data within 15
  minutes while the app runs.
- Nothing is written while `monitor.isOverridden` (Demo Mode), as `HistoryRecorder.swift:77` does.
- Clear History, Forget, and turning off device reads or recording rewrite the feed at once,
  placed or not.
- The folder is 0700 and the file 0600, like `Devices/`.

**Candidate A′:** the same payload in a dedicated preference domain, with a read-only
shared-preference exception, if A is denied and A′ isn't.

**If both fail:**
- **Candidate B** (`notify(3)` state words) is not used. It could carry only unnamed numbers (the
  24-hour charge series as packed bytes, and up to two device charge levels without names), which
  anyone can write, and that isn't worth a frozen surface before 1.0 (plan-0.7.0 §2.2).
- **Candidate C: none.** The History and iPhone & iPad widgets are not possible: the only other
  route, an App Group, needs the paid account, which the maintainer declined (M-1, 2026-10-22).
  0.7 ships the Battery and Accessories widgets alone.

**Rejected:** the app writing into the widget's own container, `~/Library/Containers/<widget
id>/Data`. That is another app's data container, denied by default on macOS 27 for a different or
absent Team ID.

### 8.4 Widget kinds and families

| Kind | Families | Phase | Data |
|---|---|---|---|
| **Battery** (keeps today's kind string, so placed widgets stay) | S, M, L, XL; XL portrait later | **0.7 MVP** | own read; History rows from the feed (stretch) |
| **Accessories** | S (the lowest), M (up to four), L (up to eight) | 0.7 MVP if W0-4 passes; else not in 0.7 (later through the feed, only if W0-3 passed) | own read, else feed |
| **History** | M, L, XL | 0.7 stretch | feed |
| **iPhone & iPad** | S (one device), M (two to three), L (up to six) | 0.7 stretch | feed; needs *Read iPhone and iPad batteries* |

Not planned:
- accessory families (macOS has none);
- Smart Stack relevance (not on macOS);
- a Control Center control (the app changes nothing on the system, and the menu bar item already
  opens it);
- push updates, and any network;
- a pager on small widgets: a widget's `UserDefaults` is one domain for every instance, so two
  widgets would page together.

### 8.5 Configuration (the edit sheet)

Defaults reproduce today's widget, so a placed 0.6.x widget looks the same after the update. A
parameter's `default:` is one value for every family (Apple's `IntentParameter` initializers), so
the per-size difference lives in the Layout parameter's "Automatic" meaning. (T) marks a technical
decision, and (L) a look decision, which the maintainer delegated on 2026-10-22 (§10's Q-W
answers); 0.7's look check shows them on sight.

**Battery** (`BatteryWidgetIntent`):

| Parameter | Type | Default | Notes |
|---|---|---|---|
| Layout | enum: Automatic, Custom | Automatic | (T) Automatic is today's widget in small and medium, field for field (`BatteryPulseWidget.swift:80-150` at v0.6.1), and §8.17's layouts in large and extra large. `WidgetLayoutPlan.automatic(size:)` decides it in BatteryCore. A widget placed by 0.6.x gets Automatic |
| Main value | enum: charge, maximum capacity, temperature, battery power | charge | (L) all four offered (Q-W4, decided by delegation) |
| Main visual | enum: number with the level symbol, number with a ring, drawn battery | number with the level symbol (today) | (L) The drawn battery reuses BatteryCore's `BatteryIconLayout`. Its painter (`BatteryIconPainter`, `BatteryIconCanvas`) lives in the app target (`MenuBar/BatteryIconView.swift:9, 215`) and moves (W-3) |
| Status lines | multi-choice: state, time | both | (L) the lines under the main value, as today; not counted as details |
| Details | array of `BatteryWidgetField`, shown only when Layout is Custom (`ParameterSummary` `When(\.$layout, .equalTo, .custom)`). Size per family: small 1 (in place of the time line), medium 4, large 8, extra large 12 | empty | (T) An empty Custom list means no details, never the defaults. The planner keeps the user's order and drops duplicates, the main value and unavailable values |
| Time | enum: clock time, time left | clock time | (L) Clock time: "Lasts until about 16:39", or "… 11:00 tomorrow" when the end falls on a later local day. Time left: `Text(.currentDate, format: .offset(to: end, allowedFields: [.hour, .minute]))`, updated by the system once a minute, never seconds, no reloads. `WidgetTimelinePlan`'s end entry removes the estimate when it ends, so nothing counts up |
| Colours | enum: level colours, monochrome | level colours | (L) Full colour only; accented and vibrant follow the system. Thresholds stay `BatteryPresentation.levelTier`'s 20 % and 10 % and `healthTier`, shared with the menu bar and the app; configurable thresholds are not planned |
| Read time | enum: when old, always | when old | (L) "Updated 14:05", the reading's own `snapshot.timestamp` (never `entry.date`), in place of the last status line. "When old" shows it from the stale entry on (§8.6) |
| History chart | bool, large and up (`When(widgetFamily:)`) | on in large and extra large, from the release that ships the feed; placed large widgets get it too (Q-W4, decided by delegation) | **ships only with the feed (W-5).** It owns the sparkline and the History chart, which are never part of Automatic, and takes the last two detail rows (§8.17) |

**The details field catalogue** (`BatteryWidgetField`, raw values frozen once shipped):

| Field | Source | Phase | Notes |
|---|---|---|---|
| State (Charging, On battery, Fully charged, Charging on hold, Not charging) | own | MVP | a status line by default |
| Time to full or empty | own | MVP | a status line by default |
| Maximum capacity, condition | own | MVP | capped at 100 % like System Settings |
| Cycle count (of rated) | own | MVP | `ratedCycles` fallback as elsewhere. A label plus a number, never a counted phrase |
| Temperature | own | MVP | pack sensor (the SMC fallback isn't reachable from the sandbox); °C (Q-W12: °C kept) |
| Adapter ("USB-C 70 W") | own | MVP | |
| Mac power use (W, `systemLoadWatts`) | own | MVP | how hard the Mac is working, on and off power |
| Battery power in or out (W) | own | MVP | (L) stale between reloads, so shown with the read time (Q-W7: offered) |
| Adapter input (W, `systemPowerInWatts`) | own | MVP | |
| Low Power Mode | own | MVP | |
| Charge in mAh ("3,912 of 4,512 mAh") | own | MVP | remaining of full charge capacity |
| Cycle life used (%) | own | MVP | |
| Cell balance (mV spread) | own | MVP | |
| Voltage | own | MVP | |
| Average drain over the last hour | feed | stretch | only in the release that ships the feed |
| Time on battery since unplugged | feed | stretch | only in the release that ships the feed |
| Why it isn't charging | own | later | only after the Charge Limit capture decodes `notChargingReason`; until then it adds nothing over State |

**Attention row:** a condition other than Normal, or a thermal state of serious or worse, takes the
last detail slot in every family and layout, with a symbol and words. On (Q-W13, decided by
delegation).

**History** (`HistoryWidgetIntent`, stretch):
- period: 24 hours or 7 days;
- series: charge, battery power, temperature; and, over 90 days whatever the period, capacity
  compared with design and cycle count from `daily`, the trend the app's History page draws
  (offered, Q-W2);
- statistics: average drain, time on battery;
- charging spans shaded.

The default is the 24-hour charge, with statistics in large. Every option is filled from feed v1,
so the trend needs no feed v2 later.

**iPhone & iPad** (`DevicesWidgetIntent`, stretch):
- **device:** "Most recently read" (the default), all devices, or a chosen device. A chosen device
  is an `AppEntity` with the `DeviceKey` string as its id, whose `EntityQuery` reads the feed and
  declares `allowedExecutionTargets` `.widgetKitExtension` (macOS 27+). If W0-1's (b) fails, the
  choice is an `AppEnum` only: most recent, lowest.
- **details:** maximum capacity, cycle count, temperature.
- The reading's age is always shown ("2 h ago").

**Accessories** (`AccessoriesWidgetIntent`):
- **MVP:** All, sorted lowest first, or Lowest only. The lowest is the lowest
  `AccessoryBattery.level`, which leaves out the case and offline parts (`Accessory.swift:168`).
  Earbuds per part, as the app shows them. Hiding fully charged ones is a nice-to-have.
  The All/Lowest parameter shows only in medium and large (`When(widgetFamily:)`); small always
  shows the lowest (§8.4).
- **Later: choosing specific accessories**, with an entity id that is never `AccessoryBattery.id`.
  That id can be brute-forced back to a Bluetooth address, and its doc comment allows only two
  copies outside memory (`Accessory.swift:120-130`).
  - The later id is `AccessoryWidgetID`: "acw-" plus FNV-1a 64 of the kind and the name the user
    sees, with an ordinal for duplicates. It is frozen in §8.13.
  - `Accessory.swift`'s comment lists widget configurations as a place where only this id appears.

**Feed-only options:** an option that needs the feed ships only in the release that ships the feed
(W-5). That covers the History chart, Average drain, Time on battery, and the History and
iPhone & iPad kinds. App Intents parameters, cases and summaries are build-time metadata, so an
option can't be hidden at run time, and removing one later breaks frozen raw values.

When the feed is temporarily missing or older than 2 hours (the app not running), a feed-backed
widget shows its last data with dates and one line, "Open BatteryPulse to update".

**Empty and error states** (each is one line of text and an SF Symbol, and a click opens the page
that fixes it; `WidgetLayoutPlan` returns `.empty(reason)`, tested on Linux):

| Kind | State | Shows | Opens |
|---|---|---|---|
| iPhone & iPad | reads off | "Turn on Read iPhone and iPad batteries in BatteryPulse" | Devices intro |
| | on, none remembered | "Connect an iPhone or iPad with a cable" | Devices intro |
| | chosen device forgotten | "This device was forgotten"; the edit sheet offers the rest | Devices intro |
| | feed missing or older than 2 h | the last readings with their dates, plus "Open BatteryPulse to update" | Overview |
| Accessories | none connected | "No accessories with batteries connected" | Accessories |
| | the lowest one went away | the next lowest; all gone: as "none connected" | Accessories |
| Battery | no battery (a desktop Mac) | "This Mac has no battery", plus "Try the Accessories widget" | Overview |
| any | Demo Mode | never shown: the feed builder skips `DeviceKey.demo` and writes nothing while the monitor is overridden | — |

### 8.6 Pure decisions in BatteryCore (tested on Linux)

BatteryCore can't import WidgetKit or App Intents, so it holds mirrors and decisions, and the widget
target maps them one to one.

- **`WidgetSize`** (small, medium, large, extraLarge, extraLargePortrait) and **`WidgetKindID`**
  (the kind strings, today's `BatteryWidgetKind.battery` included).
- **Enums with frozen `String` raw values:** `BatteryWidgetField`, `BatteryWidgetMain`,
  `BatteryWidgetVisual`, `WidgetLayoutMode`, `WidgetStatusLine`, `WidgetTimeStyle`,
  `WidgetColorStyle`, `WidgetReadTimeStyle`.
- **`WidgetLayoutPlan`:** `automatic(size:)` and `make(kind:size:layout:main:statusLines:fields:snapshot:feed:)`.
  - It decides which fields fit which family, in which order. It drops unavailable values (a Mac
    without a pack temperature) and de-duplicates the main value.
  - It adds the attention row, decides whether the sparkline fits, and returns `.empty(reason)`
    states.
  - **W-1's first test:** `automatic(.small)` and `automatic(.medium)` equal v0.6.1's widget,
    pinned before W-3 replaces the view.
- **`WidgetTimeText`:** clock time or time left, and the day.
  - An end on a later local day reads "Lasts until about 11:00 tomorrow", with the new catalog keys
    "Lasts until about %@ tomorrow" and "Full at %@ tomorrow".
  - Tests run in UTC+3 and UTC-8. This edge case is the one intended difference from today's look.
- **`WidgetTextBudget`:** the most characters per slot and family. For example: a small status
  line 24; a medium label 20 with a 9-character value; a large label 26.
  - A Linux test fills each widget key's English and Russian text with its widest value ("12:59
    PM", "−88.8 W", "100 %") and fails over budget, so a long translation is caught in CI, not on
    the M5.
  - The Russian catalog entries for Low Power Mode and Full charge capacity run to 22 characters,
    and for Service Recommended to 26 (`Resources/Localizable.xcstrings`; this file stays English
    only).
- **`WidgetRow`:** values are pre-formatted, and labels stay `LocalizedStringKey`s in the widget
  (localization rule).
  - **Formatter:** the widget's formatter is `BatteryFormatter.widget`, in the widget target. It
    uses `locale: .autoupdatingCurrent` and `UnitSymbols` from the same six catalog keys as
    `BatteryFormatter.app` ("W", "mAh", "V", "mV", "mA", "A"; `App/Localized.swift:15-23`).
    Today's widget uses `BatteryFormatter()`, whose default symbols are English
    (`BatteryFormatter.swift:33-41`), so watts would read "W" in Russian. A Linux source test
    asserts the two symbol key sets are equal.
  - **Units:** watts with one decimal (never mW), grouped mAh, volts with two decimals, and percent
    through `percent(_:)`.
  - **Cycles:** "312" beside the "Cycle count" label, so no Russian plural variations.
- **`WidgetSparkline`:** normalized points, gaps and charging spans, drawn as a `Path` (§8.12).
  **`WidgetChartSummary`:** one VoiceOver label per chart (§8.15).
- **The feed:** `WidgetFeed` (Codable, version 1, §8.3), `WidgetFeedBuilder` (from history days,
  remembered devices and accessories), `WidgetFeedPolicy` (when to write) and the reader's
  validation. Fixtures come from `DemoBattery`, `DemoDevice` and `DemoAccessories`.
- **`WidgetReloadPlanner`:**
  - **Battery:** today's `WidgetReloadPolicy` (`BatteryPresentation.swift:131-137`), plus four
    reasons that reload at once: Low Power Mode flips; the adapter's watts or wireless flag change;
    the condition changes; the thermal state crosses serious, in either direction (the attention
    row's trigger, §8.5), with its own planner test. One more waits for the 15-minute interval: a
    temperature move of 3 °C.
    The planner is the same for every configuration, because the app never reads configurations,
    so a reload a widget doesn't need is accepted.
  - **iPhone & iPad:** a new reading that moved 3 points or changed state, at most every 15
    minutes.
  - **Accessories:** a connect, a disconnect or a 10-point step, at most every 15 minutes.
  - **History:** a plug change, at most hourly.
  - **Day tests:** E15's synthetic day for Battery, bounded by today's bound plus 7; one day test
    per kind; and one with all kinds placed.
- **`WidgetTimelinePlan` per kind:** Battery as today, History 1 hour, devices and accessories 30
  minutes, never closer than 15 minutes.
  - Every timeline ends with a stale entry at reading + 45 minutes (`isStale = true`), which shows
    only if WidgetKit postpones the 30-minute reload. Extra entries cost no reload, and the plan
    keeps at most 3.
  - Tests: the stale entry comes after every planned reload, and the entries stay at most 3.
- **`WidgetRoute` and `PageID`:**
  - `PageID`'s raw values are today's `SidebarItem.storageKey` strings (`overview`, `power`,
    `health`, `history`, `accessories`, `devices`, `device:<DeviceKey>`; `Main/MainView.swift:63-90`).
    `SidebarItem` adopts `PageID`.
  - A Linux test pins the strings, which are also `@SceneStorage("mainSelection")` values.
  - `WidgetRoute(url:)` accepts only known pages and valid `DeviceKey`s.
- **The frozen-value pin test** (§8.13).

### 8.7 Rendering modes, glass, motion

- **Full colour:** level and health colours as today.
- **Accented** (Icon & widget style Clear or Tinted). On the Mac, macOS tints both the accent and
  the default group white and removes the background, so `widgetAccentable()` gives emphasis, not
  colour.
  - The glyph stays in the accent group, as today. The main value stays in the default group, so
    placed widgets look as in 0.6.x.
  - A chart's line is accented, without a gradient fill.
  - Images use `widgetAccentedRenderingMode`: `.accented` for glyphs, `.desaturated` for device
    symbols.
- **Vibrant** (the desktop, per Dim widgets on desktop): hierarchical styles only (`.primary`,
  `.secondary`).
- **In every mode,** a low or critical battery, low health or an abnormal condition is said in
  words or a distinct symbol, never by colour alone. Which mode appears where is W0-4's answer.
- **Glass:** none of ours. The system draws the widget's container, and content stays plain
  (`MotionGuardTests` already flags `glassEffect` in the widget). The container background stays
  `.fill.tertiary`, removable where the system wants it.
- **Motion:** WidgetKit animates between entries; the widget only uses `contentTransition`
  (numeric and symbol; opacity under Reduce Motion).
  - `MotionGuardTests` already covers `repeatForever`, `TimelineView(.animation…)` and hard-coded
    animation in the widget.
  - New rules flag `TimelineView(.periodic…)` and `TimelineView(.everyMinute)`, and
    `Text(…, style: .timer)` and `Text(…, style: .relative)` (which show seconds), in the widget.
  - The only self-updating text is one widget helper that uses a `SystemFormatStyle` date offset
    without `.second`. `EnergyGuardTests` EN-2 already bans `Timer`.

### 8.8 Privacy

- **Names:** device and accessory names get `.privacySensitive()`; the numbers stay.
  - Apple documents the `.privacy` redaction only for the Lock Screen and Always On (iOS, watchOS),
    and no Mac context. The modifier is a cheap defence in case one appears.
  - W0-4 logs `redactionReasons` per render.
- **No hardware-derived identifiers:** no widget configuration, feed or log holds an identifier
  derived from a hardware address or a UDID (§8.5 Accessories).
- **The feed** holds only what the widgets show, in a folder only the user can read, and is
  rewritten without data the user cleared or turned off (§8.3).
- **The widget target's own files** contain no `dlopen`, `dlsym`, `URLSession` or `Network`, and no
  file API outside `WidgetFeedReader` (new `SecurityGuardTests` placements).
  - The one symbol lookup the widget reaches is `BatterySource/MacAccessoryProvider.swift`, the
    allowed file. It only borrows the already loaded IOKit image (`dlopen` with `RTLD_NOLOAD`,
    `MacAccessoryProvider.swift:35-36`).
  - The widget uses only that provider's one-shot `read()`, never its notify registrations
    (`com.apple.system.accpowersources.*`). A source test pins that the widget target calls
    `MacAccessoryProvider.read()` and never `observeChanges(` (`MacAccessoryProvider.swift:46, 58`)
    or `AccessoryMonitor`, whose `start()` registers them (`AccessoryMonitor.swift:39`).

### 8.9 Clicks and interactivity

- **Routing (T):** every widget sets exactly one `widgetURL`, built by `WidgetRoute` from the kind
  and the configuration.
  - **The natural page per kind,** with no "Opens" parameter:
    - Battery → Overview (Health when the main value is maximum capacity; Power when it is
      temperature or battery power);
    - History → History for this Mac;
    - iPhone & iPad → that device's page, or the Devices intro;
    - Accessories → Accessories;
    - an empty state → the page that fixes it.
  - **The app delegate handles it, never a scene modifier,** because the agent app (`LSUIElement`,
    `build-app.sh:105`) usually has no window. `AppDelegate.application(_:open:)` takes the URL,
    and `application(_:continue:restorationHandler:)` takes a kind-only click.
  - **Opening the page:** both call `WindowOpener.showMainWindow(page:)`. That always opens the
    main window for a page; without one it follows `prefersCompactWindow` (`AppSettings.swift:229-231`).
    The page passes through an `@Observable` request, as `DemoController.pageRequest` does
    (`MainView.swift:238-242`).
  - **The app never imports App Intents.** `widgetConfigurationIntent(of:)` would need the intent
    types compiled into the app.
  - **The URL scheme:** if W0-4 shows that a `widgetURL` needs a registered scheme, 0.7 registers
    one in `build-app.sh`'s app Info.plist heredoc (`build-app.sh:87-108`; a new frozen surface).
    It is navigation-only, parsed by `WidgetRoute(url:)` (Linux tests) in one app file
    (`SecurityGuardTests`). A link never acts. Whether a scheme is registered follows W0-4's
    answer, a technical choice (PLAN §8).
  - No per-row `Link`s (a device row opening that device): a click anywhere opens the widget's
    page (Q-W8, decided by delegation); per-row links are an after-1.0 idea (W-9).
- **Buttons (after 1.0, Q-W9; none in 0.7):**
  - Refresh appears only on kinds that read for themselves (Battery, Accessories), together with
    the read time.
  - It is an `AppIntent` whose `perform` returns at once and declares `allowedExecutionTargets`
    `.widgetKitExtension`. It never calls `reloadTimelines`: EN-11 already forbids that outside
    `WidgetRefresher`, and WidgetKit reloads after a perform anyway, outside the budget. That costs
    one IOKit read of about 6 ms.
  - W0-1's (c) shows which process runs `perform`.
  - No button changes system state: the app is read-only. No pager (§8.4).

### 8.10 Energy

- **One read per burst:** one IOKit read per timeline (about 6 ms on the M5), shared across kinds
  and instances that reload together, through `WidgetReadCache`.
  - `WidgetReadCache` is a `Mutex`-guarded final class holding the last reading and an in-flight
    read, so concurrent `timeline(for:in:)` calls within 5 s share one read. WidgetKit calls the
    provider on its own threads.
  - There is no `Task { @MainActor }` hop (`BatteryPulseWidget.swift:50, 56` today) once WP-14a's
    nonisolated entry exists, in either shape (WP-14a item 1).
  - A test feeds N concurrent requests and counts 1 read (manual clock).
  - Accessories use the same pattern over a one-shot `MacAccessoryProvider` read.
- **App reloads:** the app reloads only kinds someone placed (`currentConfigurations()`, refreshed
  as §8.3 says). They go through `WidgetReloadPlanner`, still from `WidgetRefresher` alone (EN-11
  keeps its one call site).
- **Signposts** (CLAUDE.md's list gains them; `perf-stats.swift` prints reloads per kind per
  process):
  - `widget.timeline` in the widget, whose trigger is a `StaticString` per kind (`battery`,
    `history`, `devices`, `accessories`) from a switch over `WidgetKindID`, never the kind string;
  - `widget.feed.write` (app) and `widget.feed.read` (widget) intervals;
  - `widget.reload` keeps the trigger `policy` for the Battery kind (comparable with 0.6.1) and
    adds `policy.history`, `policy.devices` and `policy.accessories`.
- **Targets:**
  - The Battery kind stays within today's E15 day plus 7.
  - All four kinds placed stay under about 100 app-initiated reloads a day, each kind within its
    own budget.
  - The 0.7 session compares the widget's `widget.timeline` intervals with the app's
    `widget.reload` events over a day. If fewer than about 90 % of the requested reloads arrive,
    `WidgetReloadPlanner` drops the percent-step reloads first.

### 8.11 Localization

- **Catalog keys:** every parameter title, enum case name, entity type name, description and
  summary gets a catalog key with its Russian translation, in Apple's terminology (System Settings
  → Battery), following existing entries.
- **Scanned forms:** `LocalizationCatalogTests` learns the App Intents literal forms:
  - `static var title: LocalizedStringResource = "…"`;
  - `IntentDescription("…")`;
  - `@Parameter(title: "…")`;
  - `ParameterSummary`'s `Summary("…")`;
  - `TypeDisplayRepresentation(name: "…")` and `DisplayRepresentation(title: "…")`;
  - `caseDisplayRepresentations` dictionary literals.
- **Placeholders:** W0-1's (d) dumps the keys App Intents extracts for a `Summary` with a parameter.
  If they use a `${name}` form, the placeholder rule gets one explicit, reasoned exception, limited
  to the widget's intent files. CLAUDE.md's "%@ only" rule then names it.
- **Entity titles** are verbatim names (`DisplayRepresentation(title: "\(verbatim: name)")`, or
  the equivalent the spike confirms), never catalog keys, and the test ignores them.
- **No counted phrases:** a label plus a number, so no plural variations.
- **Where intents live:** every App Intents type and its strings live in the widget target, never
  in BatteryCore or another module. An Apple forum thread (developer.apple.com/forums/thread/806804)
  reports intent strings from a Swift package showing raw keys in a widget.
- **Checks:** the widget bundle already gets the compiled catalog. W0-2 checks the Russian edit
  sheet, and `WidgetTextBudget` (§8.6) checks lengths on Linux.

### 8.12 Size

- **Expected growth:** about 100-250 KB of widget `__text` (the kinds' views, App Intents
  conformances, the feed decoder), against about 47 KB of headroom today. 0.6.2's K-03 (about 187
  KB) and `-internalize-at-link` (about −27 % of `__text`) make the room. 0.7 then raises nothing,
  or raises a ceiling in its own commit that says why.
- **Also budgeted:**
  1. `strings_bytes` (251,000), which counts every `.lproj` in both bundles
     (`size-report.sh:108-111`). `build-app.sh` copies the whole catalog into the widget, so each
     new key costs twice. Measure the 80-120 new keys in W-10, before and after, in its commit.
  2. `Metadata.appintents` lands in the appex and counts toward `app_kb`. It gets a new size-report
     row, `widget_appintents_bytes`, with its own ceiling.
  3. Sparklines and History charts are a `Path` from `WidgetSparkline`, not Swift Charts, unless
     W-6 measures Charts under 15 KB of `__text`.
- **Optional (P3):** a widget-only string table. It would roughly halve the widget's `.lproj` but
  changes `string-tables.swift` and the catalog rule, so measurement decides.
- App Intents is a system framework, so no dependency is added.

### 8.13 Frozen surfaces 0.7 creates

- the kind strings;
- the intent, entity and query type names (the system stores a placed widget's configuration
  under them; renaming probably resets it, unverified);
- the parameter names, and every `AppEnum` raw value;
- the entity id formats (the `DeviceKey` string; `AccessoryWidgetID` later);
- each kind's `supportedFamilies` (sizes are only added, because removing one removes placed
  widgets), and the Layout parameter's Automatic meaning per family;
- `PageID` and `WidgetRoute` strings, and the URL scheme if there is one;
- the feed's path and version 1 schema;
- the widget's entitlement set;
- the signpost names and triggers of §8.10.

No test pins any of these today (0.6.1's check was D1's `git grep`). A new Linux test in W-1 pins
them all: kind strings, raw values, routes, the feed path and version, and the key set of
`Resources/BatteryPulseWidget.entitlements`. D1's settings-and-identifiers grep also covers the new
kind strings.

### 8.14 The 0.7 packages

| ID | Package | Depends on | Phase |
|---|---|---|---|
| W-1 | BatteryCore widget model: §8.6's types, planner, time text, text budget, routes, reload planner, frozen-value pins (Linux only) | — | MVP |
| W-2 | Build: the App Intents metadata step in `build-app.sh` (W0-1's route). The macOS job reads the appex's `Metadata.appintents` and fails unless every intent, parameter and `AppEnum` case pinned by W-1 is listed. The size-report rows | W0-1 | MVP |
| W-3 | Battery kind: `AppIntentConfiguration` on today's kind, `AppIntentTimelineProvider` (async, over WP-14a's nonisolated read and `WidgetReadCache`); S, M, L, XL; Layout Automatic and Custom; status lines; read time; rendering modes; empty states; accessibility (§8.15); routing. The drawn-battery painter moves into code the widget compiles: a small SwiftUI-only shared target, or a widget-owned copy drawn from the same `BatteryIconLayout`, with a Linux test on the layout. `MotionGuardTests.menuBarLabelFiles` is updated if the file moves. Gallery previews (`context.isPreview`) use the real reading when there is one; `DemoBattery` only without a battery. A macOS CI step renders each kind × family × language with `ImageRenderer` into PNG artifacts (a review aid, not a gate) | W-1, W-2 | MVP |
| W-4 | Reload planner in `WidgetRefresher` with `currentConfigurations()`, day tests, the energy rule update, the signposts | W-1 | MVP |
| W-8 | Accessories kind (own one-shot read; All or Lowest; previews from `DemoAccessories` when none is connected) | W0-4, K-03's `BatterySource` | MVP if W0-4 passes |
| W-5 | The feed: builder, writer hooks in the app (recorder, device and accessory monitors), reader, the entitlement, the security pins. Linux decoder tests: truncated, oversized, future-dated, wrong-version, mismatched-length and NaN inputs, and names with control or bidirectional characters | W0-3, Q-W3 | stretch |
| W-6 | History kind; the Battery kind's feed fields and History chart | W-5 | stretch |
| W-7 | iPhone & iPad kind (entity query over the feed, or `AppEnum` only) | W-5 | stretch |
| W-9 | Refresh on Battery and Accessories, XL portrait, per-row links, specific accessories, the XL dashboard (Q-W10) | W-3 | later |
| W-10 | Localization, guards (§8.7-8.11), CLAUDE.md, USER_GUIDE's Widget section, ROADMAP | all | MVP (last) |

**Order:** W-1 ‖ W-2; W-3 ‖ W-4; W-8; W-5; W-6 ‖ W-7; W-9; W-10 last. CB-02 (device JSON dates as
ISO 8601) runs alongside in any slot that doesn't touch `bpulse`'s files.

**The 0.7 session checks:**
- a 0.6.x widget after the in-app update;
- every kind × family × rendering mode, in English and Russian, at 12-hour and 24-hour time;
- the edit sheet;
- VoiceOver;
- clicks with and without a window;
- a day's reloads requested against delivered;
- the widget's energy;
- the feed's contents.

### 8.15 Accessibility

- **One element per block.** Each block is one VoiceOver element (`accessibilityElement(children:
  .combine)`) with a label built from the formatted strings, for example "Battery, 70 %, On
  battery, lasts until about 16:39".
  - The level symbol is `accessibilityHidden(true)`: its bucket (75 % for 63-87 %) can contradict
    the number.
  - Each detail row reads "label, value". A device or accessory row reads "name, 45 %, charging".
- **Charts** get one summary label from BatteryCore (`WidgetChartSummary`, for example "Charge, last
  24 hours: 92 % to 41 %, charged twice"), never per-point elements.
- **Colour is never the only signal** in any rendering mode (§8.7).
- **Text** uses text styles, except the hero number, which keeps a `minimumScaleFactor(0.7)`.
  - Labels and status lines use `lineLimit(1)` plus `minimumScaleFactor(0.8)`, then a tail
    truncation.
  - Values never truncate (`fixedSize()`, `monospacedDigit()`), and the planner drops a row rather
    than cut a value.
- **Checks:**
  - W0-5 in 0.6.2 (what VoiceOver says today; whether Text size reaches desktop widgets,
    unverified).
  - The 0.7 session: VoiceOver on a desktop widget in each family and both languages; Increase
    Contrast and Reduce Transparency.

### 8.16 If a spike fails

| Spike result | 0.7 then ships |
|---|---|
| W0-1: the manual `appintentsmetadataprocessor` step gives no working edit sheet | No configuration. Presets as separate `StaticConfiguration` kinds, each a fixed `WidgetLayoutPlan`: Battery (today's kind and look, plus large and extra large), Battery Health (maximum capacity, condition, cycles of rated, full charge capacity) and Power (adapter, battery power, Mac power use, temperature, Low Power Mode). W-2 is dropped, with no App Intents anywhere |
| W0-1 (b): entity queries don't run from the ad-hoc extension | iPhone & iPad uses an `AppEnum` (most recent, lowest); no chosen device |
| W0-1 (c): button performs don't run | No buttons (W-9's Refresh dropped) |
| W0-2: the control keeps placed widgets, but the configurable kind loses them | Today's kind stays static (today's look, new sizes). The configurable Battery widget ships as a new kind `io.github.nikitausov.BatteryPulse.battery.custom`, and the release notes say how to switch |
| W0-2: the control loses placed widgets too | The loss comes from updating an ad-hoc app, not from configuration (ROADMAP Stage 1.2 is still open). Proceed as designed; the release notes say "add the widget again if it's gone", as 0.4's did. With no signed build coming (M-1: no), it stays a documented known limitation |
| W0-3: A and A′ fail | No History or iPhone & iPad widgets (§8.3 candidate C); candidate B isn't used |
| W0-4: accessories can't be read from the sandbox | No Accessories kind in 0.7 (plan-0.7.0 §2.2, G7-8); later through the feed, only if W0-3 passed |
| W0-4: `widgetURL` needs a registered scheme | Register a navigation-only scheme (§8.9); no per-row links (Q-W8) |
| W0-6: the offset format shows seconds or misbehaves | Time left is dropped from the Time parameter; clock time only |

### 8.17 Layouts

- **Small (Automatic):** today's widget: the level symbol and number, then the state and time lines.
- **Medium (Automatic):** today's widget: the charge block plus maximum capacity, cycle count and
  temperature.
- **Large (Automatic):** the charge block and 8 details in two columns: maximum capacity, cycle
  count, temperature, adapter, Mac power use, battery power, Low Power Mode, charge in mAh.
- **Extra large (Automatic):** a bigger Battery: the charge block and those 8 details plus voltage
  and cycle life used (10). Q-W10, decided by delegation: extra large ships in 0.7 only if 0.7's
  look check shows its layout right (`docs/plans/0.7.0/PLAN.md` §14 draws it as two panels,
  Battery and Power); otherwise it comes later, which never touches placed widgets. The dashboard
  (Mac, History, devices, accessories) and the portrait size come after 1.0.
- Q-W7 keeps battery power (offered, with the read time), so cell balance stays a Custom detail.
- **The sparkline and the History chart are never part of Automatic,** so Automatic's meaning per
  family stays frozen (§8.13) when the feed ships. They belong to the History chart parameter
  (§8.5), which defaults on in large and extra large from the release that ships the feed and
  takes the last two detail rows.
- **Every family and every layout:** the attention row (§8.5) when it applies.

---

## 9. Recommendation: widget customization in 0.7, not 0.6.2

**Put it in 0.7, and use 0.6.2 to remove its risks.**

1. **0.6.1's frozen list says "Widget. Same kind, look and reload policy."** (playbook §3.4), and
   0.6.2 keeps that list (§3, §7.3). Configuration changes all three.
2. **The unknowns need the Mac before the design is final.**
   - Without App Intents metadata the edit sheet is empty, and SwiftPM doesn't produce it by itself
     (W0-1).
   - Can the sandboxed widget read anything the app writes under ad-hoc signing on macOS 27?
   - Can it read accessories itself?
   - Do placed widgets survive the move from a static to a configurable kind?

   0.6.2's Session A answers these on throwaway builds, with a control.
3. **0.6.2 already changes the widget three ways:** a new target graph (K-03),
   `-internalize-at-link`, and the read path it shares with the app (E4b, E20). Adding
   configuration, a build step and an entitlement to the same release would make a blank widget
   impossible to attribute.
4. **The project's own conventions:** "within a minor release … the storage formats, the settings
   keys and the update contract don't change" (ROADMAP, frozen outputs). 0.6.1's playbook allows
   no new on-disk file "unless a later release decides so". The bridge is a new file and a new
   entitlement, and the intents' identifiers become new frozen surfaces. That is a minor version.
5. **Size:** the widget has 4.7 % of `__text` headroom today. K-03 and `-internalize-at-link` make
   room for 0.7's views without raising ceilings.
6. **0.7 is otherwise light:** CB-02 is one change with a release-notes line, so widgets can be
   0.7's headline, with their own M5 session.

**Decided (Q-W1, the maintainer, 2026-10-22): 0.7, with no 0.6.3.** The one low-risk slice that
was considered, large and extra-large sizes of today's static Battery widget in a 0.6.3, is not
planned. It would have needed no configuration, no App Intents and no new file, but it is still a
feature in a maintenance release.

### 9.1 Phases

| Phase | Contents | Gate |
|---|---|---|
| 0.6.2 | WP-W0: W0-1 to W0-6 with the SPIKE-C control; K-03 and `-internalize-at-link` for headroom; WP-14a's nonisolated read, which the widget's async provider reuses | none: throwaway builds |
| 0.7 MVP (never cut) | W-1, W-2, W-3: Battery in S, M and L (XL only on the look check's yes, Q-W10); Layout Automatic or Custom; status lines; read time; natural-page clicks; empty states; accessibility. Also W-4, W-8 (Accessories, All or Lowest; if W0-4 passes) and W-10 | W0-1, W0-2 (§8.16 otherwise) |
| 0.7 stretch, else 1.1 (`docs/plans/1.0/ROADMAP.md` §3.2) | W-5 (feed), W-6 (History; Battery's feed fields and chart), W-7 (iPhone & iPad) | W0-3 (Q-W3: yes). If W0-3 fails, not possible without the paid account (M-1: no; §8.3 candidate C) |
| Later | Refresh, the extra-large dashboard, extra-large portrait, per-row links, specific accessories, "why it isn't charging" after the Charge Limit capture | after 1.0 for the widget extras (Q-W2, Q-W8 to Q-W10, decided by delegation); the cause after the capture |

---

## 10. The maintainer's questions and their answers (2026-10-22)

The maintainer answered on 2026-10-22. Q-B2, Q-B7 and Q-W1 are his own answers, and Q-W3 follows
from his answer to M-1. He delegated every other question ("do it by best practices, as you see
fit"), so each is recorded with its recommended answer and marked "decided by delegation". Q-B9 and
Q-B11 were settled before. No question of this plan stays open; what the maintainer still judges on
sight in the sessions is listed in §3. The road-to-1.0 questions (M-1 to M-14) are in
`docs/plans/1.0/ROADMAP.md` §6, and 0.7's own (Q7-1 to Q7-8) in `docs/plans/0.7.0/PLAN.md` §14.

**M-1, the paid Apple Developer Program account: no,** not now and not planned before 1.0 (the
maintainer, 2026-10-22). It is a non-commercial hobby project, with no budget for the account and
about zero users (below). For this plan:
- Developer ID signing and notarization stay not planned, and nothing in 0.6.2 waits for a signed
  build.
- No App Group: the History and iPhone & iPad widgets can only use the feed (W0-3, §8.3), and
  without it they aren't possible (§8.3 candidate C).
- No Enhanced Security spike (WP-20, Q-B8).
- Open Anyway on each DMG install, and grants or placed widgets possibly lost when a DMG replaces
  the app, stay documented known limitations (§8.16, WP-20's SEC-18).

**Usage evidence** (GitHub's REST API, 2026-10-22):
- DMG downloads across all releases: 14 in total (0.2.0: 1, 0.3.0: 2, 0.3.1: 4, 0.4.0: 1, 0.5.0:
  2, 0.6.0: 3, 0.6.1: 1, the last being a signature check during the release).
- Signature (`.sig`) downloads: 5. Each in-app install fetches the `.sig`, so its count is a
  privacy-free proxy for in-app updates.
- Repository page views: 2, by 1 visitor, in 14 days. No stars, forks or outside issues.
- A re-check later the same day showed 15 DMG and 6 `.sig` downloads: one more of each for 0.6.1,
  as one in-app update fetches.

So the users are, in effect, the maintainer alone. 0.6.2's scope stays as planned, because its
sessions measure the Mac the app runs on. From 0.6.2 on, each release records its DMG and `.sig`
download counts a week after publishing (D3), with no telemetry in the app.

### For 0.6.2

- **Q-B2 (Clear's fill): (b), the graphite composite** (the maintainer). Asked: pick one of three
  recorded fills, or a fill that follows the desktop picture. Session A's recordings check (b), and
  whether Translucent Dark needs it too (§6 step 6). The desktop-picture variant isn't built
  (WP-13 item 1).
- **Q-B4 (beta styles), decided by delegation: both stay beta until the maintainer signs one off**
  in Session B step 3, each style on its own, so Translucent may graduate before Clear. Asked:
  what still looks wrong in Translucent and Clear, what must be fixed before a style leaves beta,
  and whether Translucent may go first.
  - Before a style leaves beta: no black frame in its recorded cases (WP-13 item 1); an identical
    tile preview (V1b); no confirmed text-contrast failure in the audit; and every shot of its
    screenshot and graduation sets answered y. Clear's sidebar and toolbar, and contrast over
    bright or busy wallpapers, are judged in those shots.
  - The Stage 1.5 leftovers (thicker chart lines, the Raw Data table's treatment) are not done in
    0.6.2. A shot answered n for them keeps that style beta, and item 4 waits for a beta style's
    graduation, after 1.0 (FEA-25; `docs/plans/1.0/ROADMAP.md` §4.1; plan-0.7.0 C-1).
- **Q-B5, decided by delegation: the release notes only.** Asked: announce a graduated style in
  What's New, or only in the release notes? `WhatsNew.version` stays 0.6.0, so the window doesn't
  reopen; What's New feature 3's text is reworded with the graduation (§3).
- **Q-B6 (sessions), decided by delegation: the sessions as written,** with the Xcode items that
  Q-B7 adds. Asked: are the lengths OK, and which energy scenarios matter most?
  - Session A: about 65 minutes, then 3 unattended hours on battery and charging. The maintainer
    plugs the adapter in once, at the 2-hour mark, and types the admin password once, for the Low
    Power Mode runs.
  - Session B: about 95 minutes plus about 70 unattended, with the admin password once more.
  - Energy scenarios in the order they run: power in the menu bar (S2) first, then the window
    styles (S4w), then an iPhone attached and accessories (S9, S10) if at hand.
- **Q-B7 (Xcode): installed on the M5** (the maintainer). `xctrace` (WP-17; Session A step 8,
  Session B step 5), the contrast audit and Clear's shadows (WP-13 item 3; Session B steps 3 and 5)
  and every WP-18 item run, maintainer-run from Claude's step-by-step list; no step depends on
  whether Xcode is there any more. The Icon Composer icon (SZ-10), decided by delegation: prepared
  in WP-18 and shown in the four icon styles; it ships only on the maintainer's y to those
  screenshots, otherwise it waits for 0.7.
- **Q-B8, decided by delegation: no.** Asked: is the Enhanced Security spike (SEC-08) worth a
  session step? It isn't run in 0.6.2 (WP-20). Enhanced Security on an ad-hoc signature is
  unverified, an update that AMFI refused would leave an app that doesn't launch, and it stays
  after 1.0, not planned without notarization (M-1: no).
- **Q-B9 (F12), settled:** the first try failed on GitHub's limit of 60 unauthenticated API requests an hour per address, used up behind a VPN that shares its address; the app said "GitHub is limiting requests", and the re-run after the limit reset passed. Not a defect; Session B's script
  checks the remaining requests (`api.github.com/rate_limit`) before F12 and asks to turn a VPN
  off, and F12 runs once.
- **Q-B10 (Low Power Mode), decided by delegation: no fallback.** Asked: if Translucent or Clear
  uses 15 % or more energy than Standard, should it give way to Standard while Low Power Mode is
  on? A window style is the user's explicit choice, Reduce Transparency and Increase Contrast
  already give Standard, and Low Power Mode already slows the polls (`LiveRefreshPolicy`). S4w
  still measures each style, and ROADMAP's decision line records the numbers (G-13c).
- **Q-B11 (branches), settled (an engineering call):** `claude/baseline-0.6.0` (`076873d`) stays
  until 0.6.2's D3 for build A; 0.6.1's integration history stays reachable as `refs/pull/11/head`
  (see the header), so `claude/nice-faraday-k08mhb` needn't be kept.

### For widget customization (0.7)

- **Q-W1 (when): 0.7** (the maintainer), in the phases of §9.1, with no 0.6.3 of large and
  extra-large sizes of today's static widget. 0.6.2 itself stays at spikes (§1, §7.3).
- **Q-W2 (kinds), decided by delegation: all four kinds as §9.1 phases them.** Battery and
  Accessories in 0.7; History and iPhone & iPad with the feed (stretch), the History widget
  offering the 90-day capacity and cycle-count trend. Choosing specific accessories comes after
  1.0. No Battery Health and Power presets, unless configuration turns out impossible (§8.16).
- **Q-W3 (the bridge): yes** (2026-10-22, following M-1: no). BatteryPulse keeps a small copy of
  the last day, week and device readings for the widgets, in its own folder (the feed, §8.3; its
  entitlement is a W-5 detail), if W0-3's candidate A or A′ works. If W0-3 fails, the History
  and iPhone & iPad widgets aren't possible without the paid account (§8.3 candidate C).
- **Q-W4 (look), decided by delegation:**
  - main visual: the number with the level symbol by default (today's), with a number with a ring
    and a drawn battery like the menu bar icon styles offered;
  - main values: charge (the default), maximum capacity, temperature and battery power, all
    offered;
  - level colours by default;
  - large and extra large: §8.17's details, which 0.7's look check shows on sight;
  - when the feed ships, placed large widgets get the History chart in place of their last two
    rows (the parameter's default).
- **Q-W5 (time), decided by delegation:** clock time by default ("Lasts until about 16:39", as
  today), with time left ("2 hours, 13 minutes") offered if W0-6 passes.
- **Q-W6, decided by delegation:** "Updated 14:05" only when the widget is old, by default, with
  "Always" offered.
- **Q-W7, decided by delegation:** battery power in watts is offered, always shown with the read
  time.
- **Q-W8 (clicks), decided by delegation:** a click anywhere opens the widget's page (Overview,
  History, the device, Accessories; §8.9). Per-row links are an after-1.0 idea.
- **Q-W9, decided by delegation:** no Refresh button in 0.7; after 1.0 at the earliest, and only if
  W0-1 (c) shows that performs run.
- **Q-W10, decided by delegation:** extra large in 0.7 only if 0.7's look check shows its layout
  right (`docs/plans/0.7.0/PLAN.md` §14: two panels, Battery and Power); otherwise later, which
  never touches placed widgets. The dashboard and the portrait extra-large size: after 1.0.
- **Q-W11, decided by delegation:** iPhone and iPad names are shown, with `.privacySensitive()`.
- **Q-W12, decided by delegation:** °C everywhere, as today. A unit that follows the region would
  change the app and the widget together, never one alone, and isn't planned.
- **Q-W13, decided by delegation:** the attention row (a condition other than Normal, serious heat)
  is on in every family. "Off by default" would need a frozen parameter, so the choice was on or
  never.

Technical choices are made in the runs by Apple's practices and these rules, as PLAN §8 delegated.
They include configuration through App Intents, the BatteryCore planner, the feed format, the
reload planner, routing, tests and guards, and size sequencing.

---

## Appendix A: traceability of every carried item

Sources: ROADMAP at `9410861`; PLAN, playbook, research and audits at `6aec4d2`; PR 11's session
comments.

| Item | Source | 0.6.2 package or status |
|---|---|---|
| SW-04 with V-01 (main actor by default) | PLAN §3.1, §6; ROADMAP 1.7 | WP-10 (V-01 in both sessions; the post-update half in D3) |
| Clear's minimize fill (UR-3) | maintainer's settled report; 0.6.1 D3 (known beta issue) | WP-13 (fill (b), Q-B2) |
| Beta styles graduation | 0.6.1 D3 (`1f9937b`) | WP-13 |
| Low Power Mode fallback for window styles | ROADMAP Decisions ("until the energy is measured") | none (Q-B10); S4w records each style's cost (WP-21, G-13c) |
| V1b | 0.6.1 session | WP-13 |
| V1d (menu bar icon, light and dark) | 0.6.1 session (y) | WP-22 ticks Stage 1.3's comparison |
| Stage 1.3's other open items: the icon styles on the M5, the drawn exact-level battery, Increase Contrast, Reduce Transparency and the notch, the 0.6.0 rework checks (the plug, 100 % on power, Percentage Inside with 1-3 digits) | ROADMAP 1.3 | Session B optional; otherwise they stay open |
| Stage 1.5's open check (chart lines and Raw Data treatment on the sheet, full screen, contrast audit, inspector and Demo Mode bar, scroll edge, Form fills and stripes, Clear's dark appearance, Frosted next to the widget gallery, Clear's shadows, energy per style) | ROADMAP 1.5 | WP-13 item 3 (evidence, with the contrast audit and Clear's shadows: Xcode is installed, Q-B7), WP-21 (S4w); the chart lines and Raw Data treatment (item 4) not in 0.6.2 (Q-B4); what Session B doesn't reach stays open |
| E20 | PLAN §6, G16 | WP-14a |
| E4b | PLAN §6, G14 | WP-14b (gated on F13) |
| E3b | PLAN §6, G15 | WP-14b (gated) |
| `history.load day`, `history.record` tail | PR 11 perf block; PLAN Appendix C B5 (B3 inconclusive on Linux) | WP-17 riders |
| K-03 | PLAN §6, G13, Q6 | WP-15 |
| `-internalize-at-link` | PLAN Appendix C (C1) | WP-15 |
| SZ-11, SZ-14 | PLAN §6, G21 | WP-15 (experiments) |
| `diskutil` installer | ROADMAP 1.7; PLAN Appendix C (B1); CI run 39751622292's warnings | WP-16 |
| SEC-15 | PLAN §6, G18 | WP-16 + Session A |
| E10 (remaining half) | PLAN §6; research `energy.md` E10; SEC-03 | WP-16 (P3) |
| In-app install (Stage 1.2): tick it on F12 and 0.6.1's after-publishing check; re-register the login item after an update | ROADMAP 1.2 | WP-22 ticks it if the login item was kept; else WP-16 item 5 |
| 0.6.1 after-publishing results (widget, login item, notifications, first-day widget accuracy, `994c09d`) | PLAN §4b | intake A0: any failure becomes a P1 item |
| SUI-07, SUI-11, SUI-12, E19 | PLAN §6, G17 | WP-17 |
| SUI-17, SUI-18, SUI-19, SZ-10 | PLAN §6, G21 | WP-18 (maintainer-run from Claude's step-by-step list; Xcode is installed, Q-B7) |
| SUI-09, SW-21, SW-13 (now BatterySource and BatteryKit), C2 | PLAN §6 | WP-19 |
| CI pins (checkout v6.1.0, upload-artifact v7) | ROADMAP 1.7; PLAN Appendix C (B6) | WP-19 |
| SEC-08 | PLAN §6, G20 | not run (Q-B8: no); Enhanced Security is after 1.0, not planned without notarization (M-1: no) |
| SEC-18 | PLAN §6 | WP-20 (research) |
| SEC-10 | PLAN §6, G19, Q1 | not in 0.6.2 (no evidence) |
| SZ-08 | PLAN §6 | not in 0.6.2 (no glossary work) |
| S1, S2, S4w, S5, S6, S7, S8, memory, S9, S10 | PLAN §4c; ROADMAP 1.4, 1.5, 1.6, 1.7, 5, 6; playbook §2 | WP-21; A/B in Session A, C in Session B |
| S3 (popover), the minimized and other-Space runs, frame rate (Instruments) | ROADMAP 1.4 | stays open in Stage 1.4 |
| Sleep hygiene (playbook §2.3 items 1 and 7) | playbook §2.3 | WP-21 (assertions in every run; the overnight check is Session B optional) |
| Stage 1.4 legibility and accessibility pass | ROADMAP 1.4 | Session B optional; otherwise stays open |
| F5 (iPhone page, accessories, earbuds) and accessory captures | 0.6.1 session (not run); ROADMAP 5, 6 | Session A step 2 |
| F9 (Russian) | 0.6.1 session (not run) | Session B step 4 |
| F11-alert, F11-login | 0.6.1 session | closed (§4, WP-0) |
| F12's first failure | 0.6.1 session | Q-B9, settled: GitHub's rate limit behind a VPN |
| Charge Limit capture; spreadsheet exports | ROADMAP 1.1, 6 | Session B optional |
| Widgets kept across an in-app update | ROADMAP 1.2 | 0.6.1's after-publishing check; W0-2's control; Session B F8 |
| Widget customization | maintainer's request, 2026-10-22; ROADMAP 0.7 | §8; spikes WP-W0 in 0.6.2; W-1 to W-10 in 0.7 (§9.1; Q-W1: no 0.6.3) |
| CB-02 (device JSON dates) | PLAN §6, Q3 | 0.7 |
| CORE-16 | audit-core-verified | stays rejected, unless 0.7's drawn-battery visual changes `BatteryIcon` |
| Glossary re-check, captures from M1-M4 Macs; Instruments against the resource targets | ROADMAP 1.1 | not planned (WP-21's memory covers the RAM target) |
| Chart descriptors; App Nap on the minute timer | ROADMAP 3 | not planned |
| How often the mAh values change | ROADMAP 3 | Session A's ioreg sampler (`BatteryData`'s `RemainingCapacity` every 10 s); WP-22 ticks it |
| iPad capture, ManufactureDate decoding | ROADMAP 5 | not planned (no iPad at hand) |
| Apps using energy; charge limiting; package manager | ROADMAP 3, 6 | not planned (the package manager's official catalog needs notarization, and so the paid account the maintainer declined, M-1; the others a spike first) |
| K-02's CI half | WP-0b report (0.6.1) | not planned |
| Glass in the tile picker | PLAN §6 | closed: the maintainer chose the outline (PLAN §8) |
| `package` access, documentation-lint rules | PLAN §6 (SW-R17) | not planned |
| Developer ID signing, notarization, an App Group | ROADMAP Decisions; M-1 (`docs/plans/1.0/ROADMAP.md` §6) | not planned (M-1: no, 2026-10-22); §8.3 candidate C, §10 |
| Release download counts | the maintainer's question, 2026-10-22 | §10's usage evidence; D3 records each release's DMG and `.sig` counts a week after publishing |

## Appendix B: facts verified for this plan

**Apple's documentation** (fetched 2026-10-22):
- **Families:**
  - `WidgetFamily.systemExtraLarge` is macOS 14.0+, and `systemExtraLargePortrait` macOS 27.0+,
    "on the Desktop on macOS".
  - `accessoryCircular` and `accessoryRectangular` list iOS, iPadOS, Mac Catalyst, watchOS and
    visionOS 27; `accessoryInline` lists iOS, iPadOS, Mac Catalyst and watchOS. None lists macOS.
- **Configuration:**
  - `AppIntentConfiguration`, `WidgetConfigurationIntent`, `IntentCollectionSize` and
    `IntentWidgetFamily` are macOS 14.0+.
  - `IntentParameter`'s `size: [IntentWidgetFamily : IntentCollectionSize]` initializers with
    `title:` are 15.0+, with overloads from 27.0 and 27.2.
  - `When(widgetFamily:)` is 14.0+, `IntentExecutionTargets` 27.0+, and `currentConfigurations()`
    15.0+.
- **Rendering:**
  - `WidgetRenderingMode` is macOS 13.0+ (its `fullColor` text names Notification Center), and
    `widgetAccentedRenderingMode` 15.0+.
  - Apple's Liquid Glass widget articles: on the Mac, a tinted or clear appearance renders accented
    and tints primary and accented content white.
  - The macOS 27 Mac User Guide has two settings: Appearance → Icon & widget style, and Desktop &
    Dock → Dim widgets on desktop.
- **Interactivity and clicks:**
  - `Button(intent:)` and `Toggle(intent:)` are macOS 14+; a perform always reloads the timeline
    and doesn't count against the budget.
  - Clicks: "Linking to specific app scenes from your widget or Live Activity".
- **Budget:** "typically 40 to 70 refreshes" for a frequently viewed widget, entries "at least
  about 5 minutes apart", one budget per widget; WWDC26 session 277 on throttled foreground
  reloads.
- **Time formats:** `SystemFormatStyle.DateOffset` (macOS 15.0+; with `[.hour, .minute]`, "1 hour,
  5 minutes") and `DateReference` ("in 3 hours"). Re-checked by the editor.
- **Other:**
  - Smart Stack clues are iOS, iPadOS and watchOS only.
  - `privacySensitive(_:)` is macOS 12.0+; redaction is documented only for the Lock Screen and
    Always On.
  - `WidgetPushHandler` is macOS 26+.
  - `desktopImageURL(for:)` must be called on the main thread.
- **App Groups and the sandbox:**
  - App Groups need a matching Team ID or a provisioning profile ("Accessing app group containers
    in your existing macOS app").
  - The macOS 27 release notes: 161835690 (other teams' containers denied without a prompt),
    178668601 (files created by other teams' apps may be denied), 184660124 (a process without a
    bundle ID can't be granted access).
  - Temporary-exception paths must start with a slash, and a directory must end with one (App
    Sandbox Temporary Exception Entitlements).
- `diskutil image` exists since macOS 26 (its release notes, ASIF).

**Swift toolchain:**
- SwiftPM `release/6.4.0`, `Sources/SwiftBuildSupport/SwiftBuildSystem.swift:939-940` sets
  `LM_SKIP_METADATA_EXTRACTION=YES`. Re-checked by the editor.
- Per the review, not re-checked: Swift Build's `AppIntentsMetadataTaskProducer.swift:55` and
  `TaskProducer.swift:1443-1456`, `SWIFT_ENABLE_EMIT_CONST_VALUES` (YES by default), the App
  Intents protocol list in `SWBApplePlatform/Plugin.swift:359-363`, and the processor's options in
  `AppIntentsMetadata.xcspec:20-185`.
- `-internalize-at-link` is a hidden frontend flag in Swift 6.4, and `.defaultIsolation` needs
  PackageDescription 6.2+.

**The repository at `9410861`:**
- the widget's single file, kind, families, entitlements file, packaging and posture check as §8.1
  quotes them;
- `BatteryReadScope` and its choice by `SMCReadPolicy` (`BatteryProvider.swift:26-32`,
  `BatteryMonitor.swift:205-210`), and Power and Raw Data as slow-value clients
  (`MainView.swift:248-253`);
- `SourceScanner.otherTargets` (`SourceScanner.swift:36`), the allow lists
  (`SecurityGuardTests.swift:40-57, 83-92`), and BatteryKit's internal `Diagnostics`
  (`Diagnostics.swift:144`);
- 35 `@MainActor` in the app, 4 of them function types or a `Task` in a KVO handler;
- the drawing painter in the app target (`BatteryIconView.swift:9, 215`);
- `AccessoryBattery.id`'s doc comment (`Accessory.swift:120-130`);
- `BatteryFormatter()`'s English symbols (`BatteryFormatter.swift:33-41`) against
  `BatteryFormatter.app` (`App/Localized.swift:15-23`);
- E10's code (`UpdateChecker.swift:83-86, 205-212`);
- the beta strings (`AdvancedSettings.swift:54-62`, `UpdateViews.swift:409-411`).

**CI and the session:**
- CI run 39751622292 (`9410861`, push): widget binary 1,379,808 B, `__text` 943,096 B; the
  `hdiutil` deprecation warnings with their `diskutil` replacements; `No battery` after a 0.056 ms
  registry lookup.
- CI run 39492991212 is `647bc74` (`workflow_dispatch`).
- PR 11's session comments: UR-3 answers (y only on Standard, Light), V1d y, V4-materials y, no F5
  or F9 section, F12 failing once, and the `refresh history` and `accessory.read` rows.
- `git grep` finds no `perf` lines or `menuBarReady` at v0.6.0 (`6133b4f`), and finds them at
  `claude/baseline-0.6.0` (`076873d`).

**Usage** (GitHub's REST API, 2026-10-22): the release asset counts of §10's usage evidence,
re-checked by the editor with `gh api repos/{owner}/{repo}/releases` (15 DMG and 6 `.sig`
downloads at that time, against the 14 and 5 counted earlier the same day). The page views come
from the traffic API and were not re-checked.

**Not verified here; decided by WP-W0 or the sessions:**
- the processor step's output under SwiftPM;
- entity queries and button performs in an ad-hoc-signed extension;
- the extracted placeholder form of a `Summary` key;
- the temporary exception and the shared-preference exception under ad-hoc signing on macOS 27;
- `IOPSCopyPowerSourcesByType(4)` from the sandbox;
- the rendering mode per Icon & widget style, and Notification Center;
- the `NSUserActivity` type string of a widget click, and whether a `widgetURL` needs a scheme;
- whether a placed widget survives the static-to-configurable change;
- whether macOS ever redacts widgets, and whether Text size reaches desktop widgets;
- what VoiceOver says for the level symbol;
- `diskutil image attach`'s `-noautoopen` equivalent and the forced eject path;
- whether `diskutil eject` of a mount point detaches the image;
- whether a per-extension `AppleLanguages` reaches the widget and its edit sheet;
- the hdiutil deprecation, which is seen only as runner warnings, not in Apple's release notes;
- whether opening a desktop picture outside `~/Pictures` and the system folders shows a
  file-access prompt on macOS 27 (moot while the desktop-picture fill isn't built, Q-B2).

## Appendix C: facts 0.6.2 records (filled during the release)

| Fact | Shown by | Decides |
|---|---|---|
| W0-1: the processor step's `extract.actionsdata`; the `size:` overload; entity query and button results; extracted `Summary` keys | CI; Session A | W-2, §8.11, §8.16 |
| W0-2: SPIKE-C and SPIKE-W placed-widget results (`pluginkit`, screenshots); edit sheet in English and Russian | Session A | §8.16, W-3 |
| W0-3: A, A′, B results (errno and byte count) | Session A | §8.3, Q-W3 |
| W0-4: accessory count; rendering mode per style and place; `redactionReasons`; click deliveries; scheme need | Session A | W-8, §8.7, §8.9 |
| W0-5: VoiceOver text; Text size | Session A | §8.15 |
| W0-6: the offset format's text and cadence | Session A | Time parameter |
| F13: `UpdateTime` changes against "any" lines | Session A's pslog and ioreg | G-14b |
| E3b: `timeremaining` followed by "any" (battery and charging) | Session A's pslog | G-14c |
| E20 field run: traps, crash reports, `read` threads; memory over 2 hours | Session A (SPIKE-A2) | G-14a |
| V-01: "executor" log lines, new crash reports, the maintainer's answers | Session A (SPIKE-A2); Session B (RC) | G-10, G-14a |
| `read cached` p50; `registry.missed` per hour of logged runtime | Session B | G-14b |
| mAh cadence: `RemainingCapacity` changes per hour | Session A's ioreg sampler | ROADMAP Stage 3 (WP-22) |
| Clear's fill (b) and Translucent Dark's today's fill: recordings and answers | Session A step 6 | G-13a |
| The 8 recorded minimize cases and the plain answers | Session B step 3 | G-13a, G-13b |
| The 24 screenshots and the 19 graduation shots, answered y or n; V1b's pixel comparison | Session B step 3 | G-13b; WP-13 item 2 |
| The contrast audit's reports per beta style, appearance and page | Session B step 3 | G-13b (Q-B4) |
| Clear's shadows in Instruments | Session B step 5 | G-13b; Stage 1.5 |
| S4w per style against Standard | Session B | ROADMAP's decision line (G-13c; no fallback, Q-B10) |
| F8 per family and language (F8-ru: the method, or not checked) | Session B | G-15 |
| F12: offered, installed, relaunched, per try | Session B | G-16 |
| `page.switch` count and p50 per page, before and after | Session A step 8; Session B step 5 | G-17 |
| F5: accessory and device captures (`bpulse` built or not) | Session A step 2 | W0-4; ROADMAP Stages 5 and 6 |
| F9: Russian pages | Session B | D3 (a failure becomes a fix) |
| F11: the alert step and the banner, or not run; the login item gone from Login Items | Session B | D3; ROADMAP Stage 1.2 |
| `diskutil info -plist` fixture; both CI install passes | CI | WP-16 |
| Sleep hygiene: `pmset -g assertions` per run; the overnight `pmset -g log` | Sessions A and B | WP-21 |
| SEC-15 timings; `diskutil image attach` and `eject` usage text | Session A; CI | WP-16 |
| F12's first failure | Q-B9 | WP-16 acceptance |
| A/B energy (S1, S2, S2 Low Power Mode, S6, S7) | Session A | WP-21 baseline |
| C energy, S4w, S5, burst, memory | Session B | WP-21, G-13c |
| B3 bench rerun; `HistoryLoad.read` profile | WP-17 | WP-17 riders |
| `-internalize-at-link` build times and sizes | WP-15 | G-15 |
| SUI-17 previews y or n; SUI-19's 5 slowest bodies in ms; SZ-10's shots in the four icon styles and the maintainer's answer | WP-18 (the maintainer, from Claude's step-by-step list) | WP-18; SZ-10 ships or waits for 0.7 |
| SEC-18: what a self-signed identity keeps across an update | WP-20 | 0.9.0's SEC-02 decision (`docs/plans/1.0/ROADMAP.md` §3.5) |
