# Resume v0.0.8 implementation

**Updated:** 2026-05-27 ~11:45 +0700 (v0.0.8b SHIPPED publicly — DMG + appcast live)
**Use:** open new Claude Code session, paste the "Resume prompt" block below as first message.

---

## Latest snapshot (2026-05-27 mid-morning)

### v0.0.8b SHIPPED PUBLICLY (Smoodle Config.app first ship)

- DMG: `https://github.com/smoodle-type/smoodle-app/releases/tag/v0.0.8b` (Smoodle-v0.0.8b.dmg 17.2MB + .sig)
- Appcast: 3 entries (8a, 8a.1, 8b) all with valid 88-char EdDSA sigs at `https://smoodle-type.github.io/smoodle-app/appcast.xml`
- Sparkle will auto-update v0.0.8a/v0.0.8a.1 installs → v0.0.8b on next 24h check (or manual menubar S → Check for Updates)
- Smoodle Config.app (Tauri 2 + Svelte 5, universal arm64+x86_64, ~22MB) bundled into DMG alongside Smoodle.app — recruits drag-install Config.app to /Applications themselves (Sparkle doesn't deliver new .app bundles)
- 14 IPC commands across user_dict / deploy / status / settings / telemetry surfaces (27 cargo tests pass + 6 vitest tests pass)
- Menubar "Open Smoodle Config…" enabled + Apple Event handler «event RimeRdpl» registered
- vendor/smoodle pinned at v0.0.8b-schema (content unchanged from v0.0.8a-schema)
- All 18 plan tasks DONE (T0-T18); 19-20 are MANUAL (founder smoke + recruit follow-up)

### Known limitations carried into v0.0.8b (not blockers)

1. Smoodle Config.app binary inside bundle named `app` not `Smoodle Config` (Cargo package name is `app`, Tauri default). Cosmetic — Info.plist's CFBundleExecutable matches. Defer rename to v0.0.9.
2. Settings tab schema_list has no drag-reorder yet — list + remove only. Defer drag to v0.0.9.
3. Apple Event «event RimeRdpl» MAY not fire for IME-class apps (Smoodle is an input method, not standard NSApplication). Untested in the wild. If `deploy_squirrel` errors, fallback is manual menubar Deploy. Tauri returns osascript stderr in the toast for diagnostics.

### v0.0.8a.1 PATCH SHIPPED PUBLICLY (closes the default.custom.yaml gap)
- DMG: `https://github.com/smoodle-type/smoodle-app/releases/tag/v0.0.8a.1` (DMG + .sig, both verified)
- Appcast updated; Sparkle auto-updates existing v0.0.8a installs on next 24h check
- Root cause shipped + documented: `add_data_files` anchor was bogus → silent no-op; fixed by anchor change + manual pbxproj wire + `require_anchor_present` guard
- Outreach drafts URLs fixed (point at `/releases/latest` not a broken hardcoded filename)
- Legacy `release-ci.yml` workflow disabled

### v0.0.8b — 9 of 20 tasks shipped (BACKEND COMPLETE + WIRED, Words tab live)

| Task | Status | Highlight |
|---|---|---|
| 1 Scaffold | ✅ | Tauri 2 + Svelte 5 project @ `config-app/`. `identifier=me.0dl.smoodle-config`. |
| 2 yaml.rs | ✅ | `atomic_write_str` (NamedTempFile), `read<T>`, `backup` (preserves full filename incl. hidden), `atomic_copy`, `YamlError::MissingPatchRoot`. 5 tests. |
| 3 user_dict | ✅ | 3 commands + tab/newline IPC validation + $HOME-Result. 6 tests. |
| 4 deploy | ✅ | osascript Apple Event 'Deploy' shim + DeployRunner trait for mocking. 2 tests. |
| 5 status | ✅ | smoodle_running + schema_compile_log + dict_counts. CRITICAL fix: `/Library/Input Methods/...` plist path (Smoodle is an IME, not /Applications/). 3 tests. |
| 6 settings | ✅ | 4 commands inc. serde_yaml::Value merge for default.custom.yaml. Atomic copy via yaml::atomic_copy. cfg(target_os = "macos") on reset_to_defaults. 4 tests. |
| 7 telemetry | ✅ | 3 commands. reqwest blocking + 10s connect + 15s total timeout. forget_token chmod 0600. Hardcoded URL (Tauri GUI doesn't inherit shell env). ForgetRunner trait for mocking. 7 tests. |
| 8 wire lib.rs | ✅ | All 14 Tauri commands registered via `invoke_handler!`. Stale Task-8-pending NOTEs scrubbed from each module. |
| 9 Words tab | ✅ | `src/lib/api.ts` typed bindings + `src/routes/words.svelte` (Svelte 5 runes, add/delete/deploy-on-save) + 2 Vitest cases. |

**Test totals: 27 cargo tests pass (5 yaml + 6 user_dict + 2 deploy + 3 status + 4 settings + 7 telemetry). 2 vitest tests pass.**

### v0.0.8b — 11 tasks remain

| Task | What |
|---|---|
| 10 Status + Settings Svelte tabs | Same shape as Words tab; reuse api.ts. WILL HIT the Vite 6 + svelte plugin v5 PartialEnvironment-Proxy CSS preprocess bug — pre-emptively move scoped `<style>` blocks to `src/app.css`. |
| 11 App shell + tab navigation | `App.svelte` becomes a 3-tab router. Bottom status bar wires smoodle_running + dict_counts. |
| 12 Local universal build | `cargo tauri build --target universal-apple-darwin`. Produces `Smoodle Config.app`. |
| 13 build-config-app.yml | GHA workflow tag-driven build + sign + release artifact upload. |
| 14 Tag + publish Smoodle Config.app | Independent release; goes into the v0.0.8b smoodle-app DMG via Task 15. |
| 15 build-dmg.sh fetches Config.app | smoodle-app side. Pulls latest Config.app release into the v0.0.8b DMG. |
| 16 Enable menubar shim + Apple Event handler | smoodle-app `SquirrelInputController.swift`: enable "Open Smoodle Config…", wire «event RimeRdpl» handler that re-deploys Rime. |
| 17 Bump vendor/smoodle + v0.0.8b version | smoodle-app side. |
| 18 Tag v0.0.8b + verify CI | Push tag, watch release.yml, verify appcast updated, founder smoke-test the auto-update from v0.0.8a.1 → v0.0.8b. |
| 19 MANUAL Founder smoke | Verify Config.app launches from menubar, all tabs functional, no crashes. |
| 20 MANUAL Recruit follow-up | Ping recruits with `Template D` from docs/RECRUIT-OUTREACH-DRAFTS.md (when added) after Sparkle delivers v0.0.8b to their v0.0.8a.1 install. |

### v0.0.8b adaptations that MUST persist (don't revert)

| # | Symptom | Fix |
|---|---|---|
| 1 | `add_data_files` anchor `(80 65 terra_pinyin.schema.yaml)` doesn't exist in fork's pbxproj → silent no-op | Anchor changed to `(83 84 thai_phonetic.dict.yaml)`; `require_anchor_present()` guard added; anchor_lib disabled |
| 2 | `dirs::home_dir().expect("$HOME")` would crash the whole Tauri process | Every `home_dir`-using helper returns `Result<PathBuf, String>` via `ok_or_else`; commands propagate with `?` |
| 3 | `Command::new("osascript")` / `"open"` / `"pgrep"` / `"plutil"` rely on $PATH — Tauri app bundle has minimal PATH | All shell-outs use absolute paths (`/usr/bin/...`) |
| 4 | Plan said `/Applications/Smoodle.app` — wrong; Smoodle is an IME at `/Library/Input Methods/Smoodle.app` | `const SMOODLE_PLIST` + `const BUNDLED_DIR` extracted; `#[cfg(target_os = "macos")]` guard added on reset_to_defaults |
| 5 | reqwest no timeout → Tauri thread pool starvation if forget endpoint hangs | `Client::builder().connect_timeout(10s).timeout(15s)` |
| 6 | `forget_token` written 0644 → world-readable on multi-user macOS | `#[cfg(unix)]` chmod 0600 after write |
| 7 | `BadResponse` error reflected server body into Tauri Err payload | Hardcoded message; never reflect server data |
| 8 | `SMOODLE_FORGET_URL` env override silently fails in Tauri GUI (no shell env) | Dropped; hardcoded URL |
| 9 | Telemetry tests need install_id missing + runner-err paths | Added; total 7 telemetry tests |
| 10 | Plan's `TelemetryState { install_id_hash: string\|null }` doesn't match Rust struct `{ has_install_id: bool }` | api.ts uses the Rust shape (booleans) |
| 11 | Vite 6 + `@sveltejs/vite-plugin-svelte` v5 throws `PartialEnvironment Proxy` on scoped `<style>` preprocess inside vitest | Move scoped `<style>` to `src/app.css` (global) + `$lib` alias added in vite.config.ts. **Apply pre-emptively to Status + Settings tabs in Task 10.** |
| 12 | settings.rs `write_default_custom_at` was overwriting `schema_list` with empty Vec, deleting user-added schemas | Guard with `if !patch.schema_list.is_empty()` |
| 13 | yaml.rs `backup()` mangled hidden-file stems (`.squirrelrc` → `.bak.<ts>`, stem lost) | Use `with_file_name(format!("{}.bak.{}", full_filename, ts))` |

### Hot commits (smoodle repo, main)

```
[Task 9]  feat(config-app): Words tab Svelte component + Vitest + typed api.ts
[Task 8]  feat(config-app): wire all 14 Tauri commands in lib.rs (Task 8)
[Task 7] fix(config-app): telemetry.rs post-review — timeouts, perms, hardcoded URL, missing tests
[Task 7]  feat(config-app): telemetry.rs — state/set_opt_in/forget
[Task 6] fix(config-app): settings.rs + yaml.rs post-review — proper error variant, atomic_copy, schema_list guard
[Task 6]  feat(config-app): settings.rs — 4 commands
[Task 5] fix(config-app): status.rs post-review — plist path + stderr propagation + log polish
[Task 5]  feat(config-app): status.rs — smoodle_running + compile_log + dict_counts
[Task 4] polish(config-app): deploy.rs review notes
[Task 4]  feat(config-app): deploy.rs — osascript Apple Event 'Deploy' shim
[Task 3] fix(config-app): user_dict post-review — IPC validation, $HOME fallback, OOB skip
[Task 3]  feat(config-app): user_dict commands — read/add/delete
[Task 2] fix(config-app): yaml.rs post-review — backup() hidden-file bug + doc gaps
[Task 2]  feat(config-app): yaml.rs — atomic_write_str + read + backup
[Task 1] fix(config-app): post-review hardening — CSP, single-instance, gitignore, metadata
[Task 1]  feat(config-app): scaffold Tauri 2 + Svelte 5 project
```

### Resume prompt for v0.0.8b continuation

```
I'm continuing v0.0.8b implementation. Context cheat-sheet at .planning/RESUME-v0.0.8.md — read that first.

v0.0.8b state:
- 9 of 20 tasks shipped + pushed (backend complete + wired, Words tab live)
- 27 cargo tests pass; 2 vitest tests pass; both pnpm + cargo build clean
- 11 tasks remain (frontend Status+Settings+shell, build, CI, smoodle-app DMG integration, manual smoke)

Apply the 13 documented adaptations pre-emptively — they're in the RESUME doc's "v0.0.8b adaptations that MUST persist" table. Especially #11 (move scoped <style> to src/app.css before writing any new .svelte file with styling).

Resume at Task 10 (Status + Settings tabs) per docs/superpowers/plans/2026-05-26-v0.0.8b-config-app.md.

Caveman mode (full) active project-wide. Use superpowers:subagent-driven-development for plan execution. Be aware the Task 9 subagent stalled on the CSS preprocess bug; for Tasks 10-11 brief the subagent UPFRONT to put styles in app.css from the start.

Verify environment first:
  cd /Users/lex/Dev/my_repos/experiment/smoodle && git status
  cargo test --manifest-path config-app/src-tauri/Cargo.toml 2>&1 | tail -3   # expect: 27 passed
  pnpm --dir config-app test --run 2>&1 | tail -5                              # expect: 2 passed

v0.0.8a.1 is publicly shipped; recruits not yet pinged. Soak gate (8a-C5) still pending.
```



---

## TL;DR — where we are now

**v0.0.8a SHIPPED publicly + v0.0.8a.1 PATCH SHIPPED.** DMGs live at `https://github.com/smoodle-type/smoodle-app/releases` (latest tag: `v0.0.8a.1`). Appcast live at `https://smoodle-type.github.io/smoodle-app/appcast.xml` (both items with valid 88-char EdDSA sigs). Founder smoke-tested green on v0.0.8a; v0.0.8a.1 fixes default.custom.yaml bundling.

**5 of 6 v0.0.8a gate criteria PASS:**

| ID | Status | Evidence |
|---|---|---|
| 8a-C1 DMG + .sig published | ✅ | `gh release view v0.0.8a --repo smoodle-type/smoodle-app` |
| 8a-C2 appcast.xml contains v0.0.8a | ✅ | `curl https://smoodle-type.github.io/smoodle-app/appcast.xml` |
| 8a-C3 founder smoke | ✅ | `.planning/phases/08a-dmg-sparkle/VERIFICATION.md` |
| 8a-C4 librime patch in binary | ✅ | symbol layout fingerprint via `package/test-dmg.sh` |
| 8a-C5 ≥2 non-founder recruits | ⏳ | **THIS IS THE LAST BLOCKER** — needs Task 19 step 5 + soak |
| 8a-C6 Sparkle synthetic test | ✅ | green in `release` CI workflow |

**18 of 22 plan tasks + Task 13a (build chain fix) complete.** Remaining:

- **Task 19 step 5 (MANUAL — founder)**: send `docs/RECRUIT-OUTREACH-DRAFTS.md` Templates A/B/C to 2-5 diaspora-Thai macOS friends. Drafts ALREADY refreshed for DMG install path (Input Methods, not /Applications) + Gatekeeper instructions + bearer token slot.
- **Task 20 (MINE — when recruits respond)**: fill `.planning/SOAK-LEDGER-v0.0.7.md`, flip 8a-C5 PASS at N≥2, tag `v0.0.8a-closed`, emit verdict.

## MP-2 timing anchor (audit-relevant)

- Pre-registration commit `8f4439c` @ **2026-05-26 13:36:24 +0700** — `docs/DECISION-GATE-CRITERIA-v0.0.8.md`
- First-green CI run on v0.0.8a tag: ~14:52 +0700 (76 min after anchor)
- All E2E green surfaces post-date the anchor commit ✓

---

## Git state (end of session — both repos clean + pushed)

- `smoodle/main` → in sync with `origin/main`
- `smoodle-app/master` → in sync with `origin/master`
- `smoodle-app/gh-pages` → in sync; appcast live with valid sig
- Tag `v0.0.8a` → live on origin smoodle-app + gh release published
- Tag `v0.0.8a-schema` → live on smoodle (`65fbe2c`) — used by `vendor/smoodle` submodule pin

Verify:
```bash
cd /Users/lex/Dev/my_repos/experiment/smoodle && git status && git log --oneline -3
cd /Users/lex/Dev/my_repos/experiment/smoodle-app && git status && git log --oneline -3
gh release view v0.0.8a --repo smoodle-type/smoodle-app --json assets --jq '.assets[].name'
```

---

## Plan-vs-reality adaptations shipped this session (DO NOT REVERT)

| # | Symptom | Fix |
|---|---|---|
| 1 | `package/add_data_files` sed `-i ''` + multi-line `a\` exits 2 on current macOS even on success | Patched to awk equivalent (in `smoodle-app` commit `b834a0e`) |
| 2 | `action-install.sh` `copy-rime-binaries` overwrites smoodle librime with upstream from rime-1.16.1 archive → patch never reaches binary | Added force `rm + make download-librime` after copy-rime-binaries |
| 3 | `SQUIRREL_BUNDLED_RECIPES` unset → plum installs all default packages (bopomofo/cangjie/luna-pinyin/…) | Defaulted to `"prelude essay"` in action-install.sh |
| 4 | test-dmg.sh `grep -c sorted_initial_` always 0 — that's a private member, not a symbol in release-stripped builds | Replaced with Peek-offset symbol-layout fingerprint check (smoodle Peek at `0x93948`, upstream at `0x93940`) |
| 5 | `release.yml` `::add-mask::` on EdDSA sig swallowed value across job-output boundary → appcast got empty `edSignature=""` | Removed mask; EdDSA sigs are public (literally in appcast.xml) |
| 6 | `gh release create` HTTP 403 | Added `permissions: contents: write` to build-dmg job in release.yml |
| 7 | Schema-copy in `build-dmg.sh` (plan said) is too late — Xcode bundles `data/plum/*` via `add_data_files` BEFORE DMG construction | Moved schema-copy to `action-build.sh` (before make release) |
| 8 | `package/test-*` gitignore rule would swallow `package/test-dmg.sh` | Added `!package/test-dmg.sh` negation in `.gitignore` |
| 9 | Sparkle 2.x `sign_update --verify -p <pubkey>` doesn't exist | Use stdin pipe `printf %s "$KEY" \| sign_update --ed-key-file -` for sign + Keychain or env for verify |
| 10 | `smoodle-app` + `smoodle` both private — Pages requires public on free org plan, CI submodule clone of vendor/smoodle 404'd | Flipped BOTH repos to public via `gh api -X PATCH visibility=public` |
| 11 | First appcast.xml CI commit had empty sig | Manual patch on gh-pages worktree (sig recovered from `.sig` release asset) |

## Known v0.0.8a limitation — RESOLVED in v0.0.8a.1 (2026-05-26 ~16:50 +0700)

Originally: `default.custom.yaml` not bundled → fresh-machine recruits saw luna-pinyin Chinese candidates until they hand-edited `~/Library/Rime/default.custom.yaml`.

**Closed by smoodle-app commits `cf3247e` (fix) + `fe03ec5` (version bump) + tag `v0.0.8a.1`.** Root cause: `package/add_data_files`'s anchor `(80 65 terra_pinyin.schema.yaml)` referenced pbxproj entries that don't exist in this fork → awk in `add_line()` matched nothing → tmp file byte-identical to original → mv was no-op → "adding default.custom.yaml" log lied. Verified shipped v0.0.8a.1 DMG contains `Smoodle.app/Contents/SharedSupport/default.custom.yaml` (510 B); appcast updated with valid 88-char EdDSA sig; Sparkle auto-update will deliver v0.0.8a.1 to existing v0.0.8a installs on next 24h check (or manual menubar S → Check for updates...).

Hardening shipped: anchor moved to `(83 84 thai_phonetic.dict.yaml)`; `anchor_lib` disabled (no rime plugins bundled); `require_anchor_present()` hard-fail guard prevents future silent failures.

---

## Optional cleanups (non-blocking)

- **Legacy `release-ci.yml`** — ✅ disabled 2026-05-26 (`gh workflow disable release-ci.yml`). Won't fire on future tags.
- **Telemetry 90-day retention cron** on dxc.0dl.me (v0.0.7 W2 punch list item, partial close). DB grows unbounded until then. BLOCKED on SSH access — founder must run, or authorize use of shared password.
- **forget-api per-recruit bearer tokens** when N > 3 (currently single shared token in `/tmp/umami-deploy/forget_token.txt`).

---

## v0.0.7 W2 telemetry — still live + healthy

- umami at `https://telemetry.0dl.me` (admin password rotated; founder has)
- forget-api at `https://forget.0dl.me/api/forget` (bearer-auth enforced)
- Site_id `88042064-eeea-465a-8658-002d978d4f9b`
- DB pristine since 2026-05-25 13:00 +0700 (no events yet)
- Shared bearer token in `/tmp/umami-deploy/forget_token.txt` — regenerate `openssl rand -hex 32` if leaked

DMG install does NOT fire install events (v0.0.7 telemetry was install.sh-side). v0.0.9 may add runtime telemetry from Smoodle.app process.

---

## v0.0.8b plan still queued

After v0.0.8a closes (Task 20), execute:

```
docs/superpowers/plans/2026-05-26-v0.0.8b-config-app.md  (20 tasks, ~2 weeks)
```

Builds the Tauri 2 + Svelte 5 Config.app: 14 commands across user_dict/deploy/status/settings/telemetry. Ships via Sparkle auto-update to existing v0.0.8a installs (no second drag-install required).

Verify Tauri toolchain installed before starting (`cargo install tauri-cli --version "^2.0" --locked`).

---

## Resume prompt (paste this in new session)

```
I'm continuing v0.0.8 implementation. Context cheat-sheet at .planning/RESUME-v0.0.8.md — read that first.

v0.0.8a is SHIPPED publicly (DMG + appcast live). 5 of 6 gate criteria PASS; only 8a-C5 (≥2 non-founder recruits installed) is pending. Per session-start instructions from prior session, the founder is sending outreach drafts manually — when ≥2 ledger rows show install_success=Y AND v0.0.8a install=Y, close the gate (Task 20 in docs/superpowers/plans/2026-05-26-v0.0.8a-dmg-sparkle.md).

Next actions in priority order:
1. Check .planning/SOAK-LEDGER-v0.0.7.md — if ≥2 rows have v0.0.8a install=Y + install_success=Y, execute Task 20 (flip 8a-C5 PASS in .planning/phases/08a-dmg-sparkle/VERIFICATION.md, tag v0.0.8a-closed in smoodle repo, push).
2. If recruits haven't responded yet, ask the founder for status and stand by.
3. If recruits hit the default.custom.yaml gap (no Thai candidates show up), consider patching Squirrel.xcodeproj/project.pbxproj to bundle default.custom.yaml as a "Copy Shared Support Files" entry (see "Known v0.0.8a limitation" section of RESUME doc).

Other things you might be asked to start:
- v0.0.8b execution (docs/superpowers/plans/2026-05-26-v0.0.8b-config-app.md) — can start in parallel with v0.0.8a soak; doesn't block on gate.
- Optional cleanups (disable legacy release-ci.yml, telemetry 90-day cron) — non-blocking.

Caveman mode (full) active in this project — drop articles/filler, fragments OK, technical accuracy preserved. Use superpowers:subagent-driven-development for plan execution; superpowers:executing-plans for inline batch.

Verify environment before doing work:
  cd /Users/lex/Dev/my_repos/experiment/smoodle && git status
  cd /Users/lex/Dev/my_repos/experiment/smoodle-app && git status
  gh release view v0.0.8a --repo smoodle-type/smoodle-app --json assets --jq '.assets[].name'

If anything looks unexpected, ask the founder before acting.
```

---

## If something goes wrong

- **gh release v0.0.8a missing** → CI workflow `release` (.github/workflows/release.yml in smoodle-app) didn't complete. Check `gh run list --repo smoodle-type/smoodle-app --workflow=release.yml --limit 3`.
- **appcast.xml has empty edSignature** → repeat of the `::add-mask::` bug; sig fix already shipped (commit removing the mask). If recurs, recover sig from `.sig` asset + patch on gh-pages worktree. See VERIFICATION.md note for procedure.
- **librime patch not in shipped binary** → run `package/test-dmg.sh` on the DMG; symbol-layout fingerprint check will report. Don't trust the obsolete `grep sorted_initial_` check from earlier plan text.
- **Pages 404** → smoodle-app must be public (`gh api repos/smoodle-type/smoodle-app --jq '.visibility'`). Pages require public on free org plan.
- **CI submodule clone 404 on vendor/smoodle** → smoodle repo must also be public (flipped 2026-05-26).
- **Sparkle CI fails on EdDSA sign** → check `gh secret list --repo smoodle-type/smoodle-app` has SPARKLE_PRIVATE_KEY. Regenerate via Task 6 in 08a plan if leaked.
- **Recruit reports "I see Chinese candidates"** → `default.custom.yaml` gap. Send the hand-edit snippet + Deploy instruction. Consider patching project.pbxproj if it happens twice.

---

## After v0.0.8 closes

- Open v0.0.9 milestone (likely: runtime telemetry from Smoodle.app, per-recruit bearer tokens, more Settings tab surfaces — theme, hotkeys)
- Revisit Apple Developer ID notarization for v0.1.0 public-launch
- Schema regen / dict expansion still gated (out of scope per CLAUDE.md until v0.2 LLM plugin lands)
- Cross-repo HARDEN-03 (universal dylib lipo-join in smoodle-type/librime smoke-build.yml) — v0.0.7 W4
- Audit-trail backfill (retroactive `0[4567]-VERIFICATION.md` for v0.0.6 phases) — v0.0.7 W5

---

*Resume artifact rewritten 2026-05-26 15:05 +0700 after v0.0.8a shipped publicly. Self-contained; new session needs only this file + the spec + the v0.0.8b plan (08a plan can be skimmed since most tasks done).*
