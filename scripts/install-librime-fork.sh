#!/usr/bin/env bash
# smoodle: install the patched librime fork into Squirrel.app
#
# Downloads a pre-built universal macOS dylib from the smoodle-type/librime
# GitHub Release for the smoodle fork tag, then swaps it into Squirrel.app's
# Frameworks/ dir.  No Xcode or brew deps required for the download path.
#
# Set SMOODLE_SKIP_DOWNLOAD=1 to build from source instead (requires Xcode
# + all brew deps, ~5-15 min).
#
# Run scripts/install.sh either before or after this — that one handles the
# schema YAMLs (~/Library/Rime/) and is sudoless.
#
# Usage: ./scripts/install-librime-fork.sh
#
# Env overrides:
#   SMOODLE_LIBRIME_FORK_TAG  — fork tag for both download and source build
#                               (default: 1.16.0-smoodle.1)
#   SMOODLE_RELEASE_URL       — full dylib download URL (default: GitHub
#                               Releases asset for SMOODLE_LIBRIME_FORK_TAG)
#   SMOODLE_SKIP_DOWNLOAD     — "1" to skip download and build from source
#   SMOODLE_LIBRIME_FORK_URL  — git URL for source builds
#                               (default: https://github.com/smoodle-type/librime.git)
#   SMOODLE_SQUIRREL_PATH     — default: /Library/Input Methods/Squirrel.app
#   SMOODLE_SKIP_BUILD        — "1" to skip make (use dylib from download or
#                               a prior build)
#   SMOODLE_SKIP_SWAP         — "1" to acquire dylib only (no sudo, no swap)
#   SMOODLE_FORCE_REBUILD     — "1" to wipe build/ before make (source builds)
#   SMOODLE_NONINTERACTIVE    — "1" to skip the sudo confirmation prompt

set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LIBRIME_DIR="${REPO_DIR}/vendor/librime"
FORK_TAG="${SMOODLE_LIBRIME_FORK_TAG:-1.16.0-smoodle.1}"
FORK_URL="${SMOODLE_LIBRIME_FORK_URL:-https://github.com/smoodle-type/librime.git}"
SQUIRREL_PATH="${SMOODLE_SQUIRREL_PATH:-/Library/Input Methods/Squirrel.app}"
SQUIRREL_DYLIB_DIR="${SQUIRREL_PATH}/Contents/Frameworks"
SQUIRREL_DYLIB="${SQUIRREL_DYLIB_DIR}/librime.1.dylib"
BACKUP_DYLIB="${SQUIRREL_DYLIB}.smoodle-backup"
BUILT_DYLIB="${LIBRIME_DIR}/build/lib/librime.1.16.0.dylib"

_ASSET_NAME="librime-${FORK_TAG}-macOS-universal.dylib"
RELEASE_URL="${SMOODLE_RELEASE_URL:-https://github.com/smoodle-type/librime/releases/download/${FORK_TAG}/${_ASSET_NAME}}"
SKIP_DOWNLOAD="${SMOODLE_SKIP_DOWNLOAD:-0}"
SKIP_BUILD="${SMOODLE_SKIP_BUILD:-0}"
SKIP_SWAP="${SMOODLE_SKIP_SWAP:-0}"
FORCE_REBUILD="${SMOODLE_FORCE_REBUILD:-0}"
NONINTERACTIVE="${SMOODLE_NONINTERACTIVE:-0}"
BREW_DEPS=(cmake boost leveldb marisa yaml-cpp opencc googletest pkg-config ninja glog)

echo "smoodle librime fork installer"
echo "==============================="
echo "  tag:      ${FORK_TAG}"
echo "  Squirrel: ${SQUIRREL_PATH}"
echo

# --- Pre-flight: Squirrel --------------------------------------------------
if [ "${SKIP_SWAP}" != "1" ] && [ ! -d "${SQUIRREL_PATH}" ]; then
  echo "ERROR: Squirrel.app not at ${SQUIRREL_PATH}."
  echo "       Install:  brew install --cask squirrel"
  exit 1
fi

# --- Acquire dylib ----------------------------------------------------------
# Primary path: download pre-built universal binary from GitHub Releases.
# Fallback:     build from source (requires Xcode + brew deps, ~5-15 min).

_tmp_dylib=""
_cleanup() { [ -n "${_tmp_dylib}" ] && rm -f "${_tmp_dylib}"; }
trap _cleanup EXIT

