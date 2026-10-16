# BatteryPulse 0.6.1 playbook: optimization and foundation release

Date: 2026-10-15. Base: `main` = `6133b4f` (release 0.6.0). Read-only planning output; nothing in the
repository was changed.

Inputs (each item there has a source, files, measurement, risk and priority; this playbook cites
their IDs and does not repeat their evidence):

| Prefix | File | Scope |
|---|---|---|
| `SUI-` | `v061/swiftui/verified.md` | SwiftUI, Observation, Charts, Table, profiling |
| `SW-`, `V-` | `v061/swift/verified.md` | Swift 6.4 language, concurrency, logging, tests, format, dead code |
| `E`, `M1`, `C`, `F` | `v061/energy/verified.md` | energy and runtime efficiency, M5 protocol |
| `SEC-` | `v061/security/verified.md` | update channel, signing posture, privacy, MobileDevice |
| `SZ-` | `v061/size/verified.md` | binary and DMG size, build settings, CI size gate |

All paths `v061/...` are under
`/tmp/claude-0/-home-user-BatteryPulse/11e28672-c0db-5a09-a8bc-b94b73c785d3/scratchpad/v061/`.

## At a glance

1. **Phase A, sequential.**
   - WP-0: signposts, `rusage`, the profiling build, the CI size report, the warning gate and the
     Linux benches.
   - Cherry-pick WP-0 onto `perf/baseline-0.6.0` and record the **before** numbers (§2).
   - WP-1: manifest 6.4, upcoming features, strict memory safety for BatteryCore, swift-format rules.
2. **Phase B, parallel worktrees.** Each package owns its files (§3.2):
   - WP-2: read path and energy;
   - WP-3: History;
   - WP-4: observers;
   - WP-5: Raw Data and formatting;
   - WP-6: updates and security;
   - WP-7: devices;
   - WP-8: build, size and CI;
   - WP-9: view structure.
3. **Phase C, sequential.**
   - WP-10: main-actor default for the app, then the M5 runtime checklist.
   - WP-11: dead-code maps, then deletions.
   - WP-12: guard tests and docs.
   - Then the **after** numbers, the golden-output diff and the M5 checklists (§2.6, §2.7).
4. **Never changed:** behaviour, settings keys, storage formats, `bpulse` stdout and exit codes, the
   update contract (§3.4). **Never resurrected:** the rejected items (§3.3).

## 0. What changed since the research (0.5.0+fixes → 0.6.0), checked at `6133b4f`

The research read `fb41ff5`. 0.6.0 added devices, accessories, window styles, history export and
`bpulse --record`. Re-checked by grep, two Linux builds and one swift-format run (Swift 6.4.1, `--scratch-path` in the
scratchpad, repository untouched):

- **Still true, unchanged:** no signposts and one `Logger` (`Updates/UpdateInstaller.swift:333`);
  `URLSession.shared` in `UpdateChecker.swift:161` and `UpdateInstaller.swift:184, 209`; 4
  `Task.detached` (`UpdateInstaller.swift:128, 149, 159`, `DeveloperView.swift:128`); both
  `com.apple.system.powersources` keys subscribed (`MacBatteryProvider.swift:65-66`);
  tolerance-less sleeps in `HistoryView.swift:153`, `UpdateChecker.swift:70, 73`,
  `UpdateInstaller.swift:203`, `DemoController.swift:212`, `BatteryMonitor.swift:109`;
  `build-app.sh` still copies unstripped binaries, exports everything, builds UDZO, has no size
  report; `ci.yml` has no `permissions:` block and no warning gate; tools-version 6.0 with string
  platforms; `release.yml` checks a single `publicKey`.
- **Grew in 0.6.0:**
  - `withObservationTracking` re-arm loops: **4** (HistoryRecorder:54, BatteryNotifier:79 and :107,
    WidgetRefresher:25), not 3.
  - `@unchecked Sendable`: **9**, not 7. New: `USBDeviceWatcher` and its private `Watch`
    (`MobileDevice/USBDeviceWatcher.swift:13, 70`). They have to be judged with the SW-06 test.
  - `dlopen`/`dlsym` also in `MacAccessoryProvider.swift:35-36` (the private
    `IOPSCopyPowerSourcesByType`). SEC-07's location list must include it.
  - `@MainActor`: app 38, BatteryKit 26, widget 3, bpulse 3. `try?`: 67 in `Sources`.
  - MobileDevice now runs **in the app process** (`IDeviceMonitor`), so SEC-10's condition is met.
  - Tests: 539 `@Test` functions (was 330).
- **Already done in 0.6.0 (no work):** `AccessoryMonitor.scheduleRead()` already coalesces a burst of
  notifications into one read with a tolerance. E3 should copy this pattern for `BatteryMonitor`.
  `IDeviceMonitor` sleeps with a 10 % tolerance. `HistoryView` reloads only while visible.
- **Obsolete:** SUI-14 and SUI-16. The "Glass Cards" option and `CardSurfaceSetting` were removed in
  0.6.0. Cards now read `\.windowLook`, `\.tones` and `\.contentTreatment` from the environment.
  The replacement measurement is the energy and hitch cost of the four window styles (§2.4, S4w).
- **Re-measured at `6133b4f`:**
  - All five proposed upcoming features (`ExistentialAny`, `MemberImportVisibility`,
    `InferIsolatedConformances`, `NonisolatedNonsendingByDefault`, `ImmutableWeakCaptures`):
    `swift build --build-tests` has **0 diagnostics** on the Linux-compiled code.
  - `-strict-memory-safety` on BatteryCore: **0 warnings**.
  - swift-format with the project config: clean. The SW-20 opt-in rules:
    - `ValidateDocumentationComments`: 10;
    - `UseWhereClausesInForLoops`: 1;
    - `NoEmptyLinesOpeningClosingBraces`: 0 (was 2);
    - the other six: 0;
    - `AllPublicDeclarationsHaveDocumentation`: 510 (was 356);
    - `BeginDocumentationCommentWithOneLineSummary`: 280 (was 164).
  - Darwin-only code still needs the macOS CI job for both.

---

## 1. Rules

Each rule is a short statement that can be checked. **Check** says how: a grep, a test, a CI step
or an Instruments track. Sources are research IDs; the Apple and Swift sources are in those files.
Rules marked *(existing)* are already true and must stay true. CLAUDE.md stays binding and wins over
anything here.

### 1.1 SwiftUI

| ID | Rule | Check | Source |
|---|---|---|---|
| UI-1 | No formatter construction, `String(localized:)`, `Bundle` lookup or string interpolation per element in `body`, in a chart `ForEach` or in a table cell. Build display strings once per reading, and constants once per body. | Time Profiler: no `localizedString` or `formatted` under view bodies in scenarios (c) and (d) | SUI-02, SUI-03, SUI-06; W23-10160, W25-306 |
| UI-2 | Decoding, bucketing, statistics and section building never run on the main actor. Build one `Sendable, Equatable` value in a `@concurrent` function, then assign it in one step. Only the assignment is animated. | Swift executors track: no `load`/`rebuild` frames on the Main Actor except the assignment | SUI-04, SUI-02, SW-05; W26-268, D-PERF |
| UI-3 | A `.task` runs synchronously up to its first `await` (`Task.immediate` on the 2027 SDK). Nothing heavy goes before it. | Review rule; Swift executors | SUI-22; D-TASK |
| UI-4 | Live values (`snapshot`, `reading`) are read only in the view that shows them. `MainView.body` never reads `monitor.snapshot`. Never move a derived Bool up to a parent (`CopyReportButton` keeps its own read). | grep `monitor.snapshot` in `MainView.body`; SwiftUI instrument, Show Causes | SUI-07 (incl. rejected part) |
| UI-5 | A subview that shows slowly changing data takes `Equatable` value inputs. Stored closures are allowed only as action or parameter closures. `BatteryFormatter` is `Equatable` and has no closure. | Review; Summary: All Updates per tick | SUI-06, SUI-07, SUI-13; D-PERF |
| UI-6 | The environment carries only rarely changing `Equatable` values. Never `snapshot`, `reading`, dates, timers or geometry. | Review; one CLAUDE.md line | SUI-21; W25-306 |
| UI-7 | In lists and lazy stacks: one subview per `ForEach` element, filtering in the data (never `if` inside a row), setup in `init` (not `onAppear`), stable IDs, no `AnyView`, no absolute offsets. Applies to Devices, Accessories and the popover lists. | Review checklist; SwiftUI instrument while scrolling a long Demo Mode list | SUI-15; W26-321, W23-10160 |
| UI-8 | Every long-lived `.task` and `Task` has a name. | grep `.task(id:` / `Task {` without `name:` in the app and BatteryKit | SUI-10, SW-08; D-TASK |
| UI-9 | `@State` is initialized at its declaration or in `init`, never both. | Xcode 27 build has no diagnostics | SUI-09; W26-269 |
| UI-10 | Raw Data search stays case-insensitive and diacritic-sensitive: one `localizedCaseInsensitiveContains` over the joined row text. Never `.diacriticInsensitive` (it would make Russian и/й and е/ё match). | Unit test with и/й and е/ё | SUI-02 |
| UI-11 | Previews compile only under `#if DEBUG` and never change the release binary. | SZ-04 size row unchanged | SUI-17 |
| UI-12 | No lifecycle logic on `appearsActive`. Keep the `didBecomeActive` `onReceive`. | Review | SUI-20 (rejected) |
| UI-13 | *(existing)* Glass only on the control layer, never on content and never glass on glass. Motion only through `\.motion`. Nothing animates in the menu bar label or in a hidden window. Colours in `Main/` go through the tone map. | `MotionGuardTests` | CLAUDE.md |
| UI-14 | `let _ = Self._printChanges()` is for local debugging only and never committed. | grep `_printChanges` = 0 | SUI-01; W23-10160 |

