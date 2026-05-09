---
phase: 02-macos-e2e
plan: "01"
subsystem: ci
tags: [ci, github-actions, macos, e2e, gui-gate, cp-4]

dependency_graph:
  requires:
    - .github/workflows/ci.yml (Phase 1 — paths-filter + single-job conventions reused)
    - .github/workflows/install-linux-e2e.yml (Phase 0 — closest analog template)
    - scripts/install.sh (existing — driver invokes via env-var override surface; not modified)
    - schema/thai_phonetic.dict.yaml (existing — driver SHA-verifies installed copy against this source)
  provides:
    - .github/workflows/install-mac-e2e.yml (macos-15 runner, paths-filter + workflow_dispatch + weekly cron)
    - tests/test_install_e2e_mac.sh (bash driver, SMOODLE_GUI_SESSION-aware, executable)
  affects:
    - Phase 2 Plan 02-02 (will append install-librime-fork.sh step + SHA256/arch-refusal assertions to this workflow)
    - Phase 5 Lane S (release.yml will reuse the workflow_dispatch shape and weekly-cron pattern)

tech_stack:
  added:
    - GitHub Actions on macos-15 (Apple Silicon runner)
    - actions/checkout@v4 (pinned, matches Phase 1 ci.yml convention)
    - Homebrew cask for Squirrel pre-flight (with squirrel-app legacy fallback)
  patterns:
    - Two-tier CI seam (slow per-OS workflow file, NOT a job in ci.yml)
    - Env-var-gated GUI step (SMOODLE_GUI_SESSION=0 in CI, =1 for local opt-in)
    - Belt-and-suspenders verbatim log-line assertion (CP-4 prevention against silent skip)
    - BSD shasum -a 256 (sha256sum is NOT on macos-15 by default)

key_files:
  created:
    - tests/test_install_e2e_mac.sh (84 lines, executable, set -euo pipefail)
    - .github/workflows/install-mac-e2e.yml (87 lines, single job on macos-15, 6 steps)
  modified: []

decisions:
  - "D1 honored: install-mac-e2e.yml is its own workflow file (NOT a job in Phase 1 ci.yml). Two-tier CI seam preserved — Phase 1 fast path stays uncontaminated at ~20s ubuntu, this workflow is opt-in slow path."
  - "D2 honored: runs-on: macos-15 hardcoded verbatim. No matrix, no macos-latest, no macos-14. ROADMAP SC #1 names the runner explicitly; label drift breaks reproducibility."
  - "D3 honored: paths-filter triggers on scripts/install*.sh (glob — future-proof for 02-02's install-librime-fork.sh) + schema/** + the workflow file itself. Plus workflow_dispatch + weekly cron 'Mon 07:00 UTC'."
  - "D4 honored: SMOODLE_GUI_SESSION env var gates osascript path. Driver default 0 → prints verbatim '[smoodle-e2e] no-GUI-session, skipped osascript step' AND never invokes osascript. Driver also force-sets SMOODLE_AUTO_DEPLOY=0 unconditionally (defense-in-depth — install.sh's own kill+restart is also CP-4 sensitive)."
  - "D7 honored: bash-only driver, no Pester (Pester is Phase 3 Windows territory). set -euo pipefail at top; no set -x (T-02-01-03 information-disclosure mitigation)."
  - "D8 honored: brew install --cask --no-quarantine squirrel with squirrel-app fallback. If both fail, hard-exits non-zero with helpful message (does NOT silently swallow per orchestrator's brief)."
  - "D9 honored: two atomic commits with conventional-commit scope feat(02-01): one per task."
  - "Belt-and-suspenders CP-4 step: workflow re-runs the driver capturing stdout and grep -F asserts the verbatim '[smoodle-e2e] no-GUI-session, skipped osascript step' line. Drift in driver wording surfaces as red CI step, not silent skip."

requirements_addressed:
  - "E2EMAC-01: tests/test_install_e2e_mac.sh runs scripts/install.sh against ~/Library/Rime/ on macos-15 + verifies schema files copied. Verified by: workflow's 'Run E2E driver' step + driver's file-presence loop + SHA-256 dict.yaml comparison against repo source. Squirrel kill+restart sub-clause is interpreted as 'gated and either logged-skipped (CI) or exercised (GUI=1)' — CI's SMOODLE_AUTO_DEPLOY=0 makes install.sh's own kill+restart skip; driver's SMOODLE_GUI_SESSION=0 makes the driver-level osascript path skip with verbatim log line."
  - "E2EMAC-02: install-mac-e2e.yml runs the driver on paths-filter (push-to-main + pull_request, paths scripts/install*.sh + schema/** + workflow file) + workflow_dispatch + weekly cron '0 7 * * 1'. Verified by: greppable invariants on the workflow file (grep -q 'workflow_dispatch:' / cron / paths)."
  - "E2EMAC-05: GUI-required steps explicitly gated. Verified by: (a) driver's SMOODLE_GUI_SESSION env-var branch with verbatim skip line, (b) workflow's belt-and-suspenders grep -F assertion against captured runtime stdout, (c) gate-logic smoke test (tracer fn) confirms osascript is NOT invoked on GUI=0 path even though the word appears elsewhere in the source."
  - "E2EMAC-03 + E2EMAC-04: NOT covered here. Deferred to Plan 02-02 per the seam in the plan's self_check section. The seam is clean: 02-01 ships workflow + driver + GUI gate; 02-02 ships install-librime-fork.sh-side SHA256+arch logic and a script-level test, then the first live workflow_dispatch run exercises the full Phase 2 surface."

