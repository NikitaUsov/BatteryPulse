# Audit "cli-build": bpulse, Package.swift, scripts, workflows, Resources, repo-wide dead code

Base: `main` = `7bb2ac7`. Its `Sources`, `Package.swift`, `scripts`, `.github/workflows` and
`Resources` are identical to `6133b4f` (0.6.0); `git diff --stat 6133b4f HEAD` on those paths is
empty. Read-only: the repository was not modified. Scratch work is in `v061/cli-build/`:
- `legacy/`: the history-export repro (CB-01);
- `exetest/`: a throwaway package that shows `@testable import` of an executable with top-level `await`
  works on Linux, Swift 6.4.1 (CB-04);
- `ua/`: shallow clones of `actions/upload-artifact` v4 to v7, used only to read `action.yml` (CB-07);
- `ci-macos.log`: a macOS CI run of `6133b4f`, used for step times and warnings.

`bpulse` runs used the existing Linux debug build `v061/core-build/debug/bpulse` (Swift 6.4.1).

This file adds to the playbook. It doesn't repeat items that the playbook or the sibling audits
already own:
- SZ-01 to SZ-14: strip, exports, ULMO, size report, `-Osize`, maps, the identity `en` table, the
  icon. SZ-07 also notes that the widget copies every `.lproj` (`build-app.sh:90`).
- SEC-06: workflow `permissions`, `persist-credentials` and SHA pins. SEC-07: the posture checks in
  `build-app.sh`.
- SW-01 and SW-24: the manifest. K-02: job timeouts.
- AV-01 and AV-02: Export Capture, and Copy JSON's redaction, including the note on `bpulse --json`.
- CORE-01: the hex encoders, including `bpulse --smc` at `main.swift:326`.
- CORE-06, CORE-07 and K-08: dead members in BatteryCore, and the SMC result codes.

Where a finding touches one of these items, it names the item and adds only what is new.

## Findings

### CB-01 [bug] `bpulse --export` rewrites the history it reads, and the legacy migration overwrites existing day files (P2, WP-3)

- **Where:**
  - `Sources/bpulse/main.swift:292-296`: the export calls `HistoryExport.data`. That calls
    `store.samples(from: .distantPast)` (`Sources/BatteryCore/HistoryExport.swift:182`).
  - `Sources/BatteryCore/HistoryStore.swift:77-78`: `samples(from:to:)` runs `migrateLegacySamples()`
    first.
  - `HistoryStore.swift:135-143`: the migration writes each day of the legacy `samples.jsonl` with
    `writeLines(…, to: sampleURL(day))`, an atomic **replace**, then deletes `samples.jsonl`.
- **Reproduced** (`v061/cli-build/legacy/`):
  - Setup: a folder with a legacy `samples.jsonl` (t = 1760000000 and 1760000060) and an existing
    `samples/2025-10-09.jsonl` (t = 1760000120).
  - Run: `TZ=UTC bpulse --export csv --history <folder>`. It exits with 0 and prints 2 rows.
  - Afterwards, `samples.jsonl` is gone, and the day file holds only the 2 legacy samples. The third
    sample was lost on disk and is missing from the export.
- **Impact:**
  - A command that only reads, run on someone's or a backup's `--history` folder, deletes and
    rewrites files there.
  - Data is lost whenever a legacy file and a day file for the same UTC day exist together. That
    happens with an old backup next to a current folder, or when the app and `bpulse` migrate at
    the same time. The two are different processes, and the actor serializes only within one. A
    second migration's `removeItem` then throws, and the export fails with status 1.
  - In the app alone, the collision can't happen in the normal upgrade path: the first `record`
    migrates before any day file exists.
- **Change** (DC-5 keeps the migration; it only stops destroying data):
  1. In `migrateLegacySamples()`, merge before writing:
     - read the existing `sampleURL(day)` if it exists;
     - union it with the legacy group, deduplicated by `time`;
     - sort, then `writeLines`.
  2. Give the store a read-only mode:
     - `HistoryStore.init(directory:migratesLegacySamples: Bool = true)`.
     - With `false`, `samples(from:to:)` and `latestSampleTime()` skip the migration. They merge the
       legacy file's samples in memory, filtered to the range, so the export still shows them.
     - `exportHistory` (`main.swift:294`) passes `false`.
  3. The app's call sites keep the default.
