#!/bin/bash
# The 0.6.1 M5 session (PLAN.md §4b), one step per call, from ~/BatteryPulse on the release
# candidate:
#
#   bash docs/plans/0.6.1/m5-session.sh <step>
#
# Core:     prepare, v1, v2, v4, f8, f11, f12, then send
# Optional: v2-fill, f5, f9, burst, memory, energy, then send again
# Any time: restore (puts back your 0.6.0, your settings, the appearance and the screenshot folder)
#
# A is the baseline build (0.6.0 plus instrumentation, version 0.0.0), B the release candidate
# built as 0.5.99, FILL the candidate with Clear's plain fill. Everything lands in ~/bp-061: the
# builds (as DMGs), the backup of your app (a zip), settings and data, the screenshots (shots/),
# the perf logs and results.md. The builds stay in their DMGs and your app in its zip, so the only
# BatteryPulse.app on the disk is the one in /Applications, and macOS can't pick up another copy's
# widget.
#
# It needs what macOS 27 ships, the Command Line Tools (which git needs too) and the GitHub CLI,
# signed in; prepare checks both and says what to do. No perl or python. Millisecond times come
# from zsh's zsh/datetime module (part of macOS) and from the log's own timestamps.
#
# The orchestrator fills in the four IDs below in D1, so that no command needs a placeholder;
# until then prepare and send stop with a message.
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
BIN="$WORK/bin"
RESULTS="$WORK/results.md"
SUPPORT="$HOME/Library/Application Support/$BUNDLE_ID"
CACHES="$HOME/Library/Caches/$BUNDLE_ID"
HTTP_STORAGE="$HOME/Library/HTTPStorages/$BUNDLE_ID"
PERF_PREDICATE="subsystem == \"$BUNDLE_ID\" AND category == \"perf\""
SCRIPT="bash docs/plans/0.6.1/m5-session.sh"
# Where the GitHub CLI lands when installed with Homebrew or from cli.github.com, in case the
# shell's PATH doesn't name it.
PATH="$PATH:/opt/homebrew/bin:/usr/local/bin"

cd "$(dirname "$0")/../../.."

# MARK: - Helpers

fail() {
  echo "error: $*" >&2
  exit 1
}

need_ids() {
  local id
  for id in "$PR" "$RUN_A" "$RUN_B"; do
    if [ "$id" = TBD ]; then
      fail "the PR number and CI run IDs at the top of this script aren't filled in yet; fetch the branch again"
    fi
  done
}

record() { echo "$*" >>"$RESULTS"; }

# appearance <light|dark>: switches the system appearance through System Events (macOS asks once
# whether Terminal may control it); if that fails, you switch it by hand.
appearance() {
  local dark=false
  if [ "$1" = dark ]; then dark=true; fi
  if ! osascript -e "tell application \"System Events\" to tell appearance preferences to set dark mode to $dark" \
    >/dev/null 2>&1; then
    read -r -p "Switch to the $1 appearance in System Settings → Appearance, then press Return. " _
  fi
}

# ask <id> <question>: y or n plus an optional note; "light" or "dark" switches the appearance
# and asks again. The answer goes into results.md.
ask() {
  local id="$1" question="$2" reply
  while true; do
    read -r -p "$question [y/n, note; light/dark] " reply
    case "$reply" in
      light | dark) appearance "$reply" ;;
      [yYnN] | [yYnN]\ *) break ;;
      *) echo "  type y or n, then an optional note" ;;
    esac
  done
  record "- $id: $question → $reply"
}

# value <id> <question>: a free answer, such as a Digital Color Meter reading; also left in VALUE.
VALUE=""
value() {
  read -r -p "$2 " VALUE
  record "- $1: $2 → $VALUE"
}

pause() { read -r -p "$* (Return to go on) " _; }

app_running() { pgrep -x BatteryPulse >/dev/null; }

app_pid() { pgrep -x BatteryPulse | head -1 || true; }

# The installed version, read from the file: `defaults read` can answer from a cache after the
# app was replaced.
app_version() {
  plutil -extract CFBundleShortVersionString raw -o - "$APP/Contents/Info.plist" 2>/dev/null || echo none
}

on_battery() {
  case "$(pmset -g batt)" in
    *"'Battery Power'"*) return 0 ;;
    *) return 1 ;;
  esac
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
  app_running || echo "warning: BatteryPulse didn't start within 10 s" >&2
}

