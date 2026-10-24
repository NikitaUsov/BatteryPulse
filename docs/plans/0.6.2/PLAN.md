# BatteryPulse 0.6.2: the plan (revised draft for the maintainer)

Revised 2026-10-22 against `9410861` (then the tip of `claude/nice-faraday-k08mhb`; now in PR 11's
history, `refs/pull/11/head`), whose tree equals the v0.6.1 tag (`7622373` on `main`, a squash
merge). The first draft was written at `0215b71`.

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
- The maintainer's answers of 2026-10-22 (§10), his further answers later that day (§10,
  "Further answers"), and the release download counts from GitHub's REST API the same day (§10,
  "Usage evidence").

CLAUDE.md wins over all of them.

Hashes cited here that are not on `main` (`0215b71`, `1f9937b`, `11d2ab3`, `647bc74`, `6aaf8ec`,
`6aec4d2`, `9410861`) are in PR 11's history, which GitHub keeps as `refs/pull/11/head`
(`git fetch origin pull/11/head`); `claude/nice-faraday-k08mhb` restarted from `main` after the
merge, at v0.6.1 (`7622373`), and is 0.6.2's integration branch (§3). The energy baseline build
lives on `claude/baseline-0.6.0` (`076873d`), which stays until 0.6.2's D3; the `claude/061-*`
package branches go after the 0.6.1 release, as PLAN §8 says.

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
    runner already prints. It also ends the widget extension before the swap, so the update to
    0.7's configurable widget keeps placed widgets drawing (WP-16 item 6; Session A found that
    WidgetKit otherwise caches the new version with the old extension's descriptor).
  - **Release statistics** (tooling, no app change): `scripts/release-stats.swift` prints each
    release's DMG and signature downloads, and from 0.7 on the version count's, for ROADMAP's
    Releases table a week after each release (WP-19, D3).
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
  - **Session B, on the release candidate, hands-free** (the maintainer's request, 2026-10-23;
    §10, "The hands-free sessions"): about 18-22 minutes of his time in short moments (2 once
    before, 10-12 at the start with the burst, 1 at bedtime, 5-7 in the morning), against about
    100 before (plus WP-18's hour). One local Claude Code session with computer use does every
    other step: the GUI steps on the adapter in the evening, then the energy queue runs as a
    plain script overnight (§6).
  - Both include the Xcode items, now that Xcode is installed on the M5 (Q-B7). WP-18's items run
    inside Session B (SZ-10's answer joins his morning batch), not as an hour of his own.
- **Decisions (2026-10-22):** no question of §10 stays open. The maintainer answered Q-B2, Q-B7,
  Q-W1 and, through M-1, Q-W3; he delegated the rest ("by best practices"), and each carries its
  recommended answer. M-1, the paid Apple Developer Program account, is no: no App Group (§8.3
  candidate C) and no Enhanced Security spike (WP-20). Usage evidence: 14 DMG downloads across
  every release, so the users are, in effect, the maintainer (§10).
  - Further answers the same day (§10): M-5 is approved as written, with **no dates**: releases
    come when there is time and desire, so this plan sets none. Round A0 passed. The integration
    branch is `claude/nice-faraday-k08mhb`. 0.7 gets an anonymous version count, on by default
    and announced; 0.6.2 changes nothing the app sends and adds only the release-stats script.
- **Budget:** about 34-39 implementation and review runs plus 3 for fix-forward; the never-cut set
  is about 24-29 (§7.2). WP-21's hands-free mode adds 2 runs, and SZ-10's icon source, now that
  WP-18 runs inside Session B, 1 (2026-10-23).

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
| G21 SZ-10, -11, -14 | SZ-11 and SZ-14 in WP-15 as CI experiments; SZ-10 needs Xcode, which is installed on the M5 (WP-18, run by Session B; Q-B7) | G-15 (SZ-11, SZ-14); WP-18 (SZ-10) |

---

## 3. How every package runs (0.6.1's practices, kept)

Everything in PLAN §3.0 still applies. The short form:

- **Branches:**
  - The integration branch for 0.6.2 is `claude/nice-faraday-k08mhb`, the session's designated
    branch (the maintainer, 2026-10-22), from v0.6.1 (`7622373` on `main`) with the plans'
    commits on top: a `claude/` name, so CI runs (ci.yml:3-5).
  - Each package gets its own worktree and branch, `claude/062-<pkg>` (`claude/062-wp10` for
    WP-10), from the integration tip.
  - The widget spikes go on `claude/062-spike-widget` (WP-W0), and SPIKE-A2 on
    `claude/062-spike-a2` (§5 A2′). Spike branches are never merged.
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
     scripted shots (§6) cover the look items below; the session takes and pre-judges them, and
     the maintainer answers one contact sheet per style. The contrast audit (step 3) and Clear's
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
  - Standard and Frosted are compared with a TextEdit window (an empty document) minimized the
    same way: anything also seen there is the system's, not WP-13's. (TextEdit replaced Notes on
    2026-10-23: an empty file shows nothing private and closes without a save prompt.)
  - The maintainer's plain answers on each style (§6); the fill itself is decided (Q-B2).
- **Gates:** G-13a (the fill), G-13b (graduation), G-13c (Low Power Mode: decided, none). After
  round B1, (b) ships on Clear and Translucent Dark on Session A's interim verdicts (§7.1).
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
  (b) on Clear only (Q-B2, G-13a), and E3b keeps both keys (G-14c). The 14 days only let the
  packages go on; they are no deadline for the maintainer and no release date (M-5, §10).
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
- **Gates:** G-14b (E4b), G-14c (E3b). After round B1, G-14b's Session A half and G-14c passed
  (§7.1). **Effort:** M, 2-3 runs. **Risk:** medium (values of different ages in one snapshot).

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
- **Gate:** G-15 (§7.1). After round B2, K-03 can ship by §3's exception, and internalize waits
  for the RC's F8 and, on the app's line, Session B's pages (§7.1). **Effort:** M, 3 runs.
  **Risk:** medium (a widget that doesn't render; references only the runtime reaches).

### WP-16: Installer on `diskutil`, the widget extension before the swap, attach timing, Check Now (P1/P3)

- **Source:**
  - ROADMAP Stage 1.7;
  - PLAN Appendix C B1, where the hdiutil deprecation warnings were seen on the runner;
  - PLAN §6 (SEC-15, E10);
  - research `security.md` SEC-15 and `energy.md` E10;
  - ROADMAP Stage 1.2 (login item after an update);
  - Session A's W0-2, 2026-10-23 (item 6; Appendix C).
- **Items:**
  1. **`UpdateInstallPolicy.attachArguments` and `detachArguments`** (BatteryCore). They start from
     the runner's own mapping, printed by CI run 39751622292's step "Install the way 0.6.0 does,
     then launch":
     - attach: `/usr/sbin/diskutil image attach --readOnly --mountPoint <dir> --mountOptions nobrowse
       <image>` (as merged, in the usage text's order), with the order taken from `diskutil image attach` help, which CI saves to
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
  5. **Login item after an update: not run.** It was conditional on 0.6.1's after-publishing check
     losing the login item, and round A0 passed: Open at login kept its state across the in-app
     update 0.6.0 → 0.6.1 (Appendix C). WP-22 ticks ROADMAP Stage 1.2, and no settings key is
     added. The design, kept as background in case a later update loses it:
     - Nothing stores the choice today: the toggle reads `SMAppService.mainApp.status` and
       registers only from the toggle (`App/AppSettings.swift:277-319`), and no key holds it
       (`AppSettings.swift:11-55`).
     - The toggle would also store the choice in a new key, `openAtLogin`, which follows the
       status whenever the app reads it (the toggle, launch, becoming active).
     - On the first launch after a version change (`lastSeenVersion`), before that sync: if the key
       is true and the status is neither `.enabled` nor `.requiresApproval`, the app registers once
       and logs it.
  6. **End the widget extension before the swap (P1, never cut).**
     - **Why (Session A, W0-2; Appendix C):** the first SPIKE-W install (282) greyed the placed
       widgets. At the version change, chronod fetched the widget descriptors again within about
       2 ms, from the old `BatteryPulseWidget` process that was still running, and cached version
       282 with the previous build's static descriptor. Every reload then failed with
       `CHSErrorDomain` 1103 and "Connection to extension process was invalidated". After the
       session ended the old extension and installed 0.6.1, then SPIKE-W again, the same placed
       widgets (small and medium placed under 0.6.1, medium under SPIKE-I) redrew in today's look
       with fresh values: a widget placed by 0.6.1 survives its kind becoming an
       `AppIntentConfiguration` (Automatic default) when the fetch reaches the new extension.
       `WidgetRefresher.endPreviousExtension()` (`App/WidgetRefresher.swift:43-67`) runs only at
       the new app's launch, after chronod has fetched. The session script already ends the
       extension before each swap (`56702f9`).
     - **Why 0.6.2:** 0.6.2 → 0.7 runs 0.6.2's installer, and 0.7 changes the descriptor. 0.6.1 →
       0.6.2 runs 0.6.1's installer, which is harmless because 0.6.2 keeps the static kind (§7.3),
       so a descriptor cached from the old process is still right.
     - **The call:** in `UpdateInstallSteps.replace` (`Updates/UpdateInstaller.swift:388-429`),
       after `checkBundle` and `checkCodeSignature(staged)` and right before `renamex_np`:
       `await WidgetRefresher.endExtensionBeforeSwap()`. An update that fails a check leaves the
       extension alone.
     - **The function:** `nonisolated static func endExtensionBeforeSwap() async` in
       `App/WidgetRefresher.swift`, which `replace` reaches from its `@concurrent` context without a
       main-actor hop. It sends SIGTERM to every `BatteryPulseWidget` process, polls every 50 ms
       (`sleep(for:tolerance:)` with at least 10 % tolerance, so `EnergyGuardTests`' four one-shots
       stay four), sends SIGKILL to any process still there 0.5 s after its SIGTERM (a process
       started meanwhile is found by the next scan and gets its own SIGTERM), and gives up at
       1.5 s. The swap goes ahead either way: the function never throws and never fails an install.
     - **The pid scan** (`proc_listallpids` and `proc_name`, matched against
       `extensionExecutable`) moves into one `nonisolated` helper that both
       `endExtensionBeforeSwap()` and `endPreviousExtension()` use. The launch-time
       `endPreviousExtension()` stays for a copy from the DMG; after an in-app install it usually
       finds nothing, or the new extension chronod started, which it ends and reloads as today.
     - **The log:** one `Diagnostics.update` notice with counts and milliseconds only (found, ended
       by SIGTERM, ended by SIGKILL, still running, elapsed ms), all `.public`. A failed scan logs
       an error, as today. No pid, path or name is logged.
     - **Guards:** `IsolationGuardTests.offMain` lists the new `nonisolated` declarations (the
       function and the shared scan, and the executable-name constant if the compiler needs it
       `nonisolated`), each with its reason. `SecurityGuardTests`' `kill` allow-list
       (`WidgetRefresher.swift` only) is unchanged: the installer calls the function and never
       `kill` itself. A Linux source-order test (beside `UpdateInstallTests`, over
       `SourceScanner`'s blanked copy of `Updates/UpdateInstaller.swift`) pins the call inside
       `replace`, after `checkCodeSignature(staged)` and before `renamex_np`.
- **Files:** `BatteryCore/UpdateInstall.swift`, `Updates/UpdateInstaller.swift`,
  `Updates/UpdateChecker.swift` (E10), `App/WidgetRefresher.swift` (item 6),
  `.github/workflows/ci.yml` (the install step), `UpdateInstallTests`, `IsolationGuardTests`
  (item 6).
- **Acceptance:**
  - Tests; both CI install passes.
  - Session B's F12: the RC built as 0.5.99 installs the real 0.6.1 through the `diskutil` path and
    relaunches. F12 runs once, after the script checks GitHub's remaining API requests (Q-B9).
  - Item 6, in the same F12: the script reads the `update` log and finds the pre-swap line (every
    process found was ended, elapsed ≤ 1,500 ms, with at least one found when the script saw a
    `BatteryPulseWidget` process before Install), no `BatteryPulseWidget` process started before
    the swap is left, and the placed widgets redraw.
- **Gate:** G-16 (§7.1; default: back to `hdiutil`; item 6 ships either way). **Effort:** M, 2-3
  runs. **Risk:** medium (the installer first runs for real in 0.6.2 → 0.7; there is no 0.6.3,
  Q-W1).

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

### WP-18: Work that needs Xcode on the Mac (P2, run by Session B)

- **Source:** PLAN §6 (SUI-17, SUI-18, SUI-19, SZ-10; G21); Q-B7 (Xcode is installed on the M5);
  the hands-free sessions (2026-10-23, §10).
- **Items:**
  - **SUI-17:** a 30-minute previews spike. Do previews work in a SwiftPM executable target in
    Xcode 27? Session B opens the package with `xed`, and computer use resumes the canvas (Xcode
    is a "click" app for computer use, which is enough for Resume); a trust or macros prompt
    comes up in B0's preflight while the maintainer is there. Claude judges y or n from the
    canvas.
  - **SUI-18: dropped** (2026-10-23): it would leave only an uncommitted checklist, and a review
    run can use the skill directly.
  - **SUI-19:** type-check timing of the slowest bodies: `xcrun swift build` with
    `-Xswiftc -debug-time-function-bodies`, local only and never committed, on the adapter in Session B's B2 or its morning-away block.
  - **SZ-10:** the Icon Composer icon through `actool`. It changes how the app icon looks in every
    icon style. Decided by delegation (Q-B7): it is prepared and shown in the four icon styles,
    and ships only on the maintainer's y to those screenshots; otherwise it waits for 0.7. A
    cloud run (1 run, §7.2) prepares the icon source [unverified: a hand-written `.icon` bundle
    compiles with `actool`]; Session B builds it with `actool`, switches the four Icon & widget
    styles by computer use and takes the shots; his y joins the morning batch.
- **Who:** these need Xcode, which is installed on the M5 (Q-B7, 2026-10-22) and which cloud
  sessions don't have. Session B runs them (§6); nothing waits for them, and an item Session B
  doesn't reach is recorded "not run".
- **Files:** nothing committed, except SZ-10's icon source and an `actool` line in `build-app.sh`,
  only on the maintainer's y to the icon's screenshots.
- **Acceptance:** one Appendix C line per item: previews work, y or n (SUI-17); the type-check ms
  of the 5 slowest bodies (SUI-19); the icon's screenshots in the four icon styles with the
  maintainer's y (SZ-10).
- **Effort:** 1 run (SZ-10's icon source) and about 1 minute of maintainer time (SZ-10's y).
  **Risk:** low.

### WP-19: Readability and tooling (P2/P3)

- **Source:** PLAN §6 (SUI-09, SW-21, SW-13, C2, CI pins); the maintainer's answer of 2026-10-22
  (§10, "Further answers", item 6: the release statistics).
- **Items:**
  - **Release statistics (P2, cut last; no app change):** `scripts/release-stats.swift`, run with
    `swift scripts/release-stats.swift`, Foundation only. It depends on nothing else, so it may
    land first in WP-19's slot.
    - **Output:** a Markdown table, one row per published release, newest first: the tag, the
      publishing date (UTC), DMG downloads (`BatteryPulse.dmg`), signature downloads
      (`BatteryPulse.dmg.sig`; each in-app install fetches it, so it counts in-app updates) and the
      count's asset's downloads (`BatteryPulse-count.txt`, 0.7's, §10), the Count column; a total
      row last. These are the columns D3 copies into ROADMAP's Releases table.
    - A release without the asset shows "—", never 0: 0.2.0-0.3.1 have no `.sig`, and no release
      before 0.7 has the count's asset. Other assets (`BatteryPulse-dSYMs.zip`) and drafts are
      left out; a pre-release is marked.
    - The count's asset name is one constant at the top of the script, `BatteryPulse-count.txt`,
      the name the 0.7 plan's W-13 freezes. No release before v0.7.0 has that asset, so the column
      reads "—".
    - **The request:** one unauthenticated `GET
      https://api.github.com/repos/NikitaUsov/BatteryPulse/releases?per_page=100` (another
      repository with `--repo <owner>/<name>`), with a User-Agent and `Accept:
      application/vnd.github+json`. It goes through an ephemeral `URLSession`, never `.shared`, as
      CLAUDE.md's network rule says for the app (`FoundationNetworking` on Linux). It follows the
      `Link` header only past 100 releases. It sends no token and reads none.
    - **The rate limit** (60 unauthenticated requests an hour per address, which a shared VPN
      address can use up, Q-B9): a run costs one request, and it prints the requests left and the
      local reset time to stderr. A 403 or 429 with `X-RateLimit-Remaining: 0`, or with
      `Retry-After`, prints "GitHub is limiting requests until <time>; try again then, or pass a
      saved response with --input" and exits 2, with no retry and no sleep. Any other HTTP or
      network error exits 1 with its status.
    - **`--input <file>`** (`-` for stdin) renders a saved response instead, so the authenticated
      route works too (`gh api 'repos/{owner}/{repo}/releases?per_page=100' > releases.json`,
      5,000 requests an hour), and CI checks the table offline.
  - **SW-13 for BatterySource and BatteryKit (P2):** `.strictMemorySafety()` on both targets
    (today only BatteryCore and bpulse have it, `Package.swift:38-45`). Every unsafe IOKit, SMC,
    notify and MobileDevice site is marked `unsafe` with its reason. It runs after WP-15, which
    moves the IOKit, SMC and notify bindings into BatterySource. CLAUDE.md's unsafe-code sentence
    names BatterySource and BatteryKit (WP-22).
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
  DocC, and the release-stats lines in "Check the verification scripts"),
  `Tests/BatteryCoreTests/SecurityGuardTests.swift` (the escape list); SUI-09 stays in `App/`.
  The release statistics: `scripts/release-stats.swift`, `scripts/release-stats-sample.json` and
  `scripts/release-stats-sample.expected`.
- **Acceptance:** 0 warnings on both jobs; every `unsafe` carries a reason comment;
  `SecurityGuardTests`' escape list is updated; each pin is a SHA, with its changelog link in the
  commit message. For the release statistics:
  - ci.yml's "Check the verification scripts" step runs `swiftc -typecheck
    scripts/release-stats.swift`, `swift scripts/release-stats.swift --self-test` and `swift
    scripts/release-stats.swift --input scripts/release-stats-sample.json | diff -u
    scripts/release-stats-sample.expected -`, and its comment no longer says every script needs a
    display or a running BatteryPulse.
  - The sample is the real response for 0.2.0-0.6.1, cut to tags, dates, asset names and counts,
    plus a draft, a pre-release and an unrelated asset. The expected table shows "—" for
    0.2.0-0.3.1's signature and every Count cell, leaves out the draft and the dSYMs, and marks
    the pre-release.
  - `--self-test` checks the rate-limit decision on canned statuses and headers: a 403 with
    `X-RateLimit-Remaining: 0` and a 429 with `Retry-After` give the message and exit 2, a 404
    exits 1, a 200 gives the table.
  - One live run in a cloud session: its DMG and `.sig` counts equal `gh api`'s for every release,
    and its output goes in the commit message.
  - `swift format lint --strict` passes over `scripts/`; the script is English only.
- **Effort:** M, 2-3 runs (the release statistics may take the third). **Risk:** low.
  **Merged** in round B3 as `1bb19d7` (2026-10-24; §5, Appendix C): SUI-09 needed no change, and C2
  became a peak-footprint table without a budget.

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

### WP-23: The iPhone and iPad connection label follows the transport (P2)

- **Source:** Session A's F5, 2026-10-23 (Appendix C). With an iPad on the cable and on Wi-Fi:
  after the cable was detached, a "didn't answer" banner sat over stale "Connected by cable"
  values, and a fresh read over Wi-Fi was still labelled "Connected by cable".
- **Where the label comes from today:** `DeviceView.connectionPhrase`
  (`Main/DeviceView.swift:168-174`, used by the subtitle and the Connection row at :251) switches
  on `entry.connection`. `IDeviceRoster.connection(of:now:)`
  (`BatteryCore/IDeviceSchedule.swift:126-133`) derives it from the session's listed
  `connections`, USB first, and `IDeviceMonitor.apply` (`BatteryKit/IDeviceMonitor.swift:460-500`)
  replaces those only from a list. The transport a read actually used, the capture's `Connection`
  key (`IDeviceCapture.swift:47, 225`), never reaches the label, and the problem text picks its
  cable or Wi-Fi wording from the same stale value (`App/Localized.swift:59-67`).
- **Items:**
  1. **Reproduce on Linux first,** in `IDeviceMonitorTests` with the fake transport and clock: a
     device listed on USB and Wi-Fi, a USB termination, then a list that still reports USB (the
     likeliest cause), a list that reports Wi-Fi only, and a stalled monitor (a timed-out call
     drops every automatic list, USB events included, `IDeviceMonitor.swift:337-342, 655-661`).
     The test that fails names the cause; the fix follows it.
  2. **A pure decision in BatteryCore:** `IDeviceSession` and `IDeviceEntry` gain the transport
     of the latest successful read (from the capture's `Connection` key), and `IDeviceRoster`
     decides the shown connection from it, the listed interfaces, `listedAt` and the latest USB
     termination: a read over Wi-Fi after the cable left shows Wi-Fi, and a USB interface listed
     before the latest termination doesn't count. Linux tests in `IDeviceScheduleTests` cover each
     case of item 1.
  3. **`IDeviceMonitor`** records the read's transport in `finishRead` and drops `.usb` from the
     session on a confirmed termination; **`DeviceView`** and the problem text use the decided
     connection. No new string: the three phrases exist (§3: only WP-13 item 5 touches the
     catalog).
- **Files:** `Sources/BatteryPulseApp/Main/DeviceView.swift`, `App/Localized.swift` (only the
  connection it is passed), `Sources/BatteryKit/IDeviceMonitor.swift`,
  `Sources/BatteryCore/IDeviceSchedule.swift`, `Tests/BatteryCoreTests/IDeviceScheduleTests.swift`,
  `Tests/BatteryKitTests/IDeviceMonitorTests.swift`.
- **When:** a free slot from B1 on (§5, floating work), never beside WP-15 (it adds
  `import BatterySource` to `IDeviceMonitor.swift`), WP-17 (`Main/`) or WP-19's SW-13 (which may
  mark `IDeviceMonitor.swift`'s unsafe sites); a later rebase over it is mechanical.
- **Acceptance:** the Linux tests; a green macOS job; on the M5, if an iPhone or iPad is at hand
  (Session B, optional): cable, unplug, Refresh over Wi-Fi reads "Connected over Wi-Fi", and "Not
  connected" once the Wi-Fi sighting expires.
- **Effort:** S, 2 runs. **Risk:** low. **Default:** not run; the label stays as 0.6.1's, a known
  issue.

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
    ROADMAP Stage 1.2 records placed widgets surviving one DMG replacement and not another; round
    A0 saw them survive the in-app update 0.6.0 → 0.6.1 (Appendix C).
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
    - The energy setup: brightness about half, auto-brightness and True Tone off, other apps quit,
      Focus on. Session A's `window` asks for it once; in Session B the session sets the first
      three itself at the hand-over, the maintainer quits his apps and turns a Focus on at the
      start, and nothing asks (the hands-free mode below).
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
  - **Session B (C, with B for a same-day pair), in the queue's order, most important first.**
    Session A's window (Appendix C, 2026-10-23/24) showed one pair can't settle a scenario: its
    first run read high, and two identical S2 runs of one build differed by almost 2×. So the queue
    opens with a warm-up, runs three pairs of S1 and S2, and every comparison uses the median of a
    scenario's runs per build (added 2026-10-24):
    - Warm-up: one 5-minute S2 run of C, discarded (recorded, never compared).
    - S2: B C B C B C. A touched S2 run is retried as a B and C pair, never as a lone run an hour
      later.
    - S1: B C B C B C (B added on 2026-10-23, so S1 has the same-day pairs the C ÷ B × B ÷ A chain
      and the 15 % check need; three pairs on 2026-10-24). If S1's median still has 0.6.1 or the
      RC above 0.6.0 by more than the spread of its own runs, WP-21 looks for the cause before D1.
    - S2 with Low Power Mode: B C (only with the sudo ticket; B added on 2026-10-24 for a same-day
      pair).
    - S4w: Overview 5 minutes each in Standard, Clear, Translucent and Standard again, so drift
      shows against the first Standard; then Frosted if the charge allows (graduation and G-13c
      input).
    - S5: the main window covered by a TextEdit window, 5 minutes. Session B's B3 closed TextEdit, so the
      queue opens `~/bp-062/B/bp-062-cover.txt` with `open -a TextEdit`, places it over the main window
      by `ui position` (AX into TextEdit only), confirms it with `ui windows` before the quiet
      minute, and closes and quits it by AX presses after the run, before S6 locks the screen.
    - S10: accessories connected, if `pmset -g accps` lists any.
    - S7: 5 launches.
    - S3 (the popover open) and a minimized run (new, 5 minutes each), each set up by CGEvent clicks
      at CGWindowList frames before its quiet minute and confirmed in CGWindowList at its end,
      never by an AX call into the measured process. The minimized run ends with a CGEvent click
      on the window's Dock tile (its frame from the Dock's AX tree), confirmed in CGWindowList,
      before the retries.
    - One retry of each run marked not valid (none below 56 %), then **S6: B C, last** (B added on
      2026-10-24: Session A's S6 B run was disturbed, so the pair is repeated here).
    - The optional runs (Frosted, S5, S10, S3, the minimized run) are skipped below 56 %, so S6
      still starts at 50 % or more.
    - Burst: 3 unplug and plug cycles, 1 minute apart (S8), hands-on at the start (§6, B1);
      `perf-stats` counts only the reads whose trigger is a power-source notification.
    - Memory: History → 7 d three times, `phys_footprint` before and after, by the session, first
      in its GUI phase, on the backed-up history (before Clear History, so the 7-day view isn't
      empty).
    - Devices: S9 (an iPhone attached with all windows closed; target under 1 ms/s on average) is
      not run by default: an attached iPhone charges from the Mac all night and needs a second
      touch. It stays open (Appendix A).
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
    - `rusage` measures only BatteryPulse's own process, so what else runs in the background (the
      Claude Code CLI, Terminal) barely moves the figures. The cross-session confounds are the
      thermal state, the history's size and AX clients, so every run records the thermal state,
      the pack temperature and the history's size, and no run's process has had an AX client.
  - **Sleep hygiene (Session B's own night; playbook §2.3 item 7):** after the night with the RC
    installed, `pmset -g log | grep -i -E "DarkWake|Wake from" | grep -i batterypulse` must be
    empty. The night sleeps with the lid open; the maintainer's 1-minute lid close in the morning
    covers V-01's lid path.
  - **Not run, and staying open in Stage 1.4:** the other-Space run, which needs a hand mid-run,
    and the frame-rate check, which needs Instruments. S3 and the minimized run join Session B's
    queue (above).
- **Hands-free mode for Session B** (the maintainer's request, 2026-10-23; §6, §10 "The hands-free
  sessions"). The script gains what lets one local Claude Code session with computer use run
  Session B without him, and the plain queue run without Claude:
  - **`arm` and `queue` instead of `window`.** Claude opens `~/bp-062/B/arm.command` in a new
    Terminal window (`open -a Terminal`, no Automation needed) at the start. The arm window:
    - holds `caffeinate -d -i -t <GUI phase cap>` while the GUI phase runs, started by arm, not as
      a Claude background task, and kills it when the queue starts;
    - waits at a plain prompt (no password prompt waits, so nothing can type into one) and shows
      the session's state: working (with the step and the expected ready time) or ready;
    - at bedtime, on his Return, asks for the password once (`sudo -v`) and starts the keep-alive,
      capped at the queue's end or 3 hours; it checks that the ticket is bound to its own
      terminal (sudo's tty tickets: `sudo -n true` from a process with no terminal must fail;
      otherwise S2-LPM is "not run" and `sudo -k` runs at once). Without the password the queue
      still runs, with S2-LPM "not run";
    - runs the queue from the frozen worktree (§6), so a later `git` update can't change a running
      bash file;
    - starts the queue when `ready` exists (a file plus a notify post; the waiter registers first,
      then checks the file, with a 60-second backstop), or when the session's heartbeat file is
      more than 20 minutes old (a stalled session), and only on battery, after a cooldown of at
      least 10 minutes, longer until the pack temperature is within 2 °C of Session A's first run,
      at most 20 minutes, with HIDIdleTime at least 60 s. On the stale-heartbeat path it first
      runs the scriptable half of `restore gui` (the appearance, the wallpaper, BatteryPulse's
      defaults, TextEdit and System Settings closed) and lists the computer-use items for the
      morning;
    - writes `~/bp-062/B/queue.started` as soon as it decides to start the queue (on `ready` or a
      stale heartbeat), before the stale path's `restore gui` half and the cooldown, and removes it
      at the queue's end (Session B's B5); on the stale-heartbeat path it also writes `ready` itself (marked
      stale), so "never act after `ready`" holds until his morning "continue". While
      `queue.started` exists, `ui` refuses every action whose caller isn't the queue (arm's pid
      among its ancestors), so a stalled session that wakes up later, after a long retry or a
      compaction, can't act during a run;
    - never starts the queue later than 3 hours after his bedtime unplug: after that every run
      left is "not run: late", so a morning unlock never starts it;
    - starts with `install_build B`, wraps every run (a failure is recorded "not run: error" and the
      queue goes on, never `set -e`'s exit), and logs the full `pmset -g assertions` list at its
      start;
    - keeps Session A's split: `caffeinate -i -w <arm's pid>` for the whole queue, and a separate,
      killable `caffeinate -d`, both started at his Return (or at the queue's start, if he only
      unplugged);
    - posts no sound or speech from `mark away` until his morning "continue". Inside the first S6
      run, 30 seconds before its display goes off, the arm window prints the warning "The display
      turns off for 10 minutes on purpose; please don't wake the Mac" and an alert with it comes to
      the front, giving up before the display goes off (a notification would be hidden by the
      Focus); the start message gives S6's expected time;
    - drops `window`'s `read -r -p` energy-setup question: the session records the answer at the
      hand-over (default 2).
  - **Detectors** (each run's row gets touched, slept, adapter, locked, screen saver, style, Low
    Power Mode and Claude columns; a run marked not valid is retried once before S6):
    - **touch:** HIDIdleTime (`ioreg -c IOHIDSystem`) at each run's start and end and in the
      10-second sampler. A run starts only at 60 s or more; a value below the run's elapsed time
      marks it "touched". Posted events reset it too, which is why Claude ends its turn first;
    - **Claude:** the sampler counts the Claude CLI's child processes and its CPU time; a new child,
      or more than 2 s of CPU during a run, marks it "Claude active (not valid)";
    - **sleep:** `rusage.swift` records a `SuspendingClock` duration beside its `ContinuousClock`
      one; a difference over 1 s, or a Sleep or DarkWake line in `pmset -g log` inside the run,
      marks it "slept (not valid)";
    - **power:** the sampler's existing `ExternalConnected` column plus `pmset -g batt` at the
      run's end; any `Yes` sample inside a run marks it "adapter (not valid)". This replaces
      `field_run`'s 15-second poll; the queue waits for an unplug without polling (a
      `notifyutil -1 com.apple.system.powersources.source` waiter registered first, then one
      `pmset -g batt` check, looping per notification);
    - **lock and lid:** `CGSessionCopyCurrentDictionary` and `AppleClamshellState`; a run during a
      lock is "locked (not valid)". S6 checks the lock only at its start, because
      `pmset displaysleepnow` locks the screen when a password is required at once;
    - **screen saver:** `pgrep -x ScreenSaverEngine` (and `legacyScreenSaver`) [process names
      unverified on 27] in the sampler; preflight reads the screen saver's idle time;
    - **S6's display:** valid only with a "Display is turned off" line at its start and no
      "turned on" line before its end in `pmset -g log`, plus a `pmset -g assertions` snapshot
      during S6;
    - **style in effect:** before each S4w quiet minute, a window-ID shot (`screencapture -l`,
      which doesn't touch the app) and a read of `com.apple.universalaccess` (Reduce
      Transparency, Increase Contrast); either flag on, or a shot Claude reads as the wrong style
      at the morning check, marks the run "style not in effect (not valid)";
    - **thermal:** `ui thermal` prints `ProcessInfo.thermalState` (what `LiveRefreshPolicy`
      reads; `pmset -g therm` doesn't report it), Low Power Mode and HIDIdleTime at each run's
      start and end; a run waits for nominal, at most 10 minutes;
    - **Low Power Mode:** a state at the run's start or end that differs from the run's plan (on
      only in S2-LPM) marks it "LPM (not valid)", with no retry, since nothing would change it.
      Preflight reads `pmset -g custom`, and if Low Power Mode is set on for battery, the start
      message tells him: with his password the queue turns it off for the other runs (the EXIT
      trap puts it back); without it, those runs are "LPM (not valid)";
    - **occlusion:** `ui windows` (CGWindowList only) before S4w: the main window on screen,
      inside the display, not covered (except by S5's TextEdit window) and not full screen.
  - **`preflight`** (the start, while he is there): the proofs of §6 ("Proofs"; P12 waits for the
    burst), one run of every command family through Claude's Bash in auto mode (so every
    permission prompt and every auto-mode block comes now), the reads that replace prepare's
    questions, and a refusal of any `tell application` in the B scripts other than System Events
    and BatteryPulse (another target would raise an Automation prompt at night). `/usage` is a
    command he types, not one the script or the session runs: the session asks him to type it once
    at the start (§6, B0a) [unverified: whether its result reaches the session].
  - **`burst`:** 3 cycles at beeps and notifications, 1 minute apart, each power event stamped,
    ending plugged in.
  - **`docs/plans/0.6.2/ui.swift`** (AX, CGEvent and CGWindowList, built like `frames`):
    - `click [--shift|--control]`, `move`, `drag` (slow, with steps), `scroll`, `press`,
      `select-row`, `frame`, `hit`, `tree`, `windows`, `minimize on|off`, `fullscreen`,
      `position`, `banner <app>`, `idle` (HIDIdleTime and both event-source states), `locked`,
      `thermal` and `guard`;
    - points come from AX or from `--image <png> x y` (pixels converted to points), never from
      computer use's scaled coordinates;
    - **its own safety rules**, so they don't rest on Claude alone: no key presses at all, only a
      Shift or Control modifier (a flagsChanged event) around a click; never Esc, which would end
      Claude's turn; every click hit-tests the topmost window's
      owner and acts only on the approved list (BatteryPulse, the desktop, the Dock and the menu
      bar, System Settings, Notification Center, the widget gallery's host, TextEdit,
      Accessibility Inspector, Xcode); it always refuses SecurityAgent, UserNotificationCenter,
      CoreServicesUIAgent, coreautha, loginwindow, a TCC prompt and Terminal; it refuses System
      Settings while the pane is Privacy & Security, Users & Groups, Passwords or Login Password;
      it refuses any action while the screen is locked or, unless the queue calls it, while
      `queue.started` exists (above), and any point within 20 px of a hot
      corner (`wvous-*-corner`) set to Lock Screen, Start Screen Saver or Put Display to Sleep;
    - `ui guard` runs before each computer-use batch too, so a dialog that appears between a
      screenshot and a click stops the batch;
    - if preflight shows that events posted at the session tap work but leave HIDIdleTime alone,
      `ui` posts there;
    - `ui tree` on a widget host prints only the subtree inside BatteryPulse's frame, and
      `ui tree --app "System Settings" --match BatteryPulse` prints only whether the row exists;
    - CI: `swiftc -typecheck` beside `frames.swift`. The guard suites scan only `Sources/`, so
      they don't apply; every call is public API.
  - **`frames.swift`:** print the movie's frame rate and dump every frame (`frames dump <movie>
    <dir> 0.0167`, zero tolerance); the sheet keeps at most 120 evenly picked frames, `frames.tsv`
    lists every frame, and `fill_frames` crops the darkest ones to the window's rectangle.
  - **`record_clip`:** fires the minimize itself 1 s into the clip, with no `DO` line and no sound
    at night: a 3-second clip with `AXMinimized`, a 6-second clip (Session A's `FILL_SECONDS`)
    with P5's posted Shift around a click on `AXMinimizeButton` (§6 "Proofs"). The restore clip
    fires a posted Shift around a click on the window's Dock tile, or sets `AXMinimized` false.
  - **`pages`:** CGEvent clicks at the sidebar rows' AX frames on the cue schedule instead of
    `say` and notifications.
  - **F12:** `curl -s https://api.github.com/rate_limit` (unauthenticated, the limit the app
    uses; `gh api rate_limit` would show the token's); F12 runs with at least 10 requests left,
    otherwise it waits while other steps run, then moves to the morning. A VPN is recorded only
    as active yes or no.
  - **`restore`:** split into `gui` (the hand-over), `night` (the queue's end) and `morning`. Every
    change first appends `setting, original, new` to `~/bp-062/B/changes.tsv`, and restore works
    from that file, not from the session's context, so it survives a compaction. A setting whose
    original is "unknown" is never changed. The computer-use items are steps of their own;
    `restore_prompts` keeps only what needs him: turning the Focus off and, unless he kept it,
    revoking Terminal's Accessibility.
  - **`prepare` reads instead of asking:** the Charge Limit (`pmset -g battlimit` on the adapter
    [unverified below the limit: Session A saw it only at the hold, and it clears on battery after
    about 300 s, plan-0.7.0 Appendix C finding 9], else a System Settings → Battery shot Claude
    reads); Icon & widget
    style and Dim widgets from a defaults diff (`defaults read -g`, `com.apple.WindowManager`)
    plus a System Settings shot Claude reads; Open at login by an AX read of BatteryPulse's own
    toggle; click-to-show-desktop (`EnableStandardClickToShowDesktop`), the hot corners and the
    screen saver's idle time; the wallpaper (a still image, or a dynamic or aerial one, which
    restore puts back by computer use from prepare's shot). It generates the bright and busy
    wallpapers as PNGs.
  - **Judgments with pixel checks:** every `judge` answer pairs Claude's reading of the picture
    with the script's measurement where one exists (the darkest frame's luminance inside the
    window's rectangle for a black frame; V1b's pixel comparison; a widget crop's variance for
    blank or grey; a menu bar crop's diff). When the two disagree, or Claude is unsure, the
    answer is 3 with a note and a crop, for the morning batch. Each `judge` question in
    `SESSION-B.md` has written criteria and a default.
  - **"Not checked" fallbacks:** every automated step records "not checked" or "not run" with its
    reason and moves on; nothing waits for a person (§6's steps name each fallback under "If it
    can't").
  - **The report and `send`:** the energy table's new columns; the results branch and file become
    `claude/062-session-b` and `sessions/B.md` (hard-coded for Session A today); `send` refuses
    a `B.md` line with the ComputerName (`scutil --get ComputerName`), his full name, an accessory
    name from `pmset -g accps`, a VPN name or the network's name; window owners appear only when
    they are `com.apple.*` ("another app" otherwise), and assertions only as BatteryPulse lines.
  - **CI:** a `queue --dry-run` on Linux with stub `pmset`, `ioreg` and `notifyutil`, to exercise
    the order, the retries and the thresholds (the Linux job's step, for default, low and late).
  - **As merged** (2026-10-24, in three steps; §5): where the merged script is stricter than the
    bullets above (ui's processes and panes, the targets every event names, the screen saver read
    from its window, the Claude detector's baseline, the morning `continue`, the attach rules),
    the script and Appendix C's WP-21 row hold.
- **Output:**
  - The "Performance baseline (0.6.1 → 0.6.2)" tables in ROADMAP, with energy rows for the first
    time.
  - The 0.6.2 notes' energy line.
  - ROADMAP's "power in the menu bar for an hour" is reworded to the alternated 5-minute runs
    (WP-22).
- **Files:** `docs/plans/0.6.2/m5-session.sh` and its swap helper; `docs/plans/0.6.2/ui.swift`,
  `frames.swift`, and the runbook `docs/plans/0.6.2/SESSION-B.md`, which D1 adds (§6);
  `scripts/rusage.swift` (the `SuspendingClock` duration); in ci.yml, the `bash -n` line and the
  helpers' type-checks in "Check the verification scripts" and the Linux job's dry-run step, all
  removed with the folder in D3.
- **Acceptance:** `bash -n` passes in CI, `ui.swift` type-checks, and the `send` comment has a line
  for every Appendix C row the sessions own.
- **Effort:** M, 4 runs: 2 for the script (Session A's), 2 for the hands-free mode; plus the
  sessions. The hands-free mode **merged** in three steps (`075abdd`, `87c883d`, `780ff10`,
  2026-10-24; §5, Appendix C) after its implementation, two review rounds, a third safety pass and
  a delta pass; none of it has run on a Mac, so Session B's proofs and preflight check it first.

### WP-22: Guards and docs (P1, merges last)

- **Items:** each rule or doc line is conditional on its item and gets one commit (as WP-12 did).
  - **CLAUDE.md:**
    - `BatterySource` in the layout (its target, library product and `BatterySourceTests`; the
      `BatteryProvider`, `MacBatteryProvider`, `IOSBatteryProvider`, `AccessoryProvider` and
      `MacAccessoryProvider` (the demo providers stay), `SMCClient`, `SystemNotifications` and
      `Diagnostics` leave BatteryKit's line, as merged in round B2), and "an app and a BatterySource twin";
    - `read`'s four triggers (`full`, `live`, `cached`, `cached.slow`) and the `registry.missed`
      event in the signpost list (round B1);
    - E4b's two decisions (`BatteryReadScope`'s `rereadsRegistry` and `readsAllSMCKeys`;
      `RegistryReadPolicy` with its 5-minute safety net, as merged in round B1);
    - E20's isolation (a nonisolated provider; the monitor's `@concurrent` reads);
    - main actor by default for the app;
    - the `diskutil` installer;
    - WindowLook's minimize fill: the opaque graphite for Clear and Translucent Dark, Translucent
      Light's own wash (G-13a, round B1);
    - strict memory safety for BatterySource and BatteryKit (WP-19, round B3): the unsafe-code
      sentence names the four strict targets (BatteryCore, BatterySource, BatteryKit, bpulse), the
      `Unsafe:` reason comment on every `unsafe`, the four `@safe` types (`MacAccessoryProvider`,
      `MobileDeviceLibrary`, `MobileDeviceLink`, `USBDeviceWatcher`'s `Watch`) and
      `SecurityGuardTests`' escapes and strict-target test, and leaves the app's `proc_*` calls
      (`WidgetRefresher`) and `UpdateInstaller`'s `Unmanaged<CFError>` as the only unmarked
      unsafe code;
    - `release-stats.swift` in the `scripts/` list (download counts per release, WP-19, round B3);
    - the CI lines: the Linux job's DocC link check of BatteryCore ("Check the documentation
      links", SW-21) and the macOS job's peak-memory table in the step summary (C2), WP-19.
  - **Guards:** none beyond the packages' own. WP-10 holds the isolation pin, and
    `EnergyGuardTests` stays unchanged because the safety net adds no sleep.
  - **USER_GUIDE:** Clear's known issue (`docs/USER_GUIDE.md:162-163`) removed (if G-13a passes);
    graduated styles described without "beta"; the installer text if it names `hdiutil` anywhere.
    If E4b lands, one sentence in the refresh paragraph (`docs/USER_GUIDE.md:124-132`, which says
    live values refresh every 2 seconds): capacities, temperature, cell voltages and adapter
    details update when macOS reports new battery data, and at least every 5 minutes (the
    safety-net age that merged in round B1, unless G-14b's "no E4b" commit lands); Power and Raw Data
    read them on every refresh.
  - **README:** the Architecture block (`README.md:218-226`) gains a BatterySource row, and
    BatteryKit's row loses the IOKit and UIDevice providers, which K-03 moved (WP-15's review,
    Appendix C).
  - **ROADMAP:**
    - Stage 1.7 ticked (its read-path line, `docs/ROADMAP.md:585-589`, with E3b's
      `timeremaining` dropped, B1), and Stage 1.3's light and dark comparison ticked (V1d).
    - Stage 1.2 ticked: round A0 passed (Appendix C). The in-app update 0.6.0 → 0.6.1 installed
      and relaunched, and kept the desktop widget, showing the current charge, and Open at login.
      The widget line keeps its note that one DMG replacement (0.3.0 → 0.3.1) lost placed widgets,
      which stays documented.
    - The window-style Decisions line updated (G-13c).
    - "Performance baseline (0.6.1 → 0.6.2)".
    - Stage 3's "how often the mAh values change", from Session A's ioreg samples; the App Nap
      half stays open.
    - Stage 1.1's Charge Limit line gains what Session A found (Appendix C): paused at the limit,
      `ChargerData.NotChargingReason` is bit 24 (0x01000000), and the configured value is in no
      registry key. The box stays open until a capture is committed as a fixture (QUA-05,
      `docs/plans/1.0/ROADMAP.md`).
    - The 0.7 stage with §9.1's phases and CB-02 (D3 adds the link to
      `docs/plans/0.7.0/widgets.md`).
    - Stage 1.7's readability line (`docs/ROADMAP.md:603-604`) says what landed (WP-19, Appendix
      C): SW-13 for BatterySource and BatteryKit, the DocC check of BatteryCore, C2 as a
      peak-footprint table without a budget, SUI-09 needing no change, and SZ-11 and SZ-14
      measured but not adopted (WP-15); SZ-08 stays for the next glossary work. Its CI line
      (`:605-606`) is ticked: `actions/checkout` v7.0.1 and `upload-artifact` v7.0.2, pinned by
      SHA; v6.1.0 turned down.
- **Files:** `CLAUDE.md`, `docs/USER_GUIDE.md`, `docs/ROADMAP.md`, `README.md`.
- **Acceptance:** `LocalizationCatalogTests` (its `docs/` scan) is green, and the review confirms
  every new CLAUDE.md line against the merged code with `git grep`.
- **Effort:** M, 2 runs. **Risk:** low.

### D1-D3: Freeze, Session B, release

As PLAN §3.5.
- **D1:**
  - measures (§4a-style Linux benches and code counts against `v0.6.1`);
  - runs the golden, storage and settings diffs. The settings-and-identifiers `git grep` of PLAN
    §5 prints 38 lines at `9410861` (`betaWindowStyles` and an escaped-quote match in
    `scripts/perf-sample.ndjson` are new), and 38 at the RC (no key is added: WP-16 item 5
    doesn't run, A0);
  - sets the ceilings (the `widget_*` ones to the RC's numbers plus about 5 %, in a commit of their
    own, WP-15 item 4; at round B2's head (`fe0a9a0`) the widget binary is 778,640 B and its `__text` 489,132 B);
  - drafts the notes (`## What's new in 0.6.2`, checked by CB-06) and opens the draft PR with the
    session checklist. The notes list only user-visible changes, each only if its item landed
    (as PLAN §7 item 2 did):
    - Clear minimizes without a black frame (and Translucent in the dark appearance, while
      `72b790d` stays);
    - each style that graduates, or that both stay beta;
    - Check Now no longer fails while an automatic check runs, if E10 lands;
    - the iPhone and iPad page names the connection its values came over, if WP-23 lands;
    - the energy line with the S1 and S2 numbers (WP-21);
    - "Updating from 0.6.1: Install and Relaunch."
  - dispatches the RC as 0.5.99 for F12 and a profiling RC built the way SPIKE-A2's is (§5 A2′;
    Xcode is installed, Q-B7); finalizes the session script, with Session A's fixes (Appendix C):
    `plist_count` splits `pmset -g accps -xml`'s back-to-back plists, every recording ends by
    `screencapture -v -V <seconds>` alone, window IDs come without the `osascript` window query,
    and F12 checks the pre-swap extension end (WP-16 item 6); and adds the runbook
    `docs/plans/0.6.2/SESSION-B.md` for WP-21's hands-free mode (merged 2026-10-24, §5), with its
    rules (§6) and a section "After publishing" for D3's short session;
  - for WP-21's merged script (Appendix C): pins `RUN_RC`, `ARTIFACT_RC` and `ARTIFACT_RCP`
    (`m5-session.sh:70-72`) to the RC's and the profiling RC's run and artifacts, or leaves them
    empty and relies on `rc_locate` (the newest successful CI run of the integration branch whose
    code equals the frozen worktree's, preferring the 0.5.99 artifact). `SESSION-B.md` uses the
    script's command names (`prepare`, `prepare reads`, `proof`, `preflight`, `widget`,
    `desktop-spot`, `v01`, `f11 alert`, `devices forget`, `arm open`, `burst`, `mark away`,
    `heartbeat`, `memory`, `f6`, `f8`, `f9`, `relaunch`, `f11 login|listed`,
    `f12 rate|before|after`, `install C`, `case`, `styleshot`, `gradshot`, `audit estimate`, `v1b`,
    `pages`, `pane`, `open-app`, `measure`, `judge`, `change`, `restored`, `ui …`,
    `restore gui|morning`, `ready`, `continue`, `morning`, `batch`, `send`, `charge-limit`,
    `menu-bar-shots`, `wp18`; any time `status`, `note`, `shot`, `crop`, `attach`, `unattach`), the
    banner texts `ui banner` looks for ("This is how battery alerts will look" for V-01, "You can
    unplug the power adapter" for F11), F12's verdict lines (every extension process ended within
    1,500 ms; no `BatteryPulseWidget` started before the swap; no eject-failure line; Finder's
    on-screen windows during the install), each `judge` question's criteria and default, and the
    morning's list of the allow rules he added, which the script can't read, so the session asks
    him.
- **D2** is Session B, hands-free (§6).
- **D3:**
  - applies the answers or the defaults and records the numbers;
  - before removing the plan folder, moves §8, §9.1, §10's Q-W block with its answers and
    Appendix C's W0 rows to `docs/plans/0.7.0/widgets.md` (English only: `LocalizationCatalogTests`
    scans `docs/`), and links it from ROADMAP's 0.7 stage, so 0.7's plan cites a file that exists;
  - before `claude/nice-faraday-k08mhb` and the `claude/062-*` branches are deleted, copies
    `m5-session.sh`, its swap helper, the hands-free helpers (`ui.swift`, `frames.swift`,
    `SESSION-B.md`) and the whole of Appendix C into `docs/plans/0.7.0/` beside `widgets.md`
    (plan-0.7.0 D-1, D-11, Q7-8; RD §3.1 item 6);
  - removes `docs/plans/0.6.2/` (and ci.yml's lines that name it: the Linux job's queue dry-run
    step, and the `bash -n` line and the helpers' type-checks in "Check the verification scripts")
    and releases;
  - runs the after-publishing check in a short local session with computer use, as Session B
    runs (about 2 minutes of the maintainer's time: the start line and the approvals). The plan
    folder is gone by then, so the line reads the copy of `SESSION-B.md` from a ref that
    survives, the release PR's head (plan-0.7.0 Q7-8); D3 gives him the line with `<n>` filled in
    (Session B's shape, with the flags and the variable as checked in its once-before step):

    ```
    DISABLE_AUTOUPDATER=1 claude --allowedTools 'Bash(bash ~/bp-062/D3/run/docs/plans/0.7.0/m5-session.sh:*)' --permission-mode auto 'Run the BatteryPulse 0.6.2 after-publishing check hands-free: in ~/BatteryPulse run git fetch origin refs/pull/<n>/head && git show FETCH_HEAD:docs/plans/0.7.0/SESSION-B.md, then follow its section After publishing.'
    ```

    That section first makes its own frozen worktree `~/bp-062/D3/run` at FETCH_HEAD, the commit
    the runbook was read from, and works from the copies in `docs/plans/0.7.0/` there, every
    command through that script's one prefix, so the line's one allow rule covers them. It runs PLAN §4b's
    list at `6aec4d2` with 0.6.2 in place of 0.6.1 (computer use or an AX press for Install and
    Relaunch; Claude reads About for the new version, History for the past days, the settings
    and the menu bar look for no change, and the widget for a current value; `codesign -dv
    --verbose=4` shows `flags=0x10002(adhoc,runtime)`; `xattr -l` shows no quarantine; the login
    item is still listed if it was on, by the `ui tree` read of Login Items instead of `sudo
    sfltool dumpbtm`, which would need his password; notification permission is kept; on any
    failure, `gh release edit v0.6.2 --prerelease` on his yes, as plan-0.7.0 §6.4 step 5 does),
    plus V-01's post-update half (the widget reloaded after the update);
  - compares the widget's charge and "Lasts until" with the popover's (within 2 points and about
    15 minutes, `994c09d`): the short session opens the popover by a click and compares at its
    end, and the maintainer's everyday use on the first day stands in for a second look;
  - **a week after publishing,** runs `swift scripts/release-stats.swift` (WP-19) and adds its DMG
    and `.sig` download columns to ROADMAP's Releases table, for 0.2.0-0.6.2, in a commit of its
    own. If the script was cut, `gh api 'repos/{owner}/{repo}/releases?per_page=100' --jq '.[] |
    .tag_name as $t | .assets[] | "\($t) \(.name) \(.download_count)"'` gives the same counts. Each in-app install
    fetches the `.sig`, so its count is a privacy-free proxy for in-app updates. 0.6.2 changes
    nothing the app sends. Every later release does the same (§10, "Usage evidence"); from 0.7 on,
    the table also gains the Count column (§10, "Further answers").

`WhatsNew.version` stays at 0.6.0 even if a style graduates: a graduation goes in the release notes
only (Q-B5, decided by delegation).

---

## 5. Order and parallelism

At most two agents, and never two packages on one file (mechanical rebase-overs are exempt, as in
0.6.1).

| Round | Slot 1 | Slot 2 | Waits for |
|---|---|---|---|
| A0 | Intake: 0.6.1's after-publishing results (any failure would have become a P1 item). **Passed** (the maintainer, 2026-10-22; Appendix C): no P1 item | | the 0.6.1 release (done) |
| A1 | WP-10 | WP-W0's W0-1 (CI metadata step) | A0 |
| A2 | WP-14a (E20) | WP-W0's SPIKE-C, SPIKE-I and SPIKE-W (CI builds on the spike branch) | WP-10 merged (WP-14a edits `HistoryRecorder`); W0-1's answer |
| A2′ | SPIKE-A2: the A2 integration tip plus the Clear fill switch (today's fill or (b), Q-B2), a normal CI build (throwaway branch `claude/062-spike-a2`); the field run, V-01 and the fill recordings need no profiling. Because Xcode is installed (Q-B7), the branch also adds a last step to the macOS job, after "Install the way 0.6.0 does, then launch" (the job's last step today), that runs `PROFILING=1 scripts/build-app.sh` and uploads `build/BatteryPulse-profiling.dmg`; it must come last, because `build-app.sh` starts with `rm -rf build` (`build-app.sh:60`). A profiling build in the package step would fail the job: the signing smoke, the size report and the upload expect `build/BatteryPulse.dmg` (ci.yml:132-171, `size-report.sh:19-20`), and a profiling build writes `BatteryPulse-profiling.dmg` with unstripped binaries (`build-app.sh:31-34, 185-187`) | | WP-14a merged |
| **Session A** | maintainer: about 65 min, then the 3-hour window | | A2′ |
| B1 | WP-14b (E4b, E3b): **merged** as `43052dd` (head `dc3cca3`) | WP-13: **merged** as `c4803c8` (head `2b2dba0`) | Session A (F13, the pslog, the fill recordings), or 14 days after A2′ on the defaults (WP-14b "When"). **Ran** (2026-10-24) on Session A's window and its interim fill verdicts, not on the defaults; CI green on both heads and on `c4803c8` (run 40046692780); Appendix C |
| B2 | WP-15: **merged** as `bb5132d` (head `fe0a9a0`, CI run 40052102109 green; integration run 40052599901 on `bb5132d` green) | (WP-16 ran early, below) | WP-14b merged (WP-15 git-moves its files and needs `Package.swift` free). **Ran** (2026-10-24); Appendix C |
| B3 | WP-19 (SW-13 on BatterySource's moved files): **merged** as `1bb19d7` (head `fa6de42`, CI run 40056575311 green; integration run 40057041397 on `1bb19d7` green) | WP-17 (with the History riders) | WP-15 merged. WP-19 **ran** (2026-10-24), beside WP-21 (below); Appendix C |
| C1 | WP-21 (script, with the hands-free mode): **merged** in three steps, `075abdd` (head `8149531`), `87c883d` (head `c47e0d2`) and `780ff10` (head `e7e9a7d`); CI green on the three heads (runs 40061684651, 40065666925, 40068681150) and on the three merges (integration runs 40062237144, 40066338727, 40069133831) | WP-22 (merges last) | Phase B. WP-21 **ran** early (2026-10-24, below); Appendix C |
| D1 | freeze the RC | | C1 |
| **Session B** | hands-free: the maintainer about 18-22 min in short moments; the GUI phase and the energy queue run on their own (§6) | | D1 |
| D3 | release | | Session B or its defaults |

- **File ownership:** WP-19's SUI-09 stays in `App/`, and WP-17 in `Main/` and BatteryCore's
  History files. WP-16's item 6 edited `App/WidgetRefresher.swift` and `IsolationGuardTests` in
  its early round (below), which WP-23 doesn't touch.
- **Ran early (2026-10-23): WP-16 and WP-23,** beside each other, ahead of B1, because neither
  shares a file with B1's WP-14b or WP-13, nor with the other. WP-23 changed only
  `IDeviceSchedule.swift`, `IDeviceMonitor.swift` and their tests (not `DeviceView.swift`, nor `App/Localized.swift`, which WP-13 edits). Both merged into `claude/nice-faraday-k08mhb`
  (WP-16 as `f8a7445`, WP-23 as `2737b51`; Appendix C), so B2 is WP-15 alone. The later
  packages rebase over them mechanically: WP-16's one `scripts/build-app.sh` hunk is a comment
  (lines 315-320), and WP-15's `import BatterySource` and WP-19's SW-13 markers land in WP-23's
  `IDeviceMonitor.swift` as they would have before.
- **Ran early (2026-10-24): WP-21,** from `c4803c8` (B1's merge), beside WP-15 and then WP-19,
  ahead of its C1 slot: it changes only `docs/plans/0.6.2/` (not this file), `scripts/rusage.swift`
  and ci.yml lines WP-19 didn't touch (the Linux dry-run step and `ui.swift`'s type-check line).
  Its three merges followed WP-19's `1bb19d7`; WP-22 still merges last.
- **Floating work:** WP-20 (SEC-18 only) takes any free slot after B1. WP-23 (the device
  connection label) was to take a free slot from B1 on, never beside WP-15, WP-17 or WP-19's
  SW-13 (WP-23 "When"); it ran early, beside WP-16 (above). WP-18 runs inside Session B (§6) and
  blocks nothing; SZ-10's icon source is prepared by a cloud run before D1 (1 run, §7.2).

---

## 6. The M5 sessions

Both sessions use one script, `bash docs/plans/0.6.2/m5-session.sh <step>`, built from the 0.6.1
script, with prepare, backup, restore, `send` to the PR and the `perf` log stream. Session A is
run by a local Claude Code session with the maintainer's hands (`SESSION.md`); Session B is
hands-free: the same kind of session, the Claude Code CLI in Terminal with computer use, does the
hands-on steps itself, and the energy queue runs as a plain script (WP-21's hands-free mode,
`SESSION-B.md`; §10, "The hands-free sessions").

Every build stays in its DMG, and the script installs it into `/Applications` the way
`UpdateInstaller` does (WP-W0 "Install"), so only `/Applications/BatteryPulse.app` exists and macOS
can't pick up another copy's widget. The wording rules of §3 apply to every question.

**Backup and restore.** The 0.6.1 script kept the first backup for good (`backup_once`,
`m5-session.sh:416-421` at `6aec4d2`), and its restore put back the defaults domain but not
Application Support (`restore_settings` :244-248, `step_restore` :867-876). In 0.6.2:
- Each session's prepare takes a fresh backup into its own folder, `~/bp-062/A` or `~/bp-062/B`.
- Prepare records, and prints: the installed app; the `io.github.nikitausov.BatteryPulse` defaults
  domain; `~/Library/Application Support/io.github.nikitausov.BatteryPulse`; the appearance and the
  wallpaper; `lowpowermode`; and, asked once in Session A because the script can't read them
  reliably, the Icon & widget style, Dim widgets on desktop, whether Open at login is on (it is
  `SMAppService` state, not a defaults key: `App/AppSettings.swift:307-319`), the Charge Limit in
  System Settings → Battery (no registry key holds it, Appendix C), and whether Terminal is
  already listed under System Settings → Privacy & Security → Accessibility. Session B's prepare
  reads them instead (WP-21: `pmset -g battlimit`, a defaults diff and a System Settings shot, an
  AX read of Open at login; Terminal's grants are known from Session A). A value it can't read is
  "unknown", and a setting whose original is unknown is never changed: the steps that need it are
  "not checked".
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
  - then, in Session A, prompts for what only a hand can reset: "Turn VoiceOver off
    (Command-F5)"; "Set Text size back"; "Set System Settings → Appearance → Icon & widget style
    back to <value printed at prepare>", and the same for Dim widgets on desktop; "If Open at login
    was on before the session, turn it on again in Settings → General"; "Set the Charge Limit in
    System Settings → Battery back to <value printed at prepare>"; and, if Terminal wasn't listed
    at prepare, "Turn Terminal off (or remove it) in System Settings → Privacy & Security →
    Accessibility".
  - Session A's restore covers neither, so the maintainer puts both back by hand: he changed the
    Charge Limit (80, 100, 80) for the capture, and allowed Accessibility for Terminal when a
    window query through `osascript` asked for it (Appendix C).
  - **In Session B,** restore is split into `gui`, `night` and `morning` and works from
    `changes.tsv` (WP-21); the session puts the GUI items back itself, by AX, System Events or
    computer use, and confirms each with a read or a shot. What stays for his hand is turning the
    Focus off and, unless he chose to keep it, revoking Terminal's Accessibility (10 seconds).
  - **Permissions in Session B:** it asks for no permission Session A didn't give. It runs on
    Terminal's grants from Session A (Screen Recording, Accessibility, Automation of System Events
    and BatteryPulse), which computer use in the CLI uses too. He was told to keep Accessibility
    until Session B; if he revoked it after Session A, preflight asks again while he is there (one
    prompt, then the switch with Touch ID or his password). His yes at the start decides whether
    Accessibility stays until 0.7's Session R (his explicit choice, against Appendix C's "revert
    after the session") or is revoked in B's morning (the default; Session R's preflight then asks
    again while he is there). D1's script still finds window IDs without an `osascript` window
    query (CGWindowList).

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

### Session B (release candidate, hands-free; about 18-22 minutes of the maintainer's time, the rest on its own)

One local Claude Code session on the M5 runs Session B with computer use, and a plain script in a
second Terminal window, the arm window, runs the energy queue (WP-21's hands-free mode; why one
session, and why the CLI: §10, "The hands-free sessions"). The session does every step below
itself: the script, AX, CGEvent, CGWindowList and System Events first, computer use where those
can't reach, and its own judgment of the pictures. The maintainer does only what needs a person:
the start line and one yes to the list of changes, quitting his own apps, the Focus on and off, the adapter, the lid and the morning login, his password at bedtime, the permission prompts, the taste questions, his typed "continue", revoking Terminal's Accessibility unless he keeps it, and his yes before `send`. An automated step that fails records "not checked" or "not run" with its reason, and the
session moves on; its gate takes its default (§7.1). The runbook is
`docs/plans/0.6.2/SESSION-B.md` (D1).

**His part:** about 18-22 minutes, or 13-17 without the optional burst. Before the hands-free mode it
was about 100 minutes (95 hands-on, 3 on the restore list), plus WP-18's hour.

| When | What he does | Time |
|---|---|---|
| Once, any day before | Quit Session A's Claude session (one Claude session at a time on the Mac). In Terminal: `claude update`; in `~/BatteryPulse`, `claude`, then `/mcp` → `computer-use` → Enable (kept per project; interactive sessions only); `/status` shows a plan that includes computer use. In the same session he asks Claude to check the start line's flags (below) against `claude --help` and the CLI's documentation | 2 min |
| The start, in the evening, on the adapter | In Terminal, in `~/BatteryPulse`, he pastes the start line below (his choice; no agent sets a permission mode or adds a rule), types `/usage` when the session asks, and gives one yes to the list of changes, with his bedtime. He may then leave for about 10 minutes while the session builds (B0a). At its beep: he quits his own apps, approves the app list (one prompt), allows Accessibility for Terminal again if he revoked it after Session A (one prompt, from preflight), and answers any other first-time prompt preflight brings up now | 5-7 min (about 1, then 4-6 at the beep) |
| Right after: the burst (optional) | Unplug and plug in at the beeps, 3 times, 1 minute apart, ending plugged in (skipped: S8 is "not run"). Burst or not, he then turns a Focus on in Control Center (one click, once the session says the banners are done) and leaves the Mac on the adapter with the lid open | 5 min |
| Bedtime | In the Terminal window "BatteryPulse arm": if it says ready, press Return and type his password; then unplug the adapter and leave the lid open. If it says the session is still working, he only unplugs, and the Low Power Mode run is "not run" | 1 min |
| Morning | Close the lid for a minute, open it and log in (V-01's lid and wake, and the evidence "continue" needs, B7), plug in, write "continue" and keep off the Mac for about 3 minutes. Then the batch: one contact sheet per beta style for step 3's y and its two plain questions, SZ-10's y, and any picture the session answered 3. Then his yes to `send`, given at the Mac after the session opens one contact sheet of every attached image and summarizes `B.md`'s text. Last, the Focus off and, unless he keeps it for Session R, Terminal's Accessibility off (10 s) | 5-7 min |

The start line, in the pattern of Session A's sentence, as one line he pastes [check the flags on
his CLI in the once-before step]:

```
DISABLE_AUTOUPDATER=1 claude --allowedTools 'Bash(bash ~/bp-062/B/run/docs/plans/0.6.2/m5-session.sh:*)' --permission-mode auto 'Run the BatteryPulse M5 Session B hands-free: in ~/BatteryPulse run git fetch origin claude/nice-faraday-k08mhb && git show FETCH_HEAD:docs/plans/0.6.2/SESSION-B.md, then follow that runbook from its first step.'
```

- One allow rule covers every command the session runs once B0a's worktree exists, since all of
  them go through the frozen script's prefix (the rules below); the start sentence's `git fetch`
  and `git show` and the worktree's creation come before it, under auto mode. The rule lasts for
  this session only, and he adds no other.
- `--allowedTools` comes before `--permission-mode`, so its list of rules ends before the
  sentence.
- The single quotes keep the shell from running anything inside the sentence, so the sentence has
  no backticks and no apostrophe.
- `DISABLE_AUTOUPDATER=1` keeps the CLI from updating itself overnight: an update's child
  processes would count against a run (WP-21's Claude detector).

Remote Control (`claude --remote-control`) stays off by default. At night it adds nothing, and it
would store every desktop screenshot on his Claude account. "Bedtime" is whenever he leaves the
Mac for the night, or for about two hours: the same order works by day.

**The yes-list** (one yes at the start, before anything changes). The session may change these. It
writes each change to `changes.tsv` first and puts each back:
- the installed BatteryPulse (the session's builds replace it; the backup puts his back);
- the appearance, the wallpaper (to the generated bright and busy PNGs), Icon & widget style, Dim
  widgets on desktop and Text size;
- desktop widgets: a small and a medium added if either is missing, large and extra large added
  for F8, a blank one removed and added again, P10's test widget added and removed, and Session
  A's dead Test widget removed (not put back);
- Increase Contrast and Reduce Transparency, for the optional passes, and Stage 1.4's pass:
  Reduce Motion, Prefer Cross-Fade Transitions, Show Borders and the Liquid Glass slider;
- brightness, auto-brightness and True Tone, for the queue's energy setup;
- Low Power Mode, for one run (and off for the other runs, if it is set on for battery);
- BatteryPulse's settings and data, the widget's included (Clear History; the backup restores it),
  and its remembered iPhones and iPads, removed for the session so no picture shows their names
  (the backup puts them back; WP-21).

The same message asks five optional questions:
- the Charge Limit 80 → 100 → 80 in the morning-away block, at most 10 minutes at 100 %;
- keeping the large and extra-large widgets for 0.7's Session R;
- keeping Terminal's Accessibility until Session R (default: revoked in the morning);
- his bedtime (default: 4 hours after the start);
- whether the Charge Limit slider asked for a password or Touch ID in Session A. If it did, the
  capture needs him and is "not run".

Never on the list: a VPN (F12 waits for GitHub instead), the Dock's slow-motion key or any other
undocumented system key, and anything in Privacy & Security, Users & Groups or Passwords.

**The blocks, in order.** Every GUI step and every display-on check comes before `ready`. After it,
only the queue runs, and it draws nothing but its own runs. The session ends its turn at `ready`
and acts again only on his "continue".
- **B0a, the start** (on the adapter; he is there for the paste and the yes, about 1 min, then he
  may leave; about 10 min [estimate], no prompt expected; "B0" below means B0a and B0b):
  - The yes-list and his bedtime (above), first, before anything changes; `changes.tsv` started.
    The same message asks him once to type `/usage`, which shows how much of his plan's limit is
    left [unverified: whether its result reaches the session; if not, he says it with his yes].
  - Step 1's first half (prepare): the frozen worktree `~/bp-062/B/run` at FETCH_HEAD, the commit
    the runbook was read from (a later fix goes to the next session, never into a running one),
    the fetches, the builds (`bpulse`, `ui`, `frames`, `perf-stats`, `rusage`), the backup, his
    remembered iPhones and iPads removed for the session, and the RC installed.
  - Then a beep.
- **B0b, at the beep** (he is there; 4-6 min):
  - He quits his own apps, so the shots from here on don't show them.
  - Step 1's second half: prepare's reads and shots.
  - Preflight (WP-21): the proofs below and one run of every command family.
  - The computer-use app batch, in one request: BatteryPulse, System Settings, Finder (for the
    desktop and the Dock), Notification Center, the widget gallery's host (P1 names it), TextEdit,
    Accessibility Inspector, Xcode, and Numbers if the spreadsheet check runs. The session opens
    each surface once, so a surprise approval comes now. Control Center isn't needed: he turns the
    Focus on himself.
  - The banners, while he is there and before the Focus: V-01's two test notifications with their
    banner clicks (step 2), and F11's alert (step 4; at his 80 % limit, the 80 step fires within
    seconds).
  - WP-23's optional device check, if an iPhone or iPad is at hand, then `devices forget`
    (Optional, "The device connection label").
  - The arm window opens (`open -a Terminal ~/bp-062/B/arm.command`). It keeps the display awake
    for the GUI phase and waits at a plain prompt. It asks for nothing yet.
- **B1, the burst** (he is there; about 5 min; step 7): the session waits inside the `burst` call, so
  it doesn't touch BatteryPulse. Each power event is stamped, and P12 runs at the first unplug.
  The burst ends plugged in. Then `mark away`: no sound or speech from here until his morning
  "continue". It warns while BatteryPulse still remembers a device by name (`devices forget`
  first).
- **B2, the GUI phase** (on the adapter, he is away; about 2.5-3.5 hours at computer use's pace
  [estimate]). It stops 10 minutes before his bedtime, or 4 hours after the start. What is left
  then becomes "not run (time)", or moves to the morning-away block. The session touches
  `~/bp-062/B/heartbeat` after each step and between computer-use batches:
  1. memory (step 7), first, on the backed-up history;
  2. the placed widgets: a shot; large and extra large added for F8; the dead Test widget shot
     once, then removed;
  3. V-01's other half (step 2), without Clear History;
  4. F6, F8, F9 and F11's login item (step 4), on the real history;
  5. the beta styles (step 3), whose History shots need it too; then Clear History (step 2's last
     item), before the page switches, as in Session A;
  6. the page switches (step 5);
  7. F12 (step 6), when GitHub allows it, else later in B2, else in the morning; then
     `install_build C`, so the rest of B2 runs on the RC;
  8. WP-18: SUI-17, SUI-19, then SZ-10's shots;
  9. the optional extras while time allows (below);
  10. `v01 check` for the RC's window (step 2).
- **B3, the hand-over** (about 5 min):
  - `restore gui` (step 10).
  - TextEdit (its empty `bp-062-cover.txt`, so no save prompt), System Settings, Accessibility
    Inspector and Xcode are closed and quit by AX presses, not by Apple Events (TextEdit would be a
    new Automation target), and only those the script opened (`launched.tsv`); any other still
    open is named for him.
  - The energy setup: brightness about half, auto-brightness and True Tone off, by computer use on
    the Displays pane (P8's URL), with no key press (`ui`'s own rule). The energy-setup answer
    is recorded.
  - Every background task is stopped, and nothing is scheduled.
  - Then `ready`, its last call, and the session ends its turn. A message that reaches it after
    `ready` gets a text-only answer ("results in the morning"), with no tool call.
- **B4, bedtime and the queue** (script only, about 171 minutes by the script's plan, with S6 starting about 147 minutes in, plus the cooldown and any retries; about 100 before the warm-up and the extra pairs of 2026-10-24): his Return,
  password and unplug, then the queue (step 8) in the arm window, after the cooldown and a quiet
  minute. `queue.started` is already up: arm writes it as soon as it decides to start, here at
  `ready` (WP-21).
- **B5, the queue's end** (draws nothing):
  - Low Power Mode goes back (the EXIT trap); the sampler and the pslog stop; the queue's section
    is written; `restore night` runs; `queue.started` is removed.
  - Arm starts a `log stream` with `PERF_PREDICATE`, to test whether a stream survives sleep (it
    decides 0.7's Session R step 12).
  - `sudo -k`; `caffeinate` is released.
- **B6, the night:** the Mac sleeps on its own. This is the sleep-hygiene night on the RC (WP-21).
- **B7, the morning,** on his "continue" (if `queue.started` still exists, the session tells him
  when the queue ends and starts only then):
  - `continue` opens the fence only on the queue's end (or an arm window
    that stopped), the screen unlocked at the console with the lid open, his input at most 15
    minutes old (HIDIdleTime, or the HID event state where P6 finds that it ignores posted events),
    and a lid wake, or a Clamshell Sleep, in `pmset -g log` after the queue's last sign of life
    (Apple silicon's lowercase "lid" wake line counts); the lid wake and the unlocked screen are
    what software can't make. Without the lid line it refuses and asks for the lid close once more;
  - the after-lid shot and `v01 check`'s morning half;
  - `pmset -g log` for sleep hygiene, and the `log stream` result;
  - `restore morning` (step 10);
  - the report and the morning batch, then `send` after his yes (step 9).

**The morning-away block** (optional, only if he says he leaves the Mac on the adapter for about an
hour): the Charge Limit capture, SUI-19 or SZ-10's shots if B2 didn't reach them, the CSV in
Numbers, and whatever else B2 moved there.

**The steps** (what each checks, how the session does it, and what a failure costs):

1. **prepare** (B0a, then B0b):
   - Prepare's reads (above; WP-21). The session reads prepare's widget shot and adds a small and a
     medium widget if either is missing (computer use: the gallery's click-to-add, then one slow
     `ui drag`).
   - **If it can't:** an unread setting is "unknown" and never changed; missing widgets make F8's
     and F12's widget items "not checked".
2. **V-01 on the RC** (B0, B2, the morning; WP-10, WP-14a):
   - Send Test Notification (`NotificationSettings.swift:66`) by AX press, twice, the second time
     with the window in front. `ui banner` finds each banner in Notification Center's AX tree by
     its English body ("This is how battery alerts will look"), only inside an element labelled
     BatteryPulse, and presses it within 10 s (P2).
   - The menu bar item with a light and a dark bar: the appearance by System Events, a crop of the
     item, and Claude's judgment beside the crop's pixel diff.
   - Raw Data, History, Demo Mode on and off, Check Now (its offer closed by its own button), Clear
     History: AX presses and CGEvent clicks, with computer use as the fallback.
   - The lid: his 1-minute close in the morning.
   - `v01 check` at B2's end counts the "executor" lines and the crash reports for the RC's window.
     Its morning half counts only the RC's crash reports (by their `Version:`) and the executor
     lines of the RC's pids, so build B's runs in the queue don't count against the RC.
   - **If it can't:** per item "not checked"; G-10 still rests on the executor and crash counts.
     Without the lid close: "lid not checked".
3. **Beta styles** (B2; WP-13):
   - **The 8 glass-sheet minimize and restore cases** (Translucent and Clear × Light and Dark × main
     and compact):
     - the style and the appearance set by defaults and System Events, and the window's place by
       AX;
     - the minimize fired by `record_clip` 1 s into the clip: if P5 shows slow motion, a posted
       Shift around a click on `AXMinimizeButton` in a 6-second clip (Session A's
       `FILL_SECONDS`), else `AXMinimized` in a 3-second clip, with every frame dumped and
       calibrated against a Session A case (P4); the restore clip the same way, by a posted Shift
       around a click on the window's Dock tile, or `AXMinimized` false;
     - Standard and Frosted once each, next to a minimized TextEdit window (`bp-062-cover.txt`,
       not Notes);
     - Claude reads `fill_frames`' sheet beside the darkest frame's luminance, and retries once.
       The answers keep their scale: "1 like the window, or an even graphite grey (the chosen
       fill), 2 a black frame or rectangle, 3 something else (note)".
   - **The screenshot set:** 2 wallpapers (bright, busy) × Light and Dark × 3 pages (Overview,
     History with the readout under the pointer, Settings) × Translucent and Clear = 24.
     - The wallpaper and the appearance are set by System Events, the style by defaults and a
       relaunch, and the pages by AX. A CGEvent pointer move brings up the History readout.
     - Each shot is `screencapture -R <window frame>` after the occlusion check. A window-ID
       capture is used only for Standard, because it may leave out what lies behind a glass
       sheet (P3).
     - Claude pre-judges each shot. His y comes in the morning batch, one contact sheet per style.
   - **The graduation shots** (WP-13 item 3), on the bright wallpaper, per beta style ×
     appearance: Raw Data with the inspector open; Demo Mode with its bar; History scrolled under
     the title; the main window in full screen (by `AXFullScreen`, no keystroke) = 16. Plus
     Settings → General beside a Clear window in Light, and the widget gallery behind a Frosted
     window in Light and Dark, by computer use: 19 in all.
   - **The contrast audit:** Accessibility Inspector's audit by computer use (clicks only), for
     each beta style, appearance and page (Overview, History, Settings), with Claude reading its
     results. The fallback is a scripted estimate from AX text frames and pixel luminance.
   - **V1b:** AX presses on the tiles it names, and the existing pixel comparison inside the
     outline; identical pixels pass.
   - **The two plain questions,** in his morning batch: "From 0.6.2 on, offer Translucent without
     the Beta window styles setting? y/n." "And Clear? y/n."
   - **If it can't:**
     - a case "not checked": G-13a falls back to Session A's cases (ship (b) on Clear);
     - missing shots are listed, and a style with a shot missing or not answered y stays beta
       (G-13b's default);
     - "Inspector not run, estimate only": Q-B4 lacks the audit, so that style stays beta;
     - no answer to the plain questions: both stay beta (Q-B4).
4. **F6, F8, F9, F11** (B0, B2):
   - **F11's alert,** in B0 on the adapter. "When charged to" is a picker of 80, 85, 90, 95 and
     100 % (`Settings/NotificationSettings.swift:18-21`), and the alert fires while plugged in once
     the charge reaches it (`BatteryAlerts.swift:70-81`). The script quits the app, writes the
     step to `alertChargeLimit`, deletes the stored `alertState` so the alert starts armed, and
     relaunches. The step:
     - at 80 % or more, the highest step at or below the charge, which fires within seconds;
     - otherwise the lowest step above the charge, only if the Mac reports charging and that step
       is at most 3 points away; it waits up to 6 minutes, while other B0 work goes on.

     `ui banner` finds the banner by its English body ("You can unplug the power adapter"), and a
     crop records it. Otherwise, or with no banner in time, F11-alert is "not run".
   - **F11's login item:** Open at login off by AX. `ui tree --app "System Settings" --match
     BatteryPulse` says whether Login Items still lists it ("1 gone, 2 still listed"), without a
     shot of his list. `restore morning` puts Open at login back as prepare found it.
   - **F6:** every page on real data (E4b's mixed-age snapshot), by AX, a shot each, read by Claude
     against `bpulse --json` taken the same minute.
   - **F8:** the RC's own widget in every family and both languages (G-15). Its
     `supportedFamilies` lists only `.systemSmall` and `.systemMedium`, so every family means
     those two (WP-15's review, Appendix C): the large and extra-large additions of the yes-list
     and the GUI phase, the optional question about keeping them for Session R, and B0's hands-on
     minute under "If it can't" have no RC widget to place, and D1's `SESSION-B.md` drops them.
     Each comparison comes after one fixed action: a CGEvent click on the
     empty desktop spot recorded at prepare, then 1 s, because Dim widgets reacts to the desktop's
     focus. If click-to-show-desktop is on, the spot is clicked again and checked with
     `ui windows`. The Russian half uses the method Session A confirmed (step 3.3). If none
     worked, F8-ru is "not checked": the widget's strings are unchanged since 0.6.1, and
     `scripts/string-tables.swift` already checks that every translated table has every key.
     (`WidgetTextBudget`'s length test arrives with 0.7's W-1.)
   - **F9:** Russian (Overview, Settings, the update warning), by a relaunch with
     `-AppleLanguages (ru)`. Claude checks for truncation, English leftovers and the catalog's
     terms; his wording taste is optional in the batch.
   - A relaunch adds one history sample.
   - **If it can't:** per item "not checked". If the gallery's host can't be approved for computer
     use, adding large and extra large becomes one hands-on minute in B0.
5. **Page switches** (B2; WP-17's after; WP-13 item 3):
   - On the RC with the `perf` stream on: CGEvent clicks at the sidebar rows' AX frames on the
     3-second cue schedule, 10 per page (AX select as the fallback).
   - Then the profiling RC (D1) under `xctrace --no-prompt` with a watchdog, as a background task
     the session waits on (about 10 minutes, the Bash tool's limit per call), followed by 2
     minutes of the main window in Clear for Clear's shadows, recorded with the template the
     script picks from `xcrun xctrace list templates`. The developer-tools dialog is either
     already off (`DevToolsSecurity -status`) or answered in B0 (P9).
   - **If it can't:** the profiling pass is "not run (developer tools asked)", and G-17 keeps the
     plain pass.
6. **F12** (B2; Q-B9):
   - The rate check: `curl -s https://api.github.com/rate_limit`, with at least 10 requests left.
   - Check for Updates, then Install and Relaunch, by AX press. The RC's `diskutil` installer
     installs the real 0.6.1, which relaunches (G-16).
   - Before Install: a CGEvent click on prepare's empty desktop spot, so the widget draws, then
     the widget extension's processes by their executable's path (`pgrep -x` may not match a name
     past macOS's 16-character process name; preflight records both counts).
   - After the relaunch, the script checks that the installer ended the extension before the swap
     (WP-16 item 6): the `update` log's pre-swap line, with every process it found ended (by
     SIGTERM or SIGKILL) within 1,500 ms, and no `BatteryPulseWidget` process started before the
     swap (`ps -o lstart`). Claude gives the 1-4 answer from the before and after widget shots:
     "1 same, 2 blank or grey, 3 gone, 4 different (note)". With no extension running before
     Install, item 6 is recorded as not exercised.
   - Then `install_build C`: the real 0.6.1 is now installed, and the rest of B2 runs on the RC.
   - **If it can't:** "not run: rate-limited", retried later in B2, then in the morning; G-16 by
     its gate.
7. **Burst and memory** (B1, B2):
   - **The burst:** his 3 unplug and plug cycles at the beeps, 1 minute apart, stamped (S8).
   - **Memory:** History → 7 d three times by AX, `phys_footprint` before and after, first in B2.
   - **If it can't:** without the burst, S8 is "not run"; memory is "not checked".
8. **Energy** (B4; WP-21):
   - The queue and its detectors, in WP-21's order: a discarded warm-up, S2 B C B C B C, S1 B C B C B C, S2 with Low Power Mode B C, S4w,
     S5, S10, S7, S3 and the minimized run, the retries, then S6 B C last; medians per scenario and build.
   - Each run starts only on battery, at 50 % or more, after a quiet minute, at a nominal thermal
     state, with the screen unlocked and the main window uncovered (except in S5).
   - S9 isn't run by default; S10 runs if `pmset -g accps` lists accessories.
   - S6 is announced inside its first run, 30 s before the display goes off: a line in the arm
     window and an alert that gives up before the display goes off (a notification would be
     hidden by the Focus). No sound: none plays from `mark away` until his "continue".
   - **If it can't:** a touched, slept, adapter, locked, screen-saver, style-not-in-effect or
     Claude-active run is retried once (none below 56 %), then recorded "not valid"; an LPM run
     isn't retried. Without the password, S2-LPM is "not run". An incomplete energy setup is
     recorded as `energy-setup 2`, and the runs still run.
9. **send** (B7): after his yes at the Mac, to `claude/062-session-b` (`sessions/B.md`), through
   WP-21's privacy lint. Nothing leaves the Mac without the yes, and there are no interim pushes.
   **If it can't:** a lint refusal names the line, and the session drops it, tells him, and sends
   again; a failed push leaves `~/bp-062/B/B.md` and the attached crops in `~/bp-062/B/publish`
   on the Mac, `send` can run again later on the same yes, and D3 otherwise takes the gates'
   defaults.
10. **restore** (B3, B5, B7): `restore gui`, `night` and `morning`, from `changes.tsv`. The morning
    half puts back his app, the defaults domain, Application Support, the widget's data and
    preferences, Open at login as prepare found it, and brightness, auto-brightness and True Tone.
    It confirms the Charge Limit with `pmset -g battlimit` (else a System Settings → Battery shot).
    **If it can't:** each item it can't put
    back heads the morning report, for his hand.

**Optional** (0.6.0 open checks that stay in their stages):
- **The night:** sleep hygiene, the RC installed overnight (B6; WP-21).
- **In B2, while time allows:**
  - Stage 1.3: `scripts/menu-bar-shots.sh` with Increase Contrast and with Reduce Transparency, set
    by computer use, on the display with a notch; the plug state from the burst's stamps; 100 % on
    power and Percentage Inside with one, two and three digits, from Demo Mode [whether a scene
    covers each is unverified].
  - Stage 1.4's accessibility pass: the Liquid Glass slider at both ends, Reduce Motion, Prefer
    Cross-Fade Transitions, Reduce Transparency, Increase Contrast, Show Borders. Each is set by
    computer use, recorded, judged from the frames, and put back.
- **The morning-away block:**
  - The Charge Limit capture, with `bpulse --record` (built by prepare), while the Mac charges to
    his limit after the night's discharge (Stage 1.1, QUA-05). Session A already saw the paused
    state (`NotChargingReason` bit 24, Appendix C), in read-only captures it kept local.
    - On the evening's yes, computer use raises the limit to 100 % for at most 10 minutes, then
      sets it back.
    - `pmset -g battlimit` (else a System Settings → Battery shot) confirms it at the block's end,
      at every restart of the session and
      after every compaction. If it isn't back, the arm window shows an alert with a sound, and the
      morning report's first line says so.
    - The redacted before-and-after captures become a committed fixture only on his yes at `send`.
  - Exported CSV in Numbers, in a Russian and an English region (Stage 6; the Russian region
    through `-AppleLocale` [unverified], else "Russian not checked").
- **The device connection label** (WP-23), if an iPhone or iPad is at hand at the start: he plugs
  its cable in at B0 and pulls it at a beep in B0b, before `mark away` (1 minute more). The session
  refreshes over Wi-Fi and reads whether the page says "Connected over Wi-Fi". Then, still before
  `mark away`, `devices forget` quits the app, removes the session's own device store (the device
  is now remembered by name, which the sidebar shows, so no picture taken while it is gets
  attached) and relaunches it with `readDevices` off; his own remembered devices stay in the
  backup. Otherwise it stays open.

**Proofs.** Some steps rest on behaviour nobody has checked on macOS 27. Each proof but P12 runs in
B0's preflight, a few seconds each, while he is there, so any prompt it raises comes then (the
script's `preflight` runs P2, P6-P9 and P11, and the session calls `proof` for P1, P3, P4, P5 and
P10); P12 runs at the burst's first unplug (B1), and without the burst the queue uses the sampler's
`ExternalConnected` column alone. A failed proof switches its steps to their fallback before the
session goes on, so nothing waits for him later. What is left of Session A may run the ones that
change nothing earlier (P1, P3, P6, P7's reads, P8, and P9's `DevToolsSecurity -status`, writing
only under `~/bp-062/A`), so D1 can fix the script first.

| Proof | Decides | If it fails |
|---|---|---|
| P1: `ui hit` at a widget's centre: the hosting process, role, label, the parent chain and the frame (Session A's VoiceOver read the widget's container as "In BatteryPulse, widget, 9 items", Appendix C) | which process to approve for computer use; the widget click targets (F12, plan-0.7.0 §6.2 step 8); 0.7's tree read | widget points from prepare's shot (pixels to points), confirmed by `ui hit`; else computer use; else "not checked" |
| P2: a probe notification, then Notification Center's AX tree within 3 s | `ui banner` (V-01, F11) | Notification Center opened by an AX click on the clock, and a crop of the banner (no computer-use screenshot with Notification Center open); else "not checked" |
| P3: on Clear, `screencapture -o -l<id>` against `-R<frame>` | how the 24 and the 19 shots and V1b are captured | `-R` after the occlusion check for every style |
| P4: `AXMinimized` during a 3-second clip, every frame dumped, against a Session A case and his verdict on it | G-13a's method | P5's posted Shift; if neither works, the cases are "not checked", and G-13a rests on Session A |
| P5: a posted Shift (a flagsChanged event) around a click on `AXMinimizeButton`: does the animation last 2 s or more? | whether the cases keep Session A's slow motion | `AXMinimized` at normal speed with every frame (P4) |
| P6: HIDIdleTime before and after a 0-pixel move posted at the HID tap, one posted at the session tap, and `caffeinate -u -t 1`; whether `.hidSystemState` ignores posted events | the touch detector; whether `ui` posts at the session tap; whether `ui guard` can hold the session while he touches the Mac | the session still ends its turn before the queue; during B2 only his Esc tells it he is there |
| P7: the wallpaper through System Events; `defaults read com.apple.WindowManager`; the style keys in `defaults read -g`; `AppleICUForce24HourTime` | the wallpaper's restore; the style's read; click-to-show-desktop; 0.7's 24-hour read | a dynamic or aerial wallpaper is put back by computer use from prepare's shot; an unread setting is "unknown" |
| P8: the System Settings pane URLs on 27 (`x-apple.systempreferences:` for Appearance, Desktop & Dock, Displays, Accessibility, Login Items, Battery, Date & Time, Wallpaper) | opening panes without Apple Events | computer use from System Settings' sidebar |
| P9: `DevToolsSecurity -status`, else a 2-second `xctrace` recording | whether the profiling pass can run at night | the dialog answered now; else the profiling pass is "not run" |
| P10: the app batch (which names computer use accepts); one click-to-add of a widget and its removal; a screenshot right after the first action (where computer use's own notification lands); one System Settings click under auto mode | the approval batch; the gallery plan; the crops | an app it refuses: its steps go to scripting, else "not checked"; the gallery: one hands-on minute in B0 |
| P11: the popover opened by a CGEvent click on the menu bar item; 60 s later, still in CGWindowList | S3 | S3 stays open in Stage 1.4 |
| P12: one power-source notification across the burst's first unplug | the queue's unplug waiter | the sampler's `ExternalConnected` column alone |

Preflight also checks, without a proof's fallback:
- a `screencapture` test that Claude judges, which brings up Screen Recording's periodic re-consent
  prompt now if it is due [unverified on 27];
- Apple Events to System Events and to BatteryPulse, and `CGPreflightPostEventAccess`;
- a read of the extension's container preferences, which brings up the other apps' data prompt;
- `pmset -g battlimit` and `pmset -g custom`;
- the hot corners, the screen saver's idle time and the Focus state;
- whether a VPN is active, and the charge;
- `screencapture -v`'s frame rate.

**Rules in the runbook** (so no cloud session is needed mid-run; `SESSION-B.md` holds them all):
- **Frozen:** the runbook, the script and `ui` are fixed at B0. The session never edits them and
  never adopts a later fix.
- **Commands:**
  - Every command after B0a's worktree exists goes through the frozen script's one prefix (`bash
    ~/bp-062/B/run/docs/plans/0.6.2/m5-session.sh <step>`; `ui` only through the script), so the
    start line's one allow rule covers them all; before it, the start sentence's `git fetch` and
    `git show` and `git worktree add ~/bp-062/B/run FETCH_HEAD` run under auto mode.
  - The session never adds or changes a permission rule. The morning report lists any allow rule
    he added beyond the start line's, for him to remove after Session R.
  - The session never retries a command auto mode blocked: that step moves to the morning.
  - A call that may take over 2 minutes (`burst`, F11's wait, `pages`) passes the Bash tool a
    `timeout` of 600000 ms, as Session A's runbook does; anything near the tool's 10-minute limit
    (the `xctrace` pass) runs as a background task the session waits on.
- **Places:** Terminal windows go in the left third, and BatteryPulse's windows and widgets on the
  right, away from the top-right corner where banners land. Window places are recorded at prepare
  and set by AX. AX can't move widgets, so their frames come from P1.
- **A blank or grey widget:** shoot it and answer; then remove it and add it again by computer use,
  and note that.
- **A clip that missed the animation:** retry once, then 3.
- **A banner not seen in 10 s:** look in Notification Center, then 3.
- **A permission or password dialog while he is away:** leave it, record the step "not checked:
  prompt", and go on with the steps that don't need it.
  - The session never types a password and never approves a permission or authorization dialog.
  - It never toggles anything in Privacy & Security, Users & Groups or Passwords.
- **A lock screen, or the lid closed:** stop all GUI work and record "not checked: locked".
- **A script error:** note it and skip the step. A harmless workaround is allowed only if it changes
  no setting outside `changes.tsv`.
- **He touches the Mac during B2:**
  - If `ui guard` can tell his touches apart (P6), the session waits until his last touch is a
    minute old.
  - If he needs the Mac, he presses Esc: computer use stops, and the session's turn ends. He writes
    "go on" when he is done, and the session re-checks the state first.
  - Neither `ui` nor computer use ever sends Esc, which would end the turn.
- **Findings** (crash reports, "executor" lines, black frames): note them and go on.
- **The Charge Limit** changes only on the evening yes, is confirmed by `pmset -g battlimit` (else a
  System Settings → Battery shot), and is always put back.
- **After a compaction:** check the Charge Limit first, then re-read the runbook, `status`,
  `answers.tsv` and `changes.tsv`.
- **Never act after `ready` or once `queue.started` exists,** apart from the text-only answer;
  the session checks for both before every step and every computer-use batch, until his morning
  "continue". On a stale heartbeat arm writes both (`ready` marked stale), so a session that wakes
  up later stays out through the queue and the night.

**Privacy:**
- Computer use's screenshots, and every picture the session reads, go to the model. None goes into
  the repository.
- His Focus, the hidden apps and the apps he quit limit what they show. His other desktop widgets
  are in them, and the start message says so.
- No computer-use screenshot is taken while Notification Center or Control Center is open: AX
  actions and crops of BatteryPulse's frames instead.
- Full-desktop, Notification Center and System Settings shots stay in `~/bp-062/B`. Only crops of
  BatteryPulse's windows, widgets and menu bar item are attached.
- `pmset -g accps`, `pmset -g log` and `scutil` outputs reach `B.md` only as counts or BatteryPulse
  lines.
- `send` runs only after his morning yes (step 9).

**Risks of the hands-free mode:**
- **Computer use is a research preview.** Controls may not be found on macOS 27, and approvals last
  one session. AX and CGEvent come first, every step has its "not checked", and every app is asked
  for at the start.
- **A stall.** Several things would stop the session mid-phase:
  - an auto-mode pause, after 3 classifier blocks in a row or 20 in all;
  - an approval for an app missing from the batch;
  - his plan's usage limit, on a turn of several hours full of images [unverified].

  Preflight rehearses every command family, he types `/usage` once at the start when the session
  asks [unverified: whether the session sees its result], and the arm window
  starts the queue on a stale heartbeat, with `queue.started` and a stale `ready`, written at
  once, keeping a session that wakes up later out of the runs and the night.
- **Posted events reset HIDIdleTime.** This is safe only because the session ends its turn before
  the queue and never acts after `ready` or once `queue.started` exists, which `ui` enforces too.
- **The GUI phase's length is an estimate:** about 130-150 computer-use actions at 5-15 s each, plus
  the clips, the judging and two page passes. On the adapter it costs no charge, and its cap ends it
  before bedtime.
- **The fanless Air warms** in the GUI phase (`xctrace`, Xcode, the recordings). The cooldown, the
  thermal wait and the S2 pairs alternating B and C cover it.
- **The widget host process and its AX tree are unknown on 27.** P1 finds them; the fallback is
  computer use, then "not checked".
- **Normal-speed minimizes may give too few frames to judge.** P4 and P5 decide, against a Session A
  case.
- **Computer use's own notifications** ("Claude is using your computer", at each turn's first action
  and at its end) land at the top right. Widgets stay away from that corner, and shots are cropped
  to BatteryPulse's frames.
- **The lid closed before the queue's end** spoils the runs left. They are recorded so, and the start
  message gives the expected end time.
- **The cross-session 15 % check on B** rests on runs that record their thermal state and history
  size. The background processes don't enter `rusage`'s figures.

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
| G-16 installer | `diskutil` path; the pre-swap extension end (WP-16 item 6) | Session B's F12 and its `update` log | Revert to 0.6.1's `hdiutil` code. Item 6 ships either way: it never fails an install, and without it 0.6.2 → 0.7 greys the placed widgets (Appendix C, W0-2) |
| SEC-15 | skip verification on attach | Session A timing: ≥ 100 ms saved | No change |
| SEC-08 | Enhanced Security | not run (Q-B8: no; after 1.0, not planned without notarization, M-1) | Not shipped |
| G-17 | WP-17's changes | `page.switch` from the `perf` stream before and after, ≥ 10 switches per page; the SwiftUI instrument (Xcode is installed, Q-B7) | Only SUI-11's readability change |

**Status after rounds B1 and B2, WP-19 and WP-21** (2026-10-24; the facts are in Appendix C):
- **G-13a:** fill (b) ships on Clear Light, Clear Dark and Translucent Dark (WP-13, `c4803c8`), on
  Session A's interim verdicts (Translucent Dark's today's fill rated 2, a black frame); Translucent
  Light keeps its wash. If the final `A.md` doesn't confirm Translucent Dark, `git revert 72b790d`
  alone narrows it to Clear. Session B's 8 cases still decide whether the frame is gone.
- **G-14a:** Session A's field run passes (interim: 711 of 712 reads off the main thread, the
  launch's on it; no crash, no executor line); Session B repeats V-01 on the RC.
- **G-14b:** Session A's half **passed** (F13), so E4b ships with the 5-minute safety net and
  `RegistryReadPolicy.cachesOnPolls = true` (WP-14b, `43052dd`); the F13 defaults (the 60-s
  safety net) no longer apply, and with no M5 run of a build containing E4b it is still no E4b.
  Session B's four criteria remain, and it reads each `registry.missed` by its trigger and time
  (Appendix C, WP-14b's known edges). "No E4b" is still the one-line commit.
- **G-14c: passed:** `timeremaining` dropped in `c50b834`; "keep both keys" no longer applies.
- **G-15:** K-03 (`60c08d1`) can ship by §3's exception (a move with only access and import
  changes, an empty golden diff and a passing CI smoke). Both internalize lines need the RC's F8:
  the widget offers only small and medium, so "every family" means those two, in both languages;
  the app's line (`64f8aaa`) also needs Session B's pages (DC-4). A blank F8 removes the flag from
  the widget's `build-app.sh` line by hand (`8549229` doesn't revert cleanly on top of
  `64f8aaa`); a failed page reverts `64f8aaa`, which reverts cleanly. SZ-11 and SZ-14 aren't
  adopted.
- **G-14a and G-15, the revert order (WP-19, `1bb19d7`):** WP-19's SW-13 commits revert as
  `fa6de42` and `d80f35e` (BatteryKit, in that order), then `452cb28` (BatterySource), before
  E4b's and E20's commits or K-03: `d80f35e` edits the `SecurityGuardTests` placements and the
  strict-target list that `452cb28` adds. Each revert is mechanical (the markers, `@safe` and one
  `Package.swift` flag).
- **G-14b and G-16 in Session B (WP-21):** the script computes G-14b's two numeric Session B
  criteria from the queue's C runs (`read cached` p50 and `registry.missed` per hour of logged
  runtime, with the minutes measured) and prints F12's verdict lines for G-16 (Appendix C, WP-21's
  row).

### 7.2 Cut line

- **Never cut:** WP-10; SPIKE-A2; WP-13 item 1; WP-14a; WP-14b (unless G-14b's premise fails);
  WP-15 item 1 (K-03); WP-16 items 1-2 and 6; WP-W0; WP-21; WP-22; D1-D3.
- **Cut in this order if the budget runs short:** WP-20 (SEC-18; SEC-08 isn't run); WP-19's P3
  items; WP-17; WP-18; WP-15 items 2-3; WP-13 item 5 (item 4 isn't in 0.6.2, Q-B4); WP-16 items
  3-4 (item 5 doesn't run, A0); WP-19's SW-13; WP-23; WP-19's release statistics, last (D3 then
  uses the `gh api` line). A cut item moves to 0.7.
- **Effort, in runs:**

  | Package | Runs |
  |---|---|
  | WP-10 | 3 |
  | WP-13 | 2-3 |
  | WP-14a | 2 |
  | SPIKE-A2 (the fill switch) | 1 |
  | WP-14b | 2-3 |
  | WP-15 | 3 |
  | WP-16 | 2-3 |
  | WP-17 | 2 |
  | WP-18 | 1 (SZ-10's icon source; the rest runs inside Session B) |
  | WP-19 | 2-3 |
  | WP-20 (SEC-18 only) | 1 |
  | WP-23 | 2 |
  | WP-W0 | 3 |
  | WP-21 | 4 |
  | WP-22 | 2 |
  | D1+D3 | 2-3 |

  That is about 34-39 runs plus 3 in reserve (SEC-08 left WP-20 on 2026-10-22, Q-B8; the release
  statistics joined WP-19 the same day; WP-16's item 6 and WP-23 came from Session A on
  2026-10-23, and WP-21's hands-free mode, 2 runs, the same day, which also moved WP-18 into
  Session B, leaving it 1 run for SZ-10's icon source). The never-cut set is about 24-29; WP-18
  isn't in it.
  These are effort estimates, not a schedule: no release has a date (M-5, §10).

### 7.3 Frozen surfaces and intended changes

0.6.1's list (playbook §3.4) holds, plus `betaWindowStyles`, including "Widget. Same kind, look
and reload policy."

**Intended, user-visible changes:**
- Clear's minimize fill, (b) (and Translucent Dark's, if its recordings show the frame; Session A's
  interim ones did, so WP-13 gives it (b) too, Appendix C).
- Settings → General's Window Style footer keeps the height of its longest note whatever the
  choice (V1b's fix, WP-13 item 2): with Standard, one blank line with beta styles off, two with
  them on.
- Any style the maintainer graduates, with the Advanced footer and What's New text reworded
  (`WhatsNew.version` stays 0.6.0, Q-B5). No Low Power Mode fallback comes with it (Q-B10).
- E4b's freshness:
  - If F13 holds, registry values are as fresh as today. It held in Session A, so the safety-net
    age that merged is 5 minutes (WP-14b, Appendix C).
  - If it doesn't, the Power page is unaffected, because it keeps re-reading (the first 2 s or
    less after switching to Power or Raw Data can still show the cached registry, until the next
    2-s poll re-reads it).
  - Elsewhere, the registry fields (capacities, cycles, temperature, cells, adapter telemetry), and
    a history sample taken right after a cached poll, may be up to the safety-net age old: 5
    minutes in the worst case.
- The iPhone and iPad page's connection label follows the transport its values came over (WP-23,
  if it lands; no new string).

**Internal and contract changes:**
- The installer's mount tool. The 0.6.1 → 0.6.2 update itself still uses 0.6.1's `hdiutil`.
- The installer ends the widget extension before the swap (WP-16 item 6); the 0.6.1 → 0.6.2
  update still runs 0.6.1's installer, which doesn't.
- The widget's target graph and size, and both binaries' links (`-internalize-at-link`, G-15).
- The `read` signpost's triggers and the `registry.missed` event in the `perf` output.

**Unchanged:** the widget kind and look, entitlements (SEC-08 isn't run, Q-B8), storage formats,
the settings keys (none is added: WP-16 item 5 doesn't run, A0), `bpulse` output and exit codes,
the update assets and keys, and what the app sends over the network.

**Next, in 0.7:** the anonymous version count (§10, "Further answers") changes the update
contract and the settings on purpose: three new settings keys (`anonymousVersionCount`,
`lastCountedVersion`, `versionFirstLaunch`) and a new release asset (`BatteryPulse-count.txt`),
announced in a minor release. 0.6.2 prepares nothing for it but the release-stats script's Count
column ("—" until v0.7.0; WP-19).

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
| Charge limit reached | `ChargerData.NotChargingReason` bit 24 (0x01000000) while paused at the limit, seen once in Session A's read-only capture (Appendix C); the configured percentage is in no registry key, so the widget can say "paused at the limit" but not which limit | not yet: FEA-35 (`docs/plans/1.0/INVENTORY.md`). 0.7's W-14 shows the paused state (P1; whole to 0.8 without a redacted fixture by plan-0.7.0's C1, G7-18); the configured number is FEA-35's 0.8 half |

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
| Why it isn't charging | own | later | only after a committed Charge Limit fixture proves the cause (Session A saw bit 24 at the limit, Appendix C); until then it adds nothing over State |

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
  - The 0.7 session: the accessibility tree VoiceOver walks, read by the session's `ui` helper on
    a desktop widget in each family and both languages, with nobody driving VoiceOver
    (plan-0.7.0 §6.2 step 7); Increase Contrast and Reduce Transparency.

### 8.16 If a spike fails

| Spike result | 0.7 then ships |
|---|---|
| W0-1: the manual `appintentsmetadataprocessor` step gives no working edit sheet | No configuration. Presets as separate `StaticConfiguration` kinds, each a fixed `WidgetLayoutPlan`: Battery (today's kind and look, plus large and extra large), Battery Health (maximum capacity, condition, cycles of rated, full charge capacity) and Power (adapter, battery power, Mac power use, temperature, Low Power Mode). W-2 is dropped, with no App Intents anywhere |
| W0-1 (b): entity queries don't run from the ad-hoc extension | iPhone & iPad uses an `AppEnum` (most recent, lowest); no chosen device |
| W0-1 (c): button performs don't run | No buttons (W-9's Refresh dropped) |
| W0-2: the control keeps placed widgets, but the configurable kind loses them | Today's kind stays static (today's look, new sizes). The configurable Battery widget ships as a new kind `io.github.nikitausov.BatteryPulse.battery.custom`, and the release notes say how to switch |
| W0-2: placed widgets grey because the old extension answered the descriptor fetch (Session A, `CHSErrorDomain` 1103) | Not a configuration failure: a placed widget survives the change once the fetch reaches the new extension. 0.6.2's installer ends the extension before the swap (WP-16 item 6), so 0.6.2 → 0.7 is clean; a copy from the DMG over a running extension stays a risk. Its recovery is unverified (Session A recovered by ending the old extension, then installing 0.6.1 and SPIKE-W again), so 0.7's session checks one before the release notes describe it |
| W0-2: the control loses placed widgets too | The loss comes from updating an ad-hoc app, not from configuration: A0 saw placed widgets survive the in-app update 0.6.0 → 0.6.1, but ROADMAP Stage 1.2 records a DMG replacement that lost them. Proceed as designed; the release notes say "add the widget again if it's gone", as 0.4's did. With no signed build coming (M-1: no), it stays a documented known limitation |
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
Q-B11 were settled before. Later the same day he gave six further answers ("Further answers",
below), and on 2026-10-23 he asked for hands-free sessions ("The hands-free sessions", below). No
question of this plan stays open; what the maintainer still judges on sight in the
sessions is listed in §3. The road-to-1.0 questions (M-1 to M-14) are in
`docs/plans/1.0/ROADMAP.md` §6, and 0.7's own (Q7-1 to Q7-9) in `docs/plans/0.7.0/PLAN.md` §14.

**M-1, the paid Apple Developer Program account: no,** not now and not planned before 1.0 (the
maintainer, 2026-10-22). He won't pay for the account for this app: he is willing to spend on help
with development, not on the account. It is a non-commercial hobby project with about zero users
(below). For this plan:
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
download counts a week after publishing (D3), printed by `scripts/release-stats.swift` (WP-19).
0.6.2 changes nothing the app sends; from 0.7 on, the anonymous version count adds a column
("Further answers" item 5, below).

### Further answers (2026-10-22)

Decided by the maintainer later the same day:

1. **M-5, what 1.0 means: approved as written,** with its five promises: seen working on the M5
   in a packaged build; a week of daily use without a crash; in-app updates from older versions;
   nothing breaks through 1.x; usable by a non-expert (`docs/plans/1.0/ROADMAP.md` §2). **No
   dates:** "this is a hobby project; we release when there is time and desire". The plans keep
   the order of the versions and the effort estimates, and no target dates; 1.1's macOS 28
   compatibility follows macOS 28's release, an event, not a date. This plan sets no release date:
   §5 is an order, §7.2's runs are estimates, and WP-14b's 14 days only let the packages go on
   with their defaults.
2. **M-1's reason, in his words:** he won't pay for an Apple developer account for this app; he is
   willing to spend on help with development, not on the account (M-1 above).
3. **Round A0 passed:** he installed 0.6.1 through Install and Relaunch from 0.6.0; the desktop
   widget stayed and shows the current charge; Open at login kept its state (Appendix C). So no
   P1 item comes from A0, WP-16 item 5 doesn't run, and WP-22 ticks ROADMAP Stage 1.2.
4. **Branches:** the integration branch is `claude/nice-faraday-k08mhb`, the session's designated
   branch; packages go on `claude/062-<pkg>`, and the widget spikes on `claude/062-spike-widget`
   (§3).
5. **An anonymous version count, in 0.7, on by default and announced honestly.** He wants to
   know how many people use which version. Its design is 0.7's (`docs/plans/0.7.0/PLAN.md`); the
   constraints he set:
   - no server of our own, no third-party service, no identifier of any kind, and no data about
     the Mac, the battery or the settings. GitHub, which serves the asset, sees the request as it
     sees every update check, and the announcement says so;
   - it rides on the existing automatic update check: only when automatic checks are on, never
     when the frequency is Never, and never once the person turns the count off in Settings. It
     goes through `UpdateNetwork`'s ephemeral session and adds no wake-up of its own;
   - What's New for 0.7, README's and USER_GUIDE's new Privacy sections and the release notes say
     what is sent, what isn't, and where to turn it off. The repository's promise about the only
     requests to the internet is reworded in 0.7;
   - three new settings keys (`anonymousVersionCount`, `lastCountedVersion`, `versionFirstLaunch`)
     and a new release asset (`BatteryPulse-count.txt`) in the update contract: a frozen-surface
     change, announced in a minor release (§7.3).

   0.6.2 changes nothing the app sends; its only part is the Count column of WP-19's script.
6. **A release statistics script in 0.6.2** (tooling, no app change): `scripts/release-stats.swift`
   prints, per release, DMG downloads, `.sig` downloads (in-app updates) and, from 0.7 on, the
   downloads of the count's asset (`BatteryPulse-count.txt`), from GitHub's public REST API,
   unauthenticated and within its 60-requests-an-hour limit. WP-19 builds it; D3 copies its numbers
   into ROADMAP's Releases table a week after each release.

### The hands-free sessions (2026-10-23)

| Request | Decision | Where |
|---|---|---|
| The maintainer, 2026-10-23, during Session A: "Make the tests run by themselves, without me; I can't do two things at once, click and work." Session A showed the cost: every `DO (person)` line waited for him, and the timed steps tied him to the Mac | **Session B runs hands-free** (an engineering call on his request): his part is only what needs a person (the start line and one yes to the list of changes, quitting his own apps, the Focus on and off, the adapter, the lid and the morning login, his password at bedtime, the permission prompts, the taste questions, his typed "continue", revoking Terminal's Accessibility unless he keeps it, and his yes before `send`), about 18-22 minutes in short moments against about 100 (plus WP-18's hour). **One local Claude Code session, not two:** the CLI in Terminal with its built-in `computer-use` server runs the script, drives the GUI and judges the pictures, and the energy queue runs as a plain script in the arm window. Deterministic scripting comes first, computer use covers the rest, and a step it can't do is "not checked", with its gate's default | §6 Session B; WP-21's hands-free mode; WP-18; D3's after-publishing check; plan-0.7.0 §6.2 (Session R) |

Why one session and not two:
- **The lock:** only one session at a time can use the computer. A session takes the lock at its
  first computer-use action and releases it when it exits, so a second session couldn't share the
  GUI, and a session that only runs scripts would have nothing the GUI session lacks: it has Bash.
- **Timing:** several steps tie the script's timing to a click (`record_clip`'s window, the page
  cues, F11's banner wait, F12's before and after shots, the widget clicks). Across two sessions
  each would need a file handshake: the relay problem again, between two Claudes.
- **One judge:** the judgment needs the script's output and the pictures in one context.
- **One owner of the quiet state:** two sessions mean two idle loads, two approval batches, two
  permission modes and two things that can click during a run.
- **What a second process adds** (a terminal for `sudo`, survival of a crash or a compaction, no
  tool time limit, nothing of Claude's running during the measurements) comes from the arm window,
  without a second Claude. His idea of a second local session is kept in this sense: a new local
  session replaces his hands, and the second window is the queue.

Why the CLI rather than the desktop app (whose computer use is Settings → This computer → computer
use, with Accessibility and Screen Recording granted to Claude):
- **Permissions:** every grant Session A gave sits on Terminal (Screen Recording, Accessibility,
  Automation of System Events and BatteryPulse), and computer use in the CLI runs on the terminal's
  grants, so Session B asks for no permission Session A didn't give; if he revoked Accessibility
  after Session A, preflight asks again while he is there (one prompt, Touch ID or his password).
  The desktop app would need its own, then the Automation and other apps' data prompts again.
- **The pictures:** the CLI's terminal window stays visible but is left out of computer use's
  screenshots, so Claude never sees its own output or the password window.
- **The energy figures barely differ** either way, because `rusage` measures only BatteryPulse's
  own process.
- **The fallback:** the desktop app only if `/mcp` doesn't list `computer-use`, with "Keep computer
  awake" off (the arm window's `caffeinate` covers it, and the app's own assertion would sit in
  every run). The two surfaces are never mixed in one session.

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
  - **Superseded for Session B on 2026-10-23** by the hands-free sessions (above): about 18-22
    minutes of his time against about 100 (plus WP-18's hour), the password once at bedtime, and
    the queue's order of WP-21 (a warm-up, S2 first, S6 last; S9 not run by default), about 160 minutes plus
    the cooldown.
- **Q-B7 (Xcode): installed on the M5** (the maintainer). `xctrace` (WP-17; Session A step 8,
  Session B step 5), the contrast audit and Clear's shadows (WP-13 item 3; Session B steps 3 and 5)
  and every WP-18 item run, in Session B since 2026-10-23 (before: maintainer-run from Claude's
  step-by-step list); no step depends on whether Xcode is there any more. The Icon Composer icon (SZ-10), decided by delegation: prepared
  in WP-18 and shown in the four icon styles; it ships only on the maintainer's y to those
  screenshots, otherwise it waits for 0.7.
- **Q-B8, decided by delegation: no.** Asked: is the Enhanced Security spike (SEC-08) worth a
  session step? It isn't run in 0.6.2 (WP-20). Enhanced Security on an ad-hoc signature is
  unverified, an update that AMFI refused would leave an app that doesn't launch, and it stays
  after 1.0, not planned without notarization (M-1: no).
- **Q-B9 (F12), settled:** the first try failed on GitHub's limit of 60 unauthenticated API requests an hour per address, used up behind a VPN that shares its address; the app said "GitHub is limiting requests", and the re-run after the limit reset passed. Not a defect; Session B's script
  checks the remaining unauthenticated requests (`curl -s https://api.github.com/rate_limit`)
  before F12 and, hands-free, waits for them rather than asking to turn a VPN off; F12 runs once.
- **Q-B10 (Low Power Mode), decided by delegation: no fallback.** Asked: if Translucent or Clear
  uses 15 % or more energy than Standard, should it give way to Standard while Low Power Mode is
  on? A window style is the user's explicit choice, Reduce Transparency and Increase Contrast
  already give Standard, and Low Power Mode already slows the polls (`LiveRefreshPolicy`). S4w
  still measures each style, and ROADMAP's decision line records the numbers (G-13c).
- **Q-B11 (branches), settled (an engineering call):** `claude/baseline-0.6.0` (`076873d`) stays
  until 0.6.2's D3 for build A; 0.6.1's integration history stays reachable as `refs/pull/11/head`
  (see the header), so `claude/nice-faraday-k08mhb` could restart from `main`. It is now 0.6.2's
  integration branch (§3; "Further answers" item 4).

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
| In-app install (Stage 1.2): tick it on F12 and 0.6.1's after-publishing check; re-register the login item after an update | ROADMAP 1.2 | WP-22 ticks it: A0 passed and kept the login item (Appendix C); WP-16 item 5 doesn't run |
| 0.6.1 after-publishing results (widget, login item, notifications, first-day widget accuracy, `994c09d`) | PLAN §4b | intake A0: passed on 2026-10-22 (Appendix C); no P1 item |
| SUI-07, SUI-11, SUI-12, E19 | PLAN §6, G17 | WP-17 |
| SUI-17, SUI-18, SUI-19, SZ-10 | PLAN §6, G21 | WP-18, run inside Session B since 2026-10-23 (SUI-18 dropped; SZ-10's icon source by a cloud run, 1 run, and its y in the morning batch; Xcode is installed, Q-B7) |
| SUI-09, SW-21, SW-13 (now BatterySource and BatteryKit), C2 | PLAN §6 | WP-19 |
| CI pins (checkout v6.1.0, upload-artifact v7) | ROADMAP 1.7; PLAN Appendix C (B6) | WP-19 |
| SEC-08 | PLAN §6, G20 | not run (Q-B8: no); Enhanced Security is after 1.0, not planned without notarization (M-1: no) |
| SEC-18 | PLAN §6 | WP-20 (research) |
| SEC-10 | PLAN §6, G19, Q1 | not in 0.6.2 (no evidence) |
| SZ-08 | PLAN §6 | not in 0.6.2 (no glossary work) |
| S1, S2, S4w, S5, S6, S7, S8, memory, S10 | PLAN §4c; ROADMAP 1.4, 1.5, 1.6, 1.7, 6; playbook §2 | WP-21; A/B in Session A, C in Session B |
| S9 (an iPhone attached, all windows closed) | ROADMAP 5; playbook §2 | not run by default in Session B (WP-21: the iPhone would charge from the Mac all night); stays open in Stage 5 |
| S3 (popover), the minimized and other-Space runs, frame rate (Instruments) | ROADMAP 1.4 | S3 and the minimized run: Session B's queue (WP-21, set up by CGEvent before their quiet minute; P11); the other-Space run and the frame rate stay open in Stage 1.4 |
| Sleep hygiene (playbook §2.3 items 1 and 7) | playbook §2.3 | WP-21 (assertions in every run; the overnight check is Session B's own night) |
| Stage 1.4 legibility and accessibility pass | ROADMAP 1.4 | Session B optional; otherwise stays open |
| F5 (iPhone page, accessories, earbuds) and accessory captures | 0.6.1 session (not run); ROADMAP 5, 6 | Session A step 2: run on 2026-10-23 with earbuds and an iPad, no keyboard (Appendix C) |
| The widget extension ended before the swap | Session A's W0-2, 2026-10-23 | WP-16 item 6 (never cut); Session B's F12 checks it |
| The device connection label after unplugging | Session A's F5, 2026-10-23 | WP-23 (P2) |
| F9 (Russian) | 0.6.1 session (not run) | Session B step 4 |
| F11-alert, F11-login | 0.6.1 session | closed (§4, WP-0) |
| F12's first failure | 0.6.1 session | Q-B9, settled: GitHub's rate limit behind a VPN |
| Charge Limit capture | ROADMAP 1.1; QUA-05 (`docs/plans/1.0/ROADMAP.md`) | partly settled in Session A (Appendix C: bit 24 while paused, the configured value in no key); the committed fixture is Session B optional (the morning-away block); WP-22 writes the partial result into Stage 1.1 |
| Spreadsheet exports | ROADMAP 6 | Session B optional |
| The Charge Limit shown in the app, the menu bar and the widget | the maintainer, 2026-10-23 (Session A) | FEA-35 (`docs/plans/1.0/INVENTORY.md`), not 0.6.2 (no new features): 0.7's W-14 for the state in the app, the menu bar and the widget (whole to 0.8 without a redacted fixture by plan-0.7.0's C1, G7-18), 0.8 for the number; "paused at the limit" has a source, the configured value has none in the registry (Appendix C) |
| Widgets kept across an in-app update | ROADMAP 1.2 | A0: kept across 0.6.0 → 0.6.1 (Appendix C), so WP-22 ticks it; W0-2's control; Session B F8 |
| Widget customization | maintainer's request, 2026-10-22; ROADMAP 0.7 | §8; spikes WP-W0 in 0.6.2; W-1 to W-10 in 0.7 (§9.1; Q-W1: no 0.6.3) |
| CB-02 (device JSON dates) | PLAN §6, Q3 | 0.7 |
| CORE-16 | audit-core-verified | stays rejected, unless 0.7's drawn-battery visual changes `BatteryIcon` |
| Glossary re-check, captures from M1-M4 Macs; Instruments against the resource targets | ROADMAP 1.1 | not planned (WP-21's memory covers the RAM target) |
| Chart descriptors; App Nap on the minute timer | ROADMAP 3 | not planned |
| How often the mAh values change | ROADMAP 3 | Session A's ioreg sampler (`BatteryData`'s `RemainingCapacity` every 10 s); WP-22 ticks it |
| iPad capture, ManufactureDate decoding | ROADMAP 5 | not planned (Session A's F5 had an iPad at hand, but no capture was asked for) |
| Apps using energy; charge limiting; package manager | ROADMAP 3, 6 | not planned (the package manager's official catalog needs notarization, and so the paid account the maintainer declined, M-1; the others a spike first) |
| K-02's CI half | WP-0b report (0.6.1) | not planned |
| Glass in the tile picker | PLAN §6 | closed: the maintainer chose the outline (PLAN §8) |
| `package` access, documentation-lint rules | PLAN §6 (SW-R17) | not planned |
| Developer ID signing, notarization, an App Group | ROADMAP Decisions; M-1 (`docs/plans/1.0/ROADMAP.md` §6) | not planned (M-1: no, 2026-10-22); §8.3 candidate C, §10 |
| Release download counts | the maintainer's question, 2026-10-22 | §10's usage evidence; D3 records each release's DMG and `.sig` counts a week after publishing, with WP-19's script |
| Release statistics script (`scripts/release-stats.swift`: DMG, `.sig` and, from 0.7, `BatteryPulse-count.txt` downloads per release) | the maintainer's answer, 2026-10-22 (§10, "Further answers" item 6) | WP-19 (P2, cut last); D3 runs it a week after publishing |
| Anonymous version count (on by default, announced) | the maintainer's answer, 2026-10-22 (§10, "Further answers" item 5) | 0.7 (`docs/plans/0.7.0/PLAN.md`); 0.6.2 changes nothing the app sends; WP-19's script has its column |
| What 1.0 means; no release dates | M-5, approved 2026-10-22 (§10, "Further answers" item 1) | this plan sets no release date (§7.2) |
| Integration and package branches | the maintainer's answer, 2026-10-22 (§10, "Further answers" item 4) | §3: `claude/nice-faraday-k08mhb`, `claude/062-<pkg>`, `claude/062-spike-widget` |
| Hands-free M5 sessions: "Make the tests run by themselves, without me; I can't do two things at once, click and work." | the maintainer's request, 2026-10-23, during Session A (§10, "The hands-free sessions") | §6 Session B (one local Claude Code session with computer use, the queue as a plain script); WP-21's hands-free mode (+2 runs); WP-18 inside Session B; D3's after-publishing check as a short session; plan-0.7.0 §6.2 (Session R) |

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
- answered by WP-16's CI runs (Appendix C, the `diskutil` row): `diskutil image attach` has no `-noautoopen` counterpart and needs none with `--mountOptions nobrowse`; the forced path is `unmountDisk force` then `eject` of the image's disk; and `diskutil eject` of a mount point also detaches the image's own disk;
- whether a per-extension `AppleLanguages` reaches the widget and its edit sheet;
- the hdiutil deprecation, which is seen only as runner warnings, not in Apple's release notes;
- whether opening a desktop picture outside `~/Pictures` and the system folders shows a
  file-access prompt on macOS 27 (moot while the desktop-picture fill isn't built, Q-B2).

Session A's interim report (2026-10-23) answered several of these: button performs, both
exceptions, `IOPSCopyPowerSourcesByType(4)` from the sandbox, the scheme, the placed widget's
survival and the offset format's English text (Appendix C's W0 rows). The rest stays with the
sessions.

## Appendix C: facts 0.6.2 records (filled during the release)

Rows marked "interim" come from Session A's interim report of 2026-10-23 (the local Claude
session on the M5) or, for its unattended window, from the maintainer's photo of Terminal of
2026-10-24 and the window's own summary, which he pasted the same day ("the window's summary");
Session A's final `A.md`, on `claude/062-session-a`, replaces them. **Still for Session A** marks
what they leave open. Session A's energy runs are in the table after this one.

| Fact | Shown by | Decides |
|---|---|---|
| A0, recorded 2026-10-22: **passed.** 0.6.1 installed through Install and Relaunch from 0.6.0; the desktop widget stayed and shows the current charge; Open at login kept its state. The other lines of PLAN §4b's list weren't reported one by one; the maintainer's verdict is a pass | the maintainer (everyday use) | no P1 item; WP-16 item 5 not run; WP-22 ticks ROADMAP Stage 1.2 |
| W0-1 (CI half), 2026-10-22: **the metadata reaches the bundle.** On `claude/062-spike-widget`, `build-app.sh` collects the widget's Swift sources and release `.swiftconstvalues` and runs `xcrun appintentsmetadataprocessor` (Xcode 27.1, generator xcode-tools 27A9275) with the `AppIntentsMetadata.xcspec` options on the unstripped binary; the appex gets `Contents/Resources/Metadata.appintents/` (`extract.actionsdata` 7,700 B, `version.json`) and then strips, signs, passes the posture check and launches (runs 39794535282, 39806441696). The actions, the `AppEnum`, the entities and their queries, the `ParameterSummary` and its `When` clause are all extracted. **No `[AppEnum]` per-family `size:` overload compiles** with Xcode 27.1 at any deployment target (26.0-27.2); an array of an `AppEntity` does, and an integer literal per family is an exact size (min = max), so "up to N" needs `IntentCollectionSize(min:max:)`, untested. `Summary` strings aren't seen by `LocalizationCatalogTests` yet. Entity query and button behaviour at run time: Session A | CI; Session A | W-2, §8.11, §8.16 |
| W0-1 (run time), 2026-10-23 (interim): **the edit sheets show the parameters.** Battery: Layout, Main value, Time; Custom adds Details, with 4 slots on medium. The test widget: Main value, Details (4 on medium, more on extra large), Device. (c): the Refresh button's `perform` ran in the widget extension (`process=widgetExtension`). (d): the `ParameterSummary` line ("Show Charge") is not visible (W0-1-test-edit n, for the summary only). (b): no entity-query line, because the Device chooser was never opened. **Still for Session A:** (b), with the Device chooser opened | Session A | W-2; §8.11 (no summary text shows); §8.16 (W0-1 and (c) pass; (b) open) |
| WP-10, 2026-10-22: `.defaultIsolation(MainActor.self)` on the app only; `@MainActor` in the app 35 → 4; off-main types marked `nonisolated` (the plan's list plus `RawValueText`, `HistorySource`, `HistoryLoad`, `Diagnostics`, `SidebarItem.signpostName`, `BatteryFormatter.app`, `CardGroupSpace`, `PulseLine`), pinned by the new `IsolationGuardTests`. The macOS job's only isolation error was `PulseLine: Shape` (Shape inherits View, so SE-0466's exception didn't apply). 0 warnings; launch smoke green; app binary +176 B, `__text` +3,300 B | CI runs 39792414043 (the error), 39795540512, 39798511959 | G-10's compile half; V-01 is Session A's |
| WP-14a, 2026-10-22: shape B. `MacBatteryProvider` is `nonisolated` and `Sendable` with `readNonisolated(scope:)` reached through `BatteryProvider.nonisolatedReader` (nil by default), its SMC cache and the SMC client's state behind `Mutex`es, no new `@unchecked Sendable`; the widget, bpulse and the other providers unchanged. The monitor reads `.launch`, `.manual` and `.demo` on the main actor (Demo Mode's exit stays inside its animation) and the other triggers through a `@concurrent` helper, one at a time, coalesced, with generations. The CI smoke's one launch read is on the main thread before `menuBarReady` (2.5 ms; the VM has no battery, so no off-main read ran there). The `refresh` interval of an off-main trigger now spans the hop: compare with 0.6.1 by `read`. Swift 6.4.1 on Linux crashes in IRGen on `#isolation != nil \|\| Thread.isMainThread` inside a nonisolated(nonsending) async function (bind `#isolation` first); `TaskGroup.reduce(into:)` is rejected from a main-actor context | CI run 39803776795 | G-14a's compile half; the field run is Session A's |
| Spike builds for Session A, 2026-10-22: SPIKE-C = v0.6.1 (`claude/062-spike-c`, run 39800982102, #277); SPIKE-I = 0.6.1 plus `-internalize-at-link` on the widget (`claude/062-spike-i`, run 39801168615, #278): widget binary 1,379,808 → 1,059,616 B (−23.2 %), `__text` 943,096 → 684,136 B (−27.5 %), DMG −7.4 %, the app untouched; SPIKE-W = the configurable battery kind plus the test kind, the feed writer and reader (A, A′), the click logger and the render logging, with `-internalize-at-link` (`claude/062-spike-widget`, run 39806441696, #282). All CI builds are version 0.0.0, so their automatic update check stays off (`isUnversioned`) | CI | G-15's size input; Session A's install order |
| SPIKE-A2, 2026-10-22: `claude/062-spike-a2` at `cee5033` on the A2 tip `3a02643` (WP-10 + WP-14a), CI run 39808734092 (#285, 0.0.0): the normal DMG and a profiling DMG (unstripped, `get-task-allow` on the app only, same UUIDs). The spike-only key `spikeA2MinimizeFill` (`b` = fill (b), white 0.1945 opaque, on Clear; `b-and-translucent-dark` adds Translucent Dark; missing or `a` = today's fill) switches the minimize fill for step 6. The Session A script (`m5-session.sh`, `swap.swift`, `frames.swift`) and the local-session runbook (`SESSION.md`) merged at `677f8c8`; CI type-checks the helpers | CI | Session A |
| W2, 2026-10-23: SPIKE-W's code (`a609487`) built again by `workflow_dispatch` (run 40002896511, #307), so W0-2 can be retested under a build number chronod hasn't cached (`56702f9`) | CI | Session A's W0-2 retest |
| W0-2, 2026-10-23 (interim): **a widget placed by 0.6.1 survives its kind becoming an `AppIntentConfiguration` (Automatic default) when the descriptor fetch reaches the new extension.** The first SPIKE-W install (282) greyed the placed widgets: at the version change, chronod fetched the descriptors again within about 2 ms from the old `BatteryPulseWidget` process, still running, and cached 282 with the previous build's static descriptor; every reload then failed with `CHSErrorDomain` 1103 and "Connection to extension process was invalidated". `WidgetRefresher.endPreviousExtension()` runs only at the new app's launch, after that fetch. After the session ended the old extension and installed 0.6.1, then SPIKE-W again, the widgets placed under 0.6.1 (small, medium) and under SPIKE-I (medium) redrew in today's look with fresh values. Edit Widget shows the parameters (W0-1, run time). The script now ends the extension before each swap (`56702f9`). **Still for Session A:** SPIKE-C's and SPIKE-I's 1-4 answers with `pluginkit` before and after, the clean retest on W2, and the edit sheet in Russian | Session A | WP-16 item 6; §8.16 (the row on the old extension answering), W-3 |
| W0-3, 2026-10-23 (interim): **A and A′ both work** under ad-hoc signing on macOS 27, "feed ok" with 55 bytes read each. **Still for Session A:** B (`notify(3)` state words), and a read of data the app wrote while the widget wasn't running | Session A | §8.3, Q-W3 (its condition holds: W-5's feed stays 0.7's stretch) |
| W0-4, 2026-10-23 (interim): (1) **the sandboxed widget reads accessory batteries itself** ("spike accessories sources=2 accessories=1"). (2)-(3) the four Icon & widget styles ran on the desktop, focused and not, and in Notification Center, with screenshots, and the widgets redraw per style; but no process logged a "spike render" line, so the rendering mode, `showsWidgetContainerBackground` and `redactionReasons` have no log data. (4) a click delivers the URL to `application(_:open:)` with no window open and with the main window open ("spike click url scheme=batterypulse page=overview windows=1 active=true"); no `NSUserActivity` arrives. (5) the `widgetURL` reaches the app with no registered scheme (SPIKE-W registers none). **Still for Session A:** why the render lines are missing; until they come, the screenshots are §8.7's only evidence | Session A | W-8 (passes); §8.7; §8.9 (the URL route, no scheme registered; §8.16's scheme row doesn't apply) |
| W0-5: VoiceOver text; Text size. **Still for Session A** (not in the interim report). The step's photos give P1 evidence: the widget's container read as "In BatteryPulse, widget, 9 items" (P1's row, below) | Session A | §8.15 |
| W0-6, 2026-10-23 (interim), English only: the offset format prints "-2 hours, 0 minutes" without `sign: .never` (the offset runs to a later date) and "2 hours, 0 minutes" with it, and the minutes go down without a reload. **Still for Session A:** the Russian text | Session A | Time parameter (time left stays, with `sign: .never`; §8.16's W0-6 row doesn't apply) |
| F13, 2026-10-24 (interim, the window's summary): **passed.** On battery, 2.00 h sampled, 126 `UpdateTime` changes, each with an "any" line since the previous 10-s sample; charging, 0.99 h sampled, 62 changes, each with an "any" line. Notify lines by key over the window: any 194, percent 20, source 1, timeremaining 146 | Session A's pslog and ioreg sampler (the window) | G-14b's Session A half: E4b ships with the 5-minute safety net (not 60 s) and `RegistryReadPolicy.cachesOnPolls = true` (WP-14b, below) |
| E3b, 2026-10-24 (interim, the window's summary): **passed.** On battery, 125 `timeremaining` lines, each followed by "any" within 10 ms; charging (0.99 h), 21, each followed by "any" within 10 ms | Session A's pslog (the window) | G-14c: `com.apple.system.powersources.timeremaining` dropped in `c50b834`, before WP-15 moved the file (WP-14b, below) |
| E20 field run, 2026-10-24 (interim, the window's summary): started 01:01:05 on SPIKE-A2 (E20's build), 2 hours with power in the menu bar and the display on. 712 reads in the app, 711 off the main thread and 1 on it (the launch). `read` p50 7.232 ms, p95 9.716 ms; `registry` p50 5.290 ms, p95 5.729 ms, about 73 % of a read (E4b's target); the other parts, in ms as the summary gives them: `children` 1.071, `adapter` 0.490, `iops` 0.393, `parse` 0.198, `smc.power` 0.478 (668 samples), `smc.other` 2.124 (103). `refresh` by trigger: poll 584, notify 122, followUp 5, launch 1; reads per notify burst all 1 except one 2; `widget.reload`: policy 8, update 1. Footprint 20.2 → 20.5 MB; no crash, no executor line. The photo's note "ri_energy_nj didn't move; check sysctl kern.pervasive_energy" is for the final `A.md` to explain | Session A (SPIKE-A2) | G-14a: passes on this run (V-01 all y in Session A's status, the next row); Session B repeats V-01 on the RC |
| V-01: "executor" log lines, new crash reports, the maintainer's answers. Session A (interim): all y (Session A's status); no executor line, no crash report (the window's summary). **Still for Session B:** the RC | Session A (SPIKE-A2); Session B (RC) | G-10, G-14a |
| `read cached` p50; `registry.missed` per hour of logged runtime, each event read by its trigger and time (WP-14b's known edges, below) | Session B | G-14b |
| WP-14b, 2026-10-24: **merged** into `claude/nice-faraday-k08mhb` as `43052dd` (head `dc3cca3`) in round B1, beside WP-13 (§5). **Item 1:** F13 passed (its row above), so E4b ships with the 5-minute safety net and `cachesOnPolls = true`. **Item 2:** `BatteryReadScope` is a struct of two `Bool`s, `rereadsRegistry` and `readsAllSMCKeys`, with the presets `.full`, `.live`, `.cached` and `.cachedSlow` (`.full` and `.live` keep their 0.6.1 meaning); the new `BatteryCore/RegistryReadPolicy.swift` holds `RegistryReadPolicy` (the static `cachesOnPolls`, `defaultSafetyNetAge` = 300 s, `.app`, `rereadsRegistry(isPoll:age:isShown:)`), `RegistryCapture` and `BatteryReading.init(registry:smc:timestamp:)`; `SMCReadPolicy` is unchanged. `MacBatteryProvider` keeps the last registry, IOPS and adapter dictionaries that found a battery behind a `Mutex`; a cached read with an empty cache fetches the registry anyway. **Item 3:** every trigger but `poll` re-reads the registry; a poll re-reads it while Power or Raw Data is shown, or once the cached copy is 5 minutes old, an age check inside existing reads (no new task or sleep). Beyond the plan, for correctness: a coalesced follow-on read still fetches the registry if any folded request wasn't a poll (`requestedPollsOnly`), even when it is labelled with a first request that was. The `read` signpost's trigger is `full`, `live`, `cached` or `cached.slow` and names what the read did. **Item 4:** a read that fetches the registry compares the snapshot's `gaugeUpdatedAt` (`UpdateTime`) with the last fetch's; if it changed and no change notification arrived since that fetch began, the monitor logs `Diagnostics.event("registry.missed")` with the refresh trigger of the read that found it (the pure logic is `RegistryUpdateWatch`; Demo Mode and `stop()` reset it; an internal counter, `missedRegistryUpdates`, serves the tests). **Item 5:** bpulse, `--record` and the widget still call `read()` (= `.full`); bpulse output is unchanged. **Item 6 (E3b):** `timeremaining` dropped from `powerSourceNotifications` in its own commit (`c50b834`), and the coalescing-window comment no longer says powerd posts two notifications. `perf-stats` adds, for each name with more than one trigger, a row over all of them (trigger "(all)", for intervals and events), so D1 compares `read (all)` with v0.6.1's `read -`; the sample gained 0.6.2-style `read` triggers and two `registry.missed` events (`.expected` regenerated). **"No E4b"** is one line, `RegistryReadPolicy.cachesOnPolls = false`, with no test change: every rule and monitor test runs with the switch on and off, and the suite passes with it off (5 + 117 + 581, the review's check); the 60-s fallback is `RegistryReadPolicy(cachesOnPolls:safetyNetAge:)` with another age, and either commit should reword `setShowsSlowValues`' "up to 5 minutes". No settings keys, storage formats, strings, entitlements, network behaviour, bpulse output or exit codes changed; `SecurityGuardTests` and `EnergyGuardTests` untouched and green (`IOServiceOpen` still only in `SMCClient`). The golden diff is empty by construction (BatteryCore only gained `RegistryReadPolicy.swift`; bpulse, the parser and the report are unchanged). Tests 565 core + 107 kit + 5 at `f1c2527` → 581 core (58 suites) + 117 kit (9) + 5; `MacBatteryProviderTests` pass on the runner (no battery), whose launch smoke logs `perf interval read ms=0.603 trigger=full`, then `No battery`; no fix commits | CI runs 40045151920 (`dc3cca3`; 40044943854 on `b43b3f8` was cancelled by the newer push, not failed), 40046692780 (`c4803c8`, both B1 merges); the round's review | G-14b's Session A half and G-14c (§7.1); Session B's G-14b criteria (the row above); WP-22: CLAUDE.md's signpost list (`read`'s four triggers, `registry.missed`) and E4b's two decisions, USER_GUIDE's refresh sentence, ROADMAP's E3b line |
| WP-14b's known edges (minor, open). **`registry.missed` can be wrong three ways**, which Session B tells apart by each event's trigger and time: (1) too high: a read that sees a change and lands before that change's notification counts a miss (a miss followed by a `notify` refresh within about 1 s); (2) possibly too high around a wake: a notification queued during sleep can land after the first read after the wake (a `history`-triggered miss right after a wake; how often is unverified); (3) too low: any change notification counts, Low Power Mode and thermal ones included, and any later notification hides an earlier miss. With power in the menu bar (cached 10-s polls; no history read, since a read always came within 20 s) a miss shows only when the next fetch is the 5-minute safety net with no notification in between, so the detector is nearly blind there; it is fine-grained only while Power or Raw Data is shown (a fetch every 2 s) or with no polling (the history read each minute), so Session B counts it per hour of such runtime. `followUp`-triggered events are updates that the follow-up re-reads already catch. Also: `apply()` records a fetch by the scope the monitor asked for, so a `.cached` request that the provider turns into a fetch (an empty cache after a read without a battery) isn't recorded; the next safety-net re-read can come early and one baseline is skipped, values unaffected. The class doc and `setShowsSlowValues`' doc write the age as a fixed "5 minutes". **Freshness** (§7.3): pages other than Power and Raw Data show registry values up to 5 minutes old in the worst case (only if F13 fails in the field), and so does a history sample taken right after a cached poll; after switching to Power or Raw Data, the first poll interval or less (2 s, or 5 s in Low Power Mode, under reduced resources or heat) can still show the cached registry until the next poll (the lag the SMC's slow keys had in 0.6.1; no extra read on a page switch, per the plan's rule); a long sleep makes the first poll after the wake re-read (`ContinuousClock` counts sleep toward the age). F13 tested `UpdateTime` only: registry fields that might change without it (adapter or charger telemetry) can be 5 minutes old off Power and Raw Data, as §7.3 allows; the menu bar's power figure is SMC voltage × current, unaffected; F6 is the check | the implementer's notes; the round's review | left as is (no code defects; the docs' "5 minutes" changes only with the "no E4b" commit); Session B: G-14b's count and F6 |
| mAh cadence: `RemainingCapacity` changes per hour | Session A's ioreg sampler | ROADMAP Stage 3 (WP-22) |
| Clear's fill (b) and Translucent Dark's today's fill, 2026-10-23 (interim): recorded at normal speed with a frame dump every 0.05 s, answered 1 (like the window, or an even graphite grey), 2 (a black frame) or 3. Clear Light with (b): 1. Clear Dark with (b): 1 (its restore clip re-taken). Translucent Dark with today's fill: 2, the title bar band at RGB 0,0,0. Translucent Dark with (b): 1, at RGB 49,49,49. **Still for Session A:** the final `A.md` confirms these | Session A step 6 | G-13a: (b) extends to Translucent Dark (WP-13 item 1, next row) |
| WP-13, 2026-10-24: **merged** into `claude/nice-faraday-k08mhb` as `c4803c8` (head `2b2dba0`) in round B1, beside WP-14b (§5). **Item 1 (G-13a):** `WindowLookPolicy.graphiteMinimizeFill` = `Tint(white: 0.1945, opacity: 1)` (0.03 × 0.65 + 0.5 × 0.35, sRGB-encoded; 0.1945 × 255 = 49.6, Session A's RGB 49,49,49; white text on it 12.9:1) through `minimizeFill(systemDark:)`, which `sheetSurface(systemDark:isMinimized:)` returns as `.fill`: on Clear Light and Clear Dark (`6c5f8ae`) and on Translucent Dark (`72b790d`, its own small commit); Translucent Light keeps its white wash at 45 %. It rests on Session A's interim verdicts (the row above) and matches SPIKE-A2's switch `b-and-translucent-dark` exactly (the same constant and `systemDark` condition). If the final `A.md` doesn't confirm Translucent Dark, `git revert 72b790d` alone narrows the fill to Clear; it applies cleanly on `2b2dba0`, whose comment fix (the review's) points at `minimizeFill` and reads true either way. Linux tests: Clear's fill is opaque and equals 0.1945 and the tint-over-mid-grey composite; white text on it clears 4.5:1; Standard and Frosted have no fill; Reduce Transparency gives nil. The swap still never animates and ends at the restore; `App/WindowLook.swift` changed only in comments; `sheetSurface`'s "never opaque" doc is rewritten. **Item 2 (V1b, `3d2e627`), the cause inferred from the code, not yet seen on the Mac:** nothing in a tile depends on the selection but the accent outline (drawn in the tile's 4 pt / 10 pt padding, away from the preview) and the selected trait. What changed with the choice was the footer under the picker (Standard no line, Frosted 1, Translucent and Clear 2), and Settings sizes its window to its content (`SettingsPage` uses `.fixedSize`), so a new choice resized the window and could move the tiles under Digital Color Meter's fixed reading point. The fix: the footer lays out every note the offered tiles can lead to and shows only the chosen one (as `Crossfade` does, unanimated), so it keeps the height of its longest note: with Standard, one blank line with beta styles off, two with them on. The choice of notes is in BatteryCore (`WindowLookPolicy.Note`, `.note`, `notes(offered:reduceTransparency:increaseContrast:)`), with Linux tests; the new `MotionGuardTests.tileSelectionChangesOnlyTheOutline` checks that `isSelected` reaches only the outline's stroke and the trait, compared in one place (it fails on a preview's `.opacity(isSelected ? …)`). The footer keeps its catalog keys. **Items 3-5 are left to Session B's answers:** item 3's evidence is Session B's steps 3 and 5 and S4w; item 4 stays out of 0.6.2 (Q-B4); item 5 runs only on the maintainer's answers and alone may add catalog keys (keys added early would fail `LocalizationCatalogTests` as unused); G-13c stays decided (no fallback). Tests 565 → 570 core (57 suites); lint clean | CI runs 40044109067 (`3d2e627`), 40045265599 (`2b2dba0`), 40046692780 (`c4803c8`); the round's review | G-13a shipped on interim verdicts (§7.1); Session B's 8 cases and V1b's pixel comparison; WP-22: CLAUDE.md's minimize-fill line, USER_GUIDE's Clear known issue (if G-13a passes in Session B), ROADMAP's G-13c line; D1: the release notes |
| WP-13's known edges (minor, open): the V1b fix changes the look on the default setting: with Standard the Window Style footer keeps blank space the size of its longest note (one line, Frosted's, with beta styles off; two with them on; the overridden note's height under Reduce Transparency or Increase Contrast), the trade `Crossfade` makes in Settings and Welcome. The tiles moved only if AppKit doesn't keep the window's top edge when it resizes; Session B's scripted V1b compares window-relative captures (`screencapture -l`), which pass whether the window moved or not, so a pass shows identical preview pixels (what Q-B4 asks) without proving the cause. If it still finds different pixels, the next suspects are the plain button style's pressed or focus effects | the round's review; the implementer's notes | accepted as is; Session B's V1b |
| The 8 recorded minimize cases and the plain answers | Session B step 3 | G-13a, G-13b |
| The 24 screenshots and the 19 graduation shots, answered y or n; V1b's pixel comparison | Session B step 3 | G-13b; WP-13 item 2 |
| The contrast audit's reports per beta style, appearance and page | Session B step 3 | G-13b (Q-B4) |
| Clear's shadows in Instruments | Session B step 5 | G-13b; Stage 1.5 |
| S4w per style against Standard | Session B | ROADMAP's decision line (G-13c; no fallback, Q-B10) |
| F8 per family and language (F8-ru: the method, or not checked) | Session B | G-15 |
| F12: offered, installed, relaunched, per try; the pre-swap extension end (the `update` log line's counts and milliseconds, the `BatteryPulseWidget` processes before Install and after the swap, the placed widgets' 1-4 answer). The `update` notice reads exactly "Widget extension before the swap: <found> found, <n> ended by SIGTERM, <n> by SIGKILL, <n> still running, <ms> ms" (all `.public`); a process still alive at the give-up can end slightly above 1,500 ms (the last poll plus one 50 ms sleep), which already fails "every process ended". The script also checks that neither "The update's disk image isn't in diskutil info; it can't be ejected by force" (the `/private/var` match failing on the M5) nor "Ejecting the update's disk image failed: <status>" appears, and that no Finder window opens during the install (`diskutil image attach` has no `-noautoopen` counterpart; the DMG isn't marked to open a window, and the volume is mounted nobrowse) | Session B | G-16; WP-16 item 6; WP-21's F12 step (these checks) |
| `page.switch` count and p50 per page, before and after | Session A step 8; Session B step 5 | G-17 |
| F5 accessories, 2026-10-23 (interim): `bpulse --accessories` lists the 2 unnamed sources that `pmset -g accps` shows (AirPods), in 3 states. So macOS 27 doesn't hide the accessory list from apps (Stage 6's question). The F5 table's "not a list" for `pmset -g accps -xml` is the script's `plist_count`, which reads only the first of its back-to-back plists. **Still for Session A:** a keyboard on Bluetooth and on its cable (none was at hand; otherwise recorded as not run) | Session A step 2 | W0-4; ROADMAP Stage 6; D1's script |
| F5 iPad, 2026-10-23 (interim): no Local Network prompt and no library-validation message; the device log shows only "MobileDevice 1860.2.5.100.2 loaded". After the cable was detached, a "didn't answer" banner sat over stale "Connected by cable" values, and a fresh read over Wi-Fi was still labelled "Connected by cable": the label doesn't follow the transport | Session A step 2 | WP-23; ROADMAP Stage 5 |
| WP-23, 2026-10-23: **merged** into `claude/nice-faraday-k08mhb` as `2737b51` (head `ab44d4d`), beside WP-16, ahead of B1 (§5). **The cause, reproduced on Linux** (item 1; `IDeviceMonitorTests` with the fake transport and clock, an iPad listed on USB and Wi-Fi, the tests run on the 0.6.1 monitor and roster): `readOverWiFiAfterUnplugShowsWiFiThoughTheListStillSaysUSB` fails (after a Refresh over Wi-Fi the label stays `.usb`, the visible page keeps reading it every minute, and it never expires to "Not connected"); `unplugWhileStalledDropsUSBAndTryAgainReadsOverWiFi` fails (a read times out, then the cable leaves: the termination's list is dropped, and the label stays `.usb` under the timed-out banner's "Check the cable" wording, also after Try Again while usbmuxd lists USB); `unplugListedOnWiFiOnlyShowsWiFiAndKeepsOtherCables` already passed. The transport a read used never reached the label, and a USB termination reached it only through a list that applies. **The fix** (items 2-3): `IDeviceSession.readConnection` (the latest successful read's `Connection` key) and `usbTerminatedAt`; `IDeviceRoster.connection(of:now:)` takes the newest evidence (USB counts while the latest list has it and no termination, and no read over another interface after one, came later; a list or a USB read after the termination makes it count again; ties go to the termination or the read; otherwise the newest Wi-Fi sighting, then an unknown one, within 10 minutes), with the public `isOnUSB(_:)` and `sightingExpiry(of:now:)`, which `nextWake` uses. A read over another interface after a termination drops that device's `.usb`, so plugging it in again reads at once (`replugAfterReadOverWiFiReadsAtOnce`); a termination counts only with no arrival in the same debounce window; after one, automatic reads pause until the list applies; a read over Wi-Fi extends the Wi-Fi sighting to its own time. `DeviceView` and `Phrases.deviceProblem` already take `entry.connection` and didn't change; no new strings; item 2's read-transport field on `IDeviceEntry` was dropped, unused. **The review's major finding, fixed** (`acc1822`, reproduced by `readByCableAfterAnotherUnplugKeepsLaterFallbackReadsOnUSB`): `usbTerminatedAt` was set on every session and never cleared, so after any earlier termination a cabled device's first read that fell back to Wi-Fi dropped `.usb`: the label said Wi-Fi, its automatic reads and history stopped, and 10 minutes later it showed "Not connected" while still on its cable. A successful read over USB now clears it (a list that still has USB doesn't, since a stale usbmuxd listing is F5's likely cause). A minor one, fixed (`ab44d4d`, `forgottenAfterReadOverWiFiStaysHiddenWhileTheListStillSaysUSB`): Forget after a read over Wi-Fi no longer un-hides, reads and remembers the device at the next list. Tests 560 + 105 + 5 → 560 + 107 + 5 on the branch; lint clean; both CI jobs green | CI runs 40039705502 (`3b67fb2`), 40041297377 (`ab44d4d`); the round's review | WP-23 ran (its default, "not run", no longer applies); its M5 check is Session B's optional one (next row); ROADMAP Stage 5 (WP-22) |
| WP-23's known edges (minor, open): (1) a debounce that ends during a read marks every session terminated before its list runs, so other cabled devices show Wi-Fi or "Not connected" for the 1-3 s until the list returns (two or more devices on cable and an unplug during a read; the fix would touch four paths, and the fake transport can't check its timing); (2) while the monitor is stalled, a termination discounts USB on every session, so a phone still on its cable shows "Not connected" under the "couldn't look for devices" banner until Try Again (0.6.1 showed "Connected by cable"); (3) a list after a termination that fails with an error other than a timeout leaves a cabled device on Wi-Fi or "Not connected", not read automatically, until the next list; (4) after another device's termination, a cabled device whose first read falls back to Wi-Fi isn't read by itself until the next list, which, with history on and no page visible, may come after its sighting expired; (5) a usbmuxd listing that keeps a gone USB interface counts, after a read over Wi-Fi, as a new attachment, so each such list causes one automatic read, which falls back to Wi-Fi. Nobody has checked on the M5 that usbmuxd keeps listing USB after the unplug | the round's review; the implementer's notes | left as is ((1)-(2) by the review; (3)-(5) documented by the implementer); Session B's optional check is the real test: cable, unplug, Refresh over Wi-Fi reads "Connected over Wi-Fi", then "Not connected" about 10 minutes later, and a read timing out at the unplug shows the Wi-Fi wording |
| Charge Limit, 2026-10-23 (Session A; the maintainer set 80 % in System Settings; read-only captures, kept on the Mac): no `ChargeLimit` or `OptimizedCharging` key for the Mac's battery anywhere (`bpulse --raw`, three `ioreg` dumps, `pmset`). When the limit engaged at 80 % (21:37): `ChargerData.NotChargingReason` 0 → 16777216 (0x01000000, bit 24) in AppleSmartBattery and in its child AppleChargerData; `ChargingCurrent` 2626 → 0; `IsCharging` 1 → 0; `ExternalConnected` Yes; `FullyCharged` No; SMC `B0AC` and `B0AP` → 0. The configured 80 appears in no key. "Optimized Battery Charging Engaged" = false exists only in the AirPods' `accps` entries. `bpulse --smc` lists 43 `CH*` keys (names only, so whether one holds the limit is unknown). The maintainer wants the Charge Limit shown in the app, the menu bar and the widget. **Evening reads** (read-only, on AC at the 80 % limit; interim, exact values with the final `A.md`): `pmset -g battlimit` shows the 80 % limit; `bpulse --smc` lists `CHLT` and `CHNC`, not `CHLS`; the user-readable `/Library/Preferences/com.apple.powerd.charging.plist` (a keyed archive of `ChargeCtrlPolicy` objects with `battlimit`'s fields) and the defaults domain `com.apple.batteryui.charging.mac` (a prior limit of 80) are two more candidates for the number; and at the hold the charger child's inhibit and power-distribution keys showed charging inhibited and not allowed. The same reads at 100 % (or off), back at 80 % and on battery more than 5 minutes after unplugging, plus the plist's modification time, are pending (plan-0.7.0 Appendix C finding 9) | Session A (optional capture) | ROADMAP Stage 1.1, partly (WP-22); the display request is FEA-35 (`docs/plans/1.0/INVENTORY.md`), read-only and distinct from FEA-27 (setting a limit, not in 1.x, M-3): 0.7 shows the paused state from bit 24 (plan-0.7.0 W-14; a committed fixture still has to prove it, QUA-05: the redacted `charge-limit-80.plist` with the final `A.md` on the maintainer's yes, else Session B optional), and 0.8 the configured value, whose candidates are the SMC's `CHLT`, `pmset -g battlimit`, powerd's charging plist read as a file (its place, possibly first, waits for the pending reads) and, weaker, System Settings' prior limit (the private PowerUI client stays out, M-3); 0.8's NEW-01 keeps the other causes (bit 12 is still only a candidate); §8.3, §8.5; Appendix A |
| Session A's script, 2026-10-23: `log_since` counted ndjson's closing summary line (fixed in `9a32e57`); `pmset -g accps -xml` writes one plist per source back to back, and `plist_count` reads only the first; `screencapture -v` stops only at `-V` (SIGINT or the end of stdin loses the movie); the installs end the widget extension before each swap (`56702f9`) | Session A | D1's script; Session B step 3 |
| Session A's deviations, 2026-10-23: the session ran `killall chronod` once, for diagnosis; macOS asked for Accessibility for Terminal because of an `osascript` window query, and the maintainer allowed it, to revert after the session (he was later told to keep it until Session B, whose preflight asks again if he revoked it); the maintainer changed the Charge Limit himself (80, 100, 80), which restore doesn't cover | Session A | §6 (prepare asks for both, restore prompts for both; Session B's permissions); D1's script |
| F9: Russian pages | Session B | D3 (a failure becomes a fix) |
| F11: the alert step and the banner, or not run; the login item gone from Login Items | Session B | D3; ROADMAP Stage 1.2 |
| WP-16, 2026-10-23: **merged** into `claude/nice-faraday-k08mhb` as `f8a7445` (head `90eaf7a`), ahead of its B2 slot, beside WP-23 (§5). Item 1: `UpdateInstallPolicy.diskutil` (`/usr/sbin/diskutil`); attach `image attach --readOnly --mountPoint <dir> --mountOptions nobrowse <image>` (the runner's mapping, in its usage text's order); `info -plist <dir>` right after the attach (after a failed attach, the eject runs only when info shows our image there); `eject <dir>`; the forced fallback `unmountDisk force <disk>`, then `eject <disk>`, only with a known disk; every failure logged. `imageDisk(info:mountPoint:)` reads the image's own whole disk (the one APFS physical store's, else `ParentWholeDisk`) and is nil unless `BusProtocol` is "Disk Image" and `MountPoint` is exactly the folder (`/private/var` counts as `/var`); it uses `PropertyListDecoder`, so BatteryCore needs no new `unsafe`, and is tested with the CI-captured `Fixtures/diskutil/info-apfs-macos27.plist` (a subfolder, so CI's `Fixtures/*.plist` render loop skips it; the README has its row). Item 2: the step "Install the way 0.6.1 does, then launch" keeps 0.6.1's `hdiutil` lines and runs the `diskutil` pass twice (a plain eject; a file held open, so the plain eject must fail and the forced path runs), each checked in `diskutil list`; `UpdateInstallTests.ciMountsTheWayTheInstallerDoes` pins the YAML to the policy. Item 4 (E10): the automatic check runs in its own task (`UpdateChecker.automaticCheck`); Check Now cancels it and checks on `UpdateNetwork.user`; a cancelled check writes no status, records nothing and doesn't clear `running`; `checkIfDue` skips while a check runs; **the new decision** `UpdatePolicy.checkNow(during:)` returns `start` (no check runs), `takeOver` (an automatic one runs) or `wait` (the user's own runs), with the new public enums `UpdateCheckKind` and `CheckNowAction`. Item 6: `endExtensionBeforeSwap()` as designed (50 ms polls with 10 ms tolerance, so `EnergyGuardTests`' one-shots stay four), awaited after `checkCodeSignature(staged)` right before `renamex_np`, pinned by `UpdateInstallTests.endsTheWidgetExtensionRightBeforeTheSwap`; both scans share one `nonisolated` helper, `IsolationGuardTests.offMain` lists the three declarations, and the `kill` allow-list is unchanged. Item 3 adopts nothing (SEC-15's row); item 5 not run (A0). Also new: `infoArguments`, `forcedDetachArguments`, `imageDisk`; `detachArguments` lost its `force:` parameter; no strings, settings keys, storage formats, bpulse output or update assets changed. **Revert map** (G-16's default): `git revert 6bf1412` alone brings back 0.6.1's `hdiutil` code and test, and still applies cleanly on the head (`git merge-tree`); a CI step back to 0.6.1 only also reverts `90eaf7a`, then `4124451`; item 6 (`68c672f`) and E10 (`5e54fa8`) revert on their own. Both CI jobs green on the package head with no compiler warnings (the only "WARNING" lines are `hdiutil`'s runtime deprecation notices in the 0.6.1 pass); the launch smoke logs `menuBarReady`. On Linux the merged head (`2737b51`, with WP-23) passes 565 core + 107 kit + 5 tests, and `swift format lint --strict` is clean | CI runs 40039004378 (`4124451`), 40040104901 (`6bf1412`), 40041426583 (`90eaf7a`); the round's review | WP-16 acceptance's CI part (passed); G-16's revert path; F12 stays Session B's; WP-22: `docs/ROADMAP.md` lines 230 and 597 still describe the `hdiutil` mechanics |
| `diskutil` on the macOS 27 runner, 2026-10-23 (CI): **usage:** "USAGE: diskutil image attach [--verbose] [--stdinpassphrase] [--plist] [--readOnly] [--nobrowse] [--mountPoint <mountPoint>] [--mountOptions <mountOptions>] [--mp <mp>] [--noMount] <image-url> [--shadow <shadow> ...]", argument-parser style, with its own `-b`/`--nobrowse` and `--plist`, **no counterpart of `-noautoopen` and no verification-skip option**; a missing `--mountPoint` folder is created, and deleted on unmount; success prints the `/dev` node, a tab, the content hint and the mount point. "diskutil eject [force] MountPoint\|DiskIdentifier\|DeviceNode": **on macOS 27 `eject` takes `force`**; "diskutil u[n]mountDisk [force] MountPoint\|DiskIdentifier\|DeviceNode" also unmounts the virtual volumes APFS implies (the installer keeps the portable two steps). **The image's disk:** the DMG attaches as `disk17` (GUID_partition_scheme, `disk17s1` Apple_APFS), its volume `disk18s1` on the synthesized APFS container `disk18`; `diskutil info -plist <mount point>` gives `MountPoint` = the folder, `BusProtocol` "Disk Image", `APFSPhysicalStores` [`disk17s1`] and `ParentWholeDisk` `disk18` (the container, not the image's disk): the fixture. **Eject:** `diskutil eject <mount point>` printed "Disk <mount point> ejected" and also detached the image's own disk (`disk17` and `disk18` gone from `diskutil list`); with a file held open it failed ("Unmount of disk18 failed: at least one volume could not be unmounted / Unmount was dissented by PID … (/bin/bash)"), then `unmountDisk force disk17` printed "Forced unmount of all volumes on disk17 was successful" and `eject disk17` "Disk disk17 ejected", and nothing was left attached. **At the app's mount point** (the review's finding, fixed in `90eaf7a`: the first passes mounted under `$RUNNER_TEMP`, in `/Users`): both passes mount at `$(getconf DARWIN_USER_TEMP_DIR)BatteryPulse-update`, under `/var/folders`; `diskutil info` reports `MountPoint` resolved, `/private/var/folders/…/T/BatteryPulse-update`, with "Disk Image" and `disk17s1`; the eject of the unresolved `/var` path ejects the whole image, and the forced path behaves as under `/Users`. **Timings** (coarse, from the runner's log timestamps, not the M5): attach about 0.26 s, a plain eject about 0.18 s, the forced path (the failed eject, `unmountDisk force`, `eject`) about 0.36 s. Both install passes (0.6.1's `hdiutil`; `diskutil` plain and forced) green on every run | CI runs 40039004378, 40040104901, 40041426583 | WP-16 items 1-2: the parser, the forced fallback, the `/private/var` match and the eject by mount point; **G-16's CI half: passed** (its M5 half is F12); F12 is no longer the first test of the `/var` case |
| WP-16's known edges (minor, open): an automatic check cancelled before its first job still sets "Checking", and would leave it showing only if that job ran after Check Now's whole check had finished, which can't happen in practice (both tasks are enqueued on the main queue, the automatic one first, and Check Now's check needs a network round trip); a `!Task.isCancelled` in `check()`'s first guard would close it. The app's own installer code (`UpdateInstallSteps` on `diskutil`, `endExtensionBeforeSwap()`) first runs for real in F12: CI runs the same commands from the shell, and the extension's end against chronod has only Session A's script behind it | the round's review | left as is, to avoid another Darwin commit; F12 is the real test |
| Sleep hygiene: `pmset -g assertions` per run (Session A, interim: 0 BatteryPulse lines in every run of the window, the A/B energy row); the overnight `pmset -g log` | Sessions A and B | WP-21 |
| SEC-15, 2026-10-23 (interim; Session A step 7, the real 0.6.1 DMG on the M5; the exact runs with the final `A.md`): `hdiutil attach` about 152 ms, with `-noverify` about 158 ms, `diskutil image attach` about 292 ms, which has no verification-skip option (the usage text: the `diskutil` row above). The skip saves nothing | Session A | SEC-15: **not adopted**, no code change (the `attachArguments` doc says why `diskutil` needs no `-noverify`); the move to `diskutil` costs about 140 ms per install, unseen beside a download, so WP-16 item 1 goes ahead |
| Session A's swaps (interim; W0-2, WP-16 item 6): the script's pre-swap end of the widget extension took about 20 ms, by SIGTERM, on every swap (one logged 0 ms) | Session A (the script; the photo of Terminal) | WP-16 item 6's timings: the 0.5 s SIGKILL and the 1.5 s give-up are ample |
| F12's first failure | Q-B9 | WP-16 acceptance |
| A/B energy (S1, S2, S2 Low Power Mode, S6, S7), 2026-10-24 (interim, read from the maintainer's photo of Terminal; the final `A.md` gives the exact rows): Session A's unattended window, A = `claude/baseline-0.6.0` build 158 (the instrumented 0.6.0), B = 0.6.1 build 7; every run on battery, 1 minute to settle, then `rusage` over 4 minutes (S6 10 minutes with the displays asleep); started 23:56:41 on 2026-10-23 at 83 %, ended 01:00:32 at 77 %. The runs are in the table after this one; `pmset -g assertions` counted 0 BatteryPulse lines in every run. **S6's B run is not valid:** the maintainer woke the display and unlocked about a minute into it, not told that S6 darkens the screen on purpose. S7, 5 cold launches each to `menuBarReady` with power in the menu bar: B 162, 160, 161, 139, 141 ms (p50 160), with 1 read before `menuBarReady` and 1 in all per launch; A 179, 174, 177, 155, 151 ms (p50 174), with 2 reads before and 3 in all; the widget extension's process read 3 times in both | Session A's window (the photo) | WP-21 baseline, interim. 0.6.1 against 0.6.0 is lower in S2 (energy 443-517 against 504-948 mJ/h, CPU about 8-20 % lower, 6 reads a minute against 8) and in S2-LPM (energy about 46 % lower, 3.5 reads a minute against 8.5: the Low Power Mode refresh policy works); WP-2a's launch is confirmed on the M5 (1 read before `menuBarReady` instead of 2, launches about 8-9 % faster). S1 shows 0.6.1 higher (229 against 166 mJ/h) in a single pair that was the window's first run, while two identical S2 A runs differ by almost 2× (504 against 948), so one pair can't settle it: Session B (WP-21) discards a warm-up run, runs at least three pairs per scenario and compares medians, and if S1 still differs, WP-21 looks for the cause (WP-21's queue now has the discarded warm-up, three pairs each of S1 and S2, a same-day Low Power Mode pair, S6's B C pair and medians, 2026-10-24). The idle wake-ups (about 600-1,600 an hour, far more than the 2-8.5 reads a minute) are a question for the final `A.md`'s pslog and wake-up sources, and so are B's 3.5 reads a minute in S2-LPM and 2.0 in S1, above the 2 and about 1 that WP-21 expects. In absolute terms every row is under about 1 J an hour, about 0.0005 % of the battery an hour. S6's pair is repeated in Session B (B's row is disturbed), where the touch detector and the arm window's S6 warning (WP-21's hands-free mode) cover what disturbed it |
| C energy, S4w, S5, burst, memory | Session B | WP-21, G-13c |
| Session B's preflight: each proof's result (P1-P11 in B0's preflight, P12 at the burst's first unplug) and the fallback it switched to; the app names computer use accepted; the prompts and auto-mode blocks met at the start, and whether Accessibility had to be allowed again | Session B (B0, B1) | §6 Session B's steps; plan-0.7.0 W-12 and §6.2 |
| Session B's runs marked not valid (touched, slept, adapter, locked, screen saver, style not in effect, Low Power Mode, Claude active, a window open, `rusage` failed), per run, and their retries; whether a session acted while `queue.started` existed | Session B (the queue) | WP-21's pass criteria; whether the detectors hold for Session R |
| `log stream` across the night's sleep: whether the stream kept its lines after the wake, and its gaps | Session B (B5-B7) | plan-0.7.0 §6.2 step 12 (`sudo log config` only if the stream dies) |
| The hands-free mode's cost: the maintainer's minutes per moment, the GUI phase's length and computer-use actions, and the steps recorded "not checked" or "not run" with their reasons | Session B | plan-0.7.0 §6.2's estimates |
| B3 bench rerun; `HistoryLoad.read` profile | WP-17 | WP-17 riders |
| WP-15, 2026-10-24: **merged** into `claude/nice-faraday-k08mhb` as `bb5132d` (head `fe0a9a0`) in round B2 (§5). **Item 1, K-03 (`60c08d1`):** a `BatterySource` target and library product, made by git moves of `BatteryProvider` (with `BatteryObservation`), `AccessoryProvider`, `MacBatteryProvider`, `MacAccessoryProvider`, `SMCClient`, `SystemNotifications`, `IOSBatteryProvider` and `Diagnostics` (`Signposts`, `RefreshTrigger`); the only access change is BatterySource's `Diagnostics` and its members made `public`. The widget depends on BatteryCore and BatterySource only; BatteryKit depends on BatterySource, with no `@_exported`. Beyond the plan's import list: `UpdateChecker.swift` and `HistoryView.swift` import BatterySource too (they call `Signposts.Interval.end()`, and `MemberImportVisibility` requires it), and `App/Diagnostics.swift`, the widget and `bpulse/Record.swift` import BatterySource instead of BatteryKit, whose other members they don't use. The new **`BatterySourceTests`** target takes `MacBatteryProviderTests`, `MacAccessoryProviderTests` and `DiagnosticsTests` (`@testable import BatterySource`), and `BatteryKitTests` gains the dependency. `SourceScanner.otherTargets` lists BatterySource; `SecurityGuardTests`' allow-list paths, `smcClientCallsOnlySelectorTwo`'s path and `somewhere` point at `BatterySource/`, and an `IOServiceOpen` injected into `BatterySource/MacBatteryProvider.swift` fails it (checked by hand, pinned as an expectation). The new Linux test **`everySourceFolderIsAListedTarget`** checks that the folders under `Sources/` equal `targets + otherTargets` (checked by hand to fail on a stray folder). `build-app.sh` fails if `otool -L` of the widget lists CryptoKit, and prints the widget's `nm -u` `_dl*` imports: `_dlerror _dlopen _dlsym` after K-03 and after internalize, so **dead stripping keeps `MacAccessoryProvider`** (informational). The widget's link map no longer lists CryptoKit (it did, with SHA256 code) or Observation. **The golden bpulse diff is empty** (Linux debug builds of `c4803c8` and the K-03 tree, and the review's of `c4803c8` and the head): every fixture in text, `--json`, `--raw` and `--decimal-comma`, the history exports (`--export csv`, `json`, `csv --days --decimal-comma` on a saved store), `--help`, the missing-history error and the usage and exit-code cases; only the current-time fields differ, as between any two runs. **Item 2:** `-internalize-at-link` on the widget's line (`8549229`), with a check that the app binary's UUID is the same before and after the widget's line, and, measured and adopted in its own commit, on the app's line (`64f8aaa`); both dSYMs still come from `$BIN_PATH` (`.build/out/Products/Release`) and match the bundle, the posture check passes, and the CI launch smoke passed with both flags (running at 30 s, `menuBarReady`, quit, no crash report, no failed runtime lookup in the launch log). `4c1c0bd` prints each release build line's time. **Item 3:** SZ-14 and SZ-11 measured and not adopted (next row). **Item 4** is D1's, after the RC. The review's one fix, `fe0a9a0`, names BatterySource in `build-app.sh`'s note on the export list (with internalize on both lines, the `_main`-only export list is what lets the linker drop unused public code); comment only, the same UUIDs. Tests: Linux 708 → 709 (587 core + 111 kit + 6 BatterySource + 5), macOS 728 → 729 (5 + 13 `BatterySourceTests` + 124 + 587); no compiler warnings; the iOS build of BatteryKit, which compiles BatterySource with `IOSBatteryProvider`, passed | CI runs 40048131190 (`60c08d1`), 40048658013 (`8549229`), 40049337069, 40050705024 (`64f8aaa`), 40052102109 (`fe0a9a0`); the round's review | G-15 (§7.1); D1's ceilings; WP-22: README's Architecture block, CLAUDE.md's layout lines and "an app and a BatterySource twin" |
| WP-15's sizes and build times, 2026-10-24 (CI). **Before** (`c4803c8`, run 40046692780): widget binary 1,413,408 B, `__text` 970,476 B; app binary 2,924,912 B, `__text` 1,975,428 B; DMG 1,485,134 B. **K-03 alone** (run 40048131190): widget 1,131,008 B (−20.0 %), `__text` 775,896 B (−20.0 %); DMG 1,398,861 B (−5.8 %); app +16,480 B, `__text` +2,460 B (the public `Diagnostics`). **Widget internalize** on K-03 (run 40048658013): widget 778,640 B (−31.2 %), `__text` 489,132 B (−37.0 %); DMG 1,285,985 B (−8.1 %); the app unchanged (2,941,392 B, the same UUID as without the flag). **App internalize** (run 40049337069): app 2,941,392 → 2,837,888 B (−3.5 %), `__text` 1,977,888 → 1,895,020 B (−4.2 %); DMG 1,285,985 → 1,257,517 B. **The final head against `c4803c8`** (`64f8aaa`, run 40050705024): widget 778,640 B (**−44.9 %**), `__text` 489,132 B (−49.6 %); app 2,837,888 B (−3.0 %), `__text` 1,895,020 B (−4.1 %); DMG 1,257,281 B (**−15.3 %**); `app_kb` 4712 → 4004. `fe0a9a0` builds the same UUIDs (widget 88146EA5…, app 77312583…), so the builds are deterministic across runs. **Build times** (the app line varies 47-79 s on the same inputs): without the flag, app line 51 s and widget line 15 s (run 40048131190); the flag on the widget's line only, 79 s and 62 s (40048658013); on both lines, 50 s and 13 s (40049337069), 71 s and 19 s (40050705024), 47 s and 14 s (40052102109). **SZ-14** (`-dead_strip_dylibs` on the widget, run 40049337069): the same 29 dylibs and `__text` 489,132 B, because after K-03 every dylib supplies a symbol; not adopted. **SZ-11** (full LTO, SwiftPM's hidden `--experimental-lto-mode=full`, on top of internalize; runs 40049337069 and 40050154771): widget 778,640 → 664,560 B (−14.7 %), `__text` 489,132 → 384,804 B (−21.3 %), widget line 43 s; the app (an unsigned measure) −6.4 %, below the 10 % bar, though its `__text` fell 10.1 %. But the DMG grew 8,488 B (1,257,517 → 1,266,005), and `dsymutil` couldn't open the deleted LTO temporary object ("unable to open object file"), so the widget dSYM's `debug_info` shrank 1,533,764 → 761,598 B: **the dSYM lost the LTO'd code's DWARF**. Not adopted, after one adopted CI run: a hidden experimental option with no runtime evidence; a retry needs `-object_path_lto` | CI runs as listed | G-15's CI half; D1 lowers the `widget_*` ceilings to the RC's numbers plus about 5 % (now 778,640 B and `__text` 489,132 B) |
| WP-15's known edges (minor, open): internalize has only partial runtime evidence, SPIKE-I (0.6.1 plus the widget's flag, small and medium) and the CI launch smoke. The widget's `supportedFamilies` is `[.systemSmall, .systemMedium]` (`BatteryPulseWidget.swift:25`), so SPIKE-I covered every family it offers, and F8's "every family" means those two, in both languages. The review found no runtime-only name lookup it could strip (no `NSClassFromString`, `NSSelectorFromString`, `_typeByName`, AppIntents, or `dlsym` of the app's own symbols), but conformance records are runtime metadata, so only the M5 runs show the result. `8549229` doesn't `git revert` cleanly on top of `64f8aaa` (the two overlap in the comment above the lines); `64f8aaa` and K-03 do (`git apply -R --check`), so a blank F8 is a one-line edit of the widget's line, plus "Both lines add" in that comment. The review's golden diff loaded no minute samples from its hand-made history store, so its CSV sample rows were empty in both builds (the export code is untouched; the days and JSON exports matched) | the round's review | left as is; G-15's fallback (§7.1) |
| WP-19, 2026-10-24: **merged** into `claude/nice-faraday-k08mhb` as `1bb19d7` (head `fa6de42`) in round B3 (§5), beside WP-21. Seven commits, one per item and SW-13 split per target: the release statistics (`4855705`, its row below), the checkout and upload-artifact pins (`3cf59b6`, `795e5a2`), SW-21's DocC check (`a01fd0e`), C2's peak-memory step (`4f1f678`), SW-13 on BatterySource (`452cb28`) and on BatteryKit (`d80f35e`); the review's one fix, `fa6de42`, gives the last three unmarked `unsafe` sites (two in `MobileDeviceLibrary.bind()`, one in `MobileDeviceTransport.startService(_:)`) their reasons, comments only. **SUI-09: dropped, no change needed.** No `@State` in the app is both given a default and assigned in `init`, and no `State(initialValue:)` is left: `App/BatteryPulseApp.swift` sets each in one place (the monitor, accessories, demo and updater in `init`, since they depend on the monitor or on init-time work; `launchAtLogin` at its declaration, Apple's recommended form). The optional `AppServices` grouping wasn't done: it is readability only, and it would hide behind one more type the start order of `historyRecorder`, `AppDevices.start`, `notifier` and `widgetRefresher`, which no compiler or test checks. Beyond the file list: one DocC disambiguation in `RegistryReadPolicy.swift` (``cachesOnPolls-type.property``), which SW-21 needs. No catalog strings, settings keys, storage formats, bpulse output or update contract changed. The review left one informational edge: the peak-memory step runs without `pipefail`, so a failing bpulse would cut its table short while the step passes (the fixture-render steps after it fail on any bpulse error). Tests 587 → 589 core (`SecurityGuardTests`' `fourSafeTypes` and `strictMemorySafetyTargetsAreTheListedOnes`); 0 warnings on both jobs; lint clean. **Revert order** (G-14a, G-15): `fa6de42` and `d80f35e`, then `452cb28` | CI runs 40055564373 (`d80f35e`), 40056575311 (`fa6de42`), 40057041397 (`1bb19d7`); the round's review | WP-19's acceptance (met); G-14a's and G-15's revert order (§7.1); WP-22: CLAUDE.md's unsafe-code sentence, `scripts/` list and CI lines, ROADMAP's readability and CI pin lines |
| `release-stats.swift`'s first live table, 2026-10-24 (a cloud session; its output is in `4855705`'s commit message): **DMG downloads** 0.6.1 3, 0.6.0 3, 0.5.0 2, 0.4.0 1, 0.3.1 4, 0.3.0 2, 0.2.0 1, total 16 (14, then 15 at the re-check, on 2026-10-22; §10); **`.sig` downloads** 0.6.1 2, 0.6.0 3, 0.5.0 1, 0.4.0 0, 0.2.0-0.3.1 "—", total 6; Count "—" for every release. Every DMG and `.sig` count equals `gh api`'s, and the review's live run the same day matched (DMG 16, signature 6). The cloud proxy reported an authenticated quota (15,000 an hour), so the 60-an-hour path was checked only by `--self-test`. The date column is the UTC publishing date (v0.3.0 shows 2026-10-15, where ROADMAP lists 2026-10-14); the total row counts pre-releases, which the Tag column marks "(pre-release)"; a network error exits 1 with its description, since there is no HTTP status. The sample (`scripts/release-stats-sample.json`) equals the day's `gh api` response for v0.2.0-v0.6.1, plus a draft, a pre-release and an unrelated asset; the review also checked `--repo bad` and a 403 for a missing repository (both exit 1) and `--input -` | WP-19 (the live run); the review (`gh api`) | WP-19's acceptance (met); D3's Releases columns, a week after publishing |
| CI pins, 2026-10-24 (WP-19's `3cf59b6` and `795e5a2`; the review checked both SHAs with `git ls-remote`): **`actions/checkout` v7.0.1** (`3d3c42e`, commit 2026-07-17, marked Latest, in CHANGELOG.md with v7.0.0), from v6.0.3. **v6.1.0 turned down:** still a lightweight tag on `releases-v6` (`d23441a`); it now has a GitHub release ("[BREAKING] backport allow-unsafe-pr-checkout") but no CHANGELOG.md entry. v7's one behaviour change blocks fork-PR checkout under `pull_request_target` and `workflow_run`, which neither workflow uses. **`actions/upload-artifact` v7.0.2** (`cf430e0`, 2026-10-07), from v6.0.0: v7.0.0 added an `archive` input that defaults to true, so uploads stay zipped, and v7.0.2 bumps `@actions/artifact` to 6.3.1; its release notes are its changelog. Both still run on node24, both are full SHAs with changelog links in their commit messages, in ci.yml (green in run 40055564373 and in every later run that carries them: 40056575311 and the integration runs 40057041397, 40062237144, 40066338727, 40069133831) and release.yml (the same SHAs and inputs, `persist-credentials: false` included; first run at D3's release) | WP-19; the review | WP-19's CI-pin item (done); WP-22: ROADMAP's CI pin line ticked; D3's release run is release.yml's first with the pins |
| SW-13, 2026-10-24 (a macOS 27 / Xcode 27.1 build of a temporary probe commit with the flag on, no markers and the warning gate off, dropped from the branch before its final history): the compiler flagged **25 expression sites plus 1 unsafe-storage type in BatterySource** (`MacBatteryProvider`, `SMCClient`, `SystemNotifications`, `MacAccessoryProvider`) and **108 plus 3 in BatteryKit** (`MobileDeviceLibrary`, `MobileDeviceTransport`, `USBDeviceWatcher`). `DeviceKeys`, `UpdateSignature`, `IDeviceTransport`, the monitors, the iOS-only `IOSBatteryProvider` and every Linux-compiled part had none. On Darwin `OpaquePointer` (`IONotificationPortRef`) counts as unsafe, and `mach_task_self_` is flagged as a `nonisolated(unsafe)` var; `@unchecked Sendable` isn't flagged, nor are `Array.withUnsafe(Mutable)Bytes` calls, only the uses of their pointers. **As merged:** every site marked `unsafe`, with an `Unsafe:` reason comment on its statement or its group; four `@safe` types, each saying why (`MacAccessoryProvider`, `MobileDeviceLibrary`, `MobileDeviceLink`, `USBDeviceWatcher`'s `Watch`); `SecurityGuardTests` gains the escape placements (`@safe` in those four files only, `nonisolated(unsafe)` or `unowned(unsafe)` only in `SystemNotifications.swift`, no `StrictMemorySafety` silencing anywhere), a count test of the `@safe` types and a manifest test that pins the strict targets (BatteryCore, BatterySource, BatteryKit, bpulse); `MobileDeviceLibrary.bind()` builds its table into a local before `.success(library)`, with the same behaviour. No guard test checks the reason comments; the review read them by eye. 0 warnings on both jobs at `d80f35e` and `fa6de42`, and in the iOS `xcodebuild` of BatteryKit | WP-19's probe build; CI runs 40055564373, 40056575311; the review | WP-19's SW-13 (done); WP-22: CLAUDE.md's unsafe-code sentence |
| SW-21, 2026-10-24 (the Linux job, run 40055564373): the step "Check the documentation links" runs `swift package dump-symbol-graph` with the build's `-Xswiftc` flags, which doesn't rebuild, then `docc convert --warnings-as-errors` over BatteryCore's graph (internal symbols included), and fails when the graph is missing. **It costs 9 s** (docc about 4 s), under WP-19's minute. **BatteryCore only:** BatterySource's and BatteryKit's comments carry about 20 unqualified links to BatteryCore types, which DocC can't resolve per module (`--dependency` resolves only qualified links). One ambiguous link fixed (`RegistryReadPolicy`, ``cachesOnPolls-type.property``). The review put a ``NoSuchSymbol`` link in a BatteryCore comment, saw docc exit 1, and reverted it. Only BatteryCore's Linux-compiled code is checked | WP-19; CI run 40055564373; the review | SW-21 (done); WP-22: CLAUDE.md's CI lines |
| C2, 2026-10-24 (a trial on the macOS job, run 40053684730; tried once, as WP-19 says): on the `xcode-27` runner, a virtual machine, `/usr/bin/time -l` prints no "instructions retired" or "cycles elapsed" line, so **no instruction budget is possible**. The peak memory footprint is stable instead: over three runs `--help` read 1,836,352 B every time, and the fixtures 2.18-2.80 MB, each within one or two 16 KB pages (`m5-macos27-charging` 2,573,696 / 2,590,080 / 2,590,080 B). Following the plan's fallback, the macOS step "Peak memory of the parser" writes the release bpulse's peak footprint per fixture, plus `--help`'s for the start-up share, to the step summary, with no budget; the branch's final run shows `--help` at 1,819,968 B and the fixtures from 2,131,328 to 2,753,984 B. Keeping only the footprint follows the 0.6.1 playbook's rule: a counter stays only if it is non-zero and stable | WP-19 (the trial run, then the step's summaries); the review | C2 (done, as the footprint table); WP-22: CLAUDE.md's CI lines |
| WP-21, 2026-10-24: **merged** into `claude/nice-faraday-k08mhb` in three steps (§5), from `c4803c8`, ahead of its C1 slot. **`075abdd`** (head `8149531`): the implementation (8 commits); a review whose 6 majors and 9 minors were fixed (14 commits, head `fda6369`); then two reviews side by side, one of the safety rules and one of the measurements and the night, whose 30 findings were all fixed (11 commits; by the reviews' own labels 4 blockers, 11 majors, one of them found by both, and 15 minors). **`87c883d`** (head `c47e0d2`): a third safety pass, 0 blockers, 5 majors and 6 minors, all fixed (6 commits). **`780ff10`** (head `e7e9a7d`): a delta pass over the third pass's changes, 3 majors and 1 minor fixed (4 commits), each a new check that refused a step Session B needs: attach refused every picture once his remembered devices were back, and after WP-23's device check (now a picture is judged by the devices remembered when it was taken, and `devices forget` follows the check); the morning `continue` missed Apple silicon's lowercase lid wake line; a desktop click was refused under the cursor's own Window Server window (now only in the menu bar's strip); and the arm wasn't found among a caller's ancestors under `pipefail` (it failed closed). Files: `docs/plans/0.6.2/m5-session.sh`, `ui.swift` and `frames.swift`, `scripts/rusage.swift` (`awake_seconds` from a `SuspendingClock`) and ci.yml (the Linux job's `queue --dry-run` step for default, low and late; `swiftc -typecheck` of `ui.swift`); `swap.swift` unchanged. **What the script does now.** It runs as Session B from the frozen worktree `~/bp-062/B/run`, with its results in `~/bp-062/B`, `claude/062-session-b` and `sessions/B.md`, on three builds: B (v0.6.1's DMG), C (the RC) and CP (the profiling RC). **`ui`** clicks, moves, scrolls, drags, presses, selects rows, minimizes, sets full screen, positions, quits (BatteryPulse, or an app the script opened) and finds banners through AX, CGEvent and CGWindowList, and reads frames, titles, hit tests, trees, windows, the idle time, the lock and the thermal state; it never posts a key press (only a Shift or Control flagsChanged around a click, never Esc). It acts only in BatteryPulse; in System Settings only in the panes P8 confirmed plus Accessibility → Display, never Privacy & Security, Users & Groups, Touch ID & Password, Lock Screen, Passwords or Login Password (English and Russian, by the sidebar's selected row and the title; an unreadable selection refuses); in TextEdit only in the cover window (`~/bp-062/B/bp-062-cover.txt`), in Xcode only in windows under `~/bp-062/B/run`, and in Accessibility Inspector; Finder only as the bare desktop with one plain click, the Dock only at the minimized window's own tile, Control Center only at its clock, the widget hosts (`com.apple.notificationcenterui`, `com.apple.chronod`, or a `com.apple.WidgetKit.*` host P1 adds) only inside an element labelled BatteryPulse, and Terminal's windows only by position. Every click, move and scroll names its target (`--expect` with an app, `desktop` or `dock-tile`, and `--window <CGWindowID>`), whose AX owner and topmost window must both match, and a fresh window-list recheck (the same top window and pid; no lock, closed lid, fence, screen saver, loginwindow or refused window) runs right before every mouse down, wheel event and move, and a drag's first down and last up. SIGINT, SIGTERM and SIGHUP are blocked from a press's down to its release, and a Shift, Control or button left down is released at the next action. ui takes its home from the account (`getpwuid`; it refuses everything while `CFFIXED_USER_HOME` is set) and its panes, hosts and widget frames from files there, never from the environment; the script takes the home from `dscl` and fails if `$HOME` differs. **The queue** (the arm's, as of 2026-10-24): a discarded S2 C warm-up; S2 B C ×3; S1 B C ×3; S2-LPM B C; S4w in Standard, Clear, Translucent and Standard again, then Frosted; S5; S10 if accessories are listed; S7 (5 launches each); S3; the minimized run; one retry of each run not valid (S1, S2 and S2-LPM as pairs; a run invalid for LPM never); then S6 B C. Every run needs 50 %, an optional run or retry 56 % and room for itself plus 25 minutes for S6 ("not run: time kept for S6"); nothing starts later than 3 hours after the bedtime unplug; each run waits for a nominal thermal state (at most 10 minutes) and HIDIdleTime ≥ 60 s. By its plan, before the cooldown and the retries, S6 starts about 147 minutes in and the queue ends about 171 minutes in (6 per run, 12 per S6, 3 for S7). Build B's launches mark the installed version as seen, so What's New never opens. **Detectors** per run: touched (HIDIdleTime at the start and end and in the 10-s sampler), slept (`rusage`'s `SuspendingClock` against its `ContinuousClock`, and `pmset -g log`), adapter (`ExternalConnected` true, Yes or 1, and `pmset -g batt`), locked or lid closed (S6 by a sample taken just before its display goes off), screen saver (its on-screen window, since `pgrep -x` may not match names past 16 characters), style (the `com.apple.universalaccess` flags, "unknown" when unreadable, and a window-ID shot read in the morning), LPM, Claude (the CLI found by its command line: any new child, or CPU above its own rate over the cooldown plus 2 s), a BatteryPulse window open (S1, S2, S2-LPM, S6, S10) and a failed `rusage`; S6 is valid only with its display off from start to end, and is announced inside its first run, 30 s ahead, by the arm window's line and an alert, with no sound. **The fence:** once `ready` is up or `queue.started` exists, every acting command and ui refuse unless the arm (its pid and start time) is among the caller's ancestors; only `continue` opens it, after the queue's end, with the screen unlocked at the console and the lid open, input at most 15 minutes old (HIDIdleTime, or the HID event state where P6 finds that it ignores posted events), and a lid wake (or a Clamshell Sleep) in `pmset -g log` after the queue's last sign of life; the lid wake and the unlocked screen are what software can't make. **Reports:** the queue report runs `perf-stats` over every C run's `perf` lines for G-14b's two numeric Session B criteria (`read cached` p50 and `registry.missed` per hour of logged runtime, with the minutes measured), and `f12 after` prints F12's verdict lines for G-16 (every extension process ended within 1,500 ms; no `BatteryPulseWidget` from before the swap; no eject-failure line; Finder's on-screen windows, sampled every 0.5 s between `f12 before` and `f12 after`, at most 10 minutes). **The arm** holds `caffeinate -d -i` for the GUI phase; at his Return it runs one `sudo -v` (if the ticket isn't bound to its terminal, `sudo -k`, and S2-LPM is not run) and a keep-alive until `queue.done` (at most the unplug plus 3 h 45 min); the tools it runs under the ticket are hashed and read-only from prepare on, checked with a clean worktree before `sudo -v` and before the queue. **prepare** (B0a): his yes first, a fresh backup, the builds and tools, his remembered iPhones and iPads removed for the session, the RC installed, a beep; **`prepare reads`** (B0b) reads what Session A asked; **preflight** runs P2, P6-P9 and P11 with the permission, Automation and `tell application` checks; the session calls `proof` for P1, P3, P4, P5 and P10, and P12 runs at the burst's first unplug, each into `proofs.tsv` with the fallback it switched to. **`changes.tsv`:** `change` records each change first and refuses an unknown original, and `restored` confirms it by a read; `restore gui`, `night` and `morning` work from it, mark an item restored only when it reads back as the backup's, and quit only the apps the script opened (`launched.tsv`), naming any other. **Privacy:** `send` needs his B-send yes, newer than the contact sheet of every attached image, and its lint refuses a `B.md` line with the ComputerName, the LocalHostName, his full, short or first name, an accessory or Bluetooth name, an iPhone or iPad name (now, in the backup, or forgotten), a VPN name or the SSID (or says the SSID wasn't checked); attach takes only the script's own crops under `shots/` or `recordings/`, never one the size of the display, a Clear, Translucent or Frosted shot only on the generated wallpapers, and never a picture taken while BatteryPulse remembered a device by name; `unattach` takes only names in `captions.tsv`. **`devices forget`**, right after WP-23's check and before `mark away`, quits the app, removes the session's own device store and relaunches it with `readDevices` off (refused once `restore morning` has begun, or when the folder is the backup's); `mark away` warns while a device is still named. Nothing has run on a Mac: CI type-checks `ui.swift` and `frames.swift` on macOS 27 with no warnings and dry-runs the queue on Linux; the DMG mounts still use `hdiutil`, which warns on macOS 27 but works | CI runs 40048965317 (`8e21e52`) and 40052625706 (`27af620`), 40055686604 (`fda6369`), 40061684651 (`8149531`), 40065666925 (`c47e0d2`), 40068681150 (`e7e9a7d`); integration runs 40062237144 (`075abdd`), 40066338727 (`87c883d`), 40069133831 (`780ff10`); the reviews | §6 Session B (the steps it names); D1's script pins and `SESSION-B.md`; G-14b's and G-16's Session B lines (§7.1); the next row's checks |
| WP-21's behaviours still to confirm on the Mac (open). Nothing of the script has run on a Mac; a wrong guess makes its step refuse and record "not checked" or "not run", never act. **Preflight's proofs,** P1-P12 (§6). **Named by the reviews:** whether a banner's AX text carries the notification's English body inside an element labelled BatteryPulse (V-01's "This is how battery alerts will look", F11's "You can unplug the power adapter"; P2); the `CGSessionCopyCurrentDictionary` key names `CGSSessionScreenIsLocked` and `kCGSSessionOnConsoleKey`; the screen saver's process names `ScreenSaverEngine` and `legacyScreenSaver`, and whether `pgrep -x` matches a name past 16 characters (preflight records both counts); `xcrun xctrace record --no-prompt`; whether posted events reset HIDIdleTime, and whether `.hidSystemState` ignores them (P6); the line `pmset -g log` writes for a lid-open wake on Apple silicon ("LidOpen", "Lid Open" or a lowercase "lid", as in "due to smc.70070000 lid"), or a Clamshell Sleep at the close, without which `continue` never passes; the cursor's Window Server window, which a desktop click must not count as the menu bar (the top 44 points, or a Window Server window along a display's top edge at most 60 points high); whether bash 3.2's `read -t` returns early on SIGUSR1 (else the 60-s backstop applies); `pmset -g battlimit` below the charge hold; whether a click fired 1 s into a `screencapture -v` clip lands after the recording has started. Also named: whether System Settings' sidebar selection is readable on macOS 27 (else ui never acts there, and `guard` refuses while it shows a window); the AX role at an empty desktop spot; whether desktop widgets sit below layer 0 and fit ui's size limits (220×220, 440×220, 440×460 and 880×460 points); whether the TextEdit and Xcode windows' `AXDocument` is set; whether a dragged widget's image is its host's; whether BatteryPulse owns the status item's AX element and window (P11); that loginwindow shows no window while unlocked; the Claude detector's threshold for an idle CLI; that F12's Finder watcher, a background subshell, outlives the Bash tool call (else fewer samples, not a wrong verdict); `actool` on a `.icon` source | WP-21's reviews | Session B's preflight and B0; D1's `SESSION-B.md` (each step's fallback) |
| P1 evidence, recorded 2026-10-24 (the maintainer's photos of Session A's VoiceOver step, step 4): VoiceOver announced the desktop widget's accessibility container as "In BatteryPulse, widget, 9 items". So the widget host exposes "BatteryPulse" as the container's label: the app's name, not the widget's display name ("Battery", `BatteryPulseWidget.swift:23`). That is what ui's BatteryPulse-label rule needs (a title, description or identifier that begins with "BatteryPulse", on the element or one of its 10 parents), so a widget element inside that container can pass it. Still for P1: which attribute carries the label, the host process, the parent chain and the frame; the banner's and the gallery's labels stay unconfirmed | Session A step 4 (the photos) | P1's expected result; ui's widget-host rule (WP-21) |
| SUI-17 previews y or n; SUI-19's 5 slowest bodies in ms; SZ-10's shots in the four icon styles and the maintainer's answer | WP-18 (Session B; the maintainer's y in the morning batch) | WP-18; SZ-10 ships or waits for 0.7 |
| SEC-18: what a self-signed identity keeps across an update | WP-20 | 0.9.0's SEC-02 decision (`docs/plans/1.0/ROADMAP.md` §3.5) |
| The release statistics a week after publishing, 0.2.0-0.6.2 | D3 (`release-stats.swift`) | ROADMAP's Releases columns |

**Session A's energy window, 2026-10-23/24 (interim).** Read from the maintainer's photo of Terminal,
in the order it lists them; the final `A.md` gives the exact rows. A = `claude/baseline-0.6.0`
build 158 (the instrumented 0.6.0), B = 0.6.1 build 7. Every run on battery: 1 minute to settle,
then `rusage` over 4 minutes; S6 10 minutes with the displays asleep. LPM is Low Power Mode;
Assertions counts BatteryPulse's lines in `pmset -g assertions`. What the rows decide: the A/B
energy row above.

| Run | Build | LPM | Energy mJ/h | Idle wake-ups/h | Interrupt wake-ups/h | CPU s/h | Footprint MB | App reads/min | Assertions |
|---|---|---|---|---|---|---|---|---|---|
| S1 | B | 0 | 229.3 | 945 | 1,890 | 1.779 | 20.3 | 2.0 | 0 |
| S1 | A | 0 | 166.1 | 900 | 1,440 | 1.367 | 19.9 | 3.0 | 0 |
| S2 | B | 0 | 443.5 | 1,290 | 2,490 | 4.664 | 20.4 | 6.0 | 0 |
| S2 | A | 0 | 504.4 | 1,575 | 2,730 | 5.090 | 20.1 | 8.0 | 0 |
| S2 | B | 0 | 517.2 | 1,440 | 2,700 | 4.778 | 20.6 | 6.2 | 0 |
| S2 | A | 0 | 948.4 | 1,530 | 3,495 | 5.942 | 20.0 | 8.0 | 0 |
| S2-LPM | B | 1 | 258.3 | 1,065 | 1,860 | 2.362 | 21.3 | 3.5 | 0 |
| S2-LPM | A | 1 | 478.5 | 1,530 | 2,265 | 4.862 | 21.1 | 8.5 | 0 |
| S6 | B | 0 | 215.0 | 1,020 | 1,770 | 2.021 | 20.4 | 2.1 | 0 (**not valid:** the display woken and the Mac unlocked about a minute in) |
| S6 | A | 0 | 166.0 | 594 | 1,422 | 1.485 | 20.1 | 3.2 | 0 |
