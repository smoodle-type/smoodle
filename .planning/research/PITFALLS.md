# Domain Pitfalls — smoodle Phase 1 Finish

**Domain:** Indie cross-platform desktop IME (Rime/librime-based) finishing Phase 1 dogfood — solo dev, 3 OS, opt-in telemetry, dylib-swap distribution, GH Releases.
**Researched:** 2026-05-08
**Scope filter:** Pitfalls that bite smoodle specifically, given v0.0.6 schema + smoodle-type/librime fork already shipping. Generic OSS hygiene advice excluded.

**Convention:**
- **Phase tag** = which Phase 1 finish lane should own the prevention. `Lane-D` = test infra, `Lane-E` = CI+E2E, `Lane-T` = telemetry (D2), `Lane-R` = README/docs hardening, `Lane-S` = Sparkle/release hardening, `Lane-G` = Decision Gate close.
- **Phase 1 verdict:** "must fix" = blocks Decision Gate close or causes silent degradation in dogfood; "1.5+ deferral OK" = annoyance, not gate-breaking.

---

## Critical Pitfalls

> Mistakes that cause silent UX degradation, supply-chain compromise, license damage, or invalid Decision Gate signal. **Phase 1 must fix.**

### CP-1: Sparkle re-swap loop — Squirrel auto-update silently reverts patched dylib

**What goes wrong:** Squirrel ships Sparkle. Sparkle replaces `Squirrel.app/Contents/Frameworks/librime.1.dylib` on host update. Smoodle's peek-sort patch reverts; ranking degrades silently; user sees "smoodle stopped working" with no error. `CONCERNS.md` Known Bugs section already documents this; the smoodle-type/librime fork carries the patch but cannot defend the swapped-in dylib from being overwritten.

**Why it happens:**
- Sparkle is part of Squirrel's normal update cycle (Sparkle 2.x extracts/installs via launchd agent + XPC; the install pass overwrites bundle contents wholesale, including `Frameworks/librime.1.dylib`).
- The smoodle install model **trusts** the host's `Frameworks/` directory as a writable swap target, but also assumes nothing else will write there.
- Squirrel's release cadence is slow but unpredictable; the swap can stay valid for months, then silently break.

**Compounding loop scenarios specific to smoodle:**
1. **Re-swap LaunchAgent fights Sparkle:** if Lane-S adds a LaunchAgent that auto-detects hash drift and re-swaps, and Sparkle is mid-install, file-lock contention can corrupt the dylib (Squirrel's `Frameworks/librime.1.dylib` is written via Sparkle's installer XPC service; concurrent `cp` from a LaunchAgent triggered by `fseventsd` is racy).
2. **Infinite re-swap loop:** if the LaunchAgent re-swaps on hash drift, and the next Squirrel launch re-applies its own Sparkle update (e.g., partial-update retry), the dylib oscillates between patched and stock until the user manually intervenes.
3. **SIP/library validation false positive:** macOS does not require library validation for non-hardened-runtime apps (Squirrel pre-1.1.x is not hardened-runtime), but if Squirrel ever enables hardened runtime + library validation, the unsigned smoodle-built dylib will be rejected by `dyld` at launch — Squirrel won't start at all, not just degrade.

**Warning signs:**
- User reports "smoodle stopped ranking words correctly" with no recent install action on their part. Cross-check `shasum -a 256 /Library/Input\ Methods/Squirrel.app/Contents/Frameworks/librime.1.dylib` against the published `librime-1.16.0-smoodle.1-macOS-universal.dylib` SHA.
- `Squirrel.app/Contents/Info.plist` `CFBundleShortVersionString` changed since last `install-librime-fork.sh` run.
- File presence of `librime.1.dylib.smoodle-backup` but live `librime.1.dylib` matches upstream rime/librime release SHA, not fork SHA.

**Prevention strategy:**
1. **Phase 1 (Lane-S, must fix):** Hash-drift detection helper, NOT a re-swap LaunchAgent. Run on installer launch + as a schema test step:
   ```bash
   # scripts/check-librime-patch.sh
   EXPECTED_SHA=$(cat vendor/macos/librime-1.16.0-smoodle.1.dylib.sha256)
   ACTUAL_SHA=$(shasum -a 256 /Library/Input\ Methods/Squirrel.app/Contents/Frameworks/librime.1.dylib | awk '{print $1}')
   if [ "$EXPECTED_SHA" != "$ACTUAL_SHA" ]; then
     echo "WARN: librime.1.dylib drift detected. Sparkle may have overwritten the smoodle patch."
     echo "Re-run: bash scripts/install-librime-fork.sh"
     exit 2
   fi
   ```
   Document as a manual probe in README troubleshooting. **Do NOT auto-re-swap** — manual is safer for a dogfood circle of <5 people.
2. **Phase 1 (Lane-T):** When telemetry client lands, ship a single ping field `librime_sha_match: bool` (no full SHA, no host info) so the founder can detect cohort-wide drift after a Squirrel update wave.
3. **Phase 1.5+ deferral OK:** A LaunchAgent + `fcntl` advisory lock + Sparkle-aware "wait for `Squirrel.app/Contents/_CodeSignature/CodeResources` mtime to settle" handshake. This is the right long-term answer but is too much complexity for a 5-person dogfood circle. Defer until a non-founder hits the loop.

**Why a LaunchAgent NOW is wrong:** smoodle currently has zero users actively reporting Sparkle-induced regressions. Adding a LaunchAgent that runs as the user, watches a system path, and re-runs a sudo install introduces (a) a sudo prompt loop on every Squirrel update, (b) a race window with Sparkle's own installer, (c) a permission dialog on the LaunchAgent itself. Each of those is more friction than "tell the user to re-run install-librime-fork.sh."

**Phase mapping:** Lane-S (Sparkle/release hardening) — landing the hash-drift probe. Lane-T (telemetry) ships the cohort-detection ping in the same milestone.

---

### CP-2: Tag rewrite supply-chain inversion — `gh release edit` silently changes asset SHA

