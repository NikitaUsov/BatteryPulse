# Audit "core": Sources/BatteryCore and Tests/BatteryCoreTests

Base: `main` = `6133b4f` (0.6.0). Read-only: the repository was not modified. Builds, tests and benchmarks
ran under `v061/core-build`, `v061/core-bench` and `v061/core-exp` in the scratchpad (Swift 6.4.1, Linux).

This file adds to the playbook. It does not repeat items that the playbook already owns: SUI-02, SUI-04,
SUI-06, E13, E14, SW-19, SZ-08, SEC-11 and SW-17. When a finding touches one of those items, it says so
and adds only what is new. The work package (WP) that owns each file is taken from playbook §3.2.

## Measured baseline (Linux, this session)

- `swift build --build-tests`: 37 s from cold, 0 warnings.
- `swift test --filter BatteryCoreTests`: 455 tests.
  - Parallel: 2.46 s. Without the relaunch test: 1.44 s.
  - Serial (`--no-parallel`): 5.15 s.
- Slowest tests, serial:

  | Test | Time |
  |---|---|
  | `appAndWidgetFollowTheMotionRules` | 1.290 s |
  | `relaunchPassesThePathUntouched` | 1.009 s |
  | `everyUIStringIsTranslated` | 0.484 s |
  | `catalogHasNoLeftovers` | 0.467 s |
  | `timesMatchFoundationAcrossTimeZonesAndDaylightSaving` | 0.326 s |
  | `russianTextOnlyInTheCatalog` | 0.189 s |

  These six tests take 3.77 of the 5.15 s.
- BatteryCore microbenchmarks, release build, real fixture `m5-macos27-plugged-in-10s`:

  | Operation | Time |
  |---|---|
  | `BatteryReading(rawCapture:)` | 48 µs |
  | ↳ `RegistryChildren.entries(in:)`, once | 8.3 µs (the parser walks the children 3×) |
  | ↳ `SMCBattery.values(in:)`, once | 6.2 µs (the parser decodes up to 3×) |
  | ↳ the parse without children and SMC | 10 µs |
  | `RawSection.sections(for:)` (654 rows, 16 data rows) | 1.58 ms |
  | `row.value` over all rows | 1.36 ms; the 16 data rows account for all of it |
  | data rows through a table-based hex encoder | 0.13 ms, byte-identical output |

## Findings

Priorities use the playbook's levels:
- **P1**: ships in 0.6.1.
- **P2**: ships if time allows.
- **P3**: optional.

### CORE-01: the data-blob hex in `PropertyValue.description` is 11× slower than needed, and BatteryCore has four hex encoders (speed + readability, P1, WP-5 with WP-7)

- **Where:**
  - `Sources/BatteryCore/PropertyValue.swift:143`: `case .data(let value): "<\(value.map { String(format: "%02x", $0) }.joined())>"`. That is one `String(format:)` call and one `String` per byte.
  - It is reached through `RawRow.value` (`RawKeyGlossary.swift:1127`) and `RawEntry.value` (`BatteryPresentation.swift:76`). `DeveloperView` reads `row.value` twice per visible cell (`:149`, `:153`), in the search filter on every keystroke (`:226`) and in Copy Value (`:195`).
  - The other hex encoders:
    - `UpdateInstall.swift:68-76` (`UpdateIntegrity.hex`);
    - `DeviceKey.swift:57-68`;
    - `HistoryExport.swift:472-476` (JSON `\u00XX`);
    - `bpulse/main.swift:326` (`--smc`, again `String(format: "%02x")`).
- **Change:**
  - `.data` becomes `"<" + UpdateIntegrity.hex(value) + ">"`. Better, move the encoder into one internal `Hex.lowercase(_:)` in BatteryCore, with `UpdateIntegrity.hex` kept as a public forwarder for BatteryKit.
  - `DeviceKeyDerivation.key` and `bpulse --smc` use the same encoder.
  - Then, together with SUI-02, make `RawRow.value` a stored `let` that `RawSection.row(...)` fills, so a table pass never formats again.
- **Measure:**
  - Benchmark B: data rows 1.50 ms → 0.13 ms per pass; the search filter 3.2 ms → about 1.8 ms per keystroke on Linux.
  - `identical output: true` for every data row of the real fixture, checked in the bench.
  - Add a unit test: `PropertyValue.data(Data([0x00, 0xAB, 0x0F])).description == "<00ab0f>"`.
  - The golden `bpulse --smc` and Copy Report output must stay byte-identical (§2.6).
