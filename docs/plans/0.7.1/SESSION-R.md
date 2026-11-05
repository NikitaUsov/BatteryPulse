# M5 Session R: the hands-free runbook

> **For 0.7.1.** 0.7.0 shipped without this session (the maintainer's decision, 2026-10-31), so
> 0.7.1's M5 session runs it, re-pointed at 0.7.1's branch, base and candidates (PLAN.md W-16),
> with 0.7.1's own checks (W-17). His Mac runs 0.7.0 (PLAN.md §14, Q71-2).
> PLAN.md and its § references are 0.7.1's `PLAN.md` beside this file; 0.7's package IDs
> (W-3b, W-11, W-13) are 0.7.0's `docs/plans/0.7.0/PLAN.md`, readable at
> `ebe654772c7f06d5e136327e0e6a236fed71cdc9` in `refs/pull/13/head`.

Session R of BatteryPulse 0.7.1 runs on the release candidates on the MacBook Air M5. One local
Claude Code session with computer use does every step itself, through `m5-session.sh` and its `ui`
helper, and a plain script in a second Terminal window, the arm window, keeps the display awake for
the GUI phase and starts the logged day. PLAN.md §6.2-§6.4 is the plan; this file is what the
session does. It is built on 0.6.2's Session B (`SESSION-B.md`, in 0.7.0's plan folder), whose rules
and privacy hold here, with its lessons applied. The maintainer does only what needs a person: the
launcher and one yes, quitting his own apps (the Claude desktop app among them), postponing a
pending macOS update, the permission prompts, the Focus, the adapter at two beeps, the taste
questions, his typed "day-end", and his yes before `send` (about 6-8 minutes at the start, 5-6 at
the day's end, with the adapter's two beeps).

The short sessions (Charge limit, Hold watch, After publishing, Feed check) have their own sections
after "The short sessions"; each stands alone, with its own launcher argument. "Answers" and "R3: the
day's end" follow them, and his own part, "Before Session R (him)", is the last section. The launcher
prints this file up to "The short sessions"; the session it starts, you, begins at R0.

## Rules

- **Language.** Talk to him in Russian, always. Everything recorded is English: `answer`, `judge`,
  `note`, `change`, `restored`, `attach` captions; the script refuses Cyrillic.
- **One prefix.** `$S` below stands for `bash ~/bp-071/R/run/docs/plans/0.7.1/m5-session.sh`. Write it
  in full in every call, exactly so, one script call per Bash call: no `cd`, no variables, no pipes, no
  redirection, no `&&`. The only commands outside it are R0's `git fetch`, `git show`, `git rev-parse`,
  `git worktree move` and `git worktree add`, under auto mode. `$S help` lists the commands, and the
  header of `ui.swift` beside the script lists `ui`'s. Read files (shots, crops, logs, `R.md`,
  `answers.tsv`, `changes.tsv`) with your file-reading tool, never with a shell command.
- **Frozen.** The runbook, the script and `ui` are fixed at R0's commit. Never edit them, never fetch
  again, never adopt a later fix: a fix goes to the next session.
- **Permissions.** Never add or change a permission rule, never change Claude Code's or git's
  configuration, never retry a command auto mode blocked (its step is "not run: blocked"). Never type
  a password, never approve a permission or authorization dialog, never toggle anything in Privacy &
  Security, Users & Groups or Passwords.
- **Long calls.** Give every script call the Bash tool's `timeout: 600000`; it matters for every call
  over 2 minutes (`preflight`, `placed 5`, `plug`, `look`, `tick`, `count-toggle`, `language`,
  `menubar`, `f12 after`, every `restore`, `day-end`, `send`). Anything near the tool's 10-minute limit
  runs as a background task: `prepare`, `wp18 timing`, and in the short sessions `charge-limit hold`,
  `charge-limit wait100`, `count-check stats`. **Never end your turn while a background task runs:**
  wait on it with `$S wait <minutes>` (1-9) in the foreground, with `timeout: 600000`; it returns within
  a minute of the task's end, or after that many minutes; then read the task's output, and wait again
  until it ended. Never `sleep`, and never a quick loop of reads. While a task runs, the screen is the
  task's: no GUI action.
- **Heartbeat.** Every script call but `help` and `status` touches it, and the script keeps its own
  every minute while a call runs (at most 45 minutes). After `mark away` the arm window takes 20
  minutes without either for a stall and starts the logged day without you. So after `mark away` never
  let 10 minutes pass without a script call: after each step, between computer-use batches and at least
  every 10 minutes, `$S heartbeat "<step> done, next about HH:MM"`. It prints the GUI phase's minutes
  left.
