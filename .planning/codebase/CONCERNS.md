# Codebase Concerns

**Analysis Date:** 2026-05-08

## Tech Debt

### Schema and Dictionary

**LoneExile/* references not yet migrated to `smoodle-type/*`:**
- The repo's GitHub org migration to `smoodle-type` is partially complete. Every shipped installer + the README correctly use `smoodle-type/librime`, but several docs still reference the legacy `LoneExile/librime` and `LoneExile/smoodle` URLs.
- Files that still mention `LoneExile`:
  - `README.md` lines 17, 109 (live install link to `LoneExile/librime`)
  - `docs/RESUME.md` lines 52, 181, 215, 329 (canonical "where the patch lives" pointer)
  - `docs/LANE-B-WINDOWS.md` lines 53, 184 (CI workflow path)
  - `docs/LANE-B-HARDENING-PROMPT.md` lines 12, 16, 122, 126
  - `docs/LANE-C-E2E-PROMPT.md` lines 10, 169
  - `docs/CI-REFACTOR-PROMPT.md` lines 10, 41, 114, 115, 150, 152, 171
- Impact: README's "Status" line links a 404-prone URL once the upstream fork is renamed/transferred. Anyone clicking through the README install instructions on a fresh clone follows a stale link.
- Fix approach: global text replace `LoneExile/librime` -> `smoodle-type/librime` and `LoneExile/smoodle` -> `smoodle-type/smoodle` across the six doc files; verify links still resolve.
- Priority: Medium - cosmetic + outbound-link-rot risk; not a runtime issue while the GitHub redirect from `LoneExile` -> `smoodle-type` still works.

**Schema docstring drift across versions:**
- Files: `schema/thai_phonetic.schema.yaml` (lines 18-46), `scripts/merge_dict.py` (lines 42-71 FRONTMATTER)
- Issue: Both files carry a long version-by-version changelog inlined into the schema header. Each release adds another paragraph; the v0.0.6 file now carries six. The schema YAML body description duplicates the merge script's `FRONTMATTER` constant.
- Impact: Two sources of truth for "what is in this dict at this version". Drift already visible: `docs/RESUME.md` line 32 says "v0.0.6 committed; install.sh ran but Squirrel Deploy still pending"; line 132-148 still describes a v0.0.3 file map ("dict at 2101 Thai words / 4050 entries").
- Fix approach: extract changelog to `CHANGELOG.md`; collapse schema description to current-state-only ("100% TNC freq>=50 coverage, TNC-weighted").

**Default-frequency fallback for non-TNC words:**
- File: `scripts/merge_dict.py` lines 201-204 (`--default-freq` defaults to 10)
- Issue: Words not in TNC (compounds split by tokenizer, modern slang, loanwords) get a flat `weight=10`, putting them below the lowest TNC-tail entry (`freq>=50`). Users typing common compounds may see them rank dead-last.
- Impact: Legitimate Thai words that exist in dict but missed by TNC bucket will rank poorly; user-facing OOV-feel even though dict has the entry.
- Fix approach: re-evaluate the default value, OR seed missing TNC entries from a secondary corpus (LST20, ORCHID), OR document the trade-off.

### Installer Scripts

**Hardcoded `smoodle-type/librime` release URL is single point of failure:**
- File: `scripts/install-librime-fork.sh` line 44 builds `RELEASE_URL` from `https://github.com/smoodle-type/librime/releases/download/${FORK_TAG}/${_ASSET_NAME}` where `_ASSET_NAME = librime-${FORK_TAG}-macOS-universal.dylib`.
- Issue: Three failure modes converge on this URL:
  1. GitHub Releases must contain a built asset matching `librime-1.16.0-smoodle.1-macOS-universal.dylib`. Per `TODOS.md` #3 step 5, "Promotion to GitHub Releases (gated on `github.repository ==`) stays a manual step until per-OS distribution models settle." So the asset may not exist at the URL.
  2. If GitHub is down or the fork is rate-limited, install fails. No mirror, no caching, no fallback CDN.
  3. The fork might be renamed or transferred; URL goes 404.
- Fallback when download fails: drops to `make release` source build (~5-15 min), requiring 9 brew deps. No third path.
- Impact: All Phase 1 dogfood macOS users are blocked behind a single GitHub Releases asset that may not yet be uploaded.
- Fix approach: verify release asset exists at the URL; if not, document the source-build path as primary in README; add a `vendor/macos/librime.1.dylib` parallel to `vendor/windows/rime.dll`.
- Priority: High - this is the macOS dogfood bring-up gate.

**Macos installer is arm64-only:**
- File: `docs/RESUME.md` line 70-73, the patched dylib is "2.5MB" arm64-only; bundled Squirrel dylib is "7.2MB" universal x86_64+arm64.
- Issue: `scripts/install-librime-fork.sh` swaps in whatever the release URL serves. If the release ships an arm64-only dylib (per `TODOS.md` #3 step 7: "Universal binary (arm64 + x86_64) deferred to pre-public-ship gate"), an Intel Mac user runs install, gets a successful "Squirrel's librime.1.dylib is now 2500 KB" message, and Squirrel breaks on next launch with no diagnostic.
- Impact: Silent failure for Intel-Mac dogfood users (small but nonzero population).
- Fix approach: detect host arch (`uname -m`) before swap; refuse to swap arm64 dylib onto x86_64 Mac with an explicit error; document as known limitation in README install section.
- Priority: Medium - matters as soon as the dogfood circle widens past Apple Silicon owners.

**Windows DLL distribution requires gh CLI + 7-Zip if no vendored DLL:**
- File: `scripts/install-librime-fork.ps1` lines 158-168
- Issue: When `vendor/windows/rime.dll` (committed BSD-3 DLL) is unavailable, the script bootstraps gh + 7zip via winget. Per `TODOS.md` #7 discovery #3: "the Ensure-WingetTool winget installs hang or block in non-interactive SSH sessions". The fix landed (vendoring the DLL in repo), but the fallback path is still the only option for git-shallow-clone users or anyone without `vendor/windows/`.
- Impact: dogfood breakage on minimal-clone Windows installs.
- Fix approach: ship `rime.dll` inside the eventual MSI; verify the vendored path is the universal default not a fallback.

**Linux ranking limitation is documented but not fixed:**
- Files: `scripts/install-linux.sh` lines 161-176, `docs/LANE-C-LINUX.md` lines 56-90
- Issue: Lane C ships option 3 (accept unpatched system librime). Algebra-vs-direct collisions rank wrong on first lookup; user workaround is "type, commit, retype". This is by design for Phase 1 but materially degrades Linux UX.
- Impact: smoodle on Linux is functionally inferior to macOS/Windows.
- Fix approach: tracked as TODOS.md #1 (upstream PR, deferred). Once upstream merges, Linux limitation disappears. Until then: accept.
- Priority: Low - already explicitly accepted, audience is small.

**Schema timestamp issue mitigation is Windows-only:**
- File: `scripts/install-windows.ps1` lines 174-179
- Issue: rsync/Copy-Item preserves source mtimes; if dict YAML is older than the WeaselDeployer build dir, deploy silently no-ops. Windows installer touches `LastWriteTime = Get-Date` to force recompilation. macOS `scripts/install.sh` (line 68 `cp`) does NOT touch timestamps - relies on Squirrel kill+restart to force recompile.
- Impact: Edge case where macOS install onto a system with stale Squirrel build cache could silently skip deploy, especially for users who restored `~/Library/Rime/` from Time Machine.
- Fix approach: mirror the Windows `LastWriteTime = now` touch in `install.sh` after the cp loop.
- Priority: Low - rare scenario, but cheap fix.

**Auto-deploy via osascript is fragile:**
- File: `scripts/install.sh` lines 95-109
- Issue: `osascript -e 'tell application id "im.rime.inputmethod.Squirrel" to quit'` requires Accessibility permission and AppleScript automation permission. First run on a fresh macOS user pops a permission dialog; if denied or timed out, auto-deploy fails. Script does fall back to manual instructions on timeout (line 113-117), so failure is recoverable, but the UX papers over a real friction point.
- Impact: First-run users see a permission popup, then a timeout warning. Confusing.
- Fix approach: detect AppleScript permission state up-front via `osascript -e 'tell ...'` health check before the deploy attempt; document Accessibility permission in README install section.

**`run_with_timeout` perl helper:**
- File: `scripts/install.sh` lines 22-38
- Issue: Implements timeout via `perl -e` because macOS does not ship GNU `timeout` by default. Uses `fork()` + `SIGALRM` + `waitpid`. Embedded in install.sh as a heredoc-style perl one-liner.
- Impact: Test infra (`tests/test_installers.py:524-565` `TimeoutHelper` class) extracts the helper via regex; if the helper is refactored, regex breaks. Perl dependency is implicit (perl is on every macOS but worth documenting).
- Fix approach: replace with `gtimeout` if user has coreutils (`brew install coreutils`), or `python3 -c` since python3 ships on macOS now. Keep fallback to perl for edge cases.

### Code Generation Pipeline

**Dict generation pipeline relies on external relay credentials:**
- File: `docs/RESUME.md` lines 174-178 references `.env` with `ANTHROPIC_CUSTOM_BASE_URL` + `ANTHROPIC_CUSTOM_AUTH_TOKEN` for `crs.0dl.me/api`.
- Issue: Reproducible dict regeneration depends on credentialed access to a third-party Claude API relay. If the relay disappears, future TNC freq updates can't be regenerated.
- Impact: dict refresh blocked on relay availability.
- Fix approach: document fallback to direct Anthropic API with notes on cost; commit `generated-tnc.tsv` + `generated-tnc-full.tsv` (already done) so regeneration is optional, not required.

**Double-reweight footgun in merge_dict.py:**
- File: `scripts/merge_dict.py` line 149-169 (`reweight_by_freq`); `docs/RESUME.md` lines 295-313 documents the trap.
- Issue: Re-running `merge_dict.py --tnc-freq` against an already-rescaled dict double-applies frequency, producing meaningless `f^2 * q / 10000` weights. There is no guard rail in code; only a documentation warning. RESUME.md line 311: "This bit us once in the v0.0.3 session".
- Impact: silent dict corruption if a future session forgets the rebuild-from-raw-quality-base recipe.
- Fix approach: add a sentinel marker (e.g., `tnc_rescaled: true` in YAML frontmatter) and have `--tnc-freq` refuse if it sees the marker without `--force`.

### Testing

**3 skipped tests in `tests/test_installers.py` (FutureLanes class, lines 567-596):**
- `test_telemetry_opt_in_default_off` (line 577): "Phase 1 telemetry milestone not yet implemented" - decision D2 in PHASE1-PROMPT.md mandates self-hosted umami/openpanel telemetry; no client implementation in repo yet.
- `test_auto_deploy_kill_restart_against_real_squirrel` (line 583): "E2E only: requires real Squirrel.app + dogfood machine" - tracked as Lane E (CI + E2E).
- `test_install_librime_fork_end_to_end` (line 589): "E2E only: needs sudo + ~5-15min make + real Squirrel.app" - same Lane E gap.
- Impact: Lane E (CI + E2E) is a phase-1 lane explicitly listed in `docs/PHASE1-PROMPT.md` lines 149-152 but no GHA workflows exist yet for macOS or Windows installer E2E. Only `.github/workflows/install-linux-e2e.yml` is wired up.
- Priority: Medium - shape tests catch drift cheaply but real install regressions can land undetected.

**No schema lint test:**
- Per `docs/PHASE1-PROMPT.md` line 109 (decision D5): "Schema lint in CI."
- Per Lane parallelization line 147-148: `tests/test_schema_lint.py` is listed but not present in repo.
- Impact: schema YAML can ship with errors that Squirrel reports only post-install via Console.app.

**No CI matrix for macOS/Windows installer scripts:**
- Only `.github/workflows/install-linux-e2e.yml` exists.
- Per `docs/PHASE1-PROMPT.md` line 149-152: Lane E should have `ci.yml`, `release.yml`, `test_install_e2e_mac.sh`, `test_install_e2e_win.ps1`. None exist in repo.
- Impact: macOS and Windows installer regressions are caught only via local dogfood.

**Engine-mode test fixture is 56 entries, dict is 28239:**
- File: `tests/v01_fixture.yaml` (35 direct + 21 algebra-tagged); dict is 28239 entries.
- Coverage ratio: ~0.2%. Fixture covers smoke + algebra cases but not regressions in the long tail (e.g., a v0.0.6-added word ranking wrong relative to a v0.0.4 word).
- Fix approach: sample-based regression fixture (top-N TNC words sampled randomly with deterministic seed).

**Shape tests for `install-windows.ps1` and `install-librime-fork.ps1` are regex/grep against the script body:**
- File: `tests/test_installers.py` classes `InstallWindowsPs1Shape` (lines 245-355) and `InstallLibrimeForkPs1Shape` (lines 357-444).
- Issue: True PowerShell syntax validation requires `pwsh` which is not on the macOS dev box (line 248 acknowledges this). Tests assert string presence (e.g., `self.assertIn("WeaselDeployer.exe", body)`), which silently breaks if a PowerShell parse error elsewhere is introduced.
- Impact: a syntactically invalid `.ps1` file can pass shape tests on the dev machine; only the th-dc test bed catches it.
- Fix approach: install `pwsh` via brew on dev box; CI runs `pwsh -NoProfile -Command "[scriptblock]::Create((Get-Content -Raw $script))"` for real parse check.

### Documentation

**README quality gaps:**
- File: `README.md`
- Issues:
  - Line 21: status says "Phase 1 status: APPROVED-PENDING-PHASE-0" but `docs/PHASE1-PROMPT.md` line 28 + line 156 says Phase 0 closed 2026-05-06 and status flipped to "APPROVED". README hasn't caught up.
  - Line 86 ASCII repo layout omits `infra/`, `docs/LANE-*` files, `vendor/windows/rime.dll`, `.github/workflows/`.
  - Line 17 link `LoneExile/librime` (see "LoneExile/* references" above).
  - No mention of `scripts/install-linux.sh` or `scripts/install-windows.ps1` in the install section despite both shipping; only macOS install is documented.
  - No Windows install snippet despite Lane B closed (TODOS.md #7).
  - No troubleshooting section for "I ran install but Squirrel doesn't show smoodle".
- Impact: README is the entry point for new dogfood users; outdated status + no Windows/Linux instructions blocks the diaspora-Thai-friends wedge.
- Priority: High - this gates the user-facing wedge expansion.

**Stale "Phase 0 closed" status not propagated:**
- README line 21: `APPROVED-PENDING-PHASE-0`
- `docs/PHASE1-PROMPT.md` line 28: `APPROVED-PENDING-PHASE-0` -> Phase 0 closed line 156-160
- `docs/RESUME.md` line 31: still describes "v0.0.6 committed; install.sh ran but Squirrel Deploy still pending on this machine" - personal-dev-state contamination in the architecture doc.
- Fix approach: single status pointer (e.g., `STATUS.md`); have README + RESUME read from there.

**RESUME.md mixes architecture, runbook, and user notes:**
- File: `docs/RESUME.md`
- Issue: 18KB single file containing: architecture decisions, file map, install commands, "what's likely next", per-session state, TODO list. Section "What's likely next" (line 195-229) is a personal-momentum journal, not stable architecture documentation.
- Impact: hard to reference for new contributors; updates require touching multiple unrelated sections at once.
- Fix approach: split into `ARCHITECTURE.md`, `RUNBOOK.md`, `STATE.md`. (Already partially exists in `.planning/codebase/` from prior mapping passes.)

**Hardcoded absolute path in dylib reapply recipe:**
- File: `docs/RESUME.md` line 67-69: `sudo cp /Users/lex/Dev/my_repos/experiment/smoodle/vendor/librime/build/lib/librime.1.16.0.dylib ...`
- Impact: copy-paste hostile; assumes one specific machine. New contributor or new clone breaks.
- Fix approach: use `${REPO_DIR}` placeholder or relative path with explicit "from repo root" instruction.

## Known Bugs

### `DictEntryIterator::Peek` first-call sort upstream bug (mitigated, not fixed)

**Symptoms:** When an algebra-derived spelling shares input with a direct dictionary entry, the alphabetically-earlier syllable ranks #1 regardless of weight on first lookup. E.g., `yaai` -> `yai` collides with direct `yai`; `ย้าย` ranks above `ใหญ่` even though TNC freq says otherwise.

**Files:**
- Patch source: `vendor/librime-1.16.0-peek-sort.patch` (loose patch, retained for ~1 release cycle)
- Live patch: `smoodle-type/librime` commit `a75b6a48` on `1.16.0-smoodle` branch, tagged `1.16.0-smoodle.1`
- Affected upstream: `src/rime/dict/dictionary.{cc,h}`
- Reference: `docs/RESUME.md` lines 43-55, 115-120; `TODOS.md` #1

**Trigger:** Algebra rules in `schema/thai_phonetic.schema.yaml` lines 84-110 (`derive/kh/k/`, `derive/aa/a/`, etc.) produce derived spellings that collide with direct entries.

**Workaround:**
- macOS/Windows: ship the patched fork dylib via the librime-fork installer (works).
- Linux: type input -> press space (commit) -> retype (second lookup ranks correctly). Documented in `scripts/install-linux.sh` lines 161-176 RANKING LIMITATION block.

**Priority:** Resolved on macOS/Windows via fork. Upstream PR (TODOS.md #1) is DEFERRED indefinitely; fork absorbs the fix.

### v0.0.6 deploy not yet exercised on dogfood machine

**Symptoms:** Per `docs/RESUME.md` line 32: "v0.0.6 committed; install.sh ran but Squirrel Deploy still pending on this machine."

**Files:** `~/Library/Rime/` on user's dev box; `schema/thai_phonetic.dict.yaml` v0.0.6 contents.

**Trigger:** version bump from 0.0.5 -> 0.0.6 (25 deferred words added), but no Squirrel "Deploy" click yet.

**Workaround:** click Squirrel menu -> Deploy. Not a code bug; a runbook gap. Listed as RESUME.md "What's likely next" #1.

### Sparkle auto-update overwrites patched librime

**Symptoms:** Squirrel ships a Sparkle auto-updater. When Squirrel updates (e.g., from 1.1.2 to 1.1.3), Sparkle replaces `Squirrel.app/Contents/Frameworks/librime.1.dylib` with the un-patched upstream universal dylib. Smoodle ranking degrades silently to the upstream-bug behavior.

**Files:** `/Library/Input Methods/Squirrel.app/Contents/Frameworks/librime.1.dylib`, backup at `librime.1.dylib.smoodle-backup`.

**Trigger:** Squirrel auto-update via Sparkle.

**Workaround:** re-run `bash scripts/install-librime-fork.sh` to reapply the swap. Documented in `scripts/install.sh` line 133-137 (the cat-EOF post-install note) and `scripts/install-librime-fork.sh` lines 193-195 + `docs/RESUME.md` line 64-69.

**Priority:** Medium - silent degradation, no detection mechanism. Could be addressed by a periodic LaunchAgent that re-swaps if the dylib hash drifts.

### WeaselDeployer can't run from SSH on Windows

**Symptoms:** Per `TODOS.md` #7 discovery #5: "headless SSH session has no display; GUI apps including WeaselDeployer.exe and WeaselServer.exe won't stay alive across SSH session boundary."

**Files:** `scripts/install-windows.ps1` lines 218-241 (auto-deploy block).

**Trigger:** Running install-windows.ps1 over SSH (no interactive desktop).

**Workaround:** user must click "Deploy" from Weasel tray icon manually. Acceptable for Phase 1 dogfood; blocks full automation.

**Priority:** Low - documented constraint, not a regression.

## Security Considerations

### `sudo` invocation in install-librime-fork.sh

**Risk:** Script writes to `/Library/Input Methods/Squirrel.app/Contents/Frameworks/` which is system-protected. Requires sudo (line 173 backup, line 179 swap).

**Files:** `scripts/install-librime-fork.sh` lines 161-179.

**Current mitigation:**
- Interactive confirmation prompt before sudo (line 164 unless `SMOODLE_NONINTERACTIVE=1`).
- Backup of original dylib before overwrite (line 172-176; only on first run).
- `set -euo pipefail` (line 31) so any error short-circuits.

**Recommendations:**
- Verify dylib SHA256 before swap (compare to known-good from CI artifact).
- Check Apple code signature on downloaded dylib (`codesign --verify`); reject if not signed.
- Pin the GitHub Releases asset by SHA, not by tag - tag can be rewritten.

### Unsigned dylib download from GitHub Releases

**Risk:** `scripts/install-librime-fork.sh` lines 78-87 curls a `.dylib` from GitHub Releases over HTTPS, then swaps it into a system-trusted location with no signature verification. The check is only `file ... | grep "Mach-O"` (line 79) - any Mach-O file passes.

**Files:** `scripts/install-librime-fork.sh` lines 74-87.

**Current mitigation:**
- HTTPS transport (curl `-fsSL`).
- Mach-O magic-byte check (binary-format only, not provenance).

**Recommendations:**
- Embed a known-good SHA256 in the script; verify before swap.
- Use `gh release download` with attestations (GitHub now supports SLSA provenance for releases) once the fork CI emits them.
- Drop `--silent` flag from curl so the download URL is visible to the user (`-fsSL` already strips progress; `-fL` would show URL).

### Windows DLL swap trusts CI artifact

**Risk:** `scripts/install-librime-fork.ps1` downloads a CI artifact via `gh run download` (lines 244-251) or uses a vendored DLL (lines 211-215) and swaps it into `Program Files\Rime\Weasel\rime.dll` with admin elevation. Same shape as the macOS concern but with admin scope on Windows.

**Files:** `scripts/install-librime-fork.ps1` lines 173-184 (admin gate), 244-288 (download), 314-353 (swap).

**Current mitigation:**
- Explicit admin-elevation check; bails with clear error if not admin (lines 177-184).
- Backup of original DLL before overwrite (line 315-320).
- 5x retry on Copy-Item to handle file-lock contention (lines 338-349).

**Recommendations:**
- Verify Authenticode signature on `rime.dll` before swap (`Get-AuthenticodeSignature`).
- Pin run-id when invoking from a release flow (currently `latest successful smoodle-build` is the default; a malicious PR triggering CI could potentially be installed).

### th-dc dockur/windows VM uses `smoodle / smoodle` credentials

**Risk:** `infra/lane-b-windows/docker-compose.yml` lines 32-33 sets `USERNAME: "smoodle" / PASSWORD: "smoodle"`. RDP port 3389 is exposed publicly per `TODOS.md` #6 ("Ports: 8006/tcp (web VNC), 3389/tcp+udp (RDP) - public on th-dc").

**Files:** `infra/lane-b-windows/docker-compose.yml`.

**Current mitigation:** "test bed only" annotation in TODOS.md #6.

**Recommendations:**
- Move RDP behind a Tailscale or VPN before the VM is left running long-term.
- Rotate credentials when th-dc is reachable from non-trusted networks.
- Document in `infra/lane-b-windows/README.md` that this is dev-only infra and must NOT host any artifacts that are referenced by user-facing installers (preventing supply-chain inversion).

### `.env` file in repo (gitignored)

**Risk:** `docs/RESUME.md` line 174 documents `.env` containing `ANTHROPIC_CUSTOM_AUTH_TOKEN` for `crs.0dl.me/api`. Listed in `.gitignore` per line 127 of RESUME.md, but local presence means a developer running `git add -A` could inadvertently stage it.

**Files:** `.env` (root, gitignored), `.gitignore`.

**Current mitigation:** gitignore entry; manual hygiene.

**Recommendations:** verify `.gitignore` covers `.env` + `.env.*` patterns; pre-commit hook to refuse staging `.env*`.

## Performance Bottlenecks

### Rime Deploy time on first install of v0.0.6

**Problem:** First `Deploy` on a fresh install compiles the 1.2 MB / 28239-entry dict YAML into Rime's internal binary tables. Per `docs/RESUME.md` line 197-201: "recompile of 28239 entries is the slowest deploy yet - still seconds, not minutes". Per `scripts/install-windows.ps1` line 80 + tests/test_installers.py line 342-347: deploy timeout was raised from 10s -> 60s because "10s was not enough for first compile of the 1.1 MB dict".

**Files:** `schema/thai_phonetic.dict.yaml` (58068 lines, 1.2 MB).

**Cause:**
- Dict is 5x larger than v0.0.3, 7x larger than v0.0.2.
- Rime compiles to a marisa-trie + leveldb on every dict-content change.
- Algebra rules (`speller.algebra` 14 rules) multiply effective input space.

**Improvement path:**
- Profile actual deploy time; verify <60s on commodity hardware.
- If users report >60s on Windows, consider splitting the dict into multiple translators (high-freq + low-freq) so the high-freq table re-compiles fast and low-freq compiles asynchronously.
- Or: ship pre-compiled `build/thai_phonetic.*` artifacts in the installer alongside the YAML; Weasel/Squirrel's deployer would skip the compile step. (Currently the Windows installer explicitly clears these on schema change to FORCE recompile, line 184-189.)

**Priority:** Low until user reports.

### Dict file size is 1.2 MB (single YAML)

**Problem:** `schema/thai_phonetic.dict.yaml` is 1.2 MB / 58068 lines. Slow to load in editors; large diffs on every regeneration; dominates git history.

**Files:** `schema/thai_phonetic.dict.yaml`.

**Cause:** TNC freq>=50 tail = 12792 Thai words; 1-3 variants each = ~28k entries; YAML overhead per entry.

**Improvement path:**
- Migrate to Rime's "compiled" `.bin` distribution model (tracking how `cantonese.dict.yaml`-style schemas distribute pre-compiled tables).
- Or: split by freq tier, ship as multiple files.

**Priority:** Low - editor pain, not user-runtime pain.

## Fragile Areas

### Installer script error paths assume macOS-specific binaries

**Files:** `scripts/install.sh`, `scripts/install-librime-fork.sh`.

**Why fragile:**
- `install-librime-fork.sh` line 82 uses `stat -f %z` (BSD stat) - GNU stat uses `stat -c %s`. macOS-only.
- `install.sh` line 64 uses `date +%Y%m%d-%H%M%S` - portable.
- `install.sh` line 95 uses `pgrep -x Squirrel` - present on macOS by default; portable.
- Brew dep paths line 95 of install-librime-fork.sh: `/opt/homebrew/opt/${d}` (Apple Silicon) and `/usr/local/opt/${d}` (Intel) hardcoded; doesn't probe `$HOMEBREW_PREFIX`.

**Safe modification:** any cross-platform refactor must replace `stat -f` with portable detection (`if stat --version 2>/dev/null | grep -q GNU; then ...`).

**Test coverage:** shape tests check syntax + presence of strings; no integration test on a non-macOS system for the macOS-named scripts.

### Two parallel installer flavors per platform with subtle drift

**Files:** Pairs:
- macOS schema-only: `scripts/install.sh`
- macOS librime swap: `scripts/install-librime-fork.sh`
- Linux schema-only: `scripts/install-linux.sh` (no librime swap)
- Windows schema-only: `scripts/install-windows.ps1`
- Windows DLL swap: `scripts/install-librime-fork.ps1`
- DMG bundle: `scripts/build-macos-dmg.sh`

**Why fragile:**
- Six scripts with overlapping responsibilities. Drift surface across:
  - schema file list (must match across all four installers + DMG)
  - timeout default (10s vs 60s)
  - backup convention (`.bak.<stamp>` vs `.smoodle-backup`)
  - env-override naming (some prefixed `SMOODLE_`, all consistent)
- Schema file list is hardcoded in 6 places (3 schemas x 2 platforms x 1 path each, plus DMG bundler).

**Safe modification:** centralize the schema file list in a shared config (e.g., `schema/MANIFEST` text file) read by all installers.

**Test coverage:** shape tests assert each installer references all three YAMLs (covered for install-windows.ps1 line 269-276, install-linux.sh line 89, etc.); but a typo could rename `default.custom.yaml` in only one installer and pass.

### Critical Failure Modes documented but mitigation drift possible

**Files:** `docs/PHASE1-PROMPT.md` lines 113-127, `docs/LANE-B-WINDOWS.md` lines 89-148, `docs/LANE-C-LINUX.md` lines 33-54.

**Why fragile:** Three Critical Failure Modes (CFM #1 winget Weasel, CFM #2 Linux pgrep, CFM #3 deploy timeout) are documented narratively across multiple files. Mitigations are spread:
- CFM #1: `install-windows.ps1` (winget block); empirically does not reproduce on Win 11
- CFM #2: `install-linux.sh` lines 29-43 (pgrep) - test_installers.py line 193-202 verifies
- CFM #3: timeout helper in `install.sh` lines 22-38; `WaitForExit` in `install-windows.ps1`; `timeout` in `install-linux.sh` line 128.

**Safe modification:** add CFM IDs as comments in installer code (e.g., `# CFM #2 mitigation: ...`) so refactors can find the link.

### Vendor directory layout differs across platforms

**Files:** `vendor/librime/` (gitignored, ~2GB), `vendor/windows/rime.dll` (committed, 2.7 MB), `vendor/librime-1.16.0-peek-sort.patch` (committed, historical fallback).

**Why fragile:**
- Windows DLL is committed; macOS dylib is NOT. Asymmetry surfaces in install scripts: Windows has a vendored fast path; macOS always downloads or builds from source.
- `vendor/librime/` is gitignored but referenced in install-librime-fork.sh line 34 as the build dir; first-time clone needs the build infra to work.
- The committed patch file is described as "historical fallback for ~1 release cycle" (RESUME.md line 53) - lifetime is informal; will it be removed at v0.0.7? v0.1?

**Safe modification:** add `vendor/macos/librime.1.dylib` parallel to `vendor/windows/rime.dll`; document a clear retention policy for `vendor/librime-1.16.0-peek-sort.patch` (e.g., "remove at v0.1").

## Scaling Limits

### Single-user dogfood

**Current capacity:** founder + diaspora-Thai friends per `docs/PHASE1-PROMPT.md` lines 156-160.

**Limit:** Phase 0 closed without surfacing a non-founder Thai learner. Wedge narrows from "Thai language learners (broad segment)" to "founder + 1-3 friends post-Phase-1.5".

**Scaling path:** unmodified macOS dogfood install path is end-to-end. Windows + Linux installers landed (TODOS.md #7, #8 closed). Decision Gate signals are now qualitative ("≥1 unsolicited bug report or feature request"); quantitative scaling explicitly deferred.

### TNC corpus is 100% covered at freq>=50

**Current capacity:** 12792/12792 (100%) of TNC freq>=50 tail; 14893 Thai words / 28239 dict entries.

**Limit:** Tail words below freq 50 number tens of thousands more (TNC has ~106k unique tokens per RESUME.md line 142). Most are proper nouns, technical terms, or hapax legomena.

**Scaling path:**
- Add freq<50 sampling tier (will be noisy; many entries will be tokenizer artifacts, not real words).
- Add user-feedback loop where OOV words seen in dogfood get added to the next dict (manual review pipeline).
- Phase 1.5 LLM plugin is the explicit answer for OOV (PHASE1-PROMPT.md line 96-99: dict-only is enough surface to test the wedge cleanly without LLM tone disambiguation).

## Dependencies at Risk

### Squirrel (macOS host) - GPLv3, not bundled

**Risk:** Squirrel ships under GPLv3. Smoodle distributes only schema + a dylib; user obtains Squirrel via `brew install --cask squirrel-app`. License compatibility hinges on this separation. If smoodle ever bundles Squirrel into the DMG, GPLv3 contagion forces smoodle's MIT license to GPLv3.

**Files:** `README.md` lines 109-113 (license note); `scripts/build-macos-dmg.sh` (does NOT bundle Squirrel).

**Impact:** breaking the bundle boundary breaks the license model.

**Migration plan:** if Squirrel becomes user-hostile (e.g., adds telemetry or breaks compatibility), Phase 2 plan (per README line 98) is "Native IME shells per OS, license-clean rewrite of the engine in Rust or C++". License separation already accounted for.

### Weasel (Windows host) - GPLv3, not bundled

**Same shape as Squirrel.** `winget install Rime.Weasel` keeps license separation.

### librime - BSD-3, vendored

**Risk:** smoodle's fork at `smoodle-type/librime` carries a single patch on top of upstream `rime/librime` 1.16.0. Each upstream release requires fork rebase.

**Files:** `vendor/librime/`, fork tag `1.16.0-smoodle.1`.

**Impact:** if upstream ships 1.17.0 with breaking changes (e.g., to `DictEntryIterator` API), the patch may not apply cleanly.

**Migration plan:**
- TODOS.md #1 (upstream PR) is the long-term escape hatch; if merged, fork retires.
- Until then, fork is pinned to 1.16.0 indefinitely. Squirrel pins librime 1.16.0 per RESUME.md line 94, so this is stable.

### `tnc_freq.txt` (PyThaiNLP TNC unigram) - CC0

**Risk:** `scripts/tnc_freq.txt` is 1.6 MB committed; sourced from PyThaiNLP's CC0-licensed corpus. If PyThaiNLP changes the format or the file moves, the regen path in RESUME.md line 290-292 (`curl ...pythainlp.../tnc_freq.txt`) breaks.

**Files:** `scripts/tnc_freq.txt`.

**Impact:** dict regeneration blocked.

**Migration plan:** committed file insulates against repo-side breakage. Only matters if a future TNC version is desired.

### Anthropic API access via relay

**Risk:** Per RESUME.md line 174-178, dict generation goes through `crs.0dl.me/api` relay. Relay URL or auth token can rotate.

**Files:** `.env` (gitignored), `scripts/generate_dict.py`, `scripts/generate_words.py`.

**Impact:** if relay disappears, regeneration requires direct Anthropic API access (paid, no relay-side caching).

**Migration plan:** all generated TSVs (`generated-tnc.tsv`, `generated-tnc-full.tsv`, `generated-500.tsv`) are committed, so regeneration is offline-replayable. Direct Anthropic API is the documented fallback.

## Missing Critical Features

### No telemetry client

**Problem:** `docs/PHASE1-PROMPT.md` line 100-103 (decision D2): "self-hosted umami or openpanel on user's existing infra. Opt-in, default OFF, no PII, install_id_hash only."

**Blocks:** quantitative dogfood signal. Decision Gate metrics ("≥1 active user", etc.) currently rely on user self-report.

**Status:** test stub exists (`tests/test_installers.py:577 test_telemetry_opt_in_default_off`, `@unittest.skip`). No client implementation. No POST endpoint configured.

**Priority:** Phase 1 milestone per design doc; not blocking dogfood.

### No CI workflow for macOS or Windows installer E2E

**Problem:** Per `docs/PHASE1-PROMPT.md` line 149-152: Lane E should land `ci.yml`, `release.yml`, `test_install_e2e_mac.sh`, `test_install_e2e_win.ps1`. Only `install-linux-e2e.yml` exists.

**Blocks:** automated detection of installer regressions across versions.

**Status:** linux E2E green per TODOS.md #8 (run 25480673681). macOS + Windows have shape tests only.

**Priority:** Medium - Lane E is explicit Phase 1 scope.

### No release automation

**Problem:** Per `docs/PHASE1-PROMPT.md` line 149: `release.yml` workflow planned but absent. Manual gh release upload per `scripts/build-macos-dmg.sh` line 153.

**Blocks:** Cuts publishing cadence. Unsigned DMG must be uploaded manually each release.

**Status:** local build script (`build-macos-dmg.sh`) works; no CI automation.

### Schema lint test (D5)

**Problem:** `docs/PHASE1-PROMPT.md` line 109 mandates schema lint in CI; `tests/test_schema_lint.py` listed in PHASE1-PROMPT line 148 but not present.

**Blocks:** Catches schema YAML errors only post-deploy via Console.app log.

### Universal macOS dylib

**Problem:** Per TODOS.md #3 step 7: "Universal binary (arm64 + x86_64) deferred to pre-public-ship gate per design doc - Phase 1 dogfood is arm64-only on the user's Apple Silicon machine."

**Blocks:** Intel-Mac users.

**Status:** explicit deferral; surfaces if any non-Apple-Silicon dogfood user appears.

### Code signing / notarization for macOS

**Problem:** Per `docs/PHASE1-PROMPT.md` line 195-198: "NOT in scope: code-signing certificates, Apple notarization." DMG ships unsigned.

**Blocks:** Gatekeeper warning on first install. Users must right-click -> Open per `README.txt` in DMG.

**Status:** explicit deferral to "pre-public-ship gate". Phase 1 wedge accepts the friction.

### Windows MSI / signed installer

**Problem:** Per `docs/LANE-B-WINDOWS.md` lines 73-87: "Recommendation: Zip + scripts for Phase 1. MSI lands alongside code-signing cert procurement at the pre-public-ship gate."

**Blocks:** SmartScreen warning on .ps1 download.

**Status:** explicit deferral; same shape as macOS notarization.

## Test Coverage Gaps

### Auto-deploy kill+restart against real Squirrel

**What's not tested:** the kill-Squirrel + open-Squirrel flow at `scripts/install.sh` lines 95-109.

**Files:** `tests/test_installers.py:582 test_auto_deploy_kill_restart_against_real_squirrel` (`@unittest.skip("E2E only")`).

**Risk:** osascript permission failure, Squirrel not coming back up, race conditions on the 1-second sleep (line 98) - none caught by sandboxed tests.

**Priority:** Medium - covered manually during dogfood.

### librime fork install end-to-end

**What's not tested:** full clone + build + dylib swap flow.

**Files:** `tests/test_installers.py:588 test_install_librime_fork_end_to_end` (`@unittest.skip("E2E only: needs sudo + ~5-15min make + real Squirrel.app")`).

**Risk:** brew dep regressions (e.g., the v0.0.5-era glog v2 -> v3 bump that broke `rime_api_console`), make-target rename in upstream librime, dyld load failures.

**Priority:** Medium - manual dogfood + macos-14 GHA runner planned for Lane E.

### Telemetry payload shape

**What's not tested:** `tests/test_installers.py:577 test_telemetry_opt_in_default_off`.

**Risk:** N/A (no client exists yet; test will land alongside implementation).

### Schema YAML lint

**What's not tested:** `schema/thai_phonetic.schema.yaml`, `schema/thai_phonetic.dict.yaml`, `schema/default.custom.yaml`.

**Risk:** typos, malformed weights (negative, non-int), broken algebra rules (regex syntax errors), invalid `import_preset` references.

**Priority:** Medium - schema YAML is the main user-facing artifact; bugs degrade to "smoodle Thai phonetic doesn't appear in switcher".

### Windows installer E2E (real desktop)

**What's not tested:** `tests/test_install_e2e_win.ps1` per `PHASE1-PROMPT.md` line 151 - not in repo.

**Risk:** Win 11 vs Win 10 divergence, Weasel version drift, winget behavior changes.

**Priority:** Medium - manual smoke green per TODOS.md #7, but manual ≠ regression-protected.

### macOS DMG installer E2E

**What's not tested:** `tests/test_install_e2e_mac.sh` per `PHASE1-PROMPT.md` line 151 - not in repo.

**Risk:** DMG mounting, .command file permission, schema bundling correctness, post-install verification.

**Priority:** Medium.

### fcitx5 path on Linux

**What's not tested:** Linux installer's fcitx5 branch. The CI workflow `.github/workflows/install-linux-e2e.yml` line 35-36 explicitly notes: "fcitx5 path (~/.local/share/fcitx5/rime/) is not tested here; it would require the fcitx5-rime apt package + a different dest dir."

**Risk:** fcitx5 detection or schema dir typo lands undetected.

**Priority:** Low - fcitx5 is the smaller share of the smaller wedge.

### macOS Sparkle auto-update detection

**What's not tested:** Squirrel auto-update overwriting the patched dylib.

**Risk:** silent ranking degradation. No automated re-swap.

**Priority:** Medium - documented in install scripts but only on next manual install run.

## Open Roadmap Items (from TODOS.md / PHASE1-PROMPT.md / RESUME.md)

### TODOS.md OPEN items

**TODO 1 - Upstream librime PR for `DictEntryIterator::Peek` first-call sort:**
- Status: DEFERRED 2026-05-06. Fork absorbs the patch indefinitely.
- Triggers to un-defer: (a) fork maintenance burden during Phase 1.5/2, (b) another schema author hits the bug, (c) quiet weekend.
- Priority: Low.

**TODO 2 - iOS external-keyboard interception spike:**
- Status: OPEN 2026-05-05.
- Goal: test whether third-party iOS IMEs can intercept input from external Bluetooth keyboards.
- Blocks: Phase 2 iOS scoping decision.
- Priority: Low (Phase 2 scoping question, not Phase 1).

### Closed since TODOS captured (verify no regressions)

- TODO 3: LoneExile/librime fork (CLOSED) - now `smoodle-type/librime` per the org migration. Verify all references updated (see "LoneExile/* references" debt above).
- TODO 4: Rebuild vendor/librime against current homebrew deps (CLOSED via `brew install glog`).
- TODO 5: Refactor smoodle-build.yml to workflow_call (CLOSED 2026-05-06).
- TODO 6: dockur/windows on th-dc test bed (CLOSED 2026-05-06).
- TODO 7: Lane B installer scripts (CLOSED 2026-05-07; hardening discoveries documented).
- TODO 8: Lane C installer + GHA E2E (CLOSED 2026-05-07).

### From PHASE1-PROMPT.md (decisions and lanes still in motion)

- D2 Telemetry: not yet implemented. Self-hosted umami/openpanel client needed.
- Lane E (CI + E2E): only Linux E2E green; macOS + Windows installer E2E missing.
- Distribution: GitHub Releases asset for `librime-1.16.0-smoodle.1-macOS-universal.dylib` may not yet exist (per TODOS.md #3 step 5 note: "Promotion to GitHub Releases ... stays a manual step until per-OS distribution models settle").

### From RESUME.md (deck of likely-next items)

1. Deploy v0.0.6 in Squirrel + dogfood probe (in-progress; deploy not yet clicked).
2. Triage dogfood feedback (gated on #1).
3. File upstream librime PR (deferred per TODOS.md #1).
4. v0.2 LLM translator plugin sub-task 1 (Phase 1.5 not started).
5. Ship publicly (gated on universal dylib + signing).
6. Verify `kao` ranking (`เขา` vs `ข้าว`) decision after dogfood.

### Open questions still on deck (RESUME.md)

- Verify `librime-predict.dylib`'s actual async behavior (Phase 1.5 scoping).
- v0.2 plugin must handle stale-result drop AND cooperative cancellation via `ggml_abort_callback`.
- macOS Gatekeeper acceptance test on a clean machine before announcing.
- Ship strategy when end users don't have the librime patch (resolved on macOS+Windows via fork; Linux accepts the limitation).

---

*Concerns audit: 2026-05-08*
