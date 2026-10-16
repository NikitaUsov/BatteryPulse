# Core audit, verified (adversarial pass)

Source: `audit-core.md` (CORE-01 to CORE-20), checked against `6133b4f` (release 0.6.0).
`main` has moved on since then (`a32bfae`). Those later commits touch `BatteryPresentation.swift`
(`WidgetReloadPolicy`) and `WindowLook.swift` (Clear's dimming). The notes below say where that
matters.

How I checked it, all read-only:
- I exported `6133b4f` with `git archive` into `verify-core/src` and ran `swift build --build-tests`
  and `swift test` there (Linux, 4 cores), parallel and `--no-parallel`. Logs:
  `verify-core/test-par.log` and `verify-core/test-ser.log`.
- `verify-core/hex.swift` is a standalone `-O` benchmark of the `.data` description. It uses the
  real blob sizes of `m5-macos27-unplugged.plist`: 29 blobs, 1113 bytes.
- `verify-core/rx.swift` is a Swift 6 language-mode check of `static let` regexes.
- I ran the audit's existing rounding check (`core-bench`) and regex/codeOnly benches (`core-exp`)
  again.

## Summary

| ID | Verdict | Prio | Package | One line |
|---|---|---|---|---|
| CORE-01 | keep-modified | P2 | WP-7 | One-line `.data` encoder swap, measured 20× (byte-identical). Drop the new `Hex` type and the stored `RawRow.value` |
| CORE-02 | keep-modified | P2 | WP-0 | In-place `starts(with:at:)` plus a per-process source cache. `static let` regexes don't compile (Regex isn't Sendable), and the prefilter is rejected |
| CORE-03 | keep-modified | P3 | WP-6 | Make the test fast with a test-side `sleep 1` → `sleep 0` swap. No new production parameter. The real gain is about 0.2–0.4 s of parallel wall time, not 1 s |
| CORE-04 | keep-modified | P3 | WP-0 | Cache the catalog and source keys once. No `static let` regexes |
| CORE-05 | keep | P3 | WP-11 | Drop `Codable` from `IDeviceInfo` (UDID-bearing, never encoded) |
| CORE-06 | keep-modified | P3 | WP-11 | Delete the truly dead members. Move `hasHue` into the tests. The `WindowLookPolicy` flags wait for the Clear legibility work |
| CORE-07 | keep | P3 | WP-11 | Drop `Codable` from 4 types that are never encoded, with CORE-05 |
| CORE-08 | keep-modified | P2 | WP-11 | Fix 3 comments. The other 2 disappear with CORE-06/CORE-09 |
| CORE-09 | keep | P3 | WP-11 | Fold `sections(for:)` into `lines(for:)` |
| CORE-10 | reject | — | — | 28 µs per read is not measurable, and it adds parallel overloads |
| CORE-11 | reject | — | — | `BatteryUnits` with explicit ranges is churn across 3 packages and removes nothing |
| CORE-12 | keep-modified | P3 | WP-5 | Round the icon half-to-even like the text. The widget policy site is optional |
| CORE-13 | reject | — | — | Hand-rolled day keys for storage names: no gain, risk to storage, and an infeasible guard test |
| CORE-14 | keep-modified | P3 | WP-3 | Just remove the `= Date()` default. Every caller passes `at:`; no new test |
| CORE-15 | keep | P3 | WP-11 | Share the padding and adapter summary between the two reports |
| CORE-16 | reject | — | — | Menu bar icon geometry to CG types: risky semantics for about 50 lines. Defer |
| CORE-17 | keep-modified | P3 | WP-11 | One fixture loader, no static cache. `#require` instead of `guard … return` |
| CORE-18 | reject | — | — | `removeLeftovers` already deletes only a bundle with this app's identifier |
| CORE-19 | keep-modified | P3 | WP-7 | `Devices/` 0700 when it is created. Line numbers in the audit are wrong (62–80) |
| CORE-20 | reject | — | — | A pure move in a file the maintainer is still changing |

