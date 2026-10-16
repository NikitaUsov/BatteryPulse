# Audit "app-chrome": MenuBar, Settings, Welcome and the widget (base 6133b4f)

Read-only audit. I read all 9 files in the area in full (1,847 lines):
- `Sources/BatteryPulseApp/MenuBar/`: `MenuBarLabel` (76), `BatteryIconView` (343), `PopoverView` (197),
  `PopoverAccessories` (88);
- `Sources/BatteryPulseApp/Settings/`: `SettingsView` (498), `WindowLookSettings` (240);
- `Sources/BatteryPulseApp/Welcome/`: `WelcomeView` (58), `AppIconView` (140);
- `Sources/BatteryPulseWidget/BatteryPulseWidget.swift` (207).

I followed the calls they make into BatteryCore (`BatteryIconState`, `MenuBarContent`,
`BatteryPresentation`, `WidgetTimelinePlan`, `AccessoryParser`), into `App/` (`WindowOpener`,
`LaunchAtLoginModel`, `Phrases`, `Motion.swift`) and into `Tests/BatteryCoreTests/MotionGuardTests.swift`,
and checked them against `v061/playbook.md` and CLAUDE.md. IDs are `CH-nn`. "Owner" is the playbook
work package whose files the change touches (§3.2). All paths below are relative to
`Sources/BatteryPulseApp/` unless they start with `Sources/` or `Tests/`.

## Already covered by the playbook or a sibling audit (not repeated)

- **SUI-06:** `BatteryFormatter.app` is a computed `static var`. In this area it is built in
  `MenuBarLabel.swift:27` and `:65` (twice per label body), `PopoverView.swift:135`,
  `PopoverAccessories.swift:54` (once per accessory part) and `SettingsView.swift:374`.
- **SUI-07:** the popover re-runs its whole body on every 2 s reading (`PopoverView.swift:19`
  reads `monitor.snapshot`). It is gated on body counts.
- **SUI-10 / UI-8:** `SettingsView.swift:420` `.task` and `PopoverView.swift:124` `.task(id:)` get names.
- **SUI-13 (WP-9):** split `SettingsView.swift` into one file per pane. `Crossfade` (`:46-72`) and
  `PreviewTilePicker` (`:275-364`) are shared components, so they move with that split, not into a
  pane file. `MotionGuardTests.glassAllowList` and CLAUDE.md's glass list name `SettingsView.swift`
  and must follow `PreviewTilePicker`.
- **SUI-20 (rejected):** keep the `didBecomeActiveNotification` `onReceive` (`SettingsView.swift:138`).
- **SW-06:** `AppearanceVariants` (`BatteryIconView.swift:325`) stays `@unchecked Sendable`: it is
  immutable and holds `CGImage`s.
- **SW-04 / WP-10:** `@MainActor` on `MenuBarIconRenderer` (`BatteryIconView.swift:266`) and on the
  two static flags (`PopoverView.swift:114`, `AppIconView.swift:17`) become redundant under default
  main-actor isolation. The widget stays nonisolated. Its `Task { @MainActor in … }` hops
  (`BatteryPulseWidget.swift:42, 48`) are needed because `MacBatteryProvider` is `@MainActor`
  (`Sources/BatteryKit/MacBatteryProvider.swift:23`).
- **SZ-07:** the widget copies every `.lproj` (`scripts/build-app.sh:90`) but uses about 15 strings.
  The size research leaves per-key filtering for later.
- **SZ-02:** the widget links all of BatteryKit for `MacBatteryProvider`. Dead-stripping with
  `_main` as the only export is what removes the rest.
- **AC-03 (app-core):** `LaunchAtLoginModel.refresh()` reads `SMAppService.status` twice. CH-02 below
  is about how many times the Settings views *call* `refresh()`, which multiplies that.

Verdict in one line: the area is small and careful. The menu bar icon is rendered once per state
change, and `level` only changes on whole percents because `Current Capacity` / `Max Capacity` is in
percent. Its one energy-relevant defect is the opposite of waste: the menu bar's power poll can
switch itself off while power is still shown (CH-08). The findings are:
- a lifecycle bug in the menu bar label, by Apple's documented `Group` semantics (CH-08);
- one CLAUDE.md rule violation that the guard test misses (CH-01);
- a likely SwiftUI misuse that multiplies side effects in Settings (CH-02);
- a stale permission message (CH-03);
- small, exact cleanups (CH-04 to CH-07, CH-09 to CH-11).