**What goes wrong:** smoodle's macOS install path curls `https://github.com/smoodle-type/librime/releases/download/1.16.0-smoodle.1/librime-1.16.0-smoodle.1-macOS-universal.dylib`. The check is `file ... | grep "Mach-O"` (any Mach-O passes). If the founder (or a future contributor) re-runs the release pipeline and edits the existing tag's asset — `gh release upload --clobber` or deleting+re-uploading — every fresh install gets a new dylib silently. Combined with the Phase 1 lack of SHA verification (`CONCERNS.md` "Unsigned dylib download from GitHub Releases"), this is **the exact pattern** exploited in the tj-actions/changed-files March 2025 incident: mutable tags + downstream consumers trusting the tag.

**Why it happens specifically to smoodle:**
- Solo dev pipeline; no CI signature check, no second reviewer.
- `TODOS.md` #3 step 5: "Promotion to GitHub Releases (gated on `github.repository ==`) stays a manual step until per-OS distribution models settle." Manual promotion = one founder, one `gh release upload --clobber`, no audit log.
- The fork has CI artifacts (run 25429514636) but no SLSA attestations, no Cosign signatures. The artifact-to-Release promotion step has no integrity binding.
- `infra/lane-b-windows/docker-compose.yml` is on `th-dc` with public RDP on `smoodle/smoodle` credentials — supply-chain inversion vector if any dogfood install ever pulls from that VM (currently doesn't, but the boundary isn't enforced in code).

**Warning signs:**
- A user reports "I re-ran install today and the librime hash changed but version label stayed `1.16.0-smoodle.1`."
- `gh api repos/smoodle-type/librime/releases/tags/1.16.0-smoodle.1` shows asset `updated_at` newer than `created_at`.
- CI artifact for tag `1.16.0-smoodle.1` (run 25429514636) and live release-asset SHAs disagree.

**Prevention strategy:**
1. **Phase 1 (Lane-S, must fix):** Embed expected SHA256 in `scripts/install-librime-fork.sh` as a script constant. Verify pre-swap. Reject on mismatch with explicit message ("if you trust this is intentional, re-export `SMOODLE_LIBRIME_SHA256_OVERRIDE=...` and re-run").
   ```bash
   EXPECTED_SHA="<sha256-from-CI-artifact>"  # update each fork tag bump
   DOWNLOADED_SHA=$(shasum -a 256 "$_LOCAL_DYLIB" | awk '{print $1}')
   [ "$DOWNLOADED_SHA" = "$EXPECTED_SHA" ] || { echo "ERROR: SHA mismatch (got $DOWNLOADED_SHA, expected $EXPECTED_SHA)"; exit 1; }
   ```
   Same pattern in `scripts/install-librime-fork.ps1` for `rime.dll`.
2. **Phase 1 (Lane-S):** `vendor/macos/librime.1.dylib.sha256` and `vendor/windows/rime.dll.sha256` committed alongside vendored binaries (mirroring how `vendor/windows/rime.dll` is already committed). Single source of truth: tests assert script constant matches the `.sha256` file.
3. **Phase 1 (Lane-S):** Release process docs add a "tag is immutable" rule. If a re-release is needed, bump to `1.16.0-smoodle.2`, never overwrite `1.16.0-smoodle.1`. Codify with a CI guard: a workflow that fails if `gh release view <tag> --json assets --jq '.assets[].updated_at'` differs from `created_at`.
4. **Phase 1.5+ deferral OK:** SLSA provenance attestations via `actions/attest-build-provenance`. Cosign signatures. SBOMs. These are real but disproportionate for a 5-user dogfood. The vendored binary + committed SHA + tag-immutability rule covers ~95% of the risk for the dogfood circle.

**Phase mapping:** Lane-S — release hardening. **Critical to land before any non-founder install** because trust shifts from "I built this myself" to "I trust the tag URL."

---

### CP-3: Telemetry deanonymization via install_id collision + log retention

**What goes wrong:** D2 says "install_id_hash only, no PII." Naive implementations of `install_id` create deanonymization vectors that survive even with no explicit PII field:

1. **install_id collision risk:** if `install_id = sha256(<short-host-id>)` with insufficient entropy (e.g., MAC address, hostname truncated), two friends on the same diaspora-Thai network could collide; if `install_id = sha256(uuidgen)` written to `~/Library/Application Support/Smoodle/install_id`, the file persists across reinstalls and lets you correlate "user X uninstalled then reinstalled" sessions. Both undermine "anonymous."
2. **Accidental hostname/username transmission:** Bash scripts inadvertently reveal `$USER`, `$HOSTNAME`, `whoami`, `hostname` in default `curl -v` debug logs, error messages routed to stderr that get included in payloads ("error: cp /Users/alice/Library/Rime/... : permission denied"), or in `User-Agent` strings. Any of these is hostile in a wedge of <10 close-knit diaspora-Thai friends — knowing "ping came from a Mac with hostname Mali-MBP" trivially identifies the user.
3. **Missing TLS pinning / cert validation gaps:** the self-hosted umami/openpanel endpoint runs on user's existing infra. If it's behind Cloudflare with default settings, MITM at the CF layer is possible; if cert renewal lapses, `curl --insecure` workarounds documented anywhere = permanent regression.
4. **Opt-in dark pattern:** D2 says "default OFF" but if the install script asks `Send anonymous usage data? [Y/n]` (capital Y default) that is a dark pattern under GDPR Article 4(11) — pre-checked or default-yes is not consent. EU-resident diaspora-Thai friend hits this and the wedge expansion has a regulatory risk.
5. **Log aggregation enables de-anon at small N:** with 3-5 active users, even fully-anonymous payload `{install_id, os, librime_sha_match, schema_version}` can be re-identified if the founder cross-references ping timestamps with "Mali said she ran install at 3pm yesterday" — small-N kills anonymity.
6. **PIPEDA gotcha (Canadian diaspora):** install_id without explicit purpose disclosure violates PIPEDA principle 4 (limiting collection). "Just collect everything in case it's useful" is a PIPEDA failure even when each field individually is fine.
7. **GDPR retention:** EU residents have a right to erasure; if the umami DB has no retention policy and no `DELETE` endpoint, you cannot honor a "delete my data" request from a friend who knows their install_id.

**Warning signs:**
- `curl -v` traces in install logs include `> User-Agent: curl/8.x ...` or `> X-Forwarded-For: <ip>`.
- Telemetry payload includes any field derived from `whoami`, `hostname`, `id -un`, `$HOME`, `uname -n`.
- Install prompt phrasing implies "Y" is the recommended/default answer.
- No data-purge mechanism documented.
- Dogfood circle ≤5 people and you can recognize who pinged when from timestamp alone.

