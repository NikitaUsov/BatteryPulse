# Kit audit: adversarial verification

Checked against the code. HEAD is `a32bfae`. `git diff 6133b4f a32bfae` doesn't touch
`Sources/BatteryKit`, `Tests/BatteryKitTests`, `.github` or `Package.swift`, so the line numbers
are those of 0.6.0. Nothing in the repository was modified. Experiments live in
`scratchpad/v061/kitverify/`.

## Experiments run for this verification

- **E-K1, `.timeLimit` against a hung continuation (Swift 6.4.1, Linux).** Setup:
  `kitverify/tl`, a test awaiting a `CheckedContinuation` that is never resumed, with
  `@Suite(.timeLimit(.minutes(1)))`. Result: at 60.000 s the issue "Time limit was exceeded:
  60.000 seconds" is recorded and streamed, naming the test. But the runner **did not exit**:
  it was still running 72 s later, at 132 s, when the outer `timeout` killed it. Time limits
  rely on cooperative cancellation, and a continuation ignores cancellation.
- **E-K2, flakiness of the monitor tests.** The existing `core-build` runner ran
  `BatteryMonitorTests|AccessoryMonitorTests` 60 times while 16 busy loops ran on 4 cores.
  **0 failures in 60 runs**, each run about 0.34 s. Flakiness isn't shown on Linux; the macOS
  runner remains unmeasured.
- **E-K3, K-05 typecheck.** `kitverify/k05.swift` is a copy of `USBDeviceWatcher`'s shape: a
  final class holding only `let DispatchQueue`, plain `Sendable`, capturing an `@unchecked` `Watch`
  in `onTermination` and `queue.async`. It also models `MobileDeviceSink` over `NSLock.withLock`,
  including the early `return` inside the lock. `swiftc -swift-version 6 -typecheck` gives
  **0 diagnostics**.
- **CI durations.** `gh run list` shows the last 8 CI runs took **3–5 min** end to end.

## Verdicts

