# Project State: Smoodle Phase 1 Finish

**Last updated:** 2026-05-11
**Status:** PHASE-1-CLOSED (all 7 phases complete; 41/41 REQ-IDs covered; verdict: stay-in-dogfood — recruit 2-5 friends for formal 7-day soak)
**Mode:** yolo

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

**Phase:** 7 → COMPLETE (Lane G Decision Gate closed 2026-05-11; verdict: stay-in-dogfood)
**Plans:** docs/DECISION-GATE-CRITERIA.md pre-registered (GATE-01), .planning/DECISION-GATE.md checklist filled (GATE-03/GATE-04). Verdict: stay-in-dogfood — all code complete but zero non-founder installs attempted.
**Phase 1:** CLOSED — 4/4 SC met, verifier PASS. All 41 REQ-IDs across 7 phases covered.
**Phase 2:** COMPLETE — 5/5 SC met, verifier PASS, live macos-15 run 25594460125 GREEN in 1m 4s.
**Phase 3:** COMPLETE — 5/5 SC met, verifier PASS, live windows-latest run 25623956809 GREEN in 2m 12s after 2 internal-defect fixes.
**Phase 4:** COMPLETE — 9/9 TELEM REQ-IDs covered. Docker Compose stack ready for th-dc deploy.
**Phase 5:** COMPLETE — 6/6 SC met, all 7 HARDEN REQ-IDs covered. Human verification on test tag v0.0.6-test-release passed green.
**Phase 6:** COMPLETE — 7/7 DOCS REQ-IDs covered. README status APPROVED, LoneExile→smoodle-type migration complete, hardcoded paths cleaned, uninstall flags added, RELEASE-CHECKLIST.md created.
**Phase 7:** COMPLETE — 4/4 GATE REQ-IDs covered. Verdict: stay-in-dogfood. Next: recruit 2-5 diaspora-Thai friends, start formal 7-day soak, re-evaluate.
**Next action:** Recruit non-founders. When ready: `./gsd-audit-milestone` to validate Phase 1 closure. Then either `/gsd-new-milestone phase-1.5` or `/gsd-capture` to dogfood-soak-notes.

```
Roadmap progress: [■■■■■■■] 7 complete — PHASE 1 CLOSED
                       ^
                       Phase 4 COMPLETE (all 9 TELEM REQ-IDs covered)
                       Phase 5 COMPLETE (all 7 HARDEN REQ-IDs covered)
                       Phase 6 COMPLETE (all 7 DOCS REQ-IDs covered)
                       Phase 7 COMPLETE (all 4 GATE REQ-IDs covered)
                       Verdict: stay-in-dogfood

Coverage: 41/41 requirements mapped ✓
Phase 1 LINT REQ-IDs (4/4): LINT-01..04 — verifier PASS ✓
Phase 2 E2EMAC REQ-IDs (5/5): 01,02,05 (Plan 02-01) + 03,04 (Plan 02-02) — verifier PASS ✓
Phase 3 E2EWIN REQ-IDs (5/5): 01,02,04,05 (Plan 03-01) + 03,05 (Plan 03-02) — verifier PASS ✓
Phase 4 TELEM REQ-IDs (9/9): 01,07,08 (Wave 1 infra) + 02,03,04,05 (Wave 2 client) + 06,09 (Wave 3 tests) ✓
Phase 5 HARDEN REQ-IDs (7/7): 01,02,06,07 (Plan 05-01) + 04,05 (Plan 05-02) + 03 (cross-repo note) ✓
Phase 6 DOCS REQ-IDs (7/7): 01,05,07 (Wave 1 migration) + 02,03,04,06 (Wave 2 rewrite) ✓
Phase 7 GATE REQ-IDs (4/4): 01 (pre-registration) + 03 (checklist) + 04 (verdict: stay-in-dogfood) ✓
  Note: GATE-02 (7-day soak) cannot complete until non-founders attempt install.
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

**Active milestone:** phase-1-finish
**Active phase:** 5 (Lane S: Sparkle/release hardening) — COMPLETE; next is Phase 4 (parallelizable, infra-blocked) or Phase 6 (sequential, docs hardening)
**Active plans:** none in flight

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
