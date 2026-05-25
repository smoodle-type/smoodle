# Phase 4 Telemetry — VERIFICATION (live evidence)

**Phase:** 04 Telemetry (Lane T)
**Milestone:** v0.0.7-cross-platform (W2)
**Verifier:** founder (Apinant U-suwantim) — solo gate; recruit signals filed below as they arrive
**Pre-registration anchor:** `docs/DECISION-GATE-CRITERIA-v0.0.7.md` commit `067d1c5` 2026-05-25 12:14 +0700
**Started:** 2026-05-25 13:00 +0700 (DB wiped pristine, bearer auth landed)
**Closed:** _(pending — needs ≥1 non-founder install + forget round-trip per W2-C6)_

Per pre-reg, each criterion below is binary and machine-verifiable.

---

## W2-C1 — Live site_id wired into client defaults (FLAG-5)

- [x] **PASS** — `scripts/lib/telemetry.{sh,ps1}` default `SMOODLE_TELEMETRY_WEBSITE = 88042064-eeea-465a-8658-002d978d4f9b`
- **Verification command:** `grep -q "88042064" scripts/lib/telemetry.sh scripts/lib/telemetry.ps1`
- **Evidence:** commit `66a8f77` (2026-05-25) `fix(telemetry): wire production endpoints`

## W2-C2 — Live forget URL wired into client defaults (FLAG-6)

- [x] **PASS** — `scripts/lib/telemetry-forget.{sh,ps1}` default `FORGET_URL = https://forget.0dl.me/api/forget`
- **Verification command:** `grep -q "forget.0dl.me" scripts/lib/telemetry-forget.sh scripts/lib/telemetry-forget.ps1`
- **Evidence:** commit `66a8f77` (2026-05-25)

## W2-C3 — Privacy triggers live on dxc.0dl.me

- [x] **PASS** — `null_hostname` + `round_event_timestamp` (BEFORE INSERT) live on `website_event`; `round_session_timestamp` live on `session`. Verified by `information_schema.triggers` query on dxc.0dl.me 2026-05-25 12:24 +0700.
- **Smoke result:** synthetic event stored with `hostname=NULL` and `created_at=2026-05-25 05:00:00+00` (truncated to top of hour). Logged in session transcript.
- **Evidence:**
  - `infra/telemetry/setup-triggers.sh` (idempotent, supports `SMOODLE_DC_DIRECT=1`)
  - Applied to dxc DB `umami-db` (container)

## W2-C4 — Forget-api round-trip works on real data

- [x] **PASS (founder synthetic smoke)** — multiple round-trips during stand-up:
  - 2026-05-25 12:17 +0700: hash `deadbeef…6666` → `{"deleted": 1}`
  - 2026-05-25 12:23 +0700: hash `feedface…aabb` → `{"deleted": 1}` (via public tunnel `https://forget.0dl.me`)
  - 2026-05-25 12:29 +0700: real CLI invocation, hash `d37da984…1176bc` → `Deleted 2 event(s)` (2 events: install_started + install_success)
  - 2026-05-25 13:17 +0700: bearer-auth smoke, hash `16bbdcfa…671b` → `Deleted 1 event(s)`
- [ ] **PASS (non-founder)** — _pending first recruit install + forget round-trip; ledger row in `.planning/SOAK-LEDGER-v0.0.7.md`_

### Bearer-auth matrix (5/5 PASS, 2026-05-25 13:14 +0700)

| Case | Authorization header | Expected | Observed |
|------|----------------------|----------|----------|
| 1 | (absent) | 401 | `401 {"error": "missing or malformed Authorization: Bearer header"}` ✅ |
| 2 | `Bearer wrongtokenxxx...` | 403 | `403 {"error": "invalid bearer token"}` ✅ |
| 3 | `Bearer <correct>` | 200 + `deleted: N` | `200 {"deleted": 1}` ✅ |
| 4 | `Bearer <correct>` + no `install_id_hash` param | 400 | `400 {"error": "install_id_hash query parameter required"}` ✅ |
| 5 | `GET /` (heartbeat, no header) | 200 (public) | `200 {"status": "ok", "service": "smoodle-telemetry-forget-api"}` ✅ |

## W2-C5 — README documents forget CLI as invocable (FLAG-1)

- [x] **PASS** — `README.md` `## Telemetry & Privacy` section names the CLI (`bash scripts/lib/telemetry-forget.sh` and PowerShell equivalent) and documents the `SMOODLE_FORGET_URL` + `SMOODLE_FORGET_TOKEN` overrides.
- **Verification command:** `grep -q 'scripts/lib/telemetry-forget' README.md` (outside the file-tree block)
- **Evidence:** commit `3722846` (2026-05-25) `docs(telemetry): document live pipeline + privacy CLI`

## W2-C6 — End-to-end smoke from a non-founder macOS machine

- [ ] **PENDING** — needs first recruit. Ledger: `.planning/SOAK-LEDGER-v0.0.7.md` rows R1..R5 will fill with `install_id_hash` (last 8) + `install_success` Y/N + `forget-tested` Y/N as recruits land.
- [x] **PASS (founder dry-run, surrogate)** — 2026-05-25 12:29 +0700, founder ran `telemetry.sh` from a sandbox `$HOME` (no real install path), verified events landed with correct privacy triggers, forget CLI deleted them. This proves the wire path; recruit run proves the install path.
- **Recruit acceptance criteria:** ≥1 recruit row with `install_started`+`install_success` events both visible in umami AND `forget-tested=Y` AND no P0 issue in unsolicited feedback.

---

## Filter rule for non-founder events

When computing the W2-C6 success rate at gate-close:

```sql
SELECT event_name, COUNT(*) AS n
FROM website_event we
JOIN event_data ed ON ed.website_event_id = we.event_id
WHERE we.website_id = '88042064-eeea-465a-8658-002d978d4f9b'
  AND we.created_at >= '2026-05-25 13:00:00+07'         -- soak start
  AND ed.data_key = 'install_id_hash'
  AND ed.string_value NOT IN (
    -- founder hashes registered in
    -- .planning/phases/07-decision-gate-close/FOUNDER-HASH.txt
    -- (currently empty — founder has not opted in)
  )
GROUP BY event_name;
```

`install_success_rate = count(install_success) / count(install_started)`
(`install_failed` reduces numerator, also counts toward total denominator if its `install_id_hash` is unique).

---

## Open items (not blocking C1-C5 close; tracked separately)

- 90-day retention cron not yet enabled on dxc — must land before first non-founder install reaches day 60.
- Session/session_data not deleted by forget — documented limitation in `infra/telemetry/forget-api/app.py`; revisit when umami exposes per-install session attribution.

---

*Skeleton created: 2026-05-25 13:20 +0700 (post bearer-auth landing).*
*W2-C6 fills as recruit ledger fills.*
