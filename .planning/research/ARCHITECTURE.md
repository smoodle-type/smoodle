# Architecture Research

**Domain:** Phase 1 finish — Thai phonetic IME (Rime/librime), 3-repo monorepo, schema + installers + tests
**Researched:** 2026-05-08
**Confidence:** HIGH (existing architecture is well-mapped in `.planning/codebase/ARCHITECTURE.md`; Phase 1 finish only adds 5 new component classes on top, all of which are well-trodden patterns in the OSS-installer space)

## Standard Architecture

### System Overview — Phase 1 finish additions

```
┌──────────────────────────────────────────────────────────────────────────┐
│                  EXISTING (don't re-architect)                            │
│  schema/  →  scripts/install*.sh|ps1  →  ~/Library/Rime/, %APPDATA%\Rime\,│
│              ~/.local/share/fcitx5/rime/, ~/.config/ibus/rime/            │
│  smoodle-type/librime fork (CI matrix green) → release dylib + rime.dll   │
│  Squirrel.app fork (smoodle-app, v0.1.0)                                  │
│  GHA: install-linux-e2e.yml (single workflow, ubuntu-latest only)         │
└──────────────────────────────────────────────────────────────────────────┘
                                    │  Phase 1 finish wraps these in:
                                    ▼
┌──────────────────────────────────────────────────────────────────────────┐
│  CI/CD layer  (Lane E close — 2 new workflow files; existing one renamed)│
│  ┌──────────────────────────────────────────────────────────────────┐    │
│  │  .github/workflows/                                               │    │
│  │    ci.yml         ← per-PR validation: schema lint + shape tests │    │
│  │                     (ubuntu-latest only — fast, no matrix)       │    │
│  │    install-mac-e2e.yml    ← macos-14, manual + scheduled         │    │
│  │    install-win-e2e.yml    ← windows-latest, manual + scheduled   │    │
│  │    install-linux-e2e.yml  ← (existing, ubuntu-latest, on PR)     │    │
│  │    release.yml    ← tag-triggered: build DMG + attach to release │    │
│  └──────────────────────────────────────────────────────────────────┘    │
│                              │                                            │
│                              │ pulls dylib/dll asset from                 │
│                              ▼                                            │
│  ┌──────────────────────────────────────────────────────────────────┐    │
│  │  smoodle-type/librime — GH Releases                               │    │
│  │    librime-1.16.0-smoodle.1-macOS-universal.dylib  (+ .sha256)   │    │
│  │    rime-1.16.0-smoodle.1-windows-x64.dll          (+ .sha256)   │    │
│  └──────────────────────────────────────────────────────────────────┘    │
└──────────────────────────────────────────────────────────────────────────┘
                                    ▲
                                    │ verified by
                                    │
┌──────────────────────────────────────────────────────────────────────────┐
│  Installer hardening layer  (in-script verify, no new daemon)            │
│  ┌──────────────────────────────────────────────────────────────────┐    │
│  │  scripts/install-librime-fork.sh                                 │    │
│  │    download → SHA256 verify (post-download, pre-swap)            │    │
│  │              → optional codesign --verify                         │    │
│  │              → backup → swap → log install_id_hash               │    │
│  │  scripts/install-librime-fork.ps1                                │    │
│  │    download → Get-FileHash SHA256 → Get-AuthenticodeSignature    │    │
│  │              → backup → swap                                      │    │
│  │  scripts/verify-librime.sh   (new, manual)                       │    │
│  │    re-hashes the swapped dylib, warns if Sparkle clobbered it    │    │
│  └──────────────────────────────────────────────────────────────────┘    │
└──────────────────────────────────────────────────────────────────────────┘
                                    │
                                    │ optional, opt-in, default OFF
                                    ▼
┌──────────────────────────────────────────────────────────────────────────┐
│  Telemetry layer  (3 components: client helper + endpoint + dashboard)   │
│  ┌──────────────────────────────────────────────────────────────────┐    │
│  │  Client (in-installer, fire-and-forget)                          │    │
│  │    Bash: scripts/lib/telemetry.sh   (curl -s -m 3 POST)          │    │
│  │    PowerShell: scripts/lib/telemetry.ps1                         │    │
│  │    Payload: { event, install_id_hash, os, smoodle_version,       │    │
│  │               schema_version, ts }   — no PII, no ip stored      │    │
│  │    Async (background subshell on Bash, Start-Job on PS)          │    │
│  │    Opt-in: SMOODLE_TELEMETRY=1 env or ~/.smoodle/telemetry-on    │    │
│  └────────────────────────────┬─────────────────────────────────────┘    │
│                               │                                            │
│                               ▼  HTTPS POST                                │
│  ┌──────────────────────────────────────────────────────────────────┐    │
│  │  Endpoint (umami self-host on user's existing th-dc infra)       │    │
│  │    docker-compose: umami + postgres                              │    │
│  │    Send-Beacon shape: POST /api/send  with website-id            │    │
│  │    Reverse-proxied behind existing th-dc Caddy/Traefik on TLS    │    │
│  └────────────────────────────┬─────────────────────────────────────┘    │
│                               │                                            │
│                               ▼                                            │
│  ┌──────────────────────────────────────────────────────────────────┐    │
│  │  Storage + dashboard                                              │    │
│  │    Postgres (umami's own schema; events table)                   │    │
│  │    Umami built-in dashboard at https://telemetry.0dl.me/         │    │
│  │    No custom UI needed                                            │    │
│  └──────────────────────────────────────────────────────────────────┘    │
└──────────────────────────────────────────────────────────────────────────┘
                                    │
                                    │ feeds qualitative + (limited) quantitative signal into
                                    ▼
┌──────────────────────────────────────────────────────────────────────────┐
│  Decision Gate close  (1 file, manual review)                            │
│  ┌──────────────────────────────────────────────────────────────────┐    │
│  │  .planning/DECISION-GATE.md                                       │    │
│  │    Markdown checklist (see template below). Scored manually.    │    │
│  │    Inputs: telemetry numbers (if opt-in users), bug reports,     │    │
│  │    test results, README/docs status.                              │    │
│  │    Output: "ship-publicly-ready" vs "stay-in-dogfood" verdict    │    │
│  └──────────────────────────────────────────────────────────────────┘    │
└──────────────────────────────────────────────────────────────────────────┘
```

