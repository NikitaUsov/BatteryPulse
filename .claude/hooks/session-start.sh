#!/bin/bash
# Installs the Swift toolchain in Claude Code cloud sessions so `swift build` / `swift test`
# work, then warms the build cache. Local machines (Xcode) are left alone.
set -euo pipefail

if [ "${CLAUDE_CODE_REMOTE:-}" != "true" ]; then
  exit 0
fi

SWIFT_VERSION="6.4.2"
INSTALL_ROOT="/opt/swift"

. /etc/os-release
case "${ID}-${VERSION_ID}" in
  ubuntu-22.04|ubuntu-24.04) platform="ubuntu${VERSION_ID//./}"; suffix="ubuntu${VERSION_ID}" ;;
  *) echo "session-start: unsupported OS ${ID} ${VERSION_ID}, skipping Swift install" >&2; exit 0 ;;
esac

toolchain="$INSTALL_ROOT/swift-$SWIFT_VERSION-RELEASE-$suffix"
# The marker is written only after a complete extraction: an interrupted tar leaves a tree in
# which `swift --version` works but `swift build` doesn't.
if [ ! -f "$toolchain/.complete" ]; then
  mkdir -p "$INSTALL_ROOT"
  archive="$(mktemp)"
  staging="$(mktemp -d "$INSTALL_ROOT/.staging.XXXXXX")"
  trap 'rm -rf "$archive" "$staging"' EXIT
  curl -fsSL --retry 4 -o "$archive" \
    "https://download.swift.org/swift-$SWIFT_VERSION-release/$platform/swift-$SWIFT_VERSION-RELEASE/swift-$SWIFT_VERSION-RELEASE-$suffix.tar.gz"
  tar -xzf "$archive" -C "$staging"
  rm -rf "$toolchain"
  mv "$staging/$(basename "$toolchain")" "$toolchain"
  touch "$toolchain/.complete"
fi

if [ -n "${CLAUDE_ENV_FILE:-}" ]; then
  echo "export PATH=\"$toolchain/usr/bin:\$PATH\"" >> "$CLAUDE_ENV_FILE"
fi

cd "${CLAUDE_PROJECT_DIR:-$(dirname "$0")/../..}"
"$toolchain/usr/bin/swift" build --build-tests
