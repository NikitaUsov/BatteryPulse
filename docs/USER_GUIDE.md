# BatteryPulse User Guide

BatteryPulse shows what your Mac's battery and charger are really doing: charge, health, cycle
count, capacity in mAh, live power, and the power adapter. It is a native macOS app with no
third-party code, and it reads only public system data.

- [Install](#install)
- [Where BatteryPulse lives](#where-batterypulse-lives)
- [The main window](#the-main-window)
- [Settings](#settings)
- [Language](#language)
- [Understanding the numbers](#understanding-the-numbers)
- [Command-line report](#command-line-report)
- [Reporting a problem](#reporting-a-problem)

## Install

BatteryPulse needs a Mac with Apple silicon and macOS 27 or later.

1. Download **BatteryPulse.dmg** from the
   [latest release](https://github.com/NikitaUsov/BatteryPulse/releases/latest).
2. Open it and drag **BatteryPulse** onto **Applications**.
3. Open BatteryPulse from Applications.

### First launch

BatteryPulse is not notarized by Apple yet, so macOS blocks it the first time:

1. When macOS says it can't verify BatteryPulse, click **Done** (not *Move to Trash*).
2. Open **System Settings → Privacy & Security** and scroll down to **Security**.
3. Next to *"BatteryPulse" was blocked to protect your Mac*, click **Open Anyway** and confirm
   with your password or Touch ID.

You only need to do this once. A copy you build yourself (see the README) opens without it.

## Where BatteryPulse lives

By default BatteryPulse sits in the **menu bar**. Click its icon for a quick look at charge,
time remaining, power, health and cycles; **Open BatteryPulse** opens the main window.

You decide where it appears (Settings → General):

- **Show in menu bar** — the status item with the battery icon.
- **Show Dock icon** — keeps an icon in the Dock. Even when it's off, the Dock icon appears while
  a BatteryPulse window is open, so you can switch to it with ⌘-Tab.

BatteryPulse never hides from both places: if it isn't in the menu bar, it always has a Dock
icon. If the menu bar item disappears (for example, because it was turned off in System
Settings → Menu Bar), open BatteryPulse from Applications or Spotlight.

## The main window

- **Overview** — charge with a battery drawn to the exact level, what the battery is doing
  ("Charging at 31.3 W"), time remaining, gauges for charge, maximum capacity and cycle count,
  capacity bars in mAh, and a power-flow diagram from the adapter to the Mac and the battery.
- **Power** — battery voltage, current and power; the power adapter (name, rated power,
  negotiated voltage and current) and every USB Power Delivery voltage it offers; power from the
  adapter, system load, adapter loss, Low Power Mode and thermal state.
- **Health** — maximum capacity, condition, cycle count and how much of the rated cycle life is
  used, plus design, nominal, full-charge and remaining capacity.
- **Developer** — off by default (Settings → Advanced). Raw IORegistry data with a filter,
  charger reason codes, the gauge's last update, **Copy JSON** and **Export Capture…**.

**Copy Report** in the toolbar copies a plain-text report without serial numbers.

Live values refresh every 2 seconds while a window or the menu bar popover is open. Otherwise
BatteryPulse only updates when macOS reports a change, so it uses no CPU in the background.

## Settings

Open Settings with ⌘, or the gear button in the menu bar popover.

| Tab | What it controls |
|-----|------------------|
| General | Menu bar item, Dock icon, open at login, the welcome window, language |
| Menu Bar | Show percentage, battery power, both, or just the icon; icon size (standard, large, hidden) |
| Advanced | The Developer section, a link to this guide |

## Language

BatteryPulse is available in English and Russian. Like other Mac apps, it follows your system
language. To use a different language for BatteryPulse only:

1. Open **System Settings → General → Language & Region** (Settings → General → **Change in
   System Settings…** takes you there).
2. Under **Applications**, click **+**, choose BatteryPulse and pick a language.
3. Quit and reopen BatteryPulse.

## Understanding the numbers

- **Charge** is the percentage macOS shows. The smaller *Gauge* value under it is the battery
  controller's own measurement (remaining ÷ full-charge mAh); macOS keeps a small reserve, so the
  two differ slightly.
- **Maximum capacity** matches System Settings → Battery → Battery Health. macOS caps it at 100 %;
  a new battery often holds more than its design capacity, and BatteryPulse shows the real ratio
  under Health.
- **Cycle count** is out of the rated cycle life reported by the battery (1,000 on current Mac
  notebooks).
- **Time remaining** comes from macOS. Right after you plug in or unplug, macOS takes a minute to
  estimate it, and BatteryPulse shows *Calculating time…*. When macOS gives no estimate at all,
  BatteryPulse estimates it from capacity and current and says *about*.
- **Power flow**: on the adapter, power goes from the adapter into the Mac, and what the Mac
  doesn't use charges the battery. On battery, the battery powers the Mac.
- **Battery temperature and cell voltages** aren't published by macOS 27, so they aren't shown.

## Command-line report

The repository also has `bpulse`, a command-line report (`swift run bpulse`). See the
[README](../README.md#command-line-report).

## Reporting a problem

Open an [issue](https://github.com/NikitaUsov/BatteryPulse/issues/new/choose) and attach a
capture: turn on the Developer section, then **Export Capture…** (or run
`swift run bpulse --raw > capture.xml`). Serial numbers are removed from captures and reports.
