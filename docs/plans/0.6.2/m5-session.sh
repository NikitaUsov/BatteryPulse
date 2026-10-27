#!/bin/bash
# BatteryPulse 0.6.2: the M5 sessions (docs/plans/0.6.2/PLAN.md §6), one command per call.
#
#   bash docs/plans/0.6.2/m5-session.sh help
#
# Session A: a Claude Code session on the Mac runs it as docs/plans/0.6.2/SESSION.md says; the
# person at the Mac only does what needs hands, eyes or ears, and starts the unattended window in
# Terminal, where sudo asks for the password once. Everything lands in ~/bp-062/A, and `send`
# commits A.md to docs/plans/0.6.2/sessions/A.md on claude/062-session-a.
#
# Session B (hands-free; PLAN.md §6 and WP-21's hands-free mode; its runbook is SESSION-B.md): one
# local Claude Code session with computer use runs it from the frozen worktree ~/bp-062/B/run (a
# script run from there is Session B), drives the GUI through `ui` (ui.swift, with safety rules of
# its own) and judges the pictures beside the script's pixel measurements; the energy queue runs
# as a plain script in the arm window. Everything lands in ~/bp-062/B: each change goes into
# changes.tsv before it is made, and every restore works from that file; `send` commits B.md to
# docs/plans/0.6.2/sessions/B.md on claude/062-session-b after his yes, through a privacy lint. An
# automated step that can't run records "not checked" or "not run" with its reason, and the
# session goes on.
#
# In both, the builds stay in their DMGs and the backup in its zip, so the only BatteryPulse.app on
# the disk is the one in /Applications, and macOS can't pick up another copy's widget. Never another
# results branch, never a pull request.
#
# Every install goes the way UpdateInstaller goes: a copy staged on the same volume, one atomic swap
# (swap.swift: renamex_np with RENAME_SWAP), lsregister -f, a relaunch. A build whose
# CFBundleVersion isn't higher than the installed one is refused (WidgetKit caches by it), except
# the reinstall of 0.6.1 and restore's reinstall of your own app (install_build).
#
# Wording (PLAN.md §3): every y/n question means "y = looks right"; everything else is a numbered
# choice. A step prints its questions as ASK lines and its hands-on tasks as DO lines; `answer`
# (and in Session B `judge`) records the replies. The script reads the logs and counts the crash
# reports itself.
#
# It needs macOS 27, Xcode or the Command Line Tools, and the GitHub CLI (https://cli.github.com),
# signed in. No python or perl; it runs on macOS's bash 3.2. Millisecond times come from zsh's
# zsh/datetime module.
set -euo pipefail

# MARK: - Builds and places

REPO="NikitaUsov/BatteryPulse"
INTEGRATION_BRANCH="claude/nice-faraday-k08mhb"

# The builds (PLAN.md §5 A2 and A2′, WP-W0, WP-21), each a CI artifact pinned to its run. Every CI
# build of a push has its run number as CFBundleVersion, so C (277) < I (278) < W (282) < A2 (285),
# and A (158) sits between B and the spikes; B is the published 0.6.1 (release run 7).
RUN_C="39800982102" # SPIKE-C, #277: 0.6.1's code, the control
ARTIFACT_C="BatteryPulse-76223738b61a8fc2a442115eb7fc93dba332eb73"
RUN_I="39801168615" # SPIKE-I, #278: 0.6.1 plus -internalize-at-link on the widget
ARTIFACT_I="BatteryPulse-dbf4dfa11a2fe4a87a38f2f74c44eaeb7a7fabd3"
RUN_W="39806441696" # SPIKE-W, #282 (a609487): the configurable kind, the Test kind, the feed, clicks
ARTIFACT_W="BatteryPulse-a60948765b7e7df33e3a8a5d43a71953d889b411"
# W2 is the same code as W, built again by workflow_dispatch so its build number (307) is new: chronod
# caches a widget's descriptors by CFBundleVersion, and Session A's first W install cached 282 with
# the previous build's descriptor (see install_build). W2 retests W0-2 after `install B`.
RUN_W2="40002896511" # SPIKE-W again, #307 (a609487), the same artifact name as W
ARTIFACT_W2="$ARTIFACT_W"
RUN_A2="39808734092" # SPIKE-A2, #285 (cee5033): E20, the minimize fill switch, and a profiling DMG
ARTIFACT_A2="BatteryPulse-cee5033bae2f9e459332a5b22fa971aff2583765"
ARTIFACT_A2P="BatteryPulse-profiling-cee5033bae2f9e459332a5b22fa971aff2583765"
RUN_A="39413159534" # A: claude/baseline-0.6.0, #158 (076873d), the instrumented 0.6.0
ARTIFACT_A="BatteryPulse-076873d5bf151db628de91e216a8bfabb9356e1a"
TAG_B="v0.6.1" # B: the published 0.6.1 DMG

# Session B's builds (PLAN.md §6, WP-21): B, the published 0.6.1 (TAG_B); C, the RC, dispatched
# as 0.5.99 so that F12's update check offers the real 0.6.1; CP, the RC's profiling DMG, from the
# same run (ci.yml's dispatch with version 0.5.99 and profiling on). They stay empty (D1), so
# prepare finds that run by the frozen worktree's code (rc_locate); pinning them overrides it.
RUN_RC=""
ARTIFACT_RC=""
ARTIFACT_RCP=""

# SPIKE-A2's hidden switch (AppSettings.spikeA2MinimizeFillKey on that branch, never shipped): a
# WindowLookPolicy.SpikeMinimizeFill raw value, read at launch. "b" gives Clear fill (b) and leaves
# Translucent on today's fill; "b-and-translucent-dark" gives Translucent Dark fill (b) too.
FILL_KEY="spikeA2MinimizeFill"
FILL_VALUE="b"
FILL_VALUE_TD="b-and-translucent-dark"

BUNDLE_ID="io.github.nikitausov.BatteryPulse"
WIDGET_ID="$BUNDLE_ID.Widget"
FEED_DOMAIN="$BUNDLE_ID.widgetfeed"
APP="/Applications/BatteryPulse.app"

HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$HERE/../../.." && pwd)"
# The account's own home. On the Mac it comes from the user database, and HOME must be it: a run
# with another HOME would find no fence, take itself for Session A and record its changes in a
# folder no restore reads.
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
# The session: B when the script runs from Session B's frozen worktree (~/bp-062/B/run, the start
# line's one allow rule), A otherwise. BP_SESSION overrides it only off the Mac (a dry run
# elsewhere): on the Mac the path alone decides, so no variable turns Session B's fence off.
case "$HERE" in
  "$ACCOUNT_HOME"/bp-062/B/run/*) SESSION=B ;;
  *) SESSION=A ;;
esac
if [ "$(uname -s)" != Darwin ]; then SESSION="${BP_SESSION:-$SESSION}"; fi
# Session B's folder, whatever this run's own folder is: the night fence lives there.
B_HOME="$ACCOUNT_HOME/bp-062/B"
# queue --dry-run (CI on Linux) is Session B's queue in a folder of its own. On the Mac nothing
# else moves the folder: a BP_WORK of the caller's would hold no fence and no change record.
if [ "${1:-}" = queue ] && [ "${2:-}" = --dry-run ]; then
  SESSION=B
  BP_WORK="$(mktemp -d "${TMPDIR:-/tmp}/bp-062-dry.XXXXXX")"
elif [ "$(uname -s)" = Darwin ]; then
  BP_WORK=""
fi
case "$SESSION" in
  A) RESULTS_BRANCH="claude/062-session-a" ;;
  B) RESULTS_BRANCH="claude/062-session-b" ;;
  *)
    echo "error: BP_SESSION is A or B" >&2
    exit 1
    ;;
esac
TAB="$(printf '\t')"
# BP_WORK only moves the folder for a dry run of the bookkeeping commands (help, answer, note,
# status, send --dry-run, queue --dry-run) on another machine, and for queue --dry-run.
WORK="${BP_WORK:-$ACCOUNT_HOME/bp-062/$SESSION}"
BACKUP="$WORK/backup"
BUILDS="$WORK/builds"
BIN="$WORK/bin"
SHOTS="$WORK/shots"
REC="$WORK/recordings"
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
SPIKE_PREDICATE="subsystem == \"$BUNDLE_ID\" AND category == \"widget\" AND eventMessage BEGINSWITH \"spike\""
EXECUTOR_PREDICATE='process BEGINSWITH "BatteryPulse" AND eventMessage CONTAINS[c] "executor"'
# The pages of WP-17's page switches, as the sidebar names them, and their signpost names.
PAGES="Overview:overview Power:power History:history Health:health Accessories:accessories Raw_Data:developer Demo_Mode:demo"


# MARK: - Small helpers

fail() {
  echo "error: $*" >&2
  exit 1
}

warn() { echo "warning: $*" >&2; }

# public: the text with the home folder and user names taken out of paths, for A.md.
public() { sed -e "s|$HOME|~|g" -e 's|/Users/[^/ "]*|/Users/~|g'; }

CYRILLIC="$(printf '[\320\321\322\323]')"
has_cyrillic() { printf '%s' "$1" | LC_ALL=C grep -q "$CYRILLIC"; }

# The repository is English only (LocalizationCatalogTests scans docs/), so A.md can't take Russian.
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

# MARK: - Sections of A.md

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
# who: person (only the person can say) or judge (the session judges from the evidence the step
# names, and asks the person only when it can't tell).
question() {
  if [ "$SESSION" = B ] && question_b "$1"; then return 0; fi
  case "$1" in
    prep-widget-style) echo "text|person|System Settings → Appearance → Icon & widget style: which is selected now (Default, Dark, Clear or Tinted)?" ;;
    prep-dim-widgets) echo "text|person|System Settings → Desktop & Dock → Dim widgets on desktop: which value is set now?" ;;
    prep-open-at-login) echo "2|person|BatteryPulse Settings → General → Open at login: 1 on, 2 off" ;;
    prep-widgets) echo "2|judge|Are a small and a medium BatteryPulse widget on the desktop, with nothing covering them? 1 yes, 2 no" ;;
    F5-accessories) echo "3|judge|Accessories in the captures: 1 bpulse lists what pmset lists, 2 pmset lists accessories bpulse doesn't (hidden from apps), 3 neither lists any" ;;
    F5-iphone) echo "3|judge|The iPhone page in the packaged app: 1 values shown, 2 an error or no values, 3 no iPhone at hand" ;;
    F5-local-network) echo "3|person|Did macOS ask whether BatteryPulse may find devices on the local network? 1 yes, 2 no, 3 no iPhone at hand" ;;
    F5-attach-detach) echo "yn|judge|Did the iPhone page follow the cable: values after attaching, and the device shown as disconnected or gone after detaching?" ;;
    W0-2-C) echo "4|judge|SPIKE-C over 0.6.1, the placed widgets against the reference picture: 1 same, 2 blank or grey, 3 gone, 4 different (note)" ;;
    W0-2-I-small | W0-2-I-medium | W0-2-I-large | W0-2-I-xlarge)
      echo "4|judge|SPIKE-I, the ${1##*-} widget (small and medium placed under 0.6.1, large and extra large added now): 1 same as the reference or right, 2 blank or grey, 3 gone, 4 different (note)"
      ;;
    W0-2-W-small | W0-2-W-medium | W0-2-W-large | W0-2-W-xlarge)
      echo "4|judge|SPIKE-W over SPIKE-I, the ${1##*-} widget: 1 same as under SPIKE-I, 2 blank or grey, 3 gone, 4 different (note)"
      ;;
    W0-2-W-edit) echo "yn|judge|Edit Widget on the Battery widget: are Layout, Main value and Time all there (and Details once Layout is Custom)?" ;;
    W0-1-test-edit) echo "yn|judge|Edit Widget on the Test widget: are Main value, Details and Device all there, the summary reading 'Show <main value>'?" ;;
    W0-2-W-ru) echo "4|judge|With AppleLanguages (ru) in the extension's preferences: 1 the widgets and the edit sheet in Russian, 2 only the widgets, 3 only the edit sheet, 4 neither (recorded as not checked)" ;;
    W0-6-format-en | W0-6-format-ru) echo "3|judge|Does the Test widget show a time left like '2 hours, 13 minutes' (lines a and b)? 1 yes, 2 with seconds, 3 something else (note)" ;;
    W0-6-tick) echo "3|judge|A minute later, did the Test widget's minutes go down by one without a reload? 1 yes, 2 no, 3 it shows seconds" ;;
    W0-2-reinstall) echo "2|judge|After the script reinstalled 0.6.1: 1 every BatteryPulse widget shows, 2 a widget was blank and was removed and added again (note which)" ;;
    W0-5-voiceover) echo "text|person|What did VoiceOver say for the widget, the battery symbol especially (in English; say which language it spoke), or 'not reached'?" ;;
    W0-5-text-size) echo "2|judge|With a larger System Settings → Accessibility → Display → Text size, did the widget's text change? 1 yes, 2 no" ;;
    V01-notification) echo "yn|person|Did the test notification arrive, and did clicking its banner bring BatteryPulse forward?" ;;
    V01-notification-front) echo "yn|person|And again with the BatteryPulse window in front?" ;;
    V01-menubar) echo "yn|judge|Does the menu bar icon look right on a light and on a dark menu bar?" ;;
    V01-pages) echo "yn|person|Raw Data, History, Demo Mode on and off, Check Now (an offered update closed without installing) and Clear History: did each work?" ;;
    V01-lid) echo "yn|judge|After the lid was closed for a minute and opened: does BatteryPulse still run with a current value in the menu bar?" ;;
    fill-clear-light | fill-clear-dark | fill-translucent-dark)
      echo "3|judge|${1#fill-}: while the window shrank into the Dock and came back: 1 like the window, or an even graphite grey, 2 a black frame, 3 something else (note)"
      ;;
    fill-translucent-dark-b) echo "3|judge|translucent-dark with fill (b) extended to it (only after a 2 above): 1 like the window, or an even graphite grey, 2 a black frame, 3 something else (note)" ;;
    energy-setup) echo "2|person|Energy setup for the window: display brightness about half, auto-brightness and True Tone off, other apps quit (Terminal and this session stay), a Focus on: 1 done, 2 not all (note)" ;;
    *) return 1 ;;
  esac
}

QUESTIONS="prep-widget-style prep-dim-widgets prep-open-at-login prep-widgets
F5-accessories F5-iphone F5-local-network F5-attach-detach
W0-2-C W0-2-I-small W0-2-I-medium W0-2-I-large W0-2-I-xlarge
W0-2-W-small W0-2-W-medium W0-2-W-large W0-2-W-xlarge W0-2-W-edit W0-1-test-edit
W0-6-format-en W0-6-tick W0-2-W-ru W0-6-format-ru
W0-2-reinstall W0-5-voiceover W0-5-text-size
V01-notification V01-notification-front V01-menubar V01-pages V01-lid
fill-clear-light fill-clear-dark fill-translucent-dark fill-translucent-dark-b
energy-setup"

kind_hint() {
  case "$1" in
    yn) echo "y/n, y = looks right" ;;
    text) echo "text" ;;
    *) echo "1-$1" ;;
  esac
}

# ask <id>...: the questions as ASK lines for the session to put to the person, or to judge.
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
  # Session B's judge records "unsure" for the morning batch where 3 isn't "something else".
  if [ "$value" = unsure ] && [ "$SESSION" = B ] && [ "$by" = claude ]; then kind=text; fi
  if [ "$SESSION" = B ] && [ "$id" = B-send ] && [ "$value" = y ]; then
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
  if [ "$SESSION" = B ] && [ "$id" = B-send ]; then touch "$WORK/send-yes"; fi
  echo "recorded $id = $value ($by)"
}

step_note() {
  [ $# -ge 1 ] || fail "usage: $SCRIPT note <text>"
  english_only "$*"
  mkdir -p "$WORK"
  printf '%s\t%s\n' "$(date '+%H:%M')" "$(printf '%s' "$*" | tr '\t\n|' '  /')" >>"$NOTES"
  echo "noted"
}

# mark <label>: a point in time the spike log summary splits at (a widget style, a click).
step_mark() {
  [ $# -eq 1 ] || fail "usage: $SCRIPT mark <label>"
  case "$1" in *[!A-Za-z0-9._-]*) fail "a mark is letters, digits, dots, dashes and underscores" ;; esac
  mkdir -p "$WORK"
  printf '%s\t%s\t%s\n' "$(now_ms)" "$(clock)" "$1" >>"$MARKS"
  # Session B's away: no sound or speech from here until his morning continue (WP-21).
  if [ "$SESSION" = B ] && [ "$1" = away ]; then
    clock >"$WORK/away"
    if [ "$(cut -f3 <<<"$(shot_state)")" != none ]; then
      warn "BatteryPulse remembers an iPhone or iPad by name (WP-23's check): $SCRIPT devices forget, or no picture taken from now on is attached"
    fi
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

# open_app: the installed app without the windows its saved state would reopen. The main window's
# scene keeps state restoration, so a window left open at a quit (step 8 leaves it open) would
# come back at every launch and run through the energy runs; the argument holds for this launch
# only and changes no setting.
open_app() { open "$APP" --args -ApplePersistenceIgnoreState YES; }

launch() {
  open_app
  local tries=0
  until app_running || [ "$tries" -ge 40 ]; do
    sleep 0.25
    tries=$((tries + 1))
  done
  app_running || warn "BatteryPulse didn't start within 10 s"
}

set_default() { defaults write "$BUNDLE_ID" "$1" "$2" "$3"; }

# The settings every step starts from (restore puts yours back): no update checks, the menu bar item
# with the icon and the charge, the Developer section (Raw Data, Demo Mode), the main window, no
# iPhone and iPad reads.
session_settings() {
  set_default updateFrequency -string never
  set_default showInMenuBar -bool true
  set_default showDeveloperSection -bool true
  set_default menuBarShowsIcon -bool true
  set_default menuBarShowsCharge -bool true
  set_default menuBarShowsPower -bool false
  set_default menuBarShowsTemperature -bool false
  set_default prefersCompactWindow -bool false
  # Off, the default: F5 turns device reads on for its own step only, so no energy run watches USB.
  set_default readDevices -bool false
  # Session B alternates the RC, built as 0.5.99, with 0.6.1, whose What's New (0.6.0) opens at
  # every launch after a 0.5.99 one (lastSeen 0.5.99 < 0.6.0 <= 0.6.1): a window that keeps B out
  # of App Nap and inflates every B figure. The installed build's version counts as seen, which also
  # skips the launch-time end of the previous extension (install_build ended it already).
  if [ "$SESSION" = B ] && [ -f "$APP/Contents/Info.plist" ]; then
    set_default lastSeenVersion -string "$(plist_value "$APP/Contents/Info.plist" CFBundleShortVersionString)"
  fi
}

relaunch_with_session_settings() {
  quit_app
  session_settings
  launch
}

on_battery() {
  case "$(pmset -g batt)" in
    *"'Battery Power'"*) return 0 ;;
    *) return 1 ;;
  esac
}

battery_percent() { pmset -g batt | grep -o -E '[0-9]+%' | head -1 | tr -d % || true; }

# lowpowermode_of <Battery|AC>: Low Power Mode for that source from `pmset -g custom`.
lowpowermode_of() {
  pmset -g custom | awk -v source="$1" '
    /Power:$/ { section = $1 }
    section == source && $1 == "lowpowermode" && !found { print $2; found = 1 }'
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
  MOUNT="$(mktemp -d "${TMPDIR:-/tmp}/bp-062-mount.XXXXXX")"
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

# fetch_artifact <name> <run id> <artifact> <dmg file name>: builds/<name>.dmg, with
# `gh run download`. An expired artifact (ci.yml sets no retention: 90 days) comes back from a new
# CI run of the same commit's branch, with a new run number.
fetch_artifact() {
  local name="$1" run="$2" artifact="$3" file="$4" dir dmg
  dir="$BUILDS/$name.download"
  rm -rf "$dir"
  mkdir -p "$dir"
  gh run download "$run" -R "$REPO" -n "$artifact" -D "$dir" ||
    fail "can't download $artifact of run $run (expired? a new CI run of its branch makes a new one)"
  dmg="$(find "$dir" -name "$file" -type f | head -1 || true)"
  [ -n "$dmg" ] || fail "$artifact of run $run has no $file"
  mv "$dmg" "$BUILDS/$name.dmg"
  rm -rf "$dir"
  describe_build "$name" "run $run, artifact $artifact"
}

fetch_builds() {
  mkdir -p "$BUILDS"
  [ -f "$BUILDS/C.dmg" ] || fetch_artifact C "$RUN_C" "$ARTIFACT_C" BatteryPulse.dmg
  [ -f "$BUILDS/I.dmg" ] || fetch_artifact I "$RUN_I" "$ARTIFACT_I" BatteryPulse.dmg
  [ -f "$BUILDS/W.dmg" ] || fetch_artifact W "$RUN_W" "$ARTIFACT_W" BatteryPulse.dmg
  [ -f "$BUILDS/W2.dmg" ] || fetch_artifact W2 "$RUN_W2" "$ARTIFACT_W2" BatteryPulse.dmg
  [ -f "$BUILDS/A2.dmg" ] || fetch_artifact A2 "$RUN_A2" "$ARTIFACT_A2" BatteryPulse.dmg
  [ -f "$BUILDS/A2P.dmg" ] || fetch_artifact A2P "$RUN_A2" "$ARTIFACT_A2P" BatteryPulse-profiling.dmg
  [ -f "$BUILDS/A.dmg" ] || fetch_artifact A "$RUN_A" "$ARTIFACT_A" BatteryPulse.dmg
  if [ ! -f "$BUILDS/B.dmg" ]; then
    rm -rf "$BUILDS/B.download"
    mkdir -p "$BUILDS/B.download"
    gh release download "$TAG_B" -R "$REPO" -p BatteryPulse.dmg -D "$BUILDS/B.download" ||
      fail "can't download the $TAG_B DMG"
    mv "$BUILDS/B.download/BatteryPulse.dmg" "$BUILDS/B.dmg"
    rm -rf "$BUILDS/B.download"
    describe_build B "release $TAG_B"
  fi
}

# install_build <name|backup> [--no-launch]: the build's app into /Applications the way
# UpdateInstaller does it (WP-W0 "Install"): a copy staged on the same volume, its bundle ID and code
# signature checked, one atomic swap with the installed copy (swap.swift), the old copy deleted once
# it has quit, lsregister -f, a relaunch. WidgetKit caches by CFBundleVersion, so a build whose
# number isn't higher than the installed one is refused, except the reinstall of 0.6.1 (B, or your
# backed-up 0.6.1) and restore's reinstall of your own app. The order of the steps keeps every other
# install higher: C < I < W, then 0.6.1, A2, 0.6.1 again before A2's profiling build and before
# every A of the window, which is higher than 0.6.1. The same build twice is skipped. An app whose
# version equals the last one launched doesn't end the previous widget extension itself
# (WidgetRefresher.endPreviousExtension runs on a version change), so the script ends it then.
install_build() {
  local name="$1" launch_after=1 staging staged bundle version build installed last_seen why="higher"
  if [ "${2:-}" = --no-launch ]; then launch_after=0; fi
  mkdir -p "$WORK"
  if [ "$name" != backup ] && [ "$(cat "$WORK/installed" 2>/dev/null || true)" = "$name $(installed_build)" ]; then
    echo "$name is installed already: $(app_version)"
    if [ "$launch_after" = 1 ] && ! app_running; then launch; fi
    return 0
  fi
  staging="$(mktemp -d "$WORK/stage.XXXXXX")"
  staged="$staging/BatteryPulse.app"
  if [ "$name" = backup ]; then
    [ -f "$BACKUP/BatteryPulse.zip" ] || fail "no backup of your app in $BACKUP"
    ditto -x -k "$BACKUP/BatteryPulse.zip" "$staging"
  else
    [ -f "$BUILDS/$name.dmg" ] || fail "build $name is missing; run $SCRIPT prepare"
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
    # Your own app comes back regardless: restore must not stop before your settings and data.
    if [ "$name" != backup ]; then
      rm -rf "$staging"
      fail "$name's code signature doesn't verify"
    fi
    warn "your backed-up app's code signature doesn't verify; restore puts it back anyway"
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
    if [ "$version" = 0.6.1 ] && { [ "$name" = B ] || [ "$name" = backup ]; }; then
      why="the 0.6.1 reinstall"
    elif [ "$name" = backup ]; then
      why="restore puts your app back"
    else
      rm -rf "$staging"
      fail "refusing $name: its build $build isn't higher than the installed $installed, and WidgetKit caches by it; install 0.6.1 first ($SCRIPT install B)"
    fi
    echo "note: $name's build $build isn't higher than the installed $installed: $why"
  fi
  if [ "$(stat -f %d "$staging")" != "$(stat -f %d /Applications)" ]; then
    warn "the staging folder may not be on the volume of /Applications; the swap says if it isn't"
  fi
  # Before the swap, so chronod asks the new extension for the descriptors (see above).
  end_widget_extension_and_wait
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
  printf '%s\t%s\t%s (%s)\t%s\n' "$(clock)" "$name" "$version" "$build" "$why" >>"$WORK/installs.tsv"
  if [ "$launch_after" = 1 ]; then launch; fi
  echo "installed $name: $(app_version)"
}

step_install() {
  if [ "$SESSION" = B ]; then
    [ $# -eq 1 ] || fail "usage: $SCRIPT install <B|C|CP|backup>"
    case "$1" in B | C | CP | backup) ;; *) fail "no build $1 in Session B" ;; esac
    install_build "$1"
    return 0
  fi
  [ $# -eq 1 ] || fail "usage: $SCRIPT install <C|I|W|W2|B|A2|A2P|A|backup>"
  case "$1" in C | I | W | W2 | B | A2 | A2P | A | backup) ;; *) fail "no build $1" ;; esac
  install_build "$1"
}

installed_build() { plist_value "$APP/Contents/Info.plist" CFBundleVersion; }

# MARK: - Tools

tools_need_build() { [ ! -x "$BIN/$1" ] || [ "$2" -nt "$BIN/$1" ]; }

build_tools() {
  mkdir -p "$BIN"
  local tool
  for tool in perf-stats rusage; do
    if tools_need_build "$tool" "$ROOT/scripts/$tool.swift"; then
      echo "building scripts/$tool.swift..."
      xcrun swiftc -O "$ROOT/scripts/$tool.swift" -o "$BIN/$tool" 2>"$BIN/$tool.log" ||
        fail "can't build scripts/$tool.swift; see $BIN/$tool.log"
    fi
  done
  if tools_need_build swap "$HERE/swap.swift"; then
    echo "building swap.swift..."
    xcrun swiftc -O "$HERE/swap.swift" -o "$BIN/swap" 2>"$BIN/swap.log" ||
      fail "can't build swap.swift, which every install needs; see $BIN/swap.log"
  fi
  if tools_need_build frames "$HERE/frames.swift"; then
    echo "building frames.swift..."
    if ! xcrun swiftc -O "$HERE/frames.swift" -o "$BIN/frames" 2>"$BIN/frames.log"; then
      rm -f "$BIN/frames"
      warn "frames.swift didn't build (see $BIN/frames.log): step 6 then needs the recordings watched in QuickTime Player"
    fi
  fi
  if [ "$SESSION" = B ] && tools_need_build ui "$HERE/ui.swift"; then
    echo "building ui.swift..."
    if ! xcrun swiftc -O "$HERE/ui.swift" -o "$BIN/ui" 2>"$BIN/ui.log"; then
      rm -f "$BIN/ui"
      warn "ui.swift didn't build (see $BIN/ui.log): every ui step is not checked"
    fi
  fi
  if [ ! -x "$BIN/bpulse" ]; then
    echo "building bpulse (release; Package.swift needs Swift tools 6.4)..."
    if (cd "$ROOT" && xcrun swift build -c release --product bpulse) >"$BIN/bpulse.log" 2>&1; then
      cp "$(cd "$ROOT" && xcrun swift build -c release --product bpulse --show-bin-path)/bpulse" "$BIN/bpulse"
    else
      warn "bpulse didn't build (see $BIN/bpulse.log); F5 records pmset alone"
    fi
  fi
}

perf_stats() { "$BIN/perf-stats" "$@"; }

rusage() { "$BIN/rusage" "$@"; }

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

ready_count() { grep -c -F 'perf event menuBarReady' "$1" || true; }

# ready_after <capture> <ms>: from <ms> to the first menuBarReady logged after it, by the line's own
# timestamp; "-" if none.
ready_after() {
  local line stamp ms
  while IFS= read -r line; do
    stamp="$(sed -n 's/.*"timestamp" *: *"\([^"]*\)".*/\1/p' <<<"$line")"
    [ -n "$stamp" ] || continue
    ms="$(stamp_ms "$stamp")"
    if [ "$ms" -ge "$2" ]; then
      echo $((ms - $2))
      return 0
    fi
  done < <(grep -F 'perf event menuBarReady' "$1" || true)
  echo -
}

# app_reads <capture>: the app's read lines (the widget's name BatteryPulseWidget).
app_reads() { grep -F 'perf interval read ms=' "$1" | grep -c -v -F BatteryPulseWidget || true; }

# read_threads <capture>: per app process, its read lines on the main thread (the thread of its
# menuBarReady event) and off it. E20 moves every read but the launch and manual ones off it.
read_threads() {
  awk '
    function field(line, name,    rest) {
      if (!match(line, "\"" name "\" *: *[0-9]+")) return ""
      rest = substr(line, RSTART, RLENGTH)
      sub(/.*: */, "", rest)
      return rest
    }
    FNR == NR {
      if (index($0, "perf event menuBarReady") && index($0, "BatteryPulseWidget") == 0)
        main[field($0, "processID")] = field($0, "threadID")
      next
    }
    index($0, "perf interval read ms=") && index($0, "BatteryPulseWidget") == 0 {
      pid = field($0, "processID")
      if (!(pid in main)) unknown[pid]++
      else if (field($0, "threadID") == main[pid]) onmain[pid]++
      else offmain[pid]++
      seen[pid] = 1
    }
    END {
      for (pid in seen)
        printf "process %s: %d reads on the main thread, %d off it, %d before its main thread was known\n",
          pid, onmain[pid] + 0, offmain[pid] + 0, unknown[pid] + 0
    }' "$1" "$1"
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

# messages <ndjson>: "<time of day> <process> <message>" per entry, for reading and for A.md.
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
  if [ "$SESSION" = B ]; then log_shot_state "$SHOTS/$name.png" "$(shot_state)"; fi
  sips -Z 1600 -s format jpeg -s formatOptions 70 "$SHOTS/$name.png" --out "$SHOTS/$name-view.jpg" >/dev/null
  echo "SHOT $SHOTS/$name-view.jpg (full size: $SHOTS/$name.png)"
}

step_shot() {
  [ $# -eq 1 ] || fail "usage: $SCRIPT shot <name>"
  shot "$1"
}

# attach <image> <caption>: a copy of the image, at most 1200 px and about 300 KB as JPEG, for A.md.
step_attach() {
  [ $# -ge 2 ] || fail "usage: $SCRIPT attach <image> <caption>"
  local image="$1" caption name out_file count
  shift
  caption="$*"
  [ -f "$image" ] || fail "no image $image"
  english_only "$caption"
  if [ "$SESSION" = B ]; then attach_allowed "$image"; fi
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
  if [ "$SESSION" = B ]; then register_shot "$SHOTS/$6.png" "$1"; fi
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

# A fresh backup into ~/bp-062/A/backup; a second prepare keeps it unless asked for a fresh one.
backup() {
  if [ -f "$BACKUP/done" ] && [ "${1:-}" != --fresh-backup ]; then
    echo "keeping the backup of $(cat "$BACKUP/done") in $BACKUP (prepare --fresh-backup takes a new one)"
    return 0
  fi
  [ -d "$APP" ] || fail "$APP is missing: install 0.6.1 first, so the session has your app to come back to"
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
  wallpapers >"$BACKUP/wallpapers"
  pmset -g custom >"$BACKUP/pmset-custom.txt"
  lowpowermode_of Battery >"$BACKUP/lowpowermode-battery"
  lowpowermode_of AC >"$BACKUP/lowpowermode-ac"
  if defaults read "$WIDGET_PREFS" AppleLanguages >"$BACKUP/widget-languages" 2>/dev/null; then :; else
    rm -f "$BACKUP/widget-languages"
  fi
  clock >"$BACKUP/done"
  echo "backed up $(cat "$BACKUP/version"), your settings and data to $BACKUP"
}

step_prepare() {
  check_tools
  mkdir -p "$WORK" "$BUILDS" "$BIN" "$SHOTS" "$REC" "$LOGS" "$SECTIONS"
  cd "$ROOT"
  echo "macOS may ask whether this app may control BatteryPulse and System Events, and may record the screen: allow each."
  backup "${1:-}"
  if [ ! -f "$WORK/prepare.time" ] || [ "${1:-}" = --fresh-backup ]; then
    clock >"$WORK/prepare.time"
    touch "$WORK/prepare.marker"
  fi
  fetch_builds
  build_tools

  begin_section 00-prepare "Prepare"
  out "- prepared: $(cat "$WORK/prepare.time"); macOS $(sw_vers -productVersion) ($(sw_vers -buildVersion)); script at $(git -C "$ROOT" rev-parse --short HEAD 2>/dev/null || echo unknown)"
  out "- installed before the session: $(cat "$BACKUP/version")"
  out "- defaults domain: $(plutil -convert xml1 -o - "$BACKUP/defaults.plist" | grep -c '<key>' || true) keys backed up"
  if [ -d "$BACKUP/support" ]; then
    out "- Application Support: $(find "$BACKUP/support" -type f | wc -l | tr -d ' ') files, $(du -sk "$BACKUP/support" | cut -f1) KB backed up"
  else
    out "- Application Support: none"
  fi
  out "- appearance: dark mode $(cat "$BACKUP/dark-mode"), automatic $(cat "$BACKUP/auto-appearance"); wallpapers: $(grep -c . "$BACKUP/wallpapers" || true)"
  out "- Low Power Mode: battery $(cat "$BACKUP/lowpowermode-battery"), adapter $(cat "$BACKUP/lowpowermode-ac")"
  out "- widget extension's AppleLanguages: $(if [ -f "$BACKUP/widget-languages" ]; then tr -s ' \n' ' ' <"$BACKUP/widget-languages"; else echo none; fi)"
  out "- charge: $(battery_percent) %, $(if on_battery; then echo on battery; else echo on the adapter; fi); cycle count $(ioreg -r -c AppleSmartBattery | awk -F' = ' '$1 ~ /"CycleCount"$/ { print $2; exit }')"
  out "- kern.pervasive_energy: $(sysctl -n kern.pervasive_energy 2>/dev/null || echo unavailable)"
  out "- bpulse: $(if [ -x "$BIN/bpulse" ]; then echo built; else echo "not built"; fi)"
  out ""
  out "| Build | Version | CFBundleVersion | Source |"
  out "|---|---|---|---|"
  local name version build origin
  while IFS=$'\t' read -r name version build origin; do
    out "| $name | $version | $build | $origin |"
  done <"$WORK/builds.tsv"

  # F5 and SPIKE-C start from 0.6.1.
  case "$(app_version)" in
    "0.6.1 "*) relaunch_with_session_settings ;;
    *)
      install_build B --no-launch
      relaunch_with_session_settings
      ;;
  esac
  shot prepare-check
  echo
  echo "Look at the shot: if it shows only the wallpaper, Screen Recording isn't allowed yet."
  ask prep-widget-style prep-dim-widgets prep-open-at-login prep-widgets
  echo "DO (person): if no small and medium BatteryPulse widget is on the desktop, add them (right-click the desktop → Edit Widgets) where no window covers them."
  echo "NEXT: $SCRIPT widgets-ref"
}

step_widgets_ref() {
  begin_section 10-widgets-ref "Reference widgets (0.6.1)"
  pluginkit -mv -i "$WIDGET_ID" >"$LOGS/pluginkit-ref.txt" 2>&1 || true
  out "- installed: $(app_version)"
  out "- pluginkit:"
  out_block "$LOGS/pluginkit-ref.txt"
  shot widgets-ref
  echo "NEXT: $SCRIPT f5 start"
}

# MARK: - F5 (step 2)

# plist_split <file> <folder>: the XML property lists in <file>, which may hold several back to back
# (pmset -g accps -xml writes one per source, and plutil reads only the first), each from its XML
# header (or <plist>) to its </plist>, as <folder>/1.plist, 2.plist, ...; prints how many. Text
# outside them is dropped; a file with none (JSON, a binary plist) gives 0 and an empty folder.
plist_split() {
  rm -rf "$2"
  mkdir -p "$2"
  awk -v dir="$2" '
    {
      # One header or </plist> per line, even when a plist starts on the line the last one ends.
      gsub(/<\?xml/, "\n&")
      gsub(/<\/plist>/, "&\n")
      count = split($0, parts, "\n")
      for (i = 1; i <= count; i++) {
        line = parts[i]
        if (line ~ /<\?xml/ || (!inside && line ~ /<plist/)) {
          if (inside) close(file)
          n++
          file = dir "/" n ".plist"
          inside = 1
        }
        if (inside) print line >file
        if (inside && line ~ /<\/plist>/) {
          close(file)
          inside = 0
        }
      }
    }
    END { print n + 0 }' "$1"
}

# plist_entries <file>: the entries at the root of one property list or JSON file: an array's
# elements, 1 for a dictionary (pmset's plist for one source, even an empty one); otherwise why not.
plist_entries() {
  local root index=0
  # The XML form's fourth line is the root element.
  root="$(plutil -convert xml1 -o - "$1" 2>/dev/null | sed -n 4p)"
  case "$root" in
    "<array/>") echo 0 ;;
    "<array>")
      while plutil -extract "$index" xml1 -o /dev/null "$1" >/dev/null 2>&1; do index=$((index + 1)); done
      echo "$index"
      ;;
    "<dict>" | "<dict/>") echo 1 ;;
    "") echo "unreadable" ;;
    *) echo "not a list" ;;
  esac
}

# plist_count <file>: the entries of every property list in <file> (plist_entries of each piece
# plist_split finds, kept beside it in <its name without the extension>-parts), or of the whole
# file when it holds no XML property list (bpulse's JSON array). A piece that doesn't read is named
# after the sum.
plist_count() {
  local name="${1##*/}" parts pieces index=1 entries total=0 bad=""
  # From the file's name only, so a dot in a folder's name can't move the folder rm -rf empties.
  parts="$(dirname "$1")/${name%.*}-parts"
  if [ ! -s "$1" ]; then
    echo "no output"
    return 0
  fi
  pieces="$(plist_split "$1" "$parts")" || pieces=""
  case "$pieces" in
    "" | *[!0-9]*)
      echo "unreadable (not split)"
      return 0
      ;;
    0)
      rm -rf "$parts"
      plist_entries "$1"
      return 0
      ;;
  esac
  while [ "$index" -le "$pieces" ]; do
    entries="$(plist_entries "$parts/$index.plist")"
    case "$entries" in
      "" | *[!0-9]*) bad="${bad:+$bad, }plist $index $entries" ;;
      *) total=$((total + entries)) ;;
    esac
    index=$((index + 1))
  done
  if [ -n "$bad" ]; then echo "$total ($bad)"; else echo "$total"; fi
}

step_f5() {
  case "${1:-}" in
    start)
      begin_section 20-f5 "F5, accessories and devices (0.6.1)"
      clock >"$WORK/f5.time"
      case "$(app_version)" in "0.6.1 "*) ;; *) install_build B --no-launch ;; esac
      quit_app
      session_settings
      set_default readDevices -bool true
      launch
      out "- app: $(app_version), reading iPhones and iPads on"
      out "- bpulse: $(if [ -x "$BIN/bpulse" ]; then echo built; else echo "not built: pmset only"; fi)"
      out ""
      out "| State | pmset -g accps sources | bpulse --accessories (JSON entries) |"
      out "|---|---|---|"
      echo "DO (person), one state at a time, then $SCRIPT f5 capture <state>:"
      echo "  keyboard-bluetooth, keyboard-cable (a keyboard on Bluetooth, then on its cable),"
      echo "  earbuds-out (out of the case, in the ears), earbuds-in-case (in the case, lid open)."
      echo "DO (person), if an iPhone is at hand: connect it with a cable, answer the prompts on the iPhone and the Mac,"
      echo "  open BatteryPulse's main window → the iPhone's page (session: $SCRIPT shot f5-iphone-attached);"
      echo "  then unplug it (session: $SCRIPT shot f5-iphone-detached). Then $SCRIPT f5 end"
      ;;
    capture)
      local state="${2:-}"
      case "$state" in "" | *[!a-z0-9-]*) fail "usage: $SCRIPT f5 capture <state> (lowercase, digits, dashes)" ;; esac
      use_section 20-f5 "F5, accessories and devices (0.6.1)"
      # Only standard output goes to the XML file, so a warning can't land between its plists.
      pmset -g accps -xml >"$LOGS/f5-$state-pmset.xml" 2>"$LOGS/f5-$state-pmset.err" || true
      local bpulse_count="not built"
      if [ -x "$BIN/bpulse" ]; then
        "$BIN/bpulse" --accessories --raw >"$LOGS/f5-$state-bpulse-raw.plist" 2>"$LOGS/f5-$state-bpulse.err" || true
        "$BIN/bpulse" --accessories --json >"$LOGS/f5-$state-bpulse.json" 2>>"$LOGS/f5-$state-bpulse.err" || true
        bpulse_count="$(plist_count "$LOGS/f5-$state-bpulse.json")"
      fi
      out "| $state | $(plist_count "$LOGS/f5-$state-pmset.xml") | $bpulse_count |"
      echo "The captures are in $LOGS (f5-$state-*; pmset's plists one per file in f5-$state-pmset-parts);"
      echo "  they name your devices, so they stay on this Mac."
      ;;
    end)
      use_section 20-f5 "F5, accessories and devices (0.6.1)"
      local count
      out ""
      count="$(log_since "$(cat "$WORK/f5.time")" "subsystem == \"$BUNDLE_ID\" AND category == \"device\"" "$LOGS/f5-device.ndjson")"
      out "- device log lines since f5 start: $count (names, serials and UDIDs read back as <private>)"
      if [ "$count" -gt 0 ]; then
        messages "$LOGS/f5-device.ndjson" | head -40 >"$LOGS/f5-device.txt"
        out_block "$LOGS/f5-device.txt"
      fi
      count="$(log_since "$(cat "$WORK/f5.time")" 'eventMessage CONTAINS[c] "BatteryPulse" AND (eventMessage CONTAINS[c] "library validation" OR eventMessage CONTAINS[c] "not valid for use in process")' "$LOGS/f5-validation.ndjson")"
      out "- library validation messages naming BatteryPulse: $count"
      quit_app
      session_settings
      launch
      ask F5-accessories F5-iphone F5-local-network F5-attach-detach
      echo "Judge F5-accessories from the captures in $LOGS (read them; don't publish names)."
      echo "NEXT: $SCRIPT spike c"
      ;;
    *) fail "usage: $SCRIPT f5 start | capture <state> | end" ;;
  esac
}

# MARK: - Widget spikes (step 3)

spike_install() {
  local name="$1" label="$2" section="$3"
  begin_section "$section" "$label"
  pluginkit -mv -i "$WIDGET_ID" >"$LOGS/pluginkit-before-$name.txt" 2>&1 || true
  out "- before: $(app_version)"
  out_block "$LOGS/pluginkit-before-$name.txt"
  install_build "$name" --no-launch
  quit_app
  session_settings
  launch
  clock >"$WORK/spike-$name.time"
  echo "waiting 30 s for WidgetKit to redraw..."
  sleep 30
  pluginkit -mv -i "$WIDGET_ID" >"$LOGS/pluginkit-after-$name.txt" 2>&1 || true
  out "- after: $(app_version)"
  out_block "$LOGS/pluginkit-after-$name.txt"
  case "$(cat "$LOGS/pluginkit-after-$name.txt")" in
    *"$APP"*) out "- the widget runs from /Applications" ;;
    *) out "- the widget is NOT registered from /Applications" ;;
  esac
  shot "widgets-$name"
}

step_spike() {
  case "${1:-}" in
    c)
      spike_install C "SPIKE-C over 0.6.1 (W0-2's control)" 30-spike-c
      echo "Compare with $SHOTS/widgets-ref-view.jpg."
      ask W0-2-C
      echo "NEXT: $SCRIPT spike i"
      ;;
    i)
      spike_install I "SPIKE-I over SPIKE-C (-internalize-at-link)" 31-spike-i
      echo "DO (person): add a large and an extra-large BatteryPulse widget to the desktop, where nothing covers them."
      echo "Then $SCRIPT shot widgets-I-all and judge every family:"
      ask W0-2-I-small W0-2-I-medium W0-2-I-large W0-2-I-xlarge
      echo "NEXT: $SCRIPT spike w"
      ;;
    w)
      spike_install W "SPIKE-W over SPIKE-I (the configurable kind, the Test kind, the feed, the click logger)" 32-spike-w
      out ""
      out "- expected in Edit Widget: Battery: Layout, Main value, Time (Details once Layout is Custom); Test widget: Main value, Details, Device (summary 'Show <main value>')"
      ask W0-2-W-small W0-2-W-medium W0-2-W-large W0-2-W-xlarge
      cat <<EOF
DO, in this order (each line: the person acts; the session marks, shoots and judges):
  1. Person: right-click the medium Battery widget → Edit "Battery". Session: $SCRIPT shot edit-battery-en, then judge W0-2-W-edit.
     Person: set Layout to Custom so Details shows; shoot again; then Layout back to Automatic, close the sheet.
  2. Person: right-click the desktop → Edit Widgets → BatteryPulse → add a small "Test widget" next to the others.
     Person: right-click it → Edit. Session: $SCRIPT shot edit-test-en, judge W0-1-test-edit. Person: closes the sheet.
  3. Person: click the Test widget's Refresh button (W0-1 c).
  4. Session: $SCRIPT shot test-widget-en; judge W0-6-format-en; then $SCRIPT spike tick (65 s), judge W0-6-tick.
  5. Rendering modes (W0-4). Person: note Icon & widget style and Dim widgets (prepare asked); set Dim widgets on desktop
     to Automatically. Then for each style Default, Dark, Clear, Tinted: session runs $SCRIPT mark desktop-<style>,
     person picks the style in System Settings → Appearance, clicks an empty spot of the desktop, then a window.
  6. Person: click the date in the menu bar → Edit Widgets, add a small BatteryPulse widget to Notification Center.
     Then for each style again, with Notification Center open: session runs $SCRIPT mark nc-<style> first.
     Person: sets both settings back to the values prepare recorded.
  7. Clicks (W0-4): session runs $SCRIPT mark click-closed; person closes every BatteryPulse window and clicks a
     desktop widget. Session runs $SCRIPT mark click-open; person opens the main window, then clicks the widget again.
  8. Russian: $SCRIPT spike ru on, then $SCRIPT spike ru off.
  9. $SCRIPT spike logs
EOF
      ask W0-2-W-edit W0-1-test-edit W0-6-format-en W0-6-tick
      ;;
    tick)
      shot test-widget-tick-1
      echo "waiting 65 s..."
      sleep 65
      shot test-widget-tick-2
      ask W0-6-tick
      ;;
    ru)
      case "${2:-}" in
        on)
          begin_section 33-spike-ru "SPIKE-W in Russian (the extension's AppleLanguages)"
          if defaults write "$WIDGET_PREFS" AppleLanguages -array ru 2>"$LOGS/spike-ru.err"; then
            out "- AppleLanguages (ru) written to the extension's container preferences; the extension ended"
            end_widget_extension
            echo "waiting 30 s for WidgetKit to start the extension again..."
            sleep 30
            shot widgets-W-ru
            echo "DO (person): right-click the medium Battery widget → Edit. Session: $SCRIPT shot edit-battery-ru, then the Test widget's line a/b."
            ask W0-2-W-ru W0-6-format-ru
          else
            out "- writing the extension's preferences failed (macOS refused access to the container): W0-2-W-ru not checked"
            step_answer --by claude W0-2-W-ru 4 "the container's preferences couldn't be written" >/dev/null
          fi
          ;;
        off)
          defaults delete "$WIDGET_PREFS" AppleLanguages 2>/dev/null || true
          if [ -f "$BACKUP/widget-languages" ]; then
            warn "the extension had its own AppleLanguages before the session; restore puts it back"
          fi
          end_widget_extension
          echo "AppleLanguages removed and the extension ended; the widgets come back in English."
          echo "NEXT: $SCRIPT spike logs"
          ;;
        *) fail "usage: $SCRIPT spike ru on|off" ;;
      esac
      ;;
    logs) spike_logs ;;
    *) fail "usage: $SCRIPT spike c | i | w | tick | ru on|off | logs" ;;
  esac
}

# The spike's log lines since SPIKE-W was installed, counted per distinct message (ages, sequence
# numbers and process IDs folded), and split at each mark.
spike_logs() {
  [ -f "$WORK/spike-W.time" ] || fail "SPIKE-W isn't installed yet: $SCRIPT spike w"
  begin_section 34-spike-logs "SPIKE-W's log lines (W0-1, W0-3, W0-4)"
  local count
  count="$(log_since "$(cat "$WORK/spike-W.time")" "$SPIKE_PREDICATE" "$LOGS/spike-w.ndjson")"
  out "- spike lines since SPIKE-W was installed: $count (static text, numbers and case names only)"
  messages "$LOGS/spike-w.ndjson" >"$LOGS/spike-w.txt"
  # "<ms>\t<process> <message>" per line, so they split at the marks.
  : >"$LOGS/spike-w-ms.txt"
  local stamp process message
  while IFS=$'\t' read -r stamp process message; do
    [ -n "$stamp" ] || continue
    printf '%s\t%s %s\n' "$(stamp_ms "$stamp")" "$process" "$message" >>"$LOGS/spike-w-ms.txt"
  done < <(entries "$LOGS/spike-w.ndjson")
  touch "$MARKS"
  # FILENAME, not FNR == NR: with no marks the marks file is empty, and FNR == NR would then take
  # every log line for a mark.
  awk -F '\t' 'FILENAME == ARGV[1] { at[++n] = $1; label[n] = $3; next }
    {
      ms = $1
      segment = "before any mark"
      for (i = 1; i <= n; i++) if (at[i] <= ms) segment = label[i]
      line = $2
      gsub(/age=[0-9]+s/, "age=Ns", line); gsub(/sequence=[0-9]+/, "sequence=N", line); gsub(/pid=[0-9]+/, "pid=N", line)
      count[segment SUBSEP line]++
      if (!(segment in order)) { order[segment] = ++segments; names[segments] = segment }
    }
    END {
      for (s = 1; s <= segments; s++) {
        print "### " names[s]
        for (key in count) {
          split(key, part, SUBSEP)
          if (part[1] == names[s]) printf "%5d  %s\n", count[key], part[2]
        }
      }
    }' "$MARKS" "$LOGS/spike-w-ms.txt" >"$LOGS/spike-w-summary.txt"
  out_block "$LOGS/spike-w-summary.txt"
  local other
  other="$(defaults read "$BUNDLE_ID" spikeOtherActivityType 2>/dev/null || echo none)"
  out "- an unknown click activity type, as the spike app stored it: $other"
  echo "Read $LOGS/spike-w.txt for the order of events."
  echo "NEXT: $SCRIPT voiceover"
}

# MARK: - VoiceOver (step 4)

step_voiceover() {
  begin_section 40-voiceover "VoiceOver and Text size on 0.6.1 (W0-5)"
  install_build B --no-launch
  quit_app
  session_settings
  launch
  out "- reinstalled: $(app_version)"
  echo "waiting 30 s for WidgetKit to redraw..."
  sleep 30
  shot widgets-061-again
  ask W0-2-reinstall
  cat <<EOF
DO (person): press Command-F5. Click an empty spot of the desktop, then press Control-Option-Right Arrow until
  VoiceOver reads a BatteryPulse widget. Remember what it says for the battery symbol. Press Command-F5 again.
DO: session runs $SCRIPT shot text-size-before; person raises System Settings → Accessibility → Display → Text size;
  session runs $SCRIPT shot text-size-after and judges; person sets Text size back.
EOF
  ask W0-5-voiceover W0-5-text-size
  echo "NEXT: $SCRIPT v01 start"
}

# MARK: - V-01 (step 5)

step_v01() {
  case "${1:-}" in
    start)
      begin_section 50-v01 "V-01 on SPIKE-A2 (WP-10, WP-14a)"
      install_build A2 --no-launch
      quit_app
      session_settings
      launch
      clock >"$WORK/v01.time"
      touch "$WORK/v01.marker"
      out "- installed: $(app_version) at $(cat "$WORK/v01.time")"
      cat <<EOF
DO (person):
  1. BatteryPulse Settings → Notifications → Send Test Notification; click the banner when it appears.
     Again with the BatteryPulse window in front.
  2. The menu bar icon with a light and a dark menu bar: session runs $SCRIPT appearance light, $SCRIPT shot menubar-light,
     $SCRIPT appearance dark, $SCRIPT shot menubar-dark, then $SCRIPT appearance back.
  3. Raw Data; History; Demo Mode on and off; Check Now (if it offers an update, close that window without installing);
     Clear History (your data is backed up).
  4. Close the lid for a minute, then open it and log in.
Then: $SCRIPT v01 check
EOF
      ;;
    check)
      use_section 50-v01 "V-01 on SPIKE-A2 (WP-10, WP-14a)"
      [ -f "$WORK/v01.marker" ] || fail "run $SCRIPT v01 start first"
      local since_prepare since_v01
      since_prepare="$(log_since "$(cat "$WORK/prepare.time")" "$EXECUTOR_PREDICATE" "$LOGS/executor-prepare.ndjson")"
      since_v01="$(log_since "$(cat "$WORK/v01.time")" "$EXECUTOR_PREDICATE" "$LOGS/executor-v01.ndjson")"
      out "- \"executor\" log lines: $since_prepare since prepare, $since_v01 since SPIKE-A2 was installed"
      if [ "$since_prepare" -gt 0 ]; then
        messages "$LOGS/executor-prepare.ndjson" | head -20 >"$LOGS/executor.txt"
        out_block "$LOGS/executor.txt"
      fi
      out "- crash reports since prepare:"
      crash_summary "$WORK/prepare.marker"
      out "- running now: $(if app_running; then echo "yes, $(app_version)"; else echo no; fi)"
      ask V01-notification V01-notification-front V01-menubar V01-pages V01-lid
      echo "NEXT: $SCRIPT fill ready clear-light"
      ;;
    *) fail "usage: $SCRIPT v01 start | check" ;;
  esac
}

step_appearance() {
  case "${1:-}" in
    light | dark) if [ "$SESSION" = B ]; then set_appearance "$1"; else appearance "$1"; fi ;;
    back)
      case "$(cat "$BACKUP/dark-mode" 2>/dev/null || echo unknown)" in
        true) appearance dark ;;
        false) appearance light ;;
        *) warn "prepare didn't record the appearance" ;;
      esac
      ;;
    *) fail "usage: $SCRIPT appearance light|dark|back" ;;
  esac
  echo "appearance: $(is_dark | sed 's/true/dark/; s/false/light/')"
}

# MARK: - Clear's fill (step 6)

# The cases: Clear Light, Clear Dark and Translucent Dark on fill (b) for Clear (FILL_VALUE), and,
# only when Translucent Dark shows the frame (a 2), Translucent Dark again with fill (b) extended to
# it (FILL_VALUE_TD), the check of WP-13 item 1's extension.
FILL_CASES="clear-light clear-dark translucent-dark translucent-dark-b"
FILL_SECONDS=6

fill_case() {
  case "${1:-}" in
    clear-light | clear-dark | translucent-dark | translucent-dark-b) ;;
    *) fail "the cases are $FILL_CASES" ;;
  esac
}

fill_look() { echo "${1%%-*}"; }

fill_appearance() {
  local rest="${1#*-}"
  echo "${rest%%-*}"
}

fill_value() { if [ "$1" = translucent-dark-b ]; then echo "$FILL_VALUE_TD"; else echo "$FILL_VALUE"; fi; }

# record_clip <movie> <seconds>: a sound, then the screen for <seconds> (screencapture -v), then a
# second sound. This is the script's only screen recording. screencapture -v keeps the movie only
# when it stops by itself at -V: SIGINT, a typed character or the end of its standard input stops
# it too, and loses the movie (Session A). So it always runs with -V, its standard input is a FIFO
# this shell holds open, with nothing written, until it has exited (a background job's would be
# /dev/null, whose end of input comes at once), and it is waited for, never interrupted.
record_clip() {
  local movie="$1" seconds="$2" fifo="$REC/record.fifo" pid tries=0 limit
  case "$seconds" in "" | 0* | *[!0-9]*) fail "record_clip: -V takes a whole number of seconds above 0, not '$seconds'" ;; esac
  rm -f "$movie" "$fifo"
  mkfifo "$fifo"
  afplay /System/Library/Sounds/Glass.aiff &
  screencapture -v -V "$seconds" -x "$movie" <"$fifo" &
  pid=$!
  # Opening the writing end lets screencapture's redirection finish; fd 3 stays open until it exits.
  exec 3>"$fifo"
  # The movie is written after the -V seconds: give the start and the write a minute.
  limit=$(((seconds + 60) * 2))
  while kill -0 "$pid" 2>/dev/null && [ "$tries" -lt "$limit" ]; do
    sleep 0.5
    tries=$((tries + 1))
  done
  if kill -0 "$pid" 2>/dev/null; then
    # A hung recorder only: -V passed a minute ago, and the movie is lost either way. SIGKILL
    # after SIGTERM, so the wait below can't hang.
    warn "screencapture didn't stop by itself $((seconds + 60)) s after it started; ending it"
    kill -TERM "$pid" 2>/dev/null || true
    sleep 2
    kill -KILL "$pid" 2>/dev/null || true
  fi
  wait "$pid" 2>/dev/null || true
  exec 3>&-
  rm -f "$fifo"
  afplay /System/Library/Sounds/Pop.aiff || true
  [ -s "$movie" ] || fail "no recording: allow Screen Recording for this app (System Settings → Privacy & Security), then record again"
}

# fill_frames <case>: each clip's frames, contact sheet and numbers, and a line for A.md.
fill_frames() {
  local case_name="$1" phase movie folder darkest
  [ -x "$BIN/frames" ] || fail "the frame helper isn't built (see $BIN/frames.log): open the recordings in QuickTime Player ($REC) instead"
  use_section 60-fill "Clear's minimize fill on SPIKE-A2 (WP-13, Q-B2)"
  for phase in minimize restore; do
    movie="$REC/$case_name-$phase.mov"
    folder="$REC/$case_name-$phase-frames"
    [ -s "$movie" ] || fail "record it first: $SCRIPT fill record $case_name"
    rm -rf "$folder"
    "$BIN/frames" dump "$movie" "$folder" 0.2 1280
    darkest="$(tail -n +2 "$folder/frames.tsv" | sort -t "$(printf '\t')" -k4 -n -r | head -1 |
      awk -F '\t' '{ printf "frame %s at %s s, %s %% dark pixels", $1, $2, $4 }' || true)"
    out "- $case_name, $phase: $FILL_SECONDS s, $(($(wc -c <"$movie") / 1024)) KB (kept on the Mac); $(($(wc -l <"$folder/frames.tsv") - 1)) frames at 0.2 s; darkest: $darkest"
    echo "LOOK $folder/sheet.png (then the frames it names, in $folder)"
  done
}

step_fill() {
  local case_name="${2:-}" value
  case "${1:-}" in
    ready)
      fill_case "$case_name"
      value="$(fill_value "$case_name")"
      install_build A2 --no-launch
      use_section 60-fill "Clear's minimize fill on SPIKE-A2 (WP-13, Q-B2)"
      # The switch is read at launch: quit first, write, then launch.
      quit_app
      session_settings
      set_default betaWindowStyles -bool true
      set_default windowLook -string "$(fill_look "$case_name")"
      set_default "$FILL_KEY" -string "$value"
      appearance "$(fill_appearance "$case_name")"
      launch
      echo "Fill: $FILL_KEY = $value; window style $(fill_look "$case_name"), $(fill_appearance "$case_name") appearance."
      echo "DO (person): open BatteryPulse's main window (menu bar item → Open BatteryPulse) in the middle of the"
      echo "  screen, away from the Dock. Reduce Transparency and Increase Contrast must be off (they give Standard)."
      echo "  At the first sound: hold Shift and click the yellow button (the slow minimize)."
      echo "  At the next sound: hold Shift and click the window's icon in the Dock (the slow restore)."
      echo "NEXT: $SCRIPT fill record $case_name"
      ;;
    record)
      fill_case "$case_name"
      mkdir -p "$REC"
      echo "minimize: Shift-click the yellow button at the sound ($FILL_SECONDS s)"
      record_clip "$REC/$case_name-minimize.mov" "$FILL_SECONDS"
      sleep 2
      echo "restore: Shift-click the window's Dock icon at the sound ($FILL_SECONDS s)"
      record_clip "$REC/$case_name-restore.mov" "$FILL_SECONDS"
      fill_frames "$case_name"
      echo "Look at each sheet, then at the frames it names, and judge (a clip that missed the animation: record again):"
      ask "fill-$case_name"
      case "$case_name" in
        clear-light) echo "NEXT: $SCRIPT fill ready clear-dark" ;;
        clear-dark) echo "NEXT: $SCRIPT fill ready translucent-dark" ;;
        translucent-dark)
          echo "NEXT: if fill-translucent-dark is 2, $SCRIPT fill ready translucent-dark-b (fill (b) extended to it);"
          echo "  otherwise $SCRIPT fill done"
          ;;
        translucent-dark-b) echo "NEXT: $SCRIPT fill done" ;;
      esac
      ;;
    frames)
      fill_case "$case_name"
      fill_frames "$case_name"
      ;;
    done)
      quit_app
      defaults delete "$BUNDLE_ID" "$FILL_KEY" 2>/dev/null || true
      session_settings
      step_appearance back
      launch
      echo "NEXT: $SCRIPT attach-timing"
      ;;
    *) fail "usage: $SCRIPT fill ready|record|frames <case> | fill done; cases: $FILL_CASES" ;;
  esac
}

# MARK: - Attach timing (step 7)

# timed <error file> <command...>: the command's wall time in ms, or "failed" with its error output
# kept in the file.
timed() {
  local errors="$1" start end
  shift
  start="$(now_ms)"
  if "$@" >/dev/null 2>"$errors.tmp"; then
    end="$(now_ms)"
    echo $((end - start))
  else
    mv "$errors.tmp" "$errors"
    echo failed
  fi
  rm -f "$errors.tmp"
}

detach_quietly() {
  diskutil eject "$1" >/dev/null 2>&1 || hdiutil detach -quiet -force "$1" >/dev/null 2>&1 || true
}

step_attach_timing() {
  [ -f "$BUILDS/B.dmg" ] || fail "the 0.6.1 DMG is missing: $SCRIPT prepare"
  begin_section 70-attach-timing "Attach timing on the real 0.6.1 DMG (SEC-15, WP-16)"
  local dmg="$BUILDS/B.dmg" point skip="" round variant ms errors
  diskutil image attach >"$LOGS/diskutil-image-attach-usage.txt" 2>&1 || true
  diskutil image >"$LOGS/diskutil-image-usage.txt" 2>&1 || true
  diskutil eject >"$LOGS/diskutil-eject-usage.txt" 2>&1 || true
  skip="$(grep -o -E -- '-{1,2}[A-Za-z]*([Nn]o[Vv]erify|[Ss]kip[A-Za-z]*[Vv]erif[A-Za-z]*)' "$LOGS/diskutil-image-attach-usage.txt" | head -1 || true)"
  point="$(mktemp -d "${TMPDIR:-/tmp}/bp-062-timing.XXXXXX")"
  : >"$LOGS/attach-times.tsv"
  rm -f "$LOGS"/attach-*.err
  # One attach first, not counted, so every variant reads a warm file.
  if hdiutil attach -quiet -nobrowse -readonly -noautoopen -mountpoint "$point" "$dmg"; then detach_quietly "$point"; fi
  for round in 1 2 3 4 5; do
    for variant in hdiutil hdiutil-noverify diskutil diskutil-skip; do
      mkdir -p "$point"
      errors="$LOGS/attach-$variant.err"
      case "$variant" in
        hdiutil) ms="$(timed "$errors" hdiutil attach -quiet -nobrowse -readonly -noautoopen -mountpoint "$point" "$dmg")" ;;
        hdiutil-noverify)
          ms="$(timed "$errors" hdiutil attach -quiet -nobrowse -readonly -noautoopen -noverify -mountpoint "$point" "$dmg")"
          ;;
        diskutil)
          ms="$(timed "$errors" diskutil image attach --mountOptions nobrowse --readOnly --mountPoint "$point" "$dmg")"
          ;;
        diskutil-skip)
          if [ -z "$skip" ]; then ms="no option"; else
            ms="$(timed "$errors" diskutil image attach --mountOptions nobrowse --readOnly "$skip" --mountPoint "$point" "$dmg")"
          fi
          ;;
      esac
      detach_quietly "$point"
      printf '%s\t%s\t%s\n' "$variant" "$round" "$ms" >>"$LOGS/attach-times.tsv"
    done
  done
  rmdir "$point" 2>/dev/null || true
  out "- verification skip in diskutil's usage: ${skip:-none found}"
  out ""
  out "| Variant | Runs (ms) | Median ms |"
  out "|---|---|---|"
  for variant in hdiutil hdiutil-noverify diskutil diskutil-skip; do
    out "| $variant | $(awk -F '\t' -v v="$variant" '$1 == v { printf "%s%s", sep, $3; sep = ", " }' "$LOGS/attach-times.tsv") | $(awk -F '\t' -v v="$variant" '$1 == v && $3 ~ /^[0-9]+$/ { print $3 }' "$LOGS/attach-times.tsv" | median) |"
  done
  out ""
  out "- attaches left over: $(hdiutil info | grep -c -F "$dmg" || true)"
  for errors in "$LOGS"/attach-*.err; do
    [ -f "$errors" ] || continue
    out "- the last failure of $(basename "$errors" .err | sed 's/^attach-//'):"
    out_block "$errors"
  done
  out "- diskutil image attach usage:"
  out_block "$LOGS/diskutil-image-attach-usage.txt"
  out "- diskutil eject usage:"
  out_block "$LOGS/diskutil-eject-usage.txt"
  echo "NEXT: $SCRIPT pages"
}

# MARK: - Page switches (step 8)

# cue_pages <rounds> <seconds>: names each page aloud and in a notification, <rounds> times.
cue_pages() {
  local round entry label
  for round in $(seq 1 "$1"); do
    for entry in $PAGES; do
      label="${entry%%:*}"
      label="${label//_/ }"
      osascript -e "display notification \"$label ($round of $1)\" with title \"Click this page\"" >/dev/null 2>&1 || true
      say "$label" 2>/dev/null || true
      sleep "$2"
    done
  done
}

# page_counts <capture>: page.switch lines per page.
page_counts() {
  local entry name count
  for entry in $PAGES; do
    name="${entry#*:}"
    count="$(grep -c -E "perf interval page\\.switch ms=[0-9.]+ trigger=$name\"" "$1" || true)"
    printf '%s %s\n' "$name" "$count"
  done
}

step_pages() {
  local profiling="${1:-}" capture
  case "$profiling" in
    "")
      install_build A2
      begin_section 80-pages "Page switches on SPIKE-A2 (WP-17's before)"
      app_running || launch
      echo "DO (person): open BatteryPulse's main window with the sidebar showing; click each page the Mac names (about 4 minutes)."
      sleep 8
      capture="$LOGS/pages.ndjson"
      perf_capture "$capture"
      cue_pages 10 3
      perf_stop "$STREAM"
      out "- $(app_version), 10 rounds of 7 pages, a page every 3 s"
      out "- page.switch lines per page: $(page_counts "$capture" | tr '\n' ',' | sed 's/,$//; s/,/, /g')"
      summarize "$capture" '^(intervals|name|page\.switch)'
      echo "NEXT: $SCRIPT pages profiling"
      ;;
    profiling)
      begin_section 81-pages-xctrace "Page switches under xctrace (SPIKE-A2's profiling build)"
      if ! xcrun -f xctrace >/dev/null 2>&1; then
        out "- skipped: xcrun can't find xctrace"
        echo "NEXT: the window (SESSION.md)"
        return 0
      fi
      if [ ! -f "$BUILDS/A2P.dmg" ]; then
        out "- skipped: SPIKE-A2's run has no profiling DMG"
        return 0
      fi
      # A2P has A2's build number (the same run): 0.6.1 goes between them.
      install_build B --no-launch
      install_build A2P
      xcrun xctrace list templates >"$LOGS/xctrace-templates.txt" 2>&1 || true
      local template
      template="$(grep -i -m1 swiftui "$LOGS/xctrace-templates.txt" | sed -E 's/^[[:space:]]+//; s/[[:space:]]+\(.*\)$//' || true)"
      if [ -z "$template" ]; then
        out "- skipped: no SwiftUI template in 'xctrace list templates'"
        out_block "$LOGS/xctrace-templates.txt"
        return 0
      fi
      echo "DO (person): open the main window again, with the sidebar showing; click each page the Mac names. macOS may ask for"
      echo "  an administrator's password for developer tools: the person types it there, never here."
      sleep 8
      mkdir -p "$WORK/traces"
      rm -rf "$WORK/traces/pages.trace"
      capture="$LOGS/pages-profiling.ndjson"
      perf_capture "$capture"
      xcrun xctrace record --template "$template" --attach "$(app_pid)" --time-limit 240s \
        --output "$WORK/traces/pages.trace" >"$LOGS/xctrace-record.txt" 2>&1 &
      local trace=$!
      BACKGROUND="$BACKGROUND $trace"
      sleep 5
      cue_pages 10 3
      wait "$trace" || true
      perf_stop "$STREAM"
      out "- template: $template; trace: $(du -sh "$WORK/traces/pages.trace" 2>/dev/null | cut -f1 || echo none) (kept on the Mac)"
      out "- page.switch lines per page under the profiler: $(page_counts "$capture" | tr '\n' ',' | sed 's/,$//; s/,/, /g')"
      summarize "$capture" '^(intervals|name|page\.switch)'
      if [ -d "$WORK/traces/pages.trace" ]; then
        xcrun xctrace export --input "$WORK/traces/pages.trace" --toc >"$LOGS/pages-trace-toc.xml" 2>&1 || true
        out "- the trace's tables: $(grep -o -E 'schema="[^"]*"' "$LOGS/pages-trace-toc.xml" | sort -u | sed 's/schema=//; s/"//g' | tr '\n' ' ')"
      else
        out "- xctrace wrote no trace:"
        out_block "$LOGS/xctrace-record.txt"
      fi
      echo "Then read the SwiftUI tables (SESSION.md) and note what they show."
      echo "NEXT: the window (SESSION.md)"
      ;;
    *) fail "usage: $SCRIPT pages [profiling]" ;;
  esac
}

# MARK: - The unattended window (step 9)

WINDOW_T0=0
DISPLAY_AWAKE=""

keep_display_awake() {
  if [ -z "$DISPLAY_AWAKE" ]; then
    caffeinate -d -w $$ &
    DISPLAY_AWAKE=$!
    BACKGROUND="$BACKGROUND $DISPLAY_AWAKE"
  fi
}

let_display_sleep() {
  if [ -n "$DISPLAY_AWAKE" ]; then
    kill "$DISPLAY_AWAKE" 2>/dev/null || true
    DISPLAY_AWAKE=""
  fi
}

sudo_ok() { sudo -n true 2>/dev/null; }

set_lowpowermode() {
  sudo -n pmset -b lowpowermode "$1" >/dev/null 2>&1 && [ "$(lowpowermode_of Battery)" = "$1" ]
}

# Low Power Mode as prepare found it, per power source; the window's EXIT trap calls it. Fails
# (after its PUT BACK line) when it couldn't put it back, so nothing marks it restored then.
restore_lowpowermode() {
  local battery adapter
  battery="$(cat "$BACKUP/lowpowermode-battery" 2>/dev/null || true)"
  adapter="$(cat "$BACKUP/lowpowermode-ac" 2>/dev/null || true)"
  [ -n "$battery" ] && [ -n "$adapter" ] || return 0
  if lowpowermode_as_backup; then return 0; fi
  if sudo -n pmset -b lowpowermode "$battery" >/dev/null 2>&1 && sudo -n pmset -c lowpowermode "$adapter" >/dev/null 2>&1 &&
    lowpowermode_as_backup; then
    echo "Low Power Mode is back as it was (battery $battery, adapter $adapter)."
  else
    echo "PUT BACK (person, in Terminal): sudo pmset -b lowpowermode $battery; sudo pmset -c lowpowermode $adapter"
    return 1
  fi
}

# Low Power Mode for both sources is what prepare's backup holds.
lowpowermode_as_backup() {
  [ "$(lowpowermode_of Battery)" = "$(cat "$BACKUP/lowpowermode-battery" 2>/dev/null || echo unknown)" ] &&
    [ "$(lowpowermode_of AC)" = "$(cat "$BACKUP/lowpowermode-ac" 2>/dev/null || echo unknown)" ]
}

window_exit() {
  if [ ! -f "$WORK/window.done" ]; then
    echo "stopped $(clock)" >"$WORK/window.stopped"
    echo "The window stopped early ($(clock)); the session runs $SCRIPT restore."
  fi
  restore_lowpowermode || true
  stop_pslog
  cleanup
}

# NOTIFY_KEYS: the power-source notify keys: "any" (the one 0.6.1 listens to besides
# timeremaining, MacBatteryProvider.swift) and the keyed ones powerd posts.
NOTIFY_KEYS="com.apple.system.powersources com.apple.system.powersources.timeremaining
com.apple.system.powersources.percent com.apple.system.powersources.source
com.apple.system.powersources.attach com.apple.system.powersources.lowbattery"

# stamped <output> <command...>: the command under a pseudo-terminal, so it writes each line at once,
# and each line stamped by one zsh process with the time it arrived (seconds, to the microsecond).
# write_stamp_script: the zsh stamper stamped() runs, written once (Session B's prepare writes it
# before it seals the tools).
write_stamp_script() {
  [ ! -f "$BIN/stamp.zsh" ] || return 0
  mkdir -p "$BIN"
  cat >"$BIN/stamp.zsh" <<'EOF'
zmodload zsh/datetime
while IFS= read -r line; do
  line=${line%$'\r'}
  print -r -- "$EPOCHREALTIME $line"
done
EOF
}

stamped() {
  local output="$1"
  shift
  write_stamp_script
  # script's standard input is a pipe that stays open past the window (4 hours): at an end of
  # input, script passes it on to the command or stops, so /dev/null could end both at once.
  script -q /dev/null "$@" < <(sleep 14400) 2>&1 | zsh -f "$BIN/stamp.zsh" >"$output" &
  BACKGROUND="$BACKGROUND $!"
}

# `pmset -g pslog` (PLAN.md §6) and, beside it, `notifyutil -w` on every power-source key, whose
# lines name the key for sure; the analysis reads notifyutil's lines when there are any.
start_pslog() {
  local key watch=""
  stamped "$LOGS/pslog.txt" pmset -g pslog
  for key in $NOTIFY_KEYS; do watch="$watch -w $key"; done
  # $watch is split on purpose: one -w per key.
  # shellcheck disable=SC2086
  stamped "$LOGS/notify.txt" notifyutil $watch
  sleep 5
  pgrep -f 'pmset -g pslog' >/dev/null || warn "pmset -g pslog isn't running: F13 and E3b rest on notifyutil's lines"
  pgrep -f 'notifyutil -w' >/dev/null || warn "notifyutil isn't running: F13 and E3b rest on pslog's lines"
}

stop_pslog() {
  pkill -f 'pmset -g pslog' 2>/dev/null || true
  pkill -f 'notifyutil -w' 2>/dev/null || true
}

# Every 10 s: the time, AppleSmartBattery's UpdateTime, BatteryData's RemainingCapacity,
# PowerTelemetryData's SystemPowerIn, ExternalConnected, and the pack entry's BatteryData
# Temperature (macOS 27 keeps it there, RegistryChildren.swift).
sampler() {
  local battery="$LOGS/sample-battery.plist" pack="$LOGS/sample-pack.plist"
  printf 'epoch\tupdate_time\tremaining_mah\tsystem_power_in_mw\texternal\tpack_temperature\n' >"$LOGS/sampler.tsv"
  while kill -0 $$ 2>/dev/null; do
    ioreg -r -c AppleSmartBattery -a -d 1 >"$battery" 2>/dev/null || true
    ioreg -r -c AppleSmartBatteryPack -a -d 1 >"$pack" 2>/dev/null || true
    printf '%s\t%s\t%s\t%s\t%s\t%s\n' "$(date +%s)" "$(plist_value "$battery" 0.UpdateTime)" \
      "$(plist_value "$battery" 0.BatteryData.RemainingCapacity)" \
      "$(plist_value "$battery" 0.PowerTelemetryData.SystemPowerIn)" \
      "$(plist_value "$battery" 0.ExternalConnected)" "$(plist_value "$pack" 0.BatteryData.Temperature)" \
      >>"$LOGS/sampler.tsv"
    sleep 10
  done
}

# energy_row <cells...>: one row of the energy table; a run that didn't happen says why in the
# fifth cell and leaves the rest empty.
ENERGY_COLUMNS=11
energy_row() {
  local row="|" cell count=0
  for cell in "$@"; do
    row="$row $cell |"
    count=$((count + 1))
  done
  while [ "$count" -lt "$ENERGY_COLUMNS" ]; do
    row="$row |"
    count=$((count + 1))
  done
  echo "$row" >>"$LOGS/energy-rows.md"
}

rusage_value() { awk -F= -v key="$2" '$1 == key { print $2 }' "$1"; }

power_source() { if on_battery; then echo battery; else echo "adapter (not valid)"; fi; }

# energy_run <scenario> <build> <seconds>: one run of WP-21: the build installed, the scenario's
# settings, Low Power Mode and the power source recorded, 1 minute to settle, then rusage over the
# window with the perf lines captured. S1 shows the icon and the charge, S2 power in the menu bar
# too, S2-LPM that with Low Power Mode on, S6 S1 with the displays asleep. Every window stays
# closed; the display stays on (caffeinate -d) except in S6.
ENERGY_INDEX=0
energy_run() {
  local scenario="$1" build="$2" seconds="$3" capture rusage_file pid measuring assertions lpm power reads
  local per_minute
  ENERGY_INDEX=$((ENERGY_INDEX + 1))
  echo "$(clock) energy run $ENERGY_INDEX: $scenario on $build"
  install_build "$build" --no-launch
  quit_app
  session_settings
  case "$scenario" in S2*) set_default menuBarShowsPower -bool true ;; esac
  if [ "$scenario" = S2-LPM ]; then
    if ! sudo_ok || ! set_lowpowermode 1; then
      energy_row "$scenario" "$build" "$(power_source)" "-" "not run: no sudo ticket"
      return 0
    fi
  fi
  lpm="$(lowpowermode_of Battery)"
  power="$(power_source)"
  launch
  sleep 60
  if [ "$scenario" = S6 ]; then
    let_display_sleep
    pmset displaysleepnow || warn "pmset displaysleepnow failed: S6 runs with the display on"
  fi
  capture="$LOGS/energy-$ENERGY_INDEX-$scenario-$build.ndjson"
  rusage_file="$LOGS/energy-$ENERGY_INDEX-$scenario-$build.rusage"
  perf_capture "$capture"
  pid="$(app_pid)"
  if [ -z "$pid" ]; then
    perf_stop "$STREAM"
    energy_row "$scenario" "$build" "$power" "$lpm" "not run: BatteryPulse wasn't running"
  else
    rusage "$pid" "$seconds" >"$rusage_file" 2>&1 &
    measuring=$!
    sleep 5
    assertions="$(pmset -g assertions | grep -c BatteryPulse || true)"
    wait "$measuring" || true
    perf_stop "$STREAM"
    if on_battery; then :; else power="adapter (not valid)"; fi
    reads="$(app_reads "$capture")"
    per_minute="$(awk -v n="$reads" -v s="$seconds" 'BEGIN { printf "%.1f", n * 60 / s }')"
    energy_row "$scenario" "$build" "$power" "$lpm" "$(rusage_value "$rusage_file" energy_mj_per_h)" \
      "$(rusage_value "$rusage_file" idle_wakeups_per_h)" "$(rusage_value "$rusage_file" interrupt_wakeups_per_h)" \
      "$(rusage_value "$rusage_file" cpu_s_per_h)" \
      "$(awk -F= '$1 == "phys_footprint_bytes" { printf "%.1f", $2 / 1048576 }' "$rusage_file")" "$per_minute" \
      "$assertions"
  fi
  if [ "$scenario" = S6 ]; then
    caffeinate -u -t 2 >/dev/null 2>&1 || true
    keep_display_awake
  fi
  if [ "$scenario" = S2-LPM ]; then set_lowpowermode 0 || warn "Low Power Mode is still on"; fi
}

# s7_launches <build> <count>: cold launches, each timed from open to its menuBarReady line, and the
# reads before it, with power in the menu bar (WP-2a's 2 → 1 reads).
s7_launches() {
  local build="$1" count="$2" capture number=0 start starts="" waited before
  install_build "$build" --no-launch
  quit_app
  session_settings
  set_default menuBarShowsPower -bool true
  capture="$LOGS/s7-$build.ndjson"
  perf_capture "$capture"
  while [ "$number" -lt "$count" ]; do
    number=$((number + 1))
    quit_app
    sleep 3
    before="$(ready_count "$capture")"
    start="$(now_ms)"
    open_app
    waited=0
    until [ "$(ready_count "$capture")" -gt "$before" ] || [ "$waited" -ge 150 ]; do
      sleep 0.1
      waited=$((waited + 1))
    done
    if [ "$SESSION" = B ]; then note_rc_pid; fi
    starts="$starts $start"
  done
  perf_stop "$STREAM"
  out "### S7 $build"
  number=0
  for start in $starts; do
    number=$((number + 1))
    out "- launch $number: $(ready_after "$capture" "$start") ms from open to menuBarReady"
  done
  summarize "$capture" '^(processes|pid|[0-9])'
}

# footprint <pid>: phys_footprint in MB, from rusage over one second.
footprint() {
  if [ -z "$1" ]; then
    echo "not running"
    return 0
  fi
  rusage "$1" 1 | awk -F= '$1 == "phys_footprint_bytes" { printf "%.1f MB", $2 / 1048576 }'
}

plug_alert() {
  echo "$(clock): plug in the adapter now"
  (for _ in 1 2 3; do afplay /System/Library/Sounds/Glass.aiff; done) >/dev/null 2>&1 &
  osascript -e 'display alert "BatteryPulse Session A" message "Plug in the adapter now (1 minute)." giving up after 1800' \
    >/dev/null 2>&1 &
}

# field_run <end epoch> <plug epoch>: SPIKE-A2 with the perf stream until <end> (E20's field run),
# phys_footprint at its start and end, and the plug alert at <plug>.
field_run() {
  local end="$1" plug="$2" capture="$LOGS/field.ndjson" pid_start pid_end plugged=""
  begin_section 91-field "E20's field run on SPIKE-A2"
  install_build A2 --no-launch
  quit_app
  session_settings
  set_default menuBarShowsPower -bool true
  perf_capture "$capture"
  launch
  sleep 30
  pid_start="$(app_pid)"
  out "- start: $(clock), $(app_version), power in the menu bar, the display kept on"
  out "- phys_footprint at the start: $(footprint "$pid_start")"
  sleep_until "$plug"
  plug_alert
  local waited=0
  while on_battery && [ "$waited" -lt 120 ]; do
    sleep 15
    waited=$((waited + 1))
  done
  if on_battery; then plugged="not plugged in within 30 minutes"; else plugged="plugged in at $(clock)"; fi
  echo "$plugged" >"$WORK/plug.txt"
  date +%s >"$WORK/plug.epoch"
  out "- the adapter: $plugged"
  sleep_until "$end"
  pid_end="$(app_pid)"
  out "- end: $(clock); the same process: $(if [ "$pid_start" = "$pid_end" ]; then echo yes; else echo "no ($pid_start, then ${pid_end:-none})"; fi)"
  out "- phys_footprint at the end: $(footprint "$pid_end")"
  perf_stop "$STREAM"
  out "- reads by thread (the main thread is the one menuBarReady was logged on):"
  read_threads "$capture" >"$LOGS/field-threads.txt"
  out_block "$LOGS/field-threads.txt"
  summarize "$capture"
  local executor
  executor="$(log_since "$(date -r "$WINDOW_T0" '+%Y-%m-%d %H:%M:%S')" "$EXECUTOR_PREDICATE" "$LOGS/executor-window.ndjson")"
  out "- \"executor\" log lines during the window: $executor"
  out "- crash reports during the window:"
  crash_summary "$WORK/window.marker"
}

# The notify lines against the ioreg samples: F13 (every UpdateTime change has an "any" line
# between the sample before it and its own sample, 10 s apart), E3b (every timeremaining has an
# "any" within 10 ms after it; also counted within 10 ms on either side), and the mAh cadence. The
# lines are notifyutil's when it logged any, otherwise pslog's.
NOTIFY_KINDS='
  function kind(line) {
    if (line ~ /powersources\.timeremaining/) return "timeremaining"
    if (line ~ /powersources\.lowbattery/) return "lowbattery"
    if (line ~ /powersources\.percent/) return "percent"
    if (line ~ /powersources\.attach/) return "attach"
    if (line ~ /powersources\.source/) return "source"
    if (line ~ /com\.apple\.system\.powersources$/ || line ~ /com\.apple\.system\.powersources[^.]/) return "any"
    return "other"
  }'

pslog_analysis() {
  begin_section 92-pslog "pslog, notifyutil and the ioreg sampler (F13, E3b, mAh cadence)"
  local plug_epoch=0 lines="$LOGS/notify.txt"
  if [ -f "$WORK/plug.epoch" ] && ! grep -q not "$WORK/plug.txt" 2>/dev/null; then plug_epoch="$(cat "$WORK/plug.epoch")"; fi
  if ! grep -q 'powersources' "$lines" 2>/dev/null; then lines="$LOGS/pslog.txt"; fi
  out "- lines read: $(basename "$lines") (notify.txt: $(grep -c . "$LOGS/notify.txt" 2>/dev/null || echo 0) lines, pslog.txt: $(grep -c . "$LOGS/pslog.txt" 2>/dev/null || echo 0)), each stamped through a pseudo-terminal when it was written"
  out "- samples: $(($(wc -l <"$LOGS/sampler.tsv") - 1)); adapter: $(cat "$WORK/plug.txt" 2>/dev/null || echo unknown)"
  out "- lines by notification key (\"other\" is pmset's own text):"
  awk "$NOTIFY_KINDS"' { count[kind($0)]++ } END { for (k in count) printf "%s %d\n", k, count[k] }' "$lines" |
    sort >"$LOGS/pslog-kinds.txt"
  out_block "$LOGS/pslog-kinds.txt"
  # FILENAME, not FNR == NR, which would read the samples as notify lines if no line was logged.
  awk -v plug="$plug_epoch" "$NOTIFY_KINDS"'
    FILENAME == ARGV[1] {
      k = kind($0)
      if (k == "other") next
      n++; at[n] = $1 + 0; what[n] = k
      next
    }
    FNR > 1 {
      t = $1 + 0
      phase = (plug > 0 && t >= plug) ? "charging" : "battery"
      if (previous != "" && $2 != previous && $2 != "-") {
        changes[phase]++
        found = 0
        for (i = 1; i <= n; i++) if (what[i] == "any" && at[i] > last - 1 && at[i] <= t + 1) { found = 1; break }
        if (found) matched[phase]++
      }
      if (remaining != "" && $3 != remaining && $3 != "-") mah[phase]++
      if (first[phase] == "") first[phase] = t
      lastt[phase] = t
      previous = $2; remaining = $3; last = t
    }
    END {
      for (i = 1; i <= n; i++) {
        if (what[i] != "timeremaining") continue
        phase = (plug > 0 && at[i] >= plug) ? "charging" : "battery"
        tr[phase]++
        after = 0; near = 0
        for (j = i + 1; j <= n && at[j] - at[i] <= 0.010; j++) if (what[j] == "any") { after = 1; break }
        for (j = i - 1; j >= 1 && at[i] - at[j] <= 0.010; j--) if (what[j] == "any") { near = 1; break }
        if (after) { follow[phase]++; near = 1 }
        if (near) around[phase]++
      }
      split("battery charging", phases, " ")
      for (p = 1; p <= 2; p++) {
        ph = phases[p]
        hours = (lastt[ph] - first[ph]) / 3600
        printf "%s: %.2f h sampled; UpdateTime changes %d, with an \"any\" line since the sample before %d (F13)\n", ph, hours, changes[ph] + 0, matched[ph] + 0
        printf "%s: timeremaining lines %d; an \"any\" within 10 ms after %d, within 10 ms either side %d (E3b)\n", ph, tr[ph] + 0, follow[ph] + 0, around[ph] + 0
        if (hours > 0) printf "%s: RemainingCapacity changes %d, %.1f an hour\n", ph, mah[ph] + 0, mah[ph] / hours
      }
    }' "$lines" "$LOGS/sampler.tsv" >"$LOGS/pslog-checks.txt"
  out_block "$LOGS/pslog-checks.txt"
  out "- the first lines of each, to show what they name:"
  {
    head -5 "$LOGS/notify.txt" 2>/dev/null || true
    head -8 "$LOGS/pslog.txt" 2>/dev/null || true
  } >"$LOGS/pslog-head.txt"
  out_block "$LOGS/pslog-head.txt"
}

step_window() {
  [ -t 0 ] || fail "start the window in Terminal (sudo asks for the password there): $SCRIPT window"
  [ -f "$BACKUP/done" ] || fail "run $SCRIPT prepare first"
  local name
  for name in A B A2; do [ -f "$BUILDS/$name.dmg" ] || fail "build $name is missing: $SCRIPT prepare"; done
  if [ -z "$(answer_of energy-setup)" ]; then
    echo "Energy setup: display brightness about half, auto-brightness and True Tone off, other apps quit"
    echo "(Terminal and the Claude session stay), a Focus on."
    local reply=""
    read -r -p "Done? 1 done, 2 not all: " reply
    case "$reply" in 1 | 2) step_answer --by person energy-setup "$reply" ;; *) fail "answer 1 or 2" ;; esac
  fi
  on_battery || fail "the Mac is on the adapter: unplug it, then start the window again"
  local percent started
  percent="$(battery_percent)"
  case "$percent" in "" | *[!0-9]*) fail "can't read the charge from pmset -g batt" ;; esac
  [ "$percent" -ge 50 ] || fail "the battery is at $percent %; the window needs at least 50 %"
  # Terminal may not control System Events yet: its prompt would first come up at 3:00, when
  # restore puts the appearance and the wallpaper back and nobody is here. Ask now. BatteryPulse's
  # own prompt comes with the first install's quit, a few seconds after the password.
  echo "If Terminal asks to control System Events, and then BatteryPulse, click OK each time."
  is_dark >/dev/null
  echo "sudo asks for your password once (Low Power Mode for one run, and putting it back)."
  if sudo -v; then
    (while kill -0 $$ 2>/dev/null; do
      sudo -n -v 2>/dev/null || true
      sleep 60
    done) &
    BACKGROUND="$BACKGROUND $!"
  else
    warn "no sudo: the Low Power Mode run is recorded as not run"
  fi
  trap window_exit EXIT
  cd "$ROOT"
  WINDOW_T0="$(date +%s)"
  touch "$WORK/window.marker"
  rm -f "$WORK/window.done" "$WORK/plug.txt" "$WORK/plug.epoch"
  caffeinate -i -w $$ &
  BACKGROUND="$BACKGROUND $!"
  keep_display_awake
  start_pslog
  sampler &
  BACKGROUND="$BACKGROUND $!"
  if [ "$(lowpowermode_of Battery)" != 0 ]; then
    set_lowpowermode 0 || warn "Low Power Mode stays on: every run says so"
  fi

  started="$(clock) at $(battery_percent) %"
  printf '| Run | Build | Power | Low Power Mode | Energy mJ/h | Idle wake-ups/h | Interrupt wake-ups/h | CPU s/h | Footprint MB | App reads/min | BatteryPulse assertions |\n|---|---|---|---|---|---|---|---|---|---|---|\n' \
    >"$LOGS/energy-rows.md"
  # WP-21's runs, each pair with B first: A (build 158) is higher than 0.6.1 (build 7), and 0.6.1
  # may always come back, so no install goes against the CFBundleVersion rule.
  energy_run S1 B 240
  energy_run S1 A 240
  energy_run S2 B 240
  energy_run S2 A 240
  energy_run S2 B 240
  energy_run S2 A 240
  energy_run S2-LPM B 240
  energy_run S2-LPM A 240
  begin_section 90-s7 "S7, cold launches to menuBarReady (A against B)"
  s7_launches B 5
  s7_launches A 5
  # The displays sleep last: what follows needs them awake, and waking them may show the lock screen.
  energy_run S6 B 600
  energy_run S6 A 600
  begin_section 90-energy "Energy, A against B (WP-21)"
  out "- on battery; each run: the build installed, 1 minute to settle, then rusage over 4 minutes (S6: 10, displays asleep)"
  out "- A: $(awk -F '\t' '$1 == "A" { print $2 " (" $3 ")" }' "$WORK/builds.tsv"), B: $(awk -F '\t' '$1 == "B" { print $2 " (" $3 ")" }' "$WORK/builds.tsv"); started $started; ended $(clock) at $(battery_percent) %"
  out ""
  tee -a "$SECTION" <"$LOGS/energy-rows.md"

  field_run $((WINDOW_T0 + 3 * 3600)) $((WINDOW_T0 + 2 * 3600))
  stop_pslog
  pslog_analysis
  # Each in a subshell, so a failure there still leaves the prompts on screen.
  (restore_all) || warn "restore stopped early; run $SCRIPT restore"
  # No send here: the repository is public, so the maintainer sees what A.md holds and says yes
  # first (SESSION.md, "After the window").
  out "- results ready in $WORK/A.md; not sent yet (send runs after the maintainer has seen them)"
  touch "$WORK/window.done"
  osascript -e 'display alert "BatteryPulse Session A" message "The window is done. Terminal lists what to put back by hand." giving up after 36000' \
    >/dev/null 2>&1 &
  restore_prompts
}

# MARK: - Restore

restore_all() {
  [ -f "$BACKUP/done" ] || fail "no backup in $BACKUP"
  begin_section 95-restore "Restore"
  install_build backup --no-launch
  quit_app
  defaults delete "$BUNDLE_ID" 2>/dev/null || true
  defaults import "$BUNDLE_ID" "$BACKUP/defaults.plist"
  rm -rf "$SUPPORT"
  if [ -d "$BACKUP/support" ]; then ditto "$BACKUP/support" "$SUPPORT"; fi
  # SPIKE-W's feed (candidate A); 0.6.1 has none.
  rm -rf "$SUPPORT/Widget"
  defaults delete "$FEED_DOMAIN" 2>/dev/null || true
  rm -f "$HOME/Library/Preferences/$FEED_DOMAIN.plist"
  if [ "$SESSION" = B ]; then
    put_widget_languages_back || warn "the widget extension's AppleLanguages isn't as prepare found it"
  else
    defaults delete "$WIDGET_PREFS" AppleLanguages 2>/dev/null || true
    if [ -f "$BACKUP/widget-languages" ]; then
      warn "the widget extension had its own AppleLanguages before: $(tr -s ' \n' ' ' <"$BACKUP/widget-languages"); set it again by hand if you need it"
    fi
  fi
  end_widget_extension
  restore_lowpowermode || true
  if [ -s "$BACKUP/wallpapers" ] && [ "$(wallpapers)" != "$(cat "$BACKUP/wallpapers")" ] &&
    { [ "$SESSION" != B ] || wallpaper_is_still; }; then
    local index=1 path
    while IFS= read -r path; do
      [ -n "$path" ] || continue
      osascript -e 'on run argv' \
        -e 'tell application "System Events" to set picture of desktop (item 1 of argv as integer) to (item 2 of argv)' \
        -e 'end run' "$index" "$path" >/dev/null 2>&1 || warn "can't put back the wallpaper of desktop $index"
      index=$((index + 1))
    done <"$BACKUP/wallpapers"
  fi
  case "$(cat "$BACKUP/dark-mode" 2>/dev/null || echo unknown)" in
    true) [ "$(is_dark)" = true ] || (appearance dark) || warn "put the dark appearance back by hand" ;;
    false) [ "$(is_dark)" = false ] || (appearance light) || warn "put the light appearance back by hand" ;;
  esac
  launch
  out "- restored $(clock): $(app_version), the settings domain, Application Support, the widget's data and preferences, Low Power Mode, the wallpaper and the appearance"
}

restore_prompts() {
  local style dim login
  style="$(answer_of prep-widget-style)"
  dim="$(answer_of prep-dim-widgets)"
  login="$(answer_of prep-open-at-login)"
  echo
  echo "PUT BACK (person):"
  echo "- Turn VoiceOver off if it is on (Command-F5)."
  echo "- Set System Settings → Accessibility → Display → Text size back to where it was."
  echo "- Set System Settings → Appearance → Icon & widget style back to ${style:-what it was}."
  echo "- Set System Settings → Desktop & Dock → Dim widgets on desktop back to ${dim:-what it was}."
  if [ "$(cat "$BACKUP/auto-appearance" 2>/dev/null || echo 0)" = 1 ]; then
    echo "- Set System Settings → Appearance back to Auto."
  fi
  case "$login" in
    1) echo "- Open at login was on: check that it still is in BatteryPulse Settings → General." ;;
    2) ;;
    *) echo "- If Open at login was on before the session, check that it still is in BatteryPulse Settings → General." ;;
  esac
  # Reminders only: the Charge Limit is the person's own setting, and the script never changes a
  # privacy permission (macOS grants them; only the person turns them off).
  echo "- If you changed the Charge Limit during the session, set it back to what it was (System Settings → Battery)."
  echo "- If macOS asked for Accessibility for Terminal during the session and you allowed it, turn Terminal off (or remove it) in System Settings → Privacy & Security → Accessibility, unless it was on before."
  echo "- Remove the widgets the session added (large, extra large, Test, Notification Center) if you don't want them."
  echo "- If a BatteryPulse widget is blank, remove it and add it again."
  echo "The backup stays in $BACKUP."
}

step_restore() {
  restore_all
  restore_prompts
}

# MARK: - status and send

step_status() {
  if [ "$SESSION" = B ]; then
    step_status_b
    return 0
  fi
  local id value
  echo "folder: $WORK"
  if [ "$(uname -s)" = Darwin ]; then
    echo "installed: $(app_version); running: $(if app_running; then echo yes; else echo no; fi)"
    echo "battery: $(battery_percent) %, $(if on_battery; then echo on battery; else echo on the adapter; fi)"
  fi
  if [ -f "$WORK/window.done" ]; then echo "the window is done"; fi
  if [ -f "$WORK/window.stopped" ] && [ ! -f "$WORK/window.done" ]; then
    echo "the window stopped early: $(cat "$WORK/window.stopped")"
  fi
  echo "answers:"
  for id in $QUESTIONS; do
    value="$(answer_of "$id")"
    printf '  %-24s %s\n' "$id" "${value:--}"
  done
  echo "sections: $(find "$SECTIONS" -name '*.md' 2>/dev/null | sed 's|.*/||; s|\.md$||' | sort | tr '\n' ' ')"
  echo "attached images: $(grep -c . "$PUBLISH/captions.tsv" 2>/dev/null || echo 0)"
}

# The Appendix C rows Session A owns (PLAN.md), with where this file answers them.
appendix_rows() {
  cat <<'EOF'
| Fact (PLAN.md Appendix C) | Where in this file |
|---|---|
| W0-1: entity query and button results | SPIKE-W's log lines (`spike query`, `spike perform`); W0-1-test-edit |
| W0-2: SPIKE-C and SPIKE-W placed-widget results; edit sheet in English and Russian | SPIKE-C, SPIKE-I, SPIKE-W (pluginkit); W0-2-* answers |
| W0-3: A, A′, B results (errno and byte count) | SPIKE-W's log lines (`spike feed`) |
| W0-4: accessory count; rendering mode per style and place; redactionReasons; click deliveries; scheme need | SPIKE-W's log lines, per mark |
| W0-5: VoiceOver text; Text size | W0-5-* answers |
| W0-6: the offset format's text and cadence | W0-6-* answers |
| F13: UpdateTime changes against "any" lines | pslog, notifyutil and the ioreg sampler |
| E3b: timeremaining followed by "any" (battery and charging) | pslog, notifyutil and the ioreg sampler |
| E20 field run: traps, crash reports, read threads; memory over 2 hours | E20's field run |
| V-01: "executor" log lines, new crash reports, the answers | V-01; V01-* answers |
| mAh cadence: RemainingCapacity changes per hour | pslog, notifyutil and the ioreg sampler |
| Clear's fill (b) and Translucent Dark's today's fill | Clear's minimize fill; fill-* answers |
| page.switch count and p50 per page (before) | Page switches |
| F5: accessory and device captures (bpulse built or not) | F5 |
| Sleep hygiene: pmset -g assertions per run | Energy (the assertions column) |
| SEC-15 timings; diskutil image attach and eject usage text | Attach timing |
| A/B energy (S1, S2, S2 Low Power Mode, S6, S7) | Energy |
EOF
}

# The question's text without its kind and who.
question_text() {
  local spec
  spec="$(question "$1")" || return 0
  spec="${spec#*|}"
  printf '%s' "${spec#*|}"
}

build_report() {
  local id value by at note line file caption text
  echo "# Session A results (BatteryPulse 0.6.2)"
  echo
  echo "Written by \`docs/plans/0.6.2/m5-session.sh send\` on $(date '+%Y-%m-%d %H:%M %z'). Answers marked \"claude\""
  echo "were judged by the Claude session from the screenshots, frames and logs named in their step;"
  echo "\"person\" ones came from the maintainer. Recordings, traces and captures that name devices stay"
  echo "on the Mac (\`~/bp-062/A\`)."
  echo
  echo "## Appendix C rows this session owns"
  echo
  appendix_rows
  echo
  echo "## Answers"
  echo
  echo "| ID | Question | Answer | By | Time | Note |"
  echo "|---|---|---|---|---|---|"
  for id in $QUESTIONS; do
    line="$(awk -F '\t' -v id="$id" '$1 == id { line = $0 } END { print line }' "$ANSWERS" 2>/dev/null || true)"
    if [ -n "$line" ]; then
      IFS=$'\t' read -r _ value by at note <<<"$line"
      printf '| %s | %s | %s | %s | %s | %s |\n' "$id" "$(question_text "$id")" "$value" "$by" "$at" "${note:-}"
    else
      printf '| %s | %s | not answered | | | |\n' "$id" "$(question_text "$id")"
    fi
  done
  echo
  for file in "$SECTIONS"/*.md; do
    [ -f "$file" ] || continue
    cat "$file"
    echo
  done
  if [ -s "$NOTES" ]; then
    echo "## Notes"
    echo
    while IFS=$'\t' read -r at text; do
      echo "- $at: $text"
    done <"$NOTES"
    echo
  fi
  if [ -s "$PUBLISH/captions.tsv" ]; then
    echo "## Images"
    echo
    while IFS=$'\t' read -r file caption; do
      echo "$caption"
      echo
      echo "![$caption](A/$file)"
      echo
    done <"$PUBLISH/captions.tsv"
  fi
}

# send [--dry-run]: <session>.md (and the attached images) committed to docs/plans/0.6.2/sessions/
# on claude/062-session-a or -b, which starts from the integration branch; a fresh shallow clone in
# ~/bp-062/<session>/send, so your own checkout stays as it is. Never another branch, never a pull
# request. Session B's needs his yes (B-send) and passes the privacy lint first.
step_send() {
  local dry_run="" clone="$WORK/send" base name email total report="$WORK/$SESSION.md"
  if [ "${1:-}" = --dry-run ]; then dry_run=1; fi
  mkdir -p "$WORK"
  if [ "$SESSION" = B ]; then
    if [ -z "$dry_run" ] && [ "$(answer_of B-send)" != y ]; then
      fail "his yes first, at the Mac, after the contact sheet of every attached image and the summary: $SCRIPT answer --by person B-send y"
    fi
    if [ -n "$dry_run" ]; then
      publish_sheet
    elif ! publish_sheet_fresh || { [ -f "$WORK/publish-sheet.png" ] && ! [ "$WORK/send-yes" -nt "$WORK/publish-sheet.png" ]; }; then
      fail "an image was attached after the contact sheet, or his yes came before it: $SCRIPT send --dry-run, show him the new sheet, then his yes again"
    fi
    build_report_b | public >"$report"
    privacy_lint "$report"
  else
    build_report | public >"$report"
  fi
  if has_cyrillic "$(cat "$report")"; then
    fail "$SESSION.md contains Russian text; translate the answer or note it comes from, then send again"
  fi
  total=0
  if [ -s "$PUBLISH/captions.tsv" ]; then total="$(du -sk "$PUBLISH" | cut -f1)"; fi
  [ "$total" -le 6144 ] || fail "the attached images take $total KB; unattach some (at most 6 MB)"
  echo "wrote $report ($(wc -l <"$report" | tr -d ' ') lines, images $total KB)"
  [ -z "$dry_run" ] || return 0

  rm -rf "$clone"
  base="$INTEGRATION_BRANCH"
  if git ls-remote --exit-code --heads "https://github.com/$REPO.git" "$RESULTS_BRANCH" >/dev/null 2>&1; then
    base="$RESULTS_BRANCH"
  fi
  git clone --quiet --depth 1 --branch "$base" "https://github.com/$REPO.git" "$clone"
  git -C "$clone" checkout --quiet -B "$RESULTS_BRANCH"
  mkdir -p "$clone/docs/plans/0.6.2/sessions"
  rm -rf "$clone/docs/plans/0.6.2/sessions/$SESSION"
  cp "$report" "$clone/docs/plans/0.6.2/sessions/$SESSION.md"
  if [ -s "$PUBLISH/captions.tsv" ]; then
    mkdir -p "$clone/docs/plans/0.6.2/sessions/$SESSION"
    cut -f1 "$PUBLISH/captions.tsv" | while IFS= read -r file; do
      cp "$PUBLISH/$file" "$clone/docs/plans/0.6.2/sessions/$SESSION/"
    done
  fi
  git -C "$clone" add -A docs/plans/0.6.2/sessions
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
  # In UTC, so the commit dates show no local time zone (the privacy audit, 2026-10-24).
  TZ=UTC git -C "$clone" -c user.name="$name" -c user.email="$email" commit --quiet -F - <<EOF
Record M5 Session $SESSION's results

The answers, counts, perf-stats summaries, public log excerpts and the
attached crops of Session $SESSION (PLAN.md §6), for the packages and
gates that wait on them.

Co-Authored-By: Claude <noreply@anthropic.com>
EOF
  git -C "$clone" -c credential.helper= -c 'credential.helper=!gh auth git-credential' \
    push --quiet origin "HEAD:refs/heads/$RESULTS_BRANCH"
  echo "Sent: https://github.com/$REPO/blob/$RESULTS_BRANCH/docs/plans/0.6.2/sessions/$SESSION.md"
}

# MARK: - Session B: its questions

# question_b <id>: Session B's questions, in question()'s format; judged ones are Claude's, beside
# the script's measurement where one exists (WP-21), and each has its written criteria and default
# in SESSION-B.md.
question_b() {
  local rest
  case "$1" in
    B-yes) echo "yn|person|The list of changes and the start (PLAN.md §6, the yes-list): y = go ahead" ;;
    B-bedtime) echo "text|person|His bedtime, HH:MM (default: 4 hours after the start)" ;;
    B-charge-capture) echo "yn|person|The Charge Limit 80 → 100 → 80 in the morning-away block, at most 10 minutes at 100 %: y = yes" ;;
    B-keep-widgets) echo "yn|person|Keep the large and extra-large widgets for 0.7's Session R: y = keep" ;;
    B-keep-ax) echo "yn|person|Keep Terminal's Accessibility until Session R: y = keep (default: revoked in the morning)" ;;
    B-slider-auth) echo "2|person|In Session A, did the Charge Limit slider ask for a password or Touch ID? 1 no, 2 yes (the capture then needs him and is not run)" ;;
    B-usage) echo "text|person|What /usage showed at the start" ;;
    B-send) echo "yn|person|Send B.md and the attached images to claude/062-session-b, after the contact sheet and the summary: y = send" ;;
    prep-charge-limit) echo "text|judge|The Charge Limit (pmset -g battlimit, else the Battery pane's shot), in %" ;;
    prep-widget-style) echo "text|judge|System Settings → Appearance → Icon & widget style in prepare's shot: Default, Dark, Clear or Tinted" ;;
    prep-dim-widgets) echo "text|judge|System Settings → Desktop & Dock → Dim widgets on desktop in prepare's shot" ;;
    prep-open-at-login) echo "2|judge|Open at login (BatteryPulse's own toggle, read by AX): 1 on, 2 off" ;;
    prep-wallpaper-kind) echo "3|judge|His wallpaper in prepare's shot: 1 a still picture, 2 a dynamic one, 3 an aerial (restore by computer use from that shot)" ;;
    P3-capture) echo "2|judge|On Clear, -l against -R: 1 -l keeps what lies behind the glass sheet (the same picture), 2 -l leaves it out" ;;
    P4-frames) echo "3|judge|AXMinimized at normal speed, every frame, against Session A's case: 1 enough frames to judge the fill, 2 too few, 3 something else (note)" ;;
    V01-notification) echo "yn|judge|The test notification's banner came, and its press brought BatteryPulse forward" ;;
    V01-notification-front) echo "yn|judge|And again with the BatteryPulse window in front" ;;
    V01-menubar) echo "yn|judge|The menu bar item looks right on a light and on a dark menu bar (the crops)" ;;
    V01-pages) echo "yn|judge|Raw Data, History, Demo Mode on and off, Check Now (its offer closed by its own button) and Clear History, by AX: each worked" ;;
    V01-lid) echo "yn|judge|After his 1-minute lid close: BatteryPulse runs with a current value in the menu bar (the after-lid shot)" ;;
    F11-alert) echo "3|judge|The charge alert: 1 its banner appeared, 2 no banner in time, 3 not run" ;;
    F11-login) echo "2|judge|Login Items after Open at login off: 1 gone, 2 still listed" ;;
    F6-overview | F6-power | F6-history | F6-health | F6-raw)
      echo "yn|judge|F6, ${1#F6-} on real data, against bpulse --json of the same minute: right"
      ;;
    F8-small-en | F8-medium-en | F8-large-en | F8-xlarge-en | F8-small-ru | F8-medium-ru | F8-large-ru | F8-xlarge-ru)
      rest="${1#F8-}"
      echo "4|judge|F8, the RC's ${rest%-*} widget in ${rest#*-}, after the desktop click: 1 right, 2 blank or grey, 3 gone, 4 different (note)"
      ;;
    F9-overview | F9-settings | F9-update) echo "yn|judge|F9 in Russian, ${1#F9-}: no truncation, no English left, the catalog's terms" ;;
    F12-widget) echo "4|judge|After Install and Relaunch, the widget against the before shot: 1 same, 2 blank or grey, 3 gone, 4 different (note)" ;;
    fill-translucent-light-main | fill-translucent-dark-main | fill-clear-light-main | fill-clear-dark-main | \
      fill-translucent-light-compact | fill-translucent-dark-compact | fill-clear-light-compact | fill-clear-dark-compact)
      echo "3|judge|${1#fill-}: while it shrank into the Dock and came back: 1 like the window, or an even graphite grey (the chosen fill), 2 a black frame or rectangle, 3 something else (note)"
      ;;
    SZ-10) echo "yn|person|The Icon Composer icon in the four icon styles (SZ-10): ship it in 0.6.2" ;;
    SUI-17) echo "yn|judge|SUI-17: the previews render" ;;
    *) return 1 ;;
  esac
}

# The order of Session B's answers in status and B.md.
questions_b() {
  local item
  echo B-yes B-bedtime B-keep-ax B-usage
  echo prep-charge-limit prep-widget-style prep-dim-widgets prep-open-at-login prep-widgets prep-wallpaper-kind
  echo P3-capture P4-frames
  echo V01-notification V01-notification-front V01-menubar V01-pages V01-lid
  echo F11-alert F11-login F6-overview F6-power F6-history F6-health F6-raw
  echo F8-small-en F8-medium-en F8-large-en F8-xlarge-en F8-small-ru F8-medium-ru F8-large-ru F8-xlarge-ru
  echo F9-overview F9-settings F9-update F12-widget
  for item in $FILL_CASES_B; do echo "fill-$item"; done
  echo SZ-10 SUI-17 B-send
}

# MARK: - Session B: bookkeeping (PLAN.md §6, WP-21's hands-free mode)

# Session B's files, beside the shared ones (answers.tsv, notes.tsv, sections/).
CHANGES="$WORK/changes.tsv"
RESTORED="$WORK/restored.tsv"
PROOFS="$WORK/proofs.tsv"
MEASURES="$WORK/measures.tsv"
BATCH="$WORK/batch.tsv"
FENCE="$WORK/queue.started"
READY_FILE="$WORK/ready"
HEARTBEAT="$WORK/heartbeat"
# The script's own heartbeat: touched every minute while any acting call runs (heartbeat_keeper), so
# a long command doesn't look like a stall; the arm counts the newer of the two.
SCRIPT_HEARTBEAT="$WORK/heartbeat.script"
# Keep-awake holders seen (time, where, pid, process name, assertion): local only. Their names
# never reach B.md (the privacy lint refuses them) or the repository.
KEEPAWAKE_LOCAL="$WORK/keepawake.local"
MORNING="$WORK/morning-items.txt"
# The crops the script made (window_shot, rect_shot, crop, a clip's darkest frames), each with the
# window style, the wallpaper and the remembered devices it was taken with: the only pictures
# attach publishes in Session B.
PRODUCED="$WORK/produced.tsv"
# The state each of the script's pictures was taken in (shot's full shots and the crops; fields 2-4
# of produced.tsv), the latest line per path: a crop takes its source's, not the state at the crop.
SHOT_STATES="$WORK/shot-states.tsv"
# S5's cover and the minimized TextEdit beside Standard and Frosted: an empty file (no save prompt
# ever comes) whose name no document of his has, so ui aims at its window by title.
COVER="$WORK/bp-062-cover.txt"
COVER_TITLE="bp-062-cover"
# The apps the script opened that weren't running before ("<app>\t<pid>"): restore quits only
# these, never his own Xcode project, documents or settings.
LAUNCHED="$WORK/launched.tsv"
# Posted with the ready file: the arm window's waiter wakes at once instead of at its backstop.
READY_NOTIFY="io.github.nikitausov.BatteryPulse.session-b.ready"
# The English bodies of the test notification and the charge alert (App/BatteryNotifier.swift),
# which `ui banner` looks for.
TEST_NOTIFICATION_TEXT="This is how battery alerts will look"
CHARGE_ALERT_TEXT="You can unplug the power adapter"
# Every B run but the queue's: the queue reads them fresh, and a dry run swaps them out.
DRY_RUN=""

b_only() { [ "$SESSION" = B ] || fail "$1 is a Session B command: run it from the frozen worktree ~/bp-062/B/run"; }

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

# open-app <TextEdit|Xcode>: an app the session needs (Xcode for WP-18's canvas, say), opened by the
# script so restore knows it may quit it.
step_open_app() {
  b_only open-app
  b_fence
  case "${1:-}" in
    TextEdit | Xcode) track_launch "$1" open -a "$1" || fail "can't open $1" ;;
    *) fail "usage: $SCRIPT open-app Xcode | TextEdit" ;;
  esac
  echo "opened $1$(if launched_by_script "$1"; then echo " (restore gui quits it)"; else echo " (it ran already: restore leaves it)"; fi)"
}

# open_pane <name>: a System Settings pane by its URL (proof P8), System Settings tracked.
open_pane() { track_launch "System Settings" open "$(pane_url "$1")"; }

# close_cover: the cover's TextEdit window goes: TextEdit quits when the script opened it, else
# only that window closes (his documents stay open).
close_cover() {
  [ -n "$(app_pid_of TextEdit)" ] || return 0
  if launched_by_script TextEdit; then
    ui_run quit TextEdit >/dev/null 2>&1
  else
    ui_run close TextEdit --window "$COVER_TITLE" >/dev/null 2>&1
  fi
}

# The tools and the frozen scripts the arm runs while sudo's ticket lives ($BIN, this folder,
# scripts/): hashed and made read-only at prepare, and checked by the arm before sudo -v and before
# the queue, so a tool changed or rebuilt from changed code never runs with the ticket.
SEAL="$WORK/seal.tsv"

seal_files() {
  {
    find "$BIN" -type f 2>/dev/null
    find "$HERE" -maxdepth 1 -type f 2>/dev/null
    find "$ROOT/scripts" -maxdepth 1 -type f 2>/dev/null
  } | sort
}

# file_hash <file>: SHA-256 by openssl, else shasum, else MD5 (whichever the Mac has).
file_hash() {
  local hash
  hash="$(openssl dgst -sha256 -r "$1" 2>/dev/null | cut -d' ' -f1)"
  [ -n "$hash" ] || hash="$(shasum -a 256 "$1" 2>/dev/null | cut -d' ' -f1)"
  [ -n "$hash" ] || hash="$(md5 -q "$1" 2>/dev/null)"
  echo "$hash"
}

unseal_tools() {
  chmod -R u+w "$BIN" "$HERE" "$ROOT/scripts" 2>/dev/null || true
  chmod u+w "$SEAL" 2>/dev/null || true
}

seal_tools() {
  local file hash
  write_stamp_script
  : >"$SEAL.tmp"
  while IFS= read -r file; do
    hash="$(file_hash "$file")"
    [ -n "$hash" ] || fail "can't hash $file (no openssl, shasum or md5): the arm couldn't check its tools"
    printf '%s\t%s\n' "$hash" "$file" >>"$SEAL.tmp"
  done < <(seal_files)
  mv "$SEAL.tmp" "$SEAL"
  chmod -R a-w "$BIN" "$HERE" "$ROOT/scripts" 2>/dev/null || true
  chmod a-w "$SEAL"
  echo "sealed $(grep -c . "$SEAL") files (the tools and the frozen scripts): read-only, checked by the arm"
}

# seal_holds: every sealed file as prepare hashed it, no file added, and the frozen worktree's
# tracked files as at its commit.
seal_holds() {
  local hash file
  [ -s "$SEAL" ] || return 1
  while IFS=$'\t' read -r hash file; do
    [ -f "$file" ] && [ "$(file_hash "$file")" = "$hash" ] || return 1
  done <"$SEAL"
  [ "$(seal_files)" = "$(cut -f2 "$SEAL")" ] || return 1
  git -C "$ROOT" diff --quiet HEAD 2>/dev/null
}

# The background processes the morning steps end (the overnight log stream, bpulse --record), by
# their pid files, checked against their command lines.
leftover_running() {
  local pid what
  pid="$(cat "$WORK/$1.pid" 2>/dev/null || true)"
  case "$1" in night-stream) what="log stream" ;; *) what="--record" ;; esac
  [ -n "$pid" ] && kill -0 "$pid" 2>/dev/null && ps -o args= -p "$pid" 2>/dev/null | grep -q -F -- "$what"
}

# stop_leftovers: ends them when `morning` or `charge-limit record stop` didn't (restore morning,
# the next prepare).
stop_leftovers() {
  local name
  for name in night-stream charge-capture; do
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
# wallpaper, and "named" while BatteryPulse remembers an iPhone or iPad by name (outside Demo Mode
# the sidebar's Devices section lists it), else "none".
shot_state() {
  printf '%s\t%s\t%s\n' "$(defaults read "$BUNDLE_ID" windowLook 2>/dev/null || echo standard)" \
    "$(cat "$WORK/wallpaper-now" 2>/dev/null || echo his)" \
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
  [ "$SESSION" = B ] && [ -s "$1" ] || return 0
  local state
  if [ -n "${2:-}" ]; then state="$(source_state "$2")"; else state="$(shot_state)"; fi
  mkdir -p "$WORK"
  printf '%s\t%s\n' "$(abs_path "$1")" "$state" >>"$PRODUCED"
  log_shot_state "$1" "$state"
}

# attach_allowed <image>: Session B publishes only the script's own crops (under shots/ or
# recordings/), never a picture the size of the display (the Dock, the menu bar's extras, his
# desktop's file names, a banner), and a Clear, Translucent or Frosted one only when it was taken
# on the generated bright or busy wallpaper, since glass shows what lies behind it.
attach_allowed() {
  local path line style paper size screen
  path="$(abs_path "$1")"
  case "$path" in
    "$SHOTS"/* | "$REC"/*) ;;
    *) fail "only the script's own crops under shots/ or recordings/ are attached, not $1" ;;
  esac
  line="$(awk -F '\t' -v p="$path" '$1 == p { l = $0 } END { print l }' "$PRODUCED" 2>/dev/null || true)"
  [ -n "$line" ] || fail "$(basename "$1") isn't a crop the script made (a window or rectangle shot, crop, a clip's darkest frame): a full shot never leaves the Mac; crop it first ($SCRIPT crop ...)"
  # A remembered device shows by name in the sidebar: judged by the state the picture was taken in,
  # so the morning's restore (his own devices back) refuses only what is taken after it.
  [ "$(cut -f4 <<<"$line")" = none ] ||
    fail "$(basename "$1") was taken while BatteryPulse remembered an iPhone or iPad by name, which the sidebar shows: it is never attached; after WP-23's device check, $SCRIPT devices forget, then take it again (after restore morning his own devices are back: take it before)"
  style="$(cut -f2 <<<"$line")"
  paper="$(cut -f3 <<<"$line")"
  case "$style:$paper" in
    clear:bright | clear:busy | translucent:bright | translucent:busy | frosted:bright | frosted:busy) ;;
    clear:* | translucent:* | frosted:*)
      fail "a $style shot shows what lies behind its glass: only one taken on the generated bright or busy wallpaper is attached ($(basename "$1") was taken on $paper)"
      ;;
  esac
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

# publish_sheet: the contact sheet of every attached image, in B.md's order, for him to see with
# B.md's summary before his B-send (send --dry-run builds it).
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
  echo "SHEET $WORK/publish-sheet.png: every attached image; open it for him with B.md's summary, then his B-send"
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

# <folder>/continued is newer than <folder>/<file>: his continue came after it.
continued_after() { [ -f "$1/continued" ] && [ -f "$1/$2" ] && [ "$1/continued" -nt "$1/$2" ]; }

is_away() { [ -f "$WORK/away" ] && ! continued_after "$WORK" away; }

# sound <name>: a system sound, but none from `mark away` until his morning continue (WP-21).
sound() {
  if is_away; then return 0; fi
  afplay "/System/Library/Sounds/$1.aiff" >/dev/null 2>&1 || true
}

# cue <text>: a sound and a notification while he is there (B0, B1); nothing once he is away.
cue() {
  if is_away; then return 0; fi
  sound Glass
  osascript -e 'on run argv' -e 'display notification (item 1 of argv) with title "BatteryPulse Session B"' \
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
# pbi_start_tvsec): arm.pid and queue.started hold it beside the pid, so a later process that got
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

# arm_of <file>: the arm window's "<pid> <start>", the first two fields of arm.pid or queue.started.
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

# b_fence: once `ready` is up, or while queue.started exists, no command acts until his morning
# continue (§6 "Never act after ready"); a continue counts only when it is newer than ready. `ui`
# enforces the same for itself, and night_fence for every run of this script.
b_fence() {
  if [ -f "$FENCE" ] && ! caller_is_arm; then
    fail "the energy queue runs ($FENCE exists): results in the morning; nothing was done"
  fi
  if [ -f "$READY_FILE" ] && ! continued_after "$WORK" ready && ! caller_is_arm; then
    fail "ready is up: nothing acts until his morning continue; nothing was done"
  fi
  night_fence
}

# The arm window of ~/bp-062/B (arm.pid, or queue.started) is this call's ancestor.
caller_is_b_arm() { arm_is_ancestor "$B_HOME/arm.pid" || arm_is_ancestor "$B_HOME/queue.started"; }

# night_fence: Session B's fence for every run of this script, wherever it runs from and whatever
# its own folder (his checkout, Session A's commands): ~/bp-062/B's queue.started, or its ready
# without a newer continue, stops every acting command but the arm's own.
night_fence() {
  if [ -f "$B_HOME/queue.started" ] && ! caller_is_b_arm; then
    fail "Session B's energy queue runs ($B_HOME/queue.started exists): nothing acts until the morning; nothing was done"
  fi
  if [ -f "$B_HOME/ready" ] && ! continued_after "$B_HOME" ready && ! caller_is_b_arm; then
    fail "Session B's ready is up ($B_HOME/ready): nothing acts until his morning continue (an earlier attempt's, at a new start: $SCRIPT prepare attempt moves it aside); nothing was done"
  fi
  return 0
}

# The bedtime he gave at the start (B-bedtime, HH:MM), as an epoch after prepare; else 4 hours
# after prepare.
bedtime_epoch() {
  local start hm day epoch
  start="$(cat "$WORK/prepare.epoch" 2>/dev/null || date +%s)"
  hm="$(answer_of B-bedtime)"
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

# The GUI phase stops 10 minutes before his bedtime, or 4 hours after the start (B2).
gui_end_epoch() {
  local start bedtime cap
  start="$(cat "$WORK/prepare.epoch" 2>/dev/null || date +%s)"
  bedtime="$(bedtime_epoch)"
  cap=$((start + 4 * 3600))
  if [ $((bedtime - 600)) -lt "$cap" ]; then cap=$((bedtime - 600)); fi
  echo "$cap"
}

gui_minutes_left() {
  local left
  left=$(($(gui_end_epoch) - $(date +%s)))
  if [ "$left" -lt 0 ]; then left=0; fi
  echo $((left / 60))
}

# heartbeat [<step and expected ready time>]: touched by every Session B call; with text, the
# state the arm window shows.
step_heartbeat() {
  b_only heartbeat
  if [ $# -gt 0 ]; then
    english_only "$*"
    printf '%s\t%s\n' "$(clock)" "$*" >"$WORK/state"
  fi
  echo "heartbeat $(clock); GUI phase: $(gui_minutes_left) minutes left (it stops at $(epoch_hm "$(gui_end_epoch)"))"
}

# heartbeat_keeper: the script's own heartbeat while this call runs: heartbeat.script touched every
# minute until the call ends (cleanup ends it too), so pages profiling, xctrace, the installs, burst,
# memory, f11 alert's wait or a case's recordings never look like a stall to the arm window (the
# first attempt's stale path came from a 20-minute background run). At most 45 minutes, longer than
# any step takes, so a hung call still lets the arm's stale path start the queue. Its output goes
# nowhere, so the Bash tool doesn't wait for it.
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
  b_only change
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
  b_only restored
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

# MARK: - Session B: measurements paired with judgments

# measure <id> <kind> <arguments>: the script's half of a judgment, stored for `judge`:
#   black <frames folder>         the darkest frame inside the window's rectangle: 2 (a black frame)
#                                 below luma 0.06 with 40 % dark pixels, 1 above luma 0.12
#   blank <image> [x y w h]       luma's spread: 2 (blank or grey) below 0.02, else "!2" (anything
#                                 but blank: the spread can't tell right from gone or different)
#   same <image> <image> [x y w h] identical pixels: y, else n (V1b)
#   differs <image> <image> [x y w h] more than 1 % of the pixels changed: y, else n (the menu bar)
# The suggestion is "-" where the numbers sit between the thresholds.
step_measure() {
  b_only measure
  [ $# -ge 3 ] || fail "usage: $SCRIPT measure <id> black|blank|same|differs <arguments>"
  [ -x "$BIN/frames" ] || fail "the frame helper isn't built (see $BIN/frames.log)"
  local id="$1" kind="$2" line suggestion="-" value
  shift 2
  question "$id" >/dev/null || fail "no question $id"
  case "$kind" in
    black)
      [ -f "$1/frames.tsv" ] || fail "no frames.tsv in $1"
      line="$(awk -F '\t' 'NR > 1 && $7 != "-" { if (best == "" || $8 + 0 > dark + 0) { best = $1; luma = $7; dark = $8 } }
        END { if (best != "") print best, luma, dark }' "$1/frames.tsv")"
      [ -n "$line" ] || fail "frames.tsv has no rectangle columns: dump with --rect"
      value="darkest frame $(echo "$line" | awk '{ printf "%s, luma %s, %s %% dark", $1, $2, $3 }')"
      suggestion="$(echo "$line" | awk '{ if ($2 < 0.06 && $3 >= 40) print 2; else if ($2 >= 0.12) print 1; else print "-" }')"
      ;;
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
    *) fail "a measure is black, blank, same or differs" ;;
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
# or two-way question, "unsure") with the note, and the item joins the morning batch.
step_judge() {
  b_only judge
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
    note="for the morning batch: claude read $read${note:+; $note}"
  fi
  step_answer --by claude "$id" "$value" "$note"
}

# batch: the morning batch (B7): his y questions, the contact sheets per style, and every item
# the session answered 3 or unsure.
step_batch() {
  b_only batch
  local id
  echo "The morning batch (optional: each item he skips keeps its gate's default):"
  if [ -n "$(answer_of SZ-10)" ] || [ -d "$WORK/wp18-icon" ]; then ask SZ-10; fi
  if [ -s "$BATCH" ]; then
    echo "Items the session answered 3 or unsure (look at each crop, then answer):"
    while IFS=$'\t' read -r id _ note crop; do
      ask "$id"
      echo "  note: $note"
      [ -z "$crop" ] || echo "  evidence: $crop"
    done <"$BATCH"
  fi
}

# MARK: - Session B: the hands (ui), the windows and the shots

# ui <command...>: the ui helper. It reads what preflight and the session recorded (PLAN.md WP-21)
# from ~/bp-062/B itself, never from the environment: the tap (ui-tap, P6), the widget hosts
# (ui-hosts, P1), the System Settings panes it may act in (ui-panes, P8), the widgets' frames
# (widgets.tsv, `widget`) and the apps the script opened (launched.tsv). Every action passes its own
# safety rules, the fences among them.
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
  b_only ui
  ui_run "$@"
}

# launch_b [arguments...]: the installed app without its saved windows, in English for the GUI
# phase's AX labels (a launch argument only; no setting changes).
launch_b() {
  open "$APP" --args -ApplePersistenceIgnoreState YES -AppleLanguages "(en)" "$@"
  local tries=0
  until app_running || [ "$tries" -ge 40 ]; do
    sleep 0.25
    tries=$((tries + 1))
  done
  app_running || warn "BatteryPulse didn't start within 10 s"
  note_rc_pid
  sleep 2
}

# note_rc_pid: the running app's pid into rc-pids.txt when the installed build is the RC (or its
# profiling twin, which shares its build number), for `v01 morning`'s executor count: build B's
# runs, and the real 0.6.1 after F12, don't count against the RC.
note_rc_pid() {
  local rc
  rc="$(awk -F '\t' '$1 == "C" { print $3 }' "$WORK/builds.tsv" 2>/dev/null || true)"
  [ -n "$rc" ] && [ "$(installed_build)" = "$rc" ] && app_running || return 0
  app_pid >>"$WORK/rc-pids.txt"
}

relaunch_b() {
  quit_app
  session_settings
  launch_b
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
# -R <frame> (or by window ID where proof P3 showed it keeps what lies behind a glass sheet).
window_shot() {
  local file="$1" line rect id
  line="$(main_window_line "${2:-}")"
  if ! line_ok "$line"; then
    echo "the main window isn't clear: ${line:-not on screen}" >&2
    return 1
  fi
  id="$(line_id "$line")"
  rect="$(line_rect "$line")"
  mkdir -p "$(dirname "$file")"
  if [ "$(cat "$WORK/shot-method" 2>/dev/null || echo R)" = l ]; then
    screencapture -x -o -l"$id" "$file"
  else
    screencapture -x -R"$(tr ' ' ',' <<<"$rect")" "$file"
  fi
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
    *) return 1 ;;
  esac
}

PANES="appearance desktop displays accessibility login-items battery date-time wallpaper"

step_pane() {
  b_only pane
  b_fence
  local url
  url="$(pane_url "${1:-}")" || fail "usage: $SCRIPT pane <$(echo "$PANES" | tr ' ' '|')>"
  track_launch "System Settings" open "$url"
  sleep 2
  # The sidebar's selection and the title; ui acts only in a pane P8 confirmed.
  ui_run pane-state --expect "$1" || true
}

# widget <family> <x> <y> <w> <h>: a placed widget's frame in points (from proof P1's `ui hit`),
# for F8's and F12's crops and for ui's window-list rule and `tree --inside`. AX can't move
# widgets, so their frames come from here. A frame is recorded only when it is no larger than its
# family's widget (one in pixels is twice as large) and `ui hit` finds a widget host's element
# labelled BatteryPulse at its centre.
step_widget() {
  b_only widget
  [ $# -eq 5 ] || fail "usage: $SCRIPT widget small|medium|large|xlarge <x> <y> <w> <h>"
  local limit number hit bundle
  # ui.swift's Rules.widgetLimits, in points, with room to spare.
  case "$1" in
    small) limit="220 220" ;;
    medium) limit="440 220" ;;
    large) limit="440 460" ;;
    xlarge) limit="880 460" ;;
    *) fail "a family is small, medium, large or xlarge" ;;
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
  b_only desktop-spot
  local probe
  probe="$(ui_run click "$@" --expect desktop --probe 2>&1)" || fail "that point isn't the bare desktop: $probe"
  # <x> <y> in points, or --image <png> <x> <y>, which ui converts at every click.
  printf '%s --expect desktop\n' "$*" >"$WORK/desktop-spot.args"
  echo "desktop spot: $(cat "$WORK/desktop-spot.args")"
}

# click_desktop: the fixed action before a widget comparison: a click on the empty desktop spot,
# then 1 s; with click-to-show-desktop on, again, checked with ui windows. Each click is refused
# unless the bare desktop is still what lies there.
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
  if [ "$(cat "$WORK/click-to-show-desktop" 2>/dev/null || echo 0)" = 1 ]; then
    # shellcheck disable=SC2046
    ui_run click $(cat "$WORK/desktop-spot.args") >/dev/null || return 1
    sleep 1
    ui_run windows >"$LOGS/windows-after-desktop-click.txt" 2>&1 || true
  fi
}

# MARK: - Session B: prepare (step 1, B0a and B0b)

# The RC's CI run: pinned by D1 (RUN_RC), else the newest successful CI run of the integration
# branch at the frozen commit or an ancestor with the same code that holds D1's 0.5.99 DMG (the
# dispatch with version 0.5.99 and profiling on, whose run also holds the profiling DMG). A later
# push of the same code (the ceilings' commit, say) is newer but builds 0.0.0, so it is only the
# fallback when no such dispatch is found.
rc_locate() {
  RC_RUN="$RUN_RC"
  RC_ARTIFACT="$ARTIFACT_RC"
  RC_ARTIFACT_P="$ARTIFACT_RCP"
  [ -z "$RC_RUN" ] || return 0
  local head run sha names artifact fallback=""
  head="$(git -C "$ROOT" rev-parse HEAD)"
  while IFS=$'\t' read -r run sha; do
    [ -n "$run" ] || continue
    git -C "$ROOT" merge-base --is-ancestor "$sha" "$head" 2>/dev/null || continue
    git -C "$ROOT" diff --quiet "$sha" "$head" -- Sources Resources Package.swift scripts/build-app.sh 2>/dev/null || continue
    names="$(gh api "repos/$REPO/actions/runs/$run/artifacts?per_page=100" --jq '.artifacts[] | select(.expired | not) | .name' 2>/dev/null || true)"
    artifact="$(grep -x "BatteryPulse-0\\.5\\.99-$sha" <<<"$names" || true)"
    if [ -n "$artifact" ]; then
      RC_RUN="$run"
      RC_ARTIFACT="$artifact"
      RC_ARTIFACT_P="$(grep -x "BatteryPulse-profiling-0\\.5\\.99-$sha" <<<"$names" || true)"
      echo "the RC: run $run ($RC_ARTIFACT), commit ${sha:0:7}; profiling: ${RC_ARTIFACT_P:-none}"
      return 0
    fi
    if [ -z "$fallback" ] && grep -q -x "BatteryPulse-$sha" <<<"$names"; then
      fallback="$run$TAB$sha$TAB$(grep -x "BatteryPulse-profiling-$sha" <<<"$names" || true)"
    fi
  done < <(gh run list -R "$REPO" -b "$INTEGRATION_BRANCH" -w ci.yml -s success -L 30 --json databaseId,headSha \
    --jq '.[] | [.databaseId, .headSha] | @tsv' 2>/dev/null || true)
  [ -n "$fallback" ] || fail "no CI run of the RC with this code; D1 pins RUN_RC in the script"
  IFS=$'\t' read -r RC_RUN sha RC_ARTIFACT_P <<<"$fallback"
  RC_ARTIFACT="BatteryPulse-$sha"
  warn "no 0.5.99 dispatch of this code: the RC is run $RC_RUN's push build (0.0.0), commit ${sha:0:7}; profiling: ${RC_ARTIFACT_P:-none}"
}

fetch_builds_b() {
  mkdir -p "$BUILDS"
  if [ ! -f "$BUILDS/B.dmg" ]; then
    rm -rf "$BUILDS/B.download"
    mkdir -p "$BUILDS/B.download"
    gh release download "$TAG_B" -R "$REPO" -p BatteryPulse.dmg -D "$BUILDS/B.download" ||
      fail "can't download the $TAG_B DMG"
    mv "$BUILDS/B.download/BatteryPulse.dmg" "$BUILDS/B.dmg"
    rm -rf "$BUILDS/B.download"
    describe_build B "release $TAG_B"
  fi
  if [ ! -f "$BUILDS/C.dmg" ] || { [ ! -f "$BUILDS/CP.dmg" ] && [ ! -f "$BUILDS/CP.none" ]; }; then rc_locate; fi
  [ -f "$BUILDS/C.dmg" ] || fetch_artifact C "$RC_RUN" "$RC_ARTIFACT" BatteryPulse.dmg
  if [ ! -f "$BUILDS/CP.dmg" ] && [ ! -f "$BUILDS/CP.none" ]; then
    if [ -n "${RC_ARTIFACT_P:-}" ] && (fetch_artifact CP "$RC_RUN" "$RC_ARTIFACT_P" BatteryPulse-profiling.dmg); then :; else
      echo "no profiling RC" >"$BUILDS/CP.none"
      warn "no profiling RC: step 5's profiling pass is not run"
    fi
  fi
}

# attempt_head: the frozen worktree's commit, which names this attempt (~/bp-062/B/attempt).
attempt_head() { git -C "$ROOT" rev-parse HEAD 2>/dev/null || echo unknown; }

# attempt_current: ~/bp-062/B is this attempt's (its attempt file names this worktree's commit).
attempt_current() { [ "$(cat "$WORK/attempt" 2>/dev/null || true)" = "$(attempt_head)" ]; }

# attempt_fence: every acting Session B call but `prepare attempt` needs this attempt's folder, so
# nothing is written into an earlier attempt's files (off the Mac, dry runs pass).
attempt_fence() {
  [ "$(uname -s)" = Darwin ] || return 0
  attempt_current && return 0
  fail "$WORK isn't this attempt's yet (no attempt file for $(attempt_head | cut -c1-7)): $SCRIPT prepare attempt first, B0a's first call; nothing was done"
}

# prepare attempt [--kept <setting>[,...]] [--restored <setting>[,...] "<how>"] (B0a's first call,
# right after the worktree): a clean start. A ~/bp-062/B that holds an earlier attempt's files (no
# attempt file, or another commit's) moves aside to ~/bp-062/B-attempt-<that attempt's date>, never
# deleted, once no arm window of that attempt runs and every change its changes.tsv lists was put
# back (restored.tsv). Until then attempt_fence refuses `restored`, so the two options record it
# here: --restored, the session put a setting back at the new start and confirmed it (how: the
# shot); --kept, his word that he keeps a setting as that attempt left it. That attempt's fences
# (ready, queue.started) go with it, so this runs before them. Its worktree, which B0a moved to
# run-<commit>, goes along, and git is told where it went. Nothing is written to the attempt file
# unless everything moved.
step_attempt_b() {
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
    for file in "$WORK/arm.pid" "$WORK/queue.started"; do
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
    dest="$ACCOUNT_HOME/bp-062/B-attempt-$when"
    while [ -e "$dest" ]; do
      n=$((n + 1))
      dest="$ACCOUNT_HOME/bp-062/B-attempt-$when-$n"
    done
    mkdir -p "$dest"
    # seal_tools left bin read-only (restore morning unseals it), and a directory moves to another
    # parent only when it is writable (its .. entry changes).
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

# prepare [--fresh-backup] (B0a): the backup into ~/bp-062/B, the builds and tools, the RC
# installed, then a beep. Only after his yes to the list of changes (answer B-yes y).
step_prepare_b() {
  check_tools
  [ "$(answer_of B-yes)" = y ] || fail "first his one yes to the list of changes: $SCRIPT answer --by person B-yes y"
  # Once the session has changed his app and data, a fresh backup would keep the session's state
  # (the RC, no remembered devices) as his.
  if [ "${1:-}" = --fresh-backup ] && [ -n "$(original_of app)" ]; then
    fail "the session has changed his app and data already (changes.tsv): a fresh backup now would keep the session's state as his; nothing was done"
  fi
  mkdir -p "$WORK" "$BUILDS" "$BIN" "$SHOTS" "$REC" "$LOGS" "$SECTIONS"
  touch "$CHANGES" "$HEARTBEAT"
  # S5's cover and the minimized TextEdit beside Standard and Frosted (COVER).
  [ -f "$COVER" ] || : >"$COVER"
  cd "$ROOT"
  backup "${1:-}"
  if [ ! -f "$WORK/prepare.time" ] || [ "${1:-}" = --fresh-backup ]; then
    clock >"$WORK/prepare.time"
    date +%s >"$WORK/prepare.epoch"
    touch "$WORK/prepare.marker"
  fi
  stop_leftovers
  unseal_tools
  fetch_builds_b
  build_tools
  seal_tools
  begin_section 00-prepare "Prepare (B0a)"
  out "- prepared: $(cat "$WORK/prepare.time"); macOS $(sw_vers -productVersion) ($(sw_vers -buildVersion)); the frozen script at $(git -C "$ROOT" rev-parse --short HEAD 2>/dev/null || echo unknown)"
  out "- installed before the session: $(cat "$BACKUP/version")"
  out "- defaults domain: $(plutil -convert xml1 -o - "$BACKUP/defaults.plist" | grep -c '<key>' || true) keys backed up"
  if [ -d "$BACKUP/support" ]; then
    out "- Application Support: $(find "$BACKUP/support" -type f | wc -l | tr -d ' ') files, $(du -sk "$BACKUP/support" | cut -f1) KB backed up"
  fi
  out "- Low Power Mode: battery $(cat "$BACKUP/lowpowermode-battery"), adapter $(cat "$BACKUP/lowpowermode-ac")"
  out "- charge: $(battery_percent) %, $(if on_battery; then echo on battery; else echo on the adapter; fi)"
  out "- his bedtime: $(epoch_hm "$(bedtime_epoch)"); the GUI phase stops at $(epoch_hm "$(gui_end_epoch)")"
  out "- not in this attempt (PLAN.md §6, after the first attempt of 2026-10-27): G-13b's evidence (both styles stay beta), the burst (S8), memory, WP-23's device check, the optional extras and the morning-away block"
  out "- tools: ui $(if [ -x "$BIN/ui" ]; then echo built; else echo "not built"; fi), frames $(if [ -x "$BIN/frames" ]; then echo built; else echo "not built"; fi), bpulse $(if [ -x "$BIN/bpulse" ]; then echo built; else echo "not built"; fi)"
  out ""
  out "| Build | Version | CFBundleVersion | Source |"
  out "|---|---|---|---|"
  local name version build origin
  while IFS=$'\t' read -r name version build origin; do
    out "| $name | $version | $build | $origin |"
  done <"$WORK/builds.tsv"
  if [ -z "$(original_of app)" ]; then
    record_change app "$(cat "$BACKUP/version")" "the RC"
    record_change bp-settings "his settings (backup)" "the session's settings"
    record_change bp-support "his data (backup)" "the session's data"
    record_change widget-data "none" "the RC's widget data"
  fi
  # His remembered iPhones and iPads: outside Demo Mode the sidebar's Devices section lists them by
  # name, so every shot of the main window would show them. They stay in the backup, which
  # restore_all puts back, and are gone for the session.
  if [ -d "$SUPPORT/Devices" ]; then
    [ -d "$BACKUP/support/Devices" ] || fail "his remembered devices aren't in the backup ($BACKUP/support/Devices): nothing was removed"
    [ -n "$(original_of remembered-devices)" ] || record_change remembered-devices "his (backup)" "none during the session"
    quit_app
    rm -rf "$SUPPORT/Devices"
  fi
  install_build C --no-launch
  relaunch_b
  sound Glass
  echo "BEEP (B0a is done): when he is back and has quit his own apps: $SCRIPT prepare reads"
}

# devices forget: right after WP-23's optional device check, before `mark away`. The iPhone or iPad
# it plugged in is now remembered by name, which the sidebar shows, so no picture taken from then
# on is attached. Only the session's own device store goes: his remembered devices stay in the
# backup, which restore_all puts back, so once restore morning has begun nothing is removed.
step_devices() {
  b_only devices
  [ $# -eq 1 ] && [ "$1" = forget ] || fail "usage: $SCRIPT devices forget"
  [ -f "$BACKUP/done" ] || fail "no backup in $BACKUP: nothing was removed"
  [ -n "$(original_of bp-support)" ] || fail "prepare hasn't put the session's data in place: nothing was removed"
  if is_restored bp-support || [ -f "$SECTIONS/95-restore.md" ]; then
    fail "restore morning has begun (his data goes back): his remembered devices stay; nothing was removed"
  fi
  if [ ! -d "$SUPPORT/Devices" ]; then
    echo "BatteryPulse remembers no device"
    return 0
  fi
  if [ -d "$BACKUP/support/Devices" ] && diff -rq "$BACKUP/support/Devices" "$SUPPORT/Devices" >/dev/null 2>&1; then
    fail "$SUPPORT/Devices is the backup's (his remembered devices): nothing was removed"
  fi
  quit_app
  # Its name stays a privacy term for B.md (privacy_terms), in a file that never leaves the Mac.
  cat "$SUPPORT/Devices/devices.json" >>"$WORK/devices-forgotten.json" 2>/dev/null || true
  rm -rf "$SUPPORT/Devices"
  date +%s >"$WORK/devices-forgot"
  # relaunch_b turns readDevices off again (session_settings), so nothing reads the device anew.
  relaunch_b
  [ "$(cut -f3 <<<"$(shot_state)")" = none ] || fail "BatteryPulse remembers a device by name again ($SUPPORT/Devices/devices.json)"
  echo "forgot the session's remembered devices at $(clock): a picture taken from now on may be attached"
}

# prepare reads (B0b): what Session A asked, read instead (WP-21): the Charge Limit, the style keys,
# Open at login, click-to-show-desktop, the hot corners, the screen saver, the wallpaper; the
# generated wallpapers; the shots Claude reads.
step_prepare_reads() {
  b_fence
  begin_section 01-reads "Prepare's reads (B0b)"
  local limit corner value screen width height scale kind path name
  pmset -g battlimit >"$LOGS/battlimit.txt" 2>&1 || true
  limit="$(grep -o -E '[0-9]+ ?%' "$LOGS/battlimit.txt" | head -1 | tr -d ' %' || true)"
  if [ -n "$limit" ]; then
    step_answer --by claude prep-charge-limit "$limit" "read by pmset -g battlimit" >/dev/null
    out "- Charge Limit: $limit % (pmset -g battlimit)"
  else
    out "- Charge Limit: pmset -g battlimit shows none (below the limit it may not; plan-0.7.0 Appendix C finding 9): read from the Battery pane"
    open_pane battery
    sleep 2
    shot settings-battery
    ask prep-charge-limit
  fi
  defaults read -g >"$BACKUP/global-defaults.txt" 2>/dev/null || true
  defaults read com.apple.WindowManager >"$BACKUP/windowmanager.txt" 2>/dev/null || true
  value="$(defaults read com.apple.WindowManager EnableStandardClickToShowDesktop 2>/dev/null || echo unknown)"
  echo "$value" >"$WORK/click-to-show-desktop"
  out "- click-to-show-desktop (EnableStandardClickToShowDesktop): $value"
  out "- hot corners: $(for corner in tl tr bl br; do printf '%s=%s ' "$corner" "$(defaults read com.apple.dock "wvous-$corner-corner" 2>/dev/null || echo 0)"; done)"
  value="$(defaults -currentHost read com.apple.screensaver idleTime 2>/dev/null || echo unknown)"
  echo "$value" >"$WORK/screensaver-idle"
  out "- the screen saver's idle time: $value s"
  out "- AppleICUForce24HourTime: $(defaults read -g AppleICUForce24HourTime 2>/dev/null || echo unset)"
  kind=still
  while IFS= read -r path; do
    [ -n "$path" ] || continue
    case "$path" in
      *.png | *.jpg | *.jpeg | *.tif | *.tiff | *.bmp | *.PNG | *.JPG | *.JPEG) ;;
      *.heic | *.HEIC) if [ "$kind" = still ]; then kind="still or dynamic (a HEIC)"; fi ;;
      *) kind="dynamic or aerial" ;;
    esac
  done <"$BACKUP/wallpapers"
  [ -s "$BACKUP/wallpapers" ] || kind="unknown (System Events gave no picture)"
  echo "$kind" >"$WORK/wallpaper-kind"
  out "- the wallpaper: $kind; $(grep -c . "$BACKUP/wallpapers" || true) desktops (paths kept on the Mac)"
  screen="$(ui_run screen 2>/dev/null || true)"
  out "- display: $(sed 's/ corners.*//' <<<"$screen")"
  width="$(sed -n 's/^main=[-0-9]* [-0-9]* \([0-9]*\) [0-9]* .*/\1/p' <<<"$screen")"
  height="$(sed -n 's/^main=[-0-9]* [-0-9]* [0-9]* \([0-9]*\) .*/\1/p' <<<"$screen")"
  scale="$(sed -n 's/.* scale=\([0-9.]*\).*/\1/p' <<<"$screen")"
  if [ -n "$width" ] && [ -n "$height" ] && [ -x "$BIN/frames" ]; then
    width="$(awk -v w="$width" -v s="${scale:-2}" 'BEGIN { printf "%d", w * s }')"
    height="$(awk -v h="$height" -v s="${scale:-2}" 'BEGIN { printf "%d", h * s }')"
    "$BIN/frames" wallpaper bright "$WORK/wallpaper-bright.png" "$width" "$height" >/dev/null
    "$BIN/frames" wallpaper busy "$WORK/wallpaper-busy.png" "$width" "$height" >/dev/null
    out "- generated wallpapers: bright and busy, ${width}×${height}"
  else
    not_checked wallpapers "can't read the display's size: the screenshot set keeps his wallpaper"
  fi
  ui_run windows >"$LOGS/windows-prepare.txt" 2>&1 || true
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
  out "- Open at login (AX): $value"
  # grep's status tells "no Focus" (1) from a file that is missing or that the privacy rules keep
  # from Terminal (2), which a -r test can't see.
  value=0
  grep -q '"storeAssertionRecords" *: *\[ *{' "$HOME/Library/DoNotDisturb/DB/Assertions.json" 2>/dev/null || value=$?
  case "$value" in
    0) out "- Focus: on" ;;
    1) out "- Focus: off" ;;
    *) out "- Focus: not readable (his word at the start)" ;;
  esac
  for name in appearance desktop; do
    open_pane "$name"
    sleep 2
    shot "settings-$name"
  done
  quit_if_launched "System Settings"
  shot prepare-desktop
  echo "Read the shots (they stay on the Mac), then answer:"
  ask prep-widgets prep-widget-style prep-dim-widgets prep-wallpaper-kind
  echo "Then the widgets' frames from proof P1 ($SCRIPT proof P1 --image <shot> <x> <y>; $SCRIPT widget <family> x y w h),"
  echo "an empty desktop spot ($SCRIPT desktop-spot --image <shot> <x> <y>), and: $SCRIPT preflight"
}

# MARK: - Session B: proofs and preflight (B0b; PLAN.md §6 "Proofs")

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

# The assertions that declare a person at the Mac or keep it or its display awake. Another app
# holding one spoils every energy run: in the first attempt a keep-awake utility in the menu bar
# declared user activity all evening, HIDIdleTime never passed 95 s, and every run was "touched".
KEEPAWAKE_TYPES="UserIsActive PreventUserIdleDisplaySleep PreventUserIdleSystemSleep NoIdleSleepAssertion NoDisplaySleepAssertion"

# holder_is_ours <pid> <name>: an assertion holder that doesn't count: the system's own (an
# executable under /System, /usr, /bin, /sbin or /Library/Apple, or inside an app whose bundle
# identifier is Apple's), BatteryPulse, the Claude CLI, or a caffeinate that this script, the arm
# window or the Claude CLI started (an ancestor of it is one of them; the queue's Claude detector
# covers the CLI). Any other caffeinate counts (a utility may run one, or he did).
holder_is_ours() {
  local pid="$1" name="$2" path parent app bundle claude hops=0
  path="$(ps -o comm= -p "$pid" 2>/dev/null || true)"
  # Gone since pmset listed it: its assertion went with it.
  [ -n "$path" ] || return 0
  claude="$(claude_pids)"
  if grep -qx -- "$pid" <<<"$claude"; then return 0; fi
  if [ "$name" = caffeinate ] || [ "${path##*/}" = caffeinate ]; then
    parent="$pid"
    while [ "$hops" -lt 12 ]; do
      parent="$(ps -o ppid= -p "$parent" 2>/dev/null | tr -d ' ' || true)"
      case "$parent" in "" | 0 | 1) return 1 ;; esac
      if ps -o args= -p "$parent" 2>/dev/null | grep -q -F 'm5-session.sh'; then return 0; fi
      if grep -qx -- "$parent" <<<"$claude"; then return 0; fi
      hops=$((hops + 1))
    done
    return 1
  fi
  case "$path" in
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

# keepawake_holders: "<pid>\t<name>\t<assertion>" for each such assertion another process holds
# (pmset -g assertions' per-process lines). The names are for the session and the arm window only.
keepawake_holders() {
  local pid name type
  pmset -g assertions 2>/dev/null | awk -v types=" $KEEPAWAKE_TYPES " '
    /^ *pid [0-9]+\(/ {
      line = $0
      sub(/^ *pid /, "", line)
      pid = line; sub(/\(.*/, "", pid)
      name = line; sub(/^[0-9]+\(/, "", name); sub(/\): \[.*/, "", name)
      rest = line; sub(/.*\] [0-9:]+ /, "", rest)
      split(rest, w, " ")
      if (index(types, " " w[1] " ") > 0) printf "%s\t%s\t%s\n", pid, name, w[1]
    }' |
    while IFS="$TAB" read -r pid name type; do
      holder_is_ours "$pid" "$name" || printf '%s\t%s\t%s\n' "$pid" "$name" "$type"
    done
}

# keepawake_names <holders>: the processes' names, comma-joined (for the session and the arm only).
keepawake_names() { cut -f2 <<<"$1" | grep . | sort -u | tr '\n' ',' | sed 's/,$//; s/,/, /g'; }

# keepawake_record <where> <holders>: the holders into keepawake.local (never B.md).
keepawake_record() {
  [ -n "$2" ] || return 0
  mkdir -p "$WORK"
  awk -F '\t' -v at="$(clock)" -v where="$1" 'NF { print at "\t" where "\t" $1 "\t" $2 "\t" $3 }' <<<"$2" >>"$KEEPAWAKE_LOCAL"
}

# keepawake_check: preflight's read of the keep-awake assertions. The names go to the session (a
# KEEPAWAKE line) and keepawake.local; B.md gets the count.
keepawake_check() {
  local holders
  holders="$(keepawake_holders)"
  keepawake_record preflight "$holders"
  out "- keep-awake assertions of other processes (user activity, display or idle sleep): $(grep -c . <<<"$holders" || true) (names stay on the Mac)"
  if [ -n "$holders" ]; then
    awk -F '\t' '{ print "KEEPAWAKE (local only: never in a note, an answer or B.md): " $2 " (pid " $1 ") holds " $3 }' <<<"$holders"
    echo "DO (person): quit $(keepawake_names "$holders") now (its menu bar icon or its Dock icon, Quit); then: $SCRIPT preflight quiet"
    return 1
  fi
}

# quiet_check: HIDIdleTime must grow while nobody touches the Mac and nothing posts an event: 70 s.
# Below 65 s at the end, something declares user activity (a keep-awake holder, named locally) or
# posts input events (a mouse mover holds no assertion), or he touched it.
quiet_check() {
  local start end holders
  echo "DO (person): please don't touch the Mac for 70 seconds (the quiet check)."
  start="$(idle_seconds)"
  sleep 70
  end="$(idle_seconds)"
  if awk -v e="$end" 'BEGIN { exit !(e != "" && e + 0 >= 65) }'; then
    proof_record quiet pass "HIDIdleTime grew from ${start:-unread} to $end s over 70 quiet seconds"
    return 0
  fi
  holders="$(keepawake_holders)"
  keepawake_record quiet "$holders"
  proof_record quiet fail "HIDIdleTime was ${end:-unread} s after 70 quiet seconds (from ${start:-unread}); keep-awake holders: $(grep -c . <<<"$holders" || true)" \
    "he quits what holds it, then $SCRIPT preflight quiet"
  if [ -n "$holders" ]; then
    awk -F '\t' '{ print "KEEPAWAKE (local only: never in a note, an answer or B.md): " $2 " (pid " $1 ") holds " $3 }' <<<"$holders"
    echo "DO (person): quit $(keepawake_names "$holders") (its menu bar icon or its Dock icon, Quit); then: $SCRIPT preflight quiet"
  else
    echo "DO (person): no other process holds an assertion, so something posts input events (a utility that moves the pointer to keep the Mac awake), or the Mac was touched: quit such a utility; then: $SCRIPT preflight quiet"
  fi
  return 1
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

# P2: a probe notification, then Notification Center's AX tree within 3 s.
proof_p2() {
  local found
  osascript -e 'display notification "Session B probe" with title "BatteryPulse Session B"' >/dev/null 2>&1 || true
  if found="$(ui_run banner "Session B probe" --probe --seconds 3 2>&1)"; then
    proof_record P2 pass "$found"
  else
    proof_record P2 fail "${found:-no banner in the AX tree}" "Notification Center by an AX click on the clock and a crop of the banner"
  fi
}

# P3: on Clear, screencapture -o -l<id> against -R<frame>; Claude reads the pair (P3 question).
# P3-P5 say what the occlusion check saw when Clear's window doesn't pass it: in the first attempt
# (2026-10-27) they said "Clear didn't come up" while Clear was on screen, because the Dock's
# full-display window at layer 20 counted as covering it; ui passes over that one window now
# (ui.swift, Rules.isDockOverlay).
proof_p3() {
  local line id rect
  relaunch_b_style clear light || {
    proof_record P3 not-run "Clear's window didn't pass the occlusion check: ${STYLE_LINE:-not on screen}" "-R after the occlusion check for every style"
    return 0
  }
  line="$(main_window_line)"
  if ! line_ok "$line"; then
    proof_record P3 not-run "the main window isn't clear: $line" "-R after the occlusion check for every style"
    return 0
  fi
  id="$(line_id "$line")"
  rect="$(line_rect "$line")"
  mkdir -p "$SHOTS/proofs"
  screencapture -x -o -l"$id" "$SHOTS/proofs/p3-l.png"
  screencapture -x -R"$(tr ' ' ',' <<<"$rect")" "$SHOTS/proofs/p3-R.png"
  "$BIN/frames" stats "$SHOTS/proofs/p3-l.png" >"$LOGS/p3.txt" 2>&1 || true
  "$BIN/frames" stats "$SHOTS/proofs/p3-R.png" >>"$LOGS/p3.txt" 2>&1 || true
  echo "LOOK $SHOTS/proofs/p3-l.png against $SHOTS/proofs/p3-R.png ($(tr '\n' ';' <"$LOGS/p3.txt"))"
  ask P3-capture
  echo "Then: $SCRIPT proof P3 <1|2> (1: -l keeps what lies behind the sheet, so every shot may use it; 2: only -R)"
}

proof_p3_answer() {
  case "$1" in
    1)
      echo l >"$WORK/shot-method"
      proof_record P3 pass "-l keeps what lies behind the glass sheet"
      ;;
    2)
      echo R >"$WORK/shot-method"
      proof_record P3 fail "-l leaves out what lies behind the glass sheet" "-R after the occlusion check for every style"
      ;;
    *) fail "proof P3 takes 1 or 2 after its shots" ;;
  esac
  step_answer --by claude P3-capture "$1" >/dev/null
}

# animation_seconds <frames folder>: from the first to the last frame that moved more than 0.5 %
# from the frame before.
animation_seconds() {
  awk -F '\t' 'NR > 2 && $6 + 0 > 0.5 { if (first == "") first = $2; last = $2 }
    END { if (first == "") print 0; else printf "%.2f\n", last - first }' "$1/frames.tsv"
}

# P4 and P5 on a Clear Dark window: AXMinimized in a 3-second clip, then a posted Shift around a
# click on AXMinimizeButton in a 6-second clip (does the animation last 2 s or more?).
proof_p4_p5() {
  local folder seconds
  relaunch_b_style clear dark || {
    proof_record P4 not-run "Clear's window didn't pass the occlusion check: ${STYLE_LINE:-not on screen}" "P5's posted Shift"
    proof_record P5 not-run "Clear's window didn't pass the occlusion check: ${STYLE_LINE:-not on screen}" "AXMinimized at normal speed"
    return 0
  }
  if fill_clip p4 minimize ax 3 && fill_clip p4 restore ax 3; then
    folder="$REC/p4-minimize-frames"
    proof_record P4 pass "AXMinimized: $(awk 'END { print NR - 1 }' "$folder/frames.tsv") frames, the animation about $(animation_seconds "$folder") s" "P5's posted Shift"
    echo "LOOK $folder/sheet.png beside Session A's $HOME/bp-062/A/recordings/clear-dark-minimize-frames/sheet.png (his answer there: $(answer_of_file "$HOME/bp-062/A/answers.tsv" fill-clear-dark))"
    ask P4-frames
  else
    proof_record P4 fail "the AXMinimized clip missed the animation" "P5's posted Shift"
  fi
  if fill_clip p5 minimize shift 6 && fill_clip p5 restore shift 6; then
    seconds="$(animation_seconds "$REC/p5-minimize-frames")"
    if awk -v s="$seconds" 'BEGIN { exit !(s >= 2) }'; then
      echo shift >"$WORK/fill-method"
      proof_record P5 pass "the posted Shift gives slow motion: about $seconds s"
    else
      echo ax >"$WORK/fill-method"
      proof_record P5 fail "the posted Shift gave about $seconds s" "AXMinimized at normal speed with every frame (P4)"
    fi
  else
    echo ax >"$WORK/fill-method"
    proof_record P5 fail "the Shift clip missed the animation" "AXMinimized at normal speed with every frame (P4)"
  fi
}

answer_of_file() {
  [ -f "$1" ] || return 0
  awk -F '\t' -v id="$2" '$1 == id { value = $2 } END { if (value != "") print value }' "$1"
}

# P6: HIDIdleTime before and after a 0-pixel move at the HID tap, one at the session tap, and
# caffeinate -u; whether the HID event source's state ignores posted events.
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
  proof_record P6 "$(if [ "$session" = keeps ]; then echo pass; else echo fail; fi)" \
    "HIDIdleTime: a HID-tap move $hid it, a session-tap move $session it, caffeinate -u $declared it; .hidSystemState ignores posted events: $ignores; ui posts at the $(cat "$WORK/ui-tap") tap" \
    "$(if [ "$session" = keeps ]; then echo -; else echo "the session ends its turn before the queue; during B2 only his Esc says he is there"; fi)"
}

# P7: the reads restore and the style read rest on.
proof_p7() {
  local wallpaper wm global
  wallpaper="$(if [ -n "$(wallpapers)" ]; then echo read; else echo "not read"; fi)"
  wm="$(if defaults read com.apple.WindowManager >/dev/null 2>&1; then echo read; else echo "not read"; fi)"
  global="$(defaults read -g 2>/dev/null | grep -c -i -E 'icon|widget|tint|appearance' || true)"
  proof_record P7 "$(if [ "$wallpaper" = read ] && [ "$wm" = read ]; then echo pass; else echo fail; fi)" \
    "wallpaper by System Events: $wallpaper; com.apple.WindowManager: $wm; style-like keys in defaults -g: $global; AppleICUForce24HourTime: $(defaults read -g AppleICUForce24HourTime 2>/dev/null || echo unset)" \
    "a dynamic or aerial wallpaper by computer use from prepare's shot; an unread setting is unknown"
}

# P8: the System Settings pane URLs on 27. Each URL must switch to its own pane: the title must be
# that pane's (ui knows each pane's English and Russian name) and the sidebar's selection readable.
# The confirmed panes (name, sidebar selection, title) go into ui-panes, the only places ui acts in
# System Settings (with Accessibility → Display); a pane that failed is computer use's alone.
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
    if [ "$match" = yes ] && [ -n "$sidebar" ] && [ "$sidebar" != - ] && [ -n "$title" ]; then
      printf '%s\t%s\t%s\n' "$name" "$sidebar" "$title" >>"$WORK/ui-panes.tmp"
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

# P9: whether the profiling pass can run at night without the developer-tools dialog.
proof_p9() {
  local status
  status="$(DevToolsSecurity -status 2>&1 || true)"
  case "$status" in
    *enabled*)
      proof_record P9 pass "$status"
      return 0
      ;;
  esac
  rm -rf "$WORK/traces/p9.trace"
  mkdir -p "$WORK/traces"
  echo "DO (person): if macOS asks for an administrator to allow developer tools, answer it now."
  # A tool the session built, not a system binary: Instruments can't take the task port of a
  # SIP-protected one such as /bin/sleep, whatever the developer-tools setting says.
  if xcrun xctrace record --template "Time Profiler" --time-limit 2s --output "$WORK/traces/p9.trace" \
    --launch -- "$BIN/rusage" "$$" 2 >"$LOGS/p9.txt" 2>&1 </dev/null; then
    proof_record P9 pass "a 2-second xctrace recording ran ($status)"
  else
    proof_record P9 fail "xctrace: $(tail -1 "$LOGS/p9.txt")" "the profiling pass is not run (developer tools asked)"
  fi
}

# P11: the popover opened by a CGEvent click on the menu bar item, still in CGWindowList 60 s later.
proof_p11() {
  local item rect before after
  item="$(ui_run windows --status-item 2>/dev/null || true)"
  rect="${item#* }"
  if [ -z "$item" ] || [ "$rect" = "$item" ]; then
    proof_record P11 fail "no menu bar item window in CGWindowList" "S3 stays open in Stage 1.4"
    return 0
  fi
  before="$(ui_run windows --app BatteryPulse 2>/dev/null | grep -c . || true)"
  # The item's centre (x + w/2, y + h/2), clicked as the queue's S3 clicks it: by the window list
  # alone, at the item's own window.
  # shellcheck disable=SC2046
  ui_run click $(awk '{ printf "%d %d", $1 + $3 / 2, $2 + $4 / 2 }' <<<"$rect") --cg-only --expect BatteryPulse \
    --window "${item%% *}" >/dev/null 2>&1 || true
  sleep 60
  after="$(ui_run windows --app BatteryPulse 2>/dev/null | grep -c . || true)"
  # shellcheck disable=SC2046
  ui_run click $(awk '{ printf "%d %d", $1 + $3 / 2, $2 + $4 / 2 }' <<<"$rect") --cg-only --expect BatteryPulse \
    --window "${item%% *}" >/dev/null 2>&1 || true
  if [ "${after:-0}" -gt "${before:-0}" ]; then
    echo "$rect" >"$WORK/status-item"
    proof_record P11 pass "the popover opened by a posted click and stayed 60 s ($before windows, then $after)"
  else
    proof_record P11 fail "no new BatteryPulse window after the click ($before, then $after)" "S3 stays open in Stage 1.4"
  fi
}

# proof <P#> [arguments] | proof <P#> pass|fail <note>: one proof, or a result the session saw by
# computer use (P10).
step_proof() {
  b_only proof
  b_fence
  local id="${1:-}"
  [ -n "$id" ] || fail "usage: $SCRIPT proof P1-P11 [arguments] | proof <P#> pass|fail <note>"
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
    P2) proof_p2 ;;
    P3) if [ $# -gt 0 ]; then proof_p3_answer "$1"; else proof_p3; fi ;;
    P4 | P5) proof_p4_p5 ;;
    P6) proof_p6 ;;
    P7) proof_p7 ;;
    P8) proof_p8 ;;
    P9) proof_p9 ;;
    P10) fail "P10 is computer use's: record it with $SCRIPT proof P10 pass|fail <what it showed>" ;;
    P11) proof_p11 ;;
    P12) fail "P12 runs at the burst's first unplug ($SCRIPT burst)" ;;
    *) fail "no proof $id" ;;
  esac
}

# tell_targets: every `tell application` target in the frozen scripts; only System Events and
# BatteryPulse may appear, since another target would raise an Automation prompt at night.
tell_targets() {
  grep -h -o -E 'tell application (id )?\\?"[^"\\]*\\?"' "$HERE/m5-session.sh" "$HERE/ui.swift" 2>/dev/null |
    sed -E 's/tell application (id )?\\?"//; s/\\?"$//' | sort -u
}

# preflight_quiet (preflight's last part, and `preflight quiet` after he quit what it named): the
# keep-awake assertions of other processes, then the 70-second quiet check.
preflight_quiet() {
  use_section 02-preflight "Preflight (B0b)"
  if ! keepawake_check; then
    proof_record quiet not-run "another process holds a keep-awake assertion (named to the session only)" \
      "he quits it, then $SCRIPT preflight quiet"
    return 0
  fi
  quiet_check || true
}

# preflight [quiet] (B0b): the reads and checks of §6 "Preflight also checks", the proofs that need
# no answer from the session first, the keep-awake read and the quiet check, and one run of every
# command family, while he is there (about 4 minutes without a touch).
step_preflight() {
  b_only preflight
  b_fence
  if [ "${1:-}" = quiet ]; then
    preflight_quiet
    echo "NEXT: $(if [ "$(proof_result quiet)" = pass ]; then echo "go on with B0b"; else echo "what the DO line says, then $SCRIPT preflight quiet again (twice at most; then go on, and note it)"; fi)"
    return 0
  fi
  [ $# -eq 0 ] || fail "usage: $SCRIPT preflight [quiet]"
  begin_section 02-preflight "Preflight (B0b)"
  local access target bad="" vpn movie fps
  access="$(ui_run access 2>&1 || true)"
  out "- access: $access"
  case "$access" in *"ax_trusted=no"*) echo "DO (person): allow Terminal under System Settings → Privacy & Security → Accessibility (Touch ID or your password), then run preflight again." ;; esac
  for target in $(tell_targets | tr ' ' '_'); do
    case "$target" in System_Events | '$BUNDLE_ID' | "$BUNDLE_ID") ;; *) bad="$bad $target" ;; esac
  done
  if [ -n "$bad" ]; then
    out "- tell application targets: refused:$bad (each would raise an Automation prompt at night)"
    fail "the frozen script tells another app than System Events or BatteryPulse:$bad"
  fi
  out "- tell application targets: System Events and BatteryPulse only"
  out "- Apple Events: System Events $(if [ "$(is_dark)" != unknown ]; then echo answers; else echo "doesn't answer"; fi); BatteryPulse $(if osascript -e "tell application id \"$BUNDLE_ID\" to get name" >/dev/null 2>&1; then echo answers; else echo "doesn't answer"; fi)"
  shot preflight-capture
  echo "LOOK $SHOTS/preflight-capture-view.jpg: the desktop, not only the wallpaper (Screen Recording's re-consent prompt would come now)"
  out "- the widget extension's container preferences: $(if defaults read "$WIDGET_PREFS" >/dev/null 2>&1; then echo read; else echo "not read (none yet, or the other apps' data prompt)"; fi)"
  pmset -g battlimit >"$LOGS/preflight-battlimit.txt" 2>&1 || true
  pmset -g custom >"$LOGS/preflight-custom.txt" 2>&1 || true
  out "- pmset -g battlimit: $(tr '\n' ' ' <"$LOGS/preflight-battlimit.txt" | cut -c1-120)"
  out "- Low Power Mode set for battery: $(lowpowermode_of Battery)$(if [ "$(lowpowermode_of Battery)" = 1 ]; then echo " (the start message tells him: with his password the queue turns it off for the other runs, else they are LPM (not valid))"; fi)"
  out "- hot corners: $(ui_run screen 2>/dev/null | sed 's/.*corners //'); the screen saver after $(cat "$WORK/screensaver-idle" 2>/dev/null || echo unknown) s"
  vpn=no
  if scutil --nc list 2>/dev/null | grep -q 'Connected'; then vpn=yes; fi
  if ifconfig 2>/dev/null | awk '/^utun/ { u = 1; next } /^[a-z]/ { u = 0 } u && /inet / { found = 1 } END { exit !found }'; then vpn=yes; fi
  echo "$vpn" >"$WORK/vpn"
  out "- a VPN active: $vpn"
  out "- charge: $(battery_percent) %, $(if on_battery; then echo on battery; else echo on the adapter; fi)"
  movie="$REC/preflight-rate.mov"
  mkdir -p "$REC"
  fps=""
  if clip "$movie" 2; then fps="$("$BIN/frames" fps "$movie" 2>/dev/null || echo unknown)"; fi
  out "- screencapture -v: ${fps:-no movie}"
  out "- DevToolsSecurity: $(DevToolsSecurity -status 2>&1 | head -1 || true)"
  out "- the widget extension's processes: pgrep -x BatteryPulseWidget finds $(pgrep -x BatteryPulseWidget 2>/dev/null | grep -c . || true), its path $(widget_pids | grep -c . || true) (the script goes by the path)"
  proof_p7
  proof_p8
  proof_p9
  proof_p2
  proof_p6
  proof_p11
  out "- the main window's occlusion check: $(open_main && main_window_line)"
  out "- ui guard: $(ui_run guard 2>&1 || true)"
  # Last: nothing posts an event during the quiet check.
  preflight_quiet
  out ""
  out "| Proof | Result | Detail | Fallback |"
  out "|---|---|---|---|"
  local proof result detail fallback
  while IFS=$'\t' read -r proof result detail fallback _; do
    out "| $proof | $result | $detail | $fallback |"
  done <"$PROOFS"
  echo
  echo "Now, with the session's own calls: proof P1 at a widget's centre, proof P3, proof P4,"
  echo "proof P10 (the app batch, a widget's click-to-add and its removal, a screenshot after the first action, one System"
  echo "Settings click). Each family of the session's commands runs once here, so every prompt comes now:"
  echo "RUN $SCRIPT ui idle; $SCRIPT ui guard; $SCRIPT shot preflight-family; $SCRIPT heartbeat preflight;"
  echo "RUN $SCRIPT measure / judge on one shot; $SCRIPT status"
  echo "NEXT: the banners (v01 notify; f11 alert), then $SCRIPT arm open"
}

# MARK: - Session B: the GUI phase's helpers (B0b, B1, B2)

# clip <movie> <seconds> [<action...>]: the screen for <seconds>, the action fired 1 s in, with no
# DO line and no sound (WP-21's record_clip). As in Session A: screencapture -v stops only at -V,
# so its standard input is a FIFO held open until it exits, and it is waited for.
clip() {
  local movie="$1" seconds="$2" fifo="$REC/clip.fifo" pid tries=0 limit
  shift 2
  case "$seconds" in "" | 0* | *[!0-9]*) fail "clip: -V takes a whole number of seconds above 0" ;; esac
  mkdir -p "$REC"
  rm -f "$movie" "$fifo"
  mkfifo "$fifo"
  screencapture -v -V "$seconds" -x "$movie" <"$fifo" &
  pid=$!
  exec 3>"$fifo"
  if [ $# -gt 0 ]; then
    sleep 1
    "$@" >/dev/null 2>&1 || warn "the clip's action failed: $*"
  fi
  limit=$(((seconds + 60) * 2))
  while kill -0 "$pid" 2>/dev/null && [ "$tries" -lt "$limit" ]; do
    sleep 0.5
    tries=$((tries + 1))
  done
  if kill -0 "$pid" 2>/dev/null; then
    kill -TERM "$pid" 2>/dev/null || true
    sleep 2
    kill -KILL "$pid" 2>/dev/null || true
  fi
  wait "$pid" 2>/dev/null || true
  exec 3>&-
  rm -f "$fifo"
  [ -s "$movie" ]
}

# set_appearance <light|dark>: by System Events, its original recorded once.
set_appearance() {
  [ -n "$(original_of appearance)" ] || record_change appearance "$(is_dark)" "$1"
  # A fixed appearance by System Events turns Auto off, and only computer use turns it back on.
  if [ "$(cat "$BACKUP/auto-appearance" 2>/dev/null || echo 0)" = 1 ] && [ -z "$(original_of appearance-auto)" ]; then
    record_change appearance-auto on off
  fi
  appearance "$1"
}

# wallpaper_is_still: his wallpaper is a still picture, which System Events can put back: the
# judge's prep-wallpaper-kind (1) where answered, else prepare's read of the paths. A dynamic or
# aerial one would come back as a still image, so it is computer use's, from prepare's shot.
wallpaper_is_still() {
  case "$(answer_of prep-wallpaper-kind)" in
    1) return 0 ;;
    2 | 3) return 1 ;;
  esac
  [ "$(cat "$WORK/wallpaper-kind" 2>/dev/null || true)" = still ]
}

# wallpaper_as_backup: every desktop's picture reads as prepare's backup.
wallpaper_as_backup() { [ -s "$BACKUP/wallpapers" ] && [ "$(wallpapers)" = "$(cat "$BACKUP/wallpapers")" ]; }

# set_wallpaper <png>: every desktop's picture, by System Events; the originals are the backup's.
set_wallpaper() {
  [ -n "$(original_of wallpaper)" ] || record_change wallpaper "the backup's list" "$(basename "$1")"
  osascript -e 'on run argv' -e 'tell application "System Events"' -e 'repeat with d in desktops' \
    -e 'set picture of d to (item 1 of argv)' -e 'end repeat' -e 'end tell' -e 'end run' "$1" >/dev/null 2>&1 || return 1
  # Which wallpaper the shots from here on show (bright or busy), for attach's check.
  case "$1" in *bright*) echo bright ;; *busy*) echo busy ;; *) echo other ;; esac >"$WORK/wallpaper-now"
}

put_wallpapers_back() {
  [ -s "$BACKUP/wallpapers" ] || return 0
  echo his >"$WORK/wallpaper-now"
  [ "$(wallpapers)" != "$(cat "$BACKUP/wallpapers")" ] || return 0
  local index=1 path
  while IFS= read -r path; do
    [ -n "$path" ] || continue
    osascript -e 'on run argv' \
      -e 'tell application "System Events" to set picture of desktop (item 1 of argv as integer) to (item 2 of argv)' \
      -e 'end run' "$index" "$path" >/dev/null 2>&1 || warn "can't put back the wallpaper of desktop $index"
    index=$((index + 1))
  done <"$BACKUP/wallpapers"
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

# relaunch_b_style <standard|frosted|translucent|clear> [light|dark] [compact]: the style by
# defaults and a relaunch, the appearance by System Events, the window by a reopen event, placed
# by AX; succeeds when the window passes the occlusion check, whose line STYLE_LINE keeps.
STYLE_LINE=""
relaunch_b_style() {
  local style="$1" look="${2:-}" compact="${3:-}"
  STYLE_LINE=""
  quit_app
  session_settings
  set_default betaWindowStyles -bool true
  set_default windowLook -string "$style"
  if [ "$compact" = compact ]; then set_default prefersCompactWindow -bool true; fi
  if [ -n "$look" ]; then
    set_appearance "$look" || {
      STYLE_LINE="System Events didn't set the $look appearance"
      return 1
    }
  fi
  launch_b
  open_main
  place_window
  sleep 1
  STYLE_LINE="$(main_window_line)"
  line_ok "$STYLE_LINE"
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

screen_width() { ui_run screen 2>/dev/null | sed -n 's/^main=[-0-9]* [-0-9]* \([0-9]*\) .*/\1/p' || true; }

# fill_clip <name> <minimize|restore> <ax|shift> <seconds>: one clip of a case, every frame dumped,
# the darkest ones cropped to the window's rectangle (frames.swift).
fill_clip() {
  local name="$1" phase="$2" method="$3" seconds="$4" movie folder line rect point title id
  movie="$REC/$name-$phase.mov"
  folder="$REC/$name-$phase-frames"
  if [ "$phase" = minimize ]; then
    line="$(main_window_line)"
    line_ok "$line" || return 1
    line_rect "$line" >"$REC/$name.rect"
    line_id "$line" >"$REC/$name.id"
    ui_run title BatteryPulse 2>/dev/null | sed 's/^title: //' >"$REC/$name.title" || true
    # The Dock's minimized-window tiles before this minimize: the restore clicks only the tile
    # that appears, never one of his own minimized windows.
    ui_run frame --dock --list >"$REC/$name.dock" 2>/dev/null || : >"$REC/$name.dock"
  fi
  rect="$(cat "$REC/$name.rect" 2>/dev/null || true)"
  [ -n "$rect" ] || return 1
  case "$phase:$method" in
    minimize:ax) clip "$movie" "$seconds" ui_run minimize on BatteryPulse || return 1 ;;
    restore:ax) clip "$movie" "$seconds" ui_run minimize off BatteryPulse || return 1 ;;
    minimize:shift)
      id="$(cat "$REC/$name.id" 2>/dev/null || true)"
      point="$(ui_run frame BatteryPulse --minimize-button 2>/dev/null | awk '{ printf "%d %d", $1 + $3 / 2, $2 + $4 / 2 }' || true)"
      [ -n "$point" ] && [ -n "$id" ] || return 1
      # shellcheck disable=SC2086
      clip "$movie" "$seconds" ui_run click $point --shift --expect BatteryPulse --window "$id" || return 1
      ;;
    restore:shift)
      title="$(cat "$REC/$name.title" 2>/dev/null || true)"
      # The tile that appeared since the minimize, titled as the window was; ui finds it and
      # checks that it is what lies at its centre.
      clip "$movie" "$seconds" ui_run click --expect dock-tile --new-since "$REC/$name.dock" \
        ${title:+--dock-title "$title"} --shift || return 1
      ;;
  esac
  rm -rf "$folder"
  # shellcheck disable=SC2086
  "$BIN/frames" dump "$movie" "$folder" 0.0167 1280 --rect $rect --screen "$(screen_width)" >"$folder.txt" 2>&1 || return 1
  # The darkest frames are cropped to the window: the clip's only pictures attach may publish (its
  # frames and sheet are the whole screen).
  local crop
  for crop in "$folder"/darkest-*.png; do
    if [ -f "$crop" ]; then register_shot "$crop"; fi
  done
  [ -f "$folder/frames.tsv" ]
}

# MARK: - Session B: step 3, the glass-sheet cases

# The 8 glass-sheet cases, which confirm G-13a on the RC: optional, at the end of the GUI phase
# (about 25 minutes). G-13b's evidence (the 24 shots, the 19 graduation shots, the contrast audit,
# V1b, Standard and Frosted beside a minimized TextEdit) left Session B after its first attempt:
# both beta styles stay beta (PLAN.md §6, §7.1).
FILL_CASES_B="translucent-light-main translucent-dark-main clear-light-main clear-dark-main translucent-light-compact translucent-dark-compact clear-light-compact clear-dark-compact"

# case <style>-<light|dark>-<main|compact>: one of the 8 glass-sheet cases, minimized and restored
# by record_clip's method (proof P5: a posted Shift in a 6-second clip, else AXMinimized in 3 s),
# measured, then judged.
step_case() {
  b_only case
  b_fence
  local name="${1:-}" style look window method seconds phase
  case " $FILL_CASES_B " in *" $name "*) ;; *) fail "the cases are $FILL_CASES_B" ;; esac
  style="${name%%-*}"
  look="${name#*-}"
  window="${look#*-}"
  look="${look%%-*}"
  method="$(cat "$WORK/fill-method" 2>/dev/null || echo ax)"
  if [ "$method" = shift ]; then seconds=6; else seconds=3; fi
  use_section 30-cases "The glass-sheet minimize and restore cases (WP-13, G-13a)"
  # On the generated bright wallpaper, like the screenshot set: the glass shows what lies behind it.
  if [ -f "$WORK/wallpaper-bright.png" ]; then
    set_wallpaper "$WORK/wallpaper-bright.png" || warn "System Events didn't set the wallpaper: the case's crops stay on the Mac"
  else
    warn "no generated wallpaper (prepare reads): the case's crops stay on the Mac"
  fi
  if [ "$window" = compact ]; then
    relaunch_b_style "$style" "$look" compact || {
      not_checked "fill-$name" "the compact window didn't pass the occlusion check: ${STYLE_LINE:-not on screen}"
      return 0
    }
  else
    relaunch_b_style "$style" "$look" || {
      not_checked "fill-$name" "the main window didn't pass the occlusion check: ${STYLE_LINE:-not on screen}"
      return 0
    }
  fi
  for phase in minimize restore; do
    if ! fill_clip "case-$name" "$phase" "$method" "$seconds"; then
      sleep 2
      # A clip that missed the animation: retried once (§6 "Rules").
      if [ "$phase" = restore ]; then ui_run minimize on BatteryPulse >/dev/null 2>&1 || true; fi
      fill_clip "case-$name" "$phase" "$method" "$seconds" || {
        not_checked "fill-$name" "the $phase clip missed the animation twice"
        ui_run minimize off BatteryPulse >/dev/null 2>&1 || true
        return 0
      }
    fi
  done
  step_measure "fill-$name" black "$REC/case-$name-minimize-frames" >/dev/null
  out "- $name ($method, $seconds s): minimize $(grep -m1 'frame rate' "$REC/case-$name-minimize-frames.txt" || true); $(measure_of "fill-$name" 4); restore $(grep -m1 'darkest inside' "$REC/case-$name-restore-frames.txt" || true)"
  echo "LOOK $REC/case-$name-minimize-frames/sheet.png and darkest-1.png; then $REC/case-$name-restore-frames/sheet.png"
  ask "fill-$name"
  echo "Then: $SCRIPT judge fill-$name <1-3> [--unsure] [note]"
}

# MARK: - Session B: steps 2, 4, 6 and 7 (V-01, F6-F12, memory, the burst)

# v01 notify [front] | menubar | check | morning (step 2).
step_v01_b() {
  b_fence
  case "${1:-}" in
    notify)
      local id=V01-notification result
      if [ "${2:-}" = front ]; then id=V01-notification-front; fi
      if [ "$id" = V01-notification-front ]; then open_main; fi
      ui_run press BatteryPulse --menu-cmd , >/dev/null 2>&1 || fail "Settings didn't open"
      sleep 2
      ui_run press BatteryPulse Notifications >/dev/null 2>&1 || warn "the Notifications pane didn't select"
      sleep 1
      ui_run press BatteryPulse "Send Test Notification" >/dev/null 2>&1 || fail "Send Test Notification didn't press"
      # By the notification's own text (the app runs in English here), as proof P2 finds its probe:
      # Notification Center also hosts the desktop widgets, and an earlier banner may still show.
      result="$(ui_run banner "$TEST_NOTIFICATION_TEXT" --seconds 10 2>&1 || true)"
      sleep 2
      use_section 20-v01 "V-01 on the RC (WP-10, WP-14a)"
      out "- $id: $result; front window afterwards: $(ui_run windows 2>/dev/null | awk -F '\t' '$2 == "layer 0" { print $3; exit }')"
      ask "$id"
      ;;
    menubar)
      local item
      item="$(ui_run windows --status-item 2>/dev/null | cut -d' ' -f2- || true)"
      [ -n "$item" ] || fail "no menu bar item in CGWindowList"
      mkdir -p "$SHOTS/v01"
      set_appearance light
      sleep 2
      rect_shot "$SHOTS/v01/menubar-light.png" "$item" >/dev/null
      set_appearance dark
      sleep 2
      rect_shot "$SHOTS/v01/menubar-dark.png" "$item" >/dev/null
      appearance "$(if [ "$(original_of appearance)" = true ]; then echo dark; else echo light; fi)" || true
      step_measure V01-menubar differs "$SHOTS/v01/menubar-light.png" "$SHOTS/v01/menubar-dark.png"
      echo "LOOK $SHOTS/v01/menubar-light.png and $SHOTS/v01/menubar-dark.png"
      ask V01-menubar
      ;;
    check)
      use_section 20-v01 "V-01 on the RC (WP-10, WP-14a)"
      local lines
      lines="$(log_since "$(cat "$WORK/prepare.time")" "$EXECUTOR_PREDICATE" "$LOGS/executor-gui.ndjson")"
      out "- B2's end ($(clock)): \"executor\" log lines since prepare: $lines"
      if [ "$lines" -gt 0 ]; then
        messages "$LOGS/executor-gui.ndjson" | head -20 >"$LOGS/executor-gui.txt"
        out_block "$LOGS/executor-gui.txt"
      fi
      out "- crash reports since prepare:"
      crash_summary "$WORK/prepare.marker"
      ask V01-pages
      ;;
    morning)
      use_section 20-v01 "V-01 on the RC (WP-10, WP-14a)"
      local build pids count=0 report
      build="$(awk -F '\t' '$1 == "C" { print $3 }' "$WORK/builds.tsv")"
      log_since "$(cat "$WORK/prepare.time")" "$EXECUTOR_PREDICATE" "$LOGS/executor-night.ndjson" >/dev/null
      pids="$(cat "$WORK/rc-pids.txt" 2>/dev/null | tr '\n' ' ' || true)"
      out "- the morning: \"executor\" lines of the RC's processes: $(awk -v pids=" $pids " '
        match($0, /"processID" *: *[0-9]+/) { p = substr($0, RSTART, RLENGTH); sub(/.*: */, "", p); if (index(pids, " " p " ")) n++ }
        END { print n + 0 }' "$LOGS/executor-night.ndjson")"
      while IFS= read -r report; do
        [ -n "$report" ] || continue
        if head -1 "$report" | grep -q "\"build_version\" *: *\"$build\""; then count=$((count + 1)); fi
      done < <(crash_reports_since "$WORK/prepare.marker")
      out "- the RC's crash reports (build $build) since prepare: $count (build B's runs don't count)"
      shot after-lid
      ask V01-lid
      ;;
    *) fail "usage: $SCRIPT v01 notify [front] | menubar | check | morning" ;;
  esac
}

# f11 alert | login (step 4).
step_f11() {
  b_only f11
  b_fence
  use_section 40-f11 "F11: the charge alert and the login item"
  case "${1:-}" in
    alert)
      local charge step="" waited=0 result
      charge="$(battery_percent)"
      if [ "${charge:-0}" -ge 80 ]; then
        for step in 100 95 90 85 80; do
          if [ "$charge" -ge "$step" ]; then break; fi
        done
      else
        step=80
        if ! pmset -g batt | grep -q -E '; charging;' || [ $((step - charge)) -gt 3 ]; then
          out "- F11-alert: not run (at $charge %, not charging or more than 3 points below 80)"
          step_answer --by claude F11-alert 3 "not run: the charge" >/dev/null
          return 0
        fi
      fi
      quit_app
      set_default alertChargeLimit -int "$step"
      defaults delete "$BUNDLE_ID" alertState 2>/dev/null || true
      launch_b
      until result="$(ui_run banner "$CHARGE_ALERT_TEXT" --seconds 20 2>&1)" || [ "$waited" -ge 18 ]; do
        waited=$((waited + 1))
      done
      out "- F11-alert: step $step % at $charge %: ${result:-no banner}"
      ask F11-alert
      ;;
    login)
      local before
      before="$(answer_of prep-open-at-login)"
      case "$before" in 1 | 2) ;; *)
        not_checked F11-login "Open at login's original is unknown: never changed"
        return 0
        ;;
      esac
      record_change open-at-login "$(if [ "$before" = 1 ]; then echo on; else echo off; fi)" "off (F11)"
      echo "DO (session): in Settings → General, turn Open at login $(if [ "$before" = 2 ]; then echo "on, then off again"; else echo off; fi) by ui press; then: $SCRIPT f11 listed"
      ;;
    listed)
      open_pane login-items
      sleep 3
      out "- Login Items after Open at login off: $(ui_run tree "System Settings" --match BatteryPulse 2>&1 || true)"
      quit_if_launched "System Settings"
      ask F11-login
      ;;
    *) fail "usage: $SCRIPT f11 alert | login | listed" ;;
  esac
}

# f6 <page>: a page on real data (E4b's mixed-age snapshot) beside bpulse --json of the same minute.
step_f6() {
  b_only f6
  b_fence
  local page="${1:-}" label
  case "$page" in
    overview) label=Overview ;; power) label=Power ;; history) label=History ;; health) label=Health ;;
    raw) label="Raw Data" ;; *) fail "usage: $SCRIPT f6 overview|power|history|health|raw" ;;
  esac
  app_running || launch_b
  open_main
  select_page "$label" || warn "$label wasn't selected"
  sleep 2
  if [ -x "$BIN/bpulse" ]; then "$BIN/bpulse" --json >"$LOGS/f6-$page.json" 2>&1 || true; fi
  window_shot "$SHOTS/f6/f6-$page.png" || not_checked "F6-$page" "no shot"
  echo "READ $LOGS/f6-$page.json (bpulse --json, the same minute)"
  ask "F6-$page"
}

# f8 [ru on|off]: the RC's widgets after the fixed action (a click on the empty desktop spot, then
# 1 s), one crop per family with its spread, in English or, after `f8 ru on`, in Russian.
step_f8() {
  b_only f8
  b_fence
  local lang=en family rect file
  if [ "${1:-}" = ru ]; then
    case "${2:-}" in
      on)
        record_change widget-languages "$(if [ -f "$BACKUP/widget-languages" ]; then echo "his own"; else echo none; fi)" "(ru)"
        defaults write "$WIDGET_PREFS" AppleLanguages -array ru
        end_widget_extension
        sleep 5
        echo "the widget extension is in Russian now: $SCRIPT f8 ru"
        return 0
        ;;
      off)
        if put_widget_languages_back; then
          mark_restored widget-languages "as prepare found it, read back"
          echo "the widget extension's languages are as prepare found them"
        else
          warn "the widget extension's AppleLanguages isn't as prepare found it: restore gui tries again"
        fi
        return 0
        ;;
      "") lang=ru ;;
      *) fail "usage: $SCRIPT f8 [ru on|ru off|ru]" ;;
    esac
  fi
  click_desktop || not_checked "F8-$lang" "no desktop spot"
  for family in small medium large xlarge; do
    rect="$(widget_rect "$family")"
    if [ -z "$rect" ]; then
      not_checked "F8-$family-$lang" "no frame recorded for the $family widget"
      continue
    fi
    file="$SHOTS/f8/f8-$family-$lang.png"
    rect_shot "$file" "$rect" >/dev/null || continue
    step_measure "F8-$family-$lang" blank "$file" >/dev/null
    echo "LOOK $file ($(measure_of "F8-$family-$lang" 4))"
    ask "F8-$family-$lang"
  done
}

# f9: the app in Russian by a relaunch with -AppleLanguages (ru) (Overview, Settings, the update
# warning); Claude checks truncation, English leftovers and the catalog's terms.
step_f9() {
  b_only f9
  b_fence
  quit_app
  session_settings
  open "$APP" --args -ApplePersistenceIgnoreState YES -AppleLanguages "(ru)"
  sleep 3
  open_main
  place_window
  window_shot "$SHOTS/f9/f9-overview.png" || not_checked F9-overview "no shot"
  echo "DO (session): Settings (ui press BatteryPulse --menu-cmd ,) and the update warning, each by rect_shot or shot; then relaunch in English ($SCRIPT relaunch)"
  ask F9-overview F9-settings F9-update
}

step_relaunch() {
  b_only relaunch
  b_fence
  relaunch_b
  open_main
  place_window
  echo "relaunched: $(app_version)"
}

# f12 rate | before | after (step 6; Q-B9, G-16, WP-16 item 6).
step_f12() {
  b_only f12
  b_fence
  use_section 60-f12 "F12: Install and Relaunch on the RC's installer (G-16)"
  case "${1:-}" in
    rate)
      local left
      left="$(curl -s https://api.github.com/rate_limit | sed -n 's/.*"core" *: *{[^}]*"remaining" *: *\([0-9]*\).*/\1/p' | head -1 || true)"
      [ -n "$left" ] || left="$(curl -s https://api.github.com/rate_limit | tr -d ' \n' | sed -n 's/.*"rate":{[^}]*"remaining":\([0-9]*\).*/\1/p')"
      out "- the unauthenticated requests left: ${left:-unknown}; a VPN active: $(cat "$WORK/vpn" 2>/dev/null || echo unknown)"
      if [ -n "$left" ] && [ "$left" -ge 10 ]; then echo "F12 may run now: $SCRIPT f12 before"; else
        echo "not now (fewer than 10 requests left): other steps first, then f12 rate again; else in the morning"
        return 1
      fi
      ;;
    before)
      clock >"$WORK/f12.time"
      click_desktop || true
      sleep 2
      rect_shot "$SHOTS/f12/before-small.png" "$(widget_rect small)" >/dev/null 2>&1 || true
      rect_shot "$SHOTS/f12/before-medium.png" "$(widget_rect medium)" >/dev/null 2>&1 || true
      if [ -n "$(widget_pids)" ]; then echo yes >"$WORK/f12-extension"; else echo no >"$WORK/f12-extension"; fi
      out "- before Install ($(cat "$WORK/f12.time")): $(app_version); the widget extension running: $(cat "$WORK/f12-extension")"
      # Finder's on-screen windows every half second until `f12 after` (at most 10 minutes), so a
      # window the install opens and closes again is seen too (CGWindowList only).
      ui_run windows --app Finder 2>/dev/null | grep -c . >"$WORK/f12-finder-before" || true
      : >"$LOGS/f12-finder.txt"
      touch "$WORK/f12.watch"
      (
        trap '' HUP
        end=$(($(date +%s) + 600))
        while [ -f "$WORK/f12.watch" ] && [ "$(date +%s)" -lt "$end" ]; do
          printf '%s\t%s\n' "$(date +%s)" "$(ui_run windows --app Finder 2>/dev/null | grep -c . || true)" >>"$LOGS/f12-finder.txt"
          sleep 0.5
        done
      ) </dev/null >/dev/null 2>&1 &
      echo "DO (session): Check for Updates, then Install and Relaunch, by AX presses; then: $SCRIPT f12 after"
      ;;
    after)
      local waited=0 lines started swap found left ms verdict swap_at swap_epoch pid lstart early="" failures finder
      until [ "$(plist_value "$APP/Contents/Info.plist" CFBundleShortVersionString)" = 0.6.1 ] || [ "$waited" -ge 120 ]; do
        sleep 1
        waited=$((waited + 1))
      done
      sleep 5
      out "- after: $(app_version), running $(if app_running; then echo yes; else echo no; fi)"
      log_since "$(cat "$WORK/f12.time")" "subsystem == \"$BUNDLE_ID\" AND category == \"update\"" "$LOGS/f12-update.ndjson" >/dev/null
      lines="$(messages "$LOGS/f12-update.ndjson" | grep -E 'extension before the swap|diskutil|attach|eject|swap' | head -12 || true)"
      printf '%s\n' "$lines" >"$LOGS/f12-update.txt"
      out "- the update log's installer lines:"
      out_block "$LOGS/f12-update.txt"
      swap="$(sed -n 's/.*Widget extension before the swap: \(.*\)/\1/p' "$LOGS/f12-update.txt" | head -1 || true)"
      out "- the pre-swap extension end (WP-16 item 6): ${swap:-no line}$(if [ "$(cat "$WORK/f12-extension" 2>/dev/null)" = no ]; then echo "; no extension ran before Install: not exercised"; fi)"
      # WP-16 item 6's checks (PLAN.md F12, Appendix C): every process the installer found ended,
      # by SIGTERM or SIGKILL, within 1,500 ms; no BatteryPulseWidget process from before the swap;
      # neither eject failure; no Finder window during the install.
      found="$(sed -n 's/^\([0-9]*\) found,.*/\1/p' <<<"$swap")"
      left="$(sed -n 's/.* \([0-9]*\) still running,.*/\1/p' <<<"$swap")"
      ms="$(sed -n 's/.*, \([0-9]*\) ms$/\1/p' <<<"$swap")"
      if [ -z "$found" ] || [ -z "$left" ] || [ -z "$ms" ]; then verdict="not checked (no pre-swap line)"
      elif [ "$found" = 0 ]; then verdict="not exercised (none found)"
      elif [ "$left" = 0 ] && [ "$ms" -le 1500 ]; then verdict="yes ($found in $ms ms)"
      else verdict="no ($left still running, $ms ms)"; fi
      out "- every extension process the installer found ended within 1,500 ms: $verdict"
      swap_at="$(entries "$LOGS/f12-update.ndjson" | awk -F '\t' 'index($3, "Widget extension before the swap") { print substr($1, 1, 19); exit }')"
      swap_epoch="$(date -j -f '%Y-%m-%d %H:%M:%S' "$swap_at" +%s 2>/dev/null || true)"
      started=""
      for pid in $(widget_pids); do
        lstart="$(ps -o lstart= -p "$pid" 2>/dev/null || true)"
        [ -n "$lstart" ] || continue
        started="$started ${lstart# }"
        if [ -n "$swap_epoch" ] && [ "$(date -j -f '%a %b %d %T %Y' "$lstart" +%s 2>/dev/null || echo "$swap_epoch")" -lt "$swap_epoch" ]; then
          early="$early $pid"
        fi
      done
      out "- BatteryPulseWidget processes now: ${started:- none running}; started before the swap (${swap_at:-its time unknown}): $(if [ -n "$early" ]; then echo "yes (not valid)"; elif [ -n "$swap_epoch" ]; then echo no; else echo "not checked"; fi)"
      failures="$(messages "$LOGS/f12-update.ndjson" | grep -c -F -e "it can't be ejected by force" -e "Ejecting the update's disk image failed" || true)"
      out "- \"isn't in diskutil info; it can't be ejected by force\" or \"Ejecting the update's disk image failed\" lines: ${failures:-0} (must be 0)"
      rm -f "$WORK/f12.watch"
      finder="$(awk -F '\t' '$2 + 0 > max { max = $2 + 0 } END { print NR " samples, at most " max + 0 }' "$LOGS/f12-finder.txt" 2>/dev/null || true)"
      out "- Finder's on-screen windows during the install: ${finder:-not sampled}, against $(cat "$WORK/f12-finder-before" 2>/dev/null || echo unknown) before (more means a window opened)"
      click_desktop || true
      sleep 2
      rect_shot "$SHOTS/f12/after-small.png" "$(widget_rect small)" >/dev/null 2>&1 || true
      rect_shot "$SHOTS/f12/after-medium.png" "$(widget_rect medium)" >/dev/null 2>&1 || true
      [ ! -f "$SHOTS/f12/after-small.png" ] || step_measure F12-widget blank "$SHOTS/f12/after-small.png" >/dev/null
      echo "LOOK $SHOTS/f12/before-small.png against after-small.png (and medium)"
      ask F12-widget
      echo "Then: $SCRIPT install C (the rest of B2 runs on the RC)"
      ;;
    *) fail "usage: $SCRIPT f12 rate | before | after" ;;
  esac
}

# memory [<24-hour label> <7-day label>]: History → 7 days three times by AX, phys_footprint before,
# after each and at the end (step 7; first in B2, on the backed-up history).
step_memory() {
  b_only memory
  b_fence
  local day="${1:-24 Hours}" week="${2:-7 Days}" pid cycle
  use_section 75-memory "Memory: History → 7 days three times"
  app_running || launch_b
  open_main
  select_page History || warn "History wasn't selected"
  sleep 5
  pid="$(app_pid)"
  out "- before: $(footprint "$pid"), history $(du -sk "$SUPPORT/History" 2>/dev/null | cut -f1 || echo 0) KB"
  for cycle in 1 2 3; do
    ui_run press BatteryPulse "$week" >/dev/null 2>&1 || warn "$week didn't press"
    sleep 6
    ui_run press BatteryPulse "$day" >/dev/null 2>&1 || warn "$day didn't press"
    sleep 4
    out "- after cycle $cycle: $(footprint "$pid")"
  done
  sleep 10
  out "- at the end: $(footprint "$pid") (the same process: $(if [ "$(app_pid)" = "$pid" ]; then echo yes; else echo no; fi))"
}

# burst (B1, step 7): 3 unplug and plug cycles at cues, 1 minute apart, each power event stamped,
# P12 at the first unplug, ending plugged in; S8 counts only the reads a power-source notification
# triggered.
step_burst() {
  b_only burst
  b_fence
  on_battery && fail "plug the adapter in first: the burst starts and ends plugged in"
  begin_section 70-burst "S8: the burst (3 unplug and plug cycles)"
  local cycle t0 waiter waited capture="$LOGS/burst.ndjson" key watch="" unplugs="" plugs=""
  perf_capture "$capture"
  for key in $NOTIFY_KEYS; do watch="$watch -w $key"; done
  # shellcheck disable=SC2086
  stamped "$LOGS/burst-notify.txt" notifyutil $watch
  for cycle in 1 2 3; do
    t0="$(date +%s)"
    waiter=""
    if [ "$cycle" = 1 ]; then
      notifyutil -1 com.apple.system.powersources.source >/dev/null 2>&1 &
      waiter=$!
      sleep 0.5
    fi
    cue "Unplug the adapter now ($cycle of 3)"
    echo "$(clock): unplug now ($cycle of 3)"
    waited=0
    until on_battery || [ "$waited" -ge 90 ]; do
      sleep 1
      waited=$((waited + 1))
    done
    if on_battery; then unplugs="$unplugs $(clock)"; else unplugs="$unplugs missed"; fi
    if [ -n "$waiter" ]; then
      sleep 2
      if kill -0 "$waiter" 2>/dev/null; then
        kill "$waiter" 2>/dev/null || true
        proof_record P12 fail "no com.apple.system.powersources.source notification across the unplug" "the sampler's ExternalConnected column alone"
        echo sampler >"$WORK/unplug-method"
      else
        proof_record P12 pass "a power-source notification came with the unplug"
        echo notify >"$WORK/unplug-method"
      fi
    fi
    sleep_until $((t0 + 30))
    cue "Plug the adapter in now ($cycle of 3)"
    echo "$(clock): plug in now ($cycle of 3)"
    waited=0
    while on_battery && [ "$waited" -lt 90 ]; do
      sleep 1
      waited=$((waited + 1))
    done
    if on_battery; then plugs="$plugs missed"; else plugs="$plugs $(clock)"; fi
    [ "$cycle" = 3 ] || sleep_until $((t0 + 60))
  done
  sleep 20
  perf_stop "$STREAM"
  stop_pslog
  out "- unplugged at:$unplugs; plugged in at:$plugs"
  out "- reads per notify burst, widget reloads (S8: 1 read per burst, at most 1 reload per cycle):"
  summarize "$capture" '^(intervals|name|refresh|read|notify|events|widget\.reload|burst)'
  out "- power-source lines: $(grep -c powersources "$LOGS/burst-notify.txt" 2>/dev/null || echo 0)"
  if on_battery; then echo "warning: the Mac is on battery: plug the adapter in"; fi
  echo "NEXT: the Focus on (he turns it on), then $SCRIPT mark away"
}

# MARK: - Session B: page switches (step 5; WP-17's after)

# page_targets: "<label>|<x> <y>" per page, the centre of its sidebar row's AX frame, read once
# before the capture; a page without a frame is selected by AX instead ("<label>|ax").
page_targets() {
  local entry label frame
  for entry in $PAGES; do
    label="${entry%%:*}"
    label="${label//_/ }"
    frame="$(ui_run frame BatteryPulse --within AXOutline --match "$label" 2>/dev/null || true)"
    if [ -n "$frame" ]; then
      printf '%s|%s\n' "$label" "$(awk '{ printf "%d %d", $1 + $3 / 2, $2 + $4 / 2 }' <<<"$frame")"
    else
      printf '%s|ax\n' "$label"
    fi
  done
}

# cue_clicks <rounds> <seconds> <targets file>: each page clicked on the cue schedule, each click
# aimed at the main window by its ID.
cue_clicks() {
  local round target label point id
  id="$(main_window_id)"
  for round in $(seq 1 "$1"); do
    while IFS= read -r target; do
      label="${target%%|*}"
      point="${target#*|}"
      if [ "$point" = ax ] || [ -z "$id" ]; then
        ui_run select-row BatteryPulse "$label" --within AXOutline >/dev/null 2>&1 || true
      else
        # shellcheck disable=SC2086
        ui_run click $point --expect BatteryPulse --window "$id" >/dev/null 2>&1 ||
          ui_run select-row BatteryPulse "$label" --within AXOutline >/dev/null 2>&1 || true
      fi
      sleep "$2"
    done <"$3"
  done
}

# pages [profiling]: on the RC with the perf stream, 10 clicks per page every 3 s; then the
# profiling RC under xctrace --no-prompt with a watchdog (a background task the session waits on).
step_pages_b() {
  b_fence
  local capture targets="$WORK/page-targets.txt" template trace watchdog
  case "${1:-}" in
    "")
      install_build C --no-launch
      relaunch_b
      open_main
      place_window
      begin_section 80-pages "Page switches on the RC (WP-17's after)"
      page_targets >"$targets"
      out "- $(app_version), 10 rounds of 7 pages, a page every 3 s, by CGEvent clicks at the sidebar rows' AX frames ($(grep -c '|ax$' "$targets" || true) by AX selection)"
      capture="$LOGS/pages.ndjson"
      perf_capture "$capture"
      cue_clicks 10 3 "$targets"
      perf_stop "$STREAM"
      out "- page.switch lines per page: $(page_counts "$capture" | tr '\n' ',' | sed 's/,$//; s/,/, /g')"
      summarize "$capture" '^(intervals|name|page\.switch)'
      ;;
    profiling)
      begin_section 81-pages-xctrace "Page switches under xctrace (the profiling RC)"
      if [ ! -f "$BUILDS/CP.dmg" ]; then
        out "- not run: no profiling RC"
        return 0
      fi
      if ! xcrun -f xctrace >/dev/null 2>&1; then
        out "- not run: xcrun can't find xctrace"
        return 0
      fi
      if [ "$(proof_result P9)" = fail ]; then
        out "- not run (developer tools asked)"
        return 0
      fi
      # CP may share C's build number (the same run): 0.6.1 goes between them.
      install_build B --no-launch
      install_build CP --no-launch
      relaunch_b
      open_main
      place_window
      page_targets >"$targets"
      xcrun xctrace list templates >"$LOGS/xctrace-templates.txt" 2>&1 || true
      template="$(grep -i -m1 swiftui "$LOGS/xctrace-templates.txt" | sed -E 's/^[[:space:]]+//; s/[[:space:]]+\(.*\)$//' || true)"
      if [ -z "$template" ]; then
        out "- not run: no SwiftUI template in 'xctrace list templates'"
        return 0
      fi
      mkdir -p "$WORK/traces"
      rm -rf "$WORK/traces/pages.trace"
      capture="$LOGS/pages-profiling.ndjson"
      perf_capture "$capture"
      xcrun xctrace record --no-prompt --template "$template" --attach "$(app_pid)" --time-limit 240s \
        --output "$WORK/traces/pages.trace" >"$LOGS/xctrace-record.txt" 2>&1 </dev/null &
      trace=$!
      (sleep 330 && kill -INT "$trace" 2>/dev/null) &
      watchdog=$!
      BACKGROUND="$BACKGROUND $trace $watchdog"
      sleep 5
      cue_clicks 10 3 "$targets"
      wait "$trace" || true
      kill "$watchdog" 2>/dev/null || true
      perf_stop "$STREAM"
      out "- template: $template; trace: $(du -sh "$WORK/traces/pages.trace" 2>/dev/null | cut -f1 || echo none) (kept on the Mac)"
      out "- page.switch lines per page under the profiler: $(page_counts "$capture" | tr '\n' ',' | sed 's/,$//; s/,/, /g')"
      summarize "$capture" '^(intervals|name|page\.switch)'
      # Clear's shadows (2 minutes in Clear) were G-13b's evidence and left with it.
      install_build B --no-launch
      install_build C --no-launch
      relaunch_b
      ;;
    *) fail "usage: $SCRIPT pages [profiling]" ;;
  esac
}

# MARK: - Session B: the energy queue (B4, step 8; WP-21)

# The world the queue touches, one function each, so `queue --dry-run` can stand in for it.
q_now() { date +%s; }
q_sleep() { sleep "$1"; }
q_on_battery() { on_battery; }
q_charge() { battery_percent; }
q_install() { install_build "$1" --no-launch; }
q_sample() { ui_run sample 2>/dev/null || echo "hid_idle_s=unknown locked=unknown lid=unknown screensaver=unknown thermal=unknown lowpower=unknown"; }
q_sudo_ok() { sudo_ok; }
q_set_lpm() { set_lowpowermode "$1"; }
# q_lpm <0|1>: Low Power Mode for battery, its original (prepare's backup) in changes.tsv before
# the queue's first change, so B.md's "Not put back" names it until a read confirms it.
q_lpm() {
  [ -n "$(original_of lowpowermode-battery)" ] ||
    record_change lowpowermode-battery "$(cat "$BACKUP/lowpowermode-battery" 2>/dev/null || echo unknown)" "set by the queue"
  q_set_lpm "$1"
}
q_rusage() { rusage "$1" "$2" >"$3" 2>&1; }
q_perf_start() { perf_capture "$1"; }
q_perf_stop() { perf_stop "$STREAM"; }
q_reads() { app_reads "$1"; }
q_assertions() { pmset -g assertions 2>/dev/null | grep -c BatteryPulse || true; }
q_pmset_log() { pmset -g log 2>/dev/null | awk -v from="$(epoch_stamp "$1")" -v to="$(epoch_stamp "$2")" 'substr($0, 1, 19) >= from && substr($0, 1, 19) <= to' || true; }
q_display_sleep() { pmset displaysleepnow >/dev/null 2>&1 || warn "pmset displaysleepnow failed"; }
q_history_kb() { du -sk "$SUPPORT/History" 2>/dev/null | cut -f1 || echo 0; }
# q_screensaver: the screen saver shows, by its on-screen window (ui sample): a process name match
# fails past macOS's 16-character p_comm (ScreenSaverEngine, legacyScreenSaver), and a lingering
# legacyScreenSaver process doesn't mean the saver runs.
q_screensaver() {
  local saver
  saver="$(sample_field screensaver "$(q_sample)")"
  echo "${saver:-unknown}"
}
q_accessories() { pmset -g accps 2>/dev/null | grep -v -i 'InternalBattery' | grep -c -E '[0-9]+%' || true; }
# q_universal_access: Reduce Transparency and Increase Contrast; a missing key is off, an unreadable
# domain is unknown (the style column then says so, and the window-ID shot decides).
q_universal_access() {
  if ! defaults read com.apple.universalaccess >/dev/null 2>&1; then
    echo "reduceTransparency=unknown increaseContrast=unknown"
    return 0
  fi
  printf 'reduceTransparency=%s increaseContrast=%s' "$(defaults read com.apple.universalaccess reduceTransparency 2>/dev/null || echo 0)" \
    "$(defaults read com.apple.universalaccess increaseContrast 2>/dev/null || echo 0)"
}
q_after_measure() { :; }
q_alert() {
  osascript -e 'on run argv' -e 'display alert "BatteryPulse Session B" message (item 1 of argv) giving up after 25' \
    -e 'end run' "$1" >/dev/null 2>&1 &
}

# q_after_s7: S7's time in the dry run (its launches run in subshells).
q_after_s7() { :; }

q_pack_temp() {
  ioreg -r -c AppleSmartBatteryPack -a -d 1 >"$LOGS/q-pack.plist" 2>/dev/null || true
  plist_value "$LOGS/q-pack.plist" 0.BatteryData.Temperature
}

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

# q_claude: the Claude CLI's child processes (sorted, comma-joined) and its CPU seconds.
q_claude() {
  local pids pid children="" cpu=0 time
  pids="$(claude_pids)"
  for pid in $pids; do
    children="$children $(pgrep -P "$pid" 2>/dev/null | tr '\n' ' ' || true)"
    time="$(ps -o time= -p "$pid" 2>/dev/null | tr -d ' ' || true)"
    cpu="$(awk -v t="$time" -v c="$cpu" 'BEGIN {
      days = 0; if (index(t, "-")) { split(t, d, "-"); days = d[1]; t = d[2] }
      n = split(t, p, ":"); s = 0; for (i = 1; i <= n; i++) s = s * 60 + p[i]
      printf "%.2f", c + s + days * 86400 }')"
  done
  printf '%s %s\n' "$(echo "$children" | tr ' ' '\n' | grep . | sort -n | tr '\n' ',' | sed 's/,$//')" "$cpu"
}

# q_sampler: every 10 s, Session A's columns (the pslog analysis reads them) and the detectors':
# HIDIdleTime, the lock and the lid, the screen saver's window, and the Claude CLI's child PIDs
# (comma-joined, "-" for none) and CPU seconds.
q_sampler() {
  local battery="$LOGS/sample-battery.plist" pack="$LOGS/sample-pack.plist" sample claude
  printf 'epoch\tupdate_time\tremaining_mah\tsystem_power_in_mw\texternal\tpack_temperature\thid_idle_s\tlocked\tlid\tscreensaver\tclaude_children\tclaude_cpu_s\n' \
    >"$LOGS/sampler.tsv"
  while kill -0 "$ARM_PID" 2>/dev/null; do
    ioreg -r -c AppleSmartBattery -a -d 1 >"$battery" 2>/dev/null || true
    ioreg -r -c AppleSmartBatteryPack -a -d 1 >"$pack" 2>/dev/null || true
    sample="$(q_sample)"
    claude="$(q_claude)"
    printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n' "$(date +%s)" "$(plist_value "$battery" 0.UpdateTime)" \
      "$(plist_value "$battery" 0.BatteryData.RemainingCapacity)" \
      "$(plist_value "$battery" 0.PowerTelemetryData.SystemPowerIn)" \
      "$(plist_value "$battery" 0.ExternalConnected)" "$(plist_value "$pack" 0.BatteryData.Temperature)" \
      "$(sample_field hid_idle_s "$sample")" "$(sample_field locked "$sample")" "$(sample_field lid "$sample")" \
      "$(sample_field screensaver "$sample")" "$(children="${claude%% *}"; echo "${children:--}")" "${claude##* }" \
      >>"$LOGS/sampler.tsv"
    sleep 10
  done
}

sample_field() { tr ' ' '\n' <<<"$2" | sed -n "s/^$1=//p" | head -1 || true; }

# The plan (WP-21, 2026-10-24): a discarded warm-up; S2 B C B C B C; S1 B C B C B C; S2 with Low
# Power Mode B C; S4w; S5, S10, S7, S3 and the minimized run; one retry of each run not valid; S6 B
# C last. Each line: kind scenario build pair optional. Optional runs need 56 %, so S6 still
# starts at 50 % or more.
queue_plan() {
  cat <<'EOF'
warmup S2 C w0 no
run S2 B p1 no
run S2 C p1 no
run S2 B p2 no
run S2 C p2 no
run S2 B p3 no
run S2 C p3 no
run S1 B p4 no
run S1 C p4 no
run S1 B p5 no
run S1 C p5 no
run S1 B p6 no
run S1 C p6 no
run S2-LPM B p7 no
run S2-LPM C p7 no
run S4w-standard C s1 no
run S4w-clear C s2 no
run S4w-translucent C s3 no
run S4w-standard2 C s4 no
run S4w-frosted C s5 yes
run S5 C s6 yes
run S10 C s7 yes
s7 S7 B,C s8 no
run S3 C s9 yes
run MIN C s10 yes
retries - - - -
run S6 B p8 no
run S6 C p8 no
EOF
}

# The minutes a plan line takes, for the start message's times.
q_minutes() {
  case "$1" in
    S6) echo 12 ;;
    S7) echo 3 ;;
    *) echo 6 ;;
  esac
}

Q_INDEX=0
Q_LATE=0
# The Claude CLI's background CPU seconds per second, measured over the cooldown (arm_cooldown).
Q_CLAUDE_RATE=0
Q_DISPLAY_OFF=""
QUEUE_RUNS=""

q_header() {
  printf 'index\tkind\tscenario\tbuild\tpair\tstart\tend\tcharge_start\tcharge_end\tenergy_mj_h\tidle_wakeups_h\tinterrupt_wakeups_h\tcpu_s_h\tfootprint_mb\treads_min\tassertions\tthermal\tpack_temp\thistory_kb\tlpm\ttouched\tslept\tadapter\tlocked\tscreensaver\tstyle\tlpm_valid\tclaude\tstatus\n' \
    >"$QUEUE_RUNS"
}

# q_not_run <kind> <scenario> <build> <pair> <reason>: a row with the columns from charge_end to
# claude empty.
q_not_run() {
  printf '%s\t%s\t%s\t%s\t%s\t%s\t\t%s' "$Q_INDEX" "$1" "$2" "$3" "$4" "$(q_now)" "$(q_charge)" >>"$QUEUE_RUNS"
  printf '\t%.0s' 9 10 11 12 13 14 15 16 17 18 19 20 21 22 23 24 25 26 27 28 >>"$QUEUE_RUNS"
  printf '\t%s\n' "not run: $5" >>"$QUEUE_RUNS"
  echo "$(clock) run $Q_INDEX $2 $3: not run: $5"
}

# The scenario's settings, before its launch (every window closed unless the scenario opens one).
q_settings() {
  quit_app
  session_settings
  case "$1" in
    S2*) set_default menuBarShowsPower -bool true ;;
    S4w-* | S5 | MIN)
      set_default betaWindowStyles -bool true
      case "$1" in
        S4w-clear) set_default windowLook -string clear ;;
        S4w-translucent) set_default windowLook -string translucent ;;
        S4w-frosted) set_default windowLook -string frosted ;;
        *) set_default windowLook -string standard ;;
      esac
      ;;
  esac
}

q_launch() {
  open_app
  local tries=0
  until app_running || [ "$tries" -ge 40 ]; do
    sleep 0.25
    tries=$((tries + 1))
  done
  note_rc_pid
  sleep 1
}

# q_setup <scenario> <index>: the scenario's state before its quiet minute, by a reopen event,
# CGEvent clicks at CGWindowList frames (hit-tested by the window list alone, --cg-only) and AX
# into TextEdit only; never an AX call into the measured process. Prints why not, and fails, when
# it can't.
q_setup() {
  local scenario="$1" index="$2" line id rect offset title item before after
  case "$scenario" in
    S4w-* | S5 | MIN)
      open_main
      line="$(main_window_line)"
      if ! line_ok "$line"; then
        echo "the window isn't clear: ${line:-not on screen}"
        return 1
      fi
      id="$(line_id "$line")"
      rect="$(line_rect "$line")"
      case "$scenario" in
        S4w-*)
          mkdir -p "$SHOTS/queue"
          screencapture -x -o -l"$id" "$SHOTS/queue/$index-$scenario.png" 2>/dev/null || true
          ;;
        S5)
          track_launch TextEdit open -a TextEdit "$COVER" || true
          sleep 3
          # 10 points past each edge, so a size the window server rounds still covers it all; the
          # cover's own window, never one of his documents.
          # shellcheck disable=SC2046
          ui_run position TextEdit $(awk '{ printf "%d %d %d %d", $1 - 10, $2 - 10, $3 + 20, $4 + 20 }' <<<"$rect") \
            --window "$COVER_TITLE" >/dev/null 2>&1 || {
            echo "TextEdit couldn't be placed over the window"
            return 1
          }
          sleep 1
          line="$(main_window_line)"
          case "$line" in *"covered by TextEdit"*) ;; *)
            echo "TextEdit doesn't cover the window: $line"
            return 1
            ;;
          esac
          # The whole window, not a corner of it: a TextEdit window's bounds contain the main
          # window's (CGWindowList only).
          if ! ui_run windows --app TextEdit 2>/dev/null | awk -F '\t' -v r="$rect" '$2 == "layer 0" {
              split($4, b, " "); split(r, m, " ")
              if (b[1] <= m[1] && b[2] <= m[2] && b[1] + b[3] >= m[1] + m[3] && b[2] + b[4] >= m[2] + m[4]) found = 1 }
              END { exit !found }'; then
            echo "TextEdit covers only part of the window"
            return 1
          fi
          ;;
        MIN)
          offset="$(cat "$WORK/minimize-offset" 2>/dev/null || true)"
          [ -n "$offset" ] || {
            echo "no minimize button offset (ready records it)"
            return 1
          }
          title="$(ui_run windows --app BatteryPulse 2>/dev/null | awk -F '\t' -v id="$id" '$1 == id { n = $5; sub(/^alpha [0-9.]* */, "", n); gsub(/"/, "", n); print n }' || true)"
          echo "$title" >"$WORK/q-min-title"
          # The Dock's minimized-window tiles before the minimize (AX into the Dock, never into
          # BatteryPulse): the teardown clicks only the tile that appears.
          ui_run frame --dock --list >"$WORK/q-min-dock" 2>/dev/null || : >"$WORK/q-min-dock"
          # shellcheck disable=SC2046
          ui_run click --cg-only $(awk -v r="$rect" -v o="$offset" 'BEGIN { split(r, w, " "); split(o, d, " "); printf "%d %d", w[1] + d[1], w[2] + d[2] }') \
            --expect BatteryPulse --window "$id" >/dev/null 2>&1 || {
            echo "the minimize click was refused"
            return 1
          }
          sleep 3
          case "$(main_window_line)" in *"isn't on screen"* | "") ;; *)
            echo "the window didn't minimize"
            return 1
            ;;
          esac
          ;;
      esac
      ;;
    S3)
      item="$(ui_run windows --status-item 2>/dev/null | cut -d' ' -f2- || true)"
      [ -n "$item" ] || {
        echo "no menu bar item window"
        return 1
      }
      before="$(ui_run windows --app BatteryPulse 2>/dev/null | grep -c . || true)"
      # shellcheck disable=SC2046
      ui_run click --cg-only $(awk '{ printf "%d %d", $1 + $3 / 2, $2 + $4 / 2 }' <<<"$item") --expect BatteryPulse \
        --window "$(ui_run windows --status-item 2>/dev/null | cut -d' ' -f1)" >/dev/null 2>&1 || {
        echo "the click on the menu bar item was refused"
        return 1
      }
      sleep 2
      after="$(ui_run windows --app BatteryPulse 2>/dev/null | grep -c . || true)"
      [ "${after:-0}" -gt "${before:-0}" ] || {
        echo "the popover didn't open"
        return 1
      }
      echo "$before" >"$WORK/q-s3-before"
      ;;
  esac
  return 0
}

# q_confirm <scenario>: the state still holds at the run's end (CGWindowList only); prints why not.
q_confirm() {
  local open
  case "$1" in
    S1 | S2 | S2-LPM | S6 | S10)
      open="$(ui_run windows --app BatteryPulse 2>/dev/null | awk -F '\t' '$2 == "layer 0"' | grep -c . || true)"
      [ "${open:-0}" = 0 ] || echo "a window open ($open on screen)"
      ;;
    S3)
      [ "$(ui_run windows --app BatteryPulse 2>/dev/null | grep -c . || true)" -gt "$(cat "$WORK/q-s3-before" 2>/dev/null || echo 0)" ] ||
        echo "the popover closed during the run"
      ;;
    MIN) case "$(main_window_line)" in *"isn't on screen"* | "") ;; *) echo "the window came back during the run" ;; esac ;;
    S4w-*) line_ok "$(main_window_line)" || echo "the window wasn't clear at the end" ;;
  esac
  return 0
}

q_teardown() {
  local item title
  case "$1" in
    S5) close_cover || warn "TextEdit's cover window didn't close" ;;
    S3)
      item="$(ui_run windows --status-item 2>/dev/null || true)"
      # shellcheck disable=SC2046
      [ -z "$item" ] || ui_run click --cg-only $(cut -d' ' -f2- <<<"$item" | awk '{ printf "%d %d", $1 + $3 / 2, $2 + $4 / 2 }') \
        --expect BatteryPulse --window "${item%% *}" >/dev/null 2>&1 || true
      ;;
    MIN)
      # The tile that appeared at the minimize (the Dock's AX tree, never BatteryPulse's), titled
      # as the window was, then CGWindowList's word; never an app's tile or one of his windows.
      title="$(cat "$WORK/q-min-title" 2>/dev/null || true)"
      if ui_run click --expect dock-tile --new-since "$WORK/q-min-dock" ${title:+--dock-title "$title"} >/dev/null 2>&1; then
        sleep 3
        if line_ok "$(main_window_line)"; then echo "restored from the Dock tile" >"$WORK/q-min-restore"; else echo "the Dock tile click didn't bring the window back" >"$WORK/q-min-restore"; fi
      else
        echo "no single new Dock tile to click" >"$WORK/q-min-restore"
      fi
      ;;
  esac
  return 0
}

# q_wait_for <what> <seconds>: nominal thermal state, or HIDIdleTime of 60 s; at most <seconds>.
# An unread state isn't waited for: the run goes on at once, and its row says what wasn't read
# (ui missing or failing would otherwise cost every run 20 minutes, and the queue its S6).
q_wait_for() {
  local waited=0 value
  while [ "$waited" -lt "$2" ]; do
    case "$1" in
      nominal) value="$(sample_field thermal "$(q_sample)")" ;;
      *) value="$(sample_field hid_idle_s "$(q_sample)")" ;;
    esac
    case "$value" in
      "" | unknown)
        echo "the $1 state can't be read (ui sample): no wait; the row says so"
        return 2
        ;;
    esac
    case "$1" in
      nominal) [ "$value" != nominal ] || return 0 ;;
      *) awk -v i="$value" 'BEGIN { exit !(i + 0 >= 60) }' && return 0 ;;
    esac
    q_sleep 30
    waited=$((waited + 30))
  done
  case "$1" in
    nominal) echo "the thermal state isn't nominal after 10 minutes: the run goes on, its row says so" ;;
    *) echo "HIDIdleTime stays under 60 s: the run goes on, the touch detector decides" ;;
  esac
  return 1
}

# The time S6's pair keeps (2 x 12 minutes, its warning and a margin for the waits): no optional
# run or retry starts unless it ends before Q_LATE minus this.
Q_S6_RESERVE=$((25 * 60))

# q_time_for <seconds>: a run that long still leaves S6 its time before the 3-hour cap.
q_time_for() { [ $(($(q_now) + $1 + Q_S6_RESERVE)) -le "$Q_LATE" ]; }

# q_detect <start> <end> <scenario> <sample at start> <sample at end> <claude at start> <claude at
# end> <rusage file> <want lpm> <first S6> [<sample before the display went off>]: the detector
# columns, tab-separated: touched, slept, adapter, locked, screensaver, style, lpm, claude, then
# the reasons for "not valid" (or "-").
q_detect() {
  local start="$1" end="$2" scenario="$3" s0="$4" s1="$5" c0="$6" c1="$7" file="$8" want="$9" first_s6="${10}"
  local touched=no slept=no adapter=no locked=no saver=no style=- lpm=no claude=no reasons="" rows log idle
  rows="$(awk -F '\t' -v s="$start" -v e="$end" 'NR > 1 && $1 >= s && $1 <= e' "$LOGS/sampler.tsv" 2>/dev/null || true)"
  idle="$(sample_field hid_idle_s "$s1")"
  # An unread HIDIdleTime ("" or unknown) says nothing either way.
  if awk -v i="$idle" -v d=$((end - start)) 'BEGIN { exit !(i != "" && i != "unknown" && i + 2 < d) }'; then touched=yes; fi
  if [ -n "$rows" ] && awk -F '\t' -v s="$start" '$7 != "" && $7 != "unknown" && $7 != "-" && $7 + 3 < $1 - s { found = 1 } END { exit !found }' <<<"$rows"; then touched=yes; fi
  if awk -F= '$1 == "seconds" { c = $2 } $1 == "awake_seconds" { a = $2 } END { exit !(a != "" && c - a > 1) }' "$file" 2>/dev/null; then slept=yes; fi
  log="$(q_pmset_log "$start" "$end")"
  # Not "Wake Requests" (scheduled wakes) or "Sleep Service": the Mac's own sleeps and wakes.
  if awk '($4 == "Sleep" && $5 != "Service") || $4 == "DarkWake" || ($4 == "Wake" && $5 != "Requests") { found = 1 } END { exit !found }' <<<"$log"; then slept=yes; fi
  # The sampler's ExternalConnected comes from plutil's raw form, which prints a boolean as true
  # or false; ioreg's text form says Yes.
  if [ -n "$rows" ] && awk -F '\t' '$5 == "true" || $5 == "Yes" || $5 == "1" { found = 1 } END { exit !found }' <<<"$rows"; then adapter=yes; fi
  if ! q_on_battery; then adapter=yes; fi
  if [ "$scenario" = S6 ]; then
    # pmset displaysleepnow locks the screen when a password is required at once: only the first
    # S6 run's start counts, read before the display went off (the 11th argument).
    if [ "$first_s6" = yes ] && [ "$(sample_field locked "${11:-$s0}")" = yes ]; then locked=yes; fi
  else
    if [ "$(sample_field locked "$s0")" = yes ] || [ "$(sample_field locked "$s1")" = yes ]; then locked=yes; fi
    if [ "$(sample_field lid "$s0")" = closed ] || [ "$(sample_field lid "$s1")" = closed ]; then locked=yes; fi
    if [ -n "$rows" ] && awk -F '\t' '$8 == "yes" || $9 == "closed" { found = 1 } END { exit !found }' <<<"$rows"; then locked=yes; fi
  fi
  if [ -n "$rows" ] && awk -F '\t' '$10 == "yes" { found = 1 } END { exit !found }' <<<"$rows"; then saver=yes; fi
  if [ "$(q_screensaver)" = yes ]; then saver=yes; fi
  case "$scenario" in
    S4w-*)
      style=no
      case "$(q_universal_access)" in *"=1"*) style=yes ;; *unknown*) style=unknown ;; esac
      ;;
  esac
  local lpm0 lpm1
  lpm0="$(sample_field lowpower "$s0")"
  lpm1="$(sample_field lowpower "$s1")"
  # Unread by ui: pmset's setting for battery, which is the state on battery.
  case "$lpm0" in 0 | 1) ;; *) lpm0="$(lowpowermode_of Battery)" ;; esac
  case "$lpm1" in 0 | 1) ;; *) lpm1="$(lowpowermode_of Battery)" ;; esac
  if [ "$lpm0" != "$want" ] || [ "$lpm1" != "$want" ]; then lpm=yes; fi
  # The Claude CLI: a child process at the end, or in any sampler row of the run, that wasn't there
  # at its start; or more CPU than its own background rate over the cooldown allows, plus 2 s.
  if awk -v a="${c0%% *}" -v b="${c1%% *}" -v x="${c0##* }" -v y="${c1##* }" -v r="${Q_CLAUDE_RATE:-0}" \
    -v d=$((end - start)) 'BEGIN {
      n = split(a, s, ","); for (i = 1; i <= n; i++) seen[s[i]] = 1
      m = split(b, e, ","); for (i = 1; i <= m; i++) if (e[i] != "" && !(e[i] in seen)) found = 1
      if (y - x > r * d + 2) found = 1
      exit !found }'; then claude=yes; fi
  if [ -n "$rows" ] && awk -F '\t' -v a="${c0%% *}" '
      BEGIN { n = split(a, s, ","); for (i = 1; i <= n; i++) seen[s[i]] = 1 }
      $11 != "" && $11 != "-" { m = split($11, p, ","); for (i = 1; i <= m; i++) if (p[i] != "" && !(p[i] in seen)) found = 1 }
      END { exit !found }' <<<"$rows"; then claude=yes; fi
  [ "$touched" = no ] || reasons="$reasons, touched"
  [ "$slept" = no ] || reasons="$reasons, slept"
  [ "$adapter" = no ] || reasons="$reasons, adapter"
  [ "$locked" = no ] || reasons="$reasons, locked"
  [ "$saver" = no ] || reasons="$reasons, screen saver"
  [ "$style" != yes ] || reasons="$reasons, style not in effect"
  [ "$lpm" = no ] || reasons="$reasons, LPM"
  [ "$claude" = no ] || reasons="$reasons, Claude active"
  if [ "$scenario" = S6 ]; then
    # Valid only with the display off from the run's start to its end.
    if ! awk -v s="$(epoch_stamp "$start")" '
        /Display is turned off/ { state = "off" } /Display is turned on/ { if (substr($0, 1, 19) > s) on = 1; state = "on" }
        END { exit !(state == "off" && !on) }' <<<"$(q_pmset_log $((start - 14400)) "$end")"; then
      reasons="$reasons, display on"
    fi
  fi
  printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n' "$touched" "$slept" "$adapter" "$locked" "$saver" "$style" "$lpm" "$claude" \
    "${reasons#, }"
}

# q_run <kind> <scenario> <build> <pair> <optional>: one energy run of WP-21 and its row: the build
# installed, the scenario's settings, Low Power Mode as planned, a nominal thermal state, HIDIdleTime
# of 60 s, the launch, the scenario's state, the quiet minute, then rusage over 4 minutes (S6 10,
# the displays asleep) with the perf lines, and the detectors.
q_run() {
  local kind="$1" scenario="$2" build="$3" pair="$4" optional="$5" floor=50 want=0 seconds=240 charge capture file pid
  local start end s0 s1 c0 c1 detect status assertions reads thermal why first_s6=no s_dark=""
  Q_INDEX=$((Q_INDEX + 1))
  Q_BUILD="$build"
  if [ "$optional" = yes ] || [ "$kind" = retry ]; then floor=56; fi
  if [ "$scenario" = S2-LPM ]; then want=1; fi
  if [ "$scenario" = S6 ]; then seconds=600; fi
  if [ "$(q_now)" -ge "$Q_LATE" ]; then
    q_not_run "$kind" "$scenario" "$build" "$pair" "late (3 hours after the bedtime unplug)"
    return 0
  fi
  if ! q_on_battery; then
    q_not_run "$kind" "$scenario" "$build" "$pair" "on the adapter"
    return 0
  fi
  charge="$(q_charge)"
  case "$charge" in "" | *[!0-9]*) charge=0 ;; esac
  if [ "$charge" -lt "$floor" ]; then
    q_not_run "$kind" "$scenario" "$build" "$pair" "below $floor %"
    return 0
  fi
  if [ "$scenario" = S10 ] && [ "$(q_accessories)" = 0 ]; then
    q_not_run "$kind" "$scenario" "$build" "$pair" "pmset -g accps lists no accessory"
    return 0
  fi
  if { [ "$optional" = yes ] || [ "$kind" = retry ]; } && ! q_time_for $(($(q_minutes "$scenario") * 60)); then
    q_not_run "$kind" "$scenario" "$build" "$pair" "time kept for S6"
    return 0
  fi
  echo "$(clock) run $Q_INDEX: $kind $scenario on $build at $charge %"
  if ! (q_install "$build") >"$LOGS/q-install-$Q_INDEX.txt" 2>&1; then
    q_not_run "$kind" "$scenario" "$build" "$pair" "error (install: $(tail -1 "$LOGS/q-install-$Q_INDEX.txt"))"
    return 0
  fi
  q_settings "$scenario"
  if [ "$want" = 1 ] && [ "$(sample_field lowpower "$(q_sample)")" != 1 ]; then
    if ! q_sudo_ok || ! q_lpm 1; then
      q_not_run "$kind" "$scenario" "$build" "$pair" "no sudo ticket"
      return 0
    fi
  fi
  if [ "$want" = 0 ] && [ "$(lowpowermode_of Battery)" = 1 ] && q_sudo_ok; then q_lpm 0 || true; fi
  q_wait_for nominal 600 || true
  q_wait_for idle 600 || true
  q_launch
  if ! why="$(q_setup "$scenario" "$Q_INDEX")"; then
    q_teardown "$scenario"
    q_not_run "$kind" "$scenario" "$build" "$pair" "setup: $why"
    return 0
  fi
  q_sleep 60
  if [ "$scenario" = S6 ]; then
    if [ -z "$Q_DISPLAY_OFF" ]; then
      first_s6=yes
      # The warning 30 s before the display goes off, not before the install and the quiet minute.
      q_announce_s6
    fi
    # S6's lock check: the state before pmset displaysleepnow, which may lock the screen itself.
    s_dark="$(q_sample)"
    let_display_sleep
    q_display_sleep
    Q_DISPLAY_OFF=1
    q_sleep 5
  fi
  pid="$(app_pid)"
  if [ -z "$pid" ]; then
    q_teardown "$scenario"
    q_not_run "$kind" "$scenario" "$build" "$pair" "BatteryPulse wasn't running"
    return 0
  fi
  capture="$LOGS/queue-$Q_INDEX-$scenario-$build.ndjson"
  file="$LOGS/queue-$Q_INDEX-$scenario-$build.rusage"
  s0="$(q_sample)"
  c0="$(q_claude)"
  thermal="$(sample_field thermal "$s0")"
  q_perf_start "$capture"
  start="$(q_now)"
  q_rusage "$pid" "$seconds" "$file" &
  local measuring=$!
  q_sleep 5
  assertions="$(q_assertions)"
  if [ "$scenario" = S6 ]; then pmset -g assertions >"$LOGS/queue-$Q_INDEX-S6-assertions.txt" 2>&1 || true; fi
  # A trapped signal ends wait early: wait again until rusage has really finished.
  while kill -0 "$measuring" 2>/dev/null; do wait "$measuring" || true; done
  wait "$measuring" 2>/dev/null || true
  q_after_measure "$seconds"
  end="$(q_now)"
  q_perf_stop
  s1="$(q_sample)"
  c1="$(q_claude)"
  why="$(q_confirm "$scenario")"
  q_teardown "$scenario"
  if [ "$scenario" = S2-LPM ]; then q_lpm 0 || warn "Low Power Mode is still on"; fi
  reads="$(q_reads "$capture")"
  detect="$(q_detect "$start" "$end" "$scenario" "$s0" "$s1" "$c0" "$c1" "$file" "$want" "$first_s6" "$s_dark")"
  status="${detect##*"$TAB"}"
  if [ -n "$why" ]; then status="${status:+$status, }$why"; fi
  if [ -z "$(rusage_value "$file" energy_mj_per_h)" ]; then
    status="${status:+$status, }rusage failed (the app quit)"
    note_line "queue run $Q_INDEX ($scenario on $build): rusage failed, so the row has no figures (BatteryPulse quit or crashed during it)"
  fi
  if [ -n "$status" ]; then status="not valid: $status"; else status=valid; fi
  if [ "$kind" = warmup ]; then status="warm-up, discarded ($status)"; fi
  if [ "$thermal" != nominal ]; then status="$status; thermal $thermal"; fi
  printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n' "$Q_INDEX" "$kind" "$scenario" "$build" \
    "$pair" "$start" "$end" "$charge" "$(q_charge)" "$(rusage_value "$file" energy_mj_per_h)" \
    "$(rusage_value "$file" idle_wakeups_per_h)" "$(rusage_value "$file" interrupt_wakeups_per_h)" \
    "$(rusage_value "$file" cpu_s_per_h)" \
    "$(awk -F= '$1 == "phys_footprint_bytes" { printf "%.1f", $2 / 1048576 }' "$file")" \
    "$(awk -v n="${reads:-0}" -v s="$seconds" 'BEGIN { printf "%.1f", n * 60 / s }')" "$assertions" \
    "$thermal/$(sample_field thermal "$s1")" "$(q_pack_temp)" "$(q_history_kb)" \
    "$(sample_field lowpower "$s0")/$(sample_field lowpower "$s1")" "${detect%"$TAB"*}" "$status" >>"$QUEUE_RUNS"
  echo "$(clock) run $Q_INDEX $scenario $build: $status"
}

# q_retries: one retry of each run marked not valid, none below 56 %; a run of S1, S2 or S2-LPM is
# retried as its B and C pair, never alone; a Low Power Mode run that wasn't valid isn't retried,
# since nothing would change it.
q_retries() {
  local list kind scenario build pair status done_pairs=" "
  # A snapshot of the rows: the retries append to the same file.
  list="$(awk -F '\t' 'NR > 1 && $2 == "run" { print $2 "\t" $3 "\t" $4 "\t" $5 "\t" $NF }' "$QUEUE_RUNS")"
  while IFS=$'\t' read -r kind scenario build pair status; do
    [ -n "$kind" ] || continue
    case "$status" in "not valid: "*) ;; *) continue ;; esac
    case "$status" in *LPM*) continue ;; esac
    case "$scenario" in
      S1 | S2 | S2-LPM)
        case "$done_pairs" in *" $pair "*) continue ;; esac
        done_pairs="$done_pairs$pair "
        # The pair or neither: a lone B retry would leave its C to S6's time.
        if ! q_time_for $((2 * $(q_minutes "$scenario") * 60)); then
          Q_INDEX=$((Q_INDEX + 1))
          q_not_run retry "$scenario" B "$pair" "time kept for S6"
          Q_INDEX=$((Q_INDEX + 1))
          q_not_run retry "$scenario" C "$pair" "time kept for S6"
          continue
        fi
        q_run retry "$scenario" B "$pair" yes </dev/null
        q_run retry "$scenario" C "$pair" yes </dev/null
        ;;
      S6 | S7) ;;
      *) q_run retry "$scenario" "$build" "$pair" yes </dev/null ;;
    esac
  done <<<"$list"
}

# q_s7: 5 cold launches per build (B, then C) to menuBarReady, with the reads before it.
q_s7() {
  if [ "$(q_now)" -ge "$Q_LATE" ] || ! q_on_battery || [ "$(q_charge)" -lt 50 ]; then
    Q_INDEX=$((Q_INDEX + 1))
    q_not_run s7 S7 B,C s8 "late, on the adapter or below 50 %"
    return 0
  fi
  begin_section 89-s7 "S7, cold launches to menuBarReady (B against C)"
  (s7_launches B 5) || out "- S7 on B: not run: error"
  (s7_launches C 5) || out "- S7 on C: not run: error"
  q_after_s7
}

# q_announce_s6: the dark runs are announced, never silent to a person at the Mac: inside the first
# S6 run, 30 s before its display goes off, the arm window shows the warning and an alert comes to
# the front (a notification would be hidden by the Focus); the alert gives up before the display
# goes off. No sound, since none plays from `mark away` until his morning continue.
q_announce_s6() {
  local text="The display turns off for 10 minutes on purpose; please don't wake the Mac."
  echo
  echo "=== $(clock): $text (the display turns off in 30 s) ==="
  q_alert "$text"
  q_sleep 30
}

# queue_expected <start epoch>: the start message's times.
queue_expected() {
  local at="$1" kind scenario build pair optional s6=""
  while read -r kind scenario build pair optional; do
    case "$kind" in retries) continue ;; esac
    if [ "$scenario" = S6 ] && [ -z "$s6" ]; then s6="$at"; fi
    at=$((at + $(q_minutes "$scenario") * 60))
  done < <(queue_plan)
  echo "$s6 $at"
}

# queue_run <bedtime unplug epoch>: the queue, in arm's process (its pid is in queue.started).
queue_run() {
  local unplug="$1" kind scenario build pair optional times started
  Q_LATE=$((unplug + 3 * 3600))
  QUEUE_RUNS="$LOGS/queue-runs.tsv"
  q_header
  begin_section 88-queue "The energy queue (B4; WP-21)"
  started="$(q_now)"
  times="$(queue_expected "$started")"
  epoch_hm "${times##* }" >"$WORK/queue.expected"
  out "- started $(clock) at $(q_charge) %, on $(if q_on_battery; then echo battery; else echo "the adapter"; fi); the bedtime unplug at $(epoch_hm "$unplug"); no run starts after $(epoch_hm "$Q_LATE")"
  out "- the Claude CLI's background CPU over the cooldown: $Q_CLAUDE_RATE s a second (the Claude detector allows that rate over a run, plus 2 s)"
  echo "The queue runs now. S6 (the display off for 10 minutes on purpose) at about $(epoch_hm "${times%% *}"); the end at about $(epoch_hm "${times##* }"). Please keep the lid open until then."
  if [ -z "$DRY_RUN" ]; then
    pmset -g assertions >"$LOGS/queue-assertions-start.txt" 2>&1 || true
    out "- pmset -g assertions at the start: $(grep -c BatteryPulse "$LOGS/queue-assertions-start.txt" || true) BatteryPulse lines (the full list stays on the Mac)"
    out "- keep-awake assertions of other processes at the start (user activity, display or idle sleep): $(keepawake_holders | grep -c . || true) (names stay on the Mac)"
    out "- the energy setup: his, at the arm window's bedtime prompt (the brightness about half by the keys, a Focus on), not read back; auto-brightness and True Tone as he keeps them"
    start_pslog
    q_sampler &
    BACKGROUND="$BACKGROUND $!"
    if [ "$(lowpowermode_of Battery)" = 1 ]; then
      if q_sudo_ok && q_lpm 0; then out "- Low Power Mode was set for battery: off for the runs (the EXIT trap puts it back)"; else
        out "- Low Power Mode is set for battery and there is no sudo ticket: every run but S2-LPM is LPM (not valid)"
      fi
    fi
    (q_install B) >"$LOGS/q-install-0.txt" 2>&1 || out "- install B at the start: error ($(tail -1 "$LOGS/q-install-0.txt"))"
  fi
  # Each run is wrapped: a failure is its row's "not run: error", and the queue goes on (never
  # set -e's exit). Nothing in a run reads the plan's standard input.
  while read -r kind scenario build pair optional; do
    case "$kind" in
      warmup | run) q_run "$kind" "$scenario" "$build" "$pair" "$optional" </dev/null || q_not_run "$kind" "$scenario" "$build" "$pair" "error" ;;
      s7) q_s7 </dev/null || true ;;
      retries) q_retries </dev/null || true ;;
    esac
  done < <(queue_plan)
  queue_report
}

# queue_report: the energy table with the detector columns, then per scenario and build the
# median of the valid runs (the warm-up never counts), C ÷ B, and B against Session A's B.
queue_report() {
  use_section 88-queue "The energy queue (B4; WP-21)"
  out ""
  out "| # | Kind | Run | Build | Charge | Energy mJ/h | Idle wake-ups/h | Interrupt wake-ups/h | CPU s/h | Footprint MB | Reads/min | Assertions | Thermal | Pack temp | History KB | LPM | Touched | Slept | Adapter | Locked | Screen saver | Style | LPM valid | Claude | Status |"
  out "|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|"
  awk -F '\t' 'NR > 1 {
      lpmok = ($27 == "no") ? "yes" : ($27 == "yes" ? "no" : $27)
      printf "| %s | %s | %s | %s | %s→%s | %s | %s | %s | %s | %s | %s | %s | %s | %s | %s | %s | %s | %s | %s | %s | %s | %s | %s | %s | %s |\n",
        $1, $2, $3, $4, $8, $9, $10, $11, $12, $13, $14, $15, $16, $17, $18, $19, $20, $21, $22, $23, $24, $25, $26, lpmok, $28, $29 }' \
    "$QUEUE_RUNS" | tee -a "$SECTION"
  out ""
  out "Medians of the valid runs per scenario and build, a valid run whose thermal state wasn't nominal among them (its row says so; the spread is the lowest and highest run):"
  out ""
  queue_medians | tee -a "$SECTION"
  queue_g14b
}

# queue_g14b: G-14b's Session B half (PLAN.md §7.1, Appendix C): `read cached` p50 and
# `registry.missed` per hour of logged runtime, over the perf lines of every C run of the queue.
queue_g14b() {
  local all="$LOGS/queue-C-perf.ndjson" summary minutes cached missed rate
  [ -z "$DRY_RUN" ] || return 0
  cat "$LOGS"/queue-*-C.ndjson >"$all" 2>/dev/null || true
  minutes="$(awk -F '\t' 'NR > 1 && $4 == "C" && $7 != "" { s += $7 - $6 } END { printf "%.0f", s / 60 }' "$QUEUE_RUNS")"
  summary="$(perf_stats "$all" 2>/dev/null || true)"
  cached="$(awk '$1 == "read" && $2 == "cached" { print $4 " ms over " $3 " reads" }' <<<"$summary")"
  missed="$(awk '$1 == "registry.missed" && $2 != "(all)" { n += $3 } END { print n + 0 }' <<<"$summary")"
  rate="$(awk -v n="$missed" -v m="${minutes:-0}" 'BEGIN { if (m > 0) printf "%.1f an hour", n * 60 / m; else print "no runtime logged" }')"
  out ""
  out "- G-14b over the C runs' perf lines (${minutes:-0} minutes measured): read cached p50 ${cached:-none}; registry.missed $missed, $rate (the criteria: p50 under 2 ms, at most 1 an hour)"
  summarize "$all" '^(intervals|name|read|events|registry\.missed)'
}

# The rows of Session A's energy table (~/bp-062/A/logs/energy-rows.md) as "scenario build energy
# idle interrupt cpu reads", for the cross-session check and the chain C ÷ B × B ÷ A.
# Session A's S6 B run is not valid (Appendix C: he woke the display and unlocked about a minute
# in), though its row doesn't say so: it never counts, so S6's cross-session columns stay "-".
session_a_rows() {
  local file="$HOME/bp-062/A/logs/energy-rows.md"
  [ -f "$file" ] || return 0
  awk -F '|' 'NR > 2 && $4 !~ /not/ { gsub(/ /, ""); if ($2 == "S6" && $3 == "B") next; if ($6 + 0 > 0) print $2, $3, $6, $7, $8, $9, $11 }' "$file"
}

queue_medians() {
  awk -F '\t' -v arows="$(session_a_rows | tr '\n' ';')" '
    function median(list,    n, v, i, j, t) {
      n = split(list, v, " ")
      for (i = 1; i <= n; i++) for (j = i + 1; j <= n; j++) if (v[j] + 0 < v[i] + 0) { t = v[i]; v[i] = v[j]; v[j] = t }
      if (n == 0) return ""
      return (n % 2) ? v[(n + 1) / 2] : (v[n / 2] + v[n / 2 + 1]) / 2
    }
    function spread(list,    n, v, i, lo, hi) {
      n = split(list, v, " "); if (n == 0) return "-"
      lo = hi = v[1] + 0
      for (i = 2; i <= n; i++) { if (v[i] + 0 < lo) lo = v[i] + 0; if (v[i] + 0 > hi) hi = v[i] + 0 }
      return lo "-" hi
    }
    NR > 1 && $NF ~ /^valid/ && $2 != "warmup" {
      key = $3 " " $4; if (!(key in keys)) order[++keyCount] = key; keys[key] = 1; count[key]++
      energy[key] = energy[key] " " $10; idle[key] = idle[key] " " $11; irq[key] = irq[key] " " $12
      cpu[key] = cpu[key] " " $13; reads[key] = reads[key] " " $15
    }
    END {
      n = split(arows, lines, ";")
      for (i = 1; i <= n; i++) {
        split(lines[i], f, " "); if (f[1] == "") continue
        k = f[1] " " f[2]; aenergy[k] = aenergy[k] " " f[3]; acpu[k] = acpu[k] " " f[6]; aidle[k] = aidle[k] " " f[4]
      }
      print "| Scenario | Build | Valid runs | Energy mJ/h (spread) | Idle wake-ups/h | Interrupt wake-ups/h | CPU s/h (spread) | Reads/min | C ÷ B energy | C ÷ B CPU | B here ÷ B in Session A (energy, CPU) | C ÷ A energy, CPU (C ÷ B × B ÷ A) |"
      print "|---|---|---|---|---|---|---|---|---|---|---|---|"
      for (o = 1; o <= keyCount; o++) {
        key = order[o]; split(key, kb, " "); s = kb[1]; b = kb[2]
        e = median(energy[key]); c = median(cpu[key])
        ratio_e = "-"; ratio_c = "-"; cross = "-"; chain = "-"
        if (b == "C" && (s " B") in keys) {
          eb = median(energy[s " B"]); cb = median(cpu[s " B"])
          if (eb > 0) ratio_e = sprintf("%.2f", e / eb)
          if (cb > 0) ratio_c = sprintf("%.2f", c / cb)
          if ((s " A") in aenergy && (s " B") in aenergy) {
            ea = median(aenergy[s " A"]); ebA = median(aenergy[s " B"]); ca = median(acpu[s " A"]); cbA = median(acpu[s " B"])
            if (ea > 0 && ca > 0 && eb > 0 && cb > 0) chain = sprintf("%.2f, %.2f", (e / eb) * (ebA / ea), (c / cb) * (cbA / ca))
          }
        }
        if (b == "B" && (s " B") in aenergy) {
          ebA = median(aenergy[s " B"]); cbA = median(acpu[s " B"])
          if (ebA > 0 && cbA > 0) {
            de = e / ebA; dc = c / cbA
            cross = sprintf("%.2f, %.2f%s", de, dc, (de < 0.85 || de > 1.15 || dc < 0.85 || dc > 1.15) ? " (more than 15 %: noise)" : "")
          }
        }
        printf "| %s | %s | %d | %.1f (%s) | %.0f | %.0f | %.3f (%s) | %.1f | %s | %s | %s | %s |\n", s, b, count[key], e, spread(energy[key]),
          median(idle[key]), median(irq[key]), c, spread(cpu[key]), median(reads[key]), ratio_e, ratio_c, cross, chain
      }
    }' "$QUEUE_RUNS"
}

# MARK: - Session B: the arm window (B0b to B5; WP-21's arm)

ARM_PID=""
ARM_START=""
ARM_SUDO=""
ARM_GUI_CAFFEINATE=""
ARM_QUEUE_CAFFEINATE=""
ARM_READY_WAITER=""
ARM_POWER_WAITER=""
ARM_KEEPALIVE=""
# The status line's state: the unplug's epoch, the phase after it (quiet, cooldown), the cooldown's
# and the queue's expected ends, the keep-awake holders' names, the status last shown, and whether
# a Return before ready was answered already.
ARM_UNPLUG=""
ARM_PHASE=""
ARM_COOL_END=""
ARM_QUEUE_END=""
ARM_HOLDERS=""
ARM_SHOWN=""
ARM_TOLD=""
# What he does at bedtime, besides his password: the energy setup is his, by the keys (no computer
# use touches the brightness), and the Focus keeps banners off the runs.
ARM_BEDTIME="set the brightness to about half with the brightness keys, turn a Focus on (Control Center), then unplug the adapter and leave the lid open"

# arm open: writes ~/bp-062/B/arm.command and opens it in a new Terminal window (open -a
# Terminal: no Automation needed). The window runs the frozen worktree's script.
arm_open() {
  b_fence
  mkdir -p "$WORK"
  cat >"$WORK/arm.command" <<EOF
#!/bin/bash
# BatteryPulse Session B's arm window (docs/plans/0.6.2/PLAN.md §6, WP-21), opened by the session.
exec /bin/bash "$HERE/m5-session.sh" arm
EOF
  chmod +x "$WORK/arm.command"
  open -a Terminal "$WORK/arm.command"
  echo "the arm window opens (Terminal, \"BatteryPulse arm\"); it keeps the display awake for the GUI phase and asks for nothing yet"
}

arm_say() {
  printf '%s %s\n' "$(date '+%H:%M')" "$*"
  printf '%s\t%s\n' "$(clock)" "$*" >>"$LOGS/arm.log"
  # A line said between two statuses: the status shows again after it.
  ARM_SHOWN=""
}

arm_state() {
  if [ -f "$READY_FILE" ]; then
    if grep -q '^stale' "$READY_FILE" 2>/dev/null; then echo "ready (the session stalled)"; else echo "ready"; fi
  else
    echo "working: $(cut -f2- "$WORK/state" 2>/dev/null || echo "the session's step isn't known"); the GUI phase ends by $(epoch_hm "$(gui_end_epoch)")"
  fi
}

# arm_prompt: the status line, without the time (arm_wait shows it only when it changes). After the
# unplug it says that nothing is left to do: the first attempt's window kept asking for the unplug
# after it had seen it.
arm_prompt() {
  if [ -n "$ARM_HOLDERS" ]; then
    echo "Waiting: $ARM_HOLDERS keeps the Mac awake as if someone used it. Please quit it (its menu bar icon, Quit); the queue starts once it is gone."
  elif [ -n "$ARM_UNPLUG" ]; then
    case "$ARM_PHASE" in
      quiet) echo "On battery since $(epoch_hm "$ARM_UNPLUG"); 70 quiet seconds, then the cooldown. Nothing to do; don't press keys here." ;;
      cooldown) echo "On battery since $(epoch_hm "$ARM_UNPLUG"); cooling down until about $(epoch_hm "$ARM_COOL_END"); the queue then runs until about $(epoch_hm "$ARM_QUEUE_END"). Nothing to do; don't press keys here." ;;
      *) echo "On battery since $(epoch_hm "$ARM_UNPLUG"); the session is finishing ($(arm_state)); the cooldown and the queue follow. Nothing to do; don't press keys here." ;;
    esac
  elif [ -f "$READY_FILE" ] && [ -z "$ARM_SUDO" ]; then
    echo "Ready. At bedtime: press Return here and type your password; then $ARM_BEDTIME."
  elif [ -f "$READY_FILE" ]; then
    echo "The password is in. Now $ARM_BEDTIME."
  else
    echo "$(arm_state). At bedtime, if this still says working: $ARM_BEDTIME (no password)."
  fi
}

# arm_wait <seconds>: the status line when it changed, then a wait for his Return that echoes
# nothing, so a Return after the password shows nothing (the first attempt printed a line per
# press). Succeeds on a Return.
arm_wait() {
  local reply status
  status="$(arm_prompt)"
  if [ "$status" != "$ARM_SHOWN" ]; then
    printf '[%s] %s\n' "$(date '+%H:%M')" "$status"
    ARM_SHOWN="$status"
  fi
  read -r -s -t "$1" reply
}

# arm_keepawake: no other process holds a keep-awake assertion; else the queue doesn't start (every
# run would be "touched"): ARM_HOLDERS names it in the status line, and the window says so once per
# change. The names stay on the Mac (the arm window, arm.log, keepawake.local).
arm_keepawake() {
  local holders names
  holders="$(keepawake_holders)"
  if [ -z "$holders" ]; then
    if [ -n "$ARM_HOLDERS" ]; then arm_say "no keep-awake assertion of another process any more: the queue may start"; fi
    ARM_HOLDERS=""
    return 0
  fi
  names="$(keepawake_names "$holders")"
  if [ "$names" != "$ARM_HOLDERS" ]; then
    keepawake_record arm "$holders"
    arm_say "$names holds a keep-awake assertion ($(cut -f3 <<<"$holders" | sort -u | tr '\n' ' ' | sed 's/ $//')): the queue doesn't start while it runs. Please quit it."
  fi
  ARM_HOLDERS="$names"
  return 1
}

# arm_quiet: 70 quiet seconds after the unplug (HIDIdleTime, the touch detector's reading), so his
# brightness keys and the Focus are behind the cooldown; at most 10 minutes, then the cooldown
# starts anyway and the detector decides each run.
arm_quiet() {
  local waited=0 idle
  ARM_PHASE=quiet
  while [ "$waited" -lt 600 ]; do
    idle="$(idle_seconds)"
    if [ -z "$idle" ]; then
      arm_say "HIDIdleTime can't be read: the cooldown starts now"
      return 0
    fi
    if awk -v i="$idle" 'BEGIN { exit !(i + 0 >= 70) }'; then
      printf '%s\tquiet: HIDIdleTime %s s\n' "$(clock)" "$idle" >>"$LOGS/arm.log"
      return 0
    fi
    if arm_wait 5; then arm_return; fi
    waited=$((waited + 5))
  done
  arm_say "HIDIdleTime didn't reach 70 s in 10 minutes: the cooldown starts anyway; the touch detector decides each run"
}

# arm_waiters: the notification waiters, registered before the files they stand for are checked
# (a ready post, and the power source); each wakes the prompt with SIGUSR1.
arm_waiters() {
  if [ -z "$ARM_READY_WAITER" ] || ! kill -0 "$ARM_READY_WAITER" 2>/dev/null; then
    (notifyutil -1 "$READY_NOTIFY" >/dev/null 2>&1 && kill -USR1 "$ARM_PID" 2>/dev/null) &
    ARM_READY_WAITER=$!
    BACKGROUND="$BACKGROUND $ARM_READY_WAITER"
  fi
  if [ -z "$ARM_POWER_WAITER" ] || ! kill -0 "$ARM_POWER_WAITER" 2>/dev/null; then
    (notifyutil -1 com.apple.system.powersources.source >/dev/null 2>&1 && kill -USR1 "$ARM_PID" 2>/dev/null) &
    ARM_POWER_WAITER=$!
    BACKGROUND="$BACKGROUND $ARM_POWER_WAITER"
  fi
}

# arm_heartbeat_stale: 20 minutes without the session's heartbeat or the script's own.
arm_heartbeat_stale() {
  [ -f "$HEARTBEAT" ] || return 1
  [ "$(heartbeat_age)" -gt 1200 ]
}

# arm_queue_caffeinate: Session A's split, from his Return (or the queue's start): caffeinate -i
# for the whole queue, and a separate, killable caffeinate -d (S6 ends it).
arm_queue_caffeinate() {
  if [ -z "$ARM_QUEUE_CAFFEINATE" ]; then
    caffeinate -i -w "$ARM_PID" &
    ARM_QUEUE_CAFFEINATE=$!
    BACKGROUND="$BACKGROUND $ARM_QUEUE_CAFFEINATE"
  fi
  keep_display_awake
}

# arm_return: his Return at bedtime: the password once (sudo -v), a ticket bound to this terminal,
# and a keep-alive until the queue's end (B5 kills it), so Low Power Mode can still go back after
# the last run: capped at the unplug plus 3 hours 45 minutes (the last start plus S6 and B5), or 4
# hours from his Return while no unplug has come.
arm_return() {
  # After the password a Return does nothing visible.
  [ -z "$ARM_SUDO" ] || return 0
  if [ ! -f "$READY_FILE" ]; then
    if [ -z "$ARM_TOLD" ]; then
      arm_say "The session is still working ($(arm_state)): no password tonight, so the Low Power Mode run won't run. Now $ARM_BEDTIME."
      ARM_TOLD=1
    fi
    return 0
  fi
  arm_queue_caffeinate
  if ! seal_holds; then
    echo "none" >"$WORK/sudo.state"
    arm_say "The tools or the frozen scripts changed since prepare (seal.tsv): no password tonight, and the queue won't run. Now $ARM_BEDTIME."
    return 0
  fi
  echo "sudo asks for your password once (Low Power Mode for one run, and putting it back):"
  if sudo -v; then
    # sudo's tty tickets: from another terminal, the ticket must not work.
    if script -q /dev/null sudo -n true </dev/null >/dev/null 2>&1; then
      sudo -k
      echo "unbound" >"$WORK/sudo.state"
      arm_say "sudo's ticket isn't bound to this terminal, so it was dropped: the Low Power Mode run won't run. Now $ARM_BEDTIME."
      return 0
    fi
    ARM_SUDO=1
    echo "bound" >"$WORK/sudo.state"
    (
      started=$(date +%s)
      while kill -0 "$ARM_PID" 2>/dev/null && [ ! -f "$WORK/queue.done" ]; do
        end=$((started + 4 * 3600))
        if [ -f "$WORK/unplug.epoch" ]; then end=$(($(cat "$WORK/unplug.epoch") + 3 * 3600 + 45 * 60)); fi
        [ "$(date +%s)" -lt "$end" ] || break
        sudo -n -v >/dev/null 2>&1 || true
        sleep 60
      done
    ) &
    ARM_KEEPALIVE=$!
    BACKGROUND="$BACKGROUND $ARM_KEEPALIVE"
    arm_say "Thank you. Now $ARM_BEDTIME."
  else
    echo "none" >"$WORK/sudo.state"
    arm_say "No password: the Low Power Mode run won't run. Now $ARM_BEDTIME."
  fi
}

# arm_decide <ready|stale>: queue.started at once, before the stale path's restore and the
# cooldown, so a session that wakes up later can't act during a run.
arm_decide() {
  printf '%s %s %s %s\n' "$ARM_PID" "$ARM_START" "$(clock)" "$1" >"$FENCE"
  arm_say "the queue is decided ($1): $FENCE is up"
  if [ "$1" = stale ]; then
    [ -f "$READY_FILE" ] || printf 'stale %s\n' "$(clock)" >"$READY_FILE"
    arm_say "the session's heartbeat and the script's own are $(($(heartbeat_age) / 60)) minutes old: the queue starts without the session"
    (restore_gui_scriptable) >>"$LOGS/arm.log" 2>&1 || arm_say "restore gui's scriptable half stopped early"
    restore_gui_items >"$MORNING"
    arm_say "the computer-use items for the morning are in $MORNING"
  fi
}

# arm_cooldown <unplug epoch>: at least 10 minutes on battery, longer until the pack is within
# 2 °C of Session A's first run, at most 20 minutes, ending with HIDIdleTime of 60 s or more.
arm_cooldown() {
  local from="$1" target temp now claude0 claude1 at0 times
  # The Claude CLI's own CPU while the session sits idle at ready: the detector's baseline.
  claude0="$(q_claude)"
  at0="$(date +%s)"
  target="$(awk -F '\t' 'NR == 2 { print $6 }' "$HOME/bp-062/A/logs/sampler.tsv" 2>/dev/null || true)"
  case "$target" in "" | *[!0-9]*) target="" ;; esac
  arm_say "cooldown: at least 10 minutes from $(epoch_hm "$from")$(if [ -n "$target" ]; then echo ", until the pack is within 2 °C of Session A's first run ($((target / 100)) °C)"; fi), at most 20"
  ARM_PHASE=cooldown
  ARM_COOL_END=$((from + 600))
  times="$(queue_expected "$ARM_COOL_END")"
  ARM_QUEUE_END="${times##* }"
  while :; do
    now="$(date +%s)"
    [ "$now" -lt $((from + 1200)) ] || break
    temp="$(q_pack_temp)"
    if [ "$now" -ge $((from + 600)) ]; then
      # Only a warmer pack waits: a colder one starts at 10 minutes.
      if [ -z "$target" ] || awk -v t="$temp" -v g="$target" 'BEGIN { exit !(t != "-" && t - g <= 200) }'; then
        if awk -v i="$(idle_seconds)" 'BEGIN { exit !(i + 0 >= 60) }'; then break; fi
      fi
    fi
    if arm_wait 30; then arm_return; fi
  done
  claude1="$(q_claude)"
  Q_CLAUDE_RATE="$(awk -v x="${claude0##* }" -v y="${claude1##* }" -v d=$(($(date +%s) - at0)) 'BEGIN { r = (d > 0 && y > x) ? (y - x) / d : 0; printf "%.5f", r }')"
  echo "$Q_CLAUDE_RATE" >"$WORK/claude-rate"
  arm_say "cooldown done: the pack at $(q_pack_temp) (hundredths of °C), HIDIdleTime $(idle_seconds) s; the Claude CLI's background CPU $Q_CLAUDE_RATE s a second"
}

# arm_after_queue (B5): Low Power Mode back, the sampler and the pslog stopped, restore night,
# queue.started removed, the overnight log stream, sudo -k, caffeinate released. It draws nothing.
arm_after_queue() {
  # Right after the last run, while the keep-alive still holds the ticket; restore night marks it
  # restored only once a read confirms it.
  restore_lowpowermode >>"$LOGS/arm.log" 2>&1 || arm_say "Low Power Mode isn't as prepare found it: the morning report says so"
  stop_pslog
  (pslog_analysis) >/dev/null 2>&1 || true
  (restore_night) >>"$LOGS/arm.log" 2>&1 || arm_say "restore night stopped early"
  rm -f "$FENCE"
  # Whether a stream survives the night's sleep (0.7's Session R step 12): its own process.
  nohup /usr/bin/log stream --level debug --style ndjson --predicate "$PERF_PREDICATE" \
    >"$LOGS/night-stream.ndjson" 2>"$LOGS/night-stream.err" </dev/null &
  echo $! >"$WORK/night-stream.pid"
  clock >"$WORK/queue.done"
  if [ -n "$ARM_KEEPALIVE" ]; then kill "$ARM_KEEPALIVE" 2>/dev/null || true; fi
  sudo -k 2>/dev/null || true
  let_display_sleep
  if [ -n "$ARM_QUEUE_CAFFEINATE" ]; then kill "$ARM_QUEUE_CAFFEINATE" 2>/dev/null || true; fi
  arm_say "the queue is done; the Mac may sleep now. Results in the morning."
}

# arm_no_unplug: no bedtime unplug by 3 hours after his bedtime: every run "not run: no unplug",
# the fence down, and the arm ends (B5's restore has nothing to put back: no run changed anything).
arm_no_unplug() {
  arm_not_run "no bedtime unplug by $(epoch_hm $(($(bedtime_epoch) + 3 * 3600))) (3 hours after his bedtime), so a morning unplug never starts it"
}

# arm_not_run <why>: the queue isn't run tonight: its section says why, the fence comes down for
# his continue, and the arm ends.
arm_not_run() {
  arm_say "the queue is not run tonight: $1"
  begin_section 88-queue "The energy queue (B4; WP-21)"
  out "- not run: $1"
  echo "not run: $1 ($(clock))" >"$WORK/queue.done"
  rm -f "$FENCE"
  if [ -n "$ARM_KEEPALIVE" ]; then kill "$ARM_KEEPALIVE" 2>/dev/null || true; fi
  sudo -k 2>/dev/null || true
  let_display_sleep
  if [ -n "$ARM_QUEUE_CAFFEINATE" ]; then kill "$ARM_QUEUE_CAFFEINATE" 2>/dev/null || true; fi
}

arm_exit() {
  if [ -f "$FENCE" ] && [ "$(cut -d' ' -f1 "$FENCE" 2>/dev/null)" = "$ARM_PID" ] && [ ! -f "$WORK/queue.done" ]; then
    # Stopped mid-queue: Low Power Mode back, and the fence down, so the morning can go on.
    restore_lowpowermode >>"$LOGS/arm.log" 2>&1 || true
    rm -f "$FENCE"
    printf '%s\tstopped early\n' "$(clock)" >>"$LOGS/arm.log"
  fi
  stop_pslog
  rm -f "$WORK/arm.pid"
  cleanup
}

# arm: the arm window itself (B0b to B5): a status line (no password prompt waits, so nothing can
# type into one), the session's state, his Return at bedtime, then the queue on ready, or on a
# heartbeat more than 20 minutes old (the session's and the script's own), on battery, while no
# other process holds a keep-awake assertion, after 70 quiet seconds and the cooldown.
step_arm() {
  b_only arm
  if [ "${1:-}" = open ]; then
    arm_open
    return 0
  fi
  [ -t 0 ] || fail "arm runs in its own Terminal window: $SCRIPT arm open"
  local running="" running_start=""
  read -r running running_start <<<"$(arm_of "$WORK/arm.pid")" || true
  if arm_runs "$running" "$running_start"; then fail "an arm window runs already"; fi
  [ ! -f "$WORK/queue.done" ] || fail "the queue ran already ($(cat "$WORK/queue.done"))"
  mkdir -p "$LOGS"
  ARM_PID=$$
  ARM_START="$(proc_start "$ARM_PID")"
  # Without its start time, ui and the fences wouldn't know the arm window for theirs.
  [ -n "$ARM_START" ] || fail "this window's start time can't be read (ps -o lstart): the arm doesn't start"
  echo "$ARM_PID $ARM_START" >"$WORK/arm.pid"
  printf '\033]0;BatteryPulse arm\007'
  trap arm_exit EXIT
  # A waiter's SIGUSR1 ends the prompt's wait early; the 60-second timeout is the backstop.
  trap ':' USR1
  cd "$ROOT"
  local cap decided="" unplugged=0
  cap=$(($(gui_end_epoch) + 600 - $(date +%s)))
  if [ "$cap" -lt 600 ]; then cap=600; fi
  caffeinate -d -i -t "$cap" &
  ARM_GUI_CAFFEINATE=$!
  BACKGROUND="$BACKGROUND $ARM_GUI_CAFFEINATE"
  arm_say "BatteryPulse Session B's arm window. It keeps the display awake for the GUI phase (until $(epoch_hm $(($(date +%s) + cap)))) and asks for nothing now."
  while :; do
    arm_waiters
    if [ -z "$decided" ]; then
      if [ -f "$READY_FILE" ]; then
        decided=ready
      elif [ -f "$WORK/away" ] && arm_heartbeat_stale; then
        # Only in the GUI phase: before `mark away` he is at the Mac, and a pause is his.
        decided=stale
      fi
      if [ -n "$decided" ]; then arm_decide "$decided"; fi
    fi
    if on_battery && [ -f "$WORK/away" ] && [ "$unplugged" = 0 ]; then
      unplugged="$(date +%s)"
      ARM_UNPLUG="$unplugged"
      echo "$unplugged" >"$WORK/unplug.epoch"
      arm_say "the bedtime unplug at $(epoch_hm "$unplugged"): no run starts after $(epoch_hm $((unplugged + 3 * 3600)))"
    fi
    # The queue starts on battery once decided, and only while no other process holds a
    # keep-awake assertion.
    if [ -n "$decided" ] && on_battery && arm_keepawake; then break; fi
    if [ -n "$ARM_HOLDERS" ] && [ "$unplugged" != 0 ] && [ "$(date +%s)" -ge $((unplugged + 3 * 3600)) ]; then
      arm_not_run "another process held a keep-awake assertion until 3 hours after the unplug (its name stays on the Mac)"
      return 0
    fi
    # No unplug 3 hours after his bedtime: the queue isn't run, so a morning unplug never starts
    # it while he uses the Mac, and the fence comes down for his continue.
    if [ -n "$decided" ] && [ "$unplugged" = 0 ] && [ "$(date +%s)" -ge $(($(bedtime_epoch) + 3 * 3600)) ]; then
      arm_no_unplug
      return 0
    fi
    if arm_wait 60; then arm_return; fi
  done
  if [ "$unplugged" = 0 ]; then unplugged="$(date +%s)"; fi
  ARM_UNPLUG="$unplugged"
  # No more wake-ups from the waiters: a signal would end a run's wait early.
  trap '' USR1
  kill "$ARM_READY_WAITER" "$ARM_POWER_WAITER" 2>/dev/null || true
  pkill -f "notifyutil -1 $READY_NOTIFY" 2>/dev/null || true
  pkill -f 'notifyutil -1 com.apple.system.powersources.source' 2>/dev/null || true
  kill "$ARM_GUI_CAFFEINATE" 2>/dev/null || true
  arm_queue_caffeinate
  arm_quiet
  arm_cooldown "$(date +%s)"
  # One that came during the cooldown: the queue waits for it to go, until 3 hours after the unplug.
  until arm_keepawake; do
    if [ "$(date +%s)" -ge $((unplugged + 3 * 3600)) ]; then
      arm_not_run "another process held a keep-awake assertion from the cooldown's end until 3 hours after the unplug (its name stays on the Mac)"
      return 0
    fi
    if arm_wait 30; then arm_return; fi
  done
  # The queue runs with sudo's ticket: only the tools and scripts prepare sealed.
  if ! seal_holds; then
    arm_not_run "the tools or the frozen scripts changed since prepare (seal.tsv)"
    return 0
  fi
  queue_run "$unplugged"
  arm_after_queue
}

# ready (B3's last call): the minimize button's offset for the queue's minimized run (AX now, on a
# process the queue replaces), the ready file and its post. The session ends its turn after it.
step_ready() {
  b_only ready
  b_fence
  local window button
  [ -f "$WORK/gui.done" ] || warn "restore gui hasn't run"
  relaunch_b
  open_main
  window="$(ui_run frame BatteryPulse 2>/dev/null || true)"
  button="$(ui_run frame BatteryPulse --minimize-button 2>/dev/null || true)"
  if [ -n "$window" ] && [ -n "$button" ]; then
    awk -v w="$window" -v b="$button" 'BEGIN { split(w, a, " "); split(b, c, " "); printf "%d %d\n", c[1] + c[3] / 2 - a[1], c[2] + c[4] / 2 - a[2] }' \
      >"$WORK/minimize-offset"
  else
    not_checked MIN "the minimize button's offset wasn't read: the minimized run is not run"
  fi
  quit_app
  printf 'ready %s\n' "$(clock)" >"$READY_FILE"
  notifyutil -p "$READY_NOTIFY" >/dev/null 2>&1 || true
  echo "READY: end the turn now. A message that reaches the session after this gets a text-only answer (results in the morning), with no tool call."
}

# back_since <epoch>: pmset -g log shows the lid after that time: a wake because it opened, or a
# sleep because it closed (the morning's lid close, V-01's lid step). Software can't move the lid,
# but it can turn the display on and make user activity (a posted move, caffeinate -u: proof P6),
# so neither "Display is turned on" nor a UserActivity wake counts. Apple Silicon logs the lid's
# wake as "due to smc.70070000 lid ..." (lowercase), and a lid closed on a Mac already asleep logs
# no Clamshell Sleep, so the open alone must count; a "Wake Requests" line (scheduled wakes) never.
back_since() {
  pmset -g log 2>/dev/null | awk -v from="$(epoch_stamp "$1")" '
    substr($0, 1, 19) > from && (($4 == "Wake" && $5 != "Requests" && (/LidOpen|Lid Open/ || / lid([ \/]|$)/)) || ($4 == "Sleep" && /Clamshell Sleep/)) { found = 1 }
    END { exit !found }'
}

# proof_detail <id>: what a proof recorded (proofs.tsv's third field).
proof_detail() { awk -F '\t' -v id="$1" '$1 == id { detail = $3 } END { print detail }' "$PROOFS" 2>/dev/null || true; }

# continue (B7): his morning word, which opens the fence. Only after the night: the queue's end
# (queue.done), or an arm window that is gone with ready up (it stopped early). Only with him at
# the Mac, by what software can't make: the screen unlocked at the console with the lid open (his
# login), the input idle at most 15 minutes (HIDIdleTime, or the HID event state where proof P6
# found it blind to posted events), and pmset -g log showing the lid closed or opened after the
# queue's last sign of life. So a session that wakes up at night, or a continue during B0-B2,
# can't open the fence itself; ui and every command take a continue only when it is newer than
# ready.
step_continue() {
  b_only continue
  local pid start alive="" idle since file at state source
  if [ ! -f "$READY_FILE" ]; then
    echo "continue isn't needed: ready isn't up, so nothing is fenced"
    return 0
  fi
  if continued_after "$WORK" ready; then
    echo "continued already at $(cat "$WORK/continued")"
    return 0
  fi
  for file in "$WORK/arm.pid" "$FENCE"; do
    pid=""
    start=""
    read -r pid start <<<"$(arm_of "$file")" || true
    if arm_runs "$pid" "$start"; then alive="$pid"; fi
  done
  if [ -n "$alive" ]; then
    if [ ! -f "$WORK/unplug.epoch" ]; then
      fail "the arm window still waits for the bedtime unplug, with the fence up: continue comes after the queue (it gives up 3 hours after his bedtime)"
    elif [ ! -f "$WORK/queue.done" ]; then
      fail "the queue still runs (its log: $LOGS/arm.log); tell him it ends at about $(cat "$WORK/queue.expected" 2>/dev/null || echo "the time the arm window gave")"
    fi
    fail "the arm window is finishing the queue's end: continue again in a minute"
  fi
  # Software can't unlock the screen: his password or Touch ID did.
  state="$(ui_run locked 2>/dev/null || true)"
  if [ "$state" != "locked=no lid=open console=yes" ]; then
    fail "the screen isn't unlocked at the console with the lid open (${state:-ui locked unread}): continue comes after he has logged in; nothing was opened"
  fi
  # A posted move or caffeinate -u resets HIDIdleTime (proof P6); the HID event state, where P6
  # found that it ignores posted events, only counts his hands.
  if proof_detail P6 | grep -q -F 'ignores posted events: yes'; then
    idle="$(state_seconds)"
    source="the HID event state"
  else
    idle="$(idle_seconds)"
    source="HIDIdleTime"
  fi
  case "$idle" in
    "" | *[!0-9.]*) fail "$source can't be read, and continue needs it (at most 900 s): nothing was opened" ;;
  esac
  if ! awk -v i="$idle" 'BEGIN { exit !(i + 0 <= 900) }'; then
    fail "$source says $idle s since the last input: continue comes after he is at the Mac (the lid close and his login)"
  fi
  # The queue's last sign of life: its end, its fence, its log or ready, whichever is newest.
  since=0
  for file in "$WORK/queue.done" "$FENCE" "$LOGS/arm.log" "$READY_FILE"; do
    [ -f "$file" ] || continue
    at="$(mtime_of "$file")"
    if [ "$at" -gt "$since" ]; then since="$at"; fi
  done
  if ! back_since "$since"; then
    fail "pmset -g log shows no lid close or open since $(epoch_stamp "$since"): he closes the lid for a minute, opens it and logs in, then continue"
  fi
  if [ -f "$FENCE" ]; then
    rm -f "$FENCE"
    note_line "the arm window had stopped and left queue.started: removed at continue"
  fi
  clock >"$WORK/continued"
  echo "continued at $(clock): the morning (B7) may begin: $SCRIPT morning"
}

note_line() { printf '%s\t%s\n' "$(date '+%H:%M')" "$*" >>"$NOTES"; }

# morning (B7): the night's sleep hygiene (no DarkWake or wake from BatteryPulse in pmset -g log),
# and whether the overnight log stream kept its lines across the sleep.
step_morning() {
  b_only morning
  b_fence
  begin_section 96-night "The night (B6): sleep hygiene and the overnight log stream"
  local since pid lines gaps
  since="$(cat "$WORK/queue.done" 2>/dev/null || cat "$WORK/prepare.time")"
  pmset -g log 2>/dev/null | awk -v from="$since" 'substr($0, 1, 19) >= from' >"$LOGS/night-pmset.txt" || true
  out "- since $since: DarkWake or Wake from lines naming BatteryPulse: $(grep -i -E 'DarkWake|Wake from' "$LOGS/night-pmset.txt" | grep -c -i batterypulse || true) (must be 0); sleeps $(awk '$4 == "Sleep" && $5 != "Service"' "$LOGS/night-pmset.txt" | grep -c . || true), wakes $(awk '($4 == "Wake" && $5 != "Requests") || $4 == "DarkWake"' "$LOGS/night-pmset.txt" | grep -c . || true)"
  pid="$(cat "$WORK/night-stream.pid" 2>/dev/null || true)"
  if [ -n "$pid" ]; then
    out "- the overnight log stream: $(if kill -0 "$pid" 2>/dev/null; then echo "still running"; else echo "ended"; fi)"
    kill -INT "$pid" 2>/dev/null || true
    sleep 2
    lines="$(grep -c '"eventMessage"' "$LOGS/night-stream.ndjson" 2>/dev/null || true)"
    gaps="$(sed -n 's/.*"timestamp" *: *"\([0-9-]* [0-9:]*\).*/\1/p' "$LOGS/night-stream.ndjson" | awk '
      { cmd = "date -j -f \"%Y-%m-%d %H:%M:%S\" \"" $0 "\" +%s"; cmd | getline t; close(cmd)
        if (last != "" && t - last > 600) { n++; if (t - last > longest) longest = t - last }; last = t }
      END { printf "%d gaps over 10 minutes, the longest %d minutes", n, longest / 60 }')"
    out "- its lines: ${lines:-0}; $gaps (lines after the wake mean the stream survived the sleep)"
  else
    out "- the overnight log stream: not started"
  fi
  # S4w's style in effect, the shot half (WP-21's detectors): each run's window-ID shot, taken
  # before its quiet minute, for the session to read now.
  local shot
  for shot in "$SHOTS"/queue/*-S4w-*.png; do
    [ -f "$shot" ] || continue
    echo "LOOK $shot: the style its name says? If not, note \"run <#>: style not in effect (not valid)\" ($SCRIPT note ...)"
  done
}

# MARK: - Session B: restore gui, night and morning (step 10)

# When each changed setting comes back, and how: "script" ones by the script, the rest by the
# session (AX, System Events or computer use), confirmed with `restored <setting>`.
restore_phase() {
  case "$1" in
    appearance | appearance-auto | wallpaper | widget-style | dim-widgets | text-size | increase-contrast | reduce-transparency | reduce-motion | cross-fade | show-borders | glass-slider | widget-languages) echo gui ;;
    *) echo morning ;;
  esac
}

restore_how() {
  case "$1" in
    wallpaper)
      if wallpaper_is_still; then echo script; else echo "computer use from shots/prepare-desktop.png (a dynamic or aerial wallpaper: System Events would set a still)"; fi
      ;;
    appearance-auto) echo "computer use (System Settings → Appearance → Auto)" ;;
    appearance | widget-languages | app | bp-settings | bp-support | widget-data | remembered-devices | lowpowermode-battery) echo script ;;
    open-at-login) echo "AX (Settings → General → Open at login)" ;;
    charge-limit) echo "computer use (System Settings → Battery), confirmed by pmset -g battlimit" ;;
    widgets) echo "computer use (the widgets he didn't keep)" ;;
    *) echo "computer use, confirmed by a read or a shot" ;;
  esac
}

# restore_gui_scriptable: the scriptable half of restore gui (the hand-over, and arm's stale path):
# the appearance and the wallpaper, BatteryPulse's session settings for the queue, and TextEdit,
# System Settings, Accessibility Inspector and Xcode closed by AX presses (not Apple Events:
# TextEdit would be a new Automation target).
restore_gui_scriptable() {
  local original app
  # A still wallpaper by System Events, confirmed by a read; a dynamic or aerial one stays on the
  # session's list (computer use from prepare's shot).
  if [ -n "$(original_of wallpaper)" ] && wallpaper_is_still; then
    put_wallpapers_back || true
    if wallpaper_as_backup; then mark_restored wallpaper "script, read back"; fi
  fi
  original="$(original_of appearance)"
  case "$original" in
    true) if [ "$(is_dark)" != true ]; then appearance dark || true; fi ;;
    false) if [ "$(is_dark)" != false ]; then appearance light || true; fi ;;
  esac
  if [ -n "$original" ] && [ "$(is_dark)" = "$original" ]; then mark_restored appearance "script, read back"; fi
  if [ -n "$(original_of widget-languages)" ] && ! is_restored widget-languages; then
    if put_widget_languages_back; then mark_restored widget-languages "script, read back"; fi
  fi
  quit_app
  session_settings
  # Only what the script opened; one he had open, or computer use opened, stays, named for the
  # session (it quits one it opened itself with ui quit).
  if [ -n "$(app_pid_of TextEdit)" ] && ! launched_by_script TextEdit; then close_cover || true; fi
  for app in TextEdit "System Settings" "Accessibility Inspector" Xcode; do
    quit_if_launched "$app"
    if [ -n "$(app_pid_of "$app")" ]; then
      echo "LEFT OPEN $app: the script didn't open it (his own, or opened by computer use: quit it only if the session opened it)"
    fi
  done
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

# restore_night (B5, from arm): Low Power Mode as prepare found it, the RC running with the session's
# settings for the sleep-hygiene night.
restore_night() {
  if restore_lowpowermode; then
    [ -z "$(original_of lowpowermode-battery)" ] || mark_restored lowpowermode-battery "script (night), read back"
  fi
  install_build C --no-launch
  quit_app
  session_settings
  launch
  # The sleep-hygiene night's RC process: its executor lines count in the morning.
  note_rc_pid
}

# restore_morning (B7): his app, the defaults domain, Application Support, the widget's data and
# preferences, Low Power Mode, then the list for the session (Open at login as prepare found it,
# brightness, auto-brightness, True Tone, the widgets, the Charge Limit), each confirmed.
restore_morning() {
  local limit now
  stop_leftovers
  restore_all
  use_section 95-restore "Restore"
  mark_restored app "script"
  mark_restored bp-settings "script"
  mark_restored bp-support "script"
  mark_restored widget-data "script"
  if [ -n "$(original_of remembered-devices)" ] && [ -d "$SUPPORT/Devices" ]; then
    mark_restored remembered-devices "script (from the backup), read back"
  fi
  # Restored only as pmset reads it now (the morning has no sudo ticket: restore_all prints the
  # PUT BACK line otherwise, and B.md heads its list with it).
  if [ -n "$(original_of lowpowermode-battery)" ] && lowpowermode_as_backup; then
    mark_restored lowpowermode-battery "pmset -g custom"
  fi
  if [ -n "$(original_of appearance)" ] && [ "$(is_dark)" = "$(original_of appearance)" ]; then
    mark_restored appearance "script, read back"
  fi
  if [ -n "$(original_of wallpaper)" ] && wallpaper_is_still && wallpaper_as_backup; then
    mark_restored wallpaper "script, read back"
  fi
  limit="$(answer_of prep-charge-limit)"
  now="$(pmset -g battlimit 2>/dev/null | grep -o -E '[0-9]+ ?%' | head -1 | tr -d ' %' || true)"
  out "- the Charge Limit: prepare found ${limit:-unknown}; pmset -g battlimit now: ${now:-shows none (a Battery pane shot confirms it)}"
  if [ -n "$(original_of charge-limit)" ] && [ -n "$now" ] && [ "$now" = "$limit" ]; then mark_restored charge-limit "pmset -g battlimit"; fi
  # The night is over: the frozen worktree and the tools writable again, so he can remove them.
  unseal_tools
  restore_gui_items morning
  restore_gui_items gui
}

# restore gui | night | morning (Session B); restore alone is Session A's.
step_restore_b() {
  case "${1:-}" in
    gui)
      b_fence
      begin_section 95-restore-gui "Restore: the hand-over (B3)"
      restore_gui_scriptable
      restore_gui_items gui | tee "$MORNING.gui"
      out "- $(clock): the appearance, the wallpaper, the session's settings; the TextEdit, System Settings, Accessibility Inspector and Xcode the script opened closed; $(grep -c . "$MORNING.gui" || true) items for the session"
      touch "$WORK/gui.done"
      echo "Then stop every background task, and last: $SCRIPT ready (the energy setup is his, at the arm window's bedtime prompt)"
      ;;
    night)
      caller_is_arm || fail "restore night runs in the arm window at the queue's end"
      restore_night
      ;;
    morning)
      b_fence
      restore_morning
      restore_prompts_b
      ;;
    *) fail "usage: $SCRIPT restore gui | night | morning" ;;
  esac
}

# What only his hand puts back (Session B): the Focus off, and Terminal's Accessibility unless he
# keeps it for Session R.
restore_prompts_b() {
  echo
  echo "PUT BACK (person):"
  echo "- Turn the Focus off (Control Center), and set the brightness as you like it."
  if [ "$(answer_of B-keep-ax)" != y ]; then
    echo "- Turn Terminal off in System Settings → Privacy & Security → Accessibility (10 s)."
  fi
  if [ -n "$(original_of lowpowermode-battery)" ] && ! is_restored lowpowermode-battery; then
    echo "- Low Power Mode, in Terminal: sudo pmset -b lowpowermode $(cat "$BACKUP/lowpowermode-battery"); sudo pmset -c lowpowermode $(cat "$BACKUP/lowpowermode-ac")"
  fi
  if [ -n "$(original_of appearance-auto)" ] && ! is_restored appearance-auto; then
    echo "- Set System Settings → Appearance back to Auto."
  fi
  if [ -n "$(original_of wallpaper)" ] && ! is_restored wallpaper; then
    echo "- Put your wallpaper back (System Settings → Wallpaper), as it was before the session."
  fi
  echo "The backup stays in $BACKUP."
}

# MARK: - Session B: status, the report and send (step 9)

step_status_b() {
  local id value
  echo "folder: $WORK (Session B)"
  if [ "$(uname -s)" = Darwin ]; then
    echo "installed: $(app_version); running: $(if app_running; then echo yes; else echo no; fi)"
    echo "battery: $(battery_percent) %, $(if on_battery; then echo on battery; else echo on the adapter; fi)"
  fi
  echo "flags: $(for id in away ready queue.started queue.done continued gui.done; do if [ -f "$WORK/$id" ]; then printf '%s ' "$id"; fi; done)"
  if [ -f "$HEARTBEAT" ]; then
    echo "heartbeat: the session's $((($(date +%s) - $(mtime_of "$HEARTBEAT")) / 60)) minutes ago, the newer with the script's own $(($(heartbeat_age) / 60)) (stale after 20); GUI phase: $(gui_minutes_left) minutes left"
  fi
  echo "changes: $(changed_settings | grep -c . || true) settings; not put back yet: $(for id in $(changed_settings); do is_restored "$id" || printf '%s ' "$id"; done)"
  echo "proofs: $(awk -F '\t' '{ printf "%s=%s ", $1, $2 }' "$PROOFS" 2>/dev/null)"
  echo "not checked: $(grep -c . "$WORK/not-checked.tsv" 2>/dev/null || echo 0); morning batch: $(grep -c . "$BATCH" 2>/dev/null || echo 0)"
  echo "queue rows: $(($(grep -c . "$LOGS/queue-runs.tsv" 2>/dev/null || echo 1) - 1))"
  echo "answers:"
  for id in $(questions_b); do
    value="$(answer_of "$id")"
    [ -z "$value" ] || printf '  %-34s %s\n' "$id" "$value"
  done
  echo "sections: $(find "$SECTIONS" -name '*.md' 2>/dev/null | sed 's|.*/||; s|\.md$||' | sort | tr '\n' ' ')"
  echo "attached images: $(grep -c . "$PUBLISH/captions.tsv" 2>/dev/null || echo 0)"
}

# The Appendix C rows Session B owns (PLAN.md), with where B.md answers them.
appendix_rows_b() {
  cat <<'EOF'
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
EOF
}

# timeline_b: when each phase began and ended, from the session's own files (the hands-free
# mode's cost, Appendix C).
timeline_b() {
  echo "## Timeline"
  echo
  echo "- prepare (B0a): $(cat "$WORK/prepare.time" 2>/dev/null || echo "-")"
  echo "- mark away (the GUI phase begins): $(cat "$WORK/away" 2>/dev/null || echo "-")"
  echo "- restore gui (B3): $(if [ -f "$WORK/gui.done" ]; then epoch_stamp "$(mtime_of "$WORK/gui.done")"; else echo "-"; fi)"
  echo "- ready: $(cat "$READY_FILE" 2>/dev/null || echo "-")"
  echo "- the queue's end: $(cat "$WORK/queue.done" 2>/dev/null || echo "-")"
  echo "- continue (B7): $(cat "$WORK/continued" 2>/dev/null || echo "-")"
  echo
}

build_report_b() {
  local id value by at note file caption setting
  echo "# Session B results (BatteryPulse 0.6.2)"
  echo
  echo "Written by \`docs/plans/0.6.2/m5-session.sh send\` on $(date '+%Y-%m-%d %H:%M %z'). Session B ran hands-free"
  echo "(PLAN.md §6): answers marked \"claude\" were judged by the Claude session from the pictures, beside the"
  echo "script's pixel measurement where one exists; \"person\" ones came from the maintainer. Recordings,"
  echo "full-desktop shots and logs stay on the Mac (\`~/bp-062/B\`)."
  echo
  local unrestored=""
  for setting in $(changed_settings); do is_restored "$setting" || unrestored="$unrestored $setting"; done
  for setting in night-stream charge-capture; do
    if leftover_running "$setting"; then unrestored="$unrestored $setting (still running)"; fi
  done
  if [ -n "$unrestored" ]; then
    echo "**Not put back (for his hand):**$unrestored"
    echo
  fi
  echo "## Appendix C rows this session owns"
  echo
  appendix_rows_b
  echo
  timeline_b
  echo "## Answers"
  echo
  echo "| ID | Question | Answer | By | Time | Note |"
  echo "|---|---|---|---|---|---|"
  for id in $(questions_b); do
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
      echo "![$caption](B/$file)"
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

# privacy_terms: what B.md must not name (WP-21): the ComputerName and LocalHostName, his full
# name, an accessory's name (pmset -g accps, system_profiler's Bluetooth list), an iPhone's or
# iPad's name from BatteryPulse's device store (now, in the backup, and what `devices forget`
# removed), a VPN's name, the network's name, and every keep-awake holder's process name.
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
    # A caffeinate holder is a tool's name, which B.md may use.
    cut -f4 "$KEEPAWAKE_LOCAL" 2>/dev/null | grep -v -x caffeinate || true
  } | awk 'length($0) >= 3' | grep -v -i -x -E "$GENERIC_NAMES" | sort -u || true
}

# Names that are a product's, not his (a device or an accessory left with its plain name), and
# B.md's own words: never terms.
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
    echo "note: the network's name couldn't be read (macOS redacts it), so B.md wasn't checked for it"
  fi
  if [ -n "$found" ]; then
    fail "B.md names the Mac, him, an accessory, a VPN or the network on line(s)$found: drop them (note, answer or section), then send again"
  fi
}

# MARK: - Session B: the optional extras and WP-18's Xcode items

# charge-limit check | record start | record stop: the morning-away block's Charge Limit capture
# (Stage 1.1, QUA-05) with bpulse --record while the Mac charges to his limit; check confirms the
# limit is back (pmset -g battlimit, else a Battery pane shot), and says so with a sound and an
# alert when it isn't (the morning, after his continue).
step_charge_limit() {
  b_only charge-limit
  local now want
  case "${1:-}:${2:-}" in
    check:)
      want="$(answer_of prep-charge-limit)"
      now="$(pmset -g battlimit 2>/dev/null | grep -o -E '[0-9]+ ?%' | head -1 | tr -d ' %' || true)"
      if [ -z "$now" ]; then
        open_pane battery
        sleep 2
        shot charge-limit-check
        echo "pmset -g battlimit shows none: read the Battery pane's shot (it should say ${want:-the prepare value})"
      elif [ "$now" = "$want" ]; then
        echo "the Charge Limit is back at $now %"
      else
        echo "THE CHARGE LIMIT IS $now %, NOT $want %: put it back (computer use, System Settings → Battery)"
        if ! is_away; then
          sound Sosumi
          osascript -e 'display alert "BatteryPulse Session B" message "The Charge Limit is not back yet." giving up after 600' >/dev/null 2>&1 &
        fi
        note_line "the Charge Limit read $now %, not $want %, at a check"
        return 1
      fi
      ;;
    record:start)
      [ -x "$BIN/bpulse" ] || fail "bpulse isn't built: the capture is not run"
      mkdir -p "$WORK/charge-capture"
      nohup "$BIN/bpulse" --record "$WORK/charge-capture" >"$LOGS/charge-capture.txt" 2>&1 </dev/null &
      echo $! >"$WORK/charge-capture.pid"
      echo "bpulse --record runs (captures stay in $WORK/charge-capture, local)"
      ;;
    record:stop)
      kill "$(cat "$WORK/charge-capture.pid" 2>/dev/null || echo 0)" 2>/dev/null || true
      rm -f "$WORK/charge-capture.pid"
      echo "stopped; $(find "$WORK/charge-capture" -type f 2>/dev/null | wc -l | tr -d ' ') captures (a fixture only on his yes at send)"
      ;;
    *) fail "usage: $SCRIPT charge-limit check | record start | record stop" ;;
  esac
}

# menu-bar-shots <tag> [arguments]: scripts/menu-bar-shots.sh into shots/menubar (Stage 1.3, with
# Increase Contrast or Reduce Transparency set by computer use first, each through change).
step_menu_bar_shots() {
  b_only menu-bar-shots
  [ $# -ge 1 ] || fail "usage: $SCRIPT menu-bar-shots <tag> [--charge] [--looks <list>]"
  mkdir -p "$SHOTS/menubar"
  bash "$ROOT/scripts/menu-bar-shots.sh" "$SHOTS/menubar" "$@"
}

# wp18 previews | timing | icon <source.icon>: WP-18's items, through the script's one prefix:
# the package in Xcode for SUI-17's canvas, SUI-19's type-check timing (local only, never
# committed), and SZ-10's icon compiled by actool for the four icon styles' shots.
step_wp18() {
  b_only wp18
  local build="$WORK/wp18-build"
  case "${1:-}" in
    previews)
      (cd "$ROOT" && track_launch Xcode xed .) || fail "xed couldn't open the package"
      echo "Xcode opens the package: resume the canvas by computer use, then: $SCRIPT judge SUI-17 <y|n> [note]"
      ;;
    timing)
      begin_section 85-wp18 "WP-18: SUI-19's type-check timing"
      (cd "$ROOT" && xcrun swift build -c debug --scratch-path "$build" -j 2 -Xswiftc -debug-time-function-bodies) \
        >"$LOGS/sui19.txt" 2>&1 || out "- the build failed (see logs/sui19.txt on the Mac)"
      grep -E '^[0-9]+\.[0-9]+ms' "$LOGS/sui19.txt" | sort -n -r | head -5 >"$LOGS/sui19-top.txt" || true
      out "- the 5 slowest bodies (ms, file:line, the declaration):"
      out_block "$LOGS/sui19-top.txt"
      ;;
    icon)
      [ -f "${2:-}" ] || [ -d "${2:-}" ] || fail "usage: $SCRIPT wp18 icon <the .icon source>"
      mkdir -p "$WORK/wp18-icon"
      xcrun actool "$2" --compile "$WORK/wp18-icon" --platform macosx --minimum-deployment-target 27.0 \
        --app-icon "$(basename "${2%.icon}")" --output-partial-info-plist "$WORK/wp18-icon/partial.plist" \
        >"$LOGS/actool.txt" 2>&1 || fail "actool failed (see $LOGS/actool.txt)"
      echo "compiled into $WORK/wp18-icon: switch the four Icon & widget styles by computer use (change widget-style first) and shoot each"
      ;;
    *) fail "usage: $SCRIPT wp18 previews | timing | icon <source.icon>" ;;
  esac
}

# MARK: - Session B: the queue's dry run (CI on Linux; WP-21's proposal)

# queue --dry-run [default|low|late]: the queue's order, its retries and its thresholds on any
# machine, with the world stubbed: no app, no pmset, ioreg or notifyutil, a clock that jumps, a
# charge that drains 1 % every 10 minutes, the night's own times (the unplug 20 minutes before the
# start, the arm's longest cooldown; 6-minute runs, 1 of them the install; S7 3 minutes), and
# scripted detector events (default: a touched S2, an adapter S1, an LPM S2-LPM, a Claude-active
# S4w and a slept S4w; low: from 62 %; late: the bedtime unplug 2 hours before the start). Exit
# status 1 on a broken rule.
queue_dry_run() {
  local scenario="${1:-default}" unplug problems
  DRY_RUN=1
  DRY_T0=1761300000
  DRY_CLOCK="$DRY_T0"
  DRY_CHARGE0=88
  DRY_EVENTS=" "
  DRY_LPM=0
  DRY_CLAUDE_RUN=""
  unplug=$((DRY_T0 - 20 * 60))
  case "$scenario" in
    default) DRY_EVENTS=" 4:touched 10:adapter 12:lpm 17:claude 18:slept 20:locked " ;;
    low) DRY_CHARGE0=62 ;;
    late) unplug=$((DRY_T0 - 2 * 3600)) ;;
    *) fail "the dry runs are default, low and late" ;;
  esac
  mkdir -p "$LOGS" "$SECTIONS" "$SHOTS"
  ARM_PID=$$
  ARM_START="$(proc_start "$ARM_PID")"
  printf 'epoch\tupdate_time\tremaining_mah\tsystem_power_in_mw\texternal\tpack_temperature\thid_idle_s\tlocked\tlid\tscreensaver\tclaude_children\tclaude_cpu_s\n' \
    >"$LOGS/sampler.tsv"
  dry_stubs
  if ! queue_run "$unplug" >"$LOGS/dry-run.txt" 2>&1; then
    cat "$LOGS/dry-run.txt"
    fail "the dry run stopped"
  fi
  awk -F '\t' 'NR > 1 { printf "%3s %-7s %-16s %-4s %-4s %3s%%  %s\n", $1, $2, $3, $4, $5, $8, $NF }' "$LOGS/queue-runs.tsv"
  problems="$(dry_checks "$scenario" $((unplug + 3 * 3600)))"
  if [ -n "$problems" ]; then
    printf '%s\n' "$problems" >&2
    fail "the $scenario dry run broke the queue's rules"
  fi
  echo "dry run $scenario: the order, the retries and the thresholds hold ($(($(grep -c . "$LOGS/queue-runs.tsv") - 1)) rows)"
  case "$WORK" in "${TMPDIR:-/tmp}"/bp-062-dry.*) rm -rf "$WORK" ;; esac
}

dry_event() {
  case "$DRY_EVENTS" in *" $Q_INDEX:$1 "*) return 0 ;; esac
  return 1
}

dry_stubs() {
  q_now() { echo "$DRY_CLOCK"; }
  q_sleep() { DRY_CLOCK=$((DRY_CLOCK + $1)); }
  q_on_battery() { return 0; }
  on_battery() { return 0; }
  q_charge() { echo $((DRY_CHARGE0 - (DRY_CLOCK - DRY_T0) / 600)); }
  battery_percent() { q_charge; }
  q_install() {
    if dry_event error; then return 1; fi
    DRY_CLOCK=$((DRY_CLOCK + 60))
  }
  q_after_s7() { DRY_CLOCK=$((DRY_CLOCK + 180)); }
  quit_app() { :; }
  session_settings() { :; }
  set_default() { :; }
  q_launch() { :; }
  open_main() { :; }
  app_pid() { echo 4242; }
  app_running() { return 0; }
  q_setup() { return 0; }
  q_confirm() { :; }
  q_teardown() { :; }
  q_wait_for() { return 0; }
  # Once S6 has turned the display off, the screen is locked, as with a password required at once.
  q_sample() { echo "hid_idle_s=9999 locked=$(if [ -n "$Q_DISPLAY_OFF" ]; then echo yes; else echo no; fi) lid=open screensaver=no thermal=nominal lowpower=$DRY_LPM"; }
  q_sudo_ok() { return 0; }
  q_set_lpm() { DRY_LPM="$1"; }
  lowpowermode_of() { echo "$DRY_LPM"; }
  q_perf_start() { :; }
  q_perf_stop() { :; }
  q_reads() { echo 24; }
  q_assertions() { echo 0; }
  q_display_sleep() { :; }
  let_display_sleep() { :; }
  q_history_kb() { echo 100; }
  q_screensaver() { echo no; }
  q_accessories() { echo 0; }
  q_universal_access() { echo "reduceTransparency=0 increaseContrast=0"; }
  q_alert() { :; }
  q_pack_temp() { echo 3000; }
  q_claude() { if [ "$DRY_CLAUDE_RUN" = "$Q_INDEX" ]; then echo "1,2,3 10.00"; else echo "1,2 10.00"; fi; }
  s7_launches() { out "- S7 $1: dry run"; }
  q_pmset_log() {
    # S6's display check reads 4 hours back: the display turned off just before the run.
    if [ $(($2 - $1)) -gt 14000 ]; then printf '%s +0000 Notification        \tDisplay is turned off\n' "$(epoch_stamp $(($1 + 14400 - 5)))"; fi
  }
  # In the background, as rusage is: the figures, and the sampler's rows of the window.
  q_rusage() {
    local awake="$2" t external locked idle
    if dry_event slept; then awake=$(($2 - 30)); fi
    printf 'seconds=%s\nawake_seconds=%s\nenergy_mj_per_h=%s\nidle_wakeups_per_h=1000\ninterrupt_wakeups_per_h=2000\ncpu_s_per_h=%s\nphys_footprint_bytes=21000000\n' \
      "$2" "$awake" "$(if [ "$Q_BUILD" = B ]; then echo 450.0; else echo 300.0; fi)" "$(if [ "$Q_BUILD" = B ]; then echo 4.500; else echo 3.000; fi)" >"$3"
    t=$((DRY_CLOCK + 10))
    while [ "$t" -lt $((DRY_CLOCK + $2)) ]; do
      # plutil's raw form of the boolean, as the real sampler writes it.
      external=false locked=no idle=$((t - DRY_CLOCK + 400))
      if dry_event adapter && [ $((t - DRY_CLOCK)) -gt 100 ]; then external=true; fi
      if dry_event locked && [ $((t - DRY_CLOCK)) -gt 100 ]; then locked=yes; fi
      if dry_event touched && [ $((t - DRY_CLOCK)) -gt 100 ]; then idle=5; fi
      printf '%s\t1\t3000\t5000\t%s\t3000\t%s\t%s\topen\tno\t1,2\t10.00\n' "$t" "$external" "$idle" "$locked" >>"$LOGS/sampler.tsv"
      t=$((t + 10))
    done
  }
  q_after_measure() {
    DRY_CLOCK=$((DRY_CLOCK + $1 - 5))
    if dry_event lpm; then DRY_LPM=1; fi
    if dry_event claude; then DRY_CLAUDE_RUN="$Q_INDEX"; fi
  }
}

# dry_checks <scenario> <late epoch>: the queue's rules, one line per break.
dry_checks() {
  awk -F '\t' -v scenario="$1" -v late="$2" -v events="$DRY_EVENTS" '
    NR == 1 { next }
    { n++; kind[n] = $2; s[n] = $3; b[n] = $4; pair[n] = $5; start[n] = $6 + 0; charge[n] = $8 + 0; status[n] = $NF }
    END {
      if (kind[1] != "warmup" || s[1] != "S2" || b[1] != "C") print "the first run isn t the S2 C warm-up"
      if (status[1] !~ /^(warm-up|not run)/) print "the warm-up isn t discarded"
      for (i = 1; i <= n; i++) {
        if (kind[i] == "run" && s[i] == "S2") lastS2 = i
        if (kind[i] == "run" && s[i] == "S1" && firstS1 == "") firstS1 = i
        started = (status[i] !~ /^not run/)
        if (started && charge[i] < 50) print "run " i " started below 50 %"
        optional = (s[i] ~ /^(S4w-frosted|S5|S10|S3|MIN)$/ || kind[i] == "retry")
        if (started && optional && charge[i] < 56) print "run " i " (optional or a retry) started below 56 %"
        if (kind[i] == "retry") {
          retried[s[i] " " pair[i] " " b[i]]++
          if (s[i] == "S6" || s[i] == "S7") print "S6 or S7 was retried"
          if (lastS6 != "") print "a retry came after S6"
        }
        if (s[i] == "S6" && lastS6 == "") lastS6 = i
        # S6 keeps its time: no optional run or retry starts unless it, and S6 after it, fit
        # before the cap; one that was skipped for it had to be.
        need = (kind[i] == "retry" && b[i] == "B" && s[i] ~ /^(S1|S2|S2-LPM)$/) ? 720 : 360
        # A started run has its measurement start: 2 minutes (the install, the quiet minute) after the check.
        if (started && optional && start[i] - 120 + need + 1500 > late) print "run " i " (optional or a retry) ate into S6s time"
        if (status[i] ~ /time kept for S6/ && start[i] + need + 1500 <= late && !(kind[i] == "retry" && b[i] == "C" && status[i - 1] ~ /time kept/))
          print "run " i " kept time for S6 it had"
        if (s[i] == "S6" && status[i] ~ /locked/) print "run " i " (S6) counted the lock its own display sleep brings"
        if (scenario == "late" && start[i] >= late && status[i] !~ /late/) print "run " i " started after the deadline"
        if (status[i] ~ /late/ && start[i] < late) print "run " i " was late too early"
      }
      if (s[n - 1] != "S6" || b[n - 1] != "B" || s[n] != "S6" || b[n] != "C") print "S6 B C isn t last"
      if (scenario == "default" && (status[n - 1] ~ /^not run/ || status[n] ~ /^not run/)) print "S6 didn t run in the default night"
      if (firstS1 == "" || lastS2 >= firstS1) print "an S2 run comes after S1 began"
      for (i = 1; i <= n; i++) {
        if (kind[i] != "run" || status[i] !~ /^not valid/) continue
        key = s[i] " " pair[i] " " b[i]
        if (status[i] ~ /LPM/) { if (key in retried) print "the LPM-invalid run " i " was retried"; continue }
        if (s[i] == "S6") continue
        if (s[i] ~ /^(S1|S2|S2-LPM)$/) {
          if (!((s[i] " " pair[i] " B") in retried) || !((s[i] " " pair[i] " C") in retried)) print "run " i " (" s[i] ") wasn t retried as its B and C pair"
        } else if (!(key in retried)) print "run " i " (" s[i] ") wasn t retried"
        if ((key in retried) && retried[key] > 1) print "run " i " was retried twice"
      }
      if (scenario == "default") {
        # Each scripted event marks its own run with its own reason.
        reason["touched"] = "touched"; reason["adapter"] = "adapter"; reason["lpm"] = "LPM"
        reason["claude"] = "Claude active"; reason["slept"] = "slept"; reason["locked"] = "locked"
        m = split(events, list, " ")
        for (j = 1; j <= m; j++) {
          split(list[j], e, ":")
          if (status[e[1]] !~ /^not valid/ || index(status[e[1]], reason[e[2]]) == 0)
            print "run " e[1] " (" s[e[1]] ") isn t marked " reason[e[2]] ": " status[e[1]]
        }
      }
    }' "$LOGS/queue-runs.tsv"
}

# MARK: - help

step_help() {
  if [ "$SESSION" = B ]; then
    step_help_b
    return 0
  fi
  cat <<EOF
usage: $SCRIPT <command> [arguments]

Session A (PLAN.md §6), in order; SESSION.md is the runbook:
  prepare [--fresh-backup]   backup into ~/bp-062/A, the builds, the tools, 0.6.1 running (step 1)
  widgets-ref                the reference picture of the placed widgets
  f5 start | capture <state> | end
                             accessories and the iPhone page on 0.6.1 (step 2)
  spike c | i | w | tick | ru on|off | logs
                             the widget spikes (step 3)
  voiceover                  0.6.1 again; VoiceOver and Text size (step 4)
  v01 start | check          V-01 on SPIKE-A2 (step 5)
  fill ready|record|frames <clear-light|clear-dark|translucent-dark|translucent-dark-b> | fill done
                             Clear's minimize fill, recorded and dumped to frames (step 6)
  attach-timing              hdiutil against diskutil image attach (step 7)
  pages [profiling]          page switches, then under xctrace (step 8)
  window                     the unattended window, in Terminal (step 9): energy, field run, pslog,
                             then restore and send

Any time:
  answer [--by claude|person] <id> <value> [note]   record an answer (English only)
  note <text>                a note for A.md (English only)
  mark <label>               a point in time the spike log summary splits at
  shot <name>                a screenshot into shots/
  crop <image> <x> <y> <w> <h> <name>              a part of a screenshot, in pixels
  attach <image> <caption>   publish a small copy of an image in A.md (look at it first)
  unattach <file>            take one back out
  appearance light|dark|back
  install <C|I|W|W2|B|A2|A2P|A|backup>
                             one build, the way every step installs it (after a refusal: install B);
                             W2 is W rebuilt as #307, for W0-2's retest after install B
  status                     answers so far, the installed build, the battery
  restore                    your app, settings, data and system settings back, then what to do by hand
  send [--dry-run]           A.md to docs/plans/0.6.2/sessions/ on $RESULTS_BRANCH

Session B runs from ~/bp-062/B/run (see help there); queue --dry-run checks its queue anywhere.
EOF
}

step_help_b() {
  cat <<EOF
usage: $SCRIPT <command> [arguments]          (Session B, hands-free; SESSION-B.md is the runbook)

B0a (on the adapter, he is there):
  prepare attempt [--kept <setting>[,...]] [--restored <setting>[,...] "<how>"]
                             first: a clean start (an earlier attempt's ~/bp-062/B moves aside)
  answer --by person B-yes y (and B-bedtime, B-keep-ax, B-usage)
  prepare [--fresh-backup]   the backup into ~/bp-062/B, the builds (B, C = the RC, CP), the tools, the RC; a beep
B0b (at the beep, he is there):
  prepare reads              the Charge Limit, the style keys, Open at login, the hot corners, the screen saver,
                             the wallpaper, the generated wallpapers, the shots Claude reads
  proof P1 --image <png> <x> <y> | P2 | P3 [1|2] | P4 | P6 | P7 | P8 | P9 | P11 | <P#> pass|fail <note>
  preflight [quiet]          the checks, P2 P6 P7 P8 P9 P11, the keep-awake read and the 70-second quiet check
                             (quiet: those two again, after he quit what it named)
  widget <family> <x> <y> <w> <h>; desktop-spot <x> <y> | --image <png> <x> <y>
  v01 notify [front]; f11 alert   the banners
  arm open; mark away        the arm window (Terminal), then the GUI phase (no sound from here until his continue)
B2 (the GUI phase; heartbeat <step and expected ready time> after each step):
  v01 menubar | check; f6 <page>; f8 [ru on|ru|ru off]; f9; relaunch; f11 login | listed; pages [profiling];
  f12 rate | before | after; install C; wp18 previews | timing
  case <translucent|clear>-<light|dark>-<main|compact>   the optional glass-sheet cases, last
  pane <$(echo "$PANES" | tr ' ' '|')>; open-app Xcode | TextEdit (restore quits only these)
  measure <id> black|blank|same|differs <arguments>; judge <id> <answer> [--unsure] [note]
  change <setting> <original> <new> (before any change by computer use); restored <setting> <how>
  ui <command...>            the hands (ui.swift's usage), through the script only
B3:
  restore gui                then, last: ready
B4-B5 (the arm window, no session): his Return, password, brightness, Focus and unplug; 70 quiet seconds;
  the cooldown; the queue; restore night
B7 (on his continue):
  continue; v01 morning; morning; restore morning; batch (optional); send [--dry-run] (after answer --by person B-send y)
Not in this attempt (PLAN.md §6): styleshot, gradshot, audit, v1b, burst, memory, the extras, the morning-away block.
Any time: status, note, shot, crop, attach, unattach, charge-limit check, help; queue --dry-run [default|low|late] anywhere.
EOF
}

# b_run <step> [arguments]: a Session B step with set -e's exit off inside it, so a failed read or a
# refused ui call is that item's "not checked" and the step goes on; fail still stops it.
b_run() {
  local status=0
  "$@" || status=$?
  if [ "$status" != 0 ]; then
    warn "the step ended with status $status"
    exit "$status"
  fi
}

COMMAND="${1:-}"
if [ $# -gt 0 ]; then shift; fi
# B0a's clean start comes before every fence: an earlier attempt's ready or queue.started would
# stop it, and it moves them aside (step_attempt_b refuses while that attempt's arm window runs).
if [ "$SESSION" = B ] && [ "$COMMAND" = prepare ] && [ "${1:-}" = attempt ]; then
  shift
  b_run step_attempt_b "$@"
  exit 0
fi
# Once Session B's ready is up, or while its queue runs, nothing acts until his morning continue:
# checked before the session is told apart, so neither his own checkout nor Session A's commands
# (install, restore, appearance) get past it. The reads and the arm itself are let through.
case "$COMMAND:${1:-}" in
  help:* | -h:* | --help:* | status:* | continue:* | queue:* | arm: | :) ;;
  *) night_fence ;;
esac
if [ "$SESSION" = B ]; then
  # Every call but these reads is the session's heartbeat, and keeps the script's own while it
  # runs; each needs this attempt's folder.
  case "$COMMAND:${1:-}" in
    help:* | -h:* | --help:* | status:* | continue:* | queue:* | arm: | :) ;;
    *)
      attempt_fence
      b_fence
      mkdir -p "$WORK"
      touch "$HEARTBEAT"
      heartbeat_keeper
      ;;
  esac
  case "$COMMAND" in
    widgets-ref | f5 | spike | voiceover | fill | attach-timing | window) fail "$COMMAND is a Session A command" ;;
  esac
fi
case "$COMMAND" in
  prepare)
    if [ "$SESSION" = B ]; then
      if [ "${1:-}" = reads ]; then b_run step_prepare_reads; else step_prepare_b "$@"; fi
    else
      step_prepare "$@"
    fi
    ;;
  widgets-ref) step_widgets_ref ;;
  f5) step_f5 "$@" ;;
  spike) step_spike "$@" ;;
  voiceover) step_voiceover ;;
  v01) if [ "$SESSION" = B ]; then b_run step_v01_b "$@"; else step_v01 "$@"; fi ;;
  fill) step_fill "$@" ;;
  attach-timing) step_attach_timing ;;
  pages) if [ "$SESSION" = B ]; then b_run step_pages_b "$@"; else step_pages "$@"; fi ;;
  window) step_window ;;
  answer) step_answer "$@" ;;
  note) step_note "$@" ;;
  mark) step_mark "$@" ;;
  shot) step_shot "$@" ;;
  crop) step_crop "$@" ;;
  attach) step_attach "$@" ;;
  unattach) step_unattach "$@" ;;
  appearance) step_appearance "$@" ;;
  install) step_install "$@" ;;
  status) step_status ;;
  restore)
    if [ "$SESSION" = B ]; then
      b_run step_restore_b "$@"
    else
      [ $# -eq 0 ] || fail "restore takes no argument in Session A; restore gui, night and morning are Session B's"
      step_restore
    fi
    ;;
  send) step_send "$@" ;;
  heartbeat) b_run step_heartbeat "$@" ;;
  change) b_run step_change "$@" ;;
  restored) b_run step_restored "$@" ;;
  measure) b_run step_measure "$@" ;;
  judge) b_run step_judge "$@" ;;
  batch) b_run step_batch ;;
  ui) b_run step_ui "$@" ;;
  pane) b_run step_pane "$@" ;;
  open-app) b_run step_open_app "$@" ;;
  widget) b_run step_widget "$@" ;;
  desktop-spot) b_run step_desktop_spot "$@" ;;
  devices) b_run step_devices "$@" ;;
  proof) b_run step_proof "$@" ;;
  preflight) b_run step_preflight "$@" ;;
  case) b_run step_case "$@" ;;
  styleshot | gradshot | audit | v1b) fail "$COMMAND left Session B after its first attempt: G-13b takes its default, both styles stay beta (PLAN.md §6, §7.1)" ;;
  f6) b_run step_f6 "$@" ;;
  f8) b_run step_f8 "$@" ;;
  f9) b_run step_f9 ;;
  f11) b_run step_f11 "$@" ;;
  f12) b_run step_f12 "$@" ;;
  relaunch) b_run step_relaunch ;;
  memory) b_run step_memory "$@" ;;
  burst) b_run step_burst ;;
  arm) b_run step_arm "$@" ;;
  ready) b_run step_ready ;;
  continue) b_run step_continue ;;
  morning) b_run step_morning ;;
  charge-limit) b_run step_charge_limit "$@" ;;
  menu-bar-shots) b_run step_menu_bar_shots "$@" ;;
  wp18) b_run step_wp18 "$@" ;;
  queue)
    if [ "${1:-}" = --dry-run ]; then
      queue_dry_run "${2:-default}"
    else
      fail "the queue runs in the arm window ($SCRIPT arm open); queue --dry-run [default|low|late] checks its order anywhere"
    fi
    ;;
  help | -h | --help) step_help ;;
  *)
    step_help >&2
    exit 1
    ;;
esac
