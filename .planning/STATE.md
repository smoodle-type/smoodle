# Project State: Smoodle Phase 1 Finish

**Last updated:** 2026-05-25 (v0.0.7-cross-platform opened; W2 telemetry partially closed)
**Status:** PHASE-1-MACOS-SHIPPABLE + v0.0.7-cross-platform IN PROGRESS — v0.0.6 macOS verdict (stay-in-dogfood) holds; W2 telemetry deployment is live on `dxc.0dl.me` (umami + forget-api behind Cloudflare tunnel; FLAG-5 + FLAG-6 + FLAG-1 closed). W1 Windows + W3 Linux disclosure + W4 cross-repo dylib + W5 audit-trail backfill still queued. MP-2 pre-registration anchor: commit `067d1c5` 2026-05-25 12:14 +0700.
**Mode:** yolo

## 2026-05-16 Audit Re-Scope (binding)

Audit `.planning/v0.0.6-MILESTONE-AUDIT.md` + integration check `.planning/INTEGRATION-CHECK-v0.0.6.md` (run 2026-05-16) surfaced 3 BLOCK + 6 FLAG + 7 PASS findings. Re-scope decisions:

**v0.0.6 (this milestone) — keeps:** Phase 1 lint, Phase 2 macOS E2E, Phase 5 macOS-side release hardening, Phase 6 macOS docs, Phase 7 decision gate (macOS-scoped, with timing caveat per BLOCK-3).

**v0.0.6 — fixed on re-scope:** BLOCK-1 (`scripts/install.sh:216` stale `docs/RESUME.md` reference replaced with `bash scripts/verify-librime.sh` invocation). BLOCK-3 (`.planning/DECISION-GATE.md` updated with Pre-Registration Timing Caveat retracting MP-2 mitigation claim).

**v0.0.6 — deferred to v0.0.7-cross-platform:**
- BLOCK-2: `scripts/install-windows.ps1` `--uninstall` flag missing (DOCS-04 Windows portion).
- FLAG-1: README missing telemetry-forget privacy-CLI subsection (TELEM-06).
- FLAG-4: `.github/workflows/install-linux-e2e.yml` not in ROADMAP — formal disclosure or removal.
- FLAG-5: `scripts/lib/telemetry.sh:15` placeholder umami website UUID (TELEM-01/02/03).
- FLAG-6: `scripts/lib/telemetry-forget.{sh,ps1}:12` defaults `FORGET_URL` to localhost (TELEM-06).
- All E2EWIN-01..05 (Windows E2E milestone-level claim).
- All TELEM-01..09 (telemetry milestone-level claim).
- HARDEN-03 (cross-repo universal dylib lipo-join in `smoodle-type/librime`).

**v0.0.6 — accepted tech debt (FLAG-2):** Phases 4, 5, 6, 7 closed without `*-VERIFICATION.md`. Acceptable for v0.0.6 close given the audit doc + integration check serve as the verifier-equivalent rollup. Backfilling per-phase `VERIFICATION.md` is queued as v0.0.7 W5.

**Cross-platform code mandate (preserved):** Windows installer, Linux installer, telemetry clients, telemetry infra all remain in-tree. macOS-side work on shared modules must not break the Windows/Linux/telemetry paths — future v0.0.7 finish-work depends on this.

## Project Reference

**Project:** Smoodle — Pinyin-style phonetic input method for typing Thai. Type `sawadee` → see candidate `สวัสดี` → press space to commit. Ships as a Rime schema + a patched librime fork on top of existing Rime hosts (Squirrel/macOS, Weasel/Windows, fcitx5+ibus/Linux).

**Core value:** A Thai phonetic IME good enough that the founder + diaspora-Thai friend wedge reaches for it daily on macOS+Windows. **The v0.0.6 schema typing `sawadee → สวัสดี` reliably on a fresh user's machine must work** — if everything else fails, that's the survival floor.

**Milestone:** phase-1-finish (wrap Phase 1 dogfood; close Lane E + telemetry + README hardening + Decision Gate)

