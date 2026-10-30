#!/bin/bash
# Size report of a packaged build (macOS), run after scripts/build-app.sh:
#
#   scripts/size-report.sh
#
# Measures build/BatteryPulse.dmg and build/BatteryPulse.app with Apple's tools, counts the
# bundle hygiene problems, writes build/size.json and prints a Markdown table, which CI also
# appends to $GITHUB_STEP_SUMMARY. With GH_TOKEN set it compares the DMG with the latest
# release's, for information.
#
# It fails when a row exceeds its ceiling in scripts/size-budget.json, or when a bundle hygiene
# count isn't 0: the Swift runtime loaded from the bundle, a Frameworks folder, build products
# such as a dSYM inside the bundle, the build machine's paths in a shipped (stripped) binary, or
# an export list other than _main alone.
set -euo pipefail

cd "$(dirname "$0")/.."

APP="build/BatteryPulse.app"
DMG="build/BatteryPulse.dmg"
JSON="build/size.json"
BUDGET="scripts/size-budget.json"
APP_BINARY="$APP/Contents/MacOS/BatteryPulse"
WIDGET_BINARY="$APP/Contents/PlugIns/BatteryPulseWidget.appex/Contents/MacOS/BatteryPulseWidget"
WIDGET_METADATA="$APP/Contents/PlugIns/BatteryPulseWidget.appex/Contents/Resources/Metadata.appintents"
ICNS="$APP/Contents/Resources/AppIcon.icns"
for path in "$DMG" "$APP_BINARY" "$WIDGET_BINARY" "$ICNS"; do
  if [ ! -e "$path" ]; then
    echo "error: $path is missing; run scripts/build-app.sh first" >&2
    exit 1
  fi
done

bytes() { stat -f%z "$1"; }

# The size of __TEXT,__text. `size -m` prints "Segment __TEXT: <n>" and below it
# "Section __text: <n>"; "null" if that isn't there.
text_bytes() {
  local listing value
  listing="$(size -m "$1")"
  value="$(awk '/^Segment __TEXT:/ { inText = 1; next } /^Segment / { inText = 0 }
    inText && $1 == "Section" && $2 == "__text:" { print $3; exit }' <<<"$listing")"
  echo "${value:-null}"
}

# The exported symbols. `dyld_info -exports` prints a header and then one "0x<offset> <symbol>"
# line per export; "null" if the tool fails.
exports() {
  local listing
  if ! listing="$(xcrun dyld_info -exports "$1" 2>/dev/null)"; then
    echo null
    return
  fi
  grep -c -E '^[[:space:]]*0x[0-9A-Fa-f]+[[:space:]]' <<<"$listing" || true
}

# The exported names, one per line, sorted.
export_names() {
  xcrun dyld_info -exports "$1" 2>/dev/null | awk '$1 ~ /^0x[0-9A-Fa-f]+$/ { print $2 }' | sort -u || true
}

# Each shipped executable exports _main and nothing else: the number of other exported names,
# plus 1 if _main isn't exported. "null" if dyld_info fails.
other_exports() {
  local names others
  if [ "$(exports "$1")" = null ]; then
    echo null
    return
  fi
  names="$(export_names "$1")"
  others=0
  if [ -n "$names" ]; then
    others="$(grep -c -v -x -F _main <<<"$names" || true)"
  fi
  grep -q -x -F _main <<<"$names" || others=$((others + 1))
  echo "$others"
}

# Lines of `strings -a` that name a path in a user's home folder, such as the CI runner's
# /Users/runner/work checkout.
build_machine_paths() {
  local listing
  listing="$(strings -a "$1")"
  grep -c -F "/Users/" <<<"$listing" || true
}

# Lines of `otool -L` that load the Swift runtime from the bundle instead of the OS.
rpath_libswift() {
  local listing
  listing="$(otool -L "$1")"
  grep -c -F "@rpath/libswift" <<<"$listing" || true
}

version="$(plutil -extract CFBundleShortVersionString raw -o - "$APP/Contents/Info.plist")"
commit="${GITHUB_SHA:-$(git rev-parse HEAD 2>/dev/null || echo unknown)}"

