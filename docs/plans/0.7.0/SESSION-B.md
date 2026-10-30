# M5 Session B: the hands-free runbook

Session B of BatteryPulse 0.6.2 runs on the release candidate (RC) on the MacBook Air M5. One local
Claude Code session with computer use does every step itself, and a plain script in a second
Terminal window, the arm window, runs the energy queue. PLAN.md §6 "Session B" is the plan; this file
is what the session does. The maintainer does only what needs a person: the launcher and one yes,
quitting his own apps, the approvals, his password, the brightness and the Focus at bedtime, the
adapter, the lid and the morning login, his typed "continue", and his yes before `send` (about 13-15
minutes in all). This is the second attempt: the first (2026-10-27, PLAN.md Appendix C) was
cancelled, and its lessons are in the rules below.

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

## The start (him, in the evening, on the adapter)

In Terminal, from any folder, two short commands start the launcher (`start-session-b.sh`), which
changes to `~/BatteryPulse` and runs the start line below (no other rule; Remote Control stays off):

```
git -C ~/BatteryPulse fetch origin claude/nice-faraday-k08mhb
bash <(git -C ~/BatteryPulse show FETCH_HEAD:docs/plans/0.6.2/start-session-b.sh)
```

The start line itself, which he may also type in `~/BatteryPulse` (a paste can break it):

```
DISABLE_AUTOUPDATER=1 claude --allowedTools 'Bash(bash ~/bp-062/B/run/docs/plans/0.6.2/m5-session.sh:*)' --permission-mode auto 'Run the BatteryPulse M5 Session B hands-free: in ~/BatteryPulse run git fetch origin claude/nice-faraday-k08mhb && git show FETCH_HEAD:docs/plans/0.6.2/SESSION-B.md, then follow that runbook from its first step.'
```

A session started in another folder (his home, say) works the same: every command below names its
folder (`git -C ~/BatteryPulse`, `$S`). Everything below is for you, the session this line started.
Your first step is B0a.

## Rules

- **Language.** Talk to him in Russian, always. Everything recorded is English: `answer`, `judge`,
  `note`, `change`, `restored`, `attach` captions; the script refuses Cyrillic. The quoted phrases
  below are what to say, in Russian.
