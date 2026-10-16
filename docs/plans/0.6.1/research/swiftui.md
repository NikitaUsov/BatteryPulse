# BatteryPulse 0.6.1: SwiftUI and Observation (verified)

Date: 2026-10-15. This is the adversarial verification of `v061/swiftui/research.md`, written to
stand alone. Repo state checked: branch `claude/nice-faraday-k08mhb` at `fb41ff5` (0.5.0 plus the
widget fix; 0.6.0 is not merged, so line numbers will drift). Scope: SwiftUI view updates,
Observation, state and environment, Table, Swift Charts, task lifetimes, previews, profiling.

Verification method: every cited Apple page and WWDC transcript was re-read from the saved dumps
(`v061/swiftui/tr/`, `v061/swiftui/docs/`, `glass/tr/wwdc2026_269.txt`) or re-fetched
(`v061/swiftui/verify/`). Every file a recommendation names was opened. Three claims were tested
with the Swift 6.4.1 toolchain on Linux (`v061/swiftui/verify/probe/`, `.../bench/`).

## 1. Verdict summary

The researcher's overall reading holds. The app already follows most of Apple's SwiftUI
guidance:
- live data is split into `MainDetail`
- Raw Data is rebuilt off the main actor
- the selection overlay is separate
- `Card` stores its built content
- the environment holds one Equatable `MotionPolicy`
- there is no `AnyView` and no `ObservableObject`

Grep confirms all of this. What changed after verification:

| ID | Verdict | Change |
|---|---|---|
| SUI-01 | Corrected | `import os` can't go into `BatteryMonitor.swift` (compiled on Linux); subsystem must be the bundle ID; add the "menu bar only" idle scenario |
| SUI-02 | Corrected | proposed `.diacriticInsensitive` folding changes search results (Russian U+0439/U+0438, U+0451/U+0435); keep `localizedCaseInsensitiveContains` on one joined string |
| SUI-03 | Verified | P1 kept; added the Audio Graphs check for changed series values |
| SUI-04 | Corrected | the main-actor work is the smaller part; folded in the health-chart dates; `Task.detached`/`@concurrent` cross-reference |
| SUI-05 | Rejected as written, replaced | recording is on by default and writes a sample about every 60 s, so "reload on new sample" saves no reloads; the real cost is re-decoding JSON (measured ~85–90 ms for 10,080 lines on the Linux VM); merged into energy E13, raised to P1 |
| SUI-06 | Corrected, P1 → P2 | Apple's "avoid storing closures" explicitly exempts closures that take a parameter (both closures here do); the real reasons are comparability (an inference) and a bundle lookup per unit symbol |
| SUI-07 | Corrected | "pass a Bool to `CopyReportButton`" rejected: it would move the snapshot read into `MainView` and re-render the whole split view on every tick |
| SUI-08 | Corrected | `Observations` yields the current value first (SE-0475), so use `.dropFirst()` for parity; compiled with Swift 6.4.1; shared with swift SW-09 and energy |
| SUI-09, 10, 11, 12, 15, 17, 18, 19 | Verified (small fixes) | see items |
| SUI-13 | Verified | the shared `selectedTime` binding may defeat skipping; measure |
| SUI-14 | Verified, P3 | the per-instance `@AppStorage` cost is an inference |
| SUI-16 | Corrected | "Glass Cards" is a sanctioned exception in CLAUDE.md, not a violation; removing it loses a feature, so measure only |
| SUI-20 | Rejected | `appearsActive` is documented as an appearance hint, not a lifecycle signal; no perf or size gain |
| SUI-21 | Corrected | the code doesn't have this problem; a one-line CLAUDE.md convention instead of a regex test |
| SUI-22 | Added | `.task` on the 2027 SDK runs synchronously until the first `await` (`Task.immediate`); a rule for new code |

## 2. Sources (re-checked 2026-10-15)