Kept: 14 (5 as is, 9 modified). Rejected: 6.

## Details

### CORE-01: `.data` description (keep-modified, P2, WP-7)

**Confirmed.**
- `PropertyValue.swift:143` builds one `String(format: "%02x")` per byte.
- `RawRow.value` is computed from `property.description` (`RawKeyGlossary.swift:1127`).
- `DeveloperView` reads it per cell (`:149`, `:153`, `:310`), per search pass (`:226`) and in Copy
  Value (`:195`).
- My benchmark, real blob sizes, `-O`, Linux: 1.241 ms → 0.063 ms per full capture. The output is
  byte-identical for every blob (precondition-checked).

**Modified.**
1. The fix is one line: `case .data(let value): "<" + UpdateIntegrity.hex(value) + ">"`.
   `UpdateIntegrity.hex` is public and already tested (`UpdateInstallTests:96`). Add the test
   `Data([0x00, 0xAB, 0x0F])` → `"<00ab0f>"`.
2. Don't add a `Hex` namespace now:
   - `DeviceKeyDerivation`'s loop runs once per device.
   - `bpulse --smc` is a Darwin-only debug listing where speed doesn't matter.
   - `HistoryExport`'s escape appends ASCII bytes into a byte buffer, which is a different shape.

   If WP-11 wants one encoder, it can point `DeviceKeyDerivation` at the same function later.
3. Drop "make `RawRow.value` a stored let". SUI-02 (WP-5) already builds display rows with
   precomputed strings and a joined `searchText`. A stored copy would add state to an `Equatable`
   model for the same effect.

**Package.** WP-7, which owns `PropertyValue.swift`. WP-5's B4 bench (sections plus display rows)
then shows the gain after a rebase. After SUI-02 the cost is once per reading and off the main
actor, so this is P2, not P1.

### CORE-02: MotionGuardTests speed (keep-modified, P2, WP-0)

**Confirmed.** `appAndWidgetFollowTheMotionRules` takes 1.328 s serial and 1.529 s parallel.
`codeOnly`'s `starts(with:at:)` allocates two arrays per call.

**Wrong as written.**
- **`static let` regexes don't compile.** The test target is Swift 6 language mode (tools 6.0).
  `static let r = #/…/#` fails with "static property 'r' is not concurrency-safe because
  non-'Sendable' type 'Regex<…>'". I checked this with `verify-core/rx.swift`, and it is why the
  file uses computed `static var`.
- **Sharing is worth little.** The audit's own `core-exp/regexbench` gives 0.312 s fresh against
  0.285 s shared, so reuse saves about 9%.
- **The literal prefilter is rejected.**
  - `systemColor`, `standardToneColor`, `indefiniteRepeat` and `windowBackgroundAPI` are
    alternations with no single literal prefix.
  - A per-alternative anchor list is exactly the hidden-violation risk the audit names, in the
    one test that guards CLAUDE.md's glass and motion rules.
  - That isn't worth about 1 s of test time.

**Kept.** Inside WP-0's `SourceScanner` extraction:
- Compare characters in place in `starts(with:at:)`. The audit measured about 0.3 s at `-Onone`.
- Add a `static let` source table: path, text and `codeOnly` result for each file. It is
  `[String: String]`-shaped and Sendable, so it compiles, and `swift_once` makes it thread-safe.
  The WP-12 guard suites then share one read and one blanking pass.
- Optionally, parameterize the scan over the files with `@Test(arguments:)`. That follows SW-R15,
  gives per-file failure reports, and lets swift-testing spread the regex work over the cores.
  Keep the `scanned > 20` check as its own assertion on the file list.

**Measure.** The catches and allows tables stay green. A violation injected into a scratch copy
still fails. Report serial and parallel time before and after; there is no fixed target.

### CORE-03: relaunch test sleeps 1 s (keep-modified, P3, WP-6)

