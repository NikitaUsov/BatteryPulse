# Audit "app-core": Sources/BatteryPulseApp/App and Sources/BatteryPulseApp/Updates (base 6133b4f)

Read-only audit. I read all 15 files in the area in full (3,372 lines):
- `App/`: `BatteryPulseApp`, `AppSettings`, `AppDevices`, `AboutView`, `BatteryNotifier`, `DemoController`,
  `HistoryRecorder`, `WidgetRefresher`, `Localized`, `Motion`, `WindowLook`, `ToneStyle`;
- `Updates/`: `UpdateChecker`, `UpdateInstaller`, `UpdateViews`.

I checked them against `v061/playbook.md` and CLAUDE.md. IDs are `AC-nn`. "Owner" is the playbook work
package whose files the change touches (§3.2).

Scratch evidence is in `v061/appcore/`:
- `obs.swift`: the `@Observable` equality test;
- `bench/`: the release-notes benchmark, which uses BatteryCore through a path dependency and leaves
  the repository untouched.

## Already covered by the playbook (not repeated)

The following items already cover this area:
- SW-09 with V-03: the four re-armed `withObservationTracking` loops (`HistoryRecorder.swift:54`,
  `BatteryNotifier.swift:79, 107`, `WidgetRefresher.swift:25`) and `Task { @MainActor in }` at
  `WidgetRefresher.swift:53`.
- E7 tolerances at these sites:
  - `UpdateChecker.swift:70, 73`;
  - `UpdateInstaller.swift:203`;
  - `DemoController.swift:212`.
- SW-05 / SW-R4: `Task.detached` at `UpdateInstaller.swift:128, 149, 159`, and `@concurrent` on
  `verify`/`replace`.
- SW-06: `DownloadWatcher`.
- SW-12: the `update` logger, and making `UpdateInstaller.swift:523` private.
- SEC-01, SEC-02, SEC-03 and SEC-19 (`AppLinks`, `UpdateChecker.endpoint`): the update channel.
- SUI-06: `BatteryFormatter.app` is a computed `static var` that builds a new formatter and closure
  on every call.
- E8 recorder half: `HistoryRecorder.recordNow(refreshing:)` forces a read.
- V-04: `@preconcurrency import UserNotifications`.
- SW-04 / WP-10: 38 redundant `@MainActor`.
- E12 (progress KVO, rejected), SEC-14 (`endPreviousExtension` by name, rejected) and SEC-15/SEC-17
  (`hdiutil`, `clearQuarantine`, TOCTOU): left alone, as the playbook decides.

Verdict in one line: the area is careful and well commented. Two findings have measurable weight: the
release notes are re-parsed in `UpdateView.body` five times a second during a download (AC-01), and
Demo Mode wakes the app while nothing shows it (AC-06). The rest is small, exact cleanup that lowers
the code count.

---

## P2

### AC-01 [speed] The Software Update window re-parses the release notes on every body evaluation, 5×/s during a download
- **Where:**
  - `Updates/UpdateViews.swift:65`: `.onChange(of: phaseKind)`. It reads `updater.installer.phase` in
    `body`, so `body` depends on the whole `phase` value, including the download fraction.
  - `Updates/UpdateInstaller.swift:198-205`: the 200 ms poll assigns `.downloading(fraction)`.
  - `UpdateViews.swift:126` → `notes(_:)` at `:256-262`: `ReleaseNotes.inlineMarkdown` and then
    `AttributedString(markdown:options:baseURL:)`. `content` is a computed `@ViewBuilder` property,
    so it runs inside every `body` evaluation.
  - The same evaluation calls `installer.blocker(for:)` twice while idle (`:188` and `:235`). Each
    call makes two `access(2)` calls (`UpdateInstaller.swift:80-82`) and runs the path policy.
