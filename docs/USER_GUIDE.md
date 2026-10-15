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
- [iPhone and iPad](#iphone-and-ipad)
- [Accessories](#accessories)
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

### The menu bar item

Settings → Menu Bar has four switches — **Battery icon**, **Percentage**, **Battery power** and
**Temperature** — in any combination. The menu bar shows them in that order, for example the
battery icon followed by 70% · −7.5 W · 34 °C. One of them always stays on, so the last one
can't be turned off. When the chosen text has nothing to show yet (no reading, or a Mac that reports no
temperature), the icon shows instead. Battery power refreshes every few seconds while it's
shown; the charge and temperature change when macOS reports new values.

**Icon Style** draws the battery to the exact level:

- **Modern** (the default) looks like the battery item of macOS 27: a rounded battery without
  an outline whose empty part is translucent.
- **Classic** has an outline, **Percentage Inside** shows the charge inside the battery as
  macOS 27 does with the percentage turned on, and **Ring** is a small round gauge.
- **Symbol** is the SF Symbol BatteryPulse used before 0.4, in five steps.

The drawn styles show a bolt while charging, a plug while on power but not charging (full, on
hold, or just plugged in), a red fill at 20 % and below unless it's charging, and a yellow fill in Low
Power Mode; otherwise they follow the menu bar's light or dark color.

BatteryPulse can't hide the battery item macOS shows. To use BatteryPulse in its place, click
**Open Menu Bar Settings…** in Settings → Menu Bar and turn off **Battery** there.

The popover that opens from the item shows charge, state, time remaining, maximum capacity,
cycles, temperature, the adapter and the system load, and below them the batteries of connected
accessories (see [Accessories](#accessories)).

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
- **Devices** — your iPhones and iPads, one page each (see [iPhone and iPad](#iphone-and-ipad)),
  and **Accessories**, the batteries of your Bluetooth accessories (see
  [Accessories](#accessories)).
- **Developer** — a sidebar section, off by default (Settings → Advanced), with two pages:
  - **Raw Data** — every raw value macOS reports, in a table with a readable decoding (mAh,
    volts, watts, temperatures, times, dates, bit fields, USB Power Delivery offers and the
    active contract) and a short description of what the key means where that's known. Besides
    `AppleSmartBattery` there are sections for the entries below it (the battery pack, each
    cell, the charger), the power source, the adapter, and the battery keys read from the SMC.
    Filter by key, value or description, or pick one source from the menu in the toolbar;
    select rows and press ⌘C (or right-click) to copy them. Double-click a row, or click the inspector button in the toolbar, to see its full
    value, decoding and description. **Copy JSON** and **Export Capture…** are in the toolbar.
  - **Demo Mode** — simulated battery states; see [Demo Mode](#demo-mode).

**Copy Report** in the toolbar copies a plain-text report without serial numbers; on a device
page, the report of the device's last read, without its name or identifier. It is unavailable on
the Accessories page; `bpulse --accessories --raw` saves what accessories report (see
[Accessories from the command line](#accessories-from-the-command-line)).

Live values refresh every 2 seconds while a window or the menu bar popover is open and can be
seen (not on the History, Devices and Demo Mode pages, and not while the window is minimized, covered
or on another Space), and every 10 seconds when the menu bar shows power. Otherwise BatteryPulse updates when macOS reports a
change, plus one reading a minute for the history while recording is on (the default; turn it
off in Settings → Advanced), so it uses almost no CPU in the background.

### Motion and Liquid Glass

Numbers roll to their new value, the battery and the rings fill, and the bolt draws in when
charging starts; changes that come every two seconds (watts, volts, temperatures) stay instant.
With **Reduce Motion** on (System Settings → Accessibility → Display), nothing moves: changes
fade in place, and in Low Power Mode the decorative touches are skipped. Windows you can't see don't
animate. The History switch and the Demo Mode bar use Liquid Glass; the cards stay plain.

### Window style

**Window Style** in Settings → General chooses how the main window and the compact window look,
from the most opaque to the most transparent. Each tile in the picker shows a little window in
that style:

| Style | What it looks like |
|-------|--------------------|
| **Standard** | An opaque window with cards, as in earlier versions. The default. |
| **Frosted** | The desktop shows through the window, blurred and frosted, like the widget gallery of macOS. The cards become faint, lighter layers; the Raw Data table stays opaque. The frost stays when the window is in the background. |
| **Translucent** | One sheet of clear Liquid Glass behind the whole window, with a dimming layer (dark in Dark Mode, a white wash in Light Mode). The colours stay; there are no cards: thin lines, bold numbers and headings separate the groups. |
| **Clear** | Pure glass, like the Clear icon and widget style of macOS: the desktop shows through almost sharp, and all content turns white, colours included. A low battery or a battery that needs service shows a white badge with its words instead of orange or red. The window is always dark, while the glass is a little lighter or smokier with the system appearance. |

The change applies at once to both windows. Settings, the menu bar popover, the welcome window
and the widget always look as macOS draws them, so Settings stays readable whatever you choose.
The see-through styles redraw when something behind the window changes, so Translucent and
Clear use more energy than Standard; Clear is also the hardest to read over a bright or busy
wallpaper, and Translucent is the better choice there.

With **Reduce transparency** or **Increase contrast** on (System Settings → Accessibility →
Display), both windows use Standard whatever the choice, and Settings says so under the picker.
You can still pick a style for when those settings are off.

0.5's Developer option **Glass Cards** is gone; Window Style replaces it, and a stored Glass
Cards choice is cleared rather than turned into a style.

## Compact window

For a quick look without the sidebar, BatteryPulse has a small window of a fixed size: the
charge, what the battery is doing, time remaining, capacity bars, maximum capacity, cycle
count, battery power, temperature and the adapter. Open it with **Compact Window** in the main
window's toolbar, and go back with **Full Window** in its own toolbar. To
make it the window BatteryPulse opens, choose **Window to open: Compact window** in
Settings → General.

## History

BatteryPulse records the battery about once a minute while it runs (in the menu bar, the Dock,
or at login), and right away when you plug in, unplug or the charge state changes. The
**History** page shows:

- **Charge** over the last 24 hours or 7 days (switch in the toolbar). Shaded stretches are times on the power adapter,
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

Once an iPhone or iPad has been read, a menu at the left of the toolbar switches between
**This Mac** and each device; see [Device history](#device-history).

Minute-by-minute history is kept for the last 10 or so days with records, one file per day, and
the daily summary for good, in `~/Library/Application Support/io.github.nikitausov.BatteryPulse/History`
on your Mac only.
Turn recording off or clear it in Settings → Advanced. Nothing is recorded during Demo Mode.

### Exporting history

**Export** in History's toolbar (the square with an arrow) saves the history as a file:

- **Readings by Minute…**: the minute readings as CSV, one row per reading.
- **Battery Health by Day…**: the daily battery health as CSV, one row per day.
- **All History…**: both in one JSON file, for scripts.

A file holds the history History shows, this Mac's or the iPhone's or iPad's picked in its source
menu, and everything BatteryPulse keeps of it (about the last 10 days of readings and every
day's health), whatever period the charts show. Export works on what was already recorded when
recording is off, and in Demo Mode too, since History keeps showing the recorded data. The
file name tells what's in it and the day of the export, such as
`BatteryPulse-Mac-samples-2026-10-15.csv`; no file or file name contains your Mac's name or
serial number.

**CSV for spreadsheets.** The file follows your region's number format (System Settings →
General → Language & Region) at the moment of export, so spreadsheet apps such as Numbers
open it correctly with a double-click. Where decimals are written with a comma, fields are
separated by semicolons (`83,5;charging`); elsewhere by commas, with a decimal point
(`83.5,charging`). If a spreadsheet app still puts everything into one column, import the file
with its text import and choose the separator. Column names are in English in every language,
an empty field means the value wasn't available, and `1` and `0` stand for yes and no.
[`bpulse --export`](#history-export) writes either form on request.

Readings by Minute:

| Column | Meaning |
|---|---|
| `time` | The moment of the reading, ISO 8601 with its offset from UTC: `2026-10-14T13:25:00+03:00` |
| `localTime` | The same moment as a local date and time that spreadsheets read as a date: `2026-10-14 13:25:00` |
| `event` | `launch` on the first reading after BatteryPulse started, `wake` on the first after the Mac woke; empty otherwise |
| `chargePercent` | Charge, % |
| `chargeState` | `charging`, `discharging`, `charged` (full on the adapter), `notCharging` (held below full on the adapter) or `unknown` |
| `isExternalPowerConnected` | `1` on the power adapter, `0` on battery |
| `batteryWatts` | Power into the battery, W; negative while the battery discharges |
| `systemLoadWatts` | What the whole Mac uses, W |
| `temperatureCelsius` | Battery temperature, °C |
| `remainingMAh` | Remaining capacity, mAh |
| `fullChargeMAh` | Full-charge capacity, mAh |

Battery Health by Day:

| Column | Meaning |
|---|---|
| `day` | The day, `2026-10-14`, in the time zone the Mac had when it was recorded |
| `healthPercent` | Maximum capacity, %, capped at 100 like System Settings |
| `capacityToDesignPercent` | Capacity compared with design, %, not capped: a new battery can hold more than its design |
| `nominalChargeCapacityMAh` | Nominal charge capacity, mAh |
| `fullChargeCapacityMAh` | Full-charge capacity, mAh |
| `cycleCount` | Charge cycles |

**Gaps.** Readings more than 10 minutes apart belong to different stretches: the Mac slept,
BatteryPulse wasn't running, or recording was paused (turned off, or during Demo Mode). After
sleep or a launch, the first reading names the reason in `event`. History's charts break the
line at the same places.

**Times** are written in the Mac's time zone at the moment of export, each with its own offset
from UTC, so `time` is exact across daylight-saving changes. BatteryPulse doesn't remember
where a reading was taken: after a trip, the readings appear in the current time zone. When
the clocks go back, `localTime` repeats an hour, and `time` tells those readings apart.

**JSON.** All History writes one object with `format` (`"BatteryPulse history"`),
`formatVersion` (1), `exportedAt`, `generator` (BatteryPulse and its version), `source` (what
the history belongs to: `kind` `"mac"` and the macOS version as `osVersion`), `units` (the unit
of every key that has one), then `samples` and `days`. Their keys are the CSV columns, without
`localTime`. Every key is always present: a missing value is `null`, yes and no are `true` and
`false`, and numbers always use a decimal point.

**Compatibility.** Columns and keys are only ever added at the end. If a column is renamed or
removed, or its meaning changes, `formatVersion` goes up and the release notes say so. Scripts
should find columns by name and ignore the ones they don't know.

## iPhone and iPad

BatteryPulse can show the battery of an iPhone or iPad connected to the Mac: the charge, maximum
capacity and cycle count as iOS Settings shows them, the capacities in mAh, temperature, voltage,
current and the charger, with a history next to the Mac's.

### Turning it on

Reading devices is off until you turn on **Read iPhone and iPad batteries** in Settings → General,
or click **Turn On** under **Devices** in the sidebar. It uses Apple's MobileDevice framework, the
part of macOS that Finder uses for iPhones and iPads. With the setting off, BatteryPulse doesn't
load it and doesn't watch for devices. With it on, the framework loads only once an iPhone or
iPad is plugged in or you open the Devices section. Turning the setting off stops all reading;
devices read before stay in the sidebar with their last values and history.

### Connecting a device

1. Connect the device by cable and unlock it. If it asks *Trust This Computer?*, tap **Trust**
   and enter the passcode; if it doesn't ask, select the device in Finder once. BatteryPulse
   never pairs with a device by itself.
2. Within a few seconds the device appears under **Devices** and is read. If it was locked or
   didn't trust the Mac yet, BatteryPulse tries again after 20 seconds and after a minute;
   **Try Again** on its page reads it at once.

By cable, a device is read when it's plugged in, then every 5 minutes while battery history is
recorded, and every minute while its page is on screen. Over Wi-Fi (turn on *Show this iPhone
when on Wi-Fi* for the device in Finder, by cable, once), a device is never read by itself:
**Check Again** on the Devices page reads every device it finds, Wi-Fi included, and **Refresh**
on a device's page reads that device. A device read before shows up as *Connected over Wi-Fi*
when you open the Devices section. It must be unlocked and on the same network as the Mac.

If a device doesn't answer in time, BatteryPulse stops reading devices by itself until you click
**Try Again**, so a device that stopped answering can't keep it busy.

### The device page

- The charge and what the battery is doing, the model, the iOS or iPadOS version, how the device
  is connected and when it was read.
- Gauges for the charge (with the mAh behind it), **maximum capacity** (the figure in iOS
  Settings → Battery → Battery Health) and the **cycle count** against the cycles Apple rates the
  battery for: 1,000 for iPhone 15 and later and for iPads, 500 for earlier iPhones, or the
  battery's own rating when it reports one.
- Capacity bars, and the details: nominal and full-charge capacity with their share of the
  design, design capacity, temperature, voltage, current, battery power, the charger and the
  month of first use.
- **Refresh** in the toolbar reads the device again; **More** has **Show in History** and
  **Forget This Device…**.
- **Copy Report** copies the report of the device's last read since BatteryPulse started,
  without its name or identifier.

When a device is unplugged, it stays in the sidebar, dimmed, with its last values and when it
was last seen. **Forget This Device…** removes it and its history; a device that is still
connected comes back only after you unplug it and connect it again.

### Device history

While battery history is recorded (Settings → Advanced), a device on a cable is recorded every 5
minutes, and its capacity and cycles once a day. Choose it from the menu at the left of the
History toolbar. Its charts end at its last record, so its last charging session stays in view;
the period figures (drain, time on battery) are shown for the Mac only. **Clear History…**
clears the devices' history too; the devices stay.

### Privacy

Everything stays on your Mac, in
`~/Library/Application Support/io.github.nikitausov.BatteryPulse/Devices`. BatteryPulse keeps
each device's name (as its label), model, OS version, last values and history under a key made
from its identifier and a secret of this Mac; the identifier itself, serial numbers and raw
device data are never written. Demo Mode shows a simulated iPhone in place of your devices.

## Accessories

**Accessories**, the last row of the sidebar's Devices section, shows the batteries of the
accessories connected to this Mac: Bluetooth keyboards, mice, trackpads, headphones and game
controllers, a card each with its name, its kind, how it's connected and the charge of each
part. Earbuds such as AirPods show each bud and the case when macOS reports them separately, and
one charge when it reports them together. The menu bar popover lists the same accessories below
the Mac's battery, with a bolt next to a part that charges.

BatteryPulse shows what macOS itself reports for accessories (the list `pmset -g accps` prints),
so it needs no Bluetooth permission and asks for nothing. An accessory appears while it's
connected to this Mac; one connected to another device, or one that reports no battery to macOS,
doesn't. A part that is out of reach shows its last known charge, dimmed; a keyboard on its
cable or a bud in its case shows **Connected to power** when it isn't charging. The charge
changes when macOS reports a change, and BatteryPulse reads it again each time you open the
page or the popover; it never polls. The page also works on a Mac without a battery. If this
version of macOS doesn't report accessory batteries to apps, the page says **Accessories
Unavailable** and the popover shows none.

Accessories have no history and aren't exported: they report only their charge. Their names are
shown as macOS reports them; Demo Mode replaces them with simulated accessories. Nothing about
them is stored, except which accessories have already sent a low-battery notification while that
notification is on.

## Notifications

In Settings → Notifications, BatteryPulse can tell you:

- **When charged to** 80, 85, 90, 95 or 100 %. Unplugging around 80 % most of the time slows
  battery aging.
- **When the battery falls to** 10, 20 or 30 % on battery.
- **When battery service is recommended**, once each time macOS reports a condition other than
  Normal.
- **When the Mac gets hot**, once each time the thermal state turns high or critical, at most
  once an hour.
- **When an accessory falls to** 10, 20 or 30 %, once per discharge for each
  [accessory](#accessories). For earbuds, the lowest bud in use counts, even while the other
  charges in the case; the case itself and parts out of reach never notify. Off by default.

Each notification comes once and only again after the battery has clearly moved away (5 points
below the charge limit, or unplugged; 5 points above the low-battery level, or plugged in; for an
accessory, 5 points above or charging). A low-battery notification disappears from Notification
Center when you plug in (an accessory's when it charges), and a charge-level one when you unplug.
An accessory that disconnects and comes back at the same level doesn't notify again. macOS asks
for permission the first time you turn one on; **Send Test Notification** shows what they look
like. BatteryPulse has to be running to notify you.

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

Replacing BatteryPulse with a new version from the DMG removes the widgets you placed; add them
again from the gallery as above.

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
**Demo** badge with **Stop Demo**. The Devices section shows a simulated iPhone in place of
your devices, the Accessories page and the popover show a simulated keyboard, mouse and AirPods
in place of yours (so screenshots never show your accessories' names), and History shows the Mac
only. Copy Report, Copy JSON and Export Capture are unavailable during the demo, so a bug report
always contains real data. The demo stops when you quit or turn the Developer section off.

## Settings

Open Settings with ⌘, or the gear button in the menu bar popover.

| Tab | What it controls |
|-----|------------------|
| General | Menu bar item, Dock icon, open at login, the welcome window, the window style, update checks, language, reading iPhones and iPads |
| Menu Bar | What the item shows (battery icon, percentage, battery power, temperature), the icon style, and the way to turn off the battery item of macOS |
| Notifications | Charge limit, low battery, battery service, heat and accessory low-battery notifications |
| Advanced | Recording and clearing history (the Mac's and the devices'), the Developer section (Raw Data and Demo Mode), a link to this guide |

### Updates

BatteryPulse checks GitHub for a new version daily, weekly, monthly or never, as you choose in
Settings → General (daily at first), and **BatteryPulse → Check for Updates…** checks right
away with any choice. When a new version is out, the first
check after BatteryPulse starts opens a window with its release notes and **Download**, **Remind
Me Later** and **Skip This Version**; later checks don't interrupt you and show **Update
available** in the menu bar popover instead, which opens the same window.

**Install and Relaunch** (from 0.4.0) downloads the update, checks that it is signed by
BatteryPulse and is the version on offer, replaces the copy in your Applications folder and
opens the new version, without Open Anyway. Install and Relaunch isn't offered, and Download is,
when:

- BatteryPulse runs from where it was downloaded instead of from Applications (move it there
  first);
- your account can't change the folder BatteryPulse is in;
- the release has no signature.

If anything goes wrong, nothing is replaced and the window offers Download instead. Permissions
you gave BatteryPulse in Privacy & Security may be asked for again after an update, and widgets
may need adding again (see [Widget](#widget)).

**Download** opens the DMG in your browser: open it, drag BatteryPulse onto Applications to
replace the old copy, and approve the new version once in Privacy & Security (see
[First launch](#first-launch)). Updating from 0.3 works this way once; from 0.4.0 on, Install
and Relaunch takes over.

The check and the download of an update you chose to install are the only requests
BatteryPulse sends to the internet: GitHub sees your IP address, the app's version and your
language, as with any web request, and nothing else about your Mac is sent. The only other
connections are to your own iPhone or iPad while **Read iPhone and iPad batteries** is on, over
the local network for one connected over Wi-Fi (see
[Connecting a device](#connecting-a-device)); nothing from them goes to the internet. If GitHub
limits requests from your network, the check waits and tries again later. Each release also lists
`BatteryPulse.dmg.sig`, the signature the app checks; you don't need it.

After an update that adds features, a **What's New** window lists them once; it's also in the
Help menu.

**BatteryPulse → About BatteryPulse**, the ⓘ button in the menu bar popover and the Version row
in Settings → Advanced open the About window: the version and build, links to the project, this
guide and the release notes, Check for Updates and the license.

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
- **Battery power, voltage and current** are read live from the SMC. That's why BatteryPulse
  shows *Charging* a few seconds after you plug in, while macOS still says *Not charging* for
  about half a minute; the time to full appears once macOS has estimated it.
- **Temperature** is the battery pack's own sensor, and **cell voltages** come from each cell
  of the pack. macOS 27 keeps both on registry entries below the battery rather than on the
  battery itself; when a Mac doesn't have them, BatteryPulse reads them from the SMC instead
  and checks that the cell voltages add up to the battery voltage. The temperature sensors near
  the battery that the SMC also reports are shown in Raw Data only, since they can read several
  degrees off.
- **Spread** is the difference between the highest and lowest cell voltage. A few millivolts is
  normal; a spread that keeps growing over months hints at an ageing or unbalanced battery.
- **Requested charge current and voltage** are what the battery asks the charger for, shown
  while charging. The current drops as the battery fills up. Some Macs, such as a MacBook Air M5
  on macOS 27, ask for the voltage of one cell (4.47 V), and the label then says "per cell"; a
  higher value is for the whole battery.

## Command-line report

The repository also has `bpulse`, a command-line report (`swift run bpulse`). See the
[README](../README.md#command-line-report).

### Recording charging changes

`bpulse --record <folder>` watches the battery until you press Control-C and keeps the moments
a charging problem is about. It saves a capture (the `--raw` format, serial numbers removed) at
the start, just before and just after every change of the charging state (plugging in or
unplugging, charging starting or stopping, the charge held at a limit), and one every 15
minutes. `timeline.tsv` in the same folder gets a line for every reading, every 5 s: the
charge, the state, the capacity in mAh, current, voltage, the current the charger asks for, the
power from the adapter, the temperature, when the battery last updated its readings, and what
changed. A detail that keeps flipping on its own stops causing captures after three, but the
timeline still lists it.

```sh
caffeinate -i swift run bpulse --record ~/bp-capture
```

`caffeinate -i` keeps the Mac awake while it records. The folder is created if needed and must
not hold an earlier recording. A recording keeps at most 100 captures (about 4.5 MB) and stops
by itself after 50,000 readings (about 69 hours). `bpulse --input <capture>` shows the report of
any capture in the folder; attach the ones around the moment in question, with `timeline.tsv`,
to the bug report.

### History export

`bpulse --export csv` prints the minute readings BatteryPulse recorded on this Mac, everything
it keeps (about the last 10 days); `--export csv --days` prints the daily battery health, and
`--export json` both, in the formats [Exporting history](#exporting-history) describes.
`bpulse` always writes CSV with commas and decimal points, the same in every region;
`--decimal-comma` switches to semicolons and decimal commas, which spreadsheets expect where
decimals are written with a comma. Times are in the current time zone (set `TZ` to change it).

```sh
swift run bpulse --export csv > samples.csv
swift run bpulse --export csv --days --decimal-comma > days.csv
swift run bpulse --export json > history.json
```

`--history <folder>` exports another history folder, such as one copied from another Mac; the
JSON's `source` is then `null`, since `bpulse` can't tell whose history it is. `bpulse` reads
the files the app writes, so it works while the app runs. The app saves a day's summary at most
once an hour, so the latest daily row can be up to an hour behind; minute readings are saved
right away. When there is no history folder (BatteryPulse hasn't recorded on this Mac, or the
folder given doesn't exist), `bpulse` says so and exits with status 2.

### iPhone and iPad from the command line

`bpulse` reads the same devices as the app (see [iPhone and iPad](#iphone-and-ipad)), without
the setting, and saves what a device returned for a bug report.

1. Connect the device by cable and unlock it. If it asks *Trust This Computer?*, tap **Trust**
   and enter the passcode; if it doesn't ask, select the device in Finder once. BatteryPulse
   never pairs with a device by itself.
2. Run `bpulse --devices` to list the devices, then `bpulse --device 1` for the first one:
   charge, state, design, nominal and full-charge capacity with their share of the design,
   cycles, temperature, voltage, current and the adapter. `--json` prints the same as JSON.
   Devices are numbered by their identifier, so the numbers stay the same between runs, and
   the report's Device line ends with the same short ID (`ID …801C`) as the list. If a device
   doesn't answer within 10 s, the list doesn't wait for it: that device and the ones not read
   yet (cable first) are listed as *Unknown device*. `--device` still reads any of them, since it
   connects only to the device you chose.
3. Over Wi-Fi: turn on *Show this iPhone when on Wi-Fi* for the device in Finder (by cable,
   once). The device must be unlocked and on the same network as the Mac.

Maximum capacity is the figure iOS Settings → Battery → Battery Health shows (nominal capacity
÷ design capacity, which the device also reports itself); both capacities follow as a share of
the design. On an iPhone 17 Pro Max with iOS 27 the report matched Settings: 95 %, 278 cycles,
first used October 2025.
`bpulse --device 1 --raw > device.xml` saves everything the device returned for a bug report,
with serial numbers, identifiers and the device's name removed (`--devices` itself shows the
name). When no device is found or it can't be read, `bpulse` says why (not trusted, locked, no
answer) and exits with status 2.

### Accessories from the command line

`bpulse --accessories` lists the batteries macOS reports for connected accessories, one line
each, the same as the [Accessories](#accessories) page:

```
Magic Keyboard (keyboard, Bluetooth): 76 %
AirPods Pro (headphones, Bluetooth): left 64 %, right 61 %, case 90 % charging
```

`--json` prints the list as JSON. `bpulse --accessories --raw > accessories.xml` saves what macOS
reported, for a bug report: names become *Accessory 1*, *Accessory 2* and identifiers
*group-1*, *accessory-1*, consistently, so the parts of an accessory still belong together;
serial numbers and addresses are removed. `bpulse --input accessories.xml` shows a saved capture
again, on any computer. When no accessory reports a battery, the list says so and `bpulse` exits
with status 2 (`--raw` still saves the empty capture); on a macOS that doesn't report accessory
batteries to apps it says that, also with status 2.

## Reporting a problem

Open an [issue](https://github.com/NikitaUsov/BatteryPulse/issues/new/choose) and attach a
capture: turn on the Developer section, then **Raw Data → Export Capture…** (or run
`swift run bpulse --raw > capture.xml`). Serial numbers are removed from captures and reports.
For a problem with accessories, attach `swift run bpulse --accessories --raw > accessories.xml`
instead: their names and identifiers are replaced (see
[Accessories from the command line](#accessories-from-the-command-line)).
