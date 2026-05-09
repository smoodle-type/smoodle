---
phase: 01-lint-and-ci-fast-path
verified: 2026-05-09
verifier_model: opus
verdict: PASS
goal_achievement: 100%
requirement_coverage: 4/4 REQ-IDs verified
---

# Phase 1 (Lane F): Goal Verification

## Verdict: PASS

Phase 1's stated goal — "every PR is gated by a fast (~3 min) ubuntu-only check that catches schema typos, malformed weights, broken `import_preset` references, bash/pwsh syntax errors, and non-ASCII bytes in `.ps1` files before they merge" — is fully achieved in the codebase. All four ROADMAP success criteria are backed by direct, reproducible evidence: the local schema-lint test runs in 0.096s (96× faster than the 2s budget), `yamllint` exits 0 against the v0.0.6 baseline, the three smoke-test PRs (#1 README-touch, #2 schema-break, #3 ps1-nonascii) hit GitHub Actions and produced exactly the expected green/red/red conclusions in 14–21s wall-time per run (about 9× faster than the 3-minute target), and `bash -n` + `pwsh [scriptblock]::Create` are gated as named steps in `.github/workflows/ci.yml`. Every locked decision (CP-5 scope boundary, no 3-OS matrix, unittest not pytest, byte-level ASCII check) is enforced by either the test suite itself or the workflow file.

## Goal-Backward Evidence

### Success Criterion 1 — schema-lint test rejects broken fixtures in <2s
- **Status**: PASS
- **Evidence**:
  - `python3 tests/test_schema_lint.py` ran 14 tests in **0.096s** wall (`time` total 0.196s incl. interpreter startup). Result: `OK`. Budget = 2s; actual ≈ 5% of budget.
  - All four broken-schema fixtures present at `tests/fixtures/`:
    - `broken_schema_negative_weight.yaml` (605 bytes)
    - `broken_schema_bad_import_preset.yaml` (1.5k)
    - `broken_schema_missing_schema_id.yaml` (1.3k)
    - `broken_schema_malformed_algebra.yaml` (1.4k)
  - Each fixture has a dedicated negative-test method that asserts the validator returns `(False, msg)` AND that the message contains the violated check name:
    - `test_negative_weight_rejected` checks `"weight"` and `"-50"`/`"negative"` in `msg` (test_schema_lint.py:447-456)
    - `test_bad_import_preset_rejected` checks `"nonexistent_preset_xyz"` in `msg` (test_schema_lint.py:458-467)
    - `test_missing_schema_id_rejected` checks `"schema_id"` in `msg` (test_schema_lint.py:469-478)
    - `test_malformed_algebra_rejected` checks `"derive/ph"`/`"slash"`/`"parts"` in `msg` (test_schema_lint.py:480-489)
  - The CI smoke run for PR #2 (`ci-smoke-schema-break`, run id `25589248240`) failed precisely on the Schema lint step with `test_baseline_dict_passes ... FAIL` after `weight: -1` was injected into the dict body — confirming the same validator path fires red on a real schema regression.
- **Notes**: Wall-time is comfortably inside budget; if dict body grows further the line-by-line scan over ~28k rows still completes in <0.1s.

### Success Criterion 2 — .yamllint at root, yamllint exits 0 on baseline
- **Status**: PASS
- **Evidence**:
  - `.yamllint` exists at repo root (1.7k, 37 lines), starts with `extends: default`, contains a documented `ignore: | *.dict.yaml` to skip the TSV-body file, and disables `line-length`, `document-start`, and `brackets` to fit the v0.0.6 baseline.
  - `python3 -m yamllint -c .yamllint schema/thai_phonetic.schema.yaml schema/thai_phonetic.dict.yaml schema/default.custom.yaml` → **exit 0** (verified locally just now).
  - The dict file is silently skipped by yamllint via the `ignore` glob; its frontmatter is still validated by `validate_dict_structure()` via PyYAML — coverage is preserved.
- **Notes**: The dict-file ignore is a documented deviation in 01-01-SUMMARY.md (yamllint cannot tokenize tab-prefixed body lines per YAML 1.2 §6.1 — parser-level rejection, not configurable). This is a sound trade-off and is itself a structural concern enforced by `TestDictStructure`, so coverage is maintained, not lost.

