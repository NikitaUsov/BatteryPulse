# 0.6.1 research (verified): energy and runtime efficiency of a menu bar app

Status: verified. This is an adversarial check of `research.md` in this folder, and it stands on its own.
Date: 2026-10-15. Code checked at commit `fb41ff5` (0.5.0 plus early 0.6 work). Line numbers may
move in 0.6.0.

Everything here uses Apple's or the Swift project's own tools and APIs. Third-party projects
appear only as evidence in the earlier notes (`scratchpad/energy-plan.txt`). Repo-facing text must
not name them.

Legend: **P0** = do first (it enables measuring), **P1** = in 0.6.1, **P2** = if time allows,
**P3** = optional or later. Effort **S** < half a day, **M** 1–2 days, **L** more.
**UNVERIFIED** = not confirmed for macOS 27 / Swift 6.4 / the M5.
Verdicts: KEEP, CORRECTED, DEMOTED, REJECTED, MERGED, NEW.

---

## 0. What verification changed

**Source facts that held up** (re-read in the cached pages, transcripts and source):
- The `Task.sleep` tolerance path (Swift `DispatchGlobalExecutor.cpp`) and `dispatch_after`'s
  default leeway (libdispatch `source.c:1373-1426`).
- Power Profiler is iPhone and iPad only.
- The WWDC26 quotes: 268 on signposts and Run Comparison, 222 on MetricKit, 277 on widget
  throttling, 267 that performance testing is XCTest-only. The WWDC25 226 quotes, and WWDC23's
  "two and five times faster" JSON decoder.
- The quotes from Apple's archived energy guide: App Nap, the "at least 10 percent" timer tolerance,
  and "Reduce CPU usage … Reduce I/O" at the serious thermal state.
- `NSBackgroundActivityScheduler`, the URLSession configuration pages,
  `systemPrefersReducedResourceUsage` (macOS 27.0) and `MetricManager` (macOS 27.0).
- GitHub's rule that only authorized conditional requests skip the rate limit.

**Corrected or added (important):**
1. **The SMC part of a read is not small.** `SMCClient.swift:10` says one call takes 0.2–0.5 ms
   (worst case about 11 ms on an M4 Max). `SMCBattery.keys` has **16 keys, one round trip each**
   (`SMC.swift:288`, `SMCClient.read(_:)`). The cache is 2 s, so every 10 s menu bar poll and every
   2 s window poll pays about 3–8 ms on the main thread for the SMC alone. The power figure needs
   only `B0AV` and `B0AC`. The research assumed the registry dominates the cost. That is unproven,
   and the SMC split is a cheap first step (new **E4a**).
2. **powerd sends the same change on two keys, and the public key already relays the
   kernel signal.** In the open-source PowerManagement-1846.0.25.0.1, powerd subscribes to
   `kIOPMMessageBatteryStatusHasChanged` on every battery (`pmconfigd/BatteryTimeRemaining.m:1000`,
   handler `:933`). Each message runs `kernelPowerSourcesDidChange`, which posts
   `com.apple.system.powersources.timeremaining` when percent or time changed (`:1741`) and then
   **always** posts `com.apple.system.powersources` (`:1770`).
   - BatteryPulse subscribes to both keys, so one battery update gives two full reads. That confirms
     E3.
   - The "any power source" key is already the public "registry has new data" signal, so E4's
     private-message spike is redundant (REJECTED).
   - Apple's public `IOPowerSources.h` also says the "any" key "posts … more frequently than the
     other notifications, and thus uses more energy" (new **E3b**).
3. **E8's freshness check was wrong.** `BatteryMonitor.snapshot` is reassigned only when something
   other than the timestamp changes (`BatteryMonitor.swift:96-97`). So `snapshot.timestamp` is the
   time of the last *change*, not of the last read. A `lastReadAt` is needed.
4. **E9 would break current behaviour.** Apple: "The nominal fire date is calculated by using the
   interval combined with the previous fire date or the time when the activity is started". With a
   6 h interval and the default ½-interval tolerance, the first automatic check moves from 20 s
   after launch to 3–9 h after it. The check would then open the Software Update window in the middle of the
   user's work, which is what `mayOpenWindow` exists to prevent. The saving is 4 wake-ups a day.
   **REJECTED for 0.6.1.**
5. **E10's `waitsForConnectivity` has a side effect.** `checkNow()` just waits for a running check
   (`UpdateChecker.swift:79-86`). Offline, the user's Check Now would hang until the resource
   timeout. The automatic request must be cancelled first. Also add `allowsExpensiveNetworkAccess
   = false`, as Apple's guidance says.
6. **E2 named the wrong entitlement.** "Debugging Tool" is `com.apple.security.cs.debugger`.
   `com.apple.security.get-task-allow` is "Get task allow". Apple: "a debugger can't get the task
   ports of processes that don't have the Get task allow entitlement".
7. **E11's "from memory" claim is now confirmed** by the current `ProcessInfo.ActivityOptions`
   reference. It lists `userInitiatedAllowingIdleSystemSleep`, and its example
   `NSActivityUserInitiated & ~NSActivitySuddenTerminationDisabled` implies `.userInitiated`
   includes both idle-sleep and sudden-termination disabling.
8. **E8: QoS and isolation.** A `Task(priority: .utility)` started in the `@MainActor`
   `HistoryRecorder` still runs its loop, and the IOKit read, on the main actor. Only the
   `HistoryStore` actor work runs at utility. Apple's E-core sentence is about *background* tasks.
   Utility is "a balance between responsiveness, performance, and energy efficiency".
9. **E20: wrong arithmetic.** 4 ms is a quarter of a 60 Hz frame (16.7 ms), not of a 120 Hz frame
   (8.3 ms).
10. **E22 / SW-09: missed semantics.** `Observations` runs its closure on the first `next()` and
    yields the *current* value (SE-0475, "Behavioral Notes"). Today's `withObservationTracking`
    consumers fire only on change. A naive port adds a widget reload, a history evaluation and a
    notifier evaluation at every launch.
11. **The measurement protocol lacked a real energy number.** Activity Monitor's Energy Impact and
    `top`'s `POWER` are unitless scores.
    - `proc_pid_rusage(pid, RUSAGE_INFO_V6)` gives the maintainer's own process `ri_energy_nj`,
      `ri_pkg_idle_wkups`, `ri_interrupt_wkups`, CPU time, `ri_instructions`,
      `ri_diskio_byteswritten` and `ri_phys_footprint` without root (`xnu-12377.1.9
      bsd/sys/resource.h:376-417`) (new **M1**).
    - For counting notifications, `pmset -g pslog` prints every power-source notify key with a
      timestamp (PowerManagement `pmset.m:601`, `:3504-3590`).
12. **Smaller corrections:**
    - E17: a third read at launch when the power item is shown (`MenuBarLabel`'s
      `onChange(initial: true)` → a new live-refresh request → `refresh()`).
    - E14: every snapshot change, including each poll, reaches `HistoryStore.record`, which stats
      the legacy file before the policy check.
    - E5: demoted to P2.
    - C2: demoted.
    - C5: rejected.
    - E12 and E16: rejected for 0.6.1.

---

## 1. Code map (checked against the code)

