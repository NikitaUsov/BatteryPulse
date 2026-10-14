# BatteryPulse

[![CI](https://github.com/NikitaUsov/BatteryPulse/actions/workflows/ci.yml/badge.svg)](https://github.com/NikitaUsov/BatteryPulse/actions/workflows/ci.yml)
![Swift 6](https://img.shields.io/badge/Swift-6-F05138?logo=swift&logoColor=white)
![Platforms](https://img.shields.io/badge/platforms-macOS%2014%2B%20%7C%20iOS%2017%2B-lightgrey)
[![License: GPL v3](https://img.shields.io/badge/license-GPLv3-blue)](LICENSE)

A lightweight, native battery and charging inspector for macOS and iOS: health, cycle
count, capacity in mAh, live power draw, cell voltages, temperature and charger details.
Built with Swift and SwiftUI, with no third-party dependencies.

> **Status: early development.** The `bpulse` command-line tool works on macOS today. The
> menu-bar app and the iOS app come next. See the [roadmap](docs/ROADMAP.md) (in Russian).

## Try it on your Mac

```sh
git clone https://github.com/NikitaUsov/BatteryPulse.git
cd BatteryPulse
swift run bpulse              # battery report
swift run bpulse --watch 2    # live view, refreshed every 2 s
swift run bpulse --json       # machine-readable snapshot
swift run bpulse --raw > battery.plist   # raw IOKit data, serial numbers redacted
```

Example output (from a test fixture):

```text
Charge           54 %  (3136 of 5807 mAh)
State            Charging
Time to full     52 min
Battery power    +49.6 W  (12.65 V × 3920 mA)
Health           96.4 %  (6024 of 6249 mAh design)
Condition        Good
Cycles           214 of 1000  (21 % of rated life)
Temperature      33.5 °C
Cells            4012 / 4015 / 4011 mV  (spread 4 mV)
Adapter          96 W · 96W USB-C Power Adapter · 20.0 V × 4.70 A
Charger request  4000 mA at 13.05 V
System input     73.2 W
System load      22.5 W
```

Requires Xcode 16 or later (Swift 6 toolchain) on macOS 14 or later.

## What each platform exposes

| Data                                   | macOS | iOS                     |
|----------------------------------------|:-----:|:-----------------------:|
| Charge level and charging state        | ✅    | ✅                      |
| Time to empty / full                   | ✅    | estimated by the app    |
| Health, cycle count, capacity (mAh)    | ✅    | via analytics import*   |
| Voltage, current, power, cell voltages | ✅    | —                       |
| Battery temperature                    | ✅    | via analytics import*   |
| Power adapter details                  | ✅    | —                       |
| Low Power Mode, thermal state          | ✅    | ✅                      |

\* iOS doesn't expose these to App Store apps. The planned workaround is to import the
analytics file that iOS lets you export from Settings. No private APIs are involved.

On macOS everything is read from the public IOKit power-source API and the
`AppleSmartBattery` registry entry. No root, kernel extension or SMC access is needed.

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
`swift run bpulse --raw > capture.plist` and attach the file to a
[bug report](https://github.com/NikitaUsov/BatteryPulse/issues/new/choose) together with your
Mac model and macOS version. Serial numbers are redacted automatically.

## License

[GNU GPL v3](LICENSE)
