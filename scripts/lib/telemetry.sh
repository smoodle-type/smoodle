# smoodle telemetry client — Bash fire-and-forget POST helper (TELEM-02)
#
# Sourced by install.sh and install-linux.sh.
# Usage:
#   . "$(dirname "$0")/lib/telemetry.sh"
#   smoodle_telemetry_event "install_started"
#   smoodle_telemetry_event "schema_copied" "true"
#
# Opt-in: SMOODLE_TELEMETRY=1 env or ~/.smoodle/telemetry-on marker file.
# When not opted in, this file is a no-op (zero network traffic).
#
# Hard 3s timeout, no retries, no daemon, never blocks installer.

SMOODLE_TELEMETRY_URL="${SMOODLE_TELEMETRY_URL:-https://telemetry.0dl.me/api/send}"
SMOODLE_TELEMETRY_WEBSITE="${SMOODLE_TELEMETRY_WEBSITE:-88042064-eeea-465a-8658-002d978d4f9b}"
SMOODLE_VERSION="${SMOODLE_VERSION:-0.0.6}"

_smoodle_telemetry_is_opted_in() {
  if [[ "${SMOODLE_TELEMETRY:-}" == "1" ]]; then
    return 0
  fi
  if [[ -f "${HOME}/.smoodle/telemetry-on" ]]; then
    return 0
  fi
  return 1
}

_smoodle_telemetry_ensure_install_id() {
  local install_id_file="${HOME}/.smoodle/install_id"
  if [[ ! -f "$install_id_file" ]]; then
    mkdir -p "${HOME}/.smoodle"
    head -c 16 /dev/urandom | sha256sum | awk '{print $1}' > "$install_id_file"
  fi
  cat "$install_id_file"
}

smoodle_telemetry_event() {
  local event="$1"
  local librime_sha_match="${2:-true}"

  # Opt-in gate — fast path, no network if not opted in.
  if ! _smoodle_telemetry_is_opted_in; then
    return 0
  fi

  # Telemetry URL override — empty means disabled (never block install).
  if [[ -z "${SMOODLE_TELEMETRY_URL}" ]]; then
    return 0
  fi

  local install_id_hash
  install_id_hash="$(_smoodle_telemetry_ensure_install_id)"

  # Detect OS
  local os_name="linux"
  if [[ "$(uname)" == "Darwin" ]]; then
    os_name="macos"
  fi

  local payload
  payload=$(printf '{"type":"event","payload":{"website":"%s","url":"/install","name":"%s","data":{"install_id_hash":"%s","os":"%s","smoodle_version":"%s","librime_sha_match":%s}}}' \
    "${SMOODLE_TELEMETRY_WEBSITE}" \
    "${event}" \
    "${install_id_hash}" \
    "${os_name}" \
    "${SMOODLE_VERSION}" \
    "${librime_sha_match}")

  # Fire-and-forget: background subshell, 3s timeout, swallow all output.
  (
    curl -fsS -m 3 -X POST \
      -H "Content-Type: application/json" \
      -d "$payload" \
      "${SMOODLE_TELEMETRY_URL}" \
      >/dev/null 2>&1 || true
  ) &
  disown 2>/dev/null || true
}
