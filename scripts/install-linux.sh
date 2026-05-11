#!/usr/bin/env bash
# smoodle Linux installer (Lane C)
#
# Schema-only install per docs/LANE-C-LINUX.md option 3: copies schema
# YAMLs to the right per-IM dir (fcitx5 or ibus, autodetected from the
# running process), attempts auto-deploy with timeout, prints test
# instructions including the librime ranking limitation note.
#
# This installer does NOT swap libRime.so. Linux uses the distro's
# system librime (apt/pacman), which lacks the
# DictEntryIterator::Peek first-call sort fix shipped on macOS via
# the smoodle-type/librime fork. See "Ranking limitation" in the
# trailing test instructions.
#
# Usage: ./scripts/install-linux.sh

set -euo pipefail

SMOODLE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DEPLOY_TIMEOUT_SECS="${SMOODLE_DEPLOY_TIMEOUT_SECS:-10}"
# When set to 0, skip the deploy block (tests use this to avoid touching
# the user's running IM; production default is 1).
AUTO_DEPLOY="${SMOODLE_AUTO_DEPLOY:-1}"

# --- Uninstall mode (DOCS-04) ------------------------------------------------
if [[ "${1:-}" == "--uninstall" ]]; then
  echo "smoodle uninstaller (Linux)"
  echo "==========================="

  # Detect IM to find the right dir
  IM="${SMOODLE_IM:-}"
  if [[ -z "$IM" ]]; then
    if pgrep -x fcitx5 >/dev/null 2>&1; then
      IM=fcitx5
    elif pgrep -x ibus-daemon >/dev/null 2>&1; then
      IM=ibus
    else
      echo "ERROR: no IM running. Override with SMOODLE_IM=fcitx5 or SMOODLE_IM=ibus"
      exit 1
    fi
  fi

  case "${IM}" in
    fcitx5) RIME_DIR="${SMOODLE_RIME_DIR:-${HOME}/.local/share/fcitx5/rime}" ;;
    ibus)   RIME_DIR="${SMOODLE_RIME_DIR:-${HOME}/.config/ibus/rime}" ;;
    *)      echo "ERROR: unsupported IM '${IM}'"; exit 1 ;;
  esac

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
    echo "  Uninstall complete. Restart ${IM} to apply."
  fi
  exit 0
fi

# --- Source telemetry helper (TELEM-02) -------------------------------------
. "$(dirname "${BASH_SOURCE[0]}")/lib/telemetry.sh"

# --- Detect host IM ---------------------------------------------------------
# Hybrid setups exist (fcitx5 installed but ibus running, etc) — detect
# by *running process*, not by binary presence. SMOODLE_IM env var
# overrides for tests.
detect_running_im() {
  if [ -n "${SMOODLE_IM:-}" ]; then
    echo "${SMOODLE_IM}"
    return 0
  fi
  if pgrep -x fcitx5 >/dev/null 2>&1; then
    echo "fcitx5"
    return 0
  fi
  if pgrep -x ibus-daemon >/dev/null 2>&1; then
    echo "ibus"
    return 0
  fi
  return 1
}

IM="$(detect_running_im || true)"
if [ -z "${IM}" ]; then
  cat <<'EOF' >&2
ERROR: no input method daemon is currently running.

smoodle needs fcitx5 or ibus active to install into the right schema dir.

If you have fcitx5 installed:    fcitx5 &
If you have ibus installed:      ibus-daemon -drxR

Or override autodetect explicitly:
  SMOODLE_IM=fcitx5 ./scripts/install-linux.sh
  SMOODLE_IM=ibus   ./scripts/install-linux.sh
EOF
  exit 1
fi

# Per-IM schema dir + reload command.
case "${IM}" in
  fcitx5)
    DEFAULT_RIME_DIR="${HOME}/.local/share/fcitx5/rime"
    DEPLOY_CMD=(fcitx5 -r)
    ;;
  ibus)
    DEFAULT_RIME_DIR="${HOME}/.config/ibus/rime"
    DEPLOY_CMD=(ibus-daemon -drxR)
    ;;
  *)
    echo "ERROR: unsupported IM '${IM}'. Expected: fcitx5 or ibus." >&2
    exit 1
    ;;
esac

RIME_DIR="${SMOODLE_RIME_DIR:-${DEFAULT_RIME_DIR}}"

echo "smoodle installer (Linux / ${IM})"
echo "================================="
echo "  source:      ${SMOODLE_DIR}/schema/"
echo "  destination: ${RIME_DIR}/"
echo

