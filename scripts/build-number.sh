#!/bin/bash
# Prints the build number, the CFBundleVersion of the app and its widget (scripts/build-app.sh's
# BUILD_NUMBER): whole seconds since 2026-01-01T00:00:00Z, a clock that only grows.
#
#   BUILD_NUMBER="$(scripts/build-number.sh)" scripts/build-app.sh
#
# ci.yml's builds and release.yml's releases read the same clock, so every build sits above every
# earlier one, whichever workflow made it: WidgetKit caches a widget's description by
# CFBundleVersion, and a release numbered below a candidate installed before it could keep that
# candidate's description. Each workflow reads it once per job, before its first packaging step.
# Seconds, not minutes, so two builds dispatched back to back don't share a number. The value is
# a single integer, a valid CFBundleVersion, and stays within Int32 until 2094.
set -euo pipefail

# 2026-01-01T00:00:00Z.
EPOCH=1767225600

now="$(date -u +%s)"
if ! [[ "$now" =~ ^[0-9]+$ ]] || [ "$now" -le "$EPOCH" ]; then
  echo "error: the clock reads '$now', not a time after 2026-01-01" >&2
  exit 1
fi
echo "$((now - EPOCH))"