- **Measure:**
  - New `HistoryStoreTests` cases on Linux with the repro above:
    - after `record(_:)` in the default mode, the day file holds all 3 samples;
    - in the read-only mode, `samples(from: .distantPast)` returns 3, and `samples.jsonl` is still
      there, byte-identical.
  - Golden: `bpulse --export csv|json` on a folder **without** `samples.jsonl` is byte-identical to
    0.6.0 (§2.6). With the repro folder, the output gains the missing row, which is the fix.
- **Risk:** low.
  - The storage format is unchanged.
  - The merge costs one extra read per migrated day, once in the store's life.
  - The read-only mode reads `samples.jsonl` on every export, which is a rare and small file.
  - It fits E14's "migration once per session" flag.

### CB-02 [bug] The device JSON writes `firstUseDate` as seconds since 2001; the Mac JSON uses ISO 8601 (P2, decision for the maintainer)

- **Where:**
  - `Sources/bpulse/main.swift:194-196`: `renderDevice`'s `JSONEncoder` sets no
    `dateEncodingStrategy`.
  - `main.swift:161-163`: `render` sets `.iso8601`.
  - `IDeviceBattery.firstUseDate` (`Sources/BatteryCore/IDeviceBattery.swift:32`) is a `Date`.
- **Reproduced:**
  - Command: `bpulse --input Tests/BatteryCoreTests/Fixtures/iphone17promax-ios27.0.1-usb.plist --json`.
  - Output: `"firstUseDate" : 781056000`, Foundation's `deferredToDate`, which is seconds since
    2001-01-01. That is 2025-10-02, the day `IDeviceScheduleTests.swift:221` expects.
  - The same output is printed by `--device <n> --json`.
- **Impact:**
  - A script reading the value as Unix time gets 1994-09-30.
  - `docs/USER_GUIDE.md:600` says "`--json` prints the same as JSON", while the Mac snapshot's
    `timestamp` and `gaugeUpdatedAt` print as `"2026-10-16T05:57:50Z"`.
- **Change:**
  - Add one helper in `main.swift`:
    `func jsonText(_ value: some Encodable, compact: Bool = false) throws -> String`. It sets
    `[.prettyPrinted, .sortedKeys]`, or `[.sortedKeys]` when compact, plus `.iso8601`.
  - Use it at all three sites (`:161`, `:194`, `:214`). This also removes two copies of the encoder
    setup.
  - `AccessoryBattery` and `AccessoryPart` hold no `Date` (`Sources/BatteryCore/Accessory.swift:98,
    121`), so the accessory JSON stays byte-identical.
- **§3.4 conflict:** this changes one stdout line of `--device <n> --json`. Choose one:
  - (a) Ship it in 0.6.1 as a bug fix, with a release-notes line, and allow that one line in the
    golden diff.
  - (b) Land only the helper now, keep the device site on `deferredToDate` explicitly, and add a
    `// FIXME(0.7)` comment that names this finding.
- **Measure:**
  - The golden diff (§2.6) over all fixtures:
    - with (a), only the `firstUseDate` line of the iPhone fixture's `--json` changes, to
      `"2025-10-02T00:00:00Z"`;
    - with (b), nothing changes.
  - With CB-04, a test pins the chosen form.
- **Risk:** (a) breaks any script that already parses the number. That is unlikely, since the value
  is undocumented, but it is the reason this is a decision.

### CB-03 [readability, dead-code] `--smc` is a mode stored as an output format, which leaves three unreachable branches (P3, WP-11)

- **Where:**
  - `Sources/bpulse/main.swift:57`: `OutputFormat` has `.smc`.
  - Unreachable `.smc` branches:
    - `render` (`:167-168`, returns `""`);
    - `renderDevice` (`:187`, `case .text, .smc`);
    - `renderAccessories` (`:210`).
  - Why they are unreachable: the parser rejects `.smc` with devices and accessories (`:144`,
    `:150`), and `--smc` exits at `:359-362` before any render.
  - The `--smc` conflict check is the only one outside `parseOptions`: `:360` re-checks `inputPath`
    and `watchInterval` there.
  - `Options.exportFormat` is a `String` (`:69`). Its `default: nil` (`:81`) can't run, because
    `:110` accepts only `"csv"` and `"json"`.