set_default() { defaults write "$BUNDLE_ID" "$1" "$2" "$3"; }

# MARK: - Builds

dmg_of() { echo "$WORK/$1/BatteryPulse.dmg"; }

# mount_dmg <dmg>: mounts it read-only, out of Finder's sight, at a new folder in MOUNT. hdiutil
# attach and detach print a deprecation notice on macOS 27 and work.
MOUNT=""
mount_dmg() {
  MOUNT="$(mktemp -d "${TMPDIR:-/tmp}/bp-061-mount.XXXXXX")"
  hdiutil attach -quiet -nobrowse -readonly -mountpoint "$MOUNT" "$1" || fail "can't mount $1"
}

unmount_dmg() {
  hdiutil detach -quiet "$MOUNT" || hdiutil detach -quiet -force "$MOUNT" || true
  rmdir "$MOUNT" 2>/dev/null || true
}

# download <A|B|FILL> <run id>: the run's DMG artifact (not its dSYMs) to ~/bp-061/<name>, with a
# line about it in ~/bp-061/builds.txt.
download() {
  local name="$1" run="$2" artifact dmg version
  artifact="$(gh api "repos/$REPO/actions/runs/$run/artifacts" --jq '[.artifacts[]
    | select((.name | startswith("BatteryPulse-")) and (.name | contains("dSYMs") | not))]
    | first | if . == null then "" elif .expired then "expired" else .name end')" ||
    fail "can't list the artifacts of run $run"
  case "$artifact" in
    "") fail "run $run has no BatteryPulse DMG" ;;
    expired) fail "the DMG of run $run has expired; ask for a new run" ;;
  esac
  rm -rf "${WORK:?}/$name"
  mkdir -p "$WORK/$name/artifact"
  gh run download "$run" -R "$REPO" -n "$artifact" -D "$WORK/$name/artifact"
  dmg="$(find "$WORK/$name/artifact" -name BatteryPulse.dmg | head -1)"
  [ -n "$dmg" ] || fail "the artifact $artifact of run $run has no BatteryPulse.dmg"
  mv "$dmg" "$(dmg_of "$name")"
  rm -rf "$WORK/$name/artifact"
  mount_dmg "$(dmg_of "$name")"
  version="$(plutil -extract CFBundleShortVersionString raw -o - "$MOUNT/BatteryPulse.app/Contents/Info.plist" ||
    echo unknown)"
  unmount_dmg
  echo "$name: $version, run $run ($artifact)" | tee -a "$WORK/builds.txt"
}

# install_build <A|B|FILL|backup>: quits BatteryPulse and puts that build into /Applications.
install_build() {
  quit_app
  case "$1" in
    backup)
      [ -f "$BACKUP/BatteryPulse.zip" ] || fail "no backup of your app in $BACKUP; run prepare first"
      rm -rf "$APP"
      ditto -x -k "$BACKUP/BatteryPulse.zip" /Applications
      ;;
    *)
      [ -f "$(dmg_of "$1")" ] || fail "build $1 is missing; run prepare first"
      mount_dmg "$(dmg_of "$1")"
      rm -rf "$APP"
      ditto "$MOUNT/BatteryPulse.app" "$APP"
      unmount_dmg
      ;;
  esac
  echo "installed $1: $(app_version)"
}

# The helper tools, built once by prepare so that they start at once (rusage's window then
# starts when it is called).
build_tools() {
  mkdir -p "$BIN"
  local tool
  for tool in perf-stats rusage; do
    echo "building scripts/$tool.swift..."
    xcrun swiftc -O "scripts/$tool.swift" -o "$BIN/$tool" 2>"$BIN/$tool.log" ||
      fail "can't build scripts/$tool.swift; see $BIN/$tool.log"
  done
}

perf_stats() {
  if [ -x "$BIN/perf-stats" ]; then "$BIN/perf-stats" "$@"; else xcrun swift scripts/perf-stats.swift "$@"; fi
}

rusage() {
  if [ -x "$BIN/rusage" ]; then "$BIN/rusage" "$@"; else xcrun swift scripts/rusage.swift "$@"; fi
}

# MARK: - Settings

