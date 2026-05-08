# Coding Conventions

**Analysis Date:** 2026-05-08

## Naming Patterns

**Files:**
- Bash scripts: `kebab-case.sh` — e.g. `install.sh`, `install-librime-fork.sh`, `install-linux.sh`, `build-macos-dmg.sh`, `dev-sync-windows.sh`, `init_rime_testdir.sh`. Mixed: most use kebab-case; `init_rime_testdir.sh` and `generate_dict.py` / `generate_words.py` / `merge_dict.py` use snake_case (Python-style for `.py`, anomaly for one `.sh`).
- PowerShell scripts: `kebab-case.ps1` — e.g. `install-windows.ps1`, `install-librime-fork.ps1`. Same family/verb structure as the Bash siblings (one-to-one Lane B parallels).
- Python scripts: `snake_case.py` — `generate_dict.py`, `merge_dict.py`, `generate_words.py`, `tests/test_dict.py`, `tests/test_installers.py`.
- YAML schemas: dotted, lowercase — `thai_phonetic.schema.yaml`, `thai_phonetic.dict.yaml`, `default.custom.yaml`. The `<schema_id>.schema.yaml` / `<schema_id>.dict.yaml` / `<name>.custom.yaml` shape is Rime convention; smoodle inherits it as-is.
- Test fixtures: `v<NN>_fixture.yaml` — `tests/v001_fixture.yaml`, `tests/v01_fixture.yaml`. Version baked into the filename.
- Docs: `UPPERCASE-WITH-DASHES.md` for prompts/plans (`PHASE1-PROMPT.md`, `RESUME.md`, `LANE-B-WINDOWS.md`); root-level `README.md`, `LICENSE`, `TODOS.md`.

**Bash functions:**
- `snake_case` — `run_with_timeout`, `detect_running_im`. Underscore prefix `_` for cleanup helpers and intentionally-private locals (`_cleanup`, `_tmp_dylib`, `_downloaded`, `_ASSET_NAME`).

**Bash variables:**
- `UPPER_SNAKE_CASE` for script-level constants and env-derived config — `SMOODLE_DIR`, `RIME_DIR`, `SQUIRREL_PATH`, `DEPLOY_TIMEOUT_SECS`, `BREW_DEPS`.
- `lower_snake_case` for loop locals and within-block temporaries — `auto_deploy_ok`, `missing_deps`, `size_kb`, `current`, `expected`, `head_sha`.
- All env-override knobs are namespaced with the `SMOODLE_` prefix — `SMOODLE_RIME_DIR`, `SMOODLE_SQUIRREL_PATH`, `SMOODLE_AUTO_DEPLOY`, `SMOODLE_DEPLOY_TIMEOUT_SECS`, `SMOODLE_LIBRIME_FORK_TAG`, `SMOODLE_SKIP_DOWNLOAD`, `SMOODLE_NONINTERACTIVE`, etc. Tests set these to sandbox the script.

**PowerShell variables:**
- `$PascalCase` for script-level config — `$ScriptDir`, `$SmoodleDir`, `$RimeDir`, `$WeaselPath`, `$DeployTimeoutSecs`, `$AutoDeploy`, `$SchemaFiles`.
- `$camelCase` for loop locals — `$schemasChanged`, `$deployerExe`, `$autoDeployOk`, `$srcHash`, `$dstHash`, `$copyOk`.
- Same `$env:SMOODLE_*` namespacing as Bash for env overrides.

**Python:**
- Modules / files: `snake_case`.
- Functions: `snake_case` — `generate_variants`, `parse_fixture`, `query_rime`, `read_words`, `merge`, `reweight_by_freq`. Underscore-prefixed for private helpers — `_run_installer`, `_generate_with_retry`, `_run_helper`, `_CANDIDATE_LINE`.
- Classes: `PascalCase` — `InstallScriptShape`, `InstallSandboxed`, `TimeoutHelper`, `FutureLanes`, `Assertion`. Test classes describe a coverage area, not a "TestX" pattern.
- Test methods: `test_<action>_<expected>` — `test_install_sh_syntax_valid`, `test_copies_all_three_yamls`, `test_idempotent_with_timestamped_backup`, `test_returns_124_on_timeout`.
- Constants: `UPPER_SNAKE_CASE` — `REPO_ROOT`, `INSTALL_SH`, `SCHEMA_FILES`, `DEFAULT_FIXTURE`, `SYSTEM_PROMPT`, `VARIANTS_SCHEMA`, `FRONTMATTER`.

