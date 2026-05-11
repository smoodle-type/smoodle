# Smoodle CI Refactor — Next-Session Prompt

> Paste this in a new Claude Code session at the smoodle repo root,
> or just say "read docs/CI-REFACTOR-PROMPT.md and refactor the CI matrix."

---

## Mission

Refactor `smoodle-type/librime/.github/workflows/smoodle-build.yml` so
each OS job delegates to upstream's mature build workflows via
`workflow_call`, instead of inlining `make release` / `build.bat`.

**Why this is the next move:** the previous session (2026-05-06)
kicked off the CI matrix and discovered that:
- Our custom Windows job calling `build.bat thirdparty` directly fails.
- Upstream's `windows / build` job builds the **exact same source**
  cleanly across 4 variants (mingw + clang-x64 + msvc-x64 + msvc-x86).
- The gap is setup work (vcpkg bootstrap, boost paths, MSVC dev shell)
  that upstream's `windows-build.yml` already encodes.

The fix: stop reinventing the build, delegate to upstream's YAMLs.

## Read these first, in order

1. **Current workflow** (the file we're rewriting):
   `vendor/librime/.github/workflows/smoodle-build.yml` (119 lines).
2. **The pattern reference** (how upstream uses workflow_call):
   `vendor/librime/.github/workflows/release-ci.yml`. Note how each
   OS job is a 3-line `uses: ./.github/workflows/<os>-build.yml`
   stub with a `with:` block for plugin params.
3. **The called workflows** (already cross-platform-validated):
   - `vendor/librime/.github/workflows/macos-build.yml`
   - `vendor/librime/.github/workflows/linux-build.yml`
   - `vendor/librime/.github/workflows/windows-build.yml`
4. **Active TODO state:** `TODOS.md` items 3 step 5 + 5.

## Current state snapshot (2026-05-06)

```
smoodle-type/librime branch 1.16.0-smoodle:
  cf00ee70  test(dict): update PredictiveLookup expectation for the peek-sort fix
  d0692a4c  ci: add smoodle-build workflow
  a75b6a48  fix(dict): sort DictEntryIterator chunks on first Peek
  a251145d  chore(release): 1.16.0 :tada:        (upstream tag base)

Tag: 1.16.0-smoodle.1 → a75b6a48 (the patch only; pre-test-fix)

Last smoodle-build run: 25428394211
  ✅ macOS arm64 (canonical) — 3m58s
  ✅ Linux x64 (best-effort)  — 6m0s
  ❌ Windows x64 (best-effort) — build.bat thirdparty fails

Last Commit CI run (upstream's):  25428394245 — 10/10 jobs green
  including all 4 windows variants. Cross-platform evidence the
  patch + test fix are correct.
```

## Concrete steps

1. **Examine `release-ci.yml`** for the exact `workflow_call`
   incantation:
   ```yaml
   linux:
     uses: ./.github/workflows/linux-build.yml
   macos:
     uses: ./.github/workflows/macos-build.yml
     with:
       rime_plugins: hchunhui/librime-lua lotem/librime-octagram rime/librime-predict
   windows:
     uses: ./.github/workflows/windows-build.yml
     with:
       rime_plugins: hchunhui/librime-lua lotem/librime-octagram rime/librime-predict
   ```
   Decide whether smoodle needs the `rime_plugins` param (probably
   no — Phase 1 dogfood is dict-only, plugins land in Phase 1.5).

2. **Rewrite `smoodle-build.yml`** as ~30 lines:
   ```yaml
   name: smoodle-build
   on:
     push:
       branches:
         - '1.16.0-smoodle**'
       tags:
         - '1.16.0-smoodle.*'
     workflow_dispatch:

   jobs:
     macos:
       uses: ./.github/workflows/macos-build.yml
     linux:
       uses: ./.github/workflows/linux-build.yml
     windows:
       uses: ./.github/workflows/windows-build.yml
   ```
   Decide whether to keep `continue-on-error` on Windows (probably
   not — once it delegates to upstream's known-good config, it
   should pass cleanly).

3. **Commit on the `1.16.0-smoodle` branch** in `vendor/librime/`:
   ```
   ci: delegate smoodle-build to upstream {linux,macos,windows}-build.yml
   ```
   Body: explain that inlined build was missing setup steps that
   upstream's per-OS workflows already encode. Reference the
   discovery from run 25425316371 (Windows fail) vs run 25428394245
   (upstream's matrix passes 4 Windows variants on the same source).

4. **Push** `git push smoodle 1.16.0-smoodle`. CI fires automatically.

5. **Verify** all three jobs go green:
   ```
   gh run list -R smoodle-type/librime --limit 2
   gh api repos/smoodle-type/librime/actions/runs/<latest>/jobs --jq '.jobs[] | {name, conclusion}'
   ```
   Expected: `macos`, `linux`, `windows` all conclusion=success.

6. **Update `TODOS.md`** in smoodle:
   - TODO 3 step 5: flip from IN-PROGRESS → DONE with run URL.
   - TODO 5: mark CLOSED with the refactor commit SHA.
   - Maybe demote step 5 of TODO 3 entirely if Windows CI is now
     reliable (the original "deferred until Lane B kickoff" rationale
     is gone — we have working Windows CI now).

7. **Optional: tag `1.16.0-smoodle.2`** at `cf00ee70` if you want a
   release marker that includes the test fix + the new CI workflow.
   Phase 1 dogfood (current Squirrel dylib) is unaffected either way.

## Out of scope

Don't get pulled into:
- **GitHub Releases auto-publish** — upstream's `release-ci.yml` does
  this only when `github.repository == 'rime/librime'`. We can add
  fork-friendly Release publishing later, but Phase 1 dogfood is fine
  with workflow artifacts.
- **Cross-platform smoodle installer testing in CI** — that's Lane B
  (Windows) and Lane C (Linux) work, not the librime fork's CI.
- **Universal macOS binary (arm64 + x86_64 lipo)** — pre-public-ship
  gate per design doc.
- **Pinning brew/apt/vcpkg dep versions** — upstream's workflows
  pick reasonable defaults; pin if/when a real deployment-target
  problem surfaces.
- **Tagging `1.16.0-smoodle.2`** unless you specifically want a
  release marker. Phase 1 dogfood doesn't need a new tag.

## Verification

Done when:
- `smoodle-type/librime/.github/workflows/smoodle-build.yml` is ~30
  lines, three jobs delegating via `uses:`.
- `gh run list -R smoodle-type/librime --limit 1` shows the workflow
  completed-success.
- All three OS jobs in the run conclusion=success (no
  `continue-on-error` masking).
- `TODOS.md` reflects the closure.

Estimated time: ~15-30 minutes of focused work.

## Source of truth precedence

If anything in this prompt conflicts with `docs/PHASE1-PROMPT.md` or
the active TODOS, **the in-repo TODOS wins** — TODOS.md is the
canonical work tracker. This file is a runway for one specific task.

---

## Recent session summary (for context)

Phase 1 macOS dogfood is fully wired and live. v0.0.6 schema +
patched librime via the smoodle-type/librime fork tag `1.16.0-smoodle.1`
swapped into Squirrel.app. 56/56 engine fixture passes. The CI
matrix discovered that our patch was breaking an existing upstream
unit test — that's been fixed (`cf00ee70`) and the patch is now
fully cross-platform-validated. The only loose end is making our
own `smoodle-build` workflow leverage upstream's mature build
configs. That's this prompt's job.
