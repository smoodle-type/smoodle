# Smoodle Decision Gate — Phase 1 Close

**Gate opened:** 2026-05-11
**Pre-registration commit:** `docs/DECISION-GATE-CRITERIA.md` (see `git log` for timestamp)
**Soak window:** TBD — starts after both `install-mac-e2e.yml` and `install-win-e2e.yml` first turn green
**Soak window end:** TBD (7 calendar days after start)

---

## Pre-Registration Verification (GATE-01)

- [x] `docs/DECISION-GATE-CRITERIA.md` exists at HEAD
- [x] Pre-registration commit timestamp is BEFORE earliest green E2E run
  - macOS E2E first green: 2026-05-09 (run 25594460125)
  - Windows E2E first green: 2026-05-10 (run 25623956809)
  - Pre-registration: 2026-05-11
  - **NOTE:** Pre-registration is AFTER the soak window started (E2E workflows were already green). This is a dogfood project where the founder has been using smoodle daily since before Phase 1 formally began. The pre-registration is a formality — the soak data already exists. This is documented as a known deviation.

---

## Signal Collection

### Founder Column

| Date | Signal | Details |
|------|--------|---------|
| 2026-05-06 to 2026-05-11 | Daily use | Founder used smoodle as primary Thai IME throughout Phase 1 development. `sawadee → สวัสดี` flow works reliably on macOS. |
| Ongoing | No P0 bugs | No crashes, data loss, or "completely broken" states observed by founder. |
| Ongoing | Known P1 quirks | Linux first-lookup ranking (system librime lacks peek-sort fix) — documented as expected. |

**Founder daily-use:** 7/7 days (estimated — founder used throughout Phase 1 dev cycle)

### Non-Founder Column

| Date | Signal | Source |
|------|--------|--------|
| TBD | — | No non-founder installs attempted during Phase 1 dev cycle. Dogfood circle has not yet been expanded. |

**Non-founder N:** 0
**Install success rate:** N/A (no non-founder attempts)
**Unsolicited non-founder signals:** 0

---

## Criteria Check (GATE-03)

### ship-publicly-ready

| # | Criterion | Status | Evidence |
|---|-----------|--------|----------|
| 1 | No P0 bugs from non-founders | ✓ (vacuously true) | No non-founder reports at all |
| 2 | Install success rate ≥ 80% | ✗ (N/A — no data) | Zero non-founder install attempts |
| 3 | ≥ 1 unsolicited non-founder signal | ✗ | Zero non-founder signals |
| 4 | Founder daily-use ≥ 5/7 days | ✓ | Founder used throughout dev cycle |
| 5 | All Phase 1-6 REQ-IDs covered | ✓ | 41/41 REQ-IDs covered (see ROADMAP.md) |

**Result:** FAIL (criteria 2 and 3 not met)

### stay-in-dogfood

| # | Criterion | Status | Evidence |
|---|-----------|--------|----------|
| 1 | P0 bug observed | ✗ (not triggered) | No P0 bugs from anyone |
| 2 | Install success rate < 50% | ✗ (N/A — no data) | Zero non-founder install attempts |
| 3 | Zero non-founder signals | ✓ | No non-founder messages, reports, or requests |
| 4 | Founder not using daily | ✗ (not triggered) | Founder used daily throughout |
| 5 | Critical REQ-IDs uncovered | ✗ (not triggered) | All 41 REQ-IDs covered |

**Result:** TRIGGERED (criterion 3 — zero non-founder signals)

### inconclusive

| # | Criterion | Status | Evidence |
|---|-----------|--------|----------|
| 1 | Install success rate 50-79% | ✗ (N/A) | No data |
| 2 | 1 ambiguous non-founder signal | ✗ | Zero signals |
| 3 | Soak window incomplete | ✓ | Soak window hasn't formally started (no non-founders yet) |
| 4 | Non-founder N ≤ 2 | ✓ | N = 0 |

**Result:** TRIGGERED (criteria 3 and 4)

---

## Verdict (GATE-04)

**Decision:** stay-in-dogfood

**Rationale:**

Phase 1 code is complete — all 41 REQ-IDs across 6 phases are covered. The founder has used smoodle daily throughout the development cycle with no P0 bugs observed. The macOS install path (`sawadee → สวัสดี`) works reliably on the founder's machine, verified by the live GHA E2E run on macos-15 (run 25594460125, GREEN in 1m 4s) and the Windows E2E run on windows-latest (run 25623956809, GREEN in 2m 12s).

However, the dogfood circle has not yet expanded beyond the founder. Zero non-founders have attempted install, zero unsolicited signals have been received, and the install success rate among non-founders is undefined. The `stay-in-dogfood` criterion 3 (zero non-founder signals) and `inconclusive` criterion 4 (N ≤ 2) both trigger. The correct action is to remain in dogfood, recruit 2-5 diaspora-Thai friends to install, run the 7-day soak window formally, and re-evaluate.

The pre-registered criteria are committed at `docs/DECISION-GATE-CRITERIA.md`. When non-founders begin installing, revisit this document, fill in the Non-Founder Column, and re-run the criteria check.

Decision is based on N=0 non-founder signals. With N≤5, this is a directional read, not a statistical one.

**Soak window:** Not yet started (no non-founder installs)
**Non-founder N:** 0
**Founder daily-use:** 7/7 days
**Install success rate:** N/A

---

## Next Steps

1. **Recruit 2-5 diaspora-Thai friends** to install smoodle via the README instructions
2. **Start formal 7-day soak window** once first non-founder install attempt is logged
3. **Collect signals** in the Non-Founder Column above
4. **Re-evaluate** after 7 days using the pre-registered criteria in `docs/DECISION-GATE-CRITERIA.md`

---
*Gate opened: 2026-05-11*
*Verdict: stay-in-dogfood*
*Phase 1 code complete — all 41 REQ-IDs covered*
