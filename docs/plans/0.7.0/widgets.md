# BatteryPulse 0.7: the widget design, from 0.6.2's plan

This file holds §8, §9 with §9.1, §10's widget answers (Q-W1 to Q-W13) and Appendix C's W0 rows of
BatteryPulse 0.6.2's plan, moved here at 0.6.2's release (its D3) with their section, row and
question numbers kept, so a reference such as "P2 §8.5" or "Q-W4" still finds its text. Any other
reference in them (§3, §6, §7, WP-…, Appendix B, "PLAN") is to that plan, readable in the history of
the 0.6.2 release PR's head (`refs/pull/<n>/head`), and its whole Appendix C is in
`0.6.2-appendix-c.md` beside this file.

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

## 10. The maintainer's questions and their answers: the widget block

From §10 of 0.6.2's plan (answered 2026-10-22). Q-W1 is the maintainer's own answer, and Q-W3
follows from his answer to M-1 (no paid Apple Developer Program account, `docs/plans/1.0/ROADMAP.md`
§6); he delegated every other question here ("do it by best practices, as you see fit"), so each is
recorded with its recommended answer and marked "decided by delegation". 0.7's own questions (Q7-1
to Q7-10) are in `docs/plans/0.7.0/PLAN.md` §14.

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

## Appendix C: the W0 rows

The W0 rows of 0.6.2's Appendix C, with the two rows they lean on: the spike builds Session A
installed, and Session A's swaps. A row marked "final" comes from Session A's final report
(`sessions/A.md` beside this file, 2026-10-24), which replaced its interim report of 2026-10-23.

