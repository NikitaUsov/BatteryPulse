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
- **App shape:** a regular app with a main window (sidebar: Overview, Power, History, Health,
  optional Developer), a compact window and a widget, plus an optional menu bar item. Users choose menu bar and Dock presence; the app is
  never hidden from both. Liquid Glass comes from standard components only (sidebar, toolbar,
  controls); content uses standard fills, per Apple's HIG.
- **Languages:** English (source) and Russian, in a String Catalog. The language is chosen per
  app in System Settings, like any Mac app. Repository text stays English; the catalog is the only
  place with Russian.

## Principles

- **No third-party dependencies.** System frameworks only.
- **Event-driven.** Readings update on OS power notifications, plus one a minute for history
  while recording is on. Fast polling (every 2 s) runs
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
| Cell voltages, battery temperature           | ✅†      | analytics import      |
| Low Power Mode, thermal state                | ✅       | ✅                    |

On a MacBook Air M5 with macOS 27, `AppleSmartBattery` keeps the mAh values in its
`BatteryData` dictionary and no longer publishes `Temperature` or `CellVoltage`.

† macOS 27 moved them to the entries below `AppleSmartBattery`: `AppleSmartBatteryPack`
(`BatteryData.Temperature` in 0.01 °C), one `AppleSmartBatteryBank` per cell (`CellVoltage`),
and `AppleChargerData` (the charge current and voltage targets). Evidence: Stats' macOS 27 fix
and a macOS 27 `ioreg` capture in MacDashboard, not yet an M5 Air. The SMC (read-only:
`BC1V`… cell voltages, checked against the pack voltage) is the second source. Its battery-area
sensors `TB*T` are not the battery's temperature and stay in Raw Data, and `B0AT`'s unit
(0.1 K or 0.01 °C) is unsettled.

\* Read from IOPS `Optimized Battery Charging Engaged`, which macOS only publishes while the
charge is on hold; not yet seen in a macOS 27 capture.

On iOS the public API only provides level and state. The rest can come from the analytics file
iOS lets users export (Settings → Privacy & Security → Analytics & Improvements → Analytics
Data), without private APIs. The format still has to be checked against a real file.

## Architecture

