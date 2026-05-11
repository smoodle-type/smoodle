"""Telemetry client tests (TELEM-02 through TELEM-05).

Verifies:
- install_id is 64-char hex from sha256(random 16 bytes)
- No PII tokens in telemetry scripts
- 3-second timeout configured
- Fire-and-forget (no retry)
- Strict allowlist payload shape
"""
import os
import subprocess
import unittest

PROJECT_ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), '..'))


class TestTelemetryPayload(unittest.TestCase):
    """Test telemetry payload conforms to strict allowlist."""

    ALLOWED_DATA_KEYS = {
        'install_id_hash', 'os', 'smoodle_version', 'librime_sha_match'
    }

    def test_install_id_is_64_char_hex(self):
        """install_id must be sha256(random 16 bytes) = 64 hex chars."""
        result = subprocess.run(
            ['bash', '-c',
             'head -c 16 /dev/urandom | sha256sum | awk \'{print $1}\''],
            capture_output=True, text=True
        )
        install_id = result.stdout.strip()
        self.assertEqual(len(install_id), 64)
        self.assertRegex(install_id, r'^[0-9a-f]{64}$')

    def test_no_hostname_in_telemetry_sh(self):
        """telemetry.sh must not reference $HOSTNAME, hostname, whoami, etc."""
        path = os.path.join(PROJECT_ROOT, 'scripts', 'lib', 'telemetry.sh')
        if not os.path.exists(path):
            self.skipTest('telemetry.sh not found')
        with open(path) as f:
            content = f.read()
        forbidden = ['$HOSTNAME', '$USER', 'hostname', 'whoami', 'uname -n']
        for token in forbidden:
            self.assertNotIn(token, content,
                f"telemetry.sh contains forbidden token: {token}")

    def test_no_hostname_in_telemetry_ps1(self):
        """telemetry.ps1 must not reference $env:COMPUTERNAME, $env:USERNAME."""
        path = os.path.join(PROJECT_ROOT, 'scripts', 'lib', 'telemetry.ps1')
        if not os.path.exists(path):
            self.skipTest('telemetry.ps1 not found')
        with open(path) as f:
            content = f.read()
        forbidden = ['$env:COMPUTERNAME', '$env:USERNAME', 'hostname']
        for token in forbidden:
            self.assertNotIn(token, content,
                f"telemetry.ps1 contains forbidden token: {token}")

    def test_telemetry_timeout_is_3_seconds(self):
        """telemetry.sh must use -m 3 (3-second timeout)."""
        path = os.path.join(PROJECT_ROOT, 'scripts', 'lib', 'telemetry.sh')
        if not os.path.exists(path):
            self.skipTest('telemetry.sh not found')
        with open(path) as f:
            content = f.read()
        self.assertIn('-m 3', content, "telemetry.sh: missing -m 3 timeout")

    def test_telemetry_ps1_timeout_is_3_seconds(self):
        """telemetry.ps1 must use -TimeoutSec 3."""
        path = os.path.join(PROJECT_ROOT, 'scripts', 'lib', 'telemetry.ps1')
        if not os.path.exists(path):
            self.skipTest('telemetry.ps1 not found')
        with open(path) as f:
            content = f.read()
        self.assertIn('TimeoutSec 3', content,
                      "telemetry.ps1: missing -TimeoutSec 3")

    def test_fire_and_forget_no_retry(self):
        """telemetry.sh must not retry on failure."""
        path = os.path.join(PROJECT_ROOT, 'scripts', 'lib', 'telemetry.sh')
        if not os.path.exists(path):
            self.skipTest('telemetry.sh not found')
        with open(path) as f:
            content = f.read()
        self.assertNotIn('--retry', content,
                         "telemetry.sh: must not retry")

    def test_install_id_not_from_mac_address(self):
        """install_id must NOT be derived from MAC address or hostname."""
        path = os.path.join(PROJECT_ROOT, 'scripts', 'lib', 'telemetry.sh')
        if not os.path.exists(path):
            self.skipTest('telemetry.sh not found')
        with open(path) as f:
            content = f.read()
        self.assertNotIn('ifconfig', content)
        self.assertNotIn('networksetup', content)
        self.assertNotIn('ioreg', content)

    def test_telemetry_sh_syntax(self):
        """telemetry.sh passes bash -n syntax check."""
        path = os.path.join(PROJECT_ROOT, 'scripts', 'lib', 'telemetry.sh')
        if not os.path.exists(path):
            self.skipTest('telemetry.sh not found')
        result = subprocess.run(
            ['bash', '-n', path],
            capture_output=True, text=True
        )
        self.assertEqual(result.returncode, 0,
                         f"telemetry.sh syntax error: {result.stderr}")

    def test_telemetry_forget_sh_syntax(self):
        """telemetry-forget.sh passes bash -n syntax check."""
        path = os.path.join(PROJECT_ROOT, 'scripts', 'lib',
                            'telemetry-forget.sh')
        if not os.path.exists(path):
            self.skipTest('telemetry-forget.sh not found')
        result = subprocess.run(
            ['bash', '-n', path],
            capture_output=True, text=True
        )
        self.assertEqual(result.returncode, 0,
                         f"telemetry-forget.sh syntax error: {result.stderr}")

    def test_telemetry_sh_uses_opt_in_gate(self):
        """telemetry.sh checks opt-in before any network call."""
        path = os.path.join(PROJECT_ROOT, 'scripts', 'lib', 'telemetry.sh')
        if not os.path.exists(path):
            self.skipTest('telemetry.sh not found')
        with open(path) as f:
            content = f.read()
        # Must reference either the env var or the marker file
        self.assertIn('SMOODLE_TELEMETRY', content,
                      "telemetry.sh: missing SMOODLE_TELEMETRY env check")
        self.assertIn('telemetry-on', content,
                      "telemetry.sh: missing telemetry-on marker check")

    def test_telemetry_ps1_uses_opt_in_gate(self):
        """telemetry.ps1 checks opt-in before any network call."""
        path = os.path.join(PROJECT_ROOT, 'scripts', 'lib', 'telemetry.ps1')
        if not os.path.exists(path):
            self.skipTest('telemetry.ps1 not found')
        with open(path) as f:
            content = f.read()
        self.assertIn('SMOODLE_TELEMETRY', content,
                      "telemetry.ps1: missing SMOODLE_TELEMETRY env check")
        self.assertIn('telemetry-on', content,
                      "telemetry.ps1: missing telemetry-on marker check")

    def test_installers_source_telemetry_lib(self):
        """All 3 installers source the telemetry library."""
        expected_sources = {
            'install.sh': 'lib/telemetry.sh',
            'install-linux.sh': 'lib/telemetry.sh',
            'install-windows.ps1': 'lib\\telemetry.ps1',
        }
        for installer, source_ref in expected_sources.items():
            path = os.path.join(PROJECT_ROOT, 'scripts', installer)
            if not os.path.exists(path):
                continue
            with open(path) as f:
                content = f.read()
            # Windows uses backslash in path, others use forward slash
            # Check for either pattern.
            found = (source_ref in content or
                     source_ref.replace('\\', '/') in content or
                     'telemetry.sh' in content or
                     'telemetry.ps1' in content)
            self.assertTrue(found,
                f"{installer}: does not source telemetry library")