**YAML:**
- Top-level keys are Rime-defined: `schema:`, `engine:`, `speller:`, `translator:`, `switches:`, `punctuator:`, `key_binder:`, `recognizer:` (in `thai_phonetic.schema.yaml`); `name:`, `version:`, `sort:`, `columns:`, `encoder:` (in `thai_phonetic.dict.yaml`); `patch:` (in `default.custom.yaml`).
- `schema_id`: `thai_phonetic` (snake_case, must match dict `name:`).
- Human-facing `name:` uses spaces: `"smoodle Thai phonetic"`.
- Versions are SemVer-ish, double-quoted strings: `version: "0.0.6"`. Bump in BOTH `thai_phonetic.schema.yaml` and `thai_phonetic.dict.yaml` together; current source-of-truth is `0.0.6`.

## Code Style

**Formatting:**
- No automated formatter is configured for any language in this repo (no `.prettierrc`, no `pyproject.toml` `[tool.black]` / `[tool.ruff]`, no `.editorconfig`, no `shfmt` config). Style is hand-maintained.
- Indentation: 2 spaces in Bash and YAML; 4 spaces in Python and PowerShell.
- Line length: soft ~80 chars in scripts, ~100 chars in Python (no enforcement).

**Linting:**
- No linter is configured. Bash files are syntax-checked at test time via `bash -n` inside `tests/test_installers.py` (`test_install_sh_syntax_valid`, `test_script_syntax_valid`). PowerShell files have only structural / regex shape checks because `pwsh` is not on the macOS dev box; real syntax validation happens when the script runs in the Lane B test bed VM.

## Bash Style

**Strict mode (mandatory):**
- Every Bash script starts with `set -euo pipefail` immediately after the shebang + comment block. Verified in `scripts/install.sh:8`, `scripts/install-librime-fork.sh:31`, `scripts/install-linux.sh:17`, `scripts/build-macos-dmg.sh:16`, `scripts/init_rime_testdir.sh:10`, `scripts/dev-sync-windows.sh:17`. Add this line in every new shell script.

**Shebang:**
- `#!/usr/bin/env bash` (portable). Never `#!/bin/bash`.

**Header comment block:**
- Every script opens with a multi-line `#`-prefixed header that includes:
  1. One-line purpose.
  2. Short paragraph describing what it does and why (often referencing a "Critical Failure Mode" or commit-pinned design decision).
  3. `Usage:` line(s) with copy-pasteable invocations.
  4. `Env overrides:` block listing every `SMOODLE_*` knob with default and effect.
- Example template at `scripts/install-librime-fork.sh:1-29`.

**Path resolution:**
- Scripts derive their repo root via `"$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"` and assign to `SMOODLE_DIR` / `REPO_DIR`. Never use `$0` / `$PWD` for repo paths — they break when the script is sourced or invoked from another cwd.

**Env-override pattern:**
- Each tunable uses the `${VAR:-default}` form so callers (mostly tests) can override without editing the script:
  ```bash
  RIME_DIR="${SMOODLE_RIME_DIR:-${HOME}/Library/Rime}"
  AUTO_DEPLOY="${SMOODLE_AUTO_DEPLOY:-1}"
  DEPLOY_TIMEOUT_SECS="${SMOODLE_DEPLOY_TIMEOUT_SECS:-10}"
  ```
- "Skip" knobs use `SMOODLE_SKIP_<X>` → `"1"` to skip — `SMOODLE_SKIP_DOWNLOAD`, `SMOODLE_SKIP_BUILD`, `SMOODLE_SKIP_SWAP`. Tested via `if [ "${SKIP_X}" != "1" ]; then ... fi`.