| Activity | Where | Cadence | What it does (verified) |
|---|---|---|---|
| Power-source events | `BatteryKit/MacBatteryProvider.swift:64-90` | OS-driven | `notify_register_dispatch` on `com.apple.system.powersources` and `…timeremaining`, plus `NSProcessInfoPowerStateDidChange` and `thermalStateDidChangeNotification` (`SystemNotifications.swift:51-54`). **Every callback calls `refresh()`**. powerd posts both keys in the same pass (§0.2), so one battery update means two full reads. |
| One read | `MacBatteryProvider.read()` `:38-52` | per event / poll | `IORegistryEntryCreateCFProperties` on AppleSmartBattery plus its children (the M5 fixtures hold 350–716 keys including IOPS, adapter and SMC; 24–46 KB as XML). `IOPSCopyPowerSourcesInfo`, `IOPSCopyExternalPowerAdapterDetails`, **16 SMC keys with one round trip each, cached 2 s** (`:54-60`). CF→Swift bridging, `PropertyValue`, parse, then two deep `==` on the raw dictionaries and the snapshot (`BatteryMonitor.isSameReading/isSameState`). All on the main actor. |
| Menu bar power item | `BatteryCore/MenuBarContent.swift:90` → `MenuBarLabel.swift:48-52` | every 10 s ± 2.5 s while "power" is shown | A full read to update a number derived from SMC `B0AV`×`B0AC` (`MacPowerParser.swift:187-189`). It does not stop while the display sleeps. |
| Popover / main / compact | `.liveRefresh(... every: .seconds(2))` (`PopoverView:94`, `MainView:124`, `CompactView:54`) | 2 s while visible | Full read. Stops when the window is occluded, including with the display asleep (`Motion.swift:194-211, 241-292`). |
| History recorder | `App/HistoryRecorder.swift:42-47` | 60 s, tolerance 15 s | Forces `monitor.refresh()`, then `HistoryStore.record` (sample) and `record(HistoryDay)`. On wake: one more forced read (`:33-40`). **Each snapshot change** (each poll included) also runs `recordNow(refreshing: false)` → `HistoryStore.record` → `migrateLegacySamples()` (a `fileExists` stat) before the policy check (`HistoryStore.swift:53-55`). |
| History view | `Main/HistoryView.swift:71-78, 111-136` | 60 s while visible, **no tolerance** | Re-reads and decodes every sample of the period: `readLines` decodes each line with `Data($0)`. One `JSONDecoder` per file. Points, spans and statistics are computed on the main actor. |
| Raw Data | `Main/DeveloperView.swift:100, 116-129` | each new `reading` | `.task(id: monitor.reading)` rebuilds the sections in a detached task. |
| Update check | `Updates/UpdateChecker.swift:66-75, 157-161` | 20 s after launch, then every 6 h, **no tolerance** | `URLSession.shared`, `.reloadIgnoringLocalCacheData`, timeout 20 s. |
| Update download | `Updates/UpdateInstaller.swift:195-206` | 200 ms poll during a download | A `Task.sleep` loop reads `DownloadWatcher`'s byte counts. There is no `ProcessInfo` activity around download, verify and swap (`run`, `:135-180`). |
| Widget reloads | `App/WidgetRefresher.swift:62-67`, `BatteryCore/BatteryPresentation.swift` (`WidgetReloadPolicy`) | state change, or ≥ 5 % and ≥ 30 min | `reloadTimelines(ofKind:)`. `reloadAllTimelines` runs only after a version change (`:40-57`). |
| Launch | `App/BatteryPulseApp.swift:22-53` | once | `monitor.start()` reads, and `HistoryRecorder.start()` reads again (`recordNow(refreshing: true)`). With the power item shown, `MenuBarLabel`'s initial live-refresh request reads a third time (`BatteryMonitor.setLiveRefreshInterval`, `:80-84`). |

Things already done right, to keep:
- notify(3) instead of polling, and `notify_cancel` instead of a leaking run-loop source.
- 25 % tolerance on the live poll and 15 s on the history tick.
- Occlusion-driven pause of UI polling and animation.
- Low Power Mode and `systemPrefersReducedResourceUsage` feed `MotionPolicy`.
- Append-only JSONL, one file per UTC day; `days.jsonl` rewritten at most hourly.
- The widget reads on its own, sandboxed and without the SMC.
- No power assertions, and no activity held while idle.

Note on App Nap: `Motion.swift:244` already says "the menu bar item keeps the whole app
visible to macOS, so app-level occlusion and App Nap never apply". `docs/ROADMAP.md:299` still
lists "Measure App Nap's effect on the minute timer" as open. Treat it as UNVERIFIED (§6).

---

## 2. Sources and key facts (checked)

Cached under `scratchpad/v061/energy/{docs,docs2,tr,src}` and
`scratchpad/research/oss/{PowerManagement,IOKitUser,xnu}`. All fetched or read 2026-10-15.

- **F1 — Power Profiler is not for the Mac.** "Power Profiler is available on iPhone with iOS 26 or
  later, and iPad with iPadOS 26 or later" (Xcode doc "Measuring your app's power use with Power
  Profiler"). WWDC26 258 and 268 add nothing for the Mac. On the Mac, use Instruments (Time
  Profiler, os_signpost, System Trace, Allocations, Leaks, App Launch, Filesystem Activity), the
  new **Swift executors** instrument ("Instruments 27 has a new Swift executors instrument. This
  instrument visualizes the Main Actor, the global concurrent executor…", WWDC26 268) and **Run
  Comparison** (WWDC26 268). On the command line: `proc_pid_rusage` (M1), Activity Monitor, `pmset`
  and `powermetrics` (root).
- **F2 — Tolerance reaches the kernel (CONFIRMED in source).**
  - With a tolerance, `swift_dispatchEnqueueWithDeadline` creates a `DISPATCH_SOURCE_TYPE_TIMER`
    with `leeway = tolerance`. Without one, it calls `dispatch_after_f` (`DispatchGlobalExecutor.cpp:288-339`).
  - `_dispatch_after_leeway` takes the calling thread's QoS: 10 % for BG/UT, 1/15 for DEF/IN,
    5 % for UI and above, clamped to [1 ms, 60 s] (`libdispatch source.c:1373-1426`). A main-actor
    6 h sleep without a tolerance can therefore slide by at most 60 s.
  - Apple: "set the tolerance to at least 10 percent of the interval for a repeating timer" (archive
    "Energy Efficiency Guide for Mac Apps", Timers).
  - UNVERIFIED: that the shipping macOS 27 libdispatch and Swift 6.4 runtime match the open-source
    `main`. The default clock of `Task.sleep(for:)` is `.continuous` (reference page).
- **F3 — App Nap.** It requires that the app "hasn't recently updated content in the visible
  portion of a window" and has no "IOKit power management or NSProcessInfo assertions". Apple: "Don't
  rely on App Nap to get your app to fully idle … suspend energy-intensive work as quickly as
  possible" (archive, App Nap). UNVERIFIED for a status-item-only app on macOS 27; see §1 note.
- **F4 — `NSBackgroundActivityScheduler`** (macOS 10.10+). Its uses include "Periodic content
  fetches", "Installation of updates" and "intervals of 10 minutes or more". Default tolerance is
  half the interval, default QoS is background. **The first fire is at the interval (± tolerance)
  after scheduling**: "The nominal fire date is calculated by using the interval combined with the
  previous fire date or the time when the activity is started". The block runs "on a serial
  background queue", and the system wraps it in `beginActivity`.
- **F5 — WidgetKit budget.** For a frequently viewed widget "a daily budget typically includes from
  40 to 70 refreshes"; entries "at least about 5 minutes apart"; reloads don't count while "the
  widget's containing app is in the foreground" ("Keeping a widget up to date"). WWDC26 277:
  "frequent reloads while your app is in the foreground might be throttled", and developer mode
  lifts "constraints like reload budgets". UNVERIFIED: developer mode on macOS.
- **F6 — `systemPrefersReducedResourceUsage`** (SwiftUI, macOS 27.0). "Defer or shrink non-essential
  background work"; "Avoid performing or scheduling expensive work in response to changes in this
  property". Outside a scene it "defaults to an app-wide aggregate value".
- **F7 — Low Power Mode** (`isLowPowerModeEnabled`, macOS 12+): the system pauses "discretionary
  and background activities"; "take appropriate steps to reduce activity in your app".
- **F8 — QoS on Apple silicon.** "the system is more likely to run **background** tasks on lower
  performance cores". Utility "offers a balance between responsiveness, performance, and energy
  efficiency" ("Tuning your code's performance for Apple silicon").
- **F9 — MetricKit** (`MetricManager`, macOS 27.0). Reports are delivered as `AsyncSequence`s.
  Metric reports cover "the previous 24 hours … at most once per day" plus breakdowns of "a few
  hours"; diagnostic reports arrive immediately; reports are `Codable` (MetricKit pages; WWDC26
  222). UNVERIFIED: delivery for an ad-hoc-signed app distributed outside the App Store.
