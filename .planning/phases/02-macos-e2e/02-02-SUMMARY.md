---
phase: 02-macos-e2e
plan: "02"
subsystem: installer-hardening
tags: [installer-hardening, sha256, arch-refusal, cp-2, mp-3, macos, cross-repo]

dependency_graph:
  requires:
    - .github/workflows/install-mac-e2e.yml (Plan 02-01 — Wave 2 appends 2 steps)
    - tests/test_install_e2e_mac.sh (Plan 02-01 — not modified by this plan)
    - scripts/install-librime-fork.sh (existing — modified in place)
  provides:
    - vendor/macos/librime.1.dylib.sha256 (sidecar; 64-hex SHA-256 of live universal dylib)
    - vendor/macos/README.md (sidecar provenance + bump procedure)
    - .gitignore (allowlist vendor/macos/{README.md,librime.1.dylib.sha256})
    - SHA256 verify block in scripts/install-librime-fork.sh (CP-2 mitigation)
    - Intel-Mac arch refusal in scripts/install-librime-fork.sh (MP-3 mitigation)
    - tests/test_install_librime_fork_mac.py (6 unittest methods; arch + SHA + fallback + format)
    - 2 new steps in .github/workflows/install-mac-e2e.yml (sandboxed install-librime-fork + Python unittest)
  affects:
    - Phase 5 Lane S (HARDEN-04 reuses SHA256 verify shape; HARDEN-03 universal-dylib emission replaces stub-as-primary)
    - Phase 3 Lane E2 Windows (mirror gate shape into install-librime-fork.ps1)
    - smoodle-type/librime release.yml (cross-repo: live `.sha256` sidecar emission lands in Phase 5)

tech_stack:
  added:
    - lipo -archs arch detection (macOS-native; Xcode CLT preinstalled on macos-15)
    - shasum -a 256 SHA256 verification (BSD shasum; matches Plan 02-01 driver convention)
    - file:// URLs through curl for test fixtures (libcurl built-in; works on macOS + Linux)
    - Shim PATH testing pattern (lipo, file, sudo stubs) for cross-platform unittest
  patterns:
    - Post-download-pre-swap SHA256 gate (research/ARCHITECTURE.md Pattern 3)
    - Sidecar `.sha256` source-of-truth (NOT hardcoded hash literal — CP-2 anti-pattern 3)
    - Live URL primary + vendored fallback (defense-in-depth even after Phase 5)
    - Arch BEFORE SHA ordering (D6: cheaper gate fails earlier, surfaces correct error)
    - Failure-before-sudo invariant (T-02-02-03: arch + SHA exit 1 before any sudo cp)

key_files:
  created:
    - vendor/macos/librime.1.dylib.sha256 (1 line, 64 hex + newline)
    - vendor/macos/README.md (~30 lines; provenance + bump procedure)
    - tests/test_install_librime_fork_mac.py (~258 lines; 6 unittest methods)
  modified:
    - scripts/install-librime-fork.sh (+76 lines; env surface + arch refusal + SHA verify)
    - .github/workflows/install-mac-e2e.yml (+20 lines; 2 appended steps)
    - .gitignore (+4 lines; allowlist vendor/macos/{README.md,librime.1.dylib.sha256})

