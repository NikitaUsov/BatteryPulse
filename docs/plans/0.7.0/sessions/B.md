# Session B results (BatteryPulse 0.6.2)

Written by `docs/plans/0.6.2/m5-session.sh send` on 2026-10-30 17:13 +0300. Session B ran hands-free
(PLAN.md §6): answers marked "claude" were judged by the Claude session from the pictures, beside the
script's pixel measurement where one exists; "person" ones came from the maintainer. Recordings,
full-desktop shots and logs stay on the Mac (`~/bp-062/B`).

## Appendix C rows this session owns

| Fact (PLAN.md Appendix C) | Where in this file |
|---|---|
| C energy: S1, S2, S2 Low Power Mode, S4w, S5, S10, S3, the minimized run, S6 (B and C, medians, C ÷ B, the chain to A, B against Session A's B) | The energy queue |
| S7 launches on B and C | S7 |
| S8, the burst: reads per notify burst, widget reloads per cycle; P12 | S8: the burst; Proofs |
| Memory: History → 7 days three times | Memory |
| Session B's runs marked not valid, per run, and their retries; whether a session acted while queue.started existed | The energy queue (the detector columns); Notes |
| Sleep hygiene: pmset -g assertions per run; the night's DarkWake and wake lines | The energy queue (Assertions); The night |
| The overnight log stream (plan-0.7.0 §6.2 step 12) | The night |
| Session B's preflight: each proof's result and its fallback; the prompts met; Accessibility allowed again or not | Preflight; Proofs |
| V-01 on the RC: executor lines, crash reports, the answers | V-01 on the RC; Answers |
| G-13a: the 8 glass-sheet cases (optional) | The glass-sheet cases; fill-* answers |
| G-13b: not in Session B since its first attempt; both styles stay beta (PLAN.md §7.1) | - |
| G-16: F12 and its update log, the pre-swap extension end (WP-16 item 6), the eject-failure lines, Finder's windows during the install, widget processes from before the swap, the 1-4 answer | F12; Answers (F12-widget) |
| G-14b: `read cached` p50 and `registry.missed` per hour of logged runtime | The energy queue (the G-14b line) |
| F6, F8 (G-15), F9, F11 | Answers (F6-*, F8-*, F9-*, F11-*); F11 |
| WP-17's after: page.switch per page | Page switches |
| WP-18: SUI-17's previews, SUI-19's 5 slowest bodies, SZ-10's icon and his answer | WP-18: SUI-19's type-check timing; Answers (SUI-17, SZ-10) |
| The hands-free mode's cost: his minutes per moment, the GUI phase's length, the steps not checked or not run | Timeline; Not checked or not run; Notes |
| WP-23's optional device check (Connected over Wi-Fi, then Not connected) | Notes (when it ran) |

## Timeline

- prepare (B0a): 2026-10-30 12:10:26
- mark away (the GUI phase begins): 2026-10-30 12:30:38
- restore gui (B3): 2026-10-30 13:21:41
- ready: ready 2026-10-30 13:22:37
- the queue's end: 2026-10-30 15:55:10
- continue (B7): 2026-10-30 17:04:10

## Answers

| ID | Question | Answer | By | Time | Note |
|---|---|---|---|---|---|
| B-yes | The list of changes and the start (PLAN.md §6, the yes-list): y = go ahead | y | person | 12:10 |  |
| B-keep-ax | Keep Terminal's Accessibility until Session R: y = keep (default: revoked in the morning) | y | person | 12:10 |  |
| B-usage | What /usage showed at the start | he did not paste /usage; his word: plenty of usage left | person | 12:10 |  |
| prep-charge-limit | The Charge Limit (pmset -g battlimit, else the Battery pane's shot), in % | 100 | claude | 12:18 | the Battery pane's Charging sheet read by computer use at 12:18 shows Charge Limit 100% (your Mac will charge to 100% limit); pmset showed none |
| prep-widget-style | System Settings → Appearance → Icon & widget style in prepare's shot: Default, Dark, Clear or Tinted | Default | claude | 12:18 | settings-appearance shows Icon & widget style: Default selected |
| prep-dim-widgets | System Settings → Desktop & Dock → Dim widgets on desktop in prepare's shot | Automatically | claude | 12:18 | Desktop & Dock scrolled to Widgets by computer use at 12:17 shows Dim widgets on desktop: Automatically (cut off in settings-desktop) |
| prep-open-at-login | Open at login (BatteryPulse's own toggle, read by AX): 1 on, 2 off | 1 | claude | 12:18 | the AX read was unknown; the RC's Settings General tab seen by computer use at 12:18 shows Open at login switched on |
| prep-widgets | Are a small and a medium BatteryPulse widget on the desktop, with nothing covering them? 1 yes, 2 no | 1 | claude | 12:18 | prepare-desktop shows a small BatteryPulse widget at the second row and a medium one at the top row, no widget over them; only the RC's open Settings window overlaps the medium one's right edge |
| prep-wallpaper-kind | His wallpaper in prepare's shot: 1 a still picture, 2 a dynamic one, 3 an aerial (restore by computer use from that shot) | 3 | claude | 12:18 | prepare-desktop shows the Golden Gate sunset, the Landscape aerial the first attempt restored; script read dynamic or aerial |
| P3-capture | On Clear, -l against -R: 1 -l keeps what lies behind the glass sheet (the same picture), 2 -l leaves it out | 2 | claude | 12:24 |  |
| P4-frames | AXMinimized at normal speed, every frame, against Session A's case: 1 enough frames to judge the fill, 2 too few, 3 something else (note) | 1 | claude | 12:29 | the measure's darkest frame 2 (luma 0.109, 54.9 % dark) is a pre-animation frame of the Clear Dark window over the dark wallpaper part; the genie frames on the sheet are an even graphite grey, enough to judge the fill |
| V01-notification | The test notification's banner came, and its press brought BatteryPulse forward | y | claude | 12:29 | the banner was found after 398 ms and pressed; BatteryPulse was the front window afterwards |
| V01-notification-front | And again with the BatteryPulse window in front | y | claude | 12:29 | with the window in front the banner was found after 397 ms and pressed; BatteryPulse was the front window afterwards; the script warned the Notifications pane didn't select |
| V01-menubar | The menu bar item looks right on a light and on a dark menu bar (the crops) | unsure | claude | 12:31 | for the morning batch: claude read y; v01 menubar failed: no menu bar item in CGWindowList (P11); the crop v01-menubar-light shows the item as a charging battery and 99% legible and unclipped on the current blue bar; the dark bar and the pixel diff were not checked |
| V01-pages | Raw Data, History, Demo Mode on and off, Check Now (its offer closed by its own button) and Clear History, by AX: each worked | y | claude | 13:14 | v01-raw, v01-history-2, v01-demo-on (Low battery scene, 17%, menu bar too), v01-demo-off (99% again), v01-checknow (offer closed by Remind Me Later), v01-history-cleared (empty charts) each did what it says; the scene row and the alert's Clear History took a ui click by position since AXPress failed on them; History showed Raw Data's table for a few seconds after the switch (noted) |
| V01-lid | After his 1-minute lid close: BatteryPulse runs with a current value in the menu bar (the after-lid shot) | y | claude | 17:04 | after-lid shot: the BatteryPulse item shows 93 percent in the menu bar, matching the battery at 17:04; both widgets show 93 percent On battery |
| F11-alert | The charge alert: 1 its banner appeared, 2 no banner in time, 3 not run | 1 | claude | 12:29 | with the alert step at 95 % and the charge at 98 %, the unplug banner was found after 4923 ms and pressed |
| F11-login | Login Items after Open at login off: 1 gone, 2 still listed | 1 | claude | 12:40 | f11 listed found no BatteryPulse in Login Items; f11-login-items shows the Open at Login list empty after Open at login was turned off (f11-login-off-row) |
| F6-overview | F6, overview on real data, against bpulse --json of the same minute: right | y | claude | 12:34 | f6-overview against f6-overview.json: charge 99, remaining 5497, full 5553, design 5760 mAh, cycles 52, charging 10.8 W (809 mA x 13.348 V), Mac 5.4 W (5432 mW), adapter 16.5 W (16537 mW), full in 7 min, max capacity 99 (nominal 5697 of 5760) |
| F6-power | F6, power on real data, against bpulse --json of the same minute: right | y | claude | 12:34 | f6-power against f6-power.json: charging, full in 7 min, 13.35 V, current 801 vs 808 mA and +10.7 W within the minute's change, 30.1 C (30.09), requested 831 mA and 4.47 V per cell, adapter name, Apple Inc., 60 W, 20 V x 2.99 A, the four PD profiles with 20 V checked (index 3) |
| F6-history | F6, history on real data, against bpulse --json of the same minute: right | y | claude | 12:34 | f6-history against f6-history.json: the charts' right edge at 12:34 shows charge near 99 (json 99), temperature near 30 C (30.09) and battery power about +10 W (785 mA x 13.348 V = 10.5 W), on the adapter; the summary tiles are below the fold |
| F6-health | F6, health on real data, against bpulse --json of the same minute: right | y | claude | 12:34 | f6-health against f6-health.json: max capacity 99 (5697 of 5760), Normal, 52 of 1,000, 5 % used, design 5760, nominal 5697, full 5553, remaining 5497 mAh, cells 4.449, 4.449, 4.450 V, spread 1 mV |
| F6-raw | F6, raw on real data, against bpulse --json of the same minute: right | y | claude | 12:35 | f6-raw against f6-raw.json: adapter ID 0x701E, 20 V, 2990 mA, pd charger, Apple Inc., the four PD profiles (2960/5000, 2970/9000, 2980/15000, 2990/20000), 60 W, serial REDACTED; Amperage 777 mA (json instant 777, average 757 a few seconds later) |
| F8-small-en | F8, the RC's small widget in en, after the desktop click: 1 right, 2 blank or grey, 3 gone, 4 different (note) | unsure | claude | 12:36 | for the morning batch: claude read 1; f8-small-en shows 99%, Charging, Full at 12:42 in English, matching the Mac; the desktop click before it was refused on both takes (spot under the main window, then a Claude app notification banner's layer-23 window), so not after the click |
| F8-medium-en | F8, the RC's medium widget in en, after the desktop click: 1 right, 2 blank or grey, 3 gone, 4 different (note) | unsure | claude | 12:36 | for the morning batch: claude read 1; f8-medium-en shows 99%, Charging, Full at 12:42, max capacity 99%, 52 cycles, 30.2 C in English, matching the Mac; the desktop click before it was refused on both takes, so not after the click |
| F8-small-ru | F8, the RC's small widget in ru, after the desktop click: 1 right, 2 blank or grey, 3 gone, 4 different (note) | unsure | claude | 12:36 | for the morning batch: claude read 4; f8-small-ru after the desktop click shows 99%, Charging, Full at 12:42 in English, not Russian; the same text as the en crop, so the widget likely did not re-render after f8 ru on |
| F8-medium-ru | F8, the RC's medium widget in ru, after the desktop click: 1 right, 2 blank or grey, 3 gone, 4 different (note) | unsure | claude | 12:36 | for the morning batch: claude read 4; f8-medium-ru after the desktop click shows Charging, Full at 12:42, Maximum capacity, Cycle count, Temperature in English, not Russian; the same as the en crop, so likely no re-render after f8 ru on |
| F9-overview | F9 in Russian, overview: no truncation, no English left, the catalog's terms | y | claude | 12:38 | f9-overview: Russian throughout but the names iPhone, iPad and Mac; no truncation or overlap (Maximum Capacity's label wraps with a hyphen inside its ring); the catalog's terms for Charge, Maximum Capacity, Cycle Count and Normal; finding: numbers keep the English format (5,497, 1,000, 99.0 %, 8.7 W) in the Russian UI |
| F9-settings | F9 in Russian, settings: no truncation, no English left, the catalog's terms | y | claude | 12:38 | f9-settings-window: General fully Russian but the names Dock, BatteryPulse, GitHub, IP, iPhone, iPad, Mac, Wi-Fi; no truncation or overlap; the tabs General, Menu Bar, Notifications and Advanced in the catalog's terms; the four styles with the Beta badges |
| F9-update | F9 in Russian, update: no truncation, no English left, the catalog's terms | y | claude | 12:39 | f9-update: the title (the catalog's Software Update), heading, version line, footnote and the four buttons in Russian, no truncation or overlap; only the release notes from GitHub are English, which they are by design |
| F12-widget | After Install and Relaunch, the widget against the before shot: 1 same, 2 blank or grey, 3 gone, 4 different (note) | 1 | claude | 13:12 | after-small and after-medium match the before shots in layout and state (100%, Charging, 99%, 52) with fresh values (Full at 13:29 to 13:31, 38.9 to 38.2 C), so the widget reloaded after the swap; the What's New window covers the medium widget's bottom-right corner in after-medium |
| fill-translucent-light-main | translucent-light-main: while it shrank into the Dock and came back: 1 like the window, or an even graphite grey (the chosen fill), 2 a black frame or rectangle, 3 something else (note) | 1 | claude | 13:15 | minimize and restore sheets show the light window in every genie frame, no black frame or rectangle; darkest frame luma 0.969, 0.0 % dark; darkest-1 is the plain light window |
| fill-translucent-dark-main | translucent-dark-main: while it shrank into the Dock and came back: 1 like the window, or an even graphite grey (the chosen fill), 2 a black frame or rectangle, 3 something else (note) | 1 | claude | 13:17 | the window rests a mid grey (darkest-1, luma 0.418) and in every genie frame of both sheets turns an even graphite grey with its content visible (crop fill-tdm-genie), no black frame or rectangle; measure suggests 1 |
| fill-clear-light-main | clear-light-main: while it shrank into the Dock and came back: 1 like the window, or an even graphite grey (the chosen fill), 2 a black frame or rectangle, 3 something else (note) | 1 | claude | 13:18 | during the genie the content area turns an even graphite grey and the sidebar keeps its lighter grey (crop fill-clm-genie), the window's own layout; no black frame or rectangle in either sheet; darkest frame luma 0.459, 0.0 % dark; measure suggests 1 |
| fill-clear-dark-main | clear-dark-main: while it shrank into the Dock and came back: 1 like the window, or an even graphite grey (the chosen fill), 2 a black frame or rectangle, 3 something else (note) | 1 | claude | 13:20 | the window rests a dark grey (frame-0034, luma 0.304) and in every genie frame of both sheets turns an even graphite grey with its rings and text visible, no black frame or rectangle |
| fill-translucent-light-compact | translucent-light-compact: while it shrank into the Dock and came back: 1 like the window, or an even graphite grey (the chosen fill), 2 a black frame or rectangle, 3 something else (note) | 1 | claude | 13:16 | minimize and restore sheets show the light compact window in every genie frame, no black frame or rectangle; darkest frame luma 0.961, 0.0 % dark |
| fill-translucent-dark-compact | translucent-dark-compact: while it shrank into the Dock and came back: 1 like the window, or an even graphite grey (the chosen fill), 2 a black frame or rectangle, 3 something else (note) | 1 | claude | 13:18 | the compact window rests a light grey (luma 0.627) and in every genie frame of both sheets turns an even graphite grey with its content visible, no black frame or rectangle |
| fill-clear-light-compact | clear-light-compact: while it shrank into the Dock and came back: 1 like the window, or an even graphite grey (the chosen fill), 2 a black frame or rectangle, 3 something else (note) | 1 | claude | 13:19 | the compact window rests a mid grey and in every genie frame of both sheets turns an even graphite grey with its content visible; restore's darkest-1 (frame-0091, luma 0.261, 0.0 % dark) is that graphite window, no black frame or rectangle |
| fill-clear-dark-compact | clear-dark-compact: while it shrank into the Dock and came back: 1 like the window, or an even graphite grey (the chosen fill), 2 a black frame or rectangle, 3 something else (note) | 1 | claude | 13:21 | the compact window rests a mid grey (luma 0.463) and in every genie frame of both sheets turns an even graphite grey with its content visible, no black frame or rectangle |
| B-send | Send B.md and the attached images to claude/062-session-b, after the contact sheet and the summary: y = send | y | person | 17:13 | his word: send it; he did not open the shots |

