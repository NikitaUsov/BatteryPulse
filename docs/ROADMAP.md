# BatteryPulse roadmap

A lightweight native Swift/SwiftUI app for macOS and iOS that shows detailed battery and
charging state.

## Decisions

- **Platforms:** macOS 27 minimum; BatteryKit still builds for iOS 27 (PLT-05). macOS 27 means
  Apple Silicon only, since it no longer runs on Intel Macs. No Intel code paths. CI's macOS job
  keeps building BatteryKit for iOS, as cheap insurance, until that first costs time (decided with
  M-2 on 2026-10-22).
- **Distribution (macOS):** a DMG outside the App Store. The app is not sandboxed, so SMC reads
  are possible. A notarized DMG needs a paid Apple Developer account, and there won't be one: on
  2026-10-22 the maintainer decided against it, not now and
  not before 1.0. BatteryPulse is a non-commercial hobby project with about no users, and he
  won't pay for an Apple developer account for this app; he is willing to spend on help with
  development, not on the account. So each install from the DMG needs Open Anyway in Privacy &
  Security, in-app updates don't, and permissions or placed widgets may need setting up again
  after a DMG replaces the app; 1.0 documents these as known limitations.
- **Distribution (iOS):** not in 1.x (M-2 in `docs/plans/1.0/ROADMAP.md`, decided on
  2026-10-22). Public iOS APIs give only the level and the charging state, personal installs from
  Xcode have to be re-signed every 7 days, and TestFlight and the App Store need the paid account
  the maintainer declined; BatteryPulse on the Mac already reads an iPhone's or iPad's battery
  health (Stage 5).
- **Reference hardware:** MacBook Air M5 running macOS 27.
- **App shape:** a regular app with a main window (sidebar: Overview, Power, History, Health,
  Devices with a page per iPhone or iPad and Accessories, optional Developer), a compact window and a widget, plus an optional menu bar item. Users choose menu bar and Dock presence; the app is
  never hidden from both. Liquid Glass stays in the control layer, per Apple's HIG: the
  system's sidebar, toolbar and controls, plus custom glass only on controls that float over
  content (the Demo Mode bar). Content uses standard fills and is never glass. Motion is short,
  plays once on a battery event or a user action, turns into fades under Reduce Motion, and
  stops in windows that can't be seen and in the menu bar label.
- **Window styles (0.6):** the main and compact windows offer Standard (default), Frosted,
  Translucent and Clear (Settings → General). Standard and Frosted follow the HIG: Frosted is a
  standard material as the app background. Translucent and Clear knowingly go against it (Liquid
  Glass in the content layer, a window-sized sheet, glass under the system's glass, and for
  Clear contrast below the HIG minimum over parts of a bright wallpaper and a dark appearance
  chosen by the style), because they were asked for; they are opt-in, never the default, say
  what they cost in Settings, apply only to the main and compact windows and give way to
  Standard under Reduce Transparency or Increase Contrast. The sidebar stays the system's in
  every style; Frosted stays frosted in inactive windows; no Low Power Mode fallback (decided on
  2026-10-22; 0.6.2 measured Standard and Clear once each, Stage 1.7).
- **Languages:** English (source) and Russian, in a String Catalog. The language is chosen per
  app in System Settings, like any Mac app. Repository text stays English; the catalog is the only
  place with Russian.
- **Privacy (0.7): the anonymous version count.** Decided by the maintainer
  on 2026-10-22, so he can see how many people use which version, and announced honestly.
  - **What happens:** once per version, at least a day after that version first runs on a Mac,
    an automatic update check also downloads a small file, `BatteryPulse-count.txt`, from that
    version's GitHub release. GitHub counts the download, and the file's public download count is
    the number of Macs that use that version.
  - **What is sent:** nothing else. No identifier of any kind, nothing about the Mac, its battery
    or the settings, and from 0.7 the update traffic keeps no cookies. There is no server of our
    own and no third-party service. GitHub sees the address and the app's version, as it does for
    the update check.
  - **When it runs:** it is on by default. It never runs when Check for updates is Never, never
    from Check Now, and it turns off in Settings → General, which the Welcome window shows. It
    adds no wake-up of its own: it rides on the scheduled check.
  - **How it is announced:** What's New and the release notes say it, README and the User Guide
    gain a Privacy section, and the file itself explains what it is for.
  - **The contract:** a new settings switch (three settings keys: `anonymousVersionCount`,
    `lastCountedVersion`, `versionFirstLaunch`) and a new release asset (`BatteryPulse-count.txt`)
    are frozen-surface changes, so they arrive in a minor release. Through 0.6.x the app counts
    and sends nothing.
- **Releases have no dates.** BatteryPulse is a hobby project: a release ships when there is time
  and desire. The plans keep the order of the versions and estimate their effort, but set no
  target date (decided on 2026-10-22).

## Principles

- **No third-party dependencies.** System frameworks only.
- **Event-driven.** Readings update on OS power notifications, plus one a minute for history
  while recording is on. Fast polling (every 2 s) runs
  only while a view shows live values such as current or power.
- **Platform-independent core.** `BatteryCore` has no Apple-only dependencies and is tested on
  Linux and macOS against real captures (`bpulse --raw`).
- **Swift 6 with strict concurrency.**
- **Resource targets (macOS):** about 0 % CPU when idle, under 30 MB RAM, binary under 5 MB.
- **Privacy.** No account, no analytics service and no server of our own: readings, history,
  devices and settings stay on the Mac. The app connects to the internet only to reach GitHub.
  Through 0.6.x that is the update check and a download the user chose; from 0.7 it is also the
  anonymous version count, on by default and easy to turn off (Decisions). No identifier, nothing
  about the Mac, its battery or the settings is ever sent, and GitHub's public download counts
  are the only usage numbers the maintainer gets. Reading an iPhone or iPad over Wi-Fi stays on
  the local network.

## Road to 1.0

1.0.0 is the first release meant for people other than the maintainer. What it means was approved
by him as written on 2026-10-22; the full plan, with how each criterion is checked, is
`docs/plans/1.0/ROADMAP.md` (§2), and everything still open, each item placed in a version, is in
`docs/plans/1.0/INVENTORY.md`.

**Five promises:**

1. **Seen working.** What the User Guide says works was seen working on the M5 in a packaged
   build.
2. **A week without a crash.** The final 0.9.x runs in daily use for seven days without a crash.
3. **In-app updates from older versions.** Install and Relaunch reaches 1.0 from older versions,
   with data and settings kept.
4. **Nothing breaks through 1.x.** Scripts, settings, stored data, placed widgets and the update
   path keep working.
5. **Usable by a non-expert.** Someone who isn't an expert can install BatteryPulse, understand
   what it shows and report a problem without developer tools.

1.0.0 is the last 0.9.x renamed, with no new code.

**The criteria,** each checked by a Linux or CI test, a scripted step on the M5 or a document that
exists:

- **C1 Contents:** everything 0.6.1 ships; 0.7's configurable Battery widget (small, medium and
  large, and extra large if its layout is approved) and the Accessories widget; macOS's Charge
  Limit, read-only (its number only if 0.8 proves a source, else a known limitation); 0.8's
  answers.
- **C2 Every feature seen in a packaged build:** `docs/VERIFICATION.md` maps each User Guide
  feature to the session and the evidence from a DMG build, and every open "Check on the M5" line
  here is ticked or listed under Known limitations in the guide and in 1.0's notes.
- **C3 No known issue in anything on by default:** the guide's known issues list only the beta
  styles, the Developer options and what C7 allows; Open Anyway on each DMG install, and a
  permission or placed widget lost when a DMG replaces the app, are documented known limitations.
- **C4 Seven-day soak:** the final 0.9.x on the M5 for 7 days, nights included: no crash report
  for the app or the widget, no fault message, memory on day 7 within 10 % of day 1, and every
  History gap explained by a launch, a wake or a sleep.