- **Risk:** none for output, since the bytes are the same.
  - `PropertyValue.swift` is owned by WP-7 and `RawKeyGlossary.swift` by WP-5. Land it in WP-5 and have WP-7 rebase.

### CORE-02: MotionGuardTests is the slowest test, and WP-0/WP-12 will triple it (tests/speed, P1 as part of WP-0's `SourceScanner`)

- **Where:** `Tests/BatteryCoreTests/MotionGuardTests.swift`.
  - `codeOnly` (`:325-383`): `starts(with:at:)` allocates `Array(prefix)` plus an `Array` slice at every character, 3 times per position. That costs 0.30 s at `-Onone` for the app's 372 K characters.
  - `violations(in:path:)` (`:125-210`) runs about 20 regex passes per file over all 38 files.
  - The regexes are computed `static var`s (`:77-116`) plus inline `words(#/…/#)`, so each access builds a new `Regex`.
  - Most anchors are absent from most files:
    - `repeatForever`, `TimelineView`, `.repeat`, `Animator`, `NSVisualEffectView`, `preferredColorScheme`: 0 of 38 files;
    - `glassEffect`: 3;
    - `containerBackground`: 2;
    - `symbolEffect`: 5;
    - `withAnimation`: 5;
    - `.tint`: 6;
    - `.animation`: 15.
- **Change:** do this in WP-0's `SourceScanner` extraction, so `SecurityGuardTests` and `EnergyGuardTests` (WP-12) inherit it.
  1. `starts(with:at:)` compares characters in place, with no allocation.
  2. The regexes become `static let`. `Regex` is `Sendable`; if Swift 6.4 rejects that, keep them in a `nonisolated(unsafe) static let`.
  3. Before each regex pass, check a plain `code.contains("glassEffect")`-style anchor.
  4. Read each file and run `codeOnly` on it once per process (a `static let` cache keyed by path), so it is shared by every guard suite.
- **Measure:**
  - Before: `swift test --no-parallel --filter MotionGuardTests` takes 1.29 s for `appAndWidgetFollowTheMotionRules`. Target: under 0.3 s.
  - The `catches(source:)` and `allows(source:)` tables (55 cases) must stay green.
  - Injecting one violation per rule into a scratch copy must still fail.
- **Risk:** a prefilter anchor that is wrong hides a violation. Mitigation: derive each anchor from the regex's own literal prefix, and keep the `catches` cases.

### CORE-03: the relaunch test spends 1 s in the script's `sleep 1` (tests, P2, WP-6)

- **Where:**
  - `Tests/BatteryCoreTests/UpdateInstallTests.swift:185-206`;
  - `Sources/BatteryCore/UpdateInstall.swift:144-151`: the script always runs `sleep 1` after the wait.
  - The test alone takes 1.009 s and sets the parallel suite's wall time: 2.46 s with it, 1.44 s without.
- **Change:**
  - Add `settleSeconds: String = "1"` to `relaunchArguments`, passed as a positional `$4`, never interpolated. The app keeps the default; the test passes `"0"`.
  - Alternative with no API change: run the test with `.timeLimit` and accept it, but tag it `.tags(.slow)` so local runs can skip it.
- **Measure:**
  - The test drops under 0.05 s; the BatteryCore parallel run drops from 2.46 s to about 1.5 s.
  - A new assertion that the default arguments still contain `sleep 1`, so the app keeps its 1 s settle.
- **Risk:** the script text changes. Keep the path and the opener as positional arguments, and keep the existing quoting test.

### CORE-04: LocalizationCatalogTests decodes the catalog and scans the sources once per test (tests, P2, WP-6)

- **Where:** `Tests/BatteryCoreTests/LocalizationCatalogTests.swift`.
  - `catalog()` (`:52-55`) and `sourceKeys()` (`:57+`) run again in `everyUIStringIsTranslated` (0.48 s), `catalogHasNoLeftovers` (0.47 s) and `russianTranslationsAreCompleteAndKeepPlaceholders`.
  - The regexes are `static var` (`:19-30`).
- **Change:**
  - `private static let catalogResult = Result { try decode() }` and `private static let sourceKeysResult = Result { try scan() }`, which each test unwraps with `try`.
  - The regexes become `static let`.
