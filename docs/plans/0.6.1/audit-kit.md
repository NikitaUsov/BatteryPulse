# Audit "kit": Sources/BatteryKit and Tests/BatteryKitTests (base 6133b4f)

Read-only audit. I read every file in `Sources/BatteryKit` (2,965 lines in 21 files) and the
timing-relevant parts of `Tests/BatteryKitTests` (1,971 lines in 8 files), and checked them against
`v061/playbook.md` and CLAUDE.md.

The playbook already covers these items, so they are not repeated here:
- E3: coalesce notifications.
- E3b: drop the `timeremaining` key.
- E4a: two SMC key tiers.
- E4b: registry reuse.
- E7: tolerance at `BatteryMonitor.swift:109`.
- E8 and E17: freshness.
- E20: off-main reads.
- SW-06: `ResumeOnce` and `IDeviceListBuilder` to `Mutex`; `UncheckedSendable`.
- SW-07: the SMC `Port`.
- SW-08: task names.
- SW-12: logging categories.
- SW-13 Kit: strict memory safety.
- SEC-09: `RTLD_FIRST` and the version for MobileDevice.
- SEC-10: an out-of-process helper.
- SEC-11: depth limit.
- SZ-02: `_main`-only exports.

Where a finding below extends one of these items, it says so.

Everything below is new, or makes a playbook item concrete with exact lines. IDs are `K-nn`.
"Owner" is the playbook work package whose files the change touches (§3.2).

Verdict in one line: BatteryKit is careful code. The device transport is defensive and the
IOKit/SMC calls release what they take. These are the substantive gaps:
- two uses of wall-clock time to measure elapsed time (K-01);
- async deadline tests that can hang CI for 6 h (K-02);
- protocol conformances that keep the whole device, demo and CryptoKit stack in the widget even
  after SZ-02 (K-03);
- duplicated IOKit plumbing (K-04).

---

## P2

### K-01 [bug] Wall-clock `Date()` measures elapsed time in two places
- **Where:**
  - `Sources/BatteryKit/MacBatteryProvider.swift:30, 56, 58`, the SMC cache:
    `Date().timeIntervalSince(smcCache.date) < Self.smcInterval`.
  - `Sources/BatteryKit/MobileDevice/MobileDeviceTransport.swift:173-193`, `waitForDevices`: `start`,
    `lastChange` and `now` are all `Date()`.
- **Failure:**
  - If the system clock is set back by Δ, the elapsed interval is negative.
  - (a) The SMC cache counts as fresh for Δ. `B0AV` and `B0AC` (the live power and current that
    the menu bar power item and the Power page show; `MacPowerParser` prefers them) freeze for Δ,
    while the registry values keep moving.
  - (b) The discovery loop never reaches `discoveryWindow` or `settleTime`, so it spins at 10 Hz on
    the shared MobileDevice queue for Δ.
    - Every caller times out (30 s list, 60 s capture), and `IDeviceMonitor` stalls.
    - The user's Check Again then queues behind the spinning loop and times out too, until Δ has
      passed.
  - A forward jump ends discovery at once, so Wi-Fi devices can be missing from that list.
  - Δ is small for NTP steps and hours for a manual date change.
