# M5 Session R8: the hands-free runbook

Session R8 of BatteryPulse 0.8 (PLAN.md §6.4-§6.5, on `docs/plans/0.8.0/PLAN.md`) runs on the
release candidates on the MacBook Air M5, after D1. One local Claude Code session with computer use
does every step itself, through `m5-session.sh` and its `ui` helper, and a plain script in a second
Terminal window, the arm window, keeps the display awake for the GUI phase and starts the logged
day. It is built on 0.6.2's Session B and 0.7.1's Session R, whose rules and privacy hold here, with
their lessons applied. The maintainer does only what needs a person: the start line and one yes,
quitting his own apps (the Claude desktop app among them), postponing a pending macOS update, the
permission prompts, the Focus, the adapter at two beeps, his typed "day-end", and his yes before
`send` (about 6-8 minutes at the start, 3-4 at the day's end).

Each start line prints one section of this file, by `section.sh` (PLAN.md §6.0 rule 1): "R8" for
Session R8, "Hold watch" and "After publishing" for the short sessions. Each names the other
sections its session reads, from its own frozen worktree under `~/bp-080/`. His own part, "Before
Session R8 (him)", is the last section and is printed for no session.

## R8

You run BatteryPulse 0.8's Session R8. The start printed this section alone. `$S` stands for
`bash ~/bp-080/R/run/docs/plans/0.8.0/m5-session.sh`, written in full in every call. First:

1. **The worktree.** `git -C ~/BatteryPulse rev-parse FETCH_HEAD` is the commit section.sh read
   this from. If `~/bp-080/R/run` exists, read its commit (`git -C ~/bp-080/R/run rev-parse HEAD`):
   the same commit is a restart (read that copy's "If the session restarts or compacts" and go on
   from there); another commit: ask him whether this is a new attempt; on his yes, `git -C
   ~/BatteryPulse worktree move ~/bp-080/R/run ~/bp-080/R/run-<its first 7 characters>`. Then `git
   -C ~/BatteryPulse worktree add --detach ~/bp-080/R/run FETCH_HEAD`.
2. **`$S prepare attempt`**, your first script call (an earlier attempt's folder moves aside once its
   changes are back; if it lists some, follow its message: `--kept` on his word, `--restored` after
   you put one back and shot it).
3. **Read**, with your file-reading tool, these sections of
   `~/bp-080/R/run/docs/plans/0.8.0/SESSION-R.md`: Rules, Privacy, Decisions you make alone, R0, R1,
   R2, R3, If the session restarts or compacts, and Answers. Hold watch and After publishing are
   other sessions': never act on them.
4. Then `$S help` and `$S status`, and begin at R0.

## Rules

- **Language.** Talk to him in Russian, always. Everything recorded is English: `answer`, `judge`,
  `note`, `change`, `restored`, `attach` captions; the script refuses Cyrillic.
- **One prefix.** `$S` is the script of your session's own frozen worktree (Session R8's:
  `bash ~/bp-080/R/run/docs/plans/0.8.0/m5-session.sh`; a short session's section names its own).
  Write it in full in every call, exactly so, one script call per Bash call: no `cd`, no variables,
  no pipes, no redirection, no `&&`. The only commands outside it are the start's `git fetch`, `git
  show`, `git rev-parse`, `git worktree move` and `git worktree add`, under auto mode. `$S help`
  lists the commands, and the header of `ui.swift` beside the script lists `ui`'s. Read files
  (shots, crops, logs, `R.md`, `answers.tsv`, `changes.tsv`) with your file-reading tool, never with
  a shell command.
- **Frozen.** The runbook, the script and `ui` are fixed at the start's commit. Never edit them,
  never fetch again, never adopt a later fix: a fix goes to the next session.
- **Permissions.** Never add or change a permission rule, never change Claude Code's or git's
  configuration, never retry a command auto mode blocked (its step is "not run: blocked"). Never
  type a password, never approve a permission or authorization dialog, never toggle anything in
  Privacy & Security, Users & Groups or Passwords.
- **Long calls.** Give every script call the Bash tool's `timeout: 600000`; it matters for every
  call over 2 minutes (`preflight`, `placed his 5`, `placed 062 5`, `app-language`, `language`,
  `display-shots`, `menubar`, `look`, `tick`, `count-toggle`, `plug`, `f12 after`, every `restore`,
  `widgets-check`, `day-end`, `send`). Anything near the tool's 10-minute limit runs as a background
  task: `prepare`, `wp18 timing` and `charge-limit hold wait`. **Never end your turn while a
  background task runs:** wait on it with `$S wait <minutes>` (1-9) in the foreground, with
  `timeout: 600000`; it returns within a minute of the task's end, or after that many minutes; then
  read the task's output, and wait again until it ended. Never `sleep`, and never a quick loop of
  reads. While a task runs, the screen is the task's: no GUI action.
- **Heartbeat.** Every script call but `help` and `status` touches it, and the script keeps its own
  every minute while a call runs (at most 45 minutes). After `mark away` the arm window takes 20
  minutes without either for a stall and starts the logged day without you. So after `mark away`
  never let 10 minutes pass without a script call: after each step, between computer-use batches
  and at least every 10 minutes, `$S heartbeat "<step> done, next about HH:MM"`. It prints the GUI
  phase's minutes left.
- **After `ready`, nothing acts until his "day-end".** Check `$S status` before every step. A message
  that reaches you on the logged day gets a text-only answer (say: "the results come at the day's
  end"), with no tool call, unless it is "day-end".
- **Order of means.** The script and `ui` (AX, CGEvent, CGWindowList) first, computer use where they
  can't reach. Neither ever sends Esc (it would end your turn) or a key press `ui`'s rules don't
  allow. Before any change by computer use or AX outside the script: `$S change <setting>
  <original> <new>`; after putting it back: `$S restored <setting> <how it was confirmed>`. A
  setting whose original is unknown is never changed. The setting names: `widget-style`,
  `dim-widgets`, `text-size`, `increase-contrast`, `reduce-transparency`, `reduce-motion`,
  `cross-fade`, `show-borders`, `liquid-glass`, `keyboard-navigation`, `24-hour`, `open-at-login`,
  `bluetooth-accessory`, `widget-choices`, `charge-limit`, `desktop-widgets`, `history`. The
  script records and puts back its own (the app, its settings and data, its language, the window
  style, the appearance and wallpaper of its shots, `hasSeenWelcome`, the sentinel file).
- **The session's widgets** (T-1 item 7). Every widget you add from the gallery is a
  `desktop-widgets` change first. They come back only by BatteryPulse's own counts of the placed
  widgets against prepare's: after removing them, `$S widgets-check`; never `restored
  desktop-widgets`, which the script refuses.
- **The rules from 0.6.2's and 0.7.1's sessions** (PLAN.md §6.0, T-1 item 5):
  1. The start printed only its runbook section (section.sh); read only the sections it names.
  2. **Dock presence before access:** `$S main` before computer use asks for access to BatteryPulse,
     and before your first computer-use action in it (an agent app has no Dock icon otherwise).
  3. Widgets are shot by the script (`screencapture -R` at the frames `ui` reads), never by
     computer use: Notification Center, their host, can't be named in a computer-use request.
  4. Every widget or picture check causes its own redraw and waits for it (a reload, the
     extension's new process or the app's reload line) before its shot; no redraw within its
     timeout is "not checked", never "n". The script's steps do it.
  5. Preflight asks him to quit the Claude desktop app and to postpone a pending macOS update.
  6. Computer use ends each batch with a pointer move to bare desktop (its 28×40 overlay fails the
     occlusion check); after the script's desktop clicks, which end the revealed desktop
     themselves, a DO line says when one computer-use click on bare desktop must end it.
  7. Window shots are the script's (`screencapture -R` at the window's frame after the occlusion
     check, never `-l`, which leaves out what lies behind a glass sheet).
  8. A BatteryPulse window is closed by its own close button, or with BatteryPulse made active
     first (Session F: a Command-W reached no window of an inactive agent app): the script does it.
  9. A routine feed write is read from the feed's `writtenAt`, never from a log line (a routine
     write logs none): the script does it.
  10. The widget edit sheet's menus and Language & Region's per-app menu are out of computer use's
      reach (Session F): the sheet's pop-up buttons, menu items and Done by `$S ui press "widget
      sheet" "<label>"` (only while it shows a BatteryPulse widget's description), BatteryPulse's
      own language by `$S language ru | back` and `$S app-language ru | back`, which write it the
      way that menu does.
- **System Settings.** Open panes by computer use from the sidebar: on macOS 27.2 the URLs of
  Appearance, Desktop & Dock and Displays open other panes, and the sidebar's selection can't be
  read (Session B's P8). `ui` acts only in a pane P8 confirmed by its title. The Battery pane's URL
  works (`$S pane battery`).
- **Places.** Terminal windows in the left third of the screen, BatteryPulse's windows and widgets
  on the right, away from the top-right corner where banners land.
- **Commits.** You commit and push nothing. The only push is `send`'s, to your session's results
  branch (`claude/080-session-r`, `-h` or `-d3`), committed in UTC, after his yes. No other branch,
  no pull request.

## Privacy

- Every picture you read, and every computer-use screenshot, goes to the model; none goes into the
  repository but the crops you attach. His Focus, the apps he quit and the hidden apps limit what
  they show; his other desktop widgets are in them (the start message says so).
- No computer-use screenshot while Notification Center or Control Center is open: AX actions and
  the script's crops of BatteryPulse's frames instead. No computer-use screenshot of System
  Settings → Bluetooth (device names): AX presses only, and `accessories-watch`'s crops.
- Full-desktop, Notification Center and System Settings shots stay in `~/bp-080/R`. Only crops of
  BatteryPulse's windows, widgets and menu bar item are attached (`$S attach`), never one taken
  while BatteryPulse remembers an iPhone or iPad by name or its widget feed holds one (the script
  refuses those). The Accessories page and the Accessories and iPhone & iPad widgets' trees and
  crops show names: read them, never attach them, never write a name.
- Report a Problem's saved files stay on the Mac (`report-check` reads them; the report gets only
  counts). After a save BatteryPulse opens GitHub's issue chooser in his browser: no computer-use
  screenshot while that browser is in front; bring BatteryPulse forward with `$S main`.
- `pmset -g accps`, `pmset -g log`, `pmset -g battlimit` and `scutil` outputs reach `R.md` only as
  the script writes them; `send`'s privacy lint enforces it. A `KEEPAWAKE` line names another app's
  process: say it to him, and nowhere else.

## Decisions you make alone

- **A step fails or misbehaves:** read the message; run it once more only if the cause was passing
  (a window not up yet, a timeout); else `$S note "<step>: <what happened>"`, and its items are "not
  checked" or "not run" with the reason; go on. A harmless workaround is allowed only if it changes
  no setting outside `changes.tsv`, and is noted.
- **Never repair the Mac's state by hand:** no `killall` or restart of a system process (chronod,
  Dock, WindowManager, Notification Center, cfprefsd), no `lsregister`, no install, swap or copy of a
  build except through the script.