| ID | Verdict | WP | Priority (verified) |
|---|---|---|---|
| K-01 | keep-modified | WP-2 (a, inside E4a), WP-7 (b) | P3 |
| K-02 | keep-modified | WP-8 (`timeout-minutes`, main fix); WP-2/WP-7 (`.timeLimit`) | P2 |
| K-03 | keep-modified | Phase C, after WP-8 (gated) | P3 |
| K-04 | keep-modified | WP-2 (helper and MacBatteryProvider); WP-7 (MacAccessoryProvider) | P3 |
| K-05 | keep | WP-7 (with SW-06) | P2 (part of SW-06 P1) |
| K-15 | keep-modified | WP-7 (inside SW-12); the DeviceStore line goes to the core verifier | P2 |
| K-06 | reject | — | — |
| K-07 | keep-modified | WP-2 (inside E4a), WP-7 (inside SW-06) | P3 |
| K-08 | keep-modified | WP-2 (inside SW-12 `smc`) | P3 |
| K-09 | keep | WP-7 (with SEC-09's P3 flags) | P3 |
| K-10 | reject | — | — |
| K-11 | reject | — | — |
| K-12 | reject | — | — |
| K-13 | keep-modified | WP-7, WP-2 (riders only) | P3 |
| K-14 | keep-modified | WP-2 (inside E3/C1) | P3 |

## Per finding

### K-01 Wall clock for elapsed time: keep-modified (P3)

- **Confirmed.**
  - `MacBatteryProvider.swift:56`: `Date().timeIntervalSince(smcCache.date) < smcInterval`. If the
    clock steps back by Δ, the difference is negative, so the cache stays "fresh" for Δ + 2 s.
    The live `B0AV`/`B0AC` values that MacPowerParser uses for power freeze for that time.
  - `MobileDeviceTransport.swift:173-193`: with a backward step, `now.timeIntervalSince(start)`
    and `quiet` go negative, so neither the 3 s window nor the settle time ends the loop. The
    shared queue stays busy for Δ, waking at 10 Hz, and every list or capture behind it times
    out.
  - `CFRunLoopRunInMode`'s own timeout is monotonic and isn't affected.
- **Why P3, not P2.** The step must be backward and large, and it must land inside a 2 s cache
  window or a ≤ 3 s discovery. Examples are a manual date change or a large NTP step. On macOS
  that is rare; small corrections are slewed.
- **Modified.**
  - (a) Inside E4a, which rewrites this cache anyway: store `ContinuousClock.Instant`. The
    freshness decision can be E4a's pure BatteryCore function over a `Duration`; energy research
    puts the merge tests in BatteryCore. That makes a separate injected `now` in the
    macOS-only provider unnecessary.
  - (b) In WP-7: `let clock = ContinuousClock()`, `start = clock.now`,
    `start.duration(to: now) >= .seconds(3)`. That is 3–4 changed lines. The pure
    `discoveryEnded(elapsed:quiet:count:sawWanted:)` function is optional. Take it only if it
    reads as clearly as the loop: it buys Linux tests for logic that has none today, but it
    isn't needed for the fix.
  - The `sudo date` M5 check becomes optional; moving the maintainer's clock is invasive.
- **Not in scope.** `IDeviceMonitorClock` (`IDeviceMonitor.swift:19-37, 202, 229`) stays
  wall-clock. Its dates are shown and stored, and a backward step only delays a stale-list
  refresh by up to Δ. USB arrivals and Check Again still list.
- **Breaks nothing:** no stored format, no settings key, no CLI output.

### K-02 No hang protection in tests and CI: keep-modified (P2)

- **Confirmed.**
  - Only `IDeviceMonitorTests` has `.timeLimit` (`IDeviceMonitorTests.swift:346`).
  - `ci.yml` and `release.yml` have no `timeout-minutes`.
  - The CI smoke steps (`bpulse --devices`, `--record`) could also hang.
- **The audit's measurement is wrong.** Commenting out `IDeviceTransport.swift:317-319` doesn't
  make `BlockingWorkTests` hang. `stopsWaitingAtTheDeadline` waits on
  `release.wait(timeout: .now() + 10)`, so it fails after about 10 s whether or not there is a
  time limit. A real hang needs a continuation that is never resumed, which is what E-K1
  reproduces.
- **What `.timeLimit` does (E-K1).** At the limit it records the issue and names the test, but
  the process keeps hanging: measured, the runner was still alive 72 s after the limit. So the
  main fix is the job timeout, and `.timeLimit` only makes the log say which test hung.
- **Modified.**
  - WP-8, P2: set `timeout-minutes` on every job. Linux 15 and macOS 30 (today's runs take
    3–5 min), release 60.
  - WP-2 and WP-7, P3: add `.timeLimit(.minutes(1))` to the four suites, in the PRs that
    already touch them. `BatteryMonitorTests` and `AccessoryMonitorTests` go in WP-2's E3/C1
    commit, `IDeviceListingTests` and `BlockingWorkTests` in WP-7's SW-06 commit.
  - Replace the measurement with this: a temporary test awaiting a never-resumed continuation
    shows "Time limit was exceeded" at 60 s, and the job ends at its `timeout-minutes`.
  - Keep the `< 5` wall-clock bounds for now. Removing them is SW-R15's "timing is never
    asserted" work and belongs to C1.

### K-03 Split BatteryKit so the widget doesn't link the device stack: keep-modified (P3, gated, Phase C)

- **Confirmed.**
  - The widget uses only `MacBatteryProvider(readsSMC: false)`
    (`BatteryPulseWidget.swift:61`) but depends on all of BatteryKit (`Package.swift:27`).
  - Conformance records are always live (size research: `__swift5_proto`), so these witnesses
    stay after SZ-02: `MobileDeviceTransport: IDeviceTransport`,
    `USBDeviceWatcher: IDeviceAttachEvents`, `DemoBatteryProvider`/`MacAccessoryProvider`/
    `DemoAccessoryProvider`, and `HMACDeviceKeyDeriver: DeviceKeyDeriving`
    (`DeviceKeys.swift:10`).
  - **This corrects SZ-14's premise.** SZ-14 said only `UpdateSignatureVerifier` (a plain struct,
    strippable) uses CryptoKit. `HMACDeviceKeyDeriver`'s conformance keeps `HMAC<SHA256>`
    referenced, so `-dead_strip_dylibs` alone likely can't drop CryptoKit from the widget.
- **Why P3.**
  - The gain is a share of the measured ~369 KB of unused types in the widget's `__text`; much
    of that lives in BatteryCore and stays. After ULMO that is well under 1 % of the DMG.
  - CryptoKit comes from the shared cache, so loading it costs almost nothing.
  - It is a pure move: no code is deleted, and a target is added.
