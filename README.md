# BatteryPulse

[![CI](https://github.com/NikitaUsov/BatteryPulse/actions/workflows/ci.yml/badge.svg)](https://github.com/NikitaUsov/BatteryPulse/actions/workflows/ci.yml)
![Swift 6](https://img.shields.io/badge/Swift-6-F05138?logo=swift&logoColor=white)
![Platforms](https://img.shields.io/badge/platforms-macOS%2027%2B%20%7C%20iOS%2027%2B-lightgrey)
![Apple Silicon](https://img.shields.io/badge/Mac-Apple%20Silicon-black?logo=apple)
[![License: GPL v3](https://img.shields.io/badge/license-GPLv3-blue)](LICENSE)

A lightweight, native battery and charging inspector for macOS and iOS: health, cycle
count, capacity in mAh, live power draw, charger and adapter details. Built with Swift and
SwiftUI, with no third-party dependencies.

> **Status: early development.** The `bpulse` command-line tool works on macOS today. It is
> verified on a MacBook Air M5 running macOS 27. The menu-bar app (distributed as a DMG) and
> the iOS app come next. See the [roadmap](docs/ROADMAP.md).

## Try it on your Mac

```sh
git clone https://github.com/NikitaUsov/BatteryPulse.git
cd BatteryPulse
swift run bpulse              # battery report
swift run bpulse --watch 2    # live view, refreshed every 2 s
swift run bpulse --json       # machine-readable snapshot
swift run bpulse --raw > battery.xml    # raw IOKit data, serial numbers redacted
```

Example output (MacBook Air M5, macOS 27, charging):

```text
Battery         bq40z651
Charge          70 %  (3896 of 5866 mAh)
State           Charging
Time to full    ≈ 5 h 8 min
Battery power   +4.7 W  (12.26 V × 384 mA)
Health          100.0 %  (6010 of 5760 mAh design = 104.3 %)
Condition       Normal
Cycles          48 of 1000  (5 % of rated life)
Adapter         60 W · 40W Pwr Adapter 60W Max · 20.0 V × 2.99 A
System input    18.5 W
System load     14.0 W
Adapter loss    0.5 W
Low Power Mode  off
```

`≈` marks values the app derives itself (here macOS was still calculating). Health is capped
at 100 % the way System Settings shows it; the real ratio to design capacity follows it.

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
