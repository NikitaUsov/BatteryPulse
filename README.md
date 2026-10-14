# BatteryPulse

[![CI](https://github.com/NikitaUsov/BatteryPulse/actions/workflows/ci.yml/badge.svg)](https://github.com/NikitaUsov/BatteryPulse/actions/workflows/ci.yml)
![Swift 6](https://img.shields.io/badge/Swift-6-F05138?logo=swift&logoColor=white)
![Platforms](https://img.shields.io/badge/platforms-macOS%2027%2B%20%7C%20iOS%2027%2B-lightgrey)
![Apple Silicon](https://img.shields.io/badge/Mac-Apple%20Silicon-black?logo=apple)
[![License: GPL v3](https://img.shields.io/badge/license-GPLv3-blue)](LICENSE)

A lightweight, native battery and charging inspector for macOS: charge, health, cycle count,
capacity in mAh, live power flow, and power adapter details down to its USB Power Delivery
profiles. Built with SwiftUI and Liquid Glass, in English and Russian, with no third-party
dependencies.

> **Status: early development**, verified on a MacBook Air M5 with macOS 27. The iOS app comes
> later. See the [roadmap](docs/ROADMAP.md) and the [User Guide](docs/USER_GUIDE.md).

## Download

**[Download BatteryPulse.dmg](https://github.com/NikitaUsov/BatteryPulse/releases/latest/download/BatteryPulse.dmg)**
— requires a Mac with Apple silicon and macOS 27.

> **First launch:** BatteryPulse is not notarized yet, so macOS blocks it the first time. Click
> **Done**, then go to **System Settings → Privacy & Security** and click **Open Anyway** next to
> the BatteryPulse message. You do this once for each version you download. Details are in the
> [User Guide](docs/USER_GUIDE.md#first-launch).

## Features

**Overview**
- Charge with a battery drawn to the exact level, what the battery is doing ("Charging at
  31.3 W") and the time remaining, or *Calculating time…* right after you plug in.
- Ring gauges for charge (with the gauge chip's own reading), maximum capacity (coloured by the
  battery's condition) and cycle count out of the rated 1,000.
- Capacity bars in mAh — remaining, full charge and design — on one scale.
- Power flow: adapter → Mac → battery while plugged in, battery → Mac on battery, in live watts.

**Power**
- Battery voltage, current and power, time remaining and optimized charging.
- The power adapter: name, maker, rated power, the negotiated voltage × current, and every USB
  Power Delivery voltage it offers.
- System: power from the adapter, system load, adapter loss, Low Power Mode, thermal state.

**Health**
- Maximum capacity as System Settings shows it, plus the real ratio to design capacity (a new
  battery often holds more than 100 %).
- Condition, cycle count, how much of the rated cycle life is used, design, nominal,
  full-charge and remaining capacity, and the gauge chip.

**Menu bar**
- Percentage, power, both or just the icon, with a standard, large or hidden battery icon.
- A popover with charge, state, time, maximum capacity, cycles, adapter and system load.
- Optional: without it BatteryPulse lives in the Dock. Dock icon on demand, a Dock menu, and
  opening at login.

**Developer section** (off by default; Settings → Advanced)
- *Raw Data*: every value from `AppleSmartBattery`, the IOPS power source and the adapter in one
  table, decoded into units, durations, dates, bit fields and USB-PD offers and contracts, with
  what each key means where that's known. Filter, copy rows with ⌘C, Copy JSON, and Export
  Capture for bug reports (serial numbers redacted).
- *Demo Mode*: twelve simulated scenes — fast charging, low and critical battery, optimized
  charging, a worn battery, heavy load, a slow charger, Low Power Mode, no battery and more — and
  two animations, shown everywhere in the app. Pick them by hand or play a tour that switches
  pages by itself; floating controls step through it, and real readings return when you stop.

**Also**
- *Copy Report*: a plain-text report without serial numbers.
- English and Russian, chosen like any Mac app in System Settings → Language & Region.
- A welcome window with the starting settings on first launch.
- Native SwiftUI with Liquid Glass and no third-party code. No network access, no root, no
  kernel extension; updates are event-driven, so it uses almost no CPU in the background.

Build it from source:

```sh
git clone https://github.com/NikitaUsov/BatteryPulse.git
cd BatteryPulse
swift run BatteryPulse        # run straight from the source (English only, no login item)
scripts/build-app.sh          # build build/BatteryPulse.app and build/BatteryPulse.dmg
```

A copy you build yourself opens without the first-launch step. CI also uploads a DMG for every
run as a workflow artifact (needs a GitHub sign-in; kept for 90 days).

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

Building requires an Apple Silicon Mac with macOS 27 and Xcode 27.

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
BatteryCore   platform-independent models, parsing, metrics, raw-value decoding, demo data,
              text report (tested on Linux)
BatteryKit    IOKit (macOS) / UIDevice (iOS) / demo providers + an @Observable BatteryMonitor
BatteryPulse  SwiftUI app: main window, menu bar item, settings (Sources/BatteryPulseApp)
Resources     app icon and the String Catalog with the Russian translation
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
test fixtures, so the parser is checked against real hardware. In BatteryPulse, turn on
Settings → Advanced → Show Developer section and choose Raw Data → Export Capture… (or run
`swift run bpulse --raw > capture.xml`), then attach the file to a
[bug report](https://github.com/NikitaUsov/BatteryPulse/issues/new/choose) together with your
Mac model and macOS version. Serial numbers are redacted automatically.

## License

[GNU GPL v3](LICENSE)
