# BatteryPulse — notes for Claude

Native battery/charging inspector for macOS and iOS. Swift 6, SwiftUI, zero dependencies.
Plan and status: `docs/ROADMAP.md` (Russian; the maintainer speaks Russian, so reply in Russian).

## Layout

- `Sources/BatteryCore` — platform-independent: `PropertyValue` (normalized plist/CF values),
  `BatterySnapshot` model, `MacPowerParser` (AppleSmartBattery + IOPS + adapter dictionaries),
  metrics, `BatteryReport` text output. Must stay free of Apple-only frameworks.
- `Sources/BatteryKit` — `BatteryProvider` protocol, `MacBatteryProvider` (IOKit),
  `IOSBatteryProvider` (UIDevice), `BatteryMonitor` (@Observable, event-driven + optional polling).
- `Sources/bpulse` — CLI. `--raw` writes the capture format used by test fixtures; `--input`
  renders a capture (works on Linux).
- `Tests/BatteryCoreTests/Fixtures/*.plist` — raw captures. Current ones are synthetic; replace
  or add real ones from `bpulse --raw` when available.

## Environment

- Cloud sessions run on Linux: `swift build` and `swift test` work, but anything under
  `#if os(macOS)` / `#if os(iOS)` (IOKit, UIKit, SwiftUI) is NOT compiled here.
- Darwin code is verified only by CI (`.github/workflows/ci.yml`, `macos-26`, Xcode 26.6 /
  Swift 6.3). After touching Darwin code, push and check the macOS job.
- Keep `swift-tools-version: 6.0` and avoid Swift 6.4-only features: CI's macOS toolchain is 6.3.

## Commands

- `swift build`, `swift test` — run from the repo root.
- `swift format lint --strict -r Sources Tests Package.swift` — CI fails on any warning;
  `swift format format -i -r Sources Tests Package.swift` fixes most of them (config: `.swift-format`).
- `swift run bpulse --input Tests/BatteryCoreTests/Fixtures/<name>.plist` — render a capture.

The SessionStart hook (`.claude/hooks/session-start.sh`) installs the Swift toolchain in cloud sessions.

## Conventions

- Units live in property names: `MAh`, `MV`, `MA`, `MW`. Signed current: negative = discharging.
- Linux Foundation quirk: NSNumber 0/1 casts to `Bool`, and `Int` in `Any` doesn't cast to
  `Int64` — go through `PropertyValue(any:)`, never cast raw values directly.
- Tests use swift-testing (`import Testing`, `@Test`, `#expect`).
