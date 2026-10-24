# M5 Session B: the hands-free runbook

Session B of BatteryPulse 0.6.2 runs on the release candidate (RC) on the MacBook Air M5. One local
Claude Code session with computer use does every step itself, and a plain script in a second
Terminal window, the arm window, runs the energy queue. PLAN.md §6 "Session B" is the plan; this file
is what the session does. The maintainer does only what needs a person: the start line and one yes,
quitting his own apps, the Focus on and off, the adapter, the lid and the morning login, his password
at bedtime, permission prompts, taste questions, his typed "continue", revoking Terminal's
Accessibility unless he keeps it, and his yes before `send`.

## Once, any day before (him, about 2 minutes)

1. Quit Session A's Claude session: one Claude session at a time on the Mac.
2. In Terminal: `claude update`.
3. In `~/BatteryPulse`: `claude`, then `/mcp` → `computer-use` → Enable (kept per project;
   interactive sessions only). `/status` shows a plan that includes computer use.
4. In that same session he pastes: `Check the start line of docs/plans/0.6.2/SESSION-B.md (git fetch
   origin claude/nice-faraday-k08mhb && git show FETCH_HEAD:docs/plans/0.6.2/SESSION-B.md) against
   claude --help and the Claude Code documentation, as its section Once before says, and answer me in
   Russian.` That Claude checks, and changes nothing:
   - `claude --help` lists `--allowedTools` (or only `--allowed-tools`) and `--permission-mode` with
     the value `auto`;
   - `Bash(<prefix>:*)` is the documented rule for every command that starts with that prefix, and
     `~` in it matches the command as written (the session always writes `bash ~/bp-062/...`);
   - `DISABLE_AUTOUPDATER=1` is the documented way to stop the CLI updating itself;
   - `/mcp` lists `computer-use` as enabled.

   If a spelling differs, it writes him the corrected start line, changing only that spelling (never
   the rule's path or the sentence), for him to keep for the evening.
5. He keeps Terminal's Accessibility (Session A's grant) until Session B.

## The start line (him, in the evening, on the adapter)

In Terminal, in `~/BatteryPulse`, he pastes this one line (no other rule; Remote Control stays off):

```
DISABLE_AUTOUPDATER=1 claude --allowedTools 'Bash(bash ~/bp-062/B/run/docs/plans/0.6.2/m5-session.sh:*)' --permission-mode auto 'Run the BatteryPulse M5 Session B hands-free: in ~/BatteryPulse run git fetch origin claude/nice-faraday-k08mhb && git show FETCH_HEAD:docs/plans/0.6.2/SESSION-B.md, then follow that runbook from its first step.'
```

Everything below is for you, the session this line started. Your first step is B0a.

## Rules

- **Language.** Talk to him in Russian, always. Everything recorded is English: `answer`, `judge`,
  `note`, `change`, `restored`, `attach` captions; the script refuses Cyrillic. The quoted phrases
  below are what to say, in Russian.
