# BatteryPulse roadmap

A lightweight native Swift/SwiftUI app for macOS and iOS that shows detailed battery and
charging state.

## Decisions

- **Platforms:** macOS 27 and iOS 27 minimum. On the Mac this means Apple Silicon only, since
  macOS 27 no longer runs on Intel Macs. No Intel code paths.
- **Distribution (macOS):** a DMG outside the App Store. The app is not sandboxed, so SMC reads
  (and later charge limiting) are possible. A notarized DMG needs a paid Apple Developer
  account; without one, users have to approve the app in Privacy & Security.
- **Distribution (iOS):** undecided. Personal installs from Xcode work with a free Apple ID
  (re-signed every 7 days); TestFlight and the App Store need the paid account.
- **Reference hardware:** MacBook Air M5 running macOS 27.
- **App shape:** a regular app with a main window (sidebar: Overview, Power, History, Health,
  optional Developer), a compact window and a widget, plus an optional menu bar item. Users choose menu bar and Dock presence; the app is
  never hidden from both. Liquid Glass stays in the control layer, per Apple's HIG: the
  system's sidebar, toolbar and controls, plus custom glass only on controls that float over
  content (the Demo Mode bar, the selection of the menu bar icon style picker). Content uses
  standard fills; glass cards are a Developer option, off by default. Motion is short, plays
  once on a battery event or a user action, turns into fades under Reduce Motion, and stops in
  windows that can't be seen and in the menu bar label.
- **Languages:** English (source) and Russian, in a String Catalog. The language is chosen per
  app in System Settings, like any Mac app. Repository text stays English; the catalog is the only
  place with Russian.

## Principles

- **No third-party dependencies.** System frameworks only.
- **Event-driven.** Readings update on OS power notifications, plus one a minute for history
  while recording is on. Fast polling (every 2 s) runs
  only while a view shows live values such as current or power.
- **Platform-independent core.** `BatteryCore` has no Apple-only dependencies and is tested on
  Linux and macOS against real captures (`bpulse --raw`).
- **Swift 6 with strict concurrency.**
- **Resource targets (macOS):** about 0 % CPU when idle, under 30 MB RAM, binary under 5 MB.

## What the platforms expose

| Reading                                      | macOS 27 | iOS 27                |
|----------------------------------------------|:--------:|:---------------------:|
| Charge level, charging state                 | ✅       | ✅ `UIDevice`          |
| Optimized charging hold                      | ✅*      | —                     |
| Time to empty / full                         | ✅       | estimated by the app  |
| Capacity in mAh (remaining / full / design)  | ✅       | analytics import      |
| Health (Maximum Capacity), cycle count       | ✅       | analytics import      |
| Voltage, current, battery power              | ✅       | —                     |
| Adapter: watts, volts, amps, model           | ✅       | —                     |
| System input, system load, adapter loss      | ✅       | —                     |
| Cell voltages, battery temperature           | ✅†      | analytics import      |
| Low Power Mode, thermal state                | ✅       | ✅                    |

On a MacBook Air M5 with macOS 27, `AppleSmartBattery` keeps the mAh values in its
`BatteryData` dictionary and no longer publishes `Temperature` or `CellVoltage`.

† macOS 27 moved them to the entries below `AppleSmartBattery`: `AppleSmartBatteryPack`
(`BatteryData.Temperature` in 0.01 °C), one `AppleSmartBatteryBank` per series cell
(`CellVoltage`; on the M5 Air each bank has two parallel `AppleSmartBatteryCell` entries, 3S2P),
and `AppleChargerData` (the charge current target and a per-cell charge voltage, 4470 mV).
Confirmed by a capture from the M5 Air (`m5-macos27-on-battery-smc` fixture). The SMC
(read-only) is the second source: `BC1V`… or `SBA1`… (floats in volts) for the cells, checked
against the pack voltage, and `B0AT` for the temperature, in 0.1 K (3069 = 33.75 °C with the
pack at 33.69 °C). Its battery-area sensors `TB*T` stay in Raw Data: on the M5 Air `TB0T` and
`TB1T` read like the pack and `TB2T` 1.1 °C lower, and on other Macs they were further off.