**Confirmed.** It runs for 1.008 s serial. The script always runs `sleep 1`
(`UpdateInstall.swift:146-149`).

**The claim is overstated.** In my parallel run the suite takes 1.716 s. The next-longest tests are
MotionGuard (1.529 s), `timesMatchFoundationAcrossTimeZonesAndDaylightSaving` (1.331 s) and
`wifiPresenceExpiresAfterTenMinutes` (1.073 s). Removing the sleep therefore saves about 0.2 s of
parallel wall time, or about 0.4 s together with CORE-02, not "2.5 s → 1.5 s". It saves 1 s serial.

**Modified.** Don't add a production `settleSeconds` parameter, because the app's script and API
should stay as they are. In the test:
1. Take `relaunchArguments(…)`.
2. `#expect(arguments[1].contains("sleep 1; exec"))`.
3. Replace `"sleep 1;"` with `"sleep 0;"` in `arguments[1]`.
4. Run it.

The quoting under test (`"$1"`, `"$3"`) is untouched. That is two lines, test-only, with no risk to
the relaunch.

### CORE-04: LocalizationCatalogTests (keep-modified, P3, WP-0)

**Confirmed.**
- `everyUIStringIsTranslated` takes 0.531 s and `catalogHasNoLeftovers` 0.544 s, serial.
- Both call `sourceKeys()`, which is the regex scan over every app and widget source, and each
  decodes the catalog.

**Modified.**
- Cache `private static let` `Result<Catalog, any Error>` and `Result<Set<String>, any Error>`
  values. `Catalog` is a private struct, so it is implicitly Sendable, and `Set<String>` is too.
- Leave the regexes as computed `static var`, for the same Swift 6 reason as CORE-02.
- Expected: about 0.5 s less serial time. The parallel critical path doesn't change.
- WP-0 is the right home because it already owns the test scaffolding (`SourceScanner`). If
  `sourceKeys` moves onto the scanner's cached table, it shares the file reads too.

### CORE-05: `IDeviceInfo: Codable` (keep, P3, WP-11)

**Confirmed.**
- No encoder or decoder touches `IDeviceInfo` or `[IDeviceInfo]`. I checked every `JSONEncoder`,
  `JSONDecoder`, `PropertyListEncoder` and generic `some Encodable` site: `HistoryStore` only
  encodes samples and days, `bpulse` encodes snapshot, battery and accessories, and the app
  encodes snapshot and alert state.
- `IDeviceSession`, which holds the identity, is not Codable.
- `RememberedDevice.lastConnection` keeps `IDeviceConnection` Codable.

**Verdict.** Removing it is one word. It is a real SEC-R9 guard rail against a future
`--devices --json` silently writing UDIDs. Priority P3 rather than P2, since nothing leaks today.

### CORE-06: dead members (keep-modified, P3, WP-11)

**Confirmed by grep at `6133b4f` and `HEAD`.**
- `RawKeyGlossary.keys` is used nowhere.
- `RawEntry.id`, `.value` and `Identifiable` are unused. Its tests compare with `==` and nothing
  iterates `RawEntry` in a `ForEach`.
- These are test-only: `WindowLookPolicy.allowsTertiaryText` and `dividesGroupsWithHairlines`,
  `BatterySnapshot.wearPercent` (not in the JSON either, since it is computed), `MenuBarIconStyle.isDrawn`,
  `Tone.hasHue` and `HistoryStore.samples(since:)`.
- `samples(since:)` is called by `BatteryKitTests/IDeviceMonitorTests.swift:330` and
  `DeviceStoreTests`, so those tests need changing too.

**Modified.**
- Delete `RawKeyGlossary.keys`, `RawEntry.id`, `.value` and `Identifiable`, `wearPercent`,
  `isDrawn` and `samples(since:)`. Point their tests at what the app uses: `healthPercent`,
  `!= .symbol` and `samples(from:)`.
- Move `hasHue` into the test target as an extension (DC-3). It is the predicate behind
  `ToneMapTests`' "Clear shows no hue" invariant, so the invariant stays tested.