- **Change:**
  - (a) Fold this into E4a (WP-2 rewrites this cache into two tiers anyway). Keep
    `ContinuousClock.Instant` timestamps, make `smcInterval` (and E4a's 60 s tier) a `Duration`, and
    inject `now: () -> ContinuousClock.Instant` (default `ContinuousClock.now`) so the policy is
    testable.
  - (b) In `waitForDevices`, use `let clock = ContinuousClock()`, `let start = clock.now`, and the
    `.duration(to:)` comparisons against `.seconds(MobileDeviceTransport.discoveryWindow)` and so on.
  - Put the stop decision in a pure function in `IDeviceTransport.swift`, which builds on Linux, so it
    can be unit tested:
    `static func discoveryEnded(elapsed: Duration, quiet: Duration, count: Int, sawWanted: Bool?) -> Bool`.
  - `IDeviceMonitorClock` stays Date-based on purpose: its schedule comes from persisted dates, and it
    is recomputed on every `pump()`.
- **Measure:**
  - Linux unit tests for the pure stop function: a negative wall-clock delta can't occur by
    construction, and the stop happens at 3 s with no devices, and at settle and at the wanted grace.
  - For the E4a cache tests with the injected `now`: the cache expires after 2 s even when a
    "wall clock" fake goes backwards.
  - On the M5, with the Power page open, `sudo date` back by 1 h: power keeps updating every poll.
    Then `bpulse --devices` still returns in about 1–3 s.
- **Risk:** none. Behaviour is identical while the clock is monotonic.
- **Owner:** WP-2 (a), WP-7 (b).
- **Rule:** EN-5 (freshness is measured, never `snapshot.timestamp`), extended to monotonic time.

### K-02 [bug] Async deadline and timer tests have no `.timeLimit`, and CI has no job timeout
- **Where:**
  - `Tests/BatteryKitTests/IDeviceReaderTests.swift:298` (`IDeviceListingTests`) and `:432`
    (`BlockingWorkTests`);
  - `Tests/BatteryKitTests/BatteryMonitorTests.swift:51`;
  - `Tests/BatteryKitTests/AccessoryMonitorTests.swift:50`.
  - Only `IDeviceMonitorTests.swift:346` has `.timeLimit(.minutes(1))`.
  - `.github/workflows/ci.yml` has no `timeout-minutes`, so GitHub's default of 360 minutes applies.
- **Failure:** a regression in `BlockingWork.run` or `IDeviceListBuilder.run` makes the
  continuation never resume. For example:
  - a lost `asyncAfter`;
  - a `take()` that returns `nil` twice;
  - the stuck link in `aStuckIdentityReadCostsTheRestTheirNamesNotTheList`, whose gate is never
    signalled.

  `swift test` then hangs. On the macOS runner that costs up to 6 h of minutes before anything
  reports. The wall-clock `< 5` checks at `:369` and `:454` run only after the await returns, so they
  never fire on a hang.
- **Change:**
  - Add `.timeLimit(.minutes(1))` to those four suites.
  - Keep the `< 5` bounds, or drop them: the time limit is the real guard, and SW-R15 says timing
    isn't asserted.
  - WP-8: `timeout-minutes: 30` on both CI jobs, and on the release job something like
    `timeout-minutes: 60`.
- **Measure:** locally, comment out `IDeviceTransport.swift:317-319`. `BlockingWorkTests` must then
  fail after 1 min instead of hanging. Restore the line.
- **Risk:** none. The slowest of these tests takes well under 1 s.
- **Owner:** WP-2 (BatteryMonitorTests), WP-7 (the others), WP-8 (ci.yml).
- **Rule:** SW-R15 (`.timeLimit` on timer tests).

### K-03 [size] Conformance records keep the device, demo and CryptoKit code in the widget even after SZ-02 (gated)
- **Where:**
  - The widget uses exactly one BatteryKit symbol: `MacBatteryProvider(readsSMC: false)`
    (`Sources/BatteryPulseWidget/BatteryPulseWidget.swift:61`).
  - It links all of BatteryKit (`Package.swift:25-27`).
  - Dead stripping keeps protocol conformance records (`__swift5_proto`; size research SZ-02
    "Expected", swift research SW-17 caveat). Each record roots its witness table, and the table roots
    the witness methods and everything they call. These conformances stay:
    - `MobileDeviceTransport: IDeviceTransport` (`MobileDeviceTransport.swift:16`). It keeps
      `MobileDeviceDiscovery`, `MobileDeviceLibrary.load`, `IDeviceReader`, `IDeviceListBuilder`,
      `BlockingWork` and BatteryCore's `DiagnosticsRelay`.
    - `MobileDeviceLink: IDeviceLink` (`:227`).
    - `USBDeviceWatcher: IDeviceAttachEvents` (`USBDeviceWatcher.swift:13`), with its IOKit
      matching code.
    - `HMACDeviceKeyDeriver: DeviceKeyDeriving` (`DeviceKeys.swift:10`). Its witness calls
      `HMAC<SHA256>`, so **CryptoKit stays loaded in the widget**. This corrects the size research's
      expectation that "after SZ-02 the widget should no longer reference CryptoKit".
    - `DemoBatteryProvider: BatteryProvider` (`DemoBatteryProvider.swift:6`). It keeps
      `DemoBattery.reading(at:gaugeUpdatedAt:)` and the M5-style demo dictionaries; the size research
      lists `DemoBattery` among the widget's dead weight.
    - `DemoAccessoryProvider` and `MacAccessoryProvider: AccessoryProvider`, which keep
      `DemoAccessories.sources`.
- **Change (only if the gate holds):**
  - Move the code the widget doesn't need into a new library target, `BatteryServices`, which depends
    on BatteryCore and BatteryKit. It takes:
    - `BatteryMonitor`, `AccessoryMonitor`, `AccessoryProvider`, `MacAccessoryProvider`,
      `DemoAccessoryProvider` and `DemoBatteryProvider`;
    - `IDeviceTransport.swift`, `IDeviceMonitor.swift`, `DeviceKeys.swift` and `MobileDevice/*`;
    - `UpdateSignature.swift`.
  - BatteryKit keeps the read path: `BatteryProvider`/`BatteryObservation`, `MacBatteryProvider`,
    `SMCClient`, `SystemNotifications` and `IOSBatteryProvider`.
  - The app and `bpulse` add the dependency. The widget doesn't.
  - Files need explicit `import BatteryServices` (MemberImportVisibility, SW-R3). That is the 19
    app files listed by `grep -rln "import BatteryKit" Sources/BatteryPulseApp`, plus
    `bpulse/main.swift` and `Record.swift`.
  - The tests move to `@testable import BatteryServices`.
  - Cross-module internals:
    - `observeNotifications`, `systemStateNotifications` and `applySystemState` are used only by
      `MacBatteryProvider` and `IOSBatteryProvider`, so they stay in BatteryKit.
    - `IDeviceConnection.sortOrder` moves together with its users.
    - So no `internal` → `public` change is needed, which SW-R17 requires.
  - Do not name the target after a framework.
- **Gate:** after SZ-02 and SZ-06, the widget's release link map attributes **≥ 50 KB** to the moved
  types. Or `dyld_info -dependents` of the widget still lists CryptoKit. Or `-why_live` on
  `$s10BatteryKit21MobileDeviceTransportC7capture8deviceID…` in the widget shows the conformance
  record as the root.
- **Measure:**
  - Widget `__text` and `__swift5_*` sizes before and after (size report).
  - `dyld_info -dependents` loses CryptoKit, `otool -L` likewise, and the widget's launch time in
    Instruments App Launch is no worse.
  - All tests green, `bpulse` golden outputs byte-identical (§2.6), and the widget smoke test.
- **Risk:** low to medium.
  - It is a pure move, with no deletion (DC-4, DC-6).
  - The risks are missed imports on Darwin-only files (only macOS CI sees them) and test target
    wiring.
- **Owner:** Phase C. It touches `Package.swift`, so it goes after WP-8 and before WP-11's maps,
  which then attribute correctly.
- **Rule:** SZ-02, SZ-06, DC-4.

### K-04 [readability] The notify(3) registration and the IOPS list walk are copied between the two providers
- **Where:**
  - notify(3) registration:
    - `MacBatteryProvider.swift:77-89`;
    - `MacAccessoryProvider.swift:55-66`, which says "notify(3), as in MacBatteryProvider";
    - both `notify_register_dispatch(name, &token, .main)` with `MainActor.assumeIsolated`, a token
      array, and `notify_cancel` in the observation.
  - IOPS list walk:
    - `MacBatteryProvider.swift:139-153`;
    - `MacAccessoryProvider.swift:45-49`, which says "The same calls as
      MacBatteryProvider.internalBatteryDescription".
  - Literal keys: `MacBatteryProvider.swift:148` compares the literals `"Type"` and
    `"InternalBattery"`.
- **Change:**
  - In `SystemNotifications.swift`, under `#if os(macOS)`, add
    `@MainActor func observeNotifyKeys(_ names: [String], handler: @escaping @MainActor @Sendable () -> Void) -> @Sendable () -> Void`
    and use it in both providers.
  - Add one `static func powerSourceDescriptions(in blob: CFTypeRef) -> [[String: Any]]`, for example
    in `MacBatteryProvider`. Both call sites filter or convert its result.
  - Use the public `kIOPSTypeKey` and `kIOPSInternalBatteryType` constants from `IOPSKeys.h`.
  - No behaviour change. Optionally, log a `status != 0` from `notify_register_dispatch` in SW-12's
    `iokit` and `accessory` categories; today a failed registration silently means "never refreshes".
- **Measure:**
  - On macOS CI, `MacAccessoryProviderTests` stays green.
  - Add the twin `MacBatteryProviderTests.observationCancels` (cancel twice; no crash).
  - `bpulse --json` and `--accessories --json` byte-identical on the M5.
  - About −25 lines.
- **Risk:** none.
- **Owner:** WP-2 lands the helper (it owns `SystemNotifications.swift` and `MacBatteryProvider`).
  WP-7 switches `MacAccessoryProvider` after rebasing.
- **Rule:** CLAUDE.md (one way to do a thing); native constants.

### K-05 [native] `USBDeviceWatcher` can be checked `Sendable`; `Watch` and `MobileDeviceSink` keep `@unchecked`
- **Where:**
  - `MobileDevice/USBDeviceWatcher.swift:13-15`. The only stored property is
    `private let queue = DispatchQueue(...)`. `DispatchQueue` is `Sendable`, and the statics don't
    count, so `@unchecked` isn't needed.
  - `Watch` (`:70`) has queue-confined mutable IOKit state that is touched from IOKit callbacks on
    that queue. A `Mutex` would add nothing but lock traffic.
  - `MobileDeviceSink` (`MobileDeviceTransport.swift:80-122`): SW-06 measured that `Mutex` doesn't
    compile.
- **Change:** this settles the playbook's open "judge `USBDeviceWatcher` and `Watch`" item for WP-7.
  - `final class USBDeviceWatcher: IDeviceAttachEvents` with no `@unchecked` (Sendable is inherited
    from the protocol). Delete the comment at `:14-15`.
  - Keep `Watch` `@unchecked Sendable` and its comment.
  - In `MobileDeviceSink`, replace the four `lock.lock(); defer { lock.unlock() }` pairs
    (`:89-112`) with `lock.withLock { … }`.
  - The SW-R6 target count becomes: `MobileDeviceSink`, `MobileDeviceLibrary`, `AppearanceVariants`
    and `Watch`, which is 4.
- **Measure:**
  - The macOS CI build has 0 warnings with the SW-R3 features on.
  - `grep -rn "@unchecked Sendable" Sources` drops by one in this file.
  - `bpulse --devices` on the M5 lists a device plugged in during the run.
- **Risk:** none.
- **Owner:** WP-7.
- **Rule:** SW-R6.

### K-15 [bug] Seven silent `try?` in IDeviceMonitor hide failed disk writes
- **Where:** `IDeviceMonitor.swift:153` (`store.load()`), `:259` (`forget`), `:270`
  (`clearHistory`), `:568` (`save`), `:571-572` (`history.record`) and `:597` (`save`).
  - The other `try?` in BatteryKit are fine: `Task.sleep` at `BatteryMonitor.swift:109, 136` and
    `AccessoryMonitor.swift:90`, and key validation at `UpdateSignature.swift:16`.
  - `UpdateSignature.swift:27` can't fail after `init`; see K-13.
- **Failure:**
  - A full disk or a permissions problem means devices are silently not remembered and history isn't
    recorded, with nothing in the log.
  - Cross-area note for the core audit: `DeviceStore.load()` (`BatteryCore/DeviceStore.swift:104-111`)
    can throw from its move-aside path (`removeItem`/`moveItem`) without setting `isReadOnly`. The
    monitor's `?? []` then lets the next successful read `save` over the undecodable
    `devices.json`. Setting `isReadOnly = true` before that rethrow fixes it.
- **Change:**
  - `do { … } catch { Diagnostics.device.error("… \(String(describing: type(of: error)), privacy: .public)") }`
    at each site. Paths and keys stay private (SW-R10, SEC-R9).
  - The behaviour (keep going) is unchanged.
- **Measure:**
  - On the M5, `chmod 500` the `Devices` folder, plug in an iPhone with reading on, then
    `log stream --predicate 'subsystem == "io.github.nikitausov.BatteryPulse" && category == "device"'`
    shows the failure, with no UDID or path in clear text.
  - The existing `IDeviceMonitorTests` stay green.
- **Risk:** none.
- **Owner:** WP-7.
- **Rule:** SW-R12, SW-R10.

---

## P3

### K-06 [energy] Switching providers (Demo Mode on or off) schedules five power-change follow-up reads
- **Where:** `BatteryMonitor.swift:55-62` → `refresh()` → `:98-100`.
- **Failure:** a provider swap whose connection state differs from the last reading counts as a
  plug event, so `scheduleFollowUps()` runs.
  - For example, the real Mac on the charger and a discharging demo scene.
  - Leaving Demo Mode then does five full IOKit+SMC reads of the real provider at 3, 8, 15, 30 and
    60 s.
  - The follow-ups exist because "the OS … and the registry take up to a minute to catch up" after a
    *physical* plug (`:34-36`). A swap is not one.
- **Change:**
  - Add a private `refresh(followingUpPowerChange: Bool)` and keep `refresh()` as `true`.
  - `setOverride` cancels `followUpTask` and calls `refresh(followingUpPowerChange: false)`.
  - A plug inside Demo Mode still comes through the observation handler with follow-ups, as today,
    and those are cheap.
- **Measure:** a new `BatteryMonitorTests` case. The provider is connected and the demo is not. With
  `powerChangeFollowUps = [.milliseconds(10)]`, call `setOverride(demo)` and then `setOverride(nil)`.
  After the follow-up window the real provider's `readCount` rose by exactly 1. With E3's injected
  clock, this is deterministic.
- **Risk:** none.
- **Owner:** WP-2.
- **Rule:** EN-5 (no unneeded forced reads).

### K-07 [readability] Comments that no longer match the code
- **`SMCClient.swift:10-11`:** "reading the dozen battery keys every few seconds on the main actor is
  cheap".
  - `SMCBattery.keys` has 16 keys, one round trip each.
  - The energy research measured 3–8 ms per read on the main thread and calls it "not small".
  - Rewrite this with E4a: "16 keys; polls read only `B0AV`/`B0AC` (E4a)".
- **`IDeviceTransport.swift:305-309`** (`BlockingWork`): "the deadline guarantees the caller (the
  CLI) never hangs".
  - Since 0.6.0 the main caller is the app's `IDeviceMonitor`, where a timed-out call also stalls
    automatic device work (`IDeviceMonitor.swift:46-49`).
  - Say "the caller (the CLI or `IDeviceMonitor`)".
