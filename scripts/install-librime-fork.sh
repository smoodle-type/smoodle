#!/usr/bin/env bash
# smoodle: build + install the patched librime fork
#
# Builds librime from the LoneExile/librime fork at tag 1.16.0-smoodle.1
# (peek-sort patch committed there) and swaps it into Squirrel.app's
# Frameworks/ dir. Requires sudo for the dylib swap step.
#
# Run scripts/install.sh either before or after this — that one handles
# the schema YAMLs (~/Library/Rime/) and is sudoless.
#
# Usage: ./scripts/install-librime-fork.sh
#
# Env overrides:
#   SMOODLE_LIBRIME_FORK_URL  — default: https://github.com/LoneExile/librime.git
#   SMOODLE_LIBRIME_FORK_TAG  — default: 1.16.0-smoodle.1
#   SMOODLE_SQUIRREL_PATH     — default: /Library/Input Methods/Squirrel.app
#   SMOODLE_SKIP_BUILD        — "1" to skip make (dylib must already exist)
#   SMOODLE_SKIP_SWAP         — "1" to build only (no sudo, no swap)
#   SMOODLE_FORCE_REBUILD     — "1" to wipe build/ before make
#   SMOODLE_NONINTERACTIVE    — "1" to skip the sudo confirmation prompt

set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LIBRIME_DIR="${REPO_DIR}/vendor/librime"
FORK_URL="${SMOODLE_LIBRIME_FORK_URL:-https://github.com/LoneExile/librime.git}"
FORK_TAG="${SMOODLE_LIBRIME_FORK_TAG:-1.16.0-smoodle.1}"
SQUIRREL_PATH="${SMOODLE_SQUIRREL_PATH:-/Library/Input Methods/Squirrel.app}"
SQUIRREL_DYLIB_DIR="${SQUIRREL_PATH}/Contents/Frameworks"
SQUIRREL_DYLIB="${SQUIRREL_DYLIB_DIR}/librime.1.dylib"
BACKUP_DYLIB="${SQUIRREL_DYLIB}.smoodle-backup"
BUILT_DYLIB="${LIBRIME_DIR}/build/lib/librime.1.16.0.dylib"
SKIP_BUILD="${SMOODLE_SKIP_BUILD:-0}"
SKIP_SWAP="${SMOODLE_SKIP_SWAP:-0}"
FORCE_REBUILD="${SMOODLE_FORCE_REBUILD:-0}"
NONINTERACTIVE="${SMOODLE_NONINTERACTIVE:-0}"
BREW_DEPS=(cmake boost leveldb marisa yaml-cpp opencc googletest pkg-config ninja glog)

echo "smoodle librime fork installer"
echo "==============================="
echo "  fork:        ${FORK_URL}"
echo "  tag:         ${FORK_TAG}"
echo "  vendor dir:  ${LIBRIME_DIR}"
echo "  Squirrel:    ${SQUIRREL_PATH}"
echo

# --- Pre-flight: brew deps -------------------------------------------------
missing_deps=()
for d in "${BREW_DEPS[@]}"; do
  if [ ! -d "/opt/homebrew/opt/${d}" ] && [ ! -d "/usr/local/opt/${d}" ]; then
    missing_deps+=("$d")
  fi