- **Measure:** serial time for the suite, from about 1.15 s to about 0.5 s. The tests still fail when a key is removed from the catalog, checked on a scratch copy.
- **Risk:** none; a thrown error still fails every test that reads the result.

### CORE-05: `IDeviceInfo` is `Codable` but nothing encodes it, and encoding it would write the UDID (security/dead code, P2, WP-7)

- **Where:**
  - `Sources/BatteryCore/IDevice.swift:24`: `public struct IDeviceInfo: Sendable, Equatable, Codable, Identifiable`, whose `id` is the UDID (`:25`, "Never printed or written").
  - `grep` finds no encode or decode of it in `Sources` or `Tests`. It is used only in memory: `IDeviceMonitor`, the transports and `IDeviceList`.
- **Change:**
  - Drop `Codable` from `IDeviceInfo`, so a future `JSONEncoder().encode(devices)` (for example a `--devices --json`) can't silently write UDIDs. This is SEC-R9.
  - `IDeviceConnection` stays `Codable`: `RememberedDevice.lastConnection` stores it.
- **Measure:** `swift build` (Linux) and the macOS job compile; `grep -rn "IDeviceInfo" Sources` still shows no encoder.
- **Risk:** none. `devices.json` stores `RememberedDevice`, not `IDeviceInfo`.

### CORE-06: dead or test-only members in BatteryCore (dead code, P2, WP-11 confirms with maps, DC-1/DC-3)

Each member below has 0 references in `Sources` outside its declaration (grep, plus a symbol-graph scan of `BatteryCore.symbols.json` from this build).

| Member | Where | Other uses |
|---|---|---|
| `RawKeyGlossary.keys` | `RawKeyGlossary.swift:79-80` | none, not even tests, although its comment says "for coverage tests" |
| `RawEntry.value`, `RawEntry.id` with `Identifiable` | `BatteryPresentation.swift:72-76` | `RawSection.section` reads only `path` and `property` |
| `WindowLookPolicy.allowsTertiaryText` | `WindowLook.swift:142-145` | `WindowLookTests` only; the app uses `tones` |
| `WindowLookPolicy.dividesGroupsWithHairlines` | `WindowLook.swift:147-150` | `WindowLookTests` only; the app switches on `groupSurface` (`Components.swift:38`) |
| `BatterySnapshot.wearPercent` | `BatterySnapshot+Metrics.swift:28-31` | `MetricsAndReportTests` |
| `MenuBarIconStyle.isDrawn` | `MenuBarContent.swift:133` | `MenuBarTests:104` |
| `Tone.hasHue` | `ToneMap.swift:110` | `ToneMapTests:55, :137` |
| `HistoryStore.samples(since:)` | `HistoryStore.swift:87-89` | tests only; it just forwards to `samples(from:)` |

- **Change:**
  - Delete `RawKeyGlossary.keys` and `RawEntry.value`/`id`/`Identifiable`.
  - For the test-only rows, either move them into the test target as helper extensions (DC-3) or delete them and rewrite the assertions on what the app uses:
    - `groupSurface == .none`;
    - `tones.style(.text(.tertiary))`;
    - `healthPercent` for wear.
  - `samples(since:)`: callers use `samples(from:)`.
- **Measure:**
  - WP-11's intersected debug `-dead_strip` maps list these symbols as dead in all three products.
  - Tests stay green, with 0 behaviour change.
- **Risk:** low. Keep `public` on everything that stays (SW-R17).

### CORE-07: `Codable` conformances that nothing uses (size/dead code, P3, WP-11)

- **Where:**
  - `IDeviceIdentity` (`RememberedDevice.swift:5`): `RememberedDevice` stores the fields flat, and `IDeviceSession` isn't `Codable`.
  - `MenuBarItem` (`MenuBarContent.swift:4`).
  - `MenuBarIconStyle` (`:118`): `@AppStorage` uses its `String` raw value, not `Codable`.
  - `BatteryAlert` (`BatteryAlerts.swift:4`).
  - Grep finds no encoder or decoder of any of them in `Sources` or `Tests`.
- **Change:** drop `Codable` from these four.
- **Measure:**
  - Builds green.
  - SZ-06 release map: the `IDeviceIdentity` `init(from:)`/`encode(to:)`/`CodingKeys` symbols disappear.
  - The settings round-trip still works on the M5: change the icon style, quit and relaunch.
