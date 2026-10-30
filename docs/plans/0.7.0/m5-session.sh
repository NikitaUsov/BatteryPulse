#!/bin/bash
# BatteryPulse 0.7.0: the M5 sessions (docs/plans/0.7.0/PLAN.md §6), one command per call.
#
#   bash docs/plans/0.7.0/m5-session.sh help
#
# Session R (hands-free; PLAN.md §6.2; its runbook is SESSION-R.md beside this file): one local
# Claude Code session with computer use runs it from the frozen worktree ~/bp-070/R/run (a script
# run from there is Session R), drives the GUI through `ui` (ui.swift, with safety rules of its own)
# and judges the pictures beside the script's pixel measurements. The arm window keeps the display
# awake for the GUI phase and starts the logged day (§6.3) on `ready`. Everything lands in
# ~/bp-070/R: each change goes into changes.tsv before it is made, and every restore works from that
# file (`restore gui` before the logged day, `restore end` after it); `send` commits R.md to
# docs/plans/0.7.0/sessions/R.md on claude/070-session-r after his yes, through a privacy lint.
#
# The short sessions run the same way from their own frozen worktrees (SESSION-R.md, "The short
# sessions"): ~/bp-070/C/run is the Charge limit capture (`charge-limit`), ~/bp-070/H/run the Hold
# watch (`hold-watch`), ~/bp-070/D3/run the After publishing check (`after`, `count-check`); each
# keeps its files in ~/bp-070/<C|H|D3> and sends <C|H|D3>.md on claude/070-session-<c|h|d3>.
#
# An automated step that can't run records "not checked" or "not run" with its reason, and the
# session goes on. Builds stay in their DMGs and the backup in its zip, so the only
# BatteryPulse.app on the disk is the one in /Applications, and macOS can't pick up another copy's
# widget. Never another results branch, never a pull request.
#
# Every install goes the way UpdateInstaller goes: the widget extension ended first (as 0.6.2's
# installer does, D-17), a copy staged on the same volume, one atomic swap (swap.swift: renamex_np
# with RENAME_SWAP), lsregister -f, a relaunch; the extension's pids before and after, and any
# CHSErrorDomain 1103 line, go into the step's section (G7-2). A build whose CFBundleVersion isn't
# higher than the installed one is refused (WidgetKit caches by it), except the reinstall of his
# backed-up app.
#
# Wording (PLAN.md §3, §6): every y/n question means "y = looks right"; everything else is a
# numbered choice. A step prints its questions as ASK lines and its hands-on tasks as DO lines;
# `judge` and `answer` record the replies. The script reads the logs and counts the crash reports.
#
# It needs macOS 27, Xcode or the Command Line Tools, and the GitHub CLI (https://cli.github.com),
# signed in (the short sessions C and H need neither gh nor a build from CI). No python or perl;
# it runs on macOS's bash 3.2. Millisecond times come from zsh's zsh/datetime module.
set -euo pipefail

# MARK: - Builds and places

REPO="NikitaUsov/BatteryPulse"
INTEGRATION_BRANCH="claude/070-integration"

# Session R's builds (PLAN.md §6.2, D1), each a CI artifact. D1 dispatches ci.yml on the frozen
# code in this order, so each build number is higher than the one installed before it:
#   U   the release candidate as 0.6.99 (RC-U): step 2 installs it over 0.6.2;
#   P   RC-U plus one dummy widget parameter (RC-P, its own commit): step 4.4;
#   U2  RC-U again as 0.6.99, a later run (RC-U2): the rest of the session and the logged day;
#   F   the release candidate as 0.5.99 (RC-F): F12 at the day's end, whose update check offers the
#       real 0.6.2.
# U, U2 and F are found by the frozen commit's code (locate_builds); P has other code, so D1 pins
# it (RUN_P and ARTIFACT_P). A pin overrides the search.
RUN_U=""
ARTIFACT_U=""
RUN_P=""
ARTIFACT_P=""
RUN_U2=""
ARTIFACT_U2=""
RUN_F=""
ARTIFACT_F=""
# The published 0.6.2, the base: his app at the start, and what F12 installs.
TAG_BASE="v0.6.2"
BASE_VERSION="0.6.2"
RC_VERSION="0.6.99"
F_VERSION="0.5.99"

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
  "$ACCOUNT_HOME"/bp-070/R/run/*) SESSION=R ;;
  "$ACCOUNT_HOME"/bp-070/C/run/*) SESSION=C ;;
  "$ACCOUNT_HOME"/bp-070/H/run/*) SESSION=H ;;
  "$ACCOUNT_HOME"/bp-070/D3/run/*) SESSION=D3 ;;
  *) SESSION=none ;;
esac
if [ "$(uname -s)" != Darwin ]; then SESSION="${BP_SESSION:-$SESSION}"; fi
# Session R's folder, whatever this run's own folder is: its fence (ready before day-end) holds for
# every session's script.
R_HOME="$ACCOUNT_HOME/bp-070/R"
# dry-run (CI on Linux) is Session R's bookkeeping in a folder of its own. On the Mac nothing else
# moves the folder: a BP_WORK of the caller's would hold no fence and no change record.
if [ "${1:-}" = dry-run ]; then
  SESSION=R
  BP_WORK="$(mktemp -d "${TMPDIR:-/tmp}/bp-070-dry.XXXXXX")"
elif [ "$(uname -s)" = Darwin ]; then
  BP_WORK=""
fi
case "$SESSION" in
  R | C | H | D3) RESULTS_BRANCH="claude/070-session-$(tr '[:upper:]' '[:lower:]' <<<"$SESSION")" ;;
  none) RESULTS_BRANCH="" ;;
  *)
    echo "error: BP_SESSION is R, C, H or D3" >&2
    exit 1
    ;;
esac
TAB="$(printf '\t')"
# BP_WORK only moves the folder for the dry run and for the bookkeeping commands off the Mac.
WORK="${BP_WORK:-$ACCOUNT_HOME/bp-070/$SESSION}"
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
WIDGET_PREFS="$HOME/Library/Containers/$WIDGET_ID/Data/Library/Preferences/$WIDGET_ID"
REPORTS="$HOME/Library/Logs/DiagnosticReports"
LSREGISTER="/System/Library/Frameworks/CoreServices.framework/Versions/A/Frameworks/LaunchServices.framework/Versions/A/Support/lsregister"
PERF_PREDICATE="subsystem == \"$BUNDLE_ID\" AND category == \"perf\""
WIDGET_PREDICATE="subsystem == \"$BUNDLE_ID\" AND category == \"widget\""
UPDATE_PREDICATE="subsystem == \"$BUNDLE_ID\" AND category == \"update\""
FAULT_PREDICATE="subsystem == \"$BUNDLE_ID\" AND messageType == fault"
# chronod's refusal of a timeline whose descriptor it cached from another build (Session A, D-17).
CHS_PREDICATE='eventMessage CONTAINS "CHSErrorDomain" AND eventMessage CONTAINS "1103"'
# The families a Battery or Accessories widget may be recorded under (`widget`), each with its
# largest frame in points (ui.swift's Rules.widgetLimits).
WIDGET_NAMES="small medium large xlarge accessories-small accessories-medium accessories-large"

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
# judged one has its written criteria and default in SESSION-R.md.
question() {
  local rest
  case "$1" in
    R-yes) echo "yn|person|The list of changes and the start (SESSION-R.md, the start message): y = go ahead" ;;
    R-back) echo "text|person|When he is back at the Mac, HH:MM (default: 4 hours after the start); a daytime session works" ;;
    R-keep-ax) echo "yn|person|Keep Terminal's Accessibility after Session R: y = keep (default: reminded to revoke it at the end of the series)" ;;
    R-keep-widgets) echo "yn|person|Keep the widgets step 3 adds from the gallery: y = keep (default: removed at the end)" ;;
    R-usage | C-usage | H-usage | D3-usage) echo "text|person|What /usage showed at the start" ;;
    R-send | C-send | H-send | D3-send)
      echo "yn|person|Send ${1%-send}.md and the attached images to claude/070-session-$(tr '[:upper:]' '[:lower:]' <<<"${1%-send}"), after the contact sheet and the summary: y = send"
      ;;
    C-yes) echo "yn|person|The Charge limit capture with the adapter in: the recording, the limit at 100 % for at most 10 minutes and back: y = go ahead" ;;
    H-yes) echo "yn|person|The hold watch tonight: the recording under caffeinate -i, the Mac on the adapter with the lid open: y = go ahead" ;;
    D3-yes) echo "yn|person|The after-publishing check: the update to 0.7.0 by Install and Relaunch, the version count's check: y = go ahead" ;;
    prep-charge-limit) echo "text|judge|The Charge Limit (pmset -g battlimit on the adapter, else the Battery pane's shot), in %" ;;
    prep-widget-style) echo "text|judge|System Settings → Appearance → Icon & widget style (computer use from the sidebar, its shot): Default, Dark, Clear or Tinted" ;;
    prep-dim-widgets) echo "text|judge|System Settings → Desktop & Dock → Dim widgets on desktop (its shot): Automatically, Always or Never" ;;
    prep-open-at-login) echo "2|judge|Open at login (BatteryPulse's own toggle, by AX or its Settings shot): 1 on, 2 off" ;;
    prep-widgets) echo "2|judge|A small and a medium BatteryPulse widget on the desktop, uncovered: 1 yes, 2 no (one was added, noted)" ;;
    R2-small | R2-medium)
      echo "4|judge|Step 2, the ${1#R2-} widget placed under 0.6.2, after RC-U's install and the desktop click, against prepare's shot: 1 same, 2 blank or grey, 3 gone, 4 different (note)"
      ;;
    R3-large | R3-xlarge | R3-accessories-small | R3-accessories-medium | R3-accessories-large)
      echo "yn|judge|Step 3, the ${1#R3-} widget added from the gallery, against W-3b's or W-8's PNG: looks right (n names the picture)"
      ;;
    R4-1-shows) echo "yn|judge|Step 4.1: the medium widget shows the choices made (Custom, the first four details, time left if offered, monochrome)" ;;
    R4-2-kept) echo "yn|judge|Step 4.2: Edit Widget again shows the choices made" ;;
    R4-3-sheet) echo "3|judge|Step 4.3, Edit Widget with BatteryPulse in Russian: 1 all Russian, 2 some English (which), 3 the sheet didn't change language (not checked)" ;;
    R4-3-widgets) echo "3|judge|Step 4.3, the placed widgets after the language switch, the reload and a new extension: 1 Russian, 2 still English (which), 3 no redraw (not checked)" ;;
    R4-4-kept) echo "yn|judge|Step 4.4, RC-P over RC-U: Edit Widget on the medium widget still shows the choices of 4.1" ;;
    R4-5-automatic) echo "yn|judge|Step 4.5: the medium widget back on Automatic, as before step 4" ;;
    R5-always-default | R5-always-dark | R5-always-clear | R5-always-tinted | R5-auto-default | R5-auto-dark | R5-auto-clear | R5-auto-tinted | \
      R5-nc-default | R5-nc-dark | R5-nc-clear | R5-nc-tinted | R5-contrast | R5-transparency)
      rest="${1#R5-}"
      echo "yn|judge|Step 5, $rest: every widget can be read, and a low or Service Recommended state still shows without colour (beside each crop's contrast)"
      ;;
    R6-12-hour) echo "yn|judge|Step 6, 24-hour time off: the widget shows '4:39 PM'-style times" ;;
    R6-tick) echo "4|judge|Step 6, a time-left widget 65 s apart: 1 the minutes went down by one, 2 no, 3 it shows seconds, 4 it starts with a minus sign" ;;
    R6-count-toggle) echo "yn|judge|Step 6, the version count's toggle and footer: readable in English and Russian, greyed out under Never" ;;
    R7-tree) echo "yn|judge|Step 7, each widget's tree: no symbol name, the charge one element with its value, one element per row, no empty group (W-3b item 5)" ;;
    R7-tree-ru) echo "yn|judge|Step 7, the same trees in Russian" ;;
    R7-text-size) echo "3|judge|Step 7, Text size at its largest: the widgets' words 1 grow, 2 stay unchanged (expected), 3 get cut off (which)" ;;
    R8-quit | R8-running | R8-accessories | R8-health | R8-main | R8-compact)
      echo "3|judge|Step 8, a click on the widget (${1#R8-}): 1 the expected page opened, 2 another page (which, and its route), 3 nothing opened"
      ;;
    R9-plug) echo "yn|judge|Step 9, the unplug and plug-in: the Battery widget's state matches bpulse --json within a minute (at the limit: Not charging, then Charged to limit)" ;;
    R9-accessory) echo "3|judge|Step 9, the accessory disconnected and reconnected: 1 the Accessories widget changed within a minute, 2 it didn't, 3 not run" ;;
    R9b-demo) echo "yn|judge|Step 9b, Demo Mode's Charge limit scene: Overview, the popover and the compact window say Charged to limit, Power says Charge limit: Reached" ;;
    R9b-demo-ru) echo "yn|judge|Step 9b, the same in Russian, in the catalog's terms" ;;
    R9b-widgets) echo "yn|judge|Step 9b, with bit 24 now: the Battery widgets say Charged to limit" ;;
    R9b-settings-ru) echo "3|judge|Step 9b, System Settings → Battery's Charge Limit with System Settings in Russian: 1 Russian, as the catalog's words, 2 Russian, other words (which), 3 not in Russian (not checked)" ;;
    V01-menubar) echo "yn|judge|The menu bar item on a light and on a dark menu bar (the crops): legible, not clipped" ;;
    R-raw-history-base | R-raw-history-rc)
      echo "3|judge|A pointer-free switch from Raw Data to History (${1##*-}): 1 History at once, 2 History's title over Raw Data's table first (for how long), 3 something else (note)"
      ;;
    F12-version) echo "yn|judge|F12: after Install and Relaunch on RC-F, BatteryPulse came back as 0.6.2" ;;
    F12-widget) echo "4|judge|F12: the widgets after the update against the before shots: 1 same, 2 blank or grey, 3 gone, 4 different (note)" ;;
    C-bit24) echo "3|judge|At the limit on the adapter, when charging stopped: 1 NotChargingReason gained bit 24, 2 it didn't, 3 not reached" ;;
    C-full) echo "yn|judge|The limit at 100 % (computer use or his hand at the beeps), confirmed by pmset -g battlimit or the pane's shot" ;;
    C-back) echo "yn|judge|The limit back at its value, confirmed by pmset -g battlimit or the pane's shot" ;;
    H-hold) echo "3|judge|The night on the adapter: 1 a hold was seen (the charge held below 100 % with NotChargingReason set), 2 none, 3 not readable" ;;
    D3-version) echo "yn|judge|After Install and Relaunch, About shows 0.7.0" ;;
    D3-whats-new) echo "yn|judge|What's New appeared once" ;;
    D3-count-row) echo "yn|judge|What's New lists Anonymous version count" ;;
    D3-widgets) echo "4|judge|The widgets against the before-picture, after the desktop click: 1 same, 2 blank or grey, 3 gone, 4 different" ;;
    D3-history) echo "yn|judge|History shows the past days" ;;
    D3-settings) echo "yn|judge|The settings and the menu bar look are as in the before shots" ;;
    D3-login-item) echo "2|judge|Login Items: 1 BatteryPulse still listed (or Open at login was off), 2 gone" ;;
    D3-notifications) echo "yn|judge|BatteryPulse's Settings → Notifications as before the update" ;;
    D3-count) echo "3|judge|The version count: 1 counted, and release-stats shows 1 or more, 2 noCounter, failed or 0, 3 no update line" ;;
    D3-first-day) echo "yn|judge|The popover's charge and Lasts until against the widget's: within 2 points and about 15 minutes" ;;
    *) return 1 ;;
  esac
}

# The order of the answers in status and the report, per session.
questions_list() {
  case "$SESSION" in
    R)
      echo R-yes R-back R-keep-ax R-keep-widgets R-usage
      echo prep-charge-limit prep-widget-style prep-dim-widgets prep-open-at-login prep-widgets
      echo R-raw-history-base R2-small R2-medium
      echo R3-large R3-xlarge R3-accessories-small R3-accessories-medium R3-accessories-large
      echo R4-1-shows R4-2-kept R4-3-sheet R4-3-widgets R4-4-kept R4-5-automatic
      echo R5-always-default R5-always-dark R5-always-clear R5-always-tinted R5-auto-default R5-auto-dark R5-auto-clear R5-auto-tinted
      echo R5-nc-default R5-nc-dark R5-nc-clear R5-nc-tinted R5-contrast R5-transparency
      echo R6-12-hour R6-tick R6-count-toggle R7-tree R7-tree-ru R7-text-size
      echo R8-quit R8-running R8-accessories R8-health R8-main R8-compact R9-plug R9-accessory
      echo R9b-demo R9b-demo-ru R9b-widgets R9b-settings-ru V01-menubar R-raw-history-rc
      echo F12-version F12-widget R-send
      ;;
    C) echo C-yes C-usage prep-charge-limit C-bit24 C-full C-back C-send ;;
    H) echo H-yes H-usage H-hold H-send ;;
    D3) echo D3-yes D3-usage D3-version D3-whats-new D3-count-row D3-widgets D3-history D3-settings D3-login-item D3-notifications D3-count D3-first-day D3-send ;;
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

# The widget extension's processes, by their executable's path at the start of the argument list
# (so no shell whose command line names it): pgrep -x and pkill -x match macOS's p_comm, cut to 16
# characters, which "BatteryPulseWidget" (18) never equals.
WIDGET_EXEC='^/[^ ]*/BatteryPulseWidget\.appex/Contents/MacOS/BatteryPulseWidget( |$)'
widget_pids() { pgrep -f "$WIDGET_EXEC" 2>/dev/null || true; }

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
  MOUNT="$(mktemp -d "${TMPDIR:-/tmp}/bp-070-mount.XXXXXX")"
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