- **`MacBatteryProvider.swift:18-19`** ("read at most every ``smcInterval`` seconds") and
  **`:25-27`**: update both with E4a's two tiers. The same commit as E4a.
- **Measure:** review in the E4a and WP-7 PRs. DocC (SW-21) shows no stale symbol links.
- **Risk:** none.
- **Owner:** WP-2, WP-7.

### K-08 [readability] `SMCClient`: the `openConnection` loop, and the catch-all on SMC result codes
- **Where:** `SMCClient.swift:149-160` calls `name(of:)` up to twice per service, in a three-branch
  `if`.
- **Change 1:** read the name once.
  ```swift
  while case let service = IOIteratorNext(iterator), service != 0 {
      if name(of: service) == "AppleSMCKeysEndpoint" {
          if chosen != 0 { IOObjectRelease(chosen) }
          chosen = service
          break
      }
      if chosen == 0 { chosen = service } else { IOObjectRelease(service) }
  }
  ```
- **Where:** `:68`. The catch-all `catch { return nil }` also swallows
  `.smc(key, result: SMCResult.notReadable.rawValue)` (0x85), which is as permanent as `.unreadable`.
- **Change 2:** add `catch .smc(_, let result) where result == SMCResult.notReadable.rawValue` to the
  `missing.insert` branch. Log the remaining catch-all in SW-12's `smc` category, once per key per
  session (the four-char code and the result code are public).