### 1.2 Swift, concurrency and readability

| ID | Rule | Check | Source |
|---|---|---|---|
| SW-R1 | Language policy lives only in `Package.swift`, in shared `let` arrays: `swift-tools-version: 6.4`, `.macOS(.v27)` and `.iOS(.v27)`. No `-Xswiftc` in the manifest. The only `unsafeFlags` are the widget's two, each with its comment. | `swift package dump-package`; review | SW-01, SW-24 |
| SW-R2 | 0 compiler warnings on Linux and macOS. CI builds with `-warnings-as-errors -Wwarning DeprecatedDeclaration`; release builds don't. A kept deprecated API gets `@diagnose(DeprecatedDeclaration, as: ignored, reason: …)` on that one declaration. | CI gate | SW-14 |
| SW-R3 | The upcoming features `ExistentialAny`, `MemberImportVisibility`, `InferIsolatedConformances`, `NonisolatedNonsendingByDefault` and `ImmutableWeakCaptures` are on for every target. `NoUseUnstructuredThrowingTask`, `ImplicitStrongCapture` and `ErrorInFutureSwiftVersion` are errors. | dump-package | SW-02, SW-03, SW-14 |
| SW-R4 | Offload work by calling a `@concurrent` function, not `Task.detached { … }.value`. The only `Task.detached` left is the named, fire-and-forget leftover cleanup. | grep `Task.detached` = 1 | SW-05 |
| SW-R5 | A nonisolated `async` function that does synchronous heavy work before its first suspension is `@concurrent` (`UpdateInstallSteps.verify`, `.replace`). Continuation wrappers aren't. `swift package migrate` output is a report, never the commit. | Swift executors during an install; review | SW-03, V-02 |
| SW-R6 | Shared mutable state lives in `Mutex<State>` inside a checked-`Sendable` final class. An `@unchecked Sendable` stays only where `Mutex` doesn't compile or the type is immutable, and it carries a comment saying which. | grep count of `@unchecked Sendable` (9 → target 5 or fewer: `MobileDeviceSink`, `MobileDeviceLibrary`, `AppearanceVariants`, plus the two `USBDeviceWatcher` types unless they convert) | SW-06 |
| SW-R7 | Non-view code observes `@Observable` state with one named `Task` over `Observations { … }.dropFirst()`, cancelled in `stop()`/`deinit`. Never a re-armed `withObservationTracking`. `.dropFirst()` is mandatory, so launch doesn't add a notification, a widget reload or a history sample. | grep `withObservationTracking` = 0; on the M5, no extra sample in `samples/<today>.jsonl` at launch | SW-09, SUI-08, E22 |
| SW-R8 | No `Task { @MainActor in … }` inside code that is already main-actor isolated. | grep | V-03 |
| SW-R9 | The app target defaults to main-actor isolation. Callbacks that frameworks invoke off-main (`URLSessionTaskDelegate`, `Process.terminationHandler`, AppKit drawing handlers, `UNUserNotificationCenterDelegate`) are explicitly `nonisolated`. BatteryCore, BatteryKit, bpulse and **the widget** stay nonisolated by default. | grep `@MainActor` in the app (38 → near 0); V-01 checklist on the M5 | SW-04, V-01 |
| SW-R10 | One `Logger(subsystem: "io.github.nikitausov.BatteryPulse", category:)` per area: `monitor`, `smc`, `iokit`, `history`, `device`, `accessory`, `update`, `widget`. `privacy: .public` only for static text, numbers, enum case names, versions and status codes. Error descriptions, paths, device names, serials and UDIDs stay private, or use `.private(mask: .hash)`. | `log stream --level debug --predicate 'subsystem == "io.github.nikitausov.BatteryPulse"'` shows `<private>` or hashes | SW-12, SEC-12 |
| SW-R11 | No `import os` in BatteryCore. In BatteryKit, only behind `#if canImport(os)`, because BatteryKit builds on Linux. | Linux CI build | SW-12, SUI-01, E1; CLAUDE.md |
| SW-R12 | `try?` only where failure is normal (`Task.sleep`, removing a file that may be missing). Unexpected failures at I/O and OS boundaries are logged. | grep `try?` (67): each remaining one is justified | SW-12 |
| SW-R13 | BatteryCore builds with `.strictMemorySafety()` and 0 warnings. Unsafe code exists only in BatteryKit's IOKit, SMC and MobileDevice files and in the app's `proc_*`/`kill` site. | dump-package; macOS job | SW-13, SEC-13 |
| SW-R14 | Untyped `throws` by default. Typed throws only where the error set is closed and already mapped by hand (`SMCClient`, optionally `UpdateInstallSteps`). | Review | SW-11; SE-0413 |
| SW-R15 | Tests use swift-testing only: `#require` instead of silent `guard … else { return }`, `@Test(arguments:)` over fixtures, `confirmation(expectedCount:)` for callbacks, `.timeLimit` on timer tests. Timing is never asserted; work counts are. | Review; C1 | SW-19, C1, F15 |
| SW-R16 | `swift format lint --strict` passes with the six zero-hit opt-in rules on, plus `NoEmptyLinesOpeningClosingBraces`, `UseWhereClausesInForLoops` and `ValidateDocumentationComments`. | CI lint step | SW-20 |
| SW-R17 | No access-control churn in 0.6.1: keep `public`, no `package` sweep, no `InternalImportsByDefault`. | Review | SW-16 (P2, not taken) |
| SW-R18 | No new dependency. Scripts use only Apple's and the Swift project's tools. | `Package.swift` has no `dependencies:` | CLAUDE.md |

### 1.3 Energy

| ID | Rule | Check | Source |
|---|---|---|---|
| EN-1 | Every periodic `Task.sleep(for:)` passes `tolerance:` of at least 10 % of the interval. One-shots are on an allowlist with a reason: the 1.5 s "Copied" label, the widget refresher's 1 s wait, `bpulse` loops. | `EnergyGuardTests` (C4) | E7; F2 |
| EN-2 | No `Timer`, `DispatchSourceTimer`, `asyncAfter` or Combine timer. The exception is the IDevice transport timeouts (`IDeviceTransport.swift`). | `EnergyGuardTests` | E21, C4 |
| EN-3 | An OS notification means "something changed": one read per burst. Coalesce within about 150 ms with a tolerance, the way `AccessoryMonitor.scheduleRead()` already does. | C1: N callbacks in one burst → 1 read; M5: reads per `pmset -g pslog` update ≈ 1 | E3; F13 |
| EN-4 | A poll reads only what it exists for. The live SMC keys `B0AV` and `B0AC` are read every poll. The other SMC keys are read at most every 60 s, or while Raw Data or Power is shown. | Signposts `smc.power` / `smc.other`; SMCTests | E4a |
| EN-5 | No forced read when a read is younger than about 20 s (the history tick) or about 1 s (a new live-refresh request at launch). Freshness is `lastReadAt`, never `snapshot.timestamp`. | C1 | E8, E17 |
| EN-6 | Display-only work stops when nobody can see it. Windows already stop on occlusion. The menu bar poll stops while the screens sleep or the session is inactive. History recording continues. | M5 S6 ≈ S1 | E5; F3 |
| EN-7 | Under Low Power Mode, `systemPrefersReducedResourceUsage` or a thermal state of serious or worse, only the **next** poll interval grows (windows 2 → 5 s, menu bar 10 → 30 s). Nothing extra runs on the flip. LPM and the thermal state come from `ProcessInfo`, never from the snapshot (Demo Mode simulates both). | `LiveRefreshPolicy` tests | E6; F6, F7 |
| EN-8 | No `beginActivity`, `IOPMAssertion` or `performExpiringActivity`. The one exception is a `.userInitiated` activity around an in-app install, ended by `defer`. | `EnergyGuardTests`; `pmset -g assertions` | E11, E21; F18 |
| EN-9 | Unchanged data is parsed once. Closed history day files are decoded once per session (cache key: day plus file size), today's file only from its last offset. Clear History, pruning, legacy migration and day rollover invalidate the cache. | `HistoryStore` tests on Linux; `history.load` signpost | E13, SUI-05R |
| EN-10 | History I/O: the policy check comes before any syscall, the legacy migration runs once per session, the actor keeps one encoder, and decoding reads the slice without a `Data` copy. Appends stay per-sample: no batching, no compression, no `fsync`. | M1 disk bytes/h; `fs_usage` | E14; F10 |
| EN-11 | Widget reloads go only through `WidgetReloadPolicy`. `reloadAllTimelines` appears only in `WidgetRefresher` after a version change. Each reload is logged in the `widget` category; target ≤ 25 a day. | `EnergyGuardTests`; `log show` count | E15; F5 |
| EN-12 | Nothing that the energy research rejected: no background `URLSession`, no `isDiscretionary`, no ETags, no private notify keys or IOKit messages where a public relay exists, no `NSBackgroundActivityScheduler` for the update check, no MetricKit in 0.6.1. | Review | E21, E9, E16, F12 |
| EN-13 | *(existing)* Event-driven reads through `notify(3)` with `notify_cancel`. No polling while no client asks. Windows pause polling and animation when occluded. | C1: 0 reads per simulated idle hour without clients | Energy §1 |