# locate_builds: U, U2 and F from the integration branch's successful CI runs whose commit is the
# frozen one or an ancestor with the same code (Sources, Resources, Package.swift, build-app.sh):
# the oldest run with a $RC_VERSION DMG is U, the newest later one U2; the newest $F_VERSION DMG is
# F. A pin (RUN_<name>, ARTIFACT_<name>) overrides each.
LOC_U=""
LOC_U2=""
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
  # gh lists the newest first: U is the last line, U2 the first, when there are two.
  LOC_U="$(grep . <<<"$rc_runs" | tail -1 || true)"
  if [ "$(grep -c . <<<"$rc_runs" || true)" -ge 2 ]; then LOC_U2="$(grep . <<<"$rc_runs" | head -1)"; fi
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

fetch_builds_r() {
  mkdir -p "$BUILDS"
  if [ ! -f "$BUILDS/base.dmg" ]; then
    rm -rf "$BUILDS/base.download"
    mkdir -p "$BUILDS/base.download"
    gh release download "$TAG_BASE" -R "$REPO" -p BatteryPulse.dmg -D "$BUILDS/base.download" ||
      fail "can't download the $TAG_BASE DMG"
    mv "$BUILDS/base.download/BatteryPulse.dmg" "$BUILDS/base.dmg"
    rm -rf "$BUILDS/base.download"
    describe_build base "release $TAG_BASE"
  fi
  if [ ! -f "$BUILDS/U.dmg" ] || [ ! -f "$BUILDS/U2.dmg" ] || [ ! -f "$BUILDS/F.dmg" ]; then locate_builds; fi
  fetch_one U "$RUN_U" "$ARTIFACT_U" "$LOC_U"
  [ -f "$BUILDS/U.dmg" ] || fail "no RC-U: D1 dispatches ci.yml with version $RC_VERSION on the frozen code, or pins RUN_U"
  fetch_previews
  fetch_one P "$RUN_P" "$ARTIFACT_P" ""
  fetch_one U2 "$RUN_U2" "$ARTIFACT_U2" "$LOC_U2"
  fetch_one F "$RUN_F" "$ARTIFACT_F" "$LOC_F"
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

# install_build <base|U|P|U2|F|backup> [--no-launch]: the build's app into /Applications the way
# UpdateInstaller does it: the widget extension ended first and waited for (D-17), a copy staged on
# the same volume, its bundle ID and code signature checked, one atomic swap with the installed copy
# (swap.swift), the old copy deleted once it has quit, lsregister -f, a relaunch. WidgetKit caches
# by CFBundleVersion, so a build whose number isn't higher than the installed one is refused, except
# the base 0.6.2 and his backed-up app. The extension's pids before the swap and 10 s after the
# relaunch go into installs.tsv and the step's section (G7-2).
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
    if [ "$name" = base ]; then
      why="the base $BASE_VERSION reinstall"
    elif [ "$name" = backup ]; then
      why="restore puts his app back"
    else
      rm -rf "$staging"
      fail "refusing $name: its build $build isn't higher than the installed $installed, and WidgetKit caches by it (D1 dispatches U, P, U2 and F in this order)"
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

# install <base|U|P|U2|F|backup>: one build, as every step installs it, with its section lines: the
# pids, and CHSErrorDomain 1103 lines since the install (read again by the step's later shots).
step_install() {
  r_only install
  [ $# -eq 1 ] || fail "usage: $SCRIPT install <base|U|P|U2|F|backup>"
  case "$1" in base | U | P | U2 | F | backup) ;; *) fail "no build $1 in Session R" ;; esac
  [ "$1" = backup ] || [ -n "$(original_of app)" ] || fail "prepare records the app's change first: $SCRIPT prepare"
  install_build "$1"
  use_section 05-installs "Installs"
  out "- $(tail -1 "$WORK/installs.tsv" | awk -F '\t' '{ printf "%s: %s %s (%s); extension pids before %s, %s, after %s", $1, $2, $3, $4, $5, $6, $7 }')"
}

# chs_since <time>: the CHSErrorDomain 1103 lines since then (chronod's refusal of a timeline whose
# descriptor it cached from another build; Session A).
chs_since() {
  local count
  count="$(log_since "$1" "$CHS_PREDICATE" "$LOGS/chs.ndjson")"
  echo "CHSErrorDomain 1103 lines since $1: $count"
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
  build_bpulse
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

# A fresh backup into ~/bp-070/R/backup (PLAN.md §6.2 step 1): the app, the defaults domain (his
# settings: Check for updates, Window to open, the app's own AppleLanguages), Application Support,
# the widget extension's AppleLanguages, the appearance, the 24-hour setting. A second prepare keeps
# it unless asked for a fresh one.
backup() {
  if [ -f "$BACKUP/done" ] && [ "${1:-}" != --fresh-backup ]; then
    echo "keeping the backup of $(cat "$BACKUP/done") in $BACKUP (prepare --fresh-backup takes a new one)"
    return 0
  fi
  [ -d "$APP" ] || fail "$APP is missing: his $BASE_VERSION is the session's start"
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
# MARK: - Session R: bookkeeping (PLAN.md §6.2, 0.6.2's hands-free mode)

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

r_only() { [ "$SESSION" = R ] || fail "$1 is a Session R command: run it from the frozen worktree ~/bp-070/R/run"; }

# session_only <session> <command>: a short session's command, from its own frozen worktree.
session_only() { [ "$SESSION" = "$1" ] || fail "$2 is the $1 session's command: run it from ~/bp-070/$1/run"; }

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
LEFTOVERS="gui-stream day-stream record"
leftover_running() {
  local pid what
  pid="$(cat "$WORK/$1.pid" 2>/dev/null || true)"
  case "$1" in *-stream) what="log stream" ;; *) what="--record" ;; esac
  [ -n "$pid" ] && kill -0 "$pid" 2>/dev/null && ps -o args= -p "$pid" 2>/dev/null | grep -q -F -- "$what"
}