### Component Responsibilities

| Component | Responsibility | Implementation |
|-----------|----------------|----------------|
| `ci.yml` | Per-PR validation gate. Runs on every PR. Schema lint + Python shape tests + bash/pwsh syntax. ubuntu-latest only (fast feedback). | Single GHA workflow, no OS matrix at this layer. ~3 min per run. |
| `install-mac-e2e.yml` | macOS regression catch. Runs on `workflow_dispatch` + weekly schedule + on PR touching `scripts/install*.sh` or `schema/**`. | macos-14 GHA runner. Installs Squirrel via `brew install --cask`, runs `install.sh`, runs `install-librime-fork.sh` with `SMOODLE_NONINTERACTIVE=1`, asserts schemas in `~/Library/Rime/`, runs engine fixture via `rime_api_console`. |
| `install-win-e2e.yml` | Windows regression catch. Same triggers as mac. | windows-latest GHA runner. Installs Weasel via winget (`--interactive` is required per existing CFM #1; CI uses `--silent` only if the `Get-WinUserLanguageList` defense-in-depth check passes). Runs both `.ps1` installers. |
| `install-linux-e2e.yml` | (existing, unchanged) Linux regression catch. ubuntu-latest + ibus-rime apt. | Already green. Possibly extend to add fcitx5 path as a second job (low priority per `LANE-C-LINUX.md`). |
| `release.yml` | Tag-triggered. Builds DMG via `scripts/build-macos-dmg.sh`, computes SHA256 of dylib + DMG, uploads to GH Releases. | `on: push: tags: ['v*']`. macos-14 runner. Uses `gh release upload` with `--clobber` to refresh checksums. |
| `tests/test_schema_lint.py` | Validates `thai_phonetic.{schema,dict}.yaml` + `default.custom.yaml` (typos in keys, regex syntax in algebra rules, weight integrality, schema_id matches filename, `import_preset` references resolve). | stdlib Python. Wired into `ci.yml`. ~1s runtime. |
| `tests/test_install_e2e_mac.sh` | macOS E2E driver invoked by `install-mac-e2e.yml`. | bash. Wraps install + verify + engine fixture. ~5 min total. |
| `tests/test_install_e2e_win.ps1` | Windows E2E driver invoked by `install-win-e2e.yml`. | PowerShell. Same shape as the mac driver. |
| `scripts/lib/telemetry.sh` | Fire-and-forget POST helper for Bash installers. No retries, 3s timeout. Hard-fails silent on opt-in disabled. | bash + curl. Sourced by installers; one function `smoodle_telemetry_event`. |
| `scripts/lib/telemetry.ps1` | Same shape, for PowerShell installers. | `Invoke-RestMethod` in `Start-Job` so installer doesn't block. |
| Telemetry endpoint (umami) | HTTPS POST receiver; persists to postgres. Already-existing umami container on th-dc. | docker-compose (existing th-dc infra; no new infra spend). |
| `scripts/verify-librime.sh` / `.ps1` | Manual verifier the user can run any time. Re-hashes the in-place dylib/DLL. Reports drift from the last-known-good SHA. | bash / pwsh. No daemon. **Not a LaunchAgent** — see ADR below. |
| `.planning/DECISION-GATE.md` | Manually-curated checklist of "Phase 1 ship-publicly-ready" preconditions. | Markdown. ~30 lines. |

## Recommended Project Structure

The existing structure (per `.planning/codebase/STRUCTURE.md`) is sound. Phase 1 finish only adds:

```
.github/
├── workflows/
│   ├── ci.yml                          # NEW — per-PR validation
│   ├── install-mac-e2e.yml             # NEW — Lane E mac
│   ├── install-win-e2e.yml             # NEW — Lane E win
│   ├── install-linux-e2e.yml           # EXISTING — Lane E linux (unchanged)
│   └── release.yml                     # NEW — tag-triggered DMG + checksums

scripts/
├── lib/                                # NEW — shared script helpers
│   ├── telemetry.sh                    # Bash POST helper
│   └── telemetry.ps1                   # PowerShell POST helper
├── verify-librime.sh                   # NEW — manual hash-drift checker
├── verify-librime.ps1                  # NEW — PowerShell parallel
└── (existing installers, unchanged except: source telemetry.sh, add SHA256 verify block)

tests/
├── test_schema_lint.py                 # NEW — D5
├── test_install_e2e_mac.sh             # NEW — Lane E driver
├── test_install_e2e_win.ps1            # NEW — Lane E driver
└── (existing tests, unchanged except 3 @unittest.skip removals)

.planning/
└── DECISION-GATE.md                    # NEW — phase-close checklist
```

### Structure Rationale

- **`scripts/lib/`:** Three installers each gain ~10 lines of telemetry boilerplate; centralizing into `lib/telemetry.sh` keeps the boilerplate in one file. Sourced from each installer with `. "$(dirname "$0")/lib/telemetry.sh"`. Mirrors the macOS/Linux pattern.
- **`tests/test_install_e2e_*`:** Kept separate from `tests/test_installers.py` (the shape-test suite). The shape suite is fast and runs locally + in `ci.yml`; the E2E drivers are slow (5-15 min) and run only in their dedicated workflows. Same fixture format, but they don't share runtime — the E2E drivers consume `tests/v01_fixture.yaml` for the post-install assertion phase.
- **`.github/workflows/` per-OS files (NOT a single `ci.yml` matrix):** See ADR below; tl;dr: matrix on a single workflow forces all OS jobs to run on every trigger, but mac+win runners are slow (5-10 min each) and we want fast PR feedback (`ci.yml` ubuntu-only, ~3 min) plus on-demand OS-specific E2E.
- **`scripts/verify-librime.{sh,ps1}` (separate from installers):** A user can run the verifier without re-running the installer's swap path. Keeps the swap blast radius narrow.

## Architectural Patterns

### Pattern 1: Two-tier CI (fast `ci.yml` + slow per-OS `e2e.yml` files)

**What:** A single `ci.yml` runs on every PR with the cheap checks (schema lint, Python shape tests, syntax). Slow per-OS E2E workflows run on PRs that touch installer or schema paths, plus on a weekly cron, plus `workflow_dispatch`. They do NOT run on every PR.

**When to use:** Multi-platform installer projects where the per-OS runner cost (mac+win minutes are expensive) and time (5-10 min each) makes "every PR runs everything" actively painful. ([RunsOn matrix-strategy guide](https://runs-on.com/github-actions/the-matrix-strategy/) discusses the cost trade-off; matrix is good when jobs are similar and cheap, less good when they fan-out across very different setups.)

**Trade-offs:**
- Pro: Sub-3-min PR feedback for the 80%-of-PRs-touch-only-schema-or-Python case.
- Pro: On-demand E2E via `workflow_dispatch` lets the maintainer trigger a full sweep before tagging a release.
- Pro: Weekly cron catches "GHA macOS runner image upgraded and broke our Squirrel install" silently before users hit it.
- Con: Splits intent across 4 workflow files instead of 1. Mitigated by clear file naming.
- Con: A schema-only PR doesn't catch installer-side regressions until merge. Mitigated by `paths:` filters that DO trigger E2E when installer files change.

**Why not single `ci.yml` matrix:** A 3-OS matrix on every PR triggers ~25 GHA-minutes per PR (3 min linux + 8 min mac + 8 min win + setup overhead). At small dogfood scale this is tolerable but the workflow becomes the merge gate by default — PRs sit waiting on a flaky Windows winget install. Splitting per-OS keeps mac+win opt-in.

**Example:**
```yaml
# ci.yml — every PR
name: ci
on: { pull_request: {}, push: { branches: [main] } }
jobs:
  lint-and-shape:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-python@v5
        with: { python-version: '3.11' }
      - run: python3 tests/test_schema_lint.py
      - run: python3 tests/test_installers.py
      - run: bash -n scripts/install*.sh
      # pwsh syntax check is best-effort (pwsh ships in ubuntu-latest):
      - run: pwsh -NoProfile -Command "[scriptblock]::Create((Get-Content -Raw scripts/install-windows.ps1)) | Out-Null"
```

### Pattern 2: Async-fire-and-forget telemetry client

**What:** Telemetry POST runs in a background subshell (Bash) or `Start-Job` (PowerShell) with a hard 3s timeout. Installer never waits on the response, never retries on failure. If the endpoint is down, telemetry silently drops.

**When to use:** Single-binary install scripts where blocking on a network call would (a) make the installer's UX terrible on flaky networks, (b) leak user-facing latency to a non-essential signal, (c) create a dependency between the installer's success and the telemetry server's uptime. Standard pattern for opt-in OSS telemetry (homebrew analytics, dotnet CLI, vscode telemetry all use the same shape).

**Trade-offs:**
- Pro: Installer success rate decouples from telemetry endpoint availability.
- Pro: No retry logic, no queue, no daemon. Smallest possible client.
- Con: Lossy by design. Installer's last gasp before exit may not flush. Mitigated by emitting the install-success event BEFORE any work that could exit, and accepting that ~5-10% of events drop.
- Con: A user can be confused if their `~/.smoodle/telemetry-on` is off but they see `curl` in `ps`. Mitigated by gating the entire `lib/telemetry.sh` source on the env/file check.

**Example:**
```bash
# scripts/lib/telemetry.sh
smoodle_telemetry_event() {
  local event="$1"
  if [[ "${SMOODLE_TELEMETRY:-}" != "1" ]] && [[ ! -f "${HOME}/.smoodle/telemetry-on" ]]; then
    return 0  # opt-out fast path; no curl spawn
  fi
  local install_id_hash
  install_id_hash=$(_smoodle_install_id_hash)  # sha256 of stable machine id, hashed
  local payload
  payload=$(printf '{"event":"%s","install_id_hash":"%s","os":"%s","ver":"%s","schema":"%s","ts":%d}' \
    "$event" "$install_id_hash" "$(uname -s)" "$SMOODLE_VERSION" "$SMOODLE_SCHEMA_VER" "$(date +%s)")
  ( curl -fsS -m 3 -X POST -H 'Content-Type: application/json' \
      -d "$payload" "https://telemetry.0dl.me/api/send" >/dev/null 2>&1 || true ) &
  disown 2>/dev/null || true
}
```

### Pattern 3: Post-download-pre-swap SHA256 gate (NOT pre-download)

**What:** SHA256 verification happens AFTER curl/Invoke-WebRequest produces a local file but BEFORE the file is moved into the system-protected swap location. Separate `.sha256` sidecar in GH Releases provides the expected hash.

**When to use:** Any installer that downloads then swaps a system-protected binary. The download+verify+swap atomic guard is the standard supply-chain hygiene pattern (see [Akamai's CTR docs](https://techdocs.akamai.com/download-ctr/docs/verify-checksum), [Linux man page sha256sum](https://man7.org/linux/man-pages/man1/sha256sum.1.html); it's how Homebrew, Chocolatey, scoop, asdf, mise all gate their downloads).

**Trade-offs:**
- Pro: Catches CDN tampering, partial downloads, and (with pinned hash) GitHub-Releases-overwrite attacks.
- Pro: Atomic — if hash fails, nothing on the user's system has been modified.
- Con: Hash drift if the maintainer rebuilds the dylib without updating the script's pinned hash. Mitigated by sourcing the expected hash from the release's `.sha256` sidecar file (downloaded alongside, not embedded in script) BUT also verifying the sidecar's HTTPS origin (GitHub serves it over TLS) and pinning by tag.
- Con: Doesn't catch a malicious release author. For that, need code-signing. Deferred to pre-public-ship gate per project constraints.

**Why post-download-pre-swap, not pre-download:**
Pre-download (i.e., refuse to even hit the URL unless we already have a hash) requires hash to be embedded in the script. Each release bumps the hash, requiring a script edit. That's an okay approach for static URLs but it's a maintenance burden. Sidecar-hash + post-download verify is the more flexible default.

**Example:**
```bash
# In scripts/install-librime-fork.sh
download_url="${RELEASE_URL}"
sha_url="${RELEASE_URL}.sha256"
tmp_dylib="$(mktemp -t librime.XXXXXX).dylib"
tmp_sha="$(mktemp -t librime.XXXXXX).sha256"

curl -fsSL -o "$tmp_dylib" "$download_url"
curl -fsSL -o "$tmp_sha"   "$sha_url"

expected="$(awk '{print $1}' "$tmp_sha")"
actual="$(shasum -a 256 "$tmp_dylib" | awk '{print $1}')"

[[ "$expected" == "$actual" ]] || {
  echo "ERROR: dylib hash mismatch"
  echo "  expected: $expected"
  echo "  actual:   $actual"
  exit 1
}

# Only NOW do we sudo cp into /Library/Input Methods/...
```

### Pattern 4: Decision gate as static markdown checklist (NOT a dashboard)

**What:** `.planning/DECISION-GATE.md` is a flat markdown file with `- [ ]` checkboxes. Closing Phase 1 means the maintainer reviews each item, ticks the box (or notes why it's deferred), then writes a verdict at the bottom. No web UI, no automation, no dashboard.

**When to use:** Single-maintainer / small-circle dogfood projects where the "ship-publicly-ready" decision is one person's judgment call informed by ~15-20 qualitative + quantitative signals. Building a dashboard for one decision is over-engineering.

**Trade-offs:**
- Pro: Zero infra, zero dependencies. Lives in the repo, version-controlled.
- Pro: Force-functions the maintainer to write down why each box is checked (or not).
- Con: Manual. If Phase 2 has multiple maintainers or recurring gate reviews, upgrade to something structured.

**Example:**
```markdown
# Decision Gate — Phase 1 close

**Date evaluated:** 2026-MM-DD
**Verdict (after review):** [ship-publicly-ready / stay-in-dogfood / extended-dogfood-month]

## Quantitative signals (telemetry, opt-in subset only)
- [ ] ≥1 install_id_hash distinct from founder's seen in telemetry
- [ ] ≥1 deploy_success event from a non-founder install_id_hash
- [ ] ...

## Qualitative signals
- [ ] ≥1 unsolicited bug report or feature request from a non-founder
- [ ] ≥1 named non-founder converts to "uses this daily" voluntarily
- [ ] ...

## Engineering preconditions
- [ ] Lane E close: install-mac-e2e.yml + install-win-e2e.yml green for ≥7 days
- [ ] Schema lint test landed; passes on every PR
- [ ] Universal macOS dylib shipped (or explicitly deferred again)
- [ ] README updated; no LoneExile/* references
- [ ] DECISION-GATE.md filled out

## Verdict rationale
[1-3 paragraphs]
```

## Data Flow

### Asset distribution flow (librime fork → end user)

```
  smoodle-type/librime  (fork repo)
      │
      │ 1. push tag 1.16.0-smoodle.1
      ▼
  smoodle-build.yml CI matrix  (already green)
      │
      │ 2. produces artifacts:
      │    - librime-1.16.0-smoodle.1-macOS-universal.dylib (Phase 1.5: universal lipo)
      │    - rime-1.16.0-smoodle.1-windows-x64.dll
      ▼
  GH Releases (smoodle-type/librime)  ← currently MANUAL upload step (TODOS.md #3)
      │                                  Phase 1 finish: scripted in librime fork's release.yml
      │ 3. each artifact gets a sibling .sha256 file
      │
      │ 4. user runs scripts/install-librime-fork.sh
      ▼
  curl -fsSL .../librime-...dylib
  curl -fsSL .../librime-...dylib.sha256
      │
      │ 5. shasum -a 256 verify
      ▼
  /Library/Input Methods/Squirrel.app/Contents/Frameworks/librime.1.dylib
      ▲
      │ 6. (optional, manual) bash scripts/verify-librime.sh
      │    re-hashes the dylib and warns if Sparkle clobbered it
      └──── hash drift detected → user re-runs install-librime-fork.sh
```

### Install path with telemetry (Phase 1 finish version)

```
  user runs scripts/install.sh   (or .ps1, .sh per OS)
      │
      │ 1. telemetry: install_started     ─ async ─ ─ ─ ─→  POST /api/send
      ▼
  schema YAMLs copied to user dir
      │
      │ 2. telemetry: schema_copied        ─ async ─ ─ ─ ─→  POST /api/send
      ▼
  auto-deploy attempt (timeout-bounded)
      │
      │ 3. telemetry: deploy_success|deploy_timeout  ─ async ─→  POST /api/send
      ▼
  installer exits 0 (or non-zero with stderr remediation)
      │
      │ 4. telemetry: install_completed    ─ async ─ ─ ─ ─→  POST /api/send
      ▼
  user opens text editor, types `sawadee` → `สวัสดี`
      ▲
      │ (no telemetry from runtime — installer-only)
      │
  GH Releases (telemetry endpoint not aware of runtime)
```

### Per-PR validation flow (`ci.yml`)

```
  developer pushes commit / opens PR
      │
      ▼
  GHA: ci.yml triggers on PR event
      │
      │  ubuntu-latest runner (~3 min total)
      │
      ├─> python3 tests/test_schema_lint.py    (validates 3 YAMLs)
      ├─> python3 tests/test_installers.py     (shape tests, 56+ cases)
      ├─> bash -n scripts/install*.sh           (bash syntax)
      └─> pwsh -NoProfile -c …                  (pwsh syntax — ubuntu-latest ships pwsh)
      │
      ▼
  status check: green / red on PR
      │
      │  if installer or schema files touched:
      ▼
  install-{linux,mac,win}-e2e.yml triggers via paths: filter
      (linux fast ~3 min, mac+win each ~8-10 min)
      │
      ▼
  status checks: required for merge to main
```

### Decision Gate close flow

```
  Lane E green for ≥7 days  ─┐
  README updated             ─┤
  Schema lint in CI          ─┼─→  maintainer opens .planning/DECISION-GATE.md
  Telemetry shipped          ─┤
  Sparkle re-swap detected   ─┘
                                 │
                                 │  Manually walks each checkbox.
                                 │  Notes telemetry numbers (if opt-in users present)
                                 │  Notes bug reports, feature requests received
                                 ▼
                              writes verdict at bottom of file
                                 │
                                 ├─→ "ship-publicly-ready"   ──→  Phase 2 plan (signing, MSI, domain)
                                 ├─→ "stay-in-dogfood"        ──→  add 2 weeks, retry gate
                                 └─→ "extended-dogfood-month" ──→  set new date, monitor signals
```

## Scaling Considerations

| Scale | Architecture Adjustments |
|-------|--------------------------|
| 1 user (founder) | Current architecture is correct. No telemetry needed (founder knows). DMG manual upload OK. |
| 2-10 users (Phase 1 dogfood circle) | Telemetry helps but optional. Sparkle re-swap detection becomes valuable (≥1 user will hit it). Schema lint catches typos before they ship. |
| 10-100 users (post-Decision-Gate) | Universal dylib mandatory. Code signing mandatory. MSI build mandatory. Telemetry is the canary for "did the install actually work" (no in-person signal anymore). |
| 100+ users | Out of Phase 1 scope. Auto-update infra, CDN for dylib distribution, distro packaging are the next bottlenecks. |

### Scaling Priorities

1. **First bottleneck (already real at scale=1):** Sparkle silently overwrites the patched dylib. Phase 1 finish addresses with `verify-librime.sh` (manual) + post-install warning text. At scale 10-100, this becomes "users report smoodle stopped working a week after install" — that's when a LaunchAgent / scheduled task is justified. Phase 1 explicitly defers the daemon.
2. **Second bottleneck (real at scale=10):** Intel Macs silently fail. Universal dylib in `librime/release.yml` (`lipo arm64 + x86_64`) closes this. Phase 1 finish should ship this.
3. **Third bottleneck (real at scale=10-50):** GH Releases ratelimits + no CDN for downloads. Mitigation: not a real concern at this scale; GH serves releases globally. Defer.
4. **Fourth bottleneck (real at scale=100+):** Manual DMG upload. Mitigation: `release.yml` automates this in Phase 1 finish. Pre-emptive.

## Anti-Patterns

### Anti-Pattern 1: Single `ci.yml` with full 3-OS matrix on every PR

**What people do:** One workflow file, `runs-on: ${{ matrix.os }}`, matrix `[ubuntu-latest, macos-14, windows-latest]`, runs the full installer + verify on every PR. Sounds clean.

**Why it's wrong:**
- macos-14 and windows-latest GHA runners are slow (cold boot ~30s, brew/winget ops 1-3 min) and consume per-minute billing minutes 10x faster than ubuntu-latest.
- A schema-typo PR forces 25+ GHA-minutes through 3 OS jobs, all of which are doing the same redundant `pip install` + setup.
- Required-status-check on a flaky Windows runner blocks merges. Windows winget hung on `--silent` (real CFM #1) — if that's a required check, every Windows runner regression blocks everyone.
- The fast feedback loop dies. Developers stop running CI mentally.

**Do this instead:** Two-tier (Pattern 1 above). `ci.yml` ubuntu-latest only for the fast path. Per-OS `install-*-e2e.yml` files for E2E, gated on `paths:` filters + manual `workflow_dispatch`.

### Anti-Pattern 2: Telemetry client that blocks installer on POST

**What people do:** `curl -X POST ...` (no `&`, no timeout). Installer waits for the network round-trip on every event. Bonus: retry-on-failure.

**Why it's wrong:**
- Installer hangs if endpoint is down or slow. Already saw this shape with WeaselDeployer.exe / SSH — adding it to telemetry would compound the failure modes.
- Retries on failure can DDoS your own endpoint when the endpoint comes back up.
- User experience: "smoodle install hung at 80%, what's happening?" → telemetry server is the explanation. Bad.

**Do this instead:** Async background spawn (`( curl ... ) &; disown`) with a hard 3s timeout. No retries. Lossy by design. Pattern 2 above.

### Anti-Pattern 3: SHA256 hash hardcoded in installer script

**What people do:** Embed the expected hash as a string literal in `install-librime-fork.sh`. Each release: edit the script, bump the hash, re-tag.

**Why it's wrong:**
- Drift: one script hardcodes `1.16.0-smoodle.1` hash; the other still has `1.16.0-smoodle.0`. Now both pass-but-one-is-wrong.
- Coupling: smoodle repo's tag must match smoodle-type/librime's tag. If they drift, install breaks until smoodle ships a new tag.
- Inflexibility: a hotfix dylib release requires re-tagging smoodle (this repo) just to update the hash.

**Do this instead:** Sidecar `.sha256` file in the librime fork's GH Releases, downloaded at install time. Pattern 3 above. The smoodle repo's installer pins by tag (`SMOODLE_LIBRIME_FORK_TAG=1.16.0-smoodle.1`); the librime fork owns the hash provenance.

### Anti-Pattern 4: LaunchAgent / scheduled task for hash-drift detection in Phase 1

**What people do:** Install a `~/Library/LaunchAgents/com.smoodle.verify-librime.plist` that runs daily, checks the dylib hash, re-swaps if drifted.

**Why it's wrong (for Phase 1):**
- New install footprint: `launchctl bootstrap`, `launchctl unload`, plist permissions. Each of these is its own gnarly UX trap on macOS 14+ (TCC, Background Items toggle in System Settings).
- New uninstall footprint: now smoodle has to ship an uninstaller that knows to remove the LaunchAgent.
- New attack surface: a daemon with sudo (re-swap requires sudo) is a much bigger target than an opt-in script.
- Sparkle re-swap is rare (Squirrel updates infrequently). A manual `bash scripts/verify-librime.sh` is a fine 30-second user action when the user notices ranking degraded.

**Do this instead (Phase 1):** `scripts/verify-librime.sh` as a manual one-shot. Print a warning at the bottom of `install-librime-fork.sh` telling the user how to re-run it. Reconsider LaunchAgent at Phase 2 when the audience is wider and "manually re-run a script" stops being a reasonable ask.

### Anti-Pattern 5: Building a custom telemetry endpoint (Express / Cloudflare Worker)

**What people do:** Write a small Node/Worker app that accepts POST, validates payload, writes to a custom DB, builds a dashboard.

**Why it's wrong:**
- Three months of "Phase 1 finish" timeline is being spent on infra that umami already provides.
- Maintenance burden in perpetuity.
- The "dashboard" component is the slow part; umami ships it.

**Do this instead:** Self-hosted umami on existing th-dc infra. Two containers (umami + postgres) via docker-compose ([xTom guide](https://xtom.com/blog/self-host-website-analytics-umami/)). Send events as `umami.track(event_name, payload)` shape via the [umami Send API](https://umami.is/docs/sending-stats). Total infra delta: one new container set on existing th-dc box. No new code to maintain on the receiving side.

### Anti-Pattern 6: Telemetry on by default

**What people do:** "We'll just collect anonymized data, opt-out if you don't want it." Adds a `telemetry: false` config to opt out.

**Why it's wrong (for this project):**
- Audience is diaspora-Thai friends and the founder. The trust model is personal. Surreptitious telemetry is socially expensive.
- The 100% audience is already vocal — bug reports and feature requests will surface qualitatively without analytics.
- Per `PROJECT.md` D2: "opt-in, default OFF, no PII, install_id_hash only." This is a project-level constraint, not just an architecture choice.

**Do this instead:** Default OFF. Single env var `SMOODLE_TELEMETRY=1` or sentinel file `~/.smoodle/telemetry-on` flips it on. Documented in README's optional "Help us improve" section.

## Integration Points

### External Services

| Service | Integration Pattern | Notes |
|---------|---------------------|-------|
| GitHub Releases (`smoodle-type/librime`) | HTTPS GET via curl/Invoke-WebRequest. Asset URL is `${REPO}/releases/download/${TAG}/${ASSET}`. Sidecar `.sha256` for hash. | Already in use. Phase 1 finish adds `.sha256` sidecar requirement to librime release.yml. |
| GitHub Releases (`smoodle-type/smoodle`) | `release.yml` workflow uses `gh release upload --clobber` to attach DMG + checksums on tag. | NEW. Phase 1 finish. |
| GHA macOS runner image | macos-14, ARM64. Uses `brew install --cask squirrel-app` for E2E. | NEW. Lane E close. |
| GHA Windows runner image | windows-latest. Uses `winget install Rime.Weasel`. WeaselDeployer GUI doesn't run headless — E2E tests `--silent` mode + verifies output files only, not the GUI. | NEW. Lane E close. |
| umami self-host (th-dc) | HTTPS POST to `/api/send`. Existing th-dc Caddy/Traefik fronts TLS. | NEW. Re-uses existing th-dc infra (no new VM/host). |
| Sparkle (Squirrel's auto-updater) | NOT a service we integrate with — we DETECT its side effect. `verify-librime.sh` re-hashes the dylib in place. | Manual user action. No daemon. |

### Internal Boundaries

| Boundary | Communication | Notes |
|----------|---------------|-------|
| `ci.yml` ↔ `tests/test_schema_lint.py` | exec, exit code | Stdlib Python; pytest not used (existing convention). |
| `install-mac-e2e.yml` ↔ `tests/test_install_e2e_mac.sh` | exec, exit code | Driver script wraps install + post-install verify. |
| `install-mac-e2e.yml` ↔ existing installer scripts | env vars (`SMOODLE_NONINTERACTIVE=1`, `SMOODLE_AUTO_DEPLOY=0`) | Already-existing override surface. |
| installers ↔ `scripts/lib/telemetry.sh` | bash source + function call | Sourced from each installer's prelude. Single function `smoodle_telemetry_event "$event"`. |
| `scripts/lib/telemetry.sh` ↔ umami endpoint | HTTPS POST, fire-and-forget | 3s timeout. No retries. |
| `release.yml` ↔ `scripts/build-macos-dmg.sh` | exec | Existing script; no behavior change. release.yml just adds `gh release upload`. |
| `verify-librime.sh` ↔ swapped dylib | filesystem read + shasum | No side effects unless user explicitly re-runs `install-librime-fork.sh`. |

## Build Order Implications (for roadmap)

Phase 1 finish naturally splits into 5 sub-lanes with inter-dependencies:

```
Lane F (CI fast path)           — independent, can start immediately
  ├─> ci.yml + test_schema_lint.py
  └─> blocks: nothing

Lane E1 (Lane E close — mac)    — depends on librime fork release.yml shipping .sha256 sidecar
  ├─> librime fork: release.yml emits dylib + dylib.sha256
  ├─> smoodle: install-librime-fork.sh adds SHA256 verify block
  ├─> smoodle: test_install_e2e_mac.sh
  └─> smoodle: install-mac-e2e.yml

Lane E2 (Lane E close — win)    — same dependency as E1
  ├─> librime fork: release.yml emits rime.dll + rime.dll.sha256
  ├─> smoodle: install-librime-fork.ps1 adds SHA256 verify
  ├─> smoodle: test_install_e2e_win.ps1
  └─> smoodle: install-win-e2e.yml

Lane T (Telemetry)              — depends on umami container running on th-dc
  ├─> th-dc: umami + postgres docker-compose up
  ├─> th-dc: caddy/traefik route telemetry.0dl.me → umami
  ├─> smoodle: scripts/lib/telemetry.{sh,ps1}
  ├─> smoodle: install scripts source telemetry helper
  └─> smoodle: tests/test_installers.py: unskip test_telemetry_opt_in_default_off

Lane H (Hardening)              — depends on Lane E1 + E2 (verify block lives in same file)
  ├─> smoodle: scripts/verify-librime.sh + .ps1
  ├─> smoodle: install-librime-fork.{sh,ps1}: post-install warning text about Sparkle re-swap
  └─> smoodle: README.md "if smoodle ranking degrades, run scripts/verify-librime.sh"

Lane R (Release automation)     — depends on Lane E1 (mac E2E green proves DMG ships)
  ├─> smoodle: release.yml (tag-triggered)
  └─> smoodle: build-macos-dmg.sh emits .sha256 sibling

Lane DG (Decision Gate)         — depends on ALL of above + 7-day soak
  └─> .planning/DECISION-GATE.md filled out and verdict written
```

**Suggested ordering:**
1. **Lane F** first (1 day) — schema lint is cheap and catches drift on every subsequent PR. Foundational.
2. **Lane E1 + E2 in parallel** (3-5 days) — both depend on librime fork's release.yml emitting `.sha256`. Bootstrap that one prerequisite, then the two installer-side tracks are independent.
3. **Lane T in parallel with E1/E2** (2-3 days) — depends on infra (th-dc), not on Lane E. Can run independently. Land late so the install scripts already have a stable shape before adding the telemetry source line.
4. **Lane H** (1 day) — small, depends on E1/E2. Slot in after they land.
5. **Lane R** (1 day) — small. After E1 mac E2E green.
6. **Lane DG** (0.5 day execution + 7+ days soak) — last, by definition.

**Total: ~8-12 working days excluding the 7-day soak. Matches PROJECT.md's "≤2 weeks of remaining work" budget.**

## Sources

- [.planning/codebase/ARCHITECTURE.md](file:///Users/lex/Dev/my_repos/experiment/smoodle/.planning/codebase/ARCHITECTURE.md) — existing architecture, HIGH confidence
- [.planning/codebase/CONCERNS.md](file:///Users/lex/Dev/my_repos/experiment/smoodle/.planning/codebase/CONCERNS.md) — known concerns + missing pieces, HIGH confidence
- [.planning/PROJECT.md](file:///Users/lex/Dev/my_repos/experiment/smoodle/.planning/PROJECT.md) — Phase 1 finish requirement list + D2 telemetry constraint
- [docs/LANE-B-WINDOWS.md](file:///Users/lex/Dev/my_repos/experiment/smoodle/docs/LANE-B-WINDOWS.md) — Windows install model + CFM #1 + WeaselDeployer headless behavior
- [docs/LANE-C-LINUX.md](file:///Users/lex/Dev/my_repos/experiment/smoodle/docs/LANE-C-LINUX.md) — Linux IM detection + librime distribution decision
- [.github/workflows/install-linux-e2e.yml](file:///Users/lex/Dev/my_repos/experiment/smoodle/.github/workflows/install-linux-e2e.yml) — existing single-OS workflow shape
- [GitHub Actions matrix strategy](https://docs.github.com/actions/using-jobs/using-a-matrix-for-your-jobs) — official matrix docs, MEDIUM (training+verification)
- [RunsOn matrix strategy guide](https://runs-on.com/github-actions/the-matrix-strategy/) — cost trade-offs of matrix on every PR, MEDIUM
- [Self-hosting Umami Analytics — xTom](https://xtom.com/blog/self-host-website-analytics-umami/) — minimum-component shape (umami + postgres), MEDIUM
- [Self-Hosted Site Analytics with Umami, Docker, and Traefik — Aaron J Becker](https://aaronjbecker.com/posts/self-hosted-analytics-umami-docker-compose-traefik/) — reverse-proxy pattern matching th-dc setup, MEDIUM
- [Umami Tracker functions](https://umami.is/docs/tracker-functions) — `umami.track()` Send API shape, MEDIUM
- [Akamai SHA-256 verification docs](https://techdocs.akamai.com/download-ctr/docs/verify-checksum) — post-download-pre-use pattern, MEDIUM
- [Linux sha256sum manpage](https://man7.org/linux/man-pages/man1/sha256sum.1.html) — `--check` flag for sidecar files, HIGH

---
*Architecture research for: Phase 1 finish — Thai phonetic IME (Rime/librime), 3-repo monorepo*
*Researched: 2026-05-08*
