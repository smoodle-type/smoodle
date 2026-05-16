#!/usr/bin/env bash
# smoodle installer
# Copies schema YAMLs to ~/Library/Rime/, attempts auto-deploy via Squirrel
# restart (10s timeout), falls back to manual Deploy instructions.
#
# Usage: ./scripts/install.sh

set -euo pipefail

SMOODLE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# Path overrides (default to production locations; tests sandbox via env).
RIME_DIR="${SMOODLE_RIME_DIR:-${HOME}/Library/Rime}"
SQUIRREL_PATH="${SMOODLE_SQUIRREL_PATH:-/Library/Input Methods/Squirrel.app}"
SQUIRREL_BUNDLE_ID="im.rime.inputmethod.Squirrel"
DEPLOY_TIMEOUT_SECS="${SMOODLE_DEPLOY_TIMEOUT_SECS:-10}"
# When set to 0, skip the kill+restart block (tests use this to avoid
# touching the user's running Squirrel; production default is 1).
AUTO_DEPLOY="${SMOODLE_AUTO_DEPLOY:-1}"

# --- Uninstall mode (DOCS-04) ------------------------------------------------
if [[ "${1:-}" == "--uninstall" ]]; then
  echo "smoodle uninstaller (macOS)"
  echo "==========================="
  echo "  removing: ${RIME_DIR}/thai_phonetic.schema.yaml"
  echo "  removing: ${RIME_DIR}/thai_phonetic.dict.yaml"
  echo "  removing: ${RIME_DIR}/default.custom.yaml"
  echo "  removing: ${HOME}/.smoodle/ (telemetry data)"
  echo

  removed=0
  for f in thai_phonetic.schema.yaml thai_phonetic.dict.yaml default.custom.yaml; do
    if [[ -f "${RIME_DIR}/${f}" ]]; then
      rm -f "${RIME_DIR}/${f}"
      echo "  removed ${f}"
      removed=$((removed + 1))
    fi
  done
  if [[ -d "${HOME}/.smoodle" ]]; then
    rm -rf "${HOME}/.smoodle"
    echo "  removed ~/.smoodle/ (telemetry data)"
  fi
  if [[ "$removed" -eq 0 ]] && [[ ! -d "${HOME}/.smoodle" ]]; then
    echo "  Nothing to remove (already clean)."
  else
    echo
    echo "  Uninstall complete. Restart Squirrel to apply."
  fi
  exit 0
fi

# --- Source telemetry helper (TELEM-02) -------------------------------------
# When not opted in, this is a no-op (zero network traffic).
. "$(dirname "${BASH_SOURCE[0]}")/lib/telemetry.sh"

# Portable timeout helper. macOS does not ship GNU `timeout` by default.
# Returns 124 on timeout (matches GNU timeout convention).
run_with_timeout() {
  local secs="$1"; shift
  perl -e '
    use strict;
    my $secs = shift @ARGV;
    my $pid = fork();
    if ($pid == 0) { exec @ARGV or die "exec: $!"; }
    eval {
      local $SIG{ALRM} = sub { kill "TERM", $pid; sleep 1; kill "KILL", $pid; die "timeout\n"; };
      alarm $secs;
      waitpid $pid, 0;
      alarm 0;
      exit($? >> 8);
    };
    if ($@ =~ /timeout/) { exit 124; }
  ' "$secs" "$@"
}

echo "smoodle installer"
echo "================="
echo "  source:      ${SMOODLE_DIR}/schema/"
echo "  destination: ${RIME_DIR}/"
echo

# --- Telemetry: install_started (TELEM-04) ----------------------------------
smoodle_telemetry_event "install_started"

# --- Pre-flight: verify Squirrel host present -------------------------------
if [ ! -e "${SQUIRREL_PATH}" ]; then
  echo "ERROR: Squirrel.app is not installed at ${SQUIRREL_PATH}."
  echo "       Install it first:  brew install --cask squirrel-app"
  exit 1
fi

# --- Copy schema YAMLs (idempotent, with timestamped backup) ----------------
mkdir -p "${RIME_DIR}"

for f in thai_phonetic.schema.yaml thai_phonetic.dict.yaml default.custom.yaml; do
  src="${SMOODLE_DIR}/schema/${f}"
  dst="${RIME_DIR}/${f}"
  if [ ! -f "${src}" ]; then
    echo "ERROR: missing source file: ${src}"
    exit 1
  fi
  if [ -f "${dst}" ] && ! diff -q "${src}" "${dst}" >/dev/null 2>&1; then
    backup="${dst}.bak.$(date +%Y%m%d-%H%M%S)"
    echo "  backing up existing ${dst} → ${backup}"
    mv "${dst}" "${backup}"
  fi
  cp "${src}" "${dst}"
  echo "  installed ${f}"
done

# --- Post-copy verification: all three YAMLs must exist at destination ------
for f in thai_phonetic.schema.yaml thai_phonetic.dict.yaml default.custom.yaml; do
  if [ ! -f "${RIME_DIR}/${f}" ]; then
    echo "ERROR: post-copy verification failed: ${RIME_DIR}/${f} missing."
    exit 1
  fi
done

