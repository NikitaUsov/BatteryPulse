# Session F results (BatteryPulse 0.7.1)

Written by `docs/plans/0.7.1/m5-session.sh send` on 2026-11-06 13:08 +0300. The session ran hands-free
(PLAN.md §6.2): answers marked "claude" were judged by the Claude session from the pictures, beside the
script's pixel measurement where one exists; "person" ones came from the maintainer. Full-desktop shots,
recordings and logs stay on the Mac (`~/bp-071/F`).

## Appendix C rows this session owns

| Fact | Where |
|---|---|
| §6.5's short feed check: the feed at its real size and a cold read, step 2's second half, the language on one widget, One device, a click per new kind, crash reports and faults | The widget's feed; Step 2's second half; R-feed-*, R2-*, R4-*, R8-*; Crash reports and faults |

## Timeline

- prepare: 2026-11-06 12:36:43

## Answers

| ID | Question | Answer | By | Time | Note |
|---|---|---|---|---|---|
| F-yes | The short feed check (SESSION-R.md, Feed check): RC-U over his 0.7.0, which comes back at the end: y = go ahead | y | person | 12:36 |  |
| F-usage | What /usage showed at the start | session 17% used, resets 15:29 Moscow; week 45% used, resets Nov 10 12:59 | person | 12:36 |  |
| F-keep-widgets | Keep the widgets the session adds from the gallery: y = keep (default: removed at the end) | n | person | 12:36 |  |
| R-feed-before | The feed under 0.7.0, before RC-U: no Widget/feed.json (0.7.0 writes none); the script reads it | y | claude | 12:48 | no feed.json under 0.7.0 (9) |
| R2-small | Step 2's second half, the small widget (Automatic) after RC-U's install over 0.7.0 and the desktop click, against its -before.png: 1 the same layout with fresh values, 2 blank or grey, 3 gone, 4 different (note) | 1 | claude | 12:57 | small-now.png shows the before layout with fresh values: 73 % On battery, lasts until about 19:52 (before: 74 %, 19:38) |
| R2-medium | Step 2's second half, the medium widget set to Custom under 0.7.0, after RC-U's install: 1 its choices kept, with fresh values, 2 blank or grey, 3 gone, 4 different (note: choices lost?) | unsure | claude | 12:57 | for his batch: claude read 1; Custom never set (the edit sheet's menus belong to WidgetConfigurationExtension, out of computer use's reach); medium-now.png keeps his Automatic choices and layout (Maximum capacity, Cycle count, Temperature) with fresh values: 73 %, 19:52 (before: a stale 76 %, 18:17) |
| R2-large | Step 2's second half, the large widget placed under 0.7.0 (Automatic), after RC-U's install: 1 the History chart in place of the last two rows, 2 blank or grey, 3 gone, 4 different (note: the eight rows kept?) | 1 | claude | 12:57 | large-now.png shows the History chart (13:00 to 12:52, 0-100 %) in place of the Remaining capacity row; the six other details kept with fresh values: 73 %, Updated 12:53 |
| R3-history-medium | Step 3, the history-medium widget added from the gallery, against the CI render of its kind and family: looks right (n names the picture) | y | claude | 12:59 | history-medium-added.png has history-medium-day-charge.png's layout: Charge title, the value 74 %, the 100 %/0 % scale, the day's line, 13:00 to 12:52; readable, dimmed on the unfocused desktop, nothing cut |
| R3-devices-small | Step 3, the devices-small widget added from the gallery, against the CI render of its kind and family: looks right (n names the picture) | y | claude | 12:59 | devices-small-added.png matches devices-small-reads-off.png: the devices symbol and Turn on Read iPhone and iPad batteries in BatteryPulse, readable, nothing cut (reads are off in the session's settings) |
| R-feed-history | The feed within 15 minutes of the first History widget: 0600 in a 0700 folder, version 1, at most 32 KB, written within 15 minutes, no udid, serial or demo key; the widget's entitlements the sandbox and one read-only path, Widget/; no sandbox denial; the widget read it (the script reads it) | n | claude | 12:59 | 1 sandbox denials |
| R-feed-cold | A feed written while no widget process ran, then read by the extension the reload started, without a rejection or an open failure (the script reads the stream's order) | y | claude | 13:00 | written while no widget process ran, then read |
| R4-6-device | Step 4.6, the iPhone & iPad widget's edit sheet, One device (G71-4): 1 its chooser opens (empty while no device is remembered), 2 it doesn't open or shows an error, 3 no One device option | unsure | claude | 13:02 | for his batch: claude read y; not checked as asked: the sheet's words read right in devices-sheet.png and devices-show-menu.png (iPhone and iPad; The charge of your iPhone and iPad, as BatteryPulse last read it; Show: Most recently read, Lowest charge, All, One device), but One device could not be chosen: the menu belongs to WidgetConfigurationExtension, which computer use refuses, so its chooser never opened |
| R8-history | Step 8, a click on the widget (history): 1 the expected page opened, 2 another page (which, and its route), 3 nothing opened | 1 | claude | 13:03 | click/history.png shows the History page selected (24 Hours, Charge, Power, Temperature); the log reads Widget click by url opens history |
| R8-device | Step 8, a click on the widget (device): 1 the expected page opened, 2 another page (which, and its route), 3 nothing opened | 1 | claude | 13:03 | click/device.png shows the iPhone and iPad page selected with its Turn On empty state (none remembered, reads off); the log reads Widget click by url opens devices |
| F-send | Send F.md and the attached images to claude/071-session-f, after the contact sheet and the summary: y = send | y | person | 13:08 |  |

## Proofs

| Proof | Result | Detail | Fallback | Time |
|---|---|---|---|---|
| P7 | pass | the appearance by System Events: read; com.apple.WindowManager: read; style-like keys in defaults -g: 3; AppleICUForce24HourTime: 1 | an unread setting is unknown, and never changed | 2026-11-06 12:38:17 |
| P8 | fail | its own pane per URL: appearance=yes (sidebar unread); desktop=no (sidebar unread); displays=no (sidebar unread); accessibility=yes (sidebar unread); login-items=yes (sidebar unread); battery=yes (sidebar unread); date-time=yes (sidebar unread); wallpaper=yes (sidebar unread); bluetooth=yes (sidebar unread);  | computer use from System Settings' sidebar for: desktop displays (ui doesn't act there) | 2026-11-06 12:38:38 |
| P6 | pass | HIDIdleTime: a HID-tap move resets it, a session-tap move resets it, caffeinate -u keeps it; .hidSystemState ignores posted events: yes; ui posts at the hid tap | his touches by the HID event state (ui guard) | 2026-11-06 12:38:56 |
| P11 | pass | the menu bar item's frame by AX: 1194 5 78 24 (no window in CGWindowList on macOS 27.2) | - | 2026-11-06 12:38:56 |
| P1 | pass | the widget's host is NotificationCenter (com.apple.notificationcenterui), with a BatteryPulse label in its chain (logs/p1-hit.txt) | - | 2026-11-06 12:41:10 |

## Prepare (the feed check's start)

- prepared: 2026-11-06 12:36:43; macOS 27.2 (26B123); the frozen script at cba6bc1
- installed before the session: 0.7.0 (9)
- defaults domain: 32 keys backed up
- Application Support: 22 files, 308 KB backed up
- charge: 76 %, on battery
- tools: ui built, frames built, bpulse built

| Build | Version | CFBundleVersion | Source |
|---|---|---|---|
| U | 0.7.1 | 26725241 | run 42181969486, artifact BatteryPulse-0.7.1-8900331031b8efb847a78d390d206ec92aba7de2 |
- BatteryPulse's own languages (its AppleLanguages): none (the system's)