| Key | Source | Checked |
|---|---|---|
| W25-306 | WWDC25 "Optimize SwiftUI performance with Instruments", https://developer.apple.com/videos/play/wwdc2025/306/ | transcript: formatters created in body were the hot frames; "create these strings in advance and cache them"; "avoid storing values that update really often, such as geometry values or timers, in the environment" |
| W26-268 | WWDC26 "Profile, fix, and verify: Improve app responsiveness with Instruments", https://developer.apple.com/videos/play/wwdc2026/268/ | transcript: "Profiling a release build is crucial"; OSSignposter with the points-of-interest category; Top Functions; **Run Comparisons** filtered "to the exact same os_signpost interval"; new **Swift executors** instrument; `@concurrent` on the task initializer moves work off the Main Actor |
| W26-269 | WWDC26 "What's new in SwiftUI", https://developer.apple.com/videos/play/wwdc2026/269/ | transcript: `@State` is a macro; classes in `@State` are lazy and created once (back-ported to macOS 14); a default value plus an assignment in `init` is an error ("use before initialization"); ContentBuilder improves type checking with Xcode 27 for any deployment target; agent skills "SwiftUI Specialist" and "What's New In SwiftUI", exported with `xcrun agent skills export` ("This will create markdown files") |
| W26-321 | WWDC26 "Dive into lazy stacks and scrolling with SwiftUI", https://developer.apple.com/videos/play/wwdc2026/321/ | transcript: estimated off-screen sizes; filter at the data level, not with zero-or-one subviews per element; set views up in the initializer, not `onAppear`; absolute content offsets are estimated |
| W26-258 | WWDC26 "What's new in Xcode 27", https://developer.apple.com/videos/play/wwdc2026/258/ | transcript: previews and playgrounds in the canvas for a Swift file outside any project. It says **nothing** about SwiftPM executable targets. |
| W25-266 | WWDC25 "Explore concurrency in SwiftUI", https://developer.apple.com/videos/play/wwdc2025/266/ | not re-read; claim (Sendable closures of `Shape.path`/`Layout`/`visualEffect`/`onGeometryChange`) is unused below |
| W23-10160 | WWDC23 "Demystify SwiftUI performance", https://developer.apple.com/videos/play/wwdc2023/10160/ | transcript: measure, identify, optimize, re-measure; "string interpolation can often be expensive … looking up values from bundles can be expensive"; List/Table gather all IDs eagerly; `TableRow` is always one row; streamlined `ForEach(data)` in Table; `_printChanges` is debug-only |
| W23-10149 | WWDC23 "Discover Observation in SwiftUI", https://developer.apple.com/videos/play/wwdc2023/10149/ | saved transcript; property-level tracking |
| W24-10155 | WWDC24 "Swift Charts: Vectorized and function plots", https://developer.apple.com/videos/play/wwdc2024/10155/ | transcript: vectorized plots handle an entire collection; group data by style; prefer stored over computed properties |
| D-PERF | "Understanding and improving SwiftUI performance", https://developer.apple.com/documentation/xcode/understanding-and-improving-swiftui-performance | live doc: 500 µs orange / 1000 µs red; lanes; Show Causes; "Avoid storing closures in views … **You don't need to do this for action closures … or closures that require a parameter**, like the closure you pass to ForEach" |
| D-TASK | `task(id:name:priority:file:line:_:)`, https://developer.apple.com/documentation/swiftui/view/task(id:name:priority:file:line:_:) | live doc: `name:` is a no-op before macOS 26.4; "The task is created by `Task.immediate`. Its action begins execution synchronously until it suspends at the first `await`." A sibling `task(id:name:executorPreference:…)` exists, macOS 26.4+ (re-fetched) |
| D-OBS | `Observations`, https://developer.apple.com/documentation/observation/observations | live doc: macOS 26.0+; `init(_:)` and `untilFinished(_:)` |
| SE-0475 | https://github.com/swiftlang/swift-evolution/blob/main/proposals/0475-observed.md | re-fetched: Implemented (Swift 6.2); "upon the first call to next the value will be obtained … to 'prime the pump'", so **the first element is the current value** |
| D-APPEARS | `EnvironmentValues.appearsActive`, https://developer.apple.com/documentation/swiftui/environmentvalues/appearsactive | re-fetched: "Whether views and styles in this environment should prefer an active appearance"; on macOS, the key window |
| D-LINEPLOT | `LinePlot`, `VectorizedChartContent`, https://developer.apple.com/documentation/charts/lineplot | live doc: macOS 15+; `init(_:x:y:series:)`; `VectorizedChartContent` has no interpolation modifier |
| D-PREV | "Previews in Xcode", https://developer.apple.com/documentation/swiftui/previews-in-xcode | live doc: `#Preview`, `@Previewable`, `PreviewModifier`. Nothing on packages or executables. |
| D-GLASS | "Applying Liquid Glass to custom views", https://developer.apple.com/documentation/swiftui/applying-liquid-glass-to-custom-views | quote "can degrade performance" confirmed in `glass/data/` |
| SW-CPERF | https://github.com/swiftlang/swift/blob/main/docs/CompilerPerformance.md | flags confirmed in the 6.4.1 frontend: `-debug-time-function-bodies`, `-debug-time-expression-type-checking`, `-warn-long-function-bodies <n>`, `-warn-long-expression-type-checking <n>` |
| Local probes | `v061/swiftui/verify/probe/probe.swift` | Swift 6.4.1 `-swift-version 6` type-checks `@concurrent func`, `Task(name:)` and `Observations({ … }).dropFirst()` |
| Local bench | `v061/swiftui/verify/bench/bench.swift` (`swiftc -O`, Linux x86_64 cloud VM) | decoding 10,080 `HistorySample`-shaped JSON lines, the way `HistoryStore.readLines` does (one `JSONDecoder.decode` and one `Data` copy per line): **83–91 ms** per pass. The M5 will differ; measure there. |

Cross-references to the sibling 0.6.1 research:
- `v061/energy/research.md`: E13 History decode cache, timer tolerances.
- `v061/swift/research.md`: SW-05 `Task.detached` → `@concurrent`; SW-09 `Observations`.

Each overlapping item below names one owner, so the work isn't done twice.

## 3. Profiling toolkit (corrected)

Runs on the maintainer's Mac (macOS 27, Xcode 27). Nothing here runs in the Linux cloud session,
and Instruments on the hosted `xcode-27` runner is unconfirmed (assume not).

