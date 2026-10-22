#!/bin/bash
# Builds build/BatteryPulse.app and build/BatteryPulse.dmg (macOS only).
#
#   scripts/build-app.sh            # version from the latest git tag, build 1
#   VERSION=0.2.0 BUILD_NUMBER=7 scripts/build-app.sh
#   PROFILING=1 scripts/build-app.sh   # build/BatteryPulse-profiling.{app,dmg}, see below
#
# The app is ad-hoc signed. A notarized build needs a Developer ID certificate; until then,
# each version downloaded with a browser must be approved once in System Settings → Privacy &
# Security. An update installed from inside the app needs no approval: its download isn't
# quarantined (see LSFileQuarantineEnabled below).
set -euo pipefail

cd "$(dirname "$0")/.."

# Defaults to the latest release tag, so a local build of main doesn't look outdated to the
# update check. CI's shallow checkout has no tags; it gets 0.0.0.
if [ -z "${VERSION:-}" ]; then
  VERSION="$(git describe --tags --abbrev=0 2>/dev/null || echo 0.0.0)"
  VERSION="${VERSION#v}"
fi
BUILD_NUMBER="${BUILD_NUMBER:-1}"
BUNDLE_ID="io.github.nikitausov.BatteryPulse"
BUILD_DIR="build"
# PROFILING=1: a build for Instruments and the memory tools (leaks, vmmap, footprint), which
# can't attach to a hardened process without get-task-allow. Only the app gets the entitlement,
# not the widget. The outputs are named BatteryPulse-profiling so they can't pass for a release,
# and release.yml refuses them: get-task-allow hands the app's task port to any process of the
# user, so a profiling build is never published.
PROFILING="${PROFILING:-0}"
case "$PROFILING" in
  0) NAME="BatteryPulse" ;;
  1) NAME="BatteryPulse-profiling" ;;
  *) echo "error: PROFILING must be 0 or 1, not '$PROFILING'" >&2; exit 1 ;;
esac
APP="$BUILD_DIR/$NAME.app"
DMG="$BUILD_DIR/$NAME.dmg"

# The shipped binaries' release flags, on these two command lines only: swift test and CI's bpulse
# build don't get them, and Package.swift holds only the language policy.
# - Export only _main. An executable without plug-ins that link back to it needs no exported
#   symbols; the export list makes every other global private, so each binary exports one name
#   instead of the about 4,200 public names of BatteryCore and BatteryKit. It doesn't shrink the
#   code: what -dead_strip keeps doesn't depend on the exports. The widget keeps _main too,
#   though it starts in _NSExtensionMain. Taking the list off the widget's line means taking
#   widget_other_exports out of size-report.sh's hygiene checks too.
# - -Osize: optimize for size. The app's hot paths are small, and the Linux benches of parsing
#   and the History store ran no slower with it.
RELEASE_FLAGS=(-Xswiftc -Osize -Xlinker -exported_symbol -Xlinker _main)
# Each link also writes a link map, which attributes every byte of the binary to an object file
# and a symbol (for size work; build/maps, a CI artifact). They sit next to the build products,
# so a link that is up to date keeps a map that matches its binary.
MAPS="$PWD/.build/link-maps"
mkdir -p "$MAPS"
swift build -c release "${RELEASE_FLAGS[@]}" --product BatteryPulse -Xlinker -map -Xlinker "$MAPS/BatteryPulse.map"
# SPIKE-W (0.6.2 WP-W0, W0-2, spike branch only): the widget's line also internalizes its public
# symbols at link time, as SPIKE-I's does, so SPIKE-W is SPIKE-I plus the configuration, and W0-2
# asks of Edit Widget what 0.7 would ship: strip, _main-only exports and -internalize-at-link.
swift build -c release "${RELEASE_FLAGS[@]}" -Xswiftc -Xfrontend -Xswiftc -internalize-at-link \
  --product BatteryPulseWidget -Xlinker -map -Xlinker "$MAPS/BatteryPulseWidget.map"