- **One prefix.** `$S` below stands for `bash ~/bp-062/B/run/docs/plans/0.6.2/m5-session.sh`. Write
  it out in full in every call, exactly so, one script call per Bash call: no `cd`, no variables, no
  pipes, no redirection, no `&&`. That is what the start line's one allow rule covers. The only
  commands outside it are B0a's `git fetch`, `git show`, `git rev-parse`, `git worktree move` and
  `git worktree add`, under auto mode. `$S
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
  that may take over 2 minutes (`preflight`, `f11 alert`, `case`, `pages`, `f12 after`, `v01 check`,
  every `restore`, `morning`, `send`). Anything near the tool's 10-minute limit runs as a background
  task: `prepare`, `pages profiling`, `wp18 timing`. **Never end your turn while a background task
  runs: wait on it** with `$S wait <minutes>` (1-9) in the foreground, with `timeout: 600000`: it
  returns within a minute of the task's end, or after that many minutes, keeps the heartbeat and
  prints the status; then read the task's output, and wait again until it shows the task ended.
  Never `sleep`, and never a quick loop of reads. In the first attempt the session ended its turn during `pages profiling`,
  nothing called the script for 20 minutes after it, and the arm window took the session for
  stalled. While a task runs, the screen is the task's: no GUI action; judge the pictures already
  taken. Stop every background task before `ready`.
- **Heartbeat.** Every script call but `help`, `status` and `continue` touches it, and the script
  keeps its own heartbeat every minute while a call runs (at most 45 minutes). After `mark away` the
  arm window takes 20 minutes without either for a stall: it writes `queue.started` at once, and the
  rest of B2 is lost. So after `mark away` never let 10 minutes pass without a script call: a run
  of computer-use actions, judging, waiting. After each step, between computer-use batches and at
  least every 10 minutes: `$S heartbeat "<step> done, ready about HH:MM"` (a `judge` counts too). It
  prints the GUI phase's minutes left.
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
- A `KEEPAWAKE` line names another app's process. Say its name to him, and nowhere else: never in a
  `note`, an `answer`, a `judge` note or `B.md` (the privacy lint refuses it). B.md gets counts.

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
- **A prompt or a password dialog:** while he is there (B0), ask him to answer it; while he is
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
  cases, then WP-18, and go to B3 early, so the queue starts on `ready`, not on a stale heartbeat.
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
| `SUI-17` | Xcode's canvas renders a preview, not an error | n |
| `B-*` | his answers | `B-bedtime` 4 hours after the start; `B-keep-ax` n; `B-send` n (nothing is sent) |

Every item left "not checked" or "not run" takes its gate's default in D3 (PLAN.md §7.1). G-13b's
evidence (the style shots, the graduation shots, the contrast audit, V1b) isn't gathered in this
attempt: both beta styles stay beta. Not run either: the burst (S8), memory, WP-23's device check,
the optional extras and the morning-away block.

## B0a: the start (he is there about a minute)

1. **The worktree.** `git -C ~/BatteryPulse rev-parse FETCH_HEAD` is the commit you read this file
   from. If `~/bp-062/B/run` exists, read its commit (`git -C ~/bp-062/B/run rev-parse HEAD`):
   - the same commit: this is a restart. Don't create it; read
     `~/bp-062/B/run/docs/plans/0.6.2/SESSION-B.md` and follow that copy, from "If the session
     restarts";
   - another commit: ask him (one line, in Russian) whether this is a new attempt or the same
     session restarted. A restart: as above. A new attempt (the first attempt's worktree is one):
     `git -C ~/BatteryPulse worktree move ~/bp-062/B/run ~/bp-062/B/run-<its first 7 characters>`.

   Then `git -C ~/BatteryPulse worktree add --detach ~/bp-062/B/run FETCH_HEAD` (no fetch in
   between), and **`$S prepare attempt`**, your first script call: a clean start. An earlier
   attempt's `~/bp-062/B` moves aside to `~/bp-062/B-attempt-<its date>` (nothing is deleted) once
   every change its `changes.tsv` lists was put back. If it refuses and lists changes not put back,
   name each to him in the start message (step 2) and ask whether he keeps it as it is; after his
   answer, before step 3: one he keeps as it is, `$S prepare attempt --kept
   <setting>[,<setting>...]`; one he says was put back by hand already, `--restored <setting> "his
   word: <what he said>"` (his word is the only way for a setting whose way back the list gives as
   the earlier attempt's script: the app, its data, Low Power Mode); any other, put it back by
   computer use as the list says (original -> new, and the way back), confirm it with a shot, then
   `$S prepare attempt --restored <setting>[,<setting>...] "<the shot>"`. The options may go in
   one call; `restored` itself is refused until this call succeeds. If an earlier arm window still runs, ask him to close that
   Terminal window. Then `$S help` and `$S status`.
