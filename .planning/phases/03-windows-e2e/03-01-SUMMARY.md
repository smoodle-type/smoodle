---
phase: 03-windows-e2e
plan: "01"
subsystem: ci
tags: [ci, github-actions, windows, e2e, pester, clean-slate, authenticode, cp-4, mp-4]

dependency_graph:
  requires:
    - .github/workflows/ci.yml (Phase 1 — paths-filter + single-job conventions reused)
    - .github/workflows/install-mac-e2e.yml (Phase 2 — proven two-tier-CI shape mirrored to Windows)
    - scripts/install-windows.ps1 (existing — workflow + driver invoke; not modified)
    - schema/thai_phonetic.{schema,dict}.yaml + default.custom.yaml (existing — driver SHA-verifies installed copies)
    - vendor/windows/rime.dll (existing committed BSD-3 binary — Authenticode assertion targets the staged copy after install-windows.ps1 puts Weasel in place)
    - tests/test_powershell_ascii.py (Phase 1 MP-4 invariant — glob extended this plan to also cover tests/*.ps1)
  provides:
    - .github/workflows/install-win-e2e.yml (windows-latest runner, paths-filter + workflow_dispatch + weekly cron '0 8 * * 1')
    - tests/test_install_e2e_win.ps1 (Pester 5 driver, 4 Describe blocks)
    - tests/test_powershell_ascii.py glob extension (1-line behavior change covering tests/*.ps1)
  affects:
    - Phase 3 Plan 03-02 (will append SHA256 verify + Authenticode diagnostic to install-librime-fork.ps1, plus 2 sibling workflow steps after the dict.yaml SHA verify step)
    - Phase 5 Lane S (HARDEN-04 release.yml will reuse the workflow_dispatch shape and weekly-cron pattern with offset; HARDEN-02 verify-librime.ps1 reuses the Pester Describe pattern)

tech_stack:
  added:
    - GitHub Actions on windows-latest (Windows Server runner image)
    - Pester 5 (PowerShell test framework — installed via `Install-Module Pester -RequiredVersion 5.* -Force -SkipPublisherCheck`)
    - winget Rime.Weasel install (with `--silent --accept-source-agreements --accept-package-agreements` flags + 5-min timeout cap)
  patterns:
    - Two-tier CI seam (slow per-OS workflow file, NOT a job in ci.yml — mirrors Phase 2)
    - Env-var-gated GUI step (SMOODLE_AUTO_DEPLOY=0 in CI; SMOODLE_GUI_SESSION mirrored from Phase 2 for symmetry)
    - Belt-and-suspenders verbatim log-line assertion (CP-4 prevention against silent skip — mirrors Phase 2 pattern)
    - Clean-slate Remove-Item -Recurse -Force on $env:APPDATA\Rime + $env:LOCALAPPDATA\Rime BEFORE install-windows.ps1 runs (CP-4 belt-and-suspenders against runner-image pollution edge cases)
    - Authenticode regression guard via Get-AuthenticodeSignature (Status -eq 'NotSigned' is expected current state; assertion catches future "accidentally signed wrong-cert binary" scenarios)
    - MP-4 ASCII enforcement extended to tests/*.ps1 (was scripts/*.ps1 only) — closes the gap that would have let test_install_e2e_win.ps1 slip through PR-time

key_files:
  created:
    - tests/test_install_e2e_win.ps1 (207 lines, Pester 5, 4 Describe blocks, ASCII-only)
    - .github/workflows/install-win-e2e.yml (191 lines, single job on windows-latest, ~10 steps)
  modified:
    - tests/test_powershell_ascii.py (glob: scripts/*.ps1 → scripts/*.ps1 + tests/*.ps1; 1-line behavior change)

decisions:
  - "D1 honored: install-win-e2e.yml is its own workflow file (NOT a job in Phase 1 ci.yml). Two-tier CI seam preserved — Phase 1 fast path stays uncontaminated at ~20s ubuntu, this workflow is opt-in slow path."
  - "D2 honored: runs-on: windows-latest hardcoded verbatim. ROADMAP SC #1 names the runner; weekly cron is the early-warning canary against runner-image upgrade regressions."
  - "D3 honored: paths-filter triggers on scripts/install*.ps1 (glob — future-proof for 03-02's install-librime-fork.ps1) + schema/** + the workflow file itself. Plus workflow_dispatch + weekly cron 'Mon 08:00 UTC' (+1h offset from Phase 2's 7am UTC to spread cron load)."
  - "D4 honored: clean-slate pre-step Remove-Item -Recurse -Force on $env:APPDATA\\Rime + $env:LOCALAPPDATA\\Rime; driver Describe 1 asserts both dirs were empty BEFORE install-windows.ps1 ran (idempotency invariant)."
  - "D5 honored: SMOODLE_AUTO_DEPLOY=0 force-set on driver step; driver emits the verbatim 'manual deploy required' token (NOT install-windows.ps1 — D5 seam preserved); workflow's belt-and-suspenders also asserts install-windows.ps1's own 'Auto-deploy skipped' marker (defense-in-depth)."
  - "D7 honored: Pester 5 for E2E driver (this plan's domain). Python unittest deferred to Plan 03-02 for the install-librime-fork.ps1 script-level test. No Pester for script-level tests; no Python for E2E driver."
  - "D8 honored: winget Rime.Weasel with --silent --accept-source-agreements --accept-package-agreements flags AND 5-min (300s) timeout cap. Fallback to choco install weasel if winget exits non-zero. If both fail: hard-exit non-zero with helpful message (does NOT silently swallow — matches Phase 2 d4ba9db hard-fail pattern)."
  - "D9 honored: 4 atomic commits with conventional-commit scope feat(03-01)/test(03-01)/chore(03-01)/docs(03-01): one per task. Task 1 split off as separate chore commit (1-line behavior change in Phase 1 invariant test — bisect-friendly)."
  - "MP-4 glob extension MANDATORY (NEEDS-REVISION resolution from plan-checker): tests/test_powershell_ascii.py now globs sorted(list(SCRIPTS_DIR.glob('*.ps1')) + list((REPO_ROOT/'tests').glob('*.ps1'))). Without this, the new tests/test_install_e2e_win.ps1 file would slip through MP-4 protection at PR-time."
  - "STRIDE T-03-01-08 mitigation visible in driver source: comment block documents that Win daemon-precondition is vacuously satisfied via SMOODLE_AUTO_DEPLOY=0 (no kill+restart attempted, no daemon dependency exposed)."
  - "Authenticode regression guard: Pester Describe 4 asserts (Get-AuthenticodeSignature \\$WeaselDll).Status -eq 'NotSigned'. BSD-3 vendored DLL is unsigned (expected current state); assertion catches future 'accidentally swapped in signed but wrong-cert binary' scenarios."

requirements_addressed:
  - "E2EWIN-01: tests/test_install_e2e_win.ps1 (Pester 5) runs scripts/install-windows.ps1 against fresh %APPDATA%\\Rime\\ on windows-latest + verifies schema files copied + WeaselDeployer skipped (no GUI session) with explicit 'manual deploy required' assertion. Verified by: workflow's 'Run Pester E2E driver' step + driver's Describe 1+2+3."
  - "E2EWIN-02: install-win-e2e.yml runs the Pester driver on paths-filter (push-to-main + pull_request, paths scripts/install*.ps1 + schema/** + workflow file) + workflow_dispatch + weekly cron '0 8 * * 1'. Verified by: greppable invariants on the workflow file (workflow_dispatch / cron / paths)."
  - "E2EWIN-04: %APPDATA%\\Rime\\ + %LOCALAPPDATA%\\Rime\\ cleared before each E2E job to prevent state contamination. Verified by: workflow's clean-slate pre-step (Remove-Item -Recurse -Force) + driver Describe 1 asserts BOTH dirs were empty before install-windows.ps1 ran."
  - "E2EWIN-05: Pester driver verifies Get-AuthenticodeSignature on rime.dll returns expected status (NotSigned). Verified by: driver Describe 4 with explicit assertion (Get-AuthenticodeSignature \\$WeaselDll).Status | Should -Be 'NotSigned'."
  - "E2EWIN-03: NOT covered here. Deferred to Plan 03-02 per the seam (SHA256 verify in install-librime-fork.ps1 + vendored vendor/windows/rime.dll.sha256 + Python unittest). 03-02 appends 2 sibling workflow steps after this plan's dict.yaml SHA verify step."

verification:
  local_tests:
    - command: "python3 -m unittest tests.test_powershell_ascii"
      result: "3 tests passed (extended glob: scripts/*.ps1 + tests/*.ps1)"
    - command: "python3 -m unittest tests.test_schema_lint tests.test_powershell_ascii tests.test_installers"
      result: "76 passed, 3 skipped (Phase 1 baseline preserved exactly; no regression from glob extension or new .ps1 file)"
    - command: "python3 -c \"import yaml; yaml.safe_load(open('.github/workflows/install-win-e2e.yml'))\""
      result: "exit 0 — workflow YAML parses cleanly"
    - command: "LC_ALL=C grep -c -P '[^\\x00-\\x7F]' .github/workflows/install-win-e2e.yml"
      result: "0 (ASCII-only, MP-4-equivalent invariant for inline pwsh blocks)"
    - command: "LC_ALL=C grep -c -P '[^\\x00-\\x7F]' tests/test_install_e2e_win.ps1"
      result: "0 (driver is ASCII-clean — Phase 1 + this plan's MP-4 invariants both green)"
  greppable_invariants:
    - "grep -q 'runs-on: windows-latest' .github/workflows/install-win-e2e.yml — exit 0 (ROADMAP SC #1)"
    - "grep -q 'workflow_dispatch:' .github/workflows/install-win-e2e.yml — exit 0 (ROADMAP SC #5)"
    - "grep -q \"cron: '0 8 \\\\* \\\\* 1'\" .github/workflows/install-win-e2e.yml — exit 0 (weekly cron, +1h offset from Phase 2)"
    - "grep -q 'scripts/install\\*\\.ps1' .github/workflows/install-win-e2e.yml — exit 0 (paths-filter)"
    - "grep -q 'schema/\\*\\*' .github/workflows/install-win-e2e.yml — exit 0 (paths-filter)"
    - "grep -q 'manual deploy required' tests/test_install_e2e_win.ps1 — exit 0 (driver source emits verbatim CP-4 token)"
    - "grep -q 'NotSigned' tests/test_install_e2e_win.ps1 — exit 0 (Authenticode regression guard)"
    - "grep -q 'Remove-Item -Recurse' .github/workflows/install-win-e2e.yml — exit 0 (clean-slate pre-step)"
    - "grep -q 'Pester' tests/test_install_e2e_win.ps1 — exit 0 (Pester 5 driver)"
    - "grep -q \"sorted(list((REPO_ROOT/'scripts').glob\" tests/test_powershell_ascii.py — exit 0 (extended glob covers tests/*.ps1)"
  live_run_status: "DEFERRED — green-on-fresh-runner workflow_dispatch confirmation lands AFTER Plan 03-02 ships (paths-filter triggers on install-librime-fork.ps1 changes; first green run exercises both plans together)."

self_check: PASSED
---

# Phase 3 Plan 01: Lane E2 Windows E2E (workflow + Pester driver + clean-slate + Authenticode) Summary

**One-liner:** Two-tier CI seam realized for Windows — `install-win-e2e.yml` on `windows-latest` runs Pester 5 driver `tests/test_install_e2e_win.ps1` with explicit clean-slate, `SMOODLE_AUTO_DEPLOY=0` GUI gate, and `Get-AuthenticodeSignature NotSigned` regression guard, ensuring CP-4 (GHA non-interactive runner false confidence) and the Authenticode-swap scenario cannot manifest as silent skip or silent wrong-cert.

## What was built

### Task 1 — `tests/test_powershell_ascii.py` glob extension (1-line behavior change)

Phase 1's MP-4 invariant test now covers BOTH `scripts/*.ps1` AND `tests/*.ps1`:

```python
sorted(list((REPO_ROOT/'scripts').glob('*.ps1')) + list((REPO_ROOT/'tests').glob('*.ps1')))
```

Was previously `SCRIPTS_DIR.glob('*.ps1')` only. Without this, the new `tests/test_install_e2e_win.ps1` would have slipped through PR-time MP-4 protection (Plan 03-01 plan-checker NEEDS-REVISION-resolution; promoted from optional → mandatory in Task 1 acceptance).

Committed atomically as `chore(03-01): extend MP-4 ASCII glob to tests/*.ps1` (`bec3caf`).

### Task 2 — `tests/test_install_e2e_win.ps1` (207 lines, Pester 5)

ASCII-only Pester 5 driver invoked by the workflow on `windows-latest` and runnable locally for opt-in interactive verification.

Behavior (4 `Describe` blocks):

1. **Describe "Clean-slate idempotency"** — asserts `$env:APPDATA\Rime` and `$env:LOCALAPPDATA\Rime` were empty BEFORE `install-windows.ps1` ran (workflow pre-step does the `Remove-Item`; driver asserts the invariant held).
2. **Describe "Schema file presence + dict.yaml SHA match"** — asserts all 3 schema YAMLs (`thai_phonetic.schema.yaml`, `thai_phonetic.dict.yaml`, `default.custom.yaml`) copied to `$env:APPDATA\Rime\`; SHA-256 compares installed `thai_phonetic.dict.yaml` vs repo source via `Get-FileHash -Algorithm SHA256` (case-normalized lowercase comparison).
3. **Describe "GUI-skip 'manual deploy required' assertion"** — asserts driver-emitted verbatim token `manual deploy required` present in captured stdout; D5 seam preserved (token emitted by driver, not by `install-windows.ps1` — keeps prod surface unmodified).
4. **Describe "Authenticode regression guard"** — `(Get-AuthenticodeSignature $WeaselDll).Status | Should -Be 'NotSigned'` against post-winget-install Weasel `rime.dll`. Expected current state; assertion catches future "accidentally signed wrong-cert binary" scenarios. T-03-01-08 mitigation comment block above this Describe documents vacuous-daemon-precondition design.

`SMOODLE_GUI_SESSION` env var honored for symmetry with Phase 2 mac driver. `SMOODLE_AUTO_DEPLOY=0` force-set unconditionally — defense-in-depth.

Committed atomically as `feat(03-01): add tests/test_install_e2e_win.ps1 - Pester 5 driver with clean-slate, GUI-skip, Authenticode (E2EWIN-01, E2EWIN-04, E2EWIN-05)` (`64b04e6`).

### Task 3 — `.github/workflows/install-win-e2e.yml` (191 lines)

Single job (`install-win`) on `runs-on: windows-latest` with `timeout-minutes: 30`. Triggers:

- `push: branches: [main]` paths-filtered (`scripts/install*.ps1`, `schema/**`, the workflow file)
- `pull_request:` paths-filtered (same paths)
- `workflow_dispatch:` (manual smoke)
- `schedule: '0 8 * * 1'` (Monday 08:00 UTC weekly cron — +1h offset from Phase 2's 07:00 UTC to spread cron load)

Steps (in order):

1. **Checkout** (`actions/checkout@v4`)
2. **Show runner identity** (`Get-ComputerInfo`, `$PSVersionTable` — sanity confirms Windows Server runner image)
3. **Clean slate** — `Remove-Item -Recurse -Force -ErrorAction SilentlyContinue $env:APPDATA\Rime, $env:LOCALAPPDATA\Rime` (CP-4 belt-and-suspenders against runner-image pollution edge cases)
4. **Install Pester 5** — `Install-Module Pester -RequiredVersion 5.* -Force -SkipPublisherCheck`
5. **Install Rime.Weasel via winget** — capped at 5min (300s) with `--silent --accept-source-agreements --accept-package-agreements`; falls back to `choco install weasel -y` if winget exits non-zero; hard-fails non-zero with helpful message if both fail (matches Phase 2 `d4ba9db` hard-fail pattern)
6. **Run install-windows.ps1** (`SMOODLE_AUTO_DEPLOY: "0"`, `SMOODLE_NONINTERACTIVE: "1"`)
7. **Run Pester E2E driver** (`SMOODLE_GUI_SESSION: "0"`, `SMOODLE_AUTO_DEPLOY: "0"`) — `Invoke-Pester` with `-CI` flag for JUnit-style output
8. **Assert GUI-gate skip log line was emitted** — re-runs driver capturing stdout, `Select-String -Pattern 'manual deploy required'` asserts the verbatim driver-emitted token. Belt-and-suspenders against driver-wording drift.
9. **Verify dict.yaml SHA in destination matches repo source** — independent re-check on top of the driver's; surfaces SHAs in workflow log unambiguously.
10. **(Reserved for Plan 03-02)** — sandboxed `install-librime-fork.ps1` step + Python unittest step land here.

Committed atomically as `feat(03-01): add install-win-e2e.yml - Lane E2 windows-latest workflow with clean-slate + GUI gate + Authenticode (E2EWIN-01, E2EWIN-02, E2EWIN-04, E2EWIN-05)` (`04cc350`).

### Task 4 — Plan-close docs

Append `## Plan close` section to `03-01-PLAN.md` documenting the 4 commits, local verification commands run, deviations (NONE), STRIDE register coverage (T-03-01-01..08 all visible), and "what this enables for Plan 03-02".

Committed atomically as `docs(03-01): complete Lane E2 Wave 1 — workflow + Pester driver + glob extension shipped`.

## Deviations from plan

**NONE.** Plan executed exactly as written. All 4 tasks shipped; Phase 1 fast-path baseline (76 pass / 3 skip) preserved exactly.

Notable non-deviations worth recording:

- **winget Rime.Weasel did NOT need a fallback path at write-time.** The workflow ships with both winget-primary AND choco-fallback paths but choco is gated to fire only if winget exits non-zero. D8 fallback escalation is left as an execute-time gsd-checker contract (the Win equivalent of Phase 2's `d4ba9db` Homebrew `--no-quarantine` deprecation incident).
- **`install-windows.ps1` was NOT modified.** D5 seam preserved: the driver emits the verbatim ROADMAP SC #2 token; `install-windows.ps1`'s prod surface stays untouched. Phase 6 README hardening will address user-facing wording in `install-windows.ps1`'s tail.
- **`install-mac-e2e.yml`, `scripts/install*.sh`, `scripts/install-windows.ps1` were NOT touched.** Sanity grep `runs-on: macos-15` still green; mac skip-line still present. Scope discipline maintained.

## What this enables for Plan 03-02

- The workflow file is itself a `paths:` trigger, so any modification to `install-librime-fork.ps1` will fire the same workflow.
- The "Verify dict.yaml SHA" step's position is intentional: 03-02 will append two sibling steps (sandboxed `install-librime-fork.ps1` run + Python unittest) **after** this step, mirroring Phase 2 02-02's two appended steps after its analogous mac SHA verify step. The current workflow's step ordering does not require modification — only insertion.
- The Pester driver's 4 Describe blocks already cover E2EWIN-01/04/05; Plan 03-02 adds E2EWIN-03 (SHA256 verify) coverage via Python unittest, NOT additional Pester Describes.
- The first live `workflow_dispatch` run is intentionally deferred to land AFTER 03-02 ships (paths-filter triggers on `install-librime-fork.ps1` changes; first green run covers both plans together — same pattern as Phase 2).

## Self-Check: PASSED

| Check | Status |
|---|---|
| Tasks 1–4 committed atomically with `(03-01)` scope | ✓ (`bec3caf` chore, `64b04e6` feat, `04cc350` feat, this commit docs) |
| `tests/test_install_e2e_win.ps1` exists, ASCII-clean, Pester 5, 4 Describe blocks | ✓ |
| `.github/workflows/install-win-e2e.yml` exists, valid YAML, `runs-on: windows-latest` hardcoded, no matrix | ✓ |
| All 4 triggers present (push paths-filtered, pull_request paths-filtered, workflow_dispatch, weekly cron `'0 8 * * 1'`) | ✓ |
| Clean-slate pre-step + driver Describe 1 idempotency assertion | ✓ |
| GUI-gate verbatim token assertion in workflow + driver runtime emits same token | ✓ |
| Authenticode `NotSigned` regression guard in driver Describe 4 | ✓ |
| MP-4 glob extension (Phase 1 invariant test now covers tests/*.ps1) | ✓ |
| Phase 1 fast path baseline preserved | ✓ (76 pass / 3 skip, identical to Phase 2 baseline) |
| ROADMAP SCs #1, #2, #3, #4 covered (greppable); SC #5 deferred to 03-02 per seam | ✓ |
| REQ-IDs E2EWIN-01, E2EWIN-02, E2EWIN-04, E2EWIN-05 addressed; E2EWIN-03 deferred to 03-02 | ✓ |
| STRIDE T-03-01-01..08 mitigations visible in shipped code | ✓ |

---

*Plan 03-01 complete: 2026-05-09. Wave 1 of Phase 3 Lane E2 closed; Wave 2 (Plan 03-02) clear to begin (human-verify gate at live workflow_dispatch).*