# stop_leftovers [<name>...]: ends them (all by default) when their own step didn't (restore end,
# the next prepare).
stop_leftovers() {
  local name
  for name in ${*:-$LEFTOVERS}; do
    if leftover_running "$name"; then
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
# Mode the sidebar's Devices section lists it), else "none".
shot_state() {
  printf '%s\t%s\t%s\n' "$(defaults read "$BUNDLE_ID" windowLook 2>/dev/null || echo standard)" \
    "$(defaults read "$BUNDLE_ID" AppleLanguages 2>/dev/null | tr -d ' \n()"' | cut -c1-20 || true)" \
    "$(if grep -q '"name"' "$SUPPORT/Devices/devices.json" 2>/dev/null; then echo named; else echo none; fi)"
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

# r_fence: once `ready` is up (the logged day), no command acts until his day-end (§6.2: the session
# ends its turn at step 12); a day-end counts only when it is newer than ready. `ui` enforces the
# same for itself, and day_fence for every run of this script.
r_fence() {
  if [ -f "$READY_FILE" ] && ! ended_after "$WORK" ready && ! caller_is_arm; then
    fail "ready is up: the logged day runs, and nothing acts until his day-end; nothing was done"
  fi
  day_fence
}

# The arm window of ~/bp-070/R (arm.pid) is this call's ancestor.
caller_is_r_arm() { arm_is_ancestor "$R_HOME/arm.pid"; }

# day_fence: Session R's fence for every run of this script, wherever it runs from (a short
# session's worktree, his checkout): ~/bp-070/R's ready without a newer day-ended stops every acting
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
# long step, count-check's 10 minutes, the charge-limit's hold), in the foreground under the start
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

# launch_r [arguments...]: the installed app without its saved windows, in English for the GUI
# phase's AX labels (a launch argument only; no setting changes). The language step and the
# logged day launch it without the argument (launch_plain).
launch_r() {
  open "$APP" --args -ApplePersistenceIgnoreState YES -AppleLanguages "(en)" "$@"
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

# widget <name> <x> <y> <w> <h>: a placed widget's frame in points (from proof P1's `ui hit`, or
# `ui frame --widgets`), for the crops, the clicks, ui's window-list rule and `tree --inside`. AX
# can't move widgets, so their frames come from here. The names: small, medium, large and xlarge
# for the Battery kind, accessories-small, -medium and -large. A frame is recorded only when it is
# no larger than its family's widget (one in pixels is twice as large) and `ui hit` finds a widget
# host's element labelled BatteryPulse at its centre.
step_widget() {
  [ $# -eq 5 ] || fail "usage: $SCRIPT widget <$(tr ' ' '|' <<<"$WIDGET_NAMES")> <x> <y> <w> <h>"
  local limit number hit bundle
  # ui.swift's Rules.widgetLimits, in points, with room to spare.
  case "$1" in
    small | accessories-small) limit="220 220" ;;
    medium | accessories-medium) limit="440 220" ;;
    large | accessories-large) limit="440 460" ;;
    xlarge) limit="880 460" ;;
    *) fail "a widget is one of: $WIDGET_NAMES" ;;
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
# corner and above the Dock (§6 "Places"), by AX.
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

# MARK: - Session R: the start (prepare attempt, prepare, prepare reads)

# attempt_head: the frozen worktree's commit, which names this attempt (~/bp-070/R/attempt).
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
# files (no attempt file, or another commit's) moves aside to ~/bp-070/<session>-attempt-<that
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
    dest="$ACCOUNT_HOME/bp-070/$SESSION-attempt-$when"
    while [ -e "$dest" ]; do
      n=$((n + 1))
      dest="$ACCOUNT_HOME/bp-070/$SESSION-attempt-$when-$n"
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


# prepare [--fresh-backup] (the start, a background task): the backup into ~/bp-070/R, the builds
# (base, U, P, U2, F) and the tools (ui, frames, swap, perf-stats, bpulse), his remembered devices
# out of the session's sight, his 0.6.2 running with the session's settings, then a beep. Only after
# his yes to the list of changes (answer --by person R-yes y).
step_prepare_r() {
  check_tools
  [ "$(answer_of R-yes)" = y ] || fail "first his one yes to the list of changes: $SCRIPT answer --by person R-yes y"
  # Once the session has changed his app and data, a fresh backup would keep the session's state
  # (the RC, no remembered devices) as his.
  if [ "${1:-}" = --fresh-backup ] && [ -n "$(original_of app)" ]; then
    fail "the session has changed his app and data already (changes.tsv): a fresh backup now would keep the session's state as his; nothing was done"
  fi
  mkdir -p "$WORK" "$BUILDS" "$BIN" "$SHOTS" "$LOGS" "$SECTIONS"
  touch "$CHANGES" "$HEARTBEAT"
  cd "$ROOT"
  backup "${1:-}"
  if [ ! -f "$WORK/prepare.time" ] || [ "${1:-}" = --fresh-backup ]; then
    clock >"$WORK/prepare.time"
    date +%s >"$WORK/prepare.epoch"
    touch "$WORK/prepare.marker"
  fi
  stop_leftovers
  fetch_builds_r
  build_tools
  begin_section 00-prepare "Prepare (the start)"
  out "- prepared: $(cat "$WORK/prepare.time"); macOS $(sw_vers -productVersion) ($(sw_vers -buildVersion)); the frozen script at $(git -C "$ROOT" rev-parse --short HEAD 2>/dev/null || echo unknown)"
  out "- installed before the session: $(cat "$BACKUP/version")"
  out "- defaults domain: $(plutil -convert xml1 -o - "$BACKUP/defaults.plist" | grep -c '<key>' || true) keys backed up"
  if [ -d "$BACKUP/support" ]; then
    out "- Application Support: $(find "$BACKUP/support" -type f | wc -l | tr -d ' ') files, $(du -sk "$BACKUP/support" | cut -f1) KB backed up"
  fi
  out "- charge: $(battery_percent) %, $(if on_battery; then echo on battery; else echo on the adapter; fi)"
  out "- he is back at: $(epoch_hm "$(back_epoch)") (the GUI phase stops 10 minutes before, at most 4 hours after mark away)"
  out "- tools: ui $(if [ -x "$BIN/ui" ]; then echo built; else echo "not built"; fi), frames $(if [ -x "$BIN/frames" ]; then echo built; else echo "not built"; fi), bpulse $(if [ -x "$BIN/bpulse" ]; then echo built; else echo "not built"; fi)"
  out ""
  out "| Build | Version | CFBundleVersion | Source |"
  out "|---|---|---|---|"
  local name version build origin
  while IFS=$'\t' read -r name version build origin; do
    out "| $name | $version | $build | $origin |"
  done <"$WORK/builds.tsv"
  for name in P U2 F; do
    if [ -f "$BUILDS/$name.none" ]; then out "- $(cat "$BUILDS/$name.none")"; fi
  done
  if [ -z "$(original_of app)" ]; then
    record_change app "$(cat "$BACKUP/version")" "the release candidates"
    record_change bp-settings "his settings (backup)" "the session's settings"
    record_change bp-support "his data (backup)" "the session's data"
    record_change widget-data "his (backup)" "the candidates' widget data"
  fi
  # His remembered iPhones and iPads: outside Demo Mode the sidebar's Devices section lists them by
  # name, so every shot of the main window would show them. They stay in the backup, which restore
  # gui puts back for the logged day, and are gone for the GUI phase.
  if [ -d "$SUPPORT/Devices" ]; then
    [ -d "$BACKUP/support/Devices" ] || fail "his remembered devices aren't in the backup ($BACKUP/support/Devices): nothing was removed"
    [ -n "$(original_of remembered-devices)" ] || record_change remembered-devices "his (backup)" "none during the GUI phase"
    quit_app
    rm -rf "$SUPPORT/Devices"
  fi
  case "$(app_version)" in
    "$BASE_VERSION "*) ;;
    *) install_build base --no-launch ;;
  esac
  relaunch_r
  sound Glass
  echo "BEEP (prepare is done): when he is back and has quit his own apps: $SCRIPT prepare reads"
}

# prepare reads (the start): what PLAN.md §6.2 step 1 reads, as 0.6.2's prepare did: the Charge
# Limit (pmset -g battlimit), the 24-hour setting, Open at login (AX), Check for updates and Window
# to open (his defaults), the languages (BatteryPulse's own, its widget extension's, the system's),
# the appearance; Icon & widget style and Dim widgets on desktop by computer use from System
# Settings' sidebar (0.6.2's P8: their URLs open other panes), answered from its shot. A value it
# can't read is "unknown" and never changed. Then the desktop's shot and pluginkit: the small and
# medium widgets placed under 0.6.2.
step_prepare_reads() {
  begin_section 01-reads "Prepare's reads (the start)"
  local limit corner value screen keys
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
  out "- Check for updates (updateFrequency): $(setting_of updateFrequency)"
  out "- Window to open (prefersCompactWindow): $(setting_of prefersCompactWindow)"
  out "- BatteryPulse's own languages (its AppleLanguages): $(if [ -f "$BACKUP/app-languages" ]; then tr -s ' \n' ' ' <"$BACKUP/app-languages"; else echo "none (the system's)"; fi)"
  out "- the widget extension's languages: $(if [ -f "$BACKUP/widget-languages" ]; then tr -s ' \n' ' ' <"$BACKUP/widget-languages"; else echo "none (the system's)"; fi)"
  out "- the system's first language: $(defaults read -g AppleLanguages 2>/dev/null | tr -d ' \n()"' | cut -d, -f1 || echo unknown)"
  out "- appearance: dark mode $(cat "$BACKUP/dark-mode"), automatic $(cat "$BACKUP/auto-appearance")"
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
    ui_run press BatteryPulse --menu-cmd w >/dev/null 2>&1 || true
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
  ask prep-widgets
  echo "Then the widgets' frames from proof P1 ($SCRIPT proof P1 --image <shot> <x> <y>; $SCRIPT widget <name> x y w h),"
  echo "an empty desktop spot ($SCRIPT desktop-spot --image <shot> <x> <y>), and: $SCRIPT preflight"
}

# MARK: - Session R: proofs and preflight (the start; 0.6.2's proofs, quick where Session B settled them)

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
  echo "RUN $SCRIPT ui idle; $SCRIPT ui guard; $SCRIPT shot preflight-family; $SCRIPT heartbeat preflight;"
  echo "RUN $SCRIPT measure / judge on one shot; $SCRIPT status"
  echo "NEXT: $SCRIPT raw-history base; $SCRIPT install U; $SCRIPT placed 1"
}

# MARK: - Session R: the streams, the widgets' crops and the windows

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
# calls this before its first computer-use action in BatteryPulse.
step_main() {
  app_running || launch_r
  open_main
  place_window
  echo "the main window: $(main_window_line)"
}

# MARK: - Session R: step 2, placed widgets across the update (G7-2)

# placed before | 1 | 5 | compare: before (once the small and medium frames are recorded, on 0.6.2):
# a crop of each after the desktop click; 1 and 5: a minute and five minutes after RC-U's install
# (waits until then), pluginkit, a full shot (local) and the crops, the extension's pids and the
# CHSErrorDomain 1103 lines; compare (the GUI phase): the crops after the desktop click, against
# before's, with R2-small and R2-medium.
step_placed() {
  r_only placed
  local at
  use_section 10-placed "Step 2: placed widgets across the update (G7-2)"
  case "${1:-}" in
    before)
      click_desktop || not_checked R2 "no desktop spot"
      crop_widgets "$SHOTS/placed" before
      out "- before ($(clock)): $(app_version); widget extension pids: $(widget_pids | tr '\n' ' ')"
      ;;
    1 | 5)
      [ -f "$WORK/installed.time" ] && grep -q '^U ' "$WORK/installed" 2>/dev/null ||
        fail "RC-U isn't installed yet: $SCRIPT install U first"
      at="$(date -j -f '%Y-%m-%d %H:%M:%S' "$(cat "$WORK/installed.time")" +%s 2>/dev/null || date +%s)"
      sleep_until $((at + $1 * 60))
      pluginkit -mv -i "$WIDGET_ID" >"$LOGS/pluginkit-$1.txt" 2>&1 || true
      park_pointer
      shot "placed-$1"
      crop_widgets "$SHOTS/placed" "$1min"
      out "- $1 minute(s) after RC-U ($(clock)): $(app_version); widget extension pids: $(widget_pids | tr '\n' ' '); $(chs_since "$(cat "$WORK/installed.time")")"
      out "- pluginkit:"
      out_block "$LOGS/pluginkit-$1.txt"
      ;;
    compare)
      click_desktop || not_checked R2 "no desktop spot"
      crop_widgets "$SHOTS/placed" now
      out "- compared ($(clock)): $(chs_since "$(cat "$WORK/installed.time" 2>/dev/null || cat "$WORK/prepare.time")")"
      echo "Compare each crop with its -before.png beside it (what Session B's F12 answered: 1 same, with fresh values)."
      for at in small medium; do
        [ -z "$(widget_rect "$at")" ] || step_measure "R2-$at" blank "$SHOTS/placed/$at-now.png" >/dev/null || true
      done
      ask R2-small R2-medium
      ;;
    *) fail "usage: $SCRIPT placed before | 1 | 5 | compare" ;;
  esac
}

