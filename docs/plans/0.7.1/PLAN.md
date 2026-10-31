# BatteryPulse 0.7.1: the plan (the widgets that waited for the feed)

**Status: plan only. Implementation starts when the maintainer says so.** Written 2026-10-31, the
day 0.7.0 was released: tag `v0.7.0` is `main` at `5e2e5c7`, `release.yml` build 9, "Widgets you
configure". 0.7.0 shipped without its M5 session (Session R), by the maintainer's decision. The
maintainer asked for 0.7.1's plan only, so nothing of 0.7.1 is built now: no code, no preparation
branch, no pull request. This file, on `claude/071-plan`, is the only thing written for 0.7.1 until
the maintainer says the work starts.

**Scope** (ROADMAP's "### 0.7.1", R:985-1021, decided by the maintainer on 2026-10-31):
- W-5, the feed: a small copy of the last readings the app writes, which the widget reads through
  one read-only sandbox exception;
- W-6, the History widget, and the Battery widget's feed-backed options (the History chart in
  large, average drain, time on battery);
- W-7, the iPhone & iPad widget;
- the widget following the app's own language;
- 0.7's M5 checks, which Session R would have run;
- 0.7's session tools re-pointed at 0.7.1;
- the build-number clock, before 0.7.1's first candidate (a technical choice, so not asked).

The design of the feed and its widgets, and the M5 check list, are in `widgets.md` beside this file
(W71). This plan references it by section instead of copying it, and §2.3 lists what it changes
there. 0.8 follows 0.7.1 (RD's note of 2026-10-31, item 4).

**The lesson behind this plan's shape:** the maintainer may again choose to release without the M5
session. So every gate has a default, §6.5 says what ships either way and what each skipped check
costs, and §14 Q71-1 asks which variant he wants if he skips it again.

**The tools beside this file** (`SESSION-R.md`, `m5-session.sh`, `ui.swift`, `frames.swift`,
`swap.swift`, `start-session-r.sh`, `start-short-session.sh`) are 0.7.0's, copied with only their
paths changed. Where they say "PLAN.md" they mean 0.7.0's plan, as their header notes say
(SR:3-7); W-16 re-points them at this file.

**Sources and how they are cited**

| Short | Source |
|---|---|
| R:n, UG:n, RM:n | `docs/ROADMAP.md`, `docs/USER_GUIDE.md`, `README.md`, line n |
| CL | `CLAUDE.md` (it wins over every other source) |
| file:line | a file in `Sources`, `Tests`, `scripts`, `Resources` or `.github` |
| W71 | `docs/plans/0.7.1/widgets.md` (its sections keep P2's numbers: §8.3, §8.5, §8.8, §10) |
| AC70 | `docs/plans/0.7.1/0.7.0-appendix-c.md`, 0.7.0's whole Appendix C |
| SR, MS | `docs/plans/0.7.1/SESSION-R.md`, `docs/plans/0.7.1/m5-session.sh` |
| P7 | 0.7.0's plan, `ebe6547:docs/plans/0.7.0/PLAN.md` (the keep commit `ebe654772c7f06d5e136327e0e6a236fed71cdc9`, in `refs/pull/13/head`) |
| P2 | 0.6.2's plan: the sections in W71, the rest of its §8 in `ebe6547:docs/plans/0.7.0/widgets.md` |
| SPIKE-W | 0.6.2's widget spikes, `a60948765b7e7df33e3a8a5d43a71953d889b411` (off origin's branches, still served by its SHA) |
| P8 | 0.8's plan, `docs/plans/0.8.0/PLAN.md` on the unmerged `claude/080-plan` at `524f3a7` |
| RD, INV | `docs/plans/1.0/ROADMAP.md`, `docs/plans/1.0/INVENTORY.md`, by section or row ID |
| HIG | https://developer.apple.com/design/human-interface-guidelines/widgets |

- **Revision:** R, UG, RM, CL, W71, AC70, SR, MS and every file:line are at `5e2e5c7` (v0.7.0)
  unless the citation names another commit. A package re-resolves the lines it touches before
  code, since earlier packages move them.
- **Apple URLs** were read on 2026-10-31. **GitHub numbers** come from the public REST API on
  2026-10-31.

**Marks:** **[unverified]** nobody has checked it; **[inference]** reasoned from verified facts,
not observed; **[estimate]** a planning number; **[conflict]** two sources disagree (Appendix B).

**IDs:**
- Packages: V-0 (intake), B-1 (the build-number clock), W-5, W-6 and W-7 (W71's and INV's IDs,
  kept), W-15 (the widget's language), W-16 (the session tools re-pointed), W-17 (the M5 session's
  preparation), Z-1 (sizes), W-18 (localization, docs, What's New), D1-D3.
- Gates: 0.7's gates keep their IDs where 0.7.1 carries them (G7-2 to G7-18, P7 §7.1), since the
  session's question IDs name them; 0.7.1's own are G71-1 to G71-4.
- Questions: Q71-1 to Q71-4. Platform facts: PF-1 to PF-11 (§2.2). Inputs: I-1 to I-12 (§2.1).

This file is English only and names no third-party product (`LocalizationCatalogTests` scans
`docs/`). CLAUDE.md wins over everything in it.

Contents:
1. At a glance
2. Inputs, platform facts, and what this plan changes in `widgets.md`
3. How every package runs
4. Work packages
5. Order and parallelism
6. The maintainer's sittings
7. Gates and their defaults; cut line; frozen surfaces
8. Localization
9. Size
10. Energy
11. Privacy
12. Docs
13. Release steps
14. The maintainer's questions
- Appendix A: traceability
- Appendix B: facts verified, conflicts, and what stays unverified
- Appendix C: facts 0.7.1 records (filled during the release)

---

## 1. At a glance

**What 0.7.1 is:** the release 0.7 left for after itself, before 0.8 (R:985-989). Its headline is
the two widgets that can only read what the app writes for them, since there is no App Group
without a paid account (M-1 is no; R:65-75).

**What users get** (each item ships only if its package lands; §7.2 is the cut line):
- **The History widget** (medium and large): the last 24 hours or 7 days of charge, battery power
  or temperature, or the 90-day capacity and cycle-count trend, with the charging stretches shaded
  and, in large, the statistics. A click opens History (W71 §8.5; Q-W2, Q-W8).
- **The iPhone & iPad widget** (small, medium and large): the most recently read device, the one
  with the lowest charge, all of them, or one chosen, each with when it was read. A click opens
  the device's page, or Devices (W71 §8.5; Q-W11: names shown, with `.privacySensitive()`).
- **The Battery widget, large:** the History chart, on by default, in place of the last two detail
  rows, on placed large widgets too (Q-W4, decided by delegation); and two new details for Custom,
  "Average drain" and "Time on battery".
- **The widgets follow BatteryPulse's own language,** when one is chosen for it alone in System
  Settings → General → Language & Region → Applications. The edit sheet and the gallery stay in the
  Mac's language, which the system draws (PF-6).
- **A privacy line** in the notes, the guide and README: what the feed holds, where, who can read
  it, and when it is rewritten (§11).
- **What's New** for 0.7.1, if Q71-3 is yes.

**What stays as 0.7.0 shipped it:** the Battery and Accessories kinds, their options, Automatic's
meaning in every family, and the Charge Limit read-only. The Battery and Accessories widgets still
read the battery and the accessories themselves, so they keep working while BatteryPulse isn't
running (UG:508-510). The widget still makes no request. No settings key is added (§7.3).

**For the release itself:**
- **The build-number clock** (B-1), first, before any candidate: both workflows take
  `CFBundleVersion` from one clock that only grows (R:1016-1021).
- **0.7's session tools,** re-pointed at 0.7.1 (W-16) and prepared for its checks (W-17).
- **0.7's M5 checks** (QUA-16), run on 0.7.1's candidate in one hands-free session and a logged
  day (§6.2-§6.3).

**The maintainer's time** [estimate]:

| Sitting | His minutes | Where |
|---|---|---|
| Look 1, the History widget and Battery's large chart (§6.1) | 5 | CI's contact sheets in English and Russian, from anywhere |
| Look 2, the iPhone & iPad widget (§6.1) | 4 | the same |
| Look 3, layout parity of every new widget, English beside Russian (§6.1) | 3 | the same |
| Once, any day before the M5 session | 1 | the Mac |
| The M5 session's start (§6.2) | 6-8 | the Mac, on the adapter |
| The logged day | passive | his normal use |
| The day's end, with the adapter's two beeps (§6.3) | 5-6 | the Mac |
| After publishing, the short form (§6.4) | 1-2, plus 8-10 passive | the Mac |
| **Total** | **about 25-29** | the M5 part about 13-17, against R:208's 12-15: the plug moved to the day's end (+2) |

If he releases without the session again, his time is the three looks alone (about 12 minutes),
or about 15 with the short feed check that §6.5 and Q71-1 recommend.

**The runs** [estimate]:

| Package | Runs | | Package | Runs |
|---|---|---|---|---|
| V-0 intake | 0 (the orchestrator) | | W-7 iPhone & iPad | 2-3 |
| B-1 build-number clock | 1 | | W-16 tools re-pointed | 1 |
| W-5 the feed | 3 | | W-17 the session's preparation | 2 |
| W-15 the widget's language | 1-2 | | Z-1 sizes | 0-1 |
| W-6 History, Battery's options | 3 | | W-18 localization, docs | 2 |
| | | | D1 and D3 | 2 |

- **Totals:** about 17-20 runs, plus 2-3 to fix forward. The feed and its two widgets are 8-9 of
  them, as R:208 and W71 ("What 0.7's plan added") estimate.

**Not in 0.7.1** (Appendix A has the reasons): 0.8's items and its six preparation branches;
the Charge Limit's number, even through the feed; extra large, in any kind (1.1); the backup
release key (0.8); W-9 and FEA-15 to FEA-19 (after 1.0); FEA-20 (1.1); an App Group, the feed's
candidate B, and the app writing into the widget's container (REJ-53); the hold watch (QUA-06,
0.8's I-8); SIZ-07, except as a size fallback (Z-1).

---

## 2. Inputs, platform facts, and what this plan changes in `widgets.md`

### 2.1 What 0.7.1 takes from 0.7.0, and what it does if that is missing

| # | Input | Where it stands (2026-10-31) | If it is missing or wrong |
|---|---|---|---|
| I-1 | 0.7.0's code: two kinds, the BatteryCore widget model, the planner, routes, manifest, previews (W71 "What 0.7 shipped") | On `main` at `5e2e5c7` | — |
| I-2 | SPIKE-W's feed proof: the unsandboxed app wrote 55 bytes, the sandboxed widget read them under A and A′ (both exceptions in one entitlements file, `a609487:Resources/BatteryPulseWidget.entitlements`), ad-hoc signed with the hardened runtime, on macOS 27.0.1 (AC70:41, 75; 26A434, `ebe6547:docs/plans/0.7.0/sessions/A.md:73`) | Proven once; never at 8-12 KB, never for a file written while the widget wasn't running, never after 27.0.1 | PF-1: the reader type switches to A′, else the feed-backed kinds are cut before release (§7.1 G71-2) |
| I-3 | The session tools in `docs/plans/0.7.1/` | Present; still 0.7.0's names (W71 "Retargeting the session tools") | W-16 re-points them |
| I-4 | 0.7's integration branch `claude/070-integration`, which the launchers fetch | **Gone from origin** (`git ls-remote origin` lists only `main`, the tags, the seven `claude/080-*` branches and this plan's `claude/071-plan`; a stale local remote-tracking ref may still show it) | W-16 points everything at `claude/071-integration` |
| I-5 | W71's design | Present | §2.3 lists this plan's changes |
| I-6 | 0.7.0's Appendix C | AC70 | — |
| I-7 | `currentConfigurations()`' answer to this ad-hoc, unsandboxed app (G7-17) | Never checked on the M5 (AC70:144) | The feed writer fails open, as `WidgetPlacements` does (`WidgetReloadPlanner.swift:242-265`) |
| I-8 | W0-1 (b): an entity query running in the ad-hoc extension | Unanswered; 0.7.0's Details chooser was never opened (AC70:142) | W-7's default needs no query (§4 W-7 item 2); G71-4 |
| I-9 | A parameter added to a shipped intent keeps a placed widget's choices (Session R's step 4.4) | Not run; RC-P and RC-U2 never built (AC70:143) | 0.7.1's own update, 0.7.0 → its candidate, is that test (step 2's second half, W-17 item 1); G7-2's default |
| I-10 | The base the session starts from | v0.7.0 is published; whether the maintainer's Mac runs 0.6.2 or 0.7.0 is unknown | Q71-2; `prepare` reads it, and either way puts v0.6.2 in place for step 2's first half (W-17 item 1) |
| I-11 | 0.8's plan and its six preparation branches, all based on `cf847d0` (0.7's integration history) | Unmerged; none in `main` | They rebase after 0.7.1 (§5) |
| I-12 | Sizes at 0.7.0 (AC70:172; `scripts/size-budget.json`) | App `__text` 2,008,460 of 2,020,000 B (0.57 % headroom), `app_kb` 4,700 of 4,840 (2.9 %) | Z-1 |

### 2.2 Platform facts 0.7.1 rests on, and what it does if one proves false on the M5

| # | Fact | Evidence | If the M5 shows it false |
|---|---|---|---|
| PF-1 | The read-only home-relative exception lets the sandboxed widget read `~/Library/Application Support/io.github.nikitausov.BatteryPulse/Widget/` | Apple's entitlement key reference (archive), "File Access Temporary Exceptions": https://developer.apple.com/library/archive/documentation/Miscellaneous/Reference/EntitlementKeyReference/Chapters/AppSandboxTemporaryExceptionEntitlements.html (the key "enables read-only access to the specified files or subdirectories in the user's home directory"; each path starts with a slash, relative to `~`, and a directory's ends with one). The page doesn't say whether `~` is the real home or the container; SPIKE-W read the real home's path, 55 bytes on 27.0.1 (I-2). Apple calls these exceptions temporary, so a later macOS may narrow them [inference] | The reader switches to A′, the same payload in a preference domain of its own with a read-only shared-preference exception (W71 §8.3), still one exception; a new candidate. If both fail: the History and iPhone & iPad kinds, the chart and the two fields are cut before release (none has shipped, so nothing frozen breaks) and the language falls back to the Mac's (0.7.0's behaviour). 0.7.1 then ships the clock, the session's checks and 0.7's fixes, if any |
| PF-2 | A parameter added to a shipped intent: "Existing widgets … will pick up … a default value if you've provided one" | WWDC23 session 10103, https://developer.apple.com/videos/play/wwdc2023/10103/, said of a widget migrated from a SiriKit intent; for an intent that shipped as an App Intent, the same [inference] | A placed widget that loses its choices or goes blank can't be repaired from the app [inference]: the notes and the guide say "Edit Widget to choose again; remove a blank one and add it again"; it stays a documented known limitation (RD C3, C7) |
| PF-3 | An entity query with `allowedExecutionTargets` `.widgetKitExtension` runs in the ad-hoc extension (W0-1 (b)) | Unanswered (I-8) | Before release, W-7's "One device" case and its entity parameter are dropped (never shipped); 0.7.0's Details chooser, already shipped, gets a fix forward and a known-limitation line |
| PF-4 | chronod refetches the descriptors at any `CFBundleVersion` change, from whichever extension answers; the in-app installer ends the old extension right before the swap | AC70:36 (D-17), :73; P7's Session A record | New kinds missing from the gallery after the in-app update (CHSErrorDomain 1103): a stale descriptor doesn't repair itself (a chronod restart kept one in Session A, P7 §6.5), so it waits for the next version change [inference]; the installer's order gets a fix forward, the notes say the new widgets appear after the next update, and ROADMAP Stage 1.2 records it |
| PF-5 | The widget draws its words from the bundle it is given (`Text(_:tableName:bundle:comment:)`) at run time | https://developer.apple.com/documentation/swiftui/text/init(_:tablename:bundle:comment:); CI renders Russian through `\.widgetStrings` in-process (`WidgetPreviewTests.swift:78, 92`) | The widget stays in the Mac's language: the guide keeps 0.7.0's sentence (UG:637-638), W-15's change stays (harmless) and a fix goes forward |
| PF-6 | The edit sheet and the gallery follow the system's language, not the app's [inference] | An Apple DTS engineer's forum reply, about iOS and given as an opinion ("I am not an expert of WidgetKit", "it seems reasonable … the UI is part of the system", with a suggestion to file feedback): https://developer.apple.com/forums/thread/772209; Session A's sheet stayed English with the extension's own language set to Russian (AC70:28, 82). No Apple page states it | — (the guide already says so once W-18 lands) |
| PF-7 | Text the system keeps live (time left, `SystemFormatStyle.DateOffset`) follows an environment `\.locale` override while the process runs in the Mac's language | [unverified]; https://developer.apple.com/documentation/widgetkit/displaying-dynamic-dates | That text stays in the Mac's language; the guide says so; W-6's "Time on battery" and the time-left line keep it |
| PF-8 | Accented rendering draws by alpha only | https://developer.apple.com/documentation/widgetkit/optimizing-your-widget-for-accented-rendering-mode-and-liquid-glass; the HIG's table disagrees for the Mac [conflict] (P7:3567-3572) | — (the charts differ by alpha, line style and position, never hue alone) |
| PF-9 | `currentConfigurations()` returns the real placements | https://developer.apple.com/documentation/widgetkit/widgetcenter/currentconfigurations(); unverified for this app (I-7) | Fail open stays (every kind counts as placed) |
| PF-10 | A widget of a kind the installed version lacks keeps its last picture | Session A's downgrade (AC70:73) | Rollback to 0.7.0 blanks them instead: the guide's rollback line says to remove them either way |
| PF-11 | Each placed widget has its own daily reload budget, typically 40-70 for a widget the user frequently views; entries at least about 5 minutes apart | https://developer.apple.com/documentation/widgetkit/keeping-a-widget-up-to-date | G7-11: percent-step reloads for the iPhone & iPad kind go first |