- **After `ready`, nothing acts until his "day-end".** Check `$S status` before every step. A message
  that reaches you on the logged day gets a text-only answer (say: "the results come at the day's
  end"), with no tool call, unless it is "day-end".
- **Order of means.** The script and `ui` (AX, CGEvent, CGWindowList) first, computer use where they
  can't reach. Neither ever sends Esc (it would end your turn) or a key press `ui`'s rules don't allow.
  Before any change by computer use or AX outside the script: `$S change <setting> <original> <new>`;
  after putting it back: `$S restored <setting> <how it was confirmed>`. A setting whose original is
  unknown is never changed. The setting names: `widget-style`, `dim-widgets`, `text-size`,
  `increase-contrast`, `reduce-transparency`, `24-hour`, `app-language`, `open-at-login`,
  `bluetooth-accessory`, `widget-choices`, `charge-limit`, `desktop-widgets`, `history`.
- **Computer use's own traces** (Session B's lessons). Computer use finds BatteryPulse, a menu-bar
  app, only once it has a window: `$S main` before your first computer-use action in it. Computer use
  leaves a 28×40 pointer overlay at its last click, which fails the occlusion check: end every batch
  with a computer-use pointer move to bare desktop (the desktop spot). The script's desktop clicks end
  the revealed-desktop state themselves (`click_desktop`); a DO line says when you must end it by one
  computer-use click on bare desktop.
- **System Settings.** Open panes by computer use from the sidebar: on macOS 27.2 the URLs of
  Appearance, Desktop & Dock and Displays open other panes, and the sidebar's selection can't be read
  (Session B's P8). `ui` acts only in a pane P8 confirmed by its title.
- **Notification Center** can't be granted to computer use: the widgets in it, and the desktop
  widgets while it is open, are the script's crops (`look nc`).
- **Places.** Terminal windows in the left third of the screen, BatteryPulse's windows and widgets
  on the right, away from the top-right corner where banners land.
- **Commits.** You commit and push nothing. The only push is `send`'s, to `claude/071-session-r`,
  committed in UTC, after his yes. No other branch, no pull request.

## Privacy

- Every picture you read, and every computer-use screenshot, goes to the model; none goes into the
  repository. His Focus, the apps he quit and the hidden apps limit what they show; his other desktop
  widgets are in them (the start message says so).
- No computer-use screenshot while Notification Center or Control Center is open: AX actions and the
  script's crops of BatteryPulse's frames instead. No computer-use screenshot of System Settings →
  Bluetooth (device names): AX presses only, and `accessories-watch`'s crops.
- Full-desktop, Notification Center and System Settings shots stay in `~/bp-071/R`. Only crops of
  BatteryPulse's windows, widgets and menu bar item are attached (`$S attach`), never one taken while
  BatteryPulse remembers an iPhone or iPad by name or its widget feed holds one (the script refuses
  those). The Accessories and iPhone & iPad widgets' trees and crops show names: read them, never
  attach them, never write a name.
- `pmset -g accps`, `pmset -g log` and `scutil` outputs reach `R.md` only as counts; `send`'s privacy
  lint enforces it. A `KEEPAWAKE` line names another app's process: say it to him, and nowhere else.

## Decisions you make alone

- **A step fails or misbehaves:** read the message; run it once more only if the cause was passing (a
  window not up yet, a timeout); else `$S note "<step>: <what happened>"`, and its items are "not
  checked" or "not run" with the reason; go on. A harmless workaround is allowed only if it changes no
  setting outside `changes.tsv`, and is noted.
- **Never repair the Mac's state by hand:** no `killall` or restart of a system process (chronod, Dock,
  WindowManager, Notification Center, cfprefsd), no `lsregister`, no install, swap or copy of a build
  except through the script.
- **The order is fixed.** Skip ahead only while a step waits; come back to it once, later in the GUI
  phase, else at the day's end.
- **A spoiled take** (a banner over the widgets, his touch): run that one step again once; the rerun
  replaces its section; note the first take. Then answer 3 or `--unsure`.
- **A banner at layer 23** (the Claude desktop app's, Software Update's) that refuses a click: note it
  and go on to steps that don't need the desktop; never press a button in it.
- **A failed proof** prints its fallback: switch that proof's steps to it.
- **A prompt or a password dialog:** while he is there, ask him to answer it; while he is away, leave
  it, record "not checked: prompt", and go on.
- **A lock screen or the lid closed:** stop all GUI work, record "not checked: locked", and wait.
- **He touches the Mac during the GUI phase:** if P6 showed that the HID event state tells his touches
  apart (`ui guard`), wait until his last touch is a minute old. On his Esc your turn ends; on his "go
  on", check the state first (`$S status`, a shot) and carry on.
- **Findings** (crash reports, a wrong value, a widget that looks wrong): note them with their evidence
  and go on; never investigate beyond the step's reads, never patch anything.
- **Anything not on the yes-list:** never change it; a step that would need it is "not checked".
- **Your usage limit:** if `/usage` or the CLI warns that the limit is near, drop R1's extras, then
  step 7's Russian tree, and go to the hand-over early.
- **Anything this file doesn't cover:** do what changes nothing, record "not checked" with the reason.

## R0: the start (he is there, about 6-8 minutes)