- `allowsTertiaryText` and `dividesGroupsWithHairlines` are redundant:
  - `ToneMap.swift:243` already lifts `.tertiary` to `.secondary` on the glass sheet.
  - `dividesGroupsWithHairlines` is `groupSurface == .none`.

  But `WindowLook.swift` is being changed for the user's Clear and Translucent legibility problem
  (`6584585`, `ec61436`). Delete these two only after that work settles. Then assert on
  `toneMap.tone(.text(.tertiary))` and `groupSurface` instead.
- Each deletion still needs WP-11's DC-1 maps.

### CORE-07: unused `Codable` (keep, P3, WP-11)

**Confirmed.** None of these is encoded:
- `IDeviceIdentity`: `RememberedDevice` stores the fields flat, and `IDeviceSession` isn't Codable.
- `MenuBarItem`: `MenuBarContent` isn't Codable.
- `MenuBarIconStyle`: stored by `@AppStorage` through `RawRepresentable`, which doesn't need
  Codable. The settings key and type stay the same.
- `BatteryAlert`: `AlertState` holds Bools and a Date.

DC-4 is not violated, because no Codable keys run through the runtime here. Only
`IDeviceIdentity`'s synthesized coding is real weight; the enums are conformance records. Do it in
one commit with CORE-05. Check on the M5 that the icon style survives a relaunch.

### CORE-08: comments that disagree with the code (keep-modified, P2, WP-11)

**Confirmed for all five.**

**Modified.** Two of the five go away with their code: `BatteryReport.Section`'s "Details window"
(CORE-09) and `RawKeyGlossary.keys`'s "coverage tests" (CORE-06). Fix the other three:
- **`BatterySnapshot.swift:5-6`.** Temperature and cell voltages moved to the child entries; they
  weren't dropped. Wrap the line at 120 characters.
- **`IDeviceBattery.swift:245-247`.** The unit is the same as macOS's (centidegrees). The real
  differences are that on iOS 0 means "no reading" and the range is −40…150 °C. The Mac pack
  entry uses −20…85 °C (`RegistryChildren:55-56`). Writing that down covers CORE-11's "record the
  85 °C limit".
- **`CaptureRecorder.swift:256`.** "goes first" is ambiguous. Say that the `before` capture is the
  one dropped when slots run out, which is what `suffix` does.

Comment-only change; `swift format lint --strict` stays clean.

### CORE-09: `BatteryReport.Section` (keep, P3, WP-11)

**Confirmed.**
- `sections(for:)` and `Section` are used only by `lines(for:)` and by
  `MetricsAndReportTests.swift:166-168`.
- `text(for:)` prints no section titles.
- The app (`MainView:430`) and `bpulse` (`main.swift:159`) use `text(for:)`, and `IDeviceReport`
  uses `Line`.

**Change.** Remove `Section` and `close()`. Keep the five group boundaries as one-line `//`
comments, so the reading order stays visible. The golden text report is byte-identical. Do it in
one commit with CORE-15, since both touch `BatteryReport.swift`.

### CORE-10: one registry and SMC pass per read (reject)

The repeated walks are real (`MacPowerParser:129, 194-201`; `SMC:335, 359, 383`). But the whole
gain is about 28 µs per read, and the app reads at most about once a second while live. No §2
metric can see that: it is about 0.003% of one core, and IOKit's registry copy costs milliseconds.
The change adds a second, entries-based overload for each of three public functions, which is more
code for nothing measurable. Revisit only if WP-0's B1 shows parse above 1 ms on the M5, and fold
it into E4b then.

### CORE-11: `BatteryUnits` namespace (reject)

The duplicates are real but tiny:
- the pack-voltage range, declared twice;
- the decikelvin formula, twice;
- three centidegree conversions.

