#!/bin/bash
# BatteryPulse 0.6.2: M5 Session A (docs/plans/0.6.2/PLAN.md §6), one command per call. A Claude
# Code session on the Mac runs it as docs/plans/0.6.2/SESSION.md says; the person at the Mac only
# does what needs hands, eyes or ears, and starts the unattended window in Terminal, where sudo
# asks for the password once.
#
#   bash docs/plans/0.6.2/m5-session.sh help
#
# Everything lands in ~/bp-062/A: the builds (each in its DMG), the backup of your app, settings and
# data, screenshots, recordings, logs, the answers, and A.md, which `send` commits to
# docs/plans/0.6.2/sessions/A.md on the branch claude/062-session-a (never another branch, never a
# pull request). The builds stay in their DMGs and the backup in its zip, so the only
# BatteryPulse.app on the disk is the one in /Applications, and macOS can't pick up another copy's
# widget.
#
# Every install goes the way UpdateInstaller goes: a copy staged on the same volume, one atomic swap
# (swap.swift: renamex_np with RENAME_SWAP), lsregister -f, a relaunch. A build whose
# CFBundleVersion isn't higher than the installed one is refused (WidgetKit caches by it), except
# the reinstall of 0.6.1 and restore's reinstall of your own app (install_build).
#
# Wording (PLAN.md §3): every y/n question means "y = looks right"; everything else is a numbered
# choice. A step prints its questions as ASK lines and its hands-on tasks as DO lines; `answer`
# records the replies. The script reads the logs and counts the crash reports itself.
#
# It needs macOS 27, Xcode or the Command Line Tools, and the GitHub CLI (https://cli.github.com),
# signed in. No python or perl. Millisecond times come from zsh's zsh/datetime module.
set -euo pipefail

# MARK: - Builds and places

REPO="NikitaUsov/BatteryPulse"
INTEGRATION_BRANCH="claude/nice-faraday-k08mhb"
RESULTS_BRANCH="claude/062-session-a"

# The builds (PLAN.md §5 A2 and A2′, WP-W0, WP-21), each a CI artifact pinned to its run. Every CI
# build of a push has its run number as CFBundleVersion, so C (277) < I (278) < W (282) < A2 (285),
# and A (158) sits between B and the spikes; B is the published 0.6.1 (release run 7).
RUN_C="39800982102" # SPIKE-C, #277: 0.6.1's code, the control
ARTIFACT_C="BatteryPulse-76223738b61a8fc2a442115eb7fc93dba332eb73"
RUN_I="39801168615" # SPIKE-I, #278: 0.6.1 plus -internalize-at-link on the widget
ARTIFACT_I="BatteryPulse-dbf4dfa11a2fe4a87a38f2f74c44eaeb7a7fabd3"
RUN_W="39806441696" # SPIKE-W, #282 (a609487): the configurable kind, the Test kind, the feed, clicks
ARTIFACT_W="BatteryPulse-a60948765b7e7df33e3a8a5d43a71953d889b411"
RUN_A2="39808734092" # SPIKE-A2, #285 (cee5033): E20, the minimize fill switch, and a profiling DMG
ARTIFACT_A2="BatteryPulse-cee5033bae2f9e459332a5b22fa971aff2583765"
ARTIFACT_A2P="BatteryPulse-profiling-cee5033bae2f9e459332a5b22fa971aff2583765"
RUN_A="39413159534" # A: claude/baseline-0.6.0, #158 (076873d), the instrumented 0.6.0
ARTIFACT_A="BatteryPulse-076873d5bf151db628de91e216a8bfabb9356e1a"
TAG_B="v0.6.1" # B: the published 0.6.1 DMG

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
# BP_WORK only moves the folder for a dry run of the bookkeeping commands (help, answer, note,
# status, send --dry-run) on another machine.
WORK="${BP_WORK:-$HOME/bp-062/A}"
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

HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$HERE/../../.." && pwd)"
case "$HERE" in
  "$HOME"/*) SCRIPT="bash ~${HERE#"$HOME"}/m5-session.sh" ;;
  *) SCRIPT="bash $HERE/m5-session.sh" ;;
esac

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

launch() {
  open "$APP"
  local tries=0
  until app_running || [ "$tries" -ge 40 ]; do
    sleep 0.25
    tries=$((tries + 1))
  done
  app_running || warn "BatteryPulse didn't start within 10 s"
}

set_default() { defaults write "$BUNDLE_ID" "$1" "$2" "$3"; }

# The settings every step starts from (restore puts yours back): no update checks, the menu bar item
# with the icon and the charge, the Developer section (Raw Data, Demo Mode), the main window.
session_settings() {
  set_default updateFrequency -string never
  set_default showInMenuBar -bool true
  set_default showDeveloperSection -bool true
  set_default menuBarShowsIcon -bool true
  set_default menuBarShowsCharge -bool true
  set_default menuBarShowsPower -bool false
  set_default menuBarShowsTemperature -bool false
  set_default prefersCompactWindow -bool false
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
  codesign --verify --deep --strict "$staged" 2>/dev/null || fail "$name's code signature doesn't verify"
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
  [ $# -eq 1 ] || fail "usage: $SCRIPT install <C|I|W|B|A2|A2P|A|backup>"
  case "$1" in C | I | W | B | A2 | A2P | A | backup) ;; *) fail "no build $1" ;; esac
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
log_since() {
  log show --start "$1" --info --debug --style ndjson --predicate "$2" >"$3" 2>/dev/null || true
  grep -c '^{' "$3" || true
}

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
    /^\{/ {
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

# plist_count <file>: the number of elements of a property list or JSON array at its root.
plist_count() {
  local root index=0
  # The XML form's fourth line is the root element.
  root="$(plutil -convert xml1 -o - "$1" 2>/dev/null | sed -n 4p)"
  case "$root" in
    "<array/>") echo 0 ;;
    "<array>")
      while plutil -extract "$index" xml1 -o /dev/null "$1" >/dev/null 2>&1; do index=$((index + 1)); done
      echo "$index"
      ;;
    "") echo "unreadable" ;;
    *) echo "not a list" ;;
  esac
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
      pmset -g accps -xml >"$LOGS/f5-$state-pmset.xml" 2>&1 || true
      local bpulse_count="not built"
      if [ -x "$BIN/bpulse" ]; then
        "$BIN/bpulse" --accessories --raw >"$LOGS/f5-$state-bpulse-raw.plist" 2>"$LOGS/f5-$state-bpulse.err" || true
        "$BIN/bpulse" --accessories --json >"$LOGS/f5-$state-bpulse.json" 2>>"$LOGS/f5-$state-bpulse.err" || true
        bpulse_count="$(plist_count "$LOGS/f5-$state-bpulse.json")"
      fi
      out "| $state | $(plist_count "$LOGS/f5-$state-pmset.xml") | $bpulse_count |"
      echo "The captures are in $LOGS (f5-$state-*); they name your devices, so they stay on this Mac."
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
  awk -F '\t' 'FNR == NR { at[++n] = $1; label[n] = $3; next }
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
# second sound.
record_clip() {
  local movie="$1" seconds="$2" pid tries=0 limit
  rm -f "$movie"
  afplay /System/Library/Sounds/Glass.aiff &
  screencapture -v -V "$seconds" -x "$movie" &
  pid=$!
  limit=$((seconds * 2 + 10))
  while kill -0 "$pid" 2>/dev/null && [ "$tries" -lt "$limit" ]; do
    sleep 0.5
    tries=$((tries + 1))
  done
  kill -INT "$pid" 2>/dev/null || true
  sleep 1
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
  script -q /dev/null "$@" </dev/null 2>&1 | zsh -f "$BIN/stamp.zsh" >"$output" &
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
    open "$APP"
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
  awk -v plug="$plug_epoch" "$NOTIFY_KINDS"'
    FNR == NR {
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
  (step_send) || warn "send failed; run $SCRIPT send again"
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
  if [ ! -d "$BACKUP/support/Widget" ]; then rm -rf "$SUPPORT/Widget"; fi
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
| F13: UpdateTime changes against "any" lines | pslog and the ioreg sampler |
| E3b: timeremaining followed by "any" (battery and charging) | pslog and the ioreg sampler |
| E20 field run: traps, crash reports, read threads; memory over 2 hours | E20's field run |
| V-01: "executor" log lines, new crash reports, the answers | V-01; V01-* answers |
| mAh cadence: RemainingCapacity changes per hour | pslog and the ioreg sampler |
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

# MARK: - help

step_help() {
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
  status                     answers so far, the installed build, the battery
  restore                    your app, settings, data and system settings back, then what to do by hand
  send [--dry-run]           A.md to docs/plans/0.6.2/sessions/ on $RESULTS_BRANCH
EOF
}

COMMAND="${1:-}"
if [ $# -gt 0 ]; then shift; fi
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
  status) step_status ;;
  restore) step_restore ;;
  send) step_send "$@" ;;
  help | -h | --help) step_help ;;
  *)
    step_help >&2
    exit 1
    ;;
esac