1. **The worktree.** `git -C ~/BatteryPulse rev-parse FETCH_HEAD` is the commit you read this file
   from. If `~/bp-071/R/run` exists, read its commit (`git -C ~/bp-071/R/run rev-parse HEAD`): the same
   commit is a restart (read `~/bp-071/R/run/docs/plans/0.7.1/SESSION-R.md`, from "If the session
   restarts"); another commit: ask him whether this is a new attempt; a new attempt: `git -C
   ~/BatteryPulse worktree move ~/bp-071/R/run ~/bp-071/R/run-<its first 7 characters>`. Then `git -C
   ~/BatteryPulse worktree add --detach ~/bp-071/R/run FETCH_HEAD`, and **`$S prepare attempt`**, your
   first script call (an earlier attempt's folder moves aside once its changes are back; if it lists
   some, follow its message: `--kept` on his word, `--restored` after you put one back and shot it).
   Then `$S help` and `$S status`, and read this file's "Answers" in `~/bp-071/R/run` with your
   file-reading tool (the start printed only up to "The short sessions").
2. **The start message,** one message in Russian, before anything changes:
   - What may change, each written to `changes.tsv` first and put back: the installed BatteryPulse
     (v0.6.2 for step 2's first minutes, then v0.7.0, then the release candidates, whatever his Mac
     runs; his own comes back from the backup at the end); BatteryPulse's settings and data for the
     GUI phase (his settings come back for the logged day), his remembered iPhones and iPads hidden
     for it; Icon & widget style, Dim widgets on desktop, Text size, Increase Contrast, Reduce
     Transparency, the 24-hour setting; Check for updates and Window to open (his come back);
     BatteryPulse's language in Language & Region → Applications; the edit sheets' choices (back to
     Automatic); the gallery's widgets, the History and iPhone & iPad ones new (removed at the end
     unless he keeps them); a Bluetooth accessory disconnected and reconnected by an AX press; the
     appearance and a plain wallpaper for the menu bar shots (put back by the tool, read back).
   - What the end keeps and removes: the logged day's history stays; the widget feed the candidate
     writes (`Widget/feed.json`) goes with the rest of the session's data.
   - Never: the Charge Limit, a VPN, anything in Privacy & Security, Users & Groups or Passwords.
   - The questions: when is he back at the Mac (else 4 hours from now; the GUI phase ends 10 minutes
     before)? Keep Terminal's Accessibility after Session R (else a reminder at the end)? Keep the
     gallery's new widgets? And: "Please type /usage now and tell me what it shows."
   - Privacy: the pictures go to the model and stay on the Mac; his other desktop widgets appear in
     them.
   - Times: about 10 minutes of building, then a beep and about 6 minutes with him (his apps quit,
     the Claude desktop app among them; a pending macOS update postponed; the approvals); then he may
     go, with a Focus on. The GUI phase runs on its own, about 2.5-3.5 hours, at most 4. Then the
     logged day starts by itself: he turns the Focus off and uses the Mac as usual, and at the day's
     end writes "day-end" here (5-6 minutes then, the adapter at two beeps among them).
   - End your turn and wait for his answer.
3. **Record** (only on an explicit yes): `$S answer --by person R-yes y`; `R-back HH:MM` if he gave one;
   `R-keep-ax y|n`; `R-keep-widgets y|n`; `R-usage "<what he said>"`.
4. **`$S prepare`** as a background task (about 10 minutes), waited on with `$S wait 9`. It ends with
   `BEEP (prepare is done)`, with v0.6.2 in place for step 2. If it fails twice, tell him why, run `$S
   restore gui` and `$S restore end` if `changes.tsv` lists anything, and end.
5. At the beep, say: "The build is done. Please quit your own apps (Terminal stays), the Claude desktop
   app among them and any utility that keeps the Mac awake, and if Software Update offers an update,
   choose Later. Then write me that you are back." End your turn.
6. **Reads and proofs** (he is there). `$S ui access` (if `ax_trusted=no`, ask him to turn Terminal on
   under System Settings → Privacy & Security → Accessibility, then again). `$S prepare reads`; open
   System Settings → Appearance and → Desktop & Dock by computer use from the sidebar, `$S shot
   settings-appearance` and `$S shot settings-desktop`, and answer `prep-*` from the shots. `$S proof
   P1 --image <shot> <x> <y>` at one of his BatteryPulse widgets' centre (none: P1 waits for step 2's
   first widget), and `$S desktop-spot --image <shot> <x> <y>` on bare desktop away from icons and
   widgets.
7. Say: "For the next five minutes please don't touch the keyboard or the trackpad; answer any macOS
   prompt that appears." `$S preflight`: its DO lines go to him in Russian (the Claude desktop app, a
   pending update, a keep-awake holder: the name to him only). Then P10: one computer-use access
   request for the whole batch (BatteryPulse after `$S main`, System Settings, Finder, the widget host
   P1 named, Xcode, Accessibility Inspector), one widget click-to-add in the gallery and its removal
   (`change p10-widget none added` first, `restored p10-widget "<the shot>"` after), a screenshot right
   after the first action, one System Settings click, the pointer moved to the desktop spot; then `$S
   proof P10 pass|fail "<what it showed>"`. Then each command family once, as preflight's `RUN` lines
   say.
8. `$S arm open`, then `$S mark away` (no sound or speech from here until his "day-end"). Say: "A
   Terminal window named BatteryPulse arm opened; leave it open, the Mac on the adapter, the lid open.
   Please turn a Focus on. You may go; when you are back, read my summary first, turn the Focus off,
   and use the Mac as usual. At the day's end write day-end here." Go straight on to R1 in the same
   turn.

## R1: the GUI phase (he is away; about 2.5-3.5 hours, capped at 4)

It stops 10 minutes before his return, or 4 hours after `mark away` (`heartbeat` shows the minutes
left). Whatever is left then is `$S note "<item> not run (time)"`. Past 3 hours, step 5's remaining
looks and the extras are "not run (time)" before 4.3, 4.6, the new kinds' clicks or the feed's
rewrites are. Each gallery widget: Edit Widgets from the desktop's context menu (a Control-click on
an empty spot), a search for BatteryPulse, the click-to-add, then one slow `$S ui drag`, with `$S
change desktop-widgets "<before>" "<added>"` first and `$S widget <name> ...` after (`$S ui frame
--widgets`). In this order:

1. `$S capacity start`; System Settings → Battery → Battery Health by computer use (a shot); answer
   `R-capacity-start`.
2. **Step 2's first half, on 0.6.2:** a small and a medium Battery widget from 0.6.2's gallery,
   recorded as `small` and `medium` (P1 now if R0 had none). `$S menu-bar-shots before`; `$S placed
   first before`; `$S install base`; `$S whats-new`; `$S placed first 1`, `5` and `compare`
   (`timeout: 600000`), answer `R2-062-small`, `R2-062-medium`; `$S whats-new ru`, answer
   `R2-whats-new-base`.
3. **Step 2's second half, on 0.7.0:** `$S feed before`. `$S change widget-choices Automatic Custom`;
   by computer use, Edit Widget from the medium widget's context menu: Layout Custom; the first four
   details in the list; Time set to time left (if offered); Colours monochrome; Update time always;
   Done. A large Battery widget from the gallery, Automatic, as `large`. `$S placed second before`;
   `$S install U`; `$S whats-new`; `$S placed second 1`, `5` and `compare`, answer `R2-small`,
   `R2-medium`, `R2-large`; `$S whats-new ru`, answer `R2-whats-new-rc`.
4. **Step 3, the gallery,** in batches (they don't all fit): `$S gallery large` (step 2's widget);
   then Accessories small, medium, large; History medium, large; iPhone & iPad small, medium, large,
   each recorded, `$S gallery <name>`, answer `R3-<name>`. Within 15 minutes of the first History
   widget, `$S feed history`, then `$S feed cold`. After each batch, remove its widgets by computer use
   but the working set (small and medium Battery, one Accessories, one History, one iPhone & iPad),
   each with `change desktop-widgets` and `$S widget <name> none`; the large Battery one goes too.
5. **Step 4, the edit sheets** (computer use; the choices are fixed):
   1. Edit Widget on the medium widget: open Details' chooser, answer `R4-1-chooser`, swap the fourth
      detail for Average drain; Done. `$S edit-shot custom`; answer `R4-1-shows`.
   2. Edit Widget again: answer `R4-2-kept`; Done. While it shows time left (if offered): step 6's
      `$S tick`, answer `R6-tick` (back on Automatic it shows clock time).
   3. **Russian, the way a user does it:** `$S change app-language "<his, from prepare reads>" ru`,
      then System Settings → General → Language & Region → Applications by computer use: add
      BatteryPulse with Russian (recorded as `ru`). `$S language ru` waits for the reload notice and a
      new extension process, then crops: answer `R4-3-widgets` (no redraw is "not checked" by itself,
      never n). Open Edit Widget on the medium widget and read its words (a computer-use screenshot of
      the sheet): answer `R4-3-sheet`; Done. Step 7's Russian tree now, while it is Russian: `$S tree
      ru`, answer `R7-tree-ru`. Then BatteryPulse's language back by computer use as it was, `$S
      language back`, `$S restored app-language "<the pane's shot>"`.
   5. Back to Automatic by computer use; `$S edit-shot automatic`; answer `R4-5-automatic`; `$S
      restored widget-choices "<the crop>"`.
   6. `$S change widget-choices Automatic "4.6's choices"`; the History widget's Edit Widget: its
      options read, one choice made, Done, `$S edit-shot history <its name>`, answer `R4-6-history`;
      the iPhone & iPad widget's: One device, its chooser opened (no device is remembered now),
      answer `R4-6-device`. Both back to their defaults; `restored widget-choices "<the crops>"`.
6. **Step 5, rendering modes and places:** Dim widgets on desktop to Always (`change dim-widgets`
   first), then Icon & widget style through Default, Dark, Clear and Tinted (`change widget-style`
   first), by computer use from System Settings' sidebar; after each, `$S look always <style>` and its
   answer. Then Dim widgets on desktop Automatically and the four styles again with `$S look auto
   <style>`; then for each style `$S look nc <style>` (Notification Center by the script, crops only).
   Then Increase Contrast on (`change increase-contrast off on`), `$S look contrast` (it redraws the
   widgets first), off again; Reduce Transparency the same with `$S look transparency`. Last, the
   style and Dim widgets back to prepare's values, each `restored` with the pane's shot.
7. **Step 6, time:** 24-hour time off by computer use (System Settings → General → Date & Time; `change
   24-hour on off` first), `$S look 12-hour`, answer; back, `restored 24-hour "AppleICUForce24HourTime
   reads 1"` after `$S status`. (`tick` ran in step 4.2.) Then `$S count-toggle`, answer
   `R6-count-toggle` from its four shots.
8. **Step 7, the trees:** `$S tree`, answer `R7-tree` by W-3b item 5's rules, a chart one element with
   its one label. If the tree can't be read: `$S open-app "Accessibility Inspector"`, point it at each
   widget by computer use, a shot each; else "not checked". Text size to its largest by computer use
   (`change text-size <his> largest`), `$S look text-size`, answer `R7-text-size`, back, `restored`.
9. **Step 8, clicks:** `$S click-widget quit`, `running`, `accessories`, `history`, `device`, `main`,
   `compact`, each answered `R8-*` from its log lines and window shot. For `health`: set the medium
   widget's main value to maximum capacity in Edit Widget (`change widget-choices Automatic "main
   value maximum capacity"` first), `$S click-widget health`, answer, then back to Automatic and
   `restored`.
10. **Step 9's accessories half:** `$S change bluetooth-accessory connected disconnected`; in System
    Settings → Bluetooth (`$S pane bluetooth`: a computer-use action would bring a screenshot of it),
    the connected accessory's Disconnect by `$S ui press "System Settings" <its button>` (P8 confirmed
    the pane by its title; its (i) button or its row's menu; never type its name into a note); `$S
    accessories-watch disconnect`; connect it again the same way; `$S accessories-watch reconnect`;
    answer `R9-accessory`; `restored bluetooth-accessory "connected again, pmset -g accps counts it"`.
    If the press can't reach it: "not checked".
11. **Step 9b:** `$S main`; the Developer section's Demo Mode by `$S ui select-row BatteryPulse "Demo
    Mode"`, its Charge limit scene by `$S ui press BatteryPulse "Charge limit"`; `$S feed demo-start`;
    `$S demo-shots`; the compact window as its DO line says; answer `R9b-demo`; `$S demo-shots ru`,
    answer `R9b-demo-ru`; `$S feed demo-end`; leave Demo Mode by its own control. System Settings →
    Battery → (i) next to Charging by computer use, answer `R9b-settings-ru`, else "not checked".
12. **The feed's rewrites:** `$S feed reads-on`, then `$S feed reads-off` (each presses Read iPhone and
    iPad batteries by AX; never with an iPhone or iPad on a cable). Then `$S change history "his, in
    the backup" cleared`, Clear History in BatteryPulse's Settings → Advanced by computer use, its
    confirmation too, and `$S feed cleared`. Never Forget a device: the devices are his.