verification:
  local_tests:
    - command: "python3 -m unittest tests.test_schema_lint tests.test_powershell_ascii tests.test_installers"
      result: "76 tests passed, 3 skipped (pre-existing skips). Phase 1 fast path baseline preserved exactly."
    - command: "bash -n tests/test_install_e2e_mac.sh"
      result: "exit 0 — driver bash syntax valid"
    - command: "test -x tests/test_install_e2e_mac.sh"
      result: "exit 0 — driver executable bit set"
    - command: "python3 -c \"import yaml; yaml.safe_load(open('.github/workflows/install-mac-e2e.yml'))\""
      result: "exit 0 — workflow YAML parses cleanly"
    - command: "Gate-logic smoke (in-process tracer): GUI=0 path emits exactly '[smoodle-e2e] no-GUI-session, skipped osascript step' and tracer log shows zero osascript invocations"
      result: "ACCEPT — both invariants hold"
  greppable_invariants:
    - "grep -q 'runs-on: macos-15' .github/workflows/install-mac-e2e.yml — exit 0 (ROADMAP SC #1)"
    - "grep -q 'workflow_dispatch:' .github/workflows/install-mac-e2e.yml — exit 0 (ROADMAP SC #5)"
    - "grep -q \"cron: '0 7 \\* \\* 1'\" .github/workflows/install-mac-e2e.yml — exit 0 (ROADMAP SC #5)"
    - "grep -q 'scripts/install\\*\\.sh' .github/workflows/install-mac-e2e.yml — exit 0 (paths-filter)"
    - "grep -q 'schema/\\*\\*' .github/workflows/install-mac-e2e.yml — exit 0 (paths-filter)"
    - "grep -F '[smoodle-e2e] no-GUI-session, skipped osascript step' .github/workflows/install-mac-e2e.yml — exit 0 (workflow's CP-4 assertion line)"
    - "grep -q 'no-GUI-session, skipped osascript step' tests/test_install_e2e_mac.sh — exit 0 (driver source)"
    - "grep -q 'shasum -a 256' tests/test_install_e2e_mac.sh — exit 0 (D7: BSD shasum, not sha256sum)"
  live_run_status: "DEFERRED — green-on-fresh-runner workflow_dispatch confirmation lands AFTER Plan 02-02 ships, per the plan's seam (paths-filter triggers on install-librime-fork.sh changes; first green run exercises both plans)."

self_check: PASSED
---

# Phase 2 Plan 01: Lane E1 macOS E2E (workflow + driver + GUI gate) Summary

**One-liner:** Two-tier CI seam realized for macOS — `install-mac-e2e.yml` on `macos-15` runs the bash driver `tests/test_install_e2e_mac.sh` with explicit `SMOODLE_GUI_SESSION` gating, ensuring CP-4 (GHA non-interactive runner false confidence) cannot manifest as silent skip.

## What was built

### Task 1 — `tests/test_install_e2e_mac.sh` (84 lines, executable)

Bash 4+ driver invoked by the workflow on `macos-15` and runnable locally for opt-in interactive verification on Apple Silicon.

Behavior:

1. Resolves `REPO_DIR` from `BASH_SOURCE` (no hard-coded paths).
2. Honors `SMOODLE_RIME_DIR` (default `~/Library/Rime`).
3. Honors `SMOODLE_GUI_SESSION` (default 0). On =0, prints `[smoodle-e2e] no-GUI-session, skipped osascript step` and never invokes `osascript`. On =1, attempts the Squirrel kill+restart best-effort (does not gate exit code on GUI failures — local Squirrel-not-running is OK).
4. Force-sets `SMOODLE_AUTO_DEPLOY=0` when invoking `scripts/install.sh` — defense-in-depth so install.sh's own GUI-required kill+restart is also skipped.
5. Asserts all 3 schema YAMLs copied (`thai_phonetic.schema.yaml`, `thai_phonetic.dict.yaml`, `default.custom.yaml`).
6. SHA-256 compares installed `thai_phonetic.dict.yaml` vs repo source via `shasum -a 256`. Mismatch → exit 1.
7. `grep -q "thai_phonetic"` content sanity on the schema + dict files (mirrors Phase 0 install-linux-e2e.yml).
8. `set -euo pipefail`. No `set -x` (T-02-01-03 information-disclosure mitigation).

