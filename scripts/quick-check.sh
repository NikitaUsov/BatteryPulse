#!/bin/bash
# BatteryPulse's quick check after a macOS 27.x update (about 5 minutes, by hand; ROADMAP's NEW-22).
# A macOS update can move what BatteryPulse reads: the accessories' power sources, the Charge
# Limit's bit in NotChargingReason, the registry the Raw Data page shows. Run it a few minutes after
# each update, from the checkout, with BatteryPulse running:
#
#   bash scripts/quick-check.sh
#
# 1. The reads (no input): the macOS build, BatteryPulse's version, then, when bpulse is built
#    (swift build -c release --product bpulse):
#    - NotChargingReason from `bpulse --json` beside `pmset -g battlimit`. At the Charge Limit's
#      hold, on the adapter, the reason carries bit 24 (0x01000000), which BatteryPulse's "Charged
#      to limit" reads, and a plug-in's first read may carry bit 7 (128) instead. A hold without bit
#      24, or bit 24 without a limit, is printed as a CHECK line: the bit may have moved;
#    - the accessories: `bpulse --accessories --raw` and `pmset -g accps -xml` side by side, as
#      counts of power sources other than the Mac's own battery. pmset writes one property list per
#      source, back to back, and plutil reads only the first, so each is counted on its own.
# 2. Four questions, each "y = looks right" (n says what, s skips): the Devices page, the
#    Accessories page, the Raw Data page and the desktop widget.
#
# The report goes to the terminal and to ~/bp-quick-check/<macOS build>-<time>.md, on this Mac
# only. It holds counts, numbers and his answers: never an accessory's or a device's name, and no
# serial number. It changes nothing and needs no password. macOS only; bash 3.2.
set -euo pipefail

APP="/Applications/BatteryPulse.app"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
BPULSE="$ROOT/.build/release/bpulse"

if [ "$(uname -s)" != Darwin ]; then
  echo "error: the quick check runs on a Mac" >&2
  exit 1
fi

BUILD="$(sw_vers -buildVersion 2>/dev/null || echo unknown)"
FOLDER="$HOME/bp-quick-check"
REPORT="$FOLDER/$BUILD-$(date '+%Y%m%d-%H%M').md"
WORK="$(mktemp -d "${TMPDIR:-/tmp}/bp-quick-check.XXXXXX")"
trap 'rm -rf "$WORK"' EXIT
mkdir -p "$FOLDER"
: >"$REPORT"

# out <line>: to the terminal and the report.
out() { printf '%s\n' "$*" | tee -a "$REPORT"; }

# plist_split <file> <folder>: the XML property lists in <file>, which may hold several back to back,
# each from its XML header (or <plist>) to its </plist>, as <folder>/1.plist, 2.plist, ...; prints
# how many. Text outside them is dropped.
plist_split() {
  rm -rf "$2"
  mkdir -p "$2"
  awk -v dir="$2" '
    {
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

# sources <file> [<key path>]: "<all> <internal>", the power sources in one property list and those
# whose Type is InternalBattery (the Mac's own battery): the elements of the array at the key path,
# else of a root array, else the root dictionary as one source; "unreadable" otherwise.
sources() {
  local path="${2:-}" all=0 internal=0 type root
  if [ -z "$path" ]; then
    # The XML form's fourth line is the root element.
    root="$(plutil -convert xml1 -o - "$1" 2>/dev/null | sed -n 4p)"
    case "$root" in
      "<dict>" | "<dict/>")
        type="$(plutil -extract Type raw -o - "$1" 2>/dev/null || true)"
        if [ "$type" = InternalBattery ]; then echo "1 1"; else echo "1 0"; fi
        return 0
        ;;
      "<array>" | "<array/>") ;;
      *)
        echo unreadable
        return 0
        ;;
    esac
  elif ! plutil -extract "$path" xml1 -o /dev/null "$1" >/dev/null 2>&1; then
    echo unreadable
    return 0
  fi
  while plutil -extract "${path:+$path.}$all" xml1 -o /dev/null "$1" >/dev/null 2>&1; do
    type="$(plutil -extract "${path:+$path.}$all.Type" raw -o - "$1" 2>/dev/null || true)"
    if [ "$type" = InternalBattery ]; then internal=$((internal + 1)); fi
    all=$((all + 1))
  done
  echo "$all $internal"
}

