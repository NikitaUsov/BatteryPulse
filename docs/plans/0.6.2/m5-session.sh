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

# Session B's builds (PLAN.md §6, WP-21): B, the published 0.6.1 (TAG_B); C, the RC, which D1
# dispatches as 0.5.99 so that F12's update check offers the real 0.6.1; CP, the RC's profiling
# DMG. D1 pins the run and the artifact names here; while they are empty, prepare looks for the
# newest successful CI run of the integration branch with the frozen worktree's code (rc_locate).
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
case "$HERE" in
  "$HOME"/*) SCRIPT="bash ~${HERE#"$HOME"}/m5-session.sh" ;;
  *) SCRIPT="bash $HERE/m5-session.sh" ;;
esac
# The session: B when the script runs from Session B's frozen worktree (~/bp-062/B/run, the start
# line's one allow rule), A otherwise; BP_SESSION overrides it for a dry run elsewhere.
case "$HERE" in
  "$HOME"/bp-062/B/run/*) SESSION="${BP_SESSION:-B}" ;;
  *) SESSION="${BP_SESSION:-A}" ;;
esac
# queue --dry-run (CI on Linux) is Session B's queue in a folder of its own.
if [ "${1:-}" = queue ] && [ "${2:-}" = --dry-run ]; then
  SESSION=B
  BP_WORK="$(mktemp -d "${TMPDIR:-/tmp}/bp-062-dry.XXXXXX")"
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
# status, send --dry-run, queue --dry-run) on another machine.
WORK="${BP_WORK:-$HOME/bp-062/$SESSION}"
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
  if [ "$SESSION" = B ] && [ "$1" = away ]; then clock >"$WORK/away"; fi
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

end_widget_extension() { pkill -TERM -x BatteryPulseWidget 2>/dev/null || true; }

# end_widget_extension_and_wait: ends every BatteryPulseWidget process before a swap and waits for
# it: SIGTERM first, SIGKILL after 0.5 s, giving up after 1.5 s. Session A found that chronod
# refetches a widget's descriptors at the version change from whatever extension still runs, and
# caches them under the new CFBundleVersion: the previous build's static descriptor then made every
# reload of a configurable kind fail (CHSErrorDomain 1103). Prints the milliseconds it took.
end_widget_extension_and_wait() {
  local ticks=0 signal=TERM
  # 20 ms ticks, counted rather than timed: macOS's bash 3.2 has no clock below a second.
  while pgrep -x BatteryPulseWidget >/dev/null 2>&1; do
    if [ "$ticks" -ge 75 ]; then
      warn "a BatteryPulseWidget process still runs after about 1.5 s"
      break
    fi
    if [ "$ticks" -ge 25 ]; then signal=KILL; fi
    pkill "-$signal" -x BatteryPulseWidget 2>/dev/null || true
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
  awk -F '\t' -v name="$1" '$1 != name' "$PUBLISH/captions.tsv" >"$PUBLISH/captions.tmp"
  mv "$PUBLISH/captions.tmp" "$PUBLISH/captions.tsv"
  rm -f "$PUBLISH/$1"
  echo "removed $1"
}

step_crop() {
  [ $# -eq 6 ] || fail "usage: $SCRIPT crop <image> <x> <y> <width> <height> <name> (pixels from the top left)"
  [ -x "$BIN/frames" ] || fail "the frame helper isn't built (see $BIN/frames.log)"
  mkdir -p "$SHOTS"
  "$BIN/frames" crop "$1" "$2" "$3" "$4" "$5" "$SHOTS/$6.png"
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
    light | dark) appearance "$1" ;;
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

# Low Power Mode as prepare found it, per power source; the window's EXIT trap calls it.
restore_lowpowermode() {
  local battery adapter
  battery="$(cat "$BACKUP/lowpowermode-battery" 2>/dev/null || true)"
  adapter="$(cat "$BACKUP/lowpowermode-ac" 2>/dev/null || true)"
  [ -n "$battery" ] && [ -n "$adapter" ] || return 0
  if [ "$(lowpowermode_of Battery)" = "$battery" ] && [ "$(lowpowermode_of AC)" = "$adapter" ]; then return 0; fi
  if sudo -n pmset -b lowpowermode "$battery" >/dev/null 2>&1 && sudo -n pmset -c lowpowermode "$adapter" >/dev/null 2>&1; then
    echo "Low Power Mode is back as it was (battery $battery, adapter $adapter)."
  else
    echo "PUT BACK (person, in Terminal): sudo pmset -b lowpowermode $battery; sudo pmset -c lowpowermode $adapter"
  fi
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
stamped() {
  local output="$1"
  shift
  if [ ! -f "$BIN/stamp.zsh" ]; then
    cat >"$BIN/stamp.zsh" <<'EOF'
zmodload zsh/datetime
while IFS= read -r line; do
  line=${line%$'\r'}
  print -r -- "$EPOCHREALTIME $line"
done
EOF
  fi
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
  defaults delete "$WIDGET_PREFS" AppleLanguages 2>/dev/null || true
  if [ -f "$BACKUP/widget-languages" ]; then
    warn "the widget extension had its own AppleLanguages before: $(tr -s ' \n' ' ' <"$BACKUP/widget-languages"); set it again by hand if you need it"
  fi
  end_widget_extension
  restore_lowpowermode
  if [ -s "$BACKUP/wallpapers" ] && [ "$(wallpapers)" != "$(cat "$BACKUP/wallpapers")" ]; then
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

# send [--dry-run]: A.md (and the attached images) committed to docs/plans/0.6.2/sessions/ on
# claude/062-session-a, which starts from the integration branch; a fresh shallow clone in
# ~/bp-062/A/send, so your own checkout stays as it is. Never another branch, never a pull request.
step_send() {
  local dry_run="" clone="$WORK/send" base name email total
  if [ "${1:-}" = --dry-run ]; then dry_run=1; fi
  mkdir -p "$WORK"
  build_report | public >"$WORK/A.md"
  if has_cyrillic "$(cat "$WORK/A.md")"; then
    fail "A.md contains Russian text; translate the answer or note it comes from, then send again"
  fi
  total=0
  if [ -s "$PUBLISH/captions.tsv" ]; then total="$(du -sk "$PUBLISH" | cut -f1)"; fi
  [ "$total" -le 6144 ] || fail "the attached images take $total KB; unattach some (at most 6 MB)"
  echo "wrote $WORK/A.md ($(wc -l <"$WORK/A.md" | tr -d ' ') lines, images $total KB)"
  [ -z "$dry_run" ] || return 0

  rm -rf "$clone"
  base="$INTEGRATION_BRANCH"
  if git ls-remote --exit-code --heads "https://github.com/$REPO.git" "$RESULTS_BRANCH" >/dev/null 2>&1; then
    base="$RESULTS_BRANCH"
  fi
  git clone --quiet --depth 1 --branch "$base" "https://github.com/$REPO.git" "$clone"
  git -C "$clone" checkout --quiet -B "$RESULTS_BRANCH"
  mkdir -p "$clone/docs/plans/0.6.2/sessions"
  rm -rf "$clone/docs/plans/0.6.2/sessions/A"
  cp "$WORK/A.md" "$clone/docs/plans/0.6.2/sessions/A.md"
  if [ -s "$PUBLISH/captions.tsv" ]; then
    mkdir -p "$clone/docs/plans/0.6.2/sessions/A"
    cut -f1 "$PUBLISH/captions.tsv" | while IFS= read -r file; do
      cp "$PUBLISH/$file" "$clone/docs/plans/0.6.2/sessions/A/"
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
  git -C "$clone" -c user.name="$name" -c user.email="$email" commit --quiet -F - <<'EOF'
Record M5 Session A's results

The answers, counts, perf-stats summaries, public log excerpts and the
attached screenshots of Session A (PLAN.md §6), for the packages and
gates that wait on them.

Co-Authored-By: Claude <noreply@anthropic.com>
EOF
  git -C "$clone" -c credential.helper= -c 'credential.helper=!gh auth git-credential' \
    push --quiet origin "HEAD:refs/heads/$RESULTS_BRANCH"
  echo "Sent: https://github.com/$REPO/blob/$RESULTS_BRANCH/docs/plans/0.6.2/sessions/A.md"
}

# MARK: - Session B: its questions

# question_b <id>: Session B's questions, in question()'s format; judged ones are Claude's, beside
# the script's measurement where one exists (WP-21), and each has its written criteria and default
# in SESSION-B.md.
question_b() {
  local rest style paper look page family lang item
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
    energy-setup) echo "2|judge|The energy setup at the hand-over: brightness about half, auto-brightness and True Tone off, his apps quit, a Focus on: 1 done, 2 not all (note; the default)" ;;
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
      fill-translucent-light-compact | fill-translucent-dark-compact | fill-clear-light-compact | fill-clear-dark-compact | \
      fill-standard-light-main | fill-frosted-light-main)
      echo "3|judge|${1#fill-}: while it shrank into the Dock and came back: 1 like the window, or an even graphite grey (the chosen fill), 2 a black frame or rectangle, 3 something else (note)"
      ;;
    shot-*)
      rest="${1#shot-}"
      style="${rest%%-*}"
      rest="${rest#*-}"
      paper="${rest%%-*}"
      rest="${rest#*-}"
      look="${rest%%-*}"
      page="${rest#*-}"
      case "$style" in translucent | clear) ;; *) return 1 ;; esac
      case "$paper" in bright | busy) ;; *) return 1 ;; esac
      case "$look" in light | dark) ;; *) return 1 ;; esac
      case "$page" in overview | history | settings) ;; *) return 1 ;; esac
      echo "yn|judge|$style on the $paper wallpaper, $look, $page: readable, no black, grey or missing parts"
      ;;
    grad-translucent-sheet | grad-clear-sheet)
      rest="${1#grad-}"
      echo "yn|person|The contact sheet of ${rest%-sheet}'s shots (the 24 and the graduation shots): every shot looks right"
      ;;
    grad-clear-light-settings) echo "yn|judge|Settings → General beside a Clear window in Light: looks right" ;;
    grad-frosted-light-gallery | grad-frosted-dark-gallery) echo "yn|judge|The widget gallery behind a Frosted window, ${1#grad-frosted-}: looks right" ;;
    grad-*)
      rest="${1#grad-}"
      style="${rest%%-*}"
      rest="${rest#*-}"
      look="${rest%%-*}"
      item="${rest#*-}"
      case "$style" in translucent | clear) ;; *) return 1 ;; esac
      case "$look" in light | dark) ;; *) return 1 ;; esac
      case "$item" in raw | demo | history | fullscreen) ;; *) return 1 ;; esac
      echo "yn|judge|Graduation shot, $style $look, $item: looks right"
      ;;
    graduate-translucent) echo "yn|person|From 0.6.2 on, offer Translucent without the Beta window styles setting?" ;;
    graduate-clear) echo "yn|person|And Clear?" ;;
    audit-*)
      rest="${1#audit-}"
      style="${rest%%-*}"
      rest="${rest#*-}"
      look="${rest%%-*}"
      page="${rest#*-}"
      case "$style" in translucent | clear) ;; *) return 1 ;; esac
      case "$look" in light | dark) ;; *) return 1 ;; esac
      case "$page" in overview | history | settings) ;; *) return 1 ;; esac
      echo "3|judge|The contrast audit, $style $look $page: 1 no failure, 2 a failure (note), 3 not run or an estimate only"
      ;;
    V1b) echo "yn|judge|V1b: the Clear tile's preview is identical selected and unselected, inside the outline" ;;
    SZ-10) echo "yn|person|The Icon Composer icon in the four icon styles (SZ-10): ship it in 0.6.2" ;;
    SUI-17) echo "yn|judge|SUI-17: the previews render" ;;
    *) return 1 ;;
  esac
}

# The order of Session B's answers in status and B.md.
questions_b() {
  local style paper look page item
  echo B-yes B-bedtime B-charge-capture B-keep-widgets B-keep-ax B-slider-auth B-usage
  echo prep-charge-limit prep-widget-style prep-dim-widgets prep-open-at-login prep-widgets prep-wallpaper-kind
  echo P3-capture P4-frames
  echo V01-notification V01-notification-front V01-menubar V01-pages V01-lid
  echo F11-alert F11-login F6-overview F6-power F6-history F6-health F6-raw
  echo F8-small-en F8-medium-en F8-large-en F8-xlarge-en F8-small-ru F8-medium-ru F8-large-ru F8-xlarge-ru
  echo F9-overview F9-settings F9-update F12-widget
  for item in $FILL_CASES_B; do echo "fill-$item"; done
  for style in translucent clear; do
    for paper in bright busy; do
      for look in light dark; do
        for page in overview history settings; do echo "shot-$style-$paper-$look-$page"; done
      done
    done
    for look in light dark; do
      for item in raw demo history fullscreen; do echo "grad-$style-$look-$item"; done
      for page in overview history settings; do echo "audit-$style-$look-$page"; done
    done
  done
  echo grad-clear-light-settings grad-frosted-light-gallery grad-frosted-dark-gallery
  echo V1b grad-translucent-sheet grad-clear-sheet graduate-translucent graduate-clear SZ-10 SUI-17 energy-setup B-send
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
MORNING="$WORK/morning-items.txt"
# Posted with the ready file: the arm window's waiter wakes at once instead of at its backstop.
READY_NOTIFY="io.github.nikitausov.BatteryPulse.session-b.ready"
# Every B run but the queue's: the queue reads them fresh, and a dry run swaps them out.
DRY_RUN=""

b_only() { [ "$SESSION" = B ] || fail "$1 is a Session B command: run it from the frozen worktree ~/bp-062/B/run"; }

# mtime_of <file>: its modification time; GNU stat's -f means another thing, so -c goes first.
mtime_of() { stat -c %Y "$1" 2>/dev/null || stat -f %m "$1" 2>/dev/null || echo 0; }

# epoch_stamp <epoch>: "YYYY-MM-DD HH:MM:SS", the local time pmset -g log and log show use.
epoch_stamp() { date -r "$1" '+%Y-%m-%d %H:%M:%S' 2>/dev/null || date -d "@$1" '+%Y-%m-%d %H:%M:%S'; }

epoch_hm() { date -r "$1" '+%H:%M' 2>/dev/null || date -d "@$1" '+%H:%M'; }

is_away() { [ -f "$WORK/away" ] && [ ! -f "$WORK/continued" ]; }

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

# caller_is_arm: the arm window's process (its pid in arm.pid) is this call's ancestor.
caller_is_arm() {
  local arm
  arm="$(cat "$WORK/arm.pid" 2>/dev/null || true)"
  [ -n "$arm" ] && ancestor_pids | grep -qx "$arm"
}

# b_fence: once `ready` is up, or while queue.started exists, no command acts until his morning
# continue (§6 "Never act after ready"); `ui` enforces the same for itself.
b_fence() {
  if [ -f "$FENCE" ] && ! caller_is_arm; then
    fail "the energy queue runs ($FENCE exists): results in the morning; nothing was done"
  fi
  if [ -f "$READY_FILE" ] && [ ! -f "$WORK/continued" ] && ! caller_is_arm; then
    fail "ready is up: nothing acts until his morning continue; nothing was done"
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

# A step that couldn't run: "not checked" or "not run" with its reason, and the session goes on.
not_checked() {
  local id="$1"
  shift
  printf '%s\t%s\t%s\n' "$(date '+%H:%M')" "$id" "$*" >>"$WORK/not-checked.tsv"
  echo "NOT CHECKED $id: $*"
}

# MARK: - Session B: the hands (ui), the windows and the shots

# ui <command...>: the ui helper with the taps and hosts preflight chose (PLAN.md WP-21); every
# action passes its own safety rules, the queue.started fence among them.
ui_run() {
  if [ ! -x "$BIN/ui" ]; then
    warn "the ui helper isn't built (see $BIN/ui.log)"
    return 1
  fi
  BP_UI_TAP="$(cat "$WORK/ui-tap" 2>/dev/null || echo hid)" BP_UI_HOSTS="$(cat "$WORK/ui-hosts" 2>/dev/null || true)" \
    BP_FENCE="$FENCE" "$BIN/ui" "$@"
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
  sleep 2
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
  echo "SHOT $file (main window $rect)"
}

# rect_shot <file> <x y w h>: a rectangle of the screen, in points.
rect_shot() {
  mkdir -p "$(dirname "$1")"
  if [ -n "$2" ] && screencapture -x -R"$(tr ' ' ',' <<<"$2")" "$1" && [ -s "$1" ]; then
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
  open "$url"
  sleep 2
  ui_run title "System Settings" || true
}

# widget <family> <x> <y> <w> <h>: a placed widget's frame in points (from proof P1's `ui hit`),
# for F8's and F12's crops. AX can't move widgets, so their frames come from here.
step_widget() {
  b_only widget
  [ $# -eq 5 ] || fail "usage: $SCRIPT widget small|medium|large|xlarge <x> <y> <w> <h>"
  case "$1" in small | medium | large | xlarge) ;; *) fail "a family is small, medium, large or xlarge" ;; esac
  touch "$WORK/widgets.tsv"
  awk -F '\t' -v f="$1" '$1 != f' "$WORK/widgets.tsv" >"$WORK/widgets.tmp"
  mv "$WORK/widgets.tmp" "$WORK/widgets.tsv"
  printf '%s\t%s %s %s %s\n' "$1" "$2" "$3" "$4" "$5" >>"$WORK/widgets.tsv"
  echo "widget $1 at $2 $3 $4 $5"
}

widget_rect() { awk -F '\t' -v f="$1" '$1 == f { print $2 }' "$WORK/widgets.tsv" 2>/dev/null || true; }

# desktop-spot <x> <y> | --image <png> <x> <y>: an empty spot of the desktop, the fixed action
# before each widget comparison (Dim widgets reacts to the desktop's focus).
step_desktop_spot() {
  b_only desktop-spot
  local hit
  hit="$(ui_run hit "$@")" || fail "ui hit failed there: $hit"
  case "$hit" in
    *"process: Finder"* | *"process: Dock"* | *"process: WindowManager"* | *"process: Wallpaper"*) ;;
    *) fail "that point isn't the desktop: $(head -1 <<<"$hit")" ;;
  esac
  # <x> <y> in points, or --image <png> <x> <y>, which ui converts at every click.
  printf '%s\n' "$*" >"$WORK/desktop-spot.args"
  echo "desktop spot: $(cat "$WORK/desktop-spot.args")"
}

# click_desktop: the fixed action before a widget comparison: a click on the empty desktop spot,
# then 1 s; with click-to-show-desktop on, again, checked with ui windows.
click_desktop() {
  [ -f "$WORK/desktop-spot.args" ] || {
    warn "no desktop spot recorded (desktop-spot)"
    return 1
  }
  # The recorded arguments are split on purpose: <x> <y> or --image <png> <x> <y>.
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

# MARK: - Session B: the energy queue (B4, step 8; WP-21)

# The world the queue touches, one function each, so `queue --dry-run` can stand in for it.
q_now() { date +%s; }
q_sleep() { sleep "$1"; }
q_on_battery() { on_battery; }
q_charge() { battery_percent; }
q_install() { install_build "$1" --no-launch; }
q_sample() { ui_run sample 2>/dev/null || echo "hid_idle_s=unknown locked=unknown lid=unknown thermal=unknown lowpower=unknown"; }
q_sudo_ok() { sudo_ok; }
q_set_lpm() { set_lowpowermode "$1"; }
q_rusage() { rusage "$1" "$2" >"$3" 2>&1; }
q_perf_start() { perf_capture "$1"; }
q_perf_stop() { perf_stop "$STREAM"; }
q_reads() { app_reads "$1"; }
q_assertions() { pmset -g assertions 2>/dev/null | grep -c BatteryPulse || true; }
q_pmset_log() { pmset -g log 2>/dev/null | awk -v from="$(epoch_stamp "$1")" -v to="$(epoch_stamp "$2")" 'substr($0, 1, 19) >= from && substr($0, 1, 19) <= to' || true; }
q_display_sleep() { pmset displaysleepnow >/dev/null 2>&1 || warn "pmset displaysleepnow failed"; }
q_history_kb() { du -sk "$SUPPORT/History" 2>/dev/null | cut -f1 || echo 0; }
q_screensaver() { if pgrep -x ScreenSaverEngine >/dev/null 2>&1 || pgrep -x legacyScreenSaver >/dev/null 2>&1; then echo yes; else echo no; fi; }
q_accessories() { pmset -g accps 2>/dev/null | grep -v -i 'InternalBattery' | grep -c -E '[0-9]+%' || true; }
q_universal_access() {
  printf 'reduceTransparency=%s increaseContrast=%s' "$(defaults read com.apple.universalaccess reduceTransparency 2>/dev/null || echo 0)" \
    "$(defaults read com.apple.universalaccess increaseContrast 2>/dev/null || echo 0)"
}
q_after_measure() { :; }
q_alert() {
  osascript -e 'on run argv' -e 'display alert "BatteryPulse Session B" message (item 1 of argv) giving up after 45' \
    -e 'end run' "$1" >/dev/null 2>&1 &
}

q_pack_temp() {
  ioreg -r -c AppleSmartBatteryPack -a -d 1 >"$LOGS/q-pack.plist" 2>/dev/null || true
  plist_value "$LOGS/q-pack.plist" 0.BatteryData.Temperature
}

# q_claude: the Claude CLI's child processes (sorted, comma-joined) and its CPU seconds.
q_claude() {
  local pids pid children="" cpu=0 time
  pids="$(pgrep -x claude 2>/dev/null || true)"
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
# HIDIdleTime, the lock and the lid, the screen saver, and the Claude CLI's children and CPU.
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
      "$(q_screensaver)" "$(echo "$claude" | cut -d' ' -f1 | tr ',' '\n' | grep -c . || true)" "${claude##* }" \
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
  if [ "$Q_BUILD" = C ] && app_running; then app_pid >>"$WORK/rc-pids.txt"; fi
  sleep 1
}

# q_setup <scenario> <index>: the scenario's state before its quiet minute, by a reopen event,
# CGEvent clicks at CGWindowList frames and AX into TextEdit only; never an AX call into the
# measured process. Prints why not, and fails, when it can't.
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
          open -a TextEdit "$WORK/cover.txt" >/dev/null 2>&1 || true
          sleep 3
          # shellcheck disable=SC2086
          ui_run position TextEdit $rect >/dev/null 2>&1 || {
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
          ;;
        MIN)
          offset="$(cat "$WORK/minimize-offset" 2>/dev/null || true)"
          [ -n "$offset" ] || {
            echo "no minimize button offset (ready records it)"
            return 1
          }
          title="$(ui_run windows --app BatteryPulse 2>/dev/null | awk -F '\t' -v id="$id" '$1 == id { n = $5; sub(/^alpha [0-9.]* */, "", n); gsub(/"/, "", n); print n }' || true)"
          echo "${title:-BatteryPulse}" >"$WORK/q-min-title"
          # shellcheck disable=SC2046
          ui_run click $(awk -v r="$rect" -v o="$offset" 'BEGIN { split(r, w, " "); split(o, d, " "); printf "%d %d", w[1] + d[1], w[2] + d[2] }') \
            >/dev/null 2>&1 || {
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
      ui_run click $(awk '{ printf "%d %d", $1 + $3 / 2, $2 + $4 / 2 }' <<<"$item") >/dev/null 2>&1 || {
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
  case "$1" in
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
  local tile
  case "$1" in
    S5) ui_run quit TextEdit >/dev/null 2>&1 || warn "TextEdit didn't quit by its menu" ;;
    S3)
      # shellcheck disable=SC2046
      ui_run click $(ui_run windows --status-item 2>/dev/null | cut -d' ' -f2- | awk '{ printf "%d %d", $1 + $3 / 2, $2 + $4 / 2 }') >/dev/null 2>&1 || true
      ;;
    MIN)
      # The window's Dock tile, its frame from the Dock's AX tree, then CGWindowList's word.
      tile="$(ui_run frame --dock "$(cat "$WORK/q-min-title" 2>/dev/null || echo BatteryPulse)" 2>/dev/null | awk '{ printf "%d %d", $1 + $3 / 2, $2 + $4 / 2 }' || true)"
      # shellcheck disable=SC2086
      if [ -n "$tile" ] && ui_run click $tile >/dev/null 2>&1; then
        sleep 3
        if line_ok "$(main_window_line)"; then echo "restored from the Dock tile" >"$WORK/q-min-restore"; else echo "the Dock tile click didn't bring the window back" >"$WORK/q-min-restore"; fi
      else
        echo "no Dock tile to click" >"$WORK/q-min-restore"
      fi
      ;;
  esac
  return 0
}

