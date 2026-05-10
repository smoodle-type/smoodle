# Project State: Smoodle Phase 1 Finish

**Last updated:** 2026-05-10
**Status:** PHASE-3-COMPLETE (Lane E2 Windows E2E shipped; verifier PASS 5/5 SC; live run 25623956809 GREEN 2m12s; ready for `/gsd-plan-phase 4` or `/gsd-plan-phase 5`)
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

**Phase:** 3 → COMPLETE (Lane E2 Windows E2E shipped 2026-05-10, verifier PASS 5/5 SC + 5/5 REQ + 8/8 STRIDE, zero gaps)
**Plans:** 2 of 2 shipped. 03-01 (Wave 1, autonomous, 906 lines) shipped install-win-e2e.yml + Pester 5 driver + clean-slate + Authenticode NotSigned regression guard; 03-02 (Wave 2, human-verify, 1219 lines) shipped SHA256 verify in install-librime-fork.ps1 + vendored vendor/windows/rime.dll.sha256 sidecar + Python unittest.
**Phase 1:** COMPLETE — 4/4 SC met, verifier PASS.
**Phase 2:** COMPLETE — 5/5 SC met, verifier PASS, live macos-15 run 25594460125 GREEN in 1m 4s.
**Phase 3:** COMPLETE — 5/5 SC met, verifier PASS, live windows-latest run 25623956809 GREEN in 2m 12s after 2 internal-defect fixes (ba11f59 Pester 5 scoping + clean-slate ordering, 41daefb Write-Error diagnostics ordering).
**Next action:** `/gsd-plan-phase 4` (Telemetry, parallelizable, infra-blocked on th-dc umami deploy) OR `/gsd-plan-phase 5` (Sparkle/release hardening, sequential, now unblocked since both Phases 2 + 3 are green).

```
Roadmap progress: [■■■□□□□] 3 complete
                       ^
                       Phase 3 COMPLETE (verdict: PASS, zero gaps)
                       Phase 4 unblocked; parallelizable
                       Phase 5 unblocked (depended on Phases 2+3 both green)

Coverage: 41/41 requirements mapped ✓
Phase 1 LINT REQ-IDs (4/4): LINT-01..04 — verifier PASS ✓
Phase 2 E2EMAC REQ-IDs (5/5): 01,02,05 (Plan 02-01) + 03,04 (Plan 02-02) — verifier PASS ✓
Phase 3 E2EWIN REQ-IDs (5/5): 01,02,04,05 (Plan 03-01) + 03,05 (Plan 03-02) — verifier PASS ✓
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
| **MP-4**: PowerShell 5.1 cp1252 parser breakage | Phase 1 (LINT-04) | Mitigated — test_powershell_ascii.py blocks any non-ASCII byte in .ps1 files at PR-time (commit 4b8ad4d) |
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
**Active phase:** 3 (Lane E2: Windows E2E) — COMPLETE; next is Phase 4 (parallelizable, infra-blocked) or Phase 5 (sequential, now unblocked)
**Active plans:** none in flight

**Phase 3 commits (11 total, all on main):**
- `ec41146` docs(03): plan Phase 3 — 2 plans, plan-checker PASS post-revision
- `bec3caf` chore(03-01): extend MP-4 ASCII glob to tests/*.ps1
- `64b04e6` feat(03-01): tests/test_install_e2e_win.ps1 (Pester 5 driver, 4 Describes)
- `04cc350` feat(03-01): .github/workflows/install-win-e2e.yml (windows-latest workflow)
- `7b2ef02` docs(03-01): plan close + 03-01-SUMMARY.md
- `3b2083d` feat(03-02): vendor/windows/rime.dll.sha256 sidecar (3700c2f9...4275e)
- `b02ece0` feat(03-02): SHA256 verify + Authenticode diagnostic in install-librime-fork.ps1
- `55b33c8` test(03-02): tests/test_install_librime_fork_win.py
- `579601d` feat(03-02): wire install-librime-fork.ps1 + tests into install-win-e2e.yml
- `ba11f59` fix(03-01): Pester 5 scoping + workflow clean-slate ordering (live run 25623770858 red)
- `41daefb` fix(03-02): emit SHA mismatch diagnostics before Write-Error (live run 25623904961 red)

**Live smoke-tests:**
- run 25623770858 RED — Pester 5 file-scope code ran during Discovery phase (before Describe 1's emptiness assertion). Fixed `ba11f59`.
- run 25623904961 RED — `$ErrorActionPreference = 'Stop'` made Write-Error terminating before Write-Host hash diagnostics could print. Fixed `41daefb`.
- run 25623956809 **GREEN** in 2m12s — 12/12 steps passing on windows-latest. Both fixes were INTERNAL Pester 5 + PowerShell defects (distinct from Phase 2's `d4ba9db` external Homebrew regression).

**Phase 2 commits (8 total, all on main):**
- `67d7b1b` feat(02-01): tests/test_install_e2e_mac.sh
- `d01912a` feat(02-01): .github/workflows/install-mac-e2e.yml
- `a2709da` docs(02-01): plan close
- `466b43c` feat(02-02): vendor/macos/librime.1.dylib.sha256 + .gitignore allowlist
- `550d026` feat(02-02): SHA256 verify + Intel arch refusal in install-librime-fork.sh
- `9676d49` test(02-02): tests/test_install_librime_fork_mac.py
- `668e6dc` feat(02-02): wire script + tests into workflow
- `d4ba9db` fix(02-01): drop deprecated --no-quarantine brew flag (external regression)

---
*State initialized: 2026-05-08 alongside ROADMAP.md creation.*
*Updated: 2026-05-09 after Phase 2 verifier PASS (5/5 SC, 5/5 REQ, 100% goal achievement).*
*Updated: 2026-05-10 after Phase 3 verifier PASS (5/5 SC, 5/5 REQ, 8/8 STRIDE, zero gaps; live windows-latest run 25623956809 GREEN 2m12s).*