1. **Release build, SwiftUI template.** Open `Package.swift` in Xcode 27, scheme `BatteryPulse`,
   Product › Profile (W26-268: it builds Release; "profiling data from debug builds can be
   misleading"), template **SwiftUI** (D-PERF). Use the **Swift Concurrency** template for
   main-actor questions; it includes the Swift executors track (W26-268).
   - CLI alternative, after `scripts/build-app.sh`:
     `xcrun xctrace record --template 'SwiftUI' --time-limit 60s --output before.trace --launch -- BatteryPulse.app`
   - The template string is not confirmed for Instruments 27. Run `xcrun xctrace list templates`
     first.
2. **Scenarios.** Run the same steps every time:
   - (a) Overview open for 30 s of 2 s polling.
   - (b) Switch every page twice.
   - (c) History: toggle 24 Hours / 7 Days and sweep the pointer over each chart.
   - (d) Raw Data: type a 6-letter filter, clear it, open the inspector.
   - (e) Open and close the menu bar panel 5×.
   - (f) Demo Mode tour.
   - **(g) Added:** no window open, menu bar item only, 10 min, with the default label and with
     power shown in the label (which polls). This is where the app spends most of its life. The
     always-on `MenuBarLabel` re-runs its body on every snapshot change, and nothing in (a)–(f)
     measures it in isolation.
3. **Read** Long View Body Updates (orange > 500 µs, red > 1000 µs), Summary: All Updates (body
   count per view type per 2 s tick), Show Causes for unexpected updates, Hitches, and Swift
   executors for main-actor work (D-PERF, W26-268).
4. **Compare** with Run Comparisons, both runs filtered to the same signpost interval (W26-268).
5. **Signposts** (corrected; see SUI-01): `OSSignposter(subsystem: "io.github.nikitausov.BatteryPulse", category: .pointsOfInterest)`.
   This is the subsystem the existing `Logger` in `Updates/UpdateInstaller.swift:333` uses.
6. **Body-change logging** is for debugging only and never committed:
   `let _ = Self._printChanges()` (W23-10160). `Self._logChanges()` is undocumented and
   unconfirmed for macOS 27.
7. **Type-check hot spots** (corrected):
   - Command, from a clean scratch path so every file recompiles:
     `swift build -c release --scratch-path /tmp/bp-tc -Xswiftc -Xfrontend -Xswiftc -debug-time-function-bodies 2>&1 | grep -E '^[0-9.]+ms' | sort -rn | head -30`
   - This must run on macOS: the views are `#if os(macOS)`, so Linux type-checks none of them.
   - Output format, confirmed on 6.4.1: `0.01ms<TAB>file:line:col<TAB>name`.
8. **Binary size:** after `scripts/build-app.sh`, run
   `stat -f%z BatteryPulse.app/Contents/MacOS/BatteryPulse` and `size -m` (size research owns
   this).

## 4. Recommendations (verified)

Each item gives: practice · why (source) · where now (checked) · how · measure · benefit ·
risk · effort · priority.
- **P1** = do in 0.6.1.
- **P2** = do in 0.6.1 if time allows.
- **P3** = opportunistic.

### SUI-01: Build a profiling baseline before changing anything (Verified, corrected) — P1, S
- **Practice:** measure first with named intervals on a Release build, and verify each fix with
  a comparison run.
- **Why:** W23-10160 (measure → identify → optimize → re-measure). W26-268 (os_signpost
  intervals in the points-of-interest track; Run Comparisons on the same interval; "Always
  profile a release build").
- **Where now:** no signposts anywhere. The only `os` use is the `Logger` in
  `Updates/UpdateInstaller.swift:333`.
- **How:**
  - Add a small `Signposts` enum **in the app target** (`App/Signposts.swift`, `import os`) with
    intervals `history.load`, `raw.rebuild`, `raw.filter`, `page.switch`.
  - For `monitor.refresh`: `Sources/BatteryKit/BatteryMonitor.swift` is compiled and tested on
    Linux (it imports only Foundation and Observation; BatteryKitTests runs it). A bare
    `import os` there **breaks the Linux build**. Either guard it with `#if canImport(os)`, as
    `SystemNotifications.swift` does with `canImport(Darwin)`, or bracket only the app-side
    callers.
  - Use the bundle-ID subsystem above, not "BatteryPulse".
  - Record scenarios (a)–(g) for 0.6.0. Keep the numbers (not the traces) in a short
    "Performance baseline" section of `docs/ROADMAP.md`.
- **Measure:**
  - body count per type per tick
  - orange and red long updates
  - hitches
  - main-actor time inside each interval
  - for (g): CPU time and wakeups over 10 min (Activity Monitor; the energy research has the
    command-line tools)
- **Benefit:** foundation; it makes every other item verifiable.
- **Risk:** none at runtime. Signposts are low-overhead when not recorded; confirm in the first
  comparison run.

### SUI-02: Raw Data: build display rows once per reading (Verified, corrected) — P1, M
- **Practice:** keep formatting, interpolation and bundle lookups out of `body`, and cache the
  display strings (W23-10160; W25-306; D-PERF "perform the calculation asynchronously, and cache
  the result").
- **Where now (checked):** `Main/DeveloperView.swift`.
  - The Decoded cell calls `RawValueText.string(for:)`. Its default argument
    `BatteryFormatter.app` is a computed `static var` (`App/Localized.swift:12`), so it builds a
    formatter whose unit closure runs `String(localized:)` on every formatted value.
  - The Description cell calls `RawValueText.summary`, which is a `Bundle.main.localizedString`.
  - `row.value` is a computed `property.description` (`RawKeyGlossary.swift:1127`).
  - `filteredSections` runs in `body`. While the filter is non-empty, `matches` repeats up to 5
    `localizedCaseInsensitiveContains` calls (with formatting and a bundle lookup) for every
    row. That happens on every keystroke, every new reading (every 2 s while the page is shown)
    and every selection change, because `body` reads `selection` through `inspectedRows`.
  - With the filter empty, the guard returns early, and only the visible cells format.
  - The page is developer-only (hidden by default), and the code comment says "hundreds of
    rows".
- **How:**
  1. In `rebuild()`, map `RawRow` to an app-side display row holding `path`, `valueText`,
     `decodedText`, `summaryText` and `searchText`. The detached task already exists; per SW-05
     it should become a `@concurrent` function, which also propagates cancellation (a
     `Task.detached` does not).
  2. Cells show the stored strings. `RawValueText` stays the single producer of those strings.
  3. **Correction:** don't fold with `.diacriticInsensitive`, as research.md proposed. Today's
     `localizedCaseInsensitiveContains` is case-insensitive only. Diacritic folding would make
     "U+0438" match "U+0439" and "U+0435" match "U+0451" in Russian, which changes results. Instead build
     `searchText = [path, value, decoded ?? "", summary ?? "", englishSummary ?? ""].joined(separator: "\n")`
     and filter with **one** `searchText.localizedCaseInsensitiveContains(query)` per row.
  4. That gives the same results as today's five-way OR, because a search field can't enter
     "\n", so no match can straddle two fields.
  5. Pre-folding (`lowercased(with:)` plus `contains`) is an optional second step, only if
     `raw.filter` still shows up.
  6. Keep the table on `RawRow.ID` (String path) so selection and context menus keep working.
- **Measure:** the `raw.filter` and `raw.rebuild` signposts. `DeveloperView.body` duration while
  typing in scenario (d), before and after. Time Profiler: `localizedString` and `formatted`
  under `DeveloperView.body` should vanish.
- **Benefit:** typing and live-update speed on Raw Data. Readability: the cells and `matches`
  become trivial.
- **Risk:** low.
  - Locale/region changes now apply on the next reading (every 2 s), not instantly.
  - The app language can't change without a relaunch anyway.
- **Owner:** this research.

### SUI-03: History: no localization or interpolation per chart point (Verified) — P1, S
- **Practice:** hoist constants out of chart `ForEach` loops and precompute plotted values
  (W23-10160 on bundle lookups and interpolation; W24-10155 "add them as stored properties").
- **Where now (checked):** `Main/HistoryView.swift` `powerChart`, per point:
  - `String(localized: "Battery")`
  - `String(localized: "Mac")`
  - `"battery-\(point.segment)"`
  - `"load-\(point.segment)"`
  - That is 4 operations per point. A day is ≤1,440 points, so ≈5,800 per evaluation. A week is
    ≈1,008 points (10-minute buckets).
- **How:**
  1. `let battery = String(localized: "Battery")` and `let mac = String(localized: "Mac")`
     once, before `Chart {`. Reuse them in `chartForegroundStyleScale`.
  2. Series values: precompute them in BatteryCore (Linux-tested) as non-optional per-series
     arrays (see SUI-04). Or use `Int` series values (`segment * 2`, `segment * 2 + 1`).
- **Measure:** HistoryView/Chart body time during a period switch, before and after. Time
  Profiler: `localizedString` and `String(describing:)` samples under the chart should go.
- **Benefit:** speed (period switch, minute reload), energy.
- **Risk:** low.
  - Check visually that the two power lines and the gaps between segments still render the
    same.
  - Series values can surface in VoiceOver Audio Graphs. Check that it still reads acceptably,
    since an `Int` series reads as a bare number.
- **Owner:** this research.

### SUI-04: Build History chart data off the main actor, as one value (Verified, corrected) — P1, S–M
- **Practice:** move unavoidable work off the Main Actor with `@concurrent`, and verify with the
  Swift executors instrument (W26-268). D-PERF: "perform the calculation asynchronously, and
  cache the result".
- **Where now (checked):** `HistoryView.load()` is main-actor. After awaiting the store (decoding
  runs on the `HistoryStore` actor), it runs these on the main actor:
  - `HistoryPoint.points(from:bucket:)`: one `[HistorySample]` group per sample in the day view,
    plus 4 `compactMap` arrays per group
  - `HistorySpan.spans`
  - `HistoryStatistics(samples:)` over ≤10,080 samples
  - It does this every 60 s while History is visible, and on **every** visit: `MainView` gives
    the page `.id(selection)`, so the view and its state are recreated.
  - Missed by research.md: `healthCharts` runs `day.date()` for every daily summary on every
    HistoryView body. That builds a new Gregorian `Calendar` per day (`History.swift:142-152`).
- **How:**
  1. Add `struct HistoryChartData: Sendable, Equatable` in BatteryCore holding:
     - points
     - spans
     - statistics
     - per-series non-optional arrays for SUI-03
     - `hasTemperature`
     - dated daily points
  2. Give it a `static func make(samples:days:period:end:)` and Linux tests.
  3. Build it in a `@concurrent` function (SE-0461; Swift 6.2+; compiles on 6.4.1), or in a
     `HistoryStore` method. Both run off the main actor. With tools-version 6.0 and no
     `NonisolatedNonsendingByDefault`, a plain `nonisolated async` function already leaves the
     main actor, but `@concurrent` states it explicitly and survives a later switch to the
     new default (owner of that switch: swift research).
  4. The view keeps one `@State var chart: HistoryChartData?`.
  5. The period-switch `withAnimation(motion.change)` must still wrap only the assignment.
- **Measure:** Swift executors: no `HistoryView.load` frames on the Main Actor except the
  assignment. `history.load` main-thread time, before and after.
- **Benefit:** main-thread time on History visits. Readability: one state value instead of six.
  The absolute gain is probably a few ms per load. The bigger History cost is the decoding (see
  SUI-05R), so do both.
- **Risk:** low.
- **Owner:** this research (the `@concurrent` mechanics follow SW-05).

### SUI-05R: History reloads: cache decoded samples; keep a timer for the time axis (Replaces SUI-05) — P1, M
- **Research.md proposed:** key the reload on a "sample recorded" signal instead of the 60 s
  loop, "energy, less code".
- **Rejected as written, for two reasons:**
  1. Recording is on by default (`AppSettings.recordsHistory` defaults to `true`).
     `HistoryRecorder` writes a sample about every 60 s (`HistoryPolicy.interval`, plus extra
     samples on state changes). So a "reload on new sample" trigger reloads about as often as
     today. It improves freshness, not energy.
  2. With recording off, nothing new arrives. `end` (`domain`'s right edge) would then stop
     advancing and the 24 h / 7 d window would freeze. That is a visible regression.
- **The real cost:**
  - Every reload re-reads and JSON-decodes **every** sample of the period
    (`HistoryStore.samples` → `readLines`: one `JSONDecoder.decode` and one `Data` copy per
    line). That is up to 8 day files and ≈10,080 lines for 7 days.
  - Benchmark of that exact pattern: **83–91 ms per pass** on the Linux VM.
  - It runs every minute and on every History visit (see SUI-04).
  - Past days' files never change (appends go to today's file; pruning removes whole days).
- **Practice:** parse unchanged data once and cache it (energy E13, citing WWDC25 226).
- **How:** this is energy E13; implement it there, with these SwiftUI-side constraints:
  1. `HistoryStore` caches decoded samples per closed day file (key: day plus file size). For
     today's file, decode only the tail after the last offset.
  2. `HistoryView` keeps a minute timer for the axis, with `tolerance: .seconds(15)` (energy:
     the missing tolerance at `HistoryView.swift:77`).
  3. Optionally, also reload on a "sample recorded" signal for freshness, e.g. after plugging
     in.
  4. Clear History must still invalidate the cache.
- **Measure:** `history.load` signpost duration. Time Profiler: `JSONDecoder` samples per reload
  (expect today's file only).
- **Benefit:** energy and speed.
- **Risk:** cache invalidation:
  - Clear History
  - legacy migration
  - pruning
  - a day rolling over while the app runs
  BatteryCore tests can cover all four on Linux.
- **Effort:** M. **Priority:** raise E13 to P1. **Owner:** energy E13.

### SUI-06: `BatteryFormatter` without a closure, and Equatable (Corrected) — P2, S
- **Correction to "why":** D-PERF's "Avoid storing closures in views" goes on: "You don't need to
  do this for … closures that require a parameter, like the closure you pass to ForEach". Both
  closures research.md cites take a parameter:
  - `BatteryFormatter.symbol: (Unit) -> String`
  - `SelectionOverlay.value: (HistoryPoint) -> String?`
  So Apple's rule does not mandate this change.
- **Remaining, valid reasons:**
  1. W23-10160 ("looking up values from bundles can be expensive"): `BatteryFormatter.app` is a
     computed `static var`, and every formatted value runs `String(localized:)` for its unit
     symbol. This happens in each body of Overview, Power, Health, History, Compact, Popover,
     Settings and `MenuBarLabel` (twice per body: `title` and `Phrases.batteryIcon`).
  2. Inference, not Apple-documented: a closure-typed stored property can't be compared, so a
     subview holding a formatter can't be skipped when its other inputs are equal. That makes
     this a prerequisite for SUI-07's narrow inputs (e.g. `CapacityBars`, `PowerFlowView`).
- **How:**
  1. Replace the closure with `public struct UnitSymbols: Sendable, Equatable` (six Strings, with
     `.english`).
  2. Make `BatteryFormatter: Equatable`.
  3. `static let app` with `Locale.autoupdatingCurrent` (region changes still apply; unit
     symbols are fixed per launch, as the app language is).
  4. The widget keeps `BatteryFormatter()` (English).
  5. Update `BatteryFormatterTests`.
  6. The `SelectionOverlay` enum is optional (readability only). The overlay also stores a
     `ChartProxy`, so it wouldn't become skippable anyway.
- **Measure:**
  - Time Profiler: `localizedString` under `formatted` calls.
  - Show Causes for `CapacityBars` once SUI-07 gives it narrow inputs.
- **Benefit:** small speed gain; enables SUI-07; readability.
- **Risk:** low. The public API changes (app, widget, tests; `bpulse` doesn't use it).

### SUI-07: Narrow live-data inputs per subview, only where Instruments shows cost (Verified, corrected) — P2, M
- **Practice:** each view depends only on what it shows (W23-10160 "reduce view values to only
  the data they actually depend on"; W23-10149).
- **Where now (checked):**
  - `BatteryMonitor` only reassigns `snapshot` when something besides the timestamp changed
    (`isSameState`), so identical readings re-render nothing.
  - But current and voltage change on most 2 s ticks. Each tick then re-runs `MainDetail` and
    the page (Overview, Power or Health), the compact window and the popover.
  - HealthView's identity, capacity and cycle sections change a few times a day.
- **How:**
  - Only after SUI-01 numbers. Extract static sections into small structs with Equatable inputs
    (e.g. `HealthIdentitySection(name:manufacturer:)`, `CapacitySection(...)`), plus SUI-06's
    Equatable formatter.
  - **Rejected part:** "pass a Bool to `CopyReportButton`". The button's own read of
    `monitor.snapshot == nil` keeps the dependency inside the toolbar item. Passing a Bool means
    `MainView.body` reads `monitor.snapshot`, which re-renders the whole `NavigationSplitView`
    (sidebar, toolbar) on every tick. That is exactly what the `MainDetail` split exists to
    avoid (`MainView.swift` comment). Leave it.
  - Don't split `BatteryMonitor` into many observable properties.
- **Measure:** Summary: All Updates, body counts per tick in scenario (a), before and after.
- **Benefit:** small speed and energy gain while windows are open.
- **Risk:** low.

### SUI-08: `Observations` instead of re-armed `withObservationTracking` (Verified, corrected) — P2, S (shared)
- **Practice:** observe `@Observable` state from non-view code with `Observations` (SE-0475,
  Swift 6.2, Implemented; D-OBS macOS 26.0+).
- **Where now (checked):** `App/HistoryRecorder.swift:54`, `App/WidgetRefresher.swift:25` and
  `App/BatteryNotifier.swift:36`. Each one:
  - calls `withObservationTracking { _ = monitor.snapshot } onChange: { Task { @MainActor in …; observe() } }`
  - creates one task per change
  - misses any change made before the re-arm. HistoryRecorder re-arms only after
    `await recordNow`, so changes during the store write are lost until the next change.
- **How:**
  ```swift
  task = Task(name: "…") { for await _ in Observations({ monitor.snapshot }).dropFirst() { … } }
  ```
  - Type-checked with Swift 6.4.1.
  - Cancel it in a `stop()`.
  - **Correction:** SE-0475 yields the current value first ("prime the pump"). Without
    `.dropFirst()`, launch adds an extra `recordNow(refreshing: false)`, a widget reload
    evaluation and a notification evaluation that don't happen today. A low-battery alert
    could fire at launch.
  - Keep exact parity unless the maintainer wants the launch evaluation.
- **Measure:** the existing tests; Swift Concurrency template: one long-lived task per client
  instead of one per change; no extra history sample at launch (check `samples/<today>.jsonl`).
- **Benefit:** readability, correctness, less code.
- **Risk:** low with `.dropFirst()`. Values are coalesced, but the consumers only need the
  latest value.
- **Owner:** swift SW-09 (P1 there). Energy has the same item. Do it once.

### SUI-09: `@State` macro semantics; optional `AppServices` (Verified) — P3, S
- **Practice:** initialize `@State` at the declaration, and don't both default it and assign it
  in `init`. Observable classes in `@State` are created lazily, once (W26-269; D-STATE).
- **Where now:** `App/BatteryPulseApp.swift` already assigns `@State` without defaults in `init`,
  with a comment about the macro. No `State(initialValue:)` is left (grep).
- **How:** grep for `@State` with default values in views that also have a custom `init`.
  Optionally group recorder, notifier and refresher into one `@MainActor final class
  AppServices` for readability.
- **Measure:** Xcode 27 build has no new diagnostics.
- **Benefit:** readability.
- **Risk:** low.

### SUI-10: Name long-lived tasks (Verified) — P2, S
- **Practice:** `.task(name:)` and `Task(name:)`, so the Swift executors and Concurrency tracks
  show names (D-TASK: `name:` takes effect from macOS 26.4; W26-268).
- **Where now:**
  - `HistoryView` `.task(id:)`
  - `DeveloperView` `.task(id: monitor.reading)`
  - `PopoverView` `.task(id:)`
  - `SettingsView` `.task`
  - `CopyReportButton` `.task(id: copied)`
  - unstructured tasks in `HistoryRecorder`, `BatteryMonitor` (live refresh, follow-ups) and the
    observers (SUI-08)
- **How:** add names, e.g. "History reload" and "Raw Data rebuild".
- **Measure:** the names appear in Instruments.
- **Benefit:** profiling readability.
- **Risk:** none.

### SUI-11: Table rows builder; measure per-cell `.help` (Verified) — P3, S
- **Practice:** Table gathers IDs eagerly. `TableRow` is one row. `ForEach(data)` in a Table
  builds the rows itself (W23-10160).
- **Where now:**
  - `RawRow.id` is the path String.
  - Rows use `ForEach(section.rows) { row in TableRow(row) }` inside dynamic `Section`s, which
    W23-10160 calls fine.
  - The Key, Value and Description cells have `.help`.
- **How:** use the shorter `ForEach(section.rows)` (readability). Remove a tooltip only if
  measured in Other Long Updates or Long Platform View Updates.
- **Benefit:** readability.
- **Risk:** UX change only if a tooltip is dropped.

### SUI-12: Vectorized `LinePlot` spike for the power chart (Verified) — P3, M
- **Practice:** use vectorized plots for large, uniformly styled collections, with stored plotted
  properties (W24-10155; D-LINEPLOT, macOS 15+, `init(_:x:y:series:)`).
- **How:** spike only if SUI-03 and SUI-04 leave chart updates orange or red.
  - Power chart: two `LinePlot`s over the non-optional arrays from SUI-04.
  - Charge and temperature use `.interpolationMethod(.monotone)`, which `VectorizedChartContent`
    doesn't document. Keep `LineMark` there, or accept linear curves after a screenshot
    comparison.
- **Measure:** Time Profiler and the SwiftUI instrument during a period switch; screenshot diff
  at 24 h and 7 d.
- **Risk:** medium (look, legend, Audio Graphs).

### SUI-13: Split the large views into structs with value inputs (Verified) — P2, M
- **Practice:** extract subviews that have their own dependencies (W23-10160 "dependencies …
  are apparent at its use site"; D-PERF).
- **Where now (`wc -l`):** `HistoryView.swift` 432, `SettingsView.swift` 443, `Components.swift`
  407, `UpdateViews.swift` 352, `DeveloperView.swift` 333. The HistoryView chart properties
  re-evaluate on every HistoryView state change (`days`, `hasLoaded`, `end`).
- **How:**
  - `ChargeChart`, `PowerChart`, `TemperatureChart` take `HistoryChartData` (Equatable) plus
    `domain` plus the shared `$selectedTime`. `HealthTrendCharts(days:)` goes in `Main/History/`.
  - Settings: one struct per pane.
  - Components: one file per component.
  - Moving `Components.swift` or `SettingsView.swift` requires updating the file lists in
    `MotionGuardTests` and in CLAUDE.md's Liquid Glass list.
- **Caveat:** all three charts share one `selectedTime` binding (the hover rule shows on every
  chart). Whether SwiftUI can skip a chart whose only changed input is a `Binding` isn't
  documented. Measure with Summary: All Updates when only `days` changes.
- **Benefit:** readability and foundation, some speed.
- **Risk:** low (refactor). Watch the motion keys and the catalog's unused-key test.

### SUI-14: Card surface via the environment (Verified, inference noted) — P3, S
- **Where now:** every `Card` and `CardGroup` holds `CardSurfaceSetting` (two `@AppStorage`, one
  `@Environment`).
- **How:** compute `CardSurface` once at the window root, next to `.motionPolicy()`, and publish
  it as an Equatable `@Entry`. This value changes rarely, which suits the environment (W25-306).
- **Caveat:** that per-instance `@AppStorage` observation costs anything measurable is an
  inference.
- **Measure:** Show Causes when toggling Glass Cards.
- **Benefit:** small.
- **Risk:** low.

### SUI-15: Lazy-container rules for the 0.6.0 device and accessory lists (Verified) — P2, S
- **Practice (W26-321, W23-10160):**
  - one subview per `ForEach` element
  - filter in data, never with `if` in a row
  - set rows up in `init`, not `onAppear`
  - no absolute offsets
  - no `AnyView`
- **Where:** the 0.6.0 lists (not on this branch; grep finds no lazy stacks today).
- **How:** add this checklist to the 0.6.1 review prompts.
- **Measure:** SwiftUI instrument while scrolling a long Demo Mode list.

### SUI-16: Glass Cards: measure the cost, don't remove (Corrected) — P3, S
- **Correction:** research.md calls the option "contrary to the project's own rule". CLAUDE.md
  lists it as a sanctioned exception ("`Main/Components.swift` (the Developer option 'Glass
  Cards', off by default)"), and `MotionGuardTests` enforces that list.
- **How:**
  - Measure Hitches and Energy Impact with the option on and off (D-GLASS: too many effects
    outside containers can degrade performance; the cards already share one
    `GlassEffectContainer` via `CardGroup`).
  - Document the numbers.
  - Removing it is a functionality loss, so it is out of 0.6.1's "no lost functionality" scope
    unless the maintainer decides otherwise.

### SUI-17: Previews fed by Demo Mode data (Verified, unconfirmed premise) — P2, M
- **Practice:** `#Preview`, `@Previewable`, `PreviewModifier` (D-PREV).
- **Unconfirmed:** whether Xcode 27 previews work in a SwiftPM **executable** target. W26-258
  only shows previews of a stand-alone file outside a project.
- **How:**
  1. Spike for 30 minutes.
  2. If they don't work, a `BatteryPulseUI` library target that holds the views, with the
     executable keeping `@main` (`Package.swift` and `scripts/build-app.sh` change).
  3. Wrap previews in `#if DEBUG` so the release binary is unchanged.
  4. Previews will show English: localized strings come from `Bundle.main` of the preview host.
- **Measure:** previews render; release binary size unchanged.
- **Risk:** none at runtime. The target split is a build change.

### SUI-18: Use Xcode 27's SwiftUI Specialist skill as an audit checklist (Verified) — P2, S
- **Why:** W26-269: "export them with the 'xcrun agent skills export' command. This will create
  markdown files".
- **How:** export the skill on the Mac (the exact arguments are unverified). Feed it to the 0.6.1
  review agents, and commit nothing from it, since it is Apple's content.

### SUI-19: Find slow-to-type-check bodies (Verified, command corrected) — P3, S
- **Why:** W26-269 (ContentBuilder speeds up type checking with Xcode 27 for any deployment
  target; deep `Section`/`Group`/`ForEach` nesting is the classic cause); SW-CPERF.
- **How:** run §3 item 7 on the Mac. For bodies over ~100 ms, extract subviews (SUI-13).
  Optionally add
  `-Xswiftc -Xfrontend -Xswiftc -warn-long-expression-type-checking=200` locally to get
  warnings. Not in CI: compiler warnings don't fail CI today.
- **Unconfirmed:** whether custom `@ViewBuilder` parameters (`Card`, `CardGroup`) gain anything
  from ContentBuilder.

### SUI-20: `appearsActive` instead of the `onReceive` publisher (Rejected)
- **Reason:** `appearsActive` is documented as a styling hint ("whether views and styles … should
  prefer an active appearance"; on macOS, the key window), not a lifecycle event.
  - Using it to refresh the login-item state would fire on window focus changes rather than
    when the app becomes active, so the semantics differ.
  - The current `.onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification))`
    in `Settings/SettingsView.swift:131` is a documented SwiftUI modifier.
  - Combine is a system framework that SwiftUI already links, so there's no size, speed or
    energy gain.
  - An async `notifications(named:)` loop in `.task` would be equivalent. It's optional, and
    not worth a 0.6.1 item.

### SUI-21: Keep fast-changing values out of the environment (Corrected) — P3, S
- **Why:** W25-306 ("avoid storing values that update really often … in the environment").
- **Where now:** the code doesn't have this problem (`\.motion` is Equatable and changes rarely).
- **How:** add one line to CLAUDE.md Conventions ("never put `snapshot`, `reading`, dates or
  geometry into the environment"). A regex source-scan test would guard a hypothetical, with
  false-positive risk. Optional.

### SUI-22 (Added): Code must assume `.task` runs synchronously up to its first `await` — P2, S
- **Why:** D-TASK (2027 SDK): "The task is created by `Task.immediate`. Its action begins
  execution synchronously until it suspends at the first `await`."
  - Work placed before the first `await` now runs inside the view update.
  - The `executorPreference:` variant (macOS 26.4+) only affects nonisolated work called
    from the task.
- **Where now:** every current `.task` does only trivial work before its first `await`.
  - `HistoryView`: guard, then `await load()`. The first suspension is the store call.
  - `DeveloperView.rebuild`: guard.
  - `CopyReportButton`: guard.
  - `SettingsView`.
- **How:** a review rule for 0.6.0 and 0.6.1 code: nothing heavy before the first `await` in a
  `.task`. Offload with `@concurrent` (SW-05).
- **Measure:** Swift executors.
- **Risk:** none.

## 5. Rejected or demoted, and why (summary)

- **SUI-05 as written** ("reload on new sample, energy"): with recording on by default, it
  saves no reloads, and with recording off it freezes the time axis. Replaced by SUI-05R /
  energy E13 (decode cache, measured).
- **SUI-06 at P1 with Apple's "avoid storing closures" as the reason:** Apple exempts closures
  that take a parameter. Demoted to P2, with the real reasons.
- **SUI-07 "pass a Bool to `CopyReportButton`":** it would widen the dependency to the whole
  split view.
- **SUI-02's `.diacriticInsensitive` folding:** it changes Russian search results.
- **SUI-16's framing as a rule violation:** Glass Cards is a documented exception; removing it
  loses a feature.
- **SUI-20:** `appearsActive` is an appearance hint, and the change gains nothing.
- **SUI-21 as a test:** it guards a problem the code doesn't have; a convention line is enough.
- **"Considered and not recommended" in research.md** (snapshot split, `scenePhase` for
  occlusion, `Canvas` glyph, `drawingGroup` on charts, blanket `.equatable()`): agreed.

## 6. Open questions (not confirmed for macOS 27 / Swift 6.4)

1. Previews in a SwiftPM executable target in Xcode 27 (SUI-17).
2. The `xctrace` template name for SwiftUI in Instruments 27, and whether `xctrace export`
   exposes the SwiftUI tables.
3. `Self._logChanges()` availability (undocumented).
4. A monotone interpolation for `LinePlot` (not documented; check Xcode 27 autocomplete).
5. The exact `xcrun agent skills export` arguments.
6. Instruments on the hosted `xcode-27` runner (assume not).
7. The cost of per-cell `.help` in `Table` (measure).
8. Whether SwiftUI skips a subview whose only changed input is a `Binding`, or that holds a
   `ChartProxy` (SUI-13, SUI-06). Not documented; check with Show Causes.
9. The JSON decode time on the M5 for 10,080 history lines. The Linux VM figure (83–91 ms) is
   only an order of magnitude.

## 7. Recommended order for 0.6.1

1. SUI-01: baseline, with signposts in the app target and a guarded one in `BatteryMonitor`.
2. SUI-05R / E13: History decode cache, plus a timer tolerance.
3. SUI-03: hoist per-point lookups in the power chart.
4. SUI-04: `HistoryChartData` built with `@concurrent`.
5. SUI-02: Raw Data display rows with a single search string.
6. SUI-08: `Observations` with `.dropFirst()` (swift SW-09 owns it).
7. SUI-13 plus SUI-06: split HistoryView, Settings and Components; Equatable formatter.
8. SUI-10 and SUI-22: task names, and the `.task` synchronous-start rule.
9. SUI-17 and SUI-18: previews spike; SwiftUI Specialist skill as a checklist.
