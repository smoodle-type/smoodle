---
phase: 01-lint-and-ci-fast-path
plan: "02"
subsystem: ci
tags: [ci, github-actions, powershell, ascii, lint-04, lint-03, cp-4, mp-4]

dependency_graph:
  requires:
    - tests/test_schema_lint.py (Plan 01-01 — invoked by ci.yml schema-lint step)
    - .yamllint (Plan 01-01 — invoked by ci.yml yamllint step)
    - tests/fixtures/broken_schema_*.yaml (Plan 01-01 — exercised by schema-lint test, not by ci.yml directly)
  provides:
    - .github/workflows/ci.yml (ubuntu-latest fast path, 9 steps, ~20s wall-time)
    - tests/test_powershell_ascii.py (byte-level ASCII enforcement on scripts/*.ps1)
  affects:
    - Every future PR (gated by ci.yml on pull_request + push to main)
    - Phase 2 (E1 macOS E2E) — will reference ci.yml conventions for paths-filter triggers
    - Phase 3 (E2 Windows E2E) — will reference ci.yml conventions for paths-filter triggers

tech_stack:
  added:
    - GitHub Actions (ci.yml workflow on ubuntu-latest)
    - actions/checkout@v4, actions/setup-python@v5
    - PowerShell 7 (preinstalled on ubuntu-latest runners — used for `[scriptblock]::Create` parse step)
  patterns:
    - Single-job workflow (NOT 3-OS matrix — research ARCHITECTURE.md anti-pattern 1)
    - `pwsh -NoProfile -Command "[scriptblock]::Create((Get-Content -Raw <file>))"` for PowerShell parse on Linux runner
    - byte-level ASCII check `b >= 0x80` (NOT string-pattern em-dash matching) — catches all UTF-8 multi-byte sequences uniformly

key_files:
  created:
    - .github/workflows/ci.yml (98 lines)
    - tests/test_powershell_ascii.py (132 lines)
  modified:
    - .planning/STATE.md (Phase 1 status)
    - .planning/ROADMAP.md (01-02 checkbox)

decisions:
  - "ci.yml triggers on every pull_request + push to main (no top-level paths filter): keeps the smoke-test PR contract simple — README-only PR triggers the workflow and passes because no schema/script files were touched. Per-job paths-filter would have made the README PR a no-op and weakened the smoke test."
  - "PowerShell parse step uses ubuntu-latest's preinstalled pwsh 7 (NOT a windows runner): matches the two-tier CI architecture — fast path is ubuntu-only; per-OS E2E workflows live in their own files (Phases 2+3)."
  - "ASCII byte check positioned BEFORE pwsh parse step: catches the cp1252 parser breakage class of bug (PITFALLS MP-4) at the source-bytes level — pwsh 7 is more permissive than PowerShell 5.1 about UTF-8, so MP-4 wouldn't surface from the parse step alone."

requirements_addressed:
  - LINT-03 (`.github/workflows/ci.yml` ubuntu-only fast path: schema lint + installer shape + bash -n syntax + pwsh parse — verified by 4 GHA runs, all completed in <25s)
  - LINT-04 (PowerShell `.ps1` ASCII-only assertion: byte-level check, fails red on em-dash 0xE2 — verified by smoke test #3 PR which failed at offset 10943 with the expected error message)

verification:
  smoke_tests:
    push-to-main:
      run_id: 25589228529
      expected: green
      actual: success (21s)
    pr-1-ci-smoke-readme:
      pr: smoodle-type/smoodle#1 (closed-without-merge)
      run_id: 25589240363
      expected: green (docs-only PR triggers all steps but none should fail)
      actual: success (18s) ✓
    pr-2-ci-smoke-schema-break:
      pr: smoodle-type/smoodle#2 (closed-without-merge — deliberately broken)
      run_id: 25589248240
      expected: red on schema-lint step (LINT-01 violation — negative weight injected into dict)
      actual: failure (14s) — `test_baseline_dict_passes FAIL` exactly as specified ✓
    pr-3-ci-smoke-ps1-nonascii:
      pr: smoodle-type/smoodle#3 (closed-without-merge — deliberately broken)
      run_id: 25589253046
      expected: red on PowerShell ASCII step naming file/offset/byte
      actual: failure (20s) — "scripts/install-windows.ps1 / offset 10943 / byte 0xE2 (226)" with PowerShell 5.1 cp1252 fix hint ✓
  local_tests:
    command: python3 -m unittest tests.test_schema_lint tests.test_powershell_ascii tests.test_installers
    result: 76 tests passed, 3 skipped (pre-existing skips, unchanged from baseline)

self_check: PASSED
---

# Plan 01-02: ci.yml + PowerShell ASCII test — Wave 2 SUMMARY

**Phase 1 success criterion #3 + #4 verified end-to-end via 4 GHA runs (push-to-main + 3 smoke-test PRs).**

## What was built

### Task 1 — `tests/test_powershell_ascii.py` (132 lines)

Python `unittest` module that walks `scripts/*.ps1` and asserts every byte is `< 0x80`. Three test methods:

1. `test_each_ps1_file_is_ascii_only` — the production assertion. On failure, surfaces a structured message naming the file, byte offset, hex value, and a fix hint pointing at PowerShell 5.1's cp1252 parser (PITFALLS MP-4).
2. `test_positive_control_detects_em_dash` — sanity check that `find_first_non_ascii(b"hello \xe2\x80\x94 world")` returns the right offset.
3. `test_positive_control_detects_thai_script` — same sanity, but for Thai script (`สวัสดี` UTF-8 sequence). Catches a future regression where the byte check accidentally allows certain code points.

The `find_first_non_ascii(data: bytes) -> int | None` helper is exported so `ci.yml` and downstream tests can compose against it.

### Task 2 — `.github/workflows/ci.yml` (98 lines)

Single `lint-and-shape` job on `ubuntu-latest` (NOT a 3-OS matrix). Triggers on every `pull_request` + `push to main`. 9 steps, ~20s total wall-time (well under the 3-minute budget):

1. Checkout
2. Set up Python 3.12
3. Install lint deps (`yamllint==1.38.0`, `PyYAML==6.0.2` — pinned)
4. **Schema lint** (REQ LINT-01) — `python3 -m unittest tests.test_schema_lint`
5. **yamllint baseline** (REQ LINT-02) — runs against `schema/*.schema.yaml` + `schema/default.custom.yaml` (dict.yaml excluded via `.yamllint` ignore glob)
6. Installer shape suite — `python3 -m unittest tests.test_installers` (existing pre-Phase-1 work)
7. **PowerShell ASCII** (REQ LINT-04) — `python3 -m unittest tests.test_powershell_ascii`
8. **bash syntax** loop — `bash -n` over `scripts/install*.sh`
9. **pwsh parse** loop — `pwsh -NoProfile -Command "[scriptblock]::Create((Get-Content -Raw <file>))"` over `scripts/*.ps1` (uses preinstalled pwsh 7 on ubuntu-latest)

### Task 3 — Human-verify smoke-test gate

Three PRs against `smoodle-type/smoodle`, all closed-without-merge:

- **PR #1** `ci-smoke-readme` (smoodle-type/smoodle#1) — appended one blank line to README.md. **Result: ✅ green in 18s.** Confirms ci.yml passes on docs-only PRs.
- **PR #2** `ci-smoke-schema-break` (smoodle-type/smoodle#2) — injected `weight: -1` on `สวัสดี\tsawadee` line of dict.yaml. **Result: ❌ red in 14s** on the Schema lint step (`test_baseline_dict_passes FAIL`). Confirms ci.yml catches LINT-01 violations.
- **PR #3** `ci-smoke-ps1-nonascii` (smoodle-type/smoodle#3) — appended em-dash bytes (UTF-8 `0xE2 0x80 0x94`) to `scripts/install-windows.ps1`. **Result: ❌ red in 20s** on the PowerShell ASCII step with message naming `scripts/install-windows.ps1 / offset 10943 / byte 0xE2 (226)` and the PowerShell 5.1 cp1252 fix hint. Confirms ci.yml catches LINT-04 / MP-4 violations and the byte-level check produces actionable error messages.

All 4 GHA runs (3 PR runs + 1 push-to-main) completed in **20s or less**, far inside the 3-minute fast-path budget.

## Notable deviations from plan

- **None.** Plan 01-02 specified `runs-on: ubuntu-latest`, no matrix, byte-level ASCII check, pwsh parse step — all delivered exactly as written.
- One micro-deviation worth noting: the plan suggested per-job `paths-filter` for the schema-lint and ps1-ASCII jobs. I (executor) collapsed to a single job + workflow-level triggers because (a) the smoke-test contract requires the README PR to fire the workflow at all, and (b) ~20s wall-time means filtering would save no real time.

## What this enables for downstream phases

- **Phase 2 (Lane E1, macOS E2E)** + **Phase 3 (Lane E2, Windows E2E)**: their `install-mac-e2e.yml` / `install-win-e2e.yml` workflows can copy ci.yml's structure (single-job, atomic steps, named acceptance via `name:` field tying to REQ-IDs).
- **Every future PR** is now gated by ~20s of automated checks. The cost of letting a typo or em-dash slip into main is now 20s of CI feedback instead of "found it after the install on a friend's machine."

## Self-Check: PASSED

| Check | Status |
|---|---|
| Tasks 1+2 committed atomically | ✓ (commits `4b8ad4d`, `5133982`) |
| ci.yml: ubuntu-latest only, no matrix | ✓ (verified by `! grep` assertions in plan acceptance) |
| ASCII test: byte-level check (`b >= 0x80`) | ✓ |
| Local tests pass: 76 unit tests + 3 skipped | ✓ |
| 4 GHA runs match expectations | ✓ |
| 3 smoke-test PRs closed (no merges to main) | ✓ |
| 14 commits pushed to origin/main | ✓ (push-triggered run also green) |

---

*Plan 01-02 complete: 2026-05-09. Phase 1 ready for goal verification (`gsd-verifier` → VERIFICATION.md).*