- **Measure:**
  - On the M5, `bpulse --smc` and `bpulse --json` are byte-identical.
  - The E1 `smc.*` signposts show no change in round trips unless a key returns 0x85. Any such key is
    then visible in the log.
- **Risk:** none. Errors that really are transient (`commCollision`, `timeout`) still retry.
- **Owner:** WP-2.

### K-09 [security] `MacAccessoryProvider` should say in code that it only borrows the loaded IOKit
- **Where:** `MacAccessoryProvider.swift:35`, `dlopen(Self.ioKitPath, RTLD_NOW)`. The comment at
  `:28-29` says "IOKit is linked already … so this only returns a handle to the loaded image".
- **Change:** use `RTLD_NOW | RTLD_NOLOAD | RTLD_FIRST`.
  - `RTLD_NOLOAD` guarantees that nothing is ever loaded from that path. If the image isn't
    there, the result is `nil`, so accessories show as unavailable, which is the existing fallback.
  - `RTLD_FIRST` limits `dlsym` to IOKit itself. This is the same reasoning SEC-09 applies to
    MobileDevice.
- **Measure:**
  - On macOS CI, `MacAccessoryProviderTests.readReturnsAReading` stays green, which proves the
    symbol still resolves.
  - `bpulse --accessories` on the M5 is unchanged.
