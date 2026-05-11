# Smoodle Telemetry Infrastructure

Opt-in, default-OFF, no-PII install signal pipeline for the Smoodle Phase 1 dogfood circle.

## Architecture

```
  install.sh / install-windows.ps1 / install-linux.sh
      │  (fire-and-forget POST, 3s timeout)
      ▼
  https://telemetry.0dl.me/api/send  (Caddy TLS → umami:3000)
      │
      ▼
  umami v3.1.0 (Node.js, ~200 MB RAM)
      │
      ▼
  PostgreSQL 16 (umami schema + privacy triggers)
      │
      ▼
  forget-api (:8080) — DELETE /api/forget?install_id_hash=<hash>
```

## Components

| Service | Image | Port | Purpose |
|---------|-------|------|---------|
| `umami` | `ghcr.io/umami-software/umami:postgresql-v3.1.0` | 3000 (internal) | Analytics backend — receives `/api/send` events |
| `postgres` | `postgres:16-alpine` | 5432 (internal) | Data store — umami schema + privacy triggers |
| `caddy` | `caddy:2-alpine` | 80, 443 | Reverse proxy + automatic Let's Encrypt TLS |
| `forget-api` | custom (Python 3.12-slim) | 8080 (internal) | Per-install delete endpoint (TELEM-06) |

## Deploy

### Prerequisites

1. th-dc Docker context configured (`docker --context th-dc ps` works)
2. DNS A-record: `telemetry.0dl.me` → th-dc public IP
3. Ports 80 + 443 available on th-dc (for Caddy TLS)

### Steps

```bash
# 1. Start all services
docker --context th-dc compose -f infra/telemetry/docker-compose.yml up -d

# 2. Run setup (wait for migrations, insert website, apply triggers)
bash infra/telemetry/setup-website.sh

# 3. Open dashboard and CHANGE the default password
open https://telemetry.0dl.me
# Default login: admin / admin

# 4. Verify an event appears after running an install with SMOODLE_TELEMETRY=1
```

### Teardown

```bash
# Stop containers (preserves data)
docker --context th-dc compose -f infra/telemetry/docker-compose.yml down

# Stop + delete all data
docker --context th-dc compose -f infra/telemetry/docker-compose.yml down -v
```

## Dashboard

- URL: `https://telemetry.0dl.me`
- Default credentials: **admin / admin** — CHANGE THIS IMMEDIATELY
- Website: "Smoodle Install Telemetry"
- Events visible under "Realtime" and "Events" tabs

## Forget API

Delete all telemetry events for a specific install:

```bash
curl -X DELETE "http://localhost:8080/api/forget?install_id_hash=<64-char-hex>"
# Returns: {"deleted": 5}
```

Exposed internally on port 8080. NOT reverse-proxied through Caddy (not public).
Client-side access via `scripts/lib/telemetry-forget.sh`.

**Security note (dogfood scope):** No authentication on the forget API. This is acceptable for the founder-only dogfood circle. BEFORE any non-founder installs, add basic auth or an API token.

## 90-Day Retention (TELEM-08)

Enforced via a daily cron job on the th-dc host:

```bash
# Add to th-dc crontab: crontab -e
0 2 * * * docker --context th-dc exec smoodle-telemetry-postgres psql -U umami -d umami -c "DELETE FROM website_event WHERE created_at < NOW() - INTERVAL '90 days'"
```

Runs at 2 AM daily. Deletes all events older than 90 days.

## Privacy Triggers (TELEM-07)

Applied by `setup-triggers.sh` post-migration:

1. **Timestamp rounding:** `created_at` rounded to nearest hour on INSERT (both `website_event` and `session` tables)
2. **Hostname NULL:** `hostname` set to NULL on INSERT (defense-in-depth — umami doesn't store client IPs in these tables, but hostname could be reverse-DNS resolved)

## Telemetry Payload (strict allowlist)

```json
{
  "type": "event",
  "payload": {
    "website": "a1b2c3d4-e5f6-7890-abcd-ef1234567890",
    "url": "/install",
    "name": "install_started|schema_copied|deploy_success|deploy_timeout|install_completed",
    "data": {
      "install_id_hash": "<64-char hex, sha256 of random 16 bytes>",
      "os": "macos|windows|linux",
      "smoodle_version": "0.0.6",
      "librime_sha_match": true|false
    }
  }
}
```

**NEVER sent:** hostname, username, file paths, IP addresses, MAC addresses.

## Troubleshooting

| Symptom | Fix |
|---------|-----|
| umami container exits immediately | Check postgres is running: `docker --context th-dc ps` |
| `setup-website.sh` fails on website INSERT | Prisma migrations may not have finished; wait 30s and retry |
| Caddy shows TLS error | Verify DNS A-record for telemetry.0dl.me → th-dc IP |
| Forget API returns 500 | Postgres connection issue: `docker --context th-dc logs smoodle-telemetry-forget-api` |
| Events not appearing in dashboard | Check umami logs: `docker --context th-dc logs smoodle-telemetry-umami` |

---
*Infrastructure created: 2026-05-11*
