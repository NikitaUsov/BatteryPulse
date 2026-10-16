# BatteryPulse 0.6.1: Swift 6.4 language, concurrency and code quality (verified)

This is the adversarial check of `research.md` in this folder. It stands on its own: every recommendation
that survived is restated in full. Written 2026-10-15. Sources were accessed 2026-10-15.

Scope: language settings, concurrency, error handling, ownership, access control, logging, swift-testing,
swift-format, compiler diagnostics, finding unused code, and Package.swift hygiene. Every recommendation
uses only Apple's or the Swift project's own tools and adds no dependency.

## 0. How this was verified

- **Code.** I read every file a recommendation names, at HEAD `fb41ff5` (branch `claude/nice-faraday-k08mhb`).
  The research copy in `work/` is byte-identical to that HEAD (`diff -rq` was clean).
- **Toolchain.** Swift **6.4.1-RELEASE** on Linux (`/opt/swift/swift-6.4.1-RELEASE-ubuntu24.04`). Compile
  probes are in `verify/exp/t1.swift` … `t16.swift` and `verify/exp/obs/main.swift`. Each one was built with
  `swiftc -swift-version 6 -emit-sil`, not just `-typecheck`, because the region-isolation (data-race)
  diagnostics only run during SIL generation.
- **Full builds** on a fresh `git archive HEAD` copy (`verify/repo`, `verify/repo2`):
  - `verify/feat.log`: all five proposed upcoming features enabled.
  - `verify/migrate.log`: `swift package migrate` run end to end.
  - `verify/bpulse.map` and `verify/discarded-core.txt`: a Linux linker map of `bpulse`.
- **macOS evidence.** I downloaded the log of the latest green macOS CI job (run 38760126814, job
  116508893437, runner `xcode-27`): `verify/cilog/macos-job.txt`. It shows Xcode 27.0, `Apple Swift version 6.4
  (swiftlang-6.4.0.34.1)`, **0 compiler warnings**, and 330 tests (36 + 294) that run in about 1.8 s.
  Everything under `#if os(macOS)` still has to be confirmed by that job or on the maintainer's Mac. Each
  such claim is marked **[unverified macOS 27]**.
- **Cited passages.** Every quote below was checked word for word against the cached transcripts in
  `src/wwdc*.txt` and the Apple documentation JSON in `docs/`.
- **Markers.**
  - **[verified 6.4.1]**: compiled or run here.
  - **[verified CI]**: seen in the macOS CI log.
  - **[unverified macOS 27]**: still has to be checked on Darwin.

### Sources

| Key | Source |
|---|---|
| W26-262 | WWDC26 "What's new in Swift", https://developer.apple.com/videos/play/wwdc2026/262/ |
| W26-267 | WWDC26 "Migrate to Swift Testing", https://developer.apple.com/videos/play/wwdc2026/267/ |
| W26-268 | WWDC26 "Profile, fix, and verify: Improve app responsiveness with Instruments", https://developer.apple.com/videos/play/wwdc2026/268/ |
| W25-245 | WWDC25 "What's new in Swift", https://developer.apple.com/videos/play/wwdc2025/245/ |
| W25-268 | WWDC25 "Embracing Swift concurrency", https://developer.apple.com/videos/play/wwdc2025/268/ |
| W25-312 | WWDC25 "Improve memory usage and performance with Swift", https://developer.apple.com/videos/play/wwdc2025/312/ |
| SE-nnnn | https://github.com/swiftlang/swift-evolution/tree/main/proposals (SE-0522 is "Implemented (Swift 6.4)") |
| TC-diag | toolchain diagnostic docs `usr/share/doc/swift/diagnostics/*.md`, also at https://docs.swift.org/compiler/documentation/diagnostics/ |
| AD-* | https://developer.apple.com/tutorials/data/documentation/<path>.json (cached in `docs/`) |
| SZ-nn | the sibling size research, `../size/research.md` (its own verifier checks those numbers) |

## 1. Verdict summary

| ID | Topic | Research | Verdict | Now | Main reason |
|---|---|---|---|---|---|
| SW-01 | Manifest 6.4, `.v27`, shared settings | P0 | **Kept** | P0 | Manifest with every proposed setting builds; 6.3 rejects `.v27` [verified 6.4.1] |
| SW-02 | Free upcoming features | P0 | **Kept** | P0 | 0 diagnostics with all 5 features (my own build) [verified 6.4.1] |
| SW-03 | `nonisolated(nonsending)` by default | P0 | **Corrected** | P0 | The migrate tool adds `@concurrent` everywhere and mangles Package.swift. Use its output as a report only, and run it on macOS |
| SW-04 | Main actor by default | P0 (app + widget) | **Corrected** | P1, **app only** | The widget risks a runtime-only isolation failure. 3 of the 6 hops cannot be removed by this step |
| SW-05 | `@concurrent` instead of `Task.detached{}.value` | P1 | **Corrected** | P1 | The cancellation benefit is false: cancel works only while downloading. Readability only |
| SW-06 | `Mutex` instead of `NSLock` | P0 | **Corrected** | P1 | `Mutex` fails to compile for `MobileDeviceSink` and the token box. `@unchecked` goes 7 → 3, not 2 |
| SW-07 | Small 6.4 wins | P1 | **Corrected** | P2 | A plain `deinit` already works for `SMCClient`; no `weak let` site exists |
| SW-08 | Task names, shields | P1 | **Corrected** | P1 (names) / P2 (shield) | The shield changes nothing today; a quit already waits for the install |
| SW-09 | `Observations` | P1 | **Corrected** | P1 | `Observations` emits the current value first; add `.dropFirst()` to keep today's behaviour |
| SW-10 | Typed `NotificationCenter` messages | P2 | **Downgraded** | Skip unless the SDK has the messages | These notifications are posted off-main, so only `AsyncMessage` would fit |
| SW-11 | Typed throws for update steps | P1 | **Downgraded** | P2 | Correct advice, small gain, real churn |
| SW-12 | `os.Logger`, signposts, `try?` | P1 | **Corrected** | P1 | `.public` on error text leaks paths; no logging in BatteryCore |
| SW-13 | Strict memory safety | P1 | **Corrected** | P1 (Core) / P2 (Kit) | `@diagnose(…, as: warning)` does not enable the check; the test fix is wrong |
| SW-14 | Warning gate | P0 | **Kept**, narrowed | P0 | macOS already at 0 warnings [verified CI]; gate `ci.yml` only, not release |
| SW-15 | `PerformanceHints` audit | P2 | **Kept** | P2 | Counts reproduced |
| SW-16 | `public` → `package` | P1 | **Downgraded** | P2 | No size effect (`package` links like `public`); the import-check flag is a no-op |
| SW-17 | Unused code with toolchain tools | P0 | **Corrected** | P0 | macOS maps miss exported public symbols, and release maps over-report inlined code |
| SW-18 | `-Osize` | P2 | **Kept** | P2 here; see SZ-05 | Measured by the size research |
| SW-19 | swift-testing features | P1 | **Corrected** | P2 | No hardware tests to cancel; the suite runs in 1.8 s; there are no test plans |
| SW-20 | swift-format opt-in rules | P1 | **Kept** | P1 | Counts reproduced |
| SW-21 | DocC from the toolchain | P2 | **Kept** | P2 | Reproduced |
| SW-22 | `InlineArray`/`Span` for SMC | P2 | **Corrected** | Skip | The block is already a `[UInt8]` with offsets, not a tuple; the gain is negligible |
| SW-23 | Noncopyable `Continuation` | P2 | **Rejected** | — | Cannot be captured by escaping closures, and every site resumes from one |
| SW-24 | Package.swift hygiene | P0 | **Kept** | P0 | Swift Build is the default backend [verified 6.4.1] |
| V-01…V-06 | Added by the verifier | — | **New** | see §5 | Runtime isolation checklist, migrate-as-report, test guard, `@preconcurrency`, and others |