2. **The start message,** one message in Russian, before anything changes:
   - What may change, and is written to `changes.tsv` first and put back: the installed BatteryPulse
     (his comes back from the backup); the appearance, the wallpaper (to a generated bright picture),
     Icon & widget style, Dim widgets on desktop, Text size; desktop widgets (a small and a medium
     added if missing, a blank one removed and added again, a test widget added and removed, Session
     A's dead Test widget removed for good); Low Power Mode for one run; BatteryPulse's settings and
     data, the widget's included, and his remembered iPhones and iPads, removed for the session so
     no picture shows their names.
   - Never: a VPN, undocumented system keys, anything in Privacy & Security, Users & Groups or
     Passwords, the brightness (his, at bedtime).
   - The questions: his bedtime (else 4 hours from now)? Keep Terminal's Accessibility until 0.7's
     Session R (else he turns it off in the morning)? And: "Please type /usage now and tell me what
     it shows."
   - Privacy: the pictures go to the model and stay on the Mac; his other desktop widgets appear in
     them; at the beep he quits his own apps.
   - Times: about 10 minutes of building, then a beep and about 10-15 minutes with him (his apps
     quit, any utility that keeps the Mac awake among them; the approvals; the first 5 minutes
     without touching the Mac, and hands off whenever you ask until you say he may go); then he
     may go. The GUI phase runs on its own, about 1-1.5 hours, ending 10 minutes
     before his bedtime at the latest. At bedtime the arm window asks for Return, his password, the
     brightness at about half with the keys, a Focus on, and the unplug; the queue then runs about 3
     hours (give the expected end, bedtime plus about 3 h 15 min) and the lid stays open until
     then. In the morning: the lid closed for a minute, opened, log in, plug in, write "continue"
     and keep off the Mac for about 3 minutes; then his yes before anything is sent.
   - End your turn and wait for his answer.
3. **Record** (only on an explicit yes; anything else changes nothing, and you end):
   `$S answer --by person B-yes y`; `B-bedtime HH:MM` if he gave one; `B-keep-ax y|n`; `B-usage
   "<what /usage showed, or what he said>"`.
4. **`$S prepare`** as a background task (about 10 minutes): the backup, the builds and tools, his
   remembered devices removed for the session, the RC installed. It ends with `BEEP (B0a is done)`.
   Wait on it with `$S wait 9` (never end your turn while it runs). If it fails, run it once more; if it fails
   again, tell him why, run `$S restore gui` and `$S restore morning` if `changes.tsv` lists
   anything, and end. Never `--fresh-backup` unless the script asks for it.
5. At the beep, say: "The build is done. Please quit your own apps (Terminal stays), any utility
   that keeps the Mac awake among them, then write me that you are back." End your turn.

## B0b: at the beep (he is there, about 10-15 minutes)

1. First `$S ui access`: prepare's reads and P1 use AX before preflight would ask. If it says
   `ax_trusted=no`, ask him to turn Terminal on under System Settings → Privacy & Security →
   Accessibility now (his switch, his Touch ID or password), then `$S ui access` again. Then `$S
   prepare reads`; read every shot it names and answer `prep-*` (table). If `prep-widgets` is 2,
   add the missing small or medium BatteryPulse widget by computer use (the gallery's click-to-add,
   then one slow `$S ui drag`), with `$S change desktop-widgets "<what was there>" "<what you added>"`
   first, and take `$S shot prepare-desktop-2`. Your first computer-use call, here or in step 4,
   requests access for P10's whole app batch (step 4) at once.
2. **P1 and the frames:** `$S proof P1 --image <shot> <x> <y>` at a widget's centre (the shot's
   pixels); then `$S widget small <x> <y> <w> <h>` and `$S widget medium ...` in points from P1's
   frames (no large or extra-large: the RC has none), and `$S desktop-spot --image <shot> <x> <y>` on
   empty desktop, away from icons and widgets.
3. Say: "For the next five minutes please don't touch the keyboard or the trackpad; answer any macOS
   prompt that appears." Then `$S preflight` (P2, P6-P9, P11, the reads, the keep-awake read and a
   150-second quiet check, last). He answers what comes up: Accessibility for Terminal if he revoked
   it (the switch, then `$S preflight` again), the developer tools, other apps' data. **A
   `KEEPAWAKE` line, or a failed quiet check:** say its `DO` line to him in Russian with the process
   name (the name only to him, never recorded), and on his word say: "Please don't touch the Mac for
   about three minutes", then `$S preflight quiet` (twice at most;
   if it still fails, `$S note "quiet check failed twice"` and go on: the arm window won't start the
   queue while another process holds a keep-awake assertion, and says so to him at bedtime).
4. Your proofs: `$S proof P3`, then `$S proof P3 <1|2>` from its pictures; `$S proof P4` (it runs P5
   too), then `$S judge P4-frames <1-3>`. P3-P5 now pass over the Dock's full-display window
   (macOS 27.2); a "didn't pass the occlusion check" names what covered the window. **P10:** one
   computer-use access request for the whole batch (BatteryPulse, System Settings, Finder,
   Notification Center, the widget host P1 named, TextEdit, Xcode), one widget click-to-add in the
   gallery and its removal (`$S change p10-widget none "added"` first, `$S restored p10-widget "<the
   shot that shows it gone>"` after), a screenshot right after the first action (where computer
   use's own notification lands), one System Settings click; then `$S proof P10 pass|fail "<what it
   showed>"`. An app it refuses: that app's steps go to scripting, else "not checked"; a failed
   gallery click: ask him to add or remove that widget now. Then each command family once, as
   preflight's `RUN` lines say (`ui idle`, `ui guard`, `shot`, `heartbeat`, one `measure` and
   `judge`, `status`), so every prompt comes now.
5. **The banners:** `ui banner` finds each banner by its English body, only inside a BatteryPulse
   banner, and presses it within 10 s: "This is how battery alerts will look" for V-01, "You can
   unplug the power adapter" for F11. `$S v01 notify`, then `$S v01 notify front`; answer
   `V01-notification` and `V01-notification-front`. `$S f11 alert` (it may wait up to 6 minutes);
   answer `F11-alert`.
6. `$S arm open`, then `$S mark away` (no sound, speech or question from here until his
   "continue"). Say: "A Terminal window named BatteryPulse arm opened; leave it open and the Mac on
   the adapter with the lid open. You may go. At bedtime that window asks for Return and your
   password, then the brightness at about half with the brightness keys, a Focus on, and the
   unplug; wait until it says 'Nothing to do' before you go." Then go straight on to B2, in the same turn: it needs nobody.

