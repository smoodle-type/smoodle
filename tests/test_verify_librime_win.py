#!/usr/bin/env python3
"""Tests for the Plan 05-01 verify-librime.ps1 manual hash-drift checker.

Exercises scripts/verify-librime.ps1 with sandboxed paths (SMOODLE_WEASEL_PATH
pointing at a temp dir holding a fake rime.dll, sidecar resolved relative to
the script dir via vendored fallback), and asserts:

  - Clean DLL (matches sidecar) -> exit 0, stdout contains "OK"
  - Tampered DLL (wrong bytes) -> exit 1, message contains "drift detected"
    and "install-librime-fork.ps1"
  - Missing DLL -> exit 2
  - Missing sidecar -> exit 2

REQ HARDEN-02. Phase 5 Plan 05-01, Wave 1.

Cross-platform note: runtime tests require pwsh. String-grep tests run on
any platform. Mirrors the pattern in tests/test_install_librime_fork_win.py.
"""

from __future__ import annotations

import hashlib
import os
import re
import shutil
import subprocess
import tempfile
import unittest
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parent.parent
SCRIPT = REPO_ROOT / "scripts" / "verify-librime.ps1"
SIDEWAR = REPO_ROOT / "vendor" / "windows" / "rime.dll.sha256"

_PWSH = shutil.which("pwsh") or shutil.which("powershell")
_HAS_PWSH = _PWSH is not None


class TestVerifyLibrimeWinShape(unittest.TestCase):
    """Shape/grep checks that run on any platform (no pwsh needed)."""

    def test_script_exists(self):
        self.assertTrue(SCRIPT.is_file(), f"{SCRIPT} missing")

    def test_declares_cmdlet_binding(self):
        body = SCRIPT.read_text(encoding="utf-8")
        self.assertIn("[CmdletBinding()]", body)

    def test_error_action_preference_stop(self):
        body = SCRIPT.read_text(encoding="utf-8")
        self.assertIn("$ErrorActionPreference = 'Stop'", body)

    def test_uses_get_filehash_sha256(self):
        body = SCRIPT.read_text(encoding="utf-8")
        self.assertIn("Get-FileHash", body)
        self.assertIn("SHA256", body)

    def test_case_normalization_tolower(self):
        body = SCRIPT.read_text(encoding="utf-8")
        self.assertIn(".ToLower()", body)

    def test_env_override_weasel_path(self):
        body = SCRIPT.read_text(encoding="utf-8")
        self.assertIn("SMOODLE_WEASEL_PATH", body)

    def test_exit_codes_declared(self):
        body = SCRIPT.read_text(encoding="utf-8")
        self.assertIn("exit 0", body)
        self.assertIn("exit 1", body)
        # exit 2 appears at least twice (missing Weasel + missing DLL + missing sidecar)
        self.assertGreaterEqual(body.count("exit 2"), 2)

    def test_drift_message_present(self):
        body = SCRIPT.read_text(encoding="utf-8")
        self.assertIn("drift detected", body)

    def test_recovery_instruction_present(self):
        body = SCRIPT.read_text(encoding="utf-8")
        self.assertIn("install-librime-fork.ps1", body)

    def test_ascii_only_mp4(self):
        """MP-4 invariant: .ps1 files must be ASCII-only."""
        raw = SCRIPT.read_bytes()
        try:
            raw.decode("ascii")
        except UnicodeDecodeError as e:
            self.fail(f"Non-ASCII byte in verify-librime.ps1 at offset {e.start}")

    def test_sidecar_resolves_relative_script(self):
        body = SCRIPT.read_text(encoding="utf-8")
        # Must use $MyInvocation.MyCommand.Path or $ScriptDir for relative resolution.
        self.assertTrue(
            "MyInvocation" in body or "ScriptDir" in body,
            "sidecar must resolve relative to script directory",
        )

    def test_no_hardcoded_hash(self):
        """CP-2: no hardcoded 64-char hex literal assigned to a HASH variable."""
        body = SCRIPT.read_text(encoding="utf-8")
        bad = re.compile(
            r"^\s*\$[A-Za-z0-9_]*HASH[A-Za-z0-9_]*\s*=\s*['\"][a-f0-9]{64}['\"]",
            re.MULTILINE | re.IGNORECASE,
        )
        match = bad.search(body)
        self.assertIsNone(match, f"hardcoded hash found: {match.group(0) if match else None}")


