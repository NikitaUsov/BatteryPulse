# BatteryPulse User Guide

BatteryPulse shows what your Mac's battery and charger are really doing: charge, health, cycle
count, capacity in mAh, temperature and cell voltages, live power, and the power adapter. It is
a native macOS app with no third-party code; it only reads system data and needs no
administrator rights.

- [Install](#install)
- [Where BatteryPulse lives](#where-batterypulse-lives)
- [The main window](#the-main-window)
- [Compact window](#compact-window)
- [History](#history)
- [Notifications](#notifications)
- [Widget](#widget)
- [Demo Mode](#demo-mode)
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

Until BatteryPulse is notarized, you need to do this once for each new version you download. A
copy you build yourself (see the README) opens without it.

## Where BatteryPulse lives

By default BatteryPulse sits in the **menu bar**. Click its icon for a quick look at charge,
time remaining, power, health and cycles; **Open BatteryPulse** opens the main window.

You decide where it appears (Settings → General):

- **Show in menu bar** — the status item with the battery icon.
- **Show Dock icon** — keeps an icon in the Dock. Even when it's off, the Dock icon appears while
  a BatteryPulse window is open, so you can switch to it with ⌘-Tab.

BatteryPulse never hides from both places: if it isn't in the menu bar, it always has a Dock
icon, and it keeps running after you close its window (click the Dock icon to bring the window
back, or press ⌘Q to quit).

If the menu bar item disappears because macOS hid it, allow BatteryPulse again in System
Settings → Menu Bar. While BatteryPulse is running, opening it again from Applications or
Spotlight also brings up its window.

## The main window

- **Overview** — charge with a battery drawn to the exact level, what the battery is doing
  ("Charging at 31.3 W"), time remaining, gauges for charge, maximum capacity and cycle count,
  capacity bars in mAh, and a power-flow diagram from the adapter to the Mac and the battery.
- **Power** — battery voltage, current, power and temperature, and while charging the current
  and voltage the battery asks the charger for; the power adapter (name, rated power,
  negotiated voltage and current) and every USB Power Delivery voltage it offers; power from the
  adapter, system load, adapter loss, Low Power Mode and thermal state.
- **History** — charge, power and temperature over time; see [History](#history).
- **Health** — maximum capacity, condition, cycle count and how much of the rated cycle life is
  used; design, nominal, full-charge and remaining capacity; and the voltage of each cell with
  the spread between them.
- **Developer** — a sidebar section, off by default (Settings → Advanced), with two pages:
  - **Raw Data** — every raw value macOS reports, in a table with a readable decoding (mAh,
    volts, watts, temperatures, times, dates, bit fields, USB Power Delivery offers and the
    active contract) and a short description of what the key means where that's known. Besides
    `AppleSmartBattery` there are sections for the entries below it (the battery pack, each
    cell, the charger), the power source, the adapter, and the battery keys read from the SMC.
    Filter by key, value or description; select rows and press ⌘C (or right-click) to copy
    them. Double-click a row, or click the inspector button in the toolbar, to see its full
    value, decoding and description. **Copy JSON** and **Export Capture…** are in the toolbar.
  - **Demo Mode** — simulated battery states; see [Demo Mode](#demo-mode).

**Copy Report** in the toolbar copies a plain-text report without serial numbers.

Live values refresh every 2 seconds while a window or the menu bar popover is open, and every
10 seconds when the menu bar shows power. Otherwise BatteryPulse only updates when macOS reports
a change, so it uses almost no CPU in the background.

## Compact window

For a quick look without the sidebar, BatteryPulse has a small window of a fixed size, like
coconutBattery's: the charge, what the battery is doing, time remaining, capacity bars, maximum
capacity, cycle count, battery power, temperature and the adapter. Open it with **Compact
Window** in the main window's toolbar, and go back with **Full Window** in its own toolbar. To
make it the window BatteryPulse opens, choose **Open BatteryPulse in: Compact window** in
Settings → General.

## History

BatteryPulse records the battery about once a minute while it runs (in the menu bar, the Dock,
or at login), and right away when you plug in, unplug or the charge state changes. The
**History** page shows:

- **Charge** over the last 24 hours or 7 days. Shaded stretches are times on the power adapter,
  a little stronger while charging than while the charge is full or held; gaps are times the Mac
  slept or BatteryPulse wasn't running. Hover over a chart to read the values at that moment.
- **Power**: what flows into (+) or out of (−) the battery, and what the whole Mac uses.
- **Temperature** of the battery, when the Mac reports it.
- The period's figures:
  - **Average drain** per hour on battery, from the charge at the start and end of each stretch
    on battery. It appears once there's at least half an hour on battery and 3 percent used;
    shorter stretches are too coarse with whole percentages.
  - **On battery**: time unplugged while the Mac was awake and BatteryPulse was recording.
  - **Energy from battery** in watt-hours, including any the battery gave while plugged in to an
    adapter too weak for the load.
  - **Charging sessions**: times you plugged in. A held charge and an unplug of less than two
    minutes don't count as new sessions.
- **Battery Health**: capacity compared with design and the cycle count, one point per day,
  so you can watch the battery age over months.

Minute-by-minute history is kept for the last 10 or so days with records, one file per day, and
the daily summary for good, in `~/Library/Application Support/io.github.nikitausov.BatteryPulse/History`
on your Mac only.
Turn recording off or clear it in Settings → Advanced. Nothing is recorded during Demo Mode.

## Notifications

In Settings → Notifications, BatteryPulse can tell you:

- **When charged to** 80, 85, 90, 95 or 100 %. Unplugging around 80 % most of the time slows
  battery aging.
- **When the battery falls to** 10, 20 or 30 % on battery.
- **When battery service is recommended**, once each time macOS reports a condition other than
  Normal.
- **When the Mac gets hot**, once each time the thermal state turns high or critical, at most
  once an hour.

Each notification comes once and only again after the battery has clearly moved away (5 points
below the charge limit, or unplugged; 5 points above the low-battery level, or plugged in).
A low-battery notification disappears from Notification Center when you plug in, and a
charge-level one when you unplug. macOS asks for permission the first time you turn one on;
**Send Test Notification** shows what they look like. BatteryPulse has to be running to notify
you.

## Widget

BatteryPulse has a widget for the desktop and Notification Center, in two sizes: the small one
shows the charge, what the battery is doing and when it will be full or empty; the medium one
adds maximum capacity, cycle count and temperature.

1. Open BatteryPulse once after installing it, so macOS finds the widget.
2. Control-click the desktop and choose **Edit Widgets…** (or click the date in the menu bar
   and **Edit Widgets** at the bottom).
3. Search for **BatteryPulse** and drag the widget where you want it.

The widget reads the battery itself, so it keeps working while BatteryPulse isn't running.
macOS limits how often widgets refresh, so it may lag a few minutes behind; while BatteryPulse
runs, it refreshes the widget right away when you plug in or unplug.

The widget is new and depends on how macOS treats apps that aren't notarized yet. If it doesn't
appear in the widget gallery, please [report it](#reporting-a-problem); the main window, the
compact window and the menu bar work either way.

## Demo Mode

Demo Mode fills BatteryPulse with simulated data, so you can see how it handles every state
without touching the charger: in the main window, in the menu bar and in its popover. Nothing on
your Mac changes, and real readings come back as soon as you stop.

Open it from the sidebar (Developer → Demo Mode; turn the section on in Settings → Advanced):

- **Start Tour** plays every scene and animation in turn and switches to the page that shows
  each one best, then starts over. Choose how long each scene stays under **Scene length**.
- Click a **scene** to show it by hand: fast charging, on battery, low battery, critical
  battery, fully charged, optimized charging, just plugged in, a worn battery, heavy load, a slow
  charger, Low Power Mode, or a Mac without a battery.
- Click an **animation** to watch the battery charge from empty or drain to empty in 20
  seconds.

While the demo runs, a bar at the bottom of the window shows the current scene with buttons for
the previous scene, play/pause (pause also freezes an animation), the next scene and stopping
the demo. The menu bar shows a demo symbol next to the simulated values, and its popover shows a
**Demo** badge with **Stop Demo**. Copy Report, Copy JSON and Export Capture are unavailable
during the demo, so a bug report always contains real data. The demo stops when you quit or turn
the Developer section off.

## Settings

Open Settings with ⌘, or the gear button in the menu bar popover.

| Tab | What it controls |
|-----|------------------|
| General | Menu bar item, Dock icon, open at login, the welcome window, update checks, language |
| Menu Bar | Show percentage, battery power, both, or just the icon; icon size (standard, large, hidden) |
| Notifications | Charge limit, low battery, battery service and heat notifications |
| Advanced | Recording and clearing history, the Developer section (Raw Data and Demo Mode), a link to this guide |

### Updates

BatteryPulse checks GitHub for a new version once a day (turn it off in Settings → General), and
**BatteryPulse → Check for Updates…** checks right away. When a new version is out, a window
shows its release notes with **Download**, **Remind Me Later** and **Skip This Version**.
Download opens the DMG in your browser: open it, drag BatteryPulse onto Applications to replace
the old copy, and approve the new version once in Privacy & Security (see
[First launch](#first-launch)). It's the only network request BatteryPulse makes: GitHub sees
your IP address, the app's version and your language, as with any web request, and nothing else
about your Mac is sent. If GitHub limits requests from your network, the check waits and tries
again later.

After an update, a **What's New** window lists the new features once; it's also in the Help menu.

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
- **Temperature** is the battery pack's own sensor, and **cell voltages** come from each cell
  of the pack. macOS 27 keeps both on registry entries below the battery rather than on the
  battery itself; when a Mac doesn't have them, BatteryPulse reads the cell voltages from the
  SMC instead and checks that they add up to the battery voltage. The temperature sensors near
  the battery that the SMC also reports are shown in Raw Data only, since they can read several
  degrees off.
- **Spread** is the difference between the highest and lowest cell voltage. A few millivolts is
  normal; a spread that keeps growing over months hints at an ageing or unbalanced battery.
- **Requested charge current and voltage** are what the battery asks the charger for. They drop
  as the battery fills up and while macOS holds the charge.

## Command-line report

The repository also has `bpulse`, a command-line report (`swift run bpulse`). See the
[README](../README.md#command-line-report).

## Reporting a problem

Open an [issue](https://github.com/NikitaUsov/BatteryPulse/issues/new/choose) and attach a
capture: turn on the Developer section, then **Raw Data → Export Capture…** (or run
`swift run bpulse --raw > capture.xml`). Serial numbers are removed from captures and reports.