# --- Telemetry: schema_copied (TELEM-04) ------------------------------------
smoodle_telemetry_event "schema_copied"

# --- HARDEN-07: Touch schema files to force Squirrel to recompile ----------
# This mirrors the Windows LastWriteTime = Get-Date pattern (install-windows.ps1).
# Without this, rsync from Time Machine or other backup tools can restore
# schema YAMLs with stale mtimes that Squirrel considers "already compiled."
for f in thai_phonetic.schema.yaml thai_phonetic.dict.yaml; do
  touch -m "${RIME_DIR}/${f}"
done

# --- Attempt auto-deploy: kill Squirrel + restart (timeout-bounded) ---------
# Squirrel deploys schemas on launch when YAMLs have changed since last build.
# This is more reliable than osascript or rime_deployer (which require extra
# tools and can hang). 10s timeout per Critical Failure Mode #3.
echo

if [ "${AUTO_DEPLOY}" != "1" ]; then
  echo "Auto-deploy skipped (SMOODLE_AUTO_DEPLOY=${AUTO_DEPLOY})."
  echo "Click Squirrel's menu-bar icon → 'Deploy' to compile schemas."
  exit 0
fi

echo "Attempting auto-deploy via Squirrel restart..."

auto_deploy_ok=0
if pgrep -x Squirrel >/dev/null 2>&1; then
  if run_with_timeout "${DEPLOY_TIMEOUT_SECS}" osascript -e \
      'tell application id "im.rime.inputmethod.Squirrel" to quit' >/dev/null 2>&1; then
    sleep 1
    if run_with_timeout "${DEPLOY_TIMEOUT_SECS}" \
        open -b "${SQUIRREL_BUNDLE_ID}" >/dev/null 2>&1; then
      auto_deploy_ok=1
    fi
  fi
else
  if run_with_timeout "${DEPLOY_TIMEOUT_SECS}" \
      open -b "${SQUIRREL_BUNDLE_ID}" >/dev/null 2>&1; then
    auto_deploy_ok=1
  fi
fi

if [ "${auto_deploy_ok}" = "1" ]; then
  echo "  ✓ Squirrel restarted; schemas will compile on first activation."
  smoodle_telemetry_event "deploy_success"
else
  echo "  ⚠ Auto-deploy failed or timed out after ${DEPLOY_TIMEOUT_SECS}s."
  echo "    Manual fallback:"
  echo "      Click Squirrel's menu-bar icon → 'Deploy' (recompiles schemas)."
  smoodle_telemetry_event "deploy_timeout" "false"
fi

# --- Telemetry opt-in prompt (TELEM-04) -------------------------------------
# Only prompt if not already opted in.
if [[ "${SMOODLE_TELEMETRY:-}" != "1" ]] && [[ ! -f "${HOME}/.smoodle/telemetry-on" ]]; then
  echo
  echo "Telemetry (opt-in, default OFF)"
  echo "  Sends an anonymous install ping to telemetry.0dl.me"
  echo "  Payload: {install_id_hash, os, smoodle_version, librime_sha_match}"
  echo "  No hostname, username, or personal data is sent."
  echo "  Disable anytime: rm ~/.smoodle/telemetry-on"
  echo

  read -rp "  Enable telemetry? [y/N]: " _smoodle_telemetry_answer
  if [[ "$_smoodle_telemetry_answer" == "y" || "$_smoodle_telemetry_answer" == "Y" ]]; then
    mkdir -p "${HOME}/.smoodle"
    # Generate install_id if not already present
    if [[ ! -f "${HOME}/.smoodle/install_id" ]]; then
      head -c 16 /dev/urandom | sha256sum | awk '{print $1}' > "${HOME}/.smoodle/install_id"
    fi
    touch "${HOME}/.smoodle/telemetry-on"
    echo "  Telemetry enabled. Thank you!"
    export SMOODLE_TELEMETRY=1
    # Fire the install_completed event now that user just opted in.
    smoodle_telemetry_event "install_completed"
  else
    echo "  Telemetry disabled. No data will be sent."
  fi
fi

# --- Test instructions (post-install verification by user) ------------------
cat <<'EOF'

Files installed. To verify:
  1. Click Squirrel's menu-bar icon → 'Deploy' (if auto-deploy didn't run).
  2. Press Ctrl+` to open the schema switcher; pick 'smoodle Thai phonetic'.
  3. Open Notes.app and type 'sawadee'.
     Expect candidate window with: สวัสดี

If 'smoodle Thai phonetic' doesn't appear in the schema switcher:
  - Check Squirrel's Console.app log for compilation errors.
  - Verify ~/Library/Rime/ contains the three YAML files above.
  - Try the manual Deploy click; auto-restart can race on first install.

Note: this build uses smoodle's patched librime (smoodle-type/librime fork,
tagged 1.16.0-smoodle.1). If Squirrel was updated via Sparkle since
your last smoodle install, the bundled librime.1.dylib in
${SQUIRREL_PATH}/Contents/Frameworks/ may have been overwritten. Run
'bash scripts/verify-librime.sh' to detect drift; if it exits non-zero,
re-run 'bash scripts/install-librime-fork.sh' to re-swap the patched dylib.
EOF