# MARK: - Session R: step 3, the gallery

# gallery <name>: after computer use added that widget from the gallery (click-to-add, then one
# slow `ui drag`) and its frame is recorded (`widget <name> ...`): its crop after the desktop
# click, against W-3b's and W-8's PNGs (previews/, from RC-U's run).
step_gallery() {
  r_only gallery
  local name="${1:-}"
  case " $WIDGET_NAMES " in *" $name "*) ;; *) fail "usage: $SCRIPT gallery <$(tr ' ' '|' <<<"$WIDGET_NAMES")>" ;; esac
  [ -n "$(widget_rect "$name")" ] || fail "no frame recorded for $name: $SCRIPT widget $name <x> <y> <w> <h> first (ui frame --widgets lists them)"
  click_desktop || not_checked "R3-$name" "no desktop spot"
  crop_widgets "$SHOTS/gallery" added | grep -F "/$name-" || true
  use_section 15-gallery "Step 3: the gallery"
  out "- $name added and cropped ($(clock))"
  echo "The CI renders to compare with: $(find "$WORK/previews" -name '*.png' 2>/dev/null | sort | tr '\n' ' ')"
  ask "R3-$name"
}

# MARK: - Session R: step 4, the edit sheet and the language

# edit-shot <tag>: the medium widget after the desktop click, one crop per state of step 4 (the
# choices made, back to Automatic), and a full shot kept on the Mac.
step_edit_shot() {
  r_only edit-shot
  [ $# -eq 1 ] || fail "usage: $SCRIPT edit-shot <tag>"
  case "$1" in *[!A-Za-z0-9._-]*) fail "a tag is letters, digits, dots, dashes and underscores" ;; esac
  click_desktop || not_checked "edit-$1" "no desktop spot"
  crop_widgets "$SHOTS/edit" "$1" | grep -F '/medium-' || true
}

# language ru [--extension] | back: step 4.3 the way a user does it (PLAN.md W-0 item 8): the
# session sets BatteryPulse's language in System Settings → General → Language & Region →
# Applications by computer use first (`change app-language <his> ru`), then this relaunches
# BatteryPulse in the language his settings give it, waits up to 90 s for a widget reload notice
# (a widget.reload line) and a new widget extension process, and only then crops every widget.
# No reload in time is "not checked: no redraw", never "n". --extension also sets the extension's
# own AppleLanguages (D-8's method, Session A), for the tree in step 7. back: the same after the
# session put his language back.
step_language() {
  r_only language
  local lang="${1:-}" before since waited=0 reload="" fresh="" pid
  case "$lang" in ru | back) ;; *) fail "usage: $SCRIPT language ru [--extension] | back" ;; esac
  use_section 20-language "Step 4.3: the language, the way a user sets it"
  if [ "${2:-}" = --extension ]; then
    [ -n "$(original_of widget-languages)" ] ||
      record_change widget-languages "$(if [ -f "$BACKUP/widget-languages" ]; then echo "his own"; else echo none; fi)" "(ru)"
    defaults write "$WIDGET_PREFS" AppleLanguages -array ru
    out "- the extension's own AppleLanguages set to (ru) too (D-8's method)"
  fi
  if [ "$lang" = back ] && [ -n "$(original_of widget-languages)" ] && ! is_restored widget-languages; then
    if put_widget_languages_back; then mark_restored widget-languages "script, read back"; fi
  fi
  out "- BatteryPulse's AppleLanguages now: $(defaults read "$BUNDLE_ID" AppleLanguages 2>/dev/null | tr -d ' \n' || echo none)"
  before=" $(widget_pids | tr '\n' ' ') "
  since="$(clock)"
  quit_app
  launch_plain
  while [ "$waited" -lt 90 ]; do
    sleep 5
    waited=$((waited + 5))
    log_since "$since" "$PERF_PREDICATE AND eventMessage BEGINSWITH \"perf event widget.reload\"" "$LOGS/language-reload.ndjson" >/dev/null
    reload="$(messages "$LOGS/language-reload.ndjson" | head -1 || true)"
    fresh=""
    for pid in $(widget_pids); do
      case "$before" in *" $pid "*) ;; *) fresh="$pid" ;; esac
    done
    if [ -n "$reload" ] && [ -n "$fresh" ]; then break; fi
  done
  out "- $lang ($since): after ${waited} s, the reload notice: ${reload:-none}; a new extension process: ${fresh:-none}"
  if [ -z "$reload" ] || [ -z "$fresh" ]; then
    not_checked "R4-3-widgets-$lang" "no redraw: no widget reload notice or no new extension process within 90 s of the relaunch"
    return 0
  fi
  sleep 5
  click_desktop || true
  crop_widgets "$SHOTS/language" "$lang"
  if [ "$lang" = ru ]; then ask R4-3-widgets; fi
}

# MARK: - Session R: step 5, rendering modes and places (G7-4)

# look <always|auto> <default|dark|clear|tinted> | look nc <style> | look contrast | transparency |
# 12-hour | text-size: after the session set the style (and Dim widgets on desktop) by computer use,
# each recorded first with `change`: the desktop clicked, then BatteryPulse's main window (a click
# on its title bar, CGEvent), the desktop shot twice (local) with every widget's crop and contrast.
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
  use_section 30-look "Step 5: rendering modes and places (G7-4), and steps 6 and 7's looks"
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
    ui_run press BatteryPulse --menu-cmd w >/dev/null 2>&1 || true
  fi
  # shellcheck disable=SC2086
  low="$(lowest_contrast $files)"
  out "- $id ($(clock)): $(echo $files | wc -w | tr -d ' ') crops; the lowest contrast ${low:-unread}"
  if [ -n "$low" ] && [ "$id" != R7-text-size ]; then step_measure "$id" contrast "${low%% *}" >/dev/null; fi
  ask "$id"
}

# MARK: - Session R: step 6, time and the version count's toggle

# tick: two crops of the medium widget 65 s apart (a time-left widget counts down by itself).
step_tick() {
  r_only tick
  click_desktop || not_checked R6-tick "no desktop spot"
  crop_widgets "$SHOTS/tick" first | grep -F '/medium-' || true
  sleep 65
  crop_widgets "$SHOTS/tick" second | grep -F '/medium-' || true
  use_section 35-time "Step 6: time and the version count"
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
  use_section 35-time "Step 6: time and the version count"
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
      ui_run press BatteryPulse --menu-cmd w >/dev/null 2>&1 || true
    done
  done
  relaunch_r
  out "- the version count's toggle: Check for updates $value, then never, in English and Russian ($(clock))"
  echo "LOOK $SHOTS/count/settings-en-on.png, settings-en-never.png, settings-ru-on.png, settings-ru-never.png"
  ask R6-count-toggle
}

# MARK: - Session R: step 7, the trees VoiceOver walks (G7-12)

# tree [ru]: `ui tree` of every recorded widget, inside its frame in its host (P1's), roles and
# labels; the Accessories widgets' labels (accessory names) stay on the Mac, the report gets their
# roles. ru: after `language ru --extension`.
step_tree() {
  r_only tree
  local suffix="${1:-en}" name host file
  case "$suffix" in en | ru) ;; *) fail "usage: $SCRIPT tree [ru]" ;; esac
  host="$(head -1 "$WORK/ui-hosts" 2>/dev/null || true)"
  [ -n "$host" ] || fail "no widget host recorded: proof P1 first"
  use_section 40-tree "Step 7: the trees VoiceOver walks (G7-12)"
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
      accessories-*) sed 's/"[^"]*"/"(a label, kept on the Mac)"/g' "$file" >"$file.public" ;;
      *) cp "$file" "$file.public" ;;
    esac
    out_block "$file.public"
  done
  if [ "$suffix" = ru ]; then ask R7-tree-ru; else ask R7-tree; fi
}

# MARK: - Session R: step 8, clicks (G7-9)

# click-widget <quit|running|accessories|health|main|compact>: the app put in that state, then a
# CGEvent click at the widget's recorded frame (the Battery widget, the Accessories widget for
# accessories, the medium one for health, which computer use set to maximum capacity first);
# BatteryPulse's log lines since the click (its route, `url` or `activity`, and the page) and the
# window that opened. compact sets Window to open to compact through defaults while the app is
# quit, and the session's setting again after.
step_click_widget() {
  r_only click-widget
  local case_="${1:-}" name=small host since rect
  case "$case_" in
    quit | running | main | compact) ;;
    accessories) name="$(widget_names | grep '^accessories-' | head -1 || true)" ;;
    health) name=medium ;;
    *) fail "usage: $SCRIPT click-widget quit | running | accessories | health | main | compact" ;;
  esac
  rect="$(widget_rect "${name:-none}")"
  [ -n "$rect" ] || fail "no frame recorded for ${name:-an Accessories widget}"
  host="$(head -1 "$WORK/ui-hosts" 2>/dev/null || true)"
  [ -n "$host" ] || fail "no widget host recorded: proof P1 first"
  case "$case_" in
    quit) quit_app ;;
    running | accessories | health) relaunch_r ;;
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
  use_section 45-clicks "Step 8: clicks (G7-9)"
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

# MARK: - Session R: step 9, plug, unplug and accessories; 9b, the Charge Limit

