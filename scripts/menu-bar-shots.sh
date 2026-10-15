#!/bin/bash
# Menu bar screenshots of BatteryPulse's icon styles next to the system battery item (macOS), for
# the menu bar checks in docs/ROADMAP.md (Stage 1.3).
#
#   scripts/menu-bar-shots.sh <folder> <tag> [--charge] [--highlight] [--looks <list>]
#
# For each look it sets the appearance and a plain wallpaper, relaunches BatteryPulse with each
# icon style and keeps the top 120 px of the right half of every display as
# <folder>/<tag>-<look>-<style>-d<n>.png. On macOS 27 the menu bar follows the wallpaper, not
# the appearance, so the looks (comma-separated, default all four) mix the two:
#
#   light            Light appearance, light wallpaper
#   dark             Dark appearance, dark wallpaper
#   light-darkmode   Dark appearance, light wallpaper
#   dark-lightmode   Light appearance, dark wallpaper
#
# --charge also shows the charge next to the icon. --highlight adds a shot of the light and dark
# looks with BatteryPulse's menu open (you click the item when asked). The folder also gets
# displays.txt (display metrics, once per folder), <tag>-state.txt (pmset -g batt) and
# restore.txt (what the run found and puts back).
#
# When it ends, also after Control-C, it puts back BatteryPulse's menu bar settings, the
# appearance and the wallpapers. The first run asks for Screen Recording (for Terminal: grant it
# and run again) and for Automation of System Events (allow it).
set -euo pipefail

BUNDLE_ID="io.github.nikitausov.BatteryPulse"
STYLES=(symbol modern classic percentageInside ring)
KEYS=(menuBarIconStyle menuBarShowsIcon menuBarShowsCharge menuBarShowsPower menuBarShowsTemperature)
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

usage() {
  echo "usage: scripts/menu-bar-shots.sh <folder> <tag> [--charge] [--highlight] [--looks <list>]" >&2
  exit 1
}

[ $# -ge 2 ] || usage
folder="$1"
tag="$2"
shift 2
charge=false
highlight=false
looks="light,dark,light-darkmode,dark-lightmode"
while [ $# -gt 0 ]; do
  case "$1" in
    --charge) charge=true ;;
    --highlight) highlight=true ;;
    --looks)
      [ $# -ge 2 ] || usage
      looks="$2"
      shift
      ;;
    *) usage ;;
  esac
  shift
done
[ -n "$looks" ] || usage
IFS=, read -r -a look_list <<< "$looks"
for look in "${look_list[@]}"; do
  case "$look" in
    light | dark | light-darkmode | dark-lightmode) ;;
    *) echo "unknown look: $look" >&2 && usage ;;
  esac
done

mkdir -p "$folder"
folder="$(cd "$folder" && pwd)"
tmp="$(mktemp -d)"
shots=0

app_running() { pgrep -x BatteryPulse > /dev/null; }

quit_app() {
  app_running || return 0
  osascript -e "tell application id \"$BUNDLE_ID\" to quit" > /dev/null 2>&1 || true
  for _ in 1 2 3 4 5; do app_running || return 0; sleep 1; done
  pkill -x BatteryPulse || true
  for _ in 1 2 3 4 5 6 7 8 9 10; do app_running || return 0; sleep 1; done
}

# A running app may not notice `defaults write`; a relaunch is certain.
launch_app() {
  open -g -b "$BUNDLE_ID"
  sleep 4
}

# $1: true for the Dark appearance; $2: the wallpaper image.
set_look() {
  osascript -e 'on run argv' \
    -e 'tell application "System Events" to tell appearance preferences to set dark mode to (item 1 of argv is "true")' \
    -e 'tell application "System Events" to set picture of every desktop to (item 2 of argv)' \
    -e 'end run' "$1" "$2" > /dev/null
}

# $1: the icon style.
configure() {
  defaults write "$BUNDLE_ID" menuBarIconStyle -string "$1"
  defaults write "$BUNDLE_ID" menuBarShowsIcon -bool true
  defaults write "$BUNDLE_ID" menuBarShowsCharge -bool "$charge"
  defaults write "$BUNDLE_ID" menuBarShowsPower -bool false
  defaults write "$BUNDLE_ID" menuBarShowsTemperature -bool false
}

# $1: a screenshot; $2: the name of the crop, without .png. The crop uses the image's own width,
# so it needs no display metrics: 120 px covers the menu bar at any scale.
crop() {
  local width
  width="$(sips -g pixelWidth "$1" 2> /dev/null | awk '/pixelWidth/ { print $2 }')" || width=""
  if [ -n "$width" ] \
    && sips -c 120 $((width / 2)) --cropOffset 0 $((width - width / 2)) "$1" --out "$folder/$2.png" > /dev/null 2>&1; then
    :
  else
    cp "$1" "$folder/$2-full.png"
  fi
  shots=$((shots + 1))
}

# $1: the name of the shots, without -d<n>.png.
shoot() {
  local display
  for display in 1 2 3 4 5 6 7 8; do
    rm -f "$tmp/full.png"
    screencapture -x -D "$display" "$tmp/full.png" 2> /dev/null || break
    [ -s "$tmp/full.png" ] || break
    crop "$tmp/full.png" "$1-d$display"
  done
}