# json_number <file> <key>: a top-level number of bpulse's pretty-printed JSON, or nothing.
json_number() {
  sed -n "s/^  \"$2\"[[:space:]]*:[[:space:]]*\\(-*[0-9][0-9]*\\).*/\\1/p" "$1" | head -1
}

# json_word <file> <key>: a top-level string or boolean of bpulse's JSON, or nothing.
json_word() {
  sed -n "s/^  \"$2\"[[:space:]]*:[[:space:]]*\"*\\([A-Za-z]*\\).*/\\1/p" "$1" | head -1
}

# ask <id> <question>: one answer, y = looks right, n with what is wrong, s skipped.
ask() {
  local reply note=""
  while true; do
    printf '\n%s\n  y = looks right, n = something is wrong, s = skip: ' "$2"
    read -r reply </dev/tty || reply=s
    case "$reply" in
      y | n | s) break ;;
    esac
  done
  if [ "$reply" = n ]; then
    printf '  What is wrong (one line, no names): '
    read -r note </dev/tty || note=""
  fi
  ANSWERS="$ANSWERS| $1 | $reply | ${note:--} |
"
}

ANSWERS=""
out "# BatteryPulse quick check, $(date '+%Y-%m-%d %H:%M')"
out ""
out "- macOS $(sw_vers -productVersion 2>/dev/null || echo unknown) ($BUILD)"
out "- BatteryPulse $(plutil -extract CFBundleShortVersionString raw -o - "$APP/Contents/Info.plist" 2>/dev/null || echo "not installed") ($(plutil -extract CFBundleVersion raw -o - "$APP/Contents/Info.plist" 2>/dev/null || echo -))"
if pgrep -x BatteryPulse >/dev/null; then out "- BatteryPulse runs"; else out "- BatteryPulse doesn't run: open it before the questions"; fi
out "- pmset -g batt: $(pmset -g batt 2>/dev/null | sed -n 2p | grep -o -E '[0-9]+%;.*' | sed 's/ present: true//; s/[[:space:]]*$//' || true)"

# The Charge Limit: powerd's battlimit holds it only on the adapter, below it too, and on battery
# says "No battery level limits set".
pmset -g battlimit >"$WORK/battlimit.txt" 2>&1 || true
limit="$(sed -n 's/.*chargeSocLimitSoc[^0-9]*\([0-9][0-9]*\).*/\1/p' "$WORK/battlimit.txt" | head -1)"
out ""
out "## The Charge Limit's bit"
out ""
if [ -n "$limit" ]; then
  out "- pmset -g battlimit: $limit % (chargeSocLimitSoc)"
else
  out "- pmset -g battlimit: none ($(head -1 "$WORK/battlimit.txt" | cut -c1-60))"
fi
if [ ! -x "$BPULSE" ]; then
  out "- bpulse isn't built: \`swift build -c release --product bpulse\` in $(basename "$ROOT"), then run this again for NotChargingReason and the accessories' counts"
