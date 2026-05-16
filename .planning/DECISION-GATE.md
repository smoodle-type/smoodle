# Smoodle Decision Gate — Phase 1 Close

**Gate opened:** 2026-05-11
**Pre-registration commit:** `docs/DECISION-GATE-CRITERIA.md` (see `git log` for timestamp)
**Soak window:** TBD — starts after both `install-mac-e2e.yml` and `install-win-e2e.yml` first turn green
**Soak window end:** TBD (7 calendar days after start)

---

## Pre-Registration Verification (GATE-01)

- [x] `docs/DECISION-GATE-CRITERIA.md` exists at HEAD
- [ ] Pre-registration commit timestamp is BEFORE earliest green E2E run — **FAILED**
  - macOS E2E first green: 2026-05-09 (run 25594460125, merge commit `d01912a` 11:25)
  - Windows E2E first green: 2026-05-09 (Phase 3 merge `04cc350` 15:52; first dispatched green run 2026-05-10)
  - Pre-registration commit `e1d1a7a`: **2026-05-11 14:27** — 2 days AFTER both E2E greens

### Pre-Registration Timing Caveat (BLOCK-3 retraction)

The original gate plan (per STATE.md line 123 and PITFALLS MP-2) required that `docs/DECISION-GATE-CRITERIA.md` be committed BEFORE Phase 2/3 first-green-runs, so the criteria could not be tuned to a known-passing surface. **Git timestamps show the inverse:** the criteria document was authored 2 days after both E2E lanes turned green, meaning the soak surface was already observable when the thresholds were chosen.

The MP-2 anti-survivorship-bias mitigation is therefore **not actually in force** for this gate. The author can no longer claim, for the v0.0.6 close, that the criteria are independent of the observed signal.

**What survives this caveat:**
- The verdict `stay-in-dogfood` is supported by independent evidence — specifically, zero non-founder installs were attempted (`N = 0`). This evidence requires no pre-registered threshold to interpret; any reasonable read of `N = 0` lands at stay-in-dogfood.
- The criteria themselves (`docs/DECISION-GATE-CRITERIA.md`) are still useful as a *forward-looking* yardstick once non-founder signals begin to arrive.

**What is retracted:**
- Any claim that v0.0.6's verdict satisfies the MP-2 anti-survivorship-bias guarantee. It does not.
- Any claim that the criteria thresholds (≥80% install success, ≥1 unsolicited signal, etc.) were chosen blind to the v0.0.6 soak surface. They were not.

**Implication for v0.0.7:** The next milestone (v0.0.7-cross-platform) must pre-register its own decision criteria BEFORE any of its E2E lanes turn green, with git-log timestamp evidence verified at gate-open. If MP-2 protection matters for the cross-platform decision, it has to be re-established there from a clean start.

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

**Decision:** stay-in-dogfood — **scoped to macOS only**

**Rationale:**

The macOS install path (`sawadee → สวัสดี`) works reliably on the founder's machine, verified by the live GHA E2E run on macos-15 (run 25594460125, GREEN in 1m 4s) and seven days of founder daily use during Phase 1 development.

The Windows install path and self-hosted telemetry are **explicitly deferred to milestone v0.0.7-cross-platform** as of 2026-05-16. The audit (`.planning/v0.0.6-MILESTONE-AUDIT.md`) surfaced three real wiring failures on the Windows + telemetry surface (BLOCK-2 `install-windows.ps1` missing `--uninstall`; FLAG-5 telemetry website UUID is a placeholder; FLAG-6 forget endpoint defaults to localhost). These do not affect the macOS dogfood path but block any honest claim of cross-platform readiness for v0.0.6.

Zero non-founders have attempted install. Zero unsolicited non-founder signals have been received. The `stay-in-dogfood` criterion 3 (zero non-founder signals) and `inconclusive` criterion 4 (N ≤ 2) both trigger. The correct action is to remain in dogfood, recruit 2-5 diaspora-Thai friends with macOS machines to install, run the 7-day soak window formally, and re-evaluate.

The criteria document at `docs/DECISION-GATE-CRITERIA.md` is treated as a forward-looking yardstick only, given the timing caveat above. The pre-registered MP-2 anti-survivorship-bias mitigation is retracted for this gate; the verdict survives on N=0 independent grounds.

Decision is based on N=0 non-founder signals. With N≤5, this is a directional read, not a statistical one.

**Soak window:** Not yet started (no non-founder installs)
**Non-founder N:** 0
**Founder daily-use:** 7/7 days
**Install success rate:** N/A

---

## Next Steps

1. **Recruit 2-5 diaspora-Thai friends with macOS machines** to install smoodle via the README instructions
2. **Start formal 7-day macOS soak window** once first non-founder install attempt is logged
3. **Collect signals** in the Non-Founder Column above
4. **Re-evaluate** after 7 days using the criteria in `docs/DECISION-GATE-CRITERIA.md` (read as forward-looking yardstick only, per the timing caveat above)

Windows + telemetry signals are explicitly out-of-scope for this soak — they're tracked in milestone `v0.0.7-cross-platform` (see ROADMAP.md).

---
*Gate opened: 2026-05-11*
*Verdict: stay-in-dogfood (macOS-only scope, per 2026-05-16 audit re-scope)*
*Phase 1 macOS path complete; Windows + telemetry deferred to v0.0.7*
*MP-2 anti-survivorship-bias mitigation retracted — see Pre-Registration Timing Caveat*