BIN_PATH="$(swift build -c release --product BatteryPulse --show-bin-path)"
BINARY="$BIN_PATH/BatteryPulse"

rm -rf "$BUILD_DIR"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources" "$BUILD_DIR/maps"
cp "$MAPS/BatteryPulse.map" "$MAPS/BatteryPulseWidget.map" "$BUILD_DIR/maps/"
cp "$BINARY" "$APP/Contents/MacOS/BatteryPulse"

# App icon: every size iconutil expects, rendered from the 1024 px master.
ICONSET="$BUILD_DIR/AppIcon.iconset"
mkdir -p "$ICONSET"
for size in 16 32 128 256 512; do
  sips -z "$size" "$size" Resources/AppIcon.png --out "$ICONSET/icon_${size}x${size}.png" >/dev/null
  double=$((size * 2))
  sips -z "$double" "$double" Resources/AppIcon.png --out "$ICONSET/icon_${size}x${size}@2x.png" >/dev/null
done
iconutil -c icns "$ICONSET" -o "$APP/Contents/Resources/AppIcon.icns"
rm -rf "$ICONSET"

# Localizations: compile the String Catalog into <language>.lproj folders, checked below once the
# widget has its copy. English is the source language, so its folder may come out empty; it still
# declares the localization.
xcrun xcstringstool compile --output-directory "$APP/Contents/Resources" Resources/Localizable.xcstrings
mkdir -p "$APP/Contents/Resources/en.lproj"

# LSUIElement: launch without a Dock icon, so the default menu-bar mode (and Open at login)
# never flashes one. DockIconPolicy promotes the app to a regular one at run time when the menu
# bar item is off, the Dock icon is on, or a window is open.
# Never add LSFileQuarantineEnabled: the in-app updater relies on the DMG it downloads not being
# quarantined, so the new version opens without Open Anyway.
cat > "$APP/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleDevelopmentRegion</key><string>en</string>
  <key>CFBundleDisplayName</key><string>BatteryPulse</string>
  <key>CFBundleExecutable</key><string>BatteryPulse</string>
  <key>CFBundleIconFile</key><string>AppIcon</string>
  <key>CFBundleIdentifier</key><string>$BUNDLE_ID</string>
  <key>CFBundleInfoDictionaryVersion</key><string>6.0</string>
  <key>CFBundleLocalizations</key><array><string>en</string><string>ru</string></array>
  <key>CFBundleName</key><string>BatteryPulse</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleShortVersionString</key><string>$VERSION</string>
  <key>CFBundleVersion</key><string>$BUILD_NUMBER</string>
  <key>LSApplicationCategoryType</key><string>public.app-category.utilities</string>
  <key>LSMinimumSystemVersion</key><string>27.0</string>
  <key>LSUIElement</key><true/>
  <key>NSHumanReadableCopyright</key><string>GNU GPL v3</string>
</dict>
</plist>
PLIST
plutil -lint "$APP/Contents/Info.plist" >/dev/null

