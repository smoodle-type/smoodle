---
phase: 02-macos-e2e
verified: 2026-05-09T00:00:00Z
verifier: gsd-verifier (opus)
verdict: PASS
goal_achievement: 5/5 (100%)
status: human_needed
score: 5/5 must-haves verified
re_verification:
  previous_status: none
  previous_score: n/a
gaps: []
human_verification:
  - test: "Commit .planning/phases/02-macos-e2e/02-02-SUMMARY.md to main"
    expected: "Working tree clean; 02-02-SUMMARY.md tracked in git"
    why_human: "SUMMARY.md exists on disk but is untracked (git status shows ??). All other Phase 2 artifacts are committed and the live workflow run is green; this is the final exec-state cleanup before phase close-out."
---

# Phase 2 Verification — Lane E1 macOS E2E

**Date:** 2026-05-09
**Verifier:** gsd-verifier (opus)
**Verdict:** PASS
**Goal achievement:** 5/5 (100%)
**Status:** human_needed (one outstanding exec-state action: commit 02-02-SUMMARY.md)

## Goal Statement

> A regression in `scripts/install.sh` or `scripts/install-librime-fork.sh` is caught automatically by GHA before reaching the founder's dogfood machine, on a `macos-15` runner with explicit GUI-step gating so passing CI does not falsely imply the `osascript`/Accessibility flow works.
> — `.planning/ROADMAP.md` line 54

## Success Criteria Verification

### SC #1: Workflow_dispatch on macos-15 produces ~/Library/Rime/thai_phonetic.dict.yaml with SHA matching repo source; workflow exits green

- **Status:** PASS
- **Evidence:**
  - Live workflow run https://github.com/smoodle-type/smoodle/actions/runs/25594460125 — GREEN in 1m4s on macos-15.
  - 9 substeps all green: `Checkout` → `Show runner identity` → `Install Squirrel via brew cask` → `Run E2E driver` → `Assert GUI-gate skip log line was emitted` → `Verify dict.yaml SHA in destination matches repo source` → `Run install-librime-fork.sh sandboxed` → `Run install-librime-fork tests`.
  - Workflow file: `.github/workflows/install-mac-e2e.yml:28` `runs-on: macos-15` (hardcoded, not a matrix or `macos-latest`).
  - SHA verify step `.github/workflows/install-mac-e2e.yml:82-90` performs `shasum -a 256 schema/thai_phonetic.dict.yaml` against `$HOME/Library/Rime/thai_phonetic.dict.yaml` and asserts equality with non-zero exit on mismatch.
  - Driver `tests/test_install_e2e_mac.sh:67-74` does the same SHA comparison from inside the driver process — defense-in-depth.