- **Measured:**
  - `ReleaseNotes.inlineMarkdown` costs **2.3 ms per call** on 0.6.0's real notes
    (`.github/release-notes.md`, 8,707 bytes; release build, Linux VM, 500 runs, two runs:
    2.29 / 2.37 ms).
  - `AttributedString(markdown:)` comes on top. It can't be measured on Linux: the Markdown
    initializer isn't in swift-corelibs.
  - Swift 6.4's `@Observable` skips equal assignments (see AC-02), so the cost comes only from real
    fraction changes. During a download that is up to 5 per second, which is about 12 ms/s of
    main-thread parsing plus the AttributedString pass. Every hover or focus change re-evaluates
    `body` too.
- **Change:**
  - Move the notes into a value-input subview, so SwiftUI skips its body while the inputs are equal
    (UI-5):
    `private struct ReleaseNotesText: View { let notes: String; let baseURL: URL; var body: some View { Text(Self.render(notes, baseURL)).textSelection(.enabled)… } }`.
    Move `notes(_:)` into it as `static func render`.
  - In `content`, use `ReleaseNotesText(notes: release.notes, baseURL: release.pageURL)` inside the
    existing `ScrollView`.
  - In the `.available` branch, compute `let blocker = updater.installer.blocker(for: release)` once.
    Pass it to `installStatus` and `installActions` instead of calling `blocker(for:)` in each.
  - This adds no state and no strings. SEC-02's `OpenURLAction` then goes on that one subview.
- **Measure:**
  - On the M5, in Instruments (SwiftUI + Time Profiler), install a test release in-app, or run a
    DEBUG-only loop that sets `phase = .downloading(x)` 5×/s with the window open.
  - Before: `ReleaseNotes.inlineMarkdown` and `AttributedString(markdown:)` run about 5 times a
    second. After: once, when the window opens.
  - The Software Update window looks the same, and text selection in the notes survives the
    download.
- **Risk:** none expected. The same text is rendered, and it stops being rebuilt during the
  progress.
- **Owner:** WP-6. **Rule:** UI-1, UI-5.

---

## P3

### AC-02 [dead-code] Equality guards before `@Observable` assignments duplicate what the macro already does
- **Where:**
  - `App/Motion.swift:233-234` (`LowPowerMode`);
  - `App/WindowLook.swift:176-177` (`SystemAppearance.update()`).
  - The same pattern outside this area, for their owners: `BatteryKit/AccessoryMonitor.swift:60, 62`
    (WP-7) and `BatteryKit/IDeviceMonitor.swift:621` (WP-7).
- **Evidence (Swift 6.4.1):**
  - `swiftc -Xfrontend -dump-macro-expansions` on an `@Observable` class shows that every setter
    starts with `guard shouldNotifyObservers(_x, newValue) else { … }`. This is a private generic
    overload set that the macro emits into the type, and it uses `!=` for `Equatable` values.
  - The runtime check in `v061/appcore/obs.swift`: assigning an equal value fires no `onChange`.
  - The check is generated at compile time, so it doesn't depend on the OS's Observation runtime.
- **Change:**
  - In `LowPowerMode`, write `self.isEnabled = ProcessInfo.processInfo.isLowPowerModeEnabled`.
  - In `SystemAppearance.update()`, write `isDark = Self.readIsDark()`.
  - In the BatteryKit sites, assign directly.
  - Keep the guards that aren't on Observable storage:
    - `WindowVisibilityReader.updateNSView` writes a `Binding` during a view update;
    - `BatteryNotifier` guards `UserDefaults` writes, which post `didChangeNotification`.
- **Measure:**
  - Build on both jobs.
  - `swiftc obs.swift && ./obs` prints `same value fired: 0`.
  - Existing `AccessoryMonitorTests` and `IDeviceMonitorTests` still pass on Linux.
- **Risk:** none. The comparison is the same one, now done once by the generated setter.
- **Owner:** WP-11 (less code). The BatteryKit lines go with WP-7 if it lands first. **Rule:** DC-6.

