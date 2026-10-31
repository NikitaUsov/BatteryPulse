# BatteryPulse 0.7.1: the widgets 0.7 didn't build

This file holds what BatteryPulse 0.7 designed for its widgets and didn't build, moved here at
0.7.0's release (its D3), so 0.7.1 starts from it:
- the feed and the two widgets that read it, 0.7's stretch: W-5 (the feed), W-6 (the History
  widget) and W-7 (the iPhone & iPad widget);
- the widget following the app's own language (0.7's W-0 item 8);
- 0.7's M5 checks, which Session R would have run;
- for later, W-9.

The maintainer decided on 2026-10-31 to release 0.7.0 without its M5 session (Session R and its
logged day) and to move the stretch and the widget's language to 0.7.1, not to 1.1 as 0.7's plan had
it. 0.8 follows 0.7.1. The session tools beside this file (`m5-session.sh`, its helpers,
`SESSION-R.md` and the launchers) are 0.7.0's, copied with their paths moved here, and
`0.7.0-appendix-c.md` is 0.7.0's whole Appendix C, which records what 0.7 shipped and measured.

**Where its references lead.** The sections taken from 0.6.2's plan (P2) keep their numbers (§8.3,
§8.5, §8.8, §10), as 0.6.2's D3 kept them when it moved P2's §8 to §10 into 0.7.0's plan folder, so
"P2 §8.5" or "Q-W4" still finds its text here. Every other reference is to a file that left the
repository with 0.7.0's plan folder, readable at `<keep>` in `refs/pull/13/head` (the last commit of
0.7.0's release PR that holds `docs/plans/0.7.0/`), or to one that stays:
- **Inside the sections taken from P2,** a bare section, package or row is P2's: a §8 or §9 section
  that isn't here (§8.1, §8.2, §8.4, §8.6, §8.7, §8.9 to §8.17, §9 with §9.1) and the W0 rows are in
  `docs/plans/0.7.0/widgets.md`; "Appendix C" is P2's own, with Session A's and Session B's rows, in
  `docs/plans/0.7.0/0.6.2-appendix-c.md`, and their reports are in `docs/plans/0.7.0/sessions/`; the
  rest of P2 (§1 to §7, WP-…, "PLAN") is in the history of 0.6.2's release PR's head,
  `refs/pull/12/head`.
- **Everywhere else,** "plan-0.7.0", "0.7's plan" and a bare W-n, G7-n, Q7-n, D-n or section number
  are 0.7.0's `docs/plans/0.7.0/PLAN.md`; its Appendix C is also beside this file, as
  `0.7.0-appendix-c.md`.
- RD and INV are `docs/plans/1.0/ROADMAP.md` and `docs/plans/1.0/INVENTORY.md`, and CL is
  `CLAUDE.md`.

A file:line in the moved text was written against v0.6.1 (P2) or v0.6.2 (0.7's plan): re-resolve it
at v0.7.0 before code.

---

## What 0.7 shipped that this builds on

- **Two kinds,** each in small, medium and large: Battery (0.6's kind string, now an
  `AppIntentConfiguration` with `BatteryWidgetIntent`) and Accessories (`AccessoriesWidgetIntent`).
  Extra large isn't declared (the look check's question 3 = 3); BatteryCore keeps its two-panel plan
  and the intent keeps `.systemExtraLarge` in Details' sizes, so the family can come without
  changing a shipped parameter. A family is only ever added (P2 §8.13).
- **The model in BatteryCore** (`Sources/BatteryCore/Widget/`): `WidgetOptions`, `WidgetLayoutPlan`
  and `AccessoriesWidgetPlan`, `WidgetTimelinePlan`, `WidgetAccessibility`, `WidgetTextBudget`,
  `WidgetRoute` with `PageID`, `WidgetIntentManifest` (`scripts/widget-manifest.json`, the names that
  freeze), `WidgetReloadPlanner` with `WidgetPlacements`, and `ReadCoalescer`; tested on Linux.
- **The build:** `scripts/build-app.sh` runs Apple's App Intents metadata processor on the widget,
  and `scripts/appintents-check.swift` checks the metadata against the manifest and the catalog.
