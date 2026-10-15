## What's new in 0.6

- **iPhone and iPad:** turn on *Read iPhone and iPad batteries* in Settings → General and a
  connected iPhone or iPad gets its own page in the new Devices section: charge, maximum
  capacity and cycle count as iOS Settings shows them, the capacities in mAh, temperature and
  the date of first use. BatteryPulse remembers each device and keeps its history, which History
  shows next to the Mac's. It reads a device when it's plugged in, then every 5 minutes while
  battery history is recorded and every minute while its page is open, and only while the setting
  is on.
- **Accessory batteries:** Bluetooth keyboards, mice, trackpads and headphones show their charge
  in the menu bar panel and on the Accessories page, with an optional notification when one runs
  low (Settings → Notifications). No Bluetooth permission is needed.
- **Window styles:** Settings → General → Window Style lets the desktop show through the main
  and compact windows: Frosted like the widget gallery, Translucent as one sheet of glass, or
  Clear, colourless glass like the Clear icons on iPhone. Standard stays the default, and Reduce
  Transparency or Increase Contrast always give Standard.
- **Menu bar icons like macOS 27:** every drawn icon style now has the size, corners and bolt of
  the system's battery icon, and Percentage Inside keeps the digits in one colour inside the
  battery, the way macOS draws it.
- **Export history:** History's new Export menu saves the minute readings or the daily battery
  health as CSV, in your region's spreadsheet format, or all of it as JSON. The files hold
  everything BatteryPulse keeps, with units in the column names; `bpulse --export` writes the
  same from the command line.
- **Fixes:** after an update the widget no longer stays frozen on the old version's last reading,
  its "Full at" or "Lasts until" time disappears once it has passed, and Check Now asks GitHub
  afresh instead of trusting an answer cached a minute earlier.
- **Command line:** `bpulse --accessories` lists accessory batteries, and `bpulse --record` keeps
  a capture around every charging change, for bug reports.

Updating from 0.5.0: **Install and Relaunch** in the update window installs 0.6 from inside the
app. If a widget on the desktop looked frozen after the update to 0.5.0, 0.6 brings it back by
itself at its first launch.

## What's new in 0.5

- **Motion that means something:** the charge rolls to its new value, the battery and the rings
  fill smoothly, the bolt draws in when charging starts, the adapter slides into the power flow
  when you plug in, and the battery bounces once when it's full. Watts, volts and temperatures
  still change instantly, so nothing jitters every two seconds.
- **Liquid Glass controls:** the History period switch sits in the toolbar with the system's
  sliding glass selection, Raw Data gets a source menu there, the Demo Mode bar floats in glass,
  and the menu bar icon style picker has a glass selection that flows from style to style.
- **Easy on the battery:** windows that are minimized, covered or on another Space stop reading
  the battery and stop animating, Demo Mode no longer wakes the app five times a second while
  paused, and the menu bar item never animates.
- **Reduce Motion** keeps everything in place and only fades, and Low Power Mode skips the
  decorative extras.
- **Glass Cards** (experimental, Settings → Advanced with the Developer section on) draws the
  cards in Liquid Glass, if you want to compare.
- **iPhone and iPad (command-line preview):** `bpulse --device` now shows Maximum capacity as
  iOS Settings does (checked on an iPhone 17 Pro Max with iOS 27: 95 %, 278 cycles), the date of
  first use and the battery sensor's temperature.

Updating from 0.4.0: **Install and Relaunch** in the update window installs 0.5 from inside the
app, without Open Anyway. From 0.3.x, install from the DMG once as before.

## What's new in 0.4

- **Menu bar:** show any mix of the battery icon, charge, battery power and temperature. New
  icon styles are drawn to the exact level — Modern (like macOS 27, the default), Classic,
  Percentage Inside (like macOS 26) and Ring, or the SF Symbol as before — with charging,
  plugged-in, low and Low Power Mode states, so BatteryPulse can stand in for the system
  battery item (Settings → Menu Bar explains how to turn that one off). The popover shows the
  temperature too.
