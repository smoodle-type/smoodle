# Smoodle Release Checklist

Run this checklist before tagging a release. Covers fresh-clone + 3-OS
install validation (PITFALLS MP-1).

## Pre-release

- [ ] `git status` is clean on `main` (no uncommitted changes)
- [ ] `git log --oneline -5` — recent commits are all merged, no WIP
- [ ] Schema version in `schema/thai_phonetic.schema.yaml` matches intended
  release tag (e.g., `v0.0.6`)
- [ ] `schema/thai_phonetic.dict.yaml` frontmatter version matches

## Lint + Tests

- [ ] `yamllint schema/*.yaml schema/default.custom.yaml` exits 0
- [ ] `bash -n scripts/install*.sh` — all bash scripts pass syntax
- [ ] `python3 -m unittest discover tests -v` — all tests pass
  (skips on macOS for pwsh-only tests are expected)
- [ ] `python3 tests/test_dict.py --fixture tests/v01_fixture.yaml` — 56/56 PASS

## macOS

- [ ] Fresh clone: `git clone https://github.com/smoodle-type/smoodle.git`
- [ ] `brew install --cask squirrel-app` (if not already installed)
- [ ] `bash scripts/install.sh` — exits 0, YAMLs copied to `~/Library/Rime/`
- [ ] `bash scripts/install-librime-fork.sh` — exits 0, dylib swapped
- [ ] Squirrel Deploy → open any text field → `Ctrl+\`` → pick
  **smoodle Thai phonetic**
- [ ] Type `sawadee` → expect `สวัสดี` as top candidate
- [ ] `bash scripts/verify-librime.sh` — exits 0 (no drift)

## Windows

- [ ] Fresh clone or zip extract
- [ ] `winget install Rime.Weasel` (if not already installed)
- [ ] `powershell -ExecutionPolicy Bypass -File scripts\install-windows.ps1`
  — exits 0, YAMLs copied to `%APPDATA%\Rime\`
- [ ] `powershell -ExecutionPolicy Bypass -File scripts\install-librime-fork.ps1`
  (admin) — exits 0, DLL swapped
- [ ] Weasel Deploy → switch to **smoodle Thai phonetic**
- [ ] Type `sawadee` or `sawatd` → expect candidate with `สวัสดี`
- [ ] `scripts\verify-librime.ps1` — exits 0 (no drift)

## Linux

- [ ] Fresh clone: `git clone https://github.com/smoodle-type/smoodle.git`
- [ ] fcitx5 or ibus running
- [ ] `bash scripts/install-linux.sh` — exits 0, YAMLs copied
- [ ] Switch to **smoodle Thai phonetic**
- [ ] Type `sawadee` → expect `สวัสดี`
- [ ] Note: first-lookup ranking may be wrong (known limitation; retype to fix)

## Release Workflow

- [ ] Push tag: `git tag v0.0.X && git push origin v0.0.X`
- [ ] Verify `.github/workflows/release.yml` triggers (push: tags)
- [ ] Check GHA run completes green:
  - [ ] checkout
  - [ ] build DMG
  - [ ] SHA256 compute
  - [ ] create draft release
  - [ ] upload assets (DMG + SHA256 sidecars)
  - [ ] publish release (draft=false)
  - [ ] tag immutability guard passes
- [ ] Open GitHub Releases page — verify:
  - [ ] Release is NOT draft
  - [ ] Title: "Smoodle v0.0.X"
  - [ ] DMG asset attached
  - [ ] SHA256 sidecar files attached
- [ ] Download DMG from release → run install → verify `sawadee → สวัสดี`

## Post-release

- [ ] Clean up test artifacts if any were created during validation
- [ ] Update ROADMAP.md status if this closes a milestone
- [ ] Announce to dogfood circle

---
*Created: 2026-05-11 (Phase 6, DOCS-06)*
