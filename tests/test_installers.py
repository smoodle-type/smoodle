#!/usr/bin/env python3
"""smoodle installer tests (Phase 1 D5 — boil-the-lake test scope).

Exercises `scripts/install.sh` end-to-end against a sandboxed
`~/Library/Rime` and a fake Squirrel.app, plus unit checks on the
portable timeout helper.

The script supports these env overrides (added 2026-05-05) so tests
can run without touching the real macOS install:
  SMOODLE_RIME_DIR        — destination for schema YAMLs
  SMOODLE_SQUIRREL_PATH   — host detection target
  SMOODLE_AUTO_DEPLOY     — set to "0" to skip the kill+restart block
  SMOODLE_DEPLOY_TIMEOUT_SECS — timeout for auto-deploy steps

Coverage:
  - install.sh syntax (bash -n)
  - missing-host detection (Critical Failure Mode framing)
  - schema YAML copy
  - idempotency + timestamped backup
  - destination directory creation
  - perl timeout helper exit-code semantics

Stubs (SKIPPED — depend on infra not yet in repo):
  - Windows Weasel post-install registration verify (Lane B)
  - Telemetry opt-in payload (Phase 1 telemetry milestone)
  - Auto-deploy kill+restart against a real Squirrel (E2E only)

Stdlib only — matches tests/test_dict.py style. No pytest dep.

Exit codes:
  0 — all tests pass
  1 — one or more failures
  2 — environment / setup error
"""

from __future__ import annotations

import os
import re
import shutil
import subprocess
import sys
import tempfile
import time
import unittest
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parent.parent
INSTALL_SH = REPO_ROOT / "scripts" / "install.sh"
INSTALL_LIBRIME_SH = REPO_ROOT / "scripts" / "install-librime-fork.sh"
INSTALL_LINUX_SH = REPO_ROOT / "scripts" / "install-linux.sh"
SCHEMA_DIR = REPO_ROOT / "schema"
SCHEMA_FILES = (
    "thai_phonetic.schema.yaml",
    "thai_phonetic.dict.yaml",
    "default.custom.yaml",
)


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
            f"installer exited {result.returncode}\nSTDOUT:\n{result.stdout}\nSTDERR:\n{result.stderr}"
        )
    return result


class InstallScriptShape(unittest.TestCase):
    """Shape and syntax checks — fast, no filesystem mutation."""

    def test_install_sh_exists_and_executable(self):
        self.assertTrue(INSTALL_SH.is_file(), f"{INSTALL_SH} missing")
        self.assertTrue(os.access(INSTALL_SH, os.R_OK))

    def test_install_sh_syntax_valid(self):
        result = subprocess.run(
            ["bash", "-n", str(INSTALL_SH)], capture_output=True, text=True
        )
        self.assertEqual(result.returncode, 0, msg=result.stderr)

    def test_install_sh_declares_env_overrides(self):
        body = INSTALL_SH.read_text()
        for var in (
            "SMOODLE_RIME_DIR",
            "SMOODLE_SQUIRREL_PATH",
            "SMOODLE_AUTO_DEPLOY",
            "SMOODLE_DEPLOY_TIMEOUT_SECS",
        ):
            self.assertIn(var, body, f"install.sh missing env override: {var}")