13. **Settings (S-1):** each Settings pane and the Welcome window (`$S welcome`) by computer use,
    scrolled to its end, `$S front <pane>-end` after each; answer `R-settings`.
14. **The extras, while time allows:** `$S raw-history rc` (answer); `$S menubar` (answer
    `V01-menubar`); `$S menu-bar-shots after` (answer `R-menu-bar-same`); `$S wp18 previews` (an
    Install Required dialog is "not checked: prompt") and `$S wp18 timing` as a background task.

## R2: the hand-over (about 5 minutes)

1. `$S restore gui`; do each `RESTORE` item it lists, each confirmed by a read or a shot and recorded
   with `restored`. It put his settings, his remembered devices and his history back into the release
   candidate, which stays installed for the logged day.
2. `$S summary`: from its lines, write the summary he reads before he uses the Mac, in Russian, on the
   Mac only (`R.md` stays English): an alert first for every `ALERT` line, then every setting the
   session changed with how it was confirmed, then: "Please turn the Focus off." Show it as your
   message text.
3. Stop every background task. `$S ready`, your last call. End your turn. From here only text answers
   until his "day-end"; the arm window starts the logged day (the perf stream under `nohup`, the
   display assertion released) and he may close it. On "day-end", read "R3: the day's end" in
   `~/bp-071/R/run`'s copy of this file first.

