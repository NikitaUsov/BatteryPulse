# App-views audit: adversarial verification

Source: `audit-app-views.md` (AV-01 to AV-14), checked against `6133b4f` (release 0.6.0) with
`git show 6133b4f:<path>`. HEAD is `a32bfae`. `git diff 6133b4f a32bfae` doesn't touch
`Sources/BatteryPulseApp/Main/`, `App/Localized.swift`, `App/ToneStyle.swift` or `HistoryStore.swift`,
so the audit's line numbers hold. It does touch `BatteryCore/BatteryPresentation.swift` (the widget
reload policy only, which matters for AV-04's merge order) and `Settings/` plus `WindowLook`.
Nothing in the repository was modified. The one experiment lives in `scratchpad/v061/avverify/`.

**About the user's two complaints.** The tile picker's selection covering the style, and Clear's
legibility, are in `Settings/` and `WindowLook`. They were addressed after `6133b4f` (`ec61436`,
`6584585`). None of the AV findings is about them. AV-08 is the only one that touches legibility on
the glass sheet, so its acceptance check names Clear explicitly.

## Experiment

- **E-AV1: RawRepresentable on an enum with associated values (Swift 6.4.1, Linux).** In
  `avverify/rr.swift`, a `Hashable, RawRepresentable` enum shaped like `SidebarItem` (literal cases
  plus `.device(String)`) counts its `rawValue` calls. Result: **`==` calls `rawValue` twice** and
  `hash(into:)` calls it **once**. Building a 3-element `Set` makes **7** calls. The stdlib's
  `RawRepresentable` defaults replace the synthesized `Equatable` and `Hashable`. Every comparison
  then builds two Strings, and the `.device` case concatenates and allocates. This refutes AV-03's
  premise (see below).

## Verdicts

| ID | Verdict | WP | Priority (verified) | One line |
|---|---|---|---|---|
| AV-01 | keep | WP-5 (the alert string goes in after WP-6) | P2 | Real silent failure. `fileExporter` matches History's, and no other exporter shares the page |
| AV-02 | keep-modified | WP-5 | P3 | Test for the `REDACTED` placeholder and the `serialNumber` key, not for raw key names |
| AV-03 | reject | — | — | E-AV1: `==` and `hash` would go through `rawValue`, which adds String work instead of saving it |
| AV-04 | keep-modified | WP-9 (after WP-5, which owns `Localized.swift`) | P3 | Keep only the rated-cycles helper and the small `Phrases` helpers. No hero or gauge component, no `stateWithPower` merge |
| AV-05 | keep | WP-3 | P3 | Confirmed stale text. A one-line `@AppStorage` |
| AV-06 | keep | WP-9 | P3 | Confirmed: the disabled button shows the wrong tooltip |
| AV-07 | keep-modified | WP-9 (it owns the glass list) | P3 | Fix the comment, but don't write a count into it |
| AV-08 | keep-modified | WP-3 (with the chart split); guard in WP-12 | P3 | A CLAUDE.md compliance fix, not an energy one. The look needs the maintainer's approval, Clear first |
| AV-09 | keep | WP-3 | P3 | Unused conformances. Fold it into SUI-04 |
| AV-10 | keep | WP-9 | P3 | `onChange(initial: true)` is the synchronous form. Optionally `RefreshWhenShown` too |
| AV-11 | keep-modified | WP-5 | P3 | Only the volts-digits rule moves, into `BatteryFormatter`, with a test. Drop the hex part |
| AV-12 | keep-modified | WP-3 | P2 | Log the failures. No `@State` dedup. The failure is "unreadable", not "corrupt" |
| AV-13 | reject | — | — | One read per user click (a few ms) is not measurable, and after E4a it's what keeps the report's SMC values fresh |
| AV-14 | keep-modified | WP-9 (inside SUI-13) | P3 | Placement notes for the Components split. No commit of its own |

## Details

### AV-01: Export Capture (keep, P2, WP-5)

**Confirmed** at `DeveloperView.swift:272-282`:
- `panel.runModal()` opens an app-modal panel.
- `try? PropertyListSerialization.data(…)` and `try? data.write(to:options: .atomic)` drop errors.
  A write into a read-only folder does nothing and shows nothing.

Checks against the proposal:
- **No exporter conflict.** Two `fileExporter` modifiers in one hierarchy are a known source of
  trouble. `git grep fileExporter` finds only `HistoryExport.swift:75`, which sits on `HistoryView`.
  `MainDetail` (`MainView.swift:309-322`) shows either History or Developer, never both. So the
  new modifier is alone on its page.
- **Same output.** The content type `.xml`, the default name and the bytes come from the same
  `PropertyListSerialization` call. So `bpulse --input` reads the file as before.