# The widget extension: the SwiftPM executable wrapped into an .appex with its own Info.plist,
# strings and sandbox entitlement. WidgetKit caches by CFBundleVersion, so it matches the app's.
APPEX="$APP/Contents/PlugIns/BatteryPulseWidget.appex"
WIDGET="$APPEX/Contents/MacOS/BatteryPulseWidget"
mkdir -p "$APPEX/Contents/MacOS" "$APPEX/Contents/Resources"
cp "$BIN_PATH/BatteryPulseWidget" "$WIDGET"
cp -R "$APP/Contents/Resources/"*.lproj "$APPEX/Contents/Resources/"
# Both bundles must keep an en.lproj and, for each translation, a table with every catalog key.
# English ships no table while every one of its entries is its own key, as xcstringstool writes
# the strings keyed by their English text: a lookup without a table returns the key anyway. A
# table with any other entry is kept.
swift scripts/string-tables.swift Resources/Localizable.xcstrings "$APP/Contents/Resources" "$APPEX/Contents/Resources"
cat > "$APPEX/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleDevelopmentRegion</key><string>en</string>
  <key>CFBundleDisplayName</key><string>BatteryPulse</string>
  <key>CFBundleExecutable</key><string>BatteryPulseWidget</string>
  <key>CFBundleIdentifier</key><string>$BUNDLE_ID.Widget</string>
  <key>CFBundleInfoDictionaryVersion</key><string>6.0</string>
  <key>CFBundleLocalizations</key><array><string>en</string><string>ru</string></array>
  <key>CFBundleName</key><string>BatteryPulseWidget</string>
  <key>CFBundlePackageType</key><string>XPC!</string>
  <key>CFBundleShortVersionString</key><string>$VERSION</string>
  <key>CFBundleSupportedPlatforms</key><array><string>MacOSX</string></array>
  <key>CFBundleVersion</key><string>$BUILD_NUMBER</string>
  <key>LSMinimumSystemVersion</key><string>27.0</string>
  <key>NSExtension</key>
  <dict>
    <key>NSExtensionPointIdentifier</key><string>com.apple.widgetkit-extension</string>
  </dict>
</dict>
</plist>
PLIST
plutil -lint "$APPEX/Contents/Info.plist" >/dev/null

# Both halves of the extension entry point must be there: linked to start in _NSExtensionMain,
# and the WidgetBundle kept in the binary by @main. They read the unstripped binary in $BIN_PATH:
# the bundle copy loses these symbols below. Output is captured first so an early grep exit
# can't fail the pipeline.
SYMBOLS="$(nm -m "$BIN_PATH/BatteryPulseWidget")"
if ! grep -F "_NSExtensionMain" <<<"$SYMBOLS" >/dev/null; then
  echo "error: the widget is not linked through _NSExtensionMain" >&2
  exit 1
fi
DEMANGLED="$(nm "$BIN_PATH/BatteryPulseWidget" | xcrun swift-demangle)"
if ! grep -F "BatteryPulseWidget.BatteryPulseWidgets" <<<"$DEMANGLED" >/dev/null; then
  echo "error: the WidgetBundle is missing from the widget binary" >&2
  exit 1
fi

# App Intents metadata (W0-1, spike branch only). Xcode extracts it after linking a target that
# declares intents; swift build never does, because SwiftPM sets LM_SKIP_METADATA_EXTRACTION. So
# this runs Apple's processor with the options of Xcode's AppIntentsMetadata.xcspec, on the
# unstripped widget binary and the inputs Swift Build left: the widget module's Swift sources and
# the compiler's const values (*.swiftconstvalues, which Swift Build emits for the App Intents
# protocols). It writes $APPEX/Contents/Resources/Metadata.appintents before the widget is
# signed. The processor can exit with 0 without writing anything: CI's check fails then.
INTENTS="$PWD/.build/appintents"
rm -rf "$INTENTS"
mkdir -p "$INTENTS"
# The release build's intermediates of the widget module, such as
# .build/out/Intermediates.noindex/BatteryPulse.build/Release/BatteryPulseWidget-p.build/Objects-normal/arm64.
WIDGET_OBJECTS="$(find "$PWD/.build/out/Intermediates.noindex" -type d -path '*/Release/BatteryPulseWidget*.build/Objects-normal/arm64' | head -1)"
if [ -z "$WIDGET_OBJECTS" ]; then
  echo "error: no release intermediates of the widget module under .build/out" >&2
  exit 1
fi
find "$PWD/Sources/BatteryPulseWidget" -name '*.swift' | sort >"$INTENTS/BatteryPulseWidget.SwiftFileList"
find "$WIDGET_OBJECTS" -maxdepth 1 -name '*.swiftconstvalues' | sort >"$INTENTS/BatteryPulseWidget.SwiftConstValuesFileList"
if [ ! -s "$INTENTS/BatteryPulseWidget.SwiftConstValuesFileList" ]; then
  echo "error: Swift Build left no .swiftconstvalues in $WIDGET_OBJECTS" >&2
  exit 1
