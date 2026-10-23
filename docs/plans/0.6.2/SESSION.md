# M5 Session A: the runbook for a Claude Code session on the Mac

**The maintainer pastes this one sentence into Claude Code, started in `~/BatteryPulse` on the
MacBook Air M5:**

> Run BatteryPulse's M5 Session A: in ~/BatteryPulse run `git fetch origin claude/nice-faraday-k08mhb && git show FETCH_HEAD:docs/plans/0.6.2/SESSION.md`, then follow that runbook from its first step.

Everything below is for you, the Claude Code session on the Mac. It turns PLAN.md §6 "Session A"
into what you do, in order. The script `docs/plans/0.6.2/m5-session.sh` does the work; you run it,
read what it prints, look at the pictures, judge, and record. About 65 minutes hands-on, then a
3-hour unattended window that ends with restore and `send`.

## Ground rules

- **Language.** Speak Russian with the maintainer, always: questions, requests, summaries. Write
  English into everything that is recorded: `answer`, `note`, `attach` captions and anything you
  commit. The repository is English only, and the script refuses Cyrillic text.
- **You run the steps yourself.** Run every command of the script, read the logs and the counts it
  prints, look at every screenshot (`SHOT` lines) and every frame sheet (`LOOK` lines) with your
  file-reading tool, and answer the questions marked `judge` yourself.
- **Ask the maintainer only for what needs a person:**
  - the administrator password (only in the `window` step, typed by him in Terminal) and any
    password dialog macOS shows;
  - macOS permission prompts (Screen Recording, Automation, access to other apps' data, Local
    Network, developer tools);
  - closing and opening the lid; unplugging and plugging the adapter; the keyboard, the earbuds and
    the iPhone in F5;
  - listening to VoiceOver;
  - taste questions, and a `judge` question you can't settle from the pictures (say so in the
    note, and record his answer with `--by person`);
  - the clicks and settings in the user interface that the script prints as `DO (person)`, unless
    you have tools to see and control this Mac's screen: then do them yourself, one at a time, and
    leave him only the items above.
- **Secrets.** Never ask for, type, read, store or log a password, token or key. `sudo` runs only
  in the `window` step, in Terminal, where he types the password himself. If a command you run
  would need `sudo` or a password, stop and hand it to him.
- **Settings.** Change nothing beyond what restore puts back. The script changes BatteryPulse's
  settings, the appearance and Low Power Mode, and restore puts all of them back, with the
  wallpaper. The other settings the steps touch (Icon & widget style, Dim widgets on
  desktop, Text size, VoiceOver) go back by hand from restore's list. Don't write other defaults,
  don't change System Settings beyond the steps, don't reset permissions, don't change Claude
  Code's or git's configuration.
- **The repository.** Don't edit files in `~/BatteryPulse` and don't commit there. The only push is
  the script's `send`, to the branch `claude/062-session-a`. Never another branch, never a pull
  request, never recordings, traces or raw captures.
- **What gets published.** `send` commits `docs/plans/0.6.2/sessions/A.md`: the answers, counts,
  `perf-stats` output and log excerpts. Those excerpts hold only public values: the logging system
  shows private values as `<private>`, and the script replaces your home folder with `~`. Only the
  images you `attach` go with it: crop them to BatteryPulse's windows, widgets or menu bar item.
  Leave out other apps, notifications, device names, people and personal wallpaper.
- **Errors.** Read the message; most say what to do. Every step can run again: it rewrites its
  own section. Don't edit the script. If it misbehaves, `note` what happened, work around it only
  when that is harmless, and say so in your report.
- **Long steps.** Give the Bash tool a timeout of 600000 ms for `prepare`, `spike`, `voiceover`,
  `fill record`, `attach-timing` and `pages`. If a sandbox blocks a step (writes under `~/bp-062`
  or `/Applications`, `log`, `open`, `screencapture`), ask the maintainer to approve running it
  outside the sandbox.

## Before step 1

1. **Check the Mac.** Run `sw_vers` (macOS 27), `xcode-select -p` (Xcode is installed),
   `gh auth status` (signed in to github.com) and `pmset -g batt`. The window needs at least 50 %
   after the hands-on hour, so start with about 70 % or more, on the adapter.