### AC-03 [speed] `LaunchAtLoginModel` asks `SMAppService` for its status twice per refresh
- **Where:** `App/AppSettings.swift`:
  - `:273` and `:275`: the property initializers;
  - `:280-283`: `refresh()`;
  - `:305` and `:307`: `LaunchAtLogin.isEnabled` and `.requiresApproval`, each its own
    `SMAppService.mainApp.status` read.
  - `refresh()` runs when General settings appear and on every `didBecomeActiveNotification` while
    Settings or Welcome is open (`Settings/SettingsView.swift:137-139`).
  - The model is created by `@State` in `BatteryPulseApp.swift:19`, so at launch unless the Xcode 27
    `@State` macro creates it lazily (W26-269) **[unverified]**.
- **Change:**
  - Read the status once:
    - `LaunchAtLogin.status: SMAppService.Status { SMAppService.mainApp.status }`;
    - in the model, `private(set) var status = LaunchAtLogin.status`, with `isEnabled` and
      `requiresApproval` computed from it (`status == .enabled`, `status == .requiresApproval`);
    - `refresh()` becomes `status = LaunchAtLogin.status`.
  - The views read the same two properties, so they don't change.
- **Measure:**
  - On the M5, Time Profiler: count `-[SMAppService status]` calls at launch and per app activation
    with Settings open. Expect 2 → 1 per refresh, and 2 → 1 or 0 at launch.
  - Toggle Launch at login, and approve it in System Settings: the toggle and the approval note
    behave as before.
- **Risk:** none. The values are the same. Whether each read is an XPC round trip to the
  background-task daemon is **[unverified]**; the change is correct either way.
- **Owner:** WP-10 (mechanical app pass). `AppSettings.swift` is otherwise touched only by WP-6's
  `AppLinks` hunk. **Rule:** none; it keeps avoidable IPC off the launch path.

### AC-04 [readability] Split `UpdateInstallSteps` out of `UpdateInstaller.swift` and stop decoding the Info.plist twice
- **Where:**
  - `Updates/UpdateInstaller.swift` is 544 lines and holds four things:
    - the `@Observable` installer (`:22-268`);
    - the user-facing error texts (`:270-309`);
    - `DownloadWatcher` (`:311-329`);
    - `UpdateInstallSteps`, the off-main disk, `hdiutil` and code-signing steps (`:331-543`).
  - Identical Info.plist decoding at `:499-503` (`checkBundle`) and `:533-537` (`removeLeftovers`).
- **Change:**
  - First commit, a pure move: `UpdateInstallSteps` goes to `Updates/UpdateInstallSteps.swift`
    unchanged (`git diff -M` shows a rename).
  - Then add one helper:
    `private static func infoDictionary(ofBundleAt url: URL) -> [String: Any]?` (read
    `Contents/Info.plist` with `PropertyListSerialization`).
    - Both call sites use it.
    - Its doc comment says why it isn't `Bundle(url:)`: Bundle caches instances per path, so the
      swapped path could return the old version's dictionary.
  - This gives WP-6's `@concurrent` on `verify`/`replace` (SW-05/SW-R5) and WP-10's `nonisolated`
    on this type a single file to change.
- **Measure:**
  - `git diff --stat -M` is rename-dominated.
  - The macOS job builds, and `UpdateInstallTests` doesn't change.
  - On the M5, the §2.6 in-app update check: install, relaunch, and the leftover is deleted at the
    next launch.
- **Risk:** low. Conflicts with WP-6's own edits, so make it WP-6's first commit.
- **Owner:** WP-6. **Rule:** readability; SW-R5 placement.

