# Smoodle TODOs

Captured items that are real work but not blocking the active milestone.
For active execution plan, see the design doc at
`~/.gstack/projects/smoodle/lex-main-design-20260505-141957.md`.

---

## 1. Upstream librime PR — DictEntryIterator::Peek first-call sort

**Status:** DEFERRED 2026-05-06 — fork (TODO 3) absorbs the patch
indefinitely; upstream merge is community goodwill, not a Phase 1
gate. The CI evidence (run 25428394245 on Commit CI + run 25429514636
on the refactored smoodle-build) is preserved for the day we revisit.
Triggers to un-defer: (a) fork maintenance burden surfaces during
Phase 1.5/2 plugin work, (b) another Rime schema author hits the
same bug and asks, or (c) a quiet weekend with appetite for OSS work.
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
5. ✓ **DONE 2026-05-06** — CI matrix green across all 8 jobs after
   the workflow_call refactor. `smoodle-build.yml` now delegates to
   upstream's `linux-build.yml`, `macos-build.yml`,
   `windows-build.yml` via `workflow_call` (commit `69fc2399`,
   pattern matches upstream's `release-ci.yml`). Run
   https://github.com/LoneExile/librime/actions/runs/25429514636
   completed-success in 7m6s with no `continue-on-error` masking:
   - linux / build (gcc): ✅
   - linux / build (clang): ✅
   - macos / build (macos-15): ✅ (universal arm64+x86_64)
   - macos / build (macos-15-intel): ✅
   - windows / build (msvc, x64): ✅
   - windows / build (msvc, x86, x64_x86): ✅
   - windows / build (clang, x64): ✅
   - windows / build-mingw: ✅
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

**Status:** ✓ CLOSED 2026-05-06 — refactor landed at LoneExile/librime
commit `69fc2399`. `smoodle-build.yml` shrank from 119 lines (3
inlined jobs duplicating checkout / dep install / build / artifact
upload) to 20 lines (3 `workflow_call` stubs). Run
https://github.com/LoneExile/librime/actions/runs/25429514636
completed-success in 7m6s with all 8 matrix jobs green and no
`continue-on-error` masking. See TODO 3 step 5 for the per-job
breakdown. `docs/CI-REFACTOR-PROMPT.md` retained as historical
reference for the discovery → refactor flow.
**Created:** 2026-05-06 (Phase 1 CI kickoff discovery)
**Priority:** Medium — unblocked Windows in our `smoodle-build.yml`
matrix. macOS + Linux were already green; this closed the remaining gap.

**What:** Rewrote
`LoneExile/librime/.github/workflows/smoodle-build.yml` so each job
is a `workflow_call` into upstream's existing build workflows
instead of inlining `make release` / `build.bat`. Pattern reference
was upstream's `release-ci.yml`:
```yaml
macos:
  uses: ./.github/workflows/macos-build.yml
linux:
  uses: ./.github/workflows/linux-build.yml
windows:
  uses: ./.github/workflows/windows-build.yml
```
No `rime_plugins` parameter — Phase 1 dogfood is dict-only; lua /
octagram / predict plugins land in Phase 1.5.

**Why it matters:** upstream's per-OS build YAMLs already handle
vcpkg bootstrap on Windows, brew deps on macOS, apt deps on Linux,
and per-architecture flags. The previous inlined version reinvented
this and dropped the Windows ball. After the refactor,
`smoodle-build.yml` is 20 lines and the matrix is fully green.

**Done when:** `gh run list -R LoneExile/librime --limit 1` shows
all OS jobs green on `smoodle-build`. ✓ Verified
2026-05-06 via run 25429514636. Promotion to Releases remains a
separate concern.

---

## 6. Lane B test bed — dockur/windows on th-dc

**Status:** IN-PROGRESS 2026-05-06 — VM deployed + reachable; awaiting
human-eyes smoke (step 6) before flipping to ✓ DONE.
**Created:** 2026-05-06
**Priority:** High — unblocks Lane B installer dogfood. Without a
real Win 11 desktop, install-windows.ps1 ships "CI-green but
unverified on metal" (eng review Critical Failure Mode #2 risk).

**What:** Deploy [dockur/windows](https://github.com/dockur/windows)
on the th-dc remote docker context as the Lane B interactive test
bed. Win 11 + KVM + RDP/web-VNC access. Persistent storage so we
don't reinstall Windows every iteration.

**Config:**
- VM: Win 11, 16 GB RAM, 4 cores, 64 GB disk
- Storage: docker-managed named volume `windows-storage`
- Ports: 8006/tcp (web VNC), 3389/tcp+udp (RDP) — public on th-dc
- Credentials: `smoodle / smoodle` (test bed only)
- Compose file: `infra/lane-b-windows/docker-compose.yml`

**Why it matters:**
- LANE-B-WINDOWS.md Open Question 1 ("Windows machine for dogfood?")
  becomes "yes, on th-dc." Cheaper than a Parallels VM, no macOS host
  resources consumed, accessible from any device with RDP.
- Same VM serves as the rehearsal stage for the future MSI installer
  + code-signing dry runs at the pre-public-ship gate.
- TSF registration verification (Critical Failure Mode #2) requires a
  real Windows desktop; CI-only validation cannot prove it.

**Concrete steps:**
1. ✓ **DONE 2026-05-06** — verified th-dc capacity (64 CPUs, 189 GB
   RAM, 600 GB free disk, /dev/kvm present, Debian 12).
2. ⏳ **TODO** — write `infra/lane-b-windows/docker-compose.yml` +
   small README documenting deploy + access + lifecycle.
3. ⏳ **TODO** — `docker --context th-dc compose pull` (~6 GB ISO).
4. ⏳ **TODO** — `docker --context th-dc compose up -d`. Wait
   ~15-25 min for Win 11 unattended install.
5. ✓ **DONE 2026-05-06** — VM up + ports listening end-to-end.
   Dockur log: `❯ Windows started successfully, visit
   http://127.0.0.1:8006/ to view the screen...`. QEMU process alive
   2h22m+ at last check (Win 11 unattended install is normally
   15-25 min, so install has long since completed). Web VNC
   http://10.159.0.63:8006 returns HTTP 200; RDP TCP 3389 open.
   ISO download took 38m46s on first boot — subsequent restarts
   skip this and boot from the persistent `windows-storage` volume.
6. ⏳ **TODO** — first manual smoke: open
   http://10.159.0.63:8006 in a browser (or RDP via Microsoft Remote
   Desktop to th-dc:3389 user `smoodle` pass `smoodle`), run
   `winget install Rime.Weasel` inside the VM, prove TSF registers,
   type a Latin character, then uninstall. Confirms baseline before
   installer scripts land. Requires human eyes on the screen.

**Depends on / blocked by:** None. th-dc available + KVM-capable.

**Done when:** dockur/windows container is `up` on th-dc, web/RDP
reachable, fresh Win 11 desktop visible, and a single `winget
install Rime.Weasel` smoke succeeds.

---

## 7. Lane B installer scripts — install-windows.ps1 + install-librime-fork.ps1

**Status:** OPEN (depends on TODO 6)
**Created:** 2026-05-06
**Priority:** Medium — design doc parallel lane.

**What:** PowerShell parallels of macOS Lane A scripts:
- `scripts/install-windows.ps1` — schema YAMLs to `%APPDATA%\Rime\`
  + `WeaselDeployer.exe /deploy` with timeout + post-copy verify.
  Mirrors `scripts/install.sh` shape including env overrides
  (`SMOODLE_RIME_DIR`, `SMOODLE_WEASEL_PATH`, `SMOODLE_AUTO_DEPLOY`,
  `SMOODLE_DEPLOY_TIMEOUT_SECS`).
- `scripts/install-librime-fork.ps1` — fetch the LoneExile/librime
  fork, build Windows DLL on a CI runner artifact (or local MSVC),
  prompt for admin, swap `rime.dll` in
  `C:\Program Files (x86)\Rime\Weasel\`, backup convention
  `rime.dll.smoodle-backup`. Mirrors `install-librime-fork.sh`.
- Critical Failure Mode #2 mitigation (~10 lines): post-winget,
  verify `Get-WinUserLanguageList` shows Rime/Weasel TSF entry; if
  not, error with manual fix instructions.

**Concrete steps:** see `docs/LANE-B-WINDOWS.md` for full plan
including resource paths, distribution model (zip+scripts for
Phase 1), and effort breakdown (2-3 weeks total).

**Done when:** both scripts exist, shape tests in
`tests/test_installers.ps1` pass, and a manual run on the th-dc
VM types `sawadee → สวัสดี` end-to-end.

---

## 8. Lane C installer — install-linux.sh + GHA E2E

**Status:** OPEN (parallel to Lane B; no test bed dependency)
**Created:** 2026-05-06
**Priority:** Low — design doc stretch goal. Defer if month 1.5
slips.

**What:** Linux schema-only installer per `docs/LANE-C-LINUX.md`
recommendation (option 3 — accept unpatched system librime,
document the ranking limitation). Two artifacts:
- `scripts/install-linux.sh` — detect running IM (fcitx5 vs ibus
  via `pgrep`), copy schema YAMLs to the right per-IM dir, deploy
  with timeout. ~80 lines bash.
- GHA workflow: install ibus-rime via apt on `ubuntu-latest`, run
  install-linux.sh, verify schema deployment succeeds.

**Why it matters:** Linux is the smallest expected wedge audience
for Phase 1, but the script is cheap to write (Lane A is the model)
and zero-cost to test (free GHA runner). Better to land it than
defer.

**Concrete steps:**
1. ⏳ **TODO** — scaffold `scripts/install-linux.sh` skeleton with
   detection helper, env overrides, schema-copy stub.
2. ⏳ **TODO** — add `InstallLinuxScriptShape` test class to
   `tests/test_installers.py` (mirrors `InstallScriptShape`).
3. ⏳ **TODO** — convert the existing FutureLanes Lane C stub
   to a real shape test.
4. ⏳ **TODO** — flesh out detection + schema-copy + deploy logic.
5. ⏳ **TODO** — write `.github/workflows/install-linux-e2e.yml`
   running on `ubuntu-latest`.

**Done when:** `install-linux.sh` works on a real Ubuntu LTS box,
GHA E2E passes, ranking-limitation note added to README.

---

## Closing notes

- Add new TODOs as they're discovered. Each item gets: status, created
  date, priority, what/why/steps/dependencies/done-when.
- When closing a TODO, change status to CLOSED with date + 1-line
  outcome. Don't delete — kept history is useful.
- Items here are NOT blocking the active milestone. For Phase 1
  active work, see the design doc.