done
if [ ${#missing_deps[@]} -gt 0 ]; then
  echo "ERROR: missing brew deps: ${missing_deps[*]}"
  echo "       Install with:  brew install ${missing_deps[*]}"
  exit 1
fi
echo "✓ brew deps present (${#BREW_DEPS[@]}/${#BREW_DEPS[@]})"

# --- Pre-flight: Squirrel + git --------------------------------------------
if [ "${SKIP_SWAP}" != "1" ] && [ ! -d "${SQUIRREL_PATH}" ]; then
  echo "ERROR: Squirrel.app not at ${SQUIRREL_PATH}."
  echo "       Install:  brew install --cask squirrel-app"
  exit 1
fi
command -v git >/dev/null 2>&1 || { echo "ERROR: git not on PATH"; exit 1; }

# --- Source: ensure vendor/librime/ exists at (or near) the fork tag -------
if [ ! -d "${LIBRIME_DIR}/.git" ]; then
  echo "Cloning ${FORK_URL} → ${LIBRIME_DIR} (this can take a few minutes)..."
  git clone --recurse-submodules "${FORK_URL}" "${LIBRIME_DIR}"
  git -C "${LIBRIME_DIR}" checkout "${FORK_TAG}"
  git -C "${LIBRIME_DIR}" submodule update --init --recursive
else
  # Add fork as a remote if missing (so user can pull updates).
  if ! git -C "${LIBRIME_DIR}" remote get-url smoodle >/dev/null 2>&1; then
    git -C "${LIBRIME_DIR}" remote add smoodle "${FORK_URL}"
    echo "  added smoodle remote → ${FORK_URL}"
  fi
  # Ensure tag is locally available (fetch only if not).
  if ! git -C "${LIBRIME_DIR}" rev-parse "refs/tags/${FORK_TAG}" >/dev/null 2>&1; then
    echo "  fetching tag ${FORK_TAG} from smoodle..."
    git -C "${LIBRIME_DIR}" fetch smoodle "refs/tags/${FORK_TAG}:refs/tags/${FORK_TAG}"
  fi
  # Don't auto-checkout — preserves user's working state. Surface the gap.
  current="$(git -C "${LIBRIME_DIR}" describe --always --dirty 2>/dev/null || echo unknown)"
  expected="$(git -C "${LIBRIME_DIR}" rev-parse "refs/tags/${FORK_TAG}" 2>/dev/null || echo unknown)"
  head_sha="$(git -C "${LIBRIME_DIR}" rev-parse HEAD 2>/dev/null || echo unknown)"
  if [ "${head_sha}" != "${expected}" ]; then
    echo "  ⚠ vendor/librime/ HEAD is ${current}, not tag ${FORK_TAG}."
    echo "    Build will use whatever is currently checked out."
    echo "    For a clean tag-based build:"
    echo "      git -C ${LIBRIME_DIR} checkout ${FORK_TAG}"
  fi
fi
echo "✓ source ready at $(git -C "${LIBRIME_DIR}" describe --always --dirty 2>/dev/null || echo unknown)"

# --- Build ----------------------------------------------------------------
if [ "${SKIP_BUILD}" = "1" ]; then
  echo "Skipping build (SMOODLE_SKIP_BUILD=1)."
  if [ ! -f "${BUILT_DYLIB}" ]; then
    echo "ERROR: ${BUILT_DYLIB} missing. Cannot skip build without prior artifact."
    exit 1
  fi
else
  if [ "${FORCE_REBUILD}" = "1" ]; then
    echo "Wiping ${LIBRIME_DIR}/build (SMOODLE_FORCE_REBUILD=1)..."
    rm -rf "${LIBRIME_DIR}/build"
  fi
  echo "Building librime (this can take 5-15 minutes)..."
  ( cd "${LIBRIME_DIR}" && make release )
fi

# --- Verify build artifact ------------------------------------------------
if [ ! -f "${BUILT_DYLIB}" ]; then
  echo "ERROR: build did not produce ${BUILT_DYLIB}"
  exit 1
fi
size_kb=$(( $(stat -f %z "${BUILT_DYLIB}") / 1024 ))
echo "✓ built dylib: ${BUILT_DYLIB} (${size_kb} KB)"

# --- Swap (sudo) ----------------------------------------------------------
if [ "${SKIP_SWAP}" = "1" ]; then
  echo
  echo "Skipping dylib swap (SMOODLE_SKIP_SWAP=1)."
  echo "To swap manually:"
  echo "  sudo cp \"${BUILT_DYLIB}\" \"${SQUIRREL_DYLIB}\""
  exit 0
fi

echo
echo "Next: copy the patched dylib into Squirrel.app's Frameworks/."
echo "This requires sudo because ${SQUIRREL_DYLIB_DIR} is in /Library."
if [ "${NONINTERACTIVE}" != "1" ]; then
  read -r -p "Proceed? [y/N] " resp
  case "${resp}" in
    [yY]|[yY][eE][sS]) ;;
    *) echo "Aborted by user. Re-run with SMOODLE_NONINTERACTIVE=1 to skip prompt."; exit 0 ;;
  esac
fi

# Backup the original librime.1.dylib if no backup exists yet.
if [ ! -f "${BACKUP_DYLIB}" ]; then
  echo "Backing up original ${SQUIRREL_DYLIB} → ${BACKUP_DYLIB}..."
  sudo cp "${SQUIRREL_DYLIB}" "${BACKUP_DYLIB}"
else
  echo "Existing backup at ${BACKUP_DYLIB} — leaving in place."
fi

echo "Copying patched dylib..."
sudo cp "${BUILT_DYLIB}" "${SQUIRREL_DYLIB}"
new_size_kb=$(( $(stat -f %z "${SQUIRREL_DYLIB}") / 1024 ))
echo "✓ Squirrel's librime.1.dylib is now ${new_size_kb} KB."

cat <<EOF

Done. Restart Squirrel to pick up the new dylib:
  osascript -e 'tell application id "im.rime.inputmethod.Squirrel" to quit'
  open -b im.rime.inputmethod.Squirrel

Verify:
  python3 tests/test_dict.py --use-rime-api-console --fixture tests/v01_fixture.yaml
  → expect PASS 56/56

Note: Sparkle auto-update from the Rime project may overwrite this
patched dylib at any time. Re-run this script to reapply the swap.
The fork tag ${FORK_TAG} keeps the patch reproducible.
EOF
