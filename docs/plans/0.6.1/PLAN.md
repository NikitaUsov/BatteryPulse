# BatteryPulse 0.6.1: the plan

Written 2026-10-16 on `claude/nice-faraday-k08mhb` at `c9ea33c` (`a32bfae` plus the audit files).
Base release: 0.6.0 = `main` = `6133b4f`. The implementation workflows follow this file one
package at a time. They may append facts to Appendix C and must not change anything else here.

Inputs: `playbook.md` (rules UI-*, SW-R*, EN-*, SEC-R*, SZ-R*, DC-*, the measurement protocol and
the frozen surfaces in its §3.4), the six `audit-*-verified.md` files (they win over the raw
audits), and `research/*.md` for detail. CLAUDE.md wins over all of them.

## 1. At a glance

- **Phases:** A (WP-0a ‖ WP-0b, the baseline branch, then WP-1 ‖ WP-UR); B in pairs (WP-8a,
  2a, 6a, 2b; the budget checkpoint; then 5, 4, 6b, 3a, 3b, 7, 8b; P2: WP-9, WP-2c); C (WP-11 ‖
  WP-12, then WP-11b if G13 passes); D (D1 freeze, D2 M5, D3 release).
- **How:** at most 2 agents, never two on the same file; one `claude/061-*` worktree branch per
  package; an implementation run and a review run; merged `--no-ff` into
  `claude/nice-faraday-k08mhb`; CI green after every merge.
- **P1 (about 37–43 runs, plus 3 kept for fix-forward: 40–46):** the measurement tools; the two
  user-reported look bugs; the Swift 6.4 manifest; a DMG about half the size; the signing,
  release-notes and update-integrity fixes; one read per notify burst and two-key SMC polls in the
  app; History and Raw Data off the main actor; dead code removed by link maps; guard tests.
  `Observations`, `Mutex` and the installer's `@concurrent` are P1 too, unless §6's checkpoint cuts
  WP-4, WP-6b or WP-7.
- **If the budget allows (P2, about 4–5 runs):** WP-9 (views), WP-2c (Low Power Mode, display
  sleep).
- **0.6.2:** main actor by default (WP-10), the MobileDevice helper, Enhanced Security, Icon
  Composer, E4b, and every item whose gate only the M5 can decide.
- **Budget:** a checkpoint after B2 decides the cut before any cuttable package starts (§6). The
  never-cut set alone is about 31–37 runs plus the reserve.
- **Maintainer:** one M5 session on the release candidate around 29–30 October: a core of about
  30 minutes that decides every gate, then optional extras (about 15 min hands-on, 15 min
  unattended), every command `bash docs/plans/0.6.1/m5-session.sh <step>`. Every gate and step has
  a default for when it doesn't run. Then the release approval and a 5-minute update check around
  30–31 October.
- **No lost functionality:** D1's diffs, CI on every run (with WP-8a's install-and-launch smoke)
  and the session check `bpulse`, settings, storage, the update contract and the installer.

## 2. Done already (on the branch since 0.6.0; part of 0.6.1)

| Commit | Change | Settles | Leaves open |
|---|---|---|---|
| `6584585` | Clear's glass sheet gets a near-black dimming (40 % Light, 32 % Dark). The Settings preview takes its tint from `WindowLookPolicy`. | CH-14: done, its hunk is this commit | CH-13 raises the dimming to 0.65 (WP-UR), with a plain-fill variant held ready for G11, and rewords the guide text this commit wrote |
| `ec61436` | The selected tile carries the selection glass itself | CH-12's deletion of `glassOutset` and `selectionGlass(for:)` | CH-12 removes the remaining glass (WP-UR) |
| `994c09d` | `WidgetReloadPolicy` also reloads on the first estimate after a plug change, and after a 3-point or 15-minute move, at most every 15 min | No audit item. It **supersedes** EN-11's "≤ 25 reloads a day" and §2.7's "S8 ≤ 1 reload per cycle" (see §3.1) | E15's day test asserts this policy's own maximum, without changing it (WP-4). CORE-12's optional site moved to about line 140. CORE-20 stays rejected |
| `a32bfae` | An accessory is named after its earbuds, not its case | No audit item; it is a user-visible fix for the notes | The golden-output reference is `c9ea33c`, not `6133b4f` (§5) |

None of the four commits has been checked on the M5. The session's core covers the first two (V1,
V2); the optional F5 and burst steps cover `a32bfae` and `994c09d`, which Linux tests cover
otherwise.

## 3. Packages in run order

### 3.0 How every package runs

**Branches and worktrees.**
- Integration branch: `claude/nice-faraday-k08mhb`. Its checkout at `/home/user/BatteryPulse` is
  used only for merges.
- Each package gets its own worktree and branch, which CI builds because the branch name matches
  `claude/**`:

  ```
  git -C /home/user/BatteryPulse fetch origin
  git -C /home/user/BatteryPulse worktree add /home/user/wt/<pkg> -b claude/061-<pkg> origin/claude/nice-faraday-k08mhb
  ```

- With two agents on 4 CPUs, build with `-j 2`. Never share a `.build` folder between worktrees.

**Implementation run.**
- One commit per item where practical, so any item can be reverted alone.
- Before each commit: `swift format format -i -r Sources Tests Package.swift`, then `swift build`,
  `swift test` and `swift format lint --strict -r Sources Tests Package.swift`.
- Push. Any Darwin change needs a green macOS job; read it with
  `gh api repos/NikitaUsov/BatteryPulse/actions/runs?branch=claude/061-<pkg>`. Cloud sessions have no
  GraphQL, so use `gh api` or the GitHub MCP tools rather than `gh pr` or `gh release`.
- Report in the last commit message: the items done, the items dropped (with the reason), and the
  §4 rows the package moves.

**Review run.** A separate agent reviews before anything merges.
1. Read this package's section and `git diff origin/claude/nice-faraday-k08mhb...claude/061-<pkg>`.
2. Check every item against its verified version, then the acceptance checks, then the frozen
   surfaces (playbook §3.4) and the repository rules (English only, no third-party names, never the
   signing key). Check that no file outside the package's lists was touched and that the test count
   has not dropped.
3. Fix small findings on the branch itself. Send anything larger back as one fix run.

**Merge.** The reviewer merges.
1. Rebase onto the integration tip and push with `--force-with-lease`.
2. Wait for both jobs to go green.
3. `git merge --no-ff claude/061-<pkg> -m "Merge WP-x: <goal>"`, then push and wait for CI on the
   integration branch.

The next merge waits until that CI run is green. A red integration run is fixed forward at once.
Merge commits keep each package revertable with `git revert -m 1`.

**Strings.** Only WP-6a and, after it, WP-5 add catalog keys, so the two never run in parallel on
`Localizable.xcstrings`.

**Concurrency schedule.** A free slot takes the first package in this table whose dependencies have
merged **and** whose Owns and Shares lists name no file that a running package owns or shares.
Exempt are WP-1's mechanical fix-ups and hunks that both packages list, such as WP-11's and
WP-12's `Motion.swift`.
Phase B's cuttable packages start only after the budget checkpoint (§6), which sits between B2 and
B3.

| Round | Slot 1 | Slot 2 | Waits for |
|---|---|---|---|
| A1 | WP-0a | WP-0b | — |
| A1′ | baseline branch (orchestrator, 1 CI run) | | WP-0a + WP-0b |
| A2 | WP-1 | WP-UR | A1 merged |
| B1 | WP-8a | WP-2a | WP-1 |
| B2 | WP-6a | WP-2b | WP-2b needs WP-2a |
| B3 | WP-5 | WP-4 | the checkpoint; WP-5 needs WP-6a (catalog); WP-4 needs WP-2a (`lastReadAt`, CH-08 hunk) |
| B4 | WP-6b | WP-3a | WP-6b needs WP-6a |
| B5 | WP-3b | WP-7 | WP-3b needs WP-3a (`HistoryTests`, `Benchmarks.swift`); WP-7 needs WP-2b (K-04 helper) |
| B6 | WP-8b | WP-9 (P2) | WP-8b needs WP-8a and WP-6a (`release.yml`); WP-9 needs WP-5 and WP-UR |
| B7 | WP-2c (P2) | — | WP-2b |
| C1 | WP-11 | WP-12 (merges last) | all of Phase B; WP-11 needs WP-8a's maps |
| C2 | WP-11b (P3, only under G13) | — | WP-11; merges before WP-12 |
| D1 | measure and freeze the RC | — | Phase C |
| D2 | M5 session (maintainer) | | D1 |
| D3 | release | | D2, or its defaults |

### 3.1 Decisions where the inputs disagree

| Topic | Playbook | Verified audit or new constraint | Wins, and why |
|---|---|---|---|
| `SourceScanner` (WP-0) | Extract the scanner | CORE-02: `static let` regexes don't compile (Regex isn't Sendable); the literal prefilter could hide violations | Verified (compile error reproduced) |
| SW-R6 target | 9 → "5 or fewer" | K-05: `USBDeviceWatcher` can be plain `Sendable`, so the target is 4 | Verified (typechecked). Stays 5 only if WP-6b's SDK gate keeps `DownloadWatcher` `@unchecked` |
| SZ-14 premise | Only `UpdateSignatureVerifier` pulls in CryptoKit | K-03: `HMACDeviceKeyDeriver` keeps CryptoKit referenced in the widget | Verified, with its gate (G13): WP-11 measures; the split runs as WP-11b only if the gate passes and the budget allows, else 0.6.2 |
| User-reported look bugs | Not in the playbook (written before them) | CH-12 and CH-13: a new package, WP-UR | Verified. Run in A2 rather than first, so WP-0 cherry-picks cleanly onto `6133b4f` |
| CI job timeouts, `upload-artifact` | Not covered; SEC-06 pins `upload-artifact@v4` | K-02: `timeout-minutes`. CB-07: v6.0.0 (`b7c566a`), which removes the only CI warning | Verified, moved from WP-8 to WP-0b, the first owner of `ci.yml`, so every later run is protected and the warning gate starts clean |
| `${{ }}` in `run:` | SEC-06 says there are none | CB-08: `BUILD_NUMBER=${{ github.run_number }}` at `ci.yml:75`, `release.yml:70` | Verified; WP-8b moves it into `env:` |
| Release notes | — | CB-06: a P1 guard that the notes open with this version's heading | Verified; WP-8b, and a release gate |
| SW-12 in History | Sites only in WP-2, 4, 6 and 7 | AV-12: the four `try?` in `HistoryView.load` must be logged | Verified; WP-3b |
| K-04 ownership | — | A new dependency: WP-7 adopts WP-2b's notify helper | Verified; scheduled B5 after B2 |
| SUI-05R/E13 gate | `history.load` 7 d > 50 ms on the M5 | The M5 numbers come only in D2, after WP-3a has run | Plan: a Linux gate, B2 cold 7 d > 50 ms in the container. The research measured 83–91 ms there; the playbook's intent ("expected") is kept |
| SW-04 / V-01 (WP-10) | P1 in Phase C | One 30-minute session can't cover V-01 (notifications, sleep and wake, an install from a test release, the widget after an update). The failure mode is a runtime trap that only the M5 shows, and the gain is readability | Plan: deferred to 0.6.2 as its first package. V-01's notification checks and SW-R7's launch-sample check also verify WP-4, so they stay in the session (F11). AC-03, which the verified audit put in WP-10 "before the sweep", moves to WP-11 |
| AV-04 rated cycles | WP-9 | Verified places it in WP-9, a P2 package here | Plan: part 1 becomes a core WP-5 item (not a rider), because WP-5 owns `Localized.swift` and runs earlier, so this latent bug fix can't be cut |
| E4a scope | EN-4: non-live SMC keys at most every 60 s | `bpulse --watch`, `--record` and the widget share `MacBatteryProvider.read()`; §3.4 freezes `bpulse` | Plan: the provider's default stays "every key on every read"; only `BatteryMonitor` opts into the 60 s policy |
| Widget reload targets | EN-11 ≤ 25 a day; S8 ≤ 1 reload per cycle | `994c09d` deliberately reloads at once on each state change and the estimate's arrival, plus at most 4 movement reloads an hour (its comment: 40–70 a day) | Plan: E15's day test asserts the policy's own maximum on a day the plan defines (WP-4), and WP-4 records the day's total in Appendix C. The policy is not tuned in 0.6.1 |
| M5-only checks | SEC-01 corrupted `.sig`; CH-08 hidden status item; AC-07 `fs_usage`; AV-06 empty tooltip; AC-03 timing; CH-12 Reduce Motion and VoiceOver; CH-09 `defaults delete`; K-15 `chmod 500`; S1 and 3 × A/B energy runs | Prefer gates that CI or Linux can decide; a 30-minute core | Plan: SEC-01 → Linux mapping tests. CH-08 → the member count, correct in either case. AC-07 `migrate()` → no change. AV-06 → the fallback strings. AC-03 → its toggle in F11, no timing. CH-12 → `MotionGuardTests` (only `motion.crossfade`) and the review (the `isSelected` trait and the Show Borders overlay stay). CH-09 → a Linux test that `MenuBarContent.default` is icon + percentage. K-15 → the review of each log call's privacy. Energy → one optional S2 A/B; S1 to 0.6.2. Each default: ship |
| Mandatory M5 numbers (§2.7) | All before and after, each the median of 3 long runs | One short session | Plan: §4. CI and Linux numbers are the release gate; M5 numbers are reported when the session happens |
| Baseline | WP-0 lands on `main`; branch `perf/baseline-0.6.0` | CI runs only on `main` and `claude/**` | Plan: WP-0 lands on the integration branch, and the baseline is `claude/baseline-0.6.0` |

### 3.2 Phase A: foundation

#### WP-0a: Instrumentation in the code (P1)

- **Goal:** one measurement vocabulary in the code, with no behaviour change, so that the baseline
  and the candidate measure the same intervals.