### 1.4 Security and privacy

| ID | Rule | Check | Source |
|---|---|---|---|
| SEC-R1 | After an integrity failure (`.badSignature`, `.digestMismatch`, `.unexpectedBundle`, `.invalidCodeSignature`) and for `.notSigned`, the app never offers the DMG. It shows a warning and **Open Release Page**, which is not the default button. The decision is a pure BatteryCore enum (`UpdateFallback`). | `UpdateInstallTests`: every error maps; M5 check with a corrupted `.sig` | SEC-01 |
| SEC-R2 | Every URL the update code hands to `NSWorkspace.open` is `https` on `github.com`. Anything else falls back to the constant releases page. Links in release notes open only `https` (`OpenURLAction`). Downloads in the app are not host-filtered; the Ed25519 signature is the authority there. | Unit tests for `browserURL` and `isAllowedLink` | SEC-01, SEC-02 |
| SEC-R3 | The release channel (owner, repository, API endpoint, releases page, asset names) is defined once, in `ReleaseChannel`. No exact URL-prefix pinning. | grep `NikitaUsov/BatteryPulse` in `Sources` = 1 | SEC-19, SEC-01 |
| SEC-R4 | Update traffic uses ephemeral sessions with `urlCache = nil`. Automatic checks set `allowsConstrainedNetworkAccess` and `allowsExpensiveNetworkAccess` to false and **don't** wait for connectivity. Check Now never waits behind an automatic check. No `URLSession.shared`. | After SEC-03 (P2): grep `URLSession.shared` = 0; M5: no `Cache.db` after a check | SEC-03, E10 |
| SEC-R5 | The app trusts a list of release public keys. `release.yml` checks that the secret's key is in that list. Releases are signed only by the workflow, and nobody asks for or handles the private key. | `UpdateSignatureTests`: K2 verifies with {K1, K2}, fails with {K1} | SEC-05; CLAUDE.md |
| SEC-R6 | Every build checks the signing posture in `build-app.sh` and fails otherwise: the hardened runtime on every bundle; no `get-task-allow` (except a `PROFILING=1` build, which is never published); no entitlements on the app; the widget's entitlements equal its file's; no `LSFileQuarantineEnabled` or `NSAppTransportSecurity` in the Info.plist. | The CI packaging step fails on a flipped invariant | SEC-07, E2 |
| SEC-R7 | Risky APIs stay where they are today: `dlopen`/`dlsym` only in `MobileDevice/MobileDeviceLibrary.swift` and `MacAccessoryProvider.swift`; `IOServiceOpen`/`IOConnectCall*` only in `SMCClient.swift`; `Process()` only in `UpdateInstaller.swift`; `kill(` only in `WidgetRefresher.swift`. `SMCParamBlock.Command` keeps exactly the commands 5, 8 and 9 (selector 2). | `SecurityGuardTests` (shared scanner with `MotionGuardTests`); `SMCTests` pins `allCases` | SEC-07; CLAUDE.md |
| SEC-R8 | Workflows: `permissions: contents: read` by default (`contents: write` only in `release.yml`), `actions/checkout` with `persist-credentials: false`, actions pinned to full commit SHAs with a version comment, inputs passed through `env:`, never `${{ }}` in `run:`. | `grep -n "uses:" .github/workflows/*.yml` shows only SHAs | SEC-06 |
| SEC-R9 | UDIDs, ECIDs and serials are never written to disk or logged in clear. Device logs hash them. `RememberedDevice` stores none of them. | Review; `log stream` | SEC-16, SW-12 |
| SEC-R10 | Private frameworks are opened with `dlopen` on demand from constant absolute paths, every symbol is checked, they are never linked, and there are no pairing calls. The MobileDevice version is recorded for diagnostics (stderr and log only). | `bpulse --devices` smoke step | SEC-09; CLAUDE.md |
| SEC-R11 | Nothing that the security research rejected: no App Sandbox for the main app, no privacy manifest, no certificate pinning, no environment wiping for child processes, no API or DMG size caps, no runtime code requirement in the installer, no signal path check, no App Attest, no post-quantum signatures yet. | Review | SEC §5, §6 |

### 1.5 Size and build

| ID | Rule | Check | Source |
|---|---|---|---|
| SZ-R1 | Shipped executables are stripped in the bundle (after `cp`, before `codesign`). The dSYMs are kept, attached to the release as `BatteryPulse-dSYMs.zip` and uploaded as a CI artifact. The `nm` checks run on `$BIN_PATH`, never on the bundle copies. | Size report: no `/Users/runner` strings; `dwarfdump --uuid` matches | SZ-01 |
| SZ-R2 | Each shipped executable exports only `_main`, and `-dead_strip` is on its link line. | `dyld_info -exports` lists `_main` only | SZ-02 |
| SZ-R3 | The DMG is ULMO (LZMA), made by creating an image and converting it (space-optimal), not with `create -format`. | `hdiutil imageinfo` | SZ-03 |
| SZ-R4 | The shipped app and widget build with `-Osize`, passed on `build-app.sh`'s command lines only. `swift test` and the CI `bpulse` build don't use it. | Build log | SZ-05, SW-18 |
| SZ-R5 | Every CI and release run writes a size report. The budget file is the only size gate. Raising a ceiling is its own commit that says why. | CI step summary | SZ-04 |
| SZ-R6 | Bundle hygiene: no `@rpath/libswift`, no `Contents/Frameworks`, no `.dSYM`, `.o` or `.swiftmodule` inside the bundle, no build-machine paths in a binary. | Size-report assertions | SZ-09 |
| SZ-R7 | No source-language `.strings` table made only of identity entries. A guarded check removes it, so a future plural or variation keeps its table. | App and widget in English and Russian | SZ-07 |
| SZ-R8 | Nothing that the size research rejected: no disabled reflection metadata, no shared dynamic framework, no `-no_exported_symbols` on the widget, no `-Xlinker -S`, no `lzma-level` image key, no UDBZ, no zlib-9, no `-objc_stubs_small`, no binary-plist `.strings`. LTO and `-dead_strip_dylibs` only as measured experiments. | Review | SZ-11 to SZ-14, "Not worth it" |

### 1.6 Dead code

| ID | Rule | Check | Source |
|---|---|---|---|
| DC-1 | Code is deleted only when it is proven unused by the **intersection** of debug (`-Onone`) `-dead_strip` link maps of all three products (BatteryPulse, BatteryPulseWidget, bpulse), linked with `_main` as the only export. Spot-check with sourcekit-lsp Find References or an IndexStoreDB script kept outside the repository. | Maps attached to the PR | SW-17, V-05 |
| DC-2 | Release maps are only for size attribution. They over-report (inlining), so they never decide a deletion. Linux maps can't show the macOS export problem. | Review | SW-17, SZ-06 |
| DC-3 | Code dead in every product but used by `Tests/` is either kept on purpose (with a comment) or moved into the test target. | Review | SW-17 |
| DC-4 | Never delete for size what runs through the runtime: protocol conformance records, `@objc` selectors, `dlsym` names, SwiftUI dynamic properties, `Codable` keys. | `-why_live` | SZ-02, SZ-12 |
| DC-5 | Legacy migrations are not dead code: the legacy settings keys and the `samples.jsonl` history migration keep upgrades from old versions working. They stay. | Review | §3.4 |
| DC-6 | Each deletion commit says why the code is unused and keeps every test green. No feature, setting, output or storage format goes away. | CI | the 0.6.1 brief |

---

## 2. Measurement protocol