decisions:
  - "D5 honored: SHA256 sidecar source-of-truth (live URL primary, vendored fallback). NO hardcoded hash literal in the script. Test test_no_hardcoded_hash_literal grep-asserts the CP-2 anti-pattern 3 invariant. Live URL is `${RELEASE_URL}.sha256`; vendored fallback is `vendor/macos/librime.1.dylib.sha256` per D10."
  - "D6 honored: arch refusal runs BEFORE SHA256 verify. Line ordering verified at lint time: lipo line 171 < shasum line 213 < first-sudo line 232 (failure-before-sudo invariant). Tests confirm with shim lipo='arm64' + correct sidecar: arch error fires, SHA verify never reached (assertNotIn 'SHA256 verify passed')."
  - "D7 honored: Python `unittest` (matches Phase 1 + tests/test_installers.py). 6 test methods, no pytest dep. Stdlib-only including hashlib + tempfile + subprocess + shutil. Shim PATH dir holds stub `lipo`, `file`, `sudo` so tests run on Linux dev boxes too — same suite serves Phase 1 ci.yml ubuntu fast path AND Phase 2 install-mac-e2e.yml mac slow path."
  - "D9 honored: 4 atomic conventional commits with `feat(02-02)` / `test(02-02)` scope: 466b43c (sidecar), 550d026 (script gate), 9676d49 (tests), 668e6dc (workflow wiring)."
  - "D10 honored: vendor/macos/librime.1.dylib.sha256 is the cross-repo seam. README documents the 'STUB until Phase 5' narrative AND the post-Phase-5 defense-in-depth role (live tag rewrites can wipe live sidecar; vendored copy persists)."
  - "MP-3 verbatim error string: `this is an arm64-only dylib; Intel Mac not supported until universal dylib lands` — matches ROADMAP SC #3 byte-for-byte. Verified by both `grep -F` on the script and the test method's `assertIn`."
  - "Failure-before-sudo invariant (CP-2 + T-02-02-03): both arch refusal AND SHA mismatch exit 1 BEFORE any sudo cp. Test asserts via `assertNotIn 'Copying patched dylib'` on stdout."
  - "Live dylib observation (deviation note): the published asset at smoodle-type/librime tag 1.16.0-smoodle.1 is ALREADY a universal binary (arm64 + x86_64), not arm64-only as the plan narrative anticipated. The arch-refusal gate is still required per ROADMAP SC #3 and is exercised in tests via shim `lipo` returning 'arm64' alone. See Deviations section."

requirements_addressed:
  - "E2EMAC-03: SHA256 verify block in install-librime-fork.sh between download and swap. Sidecar source: live URL primary + vendored fallback. Verified by: (a) grep invariants on the script (`shasum -a 256 \"${BUILT_DYLIB}\"`, `SHA256 mismatch on downloaded dylib`), (b) test_sha_mismatch_exits_before_swap unittest, (c) test_vendored_sidecar_used_when_live_sha_url_404s unittest, (d) workflow's sandboxed step exercises the gate end-to-end on the live runner (Task 4b smoke run)."
  - "E2EMAC-04: install-librime-fork.sh refuses to swap arm64-only dylib onto x86_64 host. Verified by: (a) verbatim ROADMAP SC #3 string `grep -F` invariant in the script, (b) test_arch_refusal_x86_64_against_arm64_only_dylib unittest with shim lipo + SMOODLE_HOST_ARCH_OVERRIDE=x86_64, (c) line-ordering grep enforcing arch BEFORE SHA BEFORE sudo, (d) workflow's sandboxed step exits 0 on the happy arm64 path (Task 4b smoke run)."

