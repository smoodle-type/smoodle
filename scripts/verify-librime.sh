#!/usr/bin/env bash
# scripts/verify-librime.sh -- HARDEN-01: manual hash-drift checker for macOS
# Run this script when Thai ranking "feels wrong" after a Squirrel auto-update.
# Exit codes: 0 = clean, 1 = drift detected, 2 = precondition failure.
# NO LaunchAgent, NO daemon -- per CP-1. Manual probe only.

set -euo pipefail

# Dylib path: same canonical path install-librime-fork.sh uses, with env override.
SQUIRREL_DYLIB="${SMOODLE_SQUIRREL_PATH:-/Library/Input Methods/Squirrel.app}/Contents/Frameworks/librime.1.dylib"

# Sidecar: env override for testing; default is the vendored file from Phase 2.
SIDECAR="${SMOODLE_SHA256_SIDECAR:-$(dirname "$0")/../vendor/macos/librime.1.dylib.sha256}"

# 1. Check dylib exists
if [ ! -f "$SQUIRREL_DYLIB" ]; then
  echo "ERROR: librime.1.dylib not found at ${SQUIRREL_DYLIB}"
  echo "       Is Squirrel.app installed at the expected location?"
  exit 2
fi

# 2. Check sidecar exists
if [ ! -f "$SIDECAR" ]; then
  echo "ERROR: SHA256 sidecar not found at ${SIDECAR}"
  echo "       Run install-librime-fork.sh first to populate the sidecar."
  exit 2
fi
EXPECTED_SHA="$(awk '{print $1}' "$SIDECAR")"

# 3. Compute actual SHA
ACTUAL_SHA="$(shasum -a 256 "$SQUIRREL_DYLIB" | awk '{print $1}')"

# 4. Compare
if [ "$EXPECTED_SHA" != "$ACTUAL_SHA" ]; then
  echo "WARN: librime.1.dylib drift detected."
  echo "  expected: ${EXPECTED_SHA}"
  echo "  actual:   ${ACTUAL_SHA}"
  echo ""
  echo "Sparkle may have overwritten the smoodle-patched dylib."
  echo "Re-run to reapply the patch:"
  echo "  bash scripts/install-librime-fork.sh"
  exit 1
fi

echo "OK: librime.1.dylib hash matches expected"
exit 0
