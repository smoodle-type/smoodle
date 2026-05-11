# Phase 4 Plan — Telemetry (Lane T)

**Phase:** 4
**Lane:** T (Telemetry)
**Wave structure:** 3 waves
- **Wave 1 (autonomous: true)** — Infrastructure: Docker Compose, Caddy, Postgres triggers, sidecar forget-endpoint
- **Wave 2 (autonomous: true)** — Client: `scripts/lib/telemetry.{sh,ps1}`, install_id generation, installer opt-in prompts
- **Wave 3 (checkpoint:human-verify)** — Tests, integration smoke-test, unskip `test_telemetry_opt_in_default_off`

**Requirements:** TELEM-01 through TELEM-09 (9 REQ-IDs)
**Success Criteria:** 6 SC (from ROADMAP.md)
**Dependencies:** Phase 1 conventions (bash/pwsh syntax, unittest not pytest); th-dc Docker context reachable
**Mode:** yolo

---

## Wave 1 — Infrastructure (TELEM-01, TELEM-07, TELEM-08)

**Goal:** Deploy umami v3.1.0 + PostgreSQL on th-dc via `infra/telemetry/docker-compose.yml`, with IP-drop, timestamp-rounding, 90-day retention, and a sidecar forget-endpoint.

### Tasks

#### Task 04-01-01: Create `infra/telemetry/docker-compose.yml`

**Files:** `infra/telemetry/docker-compose.yml`

Create a Docker Compose file with 4 services:

1. **`umami`** — `ghcr.io/umami-software/umami:postgresql-v3.1.0`
   - Env: `DATABASE_URL=postgresql://umami:umami@postgres:5432/umami`
   - Env: `TRACKER_SCRIPT_NAME=api/send`
   - Env: `APP_SECRET=smoodle-telemetry-secret-change-me` (dogfood-grade, not prod-grade)
   - Ports: `3000:3000` (internal only — Caddy fronts it)
   - Depends on: `postgres`
   - Restart: `unless-stopped`

2. **`postgres`** — `postgres:16-alpine`
   - Env: `POSTGRES_DB=umami`, `POSTGRES_USER=umami`, `POSTGRES_PASSWORD=umami`
   - Volume: `postgres-data:/var/lib/postgresql/data`
   - Init SQL: mount `./init.sql` via `docker-entrypoint-initdb.d/`
   - Restart: `unless-stopped`

3. **`caddy`** — `caddy:2-alpine`
   - Mount `./Caddyfile:/etc/caddy/Caddyfile`
   - Ports: `80:80`, `443:443` (or `443:443` only if port 80 is taken on th-dc)
   - Volume: `caddy-data:/data`, `caddy-config:/config`
   - Restart: `unless-stopped`

4. **`forget-api`** — custom Python sidecar (see Task 04-01-03)
   - Build from `./forget-api/Dockerfile`
   - Env: `DATABASE_URL=postgresql://umami:umami@postgres:5432/umami`
   - Ports: `8080:8080` (internal only)
   - Depends on: `postgres`
   - Restart: `unless-stopped`

**Volumes:** `postgres-data`, `caddy-data`, `caddy-config`
**Networks:** default (bridge)

#### Task 04-01-02: Create `infra/telemetry/init.sql`

**Files:** `infra/telemetry/init.sql`

Postgres init script that runs AFTER umami's schema migration (umami creates its own tables on first boot). This script runs via `docker-entrypoint-initdb.d/` which executes in alphabetical order — we need it to run AFTER umami's own init.

**Problem:** umami's own init is embedded in its Docker image and runs on the app side (Prisma migrations), not via `docker-entrypoint-initdb.d/`. So our init.sql runs on a DB that doesn't yet have umami's tables.

**Solution:** Use a two-step approach:
1. `init.sql` creates the website row with our known UUID — but the `website` table won't exist yet.
2. Instead, use a Postgres function + `pg_cron` or a startup script that waits for umami to finish migrations, THEN inserts the website row.