_downloaded=""
if [ "${SKIP_DOWNLOAD}" != "1" ] && [ "${SKIP_BUILD}" != "1" ]; then
  echo "Downloading pre-built librime from GitHub Releases..."
  echo "  ${RELEASE_URL}"
  _tmp_dylib="$(mktemp /tmp/smoodle-librime-XXXXXX.dylib)"
  if curl -fsSL -o "${_tmp_dylib}" "${RELEASE_URL}" \
      && file "${_tmp_dylib}" | grep -q "Mach-O"; then
    BUILT_DYLIB="${_tmp_dylib}"
    _downloaded="1"
    size_kb=$(( $(stat -f %z "${BUILT_DYLIB}") / 1024 ))
    echo "✓ downloaded ${size_kb} KB universal dylib"
  else
    rm -f "${_tmp_dylib}"; _tmp_dylib=""
    echo "  download failed — falling back to local build"
  fi
fi

# Source build (when download was skipped or failed)
if [ -z "${_downloaded}" ] && [ "${SKIP_BUILD}" != "1" ]; then
  # Pre-flight: brew deps
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

  command -v git >/dev/null 2>&1 || { echo "ERROR: git not on PATH"; exit 1; }

  # Ensure vendor/librime/ is at the fork tag
  if [ ! -d "${LIBRIME_DIR}/.git" ]; then
    echo "Cloning ${FORK_URL} → ${LIBRIME_DIR} (this can take a few minutes)..."
    git clone --recurse-submodules "${FORK_URL}" "${LIBRIME_DIR}"
    git -C "${LIBRIME_DIR}" checkout "${FORK_TAG}"
    git -C "${LIBRIME_DIR}" submodule update --init --recursive
  else
    if ! git -C "${LIBRIME_DIR}" remote get-url smoodle >/dev/null 2>&1; then
      git -C "${LIBRIME_DIR}" remote add smoodle "${FORK_URL}"
      echo "  added smoodle remote → ${FORK_URL}"
    fi
    if ! git -C "${LIBRIME_DIR}" rev-parse "refs/tags/${FORK_TAG}" >/dev/null 2>&1; then
      echo "  fetching tag ${FORK_TAG} from smoodle..."
      git -C "${LIBRIME_DIR}" fetch smoodle "refs/tags/${FORK_TAG}:refs/tags/${FORK_TAG}"
    fi
    current="$(git -C "${LIBRIME_DIR}" describe --always --dirty 2>/dev/null || echo unknown)"
    expected="$(git -C "${LIBRIME_DIR}" rev-parse "refs/tags/${FORK_TAG}^{commit}" 2>/dev/null || echo unknown)"
    head_sha="$(git -C "${LIBRIME_DIR}" rev-parse HEAD 2>/dev/null || echo unknown)"
    if [ "${head_sha}" != "${expected}" ]; then
      echo "  ⚠ vendor/librime/ HEAD is ${current}, not tag ${FORK_TAG}."
      echo "    Build will use whatever is currently checked out."
      echo "    For a clean tag-based build:"
      echo "      git -C ${LIBRIME_DIR} checkout ${FORK_TAG}"
    fi
  fi
  echo "✓ source ready at $(git -C "${LIBRIME_DIR}" describe --always --dirty 2>/dev/null || echo unknown)"

  if [ "${FORCE_REBUILD}" = "1" ]; then
    echo "Wiping ${LIBRIME_DIR}/build (SMOODLE_FORCE_REBUILD=1)..."
    rm -rf "${LIBRIME_DIR}/build"
  fi
  echo "Building librime (this can take 5-15 minutes)..."
  ( cd "${LIBRIME_DIR}" && make release )
fi

# --- Verify dylib -----------------------------------------------------------
if [ ! -f "${BUILT_DYLIB}" ]; then
  echo "ERROR: dylib not found at ${BUILT_DYLIB}"
  exit 1
fi
size_kb=$(( $(stat -f %z "${BUILT_DYLIB}") / 1024 ))
echo "✓ dylib ready: $(basename "${BUILT_DYLIB}") (${size_kb} KB)"

# --- Swap (sudo) ------------------------------------------------------------
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

Note: Squirrel auto-updates from the Rime project may overwrite this patched
dylib. Re-run this script to reapply the swap. Fork tag ${FORK_TAG} keeps the
patch reproducible.
EOF