- **No reusable title.** The catalog's only "Couldn't …" titles are "Couldn't Check for Updates" and
  "Couldn't Export History". So the alert needs one new key. It goes in after WP-6 (§3.2), as the
  audit says.
- **The serialization error.** `PropertyListSerialization` can't fail on `foundationValue`, but
  SW-R12 makes a `do/catch` free here. The real failure path is the system's write, which reports
  through `onCompletion`.

Measure: as the audit gives it. The guard from the Demo Mode check (`!monitor.isOverridden`) stays
in `exportCapture()`.

### AV-02: Copy JSON redaction (keep-modified, P3, WP-5)

**Confirmed:** the redaction is done by hand at `DeveloperView.swift:259-266`. The pattern already
exists in BatteryCore (`RememberedDevice.swift:90`, `IDeviceCapture.redacted`).

**Wrong as written:**
- The fixtures are already redacted. All five `m5-macos27-*` captures hold `"REDACTED"`, 3 to 6
  times each.
- The JSON's key is `serialNumber`, not the raw names `Serial` or `SerialString`.
- So "expects neither `Serial` nor `SerialString`" tests nothing.

**Modified test:**
- Parse each `m5-macos27-*` fixture and encode its `snapshot.redacted` with Copy JSON's settings
  (`[.prettyPrinted, .sortedKeys]`, `.iso8601`).
- Expect that the output contains neither `"REDACTED"` nor `"serialNumber"`.
- This is the useful guard. Any present or future snapshot field fed from a key that
  `redactingSerialNumbers` replaces (anything with "serial", plus `ManufacturerData` and
  `MfgData`) would carry the placeholder into the JSON and fail the test.

Priority is P3, not P2: nothing leaks today. `bpulse --json` stays unredacted, frozen by §3.4. That
is noted only.

### AV-03: SidebarItem as RawRepresentable (reject)

The audit's own risk line expects the stdlib defaults to take over, and E-AV1 confirms it:
- With the conformance, every `==` builds two Strings and every hash builds one.
- `SidebarItem` is compared and hashed far more often than `selection` is parsed: `.id(selection)`,
  `.animation(_, value: selection)`, the List's selection tags, `developerPages.contains`, and
  `ForEach` with `id: Self`.
- So the change adds work.
- Avoiding that would take an explicit `==` and `hash(into:)`, which is more code than the 4-line
  wrapper it removes.
- The parser would become a second list of the 8 literal names. Today it is derived from
  `storageKey`, one source of truth.
- `SidebarItem` is app-only, so no Linux test would catch a mismatch.
- The parse it saves is a few string compares per `MainView.body`, and that body doesn't run per
  tick (UI-4).

Nothing measurable, and a real regression in hashing. Reject.

### AV-04: Duplicated presentation pieces (keep-modified, P3, WP-9)

**Rejected parts:**
- **`BatteryHero` and `GaugeRow`.** The three heroes aren't the same view:
  - Overview: a `Card`, 46 pt, `.title3`, a time line with `motion.fadeTransition`, the badge last.
  - Compact: no card but `.contentTreatment()`, 34 pt, `.callout`, spacing 16/2, an 84 pt glyph,
    the badge with `.padding(.top, 4)`, and an accessibility value of its own.
  - DeviceView: a subtitle line, then the badge, then a time line with a `ProgressView`.

  The proposed "detail Text?" input can't express DeviceView's order or its progress view. A
  component that can needs slots plus a compact flag, which is about as long as the code it
  replaces, and it risks pixel drift in 4 styles × 2 appearances × 2 languages. The gauge rows
  differ in every argument (caption, captionHelp, tier source, badge text, rating source).
  `GaugeTile` is already the shared piece.
- **`Phrases.stateWithPower(_ state:, watts:, _:)`.** It is not equivalent:
  - `DeviceView.statePhrase` (`:150-157`) only says "Charging at …". It never says "Discharging
    at …".
  - It uses `state(ChargeState)`, which has no "Charging on hold".
  - `Phrases.stateWithPower` (`Localized.swift:87-97`) does both.

  Merging them changes the iPhone page's text. Reject.
- **The `levelTier` recomputation.** A switch over a few comparisons. Not measurable.

**Kept parts:**
1. **Rated cycles.** Add `BatteryPresentation.ratedCycles(_ design: Int?) -> Int?` (nil unless
   above 0) and `fallbackRatedCycles = 1000`. Use them at `OverviewView:108`, `HealthView:61` and
   `DeviceView:217`. The text rows at `CompactView:108` and `HealthView:100` use the same nil-for-0
   rule.
   - The 0 case is real in the code: `MacPowerParser.swift:145` doesn't filter
     `DesignCycleCount9C = 0`.
   - In contrast, `IDeviceBattery.swift:188` filters it, and `cycleLifeUsed` guards `rated > 0`.
   - So on a Mac reporting 0, the gauge gets +inf or NaN and the caption reads "of 0 rated".
   - Add a Linux test with nil, 0 and 1000.
   - `bpulse` output doesn't change: `BatteryReport` already goes through `cycleLifeUsed`.