# q_wait_for <what> <seconds>: nominal thermal state, or HIDIdleTime of 60 s; at most <seconds>.
q_wait_for() {
  local waited=0 sample
  while [ "$waited" -lt "$2" ]; do
    sample="$(q_sample)"
    case "$1" in
      nominal) [ "$(sample_field thermal "$sample")" != nominal ] || return 0 ;;
      idle) awk -v i="$(sample_field hid_idle_s "$sample")" 'BEGIN { exit !(i + 0 >= 60) }' && return 0 ;;
    esac
    q_sleep 30
    waited=$((waited + 30))
  done
  return 1
}

# q_detect <start> <end> <scenario> <sample at start> <sample at end> <claude at start> <claude at
# end> <rusage file> <want lpm> <first S6>: the detector columns, tab-separated: touched, slept,
# adapter, locked, screensaver, style, lpm, claude, then the reasons for "not valid" (or "-").
q_detect() {
  local start="$1" end="$2" scenario="$3" s0="$4" s1="$5" c0="$6" c1="$7" file="$8" want="$9" first_s6="${10}"
  local touched=no slept=no adapter=no locked=no saver=no style=- lpm=no claude=no reasons="" rows log idle
  rows="$(awk -F '\t' -v s="$start" -v e="$end" 'NR > 1 && $1 >= s && $1 <= e' "$LOGS/sampler.tsv" 2>/dev/null || true)"
  idle="$(sample_field hid_idle_s "$s1")"
  if awk -v i="$idle" -v d=$((end - start)) 'BEGIN { exit !(i != "unknown" && i + 2 < d) }'; then touched=yes; fi
  if [ -n "$rows" ] && awk -F '\t' -v s="$start" '$7 != "unknown" && $7 != "-" && $7 + 3 < $1 - s { found = 1 } END { exit !found }' <<<"$rows"; then touched=yes; fi
  if awk -F= '$1 == "seconds" { c = $2 } $1 == "awake_seconds" { a = $2 } END { exit !(a != "" && c - a > 1) }' "$file" 2>/dev/null; then slept=yes; fi
  log="$(q_pmset_log "$start" "$end")"
  if awk '$4 == "Sleep" || $4 == "DarkWake" || $4 == "Wake" { found = 1 } END { exit !found }' <<<"$log"; then slept=yes; fi
  if [ -n "$rows" ] && awk -F '\t' '$5 == "Yes" { found = 1 } END { exit !found }' <<<"$rows"; then adapter=yes; fi
  if ! q_on_battery; then adapter=yes; fi
  if [ "$scenario" = S6 ]; then
    # pmset displaysleepnow locks the screen when a password is required at once: only the first
    # S6 run's start counts.
    if [ "$first_s6" = yes ] && [ "$(sample_field locked "$s0")" = yes ]; then locked=yes; fi
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
      case "$(q_universal_access)" in *"=1"*) style=yes ;; esac
      ;;
  esac
  if [ "$(sample_field lowpower "$s0")" != "$want" ] || [ "$(sample_field lowpower "$s1")" != "$want" ]; then lpm=yes; fi
  if awk -v a="${c0%% *}" -v b="${c1%% *}" -v x="${c0##* }" -v y="${c1##* }" 'BEGIN {
      n = split(a, s, ","); for (i = 1; i <= n; i++) seen[s[i]] = 1
      m = split(b, e, ","); for (i = 1; i <= m; i++) if (e[i] != "" && !(e[i] in seen)) found = 1
      if (y - x > 2) found = 1
      exit !found }'; then claude=yes; fi
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
  local start end s0 s1 c0 c1 detect status assertions reads thermal why first_s6=no
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
  echo "$(clock) run $Q_INDEX: $kind $scenario on $build at $charge %"
  if ! (q_install "$build") >"$LOGS/q-install-$Q_INDEX.txt" 2>&1; then
    q_not_run "$kind" "$scenario" "$build" "$pair" "error (install: $(tail -1 "$LOGS/q-install-$Q_INDEX.txt"))"
    return 0
  fi
  q_settings "$scenario"
  if [ "$want" = 1 ] && [ "$(sample_field lowpower "$(q_sample)")" != 1 ]; then
    if ! q_sudo_ok || ! q_set_lpm 1; then
      q_not_run "$kind" "$scenario" "$build" "$pair" "no sudo ticket"
      return 0
    fi
  fi
  if [ "$want" = 0 ] && [ "$(lowpowermode_of Battery)" = 1 ] && q_sudo_ok; then q_set_lpm 0 || true; fi
  q_wait_for nominal 600 || echo "the thermal state isn't nominal after 10 minutes: the run goes on, its row says so"
  q_wait_for idle 600 || echo "HIDIdleTime stays under 60 s: the run goes on, the touch detector decides"
  q_launch
  if ! why="$(q_setup "$scenario" "$Q_INDEX")"; then
    q_teardown "$scenario"
    q_not_run "$kind" "$scenario" "$build" "$pair" "setup: $why"
    return 0
  fi
  q_sleep 60
  if [ "$scenario" = S6 ]; then
    if [ -z "$Q_DISPLAY_OFF" ]; then first_s6=yes; fi
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
  if [ "$scenario" = S2-LPM ]; then q_set_lpm 0 || warn "Low Power Mode is still on"; fi
  reads="$(q_reads "$capture")"
  detect="$(q_detect "$start" "$end" "$scenario" "$s0" "$s1" "$c0" "$c1" "$file" "$want" "$first_s6")"
  status="${detect##*"$TAB"}"
  if [ -n "$why" ]; then status="${status:+$status, }$why"; fi
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
}

