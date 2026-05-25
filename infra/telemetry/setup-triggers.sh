#!/usr/bin/env bash
# Apply Postgres triggers for telemetry privacy (TELEM-07).
# Must run AFTER umami's Prisma migrations complete (tables exist).
#
# Usage (default — runs against docker context th-dc):
#   bash infra/telemetry/setup-triggers.sh
# Override context:
#   SMOODLE_DC_CONTEXT=other bash infra/telemetry/setup-triggers.sh
# Direct mode (no --context, e.g. running on the docker host itself):
#   SMOODLE_DC_DIRECT=1 SMOODLE_PG_CONTAINER=umami-db bash infra/telemetry/setup-triggers.sh

set -euo pipefail

CONTEXT="${SMOODLE_DC_CONTEXT:-th-dc}"
PG_CONTAINER="${SMOODLE_PG_CONTAINER:-smoodle-telemetry-postgres}"

if [[ "${SMOODLE_DC_DIRECT:-0}" == "1" ]]; then
  docker_cmd=(docker exec -i "$PG_CONTAINER")
else
  docker_cmd=(docker --context "$CONTEXT" exec -i "$PG_CONTAINER")
fi

"${docker_cmd[@]}" psql -U umami -d umami <<'SQL'

-- TELEM-07: Timestamp rounding (nearest hour)
CREATE OR REPLACE FUNCTION round_event_timestamp()
RETURNS TRIGGER AS $$
BEGIN
  NEW.created_at = date_trunc('hour', NEW.created_at);
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_round_timestamp ON website_event;
CREATE TRIGGER trg_round_timestamp
  BEFORE INSERT ON website_event
  FOR EACH ROW
  EXECUTE FUNCTION round_event_timestamp();

-- Also round session timestamps
CREATE OR REPLACE FUNCTION round_session_timestamp()
RETURNS TRIGGER AS $$
BEGIN
  NEW.created_at = date_trunc('hour', NEW.created_at);
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_round_session_timestamp ON session;
CREATE TRIGGER trg_round_session_timestamp
  BEFORE INSERT ON session
  FOR EACH ROW
  EXECUTE FUNCTION round_session_timestamp();

-- TELEM-07: Hostname NULL (defense-in-depth — umami doesn't store IPs in
-- website_event, but hostname could be reverse-DNS'd; remove it entirely).
-- Only applied to website_event: umami v3.1.0+ removed `hostname` from the
-- session table (verified on dxc 2026-05-25), so the equivalent session
-- trigger would error with `record "new" has no field "hostname"`.
CREATE OR REPLACE FUNCTION null_hostname()
RETURNS TRIGGER AS $$
BEGIN
  NEW.hostname = NULL;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_null_hostname ON website_event;
CREATE TRIGGER trg_null_hostname
  BEFORE INSERT ON website_event
  FOR EACH ROW
  EXECUTE FUNCTION null_hostname();

-- Drop legacy session.hostname trigger from older umami versions (idempotent
-- — no-op if it never existed). Required for the script to be re-runnable
-- against DBs that may have the obsolete trigger from a previous deploy.
DROP TRIGGER IF EXISTS trg_null_session_hostname ON session;
DROP FUNCTION IF EXISTS null_session_hostname();

SQL

echo "  [OK] triggers applied."
