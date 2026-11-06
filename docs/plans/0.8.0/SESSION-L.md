# M5 look shoot: the hands-free runbook

The look shoot of BatteryPulse 0.8 (PLAN.md §6.1, on `docs/plans/0.8.0/PLAN.md`) runs on the MacBook
Air M5 after round C7 merges, on a CI build of `claude/080-integration`. One local Claude Code
session with computer use does every step itself, through `m5-session.sh` and its `ui` helper. The
maintainer does only what needs a person: the start line and one yes, quitting his own apps (the
Claude desktop app among them), postponing a pending macOS update, the permission prompts, the
adapter at the beeps, Q8-3's answer, and his yes before `send` (about 5-8 minutes, 2 more with a
low-wattage adapter). It takes about 2 hours [estimate]; the shots go to the look review (§6.2) and,
in Russian, to the Russian review (§6.3).

The start line printed only the section "Look shoot" (section.sh); it tells you which sections of
this file to read next, from the frozen worktree.

## Look shoot

You run the BatteryPulse 0.8 look shoot. The start printed this section alone. `$S` stands for
`bash ~/bp-080/L/run/docs/plans/0.8.0/m5-session.sh`, written in full in every call. First:

1. **The worktree.** `git -C ~/BatteryPulse rev-parse FETCH_HEAD` is the commit section.sh read
   this from. If `~/bp-080/L/run` exists at the same commit, this is a restart: read
   `~/bp-080/L/run/docs/plans/0.8.0/SESSION-L.md` from "If the session restarts or compacts". At
   another commit: ask him whether this is a new attempt; on his yes, `git -C ~/BatteryPulse worktree
   move ~/bp-080/L/run ~/bp-080/L/run-<its first 7 characters>`. Then `git -C ~/BatteryPulse
   worktree add --detach ~/bp-080/L/run FETCH_HEAD`.
2. **`$S prepare attempt`**, your first script call: an earlier attempt's folder moves aside once
   its changes are back, so this attempt takes its own backup and counts; if it lists some not back,
   follow its message (`--kept` on his word, `--restored` after you put one back and shot it).
3. **Read**, with your file-reading tool, these sections of
   `~/bp-080/L/run/docs/plans/0.8.0/SESSION-L.md`: Rules, Privacy, Decisions you make alone, L0 to L5,
   If the session restarts or compacts, and Answers. No other file's sections are yours.
4. Then `$S help` and `$S status`, and begin at L0.

## Rules

- **Language.** Talk to him in Russian, always. Everything recorded is English: `answer`, `judge`,
  `note`, `change`, `restored`, `attach` captions; the script refuses Cyrillic.
