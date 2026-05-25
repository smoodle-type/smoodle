# Smoodle Decision Gate Criteria — v0.0.7-cross-platform

**Pre-registered:** 2026-05-25
**Author:** founder (Apinant U-suwantim)
**Re-establishes:** MP-2 anti-survivorship-bias guarantee retracted in v0.0.6 (see `.planning/DECISION-GATE.md` § "Pre-Registration Timing Caveat").

> **This document MUST be committed to `main` BEFORE any v0.0.7 workstream's E2E lane is observed green.** Verifiable via `git log --diff-filter=A --follow -- docs/DECISION-GATE-CRITERIA-v0.0.7.md` vs first-green-run timestamps on the v0.0.7 workstreams.

## Purpose

v0.0.6 closed with three deferred surfaces (Windows installer, self-hosted telemetry, Linux disclosure) and a retracted MP-2 mitigation. v0.0.7-cross-platform must:

1. Close the deferred surfaces honestly (code-complete + live-verified).
2. Re-establish MP-2 by pre-registering criteria BEFORE the relevant E2E surfaces are observed.
3. Yield a verdict on whether smoodle can credibly leave dogfood (`ship-publicly-ready`) or must continue (`stay-in-dogfood` / `inconclusive`).

## Workstream Closure Criteria

Each workstream below has a binary closure test. All criteria are objective and machine-verifiable so a future audit can re-check independently.

### W1 — Windows installer parity (BLOCK-2 close)

| ID | Criterion | Verification |
|----|-----------|--------------|
| W1-C1 | `scripts/install-windows.ps1` accepts `--uninstall` flag and removes Squirrel + schema + telemetry markers | `pwsh -File scripts/install-windows.ps1 --uninstall` exits 0 with files removed on a Win11 GHA runner |
| W1-C2 | win E2E (`install-win-e2e.yml`) GREEN on 3 consecutive runs after `--uninstall` lands | `gh run list -w install-win-e2e.yml --limit 3 --status success` |
| W1-C3 | README Windows section documents `--uninstall` invocation | grep `--uninstall` in README.md Windows subsection |

### W2 — Telemetry deployment finish (FLAG-5 + FLAG-6 + FLAG-1 close)

| ID | Criterion | Verification |
|----|-----------|--------------|
| W2-C1 | `scripts/lib/telemetry.{sh,ps1}` `SMOODLE_TELEMETRY_WEBSITE` default is the live umami site_id (UUID `88042064-eeea-465a-8658-002d978d4f9b`), not the placeholder `a1b2c3d4-…` | `grep -q "88042064" scripts/lib/telemetry.{sh,ps1}` |
| W2-C2 | `scripts/lib/telemetry-forget.{sh,ps1}` `FORGET_URL` default is `https://forget.0dl.me/api/forget` (production HTTPS), not localhost | `grep -q "forget.0dl.me" scripts/lib/telemetry-forget.{sh,ps1}` |
| W2-C3 | umami live at `https://telemetry.0dl.me` with privacy triggers applied (`null_hostname`, `round_event_timestamp` BEFORE INSERT triggers exist on `website_event` and `session`) | `psql -c "\d website_event"` shows both triggers; smoke event stored with `hostname=NULL` and `created_at` at top-of-hour |
| W2-C4 | forget-api live at `https://forget.0dl.me/api/forget`; `DELETE ?install_id_hash=<hex>` returns `{"deleted":N}` where N matches real rows deleted (SQL filters via `event_data.data_key='install_id_hash'`, not the broken `event_name LIKE` pattern) | live curl round-trip: opt-in install → event lands → forget → row gone |
| W2-C5 | README has Telemetry/Privacy subsection that names the forget CLI as an invocable command (FLAG-1 close) | grep `smoodle telemetry forget\|telemetry-forget.sh` in README.md outside the file-tree block |
| W2-C6 | end-to-end smoke from a non-founder macOS machine: opt-in → install completes → DB shows event → `bash scripts/lib/telemetry-forget.sh` removes it | recorded in `.planning/phases/04-…/VERIFICATION.md` |

### W3 — Linux scope disclosure (FLAG-4 close)

| ID | Criterion | Verification |
|----|-----------|--------------|
| W3-C1 | One of: (a) `.github/workflows/install-linux-e2e.yml` is removed and reason logged in commit message, OR (b) it is added to ROADMAP as a formal phase with REQ-IDs | `git log -- .github/workflows/install-linux-e2e.yml` or grep ROADMAP.md |

### W4 — Cross-repo HARDEN-03 (universal dylib)

| ID | Criterion | Verification |
|----|-----------|--------------|
| W4-C1 | `smoodle-type/librime` tag `1.16.0-smoodle.2` (or `.1` rebuild) ships a universal `librime.dylib` (lipo arm64 + x86_64) | `lipo -info` shows both arches on the released asset |
| W4-C2 | `scripts/verify-librime.sh` validates the universal dylib SHA against sidecar | smoke run on dxc-built mac |

