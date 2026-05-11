#!/usr/bin/env bash
# Apply Postgres triggers for telemetry privacy (TELEM-07).
# Must run AFTER umami's Prisma migrations complete (tables exist).
#
# Usage: bash infra/telemetry/setup-triggers.sh
# Override: SMOODLE_DC_CONTEXT=other bash infra/telemetry/setup-triggers.sh

set -euo pipefail

CONTEXT="${SMOODLE_DC_CONTEXT:-th-dc}"

docker --context "$CONTEXT" exec smoodle-telemetry-postgres psql -U umami -d umami <<'SQL'

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
-- website_event, but hostname could be reverse-DNS'd; remove it entirely)
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

-- Null hostname in session table too
CREATE OR REPLACE FUNCTION null_session_hostname()
RETURNS TRIGGER AS $$
BEGIN
  NEW.hostname = NULL;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_null_session_hostname ON session;
CREATE TRIGGER trg_null_session_hostname
  BEFORE INSERT ON session
  FOR EACH ROW
  EXECUTE FUNCTION null_session_hostname();

SQL

echo "  [OK] triggers applied."
