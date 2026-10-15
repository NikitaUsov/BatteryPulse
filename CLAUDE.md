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
  format and battery keys of the read-only SMC client), metrics, `BatteryReport` text output,
  `RawValueDecoding`/`RawKeyGlossary` (Developer table), `History`/`HistoryStore`,
  `BatteryAlerts`, `Updates`, `DemoBattery` (Demo Mode scenes that expand into M5-style raw
  dictionaries). Must stay free of Apple-only frameworks.
- `Sources/BatteryKit` — `BatteryProvider` protocol, `MacBatteryProvider` (IOKit, registry
  children, SMC via `SMCClient`), `IOSBatteryProvider` (UIDevice), `DemoBatteryProvider`,
  `BatteryMonitor` (@Observable, event-driven + optional polling; `setOverride` swaps in the
  demo).
- `Sources/BatteryPulseApp` — SwiftUI app (product `BatteryPulse`): `App/` (scenes, settings
  keys, Dock icon policy, localized phrases, `DemoController`), `Main/` (sidebar window:
  Overview, Power, History, Health, and the Developer section with Raw Data and Demo Mode; the
  compact window), `Updates/` (update check, Software Update and What's New windows),
  `MenuBar/`, `Settings/`, `Welcome/`. Everything is inside `#if os(macOS)`; a stub
  `main` keeps Linux builds working. Locale-independent display logic and `BatteryFormatter`
  (numbers/units per locale) live in BatteryCore so they are tested on Linux. `scripts/build-app.sh` packages `.app` + `.dmg`;
  `Resources/AppIcon.svg` is the icon source (`AppIcon.png` is rendered from it, and
  `AppIconView` draws the same design in SwiftUI).
- `Sources/BatteryPulseWidget` — the WidgetKit extension: a SwiftPM executable linked with
  `-e _NSExtensionMain`, wrapped into `BatteryPulse.app/Contents/PlugIns/*.appex` and signed
  with only the app-sandbox entitlement by `scripts/build-app.sh`.
- `Sources/bpulse` — CLI. `--raw` writes the capture format used by test fixtures; `--input`
  renders a capture (works on Linux); `--smc` lists the SMC's battery keys.
- `Tests/BatteryCoreTests/Fixtures/*.plist` — raw captures (see its README). `m5-macos27-*` are
  real; `synthetic-legacy-*` are hand-written and only cover fallback keys.

## Environment

- Cloud sessions run on Linux: `swift build` and `swift test` work, but anything under
  `#if os(macOS)` / `#if os(iOS)` (IOKit, UIKit, SwiftUI) is NOT compiled here.
- Darwin code is verified only by CI (`.github/workflows/ci.yml`, runner `xcode-27`: macOS 27,
  Xcode 27, Swift 6.4) and on the maintainer's Mac. After touching Darwin code, push and check
  the macOS job.

## Commands

- `swift build`, `swift test` — run from the repo root.
- `swift format lint --strict -r Sources Tests Package.swift` — CI fails on any warning;
  `swift format format -i -r Sources Tests Package.swift` fixes most of them (config: `.swift-format`).
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
- Localization: UI literals are `LocalizedStringKey`/`String(localized:)` keyed by the English
  text; interpolate only pre-formatted Strings (placeholders are always `%@`); never pass a
  ternary of literals to `Text` (it becomes a plain String). Add every new key with its Russian
  translation to `Resources/Localizable.xcstrings`; `LocalizationCatalogTests` fails on missing
  or unused keys. Use Apple's Russian terminology (the words macOS uses in System Settings →
  Battery); existing catalog entries show the conventions.
- Liquid Glass: rely on standard components; don't put `glassEffect` on content cards.
- Never name third-party apps, their projects or makers anywhere: code, comments, tests, docs,
  commit messages, PRs, issues, release notes. Describe the technique or the evidence instead
  ("a public capture from an M4 Max"). Apple's own apps and frameworks are fine.