- **One prefix.** `$S` stands for `bash ~/bp-080/L/run/docs/plans/0.8.0/m5-session.sh`. Write it in
  full in every call, exactly so, one script call per Bash call: no `cd`, no variables, no pipes, no
  redirection, no `&&`. The only commands outside it are the start's `git fetch`, `git show`, `git
  rev-parse`, `git worktree move` and `git worktree add`, under auto mode. `$S help` lists the
  commands, the header of `ui.swift` beside the script lists `ui`'s. Read files (shots, logs, `L.md`,
  `answers.tsv`, `changes.tsv`) with your file-reading tool, never with a shell command.
- **Frozen.** This file, the script and `ui` are fixed at the start's commit. Never edit them, never
  fetch again, never adopt a later fix: a fix goes to the next session.
- **Permissions.** Never add or change a permission rule, never change Claude Code's or git's
  configuration, never retry a command auto mode blocked (its step is "not run: blocked"). Never type
  a password, never approve a permission or authorization dialog, never toggle anything in Privacy &
  Security, Users & Groups or Passwords.
- **Long calls.** Give every script call the Bash tool's `timeout: 600000`. `prepare`, `charge-limit
  unplug` and `weak-adapter in` run as background tasks: wait on them with `$S wait <minutes>` (1-9)
  in the foreground, with `timeout: 600000`, until they end; never `sleep`, never a quick loop of
  reads, and never end your turn while a background task runs. While a task runs, the screen is the
  task's: no GUI action, but for the Charge Limit's hold, which waits between your screens (L1).
- **Order of means.** The script and `ui` (AX, CGEvent, CGWindowList) first, computer use where they
  can't reach. Neither ever sends Esc (it would end your turn) or a key press `ui`'s rules don't
  allow. Before any change by computer use or AX outside the script: `$S change <setting> <original>
  <new>`; after putting it back: `$S restored <setting> <how it was confirmed>`. A setting whose
  original is unknown is never changed. The setting names: `charge-limit`, `demo-mode`,
  `desktop-widgets`. The script records its own changes (the app, its settings and data, its
  language, `hasSeenWelcome`, the window style, the sentinel file) and puts them back itself.
- **The rules from 0.6.2's and 0.7.1's sessions** (PLAN.md §6.0, T-1 item 5):
  1. The start printed only this runbook's section (section.sh); read only the sections it names.
  2. **Dock presence before access:** `$S main` before computer use asks for access to BatteryPulse
     (an agent app has no Dock icon, so the request can't name it otherwise).
  3. A window is shot by the script (`screen`, `pages`, `scene-shots`: `screencapture -R` at its
     frame after the occlusion check, never `-l`, which leaves out what lies behind a glass sheet),
     never by computer use: computer use's screenshots go to the model, not into the results.
  4. The script closes BatteryPulse's windows by their own close button, or with BatteryPulse made
     active first (Session F: a Command-W reached no window of an inactive agent app).
  5. BatteryPulse's own language is the script's to set (`app-language ru | back`): Language &
     Region's per-app menu belongs to System Settings' own process, which computer use can't act in.
  6. Computer use ends each batch with a pointer move to bare desktop (its 28×40 overlay fails the
     occlusion check).
- **System Settings.** Open panes by computer use from the sidebar (the Appearance, Desktop & Dock
  and Displays URLs open other panes on macOS 27.2). The Battery pane's URL works: `$S pane battery`.
- **Places.** Terminal windows in the left third of the screen, BatteryPulse's windows on the right,
  away from the top-right corner where banners land.
- **Commits.** You commit and push nothing. The only push is `send`'s, to `claude/080-session-l`,
  after his yes. No other branch, no pull request.

## Privacy

- Every picture you read, and every computer-use screenshot, goes to the model; none goes into the
  repository but the script's own crops you attach. His apps quit and the hidden ones limit what
  they show; his desktop is in them (the start message says so).
- Only crops of BatteryPulse's windows are attached (`$S attach`), never a full-screen shot. The
  Accessories page lists his accessories by name: shoot it, read it, never attach a shot that shows a
  name (the sentinel's note may show none; then it may go). Never write a name in a note or answer.
- Report a Problem's saved files stay on the Mac (`report-check` reads them; the report gets only
  counts). After a save BatteryPulse opens GitHub's issue chooser in his browser: take no
  computer-use screenshot while that browser is in front; bring BatteryPulse forward with `$S main`.
- `pmset -g` outputs reach `L.md` only as the script writes them; `send`'s privacy lint checks the
  report, the samples and the captures.

## Decisions you make alone

- **A step fails or misbehaves:** read the message; run it once more only if the cause was passing (a
  window not up yet, a timeout); else `$S note "<step>: <what happened>"`, and its items are "not
  checked" or "not run" with the reason; go on.
- **Never repair the Mac's state by hand:** no `killall` or restart of a system process, no
  `lsregister`, no install, swap or copy of a build but through the script.
- **The order is fixed,** but for the hold (L1), which waits between step 3's screens.
- **A prompt or a password dialog:** ask him to answer it while he is there; while he is away, leave
  it, record "not checked: prompt" (for the Charge Limit's reads: G8-5-limit n), and go on.
- **A lock screen or the lid closed:** stop all GUI work, record "not checked: locked", and wait.
- **Findings** (a wrong value, a cut word, a crash report): note them with their evidence and go on;
  never investigate beyond the step's reads, never patch anything.
- **Anything not on the yes-list:** never change it; a step that would need it is "not checked".
- **Anything this file doesn't cover:** do what changes nothing, record "not checked" with the reason.

## L0: the start (he is there)

1. **The start message,** one message in Russian, before anything changes:
   - What changes, each recorded first and put back: the CI build installed over his BatteryPulse
     0.7.1, which comes back at the end with his settings and data (his history kept); his remembered
     iPhones and iPads hidden until then; the Charge Limit set to two values and to 100 %, then back
     to his; BatteryPulse's language switched to Russian and back; `hasSeenWelcome` cleared and put
     back (Welcome as a new user sees it); Demo Mode on and off; the window style set to Clear with
     beta styles on, and back; a sentinel file placed and removed; Report a Problem's files saved
     into the session's folder (his browser then opens GitHub's issue chooser); the display kept
     awake until the end.
   - Never: anything in Privacy & Security, Users & Groups or Passwords; his own widgets.
   - His part: quitting his own apps and the Claude desktop app, Later for a pending macOS update,
     the approvals, and the adapter: unplug at a beep, plug in at a second beep about 7 minutes
     later. **Q8-3:** does he have a low-wattage USB-C adapter (a phone's) at hand? Then two more
     beeps in step 4: that adapter in, then his usual one back.
   - Privacy: the pictures go to the model and stay on the Mac; his desktop appears in them.
   - "Please type /usage now and tell me what it shows." End your turn and wait.
2. **Record** (only on an explicit yes): `$S answer --by person L-yes y`; `L-adapter y|n` (his Q8-3);
   `L-usage "<what he said>"`.
3. **`$S prepare`** as a background task (several minutes), waited on with `$S wait 9`: the backup,
   the CI build L, the tools, the placed widgets as his BatteryPulse counts them, L installed the
   way UpdateInstaller does it, the display kept awake. It ends with `BEEP`.
4. At the beep, say: "Please quit your own apps (Terminal stays), the Claude desktop app among them,
   and if Software Update offers an update, choose Later. Then write me that you are done." End your
   turn.
5. `$S preflight`: its DO lines go to him in Russian. Then **`$S main`**, and only then one
   computer-use access request for BatteryPulse, System Settings and Finder. `$S ui access`.
6. `$S prepare reads`. If it asks, read the Charge Limit from System Settings → Battery → (i) next to
   Charging by computer use and answer `prep-charge-limit`; if it said 100, confirm it by that pane's
   shot (`$S shot settings-battery`).

## L1: the Charge Limit (G8-1, with him there for the beeps)

The Mac stays on the adapter. A slider move that asks for a password or Touch ID is his: ask him.

1. `$S charge-limit read start`: the reads at his own limit, before any change.
2. **The hold:** the limit at the step at or just below the charge (`$S status` shows it); with the
   charge under 80 %, 80 (the Mac charges to 80 and holds there; step 3's screens run meanwhile). `$S
   change charge-limit <prepare's> <n>`; System Settings → Battery → (i) next to Charging, the slider
   to `n`, by computer use; `$S charge-limit set <n>`. Then `$S charge-limit hold`: `HELD` takes the
   reads; `NOT YET` means go to L2, and call `$S charge-limit hold` again between its screens until
   `HELD` (at most an hour after the set; then it records "not checked" itself).