# The settings the session works with; each block ends by putting yours back. The menu bar shows
# the icon and the charge only, and Open BatteryPulse opens the main window, whatever yours say.
session_settings() {
  set_default updateFrequency -string never
  set_default menuBarShowsIcon -bool true
  set_default menuBarShowsCharge -bool true
  set_default menuBarShowsPower -bool false
  set_default menuBarShowsTemperature -bool false
  set_default prefersCompactWindow -bool false
}

# Your settings exactly as they were. `defaults import` adds to the keys a domain has (a key the
# session wrote and the backup lacks would stay), so the domain is deleted first.
restore_settings() {
  quit_app
  defaults delete "$BUNDLE_ID" 2>/dev/null || true
  defaults import "$BUNDLE_ID" "$BACKUP/defaults.plist"
}

# The end of every optional block: your 0.6.0 and your settings, running.
back_to_060() {
  restore_settings
  install_build backup
  launch
}

# The appearance and the screenshot folder as they were before prepare.
restore_system() {
  case "$(cat "$BACKUP/dark-mode" 2>/dev/null || echo unknown)" in
    true) appearance dark ;;
    false) appearance light ;;
  esac
  if [ "$(cat "$BACKUP/auto-appearance" 2>/dev/null || echo 0)" = 1 ]; then
    echo "Set Appearance back to Auto in System Settings → Appearance."
  fi
  if [ -f "$BACKUP/screenshot-location" ]; then
    defaults write com.apple.screencapture location "$(cat "$BACKUP/screenshot-location")"
  else
    defaults delete com.apple.screencapture location 2>/dev/null || true
  fi
}

# MARK: - Perf logs and times

# The log streams this call started, ended on exit (also after Control-C). prepare's stream runs
# on after it and is ended by f12 or restore through ~/bp-061/perf.pid.
STREAMS=""
STREAM=""
cleanup() {
  local pid
  for pid in $STREAMS; do
    kill -INT "$pid" 2>/dev/null || true
  done
}
trap cleanup EXIT
trap 'exit 130' INT TERM

# perf_capture <file>: starts `log stream` of the perf lines into the file, in the background, and
# sets STREAM to its PID. On the macOS 27 runner each line reached the file 10-20 ms after it was
# logged, so a step can wait for a line; the file's first line is log's "Filtering..." header,
# which perf-stats skips.
perf_capture() {
  log stream --level debug --style ndjson --predicate "$PERF_PREDICATE" >"$1" 2>"$1.err" </dev/null &
  STREAM=$!
  STREAMS="$STREAMS $STREAM"
  # The stream needs a moment before it passes lines on.
  sleep 2
}

# perf_stop <pid>: gives the last lines a moment, then ends the stream the way Control-C does:
# log ends within 100 ms of SIGINT with every line written, also as a background job (checked on
# the runner). SIGTERM only if it still runs 3 s later, since SIGTERM can drop a line that is
# still on its way.
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

# The stream prepare started, if it still runs.
stop_session_stream() {
  if [ -f "$WORK/perf.pid" ]; then
    perf_stop "$(cat "$WORK/perf.pid")"
    rm -f "$WORK/perf.pid"
  fi
}