### AC-05 [readability] The app re-spells the "unversioned build" constant BatteryCore already has
- **Where:**
  - BatteryCore already defines `UpdateInstallPolicy.unversioned = AppVersion(parts: [0, 0, 0])`
    (`BatteryCore/UpdateInstall.swift:91`), and `UpdateInstallTests.swift:128` uses it.
  - The app writes the literal three times: `Updates/UpdateChecker.swift:52` (`isUnversioned`) and
    `:59` (the fallback), and `App/AppSettings.swift:153` (`WhatsNewPolicy.markSeen`).
- **Change:** use `UpdateInstallPolicy.unversioned` at the three sites.
  - Leave `AboutView.swift:53` (`short != "0.0.0"`) as a string comparison. `AppVersion`'s `==`
    pads with zeros, so switching to it would also treat "0" and "0.0" as unversioned, which is a
    behaviour change.
- **Measure:**
  - Build.
  - `grep -rn "parts: \[0, 0, 0\]" Sources/BatteryPulseApp` returns 0 lines.
  - A CI artifact (unversioned) still never checks automatically, and What's New doesn't record it.
- **Risk:** none.
- **Owner:** WP-6. **Rule:** one definition per constant (SEC-R3 spirit).

### AC-06 [energy] Demo Mode's clock runs while no window or popover shows it
- **Where:**
  - `App/DemoController.swift:199-217`: the clock;
  - `:224-247`: `advance(by:)`;
  - `:187`: `begin` always starts the clock.
- **Issue:**
  - On a scene the clock ticks every second; in an animation, every 200 ms.
  - Each tick sets `DemoBatteryProvider.battery`. That makes `BatteryMonitor.refresh()` expand the
    scene into M5-style raw dictionaries and parse them. Then the menu bar label re-renders, and
    the three app observers each schedule a Task that returns on `isOverridden`.
  - Demo Mode survives closing every window (on purpose: the menu bar keeps showing it), and it
    ends only with Stop or by hiding the Developer section. A forgotten Demo Mode therefore wakes
    the app once a second indefinitely, and a playing tour keeps changing pages nobody sees.
