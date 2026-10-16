# Audit "app-views": Sources/BatteryPulseApp/Main (base 6133b4f)

Read-only audit against `v061/playbook.md` and CLAUDE.md. The repository was not modified. IDs are
`AV-nn`. Every file of `Sources/BatteryPulseApp/Main/` was read in full (14 files, 3,550 lines). The
code under `#if os(macOS)` doesn't compile on Linux, so every change here is verified by the macOS
CI job plus the M5 checks named in each item.

This file adds to the playbook and doesn't repeat what it already owns. §1 maps the playbook items
to exact lines in `Main/`, so the work packages can find them. §2 has the new findings. §3 lists the
rules checked and found compliant, so WP-9's review doesn't repeat them.

Priorities use the playbook's levels:
- **P1**: ships in 0.6.1.
- **P2**: ships if time allows.
- **P3**: optional.

The owning work package (WP) follows playbook §3.2.

## 1. Already owned by the playbook: exact sites in Main/

| Item (WP) | Sites in `Main/` at `6133b4f` |
|---|---|
| SUI-02 + SW-05 (WP-5) | `DeveloperView.swift:128-130` (`Task.detached` → `@concurrent`). `:156-174`: the Decoded and Description cells call `RawValueText.string` and `RawValueText.summary` (a bundle lookup) per cell. `:214-237`: `filteredSections`/`matches` run in `body` and format each row on every keystroke and every reading. `:207-211`: `inspectedRows` walks every row on each body. |
| SUI-06 (WP-5) | `BatteryFormatter.app` is a computed `static var` (`App/Localized.swift:13`). It is built per view init at `MainView:108`, `OverviewView:8`, `PowerView:8`, `HealthView:8`, `CompactView:13`, `DeviceView:21`, `HistoryView:50` and `AccessoriesView:90` (**once per accessory part row**). `RawValueText.swift:7` builds it as a default argument, **once per Decoded cell**. `static let app` fixes all ten sites with no call-site change. |
| SUI-03, SUI-04, SUI-05R/E13, SUI-13, E7 (WP-3) | `HistoryView.swift:153`: the 60 s sleep has no tolerance. `:211-255`: `load()` builds points, spans and statistics on the main actor. `:325`, `:328`, `:336-337` and `:362-363`: `String(localized:)` per point and per body. `:375`: the series string is interpolated per point. `:182`: `points.contains { temperature }` per body. `:474`: `day.date()` builds a `Calendar` per day per body. The file is 579 lines (the split target). |
| SUI-10 / UI-8 (WP-3, WP-5, WP-9) | Long-lived tasks without a name: `HistoryView.swift:147` ("History reload") and `DeveloperView.swift:107` ("Raw Data rebuild"). `HistoryExport.swift:74` is per request; `MainView.swift:383` is the 1.5 s "Copied" one-shot (on EN-1's allowlist). For `DeviceView.swift:94` and `DevicesIntroView.swift:16`, see AV-10. |
| WP-10 (main-actor default) | Redundant after `.defaultIsolation(MainActor.self)`: `HealthView.swift:15`, `AccessoriesView.swift:134`, and the closure types at `MainView.swift:304, 350` and `DeviceView.swift:15`. |
| WP-9 / SUI-13 | `Components.swift` is 606 lines: `Card`, `CardGroup`, `LookForm`, the ring gauge, `BatteryGlyph`, `CapacityBars`, `PowerFlowView` and `ValueRow`. AV-14 adds what else belongs in the split. |

## 2. Findings

### AV-01: Export Capture fails silently and uses a blocking `NSSavePanel.runModal()` (bug + native, P2, WP-5)

- **Where:** `DeveloperView.swift:272-282`.
  - `panel.runModal()` opens an app-modal panel.
  - Both `try? PropertyListSerialization.data(…)` and `try? data.write(to:options:)` drop errors. On a failed write (full disk, read-only or locked folder, a permissions error), nothing happens and the user believes the capture was saved.
  - The same page area already exports through SwiftUI's `fileExporter`, with a failure alert (`HistoryExport.swift:64-119`). So there are two mechanisms for one job.
- **Change:**
  1. Add `struct RawCaptureFile: Transferable { let data: Data }` with `DataRepresentation(exportedContentType: .xml)`.
  2. In `exportCapture()`, build the data with `PropertyListSerialization` (as today) into `@State var captureFile: RawCaptureFile?` and set `isExportingCapture = true`. Keep the `!monitor.isOverridden` guard.
  3. Attach `.fileExporter(isPresented:item:contentTypes: [.xml], defaultFilename: "BatteryPulse-capture.xml", onCompletion:)` to the page, not inside the `ToolbarItemGroup`. `HistoryExport.swift:34-35` explains why: presentations attached inside toolbar items are unreliable on macOS.
  4. Add an `.alert` that shows `error.localizedDescription` on a serialization or write failure.
  5. The alert title is a new UI string. Per playbook §3.2, only WP-6 adds strings, so add "Couldn't Export Capture" plus its Russian translation after WP-6 merges.
- **Measure:**
  - macOS CI builds; `LocalizationCatalogTests` passes.
  - On the M5, Raw Data → Export Capture… → save. Then `bpulse --input <file>` renders the same report as `bpulse --raw | bpulse --input /dev/stdin`, so the bytes are unchanged.
  - Save into a folder made read-only with `chmod a-w`: the alert appears.
  - Demo Mode: the button is still disabled.
- **Risk:** low. The Save panel becomes a window-attached sheet instead of an app-modal panel, the same as History's export. The file name, type and content stay the same.

### AV-02: Copy JSON's redaction lives in the view, untested (security/readability, P2, WP-5)

- **Where:**
  - `DeveloperView.swift:259-270` clears `serialNumber` and `adapter?.serialNumber` by hand, then configures its own `JSONEncoder`.
  - Nothing on Linux tests that Copy JSON carries no serial. If a later field identifies the battery (a pack or cell serial added to `BatterySnapshot`), it would leak into a clipboard meant for public bug reports, and no test would fail.
  - The same pattern already exists for devices in BatteryCore (`RememberedDevice.storable`, `RememberedDevice.swift:88-92`).
- **Change:**
  - Add `public var redacted: BatterySnapshot` to `BatterySnapshot` in BatteryCore. It sets both serials to `nil`.
  - Add a swift-testing case: encode `BatteryReading(rawCapture:)` of each `m5-macos27-*` fixture's `.redacted` with the Copy JSON settings (`[.prettyPrinted, .sortedKeys]`, `.iso8601`), then `#expect` that the output contains neither the fixture's `Serial` nor the adapter's `SerialString`.
  - `copyJSON()` becomes `encoder.encode(snapshot.redacted)`.
- **Out of scope, for the maintainer:**
  - `bpulse --json` (`Sources/bpulse/main.swift:160-164`) encodes `reading.snapshot` unredacted, so it prints both serials. USER_GUIDE:640 promises redaction only for captures and reports.
  - §3.4 freezes `--json` stdout for 0.6.1, so this is only noted. Decide in 0.7 whether `--json` should use `.redacted` too.
- **Measure:** the new test passes on Linux (`swift test --filter BatterySnapshot`). On the M5, the Copy JSON output is byte-identical to 0.6.0's (diff the clipboard from both builds on the same reading, with the timestamp masked).
- **Risk:** none (same output).

### AV-03: The sidebar selection is stored as a String and re-parsed on every read; `@SceneStorage` takes the enum directly (native/readability, P3, WP-9)

- **Where:**
  - `MainView.swift:63-91`: `storageKey` and `init?(storageKey:)`, which builds an 8-element array and compares storage strings on each call.
  - `:105`: `@SceneStorage("mainSelection") private var storedSelection: String`.
  - `:126-129`: the computed `selection` with a `nonmutating set`.
  - `MainView.body` reads `selection` about 6 times:
    - the List binding, through `sidebarSelection`;
    - `MainDetail`;
    - `.id`;
    - `.animation(value:)`;
    - `navigationTitle`;
    - `CopyReportButton`;
    - `liveRefresh`.
- **Change:**
  - Make `SidebarItem: RawRepresentable`: `rawValue` is today's `storageKey`, and `init?(rawValue:)` is today's `init?(storageKey:)`. Use a `switch` over the eight literal names instead of building the `named` array.
  - Declare `@SceneStorage("mainSelection") private var selection: SidebarItem = .overview`. `SceneStorage` supports `RawRepresentable` with `RawValue == String`.
  - Delete `storedSelection` and the computed wrapper.
  - The stored strings stay identical (`"overview"`, `"device:<key>"`, …), so a 0.6.0 window restores into 0.6.1.
- **Measure:**
  - macOS CI builds.
  - On the M5, quit with Raw Data selected and relaunch: Raw Data is restored. Repeat with a remembered iPhone's page: restored, or the intro row while the device loads (`sidebarSelection` behaviour unchanged).
  - Demo tour page switching still works.
- **Risk:** low.
  - `==`/`hash` may now come from the stdlib's `RawRepresentable` defaults. That is still correct, because `rawValue` is injective (the device prefix and key are unique).
  - Keep `Identifiable` (`id: Self`).

### AV-04: The battery hero is written three times and the gauge row twice; small phrase and constant duplicates around them (readability/size, P2, WP-9)

- **Where:**
  - **Hero** (glyph, big percent, state line, time or subtitle line, Clear's "Low battery" badge):
    - `OverviewView.swift:43-74`;
    - `CompactView.swift:59-89`;
    - `DeviceView.swift:106-147`.
    - All three compute `BatteryPresentation.levelTier` twice: Overview `:40` and `:66`, Compact `:64` and `:80`, DeviceView `:107-108` and `:127-128`, and DeviceView a third time at `:197-198`.
  - **Gauge row** ("Charge", "Maximum capacity", "Cycle count" tiles, plus `.fixedSize`): `OverviewView.swift:76-121` and `DeviceView.swift:188-230`.
  - The **rated-cycle fallback `1000`** appears three times: `OverviewView.swift:108`, `HealthView.swift:61` and `DeviceView.swift:217`.
  - The **tier → condition words** appear twice: `DeviceView.swift:238-244` and `Phrases.healthWarning` (`App/Localized.swift:137-142`).
  - `DeviceView.swift:150-157` (`statePhrase`) re-implements the charging branch of `Phrases.stateWithPower` (`Localized.swift:87-97`).
  - `DeviceView.swift:336` builds a fake `IDeviceError.timedOut(seconds: 0)` just to get the "couldn't look for devices" phrase.
- **Change:**
  1. Add `Main/Components/BatteryHero.swift`: a view with value inputs (`percent: Double?`, `isCharging`, `tier`, `state: String`, `detail: Text?`, `isCompact: Bool`). Its body is the shared layout. Overview, Compact and DeviceView pass their values, and the tier is computed once by the caller.
  2. Add `Main/Components/GaugeRow.swift`: it takes the charge, health and cycle values plus captions, and both pages use it.
  3. In BatteryCore, add `BatteryPresentation.fallbackRatedCycles = 1000` and `static func cycleFraction(cycles:rated:)` with a Linux test, including `rated == 0`, which today divides by zero (`HealthView:61`).
  4. Add `Phrases.condition(for tier:)`, used by `healthWarning` and DeviceView.
  5. Add `Phrases.stateWithPower(_ state: ChargeState, watts: Double?, _ f:)`, used by both `stateWithPower(_ s:)` and DeviceView.
  6. Add `Phrases.deviceListFailed` and use it instead of the fabricated error.
  7. No catalog key changes: the same literals move.
- **Measure:**
  - `LocalizationCatalogTests` and `MotionGuardTests` pass (the animation keys stay where they are; the Overview's `.animation(…, chargeState)` stays on the page).
  - On the M5, screenshot Overview, Compact and an iPhone page in the four window styles × Light/Dark × en/ru, and diff against 0.6.0: identical.
  - `wc -l Sources/BatteryPulseApp/Main/**/*.swift` drops by about 80 lines (an estimate).
- **Risk:** low. It's a refactor whose risk is visual, and the screenshot diff covers that. Coordinate with SUI-07: the hero's inputs become Equatable values.

### AV-05: History's empty state reads the recording setting from `UserDefaults` in `body`, so it goes stale (bug, P3, WP-3)

- **Where:**
  - `HistoryView.swift:165`: `if AppSettings.recordsHistory`, which is a plain `UserDefaults` read (`App/AppSettings.swift:82-83`). SwiftUI doesn't observe it.
  - Toggling Settings → Advanced → Record battery history while History shows "No History Yet" leaves the old sentence ("Recording is off…" or "records … about once a minute") until something else re-evaluates the body. That is up to 60 s later, at the next reload's `end` change.
- **Change:** `@AppStorage(AppSettings.recordHistoryKey) private var recordsHistory = true`, the same declaration and default as `SettingsView.swift:435`. Use it at `:165`.
- **Measure:** on the M5, clear history, open History ("No History Yet"), then toggle the setting in Settings: the sentence switches at once.
- **Risk:** none.

### AV-06: Copy Report's tooltip promises a report on pages where the button is disabled (bug, P3, WP-9)

- **Where:**
  - `MainView.swift:394-403`: `canCopy` is `false` for `.devicesIntro` and `.accessories`.
  - `:405-415`: `help` sends those pages to `default`, which says "Copy a plain-text report without serial numbers" on a disabled button.
- **Change:** add `case .devicesIntro, .accessories: return Text(verbatim: "")` to `help`. Show no tooltip, as `DeviceRow.lastSeen` (`:291-294`) already does; this adds no new string.
- **Measure:** on the M5, hover over Copy Report on Accessories and on the intro page: no tooltip. Overview and device pages are unchanged.
- **Risk:** none.

### AV-07: A comment claims DemoView has "the only custom Liquid Glass in the app" (readability, P2, WP-9)

- **Where:** `DemoView.swift:108`. Since 0.6.0, custom glass is also in `Settings/SettingsView.swift:346` and `App/WindowLook.swift:101`. CLAUDE.md and `MotionGuardTests.glassAllowList` both list three files.
- **Change:** "One of the three places with custom Liquid Glass (CLAUDE.md lists them): a control that floats over content." Keep the rest of the comment.
- **Measure:** `grep -rn "only custom" Sources` returns 0 results.
- **Risk:** none.

### AV-08: The History hover readout is the only material in the windows' content (CLAUDE.md/energy, P3, WP-3)

- **Where:**
  - `HistoryView.swift:568`: `.background(.regularMaterial, …)`.
  - `:569`: `.strokeBorder(.separator, …)`.
  - CLAUDE.md: "Content stays free of glass and materials"; readouts are content.
  - On Frosted, this puts a material on the window's material, the extra blur pass that `Components.swift:167-169` says it avoids. On Translucent and Clear, it is a material over the glass sheet.
  - `.separator` bypasses the tone map (Clear's hairline is `tones.style(.hairline)`).
- **Change:**
  - `.background(.background.secondary, in: shape)`, Card's own Standard surface (`Components.swift:40`), and `.strokeBorder(tones.style(.hairline), lineWidth: 0.5)`. `SelectionOverlay` gets `@Environment(\.tones)`.
  - WP-12 adds "no `Material`/`…Material` in `Main/`" to the guard scanner's content rules.
- **Measure:**
  - On the M5, hover a chart in each of the four styles, Light and Dark; the readout stays legible. Get the maintainer's OK on the look.
  - Instruments (Core Animation or GPU) while sweeping the pointer on Frosted, before and after.
- **Risk:** a visible change to a small overlay; it needs the maintainer's approval, which is why it is P3.

### AV-09: `HistoryView.Period` carries three unused conformances (dead code, P3, WP-3)

- **Where:** `HistoryView.swift:17-19`: `enum Period: String, CaseIterable, Identifiable` plus `var id`.
  - The picker uses explicit tags (`:131-134`).
  - There is no `allCases`, `rawValue`, `ForEach` over `Period`, or `Period(rawValue:)` anywhere (grep).
  - `ReloadKey`/`ShownKey` need only `Equatable`/`Hashable`, which a payload-free enum has automatically.
- **Change:** `enum Period { case day, week … }`. Keep `length` and `bucket`.
- **Measure:** the macOS CI build compiles, which proves there is no static use. `grep -rn "Period\.\(allCases\|init(rawValue\)\|as? any Identifiable" Sources` finds nothing, so there is no dynamic use (DC-4).
- **Risk:** none.

### AV-10: Two `.task(id: motion.isVisible)` blocks never await; they are `onChange(initial:)` (native/readability, P3, WP-9)

- **Where:**
  - `DevicesIntroView.swift:16-18` (`listIfStale()`).
  - `DeviceView.swift:94-98` (`setPageVisible`, `listIfStale()`).
  - Neither has an `await`, so each creates a task to run synchronous code. UI-8's grep ("every long-lived `.task` has a name") would also flag them.
- **Change:** `.onChange(of: motion.isVisible, initial: true) { _, isVisible in … }` with the same bodies. Keep DeviceView's `.onDisappear` (`:99-101`).
  - Every page has its own identity, through `MainDetail`'s `.id(selection)` at `MainView.swift:187`, and the intro and a device page are different branches. So `initial: true` fires on every visit, as the task did.
- **Measure:** on the M5 with reading on:
  - open an iPhone page: one list and one read (`log stream`, `device` category, after WP-7).
  - cover the window completely: the page reports hidden.
  - uncover it: one read if the last one is older than `visibleInterval`.
  - `IDeviceMonitorTests` are unchanged.
- **Risk:** low.

### AV-11: Locale-independent display logic in `RawValueText` isn't tested on Linux (readability/testability, P3, WP-5)

- **Where:** `RawValueText.swift`:
  - `:78-82` picks volts digits: whole V → 0, tenths → 1, else 2.
  - `:31-37` and `:58-59` build `"0x" + String(value, radix: 16, uppercase: true)`.
  - CLAUDE.md: "Locale-independent display logic … live[s] in BatteryCore so [it is] tested on Linux". These rules decide every PDO/RDO cell in Raw Data, and no test covers them.
- **Change:**
  - Move `fractionDigits(millivolts:)` and an uppercase `hexLiteral(_:)` into BatteryCore, in `RawValueDecoding.swift`. Do it together with CORE-01's single hex encoder, so the four encoders become one plus this uppercase form.
  - Add tests for 20000 → 0, 3300 → 1, 3250 → 2 and `0xA5`.
  - `RawValueText` keeps only the `String(localized:)` wording.
- **Measure:** the new BatteryCore tests pass on Linux. On the M5, Raw Data's Decoded column for `UsbHvcMenu`/PDO rows is identical to 0.6.0 (screenshot).
- **Risk:** none.

### AV-12: History's reload swallows every store error (logging, P2, WP-3)

- **Where:** `HistoryView.swift:220, 225, 226, 232`: four `try?` on `HistoryStore` reads.
  - An unreadable or corrupt day file, a permissions error, or a broken device store all show "No History Yet", or a silently empty health chart, and leave no trace anywhere.
  - SW-R12: unexpected failures at I/O boundaries are logged.
- **Change:**
  - Use `do`/`catch` around the reads.
  - Log once per (source, error description) in the `history` category with `privacy: .private` for the error text (SW-R10). Don't log every minute: keep `@State var lastLoggedFailure`.
  - The UI stays as it is.
- **Measure:** on the M5, `chmod 000` today's `samples/<date>.jsonl`, then open History. `log stream --predicate 'subsystem == "io.github.nikitausov.BatteryPulse" && category == "history"'` shows one error, and no more after a minute. Restore the permissions.
- **Risk:** none.

### AV-13: Copy Report forces a synchronous full read even right after a poll (energy, P3, WP-2 then WP-9)

- **Where:** `MainView.swift:428`. `monitor.refresh()` runs a full IOKit, registry and SMC read on the main actor for every click.
  - On Overview, Power, Health and Raw Data (`showsLiveValues`, `:26-31`), the window polls every 2 s, so the forced read duplicates one that is at most 2 s old.
  - EN-5 says freshness comes from `lastReadAt`, which WP-2 adds.
- **Change:** after WP-2's first commit, `if monitor.lastReadAt.map({ Date.now.timeIntervalSince($0) > 2 }) ?? true { monitor.refresh() }`. Equivalently, `if !selection.showsLiveValues`.
  - History, Demo Mode and the Devices section still read fresh, so the 0.4 rationale in the comment (`:426-427`) holds.
- **Measure:** the `monitor.read` signpost (WP-0) counts 0 reads per Copy Report on Overview and 1 on History.
- **Risk:** none. The report can be at most one poll old, as the live values on screen are (§3.4).

### AV-14: Shared components live in page files; `FrostLayer` is wider than its use (readability, P3, WP-9)

- **Where:**
  - `AccessoriesView.swift:124-168` holds `AccessorySymbol`, `AccessorySymbols` and `refreshesWhenShown`/`RefreshWhenShown`. The menu bar uses them (`MenuBar/PopoverAccessories.swift:28, 59`; `MenuBar/PopoverView.swift:103`).
  - `FrostLayer` (`Components.swift:170-181`) is internal but used only at `Components.swift:42`.
- **Change:**
  - In WP-9's Components split, move the three accessory helpers to `Main/Components/AccessorySymbol.swift` and `Main/Components/RefreshWhenShown.swift`.
  - Make `FrostLayer` `private` next to `Card`.
  - Update the `MotionGuardTests` file lists if a moved file is on them. Today none of these is.
- **Measure:** the macOS CI build passes; `MotionGuardTests` passes.
- **Risk:** none.

### Considered and dropped (no change)

- **`.task(id: monitor.reading)` cost** (`DeveloperView:107`). `BatteryMonitor` replaces `reading` only when it changed, and Dictionary equality short-circuits on shared storage and on the first difference. `rebuild()`'s `sections != allSections` (`:134`) also stops at the first differing row. Both are microseconds.
- **The Accessories page reads on every un-occlusion** (`AccessoriesView.swift:155-168`). It is intended ("catches anything missed over sleep"), and the read is one IOPS call.
- **`RingGaugeStyle` instead of a system gauge style.** `accessoryCircular` exists on macOS, but it can't take the tone map, Clear's glass piece, the motion presets or the 112/128 pt sizes. Replacing it loses the look.
- **`GroupRule`'s per-card `onGeometryChange`** (`Components.swift:102-124`). The action runs only when the Bool flips. The geometry design is deliberate: gauge tiles inside an `HStack` are all "top".
- **Two "Low battery" badges on a low accessory part in Clear** (`AccessoriesView.swift:103-116`). The comments describe it as intended; it's a design question, not a defect.

## 3. Rules checked in Main/ and found compliant (no work)

- **UI-4:** `MainView.body` never reads `monitor.snapshot`. The only reads are `MainDetail` (`:327`) and `CopyReportButton` (`:401, 429`), as SUI-07 requires.
- **UI-6:** the only environment write in `Main/` is `\.contentTreatment = nil` (`Components.swift:67`); no live values go into the environment.
- **UI-7:**
  - The sidebar is `ForEach(deviceEntries) { DeviceRow }`.
  - Accessories are `ForEach(monitor.accessories) { AccessoryCard }` and `ForEach(parts, id: \.role) { AccessoryPartRow }`.
  - Demo is `ForEach(...) { DemoStepRow }`.
  - Each is one subview per element, with no `AnyView`, no lazy stacks and no `onAppear` setup in rows. SUI-15 has nothing to fix in `Main/`.
- **UI-9:** every `@State` is initialized at its declaration only.
- **UI-11 / UI-14:** no `#Preview` and no `_printChanges` in `Main/`.
- **UI-13 / CLAUDE.md:**
  - Every animation goes through `\.motion`.
  - Glass appears only in `DemoView.swift`.
  - There are no system colour names from `MotionGuardTests.swift:94`'s list. `.white` in `InvertedBadge`/`FrostLayer` is outside that list on purpose. AV-08 is the one material.
- **EN-2:** no `Timer`, `DispatchQueue`, `asyncAfter` or Combine in `Main/`.
- **Localization:**
  - No ternary of literals passed to `Text`; `CompactView.swift:93` and `DeveloperView.swift:90-99` use two `Text` values.
  - Interpolations are pre-formatted Strings.
  - Device and accessory names use `Text(verbatim:)`.
- **Privacy:**
  - Raw Data shows and exports `redactedRawCapture`.
  - Copy Report uses `BatteryReport` (no serials) and `capture.redacted` for devices.
  - In Demo Mode, the device list, History's source picker and every export are blocked or disabled (`MainView.swift:112-114, 394-402`; `HistoryView.swift:115`; `DeveloperView.swift:89, 95`).
- **Deprecated APIs:** none found for macOS 27. `onChange` uses the two-parameter form, plus `foregroundStyle`, `confirmationDialog`, `fileExporter(item:)`, `chartXSelection` and `safeAreaBar`.
