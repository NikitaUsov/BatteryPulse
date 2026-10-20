#!/bin/bash
# The 0.6.1 M5 session (PLAN.md §4b), one step per call, from ~/BatteryPulse on the release
# candidate:
#
#   bash docs/plans/0.6.1/m5-session.sh <step>
#
# Core:     prepare, v1, v2, v4, f8, f11, f12, then send
# Optional: v2-fill, f5, f9, burst, memory, energy, then send again
# Any time: restore (puts the installed 0.6.0 and your settings back)
#
# A is the baseline build (0.6.0 plus instrumentation, version 0.0.0), B the release candidate
# built as 0.5.99, FILL the candidate with Clear's plain fill. Everything lands in ~/bp-061:
# the builds, the backup of your app, settings and data, screenshots (shots/) and results.md.
#
# FIRST DRAFT (WP-0b): D1 fills in the four IDs below and finalizes the steps, so that no command
# needs a placeholder.
set -euo pipefail

PR="TBD"       # the D1 pull request
RUN_A="TBD"    # the CI run of claude/baseline-0.6.0
RUN_B="TBD"    # the 0.5.99 CI run of the release candidate
RUN_FILL="TBD" # the CI run of claude/061-ur-clearfill

REPO="NikitaUsov/BatteryPulse"
BUNDLE_ID="io.github.nikitausov.BatteryPulse"
APP="/Applications/BatteryPulse.app"
WORK="$HOME/bp-061"
BACKUP="$WORK/backup"
SHOTS="$WORK/shots"
RESULTS="$WORK/results.md"
SUPPORT="$HOME/Library/Application Support/$BUNDLE_ID"
CACHES="$HOME/Library/Caches/$BUNDLE_ID"
HTTP_STORAGE="$HOME/Library/HTTPStorages/$BUNDLE_ID"
PERF_PREDICATE="subsystem == \"$BUNDLE_ID\" AND category == \"perf\""

cd "$(dirname "$0")/../../.."

# MARK: - Helpers

fail() {
  echo "error: $*" >&2
  exit 1
}

need_ids() {
  local id
  for id in "$PR" "$RUN_A" "$RUN_B"; do
    [ "$id" != TBD ] || fail "D1 hasn't filled in the PR number and run IDs at the top of this script yet"
  done
}

record() { echo "$*" >>"$RESULTS"; }

appearance() {
  local dark=false
  if [ "$1" = dark ]; then dark=true; fi
  osascript -e "tell application \"System Events\" to tell appearance preferences to set dark mode to $dark"
}

# ask <id> <question>: y or n plus an optional note; "light" or "dark" switches the appearance
# and asks again. The answer goes into results.md.
ask() {
  local id="$1" question="$2" reply
  while true; do
    read -r -p "$question [y/n, note; light/dark] " reply
    case "$reply" in
      light | dark) appearance "$reply" ;;
      y | y\ * | n | n\ *) break ;;
      *) echo "  type y or n, then an optional note" ;;
    esac
  done
  record "- $id: $question → $reply"
}

# value <id> <question>: a free answer, such as a Digital Color Meter reading.
value() {
  local reply
  read -r -p "$2 " reply
  record "- $1: $2 → $reply"
}

pause() { read -r -p "$* (Return to go on) " _; }

quit_app() {
  osascript -e 'tell application "BatteryPulse" to quit' >/dev/null 2>&1 || true
  local tries=0
  while pgrep -x BatteryPulse >/dev/null && [ "$tries" -lt 20 ]; do
    sleep 0.5
    tries=$((tries + 1))
  done
  pkill -x BatteryPulse 2>/dev/null || true
}

# install_build <A|B|FILL|backup>: quits BatteryPulse and puts that build into /Applications.
install_build() {
  local source="$WORK/$1/BatteryPulse.app"
  if [ "$1" = backup ]; then source="$BACKUP/BatteryPulse.app"; fi
  [ -d "$source" ] || fail "$source is missing; run prepare first"
  quit_app
  rm -rf "$APP"
  ditto "$source" "$APP"
  echo "installed $1: $(defaults read "$APP/Contents/Info" CFBundleShortVersionString)"
}