### 2.3 What this plan changes in `widgets.md`

W71 holds the design and stays as written until 0.7.1's D3; these changes hold where they differ:

1. **The widget's language rides in the feed** (W71 "What 0.7.1 builds" offered the feed or a
   shared-preference read of the app's `AppleLanguages`). A second exception would break "the
   feed is the widget's one new entitlement", and reading the app's own preference domain would
   expose every setting in it [inference]. So the feed gains `languages`, and every placed kind
   reads it, Battery and Accessories included (W-15).
2. **Write rule:** the feed serves any placed BatteryPulse kind, not only a reader kind (W71
   §8.3 "Writes"), because every kind now reads its language. Its sections follow the
   placed kinds: devices only while the iPhone & iPad kind is placed, history while History or
   Battery is. An empty or failed `currentConfigurations()` answer counts as every kind placed
   (fail open, I-7; `WidgetReloadPlanner.swift:230-265`), and the answer lists only BatteryPulse's
   own widgets, so "none placed" is an empty answer too [inference from
   https://developer.apple.com/documentation/widgetkit/widgetcenter]. So while fail-open holds,
   every section the toggles allow is written whether or not a widget is placed, and the file is
   never removed for want of one; only an answer that lists widgets narrows the sections. If
   G7-17 shows real answers on the M5, D3 records whether a later release counts an empty answer
   as none placed for the feed alone and removes the file then, which would starve the new
   widgets if WidgetKit ever answered this ad-hoc app with a silent empty list.
3. **Write moments:** W71 §8.3 writes only "at the moments the app already reloads widgets" and
   "only when the content changes". On the adapter at a steady charge nothing reloads for hours,
   and with recording off and no device read nothing changes, so the feed would pass its 2-hour
   limit and show "Open BatteryPulse to update" while the app runs [inference from
   `WidgetReloadPolicy.swift:22-62`]. So the routine write rides `HistoryRecorder`'s minute tick,
   an existing wake-up that runs whether or not recording is on (`HistoryRecorder.swift:37-62`),
   once per 15-minute step of the day series, changed or not, since `writtenAt` is the widget's
   only sign that BatteryPulse runs. It is called from the tick's loop, not from `recordNow`,
   whose guard returns while recording is off (`HistoryRecorder.swift:77`). The immediate rewrites
   stay (W-5 item 4).
4. **The writer's file modes:** the temporary file is made 0600 before the rename, as
   `DeviceStore` does for its key (`DeviceStore.swift:66-86`), not after it, as SPIKE-W did
   (`a609487:Sources/BatteryPulseApp/App/SpikeWidgetFeed.swift`).
5. **The reader** opens with `O_NOFOLLOW` and checks for a regular file, besides W71 §8.3's
   validation.
6. **Devices in the feed** carry the owner's name, the model name the app resolved, and the class,
   so the widget shows the same name as the app without the app's model lookup.
7. **"Average drain over the last hour"** (W71 §8.5) becomes "Average drain", the History page's
   24-hour figure ("%@ per hour", `HistoryView.swift:271-274`), since the feed carries
   `statistics24h` and a one-hour figure needs 30 minutes on battery to exist
   (`History.swift:221-231`). **"Time on battery since unplugged"** becomes "Time on battery",
   counted from `onBatterySince` by the one self-updating offset helper.
8. **History's families:** medium and large in 0.7.1. P2 §8.4 lists extra large too, but no kind
   declares it in 0.7.x and extra large is 1.1's (R:887-891); families are only added.
9. **W-7's choice:** an `AppEnum` (most recently read, the default; lowest charge; all; one
   device) plus the device entity, shown only for "One device". So the default never needs the
   entity query (PF-3), where W71 §8.5 chose between an entity and an enum.
10. **W-7's details** are fixed per family (medium adds maximum capacity; large adds cycle count
    and temperature), with no Details parameter in 0.7.1.
11. **The reading's age** shows as "Updated %@" (the time today, else the date) by default, through
    the widget's formatter in its language; Look 2 offers a self-updating "%@ ago" instead (§6.1).
    MotionGuardTests bans the relative and reference styles (`MotionGuardTests.swift:164-176`).
12. **A History state W71 lacks:** recording off shows "Turn on Record battery history in
    BatteryPulse" (opens History).
13. **`WidgetChartSummary`** is one VoiceOver label per widget chart (HIG Charts: a small chart
    gets one succinct label), not a chart-descriptor model. 0.8's `ChartSummary` (on
    `claude/080-x1a`, `Sources/BatteryCore/ChartSummary.swift`) stays 0.8's, for the app's charts.
14. **The session:** RC-P, RC-U2 and step 4.4 go: the update from 0.7.0 to 0.7.1's candidate adds
    a real parameter (the History chart) and two Details ids, so step 2's second half is that
    test. Its first half keeps W71's 0.6.2 widgets across the update to a configurable build, as
    0.6.2 → v0.7.0, so the session starts on v0.6.2, then v0.7.0; RC-U is built as 0.7.1 and RC-F
    as 0.6.99. The `--extension` method of the language step goes, since it would hide W-15's fix
    (W-17).
15. **Stale references** W71 cites at v0.6.1 or v0.6.2, re-resolved at v0.7.0:
    `build-app.sh:330-336` → `:383-385, 415-418`; `MacAccessoryProvider.swift:35-36, 46, 58` →
    `:41, 54, 70`; `AccessoryMonitor.swift:39` → `:40` (with `observeChanges` at `:80`).

---

## 3. How every package runs (0.7's practices, with these differences)

P7 §3 applies in full. The differences:

- **Branches:** the integration branch is `claude/071-integration`, from the `v0.7.0` tag. Each
  package has a worktree and a branch `claude/071-<pkg>`. At most two agents, never two on one
  file; builds use `-j 2` with no shared `.build`.
- **"The headline can't ship unseen"** (P7 §3, "Gates with defaults") is not 0.7.1's rule. 0.7.0
  shipped unseen by the maintainer's decision (AC70:160; RD's note item 1), so 0.7.1 plans for both:
  every gate has a default (§7.1), and §6.5 says what ships without the session and what each
  skipped check costs. RD §1.2 item 3 still holds as the plan's own bar: no default ships read-path
  code that no M5 run has exercised, unless the maintainer decides to release anyway (Q71-1).