- **The frozen surfaces** of ROADMAP's 0.7 decisions: the kind strings, the intent and
  parameter names, every option's raw value, the Details entity's ids, the sizes offered,
  Automatic's meaning per size, the `PageID` and `WidgetRoute` strings with the unregistered
  `batterypulse` scheme, and the settings key `lastSeenLanguage`.
- **The widget's privacy:** its entitlements are the sandbox alone; it reads IOKit and, through
  `MacAccessoryProvider().read()`, the accessory batteries, and no file of ours; it makes no
  request. W-5 changes the first two: one read-only exception and one file.
- **Not seen on the M5:** none of it was, since Session R didn't run. The section "0.7's M5 checks"
  below is that debt.

---

## The feed and its widgets (0.7's stretch: W-5, W-6, W-7)

### What 0.7's plan added to P2's design

Specified in P2 §8.3, §8.5 (History, iPhone & iPad, feed-only options), §8.8 and §8.14 (below).
0.7's plan added only:
- **The gate** (RD §3.2): they run only if all of these hold:
  - W0-3 passed with A or A′ (it did, with both; the feed uses A, §2.2);
  - Q-W3 is yes (decided 2026-10-22, following the maintainer's M-1 answer);
  - M-1 is no (decided 2026-10-22, by the maintainer);
  - the MVP has merged with budget left.

  The budget condition no longer applies: the maintainer moved the three packages to 0.7.1 on
  2026-10-31 (`0.7.0-appendix-c.md`, "The release"). The other three still hold.
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

Elsewhere, 0.7's plan said for the stretch:
- **Order:** W-5, then W-6; W-7 after W-5. The catalog takes W-6's and W-7's keys after the
  widget packages that shipped (plan-0.7.0 §5).
- **Storage:** `Widget/feed.json` is the one new file, so D1's storage round trip expects exactly it
  (plan-0.7.0 D1); the feed holds only what the widgets show (no `Devices/key`, no UDID or serial,
  no Demo data), in a folder that is 0700 with a file that is 0600, at most 8-12 KB, rewritten at
  once on Clear History, Forget, or turning off device reads or recording (plan-0.7.0 §11).
- **Names and identifiers:** device names get `.privacySensitive()`, like accessory names; a device
  is identified by its `DeviceKey` string, an HMAC-derived key, never a UDID or a serial (plan-0.7.0
  §11; P2 §8.3, §8.5).
- **Energy:** the History kind refreshes hourly, iPhone & iPad every 30 minutes, never closer than
  15 minutes (plan-0.7.0 §10); their reload policies arrive with W-6 and W-7, in
  `WidgetReloadPlanner` (plan-0.7.0 W-4).
- **Size:** charts are always a `Path`; Swift Charts only if it costs under 15 KB of the widget's
  `__text` (plan-0.7.0 §9, P2 §8.12).
- **Strings:** about 15-25 new keys [estimate]: P2 §8.5's History and iPhone & iPad parameters and
  states, among them "Open BatteryPulse to update" and "This device was forgotten"; the device
  titles are shown verbatim and aren't catalog keys (plan-0.7.0 §8, W-10 item 2).
- **Guards:** `SecurityGuardTests` gains W-5's one file-reading file in the widget (the reader), and
  `LocalizationCatalogTests` the new intents' literal forms (plan-0.7.0 W-10 items 2 and 4).
- **Accessibility:** `WidgetChartSummary` lands in W-6; if W-6 doesn't ship, 0.8's A11Y-01 builds it
  (plan-0.7.0 §2.5).
- **The Charge Limit's number:** the sandboxed widget can't read it; it would get it only through the
  feed, once 0.8 finds a source (plan-0.7.0 W-14).
- **Docs:** the release notes get the new widgets with a privacy line about the feed; the guide's
  and README's Privacy sections say what the feed holds (DOC-08); CLAUDE.md's "signed with only the
  app-sandbox entitlement" gains the read-only exception (plan-0.7.0 §12, §13 step 2).
- **A parameter added to a shipped intent:** W-6's History chart and its feed fields add a parameter
  and Details ids to `BatteryWidgetIntent`, which 0.7.0 shipped. Whether a placed widget keeps its
  choices when a parameter is added is what Session R's step 4.4 was to show (RD C14 item 5; the M5
  checks below), so 0.7.1 checks it before release.