## If the session restarts or compacts

- First read this file again from `~/bp-071/R/run`, then `$S status`, `~/bp-071/R/answers.tsv` and
  `changes.tsv`, and go on from the first step not done (a step that ran as the old session's
  background task: run it once more). If `ready` is up and day-end hasn't come, only text answers until
  "day-end".
- If he starts the launcher again, R0's step 1 sends the new session here (the same commit).

## The short sessions

Each starts like Session R, from any folder, with its own argument to the short launcher, which runs
the start line with its own worktree in the allow rule and a sentence that prints only its section:

```
git -C ~/BatteryPulse fetch origin claude/071-integration
bash <(git -C ~/BatteryPulse show FETCH_HEAD:docs/plans/0.7.1/start-short-session.sh) <charge-limit|hold-watch|feed-check>
```

After publishing, D3 posts the line with the release PR's number and the last commit that holds this
folder (`after-publishing <n> <keep>`), and the sentence "Don't press Install and Relaunch yourself;
the session does it." Each section stands alone: Session R's Rules, Privacy, Decisions you make alone
and Answers hold, with `$S` standing for its own worktree's script (`~/bp-071/C/run`,
`~/bp-071/H/run`, `~/bp-071/D3/run`, `~/bp-071/F/run`), and its results leave the Mac only through
`$S send` after his yes. The start printed only this part, so first, in each: `git -C ~/BatteryPulse
worktree add --detach ~/bp-071/<C|H|D3|F>/run <the commit you read this from>` (if it exists at
another commit, move it aside to `run-<its first 7 characters>` first); then read those four sections
in `~/bp-071/<C|H|D3|F>/run/docs/plans/0.7.1/SESSION-R.md` with your file-reading tool; then `$S
tools` (ui and frames from this worktree, about a minute; the After publishing check and the feed
check click and crop through them) and `$S help`.

