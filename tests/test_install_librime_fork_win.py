#!/usr/bin/env python3
"""Tests for the Plan 03-02 SHA256 verify + Authenticode diagnostic in
scripts/install-librime-fork.ps1.

Exercises the script with simulated env (SMOODLE_SHA256_SIDECAR pointing at
a fixture sidecar, SMOODLE_WEASEL_PATH pointing at a tmp dir holding a
fixture rime.dll, SMOODLE_SKIP_SWAP=1 to skip Copy-Item), and asserts:

  - SHA mismatch -> exit 1 BEFORE any Copy-Item-to-Weasel-path
  - Vendored sidecar matches committed vendor/windows/rime.dll bytes
    (sidecar-matches-DLL invariant; protects against silent DLL bumps)
  - Authenticode diagnostic block exists and emits verbatim regression
    warning when fed shim Get-AuthenticodeSignature returning non-NotSigned
    (test verifies grep against the script source; runtime shim is a
    cross-platform compatibility hazard for Get-AuthenticodeSignature
    which is Win-only)
  - Failure-before-Copy-Item invariant: SHA mismatch path leaves $WeaselDll
    unchanged (assertEqual byte-for-byte)
  - No hardcoded hash literal in the script (CP-2 anti-pattern 3)
  - Script declares the new env surface (SMOODLE_SHA256_SIDECAR,
    SMOODLE_SHA256_LIVE_URL)

REQ E2EWIN-03 (SHA256 verify) + E2EWIN-05 (Authenticode regression guard,
script-level mirror of Plan 03-01's Pester runtime check).
ROADMAP Phase 3 SC #5 (SHA256 verify pre-swap).

Cross-platform note: tests run pwsh (PowerShell 7+; macOS / Linux dev box
via brew install --cask powershell or apt install powershell). Phase 1
ci.yml ubuntu-latest has pwsh preinstalled. The Get-AuthenticodeSignature
cmdlet is Win-only - tests that need it use string-grep against the script
source rather than runtime invocation. The SHA verify path is fully
cross-platform.

If pwsh is unavailable at test time, ALL pwsh-invoking tests skip (via
@unittest.skipUnless decorator). The grep-only tests still run, providing
non-zero coverage on bare-bones machines.
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
SCRIPT = REPO_ROOT / "scripts" / "install-librime-fork.ps1"
SIDECAR = REPO_ROOT / "vendor" / "windows" / "rime.dll.sha256"
VENDORED_DLL = REPO_ROOT / "vendor" / "windows" / "rime.dll"

# A guaranteed-404 file:// URL — used to force the live-sidecar fetch to fail
# so the vendored-fallback path runs. Mirrors Phase 2 mac's pattern.
GUARANTEED_404_URL = "file:///nonexistent/smoodle/test/should/404.sha256"

# Detect pwsh availability for skipUnless decorator. pwsh = PowerShell 7+
# (cross-platform); powershell.exe = Win-only fallback. Phase 1 ci.yml's
# ubuntu-latest has pwsh preinstalled (verified at Phase 1 plan time).
_PWSH = shutil.which("pwsh") or shutil.which("powershell")
_HAS_PWSH = _PWSH is not None


class TestInstallLibrimeForkWin(unittest.TestCase):
    """Plan 03-02 SHA verify + Authenticode diagnostic tests."""

    def setUp(self) -> None:
        self.tmp = Path(tempfile.mkdtemp(prefix="smoodle-win-test-"))
        self.addCleanup(shutil.rmtree, self.tmp, ignore_errors=True)

    # --- helpers -----------------------------------------------------------

    def _make_fixture_dll(self, name: str, content: bytes) -> Path:
        path = self.tmp / name
        path.write_bytes(content)
        return path

    def _make_fixture_weasel_dir(self, dll_content: bytes = b"FIXTURE_RIME_DLL") -> Path:
        """Create a fake Weasel install dir with a fixture rime.dll inside."""
        weasel = self.tmp / "weasel-test"
        weasel.mkdir(parents=True, exist_ok=True)
        (weasel / "rime.dll").write_bytes(dll_content)
        return weasel

    def _run_script(
        self,
        env_overrides: dict,
        expect_exit: int,
    ) -> subprocess.CompletedProcess:
        """Invoke install-librime-fork.ps1 via pwsh with the supplied env."""
        env = os.environ.copy()
        env.update({
            "SMOODLE_SKIP_SWAP": "1",       # never Copy-Item in tests
            "SMOODLE_NONINTERACTIVE": "1",
            "SMOODLE_SKIP_DOWNLOAD": "0",   # Phase 2 lesson: do NOT short-circuit
        })
        env.update(env_overrides)
        result = subprocess.run(
            [_PWSH, "-NoProfile", "-ExecutionPolicy", "Bypass", "-File", str(SCRIPT)],
            env=env,
            capture_output=True,
            text=True,
        )
        self.assertEqual(
            result.returncode, expect_exit,
            f"unexpected exit code (got {result.returncode}, want {expect_exit})\n"
            f"stdout=\n{result.stdout}\nstderr=\n{result.stderr}",
        )
        return result

    # --- tests (cross-platform: grep-only) ---------------------------------

    def test_sidecar_fixture_format_strict(self) -> None:
        """The committed vendor/windows/rime.dll.sha256 must be 64 lowercase hex."""
        self.assertTrue(SIDECAR.exists(), f"missing {SIDECAR}")
        content = SIDECAR.read_text().strip()
        self.assertRegex(
            content, r"^[a-f0-9]{64}$",
            f"sidecar must be 64 lowercase hex chars, got: {content!r}",
        )

    def test_sidecar_matches_vendored_dll(self) -> None:
        """The vendored vendor/windows/rime.dll.sha256 must equal the SHA-256
        of vendor/windows/rime.dll computed via stdlib hashlib.

        This is the sidecar-matches-DLL invariant: protects against silent DLL
        bumps without sidecar updates AND against silent sidecar typos.
        """
        self.assertTrue(VENDORED_DLL.exists(), f"missing {VENDORED_DLL}")
        self.assertTrue(SIDECAR.exists(), f"missing {SIDECAR}")
        actual_hash = hashlib.sha256(VENDORED_DLL.read_bytes()).hexdigest()
        sidecar_content = SIDECAR.read_text().strip()
        self.assertEqual(
            actual_hash, sidecar_content,
            f"sidecar drift detected:\n  vendored DLL SHA-256: {actual_hash}\n"
            f"  sidecar content:    {sidecar_content!r}\n"
            f"  re-run: pwsh -c (Get-FileHash -Algorithm SHA256 vendor/windows/rime.dll).Hash.ToLower() | Out-File -Encoding utf8 vendor/windows/rime.dll.sha256",
        )

    def test_script_declares_new_env_surface(self) -> None:
        """The Plan 03-02 env vars must all be referenced in install-librime-fork.ps1."""
        body = SCRIPT.read_text(encoding="utf-8")
        for var in (
            "SMOODLE_SHA256_SIDECAR",
            "SMOODLE_SHA256_LIVE_URL",
        ):
            self.assertIn(var, body, f"install-librime-fork.ps1 missing env surface: {var}")

    def test_no_hardcoded_hash_literal(self) -> None:
        """CP-2 anti-pattern 3: no `$VARHASH=...64hex...` literal embedded in the script."""
        import re
        body = SCRIPT.read_text(encoding="utf-8")
        # Pattern: a $-prefixed variable name containing "HASH" assigned to a
        # 64-hex string literal.
        bad = re.compile(
            r"^\s*\$[A-Za-z0-9_]*HASH[A-Za-z0-9_]*\s*=\s*['\"][a-f0-9]{64}['\"]",
            re.MULTILINE | re.IGNORECASE,
        )
        match = bad.search(body)
        self.assertIsNone(
            match,
            f"hardcoded hash literal found (CP-2 violation): {match.group(0) if match else None}",
        )

    def test_authenticode_diagnostic_block_present(self) -> None:
        """E2EWIN-05 script-level: Get-AuthenticodeSignature post-swap diagnostic
        and verbatim regression-guard string."""
        body = SCRIPT.read_text(encoding="utf-8")
        self.assertIn("Get-AuthenticodeSignature", body)
        # Verbatim regression-guard string (matches Plan 03-01 Pester Describe 4
        # so any drift surfaces in BOTH places).
        self.assertIn(
            "Weasel rime.dll signature changed; review fork upgrade vs. supply-chain compromise before unblocking",
            body,
            "verbatim regression-guard string missing from install-librime-fork.ps1 Authenticode block",
        )

    def test_authenticode_diagnostic_after_copy_item(self) -> None:
        """Sequence check: Authenticode diagnostic line is AFTER the Copy-Item-to-Weasel line.

        Reads the script body, finds the FIRST occurrence of the relevant
        Copy-Item invocation and the FIRST occurrence of the relevant
        Get-AuthenticodeSignature invocation, and asserts ordering.
        """
        body = SCRIPT.read_text(encoding="utf-8").splitlines()
        copy_idx = None
        auth_idx = None
        for i, line in enumerate(body):
            if copy_idx is None and "Copy-Item -Path $DllOut -Destination $WeaselDll" in line:
                copy_idx = i
            if auth_idx is None and "Get-AuthenticodeSignature -FilePath $WeaselDll" in line:
                auth_idx = i
        self.assertIsNotNone(copy_idx, "Copy-Item-to-WeaselDll line not found")
        self.assertIsNotNone(auth_idx, "Get-AuthenticodeSignature-on-WeaselDll line not found")
        self.assertLess(
            copy_idx, auth_idx,
            f"Authenticode diagnostic must run AFTER Copy-Item; got copy={copy_idx}, auth={auth_idx}",
        )

    def test_sha_verify_before_copy_item(self) -> None:
        """Failure-before-Copy-Item invariant (T-03-02-03): SHA verify line is
        BEFORE the Copy-Item-to-Weasel line in source order."""
        body = SCRIPT.read_text(encoding="utf-8").splitlines()
        sha_idx = None
        copy_idx = None
        for i, line in enumerate(body):
            if sha_idx is None and "Get-FileHash -Algorithm SHA256 -Path $DllOut" in line:
                sha_idx = i
            if copy_idx is None and "Copy-Item -Path $DllOut -Destination $WeaselDll" in line:
                copy_idx = i
        self.assertIsNotNone(sha_idx, "SHA verify Get-FileHash line not found")
        self.assertIsNotNone(copy_idx, "Copy-Item-to-WeaselDll line not found")
        self.assertLess(
            sha_idx, copy_idx,
            f"SHA verify must run BEFORE Copy-Item (CP-2); got sha={sha_idx}, copy={copy_idx}",
        )

    # --- tests (pwsh-required: runtime invocation) -------------------------

    @unittest.skipUnless(_HAS_PWSH, "pwsh / powershell not available on PATH")
    def test_sha_mismatch_exits_before_swap(self) -> None:
        """REQ E2EWIN-03 / ROADMAP SC #5: corrupted DLL -> exit 1 before Copy-Item.

        Strategy: override SMOODLE_SHA256_SIDECAR to point at a sidecar with a
        bogus all-zero hash; the script's vendored-DLL primary path uses the
        committed vendor/windows/rime.dll (real SHA != bogus SHA) so the gate
        triggers. SMOODLE_WEASEL_PATH points to a fixture Weasel dir; we assert
        the rime.dll inside is unchanged after the script exits non-zero.
        """
        # Bogus sidecar (all-zero); vendored DLL is the committed real bytes.
        bogus_sha = "0" * 64
        sidecar = self._make_fixture_dll("bogus.sha256", f"{bogus_sha}\n".encode())
        weasel = self._make_fixture_weasel_dir(b"ORIGINAL_WEASEL_DLL_BYTES")
        original_dll_bytes = (weasel / "rime.dll").read_bytes()

        result = self._run_script(
            {
                "SMOODLE_SHA256_SIDECAR": str(sidecar),
                "SMOODLE_SHA256_LIVE_URL": GUARANTEED_404_URL,
                "SMOODLE_WEASEL_PATH": str(weasel),
            },
            expect_exit=1,
        )

        haystack = result.stdout + result.stderr
        # Verbatim mismatch error string
        self.assertIn("SHA256 mismatch on rime.dll", haystack)
        # Both expected and actual hashes surface for debuggability (T-03-02-04
        # accepted disposition).
        self.assertIn(bogus_sha, haystack)
        # CP-2 protection log marker.
        self.assertIn("CP-2 supply-chain protection", haystack)
        # Failure-before-Copy-Item invariant: $WeaselDll unchanged.
        self.assertEqual(
            (weasel / "rime.dll").read_bytes(), original_dll_bytes,
            "Copy-Item to $WeaselDll must NOT have executed on SHA mismatch path",
        )

    @unittest.skipUnless(_HAS_PWSH, "pwsh / powershell not available on PATH")
    def test_vendored_sidecar_used_when_live_url_404s(self) -> None:
        """When live ${SMOODLE_SHA256_LIVE_URL} returns 404, fall back to vendored sidecar.

        Verifies the script reaches the SKIP_SWAP early-exit successfully when:
          - live SHA URL is unreachable (file:// 404)
          - vendored sidecar matches the DLL hash
          - SMOODLE_SKIP_SWAP=1 set
        """
        # Use the real committed vendored sidecar + DLL (already match — that's
        # the sidecar-matches-DLL invariant).
        weasel = self._make_fixture_weasel_dir(b"ANY_BYTES_SKIP_SWAP_PROTECTS")

        # Default (no SMOODLE_SHA256_SIDECAR override) -> script resolves to
        # the committed vendor/windows/rime.dll.sha256.
        result = self._run_script(
            {
                "SMOODLE_SHA256_LIVE_URL": GUARANTEED_404_URL,
                "SMOODLE_WEASEL_PATH": str(weasel),
            },
            expect_exit=0,
        )

        haystack = result.stdout + result.stderr
        self.assertIn("vendored sidecar", haystack)
        self.assertIn("SHA256 verify passed", haystack)
        # SKIP_SWAP=1 path -> no Copy-Item-to-Weasel.
        self.assertNotIn("Weasel's rime.dll is now", haystack)


if __name__ == "__main__":
    unittest.main(verbosity=2)