- **F10 — Disk writes.** "Collecting small changes and performing them as a single write reduces
  the frequency, though it can also result in an increase in your app's memory use"; keep
  frequently changing and mostly static data in separate files; avoid unneeded atomic writes and
  `fsync` ("Reducing disk writes").
- **F11 — JSON.** Since macOS 14 Foundation's JSON coders are a Swift implementation, "between two
  and five times" faster in Apple's benchmarks (WWDC23 10164). JSON stays a sound history format.
- **F12 — Conditional requests.** A 304 skips GitHub's primary rate limit only "while correctly
  authorized with an `Authorization` header" (GitHub REST best practices). The check is
  unauthenticated, so ETags aren't worth code.
- **F13 — powerd relays the battery message (NEW).**
  - powerd: `IOServiceAddInterestNotification(…, battery, kIOGeneralInterest, ioregBatteryInterest…)`
    acts only on `kIOPMMessageBatteryStatusHasChanged` → `ioregBatteryProcess` →
    `kernelPowerSourcesDidChange`, which ends with `notify_post(kIOPSNotifyAnyPowerSource)`
    (`PowerManagement-1846.0.25.0.1 pmconfigd/BatteryTimeRemaining.m:883-1008, 1524-1770`).
  - The kernel side: `IOPMPowerSource::updateStatus()` "messageClients(kIOPMMessageBatteryStatusHasChanged)"
    (xnu `IOPMPowerSource.cpp:211-215`). IOPM.h calls the message "Private".
  - Conclusion: the public "any power source" key is the "registry has new data" signal, one hop
    later. UNVERIFIED that macOS 27's (closed) powerd still does this; measure (§4 item 7).
- **F14 — Apple's own advice on the notify keys (NEW).** Public `IOPowerSources.h`:
  - `kIOPSNotifyAnyPowerSource` "posts this notification more frequently than the other
    notifications, and thus uses more energy … please consider another notification that also fits
    your needs" (`kIOPSNotifyPowerSource`, `kIOPSNotifyTimeRemaining`).
  - `kIOPSNotifyTimeRemaining` also fires when the active power source changes.
  - Evidence: header text from apple-oss-distributions IOKitUser `ps.subproj/IOPowerSources.h:115-175`.
    The same text ships in the SDK header (UNVERIFIED against the macOS 27 SDK).
  - In powerd's source, every internal-battery `timeremaining` post happens inside
    `kernelPowerSourcesDidChange`, which then posts "any" (`:1741`, `:1770`; `:1396-1450` is
    called on the same path). The other `timeremaining` post (`:4886`) is for client-published
    power sources only (UPS/accessory process death).
- **F15 — Performance tests.** "UI automation and performance testing APIs are only available in
  XCTest" (WWDC26 267). SwiftPM with Swift Testing has no baselines, so budgets are explicit
  assertions or external numbers.
