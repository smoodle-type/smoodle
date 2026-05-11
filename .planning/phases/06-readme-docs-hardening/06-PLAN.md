# Phase 6 Plan — README & Docs Hardening (Lane R)

**Phase:** 6
**Lane:** R (README + Docs)
**Wave structure:** 2 waves
- **Wave 1 (autonomous: true)** — LoneExile→smoodle-type migration, status/version fix, hardcoded path cleanup, uninstall flags
- **Wave 2 (autonomous: true)** — README rewrite (install sections, troubleshooting, uninstall), RELEASE-CHECKLIST.md

**Requirements:** DOCS-01 through DOCS-07 (7 REQ-IDs)
**Success Criteria:** 6 SC (from ROADMAP.md)
**Dependencies:** Phase 5 (README references verify-librime.sh, release workflow, touch -m)
**Mode:** yolo

---

## Wave 1 — Migration + Fixes (DOCS-01, DOCS-05, DOCS-07, DOCS-04 partial)

### Tasks

#### Task 06-01-01: LoneExile → smoodle-type migration (DOCS-05)

Replace all `LoneExile` references with `smoodle-type` across:
- `README.md` (2 occurrences)
- `docs/RESUME.md` (4 occurrences)
- `docs/LANE-B-WINDOWS.md` (2 occurrences)
- `docs/LANE-B-HARDENING-PROMPT.md` (4 occurrences)
- `docs/LANE-C-E2E-PROMPT.md` (3 occurrences)
- `docs/CI-REFACTOR-PROMPT.md` (8 occurrences)
- `docs/PHASE1-PROMPT.md` (4 occurrences)
- `TODOS.md` (14 occurrences)
- `CLAUDE.md` (1 occurrence)

Total: ~42 replacements. Straight `LoneExile` → `smoodle-type` text replace.

#### Task 06-01-02: Status + version fix (DOCS-01)

In `README.md`:
- `APPROVED-PENDING-PHASE-0` → `APPROVED`
- Add note about current phase completion (Phases 1-5 done)

#### Task 06-01-03: Hardcoded path cleanup (DOCS-07)

In `docs/RESUME.md`:
- Line 67: `/Users/lex/Dev/my_repos/experiment/smoodle/vendor/librime/build/lib/` → `${REPO_DIR}/vendor/librime/build/lib/`
- Line 247: `cd /Users/lex/Dev/my_repos/experiment/smoodle` → `cd "${REPO_DIR}"` or `# from repo root`

Verify: `git grep -nE '/Users/lex/Dev/my_repos/experiment/smoodle' docs/` returns zero hits.

#### Task 06-01-04: Uninstall flags (DOCS-04 partial)

Add `--uninstall` flag to `scripts/install.sh`:
- Removes only Smoodle-owned files from `~/Library/Rime/` (thai_phonetic.schema.yaml, thai_phonetic.dict.yaml, default.custom.yaml if smoodle-owned)
- Removes `~/.smoodle/` telemetry files
- Prints clear success message

Add equivalent uninstall to `scripts/install-linux.sh`.
Add uninstall instructions in `scripts/install-windows.ps1` (comment block explaining manual removal since Windows doesn't have a clean uninstall pattern for script installs).

---

## Wave 2 — README Rewrite + RELEASE-CHECKLIST (DOCS-02, DOCS-03, DOCS-06)

### Tasks

#### Task 06-02-01: Rewrite README.md install section (DOCS-02)

Replace the single "Install (macOS dogfood)" section with 3 subsections:

```markdown
## Install

### macOS

```bash
brew install --cask squirrel-app
bash scripts/install.sh
bash scripts/install-librime-fork.sh
```

### Windows

```powershell
winget install Rime.Weasel
powershell -ExecutionPolicy Bypass -File scripts\install-windows.ps1
powershell -ExecutionPolicy Bypass -File scripts\install-librime-fork.ps1
```

### Linux

```bash
# Requires fcitx5 or ibus running
bash scripts/install-linux.sh
```
```

#### Task 06-02-02: Add troubleshooting section (DOCS-03)

Add to README.md after install section:

```markdown
## Troubleshooting

### Smoodle not in input switcher
- Verify the three YAML files exist in your Rime user directory
- Click Deploy in your IME's menu

### Ranking degraded after Squirrel auto-update
- Sparkle may have overwritten the patched librime dylib
- Run `bash scripts/verify-librime.sh` to check
- If drift detected: `bash scripts/install-librime-fork.sh` to re-swap

### Intel Mac: "arm64-only dylib" error
- As of v0.0.6, the patched dylib is arm64-only
- Universal dylib (arm64 + x86_64) planned for Phase 1.5
- Workaround: build librime from source on your Intel Mac

### Windows: Weasel installed but not registered
- Open Settings > Time & Language > Language > Keyboard
- Add "Rime" if not present
- Re-run install-windows.ps1

### Linux: candidate ranks wrong on first lookup
- Known limitation: system librime lacks the DictEntryIterator::Peek fix
- Type the input, commit, retype — second lookup ranks correctly
- This is fixed in the macOS build via smoodle-type/librime fork
```

#### Task 06-02-03: Add uninstall section to README (DOCS-04)

```markdown
## Uninstall

### macOS
```bash
bash scripts/install.sh --uninstall
```

### Windows
Remove manually:
```powershell
Remove-Item "$env:APPDATA\Rime\thai_phonetic.*"
Remove-Item "$env:APPDATA\Rime\default.custom.yaml"
```

### Linux
```bash
bash scripts/install-linux.sh --uninstall
```
```

#### Task 06-02-04: Create docs/RELEASE-CHECKLIST.md (DOCS-06)

Create a release checklist that covers:
1. Fresh clone + clean build
2. macOS install + sawadee→สวัสดี verification
3. Windows install + sawatd→สวัสดี verification
4. Linux install + sawadee→สวัสดี verification
5. Test suite passes (all 3 OS)
6. Lint passes
7. verify-librime.sh passes on macOS
8. Release workflow (draft→publish) works
9. SHA256 sidecars present on release

---

## Commits (planned)

| Commit | Scope | Convention |
|--------|-------|------------|
| `docs(06): migrate LoneExile to smoodle-type across all docs` | Task 06-01-01 | `docs(06)` |
| `docs(06): fix README status + version, clean hardcoded paths` | Task 06-01-02 + 06-01-03 | `docs(06)` |
| `feat(06): add --uninstall to install.sh + install-linux.sh` | Task 06-01-04 | `feat(06)` |
| `docs(06): rewrite README install sections for 3 OS` | Task 06-02-01 | `docs(06)` |
| `docs(06): add troubleshooting + uninstall to README` | Task 06-02-02 + 06-02-03 | `docs(06)` |
| `docs(06): add docs/RELEASE-CHECKLIST.md` | Task 06-02-04 | `docs(06)` |

---
*Plan created: 2026-05-11*
