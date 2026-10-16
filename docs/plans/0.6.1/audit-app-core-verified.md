# Audit "app-core", verified (base 6133b4f)

Adversarial check of `v061/audit-app-core.md` (AC-01 to AC-07) against the code at `6133b4f`
(read with `git show 6133b4f:<path>`). `main` is now at `a32bfae`. Since `6133b4f`, the only
changes in the files this audit cites are a comment at `App/WindowLook.swift:84` and the tile picker in
`Settings/SettingsView.swift:267-350`. No cited line has moved, and `WindowLook.swift:14` is still
136 columns at HEAD.

Scratch evidence for this pass is in `v061/appcore-verify/`:
- `b.swift`: `-dump-macro-expansions` on Swift 6.4.1 shows that the setter starts with
  `guard shouldNotifyObservers(_isDark, newValue)`, with a private `Equatable` overload. Run
  output: Bool, same value: 0 notifications; different value: 1.
- `c.swift`: the same check for `Bool?` and `[Equatable struct]`. Run output: same value: 0;
  different value: 1.
- `notes-0.6.0.md`: the 0.6.0 notes (8,707 bytes). The auditor's `NotesBench` measures
  `ReleaseNotes.inlineMarkdown` at 2.78 ms per call on this VM (the audit says 2.3 ms; the two agree).

## Summary

| ID | Verdict | Package | Priority |
| --- | --- | --- | --- |
| AC-01 | keep-modified | WP-6 (with SEC-02) | P2 |
| AC-02 | keep-modified | WP-11 (one commit, BatteryKit sites included) | P3 |
| AC-03 | keep-modified | WP-10 (own commit, before the isolation sweep) | P3 |
| AC-04 | keep-modified (helper only, no file move) | WP-6 (in the SW-05 commit area) | P3 |
| AC-05 | keep | WP-6 (plus one line of `WhatsNewPolicy`) | P3 |
| AC-06 | reject | — | — |
| AC-07 | keep-modified (`migrate()` part gated) | WP-11 | P3 |

## AC-01: release notes re-parsed on every download tick — keep-modified (WP-6, P2)

Confirmed:
- `UpdateView.body` reads `updater.installer.phase` in two places:
  - `phaseKind` in `.onChange(of:)` (line 65);
  - `installStatus` (line 150), which `content` calls from `body`.
- The progress task in `UpdateInstaller.swift:198-205` assigns `.downloading(fraction)` every 200 ms.
  The `@Observable` setter suppresses only equal values, so each new fraction invalidates `body`.
- While the window is in `.available`, each tick runs `notes(release)`, that is
  `ReleaseNotes.inlineMarkdown` plus `AttributedString(markdown:)`, and hands `Text` a fresh
  8.7 KB attributed string.
- Measured: 2.78 ms per `inlineMarkdown` call here. The macOS-only `AttributedString` pass and the
  text layout are on top of that.

The fix is real and small. It is also the natural place for SEC-02's `OpenURLAction`.
`ReleaseNotesText(notes: String, baseURL: URL)` holds the same `ReleaseInfo`'s storage on every
tick, so SwiftUI's field comparison sees equal inputs and skips its body.

Modification:
- **The blocker part, as proposed, adds work during a download.** Today `blocker(for:)` is called
  only in the `.idle` phase: `installStatus` reaches it only in `case .idle`, and `installActions`
  reaches it only after `!isBusy && phase == .idle`. During a download it is called 0 times.
  Computing `let blocker = updater.installer.blocker(for: release)` unconditionally in the
  `.available` branch would add 2 `access(2)` calls per 200 ms tick for the whole download.
  Compute it only in the idle phase:
  `let blocker = installer.phase == .idle ? installer.blocker(for: release) : nil`.
  Pass it to both helpers. The value matches the current code in every phase.
- Put the `ScrollView`, `.textSelection(.enabled)` and the background inside the new subview too,
  so `UpdateView` keeps only the layout. Keep `notes(_:)` as a `static` function in the subview. No
  new strings.