- **Install and Relaunch:** from 0.4.0 on, updates install from inside BatteryPulse: it
  downloads the next version, checks its signature, replaces itself and opens again, without
  Open Anyway. Each release now also has `BatteryPulse.dmg.sig`, which you can ignore.
- **Update checks** daily, weekly, monthly or never (Settings → General).
- **Charging at once:** charging, battery power, voltage and current are read live from the
  battery, so BatteryPulse shows *Charging* a few seconds after you plug in instead of *Not
  charging* for half a minute, and the right direction right after you unplug.
- **About BatteryPulse** in the BatteryPulse menu, the popover and Settings → Advanced.
- **Raw Data** explains the keys of the battery pack, its banks and cells and the charger
  entries that macOS 27 shows below `AppleSmartBattery`; keys whose meaning isn't known still
  show no explanation rather than a guess.
- **iPhone and iPad (preview, command line):** from a clone of the repository,
  `swift run bpulse --devices` and `swift run bpulse --device 1` read the battery of a device
  connected by cable or Wi-Fi that trusts the Mac (see the README). The app shows devices in a
  later version.
- **Fixes:** Raw Data no longer stutters when you show the inspector or filter, release notes
  in the update window no longer break mid-sentence, and Raw Data no longer claims the charge
  voltage stays below `VacVoltageLimit`.

Upgrading from 0.3: install this version from the DMG as before (Open Anyway once); the next
ones install from the app. Your menu bar settings carry over and a hidden icon stays hidden;
the icon style becomes Modern (choose Symbol for the old look), and the large icon size is
gone. Placed widgets may need adding again after replacing the app from the DMG.

## What's new in 0.3.1

Fixes from the first run on a MacBook Air M5:

- **Power page:** while charging, the requested charge voltage is labeled as per cell (a
  MacBook Air M5 asks for 4.47 V per cell), not mistaken for the whole battery's.
- **Compact window:** long labels such as "Battery power" in Russian are no longer cut off.
- **Raw Data:** the SMC's floating-point cell voltages (`SBA1`…) show as voltages instead of
  raw bytes, `B0AT` is decoded as a temperature, and temperature sensors no longer show values
  like 33.69999694824219.
- **Temperature** also comes from the SMC on Macs whose battery doesn't report it elsewhere.

## What's new in 0.3

- **Temperature and cells**: the battery's temperature on the Power page, in the compact window,
  the widget and History, and the voltage of each cell on the Health page.
- **History**: charge, power and temperature over the last 24 hours or 7 days, with the average
  drain, time on battery, energy from the battery and charging sessions; capacity and cycle
  count day by day.
- **Notifications** when the battery reaches a charge level, runs low, needs service, or the
  Mac gets hot (Settings → Notifications; all off until you turn them on).
- **Widget** for the desktop and Notification Center, in two sizes. If it doesn't show up in
  Edit Widgets, please open an issue.
- **Compact window**: a small window with just the essentials.
- **Raw Data inspector** and sections for the battery pack, each cell, the charger and the SMC.
- **Update check** once a day (Settings → General), and a What's New window after updating.

## Install

Requires a Mac with Apple silicon and macOS 27 or later.

1. Download **BatteryPulse.dmg** below and open it.
2. Drag **BatteryPulse** onto **Applications**.
3. Open BatteryPulse from Applications.

### First launch

BatteryPulse is not notarized by Apple yet, so macOS blocks it the first time you open it:

1. When macOS says it can't verify BatteryPulse, click **Done** (not *Move to Trash*).
2. Open **System Settings → Privacy & Security** and scroll down to **Security**.
3. Next to *"BatteryPulse" was blocked to protect your Mac*, click **Open Anyway** and confirm
   with your password or Touch ID.

Until BatteryPulse is notarized, you need to do this once for each new version you download;
after that it opens normally.

See the [User Guide](https://github.com/NikitaUsov/BatteryPulse/blob/main/docs/USER_GUIDE.md)
for everything else.
