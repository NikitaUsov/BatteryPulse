# BatteryPulse: the roadmap to 1.0.0

Written 2026-10-22, the day 0.6.1 was released. It answers the maintainer's request: a plan for
0.6.2, a plan for 0.7, and everything that is left until 1.0.0. English only; it names no
third-party product. Working notes it cites that aren't in the repository are marked so.

**Updated the same day with the maintainer's answers (2026-10-22).** No paid developer account
(M-1); Xcode is already on the M5 (Q-B7); Clear's minimize fill is (b) (Q-B2); widgets in 0.7, no
0.6.3 (Q-W1). Every other question was delegated ("do it by best practices, as you see fit") and
is decided as its recommendation. Only M-5, what 1.0 means, awaits the maintainer (§5.3, §6).

**Sources and how they are cited**

| Short | Source |
|---|---|
| R:n | `docs/ROADMAP.md` as v0.6.1 shipped it (unchanged at `eebf748`), line n |
| UG:n | `docs/USER_GUIDE.md`, line n |
| RM:n | `README.md`, line n |
| file:line | a file in `Sources`, `scripts`, `.github` or `Tests`. The working copy is `eebf748` on `claude/nice-faraday-k08mhb`, which is v0.6.1 (`7622373`) plus `docs/plans/0.6.2/PLAN.md`, so these lines are v0.6.1's |
| P2 | the verified 0.6.2 plan, `docs/plans/0.6.2/PLAN.md` (section, package `WP-…`/`W-…`, or question `Q-…`) |
| INV | `docs/plans/1.0/INVENTORY.md`; its row IDs (`FEA-01` …) are used throughout |
| P1, PB, RES-x | the 0.6.1 plan, playbook and research files in `6aec4d2:docs/plans/0.6.1/` (in PR 11's history) |
| V, Q, D | the three independent proposals for 1.0 this roadmap judged: user value (V), quality and trust (Q), distribution and platform (D); working notes, not in the repository |
| CLR, PKG, ICL | checked research on charge limiting (CLR, so it isn't confused with the 0.7 plan's CL for `CLAUDE.md`), package managers (PKG) and iCloud (ICL); working notes, not in the repository |
| NOTES27 | the macOS 27 release notes, saved at https://developer.apple.com/documentation/macos-release-notes/macos-27-release-notes |

Apple URLs below were fetched on 2026-10-22 unless marked. GitHub numbers, including download
and traffic counts, come from `gh api` (GitHub's REST API) on 2026-10-22.

**Marks:** [unverified] means nobody has checked it; [uncertain] means the evidence is partial or
conflicting; [estimate] is a planning number, not a measurement; [assumed] is a date or fact
taken from Apple's usual pattern, not from a source.

**IDs:** inventory rows keep their IDs. Items this roadmap adds are `NEW-01` to `NEW-23` (§5.2).
Maintainer decisions are `M-1` to `M-14` (§6; M-6 is informational, an engineering decision); all
are decided as of 2026-10-22 except M-5. 1.0's criteria are `C1` to `C17` (§2).

Contents:
1. Where we are
2. What 1.0.0 means
3. The versions from 0.6.2 to 1.0.0
4. After 1.0, not planned, and rejected
5. Every inventory item placed
6. Decisions only the maintainer makes
7. Risks and how the plan absorbs them
- Appendix A: the three proposals, judged

---

## 1. Where we are

### 1.1 The product on release day of 0.6.1

- **What it is:** a native battery and charging inspector for macOS 27 on Apple silicon. It is
  SwiftUI with no dependencies and ships as a DMG outside the App Store, with signed in-app updates
  (R:8-12, R:183-201).
- **What it does:**
  - Overview, Power, History, Health; Raw Data and Demo Mode in the Developer section (R:15-22);
  - iPhone and iPad battery health over USB or Wi-Fi, with history (R:594-633);
  - Bluetooth accessory batteries (R:652-670);
  - CSV and JSON export (R:671-676);
  - a small and medium widget (R:137-139);
  - menu bar icon styles (R:220-248) and four window styles, two of them beta (R:303-308);
  - notifications (R:591-592);
  - English and Russian;
  - the `bpulse` command line for people who build from source (UG:561-663).
- **Releases:** seven in eight days, 0.2.0 to 0.6.1 (R:691-699).
- **Size and speed at 0.6.1:**
  - DMG 1,439,093 B; installed app 4,608 KB; app binary 2,856,976 B (R:452-455).
  - A full read takes 6.3 ms at p50 and 8.8 ms at p95; page switches take 30-65 ms (R:482-491).
- **Users:** the repository was created on 2026-10-14. The usage evidence (`gh api`,
  2026-10-22):
  - **DMG downloads:** 14 across all releases. 0.2.0: 1, 0.3.0: 2, 0.3.1: 4, 0.4.0: 1, 0.5.0: 2,
    0.6.0: 3, 0.6.1: 1, and that one was a signature check during the release.
  - **Signature (`.sig`) downloads:** 5. Each in-app install fetches the `.sig`, so this count is
    a privacy-free proxy for in-app updates.
  - A re-check later the same day showed 15 DMG and 6 `.sig` downloads, one more of each for
    0.6.1 (`.sig` per release then: 0.4.0: 0, 0.5.0: 1, 0.6.0: 3, 0.6.1: 2).
  - **Repository traffic:** 2 page views by 1 visitor in 14 days.
  - **Community:** 0 stars, 0 forks and 0 watchers, and no issue from anyone else.

  So the users are, in practice, the maintainer alone (D). The app counts nothing and sends
  nothing (C14 item 8); from 0.6.2 on, each release's download counts are recorded a week after
  publishing (§1.2 item 6, NEW-23).
- **What is open:** 130 items, 22 maintainer questions and 62 rejected ideas (INV Summary). The
  questions, and M-1 to M-14, are decided as of 2026-10-22, except M-5 (§5.3, §6).
  - 54 of the items need the MacBook Air M5, 42 of them in 0.6.2 (FEA-23 and SEC-01 left it with
    the answers).
  - 12 depend on the paid developer account, which the maintainer declined (M-1).
  - 11 need Xcode on the Mac, which is installed on the M5 (Q-B7).
- **What is next (already planned):**
  - 0.6.2: maintenance and foundation (P2).
  - 0.7: widget customization and the device JSON dates (R:543-556; P2 §8, §9).
- **What is not planned:** an iOS app, charge limiting (R:704-706), and Developer ID signing and
  notarization: on 2026-10-22 the maintainer decided against the paid account, not now and not
  before 1.0 (M-1).

### 1.2 The practices 0.6.1 established (they hold to 1.0 and after)

1. **Measure first.**
   - Every optimization has a before and an after, measured with signposts whose names stay
     stable.
   - The tools: a baseline branch built with the same compiler, Linux benchmarks, and CI's size
     report with ceilings about 5 % above the release candidate (R:418-421; PB §2).
2. **Rules have guard tests.** A rule is a Linux test over every target's sources, Darwin code
   included, and an exception goes on the suite's list with its reason (R:421-423; CLAUDE.md).
3. **Gates with defaults.**
   - Every decision that needs the M5 has a default, so a short session still ships.
   - A default never ships read-path code that no M5 run has exercised (P2 §3, §7.1).
4. **One implementation run, then a separate review run.**
   - One commit per item.
   - Before each commit: format, build, test and lint. Darwin code also needs a green macOS job.
   - `--no-ff` merges; at most two agents at once (P2 §3).
5. **Frozen outputs within a minor release.** `bpulse` output, the capture format, storage,
   settings keys and the update contract stay unchanged (R:437-439; PB §3.4). "No loss of
   functionality" is proven by:
   - the test suite;
   - golden outputs;
   - an M5 checklist;
   - storage and settings diffs (PB §2.6).
6. **Releases.**
   - The release candidate, built as 0.5.99, installs the real previous release through the new
     installer (F12).
   - After publishing comes a check: About shows the new version; History, settings and the login
     item are kept; the widget is current. If anything fails, the release becomes a pre-release
     (`--prerelease`) (P2 D1-D3).
   - A week after publishing, the release's DMG and `.sig` download counts are read from the
     releases API and recorded in ROADMAP's Releases table (NEW-23, from 0.6.2's D3 on). That is
     the only usage measure: the app has no telemetry (C14 item 8).
7. **Sessions.**
   - Scripted; "y = looks right"; comparisons as numbered choices; recordings and screenshots as
     evidence.
   - The script, not the maintainer, reads the logs (P2 §3, "Session wording").
8. **Division of labour.** The maintainer decides only what he sees or does: look, behaviour,
   settings, the sessions and the release. Technical choices are delegated (P1 §8,
   "Architecture: delegated"). On 2026-10-22 he also delegated every open roadmap question but
   M-5 ("do it by best practices, as you see fit"); the looks themselves are still his to sign
   off in the sittings.
9. **Facts are recorded.** Each plan keeps an Appendix C of facts. At release, its design moves
   forward and the plan folder is removed (P2 D3).
10. **Updates are never offered unverified.**
    - The signing keys are a list, and every build checks its signing posture.
    - Workflow actions are pinned by commit (R:368-373, R:385-386, R:432-433).
11. **Energy.**
    - Event-driven first, with one read per burst of notifications.
    - A tolerance of at least 10 % on every periodic wake-up; no timers; one activity, around an
      install (R:424-427).

---

## 2. What 1.0.0 means

**Definition.** 1.0.0 is the first release meant for people other than the maintainer. It
promises three things:

1. **Seen working.** What the User Guide says works was seen working in the shipped build on the
   reference Mac.
2. **Nothing breaks through 1.x.** Scripts, settings, stored data, placed widgets and the update
   path keep working.
3. **Usable by a non-expert.** Someone who isn't an expert can install BatteryPulse, understand
   what it shows, and report a problem without developer tools.

It is a promise, not a feature count: **1.0.0 is the last 0.9.x renamed, with no new code** (V,
Q and D agree).

Each criterion below can be checked: by a Linux or CI test, a scripted M5 step, or a document
that exists.

### 2.1 Features

- **C1 Contents.**
  - Everything 0.6.1 ships (USER_GUIDE).
  - 0.7's widget MVP: the configurable Battery widget in small, medium and large, and in extra
    large if the maintainer approves its layout in 0.7's look check (Q-W10; a family can be added
    later without touching placed widgets, P2 §8.13), plus the Accessories widget if W0-4 passes
    (P2 §9.1; plan-0.7.0 §2.5).
  - 0.8's answers (§3.3): why the battery isn't charging (causes confirmed by captures only), a
    health summary, in-app explanations of the numbers, a first-run Welcome, and Report a
    Problem. An item 0.8's cut line moves lands in 0.9.0 instead, still before 1.0.
  - The History and iPhone & iPad widgets count toward 1.0 only if they shipped in 0.7.0
    (§3.2).
- **C2 Every feature seen in a packaged build.** A verification matrix (NEW-18) maps each
  USER_GUIDE feature to the session and the evidence (screenshot or log) from a DMG build. Every
  open "Check on the M5" line in ROADMAP is ticked, or listed under Known limitations in the guide
  and in 1.0's release notes. The 54 M5 rows open today are the starting list (INV Summary).
- **C3 No known issue in anything on by default.**
  - The guide's known issues may list only beta styles, Developer options, and what C7 allows: a
    permission or a placed widget that must be set up again after an update, with the steps to do
    it. The maintainer declined the paid account (M-1, 2026-10-22), so that loss may have no fix
    (INV DIS-06), and C3 doesn't block 1.0 on it.
  - Two consequences of the ad-hoc signature are documented known limitations at 1.0, in the
    guide and in 1.0's notes, and nothing waits for a signed build:
    - Open Anyway on every install from the DMG (C16);
    - a permission or placed widget that may need setting up again after the DMG replaces the app
      (C7).
  - A feature not yet seen on the M5 is a known limitation (C2), not a known issue.
  - Today it lists Clear's black minimize frame (UG:162-163), which 0.6.2 fixes, and widgets lost
    on a DMG replacement (UG:425-426), which 0.6.2 and 0.7 re-test (DIS-06).

### 2.2 Quality bars

- **C4 Seven-day soak.** The final 0.9.x runs in daily use on the M5 for 7 days, nights
  included. The script counts:
  - **Crashes:** 0 crash reports for the app or the widget (`~/Library/Logs/DiagnosticReports/BatteryPulse*`).
  - **Faults:** 0 `fault` messages in the `io.github.nikitausov.BatteryPulse` subsystem.
  - **Memory:** `phys_footprint` on day 7 within 10 % of day 1.
  - **History:** every History gap longer than 3 minutes follows a launch or wake marker
    (History.swift:4-9) or a sleep in `pmset -g log`.
