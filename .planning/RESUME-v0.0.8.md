# Resume v0.0.8 implementation

**Updated:** 2026-05-26 ~15:05 +0700 (end of v0.0.8a shipping session)
**Use:** open new Claude Code session, paste the "Resume prompt" block below as first message.

---

## TL;DR — where we are now

**v0.0.8a SHIPPED publicly.** DMG live at `https://github.com/smoodle-type/smoodle-app/releases/tag/v0.0.8a`. Appcast live at `https://smoodle-type.github.io/smoodle-app/appcast.xml` (with valid EdDSA sig). Founder smoke-tested green.

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

## Known v0.0.8a limitation (deferred to v0.0.8b)

**`default.custom.yaml` is NOT bundled in `Smoodle.app`** because it was never wired into `Squirrel.xcodeproj/project.pbxproj`. Fresh-machine recruits will see luna-pinyin Chinese candidates until they hand-create `~/Library/Rime/default.custom.yaml`:

```yaml
patch:
  schema_list:
    - schema: thai_phonetic
```

…then menubar S → Deploy. Documented in INSTALL.md + VERIFICATION.md. Founder smoke worked because the founder's ~/Library/Rime/ already had this from prior install.sh runs.

**If recruits report this is a blocker**, options:
- (a) **Patch `project.pbxproj`** to wire default.custom.yaml as a "Copy Shared Support Files" build phase entry. ~30 min surgical edit. Need new UUIDs in 4 places matching the existing pattern (see other entries like `default.yaml`).
- (b) **Wait for v0.0.8b** — Config app's "Set as default Thai input" button does this on click.

Recommendation: ship v0.0.8a as-is, see if it's an actual problem. If ≥1 recruit reports it, do (a) ASAP.

---

## Optional cleanups (non-blocking)

- **Legacy `release-ci.yml`** triggers on every tag + fails (was red before our work — independent bug in .pkg build path). Either disable (`gh workflow disable release-ci.yml --repo smoodle-type/smoodle-app`) or restrict its `tags` pattern to exclude `v0.0.8*`. Just CI noise right now.
- **Telemetry 90-day retention cron** on dxc.0dl.me (v0.0.7 W2 punch list item, partial close). DB grows unbounded until then.
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
