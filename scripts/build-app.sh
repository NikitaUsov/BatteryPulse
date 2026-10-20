#!/bin/bash
# Builds build/BatteryPulse.app and build/BatteryPulse.dmg (macOS only).
#
#   scripts/build-app.sh            # version from the latest git tag, build 1
#   VERSION=0.2.0 BUILD_NUMBER=7 scripts/build-app.sh
#   PROFILING=1 scripts/build-app.sh   # build/BatteryPulse-profiling.{app,dmg}, see below
#
# The app is ad-hoc signed. A notarized build needs a Developer ID certificate; until then,
# each downloaded version must be approved once in System Settings → Privacy & Security.
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

swift build -c release --product BatteryPulse
swift build -c release --product BatteryPulseWidget
BIN_PATH="$(swift build -c release --product BatteryPulse --show-bin-path)"
BINARY="$BIN_PATH/BatteryPulse"

rm -rf "$BUILD_DIR"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
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

# Localizations: compile the String Catalog into <language>.lproj folders. English is the
# source language, so its folder may come out empty; it still declares the localization.
xcrun xcstringstool compile --output-directory "$APP/Contents/Resources" Resources/Localizable.xcstrings
mkdir -p "$APP/Contents/Resources/en.lproj"
if ! ls "$APP/Contents/Resources/ru.lproj/"Localizable.* >/dev/null 2>&1; then
  echo "error: the Russian localization was not compiled" >&2
  exit 1
fi

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

# Ship stripped executables: the symbol table and the debug map serve debugging and crash
# symbolication, not the running app, and they carry the build machine's paths. The dSYMs keep
# them, tied to each binary by its UUID, and go into $NAME-dSYMs.zip (a CI artifact and a release
# asset). A profiling build keeps its symbols for Instruments and the memory tools.
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
  xcrun strip "$APP/Contents/MacOS/BatteryPulse" "$WIDGET"
fi
for product in BatteryPulse BatteryPulseWidget; do
  binary="$APP/Contents/MacOS/BatteryPulse"
  [ "$product" = BatteryPulse ] || binary="$WIDGET"
  expected="$(uuids "$binary")"
  if [ -z "${expected// /}" ] || [ "$(uuids "$DSYMS/$product.dSYM")" != "$expected" ]; then
    echo "error: $product.dSYM doesn't match the binary in the bundle" >&2
    exit 1
  fi
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
ENTITLEMENTS="$(codesign -d --entitlements - "$APPEX" 2>/dev/null)"
if ! grep -F "com.apple.security.app-sandbox" <<<"$ENTITLEMENTS" >/dev/null; then
  echo "error: the widget is not sandboxed" >&2
  exit 1
fi

# Drag-to-install DMG: the app next to a link to /Applications.
STAGING="$BUILD_DIR/dmg"
mkdir -p "$STAGING"
cp -R "$APP" "$STAGING/"
ln -s /Applications "$STAGING/Applications"
# hdiutil occasionally fails with "Resource busy" right after the files were written
# (seen on hosted CI runners), so flush and retry.
sync
for attempt in 1 2 3 4 5; do
  hdiutil create -quiet -volname "BatteryPulse" -srcfolder "$STAGING" -ov -format UDZO "$DMG" && break
  [ "$attempt" -eq 5 ] && exit 1
  sleep 5
done
rm -rf "$STAGING"

echo "Built $APP and $DMG ($VERSION, build $BUILD_NUMBER)"