# Save what the run changes: BatteryPulse's keys (type and value, or unset), the appearance and
# each display's wallpaper.
for key in "${KEYS[@]}"; do
  if value="$(defaults read "$BUNDLE_ID" "$key" 2> /dev/null)"; then
    type="$(defaults read-type "$BUNDLE_ID" "$key" | awk '{ print $NF }')"
    printf '%s\t%s\t%s\n' "$key" "$type" "$value"
  else
    printf '%s\tunset\t\n' "$key"
  fi
done > "$tmp/settings.tsv"
dark_mode="$(osascript -e 'tell application "System Events" to tell appearance preferences to get dark mode' 2> /dev/null)" \
  || dark_mode=unknown
auto_appearance="$(defaults read -g AppleInterfaceStyleSwitchesAutomatically 2> /dev/null)" || auto_appearance=0
osascript -e 'set out to ""' \
  -e 'tell application "System Events"' \
  -e 'repeat with d in desktops' \
  -e 'set p to "unreadable"' \
  -e 'try' \
  -e 'set p to (picture of d) as text' \
  -e 'end try' \
  -e 'set out to out & p & linefeed' \
  -e 'end repeat' \
  -e 'end tell' \
  -e 'return out' > "$tmp/wallpapers.txt" 2> /dev/null || true
was_running=false
app_running && was_running=true
wallpaper_set=false
{
  echo "== $(date '+%Y-%m-%d %H:%M:%S') $tag"
  echo "BatteryPulse settings (key, type, value):"
  cat "$tmp/settings.tsv"
  echo "Dark mode: $dark_mode; Auto appearance: $auto_appearance"
  echo "Wallpapers, by desktop:"
  cat "$tmp/wallpapers.txt"
} >> "$folder/restore.txt"

restore() {
  set +e
  echo "Putting back the settings, appearance and wallpapers."
  quit_app
  while IFS=$'\t' read -r key type value; do
    case "$type" in
      unset) defaults delete "$BUNDLE_ID" "$key" 2> /dev/null ;;
      boolean) defaults write "$BUNDLE_ID" "$key" -bool "$([ "$value" = 1 ] && echo true || echo false)" ;;
      integer) defaults write "$BUNDLE_ID" "$key" -int "$value" ;;
      float) defaults write "$BUNDLE_ID" "$key" -float "$value" ;;
      *) defaults write "$BUNDLE_ID" "$key" -string "$value" ;;
    esac
  done < "$tmp/settings.tsv"
  if [ "$dark_mode" = true ] || [ "$dark_mode" = false ]; then
    osascript -e 'on run argv' \
      -e 'tell application "System Events" to tell appearance preferences to set dark mode to (item 1 of argv is "true")' \
      -e 'end run' "$dark_mode" > /dev/null
  fi
  # The plain wallpapers are deleted below, so a desktop left on one needs its wallpaper chosen
  # again.
  local index=0 picture
  while IFS= read -r picture; do
    index=$((index + 1))
    # osascript ends its output with an empty line.
    [ -n "$picture" ] || continue
    if [ "$picture" = unreadable ] || [ "$picture" = "missing value" ] \
      || ! osascript -e 'on run argv' \
        -e 'tell application "System Events" to set picture of desktop ((item 1 of argv) as integer) to (item 2 of argv)' \
        -e 'end run' "$index" "$picture" > /dev/null 2>&1; then
      echo "Couldn't put back the wallpaper of desktop $index; choose it in System Settings → Wallpaper."
    fi
  done < "$tmp/wallpapers.txt"
  if $wallpaper_set && [ "$index" -eq 0 ]; then
    echo "Couldn't read the wallpapers before the run; choose them in System Settings → Wallpaper."
  fi
  $was_running && open -g -b "$BUNDLE_ID"
  if [ "$auto_appearance" = 1 ]; then
    echo "Set Appearance back to Auto in System Settings → Appearance."
  fi
  echo "A dynamic wallpaper may come back as a still image; its path is in $folder/restore.txt."
  rm -rf "$tmp"
}
trap restore EXIT
trap 'exit 130' INT TERM

swift "$SCRIPT_DIR/display-metrics.swift" --wallpapers "$tmp" > "$tmp/displays.txt"
[ -e "$folder/displays.txt" ] || cp "$tmp/displays.txt" "$folder/displays.txt"
pmset -g batt > "$folder/$tag-state.txt"

for look in "${look_list[@]}"; do
  case "$look" in
    light) dark=false wallpaper=light ;;
    dark) dark=true wallpaper=dark ;;
    light-darkmode) dark=true wallpaper=light ;;
    dark-lightmode) dark=false wallpaper=dark ;;
  esac
  if set_look "$dark" "$tmp/$wallpaper.png"; then
    wallpaper_set=true
  else
    appearance="$([ "$dark" = true ] && echo Dark || echo Light)"
    read -r -p "Set $appearance appearance and a $wallpaper wallpaper, then press Return. " _
  fi
  for style in "${STYLES[@]}"; do
    quit_app
    configure "$style"
    launch_app
    shoot "$tag-$look-$style"
  done
  if $highlight && { [ "$look" = light ] || [ "$look" = dark ]; }; then
    quit_app
    configure modern
    launch_app
    echo "Click BatteryPulse's menu bar item now; the shot is taken in 5 seconds."
    rm -f "$tmp/full.png"
    if screencapture -x -T 5 -D 1 "$tmp/full.png" && [ -s "$tmp/full.png" ]; then
      crop "$tmp/full.png" "$tag-$look-highlight-d1"
    fi
    read -r -p "Close the menu, then press Return. " _
  fi
done

echo "Wrote $shots shots to $folder."
