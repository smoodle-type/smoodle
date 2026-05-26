# Resume v0.0.8 implementation

**Created:** 2026-05-26 (end of brainstorm + writing-plans session)
**Use:** open new Claude Code session, paste the "Resume prompt" block below as first message.

---

## Where things stand

### Decisions locked (in spec + plans)

- v0.0.8 phased: **v0.0.8a** (DMG + Sparkle, ~1.5 weeks) → **v0.0.8b** (Tauri Config app, ~2 weeks)
- Two `.app` bundles in one DMG: `Smoodle.app` (IMK) + `Smoodle Config.app` (Tauri 2 + Svelte 5)
- Schema via git submodule: `smoodle-app/vendor/smoodle/` pinned to tag (`data/plum/*.yaml` gitignored, regenerated at build time)
- Sparkle auto-update both apps, EdDSA-signed, daily background check, user approves each install
- Hosting: GitHub Releases (DMG) + GitHub Pages (appcast.xml)
- Unsigned (Apple notarization deferred to v0.1.0); recruits accept Gatekeeper warning
- Telemetry surface unchanged from v0.0.7 (DMG install does NOT fire install events; v0.0.9 may add runtime telemetry)
- 14 Tauri commands across 5 surfaces (user_dict, deploy, status, settings, telemetry)

### Spec + plans (read these first in new session)

```
docs/superpowers/specs/2026-05-26-v0.0.8-installer-ux-design.md   (468 lines, 36KB — the design)
docs/superpowers/plans/2026-05-26-v0.0.8a-dmg-sparkle.md          (21 tasks, ~1770 lines)
docs/superpowers/plans/2026-05-26-v0.0.8b-config-app.md           (20 tasks, ~1870 lines)
```

### Git state at end of session

- `smoodle` repo (`/Users/lex/Dev/my_repos/experiment/smoodle`): on `main`, clean tree, all commits pushed to `origin/main`. Last commit: plans landed.
- `smoodle-app` repo (`/Users/lex/Dev/my_repos/experiment/smoodle-app`): on `master`, **1 commit ahead of origin/master** — `1a0314c fix(librime): re-pin submodule to smoodle-type/librime@1.16.0-smoodle.1`. **NOT PUSHED YET.** First task in v0.0.8a plan (Task 0) pushes it.

Verify with:
```bash
cd /Users/lex/Dev/my_repos/experiment/smoodle && git status && git log --oneline -5
cd /Users/lex/Dev/my_repos/experiment/smoodle-app && git status && git log --oneline origin/master..HEAD
```

### Open tasks from prior milestone (v0.0.7) — still valid, do in parallel if you want

- `.planning/SOAK-LEDGER-v0.0.7.md` rows R1-R5 are empty. Founder needs to ping 2-5 diaspora-Thai macOS recruits using `docs/RECRUIT-OUTREACH-DRAFTS.md`. v0.0.7 GATE-02 closes when ≥2 install. Note: v0.0.8a task 19 reuses the same outreach surface but with new DMG link instead of `bash scripts/install.sh`.
- Shared bearer token in `/tmp/umami-deploy/forget_token.txt` (regenerate with `openssl rand -hex 32` if leaked or stale).

### Critical context (don't re-discover)

- **librime patch was missing from existing DMG** — `dist/Smoodle-v0.1.0.dmg` in smoodle-app was built before the submodule re-pin. Must be rebuilt before any release. Task 13 in 08a plan does this.
- **Telemetry stack live on dxc.0dl.me** — `umami` at `telemetry.0dl.me`, `forget-api` at `forget.0dl.me`, both behind cloudflared. Site_id `88042064-eeea-465a-8658-002d978d4f9b`. Bearer-auth enforced. DB pristine since 2026-05-25 13:00 +0700.
- **MP-2 anti-survivorship-bias discipline applies to v0.0.8 too** — Task 1 in 08a plan pre-registers `docs/DECISION-GATE-CRITERIA-v0.0.8.md` BEFORE any v0.0.8 E2E surface goes green. The commit timestamp is the audit anchor. Don't skip.
- **`smoodle-app` Squirrel fork is real and mature** — full Xcode project, Sparkle vendored, DMG builder ready, GHA workflows exist. Don't accidentally "rewrite from scratch" — read existing scripts in `smoodle-app/package/` first.
- **Tag `1.16.0-smoodle.1` DOES exist on `smoodle-type/librime`** — verified 2026-05-26. Don't trust the earlier session's "tag doesn't exist" claim (that was a truncated `git ls-remote | head -10` output).