# summarize <capture> [<filter>]: perf-stats' summary into results.md and on the screen,
# optionally only the lines that match an extended regular expression.
summarize() {
  local summary
  summary="$(perf_stats "$1" 2>&1)" || summary="(no perf lines in $1: $summary)"
  if [ $# -ge 2 ]; then summary="$(grep -E "$2" <<<"$summary" || true)"; fi
  record '```'
  record "$summary"
  record '```'
  echo "$summary"
}

# now_ms: milliseconds since 1970, from zsh's zsh/datetime module (part of macOS). Should zsh ever
# fail, whole seconds: a time measured with them would be off by up to a second.
now_ms() {
  zsh -fc 'zmodload zsh/datetime && print -r -- $(( epochtime[1] * 1000 + epochtime[2] / 1000000 ))' 2>/dev/null ||
    echo $(($(date +%s) * 1000))
}

# stamp_ms <timestamp>: a timestamp in log's format, such as 2026-10-20 19:35:07.736961+0300, in
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

# ready_after <capture> <ms>: the milliseconds from <ms> to the first menuBarReady logged after
# it, from the line's own timestamp, so the wait for the line doesn't count; "-" if none.
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

ready_count() { grep -c -F 'perf event menuBarReady' "$1" || true; }

today_samples() {
  local file
  file="$SUPPORT/History/samples/$(date -u +%Y-%m-%d).jsonl"
  if [ -f "$file" ]; then wc -l <"$file" | tr -d ' '; else echo 0; fi
}

# MARK: - prepare

# Stops, with what to do, unless the Command Line Tools and a signed-in GitHub CLI are there.
check_tools() {
  if ! xcode-select -p >/dev/null 2>&1; then
    echo "The Command Line Tools are missing; git and swiftc need them. Install them with" >&2
    echo "  xcode-select --install" >&2
    echo "then run $SCRIPT prepare again." >&2
    exit 1
  fi
  if ! command -v gh >/dev/null 2>&1; then
    echo "The GitHub CLI (gh) is missing. Install it" >&2
    if command -v brew >/dev/null 2>&1; then
      echo "  with Homebrew:  brew install gh" >&2
      echo "  or with the macOS installer from https://cli.github.com" >&2
    else
      echo "  with the macOS installer from https://cli.github.com" >&2
    fi
    echo "then sign in with" >&2
    echo "  gh auth login" >&2
    echo "(GitHub.com, HTTPS, Login with a web browser) and run $SCRIPT prepare again." >&2
    exit 1
  fi
  if ! gh auth status -h github.com >/dev/null 2>&1; then
    echo "The GitHub CLI isn't signed in. Sign in with" >&2
    echo "  gh auth login" >&2
    echo "(GitHub.com, HTTPS, Login with a web browser) and run $SCRIPT prepare again." >&2
    exit 1
  fi
}

# Your app, settings, data, appearance and screenshot folder, once: a second prepare keeps the
# first backup, which is the one from before the session.
backup_once() {
  if [ -f "$BACKUP/defaults.plist" ]; then
    echo "keeping the backup from the first prepare in $BACKUP"
    return 0
  fi
  [ -d "$APP" ] || fail "$APP is missing: install 0.6.0 first, so the session has your app to come back to"
  ditto -c -k --keepParent "$APP" "$BACKUP/BatteryPulse.zip"
  app_version >"$BACKUP/version"
  # An absent domain exports as an empty one.
  defaults export "$BUNDLE_ID" "$BACKUP/defaults.plist"
  if [ -d "$SUPPORT" ]; then ditto "$SUPPORT" "$BACKUP/support"; fi
  osascript -e 'tell application "System Events" to tell appearance preferences to get dark mode' \
    >"$BACKUP/dark-mode" 2>/dev/null || echo unknown >"$BACKUP/dark-mode"
  defaults read -g AppleInterfaceStyleSwitchesAutomatically >"$BACKUP/auto-appearance" 2>/dev/null ||
    echo 0 >"$BACKUP/auto-appearance"
  defaults read com.apple.screencapture location >"$BACKUP/screenshot-location" 2>/dev/null ||
    rm -f "$BACKUP/screenshot-location"
  echo "backed up $(cat "$BACKUP/version"), your settings and data to $BACKUP"
}

step_prepare() {
  need_ids
  check_tools
  mkdir -p "$WORK" "$SHOTS" "$BACKUP"
  echo "macOS may ask whether Terminal may control BatteryPulse, System Events and TextEdit: allow each."
  quit_app
  rm -f "$WORK/builds.txt"
  download A "$RUN_A"
  download B "$RUN_B"
  if [ "$RUN_FILL" != TBD ]; then download FILL "$RUN_FILL"; fi
  build_tools
  backup_once
  defaults write com.apple.screencapture location "$SHOTS"
  # SEC-03: f12 checks that the candidate writes no HTTP cache, so its caches folder starts empty
  # and f12 looks only at files written after this marker.
  if [ -d "$CACHES" ]; then mv "$CACHES" "$BACKUP/caches-$(date +%Y%m%d-%H%M%S)"; fi
  touch "$WORK/prepare.marker"
  install_build B
  session_settings
  if [ -s "$RESULTS" ]; then
    mv "$RESULTS" "$WORK/results-$(date +%Y%m%d-%H%M%S).md"
    echo "kept the earlier results.md beside it"
  fi
  {
    echo "# BatteryPulse 0.6.1 M5 session, $(date '+%Y-%m-%d %H:%M %z')"
    echo
    echo "- repository: $(git rev-parse --short HEAD 2>/dev/null || echo unknown)"
    sed 's/^/- build /' "$WORK/builds.txt"
    echo "- your app: $(cat "$BACKUP/version")"
    echo "- macOS: $(sw_vers -productVersion) ($(sw_vers -buildVersion))"
    echo "- cycle count: $(ioreg -r -c AppleSmartBattery | awk -F' = ' '$1 ~ /"CycleCount"$/ { print $2; exit }')"
    echo "- kern.pervasive_energy: $(sysctl -n kern.pervasive_energy 2>/dev/null || echo unavailable)"
    echo "- charge: $(pmset -g batt | grep -o -E '[0-9]+%' | head -1), $(pmset -g batt | head -1 | sed "s/.*'\(.*\)'.*/\1/")"
    echo "- Low Power Mode: $(pmset -g | awk '$1 == "lowpowermode" { found = 1; print $2 } END { if (!found) print "unknown" }')"
  } >"$RESULTS"
  if ! on_battery; then echo "note: the session starts unplugged (PLAN.md §4b); unplug the Mac now."; fi
  # The perf lines of the whole core session (B), summarized by f12.
  stop_session_stream
  perf_capture "$WORK/perf.ndjson"
  echo "$STREAM" >"$WORK/perf.pid"
  STREAMS=""
  launch
  local waited=0
  until [ "$(ready_count "$WORK/perf.ndjson")" -gt 0 ] || [ "$waited" -ge 40 ]; do
    sleep 0.5
    waited=$((waited + 1))
  done
  if [ "$(ready_count "$WORK/perf.ndjson")" -gt 0 ]; then
    record "- perf log: B's launch lines arrived, menuBarReady included"
  else
    record "- perf log: no menuBarReady line 20 s after B's launch"
    echo "warning: the perf log shows no menuBarReady line yet; the read and launch figures may be missing" >&2
  fi
  echo
  echo "B is running. Next: $SCRIPT v1"
}

# MARK: - Core

step_v1() {
  record "## V1, tile pickers (G10)"
  pause "Open Settings → General → Window Style, then Menu Bar → Icon Style"
  ask V1a "In Light and in Dark: does the selected tile have an accent outline and no glass?"
  ask V1b "In Digital Color Meter, does one point of the Clear tile's sky read the same unselected and selected?"
  ask V1c "Are the disabled Icon Style tiles dimmed?"
  ask V1d "Next to the system battery item, does the menu bar icon look right in both appearances?"
  ask G10 "Sign off the tile pickers?"
}

# clear_check <label>: Clear over a blank TextEdit page, read in Light and Dark. Leaves the
# appearances whose reading is above about 104 (G11) in HIGH.
HIGH=""
clear_check() {
  local label="$1" mode reading
  HIGH=""
  quit_app
  set_default windowLook -string clear
  launch
  open -a TextEdit
  osascript -e 'tell application "TextEdit" to make new document' >/dev/null 2>&1 || true
  pause "Open BatteryPulse's main window and put it over the blank TextEdit page"
  for mode in light dark; do
    appearance "$mode"
    value "$label-$mode" "$mode: Digital Color Meter in a gap between groups (expected about 94)?"
    # The leading number, so "110", "110/255" and "110 note" all count.
    reading="${VALUE%%[!0-9]*}"
    case "$reading" in
      "" | *[!0-9]*) ;;
      *) if [ "$reading" -gt 104 ]; then HIGH="$HIGH $mode"; fi ;;
    esac
  done
  ask "$label-text" "Is the text readable in both? (Then glance at it over a busy part of the desktop.)"
}