- **Modified: invert the direction.**
  - Create a small lower target, for example `BatterySource`: `BatteryProvider`/
    `BatteryObservation`, `MacBatteryProvider`, `SMCClient`, `SystemNotifications` and
    `IOSBatteryProvider`.
  - The widget depends on BatterySource only. BatteryKit depends on it and keeps everything
    else under its current name.
  - With MemberImportVisibility (WP-1), only the files that name those types need the new
    import: `App/BatteryPulseApp.swift`, `App/DemoController.swift`, `bpulse/main.swift`, the
    widget, and `BatteryMonitorTests`/`AccessoryMonitorTests`. That is about 6 files instead of
    about 21.
  - Don't use `@_exported` (underscored).
- **Gate.**
  - After SZ-02/SZ-06, adopt only if the widget link map attributes **≥ 100 KB** of `__text` to
    the types that would leave. ≥ 50 KB is too little for a new target.
  - Or adopt if `-why_live` shows `HMACDeviceKeyDeriver` keeps CryptoKit and the maintainer wants
    CryptoKit out of the widget.
- **Extra checks.**
  - `ci.yml`'s `xcodebuild build -scheme BatteryKit -destination iOS` step still builds
    BatteryMonitor; with the inverted split it automatically builds the lower target too.
  - If K-04 lands first, its notify helper must be `package`, or live in the lower target,
    because MacAccessoryProvider stays in BatteryKit.
  - The bpulse golden outputs stay byte-identical, and a widget smoke test runs on the M5.

### K-04 Duplicated notify(3) loop and IOPS walk: keep-modified (P3)

- **Confirmed.**
  - `MacBatteryProvider.swift:77-89` and `MacAccessoryProvider.swift:55-66` hold the same
    register/cancel loop.
  - `:139-153` and `:45-49` hold the same IOPS list/description walk.
  - `:148` compares the literal `"Type" == "InternalBattery"`.
  - A failed `notify_register_dispatch` is silently dropped (`status == 0` filter).
- **Modified.**
  - The helper `observeNotifyKeys(_:handler:) -> @Sendable () -> Void` goes next to
    `observeNotifications` in `SystemNotifications.swift`; WP-2 is already editing that function
    for SW-06. A `powerSourceDescriptions(in:) -> [[String: Any]]` helper goes alongside.
  - Use `kIOPSTypeKey`/`kIOPSInternalBatteryType`. They are public IOPSKeys.h string macros and
    import as `String`.
  - Log a nonzero registration status through SW-12's `iokit`/`accessory` category. A failed
    registration today means "never refreshes", and nothing says so.
  - **Ownership.** WP-2 adds the helpers and adopts them in MacBatteryProvider. WP-7 adopts them
    in MacAccessoryProvider in a last commit, rebased on WP-2. That is a new cross-package
    dependency: add it to the playbook's list.
  - Add the twin test `MacBatteryProviderTests.observationCancels` (macOS CI).
  - Expect about −15 to −25 lines.
- `bpulse --json`/`--accessories --json` stay byte-identical. The filter and the dictionaries
  don't change.

### K-05 `USBDeviceWatcher` doesn't need `@unchecked`: keep (inside SW-06, WP-7)

- **Confirmed by E-K3.**
  - The only stored instance property is `let queue: DispatchQueue`, and the statics are `Int`
    and `ClosedRange<Int>`. Plain `Sendable` compiles in Swift 6 mode.
  - `Watch` holds queue-confined `var`s and is captured in `@Sendable` closures, so its
    `@unchecked` is justified. Keep it with its comment.
  - `NSLock.withLock` compiles in all four `MobileDeviceSink` methods, including the early
    `return` in `receive`.
- **Effect.** SW-R6's count after SW-06 + K-05 is 4: `MobileDeviceSink`, `MobileDeviceLibrary`,
  `AppearanceVariants`, `Watch`. Update SW-R6's target text ("5 or fewer" becomes "4"). This
  settles the playbook's open "judge `USBDeviceWatcher` and `Watch`" item.
- Confirm on macOS CI that the build has 0 warnings: Darwin's `DispatchQueue` is Sendable.

### K-15 Silent `try?` around device storage: keep-modified (P2, as SW-12's site list)

- **Confirmed.** `IDeviceMonitor.swift:153, 259, 270, 568, 571, 572, 597` all use `try?`.
  `forget` and `clearHistory` are user actions that can fail without a trace.