- **Risk:** none.
- **Owner:** WP-7.
- **Rule:** SEC-R10, SEC-09.

### K-10 [energy] Deadline timers stay armed after the work finished
- **Where:** `IDeviceTransport.swift:317` (`BlockingWork.run`, 30 or 60 s), `:387` (the list's
  overall deadline) and `:425` (one per identity step, used by `bpulse --devices`).
- **Failure:** `asyncAfter` can't be cancelled. Every list and capture leaves a GCD timer that wakes
  a global-queue thread 30–60 s later only to find the continuation already taken. With a USB
  device, reading on and history on, that is about 1–2 wasted wake-ups per 5 min. A visible device
  page adds one a minute.
- **Change:**
  - Use `DispatchSource.makeTimerSource(queue: .global())` with
    `schedule(deadline: .now() + timeout, leeway: 10 %)`.
  - The work completion `cancel()`s it.
  - EN-2 already allows timers in this file.
  - Do it in the same commit as SW-06's `ResumeOnce` → `Mutex` change, which rewrites these lines
    anyway.
- **Measure:**
  - `BlockingWorkTests` and `IDeviceListingTests` stay green.
  - A new test: after a fast `BlockingWork.run`, the returned or injected deadline source
    `isCancelled`.
  - On the M5, Instruments System Trace or `powermetrics --samplers tasks` shows no BatteryPulse
    wake-up 60 s after a device read.