The principle comes from W23-10160 and W26-268: measure, change one thing, then measure again on a
Release build over the same signpost interval. **Before** means 0.6.0 plus instrumentation only.
**After** means the 0.6.1 candidate. Every number is the median of 3 runs, taken alternately
A/B/A/B/A/B (WWDC25 226 recommends several runs). The tables go into a "Performance baseline"
section of `docs/ROADMAP.md` (numbers only, no traces), and the release notes summarize them.

### 2.1 The baseline build (do this first)

1. WP-0 (§3.2) lands on `main`. It adds instrumentation only, with no behaviour change.
2. Branch `perf/baseline-0.6.0` from `6133b4f` and cherry-pick WP-0 onto it. This is the **before**
   build: the shipped 0.6.0 code with the same signposts, `rusage`, the profiling build and the
   benchmarks as the candidate.
3. Size "before" comes from two places:
   - the published v0.6.0 `BatteryPulse.dmg`, which is the official figure;
   - `scripts/size-report.sh` on the baseline branch's build, which gives the per-component rows.
     Its DMG should match the published one within noise.
4. Record everything in §2.3 to §2.6 on the baseline before any optimization package merges.

### 2.2 Signposts (the shared vocabulary)

There is one `OSSignposter(subsystem: "io.github.nikitausov.BatteryPulse", category: .pointsOfInterest)`
in the app (`App/Diagnostics.swift`). BatteryKit gets a twin behind `#if canImport(os)` that is a
no-op on Linux. BatteryCore gets none: its work is bracketed at the call sites. The names are fixed
for 0.6.1, because Run Comparisons match intervals by name.

| Name | Kind | Where | Metadata |
|---|---|---|---|
| `refresh` | interval | `BatteryMonitor.refresh` | trigger: `notify`, `poll`, `history`, `followUp`, `wake`, `launch` |
| `read` | interval | `MacBatteryProvider.read` | full or live (after E4b) |
| `registry`, `children`, `iops`, `adapter`, `smc.power`, `smc.other`, `parse` | intervals inside `read` | `MacBatteryProvider`, `SMCClient` | key count for `smc.*` |
| `history.record` | interval | `HistoryRecorder` around the store call | — |
| `history.load` | interval | `HistoryView.load` (decode plus chart data) | period, sample count |
| `raw.rebuild`, `raw.filter` | intervals | `DeveloperView` | row count |
| `page.switch` | interval | `MainView`, from the selection change to the first `onAppear` of the page | page |
| `device.read`, `accessory.read` | intervals | `IDeviceMonitor`, `AccessoryMonitor` | — |
| `update.check` | interval | `UpdateChecker` | automatic or user |
| `widget.reload` | event | `WidgetRefresher` | reason |
| `menuBarReady` | event | first `MenuBarLabel` appearance | — |

### 2.3 On the MacBook Air M5 (macOS 27, Xcode 27)

**Builds.**
- The release DMG of each version, for energy and size.
- `PROFILING=1 scripts/build-app.sh` for Instruments and the memory tools. It signs the app (not the
  widget) with `get-task-allow`. Its outputs are named `…-profiling`, and the release and CI guards
  refuse it (E2).
- Profile only Release builds (W26-268).

**Setup** (energy §4): same macOS 27.x build; record `sw_vers`, the cycle count and
`sysctl kern.pervasive_energy`; 60–80 % charge and **unplugged** for the energy runs;
brightness 50 % with auto-brightness and True Tone off; Wi-Fi on; Low Power Mode off (plus one run
with it on); no other user apps; Focus on; 10 minutes after login. Same app settings for both
builds: History on, daily checks, the default window style unless the scenario says otherwise.

**Energy scenarios.** Measure each with `swift scripts/rusage.swift $(pgrep -x BatteryPulse) <s>`
(M1). It prints mJ/h with the P-core share, package-idle and interrupt wake-ups per hour, CPU s/h,
instructions per hour, disk bytes written per hour and `phys_footprint`.

| ID | Scenario | Duration |
|---|---|---|
| S1 | Idle: icon and charge only, no window, display on, no input | 30 min |
| S2 | Idle with the **power** item in the menu bar | 30 min |
| S3 | Popover open | 5 min |
| S4 | Main window: Overview 5 → History 24 h 5 → History 7 d 5 → Raw Data 5 | 20 min |
| S4w | S4's Overview step, once per window style: Standard, Frosted, Translucent, Clear (new: replaces SUI-16) | 4 × 5 min |
| S5 | Main window fully covered by another window | 10 min |
| S6 | Display asleep with the power item shown: once on power, once on battery with `caffeinate -i` | 15 min each |
| S7 | Cold launch: quit, then launch from Finder | 10 launches |
| S8 | Plug and unplug: 5 cycles, 1 min apart | 5 min |
| S9 | iPhone attached over USB, "Read devices" on: device page open 5, then closed 5 (0.6.0 addition, baseline only) | 10 min |
| S10 | Bluetooth accessories connected (for example AirPods), no window (0.6.0 addition, baseline only) | 15 min |

**SwiftUI scenarios** (SUI-01; SwiftUI template plus Swift executors, profiling build):
- (a) Overview, 30 s of 2 s polling.
- (b) Switch every page twice, including Devices and Accessories.
- (c) History: 24 h and 7 d, with the pointer swept over every chart.
- (d) Raw Data: type a 6-letter filter, clear it, open the inspector.
- (e) Open and close the menu bar panel 5 times.
- (f) Demo Mode tour.
- (g) Menu bar item only for 10 minutes, with the default label and with the power item.

Before the first run: `xcrun xctrace list templates`. Template names in Instruments 27 are
unconfirmed.

**Record per scenario:**
1. M1 numbers. Activity Monitor's App Nap and Preventing Sleep columns. Preventing Sleep must stay
   No outside an install.
2. Signposts (Instruments: os_signpost, Time Profiler, Swift executors):
   - reads per minute;
   - `read` p50 and p95, split into `registry`, `smc.power`, `smc.other` and `parse`;
   - `history.load` p50, cold and warm;
   - `raw.filter` per keystroke;
   - `page.switch`;
   - `widget.reload` count.

   Compare builds with Run Comparisons on the same interval.
3. SwiftUI:
   - body updates per view type per 2 s tick, for `MainDetail`, the current page, `MenuBarLabel`
     and the popover (Summary: All Updates);
   - orange (> 500 µs) and red (> 1 ms) long body updates;
   - hitches;
   - main-actor time inside each interval.
4. Memory, on the profiling build, after S4 plus 5 open → History 7 d → close cycles with Mark
   Generation: `footprint`, `vmmap --summary` and `leaks`.
5. Launch (S7): App Launch template; time to `menuBarReady` (p50 of 10); `read` count before it.
6. Once, for the gated energy items:
   - `pmset -g pslog` for 2 h on battery and 1 h charging;
   - alongside it, the 10 s `ioreg … | grep UpdateTime` loop;
   - expected: every `timeremaining` is followed by "any" (E3b), and the "any" posts follow
     `UpdateTime` changes (E4b).
7. Sleep hygiene: `pmset -g assertions` shows BatteryPulse only during an install. After a night
   with the lid closed, `pmset -g log` shows no wake attributed to BatteryPulse.

### 2.4 In CI (macOS job and release job)

`scripts/size-report.sh` runs after `build-app.sh` (SZ-04). It writes a Markdown table to
`$GITHUB_STEP_SUMMARY` and `build/size.json`, and both runs upload `size.json`.

**Size rows** (Apple tools only):

| Row | How |
|---|---|
| DMG bytes and format | `stat -f%z`, `hdiutil imageinfo` |
| `.app` installed KB | `du -sk` |
| App and widget binary bytes | `stat -f%z` |
| `__TEXT,__text` per binary | `size -m` |
| Exported symbols per binary | `dyld_info -exports … \| wc -l`; output format unverified |
| `.strings` and `.icns` bytes | `stat -f%z` |

**Hygiene assertions (SZ-09).** The step fails on any of these:
- `@rpath/libswift` in `otool -L`;
- a `Contents/Frameworks` folder;
- a `.dSYM`, `.o` or `.swiftmodule` inside the bundle;
- `/Users/runner` in a shipped binary (`strings -a`);
- any SEC-07 posture failure; `build-app.sh` checks these itself.

**Budget.**
- `scripts/size-budget.json` holds one ceiling per row. Confirm that `plutil -extract` reads JSON on
  the runner; otherwise use an XML plist.
- The first ceilings are the 0.6.1 numbers plus about 5 %.
- A comparison with the latest release DMG is informational only. That step needs
  `GH_TOKEN: ${{ github.token }}`.

**Link maps (SZ-06).**
- `-Xlinker -map` for both shipped binaries, uploaded as artifacts.
- The dead-code maps of DC-1 are a separate debug build, run on demand. They are not a CI gate.

**Warnings.** 0 on both jobs; this is the SW-14 gate. The step summary also counts the
`PerformanceHints` group, as information only (SW-15, never a gate).