## Proofs

| Proof | Result | Detail | Fallback | Time |
|---|---|---|---|---|
| P1 | pass | the widget's host is NotificationCenter (com.apple.notificationcenterui), with a BatteryPulse label in its chain (logs/p1-hit.txt) | - | 2026-10-30 12:19:08 |
| P7 | pass | wallpaper by System Events: read; com.apple.WindowManager: read; style-like keys in defaults -g: 3; AppleICUForce24HourTime: 1 | a dynamic or aerial wallpaper by computer use from prepare's shot; an unread setting is unknown | 2026-10-30 12:19:34 |
| P8 | fail | its own pane per URL: appearance=no (sidebar unread); desktop=no (sidebar unread); displays=no (sidebar unread); accessibility=yes (sidebar unread); login-items=yes (sidebar unread); battery=yes (sidebar unread); date-time=yes (sidebar unread); wallpaper=yes (sidebar unread);  | computer use from System Settings' sidebar for: appearance desktop displays accessibility login-items battery date-time wallpaper (ui doesn't act there) | 2026-10-30 12:19:52 |
| P9 | pass | a 2-second xctrace recording ran (Developer mode is currently disabled.) | - | 2026-10-30 12:20:00 |
| P2 | pass | banner found after 94 ms: AXGroup/AXNotificationCenterBanner | - | 2026-10-30 12:20:01 |
| P6 | fail | HIDIdleTime: a HID-tap move resets it, a session-tap move resets it, caffeinate -u keeps it; .hidSystemState ignores posted events: yes; ui posts at the hid tap | the session ends its turn before the queue; during B2 only his Esc says he is there | 2026-10-30 12:20:19 |
| P11 | fail | no menu bar item window in CGWindowList | S3 stays open in Stage 1.4 | 2026-10-30 12:20:19 |
| quiet | pass | HIDIdleTime grew from 11.0 to 162.4 s over 150 quiet seconds; no keep-awake holder at any of 15 reads | - | 2026-10-30 12:22:53 |
| P3 | fail | -l leaves out what lies behind the glass sheet | -R after the occlusion check for every style | 2026-10-30 12:24:24 |
| P4 | pass | AXMinimized: 180 frames, the animation about 0.37 s | P5's posted Shift | 2026-10-30 12:25:15 |
| P5 | fail | the posted Shift gave about 0.35 s | AXMinimized at normal speed with every frame (P4) | 2026-10-30 12:26:38 |
| P10 | pass | granted BatteryPulse, System Settings, Finder, TextEdit, Xcode (click tier); Notification Center can't be named in a request, so its gallery is hidden from computer-use shots, but clicks aimed from the script's shots worked: Edit Widgets from the desktop menu, the BatteryPulse row, click-to-add of a small widget (p10-added), its remove button (p10-removed), Done (p10-done); System Settings clicks (Battery, Charging info, Done) worked; no computer-use notification in the first screenshot; computer use leaves a 28x40 overlay window at its last click, which fails the occlusion check until a computer-use pointer move to bare desktop | - | 2026-10-30 12:28:32 |