3. **A second limit above the charge,** if one exists below 100: `$S change charge-limit <n> <m>`, the
   slider, `$S charge-limit set <m>`, `$S charge-limit read second` (charging toward it).
4. **100 %:** `$S change charge-limit <m or n> 100`, the slider, `$S charge-limit set 100` (its reads
   are tagged full).
5. **Back to the hold's value** (the change, the slider, `$S charge-limit set <n>`). Say: "At the
   first beep unplug the adapter; at the second beep, about 7 minutes later, plug it in again." `$S
   charge-limit unplug` as a background task, `$S wait 9` until it ends.
6. **His limit back:** `$S change charge-limit <n> <prepare's>`, the slider to prepare's value, `$S
   charge-limit back`, and a shot of the pane (`$S shot settings-battery-back`).
7. `$S charge-limit verdicts`; answer `G8-5-limit` from what the screen showed at each read.

## L2: the screens (English, then Russian)

Run the whole list in English, then `$S app-language ru` and the list again (skipping what says
English only), then `$S app-language back`. In Russian, `ui press` takes the Russian labels (`$S ui
tree BatteryPulse --match <word>` finds them). Every shot is the script's (`screen`, `pages`,
`scene-shots`); between them, `$S charge-limit hold` while L1's hold waits.

1. **A-1's causes:** `$S main`; Developer → Demo Mode by `$S ui select-row BatteryPulse "Demo Mode"`;
   `$S change demo-mode off on` (each time Demo Mode starts); for each scene that names why the
   battery isn't charging (Charge limit, the scene with no reason, and any scene A-1 added for a
   proven cause): its
   row by `$S ui press BatteryPulse "<the scene's title>"`, then `$S scene-shots a1-<scene>`. In the
   no-reason scene, the info button by `$S ui press` and `$S screen a1-reasons` (its popover). A-2's
   number, if its scene exists: `$S scene-shots a2-number`. Stop Demo by its own button (`$S ui
   press`), then `$S restored demo-mode "<the shot without the demo bar>"`.
