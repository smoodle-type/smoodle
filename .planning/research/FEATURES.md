# Feature Research

**Domain:** Small-batch indie IME at "dogfood-ready → share-with-friends" milestone (Phase 1 finish)
**Researched:** 2026-05-08
**Confidence:** MEDIUM-HIGH (HIGH for table-stakes/anti-features grounded in repo evidence + Squirrel/Rime conventions; MEDIUM for telemetry/feedback patterns extrapolated from privacy-first dev-tool norms — no direct Rime-IME peer with published "dogfood circle" docs surfaced)

---

## Audience Personas (Phase 1 Wedge)

Every feature in this doc is justified against one of three personas. If a candidate feature serves none of them, it's an anti-feature for Phase 1.

| Persona | Description | What "good" looks like |
|---------|-------------|------------------------|
| **Founder (P1)** | Heritage-Thai builder dogfooding daily on Apple Silicon. Already knows the architecture; tolerates rough edges; needs reliability + fast feedback loops. | "I open a fresh Squirrel session, smoodle ranks correctly, when something breaks I know within 60s of trying." |
| **Diaspora-Thai friend (P2)** | Bilingual EN/TH speaker, comfortable in Terminal but not deep in Rime/Squirrel internals. Surfaced through informal channels; will spend ≤15 min on first install before bouncing. | "I copy-paste 3 commands from README, type `sawadee`, see `สวัสดี`. If it doesn't work, the troubleshooting section answers my question without a GitHub issue." |
| **Edge-case Intel-Mac dogfooder (P3)** | Smaller subset of P2 on Apple Silicon-incompatible hardware. Currently broken silently. | "Either it works, or the installer refuses cleanly with a clear message instead of breaking Squirrel." |

---

## Feature Landscape

### Table Stakes (Diaspora-Thai friend MUST have these or installs bounce)

Features whose absence causes the friend-wedge to fail. Each maps to an existing `CONCERNS.md` entry or to a documented Phase 1 deliverable in `PROJECT.md`.