## Not checked or not run

- 12:35 F8-en: no desktop spot
- 12:35 F8-large-en: no frame recorded for the large widget
- 12:35 F8-xlarge-en: no frame recorded for the xlarge widget
- 12:35 F8-en: no desktop spot
- 12:35 F8-large-en: no frame recorded for the large widget
- 12:35 F8-xlarge-en: no frame recorded for the xlarge widget
- 12:36 F8-large-ru: no frame recorded for the large widget
- 12:36 F8-xlarge-ru: no frame recorded for the xlarge widget
- 12:37 F9-overview: no shot

## Prepare (B0a)

- prepared: 2026-10-30 12:10:26; macOS 27.2 (26B123); the frozen script at f484e23
- installed before the session: 0.6.1 (7)
- defaults domain: 29 keys backed up
- Application Support: 12 files, 212 KB backed up
- Low Power Mode: battery 0, adapter 0
- charge: 88 %, on the adapter
- his bedtime: 16:10; the GUI phase stops at 16:00
- not in this attempt (PLAN.md §6, after the first attempt of 2026-10-27): G-13b's evidence (both styles stay beta), the burst (S8), memory, WP-23's device check, the optional extras and the morning-away block
- tools: ui built, frames built, bpulse built

| Build | Version | CFBundleVersion | Source |
|---|---|---|---|
| B | 0.6.1 | 7 | release v0.6.1 |
| C | 0.5.99 | 373 | run 40083655970, artifact BatteryPulse-0.5.99-042033d68739a0341197738ba8314254af8fc344 |
| CP | 0.5.99 | 373 | run 40083655970, artifact BatteryPulse-profiling-0.5.99-042033d68739a0341197738ba8314254af8fc344 |