- **F16 — Per-process energy counters (NEW).** `rusage_info_v6` has `ri_user_time`,
  `ri_system_time`, `ri_pkg_idle_wkups`, `ri_interrupt_wkups`, `ri_phys_footprint`,
  `ri_diskio_byteswritten`, `ri_instructions`, `ri_cycles`, `ri_energy_nj` and `ri_penergy_nj`
  (xnu-12377.1.9 `bsd/sys/resource.h:376-417`). `proc_pid_rusage` needs the same effective uid
  (no root for the maintainer's own processes). Energy is a CLPC estimate. It is **0 in virtual
  machines** (`SOC_IS_VIRTUALIZED`, per `scratchpad/energy-plan.txt` claim 3). macOS 27 evidence
  exists only from a third-party tool (energy-plan); UNVERIFIED on the M5 until tried.
- **F17 — Entitlements for profiling (CORRECTED).** Debugging tool entitlement
  (`com.apple.security.cs.debugger`) page: "a debugger can't get the task ports of processes that
  don't have the Get task allow entitlement … Xcode automatically adds the Get task allow
  entitlement to apps that you build for debugging". Hardened Runtime protects against "process
  memory space tampering". The direct `get-task-allow` page did not resolve as JSON; cite the
  debugger page.
- **F18 — `ProcessInfo.ActivityOptions`** lists `userInitiated` ("exporting or downloading a
  user-specified file") and `userInitiatedAllowingIdleSystemSleep`. Its overview example
  `NSActivityUserInitiated & ~NSActivitySuddenTerminationDisabled` shows `.userInitiated` includes
  sudden-termination disabling; the existence of the "AllowingIdleSystemSleep" variant shows it
  includes idle-sleep disabling. `trackingEnabled` (macOS 13+) tracks an activity "using a
  signpost interval". The archive App Nap page: "the user has initiated a long-running operation
  that the user expects to complete 'now,' the system does not put your app in App Nap".
- **F19 — `Observations`** (SE-0475, Implemented in Swift 6.2): "The closure is not run immediately
  it is run asynchronously upon the first call to the iterator's `next` method". Values changed in
  one isolation are delivered as one transaction at the next suspension. Also SE-0469 `Task(name:)`
  (Swift 6.2) and SE-0472 `Task.immediate` (Swift 6.2).

---

## 3. Recommendations (verified)

### M1 — NEW: a real energy number, from `proc_pid_rusage` (P0, S)
- **Practice:** measure BatteryPulse's own energy, wake-ups and CPU time from the kernel's
  per-process counters, not from unitless scores.
- **Why:** F16. Activity Monitor's Energy Impact and `top`'s `POWER` have no unit. `powermetrics`
  needs root. `top -l 0` itself adds load (energy-plan note). WWDC25 226 advises capturing
  "multiple runs … and average the results".
- **How:** add a developer-only script, `scripts/rusage.swift <pid> <seconds>` (run with
  `swift scripts/rusage.swift`, like `sign-update.swift`; it is not a package target and doesn't
  ship). It calls `proc_pid_rusage(pid, RUSAGE_INFO_V6, …)` twice and prints the per-hour deltas
  of `ri_energy_nj` (mJ, plus the P-core share from `ri_penergy_nj`), `ri_pkg_idle_wkups`,
  `ri_interrupt_wkups`, `ri_user_time + ri_system_time` (converted from Mach ticks with
  `mach_timebase_info`), `ri_instructions` and `ri_diskio_byteswritten`, and the final
  `ri_phys_footprint`. Also sample `BatteryPulseWidget` when it runs.
- **Verify:** `sysctl kern.pervasive_energy` is non-zero on the M5. Two back-to-back idle runs
  agree within about 10 %.
- **Benefit:** before and after numbers in mJ/h and wake-ups/h, which every other item needs.
- **Risk:** none to the app. **Effort:** S. **Priority:** P0.

### E1 — KEEP: signpost the periodic work (P0, S)
- **Practice:** `OSSignposter` intervals in `.pointsOfInterest`.
- **Why:** `OSSignposter` reference (macOS 12+). WWDC26 268: "I set the category to points of
  interest, so that instruments will automatically surface this data". WWDC26 222 uses the Points
  of Interest instrument to validate states.
- **How:**
  - One signposter, subsystem `io.github.nikitausov.BatteryPulse` (the existing `Logger` subsystem).
  - Intervals: `read`, with sub-intervals `registry`, `children`, `iops`, `adapter`, `smc.power`,
    `smc.other` and `parse`; `refresh` with its trigger as metadata (`notify`, `poll`, `history`,
    `followUp`, `wake`, `launch`); `history.record`, `history.load`, `widget.reload` and
    `update.check`.
  - An event `menuBarReady`.
  - **Correction:** `BatteryMonitor` is in BatteryKit, which builds on Linux. Wrap the signposter in
    `#if canImport(os)`, or emit the `refresh` interval from Darwin-only code.
  - **Overlap:** the Swift research (`swift/research.md`, logging item 6) proposes the same
    intervals. Implement them once.
- **Verify:** Instruments: os_signpost + Time Profiler + Swift executors, attached to the E2 build.
  Per scenario (§4): `read` count, p50 and p95, and the share of `registry`, `smc.*` and `parse`.
- **Benefit:** it makes E3–E8, E13, E17 and E20 measurable. **Risk:** none.
- **Priority:** P0. Land it on 0.6.0 too, for a "before".

### E2 — CORRECTED: profile the real bundle with a profiling-only signature (P0, S)
- **Practice:** profile the packaged `.app`, not `swift run`.
- **Why:** the app is signed with `--options runtime` (`scripts/build-app.sh:134`). F17: without
  **Get task allow** (`com.apple.security.get-task-allow`; not "Debugging Tool"), tools that need
  the task port can't inspect the process. UNVERIFIED on macOS 27: exactly which tools refuse
  (`leaks`, `heap`, `vmmap`, `footprint`, Allocations attach). Time Profiler sampling usually works.
- **How:**
  - `PROFILING=1 scripts/build-app.sh` signs the app (not the widget) with a temporary
    entitlements file holding `get-task-allow = true` and names the outputs `…-profiling`.
  - Guard in `release.yml` and the CI packaging job, using the script's existing pattern:
    `E="$(codesign -d --entitlements - build/BatteryPulse.app 2>/dev/null)"; if grep -F get-task-allow <<<"$E"; then exit 1; fi`.
- **Verify:** `leaks BatteryPulse` works on the profiling build and is refused on the release build.
- **Risk:** shipping the entitlement by mistake; the guard covers it. **Priority:** P0.

### E3 — KEEP, evidence strengthened: one read per burst of notifications (P1, S)
- **Practice:** treat OS notifications as "something changed" and read once per burst.
- **Why:** F13 and F14. powerd posts `…timeremaining` and then `com.apple.system.powersources` in
  the same pass (`BatteryTimeRemaining.m:1741, 1770`). Both reach `refresh()`
  (`MacBatteryProvider.swift:78-84`), as do LPM and thermal changes.
  **Correction:** the second read in a burst usually produces an identical snapshot (the SMC cache
  is 2 s), so history and widget work is rarely duplicated. The saving is the second registry,
  IOPS and parse pass.
- **How:**
  - Add `BatteryMonitor.requestRefresh()`: when no read is pending, it schedules one after a short
    window (`Task.sleep(for: .milliseconds(150), tolerance: .milliseconds(100))`).
  - Point `observeChanges` at it. Keep `refresh()` for callers that need the value now.
  - The follow-ups (3–60 s apart) are not bursts; leave them.
  - Inject a `Clock` so C1 can test it on Linux.
- **Verify:** C1 ("N callbacks in one burst → 1 read"). On the M5, E1's `read` count per battery
  update against `pmset -g pslog` lines: about 2 → 1.
- **Benefit:** CPU and energy per battery update, which happens all day. **Risk:** a ≤ 250 ms delay
  in showing plug and unplug. **Priority:** P1.

### E3b — NEW: subscribe to fewer notify keys, per Apple's header (P2, S; measurement-gated)
- **Practice:** don't subscribe to two keys that carry the same event.
- **Why:** F14. For the internal battery, every `timeremaining` post is followed by an "any" post
  in the same powerd pass. "Any" is also the key that tracks registry changes (F13), which E4b
  needs. So keep "any" and drop `…timeremaining`. That halves notify wake-ups per update (E3 already
  removes the second read).
  - Keep the comment in `MacBatteryProvider.swift:62-63` accurate: `timeremaining` is what
    `IOPSNotificationCreateRunLoopSource` uses (IOKitUser `IOPowerSources.c:443`).
- **How:** remove `"com.apple.system.powersources.timeremaining"` from `powerSourceNotifications`,
  only after the check below.
- **Verify:** `pmset -g pslog` on the M5 for 2 h on battery and 1 h charging: every `timeremaining`
  line has an "any" line within ~10 ms. If not, keep both (E3 still applies).
- **Risk:** low; macOS 27's powerd is closed source. The 60 s history read is the backstop.
  **Priority:** P2.

### E4a — NEW (split from E4): read only the two live SMC keys on polls (P1, S)
- **Practice:** a poll reads what it exists for.
- **Why:** §0.1. Polls exist for `B0AV`/`B0AC` (`MenuBarContent.swift:86-91`,
  `MacPowerParser.swift:187-189`), but each one re-reads all 16 SMC keys, one round trip each at
  0.2–0.5 ms (`SMCClient.swift:10`). On macOS 27, cells and temperature come from the registry
  children first; the SMC is the second source (`MacPowerParser.swift:192-201`).
- **How:**
  - Split `SMCBattery.keys` into `liveKeys = ["B0AV", "B0AC"]` and the rest.
  - `MacBatteryProvider` re-reads `liveKeys` every 2 s as now, and the rest at most every 60 s, or
    when Raw Data or Power (cells, temperatures) is visible.
  - Raw Data keeps showing every key, with the age of the slower group noted if needed.
- **Verify:** E1 `smc.power` and `smc.other` durations; `read` p50 before and after (expect several
  ms less on the M5); M1 CPU and energy per hour in S2.
- **Benefit:** probably the cheapest large saving for "power in the menu bar" users. 8,640 polls a
  day × 14 fewer IOKit round trips.
- **Risk:** low. Tests for the merge of cached and fresh SMC groups go in BatteryCore.
  **Priority:** P1.

### E4b — CORRECTED: read the registry when it changes, not on every poll (P1–P2, M; measure first)
- **Practice:** don't rebuild the 350–716-key registry tree to update one number.
- **Why:** the registry has new data exactly when powerd relays the battery's status message
  (F13). That is the "any" key BatteryPulse already receives. A poll between two such events reads
  the same registry again. Apple's general advice is to do the minimum work per wake-up (archive,
  Timers; WWDC25 226: "load and parse … lazily, just one time, and cache them").
- **How:**
  - `MacBatteryProvider` keeps the last registry, IOPS and adapter dictionaries.
  - `read(scope: .live)` re-reads only E4a's live SMC keys and re-parses with the cached
    dictionaries.
  - `.full` runs on notify(3) events, on wake, on launch, for Raw Data, and as a safety net every 5
    minutes.
  - `BatteryMonitor`'s poll asks for `.live`; events ask for `.full`.
  - **Dropped:** the private `kIOPMMessageBatteryStatusHasChanged` spike. It is redundant (F13) and
    private.
- **Verify:**
  - E1 `read` duration, `.live` against `.full`.
  - M1 energy and CPU per hour in S2, before and after (Run Comparison for the call tree).
  - Once: the `ioreg -r -c AppleSmartBattery -w0 | grep UpdateTime` cadence against `pmset -g pslog`
    "any" lines. They should match if F13 holds on macOS 27.
- **Risk:** medium.
  - The snapshot mixes values of different ages.
  - The 0.4 plug-in logic needs the SMC current, which `.live` provides, and the registry's
    `ExternalConnected`, which a plug event refreshes through `.full`.
  - Raw Data must show a `.full` reading.
  - Cover the merge with fixture tests.
- **Priority:** P1 if E1 shows the registry and parse cost after E4a still matters; otherwise P3.

### E5 — DEMOTED to P2: pause the menu bar poll while nobody can see it (P2, S)
- **Practice:** stop display-only work when the screens sleep or the session is switched out.
- **Why:** F3, "suspend energy-intensive work as quickly as possible". Windows already pause through
  occlusion (`Motion.swift:241-292`); the menu bar poll does not.
  **Demoted** because on battery an idle Mac normally sleeps soon after the display sleeps. The gain
  is mostly on power, or when another process holds a sleep assertion.
- **How:**
  - Observe `NSWorkspace.screensDidSleepNotification`/`screensDidWakeNotification` (or the macOS 26
    typed `ScreensDidSleepMessage`/`ScreensDidWakeMessage`; coordinate with the Swift research
    SW-10) and `sessionDidResignActiveNotification`/`sessionDidBecomeActiveNotification`.
  - These withdraw and restore the `menuBar` live-refresh request; on restore, refresh once.
  - Register through `NSWorkspace.shared.notificationCenter`; Apple: "If you use a different
    notification center to register, you won't receive the notification".
  - History recording continues.
- **Verify:** S6 with M1: CPU time and wake-ups per hour approach S1's.
- **Risk:** low; the next notify event refreshes anyway. **Priority:** P2.

### E6 — CORRECTED: back off under Low Power Mode, reduced-resource preference, serious thermal state (P2, S)
- **Practice:** stretch poll intervals when the system asks apps to save energy.
- **Why:**
  - F6 and F7.
  - The archive, "Respond to Thermal State Changes": at Serious, "Reduce CPU usage … Reduce I/O".
  - WWDC26 8003: back off based on the thermal state.
- **How:**
  - Add `LiveRefreshPolicy.interval(base:reducesResources:thermal:)` in BatteryCore, so Linux tests
    cover it. Suggested values: windows 2 s → 5 s, menu bar 10 s → 30 s.
  - **Correction:** read LPM and the thermal state from `ProcessInfo`, not from the snapshot,
    because Demo Mode simulates both. `Motion.swift:216-238` (`LowPowerMode`) does the same for LPM.
  - `MenuBarLabel` is not wrapped in `.motionPolicy()`, so it reads
    `@Environment(\.systemPrefersReducedResourceUsage)` directly.
  - Only the next interval changes. Never do extra work on the flip (F6). Changing the interval of
    an existing client doesn't trigger a read (`setLiveRefreshInterval` reads only for new
    clients).