- **One prefix.** `$S` below stands for `bash ~/bp-062/B/run/docs/plans/0.6.2/m5-session.sh`. Write
  it out in full in every call, exactly so, one script call per Bash call: no `cd`, no variables, no
  pipes, no redirection, no `&&`. That is what the start line's one allow rule covers. The only
  commands outside it are B0a's `git fetch`, `git show` and `git worktree add`, under auto mode. `$S
  help` lists the commands, and the header of `ui.swift` beside the script lists `ui`'s. Read files
  (shots, frame sheets, `B.md`, `answers.tsv`, `changes.tsv`) with your file-reading tool, never
  with a shell command.
- **Frozen.** The runbook, the script and `ui` are fixed at B0a's commit. Never edit them, never
  fetch again, never adopt a later fix: a fix goes to the next session.
- **Permissions.** Never add or change a permission rule, never change Claude Code's or git's
  configuration, never retry a command auto mode blocked (that step moves to the morning, "not run:
  blocked"). Never type a password, never approve a permission or authorization dialog, never toggle
  anything in Privacy & Security, Users & Groups or Passwords.
- **Long calls.** Give every script call the Bash tool's `timeout: 600000`; it matters for every call
  that may take over 2 minutes (`preflight`, `f11 alert`, `burst`, `case`, `memory`, `pages`, `f12
  after`, `v01 check`, every `restore`, `morning`, `send`). Anything near the tool's 10-minute limit
  runs as a background task you wait on: `prepare`, `pages profiling`, `wp18 timing`. While one runs,
  the screen is the task's: no GUI action; judge the pictures already taken, and make a script call
  (a `judge`, else `$S heartbeat "<task> running"`) at least every 10 minutes, since after `mark away`
  the arm window takes a heartbeat older than 20 minutes for a stall and starts the queue. Stop every
  background task before `ready`.
- **Heartbeat.** After each step and between computer-use batches: `$S heartbeat "<step> done; ready
  about HH:MM"`. It prints the GUI phase's minutes left.
- **Never act after `ready` or once `queue.started` exists**, until his morning "continue": check
  `$S status` before every step and every computer-use batch. A message that reaches you then gets a
  text-only answer (say: "the results come in the morning"), with no tool call.