## Prepare's reads (B0b)

- Charge Limit: pmset -g battlimit shows none (below the limit it may not; plan-0.7.0 Appendix C finding 9): read from the Battery pane
- click-to-show-desktop (EnableStandardClickToShowDesktop): unknown
- hot corners: tl=11 tr=12 bl=2 br=4 
- the screen saver's idle time: unknown s
- AppleICUForce24HourTime: 1
- the wallpaper: dynamic or aerial; 1 desktops (paths kept on the Mac)
- display: main=0 0 1710 1107 scale=2.0 displays=1
- generated wallpapers: bright and busy, 3420×2214
- Open at login (AX): unknown
- Focus: not readable (his word at the start)

## Preflight (B0b)

- access: ax_trusted=yes post_events=yes screen_capture=yes
- tell application targets: System Events and BatteryPulse only
- Apple Events: System Events answers; BatteryPulse answers
- the widget extension's container preferences: read
- pmset -g battlimit: No battery level limits set 
- Low Power Mode set for battery: 0
- hot corners: tl=11 tr=12 bl=2 br=4; the screen saver after unknown s
- a VPN active: no
- charge: 94 %, on the adapter
- screencapture -v: fps=28.8
- DevToolsSecurity: Developer mode is currently disabled.
- the widget extension's processes: pgrep -x BatteryPulseWidget finds 1, its path 1 (the script goes by the path)
- the main window's occlusion check: main window 227 at 231 102 1259 875: covered by another app (layer 2147483630)
- ui guard: guard: clear
- keep-awake assertions of other processes (user activity or display sleep): 0; system sleep only (no run changes): 0 (names stay on the Mac)

| Proof | Result | Detail | Fallback |
|---|---|---|---|
| P1 | pass | the widget's host is NotificationCenter (com.apple.notificationcenterui), with a BatteryPulse label in its chain (logs/p1-hit.txt) | - |
| P7 | pass | wallpaper by System Events: read; com.apple.WindowManager: read; style-like keys in defaults -g: 3; AppleICUForce24HourTime: 1 | a dynamic or aerial wallpaper by computer use from prepare's shot; an unread setting is unknown |
| P8 | fail | its own pane per URL: appearance=no (sidebar unread); desktop=no (sidebar unread); displays=no (sidebar unread); accessibility=yes (sidebar unread); login-items=yes (sidebar unread); battery=yes (sidebar unread); date-time=yes (sidebar unread); wallpaper=yes (sidebar unread);  | computer use from System Settings' sidebar for: appearance desktop displays accessibility login-items battery date-time wallpaper (ui doesn't act there) |
| P9 | pass | a 2-second xctrace recording ran (Developer mode is currently disabled.) | - |
| P2 | pass | banner found after 94 ms: AXGroup/AXNotificationCenterBanner | - |
| P6 | fail | HIDIdleTime: a HID-tap move resets it, a session-tap move resets it, caffeinate -u keeps it; .hidSystemState ignores posted events: yes; ui posts at the hid tap | the session ends its turn before the queue; during B2 only his Esc says he is there |
| P11 | fail | no menu bar item window in CGWindowList | S3 stays open in Stage 1.4 |
| quiet | pass | HIDIdleTime grew from 11.0 to 162.4 s over 150 quiet seconds; no keep-awake holder at any of 15 reads | - |

## V-01 on the RC (WP-10, WP-14a)