dmg_bytes="$(bytes "$DMG")"
# `diskutil image info` prints "Image Format: <code>" (hdiutil imageinfo is deprecated in macOS 27).
dmg_info="$(diskutil image info "$DMG")"
dmg_format="$(awk -F': ' '$1 ~ /^[[:space:]]*Image Format$/ { print $2; exit }' <<<"$dmg_info")"
dmg_format="${dmg_format:-unknown}"
app_kb="$(du -sk "$APP" | cut -f1)"
app_binary_bytes="$(bytes "$APP_BINARY")"
app_text_bytes="$(text_bytes "$APP_BINARY")"
app_exports="$(exports "$APP_BINARY")"
widget_binary_bytes="$(bytes "$WIDGET_BINARY")"
widget_text_bytes="$(text_bytes "$WIDGET_BINARY")"
widget_exports="$(exports "$WIDGET_BINARY")"
strings_bytes=0
while IFS= read -r file; do
  strings_bytes=$((strings_bytes + $(bytes "$file")))
done < <(find "$APP" -path '*.lproj/*' -type f)
icns_bytes="$(bytes "$ICNS")"
# The widget's App Intents metadata, which build-app.sh extracts: the bytes of the files in
# Metadata.appintents, 0 while the widget declares no App Intents type. app_kb counts it too.
widget_appintents_bytes=0
if [ -d "$WIDGET_METADATA" ]; then
  while IFS= read -r file; do
    widget_appintents_bytes=$((widget_appintents_bytes + $(bytes "$file")))
  done < <(find "$WIDGET_METADATA" -type f)
fi

hygiene_rpath_libswift=$(($(rpath_libswift "$APP_BINARY") + $(rpath_libswift "$WIDGET_BINARY")))
hygiene_frameworks="$(find "$APP" -type d -path '*/Contents/Frameworks' | wc -l | tr -d ' ')"
hygiene_build_products="$(find "$APP" \( -name '*.dSYM' -o -name '*.o' -o -name '*.swiftmodule' \) | wc -l | tr -d ' ')"
hygiene_app_paths="$(build_machine_paths "$APP_BINARY")"
hygiene_widget_paths="$(build_machine_paths "$WIDGET_BINARY")"
hygiene_app_other_exports="$(other_exports "$APP_BINARY")"
hygiene_widget_other_exports="$(other_exports "$WIDGET_BINARY")"

# The numeric rows, as "key value", in the order of the table and of size.json.
rows="dmg_bytes $dmg_bytes
app_kb $app_kb
app_binary_bytes $app_binary_bytes
app_text_bytes $app_text_bytes
app_exports $app_exports
widget_binary_bytes $widget_binary_bytes
widget_text_bytes $widget_text_bytes
widget_exports $widget_exports
widget_appintents_bytes $widget_appintents_bytes
strings_bytes $strings_bytes
icns_bytes $icns_bytes"

{
  echo "{"
  echo "  \"version\": \"$version\","
  echo "  \"commit\": \"$commit\","
  echo "  \"dmg_format\": \"$dmg_format\","
  while read -r key value; do
    echo "  \"$key\": $value,"
  done <<<"$rows"
  echo "  \"hygiene\": {"
  echo "    \"rpath_libswift\": $hygiene_rpath_libswift,"
  echo "    \"frameworks_folders\": $hygiene_frameworks,"
  echo "    \"build_products\": $hygiene_build_products,"
  echo "    \"app_build_machine_paths\": $hygiene_app_paths,"
  echo "    \"widget_build_machine_paths\": $hygiene_widget_paths,"
  echo "    \"app_other_exports\": $hygiene_app_other_exports,"
  echo "    \"widget_other_exports\": $hygiene_widget_other_exports"
  echo "  }"
  echo "}"
} >"$JSON"

# The budget: one optional ceiling per row under "ceilings", read with plutil.
over_budget=""
ceilings=0
if plutil -extract ceilings json -o - "$BUDGET" >/dev/null 2>&1; then
  budget_note="plutil reads the JSON budget."
  while read -r key value; do
    ceiling="$(plutil -extract "ceilings.$key" raw -o - "$BUDGET" 2>/dev/null)" || continue
    ceilings=$((ceilings + 1))
    if [ "$value" = null ] || [ "$value" -gt "$ceiling" ]; then
      over_budget="$over_budget $key ($value > $ceiling)"
    fi
  done <<<"$rows"
else
  budget_note="plutil can't read $BUDGET, so no ceiling was checked; it needs to become an XML plist."
fi

