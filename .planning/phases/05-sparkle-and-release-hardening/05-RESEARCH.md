# Phase 5 Research: Sparkle Re-Swap & Release Hardening (Lane S)

**Researched:** 2026-05-10
**Requirements:** HARDEN-01 through HARDEN-07
**Confidence:** HIGH — all patterns grounded in existing code from Phases 2+3; only the cross-repo `lipo` join + release.yml draft-then-publish sequence are new patterns.

---

## 1. verify-librime.sh Design (HARDEN-01)

### What it does
A manual, one-shot script that the founder or dogfood friend runs when Thai ranking "feels wrong." It computes the SHA256 of the currently-active `librime.1.dylib` inside Squirrel.app and compares it against the install-time sidecar SHA. Reports drift with a clear recovery instruction.

### Design details

**Location:** `scripts/verify-librime.sh`

**Core logic:**
```bash
#!/usr/bin/env bash
set -euo pipefail

SQUIRREL_DYLIB="/Library/Input Methods/Squirrel.app/Contents/Frameworks/librime.1.dylib"
SIDECAR="${SMOODLE_SHA256_SIDECAR:-$(dirname "$0")/../vendor/macos/librime.1.dylib.sha256}"

# 1. Check dylib exists at expected Squirrel location
if [ ! -f "$SQUIRREL_DYLIB" ]; then
  echo "ERROR: librime.1.dylib not found at ${SQUIRREL_DYLIB}"
  echo "       Is Squirrel.app installed at /Library/Input Methods/?"
  exit 2
fi

# 2. Read expected SHA from sidecar (same file install-librime-fork.sh uses)
if [ ! -f "$SIDECAR" ]; then
  echo "ERROR: SHA256 sidecar not found at ${SIDECAR}"
  echo "       Run install-librime-fork.sh first to populate the sidecar."
  exit 2
fi
EXPECTED_SHA="$(awk '{print $1}' "$SIDECAR")"

# 3. Compute actual SHA
ACTUAL_SHA="$(shasum -a 256 "$SQUIRREL_DYLIB" | awk '{print $1}')"

# 4. Compare
if [ "$EXPECTED_SHA" != "$ACTUAL_SHA" ]; then
  echo "WARN: librime.1.dylib drift detected."
  echo "  expected: ${EXPECTED_SHA}"
  echo "  actual:   ${ACTUAL_SHA}"
  echo ""
  echo "Sparkle may have overwritten the smoodle-patched dylib."
  echo "Re-run to reapply the patch:"
  echo "  bash scripts/install-librime-fork.sh"
  exit 1
fi

# Clean: exit 0 silently (or with minimal confirmation)
echo "OK: librime.1.dylib hash matches expected"
exit 0
```

**Key design decisions:**
- **NO LaunchAgent, NO daemon, NO cron** — per CP-1. This is explicitly a manual probe. The user runs it when they suspect degradation.
- **Reads sidecar from `vendor/macos/librime.1.dylib.sha256`** — the same file that `install-librime-fork.sh` already uses. No separate "expected SHA" file needed.
- **`SMOODLE_SHA256_SIDECAR` env override** — for testing, allows pointing at an artificial sidecar.
- **Exit codes:** 0 = clean, 1 = drift detected, 2 = pre-condition failure (missing dylib or sidecar).
- **No sudo required** — reading the dylib and its hash is read-only.

### Test strategy
- Python unittest at `tests/test_verify_librime_mac.py` (parallel to `tests/test_install_librime_fork_mac.py` from Phase 2).
- Test cases:
  1. Clean dylib (matches sidecar) → exit 0.
  2. Tampered dylib (wrong bytes) → exit 1, drift message contains "re-run install-librime-fork.sh".
  3. Missing dylib → exit 2.
  4. Missing sidecar → exit 2.

---

## 2. verify-librime.ps1 Design (HARDEN-02)

### What it does
PowerShell parallel of HARDEN-01 for Windows. Computes SHA256 of the active `rime.dll` in Weasel's install directory and compares to the vendored sidecar.

### Design details

**Location:** `scripts/verify-librime.ps1`

