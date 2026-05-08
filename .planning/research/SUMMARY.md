# Project Research Summary

**Project:** smoodle (Phase 1 finish)
**Domain:** Cross-platform desktop IME (Rime/librime) — solo dev, dogfood-circle distribution, dylib-swap installers
**Researched:** 2026-05-08
**Confidence:** HIGH (subsequent-milestone synthesis; Phase 0/1 already shipped, evidence base is running codebase + 4 deep research docs)

## Executive Summary

Smoodle is past greenfield. v0.0.6 schema (14893 Thai words / 28239 entries, 100% TNC freq≥50 coverage) ships across 3 OS installers, the smoodle-type/librime fork is green on an 8-job CI matrix, and Smoodle.app v0.1.0 is live. Phase 0 closed 2026-05-06 with the wedge narrowed to **founder + diaspora-Thai friends as they surface** and Decision Gate signals re-tuned to **qualitative** (≥1 unsolicited bug report, ≥1 named non-founder converts to daily use). Phase 1 finish is the wrap lane: Lane E E2E for mac+win, schema lint, opt-in telemetry, README hardening, doc URL migration, dylib SHA256 verification, universal macOS dylib, Sparkle re-swap detection, Decision Gate close.

All four research docs converge: **the technical decisions are settled; the work is sequencing and discipline**, not exploration. Stack is umami self-host on existing th-dc infra (NOT Cloudflare Worker, NOT custom endpoint), yamllint + stdlib-Python custom validator (NOT JSON Schema, NOT regex-body checking), Pester 5 + bash for two-tier GHA CI (NOT single 3-OS matrix), `lipo` + post-download-pre-swap SHA256 with sidecar `.sha256` (NOT hardcoded hashes, NOT pre-download), and a manual `verify-librime` script (NOT a LaunchAgent — that's Phase 1.5 deferral).

The dominant risks are governance failures, not technical surprises: **tag-rewrite supply-chain inversion** (CP-2 — pin SHA + immutable-tag rule before any non-founder install), **telemetry de-anonymization at small N** (CP-3 — ephemeral install_id, allowlist payload, default-N opt-in, purge endpoint, 90d retention), **GHA non-interactive runner false-confidence E2E** (CP-4 — gate GUI-required steps), **Sparkle re-swap silently reverting the patched dylib** (CP-1 — manual hash-drift probe only, no auto-re-swap daemon), and **Decision Gate survivorship bias** (MP-2 — pre-register criteria before observing outcomes). All four docs converge on **~8-12 working days of solo wall-time + 7-day soak**, fitting the ≤2-week budget.

## Key Findings

### Recommended Stack

Stack is fully settled and grounded in the existing repo. No new languages, no new runtime deps on the user's machine. All additions are CI-side or self-hosted on existing infra.

**Core technologies:**
- **umami 3.1.0 self-hosted** (PostgreSQL + Node, ~200 MB RAM) — telemetry backend on existing th-dc infra; opt-in `/api/send` events; cookieless. Rejected alternatives: OpenPanel (3-4× footprint), PostHog (16 GB RAM min), Plausible Cloud (third-party flow), custom Worker (perpetual maintenance).
- **yamllint 1.38 + stdlib Python custom validator** — lint scope is YAML structure + key allowlist + `import_preset` resolution + algebra rule shape. **NOT** JSON Schema (Rime algebra is regex-in-strings). **NOT** Python `re.compile` on regex bodies (boost::regex divergence — see CP-5).
- **Pester 5 (Win E2E) + bash harness (mac E2E)** on `windows-latest` + `macos-15` GHA runners. Pre-installed; zero net-new tooling.
- **`lipo` + sidecar `.sha256`** for universal dylib + post-download-pre-swap verification. GitHub Releases native asset digests (June 2025) as primary; sidecar as fallback.
- **`launchd` `WatchPaths` deferred** — Phase 1 ships **manual `scripts/verify-librime.sh`** (Anti-Pattern 4 in ARCHITECTURE; CP-1 in PITFALLS — daemon-with-sudo wrong shape for 5-user dogfood).
- **Two-tier CI** — `ci.yml` ubuntu-only fast path (~3 min on every PR) + `install-{mac,win,linux}-e2e.yml` slow per-OS workflows on paths-filter + workflow_dispatch + weekly cron. **NOT** single 3-OS matrix on every PR.

Full detail: STACK.md.

### Expected Features

Phase 1 finish is dogfood UX hardening, not new IME features. Smoodle's differentiation is *better onboarding/troubleshooting/uninstall docs* than peer Rime schemas, plus opt-in telemetry done right.

**Must have (table stakes):**
- Lane E E2E for mac + Windows (TS11) — regression protection.
- Schema lint test (TS10 / D5) — prevents silent deploy no-ops.
- README troubleshooting + Win/Linux install snippets + uninstall + status flip APPROVED (TS5–TS9).
- macOS Releases asset verification + SHA256 in `install-librime-fork.sh` (TS12).
- Universal macOS dylib + Intel-Mac arch-mismatch refusal (TS3 + MP-3).
- Sparkle re-swap manual hash-drift detection (TS4).
- Opt-in self-hosted telemetry client (D2 / D3) — quantitative sanity-check, NOT Decision Gate input.
- Post-install "type sawadee" probe formalization (TS2).
- Decision Gate close memo with pre-registered criteria (MP-2).

**Should have (Phase 1.5, gate on Decision Gate signal):**
- `smoodle doctor` self-diagnose CLI (D1).
- GH issue template prefilled via URL parameters (D2).
- README onboarding sentence + 5-second screen-recording GIF (D4).
- Pre-compiled dict `.bin` artifacts (D5).
- `install.sh --check` mode (D7 — overlaps TS4).

**Defer (Phase 2+, anti-features for Phase 1):**
- Custom dictionary editor GUI (AF1).
- Cloud sync / cross-device dict sync (AF2/AF14).
- Account systems / login (AF3).
- Auto-update infra (Sparkle for smoodle, Squirrel.Windows) (AF5).
- iOS / Android (AF6).
- Code-signing / notarization / MAS / winget submission (AF7/AF10).
- LLM tone-disambiguation plugin (AF13) — Phase 1.5 explicitly per D4.
- GUI installer / Tauri-Electron (AF11).
- Forked-rime distro packages on Linux (AF12).

Full detail: FEATURES.md.

### Architecture Approach

Existing architecture is sound; Phase 1 finish only adds 5 component classes on top. No re-architecture.

**Major components added:**
1. **CI/CD layer (Lane E close)** — `ci.yml` (per-PR fast path), `install-{mac,win}-e2e.yml`, `release.yml` (tag-triggered DMG + checksum), existing `install-linux-e2e.yml`.
2. **Installer hardening layer** — `install-librime-fork.{sh,ps1}` gain download → SHA256 verify → backup → swap pipeline; `scripts/verify-librime.{sh,ps1}` is new manual one-shot.
3. **Telemetry layer** — `scripts/lib/telemetry.{sh,ps1}` (async fire-and-forget POST, 3s timeout, no retry) + umami container on th-dc + Caddy/Traefik TLS + built-in umami dashboard.
4. **Decision Gate artifact** — `.planning/DECISION-GATE.md` flat markdown checklist with pre-registered criteria. No dashboard.
5. **Schema lint** — `tests/test_schema_lint.py` (stdlib Python + PyYAML + yamllint subprocess) + `.yamllint` config.

Key patterns: two-tier CI (NOT single matrix); async-fire-and-forget telemetry (NOT blocking POST); post-download-pre-swap SHA256 with sidecar (NOT hardcoded hash); Decision Gate as static markdown (NOT dashboard).

Full detail: ARCHITECTURE.md.

### Critical Pitfalls

The five must-fix pitfalls from PITFALLS.md, lane-mapped:

1. **CP-2: Tag rewrite supply-chain inversion (Lane-S)** — `gh release upload --clobber` silently changes asset SHA. Prevention: pin expected SHA256 in install scripts + sidecar `.sha256` + immutable-tag CI guard rejecting `updated_at != created_at`. **Must land before any non-founder install.**
2. **CP-3: Telemetry de-anonymization at small N (Lane-T)** — install_id collision/persistence + accidental hostname/username leakage + default-Y opt-in dark pattern + small-N de-anon via timestamps + GDPR/PIPEDA exposure. Prevention: ephemeral random install_id (`sha256(/dev/urandom 16)`), strict allowlist payload schema, `[y/N]` default-N prompt, server-side IP drop + timestamp rounding, `smoodle telemetry forget` purge endpoint, 90-day retention. **Slips with telemetry if telemetry slips.**
3. **CP-4: GHA non-interactive runner false-confidence E2E (Lane-E)** — macOS runner has no GUI session so `osascript` permission dialogs never fire and `pgrep Squirrel` returns negative for the wrong reason; Windows runner caches `%APPDATA%\Rime\` across jobs. Prevention: explicit GUI-required step gating, `xattr -dr com.apple.quarantine` and `Unblock-File` neutralization, runner-clean-slate per Windows job, assert daemon running BEFORE installer runs. **Must land before declaring Lane-E done.**
4. **CP-1: Sparkle re-swap loop (Lane-S)** — Squirrel auto-update silently overwrites the patched dylib. Prevention: manual hash-drift probe in `verify-librime.sh` + post-install warning text + telemetry `librime_sha_match` boolean for cohort drift detection. **Do NOT ship LaunchAgent in Phase 1** — race window with Sparkle, sudo prompt loops, TCC/Background Items friction.
5. **CP-5: Schema lint false-positive churn from Python `re` ≠ boost::regex (Lane-D)** — Python re does not support boost's `\<`/`\>`, POSIX classes, `\Q...\E`, variable-width lookbehind. Prevention: lint scope = **structure-only**. Engine-mode test (`tests/v01_fixture.yaml` via `rime_api_console`) is the regex oracle, NOT the linter.

Cross-cutting must-fix: MP-3 (Intel-Mac arch refusal — `lipo -archs`), MP-4 (PowerShell 5.1 cp1252 parser — ASCII-only .ps1 assertion), MP-5 (atomic draft-then-publish in `release.yml`), MP-1 (fresh-clone README validation per release), MP-2 (Decision Gate pre-registration to kill survivorship bias).

Full detail: PITFALLS.md.

## Implications for Roadmap

All four research docs independently converge on the same 6-lane structure. Locking it in.

### Lane F: CI fast path
**Rationale:** Schema lint cheap (~1s runtime), foundational for every later PR, unblocks nothing. Land first.
**Delivers:** `ci.yml` (ubuntu-only, schema lint + shape tests + bash/pwsh syntax) + `tests/test_schema_lint.py` + `.yamllint` config.
**Addresses:** TS10, MP-4, mp-2.
**Avoids:** CP-5 by scoping lint to structure-only.
**Effort:** ~1 day.

### Lane E1+E2: Lane E close (mac + win E2E in parallel)
**Rationale:** Both block on librime fork's `release.yml` emitting `.sha256`; once that one prereq lands, mac and win tracks are independent. Highest-value regression protection for the diaspora-Thai friend wedge.
**Delivers:** `install-mac-e2e.yml` (macos-15) + `install-win-e2e.yml` (windows-latest, Pester 5) + drivers `tests/test_install_e2e_mac.sh` + `tests/test_install_e2e_win.ps1` + SHA256 verify block in `install-librime-fork.{sh,ps1}`.
**Addresses:** TS11, TS12.
**Avoids:** CP-2 (SHA pinning), CP-4 (GUI gate + clean-slate), MP-4 (pwsh parse check), MP-5 (draft-then-publish).
**Effort:** ~3-5 days parallel.

### Lane T: Telemetry (in parallel with E1/E2)
**Rationale:** Independent of Lane-E; depends only on infra. Land late within parallelism so install scripts are stable before sourcing the telemetry helper.
**Delivers:** umami + postgres docker-compose on th-dc behind Caddy/Traefik TLS + `scripts/lib/telemetry.{sh,ps1}` async helpers + opt-in prompt block in 3 installers + unskip `test_telemetry_opt_in_default_off` + `smoodle telemetry forget` purge command.
**Addresses:** D2 / D3, TS2 hook.
**Avoids:** CP-3 in full.
**Effort:** ~2-3 days.
**Open question for roadmapper:** if endpoint deploy on th-dc slips, does telemetry slip to Phase 1.5? **Recommended answer: yes** — CP-3 prevention is non-trivial; Decision Gate signals are qualitative anyway, telemetry is sanity-check only.

### Lane S: Sparkle re-swap + release hardening
**Rationale:** Depends on E1+E2 (verify block in same files). Slot in after they land. Pulls together supply-chain + Sparkle + arch-detection threads.
**Delivers:** `scripts/verify-librime.{sh,ps1}` (manual hash-drift checker, no daemon) + post-install warning text + README "if ranking degrades, run verify-librime.sh" stanza + `release.yml` atomic draft-then-publish + universal macOS dylib `lipo -create` step in librime fork's smoodle-build.yml + Intel-Mac arch-detection refusal + tag-immutability CI guard.
**Addresses:** TS3, TS4, MP-3, MP-5.
**Avoids:** CP-1 (no LaunchAgent), CP-2 (tag immutability + pinned SHA).
**Effort:** ~1-2 days.
**Open question for roadmapper:** does universal dylib stay in Phase 1 or move to 1.5? **Recommended answer: stay in Phase 1.** PROJECT.md Active includes it; FEATURES.md flags should-ship; PITFALLS MP-3 marks must-fix. Skipping leaves Intel-Mac silent break in dogfood, contradicting TS3.

### Lane R: README + docs hardening
**Rationale:** Independent of E/T/S except troubleshooting needs the patterns those lanes ship. Land after them.
**Delivers:** README status flip APPROVED + Win/Linux install snippets + troubleshooting top-5 + uninstall instructions + version line + LoneExile/* → smoodle-type/* migration across 6 docs + `docs/RELEASE-CHECKLIST.md` (fresh-clone validation procedure).
**Addresses:** TS5, TS6, TS7, TS8, TS9, MP-1, mp-1.
**Effort:** ~1 day.

### Lane G: Decision Gate close
**Rationale:** Last by definition. Requires 7-day soak after Lane E green. Pre-registration of criteria must happen *before* signal collection (start of Lane G slot, not end).
**Delivers:** `.planning/DECISION-GATE.md` checklist + `docs/DECISION-GATE-CRITERIA.md` (pre-registered ship-publicly-ready / stay-in-dogfood / inconclusive thresholds) + verdict memo with explicit founder/non-founder signal columns + small-N humility caveat.
**Addresses:** Phase 1 close, MP-2.
**Avoids:** Survivorship bias, founder-daily-use confounding, small-N false positives.
**Effort:** ~0.5 day execution + 7+ days soak.

### Phase Ordering Rationale

- **Lane F first:** schema lint catches drift on every later PR; foundational, cheap, unblocks nothing.
- **Lane E1+E2+T in parallel:** all three independent given the librime fork's `.sha256` prereq; largest chunk of wall-time so parallelism matters most.
- **Lane S after E1+E2:** SHA256 verify block lives in same install-librime-fork.* files E1/E2 touch; co-locating avoids merge friction; universal dylib + arch refusal + tag-immutability fold in naturally.
- **Lane R after Lane S:** README documents what S ships.
- **Lane G last with 7-day soak.**
- **Total:** ~8-12 working days excluding soak; matches PROJECT.md ≤2-week budget across all 4 docs.

### Research Flags

Phases likely needing deeper research (`/gsd-research-phase`):
- **Lane T:** CP-3 prevention is non-trivial — ephemeral install_id mechanics on Windows (no `/dev/urandom` — use `[System.Security.Cryptography.RandomNumberGenerator]`), umami `/api/send` payload allowlist enforcement at server side, `smoodle telemetry forget` server endpoint design (umami doesn't ship per-install delete OOTB). **Spike before committing to ship in Phase 1.**
- **Lane S:** universal dylib build is straightforward `lipo -create`, but `release.yml` atomic draft-then-publish with multi-asset upload + sidecar `.sha256` per asset has sequencing subtleties (MP-5). **Spike the workflow before tagging.**

Phases with standard patterns (skip research-phase):
- **Lane F:** stdlib Python + yamllint subprocess; well-trodden.
- **Lane E1/E2:** macos-15 + windows-latest GHA patterns documented; existing `install-linux-e2e.yml` is the template; Pester 5 preinstalled.
- **Lane R:** doc work, no infra.
- **Lane G:** markdown checklist + manual review; no tooling.

## Confidence Assessment

| Area | Confidence | Notes |
|------|------------|-------|
| Stack | HIGH | umami self-host + yamllint + Pester + lipo all have official docs verified within 6 months. Sparkle re-swap synthesis is MEDIUM but correctly de-scoped to manual probe. |
| Features | HIGH | Every TS/AF item grounded in PROJECT.md / CONCERNS.md / PHASE1-PROMPT.md. Differentiator confidence MEDIUM-HIGH — D1/D2 patterns extrapolated from privacy-first dev-tool norms. |
| Architecture | HIGH | Existing architecture well-mapped; Phase 1 finish only adds 5 component classes on well-trodden patterns. |
| Pitfalls | HIGH for CP-1/CP-2/CP-4/MP-1/MP-3/MP-4/MP-5. MEDIUM for CP-3 (regulatory framing correct; small-N de-anon math is opinion-shaped). MEDIUM for CP-5 (boost::regex vs Python re divergence real but smoodle's current 14 algebra rules don't trip it; forward-looking). |

**Overall confidence:** HIGH. Subsequent-milestone synthesis with running codebase as evidence base.

### Gaps to Address

- **Telemetry endpoint deploy on th-dc:** umami + postgres compose runs on existing infra but Caddy/Traefik TLS routing for `telemetry.0dl.me` (or chosen subdomain) is one-time infra task not yet scoped. **Lane-T blocking precondition.**
- **Universal dylib prereq in librime fork:** smoodle-type/librime's `smoodle-build.yml` has macos-15 + macos-15-intel jobs but no `lipo` join step or universal-artifact upload. **Cross-repo dependency, upstream work in librime fork.**
- **`smoodle telemetry forget` server endpoint:** umami doesn't ship per-install-id delete OOTB. Either custom Postgres `DELETE` runner (preferred) or small server-side script. **Spike during Lane-T.**
- **Decision Gate criteria pre-registration date:** MP-2 requires criteria locked *before* observing signals. **Schedule as Lane G's first sub-task, not last.**
- **7-day soak window:** Lane G's soak is wall-time, not work-time. ~8-12 working days work + 7 calendar days soak = Phase 1 close lands ~3 weeks calendar after kickoff.

## Sources

### Primary research artifacts (HIGH confidence)
- `/Users/lex/Dev/my_repos/experiment/smoodle/.planning/research/STACK.md`
- `/Users/lex/Dev/my_repos/experiment/smoodle/.planning/research/FEATURES.md`
- `/Users/lex/Dev/my_repos/experiment/smoodle/.planning/research/ARCHITECTURE.md`
- `/Users/lex/Dev/my_repos/experiment/smoodle/.planning/research/PITFALLS.md`

### Project context (HIGH confidence)
- `/Users/lex/Dev/my_repos/experiment/smoodle/.planning/PROJECT.md`
- `/Users/lex/Dev/my_repos/experiment/smoodle/docs/PHASE1-PROMPT.md`
- `/Users/lex/Dev/my_repos/experiment/smoodle/.planning/codebase/CONCERNS.md`
- `/Users/lex/Dev/my_repos/experiment/smoodle/TODOS.md`

### Domain references (MEDIUM confidence)
- umami v3.1.0 release + self-hosted Compose docs
- GitHub Releases native asset digests changelog (2025-06)
- GHA macos-15 + windows-2025 GA changelog (2025-04-10)
- Apple `lipo` + universal binary docs
- launchd `WatchPaths` semantics (Apple developer docs + Discussions thread)
- tj-actions/changed-files March 2025 supply-chain incident
- TelemetryDeck Privacy FAQ + Pants anonymous telemetry docs (opt-in default-OFF precedent)
- Pester 5 + Sparkle 2.x changelog

---
*Research completed: 2026-05-08*
*Ready for roadmap: yes — 6-lane structure (F, E1+E2, T, S, R, G), ~8-12 working days + 7-day soak, fits ≤2-week Phase 1 finish budget.*
