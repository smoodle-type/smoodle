---
phase: 03-windows-e2e
verified: 2026-05-10T00:00:00Z
verifier: gsd-verifier (opus)
verdict: PASS
goal_achievement: 5/5 (100%)
status: passed
score: 5/5 must-haves verified
re_verification:
  previous_status: none
  previous_score: n/a
gaps: []
human_verification: []
---

# Phase 3 Verification — Lane E2 Windows E2E

**Date:** 2026-05-10
**Verifier:** gsd-verifier (opus)
**Verdict:** **PASS**
**Goal achievement:** 5/5 (100%)
**Status:** passed (live workflow_dispatch run 25623956809 GREEN in 2m12s, 12/12 steps)

---

## Verdict (one-liner)

**PASS.** All 5 ROADMAP success criteria, all 5 REQ-IDs (E2EWIN-01..05), all 8 STRIDE register entries (T-03-01-01..08), and all 3 critical-pitfall surfaces (CP-2, CP-4, MP-4) have observable, code-resident mitigations confirmed by both static greppable invariants AND a live green windows-latest workflow run. Cross-phase invariants from Phase 1 (ubuntu fast path) and Phase 2 (macos-15 workflow) are preserved exactly. Two RED → GREEN iterations were both INTERNAL implementation defects (Pester Discovery-phase scoping; Write-Error terminating before diagnostics emit) — no external regressions à la Phase 2's `--no-quarantine` deprecation.

---

## Goal Statement (verbatim from ROADMAP.md Phase 3)