2. **Get the script without touching his checkout:**

   ```
   git -C ~/BatteryPulse fetch origin claude/nice-faraday-k08mhb
   git -C ~/BatteryPulse worktree add --detach ~/bp-062/repo FETCH_HEAD
   ```

   `FETCH_HEAD`, because a clone of one branch doesn't update `origin/claude/nice-faraday-k08mhb`.
   If `~/bp-062/repo` exists already, update it instead (each worktree has its own `FETCH_HEAD`):
   `git -C ~/bp-062/repo fetch origin claude/nice-faraday-k08mhb && git -C ~/bp-062/repo checkout
   --detach FETCH_HEAD`.

   Below, `$S` stands for `bash ~/bp-062/repo/docs/plans/0.6.2/m5-session.sh`. Write it out in
   full in every command, since a shell variable may not survive from one command to the next;
   the script prints its own commands the same way. `$S help` lists every command.
3. **Screen Recording first.** Run `screencapture -x /tmp/bp-check.png` and look at the picture.
   If it shows only the wallpaper and the menu bar, without windows, the app that runs you can't
   record the screen. Ask the maintainer to allow it in System Settings → Privacy & Security →
   Screen & System Audio Recording. macOS then asks to quit and reopen that app, which ends this
   conversation: tell him beforehand to reopen it, start Claude Code again in `~/BatteryPulse` with
   `claude --continue`, and say "continue". Delete `/tmp/bp-check.png` after you've looked.
4. **Arrange the screen with him.** Keep the window you run in on one side of the screen for the
   whole session, and keep the BatteryPulse widgets on the other, where nothing covers them. The
   widget screenshots compare the same spot every time.
5. Tell him, in Russian, what the session is: about an hour together, then 3 hours on battery
   unattended. He will need the adapter, the lid and his password, and maybe a Bluetooth keyboard,
   earbuds and an iPhone with its cable for F5.

## The steps

