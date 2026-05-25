# Smoodle Telemetry Infrastructure

Opt-in, default-OFF, no-PII install signal pipeline for the Smoodle dogfood circle.

**Live since 2026-05-25** on `dxc.0dl.me` (was previously a paper design targeting `th-dc` + Caddy).

## Architecture (as deployed)

```
  install.sh / install-windows.ps1 / install-linux.sh
      │  (fire-and-forget POST, 3s timeout)
      ▼
  https://telemetry.0dl.me/api/send  (Cloudflare tunnel → dxc.0dl.me 10.0.10.180:3001)
      │
      ▼
  umami v3.1.0 (Next.js, container `umami`, port 3000 internal)
      │
      ▼
  PostgreSQL 15 (container `umami-db`, with privacy triggers on website_event)
      ▲
      │  DELETE FROM website_event + event_data
      │
  https://forget.0dl.me/api/forget  (Cloudflare tunnel → dxc.0dl.me 10.0.10.180:8080)
      ▲
      │  DELETE ?install_id_hash=<hash>
      │
  scripts/lib/telemetry-forget.{sh,ps1}
```

## Components (as deployed on dxc.0dl.me)

| Container | Image | Host port | Purpose |
|-----------|-------|-----------|---------|
| `umami` | `ghcr.io/umami-software/umami:postgresql-latest` (v3.1.0) | `0.0.0.0:3001 → 3000` | Analytics backend — receives `/api/send` events |
| `umami-db` | `postgres:15-alpine` | internal `5432` | Data store — umami schema + privacy triggers |
| `umami-forget-api` | local build from `forget-api/` | `0.0.0.0:8080 → 8080` | Per-install delete endpoint (TELEM-06) |

**No Caddy in this deploy.** Cloudflare tunnel handles TLS termination + public hostname routing (`telemetry.0dl.me` and `forget.0dl.me`). The `infra/telemetry/docker-compose.yml` still includes Caddy for self-hosted redeploys; the dxc deploy uses `/opt/umami/docker-compose.yml` (umami + db + forget-api only).

### ADR: Caddy → Cloudflare tunnel

**2026-05-25** — TLS termination moved from Caddy (port 443 on host) to Cloudflare tunnel because dxc.0dl.me already runs a cloudflared sidecar for sibling services (`crs.0dl.me`, `smoodle-type.0dl.me`). Single TLS strategy across host. Trade-off: ACME-cert independence lost; gained: zero TLS config + automatic cert rotation + DDoS shielding. Cloudflared origin uses HTTP `10.0.10.180:3001` and `10.0.10.180:8080`.

## Deploy

### Path A — dxc.0dl.me (current production)

Live stack lives at `/opt/umami/` on the dxc host. To re-create from scratch:

```bash
# On dxc.0dl.me:
mkdir -p /opt/umami/forget-api-src
# Copy infra/telemetry/forget-api/{app.py,Dockerfile,requirements.txt} into /opt/umami/forget-api-src/
# Write /opt/umami/docker-compose.yml (umami + db + forget-api services)
# Write /opt/umami/.env with random APP_SECRET + POSTGRES_PASSWORD + DATABASE_URL
chmod 600 /opt/umami/.env

cd /opt/umami && docker compose up -d
SMOODLE_DC_DIRECT=1 SMOODLE_PG_CONTAINER=umami-db bash /path/to/setup-triggers.sh

# Cloudflare side:
#   telemetry.0dl.me → http://10.0.10.180:3001
#   forget.0dl.me    → http://10.0.10.180:8080
```

### Path B — generic Docker context (th-dc legacy / future hosts)

Original three-container design (umami + postgres + caddy + forget-api) preserved in `infra/telemetry/docker-compose.yml`. Deploy via:

```bash
docker --context th-dc compose -f infra/telemetry/docker-compose.yml up -d
bash infra/telemetry/setup-website.sh   # waits for migrations, applies triggers
```

Requires DNS A-record `telemetry.0dl.me → th-dc IP` and free ports 80/443.

### Teardown (dxc)

```bash
ssh root@dxc.0dl.me 'cd /opt/umami && docker compose down'      # preserves data
ssh root@dxc.0dl.me 'cd /opt/umami && docker compose down -v'   # deletes data volume
```

## Dashboard

- URL: `https://telemetry.0dl.me`
- Rotated credentials live in operator's password manager (not in repo)
- Website registered: **"smoodle"** with domain `smoodle-type.0dl.me`
- Website ID: `88042064-eeea-465a-8658-002d978d4f9b`

