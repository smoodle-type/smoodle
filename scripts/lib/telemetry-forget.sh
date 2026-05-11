#!/usr/bin/env bash
# smoodle telemetry forget — delete server-side events for this install (TELEM-06)
#
# Usage: bash scripts/lib/telemetry-forget.sh
# Sends DELETE to the forget-api sidecar, then removes local telemetry files.
# Idempotent: running twice exits 0 with "No telemetry data found."

set -euo pipefail

INSTALL_ID_FILE="${HOME}/.smoodle/install_id"
TELEMETRY_MARKER="${HOME}/.smoodle/telemetry-on"
FORGET_URL="${SMOODLE_FORGET_URL:-http://localhost:8080/api/forget}"

if [ ! -f "$INSTALL_ID_FILE" ]; then
  echo "No telemetry data found (no install_id)."
  echo "If you previously opted in, events may have already been purged."
  exit 0
fi

INSTALL_ID_HASH="$(cat "$INSTALL_ID_FILE")"

echo "Deleting telemetry events for this install..."
echo "  install_id_hash: ${INSTALL_ID_HASH:0:16}..."

RESPONSE=$(curl -fsS -X DELETE \
  "${FORGET_URL}?install_id_hash=${INSTALL_ID_HASH}" 2>&1 || true)

if echo "$RESPONSE" | grep -q '"deleted"'; then
  DELETED_COUNT=$(echo "$RESPONSE" | python3 -c "import sys,json; print(json.load(sys.stdin).get('deleted', 0))" 2>/dev/null || echo "?")
  echo "  Deleted ${DELETED_COUNT} event(s) from server."
else
  echo "  [WARN] forget API response: ${RESPONSE}"
  echo "  Events may still have been deleted. Proceeding with local cleanup."
fi

# Remove local telemetry files.
rm -f "$INSTALL_ID_FILE" "$TELEMETRY_MARKER"
echo "  Local telemetry files removed."
echo "Done."