- **Change** (keeps every accepted command line and its output, including last-wins between
  `--json`, `--raw` and `--smc`):
  - Add `var listsSMCKeys = false`:
    - `--smc` sets `format = .text` and `listsSMCKeys = true`;
    - `--json` and `--raw` set `listsSMCKeys = false`.
  - Replace `format != .smc` / `== .smc` with the flag (`:144`, `:150`, `:359`).
  - Add `!options.listsSMCKeys` to the `--record` and `--export` guards (`:128`, `:134`). Today
    `format == .text` rejects `.smc` there, and after the change `--smc` leaves the format at
    `.text`.
  - Move the `:360` guard into `parseOptions`.
  - Delete the three `.smc` cases.
  - Make `exportFormat` an `enum ExportFormat: String { case csv, json }`, parsed with
    `ExportFormat(rawValue:)`, so `exportKind` needs no `default`.
- **Not in 0.6.1:** `--raw --json` and `--smc --json` silently use the last flag (`--smc --json`
  prints the battery JSON). A usage error would be clearer, but it changes the exit status of
  command lines that work today (§3.4). Leave it for 0.7.
- **Measure:**
  - CB-04's parser table passes before and after.
  - Golden `--smc`, `--json`, `--raw`, `--device`, `--accessories` and `--help` are byte-identical.
  - `bpulse --smc --input F` still exits with 1 and prints the usage.
- **Risk:** none for behaviour. It is about 15 lines.

### CB-04 [test-coverage] `bpulse` has no tests; add a test target for its option parser (P2, WP-8 or WP-12)

- **Where:**
  - `Sources/bpulse/main.swift:86-154`: `parseOptions` has 12 interacting rules.
  - The §3.4 contract (stdout and exit codes) is checked only by the one-off golden script (§2.6).
  - `Package.swift:35-40` has no test target for `bpulse`.
- **Verified:**
  - `v061/cli-build/exetest/` is a package with an `executableTarget` whose `main.swift` has
    top-level code and `try await`, and a test target that does `@testable import tool`.
  - `swift test` passes on Linux with Swift 6.4.1.
  - SwiftPM renames the executable's entry point, so the top-level code doesn't run in the test
    process.
- **Change:**
  - Add `.testTarget(name: "bpulseTests", dependencies: ["bpulse"])` and
    `Tests/bpulseTests/OptionParsingTests.swift`.
  - The test is a `@Test(arguments:)` table of argument vectors with their expected
    `Options?`/`exportKind`, recorded from 0.6.0's behaviour. Include every rejection:
    - `--record` with any format;
    - `--days` without `--export csv`;
    - `--history` without `--export`;
    - `--devices --json`;
    - `--accessories --device 1`;
    - `--watch 0`, `--watch inf` and `--watch 86401`;
    - `--device 0`;
    - `--export xml`.
  - Add one `render`/`renderDevice`-level case per output form over the fixtures (text, `--json`,
    `--raw`), compared against small checked-in expectations or against `BatteryReport.text`.
    Avoid the `exit` paths: split `renderDevice` and `renderAccessories` into a pure
    `(String, Int32)` builder and a thin `print`/`exit` wrapper.
- **Measure:** `swift test --filter bpulseTests` passes on Linux and macOS. The release binary is
  unchanged, because test targets don't link into products. Confirm with the SZ-04 size rows.
- **Risk:** low.
  - `Package.swift` is WP-1's file. Add the target after WP-1 merges.
  - The top-level globals of `main.swift` (`usage`, `arguments`, `options`, `provider`) are set
    only by the top-level code, which never runs in the test process. The tests must not read
    them. The functions under test (`parseOptions`, `render`) don't read them either.

### CB-05 [readability] The capture format's plist encoding is written out at 3 product sites and 5 test sites (P3, WP-7 with WP-5)

- **Where:**
  - Encode:
    - `Sources/bpulse/main.swift:172-179` (`xmlPropertyList`);
    - `Sources/bpulse/Record.swift:44`, which turns that `String` back into `Data` for every
      capture;
    - `Sources/BatteryPulseApp/Main/DeveloperView.swift:278-279` (Export Capture);
    - the tests `PropertyValueTests.swift:72`, `AccessoryCaptureTests.swift:23, 29`,
      `IDeviceCaptureTests.swift:49` and `SMCTests.swift:183`.
  - Decode: `main.swift:367-378` (`loadCapture`), plus the fixture loaders that CORE-17 already
    lists.
  - CLAUDE.md calls `--raw` "the capture format used by test fixtures". Yet its definition, an XML
    plist of `PropertyValue.dictionary(…).foundationValue`, lives in the CLI and is copied
    elsewhere.