fi
# No dependency has App Intents metadata of its own: both lists stay empty.
: >"$INTENTS/BatteryPulseWidget.DependencyMetadataFileList"
: >"$INTENTS/BatteryPulseWidget.DependencyStaticMetadataFileList"
echo "App Intents inputs: $(wc -l <"$INTENTS/BatteryPulseWidget.SwiftFileList" | tr -d ' ') sources; const values:"
cat "$INTENTS/BatteryPulseWidget.SwiftConstValuesFileList"
# An empty array expands with the ${a[@]+…} form below: macOS's bash 3.2 calls a plain "${a[@]}"
# unbound under set -u.
DEPENDENCY_INFO=()
if [ -f "$WIDGET_OBJECTS/BatteryPulseWidget_dependency_info.dat" ]; then
  DEPENDENCY_INFO=(--dependency-file "$WIDGET_OBJECTS/BatteryPulseWidget_dependency_info.dat")
fi
TOOLCHAIN_DIR="$(cd "$(dirname "$(xcrun --find swiftc)")/../.." && pwd)"
XCODE_BUILD_VERSION="$(xcodebuild -version | awk '/^Build version/ { print $3 }')"
DEPLOYMENT_TARGET=27.0
PROCESSOR=(
  "$(xcrun --find appintentsmetadataprocessor)"
  --toolchain-dir "$TOOLCHAIN_DIR"
  --module-name BatteryPulseWidget
  --sdk-root "$(xcrun --sdk macosx --show-sdk-path)"
  --xcode-version "$XCODE_BUILD_VERSION"
  --platform-family macOS
  --deployment-target "$DEPLOYMENT_TARGET"
  --bundle-identifier "$BUNDLE_ID.Widget"
  --output "$APPEX/Contents/Resources"
  --target-triple "arm64-apple-macos$DEPLOYMENT_TARGET"
  --binary-file "$BIN_PATH/BatteryPulseWidget"
  ${DEPENDENCY_INFO[@]+"${DEPENDENCY_INFO[@]}"}
  --stringsdata-file "$INTENTS/ExtractedAppShortcutsMetadata.stringsdata"
  --source-file-list "$INTENTS/BatteryPulseWidget.SwiftFileList"
  --metadata-file-list "$INTENTS/BatteryPulseWidget.DependencyMetadataFileList"
  --static-metadata-file-list "$INTENTS/BatteryPulseWidget.DependencyStaticMetadataFileList"
  --swift-const-vals-list "$INTENTS/BatteryPulseWidget.SwiftConstValuesFileList"
  --compile-time-extraction
  --deployment-aware-processing
  --no-app-shortcuts-localization
)
echo "App Intents metadata: ${PROCESSOR[*]}"
"${PROCESSOR[@]}"
if [ -d "$APPEX/Contents/Resources/Metadata.appintents" ]; then
  ls -l "$APPEX/Contents/Resources/Metadata.appintents"
else
  echo "warning: the processor wrote no Metadata.appintents" >&2
fi

# Ship stripped executables: the symbol table and the debug map serve debugging and crash
# symbolication, not the running app, and they carry the build machine's paths. The dSYMs keep
# them, tied to each binary by its UUID, and go into $NAME-dSYMs.zip (a CI artifact and a release
# asset). strip -x removes the local symbols; the export list left _main the only global one
# besides the imports, so _main stays exported (a plain strip would remove it too). A profiling
# build keeps its symbols for Instruments and the memory tools.
DSYMS="$BUILD_DIR/dSYMs"
mkdir -p "$DSYMS"
uuids() { xcrun dwarfdump --uuid "$1" | awk '{ print $2 }' | sort | tr '\n' ' '; }
for product in BatteryPulse BatteryPulseWidget; do
  # Swift Build writes a dSYM next to each release product; dsymutil makes one if that is missing
  # or belongs to an older link.
  if [ -d "$BIN_PATH/$product.dSYM" ] && [ "$(uuids "$BIN_PATH/$product.dSYM")" = "$(uuids "$BIN_PATH/$product")" ]; then
    cp -R "$BIN_PATH/$product.dSYM" "$DSYMS/"
    echo "$product.dSYM: from $BIN_PATH"
  else
    xcrun dsymutil "$BIN_PATH/$product" -o "$DSYMS/$product.dSYM"
    echo "$product.dSYM: made by dsymutil"
  fi
