#!/bin/bash
# BatteryPulse 0.8: the M5 sessions (PLAN.md §6), one command per call.
# 0.7.0's, built on 0.6.2's Session B, re-pointed at 0.7.1 (0.7.1's W-16 and W-17) and moved here by
# 0.7.1's D3 for 0.8's M5 sessions, which T-1 re-points (PLAN.md §4 T-1). PLAN.md and a bare §
# below are docs/plans/0.8.0/PLAN.md, whose IDs (G8-n, Q8-n, A-n, T-1) are its own; P71 is 0.7.1's
# docs/plans/0.7.1/PLAN.md, readable at dbc696a979b0cad265ae554d1e6d69db1eac1572 in the 0.7.1
# release PR's head, whose IDs (W-5 to W-17, G71-n, PF-n, Q71-n) stay its own; plan-0.7.0, and 0.7's
# package, decision, gate and step IDs (W-3b, W-12, D-17, G7-n), are 0.7.0's
# docs/plans/0.7.0/PLAN.md, readable at ebe654772c7f06d5e136327e0e6a236fed71cdc9 in
# refs/pull/13/head.
#
#   bash docs/plans/0.8.0/m5-session.sh help
#
# Four sessions, each run by one local Claude Code session with computer use from its own frozen
# worktree, whose path names the session (the start line's one allow rule names it): it drives the
# GUI through `ui` (ui.swift, with safety rules of its own) and judges the pictures beside the
# script's pixel measurements. Each keeps its files in ~/bp-080/<session>, records each change in
# changes.tsv before it is made and puts it back from that file, and `send` commits <session>.md
# to docs/plans/0.8.0/sessions/ on claude/080-session-<session> after his yes, through a privacy
# lint. Each start line prints one runbook section (section.sh beside this file, PLAN.md §6.0):
#   L   the look shoot (PLAN.md §6.1; SESSION-L.md, "Look shoot"), ~/bp-080/L/run: a CI build of
#       the integration branch over his 0.7.1, the Charge Limit's check (G8-1), every new screen in
#       English and Russian, the optional weak adapter (Q8-3), then his 0.7.1 back;
#   R   Session R8 (PLAN.md §6.4-§6.5; SESSION-R.md, "R8"), ~/bp-080/R/run: the release candidate
#       over his 0.7.1, the GUI phase (C10's trees and keyboard, the audits, the checks 0.7.0 and
#       0.7.1 shipped without), the arm window that keeps the display awake for it and starts the
#       logged day on `ready`, and the day's end (`day-end`, F12, `restore end`);
#   H   the hold watch (SESSION-R.md, "Hold watch"), ~/bp-080/H/run: a night's recording on the
#       adapter (QUA-06, G8-2);
#   D3  the after-publishing check (PLAN.md §6.6; SESSION-R.md, "After publishing"), ~/bp-080/D3/run
#       at <keep>: Install and Relaunch to 0.8.0 from his restored 0.7.1.
#
# An automated step that can't run records "not checked" or "not run" with its reason, and the
# session goes on. Builds stay in their DMGs and the backup in its zip, so the only
# BatteryPulse.app on the disk is the one in /Applications, and macOS can't pick up another copy's
# widget. Never another results branch, never a pull request.
#
# Every install goes the way UpdateInstaller goes: the widget extension ended first (as the
# installer does since 0.6.2, D-17), a copy staged on the same volume, one atomic swap (swap.swift:
# renamex_np with RENAME_SWAP), lsregister -f, a relaunch; the extension's pids before and after,
# and any CHSErrorDomain 1103 line, go into the step's section (G7-2). A build whose CFBundleVersion
# isn't higher than the installed one is refused (WidgetKit caches by it), except v0.6.2 over a
# newer app (step 11c) and his backed-up app.
#
# Wording (PLAN.md §6.0): every y/n question means "y = looks right"; everything else is a
# numbered choice. A step prints its questions as ASK lines and its hands-on tasks as DO lines;
# `judge` and `answer` record the replies. The script reads the logs and counts the crash reports.
#
# It needs macOS 27, Xcode or the Command Line Tools, and the GitHub CLI (https://cli.github.com),
# signed in (the hold watch needs neither gh nor a build from CI). No python or perl; it runs on
# macOS's bash 3.2. Millisecond times come from zsh's zsh/datetime module.
set -euo pipefail

# MARK: - Builds and places

REPO="NikitaUsov/BatteryPulse"
INTEGRATION_BRANCH="claude/080-integration"

# Session R's builds (PLAN.md §6.4, D1), each a CI artifact. D1 dispatches ci.yml on the frozen
# code in this order, each with the build-number clock (0.7.1's B-1, scripts/build-number.sh), so
# each build number is higher than the one installed before it:
#   U   the release candidate as 0.7.99 (RC-U): step 2 installs it over his 0.7.1, and the rest of
#       the session and the logged day run on it;
#   F   the release candidate as 0.5.99 (RC-F): F12 at the day's end, whose update check offers the
#       published 0.7.1.
# Both are found by the frozen commit's code (locate_builds). A pin (RUN_<name> and
# ARTIFACT_<name>) overrides the search.
RUN_U=""
ARTIFACT_U=""
RUN_F=""
ARTIFACT_F=""
# The look shoot's build (PLAN.md §6.1), L: the newest CI build of the frozen code on the
# integration branch, a push's (version 0.0.0) or a dispatch's, its build number the clock's, above
# v0.7.1's (locate_build_l). A pin overrides the search.
RUN_L=""
ARTIFACT_L=""
# The published builds, each from its release: v0.6.2, the start, whose static Battery widget is
# placed under it and then updated to a configurable one; v0.7.1, the base, his own 0.7.x, which F12
# comes back to.
TAG_START="v0.6.2"
START_VERSION="0.6.2"
TAG_BASE="v0.7.1"
BASE_VERSION="0.7.1"
RC_VERSION="0.7.99"
F_VERSION="0.5.99"
# The release the after-publishing check installs by Install and Relaunch (PLAN.md §6.6).
RELEASE_VERSION="0.8.0"

BUNDLE_ID="io.github.nikitausov.BatteryPulse"
WIDGET_ID="$BUNDLE_ID.Widget"
APP="/Applications/BatteryPulse.app"

HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$HERE/../../.." && pwd)"
# The account's own home. On the Mac it comes from the user database, and HOME must be it: a run
# with another HOME would find no fence and record its changes in a folder no restore reads.
ACCOUNT_HOME="$HOME"
if [ "$(uname -s)" = Darwin ]; then
  ACCOUNT_HOME="$(dscl . -read "/Users/$(id -un)" NFSHomeDirectory 2>/dev/null |
    awk 'NR == 1 { sub(/^NFSHomeDirectory:[ ]*/, ""); if ($0 != "") { print; exit } next } { sub(/^ +/, ""); print; exit }' ||
    true)"
  if [ -z "$ACCOUNT_HOME" ] || [ "$HOME" != "$ACCOUNT_HOME" ]; then
    echo "error: HOME ($HOME) isn't the account's home folder (${ACCOUNT_HOME:-unreadable}, dscl): nothing was done" >&2
    exit 1
  fi
fi
case "$HERE" in
  "$HOME"/*) SCRIPT="bash ~${HERE#"$HOME"}/m5-session.sh" ;;
  *) SCRIPT="bash $HERE/m5-session.sh" ;;
esac
# The session, by the frozen worktree the script runs from (the start line's one allow rule names
# it); none elsewhere, where only help and the dry run work. BP_SESSION chooses one only off the
# Mac (a dry run): on the Mac the path alone decides, so no variable turns a fence off.
case "$HERE" in
  "$ACCOUNT_HOME"/bp-080/R/run/*) SESSION=R ;;
  "$ACCOUNT_HOME"/bp-080/L/run/*) SESSION=L ;;
  "$ACCOUNT_HOME"/bp-080/H/run/*) SESSION=H ;;
  "$ACCOUNT_HOME"/bp-080/D3/run/*) SESSION=D3 ;;
  *) SESSION=none ;;
esac
if [ "$(uname -s)" != Darwin ]; then SESSION="${BP_SESSION:-$SESSION}"; fi
# Session R's folder, whatever this run's own folder is: its fence (ready before day-end) holds for
# every session's script.
R_HOME="$ACCOUNT_HOME/bp-080/R"
# dry-run (CI on Linux) is Session R's bookkeeping in a folder of its own. On the Mac nothing else
# moves the folder: a BP_WORK of the caller's would hold no fence and no change record.
if [ "${1:-}" = dry-run ]; then
  SESSION=R
  BP_WORK="$(mktemp -d "${TMPDIR:-/tmp}/bp-080-dry.XXXXXX")"
elif [ "$(uname -s)" = Darwin ]; then
  BP_WORK=""
fi
case "$SESSION" in
  R | L | H | D3) RESULTS_BRANCH="claude/080-session-$(tr '[:upper:]' '[:lower:]' <<<"$SESSION")" ;;
  none) RESULTS_BRANCH="" ;;
  *)
    echo "error: BP_SESSION is R, L, H or D3" >&2
    exit 1
    ;;
esac
TAB="$(printf '\t')"
# BP_WORK only moves the folder for the dry run and for the bookkeeping commands off the Mac.
WORK="${BP_WORK:-$ACCOUNT_HOME/bp-080/$SESSION}"
BACKUP="$WORK/backup"
BUILDS="$WORK/builds"
BIN="$WORK/bin"
SHOTS="$WORK/shots"
LOGS="$WORK/logs"
SECTIONS="$WORK/sections"
PUBLISH="$WORK/publish"
ANSWERS="$WORK/answers.tsv"
NOTES="$WORK/notes.tsv"
MARKS="$WORK/marks.tsv"
SUPPORT="$HOME/Library/Application Support/$BUNDLE_ID"
# The widget's feed (W-5's WidgetFeedStore): feed.json in Widget/, the folder the widget's one
# read-only exception names (WidgetFeedStore.homeRelativePath), 0700 with a 0600 file.
FEED_DIR="$SUPPORT/Widget"
FEED_FILE="$FEED_DIR/feed.json"
FEED_ENTITLED_PATH="/Library/Application Support/$BUNDLE_ID/Widget/"
FEED_EXCEPTION_KEY="com.apple.security.temporary-exception.files.home-relative-path.read-only"
WIDGET_APPEX="$APP/Contents/PlugIns/BatteryPulseWidget.appex"
WIDGET_PREFS="$HOME/Library/Containers/$WIDGET_ID/Data/Library/Preferences/$WIDGET_ID"
REPORTS="$HOME/Library/Logs/DiagnosticReports"
LSREGISTER="/System/Library/Frameworks/CoreServices.framework/Versions/A/Frameworks/LaunchServices.framework/Versions/A/Support/lsregister"
PERF_PREDICATE="subsystem == \"$BUNDLE_ID\" AND category == \"perf\""
WIDGET_PREDICATE="subsystem == \"$BUNDLE_ID\" AND category == \"widget\""
UPDATE_PREDICATE="subsystem == \"$BUNDLE_ID\" AND category == \"update\""
FAULT_PREDICATE="subsystem == \"$BUNDLE_ID\" AND messageType == fault"
# chronod's refusal of a timeline whose descriptor it cached from another build (Session A, D-17).
CHS_PREDICATE='eventMessage CONTAINS "CHSErrorDomain" AND eventMessage CONTAINS "1103"'
# The widgets the session may record (`widget`): the Battery kind's families by their own names,
# the other kinds' as <kind>-<family>, each family with its largest frame in points (ui.swift's
# Rules.widgetLimits, which reads a name's last part). No kind declares extra large in 0.7.x.
WIDGET_NAMES="small medium large accessories-small accessories-medium accessories-large history-medium history-large devices-small devices-medium devices-large"

# MARK: - Small helpers

fail() {
  echo "error: $*" >&2
  exit 1
}

warn() { echo "warning: $*" >&2; }

# public: the text with the home folder and user names taken out of paths, for the report.
public() { sed -e "s|$HOME|~|g" -e 's|/Users/[^/ "]*|/Users/~|g'; }

CYRILLIC="$(printf '[\320\321\322\323]')"
has_cyrillic() { printf '%s' "$1" | LC_ALL=C grep -q "$CYRILLIC"; }

# The repository is English only (LocalizationCatalogTests scans docs/), so a report takes no Russian.
english_only() {
  if has_cyrillic "$1"; then
    fail "translate this into English first: the results file is committed, and the repository is English only"
  fi
}

now_ms() {
  zsh -fc 'zmodload zsh/datetime && print -r -- $(( epochtime[1] * 1000 + epochtime[2] / 1000000 ))' 2>/dev/null ||
    echo $(($(date +%s) * 1000))
}

clock() { date '+%Y-%m-%d %H:%M:%S'; }

# stamp_ms <timestamp>: a timestamp in log's format (2026-10-20 19:35:07.736961+0300) in
# milliseconds since 1970.
stamp_ms() {
  local day_time rest fraction zone seconds offset
  day_time="${1%.*}"
  rest="${1##*.}"
  fraction="${rest%[+-]*}"
  zone="${rest#"$fraction"}"
  seconds="$(date -j -u -f '%Y-%m-%d %H:%M:%S' "$day_time" +%s)"
  offset=$((10#${zone:1:2} * 3600 + 10#${zone:3:2} * 60))
  if [ "${zone:0:1}" = "-" ]; then offset=$((-offset)); fi
  echo $(((seconds - offset) * 1000 + 10#${fraction:0:3}))
}

sleep_until() {
  local now
  now="$(date +%s)"
  if [ "$1" -gt "$now" ]; then sleep $(($1 - now)); fi
}

median() { sort -n | awk '{ v[NR] = $1 } END { if (NR == 0) print "-"; else if (NR % 2) print v[(NR + 1) / 2]; else print (v[NR / 2] + v[NR / 2 + 1]) / 2 }'; }

# MARK: - Sections of the report

# Each step writes its own section file, which a rerun replaces; send puts them together in order.
SECTION=""
begin_section() {
  mkdir -p "$SECTIONS"
  SECTION="$SECTIONS/$1.md"
  printf '## %s\n\n' "$2" >"$SECTION"
}

use_section() {
  mkdir -p "$SECTIONS"
  SECTION="$SECTIONS/$1.md"
  [ -f "$SECTION" ] || printf '## %s\n\n' "$2" >"$SECTION"
}

# out <line>: a line of the current section, also shown.
out() {
  printf '%s\n' "$*" | public | tee -a "$SECTION"
}

# out_block <file>: a file as a code block in the current section (shown too).
out_block() {
  {
    echo '```'
    public <"$1"
    echo '```'
  } | tee -a "$SECTION"
}


# MARK: - Questions

# question <id>: "<kind>|<who>|<text>". kind: yn (y = looks right), 2-5 (numbered choices) or text;
# who: person (only he can say) or judge (the session judges from the evidence the step names,
# beside the script's measurement where one exists, and his batch takes what it can't tell). Each
# judged one has its written criteria and default in its runbook's Answers.
question() {
  local rest
  case "$1" in
    R-yes) echo "yn|person|The list of changes and the start (SESSION-R.md, the start message): y = go ahead" ;;
    R-back) echo "text|person|When he is back at the Mac, HH:MM (default: 4 hours after the start); a daytime session works" ;;
    R-keep-ax) echo "yn|person|Keep Terminal's Accessibility after Session R8: y = keep (default: reminded to revoke it at the end of the series)" ;;
    R-keep-widgets) echo "yn|person|Keep the widgets the session adds from the gallery: y = keep (default: removed at the end, and the app's counts must be back at prepare's)" ;;
    R-limit) echo "yn|person|Step 9, the Charge Limit live: set to the hold and put back, only if G8-1 passed: y = go ahead (default: step 9 not run)" ;;
    R-usage | L-usage | H-usage | D3-usage) echo "text|person|What /usage showed at the start" ;;
    R-send | L-send | H-send | D3-send)
      echo "yn|person|Send ${1%-send}.md and the attached images to claude/080-session-$(tr '[:upper:]' '[:lower:]' <<<"${1%-send}"), after the contact sheet and the summary: y = send"
      ;;
    L-yes) echo "yn|person|The look shoot's list of changes (SESSION-L.md, the start message): y = go ahead" ;;
    L-adapter) echo "yn|person|Q8-3: a low-wattage USB-C adapter at hand for step 4, about 2 minutes, two more beeps: y = yes (default: step 4 skipped)" ;;
    H-yes) echo "yn|person|The hold watch tonight: the recording under caffeinate -i, the Mac on the adapter with the lid open: y = go ahead" ;;
    D3-yes) echo "yn|person|The after-publishing check: the update to $RELEASE_VERSION by Install and Relaunch: y = go ahead" ;;
    prep-charge-limit) echo "text|judge|The Charge Limit (pmset -g battlimit on the adapter, else the Battery pane's shot), in %" ;;
    prep-widget-style) echo "text|judge|System Settings → Appearance → Icon & widget style (computer use from the sidebar, its shot): Default, Dark, Clear or Tinted" ;;
    prep-dim-widgets) echo "text|judge|System Settings → Desktop & Dock → Dim widgets on desktop (its shot): Automatically, Always or Never" ;;
    prep-open-at-login) echo "2|judge|Open at login (BatteryPulse's own toggle, by AX or its Settings shot): 1 on, 2 off" ;;
    prep-keyboard-navigation) echo "text|judge|System Settings → Keyboard → Keyboard navigation at prepare: on or off (AppleKeyboardUIMode, else the pane's shot)" ;;
    prep-widgets) echo "2|judge|A BatteryPulse widget on the desktop for proof P1: 1 yes, 2 no (P1 then runs on the first widget the session adds)" ;;
    R-capacity-start | R-capacity-day-end | D3-capacity)
      case "$1" in R-capacity-start) rest="at the GUI phase's start" ;; R-capacity-day-end) rest="at the day's end" ;; *) rest="after publishing" ;; esac
      echo "text|judge|Maximum capacity $rest: System Settings → Battery → Battery Health's figure (computer use, the pane's shot), in % (P71's W-17 item 18; the script's capacity line stands beside it)"
      ;;
    R-feed-before) echo "yn|judge|The feed under his $BASE_VERSION, before RC-U: $BASE_VERSION's Widget/feed.json, 0600 in a 0700 folder, version 1, no udid, serial or demo key (the script reads it)" ;;
    R2-small | R2-medium | R2-large)
      echo "4|judge|Step 2, the ${1#R2-} widget placed under his $BASE_VERSION, after RC-U's install, its redraw and the desktop click, against its -before.png: 1 the same layout and choices with fresh values, 2 blank or grey, 3 gone, 4 different (note)"
      ;;
    R2-whats-new-rc) echo "yn|judge|What's New after RC-U's install over $BASE_VERSION, at 520 points, in English and in Russian: 0.8's rows without the version count's row, every row and its text readable, nothing cut" ;;
    R2-062-small | R2-062-medium)
      echo "4|judge|Step 11c, the ${1#R2-062-} widget placed from $START_VERSION's gallery, after RC-U's install, its redraw and the desktop click, against its -before.png: 1 the same layout with fresh values, 2 blank or grey, 3 gone, 4 different (note)"
      ;;
    R2-whats-new-062) echo "yn|judge|What's New after RC-U's install over $START_VERSION, at 520 points, in English and in Russian: 0.8's rows and the version count's row, every row readable, nothing cut" ;;
    R-tree-app | R-tree-app-ru)
      if [ "$1" = R-tree-app ]; then rest="in English"; else rest="in Russian"; fi
      echo "yn|judge|Step 3 (C10), BatteryPulse's trees $rest (every page, the compact window, the popover, each Settings pane, About, What's New, Software Update, Welcome, Report a Problem): every control a role and a label, only decorative images without one, the power flow, the capacity bars and each ring one element with a value (n names the surface and the element)"
      ;;
    R-charts) echo "3|judge|Step 3 (X-1), each chart's label and its descriptor: 1 read (by AX or Accessibility Inspector's shot), 2 a chart without one (which), 3 not readable by either (not checked)" ;;
    R-keyboard) echo "yn|judge|Step 4 (C10), the keyboard with Keyboard navigation on: the sidebar, the toolbar, the tile pickers, Raw Data's table and filter, the update window and Report a Problem's Save each reached and focused (n names the control)" ;;
    R-contrast) echo "3|judge|Step 5 (A11Y-03), Accessibility Inspector's audit on each page in Standard and Frosted, Light and Dark, and with Increase Contrast: 1 no failure, 2 failures (listed in the note), 3 not run" ;;
    R-display) echo "yn|judge|Step 6 (A11Y-02), each display option on and off (the Liquid Glass slider at both ends, Reduce Motion, Prefer Cross-Fade Transitions, Reduce Transparency, Increase Contrast, Show Borders): the main and compact windows and the popover readable and whole in every shot (n names the shot)" ;;
    R-menubar-a11y) echo "yn|judge|Step 7 (A11Y-04), the menu bar item with Increase Contrast and with Reduce Transparency, on a light and a dark bar: legible, not clipped" ;;
    R-russian) echo "yn|judge|Step 8, every page and window in Russian, against the Russian review's answers: every word Russian but names and units, nothing cut (n names the page)" ;;
    R-limit-live) echo "3|judge|Step 9, the Charge Limit live at the hold: 1 Overview's sentence and Power's number equal pmset -g battlimit's, 2 they differ (how), 3 not run (G8-1 failed, his no, or no hold)" ;;
    R-report) echo "yn|judge|Step 10 (A-6), Report a Problem on the RC: both choices saved, no serial, user name or home path in either file, and the crash reports' names as ls lists them (the script reads them)" ;;
    R-sentinel) echo "yn|judge|Step 11 (P-1), the accessory sentinel: the note and Turn On Again on Accessories, then the file gone and the page reading again (the script reads the file)" ;;
    R-listen) echo "yn|person|Q8-6, the optional VoiceOver listen at the day's end (five minutes on Overview, Power and Health, in Russian): y = the names make sense (default: skipped)" ;;
    R3-large | R3-accessories-small | R3-accessories-medium | R3-accessories-large | R3-history-medium | R3-history-large | \
      R3-devices-small | R3-devices-medium | R3-devices-large)
      echo "yn|judge|Step 11c, the ${1#R3-} widget added from the gallery, against the CI render of its kind and family: looks right (n names the picture)"
      ;;
    R-feed-history) echo "yn|judge|The feed within 15 minutes of the first History widget: 0600 in a 0700 folder, version 1, at most 32 KB, written within 15 minutes, no udid, serial or demo key; the widget's entitlements the sandbox and one read-only path, Widget/; no sandbox denial; the widget read it (the script reads it)" ;;
    R-feed-cold) echo "yn|judge|A feed written while no widget process ran, then read by the extension the reload started, without a rejection or an open failure (the script reads the stream's order)" ;;
    R-feed-demo) echo "yn|judge|The feed across Demo Mode (step 9b): its modification time and writtenAt unchanged (the script reads them)" ;;
    R-feed-reads) echo "yn|judge|Read iPhone and iPad batteries turned on, then off: the feed rewritten within a minute each time, readsDevices following (the script reads them)" ;;
    R-feed-cleared) echo "yn|judge|Clear History on the session's own data: the feed rewritten within a minute, with an empty day (the script reads it)" ;;
    D3-feed) echo "yn|judge|After the update: Widget/feed.json 0600 in a 0700 folder, version 1, written within 15 minutes; the widget's entitlements the sandbox and one read-only path, Widget/ (the script reads them)" ;;
    R4-1-chooser) echo "3|judge|Step 11c (4.1), Details' chooser (W0-1 (b)): 1 it lists the fields, Average drain and Time on battery among them, 2 some are missing (which), 3 it is empty or doesn't open" ;;
    R4-1-shows) echo "yn|judge|Step 11c (4.1): the medium widget shows the choices made (Custom, the first three details and Average drain, time left if offered, monochrome)" ;;
    R4-2-kept) echo "yn|judge|Step 11c (4.2): Edit Widget again shows the choices made" ;;
    R4-3-sheet) echo "3|judge|Step 11c (4.3), Edit Widget with BatteryPulse in Russian: 1 all Russian, 2 some English (which), 3 the sheet didn't change language (not checked)" ;;
    R4-3-widgets) echo "3|judge|Step 11c (4.3), the placed widgets after the language switch, the reload and a new extension: 1 Russian, 2 still English (which), 3 no redraw (not checked)" ;;
    R4-5-automatic) echo "yn|judge|Step 11c (4.5): the medium widget back on Automatic, as before step 4" ;;
    R4-6-history) echo "yn|judge|Step 11c (4.6), the History widget's edit sheet: its options listed (the series, the period), and a choice shows on the widget after Done" ;;
    R4-6-device) echo "3|judge|Step 11c (4.6), the iPhone & iPad widget's edit sheet, One device (G71-4): 1 its chooser opens (empty while no device is remembered), 2 it doesn't open or shows an error, 3 no One device option" ;;
    R5-always-default | R5-always-dark | R5-always-clear | R5-always-tinted | R5-auto-default | R5-auto-dark | R5-auto-clear | R5-auto-tinted | \
      R5-nc-default | R5-nc-dark | R5-nc-clear | R5-nc-tinted | R5-contrast | R5-transparency)
      rest="${1#R5-}"
      echo "yn|judge|Step 11c, the looks, $rest: every widget can be read, and a low or Service Recommended state still shows without colour (beside each crop's contrast)"
      ;;
    R6-12-hour) echo "yn|judge|Step 11c, 24-hour time off: the widget shows '4:39 PM'-style times" ;;
    R6-tick) echo "4|judge|Step 11c, a time-left widget 65 s apart: 1 the minutes went down by one, 2 no, 3 it shows seconds, 4 it starts with a minus sign" ;;
    R6-count-toggle) echo "yn|judge|Step 11c, the version count's toggle and footer: readable in English and Russian, greyed out under Never" ;;
    R7-tree) echo "yn|judge|Step 3 (C10), each placed widget's tree, every kind and family: no symbol name, the charge one element with its value, one element per row, no empty group, a chart one element with its one label (W-3b item 5, WidgetChartSummary)" ;;
    R7-tree-ru) echo "yn|judge|Step 3 (C10), the same widget trees in Russian, after a redraw" ;;
    R7-text-size) echo "3|judge|Step 11c, Text size at its largest: the widgets' words 1 grow, 2 stay unchanged (expected), 3 get cut off (which)" ;;
    R8-quit | R8-running | R8-accessories | R8-health | R8-main | R8-compact | R8-history | R8-device)
      echo "3|judge|A click on the widget (${1#R8-}): 1 the expected page opened, 2 another page (which, and its route), 3 nothing opened"
      ;;
    R9-plug) echo "yn|judge|The day's end, the unplug and plug-in: the Battery widget's state matches bpulse --json within a minute (at the limit: Not charging, then Charged to limit)" ;;
    R9-accessory) echo "3|judge|An accessory disconnected and reconnected: 1 the Accessories widget changed within a minute, 2 it didn't, 3 not run" ;;
    R9b-demo) echo "yn|judge|Step 11c, Demo Mode's Charge limit scene: Overview, the popover and the compact window say Charged to limit, Power says Charge limit: Reached (or its number)" ;;
    R9b-demo-ru) echo "yn|judge|Step 11c, the same scene in Russian (after app-language ru), in the catalog's terms" ;;
    R9b-widgets) echo "yn|judge|Step 11c, with bit 24 now: the Battery widgets say Charged to limit" ;;
    R9b-settings-ru) echo "3|judge|Step 11c, System Settings → Battery's Charge Limit with System Settings in Russian: 1 Russian, as the catalog's words, 2 Russian, other words (which), 3 not in Russian (not checked)" ;;
    R-settings) echo "yn|judge|Settings on the Air's display (S-1): every Settings pane and the Welcome window, scrolled to its end: the last row's control reachable; a pane that fits shows no scroll bar and doesn't move (n names the pane)" ;;
    V01-menubar) echo "yn|judge|The menu bar item on a light and on a dark menu bar (the crops): legible, not clipped" ;;
    R-menu-bar-same) echo "2|judge|menu-bar-shots before ($START_VERSION's painter) against after (RC-U's), each look and style: 1 BatteryPulse's item drawn the same (the clock, the system's items and a charge that moved between them aside), 2 it differs (which)" ;;
    R-raw-history-rc)
      echo "3|judge|A pointer-free switch from Raw Data to History (rc): 1 History at once, 2 History's title over Raw Data's table first (for how long), 3 something else (note)"
      ;;
    F12-version) echo "yn|judge|F12: after Install and Relaunch on RC-F, BatteryPulse came back as the published $BASE_VERSION" ;;
    F12-widget) echo "4|judge|F12: the Battery and Accessories widgets after the update and its redraw, against the before shots: 1 same, 2 blank or grey, 3 gone, 4 different (note)" ;;
    F12-new-kinds) echo "4|judge|F12: the History and iPhone & iPad widgets under the published $BASE_VERSION, which has their kinds: 1 same, with fresh values, 2 blank or grey, 3 gone, 4 different (note)" ;;
    G8-1-hold) echo "yn|judge|G8-1 at the hold (the limit at or just below the charge, on the adapter): the app's logged number equals pmset -g battlimit's, and bpulse --json's key with it (the script reads them)" ;;
    G8-1-second) echo "yn|judge|G8-1 at a second limit above the charge (charging toward it): the app's logged number equals battlimit's, or both show none (the script reads them)" ;;
    G8-1-full) echo "yn|judge|G8-1 at 100 %: battlimit shows no limit, and neither the app's line nor bpulse --json gives a number (the script reads them)" ;;
    G8-1-battery) echo "yn|judge|G8-1 on battery, 1 and 6 minutes after the unplug: no number from the app or bpulse --json; by 6 minutes powerd holds no policy (the script reads them)" ;;
    G8-1-plugin) echo "yn|judge|G8-1 after the plug-in, at 5 s and at 1 minute: battlimit holds the limit again, and the app's number with it (the script reads them)" ;;
    G8-5-limit) echo "yn|judge|G8-5: no prompt while BatteryPulse read powerd's file (the screen at each read: no dialog came)" ;;
    L-samples) echo "3|judge|A-2's sample script at each read on the adapter: 1 every redacted copy decodes to battlimit's number, 2 a copy failed or decoded another number (which), 3 no sample script at the frozen commit (not run)" ;;
    L-limit-back) echo "yn|judge|The Charge Limit back at prepare's value (pmset -g battlimit on the adapter, or the Battery pane's shot)" ;;
    L-a1-scenes) echo "yn|judge|Step 3 (A-1): each Demo Mode scene that names a cause, and the one whose info button lists Apple's reasons, shot on Overview, Power and the popover, in English and Russian (n names the scene)" ;;
    L-a2-number) echo "3|judge|Step 3 (A-2): the Charge Limit's number in its Demo Mode scene: 1 Power and Overview's sentence show it, 2 not shown (which), 3 no such scene in this build" ;;
    L-a3-health) echo "yn|judge|Step 3 (A-3): Health's summary at the top (Condition, Maximum capacity, Cycle count), in English and Russian" ;;
    L-q84-badge) echo "3|judge|Step 3 (Q8-4): Clear's badge in the worn-battery scene, beta styles on and Clear chosen: 1 the capacity's own words (Maximum capacity below 80 percent), 2 Service Recommended, 3 not shot (why)" ;;
    L-a4-help) echo "yn|judge|Step 3 (A-4): one row's help tag and its info popover per page (Overview, Power, Health, a device page when one is remembered) and the popover's help tag, in English and Russian (n names the page)" ;;
    L-a5-welcome) echo "yn|judge|Step 3 (A-5): Welcome with hasSeenWelcome cleared, its lines and controls, in English and Russian; hasSeenWelcome back as it was (the script reads it)" ;;
    L-a6-window) echo "yn|judge|Step 3 (A-6): Report a Problem's window, its preview's top and its end, and both choices, in English and Russian" ;;
    L-a6-file) echo "yn|judge|Step 3 (A-6, G8-13): every report saved into the session's report folder holds no serial of this Mac or its battery, no user name and no home path (the script reads them)" ;;
    L-p1-note) echo "yn|judge|Step 3 (P-1): after the accessory sentinel, Accessories shows the note with Turn On Again; an AX press on it, and the file is gone (the script reads it)" ;;
    L-a7-link) echo "3|judge|Step 3 (A-7): the user guide's link (About's User Guide, else the log line): 1 this build's ref (main for 0.0.0, v<version> otherwise), 2 another ref (which), 3 not read (not checked)" ;;
    L-weak-adapter) echo "3|judge|Step 4 (Q8-3, G8-3): the captures with the low-wattage adapter under load: 1 a charger key shows it (which), 2 none does, 3 not run" ;;
    H-hold) echo "3|judge|The night on the adapter: 1 a hold was seen (the charge held below 100 % with NotChargingReason set), 2 none, 3 not readable" ;;
    D3-version) echo "yn|judge|After Install and Relaunch, About shows $RELEASE_VERSION" ;;
    D3-whats-new) echo "yn|judge|What's New appeared once, with 0.8's rows" ;;
    D3-count-row) echo "yn|judge|What's New lists Anonymous version count only for an update from before 0.7 (from $BASE_VERSION: not listed)" ;;
    D3-widgets) echo "4|judge|The widgets against the before-picture, after their redraw and the desktop click: 1 same, 2 blank or grey, 3 gone, 4 different" ;;
    D3-history) echo "yn|judge|History shows the past days" ;;
    D3-settings) echo "yn|judge|The settings and the menu bar look are as in the before shots" ;;
    D3-login-item) echo "2|judge|Login Items: 1 BatteryPulse still listed (or Open at login was off), 2 gone" ;;
    D3-notifications) echo "yn|judge|BatteryPulse's Settings → Notifications as before the update" ;;
    D3-prompt) echo "yn|judge|No prompt for BatteryPulse's own data after the update (SEC-06)" ;;
    D3-report) echo "yn|judge|Help → Report a Problem… opens its window (a shot)" ;;
    D3-help) echo "3|judge|The user guide's link at $RELEASE_VERSION (About's User Guide, else the log line): 1 v$RELEASE_VERSION, 2 another ref (which), 3 not read" ;;
    D3-first-day) echo "yn|judge|The popover's charge and Lasts until against the widget's: within 2 points and about 15 minutes" ;;
    *) return 1 ;;
  esac
}

# The order of the answers in status and the report, per session.
questions_list() {
  case "$SESSION" in
    R)
      echo R-yes R-back R-keep-ax R-keep-widgets R-limit R-usage
      echo prep-charge-limit prep-widget-style prep-dim-widgets prep-open-at-login prep-keyboard-navigation prep-widgets R-capacity-start
      echo R-feed-before R2-small R2-medium R2-large R2-whats-new-rc
      echo R-tree-app R-tree-app-ru R-charts R7-tree R7-tree-ru R-keyboard R-contrast R-display R-menubar-a11y V01-menubar
      echo R-russian R-limit-live R-report R-sentinel
      echo R2-062-small R2-062-medium R2-whats-new-062
      echo R3-large R3-accessories-small R3-accessories-medium R3-accessories-large R3-history-medium R3-history-large
      echo R3-devices-small R3-devices-medium R3-devices-large R-feed-history R-feed-cold
      echo R4-1-chooser R4-1-shows R4-2-kept R4-3-sheet R4-3-widgets R4-5-automatic R4-6-history R4-6-device
      echo R5-always-default R5-always-dark R5-always-clear R5-always-tinted R5-auto-default R5-auto-dark R5-auto-clear R5-auto-tinted
      echo R5-nc-default R5-nc-dark R5-nc-clear R5-nc-tinted R5-contrast R5-transparency
      echo R6-12-hour R6-tick R6-count-toggle R7-text-size
      echo R8-quit R8-running R8-accessories R8-health R8-main R8-compact R8-history R8-device R9-accessory
      echo R9b-demo R9b-demo-ru R9b-widgets R9b-settings-ru R-feed-demo R-feed-reads R-feed-cleared R-settings
      echo R-menu-bar-same R-raw-history-rc
      echo R9-plug R-capacity-day-end F12-version F12-widget F12-new-kinds R-listen R-send
      ;;
    L)
      echo L-yes L-usage L-adapter prep-charge-limit
      echo G8-1-hold G8-1-second G8-1-full G8-1-battery G8-1-plugin G8-5-limit L-samples L-limit-back
      echo L-a1-scenes L-a2-number L-a3-health L-q84-badge L-a4-help L-a5-welcome L-a6-window L-a6-file L-p1-note L-a7-link
      echo L-weak-adapter L-send
      ;;
    H) echo H-yes H-usage H-hold H-send ;;
    D3)
      echo D3-yes D3-usage D3-version D3-whats-new D3-count-row D3-widgets D3-history D3-settings D3-login-item D3-notifications
      echo D3-feed D3-capacity D3-prompt D3-report D3-help D3-first-day D3-send
      ;;
  esac
}

kind_hint() {
  case "$1" in
    yn) echo "y/n, y = looks right" ;;
    text) echo "text" ;;
    *) echo "1-$1" ;;
  esac
}

# ask <id>...: the questions as ASK lines, for the session to judge or to put to him.
ask() {
  local id spec kind rest who
  for id in "$@"; do
    spec="$(question "$id")" || fail "no question $id"
    kind="${spec%%|*}"
    rest="${spec#*|}"
    who="${rest%%|*}"
    printf 'ASK %s [%s; %s]: %s\n' "$id" "$who" "$(kind_hint "$kind")" "${rest#*|}"
  done
}

answer_of() {
  [ -f "$ANSWERS" ] || return 0
  awk -F '\t' -v id="$1" '$1 == id { value = $2 } END { if (value != "") print value }' "$ANSWERS"
}

# answer [--by claude|person] <id> <value> [note...]
step_answer() {
  local by="" id value note spec kind rest who
  if [ "${1:-}" = --by ]; then
    by="${2:-}"
    shift 2 || true
    case "$by" in claude | person) ;; *) fail "--by takes claude or person" ;; esac
  fi
  [ $# -ge 2 ] || fail "usage: $SCRIPT answer [--by claude|person] <id> <value> [note...]"
  id="$1"
  value="$2"
  shift 2
  note="$*"
  spec="$(question "$id")" || fail "no question $id; see $SCRIPT status"
  kind="${spec%%|*}"
  rest="${spec#*|}"
  who="${rest%%|*}"
  # judge records "unsure" for his batch where 3 isn't "something else".
  if [ "$value" = unsure ] && [ "$by" = claude ]; then kind=text; fi
  if [ "$id" = "$SESSION-send" ] && [ "$value" = y ]; then
    publish_sheet_fresh || fail "first the contact sheet of every attached image ($SCRIPT send --dry-run), shown to him, then his yes"
  fi
  case "$kind" in
    yn) case "$value" in y | n) ;; *) fail "$id takes y or n (y = looks right)" ;; esac ;;
    text) [ -n "$value" ] || fail "$id takes a text" ;;
    *)
      case "$value" in
        [1-9]) [ "$value" -le "$kind" ] || fail "$id takes 1-$kind" ;;
        *) fail "$id takes a number, 1-$kind" ;;
      esac
      ;;
  esac
  english_only "$value $note"
  if [ -z "$by" ]; then
    if [ "$who" = judge ]; then by=claude; else by=person; fi
  fi
  mkdir -p "$WORK"
  touch "$ANSWERS"
  awk -F '\t' -v id="$id" '$1 != id' "$ANSWERS" >"$ANSWERS.tmp"
  mv "$ANSWERS.tmp" "$ANSWERS"
  printf '%s\t%s\t%s\t%s\t%s\n' "$id" "$(printf '%s' "$value" | tr '\t\n|' '  /')" "$by" "$(date '+%H:%M')" \
    "$(printf '%s' "$note" | tr '\t\n|' '  /')" >>"$ANSWERS"
  if [ "$id" = "$SESSION-send" ]; then touch "$WORK/send-yes"; fi
  echo "recorded $id = $value ($by)"
}

step_note() {
  [ $# -ge 1 ] || fail "usage: $SCRIPT note <text>"
  english_only "$*"
  mkdir -p "$WORK"
  printf '%s\t%s\n' "$(date '+%H:%M')" "$(printf '%s' "$*" | tr '\t\n|' '  /')" >>"$NOTES"
  echo "noted"
}

note_line() { printf '%s\t%s\n' "$(date '+%H:%M')" "$*" >>"$NOTES"; }

# mark <label>: a point in time; `mark away` starts the GUI phase (no sound or speech from here
# until his day-end), and the GUI phase's own perf stream.
step_mark() {
  [ $# -eq 1 ] || fail "usage: $SCRIPT mark <label>"
  case "$1" in *[!A-Za-z0-9._-]*) fail "a mark is letters, digits, dots, dashes and underscores" ;; esac
  mkdir -p "$WORK"
  printf '%s\t%s\t%s\n' "$(now_ms)" "$(clock)" "$1" >>"$MARKS"
  if [ "$SESSION" = R ] && [ "$1" = away ]; then
    clock >"$WORK/away"
    if [ "$(cut -f3 <<<"$(shot_state)")" != none ]; then
      warn "BatteryPulse remembers an iPhone or iPad by name: no picture taken from now on is attached"
    fi
    gui_stream_start
  fi
  echo "marked $1 at $(clock)"
}

# MARK: - The app

app_running() { pgrep -x BatteryPulse >/dev/null; }

app_pid() { pgrep -x BatteryPulse | head -1 || true; }

plist_value() { plutil -extract "$2" raw -o - "$1" 2>/dev/null || echo -; }

app_version() {
  if [ -f "$APP/Contents/Info.plist" ]; then
    echo "$(plist_value "$APP/Contents/Info.plist" CFBundleShortVersionString) ($(plist_value "$APP/Contents/Info.plist" CFBundleVersion))"
  else
    echo none
  fi
}

quit_app() {
  app_running || return 0
  osascript -e "tell application id \"$BUNDLE_ID\" to quit" >/dev/null 2>&1 || true
  local tries=0
  while app_running && [ "$tries" -lt 20 ]; do
    sleep 0.5
    tries=$((tries + 1))
  done
  if app_running; then
    pkill -x BatteryPulse || true
    sleep 1
  fi
}

set_default() { defaults write "$BUNDLE_ID" "$1" "$2" "$3"; }

# The settings every GUI step starts from (restore gui puts his back before the logged day): no
# automatic update check (its window would cover the widgets; Session B, lesson 5), the menu bar
# item with the icon and the charge, the Developer section (Raw Data, Demo Mode), the main window,
# no iPhone and iPad reads.
session_settings() {
  set_default updateFrequency -string never
  set_default showInMenuBar -bool true
  set_default showDeveloperSection -bool true
  set_default menuBarShowsIcon -bool true
  set_default menuBarShowsCharge -bool true
  set_default menuBarShowsPower -bool false
  set_default menuBarShowsTemperature -bool false
  set_default prefersCompactWindow -bool false
  set_default readDevices -bool false
}

on_battery() {
  case "$(pmset -g batt)" in
    *"'Battery Power'"*) return 0 ;;
    *) return 1 ;;
  esac
}

battery_percent() { pmset -g batt | grep -o -E '[0-9]+%' | head -1 | tr -d % || true; }

# battlimit_value [<file>]: the Charge Limit powerd holds, from `pmset -g battlimit` (no privileges):
# "chargeSocLimitSoc = 80" in each of its entries (Session A, plan-0.7.0 Appendix C finding 9),
# else a "<n>%" form; nothing when it says "No battery level limits set". It holds the limit only
# on the adapter (below the limit too), never on battery.
battlimit_value() {
  local text
  if [ -n "${1:-}" ]; then text="$(cat "$1" 2>/dev/null || true)"; else text="$(pmset -g battlimit 2>/dev/null || true)"; fi
  {
    sed -n 's/.*chargeSocLimitSoc[^0-9]*\([0-9][0-9]*\).*/\1/p' <<<"$text"
    grep -o -E '[0-9]+ ?%' <<<"$text" | tr -d ' %'
  } | head -1 || true
}

appearance() {
  local dark=false
  if [ "$1" = dark ]; then dark=true; fi
  osascript -e "tell application \"System Events\" to tell appearance preferences to set dark mode to $dark" \
    >/dev/null 2>&1 || fail "can't switch the appearance: allow this app to control System Events (System Settings → Privacy & Security → Automation)"
}

is_dark() {
  osascript -e 'tell application "System Events" to tell appearance preferences to get dark mode' 2>/dev/null || echo unknown
}

# wallpapers: each desktop's picture, one path per line, by System Events (the paths stay on the
# Mac: in the backup, never in a report); nothing when it can't be read.
wallpapers() {
  osascript -e 'tell application "System Events"
    set out to ""
    repeat with d in desktops
      set out to out & (picture of d) & linefeed
    end repeat
    return out
  end tell' 2>/dev/null || true
}

# The widget extension's processes, by their executable's path at the start of the argument list
# (so no shell whose command line names it): pgrep -x and pkill -x match macOS's p_comm, cut to 16
# characters, which "BatteryPulseWidget" (18) never equals.
WIDGET_EXEC='^/[^ ]*/BatteryPulseWidget\.appex/Contents/MacOS/BatteryPulseWidget( |$)'
widget_pids() { pgrep -f "$WIDGET_EXEC" 2>/dev/null || true; }

# fresh_widget_pid <the pids before, space-separated> [<seconds, 60 by default>]: a widget
# extension process that wasn't among them, waited for up to that long (PLAN.md §6.0 rule 4: an
# update ends the extension before its swap, and the new version's launch reloads every kind, so
# a new process is the redraw); printed, or nothing when none came in time.
fresh_widget_pid() {
  local before=" $1 " waited=0 pid
  while :; do
    for pid in $(widget_pids); do
      case "$before" in
        *" $pid "*) ;;
        *)
          echo "$pid"
          return 0
          ;;
      esac
    done
    [ "$waited" -lt "${2:-60}" ] || return 0
    sleep 5
    waited=$((waited + 5))
  done
}

end_widget_extension() { pkill -TERM -f "$WIDGET_EXEC" 2>/dev/null || true; }

# end_widget_extension_and_wait: ends every BatteryPulseWidget process before a swap and waits for
# it: SIGTERM first, SIGKILL after 0.5 s, giving up after 1.5 s. Session A found that chronod
# refetches a widget's descriptors at the version change from whatever extension still runs, and
# caches them under the new CFBundleVersion: the previous build's static descriptor then made every
# reload of a configurable kind fail (CHSErrorDomain 1103). Prints the milliseconds it took.
end_widget_extension_and_wait() {
  local ticks=0 signal=TERM
  # 20 ms ticks, counted rather than timed: macOS's bash 3.2 has no clock below a second.
  while [ -n "$(widget_pids)" ]; do
    if [ "$ticks" -ge 75 ]; then
      warn "a BatteryPulseWidget process still runs after about 1.5 s"
      break
    fi
    if [ "$ticks" -ge 25 ]; then signal=KILL; fi
    pkill "-$signal" -f "$WIDGET_EXEC" 2>/dev/null || true
    sleep 0.02
    ticks=$((ticks + 1))
  done
  echo "widget extension ended before the swap: about $((ticks * 20)) ms, last signal $signal"
}

# MARK: - Builds

MOUNT=""
mount_dmg() {
  MOUNT="$(mktemp -d "${TMPDIR:-/tmp}/bp-080-mount.XXXXXX")"
  hdiutil attach -quiet -nobrowse -readonly -noautoopen -mountpoint "$MOUNT" "$1" || fail "can't mount $1"
}

unmount_dmg() {
  hdiutil detach -quiet "$MOUNT" 2>/dev/null || hdiutil detach -quiet -force "$MOUNT" 2>/dev/null || true
  rmdir "$MOUNT" 2>/dev/null || true
}

app_in_mount() { find "$MOUNT" -maxdepth 1 -name '*.app' -type d | head -1 || true; }

# describe_build <name> <origin>: its version and build number into builds.tsv.
describe_build() {
  local name="$1" origin="$2" app version build
  mount_dmg "$BUILDS/$name.dmg"
  app="$(app_in_mount)"
  version="$(plist_value "$app/Contents/Info.plist" CFBundleShortVersionString)"
  build="$(plist_value "$app/Contents/Info.plist" CFBundleVersion)"
  unmount_dmg
  touch "$WORK/builds.tsv"
  awk -F '\t' -v name="$name" '$1 != name' "$WORK/builds.tsv" >"$WORK/builds.tsv.tmp"
  mv "$WORK/builds.tsv.tmp" "$WORK/builds.tsv"
  printf '%s\t%s\t%s\t%s\n' "$name" "$version" "$build" "$origin" >>"$WORK/builds.tsv"
  echo "$name: $version ($build), $origin"
}

build_number_of() { awk -F '\t' -v n="$1" '$1 == n { print $3 }' "$WORK/builds.tsv" 2>/dev/null || true; }

# fetch_artifact <name> <run id> <artifact> <dmg file name>: builds/<name>.dmg, with
# `gh run download`. An expired artifact (90 days) comes back from a new dispatch of the same code.
fetch_artifact() {
  local name="$1" run="$2" artifact="$3" file="$4" dir dmg
  dir="$BUILDS/$name.download"
  rm -rf "$dir"
  mkdir -p "$dir"
  gh run download "$run" -R "$REPO" -n "$artifact" -D "$dir" ||
    fail "can't download $artifact of run $run (expired? a new dispatch of the same code makes a new one)"
  dmg="$(find "$dir" -name "$file" -type f | head -1 || true)"
  [ -n "$dmg" ] || fail "$artifact of run $run has no $file"
  mv "$dmg" "$BUILDS/$name.dmg"
  rm -rf "$dir"
  describe_build "$name" "run $run, artifact $artifact"
}

# locate_builds: U and F from the integration branch's successful CI runs whose commit is the frozen
# one or an ancestor with the same code (Sources, Resources, Package.swift, build-app.sh): the oldest
# run with a $RC_VERSION DMG is U (D1 dispatches it before F, so its build number is the lower); the
# newest $F_VERSION DMG is F. A pin (RUN_<name>, ARTIFACT_<name>) overrides each.
LOC_U=""
LOC_F=""
locate_builds() {
  local head run sha names artifact rc_runs="" f="" rc_re f_re
  head="$(git -C "$ROOT" rev-parse HEAD)"
  rc_re="$(sed 's/\./\\./g' <<<"$RC_VERSION")"
  f_re="$(sed 's/\./\\./g' <<<"$F_VERSION")"
  while IFS=$'\t' read -r run sha; do
    [ -n "$run" ] || continue
    git -C "$ROOT" merge-base --is-ancestor "$sha" "$head" 2>/dev/null || continue
    git -C "$ROOT" diff --quiet "$sha" "$head" -- Sources Resources Package.swift scripts/build-app.sh 2>/dev/null || continue
    names="$(gh api "repos/$REPO/actions/runs/$run/artifacts?per_page=100" --jq '.artifacts[] | select(.expired | not) | .name' 2>/dev/null || true)"
    artifact="$(grep -x "BatteryPulse-$rc_re-$sha" <<<"$names" || true)"
    if [ -n "$artifact" ]; then rc_runs="$rc_runs$run$TAB$artifact
"; fi
    artifact="$(grep -x "BatteryPulse-$f_re-$sha" <<<"$names" || true)"
    if [ -n "$artifact" ] && [ -z "$f" ]; then f="$run$TAB$artifact"; fi
  done < <(gh run list -R "$REPO" -b "$INTEGRATION_BRANCH" -w ci.yml -s success -L 40 --json databaseId,headSha \
    --jq '.[] | [.databaseId, .headSha] | @tsv' 2>/dev/null || true)
  # gh lists the newest first: U is the last line.
  LOC_U="$(grep . <<<"$rc_runs" | tail -1 || true)"
  LOC_F="$f"
}

# fetch_one <name> <pinned run> <pinned artifact> <located "run<TAB>artifact">: one build, pinned or
# located; "none" with the reason when neither has it.
fetch_one() {
  local name="$1" run="$2" artifact="$3" located="$4"
  [ ! -f "$BUILDS/$name.dmg" ] || return 0
  if [ -z "$run" ] && [ -n "$located" ]; then IFS=$'\t' read -r run artifact <<<"$located"; fi
  if [ -z "$run" ] || [ -z "$artifact" ]; then
    echo "no build $name (D1 dispatches it, or pins RUN_$name)" >"$BUILDS/$name.none"
    warn "no build $name: the steps that need it are not run"
    return 0
  fi
  rm -f "$BUILDS/$name.none"
  fetch_artifact "$name" "$run" "$artifact" BatteryPulse.dmg
}

# fetch_release <name> <tag>: builds/<name>.dmg from that published release's DMG.
fetch_release() {
  [ ! -f "$BUILDS/$1.dmg" ] || return 0
  rm -rf "$BUILDS/$1.download"
  mkdir -p "$BUILDS/$1.download"
  gh release download "$2" -R "$REPO" -p BatteryPulse.dmg -D "$BUILDS/$1.download" ||
    fail "can't download the $2 DMG"
  mv "$BUILDS/$1.download/BatteryPulse.dmg" "$BUILDS/$1.dmg"
  rm -rf "$BUILDS/$1.download"
  describe_build "$1" "release $2"
}

# fetch_rc_u: RC-U, pinned or located, and the widget's CI renders from its run.
fetch_rc_u() {
  if [ ! -f "$BUILDS/U.dmg" ] || [ ! -f "$BUILDS/F.dmg" ]; then locate_builds; fi
  fetch_one U "$RUN_U" "$ARTIFACT_U" "$LOC_U"
  [ -f "$BUILDS/U.dmg" ] || fail "no RC-U: D1 dispatches ci.yml with version $RC_VERSION on the frozen code, or pins RUN_U"
  fetch_previews
}

# Session R8's: the start (v0.6.2) for step 11c, then U and F. His own 0.7.1 is the base step 2
# updates from: no published 0.7.x is installed.
fetch_builds_r() {
  mkdir -p "$BUILDS"
  fetch_release start "$TAG_START"
  fetch_rc_u
  fetch_one F "$RUN_F" "$ARTIFACT_F" "$LOC_F"
}

# locate_build_l: the look shoot's build (PLAN.md §6.1, "a CI build of C7's merge"): the newest
# successful ci.yml run on the integration branch whose commit is the frozen one or an ancestor
# with the same code (Sources, Resources, Package.swift, build-app.sh), with an unexpired DMG
# artifact: a push's BatteryPulse-<sha> (version 0.0.0) or a dispatch's BatteryPulse-<version>-<sha>.
# Its build number is the clock's (0.7.1's B-1), above v0.7.1's.
LOC_L=""
locate_build_l() {
  local head run sha names artifact
  head="$(git -C "$ROOT" rev-parse HEAD)"
  LOC_L=""
  while IFS=$'\t' read -r run sha; do
    [ -n "$run" ] || continue
    git -C "$ROOT" merge-base --is-ancestor "$sha" "$head" 2>/dev/null || continue
    git -C "$ROOT" diff --quiet "$sha" "$head" -- Sources Resources Package.swift scripts/build-app.sh 2>/dev/null || continue
    names="$(gh api "repos/$REPO/actions/runs/$run/artifacts?per_page=100" --jq '.artifacts[] | select(.expired | not) | .name' 2>/dev/null || true)"
    artifact="$(grep -x -E "BatteryPulse-([0-9]+\.[0-9]+\.[0-9]+-)?$sha" <<<"$names" | head -1 || true)"
    if [ -n "$artifact" ]; then
      LOC_L="$run$TAB$artifact"
      return 0
    fi
  done < <(gh run list -R "$REPO" -b "$INTEGRATION_BRANCH" -w ci.yml -s success -L 40 --json databaseId,headSha \
    --jq '.[] | [.databaseId, .headSha] | @tsv' 2>/dev/null || true)
}

# fetch_build_l: the look shoot's build L, pinned or located (gh lists the newest run first).
fetch_build_l() {
  mkdir -p "$BUILDS"
  if [ ! -f "$BUILDS/L.dmg" ]; then locate_build_l; fi
  fetch_one L "$RUN_L" "$ARTIFACT_L" "$LOC_L"
  [ -f "$BUILDS/L.dmg" ] || fail "no CI build of the frozen code on $INTEGRATION_BRANCH (a push's ci.yml run makes one; or pin RUN_L and ARTIFACT_L)"
}

# fetch_previews: the widget's CI renders from RC-U's run (ci.yml's widget-previews-<sha>), which
# step 3 compares the gallery's widgets with; without them, the look check's PNGs.
fetch_previews() {
  local origin run sha
  [ ! -d "$WORK/previews" ] || return 0
  origin="$(awk -F '\t' '$1 == "U" { print $4 }' "$WORK/builds.tsv" 2>/dev/null || true)"
  run="$(sed -n 's/^run \([0-9]*\),.*/\1/p' <<<"$origin")"
  sha="$(sed -n 's/.*BatteryPulse-[0-9.]*-\([0-9a-f]*\)$/\1/p' <<<"$origin")"
  if [ -n "$run" ] && [ -n "$sha" ] && gh run download "$run" -R "$REPO" -n "widget-previews-$sha" -D "$WORK/previews" >/dev/null 2>&1; then
    echo "the widget's CI renders: $(find "$WORK/previews" -name '*.png' | grep -c . || true) in $WORK/previews"
  else
    rm -rf "$WORK/previews"
    warn "no widget previews from RC-U's run: step 3 compares with the look check's PNGs"
  fi
}

# install_build <start|U|F|L|backup> [--no-launch]: the build's app into /Applications the way
# UpdateInstaller does it: the widget extension ended first and waited for (D-17), a copy staged on
# the same volume, its bundle ID and code signature checked, one atomic swap with the installed copy
# (swap.swift), the old copy deleted once it has quit, lsregister -f, a relaunch. WidgetKit caches
# by CFBundleVersion, so a build whose number isn't higher than the installed one is refused, except
# the start 0.6.2 over a newer app (step 11c) and his backed-up app. The extension's pids before the
# swap and 10 s after the relaunch go into installs.tsv and the step's section (G7-2).
install_build() {
  local name="$1" launch_after=1 staging staged bundle version build installed last_seen why="higher" before after ended
  if [ "${2:-}" = --no-launch ]; then launch_after=0; fi
  mkdir -p "$WORK"
  if [ "$name" != backup ] && [ "$(cat "$WORK/installed" 2>/dev/null || true)" = "$name $(installed_build)" ]; then
    echo "$name is installed already: $(app_version)"
    if [ "$launch_after" = 1 ] && ! app_running; then launch_r; fi
    return 0
  fi
  staging="$(mktemp -d "$WORK/stage.XXXXXX")"
  staged="$staging/BatteryPulse.app"
  if [ "$name" = backup ]; then
    [ -f "$BACKUP/BatteryPulse.zip" ] || fail "no backup of his app in $BACKUP"
    ditto -x -k "$BACKUP/BatteryPulse.zip" "$staging"
  else
    [ -f "$BUILDS/$name.dmg" ] || fail "build $name is missing ($(cat "$BUILDS/$name.none" 2>/dev/null || echo "run $SCRIPT prepare"))"
    mount_dmg "$BUILDS/$name.dmg"
    bundle="$(app_in_mount)"
    if [ -z "$bundle" ]; then
      unmount_dmg
      fail "no app in $name's DMG"
    fi
    ditto "$bundle" "$staged"
    unmount_dmg
  fi
  [ -d "$staged" ] || fail "the staged copy of $name is missing"
  xattr -dr com.apple.quarantine "$staged" 2>/dev/null || true
  [ "$(plist_value "$staged/Contents/Info.plist" CFBundleIdentifier)" = "$BUNDLE_ID" ] ||
    fail "$name isn't $BUNDLE_ID"
  if ! codesign --verify --deep --strict "$staged" 2>/dev/null; then
    # His own app comes back regardless: restore must not stop before his settings and data.
    if [ "$name" != backup ]; then
      rm -rf "$staging"
      fail "$name's code signature doesn't verify"
    fi
    warn "his backed-up app's code signature doesn't verify; restore puts it back anyway"
  fi
  version="$(plist_value "$staged/Contents/Info.plist" CFBundleShortVersionString)"
  build="$(plist_value "$staged/Contents/Info.plist" CFBundleVersion)"
  build="${build%%.*}"
  installed=0
  if [ -f "$APP/Contents/Info.plist" ]; then
    installed="$(installed_build)"
    installed="${installed%%.*}"
  fi
  case "$build$installed" in "" | *[!0-9]*) fail "a build number isn't a number ($build, $installed)" ;; esac
  if [ "$build" -le "$installed" ]; then
    if [ "$name" = start ]; then
      why="the start $START_VERSION, below the installed app (step 11c)"
    elif [ "$name" = backup ]; then
      why="restore puts his app back"
    else
      rm -rf "$staging"
      fail "refusing $name: its build $build isn't higher than the installed $installed, and WidgetKit caches by it (D1 dispatches U and F in this order; L is a CI build above v$BASE_VERSION)"
    fi
    echo "note: $name's build $build isn't higher than the installed $installed: $why"
  fi
  if [ "$(stat -f %d "$staging")" != "$(stat -f %d /Applications)" ]; then
    warn "the staging folder may not be on the volume of /Applications; the swap says if it isn't"
  fi
  before="$(widget_pids | tr '\n' ' ' | sed 's/ $//')"
  # Before the swap, so chronod asks the new extension for the descriptors (D-17).
  ended="$(end_widget_extension_and_wait)"
  if [ -d "$APP" ]; then
    "$BIN/swap" "$staged" "$APP" || fail "the swap failed; $APP is as it was"
  else
    mv "$staged" "$APP"
  fi
  # The old version runs on from the staged path until it quits, as after Install and Relaunch.
  quit_app
  rm -rf "$staging"
  "$LSREGISTER" -f "$APP" || warn "lsregister -f failed"
  last_seen="$(defaults read "$BUNDLE_ID" lastSeenVersion 2>/dev/null || true)"
  if [ "$last_seen" = "$version" ]; then end_widget_extension; fi
  echo "$name $build" >"$WORK/installed"
  clock >"$WORK/installed.time"
  after="-"
  if [ "$launch_after" = 1 ]; then
    launch_r
    sleep 10
    after="$(widget_pids | tr '\n' ' ' | sed 's/ $//')"
  fi
  printf '%s\t%s\t%s (%s)\t%s\t%s\t%s\t%s\n' "$(clock)" "$name" "$version" "$build" "$why" "${before:--}" "$ended" "${after:--}" \
    >>"$WORK/installs.tsv"
  echo "installed $name: $(app_version); the widget extension's pids before: ${before:-none}; $ended; 10 s after the launch: ${after:-none}"
}

installed_build() { plist_value "$APP/Contents/Info.plist" CFBundleVersion; }

# install <start|U|F|L|backup>: one build, as every step installs it, with its section lines: the
# pids, and CHSErrorDomain 1103 lines since the install (read again by the step's later shots).
step_install() {
  rl_only install
  [ $# -eq 1 ] || fail "usage: $SCRIPT install <start|U|F|L|backup>"
  case "$SESSION:$1" in R:start | R:U | R:F | R:backup | L:L | L:backup) ;; *) fail "no build $1 in Session $SESSION" ;; esac
  [ "$1" = backup ] || [ -n "$(original_of app)" ] || fail "prepare records the app's change first: $SCRIPT prepare"
  install_build "$1"
  use_section 05-installs "Installs"
  out "- $(tail -1 "$WORK/installs.tsv" | awk -F '\t' '{ printf "%s: %s %s (%s); extension pids before %s, %s, after %s", $1, $2, $3, $4, $5, $6, $7 }')"
}

# chs_since <time>: the CHSErrorDomain 1103 lines since then (chronod's refusal of a timeline whose
# descriptor it cached from another build; Session A), the log tool's own left out (chs_line).
chs_since() {
  log_since "$1" "$CHS_PREDICATE" "$LOGS/chs.ndjson" >/dev/null
  chs_line "$1" "$LOGS/chs.ndjson"
}

# chs_line <time> <ndjson>: chs_since's line from what `log show` found. The predicate reads
# eventMessage alone, so it also matches each `log` run's own line since then (not_log_tool):
# Session F counted 1, 2 and 3 for its three calls from one start.
chs_line() {
  local count
  count="$(not_log_tool "$2" | grep -c . || true)"
  echo "CHSErrorDomain 1103 lines since $1: ${count:-0} ($(($(entry_count "$2") - ${count:-0})) of the log tool's own left out)"
}

# MARK: - Tools

tools_need_build() { [ ! -x "$BIN/$1" ] || [ "$2" -nt "$BIN/$1" ]; }

# build_tools: perf-stats (the logged day), the swap, frames (the pixel measures, the contact
# sheet), ui (the hands) and bpulse (the reads beside the pictures), built from the frozen worktree.
build_tools() {
  mkdir -p "$BIN"
  if tools_need_build perf-stats "$ROOT/scripts/perf-stats.swift"; then
    echo "building scripts/perf-stats.swift..."
    xcrun swiftc -O "$ROOT/scripts/perf-stats.swift" -o "$BIN/perf-stats" 2>"$BIN/perf-stats.log" ||
      fail "can't build scripts/perf-stats.swift; see $BIN/perf-stats.log"
  fi
  if tools_need_build swap "$HERE/swap.swift"; then
    echo "building swap.swift..."
    xcrun swiftc -O "$HERE/swap.swift" -o "$BIN/swap" 2>"$BIN/swap.log" ||
      fail "can't build swap.swift, which every install needs; see $BIN/swap.log"
  fi
  build_gui_tools
  build_bpulse
}

# build_gui_tools: frames (the pixel measures, the crops' stats, the contact sheet) and ui (the
# hands), which every session that clicks or crops needs: Session R's prepare builds them with the
# rest, a short session by its `tools` call.
build_gui_tools() {
  mkdir -p "$BIN"
  write_sheet_words
  if tools_need_build frames "$HERE/frames.swift"; then
    echo "building frames.swift..."
    if ! xcrun swiftc -O "$HERE/frames.swift" -o "$BIN/frames" 2>"$BIN/frames.log"; then
      rm -f "$BIN/frames"
      warn "frames.swift didn't build (see $BIN/frames.log): no pixel measure, crop or contact sheet"
    fi
  fi
  if tools_need_build ui "$HERE/ui.swift"; then
    echo "building ui.swift..."
    if ! xcrun swiftc -O "$HERE/ui.swift" -o "$BIN/ui" 2>"$BIN/ui.log"; then
      rm -f "$BIN/ui"
      warn "ui.swift didn't build (see $BIN/ui.log): every ui step is not checked"
    fi
  fi
}

# tools: a short session's first script call: ui and frames built from its own frozen worktree
# into ~/bp-080/<H|D3>/bin, where ui finds its session's folder (Session R8's and the look shoot's
# prepare build them in their own bin/). The After publishing check clicks, crops and reads AX
# through them.
step_tools() {
  [ "$(uname -s)" = Darwin ] || fail "this runs on the Mac"
  xcode-select -p >/dev/null 2>&1 ||
    fail "Xcode or the Command Line Tools are missing (xcode-select --install), then $SCRIPT tools again"
  mkdir -p "$WORK" "$LOGS" "$SECTIONS" "$SHOTS"
  build_gui_tools
  echo "tools in $BIN: ui $(if [ -x "$BIN/ui" ]; then echo built; else echo "not built (see $BIN/ui.log)"; fi), frames $(if [ -x "$BIN/frames" ]; then echo built; else echo "not built (see $BIN/frames.log)"; fi)"
  [ -x "$BIN/ui" ] && [ -x "$BIN/frames" ]
}

# build_bpulse: bpulse from the frozen worktree (xcrun swift build -c release --product bpulse;
# Package.swift needs Swift tools 6.4). A step that needs it records "not run" without it.
build_bpulse() {
  [ ! -x "$BIN/bpulse" ] || return 0
  mkdir -p "$BIN"
  echo "building bpulse (release)..."
  if (cd "$ROOT" && xcrun swift build -c release --product bpulse) >"$BIN/bpulse.log" 2>&1; then
    cp "$(cd "$ROOT" && xcrun swift build -c release --product bpulse --show-bin-path)/bpulse" "$BIN/bpulse"
  else
    warn "bpulse didn't build (see $BIN/bpulse.log): the steps that read it record not run"
  fi
}

perf_stats() { "$BIN/perf-stats" "$@"; }

# bpulse_json <file>: `bpulse --json` into the file; false without bpulse.
bpulse_json() {
  [ -x "$BIN/bpulse" ] || return 1
  "$BIN/bpulse" --json >"$1" 2>&1
}

# json_number <file> <key>, json_word <file> <key>: a top-level value of bpulse's pretty JSON.
json_number() { sed -n "s/^  \"$2\"[[:space:]]*:[[:space:]]*\\(-*[0-9][0-9.]*\\).*/\\1/p" "$1" 2>/dev/null | head -1 || true; }
json_word() { sed -n "s/^  \"$2\"[[:space:]]*:[[:space:]]*\"*\\([A-Za-z]*\\).*/\\1/p" "$1" 2>/dev/null | head -1 || true; }

# charge_row <bpulse json>: "<charge> % <state>, external power, NotChargingReason <n> (bit 24)" for
# the Charge Limit rows. The state is the parsed snapshot's (charging, notCharging, charged), which
# IsCharging and FullyCharged decide.
charge_row() {
  local reason
  reason="$(json_number "$1" notChargingReason)"
  printf '%s %% %s, external power %s, NotChargingReason %s (bit 24: %s)' \
    "$(json_number "$1" chargePercent)" "$(json_word "$1" chargeState)" "$(json_word "$1" isExternalPowerConnected)" \
    "${reason:--}" "$(if [ -n "$reason" ] && [ $((reason & 0x01000000)) -ne 0 ]; then echo yes; else echo no; fi)"
}

# MARK: - Logs

# Streams this call started, ended on exit (also after Control-C).
STREAMS=""
STREAM=""
BACKGROUND=""
cleanup() {
  local pid
  # log stream ends cleanly on SIGINT; the helpers in the background (subshells, caffeinate,
  # xctrace) on SIGTERM, which a subshell waiting for its sleep doesn't defer.
  for pid in $STREAMS; do
    kill -INT "$pid" 2>/dev/null || true
  done
  for pid in $BACKGROUND; do
    kill -TERM "$pid" 2>/dev/null || true
  done
}
trap cleanup EXIT
trap 'exit 130' INT TERM HUP

# perf_capture <file>: `log stream` of the perf lines into the file, in the background; STREAM is
# its PID. Lines reach the file 10-20 ms after they are logged; the first line is log's header.
perf_capture() {
  log stream --level debug --style ndjson --predicate "$PERF_PREDICATE" >"$1" 2>"$1.err" </dev/null &
  STREAM=$!
  STREAMS="$STREAMS $STREAM"
  sleep 2
}

# perf_stop <pid>: ends a stream the way Control-C does, after giving the last lines a moment.
perf_stop() {
  sleep 2
  kill -INT "$1" 2>/dev/null || true
  local tries=0 kept="" pid
  while kill -0 "$1" 2>/dev/null && [ "$tries" -lt 10 ]; do
    sleep 0.3
    tries=$((tries + 1))
  done
  kill -TERM "$1" 2>/dev/null || true
  for pid in $STREAMS; do
    if [ "$pid" != "$1" ]; then kept="$kept $pid"; fi
  done
  STREAMS="$kept"
}

# summarize <capture> [<extended regular expression>]: perf-stats' summary into the section,
# optionally only its matching lines.
summarize() {
  local summary
  summary="$(perf_stats "$1" 2>&1)" || summary="(no perf lines in $(basename "$1"): $summary)"
  if [ $# -ge 2 ]; then summary="$(grep -E "$2" <<<"$summary" || true)"; fi
  printf '%s\n' '```' "$summary" '```' | public | tee -a "$SECTION"
}

# log_since <start> <predicate> <file>: `log show` as ndjson; prints the number of entries.
# ndjson ends with a summary object ({"count":…,"finished":1}) even when nothing matched, so it is
# left out of the count, and the full path avoids zsh's `log` builtin if this ever runs there.
log_since() {
  /usr/bin/log show --start "$1" --info --debug --style ndjson --predicate "$2" >"$3" 2>/dev/null || true
  entry_count "$3"
}

# entry_count <ndjson>: the entries of `log show --style ndjson`, without its summary object.
entry_count() { grep '^{' "$1" | grep -c -v '"finished"' || true; }

# entries <ndjson>: "<timestamp>\t<process>\t<message>" per entry of `log show --style ndjson`.
entries() {
  awk '
    function text(line, name,    start, rest, out, i, c) {
      start = index(line, "\"" name "\"")
      if (start == 0) return ""
      rest = substr(line, start + length(name) + 2)
      sub(/^ *: *"/, "", rest)
      out = ""
      for (i = 1; i <= length(rest); i++) {
        c = substr(rest, i, 1)
        if (c == "\\") { out = out substr(rest, i + 1, 1); i++; continue }
        if (c == "\"") break
        out = out c
      }
      return out
    }
    /^\{/ && !/"finished"/ {
      path = text($0, "processImagePath"); sub(/.*\//, "", path)
      print text($0, "timestamp") "\t" path "\t" text($0, "eventMessage")
    }' "$1"
}

# messages <ndjson>: "<time of day> <process> <message>" per entry, for reading and for the report.
messages() { entries "$1" | awk -F '\t' '{ print substr($1, 12, 12) " " $2 " " $3 }'; }

# not_log_tool <ndjson>: the entries, as `entries` prints them, but the log tool's own. Each run of
# `log` logs its command line, predicate and all ("log run noninteractively, args: …"), so a
# predicate on eventMessage alone also matches its own run and the earlier ones: Session F's one
# sandbox denial and its CHSErrorDomain 1103 lines were those (its R-feed-history note).
not_log_tool() { entries "$1" | awk -F '\t' '$2 != "log" && index($3, "log run noninteractively") == 0'; }

crash_reports_since() { find "$REPORTS" -maxdepth 1 -name 'BatteryPulse*' -newer "$1" -type f 2>/dev/null | sort; }

# crash_summary <marker>: the count of new crash reports, a copy of each in logs/crash/, and each
# one's header line and exception, which carry no personal data.
crash_summary() {
  local report count=0
  mkdir -p "$LOGS/crash"
  while IFS= read -r report; do
    [ -n "$report" ] || continue
    count=$((count + 1))
    cp "$report" "$LOGS/crash/"
    out "- $(basename "$report"): $(head -1 "$report" | grep -o -E '"(app_version|build_version|bug_type|name)" *: *"[^"]*"' | tr '\n' ' ')"
    out "  $(grep -o -E '"(type|signal|subtype|indicator)" *: *"[^"]*"' "$report" | head -4 | tr '\n' ' ')"
  done < <(crash_reports_since "$1")
  out "- new crash reports: $count (copies in logs/crash/)"
}


# MARK: - Screenshots

# shot <name>: the screen into shots/<name>.png, and a smaller JPEG to look at.
shot() {
  local name="$1"
  case "$name" in *[!A-Za-z0-9._-]*) fail "a shot's name is letters, digits, dots, dashes and underscores" ;; esac
  mkdir -p "$SHOTS"
  screencapture -x "$SHOTS/$name.png" || fail "screencapture failed: allow Screen Recording for this app in System Settings → Privacy & Security"
  # Never attached itself, but a crop of it shows what it showed then.
  log_shot_state "$SHOTS/$name.png" "$(shot_state)"
  sips -Z 1600 -s format jpeg -s formatOptions 70 "$SHOTS/$name.png" --out "$SHOTS/$name-view.jpg" >/dev/null
  echo "SHOT $SHOTS/$name-view.jpg (full size: $SHOTS/$name.png)"
}

step_shot() {
  [ $# -eq 1 ] || fail "usage: $SCRIPT shot <name>"
  shot "$1"
}

# attach <image> <caption>: a copy of the image, at most 1200 px and about 300 KB as JPEG, for the report.
step_attach() {
  [ $# -ge 2 ] || fail "usage: $SCRIPT attach <image> <caption>"
  local image="$1" caption name out_file count
  shift
  caption="$*"
  [ -f "$image" ] || fail "no image $image"
  english_only "$caption"
  attach_allowed "$image"
  mkdir -p "$PUBLISH"
  touch "$PUBLISH/captions.tsv"
  count="$(wc -l <"$PUBLISH/captions.tsv" | tr -d ' ')"
  name="$(basename "${image%.*}")"
  out_file="$(printf '%02d' $((count + 1)))-$name.jpg"
  sips -Z 1200 -s format jpeg -s formatOptions 60 "$image" --out "$PUBLISH/$out_file" >/dev/null
  if [ "$(wc -c <"$PUBLISH/$out_file")" -gt 307200 ]; then
    sips -Z 900 -s format jpeg -s formatOptions 50 "$PUBLISH/$out_file" --out "$PUBLISH/$out_file" >/dev/null
  fi
  printf '%s\t%s\n' "$out_file" "$(printf '%s' "$caption" | tr '\t\n|' '  /')" >>"$PUBLISH/captions.tsv"
  echo "attached $out_file ($(($(wc -c <"$PUBLISH/$out_file") / 1024)) KB): $caption"
}

step_unattach() {
  [ $# -eq 1 ] || fail "usage: $SCRIPT unattach <file name in publish/>"
  [ -f "$PUBLISH/captions.tsv" ] || fail "nothing is attached"
  # Only an attached image's own name: never a path, so no other file is ever removed.
  case "$1" in */* | .* | "") fail "unattach takes the name of an attached image in publish/, not a path" ;; esac
  cut -f1 "$PUBLISH/captions.tsv" | grep -q -x -F -- "$1" || fail "$1 isn't attached (publish/captions.tsv)"
  awk -F '\t' -v name="$1" '$1 != name' "$PUBLISH/captions.tsv" >"$PUBLISH/captions.tmp"
  mv "$PUBLISH/captions.tmp" "$PUBLISH/captions.tsv"
  rm -f "$PUBLISH/$1"
  echo "removed $1"
}

step_crop() {
  [ $# -eq 6 ] || fail "usage: $SCRIPT crop <image> <x> <y> <width> <height> <name> (pixels from the top left)"
  [ -x "$BIN/frames" ] || fail "the frame helper isn't built (see $BIN/frames.log)"
  case "$6" in *[!A-Za-z0-9._-]*) fail "a crop's name is letters, digits, dots, dashes and underscores" ;; esac
  mkdir -p "$SHOTS"
  "$BIN/frames" crop "$1" "$2" "$3" "$4" "$5" "$SHOTS/$6.png"
  register_shot "$SHOTS/$6.png" "$1"
}


# MARK: - prepare (step 1)

check_tools() {
  [ "$(uname -s)" = Darwin ] || fail "this runs on the Mac"
  if ! xcode-select -p >/dev/null 2>&1; then
    fail "Xcode or the Command Line Tools are missing (xcode-select --install), then run $SCRIPT prepare again"
  fi
  if ! command -v gh >/dev/null 2>&1; then
    fail "the GitHub CLI (gh) is missing: install it from https://cli.github.com, sign in with 'gh auth login', then run $SCRIPT prepare again"
  fi
  gh auth status -h github.com >/dev/null 2>&1 ||
    fail "the GitHub CLI isn't signed in: 'gh auth login' (GitHub.com, HTTPS, a web browser), then run $SCRIPT prepare again"
  case "$(sw_vers -productVersion)" in 27.*) ;; *) warn "this session was planned for macOS 27" ;; esac
}

# A fresh backup into ~/bp-080/<R|L>/backup (PLAN.md §6.1 step 1, §6.4 step 1): the app, the
# defaults domain (his settings: Check for updates, Window to open, the window style, the app's own
# AppleLanguages), Application Support, the widget extension's AppleLanguages, the appearance, the
# 24-hour setting. A second prepare keeps it unless asked for a fresh one.
backup() {
  if [ -f "$BACKUP/done" ] && [ "${1:-}" != --fresh-backup ]; then
    echo "keeping the backup of $(cat "$BACKUP/done") in $BACKUP (prepare --fresh-backup takes a new one)"
    return 0
  fi
  [ -d "$APP" ] || fail "$APP is missing: his own BatteryPulse is the session's start"
  rm -rf "$BACKUP"
  mkdir -p "$BACKUP"
  ditto -c -k --keepParent "$APP" "$BACKUP/BatteryPulse.zip"
  app_version >"$BACKUP/version"
  # An absent domain exports as an empty one.
  defaults export "$BUNDLE_ID" "$BACKUP/defaults.plist"
  if [ -d "$SUPPORT" ]; then ditto "$SUPPORT" "$BACKUP/support"; fi
  is_dark >"$BACKUP/dark-mode"
  defaults read -g AppleInterfaceStyleSwitchesAutomatically >"$BACKUP/auto-appearance" 2>/dev/null ||
    echo 0 >"$BACKUP/auto-appearance"
  defaults read -g AppleICUForce24HourTime >"$BACKUP/24-hour" 2>/dev/null || echo unset >"$BACKUP/24-hour"
  wallpapers >"$BACKUP/wallpapers"
  if defaults read "$WIDGET_PREFS" AppleLanguages >"$BACKUP/widget-languages" 2>/dev/null; then :; else
    rm -f "$BACKUP/widget-languages"
  fi
  if defaults read "$BUNDLE_ID" AppleLanguages >"$BACKUP/app-languages" 2>/dev/null; then :; else
    rm -f "$BACKUP/app-languages"
  fi
  clock >"$BACKUP/done"
  echo "backed up $(cat "$BACKUP/version"), his settings and data to $BACKUP"
}

# setting_of <key>: one of his BatteryPulse settings as the backup holds it, or "default (unset)".
setting_of() {
  local value
  value="$(plutil -extract "$1" raw -o - "$BACKUP/defaults.plist" 2>/dev/null || true)"
  printf '%s\n' "${value:-default (unset)}"
}
# MARK: - The sessions' bookkeeping (0.6.2's hands-free mode)

# The session's files, beside the shared ones (answers.tsv, notes.tsv, sections/).
CHANGES="$WORK/changes.tsv"
RESTORED="$WORK/restored.tsv"
PROOFS="$WORK/proofs.tsv"
MEASURES="$WORK/measures.tsv"
BATCH="$WORK/batch.tsv"
# Up from `ready` until his day-end: the logged day, when nothing but the arm and day-end acts.
READY_FILE="$WORK/ready"
DAY_END="$WORK/day-ended"
HEARTBEAT="$WORK/heartbeat"
# The script's own heartbeat: touched every minute while any acting call runs (heartbeat_keeper), so
# a long command doesn't look like a stall; the arm counts the newer of the two.
SCRIPT_HEARTBEAT="$WORK/heartbeat.script"
# Keep-awake holders seen (time, where, pid, process name, assertion): local only. Their names
# never reach the report (the privacy lint refuses them) or the repository.
KEEPAWAKE_LOCAL="$WORK/keepawake.local"
# The crops the script made (window_shot, rect_shot, crop), each with the remembered devices it
# was taken with: the only pictures attach publishes.
PRODUCED="$WORK/produced.tsv"
# The state each of the script's pictures was taken in (shot's full shots and the crops; fields 2-4
# of produced.tsv), the latest line per path: a crop takes its source's, not the state at the crop.
SHOT_STATES="$WORK/shot-states.tsv"
# The apps the script opened that weren't running before ("<app>\t<pid>"): restore quits only
# these, never his own Xcode project, documents or settings.
LAUNCHED="$WORK/launched.tsv"
# Posted with the ready file: the arm window's waiter wakes at once instead of at its backstop.
READY_NOTIFY="io.github.nikitausov.BatteryPulse.session-r.ready"
# The logged day's perf stream (step 12), and the GUI phase's (steps 2-9, mark away to restore gui).
DAY_STREAM="$LOGS/day.ndjson"
GUI_STREAM="$LOGS/gui.ndjson"
DRY_RUN=""

r_only() { [ "$SESSION" = R ] || fail "$1 is a Session R command: run it from the frozen worktree ~/bp-080/R/run"; }

# rl_only <command>: a command Session R8 shares with the look shoot, which installs its own build
# over his 0.7.1 and puts his back at its end, from its own worktree (~/bp-080/L/run).
rl_only() { [ "$SESSION" = R ] || [ "$SESSION" = L ] || fail "$1 is a Session R8 or look-shoot command: run it from ~/bp-080/R/run or ~/bp-080/L/run"; }

# session_only <session> <command>: a short session's command, from its own frozen worktree.
session_only() { [ "$SESSION" = "$1" ] || fail "$2 is the $1 session's command: run it from ~/bp-080/$1/run"; }

# app_pid_of <app>: the main process of TextEdit, System Settings, Xcode or Accessibility Inspector,
# by its executable's path at the start of the argument list (pgrep -x can't match past 16
# characters, and a shell whose command line names the path must not count).
app_pid_of() {
  local exec
  case "$1" in
    TextEdit) exec='^/[^ ]*/TextEdit\.app/Contents/MacOS/TextEdit( |$)' ;;
    "System Settings") exec='^/System/Applications/System Settings\.app/Contents/MacOS/System Settings( |$)' ;;
    Xcode) exec='^/[^ ]*/Xcode[^/ ]*\.app/Contents/MacOS/Xcode( |$)' ;;
    "Accessibility Inspector") exec='^/[^ ]*/Accessibility Inspector\.app/Contents/MacOS/Accessibility Inspector( |$)' ;;
    *) return 0 ;;
  esac
  pgrep -f "$exec" 2>/dev/null | head -1 || true
}

# track_launch <app> <command...>: runs the command that opens the app; when the app wasn't
# running before, its new process goes into launched.tsv.
track_launch() {
  local app="$1" before after tries=0
  shift
  before="$(app_pid_of "$app")"
  "$@" >/dev/null 2>&1 || return 1
  [ -z "$before" ] || return 0
  after="$(app_pid_of "$app")"
  while [ -z "$after" ] && [ "$tries" -lt 40 ]; do
    sleep 0.25
    tries=$((tries + 1))
    after="$(app_pid_of "$app")"
  done
  if [ -n "$after" ]; then printf '%s\t%s\n' "$app" "$after" >>"$LAUNCHED"; fi
  return 0
}

# launched_by_script <app>: its running process is one the script opened.
launched_by_script() {
  local pid
  pid="$(app_pid_of "$1")"
  [ -n "$pid" ] && grep -q -x -F "$1$TAB$pid" "$LAUNCHED" 2>/dev/null
}

# quit_if_launched <app>: quits the app by its own Quit menu item (AX) only when the script opened
# it; his own instance stays as it was.
quit_if_launched() {
  local tries=0
  launched_by_script "$1" || return 0
  ui_run quit "$1" >/dev/null 2>&1 || return 0
  while [ -n "$(app_pid_of "$1")" ] && [ "$tries" -lt 20 ]; do
    sleep 0.25
    tries=$((tries + 1))
  done
  echo "closed $1 (the script opened it)"
}

# open-app <TextEdit|Xcode|Accessibility Inspector>: an app the session needs (Xcode for WP-18's
# canvas, Accessibility Inspector for step 7's fallback), opened by the script so restore knows it
# may quit it.
step_open_app() {
  r_only open-app
  case "${1:-}" in
    TextEdit | Xcode | "Accessibility Inspector") track_launch "$1" open -a "$1" || fail "can't open $1" ;;
    *) fail "usage: $SCRIPT open-app Xcode | TextEdit | \"Accessibility Inspector\"" ;;
  esac
  echo "opened $1$(if launched_by_script "$1"; then echo " (restore gui quits it)"; else echo " (it ran already: restore leaves it)"; fi)"
}

# open_pane <name>: a System Settings pane by its URL (proof P8), System Settings tracked.
open_pane() { track_launch "System Settings" open "$(pane_url "$1")"; }

# The background processes the script leaves running (the GUI phase's and the logged day's log
# streams, bpulse --record), by their pid files, checked against their command lines.
LEFTOVERS="gui-stream day-stream record awake"
leftover_running() {
  local pid what
  pid="$(cat "$WORK/$1.pid" 2>/dev/null || true)"
  case "$1" in *-stream) what="log stream" ;; awake) what="caffeinate -d" ;; *) what="--record" ;; esac
  [ -n "$pid" ] && kill -0 "$pid" 2>/dev/null && ps -o args= -p "$pid" 2>/dev/null | grep -q -F -- "$what"
}

# stop_leftovers [<name>...]: ends them (all by default) when their own step didn't (restore end,
# the next prepare).
stop_leftovers() {
  local name
  for name in ${*:-$LEFTOVERS}; do
    if leftover_running "$name"; then
      # The recording's pid is caffeinate's: its child, bpulse --record, is ended first, since a
      # signal to caffeinate alone may leave bpulse recording on (a terminal's Control-C reaches
      # both, as their process group).
      if [ "$name" = record ]; then pkill -INT -P "$(cat "$WORK/$name.pid")" 2>/dev/null || true; fi
      kill -INT "$(cat "$WORK/$name.pid")" 2>/dev/null || true
      sleep 1
      if leftover_running "$name"; then kill -TERM "$(cat "$WORK/$name.pid")" 2>/dev/null || true; fi
      echo "stopped the $name process left running"
    fi
    rm -f "$WORK/$name.pid"
  done
}

# abs_path <file>: the file's absolute path, as produced.tsv and shot-states.tsv record it.
abs_path() { printf '%s/%s\n' "$(cd "$(dirname "$1")" && pwd)" "$(basename "$1")"; }

# shot_state: what a picture taken now shows, as produced.tsv's fields 2-4: the window style, the
# app's language, and "named" while BatteryPulse remembers an iPhone or iPad by name (outside Demo
# Mode the sidebar's Devices section lists it) or the widget's feed holds one (an iPhone & iPad
# widget shows it), else "none".
shot_state() {
  printf '%s\t%s\t%s\n' "$(defaults read "$BUNDLE_ID" windowLook 2>/dev/null || echo standard)" \
    "$(defaults read "$BUNDLE_ID" AppleLanguages 2>/dev/null | tr -d ' \n()"' | cut -c1-20 || true)" \
    "$(if grep -q '"name"' "$SUPPORT/Devices/devices.json" "$FEED_FILE" 2>/dev/null; then echo named; else echo none; fi)"
}

# log_shot_state <file> <state>: the state a picture was taken in, for a later crop of it.
log_shot_state() {
  mkdir -p "$WORK"
  printf '%s\t%s\n' "$(abs_path "$1")" "$2" >>"$SHOT_STATES"
}

# source_state <image>: what a crop of that image shows: the state logged when the script took it
# (a full shot, a crop), else the state now, "named" when the image is older than the last
# `devices forget` (a device may have been remembered when it was taken).
source_state() {
  local path state forgot
  path="$(abs_path "$1")"
  state="$(awk -F '\t' -v p="$path" '$1 == p { l = $2 "\t" $3 "\t" $4 } END { print l }' "$SHOT_STATES" 2>/dev/null || true)"
  if [ -n "$state" ]; then
    printf '%s\n' "$state"
    return 0
  fi
  state="$(shot_state)"
  forgot="$(cat "$WORK/devices-forgot" 2>/dev/null || true)"
  if [ -n "$forgot" ] && [ "$(mtime_of "$1")" -le "$forgot" ]; then
    printf '%s\tnamed\n' "$(cut -f1-2 <<<"$state")"
  else
    printf '%s\n' "$state"
  fi
}

# register_shot <file> [<source image>]: one of the script's crops, with the style, the wallpaper
# and the remembered devices it shows: those of the moment it was taken, or of its source's.
register_shot() {
  [ -s "$1" ] || return 0
  local state
  if [ -n "${2:-}" ]; then state="$(source_state "$2")"; else state="$(shot_state)"; fi
  mkdir -p "$WORK"
  printf '%s\t%s\n' "$(abs_path "$1")" "$state" >>"$PRODUCED"
  log_shot_state "$1" "$state"
}

# attach_allowed <image>: only the script's own crops (under shots/) are published, never a
# picture the size of the display (the Dock, the menu bar's extras, his desktop's file names, a
# banner, his other widgets).
attach_allowed() {
  local path line size screen
  path="$(abs_path "$1")"
  case "$path" in
    "$SHOTS"/*) ;;
    *) fail "only the script's own crops under shots/ are attached, not $1" ;;
  esac
  line="$(awk -F '\t' -v p="$path" '$1 == p { l = $0 } END { print l }' "$PRODUCED" 2>/dev/null || true)"
  [ -n "$line" ] || fail "$(basename "$1") isn't a crop the script made (a window, widget or rectangle shot, a crop): a full shot never leaves the Mac; crop it first ($SCRIPT crop ...)"
  # A remembered device shows by name in the sidebar: judged by the state the picture was taken in,
  # so restore gui (his own devices back) refuses only what is taken after it.
  [ "$(cut -f4 <<<"$line")" = none ] ||
    fail "$(basename "$1") was taken while BatteryPulse remembered an iPhone or iPad by name, which the sidebar shows: it is never attached"
  size="$(sips -g pixelWidth -g pixelHeight "$1" 2>/dev/null | awk '/pixelWidth/ { w = $2 } /pixelHeight/ { h = $2 } END { print w " " h }')"
  screen="$(ui_run screen 2>/dev/null | awk '{ split($0, f, " "); for (i in f) { if (f[i] ~ /^scale=/) s = substr(f[i], 7) }
    if (match($0, /main=[-0-9]+ [-0-9]+ [0-9]+ [0-9]+/)) { split(substr($0, RSTART + 5, RLENGTH - 5), m, " "); printf "%d %d %d %d", m[3], m[4], m[3] * s, m[4] * s } }' || true)"
  if [ -n "$screen" ] && [ -n "$size" ]; then
    case " $(awk '{ print $1 " " $2 }' <<<"$screen") | $(awk '{ print $3 " " $4 }' <<<"$screen") " in
      *" $size "*) fail "$(basename "$1") is the size of the display: a full-screen picture is never attached; crop it to BatteryPulse's window or widget" ;;
    esac
  fi
  return 0
}

# publish_sheet: the contact sheet of every attached image, in the report's order, for him to see
# with its summary before his yes to send (send --dry-run builds it).
publish_sheet() {
  local files
  rm -f "$WORK/publish-sheet.png"
  files="$(cut -f1 "$PUBLISH/captions.tsv" 2>/dev/null | sed "s|^|$PUBLISH/|" | tr '\n' ' ' || true)"
  if [ -z "$files" ]; then
    echo "no attached images: no contact sheet"
    return 0
  fi
  [ -x "$BIN/frames" ] || fail "the frame helper isn't built: no contact sheet of the attached images, so no send"
  # $files is split on purpose: one argument per image (their names have no spaces).
  # shellcheck disable=SC2086
  "$BIN/frames" sheet "$WORK/publish-sheet.png" $files >/dev/null
  echo "SHEET $WORK/publish-sheet.png: every attached image; open it for him with $SESSION.md's summary, then his $SESSION-send"
}

# The sheet shows what is attached now: newer than the last attach (true with nothing attached).
publish_sheet_fresh() {
  [ -s "$PUBLISH/captions.tsv" ] || return 0
  [ -f "$WORK/publish-sheet.png" ] && [ "$WORK/publish-sheet.png" -nt "$PUBLISH/captions.tsv" ]
}

# mtime_of <file>: its modification time; GNU stat's -f means another thing, so -c goes first.
mtime_of() { stat -c %Y "$1" 2>/dev/null || stat -f %m "$1" 2>/dev/null || echo 0; }

# epoch_stamp <epoch>: "YYYY-MM-DD HH:MM:SS", the local time pmset -g log and log show use.
epoch_stamp() { date -r "$1" '+%Y-%m-%d %H:%M:%S' 2>/dev/null || date -d "@$1" '+%Y-%m-%d %H:%M:%S'; }

epoch_hm() { date -r "$1" '+%H:%M' 2>/dev/null || date -d "@$1" '+%H:%M'; }

# <folder>/day-ended is newer than <folder>/<file>: his day-end came after it.
ended_after() { [ -f "$1/day-ended" ] && [ -f "$1/$2" ] && [ "$1/day-ended" -nt "$1/$2" ]; }

# Away: from `mark away` until `ready` (the GUI phase), and from `ready` until his day-end.
is_away() { [ -f "$WORK/away" ] && ! ended_after "$WORK" away; }

# sound <name>: a system sound, but none from `mark away` until his day-end.
sound() {
  if is_away; then return 0; fi
  afplay "/System/Library/Sounds/$1.aiff" >/dev/null 2>&1 || true
}

# cue <text>: a sound and a notification while he is there (the start); nothing once he is away.
cue() {
  if is_away; then return 0; fi
  sound Glass
  osascript -e 'on run argv' -e 'display notification (item 1 of argv) with title "BatteryPulse Session R"' \
    -e 'end run' "$1" >/dev/null 2>&1 || true
}

ancestor_pids() {
  local pid=$$ parent
  while [ "$pid" -gt 1 ] 2>/dev/null; do
    echo "$pid"
    parent="$(ps -o ppid= -p "$pid" 2>/dev/null | tr -d ' ' || true)"
    if [ -z "$parent" ] || [ "$parent" = "$pid" ]; then break; fi
    pid="$parent"
  done
}

# proc_start <pid>: when the process started, in seconds since 1970 (ui compares the same,
# pbi_start_tvsec): arm.pid holds it beside the pid, so a later process that got
# the same pid (after a reboot or a kill) isn't taken for the arm window.
proc_start() {
  local started
  started="$(LC_ALL=C ps -o lstart= -p "$1" 2>/dev/null | tr -s ' ' | sed 's/^ //; s/ $//' || true)"
  [ -n "$started" ] || return 0
  if [ "$(uname -s)" = Darwin ]; then
    started="$(LC_ALL=C date -j -f '%a %b %d %T %Y' "$started" +%s 2>/dev/null || true)"
  else
    started="$(date -d "$started" +%s 2>/dev/null || true)"
  fi
  case "$started" in "" | *[!0-9]*) return 0 ;; esac
  echo "$started"
}

# arm_of <file>: the arm window's "<pid> <start>", the first two fields of arm.pid.
arm_of() { awk 'NR == 1 { print $1, $2 }' "$1" 2>/dev/null || true; }

# arm_runs <pid> <start>: that process runs, and started then.
arm_runs() { [ -n "$1" ] && [ -n "$2" ] && [ "$(proc_start "$1")" = "$2" ]; }

# arm_is_ancestor <file>: the arm window that file records is this call's ancestor. The list is
# read whole first: piped into grep -q under pipefail, ancestor_pids's next echo after a match gets
# SIGPIPE (status 141), so the arm would be found only as the chain's last pid.
arm_is_ancestor() {
  local pid="" start=""
  read -r pid start <<<"$(arm_of "$1")" || true
  [ -n "$pid" ] && grep -qx -- "$pid" <<<"$(ancestor_pids)" && arm_runs "$pid" "$start"
}

# caller_is_arm: the arm window's process (arm.pid) is this call's ancestor.
caller_is_arm() { arm_is_ancestor "$WORK/arm.pid"; }

# r_fence: once `ready` is up (the logged day), no command acts until his day-end (§6.2, R2: the
# session ends its turn at `ready`); a day-end counts only when it is newer than ready. `ui`
# enforces the same for itself, and day_fence for every run of this script.
r_fence() {
  if [ -f "$READY_FILE" ] && ! ended_after "$WORK" ready && ! caller_is_arm; then
    fail "ready is up: the logged day runs, and nothing acts until his day-end; nothing was done"
  fi
  day_fence
}

# The arm window of ~/bp-080/R (arm.pid) is this call's ancestor.
caller_is_r_arm() { arm_is_ancestor "$R_HOME/arm.pid"; }

# day_fence: Session R's fence for every run of this script, wherever it runs from (a short
# session's worktree, his checkout): ~/bp-080/R's ready without a newer day-ended stops every acting
# command but the arm's own and day-end.
day_fence() {
  if [ -f "$R_HOME/ready" ] && ! ended_after "$R_HOME" ready && ! caller_is_r_arm; then
    fail "Session R's logged day runs ($R_HOME/ready): nothing acts until his day-end; nothing was done"
  fi
  return 0
}

# back_epoch: when he said he is back at the Mac (R-back, HH:MM), as an epoch after prepare; else 4
# hours after prepare. A daytime session works: it is only when he is back (Session B, lesson 6).
back_epoch() {
  local start hm day epoch
  start="$(cat "$WORK/prepare.epoch" 2>/dev/null || date +%s)"
  hm="$(answer_of R-back)"
  case "$hm" in
    [0-9]:[0-5][0-9] | [01][0-9]:[0-5][0-9] | 2[0-3]:[0-5][0-9])
      day="$(date -r "$start" '+%Y-%m-%d' 2>/dev/null || date '+%Y-%m-%d')"
      epoch="$(date -j -f '%Y-%m-%d %H:%M' "$day $hm" +%s 2>/dev/null || echo "")"
      if [ -z "$epoch" ]; then
        echo $((start + 4 * 3600))
        return 0
      fi
      if [ "$epoch" -le "$start" ]; then epoch=$((epoch + 86400)); fi
      echo "$epoch"
      ;;
    *) echo $((start + 4 * 3600)) ;;
  esac
}

# The GUI phase stops 10 minutes before he is back, and at most 4 hours after `mark away` (§6.2).
gui_end_epoch() {
  local start back cap
  start="$(mtime_of "$WORK/away" 2>/dev/null)"
  [ "${start:-0}" -gt 0 ] || start="$(cat "$WORK/prepare.epoch" 2>/dev/null || date +%s)"
  back="$(back_epoch)"
  cap=$((start + 4 * 3600))
  if [ $((back - 600)) -lt "$cap" ]; then cap=$((back - 600)); fi
  echo "$cap"
}

gui_minutes_left() {
  local left
  left=$(($(gui_end_epoch) - $(date +%s)))
  if [ "$left" -lt 0 ]; then left=0; fi
  echo $((left / 60))
}

# heartbeat [<step and expected ready time>]: touched by every Session R call; with text, the
# state the arm window shows.
step_heartbeat() {
  r_only heartbeat
  if [ $# -gt 0 ]; then
    english_only "$*"
    printf '%s\t%s\n' "$(clock)" "$*" >"$WORK/state"
  fi
  echo "heartbeat $(clock); GUI phase: $(gui_minutes_left) minutes left (it stops at $(epoch_hm "$(gui_end_epoch)"))"
}

# other_calls: the pids of the other script calls running now (not the arm window, not
# a wait). A call's heartbeat keeper carries its arguments and outlives it by at most a minute. The
# pattern's backslash keeps this awk's own arguments from matching it.
other_calls() {
  ps -A -o pid= -o args= 2>/dev/null | awk -v me="$$" '
    $1 != me && match($0, /m5-session\.sh [a-z]/) {
      split(substr($0, RSTART + 14), w, " ")
      if (w[1] != "arm" && w[1] != "wait") print $1
    }' || true
}

# wait [<minutes>] (1-9, 5 by default): the session's wait on its background task (prepare, a
# long step, the charge limit's unplug, the weak adapter's load), in the foreground under the start
# line's one allow rule, which no sleep of the session's own passes. It ends within a minute of the
# task's end (no other script call runs), or after that many minutes, then prints the status. Like
# every call it touches the heartbeat and keeps the script's own while it waits, so waiting never
# looks like a stall (Session B's first attempt ended its turn instead, and looked stalled).
step_wait() {
  local minutes="${1:-5}" until others=""
  case "$minutes" in [1-9]) ;; *) fail "usage: $SCRIPT wait [<minutes, 1-9>]" ;; esac
  until=$(($(date +%s) + minutes * 60))
  while :; do
    others="$(other_calls)"
    [ -n "$others" ] || break
    [ "$(date +%s)" -lt "$until" ] || break
    sleep 15
  done
  if [ -n "$others" ]; then
    echo "wait: $minutes minutes passed and another script call still runs (pid $(tr '\n' ' ' <<<"$others" | sed 's/ $//')): read the task's output, then $SCRIPT wait again"
  else
    echo "wait: no other script call runs: the background task has ended; read its output"
  fi
  step_status
}

# heartbeat_keeper: the script's own heartbeat while this call runs: heartbeat.script touched every
# minute until the call ends (cleanup ends it too), so an install or a long step never looks like a
# stall to the arm window. At most 45 minutes, longer than any step takes, so a hung call still
# lets the arm's stale path start the logged day. Its output goes nowhere, so the Bash tool doesn't
# wait for it.
heartbeat_keeper() {
  local until=$(($(date +%s) + 2700))
  (
    while kill -0 "$$" 2>/dev/null && [ "$(date +%s)" -lt "$until" ]; do
      touch "$SCRIPT_HEARTBEAT" 2>/dev/null || true
      sleep 60
    done
  ) </dev/null >/dev/null 2>&1 &
  BACKGROUND="$BACKGROUND $!"
}

# heartbeat_age: seconds since the newer of the session's heartbeat and the script's own.
heartbeat_age() {
  local newest=0 file at
  for file in "$HEARTBEAT" "$SCRIPT_HEARTBEAT"; do
    [ -f "$file" ] || continue
    at="$(mtime_of "$file")"
    if [ "$at" -gt "$newest" ]; then newest="$at"; fi
  done
  echo $(($(date +%s) - newest))
}

# record_change <setting> <original> <new>: one line of changes.tsv, written before the change.
record_change() {
  mkdir -p "$WORK"
  printf '%s\t%s\t%s\t%s\n' "$1" "$(printf '%s' "$2" | tr '\t\n' '  ')" "$(printf '%s' "$3" | tr '\t\n' '  ')" \
    "$(clock)" >>"$CHANGES"
}

# change <setting> <original> <new...>: the session's own record before a change it makes by
# computer use or AX (restore works from this file, not from the session's context). A setting
# whose original is unknown is never changed.
step_change() {
  [ $# -ge 3 ] || fail "usage: $SCRIPT change <setting> <original> <new>"
  local setting="$1" original="$2"
  shift 2
  case "$setting" in *[!A-Za-z0-9._-]*) fail "a setting's name is letters, digits, dots, dashes and underscores" ;; esac
  case "$original" in "" | unknown | -) fail "never changed: the original of $setting is unknown, so the step that needs it is not checked" ;; esac
  english_only "$original $*"
  record_change "$setting" "$original" "$*"
  echo "recorded: $setting $original -> $*"
}

original_of() {
  [ -f "$CHANGES" ] || return 0
  awk -F '\t' -v s="$1" '$1 == s { print $2; exit }' "$CHANGES"
}

changed_settings() {
  [ -f "$CHANGES" ] || return 0
  awk -F '\t' '!seen[$1]++ { print $1 }' "$CHANGES"
}

# restored <setting> [how]: the session put it back and confirmed it with a read or a shot.
step_restored() {
  [ $# -ge 1 ] || fail "usage: $SCRIPT restored <setting> [how it was confirmed]"
  [ "$1" != desktop-widgets ] ||
    fail "desktop-widgets comes back only by the app's counts, never on the session's word: remove the widgets the session added, then $SCRIPT widgets-check"
  english_only "$*"
  printf '%s\t%s\t%s\n' "$1" "$(clock)" "$(shift && printf '%s' "$*" | tr '\t\n' '  ')" >>"$RESTORED"
  echo "restored: $1"
}

# is_restored <setting>: put back after its last change.
is_restored() {
  local changed restored
  changed="$(awk -F '\t' -v s="$1" '$1 == s { t = $4 } END { print t }' "$CHANGES" 2>/dev/null || true)"
  restored="$(awk -F '\t' -v s="$1" '$1 == s { t = $2 } END { print t }' "$RESTORED" 2>/dev/null || true)"
  [ -n "$restored" ] && [ ! "$restored" \< "$changed" ]
}

mark_restored() { printf '%s\t%s\t%s\n' "$1" "$(clock)" "$2" >>"$RESTORED"; }

# The extension's AppleLanguages as one language per line ("" when it has none).
widget_languages_of() { tr -d '(),"' <"$1" | tr -s ' \n\t' '\n' | grep . || true; }

# put_widget_languages_back: the widget extension's AppleLanguages as prepare found it: his own
# list from the backup again (never just deleted), else none. Succeeds only when a read confirms it.
put_widget_languages_back() {
  local items now="$WORK/widget-languages-now"
  if [ -f "$BACKUP/widget-languages" ]; then
    items="$(widget_languages_of "$BACKUP/widget-languages")"
    [ -n "$items" ] || return 1
    # One argument per language: a language code has no spaces.
    # shellcheck disable=SC2086
    defaults write "$WIDGET_PREFS" AppleLanguages -array $items || return 1
    defaults read "$WIDGET_PREFS" AppleLanguages >"$now" 2>/dev/null || return 1
    [ "$(widget_languages_of "$now")" = "$items" ] || return 1
  else
    defaults delete "$WIDGET_PREFS" AppleLanguages 2>/dev/null || true
    if defaults read "$WIDGET_PREFS" AppleLanguages >/dev/null 2>&1; then return 1; fi
  fi
  end_widget_extension
}

# A step that couldn't run: "not checked" or "not run" with its reason, and the session goes on.
not_checked() {
  local id="$1"
  shift
  printf '%s\t%s\t%s\n' "$(date '+%H:%M')" "$id" "$*" >>"$WORK/not-checked.tsv"
  echo "NOT CHECKED $id: $*"
}

# MARK: - Measurements paired with judgments

# measure <id> <kind> <arguments>: the script's half of a judgment, stored for `judge`:
#   blank <image> [x y w h]       luma's spread: 2 (blank or grey) below 0.02, else "!2" (anything
#                                 but blank: the spread can't tell right from gone or different)
#   same <image> <image> [x y w h] identical pixels: y, else n
#   differs <image> <image> [x y w h] more than 1 % of the pixels changed: y, else n
#   contrast <image> [x y w h]    the text contrast estimate (frames contrast): n below 3:1, else
#                                 "-" (the session judges readability; the number stands beside it)
# The suggestion is "-" where the numbers sit between the thresholds.
step_measure() {
  [ $# -ge 3 ] || fail "usage: $SCRIPT measure <id> blank|same|differs|contrast <arguments>"
  [ -x "$BIN/frames" ] || fail "the frame helper isn't built (see $BIN/frames.log)"
  local id="$1" kind="$2" line suggestion="-" value
  shift 2
  question "$id" >/dev/null || fail "no question $id"
  case "$kind" in
    blank)
      line="$("$BIN/frames" stats "$@")"
      value="$line"
      suggestion="$(echo "$line" | sed -n 's/.*stddev=\([0-9.]*\).*/\1/p' | awk '{ if ($1 < 0.02) print 2; else print "!2" }')"
      ;;
    same | differs)
      line="$("$BIN/frames" diff "$@")"
      value="$line"
      if [ "$kind" = same ]; then
        case "$line" in *"identical=yes"*) suggestion=y ;; *) suggestion=n ;; esac
      else
        suggestion="$(echo "$line" | sed -n 's/.*changed_pct=\([0-9.]*\).*/\1/p' | awk '{ if ($1 > 1) print "y"; else print "n" }')"
      fi
      ;;
    contrast)
      line="$("$BIN/frames" contrast "$@")"
      value="$line"
      suggestion="$(echo "$line" | sed -n 's/.*contrast_ratio=\([0-9.]*\).*/\1/p' | awk '{ if ($1 != "" && $1 + 0 < 3) print "n"; else print "-" }')"
      ;;
    *) fail "a measure is blank, same, differs or contrast" ;;
  esac
  mkdir -p "$WORK"
  touch "$MEASURES"
  awk -F '\t' -v id="$id" '$1 != id' "$MEASURES" >"$MEASURES.tmp"
  mv "$MEASURES.tmp" "$MEASURES"
  printf '%s\t%s\t%s\t%s\t%s\n' "$id" "$kind" "${suggestion:--}" "$(printf '%s' "$value" | tr '\t\n' '  ' | public)" \
    "$(printf '%s' "$*" | public)" >>"$MEASURES"
  echo "measured $id: $value; suggests ${suggestion:--}"
}

# measure_of <id> <column>: 3 the suggestion, 4 the numbers, 5 the evidence's paths.
measure_of() {
  [ -f "$MEASURES" ] || return 0
  awk -F '\t' -v id="$1" -v want="$2" '$1 == id { print $want }' "$MEASURES"
}

# judge <id> <answer> [--unsure] [note...]: Claude's reading of the picture, paired with the
# script's measurement. When the two disagree, or Claude is unsure, the answer is 3 (for a yes/no
# or two-way question, "unsure") with the note, and the item joins his batch.
step_judge() {
  [ $# -ge 2 ] || fail "usage: $SCRIPT judge <id> <answer> [--unsure] [note...]"
  local id="$1" value="$2" read="$2" unsure="" suggestion spec kind note
  shift 2
  if [ "${1:-}" = --unsure ]; then
    unsure=1
    shift
  fi
  note="$*"
  spec="$(question "$id")" || fail "no question $id"
  kind="${spec%%|*}"
  suggestion="$(measure_of "$id" 3)"
  # "!X" suggests anything but X; another suggestion is the answer itself.
  if [ -n "$suggestion" ] && [ "$suggestion" != "-" ] &&
    { [ "$suggestion" = "!$value" ] || { [ "${suggestion#!}" = "$suggestion" ] && [ "$suggestion" != "$value" ]; }; }; then
    unsure=1
    note="disagrees with the pixels ($(measure_of "$id" 4); they suggest $(if [ "${suggestion#!}" != "$suggestion" ]; then echo "anything but ${suggestion#!}"; else echo "$suggestion"; fi))${note:+; $note}"
  fi
  if [ -n "$unsure" ]; then
    printf '%s\t%s\t%s\t%s\n' "$id" "$value" "$(printf '%s' "$note" | tr '\t\n' '  ')" "$(measure_of "$id" 5)" >>"$BATCH"
    # 3 where the scale's 3 is "something else (note)"; elsewhere (y/n, 1-2, a widget's "3 gone")
    # "unsure".
    case "$spec" in
      *"3 something else"*) value=3 ;;
      *) value=unsure ;;
    esac
    note="for his batch: claude read $read${note:+; $note}"
  fi
  step_answer --by claude "$id" "$value" "$note"
}

# batch: his batch at the day's end (or a short session's end): every item the session answered 3
# or unsure, each with its evidence.
step_batch() {
  local id
  echo "His batch (optional: each item he skips keeps its gate's default):"
  if [ -s "$BATCH" ]; then
    echo "Items the session answered 3 or unsure (look at each crop, then answer):"
    while IFS=$'\t' read -r id _ note crop; do
      ask "$id"
      echo "  note: $note"
      [ -z "$crop" ] || echo "  evidence: $crop"
    done <"$BATCH"
  fi
}


# MARK: - The hands (ui), the windows and the shots

# ui <command...>: the ui helper. It reads what preflight and the session recorded from the
# session's folder itself (the one above its bin/), never from the environment: the tap (ui-tap,
# P6), the widget hosts (ui-hosts, P1), the System Settings panes it may act in (ui-panes, P8), the
# widgets' frames (widgets.tsv, `widget`) and the apps the script opened (launched.tsv). Every
# action passes its own safety rules, the fences among them.
ui_run() {
  if [ ! -x "$BIN/ui" ]; then
    warn "the ui helper isn't built (see $BIN/ui.log)"
    return 1
  fi
  "$BIN/ui" "$@"
}

# The main window's CGWindowID, from CGWindowList (no AX), for a click's --window.
main_window_id() { line_id "$(main_window_line)"; }

# ui_click_main <x> <y> [options...]: a click aimed at BatteryPulse's main window, by its ID.
ui_click_main() {
  local x="$1" y="$2" id
  shift 2
  id="$(main_window_id)"
  [ -n "$id" ] || {
    echo "the main window isn't on screen" >&2
    return 1
  }
  ui_run click "$x" "$y" --expect BatteryPulse --window "$id" "$@"
}

step_ui() {
  ui_run "$@"
}

# launch_r [arguments...]: the installed app without its saved windows, in the session's language
# (ui_lang: English for the GUI phase's AX labels, Russian after `app-language ru`; a launch
# argument only, no setting changes). The language step and the logged day launch it without the
# argument (launch_plain).
launch_r() {
  open "$APP" --args -ApplePersistenceIgnoreState YES -AppleLanguages "($(ui_lang))" "$@"
  wait_for_app
}

# launch_plain: the installed app in the language his settings give it.
launch_plain() {
  open "$APP" --args -ApplePersistenceIgnoreState YES
  wait_for_app
}

wait_for_app() {
  local tries=0
  until app_running || [ "$tries" -ge 40 ]; do
    sleep 0.25
    tries=$((tries + 1))
  done
  app_running || warn "BatteryPulse didn't start within 10 s"
  sleep 2
}

relaunch_r() {
  quit_app
  session_settings
  launch_r
}

# open_main: the main window by a reopen event (applicationShouldHandleReopen shows it), with no
# AX call into the app, so the queue may use it.
open_main() {
  open "$APP"
  sleep 3
}

# main_window_line [<app allowed to cover it>]: CGWindowList's check of the main window (ui
# windows --main): "main window <id> at <x y w h>: ok" or what is wrong.
main_window_line() {
  if [ -n "${1:-}" ]; then
    ui_run windows --main --allow-cover "$1" 2>/dev/null || true
  else
    ui_run windows --main 2>/dev/null || true
  fi
}

line_id() { sed -n 's/^main window \([0-9][0-9]*\) at .*/\1/p' <<<"$1"; }

line_rect() { sed -n 's/^main window [0-9][0-9]* at \(-*[0-9][0-9]* -*[0-9][0-9]* [0-9][0-9]* [0-9][0-9]*\):.*/\1/p' <<<"$1"; }

line_ok() { case "$1" in *": ok") return 0 ;; *) return 1 ;; esac }

# window_shot <file> [<app allowed to cover>]: the main window after the occlusion check, by
# -R <frame> (0.6.2's P3: -l leaves out what lies behind a glass sheet).
window_shot() {
  local file="$1" line rect
  line="$(main_window_line "${2:-}")"
  if ! line_ok "$line"; then
    echo "the main window isn't clear: ${line:-not on screen}" >&2
    return 1
  fi
  rect="$(line_rect "$line")"
  mkdir -p "$(dirname "$file")"
  screencapture -x -R"$(tr ' ' ',' <<<"$rect")" "$file"
  [ -s "$file" ] || {
    echo "screencapture wrote nothing" >&2
    return 1
  }
  register_shot "$file"
  echo "SHOT $file (main window $rect)"
}

# rect_shot <file> <x y w h>: a rectangle of the screen, in points.
rect_shot() {
  mkdir -p "$(dirname "$1")"
  if [ -n "$2" ] && screencapture -x -R"$(tr ' ' ',' <<<"$2")" "$1" && [ -s "$1" ]; then
    register_shot "$1"
    echo "SHOT $1 ($2)"
  else
    echo "no shot of ${2:-an unknown rectangle} into $1" >&2
    return 1
  fi
}

# pane <name>: a System Settings pane by its URL (proof P8), with no Apple Event.
pane_url() {
  case "$1" in
    appearance) echo "x-apple.systempreferences:com.apple.Appearance-Settings.extension" ;;
    desktop) echo "x-apple.systempreferences:com.apple.Desktop-Settings.extension" ;;
    displays) echo "x-apple.systempreferences:com.apple.Displays-Settings.extension" ;;
    accessibility) echo "x-apple.systempreferences:com.apple.Accessibility-Settings.extension" ;;
    login-items) echo "x-apple.systempreferences:com.apple.LoginItems-Settings.extension" ;;
    battery) echo "x-apple.systempreferences:com.apple.Battery-Settings.extension" ;;
    date-time) echo "x-apple.systempreferences:com.apple.Date-Time-Settings.extension" ;;
    wallpaper) echo "x-apple.systempreferences:com.apple.Wallpaper-Settings.extension" ;;
    bluetooth) echo "x-apple.systempreferences:com.apple.BluetoothSettings" ;;
    *) return 1 ;;
  esac
}

# The panes proof P8 checks. Session B found appearance, desktop and displays opening the wrong pane
# on macOS 27.2: computer use opens those from the sidebar (P8's fallback).
PANES="appearance desktop displays accessibility login-items battery date-time wallpaper bluetooth"

step_pane() {
  local url
  url="$(pane_url "${1:-}")" || fail "usage: $SCRIPT pane <$(echo "$PANES" | tr ' ' '|')>"
  track_launch "System Settings" open "$url"
  sleep 2
  # The sidebar's selection and the title; ui acts only in a pane P8 confirmed.
  ui_run pane-state --expect "$1" || true
}

# widget <name> <x> <y> <w> <h> | widget <name> none: a placed widget's frame in points (from proof
# P1's `ui hit`, or `ui frame --widgets`), for the crops, the clicks, ui's window-list rule and
# `tree --inside`; none forgets it once the session removed that widget (step 3's batches), so no
# crop shows the bare desktop in its place. AX can't move widgets, so their frames come from here.
# The names: small, medium and large for the Battery kind; accessories-, history- and devices-
# with their families. A frame is recorded only when it is no larger than its family's widget (one
# in pixels is twice as large) and `ui hit` finds a widget host's element labelled BatteryPulse at
# its centre. The first History widget's time is kept for `feed history`.
step_widget() {
  local usage limit number hit bundle
  usage="usage: $SCRIPT widget <$(tr ' ' '|' <<<"$WIDGET_NAMES")> <x> <y> <w> <h> | widget <name> none"
  case " $WIDGET_NAMES " in *" ${1:-none} "*) ;; *) fail "a widget is one of: $WIDGET_NAMES" ;; esac
  if [ $# -eq 2 ] && [ "$2" = none ]; then
    touch "$WORK/widgets.tsv"
    awk -F '\t' -v f="$1" '$1 != f' "$WORK/widgets.tsv" >"$WORK/widgets.tmp"
    mv "$WORK/widgets.tmp" "$WORK/widgets.tsv"
    echo "widget $1 forgotten (removed from the desktop)"
    return 0
  fi
  [ $# -eq 5 ] || fail "$usage"
  # ui.swift's Rules.widgetLimits, in points, with room to spare, by the name's family.
  case "${1##*-}" in
    small) limit="220 220" ;;
    medium) limit="440 220" ;;
    large) limit="440 460" ;;
  esac
  for number in "$2" "$3" "$4" "$5"; do
    case "$number" in "" | *[!0-9.-]*) fail "a frame is four numbers in points: x y width height" ;; esac
  done
  awk -v w="$4" -v h="$5" -v l="$limit" 'BEGIN { split(l, m, " "); exit !(w >= 20 && h >= 20 && w <= m[1] && h <= m[2]) }' ||
    fail "a $1 widget is at most ${limit% *} x ${limit#* } points: $4 x $5 isn't one (pixels instead of points?); nothing recorded"
  hit="$(ui_run hit "$(awk -v x="$2" -v w="$4" 'BEGIN { printf "%d", x + w / 2 }')" \
    "$(awk -v y="$3" -v h="$5" 'BEGIN { printf "%d", y + h / 2 }')" 2>&1)" ||
    fail "ui hit at the frame's centre: $(head -1 <<<"$hit"); nothing recorded"
  bundle="$(sed -n 's/^process: .* (\(.*\), pid .*/\1/p' <<<"$hit" | head -1 || true)"
  case " com.apple.notificationcenterui com.apple.chronod $(tr '\n' ' ' <"$WORK/ui-hosts" 2>/dev/null || true) " in
    *" ${bundle:-none} "*) ;;
    *) fail "the frame's centre isn't a widget host's (${bundle:-unknown}): nothing recorded" ;;
  esac
  grep -q '^batterypulse_label: yes' <<<"$hit" ||
    fail "no element labelled BatteryPulse at the frame's centre: not a BatteryPulse widget, nothing recorded"
  touch "$WORK/widgets.tsv"
  awk -F '\t' -v f="$1" '$1 != f' "$WORK/widgets.tsv" >"$WORK/widgets.tmp"
  mv "$WORK/widgets.tmp" "$WORK/widgets.tsv"
  printf '%s\t%s %s %s %s\n' "$1" "$2" "$3" "$4" "$5" >>"$WORK/widgets.tsv"
  case "$1" in history-*) [ -f "$WORK/first-history.time" ] || clock >"$WORK/first-history.time" ;; esac
  echo "widget $1 at $2 $3 $4 $5"
}

widget_rect() { awk -F '\t' -v f="$1" '$1 == f { print $2 }' "$WORK/widgets.tsv" 2>/dev/null || true; }

# desktop-spot <x> <y> | --image <png> <x> <y>: an empty spot of the desktop, the fixed action
# before each widget comparison (Dim widgets reacts to the desktop's focus). ui checks it as every
# click there will be checked (--expect desktop): a desktop-level window of Finder, WindowManager
# or the wallpaper on top, no icon or control under AX, never the Dock or a Finder window.
step_desktop_spot() {
  local probe
  probe="$(ui_run click "$@" --expect desktop --probe 2>&1)" || fail "that point isn't the bare desktop: $probe"
  # <x> <y> in points, or --image <png> <x> <y>, which ui converts at every click.
  printf '%s --expect desktop\n' "$*" >"$WORK/desktop-spot.args"
  echo "desktop spot: $(cat "$WORK/desktop-spot.args")"
}

# reveal_on: WindowManager's revealed-desktop window (layer 18) is on screen: a click on the
# wallpaper pushed the windows aside (click-wallpaper-to-reveal-desktop, on by default), and it
# covers them until a click on the bare desktop ends it (Session B's notes, 12:37 and 13:13).
reveal_on() { ui_run windows 2>/dev/null | awk -F '\t' '$2 == "layer 18" && $3 == "WindowManager" { found = 1 } END { exit !found }'; }

# end_reveal: ends that state by one more click on the desktop spot (ui accepts the revealed
# desktop's window there), up to twice, checked by the window list; says so when it stays on.
end_reveal() {
  local tries=0
  while reveal_on; do
    if [ "$tries" -ge 2 ]; then
      echo "DO (session): the revealed desktop stays on (WindowManager, layer 18): end it with one computer-use click on bare desktop, then move the pointer to bare desktop" >&2
      return 1
    fi
    # shellcheck disable=SC2046
    ui_run click $(cat "$WORK/desktop-spot.args") >/dev/null 2>&1 || true
    sleep 1
    tries=$((tries + 1))
  done
  return 0
}

# click_desktop: the fixed action before a widget comparison (Dim widgets reacts to the desktop's
# focus): a click on the empty desktop spot, then 1 s; then the revealed desktop ended (Session B
# left it on, which covered the windows of the next step) and the pointer moved back to the spot,
# so nothing of the click stays on screen. Each click is refused unless the bare desktop is still
# what lies there.
click_desktop() {
  [ -f "$WORK/desktop-spot.args" ] || {
    warn "no desktop spot recorded (desktop-spot)"
    return 1
  }
  # The recorded arguments are split on purpose: <x> <y> or --image <png> <x> <y>, then
  # --expect desktop.
  # shellcheck disable=SC2046
  ui_run click $(cat "$WORK/desktop-spot.args") >/dev/null || return 1
  sleep 1
  ui_run windows >"$LOGS/windows-after-desktop-click.txt" 2>&1 || true
  end_reveal || true
  park_pointer
}

# park_pointer: the pointer on the desktop spot (a move, no click), so computer use's 28x40
# overlay at its last click and the pointer itself cover nothing the next check reads (Session B:
# the overlay failed the occlusion check until a move to bare desktop).
park_pointer() {
  [ -f "$WORK/desktop-spot.args" ] || return 0
  # shellcheck disable=SC2046
  ui_run move $(cat "$WORK/desktop-spot.args") >/dev/null 2>&1 || true
}

# place_window: BatteryPulse's front window on the right of the main display, below the banners'
# corner and above the Dock (SESSION-R.md, "Places"), by AX.
place_window() {
  local screen width height frame w h
  screen="$(ui_run screen 2>/dev/null || true)"
  width="$(sed -n 's/^main=[-0-9]* [-0-9]* \([0-9]*\) .*/\1/p' <<<"$screen")"
  height="$(sed -n 's/^main=[-0-9]* [-0-9]* [0-9]* \([0-9]*\) .*/\1/p' <<<"$screen")"
  frame="$(ui_run frame BatteryPulse 2>/dev/null || true)"
  w="$(awk '{ print $3 }' <<<"$frame")"
  h="$(awk '{ print $4 }' <<<"$frame")"
  [ -n "$width" ] && [ -n "$w" ] || return 0
  ui_run position BatteryPulse "$((width - w - 60))" "$(awk -v H="$height" -v h="$h" 'BEGIN { y = H - h - 110; if (y < 140) y = 140; print int(y) }')" \
    >/dev/null 2>&1 || true
}

# select_page <sidebar name>: by a click at the sidebar row's AX frame, else by AX selection.
select_page() {
  local frame
  frame="$(ui_run frame BatteryPulse --within AXOutline --match "$1" 2>/dev/null || true)"
  if [ -n "$frame" ]; then
    # shellcheck disable=SC2046
    ui_click_main $(awk '{ printf "%d %d", $1 + $3 / 2, $2 + $4 / 2 }' <<<"$frame") >/dev/null 2>&1 && return 0
  fi
  ui_run select-row BatteryPulse "$1" --within AXOutline >/dev/null 2>&1
}

# MARK: - The start (prepare attempt, prepare, prepare reads)

# attempt_head: the frozen worktree's commit, which names this attempt (~/bp-080/R/attempt, or the
# look shoot's ~/bp-080/L/attempt).
attempt_head() { git -C "$ROOT" rev-parse HEAD 2>/dev/null || echo unknown; }

# attempt_current: the session's folder is this attempt's (its attempt file names this commit).
attempt_current() { [ "$(cat "$WORK/attempt" 2>/dev/null || true)" = "$(attempt_head)" ]; }

# attempt_fence: every acting call but `prepare attempt` needs this attempt's folder, so nothing is
# written into an earlier attempt's files (off the Mac, dry runs pass).
attempt_fence() {
  [ "$(uname -s)" = Darwin ] || return 0
  attempt_current && return 0
  fail "$WORK isn't this attempt's yet (no attempt file for $(attempt_head | cut -c1-7)): $SCRIPT prepare attempt first, the start's first call; nothing was done"
}

# prepare attempt [--kept <setting>[,...]] [--restored <setting>[,...] "<how>"] (the start's first
# call, right after the worktree): a clean start. A session folder that holds an earlier attempt's
# files (no attempt file, or another commit's) moves aside to ~/bp-080/<session>-attempt-<that
# attempt's date>, never deleted, once no arm window of that attempt runs and every change its
# changes.tsv lists was put back (restored.tsv). Until then attempt_fence refuses `restored`, so the
# two options record it here: --restored, the session put a setting back at the new start and
# confirmed it (how: the shot); --kept, his word that he keeps a setting as that attempt left it.
# That attempt's fence (ready) goes with it, so this runs before it. Its worktree, which the start
# moved to run-<commit>, goes along, and git is told where it went. Nothing is written to the
# attempt file unless everything moved.
step_attempt() {
  local head old file pid start setting missing="" epoch when dest n=1 entry last how left usage way
  usage="usage: $SCRIPT prepare attempt [--kept <setting>[,<setting>...]] [--restored <setting>[,<setting>...] \"<how it was confirmed>\"]"
  head="$(attempt_head)"
  mkdir -p "$WORK"
  if attempt_current; then
    echo "attempt: $WORK is this attempt's (${head:0:7}); nothing moves"
    return 0
  fi
  old="$(find "$WORK" -mindepth 1 -maxdepth 1 ! -name run ! -name 'run-*' 2>/dev/null | head -1 || true)"
  if [ -n "$old" ]; then
    for file in "$WORK/arm.pid"; do
      pid=""
      start=""
      read -r pid start <<<"$(arm_of "$file")" || true
      if arm_runs "$pid" "$start"; then
        fail "an earlier attempt's arm window still runs (pid $pid): he closes that Terminal window first; nothing moved"
      fi
    done
    while [ $# -gt 0 ]; do
      case "$1" in
        --kept)
          [ -n "${2:-}" ] || fail "$usage"
          for setting in $(tr ',' ' ' <<<"$2"); do
            changed_settings | grep -qx -- "$setting" || fail "$setting isn't in the earlier attempt's changes.tsv; nothing moved"
            is_restored "$setting" || mark_restored "$setting" "kept by him as the earlier attempt left it (his word at the new start)"
          done
          shift 2
          ;;
        --restored)
          [ -n "${2:-}" ] && [ -n "${3:-}" ] || fail "$usage"
          english_only "$3"
          how="$(printf '%s' "$3" | tr '\t\n' '  ')"
          for setting in $(tr ',' ' ' <<<"$2"); do
            changed_settings | grep -qx -- "$setting" || fail "$setting isn't in the earlier attempt's changes.tsv; nothing moved"
            [ "$setting" != desktop-widgets ] ||
              fail "desktop-widgets comes back only by the app's counts, never on the session's word: --kept desktop-widgets on his word that the widgets are as he wants them; nothing moved"
            is_restored "$setting" || mark_restored "$setting" "put back by the session at the new start: $how"
          done
          shift 3
          ;;
        *) fail "$usage" ;;
      esac
    done
    for setting in $(changed_settings); do
      is_restored "$setting" && continue
      last="$(awk -F '\t' -v s="$setting" '$1 == s { v = $3 } END { print v }' "$CHANGES")"
      way="$(restore_how "$setting")"
      # The earlier attempt's script put these back; at the new start only his word keeps them.
      [ "$way" != script ] || way="the earlier attempt's script; now only his word: --kept, or --restored if he says it was put back by hand"
      missing="$missing
- $setting: $(original_of "$setting") -> $last (the way back: $way)"
    done
    if [ -n "$missing" ]; then
      echo "NOT PUT BACK by the earlier attempt ($CHANGES; restored.tsv has no later line):$missing"
      fail "an earlier attempt's changes aren't all put back: tell him which. One with a GUI way back: put it back by computer use, confirm it with a shot, then $SCRIPT prepare attempt --restored <setting>[,<setting>...] \"<the shot>\". One he says was put back by hand already: --restored <setting> \"his word: <what he said>\". One he keeps as it is (his word): $SCRIPT prepare attempt --kept <setting>[,<setting>...]. Both options may go in one call; nothing moved"
    fi
    epoch="$(cat "$WORK/prepare.epoch" 2>/dev/null || mtime_of "$old")"
    when="$(date -r "$epoch" '+%Y-%m-%d' 2>/dev/null || date -d "@$epoch" '+%Y-%m-%d')"
    dest="$ACCOUNT_HOME/bp-080/$SESSION-attempt-$when"
    while [ -e "$dest" ]; do
      n=$((n + 1))
      dest="$ACCOUNT_HOME/bp-080/$SESSION-attempt-$when-$n"
    done
    mkdir -p "$dest"
    # A directory moves to another parent only when it is writable (its .. entry changes).
    chmod -R u+w "$WORK/bin" 2>/dev/null || true
    while IFS= read -r entry; do
      mv "$entry" "$dest/" || warn "$entry couldn't move to $dest"
    done < <(find "$WORK" -mindepth 1 -maxdepth 1 ! -name run)
    left="$(find "$WORK" -mindepth 1 -maxdepth 1 ! -name run 2>/dev/null | head -1 || true)"
    # A part that stayed would be taken for this attempt's (prepare keeps an existing backup).
    [ -z "$left" ] || fail "$left couldn't move to $dest: no attempt file was written; tell him, and move nothing by hand"
    for entry in "$dest"/run-*; do
      [ -d "$entry" ] || continue
      git -C "$ROOT" worktree repair "$entry" >/dev/null 2>&1 || warn "git worktree repair $entry failed: that copy stays as an archive"
    done
    echo "the earlier attempt moved aside to $dest (nothing deleted)"
  fi
  echo "$head" >"$WORK/attempt"
  echo "attempt: a fresh start at ${head:0:7} in $WORK"
}


# prepare_start <session's yes> [--fresh-backup]: what Session R8's and the look shoot's prepare
# share: the tools checked, his yes, the backup, the session's times, leftovers stopped.
prepare_start() {
  check_tools
  [ "$(answer_of "$1")" = y ] || fail "first his one yes to the list of changes: $SCRIPT answer --by person $1 y"
  # Once the session has changed his app and data, a fresh backup would keep the session's state
  # (the RC, no remembered devices) as his.
  if [ "${2:-}" = --fresh-backup ] && [ -n "$(original_of app)" ]; then
    fail "the session has changed his app and data already (changes.tsv): a fresh backup now would keep the session's state as his; nothing was done"
  fi
  mkdir -p "$WORK" "$BUILDS" "$BIN" "$SHOTS" "$LOGS" "$SECTIONS"
  touch "$CHANGES" "$HEARTBEAT"
  cd "$ROOT"
  backup "${2:-}"
  if [ ! -f "$WORK/prepare.time" ] || [ "${2:-}" = --fresh-backup ]; then
    clock >"$WORK/prepare.time"
    date +%s >"$WORK/prepare.epoch"
    touch "$WORK/prepare.marker"
  fi
  stop_leftovers
}

# prepare_report <title>: prepare's section: the Mac, his app, the backup, the builds.
prepare_report() {
  local name version build origin
  begin_section 00-prepare "$1"
  out "- prepared: $(cat "$WORK/prepare.time"); macOS $(sw_vers -productVersion) ($(sw_vers -buildVersion)); the frozen script at $(git -C "$ROOT" rev-parse --short HEAD 2>/dev/null || echo unknown)"
  out "- installed before the session: $(cat "$BACKUP/version")"
  out "- defaults domain: $(plutil -convert xml1 -o - "$BACKUP/defaults.plist" | grep -c '<key>' || true) keys backed up"
  if [ -d "$BACKUP/support" ]; then
    out "- Application Support: $(find "$BACKUP/support" -type f | wc -l | tr -d ' ') files, $(du -sk "$BACKUP/support" | cut -f1) KB backed up"
  fi
  out "- charge: $(battery_percent) %, $(if on_battery; then echo on battery; else echo on the adapter; fi)"
  out "- tools: ui $(if [ -x "$BIN/ui" ]; then echo built; else echo "not built"; fi), frames $(if [ -x "$BIN/frames" ]; then echo built; else echo "not built"; fi), bpulse $(if [ -x "$BIN/bpulse" ]; then echo built; else echo "not built"; fi)"
  out ""
  out "| Build | Version | CFBundleVersion | Source |"
  out "|---|---|---|---|"
  while IFS=$'\t' read -r name version build origin; do
    out "| $name | $version | $build | $origin |"
  done <"$WORK/builds.tsv"
  if [ -f "$BUILDS/F.none" ]; then out "- $(cat "$BUILDS/F.none")"; fi
}

# prepare_placed: the placed widgets as his own BatteryPulse counts them (T-1 item 7), read once,
# before the session changes anything: the counts restore end's are held against.
prepare_placed() {
  if [ -z "$(placed_of prepare)" ] && [ -z "$(original_of app)" ]; then placed_read prepare >/dev/null; fi
  out "- the placed widgets, as his BatteryPulse counts them (WidgetKit's answer, G7-17): $(placed_words "$(placed_of prepare)")"
}

# prepare_changes <what the app becomes>: changes.tsv's first lines, once, then his remembered
# iPhones and iPads out of sight: outside Demo Mode the sidebar's Devices section lists them by
# name, so every shot of the main window would show them. They stay in the backup, which restore
# gui (or restore end) puts back, and are gone until then.
prepare_changes() {
  if [ -z "$(original_of app)" ]; then
    record_change app "$(cat "$BACKUP/version")" "$1"
    record_change bp-settings "his settings (backup)" "the session's settings"
    record_change bp-support "his data (backup)" "the session's data"
    record_change widget-data "his (backup)" "the candidates' widget data"
  fi
  if [ -d "$SUPPORT/Devices" ]; then
    [ -d "$BACKUP/support/Devices" ] || fail "his remembered devices aren't in the backup ($BACKUP/support/Devices): nothing was removed"
    [ -n "$(original_of remembered-devices)" ] || record_change remembered-devices "his (backup)" "none during the GUI phase"
    quit_app
    rm -rf "$SUPPORT/Devices"
  fi
}

# prepare [--fresh-backup] (the start, a background task): the backup into ~/bp-080/R, the builds
# (start, U, F) and the tools (ui, frames, swap, perf-stats, bpulse), his remembered devices out of
# the session's sight, his own 0.7.x left in place (step 2 installs RC-U over it and his widgets
# placed under it) and relaunched with the session's settings, then a beep. Only after his yes to
# the list of changes (answer --by person R-yes y).
step_prepare_r() {
  prepare_start R-yes "${1:-}"
  fetch_builds_r
  build_tools
  prepare_report "Prepare (the start)"
  out "- he is back at: $(epoch_hm "$(back_epoch)") (the GUI phase stops 10 minutes before, at most 4 hours after mark away)"
  prepare_placed
  prepare_changes "the release candidates RC-U and RC-F (and v$START_VERSION for step 11c)"
  case "$(app_version)" in
    "$BASE_VERSION "*) out "- his $BASE_VERSION runs: step 2 installs RC-U over it" ;;
    *)
      if [ -s "$WORK/installed" ] && ! grep -q -E '^backup ' "$WORK/installed"; then
        out "- the session has begun ($(cut -d' ' -f1 "$WORK/installed") installed): prepare leaves $(app_version) as it is"
      else
        out "- $(app_version) runs, not $BASE_VERSION: step 2 installs RC-U over what runs (his comes back from the backup)"
      fi
      ;;
  esac
  relaunch_r
  sound Glass
  echo "BEEP (prepare is done): when he is back and has quit his own apps: $SCRIPT prepare reads"
}

# prepare [--fresh-backup] (the look shoot's start, a background task; PLAN.md §6.1 step 1): the
# backup into ~/bp-080/L, the look shoot's CI build L, the tools (ui, frames, swap, bpulse), his
# remembered devices out of sight, L installed the UpdateInstaller way over his 0.7.1 (which comes
# back at the end with his settings and data) and running with the session's settings, the display
# kept awake until restore end, then a beep. Only after his yes (L-yes).
step_prepare_l() {
  prepare_start L-yes "${1:-}"
  fetch_build_l
  build_tools
  prepare_report "Prepare (the look shoot's start)"
  out "- BatteryPulse's own languages (its AppleLanguages): $(if [ -f "$BACKUP/app-languages" ]; then tr -s ' \n' ' ' <"$BACKUP/app-languages"; else echo "none (the system's)"; fi)"
  case "$(cat "$BACKUP/version")" in
    "$BASE_VERSION "*) ;;
    *) warn "his BatteryPulse is $(cat "$BACKUP/version"), not $BASE_VERSION: the look shoot runs over it and puts it back the same" ;;
  esac
  prepare_placed
  prepare_changes "the look shoot's build L"
  install_build L --no-launch
  out "- L installed ($(app_version)) over his $(cat "$BACKUP/version")"
  relaunch_r
  awake_start
  sound Glass
  echo "BEEP (prepare is done): when he is back and has quit his own apps: $SCRIPT preflight"
}

# keyboard_navigation: System Settings → Keyboard → Keyboard navigation as AppleKeyboardUIMode
# holds it: on (2 or 3, the values macOS has written for it), off (0 or unset), else unknown
# [unverified on macOS 27: where the pane's shot disagrees, the shot decides].
keyboard_navigation() {
  local mode
  mode="$(defaults read -g AppleKeyboardUIMode 2>/dev/null || echo unset)"
  case "$mode" in
    2 | 3) echo on ;;
    0 | unset) echo off ;;
    *) echo unknown ;;
  esac
}

# prepare reads (the start): what SESSION-R.md's R0 reads, as 0.6.2's prepare did: the Charge
# Limit (pmset -g battlimit), the 24-hour setting, Open at login (AX), Check for updates and Window
# to open (his defaults), the languages (BatteryPulse's own, its widget extension's, the system's),
# the appearance, Keyboard navigation (AppleKeyboardUIMode, for step 4); Icon & widget style and Dim
# widgets on desktop by computer use from System Settings' sidebar (0.6.2's P8: their URLs open
# other panes), answered from its shot. A value it can't read is "unknown" and never changed. Then
# the desktop's shot and pluginkit, under his 0.7.1: his own widgets, one of which proof P1 needs.
# report/ is the folder step 10 saves Report a Problem's files into (report-check reads it).
step_prepare_reads() {
  begin_section 01-reads "Prepare's reads (the start)"
  local limit corner value screen keys
  mkdir -p "$WORK/report"
  pmset -g battlimit >"$LOGS/battlimit.txt" 2>&1 || true
  limit="$(battlimit_value "$LOGS/battlimit.txt")"
  if [ -n "$limit" ]; then
    step_answer --by claude prep-charge-limit "$limit" "read by pmset -g battlimit" >/dev/null
    out "- Charge Limit: $limit % (pmset -g battlimit, chargeSocLimitSoc)"
  elif on_battery; then
    out "- Charge Limit: pmset -g battlimit holds none on battery (it holds the limit only on the adapter): read from the Battery pane by computer use"
    ask prep-charge-limit
  else
    out "- Charge Limit: none set (pmset -g battlimit on the adapter: $(head -1 "$LOGS/battlimit.txt" | cut -c1-60))"
    step_answer --by claude prep-charge-limit 100 "none set: pmset -g battlimit on the adapter" >/dev/null
  fi
  out "- AppleICUForce24HourTime: $(cat "$BACKUP/24-hour")"
  value="$(keyboard_navigation)"
  if [ "$value" != unknown ]; then step_answer --by claude prep-keyboard-navigation "$value" "read by AppleKeyboardUIMode" >/dev/null; fi
  out "- Keyboard navigation (AppleKeyboardUIMode): $value$(if [ "$value" = unknown ]; then echo " (the Keyboard pane's shot answers prep-keyboard-navigation)"; fi)"
  out "- Check for updates (updateFrequency): $(setting_of updateFrequency)"
  out "- Window to open (prefersCompactWindow): $(setting_of prefersCompactWindow)"
  out "- BatteryPulse's own languages (its AppleLanguages): $(if [ -f "$BACKUP/app-languages" ]; then tr -s ' \n' ' ' <"$BACKUP/app-languages"; else echo "none (the system's)"; fi)"
  out "- the widget extension's languages: $(if [ -f "$BACKUP/widget-languages" ]; then tr -s ' \n' ' ' <"$BACKUP/widget-languages"; else echo "none (the system's)"; fi)"
  out "- the system's first language: $(defaults read -g AppleLanguages 2>/dev/null | tr -d ' \n()"' | cut -d, -f1 || echo unknown)"
  out "- appearance: dark mode $(cat "$BACKUP/dark-mode"), automatic $(cat "$BACKUP/auto-appearance"); the wallpaper: $(grep -c . "$BACKUP/wallpapers" 2>/dev/null || echo 0) desktops read (paths kept on the Mac)"
  # Candidates for the two style keys, kept on the Mac: the pane's shot decides.
  keys="$(defaults read -g 2>/dev/null | grep -i -E 'icon|widget|tint' | head -10 || true)"
  printf '%s\n' "$keys" >"$LOGS/style-keys.txt"
  defaults read com.apple.WindowManager 2>/dev/null | grep -i -E 'widget|dim' >>"$LOGS/style-keys.txt" || true
  out "- style-like keys (logs/style-keys.txt, on the Mac): $(grep -c . "$LOGS/style-keys.txt" || true); Icon & widget style and Dim widgets on desktop come from the panes' shots"
  value="$(defaults read com.apple.WindowManager EnableStandardClickToShowDesktop 2>/dev/null || echo "unset (on)")"
  out "- click-wallpaper-to-reveal-desktop (EnableStandardClickToShowDesktop): $value; the script ends the revealed desktop after each desktop click"
  out "- hot corners: $(for corner in tl tr bl br; do printf '%s=%s ' "$corner" "$(defaults read com.apple.dock "wvous-$corner-corner" 2>/dev/null || echo 0)"; done)"
  screen="$(ui_run screen 2>/dev/null || true)"
  out "- display: $(sed 's/ corners.*//' <<<"$screen")"
  # Open at login is SMAppService state, not a defaults key: read BatteryPulse's own toggle by AX.
  value=unknown
  if ui_run press BatteryPulse --menu-cmd , >/dev/null 2>&1; then
    sleep 2
    value="$(ui_run tree BatteryPulse --match "Open at login" 2>/dev/null | sed -n 's/.* value \([01]\) frame.*/\1/p' | head -1 || true)"
    close_front_window || true
  fi
  case "$value" in
    1) step_answer --by claude prep-open-at-login 1 "read by AX" >/dev/null ;;
    0) step_answer --by claude prep-open-at-login 2 "read by AX" >/dev/null ;;
    *) value=unknown ;;
  esac
  # No case statement inside $( ): bash 3.2 reads its pattern's ")" as the end of the substitution.
  if [ "$value" = 1 ]; then value=on; elif [ "$value" = 0 ]; then value=off; fi
  out "- Open at login (AX): $value$(if [ "$value" = unknown ]; then echo " (Session B read none: the session reads its Settings window by computer use and answers prep-open-at-login)"; fi)"
  value=0
  grep -q '"storeAssertionRecords" *: *\[ *{' "$HOME/Library/DoNotDisturb/DB/Assertions.json" 2>/dev/null || value=$?
  case "$value" in
    0) out "- Focus: on" ;;
    1) out "- Focus: off" ;;
    *) out "- Focus: not readable (his word at the start)" ;;
  esac
  pluginkit -mv -i "$WIDGET_ID" >"$LOGS/pluginkit-prepare.txt" 2>&1 || true
  out "- pluginkit:"
  out_block "$LOGS/pluginkit-prepare.txt"
  park_pointer
  shot prepare-desktop
  echo "DO (session): System Settings → Appearance and → Desktop & Dock by computer use from the sidebar (P8), one $SCRIPT shot each (settings-appearance, settings-desktop), then answer from them:"
  ask prep-widget-style prep-dim-widgets
  if [ -z "$(answer_of prep-open-at-login)" ]; then ask prep-open-at-login; fi
  if [ -z "$(answer_of prep-keyboard-navigation)" ]; then ask prep-keyboard-navigation; fi
  ask prep-widgets
  echo "Then proof P1 at one of his BatteryPulse widgets ($SCRIPT proof P1 --image <shot> <x> <y>; none: in step 2),"
  echo "an empty desktop spot ($SCRIPT desktop-spot --image <shot> <x> <y>), and: $SCRIPT preflight"
}

# prepare reads (the look shoot; PLAN.md §6.1 step 1): the Charge Limit (pmset -g battlimit on the
# adapter; at 100 % it shows none, as on battery, so the Battery pane's shot by computer use
# confirms it), BatteryPulse's own languages and the system's, his window style and beta styles,
# hasSeenWelcome, the appearance, and Demo Mode (never stored: off at every launch); report/, the
# folder the session saves Report a Problem's files into.
step_prepare_reads_l() {
  local limit
  begin_section 01-reads "Prepare's reads (the look shoot)"
  mkdir -p "$WORK/report"
  pmset -g battlimit >"$LOGS/battlimit.txt" 2>&1 || true
  limit="$(battlimit_value "$LOGS/battlimit.txt")"
  if [ -n "$limit" ]; then
    step_answer --by claude prep-charge-limit "$limit" "read by pmset -g battlimit" >/dev/null
    out "- Charge Limit: $limit % (pmset -g battlimit)"
  elif on_battery; then
    out "- Charge Limit: pmset -g battlimit holds none on battery: read from the Battery pane by computer use"
    ask prep-charge-limit
  else
    step_answer --by claude prep-charge-limit 100 "none set: pmset -g battlimit on the adapter; the Battery pane's shot confirms it" >/dev/null
    out "- Charge Limit: none set (pmset -g battlimit on the adapter: $(head -1 "$LOGS/battlimit.txt" | cut -c1-60)), so 100 %: the Battery pane's shot confirms it"
    echo "DO (session): System Settings → Battery → (i) next to Charging by computer use, a $SCRIPT shot settings-battery; if it shows another limit, $SCRIPT judge prep-charge-limit <n> \"<the shot>\""
  fi
  out "- BatteryPulse's own languages (its AppleLanguages): $(if [ -f "$BACKUP/app-languages" ]; then tr -s ' \n' ' ' <"$BACKUP/app-languages"; else echo "none (the system's)"; fi); the system's first language: $(defaults read -g AppleLanguages 2>/dev/null | tr -d ' \n()"' | cut -d, -f1 || echo unknown)"
  out "- the window style (windowLook): $(setting_of windowLook); beta window styles: $(setting_of betaWindowStyles); hasSeenWelcome: $(setting_of hasSeenWelcome)"
  out "- appearance: dark mode $(cat "$BACKUP/dark-mode"), automatic $(cat "$BACKUP/auto-appearance")"
  out "- Demo Mode: never stored (off at every launch); Report a Problem's files go to $WORK/report"
  out "- charge: $(battery_percent) %, $(if on_battery; then echo on battery; else echo on the adapter; fi)"
  echo "NEXT: the Charge Limit (SESSION-L.md, L1): $SCRIPT charge-limit read start, then the hold"
}

# MARK: - Proofs and preflight (the start; 0.6.2's proofs, quick where Session B settled them)

# proof_record <P#> pass|fail|not-run <detail> [fallback]: one row of proofs.tsv, which a rerun
# replaces.
proof_record() {
  mkdir -p "$WORK"
  touch "$PROOFS"
  awk -F '\t' -v id="$1" '$1 != id' "$PROOFS" >"$PROOFS.tmp"
  mv "$PROOFS.tmp" "$PROOFS"
  printf '%s\t%s\t%s\t%s\t%s\n' "$1" "$2" "$(printf '%s' "$3" | tr '\t\n' '  ' | public)" "${4:--}" "$(clock)" >>"$PROOFS"
  echo "PROOF $1: $2 ($3)${4:+; fallback: $4}"
}

proof_result() { awk -F '\t' -v id="$1" '$1 == id { print $2 }' "$PROOFS" 2>/dev/null || true; }

idle_seconds() { ui_run idle 2>/dev/null | sed -n 's/^hid_idle_s=\([0-9.]*\).*/\1/p' || true; }

state_seconds() { ui_run idle 2>/dev/null | sed -n 's/.* hid_state_s=\([0-9.-]*\).*/\1/p' || true; }

# lower <a> <b>: a is below b by more than half a second (HIDIdleTime went back: an event).
lower() { awk -v a="${1:-0}" -v b="${2:-0}" 'BEGIN { exit !(a + 0.5 < b) }'; }



# claude_pids: the Claude CLI's processes, by their command line: the native install runs a
# versioned file through the claude link, so its process name is the version, not "claude"; an npm
# install runs node with the claude script.
claude_pids() {
  ps -axo pid=,args= 2>/dev/null | awk '{
      n = split($2, path, "/")
      if (path[n] == "claude" || $2 ~ /\/claude\/versions\//) { print $1; next }
      if ((path[n] == "node" || path[n] == "bun") && $3 ~ /(^|\/)claude$/) print $1
    }' || true
}


# The assertions that declare a person at the Mac or keep its display awake. Another app holding
# one keeps the logged day's Mac awake and skews G7-11's delivered share (a widget nobody can see
# gets its reloads late), and declares activity during the GUI phase.
KEEPAWAKE_TYPES="UserIsActive PreventUserIdleDisplaySleep NoDisplaySleepAssertion"
# The ones that only keep the system awake: counted and recorded, nothing more.
SYSTEM_SLEEP_TYPES="PreventUserIdleSystemSleep NoIdleSleepAssertion"

# holder_is_ours <pid> <name> <type>: an assertion holder that doesn't count: one this script or
# the arm window started (an ancestor runs m5-session.sh: their caffeinate), the Claude CLI or a
# process it started (a caffeinate, an MCP server such as computer use's helper), except one that
# declares user activity, which spoils the runs whoever started it; then the system's own (an
# executable under /System, /usr but /usr/local, /bin, /sbin or /Library/Apple, or inside an app
# whose bundle identifier is Apple's) and BatteryPulse. Any other caffeinate counts (a utility may
# run one, or he did).
holder_is_ours() {
  local pid="$1" name="$2" type="${3:-}" path parent app bundle claude hops=0
  path="$(ps -o comm= -p "$pid" 2>/dev/null || true)"
  # Gone since pmset listed it: its assertion went with it.
  [ -n "$path" ] || return 0
  # The look shoot's own display assertion (awake_start), detached from the script that started it.
  if [ "$pid" = "$(cat "$WORK/awake.pid" 2>/dev/null || true)" ]; then return 0; fi
  claude="$(claude_pids)"
  if grep -qx -- "$pid" <<<"$claude"; then return 0; fi
  parent="$pid"
  while [ "$hops" -lt 12 ]; do
    parent="$(ps -o ppid= -p "$parent" 2>/dev/null | tr -d ' ' || true)"
    case "$parent" in "" | 0 | 1) break ;; esac
    # The CLI first: its own arguments name m5-session.sh (the start line's allow rule).
    if grep -qx -- "$parent" <<<"$claude"; then
      if [ "$type" = UserIsActive ]; then return 1; fi
      return 0
    fi
    if ps -o args= -p "$parent" 2>/dev/null | grep -q -F 'm5-session.sh'; then return 0; fi
    hops=$((hops + 1))
  done
  if [ "$name" = caffeinate ] || [ "${path##*/}" = caffeinate ]; then return 1; fi
  case "$path" in
    /usr/local/*) return 1 ;;
    /System/* | /usr/* | /bin/* | /sbin/* | /Library/Apple/*) return 0 ;;
    */BatteryPulse.app/* | */BatteryPulseWidget.appex/*) return 0 ;;
  esac
  app="${path%%.app/*}"
  if [ "$app" != "$path" ]; then
    bundle="$(plist_value "$app.app/Contents/Info.plist" CFBundleIdentifier)"
    case "$bundle" in com.apple.* | "$BUNDLE_ID" | "$BUNDLE_ID".*) return 0 ;; esac
  fi
  return 1
}

# keepawake_holders [<types>]: "<pid>\t<name>\t<assertion>" for each such assertion another process
# holds (pmset -g assertions' per-process lines; KEEPAWAKE_TYPES by default). The line is cut at
# its first "): [0x", so a process name with parentheses or an assertion name with brackets parses.
# The names are for the session and the arm window only.
keepawake_holders() {
  local pid name type
  pmset -g assertions 2>/dev/null | awk -v types=" ${1:-$KEEPAWAKE_TYPES} " '
    /^ *pid [0-9]+\(/ {
      line = $0
      sub(/^ *pid /, "", line)
      lp = index(line, "(")
      cut = index(line, "): [0x")
      if (cut <= lp) next
      pid = substr(line, 1, lp - 1)
      name = substr(line, lp + 1, cut - lp - 1)
      rest = substr(line, cut + 3)
      if (!sub(/^\[0x[0-9A-Fa-f]+\] [0-9:]+ /, "", rest)) next
      split(rest, w, " ")
      if (index(types, " " w[1] " ") > 0) printf "%s\t%s\t%s\n", pid, name, w[1]
    }' |
    while IFS="$TAB" read -r pid name type; do
      holder_is_ours "$pid" "$name" "$type" || printf '%s\t%s\t%s\n' "$pid" "$name" "$type"
    done
}

# keepawake_names <holders>: the processes' names, comma-joined (for the session and the arm only).
keepawake_names() { cut -f2 <<<"$1" | grep . | sort -u | tr '\n' ',' | sed 's/,$//; s/,/, /g'; }

# keepawake_record <where> <holders>: the holders into keepawake.local (never the report).
keepawake_record() {
  [ -n "$2" ] || return 0
  mkdir -p "$WORK"
  awk -F '\t' -v at="$(clock)" -v where="$1" 'NF { print at "\t" where "\t" $1 "\t" $2 "\t" $3 }' <<<"$2" >>"$KEEPAWAKE_LOCAL"
}

# keepawake_say <holders>: the KEEPAWAKE lines, for the session only.
keepawake_say() {
  awk -F '\t' '{ print "KEEPAWAKE (local only: never in a note, an answer or the report): " $2 " (pid " $1 ") holds " $3 }' <<<"$1"
}

# keepawake_check: preflight's read of the keep-awake assertions. The names go to the session (a
# KEEPAWAKE line) and keepawake.local; the report gets the counts. A system-sleep holder is only
# counted.
keepawake_check() {
  local holders system
  holders="$(keepawake_holders)"
  system="$(keepawake_holders "$SYSTEM_SLEEP_TYPES")"
  keepawake_record preflight "$holders"
  keepawake_record preflight-system-sleep "$system"
  out "- keep-awake assertions of other processes (user activity or display sleep): $(grep -c . <<<"$holders" || true); system sleep only (no run changes): $(grep -c . <<<"$system" || true) (names stay on the Mac)"
  if [ -n "$holders" ]; then
    keepawake_say "$holders"
    echo "DO (person): quit $(keepawake_names "$holders") now (its menu bar icon or its Dock icon, Quit), then $SCRIPT preflight again"
    return 1
  fi
}

# P1 --image <png> <x> <y> | <x> <y>: ui hit at a widget's centre. Only a widget host (Notification
# Center, chronod or a WidgetKit process) with a BatteryPulse label in the hit chain passes and
# joins ui-hosts; a mis-aimed point (no widget yet, a window over it, Finder) fails, so no other app
# is ever approved this way (ui also ignores any other entry).
proof_p1() {
  local hit owner bundle
  hit="$(ui_run hit "$@" 2>&1)" || {
    proof_record P1 fail "ui hit: $(head -1 <<<"$hit")" "widget points from prepare's shot, then computer use"
    return 0
  }
  printf '%s\n' "$hit" >"$LOGS/p1-hit.txt"
  owner="$(sed -n 's/^process: \(.*\) (\(.*\), pid .*/\1/p' <<<"$hit" | head -1 || true)"
  bundle="$(sed -n 's/^process: .* (\(.*\), pid .*/\1/p' <<<"$hit" | head -1 || true)"
  case "$bundle" in
    com.apple.notificationcenterui | com.apple.chronod | [Cc]om.apple.[Ww]idget[Kk]it.*) ;;
    *)
      proof_record P1 fail "the point's owner is ${owner:-unknown} (${bundle:-no bundle}), not a widget host" \
        "widget points from prepare's shot, then computer use"
      return 0
      ;;
  esac
  if ! grep -q '^batterypulse_label: yes' <<<"$hit"; then
    proof_record P1 fail "$owner is there, but no element of the hit chain is labelled BatteryPulse (logs/p1-hit.txt)" \
      "widget points from prepare's shot, then computer use"
    return 0
  fi
  { cat "$WORK/ui-hosts" 2>/dev/null || true; echo "$bundle"; } | tr ' ' '\n' | grep . | sort -u >"$WORK/ui-hosts.tmp"
  mv "$WORK/ui-hosts.tmp" "$WORK/ui-hosts"
  proof_record P1 pass "the widget's host is $owner ($bundle), with a BatteryPulse label in its chain (logs/p1-hit.txt)"
  echo "The host is ui's widget host now. Record each widget's frame: $SCRIPT widget <family> x y w h"
}


# P6: HIDIdleTime before and after a 0-pixel move at the HID tap, one at the session tap, and
# caffeinate -u; whether the HID event source's state ignores posted events. Session B settled it
# (posted events reset HIDIdleTime, and the HID event state ignores them), so this is a quick read
# that confirms it on this macOS: his touches are told apart by the HID event state.
proof_p6() {
  local before after hid session declared state_before state_after ignores
  echo "DO (person): please don't touch the Mac for about 20 seconds."
  sleep 5
  before="$(idle_seconds)"
  state_before="$(state_seconds)"
  ui_run move --here --tap hid >/dev/null 2>&1 || true
  sleep 1
  after="$(idle_seconds)"
  state_after="$(state_seconds)"
  if lower "$after" "$before"; then hid=resets; else hid=keeps; fi
  if lower "$state_after" "$state_before"; then ignores=no; else ignores=yes; fi
  sleep 4
  before="$(idle_seconds)"
  ui_run move --here --tap session >/dev/null 2>&1 || true
  sleep 1
  after="$(idle_seconds)"
  if lower "$after" "$before"; then session=resets; else session=keeps; fi
  sleep 4
  before="$(idle_seconds)"
  caffeinate -u -t 1 >/dev/null 2>&1 || true
  sleep 1.5
  after="$(idle_seconds)"
  if lower "$after" "$before"; then declared=resets; else declared=keeps; fi
  if [ "$session" = keeps ]; then echo session >"$WORK/ui-tap"; else echo hid >"$WORK/ui-tap"; fi
  proof_record P6 "$(if [ "$ignores" = yes ]; then echo pass; else echo fail; fi)" \
    "HIDIdleTime: a HID-tap move $hid it, a session-tap move $session it, caffeinate -u $declared it; .hidSystemState ignores posted events: $ignores; ui posts at the $(cat "$WORK/ui-tap") tap" \
    "$(if [ "$ignores" = yes ]; then echo "his touches by the HID event state (ui guard)"; else echo "during the GUI phase only his Esc says he is there"; fi)"
}

# P7: the reads restore rests on: the appearance by System Events, WindowManager's domain, the
# global domain, BatteryPulse's and its extension's languages.
proof_p7() {
  local dark wm global
  dark="$(if [ "$(is_dark)" != unknown ]; then echo read; else echo "not read"; fi)"
  wm="$(if defaults read com.apple.WindowManager >/dev/null 2>&1; then echo read; else echo "not read"; fi)"
  global="$(defaults read -g 2>/dev/null | grep -c -i -E 'icon|widget|tint|appearance' || true)"
  proof_record P7 "$(if [ "$dark" = read ] && [ "$wm" = read ]; then echo pass; else echo fail; fi)" \
    "the appearance by System Events: $dark; com.apple.WindowManager: $wm; style-like keys in defaults -g: $global; AppleICUForce24HourTime: $(defaults read -g AppleICUForce24HourTime 2>/dev/null || echo unset)" \
    "an unread setting is unknown, and never changed"
}

# P8: the System Settings pane URLs on 27. Each URL must switch to its own pane: the title must be
# that pane's (ui knows each pane's English and Russian name). Session B found the sidebar's
# selection unreadable on macOS 27.2 and three URLs opening other panes: a pane whose title matches
# is confirmed with its sidebar, or with "-" when the sidebar can't be read (ui then goes by the
# title alone). The confirmed panes go into ui-panes, the only places ui acts in System Settings
# (with Accessibility → Display); a pane that failed is computer use's alone, from the sidebar.
proof_p8() {
  local name state sidebar title match failed=""
  : >"$LOGS/panes.tsv"
  : >"$WORK/ui-panes.tmp"
  for name in $PANES; do
    open_pane "$name" || true
    sleep 2
    state="$(ui_run pane-state --expect "$name" 2>/dev/null || true)"
    sidebar="$(tr '\t' '\n' <<<"$state" | sed -n 's/^sidebar=//p' | head -1)"
    title="$(tr '\t' '\n' <<<"$state" | sed -n 's/^title=//p' | head -1)"
    match="$(tr '\t' '\n' <<<"$state" | sed -n 's/^match=//p' | head -1)"
    printf '%s\t%s\t%s\t%s\n' "$name" "${sidebar:--}" "${title:-none}" "${match:-no}" >>"$LOGS/panes.tsv"
    if [ "$match" = yes ] && [ -n "$title" ]; then
      printf '%s\t%s\t%s\n' "$name" "${sidebar:--}" "$title" >>"$WORK/ui-panes.tmp"
    else
      failed="$failed $name"
    fi
  done
  mv "$WORK/ui-panes.tmp" "$WORK/ui-panes"
  quit_if_launched "System Settings"
  # The verdicts only: the titles may be Russian, and stay in logs/panes.tsv on the Mac.
  proof_record P8 "$(if [ -z "$failed" ]; then echo pass; else echo fail; fi)" \
    "its own pane per URL: $(awk -F '\t' '{ printf "%s=%s%s; ", $1, $4, ($2 == "-" ? " (sidebar unread)" : "") }' "$LOGS/panes.tsv")" \
    "$(if [ -n "$failed" ]; then echo "computer use from System Settings' sidebar for:$failed (ui doesn't act there)"; else echo -; fi)"
}


# P11: the menu bar item. macOS 27.2 lists no window for it in CGWindowList (Session B's P11), so
# its frame comes from AX (the app's AXExtrasMenuBar, `ui frame BatteryPulse --status-item`): the
# rectangle the dark-bar check crops (menubar), never a click by the window list.
proof_p11() {
  local rect
  rect="$(ui_run frame BatteryPulse --status-item 2>/dev/null || true)"
  if [ -n "$rect" ]; then
    echo "$rect" >"$WORK/status-item"
    proof_record P11 pass "the menu bar item's frame by AX: $rect (no window in CGWindowList on macOS 27.2)"
  else
    rm -f "$WORK/status-item"
    proof_record P11 fail "no menu bar item in AX (AXExtrasMenuBar) nor in CGWindowList" \
      "the menu bar crops come from scripts/menu-bar-shots.sh's top strip (menu-bar-shots)"
  fi
}

# claude_app_running: the Claude desktop app runs (its permission banners sit at layer 23 over the
# whole display and refused the desktop clicks in Session B). The CLI this session runs in is
# another process (claude_pids).
claude_app_running() { pgrep -x Claude >/dev/null 2>&1; }

# pending_updates: macOS updates Software Update has found, read-only from its own preferences (no
# network, no softwareupdate call): a count, or "unknown". Its banner blocked five of Session B's
# runs; he postpones them before the GUI phase.
pending_updates() {
  local count
  count="$(defaults read /Library/Preferences/com.apple.SoftwareUpdate LastRecommendedUpdatesAvailable 2>/dev/null || true)"
  case "$count" in "" | *[!0-9]*) echo unknown ;; *) echo "$count" ;; esac
}

# proof <P#> [arguments] | proof <P#> pass|fail <note>: one proof, or a result the session saw by
# computer use (P10).
step_proof() {
  local id="${1:-}"
  [ -n "$id" ] || fail "usage: $SCRIPT proof P1 | P6 | P7 | P8 | P11 [arguments] | proof <P#> pass|fail <note>"
  shift
  case "${1:-}" in
    pass | fail | not-run)
      local result="$1"
      shift
      english_only "$*"
      proof_record "$id" "$result" "$*"
      return 0
      ;;
  esac
  case "$id" in
    P1) proof_p1 "$@" ;;
    P6) proof_p6 ;;
    P7) proof_p7 ;;
    P8) proof_p8 ;;
    P10) fail "P10 is computer use's: record it with $SCRIPT proof P10 pass|fail <what it showed>" ;;
    P11) proof_p11 ;;
    P2 | P3 | P4 | P5 | P9 | P12) fail "$id was Session B's (banners, the glass sheet's capture, profiling, the burst): not in Session R" ;;
    *) fail "no proof $id" ;;
  esac
}

# tell_targets: every `tell application` target in the frozen scripts; only System Events and
# BatteryPulse may appear, since another target would raise an Automation prompt while he is away.
tell_targets() {
  grep -h -o -E 'tell application (id )?\\?"[^"\\]*\\?"' "$HERE/m5-session.sh" "$HERE/ui.swift" 2>/dev/null |
    sed -E 's/tell application (id )?\\?"//; s/\\?"$//' | sort -u
}

# preflight (the start): the reads and checks while he is there, the proofs that need no answer
# from the session (P7, P8, P6, P11), the keep-awake read, and Session B's lessons: the Claude
# desktop app quit and pending macOS updates postponed before the GUI phase (their banners at layer
# 23 blocked five runs), BatteryPulse's own automatic update check off (session_settings). P1 runs
# by the session's own call, for 0.7's kinds too.
step_preflight() {
  [ $# -eq 0 ] || fail "usage: $SCRIPT preflight"
  begin_section 02-preflight "Preflight (the start)"
  local access target bad="" vpn updates
  access="$(ui_run access 2>&1 || true)"
  out "- access: $access"
  case "$access" in *"ax_trusted=no"*) echo "DO (person): allow Terminal under System Settings → Privacy & Security → Accessibility (Touch ID or your password), then run preflight again." ;; esac
  for target in $(tell_targets | tr ' ' '_'); do
    case "$target" in System_Events | '$BUNDLE_ID' | "$BUNDLE_ID") ;; *) bad="$bad $target" ;; esac
  done
  if [ -n "$bad" ]; then
    out "- tell application targets: refused:$bad (each would raise an Automation prompt while he is away)"
    fail "the frozen script tells another app than System Events or BatteryPulse:$bad"
  fi
  out "- tell application targets: System Events and BatteryPulse only"
  out "- Apple Events: System Events $(if [ "$(is_dark)" != unknown ]; then echo answers; else echo "doesn't answer"; fi); BatteryPulse $(if osascript -e "tell application id \"$BUNDLE_ID\" to get name" >/dev/null 2>&1; then echo answers; else echo "doesn't answer"; fi)"
  shot preflight-capture
  echo "LOOK $SHOTS/preflight-capture-view.jpg: the desktop, not only the wallpaper (Screen Recording's re-consent prompt would come now)"
  out "- the widget extension's container preferences: $(if defaults read "$WIDGET_PREFS" >/dev/null 2>&1; then echo read; else echo "not read (none yet, or the other apps' data prompt)"; fi)"
  out "- pmset -g battlimit: $(battlimit_value)"
  out "- hot corners: $(ui_run screen 2>/dev/null | sed 's/.*corners //')"
  vpn=no
  if scutil --nc list 2>/dev/null | grep -q 'Connected'; then vpn=yes; fi
  if ifconfig 2>/dev/null | awk '/^utun/ { u = 1; next } /^[a-z]/ { u = 0 } u && /inet / { found = 1 } END { exit !found }'; then vpn=yes; fi
  echo "$vpn" >"$WORK/vpn"
  out "- a VPN active: $vpn"
  out "- charge: $(battery_percent) %, $(if on_battery; then echo on battery; else echo on the adapter; fi)"
  out "- the widget extension's processes: $(widget_pids | grep -c . || true) (by its path)"
  out "- BatteryPulse's automatic update check: off for the GUI phase (session settings); his value comes back for the logged day"
  if claude_app_running; then
    out "- the Claude desktop app: running (he quits it before the GUI phase: its banners at layer 23 blocked Session B's clicks)"
    echo "DO (person): quit the Claude desktop app now (this Terminal session stays), so no banner of it covers the screen while he is away"
  else
    out "- the Claude desktop app: not running"
  fi
  updates="$(pending_updates)"
  out "- pending macOS updates (Software Update's own count, read-only): $updates"
  if [ "$updates" != 0 ]; then
    echo "DO (person): if Software Update offers an update, postpone it until after the logged day (Later, or Remind Me Tomorrow), so its banner doesn't cover the screen; don't install it before the series ends"
  fi
  proof_p7
  proof_p8
  proof_p6
  proof_p11
  out "- the main window's occlusion check: $(open_main && main_window_line)"
  out "- ui guard: $(ui_run guard 2>&1 || true)"
  keepawake_check || true
  out ""
  out "| Proof | Result | Detail | Fallback |"
  out "|---|---|---|---|"
  local proof result detail fallback
  while IFS=$'\t' read -r proof result detail fallback _; do
    out "| $proof | $result | $detail | $fallback |"
  done <"$PROOFS"
  park_pointer
  echo
  echo "Now, with the session's own calls: proof P1 at each widget's centre (and widget <name> for each),"
  echo "proof P10 (the app batch, a widget's click-to-add and its removal, a screenshot after the first action, one System"
  echo "Settings click; then a computer-use move of the pointer to bare desktop). Each family of the session's commands"
  echo "runs once here, so every prompt comes now:"
  echo "RUN $SCRIPT ui idle; $SCRIPT ui guard; $SCRIPT shot preflight-family;$(if [ "$SESSION" = R ]; then echo " $SCRIPT heartbeat preflight;"; fi)"
  echo "RUN $SCRIPT measure / judge on one shot; $SCRIPT status"
  # PLAN.md §6.0 rule 2: a menu-bar app has no Dock icon without a window, and computer use's
  # access request can't name it then.
  if [ ! -f "$WORK/main.time" ]; then
    echo "DO (session): $SCRIPT main before computer use asks for access to BatteryPulse or acts in it (rule 2: its window gives it the Dock icon the request names)"
  fi
  if [ "$SESSION" = L ]; then
    echo "NEXT: $SCRIPT main, then the one computer-use access request, then $SCRIPT prepare reads and the Charge Limit (SESSION-L.md, L1)"
  else
    echo "NEXT: $SCRIPT arm open; $SCRIPT mark away; then R1, from capacity start and step 2"
  fi
}

# MARK: - The streams, the widgets' crops and the windows

# The perf and widget lines BatteryPulse and its extension log: reload requests, timelines, reads,
# and W-4's per-kind answers of currentConfigurations().
STREAM_PREDICATE="subsystem == \"$BUNDLE_ID\" AND (category == \"perf\" OR category == \"widget\")"

# stream_start <name> <file>: a `log stream` of those lines, detached (nohup), its pid in
# <name>.pid, so it outlives this call (0.6.2's Session B: a stream so started survived the night's
# sleeps, 4 gaps over 10 minutes, the longest 17).
stream_start() {
  local pid
  if leftover_running "$1"; then
    echo "the $1 runs already (pid $(cat "$WORK/$1.pid"))"
    return 0
  fi
  mkdir -p "$LOGS"
  nohup /usr/bin/log stream --level debug --style ndjson --predicate "$STREAM_PREDICATE" >"$2" 2>"$2.err" </dev/null &
  pid=$!
  echo "$pid" >"$WORK/$1.pid"
  disown "$pid" 2>/dev/null || true
  sleep 2
  echo "the $1 runs (pid $pid) into $2"
}

# awake_start: the look shoot's display assertion, which Session R8's arm window keeps for its GUI
# phase and the arm-less look shoot needs as much (about two hours hands-free, the hold's wait and
# the adapter's beeps, the display off and the screen locked otherwise): caffeinate -d -i for at
# most 3 hours, detached, its pid in awake.pid. restore end (stop_leftovers) ends it;
# keepawake_check counts it as the script's own.
awake_start() {
  if leftover_running awake; then
    echo "the display assertion runs already (pid $(cat "$WORK/awake.pid"))"
    return 0
  fi
  nohup caffeinate -d -i -t 10800 >/dev/null 2>&1 </dev/null &
  echo "$!" >"$WORK/awake.pid"
  disown "$!" 2>/dev/null || true
  echo "the display stays awake until restore end, at most 3 hours (caffeinate pid $(cat "$WORK/awake.pid"))"
}

# stream_stop <name>: ends it the way Control-C does.
stream_stop() {
  local pid tries=0
  pid="$(cat "$WORK/$1.pid" 2>/dev/null || true)"
  [ -n "$pid" ] || return 0
  if leftover_running "$1"; then
    sleep 2
    kill -INT "$pid" 2>/dev/null || true
    while leftover_running "$1" && [ "$tries" -lt 10 ]; do
      sleep 0.3
      tries=$((tries + 1))
    done
    if leftover_running "$1"; then kill -TERM "$pid" 2>/dev/null || true; fi
  fi
  rm -f "$WORK/$1.pid"
}

gui_stream_start() { stream_start gui-stream "$GUI_STREAM"; }

# widget_names: the recorded widgets, in WIDGET_NAMES' order.
widget_names() {
  local name
  for name in $WIDGET_NAMES; do
    [ -z "$(widget_rect "$name")" ] || echo "$name"
  done
}

# crop_widgets <folder> <suffix>: a crop of every recorded widget, <folder>/<name>-<suffix>.png,
# each with its luma spread (blank or grey) and contrast; prints the LOOK lines.
crop_widgets() {
  local folder="$1" suffix="$2" name file stats
  mkdir -p "$folder"
  for name in $(widget_names); do
    file="$folder/$name-$suffix.png"
    rect_shot "$file" "$(widget_rect "$name")" >/dev/null || {
      not_checked "crop-$name-$suffix" "no shot of the $name widget"
      continue
    }
    stats="$("$BIN/frames" stats "$file" 2>/dev/null | sed -n 's/.*\(stddev=[0-9.]*\).*/\1/p' || true)"
    echo "LOOK $file (${stats:-no stats}; $("$BIN/frames" contrast "$file" 2>/dev/null | sed -n 's/^\(contrast_ratio=[0-9.]*\).*/\1/p' || true))"
  done
}

# lowest_contrast <file>...: the file with the lowest contrast ratio, and the ratio.
lowest_contrast() {
  local file ratio best="" low=""
  for file in "$@"; do
    [ -f "$file" ] || continue
    ratio="$("$BIN/frames" contrast "$file" 2>/dev/null | sed -n 's/.*contrast_ratio=\([0-9.]*\).*/\1/p' || true)"
    [ -n "$ratio" ] || continue
    if [ -z "$low" ] || awk -v a="$ratio" -v b="$low" 'BEGIN { exit !(a + 0 < b + 0) }'; then
      low="$ratio"
      best="$file"
    fi
  done
  [ -z "$best" ] || echo "$best $low"
}

# activate_app: BatteryPulse made the active app by an Apple Event to it alone (preflight's
# tell-target check allows BatteryPulse and System Events), so its window is key and a menu command
# acts on it: Session F's Command-W left What's New open while BatteryPulse, an agent app, wasn't
# active after its relaunch. Never when it doesn't run (the event would launch it).
activate_app() {
  app_running || return 0
  osascript -e "tell application id \"$BUNDLE_ID\" to activate" >/dev/null 2>&1 || true
  sleep 0.5
}

# close_front_window: BatteryPulse's front window closed by an AX press on its own close button
# (`ui close`, by the window's title), else with BatteryPulse made active first, by its Close menu
# item (Command-W, by AX): Session F's rule (AC71's F rows). False when neither closed one.
close_front_window() {
  local title
  title="$(ui_run title BatteryPulse 2>/dev/null | sed -n 's/^title: //p' | head -1 || true)"
  if [ -n "$title" ] && ui_run close BatteryPulse --window "$title" >/dev/null 2>&1; then return 0; fi
  activate_app
  ui_run press BatteryPulse --menu-cmd w >/dev/null 2>&1
}

# popover_shot <file>: the menu bar popover by an AX press on the menu bar item (ui press
# --status-item: macOS 27.2 lists no window for it, so a click there never passes ui's checks),
# shot by its AX frame, and closed by a second press. BatteryPulse's other windows are closed first
# (close_front_window), so the front window is the popover; nothing is shot when the press fails.
popover_shot() {
  local tries=0
  while close_front_window && [ "$tries" -lt 3 ]; do
    tries=$((tries + 1))
    sleep 1
  done
  ui_run press BatteryPulse --status-item >/dev/null 2>&1 || {
    echo "the menu bar item's AX press failed (ui press BatteryPulse --status-item)" >&2
    return 1
  }
  sleep 2
  front_shot "$1" || {
    ui_run press BatteryPulse --status-item >/dev/null 2>&1 || true
    return 1
  }
  ui_run press BatteryPulse --status-item >/dev/null 2>&1 || true
}

# front_shot <file>: BatteryPulse's front window (Settings, the compact window), by its AX frame.
front_shot() {
  local rect
  rect="$(ui_run frame BatteryPulse 2>/dev/null || true)"
  [ -n "$rect" ] || {
    echo "BatteryPulse shows no window" >&2
    return 1
  }
  rect_shot "$1" "$rect"
}

# widget_log_since <time> <file>: BatteryPulse's own log lines since then (its widget, update and
# app categories), as "<time> <process> <message>", for the session to read (never a full URL in the
# report: the route lines are cut at "://").
widget_log_since() {
  log_since "$1" "subsystem == \"$BUNDLE_ID\" AND category != \"perf\"" "$LOGS/since.ndjson" >/dev/null
  messages "$LOGS/since.ndjson" | sed 's|://[^ ]*|://…|g' >"$2"
}

# main: BatteryPulse's main window by a reopen event, placed on the right. Computer use finds a
# menu-bar-only app only once it has a window (0.6.2's after-publishing check), so the session
# calls this before computer use asks for access to BatteryPulse and before its first computer-use
# action in it (PLAN.md §6.0 rule 2); main.time records that it ran, which preflight checks.
step_main() {
  app_running || launch_r
  open_main
  place_window
  clock >"$WORK/main.time"
  echo "the main window: $(main_window_line)"
}

# MARK: - Session R8, steps 2 and 11c: placed widgets across RC-U's install (G7-2)

# placed <his|062> before | 1 | 5 | compare: placed widgets across RC-U's install (G7-2; P71's W-17
# item 1). his: step 2, his widgets placed under his 0.7.1 (each recorded with `widget`), across
# RC-U's install over it; 062: step 11c, the small and medium Battery widgets placed from 0.6.2's
# gallery after `install start`, across RC-U's install again (a static Battery widget becomes a
# configurable one: what an updater from 0.6.2 sees). before: a crop of each after the desktop
# click, and the extension's pids; 1 and 5: a minute and five minutes after RC-U's install (waits
# until then), pluginkit, a full shot (local) and the crops, the pids and the CHSErrorDomain 1103
# lines; compare: the crops after the desktop click, against before's, once the widgets redrew
# (rule 4: an extension process that wasn't there before the install; none is "not checked").
step_placed() {
  r_only placed
  local half="${1:-}" moment="${2:-}" names prefix at name title fresh=""
  case "$half" in
    his) names="small medium large" prefix=R2- title="Step 2: his widgets across RC-U's install over $BASE_VERSION (G7-2)" ;;
    062) names="small medium" prefix=R2-062- title="Step 11c: $START_VERSION's widgets across RC-U's install (G7-2)" ;;
    *) fail "usage: $SCRIPT placed his|062 before | 1 | 5 | compare" ;;
  esac
  use_section "10-placed-$half" "$title"
  case "$moment" in
    before)
      click_desktop || not_checked "${prefix}before" "no desktop spot"
      crop_widgets "$SHOTS/placed-$half" before
      widget_pids | tr '\n' ' ' >"$WORK/placed-$half.pids"
      out "- before ($(clock)): $(app_version); widget extension pids: $(cat "$WORK/placed-$half.pids")"
      ;;
    1 | 5)
      [ -f "$WORK/installed.time" ] && grep -q "^U " "$WORK/installed" 2>/dev/null ||
        fail "RC-U isn't installed yet: $SCRIPT install U first"
      at="$(date -j -f '%Y-%m-%d %H:%M:%S' "$(cat "$WORK/installed.time")" +%s 2>/dev/null || date +%s)"
      sleep_until $((at + moment * 60))
      pluginkit -mv -i "$WIDGET_ID" >"$LOGS/pluginkit-$half-$moment.txt" 2>&1 || true
      park_pointer
      shot "placed-$half-$moment"
      crop_widgets "$SHOTS/placed-$half" "${moment}min"
      out "- $moment minute(s) after RC-U's install ($(clock)): $(app_version); widget extension pids: $(widget_pids | tr '\n' ' '); $(chs_since "$(cat "$WORK/installed.time")")"
      out "- pluginkit:"
      out_block "$LOGS/pluginkit-$half-$moment.txt"
      ;;
    compare)
      fresh="$(fresh_widget_pid "$(cat "$WORK/placed-$half.pids" 2>/dev/null || true)" 30)"
      click_desktop || not_checked "${prefix}compare" "no desktop spot"
      crop_widgets "$SHOTS/placed-$half" now
      out "- compared ($(clock)): a widget extension process since before: ${fresh:-none}; $(chs_since "$(cat "$WORK/installed.time" 2>/dev/null || cat "$WORK/prepare.time")")"
      if [ -z "$fresh" ]; then
        for name in $names; do not_checked "$prefix$name" "no redraw: no widget extension process that wasn't there before the install"; done
        return 0
      fi
      echo "Compare each crop with its -before.png beside it (what Session B's F12 answered: 1 same, with fresh values)."
      for name in $names; do
        [ -z "$(widget_rect "$name")" ] || step_measure "$prefix$name" blank "$SHOTS/placed-$half/$name-now.png" >/dev/null || true
      done
      # The question list is the half's names, each with its prefix.
      # shellcheck disable=SC2046
      ask $(for name in $names; do printf '%s%s ' "$prefix" "$name"; done)
      ;;
    *) fail "usage: $SCRIPT placed his|062 before | 1 | 5 | compare" ;;
  esac
}

# whats-new rc|062 [ru]: What's New after RC-U's install (P71's W-17 item 11), at its 520 points:
# rc after step 2's install over his 0.7.1 (no version count row: 0.7 announced it), 062 after step
# 11c's over 0.6.2 (the row, for an updater from before 0.7). Without ru: the window that opened by
# itself at the install's launch, in English, shot by its AX frame and closed by its own close
# button (rule from Session F), with no relaunch, so the minute shots see the update alone. ru,
# after them: the last-seen version set back once to the one before (What's New shows once per
# update), BatteryPulse relaunched in Russian, the window shot and closed, then the session's
# language again.
step_whats_new() {
  r_only whats-new
  local from="${1:-}" lang="${2:-en}" version previous id rect width file
  case "$from:$lang" in
    rc:en | rc:ru) previous="$BASE_VERSION" id=R2-whats-new-rc ;;
    062:en | 062:ru) previous="$START_VERSION" id=R2-whats-new-062 ;;
    *) fail "usage: $SCRIPT whats-new rc|062 [ru]" ;;
  esac
  version="$(plist_value "$APP/Contents/Info.plist" CFBundleShortVersionString)"
  [ "$version" = "$RC_VERSION" ] || fail "What's New is checked after RC-U's install; $version is installed"
  use_section 12-whats-new "What's New after RC-U's install (P71's W-17 item 11)"
  file="$SHOTS/whats-new/$from-$lang.png"
  if [ "$lang" = ru ]; then
    quit_app
    set_default lastSeenVersion -string "$previous"
    open "$APP" --args -ApplePersistenceIgnoreState YES -AppleLanguages "(ru)"
    wait_for_app
    sleep 2
  fi
  rect="$(ui_run frame BatteryPulse 2>/dev/null || true)"
  width="$(awk '{ print $3 }' <<<"$rect")"
  if [ -n "$rect" ] && front_shot "$file" >/dev/null; then
    out "- from $previous, $lang ($(clock)): the front window ${width:-?} points wide (What's New is 520); LOOK $file"
    echo "LOOK $file"
  else
    not_checked "$id-$lang" "no BatteryPulse window after $(if [ "$lang" = ru ]; then echo "the Russian relaunch"; else echo "the install (What's New opens once after the update)"; fi)"
  fi
  close_front_window || true
  if [ "$lang" = ru ]; then
    relaunch_r
    ask "$id"
  else
    echo "Then $SCRIPT placed ... 1, 5 and compare; after them, $SCRIPT whats-new $from ru"
  fi
}

# MARK: - Session R8, step 11c: the gallery

# gallery <name>: after computer use added that widget from the gallery (click-to-add, then one
# slow `ui drag`) and its frame is recorded (`widget <name> ...`): its crop after the desktop
# click, against the CI render of its kind and family (previews/, from RC-U's run). Each one the
# session adds is a desktop-widgets change, which only the app's counts confirm gone (T-1 item 7).
step_gallery() {
  r_only gallery
  local name="${1:-}"
  case " $WIDGET_NAMES " in *" $name "*) ;; *) fail "usage: $SCRIPT gallery <$(tr ' ' '|' <<<"$WIDGET_NAMES")>" ;; esac
  [ -n "$(widget_rect "$name")" ] || fail "no frame recorded for $name: $SCRIPT widget $name <x> <y> <w> <h> first (ui frame --widgets lists them)"
  click_desktop || not_checked "R3-$name" "no desktop spot"
  crop_widgets "$SHOTS/gallery" added | grep -F "/$name-" || true
  use_section 15-gallery "Step 11c: the gallery"
  out "- $name added and cropped ($(clock))"
  echo "The CI renders to compare with: $(find "$WORK/previews" -name '*.png' 2>/dev/null | sort | tr '\n' ' ')"
  ask "R3-$name"
}

# MARK: - Session R8, step 11c: the edit sheet and the language

# edit-shot <tag> [<widget>]: one widget (the medium Battery one by default) after the desktop
# click, one crop per state of step 4 (the choices made, back to Automatic, 4.6's choices).
step_edit_shot() {
  r_only edit-shot
  [ $# -ge 1 ] && [ $# -le 2 ] || fail "usage: $SCRIPT edit-shot <tag> [<widget name>]"
  case "$1" in *[!A-Za-z0-9._-]*) fail "a tag is letters, digits, dots, dashes and underscores" ;; esac
  [ -n "$(widget_rect "${2:-medium}")" ] || fail "no frame recorded for ${2:-medium}"
  click_desktop || not_checked "edit-$1" "no desktop spot"
  crop_widgets "$SHOTS/edit" "$1" | grep -F "/${2:-medium}-" || true
}

# relaunch_for_redraw <capture> <launch command...>: BatteryPulse quit and launched again by the
# command, with a `log stream` of the perf and widget lines into <capture> from before the quit; then
# up to 90 s for a widget reload notice (a `perf event widget.reload` line: debug messages, which
# `log show` never finds) and a widget extension process that wasn't there before. Sets REDRAW to
# "<seconds> s, the reload notice: <line or none>; a new extension process: <pid or none>"; true
# only when both came.
REDRAW=""
# REDRAW_ALSO: a text the capture must also hold before the wait ends (feed cold's first read).
REDRAW_ALSO=""
relaunch_for_redraw() {
  local capture="$1" before waited=0 reload="" fresh="" pid stream
  shift
  mkdir -p "$LOGS"
  /usr/bin/log stream --level debug --style ndjson --predicate "$STREAM_PREDICATE" >"$capture" 2>"$capture.err" </dev/null &
  stream=$!
  STREAMS="$STREAMS $stream"
  sleep 2
  before=" $(widget_pids | tr '\n' ' ') "
  quit_app
  "$@"
  while [ "$waited" -lt 90 ]; do
    sleep 5
    waited=$((waited + 5))
    reload="$(messages "$capture" | grep -F 'perf event widget.reload' | head -1 || true)"
    fresh=""
    for pid in $(widget_pids); do
      case "$before" in *" $pid "*) ;; *) fresh="$pid" ;; esac
    done
    if [ -n "$reload" ] && [ -n "$fresh" ] && { [ -z "$REDRAW_ALSO" ] || grep -q -F "$REDRAW_ALSO" <<<"$(messages "$capture")"; }; then break; fi
  done
  perf_stop "$stream"
  REDRAW="after ${waited} s, the reload notice: ${reload:-none}; a new extension process: ${fresh:-none}"
  [ -n "$reload" ] && [ -n "$fresh" ]
}

# launch_redraw: launch_r after a lastSeenLanguage that differs from the app's language, so the
# launch ends the widget extension and reloads every kind (WidgetReloadPlanner.launchReason's
# language case) without a change of the language itself (W-17 item 5, the F8 lesson: WidgetKit
# keeps a widget's saved render until a reload).
launch_redraw() {
  set_default lastSeenLanguage -string redraw
  launch_r
}

# language ru | back: step 11c's widgets in BatteryPulse's own language set the user's way (P71's
# W-17 item 6, T-1 item 5): BatteryPulse's AppleLanguages written as System Settings → General →
# Language & Region → Applications writes it (app_language_write: that pane's menu belongs to System
# Settings' own process, out of computer use's reach in Session F), then BatteryPulse relaunched in
# the language its settings give it, so the app writes it into the widget's feed (W-15); the
# reload notice and a new widget extension process waited for, and only then every widget cropped.
# No reload in time is "not checked: no redraw", never "n". The extension's own AppleLanguages is
# never set: it would hide W-15's fix. back: the same with his own language put back.
step_language() {
  r_only language
  local lang="${1:-}" since
  case "$lang" in ru | back) ;; *) fail "usage: $SCRIPT language ru | back" ;; esac
  [ $# -eq 1 ] || fail "usage: $SCRIPT language ru | back"
  use_section 20-language "Step 11c: the widgets in BatteryPulse's own language, set the user's way"
  quit_app
  app_language_write "$lang"
  out "- BatteryPulse's AppleLanguages now: $(defaults read "$BUNDLE_ID" AppleLanguages 2>/dev/null | tr -d ' \n' || echo none)"
  since="$(clock)"
  if ! relaunch_for_redraw "$LOGS/language-$lang.ndjson" launch_plain; then
    out "- $lang ($since): $REDRAW"
    not_checked "R4-3-widgets-$lang" "no redraw: no widget reload notice or no new extension process within 90 s of the relaunch"
    return 0
  fi
  out "- $lang ($since): $REDRAW; the feed's languages: $(feed_languages)"
  sleep 5
  click_desktop || true
  crop_widgets "$SHOTS/language" "$lang"
  if [ "$lang" = ru ]; then ask R4-3-widgets; fi
}

# MARK: - Session R8, step 11c: rendering modes and places (G7-4)

# look <always|auto> <default|dark|clear|tinted> | look nc <style> | look contrast | transparency |
# 12-hour | text-size: after the session set the style (and Dim widgets on desktop) by computer use,
# each recorded first with `change`: the desktop clicked, then BatteryPulse's main window (a click
# on its title bar, CGEvent), the desktop shot twice (local) with every widget's crop and contrast.
# contrast, transparency, 12-hour and text-size first redraw every widget (launch_redraw): the
# widget's clock times are formatted into its timeline, so a 24-hour change shows only after a
# reload (WidgetTimeText), and so may an accessibility change.
# nc: Notification Center opened by an AX click on the clock, and only the crops of BatteryPulse's
# widgets there (ui frame --widgets), never a full shot while it is open; the clock again closes it.
step_look() {
  r_only look
  local where="${1:-}" style="${2:-}" id tag rect line low frames="" n=0 files=""
  case "$where:$style" in
    always:default | always:dark | always:clear | always:tinted | auto:default | auto:dark | auto:clear | auto:tinted)
      id="R5-$where-$style"
      ;;
    nc:default | nc:dark | nc:clear | nc:tinted) id="R5-nc-$style" ;;
    contrast: | transparency:) id="R5-$where" ;;
    12-hour:) id=R6-12-hour ;;
    text-size:) id=R7-text-size ;;
    *) fail "usage: $SCRIPT look <always|auto|nc> <default|dark|clear|tinted> | look contrast | transparency | 12-hour | text-size" ;;
  esac
  tag="${id#R?-}"
  use_section 30-look "Step 11c: rendering modes and places (G7-4), and time's and Text size's looks"
  if [ "$where" = nc ]; then
    ui_run click --ax "Control Center" clock >/dev/null 2>&1 || {
      not_checked "$id" "Notification Center didn't open by an AX click on the clock"
      return 0
    }
    sleep 2
    frames="$(ui_run frame --widgets 2>/dev/null || true)"
    while IFS= read -r rect; do
      [ -n "$rect" ] || continue
      n=$((n + 1))
      rect_shot "$SHOTS/look/$tag-$n.png" "$rect" >/dev/null && files="$files $SHOTS/look/$tag-$n.png"
    done <<<"$frames"
    ui_run click --ax "Control Center" clock >/dev/null 2>&1 || echo "DO (session): close Notification Center (an AX click on the clock: $SCRIPT ui click --ax \"Control Center\" clock)"
    park_pointer
    [ -n "$files" ] || {
      not_checked "$id" "no BatteryPulse widget frame in Notification Center (ui frame --widgets)"
      return 0
    }
    for line in $files; do echo "LOOK $line"; done
  else
    case "$where" in
      contrast | transparency | 12-hour | text-size)
        relaunch_for_redraw "$LOGS/redraw-$tag.ndjson" launch_redraw ||
          not_checked "$id-redraw" "no reload notice or no new extension process within 90 s: the crops may show the earlier render"
        out "- $id's redraw: $REDRAW"
        sleep 5
        ;;
    esac
    click_desktop || not_checked "$id" "no desktop spot"
    open_main
    line="$(main_window_line)"
    rect="$(line_rect "$line")"
    if [ -n "$rect" ]; then
      # shellcheck disable=SC2046
      ui_click_main $(awk '{ printf "%d %d", $1 + $3 * 3 / 4, $2 + 6 }' <<<"$rect") >/dev/null 2>&1 ||
        warn "the click on the main window was refused"
    fi
    park_pointer
    for n in 1 2; do
      shot "look-$tag-$n"
      crop_widgets "$SHOTS/look" "$tag-$n"
      files="$files $(for line in $(widget_names); do printf '%s ' "$SHOTS/look/$line-$tag-$n.png"; done)"
      [ "$n" = 2 ] || sleep 3
    done
    close_front_window || true
  fi
  # shellcheck disable=SC2086
  low="$(lowest_contrast $files)"
  out "- $id ($(clock)): $(echo $files | wc -w | tr -d ' ') crops; the lowest contrast ${low:-unread}"
  if [ -n "$low" ] && [ "$id" != R7-text-size ]; then step_measure "$id" contrast "${low%% *}" >/dev/null; fi
  ask "$id"
}

# MARK: - Session R8, step 11c: time and the version count's toggle

# tick: two crops of the medium widget 65 s apart (a time-left widget counts down by itself).
step_tick() {
  r_only tick
  click_desktop || not_checked R6-tick "no desktop spot"
  crop_widgets "$SHOTS/tick" first | grep -F '/medium-' || true
  sleep 65
  crop_widgets "$SHOTS/tick" second | grep -F '/medium-' || true
  use_section 35-time "Step 11c: time and the version count"
  out "- the time-left tick: two crops 65 s apart ($(clock))"
  ask R6-tick
}

# count-toggle: W-13's toggle in BatteryPulse's Settings → General: with his Check for updates
# (weekly if his is Never), then Never, each in English and in Russian (a launch argument); then
# the session's settings again. Claude reads the four shots.
step_count_toggle() {
  r_only count-toggle
  local his lang value
  his="$(setting_of updateFrequency)"
  case "$his" in never | "default (unset)") value=weekly ;; *) value="$his" ;; esac
  use_section 35-time "Step 11c: time and the version count"
  for lang in en ru; do
    for state in on never; do
      quit_app
      session_settings
      if [ "$state" = on ]; then set_default updateFrequency -string "$value"; fi
      open "$APP" --args -ApplePersistenceIgnoreState YES -AppleLanguages "($lang)"
      wait_for_app
      ui_run press BatteryPulse --menu-cmd , >/dev/null 2>&1 || not_checked "R6-count-$lang-$state" "Settings didn't open"
      sleep 2
      front_shot "$SHOTS/count/settings-$lang-$state.png" || not_checked "R6-count-$lang-$state" "no shot"
      close_front_window || true
    done
  done
  relaunch_r
  out "- the version count's toggle: Check for updates $value, then never, in English and Russian ($(clock))"
  echo "LOOK $SHOTS/count/settings-en-on.png, settings-en-never.png, settings-ru-on.png, settings-ru-never.png"
  ask R6-count-toggle
}

# MARK: - Session R8, step 3: the widgets' trees VoiceOver walks (C10, G7-12)

# tree [ru]: `ui tree` of every recorded widget, inside its frame in its host (P1's), roles and
# labels; the Accessories and iPhone & iPad widgets' labels (accessory and device names) stay on
# the Mac, the report gets their roles. ru: after `language ru`, while BatteryPulse is Russian.
step_tree() {
  r_only tree
  local suffix="${1:-en}" name host file
  case "$suffix" in en | ru) ;; *) fail "usage: $SCRIPT tree [ru]" ;; esac
  host="$(head -1 "$WORK/ui-hosts" 2>/dev/null || true)"
  [ -n "$host" ] || fail "no widget host recorded: proof P1 first"
  use_section 40-tree "Step 3: the widgets' trees VoiceOver walks (C10, G7-12)"
  for name in $(widget_names); do
    file="$LOGS/tree-$name-$suffix.txt"
    # The frame is four arguments: x y width height.
    # shellcheck disable=SC2046
    if ! ui_run tree --app "$host" --inside $(widget_rect "$name") >"$file" 2>&1; then
      not_checked "R7-tree-$name-$suffix" "ui tree: $(head -1 "$file")"
      continue
    fi
    echo "READ $file"
    out "- $name ($suffix): $(grep -c . "$file" || true) elements"
    case "$name" in
      accessories-* | devices-*) sed 's/"[^"]*"/"(a label, kept on the Mac)"/g' "$file" >"$file.public" ;;
      *) cp "$file" "$file.public" ;;
    esac
    out_block "$file.public"
  done
  if [ "$suffix" = ru ]; then ask R7-tree-ru; else ask R7-tree; fi
}

# MARK: - Session R8, step 11c: clicks (G7-9)

# click-widget <quit|running|accessories|health|main|compact|history|device>: the app put in that
# state, then a CGEvent click at the widget's recorded frame (the Battery widget, the Accessories
# widget for accessories, the medium one for health, which computer use set to maximum capacity
# first, a History widget for history, an iPhone & iPad widget for device: its device's page, or
# Devices in an empty state); BatteryPulse's log lines since the click (its route, `url` or
# `activity`, and the page) and the window that opened. compact sets Window to open to compact
# through defaults while the app is quit, and the session's setting again after.
step_click_widget() {
  r_only click-widget
  local case_="${1:-}" name=small host since rect
  case "$case_" in
    quit | running | main | compact) ;;
    accessories) name="$(widget_names | grep '^accessories-' | head -1 || true)" ;;
    history) name="$(widget_names | grep '^history-' | head -1 || true)" ;;
    device) name="$(widget_names | grep '^devices-' | head -1 || true)" ;;
    health) name=medium ;;
    *) fail "usage: $SCRIPT click-widget quit | running | accessories | health | main | compact | history | device" ;;
  esac
  rect="$(widget_rect "${name:-none}")"
  [ -n "$rect" ] || fail "no frame recorded for ${name:-a widget of that kind}"
  host="$(head -1 "$WORK/ui-hosts" 2>/dev/null || true)"
  [ -n "$host" ] || fail "no widget host recorded: proof P1 first"
  case "$case_" in
    quit) quit_app ;;
    running | accessories | health | history | device) relaunch_r ;;
    main)
      relaunch_r
      open_main
      ;;
    compact)
      quit_app
      session_settings
      set_default prefersCompactWindow -bool true
      ;;
  esac
  click_desktop || true
  since="$(clock)"
  # shellcheck disable=SC2046
  ui_run click $(awk '{ printf "%d %d", $1 + $3 / 2, $2 + $4 / 2 }' <<<"$rect") --expect "$host" >/dev/null 2>&1 ||
    not_checked "R8-$case_" "the click at the widget was refused"
  sleep 6
  widget_log_since "$since" "$LOGS/click-$case_.txt"
  use_section 45-clicks "Step 11c: clicks (G7-9)"
  out "- $case_ ($since): BatteryPulse $(if app_running; then echo runs; else echo "doesn't run"; fi); its log lines since the click:"
  grep -i -E 'url|activity|route|page|open' "$LOGS/click-$case_.txt" | head -8 >"$LOGS/click-$case_.public" || true
  out_block "$LOGS/click-$case_.public"
  front_shot "$SHOTS/click/$case_.png" || not_checked "R8-$case_" "no window to shoot"
  if [ "$case_" = compact ]; then
    quit_app
    session_settings
    relaunch_r
  fi
  ask "R8-$case_"
}

# MARK: - Session R8: the plug, the accessories and Demo Mode's Charge limit (step 11c)

# plug: at the day's end, with him (W-17 item 13: it measures the candidate with every kind
# placed): a beep for the unplug, a crop of every widget and `bpulse --json` every 10 s; 70 s later
# a second beep for the plug-in, then every 10 s for 3 minutes. Records when bit 24 appears (W-14
# item 6), and from its own stream the reloads per kind and the app's per-kind answers of
# currentConfigurations() against the widgets placed (G7-17).
step_plug() {
  r_only plug
  local i json first24="" capture="$LOGS/plug.ndjson" stream
  [ -f "$DAY_END" ] || fail "the plug runs at the day's end, after $SCRIPT day-end"
  use_section 50-plug "The day's end: the unplug and the plug-in (G7-17)"
  [ -x "$BIN/bpulse" ] || not_checked R9-plug "bpulse isn't built: the widget's crops only"
  /usr/bin/log stream --level debug --style ndjson --predicate "$STREAM_PREDICATE" >"$capture" 2>"$capture.err" </dev/null &
  stream=$!
  STREAMS="$STREAMS $stream"
  sleep 2
  cue "Unplug the adapter now"
  sound Glass
  out "- unplug cue at $(clock)"
  for i in 1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16 17 18 19 20 21 22 23 24 25; do
    if [ "$i" = 8 ]; then
      cue "Plug the adapter in now"
      sound Hero
      out "- plug-in cue at $(clock)"
    fi
    json="$LOGS/plug-$i.json"
    if bpulse_json "$json"; then
      out "- $(date '+%H:%M:%S') $(charge_row "$json")"
      if [ -z "$first24" ] && [ "$(charge_row "$json" | sed -n 's/.*bit 24: \(yes\).*/\1/p')" = yes ]; then first24="$(date '+%H:%M:%S')"; fi
    fi
    crop_widgets "$SHOTS/plug" "$i" >/dev/null
    sleep 10
  done
  out "- bit 24 first seen after the plug-in: ${first24:-not within 3 minutes}"
  perf_stop "$stream"
  out "- the widgets placed (widgets.tsv): $(widget_names | tr '\n' ' ')"
  out "- the reloads per kind over the plug (perf-stats: widget reloads, widget delivery):"
  if [ -x "$BIN/perf-stats" ]; then summarize "$capture" '^(widget (reloads|delivery)|trigger|kind|battery|accessories|history|devices|policy|update|language)'; fi
  messages "$capture" | grep -i -E 'placed widgets|configuration' | head -12 >"$LOGS/plug-placements.txt" || true
  out "- the app's answers of currentConfigurations() over the plug, against the widgets placed (G7-17):"
  out_block "$LOGS/plug-placements.txt"
  echo "LOOK the crops in $SHOTS/plug (<widget>-<n>) beside the rows above"
  ask R9-plug
}

# accessories-watch <disconnect|reconnect>: after the session's AX press in System Settings →
# Bluetooth (recorded with `change bluetooth-accessory connected disconnected` first): the
# Accessories widgets' crops and pmset's accessory count every 10 s for a minute.
step_accessories_watch() {
  r_only accessories-watch
  local what="${1:-}" i count
  case "$what" in disconnect | reconnect) ;; *) fail "usage: $SCRIPT accessories-watch disconnect | reconnect" ;; esac
  use_section 52-accessories "Step 11c: an accessory disconnected and reconnected"
  for i in 0 1 2 3 4 5 6; do
    count="$(pmset -g accps 2>/dev/null | grep -v -i 'InternalBattery' | grep -c -E '[0-9]+%' || true)"
    out "- $what +$((i * 10)) s: pmset -g accps lists $count accessory sources"
    crop_widgets "$SHOTS/accessories" "$what-$i" | grep -F '/accessories-' || true
    [ "$i" = 6 ] || sleep 10
  done
  if [ "$what" = reconnect ]; then ask R9-accessory; fi
}

# demo-shots [ru]: step 11c's Demo Mode, with its Charge limit scene chosen by AX (the session's ui
# press): Overview, Power, the menu bar popover and the compact window, in the language BatteryPulse
# runs in; and the Battery widgets when bpulse --json shows bit 24 now. Demo Mode is never stored,
# so a relaunch ends it: ru only after `app-language ru` and the scene chosen again in Russian (its
# row's label from the catalog), never a relaunch here, which would shoot the real state.
step_demo_shots() {
  r_only demo-shots
  local lang="${1:-en}" item json
  case "$lang" in en | ru) ;; *) fail "usage: $SCRIPT demo-shots [ru]" ;; esac
  [ "$lang" = "$(ui_lang)" ] ||
    fail "BatteryPulse runs in $(ui_lang): demo-shots $lang needs $SCRIPT app-language $(if [ "$lang" = ru ]; then echo ru; else echo back; fi) first, then Demo Mode's Charge limit scene again by ui press (a relaunch ends Demo Mode)"
  open_main
  place_window
  for item in Overview Power; do
    select_page "$(page_label "$item")" || not_checked "R9b-$lang" "$item wasn't selected"
    sleep 2
    window_shot "$SHOTS/demo/$(tr '[:upper:]' '[:lower:]' <<<"$item")-$lang.png" || not_checked "R9b-$lang" "no shot of $item"
  done
  popover_shot "$SHOTS/demo/popover-$lang.png" || not_checked "R9b-popover-$lang" "no shot of the popover"
  park_pointer
  use_section 55-limit "Step 11c: Demo Mode's Charge limit scene (W-14, G7-18)"
  out "- Demo Mode's Charge limit scene, $lang ($(clock)): Overview, Power, the popover"
  echo "DO (session): the compact window by computer use or ui, shot with $SCRIPT screen demo-compact front, else note it"
  json="$LOGS/limit-now.json"
  if bpulse_json "$json"; then
    out "- now: $(charge_row "$json")"
    if [ "$(charge_row "$json" | sed -n 's/.*bit 24: \(yes\).*/\1/p')" = yes ]; then
      click_desktop || true
      crop_widgets "$SHOTS/demo" "limit-$lang"
      ask R9b-widgets
    fi
  fi
  if [ "$lang" = ru ]; then ask R9b-demo-ru; else ask R9b-demo; fi
}

# MARK: - The new screens (the look shoot's step 3, Session R8's steps 3-11)

# The pages of the main window's sidebar, by their English labels (MainView's SidebarItem), split
# at "|" since some have spaces: iPhone and iPad is the Devices section's page while no device is
# remembered (prepare hides his), Raw Data and Demo Mode the Developer section's (the session's
# settings show it).
PAGES="Overview|Power|History|Health|Accessories|iPhone and iPad|Raw Data|Demo Mode"

# ui_lang: the language BatteryPulse runs in for the session's shots: en, or ru after
# `app-language ru` (launch_r passes it, so every relaunch keeps it).
ui_lang() { cat "$WORK/ui-language" 2>/dev/null || echo en; }

# catalog_ru <English key>: its Russian in the frozen worktree's String Catalog, read from its JSON
# text (an entry opens with `    "<key>": {`; plutil's key paths can't hold the dots many keys
# have), for an AX press or a sidebar row in Russian, or the widget sheet's words; the key itself
# when it has none.
catalog_ru() {
  local value
  value="$(awk -v key="    \"$1\": {" '
    !inside && $0 == key { inside = 1; next }
    inside && /^    "/ { exit }
    inside && /"value": "/ { sub(/^[^:]*: "/, ""); sub(/",?$/, ""); print; exit }' "$ROOT/Resources/Localizable.xcstrings" 2>/dev/null || true)"
  printf '%s\n' "${value:-$1}"
}

# write_sheet_words: the widget kinds' gallery descriptions (the widget's .description(...) at the
# frozen commit), in English and in Russian, into sheet-words, which ui's Sheet rules require the
# widget edit sheet to show before it presses anything there (T-1 item 5). Local only.
write_sheet_words() {
  local text
  mkdir -p "$WORK"
  : >"$WORK/sheet-words"
  grep -o '\.description("[^"]*")' "$ROOT/Sources/BatteryPulseWidget/BatteryPulseWidget.swift" 2>/dev/null |
    sed 's/^\.description("//; s/")$//' | while IFS= read -r text; do
    printf '%s\n%s\n' "$text" "$(catalog_ru "$text")" >>"$WORK/sheet-words"
  done
}

# page_label <English label>: the sidebar row's label in the session's language now.
page_label() { if [ "$(ui_lang)" = ru ]; then catalog_ru "$1"; else printf '%s\n' "$1"; fi; }

# screen <name> [main|front|popover]: what BatteryPulse shows now (the session opened it by AX or
# computer use), shot by the script (rule 8: -R at the frame after the occlusion check, never -l):
# the main window (default), the front window (Settings, Welcome, Report a Problem, About) or the
# menu bar popover, into shots/screens/<name>-<language>.png.
step_screen() {
  rl_or_d3 screen
  [ $# -ge 1 ] && [ $# -le 2 ] || fail "usage: $SCRIPT screen <name> [main|front|popover]"
  case "$1" in *[!A-Za-z0-9._-]*) fail "a screen's name is letters, digits, dots, dashes and underscores" ;; esac
  local file
  file="$SHOTS/screens/$1-$(ui_lang).png"
  case "${2:-main}" in
    main) window_shot "$file" ;;
    front) front_shot "$file" ;;
    popover) popover_shot "$file" ;;
    *) fail "usage: $SCRIPT screen <name> [main|front|popover]" ;;
  esac >/dev/null || {
    not_checked "screen-$1-$(ui_lang)" "no shot of the ${2:-main} window"
    return 0
  }
  park_pointer
  use_section 30-screens "The screens (PLAN.md §6.1 step 3, §6.4 steps 8-10)"
  out "- $1 ($(ui_lang), ${2:-main}, $(clock)): shots/screens/$(basename "$file")"
  echo "LOOK $file"
}

# pages <tag> [<page>...]: the main window's pages (all of PAGES by default; a page of two words is
# one quoted argument, "Raw Data"), each selected by its sidebar row in the session's language and
# shot, into shots/screens/<tag>-<page>-<language>.png: a Demo Mode scene on Overview and Power (the
# look shoot), every page in Russian (R8's step 8).
step_pages() {
  rl_only pages
  [ $# -ge 1 ] || fail "usage: $SCRIPT pages <tag> [<page>...]"
  case "$1" in *[!A-Za-z0-9._-]*) fail "a tag is letters, digits, dots, dashes and underscores" ;; esac
  local tag="$1" page lower file pages
  shift
  if [ $# -gt 0 ]; then pages=("$@"); else IFS='|' read -r -a pages <<<"$PAGES"; fi
  app_running || launch_r
  open_main
  place_window
  for page in "${pages[@]}"; do
    lower="$(tr '[:upper:]' '[:lower:]' <<<"$page" | tr ' ' '-')"
    select_page "$(page_label "$page")" || {
      not_checked "pages-$tag-$lower" "the sidebar row $page wasn't selected"
      continue
    }
    sleep 2
    file="$SHOTS/screens/$tag-$lower-$(ui_lang).png"
    window_shot "$file" >/dev/null || {
      not_checked "pages-$tag-$lower" "no shot of $page"
      continue
    }
    echo "LOOK $file"
  done
  park_pointer
  use_section 30-screens "The screens (PLAN.md §6.1 step 3, §6.4 steps 8-10)"
  out "- $tag ($(ui_lang), $(clock)): $(printf '%s; ' "${pages[@]}")"
}

# scene-shots <tag>: a Demo Mode scene the session chose by an AX press on its row (Developer →
# Demo Mode): Overview, Power and the menu bar popover (A-1's causes, A-2's number), in the
# session's language.
step_scene_shots() {
  rl_only scene-shots
  [ $# -eq 1 ] || fail "usage: $SCRIPT scene-shots <tag>"
  step_pages "$1" Overview Power
  step_screen "$1-popover" popover
}

# app_language_write ru | back: BatteryPulse's own language as System Settings → General →
# Language & Region → Applications sets it, its AppleLanguages in its own domain, written while
# BatteryPulse is quit (Session F: that pane's menu belongs to System Settings' own process, which
# computer use can't act in, AC71's F rows): ru records the change first; back puts his own (the
# backup's, or none) and reads it back. The session's shots and relaunches follow it (ui_lang).
app_language_write() {
  local his now
  his="$(if [ -f "$BACKUP/app-languages" ]; then tr -d ' \n()"' <"$BACKUP/app-languages"; else echo none; fi)"
  case "$1" in
    ru)
      [ -n "$(original_of app-language)" ] && ! is_restored app-language || record_change app-language "$his" ru
      defaults write "$BUNDLE_ID" AppleLanguages -array ru en
      echo ru >"$WORK/ui-language"
      ;;
    back)
      if [ -f "$BACKUP/app-languages" ]; then
        # One argument per language: a language code has no spaces.
        # shellcheck disable=SC2046
        defaults write "$BUNDLE_ID" AppleLanguages -array $(widget_languages_of "$BACKUP/app-languages")
      else
        defaults delete "$BUNDLE_ID" AppleLanguages 2>/dev/null || true
      fi
      echo en >"$WORK/ui-language"
      now="$(defaults read "$BUNDLE_ID" AppleLanguages 2>/dev/null | tr -d ' \n()"' || true)"
      now="${now:-none}"
      if [ "$now" = "$his" ]; then mark_restored app-language "script: his AppleLanguages read back ($now; none is the system's)"; else
        warn "BatteryPulse's AppleLanguages reads $now, not his $his: restore end puts his settings back"
      fi
      ;;
  esac
}

# app-language ru | back: BatteryPulse in Russian for the session's shots (the look shoot's second
# pass, Session R8's steps 3 and 8), the user's way (app_language_write), then a relaunch; back puts
# his own. AX labels are then the catalog's Russian (`ui tree BatteryPulse` lists them).
step_app_language() {
  rl_only app-language
  case "${1:-}" in
    ru | back)
      quit_app
      app_language_write "$1"
      launch_r
      echo "BatteryPulse runs in $(if [ "$1" = ru ]; then echo Russian; else echo "his language again"; fi) ($(app_version))"
      ;;
    *) fail "usage: $SCRIPT app-language ru | back" ;;
  esac
}

# welcome first | back (the look shoot's A-5): the Welcome window as a new user meets it,
# hasSeenWelcome cleared (its value recorded first) and BatteryPulse relaunched, shot as it opens
# (the session scrolls it by computer use and shoots again with screen); back puts hasSeenWelcome
# as it was and reads it back. Without an argument: Session R8's look at Welcome on the Air's
# display (a launch argument only, no setting changed).
step_welcome() {
  local was now
  case "${1:-}" in
    "")
      r_only welcome
      quit_app
      launch_r -showWelcomeAtLaunch YES
      sleep 2
      front_shot "$SHOTS/front/welcome.png" || not_checked R-settings "the Welcome window didn't open"
      ;;
    first)
      session_only L "welcome first"
      was="$(defaults read "$BUNDLE_ID" hasSeenWelcome 2>/dev/null || echo unset)"
      [ -n "$(original_of has-seen-welcome)" ] && ! is_restored has-seen-welcome || record_change has-seen-welcome "$was" cleared
      quit_app
      defaults delete "$BUNDLE_ID" hasSeenWelcome 2>/dev/null || true
      launch_r
      sleep 2
      front_shot "$SHOTS/screens/welcome-$(ui_lang).png" || not_checked L-a5-welcome "the Welcome window didn't open with hasSeenWelcome cleared"
      echo "DO (session): read it; scroll it by computer use if it doesn't fit and $SCRIPT screen welcome-end front; then $SCRIPT welcome back"
      ;;
    back)
      session_only L "welcome back"
      was="$(original_of has-seen-welcome)"
      [ -n "$was" ] || fail "welcome first hasn't run"
      close_front_window || true
      quit_app
      case "$was" in
        unset) defaults delete "$BUNDLE_ID" hasSeenWelcome 2>/dev/null || true ;;
        1 | true | YES) defaults write "$BUNDLE_ID" hasSeenWelcome -bool true ;;
        *) defaults write "$BUNDLE_ID" hasSeenWelcome -bool false ;;
      esac
      now="$(defaults read "$BUNDLE_ID" hasSeenWelcome 2>/dev/null || echo unset)"
      if [ "$now" = "$was" ] || { [ "$was" = true ] && [ "$now" = 1 ]; }; then mark_restored has-seen-welcome "script, read back ($now)"; else
        warn "hasSeenWelcome reads $now, not $was: restore end puts his settings back"
      fi
      launch_r
      ;;
    *) fail "usage: $SCRIPT welcome [first | back]" ;;
  esac
}

# report-check: every report Report a Problem saved into the session's report/ folder (the session
# saves it there by computer use; PLAN.md §6.1 step 3, §6.4 step 10): G8-13, no serial of this Mac
# (IOPlatformSerialNumber) or of its battery (AppleSmartBattery's Serial), no user name (short or
# full, the bundle ID and the repository's owner taken out first, as the privacy lint does) and no
# home path; and G8-5, the crash reports' names it lists against the folder's (ls). Only counts and
# kinds reach the report; the files stay on the Mac.
step_report_check() {
  rl_only report-check
  local file serial battery checked=0 dirty=0 found names listed=0 named=0 scrubbed="$WORK/report-scrubbed.txt" id
  if [ "$SESSION" = L ]; then id=L-a6-file; else id=R-report; fi
  serial="$(ioreg -rd1 -c IOPlatformExpertDevice 2>/dev/null | sed -n 's/.*"IOPlatformSerialNumber" = "\(.*\)"/\1/p' | head -1 || true)"
  battery="$(ioreg -rn AppleSmartBattery 2>/dev/null | sed -n 's/^ *"Serial" = "\(.*\)"/\1/p' | head -1 || true)"
  names="$(find "$REPORTS" -maxdepth 1 -type f \( -name 'BatteryPulse*' -o -name 'bpulse*' \) 2>/dev/null | sed 's|.*/||' | sort || true)"
  use_section 32-report "Report a Problem's files (G8-13, G8-5)"
  for file in "$WORK"/report/*.txt; do
    [ -f "$file" ] || continue
    checked=$((checked + 1))
    awk -v a="$(tr '[:upper:]' '[:lower:]' <<<"$BUNDLE_ID")" -v b="$(tr '[:upper:]' '[:lower:]' <<<"${REPO%%/*}")" '{
        l = tolower($0)
        while ((i = index(l, a)) > 0) l = substr(l, 1, i - 1) substr(l, i + length(a))
        while ((i = index(l, b)) > 0) l = substr(l, 1, i - 1) substr(l, i + length(b))
        print l }' "$file" >"$scrubbed"
    found=""
    [ -z "$serial" ] || ! grep -q -i -F -- "$serial" "$scrubbed" || found="$found the Mac's serial;"
    [ -z "$battery" ] || ! grep -q -i -F -- "$battery" "$scrubbed" || found="$found the battery's serial;"
    ! grep -q -i -w -F -- "$(id -un)" "$scrubbed" || found="$found the user name;"
    [ -z "$(id -F 2>/dev/null)" ] || ! grep -q -i -F -- "$(id -F)" "$scrubbed" || found="$found the full name;"
    ! grep -q -i -F -- "$(tr '[:upper:]' '[:lower:]' <<<"$HOME")" "$scrubbed" || found="$found the home path;"
    listed="$(grep -c . <<<"$names" || true)"
    named="$(while IFS= read -r one; do [ -z "$one" ] || ! grep -q -F -- "$one" "$file" || echo "$one"; done <<<"$names" | grep -c . || true)"
    out "- $(basename "$file"): $(wc -c <"$file" | tr -d ' ') bytes; $(if [ -n "$found" ]; then echo "NAMES$found"; else echo "no serial, user name or home path"; fi); crash reports named: $named of the $listed ls lists"
    [ -z "$found" ] || dirty=$((dirty + 1))
  done
  rm -f "$scrubbed"
  if [ "$checked" = 0 ]; then
    not_checked "$id" "no .txt in $WORK/report: save Report a Problem's file there first"
  elif [ "$dirty" = 0 ]; then
    feed_verdict "$id" y "$checked files without a serial, user name or home path; the crash reports' names against ls in the section" "$WORK/report"
  else
    feed_verdict "$id" n "$dirty of $checked files name this Mac or him (the kinds in the section; a leak is fixed before D1, G8-13)" "$WORK/report"
  fi
}

# sentinel place [accessories|devices] | check [accessories|devices]: P-1 (PLAN.md §6.1 step 3, §6.4
# step 11): with BatteryPulse quit, the feature's sentinel file placed, as a read cut short by a
# crash leaves it (P-1: Application Support/<bundle>/Sentinel/<feature>), then BatteryPulse launched,
# the page showing the note and Turn On Again, which the session presses by AX; check: the file gone
# and the page reading again. The file's name is P-1's [unverified until P-1 lands: place warns when
# its SentinelPolicy.swift doesn't name the feature]; a file Turn On Again left is removed.
step_sentinel() {
  rl_only sentinel
  local feature="${2:-accessories}" file id
  case "$feature" in accessories | devices) ;; *) fail "usage: $SCRIPT sentinel place|check [accessories|devices]" ;; esac
  file="$SUPPORT/Sentinel/$feature"
  if [ "$SESSION" = L ]; then id=L-p1-note; else id=R-sentinel; fi
  use_section 34-sentinel "The sentinel (P-1)"
  case "${1:-}" in
    place)
      if [ ! -f "$ROOT/Sources/BatteryCore/SentinelPolicy.swift" ]; then
        not_checked "$id" "no SentinelPolicy.swift at the frozen commit: P-1 hasn't landed"
        return 0
      fi
      grep -q -F "\"$feature\"" "$ROOT/Sources/BatteryCore/SentinelPolicy.swift" ||
        warn "SentinelPolicy.swift doesn't name \"$feature\": the file's name may not be P-1's"
      [ -n "$(original_of "sentinel-$feature")" ] && ! is_restored "sentinel-$feature" || record_change "sentinel-$feature" none placed
      quit_app
      mkdir -p "$SUPPORT/Sentinel"
      : >"$file"
      launch_r
      open_main
      place_window
      select_page "$(page_label "$(if [ "$feature" = accessories ]; then echo Accessories; else echo Devices; fi)")" >/dev/null 2>&1 || true
      sleep 2
      out "- placed Sentinel/$feature ($(clock)), BatteryPulse relaunched"
      echo "DO (session): $SCRIPT screen sentinel-note (the note and Turn On Again), then $SCRIPT ui press BatteryPulse \"$(page_label "Turn On Again")\", then $SCRIPT sentinel check $feature"
      ;;
    check)
      sleep 2
      if [ -e "$file" ]; then
        rm -f "$file"
        mark_restored "sentinel-$feature" "script: removed it, Turn On Again didn't"
        out "- check ($(clock)): Sentinel/$feature still there after Turn On Again: removed by the script"
        feed_verdict "$id" n "Sentinel/$feature stayed after Turn On Again" "$SUPPORT/Sentinel"
      else
        mark_restored "sentinel-$feature" "the file gone after Turn On Again"
        out "- check ($(clock)): Sentinel/$feature gone after Turn On Again"
        echo "DO (session): $SCRIPT screen sentinel-after (the page reading again), then judge $id from both shots"
        ask "$id"
      fi
      ;;
    *) fail "usage: $SCRIPT sentinel place|check [accessories|devices]" ;;
  esac
}

# help-link: the user guide's link (A-7, PLAN.md §6.1 step 3 and §6.6 step 4), read without the
# browser: About's User Guide link, which opens the same AppLinks.help as Help → BatteryPulse Help,
# its AXURL by `ui tree` (About opened by its menu item, closed by its button); and BatteryPulse's
# lines since then that name the guide (A-7 may log the ref it opens). Only the link's blob/<ref>
# part reaches the report.
step_help_link() {
  rl_or_d3 help-link
  local since url ref line
  since="$(clock)"
  app_running || launch_r
  ui_run press BatteryPulse "$(page_label "About BatteryPulse")" >/dev/null 2>&1 || true
  sleep 2
  url="$(ui_run tree BatteryPulse --match "$(page_label "User Guide")" 2>/dev/null | sed -n 's/.* url \(https:[^ ]*\).*/\1/p' | head -1 || true)"
  close_front_window || true
  log_since "$since" "subsystem == \"$BUNDLE_ID\" AND category != \"perf\"" "$LOGS/help.ndjson" >/dev/null
  line="$(messages "$LOGS/help.ndjson" | grep -i -E 'guide|blob/' | tail -1 | sed 's|://[^ ]*blob/|://…/blob/|g' || true)"
  ref="$(sed -n 's|.*/blob/\([^/]*\)/.*|\1|p' <<<"$url")"
  use_section 36-help "The user guide's link (A-7)"
  out "- $(app_version) ($since): About's User Guide link: ${ref:+blob/$ref/docs/USER_GUIDE.md}${ref:-not read}; a log line: ${line:-none}"
  if [ "$SESSION" = D3 ]; then ask D3-help; else ask L-a7-link; fi
}

# weak-adapter in | out (the look shoot's step 4, Q8-3's yes, G8-3): in: a beep for the low-wattage
# adapter, the change waited for (pmset -g adapter's wattage), a bounded CPU load for 2 minutes (one
# busy loop per core, each ending itself), and bpulse --raw captures at 30 s and 2 minutes into
# captures/ (serial numbers redacted; sent only after his yes), with their charger keys in the
# section; out: a beep for his usual adapter, read back.
adapter_watts() { pmset -g adapter 2>/dev/null | sed -n 's/.*[Ww]attage = \([0-9]*\).*/\1/p' | head -1 || true; }
step_weak_adapter() {
  session_only L weak-adapter
  local usual now waited=0 at cores i capture
  use_section 40-weak-adapter "The weak adapter (Q8-3, G8-3)"
  case "${1:-}" in
    in)
      [ "$(answer_of L-adapter)" = y ] || fail "Q8-3 is his: $SCRIPT answer --by person L-adapter y first, else step 4 is skipped"
      build_bpulse
      [ -x "$BIN/bpulse" ] || fail "bpulse isn't built (see $BIN/bpulse.log)"
      usual="$(adapter_watts)"
      echo "${usual:-unknown}" >"$WORK/adapter-usual"
      out "- the usual adapter: ${usual:-unknown} W ($(clock))"
      cue "Plug the low-wattage adapter in now"
      sound Glass
      while [ "$waited" -lt 180 ]; do
        now="$(adapter_watts)"
        if ! on_battery && [ -n "$now" ] && [ "$now" != "$usual" ]; then break; fi
        sleep 3
        waited=$((waited + 3))
      done
      now="$(adapter_watts)"
      [ -n "$now" ] && [ "$now" != "$usual" ] && ! on_battery || {
        not_checked L-weak-adapter "no other adapter within 3 minutes of the beep (${now:-none} W)"
        return 0
      }
      out "- the low-wattage adapter: $now W ($(clock))"
      cores="$(sysctl -n hw.ncpu 2>/dev/null || echo 4)"
      at=$(($(date +%s) + 125))
      # Each loop ends itself after 125 s (bash's SECONDS, no process per turn); cleanup ends them
      # sooner if this call ends.
      for i in $(seq 1 "$cores"); do
        (end=$((SECONDS + 125)); while [ "$SECONDS" -lt "$end" ]; do :; done) </dev/null >/dev/null 2>&1 &
        BACKGROUND="$BACKGROUND $!"
      done
      mkdir -p "$WORK/captures"
      for i in 30 120; do
        sleep_until $((at - 125 + i))
        capture="$WORK/captures/weak-$now-W-${i}s.plist"
        "$BIN/bpulse" --raw >"$capture" 2>/dev/null || {
          not_checked L-weak-adapter "bpulse --raw failed at $i s"
          continue
        }
        plutil -p "$capture" 2>/dev/null | grep -E '"(NotChargingReason|SlowChargingReason|ChargerInhibitReason|ErrorFlags|TimeChargingThermallyLimited|IsCharging|ExternalConnected)" =>' |
          sed 's/^ *//' | sort -u >"$LOGS/weak-$i.txt" || true
        out "- $i s under load: $(charge_row_raw "$capture")"
        out_block "$LOGS/weak-$i.txt"
      done
      sleep_until "$at"
      echo "LOOK the charger keys above; then $SCRIPT weak-adapter out (his usual adapter back at the beep)"
      ;;
    out)
      usual="$(cat "$WORK/adapter-usual" 2>/dev/null || true)"
      cue "Plug your usual adapter back in now"
      sound Hero
      while [ "$waited" -lt 180 ]; do
        now="$(adapter_watts)"
        if ! on_battery && [ -n "$now" ] && { [ -z "$usual" ] || [ "$usual" = unknown ] || [ "$now" = "$usual" ]; }; then break; fi
        sleep 3
        waited=$((waited + 3))
      done
      out "- back ($(clock)): ${now:-no} W on the adapter (the usual ${usual:-unknown} W)"
      ask L-weak-adapter
      ;;
    *) fail "usage: $SCRIPT weak-adapter in | out" ;;
  esac
}

# charge_row_raw <capture>: the charge, the state's keys and NotChargingReason of a bpulse --raw
# capture, for the weak adapter's rows.
charge_row_raw() {
  printf 'charge %s %%, IsCharging %s, ExternalConnected %s, NotChargingReason %s' \
    "$(battery_key "$1" CurrentCapacity top)" "$(battery_key "$1" IsCharging top)" \
    "$(battery_key "$1" ExternalConnected top)" "$(plutil -p "$1" 2>/dev/null | sed -n 's/.*"NotChargingReason" => \([0-9]*\).*/\1/p' | head -1 || true)"
}

# window-style <standard|frosted|translucent|clear> | back: BatteryPulse's window style (its
# windowLook, beta styles on for Translucent and Clear) written while BatteryPulse is quit, then a
# relaunch (Q8-4's Clear badge in the look shoot; the audit's Standard and Frosted in R8); back puts
# his own (the backup's) and reads it back.
step_window_style() {
  rl_only window-style
  local his
  his="$(setting_of windowLook)/$(setting_of betaWindowStyles)"
  case "${1:-}" in
    standard | frosted | translucent | clear)
      [ -n "$(original_of bp-window-style)" ] && ! is_restored bp-window-style || record_change bp-window-style "$his" "$1"
      quit_app
      set_default windowLook -string "$1"
      case "$1" in translucent | clear) set_default betaWindowStyles -bool true ;; esac
      launch_r
      echo "the window style is $1"
      ;;
    back)
      quit_app
      put_style_back
      if [ "$(setting_now windowLook)/$(setting_now betaWindowStyles)" = "$his" ]; then mark_restored bp-window-style "script: his windowLook and betaWindowStyles read back"; fi
      launch_r
      ;;
    *) fail "usage: $SCRIPT window-style standard|frosted|translucent|clear | back" ;;
  esac
}

# setting_now <key>: BatteryPulse's setting as its domain holds it now, read the way setting_of
# reads the backup (plutil's raw form: a Boolean is true or false), or "default (unset)".
setting_now() {
  local value
  defaults export "$BUNDLE_ID" "$WORK/defaults-now.plist" 2>/dev/null || true
  value="$(plutil -extract "$1" raw -o - "$WORK/defaults-now.plist" 2>/dev/null || true)"
  printf '%s\n' "${value:-default (unset)}"
}

# put_style_back: windowLook (a string) and betaWindowStyles (a Boolean) as the backup holds them,
# or unset.
put_style_back() {
  local look beta
  look="$(setting_of windowLook)"
  beta="$(setting_of betaWindowStyles)"
  if [ "$look" = "default (unset)" ]; then defaults delete "$BUNDLE_ID" windowLook 2>/dev/null || true; else set_default windowLook -string "$look"; fi
  case "$beta" in
    true) set_default betaWindowStyles -bool true ;;
    false) set_default betaWindowStyles -bool false ;;
    *) defaults delete "$BUNDLE_ID" betaWindowStyles 2>/dev/null || true ;;
  esac
}

# appearance-set light | dark | back: the system's appearance by System Events (Session R8's audit
# in Light and Dark), recorded first; back puts prepare's and reads it back (Auto comes back only by
# hand: then the session, by computer use).
step_appearance_set() {
  r_only appearance-set
  local dark auto
  dark="$(cat "$BACKUP/dark-mode" 2>/dev/null || echo unknown)"
  auto="$(cat "$BACKUP/auto-appearance" 2>/dev/null || echo 0)"
  case "$dark" in true | false) ;; *) fail "the appearance wasn't read at prepare: never changed" ;; esac
  case "${1:-}" in
    light | dark)
      [ -n "$(original_of appearance)" ] && ! is_restored appearance || record_change appearance "dark mode $dark, automatic $auto" "$1"
      appearance "$1"
      echo "the appearance is $1"
      ;;
    back)
      if [ "$dark" = true ]; then appearance dark; else appearance light; fi
      if [ "$(is_dark)" = "$dark" ] && [ "$(defaults read -g AppleInterfaceStyleSwitchesAutomatically 2>/dev/null || echo 0)" = "$auto" ]; then
        mark_restored appearance "script: read back by System Events"
      else
        echo "the appearance needs his Auto setting back by computer use (System Settings → Appearance), then $SCRIPT restored appearance \"<the shot>\""
      fi
      ;;
    *) fail "usage: $SCRIPT appearance-set light | dark | back" ;;
  esac
}

# app-tree <surface> [ru]: `ui tree BatteryPulse` of what BatteryPulse shows now (the session
# opened that page or window: every page, the compact window, the popover, each Settings pane,
# About, What's New, Software Update, Welcome, Report a Problem), into logs/app-tree/, with C10's
# checks counted: controls without a label, images without one (decorative only), and the elements
# that carry a value (the power flow, the capacity bars, the rings). The labels stay on the Mac (an
# accessory's name may be one); the report gets the counts.
APP_CONTROLS="AXButton AXCheckBox AXRadioButton AXPopUpButton AXMenuButton AXSlider AXLink AXTextField AXIncrementor AXDisclosureTriangle AXSegmentedControl AXComboBox"
step_app_tree() {
  r_only app-tree
  local surface="${1:-}" lang="${2:-en}" file unlabeled images values total
  case "$surface" in "" | *[!A-Za-z0-9._-]*) fail "usage: $SCRIPT app-tree <surface> [ru]" ;; esac
  case "$lang" in en | ru) ;; *) fail "usage: $SCRIPT app-tree <surface> [ru]" ;; esac
  mkdir -p "$LOGS/app-tree"
  file="$LOGS/app-tree/$surface-$lang.txt"
  ui_run tree BatteryPulse --depth 30 >"$file" 2>&1 || {
    not_checked "R-tree-app-$surface-$lang" "ui tree: $(head -1 "$file")"
    return 0
  }
  total="$(grep -c . "$file" || true)"
  unlabeled="$(awk -v roles=" $APP_CONTROLS " '{ r = $1; sub(/\/.*/, "", r) } index(roles, " " r " ") && $2 == "\"\"" { n++ } END { print n + 0 }' "$file")"
  images="$(awk '{ r = $1; sub(/\/.*/, "", r) } r == "AXImage" && $2 == "\"\"" { n++ } END { print n + 0 }' "$file")"
  values="$(grep -c -v -E ' value - frame ' "$file" || true)"
  use_section 42-app-tree "Step 3: BatteryPulse's trees (C10)"
  out "- $surface ($lang): $total elements; controls without a label $unlabeled; images without one $images (decorative only); elements with a value $values"
  echo "READ $file (controls without a label: $unlabeled; each one names an element to fix or to keep as decorative)"
}

# keys walk <surface> [<n>] | keys <tab|shift-tab|left|right|up|down> | keys <space|return> --on
# <text>: the keyboard walk (C10, PLAN.md §6.4 step 4), with Keyboard navigation on (System
# Settings → Keyboard by computer use, `change keyboard-navigation off on` first): BatteryPulse made
# active, the key posted to BatteryPulse alone (`ui key`, never Esc), and after each the focused
# element read by AX, into logs/keys/<surface>.txt; walk posts Tab n times (20 by default). Space
# and Return press the focused element only when --on names it (ui refuses an install, a quit, a
# delete and the like). The session reads the list: each named path reached is y.
step_keys() {
  r_only keys
  local surface n i file
  mkdir -p "$LOGS/keys"
  activate_app
  case "${1:-}" in
    walk)
      surface="${2:-}"
      n="${3:-20}"
      case "$surface" in "" | *[!A-Za-z0-9._-]*) fail "usage: $SCRIPT keys walk <surface> [<n>]" ;; esac
      case "$n" in [1-9] | [1-5][0-9]) ;; *) fail "a walk is 1-59 Tabs" ;; esac
      file="$LOGS/keys/$surface.txt"
      ui_run focused >"$file" 2>&1 || true
      for i in $(seq 1 "$n"); do
        ui_run key tab >>"$file" 2>&1 || {
          echo "the key wasn't posted: $(tail -1 "$file")" >&2
          break
        }
      done
      use_section 44-keys "Step 4: the keyboard (C10)"
      out "- walk $surface ($(clock)): $n Tabs, $(grep -c '^focused' "$file" || true) focused elements read (logs/keys/$surface.txt on the Mac)"
      echo "READ $file"
      ;;
    tab | shift-tab | left | right | up | down)
      ui_run key "$1"
      ;;
    space | return)
      [ "${2:-}" = --on ] && [ -n "${3:-}" ] || fail "usage: $SCRIPT keys $1 --on <the focused element's label>"
      ui_run key "$1" --on "$3"
      ;;
    *) fail "usage: $SCRIPT keys walk <surface> [<n>] | keys <tab|shift-tab|left|right|up|down> | keys <space|return> --on <text>" ;;
  esac
}

# display-shots <tag>: Stage 1.4's pass (A11Y-02, PLAN.md §6.4 step 6), after the session switched
# one display option by computer use (`change` first): the main window, the compact window (Window
# to open set to compact through defaults while BatteryPulse is quit, and back) and the popover,
# into shots/display/<tag>-<window>.png.
step_display_shots() {
  r_only display-shots
  local tag="${1:-}"
  case "$tag" in "" | *[!A-Za-z0-9._-]*) fail "usage: $SCRIPT display-shots <tag>" ;; esac
  relaunch_r
  open_main
  place_window
  park_pointer
  window_shot "$SHOTS/display/$tag-main.png" >/dev/null || not_checked "R-display-$tag" "no shot of the main window"
  quit_app
  session_settings
  set_default prefersCompactWindow -bool true
  launch_r
  open_main
  sleep 2
  front_shot "$SHOTS/display/$tag-compact.png" >/dev/null || not_checked "R-display-$tag" "no shot of the compact window"
  quit_app
  session_settings
  launch_r
  popover_shot "$SHOTS/display/$tag-popover.png" >/dev/null || not_checked "R-display-$tag" "no shot of the popover"
  park_pointer
  use_section 46-display "Step 6: the display options (A11Y-02)"
  out "- $tag ($(clock)): the main window, the compact window and the popover"
  echo "LOOK $SHOTS/display/$tag-main.png $SHOTS/display/$tag-compact.png $SHOTS/display/$tag-popover.png"
}

# rl_or_d3 <command>: a command the look shoot, Session R8 and the after-publishing check share.
rl_or_d3() { [ "$SESSION" = R ] || [ "$SESSION" = L ] || [ "$SESSION" = D3 ] || fail "$1 runs in Session R8, the look shoot or the after-publishing check"; }

# MARK: - The widget's feed (P71's W-17 item 7; G71-2)

# The feed's runs (feed.tsv): when, the moment, the file's modification time, its writtenAt, and
# when again in seconds since 1970.
FEED_RUNS="$WORK/feed.tsv"

# mode_of <path>: its permission bits in octal ("600"); GNU stat first, as mtime_of.
mode_of() { stat -c %a "$1" 2>/dev/null || stat -f %Lp "$1" 2>/dev/null || echo -; }

# feed_facts <file>: the feed's public facts as words, from W-5's format (WidgetFeed.encoded:
# compact JSON, sorted keys, dates in seconds since 1970): bytes, version, written (writtenAt),
# days (the day series' steps with a charge), devices, named (devices with a name: a count, never
# a name), forbidden (a udid, serial or ECID key, which the format never holds), demo (Demo Mode's
# device key), reads (readsDevices), records (recordsHistory); "missing" without the file.
feed_facts() {
  local file="$1" day
  if [ ! -f "$file" ]; then
    echo missing
    return 0
  fi
  day="$(sed -n 's/.*"day":{[^}]*"percent":\[\([^]]*\)\].*/\1/p' "$file" | head -1)"
  printf 'bytes=%s version=%s written=%s days=%s devices=%s named=%s forbidden=%s demo=%s reads=%s records=%s\n' \
    "$(wc -c <"$file" | tr -d ' ')" \
    "$(grep -o '"version":[0-9]*' "$file" | head -1 | cut -d: -f2)" \
    "$(grep -o '"writtenAt":[0-9.]*' "$file" | head -1 | cut -d: -f2 | cut -d. -f1)" \
    "$(tr ',' '\n' <<<"$day" | grep -c -v -x -e null -e '' || true)" \
    "$(grep -o '"key":"[0-9a-z-]*"' "$file" | grep -c . || true)" \
    "$(grep -o '"name":"' "$file" | grep -c . || true)" \
    "$(grep -o -i -E '"(udid|uniquedeviceid|serial[a-z]*|ecid|uniquechipid)"[[:space:]]*:' "$file" | grep -c . || true)" \
    "$(grep -o '"key":"demo"' "$file" | grep -c . || true)" \
    "$(grep -o '"readsDevices":[a-z]*' "$file" | head -1 | cut -d: -f2)" \
    "$(grep -o '"recordsHistory":[a-z]*' "$file" | head -1 | cut -d: -f2)"
}

# fact <facts> <name>: one word's value of feed_facts.
fact() { tr ' ' '\n' <<<"$1" | sed -n "s/^$2=//p" | head -1; }

# feed_languages: the languages the app wrote for the widget (W-15), as the feed holds them.
feed_languages() { grep -o '"languages":\[[^]]*\]' "$FEED_FILE" 2>/dev/null | head -1 | sed 's/^"languages"://' || echo none; }

# feed_problems <facts>: what of the file breaks W-5's promises (the modes, the version, the size,
# no udid, serial or demo key), one phrase each; nothing when it keeps them.
feed_problems() {
  local facts="$1" bytes
  [ "$(mode_of "$FEED_DIR")" = 700 ] || echo "the folder is $(mode_of "$FEED_DIR"), not 700"
  [ "$(mode_of "$FEED_FILE")" = 600 ] || echo "the file is $(mode_of "$FEED_FILE"), not 600"
  [ "$(fact "$facts" version)" = 1 ] || echo "version $(fact "$facts" version), not 1"
  bytes="$(fact "$facts" bytes)"
  [ "${bytes:-0}" -le 32768 ] || echo "$bytes bytes, over 32 KB"
  [ "$(fact "$facts" forbidden)" = 0 ] || echo "a udid, serial or ECID key"
  [ "$(fact "$facts" demo)" = 0 ] || echo "Demo Mode's device"
}

# widget_entitlements: the installed widget's signed entitlements (codesign, as build-app.sh's
# posture check reads them) into ENTITLEMENTS: "sandbox <yes|no>; read-only paths <n> (<paths>);
# other keys <keys>"; ENTITLEMENTS_OK is yes when they are the sandbox and the one read-only path
# of Widget/. Globals, not output: a command substitution would keep them in its subshell.
ENTITLEMENTS=""
ENTITLEMENTS_OK=no
widget_entitlements() {
  local file="$LOGS/widget-entitlements.plist" sandbox paths others
  ENTITLEMENTS_OK=no
  mkdir -p "$LOGS"
  rm -f "$file"
  codesign -d --entitlements - --xml "$WIDGET_APPEX" >"$file" 2>/dev/null || true
  if [ ! -s "$file" ] || ! plutil -convert xml1 "$file" 2>/dev/null; then
    ENTITLEMENTS="unread (codesign -d --entitlements of $(basename "$WIDGET_APPEX"))"
    return 0
  fi
  # The value on the key's line or the next (plutil writes it on the next).
  sandbox="$(awk '/<key>com\.apple\.security\.app-sandbox<\/key>/ { if (!index($0, "<true/>")) getline; print (index($0, "<true/>") ? "yes" : "no"); exit }' "$file")"
  paths="$(awk -v key="<key>$FEED_EXCEPTION_KEY</key>" 'index($0, key) { inside = 1; next }
    inside && /<\/array>/ { exit } inside && /<string>/ { s = $0; sub(/.*<string>/, "", s); sub(/<\/string>.*/, "", s); print s }' "$file")"
  others="$(grep -o '<key>[^<]*</key>' "$file" | sed 's/<[^>]*>//g' |
    grep -v -x -F -e com.apple.security.app-sandbox -e "$FEED_EXCEPTION_KEY" | tr '\n' ' ' | sed 's/ $//' || true)"
  if [ "${sandbox:-no}" = yes ] && [ "$paths" = "$FEED_ENTITLED_PATH" ] && [ -z "$others" ]; then ENTITLEMENTS_OK=yes; fi
  ENTITLEMENTS="sandbox ${sandbox:-no}; read-only paths $(grep -c . <<<"$paths" || true) ($(tr '\n' ' ' <<<"$paths" | sed 's/ $//')); other keys ${others:-none}"
}

# feed_logs_since <time>: BatteryPulse's own feed lines since then, as counts, into FEED_LOGS: the
# app's writes and their reasons and the widget's rejections and open failures (`log show`: notice
# lines), and the widget's reads (debug lines, only in this session's stream). FEED_TROUBLE is the
# sum of the rejections and failures, FEED_REASONS the reasons of the immediate writes logged
# (WidgetFeed.WriteReason's case names, one per word: `devices`, `historyCleared`, ...). A routine
# write (`step`, every 15 minutes and at a launch) logs only its signpost's debug line, which `log
# show` never has (Session F read 0 writes after RC-U's launch wrote the file, AC71's F rows): the
# feed's writtenAt is its sign, never a log line.
FEED_LOGS=""
FEED_TROUBLE=0
FEED_READS=unknown
FEED_REASONS=""
feed_logs_since() {
  local since="$1" lines reads stream=""
  log_since "$since" "$WIDGET_PREDICATE AND eventMessage CONTAINS \"widget feed\"" "$LOGS/feed-since.ndjson" >/dev/null
  lines="$(messages "$LOGS/feed-since.ndjson")"
  FEED_TROUBLE="$(grep -c -E 'widget feed was rejected|widget feed failed' <<<"$lines" || true)"
  FEED_REASONS="$(grep -o 'Wrote the widget feed ([a-zA-Z]*)' <<<"$lines" | sed 's/.*(\(.*\))/\1/' | sort -u | tr '\n' ' ' || true)"
  if [ -s "$GUI_STREAM" ]; then stream="$GUI_STREAM"; fi
  if [ -n "$stream" ]; then
    reads="$(entries "$stream" | awk -F '\t' -v s="$since" '$1 >= s && $2 == "BatteryPulseWidget" && index($3, "Read the widget feed") { n++ } END { print n + 0 }')"
  else
    reads="unknown (no stream)"
  fi
  FEED_READS="${reads%% *}"
  FEED_LOGS="since $since: writes logged (a routine step write logs none: writtenAt shows it) $(grep -c -F 'Wrote the widget feed' <<<"$lines" || true) ($(grep -o 'Wrote the widget feed ([a-zA-Z]*)' <<<"$lines" | sed 's/.*(\(.*\))/\1/' | sort | uniq -c | awk '{ printf "%s%s %s", sep, $2, $1; sep = ", " }' || true)), the widget's reads $reads, rejections $(grep -c -F 'widget feed was rejected' <<<"$lines" || true) ($(grep -o 'widget feed was rejected: [a-zA-Z]*' <<<"$lines" | sed 's/.*: //' | sort -u | tr '\n' ' ' | sed 's/ $//' || true)), open or read failures $(grep -c -F 'widget feed failed' <<<"$lines" || true) ($(grep -o -E 'failed: (errno|code) -?[0-9]+' <<<"$lines" | sed 's/^failed: //' | sort -u | tr '\n' ' ' | sed 's/ $//' || true))"
}

# feed_denials_since <time>: the sandbox's denials of BatteryPulseWidget since then, counted (all,
# and those of the feed's folder) into FEED_DENIALS_LINE and FEED_DENIALS; the lines, which name
# his home folder, stay in logs/. The predicate is [unverified] on macOS 27: 0 may also mean it
# matches nothing.
FEED_DENIALS_LINE=""
FEED_DENIALS=0
feed_denials_since() {
  log_since "$1" 'eventMessage CONTAINS "Sandbox: BatteryPulseWidget" AND eventMessage CONTAINS "deny"' "$LOGS/feed-denials.ndjson" >/dev/null
  messages "$LOGS/feed-denials.ndjson" >>"$LOGS/feed-denials.txt" 2>/dev/null || true
  feed_denials_count "$1" "$LOGS/feed-denials.ndjson"
}

# feed_denials_count <time> <ndjson>: feed_denials_since's counts from what `log show` found. The
# predicate reads eventMessage alone, so it also matches each `log` run's own line since then
# (not_log_tool), which Session F counted as its one denial; those are left out and counted apart.
feed_denials_count() {
  local lines all
  lines="$(not_log_tool "$2")"
  all="$(grep -c . <<<"$lines" || true)"
  FEED_DENIALS="${all:-0}"
  FEED_DENIALS_LINE="sandbox denials of BatteryPulseWidget since $1: ${all:-0}, of them in Widget/: $(grep -c -F '/Widget/' <<<"$lines" || true) ($(($(entry_count "$2") - ${all:-0})) of the log tool's own left out; logs/feed-denials.txt on the Mac; the predicate is unverified)"
}

# feed_record <moment> <facts>: the run's line of feed.tsv.
feed_record() {
  mkdir -p "$WORK"
  printf '%s\t%s\t%s\t%s\t%s\n' "$(clock)" "$1" "$(if [ -f "$FEED_FILE" ]; then mtime_of "$FEED_FILE"; else echo -; fi)" \
    "$(fact "$2" written)" "$(date +%s)" >>"$FEED_RUNS"
}

# feed_run <moment>: that moment's line of feed.tsv, else the last run's.
feed_run() { awk -F '\t' -v m="${1:-}" 'm == "" || $2 == m { l = $0 } END { print l }' "$FEED_RUNS" 2>/dev/null || true; }

# feed_verdict <id> y|n|unsure|<n> <note> [<evidence>]: the script's own reading of an objective
# check, recorded as the session's; unsure joins his batch with the evidence's path (the feed by
# default).
feed_verdict() {
  local id="$1" value="$2" note="$3"
  english_only "$note"
  if [ "$value" = unsure ]; then
    printf '%s\t%s\t%s\t%s\n' "$id" "$value" "$(printf '%s' "$note" | tr '\t\n' '  ')" "${4:-$FEED_FILE}" >>"$BATCH"
    note="for his batch: $note"
  fi
  step_answer --by claude "$id" "$value" "$note" >/dev/null
  echo "$id: $value ($note)"
}

# feed_wait_rewrite <since> [reads=<true|false>]: up to 60 s for a writtenAt at or after that time
# (seconds since 1970; and readsDevices as asked); prints the facts then; true when it came.
feed_wait_rewrite() {
  local before="${1:-0}" want="${2:-}" waited=0 facts written
  while :; do
    facts="$(feed_facts "$FEED_FILE")"
    written="$(fact "$facts" written)"
    if [ -n "$written" ] && [ "$written" -ge "${before:-0}" ] 2>/dev/null &&
      { [ -z "$want" ] || [ "reads=$(fact "$facts" reads)" = "$want" ]; }; then
      echo "$facts"
      return 0
    fi
    [ "$waited" -lt 60 ] || break
    sleep 2
    waited=$((waited + 2))
  done
  echo "$facts"
  return 1
}

# usb_device_count: iPhones and iPads on a cable (the USB tree's product names; no name of his).
usb_device_count() { ioreg -p IOUSB -w0 2>/dev/null | grep -c -E '\+-o (iPhone|iPad)[@ ]' || true; }

# set_reads <on|off>: Read iPhone and iPad batteries, by AX in BatteryPulse's Settings → General,
# pressed only when the setting isn't that already (so a second call never turns it back); prints
# the time of the press, in seconds since 1970, when it pressed.
set_reads() {
  local want=1 now
  if [ "$1" = off ]; then want=0; fi
  now="$(defaults read "$BUNDLE_ID" readDevices 2>/dev/null || echo 0)"
  [ "$now" != "$want" ] || return 0
  date +%s
  ui_run press BatteryPulse --menu-cmd , >/dev/null 2>&1 || return 1
  sleep 2
  ui_run press BatteryPulse General >/dev/null 2>&1 || true
  sleep 1
  ui_run press BatteryPulse "Read iPhone and iPad batteries" >/dev/null 2>&1 || return 1
  sleep 1
  close_front_window || true
}

# feed <moment>: the widget's feed (W-5) at the moments P71's W-17 item 7 names, each with the
# folder's and file's modes, the size, the version, writtenAt's age, no udid, serial or demo key,
# the device count (no name), the widget's signed entitlements, its sandbox denials and the feed's
# log lines since the last run. The script reads each verdict itself:
#   before      under his 0.7.1, before RC-U: 0.7.1's file, its modes and
#               version (0.7.0 wrote none; 0.7.1 does at every 15-minute step)  R-feed-before
#   history     within 15 minutes of the first History widget                   R-feed-history
#   cold        BatteryPulse quit and the extension ended, then a relaunch that
#               writes the feed while no widget process runs and reloads every
#               kind: the new extension's first read of it                      R-feed-cold
#   demo-start, demo-end   in step 9b's Demo Mode: the file untouched           R-feed-demo
#   reads-on, reads-off    Read iPhone and iPad batteries on, then off (by AX;
#               never with an iPhone or iPad on a cable): rewritten at once     R-feed-reads
#   cleared     after Clear History on the session's own data (change history
#               first): rewritten at once, with an empty day                    R-feed-cleared
# A rewrite "at once" is a writtenAt after the press (the history change's record for cleared), or
# the app's own line for it (Wrote the widget feed (devices), (historyCleared)) since the last run,
# so a slow computer-use clear or a toggle by computer use still reads as what it was.
#   check       after publishing: the modes, the version, the exception         D3-feed
# Never Forget a device: the devices are his.
step_feed() {
  local moment="${1:-}" since facts problems="" age written threshold pressed before mtime note value start minutes at
  case "$SESSION:$moment" in
    R:before | R:history | R:cold | R:demo-start | R:demo-end | R:reads-on | R:reads-off | R:cleared | D3:check) ;;
    *) fail "usage: $SCRIPT feed before | history | cold | demo-start | demo-end | reads-on | reads-off | cleared (Session R8; after publishing: check)" ;;
  esac
  mkdir -p "$LOGS"
  use_section 25-feed "The widget's feed (G71-2; W-17 item 7)"
  since="$(feed_run | cut -f1)"
  [ -n "$since" ] || since="$(cat "$WORK/prepare.time" 2>/dev/null || clock)"
  # A rewrite "at once" is one written in the last minute, after this call's own press, or after
  # the history change's record.
  threshold=$(($(date +%s) - 60))
  case "$moment" in
    reads-on | reads-off)
      if [ "$moment" = reads-on ]; then
        [ "$(usb_device_count)" = 0 ] || {
          not_checked R-feed-reads "an iPhone or iPad is on a cable: reads stay off, so none of his is read and remembered"
          return 0
        }
        [ -n "$(original_of remembered-devices)" ] || record_change remembered-devices none "none during the GUI phase"
      fi
      # No run is recorded until the toggle moved, so the rerun reads the app's line since the run before.
      if ! pressed="$(set_reads "${moment#reads-}")"; then
        echo "DO (session): the AX press didn't reach the toggle: turn Read iPhone and iPad batteries ${moment#reads-} in BatteryPulse's Settings → General by computer use, then $SCRIPT feed $moment again"
        return 0
      fi
      [ -z "$pressed" ] || threshold="$pressed"
      ;;
    cleared)
      # Recorded now if the session didn't before the clear: the backup holds his history either
      # way, and only this record makes restore gui put it back (and restore end keep the backup's).
      if [ -z "$(original_of history)" ]; then
        warn "Clear History's change wasn't recorded before the clear: recorded now, so restore gui puts his history back from the backup"
        record_change history "his, in the backup" cleared
      fi
      at="$(awk -F '\t' '$1 == "history" { t = $4 } END { print t }' "$CHANGES")"
      at="$(date -j -f '%Y-%m-%d %H:%M:%S' "$at" +%s 2>/dev/null || echo "$threshold")"
      if [ "$at" -lt "$threshold" ]; then threshold="$at"; fi
      ;;
    cold)
      end_widget_extension_and_wait >/dev/null
      start="$(clock)"
      if relaunch_for_redraw_reading "$LOGS/feed-cold.ndjson"; then :; fi
      out "- cold ($start): $REDRAW"
      ;;
  esac
  case "$moment" in
    reads-on | reads-off | cleared)
      if [ "$moment" = cleared ]; then
        facts="$(feed_wait_rewrite "$threshold")" && value=rewritten || value="not rewritten within a minute"
      else
        facts="$(feed_wait_rewrite "$threshold" "reads=$(if [ "$moment" = reads-on ]; then echo true; else echo false; fi)")" &&
          value=rewritten || value="not rewritten within a minute"
      fi
      ;;
    *) facts="$(feed_facts "$FEED_FILE")" ;;
  esac
  written="$(fact "$facts" written)"
  age="-"
  if [ -n "$written" ]; then age=$(($(date +%s) - written)); fi
  if [ "$facts" = missing ]; then
    out "- $moment ($(clock)): no $(basename "$FEED_FILE") ($(if [ -d "$FEED_DIR" ]; then echo "Widget/ is there, $(mode_of "$FEED_DIR")"; else echo "no Widget/ folder"; fi)); $(app_version)"
  else
    problems="$(feed_problems "$facts" | tr '\n' ';' | sed 's/;$//; s/;/; /g')"
    out "- $moment ($(clock)): $(app_version); the folder $(mode_of "$FEED_DIR"), the file $(mode_of "$FEED_FILE"); $(fact "$facts" bytes) bytes, version $(fact "$facts" version), written ${age} s ago; the day's steps with a charge $(fact "$facts" days); devices $(fact "$facts" devices) (named $(fact "$facts" named)); readsDevices $(fact "$facts" reads), recordsHistory $(fact "$facts" records); a udid, serial or ECID key $(fact "$facts" forbidden), Demo Mode's device $(fact "$facts" demo); the languages $(feed_languages)${problems:+; BROKEN: $problems}"
  fi
  widget_entitlements
  out "- the widget's entitlements: $ENTITLEMENTS"
  feed_logs_since "$since"
  out "- the feed's lines $FEED_LOGS"
  if [ "$SESSION" != D3 ]; then
    feed_denials_since "$since"
    out "- $FEED_DENIALS_LINE"
  fi
  out "- the widget extension's processes: $(widget_pids | grep -c . || true)"
  case "$moment" in
    before)
      # 0.7.1 writes the feed at every 15-minute step, whatever is placed: a file, version 1, with
      # its modes, is what his 0.7.1 leaves before RC-U.
      if [ "$facts" = missing ]; then feed_verdict R-feed-before n "no feed.json under $(app_version)"
      elif [ -n "$problems" ]; then feed_verdict R-feed-before n "$problems"
      else feed_verdict R-feed-before y "the feed his $(app_version) wrote, written ${age} s ago, as W-5 made it"
      fi
      ;;
    history | check)
      note=""
      [ "$facts" != missing ] || note="no feed.json"
      [ -z "$problems" ] || note="${note:+$note; }$problems"
      [ "$age" = - ] || [ "$age" -le 900 ] || note="${note:+$note; }written $age s ago"
      [ "$ENTITLEMENTS_OK" = yes ] || note="${note:+$note; }the entitlements aren't the sandbox and Widget/ alone"
      [ "${FEED_TROUBLE:-0}" = 0 ] || note="${note:+$note; }the widget logged a rejection or a failure"
      if [ "$moment" = history ]; then
        minutes="-"
        if [ -f "$WORK/first-history.time" ]; then
          minutes=$((($(date +%s) - $(date -j -f '%Y-%m-%d %H:%M:%S' "$(cat "$WORK/first-history.time")" +%s 2>/dev/null || date +%s)) / 60))
        fi
        out "- the first History widget: $(cat "$WORK/first-history.time" 2>/dev/null || echo "not recorded") ($minutes minutes ago)"
        [ "${FEED_DENIALS:-0}" = 0 ] || note="${note:+$note; }$FEED_DENIALS sandbox denials"
        [ "$FEED_READS" != 0 ] || note="${note:+$note; }the widget logged no read of it since $since"
        if [ -z "$note" ]; then feed_verdict R-feed-history y "every rule kept; the widget's reads: see the section"; else
          feed_verdict R-feed-history n "$note"
        fi
      elif [ -z "$note" ]; then feed_verdict D3-feed y "the modes, the version, the age and the exception as W-5 made them"; else
        feed_verdict D3-feed n "$note"
      fi
      ;;
    cold) feed_cold_verdict "$LOGS/feed-cold.ndjson" ;;
    demo-end)
      before="$(feed_run demo-start)"
      if [ -z "$before" ]; then
        not_checked R-feed-demo "no demo-start run"
      else
        mtime="$(if [ -f "$FEED_FILE" ]; then mtime_of "$FEED_FILE"; else echo -; fi)"
        start="$(cut -f5 <<<"$before")"
        note="from $(cut -f1 <<<"$before") to $(clock)$(if [ $((${start:-0} / 900)) != $(($(date +%s) / 900)) ]; then echo ", across a 15-minute step"; else echo ", within one 15-minute step (only the immediate writes were exercised)"; fi)"
        if [ "$mtime" = "$(cut -f3 <<<"$before")" ] && [ "$written" = "$(cut -f4 <<<"$before")" ]; then feed_verdict R-feed-demo y "untouched $note"; else
          feed_verdict R-feed-demo n "written in Demo Mode $note"
        fi
      fi
      ;;
    reads-on | reads-off)
      # The toggle's own write, logged since the last run, with readsDevices as asked now.
      if [ "$value" != rewritten ] && [ "reads=$(fact "$facts" reads)" = "reads=$(if [ "$moment" = reads-on ]; then echo true; else echo false; fi)" ]; then
        case " $FEED_REASONS " in *" devices "*) value="rewritten (the app's devices write since $since)" ;; esac
      fi
      out "- $moment: $value"
      echo "$moment $value" >>"$WORK/feed-reads.txt"
      if [ "$moment" = reads-off ]; then
        if grep -q '^reads-on rewritten' "$WORK/feed-reads.txt" 2>/dev/null && case "$value" in rewritten*) true ;; *) false ;; esac; then
          feed_verdict R-feed-reads y "rewritten at once on and off"
        else
          feed_verdict R-feed-reads n "$(tr '\n' ';' <"$WORK/feed-reads.txt" | sed 's/;$//; s/;/; /g')"
        fi
      fi
      ;;
    cleared)
      if [ "$value" != rewritten ]; then
        case " $FEED_REASONS " in *" historyCleared "*) value="rewritten (the app's historyCleared write since $since)" ;; esac
      fi
      if case "$value" in rewritten*) true ;; *) false ;; esac && [ "$(fact "$facts" days)" -le 1 ] 2>/dev/null; then
        feed_verdict R-feed-cleared y "$value, $(fact "$facts" days) steps of the day with a charge"
      else
        feed_verdict R-feed-cleared n "$value, $(fact "$facts" days) steps of the day with a charge"
      fi
      ;;
  esac
  feed_record "$moment" "$facts"
}

# relaunch_for_redraw_reading <capture>: relaunch_for_redraw after a lastSeenLanguage that differs,
# waiting also for the widget's first read of the feed (its debug line).
relaunch_for_redraw_reading() {
  local status=0
  REDRAW_ALSO="Read the widget feed"
  relaunch_for_redraw "$1" launch_redraw || status=$?
  REDRAW_ALSO=""
  return "$status"
}

# feed_cold_verdict <capture>: from the capture's order: the app's feed write (its perf interval)
# before the widget's first line, and the widget's read after it, with no rejection or failure.
feed_cold_verdict() {
  local rows write first read trouble
  rows="$(entries "$1")"
  write="$(awk -F '\t' '$2 == "BatteryPulse" && index($3, "perf interval widget.feed.write") { print $1; exit }' <<<"$rows")"
  first="$(awk -F '\t' '$2 == "BatteryPulseWidget" { print $1; exit }' <<<"$rows")"
  read="$(awk -F '\t' -v w="$write" '$2 == "BatteryPulseWidget" && $1 >= w && index($3, "Read the widget feed") { print $1; exit }' <<<"$rows")"
  trouble="$(awk -F '\t' '$2 == "BatteryPulseWidget" && (index($3, "widget feed was rejected") || index($3, "widget feed failed")) { n++ } END { print n + 0 }' <<<"$rows")"
  out "- cold: the app's write at ${write:-none}; the extension's first line at ${first:-none}; its read at ${read:-none}; rejections and failures $trouble"
  if [ "$trouble" != 0 ]; then
    feed_verdict R-feed-cold n "the widget logged $trouble rejections or failures"
  elif [ -n "$write" ] && [ -n "$first" ] && [ -n "$read" ] && [[ "$write" < "$first" ]]; then
    feed_verdict R-feed-cold y "written while no widget process ran, then read"
  elif [ -n "$read" ]; then
    feed_verdict R-feed-cold unsure "read, but the extension started before the write (the order: write ${write:-none}, extension ${first:-none})"
  else
    feed_verdict R-feed-cold unsure "no read line within 90 s of the relaunch"
  fi
}

# MARK: - Maximum capacity against macOS's (P71's W-17 item 18), crashes and faults, the front window

# battery_key <capture> <key> data|top: a key of AppleSmartBattery in a `bpulse --raw` capture,
# looked for in its BatteryData first (data) or at its top (top), then in the other, then in its
# registry children's BatteryData and its LifetimeData, the pack's first: on macOS 27 the M5 keeps
# AppleRawMaxCapacity and LifetimeData.CycleCountLastQmax only there (the m5-macos27-* fixtures
# with children); "-" when none holds it.
battery_key() {
  local path child paths="BatteryData.$2 $2"
  if [ "$3" = top ]; then paths="$2 BatteryData.$2"; fi
  for child in 0 1 2 3; do
    paths="$paths IORegistryEntryChildren.$child.BatteryData.$2 IORegistryEntryChildren.$child.BatteryData.LifetimeData.$2"
  done
  for path in $paths; do
    plutil -extract "AppleSmartBattery.$path" raw -o - "$1" 2>/dev/null && return 0
  done
  echo -
}

# percent_of <part> <whole>: part / whole in percent, to two places, or "-".
percent_of() { awk -v a="$1" -v b="$2" 'BEGIN { if (a ~ /^[0-9.]+$/ && b ~ /^[0-9.]+$/ && b > 0) printf "%.2f", a * 100 / b; else print "-" }'; }

# capacity <start|day-end|after> (W-17 item 18, the maintainer's question of 2026-10-31): one
# reading of maximum capacity, BatteryPulse's against macOS's, at the GUI phase's start, at the
# day's end and after publishing (a few days apart): a capture's numbers (bpulse --raw, which stays
# on the Mac: NominalChargeCapacity, AppleRawMaxCapacity, DesignCapacity, MaxCapacity, CycleCount,
# CycleCountLastQmax), BatteryPulse's Health line (bpulse) and system_profiler SPPowerDataType's
# "Maximum Capacity"; the session adds System Settings → Battery → Battery Health's figure from its
# shot. By hand without a session (bash docs/plans/0.8.0/m5-session.sh capacity <tag>, from the
# checkout, with bpulse built there: swift build -c release --product bpulse), the reading goes to
# ~/bp-capacity on the Mac only, as quick-check.sh's report does.
step_capacity() {
  local tag="${1:-}" id="" bp folder capture nominal raw design max cycles qmax health profiler row
  case "$SESSION:$tag" in
    R:start | R:day-end) id="R-capacity-$tag" ;;
    D3:after) id=D3-capacity ;;
    none:*) case "$tag" in "" | *[!A-Za-z0-9._-]*) fail "usage: $SCRIPT capacity <tag> (letters, digits, dots, dashes)" ;; esac ;;
    *) fail "usage: $SCRIPT capacity start | day-end (Session R) | after (after publishing); by hand: capacity <tag>" ;;
  esac
  [ "$(uname -s)" = Darwin ] || fail "this runs on the Mac"
  if [ "$SESSION" = none ]; then
    bp="$ROOT/.build/release/bpulse"
    [ -x "$bp" ] || fail "bpulse isn't built: swift build -c release --product bpulse in $ROOT, then capacity again"
    folder="$HOME/bp-capacity"
  else
    build_bpulse
    bp="$BIN/bpulse"
    [ -x "$bp" ] || {
      not_checked "${id:-capacity}" "bpulse isn't built (see $BIN/bpulse.log)"
      return 0
    }
    folder="$LOGS"
  fi
  mkdir -p "$folder"
  capture="$folder/capacity-$tag-$(date '+%Y%m%d-%H%M').plist"
  "$bp" --raw >"$capture" 2>/dev/null || fail "bpulse --raw failed"
  nominal="$(battery_key "$capture" NominalChargeCapacity data)"
  raw="$(battery_key "$capture" AppleRawMaxCapacity top)"
  design="$(battery_key "$capture" DesignCapacity data)"
  max="$(battery_key "$capture" MaxCapacity top)"
  cycles="$(battery_key "$capture" CycleCount top)"
  qmax="$(battery_key "$capture" CycleCountLastQmax data)"
  health="$("$bp" 2>/dev/null | grep -E '^[[:space:]]*Health' | head -1 | sed 's/^[[:space:]]*Health[[:space:]:]*//; s/[[:space:]]*$//' || true)"
  profiler="$(system_profiler SPPowerDataType 2>/dev/null | sed -n 's/^[[:space:]]*Maximum Capacity:[[:space:]]*//p' | head -1 || true)"
  row="| $tag | $(clock) | $nominal ($(percent_of "$nominal" "$design") %) | $raw ($(percent_of "$raw" "$design") %) | $design | $max | $cycles | $qmax | ${health:--} | ${profiler:--} |"
  if [ "$SESSION" = none ]; then
    # One table across the readings, a day or more apart: its header once.
    if [ ! -s "$folder/readings.md" ]; then
      printf '%s\n' "| Reading | Time | NominalChargeCapacity (of design) | AppleRawMaxCapacity (of design) | DesignCapacity | MaxCapacity | CycleCount | CycleCountLastQmax | BatteryPulse's Health | system_profiler's Maximum Capacity |" \
        "|---|---|---|---|---|---|---|---|---|---|" >"$folder/readings.md"
    fi
    printf '%s\n' "$row" >>"$folder/readings.md"
    cat "$folder/readings.md"
    echo "The capture stays in $capture; add System Settings → Battery → Battery Health's figure beside the row."
    return 0
  fi
  use_section 07-capacity "Maximum capacity against macOS's (W-17 item 18)"
  if [ ! -f "$WORK/capacity.header" ]; then
    out "| Reading | Time | NominalChargeCapacity (of design) | AppleRawMaxCapacity (of design) | DesignCapacity | MaxCapacity | CycleCount | CycleCountLastQmax | BatteryPulse's Health | system_profiler's Maximum Capacity |"
    out "|---|---|---|---|---|---|---|---|---|---|"
    touch "$WORK/capacity.header"
  fi
  out "$row"
  echo "DO (session): System Settings → Battery → Battery Health (the (i) beside it) by computer use, a shot, then answer:"
  ask "$id"
}

# faults: the crash reports of BatteryPulse and its widget and the subsystem's fault messages
# since prepare, which must be 0 (G7-16, G8-10): the look shoot's last read, Session R8's at day-end.
step_faults() {
  local faults
  [ -f "$WORK/prepare.marker" ] || fail "prepare hasn't run in $WORK"
  use_section 80-faults "Crash reports and faults since prepare (G7-16)"
  out "- crash reports since prepare (BatteryPulse and BatteryPulseWidget; must be 0):"
  crash_summary "$WORK/prepare.marker"
  faults="$(log_since "$(cat "$WORK/prepare.time")" "$FAULT_PREDICATE" "$LOGS/faults.ndjson")"
  out "- fault messages in the subsystem since prepare: $faults (must be 0)"
  if [ "${faults:-0}" -gt 0 ]; then
    messages "$LOGS/faults.ndjson" | head -10 | public >"$LOGS/faults.txt"
    out_block "$LOGS/faults.txt"
  fi
}

# front <name>: BatteryPulse's front window (Settings, a pane scrolled to its end, the Welcome
# window) by its AX frame into shots/front/<name>.png, a crop attach takes (step 10, S-1).
step_front() {
  [ $# -eq 1 ] || fail "usage: $SCRIPT front <name>"
  case "$1" in *[!A-Za-z0-9._-]*) fail "a name is letters, digits, dots, dashes and underscores" ;; esac
  front_shot "$SHOTS/front/$1.png"
}

# MARK: - Session R8: the extras (WP-18, the menu bar, Raw Data to History)

# raw-history rc: Session B's finding (1): a pointer-free switch from Raw Data to History by AX
# selection, the main window shot 0.3 s, 2 s and 8 s after it: does History show its title over Raw
# Data's table first? On the candidate only: W-3c's fix shipped in 0.7.0, so 0.7's base run went.
step_raw_history() {
  r_only raw-history
  local tag="${1:-}"
  case "$tag" in rc) ;; *) fail "usage: $SCRIPT raw-history rc" ;; esac
  app_running || launch_r
  open_main
  place_window
  select_page "Raw Data" || not_checked "R-raw-history-$tag" "Raw Data wasn't selected"
  sleep 3
  park_pointer
  ui_run select-row BatteryPulse History --within AXOutline >/dev/null 2>&1 ||
    not_checked "R-raw-history-$tag" "History wasn't selected by AX"
  sleep 0.3
  window_shot "$SHOTS/raw-history/$tag-0.3s.png" || true
  sleep 1.7
  window_shot "$SHOTS/raw-history/$tag-2s.png" || true
  sleep 6
  window_shot "$SHOTS/raw-history/$tag-8s.png" || true
  use_section 60-raw-history "Raw Data to History without the pointer (Session B's finding 1)"
  out "- $tag: $(app_version) ($(clock))"
  ask "R-raw-history-$tag"
}

# menubar [contrast | transparency]: the menu bar item on a light and a dark bar (V01-menubar's
# dark half, C-1; with contrast or transparency, A11Y-04's: after the session turned Increase
# Contrast or Reduce Transparency on, `change` first): scripts/menu-bar-shots.sh's light and dark
# looks (it sets the appearance and a plain wallpaper and puts both back itself), then each
# main-display shot cropped to the item's AX frame (P11) with 4 points around it.
step_menubar() {
  r_only menubar
  local screen width scale file rect x y w h tag="v01" id=V01-menubar
  case "${1:-}" in
    "") ;;
    contrast | transparency) tag="$1" id=R-menubar-a11y ;;
    *) fail "usage: $SCRIPT menubar [contrast | transparency]" ;;
  esac
  [ -s "$WORK/status-item" ] || fail "no menu bar item frame (proof P11): $id is not checked"
  run_menu_bar_shots "$tag" --looks light,dark ||
    not_checked "$id" "menu-bar-shots.sh didn't finish (logs/menubar-$tag.txt on the Mac), or prepare didn't read the appearance or the wallpaper"
  relaunch_r
  screen="$(ui_run screen 2>/dev/null || true)"
  width="$(sed -n 's/^main=[-0-9]* [-0-9]* \([0-9]*\) .*/\1/p' <<<"$screen")"
  scale="$(sed -n 's/.* scale=\([0-9.]*\).*/\1/p' <<<"$screen")"
  [ -n "$width" ] && [ -n "$scale" ] || fail "the display's size can't be read"
  rect="$(cat "$WORK/status-item")"
  # The strip is the right half of the display's shot, 120 px high (menu-bar-shots.sh's crop).
  read -r x y w h <<<"$(awk -v r="$rect" -v W="$width" -v s="$scale" 'BEGIN {
    split(r, a, " "); px = int(W * s); left = px - int(px / 2)
    x = int((a[1] - 4) * s) - left; if (x < 0) x = 0
    h = int((a[2] + a[4] + 4) * s); if (h > 120) h = 120
    printf "%d %d %d %d", x, 0, int((a[3] + 8) * s), h }')"
  for file in "$SHOTS"/menubar/"$tag"-*-d1.png; do
    [ -f "$file" ] || continue
    "$BIN/frames" crop "$file" "$x" "$y" "$w" "$h" "${file%.png}-item.png" >/dev/null 2>&1 &&
      register_shot "${file%.png}-item.png" && echo "LOOK ${file%.png}-item.png"
  done
  use_section 65-menubar "The menu bar item on a light and a dark bar (V01-menubar, A11Y-04)"
  out "- $tag: $(find "$SHOTS/menubar" -name "$tag-*-item.png" | grep -c . || true) crops at the item's AX frame ($rect), from menu-bar-shots.sh's light and dark looks"
  ask "$id"
}

# menu-bar-shots before | after [arguments]: scripts/menu-bar-shots.sh into shots/menubar, W-11's
# pixel check of the painter it moved into BatteryArt: before on 0.6.2 (step 2's first half, whose
# painter it is), after on the candidate (the extras), then each after shot against its before shot.
step_menu_bar_shots() {
  r_only menu-bar-shots
  local file pair same=0 differ=0 missing=0 compared
  case "${1:-}" in before | after) ;; *) fail "usage: $SCRIPT menu-bar-shots before | after [--charge] [--looks <list>]" ;; esac
  run_menu_bar_shots "$@" || fail "menu-bar-shots.sh didn't finish (logs/menubar-$1.txt), or prepare didn't read the appearance or the wallpaper"
  relaunch_r
  [ "$1" = after ] || return 0
  use_section 66-menu-bar-same "The menu bar painter, $START_VERSION against RC-U (W-11's pixel check)"
  for file in "$SHOTS"/menubar/after-*.png; do
    [ -f "$file" ] || continue
    pair="$SHOTS/menubar/before-${file#"$SHOTS"/menubar/after-}"
    if [ ! -f "$pair" ]; then
      missing=$((missing + 1))
      continue
    fi
    compared="$("$BIN/frames" diff "$pair" "$file" 2>/dev/null || true)"
    if grep -q 'identical=yes' <<<"$compared"; then
      same=$((same + 1))
    else
      differ=$((differ + 1))
      echo "LOOK $pair against $file ($(sed -n 's/.*changed_pct=\([^ ]*\).*/\1/p' <<<"$compared" | head -1) % of its pixels changed)"
    fi
  done
  # The crops are the right half of the menu bar: the clock, the system's battery item and a charge
  # that moved change between the two runs hours apart, so a pair that differs is read by eye, its
  # BatteryPulse item against the other's.
  out "- after against before, per look and style: $same identical, $differ with changed pixels (the clock and the system's items are in each crop: BatteryPulse's item is compared by eye), $missing without a before shot"
  ask R-menu-bar-same
}

# run_menu_bar_shots <tag> [arguments]: scripts/menu-bar-shots.sh into shots/menubar. Per look it
# sets the appearance and a plain wallpaper, and puts both back itself when it ends; both are his
# settings, so each goes into changes.tsv first, and only when prepare read it (an unread one is
# never changed). After the run each is read back against the backup and marked restored, else
# restore gui lists it for the session: Auto appearance comes back only by hand (the tool says so),
# and a dynamic wallpaper may come back as a still picture, which the restored line says for his
# summary.
run_menu_bar_shots() {
  local dark auto now_auto status=0
  dark="$(cat "$BACKUP/dark-mode" 2>/dev/null || echo unknown)"
  auto="$(cat "$BACKUP/auto-appearance" 2>/dev/null || echo 0)"
  case "$dark" in
    true | false) ;;
    *)
      echo "the appearance wasn't read at prepare: never changed" >&2
      return 1
      ;;
  esac
  if [ ! -s "$BACKUP/wallpapers" ]; then
    echo "the wallpaper wasn't read at prepare: never changed" >&2
    return 1
  fi
  record_change appearance "dark mode $dark, automatic $auto" "the light and dark looks of menu-bar-shots.sh"
  record_change wallpaper "his ($(grep -c . "$BACKUP/wallpapers" || true) desktops, the paths in the backup)" \
    "plain light and dark wallpapers of menu-bar-shots.sh"
  mkdir -p "$SHOTS/menubar" "$LOGS"
  bash "$ROOT/scripts/menu-bar-shots.sh" "$SHOTS/menubar" "$@" >"$LOGS/menubar-$1.txt" 2>&1 </dev/null || status=$?
  now_auto="$(defaults read -g AppleInterfaceStyleSwitchesAutomatically 2>/dev/null || echo 0)"
  if [ "$(is_dark)" = "$dark" ] && [ "$now_auto" = "$auto" ]; then
    mark_restored appearance "script: menu-bar-shots.sh put it back, read back by System Events"
  else
    warn "the appearance isn't as prepare read it (dark mode $(is_dark), automatic $now_auto): restore gui lists it"
  fi
  if [ "$(wallpapers)" = "$(cat "$BACKUP/wallpapers")" ]; then
    mark_restored wallpaper "script: menu-bar-shots.sh put the pictures back, read back by System Events (a dynamic wallpaper may stay still until he picks it again)"
  else
    warn "the wallpaper isn't as prepare read it: restore gui lists it"
  fi
  return "$status"
}

# wp18 previews | timing: WP-18's items 0.6.2 left (C-1), through the script's one prefix: the
# package in Xcode for SUI-17's canvas, and SUI-19's type-check timing (local only).
step_wp18() {
  r_only wp18
  local build="$WORK/wp18-build"
  case "${1:-}" in
    previews)
      (cd "$ROOT" && track_launch Xcode xed .) || fail "xed couldn't open the package"
      echo "Xcode opens the package: resume the canvas by computer use; an Install Required dialog is not checked: prompt"
      ;;
    timing)
      begin_section 85-wp18 "WP-18: SUI-19's type-check timing"
      (cd "$ROOT" && xcrun swift build -c debug --scratch-path "$build" -j 2 -Xswiftc -debug-time-function-bodies) \
        >"$LOGS/sui19.txt" 2>&1 || out "- the build failed (see logs/sui19.txt on the Mac)"
      grep -E '^[0-9]+\.[0-9]+ms' "$LOGS/sui19.txt" | sort -n -r | head -5 >"$LOGS/sui19-top.txt" || true
      out "- the 5 slowest bodies (ms, file:line, the declaration):"
      out_block "$LOGS/sui19-top.txt"
      ;;
    *) fail "usage: $SCRIPT wp18 previews | timing" ;;
  esac
}

# MARK: - Session R8: the arm window, ready and the logged day (step 13; §6.5)

ARM_PID=""
ARM_START=""
ARM_GUI_CAFFEINATE=""
ARM_READY_WAITER=""
ARM_SHOWN=""

# arm open: writes ~/bp-080/R/arm.command and opens it in a new Terminal window (open -a Terminal:
# no Automation needed). The window runs the frozen worktree's script.
arm_open() {
  r_fence
  mkdir -p "$WORK"
  cat >"$WORK/arm.command" <<EOF
#!/bin/bash
# BatteryPulse Session R's arm window (PLAN.md §6.3, the logged day), opened by the session.
exec /bin/bash "$HERE/m5-session.sh" arm
EOF
  chmod +x "$WORK/arm.command"
  open -a Terminal "$WORK/arm.command"
  echo "the arm window opens (Terminal, \"BatteryPulse arm\"): it keeps the display awake for the GUI phase and asks for nothing"
}

arm_say() {
  printf '%s %s\n' "$(date '+%H:%M')" "$*"
  printf '%s\t%s\n' "$(clock)" "$*" >>"$LOGS/arm.log"
  ARM_SHOWN=""
}

arm_state() {
  if [ -f "$READY_FILE" ]; then
    echo "ready"
  else
    echo "working: $(cut -f2- "$WORK/state" 2>/dev/null || echo "the session's step isn't known"); the GUI phase ends by $(epoch_hm "$(gui_end_epoch)")"
  fi
}

# arm_wait <seconds>: the status line when it changed, then a wait that a ready post (SIGUSR1)
# ends early; his keys do nothing here.
arm_wait() {
  local reply status
  status="$(arm_state). Nothing to do here; don't press keys in this window."
  if [ "$status" != "$ARM_SHOWN" ]; then
    printf '[%s] %s\n' "$(date '+%H:%M')" "$status"
    ARM_SHOWN="$status"
  fi
  read -r -s -t "$1" reply || true
}

# arm_waiter: the ready post wakes the wait at once (else its 60-second backstop).
arm_waiter() {
  if [ -z "$ARM_READY_WAITER" ] || ! kill -0 "$ARM_READY_WAITER" 2>/dev/null; then
    (notifyutil -1 "$READY_NOTIFY" >/dev/null 2>&1 && kill -USR1 "$ARM_PID" 2>/dev/null) &
    ARM_READY_WAITER=$!
    BACKGROUND="$BACKGROUND $ARM_READY_WAITER"
  fi
}

# arm_heartbeat_stale: 20 minutes without the session's heartbeat or the script's own.
arm_heartbeat_stale() {
  [ -f "$HEARTBEAT" ] || return 1
  [ "$(heartbeat_age)" -gt 1200 ]
}

# day_start: step 12. The GUI phase's display assertion released (its caffeinate ended), so the day
# runs on a Mac that sleeps normally; the logged day's perf stream started under nohup, detached
# from this window (he may close it); the time of each into day.started.
day_start() {
  kill "$ARM_GUI_CAFFEINATE" 2>/dev/null || true
  ARM_GUI_CAFFEINATE=""
  arm_say "the GUI phase's display assertion is released: the Mac sleeps normally from here"
  stream_stop gui-stream
  stream_start day-stream "$DAY_STREAM" >>"$LOGS/arm.log" 2>&1
  printf '%s\t%s\n' "$(clock)" "$(cat "$WORK/day-stream.pid" 2>/dev/null || echo -)" >"$WORK/day.started"
  arm_say "the logged day runs: the perf stream started (pid $(cat "$WORK/day-stream.pid" 2>/dev/null || echo unknown)). You may close this window; at the day's end, write day-end to the session."
}

arm_exit() {
  rm -f "$WORK/arm.pid"
  cleanup
}

# arm: the arm window itself. It keeps the display awake for the GUI phase (at most until 10
# minutes after its end), and starts the logged day on ready, or on a heartbeat more than 20
# minutes old (the session stalled: restore gui's scriptable half first, and its computer-use items
# wait for his day-end). A daytime session works the same: his return time only ends the GUI phase.
step_arm() {
  r_only arm
  if [ "${1:-}" = open ]; then
    arm_open
    return 0
  fi
  [ -t 0 ] || fail "arm runs in its own Terminal window: $SCRIPT arm open"
  local running="" running_start="" cap
  read -r running running_start <<<"$(arm_of "$WORK/arm.pid")" || true
  if arm_runs "$running" "$running_start"; then fail "an arm window runs already"; fi
  [ ! -f "$WORK/day.started" ] || fail "the logged day runs already ($(cut -f1 "$WORK/day.started"))"
  mkdir -p "$LOGS"
  ARM_PID=$$
  ARM_START="$(proc_start "$ARM_PID")"
  [ -n "$ARM_START" ] || fail "this window's start time can't be read (ps -o lstart): the arm doesn't start"
  echo "$ARM_PID $ARM_START" >"$WORK/arm.pid"
  printf '\033]0;BatteryPulse arm\007'
  trap arm_exit EXIT
  trap ':' USR1
  cd "$ROOT"
  cap=$(($(gui_end_epoch) + 600 - $(date +%s)))
  if [ "$cap" -lt 600 ]; then cap=600; fi
  caffeinate -d -i -t "$cap" &
  ARM_GUI_CAFFEINATE=$!
  BACKGROUND="$BACKGROUND $ARM_GUI_CAFFEINATE"
  arm_say "BatteryPulse Session R's arm window. It keeps the display awake for the GUI phase (until $(epoch_hm $(($(date +%s) + cap)))) and asks for nothing."
  while :; do
    arm_waiter
    if [ -f "$READY_FILE" ]; then break; fi
    if [ -f "$WORK/away" ] && arm_heartbeat_stale; then
      printf 'stale %s\n' "$(clock)" >"$READY_FILE"
      arm_say "the session's heartbeat and the script's own are $(($(heartbeat_age) / 60)) minutes old: the logged day starts without it"
      (restore_gui_scriptable) >>"$LOGS/arm.log" 2>&1 || arm_say "restore gui's scriptable half stopped early"
      restore_gui_items gui >"$WORK/day-end-items.txt" || true
      arm_say "the computer-use items left for his day-end are in $WORK/day-end-items.txt"
      break
    fi
    arm_wait 60
  done
  trap '' USR1
  kill "$ARM_READY_WAITER" 2>/dev/null || true
  pkill -f "notifyutil -1 $READY_NOTIFY" 2>/dev/null || true
  day_start
}

# ready (the GUI phase's last call, after restore gui and the summary): the ready file and its post.
# The arm window then starts the logged day; the session ends its turn, and answers only in text
# until his day-end.
step_ready() {
  r_only ready
  [ -f "$WORK/gui.done" ] || warn "restore gui hasn't run"
  printf 'ready %s\n' "$(clock)" >"$READY_FILE"
  notifyutil -p "$READY_NOTIFY" >/dev/null 2>&1 || true
  echo "READY: end the turn now. A message that reaches the session before his day-end gets a text-only answer (the results come at the day's end), with no tool call."
}

# day_per_kind <perf-stats summary>: W-17 item 16's reading of the day: per kind (Battery,
# Accessories, History, iPhone & iPad, by the timelines' triggers battery, accessories, history and
# devices) the reloads requested and delivered, the share and the median delay (G7-11, ENG-17), and
# the feed's writes (the app's widget.feed.write, by reason) and the widget's reads
# (widget.feed.read) in all and per day.
day_per_kind() {
  local hours kind row name count
  hours="$(awk -v a="$(date -j -f '%Y-%m-%d %H:%M:%S' "$(cut -f1 "$WORK/day.started" 2>/dev/null)" +%s 2>/dev/null || echo 0)" \
    -v b="$(date -j -f '%Y-%m-%d %H:%M:%S' "$(cat "$DAY_END")" +%s 2>/dev/null || echo 0)" 'BEGIN { if (a > 0 && b > a) printf "%.1f", (b - a) / 3600; else print 0 }')"
  out "- per kind over the day's $hours hours (kind, requested, delivered, share, median delay s, timelines):"
  for kind in battery accessories history devices; do
    row="$(awk -v k="$kind" '/^widget delivery/ { inside = 1; next } inside && NF == 0 { inside = 0 } inside && $1 == k { print; exit }' "$1")"
    out "  - $kind: ${row:-no reload requested and no timeline}"
  done
  for name in widget.feed.write widget.feed.read; do
    count="$(awk -v n="$name" '/^intervals/ { inside = 1; next } inside && NF == 0 { inside = 0 } inside && $1 == n && $2 != "(all)" { c += $3 } END { print c + 0 }' "$1")"
    out "  - $name: $count in all, $(awk -v c="$count" -v h="$hours" 'BEGIN { if (h > 0) printf "%.0f", c * 24 / h; else print "-" }') per day$(if [ "$name" = widget.feed.write ]; then printf ' (%s)' "$(awk '/^intervals/ { inside = 1; next } inside && NF == 0 { inside = 0 } inside && $1 == "widget.feed.write" && $2 != "(all)" { printf "%s%s %s", sep, $2, $3; sep = ", " }' "$1")"; fi)"
  done
}

# day-end (§6.3, on his "day-end"): opens the fence once he is at the Mac (the screen unlocked at the
# console, the lid open, input within the last 15 minutes by the HID event state where P6 found it
# blind to posted events), then the day's measurements: the stream stopped and perf-stats per kind
# (G7-11), the widget extension's reads, crash reports since prepare (G7-16), fault messages
# (G7-16), W-13's update lines, BatteryPulse's assertions (must be 0).
step_day_end() {
  r_only day-end
  local state idle source faults asserts summary
  [ -f "$READY_FILE" ] || fail "ready isn't up: the logged day hasn't started"
  if ! ended_after "$WORK" ready; then
    state="$(ui_run locked 2>/dev/null || true)"
    if [ "$state" != "locked=no lid=open console=yes" ]; then
      fail "the screen isn't unlocked at the console with the lid open (${state:-ui locked unread}): day-end comes once he is at the Mac; nothing was opened"
    fi
    if proof_detail P6 | grep -q -F 'ignores posted events: yes'; then
      idle="$(state_seconds)"
      source="the HID event state"
    else
      idle="$(idle_seconds)"
      source="HIDIdleTime"
    fi
    case "$idle" in "" | *[!0-9.]*) fail "$source can't be read, and day-end needs it (at most 900 s): nothing was opened" ;; esac
    awk -v i="$idle" 'BEGIN { exit !(i + 0 <= 900) }' ||
      fail "$source says $idle s since the last input: day-end comes once he is at the Mac"
    clock >"$DAY_END"
  fi
  stream_stop day-stream
  begin_section 70-day "The logged day (§6.5; G7-11, G8-10)"
  out "- from $(cut -f1 "$WORK/day.started" 2>/dev/null || echo "-") to $(cat "$DAY_END") (day-end); the display assertion released at $(awk -F '\t' 'index($2, "display assertion is released") { t = $1 } END { print t }' "$LOGS/arm.log" 2>/dev/null || echo "-")"
  if [ -s "$DAY_STREAM" ] && [ -x "$BIN/perf-stats" ]; then
    summary="$(perf_stats "$DAY_STREAM" 2>&1 || true)"
    printf '%s\n' "$summary" >"$LOGS/day-perf-stats.txt"
    out "- perf-stats over the day's stream (per kind: requested, delivered, the share, the median delay; G7-11 wants 90 % per kind, a delay isn't a refusal):"
    out_block "$LOGS/day-perf-stats.txt"
    day_per_kind "$LOGS/day-perf-stats.txt"
  else
    not_checked G7-11 "no day stream, or perf-stats isn't built"
  fi
  out "- crash reports since prepare (BatteryPulse and BatteryPulseWidget; must be 0, G8-10):"
  crash_summary "$WORK/prepare.marker"
  faults="$(log_since "$(cat "$WORK/prepare.time")" "$FAULT_PREDICATE" "$LOGS/faults.ndjson")"
  out "- fault messages in the subsystem since prepare: $faults (must be 0, G8-10)"
  if [ "${faults:-0}" -gt 0 ]; then
    messages "$LOGS/faults.ndjson" | head -10 | public >"$LOGS/faults.txt"
    out_block "$LOGS/faults.txt"
  fi
  log_since "$(cat "$WORK/prepare.time")" "$MONITOR_PREDICATE" "$LOGS/day-monitor.ndjson" >/dev/null
  messages "$LOGS/day-monitor.ndjson" | grep -i 'limit' >"$LOGS/day-limit.txt" || true
  out "- the Charge Limit reader's lines since prepare (A-2 item 7; §10: one read per trigger, never per poll): $(grep -c . "$LOGS/day-limit.txt" || true), by the case names they carry: $(cut -d' ' -f3- "$LOGS/day-limit.txt" | tr -cs 'A-Za-z' '\n' | grep -E '^[a-z]+[A-Z][A-Za-z]*$' | sort | uniq -c | awk '{ printf "%s%s %s", sep, $2, $1; sep = ", " }' || true) [the words unverified until A-2's line]"
  log_since "$(cut -f1 "$WORK/day.started" 2>/dev/null || cat "$WORK/prepare.time")" "$UPDATE_PREDICATE" "$LOGS/day-update.ndjson" >/dev/null
  messages "$LOGS/day-update.ndjson" | grep -i -E 'count|check' | head -8 >"$LOGS/day-update.txt" || true
  out "- W-13's update lines during the day (an automatic check due on $RC_VERSION gives one noCounter, since no release holds its count file):"
  out_block "$LOGS/day-update.txt"
  asserts="$(pmset -g assertions 2>/dev/null | grep -c BatteryPulse || true)"
  out "- pmset -g assertions naming BatteryPulse now: $asserts (must be 0); other processes' keep-awake holders: $(keepawake_holders | grep -c . || true)"
  echo "NEXT: $SCRIPT plug (with him, the two beeps), $SCRIPT capacity day-end, Q8-6's optional listen while RC-U still runs (app-language ru, back), then F12 ($SCRIPT f12 rate, install F, f12 before, Check for Updates and Install and Relaunch by ui press, f12 after), then batch, send --dry-run, his yes, send, restore end, each RESTORE item, widgets-check, summary end, and send again (the widgets' counts)"
}

# MARK: - Session R: F12 at the day's end (D-12, G8-9)

# f12 rate | before | after (G8-9; PLAN.md §6.4 step 12): RC-F (0.5.99) installed first (`install
# F`); Check for Updates, then Install and Relaunch by AX presses, between before and after: RC-F's
# installer (P-2's checks and relaunch fallback among them) installs the published 0.7.1. after
# reads the version, the update log's pre-swap extension end (D-17), the eject failures and the
# CHSErrorDomain 1103 lines, and the widgets after the desktop click, per kind (P71's W-17 item 9),
# once a widget extension process that wasn't there before Install drew them (PLAN.md §6.0 rule 4;
# none within a minute is "not checked", never an answer from a stale render): under 0.7.1 every
# kind comes back, the History and iPhone & iPad ones with the rest.
step_f12() {
  r_only f12
  use_section 75-f12 "F12: Install and Relaunch on RC-F's installer (G8-9)"
  case "${1:-}" in
    rate)
      local left
      left="$(curl -s https://api.github.com/rate_limit | tr -d ' \n' | sed -n 's/.*"core":{[^}]*"remaining":\([0-9]*\).*/\1/p' | head -1 || true)"
      out "- the unauthenticated requests left: ${left:-unknown}; a VPN active: $(cat "$WORK/vpn" 2>/dev/null || echo unknown)"
      if [ -n "$left" ] && [ "$left" -ge 10 ]; then echo "F12 may run now: $SCRIPT install F, then $SCRIPT f12 before"; else
        echo "not now (fewer than 10 requests left): wait for the reset in the background (at most an hour; $SCRIPT wait), then f12 rate again; else \"not run: rate-limited\""
        return 1
      fi
      ;;
    before)
      grep -q '^F ' "$WORK/installed" 2>/dev/null || fail "RC-F isn't installed: $SCRIPT install F first"
      clock >"$WORK/f12.time"
      click_desktop || true
      crop_widgets "$SHOTS/f12" before >/dev/null
      widget_pids | tr '\n' ' ' >"$WORK/f12-before.pids"
      if [ -n "$(widget_pids)" ]; then echo yes >"$WORK/f12-extension"; else echo no >"$WORK/f12-extension"; fi
      out "- before Install ($(cat "$WORK/f12.time")): $(app_version); the widget extension running: $(cat "$WORK/f12-extension") (pids: $(cat "$WORK/f12-before.pids"))"
      echo "DO (session): Check for Updates, then Install and Relaunch, by AX presses (ui press BatteryPulse ...); then: $SCRIPT f12 after"
      ;;
    after)
      local waited=0 lines swap failures version fresh
      until [ "$(plist_value "$APP/Contents/Info.plist" CFBundleShortVersionString)" = "$BASE_VERSION" ] || [ "$waited" -ge 180 ]; do
        sleep 1
        waited=$((waited + 1))
      done
      sleep 5
      version="$(plist_value "$APP/Contents/Info.plist" CFBundleShortVersionString)"
      out "- after: $(app_version), running $(if app_running; then echo yes; else echo no; fi)"
      log_since "$(cat "$WORK/f12.time")" "$UPDATE_PREDICATE" "$LOGS/f12-update.ndjson" >/dev/null
      lines="$(messages "$LOGS/f12-update.ndjson" | grep -E 'extension before the swap|diskutil|attach|eject|swap' | head -12 || true)"
      printf '%s\n' "$lines" >"$LOGS/f12-update.txt"
      out "- the update log's installer lines:"
      out_block "$LOGS/f12-update.txt"
      swap="$(sed -n 's/.*Widget extension before the swap: \(.*\)/\1/p' "$LOGS/f12-update.txt" | head -1 || true)"
      out "- the pre-swap extension end: ${swap:-no line}$(if [ "$(cat "$WORK/f12-extension" 2>/dev/null)" = no ]; then echo "; no extension ran before Install: not exercised"; fi)"
      failures="$(messages "$LOGS/f12-update.ndjson" | grep -c -F -e "it can't be ejected by force" -e "Ejecting the update's disk image failed" || true)"
      out "- eject failure lines: ${failures:-0} (must be 0); $(chs_since "$(cat "$WORK/f12.time")")"
      if [ "$version" = "$BASE_VERSION" ]; then
        step_answer --by claude F12-version y "read from the installed Info.plist: $version" >/dev/null
      else
        step_answer --by claude F12-version n "read from the installed Info.plist: $version" >/dev/null
      fi
      echo "F12-version: $(answer_of F12-version) (the installed version is $version)"
      fresh="$(fresh_widget_pid "$(cat "$WORK/f12-before.pids" 2>/dev/null || true)")"
      out "- a widget extension process since before Install (rule 4's redraw): ${fresh:-none within a minute}"
      if [ -z "$fresh" ]; then
        not_checked F12-widget "no redraw: no widget extension process that wasn't there before Install"
        not_checked F12-new-kinds "no redraw: no widget extension process that wasn't there before Install"
        return 0
      fi
      click_desktop || true
      crop_widgets "$SHOTS/f12" after
      echo "LOOK $SHOTS/f12/*-before.png against *-after.png: F12-widget for small, medium, large and accessories-*, F12-new-kinds for history-* and devices-*"
      ask F12-widget F12-new-kinds
      ;;
    *) fail "usage: $SCRIPT f12 rate | before | after" ;;
  esac
}

# MARK: - The session's gallery widgets, checked by the app's counts (T-1 item 7)

# What WidgetKit tells BatteryPulse is placed (G7-17, measured at the intake: real answers for this
# ad-hoc-signed app), one line per read: "<moment>\t<time>\t<all> <battery> <accessories> <history>
# <devices>", or "unknown". prepare reads it before anything changes; restore end's relaunch and
# widgets-check read it again. AP71's feed held 4 devices through an iPhone & iPad widget Session F
# had added and not removed, which nothing flagged: a widget the session adds comes back only by
# these counts, never on the session's word.
PLACED="$WORK/placed.tsv"

# placed_counts_in <ndjson>: "<all> <battery> <accessories> <history> <devices>" from the last of
# BatteryPulse's "Placed widgets" lines in a `log stream --style ndjson` capture: the feed writer's
# ("Placed widgets, for the widget feed: …", at notice when its counts change, so at its first
# answer after a launch) or the refresher's ("Placed widgets: …"); empty without one.
placed_counts_in() {
  entries "$1" | awk -F '\t' '$2 == "BatteryPulse" && index($3, "Placed widgets") { l = $3 } END { print l }' |
    sed -n 's/.*: \([0-9][0-9]*\) in all, \([0-9][0-9]*\) Battery, \([0-9][0-9]*\) Accessories, \([0-9][0-9]*\) History, \([0-9][0-9]*\) iPhone & iPad.*/\1 \2 \3 \4 \5/p'
}

# placed_words <counts>: the counts as words, or the word itself (unknown, none).
placed_words() {
  awk -v c="$1" 'BEGIN { if (split(c, n, " ") != 5) { print (c == "" ? "none read" : c); exit }
    printf "%d in all: %d Battery, %d Accessories, %d History, %d iPhone & iPad", n[1], n[2], n[3], n[4], n[5] }'
}

# placed_read <moment>: the installed BatteryPulse quit and launched again with its own settings,
# and its first answer of the placed widgets read from a stream of its widget lines, up to 100 s:
# its first feed write after a launch (at the history recorder's first minute tick) asks WidgetKit,
# nothing being in memory, and logs the counts at notice. Into placed.tsv, and printed; "unknown"
# when no line came (a writer with no section to fill asks nothing: History off and device reads
# off). F-1, once it ships, renews the answer within about an hour without a relaunch; the relaunch
# makes it now, and works with his 0.7.1 too.
placed_read() {
  local moment="$1" capture="$LOGS/placed-$1.ndjson" stream waited=0 counts=""
  mkdir -p "$LOGS" "$WORK"
  /usr/bin/log stream --level debug --style ndjson --predicate "$WIDGET_PREDICATE" >"$capture" 2>"$capture.err" </dev/null &
  stream=$!
  STREAMS="$STREAMS $stream"
  sleep 2
  quit_app
  launch_plain
  while [ "$waited" -lt 100 ]; do
    counts="$(placed_counts_in "$capture")"
    [ -z "$counts" ] || break
    sleep 5
    waited=$((waited + 5))
  done
  perf_stop "$stream"
  placed_record "$moment" "${counts:-unknown}"
  echo "${counts:-unknown}"
}

placed_record() { printf '%s\t%s\t%s\n' "$1" "$(clock)" "$2" >>"$PLACED"; }

# placed_of <moment>: the counts last read at that moment, empty when none was.
placed_of() { awk -F '\t' -v m="$1" '$1 == m { c = $3 } END { print c }' "$PLACED" 2>/dev/null || true; }

# placed_latest: the newest read after prepare's, as "<moment>\t<counts>", empty when none was.
placed_latest() { awk -F '\t' '$1 != "prepare" { l = $1 "\t" $3 } END { print l }' "$PLACED" 2>/dev/null || true; }

# placed_differences <prepare's counts> <counts now>: per kind whose count differs,
# "<kind>\t<now>\t<prepare's>"; nothing when they agree (or either isn't five numbers).
placed_differences() {
  awk -v a="$1" -v b="$2" 'BEGIN {
    split("Battery|Accessories|History|iPhone & iPad", k, "|")
    if (split(a, p, " ") != 5 || split(b, q, " ") != 5) exit
    for (i = 1; i <= 4; i++) if (p[i + 1] + 0 != q[i + 1] + 0) printf "%s\t%d\t%d\n", k[i], q[i + 1], p[i + 1]
  }'
}

# placed_lines: what the session's widgets left, by the app's counts against prepare's: an ALERT
# per kind above prepare's count (a widget the session added stayed; KEPT instead when he keeps
# the gallery's widgets, R-keep-widgets y) or below it (one of his own is gone), WIDGETS when they
# agree; an ALERT when either count is unknown, since then nothing confirms them.
placed_lines() {
  local before moment="" now="" diffs kind count was
  before="$(placed_of prepare)"
  IFS="$TAB" read -r moment now <<<"$(placed_latest)" || true
  if [ -z "$before" ] || [ "$before" = unknown ]; then
    echo "ALERT desktop-widgets: prepare's counts of the placed widgets are ${before:-not read}, so no widget the session added can be confirmed gone: look at the desktop and Notification Center by hand"
    return 0
  fi
  if [ -z "$now" ] || [ "$now" = unknown ]; then
    echo "ALERT desktop-widgets: no counts of the placed widgets since prepare's ($(placed_words "$before"))$(if [ -n "$moment" ]; then echo "; $moment read none"; fi): $SCRIPT widgets-check reads them"
    return 0
  fi
  diffs="$(placed_differences "$before" "$now")"
  if [ -z "$diffs" ]; then
    echo "WIDGETS back at prepare's counts ($(placed_words "$now"), read at $moment)"
    return 0
  fi
  while IFS="$TAB" read -r kind count was; do
    [ -n "$kind" ] || continue
    if [ "$count" -gt "$was" ] && [ "$(answer_of R-keep-widgets)" = y ]; then
      echo "KEPT desktop-widgets: $kind $count, prepare $was: $((count - was)) the session added stayed, as he chose (R-keep-widgets y)"
    elif [ "$count" -gt "$was" ]; then
      echo "ALERT desktop-widgets: $kind $count, prepare $was: $((count - was)) the session added stayed: remove it by computer use, then $SCRIPT widgets-check"
    else
      echo "ALERT desktop-widgets: $kind $count, prepare $was: $((was - count)) of his own gone: add it again from the gallery as prepare's shots show it, then $SCRIPT widgets-check"
    fi
  done <<<"$diffs"
}

# widgets_verdict: placed_lines into the section, and `restored desktop-widgets` recorded by the
# script when no line is an ALERT (back at prepare's counts, or above them only where he keeps the
# gallery's widgets): never on the session's word (step_restored refuses it).
widgets_verdict() {
  local lines moment line
  lines="$(placed_lines)"
  moment="$(placed_latest | cut -f1)"
  use_section 96-widgets "The session's widgets, by the app's counts (T-1 item 7)"
  out "- prepare: $(placed_words "$(placed_of prepare)")"
  awk -F '\t' '$1 != "prepare" { print "- " $1 " (" $2 "): " $3 }' "$PLACED" 2>/dev/null | while IFS= read -r line; do out "$line"; done
  while IFS= read -r line; do out "- $line"; done <<<"$lines"
  if [ -n "$(original_of desktop-widgets)" ] && ! is_restored desktop-widgets && ! grep -q '^ALERT' <<<"$lines"; then
    mark_restored desktop-widgets "script: the app's counts after $moment against prepare's ($(grep -c '^KEPT' <<<"$lines" || true) kinds kept on his word)"
    echo "desktop-widgets: back (the app's counts)"
  fi
}

# widgets-check: the app's counts read again (BatteryPulse relaunched with its own settings) after
# the session removed the widgets it added (restore end's RESTORE item), then widgets_verdict. Also
# usable whenever the session wants the counts now.
step_widgets_check() {
  rl_only widgets-check
  local counts
  counts="$(placed_read "check-$(date '+%H%M%S')")"
  echo "the placed widgets now: $(placed_words "$counts")"
  widgets_verdict
}

# MARK: - Restore gui and restore end

# When each changed setting comes back: "gui" before the logged day (restore gui: the day runs on
# the RC with his settings, his remembered devices and the system as he left it), "end" after it
# (restore end: his own BatteryPulse again, his data, the widgets the session added).
restore_phase() {
  case "$1" in
    app | bp-support | widget-data | desktop-widgets) echo end ;;
    *) echo gui ;;
  esac
}

# How each comes back: "script" ones by the script, the rest by the session (AX or computer use),
# confirmed with `restored <setting> <how>`.
restore_how() {
  case "$1" in
    app | bp-settings | bp-support | widget-data | remembered-devices | widget-languages | history) echo script ;;
    app-language | has-seen-welcome | bp-window-style | sentinel-accessories | sentinel-devices) echo script ;;
    widget-style) echo "computer use (System Settings → Appearance → Icon & widget style)" ;;
    dim-widgets) echo "computer use (System Settings → Desktop & Dock → Dim widgets on desktop)" ;;
    text-size | increase-contrast | reduce-transparency | show-borders | liquid-glass) echo "computer use (System Settings → Accessibility → Display)" ;;
    reduce-motion | cross-fade) echo "computer use (System Settings → Accessibility → Motion)" ;;
    keyboard-navigation) echo "computer use (System Settings → Keyboard → Keyboard navigation), confirmed by AppleKeyboardUIMode" ;;
    24-hour) echo "computer use (System Settings → General → Date & Time), confirmed by AppleICUForce24HourTime" ;;
    open-at-login) echo "AX (BatteryPulse's Settings → General → Open at login)" ;;
    bluetooth-accessory) echo "AX or computer use (System Settings → Bluetooth: connect it again)" ;;
    widget-choices) echo "computer use (Edit Widget: back to Automatic)" ;;
    charge-limit) echo "computer use (System Settings → Battery), confirmed by pmset -g battlimit" ;;
    desktop-widgets) echo "computer use (the widgets he didn't keep removed), confirmed only by the app's counts (widgets-check)" ;;
    appearance) echo "computer use (System Settings → Appearance: Light, Dark or Auto, as prepare read it)" ;;
    wallpaper) echo "computer use (System Settings → Wallpaper: his picture, as prepare's desktop shot shows it)" ;;
    *) echo "computer use, confirmed by a read or a shot" ;;
  esac
}

# restore_gui_scriptable: the scriptable half of restore gui (the session's, and the arm's stale
# path): the GUI phase's stream stopped and summarized, his settings and his remembered devices back
# into the RC (defaults import; the RC keeps running for the logged day), his history from the
# backup once the session cleared its copy (the feed's rewrite check), the extension's languages as
# prepare found them, the apps the script opened closed, BatteryPulse relaunched in his language.
restore_gui_scriptable() {
  local app setting
  stream_stop gui-stream
  if [ -s "$GUI_STREAM" ]; then
    use_section 58-gui-stream "The GUI phase: the widgets' reloads and timelines (W-4 item 3)"
    if [ -x "$BIN/perf-stats" ]; then
      perf_stats "$GUI_STREAM" >"$LOGS/gui-perf-stats.txt" 2>&1 || true
      out_block "$LOGS/gui-perf-stats.txt"
    fi
    messages "$GUI_STREAM" 2>/dev/null | grep -i -E 'configuration|placed' | head -20 >"$LOGS/gui-configurations.txt" || true
    out "- the app's per-kind answers of currentConfigurations() (W-4 item 3), to match with the widgets placed in steps 1 and 3:"
    out_block "$LOGS/gui-configurations.txt"
  fi
  quit_app
  if [ -f "$BACKUP/defaults.plist" ]; then
    defaults delete "$BUNDLE_ID" 2>/dev/null || true
    defaults import "$BUNDLE_ID" "$BACKUP/defaults.plist"
    mark_restored bp-settings "script: his settings imported for the logged day"
    if [ -n "$(original_of app-language)" ] && ! is_restored app-language &&
      [ "$(defaults read "$BUNDLE_ID" AppleLanguages 2>/dev/null || echo none)" = "$(cat "$BACKUP/app-languages" 2>/dev/null || echo none)" ]; then
      mark_restored app-language "script: his settings imported, read back"
    fi
    echo en >"$WORK/ui-language"
    for setting in has-seen-welcome bp-window-style; do
      if [ -n "$(original_of "$setting")" ] && ! is_restored "$setting"; then mark_restored "$setting" "script: his settings imported"; fi
    done
  fi
  for setting in sentinel-accessories sentinel-devices; do
    if [ -n "$(original_of "$setting")" ] && ! is_restored "$setting"; then
      rm -f "$SUPPORT/Sentinel/${setting#sentinel-}"
      mark_restored "$setting" "script: the sentinel file removed"
    fi
  done
  if [ -n "$(original_of remembered-devices)" ] && [ -d "$BACKUP/support/Devices" ]; then
    rm -rf "$SUPPORT/Devices"
    ditto "$BACKUP/support/Devices" "$SUPPORT/Devices" && mark_restored remembered-devices "script (from the backup), read back"
  elif [ "$(original_of remembered-devices)" = none ]; then
    # He remembered none; a device read while the session turned reads on is the session's.
    rm -rf "$SUPPORT/Devices"
    mark_restored remembered-devices "script: none, as before the session"
  fi
  if [ -n "$(original_of history)" ] && ! is_restored history; then
    rm -rf "$SUPPORT/History"
    if [ -d "$BACKUP/support/History" ]; then ditto "$BACKUP/support/History" "$SUPPORT/History"; fi
    mark_restored history "script: his history from the backup (the session cleared only its copy)"
  fi
  if [ -n "$(original_of widget-languages)" ] && ! is_restored widget-languages; then
    if put_widget_languages_back; then mark_restored widget-languages "script, read back"; fi
  fi
  for app in TextEdit "System Settings" "Accessibility Inspector" Xcode; do
    quit_if_launched "$app"
    if [ -n "$(app_pid_of "$app")" ]; then
      echo "LEFT OPEN $app: the script didn't open it (his own, or opened by computer use: quit it only if the session opened it)"
    fi
  done
  launch_plain
}

# restore_gui_items [phase]: the changed settings of that phase not put back yet, for the session.
restore_gui_items() {
  local setting phase="${1:-gui}"
  for setting in $(changed_settings); do
    [ "$(restore_phase "$setting")" = "$phase" ] || continue
    [ "$(restore_how "$setting")" != script ] || continue
    if is_restored "$setting"; then continue; fi
    if [ "$setting" = desktop-widgets ]; then
      if [ "$(answer_of R-keep-widgets)" = y ]; then
        echo "RESTORE desktop-widgets: he keeps the gallery's widgets (R-keep-widgets y): remove none; $SCRIPT widgets-check records what stayed"
      else
        echo "RESTORE desktop-widgets: remove every widget the session added, by computer use (Edit Widgets, then each one's minus), then $SCRIPT widgets-check: it records them gone only when the app's counts are back at prepare's"
      fi
      continue
    fi
    echo "RESTORE $setting back to $(original_of "$setting"), by $(restore_how "$setting"); then: $SCRIPT restored $setting <how it was confirmed>"
  done
}

# restore_all: his app, the defaults domain, Application Support, the widget extension's
# languages and the appearance as the backup holds them (restore end), but for History/, which
# keeps the logged day (0.8 changes no storage format, PLAN.md §7.3 and D1's round trip: his own
# BatteryPulse reads it), so his real day isn't lost. The candidate's Widget/feed.json and the
# sentinel's folder go with the rest of the session's data. A History/ moved aside by a restore
# that stopped early is the one kept.
restore_all() {
  local kept="$WORK/history-kept"
  [ -f "$BACKUP/done" ] || fail "no backup in $BACKUP"
  install_build backup --no-launch
  quit_app
  defaults delete "$BUNDLE_ID" 2>/dev/null || true
  defaults import "$BUNDLE_ID" "$BACKUP/defaults.plist"
  # Unless the session cleared it and restore gui never put his back: then the backup's.
  if [ ! -d "$kept" ] && [ -d "$SUPPORT/History" ] && { [ -z "$(original_of history)" ] || is_restored history; }; then
    mv "$SUPPORT/History" "$kept"
  fi
  rm -rf "$SUPPORT"
  if [ -d "$BACKUP/support" ]; then ditto "$BACKUP/support" "$SUPPORT"; fi
  if [ -d "$kept" ]; then
    mkdir -p "$SUPPORT"
    rm -rf "$SUPPORT/History"
    mv "$kept" "$SUPPORT/History"
  fi
  put_widget_languages_back || warn "the widget extension's AppleLanguages isn't as prepare found it"
  end_widget_extension
  case "$(cat "$BACKUP/dark-mode" 2>/dev/null || echo unknown)" in
    true) [ "$(is_dark)" = true ] || (appearance dark) || warn "put the dark appearance back by hand" ;;
    false) [ "$(is_dark)" = false ] || (appearance light) || warn "put the light appearance back by hand" ;;
  esac
  launch_plain
}

# summary: the facts for the summary he reads before he uses the Mac (the session writes it in his
# language, on the Mac only): an ALERT per setting not confirmed back, then every setting the
# session changed with how it was confirmed, and the Focus.
step_summary() {
  rl_only summary
  local setting phase="${1:-gui}" line
  for setting in $(changed_settings); do
    [ "$phase" = end ] || [ "$(restore_phase "$setting")" = gui ] || continue
    # The session's widgets: their lines come from the app's counts (placed_lines, below).
    [ "$setting" != desktop-widgets ] || continue
    if ! is_restored "$setting"; then echo "ALERT $setting: not confirmed back (it was $(original_of "$setting"))"; fi
  done
  if [ "$phase" = end ]; then placed_lines; fi
  for setting in $(changed_settings); do
    [ "$phase" = end ] || [ "$(restore_phase "$setting")" = gui ] || continue
    line="$(awk -F '\t' -v s="$setting" '$1 == s { l = $3 } END { print l }' "$RESTORED" 2>/dev/null || true)"
    echo "CHANGED $setting: $(original_of "$setting") -> $(awk -F '\t' -v s="$setting" '$1 == s { v = $3 } END { print v }' "$CHANGES"); back: ${line:-not yet}"
  done
  if [ "$phase" = gui ]; then
    echo "LEFT FOR LATER (restore end): the release candidate stays installed for the logged day; his own BatteryPulse, its settings and data come back at the day's end, the logged day's history kept, the candidate's widget feed removed, and the session's widgets removed unless he keeps them"
  fi
  echo "REMIND: turn the Focus off before using the Mac"
}

# restore gui | end (the look shoot: end only)
step_restore() {
  rl_only restore
  [ "$SESSION" = R ] || [ "${1:-}" = end ] || fail "the look shoot has no logged day: $SCRIPT restore end"
  case "${1:-}" in
    gui)
      restore_gui_scriptable
      begin_section 90-restore-gui "Restore gui (before the logged day)"
      restore_gui_items gui | tee "$WORK/gui-items.txt"
      out "- $(clock): his settings and remembered devices back in the RC, the extension's languages, the apps the script opened closed; $(grep -c . "$WORK/gui-items.txt" || true) items for the session"
      touch "$WORK/gui.done"
      echo "Then each RESTORE item above, then $SCRIPT summary (for the summary in his language), and last: $SCRIPT ready"
      ;;
    end)
      local limit now setting
      stop_leftovers
      restore_all
      begin_section 95-restore "Restore end"
      mark_restored app "script"
      mark_restored bp-settings "script"
      mark_restored bp-support "script"
      mark_restored widget-data "script"
      if [ -n "$(original_of remembered-devices)" ] && { [ -d "$SUPPORT/Devices" ] || [ ! -d "$BACKUP/support/Devices" ]; }; then
        mark_restored remembered-devices "script (from the backup), read back"
      fi
      if [ -n "$(original_of history)" ] && ! is_restored history; then mark_restored history "script: his history from the backup"; fi
      for setting in app-language has-seen-welcome bp-window-style; do
        if [ -n "$(original_of "$setting")" ] && ! is_restored "$setting"; then mark_restored "$setting" "script: his settings domain imported"; fi
      done
      for setting in sentinel-accessories sentinel-devices; do
        if [ -n "$(original_of "$setting")" ] && ! is_restored "$setting"; then mark_restored "$setting" "script: Application Support from the backup, without the sentinel's folder"; fi
      done
      out "- restored $(clock): $(app_version), the settings domain, Application Support (History/ kept: $(find "$SUPPORT/History" -type f 2>/dev/null | grep -c . || true) files; the feed $(if [ -e "$FEED_FILE" ]; then echo "still there"; else echo removed; fi)), the widget's languages, the appearance"
      limit="$(answer_of prep-charge-limit)"
      now="$(battlimit_value)"
      out "- the Charge Limit: prepare found ${limit:-unknown}; pmset -g battlimit now: ${now:-none (on battery it holds none: a Battery pane shot confirms it)}"
      if [ -n "$(original_of charge-limit)" ] && [ -n "$now" ] && [ "$now" = "$limit" ]; then mark_restored charge-limit "pmset -g battlimit"; fi
      out "- the placed widgets after restore end's relaunch: $(placed_words "$(placed_read end)")"
      widgets_verdict
      restore_gui_items end
      restore_gui_items gui
      echo
      echo "PUT BACK (person):"
      echo "- Turn the Focus off, if it is still on."
      if [ "$(answer_of R-keep-ax)" != y ]; then
        echo "- At the end of the series: Terminal off in System Settings → Privacy & Security → Accessibility (optional, 10 s)."
      fi
      echo "The backup stays in $BACKUP."
      ;;
    *) fail "usage: $SCRIPT restore gui | end" ;;
  esac
}

# MARK: - Status, the report and send

# proof_detail <id>: what a proof recorded (proofs.tsv's third field).
proof_detail() { awk -F '\t' -v id="$1" '$1 == id { detail = $3 } END { print detail }' "$PROOFS" 2>/dev/null || true; }

step_status() {
  local id value
  echo "folder: $WORK (Session $SESSION)"
  if [ "$(uname -s)" = Darwin ]; then
    echo "installed: $(app_version); running: $(if app_running; then echo yes; else echo no; fi)"
    echo "battery: $(battery_percent) %, $(if on_battery; then echo on battery; else echo on the adapter; fi)"
  fi
  echo "flags: $(for id in away gui.done ready day.started day-ended; do if [ -f "$WORK/$id" ]; then printf '%s ' "$id"; fi; done)"
  if [ -f "$HEARTBEAT" ] && [ "$SESSION" = R ]; then
    echo "heartbeat: the session's $((($(date +%s) - $(mtime_of "$HEARTBEAT")) / 60)) minutes ago, the newer with the script's own $(($(heartbeat_age) / 60)) (stale after 20); GUI phase: $(gui_minutes_left) minutes left"
  fi
  echo "running: $(for id in $LEFTOVERS; do if leftover_running "$id"; then printf '%s ' "$id"; fi; done)"
  echo "changes: $(changed_settings | grep -c . || true) settings; not put back yet: $(for id in $(changed_settings); do is_restored "$id" || printf '%s ' "$id"; done)"
  echo "proofs: $(awk -F '\t' '{ printf "%s=%s ", $1, $2 }' "$PROOFS" 2>/dev/null)"
  echo "not checked: $(grep -c . "$WORK/not-checked.tsv" 2>/dev/null || echo 0); his batch: $(grep -c . "$BATCH" 2>/dev/null || echo 0)"
  echo "answers:"
  for id in $(questions_list); do
    value="$(answer_of "$id")"
    [ -z "$value" ] || printf '  %-28s %s\n' "$id" "$value"
  done
  echo "sections: $(find "$SECTIONS" -name '*.md' 2>/dev/null | sed 's|.*/||; s|\.md$||' | sort | tr '\n' ' ')"
  echo "attached images: $(grep -c . "$PUBLISH/captions.tsv" 2>/dev/null || echo 0)"
}

# The question's text without its kind and who.
question_text() {
  local spec
  spec="$(question "$1")" || return 0
  spec="${spec#*|}"
  printf '%s' "${spec#*|}"
}

# The Appendix C facts each session's report answers (PLAN.md Appendix C, §6.1-§6.6), with where.
appendix_rows() {
  case "$SESSION" in
    R)
      cat <<'EOF2'
| Fact (PLAN.md Appendix C) | Where in this file |
|---|---|
| §6.4 step 2: his widgets placed under 0.7.1 across RC-U's install, the extension's pids, CHSErrorDomain 1103 (G7-2) | Step 2; Installs; R2-* |
| What's New at 520 points, English and Russian, from 0.7.1 and from 0.6.2 | What's New; R2-whats-new-* |
| G8-6, G8-8: BatteryPulse's trees in English and Russian, the charts' descriptors, the widgets' trees (I-14), the keyboard paths | Step 3: BatteryPulse's trees; Step 4: the keyboard; R-tree-app*, R-charts, R7-tree*, R-keyboard |
| G8-7: the contrast audit (A11Y-03) | R-contrast |
| A11Y-02's display options, A11Y-04's menu bar icons | Step 6: the display options; The menu bar item; R-display, R-menubar-a11y, V01-menubar |
| The Russian pages; the Charge Limit live; Report a Problem's files (G8-5, G8-13); the sentinel (P-1) | The screens; The Charge Limit's check; Report a Problem's files; The sentinel; R-russian, R-limit-live, R-report, R-sentinel |
| The checks 0.7.0 and 0.7.1 shipped without (step 11c): 0.6.2's widgets across the update, the gallery, the edit sheets, the language, the looks, the trees, the clicks, the accessories, Demo Mode, the feed (G71-2), Settings, the capacity readings | Step 11c; The widget's feed; R2-062-*, R3-* to R9b-*, R-feed-*, R-settings, R-capacity-* |
| G8-9: F12, per kind | F12; F12-* |
| G8-10: crash reports and fault messages since prepare; the Charge Limit reader's reads per trigger (§10); G7-11 per kind (I-13) | The logged day |
| Each session's gallery widgets: the counts at prepare and after its RESTORE items, and what stayed (T-1 item 7) | The session's widgets |
| Q8-6: the VoiceOver listen | R-listen |
| The hands-free mode's cost and the preflight's proofs | Timeline; Proofs; Not checked or not run; Notes |
EOF2
      ;;
    L)
      cat <<'EOF2'
| Fact (PLAN.md Appendix C) | Where in this file |
|---|---|
| G8-1: the Charge Limit's reads per limit, on the adapter, on battery and after a plug-in; the app's logged number; CHLT and CHNC; the samples (G8-5's reads from the app's own process) | The Charge Limit's check; G8-1-*, G8-5-limit, L-samples, L-limit-back |
| The look review's shots, English and Russian (§6.2, §6.3) | The screens; L-a1-* to L-a7-* |
| G8-13 and G8-5: Report a Problem's saved files | Report a Problem's files; L-a6-file |
| P-1: the sentinel's note and Turn On Again | The sentinel; L-p1-note |
| G8-3: the weak adapter's captures (Q8-3) | The weak adapter; L-weak-adapter |
| Each session's gallery widgets: the counts at prepare and after its RESTORE items, and what stayed (T-1 item 7) | The session's widgets |
| Crash reports and faults since prepare | Crash reports and faults |
EOF2
      ;;
    H) printf '%s\n' "| Fact | Where |" "|---|---|" "| G8-2 (QUA-06, I-8): an optimized-charging hold seen overnight under caffeinate -i, its captures and whether bit 24 is set | The hold watch; H-hold |" ;;
    D3) printf '%s\n' "| Fact | Where |" "|---|---|" "| §6.6: the update to $RELEASE_VERSION, the widgets, P7 §6.4's list, SEC-06, Report a Problem and the guide's link, the feed's modes and the widget's exception, the first day's comparison | After publishing; The widget's feed; The user guide's link; D3-* |" "| P71's W-17 item 18: maximum capacity, a reading after publishing | Maximum capacity; D3-capacity |" ;;
  esac
}

# timeline: when each phase began and ended, from the session's own files.
timeline() {
  echo "## Timeline"
  echo
  echo "- prepare: $(cat "$WORK/prepare.time" 2>/dev/null || echo "-")"
  if [ "$SESSION" = R ]; then
    echo "- mark away (the GUI phase begins): $(cat "$WORK/away" 2>/dev/null || echo "-")"
    echo "- restore gui: $(if [ -f "$WORK/gui.done" ]; then epoch_stamp "$(mtime_of "$WORK/gui.done")"; else echo "-"; fi)"
    echo "- ready: $(cat "$READY_FILE" 2>/dev/null || echo "-")"
    echo "- the logged day's stream: $(cut -f1 "$WORK/day.started" 2>/dev/null || echo "-")"
    echo "- day-end: $(cat "$DAY_END" 2>/dev/null || echo "-")"
  fi
  echo
}

build_report() {
  local id value by at note file caption setting line unrestored=""
  echo "# Session $SESSION results (BatteryPulse 0.8)"
  echo
  echo "Written by \`docs/plans/0.8.0/m5-session.sh send\` on $(date '+%Y-%m-%d %H:%M %z'). The session ran hands-free"
  echo "(PLAN.md §6.0): answers marked \"claude\" were judged by the Claude session from the pictures, beside the"
  echo "script's pixel measurement where one exists; \"person\" ones came from the maintainer. Full-desktop shots,"
  echo "recordings and logs stay on the Mac (\`~/bp-080/$SESSION\`)."
  echo
  for setting in $(changed_settings); do is_restored "$setting" || unrestored="$unrestored $setting"; done
  for setting in $LEFTOVERS; do
    if leftover_running "$setting"; then unrestored="$unrestored $setting (still running)"; fi
  done
  if [ -n "$unrestored" ]; then
    echo "**Not put back (for his hand):**$unrestored"
    echo
  fi
  echo "## Appendix C rows this session owns"
  echo
  appendix_rows
  echo
  timeline
  echo "## Answers"
  echo
  echo "| ID | Question | Answer | By | Time | Note |"
  echo "|---|---|---|---|---|---|"
  for id in $(questions_list); do
    line="$(awk -F '\t' -v id="$id" '$1 == id { line = $0 } END { print line }' "$ANSWERS" 2>/dev/null || true)"
    [ -n "$line" ] || continue
    IFS=$'\t' read -r _ value by at note <<<"$line"
    printf '| %s | %s | %s | %s | %s | %s |\n' "$id" "$(question_text "$id")" "$value" "$by" "$at" "${note:-}"
  done
  echo
  if [ -s "$PROOFS" ]; then
    echo "## Proofs"
    echo
    echo "| Proof | Result | Detail | Fallback | Time |"
    echo "|---|---|---|---|---|"
    awk -F '\t' '{ printf "| %s | %s | %s | %s | %s |\n", $1, $2, $3, $4, $5 }' "$PROOFS"
    echo
  fi
  if [ -s "$WORK/not-checked.tsv" ]; then
    echo "## Not checked or not run"
    echo
    awk -F '\t' '{ printf "- %s %s: %s\n", $1, $2, $3 }' "$WORK/not-checked.tsv"
    echo
  fi
  for file in "$SECTIONS"/*.md; do
    [ -f "$file" ] || continue
    cat "$file"
    echo
  done
  if [ -s "$NOTES" ]; then
    echo "## Notes"
    echo
    while IFS=$'\t' read -r at note; do echo "- $at: $note"; done <"$NOTES"
    echo
  fi
  if [ -s "$PUBLISH/captions.tsv" ]; then
    echo "## Images"
    echo
    while IFS=$'\t' read -r file caption; do
      echo "$caption"
      echo
      echo "![$caption]($SESSION/$file)"
      echo
    done <"$PUBLISH/captions.tsv"
  fi
}

# network_name: the Wi-Fi network's name, where macOS doesn't redact it (often it does).
network_name() {
  {
    ipconfig getsummary en0 2>/dev/null | sed -n 's/^ *SSID : //p'
    networksetup -getairportnetwork en0 2>/dev/null | sed -n 's/^Current Wi-Fi Network: //p'
    system_profiler SPAirPortDataType 2>/dev/null | awk '/Current Network Information:/ { getline; sub(/^ */, ""); sub(/:$/, ""); print; exit }'
  } | grep -v -i -E 'redacted|^$' | head -1 || true
}

# bluetooth_names: the names system_profiler lists under Connected and Not Connected, the
# accessories that aren't attached at send time too.
bluetooth_names() {
  system_profiler SPBluetoothDataType 2>/dev/null | awk '
    /^ *(Connected|Not Connected):$/ { match($0, /^ */); level = RLENGTH; child = -1; inlist = 1; next }
    inlist {
      match($0, /^ */); indent = RLENGTH
      if (indent <= level && $0 ~ /[^ ]/) { inlist = 0; next }
      if ($0 ~ /:$/ && (child < 0 || indent == child)) { child = indent; name = substr($0, indent + 1); sub(/:$/, "", name); print name }
    }' || true
}

# privacy_terms: what the report must not name: the ComputerName and LocalHostName, his full
# name, an accessory's name (pmset -g accps, system_profiler's Bluetooth list), an iPhone's or
# iPad's name from BatteryPulse's device store (now and in the backup) and from the widget's feed,
# a VPN's name, the network's name, and every keep-awake holder's process name.
privacy_terms() {
  {
    scutil --get ComputerName 2>/dev/null || true
    scutil --get LocalHostName 2>/dev/null || true
    id -F 2>/dev/null || true
    pmset -g accps 2>/dev/null | sed -n 's/^ *-\(.*\) (id=.*/\1/p' | grep -v -i InternalBattery || true
    bluetooth_names
    cat "$SUPPORT/Devices/devices.json" "$BACKUP/support/Devices/devices.json" "$WORK/devices-forgotten.json" "$FEED_FILE" 2>/dev/null |
      grep -o '"name" *: *"[^"]*"' | sed 's/^"name" *: *"//; s/"$//' || true
    scutil --nc list 2>/dev/null | sed -n 's/.*"\([^"]*\)".*/\1/p' || true
    network_name
    # A caffeinate holder is a tool's name, which the report may use.
    cut -f4 "$KEEPAWAKE_LOCAL" 2>/dev/null | grep -v -x caffeinate || true
  } | awk 'length($0) >= 3' | grep -v -i -x -E "$GENERIC_NAMES" | sort -u || true
}

# Names that are a product's, not his (a device or an accessory left with its plain name), and
# the report's own words: never terms.
GENERIC_NAMES='iphone|ipad|ipod|mac|macbook|macbook air|macbook pro|airpods|airpods pro|airpods max|magic mouse|magic keyboard|magic trackpad|apple watch|apple pencil|batterypulse'

# privacy_words: his short user name and first name, matched as whole words only.
privacy_words() {
  {
    id -un 2>/dev/null || true
    id -F 2>/dev/null | awk '{ print $1 }' || true
  } | awk 'length($0) >= 3' | grep -v -i -x -E 'admin|administrator|user|guest|root|test|owner' | sort -u || true
}

# privacy_lint <file> [<its name in the message>]: refuses the file if a line names any of them.
privacy_lint() {
  local term found="" scrubbed="$WORK/lint-scrubbed.txt"
  # The bundle ID and the repository's owner are public and may contain his name: taken out first,
  # so they never count, line numbers kept.
  awk -v a="$(tr '[:upper:]' '[:lower:]' <<<"$BUNDLE_ID")" -v b="$(tr '[:upper:]' '[:lower:]' <<<"${REPO%%/*}")" '{
      l = tolower($0)
      while ((i = index(l, a)) > 0) l = substr(l, 1, i - 1) substr(l, i + length(a))
      while ((i = index(l, b)) > 0) l = substr(l, 1, i - 1) substr(l, i + length(b))
      print l }' "$1" >"$scrubbed"
  while IFS= read -r term; do
    [ -n "$term" ] || continue
    if grep -n -i -F -- "$term" "$scrubbed" >"$WORK/lint.txt" 2>/dev/null; then
      found="$found $(cut -d: -f1 "$WORK/lint.txt" | tr '\n' ',' | sed 's/,$//')"
    fi
  done < <(privacy_terms)
  while IFS= read -r term; do
    [ -n "$term" ] || continue
    if grep -n -i -w -F -- "$term" "$scrubbed" >"$WORK/lint.txt" 2>/dev/null; then
      found="$found $(cut -d: -f1 "$WORK/lint.txt" | tr '\n' ',' | sed 's/,$//')"
    fi
  done < <(privacy_words)
  rm -f "$WORK/lint.txt" "$scrubbed"
  if [ -z "$(network_name)" ]; then
    echo "note: the network's name couldn't be read (macOS redacts it), so the report wasn't checked for it"
  fi
  if [ -n "$found" ]; then
    fail "${2:-$SESSION.md} names the Mac, him, an accessory, a VPN or the network on line(s)$found: drop them (note, answer or section; a sample or capture: unattach it by deleting it from $WORK), then send again"
  fi
}

# lint_kept <folder>: the privacy lint over every file a session keeps for a fixture (samples/: A-2's
# redacted copies of powerd's file with battlimit's and defaults' text; captures/: bpulse's redacted
# captures), each property list as XML text.
lint_kept() {
  local file text
  for file in "$WORK/$1"/*; do
    [ -f "$file" ] || continue
    case "$file" in
      *.plist)
        text="$WORK/lint-$(basename "$file").xml"
        plutil -convert xml1 -o "$text" "$file" 2>/dev/null || cp "$file" "$text"
        privacy_lint "$text" "$1/$(basename "$file")"
        rm -f "$text"
        ;;
      *) privacy_lint "$file" "$1/$(basename "$file")" ;;
    esac
  done
}

# send [--dry-run]: <session>.md (and the attached images, and the samples and captures a fixture
# may come from) committed to docs/plans/0.8.0/sessions/ on claude/080-session-<session>, which
# starts from that branch if it exists, else the integration branch, else main (after 0.8's D3
# removed both); a fresh shallow clone in the session's folder, so his own checkout stays as it is.
# Never another branch, never a pull request. His yes first (<session>-send y, after the contact
# sheet and the summary), then the privacy lint.
step_send() {
  local dry_run="" clone="$WORK/send" base name email total kept folder report="$WORK/$SESSION.md" candidate
  [ "$SESSION" != none ] || fail "send runs from a session's frozen worktree"
  if [ "${1:-}" = --dry-run ]; then dry_run=1; fi
  mkdir -p "$WORK"
  if [ -z "$dry_run" ] && [ "$(answer_of "$SESSION-send")" != y ]; then
    fail "his yes first, at the Mac, after the contact sheet of every attached image and the summary: $SCRIPT answer --by person $SESSION-send y"
  fi
  if [ -n "$dry_run" ]; then
    publish_sheet
  elif ! publish_sheet_fresh || { [ -f "$WORK/publish-sheet.png" ] && ! [ "$WORK/send-yes" -nt "$WORK/publish-sheet.png" ]; }; then
    fail "an image was attached after the contact sheet, or his yes came before it: $SCRIPT send --dry-run, show him the new sheet, then his yes again"
  fi
  build_report | public >"$report"
  privacy_lint "$report"
  lint_kept samples
  lint_kept captures
  if has_cyrillic "$(cat "$report")"; then
    fail "$SESSION.md contains Russian text; translate the answer or note it comes from, then send again"
  fi
  total=0
  if [ -s "$PUBLISH/captions.tsv" ]; then total="$(du -sk "$PUBLISH" | cut -f1)"; fi
  [ "$total" -le 6144 ] || fail "the attached images take $total KB; unattach some (at most 6 MB)"
  kept="$(du -sk "$WORK/samples" "$WORK/captures" 2>/dev/null | awk '{ k += $1 } END { print k + 0 }')"
  [ "$kept" -le 4096 ] || fail "the samples and captures take $kept KB (at most 4 MB): delete the ones no fixture needs from $WORK"
  echo "wrote $report ($(wc -l <"$report" | tr -d ' ') lines, images $total KB, samples and captures $kept KB: $(find "$WORK/samples" "$WORK/captures" -type f 2>/dev/null | sed 's|.*/||' | tr '\n' ' ')"
  [ -z "$dry_run" ] || return 0

  rm -rf "$clone"
  base=""
  for candidate in "$RESULTS_BRANCH" "$INTEGRATION_BRANCH" main; do
    if git ls-remote --exit-code --heads "https://github.com/$REPO.git" "$candidate" >/dev/null 2>&1; then
      base="$candidate"
      break
    fi
  done
  [ -n "$base" ] || fail "no branch to start from on GitHub (the network?): nothing was sent; send again later"
  git clone --quiet --depth 1 --branch "$base" "https://github.com/$REPO.git" "$clone"
  git -C "$clone" checkout --quiet -B "$RESULTS_BRANCH"
  mkdir -p "$clone/docs/plans/0.8.0/sessions"
  rm -rf "$clone/docs/plans/0.8.0/sessions/$SESSION"
  cp "$report" "$clone/docs/plans/0.8.0/sessions/$SESSION.md"
  if [ -s "$PUBLISH/captions.tsv" ]; then
    mkdir -p "$clone/docs/plans/0.8.0/sessions/$SESSION"
    cut -f1 "$PUBLISH/captions.tsv" | while IFS= read -r file; do
      cp "$PUBLISH/$file" "$clone/docs/plans/0.8.0/sessions/$SESSION/"
    done
  fi
  for folder in samples captures; do
    [ -n "$(find "$WORK/$folder" -type f 2>/dev/null | head -1)" ] || continue
    mkdir -p "$clone/docs/plans/0.8.0/sessions/$SESSION/$folder"
    cp "$WORK/$folder"/* "$clone/docs/plans/0.8.0/sessions/$SESSION/$folder/"
  done
  git -C "$clone" add -A docs/plans/0.8.0/sessions
  if git -C "$clone" diff --cached --quiet; then
    echo "nothing new to send"
    return 0
  fi
  name="$(git config --global user.name || true)"
  email="$(git config --global user.email || true)"
  if [ -z "$name" ] || [ -z "$email" ]; then
    name="$(gh api user --jq .login)"
    email="$(gh api user --jq '"\(.id)+\(.login)@users.noreply.github.com"')"
  fi
  # In UTC, so the commit dates show no local time zone.
  TZ=UTC git -C "$clone" -c user.name="$name" -c user.email="$email" commit --quiet -F - <<EOF2
Record M5 Session $SESSION's results

The answers, counts, perf-stats summaries, public log excerpts, the
attached crops and the redacted samples of Session $SESSION (PLAN.md §6),
for the packages and gates that wait on them.

Co-Authored-By: Claude <noreply@anthropic.com>
EOF2
  git -C "$clone" -c credential.helper= -c 'credential.helper=!gh auth git-credential' \
    push --quiet origin "HEAD:refs/heads/$RESULTS_BRANCH"
  echo "Sent: https://github.com/$REPO/blob/$RESULTS_BRANCH/docs/plans/0.8.0/sessions/$SESSION.md"
}

# MARK: - The recording (bpulse --record), the hold watch's

# record_start <folder name>: `caffeinate -i bpulse --record` into a new, empty folder under the
# session's folder (USER_GUIDE: caffeinate -i keeps the Mac awake, and the folder must not hold an
# earlier recording), detached; its pid in record.pid.
record_start() {
  local folder="$WORK/$1" pid
  if leftover_running record; then fail "a recording runs already (pid $(cat "$WORK/record.pid"))"; fi
  build_bpulse
  [ -x "$BIN/bpulse" ] || fail "bpulse didn't build (see $BIN/bpulse.log): nothing was recorded"
  [ ! -e "$folder" ] || fail "$folder exists: a recording needs a new, empty folder"
  mkdir -p "$folder" "$LOGS"
  nohup caffeinate -i "$BIN/bpulse" --record "$folder" >"$LOGS/record.txt" 2>&1 </dev/null &
  pid=$!
  echo "$pid" >"$WORK/record.pid"
  echo "$folder" >"$WORK/record.folder"
  disown "$pid" 2>/dev/null || true
  sleep 6
  [ -s "$folder/timeline.tsv" ] || warn "no timeline.tsv yet in $folder (see $LOGS/record.txt)"
  echo "recording into $folder (pid $pid; caffeinate -i keeps the Mac awake)"
}

record_folder() { cat "$WORK/record.folder" 2>/dev/null || true; }

# MARK: - The Charge Limit's check (G8-1; PLAN.md §6.1 step 2, §6.4 step 9)

# powerd's charging preferences, the one source A-2 reads (PLAN.md A-2): only its presence, size and
# time reach the report; its contents only through A-2's sample script, which zeroes the identifiers.
LIMIT_PLIST="/Library/Preferences/com.apple.powerd.charging.plist"
LIMIT_TABLE="$WORK/charge-limit.tsv"
LIMIT_DIR="$LOGS/charge-limit"
MONITOR_PREDICATE="subsystem == \"$BUNDLE_ID\" AND category == \"monitor\""

# limit_line_in <ndjson> [<since>]: the last line of BatteryPulse's `monitor` category since then
# that names the Charge Limit (A-2 item 7: one line per read, its source's case name and the
# percent, `.public`) [its words unverified until A-2's line lands]; empty without one.
limit_line_in() {
  entries "$1" | awk -F '\t' -v s="${2:-}" '$2 == "BatteryPulse" && $1 >= s && tolower($3) ~ /limit/ { l = $3 } END { print l }'
}

# limit_number_of <line>: the first number in it from 50 to 100 (A-2 reads 80-100, Apple's range),
# else empty.
limit_number_of() {
  awk '{ n = split($0, w, /[^0-9]+/); for (i = 1; i <= n; i++) if (w[i] != "" && w[i] + 0 >= 50 && w[i] + 0 <= 100) { print w[i] + 0; exit } }' <<<"$1"
}

# limit_sample <tag>: A-2's scripts/charge-limit-sample.swift (A-2 item 6) on powerd's file, called
# as `xcrun swift scripts/charge-limit-sample.swift <powerd's file> <the redacted copy>`: it copies
# the file, zeroes bootSessionUUID, the token's bytes and owner's value in place, checks that the
# copy still decodes to the same number and prints it. The copy, battlimit's verbatim text and
# defaults' beside it, wait in samples/ for his yes before send, named by the read's tag alone
# (<tag>-powerd-charging.plist, <tag>-battlimit.txt, <tag>-batteryui.txt), never by a number
# battlimit_value read: the verbatim text is what checks battlimit_value (T-1 item 2), and a name
# taken from its own reading would pass any misread. A-2's fixtures take the number the policy
# decodes to (powerd-charging-<n>.plist, -none at 100 %), battlimit's text beside one the same
# number (powerd-charging-<n>-battlimit.txt), which the dry run holds battlimit_value to. Until A-2
# lands the script: "not run". Prints one phrase.
limit_sample() {
  local tag="$1" script="$ROOT/scripts/charge-limit-sample.swift" base log
  [ -f "$script" ] || {
    echo "not run: no scripts/charge-limit-sample.swift at the frozen commit"
    return 0
  }
  [ -f "$LIMIT_PLIST" ] || {
    echo "not run: no powerd file"
    return 0
  }
  mkdir -p "$WORK/samples"
  base="$WORK/samples/$tag"
  log="$LIMIT_DIR/$tag-sample.txt"
  if (cd "$ROOT" && xcrun swift "$script" "$LIMIT_PLIST" "$base-powerd-charging.plist") >"$log" 2>&1 &&
    [ -s "$base-powerd-charging.plist" ]; then
    cp "$LIMIT_DIR/$tag-battlimit.txt" "$base-battlimit.txt"
    cp "$LIMIT_DIR/$tag-batteryui.txt" "$base-batteryui.txt"
    echo "saved $tag-powerd-charging.plist, its decoded number: $(limit_number_of "$(tail -1 "$log")" || true)"
  else
    rm -f "$base-powerd-charging.plist"
    echo "failed: $(tail -1 "$log" | cut -c1-100)"
  fi
}

# limit_read <tag> [--since <time> <monitor capture>]: one row of G8-1's reads (PLAN.md §6.1 step
# 2), into charge-limit.tsv and the section: the power source and charge, bpulse --json's state,
# bit 24 and systemChargeLimitPercent (A-2's key, absent before A-2 and whenever unknown), pmset -g
# battlimit (its number, verbatim on the Mac), defaults read com.apple.batteryui.charging.mac (its
# limit lines), bpulse --smc's CHLT and CHNC (A-2 item 4 reads their values), powerd's file (present,
# its size and time, never its contents), the sample, and the app's own read: its `monitor` line
# about the limit, with BatteryPulse relaunched by default (its first read on the adapter after
# launch, A-2 item 3), or with --since from a running capture (an external-power change is its
# own trigger).
limit_read() {
  local tag="$1" since="" capture="" stream waited=0 json key row line number battlimit chlt chnc policy sample power
  case "$tag" in "" | *[!A-Za-z0-9.-]*) fail "a read's tag is letters, digits, dots and dashes" ;; esac
  mkdir -p "$LIMIT_DIR"
  if [ "${2:-}" = --since ]; then
    since="$3"
    capture="$4"
  else
    capture="$LIMIT_DIR/$tag-monitor.ndjson"
    since="$(clock)"
    /usr/bin/log stream --level debug --style ndjson --predicate "$MONITOR_PREDICATE" >"$capture" 2>"$capture.err" </dev/null &
    stream=$!
    STREAMS="$STREAMS $stream"
    sleep 2
    relaunch_r
    while [ "$waited" -lt 20 ] && [ -z "$(limit_line_in "$capture" "$since")" ]; do
      sleep 2
      waited=$((waited + 2))
    done
    perf_stop "$stream"
  fi
  line="$(limit_line_in "$capture" "$since")"
  number="$(limit_number_of "$line")"
  pmset -g battlimit >"$LIMIT_DIR/$tag-battlimit.txt" 2>&1 || true
  battlimit="$(battlimit_value "$LIMIT_DIR/$tag-battlimit.txt")"
  defaults read com.apple.batteryui.charging.mac >"$LIMIT_DIR/$tag-batteryui.txt" 2>&1 || true
  key="-"
  row="bpulse isn't built"
  if bpulse_json "$LIMIT_DIR/$tag.json"; then
    key="$(json_number "$LIMIT_DIR/$tag.json" systemChargeLimitPercent)"
    row="$(charge_row "$LIMIT_DIR/$tag.json")"
  fi
  chlt="-"
  chnc="-"
  if [ -x "$BIN/bpulse" ] && "$BIN/bpulse" --smc >"$LIMIT_DIR/$tag-smc.txt" 2>&1; then
    chlt="$(awk '$1 == "CHLT" { $1 = ""; sub(/^ +/, ""); print; exit }' "$LIMIT_DIR/$tag-smc.txt")"
    chnc="$(awk '$1 == "CHNC" { $1 = ""; sub(/^ +/, ""); print; exit }' "$LIMIT_DIR/$tag-smc.txt")"
  fi
  if [ -f "$LIMIT_PLIST" ]; then
    policy="$(wc -c <"$LIMIT_PLIST" | tr -d ' ') bytes, modified $(epoch_stamp "$(mtime_of "$LIMIT_PLIST")")"
  else
    policy=none
  fi
  if on_battery; then power=battery; else power=ac; fi
  sample="$(limit_sample "$tag")"
  mkdir -p "$WORK"
  printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n' "$tag" "$since" "$power" "${battlimit:-none}" "${key:--}" "${number:--}" \
    "$(if [ -n "$line" ]; then echo yes; else echo no; fi)" "$(printf '%s' "$policy" | tr '\t' ' ')" "$(printf '%s' "$sample" | tr '\t' ' ')" >>"$LIMIT_TABLE"
  use_section 10-charge-limit "The Charge Limit's check (G8-1)"
  out "- $tag ($since, $power): $row"
  out "  - pmset -g battlimit: ${battlimit:-none}; bpulse --json's systemChargeLimitPercent: ${key:-absent}; the app's line: ${line:-none} (its number ${number:--})"
  out "  - CHLT ${chlt:--}; CHNC ${chnc:--}; powerd's file: $policy; the sample: $sample"
  grep -i -E 'limit|soc' "$LIMIT_DIR/$tag-batteryui.txt" 2>/dev/null | head -6 >"$LIMIT_DIR/$tag-batteryui-limit.txt" || true
  if [ -s "$LIMIT_DIR/$tag-batteryui-limit.txt" ]; then
    out "  - defaults read com.apple.batteryui.charging.mac, its limit lines:"
    out_block "$LIMIT_DIR/$tag-batteryui-limit.txt"
  fi
  echo "LOOK the screen for a prompt (G8-5): a dialog now is a no for G8-5-limit"
}

# limit_wait_for <limit>: up to 3 minutes, on the adapter, for pmset -g battlimit to hold that
# limit (none for 100); prints what it holds then; true when it came.
limit_wait_for() {
  local want="$1" waited=0 now=""
  while [ "$waited" -le 180 ]; do
    now="$(battlimit_value)"
    if { [ "$want" = 100 ] && [ -z "$now" ]; } || { [ -n "$now" ] && [ "$now" = "$want" ]; }; then
      echo "${now:-none}"
      return 0
    fi
    sleep 5
    waited=$((waited + 5))
  done
  echo "${now:-none}"
  return 1
}

# limit_column <tag prefix> <column>: that column of the newest read whose tag starts so, else
# empty (2 time, 3 power, 4 battlimit, 5 the --json key, 6 the app's number, 7 the app's line, 8
# powerd's file, 9 the sample).
limit_column() { awk -F '\t' -v p="$1" -v c="$2" 'index($1, p) == 1 { v = $c } END { print v }' "$LIMIT_TABLE" 2>/dev/null || true; }

# limit_agrees <tag prefix>: the newest such read's app number and --json key equal battlimit's,
# battlimit holding one; prints why not.
limit_agrees() {
  local battlimit app key
  battlimit="$(limit_column "$1" 4)"
  app="$(limit_column "$1" 6)"
  key="$(limit_column "$1" 5)"
  [ -n "$battlimit" ] || {
    echo "no read tagged $1"
    return 1
  }
  [ "$battlimit" != none ] || {
    echo "battlimit held no limit"
    return 1
  }
  [ "$app" = "$battlimit" ] || {
    echo "the app's number ${app} against battlimit's $battlimit$(if [ "$(limit_column "$1" 7)" = no ]; then echo " (no line: A-2's line?)"; fi)"
    return 1
  }
  [ "$key" = "$battlimit" ] || {
    echo "bpulse --json's key ${key} against battlimit's $battlimit"
    return 1
  }
}

# limit_none <tag prefix>: the newest such read gave no number from the app or --json.
limit_none() {
  [ -n "$(limit_column "$1" 2)" ] || return 1
  [ "$(limit_column "$1" 6)" = - ] && { [ "$(limit_column "$1" 5)" = - ] || [ -z "$(limit_column "$1" 5)" ]; }
}

# limit_verdicts: G8-1's answers from charge-limit.tsv, the script's reading recorded as the
# session's (an unsure one joins his batch, with the table as its evidence): hold, second, full,
# battery, plugin, and the samples, whose decoded numbers the session compares with battlimit's.
limit_verdicts() {
  local why id sample
  if why="$(limit_agrees hold)"; then feed_verdict G8-1-hold y "the app, bpulse --json and battlimit read $(limit_column hold 4)" "$LIMIT_TABLE"
  elif [ -n "$(limit_column hold 2)" ] && [ "$(limit_column hold 7)" = no ]; then feed_verdict G8-1-hold unsure "$why" "$LIMIT_TABLE"
  elif [ -n "$(limit_column hold 2)" ]; then feed_verdict G8-1-hold n "$why" "$LIMIT_TABLE"
  else not_checked G8-1-hold "no read at the hold"; fi
  if [ -z "$(limit_column second 2)" ]; then not_checked G8-1-second "no second limit above the charge"
  elif [ "$(limit_column second 4)" = none ] && limit_none second; then feed_verdict G8-1-second y "battlimit, the app and bpulse --json all without a number while charging toward the limit" "$LIMIT_TABLE"
  elif why="$(limit_agrees second)"; then feed_verdict G8-1-second y "the app, bpulse --json and battlimit read $(limit_column second 4)" "$LIMIT_TABLE"
  else feed_verdict G8-1-second "$(if [ "$(limit_column second 7)" = no ]; then echo unsure; else echo n; fi)" "$why" "$LIMIT_TABLE"; fi
  if [ -z "$(limit_column full 2)" ]; then not_checked G8-1-full "no read at 100 %"
  elif [ "$(limit_column full 4)" = none ] && limit_none full; then feed_verdict G8-1-full y "no limit in battlimit, no number from the app or bpulse --json" "$LIMIT_TABLE"
  else feed_verdict G8-1-full n "battlimit $(limit_column full 4), the app $(limit_column full 6), bpulse --json $(limit_column full 5)" "$LIMIT_TABLE"; fi
  if [ -z "$(limit_column battery-1 2)" ] || [ -z "$(limit_column battery-6 2)" ]; then not_checked G8-1-battery "the reads on battery didn't both run"
  elif limit_none battery-1 && limit_none battery-6; then
    sample="$(limit_column battery-6 9)"
    feed_verdict G8-1-battery y "no number at 1 or 6 minutes; the policy at 6 minutes, by the sample: ${sample:-not read}" "$LIMIT_TABLE"
  else feed_verdict G8-1-battery n "a number on battery: the app $(limit_column battery-1 6) and $(limit_column battery-6 6), bpulse --json $(limit_column battery-1 5) and $(limit_column battery-6 5)" "$LIMIT_TABLE"; fi
  if [ -z "$(limit_column plugin- 2)" ]; then not_checked G8-1-plugin "no read after the plug-in"
  else
    id=""
    for why in plugin-5s plugin-1min; do
      if [ "$(limit_column "$why" 4)" != none ] && [ -n "$(limit_column "$why" 4)" ] && limit_agrees "$why" >/dev/null; then id="$why"; fi
    done
    if [ -n "$id" ]; then feed_verdict G8-1-plugin y "battlimit and the app's number back at $id ($(limit_column "$id" 4))" "$LIMIT_TABLE"
    elif [ -n "$(limit_column plugin-1min 4)" ] && [ "$(limit_column plugin-1min 4)" != none ]; then feed_verdict G8-1-plugin unsure "battlimit back ($(limit_column plugin-1min 4)) but the app's number $(limit_column plugin-1min 6)" "$LIMIT_TABLE"
    else feed_verdict G8-1-plugin n "battlimit holds none a minute after the plug-in" "$LIMIT_TABLE"; fi
  fi
  if [ ! -f "$ROOT/scripts/charge-limit-sample.swift" ]; then step_answer --by claude L-samples 3 "no sample script at the frozen commit" >/dev/null
  elif awk -F '\t' '$3 == "ac" && index($9, "failed") == 1 { f = 1 } END { exit !f }' "$LIMIT_TABLE" 2>/dev/null; then
    feed_verdict L-samples 2 "a sample failed: see the reads" "$LIMIT_TABLE"
  else
    feed_verdict L-samples unsure "every sample saved: compare each decoded number with its battlimit in the reads" "$LIMIT_TABLE"
  fi
  ask G8-5-limit
}

# charge-limit read <tag> | set <n> | hold | unplug | back | verdicts (the look shoot's step 2,
# Session R8's step 9; PLAN.md §6.1 step 2): G8-1, the Charge Limit's number read by the app from
# powerd's file against pmset -g battlimit, defaults and bpulse --smc, on the adapter and on battery.
#   read <tag>: every read now (limit_read), BatteryPulse relaunched for its own;
#   set <n>:    after the session moved the slider by computer use (System Settings → Battery → (i)
#               next to Charging; `change charge-limit <prepare's> <n>` first): up to 3 minutes for
#               battlimit to hold n (none for 100), then the reads, tagged full at 100;
#   hold:       one look, no wait: is the charge held at the limit (bpulse --json: not charging on
#               the adapter, or bit 24)? Then the reads, tagged hold; else when to look again (the
#               session shoots step 3's screens meanwhile, at most an hour after the set);
#   unplug:     a beep to unplug (a background task, about 9 minutes): reads 1 and 6 minutes on
#               battery, a second beep to plug in, reads 5 s and 1 minute after it, from one capture
#               of the app's lines (the power change is the app's own trigger);
#   back:       after the slider went back to prepare's value: battlimit holds it (or none for 100),
#               then `restored charge-limit` by the script;
#   verdicts:   G8-1's answers from the reads (limit_verdicts).
step_charge_limit() {
  rl_only charge-limit
  local limit now at plug waited=0 capture
  limit="$(answer_of prep-charge-limit)"
  case "${1:-}" in
    read)
      [ $# -eq 2 ] || fail "usage: $SCRIPT charge-limit read <tag>"
      limit_read "$2"
      ;;
    set)
      case "${2:-}" in 8[0-9] | 9[0-9] | 100) ;; *) fail "usage: $SCRIPT charge-limit set <80-100> (Apple's range)" ;; esac
      [ -n "$(original_of charge-limit)" ] || fail "record the change first: $SCRIPT change charge-limit ${limit:-<the value prepare read>} $2"
      ! on_battery || fail "on battery battlimit holds no limit: set it with the adapter in"
      if now="$(limit_wait_for "$2")"; then
        clock >"$WORK/limit-set.time"
        echo "$2" >"$WORK/limit-set.value"
        if [ "$2" = 100 ]; then limit_read full; else echo "battlimit holds $now: now $SCRIPT charge-limit hold (the hold), or charge-limit read second (a limit above the charge)"; fi
      else
        not_checked "charge-limit-$2" "battlimit held $now, not $2, within 3 minutes of the slider"
      fi
      ;;
    hold)
      mkdir -p "$LIMIT_DIR"
      bpulse_json "$LIMIT_DIR/hold-look.json" || fail "bpulse isn't built (see $BIN/bpulse.log)"
      now="$(charge_row "$LIMIT_DIR/hold-look.json")"
      case "$now" in
        *"external power true"*"bit 24: yes"* | *notCharging*"external power true"*)
          echo "HELD: $now"
          limit_read hold
          ;;
        *)
          at="$(date -j -f '%Y-%m-%d %H:%M:%S' "$(cat "$WORK/limit-set.time" 2>/dev/null || clock)" +%s 2>/dev/null || date +%s)"
          if [ $(($(date +%s) - at)) -gt 3600 ]; then
            not_checked G8-1-hold "no hold within an hour of the set: $now"
          else
            echo "NOT YET ($now): shoot step 3's next screen, then $SCRIPT charge-limit hold again (until $(epoch_hm $((at + 3600))))"
          fi
          ;;
      esac
      ;;
    unplug)
      ! on_battery || fail "the adapter must be in at the start: plug it in first"
      mkdir -p "$LIMIT_DIR"
      capture="$LIMIT_DIR/unplug-monitor.ndjson"
      /usr/bin/log stream --level debug --style ndjson --predicate "$MONITOR_PREDICATE" >"$capture" 2>"$capture.err" </dev/null &
      STREAMS="$STREAMS $!"
      sleep 2
      cue "Unplug the adapter now"
      sound Glass
      while ! on_battery && [ "$waited" -lt 120 ]; do
        sleep 2
        waited=$((waited + 2))
      done
      on_battery || {
        not_checked G8-1-battery "no unplug within 2 minutes of the beep"
        return 0
      }
      at="$(date +%s)"
      clock >"$WORK/limit-unplug.time"
      sleep_until $((at + 60))
      limit_read battery-1min --since "$(epoch_stamp "$at")" "$capture"
      sleep_until $((at + 360))
      limit_read battery-6min --since "$(epoch_stamp $((at + 60)))" "$capture"
      cue "Plug the adapter in now"
      sound Hero
      waited=0
      while on_battery && [ "$waited" -lt 120 ]; do
        sleep 1
        waited=$((waited + 1))
      done
      ! on_battery || {
        not_checked G8-1-plugin "no plug-in within 2 minutes of the beep"
        return 0
      }
      plug="$(date +%s)"
      sleep_until $((plug + 5))
      limit_read plugin-5s --since "$(epoch_stamp "$plug")" "$capture"
      sleep_until $((plug + 60))
      limit_read plugin-1min --since "$(epoch_stamp "$plug")" "$capture"
      ;;
    back)
      [ -n "$limit" ] || fail "prepare's Charge Limit is unknown (prep-charge-limit): never changed, nothing to put back"
      if on_battery; then
        echo "on battery battlimit holds none: confirm the Battery pane's shot, then $SCRIPT restored charge-limit \"<the shot>\""
        return 0
      fi
      if now="$(limit_wait_for "$limit")"; then
        mark_restored charge-limit "pmset -g battlimit holds ${now} (prepare's $limit)"
        [ "$SESSION" != L ] || step_answer --by claude L-limit-back y "pmset -g battlimit holds $now, prepare's $limit" >/dev/null
        echo "the Charge Limit is back at $limit %"
      else
        echo "THE CHARGE LIMIT READS $now, NOT $limit %: put it back by computer use (System Settings → Battery), then charge-limit back again"
        return 1
      fi
      ;;
    verdicts)
      [ "$SESSION" = L ] || fail "charge-limit verdicts is the look shoot's (G8-1); Session R8's step 9 answers R-limit-live"
      limit_verdicts
      ;;
    *) fail "usage: $SCRIPT charge-limit read <tag> | set <n> | hold | unplug | back | verdicts" ;;
  esac
}

# MARK: - The short sessions: the hold watch (H)

# hold_captures: the night's captures whose IOPS power source says Optimized Battery Charging
# Engaged (G8-2's evidence), each with its NotChargingReason and whether bit 24 is set, into the
# section; at most three of them copied into captures/, which send commits after his yes.
hold_captures() {
  local capture flagged=0 reason text
  mkdir -p "$WORK/captures"
  while IFS= read -r capture; do
    [ -n "$capture" ] || continue
    # Read whole first: grep -q under pipefail would stop plutil (status 141) and skip a match.
    text="$(plutil -p "$capture" 2>/dev/null || true)"
    grep -q -E '"Optimized Battery Charging Engaged" => (1|true)' <<<"$text" || continue
    flagged=$((flagged + 1))
    reason="$(sed -n 's/.*"NotChargingReason" => \([0-9]*\).*/\1/p' <<<"$text" | head -1 || true)"
    out "- $(basename "$capture"): Optimized Battery Charging Engaged, NotChargingReason ${reason:--} (bit 24: $(if [ -n "$reason" ] && [ $((reason & 0x01000000)) -ne 0 ]; then echo yes; else echo no; fi))"
    if [ "$flagged" -le 3 ]; then cp "$capture" "$WORK/captures/hold-$(basename "$capture")"; fi
  done < <(find "$(record_folder)" -name '*.plist' -type f 2>/dev/null | sort)
  out "- captures with Optimized Battery Charging Engaged: $flagged (at most three in captures/, sent only after his yes)"
}

# hold-watch start | morning: QUA-06 and G8-2, an optimized-charging hold overnight, offered again
# before 0.8's D1 (PLAN.md I-8): a recording under caffeinate -i, the Mac on the adapter with the
# lid open; in the morning, whether the charge was held below 100 % on the adapter for 15 minutes
# or more, with its NotChargingReason values, and the recorded captures whose power source says
# Optimized Battery Charging Engaged (the evidence G8-2 asks for, with whether bit 24 is set with
# it), copied into captures/ for his yes before send (bpulse --record keeps them redacted). Whether
# macOS holds the charge while the Mac is kept awake is uncertain.
step_hold_watch() {
  session_only H hold-watch
  local file
  use_section 10-hold "The hold watch (QUA-06)"
  case "${1:-}" in
    start)
      [ "$(answer_of H-yes)" = y ] || fail "first his yes: $SCRIPT answer --by person H-yes y"
      mkdir -p "$WORK" "$LOGS" "$SECTIONS"
      [ -f "$WORK/prepare.time" ] || clock >"$WORK/prepare.time"
      ! on_battery || fail "on battery: the watch runs on the adapter; plug it in, then start again"
      out "- started $(clock) at $(battery_percent) %, on the adapter; the Charge Limit: $(battlimit_value || true)"
      record_start "night-$(date '+%Y%m%d')"
      echo "Tell him: leave the Mac plugged in with the lid open; in the morning, write morning"
      ;;
    morning)
      stop_leftovers record
      file="$(record_folder)/timeline.tsv"
      [ -s "$file" ] || fail "no timeline in $(record_folder)"
      awk -F '\t' '
        NR > 1 {
          held = ($3 == "notCharging" && $4 == "true" && $2 + 0 < 100)
          if (held && start == "") { start = $1; reasons = "" }
          if (held && index(" " reasons " ", " " $5 " ") == 0) reasons = reasons " " $5
          if (!held && start != "") { print start " to " $1 ", NotChargingReason" reasons; start = "" }
        }
        END { if (start != "") print start " to the end, NotChargingReason" reasons }' "$file" >"$LOGS/holds.txt"
      out "- the night ($(head -2 "$file" | tail -1 | cut -f1) to $(tail -1 "$file" | cut -f1)): the spans held below 100 % on the adapter:"
      out_block "$LOGS/holds.txt"
      hold_captures
      echo "Judge H-hold from them: a span of 15 minutes or more is a hold (1), none is 2"
      ask H-hold
      ;;
    *) fail "usage: $SCRIPT hold-watch start | morning" ;;
  esac
}

# MARK: - The short sessions: after publishing (D3; PLAN.md §6.6)

# after before | after | popover: the after-publishing check (PLAN.md §6.6). before (rule 6: he
# hasn't installed it himself): pluginkit, the widgets' crops after the desktop click (rule 3), the
# extension's pids, the time, right before Check for Updates and Install and Relaunch by AX
# presses; after (waits for 0.8.0, at most 3 minutes): the update log's pre-swap line and
# CHSErrorDomain 1103, pluginkit, the crops once a new extension process drew them (rule 4: none is
# "not checked"), `codesign -dv --verbose=4` and `xattr -l` (P7 §6.4's list), then the feed's modes
# and the widget's exception (`feed check`); popover: the first day's comparison, the popover
# beside the widgets.
step_after() {
  session_only D3 after
  local waited=0 flags quarantine swap fresh=""
  use_section 10-after "After publishing (§6.6)"
  case "${1:-}" in
    before)
      [ "$(answer_of D3-yes)" = y ] || fail "first his yes: $SCRIPT answer --by person D3-yes y"
      mkdir -p "$WORK" "$LOGS" "$SECTIONS" "$SHOTS"
      [ -f "$WORK/prepare.time" ] || clock >"$WORK/prepare.time"
      clock >"$WORK/after.time"
      widget_pids | tr '\n' ' ' >"$WORK/after-before.pids"
      pluginkit -mv -i "$WIDGET_ID" >"$LOGS/pluginkit-before.txt" 2>&1 || true
      click_desktop || not_checked D3-widgets "no desktop spot"
      crop_widgets "$SHOTS/after" before
      out "- before ($(cat "$WORK/after.time")): $(app_version); widget extension pids: $(cat "$WORK/after-before.pids")"
      out_block "$LOGS/pluginkit-before.txt"
      echo "DO (session): Check for Updates, then Install and Relaunch to $RELEASE_VERSION, by AX presses; then: $SCRIPT after after"
      ;;
    after)
      [ -f "$WORK/after.time" ] || fail "first: $SCRIPT after before"
      until [ "$(plist_value "$APP/Contents/Info.plist" CFBundleShortVersionString)" = "$RELEASE_VERSION" ] || [ "$waited" -ge 180 ]; do
        sleep 1
        waited=$((waited + 1))
      done
      sleep 10
      out "- after: $(app_version), running $(if app_running; then echo yes; else echo no; fi)"
      log_since "$(cat "$WORK/after.time")" "$UPDATE_PREDICATE" "$LOGS/after-update.ndjson" >/dev/null
      swap="$(messages "$LOGS/after-update.ndjson" | grep -F 'extension before the swap' | head -1 || true)"
      out "- the updating installer's pre-swap line (every BatteryPulseWidget process ended, D-17): ${swap:-none}; $(chs_since "$(cat "$WORK/after.time")")"
      pluginkit -mv -i "$WIDGET_ID" >"$LOGS/pluginkit-after.txt" 2>&1 || true
      out_block "$LOGS/pluginkit-after.txt"
      flags="$(codesign -dv --verbose=4 "$APP" 2>&1 | grep -o 'flags=[^ ]*' | head -1 || true)"
      quarantine="$(xattr -l "$APP" 2>/dev/null | grep -c com.apple.quarantine || true)"
      out "- codesign: ${flags:-no flags line} (expected flags=0x10002(adhoc,runtime)); quarantine lines: $quarantine (expected 0)"
      fresh="$(fresh_widget_pid "$(cat "$WORK/after-before.pids" 2>/dev/null || true)")"
      out "- a widget extension process since before (rule 4's redraw): ${fresh:-none within a minute}"
      click_desktop || true
      if [ -n "$fresh" ]; then crop_widgets "$SHOTS/after" after; else
        not_checked D3-widgets "no redraw: no widget extension process that wasn't there before the update"
      fi
      step_feed check
      echo "Read About, What's New, History and the settings by computer use (shots); Help → Report a Problem… by $SCRIPT ui press, then $SCRIPT screen report-problem front (D3-report); $SCRIPT help-link (D3-help); Login Items only by $SCRIPT pane login-items and $SCRIPT ui tree \"System Settings\" --match BatteryPulse (no shot of that pane); then answer, and last: $SCRIPT capacity after"
      ask D3-version D3-whats-new D3-count-row D3-widgets D3-history D3-settings D3-login-item D3-notifications D3-prompt D3-report
      ;;
    popover)
      click_desktop || true
      crop_widgets "$SHOTS/after" first-day
      popover_shot "$SHOTS/after/popover.png" ||
        not_checked D3-first-day "no shot of the popover: computer use opens it from the menu bar item"
      park_pointer
      ask D3-first-day
      ;;
    *) fail "usage: $SCRIPT after before | after | popover" ;;
  esac
}

# MARK: - The dry run (CI on Linux)

# dry-run: Session R's bookkeeping on any machine, in a folder of its own, with nothing of the Mac:
# every session's questions resolve; the setting names the runbook records come back the right
# way; answer and judge validate and record (an unsure judgment joins his batch); English only;
# the change record and its restored lines; the logged day's fence and its day-end; the summary's
# alerts; the report and its privacy lint. Exit status 1 on a broken rule.
dry_run() {
  local problems=0 id session setting report printed feed facts counts="" starts runbook section bytes status other
  local wanted missing name names found file want got
  DRY_RUN=1
  check() {
    if [ "$1" = ok ]; then echo "ok: $2"; else
      echo "FAIL: $2" >&2
      problems=$((problems + 1))
    fi
  }
  mkdir -p "$WORK" "$SECTIONS" "$LOGS"
  for session in R L H D3; do
    SESSION="$session"
    for id in $(questions_list); do
      if question "$id" >/dev/null; then :; else check fail "$session's question $id has no text"; fi
    done
    counts="${counts:+$counts, }$session $(questions_list | wc -w | tr -d ' ')"
  done
  SESSION=R
  check ok "every session's questions resolve ($counts)"
  echo "Session R's questions: $(questions_list | tr '\n' ' ')"
  for setting in app bp-settings bp-support widget-data remembered-devices widget-languages history \
    app-language has-seen-welcome bp-window-style sentinel-accessories sentinel-devices; do
    [ "$(restore_how "$setting")" = script ] && check ok "$setting comes back by the script" ||
      check fail "$setting should come back by the script"
  done
  for setting in widget-style dim-widgets text-size increase-contrast reduce-transparency 24-hour \
    open-at-login bluetooth-accessory widget-choices charge-limit desktop-widgets appearance wallpaper \
    keyboard-navigation reduce-motion cross-fade show-borders liquid-glass; do
    [ "$(restore_how "$setting")" != script ] && check ok "$setting comes back by the session ($(restore_phase "$setting"))" ||
      check fail "$setting has no way back for the session"
  done
  [ "$(restore_phase desktop-widgets)" = end ] && [ "$(restore_phase widget-style)" = gui ] &&
    check ok "the gallery's widgets go at the end, the system settings before the logged day" ||
    check fail "restore_phase puts a setting in the wrong half"
  step_answer --by person R-yes y >/dev/null && [ "$(answer_of R-yes)" = y ] && check ok "answer records" ||
    check fail "answer doesn't record"
  if (step_answer --by person R-yes maybe >/dev/null 2>&1); then check fail "a yes/no question took 'maybe'"; else
    check ok "a yes/no question refuses another word"
  fi
  if (step_answer --by claude R2-small 5 >/dev/null 2>&1); then check fail "a 1-4 question took 5"; else
    check ok "a numbered question refuses a number past its last"
  fi
  if (step_note "$(printf 'note \320\277')" >/dev/null 2>&1); then check fail "a note took Russian"; else
    check ok "a note refuses Russian"
  fi
  step_judge R2-small 1 >/dev/null && [ "$(answer_of R2-small)" = 1 ] && check ok "judge records" || check fail "judge doesn't record"
  step_judge R4-3-sheet 2 --unsure "the sheet's title stays English" >/dev/null
  [ "$(answer_of R4-3-sheet)" = unsure ] && grep -q '^R4-3-sheet' "$BATCH" && check ok "an unsure judgment joins his batch" ||
    check fail "an unsure judgment didn't join his batch"
  step_change widget-style Default Dark >/dev/null
  step_change 24-hour on off >/dev/null
  if (step_change text-size unknown larger >/dev/null 2>&1); then check fail "a setting with an unknown original changed"; else
    check ok "a setting whose original is unknown is never changed"
  fi
  is_restored widget-style && check fail "widget-style counts as restored before its restored line" ||
    check ok "a change waits for its restored line"
  sleep 1
  step_restored widget-style "a shot of the pane" >/dev/null
  is_restored widget-style && check ok "restored confirms it" || check fail "restored didn't confirm it"
  step_summary gui >"$LOGS/dry-summary.txt"
  grep -q '^ALERT 24-hour' "$LOGS/dry-summary.txt" && ! grep -q '^ALERT widget-style' "$LOGS/dry-summary.txt" &&
    check ok "the summary alerts for what isn't back, and only that" || check fail "the summary's alerts are wrong"
  printf 'ready %s\n' "$(clock)" >"$READY_FILE"
  if (r_fence >/dev/null 2>&1); then check fail "the fence let a command through on the logged day"; else
    check ok "ready fences every command until day-end"
  fi
  sleep 1
  clock >"$DAY_END"
  if (r_fence >/dev/null 2>&1); then check ok "a newer day-end opens the fence"; else check fail "day-end didn't open the fence"; fi
  not_checked R7-tree "the dry run's own not-checked line" >/dev/null
  step_note "the dry run's note" >/dev/null
  report="$WORK/dry-report.md"
  build_report | public >"$report"
  grep -q '^| R-yes |' "$report" && grep -q '^## Not checked or not run' "$report" && grep -q '^## Notes' "$report" &&
    check ok "the report holds the answers, the not-checked lines and the notes" || check fail "the report misses a part"
  grep -q 'Not put back (for his hand):\*\* 24-hour' "$report" && check ok "the report heads with what isn't back" ||
    check fail "the report doesn't head with what isn't back"
  if has_cyrillic "$(cat "$report")"; then check fail "the report has Russian text"; else check ok "the report is English"; fi
  (privacy_lint "$report" >/dev/null 2>&1) && check ok "the privacy lint passes a clean report" ||
    check fail "the privacy lint refused a clean report"
  # T-1 item 2: these two forms are Session A's paraphrase of pmset -g battlimit, not its verbatim
  # text, which only A-2's sample brings (the look shoot saves it as samples/<tag>-battlimit.txt,
  # named by the read alone). Committed beside A-2's fixtures, it takes the number its policy
  # decodes to, A-2's parser's and not battlimit_value's (powerd-charging-<n or none>-battlimit.txt,
  # as powerd-charging-<n>.plist), and must read as that number: a name from battlimit_value's own
  # reading would pass any misread. Until one is there, the parse stays unverified, for A-2 to close.
  [ "$(battlimit_value <(printf ' Battery level limits:\n  chargeSocLimitSoc = 80\n'))" = 80 ] &&
    check ok "battlimit's chargeSocLimitSoc reads as the limit [Session A's paraphrase]" || check fail "battlimit's value isn't read"
  [ -z "$(battlimit_value <(printf 'No battery level limits set\n'))" ] && check ok "no limit reads as none [Session A's paraphrase]" ||
    check fail "no limit didn't read as none"
  found=0
  while IFS= read -r file; do
    [ -n "$file" ] || continue
    found=$((found + 1))
    want="$(basename "$file" | sed -E -n 's/^powerd-charging-([0-9]+|none)(-[A-Za-z0-9.]+)*-battlimit\.txt$/\1/p')"
    got="$(battlimit_value "$file")"
    if [ -z "$want" ]; then
      check fail "battlimit's verbatim $(basename "$file") isn't named powerd-charging-<the number its policy decodes to, or none>-battlimit.txt"
    elif { [ "$want" = none ] && [ -z "$got" ]; } || { [ -n "$got" ] && [ "$got" = "$want" ]; }; then
      check ok "A-2's verbatim battlimit $(basename "$file") reads as ${got:-none}, the number its policy decodes to"
    else
      check fail "A-2's verbatim battlimit $(basename "$file") reads as ${got:-none}, not $want, the number its policy decodes to: battlimit_value misreads it"
    fi
  done < <(find "$ROOT/Tests/BatteryCoreTests/Fixtures" "$HERE/sessions" -type f -name 'powerd-charging-*battlimit*.txt' 2>/dev/null | sort)
  [ "$found" -gt 0 ] ||
    echo "unverified: pmset -g battlimit's verbatim text: no A-2 sample beside its fixture yet (powerd-charging-<n or none>-battlimit.txt, named by the number its policy decodes to), so the forms above are Session A's paraphrase (T-1 item 2)"
  # The feed's facts on W-5's format (WidgetFeed.encoded: compact, sorted keys, dates in seconds).
  feed="$WORK/feed.json"
  printf '%s' '{"day":{"batteryWatts10":[null,-52,null],"percent":[null,81,80],"plugged":[null,false,false],"start":1730800800,"step":900,"temperature10":[null,301,null]},"devices":[{"deviceClass":"iPhone","key":"0a1b2c3d4e5f6a7b8c9d0e1f2a3b4c5d","name":"Phone","percent":64,"readAt":1730801400,"state":"charging"},{"key":"9f8e7d6c5b4a39281706f5e4d3c2b1a0","state":"unknown"}],"languages":["ru","en"],"readsDevices":true,"recordsHistory":true,"version":1,"writtenAt":1730801700}' >"$feed"
  facts="$(feed_facts "$feed")"
  [ "$(fact "$facts" version)" = 1 ] && [ "$(fact "$facts" written)" = 1730801700 ] && [ "$(fact "$facts" days)" = 2 ] &&
    [ "$(fact "$facts" devices)" = 2 ] && [ "$(fact "$facts" named)" = 1 ] && [ "$(fact "$facts" forbidden)" = 0 ] &&
    [ "$(fact "$facts" demo)" = 0 ] && [ "$(fact "$facts" reads)" = true ] && [ "$(fact "$facts" records)" = true ] &&
    check ok "the feed's facts read W-5's format ($facts)" || check fail "the feed's facts misread W-5's format ($facts)"
  printf '%s' '{"devices":[{"key":"demo","serialNumber":"X","state":"unknown","udid":"Y"}],"languages":[],"readsDevices":false,"recordsHistory":false,"version":2,"writtenAt":1730801700.0}' >"$feed"
  facts="$(feed_facts "$feed")"
  [ "$(fact "$facts" demo)" = 1 ] && [ "$(fact "$facts" forbidden)" = 2 ] && [ "$(fact "$facts" days)" = 0 ] &&
    [ "$(fact "$facts" written)" = 1730801700 ] && [ "$(fact "$facts" version)" = 2 ] &&
    check ok "a demo key, a udid and a serial are found, and no day is none" || check fail "the feed's checks miss a key ($facts)"
  [ "$(feed_facts "$WORK/no-feed.json")" = missing ] && check ok "no feed reads as missing" || check fail "a missing feed isn't missing"
  # Each `log` run logs its own command line, predicate and all, so a predicate on eventMessage
  # alone finds it: never a sandbox denial or an 1103 line (Session F's R-feed-history).
  printf '%s\n' \
    '{"timestamp":"2026-11-06 12:48:14.101010+0300","processImagePath":"/usr/bin/log","eventMessage":"log run noninteractively, args: show --predicate eventMessage CONTAINS \"Sandbox: BatteryPulseWidget\" AND eventMessage CONTAINS \"deny\""}' \
    '{"timestamp":"2026-11-06 12:48:14.202020+0300","processImagePath":"/kernel","eventMessage":"Sandbox: BatteryPulseWidget(857) deny(1) file-read-data /Users/someone/Library/Application Support/io.github.nikitausov.BatteryPulse/Widget/feed.json"}' \
    '{"timestamp":"2026-11-06 12:48:14.303030+0300","processImagePath":"/kernel","eventMessage":"Sandbox: BatteryPulseWidget(857) deny(1) file-read-data /Users/someone/Library/Application Support/io.github.nikitausov.BatteryPulse/History"}' \
    '{"count":3,"finished":1}' >"$LOGS/dry-denials.ndjson"
  feed_denials_count 12:48:00 "$LOGS/dry-denials.ndjson"
  [ "$FEED_DENIALS" = 2 ] && grep -q -F "in Widget/: 1 (1 of the log tool's own left out" <<<"$FEED_DENIALS_LINE" &&
    check ok "the sandbox denials are the kernel's, the log tool's own line left out" ||
    check fail "the denials count the log tool's own line ($FEED_DENIALS_LINE)"
  printf '%s\n' \
    '{"timestamp":"2026-11-06 12:53:02.101010+0300","processImagePath":"/usr/bin/log","eventMessage":"log run noninteractively, args: show --predicate eventMessage CONTAINS \"CHSErrorDomain\" AND eventMessage CONTAINS \"1103\""}' \
    '{"timestamp":"2026-11-06 12:57:02.101010+0300","processImagePath":"/usr/bin/log","eventMessage":"log run noninteractively, args: show --predicate eventMessage CONTAINS \"CHSErrorDomain\" AND eventMessage CONTAINS \"1103\""}' \
    '{"timestamp":"2026-11-06 12:57:03.101010+0300","processImagePath":"/System/Library/PrivateFrameworks/ChronoCore.framework/Support/chronod","eventMessage":"Error Domain=CHSErrorDomain Code=1103 \"Intent configuration is required but was not provided\""}' \
    '{"count":3,"finished":1}' >"$LOGS/dry-chs.ndjson"
  [ "$(chs_line 12:52:01 "$LOGS/dry-chs.ndjson")" = "CHSErrorDomain 1103 lines since 12:52:01: 1 (2 of the log tool's own left out)" ] &&
    check ok "the CHSErrorDomain 1103 lines are chronod's, the log tool's own two left out" ||
    check fail "the 1103 count reads the log tool's own lines ($(chs_line 12:52:01 "$LOGS/dry-chs.ndjson"))"
  [ "$(percent_of 5711 5760)" = 99.15 ] && [ "$(percent_of - 5760)" = - ] && check ok "capacity's ratio reads as the plan's 99.15 %" ||
    check fail "capacity's ratio is wrong"
  # T-1 item 7: the session's gallery widgets come back only by the app's counts against prepare's.
  printf '%s\n' \
    '{"timestamp":"2026-11-06 19:28:20.101010+0300","processImagePath":"/Applications/BatteryPulse.app/Contents/MacOS/BatteryPulse","eventMessage":"Placed widgets: 1 in all, 1 Battery, 0 Accessories, 0 History, 0 iPhone & iPad"}' \
    '{"timestamp":"2026-11-06 19:28:33.101010+0300","processImagePath":"/Applications/BatteryPulse.app/Contents/MacOS/BatteryPulse","eventMessage":"Placed widgets, for the widget feed: 2 in all, 1 Battery, 0 Accessories, 0 History, 1 iPhone & iPad"}' \
    '{"count":2,"finished":1}' >"$LOGS/dry-placed.ndjson"
  [ "$(placed_counts_in "$LOGS/dry-placed.ndjson")" = "2 1 0 0 1" ] &&
    check ok "the app's counts read from its last Placed widgets line (the feed writer's, as AP71's day logged it)" ||
    check fail "the Placed widgets line misread ($(placed_counts_in "$LOGS/dry-placed.ndjson"))"
  placed_record prepare "1 1 0 0 0"
  step_change desktop-widgets "his: 1 Battery" "the gallery's: 1 iPhone & iPad" >/dev/null
  if (step_restored desktop-widgets "the session's word" >/dev/null 2>&1); then check fail "restored took desktop-widgets on the session's word"; else
    check ok "desktop-widgets never comes back on the session's word"
  fi
  placed_record end "2 1 0 0 1"
  widgets_verdict >/dev/null
  step_summary end >"$LOGS/dry-summary-end.txt"
  grep -q '^ALERT desktop-widgets: iPhone & iPad 1, prepare 0: 1 the session added stayed' "$LOGS/dry-summary-end.txt" && ! is_restored desktop-widgets &&
    check ok "a count above prepare's reads as stayed: an ALERT for that kind, and desktop-widgets not back" ||
    check fail "a count above prepare's didn't read as stayed ($(grep desktop-widgets "$LOGS/dry-summary-end.txt" | head -2 | tr '\n' ' '))"
  grep -q 'iPhone & iPad 1, prepare 0' "$WORK/sections/96-widgets.md" && check ok "the report's section says what stayed, by kind and count" ||
    check fail "the report's section misses what stayed"
  placed_record check-1 "1 0 0 0 1"
  # Each output is read whole first: grep -q under pipefail would stop its writer (status 141).
  printed="$(placed_lines)"
  [ "$(grep -c '^ALERT desktop-widgets' <<<"$printed")" = 2 ] && grep -q 'Battery 0, prepare 1: 1 of his own gone' <<<"$printed" &&
    check ok "a count below prepare's reads as one of his own gone, each kind its own ALERT" || check fail "a count below prepare's isn't an ALERT ($printed)"
  placed_record check-2 "1 1 0 0 0"
  widgets_verdict >/dev/null
  printed="$(step_summary end)"
  is_restored desktop-widgets && ! grep -q '^ALERT desktop-widgets' <<<"$printed" && grep -q '^WIDGETS back at prepare' <<<"$printed" &&
    check ok "counts back at prepare's record desktop-widgets back, by the script" || check fail "counts back at prepare's didn't record desktop-widgets back"
  : >"$PLACED"
  placed_record prepare unknown
  placed_record check-3 "1 1 0 0 0"
  printed="$(placed_lines)"
  grep -q '^ALERT desktop-widgets: prepare.s counts of the placed widgets are unknown' <<<"$printed" &&
    check ok "unknown counts at prepare confirm nothing: an ALERT" || check fail "unknown counts at prepare didn't alert"
  # G8-1's verdicts from the reads' table (the look shoot's step 2).
  SESSION=L
  printf '%s\n' \
    "hold$TAB$(clock)${TAB}ac${TAB}80${TAB}80${TAB}80${TAB}yes${TAB}1210 bytes${TAB}not run" \
    "second$TAB$(clock)${TAB}ac${TAB}none$TAB-$TAB-${TAB}no${TAB}1210 bytes${TAB}not run" \
    "full$TAB$(clock)${TAB}ac${TAB}none$TAB-$TAB-${TAB}no${TAB}none${TAB}not run" \
    "battery-1min$TAB$(clock)${TAB}battery${TAB}none$TAB-$TAB-${TAB}no${TAB}none${TAB}not run" \
    "battery-6min$TAB$(clock)${TAB}battery${TAB}none$TAB-$TAB-${TAB}no${TAB}none${TAB}not run" \
    "plugin-5s$TAB$(clock)${TAB}ac${TAB}none$TAB-$TAB-${TAB}no${TAB}none${TAB}not run" \
    "plugin-1min$TAB$(clock)${TAB}ac${TAB}80${TAB}80${TAB}80${TAB}yes${TAB}1210 bytes${TAB}not run" >"$LIMIT_TABLE"
  limit_verdicts >/dev/null
  [ "$(answer_of G8-1-hold)" = y ] && [ "$(answer_of G8-1-second)" = y ] && [ "$(answer_of G8-1-full)" = y ] &&
    [ "$(answer_of G8-1-battery)" = y ] && [ "$(answer_of G8-1-plugin)" = y ] && [ "$(answer_of L-samples)" = 3 ] &&
    check ok "G8-1's verdicts read the reads: the hold, a second limit, 100 %, battery and the plug-in" ||
    check fail "G8-1's verdicts misread the reads ($(for id in hold second full battery plugin; do printf '%s=%s ' "$id" "$(answer_of "G8-1-$id")"; done))"
  printf '%s\n' "hold$TAB$(clock)${TAB}ac${TAB}80${TAB}80$TAB-${TAB}no${TAB}1210 bytes${TAB}not run" >"$LIMIT_TABLE"
  limit_verdicts >/dev/null 2>&1
  [ "$(answer_of G8-1-hold)" = unsure ] && grep -q '^G8-1-hold' "$BATCH" &&
    check ok "no app line at the hold is unsure, for his batch, never a no" || check fail "no app line at the hold wasn't unsure"
  [ "$(limit_number_of "Charge Limit read: manualChargeLimit, 85 %, from powerd")" = 85 ] && [ -z "$(limit_number_of "Charge Limit: noPolicy")" ] &&
    check ok "the app's line gives its number, and none without one [the line's words unverified until A-2's]" ||
    check fail "the app's line's number is misread"
  SESSION=R
  [ "$(catalog_ru "Nonexistent key for the dry run")" = "Nonexistent key for the dry run" ] && [ "$(catalog_ru Overview)" != Overview ] &&
    check ok "catalog_ru reads a key's Russian from the catalog, and keeps a key without one" || check fail "catalog_ru misreads the catalog"
  # The capture's keys where macOS 27 keeps them (plutil is macOS's: a Mac's dry run reads them).
  feed="$ROOT/Tests/BatteryCoreTests/Fixtures/m5-macos27-charge-limit.plist"
  if command -v plutil >/dev/null 2>&1; then
    [ "$(battery_key "$feed" NominalChargeCapacity data)" = 5986 ] && [ "$(battery_key "$feed" AppleRawMaxCapacity top)" = 5842 ] &&
      [ "$(battery_key "$feed" CycleCountLastQmax data)" = 50 ] && [ "$(battery_key "$feed" CycleCount top)" = 51 ] &&
      check ok "capacity reads an M5 capture's keys, the pack's AppleRawMaxCapacity and CycleCountLastQmax among them" ||
      check fail "capacity misreads $(basename "$feed")"
  else
    echo "skipped: capacity's capture keys (no plutil here; a Mac's dry run reads $(basename "$feed"))"
  fi
  for id in $WIDGET_NAMES; do
    case "$id" in small | medium | large) id="R3-large" ;; *) id="R3-$id" ;; esac
    if question "$id" >/dev/null; then :; else check fail "the widget name behind $id has no step 3 question"; fi
  done
  check ok "every widget name has its step 3 question"
  # Every start line prints one runbook section by section.sh (PLAN.md §6.0 rule 1, T-1 item 4),
  # through the Bash tool, which cuts an output past 30,000 characters (a whole runbook printed at
  # once was too long for 0.6.2's after-publishing check): each section PLAN.md's start lines and
  # start-session.sh name prints alone, its heading first and no other, under 28,500 bytes (an
  # upper bound of its characters).
  starts="$({
    sed -n 's/.*section\.sh) [^ ]* \(SESSION-[LR]\.md\) \([^,]*\), then follow only what it prints.*/\1 \2/p' "$HERE/PLAN.md"
    sed -n 's/.*runbook=\(SESSION-[LR]\.md\) section="\([^"]*\)".*/\1 \2/p' "$HERE/start-session.sh"
  } | sort -u)"
  [ "$(grep -c . <<<"$starts")" -ge 4 ] && check ok "the start lines name $(grep -c . <<<"$starts") runbook sections" ||
    check fail "the start lines name too few runbook sections ($(tr '\n' ';' <<<"$starts"))"
  while read -r runbook section; do
    [ -n "$runbook" ] || continue
    printed="$(bash "$HERE/section.sh" --worktree "$runbook" "$section" 2>&1 </dev/null)" || {
      check fail "section.sh prints no section \"$section\" of $runbook ($(head -1 <<<"$printed"))"
      continue
    }
    bytes="$(printf '%s\n' "$printed" | wc -c | tr -d ' ')"
    [ "$(head -1 <<<"$printed")" = "## $section" ] && [ "$(grep -c '^## ' <<<"$printed")" = 1 ] &&
      [ "$bytes" -gt 300 ] && [ "$bytes" -lt 28500 ] &&
      check ok "the start of \"$section\" prints that section of $runbook alone, $bytes bytes" ||
      check fail "the start of \"$section\" prints $bytes bytes of $runbook, or more than its section: one section, under 28,500"
  done <<<"$starts"
  # The sections a start section sends the session to read, each a heading of its runbook.
  for wanted in "SESSION-L.md|Rules|Privacy|Decisions you make alone|L0:|L1:|L2:|L3:|L4:|L5:|If the session restarts or compacts|Answers" \
    "SESSION-R.md|Rules|Privacy|Decisions you make alone|R0:|R1:|R2:|R3:|If the session restarts or compacts|Answers"; do
    runbook="${wanted%%|*}"
    missing=""
    IFS='|' read -r -a names <<<"${wanted#*|}"
    for name in "${names[@]}"; do grep -q "^## $name" "$HERE/$runbook" || missing="$missing \"$name\""; done
    [ -z "$missing" ] && check ok "$runbook has every section its start sections name" ||
      check fail "$runbook lacks the sections$missing, which its start sections name"
  done
  bash "$HERE/section.sh" --worktree SESSION-R.md "No such section" >/dev/null 2>&1 && status=0 || status=$?
  bash "$HERE/section.sh" --worktree PLAN.md R8 >/dev/null 2>&1 && other=0 || other=$?
  [ "$status" = 1 ] && [ "$other" = 2 ] &&
    check ok "section.sh refuses a heading its runbook lacks (1) and a file that is no runbook (2)" ||
    check fail "section.sh's refusals are wrong (a missing heading $status, not 1; another file $other, not 2)"
  rm -rf "$WORK"
  if [ "$problems" -gt 0 ]; then
    echo "dry run: $problems broken rule(s)" >&2
    return 1
  fi
  echo "dry run: every rule holds"
}

# MARK: - help

step_help() {
  case "$SESSION" in
    L)
      cat <<EOF2
usage: $SCRIPT <command> [arguments]          (the look shoot; SESSION-L.md is the runbook)

The start (he is there):
  prepare attempt [--kept <setting>[,...]] [--restored <setting>[,...] "<how>"]   first: a clean start
  answer --by person L-yes y (and L-usage, L-adapter); prepare (a background task: wait 9 until it ends): the
  backup, the CI build L installed over his $BASE_VERSION, the tools, the app's counts of the placed widgets; a beep
  preflight; main (before the one computer-use access request); ui access; prepare reads
L1, the Charge Limit (G8-1), with him there for the beeps:
  change charge-limit <his> <n>, the slider by computer use, charge-limit set <n>; charge-limit hold (again
  between step 3's screens until HELD); charge-limit read second (a limit above the charge); charge-limit set 100;
  charge-limit set <n> (back to the hold's); charge-limit unplug (a background task: two beeps); the slider back
  to his, charge-limit back; charge-limit verdicts
L2, the screens, in English, then after app-language ru in Russian, then app-language back:
  scene-shots <tag> (a Demo Mode scene chosen by ui press); pages <tag> [<page>...]; screen <name> [main|front|popover];
  window-style clear | back (Q8-4); welcome first, welcome back (A-5); report-check (A-6); sentinel place, sentinel
  check (P-1); help-link (A-7)
L3, the weak adapter (only with L-adapter y): weak-adapter in (a background task); weak-adapter out
L4: restore end, each RESTORE item, widgets-check (the app's counts against prepare's), summary end
L5: batch, send --dry-run, his L-send, send
While a background task runs: wait [<minutes, 1-9>] in the foreground, again until it ended.
Any time: status, note, change, restored, shot, crop, front, attach, unattach, ui, measure, judge, faults, help.
EOF2
      ;;
    H)
      cat <<EOF2
usage: $SCRIPT <command> [arguments]          (the hold watch; SESSION-R.md, "Hold watch")

  answer --by person H-yes y; hold-watch start (the adapter in, the lid open); in the morning: hold-watch morning,
  judge H-hold; then batch, send --dry-run, his H-send, send. Any time: status, note, help.
EOF2
      ;;
    D3)
      cat <<EOF2
usage: $SCRIPT <command> [arguments]          (after publishing; SESSION-R.md, "After publishing")

  tools (ui and frames, first); answer --by person D3-yes y; main (before computer use asks for access); ui access;
  proof P1 --image <png> <x> <y>; widget <name> x y w h; desktop-spot ...; proof P11; after before; Check for
  Updates, Install and Relaunch (ui press); after after (it runs feed check); screen report-problem front; help-link;
  then judge each D3-*; capacity after; after popover; then batch, send --dry-run, his D3-send, send.
  Any time: status, note, shot, crop, front, attach, ui, judge, wait, help.
EOF2
      ;;
    *)
      cat <<EOF2
usage: $SCRIPT <command> [arguments]          (Session R8, hands-free; SESSION-R.md is the runbook)

The start (on the adapter, he is there):
  prepare attempt [--kept <setting>[,...]] [--restored <setting>[,...] "<how>"]   first: a clean start
  answer --by person R-yes y (and R-back, R-keep-ax, R-keep-widgets, R-limit, R-usage)
  prepare [--fresh-backup]   the backup into ~/bp-080/R, the builds (start, U, F), the tools, the app's counts of
                             the placed widgets, his $BASE_VERSION left for step 2; a beep
  prepare reads              the Charge Limit, 24-hour, Open at login, Keyboard navigation, Check for updates,
                             Window to open, the languages, the appearance; the panes' shots; pluginkit
  proof P1 --image <png> <x> <y> | P6 | P7 | P8 | P11 | <P#> pass|fail <note>
  widget <name> <x> <y> <w> <h> | widget <name> none (names: $WIDGET_NAMES)
  desktop-spot <x> <y> | --image <png> <x> <y>
  main                       the main window, before the first computer-use action in BatteryPulse
  preflight                  the checks, P7 P8 P6 P11, the Claude desktop app, pending macOS updates
  arm open; mark away        the arm window, then the GUI phase (no sound from here until his day-end)
The GUI phase (heartbeat <step and expected time> after each step, at least every 10 minutes):
  capacity start; feed before; placed his before | 1 | 5 | compare; install U; whats-new rc [ru]
  0.8's steps: app-tree <surface> [ru]; tree [ru]; keys walk <surface> [<n>] | keys <key> [--on <text>];
  window-style standard|frosted | back; appearance-set light|dark|back; display-shots <tag>;
  menubar [contrast | transparency] (with that option on); app-language ru | back; pages <tag> [<page>...];
  screen <name> [main|front|popover]; charge-limit set|hold|read|back; report-check;
  sentinel place | check [accessories|devices]; help-link; wp18 previews|timing
  step 11c: install start; placed 062 before | 1 | 5 | compare; whats-new 062 [ru]; gallery <name>;
  feed history | cold | demo-start | demo-end | reads-on | reads-off | cleared; edit-shot <tag> [<widget>];
  language ru | back; look <always|auto|nc> <default|dark|clear|tinted> | look contrast | transparency | 12-hour |
  text-size; tick; count-toggle; click-widget quit|running|accessories|health|main|compact|history|device;
  accessories-watch disconnect|reconnect; demo-shots [ru]; front <name>; welcome; raw-history rc; menu-bar-shots
  before | after; pane <$(tr ' ' '|' <<<"$PANES")>; open-app Xcode | TextEdit | "Accessibility Inspector"
  measure <id> blank|same|differs|contrast <arguments>; judge <id> <answer> [--unsure] [note]
  change <setting> <original> <new> (before any change by computer use or AX); restored <setting> <how>
  ui <command...>            the hands (ui.swift's usage), through the script only
  restore gui; summary; ready (last: the arm window starts the logged day)
The day's end (on his "day-end"):
  day-end; plug (his two beeps); capacity day-end; Q8-6's optional listen on RC-U (app-language ru | back);
  f12 rate; install F; f12 before; f12 after; batch; send --dry-run; his R-send; send; restore end; each RESTORE
  item; widgets-check; summary end; send again (his yes stands: R.md gains the widgets' counts after the restore)
While a background task runs: wait [<minutes, 1-9>] in the foreground, again until it ended.
Any time: status, note, shot, crop, attach, unattach, faults, help; dry-run anywhere (CI); capacity <tag> by hand
from the checkout, without a session (P71's W-17 item 18).
EOF2
      ;;
  esac
}

# run_step <step> [arguments]: a step with set -e's exit off inside it, so a failed read or a refused
# ui call is that item's "not checked" and the step goes on; fail still stops it.
run_step() {
  local status=0
  "$@" || status=$?
  if [ "$status" != 0 ]; then
    warn "the step ended with status $status"
    exit "$status"
  fi
}

COMMAND="${1:-}"
if [ $# -gt 0 ]; then shift; fi
if [ "$COMMAND" = dry-run ]; then
  dry_run
  exit $?
fi
# The start's clean start comes before every fence: an earlier attempt's ready would stop it, and
# it moves that aside (step_attempt refuses while that attempt's arm window runs). The look shoot's
# too: an earlier attempt's restored lines would count its changes as back.
if { [ "$SESSION" = R ] || [ "$SESSION" = L ]; } && [ "$COMMAND" = prepare ] && [ "${1:-}" = attempt ]; then
  shift
  run_step step_attempt "$@"
  exit 0
fi
case "$COMMAND" in
  help | -h | --help | "")
    step_help
    exit 0
    ;;
esac
# The maximum-capacity reading by hand (P71's W-17 item 18, when no session runs): it only reads,
# and keeps its capture in ~/bp-capacity.
if [ "$COMMAND" = capacity ] && [ "$SESSION" = none ]; then
  step_capacity "$@"
  exit 0
fi
[ "$SESSION" != none ] ||
  fail "$COMMAND runs from a session's frozen worktree (~/bp-080/R/run, L/run, H/run or D3/run): see SESSION-R.md or SESSION-L.md"
# From Session R's ready until his day-end, nothing acts, whichever session's script runs: the
# reads, day-end and the arm itself are let through.
case "$COMMAND:${1:-}" in
  status:* | day-end:* | arm:) ;;
  *)
    if [ "$SESSION" = R ] || [ "$SESSION" = L ]; then attempt_fence; fi
    r_fence
    mkdir -p "$WORK"
    touch "$HEARTBEAT"
    heartbeat_keeper
    ;;
esac
case "$COMMAND" in
  prepare)
    case "$SESSION:${1:-}" in
      R:reads) run_step step_prepare_reads ;;
      R:*) step_prepare_r "$@" ;;
      L:reads) run_step step_prepare_reads_l ;;
      L:*) step_prepare_l "$@" ;;
      *) fail "prepare is Session R8's or the look shoot's: run it from ~/bp-080/R/run or ~/bp-080/L/run" ;;
    esac
    ;;
  answer) step_answer "$@" ;;
  main) run_step step_main ;;
  note) step_note "$@" ;;
  mark) step_mark "$@" ;;
  shot) step_shot "$@" ;;
  crop) step_crop "$@" ;;
  attach) step_attach "$@" ;;
  unattach) step_unattach "$@" ;;
  install) run_step step_install "$@" ;;
  status) step_status ;;
  send) step_send "$@" ;;
  heartbeat) run_step step_heartbeat "$@" ;;
  wait) run_step step_wait "$@" ;;
  change) run_step step_change "$@" ;;
  restored) run_step step_restored "$@" ;;
  measure) run_step step_measure "$@" ;;
  judge) run_step step_judge "$@" ;;
  batch) run_step step_batch ;;
  ui) run_step step_ui "$@" ;;
  pane) run_step step_pane "$@" ;;
  open-app) run_step step_open_app "$@" ;;
  widget) run_step step_widget "$@" ;;
  desktop-spot) run_step step_desktop_spot "$@" ;;
  proof) run_step step_proof "$@" ;;
  preflight)
    rl_only preflight
    run_step step_preflight "$@"
    ;;
  placed) run_step step_placed "$@" ;;
  whats-new) run_step step_whats_new "$@" ;;
  feed) run_step step_feed "$@" ;;
  capacity) run_step step_capacity "$@" ;;
  faults) run_step step_faults ;;
  front) run_step step_front "$@" ;;
  welcome) run_step step_welcome "$@" ;;
  gallery) run_step step_gallery "$@" ;;
  edit-shot) run_step step_edit_shot "$@" ;;
  language) run_step step_language "$@" ;;
  look) run_step step_look "$@" ;;
  tick) run_step step_tick ;;
  count-toggle) run_step step_count_toggle ;;
  tree) run_step step_tree "$@" ;;
  click-widget) run_step step_click_widget "$@" ;;
  plug) run_step step_plug ;;
  accessories-watch) run_step step_accessories_watch "$@" ;;
  demo-shots) run_step step_demo_shots "$@" ;;
  raw-history) run_step step_raw_history "$@" ;;
  menubar) run_step step_menubar "$@" ;;
  menu-bar-shots) run_step step_menu_bar_shots "$@" ;;
  wp18) run_step step_wp18 "$@" ;;
  tools) run_step step_tools ;;
  arm) run_step step_arm "$@" ;;
  ready) run_step step_ready ;;
  summary) run_step step_summary "$@" ;;
  day-end) run_step step_day_end ;;
  f12) run_step step_f12 "$@" ;;
  restore) run_step step_restore "$@" ;;
  charge-limit) run_step step_charge_limit "$@" ;;
  hold-watch) run_step step_hold_watch "$@" ;;
  after) run_step step_after "$@" ;;
  screen) run_step step_screen "$@" ;;
  pages) run_step step_pages "$@" ;;
  scene-shots) run_step step_scene_shots "$@" ;;
  app-language) run_step step_app_language "$@" ;;
  report-check) run_step step_report_check ;;
  sentinel) run_step step_sentinel "$@" ;;
  help-link) run_step step_help_link ;;
  weak-adapter) run_step step_weak_adapter "$@" ;;
  window-style) run_step step_window_style "$@" ;;
  appearance-set) run_step step_appearance_set "$@" ;;
  app-tree) run_step step_app_tree "$@" ;;
  keys) run_step step_keys "$@" ;;
  display-shots) run_step step_display_shots "$@" ;;
  widgets-check) run_step step_widgets_check ;;
  *)
    step_help >&2
    exit 1
    ;;
esac
