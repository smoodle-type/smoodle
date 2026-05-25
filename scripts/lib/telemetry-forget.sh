#!/usr/bin/env bash
# smoodle telemetry forget — delete server-side events for this install (TELEM-06)
#
# Usage: bash scripts/lib/telemetry-forget.sh
# Sends DELETE to the forget-api sidecar, then removes local telemetry files.
# Idempotent: running twice exits 0 with "No telemetry data found."

set -euo pipefail

INSTALL_ID_FILE="${HOME}/.smoodle/install_id"
TELEMETRY_MARKER="${HOME}/.smoodle/telemetry-on"
FORGET_TOKEN_FILE="${HOME}/.smoodle/forget_token"
FORGET_URL="${SMOODLE_FORGET_URL:-https://forget.0dl.me/api/forget}"

# Bearer token: env var wins, then file, else empty (server may still accept
# in dogfood/legacy mode where FORGET_BEARER_TOKEN is unset server-side).
FORGET_TOKEN="${SMOODLE_FORGET_TOKEN:-}"
if [ -z "$FORGET_TOKEN" ] && [ -f "$FORGET_TOKEN_FILE" ]; then
  FORGET_TOKEN="$(cat "$FORGET_TOKEN_FILE")"
fi

if [ ! -f "$INSTALL_ID_FILE" ]; then
  echo "No telemetry data found (no install_id)."
  echo "If you previously opted in, events may have already been purged."
  exit 0
fi

INSTALL_ID_HASH="$(cat "$INSTALL_ID_FILE")"

echo "Deleting telemetry events for this install..."
echo "  install_id_hash: ${INSTALL_ID_HASH:0:16}..."

curl_args=(-fsS -X DELETE "${FORGET_URL}?install_id_hash=${INSTALL_ID_HASH}")
if [ -n "$FORGET_TOKEN" ]; then
  curl_args+=(-H "Authorization: Bearer ${FORGET_TOKEN}")
fi
RESPONSE=$(curl "${curl_args[@]}" 2>&1 || true)

if echo "$RESPONSE" | grep -q '"deleted"'; then
  DELETED_COUNT=$(echo "$RESPONSE" | python3 -c "import sys,json; print(json.load(sys.stdin).get('deleted', 0))" 2>/dev/null || echo "?")
  echo "  Deleted ${DELETED_COUNT} event(s) from server."
else
  echo "  [WARN] forget API response: ${RESPONSE}"
  echo "  Events may still have been deleted. Proceeding with local cleanup."
fi

# Remove local telemetry files (install_id, opt-in marker, bearer token).
rm -f "$INSTALL_ID_FILE" "$TELEMETRY_MARKER" "$FORGET_TOKEN_FILE"
echo "  Local telemetry files removed."
echo "Done."