This revision re-checked every line reference of the first pass against `6133b4f` (all hold) and
added CH-08 to CH-11.

---


## P2

### CH-08 [bug] The menu bar label's lifecycle modifiers sit on a `Group`, so one item disappearing stops the power poll
- **Where:** `MenuBar/MenuBarLabel.swift`.
  - `:28-40`: `Group { if demo.isActive { Image } ; if content.showsIcon(title:) { icon } ; if !title.isEmpty { Text } }`.
    It has 1 to 3 members, and which ones exist changes at run time.
  - `:47` `.onAppear { WindowOpener.openWindow = openWindow }`, `:48-51`
    `.onChange(of: content.liveRefreshInterval, initial: true) { monitor.setLiveRefreshInterval(interval, for: "menuBar") }`,
    `:52` `.onDisappear { monitor.setLiveRefreshInterval(nil, for: "menuBar") }`, all applied to that `Group`.
  - Apple's `Group` page (fetched to `v061/chrome/group.json`): "The modifier applies to all members
    of the group — and not to the group itself. For example, if you apply `onAppear(perform:)` to the
    above group, it applies to all of the views produced by the `if isLoggedIn` conditional, and it
    executes every time `isLoggedIn` changes." So each member gets its own `onAppear`,
    `onChange(initial:)` and `onDisappear`.
  - `MenuBarContent.liveRefreshInterval` (`Sources/BatteryCore/MenuBarContent.swift:90-92`) depends
    only on `.power`. `BatteryMonitor.setLiveRefreshInterval` (`Sources/BatteryKit/BatteryMonitor.swift:80-90`)
    keeps one request per client, so a `nil` from any member removes the label's request.
- **Failure scenario** (no BatteryPulse window open, menu bar set to icon + power, so the label is the
  only poll client):
  1. Settings → Menu Bar → turn "Battery icon" off. The icon member disappears, its `onDisappear`
     sends `nil` for `"menuBar"`. The `Text` member stays, and its `onChange` doesn't fire because
     the interval is still 10 s. The 10 s poll stops; the watts in the menu bar change only when an
     IOPS notification happens to trigger a read.
  2. The same when Demo Mode stops (the demo `Image` member disappears).
  3. With the icon turned off, a reading whose title is empty (no snapshot yet, or no value for any
     chosen item) makes `showsIcon(title:)` add the icon member as a fallback; the next full reading
     removes it again, and its `onDisappear` sends `nil`. Whether that `nil` lands before or after
     the `Text` member's `onChange(initial:)` is up to SwiftUI's ordering.
  - The popover (2 s) and the main window mask it while they are open, which is why it can go
    unnoticed. It heals only when a member appears again (its `onChange(initial: true)` re-sends 10 s).
  - Related: WP-0 plans the `menuBarReady` signpost at "first `MenuBarLabel` appearance" (playbook
    §2.2, WP-0 touches). As an `.onAppear` on this `Group` it would fire once per member and again
    each time a member appears.
- **Change** (keeps `Group`, which the status item needs to flatten an image and a text; no `HStack`):
  1. Delete `.onDisappear` (`MenuBarLabel.swift:52`). Above `.onAppear` (`:47`) add the comment
     `// A modifier on a Group runs for each member: these two are idempotent, and the request ends with the scene (BatteryPulseApp).`
     Both remaining handlers are idempotent: the same `openWindow`, and the same interval for the
     same client (`isNewRequest` is false after the first call, `effective` doesn't change, so no
     extra read and no reschedule).
  2. In `App/BatteryPulseApp.swift`, after `.menuBarExtraStyle(.window)` (`:111`), end the request
     with the menu bar item, through `Scene.onChange(of:initial:_:)`:
     ```swift
     .onChange(of: showInMenuBar) { _, isShown in
         if !isShown { monitor.setLiveRefreshInterval(nil, for: "menuBar") }
     }
     ```
     Turning the item back on recreates the label, and its `onChange(initial: true)` asks again.
  3. WP-0's `menuBarReady`: emit it behind a `static var` once-flag (the pattern of
     `AppIconView.hasDrawnIn`), not as a bare `.onAppear` on the `Group`.