**Quoting:**
- Always quote `${VAR}` expansions — `"${RIME_DIR}/${f}"`, `"${dst}"`, `"${SQUIRREL_PATH}"`. Defends against paths with spaces (e.g. `/Library/Input Methods/Squirrel.app`).
- Curly-brace form `${VAR}` is preferred over bare `$VAR` even when not strictly required.

**Section headers in scripts:**
- Long scripts use comment banners to separate phases:
  ```bash
  # --- Pre-flight: verify Squirrel host present -------------------------------
  # --- Copy schema YAMLs (idempotent, with timestamped backup) ----------------
  # --- Post-copy verification: all three YAMLs must exist at destination ------
  # --- Attempt auto-deploy: kill Squirrel + restart (timeout-bounded) ---------
  # --- Test instructions (post-install verification by user) ------------------
  ```
- Banner ends with hyphens padding to ~78 columns. Use this pattern in any new installer.

**Heredocs:**
- Closing instructions to the user are emitted via `cat <<'EOF' ... EOF` (single-quoted EOF) to suppress variable expansion when not needed, or `cat <<EOF ... EOF` when expansion IS needed (e.g. interpolating `${SQUIRREL_PATH}` into the trailer in `scripts/install.sh:120`).

## PowerShell Style

**Header block:**
- Every `.ps1` opens with a `<# .SYNOPSIS / .DESCRIPTION / .EXAMPLE / .NOTES #>` comment-based help block. See `scripts/install-windows.ps1:1-39` and `scripts/install-librime-fork.ps1:1-50`.

**Boilerplate:**
- After the help block, every script has:
  ```powershell
  [CmdletBinding()]
  param()

  $ErrorActionPreference = 'Stop'
  ```
- `$ErrorActionPreference = 'Stop'` is the PowerShell analog of `set -e`; without it cmdlet errors only emit warnings.

**ASCII-only:**
- `.ps1` files MUST be ASCII (no em-dashes, smart quotes, or Thai script). PowerShell 5.1 on Windows reads files as Windows-1252 by default and a single non-ASCII byte raises a parse error. See commit `418c7ce` ("fix: replace em-dashes and Thai chars in .ps1 files (PS5.1 Windows-1252 parse error)"). Use `-` and `'` not `—` / `"`. Bash scripts can use UTF-8 freely.

**Inline detection (no forward function calls):**
- PowerShell 5.1 executes top-to-bottom; calling a function defined later in the same script raises `CommandNotFoundException`. Detection logic that runs early (e.g. `$WeaselPath` probe) is inlined in the script body, not factored into a function. The test `test_script_auto_detects_weasel_path` in `tests/test_installers.py:284-296` enforces this with `assertNotIn("Find-WeaselPath", body)`.

**winget invocations:**
- Always pass `--accept-source-agreements --accept-package-agreements`.
- Use `--interactive` for installers known to hang on `--silent` (Inno Setup-based packages like Weasel — see `scripts/install-windows.ps1:117` and the inline note documenting the 2026-05-07 hang on `--silent`).
- Use `--silent` for headless tools (gh CLI, 7-Zip — see `scripts/install-librime-fork.ps1:143`).

## Python Style

**Shebang + future imports:**
- `#!/usr/bin/env python3` shebang, followed by a module-level docstring, followed by `from __future__ import annotations` to enable PEP 604 union syntax (`str | None`) in 3.10+. Every Python file in the repo uses this pattern.

**Module docstrings:**
- Triple-quoted block at file top: one-line summary, blank line, multi-paragraph description, then `Usage:` / `Requirements:` / `Exit codes:` sections. See `scripts/generate_dict.py:1-31`, `scripts/merge_dict.py:1-26`, `tests/test_dict.py:1-34`, `tests/test_installers.py:1-33`.

**Imports:**
- Order: `from __future__ import annotations`, blank line, third-party (e.g. `import anthropic`), stdlib alphabetical, then project-local. Example at `scripts/generate_dict.py:33-41`.
- No `isort` config — order is by hand but consistent across files.