launch() {
  open "$APP"
  local tries=0
  until pgrep -x BatteryPulse >/dev/null || [ "$tries" -ge 40 ]; do
    sleep 0.25
    tries=$((tries + 1))
  done
}

app_pid() { pgrep -x BatteryPulse | head -1; }

set_default() { defaults write "$BUNDLE_ID" "$1" "$2" "$3"; }

# download <A|B|FILL> <run id>: the run's DMG artifact, unpacked to ~/bp-061/<name>.
download() {
  local name="$1" run="$2" dmg mount
  rm -rf "${WORK:?}/$name"
  mkdir -p "$WORK/$name/artifact"
  gh run download "$run" -R "$REPO" -p 'BatteryPulse-*' -D "$WORK/$name/artifact"
  dmg="$(find "$WORK/$name/artifact" -name BatteryPulse.dmg | head -1)"
  [ -n "$dmg" ] || fail "run $run has no BatteryPulse.dmg"
  mount="$(mktemp -d)"
  hdiutil attach -quiet -nobrowse -readonly -mountpoint "$mount" "$dmg"
  ditto "$mount/BatteryPulse.app" "$WORK/$name/BatteryPulse.app"
  hdiutil detach -quiet "$mount"
  echo "$name: $(defaults read "$WORK/$name/BatteryPulse.app/Contents/Info" CFBundleShortVersionString) from run $run"
}

# The settings the session works with; each block ends by importing the backup again.
session_settings() {
  set_default updateFrequency -string never
  set_default menuBarShowsIcon -bool true
  set_default menuBarShowsCharge -bool true
  set_default menuBarShowsPower -bool false
}

restore_settings() {
  quit_app
  defaults import "$BUNDLE_ID" "$BACKUP/defaults.plist"
}

# perf_capture <file>: starts a log stream of the perf lines in the background; prints its PID.
perf_capture() {
  log stream --level debug --style ndjson --predicate "$PERF_PREDICATE" >"$1" 2>/dev/null &
  echo $!
}

# perf_stop <pid>: gives the stream a moment to write the last lines, then ends it like Control-C.
perf_stop() {
  sleep 2
  kill -INT "$1" 2>/dev/null || true
}

today_samples() {
  local file
  file="$SUPPORT/History/samples/$(date -u +%Y-%m-%d).jsonl"
  if [ -f "$file" ]; then wc -l <"$file" | tr -d ' '; else echo 0; fi
}

now_ms() { perl -MTime::HiRes=time -e 'printf "%d\n", time * 1000'; }

# MARK: - Core

step_prepare() {
  need_ids
  mkdir -p "$WORK" "$SHOTS" "$BACKUP"
  defaults write com.apple.screencapture location "$SHOTS"
  quit_app
  download A "$RUN_A"
  download B "$RUN_B"
  if [ "$RUN_FILL" != TBD ]; then download FILL "$RUN_FILL"; fi
  if [ ! -f "$BACKUP/defaults.plist" ]; then
    defaults export "$BUNDLE_ID" "$BACKUP/defaults.plist"
    if [ -d "$SUPPORT" ]; then ditto "$SUPPORT" "$BACKUP/support"; fi
    if [ -d "$APP" ]; then ditto "$APP" "$BACKUP/BatteryPulse.app"; fi
  fi
  # SEC-03 checks that the candidate writes no Cache.db, so the caches start empty.
  if [ -d "$CACHES" ]; then mv "$CACHES" "$BACKUP/caches-$(date +%s)"; fi
  install_build B
  session_settings
  {
    echo "# BatteryPulse 0.6.1 M5 session, $(date '+%Y-%m-%d %H:%M')"
    echo
    echo "- macOS: $(sw_vers -productVersion) ($(sw_vers -buildVersion))"
    echo "- cycle count: $(ioreg -r -c AppleSmartBattery | awk -F' = ' '/"CycleCount"/ { print $2; exit }')"
    echo "- kern.pervasive_energy: $(sysctl -n kern.pervasive_energy 2>/dev/null || echo unavailable)"
    echo "- charge: $(pmset -g batt | grep -o -E '[0-9]+%' | head -1)"
    echo
  } >"$RESULTS"
  perf_capture "$WORK/perf.ndjson" >"$WORK/perf.pid"
  launch
  echo "B is running. Next: bash docs/plans/0.6.1/m5-session.sh v1"
}