**Core logic:**
```powershell
[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'

# Resolve Weasel path (same detection as install-librime-fork.ps1)
$WeaselPath = $env:SMOODLE_WEASEL_PATH
if (-not $WeaselPath) {
    foreach ($parent in @(
        (Join-Path $env:ProgramFiles        'Rime'),
        (Join-Path ${env:ProgramFiles(x86)} 'Rime')
    )) {
        if (-not (Test-Path $parent)) { continue }
        $versioned = Get-ChildItem $parent -Directory -Filter 'weasel-*' `
                     -ErrorAction SilentlyContinue |
                     Sort-Object Name -Descending | Select-Object -First 1
        if ($versioned) { $WeaselPath = $versioned.FullName; break }
    }
}

if (-not $WeaselPath) {
    Write-Error "Weasel not found. Install Rime.Weasel first."
    exit 2
}

$DllPath = Join-Path $WeaselPath 'rime.dll'
if (-not (Test-Path $DllPath)) {
    Write-Error "rime.dll not found at $DllPath"
    exit 2
}

# Sidecar path (vendored, same as install-librime-fork.ps1 uses)
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$SidecarPath = Join-Path $ScriptDir '..\vendor\windows\rime.dll.sha256'
try { $SidecarPath = (Resolve-Path $SidecarPath -ErrorAction Stop).Path } catch {
    Write-Error "SHA256 sidecar not found at $SidecarPath. Run install-librime-fork.ps1 first."
    exit 2
}

$ExpectedSha = ((Get-Content -Raw -Encoding UTF8 $SidecarPath) -split '\s+')[0].Trim().ToLower()
$ActualSha = (Get-FileHash -Algorithm SHA256 -Path $DllPath).Hash.ToLower()

if ($ExpectedSha -ne $ActualSha) {
    Write-Host "WARN: rime.dll drift detected."
    Write-Host "  expected: $ExpectedSha"
    Write-Host "  actual:   $ActualSha"
    Write-Host ""
    Write-Host "A Weasel update may have overwritten the smoodle-patched DLL."
    Write-Host "Re-run to reapply the patch:"
    Write-Host "  .\scripts\install-librime-fork.ps1"
    exit 1
}

Write-Host "OK: rime.dll hash matches expected"
exit 0
```

**Key decisions:**
- Reuses the same Weasel path detection logic as `install-librime-fork.ps1` (versioned subdir probe).
- Vendored sidecar is the primary (and only) SHA source for Windows — no live URL fetch needed in the verifier.
- Case normalization via `.ToLower()` matches the install script's pattern.
- Same exit code convention: 0 = clean, 1 = drift, 2 = pre-condition failure.

### Test strategy
- Python unittest at `tests/test_verify_librime_win.py`.
- Same 4 test cases as the macOS verifier, exercised against a sandboxed DLL + sidecar.

---

## 3. Universal macOS Dylib Build in smoodle-type/librime (HARDEN-03)

### What it does
Adds a `lipo -create` join step to `smoodle-type/librime`'s `smoodle-build.yml` that combines the `macos-15` (arm64) and `macos-15-intel` (x86_64) artifacts into a single universal binary, then uploads it to GitHub Releases alongside a `.sha256` sidecar.

### Cross-repo nature
This work lives in `smoodle-type/librime`, NOT `smoodle-type/smoodle`. The planning phase for this repo must schedule the cross-repo PR as its first sub-task.

### Implementation in librine fork's `smoodle-build.yml`

**What exists today:** The fork's CI already runs `macos-15` and `macos-15-intel` jobs independently, each producing its own dylib artifact. The current workflow does NOT join them.

**What needs to be added:**

```yaml
# In smoodle-type/librime/.github/workflows/smoodle-build.yml
# New job that depends on both macos jobs completing:

