---
phase: 05-sparkle-and-release-hardening
plan: "02"
subsystem: release-infra
tags: [github-actions, release, draft-then-publish, tag-immutability, ci-cd]

# Dependency graph
requires:
  - phase: "05-01"
    provides: "verify-librime scripts and SHA256 sidecar infrastructure"
  - phase: "02-macos-e2e"
    provides: "build-macos-dmg.sh workflow precedent and macos-15 runner pattern"
  - phase: "03-windows-e2e"
    provides: "SHA256 verify patterns precedent"
provides:
  - "Atomic draft-then-publish release workflow (.github/workflows/release.yml)"
  - "Tag-immutability CI guard detecting asset rewrites"
affects:
  - "Phase 6 (Lane R: RELEASE-CHECKLIST.md will reference release.yml sequencing)"
  - "HARDEN-03 cross-repo PR in smoodle-type/librime (universal dylib upload)"

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Draft-then-publish release pattern (gh create --draft → upload → edit --draft=false)"
    - "Tag-trigger only workflow (no workflow_dispatch)"
    - "Tag-immutability guard via created_at vs updated_at comparison"

key-files:
  created:
    - ".github/workflows/release.yml"
  modified: []

key-decisions:
  - "D1: Draft-then-publish atomic pattern — all assets uploaded while invisible, single publish step"
  - "D2: Tag-trigger only — no workflow_dispatch, smoke tests use test tags"
  - "D4: Tag-immutability guard with 5s sleep for API latency tolerance"
  - "D5: Human verification checkpoint mandatory before merge — passed green on v0.0.6-test-release"
  - "D7: macos-15 runner (same as Phase 2 E2E)"

patterns-established:
  - "Release workflow uses gh CLI for all release operations (create, upload, edit, view)"
  - "--clobber only safe in draft state — never used after publish"
  - "Tag immutability verified via gh release view --json assets with jq timestamp extraction"

requirements-completed:
  - HARDEN-04
  - HARDEN-05

# Metrics
duration: 12min
completed: 2026-05-11
---

# Phase 05 Plan 02: Release Hardening Summary

**Atomic draft-then-publish release workflow with tag-immutability CI guard on macos-15**

## Performance

- **Duration:** 12min
- **Started:** 2026-05-11T03:42:00Z
- **Completed:** 2026-05-11T03:54:00Z
- **Tasks:** 1 (Task 2 was manual verification, Task 3 is awareness note)
- **Files modified:** 1

## Accomplishments
- Created `.github/workflows/release.yml` with full draft-then-publish sequencing
- Tag-immutability guard comparing created_at vs updated_at after publish
- Human verification via live test tag (v0.0.6-test-release) — all steps passed green
- Test tag and release cleaned up after verification

## Task Commits

Each task was committed atomically:

1. **Task 1: Create .github/workflows/release.yml** - `1f34b7b` (feat)

## Files Created/Modified
- `.github/workflows/release.yml` — 97-line release workflow: tag-trigger → build DMG → SHA256 → draft create → upload assets → publish → immutability guard

## Decisions Made
None - followed plan as specified. Human verification checkpoint passed on first attempt.

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered
None.

## User Setup Required
None - no external service configuration required.

## Next Phase Readiness
- Release workflow is live-verified and ready for production tag pushes.
- HARDEN-03 (universal dylib) still requires cross-repo PR in smoodle-type/librime — tracked separately.
- All Phase 5 plans (05-01 + 05-02) are complete and committed.

---
*Phase: 05-sparkle-and-release-hardening*
*Completed: 2026-05-11*
