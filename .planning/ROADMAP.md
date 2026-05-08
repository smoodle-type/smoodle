# Roadmap: Smoodle Phase 1 Finish

**Created:** 2026-05-08
**Milestone:** phase-1-finish
**Granularity:** standard (5-8 phases, 3-5 plans each)
**Parallelization:** enabled (Phases 2 / 3 / 4 run concurrently after Phase 1)
**Mode:** yolo

## Goal

Wrap Phase 1 of Smoodle: ship the Lane E (mac+win E2E), schema lint, opt-in telemetry, Sparkle re-swap detection + release hardening, README/docs hardening, and the Decision Gate close memo. v0.0.6 schema is the locked baseline — **no schema regen, no dict expansion** in this milestone.

## Coverage

- v1 requirements: **41**
- Mapped to phases: **41 / 41 (100%)** ✓
- Unmapped: **0** ✓

## Phases

- [ ] **Phase 1: Lint & CI Fast Path (Lane F)** — Schema lint test + ubuntu-only `ci.yml` running on every PR (~3 min). Foundational gate for every later PR.
- [ ] **Phase 2: macOS E2E (Lane E1)** — `install-mac-e2e.yml` + driver + SHA256 verify + Intel-Mac arch refusal + GUI-required-step gating. Runs in parallel with Phases 3 + 4 after Phase 1.
- [ ] **Phase 3: Windows E2E (Lane E2)** — `install-win-e2e.yml` + Pester 5 driver + SHA256 verify + clean-slate per job + Authenticode assertion. Runs in parallel with Phases 2 + 4 after Phase 1.
- [ ] **Phase 4: Telemetry (Lane T)** — umami self-host on th-dc + opt-in default-OFF clients + ephemeral install_id + purge endpoint + 90d retention. Runs in parallel with Phases 2 + 3 after Phase 1. Depends on infra-side th-dc deploy.
- [ ] **Phase 5: Sparkle Re-Swap & Release Hardening (Lane S)** — `verify-librime.{sh,ps1}` (manual, no daemon) + universal macOS dylib (cross-repo work in `smoodle-type/librime`) + atomic draft-then-publish `release.yml` + tag-immutability CI guard + schema timestamp touch. Depends on Phases 2 + 3.
- [ ] **Phase 6: README & Docs Hardening (Lane R)** — Status flip APPROVED + Win/Linux install snippets + troubleshooting top-5 + uninstall instructions + LoneExile/* → smoodle-type/* migration + RELEASE-CHECKLIST.md. Depends on Phase 5.
- [ ] **Phase 7: Decision Gate Close (Lane G)** — Pre-register criteria *first* (PITFALLS MP-2), then 7-day soak + verdict memo. Depends on Phase 6 + 7-day calendar soak after Lane E green.

## Phase Details

### Phase 1: Lint & CI Fast Path
**Goal**: Every PR is gated by a fast (~3 min) ubuntu-only check that catches schema typos, malformed weights, broken `import_preset` references, bash/pwsh syntax errors, and non-ASCII bytes in `.ps1` files **before** they merge. Foundational for every subsequent phase's PR flow.
**Depends on**: Nothing (first phase)
**Requirements**: LINT-01, LINT-02, LINT-03, LINT-04
**Success Criteria** (what must be TRUE):
  1. `tests/test_schema_lint.py` runs in <2s locally and rejects a deliberately-broken `thai_phonetic.schema.yaml` (e.g., negative weight, malformed `import_preset` reference, missing required key) with a clear error message.
  2. `.yamllint` config exists at repo root; `yamllint schema/*.yaml schema/default.custom.yaml` exits 0 on the v0.0.6 baseline.
  3. `.github/workflows/ci.yml` is green on a fresh PR that touches only `README.md`; same workflow fails red on a PR that introduces a schema regression or a non-ASCII byte in a `.ps1` file.
  4. `bash -n scripts/install*.sh` and `pwsh -NoProfile -c "[scriptblock]::Create((Get-Content -Raw scripts/install-windows.ps1))"` both run as gated steps inside `ci.yml` and surface syntax errors.
**Plans**: 2 plans (2 waves)

  **Wave 1 (autonomous):**
  - [ ] 01-01-PLAN.md — Schema lint validator + .yamllint config + 4 broken-schema fixtures (LINT-01, LINT-02)

  **Wave 2** *(blocked on Wave 1 completion; autonomous: no — checkpoint:human-verify)*:
  - [ ] 01-02-PLAN.md — ci.yml ubuntu-latest fast path + tests/test_powershell_ascii.py + 3 smoke-test PRs (LINT-03, LINT-04)

  **Cross-cutting constraints** (apply to both plans):
  - CP-5 boundary: schema lint validates STRUCTURE only (key allowlist, malformed weights, import_preset, algebra rule shape) — NOT regex semantics. Engine-mode test (`test_dict.py --use-rime-api-console`) is the regex oracle.
  - Two-tier CI: `ci.yml` is ubuntu-latest only. NOT a 3-OS matrix on every PR.
  - Tests use Python `unittest` (matches `tests/test_installers.py`), NOT pytest.

### Phase 2: macOS E2E (Lane E1)
**Goal**: A regression in `scripts/install.sh` or `scripts/install-librime-fork.sh` is caught automatically by GHA before reaching the founder's dogfood machine, on a `macos-15` runner with explicit GUI-step gating so passing CI does not falsely imply the `osascript`/Accessibility flow works.
**Depends on**: Phase 1 (CI workflow conventions land first); cross-repo prereq — `smoodle-type/librime` `release.yml` must emit `librime-${TAG}-macOS-universal.dylib.sha256` sidecar (handled in Phase 5 for the universal join, but a stub `.sha256` for the existing arm64 dylib unblocks E2E SHA verify immediately).
**Requirements**: E2EMAC-01, E2EMAC-02, E2EMAC-03, E2EMAC-04, E2EMAC-05
**Success Criteria** (what must be TRUE):
  1. Running `.github/workflows/install-mac-e2e.yml` via `workflow_dispatch` on a fresh `macos-15` runner produces `~/Library/Rime/thai_phonetic.dict.yaml` with a SHA matching the repo's `schema/thai_phonetic.dict.yaml`, and the workflow exits green.
  2. `tests/test_install_e2e_mac.sh` invoked locally on an Apple Silicon Mac with `SMOODLE_GUI_SESSION=0` skips the `osascript` kill+restart step with a clear "no-GUI-session, skipped" log line and exits 0; with `SMOODLE_GUI_SESSION=1` it executes the full path.
  3. `scripts/install-librime-fork.sh` invoked on an `x86_64` Mac against an `arm64`-only dylib refuses to swap with a non-zero exit and prints "this is an arm64-only dylib; Intel Mac not supported until universal dylib lands" (PITFALLS MP-3).
  4. SHA256 verification block runs *between* download and swap; an artificially-corrupted dylib triggers exit 1 *before* any sudo cp executes (PITFALLS CP-2).
  5. The workflow runs on `paths-filter` (`scripts/install*.sh`, `schema/**`) + `workflow_dispatch` + weekly cron — confirmed by inspecting `install-mac-e2e.yml` triggers section.
**Plans**: TBD

### Phase 3: Windows E2E (Lane E2)
**Goal**: A regression in `scripts/install-windows.ps1` or `scripts/install-librime-fork.ps1` is caught automatically by GHA before reaching the th-dc dockur dogfood test bed, on a `windows-latest` runner with `%APPDATA%\Rime\` cleared per job to prevent state contamination across runs.
**Depends on**: Phase 1 (CI workflow conventions land first); cross-repo prereq — `smoodle-type/librime` `release.yml` must emit `rime-${TAG}-windows.dll.sha256` sidecar.
**Requirements**: E2EWIN-01, E2EWIN-02, E2EWIN-03, E2EWIN-04, E2EWIN-05
**Success Criteria** (what must be TRUE):
  1. Running `.github/workflows/install-win-e2e.yml` via `workflow_dispatch` on a fresh `windows-latest` runner produces `%APPDATA%\Rime\thai_phonetic.dict.yaml` with a SHA matching the repo source, and the Pester 5 driver `tests/test_install_e2e_win.ps1` reports all `Describe` blocks green.
  2. The driver explicitly asserts WeaselDeployer GUI step was *skipped* (no GUI session) with a "manual deploy required" log line — passing CI does not falsely claim the GUI flow works.
  3. `Get-AuthenticodeSignature` on `rime.dll` returns `NotSigned` (Phase 1 unsigned dogfood expectation); test fails red if the signature status changes unexpectedly (guards future regressions).
  4. Pre-step `Remove-Item -Recurse -ErrorAction SilentlyContinue $env:APPDATA\Rime, "$env:LOCALAPPDATA\Rime"` runs before each job; idempotency test verifies clean-slate state.
  5. SHA256 verification block runs *between* download and swap in `install-librime-fork.ps1`; corrupted dll triggers exit 1 before any `Move-Item` to `Weasel\Frameworks\rime.dll`.
**Plans**: TBD

### Phase 4: Telemetry (Lane T)
**Goal**: Founder gains an opt-in, default-OFF, no-PII install signal pipeline (founder-visible at `telemetry.<chosen-subdomain>/dashboard`) that sanity-checks "did the install actually work for non-founder N=2..5 friends" without surrendering anonymity at small-N. **NOT** a Decision Gate input — qualitative signals dominate the gate per Phase 0 close.
**Depends on**: Phase 1 (CI conventions); **infra-side blocking precondition** — umami v3.1.0 + PostgreSQL deployed on th-dc via `infra/telemetry/docker-compose.yml`, fronted by Caddy/Traefik TLS for the chosen subdomain. **RISK FLAG**: if th-dc deploy slips, this phase moves to Phase 1.5 (per research SUMMARY.md "Open question for roadmapper" recommendation). For now keep in Phase 1; revisit at Phase 4 plan-phase if blocker surfaces.
**Requirements**: TELEM-01, TELEM-02, TELEM-03, TELEM-04, TELEM-05, TELEM-06, TELEM-07, TELEM-08, TELEM-09
**Success Criteria** (what must be TRUE):
  1. `telemetry.<chosen-subdomain>/api/send` returns 200 on a manual `curl -X POST` with the strict allowlist payload `{event, install_id_hash, os, smoodle_version, librime_sha_match, ts}`; the umami dashboard at the same host renders the event within 30s.
  2. Running any of the 3 OS installers with `SMOODLE_TELEMETRY` unset produces zero outbound network traffic to the telemetry host (verified via `tcpdump`/`netsh trace` — opt-in default-OFF respected).
  3. Running with `SMOODLE_TELEMETRY=1` (or `~/.smoodle/telemetry-on` marker) fires a single async POST per install lifecycle event with hard 3-second timeout; if the endpoint is unreachable the installer still exits 0 (fire-and-forget, never blocking).
  4. `smoodle telemetry forget` CLI sends a server-side delete request keyed by install_id_hash; running it twice exits cleanly the second time (idempotent); the umami DB no longer contains rows for that install_id_hash.
  5. `tests/test_installers.py:test_telemetry_opt_in_default_off` is unskipped and asserts the `[y/N]` default-N prompt across all 3 installers; CI exit code is 0.
  6. Server-side IP drop + timestamp rounding to nearest hour confirmed at umami ingestion (verified by inspecting a stored row's IP column = NULL, ts column = hour-rounded epoch).
**Plans**: TBD

### Phase 5: Sparkle Re-Swap & Release Hardening (Lane S)
**Goal**: After a Squirrel auto-update silently overwrites the patched `librime.1.dylib`, the founder (or a dogfood friend) can run `bash scripts/verify-librime.sh` and get a clear "drift detected — re-run install-librime-fork.sh" message; release tag rewrites are physically prevented; Intel Macs are no longer silently broken (universal dylib ships); release.yml uses atomic draft-then-publish to avoid mid-upload race.
**Depends on**: Phase 2 + Phase 3 (SHA256 verify block lives in same `install-librime-fork.{sh,ps1}` files; co-locate to avoid merge friction). **CROSS-REPO DEPENDENCY**: HARDEN-03 (universal macOS dylib) requires a `lipo -create` join step + universal-artifact upload added to `smoodle-type/librime`'s `smoodle-build.yml` — upstream work in the librime fork repo, not this one. Schedule the cross-repo PR as the first sub-task within this phase.
**Requirements**: HARDEN-01, HARDEN-02, HARDEN-03, HARDEN-04, HARDEN-05, HARDEN-06, HARDEN-07
**Success Criteria** (what must be TRUE):
  1. `bash scripts/verify-librime.sh` on a machine where Sparkle has overwritten the patched dylib reports `WARN: librime.1.dylib drift detected. Re-run install-librime-fork.sh` and exits with non-zero code; on a clean machine it exits 0 silently. **No LaunchAgent, no daemon** (PITFALLS CP-1).
  2. `scripts/install-librime-fork.sh` post-install message instructs user verbatim: "if Thai ranking ever degrades, run scripts/verify-librime.sh"; HARDEN-06 confirmed by reading the script's tail-end echo block.
  3. `lipo -archs $(curl -fsSL <release-url>/librime-${TAG}-macOS-universal.dylib)` returns `arm64 x86_64` (universal binary); SHA256 sidecar `librime-${TAG}-macOS-universal.dylib.sha256` exists at the same release URL — both verified against the live `smoodle-type/librime` GitHub Releases page.
  4. `release.yml` workflow on a tag push uses `gh release create --draft` → upload all assets → `gh release edit --draft=false` (atomic draft-then-publish, PITFALLS MP-5); a deliberate mid-upload abort leaves the release in draft state, never visible to install scripts.
  5. Tag-immutability CI guard: a workflow that runs `gh release view ${TAG} --json assets --jq '.assets[].updated_at'` and `created_at` comparison fails red if `updated_at != created_at` after publish (PITFALLS CP-2).
  6. `scripts/install.sh` runs `touch -m schema/thai_phonetic.*.yaml` after the cp loop (mirrors Windows' `LastWriteTime = now`); rsync-from-Time-Machine no longer skips Squirrel recompile silently (CONCERNS.md mp-5).
**Plans**: TBD

### Phase 6: README & Docs Hardening (Lane R)
**Goal**: A fresh diaspora-Thai friend who lands on `https://github.com/smoodle-type/smoodle` reads the README, picks their OS, runs the documented commands, and ends up with a working `sawadee → สวัสดี` typing flow on the first try — including troubleshooting paths for the top 5 known failure scenarios. All `LoneExile/*` references are gone; status reflects current phase truth.
**Depends on**: Phase 5 (README documents what S ships — `verify-librime.sh` reference, universal-dylib install snippet, Sparkle-recovery troubleshooting entry).
**Requirements**: DOCS-01, DOCS-02, DOCS-03, DOCS-04, DOCS-05, DOCS-06, DOCS-07
**Success Criteria** (what must be TRUE):
  1. `README.md` line 21-ish status badge reads `APPROVED` (was `APPROVED-PENDING-PHASE-0`); version line reads `v0.0.6`; `git grep -in 'LoneExile' README.md docs/RESUME.md docs/LANE-B-WINDOWS.md docs/LANE-B-HARDENING-PROMPT.md docs/LANE-C-E2E-PROMPT.md docs/CI-REFACTOR-PROMPT.md` returns zero hits.
  2. README install section contains 3 sub-sections (macOS / Windows / Linux), each with copy-paste-ready commands; running the Windows snippet on a fresh dockur/windows VM end-to-end produces a working candidate `sawatd → สวัสดี` (validated against the existing th-dc test bed).
  3. README troubleshooting section covers all 5 named scenarios verbatim: (a) Smoodle not in input switcher; (b) ranking degraded after Squirrel auto-update (refer to `verify-librime.sh`); (c) Intel Mac error message; (d) Windows: Weasel installed but not registered; (e) Linux: candidate ranks wrong on first lookup.
  4. `scripts/install.sh --uninstall` flag exists and removes only Smoodle-owned files from `~/Library/Rime/`; PowerShell + Linux equivalents documented in README uninstall section.
  5. `docs/RELEASE-CHECKLIST.md` exists at HEAD and describes the fresh-clone + 3-OS-install validation procedure (PITFALLS MP-1) to run before tagging a release; the founder runs it once on a fresh VM and the checklist passes.
  6. `docs/RESUME.md` line 67-69 dylib reapply recipe uses `${REPO_DIR}` placeholder (not `/Users/lex/Dev/my_repos/experiment/smoodle/...`); `git grep -nE '/Users/lex/Dev/my_repos/experiment/smoodle' docs/` returns zero hits.
**Plans**: TBD

### Phase 7: Decision Gate Close (Lane G)
**Goal**: Phase 1 closes with an honest, pre-registered verdict — "ship-publicly-ready" / "stay-in-dogfood" / "inconclusive" — based on qualitative signals collected during a 7-day soak following Lane E green, with explicit founder vs non-founder signal columns and a small-N humility caveat.
**Depends on**: Phase 6 (docs land before observation begins); Phases 2 + 3 must be green for at least 7 calendar days before GATE-02 soak completes. **CRITICAL ORDERING**: GATE-01 (pre-registration of `docs/DECISION-GATE-CRITERIA.md`) must be the FIRST sub-task in this phase, *before* any soak observation — pre-registration *after* observing signal is survivorship bias by definition (PITFALLS MP-2).
**Requirements**: GATE-01, GATE-02, GATE-03, GATE-04
**Success Criteria** (what must be TRUE):
  1. `docs/DECISION-GATE-CRITERIA.md` exists and is committed to `main` *before* the soak window opens; the commit's `git log` timestamp is earlier than the earliest `gh run list --workflow=install-mac-e2e.yml --created='>=YYYY-MM-DD'` green run start (verifiable from git history).
  2. The 7-day soak window has elapsed since both `install-mac-e2e.yml` and `install-win-e2e.yml` first turned green; founder daily-use logged in a separate column from non-founder signals.
  3. `.planning/DECISION-GATE.md` checklist is filled out: every pre-registered criterion has a `✓` or `✗` with an evidence link (commit SHA, GH issue URL, or a "no signal observed" annotation); founder vs non-founder columns are visibly separated.
  4. Verdict memo at the tail of `.planning/DECISION-GATE.md` reads exactly one of "ship-publicly-ready" / "stay-in-dogfood" / "inconclusive" with a 1-3 paragraph rationale and a small-N humility caveat verbatim ("Decision is based on N=<num> non-founder signals. With N≤5, this is a directional read, not a statistical one.").
**Plans**: TBD

## Progress

| Phase | Plans Complete | Status | Completed |
|-------|----------------|--------|-----------|
| 1. Lint & CI Fast Path | 0/? | Not started | - |
| 2. macOS E2E | 0/? | Not started | - |
| 3. Windows E2E | 0/? | Not started | - |
| 4. Telemetry | 0/? | Not started | - |
| 5. Sparkle & Release Hardening | 0/? | Not started | - |
| 6. README & Docs Hardening | 0/? | Not started | - |
| 7. Decision Gate Close | 0/? | Not started | - |

## Phase Dependency Graph

```
Phase 1 (Lane F: lint + ci.yml)            [foundational, runs first]
   │
   ├──→ Phase 2 (Lane E1: mac E2E)         ┐
   ├──→ Phase 3 (Lane E2: win E2E)         ├─ run in parallel after Phase 1
   └──→ Phase 4 (Lane T: telemetry) ⚠️     ┘  ⚠️ TELEM-01 blocked on th-dc umami deploy

Phase 2 + Phase 3
   │
   └──→ Phase 5 (Lane S: Sparkle + release hardening)
          ⚠️ HARDEN-03 universal dylib = cross-repo PR in smoodle-type/librime

Phase 5
   │
   └──→ Phase 6 (Lane R: README + docs)

Phase 6 + (Phase 2/3 green for 7 calendar days)
   │
   └──→ Phase 7 (Lane G: Decision Gate)
          ⚠️ GATE-01 pre-registration MUST be the first sub-task
             (PITFALLS MP-2 — survivorship bias prevention)
```

## Risks & Cross-Repo Dependencies

| Risk / Dependency | Phase | Mitigation |
|-------------------|-------|------------|
| Telemetry endpoint deploy on th-dc slips → blocks Phase 4 | Phase 4 | Phase moves to Phase 1.5 if blocker not cleared at plan-phase; flag at `/gsd-plan-phase 4`. Decision Gate is qualitative anyway — telemetry is sanity-check only. |
| Universal macOS dylib (HARDEN-03) needs `lipo -create` step in `smoodle-type/librime`'s `smoodle-build.yml` | Phase 5 | Cross-repo PR landed as Phase 5 plan-phase's first sub-task; success criterion 3 verifies via live release URL. |
| `smoodle telemetry forget` server endpoint — umami doesn't ship per-install delete OOTB | Phase 4 | Custom Postgres `DELETE` runner alongside umami; covered in TELEM-06; deeper research recommended at plan-phase via `/gsd-research-phase`. |
| GATE-01 pre-registration must be committed *before* GATE-02 soak observation begins | Phase 7 | First-sub-task ordering enforced via plan-phase plan ordering; verifiable from `git log` timestamps. |
| GHA non-interactive runner false-confidence E2E (PITFALLS CP-4) | Phases 2 + 3 | Explicit GUI-required step gating in success criteria 2 (mac) + 2 (win); runner-clean-slate per Win job in success criterion 4 (win). |

## Out of Scope (do NOT add to Phase 1 finish)

- Schema regen or dict expansion (v0.0.6 is the locked baseline; further dict work is Phase 1.5 / dict-only milestone, not this milestone).
- LLM tone-disambiguation translator plugin (PHASE15-01).
- iOS / Android installers, code-signing, MAS/winget submission (Phase 2).
- Sparkle re-swap LaunchAgent (PITFALLS CP-1; daemon-with-sudo wrong shape for 5-user dogfood; Phase 1.5 deferral).
- SLSA build provenance attestations (Phase 1.5 deferral; SHA256 sidecar is enough provenance for the wedge).
- GHA E2E for Linux fcitx5 path (currently only ibus tested; smaller wedge of smaller wedge).
- Hardcoded SHA256 in install scripts (sidecar `.sha256` instead — PITFALLS CP-2).
- Single 3-OS GHA matrix on every PR (architecture anti-pattern 1; mac+win runners 10× slower).

## Traceability

See `.planning/REQUIREMENTS.md` Traceability table — all 41 v1 REQ-IDs mapped.

---
*Roadmap created: 2026-05-08 (rolled up from research SUMMARY/PITFALLS/ARCHITECTURE + REQUIREMENTS.md + PROJECT.md)*
*Next: `/gsd-plan-phase 1` to break Phase 1 (Lane F) into plans.*
