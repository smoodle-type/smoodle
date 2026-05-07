#!/usr/bin/env bash
# Build dist/smoodle-{version}-macOS.dmg
#
# Produces a self-contained DMG containing:
#   Install Smoodle.command  — double-click installer (opens in Terminal)
#   README.txt               — one-page install + uninstall instructions
#   schema/                  — bundled Thai phonetic YAML files
#   scripts/                 — install.sh + install-librime-fork.sh
#
# Schemas are bundled; the patched librime dylib is downloaded from GitHub
# Releases at install time (~7 MB curl, no Xcode required).
#
# Usage:  ./scripts/build-macos-dmg.sh
# Output: dist/smoodle-{version}-macOS.dmg

set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
VERSION="$(git -C "${REPO_DIR}" describe --tags --always --dirty 2>/dev/null || echo dev)"
DIST_DIR="${REPO_DIR}/dist"
STAGING="${DIST_DIR}/.dmg-staging"
VOL_NAME="Smoodle ${VERSION}"
OUT_DMG="${DIST_DIR}/smoodle-${VERSION}-macOS.dmg"

echo "smoodle DMG builder"
echo "==================="
echo "  version: ${VERSION}"
echo "  output:  ${OUT_DMG}"
echo

# --- Staging area -----------------------------------------------------------
rm -rf "${STAGING}"
mkdir -p "${STAGING}/schema" "${STAGING}/scripts"

# Bundle schema YAMLs
for f in thai_phonetic.schema.yaml thai_phonetic.dict.yaml default.custom.yaml; do
  cp "${REPO_DIR}/schema/${f}" "${STAGING}/schema/${f}"
done
echo "✓ schema files bundled (3)"

# Bundle installer scripts
cp "${REPO_DIR}/scripts/install.sh"               "${STAGING}/scripts/install.sh"
cp "${REPO_DIR}/scripts/install-librime-fork.sh"  "${STAGING}/scripts/install-librime-fork.sh"
echo "✓ installer scripts bundled (2)"

# Generate Install Smoodle.command
# BASH_SOURCE[0] inside install.sh resolves to scripts/install.sh on the
# mounted DMG, so SMOODLE_DIR correctly points to the DMG volume root where
# schema/ lives — no extra env overrides needed.
cat > "${STAGING}/Install Smoodle.command" <<'COMMAND'
#!/usr/bin/env bash
# smoodle installer — double-click this file to install.
# macOS opens .command files in Terminal automatically.
#
# If macOS shows a security warning, right-click the file → Open → Open.

set -euo pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "========================================"
echo "  smoodle Thai phonetic IME — installer"
echo "========================================"
echo

echo "Step 1/2: installing schema files..."
bash "${DIR}/scripts/install.sh"
echo

echo "Step 2/2: installing patched librime dylib..."
bash "${DIR}/scripts/install-librime-fork.sh"

echo
echo "========================================"
echo "  Done."
echo
echo "  Next steps:"
echo "  1. Click Squirrel in the menu bar → Deploy"
echo "     (wait ~10s for Thai dictionary to compile)"
echo "  2. Switch input to Squirrel: Ctrl+Space"
echo "  3. Type 'sawadee' and press Space"
echo "     Expected first candidate: สวัสดี"
echo "========================================"
COMMAND
chmod +x "${STAGING}/Install Smoodle.command"
echo "✓ Install Smoodle.command generated"

# Generate README.txt
cat > "${STAGING}/README.txt" <<README
smoodle ${VERSION} — Thai phonetic input method for macOS
==========================================================

Requirement: Squirrel (Rime for macOS) must be installed first.
  brew install --cask squirrel

Install
-------
1. Double-click "Install Smoodle.command"
   If macOS shows a security warning: right-click → Open → Open
2. Follow the Terminal prompts (one sudo password prompt for the dylib)

After install
-------------
1. Click Squirrel in the menu bar → Deploy  (wait ~10 seconds)
2. Switch input method: Ctrl+Space or Fn+Space
3. Type "sawadee" → first candidate สวัสดี → Space to commit

Typing guide (sampler)
----------------------
  sawadee    →  สวัสดี       hello
  khob khun  →  ขอบคุณ       thank you
  mai pen rai → ไม่เป็นไร    no problem
  sabai dee  →  สบายดี       I'm well

Uninstall
---------
  rm ~/Library/Rime/thai_phonetic.* ~/Library/Rime/default.custom.yaml
  sudo cp "/Library/Input Methods/Squirrel.app/Contents/Frameworks/librime.1.dylib.smoodle-backup" \
          "/Library/Input Methods/Squirrel.app/Contents/Frameworks/librime.1.dylib"

Note: Squirrel's built-in auto-updater can overwrite the patched librime.
If Thai input stops working after a Squirrel update, re-run "Install Smoodle.command".

Source: https://github.com/LoneExile/smoodle
README
echo "✓ README.txt generated"

# --- Build DMG --------------------------------------------------------------
echo "Building DMG..."
mkdir -p "${DIST_DIR}"
rm -f "${OUT_DMG}"

hdiutil create \
  -volname "${VOL_NAME}" \
  -srcfolder "${STAGING}" \
  -ov \
  -format UDZO \
  "${OUT_DMG}"

# Cleanup staging
rm -rf "${STAGING}"

# Report
size_kb=$(( $(stat -f %z "${OUT_DMG}") / 1024 ))
sha256="$(shasum -a 256 "${OUT_DMG}" | awk '{print $1}')"
echo
echo "Done."
echo "  file:   ${OUT_DMG}"
echo "  size:   ${size_kb} KB"
echo "  sha256: ${sha256}"
echo
echo "To upload to GitHub Releases:"
echo "  gh release upload v${VERSION} \"${OUT_DMG}\" -R LoneExile/smoodle"