step_v2() {
  record "## V2, Clear (G11)"
  clear_check V2
  if [ -n "$HIGH" ]; then
    record "- V2: above about 104 in$HIGH, so D3 merges the plain fill (G11)"
    echo "A reading above about 104 ($HIGH): run $SCRIPT v2-fill after this step (5 min)."
  fi
  ask G11 "Sign off Clear?"
  restore_settings
  session_settings
  launch
}

step_v2_fill() {
  [ -f "$(dmg_of FILL)" ] || fail "no FILL build: RUN_FILL isn't filled in, or prepare ran before it was"
  record "## V2 on the plain fill (G11)"
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
  record "## V4, minimizing and the chart readout (UR-3, G12)"
  local look mode shots_before shots_after
  shots_before="$(find "$SHOTS" -type f | wc -l | tr -d ' ')"
  for look in standard frosted translucent clear; do
    quit_app
    set_default windowLook -string "$look"
    launch
    for mode in light dark; do
      appearance "$mode"
      pause "Window Style $look, $mode: open the main window"
      ask "UR-3-$look-$mode" "Shift-click the yellow button (the slow minimize), then Shift-click the window in the Dock. Did a black frame appear, minimizing or restoring? (n: none; else say which)"
      pause "History → 24 h, the pointer over a chart: ⇧⌘4, Space, click the window"
      ask "V4-$look-$mode" "Is the chart readout readable?"
    done
  done
  # UR-3 covers the compact window too, in each style and appearance (WP-UR's acceptance).
  for look in standard frosted translucent clear; do
    quit_app
    set_default windowLook -string "$look"
    set_default prefersCompactWindow -bool true
    launch
    for mode in light dark; do
      appearance "$mode"
      pause "Window Style $look, $mode: open the compact window (Open BatteryPulse in the menu bar panel)"
      ask "UR-3-compact-$look-$mode" "Shift-minimize the compact window, then Shift-click it in the Dock. Did a black frame appear? (n: none; else say which)"
    done
  done
  ask V4-materials "Are Frosted's and Translucent's sidebar and toolbar acceptable?"
  ask G12 "Approve the four styles?"
  shots_after="$(find "$SHOTS" -type f | wc -l | tr -d ' ')"
  record "- V4 screenshots: $((shots_after - shots_before)) new in shots/ (expected 8)"
  if [ "$shots_after" -le "$shots_before" ]; then
    echo "No new screenshots in $SHOTS: look on the Desktop and move them there."
  fi
  restore_settings
  session_settings
  launch
}