- **The order is fixed:** 0.8's own steps first, then step 11c (PLAN.md §6.4). Skip ahead only while
  a step waits; come back to it once, later in the GUI phase, else at the day's end.
- **A spoiled take** (a banner over the widgets, his touch): run that one step again once; the rerun
  replaces its section; note the first take. Then answer 3 or `--unsure`.
- **A banner at layer 23** (the Claude desktop app's, Software Update's) that refuses a click: note
  it and go on to steps that don't need the desktop; never press a button in it.
- **A failed proof** prints its fallback: switch that proof's steps to it.
- **A prompt or a password dialog:** while he is there, ask him to answer it; while he is away,
  leave it, record "not checked: prompt", and go on. An Xcode components prompt is his at the start
  (R0), else Accessibility Inspector's and Xcode's steps are "not run".
- **A lock screen or the lid closed:** stop all GUI work, record "not checked: locked", and wait.
- **He touches the Mac during the GUI phase:** if P6 showed that the HID event state tells his
  touches apart (`ui guard`), wait until his last touch is a minute old. On his Esc your turn ends;
  on his "go on", check the state first (`$S status`, a shot) and carry on.
- **Findings** (crash reports, a wrong value, a widget that looks wrong, a label missing): note them
  with their evidence and go on; never investigate beyond the step's reads, never patch anything.
- **Anything not on the yes-list:** never change it; a step that would need it is "not checked".
- **Time and your usage limit:** the GUI phase ends 10 minutes before he is back, at most 4 hours
  after `mark away` (`heartbeat` shows the minutes left). Past 3 hours, or if `/usage` or the CLI
  warns that the limit is near, drop step 11c's extras first, then step 11b, then step 11c's
  remaining items in reverse order: each one dropped is `$S note "<item> not run (time)"`, and it
  stays open in `docs/VERIFICATION.md` with that reason. 0.8's own steps (2-11) come before any of
  them.