Instruments on the hosted runner is not assumed (C5 rejected: a VM has no battery).

### 2.5 On Linux (cloud session and the Linux CI job)

There is no XCTest performance testing in SwiftPM with Swift Testing (F15), so the Linux numbers
come in two kinds.

**Work counts, asserted, always on (C1).** These run in BatteryKitTests and BatteryCoreTests, with
a manual `Clock` injected into `BatteryMonitor`:
- N callbacks in one burst give 1 read (E3).
- No live-refresh client gives 0 reads per simulated hour (EN-13).
- `lastReadAt` is reused by the history tick and the launch requests (E8, E17).
- `LiveRefreshPolicy` intervals under LPM, reduced resources and thermal states (E6).
- `HistoryStore`:
  - 120 samples give 120 appends and at most 2 rewrites of `days.jsonl`;
  - a closed day is decoded **once** across two loads;
  - Clear History, pruning and day rollover invalidate the cache (E13, E14).
- `WidgetReloadPolicy`: a synthetic day with 6 plug cycles gives at most 25 reloads (E15).

**Micro-benchmarks, reported, never asserted.**
- A `Benchmarks` suite in BatteryCoreTests, disabled unless `BP_BENCH=1`, run as
  `BP_BENCH=1 swift test -c release --filter Benchmarks`.
- It uses `ContinuousClock`, warms up once, and prints the median of 15 runs.
- Testable imports change optimization a little, so compare only before against after on the same
  machine and toolchain.
- The workloads exist at 0.6.0 too, so the same file runs on the baseline branch.

| Bench | Workload | Feeds |
|---|---|---|
| B1 | `MacPowerParser` over each `m5-macos27-*` fixture, including `PropertyValue(any:)` | E4b, SW-15 |
| B2 | `HistoryStore.samples` over a generated 7-day store (10,080 lines plus 8 day files), cold and warm (warm means a second load in the same store) | E13 / SUI-05R. The research measured 83–91 ms per cold pass on the Linux VM |
| B3 | Points, spans and statistics for 24 h and 7 d (after SUI-04: `HistoryChartData.make`) | SUI-04 |
| B4 | `RawSection.sections(for:)` over the largest fixture, plus building the display rows | SUI-02 |
| B5 | Raw filter: a 6-letter query over all rows, the old five-way OR against the new joined string | SUI-02 |
| B6 | `BatteryReport` text and JSON rendering per fixture | regression guard for `bpulse` |

**Optional (C2, P3).** `/usr/bin/time -l .build/release/bpulse --input <fixture>` for instructions
retired and peak footprint, on macOS CI. Keep it only if the counters are non-zero and stable on the
runner.

### 2.6 Proof of "no loss of functionality"

1. **Tests.** Every existing test passes unchanged, except where a test pins an internal API that a
   package deliberately changed (for example `BatteryFormatter`). Such a test is rewritten in the
   same commit, with the assertion kept. The test count only grows.
2. **`bpulse` golden outputs** (Linux and macOS). This is a one-off script kept in the scratchpad, not
   committed.
   - Build `bpulse` from the baseline and the candidate. Run each with `TZ=UTC LC_ALL=en_US.UTF-8`
     over every fixture in `Tests/BatteryCoreTests/Fixtures`, in each of these forms:
     - `--input F`
     - `--input F --json`
     - `--input F --raw`, where `--input` accepts it
     - `--export csv`, `--export json` and `--export csv --days --decimal-comma` against a generated
       `--history` directory
     - `--help`
   - `diff -r` must be empty. Exit codes must match. macOS adds `--smc`, `--devices` and
     `--accessories` smoke runs (status 0 or 2 on the runner).
3. **On the M5**, after the candidate is installed through an in-app update from 0.6.0:
   - SW V-01, the runtime isolation checklist: install and relaunch; a notification clicked and one
     arriving while the app is frontmost; the menu bar icon on light and dark; Raw Data, History, Demo
     Mode, Check Now and Clear History; wake from sleep; the widget added and reloaded;
   - the SEC §7 checklist: `codesign` flags, the corrupted-`.sig` path, no `Cache.db`, `xattr`,
     `sfltool dumpbtm`, notification permission kept, the widget back, History and settings readable
     (macOS 27 XProtect app-data note);
   - devices, accessories and the four window styles;
   - Russian and English;
   - Reduce Motion and Reduce Transparency.
4. **Settings and storage.** Install 0.6.0, run it for a day, then update to the candidate. The
   following must be byte-compatible, and the History page must show the 0.6.0 data:
   - the `defaults read io.github.nikitausov.BatteryPulse` keys;
   - `History/` (`samples/*.jsonl`, `days.jsonl`);
   - `Devices/` (`key`, `devices.json`, per-device history).

### 2.7 Numbers 0.6.1 must report (before → after)

**Mandatory.** The release is not done without these:

| Area | Numbers |
|---|---|
| Size (CI) | DMG bytes; `.app` KB; app binary bytes and `__text`; widget binary bytes and `__text`; exports per binary; `.strings` bytes; build-machine strings (must be 0) |
| Energy (M5) | S1 and S2: mJ/h, package-idle wake-ups/h, CPU s/h, reads/min. S8: reads per notify burst, widget reloads per cycle. S7: `menuBarReady` p50 and reads before it. Idle `phys_footprint`, and growth across the S4 cycles |
| Read path (M5) | `read` p50/p95 (full and, if E4b lands, live), with the `registry` / `smc.*` / `parse` split |
| Responsiveness (M5) | `history.load` 7 d, cold and warm (total and main-actor ms); `raw.filter` per keystroke; red and orange long updates in (a) to (d); body updates per tick for `MainDetail` and the page; hitches in (b) |
| Linux benches | B1 to B5 medians |
| Code | Lines per target (`wc -l`); warnings (Linux and macOS); test count; `@unchecked Sendable`; `withObservationTracking`; `Task.detached`; `@MainActor` in the app; `try?`; `URLSession.shared`; swift-format findings |

**Reported if measured:** S3–S6, S4w (window styles), S9, S10, disk bytes per hour, widget reloads
per day (`log show`), the App Launch trace, and `hdiutil attach` time for UDZO against ULMO with and
without `-noverify` (SEC-15).

**Proposed acceptance targets.** Fix the real values after the baseline. The estimates come from the
research and are not promises.

| Target | Value |
|---|---|
| DMG | −50 % or better against 0.6.0. The research estimates about 1.0–1.15 MB from 2.68 MB at 0.5.0; 0.6.0 is larger, so measure it |
| App binary | −55 % |
| Widget binary | −60 % |
| Exports | 1 per binary |
| Build-machine strings | 0 |
| S1 | Wake-ups/h ≤ 0.6.0; about 1 read/min (the history tick only) |
| S2 | Energy and CPU per hour −50 % (E4a, plus E4b if it lands) |
| S6 | CPU per hour about equal to S1 |
| S8 | 1 read per notify burst; ≤ 1 widget reload per cycle |
| Launch | Exactly 1 `read` before `menuBarReady`; p50 ≤ 0.6.0 |
| History 7 d warm reload | Decodes only today's file; main-actor time only the assignment |
| Raw Data typing | No red updates in `DeveloperView` |
| Memory | No growth across cycles; idle footprint ≤ 0.6.0 |
| Warnings | 0 / 0 |
| `withObservationTracking` | 0 |
| `URLSession.shared` | 0, if SEC-03 lands |
| Golden-output diff | Empty |

---

## 3. Backlog, work packages and what must not change

### 3.1 Priorities

The research used P0 to P3. This playbook folds them into three levels:
- **P1**: ships in 0.6.1. That is the foundation (research P0) plus the measured wins.
- **P2**: ships if time allows after P1. It may slip to 0.6.2 without blocking the release.
- **P3**: optional, conditional, or a spike.

A **gate** is a measured condition (§2) that promotes or drops an item. Gated items go no higher
than their gate allows.

### 3.2 Work packages

The packages run in three phases. Phase A is sequential and small, and it touches many files once,
so the parallel packages start from it. Phase B packages each own a coherent set of files and can
run in parallel worktrees. Phase C is sequential lock-in work that needs the merged code.

Each package is its own PR. It keeps `swift build`, `swift test` and `swift format lint --strict`
green on Linux, and keeps the macOS CI job green (Darwin code is verified only there). It reports its
§2.7 rows before and after.

#### Phase A: foundation (sequential, in this order)

**WP-0 Measure and gate (P1, S–M).** Lands first and is cherry-picked onto `perf/baseline-0.6.0`.
- Owns:
  - new `Sources/BatteryPulseApp/App/Diagnostics.swift`: the `Logger` categories of SW-R10 and the
    `OSSignposter`;
  - new `Sources/BatteryKit/Diagnostics.swift`: a `#if canImport(os)` twin, a no-op on Linux;
  - new `scripts/rusage.swift` (M1);
  - new `scripts/size-report.sh` and `scripts/size-budget.json`, with no ceilings yet;
  - new `Tests/BatteryCoreTests/Benchmarks.swift` (B1 to B6, opt-in);
  - a new `Tests/BatteryCoreTests/SourceScanner.swift` extracted from `MotionGuardTests` (helper
    only, so the Phase C guards can reuse it).