- **Measure:** on the M5, with WP-0's `refresh` signposts (`trigger: poll`) in Instruments → Points of
  Interest, or before WP-0 a `#if DEBUG print(client, interval)` in `setLiveRefreshInterval`. No
  window open, menu bar icon + power:
  - Baseline: one `poll` refresh about every 10 s.
  - Turn "Battery icon" off in Settings, close Settings, wait 60 s. Before: `nil` for `"menuBar"`
    is logged and the `poll` refreshes stop. After: no `nil`, about six `poll` refreshes.
  - Start Demo Mode, stop it from the popover, close all windows: the same before/after.
  - Turn "Show in menu bar" off: after the change, exactly one `nil` and no further `poll`
    refreshes (S1 idle energy unchanged from 0.6.0). Turn it on: one 10 s request, polls resume.
  - Welcome, About, Software Update and Settings still open from the Dock menu right after launch
    (`WindowOpener.openWindow` is still captured).
  - If the first "Before" step does not reproduce on macOS 27 (the status item host would then not
    distribute lifecycle modifiers), keep step 3 and drop steps 1–2.
- **Risk:** low. The only behaviour change is when the request ends: with the item's removal instead
  of with a label member's disappearance. The label also disappears at quit, where the request no
  longer matters.
- **Owner:** WP-2 (owns `MenuBarLabel.swift` and the live-refresh plumbing), with a 3-line hunk in
  WP-4's `BatteryPulseApp.swift`; step 3 is WP-0. Raise to P1 if the first "Before" step reproduces.
  **Rule:** "real bugs"; EN-6 (the poll's lifetime follows what is visible).

### CH-01 [readability] A hard-coded animation outside `Motion.swift`, which `MotionGuardTests` doesn't catch
- **Where:**
  - `Welcome/AppIconView.swift:83-89`: `extension MotionPolicy { fileprivate var iconDrawIn: Animation? { allowsFlourish ? .smooth(duration: 0.8).delay(0.2) : nil } }`.
  - CLAUDE.md, Motion: "no hard-coded animation outside `Motion.swift`".
  - `App/Motion.swift:31-45`: the preset table lists every other preset; `iconDrawIn` is missing.
  - Checked by grep over `Sources/BatteryPulseApp` and `Sources/BatteryPulseWidget`
    (`\.(smooth|spring|snappy|bouncy|easeIn|easeOut|easeInOut|linear|interactiveSpring|interpolatingSpring)\b`
    outside `Motion.swift`): this is the **only** animation built outside `Motion.swift`. The
    other hits are `.progressViewStyle(.linear)` (`Updates/UpdateViews.swift:80, 159, 164, 169`) and
    `motion.linear(…)` (`App/DemoController.swift:231`).
  - Why the guard misses it: `Tests/BatteryCoreTests/MotionGuardTests.swift:149-162` only inspects
    the *arguments* of `withAnimation(…)` and `.animation(…)`. `withAnimation(motion.iconDrawIn)`
    (`AppIconView.swift:79`) goes through `motion`, and the constructor sits in a property elsewhere.
- **Change:**
  1. Move the property, unchanged, into `App/Motion.swift` after `quickFade`, without `fileprivate`.
     Add a table row: `| ``iconDrawIn`` | smooth, 0.8 s after 0.2 s, once | `nil` | `nil` |`.
     Delete `AppIconView.swift:83-89`.
  2. In `MotionGuardTests`, inside `if !buildsPresets` (`:150`), flag an `Animation` built from
     scratch: `#/(?:^|[^\w)\]])\.(?:smooth|snappy|bouncy|spring|interactiveSpring|interpolatingSpring|easeIn|easeOut|easeInOut|linear|timingCurve)\s*\(/#`
     plus `words(#/\bAnimation\s*\.\s*[a-z]/#)`.
     - The leading class keeps `motion.linear(0.2)` and `.progressViewStyle(.linear)` legal.
     - It avoids a lookbehind; the existing rules use only lookaheads.
  3. Add one case to `catches(source:)`: `"var a: Animation? { on ? .smooth(duration: 0.8).delay(0.2) : nil }"`.
     Add two cases to `allows(source:)`: `".progressViewStyle(.linear)"` and
     `"withAnimation(motion.linear(0.2)) { x = 1 }"` (the second is already there, `:459`).
- **Measure:**
  - Linux: `swift test --filter MotionGuardTests`.
    - Before the move, the new rule flags `AppIconView.swift:87`. After the move, it passes.
    - `allowListedFilesExist` still passes.
  - On the M5, the welcome window: the pulse line draws in once per launch with full motion. It
    doesn't draw in under Reduce Motion or Low Power Mode, or on the second opening.
- **Risk:** none at run time; the property moves without changing. The new regex could flag a
  future legitimate use, such as a `ProgressView` style named like an animation followed by `(`.
  The `allows(source:)` cases pin the known ones.
- **Owner:** WP-12 (guards). The 7-line move goes with it; no other package edits `AppIconView.swift`.
  **Rule:** UI-13 *(existing)*, CLAUDE.md Motion.

### CH-02 [bug] **PLAUSIBLE**: lifecycle and presentation modifiers sit on `Section`s, so they may run once per row
- **Where** (`Settings/SettingsView.swift`):
  - `:137-140`: `.onAppear { launchAtLogin.refresh() }` and `.onReceive(didBecomeActiveNotification)`
    on the Section at `:105`. It has **3 rows**: the "Open at login" `VStack` (`:106`), the
    "Window to open" `Picker` (`:131`) and the welcome `Toggle` (`:135`).
  - `:420-428`: `.task { isDenied = … }` and `.onChange(of: [chargeLimit, …])`. The latter starts a
    `requestAuthorization` `Task`. They sit on the Section at `:401`, which has **1 or 2 rows**: 2 in
    the denied branch, a `Text` and a `Button`.
  - `:460-470`: `.confirmationDialog(isPresented: $confirmsClearing)` on the Section at `:441`, which
    has **2 rows**: the `Toggle` and the `LabeledContent`.
- **Why it matters:**
  - Apple documents for `Group` that "any modifier you apply to the group affects all of that
    group's members" (`developer.apple.com/documentation/swiftui/group`, fetched to
    `v061/chrome/group.json`). The `Section` page says nothing either way.
  - The same page's example says it outright for `onAppear(perform:)`: on a `Group` it "applies to
    all of the views produced by the" conditional "and it executes every time" the condition changes.
    CH-08 is the documented `Group` case in this area.
  - Inside `Form` and `List`, a `Section`'s content is flattened into rows the same way. That is
    why `.listRowBackground` and `.listRowSeparator` on a `Section` reach every row.
  - **[unverified on macOS 27]** whether `onAppear`, `onReceive`, `task`, `onChange` and
    `confirmationDialog` are distributed too. If they are:
    - `refresh()` runs 3× per appearance and per app activation, which with AC-03's two
      `SMAppService.status` reads is 6 XPC reads. With the Welcome window also open (it embeds
      `GeneralSettings` too), it is 12.
    - Each toggle of an alert starts up to 2 authorization tasks.
    - Two dialog presenters share one binding.