else
  "$BPULSE" --json >"$WORK/battery.json" 2>"$WORK/battery.err" || true
  reason="$(json_number "$WORK/battery.json" notChargingReason)"
  charge="$(json_number "$WORK/battery.json" chargePercent)"
  external="$(json_word "$WORK/battery.json" isExternalPowerConnected)"
  state="$(json_word "$WORK/battery.json" chargeState)"
  if [ -z "$reason" ]; then
    out "- bpulse --json: no NotChargingReason ($(head -1 "$WORK/battery.err" | cut -c1-80))"
  else
    bit24=no
    bit7=no
    if [ $((reason & 0x01000000)) -ne 0 ]; then bit24=yes; fi
    if [ $((reason & 0x80)) -ne 0 ]; then bit7=yes; fi
    out "- bpulse --json: NotChargingReason $reason ($(printf '0x%08X' "$reason")), bit 24: $bit24, bit 7: $bit7; charge ${charge:--} %, $state, external power ${external:--}"
    # The hold: on the adapter, not charging, at the limit (a point under it reads as held too).
    if [ -n "$limit" ] && [ "$external" = true ] && [ -n "$charge" ] && [ $((charge + 1)) -ge "$limit" ] && [ "$state" != charging ] && [ "$bit24" = no ]; then
      out "- CHECK: the charge holds at the ${limit} % limit on the adapter without bit 24. macOS may have moved the Charge Limit's bit: keep \`$BPULSE --raw > ~/bp-quick-check/limit-$BUILD.plist\` for the next release"
    elif [ "$bit24" = yes ] && [ -z "$limit" ]; then
      out "- CHECK: bit 24 without a Charge Limit (Optimized Charging's hold may set it too): keep \`$BPULSE --raw > ~/bp-quick-check/bit24-$BUILD.plist\`"
    elif [ "$bit24" = yes ]; then
      out "- consistent: bit 24 at the ${limit} % limit"
    elif [ -n "$limit" ]; then
      out "- not at the limit's hold now (${charge:--} %, $state): bit 24 can't be checked; run this again on the adapter at ${limit} %"
    elif [ "$external" != true ]; then
      out "- on battery: battlimit shows a Charge Limit only on the adapter, so bit 24 can't be checked; run this again on the adapter"
    else
      out "- no Charge Limit set (100 %): bit 24 can't be checked"
    fi
  fi
fi

out ""
out "## The accessories"
out ""
pmset -g accps -xml >"$WORK/accps.xml" 2>/dev/null || true
pieces="$(plist_split "$WORK/accps.xml" "$WORK/accps")"
pmset_all=0
pmset_internal=0
pmset_bad=0
index=1
while [ "$index" -le "$pieces" ]; do
  set -- $(sources "$WORK/accps/$index.plist")
  if [ "$1" = unreadable ]; then
    pmset_bad=$((pmset_bad + 1))
  else
    pmset_all=$((pmset_all + $1))
    pmset_internal=$((pmset_internal + $2))
  fi
  index=$((index + 1))
done
pmset_count=$((pmset_all - pmset_internal))
line="- pmset -g accps -xml: $pieces property lists, $pmset_count accessory sources"
if [ "$pmset_bad" -gt 0 ]; then line="$line ($pmset_bad unreadable)"; fi
out "$line"
if [ -x "$BPULSE" ]; then
  "$BPULSE" --accessories --raw >"$WORK/accessories.plist" 2>/dev/null || true
  set -- $(sources "$WORK/accessories.plist" AccessorySources)
  if [ "$1" = unreadable ]; then
    out "- bpulse --accessories --raw: unreadable"
  else
    bpulse_count=$(($1 - $2))
    out "- bpulse --accessories --raw: $bpulse_count accessory sources"
    if [ "$bpulse_count" -ne "$pmset_count" ]; then
      out "- CHECK: the counts differ: compare the Accessories page with the Bluetooth menu, and keep \`$BPULSE --accessories --raw\` (names replaced) for the next release"
    else
      out "- the same count"
    fi
  fi
fi

echo
echo "Now four questions. Open BatteryPulse's main window (its menu bar item, then Open BatteryPulse)."
ask devices "Devices: connect an iPhone or iPad by cable if one is at hand (else s). Does its page show its battery?"
ask accessories "Accessories: does the page list the accessories macOS shows in the Bluetooth menu, with their levels?"
ask raw-data "Raw Data: does the table fill, and does a search for NotChargingReason find its row?"
ask widget "The desktop widget: does it show the same charge and state as the menu bar item (give it a minute)?"

out ""
out "## Looks right?"
out ""
out "| Item | Answer | Note |"
out "|---|---|---|"
printf '%s' "$ANSWERS" | tee -a "$REPORT"
echo
echo "The report: $REPORT"
