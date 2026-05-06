# Smoodle TODOs

Captured items that are real work but not blocking the active milestone.
For active execution plan, see the design doc at
`~/.gstack/projects/smoodle/lex-main-design-20260505-141957.md`.

---

## 1. Upstream librime PR — DictEntryIterator::Peek first-call sort

**Status:** PR-READY (upgraded 2026-05-06 after CI validation)
**Created:** 2026-05-05 (eng review, /plan-eng-review)
**Priority:** Low — Path A + LoneExile/librime fork (TODO 3, kickoff
2026-05-05) absorbs the patch via fork. Upstream merge becomes
optional / community-goodwill / fork-retirement trigger; not gating
any Phase 1 milestone.

**Validation evidence (2026-05-06):** the patch + test fix together
pass upstream's full CI matrix on the LoneExile/librime fork — 10/10
jobs green: lint + macos-15 + macos-15-intel + linux gcc + linux
clang + docker + 4 windows variants (mingw + clang-x64 + msvc-x64 +
msvc-x86). See run
https://github.com/LoneExile/librime/actions/runs/25428394245 .
This is exactly the cross-platform evidence the upstream PR review
will ask for.

**What:** Submit two commits as a single upstream PR:
- `a75b6a48` (`fix(dict): sort DictEntryIterator chunks on first Peek`)
- `cf00ee70` (`test(dict): update PredictiveLookup expectation for the peek-sort fix`)

The test-fix commit is required because `test/dictionary_test.cc`
was previously asserting the buggy behavior (咋/za winning on
alphabetical syllable-id sort regardless of weight). With the
peek-sort fix, the test fixture's higher-weighted 则 (ze, 28270)
correctly takes position #1 over 砸 (za, 6923). Without the
companion test fix, upstream CI fails on every platform.

**Why it matters:** If upstream merges, smoodle can drop the
LoneExile/librime fork (TODO 3) and ship against system librime
everywhere. Until merge, the fork carries the patch. Also benefits
any other Rime schema author hitting the same bug (Mandarin pinyin
variants, Cantonese, Japanese romaji collisions, etc.).

**Concrete steps:**
1. Reduce repro to minimal failing case (3 dict entries + 1 derive
   rule). The smoodle case `yaai → yai` colliding with direct `yai`
   already serves as a clean repro.
2. Open issue on rime/librime describing the bug with repro.
3. Open PR with the patch (~10 lines in
   `src/rime/dict/dictionary.{cc,h}` adding a `sorted_initial_`
   flag). Reference the LoneExile/librime fork's commit as a working
   implementation if helpful.
4. Monitor / respond to maintainer feedback. PR review timeline is
   weeks-to-months.

**Depends on / blocked by:** Nothing strategic. Decoupled from
Phase 1 packaging via fork.

**Done when:** PR is merged into rime/librime master (then drop
LoneExile/librime fork — see TODO 3), OR closed with "won't fix" and the
reasoning is documented here.

---

## 2. iOS external-keyboard interception spike

**Status:** OPEN
**Created:** 2026-05-05 (eng review, /plan-eng-review)
**Priority:** Low (Phase 2 scoping question, not Phase 1)

**What:** Test whether third-party iOS keyboard extensions can
intercept input from an external Bluetooth keyboard on iPad/iPhone.

**Why it matters:** Phase 2 iOS scope depends entirely on this answer.
If Apple locks external-keyboard layouts to system-level Apple-only
IMEs, iOS port = wasted effort and should be cut from Phase 2. If
third-party IMEs CAN handle external keyboards, iOS becomes a real
Phase 2 candidate — iPad + BT keyboard is a common Thai-learner setup.

**Concrete steps:**
1. Install a known third-party iOS IME on iPad with external BT
   keyboard connected. Candidates: Naver SmartBoard (Korean), Google
   Japanese Input via Gboard, AnySoftKeyboard ports.
2. Connect a BT keyboard. Try to type. Observe whether the third-party
   IME activates or whether iOS forces the system keyboard layout.
3. Document findings (1-2 paragraphs) and link from design doc Open
   Question 2.
4. If supported: iOS goes on the Phase 2 candidate list with proper
   estimate. If not: iOS gets cut from Phase 2 explicitly.

**Depends on / blocked by:** Hardware availability (iPad + BT
keyboard). ~30 minutes once gear is on hand.

**Done when:** Open Question 2 in the design doc has a definitive
yes/no answer with evidence.

---

## 3. Create LoneExile/librime fork — Path A bring-up