- **Change:** attach each modifier to one concrete view that always exists. Each move is a cut and
  paste:
  - `:137-140` → the "Open at login" `VStack` (close of `:130`), the row whose state it refreshes.
  - `:460-470` → `Button("Clear History…", role: .destructive)` (`:446`). This is Apple's documented
    placement: the control that presents the dialog.
  - `:420-428` → the first section's `Picker("When charged to", …)` (`:378-381`), with the comment
    `// On one row: a modifier on a Section applies to each of its rows.` Leave `isDenied` where it is.
- **Measure:** on the M5 with a debug build in Xcode 27, before and after. Use symbolic breakpoints
  that log and continue.
  - `-[SMAppService status]`: open Settings, then switch to Finder and back. Expect 6 → 2 per
    activation if the modifiers were distributed; 2 → 2 if not. Either way the code is clearer.
  - `-[UNUserNotificationCenter getNotificationSettingsWithCompletionHandler:]` on opening the
    Notifications tab, and `requestAuthorizationWithOptions:completionHandler:` when "When the Mac
    gets hot" is turned on.
  - Clear History… shows one dialog. Cancel leaves the history. Clear History empties the charts
    once (a breakpoint on `HistoryStore.clear`).
  - Login item, notification and Clear History behave as in 0.6.0.
- **Risk:** none. Each modifier keeps its trigger and its owner. If `Section` doesn't distribute,
  the change is behaviour-neutral.
- **Owner:** WP-9 (it splits this file anyway; do it in the same commit as the split, or just
  before it). **Rule:** "real bugs"; supports AC-03.

## P3