## Forget API

Delete all telemetry events for a specific install:

```bash
curl -X DELETE "https://forget.0dl.me/api/forget?install_id_hash=<64-char-hex>"
# Returns: {"deleted": <int>}
```

SQL semantics: deletes the `website_event` rows whose `event_data` carries `data_key='install_id_hash'` matching the supplied hash, plus all associated `event_data` rows. Sessions are NOT deleted (see scope limitation in `forget-api/app.py`).

Client-side access via `scripts/lib/telemetry-forget.sh` (or `.ps1` on Windows).

**Security note (dogfood scope):** No authentication on the forget API. Acceptable for the dogfood circle because deletion is constrained to the caller's own `install_id_hash` and that hash is a random 256-bit value that never leaves the user's machine. BEFORE the install base grows to a size where hash brute-force becomes interesting, add an opaque per-install bearer token issued at install time.

## 90-Day Retention (TELEM-08)

Enforced via a daily cron job on the dxc host:

```bash
# On dxc.0dl.me: crontab -e
0 2 * * * docker exec umami-db psql -U umami -d umami -c "DELETE FROM website_event WHERE created_at < NOW() - INTERVAL '90 days'"
```

Runs at 2 AM daily. Deletes all events older than 90 days.

**Not yet enabled on dxc** — pending the macOS soak signal that gates non-founder install collection. Enable BEFORE first non-founder install lands.

## Privacy Triggers (TELEM-07)

Applied by `setup-triggers.sh` post-migration. Verified active on dxc 2026-05-25:

| Trigger | Table | What |
|---------|-------|------|
| `trg_round_timestamp` | `website_event` | `created_at = date_trunc('hour', created_at)` on INSERT |
| `trg_round_session_timestamp` | `session` | same — hour-truncates session start |
| `trg_null_hostname` | `website_event` | `hostname = NULL` on INSERT — defense-in-depth against reverse-DNS |

The corresponding `session.hostname` trigger was REMOVED — umami v3.1.0+ does not have a `hostname` column on the `session` table (verified via `information_schema.columns`). The script tolerates re-runs against older DBs by dropping the legacy trigger if it exists.

## Telemetry Payload (strict allowlist)

```json
{
  "type": "event",
  "payload": {
    "website": "88042064-eeea-465a-8658-002d978d4f9b",
    "url": "/install",
    "name": "install_started|install_success|install_failed",
    "data": {
      "install_id_hash": "<64-char hex, sha256 of random 16 bytes>",
      "os": "macos|windows|linux",
      "smoodle_version": "0.0.6",
      "librime_sha_match": true|false
    }
  }
}
```

**NEVER sent:** username, file paths, IP addresses, MAC addresses, machine name. (Hostname is sent but server-side trigger nulls it; client could skip sending it entirely — tracked as future hardening.)

## Bot-check disable

`DISABLE_BOT_CHECK=1` is set on the umami container. Without it, Umami returns 200 to `curl`-class clients but silently drops the event (the famous `{"beep":"boop"}` response). Required because the smoodle CLI is fundamentally a `curl` POST, not a browser.

## Troubleshooting

| Symptom | Fix |
|---------|-----|
| `telemetry.0dl.me` returns 502 | Cloudflare tunnel origin can't reach `10.0.10.180:3001`; verify `0.0.0.0` bind in `/opt/umami/docker-compose.yml`, not `127.0.0.1` |
| Events return 200 but no row in DB | Bot-check filter — confirm `DISABLE_BOT_CHECK=1` on umami container; alternatively send a browser-class User-Agent |
| `forget.0dl.me` 502 | Same as above for port 8080 / `umami-forget-api` container |
| Forget returns `{"deleted": 0}` for known hash | Check that events carried `data_key='install_id_hash'` (not under any other key); inspect `event_data` table |
| Events have nonzero minute/second in `created_at` | Privacy trigger missing — re-run `SMOODLE_DC_DIRECT=1 SMOODLE_PG_CONTAINER=umami-db bash setup-triggers.sh` |
| umami container exits immediately | `docker logs umami` — usually DB connection. Check `/opt/umami/.env` has correct `DATABASE_URL` |

---

*Infrastructure created: 2026-05-11 (paper design)*
*Re-architected + deployed live: 2026-05-25 (Caddy→cloudflared, th-dc→dxc.0dl.me)*