2. **Optional `Phrases.condition(for tier:)`.** It replaces `DeviceView.condition` and
   `healthWarning`'s fallback, which agree on every tier `healthWarning` is called with (it's
   called only when the badge is inverted, so never with `.normal`).
3. **Optional `Phrases.deviceListFailed`.** It replaces the fabricated
   `.timedOut(seconds: 0)` at `DeviceView:336`. `deviceUnavailable` maps `.timedOut` to the same
   literal and calls it.

The literals don't change, so neither does the catalog. `Localized.swift` belongs to WP-5, so this
lands in WP-9 after WP-5, the order SUI-07 already requires.

Measure:
- `swift test --filter BatteryPresentation`.
- On the M5, the Overview, Health and iPhone cycle gauges are unchanged (rated 1000).

### AV-05: History's recording sentence (keep, P3, WP-3)

**Confirmed:**
- `HistoryView.swift:165` reads `AppSettings.recordsHistory`, a plain `UserDefaults` read
  (`AppSettings.swift:82-83`).
- `SettingsView.swift:435` already uses `@AppStorage(AppSettings.recordHistoryKey) … = true`, the
  same default as `?? true`.

The fix adds no string, and the key, type and default stay as they are (§3.4).

### AV-06: Copy Report tooltip (keep, P3, WP-9)

**Confirmed** at `MainView.swift:394-415`. `canCopy` is false for `.devicesIntro` and
`.accessories`, but `help` falls to `default`. That shows "Copy a plain-text report without serial
numbers", or "Not available in Demo Mode" on a page where a report is never available.

`MainView` isn't listed in any package, so WP-9 (view structure) takes it.

Add to the measure: on the M5, check that `.help(Text(verbatim: ""))` shows no empty tooltip box.
If it does, use the existing "Connect the device to copy a report" for the intro, and no `.help`
on Accessories.

### AV-07: The demo bar comment (keep-modified, P3, WP-9)

**Confirmed:** `DemoView.swift:108` says "The only custom Liquid Glass in the app". CLAUDE.md and
`MotionGuardTests.glassAllowList` list three files. The comment is unchanged at HEAD.

Reword it without a number, which would rot: "One of the few places with custom Liquid Glass
(CLAUDE.md and `MotionGuardTests` list them): a control that floats over content." WP-9 owns the
glass list, so the comment changes with it.

### AV-08: The chart readout's material (keep-modified, P3, WP-3; guard in WP-12)

**Confirmed:**
- `HistoryView.swift:568` is the only `Material` in `Main/`. The only other one in the app is the
  window background in `App/WindowLook.swift:78-80`, which is allowed.
- `:569` strokes with `.separator`, while the tone map has `.hairline` (`ToneMap.swift`, `ToneRole`).
- CLAUDE.md: "Content stays free of glass and materials", readouts included.

**Reclassified:**
- This is a compliance fix, not an energy one. The readout exists only while the pointer hovers a
  chart and is about 140 × 40 pt. The blur pass is real but not measurable at the hour scale, so
  drop the Instruments step as a gate.
- Look caveat: on Standard, `.background.secondary` is the Card's own fill. The readout then reads
  as a cut-out with a hairline rim. On the glass sheet it is an opaque slab.

**Acceptance:**
- The maintainer approves screenshots in all 4 styles × Light/Dark.
- The criterion is legibility on **Clear** over a bright desktop, the user's current complaint.
- Do it inside WP-3's chart split, so `SelectionOverlay` changes once. WP-12's scanner rule is
  "no `Material` in `Main/`".

### AV-09: History's Period conformances (keep, P3, WP-3)

**Confirmed:**
- No `allCases`, `rawValue`, `init(rawValue:)` or `.id` use of `HistoryView.Period` exists in
  `Sources` or `Tests` (`git grep`).
- The picker uses explicit `.tag(Period.day)` and `.tag(Period.week)`.
- `ReloadKey` and `ShownKey` need only `Hashable`/`Equatable`, which a plain enum synthesizes.

DC-4's runtime concern doesn't apply: SwiftUI's `tag` needs `Hashable` only. If SUI-04 moves
`Period` into BatteryCore for the `@concurrent` builder, a plain enum is also implicitly
`Sendable`. Do it there.

### AV-10: Visibility hooks on the device pages (keep, P3, WP-9)