- **Risk:** small. Check DC-4 first: no runtime-generic encoding of these types exists today. The gain for the raw-value enums is tiny (only conformance records). Do it only together with CORE-06.

### CORE-08: comments that don't match the code (readability, P2, one docs commit)

- `BatterySnapshot.swift:5-6`: "macOS 27 dropped battery temperature and cell voltages". They moved to the child entries; see CLAUDE.md, `MacPowerParser.swift:109-115` and `RegistryChildren.swift:5-10`. Reword it to "moved them to the entries below `AppleSmartBattery`". The line is also more than 120 characters.
- `IDeviceBattery.swift:245-247`: "macOS publishes its `Temperature` differently, so this conversion is kept separate". macOS publishes the same unit: `MacPowerParser.celsius(fromCentidegrees:)` at `MacPowerParser.swift:284-288` divides by 100 too. The real differences are the `raw != 0` "no reading" rule and that iOS reads it from the pack. Say that.
- `BatteryReport.swift:14`: "used by the app's Details window". No Details window exists. `sections(for:)` feeds only `lines(for:)` and one test (`MetricsAndReportTests:166-168`). Either fix the comment or, better, follow CORE-09.
- `RawKeyGlossary.swift:79`: "for coverage tests". No test uses it; see CORE-06.
- `CaptureRecorder.swift:256`: "With fewer slots than captures due, the `before` capture goes first". `suffix` drops `before` first, so say "is dropped first".
- **Measure:** review only; `swift format lint --strict` stays clean.
- **Risk:** none.

### CORE-09: `BatteryReport` builds `Section`s that only become a flat list (dead code/readability, P3, WP-11)

- **Where:** `BatteryReport.swift:14-18` (`Section`), `:24-119` (`sections(for:)` with `close(_:)`), `:20-22` (`lines(for:)` is `sections(for:).flatMap(\.lines)`).
- **Change:**
  - Fold `sections(for:)` into `lines(for:)`: drop `close(...)` and the `Section` type.
  - Delete the test that compares `sections` with `lines` (`MetricsAndReportTests:166-168`).
- **Measure:** the golden `bpulse` text report and the app's Copy Report stay byte-identical (§2.6). `MetricsAndReportTests` stays green.
- **Risk:** none, unless a future UI wants the sections. In that case keep them and fix the comment (CORE-08).

### CORE-10: the battery parse walks the registry children 3 times and decodes the SMC capture up to 3 times per read (speed/energy, P3, WP-2)

- **Where:**
  - `MacPowerParser.swift:129`, `:194` and `:200` call `RegistryChildren.chargerData`, `cellVoltagesMV` and `temperatureCelsius`. Each runs `entries(in:)` (`RegistryChildren.swift:34-48`) again, and that copies every child's property dictionary.
  - `SMCBattery.liveElectrical`/`cellVoltagesMV`/`temperatureCelsius` (`SMC.swift:335`, `:359`, `:383`) each re-decode and sort the whole capture through `values(in:)`.
- **Change:**
  - In `MacPowerParser.snapshot`, compute `let children = RegistryChildren.entries(in: sb)` once and pass it to `[Entry]` overloads of the three helpers.
  - Build `let smcValues = Dictionary(uniqueKeysWithValues: SMCBattery.values(in: smc).map { ($0.key, $0) })` once and pass it to `[SMCFourCC: SMCRawValue]` overloads.
  - Keep the dictionary-taking public functions as thin wrappers, so the tests and the app don't change.
- **Measure:**
  - Bench A: `BatteryReading(rawCapture:)` 48 µs → about 20 µs on the real fixture.
  - All `MacPowerParserTests`, `RegistryChildrenTests` and `SMCTests` stay green.
  - The `parse` signpost of §2.2 on the M5.
- **Risk:** none for behaviour. The gain is about 28 µs per read; at a 2 s poll that is about 0.0014 % of one core. So it is P3, unless E4b's split shows that `parse` matters.

### CORE-11: plausibility ranges and unit conversions are duplicated, with different limits (readability, P3, WP-2 with WP-7)

