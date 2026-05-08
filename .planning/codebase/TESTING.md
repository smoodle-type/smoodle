# Testing Patterns

**Analysis Date:** 2026-05-08

## Test Framework

**Runner:**
- Python `unittest` (stdlib). No `pytest` dependency anywhere in the repo. The decision is intentional: `tests/test_installers.py:27` calls out "Stdlib only — matches tests/test_dict.py style. No pytest dep." The `.pytest_cache/` directory in the repo root is incidental (left by a developer running `pytest` ad-hoc) and is gitignored via `.gitignore:31`.
- No config file: no `pytest.ini`, no `pyproject.toml`, no `tox.ini`, no `setup.cfg`. Tests are discovered and run via the unittest CLI.
- Tests live in `tests/` at the repo root.

**Assertion library:**
- `unittest.TestCase` methods only — `self.assertEqual`, `self.assertTrue`, `self.assertFalse`, `self.assertIn`, `self.assertNotIn`, `self.assertNotEqual`, `self.skipTest(...)`, `@unittest.skip("reason")`. No bare `assert` statements (would silently no-op under `python -O`).

**Run commands:**
```bash
# Full installer suite (the primary test surface — 56 active + 3 skipped)
python3 tests/test_installers.py

# Or via the unittest CLI (same result, slightly more concise output)
python3 -m unittest tests.test_installers

# Individual test class
python3 -m unittest tests.test_installers.InstallSandboxed

# Individual test method
python3 -m unittest tests.test_installers.InstallSandboxed.test_idempotent_with_timestamped_backup

# Schema/dict correctness — fast string-match mode
python3 tests/test_dict.py --fixture tests/v01_fixture.yaml

# Schema/dict correctness — full engine mode (needs vendored librime built)
bash scripts/init_rime_testdir.sh                                       # one-time
python3 tests/test_dict.py --use-rime-api-console --fixture tests/v01_fixture.yaml
```
- Engine-mode fixture target: `PASS 56/56` (35 direct + 21 algebra-tagged).
- Installer-mode actual: `Ran 59 tests in ~5s. OK (skipped=3)` → 56 passing + 3 skipped (verified 2026-05-08).

## Test File Organization

**Location:**
- Separate `tests/` directory at the repo root, not co-located with sources. There are only two test modules so the directory is flat.

**Files:**
```
tests/
├── test_dict.py            # 285 lines — Rime schema/dict correctness
├── test_installers.py      # 665 lines — installer scripts (Bash + PowerShell)
├── v001_fixture.yaml       # legacy 30-entry fixture (v0.0.1 era)
├── v01_fixture.yaml        # active 50-entry fixture (35 direct + 15 algebra)
└── __pycache__/            # gitignored (.gitignore:32)
```

**Naming:**
- Test modules: `test_<surface>.py` (`test_dict.py`, `test_installers.py`).
- Fixtures: `v<NN>_fixture.yaml` (version baked into the filename so old fixtures stay reproducible alongside the dict changes that broke them).
- Test classes group by script-being-tested: `InstallScriptShape` for `install.sh`, `InstallLibrimeForkScriptShape` for `install-librime-fork.sh`, `InstallLinuxScriptShape` for `install-linux.sh`, `InstallWindowsPs1Shape` for `install-windows.ps1`, `InstallLibrimeForkPs1Shape` for `install-librime-fork.ps1`, `BuildMacosDmgScriptShape` for `build-macos-dmg.sh`. Plus cross-cutting classes: `InstallSandboxed` (e2e), `TimeoutHelper` (extracted-helper unit), `FutureLanes` (skip stubs).
- Test methods: `test_<aspect>_<expected>` — `test_install_sh_syntax_valid`, `test_copies_all_three_yamls`, `test_idempotent_with_timestamped_backup`, `test_returns_124_on_timeout`, `test_script_auto_detects_weasel_path`.

## Test Structure