### CH-03 [bug] The Notifications pane keeps saying notifications are off after the user allows them
- **Where:** `Settings/SettingsView.swift:405-408` and `:420`.
  - `isDenied` is read once, by `.task` when the pane appears, and again after a toggle or a test
    notification.
  - The pane's own button sends the user to System Settings (`AppLinks.notificationSettings`).
    Coming back doesn't re-read the setting, so "Notifications are turned off for BatteryPulse in
    System Settings." stays until the user switches tabs or reopens Settings.
  - `GeneralSettings` handles the same round trip for Login Items with `didBecomeActiveNotification`
    (`:138-140`).
- **Change:** next to the `.task` (on the row CH-02 picks), add the same documented modifier
  `GeneralSettings` uses (SUI-20 keeps it):
  ```swift
  .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
      Task { isDenied = await BatteryNotifier.isDenied() }
  }
  ```
  No new string; `isDenied()` (`App/BatteryNotifier.swift:209-212`) is unchanged.
- **Measure:** on the M5 (packaged app):
  1. Turn BatteryPulse's notifications off in System Settings → Notifications.
  2. Open Settings → Notifications; it shows the "turned off" text.
  3. Click Open Notification Settings, allow notifications, then click back into BatteryPulse's
     Settings window.
  - Before: the text stays. After: "Send Test Notification" appears without a tab switch.
  - Repeat in the other direction (allow → deny).
- **Risk:** one `getNotificationSettings` XPC per app activation, and only while the Notifications
  tab is on screen: the subscription ends with the view.
- **Owner:** WP-9. **Rule:** "real bugs".

### CH-04 [readability] The popover captures `openWindow` in two buttons but not in the third
- **Where:**
  - `MenuBar/PopoverView.swift:63` and `:68` assign `WindowOpener.openWindow = openWindow` before
    `showMainWindow()` and `show(WindowID.about)`.
  - `UpdateAvailableRow` (`:118`) calls `WindowOpener.show(WindowID.update)` without it.
  - The label assigns it on appear (`MenuBar/MenuBarLabel.swift:47`), and the panel can only open
    from the label. So the two assignments are redundant, or, if they are a deliberate backup, the
    third button lacks it.
- **Change:** one `.onAppear { WindowOpener.openWindow = openWindow }` on the panel's root `VStack`,
  next to `.liveRefresh` (`:101`). Delete the two per-button lines. This keeps a backup capture for
  all three buttons; the app-core audit decided to keep `WindowOpener` itself.
- **Measure:** on the M5, from the panel: Open BatteryPulse (full and compact preference), About,
  Settings and an Update available row (Demo Mode, or a test build with a pending release). Each
  opens its window, also right after launch with no window opened before.
- **Risk:** none.
- **Owner:** WP-9. **Rule:** readability (duplicated logic).

### CH-05 [dead-code] `MenuBarIconPreview`: two parameters nobody passes, and a snapshot built only for a symbol name
- **Where:** `MenuBar/BatteryIconView.swift:238-262`.
  - `var state = BatteryIconState.sample` (`:240`) and `var magnification: CGFloat = 1.5` (`:241`).
    The one caller (`Settings/SettingsView.swift:245`) passes neither `state:` nor the default
    magnification; it always passes `PreviewTile.iconMagnification` (2.5). Checked by grep over
    `Sources` and `Tests`.
  - `:249-253` builds a `BatterySnapshot(timestamp: .now, …)` to call `symbolName(for:)`. BatteryCore
    already has `BatteryPresentation.symbolName(percent:state:)`
    (`Sources/BatteryCore/BatteryPresentation.swift:12`). `symbolName(for:)` only forwards to it.
- **Change:**
  - `private let state = BatteryIconState.sample` and `let magnification: CGFloat`, with no default.
  - Replace `:249-253` with
    `Image(systemName: BatteryPresentation.symbolName(percent: state.level * 100, state: state.glyph == .bolt ? .charging : .discharging))`.
- **Measure:** Settings → Menu Bar shows the same tiles, the SF Symbol tile included: a 75 % battery
  for `sample` (level 0.7 → 70 → `battery.75percent`). Lint passes.
- **Risk:** none.
- **Owner:** WP-11 (dead code) or WP-9. **Rule:** DC-6, readability.

### CH-06 [security] Clear History swallows a failure
- **Where:** `Settings/SettingsView.swift:463-466`: `try? await AppHistory.store.clear()`.
  - If the store can't delete its files, the user sees the charts start over in memory, but nothing
    says so, and nothing is logged.
  - SW-R12: unexpected failures at I/O boundaries are logged.