# plug: at the start, with him: a beep for the unplug, a crop of the Battery widgets and
# `bpulse --json` every 10 s; 70 s later a second beep for the plug-in, then every 10 s for 3
# minutes. Records when bit 24 appears (W-14 item 6).
step_plug() {
  r_only plug
  local i json first24=""
  use_section 50-plug "Step 9: the unplug and the plug-in"
  [ -x "$BIN/bpulse" ] || not_checked R9-plug "bpulse isn't built: the widget's crops only"
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
  echo "LOOK the crops in $SHOTS/plug (small-<n>, medium-<n>) beside the rows above"
  ask R9-plug
}

# accessories-watch <disconnect|reconnect>: after the session's AX press in System Settings →
# Bluetooth (recorded with `change bluetooth-accessory connected disconnected` first): the
# Accessories widgets' crops and pmset's accessory count every 10 s for a minute.
step_accessories_watch() {
  r_only accessories-watch
  local what="${1:-}" i count
  case "$what" in disconnect | reconnect) ;; *) fail "usage: $SCRIPT accessories-watch disconnect | reconnect" ;; esac
  use_section 52-accessories "Step 9: an accessory disconnected and reconnected"
  for i in 0 1 2 3 4 5 6; do
    count="$(pmset -g accps 2>/dev/null | grep -v -i 'InternalBattery' | grep -c -E '[0-9]+%' || true)"
    out "- $what +$((i * 10)) s: pmset -g accps lists $count accessory sources"
    crop_widgets "$SHOTS/accessories" "$what-$i" | grep -F '/accessories-' || true
    [ "$i" = 6 ] || sleep 10
  done
  if [ "$what" = reconnect ]; then ask R9-accessory; fi
}

# demo-shots [ru]: step 9b, with Demo Mode's Charge limit scene chosen by AX (the session's ui
# press): Overview, Power, the menu bar popover and the compact window, in English or Russian; and
# the Battery widgets when bpulse --json shows bit 24 now.
step_demo_shots() {
  r_only demo-shots
  local lang="${1:-en}" item json
  case "$lang" in en | ru) ;; *) fail "usage: $SCRIPT demo-shots [ru]" ;; esac
  if [ "$lang" = ru ]; then
    quit_app
    open "$APP" --args -ApplePersistenceIgnoreState YES -AppleLanguages "(ru)"
    wait_for_app
    echo "DO (session): Demo Mode's Charge limit scene again if the relaunch left it (ui press), then this runs on"
  fi
  open_main
  place_window
  for item in Overview Power; do
    select_page "$item" || not_checked "R9b-$lang" "$item wasn't selected"
    sleep 2
    window_shot "$SHOTS/demo/$(tr '[:upper:]' '[:lower:]' <<<"$item")-$lang.png" || not_checked "R9b-$lang" "no shot of $item"
  done
  if [ -s "$WORK/status-item" ]; then
    # shellcheck disable=SC2046
    ui_run click $(awk '{ printf "%d %d", $1 + $3 / 2, $2 + $4 / 2 }' "$WORK/status-item") --expect BatteryPulse >/dev/null 2>&1 || true
    sleep 2
    front_shot "$SHOTS/demo/popover-$lang.png" || not_checked "R9b-$lang" "no shot of the popover"
    # shellcheck disable=SC2046
    ui_run click $(awk '{ printf "%d %d", $1 + $3 / 2, $2 + $4 / 2 }' "$WORK/status-item") --expect BatteryPulse >/dev/null 2>&1 || true
  else
    not_checked "R9b-popover-$lang" "no menu bar item frame (P11)"
  fi
  park_pointer
  use_section 55-limit "Step 9b: the Charge Limit (W-14, G7-18)"
  out "- Demo Mode's Charge limit scene, $lang ($(clock)): Overview, Power, the popover"
  echo "DO (session): the compact window by computer use or ui (Window to open), shot with $SCRIPT ui frame BatteryPulse and rect, else note it"
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

# MARK: - Session R: the extras (C-1's items in the GUI phase)

# raw-history <base|rc>: Session B's finding (1): a pointer-free switch from Raw Data to History by
# AX selection, the main window shot 0.3 s, 2 s and 8 s after it: does History show its title over
# Raw Data's table first? base runs on 0.6.2 at the start, rc in the GUI phase.
step_raw_history() {
  r_only raw-history
  local tag="${1:-}"
  case "$tag" in base | rc) ;; *) fail "usage: $SCRIPT raw-history base | rc" ;; esac
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

# menubar: the menu bar item on a light and a dark bar (V01-menubar's dark half, C-1):
# scripts/menu-bar-shots.sh's light and dark looks (it sets the appearance and a plain wallpaper and
# puts both back itself), then each main-display shot cropped to the item's AX frame (P11) with 4
# points around it.
step_menubar() {
  r_only menubar
  local screen width scale file rect x y w h
  [ -s "$WORK/status-item" ] || fail "no menu bar item frame (proof P11): V01-menubar is not checked"
  mkdir -p "$SHOTS/menubar"
  bash "$ROOT/scripts/menu-bar-shots.sh" "$SHOTS/menubar" v01 --looks light,dark >"$LOGS/menubar.txt" 2>&1 ||
    not_checked V01-menubar "menu-bar-shots.sh: $(tail -1 "$LOGS/menubar.txt")"
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
  for file in "$SHOTS"/menubar/v01-*-d1.png; do
    [ -f "$file" ] || continue
    "$BIN/frames" crop "$file" "$x" "$y" "$w" "$h" "${file%.png}-item.png" >/dev/null 2>&1 &&
      register_shot "${file%.png}-item.png" && echo "LOOK ${file%.png}-item.png"
  done
  use_section 65-menubar "The menu bar item on a light and a dark bar (V01-menubar)"
  out "- $(find "$SHOTS/menubar" -name 'v01-*-item.png' | grep -c . || true) crops at the item's AX frame ($rect), from menu-bar-shots.sh's light and dark looks"
  ask V01-menubar
}

# menu-bar-shots <tag> [arguments]: scripts/menu-bar-shots.sh into shots/menubar (W-11's pixel
# check, before and after).
step_menu_bar_shots() {
  r_only menu-bar-shots
  [ $# -ge 1 ] || fail "usage: $SCRIPT menu-bar-shots <tag> [--charge] [--looks <list>]"
  mkdir -p "$SHOTS/menubar"
  bash "$ROOT/scripts/menu-bar-shots.sh" "$SHOTS/menubar" "$@"
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

# MARK: - Session R: the arm window, ready and the logged day (steps 12; §6.3)

ARM_PID=""
ARM_START=""
ARM_GUI_CAFFEINATE=""
ARM_READY_WAITER=""
ARM_SHOWN=""

# arm open: writes ~/bp-070/R/arm.command and opens it in a new Terminal window (open -a Terminal:
# no Automation needed). The window runs the frozen worktree's script.
arm_open() {
  r_fence
  mkdir -p "$WORK"
  cat >"$WORK/arm.command" <<EOF
#!/bin/bash
# BatteryPulse Session R's arm window (docs/plans/0.7.0/PLAN.md §6.2, step 12), opened by the session.
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
  begin_section 70-day "The logged day (§6.3; G7-11, G7-16)"
  out "- from $(cut -f1 "$WORK/day.started" 2>/dev/null || echo "-") to $(cat "$DAY_END") (day-end); the display assertion released at $(awk -F '\t' 'index($2, "display assertion is released") { t = $1 } END { print t }' "$LOGS/arm.log" 2>/dev/null || echo "-")"
  if [ -s "$DAY_STREAM" ] && [ -x "$BIN/perf-stats" ]; then
    summary="$(perf_stats "$DAY_STREAM" 2>&1 || true)"
    printf '%s\n' "$summary" >"$LOGS/day-perf-stats.txt"
    out "- perf-stats over the day's stream (per kind: requested, delivered, the share, the median delay; G7-11 wants 90 % per kind, a delay isn't a refusal):"
    out_block "$LOGS/day-perf-stats.txt"
  else
    not_checked G7-11 "no day stream, or perf-stats isn't built"
  fi
  out "- crash reports since prepare (BatteryPulse and BatteryPulseWidget; must be 0):"
  crash_summary "$WORK/prepare.marker"
  faults="$(log_since "$(cat "$WORK/prepare.time")" "$FAULT_PREDICATE" "$LOGS/faults.ndjson")"
  out "- fault messages in the subsystem since prepare: $faults (must be 0)"
  if [ "${faults:-0}" -gt 0 ]; then
    messages "$LOGS/faults.ndjson" | head -10 | public >"$LOGS/faults.txt"
    out_block "$LOGS/faults.txt"
  fi
  log_since "$(cut -f1 "$WORK/day.started" 2>/dev/null || cat "$WORK/prepare.time")" "$UPDATE_PREDICATE" "$LOGS/day-update.ndjson" >/dev/null
  messages "$LOGS/day-update.ndjson" | grep -i -E 'count|check' | head -8 >"$LOGS/day-update.txt" || true
  out "- W-13's update lines during the day (an automatic check due on $RC_VERSION gives one noCounter):"
  out_block "$LOGS/day-update.txt"
  asserts="$(pmset -g assertions 2>/dev/null | grep -c BatteryPulse || true)"
  out "- pmset -g assertions naming BatteryPulse now: $asserts (must be 0); other processes' keep-awake holders: $(keepawake_holders | grep -c . || true)"
  echo "NEXT: F12 ($SCRIPT f12 rate, install F, f12 before, Check for Updates and Install and Relaunch by ui press, f12 after), then batch, send --dry-run, his yes, send, restore end"
}

# MARK: - Session R: F12 at the day's end (D-12, G7-15)

# f12 rate | before | after: RC-F (0.5.99) installed first (`install F`); Check for Updates, then
# Install and Relaunch by AX presses, between before and after. after reads the version (0.6.2?),
# the update log's pre-swap extension end (0.6.2's installer, D-17), the eject failures and the
# CHSErrorDomain 1103 lines, and the widgets after the desktop click.
step_f12() {
  r_only f12
  use_section 75-f12 "F12: Install and Relaunch on RC-F's installer (G7-15)"
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
      if [ -n "$(widget_pids)" ]; then echo yes >"$WORK/f12-extension"; else echo no >"$WORK/f12-extension"; fi
      out "- before Install ($(cat "$WORK/f12.time")): $(app_version); the widget extension running: $(cat "$WORK/f12-extension")"
      echo "DO (session): Check for Updates, then Install and Relaunch, by AX presses (ui press BatteryPulse ...); then: $SCRIPT f12 after"
      ;;
    after)
      local waited=0 lines swap failures version
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
      click_desktop || true
      crop_widgets "$SHOTS/f12" after
      if [ "$version" = "$BASE_VERSION" ]; then
        step_answer --by claude F12-version y "read from the installed Info.plist: $version" >/dev/null
      else
        step_answer --by claude F12-version n "read from the installed Info.plist: $version" >/dev/null
      fi
      echo "F12-version: $(answer_of F12-version) (the installed version is $version)"
      echo "LOOK $SHOTS/f12/*-before.png against *-after.png"
      ask F12-widget
      ;;
    *) fail "usage: $SCRIPT f12 rate | before | after" ;;
  esac
}

# MARK: - Session R: restore gui and restore end