- **Where:**
  - `SMCBattery.plausiblePackVoltage` (`SMC.swift:342`) and `IDeviceBatteryParser.plausiblePackVoltage` (`IDeviceBattery.swift:243`) are the same `2_500...20_000`.
  - There are three centidegree-to-°C conversions:
    - `MacPowerParser.celsius(fromCentidegrees:)`, `-40...150` (`MacPowerParser.swift:285-288`);
    - inline in `RegistryChildren.temperatureCelsius`, `-20...85` (`RegistryChildren.swift:55-56`);
    - `IDeviceBatteryParser.celsius(fromCentidegrees:)`, `0` = none, `-40...150` (`IDeviceBattery.swift:248-252`).
  - `-20...85` duplicates `SMCBattery.plausibleTemperature` (`SMC.swift:282`).
  - The decikelvin conversion is in `SMC.swift:326-329` and again in `RawValueDecoding.swift:71`.
- **Change:**
  - Add one internal `enum BatteryUnits` (or extend `SMCBattery`) with `plausiblePackVoltageMV`, `plausibleCellVoltageMV`, `plausibleTemperatureC`, `celsius(centidegrees:in:)` and `celsius(decikelvin:)`. Callers keep their current ranges as arguments.
  - Whether a macOS 27 pack temperature above 85 °C should be dropped while the top-level key allows up to 150 °C is a decision. Record it; don't change it here.
- **Measure:** all parser tests stay green, and the outputs of the golden fixtures are unchanged.
- **Risk:** low. It must stay a pure refactor; don't unify the ranges by accident.

### CORE-12: the menu bar icon's digits round differently from every other percentage (latent bug, P3, WP-9 or WP-2)

- **Where:**
  - `BatteryIcon.swift:48`: `Int(min(100, max(0, $0)).rounded())` rounds half away from zero.
  - `BatteryFormatter.percent` (FormatStyle, ICU) and `BatteryMotionKey` (`BatteryMotion.swift:97-98`, which documents it) round half to even.
  - A scratch check over 0…100 in 0.5 steps found **50 of 201 mismatches**: 2.5 % gives text "2" and icon "3", 22.5 gives "22" and "23", and so on.
  - Today `chargePercent` is an integer on the M5 and in Demo Mode (`DemoBattery.swift:71`), so the bug shows only when IOPS lacks `Current Capacity`/`Max Capacity` and the `CurrentCapacity`/`MaxCapacity` fallback has a max other than 100 (`MacPowerParser.swift:157-158`).
- **Change:**
  - Add `BatteryPresentation.displayedPercent(_ value: Double) -> Int`, which clamps and rounds with `.toNearestOrEven`.
  - Use it in `BatteryIconState.init(snapshot:)` and in `BatteryMotionKey`'s two initialisers. `WidgetReloadPolicy` (`BatteryPresentation.swift:134`) can use it too, for consistency.
- **Measure:** a new `@Test(arguments:)` over 0…100 in 0.5 steps: `BatteryIconState(snapshot:).percent` equals the digits of `BatteryFormatter(locale: en_US).percent(v)`. The existing icon tests stay green.
- **Risk:** a visible change only at exact .5 values, and that change is the fix.

### CORE-13: the date key builds two Gregorian calendars per call, and `HistoryExport` has its own civil-date code (readability, P3, WP-3)

- **Where:**
  - `HistoryStore.fileDay` (`HistoryStore.swift:46-50`) builds a UTC Gregorian `Calendar` only to pass its time zone. `HistoryDay.key(for:calendar:)` (`History.swift:165-168`) then builds another one through `gregorian(in:)` (`:178-182`) and formats with `String(format: "%04d-%02d-%02d", …)`.
  - `HistoryExport.fileName` (`HistoryExport.swift:191-195`) builds a third calendar, again only for its time zone.
  - `ExportBuffer.civil(fromDays:)` (`HistoryExport.swift:435-445`) already computes Gregorian dates without `Calendar`.
- **Change:**
  - Add an internal `HistoryDay.key(for:timeZone:)`. It returns `civil(fromDays: floor((t + tz.secondsFromGMT(for: date)) / 86_400))`, formatted with `ExportBuffer`'s zero-padding.
  - `fileDay` passes `.gmt`; `fileName` passes its `timeZone`.
  - Keep the public `key(for:calendar:)` as a wrapper. The Buddhist-calendar tests (`HistoryTests:200-202`) prove that it ignores the calendar's identifier.
  - SUI-04 already fixes `day.date()`; this is the formatting half.