- **Change:** after WP-0's `Diagnostics.swift`:
  `do { try await AppHistory.store.clear() } catch { Log.history.error("Clear History failed: \(error, privacy: .private)") }`.
  - The error text can contain a path, so it stays private (SW-R10).
  - The device clear (`:465`) still runs, as today.
- **Measure:** on the M5, `chmod a-w` the history `samples` folder, then Clear History. `log stream
  --predicate 'subsystem == "io.github.nikitausov.BatteryPulse" AND category == "history"'` shows
  one error with `<private>`. Restore the permission afterwards.
- **Risk:** none.
- **Owner:** WP-4 (it owns the `history` logger and SW-12), with a one-hunk touch in WP-9's file.
  **Rule:** SW-R12, SW-R10.

### CH-07 [native] The widget's placeholder is the "No battery information" state
- **Where:** `Sources/BatteryPulseWidget/BatteryPulseWidget.swift:37-39`:
  `placeholder(in:)` returns `BatteryEntry(date: .now, snapshot: nil)`.
  - The view renders `nil` as the error layout (`:84-94`): a `battery.0percent` symbol and "No
    battery information".
  - WidgetKit shows the placeholder, redacted, while the widget loads. Apple's `placeholder(in:)`
    documentation asks for a placeholder version of the widget, not an error state. So a loading
    widget flashes the error layout as grey blocks.
- **Change:** return a representative entry:
  `BatteryEntry(date: .now, snapshot: BatterySnapshot(timestamp: .now, chargePercent: 70, chargeState: .discharging))`.
  - It is the same initializer `MenuBarIconPreview` uses today, and 70 % matches
    `BatteryIconState.sample`.
  - `getSnapshot` and `getTimeline` keep reading IOKit, so the gallery still shows real values.
- **Measure:** on the M5, add the widget from Edit Widgets, small and medium. The loading flash shows
  the redacted charge layout (symbol, number, two lines), not the "No battery information" layout.
  After the first timeline, it shows the same as 0.6.0. A Mac without a battery still shows "No
  battery information", because that comes from `getTimeline`.
- **Risk:** none; it only changes what shows during loading. **[unverified]** how long macOS 27
  shows a placeholder.
- **Owner:** WP-9 (view structure). It adds no string. **Rule:** native.