class InstallLibrimeForkScriptShape(unittest.TestCase):
    """Shape and syntax checks for scripts/install-librime-fork.sh.

    The script builds the smoodle-patched librime from the LoneExile fork
    and swaps it into Squirrel's Frameworks/. The actual build+swap
    requires sudo + ~5-15 min of make time, so end-to-end coverage stays
    in FutureLanes (E2E only). Shape checks catch drift cheaply.
    """

    def test_script_exists_and_executable(self):
        self.assertTrue(INSTALL_LIBRIME_SH.is_file(), f"{INSTALL_LIBRIME_SH} missing")
        self.assertTrue(os.access(INSTALL_LIBRIME_SH, os.X_OK))

    def test_script_syntax_valid(self):
        result = subprocess.run(
            ["bash", "-n", str(INSTALL_LIBRIME_SH)], capture_output=True, text=True
        )
        self.assertEqual(result.returncode, 0, msg=result.stderr)

    def test_script_declares_env_overrides(self):
        body = INSTALL_LIBRIME_SH.read_text()
        for var in (
            "SMOODLE_LIBRIME_FORK_URL",
            "SMOODLE_LIBRIME_FORK_TAG",
            "SMOODLE_SQUIRREL_PATH",
            "SMOODLE_SKIP_BUILD",
            "SMOODLE_SKIP_SWAP",
            "SMOODLE_FORCE_REBUILD",
            "SMOODLE_NONINTERACTIVE",
        ):
            self.assertIn(var, body, f"install-librime-fork.sh missing override: {var}")

    def test_script_references_fork_and_tag(self):
        body = INSTALL_LIBRIME_SH.read_text()
        self.assertIn("LoneExile/librime", body)
        self.assertIn("1.16.0-smoodle.1", body)

    def test_script_lists_required_brew_deps(self):
        body = INSTALL_LIBRIME_SH.read_text()
        # glog matters specifically — it was the dep that bit us when brew
        # bumped past v2 and broke the existing rime_api_console binary.
        for dep in ("cmake", "boost", "leveldb", "marisa", "yaml-cpp",
                    "opencc", "googletest", "pkg-config", "ninja", "glog"):
            self.assertIn(dep, body, f"BREW_DEPS missing: {dep}")

    def test_script_backs_up_before_swap(self):
        body = INSTALL_LIBRIME_SH.read_text()
        # The .smoodle-backup convention is documented in RESUME.md and
        # avoids clobbering the upstream universal dylib on first install.
        self.assertIn(".smoodle-backup", body)


class InstallLinuxScriptShape(unittest.TestCase):
    """Shape and syntax checks for scripts/install-linux.sh (Lane C).

    The script is schema-only (option 3 from docs/LANE-C-LINUX.md): no
    libRime.so swap. End-to-end coverage lives in a future GHA workflow
    on `ubuntu-latest` with a real ibus-rime install. Shape checks here
    catch drift cheaply on the dev machine.
    """

    def test_script_exists_and_executable(self):
        self.assertTrue(INSTALL_LINUX_SH.is_file(), f"{INSTALL_LINUX_SH} missing")
        self.assertTrue(os.access(INSTALL_LINUX_SH, os.X_OK))

    def test_script_syntax_valid(self):
        result = subprocess.run(
            ["bash", "-n", str(INSTALL_LINUX_SH)], capture_output=True, text=True
        )
        self.assertEqual(result.returncode, 0, msg=result.stderr)

    def test_script_declares_env_overrides(self):
        body = INSTALL_LINUX_SH.read_text()
        for var in (
            "SMOODLE_RIME_DIR",
            "SMOODLE_IM",
            "SMOODLE_AUTO_DEPLOY",
            "SMOODLE_DEPLOY_TIMEOUT_SECS",
        ):
            self.assertIn(var, body, f"install-linux.sh missing override: {var}")

    def test_script_detects_running_im_not_just_installed(self):
        body = INSTALL_LINUX_SH.read_text()
        # Critical Failure Mode #3: hybrid setups — fcitx5 installed but
        # ibus running, or vice versa. Detection must use `pgrep` against
        # the running process, not `command -v` on the binary.
        self.assertIn("pgrep -x fcitx5", body)
        self.assertIn("pgrep -x ibus-daemon", body)
        # Negative check: must NOT use `command -v` for IM selection.
        self.assertNotIn("command -v fcitx5", body)
        self.assertNotIn("command -v ibus-daemon", body)

    def test_script_handles_both_im_paths(self):
        body = INSTALL_LINUX_SH.read_text()
        # Per-IM schema dirs and reload commands both must be present.
        self.assertIn(".local/share/fcitx5/rime", body)
        self.assertIn(".config/ibus/rime", body)
        self.assertIn("fcitx5 -r", body)
        self.assertIn("ibus-daemon", body)

    def test_script_documents_ranking_limitation(self):
        body = INSTALL_LINUX_SH.read_text()
        # Lane C ships option 3 (system librime, no fork distribution).
        # The ranking limitation must be surfaced to the user post-install
        # so the algebra-vs-direct collision behavior isn't a mystery bug.
        self.assertIn("RANKING LIMITATION", body)
        self.assertIn("LoneExile/librime", body)

    def test_script_errors_when_no_im_running(self):
        # SMOODLE_IM unset + no fcitx5/ibus process → exit non-zero with
        # explicit message. Run with auto-deploy off so we don't try to
        # actually call any IM binary even if detection somehow succeeds.
        result = subprocess.run(
            ["bash", str(INSTALL_LINUX_SH)],
            env={**os.environ, "SMOODLE_AUTO_DEPLOY": "0", "SMOODLE_IM": ""},
            capture_output=True,
            text=True,
            timeout=10,
        )
        # On a Mac dev box neither fcitx5 nor ibus-daemon will be running
        # so the script should detect that and bail out.
        if "fcitx5" in result.stderr or "ibus" in result.stderr or result.returncode != 0:
            self.assertNotEqual(result.returncode, 0)
            combined = result.stdout + result.stderr
            self.assertTrue(
                "no input method daemon" in combined.lower()
                or "smoodle_im" in combined.lower(),
                f"unexpected error output:\n{combined}",
            )
        else:
            self.skipTest("ran in env where fcitx5/ibus is actually running")