- **Measure:**
  - `timesMatchFoundationAcrossTimeZonesAndDaylightSaving` and the new key tests stay green.
  - A brute-force test compares the new key with `Calendar`'s for every hour of 1970–2100 in 5 time zones, run once and then sampled.
  - Day-file names are unchanged: same keys.
- **Risk:** the storage format depends on the key. The test above guards it, and the rollout must not rename existing files.

### CORE-14: `HistoryStore.record(_ day:at:)` defaults to `Date()` and ignores the injected clock (readability/testability, P3, WP-3)

- **Where:**
  - `HistoryStore.swift:149`: `public func record(_ day: HistoryDay, at now: Date = Date())`. The actor has `private let now: @Sendable () -> Date` (`:27`).
  - Both production callers pass `at: now` explicitly (`HistoryRecorder.swift:73`, `IDeviceMonitor.swift:572`), so the default is reached only by tests and future callers.
- **Change:** make it `at date: Date? = nil` with `let now = date ?? self.now()`, or remove the default.
- **Measure:** the existing day-summary tests stay green; a new test with an injected clock checks the `daysWriteInterval` throttle with no explicit `at:`.
- **Risk:** none.

### CORE-15: the report text layout and the adapter line exist twice (readability, P3, WP-7)

- **Where:**
  - `IDeviceReport.text(for:)` (`IDeviceReport.swift:79-87`) repeats `BatteryReport.text(for:)` (`BatteryReport.swift:121-128`), the same padding code.
  - The adapter line `IDeviceReport.swift:61-70` repeats `BatteryReport.swift:86-95` line for line.
- **Change:** add `static func text(_ lines: [BatteryReport.Line]) -> String` and `static func adapterSummary(_ adapter: PowerAdapter) -> String` in `BatteryReport`, used by both.
- **Measure:** the golden `bpulse` report and `bpulse --device <n>` output stay byte-identical (`IDeviceReportTests`, `MetricsAndReportTests`).
- **Risk:** none.

### CORE-16: hand-written CGPoint/CGRect/CGSize equivalents (native/size, P3, WP-9)

- **Where:**
  - `BatteryIcon.swift:78-142`: `IconPoint`, `IconRect` (with `maxX`/`midX`/`insetBy`/`centered`) and `IconSize`.
  - The app converts them back to Core Graphics (`BatteryIconView.swift:178`, `:191-195`).
  - On Linux, `import Foundation` provides `CGPoint`, `CGRect` (with `insetBy(dx:dy:)` and `midX`) and `CGSize`; verified with a scratch `swiftc` on 6.4.1.
- **Change:** replace the three structs with `CGPoint`/`CGRect`/`CGSize`. Keep `IconRoundedRect` as `(rect: CGRect, cornerRadius: Double)` and `centered` as a small `CGRect` extension. Delete `cgRect(_:)` in the app.
- **Measure:**
  - The `MenuBarTests` icon-geometry tests pass with the same numbers.
  - The size report shows the `IconRect` metadata gone.
  - Visual check of the five icon styles on the M5 at 1× and 2×.
- **Risk:**
  - On Darwin, `CGRect.insetBy` returns `.null` for a negative size, and `maxX` and similar standardize the rect. `IconRect` does neither. Every layout rect is positive today; add a test that asserts `width > 0` for every style.
  - `Hashable` isn't needed: `BatteryIconLayout` is `Equatable` only.
  - Skip this item if it collides with WP-9's view work.

### CORE-17: duplicated fixture loading and one silent guard in tests (tests/readability, P3, SW-19/SW-R15)

- **Where:**
  - The same `Bundle.module.url(…subdirectory: "Fixtures")` + `PropertyListSerialization` + `PropertyValue.dictionary(fromAny:)` block appears in:
    - `Fixture.swift:26-32`;
    - `AccessoryFixture.swift:15-20`;
    - `AccessoryCaptureTests.swift:36-38`;
    - `RealIDeviceCaptureTests.swift:11-13`.
  - 90 call sites re-parse fixture plists on every use.
  - `RealIDeviceCaptureTests.swift:79`: `guard case .dictionary(let raw) = … else { return }` passes silently.
- **Change:**
  - Add one `func fixtureDictionary(_ name: String) throws -> PropertyDictionary` with a `static let` cache (fixtures are immutable), used by all four.
  - Line 79 becomes `let raw = try #require(withUUID(.dictionary(fixture)).dictionaryValue)`.
