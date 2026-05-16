# Requirements: Smoodle Phase 1 Finish

**Defined:** 2026-05-08
**Re-scoped:** 2026-05-16 (audit-driven; see `.planning/v0.0.6-MILESTONE-AUDIT.md` + `.planning/INTEGRATION-CHECK-v0.0.6.md`)
**Core Value:** A Thai phonetic IME good enough that the founder + diaspora-Thai friend wedge reaches for it daily — **on macOS first** (Windows + Linux deferred to v0.0.7-cross-platform). The v0.0.6 schema typing `sawadee → สวัสดี` reliably on a fresh macOS user's machine must work.

This is the **Phase 1 finish** scope — wrap-lane requirements after Phase 0 closed 2026-05-06 and Lane A/B/C/D shipped. Categories map 1:1 to research SUMMARY.md lanes (F → E1+E2+T → S → R → G). Imported context: PHASE1-PROMPT.md, RESUME.md, TODOS.md, codebase map, project research SUMMARY.md.

**Status legend (post 2026-05-16 re-scope):**
- `[x]` — satisfied for v0.0.6 (macOS dogfood ship)
- `[ ]` — open in v0.0.6 (currently only GATE-02)
- `[→ v0.0.7]` — code may exist in-tree but explicitly deferred to milestone v0.0.7-cross-platform per audit findings
- `[partial]` — partially satisfied; specific caveat applies

Cross-platform code (Windows installer, Linux installer, telemetry clients/infra) stays in-tree. Deferral means it's not claimed shipped for v0.0.6, not that it's removed.

## v1 Requirements

### Lint (Lane F — CI fast path)

- [x] **LINT-01**: `tests/test_schema_lint.py` validates structure of `schema/thai_phonetic.{schema,dict}.yaml` + `default.custom.yaml` (key allowlist, malformed weights, `import_preset` reference resolution, algebra rule shape — NOT regex semantics).
- [x] **LINT-02**: `.yamllint` config enforces YAML syntax + style rules (indentation, line length, trailing whitespace) on schema files.
- [x] **LINT-03**: `.github/workflows/ci.yml` runs ubuntu-only fast path on every PR: schema lint + existing `test_installers.py` shape tests + bash syntax (`bash -n`) + PowerShell parse check on Windows runner only when `.ps1` files change.
- [x] **LINT-04**: PowerShell `.ps1` files asserted ASCII-only (no em-dashes, no Thai characters) — guards against PowerShell 5.1 cp1252 parser breakage (CONCERNS.md MP-4).

### E2E — macOS (Lane E1)

- [x] **E2EMAC-01**: `tests/test_install_e2e_mac.sh` driver runs `scripts/install.sh` against fresh `~/Library/Rime/` on `macos-15` GHA runner; verifies schema files copied + Squirrel kill+restart succeeds.
- [x] **E2EMAC-02**: `.github/workflows/install-mac-e2e.yml` runs the driver on paths-filter (`scripts/install*.sh`, `schema/**`) + `workflow_dispatch` + weekly cron.
- [x] **E2EMAC-03**: SHA256 verification block added to `scripts/install-librime-fork.sh` between download and swap; reads expected hash from sidecar `librime-${FORK_TAG}-macOS-universal.dylib.sha256` next to the asset URL (PITFALLS CP-2).
- [x] **E2EMAC-04**: `install-librime-fork.sh` refuses to swap arm64-only dylib onto x86_64 Mac (`uname -m` + `lipo -archs` check; explicit error + exit 1; PITFALLS MP-3).
- [x] **E2EMAC-05**: GUI-required steps in mac E2E driver are explicitly gated (skipped on non-interactive runner) so passing CI does not falsely imply the `osascript`/Accessibility flow works (PITFALLS CP-4).

### E2E — Windows (Lane E2) — `[→ v0.0.7]` deferred from v0.0.6

> **Re-scoped 2026-05-16:** Windows E2E code shipped to main (live `windows-latest` run 25623956809 GREEN 2m12s 2026-05-10) but milestone-level claim deferred to v0.0.7-cross-platform. BLOCK-2 (`install-windows.ps1` has no `--uninstall` flag) breaks the 3-OS-parity claim. Code preserved in-tree.

