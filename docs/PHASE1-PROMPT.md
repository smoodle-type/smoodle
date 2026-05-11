# Smoodle Phase 1 — Implementation Kickoff Prompt

> Paste this into a new Claude Code session at the smoodle repo root,
> or just say "read docs/PHASE1-PROMPT.md and let's start Phase 1."
> The agent should read the four source-of-truth documents listed
> below before doing anything else.

---

## Mission

Implement **Phase 1** of the smoodle cross-platform plan. Goal: ship
unsigned dogfood installers for macOS + Windows (Linux as stretch)
in ~3 months solo, distributing via GitHub Releases. Phase 1 is the
demand-validation rig before any commercial commitment.

The plan, decisions, scope, and test coverage are already designed and
reviewed (office-hours + plan-eng-review, 2026-05-05). This session is
**implementation**, not re-planning.

## Read these first, in this order

1. **Active plan (the design doc):**
   `~/.gstack/projects/smoodle/lex-main-design-20260505-141957.md`
   Contains: phase structure, Decision Gate signals, Open Questions
   with deadlines, Distribution Plan, Test Coverage Plan, Failure
   Modes, Worktree Parallelization, NOT-in-scope, Premises P1-P5.
   Status: `APPROVED` (Phase 0 closed 2026-05-06 — see below).

2. **Test plan (eng-review output):**
   `~/.gstack/projects/smoodle/lex-main-eng-review-test-plan-20260505-145430.md`
   Contains: per-OS install flows to verify, key interactions, edge
   cases, critical paths.

3. **Long-form project context:**
   `docs/RESUME.md` — architecture, file map, librime patch internals,
   critical caveats, "don't do" list. Some references in this doc
   point at v0.0.3 dict size; current state is v0.0.6 (14893 Thai
   words / 100% TNC freq≥50). Update RESUME.md when convenient.

4. **Captured TODOs:**
   `TODOS.md` — upstream librime PR + iOS BT-keyboard spike. Both
   not Phase 1 blocking; can run in parallel with packaging work.

## Current state (factual snapshot, 2026-05-05)

- Schema/dict: **v0.0.6**, `schema/thai_phonetic.{schema,dict}.yaml`
  + `schema/default.custom.yaml`. Dict is 58068 lines / 1.2MB.
- Tests: 56/56 passing in engine mode against `tests/v01_fixture.yaml`
  via `tests/test_dict.py --use-rime-api-console`.
- Vendored librime: 1.16.0 with peek-sort patch
  (`vendor/librime-1.16.0-peek-sort.patch`). macOS arm64-only build.
- Squirrel.app on this machine is running the patched librime (dylib
  swap, see `docs/RESUME.md` for the swap commands).
- macOS installer (`scripts/install.sh`) exists; copies YAMLs to
  `~/Library/Rime/`, prompts for manual Squirrel "Deploy" click.
- No Windows installer, no Linux installer, no CI workflow, no
  telemetry POST, no E2E tests for installers.

## OQ3 + OQ4 — RESOLVED 2026-05-05: Path A + smoodle-type/librime fork

Both unblocked in the kickoff session. Phase 1 ships on:

- **Path A** schema (algebra rules stay) — best-practice Rime
  schema architecture, future-proof for v0.2 LLM plugin work, dict
  stays compact.
- **smoodle-type/librime fork** — soft-fork of rime/librime 1.16.0 with the
  `DictEntryIterator::Peek` patch applied as a commit, tagged
  `1.16.0-smoodle.1`. Replaces `vendor/librime-1.16.0-peek-sort.patch`
  as the source-of-truth for the patch.
- **Distribution model:** installer dylib-swaps the host's bundled
  `librime.1.dylib` (macOS) / `librime.dll` (Windows) with our
  forked build. macOS dogfood already runs this way successfully;
  scripts/install.sh just needs to formalize the swap path.