- **C5 Energy within budgets:** on one day, the final 0.9.x no more than 15 % above 0.6.2's DMG
  in wake-ups, energy with power in the menu bar, CPU with the displays asleep, launch to the menu
  bar (with exactly one read before it) and idle memory; an attached iPhone with every window
  closed under 1 ms/s.
- **C6 Resource targets:** the app binary under 5 MB, idle CPU within C5's comparison at about one
  read a minute, and idle memory with no window open under 30 MB (or the measured number, with the
  maintainer's yes).
- **C7 Upgrade matrix:** Install and Relaunch reaches the final 0.9.x from 0.4.0, 0.6.1, the last
  0.7.x and the last 0.8.x, plus one install over the old copy from the DMG; History, devices and
  settings survive, and the guide names any permission or widget to set up again.
- **C8 No update leaves an app that can't launch:** the installer refuses a bundle that needs a
  newer macOS, and the old copy comes back if the new one fails to open.
- **C9 Robustness pinned by tests:** every storage format decodes and a future file loses
  nothing; a capture with a key removed, a type swapped or an extreme value never crashes and
  shows "—" or "Unavailable", never a wrong number; a missing source gives an explanation.
- **C10 Accessibility:** VoiceOver reaches and names every control on every page, the menu bar
  panel, every Settings pane and every widget size, in English and Russian; every chart has a
  descriptor; the keyboard works without a pointer; contrast passes in Standard and Frosted, light
  and dark, and with Increase Contrast.
- **C11 Russian:** the maintainer signs off a screenshot set of every screen, alert, notification
  and error message, and the catalog stays complete.
- **C12 Engineering gates:** no compiler warnings, the strict lint, every guard suite green and a
  test count that only grows, plus new guards for explanations, log privacy and frozen surfaces.
- **C13 Release health:** no open issue about a crash or data loss, and the last two releases
  before 1.0 needed no rollback.
- **C14 Stability for 1.x:** the promises below.
- **C15 Releases and keys:** the DMG, its signature and the debug symbols on GitHub Releases, with
  in-app updates; two signing keys, today's and an offline backup; the `release` environment's
  reviewer confirmed.
- **C16 First install, ad-hoc:** README and the guide show Open Anyway with screenshots from the
  current macOS 27.x; the guide's Known limitations and 1.0's notes say that every install from
  the DMG needs it and in-app updates don't.
- **C17 The documentation matches the product:** README without iOS promises or "early
  development", with screenshots and an honest hardware claim; the guide with a Compatibility
  section, Uninstall and Troubleshooting, and every file BatteryPulse writes and every request it
  makes; Help opening the guide at the release's tag; `SECURITY.md`; a bug template that asks for
  the version and the install; no `swift run` in user-facing text.

**The 1.x promises (C14).** Within 1.x a change may only add; breaking one waits for 2.0.

1. **Settings keys** of the `io.github.nikitausov.BatteryPulse` domain: names, types and defaults,
   and the legacy migrations. 0.7's anonymous version count adds three keys (Decisions).
2. **Storage** under Application Support (`History/`, `Devices/`): files only gain fields, readers
   ignore unknown ones, and a newer devices file makes the store read-only, never lossy.
3. **The capture format** of `bpulse --raw` and Export Capture.
4. **`bpulse`'s machine outputs:** `--json`, `--raw`, `--device <n> --json|--raw`,
   `--accessories --json|--raw`, `--export csv|json`, the `--record` folder, the options and the
   exit codes 0, 1 and 2; fields and options are only added. The text report, `--help`, the text
   of `--smc` and `--watch`, and stderr may change, with a line in the release notes.
5. **Widgets:** kind strings; the intent, entity and query type names, parameter names, option
   raw values and entity ID formats; the sizes offered, which are only added to; what Automatic
   shows in each size; the page and route strings, and the URL scheme if there is one.
6. **The update contract:** `BatteryPulse.dmg` and `BatteryPulse.dmg.sig` on GitHub Releases,
   read through `releases/latest`; signing keys are only added (a compromised key is removed in a
   release whose notes say why); the bundle IDs and the log subsystem; every 1.x version installs
   the next one in-app. 0.7's version count adds `BatteryPulse-count.txt` to every release
   (Decisions).
7. **Platform:** macOS 27 or later on Apple silicon throughout 1.x; the floor rises only in 2.0.
8. **Privacy:** the app reaches the internet only to talk to GitHub, through ephemeral sessions:
   the update check and a download the user chose, and from 0.7 the anonymous version count
   (Decisions). No identifier and nothing about the Mac, its battery or its settings is sent, and
   within 1.x nothing is added to what is sent.

Not promised: readings macOS stops providing, looks and wording, the beta window styles' look
(their stored values keep decoding), the Developer options, energy beyond C5's budgets, and the
signpost names.

**The order of the versions,** with their effort [estimate]; an order, not a schedule:

| Version | What it brings | The maintainer's time | Runs |
|---------|----------------|-----------------------|------|
| 0.7 | Widgets you configure (Battery in small, medium and large, extra large on the look check's yes, and Accessories), device JSON dates, the anonymous version count, the Charge Limit's paused state | about 31-34 minutes: the look check and a second look (about 19), Session R hands-free, the logged day's end and the after-publishing check (about 12-15); plus about 5 for the backup key | about 31-34, plus 3 in reserve; the stretch adds 8-9 |
| 0.8 | Answers in the app: why it isn't charging, the configured Charge Limit, a health summary, explanations, Report a Problem, VoiceOver and the keyboard | a look sitting of about 40 minutes and a release-candidate sitting of about 85 | 30-38 |
| 0.9.0 | Ready for others (feature freeze): the docs, the written 1.x promise, the ad-hoc first install documented, `bpulse` in the app | about 50 minutes, plus up to 60 for the verification matrix's open rows | 8-11, plus whatever 0.8's cut line moves |
| 0.9.x | Release candidates, fixes only: the soak, the energy budgets, the upgrade matrix | about 40 minutes, plus 70 unattended and a passive 7-day soak | 1-3 each |
| 1.0.0 | The promise: the last 0.9.x renamed | the after-publishing check, about 10 minutes | 1-2 |
| 1.1 | macOS 28 compatibility once macOS 28 ships (an event, not a date), and the widgets that waited | — | — |

**No dates.** "This is a hobby project; we release when there is time and desire" (the
maintainer, 2026-10-22). No version has a target date, a calendar or an outer bound; the order
and the estimates stay. If 1.0 isn't out when macOS 28's betas arrive, it still ships on macOS 27,
checked there.

## What the platforms expose

| Reading                                      | macOS 27 | iOS 27                |
|----------------------------------------------|:--------:|:---------------------:|
| Charge level, charging state                 | ✅       | ✅ `UIDevice`          |
| Optimized charging hold                      | ✅*      | —                     |
| Charge Limit reached                         | ✅‡      | —                     |
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
charge is on hold; not yet seen in a macOS 27 capture for the Mac's battery (the M5 Air showed
the key only in the AirPods' entries, 2026-10-23).

‡ macOS's Charge Limit (System Settings → Battery) pauses charging with bit 24 (0x01000000) of
`ChargerData.NotChargingReason`, seen in `AppleSmartBattery` and its child `AppleChargerData` with
the limit at 80 % on the M5 Air (2026-10-23); raising the limit to 100 % clears it and charging
resumes. Shown from 0.7. The configured value is in no registry or IOPS key. The candidates for it
(0.8), best first: powerd's charging preferences file
(`/Library/Preferences/com.apple.powerd.charging.plist`, readable without root, read as a file),
which holds the limit only while the Mac is on the adapter; System Settings' own record of the
last limit, which kept it on battery but may be stale; the SMC's `CHLT` (present on the M5 Air,
its value unread); and `pmset -g battlimit`, which prints the file's policy (80 % at the hold),
also only on the adapter.

On iOS the public API only provides level and state. The rest can come from the analytics file
iOS lets users export (Settings → Privacy & Security → Analytics & Improvements → Analytics
Data), without private APIs. The format still has to be checked against a real file.

## Architecture

```
BatteryCore    (Linux + Apple)   models, parsing, metrics, text report, history, SMC wire format
     ▲
BatterySource  (Apple)           IOKit and the SMC (macOS) / UIDevice (iOS)  ◀── Widgets
     ▲
BatteryKit     (Apple)           BatteryMonitor (@Observable), iPhone and iPad, CryptoKit
     ▲
bpulse (CLI, macOS)    App (SwiftUI: macOS menu bar + iOS)
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
- [ ] Verify on the M5: a capture at the macOS Charge Limit stop point. `bpulse --record`
  (0.6.0) keeps captures just before and after every charging change, with a timeline. Partly
  settled in 0.6.2's first session (2026-10-23 and 24, the limit at 80 %): the paused state is bit
  24 (0x01000000) of `ChargerData.NotChargingReason`, in `AppleSmartBattery` and its child
  `AppleChargerData`, with no charge current, and raising the limit to 100 % clears it; the
  configured value is in no registry key. That session's reads put its candidates for 0.8 in this
  order: powerd's charging preferences file
  (`/Library/Preferences/com.apple.powerd.charging.plist`, readable without root), which holds
  the limit only on the adapter (gone about 5 minutes after unplugging, back at plug-in); System
  Settings' own record of the last limit, which stayed 80 on battery and at 100 % alike; the SMC's
  `CHLT`, which `bpulse --smc` lists (it prints no `CH*` values; a value read waits for a reviewed
  change); and `pmset -g battlimit`, which prints the file's policy, also only on the adapter. The
  redacted capture of the hold came with the session's report. Open until it is committed as a
  test fixture (0.7, QUA-05, `docs/plans/1.0/ROADMAP.md`)
- [x] 0.4: glossary entries for the keys of the pack, banks, cells and charger entries of
  macOS 27; `RawKeyGlossaryTests` lists the ones still unexplained (about 20 on the M5)
- [ ] Glossary: re-check the keys left out as uncertain, and add captures from other Apple
  silicon Macs (M1–M4) as test fixtures
- [ ] Profile in Instruments against the resource targets
- Not planned: Developer ID signing and notarization (no paid Apple Developer account, decided
  on 2026-10-22, not before 1.0). Open Anyway on a first install stays, documented as a known
  limitation at 1.0 (`docs/plans/1.0/ROADMAP.md` C16).

### Stage 1.2: Updates and About (0.4)

- [x] Update check frequency in Settings → General: daily, weekly, monthly or never, in place of
  the on/off switch (off becomes never; a manual Check for Updates still works with never)
- [x] Release notes in the Software Update window: join the lines of a wrapped paragraph or
  list item, which now break mid-sentence (seen with 0.3.1's notes)
- [x] Install updates from the app: download the DMG itself, verify it, replace the app and
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
  - Mechanics: mount with `hdiutil attach -nobrowse -readonly` (from 0.6.2 `diskutil image
    attach`, Stage 1.7), copy next to the app on the same volume, then a small detached step
    waits for the app to quit, swaps the two bundles
    atomically (`renamex_np` with `RENAME_SWAP`), deletes the old copy, registers the new one
    with Launch Services and relaunches it. Skip when the app runs translocated or outside a
    writable folder.
  - Ad-hoc identity changes with every build, so permissions tied to it (not notifications,
    which follow the bundle ID) would be asked for again; only a Developer ID signature would fix
    that, and there is no paid account (2026-10-22), so it stays a known limitation.

  As built: Install and Relaunch downloads the DMG with URLSession into
  `~/Library/Caches/<bundle ID>/Updates` and checks GitHub's SHA-256 digest when the release has
  one and, always, an Ed25519 signature of the DMG (`BatteryPulse.dmg.sig`, made by
  `scripts/sign-update.swift` in the release workflow from the `UPDATE_SIGNING_KEY` secret of
  the `release` environment, which needs the maintainer's approval for each run,
  checked against the keys in `ReleaseSigning.publicKeys`). It mounts the DMG at a private mount
  point, copies the app into a temporary folder on the app's volume, clears quarantine, and
  checks the bundle ID, that the version is exactly the release's and newer than the running
  one (so a signed old build can't be installed over a newer one), and a strict code-signature
  validation. Then it swaps the bundles with `renamex_np(RENAME_SWAP)`, registers the new one
  with `LSRegisterURL` and relaunches through `/bin/sh`, which waits for the old process to end
  and runs `open -n`; the old copy is deleted at the next launch. Translocated copies, folders
  the user can't write, development builds and the other errors fall back to Download in the
  browser; since 0.6.1 a release without a signature, or a download that fails the digest,
  signature, bundle or code-signature check, gets a warning and the release page instead, never
  the DMG. The built-in keys are a list, so a new key can ship before it signs (`swift
  scripts/sign-update.swift --help` is the rotation runbook); a lost key still means one manual
  DMG install with the new key's build. Follow-ups: re-register the login item
  and reload the widget timelines on the first launch after an update.

  Seen on the M5 on 2026-10-22: the maintainer installed 0.6.1 through Install and Relaunch from
  0.6.0, the desktop widget stayed and showed the current charge, and Open at login kept its
  state, so the login item needs no re-registering.
- [x] Keep the widgets on the desktop across an update. (Replacing 0.3.1 with 0.4.0 from the DMG
  kept them on the M5, and so did the in-app update from 0.6.0 to 0.6.1 on 2026-10-22, with the
  widget current.) Replacing 0.3.0 with 0.3.1 from the DMG removed them; the gallery still
  offered the widget, and it worked once added again. The in-place swap above keeps the path,
  registers the new copy and raises `CFBundleVersion`, then reloads the timelines; from 0.6.2 the
  installer also ends the running widget extension just before the swap, so macOS can't take
  the old one's description for the new version. Each release's check after publishing looks
  again; a loss stays a documented known limitation at 1.0 (no Developer ID signature is
  coming, 2026-10-22), and the guide tells the user to add them again
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
  SF Symbol, as before), Modern (like macOS 27: a rounded battery without an outline, the empty
  part translucent), Classic (outlined), Percentage Inside (like macOS 27 with the percentage on)
  and Ring; the ring has only the state colors, no color or monochrome choice. Sizes are in
  `BatteryIconLayout`
- [ ] Draw the battery to the exact level with SwiftUI shapes, not the five steps of the SF
  Symbols, with every state the system shows: charging (bolt), plugged in but not charging or
  charge on hold (plug), low (red at 20 % and below), Low Power Mode (yellow). Built in 0.4.0,
  to verify on the M5
- [x] Check light and dark menu bars: on the M5 the icon looks right next to the system's battery
  item in both appearances (0.6.1's session, 2026-10-22)
- [ ] Check Increase Contrast and Reduce Transparency, and the menu bar's height on displays with
  a notch. `scripts/menu-bar-shots.sh` shoots every style next to the system item on light and
  dark wallpapers with both appearances, and records each display's menu bar height, scale and
  notch (`scripts/display-metrics.swift`)
- [ ] 0.6.0: rework the drawn styles. On the M5 (0.4.0) they looked off next to the system item:
  Modern read heavier (a full capsule, a darker track, a small thin bolt) although it was
  smaller, Percentage Inside's digits changed colour at the fill edge, the previews in Settings
  differed in size, and the ring was thin. Matched to 2x screenshots of the system item,
  measured on the M5: a 23 × 12 pt body, 4 pt corners, a 1.375 × 4 pt terminal, a 14 pt bolt,
  and 7.4 pt digits knocked out of the battery, scaled down uniformly for "100"; every bar style
  shares one 26 × 14 pt canvas, the ring has a 3 pt stroke, and the Settings previews share one
  size. Built in 0.6.0; to tick after the checks on the M5 next to the system item (light and
  dark bars, the plug, 100 % on power, Percentage Inside with 1–3 digits)

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
  Transparency; off by default (replaced by window styles in 0.6, Stage 1.5)
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
- [x] Settings: the menu bar icon style picker gets a flowing glass selection (an accent outline
  since 0.6.1); borders with Show Borders; the Glass Cards toggle
- [x] Software Update, What's New and Welcome: status and phase crossfades, one staggered entrance,
  the pulse line drawing in once; widget number and symbol transitions and rendering modes
- [ ] Check on the M5: frame rate (Instruments), energy with the window visible, covered,
  minimized, on another Space and with the display asleep (Activity Monitor and Power
  Profiler), legibility with the Liquid Glass slider at both ends, and Reduce Motion, Prefer
  Cross-Fade Transitions, Reduce Transparency, Increase Contrast and Show Borders

### Stage 1.5: Window styles (0.6)

Standard, Frosted, Translucent and Clear for the main and compact windows. Built without the
planned spike on the M5 (the maintainer checks after release); the open points are in the check
below. Since 0.6.1 Translucent and Clear are beta styles, offered only with Settings → Advanced →
Beta window styles on.

- [x] `WindowLook` and `WindowLookPolicy` in BatteryCore (the code avoids SwiftUI's
  `WindowStyle`): the background, group surface and sheet rules per style, Reduce Transparency
  and Increase Contrast giving Standard, the glass sheet's tint per system appearance, Clear's
  content treatment; tested on Linux
- [x] `ToneMap`: every colour the windows draw is a role (level, cycles, capacity bars, chart
  lines, spans, track, hairline, accent, warning, Demo Mode steps, text); today's colours in
  colour, white at fixed steps and an inverted badge in Clear. `MotionGuardTests` keeps system
  colour names out of `Main/`, the level and Demo Mode tints
- [x] The Developer option Glass Cards removed (its stored value deleted, not mapped); the main
  window's page kept in scene storage, so a style change that rebuilds the window keeps it
- [x] Settings → General: Window Style, four static preview tiles in the generalised tile
  picker (the icon styles use it too, drawn at 2.5×), footers for each style and for the
  accessibility override
- [x] Frosted: a standard material behind the window, active also in inactive windows; frost
  layers for the cards; Forms without their background; the Raw Data table opaque
- [x] Translucent: one clear glass sheet with a 45 % dimming tint; no card surfaces, hairlines
  between groups, bold numbers and medium text, no tertiary text, defined ring channels, Form rows
  and Raw Data rows on the sheet
- [x] Clear: the window in the dark appearance (that window only), graphite control tint, the
  monochrome tone map, a shadow and halo under each group, the inverted badge for a low level or
  a worn battery, a dashed second line in the power chart
- [x] `MotionGuardTests`: window backgrounds and appearance overrides only in
  `App/WindowLook.swift`, nothing animated there, never a white tint
- [ ] Check on the M5: whether the glass sheet samples the desktop and how the system sidebar,
  toolbar, inspector and Demo Mode bar look on it (fallback for Translucent: a thin
  behind-window material with the dimming layer); the material against the widget gallery; the
  graphite tint on the sidebar selection; that the dark appearance stays in its window; Form
  section fills and table stripes; the scroll edge under the title; full screen; contrast with
  Accessibility Inspector; energy of each style in Instruments (and whether Clear's shadows show
  up there); screenshots for the user guide
- [ ] Not done yet: thicker chart lines and wider area fills on the sheet (the charts keep their
  default line width), and the content treatment on the Raw Data table (an AppKit-backed table)

### Stage 1.6: Optimization and foundation (0.6.1)

No new features: readability, speed, energy, security and size, each measured before and after
against `claude/baseline-0.6.0` (0.6.0 plus the instrumentation, built with the same compiler).
The release numbers go into the performance baseline at release.

- [x] Measurement: Points of Interest signposts with a `perf` log line each
  (`scripts/perf-stats.swift` sums them), `scripts/rusage.swift`, a profiling build
  (`PROFILING=1 scripts/build-app.sh`), Linux benchmarks, and in CI a size report with ceilings,
  a warning gate, job time limits and a launch smoke test
- [x] Swift 6.4 manifest: one `strict` settings array for every target (upcoming features and
  warnings as errors) and strict memory safety for BatteryCore and bpulse
- [x] The two look bugs users reported: the Window Style and Icon Style tiles mark the choice
  with an accent outline instead of glass, and Clear dims more (0.65) so its white text stays
  readable over bright windows. While a Translucent or Clear window minimizes, its sheet is a
  plain fill of its tint: on the M5 that keeps Translucent from turning black, but Clear still
  does (a known issue of the beta, for 0.6.2)
- [x] Before 0.6.1's plan: the widget also refreshes when the estimate arrives after a plug change
  and when it moves; earbuds are named after the buds, not their case
- [x] Size: a ULMO DMG, stripped binaries that export only `_main` (debug symbols ship as
  `BatteryPulse-dSYMs.zip`), `-Osize`, and an empty English string table; the DMG went from about
  3.7 MB to under 1.5 MB
- [x] Reads: one read per burst of power notifications, 150 ms after the first; the monitor runs
  on an injected clock, so its tests are deterministic; polls read the SMC's two live keys and
  the others at most every 60 s
- [x] Update integrity: a release without a signature, or a download that fails its digest,
  signature, bundle or code-signature check, gets a warning and the release page, never the DMG; a
  list of signing keys with a rotation runbook; the browser opens release pages only on github.com
  over https; the update traffic goes through ephemeral sessions without a cache, and automatic
  checks skip Low Data Mode and expensive networks; the installer verifies and replaces off the
  main actor and holds one activity, ended on every way out
- [x] Raw Data rows built once per reading off the main actor, filtered as prebuilt rows (about
  6.4 → 2.7 ms per keystroke on Linux)
- [x] App services follow the monitor through `Observations` in named tasks; failed history
  writes and every widget reload are logged
- [x] History: decoded day files are cached (a warm 7-day load about 85 → 3 ms on Linux), the
  charts' data is built off the main actor in BatteryCore (`HistoryChartData`), and the page is
  split into `Main/History/`
- [x] Devices and accessories: `Mutex` and checked `Sendable` instead of `@unchecked`
  (9 → 4 in the package), MobileDevice and the accessory symbol loaded with `RTLD_FIRST`, a
  Devices folder only the user can read, and a device list that can't be read is never
  overwritten
- [x] Releases: `build-app.sh` checks the signing posture, the workflows pin every action by
  commit, and the release notes must open with the version's heading
- [x] Views: one file per component and per Settings pane
- [x] Fixes found on the way: a Mac reporting 0 rated cycles no longer breaks the cycle gauges;
  the menu bar's power value keeps updating after the icon is turned off or Demo Mode ends;
  Export Capture reports a failed save; Copy Report's tooltip fits pages without a report; the
  "notifications are off" note updates after a return from System Settings
- [x] Energy: every periodic wake-up allows macOS at least 10 % of its interval to coalesce it;
  live values refresh less often in Low Power Mode, under reduced resources or when the Mac runs
  hot, and the menu bar stops polling while the displays sleep
- [x] Less code: members no product uses, found with the index store and checked with `git grep`
  (Swift keeps public library symbols from dead stripping, so the linker's maps can't show them),
  removed; unused `Codable` conformances dropped and the report's sections folded into its lines
- [x] Guard tests on Linux for every target, Darwin code included: `SecurityGuardTests` (where
  `dlopen`, IOKit user clients, `Process` and `kill` may appear; `URLSession.shared`,
  `Task.detached` and `@unchecked Sendable` as they stand), `EnergyGuardTests` (tolerances,
  timers, activities, widget reloads) and two new motion rules (animations only from the
  presets, no material in `Main/` but the chart readout's)
- [x] The M5 session on the release candidate (2026-10-22): the tile pickers, Clear in a bright
  window, minimizing, the chart readout in every style, the stripped widget, every page,
  relaunch, alerts and the login item, and the update window with an install of the real 0.6.0
  through the new installer all passed, except three findings fixed before release:
  - Translucent and Clear still don't look right to the maintainer, so they became beta styles:
    Settings → Advanced → Beta window styles adds them to the picker, marked Beta, and turns
    itself on for a window that already used one;
  - the chart readout without a material was unreadable on the glass sheets, so it is back on
    0.6.0's material, the one material in `Main/`;
  - Raw Data's source pop-up cut longer names off-centre; it is a menu button sized to its label.
- [ ] Not measured in the session, for 0.6.2's: energy with power in the menu bar
  (`scripts/rusage.swift` against the 0.6.0 baseline) and each window style's energy

Decisions that last beyond 0.6.1:

- **Measure first.** Optimizations come with a before and an after: signposts with stable names
  (CLAUDE.md lists them), a baseline branch built with the same compiler, Linux benchmarks for
  BatteryCore, and the CI size report, whose ceilings sit about 5 % above the release candidate.
- **Rules have guard tests.** A rule a reviewer would otherwise have to remember (motion, glass,
  colours, energy, risky APIs) is a Linux test over every target's sources; an exception goes on
  the test's list with its reason.
- **Energy.** Event-driven first; a poll only while a view shows live values, slower while the
  system saves energy and none while the displays sleep; one read per burst of notifications;
  every periodic wake-up with a tolerance of at least 10 %; no timers; one activity, around an
  install.
- **Concurrency.** Work leaves the main actor through `@concurrent` functions, tasks have names,
  services observe with `Observations`, and `@unchecked Sendable` is kept only where the
  compiler can't see (C callbacks and tables, immutable images), each with its reason. Main actor
  by default waits for 0.6.2, because only a long session on the M5 can show its runtime traps.
- **Updates.** A release the app can't verify is never offered as a download; the signing keys
  are a list; update traffic leaves no cache and automatic checks respect Low Data Mode.
- **Size.** ULMO, stripped binaries with published debug symbols, `-Osize`.
- **API surface.** `public` stays; no `package` access and no documentation lint on every public
  declaration.
- **Frozen outputs.** Within a minor release, `bpulse`'s output and exit codes, the capture
  format, the storage formats, the settings keys and the update contract don't change; a change
  waits for a version that announces it (device JSON dates, 0.7).
- **Looks.** The tile pickers mark the choice with an accent outline; selection glass would
  return only with a pixel test. Clear dims at 0.65 in both appearances. Translucent and Clear
  stay beta styles until the maintainer signs them off on the M5; the History chart readout keeps
  its material, because a readout over a plot has to read on every style.

#### Performance baseline (0.6.0 → 0.6.1)

Before is `claude/baseline-0.6.0` (0.6.0 plus the instrumentation), after the release candidate,
both built with Xcode 27.1 on the CI runner; the published 0.6.0 DMG was 3,670,713 B.

| Size | 0.6.0 | 0.6.1 | Change |
|---|---|---|---|
| DMG | 3,699,952 B (UDZO) | 1,439,093 B (ULMO) | −61 % |
| Installed app | 11,180 KB | 4,608 KB | −59 % |
| App binary (`__text`) | 7,618,784 B (2,116,636 B) | 2,856,976 B (1,917,508 B) | −62 % (−9 %) |
| Widget binary (`__text`) | 3,172,800 B (1,084,028 B) | 1,379,792 B (942,748 B) | −57 % (−13 %) |
| Exports per binary | 4,195 | 1 (`_main`) | |
| String tables (`.lproj`) | 410,328 B | 238,124 B | −42 % |
| Build-machine paths in the binaries | 0 | 0 | |

| Linux benchmark (release, median of three alternated runs) | 0.6.0 | 0.6.1 |
|---|---|---|
| History, 7 days, first load | 75 ms | 80 ms (unchanged within noise) |
| History, 7 days, warm load | 77 ms | 2.5 ms |
| History, 7 days, after today's file grows | — | 2.4 ms |
| Raw Data sections | 3.8 ms | 2.6 ms |
| Raw Data filter per keystroke (0.6.0's five-way match in the view; 0.6.1's prebuilt rows) | 7.6 ms | 2.4 ms |
| Parse and report (B1, B6) | | no change beyond noise |

| Code | 0.6.0 | 0.6.1 |
|---|---|---|
| Lines: BatteryCore / BatteryKit / app / widget / bpulse | 9,336 / 2,731 / 8,562 / 207 / 483 | 9,995 / 3,291 / 9,229 / 215 / 480 |
| Lines: tests; `@Test` | 9,737; 539 | 12,519; 658 |
| Compiler warnings; swift-format findings | 0; 0 | 0 (now a CI gate); 0 |
| `@unchecked Sendable` | 9 | 4 |
| `withObservationTracking` | 4 | 0 |
| `Task.detached` | 4 | 1 |
| `URLSession.shared` | 3 | 0 |
| `try?` | 67 | 51 |
| `@MainActor` in the app | 38 | 35 |
| `Task.sleep` without a tolerance | 10 | 4 (one-shots) |

| MacBook Air M5, release candidate (`scripts/perf-stats.swift` over the session's `perf` lines) | 0.6.1 |
|---|---|
| Full read, p50 / p95 | 6.3 ms / 8.8 ms |
| Registry part of a read, p50 | 4.5 ms |
| SMC: the two live keys on every poll / the other keys, at most once a minute | 0.48 ms (594 reads) / 2.1 ms (93 reads) |
| Reads per burst of power notifications | about 1 |
| Reads before the menu bar item is ready | 1 |
| History load, p50: 24 hours / 7 days | 51.6 ms / 9.9 ms |
| Page switch | 30–65 ms |
| Update check | 269 ms |

Energy and launch weren't measured in the session; they move to the 0.6.2 session, against the
same baseline.

### Stage 1.7: Maintenance and foundation (0.6.2)

A second maintenance and foundation release with no new features: 0.6.1's deferred backlog, the
beta window styles' known bug, the energy measurements 0.6.1's session skipped, and the size and
read-path groundwork that widget customization (0.7) needs. The plan, removed at the release, is
readable in the history of the 0.6.2 release PR's head (`refs/pull/12/head`); its widget design
moved to `docs/plans/0.7.0/widgets.md`, and its Appendix C, session tools and both sessions'
reports were copied to `docs/plans/0.7.0/`.
Two sittings on the M5: an early one (about 65 minutes plus 3 hours unattended, 2026-10-23/24) and
one on the release candidate, run hands-free on 2026-10-30 with about the planned 13-15 minutes of
the maintainer's time (a first attempt on 2026-10-27 was cancelled). WP-18's Xcode items didn't
run.

- [x] Clear minimizes without a black frame: an opaque graphite fill (fill (b), the maintainer's
  choice, 2026-10-22) while the window minimizes and comes back, on Clear and on Translucent in
  the dark appearance. On the release candidate all 8 cases (Translucent and Clear, light and
  dark, the main and the compact window) showed the window or an even graphite grey, never a
  black frame. The tile pickers' footer keeps its height, so the Clear tile's preview should look
  the same selected or not (not checked on the M5). The evidence for leaving beta (screenshots in
  every style, the contrast audit, each style's energy) wasn't gathered, so both stay beta
- [x] Energy, measured on the M5 on battery in alternated runs compared by their medians: 0.6.1
  against the 0.6.0 baseline in the first session, the release candidate against 0.6.1 in the
  second (three valid runs each, the table below). With the icon and charge in the menu bar the
  release candidate uses 137.4 against 277.0 mJ an hour (processor time 0.59 of 0.6.1's), with
  power in the menu bar too 905.5 against 1,175.4 (processor time 0.79). Not measured: Translucent
  and Frosted, a covered or minimized window, the popover, a burst of plug changes, memory and
  devices
- [x] Release statistics (tooling, no app change): `swift scripts/release-stats.swift` prints a
  table per release of DMG downloads, signature downloads (each in-app install fetches the
  signature, so they count in-app updates) and, from 0.7.0, the version count's downloads
  (`BatteryPulse-count.txt`), from GitHub's public API without a login; within GitHub's limit of
  60 requests an hour it says when to try again instead of retrying
- [ ] A week after publishing: DMG and signature download columns in the Releases table, filled
  from that script for 0.2.0-0.6.1 and 0.6.2 (the app sends nothing for them)

Deferred from 0.6.1, each for the reason given:

- [x] Main actor by default (WP-10), first: the app target only, `@MainActor` in the app from 35
  to 4, the code that runs off the main actor marked `nonisolated` and pinned by a guard test.
  What it breaks shows only at runtime, so it went first to the M5: the first session's
  notifications, pages, Demo Mode, Check Now and lid close showed no executor trap or crash, and
  the release candidate's session repeated them, with an install, and found none either
- [x] The read path, which the M5 numbers now gate in: a full read takes 6.3 ms at p50 and 8.8 ms
  at p95, 72 % of it the registry.
  - Read the registry only when it changes (E4b): a poll reuses the last read's registry unless
    Power or Raw Data is shown or the copy is 5 minutes old. In the first session's 3 hours of
    `pmset -g pslog` and `ioreg` samples, on battery and charging, every update of the registry
    came with a notification; a read that finds one that didn't logs `registry.missed`.
  - Reads off the main actor (E20, past its 4 ms threshold): in the first session's 2-hour run,
    711 of 712 reads, all but the launch's.
  - One notify key (E3b): `com.apple.system.powersources.timeremaining` dropped, since each one
    came with the "any power source" key within 10 ms.
  - The release candidate's session measured a cached read at 0.971 ms (p50, 409 reads) and no
    missed update in 62 minutes.
- [x] SwiftUI instrument work on the pages, which switched in 21–54 ms (Session A, 2026-10-23):
  0.6.2 rebuilds only the Raw Data sections that changed and keeps that page's body off the
  reading (E19, SUI-07, SUI-11); the other pages' cost is the framework's geometry, and the charts
  stay (SUI-12 not needed). After, on the release candidate: 18–52 ms at p50 (30.4 ms over all 69
  switches, p95 53.3 ms), close to the before on every page; the profiling build's pass under the
  SwiftUI instrument is 0.7's before
- [ ] Xcode on the Mac (installed on the M5): SUI-17 and SUI-19 (SUI-18 dropped on 2026-10-23);
  the Icon Composer icon (SZ-10), shipped only on the maintainer's yes to its screenshots. Not run
  in the release candidate's session: after the macOS 27.2 update Xcode asked to install system
  components, which the hands-free session left alone, and the frozen worktree had no icon
  source. They move to 0.7, into Session R's GUI phase
- [x] CryptoKit out of the widget (K-03): a lower `BatterySource` target that the widget depends
  on alone, besides BatteryCore; with `-internalize-at-link` on the widget's and the app's link
  lines, the size headroom 0.7's widget work needs. In CI, against the build before: the widget
  binary −45 % (778,640 B, its `__text` −50 %), the app −3 %, the DMG −15 %. The flag shipped on
  both lines: on the M5 the release candidate's small and medium widgets read right in English
  and its pages worked; the Russian widget wasn't redrawn during the check, a test artifact that
  0.7 covers
- [x] The installer mounts and ejects with `diskutil image attach` and `diskutil eject`;
  `hdiutil attach`, `detach` and `imageinfo` are deprecated in macOS 27 but still work. Built:
  `diskutil image attach --readOnly --mountPoint <folder> --mountOptions nobrowse`, then
  `diskutil eject`, and by force `unmountDisk force` and `eject` of the image's own disk, which
  `diskutil info -plist` names; CI installs both ways. The update from 0.6.1 to 0.6.2 still runs
  0.6.1's installer. The release candidate's in-app install on the M5 passed (the widget
  extension ended 55 ms before the swap, no eject failure, no Finder window, the widget
  reloaded), so `diskutil` stays
- [ ] MobileDevice in a helper process (SEC-10), only on evidence of a hang or crash
- Enhanced Security (SEC-08): not planned (decided on 2026-10-22: no session step, and the
  Developer ID build it was to be retried on won't exist without the paid account)
- [ ] `-noverify` when the installer mounts the DMG (SEC-15), if mounting takes 100 ms or more;
  Check Now cancels a waiting automatic check (E10); SEC-18's research
- [x] Readability and tooling: SW-13 for BatterySource and BatteryKit (strict memory safety, each
  unsafe use marked with its reason, four `@safe` types, a guard test for both); a DocC link check
  of BatteryCore in CI (SW-21, 9 s); C2 as a table of the parser's peak memory per fixture in CI,
  without a budget, since the runner's virtual machine counts no instructions; SUI-09 needed no
  change, as every `@State` is already set in one place. SZ-11 (full LTO) and SZ-14
  (`-dead_strip_dylibs`) were measured and not adopted: LTO lost the widget's debug symbols and
  grew the DMG, and after K-03 every library the widget links is used
- [ ] SZ-08 with the next glossary work
- [x] CI: `actions/checkout` v7.0.1 and `upload-artifact` v7.0.2, pinned by commit in both
  workflows; `checkout` v6.1.0 turned down, a tag still without a changelog entry
- [ ] The 0.6.0 checks that 0.6.1's session doesn't cover, which stay open in their stages: the
  Charge Limit capture (Stage 1.1; captured in the first session, its fixture still to come); full
  screen, the contrast audit with Accessibility Inspector and each window style's energy (Stage
  1.5); frame rate and energy with motion (Stage 1.4); the menu bar icons with Increase Contrast and
  on displays with a notch (Stage 1.3); iPhone, iPad and accessory captures in the packaged app,
  as the session's optional device step didn't run (Stages 5 and 6); exported files in spreadsheet
  apps (Stage 6). Widgets kept on the desktop across an in-app update, seen across 0.6.0 → 0.6.1
  on 2026-10-22, are ticked in Stage 1.2

#### Energy and speed on the M5 (0.6.1 → 0.6.2)

Before is the 0.6.1 release (build 7), after the release candidate (0.5.99, build 373), on the
MacBook Air M5 with macOS 27.2, on battery, in alternated runs on 2026-10-30. Energy and processor
time are medians of the valid runs (`scripts/rusage.swift`); the reads and page switches are
`scripts/perf-stats.swift` over the release candidate's `perf` lines.

| MacBook Air M5, on battery | 0.6.1 | 0.6.2 | 0.6.2 ÷ 0.6.1 |
|---|---|---|---|
| Energy, the icon and charge in the menu bar, every window closed (3 runs each) | 277.0 mJ/h | 137.4 mJ/h | 0.50 |
| Processor time, the same | 2.277 s/h | 1.333 s/h | 0.59 |
| Energy, power in the menu bar too (3 runs each) | 1,175.4 mJ/h | 905.5 mJ/h | 0.77 |
| Processor time, the same | 7.735 s/h | 6.127 s/h | 0.79 |
| Cold launch to the menu bar item (5 launches) | 157–167 ms | 157–166 ms | unchanged |
| Page switch, p50 / p95 (69 switches) | — | 30.4 ms / 53.3 ms | |
| Cached read, p50 | — | 0.971 ms (409 reads) | |
| Registry updates no notification announced | — | 0 an hour (62 minutes) | |

In Low Power Mode, and with the displays asleep, one pair each came out about equal (0.6.2 ÷ 0.6.1
1.03 in energy both times). With the main window open on Overview the release candidate used
4,248.4 mJ/h in Standard and 4,335.8 in Clear, one run each; Translucent and Frosted weren't
measured.

### 0.7

Widgets you configure, plus the device JSON's dates, the anonymous version count and macOS's
Charge Limit shown. The plan: `docs/plans/0.7.0/PLAN.md`. The widget design it builds on, moved
from 0.6.2's plan at 0.6.2's release: `docs/plans/0.7.0/widgets.md`.

- [ ] Widget customization: the widget's own edit sheet (App Intents) chooses what it shows, with
  defaults that keep a placed widget looking as it does today: the main value and visual, the
  details per size, clock time or time left, level colours or monochrome; every rendering mode,
  device names hidden where the widget is redacted, clicks that open the matching page,
  VoiceOver. Which fields fit which size is decided in BatteryCore and tested on Linux. In
  phases:
  - 0.6.2, throwaway builds on the M5 for what the design depends on, plus the size headroom
    (K-03 and `-internalize-at-link`) and the read off the main actor that the widget's provider
    reuses. Their first answers (2026-10-23): a SwiftPM build gets the App Intents metadata and
    the edit sheet shows the parameters; the sandboxed widget reads a file the app writes, and
    reads accessory batteries itself; a widget placed by 0.6.1 survives the move to a
    configurable widget if the old widget extension has ended before the swap, which 0.6.2's
    installer sees to;
  - the 0.7 MVP, never cut: the Battery widget in small, medium and large (extra large only if
    its layout is approved), Layout Automatic or Custom, status lines, the read time, empty
    states and accessibility, the reload planner, and the Accessories widget (all of them, or
    the lowest);
  - 0.7's stretch, else 1.1: the small copy of the last readings the app writes for the widgets
    (the feed), and with it the History widget (with the 90-day capacity and cycle trend) and an
    iPhone & iPad widget;
  - after 1.0: a Refresh button, the extra-large dashboard and portrait size, per-row links,
    chosen accessories
- [ ] `bpulse --device <n> --json` writes dates as ISO 8601 strings, like the Mac's report
  (`firstUseDate` is a number of seconds since 2001 today), and every top-level JSON object gains
  a format version, with a line in the release notes, because scripts that read it have to change
- [ ] The anonymous version count (Decisions), on by default and announced: once per version, at
  least a day after it first runs, an automatic update check also downloads
  `BatteryPulse-count.txt` from that version's release, and its public download count shows how
  many Macs use each version. A switch in Settings → General (also in the Welcome window),
  greyed out while Check for updates is Never, when nothing is counted; no cookies on any update
  traffic; the policy in BatteryCore with Linux tests, and guard tests that keep the request in
  `UpdateNetwork`'s ephemeral sessions. What's New, the release notes, README's and the User Guide's new Privacy
  sections and the file's own text say what is sent, what isn't and where to turn it off; the
  release workflow attaches the file to every release from 0.7.0, and the Releases table gains a
  Count column
- [ ] macOS's Charge Limit shown, read-only (the maintainer's request, 2026-10-23): while the
  limit holds the charge, Overview's state says so in Apple's wording, with a pointer to System
  Settings → Battery; Power gains a "Charge limit: Reached" row; the menu bar popover, the compact
  window and the widget's state line say the same, and the widget offers a Charge limit field;
  Raw Data decodes the bit. From bit 24 of `NotChargingReason`, and only with a committed
  fixture of the real state (else it moves to 0.8). Not the limit's number (0.8), no marker on
  the ring or the battery, no menu bar icon change, and `bpulse` unchanged. The app's own "When
  charged to" alert never fires under a lower limit, which the guide says.
  BatteryPulse never sets the limit

### 0.8 to 1.0.0

The path to 1.0.0 is in `docs/plans/1.0/ROADMAP.md`, and everything still open, each item placed
in a version, in `docs/plans/1.0/INVENTORY.md`.

- [ ] 0.8, answers in the app: why the battery isn't charging (only causes proven by captures), the
  configured Charge Limit (80–100 %) if a candidate proves a source (powerd's charging preferences
  file on the adapter, System Settings' own record on battery, the SMC's `CHLT` or `pmset -g
  battlimit`; no registry key holds it), a health summary and explanations of the numbers, a
  first-run Welcome, Report a Problem (a bundle you preview and save; nothing is sent), VoiceOver
  and the keyboard everywhere, and tests that pin what 1.x keeps
- [ ] 0.9.0, ready for others: the documentation (Open Anyway on a first install, with fresh
  screenshots), the written 1.x promise and `bpulse` inside the app; no Developer ID signing,
  since there is no paid developer account; features freeze here, and 0.9.x only fixes
- [ ] 1.0.0: the last 0.9.x renamed, once its five promises hold (approved by the maintainer on
  2026-10-22): every feature seen working in a packaged build on the M5 or listed as a known
  limitation; seven days of daily use without a crash; in-app updates from older versions (0.4.0
  on); nothing that breaks through 1.x (settings, stored data, `bpulse`'s machine outputs, placed
  widgets and the update path kept); and usable by a non-expert, VoiceOver included. Energy stays
  within 15 % of 0.6.2's. Open Anyway on each DMG install, and permissions or widgets a DMG
  replacement may lose, are known limitations. No date: it ships when it is ready

Decided on 2026-10-22: no paid developer account (the maintainer won't pay for one for this app), so
no Developer ID signing or notarization and no App Group (the History and iPhone & iPad widgets can
only use a small copy of readings the app writes, which 0.6.2's sandbox spike showed the widget can
read); Xcode is on the M5, so the Xcode-only checks run; widgets in 0.7, with no 0.6.3; no iOS app
and no charge limiting (setting a limit) in 1.x (the Decisions section at the top changes in 0.7's
docs pass); what 1.0 means, approved as written, with no dates for any release; an anonymous version
count in 0.7 (Decisions); every other open question decided by its recommendation. Added on
2026-10-23, at the maintainer's request: macOS's Charge Limit is shown, read-only (0.7 the paused
state, 0.8 the number); BatteryPulse still never sets it.

Usage so far (GitHub's API, 2026-10-22): 14 DMG downloads across all releases and 5 signature
downloads (each in-app install fetches one; 15 and 6 at a re-check later that day), 2 repository
page views by 1 visitor in 14 days, and no stars, forks or outside issues; in practice the
maintainer is the only user. From 0.6.2 on, `scripts/release-stats.swift` prints each release's
DMG and signature download counts, and they are added to the Releases table a week after
publishing. Through 0.6.x the app itself counts and sends nothing; from 0.7 the anonymous version
count adds one public number per release, how many Macs ran it (Decisions), and nothing else.

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
  (`bpulse --record`'s `timeline.tsv` lists the mAh value and the gauge's update time every 5 s)
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
  - [x] The device in the app's UI (0.6): a Devices section with a page per device. Opt-in
    (*Read iPhone and iPad batteries*, off by default): with it off nothing loads or runs.
    IOKit USB matching notifications (Apple vendor ID, product IDs 0x1290–0x12FF) trigger a
    device list, so the framework stays unloaded while no iPhone or iPad is on USB. A device
    on USB is read on attach, every 5 minutes while history is recorded and every minute while
    its page is visible; Wi-Fi only on Refresh and Check Again. Quick retries at 20 and 60 s;
    a time-out stalls automatic work until the user acts. The policy, roster and monitor are
    tested on Linux with a scripted transport and a manual clock. From 0.6.2 the page's
    connection label follows the transport its values came over: once the cable is pulled, a
    read over Wi-Fi says Wi-Fi rather than USB, and a device still on its cable keeps USB and its
    automatic reads; to check on the M5 with a device that is on both
- [x] Remember each device and keep its history next to the Mac's (0.6): `Devices/devices.json`
  and a `HistoryStore` per device, keyed by HMAC-SHA256 of the UDID with a per-install secret;
  no UDID, serial or capture on disk. History has a source pop-up; Forget removes a device and
  its history
  - [ ] On the M5: library validation and the Local Network prompt in the packaged app, attach
    and detach timing, the product ID range, sleep, page switching, Russian layout, the iPad
  - [ ] Energy with an iPhone attached and all windows closed (target under 1 ms/s on
    average) and memory after 2 hours; not measured yet

### Stage 6: Later (optional)

Researched in October 2026 (each with an adversarial check). A paid Apple Developer account
($99 a year) comes up in every item: it brings Developer ID signing and notarization, which
remove Open Anyway, keep permissions across updates and unlock iCloud. The maintainer declined
the account on 2026-10-22 (not before 1.0), so the items that need it are not planned.

- [ ] **Mac battery on the iPhone via iCloud.** Needs the paid account: CloudKit and push are
  unavailable to ad-hoc and free-team builds on both platforms. With it: a CloudKit private
  database written by the Developer ID Mac app, silent pushes and a widget on the iPhone
  (refresh about every 15–60 minutes), and visible alerts through `CKQuerySubscription` (those
  read record fields, so the alerting fields can't also be encrypted). Without it, only the local
  network or Bluetooth LE, which iOS won't relaunch for after a force-quit. Blocked on Stage 2
  (iOS app) anyway.
- [x] **Bluetooth device batteries on macOS** (0.6) (keyboard, mouse, trackpad, headphones): feasible
  without the paid account. powerd publishes accessory batteries through the private
  `IOPSCopyPowerSourcesByType(4)` (reached with `dlsym` in IOKit, no entitlement, no Bluetooth
  prompt; read with the public IOPS calls, refreshed on the `com.apple.system.accpowersources.*`
  notifications, a burst coalesced into one read, plus one read whenever the page or the panel
  becomes visible; no polling). Shipped: the Accessories row in the sidebar's Devices section, a
  block in the menu bar panel, an optional low-battery notification (once per discharge, on the
  lowest part that drains), fixed demo accessories in Demo Mode, and `bpulse --accessories`
  (`--raw` pseudonymizes names and identifiers). No history and no export rows: accessories
  report only their charge. Seen working for Magic Keyboard and Mouse, a third-party Bluetooth LE
  mouse and a classic Bluetooth headset on macOS 15. Earbuds ship as IOPS reports them: per part
  (left, right, case) when published, a combined part otherwise; whether macOS publishes them at
  all is still to check on the M5. `pmset -g accps -xml` is not a fallback (it calls the same
  function); it is the contingency only if macOS 27 turns out to hide the list from apps, which
  the M5 captures (`bpulse --accessories --raw` next to `pmset -g accps -xml`) decide. Still to
  check on the M5: those captures (keyboard on Bluetooth and on its cable, earbuds in and out of
  the case), the symbols, the Russian panel with three parts, and the energy profile with
  accessories connected. Anything beyond IOPS needs Bluetooth permission, which ad-hoc signing
  loses on every update.
- [x] **CSV/JSON export** of history (0.6): an Export menu in History's toolbar (minute readings
  or daily health as CSV, both as JSON, everything the store keeps) and `bpulse --export`.
  Public APIs only (`fileExporter` with a `Transferable` file); the formatting is
  locale-independent and tested on Linux; the CSV dialect follows the region's decimal
  separator. Still to check on the M5: the files in spreadsheet apps in a Russian and an English
  region, and the Save panel.
- [ ] **Charge limiting.** The old SMC route is closed: on macOS 27 firmware the charge-inhibit
  keys that charge limiters used are gone or behind an Apple-private entitlement, even for root
  and even with a paid account. macOS 26.4+ has its own Charge Limit (80–100 %); a third-party
  app can reportedly set it through the private `PowerUISmartChargeClient` without root, so
  BatteryPulse could offer that limit in its own UI plus a read-only report of what the firmware
  allows. Below 80 %, forced discharge and the MagSafe LED need a root helper and are disputed
  on macOS 27: not now. Macs on the same firmware with macOS 15.8 have no built-in limit, so no
  charge control at all there. Not in 1.x; showing macOS's own limit without setting it is
  planned instead (0.7 and 0.8).
- [ ] **A package manager.** The main macOS package manager's official catalog needs
  notarization and some popularity. A personal catalog of our own works today, but every install
  and upgrade still needs Open Anyway. Not planned: the official catalog needs notarization, and
  so the paid account the maintainer declined (2026-10-22).

## Releases

| Version | Date       | Highlights |
|---------|------------|------------|
| 0.2.0   | 2026-10-14 | Main window (Overview, Power, Health), optional menu bar and Dock presence, Developer section with decoded and explained Raw Data and Demo Mode, English and Russian |
| 0.3.0   | 2026-10-14 | Battery temperature and cell voltages, History with charts and statistics, notifications, a widget, the compact window, the Raw Data inspector, update check and What's New |
| 0.3.1   | 2026-10-15 | Fixes from the first run on the M5 Air: per-cell charge voltage, SMC values in Raw Data, compact window labels; the SMC temperature as a fallback |
| 0.4.0   | 2026-10-15 | Update check frequency, Install and Relaunch with signed releases, the About window, menu bar content and drawn icon styles, charging shown within seconds from the SMC, Raw Data explanations for the pack, banks, cells and charger, and an iPhone/iPad command-line preview |
| 0.5.0   | 2026-10-15 | Liquid Glass and motion: rolling numbers, filling gauges, the bolt drawing in, glass toolbar switches and demo bar, Reduce Motion and hidden-window rules that save energy; iPhone health as iOS Settings shows it in `bpulse` |
| 0.6.0   | 2026-10-16 | iPhone and iPad in the app with their history, Bluetooth accessory batteries, window styles (Standard, Frosted, Translucent, Clear), menu bar icons matched to macOS 27, CSV/JSON history export, the widget kept current across updates; `bpulse --accessories`, `--export` and `--record` |
| 0.6.1   | 2026-10-22 | Optimization and foundation: a 61 % smaller download, one read per power event, a minute's pace for the SMC's other keys, slower polls in Low Power Mode and none while the displays sleep, faster History and Raw Data, updates that are never offered unverified; Translucent and Clear become beta styles; accent-outline tile pickers |
| 0.6.2   | 2026-10-30 | Maintenance and foundation: about 40 % less processor time in the background with the icon and charge in the menu bar (about 20 % with power shown too), Clear and dark Translucent windows that no longer turn black on their way to the Dock, Check Now that takes over a running automatic check, iPhone and iPad pages that name the connection their values came over, a smaller widget extension without CryptoKit, the installer on `diskutil`; main actor by default and battery reads off the main actor |

Next: **0.7**, widget customization (the 0.7 stage, `docs/plans/0.7.0/PLAN.md`): widgets you
configure in their own edit sheet, the device JSON's dates, the anonymous version count and macOS's
Charge Limit shown. Then **0.8**: answers in the app; **0.9**: ready for others; **1.0.0**: the
last 0.9.x renamed (`docs/plans/1.0/ROADMAP.md`). This is the order, not a schedule: each release
ships when there is time and desire. Not planned: an iOS app, charge limiting (setting a limit),
and Developer ID signing and notarization (no paid developer account, decided on 2026-10-22: not
before 1.0).

## Development environment

- **Claude cloud sessions** (Linux, Swift 6.4): `swift build`, `swift test`. Everything builds
  and tests except code under `#if os(macOS)` / `#if os(iOS)`.
- **CI** (`xcode-27` runner: macOS 27, Xcode 27.1): builds and tests the Darwin code, builds
  `BatteryKit` for iOS, packages the app, reports its size and launches it once.
- **The maintainer's Mac:** running the tools and the UI: `swift run BatteryPulse`,
  `swift run bpulse`, or `scripts/build-app.sh` for the packaged app.
