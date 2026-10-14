# BatteryPulse

[![CI](https://github.com/NikitaUsov/BatteryPulse/actions/workflows/ci.yml/badge.svg)](https://github.com/NikitaUsov/BatteryPulse/actions/workflows/ci.yml)
![Swift 6](https://img.shields.io/badge/Swift-6-F05138?logo=swift&logoColor=white)
![Platforms](https://img.shields.io/badge/platforms-macOS%2027%2B%20%7C%20iOS%2027%2B-lightgrey)
![Apple Silicon](https://img.shields.io/badge/Mac-Apple%20Silicon-black?logo=apple)
[![License: GPL v3](https://img.shields.io/badge/license-GPLv3-blue)](LICENSE)

A lightweight, native battery and charging inspector for macOS and iOS: health, cycle
count, capacity in mAh, live power draw, charger and adapter details. Built with Swift and
SwiftUI, with no third-party dependencies.

> **Status: early development.** The menu-bar app and the `bpulse` command-line tool run on
> macOS today, verified on a MacBook Air M5 with macOS 27. The iOS app comes next. See the
> [roadmap](docs/ROADMAP.md).

## Menu-bar app

```sh
git clone https://github.com/NikitaUsov/BatteryPulse.git
cd BatteryPulse
swift run BatteryPulse        # run the app straight from the source
scripts/build-app.sh          # or build build/BatteryPulse.app and build/BatteryPulse.dmg
```

- The menu bar shows a battery icon with the percentage, the battery power, both, or just
  the icon.
- Clicking it opens a popover with charge, time remaining and live power (refreshed every
  2 s while open), plus health, cycles and the adapter.
- **Details…** lists every reading by group, the raw IORegistry keys with a filter, and a
  *Copy Report* button.
- A welcome window on first launch sets the menu-bar content and launch at login.

CI builds the DMG for every commit; download it from the run's artifacts. It is ad-hoc
signed, not notarized, so approve it once in System Settings → Privacy & Security.

## Command-line report

```sh
swift run bpulse              # battery report
swift run bpulse --watch 2    # live view, refreshed every 2 s
swift run bpulse --json       # machine-readable snapshot
swift run bpulse --raw > battery.xml    # raw IOKit data, serial numbers redacted
```

Real output on a MacBook Air M5 (macOS 27) while charging:

```text
Battery         bq40z651
Charge          78 %  (4514 of 5862 mAh)
State           Charging
Time to full    1 h 17 min
Battery power   +31.3 W  (12.87 V × 2432 mA)
Health          100.0 %  (6006 of 5760 mAh design = 104.3 %)
Condition       Normal
Cycles          48 of 1000  (5 % of rated life)
Adapter         60 W · 40W Pwr Adapter 60W Max · 20.0 V × 2.99 A
System input    54.7 W
System load     24.9 W
Adapter loss    1.6 W
Low Power Mode  off
Thermal state   fair
```

Health is capped at 100 % the way System Settings shows it; the real ratio to design capacity
follows it. While macOS is still working out the time remaining, the report says
`calculating…`. When macOS gives no estimate at all, the app derives one from capacity and
current and marks it with `≈`.

Requires an Apple Silicon Mac with macOS 27 and Xcode 27.

## What each platform exposes

| Data                                   | macOS | iOS                     |
|----------------------------------------|:-----:|:-----------------------:|
| Charge level and charging state        | ✅    | ✅                      |
| Time to empty / full                   | ✅    | estimated by the app    |
| Health, cycle count, capacity (mAh)    | ✅    | via analytics import*   |
| Voltage, current, battery power        | ✅    | —                       |
| System input, load, adapter loss       | ✅    | —                       |
| Cell voltages, battery temperature     | —†    | via analytics import*   |
| Power adapter details                  | ✅    | —                       |
| Low Power Mode, thermal state          | ✅    | ✅                      |

\* iOS doesn't expose these to App Store apps. The planned workaround is to import the
analytics file that iOS lets you export from Settings. No private APIs are involved.

† macOS 27 no longer publishes them in `AppleSmartBattery`. Reading them from the SMC is on
the roadmap.

On macOS everything is read from the public IOKit power-source API and the
`AppleSmartBattery` registry entry. No root or kernel extension is needed.

## Architecture

```text
BatteryCore   platform-independent models, parsing, metrics, text report (tested on Linux)
BatteryKit    IOKit (macOS) / UIDevice (iOS) providers + an @Observable BatteryMonitor
BatteryPulse  SwiftUI menu-bar app (Sources/BatteryPulseApp)
bpulse        command-line report for macOS
```

`BatteryMonitor` is event-driven: it re-reads the battery only when the OS posts a
power-source change. Fast polling is enabled only while a view displays live values.

## Development

```sh
swift build
swift test
```

`BatteryCore` and the monitor logic build and test on Linux too. CI runs the core tests on
Linux and builds and tests everything on macOS, including an iOS build of `BatteryKit`.

## Contributing

Raw captures from different Macs are the most valuable contribution right now. They become
test fixtures, so the parser is checked against real hardware. Run
`swift run bpulse --raw > capture.xml` and attach the file to a
[bug report](https://github.com/NikitaUsov/BatteryPulse/issues/new/choose) together with your
Mac model and macOS version. Serial numbers are redacted automatically.

## License

[GNU GPL v3](LICENSE)