# q_announce_s6: the dark runs are announced, never silent to a person at the Mac: the arm window
# comes to the front with the warning 30 s ahead (a notification would be hidden by the Focus);
# no sound, since none plays from `mark away` until his morning continue.
q_announce_s6() {
  local text="The display turns off for 10 minutes on purpose; please don't wake the Mac."
  echo
  echo "=== $(clock): $text (S6 starts in 30 s) ==="
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
  echo "The queue runs now. S6 (the display off for 10 minutes on purpose) at about $(epoch_hm "${times%% *}"); the end at about $(epoch_hm "${times##* }"). Please keep the lid open until then."
  if [ -z "$DRY_RUN" ]; then
    pmset -g assertions >"$LOGS/queue-assertions-start.txt" 2>&1 || true
    out "- pmset -g assertions at the start: $(grep -c BatteryPulse "$LOGS/queue-assertions-start.txt" || true) BatteryPulse lines (the full list stays on the Mac)"
    start_pslog
    q_sampler &
    BACKGROUND="$BACKGROUND $!"
    if [ "$(lowpowermode_of Battery)" = 1 ]; then
      if q_sudo_ok && q_set_lpm 0; then out "- Low Power Mode was set for battery: off for the runs (the EXIT trap puts it back)"; else
        out "- Low Power Mode is set for battery and there is no sudo ticket: every run but S2-LPM is LPM (not valid)"
      fi
    fi
    (q_install B) >"$LOGS/q-install-0.txt" 2>&1 || out "- install B at the start: error ($(tail -1 "$LOGS/q-install-0.txt"))"
  fi
  # Each run is wrapped: a failure is its row's "not run: error", and the queue goes on (never
  # set -e's exit). Nothing in a run reads the plan's standard input.
  while read -r kind scenario build pair optional; do
    if [ "$scenario" = S6 ] && [ -z "$Q_DISPLAY_OFF" ] && [ "$(q_now)" -lt "$Q_LATE" ]; then q_announce_s6; fi
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
  out "Medians of the valid runs per scenario and build (the spread is the lowest and highest run):"
  out ""
  queue_medians | tee -a "$SECTION"
}

# The rows of Session A's energy table (~/bp-062/A/logs/energy-rows.md) as "scenario build energy
# idle interrupt cpu reads", for the cross-session check and the chain C ÷ B × B ÷ A.
session_a_rows() {
  local file="$HOME/bp-062/A/logs/energy-rows.md"
  [ -f "$file" ] || return 0
  awk -F '|' 'NR > 2 && $4 !~ /not/ { gsub(/ /, ""); if ($6 + 0 > 0) print $2, $3, $6, $7, $8, $9, $11 }' "$file"
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
    NR > 1 && $NF == "valid" && $2 != "warmup" {
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

# MARK: - Session B: the queue's dry run (CI on Linux; WP-21's proposal)

# queue --dry-run [default|low|late]: the queue's order, its retries and its thresholds on any
# machine, with the world stubbed: no app, no pmset, ioreg or notifyutil, a clock that jumps, a
# charge that drains 1 % every 10 minutes, and scripted detector events (default: a touched S2, an
# adapter S1, an LPM S2-LPM, a Claude-active S4w and a slept S4w; low: from 62 %; late: the
# bedtime unplug 2 hours before the start). Exit status 1 on a broken rule.
queue_dry_run() {
  local scenario="${1:-default}" unplug problems
  DRY_RUN=1
  DRY_T0=1761300000
  DRY_CLOCK="$DRY_T0"
  DRY_CHARGE0=88
  DRY_EVENTS=" "
  DRY_LPM=0
  DRY_CLAUDE_RUN=""
  unplug="$DRY_T0"
  case "$scenario" in
    default) DRY_EVENTS=" 4:touched 10:adapter 12:lpm 17:claude 18:slept 20:locked " ;;
    low) DRY_CHARGE0=62 ;;
    late) unplug=$((DRY_T0 - 2 * 3600)) ;;
    *) fail "the dry runs are default, low and late" ;;
  esac
  mkdir -p "$LOGS" "$SECTIONS" "$SHOTS"
  ARM_PID=$$
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
  q_install() { if dry_event error; then return 1; fi; }
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
  q_sample() { echo "hid_idle_s=9999 locked=no lid=open thermal=nominal lowpower=$DRY_LPM"; }
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
      external=No locked=no idle=$((t - DRY_CLOCK + 400))
      if dry_event adapter && [ $((t - DRY_CLOCK)) -gt 100 ]; then external=Yes; fi
      if dry_event locked && [ $((t - DRY_CLOCK)) -gt 100 ]; then locked=yes; fi
      if dry_event touched && [ $((t - DRY_CLOCK)) -gt 100 ]; then idle=5; fi
      printf '%s\t1\t3000\t5000\t%s\t3000\t%s\t%s\topen\tno\t2\t10.00\n' "$t" "$external" "$idle" "$locked" >>"$LOGS/sampler.tsv"
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
  awk -F '\t' -v scenario="$1" -v late="$2" '
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
        if (scenario == "late" && start[i] >= late && status[i] !~ /late/) print "run " i " started after the deadline"
        if (status[i] ~ /late/ && start[i] < late) print "run " i " was late too early"
      }
      if (s[n - 1] != "S6" || b[n - 1] != "B" || s[n] != "S6" || b[n] != "C") print "S6 B C isn t last"
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
        for (i = 1; i <= n; i++) if (kind[i] == "run" && status[i] ~ /^not valid/) invalid++
        if (invalid < 5) print "the scripted detector events didn t all mark their runs (" invalid " not valid)"
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