**Stdlib-only for tests:**
- `tests/test_dict.py` and `tests/test_installers.py` use ONLY the stdlib (`unittest`, `subprocess`, `pathlib`, `re`, `tempfile`, `shutil`, `time`). No `pytest` dependency, no `requirements-test.txt`. Anyone with Python 3.10+ can run the tests with no `pip install`.
- Driver scripts (`generate_dict.py`, `generate_words.py`) DO depend on `anthropic` — install via `pip install anthropic` per their docstrings.

**Type hints:**
- Used where they aid clarity but not strictly enforced. Common patterns: `from pathlib import Path`, `list[dict]`, `dict[str, int]`, `OrderedDict[str, dict[str, int]]`, `str | None`. `NamedTuple` for structured records (`Assertion` in `tests/test_dict.py:53`).

**argparse:**
- All Python entry points use `argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)` so `--help` reproduces the module docstring verbatim. See `scripts/generate_dict.py:182-214`, `scripts/merge_dict.py:188-205`, `tests/test_dict.py:211-229`.

**Exit codes:**
- `main()` returns an `int`; `if __name__ == "__main__": raise SystemExit(main())` (preferred) or `sys.exit(main())`. Documented exit codes in the module docstring: `0` success, `1` test failure, `2` environment / setup error.

**unittest patterns:**
- Subclass `unittest.TestCase`, use `self.assertEqual`, `self.assertTrue`, `self.assertIn`, `self.assertNotIn`, `self.assertNotEqual`. Never `assert` (silently disappears under `python -O`).
- Setup: `setUp` / `tearDown` for per-test sandbox (see `InstallSandboxed` in `tests/test_installers.py:447-464`); `setUpClass` for one-time fixture extraction (see `TimeoutHelper.setUpClass` at `tests/test_installers.py:533`).
- Skips: `@unittest.skip("reason")` decorator; reason string explains WHY (and when the skip becomes a real test). See `FutureLanes` class at `tests/test_installers.py:567-596`.
- Test classes group by surface (one class per script being tested). Method count per class: 5-15.

## YAML / Schema Conventions

**Encoding declaration:**
- Every Rime YAML opens with `# encoding: utf-8` as a comment, even though YAML is UTF-8 by default. Mirrors librime's bundled examples.

**Header comment block:**
- Schema/dict YAMLs lead with a multi-version changelog comment block before any YAML data. Each version (v0.0.1 … v0.0.6) gets a paragraph documenting the dict-size delta and the weight scheme decisions tied to it. See `schema/thai_phonetic.dict.yaml:1-29` and `schema/thai_phonetic.schema.yaml:14-46`.

**Two-document Rime native dict format:**
- `thai_phonetic.dict.yaml` is a two-document YAML: frontmatter (`name`, `version`, `sort`, `columns`, `encoder`) terminated by `...`, followed by tab-separated `<thai>\t<romanization>\t<weight>` rows. PyYAML can't parse the body cleanly, so smoodle parses line-by-line in `tests/test_dict.py:94-125` and `scripts/merge_dict.py:106-117`.
- The frontmatter template lives in `scripts/merge_dict.py:42-86` (constant `FRONTMATTER`); regenerating the dict re-emits this block verbatim. When bumping schema/dict version, edit BOTH the constant and `schema/thai_phonetic.schema.yaml:12`.

**Algebra rule comments:**
- Every `derive/X/Y/` line in `speller.algebra` is annotated with a `# ===== <Category> =====` banner and a 2-3 line rationale paragraph. See `schema/thai_phonetic.schema.yaml:84-110`. New algebra rules MUST carry the same explanatory comment.

**Schema versioning:**
- `version: "0.0.6"` (double-quoted string) appears in three places that must be kept in sync:
  1. `schema/thai_phonetic.schema.yaml:12` — `schema.version`
  2. `schema/thai_phonetic.dict.yaml:34` — top-level `version`
  3. `scripts/merge_dict.py` — `FRONTMATTER` constant string

## Error Handling