### CH-09 [readability] The menu bar choices are declared twice, with defaults that must match
- **Where:**
  - `MenuBar/MenuBarLabel.swift:12-17` and `:20-23`: five `@AppStorage` (`menuBarShowsIcon`,
    `…Charge`, `…Power`, `…Temperature`, `menuBarIconStyle`) and the `content` builder.
  - `Settings/SettingsView.swift:209-214` and `:216-219`: the same five declarations, the same
    defaults, the same builder, and the same comment ("The defaults of MenuBarContent: the icon and
    the charge.").
  - The only other user of the keys is `AppSettings.migrate()` (`App/AppSettings.swift:107-118`),
    which writes them and reads none. Checked by grep over `Sources`.
- **Change:** one SwiftUI `DynamicProperty`, the framework's own way to share a group of stored
  settings between views, below `MenuBarLabel`:
  ```swift
  /// The menu bar items and icon style, as the label and Settings read them.
  struct MenuBarChoices: DynamicProperty {
      // The defaults of MenuBarContent: the icon and the charge.
      @AppStorage(AppSettings.menuBarShowsIconKey) var showsIcon = true
      @AppStorage(AppSettings.menuBarShowsChargeKey) var showsCharge = true
      @AppStorage(AppSettings.menuBarShowsPowerKey) var showsPower = false
      @AppStorage(AppSettings.menuBarShowsTemperatureKey) var showsTemperature = false
      @AppStorage(AppSettings.menuBarIconStyleKey) var iconStyle = MenuBarIconStyle.default

      var content: MenuBarContent {
          MenuBarContent(
              showsIcon: showsIcon, showsCharge: showsCharge, showsPower: showsPower, showsTemperature: showsTemperature)
      }
  }
  ```
  - `MenuBarLabel`: `private var choices = MenuBarChoices()`; `choices.content`, `choices.iconStyle`.
  - `MenuBarSettings`: the same property; `Toggle("Battery icon", isOn: choices.$showsIcon)` and so on;
    `PreviewTilePicker(selection: choices.$iconStyle, …)`.
  - About 12 lines fewer, one place for the defaults. No new string.
- **Measure:**
  - Settings → Menu Bar: each toggle and icon style changes the status item at once; the last item on
    stays disabled.
  - `defaults delete io.github.nikitausov.BatteryPulse` then launch: icon + percentage, as in 0.6.0.
  - SUI-07's body counts for `MenuBarLabel` per tick don't rise (the property only adds the same
    five `UserDefaults` observations).
- **Risk:** low. A `DynamicProperty` must be a stored `var` in the view for SwiftUI to install its
  `@AppStorage`; a `let` or a computed property would silently stop updating. Drop this item if WP-9
  prefers no new type.
- **Owner:** WP-2 (`MenuBarLabel.swift`) defines it; WP-9 adopts it in the Settings split.
  **Rule:** readability (duplicated logic).

### CH-10 [readability] The Notifications pane watches an ad-hoc `[Int]` with Bools coded as 0/1
- **Where:** `Settings/SettingsView.swift:421`:
  `.onChange(of: [chargeLimit, lowBattery, accessoryLow, service ? 1 : 0, heat ? 1 : 0])`, then
  `guard AppSettings.alerts.isAnyEnabled` (`:423`) reads the same five defaults again.
  - `AppSettings.alerts` (`App/AppSettings.swift:63-75`) already maps the five values to
    `AlertSettings`, which is `Equatable` (`Sources/BatteryCore/BatteryAlerts.swift:16`) and has
    `isAnyEnabled` (`:37-39`).
- **Change:** `.onChange(of: AppSettings.alerts) { _, alerts in guard alerts.isAnyEnabled else { return } … }`,
  the `Task` body unchanged. The body re-runs on each of the five `@AppStorage` changes, so the value
  is read after the write. Move it with CH-02's placement.
- **Measure:** same triggers as before: turning any alert on (or changing a threshold while one is
  on) asks for authorization once; turning the last one off asks nothing. In a new macOS user
  account (no permission asked yet), turning on "When the Mac gets hot" shows the system prompt once.
- **Risk:** none: `AlertSettings` changes exactly when the array did (0 ↔ `nil` maps one to one).
- **Owner:** WP-9. **Rule:** readability.

### CH-11 [readability] The welcome window repeats `SettingsPage`'s form setup
- **Where:** `Welcome/WelcomeView.swift:32-37`
  (`Form { GeneralSettings() }.formStyle(.grouped).scrollDisabled(true).fixedSize(horizontal: false, vertical: true)`)
  repeats `SettingsPage` (`Settings/SettingsView.swift:32-41`) modifier for modifier. `SettingsPage`
  is `private`, so the welcome window can't use it.
- **Change:** drop `private` from `SettingsPage`; `WelcomeView` uses `SettingsPage { GeneralSettings() }`.
  With SUI-13's split, `SettingsPage` goes to the shared-components file with `Crossfade` and
  `PreviewTilePicker`. The two windows that embed `GeneralSettings` then size it one way.
- **Measure:** screenshots of the welcome window (600 pt wide) and Settings → General before and
  after, light and dark, English and Russian: identical. The welcome window still doesn't scroll.
- **Risk:** none.
- **Owner:** WP-9. **Rule:** readability (duplicated logic).

---

## Checked, no change proposed

- **Menu bar icon cost.** `MenuBarIconRenderer.image` (`BatteryIconView.swift:280-301`) is called on
  every label body. It is keyed on `(style, state, scale)`. `state.level` comes from
  `Current Capacity / Max Capacity`, which is in whole percent on Apple Silicon
  (`MacPowerParser.swift:155-158`), so `ImageRenderer` runs at most once per percent or state change
  (twice while red or yellow). The adaptive image's drawing handler only draws a cached `CGImage`.
  `NSScreen.screens` per call is cheap. Keep.
- **`DigitOutlines` builds two `CTFont`s per render** (`:105-110`). This happens only on a cache
  miss, as above. Not worth a static cache.
- **Label body work** (`MenuBarLabel.swift:25-53`):
  - `content` is rebuilt three times and `Phrases.batteryIcon` runs one `String(localized:)` per
    snapshot change. That is microseconds, at most every 10 s with power shown.
  - SUI-06 removes the two formatter builds; nothing else is worth changing.
  - The label has no animation (`MotionGuardTests.menuBarLabelFiles`).
- **Popover accessory rows** (`PopoverAccessories.swift`):
  - `String(localized:)` per part (`:85`) and `Phrases.accessoryName` per row run only when the
    `[AccessoryBattery]` value changes: it is `Hashable`, so SwiftUI skips the subtree on the 2 s
    poll.
  - `ForEach(accessory.parts, id: \.role)` is safe: `AccessoryParser.accessories(from:)` keeps one
    part per role (`AccessoryParser.swift:55-57`).
  - `AccessorySymbols.isAvailable` caches its lookups.
- **`UpdateAvailableRow`'s `.task(id:)` with no `await`** (`PopoverView.swift:124-129`):
  - The 2027 SDK runs it synchronously (SUI-22), which is what it wants: the bounce key changes
    right after the row appears.
  - `onChange(initial: true)` could change in the same update as the insertion, and the bounce might
    not play. Keep.
- **Settings button in the popover** (`:75-82`): `SettingsLink` can't run `prepareToShowWindow()` or
  `NSApp.activate()`, and an `LSUIElement` app needs both. Keep `openSettings()`.
- **"Last checked …"** (`SettingsView.swift:157`) doesn't tick while Settings stays open.
  `Text(date, style: .relative)` would tick, which costs a timeline for no real need, and it would
  change the localized key. Keep.
- **`PreviewTilePicker`**: buttons with `.isSelected` are announced correctly. An
  `accessibilityRepresentation { Picker … }` would change the VoiceOver experience without a
  reported problem. Keep. The custom glass selection is on CLAUDE.md's allow list.
- **`WindowLookPreview`**: four static `Canvas` drawings, two with a blur filter. They are redrawn
  only on an appearance change. Keep.
- **`AppIconView`**:
  - The SwiftUI drawing exists for unbundled runs and has to keep matching `AppIcon.svg` (SZ-10).
  - `IconColor`'s computed `static var`s are trivial.
- **Duplicated alert defaults:** every `@AppStorage` default in the area matches the other
  declarations of the same key and `AppSettings`' readers (checked by grep: `showInMenuBar` ×4 true,
  menu bar items ×2, `readDevices` ×2, `showDeveloper` ×2).
