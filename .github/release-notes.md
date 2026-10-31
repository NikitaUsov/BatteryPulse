## What's new in 0.7.0

- **Widgets you configure:** your Battery widget keeps its look. Control-click it and choose
  **Edit Widget** to pick what it shows: the charge, maximum capacity, temperature or battery
  power as its main value; the number with its symbol, a ring or a drawn battery; the time as a
  clock time or the time left; level colours or monochrome; and, with the Custom layout, the
  details you want. It now comes in large too, with eight details.
- **What changed in the look you keep:** a time on the next day says "tomorrow"; a value that
  needs attention has a symbol before it; a reading over 45 minutes old shows when it was taken
  ("Updated 14:05"); a battery condition other than Normal, or high heat, takes the last row (in
  the small widget, the time line's place); medium's values line up at the right edge; a label
  too long for its place uses a shorter word, such as "Max capacity"; and a Mac without a battery
  points you to the Accessories widget.
- **Accessories widget:** your keyboard's, mouse's, trackpad's and headphones' batteries on the
  desktop or in Notification Center, in small, medium and large. Edit Widget can show only the
  lowest one, or hide the fully charged ones.
- **Clicking a widget** opens the matching page in the main window: Overview for the charge,
  Health for maximum capacity, Power for temperature and battery power, and Accessories for the
  Accessories widget.
- **Charged to limit:** when the Charge Limit in System Settings → Battery stops charging,
  BatteryPulse now says "Charged to limit" in the app, its menu bar panel and the Battery widget,
  and Power shows "Charge limit: Reached". It can't read the limit's percentage yet.
- **Percentages** in the app, the menu bar and the widgets have no space before the % sign in
  either language, so Russian shows "80%" too. The text Copy Report and `bpulse` write is
  unchanged.
- **Anonymous version count.** Once per version, at least a day after you start using it, an
  automatic update check also downloads a small file, `BatteryPulse-count.txt`, from that
  version's release; its public download count shows how many Macs use each version. Nothing
  else is sent: no identifier, nothing about your Mac, its battery or your settings; GitHub sees
  your IP address, as it does for the update check. It is on by default, never runs when Check
  for updates is Never, and turns off in Settings → General.
- **Fixes:** switching from Raw Data to another page no longer leaves Raw Data's table under the
  new page for a few seconds, and in Russian a few labels in the menu bar panel and Settings are
  shorter, so they keep to one line.
- **For scripts:** `bpulse --device <n> --json` writes dates as ISO 8601 strings, like `bpulse
  --json`; every JSON object `bpulse` prints now has a `formatVersion` field. `--accessories
  --json` is unchanged.

Updating from 0.6.2: **Install and Relaunch** in the update window installs 0.7.0 from inside
the app.

## What's new in 0.6.2

- **Window styles:** a Clear window, and a Translucent one in the dark appearance, no longer
  turn black while they shrink into the Dock and come back: they show an even graphite grey on
  the way. Translucent and Clear stay in beta (Settings → Advanced → Beta window styles).
- **Check Now** no longer fails while an automatic update check is running: it takes over and
  checks right away, on any network.
- **iPhone and iPad:** a device's page names the connection its values came over, *Connected by
  cable* or *Connected over Wi-Fi*, also after you unplug the cable and the device is read over
  Wi-Fi.
- **Lighter in the background:** with the battery icon and charge in the menu bar, BatteryPulse
  now uses about 40 % less processor time than 0.6.1, and about 20 % less with battery power
  shown too (measured on a MacBook Air M5).

Updating from 0.6.1: **Install and Relaunch** in the update window installs 0.6.2 from inside
the app.

## What's new in 0.6.1

- **Smaller and lighter:** the download shrinks from 3.7 MB to 1.4 MB (−61 %), and the
  installed app takes 4.7 MB instead of about 11 MB. Each battery update macOS announces, such
  as plugging in or unplugging, is now read once instead of twice, and the battery values that
  only Raw Data shows are read at most once a minute. History builds its charts in the
  background, so switching periods no longer holds up the window.
- **Beta window styles:** Translucent and Clear are now in beta. Turn on **Beta window styles**
  in Settings → Advanced to choose them in Settings → General, where they are marked Beta. If
  your windows use one of them, 0.6.1 turns the setting on for you, so nothing changes. Clear
  dims the desktop more, so its white text stays readable even over a bright window behind it,
  and minimizing a Translucent window no longer turns it black on its way to the Dock. Known
  issue: a Clear window still turns black while it minimizes and comes back.
- **Tile pickers:** Window Style and Icon Style in Settings mark your choice with an accent
  outline. The flowing glass selection that 0.5 brought is gone, so the tiles show each style
  as it is.
- **Widget:** it refreshes once the estimate arrives after you plug in or unplug, and again when
  the charge or the estimate moves, so its "Full at" or "Lasts until" time keeps up with the
  app's.
- **Accessories:** earbuds are named after the buds, not their case.
- **Safer updates:** an update that has no signature or fails a check that shows it is genuine
  is no longer offered as a download. BatteryPulse says what failed and offers **Open Release
  Page** instead. Automatic update checks skip Low Data Mode and expensive networks, such as a
  Personal Hotspot, and try again later; Check for Updates… still checks on any network.
- **Saving energy:** in Low Power Mode, when macOS asks apps to save resources, or when the Mac
  runs hot, live values refresh less often: every 5 seconds in windows and every 30 seconds in
  the menu bar. While the displays sleep, the menu bar stops refreshing power and catches up
  when you're back.
- **Fixes:** the power value in the menu bar no longer stops updating when the icon is turned off
  or Demo Mode ends; a Mac that reports 0 rated cycles no longer breaks the cycle gauge; Export
  Capture tells you when it can't save the file; Raw Data's source menu shows the chosen source
  in full; the "notifications are off" note updates when you come back from System Settings;
  and Copy Report's tooltip is right on pages without a report.

Updating from 0.6.0: **Install and Relaunch** in the update window installs 0.6.1 from inside
the app.

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