**Source documents:**
- [`.planning/PROJECT.md`](./PROJECT.md) — full project context, validated requirements, key decisions, constraints
- [`.planning/REQUIREMENTS.md`](./REQUIREMENTS.md) — 41 v1 REQ-IDs across 6 lanes (Lint, E2E-mac, E2E-win, Telemetry, Hardening, Docs, Gate)
- [`.planning/ROADMAP.md`](./ROADMAP.md) — 7-phase structure with goal-backward success criteria
- [`.planning/research/SUMMARY.md`](./research/SUMMARY.md) — research synthesis (~8-12 working days + 7-day soak)
- [`.planning/research/PITFALLS.md`](./research/PITFALLS.md) — 5 critical + 5 moderate pitfalls lane-mapped
- [`.planning/research/ARCHITECTURE.md`](./research/ARCHITECTURE.md) — component boundaries, build order, anti-patterns
- [`.planning/codebase/`](./codebase/) — existing codebase map (CONCERNS.md, STRUCTURE.md, ARCHITECTURE.md)

## Current Position

**Phase:** v0.0.6 milestone CLOSED with macOS-only scope. Audit 2026-05-16 re-scoped Windows + telemetry to v0.0.7-cross-platform.
**Plans:** docs/DECISION-GATE-CRITERIA.md committed (GATE-01 partial per BLOCK-3 timing caveat), .planning/DECISION-GATE.md checklist filled + timing caveat appended 2026-05-16 (GATE-03/GATE-04 satisfied; verdict: stay-in-dogfood macOS-scoped).

**Phase 1 (LINT):** CLOSED — 4/4 SC met, verifier PASS. LINT-01..04 satisfied.
**Phase 2 (E2EMAC):** CLOSED — 5/5 SC met, verifier PASS, live macos-15 run 25594460125 GREEN in 1m 4s. E2EMAC-01..05 satisfied.
**Phase 3 (E2EWIN):** CODE-COMPLETE, MILESTONE-DEFERRED → v0.0.7 — live windows-latest run 25623956809 GREEN in 2m 12s, but BLOCK-2 (`install-windows.ps1` missing `--uninstall`) blocks the cross-platform claim. Code preserved in-tree.
**Phase 4 (TELEM):** CODE-COMPLETE, MILESTONE-DEFERRED → v0.0.7 — infra/clients/forget CLI all on disk, but FLAG-5 (placeholder umami UUID) + FLAG-6 (localhost forget endpoint) mean telemetry won't reach a server. Code preserved in-tree.
**Phase 5 (HARDEN):** CLOSED (macOS-side) — verify-librime.sh + release.yml + tag-immutability guard live-verified on test tag v0.0.6-test-release. HARDEN-01/04/05/06/07 satisfied; HARDEN-02 partial (Windows verify-librime.ps1 ships but milestone scope deferred); HARDEN-03 deferred → v0.0.7 (cross-repo).
**Phase 6 (DOCS):** CLOSED (macOS-side) — README APPROVED + macOS install snippet + troubleshooting + macOS `--uninstall` + LoneExile→smoodle-type migration + RELEASE-CHECKLIST.md + BLOCK-1 fix. DOCS-01/03/05/06/07 satisfied; DOCS-02/04 partial (Windows portions deferred → v0.0.7).
**Phase 7 (GATE):** CLOSED (macOS-scoped) — checklist + verdict (stay-in-dogfood) + pre-registration timing caveat. GATE-03/04 satisfied; GATE-01 partial per BLOCK-3 caveat; GATE-02 open pending non-founder recruits.

**Next action:** Recruit 2-5 diaspora-Thai friends with **macOS machines** for the 7-day soak (GATE-02). When signal arrives, run `/gsd-new-milestone v0.0.7-cross-platform` to formalize the deferred Windows + telemetry work.