class TestVerifyLibrimeWinRuntime(unittest.TestCase):
    """Runtime tests requiring pwsh -- skipped if unavailable."""

    def setUp(self) -> None:
        self.tmp = Path(tempfile.mkdtemp(prefix="smoodle-verify-win-"))
        self.addCleanup(shutil.rmtree, self.tmp, ignore_errors=True)

    def _make_weasel_dir(self, dll_content: bytes) -> str:
        weasel = self.tmp / "weasel-test"
        weasel.mkdir(parents=True, exist_ok=True)
        (weasel / "rime.dll").write_bytes(dll_content)
        return str(weasel)

    def _make_sidecar(self, sha256_hash: str) -> str:
        sidecar = self.tmp / "rime.dll.sha256"
        sidecar.write_text(f"{sha256_hash}  rime.dll\n")
        return str(sidecar)

    def _run(self, weasel_path: str | None = None, sidecar_path: str | None = None) -> subprocess.CompletedProcess:
        env = os.environ.copy()
        if weasel_path is not None:
            env["SMOODLE_WEASEL_PATH"] = weasel_path
        if sidecar_path is not None:
            env["SMOODLE_SHA256_SIDECAR"] = sidecar_path
        result = subprocess.run(
            [_PWSH, "-NoProfile", "-ExecutionPolicy", "Bypass", "-File", str(SCRIPT)],
            env=env, capture_output=True, text=True,
        )
        return result

    @unittest.skipUnless(_HAS_PWSH, "pwsh / powershell not available on PATH")
    def test_clean_dll(self) -> None:
        """Matching DLL + sidecar -> exit 0, stdout contains OK."""
        content = b"clean-dll-bytes"
        sha = hashlib.sha256(content).hexdigest()
        weasel = self._make_weasel_dir(content)
        sidecar = self._make_sidecar(sha)
        r = self._run(weasel_path=weasel, sidecar_path=sidecar)
        self.assertEqual(r.returncode, 0)
        self.assertIn("OK", r.stdout)

    @unittest.skipUnless(_HAS_PWSH, "pwsh / powershell not available on PATH")
    def test_tampered_dll(self) -> None:
        """Different bytes than sidecar SHA -> exit 1, drift detected."""
        sha = hashlib.sha256(b"original").hexdigest()
        weasel = self._make_weasel_dir(b"tampered-content")
        sidecar = self._make_sidecar(sha)
        r = self._run(weasel_path=weasel, sidecar_path=sidecar)
        self.assertEqual(r.returncode, 1)
        combined = r.stdout + r.stderr
        self.assertIn("drift detected", combined.lower())
        self.assertIn("install-librime-fork.ps1", combined)

    @unittest.skipUnless(_HAS_PWSH, "pwsh / powershell not available on PATH")
    def test_missing_dll(self) -> None:
        """Weasel dir exists but no rime.dll -> exit 2."""
        weasel = self._make_weasel_dir(b"")
        # Remove the DLL so it's missing.
        (Path(weasel) / "rime.dll").unlink()
        r = self._run(weasel_path=weasel)
        self.assertEqual(r.returncode, 2)

    @unittest.skipUnless(_HAS_PWSH, "pwsh / powershell not available on PATH")
    def test_missing_sidecar(self) -> None:
        """Point SMOODLE_SHA256_SIDECAR at nonexistent file -> exit 2."""
        weasel = self._make_weasel_dir(b"any-content")
        r = self._run(
            weasel_path=weasel,
            sidecar_path="/tmp/nonexistent-sidecar.sha256",
        )
        self.assertEqual(r.returncode, 2)


if __name__ == "__main__":
    unittest.main()