**Suite organization (canonical pattern from `tests/test_installers.py:642-660`):**
```python
def main() -> int:
    if not INSTALL_SH.is_file():
        print(f"FAIL  install.sh missing at {INSTALL_SH}", file=sys.stderr)
        return 2
    for f in SCHEMA_FILES:
        if not (SCHEMA_DIR / f).is_file():
            print(f"FAIL  schema source missing: {SCHEMA_DIR / f}", file=sys.stderr)
            return 2

    loader = unittest.TestLoader()
    suite = unittest.TestSuite()
    for cls in (InstallScriptShape, InstallLibrimeForkScriptShape,
                InstallLinuxScriptShape, InstallWindowsPs1Shape,
                InstallLibrimeForkPs1Shape, BuildMacosDmgScriptShape,
                InstallSandboxed, TimeoutHelper, FutureLanes):
        suite.addTests(loader.loadTestsFromTestCase(cls))
    runner = unittest.TextTestRunner(verbosity=2)
    result = runner.run(suite)
    return 0 if result.wasSuccessful() else 1
```
- Pre-flights at the top of `main()` short-circuit with exit 2 ("environment error") if input files are missing — distinguishes "smoodle's installer is broken" from "you're running tests outside the repo".
- Test classes are registered explicitly in the tuple inside `main()`. Adding a new test class means adding it both as a class definition AND to that tuple.
- `verbosity=2` prints one line per test method.

**Module-level constants:**
- Path constants for files-under-test go at module top. From `tests/test_installers.py:47-59`:
  ```python
  REPO_ROOT = Path(__file__).resolve().parent.parent
  INSTALL_SH = REPO_ROOT / "scripts" / "install.sh"
  INSTALL_LIBRIME_SH = REPO_ROOT / "scripts" / "install-librime-fork.sh"
  INSTALL_LINUX_SH = REPO_ROOT / "scripts" / "install-linux.sh"
  INSTALL_WINDOWS_PS1 = REPO_ROOT / "scripts" / "install-windows.ps1"
  INSTALL_LIBRIME_PS1 = REPO_ROOT / "scripts" / "install-librime-fork.ps1"
  BUILD_MACOS_DMG_SH = REPO_ROOT / "scripts" / "build-macos-dmg.sh"
  SCHEMA_DIR = REPO_ROOT / "schema"
  SCHEMA_FILES = (
      "thai_phonetic.schema.yaml",
      "thai_phonetic.dict.yaml",
      "default.custom.yaml",
  )
  ```

**Setup / teardown:**
- Per-test sandbox: `setUp` creates a `tempfile.mkdtemp(prefix="smoodle-test-")` directory and a fake Squirrel.app inside it; `tearDown` calls `shutil.rmtree(self.tmp, ignore_errors=True)`. Pattern at `tests/test_installers.py:450-464`.
- One-time fixture extraction: `setUpClass` (with `@classmethod`) reads the install script body once and caches the regex-extracted helper for all tests in the class. Pattern at `tests/test_installers.py:532-540` — extracts the `run_with_timeout` perl wrapper from `install.sh`.

**Assertion patterns:**
- Shape tests: `body = SCRIPT.read_text()` then `self.assertIn("expected_substring", body)` — quick regression detection without executing the script. Used heavily for PowerShell scripts since `pwsh` isn't on the macOS dev box.
- Negative-shape tests (anti-pattern detection): `self.assertNotIn(...)`. Examples:
  - `tests/test_installers.py:201-202` — `command -v fcitx5` MUST NOT appear (would be wrong: must use `pgrep -x` for running detection, not `command -v` for installed detection).
  - `tests/test_installers.py:296` — `Find-WeaselPath` MUST NOT appear (PS5.1 forward-call constraint).
  - `tests/test_installers.py:311-312` — `RunAs` and `WindowsBuiltInRole` MUST NOT appear in `install-windows.ps1` (admin elevation belongs in the librime script, not the schema script).
  - `tests/test_installers.py:347` — `} else { 10 }` MUST NOT appear (60s default after dict-compile timeout incident).

## What Is Tested

**`tests/test_installers.py` (8 active classes, 56 passing tests):**

1. **`InstallScriptShape` (3 tests)** — `scripts/install.sh`:
   - File exists and is readable.
   - `bash -n` syntax check passes.
   - All four `SMOODLE_*` env-override knobs are declared in the script body.