## Preflight (the start)

- access: ax_trusted=yes post_events=yes screen_capture=yes
- tell application targets: System Events and BatteryPulse only
- Apple Events: System Events answers; BatteryPulse answers
- the widget extension's container preferences: read
- pmset -g battlimit: 
- hot corners: tl=11 tr=12 bl=2 br=4
- a VPN active: no
- charge: 76 %, on battery
- the widget extension's processes: 1 (by its path)
- BatteryPulse's automatic update check: off for the GUI phase (session settings); his value comes back for the logged day
- the Claude desktop app: not running
- pending macOS updates (Software Update's own count, read-only): unknown
- the main window's occlusion check: main window 126 at 231 101 1259 875: covered by another app (layer 2147483630)
- ui guard: guard: clear
- keep-awake assertions of other processes (user activity or display sleep): 0; system sleep only (no run changes): 0 (names stay on the Mac)

| Proof | Result | Detail | Fallback |
|---|---|---|---|
| P7 | pass | the appearance by System Events: read; com.apple.WindowManager: read; style-like keys in defaults -g: 3; AppleICUForce24HourTime: 1 | an unread setting is unknown, and never changed |
| P8 | fail | its own pane per URL: appearance=yes (sidebar unread); desktop=no (sidebar unread); displays=no (sidebar unread); accessibility=yes (sidebar unread); login-items=yes (sidebar unread); battery=yes (sidebar unread); date-time=yes (sidebar unread); wallpaper=yes (sidebar unread); bluetooth=yes (sidebar unread);  | computer use from System Settings' sidebar for: desktop displays (ui doesn't act there) |
| P6 | pass | HIDIdleTime: a HID-tap move resets it, a session-tap move resets it, caffeinate -u keeps it; .hidSystemState ignores posted events: yes; ui posts at the hid tap | his touches by the HID event state (ui guard) |
| P11 | pass | the menu bar item's frame by AX: 1194 5 78 24 (no window in CGWindowList on macOS 27.2) | - |