- V01-notification: banner found after 398 ms; pressed; front window afterwards: BatteryPulse
- V01-notification-front: banner found after 397 ms; pressed; front window afterwards: BatteryPulse
- B2's end (2026-10-30 13:14:03): "executor" log lines since prepare: 0
- crash reports since prepare:
- new crash reports: 0 (copies in logs/crash/)
- the morning: "executor" lines of the RC's processes: 0
- the RC's crash reports (build 373) since prepare: 0 (build B's runs don't count)

## The glass-sheet minimize and restore cases (WP-13, G-13a)

- translucent-light-main (ax, 3 s): minimize frame rate: 32.0 fps, 3420×2214, 2.98 s; darkest frame 0, luma 0.969, 0.0 % dark; restore darkest inside the rectangle 1: frame-0000 at 0.000 s, luma 0.974, 0.0 % dark pixels
- translucent-light-compact (ax, 3 s): minimize frame rate: 35.9 fps, 3420×2214, 3.00 s; darkest frame 0, luma 0.961, 0.0 % dark; restore darkest inside the rectangle 1: frame-0000 at 0.000 s, luma 0.965, 0.0 % dark pixels
- translucent-dark-main (ax, 3 s): minimize frame rate: 30.3 fps, 3420×2214, 2.98 s; darkest frame 0, luma 0.418, 0.0 % dark; restore darkest inside the rectangle 1: frame-0000 at 0.000 s, luma 0.973, 0.0 % dark pixels
- translucent-dark-compact (ax, 3 s): minimize frame rate: 34.4 fps, 3420×2214, 2.98 s; darkest frame 0, luma 0.627, 0.0 % dark; restore darkest inside the rectangle 1: frame-0000 at 0.000 s, luma 0.965, 0.0 % dark pixels
- clear-light-main (ax, 3 s): minimize frame rate: 35.1 fps, 3420×2214, 2.98 s; darkest frame 0, luma 0.459, 0.0 % dark; restore darkest inside the rectangle 1: frame-0000 at 0.000 s, luma 0.974, 0.0 % dark pixels
- clear-light-compact (ax, 3 s): minimize frame rate: 34.8 fps, 3420×2214, 2.98 s; darkest frame 0, luma 0.459, 0.0 % dark; restore darkest inside the rectangle 1: frame-0091 at 1.517 s, luma 0.261, 0.0 % dark pixels
- clear-dark-main (ax, 3 s): minimize frame rate: 31.8 fps, 3420×2214, 3.00 s; darkest frame 0, luma 0.304, 0.0 % dark; restore darkest inside the rectangle 1: frame-0000 at 0.000 s, luma 0.973, 0.0 % dark pixels
- clear-dark-compact (ax, 3 s): minimize frame rate: 30.5 fps, 3420×2214, 2.98 s; darkest frame 0, luma 0.463, 0.0 % dark; restore darkest inside the rectangle 1: frame-0000 at 0.000 s, luma 0.964, 0.0 % dark pixels

## F11: the charge alert and the login item

- F11-alert: step 95 % at 98 %: banner found after 4923 ms; pressed
- Login Items after Open at login off: match BatteryPulse: not found (0)

## F12: Install and Relaunch on the RC's installer (G-16)

- the unauthenticated requests left: 58; a VPN active: no
- before Install (2026-10-30 13:11:56): 0.5.99 (373); the widget extension running: yes
- after: 0.6.1 (7), running yes
- the update log's installer lines:
```
13:12:18.999 BatteryPulse Widget extension before the swap: 1 found, 1 ended by SIGTERM, 0 by SIGKILL, 0 still running, 55 ms
```
- the pre-swap extension end (WP-16 item 6): 1 found, 1 ended by SIGTERM, 0 by SIGKILL, 0 still running, 55 ms
- every extension process the installer found ended within 1,500 ms: yes (1 in 55 ms)
- BatteryPulseWidget processes now:  Fri Oct 30 13:12:21 2026    ; started before the swap (2026-10-30 13:12:18): no
- "isn't in diskutil info; it can't be ejected by force" or "Ejecting the update's disk image failed" lines: 0 (must be 0)
- Finder's on-screen windows during the install: 50 samples, at most 1, against 1 before (more means a window opened)

## Page switches on the RC (WP-17's after)

- 0.5.99 (373), 10 rounds of 7 pages, a page every 3 s, by CGEvent clicks at the sidebar rows' AX frames (0 by AX selection)
- page.switch lines per page: overview 9, power 10, history 10, health 10, accessories 10, developer 10, demo 10
```
intervals (ms)
name            trigger      count  p50     p95
page.switch     accessories  10     18.354  26.376
page.switch     demo         10     51.767  67.744
page.switch     developer    10     26.296  39.011
page.switch     health       10     40.704  43.340
page.switch     history      10     26.784  38.254
page.switch     overview     9      30.337  31.858
page.switch     power        10     46.009  52.552
page.switch     (all)        69     30.378  53.286
name  trigger  count
```

## Page switches under xctrace (the profiling RC)

- template: SwiftUI; trace: 2.0G (kept on the Mac)
- page.switch lines per page under the profiler: overview 9, power 10, history 10, health 10, accessories 10, developer 10, demo 10
```
intervals (ms)
name            trigger      count  p50     p95
page.switch     accessories  10     23.534  26.961
page.switch     demo         10     70.253  71.494
page.switch     developer    10     34.961  36.191
page.switch     health       10     57.387  60.942
page.switch     history      10     35.984  49.439
page.switch     overview     9      39.872  41.997
page.switch     power        10     64.843  81.321
page.switch     (all)        69     40.232  70.924
name           trigger  count
```

## WP-18: SUI-19's type-check timing

- the 5 slowest bodies (ms, file:line, the declaration):
```
```

## The energy queue (B4; WP-21)

- started 2026-10-30 13:42:07 at 100 %, on battery; the bedtime unplug at 13:30; no run starts after 16:30
- the Claude CLI's background CPU over the cooldown: 0.00735 s a second (the Claude detector allows that rate over a run, plus 2 s)
- pmset -g assertions at the start: 0 BatteryPulse lines (the full list stays on the Mac)
- keep-awake assertions of other processes at the start (user activity or display sleep): 0 (names stay on the Mac)
- over the cooldown: a keep-awake holder at 0 of 21 reads (names stay on the Mac); HIDIdleTime went back 0 times (an event: a touch, or a utility that posts input)
- the energy setup: his, at the arm window's bedtime prompt (the brightness about half by the keys, a Focus on), not read back; auto-brightness and True Tone as he keeps them