latest_note=""
if [ -n "${GH_TOKEN:-}" ] && [ -n "${GITHUB_REPOSITORY:-}" ] && command -v gh >/dev/null; then
  latest="$(gh api "repos/$GITHUB_REPOSITORY/releases/latest" \
    --jq '.tag_name + " " + ([.assets[] | select(.name == "BatteryPulse.dmg") | .size | tostring] | first // "")' \
    2>/dev/null || true)"
  latest_tag="${latest%% *}"
  latest_bytes="${latest#* }"
  if [ -n "$latest_tag" ] && [ -n "$latest_bytes" ] && [ "$latest_bytes" != "$latest" ]; then
    change="$(awk -v now="$dmg_bytes" -v then="$latest_bytes" 'BEGIN { printf "%+.1f", (now - then) * 100 / then }')"
    latest_note="Latest release $latest_tag: DMG $latest_bytes B; this build $change %."
  fi
fi

# The first lines of each export listing, whose header names the file it read, and how many
# exported names the two binaries share.
app_exports_sample="$(xcrun dyld_info -exports "$APP_BINARY" 2>&1 || true)"
widget_exports_sample="$(xcrun dyld_info -exports "$WIDGET_BINARY" 2>&1 || true)"
shared_exports="$(comm -12 <(export_names "$APP_BINARY") <(export_names "$WIDGET_BINARY") | wc -l | tr -d ' ')"

report="$(
  echo "### Size ($version, ${commit:0:7})"
  echo
  echo "| Row | Value |"
  echo "|---|---|"
  echo "| DMG ($dmg_format) | $dmg_bytes B |"
  echo "| \`.app\` installed | $app_kb KB |"
  echo "| App binary | $app_binary_bytes B |"
  echo "| App \`__TEXT,__text\` | $app_text_bytes B |"
  echo "| App exports | $app_exports |"
  echo "| Widget binary | $widget_binary_bytes B |"
  echo "| Widget \`__TEXT,__text\` | $widget_text_bytes B |"
  echo "| Widget exports | $widget_exports |"
  echo "| Widget \`Metadata.appintents\` | $widget_appintents_bytes B |"
  echo "| Localized strings (\`.lproj\`), app and widget | $strings_bytes B |"
  echo "| \`AppIcon.icns\` | $icns_bytes B |"
  echo
  [ -z "$latest_note" ] || { echo "$latest_note"; echo; }
  echo "#### Bundle hygiene (each must be 0)"
  echo
  echo "| Check | Count |"
  echo "|---|---|"
  echo "| \`@rpath/libswift\` in \`otool -L\` | $hygiene_rpath_libswift |"
  echo "| \`Contents/Frameworks\` folders | $hygiene_frameworks |"
  echo "| \`.dSYM\`, \`.o\` and \`.swiftmodule\` in the bundle | $hygiene_build_products |"
  echo "| \`/Users/\` strings in the app binary | $hygiene_app_paths |"
  echo "| \`/Users/\` strings in the widget binary | $hygiene_widget_paths |"
  echo "| Exports other than \`_main\` (+1 without \`_main\`), app | $hygiene_app_other_exports |"
  echo "| Exports other than \`_main\` (+1 without \`_main\`), widget | $hygiene_widget_other_exports |"
  echo
  echo "Budget: $ceilings ceilings in \`$BUDGET\`. $budget_note"
  echo
  echo "<details><summary><code>dyld_info -exports</code>, first lines of each binary</summary>"
  echo
  echo '```'
  head -6 <<<"$app_exports_sample"
  echo
  head -6 <<<"$widget_exports_sample"
  echo '```'
  echo
  echo "Names exported by both binaries: $shared_exports."
  echo "</details>"
)"
echo "$report"
if [ -n "${GITHUB_STEP_SUMMARY:-}" ]; then
  echo "$report" >>"$GITHUB_STEP_SUMMARY"
fi

failed=0
if [ -n "$over_budget" ]; then
  echo "error: over the size budget:$over_budget" >&2
  failed=1
fi
hygiene="rpath_libswift $hygiene_rpath_libswift
frameworks_folders $hygiene_frameworks
build_products $hygiene_build_products
app_build_machine_paths $hygiene_app_paths
widget_build_machine_paths $hygiene_widget_paths
app_other_exports $hygiene_app_other_exports
widget_other_exports $hygiene_widget_other_exports"
while read -r key value; do
  if [ "$value" != 0 ]; then
    echo "error: bundle hygiene: $key is $value, not 0" >&2
    failed=1
  fi
done <<<"$hygiene"
exit "$failed"