**Status:** OPEN
**Created:** 2026-05-05 (Phase 1 kickoff session)
**Priority:** High — Phase 1 Lane A bring-up depends on this for
versioned patch infrastructure. Macos dogfood works without it
(loose `.patch` file currently in `vendor/`), but fork is the
foundation for Lane B (Windows) + future librime patches discovered
during v0.2 LLM plugin work.

**What:** Establish a soft-fork of `rime/librime` as smoodle's
versioned librime distribution.

**Why it matters:**
- Path A (algebra rules in schema) requires the
  `DictEntryIterator::Peek` first-call sort patch on every shipping
  OS. Without upstream merge, smoodle must distribute the patch
  itself.
- Loose `.patch` files don't version cleanly, don't produce CI
  artifacts, and accumulate poorly if more patches are added later.
- Fork gives reproducible builds, tagged release artifacts, and a
  clean home for future librime changes (e.g., ABI hooks discovered
  during v0.2 LLM translator plugin development).
- License is BSD-3 (clean fork + binary distribution; no GPL
  contagion).

**Concrete steps:**
1. ✓ **DONE 2026-05-05** — `gh repo fork rime/librime --clone=false`
   created https://github.com/LoneExile/librime (default branch
   `master`, parent `rime/librime`).
2. ✓ **DONE 2026-05-05** — `git remote add smoodle https://github.com/LoneExile/librime.git`
   inside `vendor/librime/`. Origin still points at upstream.
3. ✓ **DONE 2026-05-05** — branched `1.16.0-smoodle` from upstream
   tag 1.16.0; committed peek-sort patch as
   `a75b6a48 fix(dict): sort DictEntryIterator chunks on first Peek`.
4. ✓ **DONE 2026-05-05** — annotated tag `1.16.0-smoodle.1` pushed
   to LoneExile/librime alongside the branch.
5. ⏳ **IN-PROGRESS 2026-05-06** — CI matrix kicked off via
   `LoneExile/librime/.github/workflows/smoodle-build.yml` (commit
   `d0692a4c` + test-fix `cf00ee70` on `1.16.0-smoodle` branch).
   - macOS arm64: ✅ canonical, green (3m58s)
   - Linux x64: ✅ green (6m0s)
   - Windows x64: ❌ fails at `build.bat thirdparty` direct invoke
     — but **upstream's `windows-build.yml` builds the same source
     cleanly across 4 variants** (mingw + clang-x64 + msvc-x64 +
     msvc-x86). The gap is setup (vcpkg bootstrap, boost paths)
     that upstream's workflow handles.
   - **Discovery 2026-05-06:** the right refactor is to make
     `smoodle-build.yml` delegate to upstream's `linux-build.yml`,
     `macos-build.yml`, `windows-build.yml` via `workflow_call`
     (same pattern `release-ci.yml` uses). Inherits all upstream's
     setup work; our YAML drops to ~30 lines of three job stubs.
     See TODO 5.
   Promotion to GitHub Releases (gated on `github.repository ==`)
   stays a manual step until per-OS distribution models settle.
6. ✓ **DONE 2026-05-05** — docs/RESUME.md rewired to reference the
   fork tag as primary source-of-truth. Loose patch retained as
   historical fallback for ~1 release cycle.
7. ✓ **DONE 2026-05-06** — `scripts/install-librime-fork.sh` (169
   lines) clones-or-uses-existing `vendor/librime/`, ensures the
   `smoodle` remote + fork tag are present, builds via `make
   release`, prompts for sudo, backs up the bundled
   `librime.1.dylib` to `librime.1.dylib.smoodle-backup` (only on
   first run), and copies the patched 2.5MB arm64 dylib into
   Squirrel's `Frameworks/`. Env overrides cover all the moving
   parts (FORK_URL, FORK_TAG, SQUIRREL_PATH, SKIP_BUILD, SKIP_SWAP,
   FORCE_REBUILD, NONINTERACTIVE). Six new shape tests in
   `tests/test_installers.py` (InstallLibrimeForkScriptShape) +
   one E2E stub in FutureLanes. Test suite: 17 active pass + 5
   skipped stubs.

   Universal binary (arm64 + x86_64) deferred to pre-public-ship
   gate per design doc — Phase 1 dogfood is arm64-only on the
   user's Apple Silicon machine.

**CI matrix (deferred):** Once Lane B kicks off, add
`.github/workflows/librime-build.yml` that builds dylib/.dll/.so
on macos-14 + macos-13 + windows-latest + ubuntu-latest, lipos the
two macOS dylibs, and uploads artifacts to GitHub Releases on tag
push. Phase 1 macOS-only dogfood does not need this.