## Charge limit

Not needed in 0.7 (the final `A.md` brought the capture and the 100 % diff); it stays for 0.8's
FEA-35 check, after a discharge. His part: the start, his yes with the adapter in, and his yes before
`send` (about 2 minutes); the limit moves at two beeps by his hand if the slider asks for a password.

1. Say in Russian what happens: a recording with `bpulse --record` under `caffeinate -i` into a new
   folder on the Mac; the Charge Limit set to 100 % for at most 10 minutes and back, by computer use (or
   his hand at two beeps); nothing else changes. On his yes: `$S answer --by person C-yes y` and
   `C-usage`.
2. `$S charge-limit start` (it refuses on battery, and unless the charge is 5 points below the limit:
   then tell him to come back after a discharge, and end). With no battlimit value, read System Settings
   → Battery → (i) next to Charging by computer use and answer `prep-charge-limit`, then start again.
3. `$S charge-limit hold` as a background task, waited on with `$S wait 9` until it ends (at most 3
   hours): it answers `C-bit24`.
4. `$S change charge-limit <n> 100`; the slider to 100 % by computer use (System Settings → Battery →
   (i) next to Charging → Charge Limit); if it asks for a password or Touch ID, leave it and use `--his-
   hand` instead: `$S charge-limit full [--his-hand]`.
5. `$S charge-limit wait100` as a background task (10 minutes), then the slider back the same way and
   `$S charge-limit back [--his-hand]`; `$S restored charge-limit "<what it printed>"` if it didn't.
6. `$S charge-limit stop`, `$S charge-limit check`, then `$S send --dry-run`, his yes (`C-send`), `$S
   send`. Tell him in Russian what the bit did.

## Hold watch

Any night before D3, never the logged day's. His part: the start in the evening and his yes; the Mac
plugged in with the lid open overnight; "morning" and his yes before `send`.

1. On his yes: `$S answer --by person H-yes y` and `H-usage`; `$S hold-watch start`. Say: "Leave the
   Mac plugged in with the lid open; in the morning write morning." End your turn.
2. On "morning": `$S hold-watch morning`; answer `H-hold` from its spans; `$S send --dry-run`, his yes
   (`H-send`), `$S send`.

## After publishing

From his restored BatteryPulse, with his widgets placed (PLAN.md §6.4, the short form, Q71-4). His
part: the line, the approvals and his yes before `send` (about 2 minutes), plus a passive 10-minute
wait. Never `gh`, `sudo`, `killall`, an install or a copy outside the script.

1. Say in Russian: "This is the check after the 0.7.1 update, about 15 minutes. Please keep off the
   Mac until I say so, don't press Install and Relaunch yourself (the session does it), and answer a
   dialog only if I ask." On his yes: `$S answer --by person D3-yes y`.
2. `$S tools` must have built ui and frames (else every step below is "not checked"). **`$S main`
   first,** so BatteryPulse has a window and a Dock icon (it is an agent app), and only then the one
   computer-use access request. `$S ui access`, `$S proof P1 --image <shot> <x> <y>`, `$S widget
   <name> ...` for each of his widgets (`$S ui frame --widgets`), `$S desktop-spot ...`, `$S proof
   P11`. Notification Center can't be granted to computer use: the widgets are the script's crops. If
   a widget is blank or gone now, add it again from the gallery by computer use first (`change
   desktop-widgets` first).
3. Read BatteryPulse's Settings (General, Menu Bar, Notifications) by computer use, a shot each: the
   before set. `$S after before`.
4. Check for Updates, then Install and Relaunch to 0.7.1, by `$S ui press BatteryPulse ...`; `$S after
   after` (it reads the feed's modes and the widget's exception too: `D3-feed`); read About, What's
   New, History, the settings and the menu bar by computer use. Login Items only by `$S pane
   login-items` and `$S ui tree "System Settings" --match BatteryPulse`, which says only whether the
   row exists: no screenshot of that pane, which lists his other apps. Answer each `D3-*` it asks.
   Then `$S capacity after` with System Settings → Battery → Battery Health's shot: `D3-capacity`.
5. **A 2 or 4 for `D3-widgets`, or any other failure:** say in Russian that the cloud session will, on
   his yes, mark v0.7.1 a prerelease; nothing on this Mac does that. A 3: the notes say "add it again".
6. **The version count,** only if the release PR's post says v0.7.0's week-later count read 0 (PLAN.md
   V-0 item 5; else the week-later count is its sign): with Check for updates on anything but Never,
   `$S count-check`; on `counted`, `$S count-check stats` as a background task, waited on with `$S
   wait 9` twice; answer `D3-count`. On `noCounter`, failed or no line: note the printed code.
7. `$S after popover`; answer `D3-first-day`. Then `$S send --dry-run`, his yes (`D3-send`), `$S send`,
   and a short summary for him in Russian to forward to the cloud session.

## Feed check

PLAN.md §6.5's middle way, Q71-1's 2: about an hour hands-free from his own 0.7.0 with his widgets
placed, no logged day. No BatteryPulse or macOS update before it starts: step 4 needs his 0.7.0 and
his placed widgets. His part: the line, his yes, quitting his apps (the Claude desktop app among
them) and choosing Later for a pending macOS update, the approvals, his yes before `send` (about 3
minutes).