- **Anything this file doesn't cover:** do what changes nothing, record "not checked" with the
  reason.

## R0: the start (he is there, about 6-8 minutes)

1. **The start message,** one message in Russian, before anything changes:
   - What may change, each written to `changes.tsv` first and put back: the installed BatteryPulse
     (the release candidate RC-U over his 0.7.1; v0.6.2 for some minutes of step 11c, then RC-U
     again; RC-F at the day's end; his own 0.7.1 comes back from the backup at the end, with his
     settings and data); BatteryPulse's settings and data for the GUI phase (his settings come back
     for the logged day), his remembered iPhones and iPads hidden for it; Keyboard navigation turned
     on; the accessibility display options (Reduce Motion, Prefer Cross-Fade Transitions, Reduce
     Transparency, Increase Contrast, Show Borders, the Liquid Glass slider) and Text size, each
     switched and put back; Icon & widget style, Dim widgets on desktop, the 24-hour setting; the
     appearance (Light and Dark) and a plain wallpaper for some shots (put back by the script, read
     back); BatteryPulse's language and its window style (Standard and Frosted for the audit);
     Check for updates and Window to open (his come back); the edit sheets' choices (back to
     Automatic); widgets from the gallery, of every kind and size (removed at the end unless he
     keeps them, and confirmed gone only by BatteryPulse's own count of the placed widgets); a
     Bluetooth accessory disconnected and reconnected by an AX press; a sentinel file placed and
     removed; Report a Problem's files saved into the session's folder (his browser then opens
     GitHub's issue chooser); the Charge Limit only if step 9 runs (his yes below).
   - What the end keeps and removes: the logged day's history stays; the widget feed the candidate
     writes goes with the rest of the session's data. Near the GUI phase's end the session clears
     BatteryPulse's history once; his comes back from the backup for the logged day (the GUI
     phase's own hours go).
   - Never: a VPN, anything in Privacy & Security, Users & Groups or Passwords.
   - The questions: when is he back at the Mac (else 4 hours from now; the GUI phase ends 10
     minutes before)? Keep Terminal's Accessibility after Session R8 (else a reminder at the end)?
     Keep the gallery's widgets? Step 9, the Charge Limit live: set to the hold and put back, only
     if G8-1 passed (PLAN.md's Appendix C at this commit says)? And: "Please type /usage now and
     tell me what it shows."
   - Privacy: the pictures go to the model and stay on the Mac; his other desktop widgets appear in
     them.
   - Times: about 10 minutes of building (BatteryPulse relaunches once to count his placed widgets),
     then a beep and about 6 minutes with him (his apps quit, the Claude desktop app among them; a
     pending macOS update postponed; the approvals; an Xcode components prompt, if one comes); then
     he may go, with a Focus on. The GUI phase runs on its own, about 2-3 hours, at most 4. Then
     the logged day starts by itself: he turns the Focus off and uses the Mac as usual, and at the
     day's end writes "day-end" here (3-4 minutes then, the adapter at two beeps among them).
   - End your turn and wait for his answer.
2. **Record** (only on an explicit yes): `$S answer --by person R-yes y`; `R-back HH:MM` if he gave
   one; `R-keep-ax y|n`; `R-keep-widgets y|n`; `R-limit y|n`; `R-usage "<what he said>"`.
3. **`$S prepare`** as a background task (about 10 minutes), waited on with `$S wait 9`. It ends
   with `BEEP (prepare is done)`; his 0.7.1 stays installed for step 2, and prepare has recorded the
   placed widgets as his BatteryPulse counts them. If it fails twice, tell him why, run `$S restore
   end` if `changes.tsv` lists anything, and end.
4. At the beep, say: "The build is done. Please quit your own apps (Terminal stays), the Claude
   desktop app among them and any utility that keeps the Mac awake, and if Software Update offers
   an update, choose Later. Then write me that you are back." End your turn.
5. **Access, the reads and the proofs** (he is there). `$S ui access` (if `ax_trusted=no`, ask him
   to turn Terminal on under System Settings → Privacy & Security → Accessibility, then again).
   **`$S main`** (rule 2), and only then one computer-use access request for BatteryPulse, System
   Settings, Finder, Xcode and Accessibility Inspector. `$S prepare reads`; open System Settings →
   Appearance, → Desktop & Dock and → Keyboard by computer use from the sidebar, `$S shot
   settings-appearance`, `$S shot settings-desktop`, `$S shot settings-keyboard`, and answer
   `prep-*` from the shots. `$S proof P1 --image <shot> <x> <y>` at one of his BatteryPulse widgets'
   centre, then `$S widget <name> <x> <y> <w> <h>` for each of his BatteryPulse widgets (`$S ui frame
   --widgets` lists the frames; a Battery widget is `small`, `medium` or `large`, the other kinds
   `accessories-`, `history-` or `devices-` with the size), and `$S desktop-spot --image <shot> <x>
   <y>` on bare desktop away from icons and widgets. With no BatteryPulse widget of his, P1 waits for
   step 11c's first one.
6. Say: "For the next five minutes please don't touch the keyboard or the trackpad; answer any macOS
   prompt that appears." `$S preflight`: its DO lines go to him in Russian (the Claude desktop app, a
   pending update, a keep-awake holder: the name to him only). Then P10: one widget click-to-add in
   the gallery and its removal (`$S change desktop-widgets "his, as prepare counted them" "P10's one
   added and removed"` first), a screenshot right after the first action, one System Settings
   click, the pointer moved to the desktop spot; then `$S proof P10 pass|fail "<what it showed>"`.
   `$S open-app "Accessibility Inspector"` and `$S open-app Xcode` once: an Xcode components prompt
   is his to answer now. Then each command family once, as preflight's `RUN` lines say.
7. `$S arm open`, then `$S mark away` (no sound or speech from here until his "day-end"). Say: "A
   Terminal window named BatteryPulse arm opened; leave it open, the Mac on the adapter, the lid
   open. Please turn a Focus on. You may go; when you are back, read my summary first, turn the
   Focus off, and use the Mac as usual. At the day's end write day-end here." Go straight on to R1
   in the same turn.

## R1: the GUI phase (he is away; about 2-3 hours, capped at 4)

0.8's own steps first (2 to 11b), then step 11c, the checks 0.7.0 and 0.7.1 shipped without
(PLAN.md §6.4). `heartbeat` after each step. A surface is BatteryPulse's page or window that the
session opens by AX (`$S ui select-row BatteryPulse "<sidebar row>"`, `$S ui press BatteryPulse
"<label>"`, `--menu-cmd`, `--status-item`) or computer use; in Russian, AX takes the Russian labels
(`$S ui tree BatteryPulse --match <word>` finds them). A window the session opened is closed by its
own close button, `$S ui close BatteryPulse --window "<its title>"` (rule 8).

1. **Capacity:** `$S capacity start`; System Settings → Battery → Battery Health by computer use (a
   shot); answer `R-capacity-start`.
2. **Step 2, RC-U over his 0.7.1:** `$S feed before` (answer `R-feed-before`); `$S placed his
   before`; `$S install U`; `$S whats-new rc`; About BatteryPulse by `$S ui press BatteryPulse "About
   BatteryPulse"`, `$S screen about front` (it reads 0.7.99), then closed; `$S placed his 1`, `5` and
   `compare`, answer `R2-<name>` for each of his Battery widgets (one he hasn't placed: "not
   checked: none placed"); `$S whats-new rc ru`, answer `R2-whats-new-rc`.
3. **Step 3, BatteryPulse's trees VoiceOver walks (C10):** for each surface, open it, then `$S
   app-tree <surface>`: the pages (`overview`, `power`, `history`, `health`, `accessories`,
   `iphone-and-ipad`, `raw-data`, `demo-mode`); `compact` (`$S ui press BatteryPulse "Compact
   Window"`, back by "Full Window"); `popover` (`$S ui press BatteryPulse --status-item`, the same
   press closes it); each Settings pane (`$S ui press BatteryPulse --menu-cmd ,`, then each tab:
   `settings-general`, `settings-menu-bar`, `settings-notifications`, `settings-advanced`);
   `about`; `whats-new` (Help → What's New); `software-update` (Check for Updates…); `welcome` (`$S
   welcome` opens it); `report-problem` (Help → Report a Problem…). Read each `READ` file: every
   control a role and a label, only decorative images without one, the power flow, the capacity bars
   and each ring one element with a value; answer `R-tree-app`. The Russian pass is step 8's: there,
   the same surfaces with `$S app-tree <surface> ru`, answer `R-tree-app-ru`. **The charts (X-1):**
   on History (24 Hours and 7 Days), each chart's element in `app-tree history`'s file: its label,
   and its descriptor where AX shows one; where it doesn't, `$S open-app "Accessibility Inspector"`,
   pointed at each chart by computer use, a shot each (`$S shot chart-<n>`); answer `R-charts`. **The
   widgets' trees** run in step 11c's gallery batches, every kind and family, in English and Russian
   (`R7-tree`, `R7-tree-ru`).
4. **Step 4, the keyboard (C10):** Keyboard navigation on, unless prepare read it on: `$S change
   keyboard-navigation off on`, System Settings → Keyboard by computer use, the toggle; a shot.
   Then, BatteryPulse in front (`$S main`): `$S keys walk main 30` (the sidebar, the toolbar);
   arrows in the sidebar (`$S keys down`, `$S keys up`); Raw Data's table and filter (its row
   selected, `$S keys walk raw-data`); a Settings pane with tile pickers (`$S keys walk
   settings-general`, `$S keys right` on a picker); the update window (Check for Updates…, `$S keys
   walk update 10`); Report a Problem (`$S keys walk report 15`: Save… reached and focused, never
   pressed). Read each `READ` file: each path reached is y; one that can't be reached names its
   control; answer `R-keyboard`. Then `$S raw-history rc` (History over Raw Data's table, I-15),
   answer `R-raw-history-rc`. Keyboard navigation back by computer use, `$S restored
   keyboard-navigation "<the pane's shot>"`.
5. **Step 5, the contrast audit (A11Y-03):** `$S open-app "Accessibility Inspector"`, its target
   BatteryPulse, its audit on each page by computer use, a shot per audit (`$S shot
   audit-<page>-<style>-<appearance>`), in `$S window-style standard` and `$S window-style frosted`,
   each in `$S appearance-set light` and `$S appearance-set dark`, then once with Increase Contrast
   on (`$S change increase-contrast off on`, System Settings → Accessibility → Display by computer
   use). The beta styles are exempt. Answer `R-contrast`, the failures listed in the note. Then `$S
   window-style back`, `$S appearance-set back` (Auto comes back by computer use, as it says), and
   Increase Contrast stays on for step 6.
6. **Step 6, Stage 1.4's pass (A11Y-02) and step 7, the menu bar icons (A11Y-04):** each display
   option switched by computer use (System Settings → Accessibility → Display, and → Motion for
   Reduce Motion and Prefer Cross-Fade Transitions; `$S change <setting> <his> <new>` first), then
   `$S display-shots <tag>`, then back and `$S restored`: Increase Contrast (still on from step 5:
   `$S display-shots contrast`, then `$S menubar contrast`, then off), Reduce Transparency (on:
   `$S display-shots transparency`, `$S menubar transparency`; off), Reduce Motion, Prefer
   Cross-Fade Transitions, Show Borders, the Liquid Glass slider at each end. Answer `R-display`
   from the shots against Stage 1.4's open check, and `R-menubar-a11y` from the crops. Then `$S
   menubar` (the plain dark and light bars), answer `V01-menubar`.
7. **Step 8, the Russian pages:** `$S app-language ru`; `$S pages ru` (every page); each window
   (Settings' panes, About, What's New, Welcome, Report a Problem, the compact window) opened as in
   step 3 and shot with `$S screen <name> front`, the popover with `$S screen popover popover`; step
   3's Russian trees on the same surfaces (`$S app-tree <surface> ru`, `R-tree-app-ru`). Answer
   `R-russian` against the Russian review's answers. Then `$S app-language back`.
8. **Step 9, the Charge Limit live** (only with `R-limit` y and G8-1 passed; else `$S note "step 9
   not run: <why>"`): `$S change charge-limit <prepare's> <n>` (the step at or just below the
   charge; under 80 %, 80), System Settings → Battery → (i) next to Charging, the slider by computer
   use, `$S charge-limit set <n>`, then `$S charge-limit hold` between the next steps, never inside
   one (a `HELD` read relaunches BatteryPulse), until `HELD` (at most an hour; with no step left
   before the hand-over, `$S charge-limit hold wait` as a background task, `$S wait 9` until it
   ends); then `$S pages limit Overview Power` and judge `R-limit-live` from the shots
   against the `HELD` read's battlimit. The slider back to prepare's value, `$S charge-limit back`.
9. **Step 10, Report a Problem on the RC:** Help → Report a Problem… by `$S ui press`; Save… with
   each choice (the second: Include the crash reports' contents) into `~/bp-080/R/report/` (the save
   panel by computer use; typing that folder's path there is allowed); `$S main` (no screenshot of
   the issue chooser); `$S report-check`, answer `R-report`.
10. **Step 11, the sentinel (P-1):** `$S sentinel place`; `$S screen sentinel-note`; Turn On Again
    by `$S ui press` as its DO line says; `$S sentinel check`; `$S screen sentinel-after`; answer
    `R-sentinel`. Devices only if device reading is on (it is off for the GUI phase: not run).
11. **Step 11b, optional:** `$S wp18 previews` (an Install Required dialog is "not checked:
    prompt"), and `$S wp18 timing` as a background task.
12. **Step 11c, the checks 0.7.0 and 0.7.1 shipped without** (their 0.7.1 IDs kept), in this order:
    1. **0.6.2's widgets across the update (G7-2):** `$S widget <name> none` for each of his
       recorded widgets (they stay placed; from here the script crops only the session's, which
       take the same names); `$S install start`
       (v0.6.2 over RC-U); a small and a medium Battery widget from 0.6.2's gallery (`$S change
       desktop-widgets "<as now>" "<added>"` first), recorded as `small` and `medium` (P1 now if R0
       had none); `$S menu-bar-shots before`; `$S placed 062 before`; `$S install U`; `$S whats-new
       062`; `$S placed 062 1`, `5` and `compare`, answer `R2-062-small`, `R2-062-medium`; `$S
       whats-new 062 ru`, answer `R2-whats-new-062`; `$S menu-bar-shots after`, answer
       `R-menu-bar-same`.
    2. **The gallery, in batches** (they don't all fit): (a) `large`, `accessories-small`,
       `accessories-medium`, `accessories-large`; (b) `history-medium`, `history-large`; (c)
       `devices-small`, `devices-medium`, `devices-large`. Each widget: Edit Widgets from the
       desktop's context menu (a Control-click on an empty spot), a search for BatteryPulse, the
       click-to-add, then one slow `$S ui drag`, with `$S change desktop-widgets "<before>"
       "<added>"` first and `$S widget <name> ...` after (`$S ui frame --widgets`); `$S gallery
       <name>`, answer `R3-<name>`. Per batch, once placed: `$S tree` (step 3's widget trees);
       then `$S language ru`, `$S tree ru`, `$S language back` (the first batch's `language ru`
       also answers 4.3's `R4-3-widgets`). Within 15 minutes of the first History widget, `$S feed
       history`, then `$S feed cold`. After each batch, remove its widgets by computer use but the
       working set (the small and medium Battery widgets, one Accessories, one History and one
       iPhone & iPad widget), each followed by `$S widget <name> none`. Answer `R7-tree` and
       `R7-tree-ru` after the last batch.
    3. **The edit sheets (4.1-4.6):** Edit Widget from a widget's context menu by computer use; in
       the sheet, its pop-up buttons, menu items and Done by `$S ui press "widget sheet"
       "<label>"` (rule 10), a computer-use screenshot to read it. `$S change widget-choices
       Automatic Custom` first. 4.1: the medium widget's Layout Custom, Details' chooser opened
       (answer `R4-1-chooser`), the fourth detail swapped for Average drain, Time set to time left
       (if offered), Colours monochrome, Done; `$S edit-shot custom`, answer `R4-1-shows`. 4.2: Edit
       Widget again, answer `R4-2-kept`, Done; while it shows time left, `$S tick`, answer
       `R6-tick`. 4.3: `$S language ru`; Edit Widget on the medium widget in Russian, answer
       `R4-3-sheet`, Done; `$S language back`. 4.5: back to Automatic, `$S edit-shot automatic`,
       answer `R4-5-automatic`, `$S restored widget-choices "<the crop>"`. 4.6: `$S change
       widget-choices Automatic "4.6's choices"`; the History widget's options, one choice made,
       Done, `$S edit-shot history history-medium`, answer `R4-6-history`; the iPhone & iPad
       widget's One device, its chooser opened (no device is remembered now), answer
       `R4-6-device`; both back to their defaults, `$S restored widget-choices "<the crops>"`.
    4. **Rendering modes and places (G7-4):** Dim widgets on desktop to Always (`change dim-widgets`
       first), then Icon & widget style through Default, Dark, Clear and Tinted (`change
       widget-style` first), by computer use from System Settings' sidebar; after each, `$S look
       always <style>` and its answer. Then Dim widgets on desktop Automatically and the four styles
       again with `$S look auto <style>`; then for each style `$S look nc <style>` (Notification
       Center by the script, crops only). Then Increase Contrast on (`change increase-contrast off
       on` first), `$S look contrast` (it redraws the widgets first), off again and `restored`;
       Reduce Transparency the same with `$S look transparency`. Last, the style and Dim widgets
       back to prepare's values, each `restored` with the pane's shot.
    5. **Time and text size:** 24-hour time off by computer use (System Settings → General → Date &
       Time; `change 24-hour on off` first), `$S look 12-hour`, answer `R6-12-hour`; back,
       `restored 24-hour "AppleICUForce24HourTime reads 1"` after `$S status`. `$S count-toggle`,
       answer `R6-count-toggle` from its four shots. Text size to its largest by computer use
       (`change text-size <his> largest`), `$S look text-size`, answer `R7-text-size`, back,
       `restored`.
    6. **Clicks (G7-9):** `$S click-widget quit`, `running`, `accessories`, `history`, `device`,
       `main`, `compact`, each answered `R8-*` from its log lines and window shot. For `health`:
       the medium widget's main value set to maximum capacity in Edit Widget (`change
       widget-choices Automatic "main value maximum capacity"` first), `$S click-widget health`,
       answer, then back to Automatic and `restored`.
    7. **An accessory:** `$S change bluetooth-accessory connected disconnected`; `$S pane
       bluetooth`, the connected accessory's Disconnect by `$S ui press "System Settings" <its
       button>` (never a screenshot of that pane, never its name in a note); `$S accessories-watch
       disconnect`; connected again the same way; `$S accessories-watch reconnect`; answer
       `R9-accessory`; `restored bluetooth-accessory "connected again, pmset -g accps counts it"`.
       If the press can't reach it: "not checked".
    8. **Demo Mode:** `$S main`; Demo Mode's Charge limit scene by `$S ui select-row BatteryPulse
       "Demo Mode"` and `$S ui press BatteryPulse "Charge limit"`; `$S feed demo-start`; `$S
       demo-shots`; the compact window as its DO line says; answer `R9b-demo`. Then `$S
       app-language ru`, the scene again by AX in Russian, `$S demo-shots ru`, answer
       `R9b-demo-ru`, `$S app-language back`, the scene again; `$S feed demo-end`; Demo Mode left by
       its own control. System Settings → Battery → (i) next to Charging by computer use, answer
       `R9b-settings-ru`, else "not checked".
    9. **The feed's rewrites:** `$S feed reads-on`, then `$S feed reads-off` (each presses Read
       iPhone and iPad batteries by AX; never with an iPhone or iPad on a cable). Then `$S change
       history "his, in the backup" cleared`, Clear History in BatteryPulse's Settings → Advanced by
       computer use, its confirmation too, and `$S feed cleared`. Never Forget a device: the devices
       are his.
    10. **Settings on the Air's display (S-1):** each Settings pane and the Welcome window (`$S
        welcome`) by computer use, scrolled to its end, `$S front <pane>-end` after each; answer
        `R-settings`.

## R2: the hand-over (about 5 minutes)

1. `$S restore gui`; do each `RESTORE` item it lists, each confirmed by a read or a shot and recorded
   with `restored`. It put his settings, his remembered devices and his history back into the
   release candidate, which stays installed for the logged day; the session's widgets stay placed
   for it (the logged day measures every kind) and go at the day's end.
2. `$S summary`: from its lines, write the summary he reads before he uses the Mac, in Russian, on
   the Mac only (`R.md` stays English): an alert first for every `ALERT` line, then every setting
   the session changed with how it was confirmed, then: "Please turn the Focus off." Show it as your
   message text.
3. Stop every background task. `$S ready`, your last call. End your turn. From here only text
   answers until his "day-end"; the arm window starts the logged day (the perf stream under
   `nohup`, the display assertion released) and he may close it. On "day-end", read "R3: the day's
   end" in `~/bp-080/R/run`'s copy of this file first.

## R3: the day's end (on his "day-end")

1. `$S day-end` (it needs him at the Mac: the screen unlocked; if it refuses, ask him to log in and
   touch the trackpad, then again). It stops the stream and records the crash reports for
   BatteryPulse and BatteryPulseWidget since prepare and the `fault` messages (each must be 0,
   G8-10), perf-stats per kind, the Charge Limit reader's reads per trigger, the feed's writes and
   reads, and G7-11's reload delivery per kind.
2. **The plug, with him:** say: "At the first beep unplug the adapter; at the second beep, 70
   seconds later, plug it in again." `$S plug` (about 4 minutes): every kind's crops, and the
   reloads and the placed widgets' answers over it; answer `R9-plug`.
3. `$S capacity day-end` with System Settings → Battery → Battery Health's shot: answer
   `R-capacity-day-end`.
4. **Q8-6, the optional VoiceOver listen,** before F12, while the release candidate still runs: the
   listen is for 0.8's VoiceOver names (G8-6), and F12 leaves the published 0.7.1 installed until
   `restore end`. Ask him whether he has five minutes for VoiceOver on Overview, Power and Health in
   Russian (`$S app-language ru` first, `$S app-language back` after); he turns VoiceOver on and off
   himself (Command-F5). His answer is `R-listen` (`--by person`); without one, skipped.
5. **F12 (G8-9):** `$S f12 rate` (fewer than 10 requests left: wait in the background for the
   reset, at most an hour, with `$S wait 9`, then again; else "not run: rate-limited"). `$S install
   F`, `$S f12 before`; Check for Updates, then Install and Relaunch, by `$S ui press BatteryPulse
   ...`; `$S f12 after`; answer `F12-version`, `F12-widget` and `F12-new-kinds`.
6. `$S batch`: the items you answered 3 or unsure, offered in one line ("N items I wasn't sure
   about: look now, or skip and they keep their defaults?"); on "look", give each picture's full
   path (he types `! open <path>`; you never open a file by computer use) and record each with
   `--by person`.
7. `$S send --dry-run`; give him its `SHEET` the same way, summarize `~/bp-080/R/R.md` in Russian,
   and ask whether he added any allow rule beyond the launcher's (`note` his answer). On his yes,
   `$S answer --by person R-send y`, then `$S send`. A lint refusal names a line: drop it, tell him,
   dry run and his yes again.
8. `$S restore end`: his own BatteryPulse, his settings and data back, the logged day's history
   kept, the candidate's feed gone, and the placed widgets counted after its relaunch. Then each
   `RESTORE` item: the gallery's widgets removed by computer use (Edit Widgets, each one's minus),
   unless he keeps them (`R-keep-widgets` y), then `$S widgets-check`, which records them gone only
   when BatteryPulse's counts are back at prepare's; anything else not confirmed earlier. `$S summary
   end`, and tell him in Russian what is back, each widget kind that stayed or is gone by count (an
   `ALERT` each, and a `KEPT` line as an alert too: the widgets he chose to keep stay on his desktop,
   and an iPhone & iPad one keeps his devices in the widget feed), and what is his (the Focus; at the
   end of the series, Terminal's Accessibility, unless he keeps it).
9. **`$S send` once more** (T-1 item 7): step 7's send went before the restore, so `R.md` had no
   counts after it; now it gains the restore's section and the widgets' counts after each read, what
   stayed by kind and count. His yes stands for the same report (tell him what it adds); nothing new
   is attached, and the privacy lint runs again. End.

## If the session restarts or compacts

- First read this file again from your session's worktree, then `$S status`, your folder's
  `answers.tsv` and `changes.tsv`, and go on from the first step not done (a step that ran as the
  old session's background task: run it once more). In Session R8, if `ready` is up and day-end
  hasn't come, only text answers until "day-end".
- If he starts the line again, the start section's first step sends the new session here (the same
  commit).

## Answers

Steps print `ASK <id> [who; kind]: <question>` and `LOOK` lines. Look at every picture they name. A
`judge` question is yours: `$S judge <id> <answer> [--unsure] [note]`, the note in English naming
the picture (`medium-1min.png shows 80 % On battery`). A `person` question is his: `$S answer --by
person <id> <value> [note]`. `y` always means "looks right"; numbered questions take the number.
Where the script measured pixels (`blank`, `contrast`) or read a file, `judge` compares; if you
disagree, or are unsure, the item goes to his batch at the day's end. Never guess: unsure is
`--unsure`.

| Question | Criteria | Can't tell or no answer |
|---|---|---|
| `prep-*` | the value the read or the pane's shot shows | `unknown` (never changed) |
| `R-capacity-*`, `D3-capacity` | the Battery Health pane's Maximum Capacity in its shot, as `<n> %` | `unknown` |
| `R-feed-*`, `D3-feed` | the script records them from its reads; add a note only | his batch (the script's unsure) |
| `R2-small`, `R2-medium`, `R2-large`, `R2-062-*` | after the desktop click, against `-before.png`: 1 the same layout and choices with fresh values (G7-2) | `--unsure` |
| `R2-whats-new-*` | both shots about 520 points wide, 0.8's rows, every row and line readable in English and Russian, nothing cut | `--unsure` |
| `R-tree-app`, `R-tree-app-ru` | every control a role and a non-empty label, only decorative images without one, the power flow, the capacity bars and each ring one element with a value | `--unsure` |
| `R-charts` | 1 each chart's label and descriptor read; 2 a chart without one (name it); 3 neither AX nor Accessibility Inspector reads it | 3 |
| `R-keyboard` | each path the step names reached and focused, in its file; n names the control | `--unsure` |
| `R-contrast` | 1 no failure in Standard and Frosted, Light and Dark, with Increase Contrast; 2 the failures, listed | 3 (not run) |
| `R-display` | the main and compact windows and the popover readable and whole in every option's shot | `--unsure` |
| `R-menubar-a11y`, `V01-menubar` | the item legible on the light and the dark bar, not clipped | `--unsure` |
| `R-russian` | every word Russian but names and units, nothing cut, the Russian review's answers applied | `--unsure` |
| `R-limit-live` | 1 Overview's sentence and Power's number equal the hold's battlimit; 2 they differ | 3 (not run) |
| `R-report`, `R-sentinel` | the script's reading of the files; add a note only | his batch |
| `R3-<name>` | the crop against the CI render of that kind and family in `previews/`: the same layout, readable, nothing cut | `--unsure` |
| `R7-tree`, `R7-tree-ru` | no symbol name, the charge one element with its value, one element per row, no empty group, a chart one element with one label | `--unsure` |
| `R4-1-chooser`, `R4-6-*` | the sheet's own words in its shot; 4.6's chooser opening is enough (no device is remembered then) | `--unsure` |
| `R4-1-shows`, `R4-2-kept`, `R4-5-automatic` | the crop or the sheet shows exactly 4.1's choices (Custom, the first three details and Average drain, time left if offered, monochrome) | `--unsure` |
| `R4-3-sheet` | 1 every word Russian but names and units; 2 an English word (name it: a fix before release); 3 the sheet stayed English | 3 (not checked) |
| `R4-3-widgets` | after `language ru` saw the reload and a new extension: 1 Russian, 2 English (which) | not checked (no redraw) |
| `R5-*` | every widget readable; a low or Service Recommended state still shows without colour; the contrast beside it | `--unsure` |
| `R6-12-hour`, `R6-tick`, `R6-count-toggle` | the times as `4:39 PM`; the minutes down by one, no seconds, no minus sign; the toggle and footer readable, greyed out under Never | `--unsure` |
| `R7-text-size` | 1 grow, 2 unchanged (expected), 3 cut off (a fix before release) | 2 |
| `R8-*` | quit, running, main and compact: Overview; accessories: Accessories; health: Health; history: History; device: the device's page, or Devices with none remembered (an activity route opening Overview is 2, naming the route) | 3 with what the log shows |
| `R9-plug` | each crop's state matches `bpulse --json` of its row within a minute; at his limit: Not charging, then Charged to limit once bit 24 appears | `--unsure` |
| `R9-accessory` | 1 the Accessories widget changed within a minute | 3 |
| `R9b-*` | Charged to limit on Overview, the popover and the compact window; Power's Charge limit row as the scene gives it; in Russian the catalog's terms | `--unsure` |
| `R-settings` | each pane's end in its shot: the last row's control whole and reachable; a pane that fits shows no scroll bar | `--unsure` |
| `R-menu-bar-same` | each pair it lists, BatteryPulse's item alone (the clock, the system's items and the charge change between the runs): 1 drawn the same in every pair; 2 naming the pairs that differ | `--unsure` |
| `R-raw-history-rc` | 1 History at once; 2 History's title over Raw Data's table first (how long) | 3 |
| `F12-version`, `F12-widget`, `F12-new-kinds` | the version the script read; the crops before against after the redraw: 1 same, with fresh values (the published 0.7.1 has every kind, the History and iPhone & iPad ones too), 2 blank or grey, 3 gone, 4 different | `--unsure`; no redraw: not checked |
| `H-hold` | 1 a span held below 100 % on the adapter for 15 minutes or more; 2 none | 3 |
| `D3-widgets` | after the redraw and the desktop click, against the before-picture: 1 same, 2 blank or grey, 3 gone, 4 different | `--unsure` |
| `D3-*` (the rest) | as each question says, from its shot or the script's read | `--unsure` |
| `R-*`, `H-*`, `D3-*` (his) | his answers | `R-back` 4 hours after the start; `R-keep-ax` n; `R-keep-widgets` n; `R-limit` n; `R-listen` skipped; `*-send` n (nothing is sent) |

Every item left "not checked" or "not run" takes its gate's default (PLAN.md §7.1).

## Hold watch

You run BatteryPulse 0.8's hold watch (QUA-06, G8-2; PLAN.md I-8 and §6.0's table): any night
before D1, never Session R8's logged day. His part: the start in the evening and his yes; the Mac
plugged in with the lid open overnight; "morning" and his yes before `send` (about 2 minutes).
`$S` here stands for `bash ~/bp-080/H/run/docs/plans/0.8.0/m5-session.sh`. First:

1. **The worktree.** `git -C ~/BatteryPulse rev-parse FETCH_HEAD` is the commit section.sh read
   this from. If `~/bp-080/H/run` exists at another commit, `git -C ~/BatteryPulse worktree move
   ~/bp-080/H/run ~/bp-080/H/run-<its first 7 characters>`; then `git -C ~/BatteryPulse worktree
   add --detach ~/bp-080/H/run FETCH_HEAD` (at the same commit: a restart, go on from the first
   step not done).
2. **Read**, with your file-reading tool, these sections of
   `~/bp-080/H/run/docs/plans/0.8.0/SESSION-R.md`: Rules, Privacy, Decisions you make alone and
   Answers. They hold here, with `$S` as above; their Session R8 steps are not yours. Then `$S
   help`.
3. Say in Russian what happens: a recording with `bpulse --record` under `caffeinate -i` into a new
   folder on the Mac, overnight, with the Mac on the adapter and the lid open; nothing else
   changes; in the morning he writes "morning", and the captures that show an optimized hold go to
   `claude/080-session-h` only after his yes. On his yes: `$S answer --by person H-yes y` and
   `H-usage`.
4. `$S hold-watch start`. Say: "Leave the Mac plugged in with the lid open; in the morning write
   morning." End your turn.
5. On "morning": `$S hold-watch morning`; answer `H-hold` from its spans; `$S batch`; `$S send
   --dry-run`, his yes (`H-send`), `$S send`. Tell him in Russian whether a hold was seen, and
   whether bit 24 came with it.

## After publishing

You run the BatteryPulse 0.8.0 after-publishing check (PLAN.md §6.6), from his restored 0.7.1 with
his widgets placed. The start's sentence named `<keep>`, the last commit that holds this folder,
and fetched the release PR's head that holds it. His part: the line, the approvals and his yes
before `send` (about 2 minutes), plus a passive wait of about 15 minutes. Never `gh`, `sudo`,
`killall`, an install or a copy outside the script. `$S` here stands for `bash
~/bp-080/D3/run/docs/plans/0.8.0/m5-session.sh`. First:

1. **The worktree.** If `~/bp-080/D3/run` exists at another commit, `git -C ~/BatteryPulse worktree
   move ~/bp-080/D3/run ~/bp-080/D3/run-<its first 7 characters>`; then `git -C ~/BatteryPulse
   worktree add --detach ~/bp-080/D3/run <keep>` (at `<keep>` already: a restart, go on from the
   first step not done).
2. **Read**, with your file-reading tool, these sections of
   `~/bp-080/D3/run/docs/plans/0.8.0/SESSION-R.md`: Rules, Privacy, Decisions you make alone and
   Answers. They hold here, with `$S` as above; their Session R8 steps are not yours. Then `$S
   tools` (ui and frames from this worktree, about a minute; every step below clicks, crops and
   reads AX through them, so without them each is "not checked") and `$S help`.
3. **Before anything** (rule 6): ask him in Russian whether 0.8.0 is still uninstalled; if he
   installed it already, the update can't be checked: say so, note it, and check only steps 6 to 8
   from what is there. Say: "This is the check after the 0.8.0 update, about 15 minutes. Please keep
   off the Mac until I say so, don't press Install and Relaunch yourself (the session does it), and
   answer a dialog only if I ask." On his yes: `$S answer --by person D3-yes y` and `D3-usage`.
4. **`$S main` first** (rule 2: BatteryPulse's main window, so it has a Dock icon), and only then the
   one computer-use access request for BatteryPulse and System Settings. `$S ui access`, `$S proof
   P1 --image <shot> <x> <y>`, `$S widget <name> ...` for each of his widgets (`$S ui frame
   --widgets`), `$S desktop-spot ...`, `$S proof P11`. Notification Center can't be granted to
   computer use: the widgets are the script's crops (rule 3). A widget of his that is blank or gone
   now: note it and leave it; the session adds no widget here.
5. **The before-picture:** BatteryPulse's Settings (General, Menu Bar, Notifications, Advanced) by
   computer use, a shot each; `$S after before` (pluginkit, the widgets' crops after the desktop
   click, the extension's pids).
6. **The update:** Check for Updates, then Install and Relaunch to 0.8.0, by `$S ui press
   BatteryPulse ...`; `$S after after` (it waits for 0.8.0, reads the update log's pre-swap line and
   CHSErrorDomain 1103, pluginkit, `codesign` and the quarantine flag, crops the widgets once a new
   extension process drew them, rule 4, and checks the feed: `D3-feed`). Then About, What's New,
   History, the settings and the menu bar by computer use; Login Items only by `$S pane login-items`
   and `$S ui tree "System Settings" --match BatteryPulse`, which says only whether the row exists
   (no screenshot of that pane, which lists his other apps). Help → Report a Problem… by `$S ui
   press BatteryPulse "Report a Problem…"`, `$S screen report-problem front`, closed; `$S
   help-link` (the guide at `v0.8.0`). Answer each `D3-*` it asks. `$S capacity after` with System
   Settings → Battery → Battery Health's shot: `D3-capacity`.
7. **A 2 or 4 for `D3-widgets`, or any other failure:** say in Russian that the cloud session will,
   on his yes, mark v0.8.0 a prerelease and fix forward; nothing on this Mac does that. A 3: the
   notes say "add it again".
8. `$S after popover`; answer `D3-first-day`. Then `$S batch`, `$S send --dry-run`, his yes
   (`D3-send`), `$S send`, and a short summary for him in Russian to forward to the cloud session.

## Before Session R8 (him)

Not printed for any session: what he does himself.

### Once, any day before (about 1 minute)

1. Quit any other Claude session on the Mac: one at a time.
2. Don't install a macOS update or a BatteryPulse update until the series ends, so the sessions see
   the updates they test (Session R8 backs up the BatteryPulse he runs then); an update banner also
   covers the screen.
3. In `~/BatteryPulse`: `claude`, then `/mcp`: `computer-use` is enabled (kept per project; if not,
   Enable). He asks that session: `Check the launcher docs/plans/0.8.0/start-session.sh (git fetch
   origin claude/080-integration && git show FETCH_HEAD:docs/plans/0.8.0/start-session.sh) against
   claude --help and the Claude Code documentation, and answer me in Russian.` It checks that
   `--allowedTools`, `--permission-mode auto`, the rule `Bash(<prefix>:*)` with `~` as written, and
   `DISABLE_AUTOUPDATER=1` are still the documented spellings, and changes nothing; a changed
   spelling it writes out for him, changing only that spelling.

### The starts

Session R8 (on the adapter; a daytime session works), in Terminal, from any folder:

```
git -C ~/BatteryPulse fetch origin claude/080-integration
bash <(git -C ~/BatteryPulse show FETCH_HEAD:docs/plans/0.8.0/start-session.sh) r8
```

The hold watch, in the evening, the same with `hold-watch` in place of `r8`. After publishing, D3
posts the line with the release PR's number `<n>` and `<keep>`:

```
git -C ~/BatteryPulse fetch origin refs/pull/<n>/head
bash <(git -C ~/BatteryPulse show <keep>:docs/plans/0.8.0/start-session.sh) after-publishing <n> <keep>
```

The launcher changes to `~/BatteryPulse` and runs PLAN.md §6.4's or §6.6's start line: one allow
rule, `Bash(bash ~/bp-080/<R|H|D3>/run/docs/plans/0.8.0/m5-session.sh:*)`, auto mode, and a
sentence whose `section.sh` prints this file's section "R8", "Hold watch" or "After publishing"
alone.