| # | Feature | Why Expected | Complexity | Persona | Notes |
|---|---------|--------------|------------|---------|-------|
| TS1 | **Idempotent re-runnable installer** | Friend will re-run after any failure, expects backup-on-overwrite, expects no destructive side-effects | LOW | P2 | Already shipped (`install.sh`, timestamp backup); enforced by `tests/test_installers.py` shape suite. Keep working. |
| TS2 | **Post-install "type sawadee, see สวัสดี?" probe** | Confirmation in the moment of install. Without it, friend wonders "did it work?" and bounces silently | LOW | P2 | The `install.sh` already has a manual prompt block (line 95-117). Phase 1 finish should formalize: print expected probe, wait for ENTER, capture y/N response. Optional: log y/N + telemetry for D2 if opted in. |
| TS3 | **Architecture-mismatch refusal (Intel Mac)** | Silent failure on Intel = Squirrel breaks, friend has no recovery path | LOW | P3 | `uname -m` check at top of `install-librime-fork.sh`; refuse with "Intel Mac dylib not yet shipped — schema-only install (`install.sh` skip librime swap) gives partial functionality". CONCERNS.md flags this as Medium priority. |
| TS4 | **Sparkle re-swap detection / hash drift warning** | Squirrel auto-update silently un-patches; ranking degrades; friend will think smoodle "got worse" | MEDIUM | P1, P2 | Already in PROJECT.md Active list. Implementation options: (a) periodic LaunchAgent comparing dylib SHA256 to known-good, (b) `install.sh --check` mode, (c) in-installer note "if ranking degrades, re-run install-librime-fork.sh". Recommendation: ship (b) + (c) in Phase 1 finish; defer (a) to Phase 1.5. |
| TS5 | **README troubleshooting section (top 5 questions)** | First place a stuck friend goes is the README. If "Squirrel doesn't show smoodle in switcher" isn't answered, they GitHub-issue or bounce | LOW | P2 | Currently absent (CONCERNS.md "README quality gaps", README line 86 ASCII layout). Top 5 must include: switcher missing, `Ctrl+\`` doesn't trigger, deploy timeout, ranking looks wrong (Sparkle re-swap), Intel-Mac silent break. |
| TS6 | **Uninstall instructions (revert dylib + remove schema)** | Privacy/trust signal; proves you respect the user's machine. Cheap to add, expensive in trust to omit | LOW | P2 | Document in README troubleshooting: `sudo cp librime.1.dylib.smoodle-backup librime.1.dylib`, `rm ~/Library/Rime/thai_phonetic.*`, `rm ~/Library/Rime/default.custom.yaml`. Smoodle-app uninstall is a `rm /Library/Input\ Methods/Smoodle.app`. ~10 lines in README. |
| TS7 | **Status badge / version visible in README** | Friend wants to know "is this stale?" before investing 15 min in install | LOW | P2 | README line 21 still says `APPROVED-PENDING-PHASE-0` — flip to `APPROVED` per Phase 0 close. Add v0.0.6 + last-tested-date line. |
| TS8 | **Windows install snippet in README** | Lane B shipped (TODOS.md #7 closed); Windows-using diaspora friend can't find install instructions | LOW | P2 | CONCERNS.md README quality gaps: "No Windows install snippet despite Lane B closed". 5-10 lines: `winget install Rime.Weasel`, then PowerShell snippet. |
| TS9 | **Linux install snippet in README** | Same as TS8 — Lane C shipped, README hides it | LOW | P2 | One stanza for ibus + one for fcitx5. Document the RANKING LIMITATION explicitly so Linux friend knows up-front, not post-install. |
| TS10 | **Schema lint test (D5 in PHASE1-PROMPT)** | A bad schema YAML lands without lint, deploys silently no-op, friend's install "succeeds" but smoodle doesn't appear in switcher | LOW | P1 (catches regressions for P2) | Listed in PROJECT.md Active. `tests/test_schema_lint.py` validates: `import_preset` references resolve, regex syntax in algebra rules, weight column is positive int, schema/dict/default.custom.yaml are valid YAML. Wire into CI. |
| TS11 | **Lane E E2E for macOS + Windows** | A regression in `install.sh` between v0.0.6 → v0.0.7 silently breaks the friend wedge; founder finds out via friend-bug-report not CI | MEDIUM | P1 (catches regressions for P2, P3) | PROJECT.md Active. Already has `install-linux-e2e.yml` working as the template. macOS E2E needs `runs-on: macos-14` + Squirrel install + run `install.sh` + assert `~/Library/Rime/thai_phonetic.dict.yaml` exists + assert deploy completes. Windows E2E needs `runs-on: windows-latest` + Weasel + run `install-windows.ps1` + same shape assertions. |
| TS12 | **GH Releases asset for `librime-1.16.0-smoodle.1-macOS-universal.dylib`** | `install-librime-fork.sh` URL-fetches this; CONCERNS.md flags it as "may not yet be uploaded" — High priority | LOW | P2 | The asset must exist before any non-founder install attempt succeeds without `make release` 5-15 min source build. Phase 1 finish: verify asset is published; add SHA256 to script. |

**Confidence:** HIGH. All 12 are repo-grounded — either in `PROJECT.md` Active list, `CONCERNS.md` Tech Debt / Missing Critical Features, or `PHASE1-PROMPT.md` Critical Failure Modes. None are speculative.

---

### Differentiators (Potential v0.2 / Decision-Gate-positive moves — Phase 1.5 candidates)

Features that would set smoodle apart from comparable Rime schemas (rime-pinyin, rime-cangjie5, rime-bopomofo). NOT required for Phase 1; track as candidates for Decision Gate signal-positive expansion.

| # | Feature | Value Proposition | Complexity | Persona | Trigger to build |
|---|---------|-------------------|------------|---------|------------------|
| D1 | **`smoodle doctor` self-diagnose CLI** | One command (`bash scripts/doctor.sh`) prints: Squirrel version, librime SHA, schema version, deploy timestamp, last 10 Console.app smoodle entries, OS arch. Output is 1 paste in a GH issue. | LOW-MEDIUM | P1, P2 | Decision Gate positive: ≥1 unsolicited bug report. Reduces friend-bug-report friction from "what info do you need?" to "paste this". |
| D2 | **GH issue template prefilled with `doctor` output via URL parameters** | `https://github.com/smoodle-type/smoodle/issues/new?template=bug.yml&environment=...` — friend clicks button in installer, lands in pre-filled issue form | LOW | P2 | Pairs with D1. GitHub URL-parameter pre-population works for issue forms (verified — see [GitHub community discussion #15477](https://github.com/orgs/community/discussions/15477)). Generate the URL from `doctor` output. |
| D3 | **Self-hosted opt-in telemetry (D2 in PHASE1-PROMPT)** | Default OFF, install_id_hash only, single POST to umami/openpanel on first-Thai-character-committed event. Quantifies "founder + N friends use this" without GH issues | LOW-MEDIUM | P1 | Already in PROJECT.md Active. Privacy-first opt-in pattern matches industry norms (Go 1.23, [TelemetryDeck](https://telemetrydeck.com/docs/guides/privacy-faq/)). One-time consent on first install. **Critical: cannot be reused as the engagement-signal source for Decision Gate** — that signal is qualitative per Phase 0 close. Telemetry is a sanity-check, not a decision input. |
| D4 | **Schema-switcher onboarding sentence in README** | "Press `Ctrl+\`` (backtick) in any text field, pick 'smoodle Thai phonetic', start typing." Plus a 5-second screen-recording GIF. | LOW | P2 | Reduces "where's the switcher?" question from #1 troubleshooting hit to #5. McBopomofo and Squirrel both leave this as folk knowledge; smoodle differentiates by spelling it out. |
| D5 | **Pre-compiled dict `.bin` artifacts shipped alongside YAMLs** | Skip the 60s deploy on first install; user is typing in <5s after install completes | MEDIUM | P2, P3 | CONCERNS.md flags this as a Phase 1.5+ improvement. Rime supports binary table distribution. Not Phase 1 because the 60s deploy works; build infrastructure to produce `.bin` artifacts in CI is non-trivial. |
| D6 | **Installer "what just happened?" summary** | After successful install, print 5-line summary: "smoodle installed at v0.0.6, librime patched at 1.16.0-smoodle.1, Squirrel restarted, schema deployed in 47s, switcher trigger is `Ctrl+\``" | LOW | P2 | Current `install.sh` already prints success/fail; formalize into a structured summary. Reuse as the `--check` mode body for TS4. |
| D7 | **`scripts/install.sh --check` mode** | Re-run installer with `--check`; outputs hash drift status, schema deploy timestamp vs current, librime fork SHA. No side effects. | LOW | P1, P2 | Pairs with TS4 (Sparkle re-swap detection) — gives the user a manual command to verify state without the script-run-as-action ambiguity. |

**Confidence:** MEDIUM-HIGH. D1, D2, D6, D7 are direct extensions of existing installer code. D3 is already a PROJECT.md Active item. D4 is a README change. D5 is a build-infra investment with clear precedent (Rime's own binary distribution model).

---

### Anti-Features (Phase 1 explicit DO-NOT-BUILD)

Features that look attractive at this milestone but would dilute the wedge, exceed the 2-week Phase 1 finish budget, or commit smoodle to a maintenance burden incompatible with the founder + 1-3 friends scale.

| # | Anti-Feature | Why It Looks Attractive | Why It's Wrong For Phase 1 | Alternative |
|---|--------------|-------------------------|----------------------------|-------------|
| AF1 | **Custom dictionary editor UI** (GUI to add/edit/remove dict entries) | "Friends will hit OOV; let them add words!" Comparable IMEs (Gboard, Apple's Thai keyboard) have personal dictionaries. | (a) UI is 10x more code than the rest of Phase 1. (b) Dict YAML format is plain text; "edit `~/Library/Rime/thai_phonetic.dict.yaml` and re-deploy" is 2 README lines. (c) Personal dict entries don't merge with TNC weights without re-engineering merge_dict.py. (d) Wedge audience (founder + 1-3) can ship a list of OOV words to the founder, who batches them into next dict release. | Document "Adding your own words" in README troubleshooting: edit dict YAML, increment version, re-run install.sh. Total: 5 lines of docs. Defer GUI to Phase 2 or never. |
| AF2 | **Cloud sync of dict / personal entries / preferences** | "Phones, laptops, work machines — sync everything!" iCloud/Dropbox-style sync feels modern. | (a) Wedge audience is tiny — no need. (b) Adds account systems, conflict resolution, server infrastructure, ongoing $$. (c) PROJECT.md Out of Scope explicitly defers this to Phase 2 or never. (d) iCloud Drive on `~/Library/Rime/` works as a manual workaround for the founder. | Document "Sync via iCloud Drive" as a one-line tip in README troubleshooting. Phase 1 ships zero cloud infrastructure. |
| AF3 | **Account system / login** | "How do we know who our users are?" SaaS-style telemetry attribution. | (a) PROJECT.md Out of Scope. (b) Phase 0 close explicitly narrowed to qualitative signal — no quantitative attribution required. (c) Adds password reset, email verification, GDPR concerns. (d) install_id_hash (D3) gives the deduplication needed for telemetry without identity. | install_id_hash for telemetry; GitHub usernames for issue-based identity. No accounts. |
| AF4 | **Theming / color schemes / candidate-bar customization** | "Dark mode! Brand colors!" Competitive Rime schemas (rime-cantonese) ship custom skins. | (a) Squirrel/Weasel themes are user-controlled at the host level — smoodle inheriting Squirrel's theme is correct. (b) Theming work would need per-OS UI code (Squirrel's `squirrel.yaml` + Weasel's separate config) — multiplies maintenance. (c) Wedge audience hasn't asked for it. | Document "Customize Squirrel appearance" with a link to upstream Rime/Squirrel theming docs. Smoodle stays theme-agnostic. |
| AF5 | **Auto-update infrastructure (Sparkle for smoodle, Squirrel.Windows)** | "Releasing v0.0.7 means N friends need to manually re-install? Add auto-update!" | (a) PROJECT.md Out of Scope (Phase 2). (b) Adds signing/notarization/cert dependencies — explicitly NOT in Phase 1. (c) `git pull && bash scripts/install.sh` is 2 lines for the wedge audience. (d) Sparkle complications for smoodle would echo the Squirrel-Sparkle re-swap problem we already have. | Manual download + re-run installer per release. Track release cadence in TODOS.md. |
| AF6 | **iOS / iPadOS / Android installers** | "Friends type Thai on phones too!" Phone keyboard share is huge. | (a) PROJECT.md Out of Scope (Phase 2, blocked on TODOS #2 spike). (b) iOS IMEs cannot intercept input from external Bluetooth keyboards without entitlements smoodle doesn't have — kills the phonetic-typing UX entirely on iPhone touch keyboards. (c) Android third-party IMEs are a separate engine entirely (not Rime). | Document "iOS / Android: not yet" in README. Track in TODOS.md as Phase 2 spike. |
| AF7 | **Code-signed / notarized DMG; signed Authenticode .msi for Windows** | "Friends see Gatekeeper warnings; signing eliminates the friction" | (a) PROJECT.md Out of Scope (pre-public-ship gate). (b) ~$200/year (Apple Developer + Authenticode cert) wasted before Decision Gate signal positive. (c) Wedge audience is 1-3 friends — they will tolerate "right-click → Open" once. | Document the right-click-Open workaround in README. Add to public-ship checklist for post-Decision-Gate. |
| AF8 | **Internationalized installer copy / localized README** | "It's a Thai IME, the friend audience is Thai-speaking, write the README in Thai!" | (a) PROJECT.md Out of Scope. (b) Wedge audience is bilingual diaspora (English-fluent). (c) Maintenance multiplies (every README edit must propagate to TH translation). (d) Thai-speaker review burden is a real cost that competes with dict-quality review. | English README; Thai-language commentary in commit messages where natural. |
| AF9 | **Stripe / payment integration / "smoodle Pro" tier** | "Eventually we'll monetize" — signs of premature commercial commitment. | (a) PROJECT.md Out of Scope (Phase 2 commercial decision). (b) Decision Gate signals haven't fired. (c) Phase 1 finish budget is 2 weeks; Stripe integration alone is 1+ week even before considering Apple/Google in-app-purchase rules. | Defer all commercial decisions until Decision Gate review. |
| AF10 | **Mac App Store / Microsoft Store / `winget` submission** | "Make install one-click!" Distribution surface area expansion. | (a) PROJECT.md Out of Scope (pre-public-ship gate). (b) MAS/MS Store both require code signing (ties to AF7). (c) `winget install` requires manifest review; smoodle's Weasel-as-host model doesn't fit single-installer manifests cleanly. (d) Wedge audience can `bash scripts/install.sh`. | GitHub Releases is the Phase 1 distribution surface. |
| AF11 | **Cross-platform unified GUI installer (e.g., Tauri/Electron app)** | "Bash + PowerShell scripts feel old; ship a native installer with a progress bar!" | (a) Multiplies the "two parallel installer flavors per platform" CONCERNS.md fragility (currently 6 scripts; would become 6 scripts + 1 GUI = 7 surfaces). (b) Tauri/Electron adds 100+MB to the distribution. (c) Wedge audience is comfortable with a Terminal install command. | Stay with bash/PowerShell. Add `--quiet` and `--check` flags to existing scripts for power-user UX. |
| AF12 | **Forked-rime distro packages on Linux (.deb, AUR PKGBUILD with patched libRime.so)** | "Linux dogfooders deserve the same ranking quality as macOS/Windows" | (a) PROJECT.md Out of Scope. (b) Per-distro packaging maintenance burden (Debian + Ubuntu + Arch + Fedora variants). (c) Wedge audience is "smaller wedge of smaller wedge". (d) Linux already ships option 3 (accept unpatched, document RANKING LIMITATION). | Linux stays on system librime + documented limitation until upstream PR (TODOS #1) lands or audience explicitly requests. |
| AF13 | **LLM tone-disambiguation plugin (smoodle_llm_translator)** | "The dict will always have OOV; LLM solves it" | Phase 1.5 explicitly. PROJECT.md D4. Dict's 100% TNC freq≥50 coverage is enough surface to test the wedge cleanly without LLM. Adding LLM in Phase 1 means C++ plugin + llama.cpp + Qwen 1.8B Q4 + ggml_abort_callback — all of Phase 1.5 scope crammed into Phase 1. | Defer to Phase 1.5. Phase 1 finish stays dict-only. |
| AF14 | **Cross-device dict sync** | Same as AF2 but framed as "sync your wordlist across machines" | Same anti-rationale as AF2. PROJECT.md Out of Scope. | iCloud Drive / Dropbox / git on `~/Library/Rime/` if a friend asks. |
| AF15 | **Discord / Slack / forum community infrastructure** | "Build a community around smoodle!" Comparable schemas (rime-cantonese) have Discord servers. | (a) Wedge audience is 1-3 named individuals — overhead exceeds value. (b) GitHub Discussions tab is a free, low-overhead alternative. (c) Founder-time better spent on dict quality + Lane E. | GitHub Issues + GitHub Discussions if traffic appears. |

**Confidence:** HIGH. Every anti-feature here is either explicitly listed in PROJECT.md Out of Scope, contradicts the Phase 0 wedge narrowing, or violates the 2-week Phase 1 finish budget.

---

## Onboarding UX Pattern: 60-Second Self-Test

Question from the research brief: "Is there a pattern for embedding a 60-second self-test inside an installer?"

**Answer:** Yes, and `install.sh` already gestures at it (lines 95-117 — manual prompt block). Phase 1 finish should formalize this into a clearer post-install probe.

**Recommended pattern:**

```
[smoodle install complete]

Quick test (60 seconds):
  1. Press Ctrl+`  to open Squirrel's schema switcher
  2. Pick "smoodle Thai phonetic"
  3. In any text field, type:  sawadee
  4. Press space — you should see:  สวัสดี

Did it work?  [y/n/skip]:
```

- `y` → installer prints "Great. Try `khrap` → ครับ next." and exits 0.
- `n` → installer prints troubleshooting URL pointing at the README troubleshooting section + `doctor` command suggestion.
- `skip` → exits 0 silently (assume founder re-running, doesn't need the prompt).

**Telemetry hook (only if D3 opt-in is yes):** POST `{event: "first_run_probe", result: "y"|"n", install_id_hash}` to the umami endpoint. Single POST, gated on opt-in.

**Anti-pattern to avoid:** Don't try to programmatically *verify* the probe by intercepting Squirrel's IPC or simulating keystrokes — adds 100+ lines, breaks across OS versions, and the manual probe is more honest about whether the user can actually type Thai. The installer's job here is to coach the user through a sanity check, not to automate it.

**Confidence:** MEDIUM. No published Rime-IME peer ships this pattern explicitly, but it directly addresses the "did it work?" friction in Squirrel's first-run experience documented in the [Bdim blog](https://blog.bdim.moe/posts/configuring-rime-input-method-on-macos/) and [fernvenue's Rime-on-macOS guide](https://blog.fernvenue.com/archives/rime-on-macos/).

---

## Update / Re-Swap Mechanics

Question: "What do users expect when Squirrel/Weasel auto-updates and silently breaks the patched dylib? Is 're-run the installer' the standard answer or is detection+notification expected?"

**Industry pattern observed:** Re-run-the-installer is the dominant pattern for indie dev tools that swap binaries (e.g., dyld interposers, kernel-extension replacements, custom Mach-O hooks). Detection+notification exists but is typically v2 work after manual re-run is proven.

**For smoodle Phase 1:**

- **Primary mechanism:** Document the Sparkle re-swap risk in README troubleshooting + on first-run installer success message: "If smoodle ranking degrades after a Squirrel update, run `bash scripts/install-librime-fork.sh` again."
- **Detection (TS4 above):** Add `bash scripts/install.sh --check` that compares the live `librime.1.dylib` SHA256 against the known-good fork-tag SHA256. Prints OK or DRIFT with reapply command.
- **Notification (defer to Phase 1.5):** A LaunchAgent that watches the dylib path is overkill for the wedge audience and adds an always-on background process — anti-pattern for a privacy-positive tool.

**Confidence:** MEDIUM. No direct precedent in the Rime ecosystem (Squirrel-Sparkle re-swap is a smoodle-specific consequence of the librime fork). The "manual re-run + optional `--check`" pattern is consistent with how dyld interposers (e.g., DYLD_INSERT_LIBRARIES tools) handle similar problems.

---

## Telemetry & Feedback Loop Patterns (Minimum Viable)

Question: "What's the minimum-viable feedback mechanism for an opt-in dogfood circle?"

**Three patterns researched, ranked by Phase 1 fit:**

1. **GitHub Issue template prefilled via URL parameters (D2 above)** — RECOMMENDED for Phase 1 finish.
   - Effort: ~30 min (one YAML file + one bash function in `doctor` script).
   - User flow: Friend hits a problem → installer prints a clickable URL → GitHub form opens with environment fields prefilled → friend types description, hits submit.
   - Verified: GitHub issue forms support URL-parameter pre-population per [GitHub community discussion](https://github.com/orgs/community/discussions/15477).

2. **`mailto:` link with Console.app log capture** — alternative or supplement.
   - Effort: ~30 min (one bash function: `log show --predicate 'subsystem == "im.rime.inputmethod.Squirrel"' --last 5m > /tmp/smoodle-log.txt; mailto:apinant.usu@gmail.com?subject=smoodle%20bug&body=<encoded log>`).
   - Trade-off: privacy implications (Console.app logs include other apps' chatter unless filtered tightly). User must manually attach the log file in the email client (mailto: doesn't support attachments cleanly).
   - Recommended: include in `doctor` script as a fallback for friends not on GitHub.

3. **Self-hosted umami/openpanel POST on first-Thai-character-committed event (D3 / PROJECT.md D2)** — RECOMMENDED for Phase 1 finish but as quantitative sanity-check, not Decision Gate input.
   - Effort: ~1-2 days (umami install on user's existing infra + Lua script in Rime schema or post-commit hook in installer + single-POST client).
   - Privacy posture: opt-in, default OFF, install_id_hash only, no PII, single endpoint on user-controlled infra. Matches industry norms ([Go 1.23 telemetry](https://devclass.com/2024/08/14/go-1-23-released-with-telemetry-uploaded-to-google-but-opt-in-after-developer-feedback/), [TelemetryDeck Privacy FAQ](https://telemetrydeck.com/docs/guides/privacy-faq/)).
   - **CRITICAL gotcha:** Phase 0 close re-tuned Decision Gate signals to *qualitative* (≥1 unsolicited bug report). Telemetry numbers are NOT the gating signal. Don't let "we have telemetry data" substitute for "we got an unsolicited human bug report."

**Confidence:** MEDIUM-HIGH. All three patterns have direct precedent in the privacy-first dev-tools ecosystem.

---

## Documentation Table Stakes

Question: "Troubleshooting section coverage (top 5 questions), uninstall instructions, recovery flows."

### Recommended top-5 troubleshooting entries for README

Order matters — friend reads top-down and stops at the first match.

1. **"smoodle Thai phonetic doesn't appear in Squirrel's schema switcher"**
   - Cause 1: deploy didn't run / failed silently. Fix: open Squirrel menu → Deploy.
   - Cause 2: schema timestamp issue (CONCERNS.md lines 67-72). Fix: `touch ~/Library/Rime/thai_phonetic.*` then re-deploy.
   - Cause 3: `default.custom.yaml` missing or malformed. Fix: re-run `bash scripts/install.sh`.

2. **"`Ctrl+\`` doesn't open the schema switcher"**
   - Cause: Squirrel's keybinding conflicts with another app or System Settings shortcut.
   - Fix: System Settings → Keyboard → Keyboard Shortcuts → Input Sources; verify no conflicts. Or: select smoodle from the menu-bar input source picker directly.

3. **"Type `sawadee`, see wrong Thai"**
   - Cause 1: stale dict deployed (Sparkle re-swap or upgrade). Fix: `bash scripts/install-librime-fork.sh`.
   - Cause 2: ranking-bug not patched (Linux only). Document: type, commit, retype workaround.

4. **"Squirrel deploy times out"**
   - Cause: first deploy of 28239-entry dict takes 30-60s on commodity hardware.
   - Fix: wait 60s; if still hanging, check Console.app for compilation errors.

5. **"Installer says 'arm64 dylib won't work on Intel Mac'"**
   - Cause: Phase 1 dogfood is Apple Silicon-only.
   - Fix: run `bash scripts/install.sh` (schema-only, no librime swap) for partial functionality. Universal dylib is on the Phase 1.5 list.

### Uninstall instructions (TS6)

```bash
# Restore original Squirrel dylib
sudo cp "/Library/Input Methods/Squirrel.app/Contents/Frameworks/librime.1.dylib.smoodle-backup" \
        "/Library/Input Methods/Squirrel.app/Contents/Frameworks/librime.1.dylib"

# Remove smoodle schema files
rm ~/Library/Rime/thai_phonetic.schema.yaml
rm ~/Library/Rime/thai_phonetic.dict.yaml
# (default.custom.yaml is shared; only remove if smoodle was the only schema)

# Restart Squirrel
osascript -e 'tell application id "im.rime.inputmethod.Squirrel" to quit'
open -b im.rime.inputmethod.Squirrel
```

**Confidence:** HIGH. All five entries are grounded in CONCERNS.md / PHASE1-PROMPT.md Critical Failure Modes. Uninstall script is a direct read of the install.sh / install-librime-fork.sh logic.

---

## Feature Dependencies

```
TS3 (arm64 refusal) ──requires──> nothing                  [LOW, do first]
TS5 (README troubleshooting)  ──requires──> TS6 (uninstall), TS8 (Win), TS9 (Linux)
TS7 (status badge update) ──requires──> nothing            [LOW, trivial]
TS8 (Win install snippet) ──requires──> already-shipped Lane B
TS9 (Linux install snippet) ──requires──> already-shipped Lane C
TS4 (Sparkle re-swap detection) ──enhances──> D7 (--check mode)
TS10 (schema lint) ──blocks──> TS11 (Lane E E2E) for full coverage
TS11 (Lane E E2E) ──requires──> TS10 (schema lint), TS12 (release asset)
TS12 (Releases asset verification) ──requires──> nothing   [HIGH priority]
TS2 (post-install probe) ──enhances──> D3 (telemetry) for opt-in event capture
D1 (doctor CLI) ──enhances──> D2 (GH issue prefill)
D3 (telemetry) ──conflicts──> AF3 (account system)         [pick install_id_hash, not accounts]
```

### Dependency notes

- **TS5 (README troubleshooting) requires TS6 + TS8 + TS9:** the troubleshooting section is incomplete without uninstall, Windows snippet, and Linux snippet. Bundle these in one README PR.
- **TS11 (Lane E E2E) requires TS10 + TS12:** E2E that doesn't lint the schema or doesn't have a release asset to download is a partial test. Sequence: TS10 → TS12 → TS11.
- **D3 (telemetry) is independent of TS-* but depends on a deploy decision:** umami/openpanel choice + endpoint provisioning. Recommend doing the deploy decision before writing client code.

---

## MVP Definition (Phase 1 finish)

### Launch With (Phase 1 closes when these are done)

The set below maps directly to PROJECT.md Active list + the table-stakes set above. These are the must-haves for the diaspora-Thai friend wedge.

- [ ] TS3 — Architecture-mismatch refusal (Intel Mac silent break)
- [ ] TS4 — Sparkle re-swap detection (`--check` mode)
- [ ] TS5 — README troubleshooting section (top 5 questions)
- [ ] TS6 — Uninstall instructions in README
- [ ] TS7 — README status badge / version flip to APPROVED
- [ ] TS8 — Windows install snippet in README
- [ ] TS9 — Linux install snippet in README (with RANKING LIMITATION callout)
- [ ] TS10 — Schema lint test (D5 PHASE1-PROMPT)
- [ ] TS11 — Lane E E2E for macOS + Windows
- [ ] TS12 — GH Releases asset verification + SHA256 check in install-librime-fork.sh
- [ ] TS2 — Formalized post-install "type sawadee" probe (already partially shipped; close the loop)
- [ ] D3 — Self-hosted opt-in telemetry client (PROJECT.md D2; technically an Active item, treat as table-stakes for Phase 1 finish)

### Add After Validation (Phase 1.5 candidates, gated on Decision Gate signal)

Trigger to build: ≥1 unsolicited bug report or feature request from a non-founder.

- [ ] D1 — `smoodle doctor` self-diagnose CLI
- [ ] D2 — GH issue template prefilled with `doctor` output
- [ ] D4 — README onboarding sentence + 5-second screen recording GIF
- [ ] D5 — Pre-compiled dict `.bin` artifacts in CI
- [ ] D6 — Installer "what just happened?" structured summary
- [ ] D7 — `install.sh --check` mode (overlaps with TS4 implementation)
- [ ] LLM tone-disambiguation plugin (smoodle_llm_translator) — Phase 1.5 explicitly per PROJECT.md D4

### Future Consideration (Phase 2+, gated on commercial Decision Gate)

- All AF1-AF15 anti-features
- Universal macOS dylib (lipo arm64 + x86_64) — actually planned for Phase 1.5 per PROJECT.md Active; included here as a reminder it's not a Phase 1 finish blocker
- Code signing / notarization
- Public-domain / smoodle.app domain
- iOS / Android explorations
- Cloud sync, account systems, payment

---

## Feature Prioritization Matrix

| Feature | User Value | Implementation Cost | Priority |
|---------|-----------|---------------------|----------|
| TS5 README troubleshooting | HIGH (P2 friend can't proceed without it) | LOW | P1 |
| TS6 Uninstall instructions | HIGH (trust signal) | LOW | P1 |
| TS7 Status badge update | MEDIUM (friend trust) | LOW | P1 |
| TS8 Windows install snippet | HIGH (P2 Win wedge) | LOW | P1 |
| TS9 Linux install snippet | MEDIUM (small wedge) | LOW | P1 |
| TS3 Intel-Mac refusal | HIGH (P3 silent break = trust death) | LOW | P1 |
| TS12 Releases asset verification | HIGH (gates all P2 macOS installs) | LOW | P1 |
| TS10 Schema lint | MEDIUM (catches regressions) | LOW | P1 |
| TS11 Lane E E2E | MEDIUM (catches regressions) | MEDIUM | P1 |
| TS4 Sparkle re-swap detection | HIGH (silent ranking degradation) | MEDIUM | P1 |
| TS2 Post-install probe formalization | MEDIUM (UX polish) | LOW | P1 |
| D3 Opt-in telemetry | MEDIUM (sanity-check signal) | MEDIUM | P1 |
| D1 `smoodle doctor` CLI | MEDIUM (reduces friend-bug-report friction) | LOW-MEDIUM | P2 |
| D2 GH issue template prefill | MEDIUM (reduces friction) | LOW | P2 |
| D4 README onboarding GIF | LOW (polish) | LOW | P2 |
| D5 Pre-compiled dict | LOW (60s deploy is acceptable) | MEDIUM | P3 |
| D6 Installer summary | LOW (UX polish) | LOW | P3 |
| D7 `--check` mode | MEDIUM (overlaps TS4) | LOW | P2 |

**Priority key:**
- P1: Phase 1 finish blocker (must ship before declaring Phase 1 closed)
- P2: Phase 1.5 candidate, ship if Decision Gate signal positive
- P3: Phase 2+ / nice-to-have

---

## Competitor Feature Analysis

| Feature | rime/squirrel (upstream) | McBopomofo | rime-cantonese | smoodle Phase 1 |
|---------|--------------------------|------------|----------------|-----------------|
| Onboarding (first-run) | Folk knowledge ("press Ctrl+\\\` to switch"); manual log-out/log-in step | Xcode-build-it-yourself + .pkg installer | YAML-only; user follows generic Rime install docs | Bash-script install + README onboarding sentence (TS5) + post-install probe (TS2) |
| Troubleshooting docs | rime.im/docs separate site | GitHub wiki FAQ | Repo README (focused on schema, not install) | Embedded README troubleshooting section (TS5) — top 5 questions |
| Uninstall | "remove the app from /Library/Input Methods" — folk knowledge | uninstaller bundled in installer | N/A (schema only) | Documented in README troubleshooting (TS6) |
| Telemetry | None | None | None | Opt-in self-hosted umami/openpanel, install_id_hash only (D3) |
| Bug-report flow | GitHub issues, no template | GitHub issues, basic template | GitHub issues, no template | `smoodle doctor` CLI + URL-prefilled GH issue template (D1+D2, Phase 1.5) |
| Self-update / re-swap detection | Sparkle for Squirrel itself | Sparkle for McBopomofo | N/A | `--check` mode (TS4 + D7) |
| Theming | Squirrel handles it | Custom UI (NSPanel) | Schema-side only | Inherits Squirrel/Weasel — anti-feature for smoodle (AF4) |
| Custom dictionary editing | Folk knowledge ("edit YAML, redeploy") | GUI for personal phrases | YAML editing | Folk knowledge in README, anti-feature for GUI (AF1) |

**Key takeaway:** smoodle's differentiation at Phase 1 finish is *better dogfood UX* (post-install probe, troubleshooting section, uninstall, telemetry done right), not new IME features. The Rime ecosystem under-invests in onboarding/troubleshooting docs; smoodle leans into that gap for the diaspora-Thai friend wedge.

---

## Sources

- `~/Dev/my_repos/experiment/smoodle/.planning/PROJECT.md` — canonical Active/Out-of-Scope lists, Decision Gate signals, key decisions
- `~/Dev/my_repos/experiment/smoodle/docs/PHASE1-PROMPT.md` — Phase 1 mission, NOT-in-scope section, Critical Failure Modes
- `~/Dev/my_repos/experiment/smoodle/docs/RESUME.md` — Phase 0 close, wedge narrowing, dylib swap mechanics
- `~/Dev/my_repos/experiment/smoodle/.planning/codebase/CONCERNS.md` — existing UX gaps, README quality gaps, missing critical features, security recommendations
- `~/Dev/my_repos/experiment/smoodle/README.md` — current README state (status drift, missing Win/Linux snippets, no troubleshooting)
- [openvanilla/McBopomofo on GitHub](https://github.com/openvanilla/McBopomofo) — peer indie IME for comparison (developer-focused docs, no published dogfood UX guide)
- [rime/squirrel on GitHub](https://github.com/rime/squirrel) — host-level conventions (`Ctrl+\\\`` switcher, log-out-log-in step, online docs at rime.im/docs)
- [Bdim — Configuring Rime Input Method on macOS](https://blog.bdim.moe/posts/configuring-rime-input-method-on-macos/) — community first-run guide, friction points
- [fernvenue's Blog — Rime on macOS](https://blog.fernvenue.com/archives/rime-on-macos/) — community first-run guide
- [GitHub community discussion #15477 — Pre-populate issue forms via URL](https://github.com/orgs/community/discussions/15477) — confirms D2 is implementable
- [GitHub Docs — Syntax for issue forms](https://docs.github.com/en/communities/using-templates-to-encourage-useful-issues-and-pull-requests/syntax-for-issue-forms) — issue forms reference
- [TelemetryDeck Privacy FAQ](https://telemetrydeck.com/docs/guides/privacy-faq/) — privacy-first telemetry posture (opt-in default OFF, anonymized identifiers)
- [DEVCLASS — Go 1.23 telemetry opt-in after developer feedback](https://devclass.com/2024/08/14/go-1-23-released-with-telemetry-uploaded-to-google-but-opt-in-after-developer-feedback/) — industry precedent for opt-in default
- [Sparkle documentation](https://sparkle-project.org/documentation/) — auto-update framework that Squirrel uses (the Sparkle re-swap problem origin)

---

*Feature research for: small-batch indie IME (Thai phonetic, Rime/librime-based) at the dogfood-ready → share-with-friends milestone — Phase 1 finish*
*Researched: 2026-05-08*