- **Change (gated):**
  - Pause the clock while no tracked window is open and the popover isn't shown. Keep `elapsed`, so
    the tour resumes where it stopped.
  - Concretely:
    - `DockIconPolicy` exposes `static var hasOpenWindows: Bool { !openWindows.isEmpty }`;
    - `DemoController` runs one named observation task (SW-R7 form) over
      `DockIconPolicy.hasOpenWindows || monitor.liveRefreshInterval != nil`. The popover's
      `liveRefresh` makes the second term true while the popover is visible.
    - The task calls `stopClock()` / `startClock()`.
  - Don't key it on `liveRefreshInterval` alone: a page without live values (`showsLiveValues ==
    false`) would freeze the tour there.
  - `DockIconPolicy.openWindows` would need to become `@Observable` storage, or the task re-checks it
    on `windowAppeared`/`windowDisappeared`.
- **Gate:** adopt only if, on the M5 with Demo Mode on and every window closed, a 10-minute
  `top -stats pid,cpu,idlew` or `powermetrics --samplers tasks` run shows wake-ups and CPU clearly
  above S1 (the idle menu bar). Otherwise drop it. It's a developer feature.
- **Measure:** the same run after the change shows S1 levels. The tour, Pause/Play, Previous/Next
  and Stop behave as before with the window open (§2.6, Demo Mode).
- **Risk:** low to medium. The demo must look the same whenever anything shows it.
- **Owner:** WP-4. **Rule:** EN-6.

### AC-07 [readability] Small fixes in comments and code that no longer say what is true
- **`App/WindowLook.swift:14`:** a 136-column comment line (the limit is 120). A reflow merged two
  sentences, and swift-format doesn't rewrap comments. Rewrap lines 10-15.
- **`App/AppDevices.swift:55-56`:** "Typed as optional, so this compiles whether the initializer is
  failable or not."
  - Settle it on the macOS 27 SDK in the macOS CI job.
  - If `UTTagClass.init(rawValue:)` is non-failable, write
    `let tagClass = UTTagClass(rawValue: "com.apple.device-model-code")`, drop the optional binding
    in the `guard` and delete the comment.
  - If it is failable, change the comment to say so.
- **`App/AppSettings.swift:120-124`:** `migrate()` calls `removeObject` for three legacy keys on
  every launch, present or not.
  - `BatteryNotifier.swift:124` already guards its removal with `object(forKey:) != nil`, because
    every write posts `didChangeNotification` and goes to cfprefsd.
  - Guard these the same way:
    `for key in [legacyMenuBarStyleKey, legacyMenuBarIconKey, legacyGlassCardsKey] where defaults.object(forKey: key) != nil { defaults.removeObject(forKey: key) }`.
  - DC-5 keeps the migration itself.
- **Measure:**
  - Lint passes.
  - On the M5: `sudo fs_usage -w -f filesys cfprefsd | grep io.github.nikitausov` during a launch on
    an already-migrated profile shows no plist rewrite caused by `migrate()` **[unverified that
    there is one today]**.
- **Risk:** none.
- **Owner:** WP-11 (comments), WP-10 (`AppSettings`/`AppDevices` pass). **Rule:** "comments that lie".

---

## Checked, no change proposed

- **Three `UserDefaults.didChangeNotification` observers** (`BatteryPulseApp.swift:176`,
  `BatteryNotifier.swift:49`, `DemoController.swift:90`):
  - Each runs a few dictionary reads per write. Writes are rare: settings, window-frame autosave,
    the alert state when it changes.
  - The global observer is also what catches `MenuBarExtra(isInserted:)` writing `showInMenuBar`
    when the item is dragged out, so the Dock icon comes back.
  - Per-key KVO would add code without a measurable win.
- **`WindowAppearanceSetter`:** it sets `NSWindow.appearance` instead of using
  `.preferredColorScheme(.dark)`. On macOS, `preferredColorScheme(nil)` doesn't reliably give a
  window back the system appearance, which is exactly what the comment needs. Keep.
- **`WindowOpener`** (a captured `OpenWindowAction`): SwiftUI has no app-level window opener. The
  label, popover and tracked windows capture it in every launch mode. Keep.
- **`WindowVisibilityReader`** (occlusion through an `NSView`): the playbook rejected `scenePhase`
  and `appearsActive`. Keep.
- **`endPreviousExtension`:**
  - `proc_listallpids` returns a PID count, and the byte-size argument is right.
  - `String(decoding:as:)` is the non-deprecated replacement for `String(cString:)` on `[CChar]`.
  - It runs only on the first launch of a new version. Keep (SEC-14).
- **URL API style** (`appendingPathComponent`, `URL(fileURLWithPath:)`, `.path`: 22, 6 and about 40
  uses in `Sources`):
  - Apple only soft-deprecates them (deprecated in a future version), so they produce no
    warnings.
  - Migrate to `appending(path:directoryHint:)`, `URL(filePath:)` and `path(percentEncoded:)` only if
    the SW-R2 gate (`-Wwarning DeprecatedDeclaration` on Xcode 27) flags them. Otherwise it is churn.
- **`UpdateInstaller` flow:** no correctness bug found.
  - Cancel works only in `.downloading`, and quitting skips the install after `verify`.
  - The async `download(for:delegate:)` temp file is moved or deleted on every path.
  - `run(_:_:)` sets `terminationHandler` before `run()` and clears it on failure.
- **The user-agent string, duplicated** (`UpdateChecker.swift:160`, `UpdateInstaller.swift:228`):
  when SEC-03 introduces the ephemeral `URLSessionConfiguration`, set it once in
  `httpAdditionalHeaders`.
- **For the core audit:** `ReleaseNotes.inlineMarkdown` itself costs 2.3 ms for 8.7 KB (about
  260 ns per byte). It does two `replacing` passes, then `split` and `map(String.init)` of every line.
  After AC-01 it runs once per window, so it's not worth optimizing.
