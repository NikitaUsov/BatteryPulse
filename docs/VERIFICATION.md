# BatteryPulse verification matrix

Every feature the [User Guide](USER_GUIDE.md) describes, with the sessions on the M5 (the
reference MacBook Air, macOS 27) that saw it working in a packaged build, a DMG from CI or a
published release, and their evidence: a screenshot, a recording, a log or an answer given in the
session. It is how 1.0's first promise, "seen working", is checked (criterion C2 in the roadmap's
[Road to 1.0](ROADMAP.md#road-to-10)): at 1.0 every row is seen working, or the guide and 1.0's
release notes list it under Known limitations.

## How to read it

- **One row per feature,** grouped by the guide's sections. `bpulse` is in the guide but not in the
  DMG yet (0.9.0 puts it in the app), so its rows count a build from source.
- **One column per session,** oldest first. A cell names the session's question or step, its
  answer (y means it looked right; numbered answers keep the session's scale) and what was seen.
  Session A's cells are on the published 0.6.1 unless they name SPIKE-A2. "—" means the session
  didn't look at it; "0.6.2 Session B (pending)" waits for that session's report.
- **Status:** **Seen** (all of the row, as the guide describes it now), **Partly** (the rest is
  listed) or **Not seen**, with what is left and where it is expected.
- **Upkeep:** each release's last step (D3) adds its release-candidate session's column, a row for
  every feature the guide gained, and the new status. 0.6.2's D3 fills the Session B column;
  0.7's D3 adds its Session R and the widget, Accessories widget, Charge Limit and version count
  rows.

## Sessions and builds

| Session | When | Builds | Report |
|---------|------|--------|--------|
| 0.6.1's release-candidate session | 2026-10-22, macOS 27.0.1 | Build B, 0.5.99 (CI run 39492991212), the 0.6.1 release candidate; its F12 step installed the published 0.6.0 from it | The two session comments on [PR 11](https://github.com/NikitaUsov/BatteryPulse/pull/11) |
| A0 | 2026-10-22 | The published 0.6.1, installed by Install and Relaunch from 0.6.0 | The maintainer's report from everyday use, recorded in ROADMAP Stage 1.2 |
| 0.6.2 Session A | 2026-10-23 to 24, macOS 27.0.1 | The published 0.6.1 (7); SPIKE-A2, 0.0.0 (285): 0.6.1 with the app on the main actor by default and the battery read off it, plus a spike-only switch for the minimize fill (CI run 39808734092). The widget spikes were throwaway builds for 0.7's design and aren't evidence here | `docs/plans/0.6.2/sessions/A.md` as merged in `5849d01` ([on GitHub](https://github.com/NikitaUsov/BatteryPulse/blob/5849d017a50260369bbac4e4f6da9f067a9110e2/docs/plans/0.6.2/sessions/A.md), a link that outlasts the plan folders), with four crops of the minimize fill; recordings, traces and captures that name devices stay on the maintainer's Mac |
| 0.6.2 Session B | 0.6.2 Session B (pending) | The 0.6.2 release candidate | 0.6.2 Session B (pending) |

## Install ([guide](USER_GUIDE.md#install))

| Feature | 0.6.1 (RC session, A0) | 0.6.2 Session A | 0.6.2 Session B | Status |
|---------|------------------------|-----------------|-----------------|--------|
| Install from the DMG into Applications | — | — | 0.6.2 Session B (pending) | **Not seen** in 0.6.x: the sessions installed by script or in-app. 0.9.0's first-install pass (C16) |
| First launch: Open Anyway in Privacy & Security | — | — | 0.6.2 Session B (pending) | **Not seen** since 0.3.0 (ROADMAP Stage 1.1). 0.9.0, with fresh screenshots (C16) |

## Where BatteryPulse lives ([guide](USER_GUIDE.md#where-batterypulse-lives))

| Feature | 0.6.1 (RC session, A0) | 0.6.2 Session A | 0.6.2 Session B | Status |
|---------|------------------------|-----------------|-----------------|--------|
| Menu bar item and Dock icon, never hidden from both | F11-defaults y: with no settings, the menu bar shows the icon and the percentage | S7: 5 cold launches to the menu bar, p50 160 ms, one read before it | 0.6.2 Session B (pending) | **Partly.** Not seen: Show Dock icon, the Dock icon while a window is open, bringing the window back from the Dock |
| The menu bar item's switches: battery icon, percentage, battery power, temperature | F11-settings y: after a relaunch the switches match the item; F11-power y: with every window closed, the power value keeps changing | E20 field run (SPIKE-A2): power in the menu bar for 2 hours | 0.6.2 Session B (pending) | **Partly.** Not seen: the temperature switch, the icon standing in for text that has nothing to show |
| Icon styles and the drawn states (bolt, plug, red at 20 %, yellow in Low Power Mode) | V1d y: next to the system's battery item, in light and dark; V1c y: disabled Icon Style tiles are dimmed; V1a y: the chosen tile has an accent outline and no glass | V01-menubar y, a dark bar only (SPIKE-A2): crisp and aligned, the plug and 80 % | 0.6.2 Session B (pending) | **Partly.** A light bar: Session B. Each style next to the system item, Increase Contrast, Reduce Transparency and a notch: ROADMAP Stage 1.3 (`scripts/menu-bar-shots.sh`) |
| The menu bar popover | — | — | 0.6.2 Session B (pending) | **Not seen.** Session B opens it only for an energy run (S3), not to check what it shows |

## The main window ([guide](USER_GUIDE.md#the-main-window))

| Feature | 0.6.1 (RC session, A0) | 0.6.2 Session A | 0.6.2 Session B | Status |
|---------|------------------------|-----------------|-----------------|--------|
| Overview | F6 y: every page shows sensible values | Opened in step 8's page switches (SPIKE-A2) | 0.6.2 Session B (pending) | **Partly.** Its values against `bpulse --json` taken the same minute: Session B's F6 |
| Power | F6 y | Opened in step 8's page switches (SPIKE-A2) | 0.6.2 Session B (pending) | **Partly,** as Overview |
| Health | F6 y | Opened in step 8's page switches (SPIKE-A2) | 0.6.2 Session B (pending) | **Partly,** as Overview |
| Raw Data: decoded table, filter, source menu, copying rows, inspector, Copy JSON, Export Capture | F6-raw y: typing "volt", clearing it and opening the inspector work | V01-pages y (the maintainer, SPIKE-A2): Raw Data worked | 0.6.2 Session B (pending) | **Partly.** Not seen: the source menu as rebuilt after 0.6.1's session, copying rows, Copy JSON, Export Capture |
| Copy Report | — | — | 0.6.2 Session B (pending) | **Not seen** |
| Live values: every 2 s in a visible window, every 10 s with power in the menu bar, slower in Low Power Mode, under reduced resources or heat, none while hidden or while the displays sleep; one read a minute for history | F11-power y; `perf`: 501 of the app's 648 reads were polls, one read per burst of notifications but three, which had 2 | Energy window: app reads a minute 2.0 with no window (S1; about 1 expected), 6.0 and 6.2 with power in the menu bar (S2), 3.5 in Low Power Mode (S2-LPM; 2 expected); S6 not valid (the display came back on). E20 field run (SPIKE-A2, 2 hours): one read per burst but one. V01-lid y (SPIKE-A2): after a minute with the lid closed, the menu bar shows the current charge | 0.6.2 Session B (pending) | **Partly.** The displays asleep (S6), a covered window (S5), a minimized one, and the reads a minute: Session B's energy queue |
| Motion: Reduce Motion, hidden windows, Low Power Mode | — | — | 0.6.2 Session B (pending) | **Not seen** in 0.6.x: ROADMAP Stage 1.4's check (frame rate, Reduce Motion, Prefer Cross-Fade Transitions, Reduce Transparency, Increase Contrast, Show Borders) |
| Window Style: Standard and Frosted | V4-frosted-light and -dark y: the chart readout reads on Frosted; V4-materials y: Frosted's sidebar and toolbar; G12 y: the four styles approved; UR-3: no black frame while minimizing on Standard or Frosted, main and compact (Standard Light's y was most likely a polarity slip) | — | 0.6.2 Session B (pending) | **Partly.** Not seen: the readout on Standard since 0.6.1 put its material back (n in 0.6.1's session), a contrast audit. Each style's energy: Session B's S4w |
| Window Style: Translucent and Clear (beta), the Beta window styles switch, the fill while minimizing | V2 y: Clear readable over a white window, light and dark; G11 y; V4-materials y for Translucent; the readout n on both (0.6.1 put the material back); Clear turned black while minimizing (the maintainer's report), and both still didn't look right to him, so 0.6.1 made them beta styles | The minimize fill (SPIKE-A2's switch; the report's four crops): Clear Light and Clear Dark with the graphite fill 1, like the window; Translucent Dark with 0.6.1's fill 2, a black title bar, and with the graphite fill 1. 0.6.2 ships the graphite fill on Clear and Translucent Dark | 0.6.2 Session B (pending) | **Partly.** Not seen: the Beta window styles switch (added after 0.6.1's session), the release candidate's fill (Session B's optional 8 cases). Graduation evidence wasn't gathered, so both stay beta |
| Reduce Transparency or Increase Contrast give Standard | — | — | 0.6.2 Session B (pending) | **Not seen** |

## Compact window ([guide](USER_GUIDE.md#compact-window))

| Feature | 0.6.1 (RC session, A0) | 0.6.2 Session A | 0.6.2 Session B | Status |
|---------|------------------------|-----------------|-----------------|--------|
| Compact window: from the toolbar, Full Window, Window to open | UR-3-compact: opened and minimized in every style | — | 0.6.2 Session B (pending) | **Partly.** Not seen: its values, Full Window, Window to open: Compact window |

## History ([guide](USER_GUIDE.md#history))

| Feature | 0.6.1 (RC session, A0) | 0.6.2 Session A | 0.6.2 Session B | Status |
|---------|------------------------|-----------------|-----------------|--------|
| Recording: about once a minute, on plug changes, launch and wake markers | F11: a relaunch added exactly one sample; 24 reads for history when nothing else had read | E20 field run (SPIKE-A2): `history.record` ran 670 times in 2 hours | 0.6.2 Session B (pending) | **Partly.** Not seen: the wake marker, a gap after sleep |
| The History page: charts over 24 h and 7 days, shading and gaps, the hover readout, the period's figures, Battery Health | F6-history y: the last days of 0.6.0's data in 24 h and 7 d; V4: the readout readable only on Frosted, so 0.6.1 put 0.6.0's material back | V01-pages y (the maintainer, SPIKE-A2): History worked | 0.6.2 Session B (pending) | **Partly.** Not seen: the readout on its material in each style, the period's figures, the source menu |
| Clear History, recording off (Settings → Advanced) | — | V01-pages y (the maintainer, SPIKE-A2): Clear History worked | 0.6.2 Session B (pending) | **Partly.** Not seen: recording turned off |
| Exporting history: CSV and JSON, the region's separators ([guide](USER_GUIDE.md#exporting-history)) | — | — | 0.6.2 Session B (pending) | **Not seen.** A CSV opened in Numbers (ROADMAP Stage 6) left Session B's second attempt |

## iPhone and iPad ([guide](USER_GUIDE.md#iphone-and-ipad))

| Feature | 0.6.1 (RC session, A0) | 0.6.2 Session A | 0.6.2 Session B | Status |
|---------|------------------------|-----------------|-----------------|--------|
| Turning it on: the setting, MobileDevice loaded only when needed | — | F5 (reading on): "MobileDevice 1860.2.5.100.2 loaded" logged once the iPad was plugged in; F5-local-network 2: no Local Network prompt, only the device's Trust This Computer; no library-validation message naming BatteryPulse | 0.6.2 Session B (pending) | **Partly.** Not seen: Turn On in the sidebar, the setting off |
| Connecting by cable, the device page | — | F5-iphone 1: an iPad (9th generation, iPadOS 27.0.1) on a cable stood in for an iPhone; its page showed 100 %, charging at 4.0 W, 81 % maximum capacity, 141 cycles, Connected by cable (shot `f5-iphone-attached`) | 0.6.2 Session B (pending) | **Partly.** Not seen: an iPhone, Refresh, Show in History, Forget This Device, Copy Report |
| Unplugging, Wi-Fi, Try Again | — | F5-attach-detach n: after unplugging, a "didn't answer" banner over "Connected by cable", and a fresh read 17 s later still said "Connected by cable" while `bpulse --devices` listed the iPad over Wi-Fi. 0.6.2 fixes the label (WP-23, with Linux tests) | 0.6.2 Session B (pending) | **Not seen** working. WP-23's device check left Session B's second attempt; a later session |
| Device history | — | — | 0.6.2 Session B (pending) | **Not seen** |

## Accessories ([guide](USER_GUIDE.md#accessories))

| Feature | 0.6.1 (RC session, A0) | 0.6.2 Session A | 0.6.2 Session B | Status |
|---------|------------------------|-----------------|-----------------|--------|
| The Accessories page and the popover's list | F6 y: every page, Accessories included, shows sensible values | F5-accessories 1: AirPods Pro in three states, `bpulse --accessories` lists what `pmset -g accps` lists (a source build); the page opened in step 8's page switches (SPIKE-A2) | 0.6.2 Session B (pending) | **Partly.** Not seen: the page against `pmset`, the popover's list, a keyboard on Bluetooth and on its cable (none at hand) |

## Notifications ([guide](USER_GUIDE.md#notifications))

| Feature | 0.6.1 (RC session, A0) | 0.6.2 Session A | 0.6.2 Session B | Status |
|---------|------------------------|-----------------|-----------------|--------|
| When charged to, low battery, battery service, heat, accessories; Send Test Notification | F11-alert n, a pass once clarified in the session: the alert came at the 80 % step and its click opened the app | V01-notification y and V01-notification-front y (the maintainer, SPIKE-A2): the test notification arrived and its banner's click brought the window forward, also with the main window in front | 0.6.2 Session B (pending) | **Partly.** Not seen: low battery, service, heat and accessory alerts, a banner leaving Notification Center on a plug change |

## Widget ([guide](USER_GUIDE.md#widget))

| Feature | 0.6.1 (RC session, A0) | 0.6.2 Session A | 0.6.2 Session B | Status |
|---------|------------------------|-----------------|-----------------|--------|
| The small and medium widget: the gallery, its values, its refresh, kept across updates | F8 y: the widget shows the charge, its extension runs from /Applications; 22 reloads by policy and 5 after an update; A0: kept across the in-app update from 0.6.0, with the current charge | prep-widgets 1: a small and a medium widget with values (shot `widgets-ref`); W0-2-reinstall 1: every widget showed after 0.6.1 replaced a spike build; W0-5: VoiceOver reads 9 separate items and the battery symbol by its SF Symbol name, and a larger Text size changes nothing; E20 (SPIKE-A2): 8 reloads by policy, 1 after an update | 0.6.2 Session B (pending) | **Partly.** Not seen: adding it from the gallery after a DMG install, whether a DMG replacement still removes it (0.7's Session R). VoiceOver labels: 0.7 |

## Demo Mode ([guide](USER_GUIDE.md#demo-mode))

| Feature | 0.6.1 (RC session, A0) | 0.6.2 Session A | 0.6.2 Session B | Status |
|---------|------------------------|-----------------|-----------------|--------|
| Demo Mode: tour, scenes, animations, the demo bar, the menu bar's demo symbol | F6-demo y: played for 20 s, the menu bar icon followed, no notification | V01-pages y (the maintainer, SPIKE-A2): Demo Mode on and off | 0.6.2 Session B (pending) | **Partly.** Not seen: Start Tour, each scene and animation, Copy Report unavailable during the demo |

## Settings ([guide](USER_GUIDE.md#settings))

| Feature | 0.6.1 (RC session, A0) | 0.6.2 Session A | 0.6.2 Session B | Status |
|---------|------------------------|-----------------|-----------------|--------|
| The panes: General, Menu Bar, Notifications, Advanced | V1a and V1c y: the tile pickers; F11-settings y: every setting kept across a relaunch | — | 0.6.2 Session B (pending) | **Partly.** Not seen: each pane's controls one by one |
| Open at login | F11-login n, a pass once clarified in the session: turning it off worked; A0: kept its state across the in-app update | prep-open-at-login 1: on | 0.6.2 Session B (pending) | **Partly.** Turning it off on the release candidate: Session B's F11 |
| Update check: the schedule, Check for Updates…, the window, Remind Me Later, Skip This Version ([guide](USER_GUIDE.md#updates)) | F12-window y on the second try: the window offered 0.6.0 with rendered notes and a link that opened in the browser; the first try met GitHub's request limit and said so; no HTTP cache files written | V01-pages y (the maintainer, SPIKE-A2): Check Now, the offered update closed | 0.6.2 Session B (pending) | **Partly.** Not seen: the automatic schedule, Low Data Mode and expensive networks, Remind Me Later, Skip This Version, the popover's Update available |
| Install and Relaunch | G22 y on the second try: build B installed the published 0.6.0 and relaunched it, and the selection survived the download; A0: the published 0.6.1 from 0.6.0, the widget and Open at login kept | Attach timing on the published 0.6.1 DMG: `hdiutil attach` median 152 ms, `diskutil image attach` 292 ms, with no option to skip verification | 0.6.2 Session B (pending) | **Partly.** The release candidate's `diskutil` installer: Session B's F12. The refusals (no signature, a failed check) only in Linux tests. The upgrade matrix: 0.9.x (C7) |
| Download: the DMG in the browser | — | — | 0.6.2 Session B (pending) | **Not seen** |
| What's New | — | — | 0.6.2 Session B (pending) | **Not seen** in 0.6.x, whose fix releases keep 0.6.0's list |
| About BatteryPulse | — | — | 0.6.2 Session B (pending) | **Not seen** |

## Language ([guide](USER_GUIDE.md#language))

| Feature | 0.6.1 (RC session, A0) | 0.6.2 Session A | 0.6.2 Session B | Status |
|---------|------------------------|-----------------|-----------------|--------|
| Russian | — (its F9 step didn't run) | Only a spike build's widget, under the extension's language (W0-2-W-ru) | 0.6.2 Session B (pending) | **Not seen** in a shipping build. Session B: F9 (Overview, Settings, the update warning) and F8's Russian half. Every screen: 0.9.0's screenshot set (C11) |

## Understanding the numbers ([guide](USER_GUIDE.md#understanding-the-numbers))

| Feature | 0.6.1 (RC session, A0) | 0.6.2 Session A | 0.6.2 Session B | Status |
|---------|------------------------|-----------------|-----------------|--------|
| Charge and gauge, maximum capacity, cycles, time remaining, power from the SMC, temperature, cell voltages and spread, requested charge | F6 y: every page shows sensible values | — | 0.6.2 Session B (pending) | **Partly.** Session B's F6 reads each page against `bpulse --json` taken the same minute |

## Command-line report ([guide](USER_GUIDE.md#command-line-report))

Built from source in Session A's prepare step; `bpulse` isn't in the DMG before 0.9.0.

| Feature | 0.6.1 (RC session, A0) | 0.6.2 Session A | 0.6.2 Session B | Status |
|---------|------------------------|-----------------|-----------------|--------|
| The report, `--raw`, `--smc` | — | `--raw` captures while the Charge Limit held the charge (one committed with the report, redacted); `--smc` listed 43 `CH*` keys | 0.6.2 Session B (pending) | **Partly** (a source build) |
| `--record` | — | — | 0.6.2 Session B (pending) | **Not seen** |
| `--export` | — | — | 0.6.2 Session B (pending) | **Not seen** |
| `--devices`, `--device <n>` | — | F5: `--devices` listed the iPad over Wi-Fi a minute after unplugging; MobileDevice loaded in `bpulse` too | 0.6.2 Session B (pending) | **Partly** (a source build). Not seen: `--device <n>` |
| `--accessories` | — | F5-accessories 1: AirPods Pro in three states, the same parts and levels as `pmset -g accps` | 0.6.2 Session B (pending) | **Partly** (a source build). Not seen: `--json`, `--raw`, `--input` of a saved capture |

## Reporting a problem ([guide](USER_GUIDE.md#reporting-a-problem))

| Feature | 0.6.1 (RC session, A0) | 0.6.2 Session A | 0.6.2 Session B | Status |
|---------|------------------------|-----------------|-----------------|--------|
| Export Capture… and the bug report form | — | — | 0.6.2 Session B (pending) | **Not seen** |