- Measure as proposed: a DEBUG loop or Instruments, and selection survives the download.

## AC-02: redundant equality guards on `@Observable` properties — keep-modified (WP-11, P3)

Confirmed on Swift 6.4.1 (see `b.swift` and `c.swift`). The macro's setter returns early on equal
`Equatable` values, including `Bool?` and arrays, and it emits that check at compile time. So it
does not depend on the macOS version. Xcode 27 ships the same macro (Swift 6.4).

Modification:
- **The site list is incomplete.** `git grep` finds 8 manual guards. Remove the 7 on `@Observable`
  storage:
  - `Motion.swift:234` (`LowPowerMode.isEnabled`);
  - `WindowLook.swift:177` (`SystemAppearance.isDark`);
  - `AccessoryMonitor.swift:60, 62` and **`:69`** (`isOverridden`, missed by the audit);
  - **`BatteryMonitor.swift:95`** (`hasBattery`, missed by the audit);
  - `IDeviceMonitor.swift:621` (`entries`).
- Keep `Motion.swift:259`: it is a `Binding` write, not `@Observable` storage.
- Keep `BatteryMonitor.swift:96-97`: `isSameReading` and `isSameState` are semantic comparisons,
  not `==`.
- Keep the `UserDefaults` guards (`BatteryNotifier.swift:124`).
- Keep the doc comment at `AccessoryMonitor.swift:15-16` ("Reassigned only when the list
  changed…"). Reword it to say that the `@Observable` setter skips equal values, so the guarantee
  isn't lost.
- One WP-11 deletion commit for all sites. Phase C runs after WP-2 and WP-7 have merged, so this
  needs no cross-package coordination (DC-6: the commit says why).
- Measure: both CI jobs build; the `AccessoryMonitorTests`, `BatteryMonitorTests` and
  `IDeviceMonitorTests` suites stay green.

## AC-03: two `SMAppService.status` reads per refresh — keep-modified (WP-10, P3)

Confirmed:
- `isEnabled` and `requiresApproval` each call `SMAppService.mainApp.status`, at
  `AppSettings.swift:281-282` and in the initializers at lines 273 and 275.
- `BatteryPulseApp.swift:19` creates the model with `@State` in the `App` struct, so it is built at
  launch.
- `SettingsView.swift:137-139` refreshes on appear and on every `didBecomeActive`.

The speed gain is small and unmeasured. The stronger reason is correctness: two separate reads can
straddle a status change, so `isEnabled` and `requiresApproval` can describe two different moments.
A single `status` value can't tear like that.

Modification:
- Store `private(set) var status = LaunchAtLogin.status`, with `isEnabled` and `requiresApproval`
  computed from it.
- Keep the one read in the initializer. Don't make it lazy with a placeholder value: the
  Welcome/Settings toggle could flash off before `onAppear`.
- Views unchanged.
- Measure on the M5 with Time Profiler or a signpost. Toggle Launch at login and approve it in
  System Settings, as in the §2.6 checklist.
- Its own commit in WP-10, before the mechanical isolation sweep, so the sweep stays mechanical.

## AC-04: `UpdateInstaller.swift` split and duplicated Info.plist read — keep-modified (WP-6, P3)

Confirmed:
- The file is 544 lines.
- `checkBundle` (lines 499-503) and `removeLeftovers` (lines 533-537) repeat the same 5-line
  `Data(contentsOf:)` → `PropertyListSerialization` → `as? [String: Any]` read.

Modification:
- **Drop the file move.** It is a move-only refactor: no behaviour, size or speed change, and noisier
  blame. It also doesn't help the packages that follow:
  - WP-6's SW-05 (`@concurrent`), SW-06 and SW-12 edits apply in place;
  - WP-10's `nonisolated` is a per-declaration change, so the file it sits in doesn't matter.
- Keep only `private static func infoDictionary(ofBundleAt:) -> [String: Any]?`, used at both sites
  (net about −4 lines, one definition).
- Doc comment: "read from the file, not `Bundle(url:)`, which returns one cached instance per path
  for the life of the process". Not "stale after the swap": neither site reads the swapped path.
- Land it with WP-6's SW-05 "named leftover cleanup", which already edits `removeLeftovers`.
- Measure: `UpdateInstallTests` unchanged; macOS job builds; the §2.6 in-app update on the M5.

## AC-05: `AppVersion(parts: [0, 0, 0])` spelled three times — keep (WP-6, P3)

Confirmed:
- `UpdateInstallPolicy.unversioned` exists (`UpdateInstall.swift:91`), and BatteryCore and
  `UpdateInstallTests` use it.
- The app spells the literal again at `UpdateChecker.swift:52, 59` and `AppSettings.swift:153`.
  Replacing them changes no value: `AppVersion.==` pads with zeros either way.
- The audit is right to leave `AboutView.swift:53`'s string comparison alone.

Ownership note: WP-6 owns only `AppLinks` in `AppSettings.swift`. The `WhatsNewPolicy.markSeen`
line is update-related, and no other Phase B package edits `AppSettings.swift`, so WP-6 takes that
one line too.

## AC-06: pause the Demo Mode clock while no window is open — reject

The premise "nobody can see it" is false:
- The menu bar label shows the demo whenever the status item is shown, which is the default.
  `MenuBarLabel` renders `monitor.snapshot` (the demo override) plus the Demo Mode symbol, and the
  file itself says "the status item is always on screen".
- The proposed gate `hasOpenWindows || monitor.liveRefreshInterval != nil` doesn't account for it.
  With the default menu bar content (icon and charge), `MenuBarContent.liveRefreshInterval` is
  `nil`. So with every window closed the clock would stop, and a playing tour would freeze in the
  menu bar: no more charging, low, critical or no-battery icon states, and a frozen charge
  animation.
- That is a visible loss of functionality, in the very place where Demo Mode screenshots of the
  status item are taken. It breaks §3.4 ("Demo Mode. Same scenes…") and the audit's own risk
  condition ("identical whenever anything shows it").

Other reasons:
- **It needs new state.** `DockIconPolicy` is a `@MainActor enum` with a private static `Set`, not
  observable, so "an observation task over `DockIconPolicy.hasOpenWindows`" needs new observable
  state.
- **It saves little.** The only case left to save is Demo Mode on, the menu bar item hidden and every
  window closed: a developer feature that doesn't survive quitting, in a corner case of a corner
  case.
- **The wake-ups are already covered.** E7 (WP-4) already adds a tolerance to the demo clock, which
  lets its wake-ups coalesce.

## AC-07: comment and launch hygiene — keep-modified (WP-11, P3)

Confirmed:
- `App/WindowLook.swift:14` is 136 columns. The `.swift-format` `lineLength` is 120, and lint doesn't
  rewrap comments.
- `AppDevices.swift:55` hedges about whether `UTTagClass(rawValue:)` is failable.
- `migrate()` removes three legacy keys unconditionally at every launch (`AppSettings.swift:120-124`).

Modification:
- Unconditional:
  - Rewrap `WindowLook.swift:10-15`.
  - Settle `UTTagClass(rawValue:)` on the macOS CI job. If the initializer is non-failable, use a
    non-optional `let` and drop the `tagClass` binding from the `guard`. Otherwise reword the comment.
- **The `migrate()` guard is gated, not unconditional.** Whether `removeObject(forKey:)` on an
  absent key reaches cfprefsd, writes the plist or posts `UserDefaults.didChangeNotification` is
  unverified. It runs once, in `App.init` (`BatteryPulseApp.swift:27`), before most observers exist.
  - Take the `for key in [...] where defaults.object(forKey: key) != nil` form only if the M5 check
    shows a cfprefsd write or a change notification caused by `migrate()` on a migrated profile.
    Check with `fs_usage -w -f filesys cfprefsd`, or log `didChangeNotification` in a DEBUG build.
  - Otherwise leave `migrate()` as it is.
  - The migration itself stays either way (DC-5, §3.4 legacy keys).
- Measure: lint and both builds pass.