```
v0.0.6 progress: [■■◐◐■◐◐] macOS-scoped CLOSED
                  1 2 3 4 5 6 7
                  ^ ^   ^ ^ ^
                  satisfied: Phase 1 LINT + Phase 2 E2EMAC + Phase 5 HARDEN-mac + Phase 6 DOCS-mac
                  ◐ partial/deferred: Phase 3 E2EWIN → v0.0.7, Phase 4 TELEM → v0.0.7,
                                       Phase 6 DOCS-04-win → v0.0.7, Phase 7 GATE (timing caveat)

Coverage (v0.0.6 disposition):
  Satisfied:                22 REQ-IDs (LINT × 4, E2EMAC × 5, HARDEN × 6, DOCS × 5, GATE × 2)
  Partial w/ caveat:         5 REQ-IDs (HARDEN-02, DOCS-02, DOCS-04, GATE-01, GATE-04-scope)
  Open in v0.0.6:            1 REQ-ID (GATE-02 — pending non-founder recruits)
  Deferred → v0.0.7:        17 REQ-IDs (E2EWIN × 5, TELEM × 9, HARDEN-03 cross-repo,
                                          DOCS-04-win + FLAG-1 + FLAG-5 + FLAG-6 in scope-list)

v0.0.7-cross-platform queue (formalize after macOS soak signal arrives):
  - Close BLOCK-2: Port --uninstall block from install-linux.sh:25-72 into install-windows.ps1
  - Close FLAG-5: Replace placeholder umami website UUID with real telemetry.0dl.me site_id
  - Close FLAG-6: Change FORGET_URL default to production HTTPS endpoint
  - Close FLAG-1: Add Telemetry/Privacy subsection to README documenting forget CLI
  - Close FLAG-4: Decide on .github/workflows/install-linux-e2e.yml (keep or remove)
  - Close FLAG-2 (audit-trail backfill): write 0[4567]-VERIFICATION.md retroactively
  - Close HARDEN-03 (cross-repo): smoodle-type/librime lipo-join job
  - Pre-register v0.0.7 decision criteria BEFORE any v0.0.7 E2E lane turns green (reinstate MP-2)
```

## Performance Metrics

**Estimated wall-time:** ~8-12 working days + 7 calendar days soak (Phase 7 GATE-02)
**Phase 0 closed:** 2026-05-06
**Phase 1 kickoff:** 2026-05-05
**Phase 1 finish target:** ≤2 weeks of remaining work + 7-day soak

| Phase | Estimated effort (working days) | Parallelizable with |
|-------|---------------------------------|---------------------|
| 1. Lint & CI Fast Path | ~1 | (none — foundational) |
| 2. macOS E2E | ~2-3 | Phase 3, Phase 4 |
| 3. Windows E2E | ~2-3 | Phase 2, Phase 4 |
| 4. Telemetry | ~2-3 | Phase 2, Phase 3 |
| 5. Sparkle & Release Hardening | ~1-2 | (none — sequential) |
| 6. README & Docs Hardening | ~1 | (none — sequential) |
| 7. Decision Gate Close | ~0.5 work + 7d soak | (none — sequential) |

## Accumulated Context

### Decisions Locked (do NOT relitigate)