```
BatteryCore  (Linux + Apple)   models, parsing, metrics, text report, history, SMC wire format
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

### Stage 1: macOS MVP ✅ (released as 0.2.0)

- [x] SwiftUI app target built with SwiftPM (`swift run BatteryPulse`); starts without a Dock
  icon (`LSUIElement`) and shows one only when needed
- [x] `MenuBarExtra`: icon plus percentage and/or power (configurable)
- [x] Popover: charge, state, time, live power, health, cycles, adapter
- [x] Details window (later replaced by the main window), "Copy Report"
- [x] Settings: menu-bar content, launch at login (`SMAppService`)
- [x] App icon and first-launch welcome window with the starting settings
- [x] DMG packaging (`scripts/build-app.sh`, built by CI)
- [x] Main window with a sidebar (Overview, Power, Health, Developer), gauges, capacity bars and
      a power-flow diagram
- [x] Optional menu bar item and Dock icon, Dock menu, Help menu linking to the User Guide
- [x] English and Russian (String Catalog, per-app language in System Settings)
- [x] One-click GitHub release with first-launch instructions
- [x] Verify the new UI on the M5 and polish it from screenshots (English and Russian)
- [x] Developer section: raw values decoded (units, times, USB-PD offers) and explained
- [x] Demo Mode: simulated scenes and animations everywhere in the app, by hand or as a tour

### Stage 1.1: macOS polish and missing readings (0.3)

- [x] Battery temperature and cell voltages: from the registry entries below
  `AppleSmartBattery`, with the SMC (read-only, no root) as a second source for the cells. The
  temperature shows on Power, in the compact window, the widget and History, each cell's voltage
  on Health; `bpulse --smc` lists the SMC's battery keys
- [x] Raw Data inspector for the full description, value and decoding of a row
- [x] Check for updates against the latest GitHub release (no third-party updater) and show
  what's new
- [x] History and charts (see Stage 3)
- [x] Notifications: charge limit, low battery, battery service, heat (see Stage 4)
- [x] Compact mode: a small, fixed-size window with the essentials, like coconutBattery's; switch
  from the toolbar, and choose which window Open BatteryPulse shows
- [x] WidgetKit widget (small and medium), built by SwiftPM and wrapped into an `.appex` by
  `build-app.sh`; sandboxed, reading IOKit itself since ad-hoc signing rules out an App Group.
  Experimental until it is confirmed to appear for a downloaded, quarantined copy
- [ ] Verify on the M5: the registry children and their keys (`ioreg -r -c AppleSmartBattery
  -l -a`), `bpulse --smc` (and that no battery key is privilege-gated on 27), the widget in the
  gallery after Open Anyway and after an update, notification permission for the ad-hoc app,
  and a `bpulse --raw` capture at the macOS Charge Limit stop point
- [ ] Glossary: re-check the keys left out as uncertain, and add captures from other Apple
  silicon Macs (M1–M4) as test fixtures
- [ ] Profile in Instruments against the resource targets
- [ ] Developer ID signing and notarization (needs a paid Apple Developer account), so the
  first launch needs no Open Anyway

### Stage 2: iOS MVP

- [ ] iOS target sharing SwiftUI components with macOS
- [ ] Screen: charge, state, Low Power Mode, thermal state
- [ ] Charging session while the app is open: %/min, estimate to 100 %
- [ ] Analytics file import (Share Sheet / Files): cycles, health, capacity, temperature

### Stage 3: History and charts

- [x] Compact sample store in `BatteryCore` (append-only JSON Lines, tested on Linux)
- [x] macOS background recording about once a minute while the app runs
- [x] Swift Charts: charge and power over 24 h / 7 days, capacity and cycles over time
- [x] Statistics: average drain, time on battery, energy from the battery, charging sessions
- [x] One sample file per UTC day, compacted daily summaries, launch and wake markers,
  samples on state changes, shading from raw samples, hover readout as an overlay, temperature
- [ ] Accessibility chart descriptors (hourly or daily summaries for VoiceOver)
- [ ] Measure App Nap's effect on the minute timer, and how often the mAh values change
- [ ] Apps using the most energy (optional): which apps drain the battery most and at what
  average power over the last hour or day, like Activity Monitor's Energy tab but in watts.
  Researched: per-app ("coalition") energy counters give CPU, GPU and Neural Engine energy in
  nanojoules without root on macOS 26, through private but exported calls that Chromium also
  uses; per-process `proc_pid_rusage(RUSAGE_INFO_V6)` is public but covers only the user's own
  processes and only the CPU. Nobody has shown the coalition calls working without root on
  macOS 27 yet, so a one-day spike on the M5 comes first. Show watts and Wh with an
  "unattributed" remainder (display, memory, radios, idle); history only from when
  BatteryPulse runs

### Stage 4: Widgets and notifications

- [x] WidgetKit (macOS): charge, state, time to full or empty, health, cycles, temperature
- [ ] WidgetKit (iOS)
- [ ] iOS Live Activity while charging
- [x] Notifications (macOS): charge threshold reached, low battery, overheating, "Service
  Recommended"

### Stage 5: iPhone and iPad battery health on the Mac

- [ ] Read the battery of an iPhone or iPad connected by USB or Wi-Fi, like coconutBattery:
  charge, maximum capacity, cycles, design and full-charge capacity, temperature. Researched:
  load Apple's private MobileDevice framework with `dlopen` (no entitlements; the app isn't
  sandboxed), list devices with `AMDeviceNotificationSubscribe`, and ask the
  `com.apple.mobile.diagnostics_relay` service for the device's `AppleSmartBattery` registry
  entry, the same data the Mac has. WhatBattery, an open-source Mac app, does this on iOS 17
  to iPadOS 27. Rely on the trust the user already gave in Finder; no pairing of our own in the
  first version, and no promise that health matches iOS Settings until checked on a real
  iPhone. Keep the transport behind a protocol so the usbmuxd/lockdown protocol can replace
  the framework if Apple breaks it. Start with half a day on the Mac to confirm the calls and
  the iOS 27 keys.
- [ ] Remember each device and keep its history next to the Mac's

### Stage 6: Later (optional)

- [ ] Mac battery on the iPhone via iCloud
- [ ] Bluetooth device batteries on macOS (AirPods, mouse, keyboard)
- [ ] CSV/JSON export
- [ ] Charge limiting (like AlDente): needs a privileged helper and SMC writes
- [ ] Homebrew cask (after notarization)

## Releases

| Version | Date       | Highlights |
|---------|------------|------------|
| 0.2.0   | 2026-10-14 | Main window (Overview, Power, Health), optional menu bar and Dock presence, Developer section with decoded and explained Raw Data and Demo Mode, English and Russian |
| 0.3.0   | 2026-10-14 | Battery temperature and cell voltages, History with charts and statistics, notifications, a widget, the compact window, the Raw Data inspector, update check and What's New |

## Development environment

- **Claude cloud sessions** (Linux, Swift 6.4): `swift build`, `swift test`. Everything builds
  and tests except code under `#if os(macOS)` / `#if os(iOS)`.
- **CI** (`xcode-27` runner: macOS 27, Xcode 27): builds and tests the Darwin code and builds
  `BatteryKit` for iOS.
- **The maintainer's Mac:** running the tools and the UI: `swift run BatteryPulse`,
  `swift run bpulse`, or `scripts/build-app.sh` for the packaged app.