- [ ] **E2EWIN-01** [→ v0.0.7]: `tests/test_install_e2e_win.ps1` Pester 5 driver runs `scripts/install-windows.ps1` against fresh `%APPDATA%\Rime\` on `windows-latest` GHA runner; verifies schema files copied + WeaselDeployer skipped (no GUI session) with explicit "manual deploy required" assertion.
- [ ] **E2EWIN-02** [→ v0.0.7]: `.github/workflows/install-win-e2e.yml` runs the Pester driver on paths-filter (`scripts/install*.ps1`, `schema/**`) + `workflow_dispatch` + weekly cron.
- [ ] **E2EWIN-03** [→ v0.0.7]: SHA256 verification block added to `scripts/install-librime-fork.ps1` between download and swap; reads expected hash from sidecar `rime-${FORK_TAG}-windows.dll.sha256` (PITFALLS CP-2).
- [ ] **E2EWIN-04** [→ v0.0.7]: Win runner `%APPDATA%\Rime\` cleared before each E2E job to prevent state contamination across runs (PITFALLS CP-4).
- [ ] **E2EWIN-05** [→ v0.0.7]: Pester driver verifies `Get-AuthenticodeSignature` check on `rime.dll` returns expected status (NotSigned for Phase 1 unsigned dogfood; assertion guards against future signature regressions).

### Telemetry (Lane T — opt-in, default OFF) — `[→ v0.0.7]` deferred from v0.0.6

> **Re-scoped 2026-05-16:** Telemetry infrastructure, clients, and forget CLI all landed in tree but milestone-level claim deferred to v0.0.7-cross-platform. Two FLAGs make the telemetry path non-functional in production today:
> - **FLAG-5:** `scripts/lib/telemetry.sh:15` website UUID is a placeholder (`a1b2c3d4-e5f6-7890-abcd-ef1234567890`); server will reject events.
> - **FLAG-6:** `scripts/lib/telemetry-forget.{sh,ps1}:12` defaults `FORGET_URL` to `http://localhost:8080` — no user has that.
> Code stays in-tree; deployment + the missing privacy-CLI README section move to v0.0.7.

- [ ] **TELEM-01** [→ v0.0.7]: umami v3.1.0 + PostgreSQL deployed on existing th-dc infra via `infra/telemetry/docker-compose.yml`; Caddy or Traefik fronts TLS for `telemetry.<chosen-subdomain>`; smoke-tested end-to-end with a manual `curl /api/send`.
- [ ] **TELEM-02** [→ v0.0.7]: `scripts/lib/telemetry.sh` async fire-and-forget POST helper with hard 3-second timeout, no retries, no daemon. Reads opt-in state from `~/.smoodle/telemetry-on` marker file or `SMOODLE_TELEMETRY=1` env var.
- [ ] **TELEM-03** [→ v0.0.7]: `scripts/lib/telemetry.ps1` PowerShell parallel of TELEM-02. Uses `Start-Job` or `Invoke-RestMethod -TimeoutSec 3` async; opt-in state from `$env:USERPROFILE\.smoodle\telemetry-on` or `$env:SMOODLE_TELEMETRY`.
- [ ] **TELEM-04** [→ v0.0.7]: All 3 OS installers prompt `[y/N]` (default-N) for telemetry opt-in on first run; write opt-in marker only if user types `y`. Prompt text explains: anonymous, install_id_hash only, can be disabled by `rm ~/.smoodle/telemetry-on`.
- [ ] **TELEM-05** [→ v0.0.7]: Ephemeral install_id generation: `sha256(/dev/urandom 16)` on Unix, `[System.Security.Cryptography.RandomNumberGenerator]` on Windows. Never persists hostname, username, or path. Strict allowlist payload schema (event name, OS, smoodle version, install_id_hash, librime_sha_match boolean).
- [ ] **TELEM-06** [→ v0.0.7]: `smoodle telemetry forget` CLI (bash + ps1) sends a server-side delete request keyed by install_id_hash; documented in README. Server-side endpoint: small Postgres `DELETE` runner alongside umami.
- [ ] **TELEM-07** [→ v0.0.7]: Server-side IP drop + timestamp rounding (to nearest hour) at umami ingestion to prevent small-N de-anonymization (PITFALLS CP-3).
- [ ] **TELEM-08** [→ v0.0.7]: 90-day retention policy enforced by daily Postgres cron (`DELETE FROM website_event WHERE created_at < NOW() - INTERVAL '90 days'`).
- [ ] **TELEM-09** [→ v0.0.7]: `tests/test_installers.py:test_telemetry_opt_in_default_off` is unskipped and asserts the prompt's default-N behavior across all 3 installers.

### Hardening (Lane S — Sparkle re-swap + release)

- [x] **HARDEN-01**: `scripts/verify-librime.sh` manual hash-drift checker computes current `librime.1.dylib` SHA256, compares to sidecar `.sha256` from the install-time download; reports drift with explicit "run install-librime-fork.sh to re-swap" instruction. NO daemon, NO LaunchAgent (PITFALLS CP-1).
- [x] **HARDEN-02** [partial — Windows side ships but is `[→ v0.0.7]`-deferred at milestone level]: `scripts/verify-librime.ps1` PowerShell parallel of HARDEN-01 for Windows hosts.
- [ ] **HARDEN-03** [→ v0.0.7 cross-repo]: Universal macOS dylib build added to `smoodle-type/librime`'s `smoodle-build.yml`: `lipo -create` join step combining `macos-15` + `macos-15-intel` artifacts into `librime-${FORK_TAG}-macOS-universal.dylib`; uploaded to GitHub Releases alongside `.sha256` sidecar. **Status:** cross-repo PR pending in `smoodle-type/librime`; tracked in STATE.md MP-3.
- [x] **HARDEN-04**: `release.yml` workflow on tag push: builds DMG via `scripts/build-macos-dmg.sh`, computes SHA256, uses **draft-then-publish** pattern (`gh release create --draft`, upload all assets, finalize via separate `gh release edit --draft=false`) to avoid mid-upload race (PITFALLS MP-5).
- [x] **HARDEN-05**: Tag-immutability CI guard rejects `gh release upload --clobber` semantics: workflow fails if release `updated_at != created_at` after publish (PITFALLS CP-2).
- [x] **HARDEN-06**: `scripts/install-librime-fork.sh` post-install warning text instructs user to run `verify-librime.sh` if Thai ranking ever degrades (Sparkle silent overwrite recovery path). **BLOCK-1 closure (2026-05-16):** `scripts/install.sh:212-216` trailing message also now references `verify-librime.sh` (previously pointed to stale `docs/RESUME.md`).
- [x] **HARDEN-07**: macOS `scripts/install.sh` schema timestamp touch (`touch -m schema/thai_phonetic.*.yaml`) added after `cp` loop to mirror Windows installer's `LastWriteTime = now` (CONCERNS.md mp-5).

### Docs (Lane R — README + docs hardening)

- [x] **DOCS-01**: `README.md` status flipped to `APPROVED` (was `APPROVED-PENDING-PHASE-0`); current version line `v0.0.6` (was stale earlier numbers). **Note (2026-05-16):** README updated to call out macOS-shippable + Windows/telemetry-experimental scope post-audit.
- [x] **DOCS-02** [partial — Windows + Linux snippets present, but `install-windows.ps1` is `[→ v0.0.7]` per BLOCK-2]: `README.md` install section gains Windows snippet (`winget install Rime.Weasel` + `.\scripts\install-windows.ps1` + `.\scripts\install-librime-fork.ps1`) + Linux snippet (`./scripts/install-linux.sh` + ranking-limitation note).
- [x] **DOCS-03**: `README.md` troubleshooting section covers top 5 scenarios: (a) "Smoodle not in input switcher"; (b) "ranking degraded after Squirrel auto-update" (refer to verify-librime.sh); (c) "Intel Mac error message"; (d) "Windows: Weasel installed but not registered"; (e) "Linux: candidate ranks wrong on first lookup."
- [ ] **DOCS-04** [partial — mac + linux installers have `--uninstall`; Windows `--uninstall` is `[→ v0.0.7]` per BLOCK-2]: `README.md` uninstall instructions per OS (`scripts/install.sh --uninstall` flag added; PowerShell + Linux equivalents).
- [x] **DOCS-05**: `LoneExile/*` references migrated to `smoodle-type/*` across 6 docs: `README.md`, `docs/RESUME.md`, `docs/LANE-B-WINDOWS.md`, `docs/LANE-B-HARDENING-PROMPT.md`, `docs/LANE-C-E2E-PROMPT.md`, `docs/CI-REFACTOR-PROMPT.md` (CONCERNS.md "LoneExile/* references" debt).
- [x] **DOCS-06**: `docs/RELEASE-CHECKLIST.md` documents the fresh-clone + 3-OS-install validation procedure to run before tagging a release (PITFALLS MP-1).
- [x] **DOCS-07**: Hardcoded absolute path `/Users/lex/Dev/my_repos/experiment/smoodle/...` in `docs/RESUME.md` line 67-69 dylib reapply recipe replaced with `${REPO_DIR}` placeholder + "from repo root" instruction.

### Decision Gate (Lane G — Phase 1 close)

- [ ] **GATE-01** [partial — MP-2 mitigation retracted per BLOCK-3]: `docs/DECISION-GATE-CRITERIA.md` written and committed **before** soak observation begins. Pre-registers ship-publicly-ready / stay-in-dogfood / inconclusive thresholds with explicit founder vs non-founder signal columns (PITFALLS MP-2). **Audit (2026-05-16):** the criteria document was committed 2 days AFTER Phase 2/3 first-green-runs, violating the pre-registration timing. The MP-2 anti-survivorship-bias mitigation is formally retracted. See `.planning/DECISION-GATE.md` § Pre-Registration Timing Caveat.
- [ ] **GATE-02** [open — pending non-founder recruits]: 7-day soak window after Lane E green: founder daily-use observed; ≥1 unsolicited bug report or feature request from a non-founder logged. **macOS-only soak per 2026-05-16 re-scope.**
- [x] **GATE-03**: `.planning/DECISION-GATE.md` checklist completed: each criterion checked (✓/✗) with evidence link or "no signal observed" annotation; small-N humility caveat included verbatim.
- [x] **GATE-04**: Verdict memo at end of `.planning/DECISION-GATE.md`: "ship-publicly-ready" / "stay-in-dogfood" / "inconclusive" — explicit decision with reasoning. Phase 1 closes on this commit. **Verdict:** stay-in-dogfood (macOS-only scope).

## v2 Requirements

Deferred to Phase 1.5 or Phase 2. Tracked but not in current roadmap.

### Phase 1.5 (post-Decision-Gate; gated on signal)

- **PHASE15-01**: LLM tone-disambiguation translator plugin (C++ librime plugin + llama.cpp + Qwen 1.8B Q4). Per design doc D4, this was the original Phase 2 scope; demoted to Phase 1.5 because dict's 100% TNC freq≥50 coverage is enough surface to test the wedge cleanly without LLM.
- **PHASE15-02**: `smoodle doctor` self-diagnose CLI — checks Squirrel/Weasel running, schema files present, librime SHA matches expected, opt-in state, last telemetry POST. Phase 1.5 differentiator (research D1).
- **PHASE15-03**: GH issue template prefilled via URL parameters with environment info (OS, smoodle version, librime SHA, last 50 lines of Console.app log) (research D2).
- **PHASE15-04**: README onboarding sentence + 5-second screen-recording GIF showing `sawadee → สวัสดี` typing flow (research D4).
- **PHASE15-05**: Pre-compiled dict `.bin` artifacts shipped alongside YAML — Rime/Weasel deployer skips compile step (research D5).
- **PHASE15-06**: Sparkle re-swap LaunchAgent (`launchd` `WatchPaths` recipe). Deferred from Phase 1 because daemon-with-sudo is the wrong shape for a 5-user dogfood (PITFALLS CP-1).
- **PHASE15-07**: Self-hosted Mac mini + Windows mini PC GHA runners for true GUI-session E2E (PITFALLS CP-4 deferred mitigation).
- **PHASE15-08**: SLSA build provenance attestations on librime fork releases.
- **PHASE15-09**: GHA E2E for Linux fcitx5 path (currently only ibus tested per CONCERNS.md).

### Phase 2 (post-Phase-1.5; gated on commercial commitment)

- **PHASE2-01**: iOS / iPadOS port. Blocked on TODOS #2 (BT-keyboard interception spike).
- **PHASE2-02**: Android port (low priority).
- **PHASE2-03**: Code-signing certificate procurement + Apple notarization — pre-public-ship gate.
- **PHASE2-04**: Windows MSI / WiX bundle — pre-public-ship gate.
- **PHASE2-05**: `smoodle.app` domain registration.
- **PHASE2-06**: Mac App Store / Microsoft Store listings.
- **PHASE2-07**: Auto-update infrastructure (Sparkle/Squirrel.Windows for smoodle itself).
- **PHASE2-08**: Cross-device dict sync.
- **PHASE2-09**: Stripe / payment integration (commercial path).
- **PHASE2-10**: Forked-rime distro packages on Linux (`.deb` for Ubuntu, AUR for Arch with patched libRime.so).

## Out of Scope

Explicitly excluded from Phase 1 finish. Documented to prevent scope creep mid-phase.

| Feature | Reason |
|---------|--------|
| Custom dictionary editor GUI (AF1) | Wedge audience too small; YAML editing in any text editor is fine for the founder + 5 friends |
| Cloud sync / cross-device dict sync (AF2/AF14) | iCloud Drive / OneDrive workaround works; Phase 2 if signal demands |
| Account systems / login (AF3) | No backend service that needs authentication |
| Auto-update infrastructure (AF5) for smoodle | Manual `git pull && ./install.sh` is fine for Phase 1 dogfood |
| iOS / Android installers (AF6) | Phase 2; blocked on iOS BT-keyboard interception spike |
| Code-signing / notarization (AF7) | Pre-public-ship gate; Phase 1 ships unsigned with documented Gatekeeper warning |
| MSI / WiX bundle (AF7) | Pre-public-ship gate; Phase 1 ships zip+scripts |
| Mac App Store / Microsoft Store (AF10) | Pre-public-ship gate |
| LLM tone-disambiguation plugin (AF13) | Demoted to Phase 1.5 per D4; dict coverage is sufficient surface |
| GUI installer / Tauri-Electron (AF11) | Bash + PowerShell scripts adequate for the wedge |
| Forked-rime distro packages on Linux (AF12) | Audience too small to justify per-distro maintenance burden |
| Upstream librime PR for peek-sort fix | TODOS #1 deferred 2026-05-06; fork absorbs the patch indefinitely |
| Sparkle re-swap LaunchAgent | Daemon-with-sudo wrong shape for 5-user dogfood (PITFALLS CP-1); Phase 1.5 deferral |
| SLSA build attestations | Phase 1.5 deferral; SHA256 sidecar is enough provenance for the wedge |
| Self-hosted Mac mini / Win runner for E2E | Phase 1.5 deferral; GHA-hosted runners + GUI-gating is acceptable |
| Cloudflare Worker custom telemetry endpoint | Perpetual maintenance; umami self-host on existing th-dc is simpler |
| PostHog OSS for telemetry | 16 GB RAM minimum; vastly over-spec for dogfood signal |
| GA4 / Mixpanel / Sentry | Third-party PII risk; opt-in self-host only |
| Hardcoded SHA256 in install scripts | Tag rewrites silently break it; sidecar `.sha256` instead (PITFALLS CP-2) |
| Single 3-OS GHA matrix on every PR | Mac+Win runners 10× slower; Win flakes block all PRs (architecture anti-pattern 1) |
| JSON Schema for Rime YAML lint | Algebra rules are regex-in-strings; JSON Schema can't introspect (PITFALLS CP-5) |
| Python `re.compile` checking algebra regex bodies | boost::regex divergence; engine-mode test is the regex oracle, not the linter (PITFALLS CP-5) |

## Traceability

All 41 v1 REQ-IDs mapped to phases by ROADMAP.md (2026-05-08); statuses last updated 2026-05-16 after milestone audit + re-scope.

**Status counts:** 22 satisfied · 5 partial · 2 open · 17 deferred-to-v0.0.7 = 46 (cross-counted because partials/deferreds overlap categories; canonical count is 22 v0.0.6-shippable + 17 v0.0.7 + 2 genuinely open in v0.0.6).

| Requirement | Phase | Status |
|-------------|-------|--------|
| LINT-01 | Phase 1 | Satisfied (verifier PASS) |
| LINT-02 | Phase 1 | Satisfied (verifier PASS) |
| LINT-03 | Phase 1 | Satisfied (verifier PASS) |
| LINT-04 | Phase 1 | Satisfied (verifier PASS) |
| E2EMAC-01 | Phase 2 | Satisfied (live macos-15 run 25594460125 GREEN) |
| E2EMAC-02 | Phase 2 | Satisfied (verifier PASS) |
| E2EMAC-03 | Phase 2 | Satisfied (verifier PASS) |
| E2EMAC-04 | Phase 2 | Satisfied (verifier PASS) |
| E2EMAC-05 | Phase 2 | Satisfied (verifier PASS) |
| E2EWIN-01 | Phase 3 | Deferred → v0.0.7 (code shipped, milestone claim deferred) |
| E2EWIN-02 | Phase 3 | Deferred → v0.0.7 |
| E2EWIN-03 | Phase 3 | Deferred → v0.0.7 |
| E2EWIN-04 | Phase 3 | Deferred → v0.0.7 |
| E2EWIN-05 | Phase 3 | Deferred → v0.0.7 |
| TELEM-01 | Phase 4 | Deferred → v0.0.7 (FLAG-5 placeholder UUID; server not deployed) |
| TELEM-02 | Phase 4 | Deferred → v0.0.7 |
| TELEM-03 | Phase 4 | Deferred → v0.0.7 |
| TELEM-04 | Phase 4 | Deferred → v0.0.7 |
| TELEM-05 | Phase 4 | Deferred → v0.0.7 |
| TELEM-06 | Phase 4 | Deferred → v0.0.7 (FLAG-1 README + FLAG-6 localhost default) |
| TELEM-07 | Phase 4 | Deferred → v0.0.7 |
| TELEM-08 | Phase 4 | Deferred → v0.0.7 |
| TELEM-09 | Phase 4 | Deferred → v0.0.7 |
| HARDEN-01 | Phase 5 | Satisfied (macOS verify-librime.sh) |
| HARDEN-02 | Phase 5 | Partial (Windows verify-librime.ps1 ships; milestone-level Windows scope deferred → v0.0.7) |
| HARDEN-03 | Phase 5 | Deferred → v0.0.7 (cross-repo: lipo-join in smoodle-type/librime) |
| HARDEN-04 | Phase 5 | Satisfied (release.yml live-verified on test tag v0.0.6-test-release) |
| HARDEN-05 | Phase 5 | Satisfied (tag-immutability guard live-verified) |
| HARDEN-06 | Phase 5 | Satisfied (BLOCK-1 closed 2026-05-16: install.sh:212-216 references verify-librime.sh) |
| HARDEN-07 | Phase 5 | Satisfied (schema timestamp touch in install.sh) |
| DOCS-01 | Phase 6 | Satisfied (README status APPROVED; scope-caveat added 2026-05-16) |
| DOCS-02 | Phase 6 | Partial (mac install snippet authoritative; Windows snippet in-tree but per BLOCK-2 not v0.0.6-shipped) |
| DOCS-03 | Phase 6 | Satisfied |
| DOCS-04 | Phase 6 | Partial (mac + linux --uninstall ship; Windows --uninstall → v0.0.7 per BLOCK-2) |
| DOCS-05 | Phase 6 | Satisfied (LoneExile → smoodle-type migration complete) |
| DOCS-06 | Phase 6 | Satisfied (RELEASE-CHECKLIST.md committed) |
| DOCS-07 | Phase 6 | Satisfied (hardcoded path replaced with ${REPO_DIR}) |
| GATE-01 | Phase 7 | Partial (criteria committed BUT 2 days AFTER E2E green; MP-2 mitigation retracted per BLOCK-3) |
| GATE-02 | Phase 7 | Open — pending non-founder recruits (macOS-only soak per re-scope) |
| GATE-03 | Phase 7 | Satisfied (.planning/DECISION-GATE.md checklist filled) |
| GATE-04 | Phase 7 | Satisfied (verdict: stay-in-dogfood; macOS-only scope per 2026-05-16) |

**Coverage:**
- v1 requirements: 41 total
- Mapped to phases: 41 ✓
- Unmapped: 0 ✓

**v0.0.6 disposition (post 2026-05-16 audit):**
- Satisfied: 22 (LINT × 4, E2EMAC × 5, HARDEN × 6 [excl. -03], DOCS × 5 [DOCS-01/03/05/06/07], GATE-03/04)
- Partial: 5 (HARDEN-02, DOCS-02, DOCS-04, GATE-01, and treated as v0.0.6-shipped with caveats)
- Open in v0.0.6: 1 (GATE-02 — pending non-founder recruits)
- Deferred → v0.0.7-cross-platform: 17 (E2EWIN × 5, TELEM × 9, HARDEN-03 cross-repo, DOCS-04 Windows portion accounted under Partial above; E2EWIN + TELEM are pure deferrals)

---
*Requirements defined: 2026-05-08*
*Re-scoped 2026-05-16 — milestone narrowed to macOS-only dogfood; Windows + telemetry → v0.0.7-cross-platform.*
*Audit trail: `.planning/v0.0.6-MILESTONE-AUDIT.md` + `.planning/INTEGRATION-CHECK-v0.0.6.md`.*