- **C5 Energy within budgets.** The final 0.9.x's energy run alternates it with 0.6.2's published
  DMG on the same day (0.6.2 C 0.6.2 C, 0.6.2's protocol, P2 WP-21). Each metric passes when the
  final 0.9.x is no more than 15 % above 0.6.2 that day, since 5-minute runs carry about 15 %
  noise. Absolute numbers months apart, on a later macOS 27.x and an older battery, would compare
  noise; that is why 0.6.2 itself pairs builds on one day. 0.6.2's release-candidate numbers stay
  in ROADMAP for reference. The metrics:
  - S1: wake-ups per hour;
  - S2: energy per hour with power in the menu bar;
  - S6: CPU with the displays asleep;
  - launch to `menuBarReady` at p50, with exactly 1 read before it;
  - idle `phys_footprint`;
  - an iPhone attached with all windows closed: under 1 ms/s (R:636-637), which stays an absolute
    target.
- **C6 The resource targets of R:46.**
  - **Binary:** the app binary stays under 5 MB. It is 2,856,976 B at 0.6.1 (R:454); a bundled
    `bpulse` (M-7) is counted separately.
  - **Idle CPU:** S1's CPU seconds per hour within C5's S1 comparison, and about 1 read a minute
    (PB §2.7 measures S1 in mJ/h, package-idle wake-ups/h and CPU s/h). R:46's "about 0 %" is
    restated as that number at 0.6.2's D3.
  - **Memory:** idle `phys_footprint` with no window open under 30 MB, measured without
    Instruments. If it is above, 1.0 needs the maintainer's yes to restating R:46 with the
    measured number (M-5), recorded as a known limitation. [uncertain: never measured; R:151 has
    been open since 0.3]
- **C7 The upgrade matrix.** Install and Relaunch on the M5 reaches the published final 0.9.x
  from:
  - 0.4.0, the oldest in-app installer;
  - 0.6.1;
  - the last 0.7.x and the last 0.8.x;
  - plus one install over the old copy from the DMG.

  What must survive:
  - History, devices and settings, byte-compatible (PB §2.6 item 4);
  - the login item, notification permission and placed widgets, or the guide says which one must
    be set up again (R:180-181, R:202-208; UG:493-495).

  The DMG leg meets Open Anyway. A grant or widget that any leg loses (the DMG leg most likely)
  is recorded as the known limitation C3 allows, with the steps to set it up again: the
  signature stays ad-hoc through 1.x (M-1), and no leg waits for a signed build.

  If 0.4.0 or 0.5.0 fails, the notes say "from 0.4 or 0.5, download the DMG once" (D, Q).

  C7 runs on the maintainer's only Mac, over his real data, so every leg is backed up and restored
  by the session script, and it runs before the soak (§3.6).
- **C8 No update leaves an app that can't launch.**
  - The installer refuses a bundle whose `LSMinimumSystemVersion` is above the running macOS.
    `build-app.sh` writes the key (build-app.sh:104, 140), but nothing reads it before the swap
    (UpdateInstall.swift:163-170).
  - The relaunch step puts the old copy back if the new one fails to open. [unverified:
    mechanics] (D)
- **C9 Robustness pinned by tests** (Linux):
  - **Storage:** every shipped storage format decodes, and a "future 1.x" file with extra fields,
    unknown cases or a higher version loses nothing. The decoders already tolerate this
    (History.swift:86-94, HistoryStore.swift:333-337, DeviceStore.swift:90-95), but no test
    names it (Q).
  - **Parser perturbation:** for every fixture with each key removed, each type swapped, or an
    extreme value, there is no crash, and every value derived from that key shows "—" or
    "Unavailable", never 0 or a value taken from another key (Q).
  - **Degradation:** each private or moved source missing gives an explanation, never a blank or
    a crash. The sources are MobileDevice, `IOPSCopyPowerSourcesByType(4)`, the SMC keys and the
    registry entries below `AppleSmartBattery` (D; R:63-75).
- **C10 Accessibility.**
  - **VoiceOver:** every control on every page, the menu bar panel, every Settings pane and every
    widget family is reachable and named, in English and Russian.
  - **Charts:** every chart has a descriptor
    (https://developer.apple.com/documentation/swiftui/view/accessibilitychartdescriptor(_:)).
    Today the chart parts are hidden (ChargeChart.swift:31, PowerChart.swift:29) and none has a
    descriptor (R:573).
  - **Keyboard:** the sidebar, toolbar, tile pickers, Raw Data and the update window can be used
    without a pointer.
  - **Contrast:** Xcode is on the M5 (Q-B7), so the maintainer runs Accessibility Inspector from
    Claude's step-by-step list in 0.8's release-candidate sitting. It finds no failures in
    Standard and Frosted, light and dark, and with Increase Contrast. Beta styles are exempt and
    marked.
  - **Stage 1.4's checks pass** (R:298-301).
- **C11 Russian.**
  - The maintainer signs off a scripted screenshot set of every screen, alert, notification and
    error message (NEW-20).
  - The catalog stays complete: 719 keys today, enforced by `LocalizationCatalogTests`.
- **C12 Engineering gates.** The existing gates hold:
  - 0 compiler warnings;
  - `swift format lint --strict` passes;
  - every guard suite is green;
  - the test count only grows.

  The new guards join them: the explanation key (NEW-03), log privacy (NEW-12) and frozen
  surfaces (NEW-08).
- **C13 Release health.** No open issue about a crash or data loss. The last two releases before
  1.0 needed no rollback with `--prerelease` (D).

### 2.3 Stability promises for 1.x (C14)

A Compatibility section in the User Guide lists these. A change may only add; breaking one waits
for 2.0. The promise lasts a major version instead of a minor (R:437-439) (D, Q).

1. **Settings keys** of the `io.github.nikitausov.BatteryPulse` domain: names, types and defaults,
   and the legacy migrations. That is PB §3.4's list, plus `betaWindowStyles`, plus `openAtLogin`
   if 0.6.2 adds it.
2. **Storage** under Application Support: `History/` and `Devices/`.
   - Files only gain fields, and readers ignore unknown ones.
   - The widget feed, if it ships, is an internal file between an app and a widget of the same
     version. Its location may move in a minor release with a line in the notes, and its schema
     only gains fields.
   - A newer `devices.json` makes the store read-only, never lossy (DeviceStore.swift:90-95).
3. **The capture format** (`--raw` and Export Capture), which test fixtures and bug reports use.
4. **`bpulse` machine outputs:**
   - `--json`, `--raw`, `--device <n> --json|--raw`, `--accessories --json|--raw`;
   - `--export csv|json` (`formatVersion` 1, HistoryExport.swift:135);
   - the `--record` folder layout, the options, and the exit codes 0, 1 and 2.

   Fields and options are only added. **Not frozen** (M-6, an engineering decision): the text
   report, `--help`, the text of `--smc` and `--watch`, and stderr. They may change in a minor
   release, with a line in the notes.
5. **Widgets** (P2 §8.13):
   - kind strings, intent, entity and query type names, parameter names, `AppEnum` raw values and
     entity ID formats;
   - `supportedFamilies`, which are only added to;
   - what Automatic shows in each size;
   - `PageID` and `WidgetRoute` strings, and the URL scheme if there is one.
6. **The update contract:**
   - `BatteryPulse.dmg` and `BatteryPulse.dmg.sig` on GitHub Releases, read through
     `releases/latest`;
   - the Ed25519 key list: keys are only added. A compromised key is removed in a release whose
     notes say why;
   - the bundle IDs and the log subsystem;
   - every 1.x version can install the next one in-app.
7. **Platform:** macOS 27 or later on Apple silicon throughout 1.x. The floor rises only in 2.0
   (D). [uncertain: once no macOS 27 machine or runner remains, 27 is only built for, not run;
   the notes would then say so]
8. **Privacy:** the update check and a download the user chose are the only internet requests
   (UG:502-507). Nothing else is sent, and there is no telemetry.

**Not promised:**
- readings macOS stops providing (a private source may become "Unavailable", UG:376-378);
- looks and wording;
- the beta window styles' look, though their stored values keep decoding;
- the Developer options;
- energy beyond C5's budgets;
- the signpost names. They stay stable for measurements (CLAUDE.md), but that is an internal rule.

**Enforced by:**
- NEW-08: a frozen-surface test suite, with golden outputs committed and compared on Linux and
  macOS;
- P2 §8.13's widget pin test (0.7).

### 2.4 Distribution and documentation

- **C15 Releases and keys.**
  - Releases stay a DMG, its `.sig` and the dSYMs on GitHub Releases, with in-app updates.
  - `ReleaseSigning.publicKeys` lists two keys, today's and an offline backup (M-9: yes, decided
    by delegation). If the maintainer never generates the backup, ROADMAP records that as an
    accepted risk. Today it lists one (ReleaseSigning.swift:15-17).
  - The `release` environment's required reviewer is confirmed (release.yml:6-9).
- **C16 First install, ad-hoc (M-1: no paid account, 2026-10-22).**
  - README and the guide show Done → Privacy & Security → Open Anyway with screenshots re-taken
    on the current macOS 27.x (RM:22-25, UG:33-43).
  - The guide's Known limitations and 1.0's notes say that every install from the DMG meets Open
    Anyway, and that in-app updates don't (R:161-201).
  - A notarized first launch (PKG B25) is not planned (§4.2).
- **C17 The documentation matches the product.**
  - **README:** no iOS promises (the badge RM:5, RM:14-15, and the iOS column and footnote of
    "What each platform exposes", RM:192-206), no "Status: early development" (RM:14),
    screenshots, and an honest hardware claim. It says "verified on a MacBook Air M5"
    unless a fixture from another Apple silicon laptop exists (D; R:149-150).
  - **The guide gains:**
    - the Compatibility section (C14);
    - Uninstall and Troubleshooting;
    - every file BatteryPulse writes and every network request it makes.
  - **Help** opens the guide at the release's tag. Today it opens `blob/main`
    (AppSettings.swift:171, Updates.swift:163-166).
  - **Reporting:**
    - `SECURITY.md` points to GitHub's private vulnerability reporting;
    - the bug template asks for the app version and how BatteryPulse was installed (today it asks
      neither, `.github/ISSUE_TEMPLATE/bug_report.yml`), and no template offers iOS
      (`feature_request.yml:17` does today);
    - no user-facing text asks anyone to run `swift run bpulse` (UG:563-661 does today).

### 2.5 What 1.0 does not require

None of these blocks 1.0:
- the History and iPhone & iPad widgets;
- the extra-large Battery widget, if the look check leaves it out (Q-W10);
- Developer ID signing and notarization (not planned: M-1 is no; C16 is the ad-hoc path);
- graduating Translucent or Clear;
- fixtures from other Macs;
- an iPad capture;
- charge limiting;
- per-app energy.

Each is placed in §4 or §5.

---

## 3. The versions from 0.6.2 to 1.0.0

| Version | Theme | Headline | Maintainer M5 time | Runs |
|---|---|---|---|---|
| **0.6.2** | Foundation II (P2, unchanged) | Main actor by default, the read path, Clear's minimize fix, widget headroom, the `diskutil` installer, energy against three builds | Session A about 65 min, then 3 h unattended; Session B about 95 min, plus about 70 min unattended (P2 §6, with the Xcode steps: `xctrace` page switches in both, the contrast audit in B). WP-18's maintainer-run items, about 60 min in a sitting of their own [estimate] | 29-32, plus 3 in reserve (P2 §7.2) |
| **0.7** | Widgets you configure | The configurable Battery widget in small, medium, large (extra large on the look check), plus Accessories; device JSON dates | The look check (about 15 min at the desk, no M5, plus a 3-min second look), Session R (about 80 min), a logged day and its 10-min end, the after-publishing check (about 10 min); plus a 35-min spike sitting if 0.6.2's W0 never ran (plan-0.7.0 §6, §2.3) | 26-29 plus 3 in reserve; never-cut 21-24; stretch +8-9 [estimate, plan-0.7.0 §7.2] |
| **0.8** | Answers in the app | Why it isn't charging, a health summary, explanations, Report a Problem, VoiceOver and the keyboard | A look sitting of about 40 min and a release-candidate sitting of about 85 min, the contrast audit included [estimate] | 29-36 [estimate] |
| **0.9.0** | Ready for others (feature freeze) | Docs, the written promise, the ad-hoc first install documented (C16; no Developer ID, §3.4), `bpulse` in the app | About 50 min, plus up to 60 min for the verification matrix's open M5 rows [estimate] | 8-11, plus whatever 0.8's cut line moves [estimate] |
| **0.9.x** | Release candidates (fixes only) | Soak, energy budgets, the upgrade matrix | About 40 min, plus 70 min unattended and a passive 7-day soak [estimate] | 1-3 each |
| **1.0.0** | The promise | The last 0.9.x, renamed | The after-publishing check, about 10 min | 1-2 |

**Totals [estimate]** (recomputed on 2026-10-22 for the maintainer's answers):
- about 11-13 hours of hands-on time, plus the 5-minute NEW-22 check after each macOS 27.x
  update, unattended windows and a passive soak week. The parts: 0.6.2's sessions, Xcode items
  and check (about 230 min: Sessions A and B with their Xcode steps, 160, WP-18's sitting, 60,
  and the check, 10), 0.7's sittings (about 120 min, plus 35 if W-0S runs), 0.8's (about 135),
  0.9.0's (about 60-120), the 0.9.x sittings (about 50 each, two assumed) and 1.0's check (about
  10). Xcode adds about 90 minutes to 0.6.2 and 10 to 0.8; the Developer ID evening (S-ID) and
  the 30 minutes of secrets (G-ID) are gone with M-1's no;
- about 100-125 implementation and review runs, plus 8-9 if 0.7's stretch runs.

**Calendar [estimate].** It assumes about one maintainer sitting a week, and **these dates are not
gates**. WP-18's Xcode sitting floats (P2 §5), so 0.6.2's date holds; 0.9.0 is about a week
earlier without the Developer ID work:

| Release | Estimated date |
|---|---|
| 0.6.2 | mid-November 2026 |
| 0.7 | mid-December 2026 |
| 0.8 | late January 2027 |
| 0.9.0 | mid-February 2027 |
| 1.0.0 | March 2027 |
| 1.1 (macOS 28) | about two weeks after macOS 28 ships, likely September 2027 [assumed] |

The outer bound for 1.0.0 is WWDC 2027, likely early June [assumed]. After that, 1.0 would be
checked against a macOS beta that keeps changing (D).

**Why five releases, not fewer or more** (V, Q and D agree on this skeleton):
- **0.8 and 0.9 stay apart.** Merging them would put new UI into the release that has to prove
  stability and the update path (V, Q).
- **The freeze sits in 0.9.** The soak must run on the code that ships (Q).
- **0.9.x must be real releases.** Only a published build can prove the in-app path into 1.0:
  the app installs only `releases/latest` and rejects pre-releases (Updates.swift:125, 158) (V).
- **More releases would add M5 sittings without new evidence** (Q).

### 3.1 0.6.2: Foundation II (as P2 plans it; this roadmap changes only where some cut items go)

This roadmap changes nothing in 0.6.2's scope. The maintainer's answers of 2026-10-22 pick P2's
own branches: Clear's fill (b) (Q-B2, so FEA-24 is not built), no Low Power Mode fallback (Q-B10,
so FEA-23 is not built), no Enhanced Security spike (Q-B8), and Xcode on the M5 (Q-B7, so WP-18
and the contrast audit run, maintainer-run with Claude's step-by-step list). The roadmap changes
only where some cut items go: FEA-25 goes after 1.0, and SEC-01 is not planned (Q-B8 and M-1 are
no), instead of P2 §7.2's "a cut item moves to 0.7". A cut WP-18 moves to 0.7 as P2 says, still
maintainer-run. The rest of a cut follows plan-0.7.0's C-1: Linux-only items ride 0.7's
engineering lane, and items that need the M5 join Session R's optional steps.

- **Theme:** the second maintenance and foundation release, with no new features (P2 §1). It
  carries 0.6.1's deferred backlog, fixes the beta styles' last known bug, runs the energy
  measurements 0.6.1 skipped, and lays the groundwork that 0.7's widget needs.
- **Contents, by P2 package:**

  | Package | Inventory rows |
  |---|---|
  | WP-10, first | PLT-01 |
  | WP-13 | QUA-01 (fill (b), Q-B2), QUA-02, QUA-03, FEA-22 (gated), L10N-02; not built: FEA-23 (Q-B10), FEA-24 (Q-B2), FEA-25 (Q-B4: after 1.0, with a graduation) |
  | WP-14a | ENG-08 |
  | WP-14b | ENG-09, ENG-10 (both gated) |
  | WP-15 | SIZ-01, SIZ-02 (gated), SIZ-03, SIZ-04 |
  | WP-16 | PLT-02, SEC-04 (gated), QUA-12, DIS-07 (conditional) |
  | WP-17 | ENG-11, ENG-12 |
  | WP-18 (maintainer-run with Claude's step-by-step list; Xcode is installed, Q-B7) | TCI-05, TCI-06, TCI-07, PLT-03 |
  | WP-19 | SEC-05, QUA-13, TCI-02, TCI-03, TCI-04 |
  | WP-20 (optional) | SEC-02; SEC-01 not run (Q-B8) |
  | WP-W0 | FEA-01 to FEA-05, A11Y-05, L10N-03 |
  | WP-21 | ENG-01 to ENG-06, ENG-13, TCI-01 |
  | WP-22 | DOC-01, DOC-02, DOC-03 |
  | D1-D3 | DIS-08, DOC-04, DOC-05, DOC-06 (evidence), SEC-06 |

  The intake and the sessions:
  - Intake A0: DIS-04.
  - Session A: QUA-09 (if an iPhone is at hand) and QUA-10.
  - Session B and after publishing: L10N-01, DIS-05, DIS-06.
  - Optional checks: QUA-04, QUA-05, QUA-11, A11Y-02, A11Y-04.
  - Session B's contrast audit with Accessibility Inspector: A11Y-03 (Xcode is installed).
  - ENG-18 and TCI-09 are settled as they fall out of the runs.
- **Exit criteria:** P2's own.
  - Every gate of P2 §7.1 is measured or takes its default.
  - The never-cut set of §7.2 has landed.
  - D1's golden, storage and settings diffs are empty except §7.3's intended changes.
  - Session B's F12 passes, or G-16 reverts to `hdiutil`.
  - The notes are as P2 D1 lists them, and D3's after-publishing check passes.
- **M5 sessions:** A, B, the optional steps, WP-18's Xcode sitting and the after-publishing check
  (P2 §6, D3).
- **Size:** 29-32 runs, plus 3 for fixing forward; the never-cut set is 22-26 (P2 §7.2).
- **What the roadmap asks alongside 0.6.2 (answers and optional steps; no change in scope):**
  1. **M-1 is answered: no** (2026-10-22). Nothing about the paid account is asked alongside
     0.6.2, and nothing in 0.6.2 or later waits for it (§3.4).
  2. **Run the optional Charge Limit capture (QUA-05)** with the session script's `charge-limit`
     step (0.6.2's script, or 0.7's W-12). The script asks for the limit set in System Settings →
     Battery [exact menu path unverified on macOS 27] and checks that the charge is at least 5
     points below it, because a capture that starts at or above the limit records nothing. It then
     starts `caffeinate -i bpulse --record` into a new, empty folder under the session's backup
     folder (`~/bp-062/` or `~/bp-070/`; UG:579-583:
     without `caffeinate -i` the recording stops when the Mac sleeps, and the folder must not hold
     an earlier recording) and beeps when charging stops at the limit. Keep the adapter in and the
     lid open: about 2 minutes of setup, then unattended. 0.8's NEW-01 wants it; without it, the
     Charge Limit cause doesn't ship (§3.3). If 0.6.2 misses it, 0.7's Session R offers it (V).
  3. **Q-B8: no** (P2's default; decided by delegation, 2026-10-22). Enhanced Security on an
     ad-hoc signature is unverified, and if AMFI refused the new version after the swap, users
     would be left with an app that doesn't launch (RES-security SEC-08 row; D). It was to be
     retried on a Developer ID build, which M-1's no rules out, so it is not planned (§4.2).
  4. **Q-B7: Xcode is already installed on the M5** (2026-10-22). The 11 inventory rows that need
     it are no longer blocked (INV Summary). In 0.6.2 that means:
     - WP-18 runs, maintainer-run from Claude's step-by-step list: the previews spike (SUI-17),
       the SwiftUI Specialist checklist (SUI-18), type-check timing (SUI-19) and the Icon
       Composer icon (SZ-10). The icon ships only on your y to its screenshots in the four icon
       styles (P2 WP-18's acceptance; decided by delegation).
     - Sessions A and B run their `xctrace` page switches, and Session B the contrast audit with
       Accessibility Inspector (A11Y-03): about 65 and 95 minutes in all (P2 §6). C10 repeats the
       audit in 0.8.
  5. **Branches (settled, an engineering call):** `claude/baseline-0.6.0` stays until 0.6.2's D3;
     the 0.6.1 integration history stays reachable as `refs/pull/11/head`, which GitHub keeps.
  6. **A step of 0.6.2's D3:** `main` gets only squash merges, so `docs/plans/` never enters its
     history. Before `claude/062-*` is deleted, D3 copies `m5-session.sh`, its swap helper and the
     whole of Appendix C into `docs/plans/0.7.0/`, beside `widgets.md`; the release PR's
     `refs/pull/<n>/head` keeps them reachable either way (plan-0.7.0 D-1).
  7. **A second step of 0.6.2's D3, and of every later release (NEW-23):** a week after publishing,
     read the release's DMG and `.sig` download counts from the releases API (`gh api
     repos/NikitaUsov/BatteryPulse/releases --jq '.[] | {tag_name, assets: [.assets[] | {name,
     download_count}]}'`) and record them in ROADMAP's Releases table. 0.6.2's D3 adds the two
     columns (DMG, `.sig`) and fills them for the earlier releases from the same call. The counts
     include the maintainer's own downloads and the release's signature check, so they are an upper
     bound on anyone else. Nothing in the app counts or sends anything (C14 item 8).

### 3.2 0.7: Widgets you configure (P2 §8, §9.1)

- **Theme:** one headline, the configurable widget. "Within a minor release … the storage
  formats, the settings keys and the update contract don't change" (R:437-439). So 0.7 is also
  where the device JSON dates change, together with the JSON version field: scripts change once
  (Q).
- **Before code:**
  - Q-W1 to Q-W13 and Q7-1 to Q7-7 are decided (2026-10-22: Q-W1 by the maintainer, the rest by
    delegation, §5.3).
  - 0.6.2's W0 results (P2 Appendix C) pick the rows of §8.16 that apply.
  - §2 of this roadmap (M-5) awaits the maintainer; it was asked again in plain words on
    2026-10-22. Once approved, or with its recommended answer if still unanswered when 0.7
    starts (§6), it is condensed into ROADMAP as a "Road to 1.0" section in 0.7's docs pass, so
    0.6.2's scope stays as planned.
- **Contents:**
  - **MVP, never cut** (P2 §9.1):
    - FEA-07 (W-1, with P2 §8.13's frozen-value pin test);
    - FEA-08 (W-2);
    - FEA-06 (W-3; extra large only on an explicit yes in the look check, plan-0.7.0 §2.5);
    - ENG-16 (W-4);
    - FEA-09 (W-8, if W0-4 passed);
    - A11Y-06;
    - L10N-04, TCI-11 and DOC-07 (W-10);
    - L10N-05, SIZ-06, TCI-10, ENG-17, QUA-16.
  - **Fallback:** FEA-13, the preset kinds, only if W0-1 failed (P2 §8.16).
  - **For scripts:** QUA-14 (CB-02: ISO 8601 dates) and NEW-11 (`formatVersion` in every top-level
    JSON object `bpulse` prints). One line in the notes covers both.
    - List outputs keep their shape. `--accessories --json` prints a bare array (UG:648-653), and
      wrapping it would break scripts for no gain.
    - Exact shapes are a technical choice made in the run.
  - **Docs riders (no maintainer time):**
    - DOC-09: the iOS promises leave README (the badge, RM:14-15, and the iOS column and footnote
      of "What each platform exposes", RM:192-206) and the issue templates (`bug_report.yml`, and
      `feature_request.yml:17`, which offers iOS), as M-2 decided (not in 1.x).
    - ROADMAP's Decisions follow M-2 and M-3 (R:8-14): "Platforms" becomes "macOS 27 minimum;
      BatteryKit still builds for iOS 27 (PLT-05)"; "Distribution (iOS): undecided" becomes "Not in
      1.x (M-2)"; "Distribution (macOS)" drops "(and later charge limiting)" (M-1's no is
      recorded there already, 2026-10-22). The 0.7 entry (R:543-556), which promises "every size
      macOS offers" and History, iPhone and iPad widgets, is rewritten to what shipped, and the
      rest moves to a new 1.1 entry (plan-0.7.0 §12).
    - DOC-10: the bug template asks for the app version and how BatteryPulse was installed.
    - PLT-05 follows M-2: BatteryKit keeps building for iOS until that first costs time.
    - NEW-18: `docs/VERIFICATION.md` starts with 0.6.2's evidence (plan-0.7.0 R-1 item 5).
  - **Engineering lane:**
    - NEW-13: the backup key, once the maintainer has generated it (M-9).
    - NEW-22: a quick check after every macOS 27.x update starts.
    - P2 §7.2 says 0.6.2 items that get cut move to 0.7. Those that need no M5 time ride in this
      lane (plan-0.7.0 C-1); those that do join 0.7's Session R optional steps or the verification
      matrix. FEA-25, SEC-01 and the Xcode items go as §3.1 says.
  - **Nice-to-have:** FEA-21 (hide fully charged accessories). **P3:** SIZ-07, if measurement
    favours it.
  - **Stretch:** FEA-10, FEA-11, FEA-12, SEC-08 and DOC-08 (W-5 to W-7). They run **only if W0-3
    passed with candidate A or A′.** Q-W3 is yes and M-1 is no (both 2026-10-22), so the feed is
    their only route: there is no App Group without the paid account (P2 §8.2). If W0-3 failed,
    they are not possible without the account (§4.2).

    If they miss 0.7.0, they go to **1.1, not 0.7.x**. P2 §9.1 allows "0.7.x", but the feed is a
    new file on disk and a new entitlement, and the frozen-outputs rule makes those wait for a
    minor release (R:437-439; P2 §9 reason 4). 0.8 and 0.9 keep their own themes.
- **Engineering notes:**
  - Write the feed reader behind one type, so the feed's location or entitlement can change
    without touching the widget's views (D). The feed's path only links the app and the widget of
    the same version, which update together. So moving it in a minor release breaks no placed
    widget (C14 item 2).
  - `WidgetChartSummary` is built with W-6 (stretch). If W-6 doesn't ship, 0.8's A11Y-01 builds it
    in BatteryCore (plan-0.7.0 §2.5).
- **Exit criteria:**
  - **Seen before release:** Session R ran. Without it 0.7 waits and the dates move (plan-0.7.0
    §3, G7-2). This is stricter than §1.2 item 3's "a short session still ships", because the
    headline can't ship unseen (C2).
  - **Session checks (P2 §8.14):**
    - a 0.6.x widget after the in-app update (or the §8.16 row that applies, documented);
    - every kind, family and rendering mode, in English and Russian, at 12- and 24-hour time;
    - the edit sheet, localized;
    - VoiceOver, one element per block;
    - clicks with and without a window.
  - **Reloads (P2 §8.10):**
    - the Battery kind stays within E15's synthetic day plus 7;
    - all kinds stay under about 100 reloads a day;
    - at least 90 % of the requested reloads arrive over a day. Otherwise, and only when
      deliveries are missing entirely rather than delayed, the planner drops the percent-step
      reloads first (plan-0.7.0 G7-11).
  - **Size (P2 §8.12):** the widget's `__text` stays within its ceiling, or the ceiling rises in a
    commit of its own that says why. The `widget_appintents_bytes` row exists.
  - **Release:** the notes carry the CB-02 line, the after-publishing check (0.6.2's D3 list)
    passes, and a week later the download counts are recorded (NEW-23).
- **M5 sessions [estimate]** (plan-0.7.0 §6):
  - the look check at the desk (about 15 minutes, no M5) and a 3-minute second look;
  - Session R, about 80 minutes, with the screenshot matrix scripted;
  - a day of normal use with the `perf` stream on, for reloads delivered and the widget's energy,
    and about 10 minutes at its end (F12);
  - the after-publishing check;
  - QUA-05, if 0.6.2 missed it: the session script's `charge-limit` step (§3.1 item 2);
  - QUA-06: the `hold-watch` step before bed, with the adapter in and the lid open. It records
    overnight under `caffeinate -i` and says in the morning whether a hold was seen. Nobody can
    know in advance which night macOS holds the charge [uncertain: whether macOS holds it while
    the Mac is kept awake].
- **Size [estimate]:** 26-29 runs plus 3 for fixing forward; never-cut 21-24; stretch +8-9
  (plan-0.7.0 §7.2, which also counts D1-D3, the riders and W-3's split).

### 3.3 0.8: Answers in the app

- **Theme:** a non-expert gets four answers inside the app (V), and they work with VoiceOver and
  the keyboard too (Q):
  - Is my battery OK?
  - Why isn't it charging?
  - What does this number mean?
  - How do I report a problem?

  All new strings and looks go through one look review and one Russian review.
- **Contents, user-facing.** M-10 and M-11 set the rules (decided by delegation); each item's look
  is still signed off in 0.8's look sitting.
  - **NEW-01 Why it isn't charging,** shown on Overview and in the menu bar popover.
    - BatteryCore decodes the causes and tests them on Linux:
      - `NotChargingReason`, which is parsed today (MacPowerParser.swift:211) but printed only as
        hex in the text report (BatteryReport.swift:78-79). Bits 12 and 24 are candidates for the
        Charge Limit [unverified, CLR:96];
      - IOPS's optimized-charging hold (R:76-77);
      - the thermal state;
      - an adapter too weak for the load. [uncertain: a heuristic]
    - **A cause shows only when a real fixture proves it.** QUA-05 proves the Charge Limit and
      QUA-06 the optimized hold. Until then, today's state is shown.
    - Each cause gets a Demo Mode scene, so its look can be reviewed without waiting for the real
      state (CLAUDE.md: `DemoBattery` scenes expand into M5-style raw dictionaries).
    - For the Charge Limit and the optimized hold, the line points to System Settings → Battery
      (M-3).
  - **NEW-02 Health summary,** at the top of Health.
    - Facts only: the condition, maximum capacity, and cycles out of the rated count. No grade of
      our own (V, D4).
    - The catalog's placeholders are `%@` only (CLAUDE.md), so the text uses label-value pairs, not
      counted phrases.
  - **NEW-03 Explanations.**
    - Every metric that isn't obvious gets a `.help` or an info popover, in both languages, taken
      from "Understanding the numbers" (UG:530-559).
    - A guard test fails on a metric label without an explanation key (V).
  - **NEW-04 Welcome: the first ten minutes.** One window, with one line and one button each for:
    - where BatteryPulse lives;
    - turning off macOS's battery item;
    - one charge notification;
    - adding the widget;
    - iPhone reading.

    Today the window embeds General settings (WelcomeView.swift:32-34) (V).
  - **NEW-05 Help → Report a Problem…** (V, Q). Nothing is sent: the user previews one redacted
    bundle, saves it, and then the issue chooser opens. The bundle holds:
    - the battery capture;
    - the accessories capture, pseudonymized like `--accessories --raw`;
    - the last device capture, redacted like `--device --raw`;
    - the version, the build, the macOS build and the Mac model;
    - the settings' values;
    - this session's `perf` summary;
    - the names of BatteryPulse's crash reports. Their contents go in only on a second choice,
      with the home folder written as `~`.

    It closes DIS-09's capture half. The guide's "Reporting a problem" (UG:656-663) is rewritten
    around it.
  - **NEW-06 Help at the tag:** the guide link opens the guide at the release's tag (V).
  - No app-wide °F: Q-W12 keeps °C (decided by delegation, §5.3).
- **Contents, accessibility:**
  - **A11Y-01:** chart descriptors through `accessibilityChartDescriptor`. The summaries come from
    BatteryCore: 0.7's `WidgetChartSummary` if W-6 shipped, else built here (about 1 more run).
  - **NEW-07:** VoiceOver for the custom components, which have no accessibility modifiers today
    (`RingGauge`, `PowerFlowView`, `CapacityBars`). Keyboard paths for the sidebar, toolbar, tile
    pickers, Raw Data and the update window (Q).
  - A11Y-02, A11Y-03 (Accessibility Inspector; Xcode is installed) and A11Y-04, if still open.
- **Contents, resilience** (these add strings, so they ride with this release's look review):
  - **NEW-14 Sentinel for the private calls.**
    - A flag is set around each MobileDevice and accessory-symbol call.
    - If the flag is found at launch, that feature pauses with a note and **Turn On Again**.
    - This answers threat A4 (RES-security:111) without SEC-10's helper process (Q).
  - **NEW-16 Update safety,** C8 (D): the `LSMinimumSystemVersion` check and the relaunch
    fallback. SEC-07's swap-renaming check comes with it.
- **Engineering lane (Linux only; no maintainer time):**
  - NEW-08: the frozen-surface tests, and golden outputs committed for every fixture. The goldens
    land after 0.7's CB-02, so they pin the 1.x shapes.
  - NEW-09: storage tests. NEW-10: perturbation and degradation tests. NEW-12: the log-privacy
    guard (23 `.public` sites today, checked by hand).
  - **QUA-15:** remove the legacy `samples.jsonl` migration before 1.x freezes the storage list,
    with one line in the notes. No release ever wrote the file (AUD-cli-build CB-01). PB DC-5
    kept migrations for 0.6.1's "no loss of functionality". Removing this one in a minor release
    that announces it loses no user data. [uncertain: only pre-0.3 development folders had it]
- **Exit criteria:**
  - Each cause shown is pinned by a Linux test against a real fixture; no fixture, no cause.
  - The new guard suites are green.
  - The look review gets a y on every new screen in both languages, from scripted screenshots and
    the Demo Mode scenes.
  - The VoiceOver and keyboard sitting passes C10's script, and so does the contrast audit with
    Accessibility Inspector.
  - F12: the release candidate, built as 0.5.99, installs the published 0.7.x through the new
    update-safety code.
  - A CI test refuses a staged bundle whose `LSMinimumSystemVersion` is 99.0.
  - The after-publishing check passes.
- **M5 sessions [estimate]:**
  - a look sitting of about 40 minutes on a CI build: Demo Mode scenes, the Welcome window, the
    Report a Problem preview;
  - a release-candidate sitting of about 85 minutes: 45 minutes of VoiceOver and keyboard, about
    10 of the contrast audit (C10), plus F12 and the Russian pages;
  - the after-publishing check.
- **Size [estimate]:** 29-36 runs (about 18 packages: NEW-01 to NEW-07, A11Y-01 to A11Y-04,
  NEW-14, NEW-16 with SEC-07, NEW-08 to NEW-10, NEW-12, QUA-15 and D1-D3; app-wide °F left with
  Q-W12's answer). For scale: 0.6.1's 19 packages took 40-46 runs (P1, "At a glance"), and 0.7's
  16 take 26-29 (plan-0.7.0 §7.2).
- **Cut line.**
  - **Never cut:** NEW-01, NEW-02, NEW-03, NEW-05, NEW-07, A11Y-01, NEW-16 with SEC-07, NEW-08 to
    NEW-10, D1-D3.
  - **Cut in this order if the budget runs short:** NEW-06 (→ 0.9.0); NEW-04 (→ 0.9.0, whose
    theme is a newcomer's first minutes); NEW-12 and QUA-15 (→ 0.9.0's engineering lane); NEW-14
    (→ 0.9.0).
  - An item cut to 0.9.0 lands before its freeze, and one with a look joins 0.9.0's screenshot
    sitting. Each is still in 1.0 (C1, C12, C17).

### 3.4 Gate G-ID: off the path to 1.0 (M-1 is no)

**Decided 2026-10-22.** The maintainer declined the paid account (M-1), so gate G-ID, spike S-ID
and the `docs/DEVELOPER_ID.md` runbook leave the path to 1.0. No version, gate, spike or session
depends on them, and 0.9.0 has no Developer ID item. 1.0 ships ad-hoc (C16), with Open Anyway and
the grants or widgets a DMG replacement may lose documented as known limitations (C3, C7).
SEC-02's self-signed identity is the only identity change 0.9.0 weighs (§3.5).

**Background, kept in case the maintainer changes his mind.** It is not scheduled, and nothing
below runs unless M-1 is asked again.

1. **Enroll.** The maintainer would enroll (https://developer.apple.com/programs/enroll/) and
   store the signing certificate and notary credentials as secrets of the `release` environment.
   Claude never asks for or handles them, in line with CLAUDE.md's rule on the private key.
   - **1a. A runbook first.** Before S-ID, Claude would commit `docs/DEVELOPER_ID.md` (English),
     listing every click [menu names unverified on Xcode 27]: create the Developer ID Application
     certificate (Xcode → Settings → Accounts → Manage Certificates → +); export it from Keychain
     Access as a .p12 with a password; create an App Store Connect API key for `notarytool`; add
     each value as a secret of the `release` environment on GitHub (Settings → Environments →
     release). The maintainer does every click. Nothing passes through a chat, an issue or the
     repository. About 30 minutes [estimate], no longer in §3's totals.
2. **Spike S-ID,** one evening on a throwaway branch. It would check:
   - **(a) Notarization accepts the app.** The app opens MobileDevice with `dlopen` and resolves the
     accessory symbol with `dlsym`. Apple says notarization "is not App Review" but an automated
     scan for malicious content
     (https://developer.apple.com/documentation/security/notarizing-macos-software-before-distribution).
     [unverified for this app]
   - **(b) MobileDevice still loads** under library validation with a Team ID. [unverified;
     expected, since the framework is Apple-signed]
   - **(c) The Developer ID build reads the old data.** History and Devices written by the ad-hoc
     build must read with no prompt and no denial. macOS 27 "may" deny access to "files created by
     other developer teams' apps" (NOTES27 178668601). [unverified]
   - **(d) An ad-hoc version installs it in-app.** The installer checks the bundle ID, the version
     and code-signature validity with no requirement (UpdateInstall.swift:163-170,
     UpdateInstaller.swift:522-537), so it should pass. [by reading the code; to confirm]
   - **(e) What survives the swap:** placed widgets, the login item and notification permission
     (R:180-181, R:202-208).
   - **(f) First launch.** `syspolicy_check distribution` and `stapler validate` pass, and on a
     fresh macOS user account the app from the DMG opens without Open Anyway (PKG B25).
3. **Where it would land:** a 1.x minor release of its own, never before NEW-16's safeguards
   ship. The running app's installer performs every update (UpdateInstaller.swift:419 checks the
   staged bundle inside the app being replaced), so the identity switch, the riskiest update the
   app could make, must be installed by a version that already carries NEW-16 (0.8 or later, C8).
   Its notes would have an "Updating from 1.x" list of what to grant again, taken from (e).
4. **If (a) failed:** no Developer ID distribution, because a Developer ID app that isn't notarized
   is still blocked.

### 3.5 0.9.0: Ready for others (feature freeze)

- **Theme:** everything a person who isn't the maintainer meets: installing, the docs, the
  written promise, and how to get help. **The feature freeze starts when 0.9.0 is published.**
  0.9.x carries fixes only (V, Q, D).
- **Contents:**
  - No Developer ID item: M-1 is no (§3.4).
  - SEC-02's self-signed identity, only if its 0.6.2 research and an M5 check show that grants
    survive updates. PKG B14 doubts it [unverified], and if adopted its check joins this
    release's sitting.
  - Whatever 0.8's cut line moved here (§3.3).
  - **DIS-09, second half: `bpulse` inside the app (M-7).**
    - It ships inside the bundle, signed with the app and covered by the posture check and the
      size report. The path inside the bundle is a technical choice.
    - The guide and README replace `swift run bpulse` with that path and an optional `ln -s`
      line (UG:561-663, RM:147-157, RM:248).
    - No Settings row and no admin prompt.
    - [unverified: the size cost, and whether running a helper tool from inside an approved
      bundle prompts anything; the 0.9.0 sitting checks both]
  - **NEW-17 docs** (C17) and **DIS-10**: README's status line (RM:14, "Status: early
    development") becomes "Status: release candidates for 1.0, verified on a MacBook Air M5 with
    macOS 27". The first install is documented for the ad-hoc signature (C16): Open Anyway with
    fresh screenshots, and, under Known limitations, Open Anyway on every DMG install and the
    grants or placed widgets a DMG replacement may lose, with the steps to set them up again (C3,
    C7).
  - **NEW-15:** `SECURITY.md` with M-13's support promise, and the reviewer confirmed.
  - **NEW-18: the verification matrix closed.** These are ticked, or listed as known limitations:
    QUA-04, QUA-09, QUA-10, QUA-11, ENG-07 (its frame rate in Instruments too, Xcode being
    installed), DIS-06 and any A11Y row left.
  - **ROADMAP restructured:** finished stages folded, a "Not planned" section, and the 1.x
    promise.
  - **NEW-20: the Russian screenshot set,** which doubles as the guide's screenshots. This
    answers DOC-06's open question of whether they are published.
  - **FEA-22's final stance (M-8):** a style not signed off stays Beta and outside the promise.
- **Exit criteria:**
  - C2, C3, C11 and C14-C17 are met.
  - A docs check finds no `swift run` in user-facing text.
  - The after-publishing check passes, including 0.8 → 0.9.0 in-app.
- **M5 sessions [estimate]:**
  - about 50 minutes: the scripted screenshot set and the bundled `bpulse` path (the Developer ID
    fresh-account check is gone with M-1's no);
  - up to 60 minutes for the verification matrix's open M5 rows;
  - the after-publishing check.
- **Size [estimate]:** 8-11 runs, without the Developer ID work.

### 3.6 0.9.x: release candidates (fixes only)

- **Every 0.9.x is a normal release, not a GitHub pre-release.** The in-app path into 1.0 can
  only be tested from published builds (§3, "Why five releases"). This overrides Q's idea of
  public pre-releases.
- **The final 0.9.x carries:**
  - C4, the 7-day soak;
  - C5, the energy run alternated with 0.6.2's DMG (S1, S2, S6, S7 and S9, about 70 minutes
    unattended);
  - C6;
  - C7, the upgrade matrix (about 40 minutes);
  - C13.
- **Order and safety.** C7 runs first, from the session script. Before each leg it backs up the
  app, the `io.github.nikitausov.BatteryPulse` defaults domain and `~/Library/Application
  Support/io.github.nikitausov.BatteryPulse` (0.6.2's prepare, P2 §6), and restores them after.
  The 7-day soak (C4) starts only after C7's last restore, and no matrix leg runs during the soak,
  which would break C4's gap and memory counts.
- **A fix restarts the soak** only if it addresses a crash or data loss, or changes code that runs
  during the soak. A fix to docs or strings doesn't.

### 3.7 1.0.0: The promise

- **Contents:**
  - the final 0.9.x's code with the version raised;
  - notes headed `## What's new in 1.0.0` (checked by `release.yml`);
  - the Compatibility section in force;
  - README's status line becomes "Verified on a MacBook Air M5 with macOS 27" (no stage word), and
    the ROADMAP Releases row.
- **Exit criteria:** every criterion of §2 is ticked in the release PR's checklist, and the
  maintainer approves the `release` environment run.
- **After publishing:** 0.6.2's after-publishing check on 0.9.x → 1.0 in-app, with the
  `--prerelease` rollback if it fails, and the download counts a week later (NEW-23).

### 3.8 After 1.0: 1.1 and the cadence

- **1.1:**
  - **macOS 28 compatibility (NEW-21),** within about two weeks of macOS 28's release
    [assumed: September 2027]:
    - the Xcode 28 runner (CI pins Xcode 27.1 today, ci.yml:63);
    - a sweep of deprecations, as `hdiutil` was in macOS 27 (R:524-525);
    - captures on the new macOS.
  - The widgets that waited: FEA-10 to FEA-12, SEC-08 and DOC-08, on the feed if W0-3 passed
    (there is no App Group: M-1 is no); also FEA-20.
- **Cadence (M-12, decided by delegation):**
  - at most a minor release every 6-8 weeks, with one M5 sitting;
  - patches only for regressions;
  - one compatibility release per macOS major version (D).

  With about no outside users (§1.1), 6-8 weeks is an upper pace, not a commitment: a minor
  release ships when there is something worth shipping, and the recorded download counts
  (NEW-23) show whether that changes.

---

## 4. After 1.0, not planned, and rejected

### 4.1 After 1.0 (1.x minor releases that only add)

| Item | When and on what condition | Why not before 1.0 |
|---|---|---|
| History and iPhone & iPad widgets (FEA-10, FEA-11, FEA-12, SEC-08, DOC-08), if they miss 0.7.0 | 1.1, on the feed, only if W0-3 passed (Q-W3 is yes). If W0-3 failed, they are not possible without the paid account (§4.2) | They rest on an unverified temporary exception (W0-3). M-1 is no, so there is no App Group, the documented route (P2 §8.2, §8.3) |
| "Why it isn't charging" as a widget field (FEA-20) | 1.1, once NEW-01's causes are proven | Keeps 0.8 off the widget |
| Widget extras: Refresh (FEA-15), extra-large portrait (FEA-16), the dashboard (FEA-17), per-row links (FEA-18), specific accessories (FEA-19) | Specific accessories later (Q-W2). The others only if the maintainer asks: the delegated answers to Q-W8 to Q-W10 (2026-10-22) build none of them | P2 §9.1 "Later"; scope (V, Q) |
| Apps using the most energy (FEA-26) | a one-day spike on the M5 first | The private coalition calls are unproven without root on macOS 27 (R:576-584) |
| MobileDevice in a helper process (SEC-03) | on evidence of a hang or crash | None seen so far (P1 §8 Q1); NEW-14 covers 1.0 |
| Glass-sheet chart lines and Raw Data treatment (FEA-25), not in 0.6.2 (Q-B4) | with a beta style's graduation | Needs the maintainer's look call (Q-B4) |
| The glossary as data, more glossary work, other Macs' captures (SIZ-05, QUA-07) | ongoing, from contributors | Hardware not at hand (R:149-150) |
| Private-API contingencies (PLT-04) | on breakage | They answer a failure that hasn't happened (R:603-605, R:664-667) |

### 4.2 Not planned (the maintainer's stance, with the case for or against revisiting)

| Item | Stance | Reasons |
|---|---|---|
| **Developer ID signing and notarization** (DIS-01) | **Not planned: the maintainer declined the paid account on 2026-10-22 (M-1).** Revisited only if he changes his mind (§3.4 keeps the gate as background) | His reasons: a non-commercial hobby project, no budget for the account, and about zero users (§1.1). The case that was weighed, kept on record: every new user and every DMG install meets Open Anyway (RM:22-25, UG:33-43); Apple keeps tightening this path, and macOS 15 removed the Control-click override (https://developer.apple.com/news/?id=saqachfa); an App Group is the documented route for the History and device widgets (P2 §8.2); grants survive updates under a Team-pinned designated requirement (TN3127, https://developer.apple.com/documentation/technotes/tn3127-inside-code-signing-requirements; PKG B12); it costs 99 USD a year (R:642). At 1.0, Open Anyway and the grants or widgets a DMG replacement may lose are documented known limitations (C3, C7, C16). |
| **Enhanced Security** (SEC-01) | Not planned (Q-B8 no, M-1 no) | It was to be tried on a Developer ID build, which won't exist. On ad-hoc signing it is unverified, and a refusal after the swap leaves an app that doesn't launch (RES-security SEC-08). |
| **The main macOS package manager's official catalog** (DIS-03) | Not planned (M-1 no) | It needs notarization, and a notability bar of 75 stars, 30 forks and 30 watchers and a repository at least 30 days old (PKG B7); all three are 0 today (`gh api`) |
| **The History and iPhone & iPad widgets, if W0-3 fails** (FEA-10 to FEA-12) | Not possible without the paid account | If neither candidate A nor A′ works, the app's copy of the readings has no route into the sandboxed widget, and the App Group needs a Team ID (P2 §8.2, §8.3 candidate C) |
| **An iOS app** (FEA-29 to FEA-34, DIS-02) | Not in 1.x (M-2, decided by delegation) | Public iOS APIs give only the level and the state; the analytics file's format is unchecked (R:79-81). Free-team installs expire after 7 days and work on at most 3 devices (ICL #6). The Mac already reads iPhone health (R:594-637). |
| **iCloud: the Mac's battery on the iPhone** (FEA-28) | Not planned (M-1 and M-2 are no) | Needs the paid account and an iOS app (R:645-651), and M-1 and M-2 are both no |
| **Charge limiting** (FEA-27) | Not in 1.x (M-3, decided by delegation) | 1.x's promise is read-only (CLAUDE.md: the SMC is read-only; P2 §8.4: "the app changes nothing on the system"). The 80-100 % setter is a private client (R:677-684). macOS already offers the setting. The paid account wouldn't change this (CLR:105-109). |
| Options the 2026-10-22 answers didn't take: a 0.6.3 with static large sizes (FEA-14), Clear's desktop-following fill (FEA-24), a Low Power Mode fallback for the beta styles (FEA-23), app-wide °F | Not taken | Q-W1: 0.7 and Q-B2: fill (b), both the maintainer's; Q-B10: no fallback and Q-W12: °C, both by delegation (§5.3) |
| App Nap's effect (ENG-14); Instruments profiling (ENG-15's Instruments half) | Close as not planned at 0.9.0 | C6 measures the targets without Instruments. ENG-13 covers how often the mAh values change. |
| iPad capture (QUA-08) | Known limitation | No iPad at hand (R:620-621) |
| K-02's CI half (TCI-08) | Not planned | P2 App A |
| A public beta channel | No (M-4, decided by delegation) | There are about no outside users to test it (§1.1). 0.9.x must be normal releases anyway. A beta channel changes the update contract (Updates.swift:125). |

### 4.3 Rejected, and staying rejected

**REJ-01 to REJ-62 stay rejected** (INV §13). Some of their "revisit only if" conditions can
come true on the way to 1.0. Each is re-judged here:

| ID | Condition | Verdict on the path to 1.0 |
|---|---|---|
| REJ-01 | Parsing above 1 ms on the M5 | It is 0.153 ms (P2 §2.1). Still rejected. |
| REJ-04 | A release redesigns the icon | 0.7's W-3 moves the drawn-battery painter but keeps `BatteryIconLayout`, with a Linux test on the layout (P2 §8.5, §8.14). That is a move, not a redesign. Still rejected, unless W-3's move needs it (a technical choice). |
| REJ-06 | The file is next changed substantively | 0.7's W-1 changes `BatteryPresentation.swift`. **The condition is met:** W-1 moves the widget types out unchanged, in a commit of their own before its new code (plan-0.7.0 W-1 item 1). |
| REJ-17 | The next real parser change | NEW-01 decodes `NotChargingReason` in BatteryCore and doesn't touch `--smc`. Still rejected. |
| REJ-26 | The SDK gains `MainActorMessage` types | Checked again in 1.1's SDK sweep |
| REJ-34 | Only for the periodic part | Unchanged |
| REJ-36 | MetricKit as an off-by-default local option | NEW-05 covers diagnostics without it. Still rejected. |
| REJ-44 | A later key rotation | Adding a backup key (NEW-13) is not a rotation. Still rejected. |
| REJ-47 | App Sandbox: Developer ID or App Store plans | M-1 is no, so the condition isn't met. Still rejected; the sandbox would break SMC reads, usbmuxd and Install and Relaunch anyway (RES-security §5). |
| REJ-49 | A shared framework: Developer ID, if duplication stays large | M-1 is no, so the condition isn't met. Still rejected. |
| REJ-52 | Selection glass only with a pixel test | Unchanged; the accent outline stays |
| REJ-53 | The app writing into the widget's container | M-1 is no, so there is no Team ID, and macOS 27 denies another or an absent Team ID's access by default (NOTES27 161835690; INV REJ-53). Still rejected. |
| REJ-57 | Widget push needs the paid account | M-1 is no, so push stays impossible. Still rejected anyway: no network in the widget, and the read-only local promise (C14 item 8) |

Every other REJ row is unchanged (§5.4 lists them all).

**New rejections from this roadmap** (never, or not in 1.x):

| Idea | Reason |
|---|---|
| The Mac App Store | Guideline 2.4.5(i) requires the sandbox and 2.5.1 public APIs only (https://developer.apple.com/app-store/review/guidelines/). Both break the SMC reads, MobileDevice and Install and Relaunch (RES-security §5). |
| Telemetry, uploaded crash reports, analytics | The guide promises that the update check is the only internet request (UG:502-507). NEW-05 saves locally and sends nothing. |
| A personal package catalog | Every install and every upgrade would still need Open Anyway (PKG B12-B13) |
| A separate website or domain | README is the landing page (D) |
| Charge control below 80 %, forced discharge, the charging LED | They need a root helper and SMC writes, and CLAUDE.md keeps the SMC read-only (CLR:99-103; R:682-683) |
| Intel Macs; macOS before 27 within 1.x | R:8-9; C14 item 7 |
| Grades or scores of our own for battery health | Facts only (M-10). A grade becomes a look to freeze and a support question. |
| A Settings row with an admin prompt to install `bpulse` into a system folder | The app never asks for admin rights (V). The guide shows an optional `ln -s` instead. |

---

## 5. Every inventory item placed

"0.6.2" means as P2 places it. The other versions are this roadmap's. Each row's note gives the
condition or the reason.

### 5.1 The 130 inventory rows

| ID | Item (short) | Placed | Note |
|---|---|---|---|
| FEA-01 | W0-1 App Intents metadata spike | 0.6.2 | WP-W0 |
| FEA-02 | W0-2 placed widgets survive configurable kind | 0.6.2 | WP-W0, Session A |
| FEA-03 | W0-3 sandbox reads the app's file | 0.6.2 | WP-W0 |
| FEA-04 | W0-4 accessories from sandbox; modes; clicks | 0.6.2 | WP-W0 |
| FEA-05 | W0-6 self-updating time left | 0.6.2 | WP-W0 |
| FEA-06 | W-3 configurable Battery widget | 0.7 | MVP, never cut |
| FEA-07 | W-1 widget model in BatteryCore | 0.7 | MVP, with the frozen-value pin test |
| FEA-08 | W-2 App Intents metadata step | 0.7 | MVP |
| FEA-09 | W-8 Accessories widget | 0.7 | MVP if W0-4 passed; else 1.1 through the feed, only if W0-3 passed |
| FEA-10 | W-5 widget data feed | 0.7 stretch, else 1.1 | Only if W0-3 passed (Q-W3 is yes and M-1 is no, both 2026-10-22); if it misses 0.7.0, 1.1 on the feed; if W0-3 failed, not possible without the account (§4.2) |
| FEA-11 | W-6 History widget | 0.7 stretch, else 1.1 | As FEA-10 |
| FEA-12 | W-7 iPhone & iPad widget | 0.7 stretch, else 1.1 | As FEA-10 |
| FEA-13 | Preset kinds (fallback) | 0.7, conditional | Only if W0-1 failed (Q-W2: no presets otherwise) |
| FEA-14 | 0.6.3 static large sizes | Not planned | Q-W1: 0.7, no 0.6.3 (the maintainer, 2026-10-22) |
| FEA-15 | Widget Refresh button | After 1.0 | Only if asked: Q-W9 builds no Refresh button (delegation) |
| FEA-16 | Extra-large portrait | After 1.0 | Only if asked: Q-W10 takes no portrait size (delegation) |
| FEA-17 | Extra-large dashboard | After 1.0 | Only if asked: Q-W10 makes extra large a bigger Battery (delegation) |
| FEA-18 | Per-row widget links | After 1.0 | Only if asked: Q-W8 opens the widget's page (delegation) |
| FEA-19 | Choose specific accessories | After 1.0 | Q-W2: later (delegation) |
| FEA-20 | "Why it isn't charging" widget field | After 1.0 (1.1) | The app shows it in 0.8 (NEW-01) |
| FEA-21 | Hide fully charged accessories | 0.7 | Nice-to-have |
| FEA-22 | Graduate Translucent/Clear | 0.6.2 (gated) | Final stance at 0.9.0 (M-8) |
| FEA-23 | Low Power Mode fallback for beta styles | Not planned | Q-B10: no fallback (delegation, 2026-10-22) |
| FEA-24 | Clear's desktop-following fill | Not planned | Q-B2 chose fill (b) (the maintainer, 2026-10-22) |
| FEA-25 | Glass-sheet chart lines, Raw Data treatment | After 1.0 | Not in 0.6.2 (Q-B4, by delegation); with a beta style's graduation |
| FEA-26 | Apps using the most energy | After 1.0 | A spike first (§4.1) |
| FEA-27 | Charge limiting | Not planned | Not in 1.x (M-3) |
| FEA-28 | Mac battery on iPhone via iCloud | Not planned | Paid account plus an iOS app |
| FEA-29 | iOS app target | Not planned | M-2 |
| FEA-30 | iOS charge/state screen | Not planned | M-2 |
| FEA-31 | iOS charging session | Not planned | M-2 |
| FEA-32 | iOS analytics import | Not planned | M-2 |
| FEA-33 | iOS widget | Not planned | M-2 |
| FEA-34 | iOS Live Activity | Not planned | M-2 |
| QUA-01 | Clear black minimize frame | 0.6.2 | P1; fill (b), the graphite composite (Q-B2) |
| QUA-02 | Clear tile preview selected/unselected | 0.6.2 | P1 |
| QUA-03 | Beta styles graduation evidence | 0.6.2 | What it misses: 0.9.0 matrix, or a known limitation (beta) |
| QUA-04 | Menu bar icon styles signed off | 0.6.2 (optional) | Else the 0.9.0 matrix |
| QUA-05 | Charge Limit stop-point capture | 0.6.2 (optional) | Wanted before 0.8's freeze. Without it, NEW-01 ships without the Charge Limit cause (no fixture, no cause, §3.3). 0.7's Session R offers it as an optional step |
| QUA-06 | Optimized charging hold capture | 0.7-0.8 (opportunistic) | Gates NEW-01's optimized-hold cause; without it, that cause waits until after 1.0 |
| QUA-07 | Glossary keys, M1-M4 captures | After 1.0 | Ongoing; not a gate (C17's honest claim) |
| QUA-08 | iPad capture, `ManufactureDate` | Not planned | Hardware; listed as a known limitation |
| QUA-09 | iPhone/iPad in packaged app | 0.6.2 (if at hand) | Else the 0.9.0 matrix |
| QUA-10 | Accessories on macOS 27 | 0.6.2 | Session A |
| QUA-11 | Exported CSV in spreadsheet apps | 0.6.2 (optional) | Else the 0.9.0 matrix |
| QUA-12 | E10 Check Now cancels automatic check | 0.6.2 | P3 |
| QUA-13 | SUI-09 `@State` initialized once | 0.6.2 | P3 |
| QUA-14 | CB-02 device JSON dates ISO 8601 | 0.7 | With NEW-11 |
| QUA-15 | Remove legacy `samples.jsonl` migration | 0.8 | Engineering lane; a line in the notes |
| QUA-16 | 0.7's own M5 session | 0.7 | |
| ENG-01 | Menu bar energy vs 0.6.0/0.6.1/RC | 0.6.2 | Becomes C5's budgets |
| ENG-02 | Launch to `menuBarReady` | 0.6.2 | Becomes C5's budget |
| ENG-03 | Energy per window style | 0.6.2 | |
| ENG-04 | Burst, covered window, memory | 0.6.2 | |
| ENG-05 | Devices and accessories energy | 0.6.2 (if at hand) | Else the final 0.9.x energy run (C5) |
| ENG-06 | Sleep hygiene | 0.6.2 | Assertions always; overnight optional; C4's soak covers nights |
| ENG-07 | Stage 1.4 motion and energy check | 0.9.0 (matrix) | Frame rate in Instruments too: Xcode is installed (Q-B7) |
| ENG-08 | E20 reads off main actor | 0.6.2 | P1 |
| ENG-09 | E4b registry when changed | 0.6.2 (gated) | |
| ENG-10 | E3b drop `timeremaining` | 0.6.2 (gated) | |
| ENG-11 | Page responsiveness | 0.6.2 | P2 |
| ENG-12 | History riders | 0.6.2 | P2 |
| ENG-13 | mAh change cadence | 0.6.2 | |
| ENG-14 | App Nap and the minute timer | Not planned | Closed at 0.9.0 |
| ENG-15 | Profile against resource targets | 0.9.x (C6) | Measured without Instruments; the Instruments half is not planned |
| ENG-16 | W-4 widget reload planner | 0.7 | MVP |
| ENG-17 | Widget reloads and energy measured | 0.7 | |
| ENG-18 | Unconfirmed runtime facts | 0.6.2 (as they fall out) | Whatever is left: not planned |
| SEC-01 | Enhanced Security spike | Not planned | Q-B8 is no, and the Developer ID build it waited for won't exist (M-1 is no) |
| SEC-02 | SEC-18 self-signed identity | 0.6.2 (research) | M-1 is no, so it is weighed in 0.9.0: adopted only if grants survive |
| SEC-03 | SEC-10 MobileDevice helper | After 1.0 | On evidence; NEW-14 covers 1.0 |
| SEC-04 | SEC-15 skip image verification | 0.6.2 (gated) | |
| SEC-05 | SW-13 strict memory safety | 0.6.2 | P2 |
| SEC-06 | No prompt for own data after update | 0.6.2 | Repeated in every after-publishing check, and if SEC-02 changes the identity |
| SEC-07 | Swap-renaming capability check | 0.8 | With NEW-16 |
| SEC-08 | Widget feed hardening | 0.7 (with W-5), else 1.1 | Follows FEA-10 |
| SIZ-01 | K-03 `BatterySource` target | 0.6.2 | P1 |
| SIZ-02 | `-internalize-at-link` | 0.6.2 (gated) | |
| SIZ-03 | LTO, `-dead_strip_dylibs` | 0.6.2 | P3 |
| SIZ-04 | Widget ceilings lowered | 0.6.2 | |
| SIZ-05 | Glossary table as data | After 1.0 | Only with glossary work |
| SIZ-06 | 0.7 widget size budget | 0.7 | |
| SIZ-07 | Widget-only string table | 0.7 (P3) | Measurement decides |
| DIS-01 | Developer ID and notarization | Not planned | M-1 is no (2026-10-22); G-ID and S-ID are off the path (§3.4, kept as background) |
| DIS-02 | iOS distribution | Not planned | M-2 |
| DIS-03 | A package manager | Not planned | Needs notarization (M-1 is no) and the notability bar (§4.2) |
| DIS-04 | 0.6.1 after-publishing checks | 0.6.2 | Intake A0 |
| DIS-05 | Tick install from the app | 0.6.2 | |
| DIS-06 | Widgets kept across in-app update | 0.6.2 (evidence) | Re-checked in 0.7 and C7; a loss is a documented known limitation at 1.0 (C3) |
| DIS-07 | Open at login survives update | 0.6.2 (conditional) | |
| DIS-08 | 0.6.2 freeze, Session B, release | 0.6.2 | |
| DIS-09 | Ship `bpulse` to users | 0.8 + 0.9.0 | Captures in Report a Problem (0.8); `bpulse` in the app (0.9.0, M-7) |
| DIS-10 | What 1.0 means | This roadmap | M-5 awaits the maintainer (re-asked 2026-10-22); README's status in 0.9.0 |
| DOC-01 | CLAUDE.md for 0.6.2 | 0.6.2 | |
| DOC-02 | User Guide for 0.6.2 | 0.6.2 | |
| DOC-03 | Roadmap for 0.6.2 | 0.6.2 | |
| DOC-04 | 0.6.2 release notes | 0.6.2 | |
| DOC-05 | Plan files | 0.6.2 | |
| DOC-06 | Window-style screenshots | 0.6.2 (evidence) | Publication decided in 0.9.0 (NEW-20) |
| DOC-07 | Widget docs | 0.7 | |
| DOC-08 | Privacy text for the feed | 0.7 (with W-5), else 1.1 | Follows FEA-10 |
| DOC-09 | iOS promises in README | 0.7 | Docs pass; M-2: not in 1.x |
| DOC-10 | Bug template asks app version | 0.7 | Docs pass; also asks how BatteryPulse was installed |
| TCI-01 | 0.6.2 session script | 0.6.2 | |
| TCI-02 | CI pins | 0.6.2 | |
| TCI-03 | DocC check | 0.6.2 | P3 |
| TCI-04 | Parser instruction budget | 0.6.2 | P3 |
| TCI-05 | Previews in SwiftPM target | 0.6.2 (maintainer-run) | WP-18, from Claude's step-by-step list (Xcode is installed, Q-B7); if 0.6.2 cuts WP-18, 0.7, still maintainer-run |
| TCI-06 | SwiftUI Specialist checklist | 0.6.2 (maintainer-run) | As TCI-05 |
| TCI-07 | Type-check timing | 0.6.2 (maintainer-run) | As TCI-05 |
| TCI-08 | K-02's CI half | Not planned | |
| TCI-09 | Unconfirmed toolchain facts | 0.6.2 (as they fall out) | Whatever is left: not planned |
| TCI-10 | Widget render previews in CI | 0.7 | |
| TCI-11 | Widget guard rules | 0.7 | |
| PLT-01 | Main actor by default | 0.6.2 | First |
| PLT-02 | Installer on `diskutil` | 0.6.2 | |
| PLT-03 | Icon Composer icon | 0.6.2 (maintainer-run) | As TCI-05; ships only on your y to its screenshots in the four icon styles (Q-B7) |
| PLT-04 | Private-API contingencies | After 1.0 | On breakage |
| PLT-05 | iOS code kept building | 0.7 (decision) | M-2: kept until it first costs time |
| A11Y-01 | Chart descriptors | 0.8 | Moved from not planned: C10 needs it |
| A11Y-02 | Stage 1.4 accessibility pass | 0.6.2 (optional) | Else 0.8's sitting |
| A11Y-03 | Contrast audit | 0.6.2 (Session B) | Xcode is installed (Q-B7); repeated for C10 in 0.8's sitting |
| A11Y-04 | Menu bar icons under Increase Contrast, notch | 0.6.2 (optional) | Else 0.8's sitting |
| A11Y-05 | W0-5 VoiceOver on today's widget | 0.6.2 | |
| A11Y-06 | Widget accessibility | 0.7 | MVP |
| L10N-01 | F9 Russian pages | 0.6.2 | |
| L10N-02 | Strings for a graduated style | 0.6.2 (conditional) | |
| L10N-03 | Widget in Russian (method) | 0.6.2 | |
| L10N-04 | W-10 widget localization | 0.7 | MVP |
| L10N-05 | Unit symbols in the widget | 0.7 | |

### 5.2 Items this roadmap adds

| ID | Item | From | Placed |
|---|---|---|---|
| NEW-01 | Why it isn't charging, on Overview and in the popover, with causes proven by fixtures and a Demo Mode scene per cause | V | 0.8 |
| NEW-02 | Health summary: facts only, label-value pairs | V | 0.8 |
| NEW-03 | In-app explanations of the numbers, plus a guard test | V | 0.8 |
| NEW-04 | Welcome: the first ten minutes | V | 0.8 |
| NEW-05 | Help → Report a Problem…: a previewed, redacted bundle; nothing sent | V, Q, INV DIS-09 | 0.8 |
| NEW-06 | Help opens the guide at the release's tag | V | 0.8 |
| NEW-07 | VoiceOver for the custom components; keyboard paths | Q | 0.8 |
| NEW-08 | Frozen-surface tests, and committed golden outputs on Linux and macOS | Q | 0.8 |
| NEW-09 | Storage forward-compatibility tests | Q | 0.8 |
| NEW-10 | Parser perturbation and private-source degradation tests | Q, D | 0.8 |
| NEW-11 | `formatVersion` in `bpulse`'s top-level JSON objects | Q | 0.7 |
| NEW-12 | Log-privacy guard | Q | 0.8 |
| NEW-13 | Backup release key (the public half only) | Q, D | 0.7 (else 0.8) |
| NEW-14 | Sentinel around the private calls | Q | 0.8 |
| NEW-15 | `SECURITY.md`, and the reviewer confirmed | Q | 0.9.0 |
| NEW-16 | Update safety: the `LSMinimumSystemVersion` check and the relaunch fallback | D | 0.8 |
| NEW-17 | 1.0 docs: README as the landing page, Compatibility, Uninstall, Troubleshooting, files and requests | V, Q, D | 0.9.0 |
| NEW-18 | Verification matrix | V, Q, D | Built up from 0.7; closed in 0.9.0 |
| NEW-19 | Soak, energy budgets and the upgrade matrix (C4, C5, C7) | Q, D | 0.9.x |
| NEW-20 | Russian screenshot sign-off; optional double-length pseudolanguage pass [unverified: the launch argument on macOS 27] | Q | 0.9.0 |
| NEW-21 | macOS 28 compatibility | D | 1.1 |
| NEW-22 | A quick check after each macOS 27.x update: Devices, Accessories, Raw Data, widget (about 5 minutes) | V | Ongoing from 0.7 |
| NEW-23 | Each release's DMG and `.sig` download counts from the releases API, recorded in ROADMAP's Releases table a week after publishing; no telemetry in the app | the maintainer's question about downloads (2026-10-22) | From 0.6.2's D3, then every release |

### 5.3 The 22 maintainer questions of P2 §10

All are decided as of 2026-10-22. The maintainer answered Q-B2, Q-B7 and Q-W1, and Q-W3 follows from
his M-1 answer; Q-B9 and Q-B11 were settled before; he delegated the rest ("do it by best practices,
as you see fit"), so each is decided as its recommendation. A look a question leads to is still
signed off in its sitting.

| ID | Decided | Decision |
|---|---|---|
| Q-B2 | the maintainer, 2026-10-22 | Fill (b), the graphite composite (= P2's default, G-13a). FEA-24 is not built |
| Q-B4 | by delegation | Both styles stay beta until you sign one off in Session B (= P2's default, G-13b) |
| Q-B5 | by delegation | Release notes only; What's New stays at 0.6.0 (= P2's default, D3) |
| Q-B6 | by delegation | The sessions as written, every energy scenario as planned |
| Q-B9 | settled | GitHub's rate limit behind a VPN, seen in the session; Session B checks the remaining requests before F12 |
| Q-B10 | by delegation | No Low Power Mode fallback (= P2's default, G-13c). FEA-23 is not built |
| Q-B7 | the maintainer, 2026-10-22 | Xcode is already installed on the M5. WP-18 and the contrast audits run, maintainer-run from Claude's step-by-step list (§3.1 item 4). The Icon Composer icon ships only on your y to its screenshots (by delegation) |
| Q-B8 | by delegation | No (= P2's default; §3.1). Enhanced Security is not planned (§4.2) |
| Q-B11 | settled | An engineering call, not the maintainer's: `claude/baseline-0.6.0` kept until 0.6.2's D3; 0.6.1's integration history kept as `refs/pull/11/head` |
| Q-W1 | the maintainer, 2026-10-22 | 0.7; no 0.6.3 (FEA-14 not planned) |
| Q-W2, Q-W4, Q-W5, Q-W6, Q-W7, Q-W13 | by delegation | plan-0.7.0 §14's recommendations: Battery and Accessories in 0.7, History and iPhone & iPad on the feed with the 90-day trend, no presets unless configuration fails, specific accessories later; the number with the level symbol by default, a ring and a drawn battery offered, level colours; clock time by default, time left offered if W0-6 passed; "Updated" only when old, Always offered; battery power offered with its update time; the attention row on |
| Q-W11 | by delegation | The device name, with `.privacySensitive()` (only W-7 shows names) |
| Q-W3 | following the maintainer's M-1 answer, 2026-10-22 | Yes: BatteryPulse keeps a small copy of recent readings for the widgets (the feed), if W0-3 passes. If it fails, the History and iPhone & iPad widgets aren't possible without the account (§4.2) |
| Q-W10, extra large's layout | by delegation | Two panels (Battery and Power) in 0.7, if you approve it in the look check; otherwise extra large is left out of 0.7 (plan-0.7.0 §14) |
| Q-W8, Q-W9; Q-W10, the dashboard and the portrait size | by delegation | A click anywhere opens the widget's page; no Refresh button; no dashboard; no portrait size. Their items (FEA-15 to FEA-18) return only if asked (§4.1) |
| Q-W12 | by delegation | °C everywhere (0.7's recommendation); no app-wide °F (§3.3) |

plan-0.7.0 §14's own questions are decided the same way, by delegation, as recommended: Q7-1 the
gallery names as written; Q7-2 What's New once after updating to 0.7; Q7-3 the sittings as
planned; Q7-4 the evidence decides what happens if placed widgets don't survive; Q7-5 "Hide fully
charged" offered, off by default (FEA-21); Q7-6 a click opens the main window at the widget's page;
Q7-7 in small, Custom's one detail takes the time line's place. Q7-8 was settled (an engineering
call).

### 5.4 The 62 rejected ideas of INV §13

| IDs | Placed |
|---|---|
| REJ-01, REJ-04, REJ-06, REJ-17, REJ-26, REJ-34, REJ-36, REJ-44, REJ-47, REJ-49, REJ-52, REJ-53, REJ-57 | Rejected; re-judged in §4.3 (REJ-06's condition is met in 0.7 and its move is allowed) |
| REJ-02, REJ-03, REJ-05, REJ-07, REJ-08, REJ-09, REJ-10, REJ-11, REJ-12, REJ-13, REJ-14, REJ-15, REJ-16, REJ-18, REJ-19, REJ-20 | Rejected, unchanged |
| REJ-21, REJ-22, REJ-23, REJ-24, REJ-25, REJ-27, REJ-28, REJ-29, REJ-30, REJ-31, REJ-32, REJ-33, REJ-35, REJ-37, REJ-38, REJ-39 | Rejected, unchanged |
| REJ-40, REJ-41, REJ-42, REJ-43, REJ-45, REJ-46, REJ-48, REJ-50, REJ-51, REJ-54, REJ-55, REJ-56, REJ-58, REJ-59, REJ-60, REJ-61, REJ-62 | Rejected, unchanged |

---

## 6. Decisions only the maintainer makes

Each decision has a recommended answer and what changes with a different one. "Needed by" is the
latest point that keeps the plan intact. Without an answer by "Needed by", the recommended answer
applies. P2 §10's 22 questions are recorded in §5.3.

**Status on 2026-10-22.** The maintainer answered M-1 (no) and delegated M-2 to M-4 and M-6 to
M-14 ("do it by best practices, as you see fit"), so each of those is decided as its recommended
answer. Only M-5 is open: it was asked again in plain words and awaits the maintainer.

### M-1. Buy the paid Apple Developer Program account?

- **Decided 2026-10-22: no.** Not now, and not planned before 1.0. The maintainer's reasons: a
  non-commercial hobby project, no budget for the account, and about zero users (§1.1: 14 DMG
  downloads across all releases, 5 signature downloads, 2 repository views by 1 visitor in 14
  days, no stars, forks or outside issues).
- **What follows:**
  - Developer ID signing and notarization are not planned (§4.2). Gate G-ID, spike S-ID and the
    `docs/DEVELOPER_ID.md` runbook leave the path to 1.0; 0.9.0 has no Developer ID item (§3.4).
  - 1.0 ships ad-hoc. README and the guide teach Open Anyway with screenshots (C16), and the
    guide's Known limitations say that every install from the DMG meets it.
  - No App Group: the History and iPhone & iPad widgets exist only through the feed (W0-3, with
    Q-W3 yes), in 0.7's stretch or in 1.1, or not at all if W0-3 fails.
  - Permissions and placed widgets may need setting up again after a DMG replaces the app
    (UG:493-495): a documented known limitation at 1.0 (C3, C7).
  - SEC-02's self-signed identity is weighed in 0.9.0.
  - Enhanced Security (SEC-01) and the package manager's official catalog (DIS-03) are not
    planned: both needed a notarized, Developer ID build.
  - It doesn't change charge control (CLR:105-109).
- **Revisited only if the maintainer changes his mind.** The case that was weighed, kept as
  background:
  - Every new user, and everyone who installs from a downloaded DMG, meets Open Anyway
    (RM:22-25, UG:33-43).
  - Apple tightens this path over time. macOS 15 removed the Control-click override
    (https://developer.apple.com/news/?id=saqachfa). macOS 27 denies access to other teams' data
    containers and app group containers by default (NOTES27 161835690).
  - An App Group gives the History and iPhone & iPad widgets a documented route (P2 §8.2).
  - Permissions survive updates, because the designated requirement is pinned to the Team ID
    (TN3127; PKG B12; R:180-181).
  - It opens the package manager's official catalog later (PKG B25).
  - **Cost:** 99 USD a year (R:642), and Apple checks your legal identity
    (https://developer.apple.com/programs/enroll/); your legal name probably appears as the
    developer's name. [from memory, unverified]
  - **Unverified:** whether enrollment works with your region and payment method, and whether
    notarization accepts the private `dlopen`/`dlsym` calls (S-ID a).

### M-2. An iOS app?

- **Needed by:** 0.7's docs pass.
- **Decided by delegation (2026-10-22), as recommended: not in 1.x.**
  - 0.7 removes the iOS promises from README (RM:5, RM:14-15, and the iOS column and footnote of
    "What each platform exposes", RM:192-206), from the bug template and from the feature-request
    template (`feature_request.yml:17`), and ROADMAP's Decisions follow (§3.2).
  - CI keeps building BatteryKit for iOS (ci.yml:130-131) until that first costs time.
- **Why:** public iOS APIs give only the level and the state, and the analytics file is unchecked
  (R:79-81). Personal installs expire every 7 days (ICL #6). The Mac already reads iPhone health.
- **If it were yes:**
  - Stage 2 would become a project after 1.0 that needs the paid account, which M-1 declined.
  - README would keep the promise.
  - The 1.x contract would gain a second platform.

### M-3. Charge limiting?

- **Needed by:** 0.8.
- **Decided by delegation (2026-10-22), as recommended:** not in 1.x.
  - 0.8 says why the battery isn't charging, from the readings, and points to System Settings →
    Battery.
  - Neither a setter nor a private reading of the limit.
- **Why:** 1.x's trust promise is read-only, and macOS already has the setting (R:677-684).
- **If it were yes, for 80-100 %:**
  - a spike of the private client opened with `dlopen` (CLR:98 cites two outside measurements;
    unverified here);
  - a new `SecurityGuardTests` placement and Settings UI;
  - README's read-only claim changes.

  Below 80 %, forced discharge and the LED stay never (§4.3).

### M-4. A public beta channel?

- **Needed by:** 0.9.0.
- **Decided by delegation (2026-10-22), as recommended: no.** The 0.9.x releases are normal
  releases. There are about no outside users (§1.1), so a second track would have nobody to test
  it; the question returns only if the recorded download counts (NEW-23) show outside users.
- **If it were yes:**
  - The update contract changes, because pre-releases are rejected today (Updates.swift:125).
  - The beta needs an opt-in setting.
  - There are two release tracks to maintain.

### M-5. What 1.0 means

- **Status: awaiting the maintainer.** Asked again in plain words on 2026-10-22: "Should 1.0 mean
  'ready for people other than you', checked by the list in §2 (every feature seen working, a
  week of daily use without a crash, updates that keep your data, VoiceOver everywhere, and
  nothing that breaks through 1.x), with no fixed date and WWDC 2027 as the latest?"
- **Needed by:** before 0.7.
- **Recommended (unchanged):**
  - Approve §2 as written: yes.
  - WWDC 2027 [assumed early June] is the outer bound. There is no fixed date.
  - The usage evidence (§1.1) doesn't change the recommendation: 1.0's "ready for others" scope
    stays as planned, while cadence, support and the beta channel are sized for about no outside
    users (M-4, M-12, M-13).
- **If changed:**
  - A dropped criterion becomes a known limitation in 1.0's notes.
  - An added one moves to the version whose theme fits it.

### M-6. `bpulse`'s 1.x promise (informational, no answer needed)

- **Decided by engineering** (P1 §8, "Architecture: delegated"; §1.2 item 8), and confirmed by the
  delegation of 2026-10-22: frozen and only added to are the machine outputs and the exit codes;
  the text report, `--help` and the text of `--smc` and `--watch` may change in a minor release
  with a line in the notes. It enters ROADMAP's Decisions with NEW-08 in 0.8.
- **Why:** PB §3.4 freezes all of stdout byte for byte, which would block fixes to the report for
  years (Q). Scripts read the machine outputs, not the text.

### M-7. Ship `bpulse` inside the app?

- **Needed by:** 0.9.0.
- **Decided by delegation (2026-10-22), as recommended: yes, in 0.9.0.**
  - It goes inside the bundle, with a documented path.
  - No Settings row and no admin prompt.
  - If the DMG then exceeds its 1,520,000 B ceiling (`scripts/size-budget.json`), the ceiling rises
    in its own commit. [size unmeasured]
- **If it were no:**
  - The guide drops `swift run` for users; Report a Problem covers captures.
  - `--record` and `--export` stay for people who build from source.

### M-8. The beta window styles at 1.0

- **Needed by:** 0.9.0.
- **Decided by delegation (2026-10-22), as recommended:**
  - Graduate what you sign off.
  - The rest stays Beta behind Advanced, outside the promise. It is never removed, because
    removing it would break a choice users have made since 0.6.0 (`windowLook`,
    `betaWindowStyles`).
- **If removed:** those users fall back to Standard, and a frozen key's value goes unused.

### M-9. A backup signing key

- **Needed by:** during 0.7.
- **Decided by delegation (2026-10-22), as recommended: yes.** Generating the key is still yours:
  - Read the steps first with `swift scripts/sign-update.swift --help`. Then, in Terminal on your
    Mac (never in a chat), run `swift scripts/sign-update.swift --generate-key`. It prints the new
    private key (`sign-update.swift:9-12`). Keep it only offline (a password-manager entry or a
    printed sheet), never in an issue, a PR or the repository.
  - Print its public half with `read -rs UPDATE_SIGNING_KEY && export UPDATE_SIGNING_KEY && swift
    scripts/sign-update.swift --public-key; unset UPDATE_SIGNING_KEY` (:7-8). Paste the key when
    the cursor waits: nothing shows, and it stays out of the shell history. Post only the printed
    public line in the PR.
  - Only the public half enters `ReleaseSigning.publicKeys`.
- **If it is never generated:** losing today's one key forces every user into a manual DMG install
  (R:198-200), and ROADMAP records that as an accepted risk (C15).

### M-10. How 0.8's answers look and read

- **Needed by:** 0.8's look sitting.
- **Decided by delegation (2026-10-22), as recommended:**
  - Health: facts only, as label-value pairs.
  - "Not charging": a cause appears only when it is proven.
  - Welcome: one window, not a tour.
  - The `%@`-only placeholder rule rules out counted phrases.
- **If you want grades:** they need thresholds of our own, which become a look to freeze and a
  support question.

### M-11. What Report a Problem saves

- **Needed by:** 0.8.
- **Decided by delegation (2026-10-22), as recommended:**
  - NEW-05's contents, previewed before saving.
  - Nothing is sent.
  - Crash-report contents go in only on a second choice.
- **If it should send automatically:** that is telemetry, which is rejected (UG:502-507).

### M-12. Sessions and cadence

- **Needed by:** now.
- **Decided by delegation (2026-10-22), as recommended:**
  - about two sittings per release (§3's table);
  - Xcode on the M5: already installed (Q-B7);
  - a 7-day soak, one VoiceOver and keyboard sitting, and one Russian screenshot review;
  - after 1.0, at most a minor release every 6-8 weeks, with one sitting each. With about no
    outside users (§1.1), that is an upper pace, not a commitment (§3.8).
- **If you have fewer sittings:** features that weren't checked become known limitations, and C2
  shrinks to "listed".

### M-13. A support promise for 1.x

- **Needed by:** 0.9.0, for `SECURITY.md`.
- **Decided by delegation (2026-10-22), as recommended:**
  - fixes for the latest 1.x only;
  - security reports answered within 7 days;
  - everything else on a best-effort basis.

  With about no outside users (§1.1), anything longer would spend session time on nobody.
- **If you want longer support:** every supported line needs its own release branch, workflow run
  and session time.

### M-14. The licence

- **Needed by:** 0.9.0.
- **Decided by delegation (2026-10-22), as recommended:**
  - Keep GPLv3 (`LICENSE`, RM:252-254), with no contributor agreement.
  - Contributions are mainly captures.
- **If changed:** it needs every contributor's consent. [uncertain; a legal question]

---

## 7. Risks and how the plan absorbs them

### Yearly macOS and SDK changes

Each year brings betas at WWDC in June and the release in September [assumed], plus deprecations:
`hdiutil` in 27 is the precedent (R:524-525). CI pins Xcode 27.1 (ci.yml:63).

- 1.0 aims to ship before WWDC 2027.
- 1.1 is a compatibility release about two weeks after macOS 28.
- No beta macOS goes on the M5, the only Mac and the reference. Use a CI beta runner if one is
  offered. [uncertain]
- The platform floor stays at 27 throughout 1.x (C14).

### A macOS 27.x update breaks a private source

The private sources are MobileDevice, `IOPSCopyPowerSourcesByType(4)` and the registry layout,
which already moved once in 27 (R:63-75).

- CI's canary (ci.yml:91-93).
- The "Unavailable" states (UG:376-378).
- NEW-10's degradation tests and NEW-14's sentinel.
- NEW-22's 5-minute check after each update.
- PLT-04's contingencies.
- C14 doesn't promise readings that macOS withdraws.

### The single maintainer's time

- About 11-13 hours of hands-on time to 1.0 [estimate], plus the 5-minute NEW-22 check after
  each macOS 27.x update, unattended windows and a passive soak week (§3, Totals). Xcode's items
  add about 90 minutes to 0.6.2 and 10 to 0.8; the Developer ID evening and secrets are gone.
- Every step has a default (PB practice).
- Sessions are scripted, with unattended windows. The soak is passive.
- The verification matrix is built up from 0.7 on.
- Whatever isn't checked becomes a known limitation, not a blocker.
- Dates are estimates, not gates.
- Implementation never waits on him; only looks, behaviour, the sessions and releases do.

### The M5 is the only hardware

There is no iPad, and no other Mac model (R:149-150).

- README makes an honest claim: "verified on a MacBook Air M5" (C17).
- Report a Problem (NEW-05) makes captures cheap for others to send.
- The perturbation tests (NEW-10) cover keys other Macs may lack.
- The iPad is a known limitation (QUA-08).

### The switch to Developer ID is a migration of its own

Permissions would be asked again, placed widgets may be lost, and macOS 27 may deny the new
identity the old History (NOTES27 178668601) [unverified].

- M-1 is no (2026-10-22), so no identity switch is on the path to 1.0, and this risk is gone
  from it.
- If the maintainer ever changes his mind, the switch is a 1.x minor release of its own, after
  S-ID's (a)-(f) and installed by a version with NEW-16 (§3.4, background).
- SEC-02's self-signed identity, if 0.9.0 adopts it, is also a switch: it ships only after an M5
  check that grants and data survive (SEC-06).

### The signing key is lost or stolen

A stolen key means signed malicious updates until a release drops the key, and versions already
installed keep trusting it (RES-security A3).

- The backup key (NEW-13).
- The required reviewer (release.yml:6-9).
- A compromised key is removed in a release that says why.
- The rest is an accepted risk (Q).

### The GitHub account is lost

The update source is hard-coded (Updates.swift:152).

- The maintainer keeps two-factor authentication and recovery codes offline.
- A moved repository needs one last release from the old one.
- Total loss is an accepted risk (D).

### Ad-hoc signing keeps costing permissions and widgets

M-1 is no, so this lasts through 1.x.

- Open Anyway on every DMG install, and the grants or placed widgets a DMG replacement may lose,
  are documented known limitations at 1.0 (C3, C7, C16). Nothing waits for a signed build.
- In-app updates don't meet Open Anyway (R:161-201).
- The guide says what to set up again (UG:493-495).
- Every release's after-publishing check and C7 re-test widget survival (DIS-06).
- SEC-02's self-signed identity is weighed in 0.9.0.

### Wrong or misleading explanations

A wrong cause, or a misleading health line, does harm (V).

- A cause shows only when a real fixture proves it; Linux tests pin each one (NEW-01).
- The health summary is facts only (M-10).

### Few or no outside users

The usage evidence (§1.1) says the maintainer is, in practice, the only user.

- 1.0's "ready for others" scope stays as planned (M-5 awaits the maintainer).
- The cadence (M-12), the support promise (M-13) and the absence of a beta channel (M-4) are
  sized for that.
- Each release's download counts are recorded (NEW-23), with no telemetry (§4.3).

### Scope creep

"Everything" for widgets, or new ideas, delay 1.0.

- 0.7's MVP is never cut, and the stretch is conditional.
- The later items are listed (§4.1).
- The feature freeze starts at 0.9.0.

### Noise in energy runs

5-minute runs carry about 15 % noise (P2 WP-21).

- Budgets carry a 15 % margin.
- Builds alternate A/B.
- B's figures must agree across sessions.

### Freezing too much

- C14 pins only what scripts, stored data, placed widgets and the update path need.
- The text report is not frozen (M-6).

### Verification debt grows faster than sittings close it

There are 54 M5 rows today.

- Each release's session closes its own new checks.
- 0.9.0 closes the rest or lists them.
- The "y = looks right" scripts keep each check short.

### Notarization refuses private-framework loading

[unverified]

- Moot while M-1 is no: nothing is notarized.
- If the account ever comes, S-ID (a) tests it first (§3.4, background), and ad-hoc stays the
  fallback.

---

## Appendix A: the three proposals, judged

| Idea | From | Verdict | Where, and why |
|---|---|---|---|
| 1.0 means a non-expert gets answers to "is it OK / why not charging / what does this mean" | V | **Taken** | 0.8's theme. It is the largest user-visible gap; all the data is already read (MacPowerParser.swift:211). |
| A cause shows only after captures confirm it | V | **Taken** | NEW-01's rule and test |
| A verification matrix from the packaged build | V | **Taken** | C2, NEW-18. It turns 54 open M5 rows into one closable list. |
| 0.9 must be published to test the update into 1.0 | V | **Taken; decisive** | §3.6. The checker reads only `releases/latest` and rejects pre-releases (Updates.swift:125, 158). |
| Make F5's iPhone step and the Charge Limit capture never-cut in 0.6.2 | V | **Modified** | 0.6.2 must match P2. The capture is instead wanted before 0.8's freeze, and without it the Charge Limit cause doesn't ship (QUA-05); the iPhone step goes to the matrix. |
| A Settings row with `ln -s` for `bpulse` | V | **Modified** | Docs only; no new UI in the freeze release (M-7) |
| An iPad capture as a 1.0 gate | V | **Not taken** | No hardware; a known limitation |
| Help opens the guide at the release's tag | V | **Taken** | NEW-06 |
| A 7-day soak with counted pass criteria | Q | **Taken** (over D's 14 days) | C4. Counted metrics give more evidence than a longer, uncounted period, and they cost the single maintainer less calendar time. |
| Absolute energy budgets from 0.6.2's release candidate plus 15 % | Q | **Taken** | C5 |
| Storage, perturbation and frozen-surface tests; committed goldens | Q | **Taken** | NEW-08 to NEW-10, in 0.8's engineering lane. Linux only, so no maintainer time. |
| `formatVersion` on every JSON output, in 0.7, so scripts change once | Q | **Taken, narrowed** | NEW-11. Top-level objects only; bare arrays keep their shape. |
| The text report not byte-frozen in 1.x | Q | **Taken** | M-6 |
| Public release candidates as GitHub pre-releases | Q | **Rejected** | The app never offers pre-releases, so the update path couldn't be tested (V's point) |
| A log-privacy guard; a backup key; a crash-loop sentinel; `SECURITY.md` | Q | **Taken** | NEW-12, NEW-13, NEW-14, NEW-15 |
| `bpulse` stays source-only | Q | **Not taken** (recommendation) | The guide and the Contributing section send users to it (UG:561-663, RM:243-250), and `--record` has no in-app equivalent. M-7 decides. |
| 0.8 as "contracts and accessibility" | Q | **Split** | Accessibility joins 0.8's user-facing review; the contracts run in parallel as a Linux-only lane. Neither needs a release of its own. |
| Reconsider the paid account now; enroll early | D | **Weighed; declined by the maintainer** | M-1 is no (2026-10-22): a non-commercial hobby project, no budget for the account, about zero users. The case stays as background (§3.4, §4.2). |
| Developer ID in 0.8 | D | **Moot** (was: modified to 0.9.0) | M-1 is no, so there is no switch. The reasoning stays as background: the running app's installer performs every update, so a switch must be installed by a version with NEW-16 (§3.4 step 3, C8). |
| Refuse an update whose `LSMinimumSystemVersion` is too high; a relaunch fallback | D | **Taken** | C8, NEW-16. A dead app is the worst failure of an in-app updater. |
| The upgrade matrix from 0.4.0 | D | **Taken** (with Q's 0.6.1, 0.7.x and 0.8.x) | C7 |
| The platform floor stays at macOS 27 throughout 1.x | D | **Taken, with uncertainty marked** | C14 item 7 |
| An honest hardware claim | D | **Taken** | C17 |
| Before WWDC 2027; 1.1 for macOS 28 | D | **Taken** | §3, §3.8 |
| Q-B8 no | D | **Taken** (= P2's default; decided by delegation) | §3.1 |
| A 14-day daily-use period | D | **Not taken** | C4's 7 counted days instead (see above) |
| Mac App Store never; no personal package catalog; no telemetry; no separate website | D, Q | **Taken** | §4.3 |
| Cadence after 1.0; keep GPLv3 | D | **Taken** (decided by delegation; the cadence as an upper pace, given the usage evidence) | M-12, M-14 |
| Charge limit: read it and explain it (V) / never in 1.x (Q) | V vs Q | **Resolved: explain from the readings only; no setter and no private limit read in 1.x** | M-3. The read-only promise, plus no new private-API surface. |