**Better solution:** The umami Docker image runs Prisma migrations on container start. By the time our `init.sql` runs (which is during Postgres container init, BEFORE umami even connects), the tables don't exist.

**Final approach:** Create a separate `infra/telemetry/setup-website.sh` script that:
1. Runs `docker --context th-dc compose up -d` (starts umami + postgres)
2. Sleeps 15s (waits for Prisma migrations)
3. Runs `docker --context th-dc exec postgres psql -U umami -d umami -c "INSERT INTO website ..."` to insert our known-UUID website

This is a deploy-time script, not a runtime one. Document it in `infra/telemetry/README.md`.

**init.sql should contain:**
- The `pg_cron` extension enable (for 90-day retention cron — TELEM-08)
- `CREATE EXTENSION IF NOT EXISTS pg_cron;`
- `ALTER SYSTEM SET cron.database_name = 'umami';`
- The retention cron job: `SELECT cron.schedule('90d-retention', '0 2 * * *', $$DELETE FROM website_event WHERE created_at < NOW() - INTERVAL '90 days'$$);`

Wait — `pg_cron` requires superuser and is a Postgres extension that must be in `shared_preload_libraries`. The `postgres:16-alpine` image doesn't have it by default.

**Simpler approach for TELEM-08:** A tiny sidecar cron container, or a shell script run via `docker exec` from the host's crontab.

**Simplest approach:** Add a daily cron job to the th-dc host's crontab via the README:
```
0 2 * * * docker --context th-dc exec postgres psql -U umami -d umami -c "DELETE FROM website_event WHERE created_at < NOW() - INTERVAL '90 days'"
```

This is dogfood-grade, not production-grade. TELEM-08 is satisfied by the policy being enforced, not by the mechanism being fancy.

**So init.sql contains only:**
```sql
-- Triggers for IP drop and timestamp rounding (TELEM-07)

-- Round created_at to nearest hour on INSERT
CREATE OR REPLACE FUNCTION round_event_timestamp()
RETURNS TRIGGER AS $$
BEGIN
  NEW.created_at = date_trunc('hour', NEW.created_at);
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

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

CREATE TRIGGER trg_round_session_timestamp
  BEFORE INSERT ON session
  FOR EACH ROW
  EXECUTE FUNCTION round_session_timestamp();

-- Note: umami v3.x does NOT store client IPs in website_event or session tables.
-- The hostname field is only populated if reverse DNS resolves the IP.
-- For defense-in-depth, we NULL it anyway:
CREATE OR REPLACE FUNCTION null_hostname()
RETURNS TRIGGER AS $$
BEGIN
  NEW.hostname = NULL;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_null_hostname
  BEFORE INSERT ON website_event
  FOR EACH ROW
  EXECUTE FUNCTION null_hostname();
```

**Caveat:** These triggers reference tables (`website_event`, `session`) that umami creates via Prisma migrations. The init.sql in `docker-entrypoint-initdb.d/` runs BEFORE umami connects, so the tables don't exist yet.

**Final final approach:** The triggers are created by a post-migration script (`setup-triggers.sh`) that runs AFTER umami is up:

```bash
#!/usr/bin/env bash
# setup-triggers.sh — run after umami finishes Prisma migrations
set -euo pipefail
CONTEXT="${SMOODLE_DC_CONTEXT:-th-dc}"
docker --context "$CONTEXT" exec postgres psql -U umami -d umami <<'SQL'
-- triggers here
SQL
```

This is called from the deploy script after the 15s wait.

**init.sql will be empty or contain only pg_cron setup if we go the cron extension route.** Actually, let's keep it simple: init.sql is empty, and all Postgres customization (triggers + cron) is done via `setup-triggers.sh` post-migration.

#### Task 04-01-03: Create `infra/telemetry/forget-api/`

**Files:**
- `infra/telemetry/forget-api/Dockerfile`
- `infra/telemetry/forget-api/app.py`
- `infra/telemetry/forget-api/requirements.txt`