| # | Kind | Run | Build | Charge | Energy mJ/h | Idle wake-ups/h | Interrupt wake-ups/h | CPU s/h | Footprint MB | Reads/min | Assertions | Thermal | Pack temp | History KB | LPM | Touched | Slept | Adapter | Locked | Screen saver | Style | LPM valid | Claude | Status |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| 1 | warmup | S2 | C | 100→100 | 708.2 | 2100 | 4590 | 6.464 | 20.4 | 6.2 | 0 | nominal/nominal | 2889 | 12 | 0/0 | no | no | no | no | no | - | yes | no | warm-up, discarded (valid) |
| 2 | run | S2 | B | 100→100 | 884.1 | 2460 | 4290 | 7.516 | 20.1 | 6.2 | 0 | nominal/nominal | 2850 | 12 | 0/0 | no | no | no | no | no | - | yes | no | valid |
| 3 | run | S2 | C | 100→100 | 1043.0 | 2970 | 5115 | 7.123 | 20.3 | 6.5 | 0 | nominal/nominal | 2829 | 12 | 0/0 | no | no | no | no | no | - | yes | no | valid |
| 4 | run | S2 | B | 100→100 | 1847.7 | 3000 | 5370 | 9.069 | 20.2 | 6.5 | 0 | nominal/nominal | 2809 | 12 | 0/0 | no | no | no | no | no | - | yes | no | valid |
| 5 | run | S2 | C | 100→100 | 638.9 | 2385 | 4275 | 6.020 | 20.4 | 6.2 | 0 | nominal/nominal | 2789 | 12 | 0/0 | no | no | no | no | no | - | yes | no | valid |
| 6 | run | S2 | B | 100→100 | 1175.4 | 2055 | 4335 | 7.735 | 20.3 | 6.5 | 0 | nominal/nominal | 2769 | 12 | 0/0 | no | no | no | no | no | - | yes | no | valid |
| 7 | run | S2 | C | 100→100 | 1091.3 | 2715 | 4470 | 6.284 | 20.3 | 6.2 | 0 | nominal/nominal | 2759 | 16 | 0/0 | no | no | no | no | no | - | yes | yes | not valid: Claude active |
| 8 | run | S1 | B | 100→100 | 533.2 | 1275 | 2115 | 2.100 | 20.6 | 1.0 | 0 | nominal/nominal | 2759 | 16 | 0/0 | no | no | no | no | no | - | yes | no | valid |
| 9 | run | S1 | C | 100→100 | 137.4 | 1260 | 1770 | 1.288 | 20.7 | 1.0 | 0 | nominal/nominal | 2750 | 16 | 0/0 | no | no | no | no | no | - | yes | no | valid |
| 10 | run | S1 | B | 100→99 | 277.0 | 1365 | 2250 | 2.286 | 20.7 | 1.8 | 0 | nominal/nominal | 2739 | 16 | 0/0 | no | no | no | no | no | - | yes | no | valid |
| 11 | run | S1 | C | 99→99 | 230.0 | 1215 | 1995 | 2.088 | 20.8 | 1.8 | 0 | nominal/nominal | 2739 | 16 | 0/0 | no | no | no | no | no | - | yes | no | valid |
| 12 | run | S1 | B | 99→98 | 247.8 | 1170 | 2190 | 2.277 | 20.8 | 1.8 | 0 | nominal/nominal | 2739 | 16 | 0/0 | no | no | no | no | no | - | yes | no | valid |
| 13 | run | S1 | C | 98→98 | 136.6 | 1065 | 1770 | 1.333 | 20.8 | 1.0 | 0 | nominal/nominal | 2729 | 16 | 0/0 | no | no | no | no | no | - | yes | no | valid |
| 14 | run | S2-LPM | B | 98→97 | 441.6 | 1455 | 2400 | 3.663 | 21.4 | 3.5 | 0 | nominal/nominal | 2719 | 20 | 1/1 | no | no | no | no | no | - | yes | no | valid |
| 15 | run | S2-LPM | C | 97→97 | 455.3 | 1365 | 2505 | 3.388 | 21.3 | 3.0 | 0 | nominal/nominal | 2719 | 20 | 1/1 | no | no | no | no | no | - | yes | no | valid |
| 16 | run | S4w-standard | C | 97→96 | 4248.4 | 6690 | 12914 | 35.010 | 50.8 | 28.5 | 0 | nominal/nominal | 2719 | 20 | 0/0 | no | no | no | no | no | no | yes | no | valid |
| 17 | run | S4w-clear | C | 96→96 | 4736.6 | 7680 | 12704 | 32.506 | 48.8 | 28.2 | 0 | nominal/nominal | 2719 | 20 | 0/0 | no | no | no | no | no | no | yes | no | not valid: the window wasn't clear at the end |
| 18 | run | S4w-translucent | C | 96→ |  |  |  |  |  |  |  |  |  |  |  |  |  |  |  |  |  |  |  | not run: setup: the window isn't clear: main window 599 at 690 140 960 870: covered by NotificationCenter (layer 23) |
| 19 | run | S4w-standard2 | C | 96→ |  |  |  |  |  |  |  |  |  |  |  |  |  |  |  |  |  |  |  | not run: setup: the window isn't clear: main window 605 at 690 140 960 870: covered by NotificationCenter (layer 23) |
| 20 | run | S4w-frosted | C | 96→ |  |  |  |  |  |  |  |  |  |  |  |  |  |  |  |  |  |  |  | not run: setup: the window isn't clear: main window 611 at 690 140 960 870: covered by NotificationCenter (layer 23) |
| 21 | run | S5 | C | 96→ |  |  |  |  |  |  |  |  |  |  |  |  |  |  |  |  |  |  |  | not run: setup: the window isn't clear: main window 613 at 690 140 960 870: covered by NotificationCenter (layer 23) |
| 22 | run | S10 | C | 96→95 | 574.7 | 1230 | 2445 | 3.202 | 21.4 | 2.2 | 0 | nominal/nominal | 2739 | 20 | 0/0 | no | no | no | no | no | - | yes | no | valid |
| 23 | run | S3 | C | 95→ |  |  |  |  |  |  |  |  |  |  |  |  |  |  |  |  |  |  |  | not run: setup: no menu bar item window |
| 24 | run | MIN | C | 95→ |  |  |  |  |  |  |  |  |  |  |  |  |  |  |  |  |  |  |  | not run: setup: the window isn't clear: main window 619 at 690 140 960 870: covered by NotificationCenter (layer 23) |
| 25 | retry | S2 | B | 95→95 | 1386.9 | 2490 | 4635 | 7.905 | 20.4 | 6.2 | 0 | nominal/nominal | 2739 | 24 | 0/0 | yes | no | no | no | no | - | yes | no | not valid: touched |
| 26 | retry | S2 | C | 95→94 | 905.5 | 2670 | 4650 | 6.127 | 20.4 | 6.2 | 0 | nominal/nominal | 2729 | 24 | 0/0 | no | no | no | no | no | - | yes | no | valid |
| 27 | retry | S4w-clear | C | 94→93 | 4335.8 | 6615 | 12539 | 31.437 | 49.1 | 27.2 | 0 | nominal/nominal | 2729 | 24 | 0/0 | no | no | no | no | no | no | yes | no | valid |
| 28 | run | S6 | B | 93→93 | 258.0 | 696 | 2082 | 2.171 | 21.0 | 2.0 | 0 | nominal/nominal | 2669 | 24 | 0/0 | no | no | no | no | no | - | yes | no | valid |
| 29 | run | S6 | C | 93→93 | 266.5 | 564 | 2142 | 2.123 | 21.2 | 1.9 | 0 | nominal/nominal | 2629 | 28 | 0/0 | no | no | no | no | no | - | yes | no | valid |