### Success Criterion 3 — ci.yml red/green on smoke tests
- **Status**: PASS
- **Evidence** (from `gh run list --workflow=ci.yml --limit 5`):
  | Run | Branch / PR | Trigger | Conclusion | Wall |
  |-----|-------------|---------|------------|------|
  | 25589228529 | main | push | success | 21s |
  | 25589240363 | ci-smoke-readme (PR #1) | pull_request | **success** | 18s |
  | 25589248240 | ci-smoke-schema-break (PR #2) | pull_request | **failure** | 14s |
  | 25589253046 | ci-smoke-ps1-nonascii (PR #3) | pull_request | **failure** | 20s |
  | 25589334924 | main (close commit) | push | success | 20s |
  - **PR #1 (README-only)** turned **green** in 18s — every step succeeded (Set up job → Checkout → Set up Python 3.12 → Install lint deps → Verify pwsh → Schema lint → yamllint → Installer shape → PowerShell ASCII → Bash syntax → PowerShell parse → Complete job; verified via `gh run view 25589240363 --json jobs`).
  - **PR #2 (schema break: weight -1 injected into dict)** turned **red** in 14s. The only failing step was `Schema lint (REQ LINT-01): failure` (verified via `gh run view 25589248240 --json jobs`). The failure log shows `test_baseline_dict_passes ... FAIL` followed by the negative-weight detection message — failure is for the *correct* reason.
  - **PR #3 (em-dash 0xE2 0x80 0x94 appended to install-windows.ps1)** turned **red** in 20s. The only failing step was `PowerShell ASCII-only assertion (REQ LINT-04): failure`. The failure log contains the literal string `scripts/install-windows.ps1\n    offset 10943: byte 0xE2 (226)` plus the `PowerShell 5.1 reads .ps1 as Windows-1252` fix hint — failure is for the *correct* reason and the message is actionable.
- **Notes**: Wall-time on the green path is **18s**, vastly under the 3-minute (180s) ROADMAP target. All three smoke PRs are closed-without-merge (intentional per the test plan). Schema-break and ps1-nonascii each fail on the *single* step they were designed to exercise — no false positives in adjacent steps. The push-to-main run (25589228529) at the close commit also succeeds, confirming `main` itself is green-correct.

### Success Criterion 4 — bash -n + pwsh parse gated inside ci.yml
- **Status**: PASS
- **Evidence**:
  - `.github/workflows/ci.yml:55` — step `Bash syntax check (REQ LINT-03)` runs `bash -n` over all six shell scripts including the three user-facing installers `scripts/install.sh`, `scripts/install-librime-fork.sh`, `scripts/install-linux.sh` (verified by grep). Failures aggregated and surfaced via `exit 1` after the loop.
  - `.github/workflows/ci.yml:79` — step `PowerShell parse check (REQ LINT-03)` runs `pwsh -NoProfile -Command "[scriptblock]::Create((Get-Content -Raw '$f'))"` over both `scripts/install-windows.ps1` and `scripts/install-librime-fork.ps1` — the exact form mandated by the ROADMAP success criterion 4.
  - Both steps appeared as `success` in the green-path run (25589240363) per `gh run view --json jobs`, confirming they actually execute on every PR.
- **Notes**: pwsh is exercised on `ubuntu-latest` (PowerShell 7.x preinstalled) — the fast path uses Linux pwsh; PS5.1-specific semantics are deferred to Phase 3 Win E2E by design.

## Requirement Coverage

| REQ-ID | Plan | Verification | Status |
|--------|------|--------------|--------|
| LINT-01 | 01-01 | `tests/test_schema_lint.py` exists (590 lines), 7 TestCase classes, exits 0 on baseline + non-zero on each of 4 broken fixtures with check-specific error messages. CI run 25589248240 confirms it fires red on a real schema regression (`test_baseline_dict_passes FAIL`). | ✓ |
| LINT-02 | 01-01 | `.yamllint` exists at repo root (37 lines, `extends: default`); `yamllint -c .yamllint schema/*.{schema,dict,custom}.yaml` exits 0 (verified locally). Step `yamllint baseline (REQ LINT-02)` succeeded on green-path CI run 25589240363. | ✓ |
| LINT-03 | 01-02 | `.github/workflows/ci.yml` exists, ubuntu-latest only, 9 substantive steps, runs on `pull_request:` and `push: branches: [main]`. Schema lint + installer shape + bash -n + pwsh parse all gated as named steps. Confirmed green on README-only PR (#1) in 18s, well inside 3-min budget. | ✓ |
| LINT-04 | 01-02 | `tests/test_powershell_ascii.py` (132 lines) byte-level checks (`b >= 0x80`) all `scripts/*.ps1` files; positive controls for em-dash + Thai script. CI run 25589253046 confirms it fires red on em-dash injection with file path / offset 10943 / byte 0xE2 / fix hint surfaced in the log. | ✓ |

**Coverage: 4/4 REQ-IDs satisfied. No orphans.** REQUIREMENTS.md maps exactly LINT-01..04 to Phase 1; both PLAN.md frontmatter `requirements:` blocks declare them (01-01: LINT-01+LINT-02; 01-02: LINT-03+LINT-04).

## Locked-Decision Compliance

| Decision | Verified by | Status |
|----------|-------------|--------|
| CP-5 schema-lint scope: structure only, NOT regex semantics | `class TestRegexBodyNotCompiled` at tests/test_schema_lint.py:492 with `test_no_regex_compilation_of_algebra_bodies` (line 510) — uses `tokenize.generate_tokens()` to assert no `import re`/`from re import` appears in the executable source. Stronger than the planned string-match sentinel; structurally precludes any future re.compile() on rule bodies. | ✓ |
| Two-tier CI: ubuntu-only, no 3-OS matrix | `grep -E "runs-on:" .github/workflows/ci.yml` → only `runs-on: ubuntu-latest` (1 hit, no macos/windows). `grep -E "^[[:space:]]*strategy:" .github/workflows/ci.yml` → exit 1 (no matrix). | ✓ |
| Tests use Python unittest, NOT pytest | `grep -E "import pytest\|from pytest" tests/test_schema_lint.py tests/test_powershell_ascii.py` → exit 1 (zero matches). `grep -c "unittest.TestCase"` → 7 in test_schema_lint.py + 1 in test_powershell_ascii.py = 8 total. | ✓ |
| ASCII check is byte-level (b >= 0x80) | tests/test_powershell_ascii.py:36 — `if b >= 0x80:` inside `find_first_non_ascii(data: bytes)`. Operates on raw bytes (`path.read_bytes()`), not decoded strings — uniformly catches em-dash (E2), smart quote (E2), Thai script (E0..), and any other multi-byte UTF-8 sequence. | ✓ |
| Existing installer-shape suite continues to pass | `python3 -m unittest tests.test_installers` → `Ran 59 tests in 4.840s. OK (skipped=3)` — matches the pre-Phase-1 baseline (per .planning/codebase/TESTING.md "59 tests in ~5s"). No regression. | ✓ |

## Open Issues / Caveats

None blocking. A few observations worth recording for downstream phases:

1. **Wall-time has substantial headroom**: green path completes in 18-21s vs 180s ROADMAP target. Phase 2 (mac E2E), Phase 3 (win E2E), Phase 4 (telemetry) can confidently add to the fast path before the budget gets tight. Note though that the locked decision is to NOT bloat ci.yml — per-OS workflows are slow-path on `paths-filter`.

2. **Dict file yamllint exclusion is documented and reasoned**: `*.dict.yaml` is excluded from yamllint due to YAML 1.2 §6.1 tab-token rejection. The frontmatter is still validated by `TestDictStructure` via PyYAML safe_load, and the body is validated line-by-line with weight-integrality checks. Coverage is preserved through a different validator path, not lost.

3. **CP-5 sentinel is stronger than the plan specified**: the plan called for a string-match check on `re.compile(` near `algebra`/`derive`. The executor (per 01-01-SUMMARY.md deviation #3) replaced it with a `tokenize`-based check that asserts `re` is never imported at all. This is structurally more robust (no docstring-self-invalidation; no future-contributor risk of tokenizer evasion via aliasing). Recorded as a positive deviation.

4. **pwsh parse step uses bash-style single-quote interpolation** (`'$f'`) inside the pwsh `-Command` string. This works because bash expands `$f` before pwsh receives the string. If a future PR adds a script path containing apostrophes the quoting would break — defensive note for the maintainer, not a current bug (no script paths contain apostrophes).

## Recommendation

**PASS — proceed to `/gsd-transition`.** Phase 1 closes cleanly. The fast-path CI gate is foundational infrastructure for Phases 2 (mac E2E), 3 (win E2E), and 4 (telemetry), all of which are cleared to start in parallel. The smoke-test PR contract (green-on-docs / red-on-schema-break / red-on-ps1-nonascii) gives downstream phase authors a reusable shape for their own GHA workflow validation. No remediation work needed.

---

*Verified: 2026-05-09*
*Verifier: Claude (gsd-verifier, opus model)*