## 2. Baseline (corrected)

- **`Package.swift`.** It uses `swift-tools-version: 6.0` and string platforms (`.macOS("27.0")`, `.iOS("27.0")`).
  The only `swiftSettings` are the widget's `unsafeFlags` (`-application-extension`, and the linker flag
  `-e _NSExtensionMain`). BatteryCore and BatteryKit are `.library` products.
- **Warnings.** Swift 6 language mode is on and no upcoming features are enabled. **0 warnings on Linux**
  (6.4.1) and **0 on macOS 27 / Xcode 27** [verified CI, run 38760126814].
- **`@MainActor`: 43 annotations, not "about 50".**
  - BatteryPulseApp: 24
  - BatteryPulseWidget: 3
  - BatteryKit: 15
  - bpulse: 1
- **`@unchecked Sendable`: 7.**
  - `MobileDeviceLibrary`, MobileDeviceLibrary.swift:13
  - `MobileDeviceSink`, MobileDeviceTransport.swift:80, with an NSLock
  - `UncheckedSendable`, SystemNotifications.swift:6
  - `ResumeOnce`, IDeviceTransport.swift:314, with an NSLock
  - `IDeviceListBuilder`, IDeviceTransport.swift:344, with an NSLock
  - `DownloadWatcher`, UpdateInstaller.swift:313, with an NSLock
  - `AppearanceVariants`, BatteryIconView.swift:270
- **`Task.detached`: 4.**
  - Three are awaited at once: UpdateInstaller.swift:149 and :159, and DeveloperView.swift:121.
  - One is fire-and-forget: UpdateInstaller.swift:128.
- **`withObservationTracking` re-arm loops: 3.** Each hops through `Task { @MainActor in }`:
  - HistoryRecorder.swift:54/57
  - BatteryNotifier.swift:36/39
  - WidgetRefresher.swift:25/28
- **Other `Task { @MainActor in }`:**
  - WidgetRefresher.swift:53, which is already redundant: the enclosing static method is main-actor, so
    the `Task` inherits that.
  - BatteryPulseWidget.swift:42 and :48.
- **Other code facts:**
  - One `@preconcurrency import UserNotifications` (BatteryNotifier.swift:6).
  - 51 `try?` in `Sources`.
  - One `Logger`: UpdateInstaller.swift:333, subsystem `io.github.nikitausov.BatteryPulse`, category `update`.
  - `weak var`: 2, both reassigned (UpdateInstaller.swift:38, Motion.swift:265).
  - `#available`: 0.
- **Tests and format:**
  - 330 tests, 8 fixtures. There are no hardware-dependent tests: real data comes from the fixtures.
  - swift-format 6.4.1 reports 0 findings with the project's `.swift-format`.
- **Update install semantics** (these matter for SW-05 and SW-08):
  - `canCancel` is true only in `.downloading` (UpdateInstaller.swift:60-66): "Only the download can be
    stopped; once checked, the update goes in."
  - `finishBeforeQuitting()` (:105-111) lets an install that is already under way finish.
  - Neither `verify` nor `replace` checks for cancellation.

## 3. Recommendations (verified)

Format: Practice · Why (source) · How · Verify · Benefit · Risk · Effort · Priority.
Priorities: **P0** = foundation, do first. **P1** = belongs in 0.6.1. **P2** = optional or later. **Skip** = don't.

---

### SW-01 — Modern manifest: tools-version 6.4, typed platforms, shared settings lists (P0, S)
- **Practice:** declare `// swift-tools-version: 6.4` and `platforms: [.macOS(.v27), .iOS(.v27)]`. Give targets
  their language settings from shared `let` arrays written by hand.
- **Why:**
  - `SwiftSetting.defaultIsolation`, `treatWarning(_:as:)` and `strictMemorySafety()` come from
    PackageDescription 6.2 (SE-0466, SE-0480, SE-0458). `.v27` needs PackageDescription 6.4.
  - **[verified 6.4.1]** A tools-6.4 manifest that uses every setting below (`verify/exp/pkg/Package.swift`)
    builds.
  - **[verified 6.4.1]** `swift package dump-package` shows `defaultIsolation`, `treatWarning` and
    `strictMemorySafety`.
  - **[verified 6.4.1]** With tools-version 6.3 the same manifest fails with "'v27' is unavailable".
  - CI uses Xcode 27 with Swift 6.4.0 and the `swift:6.4-noble` container [verified CI].
- **How:**
  ```swift
  let strict: [SwiftSetting] = [
      .enableUpcomingFeature("ExistentialAny"),
      .enableUpcomingFeature("MemberImportVisibility"),
      .enableUpcomingFeature("InferIsolatedConformances"),
      .enableUpcomingFeature("NonisolatedNonsendingByDefault"),
      .enableUpcomingFeature("ImmutableWeakCaptures"),
      .treatWarning("NoUseUnstructuredThrowingTask", as: .error),   // SW-14
      .treatWarning("ImplicitStrongCapture", as: .error),
      .treatWarning("ErrorInFutureSwiftVersion", as: .error),
  ]
  let app = strict + [.defaultIsolation(MainActor.self)]   // BatteryPulseApp only (SW-04)
  ```
  - Use `strict` for BatteryCore, BatteryKit, bpulse, BatteryPulseWidget and the test targets.
  - Use `app` for BatteryPulseApp.
  - BatteryCore also gets `.strictMemorySafety()` (SW-13).
  - Keep the widget's two `unsafeFlags` with their comments.
  - **Do not** let `swift package migrate` write the manifest. **[verified 6.4.1]** It copies four
    `.enableUpcomingFeature` lines into every target, with formatting that `swift format lint --strict` would
    reject (`verify/repo2`, `git diff`).
- **Verify:** `swift package dump-package`; `swift build --build-tests` on Linux; the macOS CI job; 0 warnings.
- **Benefit:** one place for language policy, and it unlocks the newer APIs. **Risk:** none at runtime.
  **Effort:** S. **Priority:** P0.

### SW-02 — Enable the upcoming features that cost nothing (P0, S)
- **Practice:** enable `ExistentialAny` (SE-0335), `MemberImportVisibility` (SE-0444), `InferIsolatedConformances`
  (SE-0470) and `ImmutableWeakCaptures` (SE-0481).
- **Why:**
  - `swiftc -print-supported-features` (6.4.1) lists each one as `"enabled_in": "7"` [verified 6.4.1].
  - **[verified 6.4.1]** `swift build --build-tests` with these four plus `NonisolatedNonsendingByDefault` emits
    **0 diagnostics** on the Linux-compiled code (`verify/feat.log`, 52 s).
- **How:** add them to `strict` (SW-01). If `MemberImportVisibility` flags a Darwin file in the macOS job, add the
  missing `import` (for example `Combine` for `.onReceive`). **[unverified macOS 27]**
- **Caveat:** `InferIsolatedConformances` combined with `defaultIsolation(MainActor)` turns an unannotated
  conformance into a *main-actor-isolated* conformance without saying so. That is why SW-04 leaves out the
  widget and adds the runtime checklist (V-01).
- **Verify:** the macOS job must stay at 0 warnings. It is 0 today [verified CI].
- **Benefit:** readability (explicit `any` and explicit imports) and Swift 7 readiness. **Risk:** compile time
  only. **Effort:** S. **Priority:** P0.