Medians of the valid runs per scenario and build, a valid run whose thermal state wasn't nominal among them (its row says so; the spread is the lowest and highest run):

| Scenario | Build | Valid runs | Energy mJ/h (spread) | Idle wake-ups/h | Interrupt wake-ups/h | CPU s/h (spread) | Reads/min | C ÷ B energy | C ÷ B CPU | B here ÷ B in Session A (energy, CPU) | C ÷ A energy, CPU (C ÷ B × B ÷ A) |
|---|---|---|---|---|---|---|---|---|---|---|---|
| S2 | B | 3 | 1175.4 (884.1-1847.7) | 2460 | 4335 | 7.735 (7.516-9.069) | 6.5 | - | - | - | - |
| S2 | C | 3 | 905.5 (638.9-1043) | 2670 | 4650 | 6.127 (6.02-7.123) | 6.2 | 0.77 | 0.79 | - | - |
| S1 | B | 3 | 277.0 (247.8-533.2) | 1275 | 2190 | 2.277 (2.1-2.286) | 1.8 | - | - | - | - |
| S1 | C | 3 | 137.4 (136.6-230) | 1215 | 1770 | 1.333 (1.288-2.088) | 1.0 | 0.50 | 0.59 | - | - |
| S2-LPM | B | 1 | 441.6 (441.6-441.6) | 1455 | 2400 | 3.663 (3.663-3.663) | 3.5 | - | - | - | - |
| S2-LPM | C | 1 | 455.3 (455.3-455.3) | 1365 | 2505 | 3.388 (3.388-3.388) | 3.0 | 1.03 | 0.92 | - | - |
| S4w-standard | C | 1 | 4248.4 (4248.4-4248.4) | 6690 | 12914 | 35.010 (35.01-35.01) | 28.5 | - | - | - | - |
| S10 | C | 1 | 574.7 (574.7-574.7) | 1230 | 2445 | 3.202 (3.202-3.202) | 2.2 | - | - | - | - |
| S4w-clear | C | 1 | 4335.8 (4335.8-4335.8) | 6615 | 12539 | 31.437 (31.437-31.437) | 27.2 | - | - | - | - |
| S6 | B | 1 | 258.0 (258-258) | 696 | 2082 | 2.171 (2.171-2.171) | 2.0 | - | - | - | - |
| S6 | C | 1 | 266.5 (266.5-266.5) | 564 | 2142 | 2.123 (2.123-2.123) | 1.9 | 1.03 | 0.98 | - | - |

- G-14b over the C runs' perf lines (62 minutes measured): read cached p50 0.971 ms over 409 reads; registry.missed 0, 0.0 an hour (the criteria: p50 under 2 ms, at most 1 an hour)
```
intervals (ms)
name            trigger      count  p50    p95
read            cached       409    0.971  1.114
read            cached.slow  32     3.172  3.855
read            full         24     9.303  9.675
read            live         52     6.549  7.046
read            (all)        517    0.995  7.046
events
name  trigger  count
```

## S7, cold launches to menuBarReady (B against C)

### S7 B
- launch 1: 167 ms from open to menuBarReady
- launch 2: 166 ms from open to menuBarReady
- launch 3: 159 ms from open to menuBarReady
- launch 4: 163 ms from open to menuBarReady
- launch 5: 157 ms from open to menuBarReady
```
processes
pid    image               reads  reads before menuBarReady  widget reloads  reads per notify burst
63702  BatteryPulseWidget  2      -                          0               -
63767  BatteryPulse        1      1                          0               -
63792  BatteryPulse        1      1                          0               -
63816  BatteryPulse        1      1                          0               -
63890  BatteryPulse        1      1                          0               -
63912  BatteryPulse        1      1                          0               -
```
### S7 C
- launch 1: 166 ms from open to menuBarReady
- launch 2: 164 ms from open to menuBarReady
- launch 3: 165 ms from open to menuBarReady
- launch 4: 157 ms from open to menuBarReady
- launch 5: 159 ms from open to menuBarReady
```
processes
pid    image               reads  reads before menuBarReady  widget reloads  reads per notify burst
64146  BatteryPulseWidget  2      -                          0               -
64208  BatteryPulse        1      1                          0               -
64235  BatteryPulse        1      1                          0               -
64262  BatteryPulse        1      1                          0               -
64343  BatteryPulse        1      1                          0               -
64368  BatteryPulse        1      1                          0               -
```

