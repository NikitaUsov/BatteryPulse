# BatteryPulse — notes for Claude

Native battery/charging inspector for macOS and iOS. Swift 6, SwiftUI, zero dependencies.
Plan, decisions and status: `docs/ROADMAP.md`. User-facing docs: `docs/USER_GUIDE.md`.
Everything in the repository is English only, except the Russian translations in
`Resources/Localizable.xcstrings`.

Targets: macOS 27 / iOS 27, Apple Silicon only (no Intel code). macOS ships as a DMG, not
through the App Store. Reference hardware: MacBook Air M5.

## Layout

- `Sources/BatteryCore` — platform-independent: `PropertyValue` (normalized plist/CF values),
  `BatterySnapshot` model, `MacPowerParser` (AppleSmartBattery + IOPS + adapter dictionaries),
  `RegistryChildren` (the pack, banks and charger entries below AppleSmartBattery), `SMC` (wire
  format and battery keys of the read-only SMC client; `SMCReadPolicy`/`SMCValueCache` read the
  keys a poll doesn't show at most every 60 s), metrics, `BatteryReport` text output,
  `CaptureFormat` (the capture property list, `BatterySnapshot.redacted`, Copy JSON's encoder),
  `RawValueDecoding`/`RawKeyGlossary` (Developer table; `RawDisplayRow`/`RawDisplaySection` are
  its prebuilt rows), `History`/`HistoryStore`, `HistoryChartData` (the History page's charts),
  `BatteryAlerts`, `Updates`, `UpdateInstall` (install policy, integrity, errors) and
  `ReleaseSigning` (`publicKeys`, the Ed25519 keys a release may be signed with),
  `MenuBarContent`/`BatteryIcon` (menu bar items and icon geometry), `IDevice*` (iPhone/iPad:
  device list, diagnostics relay capture, battery parser, report), `DemoBattery` (Demo Mode scenes
  that expand into M5-style raw dictionaries), `BatteryMotion` (`MotionPolicy` and
  `BatteryMotionKey`, the discrete parts of a snapshot that animations key on),
  `DeviceKey`/`RememberedDevice`/`DeviceStore`/`IDeviceSchedule`/`IDeviceModel`/`DemoDevice`
  (remembered iPhones and iPads, their history and read schedule), `Accessory*`/`DemoAccessories`
  (Bluetooth accessory batteries: model, parser, pseudonymized capture, alerts, report),
  `HistoryExport` (CSV/JSON), `CaptureRecorder` (`bpulse --record`), `LiveRefreshPolicy`
  (slower polls in Low Power Mode, under reduced resources or heat), `WindowLook`
  (`WindowLookPolicy`) and `ToneMap` (window styles). Must stay free of Apple-only frameworks.
- `Sources/BatteryKit` — `BatteryProvider` protocol, `MacBatteryProvider` (IOKit, registry
  children, SMC via `SMCClient`), `IOSBatteryProvider` (UIDevice), `DemoBatteryProvider`,
  `BatteryMonitor` (@Observable, event-driven + optional polling, one read per notification burst,
  on an injected `MonitorClock`; `setOverride` swaps in the demo), `Diagnostics` (its loggers and
  `Signposts`), `UpdateSignatureVerifier` (CryptoKit), `IDeviceTransport` and `MobileDevice/` (the
  private MobileDevice framework through `dlopen`, never linked; no pairing calls),
  `IDeviceMonitor` (opt-in, USB-triggered device reads; `USBDeviceWatcher`, `DeviceKeys` HMAC),
  `AccessoryMonitor` and `MacAccessoryProvider` (the private `IOPSCopyPowerSourcesByType(4)`
  through `dlsym`, refreshed on the `com.apple.system.accpowersources.*` notifications).
- `Sources/BatteryPulseApp` — SwiftUI app (product `BatteryPulse`): `App/` (scenes, settings keys,
  Dock icon policy, localized phrases, `DemoController`, `Diagnostics` (loggers and signposts),
  `Motion` with the `\.motion` environment value and its presets, plus `SystemPowerState` and
  `ScreenActivity`, which slow or stop polls), `Main/` (sidebar window:
  Overview, Power, History (`Main/History/`), Health, the Devices section with a page per
  iPhone/iPad and Accessories, and the Developer section with Raw Data and Demo Mode; the compact
  window; `Main/Components/`, one file per component, `Card.swift` with `Card`, `CardGroup` and
  `LookForm`), `Updates/` (update check and `UpdateNetwork`, Software Update and What's New
  windows), `MenuBar/`,
  `Settings/` (one file per pane), `Welcome/`. Everything is inside `#if os(macOS)`; a stub `main`
  keeps Linux builds working. Locale-independent display logic and `BatteryFormatter`
  (numbers/units per locale) live in BatteryCore so they are tested on Linux.
  `scripts/build-app.sh` packages `.app` + `.dmg`; `Resources/AppIcon.svg` is the icon source
  (`AppIcon.png` is rendered from it, and `AppIconView` draws the same design in SwiftUI).
- `Sources/BatteryPulseWidget` — the WidgetKit extension: a SwiftPM executable linked with
  `-e _NSExtensionMain`, wrapped into `BatteryPulse.app/Contents/PlugIns/*.appex` and signed
  with only the app-sandbox entitlement by `scripts/build-app.sh`.
- `Sources/bpulse` — CLI. `--raw` writes the capture format used by test fixtures; `--input`
  renders a capture (works on Linux); `--smc` lists the SMC's battery keys; `--devices` and
  `--device <n> [--json | --raw]` read a connected iPhone or iPad; `--accessories [--json |
  --raw]` lists accessory batteries; `--export csv|json` prints the recorded history; `--record
  <folder>` keeps captures around every charging change.
- Releases: `release.yml` checks that `.github/release-notes.md` opens with `## What's new in
  <version>`, checks the secret's key against `ReleaseSigning.publicKeys`, signs the DMG with
  `scripts/sign-update.swift` and the `UPDATE_SIGNING_KEY` secret of the `release` environment
  (`BatteryPulse.dmg.sig`; `--help` is the key rotation runbook) and publishes
  `BatteryPulse-dSYMs.zip` beside them. The app's `Updates/UpdateInstaller` refuses an update
  without a `.sig` or one that fails its signature, digest, bundle or code-signature check, and
  then offers only the release page, never the DMG (`UpdateFallback`). Never ask for or handle
  the private key.
- `scripts/` — `build-app.sh` (packages the app, `PROFILING=1` for an Instruments build, and
  fails on any signing-posture violation, listing each), `size-report.sh` with
  `size-budget.json` (CI's size report and ceilings), `string-tables.swift` (every translated
  table has every catalog key), `perf-stats.swift` (sums the `perf` log lines), `rusage.swift`
  (one process's energy and wake-ups), `menu-bar-shots.sh` with `display-metrics.swift`.
- `Tests/BatteryCoreTests/Fixtures/*.plist` — raw captures (see its README). `m5-macos27-*` are
  real; `synthetic-legacy-*` are hand-written and only cover fallback keys.

## Environment

- Cloud sessions run on Linux: `swift build` and `swift test` work, but anything under
  `#if os(macOS)` / `#if os(iOS)` (IOKit, UIKit, SwiftUI) is NOT compiled here.
- Darwin code is verified only by CI (`.github/workflows/ci.yml`, runner `xcode-27`: macOS 27,
  Xcode 27.1 through `DEVELOPER_DIR`, Swift 6.4) and on the maintainer's Mac. After touching
  Darwin code, push and check the macOS job.
- Both CI jobs treat every compiler warning as an error (a deprecation stays a warning) and have
  time limits; the macOS job also packages the app, checks its size and signing posture, and
  launches it once.

## Commands

- `swift build`, `swift test` — run from the repo root.
- `swift format lint --strict -r Sources Tests Package.swift scripts` — CI fails on any warning;
  `swift format format -i -r Sources Tests Package.swift scripts` fixes most of them (config:
  `.swift-format`).
- `swift run bpulse --input Tests/BatteryCoreTests/Fixtures/<name>.plist` — render a capture.

The SessionStart hook (`.claude/hooks/session-start.sh`) installs the Swift toolchain in cloud sessions.

## Conventions

- Units live in property names: `MAh`, `MV`, `MA`, `MW`. Signed current: negative = discharging.
- macOS 27 layout: mAh values live in `AppleSmartBattery` → `BatteryData` (`RemainingCapacity`,
  `FullChargeCapacity`, `NominalChargeCapacity`, `DesignCapacity`); `Temperature` and
  `CellVoltage` moved to the child entries (`RegistryChildren`). Health is capped at 100 % like
  System Settings; no condition key (or an empty one) means "Normal".
- The SMC is read-only: only commands 5, 8 and 9 through selector 2, never a write.
- Linux Foundation quirk: NSNumber 0/1 casts to `Bool`, and `Int` in `Any` doesn't cast to
  `Int64` — go through `PropertyValue(any:)`, never cast raw values directly.
- Tests use swift-testing (`import Testing`, `@Test`, `#expect`).
- Language: every target builds with `Package.swift`'s `strict` settings and no compiler flags of
  its own (the widget's two only shape the extension). `MemberImportVisibility` is on, so a file
  imports every module whose members it uses (`os` for a `Logger` call through `Diagnostics`,
  BatteryCore for a `MotionPolicy` member).
  BatteryCore and bpulse build with strict memory safety: an unavoidable unsafe call is marked
  `unsafe` with its reason (bpulse's three pointer and format calls, and `BatteryReport.cFormat`'s
  `String(format:)`, which only Darwin's Foundation marks, so its marker sits under
  `#if canImport(Darwin)`: an unneeded one warns). The rest of the unsafe code is BatteryKit's
  system bindings (IOKit, SMC, MobileDevice, notify) and the app's `proc_*` calls.
- Concurrency: a plain `async` function runs on its caller's actor
  (`NonisolatedNonsendingByDefault`). Work that leaves the main actor (decoding, hashing,
  building chart data or Raw Data rows) is a `@concurrent` function over `Sendable` values, not
  `Task.detached`. Tasks have names (`Task(name: "Type.purpose")`).
- Observation: a service follows `@Observable` state in a named task over
  `Observations { … }.dropFirst()` (the start value is no change) and cancels it in `stop()`;
  never `withObservationTracking`.
- Energy: every periodic `sleep(for:)` passes `tolerance:` of at least 10 % of its interval
  (one-shots go on `EnergyGuardTests`' list with their reason); no `Timer`, Combine or dispatch
  timer (`asyncAfter` only for the device transport's timeouts); `beginActivity` only around an
  install; widget reloads only in `WidgetRefresher`, through `WidgetReloadPolicy`.
- The SwiftUI environment's values are rarely changing `Equatable` ones (`\.motion`, `\.tones`,
  `\.windowLook`, `\.contentTreatment`), and its objects are `@Observable` services that views
  read property by property; never `snapshot`, `reading`, dates, timers or geometry as a value,
  which would re-render every view that reads it.
- Logging: `Diagnostics` (an app and a BatteryKit twin), one `Logger` per category of the
  `io.github.nikitausov.BatteryPulse` subsystem: `monitor`, `smc`, `iokit`, `history`, `device`,
  `accessory`, `update`, `widget`, `perf`. A failure that loses data or a feature is logged, not
  dropped with `try?`. Only static text, numbers and case names log as `.public`; error
  descriptions, paths, device names, serials and UDIDs never do (a device key logs as
  `.private(mask: .hash)`).
- Signposts: `Diagnostics.begin`/`measure`/`event` with `StaticString` names and triggers: a
  Points of Interest signpost plus a `perf` debug line that `scripts/perf-stats.swift` reads.
  Names: `refresh` (its trigger is a `RefreshTrigger`), `read` with `registry`, `iops`,
  `adapter`, `smc.power`, `smc.other`, `children` and `parse`; `history.load`, `history.record`,
  `raw.rebuild`, `raw.filter`, `update.check`, `page.switch`, `device.read`, `accessory.read`;
  the events `widget.reload` and `menuBarReady`. Keep them stable: measurements compare by name.
- Guard suites run on Linux over the sources with comments and strings blanked
  (`Tests/BatteryCoreTests/SourceScanner.swift`), Darwin code included: `MotionGuardTests`
  (motion, glass, window style, tone map), `EnergyGuardTests` (the energy rules above),
  `SecurityGuardTests` (where `dlopen`/`dlsym`, IOKit user clients, `Process` and `kill` may
  appear, the SMC's one selector, and the escapes from the compiler's checks) and
  `LocalizationCatalogTests`. An exception goes on the suite's list with its reason.
- Localization: UI literals are `LocalizedStringKey`/`String(localized:)` keyed by the English
  text; interpolate only pre-formatted Strings (placeholders are always `%@`); never pass a
  ternary of literals to `Text` (it becomes a plain String). Add every new key with its Russian
  translation to `Resources/Localizable.xcstrings`; `LocalizationCatalogTests` fails on missing
  or unused keys. Use Apple's Russian terminology (the words macOS uses in System Settings →
  Battery); existing catalog entries show the conventions.
- Liquid Glass and window styles: glass is the control layer: standard components, plus custom
  controls that float over content, each cluster inside one `GlassEffectContainer`, `.regular`
  variant. Never `glassEffect` on content (cards, tiles, charts, tables, readouts), never glass on
  glass. Custom glass appears only in `Main/DemoView.swift` (the floating demo bar) and
  `App/WindowLook.swift`; the Settings tile pickers use an accent outline. The one
  exception is the window style setting (Settings → General: Standard / Frosted / Translucent /
  Clear; code name `WindowLook`, never `WindowStyle`, which is SwiftUI's), decided by
  `WindowLookPolicy` in BatteryCore: Frosted is a standard material behind the window
  (`containerBackground(_:for: .window)`); Translucent and Clear are one `.clear` glass sheet
  behind the whole window, Translucent with a dimming tint, Clear with a dark dimming, the
  window in the dark appearance, a graphite control tint (never white) and every colour through
  the tone map (`\.tones`, `App/ToneStyle.swift`; no system colour names in `Main/`,
  `App/Localized.swift` or `App/DemoController.swift`). The sheet is the only glass under other
  glass. Only the main and compact windows; Reduce Transparency or Increase Contrast gives
  Standard. Content stays free of glass and materials: no material in `Main/` but the History
  chart's hover readout, which must read on every style; groups use `Card`/`CardGroup`/`LookForm`.
  Only the window background may depend on the style's structure; everything else takes the style
  as a value. `MotionGuardTests` enforces the lists.
- Motion: through `\.motion` (`App/Motion.swift`), keyed on `BatteryMotionKey` or UI state, never
  on `snapshot`/`reading`. `change` moves things and is `nil` under Reduce Motion; `crossfade` is
  for opacity and colour only. No repeating or per-frame animation, no hard-coded animation
  outside `Motion.swift`; nothing animates in the menu bar label or in a hidden window.
  `MotionGuardTests` enforces this.
- Network: the update traffic goes only through `UpdateNetwork`'s ephemeral sessions, which
  cache nothing on disk; automatic checks never use Low Data Mode or an expensive network, while
  Check Now and a download the user chose use any. `URLSession.shared` appears nowhere
  (`SecurityGuardTests`).
- Never name third-party apps, their projects or makers anywhere: code, comments, tests, docs,
  commit messages, PRs, issues, release notes. Describe the technique or the evidence instead
  ("a public capture from an M4 Max"). Apple's own apps and frameworks are fine.