### 8.3 Data sources and the bridge

| Data | Source | Works today? |
|---|---|---|
| Charge, state, estimate, health, condition, cycles, capacities, voltage, temperature (pack sensor), adapter watts, external power, optimized-charging hold, battery power, Mac power use, adapter input, cell voltages (registry and its children) | the widget's own IOKit read | yes |
| Low Power Mode, thermal state | the widget process's `ProcessInfo` | yes |
| Accessory batteries | the widget's own one-shot `MacAccessoryProvider.read()` | **W0-4** |
| History (series, statistics, time on battery) | the app's store | **needs the bridge (W0-3)** |
| iPhone and iPad (last reading) | the app's `devices.json` | **needs the bridge (W0-3)**; MobileDevice never runs in the widget |
| SMC live values (current and voltage within seconds) | the SMC | no (sandbox); not needed at widget cadence |
| Charge limit reached | `ChargerData.NotChargingReason` bit 24 (0x01000000) while paused at the limit, seen once in Session A's read-only capture (P2 Appendix C); the configured percentage is in no registry key, so the widget can say "paused at the limit" but not which limit | not yet: FEA-35 (`docs/plans/1.0/INVENTORY.md`). 0.7's W-14 shows the paused state (P1; whole to 0.8 without a redacted fixture by plan-0.7.0's C1, G7-18); the configured number is FEA-35's 0.8 half |

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

**Since 0.7:** the accessory row is answered (W0-4 passed; W-8 reads them in the widget), so the
feed never carries accessory levels; the Charge Limit's "at limit" state shipped with W-14, and its
number is FEA-35's 0.8 half. The feed uses candidate A (W0-3 passed with A and A′ in Session A).

### 8.5 Configuration: the History and iPhone & iPad parts

From P2 §8.5. 0.7 shipped the rest of it: the Battery parameters but the History chart, the details
catalogue's own fields, the attention row and the Accessories kind's MVP options.

**Battery** (`BatteryWidgetIntent`), the parameter that waits for the feed:

| Parameter | Type | Default | Notes |
|---|---|---|---|
| History chart | bool, large and up (`When(widgetFamily:)`) | on in large and extra large, from the release that ships the feed; placed large widgets get it too (Q-W4, decided by delegation) | **ships only with the feed (W-5).** It owns the sparkline and the History chart, which are never part of Automatic, and takes the last two detail rows (§8.17) |

**The details field catalogue,** the fields that wait for the feed (`BatteryWidgetField`, raw values
frozen once shipped; 0.7 shipped them as the Details entity `BatteryWidgetDetail`'s ids):

| Field | Source | Phase | Notes |
|---|---|---|---|
| Average drain over the last hour | feed | stretch | only in the release that ships the feed |
| Time on battery since unplugged | feed | stretch | only in the release that ships the feed |

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

**Feed-only options:** an option that needs the feed ships only in the release that ships the feed
(W-5). That covers the History chart, Average drain, Time on battery, and the History and
iPhone & iPad kinds. App Intents parameters, cases and summaries are build-time metadata, so an
option can't be hidden at run time, and removing one later breaks frozen raw values.

When the feed is temporarily missing or older than 2 hours (the app not running), a feed-backed
widget shows its last data with dates and one line, "Open BatteryPulse to update".

**Empty and error states,** the rows that wait for the feed:

| Kind | State | Shows | Opens |
|---|---|---|---|
| iPhone & iPad | reads off | "Turn on Read iPhone and iPad batteries in BatteryPulse" | Devices intro |
| | on, none remembered | "Connect an iPhone or iPad with a cable" | Devices intro |
| | chosen device forgotten | "This device was forgotten"; the edit sheet offers the rest | Devices intro |
| | feed missing or older than 2 h | the last readings with their dates, plus "Open BatteryPulse to update" | Overview |
| any | Demo Mode | never shown: the feed builder skips `DeviceKey.demo` and writes nothing while the monitor is overridden | — |

### 8.8 Privacy, with the feed's hardening

From P2 §8.8 (INV SEC-08). 0.7 shipped its accessory half: names with `.privacySensitive()`, no
hardware-derived identifier, the widget's own files without `dlopen`, `dlsym`, `URLSession` or
`Network`, and only the provider's one-shot `read()`. The feed's half is W-5's:

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

### The packages

From P2 §8.14, with 0.7's estimates:

| ID | Package | Depends on | Phase |
|---|---|---|---|
| W-5 | The feed: builder, writer hooks in the app (recorder, device and accessory monitors), reader, the entitlement, the security pins. Linux decoder tests: truncated, oversized, future-dated, wrong-version, mismatched-length and NaN inputs, and names with control or bidirectional characters | W0-3, Q-W3 | stretch |
| W-6 | History kind; the Battery kind's feed fields and History chart | W-5 | stretch |
| W-7 | iPhone & iPad kind (entity query over the feed, or `AppEnum` only) | W-5 | stretch |

---

## The widget following the app's own language

From 0.7's W-0 item 8 (0.6.2's Session B, F8-ru):

**The widget's language** (0.6.2 Session B's F8-ru). The widget showed English after its
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