- **Measure first:** the "before" is v0.7.0 (CI run 41209639359's size report, AC70:172). Each
  commit message records the widget's `__text`, binary, `widget_appintents_bytes` and
  `strings_bytes`, and, since its headroom is 0.57 %, the app's `__text` and `app_kb` (Z-1).
- **Frozen values:** a kind, parameter, case or field raw value is decided before D1, as in 0.7. A
  surface not yet released may still be cut after D1 if the M5 session shows it broken; that costs
  a new candidate and a repeat of the steps it touches (G71-2, G71-4).
- **Strings:** one package at a time touches `Resources/Localizable.xcstrings`. The catalog order is
  W-6, W-7, then W-18 (§5).
- **Layout parity** of Russian and English widgets is a standing requirement ("check everywhere
  they look the same in layout", the maintainer's words as relayed for this plan, not in the
  repository; AC70:139 records 0.7's parity confirmation): every new string gets a
  `WidgetTextBudgetTests` row, and Look 3 measures the pictures as 0.7's parity merge did. No
  space before % in any locale
  (`BatteryFormatter.percent`; `LocalizationCatalogTests.noSpaceBeforeAPercentSign`).
- **The look checks** are private pages of CI's contact sheets in English and Russian, answered
  from anywhere (0.7's three worked that way, AC70:137-139), not M5 steps.
- **0.8's preparation branches** are never edited, merged or rebased by 0.7.1; §5 says what keeps
  them rebasable.
- **Facts go to Appendix C** of the committed copy of this plan. At D3, the lasting parts move to
  ROADMAP and the plan folder is removed (§13).

---

## 4. Work packages

**Priorities:** P1 must ship; P2 ships if the budget allows; conditional depends on a gate. Each
package lists: Source; Items; Files; Linux tests; Guards; Acceptance; Effort; Risk; Rollback.

### V-0: Intake (P1, the orchestrator, no code)

- **Source:** §2; W71's opening note (its file:lines are v0.6.1's or v0.6.2's).
- **Items:**
  1. Create `claude/071-integration` from `v0.7.0`, once the maintainer says the work starts.
  2. Re-resolve every file:line W71 and this plan cite against the integration branch; record the
     changes in Appendix C.
  3. Record the CI and toolchain facts the packages need: the macOS job's `DEVELOPER_DIR`
     (Xcode 27.2, AC70:169), the Linux suite's count (781 tests in 75 suites at 0.7.0), the latest
     `ci.yml` and `release.yml` run numbers (511 and 9 on 2026-10-31).
  4. Ask Q71-2 to Q71-4 once (Q71-1 waits until the session is due).
  5. **v0.7.0's week-later counts** (R:917-918; NEW-23): if ROADMAP's Releases table still lacks
     them once they are a week old, `swift scripts/release-stats.swift` and the row, in a commit of
     its own; D1 reads them again. A `BatteryPulse-count.txt` count of 0 puts the version count's
     check back into §6.4 (P7 §6.4 step 6), since no Mac has yet been seen counting (AC70:152).
- **Files:** this plan's Appendix C; ROADMAP's Releases row (item 5). **Linux tests, guards:**
  none.
- **Acceptance:** the integration branch's first CI run is green on both jobs.
- **Effort:** none of the budget. **Risk:** low. **Rollback:** none needed.

### B-1: The build-number clock (P1; first, before any candidate)

- **Source:** R:1016-1021 and R:978-983; W71 "Build numbers"; P7 D1 ("Build numbers, before the
  candidates"); RD's note item 3; AC70:162.
- **Why first:** 0.7.1's candidates come from `ci.yml`, whose run numbers (511 on 2026-10-31) sit
  far above `release.yml`'s (9 for v0.7.0), so the release would carry a lower `CFBundleVersion`
  than the candidates the session installed, and WidgetKit caches a widget's description by that
  number (`build-app.sh:143`, P7 §6.5). `MS`'s `install_build` also refuses a build not higher
  than the installed one (MS:686-692).
- **Items:**
  1. One script, `scripts/build-number.sh`, prints the build number: whole seconds since
     2026-01-01T00:00:00Z (epoch 1767225600), about 26.2 million on 2026-10-31. Seconds, not
     minutes, because D1 dispatches RC-U and RC-F back to back, and two builds within one minute
     would share a number [inference]. The value is a single integer, a valid `CFBundleVersion`
     (https://developer.apple.com/documentation/bundleresources/information-property-list/cfbundleversion),
     and stays within `Int32` until the 2090s.
  2. `ci.yml`'s two packaging steps (`ci.yml:223, 437`) and `release.yml`'s (`release.yml:128`) set
     `BUILD_NUMBER` from it, instead of `github.run_number`. The clock is read once per job: an
     `env:` value can't run a script, and the profiling build must carry "the same version and
     build number as the DMG above" (`ci.yml:430-433`), which a clock read in each step, minutes
     apart, would break. So one step before the first packaging step writes it to
     `$GITHUB_ENV`, and both packaging steps take it from there.
  3. About already shows "version (build)" when they differ (`AboutView.swift:49-56`), so no app
     change.
  4. ROADMAP's decisions gain the line (W-18 writes it; R:978-983 already announces it).
- **Files:** `scripts/build-number.sh` (new), `.github/workflows/ci.yml`,
  `.github/workflows/release.yml`, and a new `Tests/BatteryCoreTests/BuildNumberTests.swift`, not
  `UpdateInstallTests.swift` (which already reads `ci.yml`, `UpdateInstallTests.swift:284-288`, but
  which p2a rewrites, +335 and −52 lines since `cf847d0`; §5).
- **Linux tests:** no line in either workflow uses `run_number`; each workflow reads the script
  once, into `$GITHUB_ENV`, before its first packaging step, and both of `ci.yml`'s packaging
  steps take that value; the script prints an integer above 26,000,000 and above `release.yml`'s 9.
- **Guards:** the test above. **Acceptance:** both jobs green; the macOS job's packaged app reads
  a clock-form `CFBundleVersion` (`PlistBuddy`), and so does the next `ci.yml` artifact.
- **Effort:** S, 1 run. **Risk:** low (p2a's `ci.yml` step lands right before "Package the
  profiling build", a few lines above its `BUILD_NUMBER`: a mechanical rebase-over for 0.8, §5).
  **Rollback:** revert before D1; never after a candidate is installed.

### W-5: The feed (P1; FEA-10, SEC-08's feed half)

- **Source:** R:991-993; W71 §8.3, §8.8, "What 0.7's plan added", "The packages" (W-5); INV FEA-10
  and SEC-08; TCI-11's file placement; RD C14 items 2 and 8; SPIKE-W; §2.3 items 1-6.
- **Items:**
  1. **`WidgetFeed`** in BatteryCore (`Sources/BatteryCore/Widget/WidgetFeed.swift`), version 1,
     `Codable`, with W71 §8.3's contents: `writtenAt`; the `day` (900 s × 96) and `week`
     (7,200 s × 84) series with parallel arrays `percent`, `batteryWatts10`, `temperature10` and
     `plugged`; `statistics24h` (`HistoryStatistics`, `History.swift:217-231`); `onBatterySince`;
     `daily` (up to 90 days of `capacityToDesign10` and `cycleCount`); up to 8 devices. Plus
     `languages` (W-15) and the flags `recordsHistory` and `readsDevices`, so a widget can tell
     "off" from "none".
     - A device holds its `DeviceKey` string, the owner's name and the model name as the app
       shows them (verbatim), its class, charge, state, maximum capacity, cycles, temperature and
       read time. Never a UDID, ECID or serial (`RememberedDevice` holds none,
       `RememberedDevice.swift:37-108`), and never `DeviceKey.demo`.
     - No accessory levels (W0-4 passed) and no Charge Limit number (0.8's A-2; v1 may gain it,
       since its schema only gains fields, RD C14 item 2).
  2. **The builder,** a pure function over `Sendable` values, called from a `@concurrent` function
     in the app (CL concurrency). It re-buckets `HistorySample`s into the feed's steps (means,
     with gaps as nulls; the History page's own differ: a day's minute samples and a week's
     10-minute means, `HistoryChartData.swift:9-10, 51-55`) and takes the store's existing reads
     (`HistoryStore.samples(from:to:)`, `dailySummaries()`, as `HistoryView.swift:303-331` calls
     them), so `HistoryStore.swift` is not edited (§5, e2 and e3).
  3. **`WidgetFeedStore`** in BatteryCore, the writer's file half: the `Widget/` folder 0700
     (created so, or set so if it exists); a temporary file in it, created and set 0600 before any
     byte is written; `rename` over `feed.json`; nothing written when everything but `writtenAt`
     is unchanged, except the routine step's write (item 4); the file removed on request.
  4. **The app's writer** (`App/WidgetFeedWriter.swift`, driven from `WidgetRefresher`, which stays
     the only reload site, `EnergyGuardTests.swift:78-82`):
     - **Routine:** at `HistoryRecorder`'s minute tick, from its loop rather than `recordNow`
       (whose guard returns while recording is off, `HistoryRecorder.swift:77`), once per
       15-minute step, changed or not, so `writtenAt` stays under the widgets' 2-hour limit while
       the app runs (§2.3 item 3).
     - **At once:** Clear History (`AdvancedSettings.swift:85-99`); the recording toggle; reading
       iPhones and iPads turned on or off (`AppDevices.setReading`, `AppDevices.swift:21-24`);
       Forget (`DeviceView.swift:87`); a new device reading; a plug change; the app's language
       changed at launch, before W-4's reload (W-15); Demo Mode left.
     - **Never** while `monitor.isOverridden` (Demo Mode), as `HistoryRecorder.swift:77` does.
     - **Sections by placement** (§2.3 item 2), through `WidgetPlacements`; the answer is re-asked
       at a write moment once it is older than 15 minutes (`WidgetPlacements.maximumAge`).
     - Recording off or reads off drop their sections at once, placed or not.
  5. **The reader** (`Sources/BatteryPulseWidget/WidgetFeedReader.swift`, the one widget file
     allowed a file API): the real home from `getpwuid(getuid())`, because `NSHomeDirectory()` is
     the container inside the sandbox (SPIKE-W's `SpikeProbes.swift`); `open` with `O_RDONLY`,
     `O_NOFOLLOW` and `O_CLOEXEC`; `fstat` for a regular file of at most 32 KB; a read of at most
     32 KB + 1 bytes; the bytes go to BatteryCore's validating decoder. A third `WidgetReadCache`
     gives one read per burst of timeline requests (`WidgetReadCache.swift:12-41`).
  6. **The validating decoder** in BatteryCore: W71 §8.3's rejections (over 32 KB, an unknown
     version, series of different lengths, NaN or infinity, a date more than 10 minutes ahead);
     control and bidirectional-override characters stripped from names and names capped at 64
     characters; unknown fields ignored. A missing file is a state ("no feed"), not an error.
  7. **The entitlement:**
     `com.apple.security.temporary-exception.files.home-relative-path.read-only` with one path,
     `/Library/Application Support/io.github.nikitausov.BatteryPulse/Widget/`, in
     `Resources/BatteryPulseWidget.entitlements`, whose comment is rewritten (it says the widget
     reads the battery itself because there is no App Group). The posture check compares the signed
     entitlements with that file, so it passes unchanged (`build-app.sh:383-385, 415-418`).
  8. **Signposts:** `widget.feed.write` (app) and `widget.feed.read` (widget) intervals (P2 §8.10,
     `ebe6547:docs/plans/0.7.0/widgets.md:448-454`).
  9. **Logs:** the bytes, the section counts and a rejection's case name as `.public`; never a
     name, a key or a path (CL logging). A rejection logs at notice, so `log show` finds it
     (AC70:168). The widget has no `Diagnostics` of its own: it uses BatterySource's
     (`BatteryTimelineProvider.swift:44`, `WidgetReadCache.swift:66`), which has no `widget`
     logger (`BatterySource/Diagnostics.swift:147-156`; the app's twin has one,
     `BatteryPulseApp/App/Diagnostics.swift:21`). So W-5 adds that one logger line to
     BatterySource's `Diagnostics`, the one BatterySource edit of 0.7.1 (a6a, §5); the widget's
     signposts pass their new names to BatterySource's `Diagnostics.begin`, with no edit there.
- **Files:** `Sources/BatteryCore/Widget/WidgetFeed.swift`, `.../WidgetFeedStore.swift`,
  `Sources/BatteryPulseApp/App/WidgetFeedWriter.swift`, `.../WidgetRefresher.swift`,
  `.../HistoryRecorder.swift` (the tick's call), `.../BatteryPulseApp.swift` (the init line),
  `Sources/BatteryPulseWidget/WidgetFeedReader.swift`, `.../WidgetReadCache.swift`,
  `Sources/BatterySource/Diagnostics.swift` (the `widget` logger, item 9),
  `Resources/BatteryPulseWidget.entitlements`, `Tests/BatteryCoreTests/{WidgetFeedTests,
  WidgetFeedStoreTests, WidgetSurfaceTests, SecurityGuardTests, IsolationGuardTests}.swift`.
- **Linux tests:**
  - the largest feed (8 devices with 64-character names of 4-byte characters, up to 256 bytes
    each in UTF-8, 90 days, full series, every statistic) fits 8 KB, or the limit becomes 12 KB
    by this test (W71 §8.3);
  - the decoder rejects truncated, oversized, future-dated, wrong-version, mismatched-length and
    NaN inputs, strips control and bidirectional characters, and round-trips a full feed;
  - the store: folder 0700, file 0600, an atomic replace (a reader sees the old or the new file),
    unchanged bytes not rewritten, removal;
  - the builder: no `DeviceKey.demo`, nothing while overridden, sections by placement (an empty
    answer: every section), reads off → no devices, recording off → no series, the re-bucketing
    at UTC midnight and across a gap;
  - the write rule: a step's write goes out with nothing else changed, and with recording off.
- **Guards:**
  - `SecurityGuardTests`: `widgetForbidden` keeps covering every widget file, with one allowed
    placement for the file API only, `WidgetFeedReader.swift` (`SecurityGuardTests.swift:161-200`);
    `dlopen`, `dlsym`, `URLSession` and `Network` stay banned there too. Today's pattern names
    only Foundation's file APIs and `fopen` (`FileManager`, `FileHandle`, `contentsOf:`, `fopen(`,
    :161-165), not the POSIX calls the reader uses, so it gains `open(`, `fstat(` and `getpwuid`
    (not `read(`, which `MacAccessoryProvider().read()` would match), and the self-test
    (`theWidgetHasNoFileOrNetworkAPI`, :432-441) gains those samples, so it flags them in any
    other widget file.
  - `WidgetSurfaceTests.widgetEntitlements` (`WidgetSurfaceTests.swift:93-101`) pins exactly the
    sandbox key and the one exception with its one path.
  - `IsolationGuardTests`' list gains the writer's `nonisolated` declarations, if any.
  - `EnergyGuardTests` is unchanged: no sleep, timer or task is added.
- **Acceptance:** both jobs green; the posture check passes; the packaged widget's entitlements
  hold the exception; the storage round trip of D1 finds exactly `Widget/feed.json` new.
- **Effort:** L, 3 runs. **Risk:** medium: a temporary exception may be narrowed by a macOS 27.x
  update (PF-1); the reader type keeps the switch to A′ local. **Rollback:** before D1, a revert;
  once released, the location may move in a minor release with a line in the notes, and the schema
  only gains fields (RD C14 item 2).

### W-15: The widget follows the app's own language (P1)

- **Source:** R:999-1001; W71 "The widget following the app's own language" (W-3b's, W-12's and
  W-10's parts); P7 W-0 item 8 (P7:503-524); RD's note item 2; §2.3 item 1.
- **Items:**
  1. **`WidgetLanguage`** in BatteryCore: from the feed's `languages` and the widget's
     localizations (`en`, `ru`), the localization to draw, as
     `Bundle.preferredLocalizations(from:forPreferences:)` would choose it
     (https://developer.apple.com/documentation/foundation/bundle/preferredlocalizations(from:forpreferences:)),
     as a pure function for Linux; `nil` without a feed, which keeps today's behaviour (the
     extension's own language).
  2. **The app writes its effective language list** (`Bundle.main.preferredLocalizations`) into
     the feed. At a launch whose language differs from `lastSeenLanguage` (W-4's reason,
     `WidgetRefresher.swift:61, 79-89`; `WidgetReloadPlanner.launchReason`, :223), it writes the
     feed first, then ends the extension and reloads every kind. A language chosen for an app
     alone may show only once the app is reopened ("If the app is open, you may need to quit and
     then reopen it to see the change", Apple's guide:
     https://support.apple.com/guide/mac-help/change-the-language-your-mac-uses-mh26684/mac), and
     the app reads its language at launch (`WidgetRefresher.swift:79-82`), so that launch is the
     moment.
  3. **The widget's root views** (Battery and Accessories now; History and iPhone & iPad from
     birth) set `\.widgetStrings` to the chosen language's `.lproj` in the extension's bundle,
     English's `en.lproj` included (it holds no table, so each key shows as its own text,
     `build-app.sh:105-110, 148`). `nil` stays only for "no feed": in the extension, `nil` means
     `.main`, whose tables follow the Mac's language (`WidgetWords.swift:7-11, 26-33, 47-50`), so
     `nil` for English would leave a widget in Russian on a Russian Mac with BatteryPulse set to
     English. (The previews' `nil` for English, `WidgetPreviewTests.swift:76-78`, works only
     because the test process has no Russian table.) `\.locale` is set to the chosen language
     with the Mac's region (number formats keep the region, as the app's did in Russian in
     Session B's F9, AC70:59; for the widget [inference]), and a formatter is built for that
     language. Today's `BatteryFormatter.widget` is a static built once on `.autoupdatingCurrent`
     with its unit symbols from `String(localized:)`, the Mac's language
     (`WidgetFormatter.swift:10-18`), so the widget keeps one formatter per language, as the
     previews already do (`WidgetPreviewTests.swift:81-90`). VoiceOver's labels go through the
     same bundle (`WidgetWords.swift:26-33`).
  4. **CI previews:** the Battery and Accessories widgets drawn from a feed whose language is
     Russian while the process is English, beside the English render.
  5. **What can't follow,** written into the guide by W-18: the edit sheet and the gallery's names
     (PF-6), and, if PF-7 fails, the time text the system keeps live.
- **Files:** `Sources/BatteryCore/Widget/WidgetLanguage.swift`, `WidgetFeed.swift` (the field),
  `Sources/BatteryPulseWidget/{BatteryWidgetView, AccessoriesWidgetView, WidgetWords,
  WidgetFormatter, BatteryTimelineProvider}.swift` and the accessories provider,
  `Sources/BatteryPulseApp/App/WidgetRefresher.swift` (the order at launch), the tests.
- **Linux tests:** the choice for `["ru"]`, `["en"]` (English itself, never `nil`),
  `["ru-RU", "en"]`, `["de", "en"]`, `[]` and no feed; the launch order (feed written before the
  reload) in `WidgetReloadPlannerTests`.
- **Guards:** none new: no new entitlement, no file API outside the reader.
- **Acceptance:** both jobs green; the preview pair above, with the Russian render laid out like
  0.7.0's Russian render (pixel-measured).
- **Effort:** S-M, 1-2 runs. **Risk:** low-medium (PF-5, PF-7). **Rollback:** a revert; the widget
  follows the Mac's language, as in 0.7.0.

### W-6: The History widget, and the Battery widget's feed options (P1; FEA-11)

- **Source:** R:994-996; W71 §8.5 (the History chart, the two fields, `HistoryWidgetIntent`) and
  §8.3; P2 §8.4, §8.6, §8.10 and §8.17 (`ebe6547:docs/plans/0.7.0/widgets.md:157-173, 325-341,
  440-454, 590-606`); INV FEA-11 and A11Y-06 (one summary per chart); Q-W2, Q-W4, Q-W8; §2.3
  items 7, 8, 12 and 13.
- **Items:**
  1. **BatteryCore:** `WidgetKindID.history` = `io.github.nikitausov.BatteryPulse.history`, its
     signpost name `history`, its intent type `HistoryWidgetIntent` and its page `.history` (the
     route exists: `WidgetRoute.swift:7-47`; the kind's switches are at :131-150).
     `HistoryWidgetPlan` decides what each family shows; the chart's geometry (points, gaps,
     charging spans, the axis's range) is computed there, so the widget only strokes a `Path`.
     `WidgetChartSummary` gives each chart one VoiceOver label, in English and Russian, with no
     counted phrase.
  2. **`HistoryWidgetIntent`:** `period` (24 hours, the default, or 7 days); `series` (charge, the
     default; battery power; temperature; capacity compared with design; cycle count; the last two
     always over 90 days, with `period` hidden for them); `statistics` (a Bool shown in large,
     default on). Families medium and large (§2.3 item 8). Timelines refresh hourly, with at most 3
     entries, one of them the "Open BatteryPulse to update" entry at `writtenAt` + 2 hours.
     `WidgetReloadPlanner.history`: a plug change, at most hourly (P2 §8.10).
  3. **The Battery kind's feed options:**
     - `historyChart`, a Bool on `BatteryWidgetIntent`, shown only in large (`When(widgetFamily:)`),
       default on, so a placed large widget gets it (PF-2). It draws the 24-hour charge in place of
       the last two detail rows: large shows 6 of its 8 slots while the chart shows, and Automatic's
       meaning doesn't change, since the chart belongs to the parameter (P2 §8.17). An Automatic
       large widget placed under 0.7.0 therefore shows the chart instead of Low Power Mode and the
       charge in mAh; the notes say so (§13). Without a feed, or with recording off, the chart's
       place shows the History kind's matching state line (item 4), in every placed large widget
       until BatteryPulse writes the feed; Look 1 shows it.
     - Two `BatteryWidgetField` cases, `averageDrain` ("Average drain", "%@ per hour") and
       `timeOnBattery` ("Time on battery", since the last unplug, through the one self-updating
       offset helper; "—" on the adapter), Custom only. The Details chooser lists them, since it
       offers `BatteryWidgetField.allCases` (`BatteryWidgetIntent.swift:244`); their raw values
       become Details ids. `WidgetLayoutPlan.make` gains the feed's values as an input; without a
       feed they show "—".
  4. **The widget:** `HistoryWidget` in the bundle (`BatteryPulseWidget.swift:10-15`), views that
     draw a `Path` (no Swift Charts in the widget, P2 §8.12; the app's charts are Swift Charts in
     the app target); in accented and vibrant modes the series and the charging spans differ by
     alpha, line style and position, never hue alone (PF-8). States: "No History Yet" (reused),
     "Turn on Record battery history in BatteryPulse", and a feed missing or over 2 hours old: the
     last data with its times plus "Open BatteryPulse to update" (W71 §8.5). A click opens History,
     through the URL route and the activity route of its intent type (W-3c's pattern).
  5. **Gallery previews** from sample series built in BatteryCore, so the gallery needs no feed.
  6. **The app:** `WidgetRefresher` evaluates the History kind through the planner, placed kinds
     only (`WidgetRefresher.swift:188-237`).
  7. **Pins:** `WidgetIntentManifest.shipping` and `scripts/widget-manifest.json`;
     `WidgetSurfaceTests` (kinds, signpost triggers, field raw values, the manifest literal);
     `WidgetSourceTests` (`intents.count == 2` becomes 3, `WidgetSourceTests.swift:259`; the
     mirrors; the Battery intent's defaults gain `historyChart` on); `appintents-check.swift`.
  8. **CI previews** (template: `AccessoriesWidgetPreviewTests.swift:167-185`): History medium and
     large × period × series × rendering mode × light and dark × English and Russian; Battery large
     with and without the chart; the two new details; Look 1's contact sheets; a
     `WidgetTextBudgetTests` row for every new string.
- **Files:** `Sources/BatteryCore/Widget/*` (the kind, the plan, the geometry, the summary, the
  planner, the timeline plan, the manifest), `Sources/BatteryPulseWidget/*` (the intent, the views,
  the provider, the bundle), `Sources/BatteryPulseApp/App/WidgetRefresher.swift`,
  `scripts/widget-manifest.json`, `Resources/Localizable.xcstrings`, the tests.
- **Linux tests:** the plan per family; the geometry (gaps, spans, a flat series, a missing series);
  the summary label in both languages; a planner day test with History placed (plug changes, the
  hourly cap), and 0.7.0's every-kind day test with History added, still under 100 app-initiated
  reloads a day (`WidgetReloadPlannerTests.swift:342-351`; P2 §8.10; RD:832; INV ENG-16); the
  timeline plan (hourly, at most 3 entries, the 2-hour entry); the large Battery widget with the
  chart (6 details) and without (8, as 0.7.0's Automatic large, pinned).
- **Guards:** the pins above; `MotionGuardTests` keeps the one self-updating text, which "Time on
  battery" uses through its helper file.
- **Acceptance:** both jobs green; Look 1 answered (§6.1).
- **Effort:** L, 3 runs. **Risk:** medium: the widget's size (Z-1), and a parameter added to a
  shipped intent (PF-2, G7-2). **Rollback:** before D1, each of the History kind, the chart and the
  two fields is its own commit and reverts alone (§7.2); once released, all are frozen.

### W-7: The iPhone & iPad widget (P1; FEA-12)

- **Source:** R:997-998; W71 §8.5 (`DevicesWidgetIntent`, the empty states), §8.3 (the devices);
  P2 §8.4 (families); INV FEA-12; Q-W8, Q-W11; §2.3 items 6, 9, 10 and 11.
- **Items:**
  1. **BatteryCore:** `WidgetKindID.devices` = `io.github.nikitausov.BatteryPulse.devices`, its
     signpost name `devices`, its intent type `DevicesWidgetIntent`; its page is `.device(key)` for
     one device and `.devices` otherwise (the routes exist and refuse `DeviceKey.demo`,
     `WidgetRoute.swift:62-69, 117-122`). `DevicesWidgetPlan`: small one device, medium two to
     three, large up to six (P2 §8.4); each row the charge and the state; medium adds maximum
     capacity, large cycle count and temperature. The display name: the owner's name, else the
     model's, else "iPhone" or "iPad".
  2. **`DevicesWidgetIntent`:** `show`, an `AppEnum`: "Most recently read" (the default), "Lowest
     charge", "All", "One device"; `device`, an `AppEntity` (`DevicesWidgetDevice`, its id the
     `DeviceKey` string, 32 lowercase hexadecimal characters, `DeviceKey.swift:9-35`), shown only
     for "One device", whose `EntityQuery` reads the feed through `WidgetFeedReader` and declares
     `allowedExecutionTargets` `.widgetKitExtension`, as Details does
     (`BatteryWidgetIntent.swift:259`). Its titles are the names, shown verbatim, never catalog
     keys. The default never runs the query (PF-3).
  3. **The reading's age:** "Updated %@", the time today and the date otherwise, through the
     widget's formatter in its language (§2.3 item 11); Look 2 offers the alternative.
  4. **Names:** `DeviceNameText` applies `.privacySensitive()`, the one namer for devices, pinned
     by a source test like `AccessoryNameText`'s (`WidgetSourceTests.swift:106-140`).
  5. **States** (W71 §8.5's table): reads off, "Turn on Read iPhone and iPad batteries in
     BatteryPulse"; none remembered, "Connect an iPhone or iPad with a cable"; the chosen device
     forgotten, "This device was forgotten"; a feed missing or over 2 hours old, the last readings
     with their times plus "Open BatteryPulse to update". Demo Mode never shows (the feed skips
     `DeviceKey.demo`); gallery previews come from `DemoDevice`.
  6. **Timelines** every 30 minutes, at most 3 entries; `WidgetReloadPlanner.devices`: a new
     reading that moved 3 points or changed state, at most every 15 minutes; Forget and reads off
     reload at once, inside the immediate reasons' shared 5-minute minimum.
  7. **Pins and previews** as W-6 item 7 and 8 (`intents.count` 4); Look 2's contact sheets with
     sample names in both languages.
- **Files:** as W-6's, plus `Sources/BatteryPulseWidget/DevicesWidget*.swift`.
- **Linux tests:** the plan per family and state; the display name's order; the choice for each
  `show` case, including "One device" with a forgotten key; the planner's devices day (a device
  read every 5 minutes while connected, `IDeviceSchedule.swift:39`), and the every-kind day test
  with all four kinds, still under 100 a day (W-6); `WidgetRoute` for each page.
- **Guards:** the name guard; `SecurityGuardTests`: the entity query calls the reader and uses no
  file API of its own.
- **Acceptance:** both jobs green; Look 2 answered.
- **Effort:** M, 2-3 runs. **Risk:** medium (PF-3). **Rollback:** before D1, a revert (the kind is
  never declared); "One device" alone is its own commit (§7.2).

### W-16: The session tools re-pointed at 0.7.1 (P1)

- **Source:** R:1009-1010; W71 "Retargeting the session tools"; I-4.
- **Items** (mechanical; every occurrence, counted by `grep` before and after):
  1. `INTEGRATION_BRANCH` and the launchers' and the runbook's fetch lines: `claude/071-integration`
     (MS:48; `start-session-r.sh:6, 15`; `start-short-session.sh:6, 23, 30`; SR:351, 439, 450,
     456).
  2. The base and the candidates: `TAG_BASE` v0.7.0, `BASE_VERSION` 0.7.0, `RC_VERSION` 0.7.1,
     `F_VERSION` 0.6.99 (MS:68-71); RC-P's and RC-U2's pins, fetches and install cases removed
     (MS:50-66, 650-668, 784-793). `ci.yml`'s dispatch takes only `x.y.z` versions (`ci.yml:225`),
     which these are.
  3. `~/bp-070` → `~/bp-071` in the script, `ui.swift`, `frames.swift`, `swap.swift`, the launchers'
     allow rules and the runbook's `$S`; `claude/070-session-*` → `claude/071-session-*`; the
     report's title "BatteryPulse 0.7.1".
  4. The literal versions in the logic and the questions: `step_after`'s "0.7.0" becomes a
     variable; D3-yes, D3-version, F12-version and R2's texts name 0.7.1 and 0.7.0 (MS:253,
     259-261, 295, 301, 4303-4315), and so do the lines that call the base "his 0.6.2" (for
     example MS:3598, 3716).
  5. The runbook's top note and the tools' "PLAN.md" references point at this file.
- **Files:** `docs/plans/0.7.1/{m5-session.sh, SESSION-R.md, ui.swift, frames.swift, swap.swift,
  start-session-r.sh, start-short-session.sh}`.
- **Linux tests:** `bash docs/plans/0.7.1/m5-session.sh dry-run` (CI's Linux job, `ci.yml:75-81`),
  with its printed-size rule: the part of SR the start prints must stay under 28,500 bytes
  (MS:4474-4483); it is 28,380 today, so W-16's cuts (P, U2, step 4.4) pay for W-17's additions.
- **Guards:** the macOS job's `bash -n` and `swiftc -typecheck` lines (`ci.yml:209-217`).
- **Acceptance:** both jobs green; `grep -rn '070\|0\.6\.99\|0\.5\.99\|0\.6\.2' docs/plans/0.7.1/`
  finds only history notes, RC-F's new `0.6.99` (`F_VERSION`) and step 2's first base, v0.6.2
  (W-17 item 1); the bare `0.6.2` is searched too, since "his 0.6.2" and "placed under 0.6.2"
  carry no `v` and no `070`.
- **Effort:** S, 1 run. **Risk:** low. **Rollback:** a revert.

### W-17: The M5 session's preparation (P1; QUA-16)

- **Source:** R:1002-1008; W71 "0.7's M5 checks"; INV QUA-16, ENG-17; P7 §6.2-§6.4; SR; §2.3
  item 14; the lessons of 0.6.2's and 0.7's records (AC70:29, 53, 160).
- **Items:**
  1. **Step 2 in two halves,** at the GUI phase's start:
     - **0.6.2's widgets across the update to a configurable one** (0.7's own step 2, G7-2's
       original check, QUA-16's first item; R:1002-1003), whatever the Mac runs: `prepare` puts
       v0.6.2 in place from its release unless the Mac runs it, as 0.7's `prepare` puts its base
       (MS:2188-2191, with the base's exemption from the higher-build rule, MS:739-748), and his
       own app waits in the backup. Then a small and a medium Battery widget from 0.6.2's gallery
       by computer use (his own may carry 0.7.0's choices), `menu-bar-shots before` (item 12),
       `placed before`, v0.7.0 installed the installer's way, `placed 1`, `placed 5`;
       `R2-062-small` and `R2-062-medium` ("the same layout with fresh values"); 0.7.0's What's
       New (item 11).
     - **The parameter test** (it replaces step 4.4): under 0.7.0, the session sets the medium
       Battery widget to step 4.1's Custom choices and adds a large Battery widget (Automatic),
       both by computer use, then `placed before`, `install U`, `placed 1`, `placed 5`;
       `R2-small`, `R2-medium` ("choices kept") and `R2-large` ("the chart in place of the last
       two rows").

     A 0.6.2 user who updates straight to 0.7.1 crosses both changes at once, which the two
     halves cover between them [inference].
  2. **Five more widget names:** `history-medium`, `history-large`, `devices-small`,
     `devices-medium`, `devices-large` in `WIDGET_NAMES`, the R3 questions and the question list
     (MS:150, 262-263, 316-333), and `xlarge` with `R3-xlarge` out of them (no kind declares extra
     large, AC70:166; SR's step 3 adds it only "if offered"); `ui.swift` needs no change (its
     family rule takes the name's last part, `ui.swift:325-333`; its `xlarge` limit stays unused).
     Step 3 adds them in batches, keeps a working set through steps 5-9 (small and medium
     Battery, one Accessories, one History, one iPhone & iPad) and records each change with
     `change desktop-widgets`, since they won't all fit on the Air's display [inference].
  3. **Clicks:** `click-widget history` (the History page) and `device` (the device's page, or
     Devices in an empty state), beside its cases today (MS:3073-3082).
  4. **The tree:** `step_tree` redacts `devices-*` labels, as it does `accessories-*`
     (MS:3058-3061).
  5. **A redraw before every look** (the F8 lesson, AC70:53): the 12-hour, text-size, contrast and
     transparency looks first write a `lastSeenLanguage` that differs from the app's and relaunch
     it, so `launchReason` reloads every kind, then wait for the reload notice and a new extension
     process, as `step_language` does [inference: not yet seen on the Mac]. The widget's clock times
     are formatted into the timeline, so a 24-hour change shows only after a reload
     (`WidgetTimeText.swift:56-60`).
  6. **The language step, the user's way only:** BatteryPulse's language set in Language & Region
     → Applications, then `language ru`; no `--extension` (it would hide W-15). Every kind is shot
     after the reload notice; no reload within the timeout is "not checked", never "n". The sheet
     keeps its default of 3 (PF-6).
  7. **A `feed` command:** the folder's and file's modes, the size, the version, `writtenAt`'s age,
     no `udid`, serial or demo key, the device count; the widget's signed entitlements
     (`codesign -d --entitlements`); `BatteryPulseWidget`'s sandbox denials since `prepare`
     (expected 0; the log predicate is [unverified]). It runs before step 3 (no file: 0.7.0 writes
     none), within 15 minutes of the first History widget, across step 9b's Demo Mode (the file's
     time unchanged), with reads turned off and on (rewritten at once), and after Clear History on
     the session's own data near the GUI phase's end (rewritten at once). Never Forget: the devices
     are his.
  8. **Privacy:** `shot_state` counts a `feed.json` that holds a device name as "named", so
     `attach` refuses those crops (MS:1261-1265, 2180-2187).
  9. **F12 per kind:** under 0.7.0, the Battery and Accessories widgets come back (`1`), and the
     History and iPhone & iPad widgets keep their last picture (PF-10).
  10. **`restore end` keeps the logged day's `History/`** (0.7.1 changes no storage format, D1's
      round trip), so his real day isn't lost; the start message says what it keeps and what it
      removes (the RC's `feed.json` with the rest of the session's data).
  11. **What's New** at 520 points, shot in English and again in Russian (the script clears the
      last-seen version once): 0.7.0's after step 2's first half, from 0.6.2, with its three rows
      and the count's row (W71, "What W-10 couldn't see"; AC70:170), and 0.7.1's after
      `install U`, if Q71-3 is yes.
  12. **Drops:** `raw-history base` (W-3c shipped in 0.7.0; `rc` stays). `menu-bar-shots before`
      needs 0.6.2's painter, so it runs on 0.6.2 in step 2's first half (item 1), and `after` on
      the candidate.
  13. **The plug** (the two beeps) moves to the day's end, so it measures the candidate with every
      kind placed; the start keeps only what needs him.
  14. **The short feed check** (§6.5) as a short-session section of its own, `feed-check`, with its
      launcher argument. It keeps Session R's lessons, since it drives the edit sheets, System
      Settings and the desktop too: no BatteryPulse or macOS update before it starts (its step 2
      needs his 0.7.0 and his placed widgets); `preflight`'s DO lines (his apps quit, the Claude
      desktop app among them, and a pending macOS update postponed with Later), since a banner at
      layer 23 refuses the desktop's clicks (AC70:63); `$S main` before its one computer-use
      access request; the language look only after the reload notice (item 6); the widgets by the
      script's crops.
  15. **After publishing:** `$S main` first, so BatteryPulse has a window and a Dock icon before
      computer use asks for access (it is an agent app, `build-app.sh:112, 135`); the posted line
      tells the maintainer not to press Install and Relaunch himself (0.6.2's lesson, AC70:29).
  16. **`perf-stats`** per kind with the `history` and `devices` triggers, and the feed's writes
      and reads per day.
  17. **The quick check after a macOS 27.x update** (`scripts/quick-check.sh`, NEW-22, RD:1411)
      gains the feed, since a macOS update may narrow the widget's temporary exception (PF-1) and
      nothing else would show it before a user's report: the file's age, modes and version (no
      name), any rejection the widget logged at notice since the update (W-5 item 9), and a fifth
      question, whether a placed History or iPhone & iPad widget shows data rather than "Open
      BatteryPulse to update".
- **Files:** as W-16's, and `scripts/quick-check.sh` (item 17; no 0.8 branch touches it).
- **Linux tests:** the dry run (every session's questions resolve; the printed size under 28,500
  bytes).
- **Guards:** the macOS job's type-checks and `bash -n scripts/quick-check.sh` (`ci.yml:200`).
- **Acceptance:** both jobs green; the dry run lists the new questions.
- **Effort:** M, 2 runs. **Risk:** medium: the printed-size limit, and a GUI phase about 40-55
  minutes longer than 0.7's (still capped at 4 hours) [estimate]. **Rollback:** a revert; the
  session then runs 0.7's steps re-pointed (W-16), without the new kinds' checks.

### Z-1: Size ceilings (P1)

- **Source:** AC70:172; `scripts/size-budget.json`; P7 §9 rules 1-4; RD C6; INV SIZ-06, SIZ-07.
- **Items:**
  1. Every package that touches a binary records the numbers of §3 in its commit message.
  2. A ceiling a package crosses is raised in a budget-only commit of its own that says why, in
     that package (as 0.7's W-3a did, AC70:126), and D1 sets each to the candidate plus about 5 %.
  3. **0.7.1's outer bounds:** the widget within 0.6.1's ceilings (990,000 B of `__text`,
     1,450,000 B of binary; P7 §9 rule 2); the app binary under RD C6's 5 MB; `app_kb` up to
     5,000 KB and the DMG up to 1,600,000 B [estimate]. Beyond them the cut order applies.
  4. `widget_appintents_bytes`' provisional 24,000 B (W-2's, AC70:125) is replaced at D1 by the
     candidate plus about 5 %. 0.7's two intents take 15,725 B, so two more and an entity may
     reach it [inference].
  5. **The cut order** (§9).
- **Files:** `scripts/size-budget.json` only. **Linux tests, guards:** CI's size report.
- **Acceptance:** the macOS job's size report passes at D1.
- **Effort:** S, 0-1 run (its commits ride in the packages). **Risk:** medium: the app's `__text`
  has 11,540 B of room and W-5's builder and writer land there. **Rollback:** none needed.

### W-18: Localization review, docs and What's New (P1; DOC-08; merges last)

- **Source:** P7 W-10; INV DOC-08, L10N-04; §8, §11, §12 below.
- **Items:**
  1. **The terminology pass** over every key W-6, W-7 and W-18 add, with Apple's Russian wording
     (CL localization); the PR lists each key with its Russian.
  2. **The rules checked:** placeholders `%@` only (the `Summary` keys stay plain text, as 0.7's
     were, AC70:134); no counted phrase; no space before % in any language; device titles verbatim.
  3. **Layout parity:** every new widget's English and Russian pictures measured as 0.7's parity
     merge was, and Look 3 (§6.1).
  4. **The docs** of §12, each new CL line checked against the merged code with `git grep`.
  5. **What's New** as Q71-3 decides, and the release notes' draft with the privacy line (§11, §13).
- **Files:** `Resources/Localizable.xcstrings`, `Sources/BatteryPulseApp/Updates/UpdateViews.swift`,
  `CLAUDE.md`, `docs/USER_GUIDE.md`, `README.md`, `docs/ROADMAP.md`, `docs/plans/1.0/*.md`,
  `docs/VERIFICATION.md`, `.github/release-notes.md`.
- **Linux tests:** `LocalizationCatalogTests` (every key with its Russian, nothing unused, no
  Cyrillic outside the catalog, no space before %).
- **Guards:** as above. **Acceptance:** both jobs green; Look 3 answered.
- **Effort:** M, 2 runs. **Risk:** low. **Rollback:** a revert.

### D1-D3: Freeze, the M5 session, release

As P7's D1-D3, with 0.7.1's differences.

**D1, the freeze:**
- **Golden diff** against v0.7.0, P1 §5's forms as AC70's D1-lite ran them: no difference at all,
  since 0.7.1 changes no `bpulse` output.
- **Storage round trip:** byte-identical, with exactly `Widget/feed.json` new (0700 folder, 0600
  file).
- **The settings-and-identifiers `git grep`:** the new lines are the two kind strings
  (`…history`, `…devices`) and the entitlement's path; no settings key, no `CFBundleURLTypes`, no
  App Group, no `suiteName`.
- **Ceilings** (Z-1) and the notes' draft (§13), checked by `release.yml`'s heading step run by
  hand (`release.yml:41-64`).
- **The candidates,** after B-1, on `claude/071-integration`, in this order: RC-U built as 0.7.1
  (above the installed 0.7.0; its update check offers nothing, and its version count's 404 for a
  v0.7.1 that doesn't exist yet marks only the session's settings, which `restore end` replaces,
  MS:3687-3688), then RC-F built as 0.6.99 (below v0.7.0, so Check for Updates offers 0.7.0 and
  F12 runs 0.7.1's installer), each with a clock build number, F's the higher.

**D2** is the M5 session and its logged day (§6.2-§6.3), or the maintainer's decision to release
without it (§6.5).

**D3:**
- Apply the answers or the defaults; record the numbers in Appendix C.
- Move the lasting decisions to ROADMAP; fill `docs/VERIFICATION.md`'s 0.7 and 0.7.1 rows.
- Move the session tools to `docs/plans/0.8.0/` with the `ci.yml` lines that check them, so 0.8's
  T-1 finds them (P8's I-7 expected them missing), unless 0.8's intake says otherwise.
- Remove `docs/plans/0.7.1/` in the last commit, noting `<keep>`, the commit before it.
- Release (§13), then the after-publishing check (§6.4), then a week later the download counts.

---

## 5. Order and parallelism

At most two agents, never two on one file, and one package at a time on the catalog. Slot 1 owns
the widget target, `Sources/BatteryCore/Widget/*`, `WidgetRefresher.swift` and the catalog; slot 2
never touches them.

| Round | Slot 1 | Slot 2 | Waits for |
|---|---|---|---|
| A0 | V-0, the intake | | the maintainer's go |
| A1 | W-5 | B-1, then W-16 | A0 |
| A2 | W-15 | W-17 | W-5 (the feed, the reader, `WidgetRefresher`); W-17: W-16 (the same files) |
| A3 | W-6 | (W-17's `feed` checks, once W-5's file exists) | W-15 (the root views, `WidgetRefresher`) |
| **Look 1** | the maintainer, about 5 minutes (§6.1) | | W-6's contact sheets |
| A4 | W-7 | | W-6 (the widget files, the planner, the manifest, the catalog) |
| **Look 2** | the maintainer, about 4 minutes | | W-7's contact sheets |
| C1 | W-18 (merges last) | | everything above |
| **Look 3** | the maintainer, about 3 minutes | | W-18's terminology pass |
| D1 | freeze; RC-U, then RC-F | | C1, B-1 |
| **The M5 session** and its logged day | the maintainer (§6.2, §6.3) | | D1 |
| D3 | release; after publishing (§6.4); a week later, the counts | | the session, or Q71-1 |

**Why this order:**
- **B-1 first in slot 2,** long before any candidate, so every later CI build already carries a
  clock number.
- **W-5 before everything that reads it.** W-15 next, so the new kinds follow the language from
  their first commit; then W-6 and W-7 in sequence, since both edit `BatteryPulseWidget.swift`,
  `WidgetOptions.swift`, `WidgetReloadPlanner.swift`, `WidgetRefresher.swift`, the manifest, the
  pins and the catalog.
- **The tooling in slot 2** (B-1, W-16, W-17) shares no file with slot 1.
- **Catalog order:** W-6, W-7, W-18. W-5 and W-15 add no key; if one needs one, it takes its turn
  before W-6.
- **Z-1's raises** are commits inside the package that crosses a ceiling.

**Keeping 0.8's preparation branches rebasable.** The six branches (`claude/080-e3` `a299755`,
`-a6a` `9568aa3`, `-p2a` `241b061`, `-x1a` `4f6efe1`, `-e2` `b1f7691`, `-x2a` `f55b095`) fork from
`cf847d0` ("Merge W-3c") and rebase onto `v0.7.1` after it ships. 0.7.1 keeps out of their files:
- **e2** (`DeviceStore.swift`, `HistoryStore.swift`, StorageCompatibilityTests): W-5 reads through
  the stores' existing API and edits neither; at its rebase, e2's storage tests add the feed file.
- **e3** (`HistoryStore.swift`, `SourceScanner.swift`, LogPrivacyGuardTests' per-file allow list of
  `.public` values): 0.7.1 adds no target, so `SourceScanner.swift` is untouched; at its rebase,
  e3's allow list gains 0.7.1's new `.public` log lines (the feed's bytes, counts and case names).
- **p2a** (a `ci.yml` step right before "Package the profiling build", next to B-1's line, and the
  updater's files, `UpdateInstallTests.swift` among them): B-1 edits only the `BUILD_NUMBER`
  lines and adds the step that reads the clock; a mechanical rebase-over. 0.7.1 doesn't touch
  `UpdateInstall*.swift`, so B-1's test is a file of its own.
- **x1a** (`ChartSummary.swift`): W-6's `WidgetChartSummary` is a widget label in
  `BatteryCore/Widget/`, not a second descriptor model (§2.3 item 13).
- **x2a** (`AccessibilityText.swift`, built on `WidgetPhrase` and `WidgetAccessibility`): W-6 and
  W-7 only add to their API, never rename it.
- **a6a** (BatterySource's `Diagnostics.swift`, whose `Signposts` it rewrites, and ProblemReport):
  the app's signposts go in the app's `Diagnostics`; the widget has none of its own and passes its
  new signpost names to BatterySource's `Diagnostics.begin` unchanged. W-5's one edit there is the
  `widget` logger line (W-5 item 9), outside the `Signposts` code a6a changes: a one-line
  rebase-over. 0.7.1 adds no settings key for ProblemReport's list.
- **0.8's plan** (`claude/080-plan`) changes after 0.7.1 in its rows I-5 (W-6's label exists; X-1a
  still builds `ChartSummary`), I-6 (the feed exists, so `systemChargeLimit` could show the number
  once A-2 finds a source), I-7 (the tools in `docs/plans/0.8.0/`, D3), I-9 (the clock landed),
  I-13 and I-14 (0.7.1's session measured them) and its "Not in 0.8" line (P8:150-154, 171-175).
  0.8's own intake updates them; 0.7.1 never edits that branch.

---

## 6. The maintainer's sittings

**Wording** (P7 §6): every yes or no question means "y = looks right"; comparisons are numbered
choices; screenshots and logs are the evidence; the maintainer is asked only for taste and consent.

### 6.1 The look checks (CI's contact sheets, English and Russian; about 12 minutes in all)

Each is a private page of CI's contact sheets, English beside Russian, which he answers from
anywhere, as 0.7's three were (AC70:137-139). Each question offers the decided answer first;
without an answer, the decided answers hold; without pictures, the M5 session's step 3 carries the
question and his answer joins the day-end batch.

**Look 1** (after W-6, about 5 minutes):
1. "History, medium and large: the 24-hour charge (the default), 7 days, battery power,
   temperature, and the 90-day capacity and cycle trend, with the charging stretches shaded and the
   statistics in large: y, or say the picture's number."
2. "Battery, large, as a widget placed under 0.7.0 looks after the update: **1** the History chart
   in place of the last two rows (Q-W4's decided default), **2** the eight rows kept, the chart a
   choice in Edit Widget."
3. "The two new details, 'Average drain' and 'Time on battery': y, or say."
4. "The states: 'No History Yet', 'Turn on Record battery history in BatteryPulse', and the last
   data with 'Open BatteryPulse to update', in the History widget and in the large Battery
   widget's chart: y."
5. "The edit sheet's new words (the list, English and Russian): y, or say which."

**Look 2** (after W-7, about 4 minutes):
1. "iPhone & iPad, small, medium and large, with sample names: the most recently read, the lowest,
   all, one chosen: y."
2. "When it was read: **1** 'Updated 14:05', or the date when it isn't today (the default), **2**
   '2 hours, 13 minutes ago', counting by itself."
3. "The states: reading off, none remembered, a forgotten device, 'Open BatteryPulse to update':
   y."
4. "The edit sheet's words: y, or say which."

**Look 3** (layout parity, after W-18's terminology pass, about 3 minutes): every new widget and
state in English beside Russian, with the pixel measurements: "**1** laid out alike (the shorter
Russian forms where the full ones don't fit), **2** say which differs"; and "no space before % in
either: y".

**Pre-answers:** the orchestrator posts each sheet with its measurements and the words checked
against the catalog's terms, so he mostly confirms.

### 6.2 The M5 session (hands-free; about 6-8 minutes at its start)

It runs as P7 §6.2 and SR describe, re-pointed (W-16) and with W-17's steps: one local Claude Code
session on the M5, the CLI with computer use, through `m5-session.sh` and `ui`; he does only what
needs a person.

**Before it** (SR "Before Session R"): no macOS update and no BatteryPulse update until the series
ends, so the session sees the update it tests (0.6.2's lesson, AC70:29); once, any day before, the
CLI's flag check (1 minute).

**The start line** (two short commands, as `start-session-r.sh` documents, re-pointed):
`git -C ~/BatteryPulse fetch origin claude/071-integration`, then
`bash <(git -C ~/BatteryPulse show FETCH_HEAD:docs/plans/0.7.1/start-session-r.sh)`.

**R0, the start** (he is there, on the adapter, 6-8 minutes): his yes to the list of changes (SR
R0 step 2, plus v0.6.2 and then v0.7.0 for step 2 whatever his Mac runs, the gallery's five new
widgets, the feed the candidate writes and `restore end` removes, and the logged day's history it
keeps); `prepare` (about 10 minutes, two builds; it puts v0.6.2 in place, W-17 item 1); his apps
quit, the Claude desktop app among them, and a pending macOS update postponed with Later, as
preflight asks; the reads and proofs; one computer-use access request after `$S main`; a Focus on;
`mark away`.

**R1, the GUI phase** (he is away; about 2.5-3.5 hours, capped at 4 [estimate]):
1. **Step 2** (W-17 item 1): on 0.6.2, its small and medium widgets, `menu-bar-shots before`,
   v0.7.0 installed, the shots, `placed compare` and 0.7.0's What's New; then the 0.7.0 set-up,
   `install U`, the shots, `placed compare`, and 0.7.1's What's New if Q71-3 is yes (item 11).
2. **Step 3:** the gallery in every size in batches (Battery large; Accessories small, medium,
   large; History medium, large; iPhone & iPad small, medium, large), each against CI's previews;
   then the working set. `feed` before and within 15 minutes after the first History widget.
3. **Step 4, the edit sheets:** 4.1 Custom on the medium widget and Details' chooser (W0-1 (b));
   4.2 the choices kept; 4.3 Russian the user's way, every kind shot after the reload (W-17 item
   6), the sheet (expected to stay in the Mac's language, PF-6), the tree in Russian; 4.5 back to
   Automatic; **4.6** the History sheet's options and the iPhone & iPad sheet's "One device"
   chooser (G71-4).
4. **Step 5, rendering modes and places** (G7-4): Dim widgets Always and Automatically × the four
   Icon & widget styles; Notification Center by the script's crops (it can't be granted to
   computer use); Increase Contrast and Reduce Transparency, each after a redraw (W-17 item 5).
5. **Step 6, time** (G7-3): the 12-hour look after a redraw, `tick` on time left, the count
   toggle in both languages.
6. **Step 7, the trees** (G7-12): every kind, `devices-*` and `accessories-*` labels redacted; the
   charts' labels against `WidgetChartSummary`; Text size.
7. **Step 8, clicks** (G7-9): every page, History and the device page included, with and without a
   window and with BatteryPulse quit.
8. **Step 9's accessories half** (G7-8) and **step 9b** (G7-18): Demo Mode's Charge Limit scene in
   both languages, with `feed` showing the file untouched across it.
9. **The feed's rewrites:** reads off and on; Clear History on the session's data; `feed` after
   each.
10. **Extras, while time allows:** `raw-history rc`; the menu bar on a dark bar (`V01-menubar`);
    `menu-bar-shots after` (W-17 item 12); 0.6.2's WP-18 Xcode items, last.

**R2, the hand-over:** `restore gui` (his settings and devices back into the candidate, which stays
installed), the summary he reads first (in his language, on the Mac only), `ready`.

### 6.3 The logged day, and its end (passive, then about 5-6 minutes)

- **During the day:** nothing to do; the candidate runs with his settings, his devices and every
  kind placed.
- **The day's end,** on his "day-end":
  - `day-end`: per kind (Battery, Accessories, History, iPhone & iPad), the reloads requested, the
    timelines delivered, the share and the median delay (G7-11, ENG-17); the widget's reads, the
    feed's writes and reads; crash reports and `fault` lines since `prepare`, which must be 0
    (G7-16); W-13's lines.
  - **The plug** (2 minutes of his): unplug at a beep, plug in at the second, 70 seconds later;
    each crop's state against `bpulse --json` within a minute, and at a Charge Limit he set, when
    bit 24 appears (`R9-plug`, SR:149); the reloads per kind, and `currentConfigurations()`'
    counts against the widgets placed (G7-17).
  - **F12** (G7-15): RC-F (0.6.99) → Check for Updates → Install and Relaunch to 0.7.0, by AX
    presses; per kind as W-17 item 9 says.
  - The batch (items the session answered 3), his yes, `send` to `claude/071-session-r`, and
    `restore end` (his own BatteryPulse, 0.7.0 or the 0.6.2 he ran, his settings, the logged day's
    history kept).

### 6.4 After publishing (the short form: about 1-2 minutes of his, plus 8-10 passive)

From his restored BatteryPulse (0.7.0, or the 0.6.2 he ran, Q71-2), with his widgets placed. D3
posts the start line on the release PR, with the PR's number `<n>` and `<keep>`, and the sentence
"Don't press Install and Relaunch yourself; the session does it":
`git -C ~/BatteryPulse fetch origin refs/pull/<n>/head`, then
`bash <(git -C ~/BatteryPulse show <keep>:docs/plans/0.7.1/start-short-session.sh) after-publishing <n> <keep>`.

1. His yes; `$S tools`; **`$S main` first,** so BatteryPulse has a window and a Dock icon; only
   then the one computer-use access request; the widget frames (the script's crops).
2. The before set (BatteryPulse's Settings: General, Menu Bar, Notifications, a shot each by
   computer use); `after before`; Install and Relaunch to 0.7.1 by `ui press`; `after after`: the
   version, the pre-swap line, any CHSErrorDomain 1103, `pluginkit`, `codesign`, `xattr`, the
   crops, the feed's modes and the widget's exception (seconds each); then About, What's New,
   History, the settings and the menu bar by computer use, and Login Items only by `ui tree`,
   which says whether the row exists (SR:413-419; MS:4323-4324).
3. The session judges D3-version, D3-whats-new, D3-widgets (the Battery and Accessories widgets as
   before; a History or iPhone & iPad widget he kept comes alive), D3-history, D3-settings,
   D3-login-item and D3-notifications; then `after popover` and D3-first-day, the widget against
   the popover; `send` on his yes.

Kept from 0.7's full form (P7 §6.4), since RD §1.2 item 6 makes them every release's check
(About, History, the settings and the login item kept, the widget current; RD:181-183; RD §3.2's
release criterion, RD:838-842) and 0.7.1 edits `HistoryRecorder.swift` and adds a storage file:
everything but the version count's 10-minute wait. That wait is dropped, since the week-later count
is its sign, unless v0.7.0's week-later count reads 0 (V-0 item 5), which puts P7 §6.4 step 6 back.
**Without a session** (Q71-4): his own two screenshots of a placed widget, before and after
updating, as 0.6.2's D-9 had.

### 6.5 Releasing without the M5 session

**What ships either way** is what D1 froze and CI checked: both jobs with warnings as errors; the
feed's builder, store, decoder and reader with their Linux tests (the largest-feed size included);
the language choice in BatteryCore and its Russian preview under an English process; the planner's
new kinds and their day tests; `WidgetTextBudget`; `SecurityGuardTests`' one reader placement; the
posture check with its one exception; `appintents-check` (the sheet's strings and the added
parameter); the previews and the three looks; and D1's diff, round trip, identifiers and ceilings.
D1 then builds RC-U alone, for the short feed check, or no candidate at all, as at 0.7.0
(AC70:161).

**What each skipped check costs:**

| Skipped | What could reach every user unseen | Cost [inference] |
|---|---|---|
| The feed through the real exception on today's macOS 27.x (G71-2) | The History and iPhone & iPad widgets stuck on "Open BatteryPulse to update", and the widget's language not following | The headline unseen; known only from reports. RD §1.2 item 3's bar is set aside |
| Step 2's first half: 0.6.2's widgets across the update to a configurable one (G7-2's original check) | A 0.6.2 user's placed widget gone or blank after updating to 0.7.x | The notes' and the guide's "add it again" lines stay unconfirmed, as at 0.7.0 (AC70:171) |
| Step 2's second half: 0.7.0 → the candidate, a parameter added (G7-2) | Placed widgets that lose their choices or go blank | Each user re-edits or re-adds a widget; §6.4 sees it first on his own widgets, if Q71-4 is 1 |
| The language the user's way (G71-3) | The widget staying in the Mac's language | The notes' "should" stays unconfirmed |
| The device chooser (G71-4) | "One device" with an empty chooser | One option that doesn't work |
| The feed's modes, Demo Mode, the rewrites (Darwin hooks compiled, never run) | A privacy promise nobody saw kept | The notes promise it on CI's evidence alone |
| Rendering modes on the Mac (G7-4) | A chart unreadable in tinted or clear styles | A fix forward |
| Clicks on the new kinds (G7-9) | A click that opens nothing or the wrong page | A fix forward; with BatteryPulse quit, the scheme registered (P7 §7.3) |
| The trees of the new kinds (G7-12) | A chart or a device row that VoiceOver reads wrongly or not at all | A fix forward; VERIFICATION's row stays open (RD C10) |
| The logged day (G7-11, G7-16, ENG-17) | Reloads not delivered; a crash or fault | Known only from reports |
| F12 (G7-15) | A broken update path | Low while `UpdateInstaller` is unchanged since 0.6.2 (`git diff v0.6.2 v0.7.0` shows no change there) |
| 0.7's debts | Every 0.7 check carries over again (`docs/VERIFICATION.md`'s 0.7 rows) | 0.8's session inherits them |

**What the notes then say:** that the new widgets were checked on CI's renders, not on a Mac;
placed widgets should keep their choices, and one that lost them or went blank is edited again or
removed and added again; the feed's privacy line (§11); the widgets should follow BatteryPulse's
language once it is reopened; the new widgets fill in once BatteryPulse has run. VERIFICATION's
0.7.1 rows say "not checked on the M5".

**The short feed check** (the middle way, Q71-1's recommendation if he skips the full session):
one short hands-free session from the same tools (W-17 item 14), about 3 minutes of his (the
launcher, one yes, the approvals, his apps quit with the Claude desktop app among them and a
pending macOS update postponed, as preflight asks) and about 50-70 minutes passive [estimate], no
logged day; like the full session, it needs his 0.7.0 not updated before it starts. It runs only
the checks whose failure would reach every user: the feed read through the exception at its real
size, including a file written while no widget process ran (`feed`, and the widget's
`widget.feed.read` lines); step 2's parameter test; the language the user's way on one widget,
shot after the reload notice; the "One device" chooser; one click per new kind; crash reports and
faults since `prepare`; then `restore end`. It pays RD §1.2 item 3's bar for the new read path.

### 6.6 Risks the sittings watch

- **Desktop space:** eleven BatteryPulse widgets don't fit the Air's display; W-17's batches and
  working set (W-17 item 2).
- **The runbook's printed size** (28,380 of 28,500 bytes): every addition pays with a cut (W-16).
- **The GUI phase's length:** about 40-55 minutes more than 0.7's plan, inside the 4-hour cap; what
  doesn't fit is "not run (time)" [estimate].
- **The start on 0.6.2:** on a Mac that runs 0.7.0, his own widgets show under 0.6.2 until step 2's
  first half ends (its Accessories widgets keep their last picture, PF-10); 0.6.2 reads 0.7's
  storage (AC70:172's round trip), its code names none of 0.7's four settings keys (`git grep` at
  v0.6.2), and `restore end` brings back his own app and settings.
- **The iPhone & iPad widget with a device:** `prepare` hides his remembered devices for the GUI
  phase, so it shows only its empty states then; its look with a device comes on the logged day
  and is read against the Devices page, never attached; CI's sample names are the look's evidence.
- **0.7's risks** (P7 §6.5) hold: a DMG copy over a running extension, ad-hoc signing through 1.0,
  the hands-free mode's stalls and pointer traces, a display assertion left into the logged day.

---

## 7. Gates and their defaults; cut line; frozen surfaces

### 7.1 Gates

| Gate | Decides | Measured by | Default without a measurement | If it fails |
|---|---|---|---|---|
| **G71-1** build-number clock | whether candidates may be built | B-1's test; D1 reads RC-U's `CFBundleVersion` | none: no candidate before it | fixed before D1 |
| **G71-2** the feed through the exception | the feed-backed kinds, the chart, the two fields, the language | the Linux tests; CI's posture check; the M5's `feed` and `widget.feed.read` lines | ship (§6.5's notes), only on the maintainer's decision (Q71-1) | PF-1's path: A′ in a new candidate; both denied: the feed-backed parts cut before release |
| **G71-3** the widget's language | the guide's Language text | W-15's preview (CI); step 4.3, the user's way | ship; the notes and the guide say "should follow" | PF-5's path: the guide keeps 0.7.0's sentence; a fix forward |
| **G71-4** the device chooser | W-7's "One device" | step 4.6 (with Details' 4.1) | ship: the default needs no query | "One device" and its entity cut before release; Details' chooser fixed forward |
| **G7-2** placed widgets across the updates | the release | step 2's two halves (0.6.2 → v0.7.0, a configurable widget; 0.7.0 → the candidate, a parameter added); §6.4 | ship; "Edit Widget to choose again; add a blank one again" | PF-2's path; for the first half, P7 G7-2's (the pre-swap end and CHSErrorDomain 1103 in the logs; the notes' "add it again") |
| **G7-3** time left | — | step 6 in both languages | ship | a minus sign: a fix before release |
| **G7-4** rendering modes | — | step 5's shots | ship | a fix forward |
| **G7-8** Accessories | — | steps 3 and 9 | ship | its empty state (RD §7) |
| **G7-9** clicks | — | step 8 | no URL scheme registered | a click with BatteryPulse quit that opens nothing: the scheme registered, navigation only (P7 §7.3) |
| **G7-10** size | ceilings and cuts | the size report | Z-1 | §9's cut order |
| **G7-11** reload delivery | the percent-step reloads | the logged day, per kind, at least 90 % delivered | keep the Linux-tested planner | the iPhone & iPad kind's percent steps go first |
| **G7-12** accessibility | labels | step 7's trees | the Linux tests stand; the row stays open | a fix forward |
| **G7-13** the Russian edit sheet | — | step 4.3 | "not checked" (PF-6 expects English) | — |
| **G7-15** update path | the release | F12; §6.4 | as 0.6.2's G-16 | `gh release edit v0.7.1 --prerelease` on his yes; fix forward |
| **G7-16** crashes and faults | whether the candidate ships | `day-end`'s counts | — | no D3: a fix, a new candidate, the steps it touches again |
| **G7-17** placements | whether reloads and the feed filter by kind, and whether a later release may remove the feed when none is placed | the plug's counts at the day's end | an empty answer counts as every kind placed, so the feed holds every section the toggles allow (§2.3 item 2) | — |
| **G7-18** Charge Limit | — | step 9b's Russian shot | Apple's Russian support article (102338) stands (AC70:141) | a one-key fix |

### 7.2 Cut line

**Never cut:** B-1, W-5, W-15, W-16, W-17, W-18 and D1-D3. If W-5 can't land, 0.7.1 is the clock,
the session's 0.7 checks and nothing new for users: the widgets that need the feed wait, and so does
the language, which rides in it.

**What ships if a widget isn't ready by D1** (nothing undeclared is frozen, so each cut costs
nothing later; a kind or a case can come in any later release):
1. W-7's "One device" (the entity and its case) first;
2. W-7 whole (its devices section is then never written);
3. the History kind's 90-day series (capacity and cycles), as cases that can be added later;
4. the Battery widget's two fields;
5. the History kind whole;
6. the Battery widget's History chart (then 0.7.1 adds no parameter to a shipped intent, and step
   2's second half tests only the update).

**Effort** is §1's table: about 17-20 runs, plus 2-3 to fix forward.

### 7.3 Frozen surfaces: what 0.7.1 adds, and what it keeps from 0.7.0

**What 0.7.1 adds or changes on purpose:**

| Surface | 0.7.0 | 0.7.1 | Notes line (§13) |
|---|---|---|---|
| The Battery kind | 8 parameters; 16 fields as Details ids | Plus `historyChart` (large only, default on) and the fields `averageDrain` and `timeOnBattery`; Automatic's meaning unchanged; placed large widgets show the chart in place of their last two rows | "Large Battery widgets now show the last day's charge in place of their last two rows; Edit Widget turns it off" |
| A new kind, `…history` | — | Medium and large; `HistoryWidgetIntent`, its parameters and raw values | "A History widget …" |
| A new kind, `…devices` | — | Small, medium and large; `DevicesWidgetIntent`, `DevicesWidgetDevice` (its id the `DeviceKey` string) | "An iPhone & iPad widget …" |
| The widget's entitlements | The sandbox only | Plus one read-only home-relative exception, one path (not a 1.x promise: RD C14 item 2) | The privacy line (§11) |
| Storage | `History/`, `Devices/` | Plus `Widget/feed.json` (0700, 0600), an internal file between an app and a widget of the same version: its location may move in a minor release with a notes line, its schema only gains fields (RD C14 item 2) | The privacy line |
| Signposts | `widget.timeline` (`battery`, `accessories`); `widget.reload` (`policy`, `policy.accessories`, `language`, `update`) | Plus the triggers `history`, `devices`, `policy.history`, `policy.devices`, and the intervals `widget.feed.write`, `widget.feed.read` | — (CL's list) |
| `CFBundleVersion` | each workflow's run number | the clock (B-1) | — |
| `WhatsNew.version` | 0.7.0 (`UpdateViews.swift:390`) | 0.7.1 if Q71-3 is yes | — |

**Kept from 0.7.0** (R:920-983; RD C14 items 1, 5, 6 and 8): every kind string, intent and
parameter name, raw value and Details id; families only added, Automatic's meaning per family; the
`PageID` and `WidgetRoute` strings, the `batterypulse` scheme unregistered; the four settings keys,
and **no new one** (a run that finds it needs one stops and adds a row here with its frozen-surface
note first; the placement answer stays in memory); `BatteryPulse-count.txt` on every release; no
space before %; reloads only for placed kinds, never on a timer; one self-updating time text (W-6's
"Time on battery" uses that helper); the Charge Limit read-only; the widget sends nothing, and the
app's requests are unchanged; `bpulse`'s outputs unchanged; `ChargeState`'s five cases.

**New 1.x surfaces once 0.7.1 ships** (RD C14 item 5): the two kind strings, the two intent type
names, `DevicesWidgetDevice`, its query's type name and its id format, every new parameter name
and raw value, the two field raw values, and the families declared. `WidgetSurfaceTests` and
`scripts/widget-manifest.json` pin them.

---

## 8. Localization

**Rules** (CL "Localization"; P7 §8): every literal a `LocalizedStringKey` or `String(localized:)`
keyed by its English text, with its Russian in the catalog; placeholders `%@` only; Apple's Russian
terminology; **no counted phrases** (a label and a number); device names verbatim, never keys; the
widget carries the whole compiled catalog, so each key costs twice in `strings_bytes`.

**New keys (English), by package** [estimate: about 18-24]; the final wording is settled in the
looks and W-18's pass:

| Package | New keys |
|---|---|
| W-6, gallery and intent | the History widget's gallery description (for example "Charge, power or temperature over the last day or week.") · its intent title ("Choose History") and description · "Series" · "Statistics" · "History chart" (Battery's parameter) · "Time on battery" (the field) |
| W-6, states | "Turn on Record battery history in BatteryPulse" · "Open BatteryPulse to update" |
| W-7, gallery and intent | its gallery description · its intent title and description · "Device" (the entity's type name) · "Most recently read" · "Lowest charge" · "One device" |
| W-7, states | "Turn on Read iPhone and iPad batteries in BatteryPulse" · "Connect an iPhone or iPad with a cable" · "This device was forgotten" |
| W-18, What's New (if Q71-3) | two titles and their details |

**Reused keys** (in the catalog at `5e2e5c7` with their Russian, 766 keys): "History" · "24 Hours" ·
"7 Days" · "Period" · "Charge" · "Battery power" · "Temperature" · "Capacity compared with design" ·
"Cycle count" · "Maximum capacity" · "Average drain" · "%@ per hour" · "Charging sessions" ·
"On battery" · "No History Yet" · "All" · "iPhone and iPad" · "Devices" · "Unknown Device" ·
"Updated %@" · "Open BatteryPulse" · the state words and the six unit symbols.

**Checks:**
- `LocalizationCatalogTests`: every key with its Russian, nothing unused, the App Intents literal
  forms (taught in 0.7's W-1), no space before % (`LocalizationCatalogTests.swift:270-290`), and
  no Cyrillic outside the catalog (:245-264).
- `WidgetTextBudgetTests`: a row for every new string, so a Russian text that would lay out
  differently from its English fails on Linux (`WidgetTextBudget.swift:20-63, 95-128`).
- `appintents-check.swift`: the sheets' strings are catalog keys the widget bundle translates.
- Look 3: layout parity on the pictures (§6.1).

---

## 9. Size

**Where it starts** (AC70:172, CI run 41209639359; `scripts/size-budget.json`):

| Measure | 0.7.0 | Ceiling | Headroom |
|---|---|---|---|
| App `__text` | 2,008,460 B | 2,020,000 B | 0.57 % |
| `app_kb` | 4,700 KB | 4,840 KB | 2.9 % |
| App binary | 3,007,712 B | 3,160,000 B | 4.8 % |
| Widget `__text` | 810,068 B | 852,000 B | 4.9 % |
| Widget binary | 1,293,904 B | 1,359,000 B | 4.8 % |
| `widget_appintents_bytes` | 15,725 B | 24,000 B (provisional) | 34.5 % |
| `strings_bytes` | 250,710 B | 264,000 B | 5.0 % |
| DMG | 1,415,873 B | 1,520,000 B | 6.9 % |

**Expected growth** [estimate]:
- **App:** W-5's builder, store and writer, a few to about 15 KB of `__text`: the app's ceiling is
  likely crossed in W-5, with a raise there.
- **Widget:** two kinds, their plans and views, the reader and the language choice. 0.7's Battery
  and Accessories kinds took the widget's `__text` from 492,660 to 810,068 B (AC70:125, 133),
  so 60-200 KB is plausible; the widget's ceilings will be raised, inside 0.6.1's.
- **Metadata:** two intents and an entity, about 8-10 KB, near the provisional 24,000 B.
- **Strings:** about 18-24 keys × 2 bundles, about 4-7 KB of `strings_bytes`.

**Rules:** Z-1 items 2-4 (raises in budget-only commits; the outer bounds).

**Cut order if an outer bound is crossed:**
1. charts are always a `Path` (already the design; Swift Charts never enters the widget unless it
   costs under 15 KB of its `__text`, P2 §8.12);
2. SIZ-07, a widget-only string table, about half the widget's `.lproj` (P2 §8.12), if
   `strings_bytes` is the one crossed;
3. §7.2's cut line, from its first item.

---

## 10. Energy

**What Apple allows** (PF-11): each placed widget has its own daily budget, typically 40-70
refreshes; reloads while the app is in front, after an app intent, or on a locale or accessibility
change don't count. BatteryPulse is an agent app that is rarely in front, so its reloads count.

**The feed's writes:**
- **No new wake-up:** the routine write rides `HistoryRecorder`'s minute tick, which already exists
  with 15 seconds of tolerance (`HistoryRecorder.swift:56-62`), once per 15-minute step while the
  app runs (§2.3 item 3): at most 96 writes a day of at most 8-12 KB, each an atomic rename
  [estimate]. The immediate rewrites ride user actions and existing observations.
- Nothing is written in Demo Mode. An empty answer, which is also how "no BatteryPulse widget
  placed" reads, writes as if every kind were placed (§2.3 item 2), so the writes above hold for
  every Mac that runs 0.7.1 [inference].
- `EnergyGuardTests` is unchanged: no sleep, timer, task or activity is added.

**Reloads and timelines** (W-6, W-7; tested on Linux):
- **History:** its timeline refreshes hourly (about 24 a day), plus a plug change, at most hourly.
- **iPhone & iPad:** every 30 minutes (about 48 a day, inside the 40-70 Apple gives a widget the
  user often sees, PF-11, with little room left for the app's own reloads), plus a new reading
  that moved 3 points or changed state, at most every 15 minutes; Forget and reads off at once,
  inside the 5-minute minimum the immediate reasons share.
- **The "Open BatteryPulse to update" line** is a precomputed entry at `writtenAt` + 2 hours, not a
  reload; at most 3 entries per timeline, never closer than 15 minutes.
- **All four kinds placed:** under about 100 app-initiated reloads a day, each kind within its own
  budget, the target P2 §8.10 set for these four kinds (`ebe6547:docs/plans/0.7.0/widgets.md:457`;
  INV ENG-16; RD:832) and 0.7.0's day test pins for its two
  (`WidgetReloadPlannerTests.swift:342-351`, extended by W-6 and W-7); the Battery kind stays within
  0.7's E15 bound plus 7.
- **Only placed kinds** are reloaded and written for; an empty answer counts as every kind placed.

**Reads:** one feed read per burst of timeline requests, shared by every kind and instance, through
a third `WidgetReadCache`; a read of at most 32 KB from the user's own Library [estimate: well under
a millisecond]. The Battery and Accessories widgets' own reads are unchanged.

**Measured** (the logged day, G7-11): per kind, requested against delivered and the median delay;
the feed's writes and the widget's feed reads per day; `pmset -g assertions` at `day-end`.

---

## 11. Privacy

**What the feed holds** (W-5 item 1): the last day's and week's charge, battery power, temperature
and plugged-in state in 15-minute and 2-hour steps; the last 24 hours' average drain, time on
battery and charging sessions; when the Mac was last unplugged; up to 90 days of capacity compared
with design and cycle count; up to 8 remembered iPhones and iPads (the `DeviceKey` string, the
owner's name, the model, the class, the charge, the state, the maximum capacity, the cycles, the
temperature and the read time); BatteryPulse's language list; and whether history recording and
device reads are on. Never a UDID, ECID or serial; never `Devices/key`; never Demo Mode's data;
never an accessory; nothing that isn't already in `History/` or `Devices/devices.json` beside it.

**Only what a placed kind can show, once WidgetKit lists the placed widgets:** devices only while
an iPhone & iPad widget is placed, the history only while a History or Battery widget is (§2.3
item 2). An empty or failed answer, which is also how "no BatteryPulse widget placed" reads,
writes every section the toggles allow, so a Mac without BatteryPulse widgets keeps the file too
[inference; G7-17]. Clear History, Forget, and turning recording or device reads off rewrite it at
once, placed or not.

**Who can read it:**
- The folder is 0700 and the file 0600, owned by the user, like `Devices/` when its key creates it
  (`DeviceStore.swift:66-86`; `~/Library` is 0700 anyway). Any process of that user that isn't
  sandboxed could read it, as it can `devices.json` today; a sandboxed app of another developer
  can't, without an exception of its own [inference].
- The widget's exception is read-only and names only `Widget/`, not `Devices/` or `History/`
  (`codesign -d --entitlements` shows it in the session). Apple's key reference doesn't say the
  sandbox grants only listed paths: it gives a sandboxed app "its container, … locations that are
  POSIX world-readable, and … locations … the user indicates", plus the exceptions (PF-1's page),
  and `History/` is created with the default modes (`HistoryStore.swift:236, 260`). That the
  sandbox alone keeps the widget out of `History/` is [unverified]; what keeps it out is its code:
  one reader, of `feed.json` only (W-5's `SecurityGuardTests` placement). No probe that tries to
  read further ships.
- Time Machine and other backups include it, as they include `devices.json` [inference].
- **Nothing is sent:** the widget still has no network (`SecurityGuardTests`), the feed goes
  nowhere, and the app's internet requests are unchanged (RD C14 item 8).

**Names and identifiers:** device names get `.privacySensitive()` (Q-W11); a device is known by its
`DeviceKey`, an HMAC with a key only the app reads (CL; `DeviceKey.swift`), so neither the widget's
configuration nor the feed holds a hardware identifier. `AccessoryBattery.id` never enters the
widget.

**Logs:** the feed logs bytes, counts and case names as `.public`; a name, a key or a path never.
A device page's `DeviceKey` logs as `.private(mask: .hash)` (CL logging).

**The privacy line** (the notes, and the guide's and README's Privacy sections, by W-18):

> **Widgets and privacy.** The History and iPhone & iPad widgets can't read BatteryPulse's history
> or your devices themselves, so BatteryPulse keeps a small copy of what they show (the last day
> and week of readings, and your iPhones' and iPads' last readings) in its own folder, which only
> you can read: `~/Library/Application Support/io.github.nikitausov.BatteryPulse/Widget/`. The
> widgets read that folder and nothing else of BatteryPulse's. Nothing in it leaves your Mac,
> and it is rewritten at once when you clear the history, forget a device or turn a reading off.

---

## 12. Docs

| Document | Change | Package |
|---|---|---|
| `docs/USER_GUIDE.md`, Widgets | The History and iPhone & iPad kinds, their sizes and options; the large Battery widget's History chart and the two details; "Open BatteryPulse to update"; the empty states; clicks; a rollback to 0.7.0 leaves the new kinds frozen, so remove them (PF-10) | W-18 |
| `docs/USER_GUIDE.md`, Language (UG:627-638) | The widgets follow the language chosen for BatteryPulse once it is reopened; the edit sheet, the gallery and, if PF-7 fails, the live time text follow the Mac's | W-18 |
| `docs/USER_GUIDE.md`, the widgets' independence (UG:508-510) | The Battery and Accessories widgets still read the Mac themselves; History and iPhone & iPad show what BatteryPulse last wrote | W-18 |
| `docs/USER_GUIDE.md` and `README.md`, Privacy | §11's privacy line | W-18 |
| `README.md`, Widget bullets | The four kinds | W-18 |
| What's New | Q71-3 | W-18 |
| `CLAUDE.md` | Layout: `WidgetFeed`, `WidgetFeedStore`, `WidgetLanguage`, `WidgetChartSummary` in BatteryCore's list; the widget "signed with only the app-sandbox entitlement" (CL:99) gains the read-only exception, and "reads no file of ours" (CL:103) becomes "reads only the feed, in `WidgetFeedReader`"; four kinds; the signposts (CL:237-238); Releases: the build number from the clock | W-18, B-1 |
| `docs/ROADMAP.md` | The 0.7.1 entry ticked; the Releases row; the decisions: the feed and its exception, the clock, the language; Stage 1.2's widget line from §6.4 | W-18, D3 |
| `docs/plans/1.0/ROADMAP.md`, `INVENTORY.md` | FEA-10 to FEA-12, SEC-08, DOC-08, QUA-16 marked shipped or carried; C1's sentence that the two widgets count toward 1.0 "only if they shipped in 0.7.0" (RD:257-262) restated for 0.7.1; SIZ-07 given a home (Appendix A); C10's charts read as the app's (Appendix B) | W-18 |
| `docs/VERIFICATION.md` | 0.7's rows from the session; 0.7.1's rows | D3 |
| `.github/release-notes.md` | §13 step 2 | W-18, D1 |

---

## 13. Release steps

1. **Version:** the tag `v0.7.1` sets `VERSION`; `BUILD_NUMBER` comes from the clock (B-1), so the
   release sits above every candidate.
2. **Notes:** `.github/release-notes.md` opens with `## What's new in 0.7.1`, the only heading
   `release.yml` accepts for v0.7.1 (`release.yml:41-64`; AC70's D1-lite row 4). They list only what
   landed:
   - the History widget and the iPhone & iPad widget, with the privacy line (§11);
   - "Large Battery widgets now show the last day's charge in place of their last two rows; Edit
     Widget turns it off", and the two new details;
   - "The widgets now follow the language you chose for BatteryPulse in System Settings, once you
     reopen it (Edit Widget's sheet follows your Mac's)";
   - from §6.5, if the session didn't run: "checked on CI's renders, not on a Mac", with the
     "should" lines;
   - "If a widget is blank after the update, remove it and add it again from the gallery", if the
     session or §6.4 saw one;
   - "Updating from 0.7.0 or 0.6.2: Install and Relaunch."
3. **ROADMAP:** the Releases row; §12's changes.
4. **D3's moves** (D1-D3 above), then remove `docs/plans/0.7.1/` in the last commit; `<keep>` is
   the commit before it.
5. **The PR** `claude/071-integration` → `main`, with the numbers, Appendix C and the session's
   results; both jobs green with no warning; merged on the maintainer's OK.
6. **Tag and release:** the maintainer approves the `release` environment's run; `release.yml`
   attaches the DMG, its `.sig`, the dSYMs and `BatteryPulse-count.txt` and checks the last is
   listed.
7. **After publishing** (§6.4), with `gh release edit v0.7.1 --prerelease`, on his yes, as the
   rollback.
8. **A week later:** `swift scripts/release-stats.swift`, v0.7.1's row in ROADMAP's Releases table,
   in a commit of its own (NEW-23).

---

## 14. The maintainer's questions

Only what the scope leaves open. Technical choices are made by the plan and the runs (P1 §8:
architecture is delegated), among them the clock's form, the feed's format and write moments, the
language through the feed, the families, the device choice's shape, the sizes and the session's
steps.

- **Q71-1: If you decide again to release without the M5 session, which way?**
  - **1** Release as built, as 0.7.0 was (looks only, about 12 minutes; §6.5's costs and notes).
  - **2** First the short feed check: about 3 minutes of yours and about an hour hands-free, no
    logged day (§6.5).
  - **3** Wait for the full session.

  **Recommendation: 2,** if the full session doesn't suit you. The feed's reader is new code that
  no M5 run has exercised beyond 55 bytes on macOS 27.0.1, and if it fails, every user's History
  and iPhone & iPad widgets show nothing but "Open BatteryPulse to update" (RD §1.2 item 3).
  **Default:** the full session as planned; asked only when it is due.
- **Q71-2: Which BatteryPulse does your Mac run now, 0.6.2 or 0.7.0?** Please don't update it
  before the session starts, so the session sees the update it tests. **Recommendation:** stay on
  what you have. Either way step 2 starts on 0.6.2: from yours, or, on 0.7.0, from v0.6.2 that
  `prepare` puts in place for the first minutes (your own app comes back at the end), so 0.7.0's
  own update debt (G7-2's original check) and 0.6.2's menu bar shots (W-17 items 1 and 12) are
  paid either way, about 7-10 minutes more, hands-free. **Default:** `prepare` reads the version
  and plans from it.
- **Q71-3: What's New for 0.7.1?** **1** yes: once after updating, the History widget and the
  iPhone & iPad widget (with the feed's privacy sentence), plus the version count's row for anyone
  coming from before 0.7; **2** no, as a fix release would. **Recommendation: 1:** two new widgets
  are news, and the window is where an updater meets the new file. **Default:** 1.
- **Q71-4: The check after publishing:** **1** the short session (about 1-2 minutes of yours plus
  8-10 passive, §6.4); **2** your own two screenshots of a placed widget before and after updating.
  **Recommendation: 1,** since it also reads the feed's modes and the widget's exception on the
  published build. **Default:** 1; 2 if you skip it.

Already decided, and only signed off in the looks: Q-W2 (the two kinds; the 90-day trend), Q-W4
(placed large widgets get the chart), Q-W8 (a click opens the widget's page), Q-W11 (device names
shown, `.privacySensitive()`), Q-W12 (°C).

---

## Appendix A: traceability

**ROADMAP's 0.7.1 entry** (R:985-1021):

| Item | Source | 0.7.1 package or status |
|---|---|---|
| The feed, in a folder only the user can read, one read-only exception, rewritten on clear, forget or off | R:991-993; INV FEA-10, SEC-08 | W-5 |
| The History widget; the Battery widget's chart, average drain and time on battery | R:994-996; INV FEA-11 | W-6 |
| The iPhone & iPad widget, with its reading's age | R:997-998; INV FEA-12 | W-7 |
| The widget following the app's own language | R:999-1001; P7 W-0 item 8 (no INV or RD row) | W-15 (W-3b's part); W-17 item 6 (W-12's); W-18 (W-10's) |
| 0.7's M5 checks | R:1002-1008; INV QUA-16 | W-16, W-17, §6.2-§6.4; one by one below |
| The session tools re-pointed | R:1009-1010 | W-16 |
| The feed and the exception announced with a privacy line | R:1012-1014; INV DOC-08 | §11, §13 step 2, W-18 |
| The build-number clock before the first candidate | R:1016-1021 | B-1 (first) |

**W71's sections:**

| Item | 0.7.1 package or status |
|---|---|
| "What 0.7's plan added": the gate (W0-3 passed, Q-W3 yes, M-1 no) | Holds; the budget condition is gone (W71) |
| "What 0.7's plan added", the rest: order, storage, names and identifiers, energy, size, strings, guards, accessibility, the Charge Limit's number, docs, a parameter added | §5; D1's storage round trip; W-7 item 4, §11; §10; §9; §8; W-5's guards and `LocalizationCatalogTests`; W-6 item 1 (§2.3 item 13); not in 0.7.1 (0.8's A-2); §12; step 2's second half (W-17 item 1) |
| One type behind the reader; A′ as the fallback | W-5 item 5; PF-1 |
| The feed's location not a 1.x promise | §7.3 |
| The entitlement and its pin | W-5 item 7 |
| `WidgetChartSummary` | W-6 item 1 (§2.3 item 13) |
| §8.3 contents, validation, writes | W-5 (§2.3 items 2-6) |
| §8.3 candidate B, candidate C, the widget's container | Not in 0.7.1 (rejected, W71 §8.3; RD REJ-53) |
| §8.5 Battery's History chart and the two fields | W-6 item 3 (§2.3 item 7) |
| §8.5 `HistoryWidgetIntent` | W-6 item 2 |
| §8.5 `DevicesWidgetIntent`, its states | W-7 (§2.3 items 9-11) |
| §8.5 feed-only options ship only with the feed | §7.2 (the cuts come before release) |
| §8.8 the feed's hardening | W-5 items 5-7, 9; W-7 item 4 |
| "The packages" W-5, W-6, W-7 | W-5, W-6, W-7 |
| The widget's language (W-4's part shipped; W-3b's, W-12's, W-10's parts) | W-15, W-17, W-18 |
| "0.7's M5 checks" | One by one in the next table |
| "Build numbers" | B-1 |
| "Retargeting the session tools" | W-16 |
| "Later: W-9" | Not in 0.7.1: after 1.0 at the earliest, only if asked (RD §4.1) |
| §10 Q-W answers | §14 ("Already decided") |

**0.7's M5 checks, one by one** (W71 "0.7's M5 checks"; AC70:140-153, 170; every one unrun):

| Check (0.7's step, gate) | 0.7.1 step, package or reason |
|---|---|
| 0.6.2's small and medium widgets across the update to a configurable one (step 2, G7-2) | Step 2's first half, 0.6.2 → v0.7.0, whatever the Mac runs (W-17 item 1) |
| A parameter added to a shipped intent keeping the choices (step 4.4, RC-P, RC-U2) | Step 2's second half, 0.7.0 → the candidate (W-17 item 1; §2.3 item 14); RC-P and RC-U2 go |
| The gallery in every size against CI's previews, with no extra-large views (step 3) | §6.2 R1 step 2 (W-17 item 2) |
| The edit sheet: Custom, the choices kept, Details' chooser (W0-1 (b)), back to Automatic (steps 4.1, 4.2, 4.5) | §6.2 R1 step 3 |
| The edit sheet and the widgets in Russian (step 4.3, G7-13) | §6.2 R1 step 3, the user's way only (W-17 item 6) |
| Rendering modes, Notification Center, Increase Contrast, Reduce Transparency (step 5, G7-4) | §6.2 R1 step 4 |
| Time left, 12-hour time, the count's toggle in both languages (step 6, G7-3, W-13) | §6.2 R1 step 5 (W-17 item 5) |
| The accessibility tree, in English and Russian, and Text size (step 7, G7-12) | §6.2 R1 steps 3 and 6 |
| Clicks with and without a window and with BatteryPulse quit (step 8, G7-9) | §6.2 R1 step 7 (W-17 item 3) |
| The plug against `bpulse --json`, and the per-kind counts against the placements (step 9, G7-17) | §6.3, at the day's end (W-17 item 13) |
| The accessories' half (step 9, G7-8) | §6.2 R1 step 8 |
| The Charge Limit in Demo Mode, in both languages, and System Settings' Russian (step 9b, G7-18) | §6.2 R1 step 8; else Apple's Russian article stands |
| Raw Data to History (step 10) | `raw-history rc` (W-17 item 12); `base` goes, since Session B showed the bug on 0.6.2 and W-3c shipped |
| The menu bar painter before and after W-11 (step 10) | `menu-bar-shots before` on 0.6.2 in step 2's first half, `after` on the candidate (W-17 items 1, 12) |
| WP-18's Xcode items and the dark bar (step 11) | §6.2 R1 step 10, last |
| The logged day: reloads per kind, the widget's reads, crashes, faults, assertions (G7-11, G7-16) | §6.3 |
| W-13's optional `noCounter` line | §6.3's W-13 lines: RC-U's 404 for v0.7.1, if it runs for 24 hours |
| F12 (G7-15) | §6.3: RC-F as 0.6.99 → v0.7.0 |
| After publishing: About, What's New, History, the settings, the login item, notifications, `codesign`, `xattr`, the widget against the popover | §6.4, RD §1.2 item 6's list |
| After publishing: the count's `counted` line and its count at 1 or more | Not in §6.4: v0.7.0's week-later count is its sign (V-0 item 5); a count of 0 puts it back |
| What's New's rows and the count's row at 520 points in Russian (W-10) | W-17 item 11: 0.7.0's window from 0.6.2, 0.7.1's from 0.7.0 |
| The hold watch (QUA-06, step 11) and the Charge Limit capture (QUA-05) | Not in 0.7.1: 0.8's I-8; QUA-05 not needed (AC70's D-13) |

**RD and INV rows:**

| Row | 0.7.1 package or status |
|---|---|
| FEA-10 | W-5 |
| FEA-11 | W-6 |
| FEA-12 | W-7 |
| SEC-08 | W-5 (the reader's rejections, the modes, the placement), W-7 item 4 (device names) |
| DOC-08 | W-18 (§11's line) |
| QUA-16 | W-17, §6 |
| ENG-17 (placed in 0.7; no logged day ran) | §6.3, G7-11 |
| A11Y-06's "one summary per chart" (0.7; no chart shipped) | W-6 item 1 |
| TCI-11's file placement for FEA-10 | W-5's guard |
| L10N-04 for the new intents | W-6, W-7, W-18 |
| SIZ-06 (0.7's budget) | Z-1 |
| SIZ-07 (placed in 0.7 as P3; 0.7's records don't say it was measured) | Not in 0.7.1 except as a size fallback (§9); W-18 asks RD to give it a home |
| RD C1 (the two widgets count toward 1.0 only if in 0.7.0) | W-18 restates it |
| RD C10 (every family reachable and named in both languages; every chart a descriptor) | W-6, W-7 (labels and summaries); §6.2 step 7; the widget charts get one label, not a descriptor (Appendix B) |
| RD C14 items 2, 5, 8 | §7.3 |
| RD §1.2 item 3 | §3; §6.5; Q71-1 |
| RD §1.2 item 6 (the after-publishing check) | §6.4 |
| NEW-18 (the verification matrix) | D3: VERIFICATION's 0.7 and 0.7.1 rows |
| NEW-22 (the quick check after a macOS 27.x update) | W-17 item 17: the feed joins `scripts/quick-check.sh` |
| NEW-23 (the counts a week after publishing) | §13 step 8 for v0.7.1; V-0 item 5 for v0.7.0 |
| REJ-30, REJ-53, REJ-57, REJ-60, REJ-62 | Still rejected: the widget stays nonisolated, its reader too; no write into the widget's container; no network in the widget; App Intents types only in the widget target; no seconds or timer text ("Time on battery" and Look 2's self-updating age use the one offset helper) |
| NEW-13 (the backup key) | Not in 0.7.1: 0.8 (the maintainer's decision, 2026-10-31) |
| FEA-15 to FEA-19 (W-9) | Not in 0.7.1: after 1.0 (RD §4.1) |
| FEA-20 (why it isn't charging, as a widget field) | Not in 0.7.1: 1.1 |
| FEA-35's number | Not in 0.7.1: 0.8's A-2; the feed may carry it later |
| QUA-06 (the hold watch) | Not in 0.7.1: 0.8's I-8 |
| Extra large (any kind) | Not in 0.7.1: 1.1 (R:1068-1070) |
| 0.8's A-1 to L-1 and its six preparation branches | Not in 0.7.1 (§5) |

---

## Appendix B: facts verified, conflicts, and what stays unverified

**Verified for this plan** (at `5e2e5c7` unless named; read 2026-10-31):
- v0.7.0 is `release.yml` run 9 at `5e2e5c7` (run 8 was v0.6.2 at `0ecca33`); the latest `ci.yml`
  run before this plan's own is 511 on `main` at `5e2e5c7` (512 and up are `claude/071-plan`'s),
  and 510 on the 0.7 integration branch at `8713ab9` (GitHub's API). `BUILD_NUMBER` is
  `github.run_number` at `ci.yml:223, 437` and `release.yml:128`; the profiling build shares the
  DMG's build number (`ci.yml:430-433`).
- `git ls-remote origin` lists no `claude/070-*` branch: only `main`, the tags, the seven
  `claude/080-*` branches, `claude/071-plan` and `refs/pull/*` (`refs/pull/13/head` = `8713ab9`).
  The launchers' documented `git fetch origin claude/070-integration` would fail
  (`start-session-r.sh:6, 15`).
- The widget's entitlements are the sandbox key alone
  (`Resources/BatteryPulseWidget.entitlements:7`), pinned by `WidgetSurfaceTests.swift:93-101`.
- `widgetForbidden` covers `BatteryPulseWidget/` and `BatteryArt/` with no allow list
  (`SecurityGuardTests.swift:161-200`), naming Foundation's file APIs and `fopen` but no POSIX
  `open`, `fstat` or `getpwuid` (:161-165); its self-test is at :432-441.
- The widget's `Diagnostics` is BatterySource's (`BatteryTimelineProvider.swift:44`,
  `WidgetReadCache.swift:66`), whose loggers have no `widget` category
  (`BatterySource/Diagnostics.swift:147-156`); a6a rewrites that file's `Signposts`.
- The widget extension's main bundle holds `en` and `ru` (`build-app.sh:105-110, 148, 164`), and
  the words fall back to `.main` when no bundle is set (`WidgetWords.swift:26-33, 47-50`).
- p2a rewrites `UpdateInstallTests.swift` (+335, −52 since `cf847d0`).
- Two kinds (`WidgetOptions.swift:21-34`), each in small, medium and large
  (`BatteryPulseWidget.swift:33, 51`); `WidgetSourceTests.swift:259` expects 2 intents.
- `WidgetPlacements` counts no answer, a failure and an empty answer as every kind placed
  (`WidgetReloadPlanner.swift:242-265`); `launchReason` at :223.
- `WidgetRefresher` holds the battery and accessory observations, skips Demo Mode, and keeps
  `lastSeenLanguage` (`WidgetRefresher.swift:29-61, 79-89, 188-237`).
- `HistoryRecorder`'s minute tick starts whatever the recording setting, sleeps with 15 seconds of
  tolerance, and its `recordNow` returns while recording is off or Demo Mode shows
  (`HistoryRecorder.swift:37-62, 77, 84`); `History/` takes the default modes
  (`HistoryStore.swift:236, 260`).
- `HistoryStatistics.averageDrainPercentPerHour` is `nil` before 30 minutes and 3 points on
  battery (`History.swift:217-282`); the History page shows "Average drain", "%@ per hour", "On
  battery" and "Charging sessions" (`HistoryView.swift:268-281`).
- `DeviceStore` creates its folder 0700 and its key 0600 on a temporary file before moving it
  (`DeviceStore.swift:66-86`).
- What's New: `WhatsNew.version` is 0.7.0 (`UpdateViews.swift:390`), shown when the last seen
  version is below it (`Updates.swift:272-275`); the count's row for updaters from before 0.7.0
  (`UpdateViews.swift:419-434`; `VersionCounter.swift:23, 92-95`).
- `release.yml`'s notes check requires `## What's new in <version>` (`release.yml:41-64`).
- `MotionGuardTests` bans `.timer`, `.relative` and `.offset` styles and the reference format style
  in the widget, with one helper allowed (`MotionGuardTests.swift:35-38, 164-176`).
- SR's printed part is 28,380 bytes, under MS's 28,500 limit (MS:4474-4483; `wc -c`).
- 0.7.0's day test pins the two MVP kinds under 100 app-initiated reloads a day
  (`WidgetReloadPlannerTests.swift:342-351`), the bound P2 §8.10 set for all four kinds
  (`ebe6547:docs/plans/0.7.0/widgets.md:457-458`), as INV ENG-16 and RD's exit criterion (RD:832)
  do.
- MS's `prepare` installs its base whenever the Mac runs another version (MS:2188-2191), exempt
  from the higher-build rule (MS:739-748); its After publishing reads About, What's New, History,
  the settings, the menu bar and Login Items, and asks D3-history, D3-settings, D3-login-item and
  D3-notifications (SR:413-426; MS:333, 4323-4324). `ci.yml:200` runs `bash -n` on
  `scripts/quick-check.sh`, and no 0.8 branch touches it. 0.6.2's code names none of 0.7's four
  settings keys (`git grep` at `v0.6.2`).
- The catalog holds 766 keys, none with plural variations; the reused keys of §8 are among them.
- The sizes of §9 (AC70:172; `scripts/size-budget.json`).
- 0.8's six preparation branches fork from `cf847d0`; none is in `main`; x1a adds
  `ChartSummary.swift` (`origin/claude/080-x1a`).
- Apple: the entitlement key reference (PF-1; its file-access introduction also lists POSIX
  world-readable locations among what a sandboxed app reaches, §11); WWDC23 10103 on added
  parameters (PF-2, said of a migrated SiriKit intent); the reload budget (PF-11);
  `CFBundleVersion`'s form (B-1); per-app language and "you may need to quit and then reopen it"
  (W-15 item 2); `Bundle.preferredLocalizations(from:forPreferences:)` (W-15 item 1);
  `Text(_:tableName:bundle:comment:)`, which shows the key when its table has none (PF-5). Not
  verified by Apple: the sheet following the system's language (PF-6), which rests on a DTS
  engineer's opinion about iOS and on Session A.

**Conflicts, and which record holds:**
- **Where the clock goes:** P7 (`ebe6547`, PLAN.md:2040-2042, 2692) says 0.8, "the maintainer's
  decision"; `main` (R:978-983, 1016-1021; AC70:162; RD's note item 3) says 0.7.1, a technical
  choice. `main` is the later record and holds.
- **W-7's device choice:** P7 §2.2 (PLAN.md:304) says an `AppEnum`; W71 §8.5 and INV FEA-12 say an
  entity unless queries fail. This plan ships both shapes (§2.3 item 9).
- **History's extra large:** P2 §8.4 lists it; no kind declares extra large in 0.7.x (§2.3 item 8).
- **RD C1** still ties the two widgets' 1.0 counting to 0.7.0 (RD:257-262); W-18 restates it.
- **W71's "likely deleted" integration branch:** it is deleted.
- **Accented mode on the Mac:** the HIG's table and Apple's accented-rendering article disagree
  (PF-8; P7:3567-3572).
- **RD C10's "every chart has a descriptor"** (RD:347-353, naming the app's charts) against §2.3
  item 13's one label per widget chart (HIG Charts allows one succinct label for a small chart).
  This plan reads C10 as the app's charts [inference]; W-18 asks RD to say so.
- **RD C14 item 5's "what Automatic shows in each size"** (RD:402-407) against Q-W4's placed large
  widgets getting the History chart in place of their last two rows (W71 §8.5): this plan reads
  the chart as its own parameter's, never part of Automatic (P2 §8.5, §8.17), so Automatic's
  detail list is unchanged [inference]; the notes say what placed widgets show (§13), and Look 1
  question 2 lets the maintainer keep the eight rows instead.

**Unverified:**
- PF-1 at 8-12 KB, for a file written while no widget process ran, and on macOS after 27.0.1.
- PF-2 on macOS 27 with the ad-hoc extension; PF-3; PF-5 at run time; PF-6; PF-7; PF-9; PF-10
  for 0.7.0.
- Whether the widget's sandbox alone would refuse a read of `History/` (§11).
- That `currentConfigurations()` lists only BatteryPulse's own widgets, so none placed reads as an
  empty answer and the feed is written with every section (§2.3 item 2).
- Whether a language chosen for BatteryPulse alone reaches the extension without help on macOS 27
  (W71; AC70:163). W-15 doesn't depend on it.
- Whether VoiceOver reads the widget's Russian labels with a Russian voice under an English system.
- The cost of the redraw trick (W-17 item 5) on the Mac; the sandbox-denial log predicate (W-17
  item 7); how 0.6.2 draws widgets configured under 0.7.0 for step 2's first half's minutes
  (§6.6; Session A saw configurable widgets survive a reinstall of 0.6.1, AC70:73).
- Every [estimate] in §1, §6, §9 and §10.

---

## Appendix C: facts 0.7.1 records (filled during the release)

Empty until the work starts.