- **Change:**
  - In `Sources/BatteryCore/PropertyValue.swift`, add:
    - `public static func xmlPropertyListData(_ dictionary: PropertyDictionary) throws -> Data`;
    - `public static func dictionary(propertyListData: Data) throws -> PropertyDictionary?`.
  - `bpulse` and `DeveloperView` call them (with AV-01's `fileExporter`). `Record.swift:44` writes
    the `Data` directly.
  - The tests use them, and CORE-17's fixture helper sits on top.
- **Measure:**
  - The existing round-trip test `PropertyValueTests.swift:72-78` runs through the new functions.
  - Golden `--raw` and `--device --raw` are byte-identical. A `--record` capture file is
    byte-identical too: diff a capture from each build on the M5.
- **Risk:** none. Linux Foundation has `PropertyListSerialization`, and the tests already use it.

### CB-06 [bug, release] The release notes still open with "What's new in 0.6", and nothing ties them to the version being released (P1 for 0.6.1, WP-8)

- **Where:**
  - `.github/workflows/release.yml:182-184` publishes `.github/release-notes.md` as the body of any
    version.
  - `release.yml:151-166` (Resolve version) checks the version format, but not the notes.
  - Line 1 of the file is `## What's new in 0.6`. The headings were `0.4`, `0.5` and `0.6` at
    `15c4bd2`, `8af137d` and `6133b4f`, and the file also has `## What's new in 0.3.1`.
  - The app shows the release body in the Software Update window. So if the notes aren't updated, a
    0.6.1 tag publishes "What's new in 0.6" again, and every 0.6.0 user sees it as the 0.6.1
    update text.
- **Change:** in Resolve version, after the regex check:

  ```bash
  heading="$(grep -m1 '^## ' .github/release-notes.md)"
  if [ "$heading" != "## What's new in $version" ] && [ "$heading" != "## What's new in ${version%.0}" ]; then
    echo "error: .github/release-notes.md starts with '$heading', not the notes for $version" >&2
    exit 1
  fi
  ```

  `${version%.0}` keeps the existing `x.y` headings for `x.y.0` releases.
- **Measure:**
  - Run the snippet locally with `version=0.6.1` on today's file: it fails.
  - With `version=0.6.0` on `git show 6133b4f:.github/release-notes.md`, and with `0.5.0` on
    `8af137d`: it passes.
  - With a `## What's new in 0.6.1` heading: it passes.
- **Risk:** none. The release fails early, before signing, and only when the notes are stale. WP-12
  writes the 0.6.1 notes anyway.

### CB-07 [native] `actions/upload-artifact@v4` runs on the deprecated Node 20, and so does v5; pin v6 (P2, with SEC-06 in WP-8)

- **Where:**
  - `.github/workflows/ci.yml:94`.
  - The macOS run's Complete job step warns: "Node.js 20 is deprecated. The following actions target
    Node.js 20 but are being forced to run on Node.js 24: actions/upload-artifact@v4"
    (`ci-macos.log:2026`).
  - The `action.yml` files read from the tags (`v061/cli-build/ua/`):
    - v4 and v5 have `using: 'node20'`;
    - v6 and v7 have `'node24'`.
  - The v6 README says v6 needs runner 2.327.1 or later. The log shows runner 2.337.0.
  - `actions/checkout@v5` doesn't appear in the warning.
- **Change:**
  - `uses: actions/upload-artifact@b7c566a772e6b6bfb58ed0dc250532a479d7789f # v6.0.0` (the
    `refs/tags/v6.0.0` SHA from `git ls-remote`).
  - Correct SEC-06's suggestion (`security/verified.md:353`, `# v4`) to this pin.
  - v7 also exists (`v7.0.2` = `cf430e030ddbb5b0abf93d22962f4752f3646cd9`), but its README
    reorganizes the upload examples around zipping. Take it only after reading its release notes.
- **Measure:** the next macOS run has no `##[warning]Node.js 20` line, and the
  `BatteryPulse-<sha>` artifact still holds `BatteryPulse.dmg`.
- **Risk:** low. The inputs used (`name`, `path`, `if-no-files-found`) are unchanged in v6.


### CB-08 [readability, test-coverage] The CI smoke step checks the `--devices` status 10 lines late and never runs `--accessories` or `--input` (P3, WP-8)

- **Where:** `.github/workflows/ci.yml:40-68`.
  - `--devices` sets `status` at `:58`. `:61` and `:66` don't change `status`, and the check runs on
    the last line (`:68`). One more command that sets `status` in between would silently stop
    checking `--devices`.
  - §2.6 lists `--accessories` smoke runs on macOS, but the step has none. `MacAccessoryProviderTests`
    covers the provider, not the CLI path through `readAccessories` and `renderAccessories`
    (`main.swift:208-234`).
  - Linux runs `--input` only in debug, through tests. On Darwin, the release `bpulse` never renders
    a fixture, although Darwin's Foundation bridges plist numbers differently from Linux (see the
    CLAUDE.md quirk).
