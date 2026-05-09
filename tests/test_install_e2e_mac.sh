#!/usr/bin/env bash
# tests/test_install_e2e_mac.sh — Lane E1 macOS E2E driver
# Invoked by .github/workflows/install-mac-e2e.yml on macos-15 runners.
# Also runnable locally (Apple Silicon Mac) for opt-in interactive verification.
#
# Locked decisions (Plan 02-01, REQ E2EMAC-01/02/05):
#   - GUI gate: SMOODLE_GUI_SESSION env var. Default 0 (skip osascript). =1 opts in.
#   - Auto-deploy: SMOODLE_AUTO_DEPLOY=0 ALWAYS forced (script's own kill+restart skipped).
#   - SHA verification: post-install dict.yaml SHA-256 == repo source SHA-256. Mismatch = exit 1.
#
# Exit codes:
#   0 — all checks pass
#   1 — schema file missing OR SHA mismatch OR install.sh exited non-zero

set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SCHEMA_DIR="${REPO_DIR}/schema"

# Honor SMOODLE_RIME_DIR (set by workflow / local dev to a sandboxed path; default = ~/Library/Rime).
RIME_DIR="${SMOODLE_RIME_DIR:-${HOME}/Library/Rime}"

# GUI session gate (CP-4 prevention). Default 0 = non-interactive (CI runner).
GUI_SESSION="${SMOODLE_GUI_SESSION:-0}"

log() { echo "[smoodle-e2e] $*"; }

log "starting macOS E2E driver"
log "  REPO_DIR=${REPO_DIR}"
log "  RIME_DIR=${RIME_DIR}"
log "  SMOODLE_GUI_SESSION=${GUI_SESSION}"

# --- Run install.sh (schema YAML copy + auto-deploy gated by AUTO_DEPLOY) ---
# Always force SMOODLE_AUTO_DEPLOY=0 — the kill+restart Squirrel path is GUI-required
# and CP-4 territory. We still exercise file-copy + SHA verification unconditionally.
log "running scripts/install.sh with SMOODLE_AUTO_DEPLOY=0"
SMOODLE_AUTO_DEPLOY=0 bash "${REPO_DIR}/scripts/install.sh"

# --- GUI gate: osascript Squirrel kill+restart path ---
# CI exports SMOODLE_GUI_SESSION=0 (this branch is taken — verbatim skip line printed).
# Local devs can opt into the full path with SMOODLE_GUI_SESSION=1.
if [ "${GUI_SESSION}" = "1" ]; then
  log "SMOODLE_GUI_SESSION=1 — exercising osascript kill+restart"
  # Best-effort attempt; do NOT exit 1 if Squirrel is not running locally.
  osascript -e 'tell application id "im.rime.inputmethod.Squirrel" to quit' >/dev/null 2>&1 || true
  sleep 1
  open -b im.rime.inputmethod.Squirrel >/dev/null 2>&1 || true
  log "osascript path attempted (best-effort; not gating exit code)"
else
  log "no-GUI-session, skipped osascript step"
fi

# --- Verify schema files exist at destination ---
log "verifying schema files at ${RIME_DIR}/"
for f in thai_phonetic.schema.yaml thai_phonetic.dict.yaml default.custom.yaml; do
  if [ ! -f "${RIME_DIR}/${f}" ]; then
    log "FAIL: missing ${RIME_DIR}/${f}"
    exit 1
  fi
done
log "OK: all 3 schema files present"

# --- SHA-256 comparison: dict.yaml destination must match repo source ---
# Use shasum -a 256 (BSD shasum, default on macOS). sha256sum is NOT installed by
# default on macos-15 runners.
log "comparing SHA-256 of installed dict.yaml against repo source"
src_sha=$(shasum -a 256 "${SCHEMA_DIR}/thai_phonetic.dict.yaml" | awk '{print $1}')
dst_sha=$(shasum -a 256 "${RIME_DIR}/thai_phonetic.dict.yaml" | awk '{print $1}')
log "  src=${src_sha}"
log "  dst=${dst_sha}"
if [ "${src_sha}" != "${dst_sha}" ]; then
  log "FAIL: SHA-256 mismatch on thai_phonetic.dict.yaml"
  exit 1
fi
log "OK: SHA-256 match"

# --- Schema file content sanity (mirrors install-linux-e2e.yml) ---
grep -q "thai_phonetic" "${RIME_DIR}/thai_phonetic.schema.yaml" \
  || { log "FAIL: thai_phonetic marker missing in schema.yaml"; exit 1; }
grep -q "thai_phonetic" "${RIME_DIR}/thai_phonetic.dict.yaml" \
  || { log "FAIL: thai_phonetic marker missing in dict.yaml"; exit 1; }

log "ALL CHECKS PASSED"
exit 0