\* Read from IOPS `Optimized Battery Charging Engaged`, which macOS only publishes while the
charge is on hold; not yet seen in a macOS 27 capture.

On iOS the public API only provides level and state. The rest can come from the analytics file
iOS lets users export (Settings → Privacy & Security → Analytics & Improvements → Analytics
Data), without private APIs. The format still has to be checked against a real file.

## Architecture

```
BatteryCore  (Linux + Apple)   models, parsing, metrics, text report, history, SMC wire format
     ▲
BatteryKit   (Apple)           IOKit (macOS) / UIDevice (iOS), BatteryMonitor (@Observable)
     ▲
bpulse (CLI, macOS)    App (SwiftUI: macOS menu bar + iOS)    Widgets
```

## Stages

### Stage 0: Foundation ✅

- [x] Swift package: `BatteryCore`, `BatteryKit`, `bpulse`
- [x] Parser for AppleSmartBattery, IOPowerSources and adapter details
- [x] Metrics: health, wear, power, cell spread, time estimates
- [x] `BatteryMonitor`: OS-event updates plus an on-demand live mode
- [x] `bpulse` CLI (`--json`, `--raw`, `--watch`, `--input`)
- [x] CI: Linux (core tests and lint) and macOS 27 (build, tests, iOS build of BatteryKit)
- [x] Verified on a real MacBook Air M5 (macOS 27); real captures are the test fixtures

### Stage 1: macOS MVP ✅ (released as 0.2.0)

- [x] SwiftUI app target built with SwiftPM (`swift run BatteryPulse`); starts without a Dock
  icon (`LSUIElement`) and shows one only when needed
- [x] `MenuBarExtra`: icon plus percentage and/or power (configurable)
- [x] Popover: charge, state, time, live power, health, cycles, adapter
- [x] Details window (later replaced by the main window), "Copy Report"
- [x] Settings: menu-bar content, launch at login (`SMAppService`)
- [x] App icon and first-launch welcome window with the starting settings
- [x] DMG packaging (`scripts/build-app.sh`, built by CI)
- [x] Main window with a sidebar (Overview, Power, Health, Developer), gauges, capacity bars and
      a power-flow diagram
- [x] Optional menu bar item and Dock icon, Dock menu, Help menu linking to the User Guide
- [x] English and Russian (String Catalog, per-app language in System Settings)
- [x] One-click GitHub release with first-launch instructions
- [x] Verify the new UI on the M5 and polish it from screenshots (English and Russian)
- [x] Developer section: raw values decoded (units, times, USB-PD offers) and explained
- [x] Demo Mode: simulated scenes and animations everywhere in the app, by hand or as a tour

### Stage 1.1: macOS polish and missing readings (0.3)

- [x] Battery temperature and cell voltages: from the registry entries below
  `AppleSmartBattery`, with the SMC (read-only, no root) as a second source for the cells. The
  temperature shows on Power, in the compact window, the widget and History, each cell's voltage
  on Health; `bpulse --smc` lists the SMC's battery keys
- [x] Raw Data inspector for the full description, value and decoding of a row
- [x] Check for updates against the latest GitHub release (no third-party updater) and show
  what's new
- [x] History and charts (see Stage 3)
- [x] Notifications: charge limit, low battery, battery service, heat (see Stage 4)
- [x] Compact mode: a small, fixed-size window with the essentials; switch from the toolbar, and
  choose which window Open BatteryPulse shows
- [x] WidgetKit widget (small and medium), built by SwiftPM and wrapped into an `.appex` by
  `build-app.sh`; sandboxed, reading IOKit itself since ad-hoc signing rules out an App Group.
  Appears in the gallery for a downloaded copy after Open Anyway (M5 Air, 0.3.0)
- [x] Verify on the M5 (0.3.0): the registry children and their keys, all SMC battery keys
  readable without privileges, the widget, notification permission for the ad-hoc app
- [x] 0.3.1: fixes from that run (per-cell charge voltage, SMC float cells in volts, `B0AT` in
  0.1 K as a temperature fallback, compact window labels) and the M5 capture as a fixture