- **Change:** in the same `run:` block, with `set +e` still on:
  - `:59`: `[ "$status" -eq 0 ] || [ "$status" -eq 2 ] || exit 1` right after the echo. Then delete
    `:68`.
  - Add the accessory runs:

    ```bash
    .build/release/bpulse --accessories; s=$?; [ $s -eq 0 ] || [ $s -eq 2 ] || exit 1
    .build/release/bpulse --accessories --json > acc.json || exit 1
    ```

  - Add a fixture loop:

    ```bash
    for f in Tests/BatteryCoreTests/Fixtures/*.plist; do
      for form in "" --json --raw; do .build/release/bpulse --input "$f" $form > /dev/null || exit 1; done
    done
    ```

    On Linux, all 27 runs (9 fixtures × 3 forms) exit with 0, including the device and accessory
    fixtures.
  - Move `BUILD_NUMBER=${{ github.run_number }}` (`ci.yml:75`, `release.yml:168`) into `env:`. This
    adds the last two `${{ }}` in `run:` to SEC-06's list (SEC-R8). They aren't injectable, but the
    rule has no exceptions.
- **Measure:** the step stays green on the runner. The log shows the accessory status (2 for text
  and 0 for `--json` on a VM with no accessories), and 27 fixture renders (9 fixtures × 3 forms)
  that exit with 0. The step's runtime grows by under 2 s.
- **Risk:** none. The commands only read.

### CB-09 [readability] Small fixes in the build files: unlinted scripts, three stale comments, an unpinned style list (P3, WP-8)

Each item is a one-line change.
- **`scripts/*.swift` aren't linted.**
  - `ci.yml:21` and CLAUDE.md lint only `Sources Tests Package.swift`.
  - `swift format lint --strict -r scripts` passes today (exit 0, no findings).
  - Change: add `scripts` to the CI lint line and to the CLAUDE.md commands, so the two Swift scripts
    keep to the same rules.
- **`Package.swift:13`** says "Command-line battery report for macOS". In fact `--input` and
  `--export` work on Linux (CLAUDE.md, `bpulse` section).
  - Change it to "Command-line battery report (`swift run bpulse`); live reads need macOS,
    `--input` and `--export` work anywhere".
  - `Package.swift` belongs to WP-1, so take it with SW-01.
- **`scripts/build-app.sh:7-8`** says each downloaded version must be approved once in Privacy &
  Security. That is true only for a DMG opened from a browser. `:57-58` of the same script, and the
  updater, rely on an in-app update not being quarantined.
  - Change: "…each version downloaded with a browser must be approved once…; an update installed
    from inside the app needs no approval".
- **`.github/pull_request_template.md`** lists only `swift test`, but CI fails on any lint warning.
  - Change: add `- [ ] swift format lint --strict -r Sources Tests Package.swift passes`.
- **`scripts/menu-bar-shots.sh:28`** hard-codes `STYLES=(symbol modern classic percentageInside
  ring)`. That matches `MenuBarIconStyle` (`Sources/BatteryCore/MenuBarContent.swift:118-128`)
  today, but nothing checks it, and 0.6.0 reworked the styles.
  - Change: add a `@Test` in `Tests/BatteryCoreTests/MenuBarTests.swift`. It reads the script
    (`#filePath`, three levels up), extracts the `STYLES=(…)` line and expects it to equal
    `MenuBarIconStyle.allCases.map(\.rawValue)`.
- **Measure:** CI lint passes with `scripts` added. The new test passes on Linux. For the comments
  and the template, review is enough.
- **Risk:** none.

## Repo-wide dead code and duplicated helpers: result

- **Method.**
  - A name-reference scan over `Sources` and `Tests` (`v061/cli-build/deadscan2.py`, output
    `deadscan.tsv`): every declared `func`/`var`/`let`/`case`/type with no reference in `Sources`
    outside its declaration.
  - A same-name scan of functions and types across targets and `scripts` (`dupscan.py`).
  - Both were then checked by hand against the sibling audits' lists.