**What 0.7 shipped of it:** W-4's part. `WidgetRefresher.endPreviousExtension(versionChanged:)` keeps
the app's effective language in the settings key `lastSeenLanguage`, and at a launch in another
language it ends the widget extension and reloads every kind (`WidgetReloadPlanner.launchReason`,
tested on Linux). So a widget no longer keeps the old language's render after a change of the
system's language.

**What 0.7.1 builds:** the widget's own choice of language, W-3b's part above: the widget picks its
`.lproj` from the app's language list at each render, read through the feed (W-5) or, if W-5 waits,
through a read-only shared-preference exception for the app's `AppleLanguages` alone. Either changes
the widget's reads or entitlements, so it goes through the posture check, `SecurityGuardTests` and
the M5 session, whose Russian step switches the language the way a user does (W-12's part above).
The guide's Language section then says what the widget follows (W-10's part; 0.7.0's guide doesn't
say it yet).

---

## 0.7's M5 checks, which Session R would have run

0.7.0 shipped on CI's evidence alone: both jobs with warnings as errors, the Linux tests and guards,
the macOS job's build, tests, packaging, size report, signing posture, install and launch, and the
widget previews, plus three look checks the maintainer answered on CI's pictures
(`0.7.0-appendix-c.md`, "0.7's own" and "The release"). 0.7.1's M5 session, run from the tools
beside this file (`SESSION-R.md` is Session R's runbook, with a note at its top), checks
what Session R would have, on 0.7.1's release candidate:
- **Placed widgets across the update** (Session R step 2, G7-2): a small and a medium Battery widget
  placed under 0.6.2 (static), then the in-app update to a configurable build. 0.6.2 → 0.7.0 itself
  was never checked; the notes and the guide say to add a widget again if it is gone or blank.
- **The gallery in every size** (step 3), Battery large and Accessories small, medium and large,
  against CI's previews.
- **The edit sheet** (step 4): Custom with four details, time left, monochrome, the update time
  always; the sheet keeping the choices; the sheet in Russian (G7-13); Details' chooser listing the
  fields (W0-1 (b)); and step 4.4, a parameter added to the shipped intent keeping the placed
  widget's choices (RC-P, then RC-U2 above it), which W-6 needs (above).
- **Rendering modes and places** (step 5, G7-4): the desktop and Notification Center, every Icon &
  widget style.
- **Time and language** (step 6, G7-3): time left counting down by the minute without a sign, in
  English and Russian; 12- and 24-hour time; the widgets in Russian after the app's language
  changes; the version count's toggle on, then greyed under Never, in both languages (W-13).
- **Accessibility and Text size** (step 7, G7-12): the accessibility tree against the label builder.
- **Clicks** (step 8, G7-9): each page, with and without a window, and with BatteryPulse quit.
- **Plug, unplug and accessories** (step 9, G7-8, G7-17): the reloads per kind, and
  `currentConfigurations()`' counts against the widgets placed.
- **The Charge Limit** (step 9b, G7-18): "Charged to limit" on the M5, its Russian screenshot.
- **Step 11's optional items:** 0.6.2's WP-18 Xcode items (SUI-17, SUI-19's timing, SZ-10's icon)
  and the menu bar item on a dark bar, which 0.6.2's Session B couldn't check and C-1 gave to
  Session R's GUI phase.
- **The logged day** (G7-11, G7-16): per kind, the reloads requested and delivered, the share and the
  median delay; the widget's reads and their time; crash reports and faults, which must be 0.
- **F12** (G7-15): a candidate built as 0.5.99 updating itself to the published release.
- **After publishing** (plan-0.7.0 §6.4): the update from the previous release with placed widgets,
  About, What's New once, the count's `counted` line (logged at notice since W-10, so `log show`
  finds it) and the release's count at 1 or more, History, the settings, `codesign` and `xattr`, the
  login item, notification permission, and the first day's widget against the popover.
- **What W-10 couldn't see:** the What's New window's three rows and the count row at 520 pt in
  Russian, and the widget drawn without extra large's views in every declared family on a Mac.

The candidates (RC-U as 0.6.99, RC-F as 0.5.99, RC-P and RC-U2) need the build-number clock first,
which moved to 0.8 (ROADMAP's 0.8 entry), or another way to keep each candidate's build number above
the installed release's: 0.7.0's is `release.yml`'s run number.

---

## Later: W-9

From P2 §8.14 and §8.5, and plan-0.7.0 §1 ("Not in 0.7"): after 1.0 at the earliest, only if asked
(RD §4.1).

| ID | Package | Depends on | Phase |
|---|---|---|---|
| W-9 | Refresh on Battery and Accessories, XL portrait, per-row links, specific accessories, the XL dashboard (Q-W10) | W-3 | later |

- The Refresh button: W0-1 (c) showed that a button's `perform` runs in the widget extension
  (Session A), so W-9 knows where its performs run; a button stays its own accessibility element.
- "Why it isn't charging" as a widget field (FEA-20) waits for captures that prove the causes; the
  Charge Limit's part shipped with W-14 (the `systemChargeLimit` field).
- **Later: choosing specific accessories**, with an entity id that is never `AccessoryBattery.id`.
  That id can be brute-forced back to a Bluetooth address, and its doc comment allows only two
  copies outside memory (`Accessory.swift:120-130`).
  - The later id is `AccessoryWidgetID`: "acw-" plus FNV-1a 64 of the kind and the name the user
    sees, with an ordinal for duplicates. It is frozen in §8.13.
  - `Accessory.swift`'s comment lists widget configurations as a place where only this id appears.

---

## 10. The maintainer's questions and their answers: the widget block

From §10 of 0.6.2's plan (answered 2026-10-22). Q-W1 is the maintainer's own answer, and Q-W3
follows from his answer to M-1 (no paid Apple Developer Program account, `docs/plans/1.0/ROADMAP.md`
§6); he delegated every other question here ("do it by best practices, as you see fit"), so each is
recorded with its recommended answer and marked "decided by delegation". 0.7's own questions (Q7-1
to Q7-10) are in plan-0.7.0 §14.

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
  right (plan-0.7.0 §14: two panels, Battery and Power); otherwise later, which
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

**What 0.7 settled of them** (plan-0.7.0 §14 and the look checks of 2026-10-31):
- Q-W2: Battery and Accessories shipped in 0.7; History and iPhone & iPad wait for the feed here.
- Q-W4: the three main visuals, the four main values and level colours shipped; large's eight
  details were signed off in the look check (question 2).
- Q-W5: an end two or more days ahead shows no time rather than a weekday.
- Q-W10: question 3 was 3, so extra large isn't declared; BatteryCore keeps its two-panel plan for a
  later release.
- Q-W8, Q-W9 and Q-W11: a click anywhere opens the widget's page (shipped); no Refresh button
  (W-9); device names with `.privacySensitive()` come with W-7.