- **Widget:**
  - `state(_:)` repeats `Phrases.state`'s switch (`BatteryPulseWidget.swift:166-176`), because the
    widget can't import the app target. Moving the key choice into BatteryCore would still need a
    `String(localized:)` switch in each target. Keep.
  - `time(_:)` uses `entry.date` as the reading time. That is correct because
    `WidgetTimelinePlan` only sets `showsEstimate` on the entry dated at the read
    (`BatteryPresentation.swift:189-204`).
  - The `Task { @MainActor in }` hops are needed (see above). `BatteryFormatter()` there shows only
    percent and °C, so it needs no localized unit symbols.
- **Energy:**
  - The area has no timer, sleep, `DispatchQueue` or polling of its own.
  - The popover's 2 s poll and the label's 10 s poll go through `liveRefresh` /
    `setLiveRefreshInterval` (WP-2: E5–E7).
  - The welcome icon's draw-in plays once per launch.
- **Other `Group`s in the area:** `MenuBarIconPreview` (`BatteryIconView.swift:245-260`) has one member
  at a time and only a `.frame` on it; the menu bar label's `.transaction` (`MenuBarLabel.swift:43-46`)
  is meant to reach each member. Neither needs a change; only CH-08's lifecycle modifiers do.
- **Setting defaults outside the first pass's list:** `updateFrequency` (daily, matching
  `UpdateFrequency.stored(nil, …)`), `showWelcomeAtLaunch`, `prefersCompactWindow`, `windowLook`
  (×2, `.standard`), the five alert keys (0/false, matching `AppSettings.alerts`) and
  `recordHistory` (true, matching `AppSettings.recordsHistory`). All consistent.
- **`BatteryNotifier` calls from Settings** (`SettingsView.swift:402-427`): `isDenied()`,
  `requestAuthorization()` and `sendTest()` all return early when `isAvailable` is false
  (`App/BatteryNotifier.swift:204-216`), so an unbundled `swift run` never touches
  `UNUserNotificationCenter.current()`. Keep.
- **Widget tint** (`BatteryPulseWidget.swift:158-164`) repeats the app's level colours; it can't import
  the app target and BatteryCore must stay free of SwiftUI. Keep.
