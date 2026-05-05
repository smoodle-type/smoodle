# Smoodle TODOs

Captured items that are real work but not blocking the active milestone.
For active execution plan, see the design doc at
`~/.gstack/projects/smoodle/lex-main-design-20260505-141957.md`.

---

## 1. Upstream librime PR — DictEntryIterator::Peek first-call sort

**Status:** OPEN
**Created:** 2026-05-05 (eng review, /plan-eng-review)
**Priority:** Low — Path A + LoneExile/librime fork (TODO 3, kickoff
2026-05-05) absorbs the patch via fork. Upstream merge becomes
optional / community-goodwill / fork-retirement trigger; not gating
any Phase 1 milestone.

**What:** Submit the contents of `vendor/librime-1.16.0-peek-sort.patch`
to upstream rime/librime on GitHub.

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
2. Wire local `vendor/librime/` to the fork as `origin` (or add
   as a `smoodle` remote alongside upstream `rime/librime`).
3. Apply `vendor/librime-1.16.0-peek-sort.patch` as a real commit
   on a `1.16.0-smoodle` branch. Commit message:
   "Patch DictEntryIterator::Peek first-call sort (smoodle fork)"
   with body explaining the bug + smoodle's repro.
4. Tag `1.16.0-smoodle.1` at that commit. Push tag.
5. Build per-OS dylibs from the tag (macOS arm64 first; Lane B will
   add Windows DLL + macos-13 Intel + lipo into universal mac).
6. Update `docs/RESUME.md` to reference the fork tag instead of the
   loose `.patch` file. Keep the loose patch file in `vendor/` as
   a fallback / documentation reference for ~1 release cycle.
7. Update `scripts/install.sh` (or new `scripts/install-librime-fork.sh`)
   to build-or-fetch the fork-tagged dylib and dylib-swap into
   Squirrel's `Frameworks/`.

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

**Status:** OPEN
**Created:** 2026-05-05 (Phase 1 kickoff baseline diagnostic)
**Priority:** Low — does not block fork bring-up, but blocks
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

## Closing notes

- Add new TODOs as they're discovered. Each item gets: status, created
  date, priority, what/why/steps/dependencies/done-when.
- When closing a TODO, change status to CLOSED with date + 1-line
  outcome. Don't delete — kept history is useful.
- Items here are NOT blocking the active milestone. For Phase 1
  active work, see the design doc.
