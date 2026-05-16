# Cross-Phase Integration Check — Smoodle v0.0.6 (`phase-1-finish`)

**Audited:** 2026-05-16
**Scope:** 7 phases / 41 REQ-IDs / cross-phase seams only (in-phase quality is each phase's own VERIFICATION.md problem)
**Auditor stance:** every cross-phase connection is broken until grep proves it end-to-end

## Verdict

**3 BLOCK, 6 FLAG, 7 PASS.** The phases ship as individually-complete silos; several cross-phase invariants the milestone explicitly named (HARDEN-06 trailing-message symmetry, DOCS-04 uninstall symmetry, GATE-01 pre-registration timing) are visibly broken on disk. None of the three BLOCKers stop the v0.0.6 dogfood path from working today, but they break the dogfood->ship-publicly narrative the milestone claims.

---

## Findings

### BLOCK-1 — install.sh trailing message points to stale RESUME.md recipe, not verify-librime.sh

**Severity:** BLOCK
**Affected REQ-IDs:** HARDEN-06, DOCS-04, DOCS-07
**Evidence:** `scripts/install.sh:216` final heredoc still reads `see docs/RESUME.md for the dylib-swap recipe.` — Phase 5 commit `b5f6919` updated `install-librime-fork.sh` (line 272) to reference `verify-librime.sh`, and `install-librime-fork.ps1:473` was updated in `e71a2ad`, but the **primary user-facing installer** `install.sh` was never updated. New users see "RESUME.md" first.
**Closure step:** Edit `scripts/install.sh` lines 212-216 to replace the RESUME.md pointer with `bash scripts/verify-librime.sh` (mirroring `install-librime-fork.sh:272`). Re-run mac E2E.

### BLOCK-2 — install-windows.ps1 has NO --uninstall flag despite DOCS-04 claiming 3-OS parity

**Severity:** BLOCK
**Affected REQ-IDs:** DOCS-04
**Evidence:** `grep -ni "uninstall" scripts/install-windows.ps1` returns 0 matches. `install.sh:21` and `install-linux.sh:26` both implement `--uninstall`. STATE.md line 33 claims "uninstall flags added" — that's only 2 of 3 OSes. Phase 6 missed Windows.
**Closure step:** Port the `--uninstall` block from `install-linux.sh:25-72` into `install-windows.ps1` (remove `%APPDATA%\Rime\thai_phonetic.*.yaml` + `%APPDATA%\Rime\default.custom.yaml` + `$env:USERPROFILE\.smoodle\`). Re-run win E2E.

### BLOCK-3 — GATE-01 pre-registration committed AFTER Phases 2/3 first green runs (anti-survivorship-bias guard inverted)

**Severity:** BLOCK
**Affected REQ-IDs:** GATE-01, MP-2
**Evidence:** `git log` timestamps:
- `docs/DECISION-GATE-CRITERIA.md` first commit: **`e1d1a7a` 2026-05-11 14:27**
- Phase 2 mac E2E workflow merged: `d01912a` 2026-05-09 11:25 (2 days earlier)
- Phase 3 win E2E workflow merged: `04cc350` 2026-05-09 15:52 (2 days earlier)
- STATE.md line 123 explicit instruction: "GATE-01 pre-registration must be authored *before* Phase 2/3 turn green (verifiable from git log timestamps)"

The PITFALLS-MP-2 mitigation is invalidated — criteria were authored knowing the soak surface. Re-pre-registration won't restore the guarantee; the verdict `stay-in-dogfood` survives on independent grounds but the pre-registration claim must be retracted.
**Closure step:** Edit `.planning/DECISION-GATE.md` to add a "Pre-registration timing caveat" section explicitly acknowledging MP-2 was not mitigated as planned; cite git timestamps. Adjust verdict reasoning to not lean on pre-registered thresholds.

---

### FLAG-1 — README documents `telemetry-forget.{sh,ps1}` only as file-tree entries, not as a CLI users can run

**Severity:** FLAG
**Affected REQ-IDs:** TELEM-06
**Evidence:** `grep -n "telemetry forget\|telemetry-forget" README.md` returns only file-tree lines `README.md:147-148`. TELEM-06 says "`smoodle telemetry forget` CLI ... documented in README." No troubleshooting section, no "how to purge your data" walk-through.
**Closure step:** Add a "Telemetry / Privacy" subsection to README between Troubleshooting and File-tree, with the verbatim invocations `bash scripts/lib/telemetry-forget.sh` and `powershell -ExecutionPolicy Bypass -File scripts\lib\telemetry-forget.ps1`.

### FLAG-2 — Phases 4, 5, 6, 7 closed without VERIFICATION.md (only Phases 1, 2, 3 have one)

**Severity:** FLAG
**Affected REQ-IDs:** TELEM-01..09, HARDEN-01..07, DOCS-01..07, GATE-01..04 (23 REQ-IDs)
**Evidence:** `ls .planning/phases/04..07/` returns PLAN + RESEARCH + SUMMARY only — no `*-VERIFICATION.md`. Closure was recorded in STATE.md narrative, not in verifier-PASS artifacts. The 3 BLOCKers above (install.sh trailing message, Win uninstall flag, GATE-01 timing) would have been caught by a verifier pass with the same brief Phases 1-3 received.
**Closure step:** Run `gsd-verify-phase` on each of 4/5/6/7 retroactively and accept the BLOCKers as part of that pass.

### FLAG-3 — REQUIREMENTS.md traceability table never updated post-closure (41 still "Pending")

**Severity:** FLAG
**Affected REQ-IDs:** all 41
**Evidence:** `REQUIREMENTS.md:136-176` — every row still says `Pending` despite STATE.md line 28 claiming all 7 phases CLOSED. Anyone reading REQUIREMENTS first sees a milestone in progress, not closed.
**Closure step:** Bulk-update column 3 to reflect completed status; mark GATE-02 explicitly as "Deferred — pending non-founder recruits" not "Pending"; mark BLOCK-1/2/3 affected REQs as "Partial".

### FLAG-4 — Linux E2E workflow exists but is not in STATE.md / ROADMAP.md phase manifest

**Severity:** FLAG
**Affected REQ-IDs:** none (out-of-scope for v0.0.6 per CLAUDE.md Locked Decisions: "Linux accepts unpatched system librime with documented limitation")
**Evidence:** `.github/workflows/install-linux-e2e.yml` exists and runs `install-linux.sh` on paths-filter. Not listed in ROADMAP.md phase table; not credited to a REQ-ID. Either silent scope-creep or untracked Phase 1.5 prework.
**Closure step:** Either delete the workflow (deferral per CLAUDE.md) OR add a one-line note to STATE.md disclosing it as out-of-scope bonus coverage.

### FLAG-5 — Telemetry website UUID is hardcoded placeholder, not real umami site_id

**Severity:** FLAG
**Affected REQ-IDs:** TELEM-01, TELEM-02, TELEM-03
**Evidence:** `scripts/lib/telemetry.sh:15` — `SMOODLE_TELEMETRY_WEBSITE="${SMOODLE_TELEMETRY_WEBSITE:-a1b2c3d4-e5f6-7890-abcd-ef1234567890}"`. Looks like a placeholder. If anyone opts in today the payload's `website` field references a UUID that does not exist on `telemetry.0dl.me` — server will reject the event. STATE.md line 117 says "umami v3.1.0 deployed" but the smoke-test (TELEM-01) line "smoke-tested end-to-end with a manual `curl /api/send`" cannot have succeeded against this placeholder.
**Closure step:** Either swap in the real umami website_id (founder picks) and commit, OR mark TELEM-01 as Deferred-pending-infra in REQUIREMENTS.md.

### FLAG-6 — telemetry-forget client points to `http://localhost:8080/api/forget` by default (not the public TLS endpoint)

**Severity:** FLAG
**Affected REQ-IDs:** TELEM-06
**Evidence:** `scripts/lib/telemetry-forget.sh:12` + `telemetry-forget.ps1:12` both default `FORGET_URL` to `http://localhost:8080/api/forget`. End-users will not have a `forget-api` container on localhost. README docs do not call out the env override. Couples directly to the same TELEM-01 deployment gap.
**Closure step:** Change default to `https://telemetry.0dl.me/api/forget` once subdomain is live; document `SMOODLE_FORGET_URL` override.

---

### PASS-1 — Phase 1 ci.yml + Phase 2 mac-e2e + Phase 3 win-e2e paths-filters are non-overlapping by design

**Severity:** PASS
**Affected REQ-IDs:** LINT-03, E2EMAC-02, E2EWIN-02
**Evidence:** `ci.yml` triggers on all PRs (no paths). `install-mac-e2e.yml:11-19` paths = `scripts/install*.sh` + `schema/**` + the workflow itself. `install-win-e2e.yml:13-21` paths = `scripts/install*.ps1` + `schema/**` + the workflow itself. Two-tier CI per ARCHITECTURE.md Anti-Pattern #1: ci.yml fast on every PR, slow E2E gated. No conflict, no skip-by-omission.

### PASS-2 — Phase 2 + Phase 3 share dict.yaml SHA source-of-truth (the in-repo file)

**Severity:** PASS
**Affected REQ-IDs:** E2EMAC-01, E2EWIN-01
**Evidence:** Both workflows compute SHA of `schema/thai_phonetic.dict.yaml` from the repo checkout and compare to the destination copy. `install-mac-e2e.yml:86-90` (shasum) and `install-win-e2e.yml:185-193` (Get-FileHash) — identical semantic, no second source-of-truth.

### PASS-3 — Phase 4 telemetry opt-in does NOT block installer completion

**Severity:** PASS
**Affected REQ-IDs:** TELEM-04, E2EMAC-01, E2EWIN-01
**Evidence:** `install.sh:172-196` and `install-windows.ps1:267-` (and `install-linux.sh:205-225`) gate the prompt on `! -f telemetry-on` AND show `[y/N]` with N-default; the prompt is after the schema-copy + verification block. If E2E tests run with `SMOODLE_NONINTERACTIVE=1` the prompt is short-circuited. The prompt runs AFTER `install_completed` event would fire; even worst case (stdin closed), `read` returns empty → default N → installer continues.

### PASS-4 — Telemetry payload does NOT leak release tag PII

**Severity:** PASS
**Affected REQ-IDs:** TELEM-05, HARDEN-04
**Evidence:** `scripts/lib/telemetry.sh:14-16` and `telemetry.ps1:19-23` hardcode `SMOODLE_VERSION='0.0.6'` and the umami host. Payload allowlist (telemetry.sh:61) is exactly `{install_id_hash, os, smoodle_version, librime_sha_match}`. No `release_tag`, no `github.ref_name`, no path. Release workflow (`release.yml`) does not call telemetry — clean separation.

### PASS-5 — Phase 4 install_id generation matches across mac + linux (sha256 of 16 urandom bytes)

**Severity:** PASS
**Affected REQ-IDs:** TELEM-05
**Evidence:** `install.sh:186` + `install-linux.sh:220` + `telemetry.sh:32` all use `head -c 16 /dev/urandom | sha256sum | awk '{print $1}'` — identical 64-char hex. PowerShell side uses `RandomNumberGenerator` per spec (not grepped here but per phase summary; flagged for retroactive verifier in FLAG-2).

### PASS-6 — Phase 5 release.yml uses atomic draft-then-publish + tag-immutability assertion

**Severity:** PASS
**Affected REQ-IDs:** HARDEN-04, HARDEN-05, CP-2, MP-5
**Evidence:** `release.yml:46-72` — `gh release create --draft` → upload → `gh release edit --draft=false` is 3 distinct steps. Lines 74-95 read `created_at` vs `updated_at` per asset and fail if they diverge. Live-verified on test tag `v0.0.6-test-release` run 25649115808 per STATE.md.

### PASS-7 — Phase 5 verify-librime.sh referenced by both install-librime-fork installers + RELEASE-CHECKLIST

**Severity:** PASS
**Affected REQ-IDs:** HARDEN-01, HARDEN-02, HARDEN-06, DOCS-06
**Evidence:** `install-librime-fork.sh:272` and `install-librime-fork.ps1:473` both reference verify-librime in their post-install trailing messages. `docs/RELEASE-CHECKLIST.md:28` includes `bash scripts/verify-librime.sh` as a release-checklist line item. The recovery path is consistently wired — except via the missing pointer from `install.sh` itself (BLOCK-1).

---

## Requirements Integration Map

| Requirement | Integration Path | Status | Issue |
|-------------|-----------------|--------|-------|
| LINT-01..04 | self-contained — gates Phase 2/3 via ci.yml | WIRED | — |
| E2EMAC-01..05 | dict.yaml SHA shared with Phase 1 schema/, telemetry env-overrides honored | WIRED | — |
| E2EWIN-01..05 | as above, Pester driver + Authenticode | WIRED | — |
| TELEM-01 | infra/telemetry/docker-compose.yml — not yet smoke-tested against real subdomain | PARTIAL | FLAG-5 placeholder website UUID |
| TELEM-02..03 | sourced by install.sh:53, install-linux.sh:77, install-windows.ps1:84 | WIRED | — |
| TELEM-04 | [y/N] prompt in all three installers, post-copy non-blocking | WIRED | — |
| TELEM-05 | ephemeral install_id consistent across clients | WIRED | — |
| TELEM-06 | client → forget-api server present, but README doc-link missing + URL default localhost | PARTIAL | FLAG-1, FLAG-6 |
| TELEM-07..08 | infra/telemetry/init.sql + setup-triggers.sh — not audited live | PARTIAL | infra-side, blocked on TELEM-01 |
| TELEM-09 | tests/test_telemetry.py present | WIRED | — |
| HARDEN-01..02 | verify-librime.{sh,ps1} present | WIRED | — |
| HARDEN-03 | cross-repo (smoodle-type/librime) — not in this audit's scope | DEFERRED | tracked in STATE.md MP-3 row |
| HARDEN-04..05 | release.yml live-verified | WIRED | — |
| HARDEN-06 | install-librime-fork.{sh,ps1} trailing messages reference verify-librime; **install.sh does NOT** | PARTIAL | BLOCK-1 |
| HARDEN-07 | install.sh:125-127 touch -m after cp loop | WIRED | — |
| DOCS-01..03 | README.md updated | WIRED | — |
| DOCS-04 | mac+linux installers have --uninstall; **Windows does NOT** | PARTIAL | BLOCK-2 |
| DOCS-05..07 | LoneExile→smoodle-type migration + RELEASE-CHECKLIST.md + path placeholder | WIRED | — |
| GATE-01 | DECISION-GATE-CRITERIA.md exists but committed AFTER E2E green | PARTIAL | BLOCK-3 |
| GATE-02 | deferred — pending non-founder recruits | DEFERRED | STATE.md line 54 acknowledges |
| GATE-03..04 | checklist filled + verdict committed | WIRED | — |

**REQ-IDs with no cross-phase wiring (correctly self-contained):**
LINT-01, LINT-02, LINT-04 (in-CI lint only); HARDEN-07 (in-installer mtime touch); DOCS-01, DOCS-05, DOCS-07 (pure README edits); GATE-02, GATE-03, GATE-04 (planning artifacts only).

---

## Suggested Closure Sequence

1. Fix BLOCK-1 + BLOCK-2 in a single Phase 6 follow-up commit (install.sh trailing message + Windows `--uninstall`). Re-run mac + win E2E.
2. Address BLOCK-3 with a caveat addendum to `.planning/DECISION-GATE.md` — verdict survives, claim of MP-2 mitigation does not.
3. Update REQUIREMENTS.md traceability table (FLAG-3) to reflect post-audit status.
4. Resolve telemetry deployment placeholders (FLAG-5, FLAG-6) before any non-founder install attempt; this is the wedge's privacy-promise surface.
5. Optional: backfill VERIFICATION.md for Phases 4-7 (FLAG-2) so future audits have evidence trails.