step_f8() {
  record "## F8, widget (G3)"
  pause "Add the BatteryPulse widget to the desktop (right-click the desktop → Edit Widgets)"
  ask F8 "Does the widget show the charge?"
  local plugin
  plugin="$(pluginkit -mv -i "$BUNDLE_ID.Widget" 2>&1 || true)"
  case "$plugin" in
    *"$APP"*) record "- F8 pluginkit: the widget runs from /Applications ($plugin)" ;;
    *) record "- F8 pluginkit: NOT from /Applications: $plugin" ;;
  esac
  tail -1 "$RESULTS"
}

# The login items as macOS keeps them. sfltool needs root: run as you, it waits for an
# authorization that never comes (on the runner it never returned), so it runs through sudo, and
# is given 60 s.
login_items() {
  echo "sfltool reads the login items as root; sudo asks for your password." >&2
  if ! sudo -v; then
    echo "(sfltool skipped: no sudo)"
    return 0
  fi
  # The file is yours; only sfltool runs as root.
  # shellcheck disable=SC2024
  sudo -n sfltool dumpbtm >"$WORK/btm.txt" 2>&1 &
  local pid=$! tries=0
  while kill -0 "$pid" 2>/dev/null && [ "$tries" -lt 120 ]; do
    sleep 0.5
    tries=$((tries + 1))
  done
  if kill -0 "$pid" 2>/dev/null; then
    kill "$pid" 2>/dev/null || true
    echo "(sfltool didn't finish in 60 s)"
    return 0
  fi
  grep -i -A3 batterypulse "$WORK/btm.txt" | tr -s ' ' | tr '\n' ' ' || echo "(no BatteryPulse entry)"
}

step_f11() {
  record "## F6, pages"
  pause "Open every page: Overview, Power, History (24 h, 7 d), Health, Raw Data, Demo Mode"
  ask F6-history "Does History show the last days of 0.6.0 data in 24 h and 7 d?"
  ask F6-raw "Raw Data: does typing \"volt\", clearing it and opening the inspector work?"
  ask F6-demo "Demo Mode, played 20 s: does the menu bar icon follow, with no notification?"
  ask F6 "Do all pages show sensible values?"

  record "## F11, relaunch, alerts, login item"
  quit_app
  set_default menuBarShowsPower -bool true
  local before after
  before="$(today_samples)"
  launch
  echo "waiting 30 s for the launch sample..."
  sleep 30
  after="$(today_samples)"
  record "- F11 launch sample: $before → $after lines today (expected exactly one more)"
  echo "samples today: $before → $after (expected exactly one more)"
  pause "Close every BatteryPulse window"
  ask F11-power "With every window closed, does the power value in the menu bar keep changing?"
  ask F11-settings "Apart from what the session sets (no update checks; icon, charge and power in the menu bar; the main window to open), are your settings all there, the menu bar toggles matching the label, and the icon style unchanged?"
  pause "Settings frontmost: set \"When charged to\" below the current charge, then plug in"
  ask F11-alert "Did a notification arrive within about 10 s, and does clicking it bring BatteryPulse forward?"
  pause "Turn on Open at login (approve it in System Settings if asked)"
  record "- F11 login item: $(login_items)"
  tail -1 "$RESULTS"
  ask F11-login "Is BatteryPulse listed above? Then turn Open at login off: is it off?"
  # CH-09: with no settings the menu bar shows the icon and the charge. Only the update check
  # stays off, so no update window comes up.
  quit_app
  defaults delete "$BUNDLE_ID" 2>/dev/null || true
  set_default updateFrequency -string never
  launch
  ask F11-defaults "With no settings at all, does the menu bar show the icon and the percentage? (Close the welcome window if it opens.)"
  restore_settings
  session_settings
  launch
}