B0a and B0b (on the adapter, he is there):
  answer --by person B-yes y (and B-bedtime, B-charge-capture, B-keep-widgets, B-keep-ax, B-slider-auth, B-usage)
  prepare [--fresh-backup]   the backup into ~/bp-062/B, the builds (B, C = the RC, CP), the tools, the RC; a beep
  prepare reads              the Charge Limit, the style keys, Open at login, the hot corners, the screen saver,
                             the wallpaper, the generated wallpapers, the shots Claude reads
  proof P1 --image <png> <x> <y> | P2 | P3 [1|2] | P4 | P6 | P7 | P8 | P9 | P11 | <P#> pass|fail <note>
  preflight                  the checks, P2 P6 P7 P8 P9 P11, and every command family once
  widget <family> <x> <y> <w> <h>; desktop-spot <x> <y> | --image <png> <x> <y>
  v01 notify [front]; f11 alert   the banners, before the Focus
  arm open                   the arm window (Terminal); it holds the display awake and waits
B1:
  burst                      3 unplug and plug cycles at cues, P12 at the first unplug (S8); then the Focus on,
                             then: mark away (no sound from here until his continue)
B2 (the GUI phase; heartbeat <step and expected ready time> after each step):
  memory [<24-hour label> <7-day label>]; v01 menubar | check; f6 <page>; f8 [ru on|ru|ru off];
  f9; relaunch; f11 login | listed; f12 rate | before | after; install C
  case <style>-<light|dark>-<main|compact> (and standard-light-main, frosted-light-main)
  styleshot <translucent|clear> <bright|busy> <light|dark> <overview|history|settings>
  gradshot <style> <light|dark> <raw|demo|history|fullscreen|settings|gallery> [--ready]
  audit estimate <style> <light|dark> <page>; v1b <x> <y> <w> <h>; pages [profiling]
  pane <$(echo "$PANES" | tr ' ' '|')>
  measure <id> black|blank|same|differs <arguments>; judge <id> <answer> [--unsure] [note]
  change <setting> <original> <new> (before any change by computer use); restored <setting> <how>
  ui <command...>            the hands (ui.swift's usage), through the script only
B3:
  restore gui                then the energy setup, answer --by claude energy-setup <1|2>, and last: ready
B4-B5 (the arm window, no session): his Return, password and unplug; the queue; restore night
B7 (on his continue):
  continue; v01 morning; morning; restore morning; batch; send [--dry-run] (after answer --by person B-send y)
The morning-away block and the extras: charge-limit check | record start | record stop; menu-bar-shots <tag> [...];
  wp18 previews | timing | icon <source.icon>
Any time: status, note, shot, crop, attach, unattach, help; queue --dry-run [default|low|late] anywhere.
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
if [ "$SESSION" = B ]; then
  # Once ready is up, or while the queue runs, nothing acts until his morning continue; every call
  # but these reads is the session's heartbeat.
  case "$COMMAND:${1:-}" in
    help:* | -h:* | --help:* | status:* | continue:* | queue:* | arm: | :) ;;
    *)
      b_fence
      mkdir -p "$WORK"
      touch "$HEARTBEAT"
      ;;
  esac
  case "$COMMAND" in
    widgets-ref | f5 | spike | voiceover | fill | attach-timing | window) fail "$COMMAND is a Session A command" ;;
  esac
fi
case "$COMMAND" in
  prepare) step_prepare "$@" ;;
  widgets-ref) step_widgets_ref ;;
  f5) step_f5 "$@" ;;
  spike) step_spike "$@" ;;
  voiceover) step_voiceover ;;
  v01) step_v01 "$@" ;;
  fill) step_fill "$@" ;;
  attach-timing) step_attach_timing ;;
  pages) step_pages "$@" ;;
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
  restore) step_restore ;;
  send) step_send "$@" ;;
  heartbeat) b_run step_heartbeat "$@" ;;
  change) b_run step_change "$@" ;;
  restored) b_run step_restored "$@" ;;
  ui) b_run step_ui "$@" ;;
  pane) b_run step_pane "$@" ;;
  widget) b_run step_widget "$@" ;;
  desktop-spot) b_run step_desktop_spot "$@" ;;
  queue)
    if [ "${1:-}" = --dry-run ]; then
      queue_dry_run "${2:-default}"
    else
      fail "the queue runs in the arm window ($SCRIPT arm open); queue --dry-run [default|low|late] checks its order anywhere"
    fi
    ;;
  *)
    step_help >&2
    exit 1
    ;;
esac