- **Upstream PR (TODOS #1):** demoted to optional. Still file it
  (community goodwill + clean future), but Phase 1 ship does not
  depend on merge.
- **CI matrix for fork builds:** deferred until Lane B (Windows)
  kicks off. Phase 1 macOS-only dogfood builds from the tag locally.
- **Linux (Lane C):** still hard — fcitx5-rime / ibus-rime use
  system librime via package manager. Lane C scoping must pick
  forked-rime distro package vs LD_PRELOAD vs accept-unpatched.
  Defer that decision until Phase 0 finds user #2 + Lane A is
  actually shipped.

**First fork-bring-up steps (TODO #3 in TODOS.md):**
1. Fork `rime/librime` to `smoodle-type/librime` on GitHub.
2. Apply the contents of `vendor/librime-1.16.0-peek-sort.patch`
   as a real commit on the fork's `main` (or `1.16.0-smoodle` branch).
3. Tag `1.16.0-smoodle.1`.
4. Update `scripts/install.sh` to clone the tag instead of
   reading the loose patch file (or document the build-from-tag
   recipe in RESUME.md and keep install.sh dylib-swap-only).

## Decisions already locked in (eng review D1-D5)

- **D1 — Linux:** detect fcitx5 vs ibus at install time (~30 lines
  bash, `pgrep`-based detection of *running* IM not just installed).
- **D2 — Telemetry:** self-hosted umami or openpanel on user's
  existing infra. Opt-in, default OFF, no PII, install_id_hash only.
- **D3 — Auto-deploy:** hybrid. Try host CLI invocation
  (`osascript`/`rime_deploy`/`WeaselDeployer.exe /deploy`/`fcitx5 -r`/
  `ibus-daemon -r`); fall back to clear manual instructions on
  failure. Wrap CLI calls with 10s timeout.
- **D4 — LLM plugin:** moved to **Phase 1.5**. Phase 1 ships
  dict-only. Dict's 100% TNC freq≥50 coverage is enough surface
  to test the wedge cleanly without LLM tone disambiguation.
- **D5 — Test scope:** boil-the-lake. Full unit + E2E coverage
  per OS. Schema lint in CI. See test plan for specifics.

## Critical failure modes (must address in installer code)

These are silent-failure modes flagged in the eng review. Each
needs explicit verification + timeout in installer logic.

1. **Windows: winget reports Weasel install success but IME
   registration step silently skipped.** Mitigation: after install,
   invoke Weasel and verify candidate window appears. ~10 lines.
2. **Linux: fcitx5+ibus hybrid setups, detection picks the inactive
   one.** Mitigation: `pgrep -x fcitx5 || pgrep -x ibus-daemon` to
   pick the running IM, not just installed.
3. **Auto-deploy CLI hangs indefinitely if host isn't running.**
   Mitigation: wrap every host CLI invocation with 10s timeout
   (`timeout 10s ...` on Linux/macOS, `Wait-Process -Timeout` on
   Windows). Fall back to manual-instructions on timeout.

Total mitigation: ~50 lines extra installer code, ~1-2 days work.

## Worktree parallelization

After OQ3+OQ4 decided in day 1:

- **Lane A** — macOS installer + dmg build
  - Files: `scripts/install.sh` (evolve), `scripts/build-macos.sh`
    (NEW), `Makefile` or `build.sh`
  - Goal: notarized-able universal `.dmg` (sign deferred to
    pre-public-ship)
- **Lane B** — Windows installer + msi build
  - Files: `scripts/install-windows.ps1` (NEW),
    `scripts/build-windows.ps1` (NEW)
  - Goal: signable-later `.msi` distributable via GitHub Releases
- **Lane C** — Linux installer (stretch goal — defer if month 1.5
  slips)
  - Files: `scripts/install-linux.sh` (NEW), debian packaging,
    AUR PKGBUILD
- **Lane D** — Test infrastructure (parallel with A/B/C)
  - Files: `tests/test_installers.py`, `tests/test_schema_lint.py`,
    `tests/test_telemetry.py`
- **Lane E** — CI + E2E (after A/B merge)
  - Files: `.github/workflows/ci.yml`, `.github/workflows/release.yml`,
    `tests/test_install_e2e_mac.sh`, `tests/test_install_e2e_win.ps1`

Launch A + B + D in parallel via Task tool with `isolation: "worktree"`.
C is independent and can run alongside. E waits for A+B+C to merge.

## Phase 0 — CLOSED 2026-05-06 (self-only dogfood)

**Outcome:** Phase 0 closed without surfacing a non-founder Thai
learner. The wedge narrows from "Thai language learners (broad
segment)" to **"founder + diaspora-Thai friends as they surface"** —
explicitly accommodated by the design doc as a valid smaller wedge.

**Status flipped:** `APPROVED-PENDING-PHASE-0` → `APPROVED`.
Lane B (Windows) and Lane C (Linux) are unblocked for build investment.

**Decision Gate signal targets adjust accordingly:**
- Activity-ping target: revise from "≥10 active users on ≥2 platforms"
  to "founder dogfooding daily + 1-3 named friends post-Phase-1.5
  whenever they surface." Treat as qualitative, not quantitative.
- Engagement signal: ≥1 unsolicited bug report or feature request
  from a non-founder during Phase 1.5 (was: ≥3).
- Qualitative: ≥1 named non-founder converts to "uses this daily"
  voluntarily within Phase 1.5 (was: ≥5).

**Phase 0 protocol stays alive informally:** if a non-founder Thai
speaker / learner / heritage person surfaces during dogfood (language
exchange, diaspora friend, demo at a meetup), capture a 15-minute
observation session per the original protocol — first thing they
tried to type, where they got stuck, what they said out loud, what
surprised you — and append to a "Phase 0 evidence" section in this
file. The dogfood data point is more valuable than waiting for a
second user before shipping.

**Original assignment (kept for context):** within 7 days, find one
Thai language learner besides yourself, watch them try smoodle on
macOS for 15 minutes, don't help, capture the four observations
above. Founder self-identified as Thai learner #1 (heritage Thai,
dogfooding v0.0.6 daily on the patched librime).