- **Risk:** low. The timer must be cancelled on every path; the `Mutex` take-once logic stays the
  single resume point.
- **Owner:** WP-7.
- **Rule:** EN-2 (exception file), EN-1 spirit.

### K-11 [bug] The USB watch outlives a deallocated `IDeviceMonitor`
- **Where:** `IDeviceMonitor.swift:640-644`:
  `for await change in attachEvents.changes() { self?.attachChanged(change) }`.
- **Failure:** with `self` gone, the loop keeps awaiting forever. The `AsyncStream` is never
  terminated, so `Watch.stop()` never runs, and the IOKit notification port and matching
  notifications stay registered.
  - The app keeps one monitor for its whole life, so today this only leaks per test in
    `IDeviceMonitorTests`.
  - It would leak for real if a monitor were ever recreated, for example when the device setting is
    rebuilt.
- **Change:**
  `for await change in attachEvents.changes() { guard let self else { return }; self.attachChanged(change) }`.
  - Returning ends the iteration and terminates the stream.
- **Measure:** a new `IDeviceMonitorTests` case.
  - A `FakeAttachEvents` records `onTermination`.
  - Enable a monitor, drop the last reference, and yield one change.
  - `onTermination` was called.
- **Risk:** none.
- **Owner:** WP-7.

### K-12 [energy] E4b additions: notifications that only change system state should not re-read IOKit
- **Where:**
  - `MacBatteryProvider.swift:71-72`: `NSProcessInfoPowerStateDidChange` and
    `thermalStateDidChangeNotification` reach the same handler as the power keys, so `refresh()` does
    a full IORegistry, IOPS, adapter, SMC and parse read.
  - Yet the only fields that can change are `isLowPowerModeEnabled` and `thermalState`
    (`SystemNotifications.swift:24-27`).
  - Thermal state flips between nominal and fair under sustained load.