# --- Telemetry: install_started (TELEM-04) ----------------------------------
smoodle_telemetry_event "install_started"

# --- Copy schema YAMLs (idempotent, with timestamped backup) ----------------
mkdir -p "${RIME_DIR}"

for f in thai_phonetic.schema.yaml thai_phonetic.dict.yaml default.custom.yaml; do
  src="${SMOODLE_DIR}/schema/${f}"
  dst="${RIME_DIR}/${f}"
  if [ ! -f "${src}" ]; then
    echo "ERROR: missing source file: ${src}" >&2
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

# --- Post-copy verification --------------------------------------------------
for f in thai_phonetic.schema.yaml thai_phonetic.dict.yaml default.custom.yaml; do
  if [ ! -f "${RIME_DIR}/${f}" ]; then
    echo "ERROR: post-copy verification failed: ${RIME_DIR}/${f} missing." >&2
    exit 1
  fi
done

# --- Telemetry: schema_copied (TELEM-04) ------------------------------------
smoodle_telemetry_event "schema_copied"

# --- Attempt auto-deploy ----------------------------------------------------
echo

if [ "${AUTO_DEPLOY}" != "1" ]; then
  echo "Auto-deploy skipped (SMOODLE_AUTO_DEPLOY=${AUTO_DEPLOY})."
  case "${IM}" in
    fcitx5) echo "Run:  fcitx5 -r" ;;
    ibus)   echo "Run:  ibus-daemon -drxR" ;;
  esac
  exit 0
fi

echo "Attempting auto-deploy via ${IM} reload..."

auto_deploy_ok=0
if timeout "${DEPLOY_TIMEOUT_SECS}" "${DEPLOY_CMD[@]}" >/dev/null 2>&1; then
  auto_deploy_ok=1
fi

if [ "${auto_deploy_ok}" = "1" ]; then
  echo "  ✓ ${IM} reloaded; schemas will compile on first activation."
  smoodle_telemetry_event "deploy_success"
else
  echo "  ⚠ Auto-deploy failed or timed out after ${DEPLOY_TIMEOUT_SECS}s."
  echo "    Manual fallback:"
  case "${IM}" in
    fcitx5) echo "      fcitx5 -r" ;;
    ibus)   echo "      ibus-daemon -drxR" ;;
  esac
  smoodle_telemetry_event "deploy_timeout" "false"
fi

# --- Telemetry opt-in prompt (TELEM-04) -------------------------------------
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
    if [[ ! -f "${HOME}/.smoodle/install_id" ]]; then
      head -c 16 /dev/urandom | sha256sum | awk '{print $1}' > "${HOME}/.smoodle/install_id"
    fi
    touch "${HOME}/.smoodle/telemetry-on"
    echo "  Telemetry enabled. Thank you!"
    export SMOODLE_TELEMETRY=1
    smoodle_telemetry_event "install_completed"
  else
    echo "  Telemetry disabled. No data will be sent."
  fi
fi

# --- Test instructions ------------------------------------------------------
cat <<EOF

Files installed. To verify:
  1. Switch input method to 'smoodle Thai phonetic' (Ctrl+Space by default
     on most Linux desktops; check your IM tray icon).
  2. Open any text input (terminal, browser, gedit). Type 'sawadee'.
     Expect candidate window with: สวัสดี

If 'smoodle Thai phonetic' doesn't appear in the schema switcher:
  - Re-run the deploy command:
      ${DEPLOY_CMD[*]}
  - Verify ${RIME_DIR}/ contains the three YAML files above.
  - Check the IM log:
      fcitx5 -d --replace                  (fcitx5)
      ibus-daemon -v -drxR                 (ibus)

================================================================
RANKING LIMITATION (Linux only)
----------------------------------------------------------------
This Linux build uses the distro's system librime, which has a
known bug: on first lookup, the alphabetically-earlier syllable
wins position #1 regardless of weight. smoodle's algebra rules
can produce spelling variants that collide with direct dictionary
entries — those collisions may rank wrong on first lookup.

Workaround: type the input, press space (or arrow-down) to commit,
retype — second lookup ranks correctly.

This is fixed in smoodle's macOS build via a librime fork
(smoodle-type/librime, tag 1.16.0-smoodle.1). Distributing a forked
librime on Linux is out of scope for Phase 1; revisited if Linux
dogfood signal materialises.
================================================================
EOF