| Decision | Rationale | Source |
|----------|-----------|--------|
| **D1**: Linux IM detection via `pgrep` | Hybrid setups defeat `command -v` | PROJECT.md ✓ shipped |
| **D2**: Telemetry self-hosted umami, opt-in default OFF, install_id_hash only | No PII risk; quantitative signal without third-party tracking | PROJECT.md (Phase 4 implements) |
| **D3**: Auto-deploy: hybrid CLI + 10s timeout + manual fallback | Auto-deploy hangs if host isn't running | PROJECT.md ✓ shipped |
| **D4**: LLM plugin → Phase 1.5 | Dict's 100% TNC freq≥50 coverage is enough surface | PROJECT.md ✓ shipped |
| **D5**: Test scope = boil-the-lake (full unit + E2E per OS, schema lint in CI) | Solo project; cheap to test, expensive to debug post-ship | PROJECT.md (Phases 1-3 implement) |
| **OQ3+OQ4**: Path A schema + smoodle-type/librime fork | Best-practice Rime architecture; future-proof for LLM plugin | PROJECT.md ✓ shipped |
| **Phase 0 wedge narrowing 2026-05-06** | Phase 0 didn't surface non-founder Thai learner; founder + diaspora friends valid smaller wedge | PROJECT.md ✓ shipped |
| **Linux: option 3** (accept unpatched system librime, document limitation) | Forked-rime distro packages = high effort, tiny audience | PROJECT.md ✓ shipped |
| **Vendor `rime.dll` directly in repo (BSD-3)** | gh CLI bootstrap path hangs in non-interactive SSH | PROJECT.md ✓ shipped |
| **Three-repo split with smoodle-type org** | Schema/installer/app/engine concerns separate | PROJECT.md ✓ shipped |
| **Two-tier CI** (ubuntu fast path + per-OS E2E gated by paths-filter) | NOT single 3-OS matrix — mac+win runners 10× slower | research ARCHITECTURE.md (Phase 1-3) |
| **Manual `verify-librime.sh`, NOT LaunchAgent** | Phase 1 dogfood = 5 users; daemon-with-sudo wrong shape | research PITFALLS CP-1 (Phase 5) |
| **Sidecar `.sha256` from GH Releases, NOT hardcoded hash in install script** | Tag rewrites silently break hardcoded hash | research PITFALLS CP-2 (Phase 5) |
| **Lint scope = structure-only, NOT regex semantics** | Python `re` ≠ boost::regex; engine fixture is the regex oracle | research PITFALLS CP-5 (Phase 1) |

### Critical Pitfalls Tracked

| Pitfall | Phase | Status |
|---------|-------|--------|
| **CP-1**: Sparkle re-swap loop (silent dylib overwrite) | Phase 5 (HARDEN-01/02/06) | Mitigated — verify-librime.{sh,ps1} detect drift, exit 1, no daemon |
| **CP-2**: Tag rewrite supply-chain inversion | Phases 2+3+5 (E2EMAC-03, E2EWIN-03, HARDEN-04/05) | Mitigated — tag-immutability guard in release.yml fails red on rewrite |
| **CP-3**: Telemetry de-anonymization at small N | Phase 4 (TELEM-05/07/08, MP-2) | Mitigated — ephemeral install_id, strict allowlist payload, [y/N] default-N, server-side IP-drop + timestamp rounding via Postgres triggers, 90-day retention cron, forget CLI for data purge |
| **CP-4**: GHA non-interactive runner false-confidence E2E | Phases 2+3 (E2EMAC-05, E2EWIN-04) | Mitigated — live runs green on macos-15 + windows-latest |
| **CP-5**: Schema lint false-positive churn (Python re ≠ boost::regex) | Phase 1 (LINT-01 scope) | Mitigated — structure-only lint scope |
| **MP-1**: README tested only on author's machine | Phase 6 (DOCS-06) | Mitigated — docs/RELEASE-CHECKLIST.md documents fresh-clone + 3-OS validation procedure |
| **MP-2**: Decision Gate survivorship bias + founder confounding | Phase 7 (GATE-01 pre-registration) | Mitigated — docs/DECISION-GATE-CRITERIA.md committed BEFORE soak observation |
| **MP-3**: Universal dylib silent failure on Intel Mac | Phase 5 (HARDEN-03) | Pending — cross-repo PR in smoodle-type/librime required |
| **MP-4**: PowerShell 5.1 cp1252 parser breakage | Phase 1 (LINT-04) | Mitigated — test_powershell_ascii.py blocks any non-ASCII byte in .ps1 files at PR-time (commit 4b8ad4d) |
| **MP-5**: GHA multi-asset release upload partial state | Phase 5 (HARDEN-04 atomic draft-then-publish) | Mitigated — draft-then-publish pattern prevents partial releases |

### Cross-Repo Dependencies