---

## Resume prompt (paste this in new session)

```
I'm continuing v0.0.8 implementation. Context cheat-sheet lives at .planning/RESUME-v0.0.8.md — read that first.

Spec: docs/superpowers/specs/2026-05-26-v0.0.8-installer-ux-design.md
Plans:
  - docs/superpowers/plans/2026-05-26-v0.0.8a-dmg-sparkle.md  (do this first, prerequisite)
  - docs/superpowers/plans/2026-05-26-v0.0.8b-config-app.md   (after 08a closes)

Plans were produced by superpowers:writing-plans. Both have explicit task checkboxes (`- [ ]`) with full code blocks per step — no placeholders, ready to execute.

Start with v0.0.8a Task 0 (push the staged librime fix in /Users/lex/Dev/my_repos/experiment/smoodle-app — verify locally first that exactly one commit is ahead of origin/master). Then continue through Task 1 (pre-register decision criteria), Task 2 (tag schema), etc.

Execute via superpowers:subagent-driven-development (recommended — fresh subagent per task, review between tasks) OR superpowers:executing-plans (inline batch execution). Pick the right skill based on how independent the tasks feel.

Stop at any task that needs human input (Task 14 founder smoke test, Task 15 recruit outreach, Task 19 founder e2e). Surface what you need from me clearly.

Caveman mode (full) is active in this project — drop articles/filler, fragments OK, technical accuracy preserved.
```

---

## If the new session asks "which task am I on"

Each plan task starts with `## Task N: <name>`. Track progress by which checkboxes are flipped (`- [x]`) inside the plan file. Re-read the file to see current state.

After completing a task, the next agent should:
1. Update the task's checkboxes inline in the plan file
2. Commit with the conventional commit message shown in that task's last "Commit" step
3. Move to next task

---

## If something goes wrong

- **librime patch not in shipped binary** → `otool -tV /Applications/Smoodle.app/Contents/Frameworks/librime.1.dylib | grep sorted_initial_` should return ≥1 line. If 0, the submodule re-pin didn't take effect — verify `cd smoodle-app/librime && git describe --tags` returns `1.16.0-smoodle.1`.
- **Sparkle CI fails on EdDSA sign** → check `SPARKLE_PRIVATE_KEY` secret is set on `smoodle-type/smoodle-app` repo (`gh secret list --repo smoodle-type/smoodle-app`); regenerate via Task 6 if leaked.
- **GitHub Pages 404 on appcast.xml** → Pages may need re-enabling: `gh api repos/smoodle-type/smoodle-app/pages` should show `"status":"built"`; if not, redo Task 12 Step 5.
- **Tauri build fails on macOS** → likely missing `cargo install tauri-cli --version "^2.0" --locked` OR Xcode CLI tools not present (`xcode-select --install`).
- **Recruits report Gatekeeper blocks them** → expected for v0.0.8 (unsigned). Right-click → Open is the workaround; documented in `INSTALL.md`. If a recruit can't do this, ad-hoc-sign as a fallback (`codesign --force --deep --sign - /Applications/Smoodle.app`) — still triggers Gatekeeper but proves provenance.

---

## After v0.0.8 closes

- Open v0.0.9 milestone (likely: runtime telemetry from Smoodle.app, per-recruit bearer tokens, more Settings tab surfaces — theme, hotkeys)
- Revisit Apple Developer ID notarization for v0.1.0 public-launch
- Schema regen / dict expansion still gated (out of scope per CLAUDE.md until v0.2 LLM plugin lands)

---

*Resume artifact written 2026-05-26 13:50 +0700 at end of brainstorm + writing-plans session. Self-contained; new session needs only this file + the spec + the plans.*