- **Order of means.** The script and `ui` (AX, CGEvent, CGWindowList, System Events) first, computer
  use where they can't reach. Neither ever sends Esc (it would end your turn) or a key press `ui`'s
  rules don't allow. Before any change by computer use or AX outside the script: `$S change <setting>
  <original> <new>`; after putting it back: `$S restored <setting> <how it was confirmed>`. A setting
  whose original is unknown is never changed.
- **Places.** Terminal windows in the left third of the screen, BatteryPulse's windows and widgets
  on the right, away from the top-right corner where banners and computer use's own notifications
  land. Windows are placed by AX (`$S ui position ...`); widgets can't be moved, so their frames come
  from P1.
- **Commits.** You commit and push nothing. The only push is `send`'s, to `claude/062-session-b`,
  committed in UTC, after his morning yes. No interim pushes, no other branch, no pull request.

## Privacy

- Every picture you read, and every computer-use screenshot, goes to the model; none goes into the
  repository. His Focus, the apps he quit and the hidden apps limit what they show; his other desktop
  widgets are in them (the start message says so).
- No computer-use screenshot while Notification Center or Control Center is open: AX actions and
  crops of BatteryPulse's frames instead.
- Full-desktop, Notification Center and System Settings shots stay in `~/bp-062/B`. Only crops of
  BatteryPulse's windows, widgets and menu bar item are attached (`$S crop`, `$S attach`), never one
  taken while BatteryPulse remembers an iPhone or iPad by name.
- `pmset -g accps`, `pmset -g log` and `scutil` outputs reach `B.md` only as counts or BatteryPulse
  lines; `send`'s privacy lint enforces it. Results leave the Mac only through `send`, after his yes.

## Decisions you make alone

Nobody is there to ask: Session A's questions to a cloud session become these rules.
- **A step fails or misbehaves:** read the message (most say what to do); run it once more only if
  the cause was passing (a window not up yet, a timeout); else `$S note "<step>: <what happened>"`,
  and the step's items are "not checked" or "not run" with the reason; go on. A harmless workaround
  is allowed only if it changes no setting outside `changes.tsv`, and is noted.
- **Never repair the Mac's state by hand:** no `killall` or restart of a system process (chronod,
  Dock, WindowManager, Notification Center, cfprefsd), no `lsregister`, no install, swap or copy of
  a build except through the script (`prepare`, `install C`, `f12`, `pages profiling`, restore).
- **The order of B2 is fixed.** Skip ahead only while a step waits (F12 on GitHub's limit, a prompt
  he must answer); come back to it once, later in B2, else in the morning.
- **A spoiled take** (a banner over the window, his touch, a clip that missed the animation): run
  that one step again once; the rerun replaces its section; note the first take. Then answer 3 (or
  `--unsure`).
- **A banner not seen in 10 s:** look in Notification Center (an AX click on the clock, then a crop
  of the banner; no computer-use screenshot while it is open), then answer it not seen (3, or n).
- **A failed proof** prints its fallback (`PROOF Px: fail (...); fallback: ...`): switch that proof's
  steps to it before you go on, so nothing waits for him later.
- **A prompt or a password dialog:** while he is there (B0, B1), ask him to answer it; while he is
  away, leave it, record the step "not checked: prompt", and go on with steps that don't need it.
- **A lock screen or the lid closed:** stop all GUI work, record "not checked: locked", and wait for
  him (in B2 that is his Esc, below).
- **He touches the Mac during B2:** if P6 showed that `ui guard` tells his touches apart, wait until
  his last touch is a minute old. If he presses Esc, computer use stops and your turn ends; on his "go
  on", check the state first (`$S status`, a shot) and carry on.
- **Findings** (crash reports, "executor" lines, black frames, a wrong value): note them with their
  evidence and go on. Never investigate beyond the step's reads, never patch anything.
- **Anything not on the yes-list:** never change it; a step that would need it is "not checked".
- **Your usage limit:** if `/usage` or the CLI warns that the limit is near, drop the optional
  extras, then WP-18, and go to B3 early, so the queue starts on `ready`, not on a stale heartbeat.
- **Anything this file doesn't cover:** do what changes nothing, record "not checked" with the
  reason, and go on.

## Answers

Steps print `ASK <id> [who; kind]: <question>`, `LOOK` and `SHOT` lines. Look at every picture they
name. A `judge` question is yours: `$S judge <id> <answer> [--unsure] [note]`, the note in English
naming the picture or frame (`frame-0012 shows an even grey shape`). A `person` question is his:
`$S answer --by person <id> <value> [note]`. `y` always means "looks right"; numbered questions take
the number. Where the script measured pixels, `judge` compares; if you disagree, or `--unsure`, the
item goes to his morning batch. Never guess: unsure is `--unsure`.

| Question | Criteria | Can't tell or no answer |
|---|---|---|
| `prep-charge-limit`, `prep-widget-style`, `prep-dim-widgets` | the value `pmset -g battlimit` or the pane's shot shows | `unknown` (never changed) |
| `prep-open-at-login` | 1 on, 2 off, by the AX read | `--unsure` (never changed) |
| `prep-widgets` | 1 a small and a medium BatteryPulse widget on the desktop, uncovered | 2 |
| `prep-wallpaper-kind` | 1 still, 2 dynamic, 3 aerial | 3 (restored from the shot) |
| `P3-capture` | 1 `-l` keeps what lies behind the sheet, 2 it leaves it out | 2 (`-R` for every style) |
| `P4-frames` | 1 enough frames to judge the fill, against Session A's case; 2 too few | 3 (P5's Shift, else Session A's cases) |
| `V01-notification`, `-front` | the banner came and its press brought BatteryPulse forward | `--unsure` |
| `V01-menubar` | legible on a light and a dark bar, no clipping, the pixel diff shows the change | `--unsure` |
| `V01-pages` | Raw Data, History, Demo Mode on and off, Check Now (its offer closed by its own button), Clear History each did what it says | n, naming the one that failed |
| `V01-lid` | the after-lid shot shows BatteryPulse in the menu bar with the current charge | `--unsure` |
| `F11-alert` | 1 its banner appeared, 2 none in time, 3 not run | 3 |
| `F11-login` | 1 gone from Login Items, 2 still listed | `--unsure` |
| `F6-<page>` | every figure agrees with `bpulse --json` of the same minute (charge within 1 point, capacities and cycles exact, power and temperature within their minute's change) | n, with the differing values |
| `F8-<family>-<en/ru>` | 1 right: the current charge and state, in that language; 2 blank or grey; 3 gone; 4 different | `--unsure` |
| `F9-<page>` | no truncation or overlap, no English left but names and units, the terms System Settings → Battery uses | `--unsure` |
| `F12-widget` | before against after: 1 same, 2 blank or grey, 3 gone, 4 different | `--unsure` |
| `fill-<case>` | over the frame sheet and the darkest frame's luminance: 1 like the window, or an even graphite grey (about RGB 49,49,49), in every frame; 2 a black frame or rectangle in any frame; 3 something else | 3, with a note |
| `shot-<style>-...` | readable, no black, grey or missing parts; History's readout under the pointer | `--unsure` |
| `grad-<style>-...`, `grad-clear-light-settings`, `grad-frosted-*-gallery` | looks right: text readable, controls and bars visible, nothing black, grey or missing | `--unsure` |
| `audit-<style>-<look>-<page>` | 1 no failure, 2 a failure (note it), 3 not run or an estimate only | 3 (that style stays beta) |
| `V1b` | the script's pixel comparison inside the outline is identical | n |
| `SUI-17` | Xcode's canvas renders a preview, not an error | n |
| `energy-setup` | 1 only if brightness about half, auto-brightness and True Tone off, his apps quit and a Focus on are each confirmed by a read or a shot | 2 |
| `B-*`, `grad-*-sheet`, `graduate-*`, `SZ-10` | his answers | `B-bedtime` 4 hours after the start; `B-charge-capture`, `B-keep-ax` n; `B-slider-auth` 2; the rest n (a style stays beta, SZ-10 waits for 0.7, nothing is sent) |

Every item left "not checked" or "not run" takes its gate's default in D3 (PLAN.md §7.1).

## B0a: the start (he is there about a minute)

1. **The worktree.** If `~/bp-062/B/run` exists, this is a restart: don't create it, read
   `~/bp-062/B/run/docs/plans/0.6.2/SESSION-B.md` and follow that copy, from "If the session
   restarts". Otherwise: `git -C ~/BatteryPulse worktree add --detach ~/bp-062/B/run FETCH_HEAD` (the
   commit you read this file from; no fetch in between). Then `$S help` and `$S status`.
2. **The start message,** one message in Russian, before anything changes:
   - What may change, and is written to `changes.tsv` first and put back: the installed BatteryPulse
     (his comes back from the backup); the appearance, the wallpaper (to generated bright and busy
     pictures), Icon & widget style, Dim widgets on desktop, Text size; desktop widgets (a small and
     a medium added if missing, a blank one removed and added again, a test widget added and
     removed, Session A's dead Test widget removed for good); Increase Contrast, Reduce Transparency,
     Reduce Motion, Prefer Cross-Fade Transitions, Show Borders and the Liquid Glass slider for the
     optional passes; brightness, auto-brightness and True Tone for the energy runs; Low Power Mode
     for one run; BatteryPulse's settings and data, the widget's included, and his remembered iPhones
     and iPads, removed for the session so no picture shows their names.
   - Never: a VPN, undocumented system keys, anything in Privacy & Security, Users & Groups or
     Passwords.
   - The questions: may the Charge Limit go 80 → 100 → 80 in the morning, at most 10 minutes at
     100 %? Keep Terminal's Accessibility until 0.7's Session R (else he turns it off in the
     morning)? His bedtime (else 4 hours from now)? In Session A, did the Charge Limit slider ask for
     a password or Touch ID? And: "Please type /usage now and tell me what it shows."
   - Privacy: the pictures go to the model and stay on the Mac; his other desktop widgets appear in
     them; at the beep he quits his own apps.
   - Times: about 10 minutes of building, then a beep and about 5 minutes with him; an optional 5-minute
     burst; then the GUI phase on its own until 10 minutes before bedtime; at bedtime the arm window
     asks for Return, his password and the unplug; the queue then runs about 3 hours (give the
     expected end, bedtime plus about 3 h 15 min); the lid stays open until then; in the morning: the
     lid closed for a minute, opened, log in, plug in, write "continue" and keep off the Mac for
     about 3 minutes; then a few questions and his yes before anything is sent.
   - End your turn and wait for his answer.
3. **Record** (only on an explicit yes; anything else changes nothing, and you end):
   `$S answer --by person B-yes y`; `B-bedtime HH:MM` if he gave one; `B-charge-capture y|n`;
   `B-keep-ax y|n`; `B-slider-auth 1|2`; `B-usage "<what /usage showed, or what he said>"`. And
   `$S answer --by claude B-keep-widgets n "not asked: the RC's widget offers only small and medium"`.
4. **`$S prepare`** as a background task (about 10 minutes): the backup, the builds and tools, his
   remembered devices removed for the session, the RC installed. It ends with `BEEP (B0a is done)`.
   If it fails, run it once more; if it fails again, tell him why, run `$S restore gui` and `$S
   restore morning` if `changes.tsv` lists anything, and end. Never `--fresh-backup` unless the
   script asks for it.
5. At the beep, say: "The build is done. Please quit your own apps (Terminal stays), then write me
   that you are back." End your turn.

## B0b: at the beep (he is there, 4-6 minutes)

1. `$S prepare reads`; read every shot it names and answer `prep-*` (table). If `prep-widgets` is 2,
   add the missing small or medium BatteryPulse widget by computer use (the gallery's click-to-add,
   then one slow `$S ui drag`), with `$S change desktop-widgets "<what was there>" "<what you added>"`
   first, and take `$S shot prepare-desktop-2`.
2. **P1 and the frames:** `$S proof P1 --image <shot> <x> <y>` at a widget's centre (the shot's
   pixels); then `$S widget small <x> <y> <w> <h>` and `$S widget medium ...` in points from P1's
   frames (no large or extra-large: the RC has none), and `$S desktop-spot --image <shot> <x> <y>` on
   empty desktop, away from icons and widgets.
3. Say: "For the next two minutes please don't touch the keyboard or the trackpad; answer any macOS
   prompt that appears." Then `$S preflight` (P2, P6-P9, P11 and the reads). He answers what comes
   up: Accessibility for Terminal if he revoked it (the switch, then `$S preflight` again), the
   developer tools, other apps' data.
4. Your proofs: `$S proof P3`, then `$S proof P3 <1|2>` from its pictures; `$S proof P4` (it runs P5
   too), then `$S judge P4-frames <1-3>`; **P10:** one computer-use access request for the whole
   batch (BatteryPulse, System Settings, Finder, Notification Center, the widget host P1 named,
   TextEdit, Accessibility Inspector, Xcode, and Numbers if the CSV check will run), one widget
   click-to-add in the gallery and its removal, a screenshot right after the first action (where
   computer use's own notification lands), one System Settings click; then `$S proof P10 pass|fail
   "<what it showed>"`. An app it refuses: that app's steps go to scripting, else "not checked"; a
   failed gallery click: ask him to add or remove that widget now. Then each command family once,
   as preflight's `RUN` lines say (`ui idle`, `ui guard`, `shot`, `heartbeat`, one `measure` and
   `judge`, `status`), so every prompt comes now.
5. **The banners, before the Focus:** `ui banner` finds each banner by its English body, only
   inside a BatteryPulse banner, and presses it within 10 s: "This is how battery alerts will look"
   for V-01, "You can unplug the power adapter" for F11. `$S v01 notify`, then `$S v01 notify
   front`; answer `V01-notification` and `V01-notification-front`. `$S f11 alert` (it may wait up to
   6 minutes); answer `F11-alert`.
6. **WP-23's device check,** only if he has an iPhone or iPad and its cable at hand: he plugs it in;
   turn Read iPhone and iPad batteries on in BatteryPulse's Settings → General by `ui press`; once
   its page shows values, say "Please pull the cable now"; press Refresh on its page and read whether
   it says "Connected over Wi-Fi" (`$S ui tree --app BatteryPulse --match Connected`); `$S note
   "WP-23: <what the page said>"`. Then `$S devices forget`. No picture is attached until it has run.
   Without a device: `$S note "WP-23 device check not run: no device at hand"`.
7. `$S arm open`. Say: "A Terminal window named BatteryPulse arm opened. Leave it open; at bedtime it
   tells you what to do."

## B1: the burst (optional; he is there about 5 minutes)

Ask: "Now the optional burst, 5 minutes: at each beep unplug the adapter, at the next plug it in, three
times, a minute apart; it ends plugged in. Shall we, or skip?" On yes, `$S burst` (P12 runs at the
first unplug). On skip, `$S note "S8 not run: the burst was skipped"`. Then say: "Please turn a Focus
on in Control Center now, leave the Mac on the adapter with the lid open, and write me when the Focus
is on." On his word, `$S mark away`: no sound, speech or question from here until his "continue". It
warns if BatteryPulse still remembers a device by name (`$S devices forget` first).

## B2: the GUI phase (he is away, about 2.5-3.5 hours)

It stops 10 minutes before his bedtime, or 4 hours after the start (`heartbeat` shows the minutes
left). Whatever is left then is `$S note "<item> not run (time)"`, or moves to the morning-away
block. In this order:

1. **Memory:** `$S memory` (History → 7 d three times, `phys_footprint` before and after).
2. **The placed widgets:** `$S shot widgets-placed`. Session A's dead Test widget: one shot, then
   `$S change test-widget "placed" "removed"` and remove it by computer use; it isn't put back. A
   blank or grey widget anywhere: shoot it, answer, then remove it and add it again by computer use,
   and note that.
3. **V-01's other half:** `$S v01 menubar`, answer `V01-menubar`; then Raw Data, History, Demo Mode
   on and off, Check Now (close its offer by its own button) by `ui press`, `ui select-row` and `ui
   click`, computer use as the fallback. Clear History comes in item 5.
4. **F6, F8, F9, F11's login item:** `$S f6 overview`, `power`, `history`, `health`, `raw`, each
   answered against the `bpulse --json` it prints; `$S f8`, `$S f8 ru on`, `$S f8 ru`, `$S f8 ru off`
   (small and medium in English and Russian; large and extra large are "not checked": no such
   family); `$S f9`, answer `F9-*`, then `$S relaunch` (English again); `$S f11 login`, turn Open at
   login off by `ui press` as it says, `$S f11 listed`, answer `F11-login`. If none of F8's Russian
   ways works, F8-ru is "not checked".
5. **The beta styles:**
   - The 10 minimize cases: `$S case translucent-light-main`, and the same for `translucent-dark`,
     `clear-light`, `clear-dark` (`-main` and `-compact` each), `standard-light-main` and
     `frosted-light-main`; read each frame sheet beside the darkest frame's luminance and answer
     `fill-*`. A clip that missed the animation: once more, then 3.
   - The 24 shots: `$S styleshot <translucent|clear> <bright|busy> <light|dark>
     <overview|history|settings>`, each answered `shot-*`.
   - The 19 graduation shots: `$S gradshot <translucent|clear> <light|dark>
     <raw|demo|history|fullscreen>`, doing what its `DO` line says and then the same command with
     `--ready`; `$S gradshot clear light settings`; `$S gradshot frosted <light|dark> gallery`. Answer
     each `grad-*`.
   - The contrast audit: `$S open-app "Accessibility Inspector"`, its audit by computer use (clicks
     only) for each beta style, appearance and page (Overview, History, Settings); answer `audit-*`.
     Without the Inspector: `$S audit estimate <style> <look> <page>`, answered 3.
   - V1b: `$S v1b <x> <y> <w> <h>` with the Clear tile's frame in Settings → General; answer `V1b`.
   - Then Clear History by `ui press` (`V01-pages` is answered at item 10).
   - A style with a shot missing or not answered y stays beta; so does one whose audit didn't run.
6. **Page switches:** `$S pages`; then `$S pages profiling` as a background task (`xctrace` with a
   watchdog, then 2 minutes of Clear), judging the backlog while it runs. Without the profiling RC,
   or with P9 failed, it records "not run" itself.
7. **F12:** `$S f12 rate` (at least 10 requests left, else try again later in B2, then in the
   morning: "not run: rate-limited"); `$S f12 before`; Check for Updates, then Install and Relaunch,
   by `ui press`; `$S f12 after`, which prints the verdict lines: every extension process the
   installer found ended within 1,500 ms; no `BatteryPulseWidget` process started before the swap;
   no "can't be ejected by force" or "Ejecting the update's disk image failed" line (must be 0);
   Finder's on-screen windows during the install (more than before means a window opened). With no
   extension running before Install, item 6 is "not exercised". Answer `F12-widget`, then `$S
   install C`: the rest runs on the RC.
8. **WP-18:** `$S wp18 previews`, resume the canvas in Xcode by computer use, answer `SUI-17`;
   `$S wp18 timing` as a background task; SZ-10 only if the frozen worktree holds an `.icon` source
   under `Resources/`: `$S wp18 icon <path>`, the four Icon & widget styles by computer use (each
   `change` first, `restored` after), its shots for his morning batch; else `$S note "SZ-10 not run:
   no icon source in the frozen worktree"`.