step_f12() {
  record "## F12, update window and installer (G22)"
  pause "Choose Check for Updates"
  ask F12-window "Does the window offer 0.6.0, with rendered notes and a link that opens in the browser?"
  local cached
  cached="$(find "$CACHES" "$HTTP_STORAGE" \( -name 'Cache.db*' -o -name fsCachedData \) \
    -newer "$WORK/prepare.marker" 2>/dev/null | sed "s|$HOME|~|" | tr '\n' ' ' || true)"
  record "- F12 HTTP cache files written since prepare: ${cached:-none} (expected none, SEC-03)"
  tail -1 "$RESULTS"
  pause "Select a sentence in the notes, then choose Install and Relaunch; close What's New when it opens"
  ask F12-selection "Did the selection survive the download?"
  record "- F12 installed version: $(app_version) (expected 0.6.0)"
  tail -1 "$RESULTS"
  ask G22 "Did 0.6.0 install and relaunch?"
  # The core session's perf lines, all from B: read and its parts, history.load, page switches.
  stop_session_stream
  if [ -f "$WORK/perf.ndjson" ]; then
    record "## Perf lines of the core session (B)"
    summarize "$WORK/perf.ndjson" >/dev/null
  fi
  # Your settings come back; the History written meanwhile stays (same format, real samples).
  restore_settings
  restore_system
  launch
  echo "Results: $RESULTS. Next: $SCRIPT send"
}

step_send() {
  need_ids
  [ -s "$RESULTS" ] || fail "no results yet in $RESULTS"
  local url
  url="$(gh api -X POST "repos/$REPO/issues/$PR/comments" -F "body=@$RESULTS" --jq .html_url)"
  echo "Posted: $url"
  echo "Edit that comment and drag the screenshots from $SHOTS into it."
  open "$SHOTS"
  open "$url"
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
  back_to_060
}

step_f9() {
  record "## F9, Russian"
  install_build B
  session_settings
  open "$APP" --args -AppleLanguages '(ru)'
  ask F9 "In Russian, do Overview and Settings look right?"
  back_to_060
}

# Reads per notify burst and widget reloads, from one perf log per build.
step_burst() {
  record "## Burst (S8)"
  local build capture change
  for build in A B; do
    install_build "$build"
    session_settings
    capture="$WORK/burst-$build.ndjson"
    perf_capture "$capture"
    launch
    sleep 10
    for change in 1 2 3 4 5 6; do
      if on_battery; then
        pause "$build, change $change of 6: plug in"
      else
        pause "$build, change $change of 6: unplug"
      fi
      echo "waiting 30 s..."
      sleep 30
    done
    perf_stop "$STREAM"
    record "### $build: 6 plug changes, 30 s apart (widget reloads ÷ 6 = reloads per change)"
    summarize "$capture"
  done
  back_to_060
}

# history.load lines in the order they were logged: "<trigger> <ms>", comma-separated.
history_loads() {
  grep -o -E 'perf interval history\.load ms=[0-9.]+ trigger=[a-z]+' "$1" |
    sed -E 's/.*ms=([0-9.]+) trigger=([a-z]+)/\2 \1/' | paste -s -d , - || true
}

