#!/usr/bin/env bash
# Sync the smoodle dev tree to the Lane B Windows test bed (dockur/windows
# on th-dc) via rsync. The destination is bind-mounted into the VM as
# \\host.lan\Data — the "Shared" desktop shortcut points at it.
#
# Usage:
#   ./scripts/dev-sync-windows.sh
#
# Env overrides:
#   SMOODLE_TH_DC_HOST       SSH alias / hostname for th-dc (default: th-dc)
#   SMOODLE_TH_DC_SHARE      remote path bound into /data (default: /root/smoodle-shared)
#   SMOODLE_RSYNC_DRY_RUN    "1" to print what would change without copying
#
# Iteration loop:
#   edit on Mac  →  ./scripts/dev-sync-windows.sh  →  open Shared in VM  →  run

set -euo pipefail

TH_DC_HOST="${SMOODLE_TH_DC_HOST:-th-dc}"
TH_DC_SHARE="${SMOODLE_TH_DC_SHARE:-/root/smoodle-shared}"
DRY_RUN="${SMOODLE_RSYNC_DRY_RUN:-0}"

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

dry_flag=()
if [ "${DRY_RUN}" = "1" ]; then
  dry_flag=(--dry-run)
  echo "(dry run — no files will be copied)"
fi

echo "smoodle → ${TH_DC_HOST}:${TH_DC_SHARE}/"

rsync -avz --delete "${dry_flag[@]}" \
  --exclude='.git/' \
  --exclude='vendor/' \
  --exclude='__pycache__/' \
  --exclude='.omc/' \
  --exclude='build.log' \
  --exclude='installation.yaml' \
  --exclude='*.pyc' \
  --exclude='.DS_Store' \
  "${REPO_DIR}/" \
  "${TH_DC_HOST}:${TH_DC_SHARE}/"

echo
echo "Done. Inside the VM:"
echo "  - Click the 'Shared' desktop shortcut (or open \\\\host.lan\\Data\\)."
echo "  - Then in PowerShell:"
echo "      cd \\\\host.lan\\Data\\"
echo "      powershell -ExecutionPolicy Bypass -File .\\scripts\\install-windows.ps1"