9. **The optional extras,** while time allows, each setting `change`d first and `restored` after:
   `$S menu-bar-shots <tag>` with Increase Contrast and with Reduce Transparency (set by computer use;
   the plug state from the burst's stamps; Demo Mode for 100 % on power and one, two and three
   digits); Stage 1.4's pass (the Liquid Glass slider at both ends, Reduce Motion, Prefer Cross-Fade
   Transitions, Reduce Transparency, Increase Contrast, Show Borders), judged from shots and noted.
10. `$S v01 check` (the RC window's "executor" lines and crash reports); answer `V01-pages`.

## B3: the hand-over (about 5 minutes)

1. `$S restore gui`; do the items it lists for you by AX, System Events or computer use, each
   confirmed by a read or a shot and recorded with `restored`. It quits what the script opened
   (TextEdit, System Settings, Accessibility Inspector, Xcode); name any other open app in a note.
2. The energy setup: `$S pane displays`; by computer use (no key press): brightness about half,
   auto-brightness off, True Tone off, each `change`d first; a shot; then `$S answer --by claude
   energy-setup <1|2>`.
3. Stop every background task; schedule nothing.
4. `$S ready`, your last call. End your turn. From here only text answers until his "continue".

**B4-B6 run without you:** his Return, password and unplug in the arm window; the queue (a discarded
warm-up, S2 and S1 three pairs each, S2 with Low Power Mode, S4w, S5, S10, S7, S3 and the minimized
run, the retries, S6 last); `restore night`; the night's sleep on the RC.

## B7: the morning, on his "continue"

1. `$S status`. If `queue.started` still exists, tell him when the queue should end, and act only
   then.
2. `$S continue`. Without a lid line it refuses: say "Please close the lid for a minute once more,
   open it, log in, then write continue again."
3. `$S v01 morning`, answer `V01-lid`; `$S morning` (sleep hygiene, the overnight log stream).
4. **The morning-away block,** only if he says he leaves the Mac on the adapter for about an hour:
   the Charge Limit capture if `B-charge-capture` is y and `B-slider-auth` is 1 (`$S charge-limit
   record start`; `$S change charge-limit <his value> 100`; the slider to 100 % by computer use for
   at most 10 minutes; back to his value; `$S restored charge-limit "pmset -g battlimit"`; `$S
   charge-limit record stop`), whatever B2 moved here, and the exported CSV in Numbers (an English
   and a Russian region; "Russian not checked" if `-AppleLocale` doesn't take). Last, `$S
   charge-limit check`: if the limit isn't back, that is the report's first line, and say so.
5. `$S restore morning`; do the GUI items it lists (brightness, auto-brightness, True Tone, Open at
   login as prepare found it), each `restored`. Anything you can't put back heads the report, for his
   hand.
6. Ask: "Did you add any allow rule beyond the start line's? Which?" Then `$S note "allow rules he
   added: <his answer>"`, for him to remove after Session R.
7. `$S batch`: open each `SHEET` for him (Preview, by computer use; or give him the path), and ask its
   questions: per beta style its contact sheet (`grad-translucent-sheet`, `grad-clear-sheet`), "From
   0.6.2 on, offer Translucent without the Beta window styles setting? y/n." "And Clear? y/n."
   (`graduate-translucent`, `graduate-clear`), `SZ-10`'s y if it ran, and every item you answered 3
   or unsure. Record each with `--by person`.
8. `$S send --dry-run`; open its `SHEET` (every attached image) and summarize `~/bp-062/B/B.md` in
   Russian; on his yes, `$S answer --by person B-send y`, then `$S send`. A lint refusal names a line:
   drop it (`unattach`, or leave the note out), tell him, `send --dry-run` and his yes again. A failed
   push keeps everything in `~/bp-062/B`; `send` can run again later on the same yes.
9. Say: "Please turn the Focus off" and, unless `B-keep-ax` is y, "and turn Terminal off in System
   Settings → Privacy & Security → Accessibility." Then end.

## If the session restarts or compacts

- After a compaction or a restart, first `$S charge-limit check` (unless `ready` is up), then read
  this file again from `~/bp-062/B/run`, `$S status`, and `~/bp-062/B/answers.tsv` and
  `changes.tsv`, and go on from the first step not done. If `ready` is up or `queue.started` exists,
  only text answers until "continue".
- If he starts the start line again, B0a's step 1 sends the new session here.

## After publishing (D3's short session)

D3 gives him a start line that reads this file's copy, `docs/plans/0.7.0/SESSION-B.md`, from the
release PR's head and points here. Rules, language and privacy as above, with `$D` for `bash
~/bp-062/D3/run/docs/plans/0.7.0/m5-session.sh`, the start line's one allow rule; about 2 minutes of
his time. What the copy of the script offers goes through `$D`; the two reads in step 4 (`codesign`,
`xattr`) and step 6's `gh` run as plain commands under auto mode, `gh` only on his yes.

1. `git -C ~/BatteryPulse worktree add --detach ~/bp-062/D3/run FETCH_HEAD` (the commit you read
   this from), then work from the copies in `docs/plans/0.7.0/` there.
2. Say what follows, and that on any failure you will ask his yes to mark v0.6.2 a prerelease. Note
   whether Open at login is on (BatteryPulse's Settings → General, by AX) and the widget's charge and
   "Lasts until".
3. Check for Updates, then Install and Relaunch, by AX press or computer use.
4. Then check: About shows 0.6.2; History shows the past days; the settings and the menu bar look are
   unchanged; the widget shows a current value and reloaded after the update (V-01's post-update
   half); `codesign -dv --verbose=4 /Applications/BatteryPulse.app` shows `flags=0x10002(adhoc,runtime)`;
   `xattr -l /Applications/BatteryPulse.app` shows no quarantine; the login item is still listed if it
   was on (`ui tree` of System Settings → Login Items, never `sfltool`); notification permission is
   kept.
5. Open the popover by a click and compare the widget's charge and "Lasts until" with the popover's:
   within 2 points and about 15 minutes. His everyday use on the first day is the second look.
6. Tell him the result in Russian. On any failure, and only on his yes: `gh release edit v0.6.2
   --prerelease`, which serves 0.6.1 as the latest again.