universal-mac:
  needs: [macos, macos-intel]  # whatever the existing job names are
  runs-on: macos-15
  steps:
    - uses: actions/download-artifact@v4
      with:
        name: librime-macos-arm64  # artifact from macos-15 job
        path: arm64/
    - uses: actions/download-artifact@v4
      with:
        name: librime-macos-x86_64  # artifact from macos-15-intel job
        path: x86_64/

    - name: Create universal binary
      run: |
        lipo -create arm64/librime.1.dylib x86_64/librime.1.dylib \
          -output librime-${{ env.FORK_TAG }}-macOS-universal.dylib

    - name: Generate SHA256 sidecar
      run: |
        shasum -a 256 librime-${{ env.FORK_TAG }}-macOS-universal.dylib \
          > librime-${{ env.FORK_TAG }}-macOS-universal.dylib.sha256

    - uses: actions/upload-artifact@v4
      with:
        name: librime-macos-universal
        path: |
          librime-${{ env.FORK_TAG }}-macOS-universal.dylib
          librime-${{ env.FORK_TAG }}-macOS-universal.dylib.sha256

    # On tag push, upload to GitHub Releases:
    - name: Upload to release
      if: startsWith(github.ref, 'refs/tags/')
      run: |
        gh release upload ${{ github.ref_name }} \
          librime-${{ env.FORK_TAG }}-macOS-universal.dylib \
          librime-${{ env.FORK_TAG }}-macOS-universal.dylib.sha256 \
          --repo ${{ github.repository }}
      env:
        GH_TOKEN: ${{ secrets.GITHUB_TOKEN }}
```

**Key details:**
- The exact `env.FORK_TAG` value needs to match the tag the workflow is running on (or is extracted from `github.ref_name` for tag-triggered runs).
- The `needs:` clause must reference the actual job names from the existing `smoodle-build.yml`.
- The sidecar must be generated from the *universal* binary, not from either slice individually.
- For this repo's `install-librime-fork.sh` to find the sidecar, the URL pattern `.../librime-${FORK_TAG}-macOS-universal.dylib.sha256` must resolve — which it will once the release.yml (HARDEN-04) uploads it.

### What this repo does
Nothing changes in `install-librime-fork.sh`'s logic — it already expects `librime-${FORK_TAG}-macOS-universal.dylib` as the asset name and does `lipo -archs` to check for both slices. The only change is that the sidecar will now be a live URL (not just vendored) once the fork's release.yml emits it.

### Planning note
The cross-repo PR must land BEFORE this phase's verify steps can pass against a live release. The plan should sequence: (1) draft cross-repo PR in librime fork, (2) merge, (3) verify live release URL in this repo's tests.

---

## 4. release.yml Atomic Draft-Then-Publish (HARDEN-04)

### What it does
A tag-triggered workflow in this repo that builds the macOS DMG via `scripts/build-macos-dmg.sh`, computes SHA256 of the DMG, and uploads assets to GitHub Releases using an atomic draft-then-publish pattern to avoid mid-upload race conditions.

### Why draft-then-publish
Per MP-5: if a single `gh release create` command uploads assets sequentially and the workflow is cancelled mid-upload, the release is partially published — some assets exist, some don't. Installers that run during this window get inconsistent results. The draft pattern avoids this: all assets are uploaded while the release is invisible, then a single `gh release edit --draft=false` makes everything visible atomically.

### Location
`.github/workflows/release.yml`

### Implementation:

```yaml
name: release
on:
  push:
    tags: ['v*']

permissions:
  contents: write  # for gh release create/upload