The ranges differ on purpose: −40…150 for iOS and the IOPS fallback, −20…85 for the pack and the
SMC, and 0 means none on iOS. A namespace where every caller passes its own range explicitly
removes no logic and makes five call sites longer. It also spreads across SMC (WP-2),
RawValueDecoding (WP-5) and unowned files, and it carries the risk the audit itself names:
unifying the ranges by accident. The one useful part, writing down the 85 °C limit, is folded into
CORE-08.

### CORE-12: icon digits round differently (keep-modified, P3, WP-5)

**Confirmed.**
- I ran `core-bench` again: 50 of 201 half-steps mismatch.
- `BatteryIcon.swift:48` uses `.rounded()`, which is `.toNearestOrAwayFromZero`.
- `BatteryFormatter.percent` (FormatStyle) and both `BatteryMotionKey` initialisers use half-even.
- It is latent: the macOS 27 percent is an integer, and Demo Mode uses integer levels.

**Modified.**
- The fix is `.rounded(.toNearestOrEven)` in `BatteryIconState.init(snapshot:)`.
- A shared `BatteryPresentation.displayedPercent(_:)` used by the icon and both motion keys is fine
  if it reads better.
- `WidgetReloadPolicy`'s `percent` only measures movement against `percentStep`, so its rounding
  mode doesn't change behaviour. Changing it is optional. Note that it moved in `994c09d`; it is
  around line 140 at `HEAD`.
- Keep the `@Test(arguments:)` over 0…100 in 0.5 steps against the en_US formatter.

**Package.** WP-5, which owns `BatteryFormatter`, the reference this rounding must match.

### CORE-13: day keys without Calendar (reject)

- **No gain.**
  - `fileDay` runs once per recorded sample (about once a minute) and at range bounds.
  - It runs per sample only in the one-time legacy migration (`HistoryStore:139`).
  - `HistoryDay.key` runs once per day summary write.
- **Risk.** The keys name the storage files, which the playbook says must not change (§3.4).
  `Calendar` with the time zone is the API Apple intends.
- **The proposed guard is infeasible.** "Every hour from 1970 to 2100 in 5 time zones" is about
  5.7 M `Calendar` comparisons, tens of seconds per run.
- **It belongs elsewhere.** The real per-sample cost is the `Calendar` built in `HistoryDay.date()`
  for charts, and SUI-04 (WP-3) owns that.

### CORE-14: `record(_:at:)` default (keep-modified, P3, WP-3)

**Confirmed.** `HistoryStore.swift:149` has `at now: Date = Date()`, which bypasses the injected
clock. Every caller passes `at:`:
- `HistoryRecorder:73`
- `IDeviceMonitor:572`
- `HistoryTests:211-224`

**Modified.** Remove the default (`at now: Date`) rather than adding an optional. That is
zero new lines, no new test, and a compile error for any future caller that forgets the clock.

### CORE-15: shared report helpers (keep, P3, WP-11)

**Confirmed.**
- `IDeviceReport.text(for:)` (`:79-87`) duplicates `BatteryReport.text(for:)` (`:121-128`).
- The adapter block (`IDeviceReport:61-70`, `BatteryReport:86-95`) is identical, and both use the
  same `PowerAdapter` type.

**Change.** Add two internal helpers, `BatteryReport.text(_ lines:)` and `adapterSummary(_:)`.
The golden `bpulse` text report and the `--device` output must stay byte-identical. Same commit as
CORE-09.

### CORE-16: `IconRect` to `CGRect` (reject for 0.6.1)

- **The menu bar icon is the most visible element.** The audit itself lists the semantic traps:
  Darwin's `CGRect.insetBy` gives `.null` for a negative size, and `maxX`/`midX` standardize the
  rect, while `IconRect` does neither.
- **Hard to verify.** It needs a visual check of five styles at 1× and 2× on the M5.
- **Little gain.** About 50 lines and a conversion helper.
- **Type friction.** On Linux, `CGFloat` is a separate type, so the Double-based layout code and
  the tests need conversions.
