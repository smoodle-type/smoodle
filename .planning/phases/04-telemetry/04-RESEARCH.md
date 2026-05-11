# Phase 4 Research — Telemetry (Lane T)

**Domain:** Opt-in, default-OFF, no-PII install signal pipeline for Smoodle Phase 1 dogfood
**Researched:** 2026-05-11
**Confidence:** HIGH (umami API well-documented; Postgres customization straightforward; Docker Compose on th-dc proven by Lane B)

## Summary

Phase 4 delivers a telemetry layer across 3 concerns:
1. **Infrastructure (TELEM-01/07/08):** umami v3.1.0 + PostgreSQL Docker Compose on th-dc, with custom Postgres hooks for IP-drop, timestamp-rounding, install_id delete, and 90-day retention
2. **Client (TELEM-02/03/04/05):** Bash + PowerShell fire-and-forget POST helpers with ephemeral install_id, strict allowlist payload, `[y/N]` opt-in prompts in all 3 installers
3. **Purge CLI + Tests (TELEM-06/09):** `smoodle telemetry forget` commands, unskipped test for default-N opt-in

**Key constraint:** umami v3.x ships its own `/api/send` endpoint that expects a `website_id` UUID and a specific event shape. We cannot customize umami's ingestion pipeline directly — IP drop and timestamp rounding must happen at the Postgres level (triggers or views), NOT in umami's Node code.

## Open Questions Resolved

### Q1: What subdomain for telemetry?
**Answer:** `telemetry.0dl.me` (tentative, founder's existing domain `0dl.me` on th-dc infra). The docker-compose will expose umami on an internal port; Caddy/Traefik reverse proxy handles TLS. If th-dc doesn't have Caddy/Traefik already, we ship Caddy alongside (simplest: single `Caddyfile` with `telemetry.0dl.me` + automatic Let's Encrypt).

### Q2: How to drop IPs and round timestamps in umami?
**Answer:** umami stores events in `website_event` table with columns `session_id`, `visit_id`, `hostname`, `browser`, `os`, `device`, `screen`, `language`, `country`, `subdivision1`, `subdivision2`, `city`, `pageview_id`, `url_path`, `url_query`, `referrer_path`, `referrer_query`, `referrer_domain`, `title`, `event_type`, `event_name`, `created_at`, `uuid`.

- **IP drop:** umami v3.x has a `TRACKER_SCRIPT_NAME` env var but NO built-in IP-anonymization toggle. We add a Postgres `BEFORE INSERT` trigger on `website_event` that sets `hostname = NULL` (umami doesn't actually store IPs in `website_event` — it stores the visitor's hostname if resolved, otherwise NULL). For session-level IP tracking, umami stores it in `session` table — we add a trigger to NULL it there too.
- **Timestamp rounding:** `BEFORE INSERT` trigger rounds `created_at` to `date_trunc('hour', created_at)`.

### Q3: How to implement `smoodle telemetry forget` (per-install delete)?
**Answer:** umami does NOT ship a per-install delete API. Our options:
1. **Custom Postgres function** + custom HTTP endpoint alongside umami (e.g., a tiny Node/Python container or a Postgres `pg_net` webhook). Too much infra.
2. **Direct SQL via `docker exec`:** The `smoodle telemetry forget` CLI SSHes to th-dc and runs `docker exec telemetry-postgres psql -U umami -d umami -c "DELETE FROM website_event WHERE event_name = 'install_<hash>'"` — but this requires SSH access and is brittle.
3. **Custom umami API extension:** umami's `/api/websites/{id}/events` endpoint supports DELETE but it deletes ALL events for a website, not filtered by event_name. Not suitable.
4. **BEST OPTION:** A sidecar container in the same docker-compose — a tiny Python `http.server` on port 8080 that accepts `DELETE /api/forget?install_id_hash=<hash>` and runs the Postgres DELETE via `psycopg2`. ~30 lines of Python, single dependency, runs in the same Compose stack.

**Decision:** Option 4 — sidecar Python container. Minimal blast radius, no external dependencies beyond `psycopg2-binary`, runs in same Docker network as Postgres.

### Q4: How to generate ephemeral install_id without persisting anything identifiable?
**Answer:** Per PITFALLS CP-3:
- Unix: `head -c 16 /dev/urandom | sha256sum | awk '{print $1}'` → 64-char hex
- Windows: `[System.Security.Cryptography.RandomNumberGenerator]::Create()` → 16 bytes → hex string
- Store at `~/.smoodle/install_id` (Unix) / `$env:USERPROFILE\.smoodle\install_id` (Windows)
- On subsequent installs, REUSE the same file (so install events correlate across reinstalls for the same user, but the ID itself is meaningless entropy)
- `smoodle telemetry forget` deletes both the server-side rows AND the local file

### Q5: What umami website_id to use?
**Answer:** On first deploy, umami creates a default website. We need to either:
1. Pre-seed the `website` table with a known UUID via init SQL
2. Query the API post-deploy to discover it
3. Hardcode a UUID in the docker-compose and telemetry scripts

**Decision:** Option 1 — init SQL that inserts a website with a known UUID (`a1b2c3d4-e5f6-7890-abcd-ef1234567890`). Both docker-compose and client scripts reference the same UUID. Simpler than API discovery.

### Q6: How does umami's `/api/send` event API actually work?
**Answer:** umami v3.x `/api/send` endpoint expects:
```json
{
  "type": "event",
  "payload": {
    "website": "<website_id UUID>",
    "hostname": "optional",
    "url": "optional path",
    "name": "event name",
    "data": { "key": "value" }
  }
}
```

Our install events will use:
```json
{
  "type": "event",
  "payload": {
    "website": "a1b2c3d4-e5f6-7890-abcd-ef1234567890",
    "url": "/install",
    "name": "install_started|schema_copied|deploy_success|deploy_timeout|install_completed",
    "data": {
      "install_id_hash": "<64-char hex>",
      "os": "macos|windows|linux",
      "smoodle_version": "0.0.6",
      "librime_sha_match": true
    }
  }
}
```

### Q7: Does th-dc already have Caddy/Traefik?
**Answer:** Unknown — needs verification at plan time. If not, ship a simple Caddy container in the telemetry Compose stack. Caddy is simpler than Traefik for a single-host reverse proxy with automatic TLS.

## Risk Assessment

| Risk | Likelihood | Impact | Mitigation |
|------|------------|--------|------------|
| th-dc unreachable or Docker not running | Low | High (blocks entire phase) | Verify at plan time; if blocked, mark phase as infra-blocked and move to user's attention |
| Caddy/Traefik not on th-dc | Medium | Medium | Ship Caddy in Compose; requires DNS A-record for `telemetry.0dl.me` pointing to th-dc IP |
| umami API shape changes in v3.x | Low | Medium | Pin umami to `ghcr.io/umami-software/umami:postgresql-v3.1.0` specifically |
| Postgres trigger conflicts with umami schema migrations | Low | Medium | Test trigger creation against fresh umami DB; document migration path |
| Sidecar forget-endpoint is a security hole | Medium | High | Sidecar accepts DELETE only from th-dc localhost; no auth token yet (dogfood circle); add basic auth before non-founder installs |

## Pre-Plan Checklist Items to Verify

1. `docker --context th-dc ps` — confirm Docker is reachable
2. `docker --context th-dc network ls` — check existing networks (for Caddy/Traefik)
3. Confirm DNS A-record for `telemetry.0dl.me` exists or can be created
4. Decide on the subdomain — confirm with user if `telemetry.0dl.me` is correct

---
*Research completed: 2026-05-11*
*Ready for plan-phase*