**Prevention strategy:**
1. **Phase 1 (Lane-T, must fix) — install_id as ephemeral, not persistent:**
   - Generate `install_id = sha256(/dev/urandom 16 bytes)` once at install time, store at `~/.config/smoodle/install_id` (XDG path on all 3 OS), and provide `smoodle telemetry reset` command that regenerates. Document this as "rotate any time."
   - **NOT** sha256(MAC) or sha256(hostname). Pure entropy only.
2. **Phase 1 (Lane-T) — strict allowlist payload schema:**
   ```jsonc
   {
     "install_id": "<32-hex>",         // ephemeral random
     "os": "macos|windows|linux",      // string literal, not uname -a
     "os_major": 14,                   // integer, not full version string
     "smoodle_version": "0.0.6",       // schema version
     "librime_sha_match": true,        // bool, no SHA values
     "event": "install_complete|deploy_success|deploy_timeout",
     "ts": 1714000000                  // unix epoch, no timezone
   }
   ```
   No optional fields. No `extra: {...}` map. Tests in `tests/test_telemetry.py` assert payload keys are a subset of the allowlist; reject anything else.
3. **Phase 1 (Lane-T) — opt-in UX, hostile-default:**
   - Default answer is `n`, not `Y`: `Send anonymous usage ping (helps me know if v0.0.6 deploys correctly)? [y/N]`.
   - Lowercase default letter outside brackets, capital `N` outside brackets — the defaulting convention.
   - Print exactly what gets sent before asking: `Telemetry payload preview: {os: macos, os_major: 14, ...}`. Show a specific URL: `Sends to: https://smoodle.example.com/api/event`.
   - Store consent at `~/.config/smoodle/telemetry_opted_in` (presence = consent, absent = no). Re-prompt on major version bump (forces re-consent).
4. **Phase 1 (Lane-T) — TLS minimums:**
   - Enforce `curl --tls-min 1.2 --proto =https` (no http fallback).
   - Document in code comment: "TLS pinning deferred — out of scope for self-hosted endpoint with Let's Encrypt rotation. Reconsider if endpoint moves behind Cloudflare."
5. **Phase 1 (Lane-T) — small-N de-anon mitigation:**
   - Server-side: round timestamps to nearest hour (15-min for high-frequency events) before storing.
   - Server-side: drop source IP at ingest (umami can do this; verify config).
   - Document: "if dogfood circle ≤10, treat all telemetry as effectively pseudonymous, not anonymous."
6. **Phase 1 (Lane-T, must fix for EU/CA friend) — purge endpoint:**
   - `smoodle telemetry forget` CLI sends `DELETE /api/install/<install_id>` with the locally stored ID; on success, deletes the local consent file. Server enforces "delete all rows where install_id = ?". Documented in README troubleshooting.
   - Retention policy: 90 days max. After 90d, server runs `DELETE FROM events WHERE ts < NOW() - 90d`. Document in README + privacy section.
7. **Phase 1.5+ deferral OK:** Differential privacy noise injection. K-anonymity guarantees. Formal DPIA. These are over-engineering for a self-reported 5-user wedge with explicit opt-in and a purge command.

**Network failure handling:**
- Telemetry POST timeout = 3s, single attempt, no retry, no queueing. Failure is a silent log line, never a user-visible error. **Critical:** never let telemetry block install completion. Tests assert install succeeds with telemetry endpoint unreachable / DNS-blackholed.

**Phase mapping:** Lane-T (telemetry milestone). **Must land before any non-founder install** if D2 telemetry ships in Phase 1; if telemetry slips to Phase 1.5, this entire pitfall reduces to "test stub `test_telemetry_opt_in_default_off` ensures opt-in default-off shape is preserved when implementation lands."

---

### CP-4: GHA non-interactive runner + IME registration mismatch