jobs:
  build-and-release:
    runs-on: macos-15
    steps:
      - uses: actions/checkout@v4

      - name: Build DMG
        run: |
          chmod +x scripts/build-macos-dmg.sh
          ./scripts/build-macos-dmg.sh

      - name: Compute SHA256
        run: |
          for f in dist/*.dmg; do
            shasum -a 256 "$f" > "${f}.sha256"
          done

      - name: Create draft release
        run: |
          gh release create "${{ github.ref_name }}" \
            --draft \
            --title "Smoodle ${{ github.ref_name }}" \
            --notes "Release ${{ github.ref_name }}" \
            --repo "${{ github.repository }}"
        env:
          GH_TOKEN: ${{ secrets.GITHUB_TOKEN }}

      - name: Upload assets to draft release
        run: |
          gh release upload "${{ github.ref_name }}" \
            dist/*.dmg \
            dist/*.dmg.sha256 \
            --repo "${{ github.repository }}"
        env:
          GH_TOKEN: ${{ secrets.GITHUB_TOKEN }}

      - name: Publish release (remove draft)
        run: |
          gh release edit "${{ github.ref_name }}" \
            --draft=false \
            --repo "${{ github.repository }}"
        env:
          GH_TOKEN: ${{ secrets.GITHUB_TOKEN }}
```

**Key sequencing:**
1. `gh release create --draft` — creates an invisible release.
2. `gh release upload` — uploads all assets (DMG + SHA256) to the draft. If this step fails or is cancelled, the release remains invisible. No installer will ever fetch a partial release.
3. `gh release edit --draft=false` — single atomic publish. If this step fails, the release is still in draft state; a retry can be run manually.

**What to upload:**
- The DMG built by `scripts/build-macos-dmg.sh`.
- The `.sha256` sidecar for the DMG.
- NOTE: The librime dylib + sidecar are uploaded from the `smoodle-type/librime` fork's workflow (HARDEN-03), not this one. This repo's release.yml handles smoodle's own assets.

**Failure mode:** If the upload step is cancelled mid-way, the release stays in draft. A manual `gh release upload --clobber` can resume, then `gh release edit --draft=false` publishes. The `--clobber` here is acceptable because the release is still in draft state — no user has fetched it yet.

---

## 5. Tag-Immutability CI Guard (HARDEN-05)

### What it does
A workflow (can be part of `ci.yml` or a separate `tag-immutability.yml`) that rejects releases where assets have been rewritten after initial publication. It detects `gh release upload --clobber` abuse by comparing `updated_at` vs `created_at` timestamps on release assets.

### Implementation

**Location:** Can be a step in `ci.yml` triggered on `push: tags`, or a separate workflow `.github/workflows/tag-immutability.yml`.

**Core logic:**
```bash
#!/usr/bin/env bash
# Called after release.yml publishes a tag. If any asset's updated_at
# differs from created_at, someone re-uploaded via --clobber after
# initial publish. Fail the workflow.

set -euo pipefail

TAG="${1:?tag required}"
REPO="${2:?repo required}"

# Get all assets with their timestamps
ASSETS_JSON=$(gh release view "$TAG" \
  --repo "$REPO" \
  --json assets \
  --jq '.assets[] | {name, created_at, updated_at}')

# Check each asset
echo "$ASSETS_JSON" | while read -r asset; do
  name=$(echo "$asset" | jq -r '.name')
  created=$(echo "$asset" | jq -r '.created_at')
  updated=$(echo "$asset" | jq -r '.updated_at')
  if [ "$created" != "$updated" ]; then
    echo "ERROR: asset ${name} was modified after initial release"
    echo "  created_at: ${created}"
    echo "  updated_at: ${updated}"
    echo "  tag rewrites are not allowed — create a new tag instead"
    exit 1
  fi
done

echo "OK: all asset timestamps match (tag is immutable)"
```

**When it runs:** As a post-publish step in `release.yml` (after the `--draft=false` edit), or as a separate workflow triggered on `release: published` events.

**Why it works:** GitHub sets `created_at` and `updated_at` to the same value on initial upload. If someone runs `gh release upload --clobber`, the `updated_at` changes while `created_at` stays the same. This guard catches it and fails the workflow.

**Alternative approach:** A branch protection rule or repository setting could enforce tag immutability at the git level, but the asset-level guard is what matters here — git tags themselves are immutable by nature; it's the GitHub Release *assets* attached to the tag that get rewritten.

**Integration with release.yml:** Add as the final step after publish:

```yaml
      - name: Verify tag immutability
        run: |
          # Small delay to ensure GitHub has indexed the release
          sleep 5
          for asset in $(gh release view "${{ github.ref_name }}" \
            --repo "${{ github.repository }}" \
            --json assets \
            --jq '.assets[] | "\(.name)|\(.created_at)|\(.updated_at)"'); do
            name=$(echo "$asset" | cut -d'|' -f1)
            created=$(echo "$asset" | cut -d'|' -f2)
            updated=$(echo "$asset" | cut -d'|' -f3)
            if [ "$created" != "$updated" ]; then
              echo "ERROR: ${name} was rewritten (created=${created}, updated=${updated})"
              echo "Tag rewrites are not allowed — bump the version tag instead."
              exit 1
            fi
          done
          echo "OK: tag ${GITHUB_REF_NAME} is immutable"
        env:
          GH_TOKEN: ${{ secrets.GITHUB_TOKEN }}
```

---

## 6. install-librime-fork.sh Post-Install Warning (HARDEN-06)

### What it does
Adds a trailing message at the end of `install-librime-fork.sh` that instructs the user to run `verify-librime.sh` if Thai ranking degrades. This is the Sparkle re-swap recovery path.

### Current state
The existing `install-librime-fork.sh` already has a post-install cat-EOF block (the final `cat <<EOF` at the bottom). It currently says:

> "Note: Squirrel auto-updates from the Rime project may overwrite this patched dylib. Re-run this script to reapply the swap."

### Required change
Replace the trailing note with text that references `verify-librime.sh`:

```
Note: Squirrel auto-updates via Sparkle may overwrite the patched
librime.1.dylib silently. If Thai ranking ever degrades, run:

  bash scripts/verify-librime.sh

This will check whether the dylib hash still matches the smoodle patch.
If drift is detected, re-run this installer:

  bash scripts/install-librime-fork.sh
```

**Implementation:** Simple text edit in the existing `cat <<EOF` block at the end of `scripts/install-librime-fork.sh`.

**Also needed:** The same trailing note should be added to `scripts/install-librime-fork.ps1` for Windows, referencing `verify-librime.ps1`:

```
Note: A Weasel update may overwrite the patched rime.dll silently.
If Thai ranking ever degrades, run:

  .\scripts\verify-librime.ps1

This will check whether the DLL hash still matches the smoodle patch.
If drift is detected, re-run this installer:

  .\scripts\install-librime-fork.ps1
```

---

## 7. install.sh Schema Timestamp Touch (HARDEN-07)

### What it does
Adds `touch -m schema/thai_phonetic.*.yaml` after the `cp` loop in `scripts/install.sh` to force Squirrel to recompile schemas on next Deploy, even when rsync/Copy-Item preserved stale mtimes (e.g., restored from Time Machine).

### Current state
`scripts/install-windows.ps1` already does this (lines 174-179):
```powershell
# Touch schema files to force WeaselDeployer to recompile
Get-ChildItem $RimeDir -Filter 'thai_phonetic.*.yaml' | ForEach-Object {
    $_.LastWriteTime = Get-Date
}
```

`scripts/install.sh` does NOT have an equivalent touch — it relies on Squirrel kill+restart to force recompile, which is fine for fresh installs but breaks for Time Machine restores where `~/Library/Rime/` has stale mtimes that are newer than Squirrel's build cache.

### Required change
Add after the `cp` loop (around line 70, after the post-copy verification block):

```bash
# Touch schema files to force Squirrel to recompile on next Deploy.
# This mirrors the Windows LastWriteTime = Get-Date pattern (install-windows.ps1).
# Without this, rsync from Time Machine or other backup tools can restore
# schema YAMLs with stale mtimes that Squirrel considers "already compiled."
for f in thai_phonetic.schema.yaml thai_phonetic.dict.yaml; do
  touch -m "${RIME_DIR}/${f}"
done
```

**Key details:**
- Touch only the Thai phonetic schema files, NOT `default.custom.yaml` (touching that could trigger a broader recompile of all schemas).
- `touch -m` modifies the modification time to "now" — this is the macOS/BSD equivalent of the Windows `LastWriteTime = Get-Date`.
- Touch the destination copies in `~/Library/Rime/`, not the source files in the repo.

---

## 8. Existing Patterns from Phases 2+3 for Co-location

### SHA256 verify blocks

**macOS (`install-librime-fork.sh`, lines ~195-225):**
- Downloads sidecar from `${SHA256_LIVE_URL}` first, falls back to `${SHA256_SIDECAR_FALLBACK}` (vendored).
- Uses `shasum -a 256` for hash computation.
- Runs ONLY when `_downloaded` is set (i.e., downloaded dylib, not source-built).
- Exits 1 on mismatch with expected/actual/source diagnostic lines.

**Windows (`install-librime-fork.ps1`, lines ~290-340):**
- Vendored sidecar is PRIMARY, live URL is SECONDARY (reversed from macOS).
- Uses `Get-FileHash -Algorithm SHA256` with `.ToLower()` normalization.
- Runs for ALL DLL resolution paths (vendored, cached, CI download).
- Exits 1 on mismatch with Write-Host diagnostics before Write-Error.

**Co-location for Phase 5:** The verify scripts (`verify-librime.{sh,ps1}`) read from the same sidecar files. No new sidecar files need to be created. The verifier is essentially the "read-only half" of the SHA256 verify block that already exists in the installers.

### Architectural relationship

```
install-librime-fork.sh          verify-librime.sh
─────────────────────            ──────────────────
download dylib
     │
     ▼
download sidecar (live → vendored)
     │
     ▼
SHA256 verify (pre-swap)          ←─ shares sidecar file ─→  read sidecar
     │                                                          │
     ▼                                                          ▼
swap dylib (sudo cp)                                           hash dylib in-place
     │                                                          │
     ▼                                                          ▼
post-install message ──────────────────────────────────→  "run verify-librime.sh
                                                          if ranking degrades"
```

The installers and verifiers share a single source of truth for expected SHA: the `vendor/{macos,windows}/*.sha256` files.

---

## Risks & Dependencies

| Risk | Mitigation |
|------|------------|
| **Cross-repo PR in librime fork blocks HARDEN-03** | Schedule as first sub-task in plan-phase. The smoodle repo's plan can proceed in parallel — the verifier scripts don't depend on the universal dylib being live, only the release.yml upload does. |
| **release.yml draft-then-publish sequencing subtleties** | The `gh release upload` step can fail partway through a multi-file upload. Using `--clobber` in the upload step is safe because the release is in draft state. The key invariant is: `--draft=false` is the LAST step, never run before all assets are confirmed uploaded. |
| **Tag-immutability guard false positives** | GitHub's API may report slightly different timestamps due to indexing latency. Add a `sleep 5` before the check, or tolerate a small delta (<30s). The real failure mode is hours/days later when `--clobber` is used manually. |
| **verify-librime.sh reads wrong dylib path** | Squirrel can be installed at `/Library/Input Methods/Squirrel.app` or `/Applications/Squirrel.app`. The verify script should check the same path that `install-librime-fork.sh` uses (`SMOODLE_SQUIRREL_PATH` env override). |
| **touch -m triggers unnecessary recompile** | Minor cost — Squirrel's recompile of the 28k-entry dict takes ~60s on first Deploy, but the user already clicked Deploy manually. The touch just ensures it actually recompiles. |

---

## Planning Sequence

Recommended sub-plan structure for Phase 5:

**Plan 05-01: verify-librime.{sh,ps1} + post-install warning (HARDEN-01, 02, 06)**
- Create `scripts/verify-librime.sh` and `scripts/verify-librime.ps1`.
- Add trailing recovery messages to `install-librime-fork.sh` and `install-librime-fork.ps1`.
- Python unittests for both verifiers.
- Wave 1, autonomous.

**Plan 05-02: release.yml draft-then-publish + tag-immunity guard (HARDEN-04, 05)**
- Create `.github/workflows/release.yml` with draft-then-publish sequencing.
- Add tag-immutability post-publish verification step.
- Wave 2, checkpoint: human-verify (trigger on a test tag to confirm sequencing).

**Plan 05-03: schema timestamp touch (HARDEN-07)**
- Add `touch -m` after cp loop in `scripts/install.sh`.
- Trivial change, no test needed beyond existing `test_installers.py` shape tests.
- Can be folded into Plan 05-01 as a single-line addition.

**Cross-repo task (HARDEN-03): NOT a plan in this repo**
- Draft PR in `smoodle-type/librime` adding `lipo -create` join + universal-artifact upload to `smoodle-build.yml`.
- This is tracked as a dependency, not a plan. The plan-phase should note it and schedule it as a parallel work item in the librine fork.

---

## Files to Create/Modify

| Action | File | Requirement |
|--------|------|-------------|
| CREATE | `scripts/verify-librime.sh` | HARDEN-01 |
| CREATE | `scripts/verify-librime.ps1` | HARDEN-02 |
| CREATE | `tests/test_verify_librime_mac.py` | HARDEN-01 (test) |
| CREATE | `tests/test_verify_librime_win.py` | HARDEN-02 (test) |
| CREATE | `.github/workflows/release.yml` | HARDEN-04 |
| MODIFY | `scripts/install-librime-fork.sh` (trailing message) | HARDEN-06 |
| MODIFY | `scripts/install-librime-fork.ps1` (trailing message) | HARDEN-06 |
| MODIFY | `scripts/install.sh` (touch -m after cp loop) | HARDEN-07 |
| CROSS-REPO | `smoodle-type/librime` — `smoodle-build.yml` (lipo + upload) | HARDEN-03 |

---

*Research completed: 2026-05-10*
*Ready for /gsd-plan-phase 5.*