- **HARDEN-03** (Phase 5): universal macOS dylib via `lipo -create` join step in `smoodle-type/librime`'s `smoodle-build.yml`. Upstream PR in librime fork repo, not this one.
- **Phase 2 + Phase 3 SHA256 verify** (E2EMAC-03 + E2EWIN-03): require `smoodle-type/librime` `release.yml` to emit `.sha256` sidecar files alongside dylib/dll assets. Stub sidecar for existing arm64 dylib unblocks E2E immediately; full universal sidecar lands in Phase 5.

### Infra-Side Blocking Preconditions

- **TELEM-01** (Phase 4): umami v3.1.0 + PostgreSQL deployed on existing th-dc infra via `infra/telemetry/docker-compose.yml`; Caddy/Traefik fronts TLS for `telemetry.<chosen-subdomain>`. **If this slips, Phase 4 moves to Phase 1.5** (per research SUMMARY.md "Open question for roadmapper" recommendation).

### Open Todos (carry into plan-phase)

- [ ] Resolve cross-repo PR sequencing for HARDEN-03 (Phase 5 cross-repo note — smoodle-type/librine lipo-join job still needed).
- [ ] Confirm telemetry subdomain at Phase 4 plan-phase (was tentatively `telemetry.0dl.me` per research; founder picks).
- [ ] GATE-01 pre-registration must be authored *before* Phase 2/3 turn green (verifiable from git log timestamps; enforce via plan ordering at Phase 7 plan-phase).
- [ ] Phase 4 plan-phase: research-flag `/gsd-research-phase 4` recommended for `smoodle telemetry forget` server endpoint design (umami doesn't ship per-install delete OOTB).

### Blockers

None at roadmap-creation time. All blockers are surfaced at plan-phase per `Risks & Cross-Repo Dependencies` table in ROADMAP.md.

## Session Continuity

**On session resume:**
1. Re-read this file (STATE.md) for current position.
2. Re-read [ROADMAP.md](./ROADMAP.md) for phase context.
3. If a plan was in-flight, re-read its PLAN-N.md.
4. Next action is `/gsd-plan-phase <next-phase>` per Current Position.

**Active milestone:** v0.0.7-cross-platform (opened 2026-05-25, light scaffold — formal `/gsd-new-milestone` deferred). v0.0.6 stays closed at macOS-only scope per 2026-05-16 audit.
**Active phase:** W2 telemetry — partially closed (live deploy + clients wired). W1, W3, W4, W5 pending.
**Active plans:** none formally scoped; W2 work tracked via DECISION-GATE-CRITERIA-v0.0.7.md (pre-registered `067d1c5` 2026-05-25 12:14 +0700).

**v0.0.7 W2 telemetry progress (live as of 2026-05-25 12:31 +0700):**
- ✅ umami v3.1.0 + postgres 15 deployed on `dxc.0dl.me` (`/opt/umami/`)
- ✅ Public TLS via Cloudflare tunnel: `telemetry.0dl.me` → 10.0.10.180:3001 ; `forget.0dl.me` → 10.0.10.180:8080
- ✅ Privacy triggers active on `website_event` (null_hostname + round_event_timestamp); session ts also rounded; session.hostname trigger dropped (umami v3 schema doesn't carry the column)
- ✅ forget-api container `umami-forget-api` live; SQL rewritten to JOIN event_data on `data_key='install_id_hash'` (previous `event_name LIKE` filter was broken-by-design)
- ✅ FLAG-5 closed: `scripts/lib/telemetry.{sh,ps1}` site_id default = `88042064-eeea-465a-8658-002d978d4f9b`
- ✅ FLAG-6 closed: `scripts/lib/telemetry-forget.{sh,ps1}` URL default = `https://forget.0dl.me/api/forget`
- ✅ FLAG-1 closed: README has new `## Telemetry & Privacy` section documenting opt-in + opt-out + forget CLI
- ✅ End-to-end smoke verified: opt-in install → 2 events land with hostname=NULL + ts hour-aligned → forget CLI reports "Deleted 2" → DB confirms 0
- ✅ Bearer-token auth on forget-api (FORGET_BEARER_TOKEN env, 5/5 cases verified: 401/403/200/400/200-public) — recruit-ready
- ✅ Gate evidence scaffolding committed: `.planning/phases/04-telemetry/VERIFICATION.md` (W2-C1..C5 PASS, C6 pending recruit), `.planning/SOAK-LEDGER-v0.0.7.md` (R1..R5 empty rows), `.planning/phases/07-decision-gate-close/FOUNDER-HASH.txt` (founder never opted in → sentinel), `docs/RECRUIT-OUTREACH-DRAFTS.md` (3 tone templates)
- ⏳ Pending in W2: 90-day retention cron on dxc; per-recruit bearer tokens when N > 3; session_data cleanup design decision
- ⏳ Pending: founder pings recruits → ledger fills → first non-founder install_started lands

**Commits this session (v0.0.7 W2 + pre-reg):**
- `067d1c5` docs(gate): pre-register v0.0.7-cross-platform decision criteria (MP-2 timing anchor)
- (next 3 commits land below this state update)

**Phase 5 commits (10 total, all on main):**
- `c8a487e` feat(05-01): add scripts/verify-librime.sh -- manual hash-drift checker (HARDEN-01)
- `39819ad` feat(05-01): add scripts/verify-librime.ps1 -- manual hash-drift checker (HARDEN-02)
- `8a97155` test(05-01): add tests/test_verify_librime_mac.py (HARDEN-01 test)
- `86cb398` test(05-01): add tests/test_verify_librime_win.py (HARDEN-02 test)
- `b5f6919` fix(05-01): update install-librime-fork.sh trailing message to reference verify-librime.sh (HARDEN-06)
- `e71a2ad` fix(05-01): update install-librime-fork.ps1 trailing message to reference verify-librime.ps1 (HARDEN-06)
- `483f602` fix(05-01): add touch -m for schema files after cp loop in install.sh (HARDEN-07)
- `ceb3d0e` docs(05-01): add 05-01-SUMMARY.md for Phase 5 Plan 01 completion
- `1f34b7b` feat(05-02): add .github/workflows/release.yml — draft-then-publish + tag-immutability guard (HARDEN-04, HARDEN-05)
- `f5b1b42` docs(05): add Phase 5 research and plan artifacts

**Live verification:**
- Test tag v0.0.6-test-release → release workflow run 25649115808 **GREEN** — all steps passed (checkout → build DMG → SHA256 → create draft → upload → publish → verify immutability). Tag and release cleaned up.

---
*State initialized: 2026-05-08 alongside ROADMAP.md creation.*
*Updated: 2026-05-09 after Phase 2 verifier PASS (5/5 SC, 5/5 REQ, 100% goal achievement).*
*Updated: 2026-05-10 after Phase 3 verifier PASS (5/5 SC, 5/5 REQ, 8/8 STRIDE, zero gaps; live windows-latest run 25623956809 GREEN 2m12s).*
*Updated: 2026-05-11 after Phase 5 verifier PASS (7/7 HARDEN REQ-IDs covered; release workflow live-verified green on test tag v0.0.6-test-release).*
*Updated: 2026-05-16 after audit re-scope: v0.0.6 narrowed to macOS-only; Windows + telemetry deferred to v0.0.7-cross-platform; BLOCK-1 + BLOCK-3 closed.*
*Updated: 2026-05-25 v0.0.7-cross-platform opened: MP-2 pre-registration anchored at `067d1c5`; W2 telemetry stack live on dxc.0dl.me (umami + forget-api via Cloudflare tunnel); FLAG-1/5/6 closed; W1/W3/W4/W5 still queued.*
*Updated: 2026-05-25 13:30 +0700 — bearer auth on forget-api (5/5 cases verified); gate evidence scaffolding committed (Phase 4 VERIFICATION.md skeleton, SOAK-LEDGER-v0.0.7.md, FOUNDER-HASH.txt sentinel, recruit outreach drafts). W2 is recruit-ready.*