step_v1() {
  record "## V1, tile pickers (G10)"
  pause "Open Settings → General → Window Style, then Menu Bar → Icon Style"
  ask V1a "In Light and in Dark: does the selected tile have an accent outline and no glass?"
  ask V1b "Does one point of the Clear tile's sky read the same unselected and selected?"
  ask V1c "Are the disabled Icon Style tiles dimmed?"
  ask V1d "Next to the system battery item, does the menu bar icon look right in both appearances?"
  ask G10 "Sign off the tile pickers?"
}

clear_check() {
  local label="$1"
  set_default windowLook -string clear
  quit_app
  launch
  open -a TextEdit
  osascript -e 'tell application "TextEdit" to make new document' >/dev/null
  pause "Put the main window over the blank TextEdit page"
  appearance light
  value "$label-light" "Light: Digital Color Meter in a gap between groups (about 94)?"
  appearance dark
  value "$label-dark" "Dark: the same reading?"
  ask "$label-text" "Is the text readable in both? (Then glance at it over a busy desktop.)"
}

step_v2() {
  record "## V2, Clear (G11)"
  clear_check V2
  ask G11 "Sign off Clear?"
  restore_settings
  session_settings
  launch
}

step_v2_fill() {
  [ -d "$WORK/FILL/BatteryPulse.app" ] || fail "no FILL build; D1 sets RUN_FILL"
  record "## V2 on the plain fill"
  install_build FILL
  session_settings
  clear_check V2-fill
  ask G11-fill "Sign off the plain fill?"
  restore_settings
  install_build B
  session_settings
  launch
}

step_v4() {
  record "## V4, chart readout and minimizing (G12, UR-3)"
  local look
  for look in standard frosted translucent clear; do
    set_default windowLook -string "$look"
    quit_app
    launch
    pause "Window Style is $look. Open the main window"
    ask "UR-3-$look" "$look: minimize and restore with Shift held. No black frame?"
    pause "History → 24 h, pointer over a chart: take a screenshot in Light, then type dark and take one in Dark"
    ask "V4-$look" "$look: is the readout readable?"
  done
  ask V4-materials "Are Frosted's and Translucent's sidebar and toolbar acceptable?"
  ask G12 "Approve the four styles?"
  restore_settings
  session_settings
  launch
}

step_f8() {
  record "## F8, widget (G3)"
  pause "Add the BatteryPulse widget to the desktop"
  ask F8 "Does the widget show the charge?"
  local plugin
  plugin="$(pluginkit -mv -i "$BUNDLE_ID.Widget" 2>&1 || true)"
  record "- F8 pluginkit: $plugin"
  case "$plugin" in
    *"$APP"*) echo "pluginkit: the widget runs from /Applications" ;;
    *) echo "pluginkit doesn't show the /Applications path: $plugin" ;;
  esac
}

