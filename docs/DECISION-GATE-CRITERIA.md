# Smoodle Decision Gate Criteria

**Version:** v1.0
**Pre-registered:** 2026-05-11 (committed BEFORE soak observation — PITFALLS MP-2)
**Author:** founder
**Soak window:** 7 calendar days after both `install-mac-e2e.yml` AND `install-win-e2e.yml` first turned green

---

## Purpose

This document pre-registers the criteria by which Phase 1 closes. The verdict
is one of three options:

| Verdict | Meaning |
|---------|---------|
| **ship-publicly-ready** | The product works well enough to ship publicly (though additional polish may still be desirable). |
| **stay-in-dogfood** | The product needs more iteration before public exposure. |
| **inconclusive** | Signals are mixed or too sparse to make a confident call; extend soak or gather more data. |

Pre-registration prevents survivorship bias — adjusting criteria AFTER
observing signal is post-hoc rationalization (PITFALLS MP-2).

---

## Signal Columns

Signals are collected in TWO columns, never mixed:

| Column | What | Why |
|--------|------|-----|
| **Founder** | Daily-use observations from the founder (type quality, crashes, frustration moments, workflow fit) | Founder is a sophisticated user; their signal is rich but NOT representative of the broader audience. |
| **Non-founder** | Every external signal: bug reports, feature requests, install feedback, telemetry install counts, unsolicited messages | These are the people the product is actually for. Founder signal informs roadmap; non-founder signal decides the gate. |

**Rule:** The gate verdict is driven by the **Non-founder** column. The Founder column provides context but never overrides it.

---

## Criteria

### ship-publicly-ready

All of the following must be TRUE:

1. **No P0 bugs observed:** Zero crash reports, zero data-loss reports, or zero "completely broken" bug reports from non-founders during the soak window. P1 bugs (ranking quirks, missing features) are acceptable.
2. **Install success rate ≥ 80%:** Of non-founders who attempted install (counted from telemetry install_completed events OR direct reports), ≥ 80% reached a working `sawadee → สวัสดี` flow without founder intervention.
3. **≥ 1 unsolicited non-founder signal:** At least one bug report, feature request, or "this works for me" message from a non-founder that was NOT prompted by the founder asking "does it work?"
4. **Founder daily-use confirmed:** Founder used smoodle as their primary IME for ≥ 5 of the 7 soak days (self-reported).
5. **All Phase 1-6 REQ-IDs covered:** Every REQ-ID in `.planning/REQUIREMENTS.md` has a ✓ or a documented deferral note. Phase 1 code is complete.

### stay-in-dogfood

ANY of the following being TRUE triggers this verdict:

1. **P0 bug observed:** Any crash, data loss, or "completely broken" report from a non-founder.
2. **Install success rate < 50%:** More than half of non-founder install attempts required founder intervention or failed entirely.
3. **Zero non-founder signals:** No unsolicited messages, bug reports, or feature requests from non-founders during the entire 7-day window.
4. **Founder not using daily:** Founder reverted to their previous IME for ≥ 3 of the 7 soak days due to smoodle frustration.
5. **Critical REQ-IDs uncovered:** Any Phase 1-6 REQ-ID remains unimplemented (not just untested — actually missing).

### inconclusive

The verdict is inconclusive if:

1. **Install success rate 50-79%:** Some non-founders got it working, others needed help; not clearly a win or a loss.
2. **1 non-founder signal but ambiguous:** A single non-founder message that could be interpreted as positive OR negative depending on framing.
3. **Soak window incomplete:** The 7-day window hasn't fully elapsed (e.g., E2E workflows only turned green 3 days ago).
4. **Non-founder N ≤ 2:** Fewer than 3 non-founders attempted install; the sample is too small even for a qualitative read.

---

## Small-N Humility Caveat

> Decision is based on N=<num> non-founder signals. With N≤5, this is a
> directional read, not a statistical one. A "ship-publicly-ready" verdict
> means "the signals we have don't reveal blocking issues" — NOT "the product
> is proven to work at scale."

This caveat MUST appear verbatim in the verdict memo.

---

## Evidence Collection

| Signal type | Where it goes |
|-------------|---------------|
| Bug report | GitHub Issue URL (or email/DM screenshot) |
| Feature request | GitHub Issue URL (or email/DM screenshot) |
| Install success/failure | Telemetry dashboard URL + install_completed count, or direct report |
| Founder daily-use | Self-reported in `.planning/DECISION-GATE.md` founder column |
| Unsolicited feedback | GitHub comment, email, DM — link or quote |

---

## Verdict Template

```markdown
## Verdict

**Decision:** ship-publicly-ready | stay-in-dogfood | inconclusive

**Rationale:** (1-3 paragraphs explaining the decision, referencing specific
criteria that were met or failed.)

<small-N humility caveat verbatim from above></small-N>

**Soak window:** YYYY-MM-DD to YYYY-MM-DD (N days)
**Non-founder N:** <number of distinct non-founders who attempted install>
**Founder daily-use:** X/7 days
**Install success rate:** X/Y (XX%)
```

---
*Pre-registered: 2026-05-11*
*This document MUST be committed to `main` BEFORE any soak observation begins.*