- [x] Verify on the M5: the update check finds a new release (0.3.0 → 0.3.1)
- [ ] Verify on the M5: a capture at the macOS Charge Limit stop point
- [x] 0.4: glossary entries for the keys of the pack, banks, cells and charger entries of
  macOS 27; `RawKeyGlossaryTests` lists the ones still unexplained (about 20 on the M5)
- [ ] Glossary: re-check the keys left out as uncertain, and add captures from other Apple
  silicon Macs (M1–M4) as test fixtures
- [ ] Profile in Instruments against the resource targets
- [ ] Developer ID signing and notarization (needs a paid Apple Developer account), so the
  first launch needs no Open Anyway

### Stage 1.2: Updates and About (0.4)

- [x] Update check frequency in Settings → General: daily, weekly, monthly or never, in place of
  the on/off switch (off becomes never; a manual Check for Updates still works with never)
- [x] Release notes in the Software Update window: join the lines of a wrapped paragraph or
  list item, which now break mid-sentence (seen with 0.3.1's notes)
- [ ] Install updates from the app: download the DMG itself, verify it, replace the app and
  relaunch, instead of sending the user to the browser. Built in 0.4.0; the first real test is
  0.4.0 → 0.4.1 on the M5. Researched (October 2026, with an adversarial check):
  - A file a non-sandboxed app downloads with URLSession isn't quarantined (no
    `LSFileQuarantineEnabled` in our Info.plist), and neither is what it copies out of that
    DMG. Gatekeeper only asks for Open Anyway on quarantined apps: an unquarantined ad-hoc app
    opened without a prompt in tests on macOS 15 and 26. macOS 27 is untested; check on the M5
    and run `xattr -l` on the download.
  - App Management: an app without a Team ID replacing its own bundle by rename didn't prompt
    on macOS 26.2 in a public probe; undocumented, so on any error fall back to the browser.
  - Integrity: GitHub computes a SHA-256 `digest` for every release asset (0.3.1's matches the
    DMG); it catches a broken download but not a swapped one. An Ed25519 signature from CryptoKit,
    made in CI with a secret key and checked against a public key built into the app, proves the
    update is ours. Also check the bundle ID, the version and `codesign --verify --strict`.
  - Mechanics: mount with `hdiutil attach -nobrowse -readonly`, copy next to the app on the same
    volume, then a small detached step waits for the app to quit, swaps the two bundles
    atomically (`renamex_np` with `RENAME_SWAP`), deletes the old copy, registers the new one
    with Launch Services and relaunches it. Skip when the app runs translocated or outside a
    writable folder.
  - Ad-hoc identity changes with every build, so permissions tied to it (not notifications,
    which follow the bundle ID) would be asked for again; Developer ID fixes that for good.

  As built: Install and Relaunch downloads the DMG with URLSession into
  `~/Library/Caches/<bundle ID>/Updates` and checks GitHub's SHA-256 digest when the release has
  one and, always, an Ed25519 signature of the DMG (`BatteryPulse.dmg.sig`, made by
  `scripts/sign-update.swift` in the release workflow from the `UPDATE_SIGNING_KEY` secret of
  the `release` environment, which needs the maintainer's approval for each run,
  checked against the key in `ReleaseSigning.swift`). It mounts the DMG at a private mount
  point, copies the app into a temporary folder on the app's volume, clears quarantine, and
  checks the bundle ID, that the version is exactly the release's and newer than the running
  one (so a signed old build can't be installed over a newer one), and a strict code-signature
  validation. Then it swaps the bundles with `renamex_np(RENAME_SWAP)`, registers the new one
  with `LSRegisterURL` and relaunches through `/bin/sh`, which waits for the old process to end
  and runs `open -n`; the old copy is deleted at the next launch. Translocated copies, folders
  the user can't write, development builds, releases without a signature and any error fall
  back to Download in the browser. There is one built-in key and no rotation yet: a lost key
  means one manual DMG install with the new key's build. Follow-ups: re-register the login item
  and reload the widget timelines on the first launch after an update.
- [ ] Keep the widgets on the desktop across an update. (Replacing 0.3.1 with 0.4.0 from the DMG
  kept them on the M5; an in-app update is still to be checked.) Replacing 0.3.0 with 0.3.1 from the DMG
  removed them; the gallery still offered the widget, and it worked once added again. The
  in-place swap above keeps the path, registers the new copy and raises
  `CFBundleVersion`, then reloads the timelines; check with `pluginkit` on the M5 whether that
  keeps them or only a stable Developer ID signature does, and until then tell the user to add
  them again
- [x] An About BatteryPulse window: version and build, license, links to the project, the User
  Guide and the release notes, and Check for Updates; from the app menu, the menu bar
  popover and Settings
- [x] The first half minute after plugging in. A timeline from the M5 Air (`pmset` and
  `ioreg` every 2 s): macOS itself reports "AC attached; not charging" for 29 s, and the
  registry keeps the last discharge current (−661 mA) until then. Captures taken 10–40 s after
  plugging in show the SMC's `B0AC` already at +1.9 A, and just after unplugging the registry
  still reads +250 mA while `B0AC` reads −562 mA. So current and voltage now come live from the
  SMC, "not charging" becomes "charging" as soon as it measures a charge current, and the
  monitor reads again 3–60 s after the adapter is plugged in or out

### Stage 1.3: Menu bar icon styles (0.4)

- [x] Choose what the menu bar shows, in any combination: the battery icon, the charge, the
  battery power and the battery temperature; the popover shows the temperature too

- [ ] A choice of menu bar icon styles, so BatteryPulse can replace the system battery item
  (turned off in System Settings → Menu Bar → Battery; BatteryPulse can't hide it itself,
  so Settings explains this and links there). Built in 0.4.0, to verify on the M5: Symbol (the
  SF Symbol, as before), Modern (like macOS 27: a capsule without an outline, the empty part
  translucent), Classic (outlined), Percentage Inside (like macOS 26) and Ring; the ring has
  only the state colors, no color or monochrome choice. Sizes are in `BatteryIconLayout`
- [ ] Draw the battery to the exact level with SwiftUI shapes, not the five steps of the SF
  Symbols, with every state the system shows: charging (bolt), plugged in but not charging or
  charge on hold (plug), low (red at 20 % and below), Low Power Mode (yellow). Built in 0.4.0,
  to verify on the M5
- [ ] Check light and dark menu bars, Increase Contrast and Reduce Transparency, and the menu
  bar's height on displays with a notch
- [ ] 0.6.1: rework the drawn styles. On the M5 (0.4.0) they look off next to the system item:
  Modern is thicker and larger than the macOS 27 battery, Percentage Inside's digits are taller
  than the body and change colour at the fill edge, the previews in Settings differ in size, and
  the ring is thin. Render `BatteryIconLayout` on Linux and match it to screenshots of the
  system item before changing the app

### Stage 1.4: Liquid Glass and motion (0.5)

Every animation is triggered by an event, plays once and lasts 0.15–0.35 s; it is keyed on the
discrete parts of a reading, never on the 2 s values, and goes through one policy. Liquid Glass
stays on controls; the glass bubbles come from standard segmented controls.

- [x] Foundation: `MotionPolicy` and `BatteryMotionKey` in BatteryCore (percent, tier, plugged
  in, charge state, symbol, power flow with a 0.15 W dead band, just above the current's noise, Low Power Mode), tested
  on Linux against the M5 captures
- [x] `\.motion` on every window and the menu bar panel: fades under Reduce Motion and Prefer
  Cross-Fade Transitions, no one-off extras under Low Power Mode or when macOS asks apps to save
  resources, and no animation at all while the window is covered, minimized, on another Space
  or the display sleeps (per-window occlusion; the menu bar item keeps the app itself visible).
  The presets, plus `numericValue` (numbers that roll) and `liveRefresh` (polling that stops in
  hidden windows) for the views to adopt
- [x] `MotionGuardTests`: no repeating or per-frame animation, no animation keyed on the whole
  snapshot, none in the menu bar label, and `glassEffect` only in the three files allowed
- [x] Overview: the percent rolls in the direction of change; the battery glyph's fill, colour
  and bolt animate; rings and tile values; the power flow's adapter slides in and out, its arrow
  follows the flow without flickering, symbols swap, one bounce on reaching full; the time line
  fades
- [x] Power and Health: rows that come with plugging in or charging; the active USB PD profile;
  Low Power Mode and thermal state; rings (optionally filling once per launch)
- [x] Developer option "Glass Cards" (Settings → Advanced, with the Developer section): the cards
  in Liquid Glass, one `GlassEffectContainer` per page, plain when off or under Reduce
  Transparency; off by default
- [x] Main window: polling only while visible and on pages with live values, a short page fade,
  toolbar grouping, feedback and a VoiceOver announcement for Copy Report, the tour's page switch
  in one transaction
- [x] History: the period switch moves into the toolbar as a segmented control with the
  system's sliding glass selection; the charts crossfade on a period switch without morphing the
  lines; the minute reload pauses in a hidden window
- [x] Raw Data: a source menu in the toolbar (All, Battery, Pack, Banks, Charger, IOPS,
  Adapter, SMC — only those present) that filters the table, since a SwiftUI Table can't be
  scrolled to a section; a pop-up rather than segments, because seven or eight segments don't
  fit the default window (in Russian even five don't); rows never animate
- [x] Review fixes: under Reduce Motion layout snaps and only opacity and colour fade (also in
  Demo Mode); scene variations don't animate the 2 s values; the update window swaps status and
  install phases in place; Copy Report takes a fresh reading on pages that don't poll
- [x] Demo Mode: one transaction per change; the demo bar materializes and morphs in interactive
  glass; Play and Pause as one button; the demo clock sleeps while paused and ticks once a
  second on scenes
- [x] Compact window and menu bar panel: rolling percent, polling through `liveRefresh`, the Demo
  badge in the toolbar, no animated window resizing; the menu bar label stays unanimated
- [x] Settings: the menu bar icon style picker gets a flowing glass selection; borders with Show
  Borders; the Glass Cards toggle
- [x] Software Update, What's New and Welcome: status and phase crossfades, one staggered entrance,
  the pulse line drawing in once; widget number and symbol transitions and rendering modes
- [ ] Check on the M5: frame rate (Instruments), energy with the window visible, covered,
  minimized, on another Space and with the display asleep (Activity Monitor and Power
  Profiler), legibility with the Liquid Glass slider at both ends, and Reduce Motion, Prefer
  Cross-Fade Transitions, Reduce Transparency, Increase Contrast and Show Borders

### Stage 2: iOS MVP

- [ ] iOS target sharing SwiftUI components with macOS
- [ ] Screen: charge, state, Low Power Mode, thermal state
- [ ] Charging session while the app is open: %/min, estimate to 100 %
- [ ] Analytics file import (Share Sheet / Files): cycles, health, capacity, temperature

### Stage 3: History and charts

- [x] Compact sample store in `BatteryCore` (append-only JSON Lines, tested on Linux)
- [x] macOS background recording about once a minute while the app runs
- [x] Swift Charts: charge and power over 24 h / 7 days, capacity and cycles over time
- [x] Statistics: average drain, time on battery, energy from the battery, charging sessions
- [x] One sample file per UTC day, compacted daily summaries, launch and wake markers,
  samples on state changes, shading from raw samples, hover readout as an overlay, temperature
- [ ] Accessibility chart descriptors (hourly or daily summaries for VoiceOver)
- [ ] Measure App Nap's effect on the minute timer, and how often the mAh values change
- [ ] Apps using the most energy (optional): which apps drain the battery most and at what
  average power over the last hour or day, like Activity Monitor's Energy tab but in watts.
  Researched: per-app ("coalition") energy counters give CPU, GPU and Neural Engine energy in
  nanojoules without root on macOS 26, through private but exported calls that shipping
  software already uses; per-process `proc_pid_rusage(RUSAGE_INFO_V6)` is public but covers
  only the user's own processes and only the CPU. Nobody has shown the coalition calls working without root on
  macOS 27 yet, so a one-day spike on the M5 comes first. Show watts and Wh with an
  "unattributed" remainder (display, memory, radios, idle); history only from when
  BatteryPulse runs

### Stage 4: Widgets and notifications

- [x] WidgetKit (macOS): charge, state, time to full or empty, health, cycles, temperature
- [ ] WidgetKit (iOS)
- [ ] iOS Live Activity while charging
- [x] Notifications (macOS): charge threshold reached, low battery, overheating, "Service
  Recommended"

### Stage 5: iPhone and iPad battery health on the Mac (0.4)

- [ ] Read the battery of an iPhone or iPad connected by USB or Wi-Fi: charge, maximum capacity,
  cycles, design and full-charge capacity, temperature. Researched: load Apple's private
  MobileDevice framework with `dlopen` (no entitlements; the app isn't sandboxed), list devices
  with `AMDeviceNotificationSubscribe`, and ask the `com.apple.mobile.diagnostics_relay` service
  for the device's `AppleSmartBattery` registry entry, the same data the Mac has. Public
  captures cover iPhones on iOS 26.6 and iPads on iPadOS 17.7 and 27.0.1; iPhones on iOS 27
  still need checking. Rely on the trust the user already gave in Finder; no pairing
  of our own in the first version, and no promise that health matches iOS Settings until checked
  on a real iPhone. Keep the transport behind a protocol so the usbmuxd/lockdown protocol can
  replace the framework if Apple breaks it. Start with half a day on the Mac to confirm the
  calls and the iOS 27 keys.
  - [x] Spike in `bpulse` (0.4.0, preview): `--devices` and `--device <n> [--json | --raw]`.
    MobileDevice is loaded with `dlopen` from `/Library/Apple` first, then `/System`, and
    nothing is linked. Devices come from the notifications plus `AMDCreateDeviceList`; every
    call runs on one serial queue while subscribed. No pairing calls. The relay is asked for
    `AppleSmartBattery` (`IOPMPowerSource` as a fallback), then `AppleSmartBatteryPack`,
    `AppleSmartBatteryBank` and `AppleChargerData`, then Goodbye, with 5 s socket timeouts
    and 30/60 s deadlines. The transport sits behind `IDeviceTransport`/`IDeviceLink`. The
    parser is tested with synthetic data until real captures exist
  - [x] iPhone 17 Pro Max on iOS 27.0.1 as a fixture: the bpulse spike worked on the first try
    over USB. Health is nominal ÷ design (Settings: 95 %; the pack's `LifetimeData.NccpFiltered`
    is the same 95; full charge ÷ design would be 97.9 %); the temperature is the pack's
    `Temperature` sensor, not `VirtualTemperature`; `DateOfFirstUse` matches Settings' First Use;
    the pack's `UUID` is now redacted
  - [ ] An iPad (9th generation) capture, and the manufacture date (Settings: August 2025; the
    pack's `ManufactureDate` doesn't decode like the Mac's yet)
  - [ ] The device in the app's UI (0.6): a Devices section with a page per device
- [ ] Remember each device and keep its history next to the Mac's (0.6)

### Stage 6: Later (optional)

Researched in October 2026 (each with an adversarial check). A paid Apple Developer account
($99 a year) comes up in every item: it brings Developer ID signing and notarization, which
remove Open Anyway, keep permissions across updates and unlock iCloud.

- [ ] **Mac battery on the iPhone via iCloud.** Needs the paid account: CloudKit and push are
  unavailable to ad-hoc and free-team builds on both platforms. With it: a CloudKit private
  database written by the Developer ID Mac app, silent pushes and a widget on the iPhone
  (refresh about every 15–60 minutes), and visible alerts through `CKQuerySubscription` (those
  read record fields, so the alerting fields can't also be encrypted). Without it, only the local
  network or Bluetooth LE, which iOS won't relaunch for after a force-quit. Blocked on Stage 2
  (iOS app) anyway.
- [ ] **Bluetooth device batteries on macOS** (0.6) (keyboard, mouse, trackpad, headphones): feasible
  without the paid account. powerd publishes accessory batteries through the private
  `IOPSCopyPowerSourcesByType(4)` (reached with `dlsym` in IOKit, no entitlement, no Bluetooth
  prompt; read with the public IOPS calls, refreshed on the `com.apple.system.accpowersources.*`
  notifications), with `pmset -g accps -xml` as a fallback. Seen working for Magic Keyboard and
  Mouse, a third-party Bluetooth LE mouse and a classic Bluetooth headset on macOS 15; AirPods per part
  (left, right, case) and macOS 27 still need checking on the M5. Anything beyond IOPS needs
  Bluetooth permission, which ad-hoc signing loses on every update.
- [ ] **CSV/JSON export** of history (0.6): public APIs only (`fileExporter`), about two days,
  formatting tested on Linux; CSV dialect follows the locale's decimal separator.
- [ ] **Charge limiting.** The old SMC route is closed: on macOS 27 firmware the charge-inhibit
  keys that charge limiters used are gone or behind an Apple-private entitlement, even for root
  and even with a paid account. macOS 26.4+ has its own Charge Limit (80–100 %); a third-party
  app can reportedly set it through the private `PowerUISmartChargeClient` without root, so
  BatteryPulse could offer that limit in its own UI plus a read-only report of what the firmware
  allows. Below 80 %, forced discharge and the MagSafe LED need a root helper and are disputed
  on macOS 27: not now. Macs on the same firmware with macOS 15.8 have no built-in limit, so no
  charge control at all there.
- [ ] **A package manager.** The main macOS package manager's official catalog needs
  notarization and some popularity. A personal catalog of our own works today, but every install
  and upgrade still needs Open Anyway. Worth it after notarization.

## Releases

| Version | Date       | Highlights |
|---------|------------|------------|
| 0.2.0   | 2026-10-14 | Main window (Overview, Power, Health), optional menu bar and Dock presence, Developer section with decoded and explained Raw Data and Demo Mode, English and Russian |
| 0.3.0   | 2026-10-14 | Battery temperature and cell voltages, History with charts and statistics, notifications, a widget, the compact window, the Raw Data inspector, update check and What's New |
| 0.3.1   | 2026-10-15 | Fixes from the first run on the M5 Air: per-cell charge voltage, SMC values in Raw Data, compact window labels; the SMC temperature as a fallback |
| 0.4.0   | 2026-10-15 | Update check frequency, Install and Relaunch with signed releases, the About window, menu bar content and drawn icon styles, charging shown within seconds from the SMC, Raw Data explanations for the pack, banks, cells and charger, and an iPhone/iPad command-line preview |
| 0.5.0   | 2026-10-15 | Liquid Glass and motion: rolling numbers, filling gauges, the bolt drawing in, glass toolbar switches and demo bar, Reduce Motion and hidden-window rules that save energy; iPhone health as iOS Settings shows it in `bpulse` |

Next: **0.6.0** is about the other devices: iPhone and iPad in the app, remembered with their
history (Stage 5), the batteries of Bluetooth accessories (Stage 6), and CSV/JSON export of the
history; plus the open checks on the M5 (a capture at the Charge Limit stop point, a profile in
Instruments, menu bar icons on light and dark menu bars, widgets across an in-app update).
**0.6.1** reworks the drawn menu bar icon styles (Stage 1.3). Optional, if a one-day spike on
the M5 works: the apps using the most energy. Not planned: an iOS app, charge limiting, and
Developer ID signing until there is a paid developer account.

## Development environment

- **Claude cloud sessions** (Linux, Swift 6.4): `swift build`, `swift test`. Everything builds
  and tests except code under `#if os(macOS)` / `#if os(iOS)`.
- **CI** (`xcode-27` runner: macOS 27, Xcode 27): builds and tests the Darwin code and builds
  `BatteryKit` for iOS.
- **The maintainer's Mac:** running the tools and the UI: `swift run BatteryPulse`,
  `swift run bpulse`, or `scripts/build-app.sh` for the packaged app.