> A regression in `scripts/install-windows.ps1` or `scripts/install-librime-fork.ps1` is caught automatically by GHA before reaching the th-dc dockur dogfood test bed, on a `windows-latest` runner with `%APPDATA%\Rime\` cleared per job to prevent state contamination across runs.
> — `.planning/ROADMAP.md` line 68

---

## Goal Achievement Matrix (ROADMAP Success Criteria)

### SC #1: workflow_dispatch on windows-latest produces `%APPDATA%\Rime\thai_phonetic.dict.yaml` with SHA matching repo source; Pester 5 driver reports all Describe blocks green

- **Status:** **MET**
- **Evidence:**
  - Live workflow run https://github.com/smoodle-type/smoodle/actions/runs/25623956809 — GREEN in 2m12s on `windows-latest`.
  - Workflow file `.github/workflows/install-win-e2e.yml:32` — `runs-on: windows-latest` (hardcoded, not a matrix).
  - SHA verify step `.github/workflows/install-win-e2e.yml:179-193` performs `Get-FileHash -Algorithm SHA256` on `schema\thai_phonetic.dict.yaml` vs `$env:APPDATA\Rime\thai_phonetic.dict.yaml` and `Write-Error + exit 1` on mismatch.
  - Pester driver `tests/test_install_e2e_win.ps1:179-187` re-checks SHA inside Describe 2 (defense-in-depth).
  - All 4 Pester `Describe` blocks present and green: clean-slate idempotency (lines 115-130), schema files + SHA (140-188), GUI-skip token (191-199), Authenticode regression guard (202-218).

### SC #2: Driver explicitly asserts WeaselDeployer GUI step skipped with "manual deploy required" log line — passing CI does not falsely claim GUI flow works

- **Status:** **MET**
- **Evidence:**
  - Driver `tests/test_install_e2e_win.ps1:159-160` emits the verbatim token: `manual deploy required (SMOODLE_AUTO_DEPLOY=0 - WeaselDeployer GUI skipped on github-hosted runner)`.
  - Pester assertion `tests/test_install_e2e_win.ps1:193` — `Should -Match 'manual deploy required'` with explicit `-Because 'ROADMAP Phase 3 SC #2 mandates this exact token; missing it means CP-4 false-confidence vector is open'`.
  - Belt-and-suspenders workflow step `.github/workflows/install-win-e2e.yml:157-177` (`Assert manual-deploy token surfaced`) re-runs install-windows.ps1 and grep-asserts `Auto-deploy skipped` marker — fails red on driver-wording drift.
  - D5 seam preserved: driver emits token, install-windows.ps1 prod surface stays unchanged. Two layers must both break for silent skip to be possible.
  - Live run substep `Assert manual-deploy token surfaced (CP-4 belt-and-suspenders)` is GREEN.

### SC #3: `Get-AuthenticodeSignature` on `rime.dll` returns `NotSigned`; test fails red if signature changes (regression guard)

- **Status:** **MET**
- **Evidence:**
  - Driver `tests/test_install_e2e_win.ps1:202-218` Describe 4 — `(Get-AuthenticodeSignature $WeaselDll).Status | Should -Be 'NotSigned'`.
  - Verbatim regression-guard message in failure block (lines 210-216): `Weasel rime.dll signature changed; review fork upgrade vs. supply-chain compromise before unblocking`.
  - Script-level mirror `scripts/install-librime-fork.ps1:442-448` runs `Get-AuthenticodeSignature` post-swap with the SAME verbatim warning string — drift in either place fails tests at PR-time (`tests/test_install_librime_fork_win.py:166-177` `test_authenticode_diagnostic_block_present`).
  - Sequence test `tests/test_install_librime_fork_win.py:179-199` `test_authenticode_diagnostic_after_copy_item` asserts the diagnostic line is AFTER the Copy-Item line in source order (post-swap visibility, not pre-swap blocking).

### SC #4: Pre-step `Remove-Item -Recurse -ErrorAction SilentlyContinue $env:APPDATA\Rime, "$env:LOCALAPPDATA\Rime"` runs before each job; idempotency test verifies clean-slate state

- **Status:** **MET**
- **Evidence:**
  - Workflow `.github/workflows/install-win-e2e.yml:121-133` — `Clean-slate %APPDATA%\Rime + %LOCALAPPDATA%\Rime (CP-4 prevention)` step runs `Remove-Item -Recurse -Force -ErrorAction SilentlyContinue $env:APPDATA\Rime, "$env:LOCALAPPDATA\Rime"`.
  - Critical ordering fix in `ba11f59`: clean-slate step runs AFTER winget install Weasel (which can deploy default Rime configs to `%APPDATA%\Rime` in some Inno Setup `--silent` paths) and BEFORE the Pester driver. Live run substep ordering confirms this on the green run.
  - Driver `tests/test_install_e2e_win.ps1:115-130` Describe 1 (Clean-slate idempotency) re-asserts BOTH `%APPDATA%\Rime` AND `%LOCALAPPDATA%\Rime` were empty (`Get-ChildItem` count = 0) BEFORE Describe 2's BeforeAll fires `install-windows.ps1`.
  - Pester 5 Discovery-phase fix (`ba11f59`): imperative install-windows.ps1 invocation moved into `BeforeAll` block; without this fix Describe 1's emptiness check would have observed the post-install state.

### SC #5: SHA256 verification block runs between download and swap in `install-librime-fork.ps1`; corrupted DLL triggers exit 1 BEFORE any `Move-Item`/`Copy-Item` to Weasel install path

- **Status:** **MET**
- **Evidence:**
  - SHA verify block `scripts/install-librime-fork.ps1:310-367` post-DLL-resolution, pre-Copy-Item.
  - Line ordering proven by `tests/test_install_librime_fork_win.py:201-217` `test_sha_verify_before_copy_item`: `Get-FileHash -Algorithm SHA256 -Path $DllOut` (source line 353) is BEFORE `Copy-Item -Path $DllOut -Destination $WeaselDll` (source line 419).
  - Failure-before-Copy-Item invariant proven at runtime by `test_sha_mismatch_exits_before_swap` (lines 222-258): bogus all-zero sidecar → exit 1, fixture `$WeaselDll` bytes unchanged byte-for-byte.
  - Diagnostics-before-Write-Error fix (`41daefb`): expected/actual SHA values + `(CP-2 supply-chain protection)` marker emitted via `Write-Host` BEFORE the terminating `Write-Error` — without this fix `$ErrorActionPreference = 'Stop'` made all post-error `Write-Host` lines unreachable on the SHA-mismatch path.
  - Sidecar-source-of-truth proven by `test_no_hardcoded_hash_literal` (lines 150-164): regex `^\s*\$[A-Za-z0-9_]*HASH[A-Za-z0-9_]*\s*=\s*['"][a-f0-9]{64}['"]` returns no match — CP-2 anti-pattern 3 absent.
  - Sidecar-matches-DLL invariant proven by `test_sidecar_matches_vendored_dll` (lines 123-139): `hashlib.sha256(vendor/windows/rime.dll)` == `vendor/windows/rime.dll.sha256` content. Independently re-verified at audit time: both equal `3700c2f97cf189f6e85050e1d7001a356e9e22af213dbe11f734c4f33cd4275e`.
  - Sandboxed workflow step `.github/workflows/install-win-e2e.yml:195-210` (`SMOODLE_SKIP_SWAP=1`) exercises the gate end-to-end on the live runner without admin elevation — green substep on run 25623956809.

**Goal Achievement Score: 5/5 = 100% MET.**

---

## REQ-ID Coverage Matrix

| REQ-ID | Description | Status | Evidence |
|---|---|---|---|
| **E2EWIN-01** | Pester 5 driver runs install-windows.ps1 against fresh `%APPDATA%\Rime\` on windows-latest; verifies schema files copied + WeaselDeployer skipped with explicit "manual deploy required" assertion | **MET** | Driver `tests/test_install_e2e_win.ps1` Describes 1+2+3 (lines 115-199); workflow steps `Run Pester E2E driver` + `Assert manual-deploy token surfaced` green on run 25623956809. |
| **E2EWIN-02** | install-win-e2e.yml runs Pester driver on paths-filter + workflow_dispatch + weekly cron | **MET** | Workflow `.github/workflows/install-win-e2e.yml:10-27` declares `push` (paths-filtered), `pull_request` (paths-filtered), `workflow_dispatch`, `schedule: '0 8 * * 1'`. All four triggers present. |
| **E2EWIN-03** | SHA256 verify block in install-librime-fork.ps1 between download and swap; reads from sidecar | **MET** | Script lines 310-367 (verify block); sidecar resolution lines 83-89 with `SMOODLE_SHA256_SIDECAR` + `SMOODLE_SHA256_LIVE_URL` env surface. Vendored `vendor/windows/rime.dll.sha256` = real DLL SHA. Tests `test_sha_mismatch_exits_before_swap` + `test_vendored_sidecar_used_when_live_url_404s` + `test_sha_verify_before_copy_item` all green. |
| **E2EWIN-04** | `%APPDATA%\Rime\` cleared before each E2E job (CP-4 prevention) | **MET** | Workflow lines 121-133 `Remove-Item -Recurse -Force` of BOTH `%APPDATA%\Rime` AND `%LOCALAPPDATA%\Rime`; driver Describe 1 re-asserts emptiness post-clean, pre-install. Two-layer mitigation. |
| **E2EWIN-05** | Pester driver verifies `Get-AuthenticodeSignature` on `rime.dll` returns NotSigned (regression guard) | **MET** | Pester driver Describe 4 (lines 202-218); script-level mirror `install-librime-fork.ps1:442-448`; verbatim regression-guard string identical in BOTH places (`test_authenticode_diagnostic_block_present` enforces). |

**REQ Coverage Score: 5/5 = 100% MET.**

---

## STRIDE Register Coverage (T-03-01-01..08)

| ID | Category | Component | Disposition | Mitigation Visible at | Status |
|---|---|---|---|---|---|
| **T-03-01-01** | Tampering | install-win-e2e.yml | mitigate | `actions/checkout@v4` pinned at `.github/workflows/install-win-e2e.yml:41`; workflow file in `paths` filter (line 16, 21) | **MITIGATED** |
| **T-03-01-02** | Denial of Service | winget Rime.Weasel install hang | mitigate | `Start-Process -Wait` 300s cap at `.github/workflows/install-win-e2e.yml:73-77`; Win analog of d4ba9db escalation contract documented in workflow comment lines 62-65 | **MITIGATED** |
| **T-03-01-03** | DoS / cron cost | weekly cron resource cost | accept | `schedule: '0 8 * * 1'` line 27; ~10 GHA-min/week within free tier | **ACCEPTED (documented)** |
| **T-03-01-04** | Information Disclosure | Pester driver log output | mitigate | Driver does NOT call `Set-PSDebug -Trace 1` or dump env (verified by source grep: zero matches in `tests/test_install_e2e_win.ps1`); SHA values are public-by-design | **MITIGATED** |
| **T-03-01-05** | Spoofing | GUI-skip log-line drift | mitigate | Verbatim Pester `Should -Match 'manual deploy required'` at `tests/test_install_e2e_win.ps1:193`; belt-and-suspenders `Auto-deploy skipped` re-grep at workflow line 173-176 | **MITIGATED** |
| **T-03-01-06** | Tampering | Authenticode regression on rime.dll | mitigate | Pester Describe 4 `tests/test_install_e2e_win.ps1:202-218`; explicit failure-comment names this a regression-guard not a "we want unsigned" invariant | **MITIGATED** |
| **T-03-01-07** | Repudiation | Clean-slate `-ErrorAction SilentlyContinue` masking ACL/lock | accept | Driver Describe 1 emptiness assertion catches the case where SilentlyContinue masked a real failure (lines 121-129) | **ACCEPTED (driver double-checks)** |
| **T-03-01-08** | False-confidence (CP-4) | Win daemon-precondition vacuous satisfaction | accept-with-documentation | Driver source comment block lines 35-42 explicitly documents vacuous-daemon-precondition design; `SMOODLE_AUTO_DEPLOY=0` gates `if ($AutoDeploy)` block; daemon-restart never reached | **DOCUMENTED** |

**STRIDE Coverage Score: 8/8 entries traceable to source.**

---

## Critical Pitfall Coverage

| Pitfall | Mitigation Status | Evidence |
|---|---|---|
| **CP-2 (tag rewrite supply-chain inversion)** | **PASS** | Sidecar source-of-truth (NOT hardcoded — `test_no_hardcoded_hash_literal` enforces). Vendored PRIMARY + live URL SECONDARY (Win-specific REVERSAL from mac, documented at `install-librime-fork.ps1:313-316`). Failure-before-Copy-Item invariant proven by source-line ordering AND runtime fixture test. Sidecar-matches-DLL invariant proven byte-for-byte at audit time (both = `3700c2f9...275e`). |
| **CP-4 (GHA non-interactive runner false confidence)** | **PASS** | Three-layer mitigation: (a) workflow clean-slate Remove-Item BEFORE driver, AFTER winget (post-`ba11f59` ordering); (b) driver Describe 1 re-asserts emptiness via `Get-ChildItem` count; (c) verbatim `manual deploy required` token + belt-and-suspenders `Auto-deploy skipped` workflow grep. Three layers must all break for silent skip to be possible. T-03-01-08 vacuous-daemon-precondition documented in driver source. Live run substep `Assert manual-deploy token surfaced` is GREEN. |
| **MP-4 (PS 5.1 cp1252 non-ASCII byte parse error)** | **PASS** | `tests/test_powershell_ascii.py:63-66` glob extended in commit `bec3caf` to `sorted(list((REPO_ROOT/'scripts').glob('*.ps1')) + list((REPO_ROOT/'tests').glob('*.ps1')))`. Verified: `python3 -m unittest tests.test_powershell_ascii` green at audit time (3/3 OK including positive controls). New `tests/test_install_e2e_win.ps1` covered by extended glob; ASCII-only confirmed by `LC_ALL=C grep -P '[^\x00-\x7F]'` returning 0 matches per SUMMARY's verification block. |

---

## Cross-Phase Consistency Check

| Invariant | Phase 1 / 2 Source | Status After Phase 3 |
|---|---|---|
| ci.yml ubuntu-only fast path | `.github/workflows/ci.yml:17` `runs-on: ubuntu-latest` | **PRESERVED** — Phase 3 created its own `install-win-e2e.yml`; ci.yml not touched. Two-tier CI seam intact (D1). |
| install-mac-e2e.yml `runs-on: macos-15` | `.github/workflows/install-mac-e2e.yml:28` | **PRESERVED** — Phase 2 mac workflow file not modified by Phase 3 commits (verified by `git log --oneline` filter). |
| `tests/test_powershell_ascii.py` MP-4 invariant | Phase 1 LINT-04 | **EXTENDED, NOT BROKEN** — glob now covers `scripts/*.ps1` ∪ `tests/*.ps1`. Phase 1 baseline (76 pass / 3 skip per SUMMARY, 9-test green at audit) preserved exactly. The extension is mandatory: without it, the new `tests/test_install_e2e_win.ps1` would slip MP-4 protection. |
| `tests/test_install_librime_fork_mac.py` (Phase 2) | Phase 2 D7 unittest | **NOT TOUCHED** — Phase 3 added `tests/test_install_librime_fork_win.py` as a sibling; mac tests unaffected. |
| `vendor/macos/librime.1.dylib.sha256` vendored sidecar | Phase 2 D10 | **NOT TOUCHED** — Phase 3 added `vendor/windows/rime.dll.sha256` as a sibling. |
| Phase 1 fast path baseline 76 pass / 3 skip | Phase 1 SUMMARY | **PRESERVED** — Plan 03-01 SUMMARY explicitly verified 76 pass / 3 skip after extension; audit-time `python3 -m unittest tests.test_powershell_ascii tests.test_schema_lint` returns 17 tests OK; `tests.test_install_librime_fork_win` returns 9 tests OK (2 pwsh-required tests skipped on darwin host). |

**Cross-phase consistency: PASS.** Phase 3 added new files and 1 backwards-compatible glob extension. Zero modifications to Phase 1 or Phase 2 artifacts.

---

## Live Evidence

**Primary green run:** https://github.com/smoodle-type/smoodle/actions/runs/25623956809

- **Wall time:** 2m12s
- **Runner:** windows-latest (Windows Server 2022 / 2025 transition image)
- **Step pass list (12/12 GREEN):**

  1. ✓ Set up job
  2. ✓ Checkout (`actions/checkout@v4`)
  3. ✓ Show runner identity (`Get-ComputerInfo`, `$PSVersionTable`, Pester version)
  4. ✓ Install Weasel via winget (with 5-min timeout cap) — T-03-01-02 mitigation exercised
  5. ✓ Resolve Weasel install path (versioned subdir) — `SMOODLE_WEASEL_PATH` exported via `$GITHUB_ENV`
  6. ✓ Clean-slate `%APPDATA%\Rime` + `%LOCALAPPDATA%\Rime` (CP-4 prevention) — post-winget ordering correct
  7. ✓ Run Pester E2E driver (E2EWIN-01, E2EWIN-04, E2EWIN-05) — all 4 Describe blocks green
  8. ✓ Assert manual-deploy token surfaced (CP-4 belt-and-suspenders) — verbatim grep passes
  9. ✓ Verify dict.yaml SHA in destination matches repo source — independent re-check
  10. ✓ Run install-librime-fork.ps1 sandboxed (SHA + Authenticode gate exercised) — `SMOODLE_SKIP_SWAP=1`
  11. ✓ Run install-librime-fork tests (E2EWIN-03, E2EWIN-05) — Python unittest on windows-latest
  12. ✓ Post Checkout / Complete job

---

## Triage History

Two RED → GREEN iterations during the smoke-run cycle. Both were INTERNAL implementation defects, NOT external-environment regressions (the latter pattern is what Phase 2's `d4ba9db` `--no-quarantine` deprecation incident represents). Logging the distinction here so future verifier reads don't conflate the two patterns.

### Iteration 1: run **25623770858** RED → fix `ba11f59`

- **Symptom:** Pester driver showed Describe 1 (Clean-slate idempotency) failing because it observed the post-install `%APPDATA%\Rime` state, not the empty pre-install state.
- **Root causes (two coupled issues):**
  1. **Pester 5 Discovery-phase scoping bug:** file-level imperative code (`& install-windows.ps1`) ran during the Discovery phase, BEFORE any `It` block — so Describe 1's emptiness check observed already-populated state. Pester 5 idiom: imperative setup MUST live inside `BeforeAll`, not at file scope. Variables shared across Describes need `$script:` scoping (param-bound vars propagate naturally; file-level `$foo = ...` does not).
  2. **Workflow clean-slate ordering:** clean-slate step ran BEFORE winget Weasel install, so winget's Inno Setup default-config deployment to `%APPDATA%\Rime` re-polluted the directory before the driver ran.
- **Fix:** moved `install-windows.ps1` invocation into Describe 2's `BeforeAll`; added `$script:` scoping to shared vars; reordered workflow so clean-slate runs AFTER winget Resolve-Weasel-Path step and BEFORE Pester driver.
- **Pattern:** internal Pester-framework idiom defect + workflow-step ordering. Distinct from Phase 2's external-tool regression pattern.

### Iteration 2: run **25623904961** RED → fix `41daefb`

- **Symptom:** SHA-mismatch path on the sandboxed install-librime-fork.ps1 step exited 1 cleanly, but the expected `expected: <hash>` / `actual: <hash>` / `(CP-2 supply-chain protection)` diagnostic lines were NOT present in the workflow log — making operator triage of CP-2 supply-chain anomalies vs corrupted-download impossible.
- **Root cause:** `$ErrorActionPreference = 'Stop'` (set at script top) makes `Write-Error` terminating. Any `Write-Host` line AFTER `Write-Error` is unreachable. The original implementation had `Write-Error "ERROR: SHA256 mismatch"` followed by diagnostics — diagnostics never emitted.
- **Fix:** reordered to emit `Write-Host` diagnostics (expected, actual, source, CP-2 marker) BEFORE the terminating `Write-Error`. `tests/test_install_librime_fork_win.py:248-253` enforces the order with `assertIn` on each diagnostic string.
- **Pattern:** internal PowerShell semantics defect (`$ErrorActionPreference = 'Stop'` interaction). Distinct from external-environment regression.

### Run 25623956809 — GREEN

After both fixes, the live workflow_dispatch run completed in 2m12s with all 12 steps passing on `windows-latest`. The 2-iteration cost was 2 commits (`ba11f59`, `41daefb`) within roughly the same timeframe as Phase 2's 4-iteration `--no-quarantine` cycle (Phase 2 needed external-environment understanding before fix could be authored; Phase 3 fixes were code-internal and faster to author once the live run surfaced them).

---

## Plan-Level Self-Check Status

| Plan | Self-Check | Notes |
|---|---|---|
| 03-01 | PASSED | SUMMARY committed (`7b2ef02`); plan-level `self_check: PASSED` (line 88 of 03-01-SUMMARY.md). Phase 1 fast-path baseline preserved exactly (76 pass / 3 skip). Live workflow run intentionally deferred to land AFTER Plan 03-02 ships (paths-filter triggers on `install-librime-fork.ps1` changes). |
| 03-02 | PASSED (post-checkpoint) | `vendor/windows/rime.dll.sha256` = real DLL SHA `3700c2f9...275e`. SHA verify block + Authenticode diagnostic + Python unittest all shipped. Live human-verify checkpoint cleared by run 25623956809 (12/12 GREEN, 2m12s). |

---

## Deviations Surfaced + Resolved

1. **Pester 5 Discovery-phase imperative-setup defect (Rule 3 — internal framework idiom; auto-fix via `ba11f59`).** First live run RED because file-level `& install-windows.ps1` invocation ran during Discovery, polluting Describe 1's emptiness assertion. Pester 5 idiom requires imperative setup inside `BeforeAll`. Single coherent fix commit; documented in driver source comment block (lines 44-50). No deviation from plan intent — plan already mandated 4 Describe blocks; the fix is internal to Describe-block construction.

2. **Workflow clean-slate ordering (Rule 3 — internal step ordering; auto-fix via `ba11f59`).** Same fix commit reordered the workflow so `Clean-slate` runs AFTER `Resolve Weasel install path` (which depends on winget install) and BEFORE the Pester driver. Without this ordering, winget's Inno Setup `--silent` default-config deployment to `%APPDATA%\Rime` re-polluted the directory after the original pre-winget Remove-Item ran. Plan-checker accepted this as the canonical ordering 2026-05-10.

3. **`$ErrorActionPreference = 'Stop'` + `Write-Error` terminating before diagnostics (Rule 3 — internal PowerShell semantics; auto-fix via `41daefb`).** Diagnostics emitted via `Write-Host` AFTER `Write-Error` were unreachable. Fix: reorder to emit `Write-Host` BEFORE the terminating `Write-Error`. Operator-triage value of CP-2 supply-chain-vs-corrupted-download distinction is restored. `tests/test_install_librime_fork_win.py` runtime test enforces the order.

**No external-environment regressions.** No d4ba9db-class incidents (winget Rime.Weasel package id stable; choco fallback path shipped but not exercised; Pester 5 preinstalled on windows-latest as expected). Both deviations are internal craft fixes documented in source comments + tests + plan close.

---

## Annotations / Forward Concerns (non-blocking)

- **Node.js 20 deprecation in `actions/checkout@v4`.** Same annotation Phase 2 logged. When Phase 5 / HARDEN-03 / HARDEN-04 touches workflow files, audit `actions/checkout` version across all 4 workflows (`ci.yml`, `install-linux-e2e.yml`, `install-mac-e2e.yml`, `install-win-e2e.yml`). Not Phase 3 work; logged here for traceability.
- **windows-latest moving label (D2 intentional).** Workflow uses `windows-latest` which is in the windows-2022 → windows-2025 transition. Weekly cron is the canary. Phase 5 / HARDEN-04 release.yml MUST keep using `windows-latest` (not pinning to a specific version) to preserve canary value.
- **winget `--silent` documented hang risk (T-03-01-02 accepted).** Did NOT manifest on the green run. If it surfaces on a future cron run, escalate per the workflow comment lines 62-65 — do NOT silently mask with `|| true`. Choco fallback path shipped but not yet exercised live.
- **Phase 5 cross-repo dependency (HARDEN-04).** Plan 03-02's `SMOODLE_SHA256_LIVE_URL` env surface is wired and tested via the guaranteed-404 fallback path. The vendored sidecar will remain the primary source until Phase 5 lands the live `release.yml` emission upstream in `smoodle-type/librime`. No Phase 3 work required.

---

## Gaps Requiring Follow-up

**ZERO gaps.** All 5 ROADMAP success criteria, all 5 REQ-IDs, all 8 STRIDE entries, all 3 critical-pitfall surfaces, and all cross-phase invariants verified. Both internal-defect deviations were surfaced and resolved during the smoke-run cycle and are documented in source + tests + plan-close artifacts.

---

## Verdict Summary

**Phase 3 achieves its goal.** All five ROADMAP success criteria are MET-verified by a combination of (a) live green workflow run on windows-latest (`gh run view 25623956809` — 2m12s, 12/12 substeps green) and (b) static greppable invariants in the actual artifact files (verbatim error/regression-guard strings, line ordering, env-var surface, trigger declarations, paths-filter coverage, sidecar = DLL byte-for-byte equality). All five requirements (E2EWIN-01..05) trace cleanly to source evidence. All eight STRIDE register entries (T-03-01-01..08) have observable, code-resident mitigations or documented acceptances. All three critical-pitfall surfaces (CP-2, CP-4, MP-4) are protected by multi-layer mitigations. Cross-phase invariants from Phase 1 (ci.yml ubuntu-only, MP-4 ASCII baseline) and Phase 2 (install-mac-e2e.yml on macos-15, vendored mac sidecar, Phase 1 baseline 76 pass / 3 skip) are preserved exactly. Two internal-defect deviations (`ba11f59` Pester scoping + clean-slate ordering; `41daefb` Write-Error diagnostics ordering) were surfaced by live runs and resolved cleanly within the same execute cycle — distinct pattern from Phase 2's external-environment regression triage shape.

**Recommended next action:** orchestrator runs `/gsd-transition` to mark Phase 3 complete and unlock Phase 4 (Lane T Telemetry) + Phase 5 prerequisites (Lane S — Sparkle/release hardening depends on both Phases 2+3 being green). Phase 5's HARDEN-04 release.yml work can reuse the install-win-e2e.yml workflow_dispatch shape and weekly-cron pattern; HARDEN-02 verify-librime.ps1 can reuse the Pester Describe pattern from `tests/test_install_e2e_win.ps1`. The Phase 3 split-stack precedent (Pester 5 for E2E driver, Python unittest for script-level cross-platform) should be honored in Phase 5 as well.

---

*Verified: 2026-05-10*
*Verifier: gsd-verifier (opus)*