**Confirmed:**
- The bodies are synchronous: `DevicesIntroView.swift:16-18` and `DeviceView.swift:94-98`.
- `listIfStale()` and `setPageVisible(_:_:)` are synchronous main-actor methods that only mutate
  state and enqueue work (`IDeviceMonitor.swift:200-232`).
- So `onChange(of: motion.isVisible, initial: true)` behaves the same: it runs at the first
  appearance (`.id(selection)` gives every visit a new identity) and on every flip.
- It also keeps UI-8's "name every `.task`" grep from flagging two closures that aren't tasks.

Optional: `RefreshWhenShown` (`AccessoriesView.swift:155-168`) is `onAppear` plus `onChange` and
can use the same single `onChange(…, initial: true)`.

### AV-11: Raw Data display rules (keep-modified, P3, WP-5)

- **Keep:** the volts-digits rule (`RawValueText.swift:79-82`) as a `BatteryFormatter` method,
  for example `volts(millivolts:)` with automatic digits. Test 20000 → "20 V", 3300 → 1 digit and
  3250 → 2 digits in the existing `BatteryFormatterTests`, which WP-5 already owns. That is the
  CLAUDE.md rule (locale-independent display logic in BatteryCore).
- **Drop:**
  - The hex helper: `"0x" + String(value, radix: 16, uppercase: true)` is a stdlib one-liner, and a
    wrapper plus a test adds code for nothing.
  - The link to "CORE-01's single hex encoder": the core verification kept CORE-01 only as a
    one-line `.data` encoder swap and dropped the new `Hex` type. That encoder is lowercase
    per-byte hex, a different format.

### AV-12: History load errors (keep-modified, P2, WP-3)

**Confirmed:** four `try?` at `HistoryView.swift:220, 225, 226, 232`.

**Corrected failure scenario:**
- A *corrupt* day file doesn't throw. `HistoryStore.readLines` skips undecodable lines with
  `compactMap { try? … }` (`HistoryStore.swift:244-248`).
- Missing files return `[]` (`:97`, `:245`).
- Only an unreadable file or directory, or an I/O error, throws. That is exactly the "unexpected
  failure at an I/O boundary" that SW-R12 says must be logged.
- SW-12 is listed for WP-2, WP-4, WP-6 and WP-7, not for WP-3. Without this item, these four sites
  stay unjustified under SW-R12's `try?` grep. Hence P2.

**Modified:**
- Drop the `@State lastLoggedFailure` dedup. At most one line a minute, only while History is
  visible, with the error text private (SW-R10), is cheap, and it shows that the failure persists.
- Use the `history` category, the same subsystem and category as WP-4's recorder Logger. Two
  `Logger` values with the same category are fine, so WP-3 doesn't wait for WP-4.
- Do it inside WP-3's rewrite of `load()` (SUI-04), not before it.

Measure: as the audit gives it, except the line repeats each minute while the file stays
unreadable.

### AV-13: Copy Report's forced read (reject)

- `copyReport()` (`MainView.swift:428`) calls `monitor.refresh()` once per click, and that is a user
  action that happens a handful of times. One read is a few ms; the playbook's E20 gate is "full
  `read` p95 > 4 ms". So nothing is measurable in S1–S6 or per hour. EN-5 is about automatic
  reads.
- After E4a (WP-2), the window poll on Overview reads only `B0AV` and `B0AC`. The other SMC values
  may be up to 60 s old (§3.4). The forced read is what keeps a bug report's SMC values current.
  Skipping it on the "live" pages would make the report staler than today.
- It would also add a dependency on WP-2's `lastReadAt` for no gain.

### AV-14: Placement of shared helpers (keep-modified, P3, WP-9 inside SUI-13)

**Confirmed:**
- `AccessorySymbol` and `AccessorySymbols` are used by `PopoverAccessories.swift:28, 59`.
- `refreshesWhenShown` is used by `PopoverView.swift:103`.
- `FrostLayer` is used only at `Components.swift:42`.

This only moves code, so it isn't worth a commit of its own. It is a placement note for SUI-13's
`Components.swift` split:
- `FrostLayer` becomes `private` in the same file as `Card`.
- The accessory helpers go to `Main/Components/`.

None of these files is on a `MotionGuardTests` list.

## Hand-off by package

- **WP-3:** AV-05, AV-09 (with SUI-04), AV-12 (in the `load()` rewrite), AV-08 (with the chart
  split; needs the maintainer's look approval).
- **WP-5:** AV-01 (alert key after WP-6), AV-02, AV-11.
- **WP-9:** AV-04 reduced (after WP-5), AV-06, AV-07, AV-10, AV-14 (inside SUI-13).
- **WP-12:** the "no `Material` in `Main/`" scanner rule from AV-08.
- **Rejected:** AV-03, AV-13.