2. **`InstallLibrimeForkScriptShape` (7 tests)** — `scripts/install-librime-fork.sh`:
   - File exists and is executable.
   - `bash -n` syntax check.
   - All nine env overrides declared.
   - Fork repo (`smoodle-type/librime`) and tag (`1.16.0-smoodle.1`) referenced.
   - Required brew deps listed (`cmake`, `boost`, `leveldb`, `marisa`, `yaml-cpp`, `opencc`, `googletest`, `pkg-config`, `ninja`, `glog`).
   - Default path is download-from-GitHub-Releases (curl + `releases/download` + `macOS-universal.dylib`).
   - `.smoodle-backup` convention is in place before any swap.

3. **`InstallLinuxScriptShape` (6 tests)** — `scripts/install-linux.sh` (Lane C):
   - File exists and is executable.
   - `bash -n` syntax check.
   - Env overrides declared (`SMOODLE_RIME_DIR`, `SMOODLE_IM`, `SMOODLE_AUTO_DEPLOY`, `SMOODLE_DEPLOY_TIMEOUT_SECS`).
   - IM detection uses `pgrep -x fcitx5` / `pgrep -x ibus-daemon` (running process), NOT `command -v` (installed binary). Hybrid setups exist where one is installed and another is running.
   - Both fcitx5 and ibus paths handled (`.local/share/fcitx5/rime`, `.config/ibus/rime`, `fcitx5 -r`, `ibus-daemon`).
   - Ranking-limitation note ships in the post-install instructions.
   - Errors out with non-zero when no IM daemon is running (skipped if test machine actually has fcitx5/ibus running).

4. **`InstallWindowsPs1Shape` (12 tests)** — `scripts/install-windows.ps1` (Lane B):
   - File exists.
   - All four env overrides declared.
   - All three schema YAML filenames mentioned.
   - Uses `%APPDATA%\Rime` (user-scope, no admin).
   - Auto-detects Weasel install path under both Program Files parents (`weasel-*` versioned subdirs — discovered 2026-05-07).
   - Detection is inline, not in a function (PS5.1 forward-call constraint).
   - Uses `WeaselDeployer.exe /deploy` with `WaitForExit` for timeout.
   - Does NOT use `RunAs` or `WindowsBuiltInRole` (admin belongs in the librime script).
   - Auto-installs Weasel via `winget install Rime.Weasel` if missing, except when `SMOODLE_WEASEL_PATH` is overridden.
   - Touches schema timestamps after copy (rsync from Mac preserves old mtimes — would otherwise cause WeaselDeployer to skip recompilation silently).
   - Clears compiled `thai_phonetic.*` build dir when schemas change.
   - Default deploy timeout is 60s (was 10s; 1.1 MB dict compile takes longer).
   - WARN message references the Weasel tray icon and "Under maintenance" so users have a no-docs fallback.

5. **`InstallLibrimeForkPs1Shape` (10 tests)** — `scripts/install-librime-fork.ps1` (Lane B librime DLL swap):
   - File exists.
   - All eight env overrides declared.
   - Fork repo default `smoodle-type/librime` referenced.
   - Uses `gh run list --workflow smoodle-build --status success` to resolve latest CI artifact.
   - Default variant `msvc-x64` and artifact name pattern `artifact-Windows-` referenced.
   - Requires admin elevation (`WindowsBuiltInRole`, `Administrator`, `RunAs`).
   - Uses the same `.smoodle-backup` convention as the macOS installer.
   - Auto-installs gh CLI + 7-Zip via winget (`GitHub.cli`, `7zip.7zip`).
   - Vendored DLL paths checked: `vendor\windows\rime.dll` (repo) and `\\host.lan\Data\vendor\windows\rime.dll` (dev share-mount loop).
   - When vendored DLL is found, gh CLI / 7-Zip installs are skipped (guard via `-not $VendoredDll`).

6. **`BuildMacosDmgScriptShape` (7 tests)** — `scripts/build-macos-dmg.sh` (Lane A DMG packaging):
   - File exists and is executable.
   - `bash -n` syntax check.
   - Derives version from `git describe`.
   - Bundles all three schema YAMLs.
   - Bundles both installer scripts (`install.sh`, `install-librime-fork.sh`).
   - Generates `Install Smoodle.command` double-clickable entry point.
   - Creates DMG via `hdiutil` with `UDZO` compression.
   - Outputs to `dist/smoodle-{version}-macOS.dmg`.