# When each changed setting comes back: "gui" before the logged day (restore gui: the day runs on
# the RC with his settings, his remembered devices and the system as he left it), "end" after it
# (restore end: his 0.6.2 again, his data, the widgets the session added).
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
    app | bp-settings | bp-support | widget-data | remembered-devices | widget-languages) echo script ;;
    app-language) echo "computer use (System Settings → General → Language & Region → Applications), else the script's import of his settings" ;;
    widget-style) echo "computer use (System Settings → Appearance → Icon & widget style)" ;;
    dim-widgets) echo "computer use (System Settings → Desktop & Dock → Dim widgets on desktop)" ;;
    text-size | increase-contrast | reduce-transparency) echo "computer use (System Settings → Accessibility → Display)" ;;
    24-hour) echo "computer use (System Settings → General → Date & Time), confirmed by AppleICUForce24HourTime" ;;
    open-at-login) echo "AX (BatteryPulse's Settings → General → Open at login)" ;;
    bluetooth-accessory) echo "AX or computer use (System Settings → Bluetooth: connect it again)" ;;
    widget-choices) echo "computer use (Edit Widget: back to Automatic)" ;;
    charge-limit) echo "computer use (System Settings → Battery), confirmed by pmset -g battlimit" ;;
    desktop-widgets) echo "computer use (the widgets he didn't keep removed)" ;;
    *) echo "computer use, confirmed by a read or a shot" ;;
  esac
}

# restore_gui_scriptable: the scriptable half of restore gui (the session's, and the arm's stale
# path): the GUI phase's stream stopped and summarized, his settings and his remembered devices back
# into the RC (defaults import; the RC keeps running for the logged day), the extension's languages
# as prepare found them, the apps the script opened closed, BatteryPulse relaunched in his language.
restore_gui_scriptable() {
  local app
  stream_stop gui-stream
  if [ -s "$GUI_STREAM" ]; then
    use_section 58-gui-stream "Steps 2-9: the widget's reloads and timelines (W-4 item 3)"
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
  fi
  if [ -n "$(original_of remembered-devices)" ] && [ -d "$BACKUP/support/Devices" ]; then
    rm -rf "$SUPPORT/Devices"
    ditto "$BACKUP/support/Devices" "$SUPPORT/Devices" && mark_restored remembered-devices "script (from the backup), read back"
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
    echo "RESTORE $setting back to $(original_of "$setting"), by $(restore_how "$setting"); then: $SCRIPT restored $setting <how it was confirmed>"
  done
}

# restore_all: his app, the defaults domain, Application Support, the widget extension's
# languages and the appearance as the backup holds them (restore end).
restore_all() {
  [ -f "$BACKUP/done" ] || fail "no backup in $BACKUP"
  install_build backup --no-launch
  quit_app
  defaults delete "$BUNDLE_ID" 2>/dev/null || true
  defaults import "$BUNDLE_ID" "$BACKUP/defaults.plist"
  rm -rf "$SUPPORT"
  if [ -d "$BACKUP/support" ]; then ditto "$BACKUP/support" "$SUPPORT"; fi
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
  r_only summary
  local setting phase="${1:-gui}" line
  for setting in $(changed_settings); do
    [ "$phase" = end ] || [ "$(restore_phase "$setting")" = gui ] || continue
    if ! is_restored "$setting"; then echo "ALERT $setting: not confirmed back (it was $(original_of "$setting"))"; fi
  done
  for setting in $(changed_settings); do
    [ "$phase" = end ] || [ "$(restore_phase "$setting")" = gui ] || continue
    line="$(awk -F '\t' -v s="$setting" '$1 == s { l = $3 } END { print l }' "$RESTORED" 2>/dev/null || true)"
    echo "CHANGED $setting: $(original_of "$setting") -> $(awk -F '\t' -v s="$setting" '$1 == s { v = $3 } END { print v }' "$CHANGES"); back: ${line:-not yet}"
  done
  if [ "$phase" = gui ]; then
    echo "LEFT FOR LATER (restore end): the release candidate stays installed for the logged day; his 0.6.2, its data and the session's widgets come back at the day's end"
  fi
  echo "REMIND: turn the Focus off before using the Mac"
}

# restore gui | end
step_restore() {
  r_only restore
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
      local limit now
      stop_leftovers
      restore_all
      begin_section 95-restore "Restore end"
      mark_restored app "script"
      mark_restored bp-settings "script"
      mark_restored bp-support "script"
      mark_restored widget-data "script"
      if [ -n "$(original_of remembered-devices)" ] && [ -d "$SUPPORT/Devices" ]; then
        mark_restored remembered-devices "script (from the backup), read back"
      fi
      out "- restored $(clock): $(app_version), the settings domain, Application Support, the widget's languages, the appearance"
      limit="$(answer_of prep-charge-limit)"
      now="$(battlimit_value)"
      out "- the Charge Limit: prepare found ${limit:-unknown}; pmset -g battlimit now: ${now:-none (on battery it holds none: a Battery pane shot confirms it)}"
      if [ -n "$(original_of charge-limit)" ] && [ -n "$now" ] && [ "$now" = "$limit" ]; then mark_restored charge-limit "pmset -g battlimit"; fi
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

# The Appendix C facts each session's report answers (PLAN.md §6.2-§6.4), with where.
appendix_rows() {
  case "$SESSION" in
    R)
      cat <<'EOF'
| Fact (PLAN.md Appendix C) | Where in this file |
|---|---|
| G7-2: placed widgets across RC-U's install, the extension's pids, CHSErrorDomain 1103 | Step 2; Installs; R2-* |
| The gallery's new sizes against the CI renders | Step 3; R3-* |
| G7-13 and the added parameter (RC-P over RC-U, RD C14 item 5) | Step 4.3; R4-* |
| G7-4: rendering modes and places, with each crop's contrast | Step 5; R5-* |
| G7-3, W-13's toggle | Step 6; R6-* |
| G7-12: the trees, Text size | Step 7; R7-* |
| G7-9: the clicks and their routes | Step 8; R8-* |
| W-14's states (bit 7, then bit 24), the accessory's disconnect, Demo Mode's Charge limit | Step 9, 9b; R9-*, R9b-* |
| W-4 item 3: currentConfigurations()'s per-kind answers against the widgets placed | Steps 2-9: the widget's reloads |
| G7-11: per kind, requested, delivered, the share and the median delay; the widget's reads | The logged day |
| G7-16: crash reports and fault messages since prepare | The logged day |
| G7-15: F12 | F12; F12-* |
| Session B's findings: History over Raw Data's table; the menu bar item on a dark bar | Raw Data to History; The menu bar item |
| The hands-free mode's cost and the preflight's proofs | Timeline; Proofs; Not checked or not run; Notes |
EOF
      ;;
    C) printf '%s\n' "| Fact | Where |" "|---|---|" "| QUA-05 / FEA-35: the Charge Limit's bit at the hold, the 100 % diff, the rows around each change | The Charge limit capture; C-* |" ;;
    H) printf '%s\n' "| Fact | Where |" "|---|---|" "| QUA-06: an optimized-charging hold seen overnight under caffeinate -i | The hold watch; H-hold |" ;;
    D3) printf '%s\n' "| Fact | Where |" "|---|---|" "| §6.4: the update to 0.7.0, the widgets, P2 D3's list, the version count (W-13), the first day's comparison | After publishing; D3-* |" ;;
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
  echo "# Session $SESSION results (BatteryPulse 0.7.0)"
  echo
  echo "Written by \`docs/plans/0.7.0/m5-session.sh send\` on $(date '+%Y-%m-%d %H:%M %z'). The session ran hands-free"
  echo "(PLAN.md §6.2): answers marked \"claude\" were judged by the Claude session from the pictures, beside the"
  echo "script's pixel measurement where one exists; \"person\" ones came from the maintainer. Full-desktop shots,"
  echo "recordings and logs stay on the Mac (\`~/bp-070/$SESSION\`)."
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
# iPad's name from BatteryPulse's device store (now and in the backup), a VPN's name, the
# network's name, and every keep-awake holder's process name.
privacy_terms() {
  {
    scutil --get ComputerName 2>/dev/null || true
    scutil --get LocalHostName 2>/dev/null || true
    id -F 2>/dev/null || true
    pmset -g accps 2>/dev/null | sed -n 's/^ *-\(.*\) (id=.*/\1/p' | grep -v -i InternalBattery || true
    bluetooth_names
    cat "$SUPPORT/Devices/devices.json" "$BACKUP/support/Devices/devices.json" "$WORK/devices-forgotten.json" 2>/dev/null |
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

# privacy_lint <file>: refuses the file if a line names any of them.
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
    fail "$SESSION.md names the Mac, him, an accessory, a VPN or the network on line(s)$found: drop them (note, answer or section), then send again"
  fi
}

# send [--dry-run]: <session>.md (and the attached images) committed to docs/plans/0.7.0/sessions/
# on claude/070-session-<session>, which starts from that branch if it exists, else the
# integration branch, else main (after 0.7's D3 removed both); a fresh shallow clone in the
# session's folder, so his own checkout stays as it is. Never another branch, never a pull request.
# His yes first (<session>-send y, after the contact sheet and the summary), then the privacy lint.
step_send() {
  local dry_run="" clone="$WORK/send" base name email total report="$WORK/$SESSION.md" candidate
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
  if has_cyrillic "$(cat "$report")"; then
    fail "$SESSION.md contains Russian text; translate the answer or note it comes from, then send again"
  fi
  total=0
  if [ -s "$PUBLISH/captions.tsv" ]; then total="$(du -sk "$PUBLISH" | cut -f1)"; fi
  [ "$total" -le 6144 ] || fail "the attached images take $total KB; unattach some (at most 6 MB)"
  echo "wrote $report ($(wc -l <"$report" | tr -d ' ') lines, images $total KB)"
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
  mkdir -p "$clone/docs/plans/0.7.0/sessions"
  rm -rf "$clone/docs/plans/0.7.0/sessions/$SESSION"
  cp "$report" "$clone/docs/plans/0.7.0/sessions/$SESSION.md"
  if [ -s "$PUBLISH/captions.tsv" ]; then
    mkdir -p "$clone/docs/plans/0.7.0/sessions/$SESSION"
    cut -f1 "$PUBLISH/captions.tsv" | while IFS= read -r file; do
      cp "$PUBLISH/$file" "$clone/docs/plans/0.7.0/sessions/$SESSION/"
    done
  fi
  git -C "$clone" add -A docs/plans/0.7.0/sessions
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

The answers, counts, perf-stats summaries, public log excerpts and the
attached crops of Session $SESSION (PLAN.md §6.2), for the packages and
gates that wait on them.

Co-Authored-By: Claude <noreply@anthropic.com>
EOF2
  git -C "$clone" -c credential.helper= -c 'credential.helper=!gh auth git-credential' \
    push --quiet origin "HEAD:refs/heads/$RESULTS_BRANCH"
  echo "Sent: https://github.com/$REPO/blob/$RESULTS_BRANCH/docs/plans/0.7.0/sessions/$SESSION.md"
}

# MARK: - The short sessions: the Charge limit capture (C), the hold watch (H)

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

# timeline_rows [<n>]: the recording's last rows (time, percent, state, external, NotChargingReason).
timeline_rows() {
  local file
  file="$(record_folder)/timeline.tsv"
  [ -s "$file" ] || return 0
  awk -F '\t' 'NR > 1 { print $1 " " $2 " % " $3 ", external " $4 ", NotChargingReason " $5 }' "$file" | tail -"${1:-3}"
}

# timeline_changes: each row where the state or NotChargingReason changed, with the row before it
# (the rows around each change, PLAN.md W-12 item 1).
timeline_changes() {
  local file
  file="$(record_folder)/timeline.tsv"
  [ -s "$file" ] || return 0
  awk -F '\t' 'NR == 2 { print $1 " " $2 " % " $3 ", external " $4 ", NotChargingReason " $5 " (the first row)" }
    NR > 2 && ($3 != state || $5 != reason) {
      print "  " prev
      print $1 " " $2 " % " $3 ", external " $4 ", NotChargingReason " $5
    }
    NR > 1 { state = $3; reason = $5; prev = $1 " " $2 " % " $3 ", external " $4 ", NotChargingReason " $5 }' "$file"
}

# bit24_seen: a row of the recording at the limit, not charging, on the adapter, with bit 24.
bit24_seen() {
  local file
  file="$(record_folder)/timeline.tsv"
  [ -s "$file" ] || return 1
  awk -F '\t' 'NR > 1 && $3 == "notCharging" && $4 == "true" && $5 ~ /^[0-9]+$/ && int($5 / 16777216) % 2 == 1 { found = 1 } END { exit !found }' "$file"
}

# charge-limit start | hold | full [--his-hand] | wait100 | back [--his-hand] | stop | check: the
# Charge limit capture (QUA-05; 0.8's FEA-35 check), from its short session with the adapter in.
#   start: the limit read on the adapter (pmset -g battlimit, else the Battery pane's shot), the
#          charge at least 5 points below it, then the recording;
#   hold:  waits (a background task, at most 3 hours) until charging stops at the limit, and says
#          whether NotChargingReason gained bit 24;
#   full:  after the session set the limit to 100 % by computer use (`change charge-limit <n> 100`
#          first), waits until battlimit shows none; --his-hand beeps twice for his hand instead;
#   wait100: the 10 minutes at 100 % (a background task), the rows around the change;
#   back:  after the limit went back, waits until battlimit shows it, then `restored`;
#   stop:  the recording ended, the rows around each change, the bit-24 verdict;
#   check: the limit is as at start.
step_charge_limit() {
  session_only C charge-limit
  local limit now charge waited=0
  use_section 10-charge-limit "The Charge limit capture (QUA-05)"
  case "${1:-}" in
    start)
      [ "$(answer_of C-yes)" = y ] || fail "first his yes, with the adapter in: $SCRIPT answer --by person C-yes y"
      mkdir -p "$WORK" "$LOGS" "$SECTIONS" "$SHOTS"
      touch "$CHANGES" "$HEARTBEAT"
      [ -f "$WORK/prepare.time" ] || clock >"$WORK/prepare.time"
      ! on_battery || fail "on battery: battlimit holds no limit there; plug the adapter in, then start again"
      limit="$(battlimit_value)"
      if [ -n "$limit" ]; then
        step_answer --by claude prep-charge-limit "$limit" "read by pmset -g battlimit on the adapter" >/dev/null
      elif [ -z "$(answer_of prep-charge-limit)" ]; then
        echo "pmset -g battlimit shows no limit: read System Settings → Battery → (i) next to Charging by computer use, then $SCRIPT answer --by claude prep-charge-limit <n> \"<the shot>\", and start again"
        return 1
      fi
      limit="$(answer_of prep-charge-limit)"
      [ "$limit" != 100 ] || fail "no Charge Limit is set (100 %): there is no hold to capture"
      charge="$(battery_percent)"
      [ "$((charge + 5))" -le "$limit" ] || fail "the charge ($charge %) isn't 5 points below the limit ($limit %): run this after a discharge"
      out "- the limit: $limit %; the charge at the start: $charge %, on the adapter ($(clock))"
      record_start "record-$(date '+%Y%m%d-%H%M')"
      out "- recording into $(basename "$(record_folder)") (on the Mac)"
      ;;
    hold)
      limit="$(answer_of prep-charge-limit)"
      while [ "$waited" -lt 10800 ]; do
        if bit24_seen; then break; fi
        now="$(timeline_rows 1)"
        case "$now" in *notCharging*) break ;; esac
        sleep 30
        waited=$((waited + 30))
      done
      out "- the hold ($(clock)), after $((waited / 60)) minutes: $(timeline_rows 1)"
      if bit24_seen; then
        step_answer --by claude C-bit24 1 "the recording's rows at the hold" >/dev/null
      elif [ "$waited" -ge 10800 ]; then
        step_answer --by claude C-bit24 3 "charging didn't stop within 3 hours" >/dev/null
      else
        step_answer --by claude C-bit24 2 "notCharging without bit 24" >/dev/null
      fi
      out "- NotChargingReason gained bit 24 when charging stopped at the limit: $(answer_of C-bit24) (1 yes, 2 no, 3 not reached)"
      ;;
    full | back)
      limit="$(answer_of prep-charge-limit)"
      if [ "${2:-}" = --his-hand ]; then
        cue "Set the Charge Limit to $(if [ "$1" = full ]; then echo 100; else echo "$limit"; fi) % now"
        sound Glass
        sound Glass
      fi
      [ -n "$(original_of charge-limit)" ] || [ "$1" = back ] ||
        echo "note: record the change first ($SCRIPT change charge-limit $limit 100); the wait goes on"
      while [ "$waited" -lt 180 ]; do
        now="$(battlimit_value)"
        if [ "$1" = full ] && [ -z "$now" ]; then break; fi
        if [ "$1" = back ] && [ "$now" = "$limit" ]; then break; fi
        sleep 5
        waited=$((waited + 5))
      done
      now="$(battlimit_value)"
      out "- $1 ($(clock)): pmset -g battlimit ${now:-shows none}; $(timeline_rows 1)"
      clock >"$WORK/charge-$1.time"
      if [ "$1" = full ]; then
        if [ -z "$now" ]; then step_answer --by claude C-full y "pmset -g battlimit shows none" >/dev/null; else
          echo "battlimit still shows $now: read the Battery pane's shot, then $SCRIPT judge C-full <y|n>"
        fi
      else
        if [ "$now" = "$limit" ]; then
          step_answer --by claude C-back y "pmset -g battlimit shows $now" >/dev/null
          [ -z "$(original_of charge-limit)" ] || mark_restored charge-limit "pmset -g battlimit shows $now"
        else
          echo "battlimit shows ${now:-none}, not $limit: read the Battery pane's shot, then $SCRIPT judge C-back <y|n>"
        fi
      fi
      ;;
    wait100)
      [ -f "$WORK/charge-full.time" ] || fail "the limit isn't at 100 % yet: $SCRIPT charge-limit full"
      sleep_until $(($(date -j -f '%Y-%m-%d %H:%M:%S' "$(cat "$WORK/charge-full.time")" +%s 2>/dev/null || date +%s) + 600))
      out "- 10 minutes at 100 % ($(clock)): $(timeline_rows 1)"
      echo "now the limit back by computer use, then: $SCRIPT charge-limit back"
      ;;
    stop)
      stop_leftovers record
      out "- the recording stopped ($(clock)): $(find "$(record_folder)" -name '*.plist' 2>/dev/null | grep -c . || true) captures (on the Mac; a fixture only on his yes)"
      out "- the rows around each change (time, charge, state, external power, NotChargingReason):"
      timeline_changes >"$LOGS/charge-changes.txt"
      out_block "$LOGS/charge-changes.txt"
      ;;
    check)
      limit="$(answer_of prep-charge-limit)"
      now="$(battlimit_value)"
      if [ "$now" = "$limit" ]; then echo "the Charge Limit is back at $now %"; else
        echo "THE CHARGE LIMIT READS ${now:-none}, NOT $limit %: put it back (computer use, System Settings → Battery), or on battery read the pane's shot"
        return 1
      fi
      ;;
    *) fail "usage: $SCRIPT charge-limit start | hold | full [--his-hand] | wait100 | back [--his-hand] | stop | check" ;;
  esac
}