step_f11() {
  record "## F6, pages"
  pause "Open every page: Overview, Power, History (24 h, 7 d), Health, Raw Data, Demo Mode"
  ask F6-history "Does History show the last days of 0.6.0 data in 24 h and 7 d?"
  ask F6-raw "Raw Data: does typing \"volt\", clearing it and opening the inspector work?"
  ask F6-demo "Demo Mode, played 20 s: does the menu bar icon follow, with no notification?"
  ask F6 "Do all pages show sensible values?"

  record "## F11, relaunch, alerts, login item"
  set_default menuBarShowsPower -bool true
  quit_app
  local before after
  before="$(today_samples)"
  launch
  echo "waiting 30 s for the launch sample..."
  sleep 30
  after="$(today_samples)"
  record "- F11 launch sample: $before → $after lines (expected exactly one more)"
  echo "samples today: $before → $after"
  pause "Close every window"
  ask F11-power "With every window closed, does the power value keep changing?"
  ask F11-settings "Are your settings all there, and the icon style unchanged?"
  pause "Settings frontmost: set \"When charged to\" below the current charge, then plug in"
  ask F11-alert "Did a notification arrive within about 10 s, and does clicking it bring BatteryPulse forward?"
  pause "Turn on Open at login (approve it in System Settings if asked)"
  record "- F11 login item: $(sfltool dumpbtm 2>/dev/null | grep -i -A3 batterypulse | tr '\n' ' ' || true)"
  ask F11-login "Is it listed above, and is it off again after you turn it off?"
  restore_settings
  session_settings
  launch
}

step_f12() {
  record "## F12, update window and installer (G22)"
  pause "Choose Check for Updates"
  ask F12-window "Does the window offer 0.6.0, with rendered notes and a link that opens in the browser?"
  local caches
  caches="$(find "$CACHES" "$HTTP_STORAGE" -name 'Cache.db*' 2>/dev/null | wc -l | tr -d ' ')"
  record "- F12 Cache.db files: $caches (expected 0)"
  pause "Select a sentence in the notes, then choose Install and Relaunch; close What's New when it opens"
  ask F12-selection "Did the selection survive the download?"
  local version
  version="$(defaults read "$APP/Contents/Info" CFBundleShortVersionString)"
  record "- F12 installed version: $version (expected 0.6.0)"
  ask G22 "Did 0.6.0 install and relaunch?"
  # Your settings come back; the History written meanwhile stays (same format, real samples).
  restore_settings
  launch
  echo "Results: $RESULTS. Next: bash docs/plans/0.6.1/m5-session.sh send"
}

step_send() {
  need_ids
  gh api -X POST "repos/$REPO/issues/$PR/comments" -F "body=@$RESULTS" --jq .html_url
  echo "Now drag $SHOTS into that comment."
}

# MARK: - Optional

step_f5() {
  record "## F5, devices and accessories"
  install_build B
  session_settings
  set_default readDevices -bool true
  launch
  pause "Connect an iPhone or iPad, and AirPods if you have them"
  ask F5 "Do the device page and Accessories show values, with the earbuds named after the buds?"
  restore_settings
  install_build backup
}

step_f9() {
  record "## F9, Russian"
  install_build B
  session_settings
  quit_app
  open "$APP" --args -AppleLanguages '(ru)'
  ask F9 "In Russian, do Overview and Settings look right?"
  restore_settings
  install_build backup
}

# One perf log per build; prints reads per notify burst and widget reloads.
step_burst() {
  record "## Burst (S8)"
  local build capture pid
  for build in A B; do
    install_build "$build"
    session_settings
    capture="$WORK/burst-$build.ndjson"
    pid="$(perf_capture "$capture")"
    launch
    sleep 10
    local cycle
    for cycle in 1 2 3; do
      pause "$build, cycle $cycle: unplug"
      sleep 30
      pause "$build, cycle $cycle: plug in"
      sleep 30
    done
    perf_stop "$pid"
    record "### $build"
    record '```'
    swift scripts/perf-stats.swift "$capture" | tee -a "$RESULTS"
    record '```'
  done
  restore_settings
  install_build backup
}