7. **`InstallSandboxed` (5 tests)** — end-to-end execution of `install.sh` against a tmpdir:
   - Helper `_run_installer(env_overrides, expect_success=True)` at `tests/test_installers.py:62-76` runs the script with overridden env, captures stdout/stderr, raises with combined output on unexpected failure.
   - `test_fails_when_squirrel_missing` — `SMOODLE_SQUIRREL_PATH` pointed at a nonexistent path → script exits non-zero with "Squirrel.app is not installed".
   - `test_copies_all_three_yamls` — runs the installer, checks all three YAMLs landed in the sandboxed Rime dir with content matching the source.
   - `test_creates_rime_dir_when_missing` — `RIME_DIR` doesn't exist beforehand → installer creates it via `mkdir -p`.
   - `test_idempotent_with_timestamped_backup` — runs twice with a mutation between runs; verifies a single `*.bak.{timestamp}` file is created carrying the user's edit, and the live file is restored to repo content. Sleeps 1.1s between runs because macOS HFS+ has 1s mtime resolution.
   - `test_idempotent_no_backup_when_unchanged` — runs twice without mutation; no backups should be created. Tests that the `diff -q` check in `install.sh:63` works.

8. **`TimeoutHelper` (3 tests)** — extracts the `run_with_timeout` perl helper from `install.sh` via regex (`setUpClass` at `tests/test_installers.py:532-540`) and exercises it standalone:
   - `test_returns_zero_on_success` — `run_with_timeout 2 true` returns 0.
   - `test_returns_command_exit_code_on_failure` — `run_with_timeout 2 false` returns 1.
   - `test_returns_124_on_timeout` — `run_with_timeout 1 sleep 5` returns 124 (matches GNU `timeout` convention).
   - This tests the helper without re-implementing it: the test extracts the function body from the live `install.sh` and embeds it in a wrapper bash script. If the helper drifts in `install.sh`, the test still uses the current version.