verification:
  local_tests:
    - command: "bash -n scripts/install-librime-fork.sh"
      result: "exit 0 — script syntax valid"
    - command: "for f in scripts/install*.sh; do bash -n \"$f\"; done"
      result: "exit 0 — all 5 install*.sh scripts parse cleanly"
    - command: "python3 -m unittest tests.test_schema_lint tests.test_powershell_ascii tests.test_installers"
      result: "76 tests passed, 3 skipped — Phase 1 fast-path baseline preserved exactly"
    - command: "python3 -m unittest tests.test_install_librime_fork_mac"
      result: "6 tests passed — all 6 methods green on Apple Silicon dev box"
    - command: "python3 -c \"import yaml; yaml.safe_load(open('.github/workflows/install-mac-e2e.yml'))\""
      result: "exit 0 — workflow YAML still parses cleanly after Wave 2 additions"
    - command: "tr -d '\\n' < vendor/macos/librime.1.dylib.sha256 | grep -qE '^[a-f0-9]{64}$'"
      result: "exit 0 — sidecar is exactly 64 lowercase hex chars (after newline strip)"
    - command: "Live verify: curl -fsSL <release-url> | shasum -a 256 | awk '{print $1}' against committed sidecar content"
      result: "MATCH — d5723e0de87bc7b73cb38099e9dee2f79b0ec77538c66b83b30dc9161d00be2b"
  greppable_invariants:
    - "grep -F 'this is an arm64-only dylib; Intel Mac not supported until universal dylib lands' scripts/install-librime-fork.sh — exit 0 (ROADMAP SC #3 verbatim)"
    - "grep -q 'lipo -archs' scripts/install-librime-fork.sh — exit 0 (D6 arch detection)"
    - "grep -Fq 'shasum -a 256 \"${BUILT_DYLIB}\"' scripts/install-librime-fork.sh — exit 0 (CP-2 verify call)"
    - "grep -q 'SHA256 mismatch on downloaded dylib' scripts/install-librime-fork.sh — exit 0 (CP-2 error path)"
    - "grep -q 'SMOODLE_HOST_ARCH_OVERRIDE' AND grep -q 'SMOODLE_SHA256_LIVE_URL' AND grep -q 'SMOODLE_SHA256_SIDECAR' scripts/install-librime-fork.sh — all exit 0 (test surface)"
    - "grep -q 'vendor/macos/librime.1.dylib.sha256' scripts/install-librime-fork.sh — exit 0 (sidecar fallback wired)"
    - "Line ordering: awk-index check confirms lipo line 171 < shasum line 213 < first-sudo line 232 (failure-before-sudo invariant)"
    - "grep -q 'bash scripts/install-librime-fork.sh' .github/workflows/install-mac-e2e.yml — exit 0 (workflow step present)"
    - "grep -q 'SMOODLE_SKIP_SWAP: \"1\"' .github/workflows/install-mac-e2e.yml — exit 0 (workflow never sudo's)"
    - "grep -q 'python3 -m unittest tests.test_install_librime_fork_mac' .github/workflows/install-mac-e2e.yml — exit 0 (test step present)"
    - "Step ordering: dict.yaml SHA step (line 79) before install-librime-fork sandboxed step (line 89)"
    - "Wave 1 invariants preserved: runs-on: macos-15 + workflow_dispatch + weekly cron '0 7 * * 1' + GUI-skip verbatim line + paths-filter all still grep-positive"
  live_run_status: "PASSED — push-triggered run 25594460125 on macos-15 (1m 4s wall-time, 9/9 substeps green). Validates ROADMAP SC #1 + #2 + #5; in-workflow Python unittests validate SC #3 + #4 with shim lipo + simulated corruption. Run URL: https://github.com/smoodle-type/smoodle/actions/runs/25594460125"
  live_run_deviation: "[Rule 1 - Bug] First 3 attempts (runs 25591684384, 25591862949, 25594426572) all failed at the brew-cask-install step because Homebrew removed the --no-quarantine flag in 2025 ('There is no replacement'). Fix d4ba9db dropped the flag from both primary and fallback brew commands; quarantine on the cask bundle is harmless because install.sh only copies schema files and the GUI launch path is gated by SMOODLE_GUI_SESSION=0 in CI (CP-4 prevention). Fourth run (25594460125) green."

self_check: PASSED
---

# Phase 2 Plan 02: Lane E1 macOS E2E — SHA256 + arch refusal Summary