- **Items:**
  - SUI-01/E1:
    - `App/Diagnostics.swift`: the SW-R10 `Logger`s, plus a `perf` category, and one
      `OSSignposter` in `.pointsOfInterest`;
    - `BatteryKit/Diagnostics.swift`: a twin behind `#if canImport(os)`, a no-op on Linux;
    - one helper, `measure(name, metadata)`. It opens a signpost interval and logs a `.debug`
      line with the duration under `perf`. The M5 session reads these lines with `log stream`,
      so it needs neither Instruments nor `get-task-allow`. The signposts serve Instruments.
    - **The `perf` line format**, which WP-0b's `perf-stats.swift` parses (both packages cite
      this item; every part is `privacy: .public`, being a static name, trigger or number):
      - an interval: `perf interval <name> ms=<duration, 3 decimals> trigger=<trigger or ->`;
      - an event: `perf event <name> trigger=<trigger or ->`;
      - `refresh` carries the trigger (`notify`, `poll`, `launch`, `history`, `demo`, `manual`);
        its nested `read` and parts log `trigger=-`;
      - a notify burst is a run of `refresh trigger=notify` lines less than 1 s apart; its reads
        are the `read` lines inside it.
  - The playbook §2.2 names, as one-line wraps:
    - intervals: `refresh` (with its trigger), `read` and its parts (`registry`, `children`,
      `iops`, `adapter`, `smc.power`, `smc.other`, `parse`), `history.record`, `history.load`,
      `raw.rebuild`, `raw.filter`, `page.switch`, `device.read`, `accessory.read`, `update.check`;
    - events: `widget.reload`, and `menuBarReady` once per process (the once-flag CH-08 asks
      for).
  - B1–B6 in `Tests/BatteryCoreTests/Benchmarks.swift`:
    `.enabled(if: ProcessInfo.processInfo.environment["BP_BENCH"] == "1")`, timed with
    `ContinuousClock`, one warm-up, then the median of 15. B2 generates a 7-day store.
  - `Tests/BatteryCoreTests/SourceScanner.swift`, extracted from `MotionGuardTests`:
    - with CORE-02: `starts(with:at:)` compares in place, and one `static let` table holds path,
      text and `codeOnly` per file;
    - the regexes stay computed `static var`, with no literal prefilter;
    - optionally `@Test(arguments:)` per file, keeping the `scanned > 20` check as its own
      assertion.
  - CORE-04: `LocalizationCatalogTests` caches the catalog and the source keys as
    `static let Result` values.
- **Owns:** the two `Diagnostics.swift`, `Benchmarks.swift`, `SourceScanner.swift`, and the scanner
  and cache parts of `MotionGuardTests` and `LocalizationCatalogTests`.
- **Shares:** one-line wraps only, which later owners rebase over:
  - `BatteryMonitor`, `MacBatteryProvider`, `SMCClient` (WP-2a/2b);
  - `IDeviceMonitor`, `AccessoryMonitor` (WP-7);
  - `HistoryRecorder`, `WidgetRefresher` (WP-4);
  - `HistoryView` (WP-3b), `DeveloperView` (WP-5), `MainView` (WP-2b, WP-9), `UpdateChecker`
    (WP-6a/6b), `MenuBarLabel` (WP-2a).

  It must touch no file changed by the four done commits, so that it cherry-picks cleanly onto
  `6133b4f`.
- **Gates:** none.
- **Acceptance:**
  - Linux build, test and lint, and the macOS job, are green.
  - `BP_BENCH=1 swift test -c release --filter Benchmarks` prints B1–B6.
  - `MotionGuardTests` and `LocalizationCatalogTests` are green. Report their serial and parallel
    times before and after. A violation injected into a scratch copy still fails.
  - `bpulse --input` over the 9 fixtures prints the same as before.
- **Effort:** M, 2 runs. **Risk:** low. **Parallel with:** WP-0b.

#### WP-0b: Measurement scripts, CI gates, baseline (P1)

- **Goal:** the tools and CI steps that produce every automatic number, and the "before" build.
- **Items:**
  - M1: `scripts/rusage.swift <pid> <seconds>` prints mJ/h with the P-core share, idle and
    interrupt wake-ups per hour, CPU s/h, instructions per hour, disk bytes per hour and
    `phys_footprint`.
  - New: `scripts/perf-stats.swift <log.ndjson>`. From `log stream --style ndjson` output in WP-0a's
    `perf` line format it prints the count, p50 and p95 per name and trigger, the reads per notify
    burst, the reads before `menuBarReady` per process, and the widget reloads. A committed
    `scripts/perf-sample.ndjson` (hand-written in that format: two processes, bursts of 1 and 2
    reads, a widget reload) and its `scripts/perf-sample.expected` output are diffed in "Check the
    verification scripts".
  - E2: `PROFILING=1 scripts/build-app.sh` signs the app (not the widget) with `get-task-allow` and
    names its outputs `…-profiling`. `release.yml` refuses such a build.
  - SZ-04 with SZ-09:
    - `scripts/size-report.sh` makes the playbook §2.4 rows and runs the hygiene checks. It
      writes Markdown to `$GITHUB_STEP_SUMMARY` and writes `build/size.json`;
    - the hygiene checks are **report-only** here: a count per check in `size.json` and the
      summary. The unstripped 0.6.0 binaries hold 133 `/Users/runner` strings (size research), so a
      hard failure would turn this job and the baseline red. WP-8a's SZ-01 commit makes them fail;
    - `scripts/size-budget.json` starts without ceilings;
    - both workflows upload `size.json`;
    - settle the `dyld_info -exports` output format and whether `plutil -extract` reads JSON.
  - SW-14: the warning gate (`-warnings-as-errors -Wwarning DeprecatedDeclaration`) on the Linux
    build and on the macOS `swift test`. Release builds don't get it.
  - SW-24 (CI part): run `swift package dump-package`.
  - K-02: `timeout-minutes`: Linux 15, macOS 30, release 60.
  - CB-07: `actions/upload-artifact@b7c566a772e6b6bfb58ed0dc250532a479d7789f # v6.0.0`.
  - A `version` input on `ci.yml`'s `workflow_dispatch`, passed to `build-app.sh` as `VERSION` and
    added to the DMG artifact's name. Pushes still build 0.0.0. D1 uses it for the session's
    0.5.99 build, the only one that can run Install and Relaunch (F12).
  - Add `swiftc -typecheck` of the new scripts to "Check the verification scripts", and the
    `perf-sample` diff.
  - `docs/plans/0.6.1/m5-session.sh`, a first draft of the §4b subcommands, checked with
    `bash -n`.
  - Answer the playbook §4 CI questions WP-8a needs, in Appendix C:
    - whether `.dSYM` folders appear in the bin path;
    - whether `-dead_strip` is on the link line and `-export_dynamic` absent
      (`swift build -c release --product BatteryPulseWidget -v`);
    - whether `hdiutil help` lists ULMO.
- **Owns:** `scripts/{rusage.swift, perf-stats.swift, perf-sample.ndjson, perf-sample.expected, size-report.sh, size-budget.json}`,
  `ci.yml` and `release.yml` (until WP-8a), the `PROFILING` block of `build-app.sh`, and
  `m5-session.sh`.
- **Gates:** none.
- **Acceptance:**
  - Both CI jobs are green with the warning gate on, and the size table, with the hygiene counts,
    appears in the step summary.
  - `bash -n` passes on `m5-session.sh`.
  - The scripts typecheck, and `perf-stats.swift` reproduces `perf-sample.expected`.
  - K-02's proof, on a scratch commit removed before merge: a test awaiting a never-resumed
    continuation shows "Time limit was exceeded" at 60 s, and the Linux job ends at its 15 minutes.
- **Then, A1′ (orchestrator):**
  1. `git switch -c claude/baseline-0.6.0 6133b4f`.
  2. Cherry-pick the commits of both WP-0 packages.
  3. Push. The macOS job must be green; its `size.json` (hygiene counts included) and DMG are the
     "before".
  4. Check that `git diff 6133b4f claude/baseline-0.6.0 --stat` lists only WP-0 files.
- **Effort:** M, 2 runs. **Risk:** low; the changes are CI-only. **Parallel with:** WP-0a.

#### WP-1: Manifest and language mode (P1)

- **Goal:** Swift 6.4 language policy in one place, and lint rules that lock in what already
  passes.
- **Items:**
  - SW-01: tools 6.4, `.macOS(.v27)`, `.iOS(.v27)` and a shared `strict` settings array. No
    `.defaultIsolation`.
  - SW-02: the five upcoming features.
  - SW-03 with V-02: `NonisolatedNonsendingByDefault`. Run `swift package migrate` once on macOS
    CI, in a temporary step, as a report pasted into the commit message; never commit its output.
  - SW-R3: `NoUseUnstructuredThrowingTask`, `ImplicitStrongCapture` and
    `ErrorInFutureSwiftVersion` become errors.
  - SW-13: `.strictMemorySafety()` for BatteryCore with 0 warnings. `bpulse` marks its one site
    `unsafe`, or stays without the flag.
  - SW-20:
    - fix the 10 `ValidateDocumentationComments` sites and the 1 `UseWhereClausesInForLoops`
      site;
    - turn on all nine rules.
  - SW-24 hygiene.
  - CB-09: the `Package.swift` comment says that `bpulse --input` and `--export` run on Linux.
  - CB-04, the last commit:
    - a `bpulseTests` target with a `@Test(arguments:)` parser table covering every rejection;
    - `Options: Equatable`;
    - no render split, and no test reads a top-level global of `main.swift`.
- **Owns:** `Package.swift`, `.swift-format`, the new `Tests/bpulseTests/`, and `Options` in
  `Sources/bpulse/main.swift`.
- **Shares:** the mechanical fix-ups the settings demand in any file (`any`, explicit imports such
  as `Combine`, `unsafe`); later owners rebase. Conflicts with WP-UR, running in parallel, are
  trivial.
- **Gates:** the macOS job decides the Darwin fix-ups.
- **Acceptance:**
  - `swift package dump-package` shows the settings.
  - 0 warnings on both jobs; the strict lint passes with the nine rules.
  - `swift test --filter bpulseTests` passes.
  - The manifest has no `-Xswiftc`; the only `unsafeFlags` are the widget's two.
- **Effort:** M, 2–3 runs (the third only if the Darwin fix-ups take several CI rounds).
- **Risk:** low to medium. `nonisolated(nonsending)` moves where `async` code runs; tests plus a
  review of each `@concurrent` cover it.
- **Parallel with:** WP-UR.

#### WP-UR: The user-reported look bugs (P1)

- **Goal:** the tile picker no longer floods the style it shows, Clear stays readable over a
  white window, and a glass-sheet window minimizes without a black frame.
- **The maintainer's choice comes first.** CH-12 (glass or an accent outline only) and CH-13
  (Clear at 0.40/0.32, about 0.50, or 0.65) were put to the maintainer on 2026-10-16. Their answer
  replaces the defaults below and gates G10 and G11; without an answer, the defaults stand.