- **Decision:** PASS. Both the live green run AND the static greppable invariants are satisfied. The "post-Plan-02-02 first green run" precondition (per Plan 02-01's `<verification>` note) was met by the d4ba9db push run.

### SC #2: SMOODLE_GUI_SESSION=0 skips osascript with explicit log; =1 runs full path

- **Status:** PASS
- **Evidence:**
  - Driver `tests/test_install_e2e_mac.sh:42-51` — `if [ "${GUI_SESSION}" = "1" ]` branch attempts `osascript ... quit` + `open -b im.rime.inputmethod.Squirrel`; else-branch prints the verbatim `log "no-GUI-session, skipped osascript step"`.
  - Workflow `.github/workflows/install-mac-e2e.yml:69-80` — `Assert GUI-gate skip log line was emitted` step re-runs the driver, captures stdout, and `grep -F '[smoodle-e2e] no-GUI-session, skipped osascript step'` — non-zero exit if the line is missing. This is the CP-4 belt-and-suspenders.
  - The live runner emitted the log (substep `Assert GUI-gate skip log line was emitted` is green).
- **Decision:** PASS. Both env-var branches present in the driver; verbatim CI assertion enforces wording stability.

### SC #3: install-librime-fork.sh on x86_64 vs arm64-only dylib refuses with verbatim error + non-zero exit

- **Status:** PASS
- **Evidence:**
  - `scripts/install-librime-fork.sh:174-178` — `if [ "${HOST_ARCH}" = "x86_64" ]; then if ! echo "${DYLIB_ARCHS}" | grep -q "x86_64"; then echo "ERROR: this is an arm64-only dylib; Intel Mac not supported until universal dylib lands"; exit 1; fi; fi`. Verbatim string matches ROADMAP SC #3 byte-for-byte.
  - Test `tests/test_install_librime_fork_mac.py:126-156` `test_arch_refusal_x86_64_against_arm64_only_dylib` exercises with shim `lipo`-prints-`arm64` + `SMOODLE_HOST_ARCH_OVERRIDE=x86_64`, expects exit 1, asserts both verbatim string AND `assertNotIn 'Copying patched dylib'` (failure-before-sudo) AND `assertNotIn 'SHA256 verify passed'` (arch fires before SHA — D6 ordering proof).
  - Test green locally: `python3 -m unittest tests.test_install_librime_fork_mac` → `Ran 6 tests in 2.243s OK`.
  - Test green on macos-15 runner: substep `Run install-librime-fork tests (E2EMAC-03, E2EMAC-04)` of run 25594460125.
- **Decision:** PASS. Verbatim string + non-zero exit + failure-before-sudo all proven by both source greps and a live green test method.

### SC #4: SHA256 verify between download and swap; corrupted dylib → exit 1 BEFORE sudo cp

- **Status:** PASS
- **Evidence:**
  - `scripts/install-librime-fork.sh:213` — `_actual_sha="$(shasum -a 256 "${BUILT_DYLIB}" | awk '{print $1}')"` post-download.
  - `scripts/install-librime-fork.sh:215-220` — mismatch path prints `ERROR: SHA256 mismatch on downloaded dylib` + expected/actual + `(CP-2 supply-chain protection)` + `exit 1`.
  - **Failure-before-sudo line ordering:** `lipo -archs` at line 171, `shasum -a 256 "${BUILT_DYLIB}"` at line 213, first `sudo cp` at line 232. arch < sha < sudo confirmed numerically.
  - **Sidecar source NOT hardcoded:** lines 196-203 — live URL primary (`SHA256_LIVE_URL`), vendored fallback secondary (`SHA256_SIDECAR_FALLBACK` → `vendor/macos/librime.1.dylib.sha256`). Regex check `^[A-Za-z0-9_]*HASH[A-Za-z0-9_]*=.[a-f0-9]{64}.` returns no match — CP-2 anti-pattern 3 is absent.
  - Test `tests/test_install_librime_fork_mac.py:158-187` `test_sha_mismatch_exits_before_swap` — bogus `0x64` sidecar; expects exit 1, asserts `'SHA256 mismatch'`, `assertIn(bogus_sha, ...)` (T-02-02-04 debuggability), `assertNotIn 'Copying patched dylib'` (failure-before-sudo).
  - Vendored fallback path tested by `test_vendored_sidecar_used_when_live_sha_url_404s` (live URL → guaranteed-404 file:// path; vendored sidecar matches; expects exit 0 + `'vendored fallback'` + `'SHA256 verify passed'`).
  - Sandboxed workflow step `Run install-librime-fork.sh sandboxed (SHA + arch gate exercised)` (`SMOODLE_SKIP_SWAP=1`) ran green on the live runner — exercises the gate end-to-end without sudo.
- **Decision:** PASS. SHA verify position, corruption-fail-before-swap, and sidecar-not-hardcoded all proven.

### SC #5: Workflow runs on paths-filter + workflow_dispatch + weekly cron

- **Status:** PASS
- **Evidence:** `.github/workflows/install-mac-e2e.yml`
  - Line 9 `push:` with `branches: [main]` + `paths:` `scripts/install*.sh`, `schema/**`, `.github/workflows/install-mac-e2e.yml` (lines 11-14).
  - Line 15 `pull_request:` with the same paths (lines 16-19).
  - Line 20 `workflow_dispatch:` (manual trigger).
  - Line 23 `cron: '0 7 * * 1'` (Monday 07:00 UTC).
- **Decision:** PASS. All four trigger sources present and match the locked decision (D3).

## Requirements Verification

| REQ-ID | Description | Status | Evidence |
|---|---|---|---|
| E2EMAC-01 | Driver runs install.sh against fresh ~/Library/Rime/ on macos-15; verifies schema files copied + Squirrel kill+restart succeeds | PASS | Driver `tests/test_install_e2e_mac.sh:37` runs `bash scripts/install.sh` with `SMOODLE_AUTO_DEPLOY=0`; schema-file presence loop at lines 54-61; SHA-256 dict.yaml comparison at lines 67-74. Kill+restart sub-clause is satisfied via gating (=0 logs skip line; =1 attempts best-effort osascript). Live green run confirms behavior. |
| E2EMAC-02 | install-mac-e2e.yml runs the driver on paths-filter + workflow_dispatch + weekly cron | PASS | Workflow lines 8-23 declare all 4 triggers with the canonical paths. |
| E2EMAC-03 | SHA256 verification block added between download and swap; reads expected hash from sidecar | PASS | Script lines 187-225 SHA verify block; live URL primary, vendored fallback at line 200. Tests `test_sha_mismatch_exits_before_swap` + `test_vendored_sidecar_used_when_live_sha_url_404s` both green. |
| E2EMAC-04 | install-librime-fork.sh refuses arm64-only dylib onto x86_64 with explicit error + exit 1 | PASS | Script lines 166-185 — verbatim error string + non-zero exit. `test_arch_refusal_x86_64_against_arm64_only_dylib` green. |
| E2EMAC-05 | GUI-required steps explicitly gated (skipped on non-interactive runner) | PASS | Driver lines 42-51 + workflow CP-4 belt-and-suspenders assertion lines 69-80. Both layers required to break before silent skip is possible. |

## Locked Decisions Validation

- **D1 (two-tier CI: separate workflow file, NOT a job in ci.yml):** PASS — `.github/workflows/install-mac-e2e.yml` is its own file with its own job. Phase 1 `ci.yml` remains ubuntu-only.
- **D2 (macos-15 runner verbatim, no matrix, no macos-latest):** PASS — `runs-on: macos-15` at line 28; `grep -c 'matrix:' .github/workflows/install-mac-e2e.yml` returns 0.
- **D3 (paths-filter strategy: scripts/install*.sh + schema/** + workflow file + workflow_dispatch + weekly Mon 07:00 UTC cron):** PASS — all four triggers present with canonical paths.
- **D4 (GUI gate via SMOODLE_GUI_SESSION env var; verbatim skip log line):** PASS — driver branch lines 42-51; workflow assertion lines 69-80; verbatim string `[smoodle-e2e] no-GUI-session, skipped osascript step`.
- **D5 (SHA256 verify shape: sidecar source-of-truth, live URL primary + vendored fallback, NO hardcoded hash):** PASS — script lines 196-203; CP-2 anti-pattern 3 grep returns no match; `test_no_hardcoded_hash_literal` green.
- **D6 (arch refusal BEFORE SHA verify):** PASS — line ordering: arch=171 < shasum=213 < sudo=232. Test method confirms by asserting `assertNotIn 'SHA256 verify passed'` on the arch-failure path.
- **D7 (Python unittest, not pytest):** PASS — `tests/test_install_librime_fork_mac.py` uses stdlib `unittest`; `python3 -m unittest tests.test_install_librime_fork_mac` runs and passes 6/6.
- **D8 (brew install --cask squirrel with squirrel-app fallback):** PASS — workflow lines 51-55. `--no-quarantine` correctly removed in commit `d4ba9db` after Homebrew deprecated the flag in 2025; comment at lines 46-49 documents the rationale.
- **D9 (conventional commits with `feat(02-XX)`/`test(02-XX)` scope):** PASS — `git log --oneline` shows `feat(02-01)`, `feat(02-02)`, `test(02-02)`, `fix(02-01)` scopes on commits `67d7b1b`, `d01912a`, `466b43c`, `550d026`, `9676d49`, `668e6dc`, `d4ba9db`.
- **D10 (vendored sidecar as cross-repo seam stub until Phase 5):** PASS — `vendor/macos/librime.1.dylib.sha256` committed (64-hex `d5723e0d...e2b`); script's fallback chain works correctly under both states.

## Critical Pitfalls Mitigation

| Pitfall | Mitigation Status | Evidence |
|---|---|---|
| **CP-2 (tag rewrite supply-chain inversion)** | PASS | Sidecar-source-of-truth (NOT hardcoded), post-download-pre-swap verify, vendored fallback. Failure-before-sudo invariant enforced by line ordering AND test assertion. Phase 5 / HARDEN-04 will add live-sidecar emission upstream; vendored copy persists as defense-in-depth. |
| **CP-4 (GHA non-interactive runner false confidence)** | PASS | Two-layer mitigation: driver-side env-var branch + workflow-side `grep -F` verbatim assertion. Belt-and-suspenders against any single point of drift. Squirrel daemon-precondition step (`/Library/Input Methods/Squirrel.app` existence check, line 57) ensures the prereq is real before the installer runs. Live runner ran green; the assertion step passed (which means the verbatim line WAS emitted — silent skip is observably impossible here). |
| **MP-3 (Intel-Mac silent failure)** | PASS | `lipo -archs` check ordered BEFORE SHA verify (D6 — cheaper, fails earlier on the path Intel-Mac users hit). Verbatim error string matches ROADMAP SC #3 byte-for-byte. Test exercises the failure path on an arm64 host via `SMOODLE_HOST_ARCH_OVERRIDE=x86_64` + shim `lipo`, no Intel hardware required. |

## Plan-Level Self-Check Status

| Plan | Self-Check | Notes |
|---|---|---|
| 02-01 | PASSED | SUMMARY committed (`a2709da`). Plan-level self_check `PASSED`. All Wave 1 invariants verified. |
| 02-02 | PASSED (pre-checkpoint) | SUMMARY exists on disk at `.planning/phases/02-macos-e2e/02-02-SUMMARY.md` but is **untracked in git** (`git status` shows `??`). Pre-checkpoint self_check `PASSED`. The Task 4b human-verify checkpoint is observably satisfied by the green live run 25594460125 — the orchestrator should commit 02-02-SUMMARY.md (with run-id captured) to formally close the plan. |

## Deviations Surfaced + Resolved

1. **`--no-quarantine` flag deprecation (Rule 1 — external environment regression).** Initial `brew install --cask --no-quarantine squirrel` failed RED on three workflow runs (25591684384, 25591862949, 25594426572) with `Error: invalid option: --no-quarantine`. Root cause: Homebrew deprecated and removed the flag in 2025; the plan's locked decision D8 was authored when the flag was still valid. **Fix:** commit `d4ba9db` removed `--no-quarantine` from both cask invocations and added an inline comment (lines 46-49) explaining why the flag is no longer needed in this context (CP-4 GUI-gate already prevents Gatekeeper friction at the install.sh + osascript boundary). Smoke run #4 (25594460125) green in 1m4s. **Plan-author follow-up:** update Plan 02-01's locked decision D8 to reflect that the flag is removed permanently — the Phase 5 / HARDEN-04 work that triggers cask reinstall must NOT re-introduce it.

2. **Live dylib already universal, not arm64-only (Rule 1 — factual correction).** The plan's `cross_repo_prereq` narrative anticipated `librime-1.16.0-smoodle.1-macOS-universal.dylib` being arm64-only at execute time. Live observation: the published asset is already universal (`x86_64 arm64`). The arch-refusal gate is still required (independent protection against future regressions and tag rewrites). Tests exercise the arm64-only failure path via shim `lipo` returning `arm64` alone. No code change; narrative truth-up only. **Plan-author follow-up:** Phase 5 / HARDEN-03 plan-checker scope can be reduced — universal-dylib build may already be done upstream; only `release.yml` live-sidecar emission remains.

3. **`.gitignore` blocked `vendor/macos/` (Rule 3 — blocking issue auto-fix).** The repo's `.gitignore` had `vendor/*` with allowlist exceptions only for `vendor/{*.patch,README.md,windows/,windows/rime.dll}`. Plan 02-02's `vendor/macos/librime.1.dylib.sha256` was blocked from `git add`. Auto-fixed by mirroring the existing `vendor/windows/` allowlist pattern (4 lines added). Single coherent commit `466b43c`. No deviation from plan intent.

4. **Test-harness `SMOODLE_SKIP_BUILD=1` short-circuited download (Rule 1 — test-harness fix).** First test run failed because the script's line 89 condition is `if [ "${SKIP_DOWNLOAD}" != "1" ] && [ "${SKIP_BUILD}" != "1" ]` — both must be 0 for the download branch to run. With `SKIP_BUILD=1` set as a test default, the script bypassed download, leaving `_downloaded=""`, so the SHA verify block ran the "skipped (source-built dylib)" branch. Fix: removed `SMOODLE_SKIP_BUILD` from `_run_script`'s defaults. Documented inline. Not a script bug — a test-harness misconfiguration on first author.

## Annotations / Forward Concerns (non-blocking)

- **Node.js 20 deprecation in actions/checkout@v4.** GitHub annotation on run 25594460125: `actions/checkout@v4` runs on Node.js 20 which is deprecated; default flips to Node.js 24 on 2026-06-02; Node.js 20 removed from runners on 2026-09-16. The pin to `@v4` is a Phase 1 ci.yml convention (D1 honored). When Phase 5 / HARDEN-03 / HARDEN-04 touches workflow files, audit `actions/checkout` version across all four workflows (ci.yml, install-linux-e2e.yml, install-mac-e2e.yml, future install-win-e2e.yml). Not Phase 2 work; logged here for traceability.
- **02-02-SUMMARY.md is untracked.** Pre-checkpoint `self_check_pre_checkpoint: PASSED` already, and the live-run gate (Task 4b) is observably satisfied by run 25594460125. The orchestrator should commit the SUMMARY with the run-id captured before transitioning Phase 2 → complete.
- **Defense-in-depth `sudo` shim in tests.** `tests/test_install_librime_fork_mac.py:78-80` writes a no-op `sudo` stub into the shim PATH dir. With `SMOODLE_SKIP_SWAP=1` the script never reaches the sudo path anyway, but the stub ensures an accidental swap-path reach during a future regression no-ops on a dev box instead of escalating. Good hygiene; no action needed.

## Verdict Summary

**Phase 2 achieves its goal.** All five ROADMAP success criteria are PASS-verified by a combination of (a) live green workflow run on macos-15 (`gh run view 25594460125` — 1m4s, all 9 substeps green) and (b) static greppable invariants in the actual artifact files (verbatim error strings, line ordering, env-var surface, trigger declarations, paths-filter coverage). All five requirements (E2EMAC-01 through E2EMAC-05) trace cleanly to source evidence. All three critical pitfalls (CP-2, CP-4, MP-3) have observable, code-resident mitigations — not just narrative claims. The `--no-quarantine` deprecation surfaced and was resolved cleanly during the smoke-run cycle (4 RED runs → root cause identified → 1 commit fix → smoke run #4 GREEN).

**Recommended next action:** orchestrator commits `.planning/phases/02-macos-e2e/02-02-SUMMARY.md` (currently untracked) with the live run-id `25594460125` captured in the SUMMARY's pending `live_run_status` field, then runs `/gsd-transition` to mark Phase 2 complete and unlock Phase 3 (Lane E2 Windows E2E). The Windows phase can fully mirror the Phase 2 shape — sandboxed install-librime-fork.ps1 step + Pester driver with WeaselDeployer GUI gating mirroring the SMOODLE_GUI_SESSION pattern.

---

*Verified: 2026-05-09*
*Verifier: gsd-verifier (opus)*
