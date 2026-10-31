#!/bin/bash
# Runs the installer's relaunch script on macOS, both ways an update can go, with the app's own
# script text (UpdateInstallPolicy.relaunchScript; a Linux test keeps the copy below equal to it):
#
# 1. The update doesn't open. Two throwaway app bundles in a temporary folder: the newer one at the
#    app's path, exiting at launch; the older one where the installer leaves the previous version.
#    The script must open the newer one, wait out its 30 s, put the older one back at the app's
#    path and the newer one in the older one's place, and open the older one.
# 2. The update opens (only when a BatteryPulse.app is given). A copy of it at the app's path, a
#    stand-in previous version with its bundle identifier, the update's downloads folder and the
#    updateLeftover default, as the installer leaves them. The app must create its launch marker
#    long before the 30 s are out, the script leave the app in place, and the app delete the
#    stand-in and the downloads. This side runs the app itself, so it checks the app's half of the
#    handshake too.
#
# Usage: scripts/relaunch-fallback-check.sh [<BatteryPulse.app>]
# CI's macOS job runs it on the app it built; it takes about a minute.
set -euo pipefail

if [ "$(uname)" != Darwin ]; then
  echo "error: the relaunch check runs on macOS" >&2
  exit 1
fi
built="${1:-}"
if [ -n "$built" ] && [ ! -f "$built/Contents/Info.plist" ]; then
  echo "error: $built is not an app bundle" >&2
  exit 1
fi

# The app's relaunch script, verbatim.
RELAUNCH='i=0
while kill -0 "$2" 2>/dev/null && [ "$i" -lt 50 ]; do sleep 0.2; i=$((i + 1)); done
sleep 1
"$3" -n "$1"
i=0
while [ ! -e "$5" ] && [ -d "${5%/*}" ] && [ "$i" -lt "$6" ]; do sleep 0.2; i=$((i + 1)); done
mkdir "$5" 2>/dev/null || exit 0
if [ -d "$4" ] && [ ! -e "$4.new" ] && mv "$1" "$4.new"; then
  if mv "$4" "$1"; then
    mv "$4.new" "$4"
    rmdir "$5"
    exec "$3" -n "$1"
  fi
  mv "$4.new" "$1"
fi
rmdir "$5"'
# UpdateInstallPolicy.launchMarkerChecks and launchMarkerName.
CHECKS=150
MARKER_NAME=Launched

work="$(mktemp -d -t relaunch-check)"
leftover_default=
app_downloads=
cleanup() {
  if [ -n "$leftover_default" ]; then
    defaults delete "$leftover_default" updateLeftover 2> /dev/null || true
  fi
  [ -z "$app_downloads" ] || rm -rf "$app_downloads"
  rm -rf "$work"
}
trap cleanup EXIT
status=0
fail() {
  echo "error: $*" >&2
  status=1
}

# since <start> <file>: the seconds from <start> (date +%s) to the file's modification.
since() {
  echo $(($(stat -f %m "$2") - $1))
}

# version <bundle>: its CFBundleShortVersionString, or nothing.
version() {
  plutil -extract CFBundleShortVersionString raw -o - "$1/Contents/Info.plist" 2> /dev/null || true
}

# wait_for <seconds> <test arguments...>: polls the test twice a second until it holds.
wait_for() {
  local tries=$(($1 * 2))
  shift
  while ! test "$@"; do
    tries=$((tries - 1))
    [ "$tries" -gt 0 ] || return 1
    sleep 0.5
  done
}

# running <name>: whether a process of that name runs.
running() {
  pgrep -x "$1" > /dev/null
}

# relaunch <app> <previous> <marker>: runs the script as the installer does, with a stand-in for
# the installing process that quits after a second, and prints how many seconds it took. The
# script's own output goes to the log.
relaunch() {
  sleep 1 > /dev/null &
  local installer=$! start=$SECONDS
  /bin/sh -c "$RELAUNCH" sh "$1" "$installer" /usr/bin/open "$2" "$3" "$CHECKS" >&2 || true
  echo $((SECONDS - start))
}

# The throwaway app: it records that it opened (in the file its Info.plist names) and, as the
# update that doesn't open, exits at once.
cat > "$work/probe.swift" << 'SWIFT'
import Foundation

let info = Bundle.main.infoDictionary ?? [:]
if let flag = info["ProbeOpened"] as? String {
    FileManager.default.createFile(atPath: flag, contents: nil)
}
exit(info["ProbeExitsAtLaunch"] as? Bool == true ? 1 : 0)
SWIFT
# For the oldest macOS the app runs on, not the SDK's.
swiftc -O -target "$(uname -m)-apple-macosx27.0" "$work/probe.swift" -o "$work/probe"