## NOT in scope (Phase 1)

Don't get pulled into:
- LLM tone-disambiguation plugin (Phase 1.5)
- iOS / Android installers
- Code-signing certificates
- Apple notarization
- `smoodle.app` domain registration
- Mac App Store / Microsoft Store listings
- Auto-update infrastructure (Sparkle, Squirrel.Windows)
- Cross-device dict sync
- Stripe / payment integration
- Internationalized installer copy

All explicitly deferred with rationale in the design doc.

## How to start the next session

OQ3+OQ4 are RESOLVED (Path A + fork). Lane A first concrete steps:

1. Greet briefly. Confirm you've read the four source-of-truth docs.
2. Confirm fork status: has `smoodle-type/librime` been created + tagged
   `1.16.0-smoodle.1` yet? If not, that's TODO #3 — block or proceed
   on local-build path depending on user preference.
3. Harden `scripts/install.sh`:
   - 10s timeout on auto-deploy CLI invocation (Critical Failure
     Mode #3 — `osascript`/`rime_deploy` can hang).
   - Post-install verification: prompt user to type `sawadee` and
     report whether `สวัสดี` candidate appears.
   - Idempotency: timestamp-backup any existing
     `~/Library/Rime/thai_phonetic.*.yaml` before overwrite.
   - Document the dylib-swap recipe (already in RESUME.md, formalize
     into a `scripts/install-librime-fork.sh` helper).
4. Stand up `tests/test_installers.py` skeleton (per D5). Stub cases
   covering: detection (Squirrel present/absent), schema copy
   idempotency, deploy timeout handling.
5. Lane B + Lane D ready to launch in parallel worktrees via the
   Task tool whenever user pulls the trigger (Phase 0 closed 2026-05-06,
   no longer gating). At that point CI matrix for the fork (TODO 3
   step 5) becomes Phase 1 critical-path.

## Source of truth precedence

If anything in this prompt conflicts with the design doc, **the
design doc wins** — it's the canonical plan. This file is a
runway, not the runway.