## B2: the GUI phase (he is away, about 1-1.5 hours)

It stops 10 minutes before his bedtime, or 4 hours after the start (`heartbeat` shows the minutes
left). Whatever is left then is `$S note "<item> not run (time)"`. In this order:

1. **The placed widgets:** `$S shot widgets-placed`. Session A's dead Test widget, if still there:
   one shot, then `$S change test-widget "placed" "removed"` and remove it by computer use; it isn't
   put back. A blank or grey widget anywhere: shoot it, answer, then `$S change <family>-widget
   "blank" "added again"`, remove it and add it again by computer use, `$S restored <family>-widget
   "<the shot>"`, and note that.
2. **V-01's other half:** `$S v01 menubar`, answer `V01-menubar`; then Raw Data, History, Demo Mode
   on and off, Check Now (close its offer by its own button) by `ui press`, `ui select-row` and `ui
   click`, computer use as the fallback.
3. **F6, F8, F9, F11's login item:** `$S f6 overview`, `power`, `history`, `health`, `raw`, each
   answered against the `bpulse --json` it prints; `$S f8`, `$S f8 ru on`, `$S f8 ru`, `$S f8 ru off`
   (small and medium in English and Russian; large and extra large are "not checked": no such
   family); `$S f9`, answer `F9-*`, then `$S relaunch` (English again); `$S f11 login`, turn Open at
   login off by `ui press` as it says, `$S f11 listed`, answer `F11-login`. If none of F8's Russian
   ways works, F8-ru is "not checked". Then Clear History by `ui press` (`V01-pages` is answered at
   item 7).
4. **Page switches:** `$S pages`; then `$S pages profiling` as a background task you wait on
   (`xctrace` with a watchdog, about 10 minutes), judging the backlog meanwhile. Without the
   profiling RC, or with P9 failed, it records "not run" itself.
5. **F12:** `$S f12 rate` (at least 10 requests left, else try again later in B2, then in the
   morning: "not run: rate-limited"); `$S f12 before`; Check for Updates, then Install and Relaunch,
   by `ui press`; `$S f12 after`, which prints the verdict lines: every extension process the
   installer found ended within 1,500 ms; no `BatteryPulseWidget` process started before the swap;
   no "can't be ejected by force" or "Ejecting the update's disk image failed" line (must be 0);
   Finder's on-screen windows during the install (more than before means a window opened). With no
   extension running before Install, item 6 is "not exercised". Answer `F12-widget`, then `$S
   install C`: the rest runs on the RC.
6. **WP-18,** without his hand: `$S wp18 previews`, resume the canvas in Xcode by computer use,
   answer `SUI-17`; `$S wp18 timing` as a background task you wait on. SZ-10 needs an `.icon`
   source under `Resources/`, which the frozen worktree doesn't hold: `$S note "SZ-10 not run: no
   icon source in the frozen worktree"`.
7. `$S v01 check` (the RC window's "executor" lines and crash reports); answer `V01-pages`.
8. **Optional, while time allows (about 25 minutes): the 8 glass-sheet cases,** which confirm G-13a
   on the RC: `$S case translucent-light-main`, and the same for `translucent-dark`, `clear-light`,
   `clear-dark` (`-main` and `-compact` each); read each frame sheet beside the darkest frame's
   luminance and answer `fill-*`. A clip that missed the animation: once more, then 3. A case not
   reached: `$S note "fill-<case> not run (time)"`; G-13a then rests on Session A.

## B3: the hand-over (about 3 minutes)

1. `$S restore gui`; do the items it lists for you by AX, System Events or computer use, each
   confirmed by a read or a shot and recorded with `restored`. It quits what the script opened
   (TextEdit, System Settings, Xcode); name any other open app in a note.
2. Stop every background task; schedule nothing. The brightness and the Focus are his, at the arm
   window's bedtime prompt: no computer use touches them.
3. `$S ready`, your last call. End your turn. From here only text answers until his "continue".

**B4-B6 run without you:** in the arm window, his Return and password, the brightness at about half
by the keys, a Focus on, and the unplug; the arm waits while another process holds a keep-awake
assertion (it names it to him there, at his Return already), then for 70 quiet seconds, then the
cooldown, which counts holders and HIDIdleTime's drops for the queue's section; its status line
says "On battery since HH:MM; cooling down until about HH:MM; the queue then runs until about
HH:MM. Nothing to do; don't press keys here." The queue (a discarded warm-up, S2 and S1 three pairs
each, S2 with Low Power Mode, S4w, S5, S10, S7, S3 and the minimized run, the retries, S6 last);
`restore night`; the night's sleep on the RC.