# phys_footprint before and after three History 7 d cycles, and history.load cold and warm.
step_memory() {
  record "## Memory"
  local build capture pid
  for build in A B; do
    install_build "$build"
    session_settings
    capture="$WORK/memory-$build.ndjson"
    pid="$(perf_capture "$capture")"
    launch
    sleep 20
    record "- $build before: $(swift scripts/rusage.swift "$(app_pid)" 1 | grep phys_footprint)"
    local cycle
    for cycle in 1 2 3; do
      pause "$build, cycle $cycle: open the main window, choose History → 7 d, then close the window"
    done
    sleep 10
    record "- $build after: $(swift scripts/rusage.swift "$(app_pid)" 1 | grep phys_footprint)"
    perf_stop "$pid"
    record '```'
    swift scripts/perf-stats.swift "$capture" | grep -E '^(name|history\.load)' | tee -a "$RESULTS"
    record '```'
  done
  restore_settings
  install_build backup
}

# S2 (power in the menu bar, no window) for 1 + 4 minutes per build, then S7: 5 cold launches
# per build from open to the menuBarReady line.
step_energy() {
  record "## Energy (S2, S7)"
  pause "Unplug the Mac, then leave it alone for about 15 minutes"
  caffeinate -d &
  local awake=$!
  local build
  for build in A B; do
    install_build "$build"
    session_settings
    set_default menuBarShowsPower -bool true
    launch
    sleep 60
    record "### S2 $build"
    record '```'
    swift scripts/rusage.swift "$(app_pid)" 240 | tee -a "$RESULTS"
    record '```'
  done
  for build in A B; do
    install_build "$build"
    session_settings
    local capture="$WORK/launch-$build.ndjson" launch_number pid start
    : >"$capture"
    pid="$(perf_capture "$capture")"
    sleep 2
    for launch_number in 1 2 3 4 5; do
      quit_app
      sleep 3
      start="$(now_ms)"
      local ready_before
      ready_before="$(grep -c menuBarReady "$capture" || true)"
      open "$APP"
      # DRAFT: assumes log stream writes each line as it comes; D1 confirms it on the M5.
      local waited=0
      until [ "$(grep -c menuBarReady "$capture" || true)" -gt "$ready_before" ] || [ "$waited" -ge 600 ]; do
        sleep 0.05
        waited=$((waited + 1))
      done
      record "- S7 $build launch $launch_number: $(($(now_ms) - start)) ms to menuBarReady"
    done
    perf_stop "$pid"
    record '```'
    swift scripts/perf-stats.swift "$capture" | sed -n '/^processes/,$p' | tee -a "$RESULTS"
    record '```'
  done
  kill "$awake" 2>/dev/null || true
  restore_settings
  install_build backup
}

# MARK: - Restore

step_restore() {
  [ -f "$BACKUP/defaults.plist" ] || fail "no backup in $BACKUP"
  if [ -f "$WORK/perf.pid" ]; then
    kill "$(cat "$WORK/perf.pid")" 2>/dev/null || true
    rm -f "$WORK/perf.pid"
  fi
  install_build backup
  restore_settings
  defaults delete com.apple.screencapture location 2>/dev/null || true
  launch
  echo "0.6.0 and your settings are back."
}

case "${1:-}" in
  prepare) step_prepare ;;
  v1) step_v1 ;;
  v2) step_v2 ;;
  v2-fill) step_v2_fill ;;
  v4) step_v4 ;;
  f8) step_f8 ;;
  f11) step_f11 ;;
  f12) step_f12 ;;
  send) step_send ;;
  f5) step_f5 ;;
  f9) step_f9 ;;
  burst) step_burst ;;
  memory) step_memory ;;
  energy) step_energy ;;
  restore) step_restore ;;
  *)
    echo "usage: bash docs/plans/0.6.1/m5-session.sh <step>" >&2
    echo "  core: prepare v1 v2 v4 f8 f11 f12 send; optional: v2-fill f5 f9 burst memory energy; restore" >&2
    exit 1
    ;;
esac