**One-liner:** Closes the supply-chain (CP-2) and Intel-Mac (MP-3) gaps in `scripts/install-librime-fork.sh` with an `lipo -archs`-driven arch refusal (verbatim ROADMAP SC #3 error string) followed by a sidecar-sourced `shasum -a 256` verify (live URL primary, vendored fallback secondary), both gating BEFORE any `sudo cp`. Wires the gates into Plan 02-01's `install-mac-e2e.yml` via a sandboxed `SMOODLE_SKIP_SWAP=1` step plus a Python unittest step.

## What was built

### Task 1 — `vendor/macos/librime.1.dylib.sha256` (sidecar) + `vendor/macos/README.md` + `.gitignore` allowlist (commit `466b43c`)

64-character lowercase-hex SHA-256 of the live universal dylib at `smoodle-type/librime` tag `1.16.0-smoodle.1`, computed at execute-time via:

```bash
curl -fsSL <release-url> | shasum -a 256 | awk '{print $1}'
```

Hash: `d5723e0de87bc7b73cb38099e9dee2f79b0ec77538c66b83b30dc9161d00be2b`. Sidecar is the fallback when `${RELEASE_URL}.sha256` 404s — which is the expected state until Phase 5 / HARDEN-04 lands live sidecar emission in `smoodle-type/librime` `release.yml`. README documents provenance, bump procedure, and the post-Phase-5 defense-in-depth role. `.gitignore` mirrors the existing `vendor/windows/rime.dll` allowlist pattern for `vendor/macos/{README.md,librime.1.dylib.sha256}`.

### Task 2 — `scripts/install-librime-fork.sh` arch refusal + SHA verify (commit `550d026`)

Two blocks inserted between the existing `# --- Verify dylib ---` (line 168 — existence + size log) and the `# --- Swap (sudo) ---` divider:

1. **Arch refusal (lines 170-187, MP-3)**: `lipo -archs "${BUILT_DYLIB}"`; `x86_64` host + dylib without `x86_64` slice → `exit 1` with the verbatim ROADMAP SC #3 string. `arm64` host + dylib without `arm64` slice → `exit 1` with a clear "cannot run on Apple Silicon" message. Either pass → `✓ arch check passed` log.
2. **SHA256 verify (lines 189-225, CP-2)**: gated on `_downloaded` (skipped for source-built dylibs since provenance is local). Live URL primary, vendored fallback secondary. Mismatch prints `expected:`, `actual:`, `source:` and exits 1 with a `(CP-2 supply-chain protection)` log. Either no sidecar available OR mismatch → `exit 1` BEFORE the swap section.

New env surface (after `NONINTERACTIVE`):
- `SMOODLE_HOST_ARCH_OVERRIDE` (test hook for Intel-Mac path on arm64 dev boxes)
- `SMOODLE_SHA256_LIVE_URL` (defaults to `${RELEASE_URL}.sha256`; test hook for guaranteed-404)
- `SMOODLE_SHA256_SIDECAR` (defaults to `${REPO_DIR}/vendor/macos/librime.1.dylib.sha256`)

Failure-before-sudo invariant verified at lint time: arch line 171 < shasum line 213 < first-sudo line 232.

### Task 3 — `tests/test_install_librime_fork_mac.py` (commit `9676d49`)

Python `unittest` module, 258 lines, 6 test methods (4 minimum required by plan):

1. `test_arch_refusal_x86_64_against_arm64_only_dylib` — REQ E2EMAC-04 / SC #3 verbatim string + `assertNotIn 'Copying patched dylib'` + `assertNotIn 'SHA256 verify passed'` (arch fires before SHA).
2. `test_sha_mismatch_exits_before_swap` — REQ E2EMAC-03 / SC #4 with bogus all-zero sidecar; asserts both expected and actual hashes appear in output (T-02-02-04 accepted disposition); arch check log present (it ran first).
3. `test_vendored_sidecar_used_when_live_sha_url_404s` — live URL forced to `file:///nonexistent/...` (guaranteed 404), vendored sidecar holds correct hash; asserts `'vendored fallback'` log marker + `'SHA256 verify passed'` + exit 0 under `SMOODLE_SKIP_SWAP=1`.
4. `test_sidecar_fixture_format_strict` — committed `vendor/macos/librime.1.dylib.sha256` is `^[a-f0-9]{64}$` after strip.
5. `test_script_declares_new_env_surface` — all 3 new env vars referenced in the script.
6. `test_no_hardcoded_hash_literal` — CP-2 anti-pattern 3 grep-test: no `^[A-Z]*HASH[A-Z]*=<64hex>` literal embedded.

Test harness via shim PATH directory holding stub `lipo` (controllable arch string), stub `file` (forces Mach-O magic line so the script's `file | grep Mach-O` post-download check passes regardless of fixture bytes), stub `sudo` (defense-in-depth no-op so an accidental swap-path reach during regression doesn't escalate). Test fixtures use `file://` URLs through curl — works on both macOS and Linux dev boxes.

### Task 4a — `.github/workflows/install-mac-e2e.yml` Wave 2 wiring (commit `668e6dc`)

Two new steps APPENDED to the existing `install-mac` job (no existing step modified):

1. **Run install-librime-fork.sh sandboxed (SHA + arch gate exercised)** — `env: SMOODLE_SKIP_SWAP: "1", SMOODLE_NONINTERACTIVE: "1"` + `run: bash scripts/install-librime-fork.sh`. Exercises the gate end-to-end on the live `macos-15` runner without sudo. Hash provenance: live URL primary (404 expected until Phase 5 lands live sidecar), vendored fallback secondary. ROADMAP SC #4's "exit 1 before any sudo cp executes" is operationally verified by this step — `SKIP_SWAP=1` prevents sudo regardless of failure path.
2. **Run install-librime-fork tests (E2EMAC-03, E2EMAC-04)** — `run: python3 -m unittest tests.test_install_librime_fork_mac`. All 6 methods exercised on the runner.

Step ordering preserved: checkout → runner identity → brew Squirrel → Run E2E driver → GUI-gate skip-line assertion → Verify dict.yaml SHA → **NEW: install-librime-fork.sh sandboxed** → **NEW: install-librime-fork tests**. Wave 1 invariants intact: `runs-on: macos-15`, all 4 triggers (push paths-filter + pull_request paths-filter + workflow_dispatch + weekly cron `'0 7 * * 1'`), GUI-skip verbatim line preserved.

## Deviations from plan

**[Rule 1 - Factual correction] Live dylib is already universal (arm64 + x86_64), not arm64-only.** The plan narrative — `cross_repo_prereq.description`, the README boilerplate, the SC #3 framing in `must_haves.truths` — anticipated `librime-1.16.0-smoodle.1-macOS-universal.dylib` being arm64-only at execute time, treating the universal join as Phase 5 / HARDEN-03 work. Live observation at execute time: `lipo -archs` returns `x86_64 arm64` on the published asset. The arch-refusal gate is still required by ROADMAP SC #3 (the gate is independent of current asset state — protects against future regressions and tag rewrites that could revert to single-arch). Tests exercise the failure path via a shim `lipo` that returns `arm64` alone with `SMOODLE_HOST_ARCH_OVERRIDE=x86_64`. The vendored sidecar holds the universal-binary hash; the README narrative was authored to acknowledge this rather than carrying through the stale "arm64-only" framing. No code or test change required from this discovery — only narrative truth-up. Logged in commit `466b43c` body. **Action for plan-author: update Phase 5 / HARDEN-03 plan-checker scope — universal-dylib build may already be done, only `release.yml` live-sidecar emission remains.**

**[Rule 3 - Blocking issue auto-fix] `.gitignore` blocked `vendor/macos/`.** The repo's `.gitignore` had `vendor/*` with allowlist exceptions only for `vendor/*.patch`, `vendor/README.md`, `vendor/windows/`, and `vendor/windows/rime.dll`. Plan 02-02's `provides:` block requires committing `vendor/macos/librime.1.dylib.sha256` — `git add` failed with the ignored-paths advisory. Auto-fixed by mirroring the existing `vendor/windows/` allowlist pattern: added 4 lines (`!vendor/macos/`, `vendor/macos/*`, `!vendor/macos/README.md`, `!vendor/macos/librime.1.dylib.sha256`). Single coherent commit with the sidecar (`466b43c`). No deviation from plan intent — the plan implicitly required this; just an unflagged prerequisite.

**[Rule 1 - Test harness fix] `SMOODLE_SKIP_BUILD=1` short-circuited the download path.** First test run failed because the script's line 74 condition is `if [ "${SKIP_DOWNLOAD}" != "1" ] && [ "${SKIP_BUILD}" != "1" ]` — both must be 0 for the download block to run. With `SKIP_BUILD=1` set as a test default, the script bypassed the download branch entirely, leaving `_downloaded=""` so the SHA verify block ran the "skipped (source-built dylib)" branch. Removed `SMOODLE_SKIP_BUILD` from `_run_script`'s default env and documented the reason inline. The file:// fixture URL ensures the download succeeds, which sets `_downloaded=1` and prevents the source-build branch from ever running (gated on `[ -z "${_downloaded}" ]`). All 6 tests then green on first re-run. Not a script bug — a test-harness misconfiguration on first author. Documented in test docstring.

**No other deviations.** All locked decisions (D5/D6/D7/D9/D10, MP-3 verbatim string, failure-before-sudo invariant) honored exactly as the plan specified.

## Cross-repo seam status

**STUB-IN-PHASE-2 / FULL-IN-PHASE-5** — `vendor/macos/librime.1.dylib.sha256` is the cross-repo seam. Current state: vendored copy is the source of truth (live `${RELEASE_URL}.sha256` returns 404 because `smoodle-type/librime` `release.yml` does not yet emit `.sha256` sidecar assets). Phase 5 / HARDEN-04 ships:

1. `release.yml` change in `smoodle-type/librime` to emit live `.sha256` sidecars on every release.
2. After live sidecar exists, vendored copy persists as defense-in-depth — tag rewrites (`gh release upload --clobber`) can wipe the live sidecar; the vendored copy is the immutable record.

Phase 5 plan-phase MUST update `vendor/macos/README.md` to reflect "live sidecar primary, vendored fallback secondary" once HARDEN-04 lands. The `install-librime-fork.sh` code path already works correctly under both states (live URL primary, fallback secondary) without modification.

## Pending: human-verify gate (Task 4b)

Task 4b is `type="checkpoint:human-verify"` — the live `workflow_dispatch` smoke run on `macos-15`. ROADMAP Phase 2 SC #1 ("workflow exits green on a fresh macos-15 runner") cannot be observationally confirmed without running the workflow once; greppable invariants alone don't substitute for a live runner. Phase 1 Plan 01-02's smoke-test gate is the precedent (4 GHA runs ≤21s, smoke-then-approve).

**Status:** All pre-checkpoint commits pushed to `origin/main` (push of 4 commits `466b43c..668e6dc` confirmed). The `paths:` trigger fires on `scripts/install*.sh` changes, so the push commit set has likely already triggered an automatic run on `main` — the workflow_dispatch smoke is for explicit user-triggered verification on top of that.

**Awaiting orchestrator/user action.** When approved with run-id, this SUMMARY will be finalized with:
- Live run ID + duration + step-by-step pass log
- ROADMAP SC #1-#5 final close
- Cross-repo seam re-confirmation
- "What this enables for downstream" (Phase 5 Lane S, Phase 3 Lane E2 Windows mirror)

## Self-Check (pre-checkpoint subset): PASSED

| Check | Status |
|---|---|
| 4 atomic commits with `feat(02-02)`/`test(02-02)` scope | ✓ (`466b43c`, `550d026`, `9676d49`, `668e6dc`) |
| Sidecar exists, 64 lowercase hex, live-verified | ✓ (`d5723e0de87bc7b73cb38099e9dee2f79b0ec77538c66b83b30dc9161d00be2b`) |
| `install-librime-fork.sh` syntax valid + new env surface present | ✓ (`bash -n` exit 0; all 3 vars referenced) |
| Verbatim MP-3 / SC #3 error string | ✓ (`grep -F` exit 0 on script + tests) |
| Failure-before-sudo invariant (line ordering) | ✓ (arch=171 < sha=213 < sudo=232) |
| 6 unittest methods green locally | ✓ (`python3 -m unittest tests.test_install_librime_fork_mac` exits 0) |
| Phase 1 baseline preserved | ✓ (76 pass / 3 skip — identical to Plan 02-01 SUMMARY baseline) |
| Workflow YAML parses + 2 new steps appended after dict.yaml SHA step | ✓ (`yaml.safe_load` exit 0; ordering 79 < 89) |
| Wave 1 invariants intact (macos-15 + 4 triggers + GUI-skip verbatim) | ✓ (all greps exit 0) |
| All 4 commits pushed to origin/main | ✓ (`a2709da..668e6dc`) |
| Task 4b is checkpoint:human-verify | PENDING (awaiting live workflow_dispatch run-id) |

---

*Plan 02-02 pre-checkpoint complete: 2026-05-09. Wave 2 of Phase 2 Lane E1 commits landed; awaiting Task 4b human-verify gate to close the plan.*