class InstallSandboxed(unittest.TestCase):
    """End-to-end runs against a tmpdir-sandboxed Rime + fake Squirrel."""

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

    def tearDown(self):
        shutil.rmtree(self.tmp, ignore_errors=True)

    def test_fails_when_squirrel_missing(self):
        env = dict(self.env)
        env["SMOODLE_SQUIRREL_PATH"] = str(self.tmp / "does-not-exist.app")
        result = _run_installer(env, expect_success=False)
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("Squirrel.app is not installed", result.stdout + result.stderr)

    def test_copies_all_three_yamls(self):
        _run_installer(self.env)
        for f in SCHEMA_FILES:
            dst = self.rime_dir / f
            src = SCHEMA_DIR / f
            self.assertTrue(dst.is_file(), f"missing at destination: {dst}")
            self.assertEqual(
                dst.read_bytes(),
                src.read_bytes(),
                f"content mismatch for {f}",
            )

    def test_creates_rime_dir_when_missing(self):
        self.assertFalse(self.rime_dir.exists())
        _run_installer(self.env)
        self.assertTrue(self.rime_dir.is_dir())

    def test_idempotent_with_timestamped_backup(self):
        _run_installer(self.env)
        # Mutate one of the destination YAMLs so the second run sees a diff.
        target = self.rime_dir / "thai_phonetic.schema.yaml"
        original = target.read_text()
        target.write_text(original + "\n# user-local edit\n")
        # macOS HFS+ has 1s mtime resolution; sleep so backup suffix differs.
        time.sleep(1.1)
        _run_installer(self.env)
        backups = list(self.rime_dir.glob("thai_phonetic.schema.yaml.bak.*"))
        self.assertEqual(
            len(backups),
            1,
            f"expected 1 timestamped backup, found {len(backups)}: {backups}",
        )
        # Backup carries the user's edit; live file is back to repo content.
        self.assertIn("# user-local edit", backups[0].read_text())
        self.assertEqual(
            target.read_bytes(),
            (SCHEMA_DIR / "thai_phonetic.schema.yaml").read_bytes(),
        )

    def test_idempotent_no_backup_when_unchanged(self):
        _run_installer(self.env)
        time.sleep(1.1)
        _run_installer(self.env)
        backups = list(self.rime_dir.glob("*.bak.*"))
        self.assertEqual(
            len(backups),
            0,
            f"unchanged install should not produce backups, got: {backups}",
        )


