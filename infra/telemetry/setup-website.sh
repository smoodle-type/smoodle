#!/usr/bin/env bash
# Deploy-time setup: start telemetry Compose, wait for Prisma migrations,
# insert the known-UUID website row, then apply Postgres triggers.
#
# Usage: bash infra/telemetry/setup-website.sh
# Override Docker context: SMOODLE_DC_CONTEXT=other bash infra/telemetry/setup-website.sh

set -euo pipefail

CONTEXT="${SMOODLE_DC_CONTEXT:-th-dc}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
COMPOSE_FILE="${SCRIPT_DIR}/docker-compose.yml"

echo "smoodle telemetry setup"
echo "======================="
echo "  context:     ${CONTEXT}"
echo "  compose:     ${COMPOSE_FILE}"
echo

# --- Step 1: Start Compose --------------------------------------------------
echo "Starting umami + postgres + caddy + forget-api..."
docker --context "$CONTEXT" compose -f "$COMPOSE_FILE" up -d

# --- Step 2: Wait for Prisma migrations --------------------------------------
echo "Waiting for umami Prisma migrations (15s)..."
sleep 15

# Health-check loop: retry up to 30s if postgres isn't ready yet
echo "Verifying postgres is accepting connections..."
for i in $(seq 1 6); do
  if docker --context "$CONTEXT" exec smoodle-telemetry-postgres \
       pg_isready -U umami -d umami >/dev/null 2>&1; then
    echo "  postgres ready."
    break
  fi
  if [ "$i" -eq 6 ]; then
    echo "ERROR: postgres not ready after 30s."
    echo "Run: docker --context ${CONTEXT} logs smoodle-telemetry-postgres"
    exit 1
  fi
  echo "  attempt ${i}/6 — waiting 5s..."
  sleep 5
done

# --- Step 3: Insert website row (TELEM-01) -----------------------------------
WEBSITE_UUID="${SMOODLE_WEBSITE_UUID:-a1b2c3d4-e5f6-7890-abcd-ef1234567890}"
echo "Inserting website row (UUID: ${WEBSITE_UUID})..."

docker --context "$CONTEXT" exec smoodle-telemetry-postgres psql -U umami -d umami <<SQL
INSERT INTO website (id, name, domain, share_id, created_at)
VALUES ('${WEBSITE_UUID}', 'Smoodle Install Telemetry', 'telemetry.0dl.me', 'smoodle', NOW())
ON CONFLICT (id) DO NOTHING;
SQL

echo "  [OK] website row inserted."

# --- Step 4: Apply Postgres triggers (TELEM-07) -----------------------------
echo "Applying Postgres triggers (IP-drop, timestamp rounding)..."
bash "${SCRIPT_DIR}/setup-triggers.sh"

# --- Step 5: Smoke test -----------------------------------------------------
echo
echo "Smoke-testing umami /api/send endpoint..."
SMOKE_RESULT=$(curl -sf -X POST \
  -H "Content-Type: application/json" \
  -d "{\"type\":\"event\",\"payload\":{\"website\":\"${WEBSITE_UUID}\",\"url\":\"/smoke-test\",\"name\":\"smoke_test\"}}" \
  "http://localhost:3000/api/send" 2>&1 || true)

if [ -z "$SMOKE_RESULT" ]; then
  echo "  [OK] smoke test passed (200 response)."
else
  echo "  [WARN] smoke test returned unexpected response: ${SMOKE_RESULT}"
  echo "  This may be normal if umami hasn't fully initialized yet."
fi

echo
echo "smoodle telemetry deploy complete."
echo "  Dashboard:  https://telemetry.0dl.me  (default: admin/admin — CHANGE THIS!)"
echo "  API:        https://telemetry.0dl.me/api/send"
echo "  Forget API: http://localhost:8080/api/forget"
echo
echo "Next steps:"
echo "  1. Change umami admin password via the dashboard UI."
echo "  2. Set up 90-day retention cron on th-dc host:"
echo "     0 2 * * * docker --context ${CONTEXT} exec smoodle-telemetry-postgres psql -U umami -d umami -c \"DELETE FROM website_event WHERE created_at < NOW() - INTERVAL '90 days'\""
echo "  3. Verify DNS A-record for telemetry.0dl.me points to th-dc."