### W5 — Audit-trail backfill (FLAG-2 close)

| ID | Criterion | Verification |
|----|-----------|--------------|
| W5-C1 | `.planning/phases/0[4567]-*/VERIFICATION.md` exists for v0.0.6 phases 4, 5, 6, 7 (retroactive, references the audit + integration-check as primary evidence sources) | `ls .planning/phases/0{4,5,6,7}-*/VERIFICATION.md` |

## Decision Verdicts

Evaluated after all 5 workstreams are code-complete + verified per above. Soak window starts when first cross-platform install lands on a non-founder Windows machine.

### `ship-publicly-ready` (cross-platform claim approved)

ALL of:

1. W1, W2, W3, W4, W5 closure criteria green (per above)
2. ≥3 non-founder installs across ≥2 OSes (mac + win, or mac + linux) with success rate ≥80% (event `install_success` recorded for ≥80% of opt-in `install_started` events)
3. Zero P0/P1 issues reported via either telemetry payload (`install_failed`, `librime_sha_mismatch=true`) or unsolicited user channels (issue tracker, Telegram, email) during a 7-day soak window
4. Founder has run `smoodle telemetry forget` round-trip at least once and confirmed DB row removal
5. `.planning/v0.0.7-MILESTONE-AUDIT.md` and `INTEGRATION-CHECK-v0.0.7.md` close with `status: clean` (no BLOCKs)

### `stay-in-dogfood` (continue private soak)

ANY of:

1. W1, W2, W3, or W4 closure criterion fails on the live surface (not just code-complete on disk)
2. Non-founder install success rate < 80% across the soak window (rate computed: `count(install_success) / count(install_started)` filtered on `install_id_hash != founder_hash`)
3. Zero non-founder install events received during the soak window (analogous to v0.0.6 N=0 trigger)
4. Any P0 issue (data loss, schema corruption, install bricks a working IME setup) reported by any channel
5. `.planning/v0.0.7-MILESTONE-AUDIT.md` lists ≥1 BLOCK or ≥3 FLAGs at gate-open

### `inconclusive` (extend soak window)

ALL of:

1. No P0/P1 issues observed
2. 1 ≤ non-founder N ≤ 2 (data exists but too thin to call success rate)
3. Founder explicitly opts to extend the window by ≥7 calendar days

## Small-N Humility Caveat

With non-founder N ≤ 5 (likely for v0.0.7 the same as v0.0.6), all verdicts are directional reads, not statistical inferences. The success-rate threshold (80%) is a yardstick for "did anything obviously break," not a confidence interval. If N ≥ 10 is achieved during the soak window, an addendum may be filed promoting the read to a statistical claim.

## Evidence Collection

For each non-founder install attempt:

- **Telemetry side:** `install_started` + (`install_success` | `install_failed`) events in `website_event` joined to `event_data` (data_key in `{install_id_hash, os, smoodle_version, librime_sha_match}`)
- **User side:** any unsolicited message (Telegram screenshot, GitHub issue, email)
- **Founder side:** `install_id_hash` of the founder's own machine recorded in `.planning/phases/07-*/FOUNDER-HASH.txt` so it can be filtered out of the success-rate calc

## Verdict Template

When v0.0.7's gate is opened, fill `.planning/DECISION-GATE-v0.0.7.md` using this template:

```
Verdict: <ship-publicly-ready | stay-in-dogfood | inconclusive>

Workstream closure (binary):
  W1 Windows parity:      [ ] PASS / [ ] FAIL
  W2 Telemetry live:      [ ] PASS / [ ] FAIL
  W3 Linux disclosure:    [ ] PASS / [ ] FAIL
  W4 Cross-repo HARDEN:   [ ] PASS / [ ] FAIL
  W5 Audit-trail backfill:[ ] PASS / [ ] FAIL

Soak data:
  Non-founder N:                   <int>
  Soak window length (days):       <int>
  install_success rate (non-fdr):  <pct>
  P0/P1 issues reported:           <int>
  Founder telemetry-forget tested: [ ] yes / [ ] no

Audit:
  v0.0.7-MILESTONE-AUDIT status:   <clean | gaps_found>
  INTEGRATION-CHECK-v0.0.7 status: <BLOCK/FLAG/PASS counts>

Pre-registration verification:
  This doc's first commit timestamp: <git log --diff-filter=A --follow -- docs/DECISION-GATE-CRITERIA-v0.0.7.md>
  First v0.0.7 E2E green timestamp:  <gh run list --limit 1 --status success --json createdAt>
  MP-2 timing OK:                    [ ] yes (pre-reg before any green) / [ ] no (timing caveat applies)

Rationale: <2-4 sentences>

Next: <recruit more | open v0.0.8 | publish | other>
```

---

*Pre-registered before any v0.0.7 E2E lane is observed green. This commit is the timing anchor for MP-2 (BLOCK-3 carry-over closure).*