**What goes wrong:** macOS IME registration (TIS/TextInputSources) and Windows TSF registration both have implicit dependencies on a logged-in interactive desktop session. `pgrep`-based detection in `install-linux.sh` (CFM #2 mitigation) works on Linux because ibus/fcitx5 have a launching daemon. On macOS, `osascript -e 'tell application id "im.rime.inputmethod.Squirrel" to quit'` requires both Accessibility permission AND an active loginwindow session. **GHA macOS runners run as a launchd daemon without a user session by default.** Most current macOS GHA install logs that "look green" are testing the file-copy step but skipping the kill+restart step; the test is passing for the wrong reason.

**Why this is sneaky for smoodle:**
- `tests/test_install_e2e_mac.sh` (Lane-E open work) is most likely to be a checkmark-in-CI without testing what dogfood users actually hit on first install.
- Runners are reset per-job on github-hosted runners (`macos-15`), but they keep keychain/pasteboard state from launchd-as-system, not user. Anything that reads from `~/Library/Preferences/com.apple.HIToolbox.plist` for input source enumeration will see an empty list.
- CFM #2 mitigation (pgrep on `Squirrel`) will return non-zero on a CI runner because Squirrel was never launched, never auto-started. The installer's "kill+restart Squirrel" path will silently no-op and the test will not catch this — even though on a user's machine, `Squirrel` is likely already running before install.
- Windows GHA runner is the inverse: IT does have an interactive desktop session (windows-latest is an autologon-as-runneradmin desktop), but cached Weasel state from a previous build can pollute `%APPDATA%\Rime\` and make installer idempotency tests pass for the wrong reason.

**Specific failure modes:**
1. **macOS test green, real install red:** osascript permission dialog never fires in CI (no GUI session), so `install.sh` "passes" the kill+restart step instantly, but on a user's first run the dialog blocks for 30s and times out. Documented as a real friction in `CONCERNS.md` "Auto-deploy via osascript is fragile."
2. **macOS test red, real install green:** Squirrel.app isn't installed on `macos-15` runners, so `install.sh` will refuse to deploy. Lane-E E2E needs to install Squirrel FROM `brew install --cask squirrel-app` first, which itself requires Homebrew to be in the runner image (it is) AND no Gatekeeper dialog (cask install is `--no-quarantine`-eligible, but defaults vary by runner image version).
3. **Windows registry pollution:** `windows-latest` runners cache user-profile state across jobs in the same workflow run; `HKCU\Software\Rime\Weasel` settings written by a previous job leak into the next. Idempotency test of "second run produces same state as first" passes because BOTH runs see the polluted state.
4. **AppArmor / Gatekeeper dialogs hang the runner:** macOS Gatekeeper first-launch quarantine dialog on the unsigned DMG would block forever in a non-interactive session if the test mounts and opens the DMG. Documentation says `xattr -dr com.apple.quarantine` strips MOTW; tests must do this explicitly or hang.
5. **CFM #2 resurfaces in CI:** On a runner with NEITHER fcitx5 NOR ibus running, `install-linux.sh`'s pgrep check exits non-zero. The test bed in `install-linux-e2e.yml` apt-installs ibus-rime which auto-starts ibus-daemon, but a future "install but don't auto-start" runner image change silently breaks the test without a real regression.

**Warning signs:**
- macOS install E2E passes in <30 seconds (real install averages 40-90s with Deploy click). Too-fast = some step was skipped.
- `tests/test_install_e2e_mac.sh` does not call `osascript -e 'tell application "System Events" to keystroke ...'` or otherwise simulate a user session.
- Windows install E2E passes idempotency on the first run with no `Remove-Item -Recurse %APPDATA%\Rime` cleanup step.
- CI logs show `osascript: cannot connect to window server` (canary for missing GUI session) but the test step exit code is 0.
- `pgrep` of expected daemon returns 0 in CI but the daemon was never `apt install`'d in the workflow.

**Prevention strategy:**
1. **Phase 1 (Lane-E, must fix) — explicit GUI prerequisite gate:**
   - macOS E2E starts with: `brew install --cask squirrel-app && open -a Squirrel || (echo "no GUI session, skipping E2E" && exit 78)` (78 = neutral skip).
   - Mark macOS E2E job with `if: github.event_name != 'pull_request'` or similar gate so PRs don't fail on the GUI-required test.
   - Document: "macOS E2E requires a self-hosted runner with logged-in user session for full coverage. github-hosted runners cover the file-system shape only."
2. **Phase 1 (Lane-E) — Windows clean-slate per job:**
   - Pre-step: `Remove-Item -Recurse -ErrorAction SilentlyContinue $env:APPDATA\Rime, "$env:LOCALAPPDATA\Rime"`
   - Pre-step: `reg delete HKCU\Software\Rime /f` (ignore exit code).
   - Post-test: snapshot the registry diff to an artifact for debugging.
3. **Phase 1 (Lane-E) — Gatekeeper neutralization:**
   - Explicit `xattr -dr com.apple.quarantine` after DMG mount in test_install_e2e_mac.sh.
   - Explicit `Unblock-File` in test_install_e2e_win.ps1 for any downloaded asset.
   - Document why each is there (test-only — production users see and must clear the dialog manually).
4. **Phase 1 (Lane-E) — assert daemon was actually started:**
   - Linux E2E: `systemctl --user is-active ibus || pgrep -x ibus-daemon`. Fail if not running BEFORE installer runs (= runner setup bug, not installer bug). This separates "installer broken" from "test setup broken."
   - macOS E2E: skip the kill+restart step assertion entirely on github-hosted runners; assert only file-copy + schema lint. Mark the kill+restart as `@unittest.skipUnless(os.environ.get("SMOODLE_GUI_SESSION") == "1", ...)`.
5. **Phase 1.5+ deferral OK:** Self-hosted macOS Mac mini runner with persistent user session for true E2E. Cost is low (founder has hardware) but maintenance is real. Defer until first dogfood-circle regression that github-hosted CI missed.

**CFM #2 in CI:** Add an explicit canary test: `tests/test_install_linux_no_im_running.sh` that runs `install-linux.sh` with NEITHER ibus nor fcitx5 running and asserts a clear error message, NOT silent success. This is the regression-protection for CFM #2's mitigation — without it, a future refactor could re-introduce CFM #2 silently.

**Phase mapping:** Lane-E (CI + E2E for macOS + Windows). **Must land before declaring Lane-E done** — otherwise Lane-E delivers false confidence.

---

### CP-5: Schema lint false-positive churn — custom validator drifts from boost::regex

**What goes wrong:** `tests/test_schema_lint.py` (D5, currently absent) needs to validate `thai_phonetic.{schema,dict}.yaml` algebra rules. The natural implementation is "use Python `re.compile` to verify each `derive/X/Y/` regex parses." Python's `re` module is **not** boost::regex (which librime uses). Differences:

1. **Boost::regex supports `\<` `\>` word boundaries; Python `re` does not.** False positive: lint rejects valid Rime regex.
2. **Boost::regex partial regex syntax for character class escapes differs (e.g., `[[:alpha:]]` POSIX classes, conditional patterns).** Python re accepts `[[:alpha:]]` as `[:alph]` literal (silently buggy), boost::regex treats it as POSIX. False negative AND false positive on different inputs.
3. **Boost::regex `\Q...\E` literal blocks are not in stdlib Python re.** False positive on legitimate Rime regex.
4. **Lookbehind length differences:** Python re requires fixed-width lookbehind; boost::regex is variable. Smoodle's algebra rules currently don't use these, but if a future v0.0.7 rule uses `(?<=...)`, Python lint rejects valid input.

**Specific to smoodle:** the v0.0.6 algebra rules in `schema/thai_phonetic.schema.yaml` lines 84-110 use straightforward `derive/<from>/<to>/` patterns (e.g., `derive/^kh/k/`, `derive/aa$/a/`). These all parse identically in Python re and boost::regex. **The pitfall is not today; it's the lint test growing teeth that reject future legitimate rules.**

**Compounding factor:** false-positive lint blocks a release. Solo dev → temptation to disable the lint test, which rots the test infra.

**Warning signs:**
- Lint test rejects an algebra rule that the engine fixture (`tests/v01_fixture.yaml`) accepts and produces correct output for.
- Lint test passes a rule that the engine fixture fails on with "regex compilation error."
- Lint test was disabled in CI ("flaky on 0.0.7 regen") — the canonical signal of false-positive churn.

**Prevention strategy:**
1. **Phase 1 (Lane-D, must fix) — lint scope = structure, not regex semantics:**
   - Validate YAML parses (PyYAML safe_load).
   - Validate top-level keys match a schema (use Yamale or a hand-rolled allowlist).
   - Validate `weight` fields are positive integers.
   - Validate `import_preset` references an existing preset name (whitelist: `default`, `symbols`, etc.).
   - Validate dict entry format: `<text>\t<code>\t<weight>` with exact tab separators, no leading/trailing whitespace.
   - Validate algebra rule shape: starts with `xform/`, `derive/`, `xlit/`, etc., has the right number of `/`-separated parts.
   - **Do NOT compile the regex body in Python.** Defer regex validity to engine-mode tests in `test_dict.py`.
2. **Phase 1 (Lane-D) — engine-mode is the regex oracle:**
   - Engine fixture run is the source of truth for "does this regex actually work in librime." If `tests/v01_fixture.yaml` runs green, all algebra rules are valid by construction.
   - Add `test_schema_engine_smoke` that runs `rime_api_console` with the dict, asserts no `regex compilation error` line in stderr. This catches new-rule mistakes without reimplementing boost::regex.
3. **Phase 1.5+ deferral OK:** Bind to actual `boost::regex` via a Python C extension, run rules through it. Or: write a Lua harness that runs inside librime's Lua sandbox to validate. Both are massive overengineering for a 14-rule algebra surface.

**Phase mapping:** Lane-D (test infrastructure). The schema lint test is in scope; the regex-validity test is explicitly NOT.

---

## Moderate Pitfalls

> Annoyances that degrade quality but don't gate Phase 1 close. **Phase 1 fix preferred; 1.5 deferral acceptable.**

### MP-1: README-tested-only-on-author's-machine — install instructions silently rot

**What goes wrong:** Solo-dev README install snippets are written, copy-pasted by author from terminal history, then never re-tested from a fresh machine state. Common failure modes:
- `bash scripts/install.sh` assumes `cd /path/to/smoodle` first; first-time clone user runs from `~/Downloads/smoodle-main/` and the script's relative paths break.
- README shows `brew install --cask squirrel-app` but doesn't mention the cask isn't auto-tapped; on a fresh Homebrew install, `--cask` was relocated to `homebrew/cask` in 2024.
- macOS Gatekeeper warning instructions are wrong because author has Gatekeeper relaxed (`spctl --master-disable` from years ago) — fresh user sees a different dialog.
- "Type sawadee → see สวัสดี candidate" assumes user knows how to switch to smoodle in the input switcher (Cmd-Space or Win+Space). Author has muscle memory; new user doesn't.
- `CONCERNS.md` already flags this: "no troubleshooting section for 'I ran install but Squirrel doesn't show smoodle'."

**Smoodle-specific:** `README.md` line 17 still references `LoneExile/librime`; line 21 says `APPROVED-PENDING-PHASE-0` (Phase 0 closed); line 86 ASCII repo layout is stale.

**Warning signs:**
- README install section was last edited >2 weeks ago.
- User asks a basic question on first install ("where do I put the YAML files?") that's answered in the README — implies README isn't being read OR is unclear.
- Founder has not run install.sh from a fresh `git clone` in >1 month.

**Prevention strategy:**
1. **Phase 1 (Lane-R, must fix):**
   - Run install.sh + install-windows.ps1 + install-linux.sh from a fresh `git clone` in a clean directory once per release, in a clean OS image (macOS in a fresh user account; Windows on the th-dc dockur VM with `windows-storage` volume reset; Linux on a fresh `ubuntu:22.04` Docker container).
   - Document the README-validation procedure in `docs/RELEASE-CHECKLIST.md` (new file). Include explicit steps for each OS.
2. **Phase 1 (Lane-R) — README structure:**
   - Status line points at single source: `STATUS: see [.planning/PROJECT.md](.planning/PROJECT.md)`.
   - Three install sections (macOS/Windows/Linux) with copy-paste-ready commands AND screenshots of expected dialogs.
   - Troubleshooting section ordered by frequency: (1) "I ran install but smoodle doesn't appear in the input switcher" → first-deploy click required; (2) "Squirrel quits on launch" → librime arch mismatch (Intel vs ARM); (3) "candidates don't appear" → Deploy didn't fire, restart Squirrel.
3. **Phase 1.5+ deferral OK:** Animated GIFs of the install flow. Video walkthroughs. Localized to Thai (founder is bilingual; not blocking).

**Phase mapping:** Lane-R (README hardening).

---

### MP-2: Decision Gate close — survivorship bias + "founder daily use" confounding wedge validation

**What goes wrong:** The Phase 0 close already narrowed the wedge to "founder + diaspora-Thai friends as they surface" with qualitative signals (≥1 unsolicited bug report, ≥1 named non-founder converts to "uses this daily"). Phase 1 close uses the same signal set. Two specific failure modes:

1. **Survivorship bias on signal collection:** Friends who hit a bug and bounce out without reporting are invisible. Founder will only count signal from friends who STAYED engaged enough to report — these are by definition the friends most predisposed to like smoodle. Conclusion ("looks promising, ≥2 active") rests on the engaged-friend cohort, missing the bounced-friend cohort.
2. **Confounding founder-daily-use with wedge validation:** "Founder uses smoodle daily on patched Squirrel" is **not** evidence of wedge value. It's evidence of sunk-cost and dogfooding discipline. If the Decision Gate close ledger says "founder uses this daily ✓ + 1 friend reports a bug ✓ → wedge validated," that's a false positive — a single non-founder bug report is too thin to declare validation.
3. **Absence-of-signal interpretation:** "I gave smoodle to 3 friends, 0 reported back, so I'll wait another month" is a reasonable read; "I gave smoodle to 3 friends, 0 reported back, so it must be working fine" is the dangerous read. The Decision Gate spec doesn't disambiguate.
4. **Small-N false positives:** with N=3 friends, each independent friend conversion has ~33% probability of being noise/coincidence. Two convert → "validated" is a 4-of-9 odds outcome under a null hypothesis where the wedge has no signal. This is small-N magic — easy to fool yourself.

**Warning signs:**
- Decision Gate close decision is being made unilaterally by founder with no second pair of eyes.
- "Daily use" criterion for a friend was self-reported to founder verbally, not measured (telemetry would help here, but Phase 1 telemetry may not be live).
- Founder has been using smoodle for >2 months and is the heaviest user; founder's testimony dominates the close memo.
- The close memo doesn't explicitly identify what would have caused a "stay-in-dogfood" verdict.

**Prevention strategy:**
1. **Phase 1 (Lane-G, must fix) — pre-register the decision criteria:**
   - BEFORE collecting signal (i.e., right now, in Phase 1 finish), write `docs/DECISION-GATE-CRITERIA.md` with explicit:
     - "Ship-publicly-ready" requires: ≥1 named non-founder uses smoodle daily for ≥7 consecutive days WITHOUT founder prompting, AND ≥1 unsolicited bug report from a non-founder, AND founder daily use ≥30 days.
     - "Stay-in-dogfood" triggered by: any non-founder who tried smoodle bounced (uninstalled, stopped using, or lost interest within 14 days), OR ≤1 unsolicited signal over 60 days of dogfood.
     - "Inconclusive" allowed: extend Phase 1.5 by 4 weeks if signal is mixed.
   - Lock this BEFORE Phase 1 close. Pre-registration kills survivorship bias because the criteria are fixed before outcomes are observed.
2. **Phase 1 (Lane-G) — explicit founder-use exclusion:**
   - Decision Gate ledger has separate columns for "founder signal" and "non-founder signal." Founder daily-use is a precondition (smoodle works) but does NOT count as wedge validation.
   - "Founder used smoodle daily for 60 days" → "smoodle is dogfood-stable" (not "wedge validated").
3. **Phase 1 (Lane-G) — explicit absence-of-signal protocol:**
   - 0 friends report after 30 days → "inconclusive — extend dogfood" (NOT "validated, ship").
   - 0 friends report after 60 days → "stay-in-dogfood, smaller wedge than expected."
   - Any friend who installs and STOPS using = explicit negative signal, capture the bounce reason.
4. **Phase 1 (Lane-G) — small-N humility caveat in close memo:**
   - Final memo includes: "Decision is based on N=<num> non-founder signals. With N≤5, this is a directional read, not a statistical one. Confidence: directional."
5. **Phase 1.5+ deferral OK:** Formal cohort tracking, retention analytics, NPS-style survey. Disproportionate for a 5-person wedge.

**Phase mapping:** Lane-G (Decision Gate close). Pre-registration of criteria must happen before any Phase 1 close work; the close itself can land at Phase 1 wrap.

---

### MP-3: Universal dylib silent failure on Intel Mac — MP-1 install instructions hide the architecture trap

**What goes wrong:** `CONCERNS.md` flags this directly: macOS installer is arm64-only. Intel Mac user runs `install-librime-fork.sh`, sees `Squirrel's librime.1.dylib is now 2500 KB` success message, Squirrel breaks on next launch with `dyld: bad CPU type in executable`. **The success message confirms the file copy, not the architecture compatibility.**

**Compounding factors:**
- `arm64`-only dylib is 2.5MB; bundled universal is 7.2MB. The install script's "size check" passes because it's checking presence, not arch.
- Intel Macs in the diaspora-Thai friend circle are common (Thai users tend to keep older hardware longer than US average; Apple's 2018-2019 Intel MacBook Pros are still in heavy use).
- Failure mode is "Squirrel quits silently with no UI" — user sees IME stop working with no diagnostic.

**Warning signs:**
- `uname -m` returns `x86_64` on installer host but installer doesn't gate on arch.
- `lipo -archs vendor/macos/librime.1.dylib` returns only `arm64`, not `arm64 x86_64`.
- Dogfood install on an Intel Mac succeeded on logs but Squirrel doesn't launch.

**Prevention strategy:**
1. **Phase 1 (Lane-S, must fix even before universal lands) — refuse install on arch mismatch:**
   ```bash
   # in install-librime-fork.sh, before swap
   HOST_ARCH=$(uname -m)
   DYLIB_ARCHS=$(lipo -archs "$_LOCAL_DYLIB" 2>/dev/null || file "$_LOCAL_DYLIB" | grep -oE 'x86_64|arm64' | tr '\n' ' ')
   case "$HOST_ARCH" in
     arm64) echo "$DYLIB_ARCHS" | grep -q arm64 || { echo "ERROR: dylib does not contain arm64 slice"; exit 1; } ;;
     x86_64) echo "$DYLIB_ARCHS" | grep -q x86_64 || { echo "ERROR: this is an arm64-only dylib; Intel Mac not supported until v0.0.7. See https://github.com/smoodle-type/smoodle/issues/<universal-tracking>"; exit 1; } ;;
   esac
   ```
2. **Phase 1 (Lane-S) — universal dylib as actual Phase 1 deliverable:**
   - `lipo -create` arm64 + x86_64 builds in CI.
   - Smoodle-build.yml already has macos-15 + macos-15-intel jobs; add a `lipo` step + `actions/upload-release-asset` for the universal artifact.
   - This closes both the silent-failure and the arch-detection gap in one stroke.
3. **Phase 1 (Lane-R) — README explicit Intel-Mac caveat until universal lands:**
   - "macOS Intel currently requires source build (5-15 min). Apple Silicon users: prebuilt arm64 dylib via install-librime-fork.sh."
   - Removed when universal lands.

**Phase mapping:** Lane-S (release hardening) for arch-detection refusal; universal-dylib build belongs to the same lane.

---

### MP-4: install-windows.ps1 PowerShell parser fragility — UTF-8 emoji/Thai re-introduces CFM-style breakage

**What goes wrong:** `TODOS.md` #7 discovery #2 already documents: PowerShell 5.1 reads .ps1 files as Windows-1252 by default; UTF-8 em-dashes (E2 80 94) parse as `0x94` = `"` in cp1252 and break string parsing. This was fixed once. **The pitfall is regression** — a future contributor adds Thai sample text or em-dash to a .ps1 file, CI doesn't catch it (test_installers.py does shape regex check, not pwsh parse), and the Windows installer silently breaks.

**Smoodle-specific:** the natural inclination on a Thai IME project is to put Thai characters in install messages ("Type sawadee → see สวัสดี"). Doing so in a .ps1 file is a CFM-class regression.

**Warning signs:**
- A .ps1 file contains any non-ASCII byte that isn't escaped via `[char]0xXXXX` or in a UTF-8-with-BOM-saved file.
- `git log -p scripts/install-windows.ps1 scripts/install-librime-fork.ps1` shows recent additions of Thai script or em-dashes.
- Windows install on the th-dc test bed fails with `Unrecognized token in source text`.

**Prevention strategy:**
1. **Phase 1 (Lane-D, must fix) — pwsh parse check on dev box + CI:**
   - Add to `tests/test_installers.py`: a test that runs `pwsh -NoProfile -Command "[scriptblock]::Create((Get-Content -Raw -Encoding UTF8 \$script))"` for each .ps1 file. Skip if pwsh not installed locally; require pwsh in Lane-E CI matrix.
   - `brew install --cask powershell` on the dev box is documented in CONTRIBUTING (in scope for Phase 1; tiny ask).
2. **Phase 1 (Lane-D) — ASCII-only assertion on .ps1:**
   - Test asserts `file --mime-encoding scripts/*.ps1` returns only `us-ascii` (or `utf-8` if BOM is present and confirmed).
   - This catches the em-dash/Thai-script class of regression in <1ms with no pwsh dependency.
3. **Phase 1 (Lane-D) — explicit doc:**
   - Comment block at the top of each .ps1: `# This file is parsed as Windows-1252 by PS 5.1. ASCII-only. Use [char]0x<hex> for Thai or em-dash.`

**Phase mapping:** Lane-D.

---

### MP-5: GHA multi-asset release upload partial state

**What goes wrong:** A release with multiple assets (universal dylib, Windows DLL, source tarball, schema YAMLs zip) uploaded via parallel GHA jobs can be mid-publish when a user runs install. `install-librime-fork.sh` resolves the URL and downloads — at the moment between "release tag created" and "all assets uploaded," the asset URL returns 404 even though the release exists.

**Smoodle-specific:** TODOS.md #3 step 5 manually promotes assets, but as Phase 1 finish lands `release.yml`, parallel job uploads become real. Combined with `gh release download --pattern '*.dylib'`, partial-state means user gets a stale-version dylib that matches the pattern from the previous release.

**Warning signs:**
- `gh release view <tag> --json assets` shows fewer assets than expected immediately after a release-publish event.
- User installs ~minutes after tag push and gets 404 on the dylib URL.

**Prevention strategy:**
1. **Phase 1 (Lane-S, must fix) — atomic release publish:**
   - `release.yml` workflow: create release as DRAFT first, upload all assets, then publish (`gh release edit <tag> --draft=false`).
   - `install-librime-fork.sh` accepts only published (non-draft) release assets via `gh api /repos/.../releases/tags/<tag> --jq '.draft'` check (must be `false`).
2. **Phase 1 (Lane-S) — install script handles partial state:**
   - On 404, surface explicit message: "Release <tag> exists but asset not yet published. If this just released, retry in 60 seconds."
   - Do NOT silently fall back to source build (current behavior masks the partial-state bug).

**Phase mapping:** Lane-S.

---

## Minor Pitfalls

> Catch them when convenient; not Phase 1 critical.

### mp-1: Documentation drift — multiple status sources

**What goes wrong:** `CONCERNS.md` already documents: README says `APPROVED-PENDING-PHASE-0`, PROJECT.md says `APPROVED`, RESUME.md describes v0.0.3. Multi-source-of-truth → users read whichever they hit first.

**Prevention:** Single canonical source (`PROJECT.md`); README links there for status. Lane-R already covers this.

**Phase mapping:** Lane-R.

---

### mp-2: Schema YAML duplicate-key silent override

**What goes wrong:** YAML duplicate-key behavior is implementation-defined; PyYAML silently keeps the LAST occurrence, libyaml (used by Rime via marisa) varies. A schema patch like `default.custom.yaml` could redefine a key already in `thai_phonetic.schema.yaml`, and the deploy can pick either depending on parse order.

**Smoodle-specific:** v0.0.6 schema has 14 algebra rules. A future regen that accidentally duplicates a `derive/` key would silently override.

**Prevention:** Schema lint asserts no duplicate keys at any nesting level. PyYAML's `RoundTripLoader` from ruamel can detect; or hand-rolled key-tracking.

**Phase mapping:** Lane-D.

---

### mp-3: `vendor/librime/` 2GB build dir gitignored vs documented

**What goes wrong:** `vendor/librime/` is 2GB+, gitignored, but `install-librime-fork.sh` line 34 references it as the build dir. First-time clone needs `git clone smoodle-type/librime vendor/librime/` — if the README install instructions don't say this, fresh user runs `install-librime-fork.sh` and gets `vendor/librime/Makefile not found`.

**Prevention:** Either document the clone step in README, OR have install-librime-fork.sh auto-clone if missing (currently exists per TODOS.md #3 step 7: "clones-or-uses-existing"). Verify the clone-or-use path is robust.

**Phase mapping:** Lane-R + Lane-D shape test asserting `install-librime-fork.sh` handles the no-vendor-dir case.

---

### mp-4: Windows `gh release download` requires gh CLI auth

**What goes wrong:** `install-librime-fork.ps1` falls back to `gh run download` (TODOS.md #7 discovery #3). `gh` CLI requires `gh auth login` for private artifacts; even for public releases, rate-limiting kicks in faster on unauthenticated requests. Fresh Windows user without `gh auth` setup hits rate limit, install fails opaquely.

**Prevention:** `install-librime-fork.ps1` uses `Invoke-WebRequest` against the public release asset URL (no `gh` dependency) as the primary path; `gh run download` only as last-resort fallback. Already partially addressed via `vendor/windows/rime.dll` committed to repo (BSD-3 license).

**Phase mapping:** Lane-D shape test asserts `Invoke-WebRequest` is the primary download path.

---

### mp-5: Schema timestamp issue regression on macOS

**What goes wrong:** `CONCERNS.md` Schema timestamp issue mitigation is Windows-only. macOS `install.sh` line 68 uses `cp` which preserves source mtime (technically `cp -p` would; bare `cp` resets to current time, but rsync would preserve). If a user uses rsync from a backup or Time Machine restore, stale mtimes silently skip recompile.

**Prevention:** PROJECT.md Active list already has this: "install.sh schema timestamp touch: mirror Windows' `LastWriteTime = now`." Add `touch ~/Library/Rime/thai_phonetic.*.yaml` after the cp loop.

**Phase mapping:** Lane-A leftover (already in PROJECT.md Active).

---

## Phase-Specific Warnings

| Phase 1 Lane | Most Likely Pitfall | Specific Mitigation |
|--------------|--------------------|---------------------|
| Lane-E (CI + E2E mac+win) | CP-4: false-confidence E2E that skips real install steps | Explicit GUI gate; runner-clean-slate pre-step; assert daemon running before installer runs |
| Lane-T (telemetry) | CP-3: install_id de-anon + opt-in dark pattern | Ephemeral random install_id; strict allowlist payload; default-N opt-in prompt; purge endpoint; 90d retention |
| Lane-S (Sparkle re-swap + release hardening) | CP-1 + CP-2 + MP-3 + MP-5: dylib drift + tag rewrite + arch mismatch + partial release | Hash-drift probe (no LaunchAgent); SHA256 pinning; tag-immutability rule; arch detection; draft-then-publish |
| Lane-D (test infra) | CP-5 + MP-4 + mp-2: lint scope creep + .ps1 charset + duplicate keys | Lint = structure not regex semantics; pwsh parse check; ASCII-only .ps1 assertion |
| Lane-R (README hardening) | MP-1: install instructions tested only on author's machine | Fresh-clone validation per release; release checklist doc |
| Lane-G (Decision Gate close) | MP-2: survivorship bias + founder confounding | Pre-register criteria; separate founder/non-founder columns; absence-of-signal protocol |

---

## What "Phase 1 Must Fix" vs "1.5+ Deferral OK"

**Phase 1 must fix (blocks Phase 1 close or causes silent dogfood degradation):**

- **CP-1** hash-drift detection probe (NOT auto-re-swap LaunchAgent — that's deferral)
- **CP-2** SHA pinning + tag-immutability rule
- **CP-3** ephemeral install_id + allowlist payload + opt-in default-N + purge endpoint (only if telemetry actually ships in Phase 1; if D2 slips to Phase 1.5, this slips with it)
- **CP-4** GUI-required-step gating + runner-clean-slate per job
- **CP-5** schema lint = structure-only scope
- **MP-3** arch-detection refusal in install-librime-fork.sh
- **MP-4** pwsh parse check + ASCII-only .ps1 assertion
- **MP-5** atomic draft-then-publish in release.yml

**Phase 1.5+ deferral OK (annoyance, not gate):**

- LaunchAgent + advisory-lock Sparkle handshake (CP-1 deferral)
- SLSA provenance attestations + Cosign signatures (CP-2 deferral)
- Differential privacy noise injection (CP-3 deferral)
- Self-hosted Mac mini runner with persistent user session (CP-4 deferral)
- Bound-to-boost::regex schema lint (CP-5 deferral)
- Animated GIF README (MP-1 deferral)
- Formal cohort tracking + retention analytics (MP-2 deferral)

---

## Sources

### Smoodle internal context (HIGH confidence)
- [`/Users/lex/Dev/my_repos/experiment/smoodle/.planning/PROJECT.md`](../PROJECT.md) — current scope of Phase 1 finish.
- [`/Users/lex/Dev/my_repos/experiment/smoodle/.planning/codebase/CONCERNS.md`](../codebase/CONCERNS.md) — comprehensive failure-mode audit; primary source for CP-1/CP-2/MP-3/mp-1/mp-5.
- [`/Users/lex/Dev/my_repos/experiment/smoodle/docs/PHASE1-PROMPT.md`](../../docs/PHASE1-PROMPT.md) — D1-D5 decisions, Critical Failure Modes #1/#2/#3.
- [`/Users/lex/Dev/my_repos/experiment/smoodle/TODOS.md`](../../TODOS.md) — Lane B + Lane C closure notes, hardening discoveries (especially #7 discoveries 1-5).

### Domain research (MEDIUM confidence — webSearch + cross-checked)
- [Sparkle CHANGELOG (2.x)](https://github.com/sparkle-project/Sparkle/blob/2.x/CHANGELOG) — XPC + launchd installation model relevant to CP-1.
- [tj-actions/changed-files March 2025 supply-chain incident discussion (cli/cli #8669)](https://github.com/cli/cli/issues/8669) — `gh release edit --target` cannot move tags; mutable-tag attack pattern relevant to CP-2.
- [GitHub community discussion 154525: actions runner workspace contamination](https://github.com/orgs/community/discussions/154525) — runner state leaking across jobs; basis for CP-4.
- [GitHub community discussion 116729: macOS runners + cached venv](https://github.com/orgs/community/discussions/116729) — macOS-specific runner state contamination.
- [SmartScreen reputation for Windows app developers — Microsoft Learn](https://learn.microsoft.com/en-us/windows/apps/package-and-deploy/smartscreen-reputation) — MOTW + reputation context for unsigned PS1 (informs MP-4 framing, though smoodle defers signed installer to pre-public-ship gate).
- [Dark Patterns after the GDPR (CHI 2020 paper, dl.acm.org/doi/10.1145/3313831.3376321)](https://dl.acm.org/doi/10.1145/3313831.3376321) — basis for opt-in default-N rule in CP-3.
- [TelemetryDeck Privacy FAQ](https://telemetrydeck.com/docs/guides/privacy-faq/) — install-id-as-ephemeral-not-persistent pattern in CP-3.
- [System Integrity Protection — Apple Support 102149](https://support.apple.com/en-us/102149) — SIP scope; smoodle's swap target `/Library/Input Methods/Squirrel.app/Contents/Frameworks/` is NOT SIP-protected (Apple-installed Squirrel is, but third-party Squirrel via brew cask is not), so swap works; informs CP-1 future-proofing.
- [Sparkle documentation: publishing an update](https://sparkle-project.org/documentation/publishing/) — Sparkle's bundle-replace semantics relevant to CP-1.
- [Configuring a GitHub Actions Runner on a Mac mini (Scaleway)](https://www.scaleway.com/en/docs/tutorials/install-github-actions-runner-mac/) — explicit "background daemon vs. user session" distinction relevant to CP-4.

### Domain research (LOW confidence — single source or training-data-only)
- Boost::regex vs Python `re` semantic differences (CP-5) — not directly searchable for smoodle's exact algebra rules; framing based on documented boost::regex POSIX support and Python `re` docs.
- Survivorship bias / small-N validation framing (MP-2) — drawn from general indie/startup customer-discovery literature; smoodle-specific application is opinion not measurement.

---

*Domain pitfalls audit: 2026-05-08. Curated for Phase 1 finish roadmap. Generic OSS/security advice excluded; only smoodle-specific surface.*