Each step's commands print `ASK <id> [who; kind]: <question>` lines and `DO` lines. `who` is
`person` (ask the maintainer) or `judge` (you decide from the evidence; ask only when you can't).
Record each answer with `$S answer <id> <value> [note]`:
- `y`/`n` questions: `y` always means "looks right".
- Numbered questions take the number. Put what you saw in the note, in English, with the
  screenshot or frame it comes from, for example `frame-0012 shows an even grey shape`.
- `$S status` shows what is still unanswered.

### 1. prepare (3 min)

- Run `$S prepare`. It checks the tools, takes the backup into `~/bp-062/A/backup` (the app,
  BatteryPulse's settings, Application Support, the appearance, the wallpaper and Low Power Mode),
  downloads the builds and builds the helpers and `bpulse`. Then it puts 0.6.1 in front and takes a
  screenshot.
- macOS may ask whether the app that runs you may control System Events and BatteryPulse: the
  maintainer clicks Allow.
- Ask him the three `person` questions:
  - Icon & widget style (System Settings → Appearance);
  - Dim widgets on desktop (System Settings → Desktop & Dock);
  - Open at login (BatteryPulse Settings → General).
- Record his answers in English, for example `Default`, `Automatically`, `1`.
- Judge `prep-widgets` from the screenshot. Without a small and a medium BatteryPulse widget on
  the desktop, he adds them (right-click the desktop → Edit Widgets), where nothing covers them.
- Run `$S widgets-ref`. Its screenshot is the reference for step 3.

### 2. F5, accessories and devices on 0.6.1 (5 min)

- Run `$S f5 start`. Then, for each state, he sets it up and you run
  `$S f5 capture <state>`:
  - `keyboard-bluetooth`, `keyboard-cable`;
  - `earbuds-out`, `earbuds-in-case`;
  - skip the states he has no device for, and `note` it.
- iPhone, if he has one at hand:
  - He connects it with a cable and answers the prompts on the iPhone and the Mac. Ask him whether
    macOS asked about the local network.
  - He opens the main window on the iPhone's page. You run `$S shot f5-iphone-attached`.
  - He unplugs it. You run `$S shot f5-iphone-detached`.
- Run `$S f5 end`. Judge `F5-accessories` by reading the captures in `~/bp-062/A/logs/f5-*`:
  - does `bpulse --accessories` list what `pmset -g accps` lists?
  - Report only counts and kinds; the device names stay on the Mac.
- Judge `F5-iphone` and `F5-attach-detach` from the two screenshots (`3` and a note when there was
  no iPhone).

### 3. The widget spikes (23 min)

1. `$S spike c` installs SPIKE-C over 0.6.1, waits 30 s and takes `widgets-C`. Compare it with
   `widgets-ref`: the same widgets, in the same places, with values and nothing blank. Then answer
   `W0-2-C`.
2. `$S spike i` installs SPIKE-I.
   - He adds a large and an extra-large BatteryPulse widget.
   - You run `$S shot widgets-I-all` and answer the four `W0-2-I-*` questions.
3. `$S spike w` installs SPIKE-W and prints the plan of this step: follow it in order.
   - **Edit sheets.** He opens Edit "Battery" on the medium widget, and later Edit on the Test
     widget; you take `edit-battery-en` and `edit-test-en`. Compare them with the expected
     parameter names the step printed (Battery: Layout, Main value, Time, and Details once Layout
     is Custom; Test widget: Main value, Details, Device, the summary "Show <main value>"). Answer
     `W0-2-W-edit` and `W0-1-test-edit`.
   - **The Test widget.** He presses its Refresh button.
     - Take `test-widget-en` and answer `W0-6-format-en` from lines a and b.
     - `$S spike tick` takes two screenshots 65 s apart: answer `W0-6-tick`.
   - **Rendering modes (W0-4).** He first sets System Settings → Desktop & Dock → Dim widgets on
     desktop to Automatically. For each style, in the order Default, Dark, Clear, Tinted, run
     `$S mark desktop-<style>` first. He then picks the style in System Settings → Appearance →
     Icon & widget style and clicks an empty spot of the desktop, then a window.
     - Then he adds a small BatteryPulse widget to Notification Center (click the date in the
       menu bar, then Edit Widgets), and the same four styles follow with Notification Center open
       (`$S mark nc-<style>`).
     - Then he sets both settings back to what prepare recorded.
   - **Clicks.** `$S mark click-closed`, then he closes every BatteryPulse window and clicks a
     desktop widget. `$S mark click-open`, then he opens the main window and clicks the widget
     again.
   - **Russian.** `$S spike ru on` writes `AppleLanguages (ru)` into the widget extension's own
     preferences and restarts the extension.
     - macOS may ask whether the app that runs you may access other apps' data: he allows it.
     - Take `edit-battery-ru` after he opens Edit "Battery" again. Answer `W0-2-W-ru` and
       `W0-6-format-ru`: a widget that stays in English is `4`, which the results record as "not
       checked", never as a failure.
     - Then `$S spike ru off`.
   - **Logs.** `$S spike logs` sums up the spike's log lines between your marks (feed candidates
     with byte counts or errno, the accessory count, the rendering mode per style and place, the
     entity queries, the button, the clicks). Read `~/bp-062/A/logs/spike-w.txt` too. If a part
     has no lines at all (no `spike render`, no `spike click`), `note` it; it is a result, not an
     error.

### 4. VoiceOver and Text size on 0.6.1 (4 min)

- `$S voiceover` reinstalls 0.6.1 and takes `widgets-061-again`. Answer `W0-2-reinstall`.
  - If a widget is blank, he removes it and adds it again; say which in the note.
- **VoiceOver** needs his ears:
  - he presses Command-F5, clicks an empty spot of the desktop, and presses
    Control-Option-Right Arrow until VoiceOver reads a BatteryPulse widget;
  - he tells you what it says for the battery symbol, then presses Command-F5 again;
  - record it in English with the language VoiceOver spoke, or `not reached`, as `W0-5-voiceover`.
- **Text size.**
  - `$S shot text-size-before`.
  - He raises System Settings → Accessibility → Display → Text size.
  - `$S shot text-size-after`, and answer `W0-5-text-size` from the two pictures.
  - He sets Text size back.

### 5. V-01 on SPIKE-A2 (12 min)

- `$S v01 start` installs SPIKE-A2. Then, in this order:
  1. He sends a test notification (BatteryPulse Settings → Notifications → Send Test
     Notification) and clicks the banner; then again with the BatteryPulse window in front.
  2. `$S appearance light`, `$S shot menubar-light`, `$S appearance dark`,
     `$S shot menubar-dark`, `$S appearance back`. Judge the menu bar item in both shots.
  3. He opens Raw Data, History, turns Demo Mode on and off, presses Check Now (and closes any
     update offer without installing), and presses Clear History. His data is in the backup.
  4. He closes the lid for a minute, opens it and logs in.
- Run `$S v01 check`. It counts the "executor" log lines and the new crash reports and shows the
  first lines.
  - Ask him `V01-notification`, `V01-notification-front` and `V01-pages`.
  - Judge `V01-menubar`, and `V01-lid` from `$S shot after-lid` and the running state that `check`
    prints.
  - Any "executor" line or crash report is a finding: put the count and the first line in a
    `note`.

### 6. Clear's minimize fill (4 min)

For each case, in order `clear-light`, `clear-dark`, `translucent-dark`:

1. `$S fill ready <case>` sets the hidden SPIKE-A2 switch: fill (b) on Clear, today's fill on
   Translucent. It sets the style and the appearance and relaunches the app.
   - He opens the main window in the middle of the screen, away from the Dock.
2. `$S fill record <case>` plays a sound, records 6 s, plays another, records 6 s again, and
   dumps both clips to frames:
   - at the first sound, he holds Shift and clicks the yellow button (the slow minimize);
   - at the next sound, he holds Shift and clicks the window's icon in the Dock (the slow restore).
3. Look at each clip's `sheet.png` (the frames in order, rows of 10), then at the frames
   `frames.tsv` and the printed lines name: the most dark pixels, the largest change. Judge the
   question yourself:
   - `1`: while the window shrinks and comes back, its shape shows the window itself, or an even
     graphite grey. Fill (b) is about 19 % white, about RGB 50, 50, 50.
   - `2`: the shape is black or nearly black (a luma under about 0.08), or has a black border or
     band that the window itself doesn't have. Clear Dark's window is dark by design: compare the
     shape with the first frame, before the minimize starts.
   - `3`: anything else, described in the note.
   - Name the frames in the note.
   - A clip that missed the animation (no change, or only its start): run `fill record` again.
   - Attach one cropped frame per case as evidence: `$S crop <frame> <x> <y> <w> <h> <name>`, then
     `$S attach ~/bp-062/A/shots/<name>.png "<case>: <what it shows>"`.
4. If `translucent-dark` is `2`, also run `fill ready translucent-dark-b` and `fill record
   translucent-dark-b`. This case extends fill (b) to Translucent Dark; answer
   `fill-translucent-dark-b`.
5. `$S fill done`.

### 7. Attach timing (3 min, unattended)

`$S attach-timing` attaches the real 0.6.1 DMG 5 times each with `hdiutil` and with `diskutil image
attach`, with and without verification skipping, and saves diskutil's usage text. Nothing to
answer. If a variant failed every time, its error is in the section; `note` it.

### 8. Page switches (14 min)

1. `$S pages`. He opens the main window with the sidebar showing. For about 4 minutes the Mac
   speaks a page's name and shows it in a notification every 3 s, and he clicks that page.
   - The section lists the `page.switch` lines per page; a page with far fewer than 10 was
     missed: `note` it.
2. `$S pages profiling` installs 0.6.1 and then SPIKE-A2's profiling build, and does the same under
   `xctrace` with the SwiftUI template.
   - macOS may ask for an administrator's password for developer tools: he types it in that
     dialog, never in your conversation.
   - When it is done, export what you can read: `xcrun xctrace export --input
     ~/bp-062/A/traces/pages.trace --toc` lists the tables. Note the slowest view bodies or
     updates per page in a `note`, in milliseconds, with no paths. If the trace is empty or the
     template is missing, note that instead.

### 9. Start the unattended window (1 min)

1. Ask him, in Russian:
   - to set the energy setup: display brightness about half, auto-brightness and True Tone off,
     every other app quit except Terminal and the one that runs you, a Focus on;
   - to unplug the adapter and leave the lid open;
   - to open a new Terminal window and paste
     `bash ~/bp-062/repo/docs/plans/0.6.2/m5-session.sh window`.
2. `window` asks him once for the energy setup (1 or 2) and once for his password (`sudo`, for the
   Low Power Mode runs and for putting Low Power Mode back). It refuses to start on the adapter or
   under 50 %. If Terminal asks to control System Events and then BatteryPulse, he clicks OK; ask
   him to wait until Terminal prints `installed B` before he leaves, so no prompt waits for him.
3. Tell him the timetable, with the times of day:
   - 0:00-1:10, the A/B energy runs, with the display kept on except in two 10-minute runs;
   - 1:10-3:00, the field run on SPIKE-A2;
   - **at 2:00, a sound and an alert ask him to plug the adapter in** (1 minute);
   - at 3:00 the script runs restore and leaves the list of what to put back by hand on the
     screen. Nothing is sent yet: the results wait for his yes (below).
   - If he can't plug in at 2:00, the run records battery only; that is fine.
4. Then stay idle: no commands, no polling. Your own work would show up in the energy runs. Wait
   until he writes to you again.

## After the window

1. `$S status`: every answer recorded, the window done (or stopped early: then run `$S restore`
   yourself).
2. Read `~/bp-062/A/A.md`. Check:
   - no Russian, no device names, no paths outside `~`;
   - the energy table has a row per run;
   - the pslog section has lines for both phases.
3. **The repository is public, so he decides what leaves the Mac.** Tell him in Russian, in a
   few lines, what `send` will publish: the kinds of content (answers, counts, timings, energy
   numbers, log lines with private values shown as `<private>`), the attached images one by one
   (open each so he sees it), and that recordings, traces, raw captures, screenshots that aren't
   attached, and the backup stay in `~/bp-062/A`. Remove anything he doesn't want with
   `$S unattach <file>` or by not attaching it. Run `$S send` only after his yes. If you `attach`
   or `note` anything more later, show it to him and run `$S send` again; it adds a commit to the
   same branch.
4. Check that the file arrived:

   ```
   gh api "repos/NikitaUsov/BatteryPulse/contents/docs/plans/0.6.2/sessions/A.md?ref=claude/062-session-a" --jq .size
   ```
5. Go through restore's "PUT BACK" list with him, item by item, in Russian:
   - VoiceOver off;
   - Text size;
   - Icon & widget style and Dim widgets on desktop, to the values prepare recorded;
   - Appearance → Auto if it was Auto;
   - Open at login;
   - the widgets the session added;
   - a blank widget, removed and added again.
   - If the window printed a `PUT BACK (person, in Terminal): sudo pmset ...` line, he runs it
     himself.
6. Report to him, in Russian, in a few lines:
   - what was answered and what wasn't, and why;
   - anything that looked wrong: crash reports, "executor" lines, a widget that went blank, a
     black frame;
   - the link `send` printed.
   - Your backup and the recordings stay in `~/bp-062/A`; `~/bp-062/repo` is a worktree he can
     remove with `git -C ~/BatteryPulse worktree remove ~/bp-062/repo`.

## If the session stops early

- Always run `$S restore` before leaving: it reinstalls his app and puts back the settings, the
  data, Low Power Mode, the wallpaper and the appearance. Then go through its list with him.
- Then, after he has seen what it holds and said yes (as in "After the window", step 3), `$S send`.
  A partial A.md is worth sending, because the answers left blank show as "not answered".
- To go on later, run the next step: the answers so far stay in `~/bp-062/A/answers.tsv`. A second
  `prepare` keeps the first backup (`prepare --fresh-backup` would replace it with the session's
  state: never use it mid-session).
- A refused install ("isn't higher than the installed") means a step ran out of order: `$S install
  B` (0.6.1), then the step again.