- **Verify:** C1 policy tests. On the M5, toggle Low Power Mode during S2: `read` signposts per
  minute drop from 6 to 2. UNVERIFIED: whether Xcode's thermal condition inducer (mentioned in
  WWDC26 8003) works for a Mac target. Otherwise rely on the unit test.
- **Risk:** coarser live numbers in Low Power Mode, by design. **Priority:** P2.

### E7 — KEEP, completed: every periodic sleep declares a tolerance; keep `Task.sleep` (P2, S)
- **Practice:** `Task.sleep(for:tolerance:)` with ≥ 10 % tolerance for periodic work. There's no
  reason to move to `Timer` or `DispatchSourceTimer`.
- **Why:** F2; `Timer.tolerance`: "increases the ability of the system to optimize for increased
  power savings".
- **How:** all the tolerance-less sleeps in `Sources` (grep):
  - Add a tolerance:
    - `HistoryView.swift:77`: 60 s → `tolerance: .seconds(15)`, or replace with E13.
    - `UpdateChecker.swift:70` (20 s → 5 s) and `:73` (6 h → `.seconds(30 * 60)`).
    - `UpdateInstaller.swift:203` (200 ms → 50 ms).
    - `DemoController.swift:204` (developer only).
    - The follow-ups at `BatteryMonitor.swift:109`: about 10 % of each gap.
  - Allowlist, no tolerance: one-shot UI feedback (`MainView.swift:185`, the 1.5 s "Copied"
    label), `WidgetRefresher.swift:54` (one-shot) and the CLI's `bpulse` watch loop
    (`main.swift:268`).
- **Verify:** C4 passes. M1 `ri_pkg_idle_wkups` per hour in S1 doesn't rise.
- **Risk:** none. **Priority:** P2.

### E8 — CORRECTED: the history tick reuses a fresh read (P2, S)
- **Practice:** the minute tick shouldn't force a read if one just happened.
- **Why:** `HistoryRecorder.swift:44` always calls `monitor.refresh()`, even right after a poll or
  an event read. With power in the menu bar, a read happened at most 10 s earlier.