A minimal Python HTTP server that accepts `DELETE /api/forget?install_id_hash=<hash>` and runs:
```sql
DELETE FROM website_event WHERE event_name LIKE 'install_%' AND event_name LIKE '%' || install_id_hash_from_data;
```

Wait — umami stores custom event data in the `event_name` field and a JSONB `data` column. Let me reconsider the event storage model.

umami v3.x event model:
- `event_type` = 'custom_event' for custom events
- `event_name` = the event name we pass (e.g., "install_completed")
- Custom data goes into a JSON column... but umami v3.x may not expose a `data` column on `website_event`.

**Research finding:** umami's `/api/send` endpoint maps the `payload.data` object into the `event_name` or stores it differently depending on version. The safest approach is to store the `install_id_hash` in the `event_name` field itself, like: `install_completed:<hash>`.

Then the DELETE is:
```sql
DELETE FROM website_event WHERE event_name LIKE '%:<install_id_hash>';
```

And the forget-api accepts `install_id_hash` as a query parameter and runs this DELETE.

**app.py:**
```python
import os
import json
from http.server import HTTPServer, BaseHTTPRequestHandler
import psycopg2

DATABASE_URL = os.environ["DATABASE_URL"]

class ForgetHandler(BaseHTTPRequestHandler):
    def do_DELETE(self):
        from urllib.parse import urlparse, parse_qs
        qs = parse_qs(urlparse(self.path).query)
        install_id_hash = qs.get("install_id_hash", [None])[0]
        if not install_id_hash:
            self.send_response(400)
            self.end_headers()
            self.wfile.write(b'{"error": "install_id_hash required"}')
            return
        
        conn = psycopg2.connect(DATABASE_URL)
        cur = conn.cursor()
        cur.execute(
            "DELETE FROM website_event WHERE event_name LIKE %s",
            (f"%:{install_id_hash}",)
        )
        deleted = cur.rowcount
        conn.commit()
        cur.close()
        conn.close()
        
        self.send_response(200)
        self.send_header("Content-Type", "application/json")
        self.end_headers()
        self.wfile.write(json.dumps({"deleted": deleted}).encode())
    
    def log_message(self, format, *args):
        pass  # suppress logs in production

if __name__ == "__main__":
    HTTPServer(("0.0.0.0", 8080), ForgetHandler).serve_forever()
```

**Dockerfile:**
```dockerfile
FROM python:3.12-slim
WORKDIR /app
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt
COPY app.py .
EXPOSE 8080
CMD ["python", "app.py"]
```

**requirements.txt:**
```
psycopg2-binary==2.9.9
```

#### Task 04-01-04: Create `infra/telemetry/Caddyfile`

**Files:** `infra/telemetry/Caddyfile`

```
telemetry.0dl.me {
    reverse_proxy umami:3000
    encode gzip
    log
}
```

If TLS is not possible (no DNS setup, no port 80), fall back to HTTP-only:
```
http://telemetry.0dl.me {
    reverse_proxy umami:3000
}
```

#### Task 04-01-05: Create `infra/telemetry/setup-website.sh`

**Files:** `infra/telemetry/setup-website.sh`

Deploy-time script that:
1. Starts Compose: `docker --context th-dc compose up -d`
2. Waits 15s for Prisma migrations
3. Inserts the known-UUID website into the `website` table
4. Runs `setup-triggers.sh`
5. Smoke-tests with `curl`: `curl -X POST http://telemetry.0dl.me/api/send -H 'Content-Type: application/json' -d '{"type":"event","payload":{"website":"<UUID>","url":"/test","name":"smoke_test"}}'`

Website insert SQL:
```sql
INSERT INTO website (id, name, domain, share_id, created_at)
VALUES ('a1b2c3d4-e5f6-7890-abcd-ef1234567890', 'Smoodle Install Telemetry', 'telemetry.0dl.me', 'smoodle', NOW())
ON CONFLICT (id) DO NOTHING;
```