### Task 2 — `.github/workflows/install-mac-e2e.yml` (87 lines)

Single job (`install-mac`) on `runs-on: macos-15` with `timeout-minutes: 30`. Triggers:

- `push: branches: [main]` paths-filtered (`scripts/install*.sh`, `schema/**`, the workflow file)
- `pull_request:` paths-filtered (same paths)
- `workflow_dispatch:` (manual smoke)
- `schedule: '0 7 * * 1'` (Monday 07:00 UTC weekly cron — surfaces runner-image upgrade regressions)

Steps (in order):

1. **Checkout** (`actions/checkout@v4`)
2. **Show runner identity** (`sw_vers`, `uname -m` — sanity confirms macos-15 + Apple Silicon)
3. **Install Squirrel via brew cask** (`brew install --cask --no-quarantine squirrel || ... squirrel-app || hard-fail`; verifies `/Library/Input Methods/Squirrel.app` exists post-install)
4. **Run E2E driver** (with `SMOODLE_GUI_SESSION: "0"` and `SMOODLE_AUTO_DEPLOY: "0"`)
5. **Assert GUI-gate skip log line was emitted** — re-runs driver capturing stdout, `grep -F` asserts the verbatim `[smoodle-e2e] no-GUI-session, skipped osascript step` line. Belt-and-suspenders against driver-wording drift.
6. **Verify dict.yaml SHA in destination matches repo source** — independent re-check on top of the driver's; surfaces the SHAs in the workflow log unambiguously.

## Deviations from plan

**[Rule 2 - Plan defect]** in the plan's overall `<verification>` block: one of the recommended verification commands was `grep -F '[smoodle-e2e] no-GUI-session, skipped osascript step' tests/test_install_e2e_mac.sh` (with `[smoodle-e2e]` prefix grepping the *source* file). The driver source uses a `log()` helper that prepends `[smoodle-e2e] ` at runtime, so the literal prefixed string only appears in *runtime stdout*, not in the source file. The Task 1 acceptance criterion correctly grepped without the prefix; the workflow's belt-and-suspenders step correctly greps captured runtime stdout (where the prefix IS present). No source-file change needed — both the driver and the workflow assertion are internally consistent and correct. Documented here for plan-author follow-up.

**No other deviations.** Plan executed exactly as written. Both tasks shipped on first attempt; Phase 1 fast-path baseline (76 pass / 3 skip) is preserved.

## What this enables for Plan 02-02

- The workflow file is itself a `paths:` trigger, so any modification to `install-librime-fork.sh` will fire the same workflow.
- The "Run E2E driver" step's position is intentional: 02-02 will append a sibling `install-librime-fork.sh` step **before** the driver step (so SHA256/arch-refusal logic runs and the dylib is in place by the time install.sh + the driver run). The current workflow's step ordering does not require modification — only insertion.
- The driver does NOT touch `install-librime-fork.sh` — that script's surface (SHA256 verify + Intel-Mac arch refusal) is exercised by 02-02's separate test, then the first green `workflow_dispatch` run wires both plans' surfaces together.
- The greppable-invariant + verbatim-skip-line approach is the template Plan 02-02 should mirror for its arch-refusal verbatim error message.

## Self-Check: PASSED

| Check | Status |
|---|---|
| Task 1 + Task 2 committed atomically with `feat(02-01)` scope | ✓ (`67d7b1b`, `d01912a`) |
| `tests/test_install_e2e_mac.sh` exists, executable, `set -euo pipefail`, SMOODLE_GUI_SESSION-aware | ✓ |
| `.github/workflows/install-mac-e2e.yml` exists, valid YAML, `runs-on: macos-15` hardcoded, no matrix | ✓ |
| All 4 triggers present (push paths-filtered, pull_request paths-filtered, workflow_dispatch, weekly cron) | ✓ |
| GUI-gate skip-line verbatim assertion in workflow + driver runtime emits same line | ✓ (gate-logic tracer smoke confirmed osascript NOT invoked on =0) |
| Phase 1 fast path baseline preserved | ✓ (76 pass / 3 skip, identical to 01-02-SUMMARY baseline) |
| ROADMAP SCs #1, #2, #5 covered (greppable); SCs #3, #4 deferred to 02-02 per seam | ✓ |
| REQ-IDs E2EMAC-01, E2EMAC-02, E2EMAC-05 addressed; E2EMAC-03/04 deferred to 02-02 | ✓ |

---

*Plan 02-01 complete: 2026-05-09. Wave 1 of Phase 2 Lane E1 closed; Wave 2 (Plan 02-02) clear to begin.*