- **Change:** when E4b lands (it caches the last dictionaries):
  - The two system-state names set `pendingScope = .systemState`.
  - The next `read()` re-applies `applySystemState()` to the cached reading, with no IOKit or SMC
    call.
  - Any power key in the same E3 window widens the scope to `.full`.
  - Also reuse the `AppleSmartBattery` `io_service_t` matched by the last `.full` read for `.live`
    reads, instead of `IOServiceGetMatchingService` per read (`:95`). Re-match on every `.full`.
- **Measure:**
  - E1 `registry` signposts per LPM toggle (System Settings → Battery) go from 1 to 0, and the
    snapshot shows the new LPM state.
  - A separate `registry.match` signpost shows what the cached service saves. Adopt it only if it is
    ≥ 0.2 ms p50.
- **Risk:** low. Demo Mode simulates LPM and thermal state in its own provider and is unaffected.
- **Owner:** WP-2.
- **Gate:** E4b itself.

### K-13 [readability] Small native idioms (one line each)
- **`IDeviceTransport.swift:171`:**
  `exchanges.filter { $0.reply != nil }.count * 100 + steps.filter(\.status.isSuccess).count`
  becomes `exchanges.count { $0.reply != nil } * 100 + steps.count(where: \.status.isSuccess)`
  (`Sequence.count(where:)`, Swift 6.0). Owner WP-7.
- **`IDeviceMonitor.swift:401-402`:** drop the `var generator = SystemRandomNumberGenerator()` and
  `using: &generator`. `UInt8.random(in:)` already uses the system generator. Owner WP-7.
- **`UpdateSignature.swift:9-30`:** the key is parsed in `init` and again in every `isValid`, behind a
  `try?` that can't fail.
  - When SEC-05 turns this into a key list (WP-6), store the parsed
    `[Curve25519.Signing.PublicKey]`, or keep `[Data]` if the macOS 27 SDK doesn't mark the key
    `Sendable`, and drop the second parse.