**Bash:**
- Pre-flight checks emit `echo "ERROR: ..."` (stdout in `install.sh`, stderr `>&2` in `install-linux.sh:47-58`) followed by `exit 1`.
- Error messages prescribe the fix on the next line:
  ```bash
  echo "ERROR: Squirrel.app is not installed at ${SQUIRREL_PATH}."
  echo "       Install it first:  brew install --cask squirrel-app"
  exit 1
  ```
- Soft failures (auto-deploy timeout) downgrade to `⚠` warning + manual fallback instructions, not `exit 1`. See `scripts/install.sh:111-117`.
- Timeouts use the bespoke `run_with_timeout` perl wrapper (`scripts/install.sh:22-38`) because macOS lacks GNU `timeout`. Returns 124 on timeout (matches GNU convention).

**PowerShell:**
- Hard errors: `Write-Error "..."` (raises with `$ErrorActionPreference = 'Stop'`) followed by `exit 1`. Soft warnings: `Write-Host "  [WARN] ..."`.
- Status messages use bracketed tags: `[OK]`, `[WARN]`, `[SKIP]`. ASCII only — emoji and unicode arrows break PS5.1 parsing.
- Exit codes from external tools are checked via `if ($LASTEXITCODE -ne 0)` immediately after the `&` invocation. See `scripts/install-windows.ps1:118-122`.

**Python (driver scripts):**
- One-shot CLI errors: `sys.exit(f"ERROR: ...")` exits with code 1 and prints to stderr.
- API errors in `generate_dict.py` are caught per-word so one failure doesn't kill a 500-word run (`_generate_with_retry` at `scripts/generate_dict.py:293-318`). The Anthropic SDK's built-in retry (default `max_retries=2`) handles 429/5xx; smoodle re-raises other errors.

**Python (tests):**
- Tests fail with `self.assertX(...)` assertions. Sandbox setup failures (`setUp` exceptions) are caught by `unittest` and reported per-test. Helper functions like `_run_installer` (`tests/test_installers.py:62-76`) raise `AssertionError` with combined stdout+stderr in the message so failures are debuggable from the test runner output alone.

## Logging

**Bash / PowerShell:**
- No structured logging framework. Plain `echo` / `Write-Host`. The convention is "human-readable progress narration": each phase prints a one-line marker, success printed as `✓` or `[OK]`, soft failure as `⚠` or `[WARN]`, hard error as `ERROR:` + fix.
- Bash uses unicode `✓` / `⚠` / `→` freely; PowerShell does not (PS5.1 Windows-1252 constraint).

**Python:**
- Driver scripts use `print(..., file=sys.stderr)` for progress (see `scripts/generate_dict.py:228-289`); stdout is reserved for machine-readable output (TSV rows). This separation lets `python ... > out.tsv 2> progress.log` work cleanly.
- Tests use the unittest runner's verbosity (`unittest.TextTestRunner(verbosity=2)` at `tests/test_installers.py:658`).

## Comments

**When to comment:**
- Document WHY, not WHAT. The codebase is dense with rationale comments tying decisions to specific commits, dates, or empirical findings:
  - `scripts/install-windows.ps1:56-61` — explains the versioned `weasel-*` subdir discovery dated 2026-05-07.
  - `scripts/install-windows.ps1:110-116` — explains why `--silent` is NOT used for Weasel's winget install.
  - `scripts/install-librime-fork.ps1:46-50` — explains why the script downloads instead of building.
  - `tests/test_installers.py:144-148` — explains why `glog` matters specifically.
- Critical-path constants reference the commit / date / "Critical Failure Mode" that motivated them.

**Inline rationale style:**
- Use 2-3 line paragraphs, broken at ~78 cols, prefixed with `# `. Group multi-line comment blocks above the line they describe, not trailing.

## Function Design

**Bash:**
- Few functions. Most scripts are linear top-to-bottom. Exceptions: helpers that genuinely need encapsulation (`run_with_timeout` for the perl wrapper, `detect_running_im` for IM autodetection). Cleanup helpers use `_underscore` prefix.
- Args: positional `$1`, `$2`, … with `local var="$1"; shift` near the top so the body reads symbolically.

