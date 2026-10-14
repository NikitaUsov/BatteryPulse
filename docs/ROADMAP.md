# BatteryPulse roadmap

A lightweight native Swift/SwiftUI app for macOS and iOS that shows detailed battery and
charging state.

## Decisions

- **Platforms:** macOS 27 and iOS 27 minimum. On the Mac this means Apple Silicon only, since
  macOS 27 no longer runs on Intel Macs. No Intel code paths.
- **Distribution (macOS):** a DMG outside the App Store. The app is not sandboxed, so SMC reads
  (and later charge limiting) are possible. A notarized DMG needs a paid Apple Developer
  account; without one, users have to approve the app in Privacy & Security.
- **Distribution (iOS):** undecided. Personal installs from Xcode work with a free Apple ID
  (re-signed every 7 days); TestFlight and the App Store need the paid account.
- **Reference hardware:** MacBook Air M5 running macOS 27.

## Principles

- **No third-party dependencies.** System frameworks only.
- **Event-driven.** Readings update on OS power notifications. Fast polling (every 2 s) runs
  only while a view shows live values such as current or power.
- **Platform-independent core.** `BatteryCore` has no Apple-only dependencies and is tested on
  Linux and macOS against real captures (`bpulse --raw`).
- **Swift 6 with strict concurrency.**
- **Resource targets (macOS):** about 0 % CPU when idle, under 30 MB RAM, binary under 5 MB.

## What the platforms expose

| Reading                                      | macOS 27 | iOS 27                |
|----------------------------------------------|:--------:|:---------------------:|
| Charge level, charging state                 | ✅       | ✅ `UIDevice`          |
| Optimized charging hold                      | ✅*      | —                     |
| Time to empty / full                         | ✅       | estimated by the app  |
| Capacity in mAh (remaining / full / design)  | ✅       | analytics import      |
| Health (Maximum Capacity), cycle count       | ✅       | analytics import      |
| Voltage, current, battery power              | ✅       | —                     |
| Adapter: watts, volts, amps, model           | ✅       | —                     |
| System input, system load, adapter loss      | ✅       | —                     |
| Cell voltages, battery temperature           | SMC (planned) | analytics import |
| Low Power Mode, thermal state                | ✅       | ✅                    |

On a MacBook Air M5 with macOS 27, `AppleSmartBattery` keeps the mAh values in its
`BatteryData` dictionary and no longer publishes `Temperature` or `CellVoltage`.

\* Read from IOPS `Optimized Battery Charging Engaged`, which macOS only publishes while the
charge is on hold; not yet seen in a macOS 27 capture.

On iOS the public API only provides level and state. The rest can come from the analytics file
iOS lets users export (Settings → Privacy & Security → Analytics & Improvements → Analytics
Data), without private APIs. The format still has to be checked against a real file.

## Architecture

```
BatteryCore  (Linux + Apple)   models, parsing, metrics, text report; later history
     ▲
BatteryKit   (Apple)           IOKit (macOS) / UIDevice (iOS), BatteryMonitor (@Observable)
     ▲
bpulse (CLI, macOS)    App (SwiftUI: macOS menu bar + iOS)    Widgets
```

## Stages

### Stage 0: Foundation ✅

- [x] Swift package: `BatteryCore`, `BatteryKit`, `bpulse`
- [x] Parser for AppleSmartBattery, IOPowerSources and adapter details
- [x] Metrics: health, wear, power, cell spread, time estimates
- [x] `BatteryMonitor`: OS-event updates plus an on-demand live mode
- [x] `bpulse` CLI (`--json`, `--raw`, `--watch`, `--input`)
- [x] CI: Linux (core tests and lint) and macOS 27 (build, tests, iOS build of BatteryKit)
- [x] Verified on a real MacBook Air M5 (macOS 27); real captures are the test fixtures

### Stage 1: macOS MVP (menu-bar app)

- [x] SwiftUI app target built with SwiftPM (`swift run BatteryPulse`), no Dock icon
- [x] `MenuBarExtra`: icon plus percentage and/or power (configurable)
- [x] Popover: charge, state, time, live power, health, cycles, adapter
- [x] Details window: every reading by group, filterable raw IORegistry keys, "Copy Report"
- [x] Settings: menu-bar content, launch at login (`SMAppService`)
- [x] App icon and first-launch welcome window with the starting settings
- [x] DMG packaging (`scripts/build-app.sh`, built by CI)
- [ ] Verify the UI on the M5 and polish it from screenshots
- [ ] Battery temperature and cell voltages from the SMC
- [ ] String Catalog for localization
- [ ] Profile in Instruments against the resource targets
- [ ] Developer ID signing and notarization

### Stage 2: iOS MVP

- [ ] iOS target sharing SwiftUI components with macOS
- [ ] Screen: charge, state, Low Power Mode, thermal state
- [ ] Charging session while the app is open: %/min, estimate to 100 %
- [ ] Analytics file import (Share Sheet / Files): cycles, health, capacity, temperature

### Stage 3: History and charts

- [ ] Compact sample store in `BatteryCore` (append-only, tested on Linux)
- [ ] macOS background recording (the app lives in the menu bar anyway)
- [ ] Swift Charts: charge and power over 24 h / 7 days, health and cycles over time
- [ ] Statistics: average drain, time on battery, charging sessions

### Stage 4: Widgets and notifications

- [ ] WidgetKit (macOS + iOS): charge, health
- [ ] iOS Live Activity while charging
- [ ] Notifications: charge threshold reached, overheating, "Service Recommended"

### Stage 5: Later (optional)

- [ ] Mac battery on the iPhone via iCloud
- [ ] Bluetooth device batteries on macOS (AirPods, mouse, keyboard)
- [ ] CSV/JSON export
- [ ] Charge limiting (like AlDente): needs a privileged helper and SMC writes
- [ ] Notarized DMG and a Homebrew cask

## Development environment

- **Claude cloud sessions** (Linux, Swift 6.4): `swift build`, `swift test`. Everything builds
  and tests except code under `#if os(macOS)` / `#if os(iOS)`.
- **CI** (`xcode-27` runner: macOS 27, Xcode 27): builds and tests the Darwin code and builds
  `BatteryKit` for iOS.
- **The maintainer's Mac:** running the tools and the UI: `swift run BatteryPulse`,
  `swift run bpulse`, or `scripts/build-app.sh` for the packaged app.