- **The current types are honest.** They are plain, Linux-tested and documented (y-down, top-left
  origin).

Defer to a release that redesigns the icon anyway.

### CORE-17: test fixture loading (keep-modified, P3, WP-11)

**Confirmed.** The same three-line `Bundle.module` → plist → `PropertyValue.dictionary(fromAny:)`
block appears four times:
- `Fixture.swift:26-32`
- `AccessoryFixture.swift:15-20`
- `AccessoryCaptureTests.swift:36-38`
- `RealIDeviceCaptureTests.swift:11-13`

`RealIDeviceCaptureTests.swift:79` has `guard case .dictionary … else { return }`.

**Modified.**
- Add one `fixtureDictionary(_:)` helper.
- No static cache. Parse cost is negligible, and a shared mutable cache under parallel
  swift-testing would need a `Mutex` for no measured gain.
- Replace the guard with `try #require(...dictionaryValue)` (SW-R15).

This sits with SW-19 in WP-11.

### CORE-18: leftover name check (reject)

The premise "a tampered preference could make the next launch delete another app" is false:
- `UpdateInstallSteps.removeLeftovers` (`UpdateInstaller.swift:529-541`) reads the leftover's
  `Contents/Info.plist`.
- It deletes only when `CFBundleIdentifier` equals this app's identifier.

So it can only ever delete another copy of BatteryPulse. A name check adds nothing on top of that.
It would also stop a legitimate cleanup if the user renames the app between the update and the
next launch, because the leftover keeps the old `target.lastPathComponent`. Tampering already
needs user-level code, and that code can delete anything.

### CORE-19: `Devices/` permissions (keep-modified, P3, WP-7)

**Confirmed, with wrong line numbers.** The code is `DeviceStore.swift:62-80`
(`createSecret()`), not `133-150`.
- `createDirectory(at:withIntermediateDirectories: true)` uses the umask.
- `createFile(… attributes: [.posixPermissions: 0o600])` and the following
  `setAttributes(0o600)` repeat one another.
- There is a double space in `catch  where` (`:77`).

**Modified.**
- Pass `attributes: [.posixPermissions: 0o700]` to the `createDirectory` in `createSecret()`.
  That applies only to folders it creates, so new installs get it.
- Keep a single 0600 step. Keep the explicit `setAttributes`, since it behaves the same on Linux.
- Don't chmod existing folders. `~/Library` is 0700, and changing the mode of an existing folder
  is a behaviour change with no benefit.
- Fix the double space.
- Add a `DeviceStoreTests` case: after `secret()` on a fresh directory, the folder is 0700 and
  `key` is 0600.

### CORE-20: move widget types out of `BatteryPresentation.swift` (reject)

This is a pure move: no behaviour, size or speed effect. It churns blame, and it would conflict
with the maintainer's current work: `994c09d` rewrote `WidgetReloadPolicy` in this file after
`6133b4f`. Move the types when the file is next substantively changed, not as a 0.6.1 item.

## Effect on the playbook

- **WP-0:** CORE-02 (scanner changes, minus `static let` and the prefilter) and CORE-04.
- **WP-3:** CORE-14.
- **WP-5:** CORE-12.
- **WP-6:** CORE-03 (test-only).
- **WP-7:** CORE-01 and CORE-19.
- **WP-11:**
  - one commit "drop unused Codable": CORE-05 and CORE-07;
  - dead members: CORE-06, with the `WindowLookPolicy` flags after the Clear legibility work;
  - one `BatteryReport` commit: CORE-09 and CORE-15, plus CORE-08's comments;
  - the fixture helper: CORE-17.
- **Rejected; don't resurrect:**
  - CORE-10 (unless B1 shows parse above 1 ms on the M5);
  - CORE-11;
  - CORE-13;
  - CORE-16 (deferred);
  - CORE-18;
  - CORE-20;
  - "static let regexes" in the test target (they don't compile in Swift 6 mode);
  - literal prefilters in guard tests.