## B7: the morning, on his "continue"

1. `$S status`. If `queue.started` still exists, tell him when the queue should end, and act only
   then.
2. `$S continue`. Without a lid line it refuses: say "Please close the lid for a minute once more,
   open it, log in, then write continue again."
3. `$S v01 morning`, answer `V01-lid`; `$S morning` (sleep hygiene, the overnight log stream).
4. `$S charge-limit check` (nothing changed it; a read for the report).
5. `$S restore morning`; do the GUI items it lists (Open at login as prepare found it, and any
   other), each `restored`. Anything you can't put back heads the report, for his hand.
6. `$S batch`: if it lists items you answered 3 or unsure, offer them in one line ("N items I
   wasn't sure about: look now, or skip and they keep their defaults?"); on "look", give each
   picture's full path (he types `! open <path>` at your prompt, or uses Finder; you never open a
   file by computer use) and record each with `--by person`.
7. `$S send --dry-run`; give him its `SHEET` (every attached image) the same way, summarize
   `~/bp-062/B/B.md` in Russian, and add: "If you added any allow rule beyond the start line's,
   tell me which." Record that with `$S note "allow rules he added: <his answer, or none named>"`.
   On his yes, `$S answer --by person B-send y`, then `$S send`. A lint refusal names a line: drop
   it (`unattach`, or leave the note out), tell him, `send --dry-run` and his yes again. A failed
   push keeps everything in `~/bp-062/B`; `send` can run again later on the same yes.
8. Say: "Please turn the Focus off and set the brightness as you like it" and, unless `B-keep-ax`
   is y, "and turn Terminal off in System Settings → Privacy & Security → Accessibility." Then end.

## If the session restarts or compacts

- After a compaction or a restart, first `$S charge-limit check` (unless `ready` is up), then read
  this file again from `~/bp-062/B/run`, `$S status`, and `~/bp-062/B/answers.tsv` and
  `changes.tsv`, and go on from the first step not done (a step that ran as the old session's
  background task: run it once more). If `ready` is up or `queue.started` exists, only text answers
  until "continue".
- If he starts the launcher again, B0a's step 1 sends the new session here (the same commit).

## After publishing (D3's short session)

```
git -C ~/BatteryPulse fetch origin main
bash <(git -C ~/BatteryPulse show FETCH_HEAD:docs/plans/0.7.0/start-after-publishing.sh)
```

He types these two lines in Terminal, from any folder, once v0.6.2 is published. The launcher,
`start-after-publishing.sh` beside this file, changes to `~/BatteryPulse` and starts Claude Code
there in auto mode with no allow rule; its sentence has you fetch `main` and read this section. His
part is the two lines and any dialog you ask him to answer: about 2 minutes. This section stands
alone: nothing above it applies (no script, no `$S`, no worktree, no heartbeat, no fence, no
`send`), and everything you need is below.

**Where you run.** In `~/BatteryPulse`, with computer use enabled (`/mcp` lists `computer-use`; if
it doesn't, ask him to enable it there, `/mcp` → `computer-use` → Enable, and go on when he says
so), in permission mode auto, with no allow rule.

**Rules.**
- Talk to him in Russian, always. The quoted phrases below are what to say, in Russian.
- Record nothing and push nothing: no commit, no branch, no push, no pull request, no file written
  in `~/BatteryPulse` or anywhere else. The start sentence's `git fetch` and `git show` are your
  only git commands.