- **Measure:** the test count is unchanged (455); `swift test` stays green; a deliberately wrong fixture name now fails instead of passing.
- **Risk:** none.

### CORE-18: `leftoverToDelete` accepts any `.app` path that the preferences hold (security hardening, P3, WP-6)

- **Where:** `UpdateInstall.swift:155-163`.
  - The path comes from the `updateLeftover` default.
  - Any absolute `.app` path with at least 2 components that is neither the running app nor inside or around it passes. A tampered preference could make the next launch delete, say, `/Applications/Other.app`. Tampering already needs user-level code, so this is defense in depth only, not a boundary.
- **Change:** also require the leftover's last path component to equal the running bundle's (`BatteryPulse.app`). The swapped-out copy always keeps the app's name; see the test path `…/NSIRD_BatteryPulse_x/BatteryPulse.app` (`UpdateInstallTests:213`).
- **Measure:** add a case to `deletesOnlyThePreviousVersion`: `"/Applications/Other.app"` → `nil`. The existing cases stay green. On the M5, an update 0.6.0 → candidate still removes the leftover at the next launch.
- **Risk:** a user who renamed the app (`BatteryPulse 2.app`) keeps an old copy around. Compare with the running bundle's name, not with a constant.

### CORE-19: the device secret's folder is created with default permissions (security hardening, P3, WP-7)

- **Where:** `DeviceStore.swift:133-150`.
  - `createDirectory(at: directory, withIntermediateDirectories: true)` makes `Devices/` with the umask, 0755.
  - `FileManager.createFile(…, attributes: [.posixPermissions: 0o600])` sets the mode after writing, so the temporary key file briefly has the umask's mode. `setAttributes` (`:143`) then repeats the same mode.
  - `~/Library` is 0700 by default, which is why this is P3.
  - Nit: `} catch  where` (`:146`) has a double space.
- **Change:**
  - Create `Devices/` with `attributes: [.posixPermissions: 0o700]` when the secret is first created. It holds the HMAC key and the device names.
  - Remove the duplicate `setAttributes`, or keep exactly one place that sets 0600.
- **Measure:** a `DeviceStoreTests` case checks that the folder's mode is 0700 and the key's is 0600 after `secret()`, on Linux and on macOS.
- **Risk:** existing installs keep 0755 unless the folder's mode is also set when the key already exists. That is optional.

### CORE-20: `BatteryPresentation.swift` holds four unrelated types (readability, P3, move only)

- **Where:** `BatteryPresentation.swift`:
  - `RawEntry`: `:71-103`;
  - `BatteryWidgetKind`: `:105-109`;
  - `WidgetReloadPolicy`: `:111-152`;
  - `WidgetTimelinePlan`: `:154-206`.

  Their tests already have their own files: `WidgetReloadPolicyTests` and `WidgetTimelinePlanTests`.
- **Change:**
  - Move the widget types to `Sources/BatteryCore/Widget.swift`.
  - Move `RawEntry` next to `RawSection`, or into `RawValueDecoding.swift`.
- **Measure:** `git diff -M` shows pure moves; the builds stay green.
- **Risk:** none. Do it after WP-5's and WP-4's edits to avoid conflicts.

## Considered, no change

- `SMCResult` (`SMC.swift:124-139`): only `.success` and `.keyNotFound` are used (`SMCClient.swift:134-135`). The other 12 cases document the protocol and cost almost nothing. Keep them.
- `HistoryExport`'s hand-written CSV/JSON writer: the output has to stay byte-identical (§3.4), and `JSONEncoder` can't keep its digit rules or key order. Keep it.
- `ReleaseNotes.LineJoiner` (`Updates.swift:192+`, about 300 lines): `AttributedString(markdown:)` with `PresentationIntent` is the native route, but it isn't testable on Linux, and the joiner is covered by `UpdatesTests`. Keep it.
- `AccessoryBattery.id` (FNV of a possible Bluetooth address) is already left out of JSON and captures (`Accessory.swift:122-150`).
- `SMCValueDecoder.number` switches on `info.type.description`: a small string with no heap allocation, and cheap enough.
- Linux `PropertyValue(any:)` turns `<real>3</real>` into `.int(3)`, while Darwin gives `.double`. The accessors hide the difference. No change.