### SW-03 — Adopt `NonisolatedNonsendingByDefault` (SE-0461) (P0, S)
- **Practice:** a nonisolated `async` function then runs on its caller's actor. Mark work that must leave the
  actor with `@concurrent`.
- **Why:**
  - W25-268: "The Approachable Concurrency setting enables a suite of upcoming features that make easier to
    work with concurrency. We recommend that all projects adopt this setting." In Swift 6 mode, the two
    features in that setting that aren't already on are `NonisolatedNonsendingByDefault` and
    `InferIsolatedConformances`.
  - TC-diag `nonisolated-nonsending-by-default.md`.
- **How (corrected):**
  1. Treat `swift package migrate --to-feature NonisolatedNonsendingByDefault` as a **report**, not the change.
     **[verified 6.4.1]** It is behaviour-preserving and blunt: it put `@concurrent` on every nonisolated
     async declaration it saw (4 fix-its: both `IDeviceTransport` protocol requirements,
     `BlockingWork.run`, `IDeviceListBuilder.run`). Each of these suspends at once on a continuation, and the
     work runs on the transport's `DispatchQueue`, so none needs `@concurrent`. Revert them.
  2. **Run it on macOS too** (the maintainer's Mac or a CI step), because the Linux run never sees
     `#if os(macOS)` code. Alternatively, build once with
     `.enableUpcomingFeature("NonisolatedNonsendingByDefault:migrate")` and read the warnings
     ("will cause nonisolated async closure to run on the caller's actor").
  3. The real list of affected nonisolated async functions, from grep over all of `Sources`:
     - `MobileDeviceTransport.devices/capture`: suspend at once, so leave them.
     - `UpdateInstallSteps.replace`, `withMountedImage`, `detach`, `run(_:_:)`: today they are only called from
       `Task.detached`, so nothing changes. Once SW-05 calls `replace` directly, `replace` **must** be
       `@concurrent`. It does synchronous `copyItem` of the app bundle, quarantine clearing and
       `SecStaticCodeCheckValidityWithErrors` with strict, nested validation.
     - bpulse `readDevices`: CLI top level, fine.
     - Everything else is actor- or main-actor-isolated already.
- **Verify:**
  - The macOS job has 0 warnings.
  - Instruments 27 **Swift executors** instrument while installing an update and opening Raw Data. W26-268:
    "Instruments 27 has a new Swift executors instrument. This instrument visualizes the Main Actor, the
    global concurrent executor, and any custom executors in your process."
  - No install step may appear on the Main Actor track.
- **Benefit:** behaviour that is easy to predict, and fewer `Sendable` constraints on async helpers.
- **Risk:** low in this codebase; the only heavy async function is covered above. **Effort:** S. **Priority:** P0.

### SW-04 — Main actor by default for **BatteryPulseApp only** (P1, M)
- **Practice:** `.defaultIsolation(MainActor.self)` (SE-0466) on the app target. BatteryCore, BatteryKit, bpulse
  and **the widget** stay nonisolated by default.
- **Why:**
  - W25-268: "For Swift modules that are primarily interacting with the UI, such as your main app module, we
    also recommend setting the default actor isolation to 'main actor'."
- **Corrections to the research:**
  - **Widget excluded.** `BatteryTimelineProvider` (BatteryPulseWidget.swift:36) has no annotation. Under default
    main-actor isolation plus `InferIsolatedConformances`, its `TimelineProvider` conformance would become
    main-actor-isolated without any diagnostic. `Widget.body` is a main-actor context, so it would still
    compile. WidgetKit then calls `placeholder`, `getSnapshot` and `getTimeline` on its own threads. The
    current code is written for exactly that (`Task { @MainActor in completion(…) }`). So a mistake shows up
    only at runtime, and CI never runs the widget. The gain would be 3 annotations. Not worth it.
    **[unverified macOS 27: WidgetKit's calling thread in the 27 SDK]**
  - **The 3 `onChange` hops cannot be removed by this step.** **[verified 6.4.1, `verify/exp/t11.swift`]** Under
    `-default-isolation MainActor`, a `Task {}` inside the `@Sendable` `onChange` closure is still nonisolated.
    Dropping `@MainActor in` gives "main actor-isolated instance method … cannot be called from outside of the
    actor". These hops go away only through SW-09.
  - **WidgetRefresher.swift:53** `Task { @MainActor in` → `Task {` is redundant **today**: the static method is
    already main-actor. Remove it now, with or without SW-04.
  - The count is **24** `@MainActor` in the app, not 27.
- **How:**
  1. Do SW-09 first, so the observation hops are gone.
  2. Add `.defaultIsolation(MainActor.self)` to BatteryPulseApp, then delete the now-redundant `@MainActor` in
     `Sources/BatteryPulseApp`.
  3. Mark off-main code `nonisolated` explicitly. Otherwise it becomes main-actor:
     - `enum UpdateInstallSteps`, including `static let log`, `verify`, `replace` and `run(_:_:)`. Its
       `process.terminationHandler` runs on a background thread.
     - `DownloadWatcher`, a `URLSessionTaskDelegate` that URLSession calls on its delegate queue. With
       `InferIsolatedConformances` its conformance would become main-actor-isolated without a diagnostic.
     - `AppearanceVariants`: AppKit calls its drawing handler whenever it draws.
     - The `UNUserNotificationCenterDelegate` methods are already `nonisolated` (BatteryNotifier.swift:126/133).
       Keep them.
  4. Then go through the runtime checklist V-01 by hand.
- **Verify:**
  - The macOS job compiles.
  - `grep -rc "@MainActor" Sources/BatteryPulseApp` drops close to 0.
  - V-01 on the maintainer's Mac.
  - Instruments Swift executors / Hangs (W26-268).
- **Benefit:** readability (about 20 fewer annotations) and safe-by-default UI code.
- **Risk:** medium. A conformance or callback that a framework invokes off-main fails only at runtime: Swift 6's
  dynamic isolation checks (SE-0423) trap. **Effort:** M. **Priority:** P1, after SW-03, SW-06 and SW-09.

### SW-05 — `@concurrent` functions instead of `Task.detached { … }.value` (P1, S)
- **Practice:** to offload work, call a `@concurrent` function (W25-268; W25-245). Don't use an unstructured
  detached task.
- **Why (corrected):**
  - The research said cancelling an update while it verifies leaves the verification running, and that
    `@concurrent` fixes this. **That is not a real problem here:**
    - `cancel()` does nothing outside `.downloading` (UpdateInstaller.swift:60-66, 97-100).
    - Neither `verify` nor `replace` checks cancellation, so they would run to the end either way.
    - In DeveloperView, `RawSection.sections(for:)` doesn't check cancellation either, and a stale result is
      already dropped by `guard !Task.isCancelled` (DeveloperView.swift:127).
  - The real gains:
    - the idiom WWDC25 recommends ("@concurrent tells Swift to run the function in the background");
    - priority inheritance;
    - with SW-04, an explicitly nonisolated, compiler-checked boundary instead of a closure.
  - **[verified 6.4.1, t2]** `@concurrent static func` compiles inside a `@MainActor` enum.
- **How:**
  - UpdateInstaller.swift:149: `try await UpdateInstallSteps.verify(…)`, with `verify` made `@concurrent … async`.
  - UpdateInstaller.swift:159: `try await withTaskCancellationShield { try await UpdateInstallSteps.replace(…) }`,
    with `replace` made `@concurrent`. The shield writes down the existing rule "once checked, the update
    goes in". **[verified 6.4.1]** The async overload of `withTaskCancellationShield` exists; it is macOS 27
    (AD `swift/withtaskcancellationshield(operation:)`).
  - DeveloperView.swift:121: a `@concurrent` helper that returns `[RawSection]`.
  - UpdateInstaller.swift:128 (`cleanUpAfterUpdate`): keep it detached, but name it:
    `Task.detached(name: "Remove update leftovers", priority: .utility)`.
- **Verify:** the macOS job; one manual update install (V-01); the Swift executors instrument shows `verify` and
  `replace` off the Main Actor track.
- **Benefit:** readability and native idiom. **Risk:** low, if `replace` is `@concurrent` (SW-03). **Effort:** S.
  **Priority:** P1.

### SW-06 — `Mutex` instead of `NSLock` + `@unchecked Sendable`, where it fits (P1, S)
- **Practice:** guard shared mutable state with `Mutex<State>` (SE-0433). A final class whose stored properties
  are `let`s of Sendable types (a `Mutex` is Sendable) is checked `Sendable`, with no `@unchecked`.
- **Why:**
  - AD `synchronization/mutex` (macOS 15.0+).
  - The compiler then checks the claim that today lives in a comment ("every var is guarded by lock").
- **Verified per site [verified 6.4.1, `verify/exp/t1.swift`, `t2.swift`, `t13.swift`]:**

  | Type | `Mutex`? | Notes |
  |---|---|---|
  | `ResumeOnce` (IDeviceTransport.swift:314) | **Yes** | `Mutex<CheckedContinuation<T, any Error>?>`, resumed with `state.withLock { $0.take() }?.resume(with:)` |
  | `IDeviceListBuilder` (:344) | **Yes** | One `Mutex<State>` holding `entries`, `step` and `continuation`, which are all Sendable. Keep resuming outside the lock (`take()` as today) |
  | `DownloadWatcher` (UpdateInstaller.swift:313) | **Yes** | `final class DownloadWatcher: NSObject, URLSessionTaskDelegate, Sendable { let task = Mutex<URLSessionTask?>(nil) }` compiles on Linux. **[unverified macOS 27]**: that `URLSessionTask` is Sendable in the SDK |
  | `MobileDeviceSink` (MobileDeviceTransport.swift:80) | **No** | `[AnyObject]` is not Sendable. Appending a caller's object gives "'inout sending' parameter … is accessible … at end of function", and copying out fails the same way. Keep the `NSLock` and `@unchecked`, with the comment |
  | `UncheckedSendable` (SystemNotifications.swift:6) | **No `Mutex`** | `Mutex(tokens)` fails ("sending value of non-Sendable type '[any NSObjectProtocol]' risks causing data races"). What compiles: a local `nonisolated(unsafe) let tokens = …` captured by the `@Sendable` remover. That deletes the helper type. `NotificationCenter.removeObserver` is thread-safe, and `BatteryObservation.deinit` may call the remover on any thread, so the remover must stay `@Sendable` |
  | `MobileDeviceLibrary`, `AppearanceVariants` | Keep | Immutable. `AppearanceVariants` could become plain `Sendable` if `CGImage` is `Sendable` in the macOS 27 SDK **[unverified macOS 27]** |

- **How:** convert the three "Yes" rows. Replace `UncheckedSendable` with the local `nonisolated(unsafe) let`.
  `nonisolated(unsafe)` stays greppable and is reported as unsafe under SW-13. Use `Atomic` only for a single
  word; nothing needs it today.
- **Verify:**
  - `grep -rn "@unchecked Sendable" Sources | wc -l` goes from **7 to 3**. Remaining: `MobileDeviceSink`,
    `MobileDeviceLibrary`, `AppearanceVariants`.
  - `swift test`; `bpulse --devices` smoke step in CI.
  - Optional: `swift test --sanitize=thread` on Linux **[not run here]**.
- **Benefit:** compiler-checked thread safety and slightly less code. **Risk:** low. **Effort:** S.
  **Priority:** P1.

### SW-07 — `SMCClient` without its `Port` helper; skip the rest (P2, S)
- **Practice:** delete helper types that exist only to work around deinit isolation.
- **Why (corrected):**
  - **[verified 6.4.1, t2]** In Swift 6 mode, a plain, nonisolated `deinit` of a `@MainActor final class` may read
    a stored `var` whose type is Sendable (`io_connect_t` is `UInt32`). So
    `deinit { if port != 0 { IOServiceClose(port) } }` works without the nested `Port` class
    (SMCClient.swift:37-43).
  - The researcher's `isolated deinit` (SE-0371) also compiles. But it schedules the deinit on the main actor
    whenever the last release happens off-main, and nothing here needs main-actor state in the deinit. Prefer
    the plain `deinit`.
- **Dropped parts:**
  - **`weak let`: no site.** Both `weak var`s are reassigned (UpdateInstaller.swift:38 in `init`, Motion.swift:265
    in `viewDidMoveToWindow`). The compiler already checks this: `VariableNeverMutated::WeakMutability` is on
    by default [verified 6.4.1, t8], and the build has 0 warnings. No grep audit is needed.
  - **`~Sendable` on `BatteryObservation`** (SE-0518, W26-262): no effect. A public class with a `var` is never
    inferred Sendable. Optional documentation only.
  - **`await` in `defer`:** no current use.
- **Verify:** the macOS job; `bpulse --smc` smoke step (ci.yml:49). **Benefit:** about 6 lines fewer, and one
  type fewer. **Risk:** low. **Effort:** S. **Priority:** P2.

### SW-08 — Name long-lived tasks; cancellation shield only where it changes something (P1 / P2, S)
- **Practice:** name long-lived tasks (SE-0469; `Task(name:)`, macOS 26). Keep handles to them. Use
  `withTaskCancellationShield` (SE-0504, macOS 27) only around work that checks cancellation and must
  finish anyway.
- **Why:**
  - Names appear in the Instruments "Swift Tasks" view and in the debugger, which helps the 0.6.1 profiling.
  - W26-262 on shields: "there are times where we actually want to do the work even after the task was
    cancelled, like finishing writing data to disk to avoid corrupting a file … keep this region short".
- **How:**
  - Name these tasks (P1):
    - `BatteryMonitor.liveRefreshTask` and `followUpTask` (BatteryMonitor.swift:106/133)
    - `UpdateChecker.schedule` (UpdateChecker.swift:68)
    - `DemoController.clock` (DemoController.swift:202)
    - `HistoryRecorder.task` (HistoryRecorder.swift:42)
    - the SW-09 observation tasks
    - `UpdateInstaller.work` (:94)
  - Shield (P2): **only** around the `replace` call, once SW-05 makes it a structured call.
    - The research's claim that a shield stops "a cancel or quit during an install" from breaking the bundle
      is **wrong**:
      - a quit already waits for the install (`finishBeforeQuitting`);
      - a force quit or crash isn't affected by any shield;
      - the swap is one atomic `renamex_np(…, RENAME_SWAP)`.
    - `HistoryStore` and `removeDownloads` never check cancellation, so they need no shield.
  - `NoUseUnstructuredThrowingTask` (TC-diag; W26-262): 0 hits today on Linux and macOS [verified CI]. Keep it
    as an error group (SW-14).
  - `Task.immediate` (SE-0472) for "Check Now" and "Clear History" (SettingsView.swift:357/369/399):
    optional P2.
- **Verify:** task names appear in an Instruments "Swift Tasks" trace. **Benefit:** easier profiling and
  debugging. **Risk:** none. **Effort:** S.

### SW-09 — `Observations` instead of re-arming `withObservationTracking` (P1, S)
- **Practice:** to react to `@Observable` changes outside SwiftUI, use one long-lived named task:
  `for await _ in Observations({ monitor.snapshot }).dropFirst() { … }`. `Observations` is SE-0475, macOS 26.
- **Why:**
  - AD `observation/observations`: "tracks the transactional changes … starting from the willSet of the first
    mutation to the next suspension point".
  - It replaces three recursive patterns (HistoryRecorder.swift:54, BatteryNotifier.swift:36,
    WidgetRefresher.swift:25). Each re-registers and creates a task on every change. The replacement also
    removes their `Task { @MainActor in }` hops (see SW-04).
- **Verified behaviour [verified 6.4.1, `verify/exp/obs/main.swift`]:**
  - **It emits the current value first.** The run printed `seen: [Optional(1), Optional(3)]` when the value was
    1 at start. Without `.dropFirst()`:
    - BatteryNotifier would evaluate at launch, and could post an alert just because the app started.
    - HistoryRecorder would race its own timer's first `recordNow` for the pending `.launch` event.
    - WidgetRefresher would reload at every launch.
  - With `.dropFirst()` it printed `[Optional(3)]`: changes only, as today.
  - Two assignments in the same main-actor turn (2 then 3) are delivered once (3), and that is fine for all three
    consumers.
  - Cancelling the task ends the `for await` loop.
  - The closure `{ monitor.snapshot }` over a `@MainActor @Observable` monitor is inferred main-actor. The
    element (`BatterySnapshot?`) is Sendable.
- **How:**
  ```swift
  task = Task(name: "Widget refresh") { [weak self, monitor] in
      for await _ in Observations({ monitor.snapshot }).dropFirst() { self?.evaluate() }
  }
  ```
  Add `stop()`/`deinit` cancellation where an owner can go away. Today all three live for the app's lifetime.
- **Verify:**
  - Existing tests.
  - On the Mac: plug and unplug, and the widget, notification and history behave as before.
  - In Instruments "Swift Tasks", the per-change tasks are gone.
- **Benefit:** readability, cancellable observers, coalesced work. **Risk:** low with `.dropFirst()`.
  **Effort:** S. **Priority:** P1.

### SW-10 — Typed `NotificationCenter` messages (Skip unless the SDK provides them)
- **Why it was downgraded:**
  - AD `foundation/notificationcenter/mainactormessage`: "The notification center delivers `MainActorMessage`
    types synchronously when posted", so the post must happen on the main actor.
  - ProcessInfo power and thermal changes and `UserDefaults.didChangeNotification` are posted on whatever
    thread caused them. They could only be `AsyncMessage` types, which deliver asynchronously and change
    ordering.
  - The current `addObserver(…, queue: .main)` + `MainActor.assumeIsolated` pattern is correct.
  - The `UncheckedSendable` box goes away through SW-06 instead.
- **Action:** when the macOS 27 SDK is at hand, check whether concrete message types exist for these
  notifications **[unverified macOS 27]**. Adopt them only if they are `MainActorMessage`.

### SW-11 — Typed throws only for `UpdateInstallSteps` (P2, S)
- **Practice:** SE-0413: "untyped `throws` is better for most scenarios … Resist the temptation to use typed throws
  because there is only a single kind of error."
- **How:**
  - Keep `SMCClient`'s `throws(Failure)` as it is.
  - Optionally move `UpdateInstallSteps.verify` and `replace` to `throws(UpdateInstallError)`; each already maps
    every error by hand. The `withMountedImage` body closure must become typed too.
  - `CancellationError` is not an `UpdateInstallError`. `run` distinguishes it from the steps' errors, so keep
    any cancellation check in `run`, outside the typed functions.
  - Keep `HistoryStore` and the IDevice transport untyped.
- **Benefit:** compile-time exhaustiveness. **Risk:** low. **Effort:** S. **Priority:** P2.

### SW-12 — `os.Logger` per category, signposts, and fewer silent `try?` (P1, M)
- **Practice:**
  - Use one `Logger(subsystem: "io.github.nikitausov.BatteryPulse", category:)` per area.
  - Log unexpected failures at OS and I/O boundaries.
  - Rely on the default privacy. AD `os/generating-log-messages-from-your-code`: "By default, the system doesn't
    redact integer, floating-point and Boolean values, but it does redact the contents of dynamic strings and
    complex dynamic objects".
  - Debug messages are memory-only: "Debug logs have very low overhead".
- **Corrections:**
  - **No `os` in BatteryCore** (CLAUDE.md: it must stay free of Apple-only frameworks).
    - `HistoryStore` (BatteryCore/HistoryStore.swift) already throws. Log at its call sites in
      HistoryRecorder.swift:71/73, which are `try?` today.
    - `RawSection.sections` (BatteryCore/RawKeyGlossary.swift) and the History bucketing are BatteryCore too,
      so their signposts go at the app call sites (DeveloperView, HistoryView).
  - **Don't write `\(error, privacy: .public)`.** Foundation error descriptions contain file paths under
    `/Users/<name>/…`. Log the error type or code publicly, and the description at the default (private)
    level or with `.private(mask: .hash)` (AD `os/oslogprivacy`: "makes it possible to correlate log messages
    that contain the same original value").
  - The existing UpdateInstaller logs make values public that are fine to make public: the version, the
    `UpdateInstallError` case, `LSRegisterURL`'s status and `strerror` text. The exception is `checkCodeSignature`
    (:522): its reason comes from `CFError` and can include the path. Make that one private.
- **How:**
  1. Categories: `monitor`, `smc`, `iokit`, `history`, `device`, `update`, `widget`.
  2. Convert unexpected-failure `try?`:
     - HistoryRecorder writes;
     - SMC open (`isUnavailable` path, SMCClient.swift:58-60);
     - the MobileDevice `dlopen`;
     - `WidgetCenter` calls.
     Keep `try?` where failure is normal: `Task.sleep`, `removeItem` of a file that may be missing.
  3. Device serials and UDIDs: `.private(mask: .hash)`.
  4. `OSSignposter` intervals (AD `os/ossignposter`, macOS 12+) around `BatteryMonitor.refresh`,
     `SMCClient.read(_:)`, the Raw Data rebuild and the History load. W26-268 uses this to tie a hang to code.
  5. bpulse keeps `print`/stderr.
- **Verify:**
  - `log stream --level debug --predicate 'subsystem == "io.github.nikitausov.BatteryPulse"'`. Serials and paths
    must show as `<private>` or a hash.
  - The signposts show in Instruments' Points of Interest / os_signpost track.
  - `grep -c "try?" -r Sources` drops from 51, with each remaining one justified.
- **Benefit:** diagnosable failures, better privacy, and the before/after measure for the speed work.
  **Risk:** none. **Effort:** M. **Priority:** P1.

### SW-13 — Strict memory safety: BatteryCore now, BatteryKit later (P1 Core / P2 Kit)
- **Practice:** `.strictMemorySafety()` (SE-0458) where untrusted input is parsed.
- **Why:**
  - W25-245: Apple adopted it in "two security critical components … WebKit and a subsystem of the Messages app
    that parses incoming messages and attachments".
  - W26-262: "you could turn on strict memory safety in security-critical functions".
- **Measured [verified 6.4.1]:**
  - `-strict-memory-safety` gives **0 warnings in BatteryCore**, 1 in `bpulse/main.swift:230`, and 13 in tests.
  - BatteryCore is where the GitHub release JSON, the iPhone plists and the capture files are parsed.
- **Corrections:**
  - **`@diagnose(StrictMemorySafety, as: warning)` does not turn the check on** for one function in a module
    built without the flag. **[verified 6.4.1, t14]** It produced no warning for an unmarked
    `UnsafeMutablePointer` use.
    - What does work is the reverse: enable it for the module, and put
      `@diagnose(StrictMemorySafety, as: ignored, reason: "…")` on declarations already audited
      **[verified 6.4.1, t15, t16; SE-0522 "Implemented (Swift 6.4)"]**.
    - So the W26-262 sentence describes something 6.4.1 does not do. Re-check on Xcode 27's Swift 6.4.0
      **[unverified macOS 27]**.
  - **The test fix is wrong.** `PropertyListSerialization.propertyList(from:)` without `format:` does not exist
    **[verified 6.4.1, t6]: "missing argument for parameter 'format'"**. Don't enable strict memory safety on the
    test targets; it adds nothing there.
- **How:**
  1. Put `.strictMemorySafety()` on BatteryCore now. It costs nothing and locks in the 0.
  2. bpulse: mark the one line `unsafe`, or leave bpulse without the flag.
  3. BatteryKit (P2): IOKit `&out` pointers, the SMC `withUnsafeBytes`, MobileDevice `dlsym`/`unsafeBitCast`,
     and WidgetRefresher's `proc_*`. Expect broad `unsafe` churn **[unverified macOS 27]**. Do it only if the
     maintainer wants every unsafe site greppable.
- **Verify:** 0 `StrictMemorySafety` warnings in the macOS job, then promote the group to an error for BatteryCore.
  **Benefit:** safety lock-in on the parsers. **Risk:** none at runtime. **Effort:** S (Core), M (Kit).

### SW-14 — Warning gate in CI (P0, S)
- **Practice:** keep 0 warnings. Promote all warnings to errors in CI, except deprecations. W25-245: "you could
  decide to treat all warnings as errors by default, but make an exception for deprecated declarations."
- **Verified:**
  - Both platforms are at **0 warnings today** [verified CI on macOS 27 / Xcode 27; 6.4.1 on Linux], so the gate
    can go in at once.
  - `-warnings-as-errors -Wwarning DeprecatedDeclaration` keeps the deprecation as a warning and makes
    everything else an error [verified 6.4.1, t8]. The order matters, as in TC-diag `diagnostic-groups.md`.
- **How:**
  1. In `.github/workflows/ci.yml`, add
     `-Xswiftc -warnings-as-errors -Xswiftc -Wwarning -Xswiftc DeprecatedDeclaration` to the build at line 23
     (Linux) and to the `swift test` at line 37 (macOS).
     **Not** in `release.yml` or `scripts/build-app.sh`: a release of a commit that already passed CI should
     not fail because a newer Xcode added a warning.
  2. In the manifest (SW-01), make `NoUseUnstructuredThrowingTask`, `ImplicitStrongCapture` and
     `ErrorInFutureSwiftVersion` errors. Each group has its own TC-diag page. Add `StrictMemorySafety` for
     BatteryCore after SW-13.
  3. If a deprecated API must stay, put `@diagnose(DeprecatedDeclaration, as: ignored, reason: "…")` on that one
     declaration [verified 6.4.1, t16].
- **Correction:** `PreconcurrencyImport` is "experimental and disabled by default" (TC-diag
  `preconcurrency-import.md`). Swift 6.4 does **not** warn about a needless `@preconcurrency` unless that group is
  enabled. See V-04.
- **Verify:** a deliberate unused `var` in a PR fails CI. **Benefit:** regressions surface in the PR.
  **Risk:** CI friction after an Xcode update, which the deprecation exception covers. **Effort:** S.
  **Priority:** P0.

### SW-15 — Run `PerformanceHints` once as an audit, never as a gate (P2, S)
- **Measured [verified]:** 125 hints on the Linux-compiled code (`exp3.clean`):
  - 46 `ExistentialType`
  - 50 `ReturnTypeImplicitCopy`
  - 29 `UntypedThrows`

  TC-diag `performance-hints.md`: the group is off by default and opt-in.
- **How:** run `swift build -Xswiftc -Wwarning -Xswiftc PerformanceHints` once. Look only at hot paths:
  - `MacPowerParser`
  - the Raw Data rebuild
  - History bucketing
  - `BatteryMonitor.isSameState`/`isSameReading`

  Change only what Time Profiler or the SW-12 signposts show to matter.
- **Benefit:** focused speed work. **Risk:** churn if applied wholesale.

### SW-16 — `package` instead of `public` (P2, M; optional)
- **Practice:** `package` (SE-0386) says "shared inside BatteryPulse, not an API". BatteryCore and BatteryKit
  have 766 `public`/`open` declarations, and no external client.
- **Corrections:**
  - **No size effect, and the research's reason was wrong.** **[verified 6.4.1]** `package` and `public`
    functions get the same global symbol (`nm`: `T` for both, even with `-wmo`; only an unused `internal`
    function was removed). On macOS the executables export every global symbol today (the size research SZ-02
    counts 2,709 exports). That keeps unused public code from being dead-stripped. The fix for that is SZ-02
    (export only `_main`), not access control.
  - **`--explicit-target-dependency-import-check error` is a no-op with the default Swift Build backend**
    **[verified 6.4.1]**. A target importing an undeclared module compiled and failed only at link time, with
    or without the flag. Drop that step.
  - `InternalImportsByDefault` breaks about 58 distinct source lines today (`exp1.log`, each reported about twice).
    Each needs `public import` or `package import Foundation`.
  - It conflicts with SW-20: after this change nothing is `public`, so `AllPublicDeclarationsHaveDocumentation`
    would check nothing. Pick one: keep `public` and turn on that rule, or switch to `package` and drop it.
- **Verify:** builds on both OSes, plus `xcodebuild -scheme BatteryKit` for iOS (ci.yml:61).
- **Benefit:** readability of intent only. **Risk:** low, but a 766-line diff that will collide with 0.6.0 work.
  **Effort:** M. **Priority:** P2.

### SW-17 — Find unused code with linker and toolchain tools (P0, M)
- **Practice:** prove which code is unused with Apple's linker and the Swift toolchain, then delete it with the
  tests green.
- **Corrections:**
  - **On macOS, link maps miss unused *public* code today.** The executables export all global symbols (SZ-02),
    and exported symbols are dead-strip roots. ld64: "-dead_strip: Remove functions and data that are
    unreachable by the entry point or exported symbols", as quoted in SZ-02. So a public BatteryCore function
    nobody calls never appears under "Dead Stripped Symbols". Make the map builds export only `_main`:
    `-Xlinker -exported_symbol -Xlinker _main`, or adopt SZ-02 first **[unverified macOS 27]**.
  - **Release maps over-report.** **[verified 6.4.1]** A Linux release link of `bpulse`
    (`swift build -c release --product bpulse -Xlinker -Map=<file>`) lists **1,543 BatteryCore text sections**
    under "Discarded input sections". These include code the *app* uses (`AlertSettings`, `AlertState`
    accessors) and code that was inlined into its callers. For finding dead code:
    - use **debug** builds (`-Onone`, no inlining) with `-Xlinker -dead_strip` added;
    - take the **intersection** over all three products (BatteryPulse, BatteryPulseWidget, bpulse).

    Keep release maps for size attribution (SZ-06).
  - Code that is dead in every product but referenced from `Tests/` is test-only code. Either keep it on
    purpose or move it into the test target.
- **How:**
  1. macOS, per product:
     ```
     swift build --product <P> -Xlinker -dead_strip -Xlinker -exported_symbol -Xlinker _main \
       -Xlinker -map -Xlinker build/<P>.map
     ```
     Read `# Dead Stripped Symbols:` and demangle with `xcrun swift-demangle`. Use
     `-Xlinker -why_live -Xlinker <symbol>` to explain a survivor (it applies only with `-dead_strip`).
     On Linux the same works with `-Xlinker -Map=<file>` [verified 6.4.1].
  2. Declarations at or above an access level: `swift package dump-symbol-graph --minimum-access-level internal`
     (built in, 6.4.1). It is simpler than passing `-emit-symbol-graph` by hand.
  3. References: "Find References" through `sourcekit-lsp` (it ships in the toolchain) for spot checks. For a
     full sweep, a throwaway script outside the repo using swiftlang's IndexStoreDB over the index store, which
     SwiftPM writes by default (`--auto-index-store`).
  4. Coverage as a hint: `swift test --enable-code-coverage`, then
     `llvm-cov report <binary> -instr-profile $(swift test --show-codecov-path …)`.
- **Caveat [plausible]:** dead stripping keeps protocol-conformance records, so an unused type that has
  conformances keeps costing bytes. Confirm with `-why_live`, then delete the type.
- **Benefit:** less code and a smaller app, with "no lost functionality" provable from the maps and the tests.
  **Risk:** none from the analysis itself. **Effort:** M. **Priority:** P0.

### SW-18 — `-Osize` for the shipped binaries (P2 here; see SZ-05)
- `swift build -c release --product BatteryPulse -Xswiftc -Osize`, and the same for the widget in
  `scripts/build-app.sh:25-26`. Use the command line, never `unsafeFlags`.
- The size research measured about −13 % `__text` on a Linux proxy and checked that the last `-O…` flag wins
  (SZ-05). It owns that decision; this file only confirms that the flag can be expressed without manifest
  `unsafeFlags`.
- **Verify:** binary and DMG size before and after; Time Profiler on History and Raw Data.

### SW-19 — swift-testing: only the features that fix something here (P2, S; one P1 item)
- **Kept:**
  - **`#require` instead of silent early returns.** RealIDeviceCaptureTests.swift:79,
    `guard case .dictionary(let raw) = … else { return }`, would pass silently if the guard ever failed. It
    cannot fail today, so this is hygiene: P2.
  - **`confirmation(expectedCount:)`** for callback APIs: `DemoBatteryProvider.observeChanges`, and the
    monitor's refresh on a change (AD `testing/testing-asynchronous-code`). P2.
  - **`.timeLimit(.minutes(1))`** on tests that wait on timers (AD `testing/timelimittrait`). P2.
  - **`swift test --repeat-until fail --maximum-repetitions 50`** to hunt flaky timer tests. Both flags exist in
    6.4.1 `swift test --help` [verified 6.4.1].
  - **One test case per fixture** (`@Test(arguments:)`) where a test loops over fixtures today. It has 8
    fixtures, and each failure is then reported separately (AD `testing/parameterizedtesting`). P2.
- **Rejected:**
  - **`Test.cancel` "for tests that need real hardware".** No such test exists; all hardware data comes from
    fixtures.
  - **"Faster CI".** The macOS suite runs 330 tests in about 1.8 s [verified CI].
  - **Tags "for Xcode test plans".** The project runs `swift test` and has no test plans. `--filter`/`--skip`
    match names. Tags are optional, for readability only.
- **Exit tests:** the only `precondition`-style path is `preconditionFailure` in SMC.swift:31. A test of it is
  optional. The research said exit tests run on "macOS and Linux only". The documentation says macOS,
  Linux, FreeBSD, OpenBSD and Windows (AD `testing/exit-testing`; W26-267 omits OpenBSD).
- **`Issue.record(severity: .warning)`** (Swift 6.3, AD `testing/issue/severity-swift.enum`) for known "M5
  verification debts": optional.

### SW-20 — swift-format: lock in the rules that already pass (P1, S)
- **Measured [verified 6.4.1]:** I re-tallied the research's `fmt-strict.txt`. `swift format dump-configuration`
  confirms these are exactly the 12 rules that are off by default.

  | Rule | Hits |
  |---|---|
  | `AllPublicDeclarationsHaveDocumentation` | 356 |
  | `BeginDocumentationCommentWithOneLineSummary` | 164 |
  | `ValidateDocumentationComments` | 10 |
  | `NoEmptyLinesOpeningClosingBraces` | 2 |
  | `UseWhereClausesInForLoops` | 1 |
  | `NeverUseForceTry`, `NeverUseImplicitlyUnwrappedOptionals`, `OmitExplicitReturns`, `UseEarlyExits`, `AlwaysUseLiteralForEmptyCollectionInit`, `NoLeadingUnderscores` | 0 each |
- **How:**
  1. Enable the six zero-hit rules now.
  2. Fix the 13 sites (2 + 1 + 10), then enable `NoEmptyLinesOpeningClosingBraces`, `UseWhereClausesInForLoops`
     and `ValidateDocumentationComments`.
  3. `AllPublicDeclarationsHaveDocumentation` depends on the SW-16 choice.
  4. `BeginDocumentationCommentWithOneLineSummary` is a style choice: P2.
- **Verify:** `swift format lint --strict -r Sources Tests Package.swift` passes in CI (ci.yml:21).
  **Risk:** none.

### SW-21 — DocC from the toolchain (P2, S)
- **[verified]** `docc` ships in the toolchain (`usr/bin/docc`; on macOS, `xcrun docc`). The research's
  symbol-graph plus `docc convert --analyze` run gave 2 warnings:
  - a missing `source` parameter at IDeviceBattery.swift:148;
  - a missing `timestamp` parameter at MacPowerParser.swift:11.

  `--warnings-as-errors` exists.
- **How:**
  - An optional Linux CI step that checks the ``` ``Symbol`` ``` links the code already uses.
  - Follow the Swift API Design Guidelines (https://www.swift.org/documentation/api-design-guidelines/). A grep
    found no `get`-prefixed methods except WidgetKit requirements.

### SW-24 — Package.swift hygiene checklist (P0, S)
1. Typed platforms `.macOS(.v27)`, `.iOS(.v27)` (SW-01).
2. Keep only the widget's two `unsafeFlags`, each with its comment. Swift Build is the default backend:
   `swift build --help` shows `(default: swiftbuild)`, and `native` is "deprecated" [verified 6.4.1]. W26-262:
   "Swift Build is now the default build system backend for Swift Package Manager". Whether Swift Build can
   express the app-extension setting without `unsafeFlags` is **[unverified]**.
3. Resources: the test fixtures' `.copy("Fixtures")` is right. The app's `.xcstrings` and icon are compiled by
   `build-app.sh`. Leave both as they are.
4. Language settings come from shared arrays (SW-01). Do not put `-Xswiftc` in the manifest.
5. CI smoke test: `swift package dump-package > /dev/null`.

## 4. Rejected or skipped

- **SW-23, noncopyable `Continuation`** (SE-0528, macOS 27; W26-262 "checks at compile time that you only resume
  it once").
  - **[verified 6.4.1, t10]** It cannot be captured by an escaping closure: "noncopyable 'c' cannot be consumed
    when captured by an escaping closure".
  - Every continuation in BatteryPulse is resumed from an escaping callback: `DispatchQueue.async`/`asyncAfter`
    in `BlockingWork`/`IDeviceListBuilder`, and `Process.terminationHandler` in `UpdateInstallSteps.run`.
  - The examples the research gave (BatteryNotifier, WidgetRefresher) contain no continuations.
  - A `Mutex<Continuation?>` box does compile, but it only re-creates `CheckedContinuation` and loses its
    leak check.
- **SW-22, `InlineArray`/`Span` for the SMC wire format.**
  - `SMCParamBlock` is already an 80-byte `[UInt8]` with explicit offsets (BatteryCore/SMC.swift:58-117). There is
    no tuple and no C struct. It is portable, and tested on Linux.
  - The call still needs a raw pointer at `IOConnectCallStructMethod`. The saving would be about 2 small
    allocations per key, for a dozen keys per refresh. Not worth the churn in a public BatteryCore API.
- **SW-10, typed notification messages:** see above.
- **`ExplicitSendable` group:** it fires on every caseless namespace `enum`, so it is noise.
- **Turning `PerformanceHints` on permanently.**
- **Experimental flags** (`Embedded`, `Lifetimes`, LTO or CRR outside the size research's single experiment).
- **Typed throws everywhere** (SE-0413).
- **`@inline(always)`, `@specialized`, `Iterable`, `UniqueArray`:** aimed at library hot paths.
- **The Subprocess package:** a dependency. Keep Foundation `Process`.
- **Module selectors:** there are no name clashes.
- **`isolated deinit` for `SMCClient`:** a plain `deinit` suffices (SW-07).
- **`weak let`:** no site (SW-07).

## 5. Added by the verifier

### V-01 — Runtime isolation checklist for SW-04 (P1, part of SW-04)
- **Why:** default main-actor isolation plus `InferIsolatedConformances` can attach the main actor to code that
  frameworks call from other threads. Swift 6 then traps at runtime (SE-0423 dynamic isolation checks). CI
  compiles the app but never runs it.
- **How:** after SW-04, on the maintainer's Mac, run the app built by `scripts/build-app.sh` from
  /Applications. Watch Console for "Incorrect actor executor assumption" or crashes while doing each of these:
  1. Install and Relaunch, from a local test release, in Debug.
  2. Click a notification, and get a notification while the app is frontmost.
  3. The menu bar icon on a light and a dark menu bar (the `AppearanceVariants` drawing handler).
  4. Raw Data, History, Demo Mode, Settings → Check Now and Clear History.
  5. Wake from sleep (the HistoryRecorder wake observer).
  6. Add the widget, and reload it after an update.
- **Effort:** S. **Benefit:** catches the only failure mode SW-04 adds.

### V-02 — Use `swift package migrate` as a report, never as the commit (P0, part of SW-03)
- **[verified 6.4.1]** It applied 4 fix-its: `@concurrent` on two protocol requirements and two helpers that
  don't need it. It also rewrote `Package.swift` with settings repeated per target and broken formatting.
- **How:** run it on a throwaway branch on macOS and read the diff. Hand-apply only `@concurrent` on functions
  that do synchronous heavy work before their first suspension. Write the manifest by hand (SW-01).

### V-03 — Remove the redundant `@MainActor in` now (P1, XS)
- WidgetRefresher.swift:53: `Task { @MainActor in … }` inside a `@MainActor` class's static method → `Task { … }`.
  An unstructured `Task` inherits the actor. This doesn't depend on SW-04.

### V-04 — Check whether `@preconcurrency import UserNotifications` is still needed (P2, XS)
- BatteryNotifier.swift:6. On macOS CI, try removing it. Or build once with
  `-Xswiftc -Wwarning -Xswiftc PreconcurrencyImport` (an experimental group, off by default, TC-diag
  `preconcurrency-import.md`). Remove it if the macOS 27 SDK build is clean **[unverified macOS 27]**.

### V-05 — Do the dead-code maps after SZ-02, or with `_main` as the only export (P0, part of SW-17)
- Without that, the macOS maps cannot show unused public BatteryCore/BatteryKit code (see SW-17). Run the
  sweep and the size work in this order:
  1. SZ-02 (export only `_main`)
  2. SW-17 maps
  3. Delete code
  4. SZ-05/SW-18 (`-Osize`)

### V-06 — Rely on the compiler's on-by-default hygiene groups (P2, no work)
- `VariableNeverMutated` with its `WeakMutability` sub-group, `UnnecessaryEffectMarker`, `UselessAvailabilityCheck`
  and `NoUsage` are default warnings in 6.4.1 [verified 6.4.1, t8 and t2 output; TC-diag]. With the SW-14 gate
  they become errors in CI automatically. No grep audits are needed for `weak var`, `var`→`let`, needless
  `await`, or redundant `#available` (there are 0 today).

## 6. Order for 0.6.1

1. **Manifest and gate:** SW-01, SW-24, SW-02, SW-14. One commit; the macOS job must stay at 0 warnings.
2. **Concurrency foundation:** SW-03 (with V-02), then SW-06, then SW-09, then V-03. Separate commits; check the
   macOS job after each.
3. **App isolation:** SW-04 + V-01, then SW-05 and SW-08 (names; shield on `replace`).
4. **Less code:** SZ-02 → SW-17 (V-05) → delete what the maps and index prove unused → SW-20 rules.
5. **Diagnostics and safety:** SW-12 (logging and signposts; they feed the speed measurements), SW-13 (BatteryCore).
6. **As time allows:** SW-07, SW-11, SW-15, SW-16, SW-18 (with SZ-05), SW-19, SW-21, V-04.

## 7. Still to confirm on macOS 27 (CI or the maintainer's Mac)

- **Toolchain:** whether `@diagnose(StrictMemorySafety, as: warning)` behaves the same on Xcode 27's Swift 6.4.0
  as on 6.4.1 (where it does not turn the check on).
- **SDK, Sendable:** `URLSessionTask` Sendable (SW-06 `DownloadWatcher`); `CGImage` Sendable (`AppearanceVariants`).
- **SDK, other:**
  - the WidgetKit calling thread (SW-04, the reason the widget is excluded);
  - concrete `NotificationCenter` message types (SW-10);
  - whether `@preconcurrency` is still needed (V-04).
- **Linker:** the `# Dead Stripped Symbols:` section with `-exported_symbol _main` on Xcode 27's ld (SW-17).
- **Build:** `MemberImportVisibility` fix-ups in Darwin-only files (SW-02); `migrate` output on the Darwin-only
  code (SW-03).

## 8. Evidence files

All under `/tmp/claude-0/-home-user-BatteryPulse/11e28672-c0db-5a09-a8bc-b94b73c785d3/scratchpad/v061/swift/verify/`:

| Files | What they show |
|---|---|
| `exp/t1.swift` | `Mutex` with `[AnyObject]` fails |
| `exp/t2.swift` | `@concurrent` in a `@MainActor` enum; plain `deinit`; `isolated deinit`; `Mutex` for `ResumeOnce` and `DownloadWatcher`; `weak let`; `~Sendable`; the shield |
| `exp/t6.swift` | no `propertyList(from:)` without `format:` |
| `exp/t8.swift` | warning flag order; `WeakMutability` on by default |
| `exp/t10.swift` | noncopyable `Continuation` in an escaping closure fails |
| `exp/t11.swift` | `onChange` hops are needed under `MainActor` default |
| `exp/t12.swift`, `exp/t13.swift` | token box alternatives |
| `exp/t14.swift`, `exp/t15.swift`, `exp/t16.swift` | `@diagnose` behaviour |
| `exp/obs/main.swift` | `Observations` semantics |
| `exp/pkg/Package.swift` | tools-6.4 manifest; `.v27`; the import-check no-op |
| `exp/pk.swift` | `package` vs `public` linkage |
| `feat.log` | 0 diagnostics with all five features |
| `migrate.log`, `repo2/` (git diff) | the migrate tool's output |
| `bpulse.map`, `discarded-core.txt` | Linux release map |
| `cilog/macos-job.txt` | macOS 27 CI: Xcode 27.0, Swift 6.4.0, 0 warnings, 330 tests |
