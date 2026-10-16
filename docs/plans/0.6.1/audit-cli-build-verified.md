# Audit "cli-build": verified

Source: `audit-cli-build.md` (CB-01 to CB-09), checked against `6133b4f` (release 0.6.0) with
`git show 6133b4f:<path>`. HEAD is `a32bfae`. `git diff 6133b4f a32bfae` doesn't touch `Sources/bpulse`,
`HistoryStore.swift`, `Package.swift`, `scripts/` or `.github/`, so the code is the same as 0.6.0.
I didn't modify the repository. Scratch work is in `v061/cbverify/`: a `git archive` copy of
`scripts/` plus `.swift-format`, used for the lint run.

The runs below used the existing Linux debug build `v061/core-build/debug/bpulse` (Swift 6.4.1).

## Verdicts

| ID | Verdict | Package | Priority | One line |
|---|---|---|---|---|
| CB-06 | keep-modified | WP-8 (guard); the 0.6.1 notes themselves are a release-gate item | P1 | Confirmed. Fix the line numbers and run the check before `swift test`. The 0.6.1 notes must be written whatever happens to the guard |
| CB-07 | keep | WP-8, folded into SEC-06 | P2 | Confirmed from the CI log and each tag's `action.yml`. `b7c566a` is the `v6`/`v6.0.0` tag |
| CB-04 | keep-modified | WP-1 (last commit: the target plus the parser table) | P2 | Keep the parser table. Drop the render split, which moves code only for tests that the golden script and CB-08 already cover |
| CB-02 | keep-modified | WP-12 (a ROADMAP 0.7 entry); no code in 0.6.1 | P3 for 0.6.1 | The bug is real, but §3.4 freezes `--device --json` stdout. Defer the ISO 8601 switch to 0.7. No helper and no FIXME |
| CB-08 | keep | WP-8 (`BUILD_NUMBER` goes in with SEC-06) | P3 | Confirmed. I ran all 27 fixture forms: each exits with 0. Correct the release.yml line (it's `:70`, not `:168`) |
| CB-09 | keep-modified | WP-1 (Package.swift comment), WP-8 (CI lint, build-app.sh comment, PR template), WP-12 (CLAUDE.md) | P3 | Drop the `STYLES` test. Add `scripts` to the lint line only after WP-1's SW-20 rules are on |
| CB-05 | keep-modified | WP-5, with AV-01 | P3 | Only the encoder, in a new BatteryCore file (not WP-7's `PropertyValue.swift`). No decoder helper and no test rewrites |
| CB-01 | reject | — | — | No released version ever wrote `samples.jsonl`. The collision and the race need a file that no user can have |
| CB-03 | reject | — | — | A net-zero-line refactor on the surface that §3.4 freezes (exit codes), with no measurable effect. One of its claims is wrong |

## Per item

### CB-06: release notes not tied to the version (keep-modified, WP-8, P1)

**Confirmed:**
- `release.yml` publishes with `--notes-file .github/release-notes.md --generate-notes` (`:83-86`).
- `Updates.swift:130` shows `release.body` as the update notes. So the Software Update window of
  0.6.0 → 0.6.1 would show the 0.6 text.
- The headings at the commits that changed the file: `6133b4f` "What's new in 0.6", `8af137d` 0.5,
  `15c4bd2` 0.4, `6f6eee6` 0.3.1, `1a19084` 0.3.
- So the convention is one heading per release, including patch releases (0.3.1).
- The file is unchanged at `a32bfae`.

**Corrections:**
- The audit's `release.yml:151-166, 182-184` don't exist: the file has 86 lines at `6133b4f` and at
  HEAD. The real lines are "Resolve version" `:53-68` and "Publish release" `:83-86`.
- "Fails early, before signing" is true, but the check sits after `swift test` (`:51-52`), which
  takes minutes.

**Change, modified:**
1. Run the heading check in its own step right after checkout, before "Check the update signing
   key" and "Test". Alternatively, move "Resolve version" there; it needs only `gh` and the ref.
2. Keep the audit's rule: `"## What's new in $version"` or `"## What's new in ${version%.0}"`.
   - `${version%.0}` turns 0.6.0 into 0.6, leaves 0.6.10 alone and turns 1.0.0 into 1.0, so all
     three are right.
   - Print the expected heading in the `::error::` line.
3. **Release gate, whatever happens to the guard:** `.github/release-notes.md` for 0.6.1 opens with
   `## What's new in 0.6.1`. It lists the user-visible changes since 0.6.0:
   - the tile picker's selection now sits behind the tile (`ec61436`);
   - Clear's dimming (`6584585`);
   - the widget refresh (`994c09d`);
   - earbud naming (`a32bfae`);
   - SEC-01's integrity-failure behaviour, if it lands.

   This answers the user's "launch 0.6.1" directly.

**Ownership:** WP-6 owns only the key-check hunk, so the new step doesn't conflict with it.

### CB-07: `upload-artifact@v4` on Node 20 (keep, WP-8 with SEC-06, P2)

**Confirmed:**
- `ci.yml:94` uses `actions/upload-artifact@v4`.
- `cli-build/ci-macos.log:2026` has `##[warning]Node.js 20 is deprecated … actions/upload-artifact@v4`.
- Each clone's `action.yml`:
  - v4 `ea165f8`: `node20`;
  - v5 `330a01c`: `node20`;
  - v6 `b7c566a`: `node24`, with tags `v6` and `v6.0.0`, dated 2025-12-12;
  - v7 `cf430e0`: `node24`, with tag `v7.0.2`.
- v6's README requires runner 2.327.1 or later. The log shows 2.337.0.
- `actions/checkout@v5` causes no warning.
- SEC-06's pin list (`security/verified.md:352-353`) says `upload-artifact@<sha> # v4`, so correct
  it to `@b7c566a772e6b6bfb58ed0dc250532a479d7789f # v6.0.0`.
- v7.0.2 would also do. Whichever is chosen, the comment names the exact tag.

**Why it matters:** the release gate asks for "both CI jobs green with 0 warnings", and this is
today's only annotation warning.

### CB-04: `bpulse` tests (keep-modified, WP-1, P2)

**Confirmed:**
- There is no test target for bpulse (`Package.swift:35-40`).
- `parseOptions` (`main.swift:86-154`) holds the exit-1 half of the frozen contract.
- The `exetest` package shows `@testable import` of an executable with top-level `await` on Linux,
  Swift 6.4.1. SwiftPM renames the executable's `main` for tests on both platforms.

**Change, modified:**
1. Add `.testTarget(name: "bpulseTests", dependencies: ["bpulse"])` as WP-1's last commit. WP-1 owns
   `Package.swift`, and this way the table guards every later package, WP-1's own SW-13 `unsafe`
   marker in bpulse included.
2. Write a `@Test(arguments:)` table of argument vectors and the expected `Options?`/`exportKind`,
   including every rejection the audit lists.
3. Add `: Equatable` to `Options` in `main.swift`. A synthesized conformance can't be declared in
   an extension in the test file. `OutputFormat` is already `Equatable`.
4. **Drop** the `renderDevice`/`renderAccessories` split. It moves code only so tests can reach it,
   and the output forms are already covered: the §2.6 golden script runs every fixture in the text,
   `--json` and `--raw` forms, CB-08 adds them to CI, and the iPhone fixture exercises
   `renderDevice` through `--input`. The functions end in `exit()`, so they stay untested.

**Constraint:** the tests read no top-level global of `main.swift` (`usage`, `arguments`,
`options`). Those are initialized only by top-level code, which never runs under tests.
`parseOptions` reads none of them.

### CB-02: device JSON `firstUseDate` (keep-modified, WP-12, no code in 0.6.1)

**Confirmed:**
- I ran `--input iphone17promax-ios27.0.1-usb.plist --json`. It prints `"firstUseDate" : 781056000`,
  while the Mac fixtures print `"gaugeUpdatedAt" : "2026-…Z"`.
- The encoders at `main.swift:194-196` and `:214-216` set no date strategy. `:161-163` sets
  `.iso8601`.
- `IDeviceBattery.firstUseDate: Date?` (`IDeviceBattery.swift:32`).
- USER_GUIDE `:600` says only "`--json` prints the same as JSON"; it doesn't document the field.

**Why not in 0.6.1:**
- Option (a) changes `bpulse --device --json` stdout. §3.4 lists it as byte-identical, and the
  golden-diff gate must stay empty.
- Option (b), a FIXME plus an explicit `deferredToDate`, is noise. So is a shared helper with a
  per-site exception: three 3-line encoder setups aren't worth it.

**Change:**
- WP-12 adds a ROADMAP 0.7 entry: device JSON dates become ISO 8601, with a release-notes line.
  The `jsonText` helper comes then, when it doesn't need an exception.
- If the maintainer explicitly wants it in 0.6.1, it becomes a recorded §3.4 exception and a line
  in the 0.6.1 notes. The golden diff then expects exactly that one line: `"2025-10-02T00:00:00Z"`.

### CB-08: CI smoke step (keep, WP-8, P3)

**Confirmed:**
- `status` is set by `--devices` at `ci.yml:57-58`. Neither `:61` nor the `if` block at `:65-67`
  reassigns it, and `:68` checks it. That's correct but hard to follow.
- No `--accessories` or `--input` run on Darwin.
- `BUILD_NUMBER=${{ github.run_number }}` sits inside `run:` at `ci.yml:75` and `release.yml:70`. The
  audit's `release.yml:168` doesn't exist.
- SEC-06's "already good: never `${{ }}` inside `run:`" (`security/verified.md:347-348`) is wrong
  about these two lines. The value is numeric, so this is hygiene under SEC-R8, not a vulnerability.
- I re-ran all 9 fixtures × {"", `--json`, `--raw`} with `TZ=UTC`: all 27 exit with 0.

**Note:**
- `--accessories --json` exits with 2 only when `dlsym` doesn't find `IOPSCopyPowerSourcesByType`
  (`MacAccessoryProvider.swift:41`).
- Requiring 0 therefore doubles as a canary: it fails if the private symbol disappears from the
  runner's macOS, which is worth knowing. Keep it, and say so in a comment.

**Ownership:** the `BUILD_NUMBER` move belongs in the same commit as SEC-06.

### CB-09: small build-file fixes (keep-modified, P3)

**Confirmed:**
- `swift format lint --strict -r scripts` on a `6133b4f` copy exits with 0 (`v061/cbverify/s`).
- Stale comments:
  - `Package.swift:13` says "Command-line battery report for macOS", but `--input` and `--export`
    run on Linux;
  - `build-app.sh:7-8` says each downloaded version must be approved, but in-app updates aren't
    quarantined (§3.4: no `LSFileQuarantineEnabled`).
- The PR template has no lint item.

**Changes and owners:**
- WP-1: the `Package.swift` comment.
- WP-8:
  - add `scripts` to `ci.yml:21`, after WP-1's SW-20 rules are on, so they apply to the scripts
    too, and fix any hits there in the same commit (WP-0's new `rusage.swift` included);
  - the `build-app.sh` comment, worded as "each version downloaded with a browser"; in-app updates
    need no approval;
  - the PR-template checkbox.
- WP-12: add `scripts` to the CLAUDE.md Commands lint line. Phase C owns CLAUDE.md apart from the
  glass list.

**Dropped:** the `@Test` that parses `STYLES=(...)` out of `menu-bar-shots.sh`.
- It is a regex over bash syntax, testing a manual screenshot script that runs only on the
  maintainer's Mac.
- That script shoots every listed style, so a missing one shows on its first run.
- `bash -n` already checks the script in CI.
- Today the list matches `MenuBarIconStyle.allCases` exactly: symbol, modern, classic,
  percentageInside, ring.

### CB-05: capture-format encoding (keep-modified, WP-5 with AV-01, P3)

**Confirmed:** the capture format is defined twice in the products:
- `main.swift:172-179` (`xmlPropertyList`), used by `render`, `renderDevice`, `renderAccessories`
  and `Record.swift:44`;
- `DeveloperView.swift:278-279` (Export Capture).

Its value is structural: Export Capture and `bpulse --raw` produce the fixture format by
construction.

**Change, modified:**
1. Add only `PropertyValue.xmlPropertyListData(_ dictionary: PropertyDictionary) throws -> Data`, in
   a new `BatteryCore/CaptureFormat.swift`. Putting it in `PropertyValue.swift` would touch WP-7's
   file.
2. AV-01's `FileDocument` and bpulse's `xmlPropertyList` call it. `Record.swift` writes the `Data`
   directly.
   - The UTF-8 XML round-trips through `String` unchanged, so the files are byte-identical.
   - The saving is negligible (at most 100 captures per recording), so it's about readability only.
3. Add one round-trip test of the new function.

**Dropped:**
- The decoder helper: `loadCapture` is the only product decode site, and the tests already share
  `Fixture.swift` and `AccessoryFixture.swift`.
- The rewrite of the five test sites: they check against Foundation directly, which is a more
  independent check than calling the helper they would then be testing.

### CB-01: export migrates the legacy file (reject)

The mechanism is right. `samples(from:to:)` and `latestSampleTime()` call
`migrateLegacySamples()` (`HistoryStore.swift:78, 108`). That function overwrites day files and
removes the legacy file (`:135-143`).

**Why the scenario can't happen:**
- `v0.2.0` has no `HistoryStore` at all.
- `v0.3.0` (`1a19084`, the only commit between the two tags) is the first release with history,
  and it already writes `samples/<day>.jsonl` and ships the migration.
- `git log --all -S'"samples.jsonl"'` finds only `1a19084`: no commit in the repository ever wrote
  the single file.
- So the legacy file exists only in pre-0.3 development folders, which the first `record` of any
  release migrated, before any day file existed.

What the audit's impacts need, and why none of them occurs:
- The data loss needs a legacy file next to a day file of the same UTC day.
- The app/bpulse race needs a legacy file at all.
- The downgrade route is impossible: no release writes the legacy file.
- On every real folder the export only reads: the migration returns at `:136`.

**Cost:** a new `init` parameter and an in-memory merge path, in a release whose goal is less code,
for a state no user can reach.

**Leave as is:**
- DC-5 stands; deleting the migration is not a 0.6.1 change.
- For a later decision, the maintainer may note that DC-5's premise ("upgrades from old versions")
  doesn't hold for `samples.jsonl`.

### CB-03: `--smc` as an output format (reject)

**What the audit gets right:**
- The `.smc` branches at `main.swift:167-168, 187, 210` are unreachable:
  - devices and accessories reject `.smc` (`:144, :150`);
  - `--input` and `--watch` with `.smc` exit at `:360`;
  - the render loop is never reached with `.smc`.
- Its last-wins analysis is right too: `--smc --json` prints JSON, and `--json --smc` lists keys.

**Corrections:**
- "`exportFormat` … its `default: nil` can't run" is wrong. `exportFormat` is a `String?`, so
  `default` is the `nil` case.
- It runs on every invocation without `--export`, through `options.exportKind` at `:350`. An enum
  would still need `case nil`.

**Why reject:**
- The change adds a flag and touches 6 guards.
- It moves `:360` into the parser and adds an enum. It deletes about as many lines as it adds.
- Nothing measurable changes.
- Every edited line is on the exit-code surface that §3.4 freezes: the combinations with
  `--record`, `--export`, `--devices` and `--accessories` all go through the new flag. That is risk
  without benefit.
- DC-1 doesn't cover it either: link maps can't show unreachable enum cases.
- CB-04's parser table already pins today's behaviour, so the next real change to the parser can
  restructure it with a safety net.
