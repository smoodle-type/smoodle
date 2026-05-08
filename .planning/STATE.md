# Project State: Smoodle Phase 1 Finish

**Last updated:** 2026-05-08
**Status:** READY-TO-EXECUTE (Phase 1 planned)
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

**Phase:** 1 (Lane F: Lint & CI Fast Path)
**Plans:** 2 plans in 2 waves (01-01 schema-lint+yamllint Wave 1, 01-02 ci.yml+ps1-ASCII Wave 2)
**Status:** READY-TO-EXECUTE
**Next action:** `/gsd-execute-phase 1` — Wave 1 runs autonomous; Wave 2 has a `checkpoint:human-verify` task that requires manually pushing 3 smoke-test PRs (README-only green, schema-break red, ps1-non-ASCII red).

```
Roadmap progress: [▣□□□□□□] 0/7 phases complete (Phase 1 planned, not yet executed)
                   ^
                   currently at Phase 1 entry — plans landed 2026-05-08

Coverage: 41/41 requirements mapped ✓
Phase 1 plan coverage: 4/4 LINT REQ-IDs (LINT-01,02 in 01-01; LINT-03,04 in 01-02) ✓
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
| **CP-1**: Sparkle re-swap loop (silent dylib overwrite) | Phase 5 (HARDEN-01/02/06) | Pending |
| **CP-2**: Tag rewrite supply-chain inversion | Phases 2+3+5 (E2EMAC-03, E2EWIN-03, HARDEN-04/05) | Pending |
| **CP-3**: Telemetry de-anonymization at small N | Phase 4 (TELEM-05/07/08, MP-2) | Pending |
| **CP-4**: GHA non-interactive runner false-confidence E2E | Phases 2+3 (E2EMAC-05, E2EWIN-04) | Pending |
| **CP-5**: Schema lint false-positive churn (Python re ≠ boost::regex) | Phase 1 (LINT-01 scope) | Pending |
| **MP-1**: README tested only on author's machine | Phase 6 (DOCS-06) | Pending |
| **MP-2**: Decision Gate survivorship bias + founder confounding | Phase 7 (GATE-01 pre-registration) | Pending |
| **MP-3**: Universal dylib silent failure on Intel Mac | Phase 5 (HARDEN-03) | Pending |
| **MP-4**: PowerShell 5.1 cp1252 parser breakage | Phase 1 (LINT-04) | Pending |
| **MP-5**: GHA multi-asset release upload partial state | Phase 5 (HARDEN-04 atomic draft-then-publish) | Pending |

### Cross-Repo Dependencies

- **HARDEN-03** (Phase 5): universal macOS dylib via `lipo -create` join step in `smoodle-type/librime`'s `smoodle-build.yml`. Upstream PR in librime fork repo, not this one.
- **Phase 2 + Phase 3 SHA256 verify** (E2EMAC-03 + E2EWIN-03): require `smoodle-type/librime` `release.yml` to emit `.sha256` sidecar files alongside dylib/dll assets. Stub sidecar for existing arm64 dylib unblocks E2E immediately; full universal sidecar lands in Phase 5.

### Infra-Side Blocking Preconditions

- **TELEM-01** (Phase 4): umami v3.1.0 + PostgreSQL deployed on existing th-dc infra via `infra/telemetry/docker-compose.yml`; Caddy/Traefik fronts TLS for `telemetry.<chosen-subdomain>`. **If this slips, Phase 4 moves to Phase 1.5** (per research SUMMARY.md "Open question for roadmapper" recommendation).

### Open Todos (carry into plan-phase)

- [ ] Resolve cross-repo PR sequencing for HARDEN-03 (Phase 5 plan-phase's first sub-task).
- [ ] Confirm telemetry subdomain at Phase 4 plan-phase (was tentatively `telemetry.0dl.me` per research; founder picks).
- [ ] GATE-01 pre-registration must be authored *before* Phase 2/3 turn green (verifiable from git log timestamps; enforce via plan ordering at Phase 7 plan-phase).
- [ ] Phase 4 plan-phase: research-flag `/gsd-research-phase 4` recommended for `smoodle telemetry forget` server endpoint design (umami doesn't ship per-install delete OOTB).
- [ ] Phase 5 plan-phase: research-flag `/gsd-research-phase 5` recommended for `release.yml` atomic draft-then-publish multi-asset sequencing (PITFALLS MP-5 has subtleties).

### Blockers

None at roadmap-creation time. All blockers are surfaced at plan-phase per `Risks & Cross-Repo Dependencies` table in ROADMAP.md.

## Session Continuity

**On session resume:**
1. Re-read this file (STATE.md) for current position.
2. Re-read [ROADMAP.md](./ROADMAP.md) for phase context.
3. If a plan was in-flight, re-read its PLAN-N.md.
4. Next action is `/gsd-plan-phase <next-phase>` per Current Position.

**Active milestone:** phase-1-finish
**Active phase:** none yet — start with `/gsd-plan-phase 1`
**Active plan:** none yet
**Files in flight:** none

---
*State initialized: 2026-05-08 alongside ROADMAP.md creation.*