2. **A-3's summary:** `$S pages a3-health Health`.
3. **Q8-4's badge:** `$S window-style clear`; `$S change demo-mode off on`, Demo Mode's worn-battery
   scene by `$S ui select-row BatteryPulse "Demo Mode"` and `$S ui press`; `$S pages q84-badge
   Overview Health`; `$S window-style back` (its relaunch ends Demo Mode), then `$S restored
   demo-mode "<the relaunch ended it: a page without the demo bar>"`.
4. **A-4's explanations:** on Overview, Power and Health (and a device's page when one shows), one
   row's help tag (a `$S ui move <the row's centre> --expect BatteryPulse`, two seconds, `$S screen
   a4-<page>-tag`) and its info popover (`$S ui press` on its info button, `$S screen
   a4-<page>-popover`); in the menu bar popover one row's help tag (`$S screen a4-popover-tag
   popover`).
5. **A-5's Welcome:** `$S welcome first`; if it doesn't fit, scroll it by computer use and `$S screen
   welcome-end front`; then `$S welcome back`.
6. **A-6's Report a Problem:** Help → Report a Problem… by `$S ui press`; `$S screen a6-window front`;
   the preview scrolled to its end by computer use, `$S screen a6-preview-end front`; the second
   choice (Include the crash reports' contents) by `$S ui press`, `$S screen a6-choice-2 front`. In
   English only: Save… with each choice, into `~/bp-080/L/report/` (the save panel by computer use;
   the folder's path typed there is allowed, never a password), then `$S main` (the browser opened
   GitHub's issue chooser: no screenshot of it), and `$S report-check`.
7. **P-1's note:** `$S sentinel place`; `$S screen sentinel-note`; Turn On Again by `$S ui press`;
   `$S sentinel check`; `$S screen sentinel-after`.
8. **A-7's link** (English only): `$S help-link`.
9. **Attach** each screen the look review asks about, its caption beginning with its §6.2 question
   (1 A-1's sentence and Battery Settings…, 2 the info button, 3 A-2's number, 4 Health's summary,
   5 Clear's badge, 6 a help tag and popover, 7 Welcome, 8 Report a Problem, 9 P-1's note), the
   language last ("Q4 Health's summary, en"): `$S attach <shot> "<caption>"`.

## L3: the weak adapter (only with his Q8-3 yes)

Say: "At the beep, plug in the low-wattage adapter in place of yours; at the next beep, about 3
minutes later, your usual one again." `$S weak-adapter in` as a background task (the beep, the
change waited for, a 2-minute load the script bounds, captures at 30 s and 2 minutes); read its keys
and answer `L-weak-adapter`; then `$S weak-adapter out`.

## L4: restore, the widgets' counts and the summary

1. `$S restore end`: his BatteryPulse 0.7.1, his settings and data back (History kept), the
   widgets counted after its relaunch; then each `RESTORE` item it lists, each confirmed and
   recorded (`restored`). The session's widgets come back only by the app's counts: after removing
   any it added, `$S widgets-check`; never `restored desktop-widgets`, which the script refuses.
2. `$S faults` (crash reports and faults since prepare, which must be 0).
3. `$S summary end`: from its lines, the summary in Russian, for him to read first: an alert for
   every `ALERT` line (each widget kind that stayed or is gone, by count), then every setting the
   session changed and how it was confirmed back.

## L5: send

`$S batch` (the items you answered 3 or unsure: offer them in one line; on "look", give each
picture's full path, he types `! open <path>`, and record each with `--by person`); `$S send
--dry-run`, its `SHEET` and the report's summary to him in Russian; on his yes, `$S answer --by
person L-send y`, then `$S send` (`L.md`, the attached crops, the samples and captures, to
`claude/080-session-l`). A lint refusal names a line: drop it, tell him, dry run and his yes again.

## If the session restarts or compacts

First read this file again from `~/bp-080/L/run`, then `$S status`, `~/bp-080/L/answers.tsv` and
`changes.tsv`, and go on from the first step not done (a step that ran as the old session's
background task: run it once more). If he starts the line again, the start's first step sends the
new session here (the same commit).

## Answers

Steps print `ASK <id> [who; kind]: <question>` and `LOOK` lines. Look at every picture they name. A
`judge` question is yours: `$S judge <id> <answer> [--unsure] [note]`, the note in English naming
the picture. A `person` question is his: `$S answer --by person <id> <value> [note]`. `y` always
means "looks right"; numbered questions take the number. The script records its own reading of the
objective checks (G8-1's, the report files, the sentinel); an unsure one joins his batch. Never
guess: unsure is `--unsure`.

| Question | Criteria | Can't tell or no answer |
|---|---|---|
| `prep-charge-limit` | `pmset -g battlimit`'s number, else the Battery pane's shot | unknown (never changed) |
| `G8-1-*` | the script's reading of the reads' table (the app's line, `bpulse --json`, battlimit) | his batch |
| `G8-5-limit` | no dialog on the screen at any read | `--unsure` |
| `L-samples`, `L-limit-back` | the script's; the samples' decoded numbers against battlimit's | his batch |
| `L-a1-scenes`, `L-a3-health`, `L-a4-help`, `L-a5-welcome`, `L-a6-window` | each shot shows what its step names, readable, nothing cut, in both languages (the look itself is his, §6.2) | `--unsure` |
| `L-a2-number`, `L-q84-badge`, `L-a7-link` | the number, the badge's words, the link's ref as the step names them | 3 |
| `L-a6-file`, `L-p1-note` | the script's reading | his batch |
| `L-weak-adapter` | 1 a charger key changed under load (name it), 2 none did | 3 |
| `L-*` (his) | his answers | `L-adapter` n (step 4 skipped); `L-send` n (nothing is sent) |

Every item left "not checked" or "not run" takes its gate's default (PLAN.md §7.1).

## Before the look shoot (him)

Not printed for the session: what he does himself.

1. Once, any day before: in `~/BatteryPulse`, `claude`, then `/mcp`: `computer-use` is enabled. He
   asks that session: `Check the launcher docs/plans/0.8.0/start-session.sh (git fetch origin
   claude/080-integration && git show FETCH_HEAD:docs/plans/0.8.0/start-session.sh) against claude
   --help and the Claude Code documentation, and answer me in Russian.` It checks that
   `--allowedTools`, `--permission-mode auto`, the rule `Bash(<prefix>:*)` with `~` as written, and
   `DISABLE_AUTOUPDATER=1` are still the documented spellings, and changes nothing.
2. Don't install a macOS update or a BatteryPulse update before the session.
3. The start, on the adapter, in Terminal, from any folder:

```
git -C ~/BatteryPulse fetch origin claude/080-integration
bash <(git -C ~/BatteryPulse show FETCH_HEAD:docs/plans/0.8.0/start-session.sh) look-shoot
```

The launcher changes to `~/BatteryPulse` and runs PLAN.md §6.1's start line: one allow rule,
`Bash(bash ~/bp-080/L/run/docs/plans/0.8.0/m5-session.sh:*)`, auto mode, and a sentence whose
section.sh prints this file's section "Look shoot" alone.
