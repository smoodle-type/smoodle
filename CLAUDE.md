# Smoodle — Project Instructions

Thai phonetic input method built on Rime/librime. Type `sawadee` → `สวัสดี` → space to commit. Three coupled repos:

- `smoodle-type/smoodle` — schema YAMLs + installer scripts + tests + docs (this repo)
- `smoodle-type/smoodle-app` — macOS IME app (Squirrel fork, universal binary, v0.1.0)
- `smoodle-type/librime` — librime fork carrying the peek-sort patch (tag `1.16.0-smoodle.1`)

**Status:** Phase 1 finish in progress. v0.0.6 schema shipped. Phase 0 closed 2026-05-06 — wedge narrowed to "founder + diaspora-Thai friends as they surface."

## Read these first (in order)

1. `.planning/PROJECT.md` — current project context, Validated/Active/Out-of-Scope, Key Decisions
2. `.planning/REQUIREMENTS.md` — 41 v1 REQ-IDs across 7 phases
3. `.planning/ROADMAP.md` — 7-phase structure, dependencies, success criteria
4. `.planning/research/SUMMARY.md` — research synthesis (stack/features/arch/pitfalls)
5. `.planning/codebase/` — existing codebase map

`docs/PHASE1-PROMPT.md` + `docs/RESUME.md` + `TODOS.md` are the historical (gstack-era) context the GSD plan was imported from. Read for archaeology, not as source of truth — the `.planning/` docs are canonical now.

## Locked decisions (do NOT relitigate without strong reason)

- **Foundation:** Rime/Squirrel (macOS) + Weasel (Windows) + fcitx5/ibus-rime (Linux). NOT a McBopomofo Swift IMK fork.
- **librime version:** pinned at 1.16.0 (matches Squirrel 1.1.2, Weasel 0.17.4).
- **Path A (algebra-thin dict):** speller.algebra rules collapse phonemic equivalence; future-proof for v0.2 LLM plugin.
- **librime fork distribution:** `smoodle-type/librime` tag `1.16.0-smoodle.1`. macOS+Windows ship the patched dylib; Linux accepts unpatched system librime with documented limitation.
- **Three-repo split:** schema/installer concerns separate from app concerns separate from engine concerns.
- **Multi-syllable Thai uses continuous Latin** (`khobkhun`, not `khob khun`) — Rime treats space as commit delimiter.
- **Algebra rules replace ALL occurrences** in one pass (`boost::regex_replace`), not first-match-only.
- **Rime weights are log-frequencies** — store RAW counts in dict YAML.
- **License separation** — Squirrel/Weasel are GPLv3, smoodle is MIT. Don't bundle the hosts.

## Phase 1 finish open work (do these)

7 phases. Parallel: 2+3+4 after 1. Sequential: 5 → 6 → 7.

| Phase | Lane | Goal |
|---|---|---|
| 1 | F (lint + CI fast path) | `tests/test_schema_lint.py` + `.yamllint` + ubuntu-only `ci.yml` (~3min/PR) |
| 2 | E1 (mac E2E) | `install-mac-e2e.yml` + driver + SHA256 verify + Intel-Mac arch refusal |
| 3 | E2 (win E2E) | `install-win-e2e.yml` + Pester 5 + clean-slate per job + Authenticode assertion |
| 4 | T (telemetry) | umami self-host + opt-in default-OFF + ephemeral install_id + purge endpoint |
| 5 | S (Sparkle + release) | `verify-librime.{sh,ps1}` (manual) + universal dylib (cross-repo) + atomic draft-then-publish |
| 6 | R (README + docs) | Status APPROVED + Win/Linux snippets + troubleshooting + smoodle-type→smoodle-type |
| 7 | G (Decision Gate) | Pre-register criteria FIRST, then 7-day soak + verdict |

## Out of Scope (deliberate; don't pull in)

- Schema regen / dict expansion (v0.0.6 is locked baseline)
- LLM tone-disambiguation plugin (Phase 1.5)
- iOS / Android (Phase 2; blocked on TODOS #2 BT-keyboard spike)
- Code-signing / notarization / MSI / MAS / winget submission (pre-public-ship gate)
- Auto-update infrastructure (Sparkle for smoodle itself; manual `git pull` is fine for 5-user dogfood)
- Sparkle re-swap LaunchAgent (Phase 1.5 — daemon-with-sudo wrong shape for the wedge)
- Single 3-OS GHA matrix on every PR (architecture anti-pattern; mac+win runners 10× slower)
- Hardcoded SHA256 in install scripts (use sidecar `.sha256`; tags can rewrite)
- JSON Schema for Rime YAML lint (algebra is regex-in-strings, can't introspect)

## Critical pitfalls to avoid (CP-1 .. CP-5)

- **CP-1 Sparkle re-swap loop:** No LaunchAgent. Manual `verify-librime.sh` only.
- **CP-2 Tag rewrite supply-chain:** Sidecar `.sha256`, tag-immutability CI guard, draft-then-publish.
- **CP-3 Telemetry deanonymization:** Ephemeral install_id, allowlist payload, default-N opt-in, IP drop, hour-rounded ts, 90d retention, `smoodle telemetry forget` purge.
- **CP-4 GHA non-interactive runner false confidence:** Gate GUI steps, clean slate per Win job, assert daemon running before installer runs.
- **CP-5 Schema lint scope creep:** Lint structure only. Engine-mode test (`v01_fixture.yaml` via `rime_api_console`) is the regex oracle.

## How to drive work forward

Phase 1 finish uses GSD workflow:

```
/gsd-plan-phase 1     # break Phase 1 into plans
/gsd-execute-plan ... # for each plan
/gsd-verify-phase 1   # gsd-verifier confirms phase goal achieved
/gsd-transition       # mark phase complete, move to next
```

Mode is yolo (auto-approve). Parallelization enabled. Quality model profile (opus for research/planning).

## Working with the codebase

- Tests: `python3 -m unittest tests.test_installers` (56 pass / 3 skipped before Phase 1 starts)
- Engine test: `python3 tests/test_dict.py --use-rime-api-console --fixture tests/v01_fixture.yaml`
- Bash + PowerShell installers: `set -euo pipefail`, hard 10-60s timeouts on host CLI calls, backup-before-overwrite, env override prefix `SMOODLE_`.
- Schema files: `schema/thai_phonetic.{schema,dict}.yaml` + `schema/default.custom.yaml`. Do NOT regenerate the dict in Phase 1 finish.
- librime fork: lives at `vendor/librime/` (gitignored, ~2GB after build); pull from `smoodle-type/librime` tag `1.16.0-smoodle.1`.
- Generated TSVs (`generated-tnc{,-full}.tsv`) are committed for offline regen replay; don't delete.
- `.env` (gitignored) holds the `crs.0dl.me` Anthropic relay credentials for dict regen.

---
*Last updated: 2026-05-08 after `/gsd-new-project` (Phase 1 finish initialization)*