**PowerShell:**
- Functions are rare and only used when truly reusable (`Ensure-WingetTool` in `scripts/install-librime-fork.ps1:130-156`). Inline code preferred (PS5.1 forward-call constraint).

**Python:**
- Small, single-purpose functions. Test helper `_run_installer` at `tests/test_installers.py:62-76` is the canonical shape: takes env overrides + an `expect_success` flag, runs the subprocess with a 30s timeout, raises with combined output on unexpected non-zero exit.
- Keyword-only arguments (`*` separator) when there are 4+ params and order would be confusing — see `scripts/generate_dict.py:113-118`.

## Module Design

**Python:**
- Each `scripts/*.py` is a runnable CLI module — `main()` returns `int`, `if __name__ == "__main__": raise SystemExit(main())`.
- No package layout (no `__init__.py`, no `setup.py`, no `pyproject.toml`). Scripts are run directly: `python3 scripts/generate_dict.py ...` or `python3 tests/test_installers.py`.
- No shared library code — each script is self-contained. Constants like `REPO_ROOT = Path(__file__).resolve().parent.parent` are duplicated rather than imported.

## Commit Message Style

**Tag prefixes (no enforced convention; observed patterns):**
- `vX.Y.Z:` — version-bump commits that change schema/dict content. Examples: `v0.0.6: close 25-word gap (now 100% of TNC freq>=50)`, `v0.0.5: finish TNC freq>=50 tail (14868 words / 28187 entries)`, `v0.0.8: Lane A DMG builder + download-first librime installer`. Bumps trigger schema version updates in the YAMLs.
- `chore:` — repo housekeeping. Example: `chore: update LoneExile/* references to smoodle-type/* org`.
- `fix:` — bug fixes. Examples: `fix: replace em-dashes and Thai chars in .ps1 files (PS5.1 Windows-1252 parse error)`, `fix: indentation error from TSF test removal`, `fix(stub): drop space from ขอบคุณ romanizations`. Optional `(scope)` after `fix`.
- `docs:` — doc-only changes. Example: `docs: add LANE-C-E2E-PROMPT.md for next session`.
- `<file>:` — single-file scoped changes. Examples: `install-windows.ps1: drop --silent on Weasel auto-install`, `RESUME.md: refresh for v0.0.4 + capture v0.0.5 backlog`, `install-librime-fork.sh: fix annotated-tag comparison`.
- `Lane B:` / `Lane C:` / `Lane A` — milestone-tagged commits during multi-script feature work. Example: `Lane B: scripts/install-librime-fork.ps1`, `Lane C scaffold: install-linux.sh + InstallLinuxScriptShape tests`.
- `TODO N <verb>:` / `TODOS:` — TODO tracking commits. Examples: `TODO 7 ✓ CLOSED: Lane B Windows smoke green — sawatd -> สวัสดี`, `TODOS.md: close TODO 8 (Lane C GHA E2E green, run 25480673681)`, `TODOS: defer TODO 1, kick off Lane B test bed + Lane B/C TODOs`. The `✓ CLOSED` ASCII-checkmark suffix marks completion.
- `Phase N:` — phase milestone closure. Example: `Phase 0: CLOSED — self-only dogfood, status flips to APPROVED`, `Phase 1 kickoff: harden install.sh + scaffold installer tests`.

**First-line rules:**
- Imperative mood ("close", "drop", "add", "fix", "update") — never past tense.
- Keep under ~80 chars. Em-dashes (`—`) and unicode are fine in commit messages (only `.ps1` files have the ASCII constraint).
- Trailing context after `—` is common: `v0.0.4: scale dict to 10257 Thai words (5x expansion)`, `Phase 0: CLOSED — self-only dogfood, status flips to APPROVED`.

**Body:**
- Most commits are subject-line only. Multi-line bodies are reserved for non-trivial changes or when explaining the WHY needs > 80 chars. No strict format enforcement.

---

*Convention analysis: 2026-05-08*