# probe <bundle> <version> <exits at launch: true|false> <opened flag>
probe() {
  mkdir -p "$1/Contents/MacOS"
  cp "$work/probe" "$1/Contents/MacOS/Probe"
  cat > "$1/Contents/Info.plist" << PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleExecutable</key><string>Probe</string>
  <key>CFBundleIdentifier</key><string>io.github.nikitausov.BatteryPulse.relaunch-check</string>
  <key>CFBundleName</key><string>Probe</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleShortVersionString</key><string>$2</string>
  <key>CFBundleVersion</key><string>1</string>
  <key>LSUIElement</key><true/>
  <key>ProbeExitsAtLaunch</key><$3/>
  <key>ProbeOpened</key><string>$4</string>
</dict>
</plist>
PLIST
  codesign --force --sign - "$1"
}

echo "1. An update that exits at launch"
one="$work/one"
app="$one/Applications/Probe.app"
previous="$one/NSIRD_Probe/Probe.app"
downloads="$one/Caches/Updates"
marker="$downloads/$MARKER_NAME"
probe "$app" 2.0 true "$one/update-opened"
probe "$previous" 1.0 false "$one/previous-opened"
mkdir -p "$downloads"
: > "$downloads/BatteryPulse.dmg"
start="$(date +%s)"
seconds="$(relaunch "$app" "$previous" "$marker")"
echo "The script ended after $seconds s"
wait_for 15 -e "$one/previous-opened" || fail "the previous version wasn't opened again"
[ -e "$one/update-opened" ] || fail "the update wasn't opened"
# When each version opened, from the probes' own files: the wait is the time between the two.
if [ -e "$one/update-opened" ] && [ -e "$one/previous-opened" ]; then
  echo "The update opened after $(since "$start" "$one/update-opened") s, the previous version after $(since "$start" "$one/previous-opened") s"
fi
[ "$(version "$app")" = 1.0 ] || fail "the app's path holds version '$(version "$app")', not the previous 1.0"
[ "$(version "$previous")" = 2.0 ] || fail "the previous version's place holds '$(version "$previous")', not the update"
[ ! -e "$previous.new" ] || fail "the update was left aside at $previous.new"
[ ! -e "$marker" ] || fail "the script left its launch marker"
[ "$seconds" -ge 30 ] || fail "the script put the previous version back after $seconds s, before the 30 s were out"
if [ "$status" -eq 0 ]; then echo "The previous version is back and open"; fi

if [ -n "$built" ]; then
  echo "2. An update that opens: $built"
  identifier="$(plutil -extract CFBundleIdentifier raw -o - "$built/Contents/Info.plist")"
  executable="$(plutil -extract CFBundleExecutable raw -o - "$built/Contents/Info.plist")"
  built_version="$(version "$built")"
  if running "$executable"; then
    echo "error: $executable is running already" >&2
    exit 1
  fi
  two="$work/two"
  app="$two/Applications/BatteryPulse.app"
  previous="$two/NSIRD_BatteryPulse/BatteryPulse.app"
  # Where the app keeps its downloads: Caches/<bundle identifier>/Updates.
  downloads="$HOME/Library/Caches/$identifier/Updates"
  marker="$downloads/$MARKER_NAME"
  mkdir -p "$two/Applications" "$previous/Contents"
  ditto "$built" "$app"
  # A previous version needs no more than its identifier and a version of its own to be deleted.
  cat > "$previous/Contents/Info.plist" << PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleIdentifier</key><string>$identifier</string>
  <key>CFBundleShortVersionString</key><string>0.1.0</string>
</dict>
</plist>
PLIST
  app_downloads="$downloads"
  rm -rf "$downloads"
  mkdir -p "$downloads"
  : > "$downloads/BatteryPulse.dmg"
  leftover_default="$identifier"
  defaults write "$identifier" updateLeftover "$previous"
  touch "$work/launch-marker"
  seconds="$(relaunch "$app" "$previous" "$marker")"
  echo "The script ended after $seconds s"
  [ "$seconds" -lt 30 ] || fail "the script waited out the 30 s: the app never created its launch marker"
  [ "$(version "$app")" = "$built_version" ] || fail "the app's path holds version '$(version "$app")', not $built_version"
  [ ! -e "$previous.new" ] || fail "the app was moved aside to $previous.new"
  wait_for 15 ! -e "$previous" || fail "the app didn't delete the previous version"
  wait_for 15 ! -e "$downloads" || fail "the app didn't delete the downloads"
  running "$executable" || fail "$executable isn't running"
  pkill -x "$executable" || true
  for _ in 1 2 3 4 5 6 7 8 9 10; do
    running "$executable" || break
    sleep 1
  done
  if running "$executable"; then
    fail "$executable didn't quit"
    pkill -9 -x "$executable" || true
  fi
  crashes="$(find "$HOME/Library/Logs/DiagnosticReports" /Library/Logs/DiagnosticReports -name "$executable*" \
    -newer "$work/launch-marker" 2> /dev/null || true)"
  [ -z "$crashes" ] || fail "crash reports: $crashes"
  if [ "$status" -eq 0 ]; then echo "The update stayed, and it deleted the previous version and the downloads"; fi
fi
exit "$status"
