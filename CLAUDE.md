# BatteryPulse — notes for Claude

Native battery/charging inspector for macOS and iOS. Swift 6, SwiftUI, zero dependencies.
Plan, decisions and status: `docs/ROADMAP.md`. Everything in the repository is English only.

Targets: macOS 27 / iOS 27, Apple Silicon only (no Intel code). macOS ships as a DMG, not
through the App Store. Reference hardware: MacBook Air M5.

## Layout

- `Sources/BatteryCore` — platform-independent: `PropertyValue` (normalized plist/CF values),
  `BatterySnapshot` model, `MacPowerParser` (AppleSmartBattery + IOPS + adapter dictionaries),
  metrics, `BatteryReport` text output. Must stay free of Apple-only frameworks.
- `Sources/BatteryKit` — `BatteryProvider` protocol, `MacBatteryProvider` (IOKit),
  `IOSBatteryProvider` (UIDevice), `BatteryMonitor` (@Observable, event-driven + optional polling).
- `Sources/BatteryPulseApp` — SwiftUI menu-bar app (product `BatteryPulse`): `MenuBarExtra`
  popover, Details, Settings and Welcome windows. Everything is inside `#if os(macOS)`; a stub
  `main` keeps Linux builds working. Display strings live in `BatteryCore/BatteryPresentation`
  so they are tested on Linux. `scripts/build-app.sh` packages `.app` + `.dmg`;
  `Resources/AppIcon.svg` is the icon source (`AppIcon.png` is rendered from it, and
  `AppIconView` draws the same design in SwiftUI).
- `Sources/bpulse` — CLI. `--raw` writes the capture format used by test fixtures; `--input`
  renders a capture (works on Linux).
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
  `FullChargeCapacity`, `NominalChargeCapacity`, `DesignCapacity`); there is no `Temperature` or
  `CellVoltage`. Health is capped at 100 % like System Settings; no condition key means "Normal".
- Linux Foundation quirk: NSNumber 0/1 casts to `Bool`, and `Int` in `Any` doesn't cast to
  `Int64` — go through `PropertyValue(any:)`, never cast raw values directly.
- Tests use swift-testing (`import Testing`, `@Test`, `#expect`).