## pslog, notifyutil and the ioreg sampler (F13, E3b, mAh cadence)

- lines read: notify.txt (notify.txt: 281 lines, pslog.txt: 560), each stamped through a pseudo-terminal when it was written
- samples: 786; adapter: unknown
- lines by notification key ("other" is pmset's own text):
```
any 137
percent 7
timeremaining 137
```
```
battery: 2.21 h sampled; UpdateTime changes 136, with an "any" line since the sample before 136 (F13)
battery: timeremaining lines 137; an "any" within 10 ms after 137, within 10 ms either side 137 (E3b)
battery: RemainingCapacity changes 123, 55.5 an hour
charging: 0.00 h sampled; UpdateTime changes 0, with an "any" line since the sample before 0 (F13)
charging: timeremaining lines 0; an "any" within 10 ms after 0, within 10 ms either side 0 (E3b)
```
- the first lines of each, to show what they name:
```
1793356945.0398819447 com.apple.system.powersources.timeremaining
1793356945.0401020050 com.apple.system.powersources
1793357005.0333940983 com.apple.system.powersources.timeremaining
1793357005.0341110229 com.apple.system.powersources
1793357065.0363779068 com.apple.system.powersources.timeremaining
1793356927.4223220348 Logging IORegisterForSystemPower sleep/wake messages
1793356927.4223809242 pmset is in logging mode now. Hit ctrl-c to exit.
1793356927.4228639603 2026-10-30 13:42:07 +0300 IOPSNotificationCreateRunLoopSource
1793356927.4230780602 Now drawing from 'Battery Power'
1793356927.4232339859  -InternalBattery-0 (id=23724131)	100%; discharging; 17:53 remaining present: true
1793356945.0403649807 2026-10-30 13:42:25 +0300 com.apple.system.powersources.timeremaining
1793356945.0406761169 2026-10-30 13:42:25 +0300 IOPSNotificationCreateRunLoopSource
1793356945.0417299271  -InternalBattery-0 (id=23724131)	100%; discharging; 17:43 remaining present: true
```

## Restore: the hand-over (B3)

- 2026-10-30 13:21:41: the appearance, the wallpaper, the session's settings; the TextEdit, System Settings, Accessibility Inspector and Xcode the script opened closed; 2 items for the session

## Restore

- restored 2026-10-30 17:05:13: 0.6.1 (7), the settings domain, Application Support, the widget's data and preferences, Low Power Mode, the wallpaper and the appearance
- the Charge Limit: prepare found 100; pmset -g battlimit now: shows none (a Battery pane shot confirms it)

## The night (B6): sleep hygiene and the overnight log stream

- since 2026-10-30 15:55:10: DarkWake or Wake from lines naming BatteryPulse: 0 (must be 0); sleeps 11, wakes 11
- the overnight log stream: still running
- its lines: 199; 4 gaps over 10 minutes, the longest 17 minutes (lines after the wake mean the stream survived the sleep)

## Notes

- 12:10: B-bedtime not given: a daytime session; his word: take the time needed, so the default of 4 hours after the start applies
- 12:23: widgets showed 88% Charging, Full at 12:49 from 12:12 to 12:19 while the charge rose to 94%
- 12:23: P3 first try: not-run, its occlusion check counted the pointer's own window (layer 2147483630, 28x40 at 942,132, where a computer-use click left it); the pointer moved to bare desktop by ui move, then P3 once more
- 12:24: the cover was computer use's own pointer overlay (layer 2147483630, 28x40) left at its last click; a computer-use pointer move to bare desktop removed it; every computer-use batch now ends with that move
- 12:30: two read-only commands ran outside the script during B0b: a grep of m5-session.sh for measure's arguments, and an osascript read of Terminal's window titles to place the arm window
- 12:32: finding: after select-row History from Raw Data, the shot right after (v01-history, 12:32:13) shows History's title, picker and sidebar selection over Raw Data's table; v01-history-2 at 12:32:21 shows History's charts
- 12:35: F8 first take: NOT CHECKED F8-en (no desktop spot): the spot 855,930 chosen in B0b lay under the main window moved to 740,140 960x870 in B2.1; new spot 640,310 (probe holds), F8 once more
- 12:36: F8 second take: the desktop click refused by a NotificationCenter window at layer 23 over the whole display, a Claude desktop app banner (Claude needs your permission: an MCP tool) at 12:35, left untouched; F8-en answered from the crops with --unsure
- 12:37: F9 first take: NOT CHECKED F9-overview: the show-desktop state left by F8's desktop click covered the window (WindowManager layer 18); ended by one computer-use click on bare desktop at 12:37, then F9 once more
- 13:13: finding about the script: its desktop clicks (F8, and during pages profiling or F12) leave the click-wallpaper-to-show-desktop state on (WindowManager layer 18, Terminals pushed off-screen); each time ended by one computer-use click on bare desktop (12:37, 13:13)
- 13:13: SUI-17 not checked: prompt: Xcode opened with Install Required (system-wide components must be installed, Quit or Install) at 13:13; left untouched while he is away, no canvas reached
- 13:14: wp18 timing ended at once with an empty list of the 5 slowest bodies, likely the same missing Xcode components as SUI-17's prompt; WP-18 timing not run
- 13:14: SZ-10 not run: no icon source in the frozen worktree
- 17:05: charge-limit check: pmset battlimit shows none; the Battery pane shot (charge-limit-check) shows Last charged to 100% at 13:30 and no limit, as at prepare (prep-charge-limit 100): unchanged
- 17:10: morning batch: he skipped the 5 unsure items (V01-menubar, F8-small-en, F8-medium-en, F8-small-ru, F8-medium-ru) and asked the next Claude session to review them from the shots kept on the Mac in ~/bp-062/B (shots/f8/f8-small-en.png, f8-medium-en.png, f8-small-ru.png, f8-medium-ru.png, and the v01-menubar crops); they keep their defaults until then. Open questions: F8-ru, did the widgets stay English because of a bug or because they did not re-render after f8 ru on; V01-menubar, the dark bar and the pixel diff were never checked
- 17:12: allow rules he added: none named (his word: no)