# hold-watch start | morning: QUA-06, an optimized-charging hold overnight: the same recording
# under caffeinate -i, the Mac on the adapter with the lid open; in the morning, whether the charge
# was held below 100 % on the adapter for 15 minutes or more, with its NotChargingReason values
# (whether macOS holds the charge while the Mac is kept awake is uncertain).
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
      echo "Judge H-hold from them: a span of 15 minutes or more is a hold (1), none is 2"
      ask H-hold
      ;;
    *) fail "usage: $SCRIPT hold-watch start | morning" ;;
  esac
}

# MARK: - The short sessions: after publishing (D3; PLAN.md §6.4)

# after before | after | popover: the before-picture (pluginkit, the crops after the desktop click,
# the time), right before Check for Updates and Install and Relaunch by AX presses; after (waits
# for 0.7.0, at most 3 minutes): the update log's pre-swap line and CHSErrorDomain 1103, pluginkit,
# the crops, `codesign -dv --verbose=4` and `xattr -l` (P2 D3's list); popover: the first day's
# comparison, the popover beside the widgets.
step_after() {
  session_only D3 after
  local waited=0 flags quarantine swap
  use_section 10-after "After publishing (§6.4)"
  case "${1:-}" in
    before)
      [ "$(answer_of D3-yes)" = y ] || fail "first his yes: $SCRIPT answer --by person D3-yes y"
      mkdir -p "$WORK" "$LOGS" "$SECTIONS" "$SHOTS"
      [ -f "$WORK/prepare.time" ] || clock >"$WORK/prepare.time"
      clock >"$WORK/after.time"
      pluginkit -mv -i "$WIDGET_ID" >"$LOGS/pluginkit-before.txt" 2>&1 || true
      click_desktop || not_checked D3-widgets "no desktop spot"
      crop_widgets "$SHOTS/after" before
      out "- before ($(cat "$WORK/after.time")): $(app_version); widget extension pids: $(widget_pids | tr '\n' ' ')"
      out_block "$LOGS/pluginkit-before.txt"
      echo "DO (session): Check for Updates, then Install and Relaunch to 0.7.0, by AX presses; then: $SCRIPT after after"
      ;;
    after)
      [ -f "$WORK/after.time" ] || fail "first: $SCRIPT after before"
      until [ "$(plist_value "$APP/Contents/Info.plist" CFBundleShortVersionString)" = 0.7.0 ] || [ "$waited" -ge 180 ]; do
        sleep 1
        waited=$((waited + 1))
      done
      sleep 10
      out "- after: $(app_version), running $(if app_running; then echo yes; else echo no; fi)"
      log_since "$(cat "$WORK/after.time")" "$UPDATE_PREDICATE" "$LOGS/after-update.ndjson" >/dev/null
      swap="$(messages "$LOGS/after-update.ndjson" | grep -F 'extension before the swap' | head -1 || true)"
      out "- 0.6.2's pre-swap line (every BatteryPulseWidget process ended, D-17): ${swap:-none}; $(chs_since "$(cat "$WORK/after.time")")"
      pluginkit -mv -i "$WIDGET_ID" >"$LOGS/pluginkit-after.txt" 2>&1 || true
      out_block "$LOGS/pluginkit-after.txt"
      flags="$(codesign -dv --verbose=4 "$APP" 2>&1 | grep -o 'flags=[^ ]*' | head -1 || true)"
      quarantine="$(xattr -l "$APP" 2>/dev/null | grep -c com.apple.quarantine || true)"
      out "- codesign: ${flags:-no flags line} (expected flags=0x10002(adhoc,runtime)); quarantine lines: $quarantine (expected 0)"
      click_desktop || true
      crop_widgets "$SHOTS/after" after
      echo "Read About, What's New, History, the settings and Login Items by computer use (shots), then answer:"
      ask D3-version D3-whats-new D3-count-row D3-widgets D3-history D3-settings D3-login-item D3-notifications
      ;;
    popover)
      [ -s "$WORK/status-item" ] || proof_p11 >/dev/null
      click_desktop || true
      crop_widgets "$SHOTS/after" first-day
      if [ -s "$WORK/status-item" ]; then
        # shellcheck disable=SC2046
        ui_run click $(awk '{ printf "%d %d", $1 + $3 / 2, $2 + $4 / 2 }' "$WORK/status-item") --expect BatteryPulse >/dev/null 2>&1 || true
        sleep 2
        front_shot "$SHOTS/after/popover.png" || not_checked D3-first-day "no shot of the popover"
        # shellcheck disable=SC2046
        ui_run click $(awk '{ printf "%d %d", $1 + $3 / 2, $2 + $4 / 2 }' "$WORK/status-item") --expect BatteryPulse >/dev/null 2>&1 || true
        park_pointer
      else
        not_checked D3-first-day "no menu bar item frame (P11): computer use opens the popover"
      fi
      ask D3-first-day
      ;;
    *) fail "usage: $SCRIPT after before | after | popover" ;;
  esac
}