- Touches:
  - one-line interval wraps (§2.2) in `BatteryMonitor`, `MacBatteryProvider`, `SMCClient`,
    `IDeviceMonitor`, `AccessoryMonitor`, `HistoryRecorder`, `HistoryView`, `DeveloperView`,
    `MainView`, `WidgetRefresher`, `UpdateChecker`, and `menuBarReady` in `MenuBarLabel`;
  - `scripts/build-app.sh`: `PROFILING=1` (E2);
  - `.github/workflows/ci.yml`:
    - the warning gate on the Linux build and the macOS `swift test` (SW-14);
    - `swift package dump-package` (SW-24);
    - the size-report step;
    - `swiftc -typecheck scripts/rusage.swift` in "Check the verification scripts";
  - `.github/workflows/release.yml`: the size report, and the `get-task-allow` refusal (E2).
- Items: SUI-01, E1, M1, E2, SZ-04 (with SZ-09), SW-14, SW-24 (CI smoke), the B1 to B6 benches.
- Then: record the baseline (§2.1).

**WP-1 Manifest and language mode (P1, S).**
- Owns: `Package.swift` and `.swift-format`.
- Touches: only the mechanical fix-ups the new settings demand in Darwin-only files: `any`, explicit
  imports such as `Combine` for `.onReceive`, and an `unsafe` marker. On Linux the fix-ups are 0, as
  measured at `6133b4f`.
- Items:
  - SW-01: tools 6.4, `.v27`, the shared `strict` array; `.defaultIsolation` is **not** added yet;
  - SW-02;
  - SW-03 with V-02: migrate as a report, run on macOS too;
  - SW-13 for BatteryCore. bpulse marks its one site `unsafe`, or stays without the flag;
  - SW-20, complete. At `6133b4f`, seven of its rules have 0 hits: the six, plus
    `NoEmptyLinesOpeningClosingBraces`, which is now 0. Fix the 11 remaining sites
    (`ValidateDocumentationComments` 10, `UseWhereClausesInForLoops` 1; doc comments and one loop),
    then turn on all nine rules;
  - SW-24.
- Done when: dump-package shows the settings; 0 warnings on both jobs.

#### Phase B: parallel worktrees (after WP-1 merges)

| WP | Theme | Owns (files) | Items |
|---|---|---|---|
| **WP-2** | Battery read path and polling energy | `BatteryKit/{BatteryMonitor, MacBatteryProvider, BatteryProvider, SMCClient, SystemNotifications}.swift`; `BatteryCore/SMC.swift`; new `BatteryCore/LiveRefreshPolicy.swift`; `MenuBar/MenuBarLabel.swift`; `App/Motion.swift` (only the live-refresh request plumbing for E5); tests `BatteryKitTests/BatteryMonitorTests`, `BatteryCoreTests/SMCTests`, new `LiveRefreshPolicyTests` | **P1:** E3 (inject a `Clock`), E4a, C1 monitor cases, SW-08 (monitor task names), SW-12 (`monitor`/`smc`/`iokit`), E8 monitor half (`lastReadAt`, **first commit**, so WP-4 can rebase on it), E7 (follow-up tolerances). **P2:** E17, E5, E6, SW-06 (`UncheckedSendable` → local `nonisolated(unsafe) let`), SW-07, E3b (gate: pslog). **P1/P3:** E4b (P1 if `registry` plus `parse` still dominate `read` after E4a, else P3). **P3:** E20 (gate: full `read` p95 > 4 ms) |
| **WP-3** | History pipeline | `BatteryCore/{HistoryStore, History}.swift`; `Main/HistoryView.swift` → `Main/History/{HistoryView, ChargeChart, PowerChart, TemperatureChart, HealthTrendCharts}.swift`; tests `HistoryTests` plus new store and chart-data tests | **P1:** SUI-03, SUI-04 (`HistoryChartData` in BatteryCore with a `@concurrent` builder; fix the per-day `Calendar` in `day.date()`), SUI-05R/E13 decode cache (gate: P1 if `history.load` 7 d > 50 ms on the M5; the Linux VM measured 83–91 ms, so expected), the minute timer with `tolerance: .seconds(15)` (E7), SUI-10 names. **P2:** SUI-13 chart split, E14 store hygiene (policy before I/O, migration once per session, one encoder, no `Data` copy). **P3:** SUI-12 `LinePlot` spike (gate: chart updates still orange or red after SUI-03/04) |
| **WP-4** | App services: observers, notifier, widget refresher | `App/{HistoryRecorder, BatteryNotifier, WidgetRefresher, DemoController, BatteryPulseApp}.swift` | **P1:** SW-09 at all 4 sites with `.dropFirst()`, V-03, SW-08 names, SW-12 (`history`/`widget`; log the recorder's failed writes instead of `try?`), E7 (`DemoController` tolerance). **P2:** E8 recorder half (after WP-2's `lastReadAt`), E15 (log each reload, plus a signpost event), V-04 (`@preconcurrency import UserNotifications`, macOS only). **P3:** SUI-09 `AppServices` grouping |
| **WP-5** | Raw Data and formatting | `Main/{DeveloperView, RawValueText}.swift`; `App/Localized.swift`; `BatteryCore/{BatteryFormatter, RawValueDecoding, RawKeyGlossary, RawSectionGroup}.swift`; tests `BatteryFormatterTests`, `RawKeyGlossaryTests`, `RawSectionGroupTests` | **P1:** SUI-02 (display rows with a joined `searchText`, built in a `@concurrent` helper; UI-10), SW-05 (the DeveloperView site). **P2:** SUI-06 (`UnitSymbols: Equatable`, `BatteryFormatter: Equatable`, `static let app`). It keeps the names `BatteryFormatter.app` and `BatteryFormatter()`, so its 14 call sites (app and widget) don't change. **P3:** SUI-11, E19, SZ-08 (glossary as data) |
| **WP-6** | Updates and release channel | `Updates/{UpdateChecker, UpdateInstaller, UpdateViews}.swift`; `App/AppSettings.swift` (`AppLinks` only); `BatteryCore/{UpdateInstall, Updates, ReleaseSigning}.swift`; `BatteryKit/UpdateSignature.swift`; `scripts/sign-update.swift` (runbook in `--help`); `release.yml` (only the key-check step); `Resources/Localizable.xcstrings` (**the only package that adds strings**); tests `UpdateInstallTests`, `UpdatesTests`, `UpdateSignatureTests` | **P1:** SEC-01, SEC-05 (ships with SEC-01), SW-05 (`verify`/`replace` as `@concurrent`, the shield on `replace`, and the named leftover cleanup), SW-06 (`DownloadWatcher` → `Mutex`), SW-12 (`update`; `UpdateInstaller.swift:523` private), SW-08 names, E7 (20 s → 5 s, 6 h → 30 min, 200 ms → 50 ms tolerances). **P2:** SEC-19, SEC-03 (no `waitsForConnectivity`), SEC-02, E11, SW-11. **P3:** E10 (`waitsForConnectivity` together with Check Now cancelling a waiting automatic check), SEC-15 (`-noverify`, gate: ≥ 100 ms with ULMO), SEC-17 (doc comment plus a downgrade test) |
| **WP-7** | Devices and accessories robustness | `BatteryKit/{IDeviceTransport, IDeviceMonitor, MacAccessoryProvider, AccessoryMonitor}.swift`; `BatteryKit/MobileDevice/*`; `BatteryCore/PropertyValue.swift`; tests `IDeviceMonitorTests`, `IDeviceReaderTests`, `PropertyValueTests` | **P1:** SW-06 (`ResumeOnce`, `IDeviceListBuilder`; judge `USBDeviceWatcher` and `Watch` by the same test). **P2:** SEC-09 version (in `IDeviceError.frameworkUnavailable` text and the `device` log, never on `--devices` stdout), SW-12 (`device`/`accessory`, identifiers hashed). **P3:** SEC-09 `RTLD_LOCAL \| RTLD_FIRST`, SEC-11 depth limit 64. **WP-7b (P2 → P1 on evidence, M):** SEC-10, MobileDevice in a separate process. Gate: a MobileDevice hang or crash in 0.6.0's M5 testing. Option B (`BatteryPulse --device-helper`, 0 MB) touches only `BatteryPulseApp.swift` plus BatteryKit. Option A (an `.xpc`) also touches `Package.swift` and `build-app.sh`, so it waits for WP-8 and runs in Phase C |
| **WP-8** | Build, size and release pipeline | `scripts/build-app.sh` (except WP-0's `PROFILING` block); `ci.yml` and `release.yml` (except WP-6's key-check step); `scripts/size-budget.json` (the ceilings); `Resources/AppIcon.*` | **P1:** SZ-01 (strip the bundle copies, dSYMs zipped onto the release and uploaded in CI), SZ-02 (`-Xlinker -exported_symbol -Xlinker _main` on both `swift build -c release` lines; confirm `-dead_strip` with `-v`; `-why_live` on `RawSection.sections(for:)`), SZ-03 (ULMO via create → convert), SZ-05 (`-Osize`, verified with Run Comparisons), SZ-06 (link maps as artifacts), SEC-07 build check. **P2:** SEC-06 (`permissions`, `persist-credentials: false`, SHA pins; immutable releases are a repository setting for the maintainer), SZ-07 (guarded identity `en` table), SZ-10 (Icon Composer through `actool`; `AppIconView` must keep matching), SEC-08 spike on a throwaway branch (widget first; hard gate: an in-app update 0.6.0 → candidate launches on the M5; drop it if ad-hoc signatures can't carry the entitlements). **P3:** SZ-14, SZ-11 (one LTO CI experiment; adopt only if > 10 % on top of the rest). Fill the budget ceilings last |
| **WP-9** | View structure (readability) | `Settings/SettingsView.swift` → one file per pane; `Main/Components.swift` → `Main/Components/*.swift`; `Main/{OverviewView, PowerView, HealthView, CompactView, AccessoriesView, DeviceView, DevicesIntroView}.swift`; `MenuBar/{PopoverView, PopoverAccessories}.swift`; the `MotionGuardTests` file lists, and CLAUDE.md's glass list (`SettingsView.swift` is on it) | **P2:** SUI-13 (Settings and Components split), SUI-15 (review the device and accessory lists against UI-7), SUI-07 (gate: body counts per tick; needs WP-5's Equatable formatter, so rebase after WP-5), SUI-17 previews spike in `#if DEBUG` (if previews need a library target, the target split moves to Phase C because it touches `Package.swift`), SUI-18 (SwiftUI Specialist skill as the review checklist; nothing from it is committed). **P3:** SUI-19 type-check timing on the Mac |

