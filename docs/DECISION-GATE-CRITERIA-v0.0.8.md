# Smoodle Decision Gate Criteria — v0.0.8-installer-ux

**Pre-registered:** 2026-05-26
**Author:** founder (Apinant U-suwantim)
**Re-establishes:** MP-2 anti-survivorship-bias guarantee for the v0.0.8 milestone — same discipline as v0.0.7's `DECISION-GATE-CRITERIA-v0.0.7.md` (commit 067d1c5).

> **This document MUST be committed to `main` BEFORE any v0.0.8a or v0.0.8b E2E surface is observed green.** Verifiable via `git log --diff-filter=A --follow -- docs/DECISION-GATE-CRITERIA-v0.0.8.md` vs first-green timestamps on the v0.0.8 workstreams.

## Purpose

v0.0.8 ships a drag-install DMG (v0.0.8a) followed by a Tauri config app (v0.0.8b) so recruits stop needing to clone+run install scripts. The gate decides whether v0.0.8 closes (recruits onboarded successfully) or stays open for more iteration.

## v0.0.8a closure criteria (binary, machine-verifiable)

| ID | Criterion | Verification |
|----|-----------|--------------|
| 8a-C1 | Smoodle-v0.0.8a.dmg published to gh releases with EdDSA sig | `gh release view v0.0.8a --repo smoodle-type/smoodle-app --json assets` shows `.dmg` + `.dmg.sig` |
| 8a-C2 | appcast.xml on gh-pages contains v0.0.8a entry | `curl -s https://smoodle-type.github.io/smoodle-app/appcast.xml \| grep -c "v0.0.8a"` ≥ 1 |
| 8a-C3 | Founder smoke-test passed | `.planning/phases/08a-dmg-sparkle/VERIFICATION.md` checklist marked PASS with timestamp |
| 8a-C4 | librime patch confirmed in shipped binary | `otool -tV /Applications/Smoodle.app/Contents/Frameworks/librime.1.dylib \| grep -c sorted_initial_` ≥ 1 |
| 8a-C5 | ≥2 non-founder recruits install DMG + report typing works | `.planning/SOAK-LEDGER-v0.0.7.md` has ≥2 rows with `v0.0.8a install=Y` AND `install_success=Y` |
| 8a-C6 | Sparkle synthetic update test green | `smoodle-app/tests/sparkle-update-test.sh` exits 0 in nightly CI |

## v0.0.8b closure criteria (binary, machine-verifiable)

| ID | Criterion | Verification |
|----|-----------|--------------|
| 8b-C1 | Smoodle Config.app present in v0.0.8b DMG | After `hdiutil attach Smoodle-v0.0.8b.dmg`, both `Smoodle.app` and `Smoodle Config.app` exist at the mount root |
| 8b-C2 | v0.0.8a installs auto-update to v0.0.8b via Sparkle (real recruit, not synthetic) | SOAK-LEDGER has ≥1 recruit row with `auto-updated-to-0.0.8b=Y` |
| 8b-C3 | Words tab add+deploy round-trip works | Manual e2e checklist green + ≥1 recruit with `Words-added count` > 0 |
| 8b-C4 | Status tab shows correct running/version/word-count | Manual + ≥1 recruit screenshot in SOAK-LEDGER `feedback` column |
| 8b-C5 | Settings tab edits round-trip to default.custom.yaml | Manual + ≥1 recruit with `Settings-changed=Y` |
| 8b-C6 | Telemetry toggle + forget via GUI matches CLI behavior | Manual + DB cross-reference (`SELECT COUNT(*) FROM event_data WHERE string_value=<recruit hash>` before and after GUI forget) |
| 8b-C7 | ≥3 non-founder recruits used Config app at least once | SOAK-LEDGER `Config-opened=Y` for ≥3 |

## Verdicts

- **ship-publicly-ready:** ALL 8a-C1..C6 AND 8b-C1..C7 green AND zero P0/P1 issues reported during soak.
- **stay-in-dogfood:** ANY 8a or 8b criterion FAIL on live surface AND/OR ≥1 P0 issue reported.
- **inconclusive:** 1 ≤ non-founder N ≤ 2 with no P0 issues — extend soak.

## Out of v0.0.8 gate scope (deferred)

- Apple Developer ID + notarization (v0.1.0)
- Per-recruit bearer tokens (v0.0.9 if N>3)
- Runtime telemetry from Smoodle.app process (v0.0.9)
- Windows / Linux parity (v0.0.7 W1 owns Windows; Linux per CLAUDE.md)

---

*Pre-registered before any v0.0.8 E2E surface goes green. This commit is the timing anchor for MP-2.*