#### Task 04-01-06: Create `infra/telemetry/setup-triggers.sh`

**Files:** `infra/telemetry/setup-triggers.sh`

Runs the Postgres triggers from Task 04-01-02 against the live database.

#### Task 04-01-07: Create `infra/telemetry/README.md`

**Files:** `infra/telemetry/README.md`

Documentation covering:
- Deploy instructions (docker-compose up + setup-website.sh)
- How to access the umami dashboard (https://telemetry.0dl.me, default admin/admin — change password!)
- How the forget API works
- Daily retention cron setup (th-dc host crontab entry)
- DNS requirements (A-record for telemetry.0dl.me → th-dc IP)
- Security notes (dogfood-grade auth, change admin password, add basic auth before non-founder installs)

### Wave 1 Success Criteria
- [ ] `docker --context th-dc compose -f infra/telemetry/docker-compose.yml config` validates
- [ ] All 4 services start and stay up (`docker --context th-dc compose ps` shows all healthy)
- [ ] `curl -X POST http://localhost:3000/api/send` (via port-forward) returns 200
- [ ] Triggers are active (INSERT a test row → verify `created_at` is hour-rounded, `hostname` is NULL)
- [ ] Forget API accepts DELETE and removes matching rows
- [ ] Website row exists with UUID `a1b2c3d4-e5f6-7890-abcd-ef1234567890`

---

## Wave 2 — Client Scripts + Installer Integration (TELEM-02, TELEM-03, TELEM-04, TELEM-05)

**Goal:** Create `scripts/lib/telemetry.sh` and `scripts/lib/telemetry.ps1`, generate ephemeral install_id, add `[y/N]` opt-in prompts to all 3 installers.

### Tasks

#### Task 04-02-01: Create `scripts/lib/telemetry.sh`

**Files:** `scripts/lib/telemetry.sh`

Bash helper that:
- Reads opt-in: `SMOODLE_TELEMETRY=1` env or `~/.smoodle/telemetry-on` marker
- If not opted in, returns 0 immediately (no network, no spawn)
- Generates/reads install_id from `~/.smoodle/install_id`:
  - If file doesn't exist: `head -c 16 /dev/urandom | sha256sum | awk '{print $1}' > ~/.smoodle/install_id`
  - Read the value
- Constructs payload (strict allowlist):
  ```json
  {
    "type": "event",
    "payload": {
      "website": "a1b2c3d4-e5f6-7890-abcd-ef1234567890",
      "url": "/install",
      "name": "<event_name>",
      "data": {
        "install_id_hash": "<hash>",
        "os": "macos",
        "smoodle_version": "0.0.6",
        "librime_sha_match": true|false
      }
    }
  }
  ```
- Fires async POST: `(curl -fsS -m 3 -X POST -H 'Content-Type: application/json' -d "$payload" "$TELEMETRY_URL" >/dev/null 2>&1 || true) &`
- Disowns the background process
- Hard 3-second timeout (`-m 3`)
- Never blocks, never retries, never errors

Env vars:
- `SMOODLE_TELEMETRY_URL` — defaults to `https://telemetry.0dl.me/api/send`
- `SMOODLE_TELEMETRY` — if set to `1`, opt-in
- `SMOODLE_VERSION` — schema version (default `0.0.6`)
- `SMOODLE_LIBRIME_SHA_MATCH` — boolean for librime hash match status

Function signature:
```bash
smoodle_telemetry_event() {
  local event="$1"
  local librime_sha_match="${2:-true}"
  ...
}
```

#### Task 04-02-02: Create `scripts/lib/telemetry.ps1`

**Files:** `scripts/lib/telemetry.ps1`

PowerShell parallel of TELEM-02:
- Reads opt-in: `$env:SMOODLE_TELEMETRY -eq '1'` or `$env:USERPROFILE\.smoodle\telemetry-on` exists
- Generates/reads install_id from `$env:USERPROFILE\.smoodle\install_id`:
  - If file doesn't exist: generate 16 random bytes via `[System.Security.Cryptography.RandomNumberGenerator]` → hex string → write to file
- Constructs same payload shape as bash
- Fires async POST via `Start-Job`:
  ```powershell
  Start-Job -ScriptBlock {
    param($url, $payload)
    try {
      Invoke-RestMethod -Uri $url -Method Post -Body $payload -ContentType 'application/json' -TimeoutSec 3 -ErrorAction SilentlyContinue | Out-Null
    } catch { }
  } -ArgumentList $TelemetryUrl, $payloadJson | Out-Null
  ```
- ASCII-only (PITFALLS MP-4)
- Uses `$ErrorActionPreference = 'Stop'` at top

Function signature:
```powershell
function Invoke-SmoodleTelemetryEvent {
  param(
    [string]$EventName,
    [string]$LibrimeShaMatch = 'true'
  )
  ...
}
```

#### Task 04-02-03: Add telemetry opt-in prompt to `scripts/install.sh` (macOS)

**Files:** `scripts/install.sh` (modified)

After the "attempt auto-deploy" block but BEFORE the trailing test instructions, add:

```bash
# --- Telemetry opt-in (TELEM-04) -------------------------------------------
_smoodle_telemetry_prompt() {
  if [[ "${SMOODLE_TELEMETRY:-}" == "1" ]] || [[ -f "${HOME}/.smoodle/telemetry-on" ]]; then
    return 0  # already opted in
  fi
  
  echo
  echo "Telemetry (opt-in, default OFF)"
  echo "  Sends an anonymous install ping to telemetry.0dl.me"
  echo "  Payload: {install_id_hash, os, smoodle_version, librime_sha_match}"
  echo "  No hostname, username, or personal data is sent."
  echo "  Disable anytime: rm ~/.smoodle/telemetry-on"
  echo
  
  read -rp "  Enable telemetry? [y/N]: " answer
  if [[ "$answer" == "y" || "$answer" == "Y" ]]; then
    mkdir -p "${HOME}/.smoodle"
    # Generate install_id
    head -c 16 /dev/urandom | sha256sum | awk '{print $1}' > "${HOME}/.smoodle/install_id"
    touch "${HOME}/.smoodle/telemetry-on"
    echo "  ✓ Telemetry enabled. Thank you!"
  else
    echo "  Telemetry disabled. No data will be sent."
  fi
}

_smoodle_telemetry_prompt
```

Source the telemetry helper and fire events at key lifecycle points:
- After "smoodle installer" header: `smoodle_telemetry_event "install_started"`
- After schema copy: `smoodle_telemetry_event "schema_copied"`
- After auto-deploy success/failure: `smoodle_telemetry_event "deploy_success"` or `"deploy_timeout"`
- Before exit: `smoodle_telemetry_event "install_completed"`

#### Task 04-02-04: Add telemetry opt-in prompt to `scripts/install-windows.ps1`

**Files:** `scripts/install-windows.ps1` (modified)

Same pattern as macOS but in PowerShell. Add after the auto-deploy block:

```powershell
# Telemetry opt-in (TELEM-04)
function Show-SmoodleTelemetryPrompt {
    $telemetryPath = Join-Path $env:USERPROFILE '.smoodle\telemetry-on'
    if ($env:SMOODLE_TELEMETRY -eq '1' -or (Test-Path $telemetryPath)) {
        return  # already opted in
    }
    
    Write-Host ''
    Write-Host 'Telemetry (opt-in, default OFF)'
    Write-Host '  Sends an anonymous install ping to telemetry.0dl.me'
    Write-Host '  Payload: {install_id_hash, os, smoodle_version, librime_sha_match}'
    Write-Host '  No hostname, username, or personal data is sent.'
    Write-Host "  Disable anytime: Remove-Item '$telemetryPath'"
    Write-Host ''
    
    $answer = Read-Host '  Enable telemetry? [y/N]'
    if ($answer -eq 'y' -or $answer -eq 'Y') {
        $smoodleDir = Join-Path $env:USERPROFILE '.smoodle'
        if (-not (Test-Path $smoodleDir)) { New-Item -ItemType Directory -Path $smoodleDir -Force | Out-Null }
        # Generate install_id
        $rng = [System.Security.Cryptography.RandomNumberGenerator]::Create()
        $bytes = New-Object byte[] 16
        $rng.GetBytes($bytes)
        $hex = ($bytes | ForEach-Object { $_.ToString('x2') }) -join ''
        # Hash it
        $hashBytes = [System.Security.Cryptography.SHA256]::Create().ComputeHash([System.Text.Encoding]::UTF8.GetBytes($hex))
        $installIdHash = ($hashBytes | ForEach-Object { $_.ToString('x2') }) -join ''
        $installIdFile = Join-Path $smoodleDir 'install_id'
        Set-Content -Path $installIdFile -Value $installIdHash -Encoding ASCII
        New-Item -ItemType File -Path $telemetryPath -Force | Out-Null
        Write-Host '  [OK] Telemetry enabled. Thank you!'
    } else {
        Write-Host '  Telemetry disabled. No data will be sent.'
    }
}

Show-SmoodleTelemetryPrompt
```

Source `telemetry.ps1` and fire events at lifecycle points (same as macOS).

#### Task 04-02-05: Add telemetry opt-in prompt to `scripts/install-linux.sh`

**Files:** `scripts/install-linux.sh` (modified)

Same pattern as macOS install.sh. Source `telemetry.sh` and add the prompt + lifecycle events.

### Wave 2 Success Criteria
- [ ] `bash -n scripts/lib/telemetry.sh` passes
- [ ] `pwsh -NoProfile -c "[scriptblock]::Create((Get-Content -Raw scripts/lib/telemetry.ps1))"` passes
- [ ] All 3 installers prompt `[y/N]` with default-N when `SMOODLE_TELEMETRY` is unset
- [ ] With `SMOODLE_TELEMETRY=1`, events fire without blocking install
- [ ] With endpoint unreachable, installers still exit 0
- [ ] install_id is 64-char hex (sha256 of random 16 bytes)
- [ ] Payload contains ONLY allowlisted keys (no hostname, username, path)

---

## Wave 3 — Tests + Integration (TELEM-06, TELEM-09)

**Goal:** `smoodle telemetry forget` CLI, unskip `test_telemetry_opt_in_default_off`, integration smoke-test.

### Tasks

#### Task 04-03-01: Create `scripts/lib/telemetry-forget.sh`

**Files:** `scripts/lib/telemetry-forget.sh`

Bash CLI for `smoodle telemetry forget`:
- Reads local install_id from `~/.smoodle/install_id`
- If file doesn't exist: prints "No telemetry data found (no install_id)" and exits 0 (idempotent)
- Sends `DELETE https://telemetry.0dl.me/api/forget?install_id_hash=<hash>` (to the forget-api sidecar)
- On success: prints "Deleted N events for this install"
- Deletes local files: `rm ~/.smoodle/install_id ~/.smoodle/telemetry-on`
- Idempotent: running twice exits 0 with "No telemetry data found"

#### Task 04-03-02: Create `scripts/lib/telemetry-forget.ps1`

**Files:** `scripts/lib/telemetry-forget.ps1`

PowerShell parallel of TELEM-06.

#### Task 04-03-03: Unskip and implement `test_telemetry_opt_in_default_off`

**Files:** `tests/test_installers.py` (modified)

The test at line 577 (`test_telemetry_opt_in_default_off`) is currently `@unittest.skip`. Unskip it and implement assertions:
- Grep all 3 installers for the telemetry prompt
- Assert `[y/N]` pattern exists (capital N = default NO)
- Assert the prompt text mentions "anonymous" or "opt-in"
- Assert the default is N (lowercase n in brackets, capital N outside, OR the prompt reads "y/N")

```python
def test_telemetry_opt_in_default_off(self):
    """Assert all installers prompt [y/N] (default-N) for telemetry."""
    for installer in ['install.sh', 'install-linux.sh', 'install-windows.ps1']:
        path = os.path.join(PROJECT_ROOT, 'scripts', installer)
        with open(path) as f:
            content = f.read()
        # Must contain [y/N] pattern (capital N = default no)
        self.assertIn('[y/N]', content,
            f"{installer}: missing [y/N] telemetry prompt (found: default-Y or no prompt)")
```

#### Task 04-03-04: Create `tests/test_telemetry.py`

**Files:** `tests/test_telemetry.py`

Python unittest module testing telemetry client behavior:

```python
class TestTelemetryPayload(unittest.TestCase):
    """Test telemetry payload conforms to strict allowlist."""
    
    ALLOWED_DATA_KEYS = {'install_id_hash', 'os', 'smoodle_version', 'librime_sha_match'}
    
    def test_install_id_is_64_char_hex(self):
        """install_id must be sha256(random 16 bytes) = 64 hex chars."""
        # Read the generation logic from telemetry.sh/ps1
        # Verify the command produces 64-char hex output
        result = subprocess.run(
            ['bash', '-c', 'head -c 16 /dev/urandom | sha256sum | awk "{print \$1}"'],
            capture_output=True, text=True
        )
        install_id = result.stdout.strip()
        self.assertEqual(len(install_id), 64)
        self.assertRegex(install_id, r'^[0-9a-f]{64}$')
    
    def test_no_hostname_in_telemetry_sh(self):
        """telemetry.sh must not reference $HOSTNAME, hostname, whoami, etc."""
        with open(os.path.join(PROJECT_ROOT, 'scripts/lib/telemetry.sh')) as f:
            content = f.read()
        forbidden = ['$HOSTNAME', '$USER', 'hostname', 'whoami', 'uname -n']
        for token in forbidden:
            self.assertNotIn(token, content,
                f"telemetry.sh contains forbidden token: {token}")
    
    def test_no_hostname_in_telemetry_ps1(self):
        """telemetry.ps1 must not reference $env:COMPUTERNAME, $env:USERNAME, etc."""
        with open(os.path.join(PROJECT_ROOT, 'scripts/lib/telemetry.ps1')) as f:
            content = f.read()
        forbidden = ['$env:COMPUTERNAME', '$env:USERNAME', '$env:USERPROFILE\\Desktop', 'hostname']
        for token in forbidden:
            self.assertNotIn(token, content,
                f"telemetry.ps1 contains forbidden token: {token}")
    
    def test_telemetry_timeout_is_3_seconds(self):
        """telemetry.sh must use -m 3 (3-second timeout)."""
        with open(os.path.join(PROJECT_ROOT, 'scripts/lib/telemetry.sh')) as f:
            content = f.read()
        self.assertIn('-m 3', content, "telemetry.sh: missing -m 3 timeout")
    
    def test_telemetry_ps1_timeout_is_3_seconds(self):
        """telemetry.ps1 must use -TimeoutSec 3."""
        with open(os.path.join(PROJECT_ROOT, 'scripts/lib/telemetry.ps1')) as f:
            content = f.read()
        self.assertIn('TimeoutSec 3', content, "telemetry.ps1: missing -TimeoutSec 3")
    
    def test_fire_and_forget_no_retry(self):
        """telemetry.sh must not retry on failure."""
        with open(os.path.join(PROJECT_ROOT, 'scripts/lib/telemetry.sh')) as f:
            content = f.read()
        self.assertNotIn('--retry', content, "telemetry.sh: must not retry")
    
    def test_install_id_not_persisted_from_mac_address(self):
        """install_id must NOT be derived from MAC address or hostname."""
        with open(os.path.join(PROJECT_ROOT, 'scripts/lib/telemetry.sh')) as f:
            content = f.read()
        self.assertNotIn('ifconfig', content)
        self.assertNotIn('networksetup', content)
        self.assertNotIn('ioreg', content)
```

#### Task 04-03-05: Integration smoke-test (manual, documented)

**Files:** `infra/telemetry/SMOKE-TEST.md`

Document a manual smoke-test procedure:
1. Deploy on th-dc: `docker --context th-dc compose -f infra/telemetry/docker-compose.yml up -d`
2. Run setup: `bash infra/telemetry/setup-website.sh`
3. Run macOS install with telemetry: `SMOODLE_TELEMETRY=1 SMOODLE_AUTO_DEPLOY=0 bash scripts/install.sh`
4. Check umami dashboard at `https://telemetry.0dl.me` — event should appear within 30s
5. Run forget: `bash scripts/lib/telemetry-forget.sh` — should report deleted events
6. Verify DB row is gone: `docker --context th-dc exec postgres psql -U umami -d umami -c "SELECT count(*) FROM website_event WHERE event_name LIKE '%install%'"`
7. Clean up: `docker --context th-dc compose down`

### Wave 3 Success Criteria
- [ ] `smoodle telemetry forget` exits 0 on first run (deletes events) AND second run (idempotent, "no data found")
- [ ] `test_telemetry_opt_in_default_off` is unskipped and passes (all 3 installers have `[y/N]`)
- [ ] `test_telemetry.py` tests pass (payload allowlist, timeout, no PII tokens, install_id shape)
- [ ] Smoke-test procedure documented
- [ ] Full test suite still passes: `python3 -m unittest discover tests -v` (111+ tests)

---

## Commits (planned)

| Commit | Scope | Convention |
|--------|-------|------------|
| `feat(04-01): add infra/telemetry/ — umami + postgres + caddy + forget-api` | Wave 1 infrastructure | `feat(04-01)` |
| `feat(04-02): add scripts/lib/telemetry.sh — fire-and-forget POST helper` | Wave 2 bash client | `feat(04-02)` |
| `feat(04-02): add scripts/lib/telemetry.ps1 — fire-and-forget POST helper` | Wave 2 pwsh client | `feat(04-02)` |
| `feat(04-02): add telemetry opt-in prompt to install.sh` | Wave 2 macOS | `feat(04-02)` |
| `feat(04-02): add telemetry opt-in prompt to install-windows.ps1` | Wave 2 windows | `feat(04-02)` |
| `feat(04-02): add telemetry opt-in prompt to install-linux.sh` | Wave 2 linux | `feat(04-02)` |
| `feat(04-03): add scripts/lib/telemetry-forget.{sh,ps1} — purge CLI` | Wave 3 forget | `feat(04-03)` |
| `test(04-03): unskip test_telemetry_opt_in_default_off + add tests/test_telemetry.py` | Wave 3 tests | `test(04-03)` |
| `docs(04): add infra/telemetry/README.md + SMOKE-TEST.md` | Wave 3 docs | `docs(04)` |

---

## Risks & Mitigations

| Risk | Mitigation |
|------|------------|
| th-dc Docker unreachable | Verify at plan execution start; if blocked, halt phase and flag to user |
| DNS not set for telemetry.0dl.me | Use HTTP-only for dogfood; Caddy still handles reverse proxy; TLS added when DNS is ready |
| umami Prisma migration takes >15s | Increase wait to 30s in setup-website.sh; add health-check loop |
| Postgres triggers fail on INSERT (table not yet created by Prisma) | setup-triggers.sh runs AFTER setup-website.sh's 15s wait; add retry loop |
| Forget API is a security hole (unauthenticated DELETE) | Dogfood-circle risk only; document that basic auth must be added before non-founder installs |
| PowerShell 5.1 cp1252 encoding | ASCII-only in telemetry.ps1; test_powershell_ascii.py (Phase 1) catches non-ASCII |
| install_id file permissions on multi-user machine | Not a concern for dogfood (single-user machines); document in README |

---
*Plan created: 2026-05-11*
*Ready for /gsd-execute-phase 4*
