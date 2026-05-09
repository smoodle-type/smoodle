#!/usr/bin/env python3
"""ASCII-only assertion for scripts/*.ps1 files (Phase 1, REQ LINT-04).

Closes MP-4 from .planning/research/PITFALLS.md: PowerShell 5.1 reads .ps1
files as Windows-1252 by default. A single non-ASCII byte (em-dash 0xE2,
smart quote 0xE2, Thai script 0xE0...) triggers `Unrecognized token in
source text` and silently breaks the Windows installer.

On a Thai-IME project the natural inclination is to put Thai characters
in install messages -- doing so in a .ps1 file is a CFM-class regression.
This test catches that class of regression at PR-time, before it reaches
the Win 11 dogfood VM.

Reference: commit 418c7ce ("fix: replace em-dashes and Thai chars in
.ps1 files (PS5.1 Windows-1252 parse error)") -- the original incident.

Usage:
  python3 tests/test_powershell_ascii.py
  python3 -m unittest tests.test_powershell_ascii

Exit codes: 0 success, 1 lint failure, 2 environment / setup error.
"""
from __future__ import annotations

import sys
import unittest
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parent.parent
SCRIPTS_DIR = REPO_ROOT / "scripts"


def find_first_non_ascii(data: bytes) -> tuple[int, int] | None:
    """Return (offset, byte_value) of first non-ASCII byte, or None."""
    for i, b in enumerate(data):
        if b >= 0x80:
            return (i, b)
    return None


def format_context(data: bytes, offset: int, span: int = 20) -> str:
    """Decode ±span bytes around offset using errors='replace'.

    Used in failure messages so contributors can locate the offense.
    """
    start = max(0, offset - span)
    end = min(len(data), offset + span + 1)
    chunk = data[start:end]
    return chunk.decode("utf-8", errors="replace")


class TestPowerShellAscii(unittest.TestCase):
    """Every scripts/*.ps1 file must be pure ASCII (no byte >= 0x80)."""

    @classmethod
    def setUpClass(cls):
        cls.ps1_files = sorted(SCRIPTS_DIR.glob("*.ps1"))
        if not cls.ps1_files:
            raise unittest.SkipTest(
                f"No .ps1 files found under {SCRIPTS_DIR}. "
                "If this is a true regression (all installers deleted), "
                "this test should fail loudly -- change to assertFail "
                "instead of skip in that scenario."
            )

    def test_each_ps1_file_is_ascii_only(self):
        offenders: list[str] = []
        for path in self.ps1_files:
            data = path.read_bytes()
            hit = find_first_non_ascii(data)
            if hit is not None:
                offset, byte_val = hit
                context = format_context(data, offset)
                offenders.append(
                    f"\n  {path.relative_to(REPO_ROOT)}\n"
                    f"    offset {offset}: byte 0x{byte_val:02X} ({byte_val})\n"
                    f"    context: {context!r}\n"
                    f"    fix: PowerShell 5.1 reads .ps1 as Windows-1252.\n"
                    f"         Use `[char]0xXXXX` or save as UTF-8 with BOM."
                )
        self.assertEqual(
            offenders, [],
            msg="Non-ASCII bytes found in .ps1 file(s):" + "".join(offenders),
        )

    def test_positive_control_detects_em_dash(self):
        """Sanity: feed a synthetic bytestring with an em-dash; the
        checker MUST detect it. Guards against the test silently no-op'ing
        (e.g. if Path.glob is broken or find_first_non_ascii regresses).
        """
        # b'\xe2\x80\x94' is U+2014 EM DASH in UTF-8.
        synthetic = b"Write-Host 'hello' \xe2\x80\x94 'world'\n"
        hit = find_first_non_ascii(synthetic)
        self.assertIsNotNone(hit, "em-dash byte sequence not detected")
        offset, byte_val = hit
        self.assertEqual(byte_val, 0xE2)
        self.assertEqual(offset, 19)  # position of \xe2 in synthetic

    def test_positive_control_detects_thai_script(self):
        """Sanity: a Thai character (e.g. ส = U+0E2A = E0 B8 AA in UTF-8)
        must be detected. The motivating regression was Thai chars in
        install messages.
        """
        # b'\xe0\xb8\xaa' is U+0E2A THAI CHARACTER SO SO in UTF-8.
        synthetic = b"Write-Host 'sawadee = \xe0\xb8\xaa\xe0\xb8\xa7'\n"
        hit = find_first_non_ascii(synthetic)
        self.assertIsNotNone(hit, "Thai byte sequence not detected")
        offset, byte_val = hit
        self.assertEqual(byte_val, 0xE0)


def main() -> int:
    if not SCRIPTS_DIR.is_dir():
        print(f"FAIL  scripts dir missing: {SCRIPTS_DIR}", file=sys.stderr)
        return 2
    ps1_count = len(list(SCRIPTS_DIR.glob("*.ps1")))
    if ps1_count == 0:
        print(
            f"FAIL  no .ps1 files found under {SCRIPTS_DIR} -- "
            "test setup error or installers deleted",
            file=sys.stderr,
        )
        return 2
    loader = unittest.TestLoader()
    suite = loader.loadTestsFromTestCase(TestPowerShellAscii)
    runner = unittest.TextTestRunner(verbosity=2)
    result = runner.run(suite)
    return 0 if result.wasSuccessful() else 1


if __name__ == "__main__":
    raise SystemExit(main())