**Cross-package dependencies (the only ones):**
- WP-4's E8 needs WP-2's first commit (`lastReadAt`).
- WP-9's SUI-07 needs WP-5's SUI-06.
- WP-7b option A needs WP-8.
- Phase C's dead-code maps need WP-8's SZ-02.

**Files more than one package touches:**
- `ci.yml` and `release.yml`: WP-0 lands first, then WP-8 owns them, except WP-6's key-check hunk.
- `build-app.sh`: WP-0's `PROFILING` block, then WP-8.
- `MotionGuardTests.swift`: WP-0 extracts the scanner, WP-9 edits the lists, and the Phase C guards
  are new files.
- CLAUDE.md: WP-9 changes only the glass list; Phase C changes everything else.
- `Localizable.xcstrings`: WP-6 only. No other package adds or removes a UI string. If one must, it
  rebases after WP-6.

#### Phase C: lock-in (sequential, after Phase B merges)

**WP-10 App isolation (P1, M).**
- Items: SW-04 (`.defaultIsolation(MainActor.self)` for `BatteryPulseApp` only); remove the
  redundant `@MainActor`; mark off-main code `nonisolated` (`UpdateInstallSteps`, `DownloadWatcher`,
  `AppearanceVariants`; keep the `UNUserNotificationCenterDelegate` methods `nonisolated`).
- Then the V-01 checklist on the M5. It goes last because it touches every app file mechanically.

**WP-11 Less code (P1, M).**
1. SW-17 with V-05: debug `-dead_strip` maps of the three products with `_main` as the only export,
   intersected, then cross-checked with references (DC-1 to DC-6).
2. One deletion commit per area.
3. SZ-06 attribution of what remains.
4. Lint the deletions with the SW-20 rules; WP-1 already turned them on.
5. P2: SW-15 `PerformanceHints` audit of the hot paths only, SW-19 (`#require`, parameterized
   fixtures), SW-21 DocC check.
6. **Not in 0.6.1:** SW-16 (`package`) and `AllPublicDeclarationsHaveDocumentation` (510 sites at
   `6133b4f`; `BeginDocumentationCommentWithOneLineSummary` has 280). The decision is to keep `public`
   (SW-R17).

**WP-12 Guards and docs (P1 for the guards, S).**
- New tests, reusing `SourceScanner`:
  - `SecurityGuardTests` (SEC-R7; plus "`URLSession.shared` nowhere" once SEC-03 has landed);
  - `EnergyGuardTests` (EN-1, EN-2, EN-8, EN-11).
- CLAUDE.md Conventions, one line each: sleep tolerances, `Observations` with `.dropFirst()`, logging
  privacy, `@concurrent` offloading, environment contents (UI-6), the signpost names, the guard tests.
- `docs/ROADMAP.md`: the 0.6.1 stage, decisions and the "Performance baseline" tables (§2.7).
- `docs/USER_GUIDE.md`: only the new update-integrity warning text.
- Set the final size-budget ceilings (0.6.1 plus about 5 %).

**Release gate.** Every §2.7 mandatory number, before and after. An empty golden-output diff. The M5
checklists of §2.6. Both CI jobs green with 0 warnings.

### 3.3 Backlog by priority (one line per item; the package is in brackets)

**P1.** SUI-01/E1 [0]; M1 [0]; E2 [0]; SZ-04 with SZ-09 [0]; SW-14 [0]; SW-24 [0,1]; SW-01 [1];
SW-02 [1]; SW-03 with V-02 [1]; SW-13 Core [1]; SW-20 [1]; E3 [2]; E4a [2]; C1 [2,3];
E8 monitor half [2]; SW-08 [2,3,4,6]; SW-12 [2,4,6,7]; SUI-03 [3]; SUI-04 [3];
SUI-05R/E13 [3, gated, expected]; E7 at every site [2,3,4,6] (one argument each; EnergyGuardTests needs all of them); SW-09 with V-03 [4]; SUI-02 [5];
SW-05 [5,6]; SEC-01 [6]; SEC-05 [6, paired with SEC-01]; SW-06 [6,7]; SZ-01 [8]; SZ-02 [8];
SZ-03 [8]; SZ-05 [8]; SZ-06 [8,11]; SEC-07 build check [8]; SW-04 with V-01 [10];
SW-17 with V-05 [11]; SEC-07 guard test and C4 [12]; docs [12].

**P2.** E17, E5, E6, SW-06 `UncheckedSendable`, SW-07, E3b gated [2]; SUI-13 History,
E14 [3]; E8 recorder half, E15, V-04 [4]; SUI-06 [5]; SEC-19, SEC-03, SEC-02, E11, SW-11 [6];
SEC-09 version, logging identifiers [7]; SEC-10 [7b, P1 on evidence]; SEC-06, SZ-07, SZ-10, SEC-08
spike [8]; SUI-13 Settings and Components, SUI-15, SUI-07 gated, SUI-17, SUI-18 [9]; SW-15, SW-19,
SW-21 [11]; E18 and SUI-16's replacement S4w (measurement only).