# phys_footprint before and after three History 7 d cycles, and history.load cold and warm.
step_memory() {
  record "## Memory"
  local build capture cycle
  for build in A B; do
    install_build "$build"
    session_settings
    capture="$WORK/memory-$build.ndjson"
    perf_capture "$capture"
    launch
    sleep 20
    record "- $build before: $(rusage "$(app_pid)" 1 | grep phys_footprint)"
    for cycle in 1 2 3; do
      pause "$build, cycle $cycle of 3: open the main window, choose History → 7 d, then close the window"
    done
    sleep 10
    record "- $build after: $(rusage "$(app_pid)" 1 | grep phys_footprint)"
    perf_stop "$STREAM"
    record "- $build history.load in order, ms (the first of each trigger is cold): $(history_loads "$capture")"
    summarize "$capture" '^(intervals|name|history\.load)'
  done
  back_to_060
}

# s2_window <build> <seconds>: S2 for one build: power in the menu bar and no window, 1 minute to
# settle, then rusage over the window, with the app's reads counted.
s2_window() {
  local build="$1" seconds="$2" capture reads
  install_build "$build"
  session_settings
  set_default menuBarShowsPower -bool true
  launch
  sleep 60
  capture="$WORK/s2-$build.ndjson"
  perf_capture "$capture"
  record "### S2 $build"
  record '```'
  rusage "$(app_pid)" "$seconds" | tee -a "$RESULTS"
  record '```'
  perf_stop "$STREAM"
  # The app's reads only: the widget's lines name BatteryPulseWidget.
  reads="$(grep -F 'perf interval read ms=' "$capture" | grep -c -v -F BatteryPulseWidget || true)"
  record "- S2 $build: $reads reads by the app in $seconds s ($(awk -v n="$reads" -v s="$seconds" \
    'BEGIN { printf "%.1f", n * 60 / s }') a minute)"
}

# s7_launches <build> <count>: S7 for one build: cold launches, each timed from open to its
# menuBarReady line, and the reads before it. Power stays in the menu bar as in S2: the menu
# bar's request at launch read again in 0.6.0 and reuses the launch read in the candidate, the
# 2 → 1 reads before menuBarReady that WP-2a left for the session to measure.
s7_launches() {
  local build="$1" count="$2" capture launch_number=0 start starts="" waited before
  install_build "$build"
  session_settings
  set_default menuBarShowsPower -bool true
  capture="$WORK/launch-$build.ndjson"
  perf_capture "$capture"
  while [ "$launch_number" -lt "$count" ]; do
    launch_number=$((launch_number + 1))
    quit_app
    sleep 3
    before="$(ready_count "$capture")"
    start="$(now_ms)"
    open "$APP"
    # The time comes from the line's timestamp; this only waits for the line, at most 15 s.
    waited=0
    until [ "$(ready_count "$capture")" -gt "$before" ] || [ "$waited" -ge 150 ]; do
      sleep 0.1
      waited=$((waited + 1))
    done
    starts="$starts $start"
  done
  perf_stop "$STREAM"
  record "### S7 $build"
  launch_number=0
  for start in $starts; do
    launch_number=$((launch_number + 1))
    record "- S7 $build launch $launch_number: $(ready_after "$capture" "$start") ms from open to menuBarReady"
  done
  summarize "$capture" '^(processes|pid|[0-9])'
}

# S2 for 1 + 4 minutes per build, then S7, 5 launches per build.
step_energy() {
  record "## Energy (S2, S7)"
  if ! on_battery; then pause "Unplug the Mac"; fi
  # An open window can come back at each launch and would poll every 2 s.
  pause "Close every BatteryPulse window and quit other apps, then leave the Mac alone for about 15 minutes; the display stays on"
  # Keeps the display on until this script ends, also after Control-C.
  caffeinate -d -w $$ &
  s2_window A 240
  s2_window B 240
  s7_launches A 5
  s7_launches B 5
  back_to_060
}

# MARK: - Restore

step_restore() {
  [ -f "$BACKUP/defaults.plist" ] || fail "no backup in $BACKUP"
  stop_session_stream
  install_build backup
  restore_settings
  restore_system
  launch
  echo "Your $(cat "$BACKUP/version" 2>/dev/null || echo app), settings, appearance and screenshot folder are back."
  echo "The backup stays in $BACKUP, with your data from before the session in support/."
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
    echo "usage: $SCRIPT <step>" >&2
    echo "  core: prepare v1 v2 v4 f8 f11 f12 send; optional: v2-fill f5 f9 burst memory energy; restore" >&2
    exit 1
    ;;
esac
