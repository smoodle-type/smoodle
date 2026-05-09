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

# Plan 02-02: arch-refusal + SHA256 verify env surface ----------------------
# SMOODLE_HOST_ARCH_OVERRIDE — for testing the Intel-Mac refusal path on arm64
#                              hosts. Default: $(uname -m). Tests set to x86_64.
# SMOODLE_SHA256_LIVE_URL    — URL of the live `.sha256` sidecar.
#                              Default: ${RELEASE_URL}.sha256. Tests can point
#                              this at a 404-guaranteed file:// path to exercise
#                              the vendored fallback.
# SMOODLE_SHA256_SIDECAR     — path to a local .sha256 sidecar; used as fallback
#                              when the live URL above returns 404.
#                              Default: $REPO_DIR/vendor/macos/librime.1.dylib.sha256
HOST_ARCH="${SMOODLE_HOST_ARCH_OVERRIDE:-$(uname -m)}"
SHA256_LIVE_URL="${SMOODLE_SHA256_LIVE_URL:-${RELEASE_URL}.sha256}"
SHA256_SIDECAR_FALLBACK="${SMOODLE_SHA256_SIDECAR:-${REPO_DIR}/vendor/macos/librime.1.dylib.sha256}"

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

# --- Plan 02-02: Architecture refusal (MP-3) -------------------------------
# Cheaper-than-SHA gate: if host arch is x86_64 but the dylib is arm64-only,
# refuse to proceed. Verbatim error string per ROADMAP Phase 2 SC #3.
# Runs BEFORE the SHA256 verify block (D6) — failing earlier on the path
# Intel-Mac users hit, without making them wait on hash computation.
DYLIB_ARCHS="$(lipo -archs "${BUILT_DYLIB}" 2>/dev/null || echo "unknown")"
echo "  host arch: ${HOST_ARCH}"
echo "  dylib archs: ${DYLIB_ARCHS}"
if [ "${HOST_ARCH}" = "x86_64" ]; then
  if ! echo "${DYLIB_ARCHS}" | grep -q "x86_64"; then
    echo "ERROR: this is an arm64-only dylib; Intel Mac not supported until universal dylib lands"
    exit 1
  fi
elif [ "${HOST_ARCH}" = "arm64" ]; then
  if ! echo "${DYLIB_ARCHS}" | grep -q "arm64"; then
    echo "ERROR: dylib does not contain an arm64 slice; cannot run on Apple Silicon"
    exit 1
  fi
fi
echo "✓ arch check passed"

# --- Plan 02-02: SHA256 verify (CP-2) --------------------------------------
# Post-download, pre-swap. Sidecar source: live ${SHA256_LIVE_URL} first,
# vendored fallback at ${SHA256_SIDECAR_FALLBACK} second.
# This block runs ONLY when the dylib was downloaded (not for source-built
# dylibs — source builds are local, hash provenance is the build, not a sidecar).
if [ -n "${_downloaded:-}" ]; then
  _expected_sha=""
  _sha_source=""
  _tmp_sha="$(mktemp /tmp/smoodle-librime-XXXXXX.sha256)"
  if curl -fsSL -o "${_tmp_sha}" "${SHA256_LIVE_URL}" 2>/dev/null \
      && [ -s "${_tmp_sha}" ]; then
    _expected_sha="$(awk '{print $1}' "${_tmp_sha}")"
    _sha_source="live sidecar at ${SHA256_LIVE_URL}"
  elif [ -f "${SHA256_SIDECAR_FALLBACK}" ]; then
    _expected_sha="$(awk '{print $1}' "${SHA256_SIDECAR_FALLBACK}")"
    _sha_source="vendored fallback ${SHA256_SIDECAR_FALLBACK}"
  fi
  rm -f "${_tmp_sha}"

  if [ -z "${_expected_sha}" ]; then
    echo "ERROR: no SHA256 sidecar available (live 404 + no vendored fallback)"
    echo "       cannot verify dylib integrity; refusing to swap"
    exit 1
  fi
  echo "  sha source: ${_sha_source}"

  _actual_sha="$(shasum -a 256 "${BUILT_DYLIB}" | awk '{print $1}')"
  if [ "${_expected_sha}" != "${_actual_sha}" ]; then
    echo "ERROR: SHA256 mismatch on downloaded dylib"
    echo "  expected: ${_expected_sha}"
    echo "  actual:   ${_actual_sha}"
    echo "  source:   ${RELEASE_URL}"
    echo "       refusing to swap (CP-2 supply-chain protection)"
    exit 1
  fi
  echo "✓ SHA256 verify passed (${_actual_sha})"
else
  echo "  SHA256 verify skipped (source-built dylib, not a download)"
fi

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