**P3.** E4b unless gated up, E20 gated [2]; SUI-12 gated [3]; SUI-09 [4]; SUI-11, E19, SZ-08 [5];
E10, SEC-15 gated, SEC-17 [6]; SEC-09 flags, SEC-11 [7]; SZ-11, SZ-14 [8]; SUI-19 [9];
SUI-21 (one CLAUDE.md line, in WP-12); C2; SEC-16 (keep USER_GUIDE's privacy text current);
SEC-18 (after 0.6.1).

**Obsolete since 0.6.0:** SUI-14 (cards already read the environment) and SUI-16 (Glass Cards
removed).

**Rejected; don't resurrect them:**

| Area | Items |
|---|---|
| SwiftUI | SUI-05 as written; SUI-06's "avoid closures" reason; a Bool passed to `CopyReportButton`; diacritic folding; SUI-20 `appearsActive`; SUI-21 as a test; splitting the snapshot, `scenePhase` for occlusion, a `Canvas` glyph, `drawingGroup` on charts, blanket `.equatable()` |
| Swift | SW-10 typed notification messages (unless the SDK has `MainActorMessage` types); SW-22 `InlineArray`/`Span`; SW-23 noncopyable `Continuation`; `ExplicitSendable`; permanent `PerformanceHints`; Embedded, Lifetimes and other experimental flags; typed throws everywhere; `@inline(always)`/`@specialized`; the Subprocess package; module selectors; `isolated deinit`; `weak let`; default main-actor isolation for the widget; `--explicit-target-dependency-import-check`; `@diagnose(StrictMemorySafety, as: warning)` as a per-function switch |
| Energy | the E4 private-message spike; E9 `NSBackgroundActivityScheduler`; E12 KVO download progress; E16 MetricKit; C5 xctrace on CI |
| Security | SEC-04; SEC-14; SEC-15 environment wiping; SEC-11 size caps; the `dladdr` assertion; moving `contents: write` into the single job; certificate pinning; fd-based verification; an Enhanced Security helper extension; App Attest; post-quantum signatures; provisional notifications; a privacy manifest; App Sandbox for the main app; exact URL-prefix pinning |
| Size | SZ-12 (disabling reflection); SZ-13 (shared framework); `-objc_stubs_small`; binary `.strings`; zlib-9; UDBZ; `package` for size; `lzma-level`; `-no_exported_symbols` on the widget; `-Xlinker -S` |

### 3.4 What must stay unchanged

0.6.1 adds no features and removes none. Each item below is checked by §2.6.

**Behaviour.**
- Everything in `docs/USER_GUIDE.md` works as in 0.6.0:
  - Overview, Power, History, Health, Devices (iPhone/iPad pages), Accessories, Raw Data, Demo Mode;
  - the compact window, the popover and the menu bar content and icon styles;
  - Dock icon policy, the welcome window, About, What's New;
  - window styles, including the Reduce Transparency and Increase Contrast fallback to Standard;
  - Reduce Motion and the hidden-window rules;
  - English and Russian.
- **Notifications.** Same alert rules and thresholds. No new evaluation at launch: SW-R7's
  `.dropFirst()`.
- **History.**
  - A sample about every 60 s (`HistoryPolicy.interval`), plus samples on state changes and on wake.
  - 10-day sample retention and daily summaries kept.
  - Clear History clears everything, including any new cache.
  - With recording off, the time axis still advances.
- **Plug and unplug.**
  - Still shown within the 0.4 "starting to charge" window.
  - E3's coalescing may add at most about 250 ms.
  - Live values may be up to one poll old. SMC values other than `B0AV`/`B0AC` may be up to 60 s old
    while neither Raw Data nor Power is shown.
- **Updates.**
  - The first automatic check about 20 s after launch, and only it may open the Software Update
    window.
  - Frequencies daily, weekly, monthly or never.
  - Check Now never waits behind an automatic check, and it bypasses the cached answer.
  - Only the download can be cancelled; once checked, the update goes in.
  - Quitting waits for an install.
  - Downgrades are refused.
  - Relaunch works.
  - The only intended change is SEC-01: after an integrity failure the app offers the release page
    instead of the DMG.
- **Widget.** Same kind, look and reload policy. The stale extension still ends after an update.
- **Devices.** Reads are opt-in. No pairing calls. UDIDs stay in memory only. Device history keeps
  its schedule.
- **Raw Data search.** Case-insensitive and diacritic-sensitive, the same matches as 0.6.0 (UI-10).
- **Demo Mode.** Same scenes, and it still simulates LPM and the thermal state without changing the
  real poll policy.

**Settings keys** (`UserDefaults` domain `io.github.nikitausov.BatteryPulse`). Names, types and
defaults stay unchanged, and so do the legacy migrations:
- menu bar and Dock: `showInMenuBar`, `showDockIcon`, `menuBarShowsIcon`, `menuBarShowsCharge`,
  `menuBarShowsPower`, `menuBarShowsTemperature`, `menuBarIconStyle`;
- windows and welcome: `showDeveloperSection`, `showWelcomeAtLaunch`, `hasSeenWelcome`,
  `prefersCompactWindow`, `windowLook`;
- updates: `updateFrequency`, `lastUpdateCheck`, `skippedVersion`, `updateLeftover`,
  `lastSeenVersion`;
- history and devices: `recordHistory`, `readDevices`;
- alerts: `alertChargeLimit`, `alertLowBattery`, `alertService`, `alertHeat`, `alertState`,
  `alertAccessoryLow`, `accessoryAlertState`;
- legacy keys that are still read and then removed: `menuBarStyle`, `menuBarIcon`, `glassCards`,
  `checkForUpdates`.

Plus the login item through `SMAppService.mainApp`.

**Storage formats** under `~/Library/Application Support/io.github.nikitausov.BatteryPulse/`:
- `History/samples/YYYY-MM-DD.jsonl`: one file per UTC day, one JSON sample per line, append-only,
  with the same field names. Any new cache lives only in memory; there is no new on-disk file unless
  a later release decides so.
- `History/days.jsonl`: one summary per local day, rewritten atomically, at most hourly.
- `History/samples.jsonl`: legacy, migrated once.
- `Devices/key`, `Devices/devices.json`, `Devices/devices.unreadable.json`, and the per-device history
  stores in the same JSONL format.

**Public outputs of `bpulse`.** These stay byte-identical on stdout:
- the text report, `--json`, and the `--raw` capture plist (the fixture format);
- `--smc`, `--watch`;
- `--devices`, `--device <n> [--json | --raw]`, `--accessories [--json | --raw]`;
- `--export csv|json` with `--days`, `--decimal-comma` and `--history`;
- the `--record <folder>` layout and file names;
- `--help`;
- the exit codes: 0 for success, 1 for usage, 2 for no battery or no device.

Only stderr diagnostics may gain detail, for example the MobileDevice version in an error.

**Release and update contract.**
- Bundle IDs `io.github.nikitausov.BatteryPulse` and `….Widget`; the widget kind.
- The assets `BatteryPulse.dmg` and `BatteryPulse.dmg.sig` on GitHub Releases, so
  `releases/latest/download/BatteryPulse.dmg` keeps working.
- The Ed25519 key currently trusted stays trusted. SEC-05 only adds the ability to list a second
  key.
- Info.plist:
  - `LSUIElement`, `CFBundleLocalizations` en/ru, minimum system 27.0;
  - **no** `LSFileQuarantineEnabled`.
- Entitlements: none on the app, only the sandbox on the widget. The SEC-08 spike changes this only
  if it passes its gate.
- The log subsystem name.
- 0.6.0 must be able to install 0.6.1 in-app. A ULMO DMG is attached by `/usr/bin/hdiutil`, which
  0.6.0 already calls.

---

## 4. Settle these first (on CI or the M5), before the packages that depend on them

| Question | Where | Blocks |
|---|---|---|
| Does Swift Build write `$BIN_PATH/*.dSYM` for release products? | CI (`ls .build/out/Products/Release/*.dSYM` or the `--show-bin-path` folder) | SZ-01 dSYM step |
| Is `-dead_strip` on the macOS link line, and `-export_dynamic` absent? (`swift build -c release --product BatteryPulseWidget -v`) | CI | SZ-02, SW-17 |
| After SZ-02: does `-why_live` show `RawSection.sections(for:)` dead in the widget, and does the widget still start with only `_main` exported? | CI, then the M5 | SZ-02 |
| Output format of `dyld_info -exports`; can `plutil -extract … raw` read JSON? | CI | SZ-04 |
| Does `hdiutil help create` list ULMO (and any LZMESH format)? Does create → convert remove the 170 KB gap? | CI | SZ-03 |
| Does `actool` compile a `.icon` outside an Xcode project? | CI | SZ-10 |
| `xcrun xctrace list templates`: the SwiftUI and Swift Concurrency template names | M5 | §2.3 |
| Is `ri_energy_nj` non-zero for BatteryPulse? (`sysctl kern.pervasive_energy`) | M5 | M1 numbers; otherwise use CPU time and wake-ups only |
| Does App Nap apply to a status-item-only app? | M5, S1 against S2 | E5 framing |
| `pmset -g pslog`: is every `timeremaining` followed by "any", and does "any" track `UpdateTime`? | M5 | E3b, E4b |
| The cost split of `read` (`registry`, `smc.*`, `parse`) | M5 baseline | E4a size of win, E4b, E20 |
| `history.load` 7 d on the M5 (cold and warm) | M5 baseline | SUI-05R/E13 gate (> 50 ms) |
| `URLSessionTask` and `CGImage` `Sendable` in the macOS 27 SDK; the WidgetKit calling thread | macOS CI build | SW-06 `DownloadWatcher`, `AppearanceVariants`; SW-04 widget exclusion |
| `MemberImportVisibility` and `ExistentialAny` fix-ups in Darwin-only files; `migrate` output on Darwin code | macOS CI | WP-1 |
| Is `@preconcurrency import UserNotifications` still needed? | macOS CI | V-04 |
| Do previews work in a SwiftPM executable target in Xcode 27? | M5, 30 min | SUI-17 (library target or not) |
| Does AMFI accept the Enhanced Security entitlements on an ad-hoc signature? Does an in-app 0.6.0 → candidate update launch? | M5 | SEC-08 |
| Did 0.6.0's M5 testing show a MobileDevice hang or crash? | M5 (0.6.0 checks in `ROADMAP.md`) | SEC-10 priority |
| Does the new version still read History and settings with no prompt after an update? (macOS 27 XProtect app-data note) | M5 | SEC-17; release gate |