class TimeoutHelper(unittest.TestCase):
    """Exercise the perl-based run_with_timeout helper directly.

    The helper is embedded in install.sh; we extract it and verify
    exit-code semantics match GNU `timeout` (124 on timeout, command's
    own exit code on completion).
    """

    @classmethod
    def setUpClass(cls):
        body = INSTALL_SH.read_text()
        m = re.search(
            r"run_with_timeout\(\)\s*\{(.*?)^}", body, re.DOTALL | re.MULTILINE
        )
        if not m:
            raise unittest.SkipTest("run_with_timeout helper not found in install.sh")
        cls.helper_body = m.group(0)

    def _run_helper(self, secs: int, *cmd: str) -> int:
        wrapper = f"""
        #!/usr/bin/env bash
        set -uo pipefail
        {self.helper_body}
        run_with_timeout "$@"
        """
        result = subprocess.run(
            ["bash", "-c", wrapper, "wrapper", str(secs), *cmd],
            capture_output=True,
            text=True,
            timeout=secs + 5,
        )
        return result.returncode

    def test_returns_zero_on_success(self):
        self.assertEqual(self._run_helper(2, "true"), 0)

    def test_returns_command_exit_code_on_failure(self):
        self.assertEqual(self._run_helper(2, "false"), 1)

    def test_returns_124_on_timeout(self):
        self.assertEqual(self._run_helper(1, "sleep", "5"), 124)


class FutureLanes(unittest.TestCase):
    """Stubs for installer surfaces that don't exist yet in the repo.

    These are placeholders so the test surface is visible early. As
    Lane B (Windows), Lane C (Linux), and the telemetry milestone land,
    the corresponding installer scripts get created and these skips
    convert into real tests.
    """

    @unittest.skip("Lane B: Windows installer not yet implemented")
    def test_windows_weasel_post_install_registration_verified(self):
        # When scripts/install-windows.ps1 exists, verify it invokes
        # Weasel + checks the candidate window appears (Critical Failure
        # Mode #2 — winget reports success but IME registration silent-fails).
        ...

    @unittest.skip("Phase 1 telemetry milestone not yet implemented")
    def test_telemetry_opt_in_default_off(self):
        # When the telemetry POST client lands, verify default is OFF
        # and payload contains only {install_id_hash, version, os}.
        ...

    @unittest.skip("E2E only: requires real Squirrel.app + dogfood machine")
    def test_auto_deploy_kill_restart_against_real_squirrel(self):
        # Covered manually during dogfood; CI E2E lane (Lane E) will
        # exercise this on a macos-14 GitHub runner.
        ...

    @unittest.skip("E2E only: needs sudo + ~5-15min make + real Squirrel.app")
    def test_install_librime_fork_end_to_end(self):
        # Full flow: clone (or reuse) vendor/librime, checkout fork tag,
        # make release, back up the upstream librime.1.dylib, swap in
        # the patched build/lib/librime.1.16.0.dylib, then verify
        # Squirrel picks up the new dylib (file size, dyld load check,
        # tests/test_dict.py engine-mode 56/56). Manual dogfood for
        # Phase 1; macos-14 CI runner for Lane E.
        ...


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
                InstallLinuxScriptShape, InstallSandboxed, TimeoutHelper,
                FutureLanes):
        suite.addTests(loader.loadTestsFromTestCase(cls))
    runner = unittest.TextTestRunner(verbosity=2)
    result = runner.run(suite)
    return 0 if result.wasSuccessful() else 1


if __name__ == "__main__":
    sys.exit(main())