**`tests/test_dict.py` (one-shot script, not unittest):**
- Reads a fixture YAML of `(romanization, expected_thai)` assertions.
- **String-match mode (default)** — checks every fixture pair appears as a `<thai>\t<romanization>` line in `schema/thai_phonetic.dict.yaml`. Catches romanization typos, wrong tone marks, dropped variants. Algebra-tagged assertions are SKIPPED with a note (string-match can't verify them).
- **Engine mode (`--use-rime-api-console`)** — drives each assertion through `vendor/librime/build/bin/rime_api_console`, checks `expected_thai` appears in the top-N candidates. Both direct and algebra-tagged assertions exercised end-to-end. Requires `vendor/librime/` built (`make release`) and `/tmp/smoodle-rime-test/` initialized via `scripts/init_rime_testdir.sh`.
- **Mistagging guard** — algebra-tagged entries that ALSO appear directly in the dict cause a hard FAIL. Prevents the algebra rule getting false credit.
- Exit codes: `0` pass, `1` assertion failure, `2` fixture/dict missing.

## Mocking

**Framework:** None — `unittest.mock` is not used anywhere.

**What gets mocked / sandboxed:**

The strategy is "real subprocess execution against a sandboxed filesystem" rather than mocking. The `install.sh` script was deliberately designed (commit `73a24a1` "Phase 1 kickoff: harden install.sh + scaffold installer tests") to take its mutable paths from env overrides so tests can redirect them:

| Production | Test override |
|------------|---------------|
| `~/Library/Rime/` | `SMOODLE_RIME_DIR=$tmpdir/Rime` |
| `/Library/Input Methods/Squirrel.app` | `SMOODLE_SQUIRREL_PATH=$tmpdir/Squirrel.app` (a stub directory) |
| Auto-deploy via Squirrel restart | `SMOODLE_AUTO_DEPLOY=0` (skip the kill+restart block entirely) |
| 10s deploy timeout | `SMOODLE_DEPLOY_TIMEOUT_SECS=2` (faster test loop) |

Setup pattern (`tests/test_installers.py:450-461`):
```python
def setUp(self):
    self.tmp = Path(tempfile.mkdtemp(prefix="smoodle-test-"))
    self.rime_dir = self.tmp / "Rime"
    self.squirrel = self.tmp / "Squirrel.app"
    # Fake Squirrel: just needs to exist as a path the script can stat.
    self.squirrel.mkdir(parents=True, exist_ok=True)
    self.env = {
        "SMOODLE_RIME_DIR": str(self.rime_dir),
        "SMOODLE_SQUIRREL_PATH": str(self.squirrel),
        "SMOODLE_AUTO_DEPLOY": "0",
        "SMOODLE_DEPLOY_TIMEOUT_SECS": "2",
    }
```

**What is NOT mocked / sandboxed:**
- `bash -n` syntax checks run against the real script files.
- File-existence and shape checks (`assertIn` against `script.read_text()`) read the real script files.
- The `run_with_timeout` perl helper is exercised against real `true` / `false` / `sleep 5` subprocesses.

**What is NOT covered (deliberately deferred):**
- `install-librime-fork.sh` end-to-end — needs sudo + ~5-15 min `make release` + a real Squirrel.app. Marked as `@unittest.skip("E2E only: needs sudo + ~5-15min make + real Squirrel.app")` in `FutureLanes` at `tests/test_installers.py:588-596`. Coverage is shape-only (string-match against the script body).
- Auto-deploy `kill+restart` against a real Squirrel — skipped, will live in a future Lane E E2E job (`tests/test_installers.py:582-586`).
- PowerShell script real syntax / execution — `pwsh` isn't on the macOS dev box, so PS scripts get only regex/grep shape checks. Real execution happens in the th-dc test bed VM (Lane B) and CI.

## Skipped Tests (3 total)

All three skips are in `FutureLanes` at `tests/test_installers.py:567-596`. Verified by running the suite: `Ran 59 tests in 4.900s. OK (skipped=3)`.

| Test | Reason |
|------|--------|
| `test_telemetry_opt_in_default_off` | "Phase 1 telemetry milestone not yet implemented." Placeholder for verifying the future telemetry POST client defaults OFF and payload contains only `{install_id_hash, version, os}`. |
| `test_auto_deploy_kill_restart_against_real_squirrel` | "E2E only: requires real Squirrel.app + dogfood machine." Covered manually during dogfood; CI E2E lane (Lane E) will exercise this on a `macos-14` GitHub runner. |
| `test_install_librime_fork_end_to_end` | "E2E only: needs sudo + ~5-15min make + real Squirrel.app." The full clone-checkout-fork-tag, make-release, swap-dylib, verify-engine flow. Manual dogfood for Phase 1; `macos-14` CI runner for Lane E. |

The skips are placeholder bodies (`...`) with `@unittest.skip("...")` decorators — they intentionally fail neither pass nor fail; they make the future test surface visible early so the test inventory matches the roadmap.

## Fixtures and Test Data

**Test fixtures live in `tests/`:**
- `tests/v01_fixture.yaml` (active, 50 assertions: 30 direct + 20 algebra-tagged) — the source of truth for the engine-mode 56/56 baseline. (Note: comments at the top of the file say "50 assertions / 35 direct + 21 algebra"; the actual file is 30 + 20. The README at line 63 says "56/56 PASS (35 direct + 21 algebra)". Mismatch is observed, not corrected here.)
- `tests/v001_fixture.yaml` (legacy, v0.0.1 era). Kept around for historical comparison; not exercised by the active test runs.

**Fixture format** (parsed by hand-rolled regex in `tests/test_dict.py:73-91`, not PyYAML):
```yaml
# Direct assertion (literal dict entry expected)
- {romanization: "sawadee",      expected_thai: "สวัสดี"}

# Algebra assertion (must be derivable by the named rule, NOT in dict directly)
- {romanization: "kopkoon",      expected_thai: "ขอบคุณ",  via: "kh->k"}
```

**Why hand-rolled regex instead of PyYAML?** Test scripts are stdlib-only by design (`tests/test_dict.py:24-29`, `tests/test_installers.py:27`). Anyone with Python 3.10+ can run them with no `pip install`.

**Fixtures used by `test_installers.py`:**
- The schema YAMLs at `schema/*.yaml` are the test inputs, not separate fixture files. Tests verify they get copied correctly.
- Test sandboxes are constructed in-memory via `tempfile.mkdtemp(prefix="smoodle-test-")` and torn down in `tearDown`.

## Coverage

**Requirements:** None enforced. No coverage tool is configured.

**View coverage:** Not set up. Add `coverage run -m unittest tests.test_installers && coverage report` if needed.

## Test Types

**Unit tests:**
- Embedded helper test: `TimeoutHelper` extracts `run_with_timeout` from `install.sh` and exercises it standalone. The helper is the only proper "unit" in the test suite — most everything else is integration- or shape-flavored.

**Integration / E2E tests:**
- `InstallSandboxed` — runs the full `install.sh` end-to-end against a sandboxed Rime dir + fake Squirrel.app. Covers the schema-copy + verification + idempotency flow; auto-deploy is disabled (`SMOODLE_AUTO_DEPLOY=0`) because tests must not touch the dev box's running Squirrel.

**Shape / static tests:**
- The bulk of `test_installers.py` is shape-flavored: read the script body, regex-check for required env overrides / required commands / known-bad anti-patterns. Cheap to run, catches drift on PowerShell scripts that can't be syntax-checked on Mac.

**Schema correctness tests:**
- `tests/test_dict.py` — string-match (fast, default) and engine-mode (slow, requires librime built). Engine mode is the gold-standard pipeline test for the schema; string-match is the regression net for typos.

**E2E tests (deferred / out of process):**
- macOS librime build + dylib swap → manual dogfood + future Lane E `macos-14` runner.
- Windows installer → th-dc dockur/windows test bed VM (Lane B).
- Linux installer → GitHub Actions `ubuntu-latest` runner (Lane C, see CI section below).

## CI Status

**GitHub Actions workflows:** One workflow lives in this repo.

**`.github/workflows/install-linux-e2e.yml`** — Lane C end-to-end installer test:
- Triggers: `push` to `main` and `pull_request`, both filtered by paths (`scripts/install-linux.sh`, `schema/**`, the workflow file itself).
- Runs on: `ubuntu-latest`.
- Steps:
  1. `actions/checkout@v4`.
  2. `sudo apt-get install -y ibus-rime` to bring in the system librime.
  3. Run installer with `SMOODLE_AUTO_DEPLOY=0 SMOODLE_IM=ibus bash scripts/install-linux.sh`. The env overrides skip `pgrep -x ibus-daemon` (no daemon in the runner) and skip `ibus-daemon -drxR` restart (no display).
  4. Verify all three schema files landed in `~/.config/ibus/rime/`.
  5. Verify file content via `grep -q "thai_phonetic"`.
- Status (per recent commits): `d0eb089 TODOS.md: close TODO 8 (Lane C GHA E2E green, run 25480673681)` — green.
- Coverage gap: fcitx5 path is NOT tested in CI (would require `fcitx5-rime` apt package + a different dest dir); only the ibus path is exercised end-to-end.

**No workflow exists for:**
- `tests/test_installers.py` (the macOS-only Bash + PowerShell installer suite). Runs on the dev box.
- `tests/test_dict.py` string-match mode. Runs on the dev box.
- `tests/test_dict.py` engine mode. Manual dogfood; future Lane E `macos-14` runner planned per `FutureLanes` skip rationale.
- Lane B Windows installer. Manual smoke test on the th-dc dockur/windows VM (closed via `ee6efbb TODO 7 ✓ CLOSED: Lane B Windows smoke green — sawatd -> สวัสดี`).
- Lane A DMG build. Manual.

## Common Patterns

**Subprocess testing:**
```python
def _run_installer(env_overrides: dict[str, str], expect_success: bool = True):
    env = os.environ.copy()
    env.update(env_overrides)
    result = subprocess.run(
        ["bash", str(INSTALL_SH)],
        env=env,
        capture_output=True,
        text=True,
        timeout=30,
    )
    if expect_success and result.returncode != 0:
        raise AssertionError(
            f"installer exited {result.returncode}\n"
            f"STDOUT:\n{result.stdout}\nSTDERR:\n{result.stderr}"
        )
    return result
```
- Always pass `timeout=` to `subprocess.run` (30s for installers, 10s for shape-runs, 15s for `rime_api_console` queries). Prevents a hung script from hanging the test runner.
- Always pass `capture_output=True, text=True` so the helper can include both streams in the assertion message.
- Inherit-then-update env: `env = os.environ.copy(); env.update(overrides)`. Don't pass a bare overrides dict — bash needs `PATH`, `HOME`, etc.

**bash -n syntax check:**
```python
def test_install_sh_syntax_valid(self):
    result = subprocess.run(
        ["bash", "-n", str(INSTALL_SH)], capture_output=True, text=True
    )
    self.assertEqual(result.returncode, 0, msg=result.stderr)
```
- `bash -n` parses without executing — catches syntax drift cheaply. Used on every Bash script in `scripts/`.

**Shape / regex assertions:**
```python
def test_script_declares_env_overrides(self):
    body = INSTALL_SH.read_text()
    for var in ("SMOODLE_RIME_DIR", "SMOODLE_SQUIRREL_PATH",
                "SMOODLE_AUTO_DEPLOY", "SMOODLE_DEPLOY_TIMEOUT_SECS"):
        self.assertIn(var, body, f"install.sh missing env override: {var}")
```
- Failure messages always name the missing item — `f"install.sh missing env override: {var}"` not just bare `assertIn`. Test failures must be debuggable from the runner output without re-reading the test.

**Regex extraction of embedded helpers** (`tests/test_installers.py:533-540`):
```python
@classmethod
def setUpClass(cls):
    body = INSTALL_SH.read_text()
    m = re.search(
        r"run_with_timeout\(\)\s*\{(.*?)^}", body, re.DOTALL | re.MULTILINE
    )
    if not m:
        raise unittest.SkipTest("run_with_timeout helper not found in install.sh")
    cls.helper_body = m.group(0)
```
- Extract a function body once in `setUpClass`, embed it in a wrapper bash script per-test. Avoids re-implementing the helper in the test file (which would drift from the real script).

**HFS+ mtime resolution awareness:**
```python
_run_installer(self.env)
time.sleep(1.1)  # macOS HFS+ has 1s mtime resolution; backup suffix differs
_run_installer(self.env)
```
- Used in `test_idempotent_with_timestamped_backup` and `test_idempotent_no_backup_when_unchanged`. The `1.1` is rationalized in a comment at `tests/test_installers.py:496`.

**Skip with explanation:**
```python
@unittest.skip("E2E only: needs sudo + ~5-15min make + real Squirrel.app")
def test_install_librime_fork_end_to_end(self):
    # Full flow: clone (or reuse) vendor/librime, checkout fork tag,
    # make release, back up the upstream librime.1.dylib, swap in
    # the patched build/lib/librime.1.16.0.dylib, then verify
    # Squirrel picks up the new dylib (file size, dyld load check,
    # tests/test_dict.py engine-mode 56/56). Manual dogfood for
    # Phase 1; macos-14 CI runner for Lane E.
    ...
```
- Reason string explains BOTH why it's skipped AND when the skip becomes a real test (which milestone, which runner).

## Adding New Tests

**For a new installer script** (`install-foo.sh`):
1. Add path constant at the top of `tests/test_installers.py` next to the existing siblings: `INSTALL_FOO_SH = REPO_ROOT / "scripts" / "install-foo.sh"`.
2. Add a new `InstallFooScriptShape(unittest.TestCase)` class with at minimum: `test_script_exists_and_executable`, `test_script_syntax_valid`, `test_script_declares_env_overrides`.
3. Register the new class in the tuple inside `main()` at `tests/test_installers.py:653-656`.
4. If the script is a Bash script, syntax check with `bash -n`. If PowerShell, do regex/grep shape checks only — `pwsh` isn't available on the macOS dev box.

**For a new schema/dict assertion**:
1. Add a `- {romanization: "...", expected_thai: "..."}` line under the appropriate `# === DIRECT: <category> ===` banner in `tests/v01_fixture.yaml`. Or a `- {romanization: "...", expected_thai: "...", via: "<rule>"}` line under `# === ALGEBRA <rule> ===`.
2. Run `python3 tests/test_dict.py` (string-match) to catch direct-entry typos.
3. Run engine mode for algebra-tagged additions: `python3 tests/test_dict.py --use-rime-api-console --fixture tests/v01_fixture.yaml`.

**For a new sandboxed e2e test:**
1. Add the test method to `InstallSandboxed` (or create a parallel sandboxed class for a different installer).
2. Use the existing `setUp` env baseline; override individual keys per-test if needed.
3. Always set `SMOODLE_AUTO_DEPLOY=0` to keep tests away from the dev box's running IM.

---

*Testing analysis: 2026-05-08*