- The only other commands are step 4's two reads, `codesign -dv --verbose=4
  /Applications/BatteryPulse.app` and `xattr -l /Applications/BatteryPulse.app`, each as written, one
  per Bash call. Never `gh` (it isn't on his Mac), `sudo`, `defaults`, `killall`, `sfltool`, an
  install or a copy. If auto mode blocks a command, don't retry it: its check is "not checked:
  blocked".
- Everything else is computer use: screenshots and clicks in BatteryPulse and System Settings.
  Your first computer-use call asks him, in Claude Code, to let you use apps: ask once for
  BatteryPulse, System Settings, Finder and Notification Center (the last two show the desktop and
  its widgets; asking for them opens nothing). Checks in an app he doesn't allow are "not checked:
  no access". BatteryPulse and System Settings may show their Russian names; the English ones are
  given here. Never send Esc (it would end your turn): close a window with its close button, the
  popover by a second click on the menu bar item.
- Read settings, never change them: in BatteryPulse's Settings and in System Settings (open it from
  the Apple menu), click only the tabs, sidebar items and rows that open a page (General → Login
  Items & Extensions, Notifications → BatteryPulse), never a switch, menu or button on a page.
  Close each window you opened when you are done with it.
- A check that fails to run, or a screen you can't read: try once more only if the cause was passing
  (a window not up yet); otherwise it is "not checked", with the reason. Go on either way.

**Privacy.**
- Screenshots go to the model only: never save one, and never put one in the repository.
- No screenshot while Notification Center or Control Center is open.
- Never type his password, never approve a permission or authorization dialog, and never open or
  touch Privacy & Security, Users & Groups or Passwords in System Settings. If a dialog asks for any
  of that, ask him to answer it; if he doesn't, that check is "not checked: dialog".
- His other windows, apps and widgets may show in screenshots: never name or describe them, in the
  summary or anywhere else.

**Steps.**
1. Say: "This is the check after the 0.6.2 update, about 5 minutes. Please keep off the Mac until I
   say so. First Claude Code asks you to let me use BatteryPulse, System Settings, Finder and
   Notification Center: please allow it. After that, answer a dialog only if I ask. At the end you
   get a short summary to forward to the cloud session. If something fails, the cloud session will,
   on your yes, mark v0.6.2 a prerelease." Go on without waiting.
2. **Before the update** (0.6.1 installed and running): open BatteryPulse's Settings (the popover's
   Settings button, or BatteryPulse's menu) and note:
   - General: whether Open at login is on;
   - Menu Bar: the icon style and what the item shows; and look at BatteryPulse's menu bar item;
   - Notifications: whether it offers Send Test Notification or says "Notifications are turned off
     for BatteryPulse in System Settings.";
   - the desktop widget: its charge and its "Lasts until" time (or the time it shows while
     charging), with the clock time you read it. With no BatteryPulse widget on the desktop, the
     widget checks are "not checked: no widget".
3. **The update:** Check for Updates… (in About BatteryPulse, which the popover's About button
   opens, or in BatteryPulse's menu); in the update window that offers 0.6.2, Install and Relaunch.
   Wait until BatteryPulse is back in the menu bar (about a minute, at most 3). If no update is
   offered, or the install shows an error, note its message: the update failed.
4. **After the update:**
   - About BatteryPulse shows version 0.6.2;
   - the main window's History page (the popover's Open BatteryPulse button opens the window) shows
     the past days (its chart reaches back before today), not an empty page;
   - Settings: General's Open at login, Menu Bar's choices and Notifications' line are as in step 2,
     and the menu bar item looks as it did;
   - the widget shows a current value: a charge, not blank or grey (give it up to 2 minutes after
     the relaunch); note which it is: still placed with a current value, blank or grey, or gone;
   - Login Items: if Open at login was on in step 2, System Settings → General → Login Items &
     Extensions still lists BatteryPulse under Open at Login;
   - notification permission is kept: Settings → Notifications as in step 2 (if unsure, System
     Settings → Notifications → BatteryPulse shows its notifications allowed);
   - `codesign -dv --verbose=4 /Applications/BatteryPulse.app` prints
     `flags=0x10002(adhoc,runtime)` (it writes to stderr: read all of its output);
   - `xattr -l /Applications/BatteryPulse.app` prints no `com.apple.quarantine` line.
5. **The popover:** click BatteryPulse's menu bar item and compare its charge and time with the
   widget's: they agree within 2 points and about 15 minutes. The popover shows the time as a
   duration ("… left", or "Full in …" while charging): add it to the clock time you read it, and
   compare that with the widget's "Lasts until about …" (or "Full at …"). His everyday use on the
   first day is the second look. Close the popover with a second click.
6. **The end:** say "Done, you can use the Mac again. Please forward this to the cloud session:",
   then a short summary in Russian: each check of steps 3 to 5 as passed, failed or not checked
   (with the reason), and the values read (the version in About, the `flags=` line, whether a
   quarantine line was there, Open at login before and after, the widget's state after the update,
   the widget's and the popover's charge and times). On any failure, add: "On your yes, the cloud session marks v0.6.2 a prerelease, so
   0.6.1 is served as the latest again; nothing on this Mac does that." Then end your turn.
