#!/usr/bin/env python3
"""Tests for the Plan 02-02 SHA256 + arch-refusal gate in install-librime-fork.sh.

Exercises scripts/install-librime-fork.sh with simulated env (SMOODLE_HOST_ARCH_OVERRIDE
for arch, SMOODLE_RELEASE_URL pointing at a local file:// fixture for the dylib,
SMOODLE_SHA256_LIVE_URL pointing at a local sidecar fixture or a guaranteed-404
file:// path), and asserts:

  - Arm64-only dylib + x86_64 host -> exit 1 + verbatim MP-3 error string
  - SHA mismatch -> exit 1 BEFORE any sudo cp (SMOODLE_SKIP_SWAP=1 belt-and-
    suspenders + assertNotIn "Copying patched dylib" log line)
  - Vendored sidecar fallback works when the live SHA URL 404s
  - Sequence: arch refusal fires BEFORE SHA verify (verbatim format check on
    the committed sidecar)

REQ E2EMAC-03 (SHA256 verify) + E2EMAC-04 (Intel arch refusal).
ROADMAP Phase 2 SC #3 (verbatim arch error) + SC #4 (SHA256 verify pre-swap).

Cross-platform note: tests stub `lipo`, `file`, and `sudo` via a shim PATH dir.
The script needs only curl + shasum + bash, all of which are present on macOS
runners and Linux dev boxes. Tests therefore run on the Phase 1 ci.yml ubuntu
fast path AND the Phase 2 install-mac-e2e.yml mac slow path identically.
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
SCRIPT = REPO_ROOT / "scripts" / "install-librime-fork.sh"
SIDECAR = REPO_ROOT / "vendor" / "macos" / "librime.1.dylib.sha256"

# A guaranteed-404 file:// URL — used to force the live-sidecar fetch to fail
# so the vendored-fallback path runs.
GUARANTEED_404_URL = "file:///nonexistent/smoodle/test/should/404.sha256"


class TestInstallLibrimeForkMac(unittest.TestCase):
    """Plan 02-02 SHA + arch gate tests."""

    def setUp(self) -> None:
        self.tmp = Path(tempfile.mkdtemp(prefix="smoodle-test-"))
        self.addCleanup(shutil.rmtree, self.tmp, ignore_errors=True)

    # --- helpers -----------------------------------------------------------

    def _make_shim_dir(self, *, lipo_archs: str) -> Path:
        """Create a temp dir with shim `lipo`, `file`, and `sudo` executables.

        - `lipo`: prints the supplied arch string regardless of arguments.
                  Tests use "arm64", "x86_64", or "arm64 x86_64" to drive
                  the script's arch-refusal branches.
        - `file`: prints a Mach-O magic-marker line so the script's existing
                  `file | grep Mach-O` post-download check passes regardless
                  of fixture-dylib byte content.
        - `sudo`: a no-op stub. The tests use SMOODLE_SKIP_SWAP=1 so sudo
                  should never be invoked, but the stub is defense-in-depth:
                  an accidental swap-path reach during a regression would
                  no-op instead of prompting / escalating on the dev box.
        """
        d = self.tmp / "shim"
        d.mkdir(parents=True, exist_ok=True)

        (d / "lipo").write_text(f"#!/bin/sh\necho '{lipo_archs}'\n")
        (d / "lipo").chmod(0o755)

        (d / "file").write_text(
            "#!/bin/sh\necho 'Mach-O 64-bit dynamically linked shared library'\n"
        )
        (d / "file").chmod(0o755)

        # Defense-in-depth no-op sudo (should never be reached with SKIP_SWAP=1).
        (d / "sudo").write_text("#!/bin/sh\nexit 0\n")
        (d / "sudo").chmod(0o755)

        return d

    def _write_fixture_dylib(self, name: str, content: bytes) -> Path:
        path = self.tmp / name
        path.write_bytes(content)
        return path

    def _run_script(
        self,
        env_overrides: dict,
        expect_exit: int,
        shim_dir: Path | None = None,
    ) -> subprocess.CompletedProcess:
        env = os.environ.copy()
        # Always-on test defaults: never invoke sudo, never prompt.
        # NOTE: SMOODLE_SKIP_BUILD must NOT be set here. The script's download
        # block (line 74) only runs when BOTH SKIP_DOWNLOAD and SKIP_BUILD are
        # unset — setting SKIP_BUILD=1 would short-circuit the download too,
        # leaving _downloaded="" so the SHA verify block is bypassed entirely.
        # Tests rely on the file:// fixture URL succeeding via curl, which
        # sets _downloaded=1 and prevents the script from ever reaching the
        # source-build branch (which is gated on -z "${_downloaded}").
        env.update({
            "SMOODLE_SKIP_SWAP": "1",
            "SMOODLE_NONINTERACTIVE": "1",
        })
        if shim_dir is not None:
            env["PATH"] = f"{shim_dir}:{env.get('PATH', '')}"
        env.update(env_overrides)
        result = subprocess.run(
            ["bash", str(SCRIPT)],
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

    # --- tests -------------------------------------------------------------

    def test_arch_refusal_x86_64_against_arm64_only_dylib(self) -> None:
        """REQ E2EMAC-04 / ROADMAP SC #3: x86_64 + arm64-only -> exit 1 + verbatim error."""
        shim = self._make_shim_dir(lipo_archs="arm64")
        fixture = self._write_fixture_dylib("fixture.dylib", b"FAKE_ARM64_DYLIB_CONTENTS")
        # Use a sidecar that would PASS, so we know the failure was arch and not SHA.
        # (Won't be reached anyway because arch fires first per D6.)
        sha = hashlib.sha256(b"FAKE_ARM64_DYLIB_CONTENTS").hexdigest()
        sidecar = self._write_fixture_dylib("good.sha256", f"{sha}\n".encode())

        result = self._run_script(
            {
                "SMOODLE_HOST_ARCH_OVERRIDE": "x86_64",
                "SMOODLE_RELEASE_URL": f"file://{fixture}",
                "SMOODLE_SHA256_LIVE_URL": GUARANTEED_404_URL,
                "SMOODLE_SHA256_SIDECAR": str(sidecar),
            },
            expect_exit=1,
            shim_dir=shim,
        )

        haystack = result.stdout + result.stderr
        # ROADMAP Phase 2 SC #3 verbatim string — byte-for-byte.
        self.assertIn(
            "this is an arm64-only dylib; Intel Mac not supported until universal dylib lands",
            haystack,
            "verbatim MP-3 / SC #3 error string missing",
        )
        # Failure-before-sudo invariant (T-02-02-03).
        self.assertNotIn("Copying patched dylib", haystack)
        # arch fires before SHA: the SHA verify "passed" log line must NOT appear.
        self.assertNotIn("SHA256 verify passed", haystack)

    def test_sha_mismatch_exits_before_swap(self) -> None:
        """REQ E2EMAC-03 / ROADMAP SC #4: corrupted dylib -> exit 1 before sudo cp."""
        shim = self._make_shim_dir(lipo_archs="arm64 x86_64")
        fixture = self._write_fixture_dylib("fixture.dylib", b"REAL_DYLIB_CONTENTS")
        # Bogus sidecar (all-zero hash); script must reject.
        bogus_sha = "0" * 64
        sidecar = self._write_fixture_dylib("bogus.sha256", f"{bogus_sha}\n".encode())

        result = self._run_script(
            {
                "SMOODLE_HOST_ARCH_OVERRIDE": "arm64",
                "SMOODLE_RELEASE_URL": f"file://{fixture}",
                # Force live URL fetch to fail so the vendored-fallback path serves
                # the bogus sidecar.
                "SMOODLE_SHA256_LIVE_URL": GUARANTEED_404_URL,
                "SMOODLE_SHA256_SIDECAR": str(sidecar),
            },
            expect_exit=1,
            shim_dir=shim,
        )

        haystack = result.stdout + result.stderr
        self.assertIn("SHA256 mismatch", haystack)
        # Both expected and actual hashes must surface for debuggability (T-02-02-04
        # accepted disposition).
        self.assertIn(bogus_sha, haystack)
        # Failure-before-sudo invariant: no "Copying patched dylib..." line.
        self.assertNotIn("Copying patched dylib", haystack)
        # Arch check must have passed (it ran before SHA).
        self.assertIn("arch check passed", haystack)

    def test_vendored_sidecar_used_when_live_sha_url_404s(self) -> None:
        """When live ${SMOODLE_SHA256_LIVE_URL} returns 404, fall back to vendored sidecar.

        Verifies the script reaches the swap section successfully (exits 0 under
        SMOODLE_SKIP_SWAP=1) when:
          - live SHA URL is unreachable
          - vendored sidecar matches the dylib hash
          - host arch matches dylib archs
        """
        shim = self._make_shim_dir(lipo_archs="arm64 x86_64")
        content = b"VENDORED_SIDECAR_TEST_CONTENT"
        fixture = self._write_fixture_dylib("fixture.dylib", content)
        real_sha = hashlib.sha256(content).hexdigest()
        sidecar = self._write_fixture_dylib("vendored.sha256", f"{real_sha}\n".encode())

        # SKIP_SWAP=1 makes the script exit 0 after dylib swap-section header
        # without invoking sudo cp; we want the SHA gate to pass.
        result = self._run_script(
            {
                "SMOODLE_HOST_ARCH_OVERRIDE": "arm64",
                "SMOODLE_RELEASE_URL": f"file://{fixture}",
                "SMOODLE_SHA256_LIVE_URL": GUARANTEED_404_URL,
                "SMOODLE_SHA256_SIDECAR": str(sidecar),
            },
            expect_exit=0,
            shim_dir=shim,
        )

        haystack = result.stdout + result.stderr
        # The "vendored fallback" log marker should appear (telegraphs the source).
        self.assertIn("vendored fallback", haystack)
        self.assertIn("SHA256 verify passed", haystack)
        # SKIP_SWAP=1 path -> no sudo cp executed.
        self.assertNotIn("Copying patched dylib", haystack)

    def test_sidecar_fixture_format_strict(self) -> None:
        """The committed vendor/macos/librime.1.dylib.sha256 must be 64 lowercase hex."""
        self.assertTrue(SIDECAR.exists(), f"missing {SIDECAR}")
        content = SIDECAR.read_text().strip()
        self.assertRegex(
            content, r"^[a-f0-9]{64}$",
            f"sidecar must be 64 lowercase hex chars, got: {content!r}",
        )

    def test_script_declares_new_env_surface(self) -> None:
        """The Plan 02-02 env vars must all be referenced in install-librime-fork.sh."""
        body = SCRIPT.read_text()
        for var in (
            "SMOODLE_HOST_ARCH_OVERRIDE",
            "SMOODLE_SHA256_LIVE_URL",
            "SMOODLE_SHA256_SIDECAR",
        ):
            self.assertIn(var, body, f"install-librime-fork.sh missing env surface: {var}")

    def test_no_hardcoded_hash_literal(self) -> None:
        """CP-2 anti-pattern 3: no `HASH=...64hex...` literal embedded in the script."""
        import re
        body = SCRIPT.read_text()
        # Pattern from acceptance criterion: ^[A-Za-z0-9_]*HASH[A-Za-z0-9_]*=.[a-f0-9]{64}.
        # Means: a variable name containing "HASH" assigned a 64-hex literal.
        bad = re.compile(r"^[A-Za-z0-9_]*HASH[A-Za-z0-9_]*=.[a-f0-9]{64}.", re.MULTILINE)
        match = bad.search(body)
        self.assertIsNone(
            match,
            f"hardcoded hash literal found (CP-2 violation): {match.group(0) if match else None}",
        )


if __name__ == "__main__":
    unittest.main(verbosity=2)
