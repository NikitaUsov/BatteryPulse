#!/bin/bash
# Installs the Swift toolchain in Claude Code cloud sessions so `swift build` / `swift test`
# work, then warms the build cache. Local machines (Xcode) are left alone.
set -euo pipefail

if [ "${CLAUDE_CODE_REMOTE:-}" != "true" ]; then
  exit 0
fi

SWIFT_VERSION="6.4.1"
INSTALL_ROOT="/opt/swift"

. /etc/os-release
case "${ID}-${VERSION_ID}" in
  ubuntu-22.04|ubuntu-24.04) platform="ubuntu${VERSION_ID//./}"; suffix="ubuntu${VERSION_ID}" ;;
  *) echo "session-start: unsupported OS ${ID} ${VERSION_ID}, skipping Swift install" >&2; exit 0 ;;
esac

toolchain="$INSTALL_ROOT/swift-$SWIFT_VERSION-RELEASE-$suffix"
if ! "$toolchain/usr/bin/swift" --version >/dev/null 2>&1; then
  mkdir -p "$INSTALL_ROOT"
  archive="$(mktemp)"
  trap 'rm -f "$archive"' EXIT
  curl -fsSL --retry 4 -o "$archive" \
    "https://download.swift.org/swift-$SWIFT_VERSION-release/$platform/swift-$SWIFT_VERSION-RELEASE/swift-$SWIFT_VERSION-RELEASE-$suffix.tar.gz"
  tar -xzf "$archive" -C "$INSTALL_ROOT"
fi

if [ -n "${CLAUDE_ENV_FILE:-}" ]; then
  echo "export PATH=\"$toolchain/usr/bin:\$PATH\"" >> "$CLAUDE_ENV_FILE"
fi

cd "${CLAUDE_PROJECT_DIR:-$(dirname "$0")/../..}"
"$toolchain/usr/bin/swift" build --build-tests