- **Dead or test-only symbols.** Everything the scan found is either a false positive or already
  listed:
  - False positives: the `NSApplicationDelegate`, `TimelineProvider` and `Transferable`
    requirements, `@main` types, and the Linux stubs.
  - Already listed:
    - CORE-06: `allowsTertiaryText`, `dividesGroupsWithHairlines`, `wearPercent`, `isDrawn`,
      `hasHue`, `RawKeyGlossary.keys`, `samples(since:)`;
    - K-08: the eleven unused `SMCResult` cases, which are a mapping of SMC result codes and stay
      as documentation, per DC-4's spirit;
    - the K audit's test-only hook `IDeviceMonitor.waitUntilIdle` (DC-3).
  - One more test-only symbol: `RawKeyGlossary.summaries` (`RawKeyGlossary.swift:75`). Only
    `LocalizationCatalogTests.swift:58` uses it, and on purpose: it feeds the catalog check. Keep
    it, and add a `// Used by LocalizationCatalogTests` comment (DC-3).
- **Dead code in `bpulse`:** the three `.smc` branches and the `default: nil` (CB-03). No unused
  functions.
- **Duplicated helpers across targets:**
  - new here: the capture plist encode and decode (CB-05) and three JSON encoder setups (CB-02);
  - already owned: the hex encoders (CORE-01, including `bpulse --smc`), the notify and IOPS
    plumbing (K-04), the unversioned-build constant (AC-05), the user agent (AC, considered), and
    Copy JSON's encoder (AV-02).
  - `fail(_:)` appears three times (`bpulse`, `sign-update.swift`, `display-metrics.swift`).
    Standalone scripts can't import the package, so this stays.
- **Resources.**
  - `AppIcon.svg` is the source of `AppIcon.png`, and nothing ships it.
  - `AppIcon.png` becomes the `.icns` (SZ-10 owns that).
  - The widget entitlements hold only the sandbox key, as CLAUDE.md requires.
  - The catalog has 713 entries, all `manual`, all with a translated `ru`. Four `ru` values equal
    their key (`BatteryPulse`, `Mac`, `PPS %@ × %@`, `USB Power Delivery`), and that is correct. 368
    entries carry comments. No unused key: `LocalizationCatalogTests` enforces this. The catalog
    itself isn't shipped (only the compiled tables, see SZ-07).

## Considered, no change

- **Duplicate CI runs for a PR from a `claude/**` branch** (`ci.yml:4-11`: a push run plus a
  `pull_request` run, with different `github.ref` concurrency groups). The repository is public, so
  the minutes cost nothing. The PR run also tests the merge commit. A shared group would let one run
  cancel the other, and the PR could show a cancelled check. Leave it as it is.
- **Compiling `sign-update.swift` once instead of running it through the interpreter 5 times in CI
  and 3 times in the release.** The whole signing smoke step takes 5 s (`ci-macos.log`), so the gain
  is too small.
- **Hoisting the `JSONEncoder` out of the `--watch` loop** (`main.swift:161`). It is one allocation
  every 2 s or more, in a tool. CB-02's helper keeps creating it per call, and that's fine.
- **`Task.sleep` without tolerance in `--watch` (`main.swift:415`) and `--record` (`Record.swift:62`).**
  EN-1 allowlists the `bpulse` loops, and `--record`'s timeline wants a regular 5 s.
- **The top-level `try` in `main.swift`.** A thrown error would trap rather than exit with 1. The
  only throwing calls are the JSON and plist encoders and `Task.sleep`. Every `Double` that reaches
  them is range-checked (`MacPowerParser.swift:155-158, 279-288`, `IDeviceBattery.swift:190-225`),
  and no NaN path was found, so there is no reachable trap.
- **`URL(fileURLWithPath:)`, `appendingPathComponent` and `NSString.expandingTildeInPath`**
  (`Record.swift:20-21, 42`, `main.swift:276, 369`). These are soft-deprecated spellings with no
  warning on macOS 27. The app-core audit's rule applies: change them only together with the app's
  own sites.
- **An extra blank line after `--raw`** (`main.swift:411` uses `print(output)` after a plist that
  already ends in a newline, while the device and accessory captures use `terminator: ""`). Fixing it
  would change frozen stdout bytes, and `--input` reads either form.
- **`--record` writes captures with the default umask** (0644 files, 0755 folder). The captures
  carry no serials (`redactedRawCapture`), and the user picks the folder.
- **A filtered string table for the widget** (it uses about 15 of the 713 keys): SZ-07 explicitly
  leaves per-key filtering for later, and ULMO shrinks the DMG gain to a few KB.