- **`Tests/BatteryKitTests/BatteryMonitorTests.swift:34-39`:** the test-only `Counter`
  (`@unchecked Sendable` with `NSLock`) becomes `final class Counter: Sendable` over
  `Mutex<Int>` (Synchronization; Linux too). Owner WP-2.
- **Measure:** builds and tests green on both jobs; no behaviour change.
- **Risk:** none.

### K-14 [bug] Make the remaining real-time monitor tests deterministic
- **Where:**
  - `BatteryMonitorTests.swift:147` (`liveRefreshPollsOnlyWhileEnabled`: `>= 3` reads in 200 ms with
    5 ms polls), `:181` (`pluggingInIsFollowedByExtraReads`: `== 5` after 150 ms with 10 and 20 ms
    follow-ups) and `:210`. All three can fail on a loaded macOS runner.
  - E3 (WP-2) already injects a `Clock` into `BatteryMonitor`. Convert these three tests in that PR.
  - `AccessoryMonitorTests.swift:117, 139, 193` sleep for 100 ms after a 10 ms coalescing delay.
    The negative asserts there can't catch a late read, and `AccessoryMonitor` gets no clock in the
    playbook.
- **Change:** give `AccessoryMonitor` the same injected `Clock` (default `ContinuousClock`) for
  `scheduleRead()` (`AccessoryMonitor.swift:85-95`), and drive those three tests with a test clock.
- **Measure:** run both suites 200 times with `swift test --filter 'BatteryMonitorTests|AccessoryMonitorTests'`
  in a loop on Linux under `stress -c $(nproc)`. 0 failures, and the wall time per suite is under 1 s.
- **Risk:** none.
- **Owner:** WP-2 (BatteryMonitor), WP-7 (AccessoryMonitor).
- **Rule:** SW-R15, C1.

---

## Checked and fine (no change)

- IOKit object lifetimes:
  - `MacBatteryProvider.childProperties` releases children and iterators.
  - `SMCClient` closes on connection loss and in `Port.deinit`.
  - `USBDeviceWatcher.drain` releases and re-arms.
  - `MobileDeviceLink` invalidates and then releases the service, and `deinit` closes it.
- The SMC stays read-only: `call` only sends `SMCParamBlock.Command` values through selector 2, as
  CLAUDE.md requires.
- MobileDevice:
  - every symbol is checked, and the handle is closed when one is missing;
  - `dlopen` uses constant absolute paths;
  - no pairing calls;
  - UDIDs live only in `IDeviceMonitor.udids` and in the in-memory captures;
  - the socket timeouts are set (`MobileDeviceTransport.swift:282-288`).
- `AccessoryMonitor.scheduleRead()` coalesces with a tolerance (the playbook's model for E3).
  `IDeviceMonitorClock.system` sleeps on `ContinuousClock` with a 10 % tolerance.
- Dead code:
  - Every public BatteryKit symbol has a caller in the app, `bpulse` or the widget, except
    test-only hooks with a comment (`IDeviceMonitor.waitUntilIdle`, DC-3) and
    `IOSBatteryProvider`.
  - `IOSBatteryProvider` is compiled out on macOS (0 bytes) and is part of the stated iOS target,
    so it stays.
  - Public members that only tests read (`BatteryMonitor.liveRefreshInterval`/`isRunning`,
    `IDeviceMonitor.lastListed`/`cannotRemember`) stay public under SW-R17.
- The `Task { @MainActor in … }` at `DemoBatteryProvider.swift:35` is a legitimate hop. The
  `onCancel` closure is `@Sendable` and may run from `BatteryObservation.deinit` off the main actor.
  The SW-R8 grep in `EnergyGuardTests`/review should allowlist it.