- **How:**
  - Add `@ObservationIgnored public private(set) var lastReadAt: ContinuousClock.Instant?` to
    `BatteryMonitor`, set in `refresh()`.
  - **Not** `snapshot.timestamp`: the snapshot is only reassigned on change, so its timestamp can
    be hours old while reads happen every 10 s.
  - `recordNow(refreshing:)` refreshes only when `lastReadAt` is older than ~20 s. With E4b it asks
    for `.live`.
  - Also return early in the snapshot-change path when `HistoryPolicy` would reject the sample: keep
    the last recorded sample in the recorder, or move `migrateLegacySamples()` after the policy
    check (see E14).
  - QoS: the recorder is `@MainActor`, so `Task(priority:)` doesn't move the read off the main
    thread. Only `HistoryStore` work follows the priority. Use `.utility`; F8's E-core preference
    is for `.background`. A name via `Task(name: "History", …)` (SE-0469) helps Instruments. The
    gain from QoS is small; the gain is the avoided read.
- **Verify:** E1 `read` count per hour in S1 and S2; M1 CPU time per hour.
- **Risk:** low (samples may carry power values up to 20 s old). **Priority:** P2.

### E9 — REJECTED for 0.6.1: `NSBackgroundActivityScheduler` for automatic update checks
- **Why rejected:**
  - F4: the first fire comes interval ± tolerance after scheduling, which changes "check 20 s after
    launch" into "check 3–9 h after launch". That first automatic check is the only one allowed to
    open the Software Update window (`UpdateChecker.swift:45-48, 109-112, 134`), so the window would then
    appear in the middle of the user's work.
  - The energy at stake is 4 wake-ups a day.
  - E7's 30 min tolerance on the 6 h sleep gets the coalescing for one argument.
- **If revisited later:** keep the one-shot check after launch, and use the scheduler only for the
  periodic part (`repeats = true`, `interval = 6 h`). Run `checkIfDue()` on the main actor and call
  `completion(.finished)` when it ends; respect `shouldDefer`.

### E10 — CORRECTED: a configuration for automatic checks (P3, S)
- **Practice:** automatic, non-user requests wait for good connectivity and skip Low Data Mode and
  expensive networks.
- **Why:** `allowsConstrainedNetworkAccess`: "set `allowsConstrainedNetworkAccess` (and
  `allowsExpensiveNetworkAccess`) to false and `waitsForConnectivity` to true".
  `isDiscretionary` is "ignored for configuration objects created using other methods" than
  `background(withIdentifier:)`.
- **How:**
  - A lazily built `URLSession(configuration:)` for automatic checks:
    `waitsForConnectivity = true`, `allowsConstrainedNetworkAccess = false`,
    `allowsExpensiveNetworkAccess = false`, `timeoutIntervalForResource = 10 * 60`,
    `urlCache = nil` (the request already ignores the cache).
  - **Required with it:** Check Now must cancel a waiting automatic check and start its own request
    on `URLSession.shared`. Today it only waits (`UpdateChecker.swift:83-86`), so offline it would
    hang for up to 10 minutes.
- **Verify:** an automatic check with Wi-Fi off, then on, succeeds without a failure state. Check
  Now while it waits returns at once. UNVERIFIED: Low Data Mode exposure per Wi-Fi network on macOS
  27 (look in System Settings → Wi-Fi → Details).
- **Benefit:** small. **Risk:** low with the cancel fix. **Priority:** P3.

### E11 — KEEP, confirmed: a `.userInitiated` activity only during an install (P2, S)
- **Practice:** wrap download → verify → swap → relaunch in
  `ProcessInfo.processInfo.beginActivity(options: .userInitiated, reason: "Installing an update")`
  and end it on every exit path.
- **Why:** F18. It keeps the app out of App Nap. It also prevents idle system sleep and sudden
  termination while the bundle is being replaced.
- **How:** in `UpdateInstaller.run` (`:135`): `let activity = …beginActivity(…)` plus
  `defer { ProcessInfo.processInfo.endActivity(activity) }`. Never hold one outside an install
  (E21, C4).
- **Verify:** `pmset -g assertions` shows BatteryPulse's assertion only during an install; Activity
  Monitor "Preventing Sleep" is Yes only then.
- **Risk:** none with `defer`. **Priority:** P2.

### E12 — REJECTED for 0.6.1 (energy): KVO download progress instead of the 200 ms poll
- **Why rejected:** the poll runs only for the seconds a ~10 MB download takes. KVO on
  `URLSessionTask.progress`, plus throttling and a hop to the main actor, isn't shorter than the
  6-line loop. E7's tolerance covers the energy point. Leave it to the Swift research, which may
  adopt Foundation's `ProgressManager` (WWDC26 262).

### E13 — DEMOTED to P3 (conditional): History view reloads on new samples and decodes only what's new (P3, M)
- **Practice:** event-driven refresh and caching of immutable data.
- **Why:** WWDC25 226's fix: "load and parse … lazily, just one time, and cache them".
  `HistoryView.load()` re-decodes up to ~10,000 lines every 60 s while visible, and closed day files
  never change. It also computes points, spans and statistics on the main actor (`:114-117`). The
  cost applies only while the window is visible, so this is conditional.
- **How:**
  - In `HistoryStore`, cache decoded samples per closed day (key: day + file size) and decode only
    the tail of today's file.
  - Publish a `recordedCount` (or an `AsyncStream`) so the view reloads when a sample is actually
    written.
  - Move bucketing off the main actor (`@concurrent`, Swift research SW-05).
- **Verify:** E1 `history.load` for 7 days, cold and warm; Time Profiler in S4.
- **Do it if:** `history.load` exceeds ~50 ms on the M5, or it shows as a hang.
- **Risk:** cache invalidation on `clear()`, day rollover and pruning; covered by Linux tests.
  **Priority:** P3.

### E14 — KEEP, extended: HistoryStore I/O hygiene; keep per-sample appends, no compression (P3, S)
- **Practice:** append-only, crash-safe, without redundant syscalls.
- **Why:**
  - F10 supports the layout. Batching risks losing minutes of data on a crash. ~14,400 lines (about
    2–3 MB, estimate) need no compression.
  - **Added:** `record(_ sample:)` calls `migrateLegacySamples()` (a `fileExists`) before the
    policy check (`HistoryStore.swift:54, 125-126`). It is reached on every snapshot change through
    `HistoryRecorder.observe`, i.e. on every 10 s or 2 s poll whose values moved, not just once a
    minute.
- **How:**
  - Run the legacy migration once per session (a flag).
  - Check the policy before any I/O.
  - Create the samples directory once per day file.
  - Check the trailing newline only on the first open of the session.
  - Keep one `JSONEncoder` in the actor (`encoder()` builds one per append, `:196-205`).
  - Decode from the slice without the `Data($0)` copy (`:238`).
- **Verify:** M1 `ri_diskio_byteswritten` per hour; `sudo fs_usage -w -f filesys BatteryPulse` for
  5 min (syscalls per sample); Filesystem Activity instrument.
- **Risk:** very low. **Priority:** P3.

### E15 — KEEP: count widget reloads and stay well inside the budget (P3, S)
- **Practice:** treat 40–70 refreshes a day as a ceiling, and make reloads observable.
- **Why:** F5. The policy (state change, or ≥ 5 % and ≥ 30 min; entries ≥ 5 min apart) already
  matches. The remaining risk is churn when plugging and unplugging.