| Fact | Shown by | Decides |
|---|---|---|
| W0-1 (CI half), 2026-10-22: **the metadata reaches the bundle.** On `claude/062-spike-widget`, `build-app.sh` collects the widget's Swift sources and release `.swiftconstvalues` and runs `xcrun appintentsmetadataprocessor` (Xcode 27.1, generator xcode-tools 27A9275) with the `AppIntentsMetadata.xcspec` options on the unstripped binary; the appex gets `Contents/Resources/Metadata.appintents/` (`extract.actionsdata` 7,700 B, `version.json`) and then strips, signs, passes the posture check and launches (runs 39794535282, 39806441696). The actions, the `AppEnum`, the entities and their queries, the `ParameterSummary` and its `When` clause are all extracted. **No `[AppEnum]` per-family `size:` overload compiles** with Xcode 27.1 at any deployment target (26.0-27.2); an array of an `AppEntity` does, and an integer literal per family is an exact size (min = max), so "up to N" needs `IntentCollectionSize(min:max:)`, untested. `Summary` strings aren't seen by `LocalizationCatalogTests` yet. Entity query and button behaviour at run time: Session A | CI; Session A | W-2, §8.11, §8.16 |
| W0-1 (run time), 2026-10-23 (final; the interim text held): **the edit sheets show the parameters** (W0-2-W-edit y). Battery: Layout (Automatic), Main value (Charge), Time (Clock time); Layout Custom adds Details, with 4 slots on medium, so the `ParameterSummary`'s `When` clause applies. The test widget: Main value, Details (4 on medium, more on extra large), Device. (c): the Refresh button's `perform` ran in the widget extension (`process=widgetExtension`), 3 times. (d): no summary line ("Show Charge") shows in either sheet (W0-1-test-edit n, for the summary only). (b): **not answered:** no `spike query` line, because the Device chooser was never opened; with Session A over, it passes to 0.7. The sheets close when Terminal takes focus, so the session read them from its own screen recordings | Session A | W-2; §8.11 (no summary text shows); §8.16 (W0-1 and (c) pass); (b): plan-0.7.0's G7-1 default (W-3a's review chooses per-slot `AppEnum` parameters before its merge) |
| Spike builds for Session A, 2026-10-22: SPIKE-C = v0.6.1 (`claude/062-spike-c`, run 39800982102, #277); SPIKE-I = 0.6.1 plus `-internalize-at-link` on the widget (`claude/062-spike-i`, run 39801168615, #278): widget binary 1,379,808 → 1,059,616 B (−23.2 %), `__text` 943,096 → 684,136 B (−27.5 %), DMG −7.4 %, the app untouched; SPIKE-W = the configurable battery kind plus the test kind, the feed writer and reader (A, A′), the click logger and the render logging, with `-internalize-at-link` (`claude/062-spike-widget`, run 39806441696, #282). All CI builds are version 0.0.0, so their automatic update check stays off (`isUnversioned`) | CI | G-15's size input; Session A's install order |
| W2, 2026-10-23: SPIKE-W's code (`a609487`) built again by `workflow_dispatch` (run 40002896511, #307), so W0-2 can be retested under a build number chronod hasn't cached (`56702f9`) | CI | Session A's W0-2 retest |
| W0-2, 2026-10-23 (final): **a widget placed by 0.6.1 survives its kind becoming an `AppIntentConfiguration` (Automatic default) when the descriptor fetch reaches the new extension, and the clean retest passed.** SPIKE-C over 0.6.1: 1 (the same places, current values); `pluginkit` 0.6.1 (7) → 0.0.0 (277), from `/Applications`. SPIKE-I over SPIKE-C: small 1, medium 1 (a second medium added under SPIKE-I renders the same); `pluginkit` 277 → 278; large and extra large not answered, since SPIKE-I's widget, like 0.6.1's, offers only small and medium. **The first SPIKE-W install** (282) left the placed widgets unable to reload: at the version change (20:52:19.590) chronod fetched the descriptors again and was answered within 2 ms by SPIKE-I's `BatteryPulseWidget` process, still running (SPIKE-W's started at 20:52:20), so it cached 282 with 1 static descriptor: no Edit item, no test widget in the gallery, and every reload failed with `CHSErrorDomain` 1103 ("Intent configuration is required but was not provided"). `WidgetRefresher.endPreviousExtension()` runs only at the new app's launch, after that fetch. `killall chronod` (20:59) kept those descriptors and dropped the cached snapshots, and only then did the widgets turn into grey placeholders (the interim put the grey at the install). **The reverse race:** 0.6.1 installed over SPIKE-W (21:05:08) cached SPIKE-W's 2 descriptors as version 7's, until chronod's maintenance refetched the descriptors with unresolved default intents (21:05:31); a cached descriptor without intents (the SPIKE-W case) never qualifies for that refetch, so it stays wrong until the next version change. SPIKE-W installed again by hand (21:06, the app quit and the extension ended first): chronod got its 2 descriptors from the new extension, two reloads failed at once (`CHSErrorDomain` 1050), then every one succeeded, and the widgets placed under 0.6.1 (small, medium) and under SPIKE-I (medium) redrew in today's look with fresh values. **The retest on W2** (#307, SPIKE-W's code; the order 0.6.2's installer takes, `56702f9`): over 0.6.1 at 21:45:27, the extension ended about 20 ms before the swap; chronod refetched 7 → 307 and got SPIKE-W's 2 descriptors (21:45:27.670); the only error was one placeholder reload at the swap (`NSCocoaErrorDomain` 4099, the old process's connection); every reload succeeded within 0.5 s; small 1, medium 1 (both mediums; the one edited in the sheets reloaded under its own intent). **Russian:** with `AppleLanguages (ru)` in the extension's container preferences, 2: the widgets turned Russian (the test widgets once Refresh redrew them), but the edit sheet stayed English. After the script installed 0.6.1 again over W2: 1, every Battery widget shows 0.6.1's values; the two test widgets (a medium and an extra large, a kind 0.6.1 doesn't have) keep W2's last picture | Session A | WP-16 item 6 (W2's order; F12 is the first run of the app's own); §8.16 (the row on the old extension answering); W-3; §8.11 and 0.7's session (the edit sheet doesn't follow the extension's `AppleLanguages`, so its Russian check needs another method); Session B's F8-ru (the extension's `AppleLanguages` works for the widgets, after a redraw); Session B's yes-list (two dead test widgets to remove, not one) |
| W0-3, 2026-10-23 (final): **A and A′ both work** under ad-hoc signing on macOS 27: every feed read logged "feed ok" with the 55 bytes the app wrote, for A and A′ alike (7 each before any mark, 3 in desktop-Dark, 5 in click-open; the Notification Center segments logged no feed line). **B wasn't tested:** SPIKE-W probes only A and A′ (its `SpikeProbes.Candidate`), so no line names B, and the interim's "still for Session A" couldn't be met. Whether a read saw data written while the widget wasn't running can't be told from the log, whose ages read back as N | Session A | §8.3, Q-W3 (its condition holds: W-5's feed stays 0.7's stretch); §8.3 doesn't use B either way |
| W0-4, 2026-10-23 (final): (1) **the sandboxed widget reads accessory batteries itself** ("spike accessories sources=2 accessories=1", the AirPods, before any mark, in desktop-Dark and in click-open). (2)-(3) the four Icon & widget styles ran on the desktop, focused and not, and in Notification Center, with screenshots, and the widgets redraw per style; but **no "spike render" line** reached the log from any process or segment, and the final report doesn't say why, so the rendering mode, `showsWidgetContainerBackground` and `redactionReasons` have no data and the screenshots stay §8.7's only evidence. (4) the medium Battery widget's `widgetURL` reached `application(_:open:)` ("spike click url scheme=batterypulse page=overview windows=1 active=true") with no window open and with the main window open. **New in the final report, against the interim's "no `NSUserActivity` arrives":** two clicks on the test widget's body, which sets no `widgetURL`, arrived through `application(_:continue:restorationHandler:)` as an `NSUserActivity` whose type is the configuration intent's type name (`SpikeWidgetIntent`, logged as `other`), with the userInfo keys `WGWidgetUserInfoKeyFamily` and `WGWidgetUserInfoKeyKind`, no `webpageURL`, and no window open. (5) the `widgetURL` reaches the app with no registered scheme (SPIKE-W registers none) | Session A | W-8 (passes); §8.7; §8.9 (the URL route, no scheme registered; §8.16's scheme row doesn't apply); §8.9's activity route and plan-0.7.0's "no activity handler" (W-3c, G7-9): a click on a widget without a `widgetURL` does arrive, typed by the intent rather than the kind string, so that choice holds only while every 0.7 widget sets one |
| W0-5, 2026-10-23 (final; not in the interim report): **VoiceOver** (the maintainer's photos, on 0.6.1 with SPIKE-W's test widget still placed; it spoke English): "In BatteryPulse, widget, 9 items", then "Three-Quarter-Charged Battery, image" (the level symbol by its SF Symbol name, the 75 % bucket at 80 %, not the charge), and one step inside, "In Three-Quarter-Charged Battery, image, content is empty". **The accessibility tree,** read through System Events (23:49; roles, descriptions and values only): Finder's desktop group holds one `AXGroup` per desktop widget, described "widget", with flat children. Medium: an `AXImage` described "image" with no label or value, then 8 `AXStaticText` ("83%", "Not charging", "Maximum capacity", "100%", "Cycle count", "51", "Temperature", "37.8 °C"): the 9 items VoiceOver counted. Small: the image and 2 texts. The test widget: 8 texts and an `AXButton`. No element pairs a label with its value, the symbol has no label, and the time-left lines split the letter from the value. **Text size: 2, no change:** at 17 pt the widgets were pixel-identical to a shot at the usual size minutes before | Session A step 4 | §8.15: its design already answers each finding (the symbol `accessibilityHidden`, one combined element per block whose label carries the value, each row "label, value"), as the report's own advice for 0.7 does; Text size doesn't reach desktop widgets on macOS 27.0.1, which answers §8.15's "unverified"; P1 (the Finder host, its row below) |
| W0-6, 2026-10-23 (final): **English,** 1: line b, with `sign: .never`, "2 hours, 0 minutes"; line a, without it, "-2 hours, 0 minutes" (the offset runs to a later date); no seconds; a zero minutes field still shows. **The tick,** 1: 65 s apart, on an unchanged 21:17 entry, a went to "-1 hour, 59 minutes" and b to "1 hour, 59 minutes" without a reload (the extra-large test widget too, 10 → 9 minutes on its 21:10 entry). **Russian,** 1: once Refresh redrew the widget under the extension's `AppleLanguages (ru)`, line b read the Russian for "2 hours 12 minutes", without the English comma, and line a the same with a minus sign; no seconds. A test widget not yet redrawn kept English, its live minutes too | Session A | Time parameter (time left stays, with `sign: .never`; §8.16's W0-6 row doesn't apply); §8.11 (the Russian form) |
| Session A's swaps (final; W0-2, WP-16 item 6): the script's pre-swap end of the widget extension took about 20 ms (by SIGTERM, the photo of Terminal) on W2's install and on 0.6.1's reinstall over W2, and 0 ms on prepare's reinstall of 0.6.1 before W2; each time chronod's refetch then reached the new extension (W0-2) | Session A (the script; the photo of Terminal) | WP-16 item 6's timings: the 0.5 s SIGKILL and the 1.5 s give-up are ample |