## Installs

- 2026-11-06 12:52:13: U 0.7.1 (26725241) (higher); extension pids before 857, widget extension ended before the swap: about 20 ms, last signal TERM, after 6490

## Step 2's second half: placed widgets across the update to RC-U (G7-2)

- before (2026-11-06 12:51:41): 0.7.0 (9); widget extension pids: 857 
- 1 minute(s) after U's install (2026-11-06 12:53:02): 0.7.1 (26725241); widget extension pids: 6490 ; CHSErrorDomain 1103 lines since 2026-11-06 12:52:01: 1
- pluginkit:
```
     io.github.nikitausov.BatteryPulse.Widget(0.7.1)	B6CE8E02-932E-40F1-BCB9-87C1579584B6	2026-11-06 09:52:01 +0000	/Applications/BatteryPulse.app/Contents/PlugIns/BatteryPulseWidget.appex
 (1 plug-in)
```
- 5 minute(s) after U's install (2026-11-06 12:57:02): 0.7.1 (26725241); widget extension pids: 6490 ; CHSErrorDomain 1103 lines since 2026-11-06 12:52:01: 2
- pluginkit:
```
     io.github.nikitausov.BatteryPulse.Widget(0.7.1)	B6CE8E02-932E-40F1-BCB9-87C1579584B6	2026-11-06 09:52:01 +0000	/Applications/BatteryPulse.app/Contents/PlugIns/BatteryPulseWidget.appex
 (1 plug-in)
```
- compared (2026-11-06 12:57:08): CHSErrorDomain 1103 lines since 2026-11-06 12:52:01: 3

## Step 3: the gallery

- history-medium added and cropped (2026-11-06 12:59:24)
- devices-small added and cropped (2026-11-06 12:59:27)

## The widget's feed (G71-2; W-17 item 7)