# count-check | count-check stats: W-13's version count (§6.4 step 6), with Check for updates set to
# anything but Never: BatteryPulse quit, lastCountedVersion and lastUpdateCheck cleared,
# versionFirstLaunch back-dated (the grace day skipped, a check due), BatteryPulse opened again;
# then W-13's update line (the first automatic check runs 20 s after launch), at most 2 minutes.
# stats, 10 minutes after that line (a background wait): scripts/release-stats.swift, v0.7.0's
# count. On failed, noCounter or no line it prints the logged code.
step_count_check() {
  session_only D3 count-check
  local frequency since waited=0 line
  use_section 20-count "The version count (W-13)"
  case "${1:-}" in
    "")
      frequency="$(defaults read "$BUNDLE_ID" updateFrequency 2>/dev/null || echo "default")"
      [ "$frequency" != never ] || fail "Check for updates is Never: set it to anything else in BatteryPulse's Settings (his yes), then count-check again"
      quit_app
      defaults delete "$BUNDLE_ID" lastCountedVersion 2>/dev/null || true
      defaults delete "$BUNDLE_ID" lastUpdateCheck 2>/dev/null || true
      defaults write "$BUNDLE_ID" versionFirstLaunch -date "2026-01-01 00:00:00 +0000"
      since="$(clock)"
      echo "$since" >"$WORK/count.time"
      launch_plain
      while [ "$waited" -lt 120 ]; do
        sleep 10
        waited=$((waited + 10))
        log_since "$since" "$UPDATE_PREDICATE" "$LOGS/count.ndjson" >/dev/null
        line="$(messages "$LOGS/count.ndjson" | grep -i -E 'counted|nocounter|count' | head -1 || true)"
        [ -z "$line" ] || break
      done
      out "- count-check at $since (Check for updates: $frequency): ${line:-no update line within 2 minutes}"
      case "$line" in
        *ounted*) echo "counted: in 10 minutes, $SCRIPT count-check stats (wait in the background: $SCRIPT wait 9, twice)" ;;
        *oCounter*) echo "noCounter: the asset is missing: the cloud session runs the gh release upload release.yml's check names, then count-check again" ;;
        *) echo "no counted line: $(messages "$LOGS/count.ndjson" | tail -3)" ;;
      esac
      ;;
    stats)
      [ -f "$WORK/count.time" ] || fail "first: $SCRIPT count-check"
      sleep_until $(($(date -j -f '%Y-%m-%d %H:%M:%S' "$(cat "$WORK/count.time")" +%s 2>/dev/null || date +%s) + 600))
      (cd "$ROOT" && xcrun swift scripts/release-stats.swift) >"$LOGS/release-stats.txt" 2>&1 ||
        out "- release-stats failed: $(tail -1 "$LOGS/release-stats.txt")"
      out "- release-stats (10 minutes after the check):"
      # Newest first: the header, its rule, then 0.7.0's row.
      head -3 "$LOGS/release-stats.txt" >"$LOGS/release-stats-070.txt" || true
      out_block "$LOGS/release-stats-070.txt"
      ask D3-count
      ;;
    *) fail "usage: $SCRIPT count-check [stats]" ;;
  esac
}

# MARK: - The dry run (CI on Linux)

# dry-run: Session R's bookkeeping on any machine, in a folder of its own, with nothing of the Mac:
# every session's questions resolve; the setting names the runbook records come back the right
# way; answer and judge validate and record (an unsure judgment joins his batch); English only;
# the change record and its restored lines; the logged day's fence and its day-end; the summary's
# alerts; the report and its privacy lint. Exit status 1 on a broken rule.
dry_run() {
  local problems=0 id session setting report
  DRY_RUN=1
  check() {
    if [ "$1" = ok ]; then echo "ok: $2"; else
      echo "FAIL: $2" >&2
      problems=$((problems + 1))
    fi
  }
  mkdir -p "$WORK" "$SECTIONS" "$LOGS"
  for session in R C H D3; do
    SESSION="$session"
    for id in $(questions_list); do
      if question "$id" >/dev/null; then :; else check fail "$session's question $id has no text"; fi
    done
  done
  SESSION=R
  check ok "every session's questions resolve"
  for setting in app bp-settings bp-support widget-data remembered-devices widget-languages; do
    [ "$(restore_how "$setting")" = script ] && check ok "$setting comes back by the script" ||
      check fail "$setting should come back by the script"
  done
  for setting in app-language widget-style dim-widgets text-size increase-contrast reduce-transparency 24-hour \
    open-at-login bluetooth-accessory widget-choices charge-limit desktop-widgets; do
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
  [ "$(battlimit_value <(printf ' Battery level limits:\n  chargeSocLimitSoc = 80\n'))" = 80 ] &&
    check ok "battlimit's chargeSocLimitSoc reads as the limit" || check fail "battlimit's value isn't read"
  [ -z "$(battlimit_value <(printf 'No battery level limits set\n'))" ] && check ok "no limit reads as none" ||
    check fail "no limit didn't read as none"
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
    C)
      cat <<EOF
usage: $SCRIPT <command> [arguments]          (the Charge limit capture; SESSION-R.md, "Charge limit")

  answer --by person C-yes y; charge-limit start (the adapter in, at least 5 points below the limit)
  charge-limit hold (a background task: wait 9 until it ends); change charge-limit <n> 100, then the slider
  by computer use (or --his-hand); charge-limit full; charge-limit wait100 (a background task);
  the slider back; charge-limit back; restored charge-limit "<how>"; charge-limit stop; charge-limit check
  then batch, send --dry-run, his C-send, send. Any time: status, note, shot, crop, attach, ui, judge, wait, help.
EOF
      ;;
    H)
      cat <<EOF
usage: $SCRIPT <command> [arguments]          (the hold watch; SESSION-R.md, "Hold watch")

  answer --by person H-yes y; hold-watch start (the adapter in, the lid open); in the morning: hold-watch morning,
  judge H-hold; then send --dry-run, his H-send, send. Any time: status, note, help.
EOF
      ;;
    D3)
      cat <<EOF
usage: $SCRIPT <command> [arguments]          (after publishing; SESSION-R.md, "After publishing")

  answer --by person D3-yes y; ui access; proof P1 --image <png> <x> <y>; widget <name> x y w h; desktop-spot ...;
  proof P11; after before; Check for Updates, Install and Relaunch (ui press); after after (then judge each D3-*);
  count-check; count-check stats (10 minutes later: wait in the background); after popover;
  then batch, send --dry-run, his D3-send, send. Any time: status, note, shot, crop, attach, ui, judge, wait, help.
EOF
      ;;
    *)
      cat <<EOF
usage: $SCRIPT <command> [arguments]          (Session R, hands-free; SESSION-R.md is the runbook)

The start (on the adapter, he is there):
  prepare attempt [--kept <setting>[,...]] [--restored <setting>[,...] "<how>"]   first: a clean start
  answer --by person R-yes y (and R-back, R-keep-ax, R-keep-widgets, R-usage)
  prepare [--fresh-backup]   the backup into ~/bp-070/R, the builds (base, U, P, U2, F), the tools; a beep
  prepare reads              the Charge Limit, 24-hour, Open at login, Check for updates, Window to open, the
                             languages, the appearance; the panes' shots for the two style settings; pluginkit
  proof P1 --image <png> <x> <y> | P6 | P7 | P8 | P11 | <P#> pass|fail <note>
  widget <name> <x> <y> <w> <h> (names: $WIDGET_NAMES); desktop-spot <x> <y> | --image <png> <x> <y>
  main                       the main window, before the first computer-use action in BatteryPulse
  preflight                  the checks, P7 P8 P6 P11, the Claude desktop app, pending macOS updates
  raw-history base; placed before; install U; placed 1; placed 5; plug (his two beeps)
  arm open; mark away        the arm window, then the GUI phase (no sound from here until his day-end)
The GUI phase (heartbeat <step and expected time> after each step, at least every 10 minutes):
  placed compare; gallery <name>; edit-shot <tag>; language ru [--extension] | back; install P; install U2
  look <always|auto|nc> <default|dark|clear|tinted> | look contrast | transparency | 12-hour | text-size
  tick; count-toggle; tree [ru]; click-widget quit|running|accessories|health|main|compact
  accessories-watch disconnect|reconnect; demo-shots [ru]; raw-history rc; menubar; wp18 previews|timing
  pane <$(tr ' ' '|' <<<"$PANES")>; open-app Xcode | TextEdit | "Accessibility Inspector"
  measure <id> blank|same|differs|contrast <arguments>; judge <id> <answer> [--unsure] [note]
  change <setting> <original> <new> (before any change by computer use or AX); restored <setting> <how>
  ui <command...>            the hands (ui.swift's usage), through the script only
  restore gui; summary; ready (last: the arm window starts the logged day)
The day's end (on his "day-end"):
  day-end; f12 rate; install F; f12 before; f12 after; batch; send --dry-run; his R-send; send; restore end; summary end
While a background task runs: wait [<minutes, 1-9>] in the foreground, again until it ended.
Any time: status, note, shot, crop, attach, unattach, help; dry-run anywhere (CI).
EOF
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
# it moves that aside (step_attempt refuses while that attempt's arm window runs).
if [ "$SESSION" = R ] && [ "$COMMAND" = prepare ] && [ "${1:-}" = attempt ]; then
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
[ "$SESSION" != none ] ||
  fail "$COMMAND runs from a session's frozen worktree (~/bp-070/R/run, C/run, H/run or D3/run): see SESSION-R.md"
# From Session R's ready until his day-end, nothing acts, whichever session's script runs: the
# reads, day-end and the arm itself are let through.
case "$COMMAND:${1:-}" in
  status:* | day-end:* | arm:) ;;
  *)
    if [ "$SESSION" = R ]; then attempt_fence; fi
    r_fence
    mkdir -p "$WORK"
    touch "$HEARTBEAT"
    heartbeat_keeper
    ;;
esac
case "$COMMAND" in
  prepare)
    r_only prepare
    if [ "${1:-}" = reads ]; then run_step step_prepare_reads; else step_prepare_r "$@"; fi
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
    r_only preflight
    run_step step_preflight "$@"
    ;;
  placed) run_step step_placed "$@" ;;
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
  menubar) run_step step_menubar ;;
  menu-bar-shots) run_step step_menu_bar_shots "$@" ;;
  wp18) run_step step_wp18 "$@" ;;
  arm) run_step step_arm "$@" ;;
  ready) run_step step_ready ;;
  summary) run_step step_summary "$@" ;;
  day-end) run_step step_day_end ;;
  f12) run_step step_f12 "$@" ;;
  restore) run_step step_restore "$@" ;;
  charge-limit) run_step step_charge_limit "$@" ;;
  hold-watch) run_step step_hold_watch "$@" ;;
  after) run_step step_after "$@" ;;
  count-check) run_step step_count_check "$@" ;;
  *)
    step_help >&2
    exit 1
    ;;
esac