- **How:** a `Logger` line (category `widget`) and an E1 event per `reloadTimelines`. If bursts
  appear, rate-limit state-change reloads to one per 5 min.
- **Verify:** `log show --last 1d --predicate 'subsystem == "io.github.nikitausov.BatteryPulse" AND category == "widget"' | wc -l`
  stays under ~25 on a normal day. UNVERIFIED: WidgetKit developer mode on macOS.
- **Priority:** P3.

### E16 — REJECTED for 0.6.1: MetricKit `MetricManager`
- **Why rejected:**
  - It adds about 60–100 lines against the "less code" goal.
  - Delivery to an ad-hoc-signed app distributed outside the App Store is UNVERIFIED (F9).
  - There is no server.
  - M1 plus E1 give the maintainer's own lab numbers.
- **Revisit:** after 0.6.1, as an off-by-default Developer option that saves `Codable` reports
  locally.

### E17 — CORRECTED: one read before the menu bar is ready (P2, S)
- **Practice:** the first frame shouldn't wait for work that can follow it.
- **Why:** "Move expensive tasks out of your app delegate"; "Remove or reduce the static
  initializers in your code" ("Reducing your app's launch time"). That doc also says "On macOS, the
  system will not terminate your process as part of normal use", so the cold launch is mostly the
  login launch.
- **How:**
  - Keep `monitor.start()` (one read).
  - The recorder's first tick reuses it (E8).
  - **Added:** `setLiveRefreshInterval`'s "new request → refresh" skips the read when `lastReadAt`
    is under ~1 s old. With power shown, `MenuBarLabel`'s initial request otherwise causes a third
    read at launch.
  - Statics such as `RawKeyGlossary` are lazily initialized Swift globals; confirm with E1 that
    nothing touches them before `menuBarReady`.
- **Verify:** App Launch template on the E2 build, 10 cold launches. Time to `menuBarReady` (p50),
  and `read` count before it = 1.
- **Risk:** none. **Priority:** P2.

### E18 — KEEP: memory steady over days; windows release what they load (P2, S, measurement)
- **Why:** "Gathering information about memory use": Allocations' Generations view; `vmmap` and
  `leaks`.
- **How:** no code up front.
  - Check that History arrays, Raw Data sections and chart data go away when the window closes.
    UNVERIFIED: whether closed `Window` scenes keep `@State` on macOS 27.
  - If they don't, reset them on disappear.
- **Verify:** E2 build. `footprint` at idle after 10 min; 5 cycles of open → History 7 days →
  close, with Mark Generation each time (growth ≈ 0); `leaks` = 0; `vmmap --summary`.
- **Priority:** P2.

### E19 — KEEP: Raw Data rebuild cadence (P3, S)
- **Why:** WWDC26 8003: avoiding view invalidations "is not just going to help you with
  performance, but also power".
- **How:** after measuring, rebuild only the sections whose source dictionary changed, or ask for 5 s
  instead of 2 s while Raw Data is shown. `.task(id: monitor.reading)` compares the whole reading;
  that is acceptable.
- **Verify:** SwiftUI instrument with Raw Data visible for 5 min. **Priority:** P3.

### E20 — CORRECTED: move IOKit and SMC reads off the main actor only if E1 says so (P3, M; conditional)
- **Why:** "Improving app responsiveness"; WWDC26 268: "two ways to fix it … code optimization …
  [or] offloading the work". `MacBatteryProvider` and `SMCClient` are `@MainActor`.
- **How:** do E4a and E4b first. They likely bring polls well under the threshold.
  - Threshold: `.full` read p95 > 4 ms on the M5. **Corrected:** that is a quarter of a 60 Hz frame
    (16.7 ms), or half of a 120 Hz frame.
  - Only then make the IOKit part `nonisolated` and call it from a `@concurrent` function (Swift
    6.2+, Swift research SW-05). `SMCClient` then needs its own isolation.
- **Verify:** Instruments 27 Swift executors instrument (main actor track) and Time Profiler, S3.
- **Risk:** concurrency in Darwin-only code that only CI compiles. **Priority:** P3.

### E21 — KEEP: things not to add (rules)
- No `beginActivity`, `IOPMAssertion` or `performExpiringActivity` around periodic work (F3). The
  only exception is E11.
- No background `URLSession` and no `isDiscretionary` for a ~30 KB check.
- No `Timer` or `DispatchSourceTimer` rewrite of `Task.sleep` loops (F2).
- No history compression or batching, and no `fsync`/`F_FULLFSYNC` (F10).
- No ETag code (F12). No Combine timers.
- **Added:** no private IOKit messages or private notify keys where the public relay exists (F13).

### E22 — MERGED into the Swift research SW-09 (`Observations`), with a correction
- **Correction for SW-09:** `Observations` yields the current value on the first `next()` (F19).
  Today's consumers react only to changes. Drop the first element, or seed each consumer's state
  first (e.g. `WidgetReloadPolicy` records the shown state without reloading). Otherwise every
  launch adds a widget reload, a history evaluation and a notifier pass.
- The energy effect is small. With E3, `snapshot` changes at most once per burst anyway.

---

## 4. Measurement protocol on the MacBook Air M5 (before = 0.6.0, after = 0.6.1 candidate)

### Setup (same for both builds)
- Same macOS 27.x build: record `sw_vers`, the cycle count and `sysctl kern.pervasive_energy`.
  Charge 60–80 % and **unplug** for the energy runs. Use the adapter only for the "on power"
  variants.
- Brightness 50 % with auto-brightness and True Tone off, Wi-Fi on, Low Power Mode **off** (one
  extra run with it on, for E6). No other user apps; Focus on. Wait 10 min after login.
- Builds: the release DMG of each version (for energy) and the E2 profiling build of each (for
  Instruments and memory). Same settings: History on, daily checks, menu bar items per scenario.
- Run each scenario **3×, alternating A/B/A/B/A/B**, and report the median. Apple suggests averaging
  multiple runs (WWDC25 226); the median is more robust to one noisy run.

### Scenarios
| ID | What | Duration |
|---|---|---|
| S1 | Idle: icon + charge only, no window, display on, no input | 30 min |
| S2 | Idle with the **power** item shown | 30 min |
| S3 | Popover open | 5 min |
| S4 | Main window: Overview 5 → History 24 h 5 → History 7 days 5 → Raw Data 5 | 20 min |
| S5 | Main window fully covered by another window | 10 min |
| S6 | Display asleep (`pmset displaysleepnow`), power item shown, on power and on battery with a `caffeinate -i` assertion | 15 min each |
| S7 | Cold launch: quit, then launch from Finder | 10 launches |
| S8 | Plug/unplug: 5 cycles, 1 min apart | 5 min |

### What to record (one row per scenario per build)
1. **M1 `scripts/rusage.swift $(pgrep -x BatteryPulse) <seconds>`**: energy (mJ/h, P-core
   share), package-idle wake-ups/h, interrupt wake-ups/h, CPU time (s/h), instructions/h, disk
   bytes written/h, phys_footprint. These are the primary numbers.
2. **Activity Monitor → Energy tab**: the App Nap and Preventing Sleep columns (Preventing Sleep
   must stay No outside an install). Energy Impact is a secondary, unitless cross-check.