- before (2026-11-06 12:48:14): no feed.json (no Widget/ folder); 0.7.0 (9)
- the widget's entitlements: sandbox yes; read-only paths 0 (); other keys none
- the feed's lines since 2026-11-06 12:36:43: writes 0 (), the widget's reads 0, rejections 0 (), open or read failures 0 ()
- sandbox denials of BatteryPulseWidget since 2026-11-06 12:36:43: 1, of them in Widget/: 0 (logs/feed-denials.txt on the Mac; the predicate is unverified)
- the widget extension's processes: 1
- history (2026-11-06 12:59:44): 0.7.1 (26725241); the folder 700, the file 600; 3561 bytes, version 1, written 463 s ago; the day's steps with a charge 91; devices 0 (named 0); readsDevices false, recordsHistory true; a udid, serial or ECID key 0, Demo Mode's device 0; the languages ["en","en"]
- the widget's entitlements: sandbox yes; read-only paths 1 (/Library/Application Support/io.github.nikitausov.BatteryPulse/Widget/); other keys none
- the feed's lines since 2026-11-06 12:48:17: writes 0 (), the widget's reads 8, rejections 0 (), open or read failures 0 ()
- sandbox denials of BatteryPulseWidget since 2026-11-06 12:48:17: 1, of them in Widget/: 0 (logs/feed-denials.txt on the Mac; the predicate is unverified)
- the widget extension's processes: 1
- the first History widget: 2026-11-06 12:59:15 (0 minutes ago)
- cold (2026-11-06 13:00:04): after 5 s, the reload notice: 13:00:07.119 BatteryPulse perf event widget.reload trigger=policy; a new extension process: 9544
- cold (2026-11-06 13:00:16): 0.7.1 (26725241); the folder 700, the file 600; 3560 bytes, version 1, written 9 s ago; the day's steps with a charge 91; devices 0 (named 0); readsDevices false, recordsHistory true; a udid, serial or ECID key 0, Demo Mode's device 0; the languages ["en","en"]
- the widget's entitlements: sandbox yes; read-only paths 1 (/Library/Application Support/io.github.nikitausov.BatteryPulse/Widget/); other keys none
- the feed's lines since 2026-11-06 12:59:46: writes 1 (language 1), the widget's reads 1, rejections 0 (), open or read failures 0 ()
- sandbox denials of BatteryPulseWidget since 2026-11-06 12:59:46: 1, of them in Widget/: 0 (logs/feed-denials.txt on the Mac; the predicate is unverified)
- the widget extension's processes: 1
- cold: the app's write at 2026-11-06 13:00:07.113118+0300; the extension's first line at 2026-11-06 13:00:07.200392+0300; its read at 2026-11-06 13:00:07.202179+0300; rejections and failures 0

## Step 8: clicks (G7-9)

- history (2026-11-06 13:03:07): BatteryPulse runs; its log lines since the click:
```
13:03:07.655 BatteryPulse Widget click by url opens history
```
- device (2026-11-06 13:03:29): BatteryPulse runs; its log lines since the click:
```
13:03:29.584 BatteryPulse Widget click by url opens devices
```

## Crash reports and faults since prepare (G7-16)

- crash reports since prepare (BatteryPulse and BatteryPulseWidget; must be 0):
- new crash reports: 0 (copies in logs/crash/)
- fault messages in the subsystem since prepare: 0 (must be 0)

## Restore end

- restored 2026-11-06 13:03:54: 0.7.0 (9), the settings domain, Application Support (History/ kept: 12 files; the feed removed), the widget's languages, the appearance
- the Charge Limit: prepare found unknown; pmset -g battlimit now: none (on battery it holds none: a Battery pane shot confirms it)

## Notes

- 12:50: step 4: the medium widget's Custom choices not set: the edit sheet's menus (Layout, Details, Colors) belong to com.apple.WorkflowUI.WidgetConfigurationExtension (ui hit: AXMenu at layer 101), which computer use refuses and cannot grant, and the rules allow no key press; his Automatic choices stay, so R2-medium checks only the layout across the update; step 7's One device chooser is a menu of the same extension
- 12:52: step 4: What's New after RC-U's install stayed open after two presses of the Command-W menu item (ui press --menu-cmd w said pressed; ui windows still listed it); closed by ui close BatteryPulse --window "What's New" (its close button by AX)
- 13:00: R-feed-history: its one sandbox denial is a false match: logs/feed-denials.txt holds only the log tool's own 'log run noninteractively' lines, whose arguments contain the predicate's text (Sandbox: BatteryPulseWidget, deny); no denial line; every other rule held (modes 700/600, version 1, written 463 s before, 0 devices, no udid/serial/ECID, the widget's 8 reads, no rejection or failure); the feed's write lines read 0 although the file was written at RC-U's launch (12:52)
- 13:01: step 6 (R4-3-widgets, language ru and back) not checked: in System Settings, General, Language and Region, Applications, BatteryPulse was already listed as System Default - English; its language pop-up menu is owned by the pane's own process (computer use: 'Language & Region (System Settings)', not grantable), ui acts only in P8's panes, and no key press is allowed; nothing was changed, so language ru and language back were not run

