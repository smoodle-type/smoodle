#!/usr/bin/env python3
"""Tests for the Plan 05-01 verify-librime.sh manual hash-drift checker.

Exercises scripts/verify-librime.sh with sandboxed paths (SMOODLE_SQUIRREL_PATH
pointing at a temp dir holding a fake librime.1.dylib, SMOODLE_SHA256_SIDECAR
pointing at a fixture sidecar), and asserts:

  - Clean dylib (matches sidecar) -> exit 0, stdout contains "OK"
  - Tampered dylib (wrong bytes) -> exit 1, message contains "drift detected"
    and "install-librime-fork.sh"
  - Missing dylib -> exit 2
  - Missing sidecar -> exit 2

REQ HARDEN-01. Phase 5 Plan 05-01, Wave 1.
"""

from __future__ import annotations

import hashlib
import os
import shutil
import subprocess
import tempfile
import unittest
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parent.parent
SCRIPT = REPO_ROOT / "scripts" / "verify-librime.sh"


class TestVerifyLibrimeMac(unittest.TestCase):
    """HARDEN-01: verify-librime.sh exit-code and message tests."""

    def setUp(self) -> None:
        self.tmp = Path(tempfile.mkdtemp(prefix="smoodle-verify-mac-"))
        self.addCleanup(shutil.rmtree, self.tmp, ignore_errors=True)

    # --- helpers -----------------------------------------------------------

    def _make_squirrel_dir(self, dylib_content: bytes) -> str:
        """Create a fake Squirrel.app/Contents/Frameworks/ with a dylib inside."""
        frameworks = self.tmp / "Squirrel.app" / "Contents" / "Frameworks"
        frameworks.mkdir(parents=True, exist_ok=True)
        dylib = frameworks / "librime.1.dylib"
        dylib.write_bytes(dylib_content)
        return str(self.tmp / "Squirrel.app")

    def _make_sidecar(self, sha256_hash: str) -> str:
        """Create a sidecar file with the given SHA-256 hash."""
        sidecar = self.tmp / "librime.1.dylib.sha256"
        sidecar.write_text(f"{sha256_hash}  librime.1.dylib\n")
        return str(sidecar)

    def _run(self, squirrel_path: str | None = None, sidecar_path: str | None = None) -> subprocess.CompletedProcess:
        env = os.environ.copy()
        if squirrel_path is not None:
            env["SMOODLE_SQUIRREL_PATH"] = squirrel_path
        if sidecar_path is not None:
            env["SMOODLE_SHA256_SIDECAR"] = sidecar_path
        result = subprocess.run(
            ["bash", str(SCRIPT)],
            env=env, capture_output=True, text=True,
        )
        return result

    # --- tests -------------------------------------------------------------

    def test_clean_dylib(self) -> None:
        """Matching dylib + sidecar -> exit 0, stdout contains OK."""
        content = b"clean-dylib-bytes"
        sha = hashlib.sha256(content).hexdigest()
        squirrel = self._make_squirrel_dir(content)
        sidecar = self._make_sidecar(sha)
        r = self._run(squirrel_path=squirrel, sidecar_path=sidecar)
        self.assertEqual(r.returncode, 0)
        self.assertIn("OK", r.stdout)

    def test_tampered_dylib(self) -> None:
        """Different bytes than sidecar SHA -> exit 1, drift detected."""
        sha = hashlib.sha256(b"original").hexdigest()
        squirrel = self._make_squirrel_dir(b"tampered-content")
        sidecar = self._make_sidecar(sha)
        r = self._run(squirrel_path=squirrel, sidecar_path=sidecar)
        self.assertEqual(r.returncode, 1)
        combined = r.stdout + r.stderr
        self.assertIn("drift detected", combined.lower())
        self.assertIn("install-librime-fork.sh", combined)

    def test_missing_dylib(self) -> None:
        """Point SMOODLE_SQUIRREL_PATH at nonexistent dir -> exit 2."""
        r = self._run(squirrel_path="/tmp/nonexistent-smoodle-squirrel.app")
        self.assertEqual(r.returncode, 2)

    def test_missing_sidecar(self) -> None:
        """Point SMOODLE_SHA256_SIDECAR at nonexistent file -> exit 2."""
        squirrel = self._make_squirrel_dir(b"any-content")
        r = self._run(
            squirrel_path=squirrel,
            sidecar_path="/tmp/nonexistent-sidecar.sha256",
        )
        self.assertEqual(r.returncode, 2)


if __name__ == "__main__":
    unittest.main()