3. **Signposts (E1)**, Instruments os_signpost + Time Profiler + Swift executors on the profiling
   build: reads per minute, `read` p50/p95, the split of `registry`/`smc.power`/`smc.other`/`parse`,
   `history.load` (S4), `widget.reload` count (S8). Before/after with **Run Comparison**
   (Instruments 27).
4. **Memory** (profiling build): `footprint`, `vmmap --summary`, `leaks` after S4 plus 5 open/close
   cycles.
5. **Launch (S7)**: App Launch template; time to `menuBarReady` (p50 of 10); `read` count before it.
6. **System cross-check (optional)**: `sudo powermetrics --samplers tasks --show-process-energy -i 5000 -n 360`.
   It needs root, and its per-task numbers are scores too.
7. **OS cadence, once (informs E3, E3b, E4b):**
   - `pmset -g pslog` for 2 h on battery and 1 h charging. It prints each `lowbattery`,
     `timeremaining`, `source`, `attach`, "any" and `percent` notification with a timestamp
     (PowerManagement `pmset.m:3504-3590`).
   - Alongside it, `for i in $(seq 360); do date +%T; ioreg -r -c AppleSmartBattery -w0 | grep '"UpdateTime"'; sleep 10; done`.
   - Expect "any" lines to match `UpdateTime` changes (F13), and `timeremaining` to be followed by
     "any" (F14).
8. **Disk (S1)**: M1 bytes written; `sudo fs_usage -w -f filesys BatteryPulse` for 5 min.
9. **Sleep hygiene**: `pmset -g assertions` (BatteryPulse appears only during an install); after a
   night with the lid closed, `pmset -g log | grep -i -E "DarkWake|Wake from"` shows no wake
   attributed to BatteryPulse.

### Results table template
| Scenario | Build | mJ/h | pkg-idle wake-ups/h | CPU s/h | reads/min | read p95 (ms) | App Nap | Footprint (MB) |
|---|---|---|---|---|---|---|---|---|
| S1 | 0.6.0 | | | | | | | |
| S1 | 0.6.1 | | | | | | | |

### Proposed acceptance targets (set the real numbers from the 0.6.0 baseline)
- S1: wake-ups/h ≤ 0.6.0; reads/min ≈ 1 or less (history only, E8).
- S2: energy and CPU per hour −50 % or better (E4a + E4b; an estimate until E1 and M1 numbers exist).
- S6: CPU per hour ≈ S1 (E5).
- S8: one read per notify burst (E3); widget reloads ≤ 1 per cycle.
- Memory: no growth across cycles; idle footprint ≤ 0.6.0.
- Launch: `menuBarReady` p50 ≤ 0.6.0; exactly one `read` before it.

---

## 5. CI

### C1 — KEEP: deterministic work-count tests (Linux, Swift Testing; P1, S–M)
- Count work instead of timing it.
- `MockBatteryProvider` exists (`Tests/BatteryKitTests/BatteryMonitorTests.swift:8`), and
  BatteryKit tests run on the Linux job.
- **Needed:** inject a `Clock` into `BatteryMonitor` (polls, follow-ups, E3's window). Swift
  Testing has no test clock, so add a small manual one in the tests.
- Cases:
  - N callbacks in one burst → 1 read (E3).
  - No live-refresh requests → 0 reads over a simulated hour.
  - `LiveRefreshPolicy` under reduced resources and thermal states (E6).
  - `lastReadAt` reuse (E8, E17).
  - `HistoryStore` with an injected clock: 120 samples → 120 appends, ≤ 2 `days.jsonl` rewrites;
    a closed day decoded once across two loads (E13, if done).
  - `WidgetReloadPolicy`: a synthetic day with 6 plug cycles → ≤ 25 reloads (E15).

### C2 — DEMOTED to P3 (try once, don't gate): parser instruction budget
- `/usr/bin/time -l .build/release/bpulse --input <fixture>` prints "instructions retired" and
  "peak memory footprint".
- **Caveats:**
  - For one fixture, process start-up dominates the count, so a 15 % budget barely sees the parser.
  - In a virtual machine the CPU counters are likely 0 (F16 notes energy is 0 under
    `SOC_IS_VIRTUALIZED`; the instruction counter is UNVERIFIED there).
  - Whether the xcode-27 runner is a VM is UNVERIFIED.
- Keep it only if the first run shows non-zero, stable numbers. Otherwise report the peak footprint
  in the step summary.

### C3 — KEEP: bundle size report (P2, S)
`du -sk` of the app, the main binary, the `.appex` and the DMG, written to `$GITHUB_STEP_SUMMARY`.
It fails at > +10 % against a committed baseline. The size research owns the details.

### C4 — KEEP, simplified: `EnergyGuardTests` (Linux; P2, S)
Put it next to `MotionGuardTests` (same text scan, with comments and strings blanked). Scan
`Sources/BatteryKit`, `Sources/BatteryPulseApp` and `Sources/BatteryPulseWidget`:
- every `Task.sleep(for:` passes `tolerance:` unless it is on an allowlist that gives a reason
  (E7's one-shots);
- no `Timer.scheduledTimer`, `makeTimerSource` or `asyncAfter`, except `IDeviceTransport.swift`
  (timeouts);
- `beginActivity(`/`IOPMAssertionCreate` appear only in `UpdateInstaller.swift` (E11);
- `reloadAllTimelines` appears only in `WidgetRefresher.swift`.

Add a line to CLAUDE.md's Conventions when it lands.

### C5 — REJECTED: xctrace launch trace on CI
The runner has no battery: in a VM, `AppleSmartBattery` is absent and the read takes the "no
battery" path. A trace there measures a different launch. S7 on the M5 covers launch.

---

## 6. Still unconfirmed (settle on the M5 / macOS 27)
1. App Nap for a status-item-only app (S1 vs S2, Activity Monitor). `Motion.swift:244` assumes it
   never applies; `ROADMAP.md:299` keeps it open.
2. The cost split of a read: registry, SMC (16 vs 2 keys) and parse. E4a, E4b and E20 depend on
   it. The 0.2–0.5 ms per SMC call comes from the code's own comment, not from an M5 trace.
3. Whether macOS 27's powerd still relays `kIOPMMessageBatteryStatusHasChanged` as the "any"
   notify key, and whether `timeremaining` is always followed by "any" (F13, F14; `pmset -g
   pslog`). The source checked is PowerManagement-1846.0.25.0.1, macOS 26-era.
4. `ri_energy_nj` non-zero for BatteryPulse on the M5 under macOS 27 (F16; only third-party
   evidence so far).
5. That the shipping libdispatch and Swift 6.4 runtime handle leeway like the open-source `main`
   (F2).
6. Which memory tools refuse a hardened, ad-hoc build without Get task allow (E2).
7. The CI runner: VM or not; `/usr/bin/time -l` counters (C2).
8. Low Data Mode per network on macOS 27 (E10); WidgetKit developer mode on macOS (E15); Xcode's
   thermal condition inducer for a Mac target (E6).
9. Whether closed `Window` scenes release `@State` on macOS 27 (E18).
10. MetricKit delivery for an ad-hoc-signed, non-App-Store app (E16, deferred).

Resolved since `research.md`: `.userInitiated` includes idle-sleep and sudden-termination
disabling (F18).
