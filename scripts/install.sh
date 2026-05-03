#!/usr/bin/env bash
# smoodle installer
# Copies schema YAMLs to ~/Library/Rime/ and prompts user to Deploy in Squirrel.
#
# Usage: ./scripts/install.sh

set -euo pipefail

SMOODLE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RIME_DIR="${HOME}/Library/Rime"

echo "smoodle installer"
echo "================="
echo "  source:      ${SMOODLE_DIR}/schema/"
echo "  destination: ${RIME_DIR}/"
echo

if [ ! -e "/Library/Input Methods/Squirrel.app" ]; then
  echo "ERROR: Squirrel.app is not installed at /Library/Input Methods/."
  echo "       Install it first:  brew install --cask squirrel-app"
  exit 1
fi

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

echo
echo "Files installed. Next steps:"
echo "  1. Click Squirrel's menu-bar icon → 'Deploy' (recompiles schemas)."
echo "  2. Press Ctrl+\` to switch input schema; pick 'smoodle Thai phonetic'."
echo "  3. Open Notes.app and type 'sawadee' → expect สวัสดี in the candidate window."
echo
echo "If 'smoodle Thai phonetic' doesn't appear in the schema switcher:"
echo "  - Check Squirrel's Console.app log for compilation errors."
echo "  - Verify ~/Library/Rime/ contains the three YAML files above."
