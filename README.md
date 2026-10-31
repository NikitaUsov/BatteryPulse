# BatteryPulse

[![CI](https://github.com/NikitaUsov/BatteryPulse/actions/workflows/ci.yml/badge.svg)](https://github.com/NikitaUsov/BatteryPulse/actions/workflows/ci.yml)
![Swift 6](https://img.shields.io/badge/Swift-6-F05138?logo=swift&logoColor=white)
![Platform](https://img.shields.io/badge/platform-macOS%2027%2B-lightgrey)
![Apple Silicon](https://img.shields.io/badge/Mac-Apple%20Silicon-black?logo=apple)
[![License: GPL v3](https://img.shields.io/badge/license-GPLv3-blue)](LICENSE)

A lightweight, native battery and charging inspector for macOS: charge, health, cycle count,
capacity in mAh, temperature and cell voltages, live power flow, history, and power adapter
details down to its USB Power Delivery profiles. Built with SwiftUI and Liquid Glass, in English and Russian, with no third-party
dependencies.

> **Status: early development**, verified on a MacBook Air M5 with macOS 27. See the
> [roadmap](docs/ROADMAP.md) and the [User Guide](docs/USER_GUIDE.md).

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
- Battery voltage, current, power and temperature, time remaining and optimized charging, and
  while charging the current and voltage the battery asks the charger for.
- The power adapter: name, maker, rated power, the negotiated voltage × current, and every USB
  Power Delivery voltage it offers.
- System: power from the adapter, system load, adapter loss, Low Power Mode, thermal state.

**Health**
- Maximum capacity as System Settings shows it, plus the real ratio to design capacity (a new
  battery often holds more than 100 %).
- Condition, cycle count, how much of the rated cycle life is used, design, nominal,
  full-charge and remaining capacity, and the gauge chip.
- The voltage of each cell and the spread between them.

**Compact window**
- A small, fixed-size window with the essentials; it can be the window BatteryPulse opens.

**History**
- Charge, power (battery and Mac) and temperature over the last 24 hours or 7 days, with plugged-in stretches
  shaded and a readout under the pointer.
- The period's average drain per hour, time on battery, energy from the battery and charging
  sessions; capacity and cycle count day by day.
- Recorded about once a minute while BatteryPulse runs; kept on your Mac for 10 days (daily
  summaries for good).
- Export to CSV (minute readings or daily health, in your region's spreadsheet format) or
  JSON (both), with units in the column names.

**iPhone and iPad** (Settings → General, off until you turn it on)
- A page for each iPhone or iPad connected to the Mac: charge, maximum capacity and cycle count
  as iOS Settings shows them, capacities in mAh, temperature, voltage, the charger and the month
  of first use, with its history next to the Mac's on the History page.
- Read when it's plugged in, then every 5 minutes while history is recorded and every minute
  while its page is open; over Wi-Fi only when you click Refresh or Check Again. The device
  must trust this Mac: BatteryPulse never pairs by itself and keeps no identifier or serial
  number on disk.

**Accessories**
- The batteries of Bluetooth keyboards, mice, trackpads, headphones and game controllers
  connected to this Mac, as macOS reports them: an Accessories page in the Devices section and
  rows in the menu bar popover, with each part's charge, such as each AirPods bud and the case.
- No Bluetooth permission and no polling; an optional notification when one runs low.

**Notifications** (Settings → Notifications, all off until you turn them on)
- When the charge reaches 80–100 % (unplugging around 80 % slows battery aging), when it falls
  to 10–30 %, when battery service is recommended, when the Mac runs hot, and when an
  accessory falls to 10–30 %.

**Widgets** (configurable from 0.7)
- A Battery widget for the desktop and Notification Center, in small, medium and large: charge,
  state, when the battery will be full or empty, maximum capacity, cycles and temperature as it
  comes, and in Edit Widget the main value, a ring or a drawn battery, clock time or time left,
  level colors or monochrome and the details you choose. A widget placed before 0.7 keeps its
  look.
- An Accessories widget, in the same three sizes: the batteries of your keyboard, mouse,
  trackpad and headphones, all of them or the lowest.
- A click opens the matching page in the main window.

**Menu bar**
- Any mix of the battery icon, charge, battery power and temperature.
- Icon styles drawn to the exact level — Modern (like macOS 27), Classic, Percentage Inside
  (like macOS 27 with the percentage on), Ring, or the SF Symbol — with charging, plugged-in,
  low and Low Power Mode states, so it can take the place of the system battery item.
- A popover with charge, state, time, maximum capacity, cycles, temperature, adapter, system
  load and accessory batteries.
- Optional: without it BatteryPulse lives in the Dock. Dock icon on demand, a Dock menu, and
  opening at login.

**Developer section** (off by default; Settings → Advanced)
- *Raw Data*: every value from `AppleSmartBattery` and the entries below it (pack, cells,
  charger), the IOPS power source, the adapter and the SMC's battery keys in one table, decoded into units, durations, dates, bit fields and USB-PD offers and contracts, with
  what each key means where that's known. An inspector shows the selected row in full. Filter,
  copy rows with ⌘C, Copy JSON, and Export Capture for bug reports (serial numbers redacted).
- *Demo Mode*: twelve simulated scenes — fast charging, low and critical battery, optimized
  charging, a worn battery, heavy load, a slow charger, Low Power Mode, no battery and more — and
  two animations, shown everywhere in the app. Pick them by hand or play a tour that switches
  pages by itself; floating controls step through it, and real readings return when you stop.

**Also**
- *Copy Report*: a plain-text report without serial numbers.
- English and Russian, chosen like any Mac app in System Settings → Language & Region.
- A welcome window with the starting settings on first launch.
- Motion that follows the battery: the charge rolls, gauges fill and the bolt draws in when
  charging starts, with fades under Reduce Motion and nothing animating in windows you can't
  see. Liquid Glass on the controls (the History switch in the toolbar and the Demo Mode bar),
  never on the content.
- *Window Style* (Settings → General) for the main and compact windows: Standard, Frosted (the
  desktop blurred behind the window), and two beta styles that Settings → Advanced → Beta window
  styles adds: Translucent (one sheet of Liquid Glass with a dimming layer) and Clear (pure
  glass, white content). Reduce Transparency or Increase Contrast gives Standard.
- Native SwiftUI with Liquid Glass and no third-party code. No root and no kernel extension;
  the SMC is only ever read. Updates are event-driven, plus one reading a minute for the
  history while recording is on, so it uses almost no CPU in the background. It reaches the
  internet only to talk to GitHub: an optional update check against GitHub releases, which sends
  nothing about your Mac, from 0.7 an anonymous version count once per version (see
  [Privacy](#privacy)), and the download of an update you chose to install. Reading an iPhone or
  iPad over Wi-Fi (opt-in) stays on your local network.
- *Check for Updates…* in the app menu, an automatic check daily, weekly, monthly or never
  (Settings → General), and a What's New window after updates that add features. From 0.4.0,
  *Install and Relaunch* installs the next version from inside the app; each release is
  signed, and the app checks the signature before replacing itself.
- An About window with the version, links and the license.

Build it from source:

```sh
git clone https://github.com/NikitaUsov/BatteryPulse.git
cd BatteryPulse
swift run BatteryPulse        # run straight from the source (English only, no login item)
scripts/build-app.sh          # build build/BatteryPulse.app and build/BatteryPulse.dmg
```

A copy you build yourself opens without the first-launch step. CI also uploads a DMG for every
run as a workflow artifact (needs a GitHub sign-in; kept for 90 days).

## Privacy

BatteryPulse has no account, no analytics service and no server of its own. Your battery
readings, history, devices and settings stay on your Mac. It connects to the internet only to
reach GitHub: to check for updates (daily, weekly, monthly or never, as you choose in Settings →
General), to download an update you chose to install, and, from 0.7, for an anonymous version
count. Once per version, at least a day after you start using it, an automatic update check also
downloads a small file from that version's release on GitHub. GitHub counts downloads, and that
public count is the only number the developer gets: how many Macs use each version. No
identifier of any kind is sent, no cookie is kept, and nothing about your Mac, its battery or
your settings is included. As with any web request, GitHub sees your IP address and the app's
version, just as it does for the update check, under GitHub's own privacy statement. The
developer never sees addresses, only totals that anyone can read through GitHub's API. The count
is on by default, never happens when Check for updates is Never, and turns off with **Include
this Mac in the anonymous version count** in Settings → General. Reading an iPhone or iPad over
Wi-Fi (opt-in) stays on your local network.

The [User Guide](docs/USER_GUIDE.md#privacy) says when each request happens.

## Command-line report

```sh
swift run bpulse              # battery report
swift run bpulse --watch 2    # live view, refreshed every 2 s
swift run bpulse --json       # machine-readable snapshot
swift run bpulse --raw > battery.xml    # raw IOKit data, serial numbers redacted
swift run bpulse --record ~/bp-capture   # captures at every charging change, for bug reports
swift run bpulse --smc        # the SMC's battery and charger keys; values of the battery ones
swift run bpulse --devices    # iPhones and iPads connected by USB or Wi-Fi
swift run bpulse --device 1   # battery of device 1; add --json, or --raw for a redacted capture
swift run bpulse --accessories   # Bluetooth accessories' batteries; --json, or --raw (pseudonymized)
swift run bpulse --export csv > samples.csv   # recorded history; --days for daily health
swift run bpulse --export json > history.json # all recorded history as JSON
```

The device report shows Maximum capacity as iOS Settings does (checked against an iPhone 17
Pro Max on iOS 27), the cycle count, the date of first use and the battery's temperature.
`--input` renders a saved capture, of a Mac or of a device. Reading an iPhone or iPad needs the
device to trust this Mac (unlock it and tap Trust); BatteryPulse never pairs by itself. The
app shows them too; see [iPhone and iPad](docs/USER_GUIDE.md#iphone-and-ipad).

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

## What macOS exposes

| Data                                   | macOS |
|----------------------------------------|:-----:|
| Charge level and charging state        | ✅    |
| Time to empty / full                   | ✅    |
| Health, cycle count, capacity (mAh)    | ✅    |
| Voltage, current, battery power        | ✅    |
| System input, load, adapter loss       | ✅    |
| Cell voltages, battery temperature     | ✅†   |
| Power adapter details                  | ✅    |
| Low Power Mode, thermal state          | ✅    |

† macOS 27 moved them from `AppleSmartBattery` to the registry entries below it (the pack and
one bank per cell). BatteryPulse reads those, and the SMC's battery keys as a second source for
the cell voltages and the temperature.

On macOS everything is read from the public IOKit power-source API, the `AppleSmartBattery`
registry entry and its children, and, read-only, the SMC. No root or kernel extension is
needed.

## Architecture

```text
BatteryCore   platform-independent models, parsing, metrics, raw-value decoding, demo data,
              text report (tested on Linux)
BatterySource the battery and accessory reads: IOKit and the read-only SMC (macOS) / UIDevice
              (iOS), with their loggers and signposts; with BatteryCore and BatteryArt, all the
              widget links
BatteryKit    on top of BatterySource: demo providers, an @Observable BatteryMonitor, iPhone and
              iPad reads, update signatures
BatteryArt    the drawn battery icon's painter, shared by the menu bar and the widget (macOS)
BatteryPulse  SwiftUI app: main and compact windows, menu bar item, history, notifications,
              update check, settings (Sources/BatteryPulseApp)
BatteryPulseWidget  WidgetKit extension, wrapped into the app as an .appex by build-app.sh
Resources     app icon and the String Catalog with the Russian translation
bpulse        command-line report for macOS
```

`BatteryMonitor` is event-driven: it re-reads the battery when the OS posts a power-source
change. Fast polling is enabled only while a view displays live values, and the history
recorder reads once a minute while recording is on.

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