done
if [ "$PROFILING" = 0 ]; then
  xcrun strip -x "$APP/Contents/MacOS/BatteryPulse" "$WIDGET"
fi
for product in BatteryPulse BatteryPulseWidget; do
  binary="$APP/Contents/MacOS/BatteryPulse"
  [ "$product" = BatteryPulse ] || binary="$WIDGET"
  expected="$(uuids "$binary")"
  if [ -z "${expected// /}" ] || [ "$(uuids "$DSYMS/$product.dSYM")" != "$expected" ]; then
    echo "error: $product.dSYM doesn't match the binary in the bundle" >&2
    exit 1
  fi
  echo "$product.dSYM matches the binary in the bundle: UUID ${expected% }"
done
ditto -c -k "$DSYMS" "$BUILD_DIR/$NAME-dSYMs.zip"
rm -rf "$DSYMS"

# Inside out, and never --deep when signing: it would re-sign the widget without its
# entitlements.
codesign --force --sign - --options runtime --entitlements Resources/BatteryPulseWidget.entitlements "$APPEX"
if [ "$PROFILING" = 1 ]; then
  PROFILING_ENTITLEMENTS="$BUILD_DIR/profiling.entitlements"
  cat > "$PROFILING_ENTITLEMENTS" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>com.apple.security.get-task-allow</key><true/>
</dict>
</plist>
PLIST
  codesign --force --sign - --options runtime --entitlements "$PROFILING_ENTITLEMENTS" "$APP"
  rm "$PROFILING_ENTITLEMENTS"
else
  codesign --force --sign - --options runtime "$APP"
fi
codesign --verify --strict --deep "$APP"

# The signing posture, checked on every build so that a weaker one can't ship:
# - both bundles run with the hardened runtime;
# - neither is signed with get-task-allow, except the app of a profiling build;
# - the app has no entitlements (a profiling build: get-task-allow alone), and the widget exactly
#   the ones in its file, which include the sandbox;
# - neither Info.plist has LSFileQuarantineEnabled (an in-app update would then need Open
#   Anyway) or NSAppTransportSecurity (an exception to App Transport Security).
# Entitlements are compared as XML plists that plutil has rewritten, so neither the key order nor
# codesign's formatting matters. Every violation is listed before the build fails.
POSTURE="$BUILD_DIR/posture"
mkdir -p "$POSTURE"
cat > "$POSTURE/none.entitlements" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict/>
</plist>
PLIST
# What a profiling build's app may have, written here rather than read from the file it was signed
# with, so an entitlement added to that file fails the check too.
cat > "$POSTURE/profiling.entitlements" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>com.apple.security.get-task-allow</key><true/>
</dict>
</plist>
PLIST
# normalize <plist> <name>: the plist as plutil writes it, in $POSTURE/<name>.plist.
normalize() { plutil -convert xml1 -o "$POSTURE/$2.plist" "$1"; }
# signed_entitlements <bundle> <name>: the bundle's entitlements, normalized; an empty dictionary
# when it has none.
signed_entitlements() {
  if ! codesign -d --entitlements - --xml "$1" >"$POSTURE/$2.signed" 2>"$POSTURE/$2.log"; then
    cat "$POSTURE/$2.log" >&2
    echo "error: can't read the entitlements of $1" >&2
    exit 1
  fi
  [ -s "$POSTURE/$2.signed" ] || cp "$POSTURE/none.entitlements" "$POSTURE/$2.signed"
  normalize "$POSTURE/$2.signed" "$2"
}
signed_entitlements "$APP" app
signed_entitlements "$APPEX" widget
normalize Resources/BatteryPulseWidget.entitlements widget-expected
if [ "$PROFILING" = 1 ]; then
  normalize "$POSTURE/profiling.entitlements" app-expected