- **Not a separate item.** It is the concrete `device` site list of WP-7's existing SW-12 (P2).
  Log the error's type and case public, its description, paths and keys private. Keep "carry
  on".
- **The DeviceStore half (`DeviceStore.swift:105-113`) is real but marginal.**
  - When the move-aside throws, `isReadOnly` stays false. A later save could then overwrite the
    undecodable `devices.json`.
  - In practice a folder that refuses the move also refuses the atomic save's rename. Only an
    undeletable `devices.unreadable.json` separates the two.
  - Hand it to the core verifier as a P3 one-liner: `isReadOnly = true` before rethrowing.
- **Measure.** `chmod 500` on the Devices folder, then `log stream` for category `device` shows
  the failure with no UDID or path in clear text.

### K-06 Follow-up reads after leaving Demo Mode: reject

- **Accurate but not worth code.**
  - Demo Mode is a developer path. Exiting it costs at most 5 extra reads, once, about tens of
    ms of CPU in total, which can't be measured in energy.
- **And it can lose function.**
  - The device's notifications pause during Demo Mode (`BatteryMonitor.swift:53-61`). If the
    adapter was plugged in or out meanwhile, the exit refresh is the first to see it. The
    follow-ups are then exactly the catch-up reads the 0.4 plug-in logic relies on ("the OS …
    take[s] up to a minute to catch up").
  - Suppressing follow-ups on every override swap drops them in that case.

### K-07 Stale comments: keep-modified (P3, riders)

- **Confirmed.**
  - `SMCBattery.keys` has 16 entries (1 + 3 + 4 + 4 + 4), not "a dozen"
    (`SMCClient.swift:10-11`). The 3–8 ms is 16 × 0.2–0.5 ms, derived rather than measured.
  - `BlockingWork`'s "(the CLI)" (`IDeviceTransport.swift:309`) is outdated since
    `IDeviceMonitor` became a caller.
- **Modified.** No separate item.
  - The `SMCClient` and `MacBatteryProvider` docs change in the E4a commit.
  - The `BlockingWork` doc changes in WP-7's SW-06 commit, which rewrites that type.
  - Drop the DocC measurement; no symbol links change.

### K-08 `openConnection` loop and the per-key catch-all: keep-modified (P3)

- **Reject the `0x85 notReadable` → `missing` change.**
  - No capture shows 0x85, and the SMC result codes have no documented semantics.
  - If 0x85 is transient on some Mac, for example while the SMC is busy around sleep, marking
    `B0AV`/`B0AC` missing for the session would freeze live power until relaunch. That is a
    functionality risk for a retry that costs about 0.3 ms.
  - `info.isReadable` already handles keys whose attributes say "not readable"
    (`SMCClient.swift:76`).
- **Keep the logging.** Log the remaining catch-all (`SMCClient.swift:68`) once per key per
  session under SW-12's `smc` category, with the key and result code public. That is how a
  0x85 would ever be seen. It belongs to WP-2's existing SW-12.
- **The one-pass `name(of:)` loop is optional readability.** `openConnection` runs once per
  process, or after a lost connection, so it has no cost effect.

### K-09 `RTLD_NOLOAD | RTLD_FIRST` for the IOKit handle: keep (P3, with SEC-09's flags)

- **Confirmed.** `MacAccessoryProvider.swift:35` uses `RTLD_NOW` only, and the "already loaded"
  promise lives in a comment.
- **What the flags do.**
  - IOKit is always loaded: BatteryKit links it, and MacBatteryProvider calls it. So
    `RTLD_NOLOAD` turns the comment into a guarantee.
  - `IOPSCopyPowerSourcesByType` is exported by IOKit itself, so `RTLD_FIRST` only narrows the
    lookup.
- **Cost and risk.** No added lines. A nil handle keeps today's "unavailable" path, which
  `MacAccessoryProviderTests.readReturnsAReading` would catch on CI.
- **Do it in the same commit as SEC-09's `RTLD_LOCAL | RTLD_FIRST` for MobileDevice,** so both
  dlopen sites follow one rule.

### K-10 Cancellable deadline timers: reject

- **`asyncAfter` already has the proposed leeway.** libdispatch's `_dispatch_after` sets a
  leeway of delta/10, clamped between 1 ms and 60 s, and implements itself with a dispatch
  timer source. The proposal adds only cancellation.
- **The saving is too small to measure.** It is a few µs-long wake-ups per 5 minutes, and they
  are already coalescable. The proposed `powermetrics` check can't tell one of them from the
  background.
- **It adds code and risk on every path.** Each path needs create, set handler, resume and
  cancel; cancelling a suspended source crashes, and a capture can form a retain cycle.
- EN-2 deliberately exempts these timers.

### K-11 The attach-events loop outlives a deallocated monitor: reject

- **No functional effect.**
  - The monitor is the process-lifetime `AppDevices.monitor` (`AppDevices.swift:13`).
  - `setEnabled(false)` already cancels `attachTask` (`IDeviceMonitor.swift:173-174`). That
    ends the stream, whose `onTermination` runs `Watch.stop()`.
- **The premise is wrong.** Tests use `FakeAttachEvents`, so no IOKit port is ever registered
  there.
- **The fix doesn't fix it.** `guard let self` would end the loop only on the next USB event
  after deallocation. A real fix would be an isolated deinit, for a case that can't happen.

### K-12 System-state-only reads and `io_service_t` reuse: reject

- **Service reuse has nothing to serve.** Under E4b, `.live` reads touch no registry at all; they
  re-read the live SMC keys over cached dictionaries. Reusing the `io_service_t` would also need
  termination handling.
- **The system-state scope saves too little.** Low Power Mode toggles and thermal-state
  transitions are a handful per hour at most, each one full read of a few ms.
- **And it adds risk.** A third read scope adds a merge path to E4b, which the research already
  rates medium risk ("the snapshot mixes values of different ages"). The gate can't change the
  verdict.

### K-13 Small idioms: keep-modified (P3, riders only)

- **Keep, as riders in commits that already touch the files.**
  - `count(where:)` at `IDeviceTransport.swift:171` (WP-7, SW-06 commit).
  - The default RNG `UInt8.random(in: .min ... .max)` at `IDeviceMonitor.swift:401-402` (WP-7).
    `DeviceStore.swift:65-66` has the same pattern; that one goes to the core verifier.
  - The test `Counter` over `Mutex<Int>` (`BatteryMonitorTests.swift:34-39`, WP-2). Also convert
    `LockedValue` (`IDeviceReaderTests.swift:275`, WP-7) the same way, or replace `Counter` with
    `LockedValue<Int>`, so the test target has one locked-box helper instead of two.
- **Reject caching the parsed Ed25519 key** (`UpdateSignature.swift:25-29`).
  - The key is verified once per update install, in microseconds.
  - Storing `Data` keeps the verifier checked-`Sendable` without relying on the SDK's
    `Sendable` annotation for `Curve25519.Signing.PublicKey`.
  - SEC-05 (WP-6) reshapes the type into a key list anyway.

### K-14 Timing-based monitor tests: keep-modified (P3, inside E3/C1)

- **Not confirmed as flaky.** E-K2 gave 0 of 60 failures under 4× CPU oversubscription.
- **Partly right about the AccessoryMonitor tests.** Their positive asserts poll with `wait {}`.
  Only the negative "no extra read" asserts after a 100 ms sleep are weak: a late read would
  still pass them.
- **Modified.**
  - The three BatteryMonitor tests are already covered by WP-2's E3 (injected `Clock`) and C1.
    Convert them there; no separate item.
  - Inject a clock into AccessoryMonitor only if E3 produces one shared coalescer type that both
    monitors use. That is one way to coalesce, which EN-3 already points at ("the way
    `AccessoryMonitor.scheduleRead()` already does"). Otherwise leave AccessoryMonitor's
    production code alone: a new clock parameter only for stronger negative asserts isn't worth
    it.
  - Drop the "under 1 s wall time" criterion. SW-R15 asserts work counts, not time.

## Notes for the playbook

- **SW-R6 target:** 4 `@unchecked Sendable` in Sources after SW-06 + K-05.
- **New cross-package dependency (K-04):** WP-7's MacAccessoryProvider adoption needs WP-2's
  helper commit.
- **SZ-14 premise:** `HMACDeviceKeyDeriver: DeviceKeyDeriving` likely keeps CryptoKit referenced
  in the widget, so `-dead_strip_dylibs` alone won't drop it. K-03's gate covers this.
- **WP-8 additions:** `timeout-minutes` on all jobs (15 / 30 / 60).
- **Core verifier:** two one-liners in `DeviceStore.swift`: `isReadOnly` on a failed
  move-aside, and the default RNG.