- **Items** (one commit each, so each can be reverted alone):
  - **CH-12**, on top of `ec61436`: remove the tile picker's selection glass.
    - Delete the `GlassEffectContainer`, `@Namespace glassNamespace`, `let flows`,
      `.glassEffect`, `.glassEffectID` and `.glassEffectTransition`, and the glass comments.
    - Replace the `AnyShapeStyle` conditional with `.background(.fill.quaternary, in: shape)` on
      every tile.
    - Keep `.animation(motion.crossfade, value: selection)`, the disabled-tile opacity, the Show
      Borders overlay and the `isSelected` trait.
    - `MotionGuardTests` drops `SettingsView.swift` from `glassAllowList`, and the expectation at
      line 491 flips to `#expect(flags(...))`.
    - CLAUDE.md and ROADMAP line 20 drop the tile pickers from the custom-glass list.
  - **CH-13**, on top of `6584585`:
    - `.clear: Tint(white: 0.03, opacity: 0.65)` in both appearances;
    - update the doc comment and the `WindowLookTests` expectations;
    - new Linux test `clearKeepsTextReadableOverAWhiteWindow(systemDark:)`: a contrast floor
      computed from `sheetTint`, 4.5:1 for primary and 3:1 for secondary text, with a comment
      naming the label alphas it assumes;
    - USER_GUIDE line 141 describes sharpness rather than "most opaque to most transparent", and
      line 149 says "sharp but dimmed" and drops "lighter or smokier".
  - **CH-13's plain-fill variant, held ready, not merged:** one commit on its own branch
    `claude/061-ur-clearfill`, on top of the CH-13 commit. Clear's dimming becomes a plain fill
    over untinted `Glass.clear` inside `GlassSheet`, for Clear only (the verified audit's step 3);
    the contrast test then holds by construction. Its macOS job must be green. D3 merges it only
    under G11.
  - **UR-3, black frame on minimize** (reported 2026-10-16 on 0.6.0, M5): in Clear, minimizing the
    window (the yellow button or Command-M) turns its background black first, then the genie
    animation runs.
    - Likely cause, unverified: the minimize animation works from a snapshot of the window's own
      layers. The glass sheet's backdrop (the desktop sampled behind the window) is not part of it,
      so the sheet falls back to its tint, near-black in Clear's forced dark appearance.
    - First establish the extent from the code and Apple's documentation: does the same apply to
      Translucent (same sheet) and to Frosted (a material behind the window)? The M5 answers it in
      session step V4.
    - Candidate fixes, smallest first, choosing the first that is documented to work:
      (a) observe `NSWindow.willMiniaturizeNotification` and `didDeminiaturizeNotification` for the
      tracked window and, between them, draw the sheet's place as a still fill in the window's own
      tone (no glass), so the snapshot has something to show; (b) make sure the window stays
      non-opaque with a clear `backgroundColor` while a glass sheet is shown, if SwiftUI leaves it
      opaque; (c) if every glass window on macOS 27 does this, write it down in USER_GUIDE and the
      ROADMAP decisions and change nothing.
    - The swap must not animate (a background swap is not a motion event) and must not survive
      a restore; Standard and Frosted stay untouched unless step one shows they are affected.
- **Owns:** the tile picker in `Settings/SettingsView.swift`, `BatteryCore/WindowLook.swift`,
  `App/WindowLook.swift` (`GlassSheet` on the variant branch; UR-3's minimize handling),
  `WindowLookTests`, the glass list in `MotionGuardTests`, and the glass-list lines of CLAUDE.md,
  ROADMAP and USER_GUIDE.
- **Gates:** G10 and G11 (§3.6), decided by the maintainer in the session.
- **Acceptance:**
  - `swift test --filter "MotionGuardTests|WindowLookTests"`, the lint and the macOS job pass, on
    both branches.
  - `git grep -h -o -F glassEffect -- Sources/BatteryPulseApp/Settings | wc -l` prints 0 (only if
    the maintainer chose the accent outline).
  - UR-3: session step V4 shows no black frame when minimizing and restoring the main and the
    compact window in each style, in Light and Dark.
  - No string changes.
- **Effort:** S–M, 3–4 runs (UR-3 adds one). **Risk:** low; only the look changes, and only after the maintainer signs
  off.
- **Parallel with:** WP-1. It must merge before WP-9.

### 3.3 Phase B: parallel packages

#### WP-8a: Size (P1)

- **Goal:** the playbook's size wins, provable from the CI size report.
- **Items:**
  - SZ-01:
    - strip the bundle copies after `cp` and before `codesign`;
    - in the same commit, WP-0b's report-only hygiene checks become failures (SZ-09);
    - keep the dSYMs: look in the bin path first, else run `dsymutil`;
    - attach `BatteryPulse-dSYMs.zip` as a CI artifact and as an extra release asset. The names of
      the DMG and its `.sig` don't change;
    - the existing `nm` checks keep running on `$BIN_PATH`, never on the stripped copies.
  - SZ-02:
    - `-Xlinker -exported_symbol -Xlinker _main` on both `swift build -c release` lines of
      `build-app.sh`, not in the manifest (SW-R1);
    - confirm `-dead_strip` with `-v`, and add it if it is missing;
    - run `-why_live` on `RawSection.sections(for:)` in the widget.
  - SZ-03: ULMO, made by `hdiutil create` into a read/write image and then `hdiutil convert -format ULMO`.
  - SZ-05: `-Xswiftc -Osize` on the same two lines only.
  - SZ-06: `-Xlinker -map` for both shipped binaries, uploaded as artifacts.
  - New CI step, "install the way 0.6.0 does", run on the candidate DMG:
    1. `hdiutil attach` with `UpdateInstallPolicy.attachArguments`'s arguments;
    2. `ditto` the app out;
    3. `plutil -extract` `CFBundleIdentifier` and `CFBundleShortVersionString`;
    4. `codesign --verify --strict --deep --all-architectures`, the flags of 0.6.0's
       `checkCodeSignature`;
    5. detach;
    6. launch smoke: with `log stream --level debug` on the app's subsystem running, `open` the
       copied app, wait 30 s, then assert the process is alive, the `menuBarReady` event was
       logged and no `BatteryPulse*` crash report appeared; quit it with `osascript`.

    This puts the 0.6.0 → 0.6.1 install path under CI, which matters because the update runs
    0.6.0's installer, and from then on every macOS run launches the app. If the runner can't open
    a GUI app, WP-8a records that in Appendix C and drops step 6; F11's default (§3.6) then becomes
    "revert".
- **Owns:** `scripts/build-app.sh` (except the `PROFILING` block), the packaging and upload steps
  of `ci.yml` and `release.yml`, and the rows of `size-budget.json`.
- **Shares:** `release.yml` with WP-6a's key-check hunk.
- **Gates:** G2 (`-Osize`) and G3 (widget exports).
- **Acceptance:**
  - Size rows before and after go in the commit message.
  - `hdiutil imageinfo` reports ULMO.
  - Each binary exports `_main` only.
  - No `/Users/runner` strings remain, and the hygiene checks now fail the step (a flipped check
    shown once in a scratch commit).
  - `dwarfdump --uuid` of each dSYM matches its binary.
  - The install-path step, its launch smoke and the signing smoke pass; CI is green.
- **Effort:** M, 2–3 runs. It is CI-heavy: each iteration is a 3–5 minute macOS run.
- **Risk:** medium (the DMG format and the binaries). The install-path step and session step F8
  catch it.
- **Parallel with:** WP-2a.

#### WP-2a: Monitor: one read per burst, freshness, names (P1)

- **Goal:** fewer battery reads with the same values on screen.
- **Items:**
  - E8, the monitor half, as the **first commit**:
    `@ObservationIgnored public private(set) var lastReadAt: ContinuousClock.Instant?`, set in
    `refresh()`.
  - E3: notify callbacks go through `requestRefresh()`, which coalesces with a 150 ms window and
    a 100 ms tolerance. `refresh()` stays for callers that need a value now. The monitor gets an
    injected `Clock`.
  - C1, the monitor cases:
    - N callbacks in one burst give 1 read;
    - no live-refresh client gives 0 reads per simulated hour;
    - `lastReadAt` is reused.
  - K-14: the three timing-based BatteryMonitor tests move to the clock, and the "under 1 s"
    criterion goes.
  - K-02: `.timeLimit(.minutes(1))` on `BatteryMonitorTests` and `AccessoryMonitorTests`.
  - K-13: the test `Counter` over `Mutex<Int>`.
  - E7: the follow-up sleeps get about 10 % tolerance.
  - SW-08: names for the monitor's tasks.
  - SW-12: the `monitor` category.
  - E17 (P2 rider): a new live-refresh request skips its read when `lastReadAt` is under about 1 s
    old.
  - CH-08 (P2 rider):
    - the menu bar label counts its shown members (+1 on appear, −1 on disappear, `nil` at 0)
      instead of `nil` on any member's disappear;
    - a Scene `.onChange(of: showInMenuBar)` sends `nil` when the item is turned off;
    - `menuBarReady` keeps WP-0a's once-flag.
- **Owns:** `BatteryKit/BatteryMonitor.swift`, `MenuBar/MenuBarLabel.swift`,
  `BatteryMonitorTests`, and the time limit in `AccessoryMonitorTests`.
- **Shares:** a 3-line Scene hunk in `App/BatteryPulseApp.swift`. WP-4 owns that file and runs
  later.
- **Gates:** none. CH-08's member count is right whether or not hiding the item in System Settings
  tears the label down, so it needs no M5 check.
- **Acceptance:**
  - `swift test --filter BatteryMonitorTests` passes on Linux with no timing assertion.
  - The macOS job is green.
  - The review confirms that coalescing adds at most about 250 ms to plug and unplug (§3.4).
- **Effort:** M, 2 runs. **Risk:** low to medium (display latency). **Parallel with:** WP-8a.

#### WP-6a: Update integrity and the release channel (P1)

- **Goal:** the app never steers the user to a DMG it refused, and a second signing key can be
  listed.
- **Items:**
  - SEC-19 (needed by SEC-01): `ReleaseChannel` defines the owner, repository, API endpoint,
    releases page and asset names once.
  - SEC-01:
    - `UpdateFallback { downloadDMG, releasePage, none }` and
      `UpdateInstallError.isIntegrityFailure` in BatteryCore;
    - integrity failures and `.notSigned` show a warning and **Open Release Page**, which is not
      the default button, and no DMG offer;
    - `ReleaseLinks.browserURL(for:)` accepts only `https` on `github.com`, else the constant
      releases page. Every URL the update code opens (in `Updates/`, and `AppLinks.releases`) goes
      through it; the System Settings links don't;
    - `UpdateInstallError.message` and `reason` stop steering to the DMG where SEC-01 withholds it
      (`.notSigned`: "This release can only be installed from the DMG.");
    - the new strings get Russian translations.
  - SEC-05:
    - `ReleaseSigning.publicKeys`, with today's key as the only entry;
    - `release.yml` checks the secret's key against the list;
    - tests: K2 verifies with {K1, K2} and fails with {K1}; an empty or malformed entry is
      ignored. They generate throwaway keys and never touch the real one;
    - the rotation runbook, one paragraph in `scripts/sign-update.swift --help`: N ships {K1, K2}
      signed with K1; N+1 is signed with K2; a later version drops K1. Releases are signed only by
      the workflow.
  - SEC-02 with AC-01:
    - a `ReleaseNotesText(notes:baseURL:)` subview holding the ScrollView, text selection and
      background, with a `static notes(_:)`;
    - an `OpenURLAction` that opens only `https`;
    - `blocker` computed only in the idle phase.
  - AC-05: `UpdateInstallPolicy.unversioned` at the three literal sites, including
    `WhatsNewPolicy.markSeen`.
  - SEC-17 (P3 rider): a doc comment on the updater's boundaries, and a downgrade test.
- **Owns:**
  - `Updates/{UpdateChecker, UpdateViews}.swift`, and the `UpdateInstallError` `message`/`reason`
    extension in `Updates/UpdateInstaller.swift` (WP-6b owns the rest of that file and runs later);
  - in `App/AppSettings.swift`, `AppLinks` and one line of `WhatsNewPolicy`;
  - `BatteryCore/{UpdateInstall, Updates, ReleaseSigning}.swift` and
    `BatteryKit/UpdateSignature.swift`;
  - `scripts/sign-update.swift` (the `--help` runbook only);
  - the key-check step of `release.yml`;
  - `Localizable.xcstrings`;
  - `UpdateInstallTests`, `UpdatesTests` and `UpdateSignatureTests`.
- **Gates:** none. SEC-01's M5 check with a corrupted `.sig` is replaced by the Linux mapping
  tests.
- **Acceptance:**
  - Every `UpdateInstallError` maps to its fallback (test).
  - `browserURL` and the link check reject `http`, `file`, a custom scheme and a foreign host.
  - `git grep -h -o -F 'NikitaUsov/BatteryPulse' -- Sources | wc -l` prints 1.
  - The key check passes a dry run with a throwaway key.
  - The macOS job is green; session step F12 covers the window.
- **Effort:** M, 2 runs. **Risk:** low. A genuine release with a broken signature now shows a
  warning, which is intended. The change is user-visible.
- **Parallel with:** WP-2b.

#### WP-2b: Provider and SMC: read only what a poll needs (P1)

- **Goal:** polls read the two live SMC keys instead of all 16.
- **Items:**
  - E4a:
    - split `SMCBattery.keys` into `liveKeys` (`B0AV`, `B0AC`) and the rest;
    - the rest is read at most every 60 s, or while Raw Data or Power is shown. The main window
      tells the monitor which page is up (one hunk in `MainView`);
    - **opt-in:** the provider's default stays "every key on every read", as today, so
      `bpulse --watch`, `bpulse --record` and the widget are unchanged. Only `BatteryMonitor`
      turns the 60 s policy on and passes the page signal;
    - the freshness decision is a pure BatteryCore function over `Duration`, with merge tests;
    - K-01a: use `ContinuousClock` instead of `Date`;
    - K-07: the docs say 16 keys and a derived 3–8 ms.
  - SW-12: the `smc` and `iokit` categories.
  - K-08: log the per-key catch-all once per key per session, with the key and result code
    public. Keep 0x85 as is.
  - K-04:
    - `observeNotifyKeys(_:handler:)` and `powerSourceDescriptions(in:)` in
      `SystemNotifications.swift`, adopted by `MacBatteryProvider`;
    - compare against `kIOPSTypeKey` and `kIOPSInternalBatteryType`;
    - log a failed registration;
    - a new `MacBatteryProviderTests.observationCancels` (macOS).
  - SW-06 (P2 rider): `UncheckedSendable` becomes a local `nonisolated(unsafe) let`.
  - SW-07 (P2 rider): `SMCClient` without its `Port` helper, with a plain `deinit`.
- **Owns:** `BatteryKit/{MacBatteryProvider, BatteryProvider, SMCClient, SystemNotifications}.swift`,
  `BatteryCore/SMC.swift`, `SMCTests`, and the new `MacBatteryProviderTests`.
- **Shares:** `BatteryMonitor` (after WP-2a) and one `MainView` hunk (WP-9 later).
- **Gates:** G14–G16. E4b, E3b and E20 are deferred.
- **Acceptance:**
  - `SMCTests` covers the cached and fresh merge, and the commands stay 5, 8 and 9.
  - A BatteryCore test shows the policy is off by default; the review confirms that
    `bpulse --watch --raw` still reads every SMC key on each tick.
  - `@unchecked Sendable` drops by 1 if the SW-06 rider landed.
  - Raw Data still shows every key (session step F6).
  - The macOS job is green.
- **Effort:** M, 2 runs. **Risk:** low to medium. In the app, non-live SMC values can be up to 60 s
  old, which §3.4 allows.
- **Parallel with:** WP-6a.

#### WP-5: Raw Data and formatting (P1)

- **Goal:** Raw Data does its row and search work once per reading, off the main actor.
- **Items:**
  - SUI-02:
    - display rows with precomputed strings and one joined `searchText`, built in a
      `@concurrent` helper;
    - a UI-10 test: case-insensitive, and U+0438/U+0439 and U+0435/U+0451 don't match each other.
  - SW-05: `DeveloperView`'s `Task.detached` becomes a `@concurrent` call.
  - AV-04 part 1 (core, not a rider; §3.1): `BatteryPresentation.ratedCycles(_:)` and
    `fallbackRatedCycles = 1000` at the Overview, Health, Device and Compact sites, with a Linux
    test for nil, 0 and 1000.
  - P2 riders:
    - SUI-06: `UnitSymbols` and `BatteryFormatter` become `Equatable`, with `static let app` built
      on `Locale.autoupdatingCurrent`, so a region change still reaches the numbers without a
      relaunch. The names stay, so the 14 call sites don't change;
    - AV-01: Export Capture goes through `fileExporter`, with an error alert. One new key, with
      Russian.
  - P3 riders, dropped first in this order if the package runs long:
    1. AV-11: the volts-digits rule moves into `BatteryFormatter`, with 3 tests;
    2. AV-02: the Copy JSON test (no `"REDACTED"`, no `"serialNumber"`);
    3. CORE-12: icon digits round half-to-even, with `@Test(arguments:)` over 0…100 in 0.5
       steps;
    4. CB-05: `PropertyValue.xmlPropertyListData(_:)` in a new `BatteryCore/CaptureFormat.swift`.
       `bpulse`'s `xmlPropertyList`, `Record.swift` and Export Capture use it, and one round-trip
       test covers it.
  - B4 and B5 follow the new API.
- **Owns:**
  - `Main/{DeveloperView, RawValueText}.swift` and `App/Localized.swift`;
  - `BatteryCore/{BatteryFormatter, RawValueDecoding, RawKeyGlossary, RawSectionGroup, BatteryIcon}.swift`
    and the new `CaptureFormat.swift`;
  - the capture encoder in `Sources/bpulse/{main, Record}.swift`;
  - one catalog key;
  - their tests.
- **Shares:**
  - `BatteryPresentation.swift`, for `ratedCycles`;
  - the four AV-04 view files, with WP-9 later.
- **Gates:** none.
- **Acceptance:**
  - Raw Data search matches exactly what 0.6.0 matched in the UI-10 cases.
  - With SUI-06, the review confirms the formatter follows a region change without a relaunch.
  - B4 and B5 before and after are reported.
  - `--raw` output stays byte-identical (golden diff).
  - `LocalizationCatalogTests` and the macOS job pass.
- **Effort:** M–L, 2–3 runs. **Risk:** low to medium. **Parallel with:** WP-4.

#### WP-4: App services: observers, notifier, widget refresher (P1)

- **Goal:** the app's observation loops follow Apple's current pattern, with today's behaviour.
- **Items:**
  - SW-09, at all four sites: `HistoryRecorder:54`, `BatteryNotifier:79` and `:107`,
    `WidgetRefresher:25`.
    - Each becomes one named `Task` over `Observations { … }.dropFirst()`, cancelled in `stop()`.
    - A `BatteryKitTests` case pins the pattern on Linux: nothing is yielded for the current
      value, and one value per change.
  - V-03: no `Task { @MainActor in … }` in code that is already main-actor isolated.
  - SW-08: task names.
  - SW-12: the `history` and `widget` categories. The recorder's failed writes are logged instead
    of dropped by `try?`.
  - E7: `DemoController` gets a tolerance.
  - P2 riders:
    - E8, the recorder half: reuse a read younger than about 20 s;
    - E15: a `widget` log line and a `widget.reload` event per reload, plus a C1 day test in
      `WidgetReloadPolicyTests` that feeds `994c09d`'s policy, unchanged, a synthetic day:
      - 16 h awake from 07:00; unplugged at 07:00, 12:00 and 18:00, plugged in at 10:00, 13:00 and
        22:00 (6 plug changes); 8 %/h on battery and 30 %/h charging, to 80 %, where the state
        becomes "not charging"; one snapshot a minute; the estimate arrives 1 min after each plug
        change and follows the rate;
      - it asserts the policy's own maximum: per plug change the state reload plus at most one
        estimate reload; at most 4 movement reloads in any hour; a total of at most
        2 × plug changes + other state changes + 4 × awake hours;
      - WP-4 records the day's actual total in Appendix C. A failing bound is reported, never fixed
        by tuning the day or `WidgetReloadPolicy`;
    - V-04: drop `@preconcurrency import UserNotifications` if macOS CI builds without it.
- **Owns:** `App/{HistoryRecorder, BatteryNotifier, WidgetRefresher, DemoController, BatteryPulseApp}.swift`
  and the new case in `WidgetReloadPolicyTests`.
- **Gates:** G5 (V-04); session step F11 (§3.6).
- **Acceptance:**
  - `git grep -h -o -F withObservationTracking -- Sources | wc -l` prints 0.
  - The Linux pattern test passes, and the macOS job and its launch smoke are green.
  - In the session (F11): a relaunch adds exactly one history sample (the launch sample); Demo Mode
    posts no notification; a real charge-limit alert arrives with the app frontmost and opens it
    when clicked.
- **Effort:** M, 2 runs. **Risk:** medium. The behaviour lives in app-only code that no Linux test
  reaches; the review, the CI launch smoke and F11 cover it.
- **Parallel with:** WP-5.

#### WP-6b: Update code hygiene (P1)

- **Goal:** the installer uses `@concurrent`, `Mutex`, named tasks and private logs, with the same
  behaviour.
- **Items:**
  - SW-05: `verify` and `replace` become `@concurrent`. The named, fire-and-forget leftover cleanup
    is the only `Task.detached` left. One commit per site, so D3 can revert them under G22.
  - AC-04: one `infoDictionary(ofBundleAt:)` helper with its doc comment. No file move.
  - SW-06: `DownloadWatcher` moves to `Mutex`, as a checked `Sendable` (G4).
  - SW-12: the `update` category. The log at `UpdateInstaller.swift:523` becomes private.
  - SW-08: task names.
  - E7: tolerances on the 20 s (5 s), 6 h (30 min) and 200 ms (50 ms) sleeps.
  - CORE-03: on the test side, `#expect(arguments[1].contains("sleep 1; exec"))`, then replace
    `sleep 1;` with `sleep 0;`. No production parameter.
  - P2 riders:
    - SEC-03: one ephemeral configuration with `urlCache = nil`. Automatic checks set
      `allowsConstrainedNetworkAccess` and `allowsExpensiveNetworkAccess` to false and never
      `waitsForConnectivity`. Check Now is unchanged. `URLSession.shared` goes to 0;
    - E11: a `.userInitiated` activity around an install, ended by `defer`;
    - SW-08's shield: `withTaskCancellationShield` around the `replace` call only. P2, per the swift
      research (SW-08), which corrects the playbook's P1: it writes down "once checked, the update
      goes in" and changes nothing today;
    - SW-11: typed throws for `UpdateInstallSteps`, only if it stays small.
- **Owns:** `Updates/UpdateInstaller.swift` (except WP-6a's error texts), `UpdateChecker.swift`
  (after WP-6a), and the CORE-03 test.
- **Gates:** G4; G22 (session step F12).
- **Acceptance:**
  - `Task.detached` count is 1 and, with SEC-03, `URLSession.shared` count is 0.
  - `UpdateInstallTests` passes, and the serial test run is about 1 s shorter.
  - The install-path step still passes.
  - The session's step F12, the new installer of the 0.5.99 build installing the real 0.6.0, works.
- **Effort:** M, 2 runs.
- **Risk:** medium. The candidate's installer first runs for real in the 0.6.1 → 0.6.2 update; F12
  exercises it end to end before then, and G22 reverts the installer commits if it can't.
- **Parallel with:** WP-3a.

#### WP-3a: History store (P1; runs on Linux only)

- **Goal:** unchanged history days are decoded once.
- **Items:**
  - SUI-05R/E13: a decode cache, in memory only.
    - Closed day files are decoded once per session; the key is the day plus the file size.
    - Today's file is read from its last offset.
    - Clear History, pruning, the legacy migration and the day rollover invalidate the cache.
  - C1, the store cases:
    - 120 samples give 120 appends and at most 2 rewrites of `days.jsonl`;
    - a closed day is decoded once across two loads;
    - each invalidation works.
  - E14 (P2 rider):
    - the policy check runs before any syscall;
    - the legacy migration runs once per session;
    - the store keeps one encoder;
    - the slice is decoded without a `Data` copy;
    - appends stay per sample.
  - CORE-14: remove the `= Date()` default from `record(_:at:)`.
- **Owns:** `BatteryCore/HistoryStore.swift`, `HistoryTests` and the new store tests, and B2.
- **Shares:** none. The API stays, so `IDeviceMonitor`'s per-device stores are unchanged.
- **Gates:** G1.
- **Acceptance:**
  - B2 cold and warm, before and after, are reported.
  - The store tests pass.
  - D1's storage round trip shows byte-identical files.
- **Effort:** M, 2 runs. **Risk:** medium. A stale cache would show wrong History; the
  invalidation tests cover it.
- **Parallel with:** WP-6b.

#### WP-3b: History view (P1)

- **Goal:** the charts do no per-point formatting and no main-actor computation beyond one
  assignment.
- **Items:**
  - SUI-03: no localization, formatter or interpolation per chart point.
  - SUI-04:
    - `HistoryChartData` in BatteryCore (points, spans and statistics for 24 h and 7 d), built in
      a `@concurrent` function and assigned in one step;
    - fix the per-day `Calendar` in `HistoryDay.date()`;
    - AV-09: `Period` becomes a plain enum and moves to BatteryCore with the builder.
  - SUI-13, the History split (P2 rider):
    `Main/History/{HistoryView, ChargeChart, PowerChart, TemperatureChart, HealthTrendCharts}.swift`.
  - E7: the minute timer gets `tolerance: .seconds(15)`.
  - SUI-10/SW-08: task names.
  - AV-05: the recording sentence reads
    `@AppStorage(AppSettings.recordHistoryKey) … = true`.
  - AV-12: log the four `try?` load failures (category `history`, text private). No dedup state.
  - AV-08, in its own commit: the hover readout without `Material`, stroked with `.hairline`.
  - B3 moves to `HistoryChartData.make`.
- **Owns:** `Main/HistoryView.swift` (becoming `Main/History/*`), the new BatteryCore
  `HistoryChartData` and its tests, and `HistoryDay` in `BatteryCore/History.swift`.
- **Gates:** G12 (AV-08's look). SUI-12 is deferred.
- **Acceptance:**
  - The `HistoryChartData` tests pass, and B3 before and after is reported.
  - Audio Graphs values are unchanged (review).
  - The macOS job is green, and session steps V4 and F6 pass.
- **Effort:** M–L, 2–3 runs. **Risk:** medium (the charts' look and hover). **Parallel with:** WP-7.

#### WP-7: Devices and accessories robustness (P1)

- **Goal:** checked `Sendable` and monotonic time in the device stack, plus diagnosable failures.
- **Items:**
  - SW-06: `ResumeOnce` and `IDeviceListBuilder` move to `Mutex`.
  - K-05: `USBDeviceWatcher` becomes plain `Sendable`, and `Watch` keeps `@unchecked` with its
    comment.
  - CB-08's canary, moved here from WP-8b: the CI smoke step requires `--accessories --json` to
    exit 0, with a comment saying that it is a canary for the private symbol.
  - K-02: `.timeLimit` on `IDeviceListingTests` and `BlockingWorkTests`.
  - K-07: the `BlockingWork` doc.
  - K-13: `count(where:)`, the default RNG in `IDeviceMonitor` and `DeviceStore`, and one locked-box
    test helper instead of two.
  - K-01b: `ContinuousClock` in the discovery loop.
  - K-04: `MacAccessoryProvider` adopts WP-2b's helper.
  - CORE-01: the `.data` description through `UpdateIntegrity.hex`, with the test `<00ab0f>`.
  - CORE-19:
    - `Devices/` is created with 0700;
    - a single 0600 step;
    - the double space goes;
    - a `DeviceStoreTests` case.
  - DeviceStore: `isReadOnly = true` before rethrowing a failed move-aside (the kit verifier's
    one-liner).
  - P2 riders:
    - SW-12: the `device` and `accessory` categories, at K-15's sites. Case names are public;
      descriptions, paths and keys are private; identifiers are hashed;
    - SEC-09: the MobileDevice version in the `frameworkUnavailable` text and in the log, never on
      stdout.
  - P3 riders, one commit: SEC-09's `RTLD_LOCAL | RTLD_FIRST`, and K-09's
    `RTLD_NOLOAD | RTLD_FIRST`.
  - SEC-11: a depth limit of 64 in `PropertyValue`.
- **Owns:** `BatteryKit/{IDeviceTransport, IDeviceMonitor, MacAccessoryProvider, AccessoryMonitor}.swift`,
  `BatteryKit/MobileDevice/*`, `BatteryCore/{PropertyValue, DeviceStore}.swift`, and their tests.
- **Shares:** the one `--accessories --json` line in `ci.yml`'s smoke step (WP-8b later).
- **Gates:** G19. SEC-10 (WP-7b) is deferred.
- **Acceptance:**
  - `@unchecked Sendable` drops by 3 from WP-7's own items (`ResumeOnce`, `IDeviceListBuilder`,
    `USBDeviceWatcher`). With WP-2b's SW-06 rider and G4 both landed the total is 4; each one
    missing adds 1.
  - The CI smoke runs end with `--devices` 0 or 2, and `--accessories --json` 0.
  - The golden diff is empty.
  - The macOS job is green.
- **Effort:** M, 2 runs. **Risk:** low to medium. **Parallel with:** WP-3b.

#### WP-8b: Signing posture and pipeline hygiene (P1 and P2)

- **Goal:** a build fails when the signing posture or the release notes are wrong, and the
  workflows are hardened.
- **Items:**
  - P1, SEC-07: `build-app.sh` fails unless:
    - both bundles have the hardened runtime;
    - neither has `get-task-allow`, except in a `PROFILING` build;
    - the app has no entitlements, and the widget's entitlements equal its file's;
    - the Info.plist has no `LSFileQuarantineEnabled` and no `NSAppTransportSecurity`.
  - P1, CB-06: a heading check as the first `release.yml` step after checkout. It accepts
    `## What's new in $version` or `${version%.0}`, and prints the expected heading in its
    `::error::`. Its body reads only `VERSION` and the notes file, so D1 runs it by hand on the
    draft with `VERSION=0.6.1` before the tag.
  - P2, SEC-06:
    - `ci.yml` gets `permissions: contents: read`;
    - `persist-credentials: false` in both workflows;
    - every action pinned to a full SHA with a version comment;
    - inputs passed through `env:`.
  - P3, CB-08, in the SEC-06 commit (its canary line landed in WP-7):
    - `BUILD_NUMBER` moves into `env:`;
    - `--input` runs over the fixtures on Darwin;
    - the status variables become readable.
  - P3, CB-09:
    - `scripts` joins the lint line, with any hits fixed;
    - the `build-app.sh` comment says that only browser downloads need approval;
    - the PR template gets a lint checkbox.
  - P2, SZ-07: remove the identity-only `en` table behind a guard, keeping the empty `en.lproj`.
- **Owns:** the same files as WP-8a, run after it, plus `.github/pull_request_template.md`.
- **Gates:** none.
- **Acceptance:**
  - A deliberately flipped invariant fails the build. Show it once in a scratch commit.
  - `grep -n "uses:" .github/workflows/*.yml` shows only SHAs.
  - The heading check passes with the 0.6.1 heading and fails without it (a dry run of the step).
  - `LocalizationCatalogTests` passes; with SZ-07, `build-app.sh` checks that the bundle keeps an
    `en.lproj` and a `ru.lproj/Localizable.strings` with every catalog key (optional session step
    F9 looks at it).
- **Effort:** S–M, 2 runs. **Risk:** low. **Parallel with:** WP-9.

#### WP-9: Views (P2; a lite tier first)

- **Goal:** small view bugs fixed; then, if the budget allows, the large view files split for
  readability.
- **Lite tier** (P3 fixes, S): run first.
  - AV-06: Copy Report's tooltip uses "Connect the device to copy a report" on the intro page, and
    Accessories gets no `.help`. This is the fallback, so it needs no M5 check.
  - AV-07: the demo bar comment, without a count.
  - AV-10: `onChange(of: motion.isVisible, initial: true)` on the device pages, and optionally
    `RefreshWhenShown`.
  - CH-03 with CH-02's notifications hunk: the `.task` moves from the notifications Section onto
    the always-present "When charged to" Picker, and `isDenied` refreshes on `didBecomeActive`
    next to it.
  - CH-04: drop the two redundant `WindowOpener` assignments.
  - CH-06: log Clear History's error in the `history` category.
  - CH-07: the widget placeholder draws a sample snapshot.
- **Full tier** (P2, M):
  - SUI-13, the Settings and Components split: one file per Settings pane, and
    `Main/Components/*`;
  - CH-02's other two hunks: the modifiers move onto the Open-at-login VStack and the Clear
    History… button;
  - CH-11: `SettingsPage` becomes internal, and WelcomeView reuses it;
  - AV-14: `FrostLayer` becomes private next to `Card`, and the accessory helpers go to
    `Main/Components/`;
  - AV-04 parts 2 and 3: `Phrases.condition(for:)` and `Phrases.deviceListFailed`;
  - SUI-15: review the lists against UI-7 and fix only violations;
  - the `MotionGuardTests` file lists and CLAUDE.md follow the new file names.
- **Owns:**
  - `Settings/*`;
  - `Main/{Components, OverviewView, PowerView, HealthView, CompactView, AccessoriesView, DeviceView, DevicesIntroView, DemoView}.swift`,
    and the `.help` in `MainView`;
  - `MenuBar/{PopoverView, PopoverAccessories}.swift` and `Welcome/WelcomeView.swift`;
  - the widget's placeholder;
  - the file lists in `MotionGuardTests`.
- **Shares:** `App/Localized.swift`, only the two `Phrases` helpers of AV-04 parts 2–3 (after
  WP-5).
- **Gates:** none. SUI-07, SUI-17 and SUI-18 are deferred.
- **Acceptance:**
  - `MotionGuardTests` and `LocalizationCatalogTests` pass, with no new strings.
  - The macOS job is green, and session step F6 passes.
- **Effort:** lite S, 2 runs; full M, +1 run. **Risk:** low. **Parallel with:** WP-8b.

#### WP-2c: Energy policies (P2)

- **Goal:** polling backs off when the system asks for it, and stops while no screen is on.
- **Items:**
  - E6:
    - `LiveRefreshPolicy.interval(base:reducesResources:thermal:)` in BatteryCore, with Linux
      tests;
    - under Low Power Mode, reduced resources, or a serious or worse thermal state, the window
      interval goes 2 → 5 s and the menu bar interval 10 → 30 s;
    - Low Power Mode and the thermal state come from `ProcessInfo`;
    - `MenuBarLabel` reads `systemPrefersReducedResourceUsage`;
    - only the next interval changes.
  - E5: on screen sleep or session resign, the `menuBar` request is withdrawn; on return, one
    refresh. The notifications come through `NSWorkspace.shared.notificationCenter`.
- **Owns:** the new `BatteryCore/LiveRefreshPolicy.swift` and its tests, `MenuBarLabel`, and the
  live-refresh plumbing in `App/Motion.swift`.
- **Gates:** none; the Linux tests decide.
- **Acceptance:**
  - The policy tests pass.
  - Demo Mode still simulates Low Power Mode and the thermal state without changing the real poll.
  - The USER_GUIDE line is added (by WP-12).
- **Effort:** S–M, 2 runs.
- **Risk:** low. Live values get coarser under Low Power Mode, by design; this is user-visible.

### 3.4 Phase C: lock-in

#### WP-11: Less code (P1)

- **Goal:** remove what no product uses, proven by link maps, plus the small cleanups the audits
  kept.
- **Items:**
  1. SW-17 with V-05: dead code found by link maps.
     - Build debug (`-Onone`) `-dead_strip` link maps of `BatteryPulse`, `BatteryPulseWidget` and
       `bpulse`, each with `_main` as the only export. They come from a temporary macOS CI step on
       the package's branch, removed before merge.
     - Intersect the three maps.
     - Cross-check each candidate with `git grep -w` over all of `Sources` and `Tests`, Darwin
       blocks included (DC-1…DC-6). The Linux container indexes no `#if os(macOS)` code, so a
       Linux sourcekit-lsp or IndexStoreDB "no references" proves nothing.
     - The first run appends the candidate file list to Appendix C before any deletion. WP-12
       rebases over it, and the review rejects any WP-11 file outside that list and the riders'.
     - Make one deletion commit per area, each saying why the code is unused.
  2. Riders, each in its own commit:
     - CORE-05 and CORE-07: drop the unused `Codable` from `IDeviceInfo`, `IDeviceIdentity`,
       `MenuBarItem`, `MenuBarIconStyle` and `BatteryAlert`.
     - CORE-06: delete the dead members, pointing their tests at what the app uses. The members
       are `RawKeyGlossary.keys`; `RawEntry.id`, `.value` and `Identifiable`; `wearPercent`;
       `isDrawn`; `samples(since:)`; and `allowsTertiaryText` and `dividesGroupsWithHairlines`,
       which can go now that WP-UR has merged. `hasHue` moves into the test target.
     - CORE-09, CORE-15 and CORE-08's comments, as one `BatteryReport` commit. The golden text
       stays identical.
     - CORE-17 with SW-19: one `fixtureDictionary(_:)`, `#require`, and parameterized fixtures
       where they remove code.
     - AC-02: remove the 7 redundant guards on `@Observable` storage, and reword the doc comment of
       `AccessoryMonitor`.
     - AC-03 (moved from WP-10): one `status` value for `LaunchAtLogin`.
     - AC-07:
       - rewrap `WindowLook.swift:10–15`;
       - settle `UTTagClass(rawValue:)` on the macOS job (G6);
       - leave `migrate()` unchanged (G7).
     - CH-05: `MenuBarIconPreview`'s unused parameters.
     - CH-09: one `DynamicProperty` for the menu bar choices, with defaults from
       `MenuBarContent.default` and `MenuBarIconStyle.default`, and a Linux test that those are
       icon + percentage (what the app shows after `defaults delete`).
  3. SZ-06: attribute the remaining size from WP-8a's release maps.
  4. K-03, G13: record in Appendix C the widget's `__text` share of the types a lower target would
     remove, and whether `-why_live` shows `HMACDeviceKeyDeriver` keeping CryptoKit.
  5. P2, SW-15: one `PerformanceHints` pass over the hot paths, as a report.
- **Owns:** the files on its Appendix C list, and the rider files.
- **Shares:** `Motion.swift` with WP-12 (different hunks).
- **Gates:** DC-1; G6; G7; G13 (measured here).
- **Acceptance:**
  - Lines per target go down.
  - All tests pass; deleted tests belong only to deleted test-only members, and their assertions
    move to what the app uses.
  - The golden diff is empty.
  - The macOS job is green, and every commit states DC-6.
- **Effort:** M–L, 3 runs. **Risk:** medium; code reached only through the runtime is at risk
  (DC-4). **Parallel with:** WP-12.

**WP-11b (P3, only if G13 passes and the budget allows; else 0.6.2):** K-03 as the verified audit
modifies it: a lower `BatterySource` target (`BatteryProvider`/`BatteryObservation`,
`MacBatteryProvider`, `SMCClient`, `SystemNotifications`, `IOSBatteryProvider`) that the widget
depends on alone, with BatteryKit on top under its name; about 6 files gain the import; no
`@_exported`. Owns `Package.swift` and those imports. S–M, 2 runs, after WP-11 and before D1.

#### WP-12: Guards and docs (P1)

- **Goal:** the new rules are enforced by tests and written down.
- **Conditional on what landed:** each rule or CLAUDE.md line that depends on one package item is
  its own commit naming that item, so a D3 revert of the item takes its rule along. If §6 cut WP-4
  or WP-6b, WP-12 takes their E7 hunks (one argument each: `DemoController.swift:212`;
  `UpdateChecker.swift:70, 73` and `UpdateInstaller.swift:203`), so EN-1 needs no new allowlist
  entry, and the `Observations` line is written only if WP-4 landed.
- **Items:**
  - `SecurityGuardTests` (SEC-R7), on top of `SourceScanner`. If SEC-03 landed, it also checks
    that `URLSession.shared` appears nowhere.
  - `EnergyGuardTests` (C4):
    - EN-1: sleep tolerances. The allowlist holds exactly the four one-shots: `MainView`'s 1.5 s
      "Copied", `WidgetRefresher`'s 1 s wait and the two `bpulse` loops;
    - EN-2: timers;
    - EN-8: `beginActivity` only in `UpdateInstaller`;
    - EN-11: `reloadAllTimelines` only in `WidgetRefresher`.
  - CH-01:
    - the welcome icon's 0.8 s draw-in becomes a `Motion.swift` preset gated on `allowsFlourish`;
    - a guard rule flags `\bAnimation\.` outside `Motion.swift`, excludes `motion.linear(`, and pins
      both cases as allowed.
  - AV-08's rule, "no `Material` in `Main/`", if AV-08 stays.
  - CLAUDE.md Conventions, one line each:
    - sleep tolerances;
    - `Observations` with `.dropFirst()` (if WP-4 landed);
    - the logging categories (including `perf`) and their privacy;
    - `@concurrent` offloading;
    - what the environment may carry (UI-6, SUI-21);
    - the signpost names;
    - the guard tests;
    - `scripts` in the lint command (CB-09).
  - USER_GUIDE:
    - the update-integrity warning, replacing "the window offers Download instead" for integrity
      failures (SEC-01);
    - the Low Power Mode line, if WP-2c landed;
    - the privacy paragraph, checked again (SEC-16).
  - ROADMAP:
    - the 0.6.1 stage and its lasting decisions;
    - CB-02's 0.7 entry: device JSON dates become ISO 8601, with a release-notes line;
    - the 0.6.2 backlog (§6);
    - the 0.6.0 checks the session doesn't cover.
- **Owns:** the two new guard suites, the new rule in `MotionGuardTests`, the preset in
  `App/Motion.swift`, `Welcome/AppIconView.swift`, CLAUDE.md, USER_GUIDE and ROADMAP (except the
  numbers); under §6's step 4 only, the cut packages' E7 hunks.
- **Gates:** none.
- **Acceptance:**
  - Each new suite catches a violation injected into a scratch copy.
  - The lint and `LocalizationCatalogTests` pass.
  - The docs are checked against §3.4.
- **Effort:** M, 2 runs. **Risk:** low. **Parallel with:** WP-11; WP-12 merges last.

### 3.5 Phase D: measure, M5, release

- **D1: Measure and freeze the release candidate.** One run, in one container.
  1. Run §4a.
  2. Run every check in §5.
  3. Set the size ceilings at the RC plus about 5 %, in a commit of its own that says why.
  4. Draft `.github/release-notes.md` (§7), with the M5 numbers marked TBD.
  5. Open a **draft** PR to `main` through the REST API or the GitHub MCP tool, with §4b as its
     checklist.
  6. Dispatch `ci.yml` on the RC with `version=0.5.99` (`gh api -X POST
     repos/NikitaUsov/BatteryPulse/actions/workflows/ci.yml/dispatches -f ref=claude/nice-faraday-k08mhb
     -f inputs[version]=0.5.99`). Its DMG is the session's B; the baseline's stays 0.0.0 (A).
     Rebase `claude/061-ur-clearfill` onto the RC and push it, so its DMG is the RC plus the fill.
  7. Finalise `m5-session.sh` with the PR number and the run IDs of A, B and the CH-13 fill
     branch, so no command needs a placeholder; check it with `bash -n`.
  8. Run CB-06's heading check by hand with `VERSION=0.6.1` against the draft notes.
  9. CI must be green. From here, the integration branch takes only D3's changes.
- **D2: The M5 session.** The maintainer runs §4b.
- **D3: Release.** 1–2 runs.
  1. Apply the session's answers, or the §3.6 defaults if none come. That means reverts of item
     commits (with their WP-12 rule commits), a dropped flag, or merging the CH-13 fill branch;
     nothing else.
  2. Add the M5 numbers to ROADMAP and the notes.
  3. Remove `docs/plans/0.6.1`.
  4. Then follow §7.

### 3.6 Gates and their default decisions

| Gate | Decides | Measured by | If no measurement comes |
|---|---|---|---|
| G1 SUI-05R/E13 decode cache | WP-3a | B2 cold 7 d > 50 ms on Linux (Linux) | Ship (83–91 ms measured) |
| G2 SZ-05 `-Osize` | WP-8a | B1 and B2 with and without `-Xswiftc -Osize` (Linux) | Adopt, unless a median regresses > 25 % |
| G3 SZ-02 on the widget | WP-8a / D3 | Session F8: the widget renders | No session, or a broken widget: D3 drops the widget's export flag; the app keeps its own |
| G4 SW-06 `DownloadWatcher` | WP-6b | macOS job compiles it as checked `Sendable` | Stays `@unchecked` with a comment; the target becomes 5 |
| G5 V-04 | WP-4 | macOS job builds without `@preconcurrency` | Keep the import |
| G6 AC-07 `UTTagClass` | WP-11 | macOS job | Reword the comment only |
| G7 AC-07 `migrate()` guard | — | `fs_usage` on cfprefsd (M5) | No change; not measured in 0.6.1 |
| G8 CH-08 hidden status item | WP-2a | — | The member count; correct in both cases |
| G9 AV-06 empty tooltip | WP-9 | — | The fallback strings |
| G10 CH-12 look | D3 | Session V1: accent outline, no glass; one point of the Clear tile reads the same selected and unselected; disabled tiles dimmed; sign-off | Ship the outline. If the maintainer wants glass, it returns in 0.6.2 with the pixel test |
| G11 CH-13 look and readability | D3 | Session V2: Digital Color Meter ≈ 94/255 in a gap, Light and Dark; sign-off | Ship 0.65. A reading > ~104 in either appearance: D3 merges `claude/061-ur-clearfill`, and the maintainer repeats V2 on its DMG before approving (`bash docs/plans/0.6.1/m5-session.sh v2-fill`, 5 min); without that repeat the fill ships, because a plain fill's contrast is the computed one. Clearly darker in Dark keeps 0.65. If rejected, revert to `6584585`'s 40/32 and drop the test |
| G12 AV-08 look | D3 | Session V4: 4 styles × Light/Dark, legible on Clear over a bright desktop; approval | The verified audit makes approval its acceptance. Not run or rejected: revert the AV-08 commit and WP-12's `Material` rule commit |
| G13 K-03 lower target | WP-11b | Widget map share ≥ 100 KB, or `-why_live` shows `HMACDeviceKeyDeriver` keeping CryptoKit and the maintainer wants it out (Q6); WP-11 records both | Gate fails or no budget: no split; 0.6.2 |
| G14 E4b registry only on change | 0.6.2 | M5 `read` split after E4a | Deferred |
| G15 E3b fewer notify keys | 0.6.2 | `pmset -g pslog` for 3 h on the M5 | Deferred; both keys kept |
| G16 E20 reads off the main actor | 0.6.2 | `read` p95 > 4 ms (M5) | Deferred |
| G17 SUI-07, SUI-11, SUI-12, E19 | 0.6.2 | SwiftUI instrument (M5, profiling build) | Deferred |
| G18 SEC-15 `-noverify` | 0.6.2 | Attach timing with ULMO (M5) | Deferred |
| G19 SEC-10 MobileDevice helper | 0.6.2 | Maintainer's evidence of a hang or crash (Q1) | Deferred |
| G20 SEC-08 Enhanced Security | 0.6.2 | An in-app update 0.6.0 → candidate launches, possible only after publishing | Deferred |
| G21 SZ-10, SZ-11, SZ-14 | 0.6.2 | Icon Composer on the Mac; CI experiments | Deferred |
| G22 the candidate's installer | D3 | Session F12: the 0.5.99 build's Install and Relaunch installs 0.6.0, which relaunches | Fails or doesn't run: D3 reverts WP-6b's installer commits (SW-05 on `verify`/`replace`, the shield, SEC-03, E11, the `Mutex` `DownloadWatcher`) with their WP-12 rules. They are hygiene with no user-visible gain, so 0.6.0's proven installer code ships |

**Session steps without a gate of their own** (§4b):

| Step | Checks | If it fails | If it doesn't run |
|---|---|---|---|
| F6 pages | WP-2b, WP-3b, WP-5, WP-9 on real data | D3 reverts the commits behind the broken page | Ship on the tests (and the CI launch smoke, if it runs) |
| F11 relaunch, alerts, login item | WP-4 (SW-09), WP-2a (CH-08), WP-11 (AC-03) | D3 reverts the failing item's commit | Ship if the CI launch smoke runs; otherwise revert WP-4's four SW-09 commits |
| F12, the window part | WP-6a (SEC-02, AC-01), SEC-03's `Cache.db` | D3 reverts that item's commit | Ship on the Linux tests |
| Optional: F5, F9, burst, memory, energy | `a32bfae`, SZ-07, E3 and `994c09d`, E18, energy | Reported; D3 reverts the item named | "Not measured"; the Linux and CI checks stand |

**Release gate (D3):**
- both CI jobs green with 0 warnings;
- the golden, storage and settings diffs clean (§5);
- the size rows recorded;
- the notes heading check passing;
- the session's answers, or the defaults above (gates and steps), applied;
- the maintainer's approval.

### 3.7 Effort summary

| Package | Prio | Size | Runs | Package | Prio | Size | Runs |
|---|---|---|---|---|---|---|---|
| WP-0a | P1 | M | 2 | WP-6b | P1 (cuttable) | M | 2 |
| WP-0b (+A1′) | P1 | M | 2 | WP-3a | P1 | M | 2 |
| WP-1 | P1 | M | 2–3 | WP-3b | P1 | M–L | 2–3 |
| WP-UR | P1 | S | 2–3 | WP-7 | P1 (cuttable) | M | 2 |
| WP-8a | P1 | M | 2–3 | WP-8b | P1/P2 | S–M | 2 |
| WP-2a | P1 | M | 2 | WP-11 | P1 | M–L | 3 |
| WP-6a | P1 | M | 2 | WP-12 | P1 | M | 2 |
| WP-2b | P1 | M | 2 | D1 + D3 | P1 | — | 2–3 |
| WP-5 | P1 | M–L | 2–3 | WP-9 (lite, full) | P2 | S, M | 2, +1 |
| WP-4 | P1 (cuttable) | M | 2 | WP-2c | P2 | S–M | 2 |
| Fix-forward reserve | — | — | 3 | WP-11b (gated) | P3 | S–M | 2 |

Totals: P1 about 37–43 runs plus the reserve of 3, so 40–46; through B2, 16–19. The never-cut set
(§6) is about 31–37 plus the reserve. P2 about 4–5 runs. WP-10, deferred, would be about 3.

## 4. Measurements

### 4a. Automatic, on CI and Linux

**On every macOS CI run after WP-0b:**
- the size report (summary and `size.json`);
- the warning gate;
- the `bpulse` smoke runs;
- the signing smoke;
- after WP-8a, the install-path step and the link maps.

"Before" is the `claude/baseline-0.6.0` run. The official before figure is the published v0.6.0
DMG, 3,670,713 bytes:

```
gh api repos/NikitaUsov/BatteryPulse/releases/tags/v0.6.0 --jq '.assets[] | "\(.name) \(.size)"'
```

**In D1, on Linux, in one container** (`$SP` is the session's scratchpad):

```
R=/home/user/BatteryPulse
git -C $R fetch origin
for w in base:origin/claude/baseline-0.6.0 ref:c9ea33c shipped:6133b4f rc:origin/claude/nice-faraday-k08mhb; do
  git -C $R worktree add --detach $SP/${w%%:*} ${w#*:}; done
# Benches, alternating A/B three times; report the median of the three medians
for i in 1 2 3; do for w in base rc; do
  (cd $SP/$w && BP_BENCH=1 swift test -c release -j 2 --filter Benchmarks) > $SP/bench-$w-$i.txt 2>&1; done; done
# Code metrics at 6133b4f and the RC
for rev in 6133b4f origin/claude/nice-faraday-k08mhb; do
  for t in BatteryCore BatteryKit BatteryPulseApp BatteryPulseWidget bpulse; do
    echo "$rev $t $(git -C $R ls-tree -r --name-only $rev Sources/$t | grep '\.swift$' | sed "s|^|$rev:|" | xargs git -C $R show | wc -l)"; done
  for p in '@unchecked Sendable' withObservationTracking Task.detached URLSession.shared 'try?'; do
    echo "$rev $p $(git -C $R grep -F "$p" $rev -- Sources | wc -l)"; done
  echo "$rev @MainActor-app $(git -C $R grep -F '@MainActor' $rev -- Sources/BatteryPulseApp | wc -l)"; done
```

The test count is the "Test run with N tests" line of `swift test` in the RC worktree. Warnings come
from the CI gate, and must be 0. The swift-format findings come from
`swift format lint --strict -r Sources Tests Package.swift scripts`.

Anchors at `c9ea33c`:

| Metric | Value |
|---|---|
| Lines: BatteryCore | 9,363 |
| Lines: BatteryKit | 2,731 |
| Lines: app | 8,556 |
| Lines: widget | 207 |
| Lines: bpulse | 483 |
| Lines: tests | 9,789 |
| `@Test` | 542 |
| `withObservationTracking` | 4 |
| `@unchecked Sendable` | 9 |
| `Task.detached` | 4 |
| `URLSession.shared` | 3 |
| `try?` | 67 |
| `@MainActor` in the app | 38 |
| `Task.sleep` without a tolerance | 10: 6 E7 sites (WP-2a, 3b, 4, 6b) and 4 allowlisted one-shots (`MainView` 1.5 s, `WidgetRefresher` 1 s, 2 in `bpulse`) |

### 4b. The M5 session (one sitting on the release candidate, after D1)

**What it takes:** a core of about 30 minutes hands-on (steps 1–7) that decides every gate, then
optional extras of about 15 minutes hands-on and 15 minutes unattended. Every command runs from
`~/BatteryPulse` as `bash docs/plans/0.6.1/m5-session.sh <step>`. D1 bakes the PR number and the
CI run IDs into the script, so no command has a placeholder. A session cut short still leaves
every gate decided, by an answer or by its §3.6 default. The session doesn't touch the installed 0.6.0 for good: `prepare`
backs up the app, settings and data; F12 installs 0.6.0 back with the candidate's own installer;
each block ends by restoring the settings.

Builds: A is the baseline (0.0.0); B is the RC built as 0.5.99 by D1, so that B's Install and
Relaunch accepts the real 0.6.0.

**Before you start (1 min):** the Mac at 60–80 % charge and unplugged; brightness at 50 %, with
auto-brightness and True Tone off; Wi-Fi on and Low Power Mode off; other apps quit; `gh` signed
in; Digital Color Meter open with "Display native values".

**Core (about 30 min):**

1. **Prepare** (2 min):

   ```
   cd ~/BatteryPulse && git fetch origin && git switch --detach origin/claude/nice-faraday-k08mhb
   bash docs/plans/0.6.1/m5-session.sh prepare
   ```

   The script:
   - quits BatteryPulse;
   - downloads A and B from CI with `gh run download` into `~/bp-061/{A,B}`;
   - backs up `defaults export io.github.nikitausov.BatteryPulse`, the Application Support folder
     and `/Applications/BatteryPulse.app`, and moves the app's caches folder aside, so SEC-03's
     check starts clean;
   - installs B into `/Applications`;
   - sets `updateFrequency never` and the menu bar to icon and charge;
   - records `sw_vers`, the cycle count, `sysctl kern.pervasive_energy` and the charge;
   - starts `log stream --level debug --style ndjson --predicate 'subsystem == "io.github.nikitausov.BatteryPulse" AND category == "perf"'`
     in the background;
   - opens B.

   Each later prompt takes y or n and an optional note; typing `light` or `dark` switches the
   appearance. Screenshots: ⇧⌘4, then Space; they go to `~/bp-061/shots/`.
2. **V1, tile pickers** (3 min): `bash docs/plans/0.6.1/m5-session.sh v1`. Settings → General → Window Style, and Menu
   Bar → Icon Style, in Light and Dark: the selected tile has an accent outline and no glass; one
   point of the Clear tile's sky reads the same in Digital Color Meter unselected and selected; the
   disabled Icon Style tiles are dimmed. Glance at the menu bar icon next to the system battery
   item in both appearances (0.6.0 open check). Sign off (G10).
3. **V2, Clear** (4 min): `bash docs/plans/0.6.1/m5-session.sh v2`. Window Style Clear, the main window over a blank white
   TextEdit page, Light then Dark. Read a gap between groups and type both values (expected ≈ 94).
   Is the text readable? Then look once over a busy part of the desktop. Sign off (G11).
4. **V4, the chart readout and minimizing** (6 min): `bash docs/plans/0.6.1/m5-session.sh v4`. In
   each style, minimize and restore the main window with Shift held (the slow genie animation):
   no black frame (UR-3). History 24 h with the pointer over a
   chart: one screenshot per style (Standard, Frosted, Translucent, Clear) in Light and in Dark. Is
   the readout readable, above all on Clear? Are Frosted's and Translucent's sidebar and toolbar
   acceptable (0.6.0 open check)? Approve (G12).
5. **F8, widget** (2 min): `bash docs/plans/0.6.1/m5-session.sh f8`. Add the BatteryPulse widget to the desktop; it shows
   the charge. The script checks that `pluginkit -mv -i io.github.nikitausov.BatteryPulse.Widget`
   shows the `/Applications` path (G3).
6. **F6 and F11, functions** (8 min): `bash docs/plans/0.6.1/m5-session.sh f11`.
   - **F6:** every page: Overview, Power, History (24 h and 7 d, with the last days' 0.6.0 data),
     Health, Raw Data (type "volt", clear it, open the inspector), and Demo Mode (play 20 s: the
     menu bar icon follows, and no notification arrives).
   - **F11:**
     - the script turns the power value on in the menu bar, quits B, counts the lines of today's
       `History/samples/<UTC date>.jsonl`, relaunches B, waits 30 s and counts again: exactly one
       new line, the launch sample;
     - meanwhile, with every window closed, the power value keeps changing (CH-08);
     - your settings are all there, and the icon style is unchanged;
     - with the Settings window frontmost, set "When charged to" below the current charge and plug
       in: a notification arrives within about 10 s; click it, and BatteryPulse comes forward;
     - turn on Open at login, approve it in System Settings if asked, check that the script's
       `sfltool dumpbtm` line lists it, then turn it off (AC-03).
7. **F12, update window and installer** (5 min): `bash docs/plans/0.6.1/m5-session.sh f12`. Choose Check for Updates.
   - The window offers 0.6.0, the notes render, and a link opens in the browser. The script checks
     that no `Cache.db` appeared in the app's caches folder or `~/Library/HTTPStorages` (SEC-03).
   - Select a sentence in the notes, then choose **Install and Relaunch**. The selection survives
     the download (AC-01); the installer verifies and installs the real 0.6.0 over B, which
     relaunches. Its What's New window opens because B recorded 0.5.99; close it.
   - The script checks that `/Applications` holds 0.6.0, restores your settings (keeping the History
     written meanwhile: same format, genuine samples) and writes `~/bp-061/results.md` (G22).

   Then `bash docs/plans/0.6.1/m5-session.sh send` posts `results.md` as a comment on the D1 PR; drag `~/bp-061/shots/` into
   that comment.

**Optional extras.** Each reinstalls B, runs, and ends by putting 0.6.0 and your settings back;
`bash docs/plans/0.6.1/m5-session.sh send` afterwards posts the new results.
- **F5** (2 min, if an iPhone, iPad or AirPods are at hand): `bash docs/plans/0.6.1/m5-session.sh f5`. An iPhone page and
  Accessories show values, and the earbuds are named after the buds.
- **F9** (2 min): `bash docs/plans/0.6.1/m5-session.sh f9` relaunches in Russian; glance at Overview and Settings; it
  switches back to English.
- **Burst** (5 min): `bash docs/plans/0.6.1/m5-session.sh burst`. 3 unplug and plug cycles per build, 30 s apart; the script
  switches between A and B and prints the reads per notify burst and the widget reloads per change.
- **Memory** (4 min): `bash docs/plans/0.6.1/m5-session.sh memory`. Per build, open the main window, choose History → 7 d
  and close it, three times; the script prints `phys_footprint` before and after, and
  `history.load` cold and warm.
- **Energy** (about 15 min unattended; unplug first, then leave the Mac): `bash docs/plans/0.6.1/m5-session.sh energy`. S2
  (power in the menu bar, no window) as A then B, each 1 minute to settle plus 4 minutes of
  `rusage.swift`; then S7, 5 cold launches per build from `open` to the `menuBarReady` line, with
  the reads before it counted. `caffeinate -d` keeps the display on.

Shorter windows than the playbook's 30 minutes, and one A/B pair instead of three, mean the
per-hour figures are extrapolated and noisier. A difference under 15 % counts as noise.

**After publishing** (part of the release approval, 5 min), on the M5 running 0.6.0:
1. Check for Updates → **Install and Relaunch**.
2. Then check that:
   - About shows 0.6.1;
   - History shows the past days;
   - the settings and the menu bar look are unchanged;
   - the widget shows a current value;
   - `codesign -dv --verbose=4 /Applications/BatteryPulse.app 2>&1 | grep flags` shows
     `flags=0x10002(adhoc,runtime)`;
   - `xattr -l /Applications/BatteryPulse.app` shows no quarantine;
   - `sfltool dumpbtm | grep -i -A3 batterypulse` still lists the login item, if it was on;
   - notification permission is kept.
3. On any failure, run `gh release edit v0.6.1 --prerelease`, which makes `releases/latest` serve
   0.6.0 again, and report it.
4. In everyday use during the first day (no session time): after half an hour on battery, the
   widget's charge is within 2 points of the popover's and its "Lasts until" within about 15
   minutes of the popover's estimate (`994c09d`). If not, send a screenshot with both.

This is the only M5 step outside the session. It can't run earlier, because the app fetches only
`releases/latest`. The CI install-path step and F12 cover its risky parts beforehand.

### 4c. Numbers 0.6.1 reports (before → after)

**ROADMAP: "Performance baseline (0.6.0 → 0.6.1)".**

| Table | Rows | Source | If no session |
|---|---|---|---|
| Size | DMG bytes and format; `.app` KB; app and widget binary bytes and `__text`; exports per binary; `.strings` bytes; build-machine strings (must be 0) | CI | — (always) |
| Linux benches | B1–B6 medians | D1 | — (always) |
| Code | Lines per target; warnings; tests; the counts in §4a; swift-format findings | D1 | — (always) |
| Energy | S2: mJ/h, idle wake-ups/h, CPU s/h, reads/min. S7: `menuBarReady` p50 and reads before it. S8: reads per burst, widget reloads per change. Idle `phys_footprint` and growth over the cycles | Session (optional extras) | "not measured; 0.6.2 session" |
| Read path and responsiveness | `read` p50/p95 split into `registry`, `smc.*` and `parse`; `history.load` 7 d cold and warm | Session (core and extras) | "not measured" |

**Release notes:** one short paragraph:
- download size, X.X MB → Y.Y MB (−Z %), and the installed app size;
- one battery read per plug change instead of two;
- if measured, the CPU and energy per hour with the power value in the menu bar, and the idle
  wake-ups.

## 5. Proof of no lost functionality

| Check | What it compares | When and who | Pass |
|---|---|---|---|
| Tests | Every existing test, Linux and macOS. A test pinning an internal API a package changed is rewritten in the same commit with its assertion kept | Every push; CI and the review agent | Green; count ≥ 542 plus the new tests |
| Frozen-surface review | Playbook §3.4, item by item, against the package diff | Each review run | Nothing touched |
| `bpulse` golden diff | See the forms below | D1, Linux | `diff -r ref rc` empty. `diff -r shipped rc` differs at most in accessory names, from `a32bfae` |
| `bpulse` on Darwin | `--smc`, `--devices`, `--record`, `--accessories --json`, `--input` | Every macOS run | Status 0 or 2 as today; `--accessories --json` 0 |
| Storage round trip | A scratch package depends on BatteryCore from `ref` and from `rc`. Its writer writes 3 days across UTC midnight with fixed dates and time zone, plus `days.jsonl`, `Devices/devices.json` and the per-device history, with `Devices/key` copied from `ref`. Its reader dumps every store as sorted JSON | D1, Linux | The files written by `ref` and `rc` are byte-identical; `rc` reads `ref`'s files exactly as `ref` does, and the reverse |
| Settings and identifiers | The command below over `Sources scripts .github` at `6133b4f` and the RC; also the asset names in `release.yml`, the Info.plist keys in `build-app.sh`, and the log subsystem | D1, Linux | It prints 36 at `6133b4f` (an empty result fails the check) and the `diff` is empty; elsewhere only the new log categories are new |
| Update contract | The CI install-path step (0.6.0's steps on the candidate DMG); the signing smoke; the SEC-05 test that today's key is in the list; asset names | Every macOS run; D1 | Pass |
| The candidate's installer | F12: the 0.5.99 build of the RC installs the real 0.6.0 | Session, maintainer | 0.6.0 relaunches; otherwise G22 |
| Behaviour on real data | Session steps F6, F8 and F11 (and F5, F9 if run), on the maintainer's own 0.6.0 settings and History | Session, maintainer | All yes; otherwise §3.6's step defaults |
| The real update | 0.6.0 → 0.6.1 in-app (§4b, after publishing) | Maintainer, 5 min | All yes; otherwise the prerelease rollback |

The settings and identifiers command (`$R` as in §4a):

```
for rev in 6133b4f origin/claude/nice-faraday-k08mhb; do
  git -C $R grep -h -o -E 'Key = "[A-Za-z]+"|@(AppStorage|SceneStorage)\("[^"]+"|"io\.github\.nikitausov\.BatteryPulse[^"]*"|kind: "[^"]+"' $rev -- Sources scripts .github | sort -u > $SP/ids-${rev##*/}.txt
  wc -l < $SP/ids-${rev##*/}.txt; done
diff $SP/ids-6133b4f.txt $SP/ids-nice-faraday-k08mhb.txt
```

**The golden diff's forms.** Build `bpulse` (release) in `shipped`, `ref` and `rc`, and run each
with `TZ=UTC LC_ALL=en_US.UTF-8`:
- every fixture with `--input F`, `--input F --json` and `--input F --raw`;
- `--help`;
- `--export csv`, `--export json` and `--export csv --days --decimal-comma` against the storage
  writer's `--history` folder;
- about 10 usage-error vectors: `--record x --json`, `--devices --watch`, `--smc --input F`,
  `--export xml`, `--bogus`, and similar.

Compare stdout and the exit status of every run.

## 6. Cut line

**P1, must ship** (playbook P1 plus the verified P1 items; WP-4, WP-6b and WP-7 unless the
checkpoint below cuts them):
- WP-0a, WP-0b, WP-1 and WP-UR;
- WP-8a, WP-2a, WP-6a, WP-2b, WP-5, WP-4, WP-6b, WP-3a, WP-3b, WP-7, and WP-8b's P1 items;
- WP-11 and WP-12;
- D1–D3.

P2 and P3 riders inside these packages ship with them unless the package runs long. Each package
names its drop order, and a dropped rider moves to 0.6.2.

**P2, if the budget allows:** WP-9 (lite tier first), then WP-2c. WP-11b (P3) only under G13.

**Budget checkpoint, after B2 merges and before B3 starts.** The orchestrator compares the runs
used with the plan (16–19 through B2) and the maintainer's budget (Q5; default 40):
- remaining = budget − runs used;
- remaining covers the rest of P1 at the high end (24) plus the reserve (3): go on. P2 packages
  start only if what remains after Phase B also covers them;
- otherwise cut now, before any cuttable package runs, in this order and only as far as needed:
  1. the P2 and P3 riders of the packages still to run (each package's drop order);
  2. WP-6b (2 runs; hygiene with no user-visible gain, and its installer is the riskiest change);
  3. WP-7 (2 runs);
  4. WP-4 (2 runs).

  A cut package moves to 0.6.2 whole. WP-12 then takes its E7 hunks and leaves out its rules and
  CLAUDE.md lines (WP-12's conditional rule); its targets (`@unchecked Sendable`, `Task.detached`,
  `withObservationTracking`) are reported as they stand.
- If even the never-cut set doesn't fit (about 15–18 runs after B2, plus the reserve), stop and
  ask the maintainer; don't start a package that can't finish.

P1 alone costs 37–43 runs plus the reserve, 40–46. If only the never-cut set fits (31–37 plus the
reserve), 0.6.1 still ships the measurement tools, the two look fixes, the Swift 6.4 manifest, the
smaller DMG, the update-integrity and release fixes, one read per burst with two-key SMC polls,
History and Raw Data off the main actor, the dead-code removal and the guard tests; the
`Observations`, `Mutex` and installer `@concurrent` work moves to 0.6.2.

Never cut WP-0a/0b, WP-UR, WP-1, WP-8a, WP-8b's P1 items, WP-6a, WP-2a/2b, WP-3a/3b, WP-5,
WP-11's map-driven deletions, WP-12 or D1–D3.

**Deferred to 0.6.2:**

| Item | Reason |
|---|---|
| SW-04 with V-01 (WP-10) | V-01 needs a long M5 session (notifications, sleep and wake, an install from a test release, the widget after an update). Its failure mode is a runtime trap, and the gain is readability. It becomes 0.6.2's first package |
| SEC-10 (WP-7b) | Gate: no recorded MobileDevice hang or crash (Q1) |
| SEC-08 | Its hard gate (an in-app update 0.6.0 → candidate launches) is possible only after publishing |
| E4b, E3b, E20 | Their gates are M5 measurements that come after the packages run |
| SUI-07, SUI-11, SUI-12, E19 | They need the SwiftUI instrument on the M5 |
| SUI-17, SUI-18, SUI-19 | They need Xcode on the Mac, or are P3 |
| SUI-09 | P3, readability only |
| SZ-08 | P3; only together with other glossary work |
| SZ-10 | Icon Composer on the Mac plus a look check; size-neutral |
| SZ-11, SZ-14 | P3 experiments |
| K-03 | Unless G13 passes and the budget allows WP-11b |
| E10 | P3; needs Check Now to cancel a waiting check |
| SEC-15 | M5 timing gate |
| SEC-18 | Research after 0.6.1 |
| SW-21 | No consumer of the DocC output in 0.6.1; SW-20's `ValidateDocumentationComments` covers comment correctness |
| SW-13 for BatteryKit | Research P2, "later" |
| C2 | P3, try-once |
| S4w and the remaining 0.6.0 open checks (Charge Limit capture, full screen, contrast audit) | Not in the 30-minute session; they stay open in ROADMAP |
| CB-02's ISO 8601 device dates | 0.7, because `--device --json` stdout is frozen; WP-12 writes the ROADMAP entry |
| Glass in the tile picker | Only if the session asks for it (G10), with the pixel test |
| `package` access, `AllPublicDeclarationsHaveDocumentation`, `BeginDocumentationCommentWithOneLineSummary` | Not in 0.6.1 by decision (SW-R17) |

**Rejected:** do not resurrect them. Appendix B lists them by ID.

## 7. Release steps (D3)

1. **Version.** No source change. The tag `v0.6.1` sets `VERSION` (release.yml "Resolve
   version"), and the run number sets `BUILD_NUMBER`.

   `WhatsNew.version` stays `0.6.0`. 0.6.1 is a fix release, so by `UpdatePolicy.showsWhatsNew`
   the What's New window doesn't appear for 0.6.0 users, and there are no new strings for it. Users
   coming from 0.5.x still see 0.6's window.
2. **What's New**: the top section of `.github/release-notes.md`, headed `## What's new in 0.6.1`,
   which CB-06 enforces. It lists only user-visible changes:
   - a smaller download, with the numbers from §4c, and less energy with power in the menu bar, if
     measured;
   - Window Style and Icon Style mark the choice with an accent outline (`ec61436`, CH-12). The
     0.5 notes promised a flowing glass selection, so say it is gone;
   - Clear is dimmed more, so its white text stays readable over bright windows (`6584585`,
     CH-13);
   - the widget refreshes once the estimate arrives after plugging in or unplugging, and when it
     moves (`994c09d`);
   - earbuds are named after the buds, not their case (`a32bfae`);
   - an update that fails its integrity check is no longer offered as a download. BatteryPulse
     warns and offers the release page (SEC-01);
   - if CH-08 landed: the power value in the menu bar no longer stops updating when the icon is
     turned off or Demo Mode ends;
   - a Mac reporting 0 rated cycles no longer breaks the cycle gauge (AV-04); if AV-01 landed,
     Export Capture also reports a failed save;
   - if WP-9 landed: the "notifications are off" note updates after you return from System
     Settings (CH-03), and Copy Report's tooltip is right on pages without a report (AV-06);
   - if WP-2c landed: in Low Power Mode, live values refresh less often;
   - "Updating from 0.6.0: Install and Relaunch."

   The older sections stay below.
3. **ROADMAP:**
   - a Releases row `| 0.6.1 | <date> | … |`;
   - the "Performance baseline" tables (§4c);
   - the 0.6.1 stage, ticked;
   - the "Next" paragraph pointing at 0.6.2: §6's deferred list, with WP-10 first;
   - the 0.6.0 open checks ticked where the session did them.
4. **USER_GUIDE:**
   - CH-13's wording (WP-UR);
   - SEC-01's update text (WP-12);
   - E6's line, if WP-2c landed;
   - nothing else changes for users.
5. **Remove `docs/plans/0.6.1/`** in the last commit, after ROADMAP holds the lasting decisions.
6. **PR** `claude/nice-faraday-k08mhb` → `main`:
   - mark the D1 draft ready, with a summary, the numbers and the §5 table;
   - both jobs green with 0 warnings;
   - merge after the maintainer's OK in the PR.
7. **Tag:**

   ```
   git tag v0.6.1 <merge-sha> && git push origin v0.6.1
   ```

   Alternatively, run the release workflow by hand with version `0.6.1`. The job runs in the
   `release` environment, so the maintainer approves it **before any step runs**; D1 already ran
   the heading check on the draft, so approval isn't wasted. Then the job runs:
   1. the heading check;
   2. the key check;
   3. the tests;
   4. the build and the size report;
   5. signing;
   6. publishing.
8. **Post-release check** (§4b, 5 min), with the prerelease rollback if it fails.

## 8. The maintainer's answers (2026-10-20)

- **Tile picker (CH-12, G10):** the accent outline only; the selection glass goes. G10 is decided:
  no glass, so the pixel test is not needed.
- **Clear (CH-13, G11):** 0.65 in both appearances. The plain-fill variant stays held for the M5
  reading (G11), as planned.
- **Q1:** no MobileDevice hang or crash seen; SEC-10 stays in 0.6.2.
- **Q2:** WP-10 (main actor by default) moves to 0.6.2.
- **Q3:** device JSON dates (CB-02) wait for 0.7.
- **Q4:** immutable releases stay as they are.
- **Q5:** the whole plan, P2 included if the budget allows; the checkpoint after B2 still applies.
- **Q6:** CryptoKit in the widget (K-03) waits for 0.6.2 unless G13 and the budget allow WP-11b.
- **Branches:** pushing `claude/061-<pkg>` and `claude/baseline-0.6.0` is allowed; they are
  deleted after the release.
- **Architecture:** delegated (2026-10-20). Technical and architectural choices are made in the
  run by Apple's practices and this plan's rules, without asking; only what the maintainer sees
  or does (look, behaviour, settings, the M5 session, the release) goes to the maintainer.

## Appendix A: traceability

Package names are those of §3. "Rider" means it ships with that package unless dropped (→ 0.6.2).

**From the verified audits:**

| ID | Package | Prio | Note |
|---|---|---|---|
| CORE-01 | WP-7 | P2 | One-line hex encoder swap |
| CORE-02 | WP-0a | P2 | Scanner speed; no static regexes |
| CORE-03 | WP-6b | P3 | Test-side `sleep 0` |
| CORE-04 | WP-0a | P3 | Catalog test cache |
| CORE-05 | WP-11 | P3 | `IDeviceInfo` Codable |
| CORE-06 | WP-11 | P3 | Dead members (after WP-UR) |
| CORE-07 | WP-11 | P3 | Unused Codable ×4 |
| CORE-08 | WP-11 | P2 | Three comments |
| CORE-09 | WP-11 | P3 | `BatteryReport.Section` |
| CORE-12 | WP-5 | P3 | Icon half-even (rider) |
| CORE-14 | WP-3a | P3 | `record(_:at:)` default |
| CORE-15 | WP-11 | P3 | Shared report helpers |
| CORE-17 | WP-11 | P3 | Fixture helper, `#require` |
| CORE-19 | WP-7 | P3 | `Devices/` 0700 |
| K-01 | WP-2b (a), WP-7 (b) | P3 | Monotonic clocks |
| K-02 | WP-0b (timeouts and their proof), WP-2a and WP-7 (`.timeLimit`) | P2 / P3 | Moved from WP-8 |
| K-03 | WP-11 (G13 measurement), WP-11b if it passes | P3 | Else 0.6.2 |
| K-04 | WP-2b, then WP-7 | P3 | Notify and IOPS helpers |
| K-05 | WP-7 | P2 | Within SW-06 |
| K-07 | WP-2b, WP-7 | P3 | Doc riders |
| K-08 | WP-2b | P3 | SMC catch-all log |
| K-09 | WP-7 | P3 | With SEC-09's flags |
| K-13 | WP-2a, WP-7 | P3 | Idiom riders |
| K-14 | WP-2a | P3 | Within E3/C1 |
| K-15 | WP-7 | P2 | SW-12 device sites |
| Kit → core one-liners | WP-7 | P3 | DeviceStore `isReadOnly`, default RNG |
| AC-01 | WP-6a | P2 | `ReleaseNotesText`, idle-only blocker |
| AC-02 | WP-11 | P3 | 7 redundant guards |
| AC-03 | WP-11 | P3 | Moved from WP-10 |
| AC-04 | WP-6b | P3 | Helper only |
| AC-05 | WP-6a | P3 | `unversioned` |
| AC-07 | WP-11 | P3 | `migrate()` unchanged (G7) |
| AV-01 | WP-5 | P2 | Export Capture errors |
| AV-02 | WP-5 | P3 | Redaction test (rider) |
| AV-04 | WP-5 (part 1, core), WP-9 (parts 2–3) | P3 | No hero or gauge component |
| AV-05 | WP-3b | P3 | `@AppStorage` sentence |
| AV-06 | WP-9 (lite) | P3 | Fallback strings |
| AV-07 | WP-9 (lite) | P3 | Comment |
| AV-08 | WP-3b; guard in WP-12 | P3 | G12 |
| AV-09 | WP-3b | P3 | With SUI-04 |
| AV-10 | WP-9 (lite) | P3 | `onChange(initial:)` |
| AV-11 | WP-5 | P3 | Volts rule (rider) |
| AV-12 | WP-3b | P2 | Log load failures |
| AV-14 | WP-9 (full) | P3 | Placement in the split |
| CH-01 | WP-12 | P3 | Motion preset and guard |
| CH-02 | WP-9 (full) | P3 | During the split |
| CH-03 | WP-9 (lite) | P3 | Stale "notifications off" |
| CH-04 | WP-9 (lite) | P3 | `WindowOpener` |
| CH-05 | WP-11 | P3 | Unused parameters |
| CH-06 | WP-9 (lite) | P3 | Log Clear History |
| CH-07 | WP-9 (lite) | P3 | Widget placeholder |
| CH-08 | WP-2a | P2 | Member count (G8) |
| CH-09 | WP-11 | P3 | One `DynamicProperty` |
| CH-11 | WP-9 (full) | P3 | Reuse `SettingsPage` |
| CH-12 | WP-UR | P1 | G10 |
| CH-13 | WP-UR | P1 | G11 |
| UR-3 | WP-UR | P1 | Black frame on minimize in Clear (maintainer, 2026-10-16); session V4 |
| CB-02 | WP-12 (ROADMAP 0.7 entry) | P3 | No code in 0.6.1 |
| CB-04 | WP-1 | P2 | `bpulseTests`, parser table |
| CB-05 | WP-5 | P3 | `CaptureFormat.swift` |
| CB-06 | WP-8b; release gate | P1 | Heading check |
| CB-07 | WP-0b | P2 | Moved from WP-8 |
| CB-08 | WP-8b; its canary line in WP-7 | P3 | With SEC-06 |
| CB-09 | WP-1, WP-8b, WP-12 | P3 | Comments, lint, PR template |

**From the playbook backlog (§3.3):**

| ID | Package | Prio | Note |
|---|---|---|---|
| SUI-01 / E1 | WP-0a | P1 | Plus the `perf` debug lines |
| B1–B6 | WP-0a | P1 | Benches |
| M1 | WP-0b | P1 | `rusage.swift` |
| E2 | WP-0b | P1 | `PROFILING=1` |
| SZ-04, SZ-09 (C3) | WP-0b | P1 | Size report |
| SW-14 | WP-0b | P1 | Warning gate |
| SW-24 | WP-0b, WP-1 | P1 | |
| SW-01, SW-02 | WP-1 | P1 | |
| SW-03, V-02 | WP-1 | P1 | `migrate` as a report |
| SW-13 (BatteryCore) | WP-1 | P1 | |
| SW-20 | WP-1 | P1 | Nine rules |
| E3 | WP-2a | P1 | |
| C1 | WP-2a (monitor), WP-3a (store), WP-4 (widget day) | P1 | |
| E8, monitor half | WP-2a | P1 | First commit |
| E4a | WP-2b | P1 | |
| SW-08 (SUI-10) | WP-2a, 3b, 4, 6b | P1 | The shield on `replace` is a WP-6b P2 rider |
| SW-12 (SEC-12) | WP-2a, 2b, 3b, 4, 6b, 7, 9 | P1 | |
| E7 | WP-2a, 3b, 4, 6b | P1 | Every site |
| SUI-03, SUI-04 | WP-3b | P1 | |
| SUI-05R / E13 | WP-3a | P1 | G1 (Linux) |
| SW-09, V-03 (SUI-08, E22) | WP-4 | P1 | |
| SUI-02 | WP-5 | P1 | |
| SW-05 | WP-5, WP-6b | P1 | |
| SEC-01, SEC-05 | WP-6a | P1 | |
| SW-06 | WP-6b, WP-7 | P1 | |
| SZ-01, SZ-02, SZ-03, SZ-05 (SW-18) | WP-8a | P1 | G2, G3 |
| SZ-06 | WP-8a, WP-11 | P1 | |
| SEC-07, build check | WP-8b | P1 | |
| SEC-07, guard test, and C4 | WP-12 | P1 | |
| SW-17, V-05 | WP-11 | P1 | |
| SW-04, V-01 | Deferred (WP-10) | P1 → 0.6.2 | §3.1 |
| Docs | WP-12, D3 | P1 | |
| E17 | WP-2a | P2 | Rider |
| E5, E6 | WP-2c | P2 | |
| SW-06 (`UncheckedSendable`) | WP-2b | P2 | Rider |
| SW-07 | WP-2b | P2 | Rider |
| E3b | Deferred | P2 | G15 |
| SUI-13 (History) | WP-3b | P2 | Rider |
| E14 | WP-3a | P2 | Rider |
| E8, recorder half | WP-4 | P2 | Rider |
| E15 | WP-4 | P2 | The policy's own maximum, see §3.1 |
| V-04 | WP-4 | P2 | G5 |
| SUI-06 | WP-5 | P2 | Rider |
| SEC-19 | WP-6a | P2 → P1 | Needed by SEC-01 |
| SEC-02 | WP-6a | P2 | With AC-01 |
| SEC-03, E11, SW-11 | WP-6b | P2 | Riders |
| SEC-09 (version) | WP-7 | P2 | Rider |
| SW-12 (device and accessory identifiers) | WP-7 | P2 | With K-15 |
| SEC-10 | Deferred (WP-7b) | P2 | G19 |
| SEC-06 | WP-8b | P2 | With CB-07's pin, CB-08 |
| SZ-07 | WP-8b | P2 | |
| SZ-10 | Deferred | P2 | G21 |
| SEC-08 | Deferred | P2 | G20 |
| SUI-13 (Settings, Components) | WP-9 (full) | P2 | |
| SUI-15 | WP-9 (full) | P2 | Review |
| SUI-07 | Deferred | P2 | G17 |
| SUI-17, SUI-18 | Deferred | P2 | Need Xcode on the Mac |
| SW-15 | WP-11 | P2 | Report only |
| SW-19 | WP-11 | P2 | With CORE-17 |
| SW-21 | Deferred | P2 | §6 |
| E18 | Session step 5 | P2 | Measurement |
| S4w | Deferred | P2 | Not in the session |
| E4b, E20 | Deferred | P3 | G14, G16 |
| SUI-12 | Deferred | P3 | G17 |
| SUI-09 | Deferred | P3 | |
| SUI-11, E19 | Deferred | P3 | G17 |
| SZ-08 | Deferred | P3 | |
| E10 | Deferred | P3 | |
| SEC-15 | Deferred | P3 | G18 |
| SEC-17 | WP-6a | P3 | Rider |
| SEC-09 (flags) | WP-7 | P3 | With K-09 |
| SEC-11 | WP-7 | P3 | Depth 64 |
| SZ-11, SZ-14 | Deferred | P3 | G21 |
| SUI-19 | Deferred | P3 | |
| SUI-21 | WP-12 | P3 | One CLAUDE.md line |
| C2 | Deferred | P3 | |
| SEC-16 | WP-12 | P3 | Privacy text check |
| SEC-18 | Deferred | P3 | |
| SUI-14, SUI-16 | Obsolete since 0.6.0 | — | |
| SUI-22 | Rule UI-3 | — | Review only |
| SEC-13 | = SW-13 | — | |
| SW-13 (BatteryKit) | Deferred | P2 | |
| SW-16 | Not taken (SW-R17) | — | |
| V-06 | No work | — | |

## Appendix B: rejected (don't resurrect)

**From the verified audits:**
- whole findings: CORE-10, CORE-11, CORE-13, CORE-16, CORE-18, CORE-20, K-06, K-10, K-11, K-12,
  AC-06, AV-03, AV-13, CH-10, CH-14 (done in `6584585`), CB-01, CB-03;
- rejected parts of kept findings:
  - CORE-01: the `Hex` type and a stored `RawRow.value`;
  - CORE-02: `static let` regexes and literal prefilters;
  - CORE-03: a production `settleSeconds`;
  - CORE-17: a static cache;
  - K-08: 0x85 → missing;
  - K-13: a cached Ed25519 key;
  - AC-01: an unconditional blocker;
  - AC-04: the file move;
  - AV-04: `BatteryHero`, `GaugeRow`, the `stateWithPower` merge, `levelTier`;
  - AV-11: the hex helper;
  - AV-12: `@State` dedup;
  - CB-04: the render split;
  - CB-05: the decoder helper and the test rewrites;
  - CB-09: the `STYLES` test.

**From the playbook (§3.3), by area:**
- **SwiftUI:** SUI-05 as written; SUI-06's closure reason; a Bool for `CopyReportButton`;
  diacritic folding; SUI-20; SUI-21 as a test; splitting the snapshot; `scenePhase` for
  occlusion; a `Canvas` glyph; `drawingGroup` on charts; blanket `.equatable()`.
- **Swift:** SW-10, SW-22, SW-23; `ExplicitSendable`; permanent `PerformanceHints`; experimental
  flags; typed throws everywhere; `@inline(always)`/`@specialized`; the Subprocess package; module
  selectors; `isolated deinit`; `weak let`; main-actor default for the widget;
  `--explicit-target-dependency-import-check`; per-function `@diagnose(StrictMemorySafety…)`.
- **Energy:** the E4 private-message spike, E9, E12, E16, C5.
- **Security:** SEC-04, SEC-14; SEC-15's environment wiping; SEC-11's size caps; the `dladdr`
  assertion; moving `contents: write`; certificate pinning; fd-based verification; an Enhanced
  Security helper extension; App Attest; post-quantum signatures; provisional notifications; a
  privacy manifest; App Sandbox for the app; exact URL-prefix pinning.
- **Size:** SZ-12, SZ-13; `-objc_stubs_small`; binary `.strings`; zlib-9; UDBZ; `package` for size;
  `lzma-level`; `-no_exported_symbols` on the widget; `-Xlinker -S`.

## Appendix C: facts settled during the run

Packages append one line per fact here: what they found, on which job, and which item it decides.
This covers the playbook §4 CI questions, the gates of §3.6 and the SDK checks.

- (none yet)

### A1 (WP-0a, WP-0b), merged 2026-10-20

- **perf triggers:** a seventh refresh trigger, `followUp`, marks the reads after a plug change
  (playbook §2.2 names it); `perf-stats.swift` accepts any trigger string. The trigger field also
  carries each interval's static detail (`history.load` day or week, `update.check` user or
  automatic, `page.switch` the page, `widget.reload` policy or update).
- **SMC parts:** `smc.power` and `smc.other` are two reads of the same keys (B0AV and B0AC first,
  then the rest); `MacBatteryProvider`'s private `smcPowerKeys` is what WP-2b's `liveKeys` replaces.
- **Linux numbers (noisy, another agent running):** B2 7-day store cold 72 ms in release (106 ms in
  debug), so G1 points to the decode cache; B4 raw sections 3.5 ms; B5 five-way filter 6.9 ms against
  joined 2.1 ms. Guard suites in parallel 1.8 s → 0.8 s.
- **macOS job facts (run 39411206693):** `.dSYM` folders for all three products are in the release
  bin path; the widget's link line has `-dead_strip` and no `-export_dynamic`; `hdiutil create` lists
  ULFO and ULMO; `hdiutil imageinfo` is deprecated in favour of `diskutil image info`; plutil reads
  the JSON budget. DMG (UDZO) 3,676,272 B, `.app` 11,112 KB, app binary 7,568,864 B, widget binary
  3,157,120 B; the hygiene counts are all 0, including `/Users/` strings, unlike the size research's
  133 in an unstripped binary. App and widget both report 4170 exports: WP-8a checks that the widget
  count reads the widget binary.
- **Flaky test:** `BatteryMonitorTests.pluggingInIsFollowedByExtraReads` failed once on macOS
  (wall-clock sleeps of 10-150 ms under load) and passed on the next runs. WP-2a's E3 (an injected
  `Clock`) must make it deterministic.
- **K-02:** the swift-testing time limit reports "Time limit was exceeded: 60.000 seconds" on Linux,
  and the process then hangs until killed, so the job timeout is what ends a hang. The CI half was
  not run. Output of a killed `swift test` redirected to a file is lost; run it under a pty.
- **Toolchain (2026-10-20):** Xcode 27.1 (27A9275, Swift 6.4) shipped on 2026-10-15. The
  `xcode-27` image still defaults to 27.0 but has 27.1 at `/Applications/Xcode_27.1.app`, so both
  workflows set `DEVELOPER_DIR` to it, the baseline branch too, so before and after use the same
  compiler. The Linux container is Swift 6.4.1. `actions/checkout` has v6 (v6.0.3): WP-8b moves both
  workflows to it, pinned by SHA with `persist-credentials: false` (SEC-06).
- **The "before" (A1′), `claude/baseline-0.6.0` at `076873d`, Xcode 27.1, run 39413159534:** DMG
  (UDZO) 3,699,952 B; `.app` 11,180 KB; app binary 7,618,784 B (`__text` 2,116,636 B, 4195
  exports); widget binary 3,172,800 B (`__text` 1,084,028 B); `.lproj` 410,328 B; `AppIcon.icns`
  215,181 B; every hygiene count 0. The integration tip `98b4fe7` (0.6.0 plus the four fixes and
  WP-0) reads DMG 3,704,721 B. The widget's export count again equals the app's (4195 and 4200), so
  the report reads the same binary twice or the counts happen to match: WP-8a checks.

### A2 (WP-1, WP-UR), merged 2026-10-20

- **Strict memory safety on Darwin:** Darwin Foundation marks `String(format:)` `@unsafe`; Linux
  corelibs don't, so BatteryCore had 0 warnings on Linux and 9 errors on macOS and iOS. The
  integer formats are plain Swift now (same output); the fixed-point ones go through one private
  `BatteryReport.cFormat` with a Darwin-only `unsafe`. `CFormatEquivalenceTests` pin both. bpulse has
  3 marked sites. An `unsafe` marker on the Linux side warns `UnnecessaryUnsafe`. WP-12 rewords
  SW-R13 (unsafe is no longer only in BatteryKit's IOKit/SMC/MobileDevice and the app's
  `proc_*`/`kill`).
- **Upcoming features on Darwin:** 4 `(any NSObjectProtocol)?` tokens, 1 `import BatteryKit`, and
  `AppDelegate` and `BatteryNotifier` conform `nonisolated` (InferIsolatedConformances). The widget
  and the iOS BatteryKit build had 0 diagnostics.
- **`swift package migrate` on macOS** (report in the message of `f2e3740`): 15 `@concurrent`
  fix-its, none taken. `UpdateInstallSteps.replace` must become `@concurrent` once WP-6b calls it
  directly. migrate can't edit this manifest (the settings come from the shared array) and exits 1.
  The compiler colours diagnostics even into a file; strip them before grepping.
- **Clear (CH-13):** 0.65 gives 5.22:1 primary and 3.21:1 secondary over a white window and a
  dimmed gap of about 94/255 (G11's expected V2 reading); 0.40 gave 2.41:1, 1.82:1 and 156/255.
- **UR-3:** `WindowLookPolicy.SheetSurface` decides the sheet's place; from `willMiniaturize` to
  `didDeminiaturize` it is a plain fill of the sheet's own tint over the still see-through window,
  for Translucent and Clear; Standard and Frosted are untouched. `WindowMinimizeReader` calls
  `displayIfNeeded()` at `willMiniaturize`. Unproven until V4: if the snapshot is taken before
  SwiftUI applies the change, the next step is an explicit transaction flush or writing the
  behaviour down (candidate c). Check minimize and restore separately, with Shift held.
- **The held variant** `claude/061-ur-clearfill` (`51c383c`) sits on the pre-rebase CH-13 commit;
  D1 rebases it onto the RC before the session.
- **Release notes (D3):** one line that the tile picker's selection is now an accent outline (the
  0.5 notes advertised a flowing glass selection).