**Linux gotcha:** fcitx5-rime / ibus-rime use **system librime**
via apt/pacman. Lane C (Linux installer) must decide between
shipping a forked-rime `.deb` / AUR package, using `LD_PRELOAD`
shim, or accepting unpatched-librime on Linux (algebra-vs-direct
ranking sometimes wrong). Out of scope for fork creation; surfaces
when Lane C scoping starts.

**Trigger to retire the fork:** TODO 1 (upstream PR) merges. At
that point, drop the smoodle commit, ship system librime
everywhere, simplify installers.

**Depends on / blocked by:** Nothing blocking. Step 1 cleared
2026-05-05 via `gh`. Steps 2-7 ready to proceed when convenient.

**Done when:** `LoneExile/librime` exists on GitHub, has a
`1.16.0-smoodle` branch with the peek-sort commit, has tag
`1.16.0-smoodle.1`, and `docs/RESUME.md` references the fork.

---

## 4. Rebuild vendor/librime against current homebrew deps

**Status:** ✓ CLOSED 2026-05-05 — root cause was missing `glog`
brew formula (Homebrew bumped past `libglog.2.dylib`). Fixed via
`brew install glog` (0.7.1 + gflags 2.3.0) + clean rebuild
(`rm -rf build && make release`). Engine fixture restored to
56/56 PASS against the rebuilt `rime_api_console`.
**Created:** 2026-05-05 (Phase 1 kickoff baseline diagnostic)
**Priority:** Low — did not block fork bring-up, but blocked
`tests/test_dict.py --use-rime-api-console` engine-mode runs.

**What:** The vendored `rime_api_console` binary at
`vendor/librime/build/bin/rime_api_console` was linked against
`libglog.2.dylib`, which Homebrew has since superseded (current
glog package no longer ships `.2.dylib`). All 56/56 fixture entries
fail engine-mode test with a dyld load error.

**Why it matters:** Engine-mode tests are the only way to exercise
the algebra-derived spellings end-to-end (string-match mode skips
20/56 algebra-tagged assertions). Without engine mode, regressions
in algebra rules or the peek-sort patch will not be caught locally.

**Concrete steps:**
1. `cd vendor/librime/build && cmake --build .` (incremental rebuild
   against current brew deps). If cmake cache is stale:
   `rm -rf vendor/librime/build && cd vendor/librime && make release`.
2. Re-run engine test:
   `python3 tests/test_dict.py --use-rime-api-console --fixture tests/v01_fixture.yaml`
3. Confirm 56/56 pass before any schema/dict edits.

**Depends on / blocked by:** Nothing. ~5-15 min of build time.

**Done when:** engine-mode test passes 56/56 against the rebuilt
`rime_api_console`.

---

## 5. Refactor smoodle-build.yml to use workflow_call

**Status:** NEXT (next-session focus per `docs/CI-REFACTOR-PROMPT.md`)
**Created:** 2026-05-06 (Phase 1 CI kickoff discovery)
**Priority:** Medium — unblocks Windows in our `smoodle-build.yml`
matrix. macOS + Linux already green; this closes the remaining gap.

**What:** Rewrite
`LoneExile/librime/.github/workflows/smoodle-build.yml` so each job
is a `workflow_call` into upstream's existing build workflows
instead of inlining `make release` / `build.bat`. Pattern reference
is upstream's `release-ci.yml`:
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

**Why it matters:** upstream's per-OS build YAMLs already handle
vcpkg bootstrap on Windows, brew deps on macOS, apt deps on Linux,
and per-architecture flags. Our inlined version reinvents the wheel
and drops the Windows ball. After refactor, `smoodle-build.yml`
shrinks to ~30 lines (3 job stubs) and Windows joins macOS + Linux
on the green matrix.

**Concrete steps:** see `docs/CI-REFACTOR-PROMPT.md` for the full
self-contained prompt that walks through the refactor.

**Done when:** `gh run list -R LoneExile/librime --limit 1` shows
all three OS jobs green on `smoodle-build`. Promotion to Releases
remains a separate concern (TODO 3 step 5 closure).

---

## Closing notes

- Add new TODOs as they're discovered. Each item gets: status, created
  date, priority, what/why/steps/dependencies/done-when.
- When closing a TODO, change status to CLOSED with date + 1-line
  outcome. Don't delete — kept history is useful.
- Items here are NOT blocking the active milestone. For Phase 1
  active work, see the design doc.