1. Say in Russian what happens: the release candidate over his 0.7.0, which comes back at the end
   with his settings and data (his history kept, the candidate's feed removed); his remembered
   iPhones and iPads hidden until then; BatteryPulse's language for one look; a large, a History and
   an iPhone & iPad widget from the gallery (removed at the end unless he keeps them); the medium
   widget's choices for a while. On his yes: `$S answer --by person F-yes y`, `F-usage`,
   `F-keep-widgets`.
2. `$S prepare` as a background task, waited on with `$S wait 9` (the backup, RC-U, the tools).
3. At its beep, ask him to quit his apps, the Claude desktop app among them, and to choose Later for
   a pending macOS update. `$S preflight` (its DO lines to him); **`$S main`,** then the one
   computer-use access request; `$S proof P1 ...` at his small or medium widget, `$S widget small
   ...` and `$S widget medium ...`, `$S desktop-spot ...`.
4. `$S feed before`. Step 2's second half as R1 step 3 does it, on his widgets (the medium one's
   Custom choices, with `change widget-choices "<his, from its sheet>" Custom` first and his back at
   step 9; a large widget; `placed second before`, `install U`, What's New closed by `$S ui press
   BatteryPulse --menu-cmd w`, `placed second 1`, `5` and `compare`, answers `R2-*`).
5. A History medium and an iPhone & iPad small widget from the gallery, as R1 does it (`change
   desktop-widgets`, `widget`, `gallery`, `R3-*`); `$S feed history`, then `$S feed cold`.
6. The language the user's way on one widget: R1 step 5.3's first half (`change app-language`, the
   Applications pane, `$S language ru`, `R4-3-widgets`), then back (`$S language back`, `restored`).
7. "One device": R1 step 5.6's iPhone & iPad half (`R4-6-device`), with `change widget-choices`.
8. `$S click-widget history`, `$S click-widget device`; then `$S faults` (0 expected).
9. `$S restore end`; each `RESTORE` item, `restored` after it; `$S summary end`, told to him in
   Russian. Then `$S batch`, `$S send --dry-run`, his yes (`F-send`), `$S send`.

## Answers

Steps print `ASK <id> [who; kind]: <question>` and `LOOK` lines. Look at every picture they name. A
`judge` question is yours: `$S judge <id> <answer> [--unsure] [note]`, the note in English naming the
picture (`medium-1min.png shows 80 % On battery`). A `person` question is his: `$S answer --by person
<id> <value> [note]`. `y` always means "looks right"; numbered questions take the number. Where the
script measured pixels (`blank`, `contrast`), `judge` compares; if you disagree, or are unsure, the
item goes to his batch at the day's end. Never guess: unsure is `--unsure`.

| Question | Criteria | Can't tell or no answer |
|---|---|---|
| `prep-*` | the value the read or the pane's shot shows | `unknown` (never changed) |
| `R-capacity-*`, `D3-capacity` | the Battery Health pane's Maximum Capacity in its shot, as `<n> %` | `unknown` |
| `R2-062-*`, `R2-small` | after the desktop click, against `-before.png`: 1 the same layout with fresh values (G7-2) | `--unsure` |
| `R2-medium`, `R2-large` | 1 the medium's Custom choices kept; the large shows the History chart in place of its last two rows | `--unsure` |
| `R2-whats-new-*` | both shots about 520 points wide, every row and line readable in English and Russian, nothing cut | `--unsure` |
| `R-feed-*`, `D3-feed` | the script records them from its reads; add a note only | his batch (the script's unsure) |
| `R3-<name>` | the crop against the CI render of that kind and family in `previews/` (the look check's PNGs without them): the same layout, readable, nothing cut | `--unsure` |
| `R4-1-chooser`, `R4-6-*` | the sheet's own words in its shot; 4.6's chooser opening is enough (no device is remembered then) | `--unsure` |
| `R4-1-shows`, `R4-2-kept`, `R4-5-automatic` | the crop or the sheet shows exactly the choices of 4.1 (Custom, the first three details and Average drain, time left if offered, monochrome) | `--unsure` |
| `R4-3-sheet` | 1 every word Russian but names and units; 2 an English word (name it: a fix before release); 3 the sheet stayed English | 3 (not checked) |
| `R4-3-widgets` | after `language ru` saw the reload and a new extension: 1 Russian, 2 English (which) | not checked (no redraw) |
| `R5-*` | every widget readable; a low or Service Recommended state still shows without colour; the contrast beside it | `--unsure` |
| `R6-12-hour`, `R6-tick`, `R6-count-toggle` | the times as `4:39 PM`; the minutes down by one, no seconds, no minus sign; the toggle and footer readable, greyed out under Never | `--unsure` |
| `R7-tree`, `R7-tree-ru` | no symbol name, the charge one element with its value, one element per row, no empty group, a chart one element with one label | `--unsure` |
| `R7-text-size` | 1 grow, 2 unchanged (expected), 3 cut off (a fix before release) | 2 |
| `R8-*` | quit, running, main and compact: Overview; accessories: Accessories; health: Health; history: History; device: the device's page, or Devices with none remembered (an activity route opening Overview is 2, naming the route) | 3 with what the log shows |
| `R9-plug` | each crop's state matches `bpulse --json` of its row within a minute; at his limit: Not charging, then Charged to limit once bit 24 appears | `--unsure` |
| `R9-accessory` | 1 the Accessories widget changed within a minute | 3 |
| `R9b-*` | Charged to limit on Overview, the popover and the compact window, Charge limit: Reached on Power; in Russian the catalog's terms | `--unsure` |
| `R-settings` | each pane's end in its shot: the last row's control whole and reachable; a pane that fits shows no scroll bar | `--unsure` |
| `V01-menubar` | the item legible on the light and the dark bar, not clipped | `--unsure` |
| `R-menu-bar-same` | 1 the script's diff found every pair identical; else 2, naming the pairs it lists | `--unsure` |
| `R-raw-history-rc` | 1 History at once; 2 History's title over Raw Data's table first (how long: 0.3 s, 2 s, 8 s) | 3 |
| `F12-widget`, `F12-new-kinds` | before against after: 1 same (the new kinds: their last picture kept), 2 blank or grey, 3 gone, 4 different | `--unsure` |
| `R-*` (his) | his answers | `R-back` 4 hours after the start; `R-keep-ax` n; `R-keep-widgets` n; `R-send` n (nothing is sent) |

Every item left "not checked" or "not run" takes its gate's default (PLAN.md §7.1).

## R3: the day's end (on his "day-end")

1. `$S day-end` (it needs him at the Mac: the screen unlocked; if it refuses, ask him to log in and
   touch the trackpad, then again). It stops the stream and records perf-stats per kind (Battery,
   Accessories, History, iPhone & iPad), the feed's writes and reads per day, the crash reports, the
   faults, W-13's lines and the assertions.
2. **The plug, with him:** say: "At the first beep unplug the adapter; at the second beep, 70 seconds
   later, plug it in again." `$S plug` (about 4 minutes): every kind's crops, and the reloads and
   currentConfigurations()' answers over it; answer `R9-plug`.
3. `$S capacity day-end` with System Settings → Battery → Battery Health's shot: `R-capacity-day-end`.
4. **F12:** `$S f12 rate` (fewer than 10 requests left: wait in the background for the reset, at most
   an hour, with `$S wait 9`, then again; else "not run: rate-limited"). `$S install F`, `$S f12
   before`; Check for Updates, then Install and Relaunch, by `$S ui press BatteryPulse ...`; `$S f12
   after`; answer `F12-widget` and `F12-new-kinds`.
5. `$S batch`: the items you answered 3 or unsure, offered in one line ("N items I wasn't sure about:
   look now, or skip and they keep their defaults?"); on "look", give each picture's full path (he
   types `! open <path>`; you never open a file by computer use) and record each with `--by person`.
6. `$S send --dry-run`; give him its `SHEET` the same way, summarize `~/bp-071/R/R.md` in Russian, and
   ask whether he added any allow rule beyond the launcher's (`note` his answer). On his yes, `$S
   answer --by person R-send y`, then `$S send`. A lint refusal names a line: drop it, tell him, dry
   run and his yes again.
7. `$S restore end`: his own BatteryPulse, his settings and data back, the logged day's history kept,
   the candidate's feed gone; then each `RESTORE` item (the gallery's widgets he didn't keep removed
   by computer use, anything not confirmed earlier). `$S summary end`, and tell him in Russian what is
   back and what is his (the Focus; at the end of the series, Terminal's Accessibility, unless he
   keeps it). End.

## Before Session R (him)

Not printed for the session (its launcher stops at "The short sessions"): what he does himself.

### Once, any day before (about 1 minute)

1. Quit any other Claude session on the Mac: one at a time.
2. Don't install a macOS update or a BatteryPulse update until the series ends, so the sessions see
   the updates they test (Session R backs up the BatteryPulse he runs then); an update banner also
   covers the screen.
3. In `~/BatteryPulse`: `claude`, then `/mcp`: `computer-use` is enabled (kept per project from
   Session B; if not, Enable). He asks that session: `Check the launcher docs/plans/0.7.1/start-session-r.sh
   (git fetch origin claude/071-integration && git show FETCH_HEAD:docs/plans/0.7.1/start-session-r.sh)
   against claude --help and the Claude Code documentation, and answer me in Russian.` It checks that
   `--allowedTools`, `--permission-mode auto`, the rule `Bash(<prefix>:*)` with `~` as written, and
   `DISABLE_AUTOUPDATER=1` are still the documented spellings, and changes nothing; a changed spelling
   it writes out for him, changing only that spelling.

### The start (on the adapter; a daytime session works)

In Terminal, from any folder:

```
git -C ~/BatteryPulse fetch origin claude/071-integration
bash <(git -C ~/BatteryPulse show FETCH_HEAD:docs/plans/0.7.1/start-session-r.sh)
```

The launcher changes to `~/BatteryPulse` and runs the start line of PLAN.md §6.2: one allow rule,
`Bash(bash ~/bp-071/R/run/docs/plans/0.7.1/m5-session.sh:*)`, auto mode, and a sentence that has the
session fetch `claude/071-integration` and read this file up to "The short sessions"; it begins at R0.