else
  normalize "$POSTURE/none.entitlements" app-expected
fi
violations=0
violation() {
  echo "error: $1" >&2
  violations=$((violations + 1))
}
for bundle in "$APP" "$APPEX"; do
  # The code directory's flags, for example flags=0x10002(adhoc,runtime).
  details="$(codesign -dv "$bundle" 2>&1)"
  grep -Eq 'flags=0x[0-9a-fA-F]+\([^)]*runtime' <<<"$details" || violation "$bundle lacks the hardened runtime"
done
if grep -F "com.apple.security.get-task-allow" "$POSTURE/widget.plist" >/dev/null; then
  violation "the widget is signed with get-task-allow"
fi
if [ "$PROFILING" = 0 ] && grep -F "com.apple.security.get-task-allow" "$POSTURE/app.plist" >/dev/null; then
  violation "the app is signed with get-task-allow, which only a profiling build may have"
fi
if ! cmp -s "$POSTURE/app-expected.plist" "$POSTURE/app.plist"; then
  if [ "$PROFILING" = 1 ]; then
    violation "the app's entitlements must be get-task-allow alone (expected < > signed):"
  else
    violation "the app must have no entitlements (expected < > signed):"
  fi
  diff "$POSTURE/app-expected.plist" "$POSTURE/app.plist" >&2 || true
fi
if ! cmp -s "$POSTURE/widget-expected.plist" "$POSTURE/widget.plist"; then
  violation "the widget's entitlements differ from Resources/BatteryPulseWidget.entitlements (file < > signed):"
  diff "$POSTURE/widget-expected.plist" "$POSTURE/widget.plist" >&2 || true
fi
if ! grep -F "com.apple.security.app-sandbox" "$POSTURE/widget.plist" >/dev/null; then
  violation "the widget is not sandboxed"
fi
for plist in "$APP/Contents/Info.plist" "$APPEX/Contents/Info.plist"; do
  for key in LSFileQuarantineEnabled NSAppTransportSecurity; do
    if plutil -extract "$key" xml1 -o - "$plist" >/dev/null 2>&1; then
      violation "$plist must not contain $key"
    fi
  done
done
rm -rf "$POSTURE"
if [ "$violations" -gt 0 ]; then
  echo "error: the signing posture is wrong (violations: $violations)" >&2
  exit 1
fi
echo "Signing posture: hardened runtime, the expected entitlements, no quarantine or ATS keys"

# Drag-to-install DMG: the app next to a link to /Applications. It is ULMO (LZMA), the smallest
# compressed format hdiutil makes, which macOS 10.15 and later attach; every BatteryPulse updater
# attaches it with /usr/bin/hdiutil, and the signature covers the file's bytes whatever the format.
# It is made the space-optimal way hdiutil(1) documents: a read/write image of the folder, then a
# conversion, so the compressed image holds no unused space.
STAGING="$BUILD_DIR/dmg"
READ_WRITE="$BUILD_DIR/$NAME-rw.dmg"
mkdir -p "$STAGING"
cp -R "$APP" "$STAGING/"
ln -s /Applications "$STAGING/Applications"
# hdiutil occasionally fails with "Resource busy" right after the files were written
# (seen on hosted CI runners), so flush and retry. The conversion reads an image hdiutil has just
# written, so it is retried with the creation.
sync
for attempt in 1 2 3 4 5; do
  hdiutil create -quiet -volname "BatteryPulse" -srcfolder "$STAGING" -ov -format UDRW "$READ_WRITE" \
    && hdiutil convert -quiet "$READ_WRITE" -format ULMO -ov -o "$DMG" && break
  [ "$attempt" -eq 5 ] && exit 1
  sleep 5
done
rm -rf "$STAGING" "$READ_WRITE"

echo "Built $APP and $DMG ($VERSION, build $BUILD_NUMBER)"
