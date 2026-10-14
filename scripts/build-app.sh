#!/bin/bash
# Builds build/BatteryPulse.app and build/BatteryPulse.dmg (macOS only).
#
#   scripts/build-app.sh            # version 0.1.0, build 1
#   VERSION=0.2.0 BUILD_NUMBER=7 scripts/build-app.sh
#
# The app is ad-hoc signed. A notarized build needs a Developer ID certificate; until then,
# a downloaded copy must be approved once in System Settings → Privacy & Security.
set -euo pipefail

cd "$(dirname "$0")/.."

VERSION="${VERSION:-0.1.0}"
BUILD_NUMBER="${BUILD_NUMBER:-1}"
BUNDLE_ID="io.github.nikitausov.BatteryPulse"
BUILD_DIR="build"
APP="$BUILD_DIR/BatteryPulse.app"
DMG="$BUILD_DIR/BatteryPulse.dmg"

swift build -c release --product BatteryPulse
BINARY="$(swift build -c release --product BatteryPulse --show-bin-path)/BatteryPulse"

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

codesign --force --sign - --options runtime "$APP"
codesign --verify --strict "$APP"

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
