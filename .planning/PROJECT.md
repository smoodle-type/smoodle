# Smoodle

## What This Is

A Pinyin-style phonetic input method for typing Thai. Type `sawadee` → see candidate `สวัสดี` → press space to commit. Ships as a Rime schema + a patched librime fork on top of the existing Rime hosts (Squirrel on macOS, Weasel on Windows, fcitx5/ibus-rime on Linux).

This is a builder/learning project. The technical challenge — Rime schema authoring + librime patching + a future LLM-as-translator plugin — is the explicit draw, not shipping speed.

## Core Value

A Thai phonetic IME good enough that the founder (and a small diaspora-Thai dogfood circle) reaches for it daily on macOS and Windows. **If everything else fails, the v0.0.6 schema typing `sawadee → สวัสดี` reliably on a fresh user's machine must work.**

## Requirements

### Validated

<!-- Shipped and confirmed valuable. -->

- ✓ **Phonetic Thai schema** — v0.0.6, 14893 Thai words / 28239 entries, 100% coverage of TNC freq≥50 tail, TNC-frequency-weighted ranking. (`schema/thai_phonetic.{schema,dict}.yaml`, `schema/default.custom.yaml`)
- ✓ **Path A architecture** (algebra-thin dict) — speller.algebra rules collapse phonemic equivalence (kh~k, ph~p, vowel length, p~b/t~d at end) so the dict carries 1-3 variants per word instead of 4-5. Future-proof for v0.2 LLM plugin.
- ✓ **librime peek-sort patch** — fixes upstream `DictEntryIterator::Peek` first-call sort bug. Lives as commit `a75b6a48` on `smoodle-type/librime` branch `1.16.0-smoodle`, tagged `1.16.0-smoodle.1`.
- ✓ **macOS schema-only installer** — `scripts/install.sh` copies YAMLs to `~/Library/Rime/`, kill+restarts Squirrel, prompts for manual Deploy on timeout.
- ✓ **macOS librime-fork swap installer** — `scripts/install-librime-fork.sh` clones tag, builds, sudo-swaps `Squirrel.app/Contents/Frameworks/librime.1.dylib`. Phase 1 dogfood is arm64-only.
- ✓ **macOS DMG bundle** — `scripts/build-macos-dmg.sh` produces unsigned drag-to-install DMG.
- ✓ **Windows installer scripts** — `scripts/install-windows.ps1` + `scripts/install-librime-fork.ps1`, verified end-to-end on the th-dc dockur/windows test bed (Win 11, Weasel 0.17.4): `sawatd → สวัสดี` candidate #1.
- ✓ **Linux schema-only installer** — `scripts/install-linux.sh` (option 3: accept unpatched system librime, document the ranking limitation), pgrep-based fcitx5/ibus detection. GHA E2E green on ubuntu-latest/ibus.
- ✓ **Smoodle.app fork (sister repo `smoodle-type/smoodle-app`)** — Squirrel-derived macOS IME app, universal arm64+x86_64 binary, InfoPlist.xcstrings localization showing "Smoodle Thai" in menu bar. Tag `v0.1.0`.
- ✓ **Test suite** — 56 passing / 3 skipped (Lane E E2E gaps). `tests/test_installers.py` covers shape + idempotency + timeout + IM detection across all four installers.
- ✓ **Engine-mode test fixture** — 56 entries (35 direct + 21 algebra-tagged), drives librime via `rime_api_console`.
- ✓ **librime fork CI matrix** — `smoodle-build.yml` green across linux gcc/clang + macos-15 + macos-15-intel + windows msvc-x64/x86/clang/mingw (8/8 jobs).
- ✓ **Phase 0 closed 2026-05-06** — wedge narrowed to "founder + diaspora-Thai friends as they surface." Status flipped APPROVED-PENDING-PHASE-0 → APPROVED. Lane B + C unblocked.

### Active

<!-- Phase 1 finish — remaining work to declare Phase 1 done. -->

- [ ] **Lane E (CI + E2E for macOS):** `tests/test_install_e2e_mac.sh` + `.github/workflows/install-mac-e2e.yml`. Currently only `install-linux-e2e.yml` exists. Catches DMG/install regressions automatically.
- [ ] **Lane E (CI + E2E for Windows):** `tests/test_install_e2e_win.ps1` + `.github/workflows/install-win-e2e.yml`. Manual smoke green on th-dc but not regression-protected.
- [ ] **Schema lint test (D5):** `tests/test_schema_lint.py` validates `thai_phonetic.{schema,dict}.yaml` + `default.custom.yaml` (typos, malformed weights, regex syntax in algebra rules, `import_preset` references).
- [ ] **Telemetry client (D2):** opt-in, default OFF, no PII, install_id_hash only. Self-hosted umami or openpanel POST endpoint on user's existing infra.
- [ ] **macOS Releases asset verification:** confirm `librime-1.16.0-smoodle.1-macOS-universal.dylib` exists at the GitHub Releases URL (currently a manual promotion step). Add SHA256 verification in `install-librime-fork.sh`.
- [ ] **Universal macOS dylib:** lipo arm64 + x86_64. Currently arm64-only — silent failure on Intel Macs.
- [ ] **README.md hardening:** flip status to APPROVED, add Windows + Linux install snippets, add troubleshooting section, update repo layout to include `infra/`, `vendor/windows/`, `docs/LANE-*`.
- [ ] **LoneExile/* doc references migrated to smoodle-type/*:** README, RESUME, LANE-B-WINDOWS, LANE-B-HARDENING-PROMPT, LANE-C-E2E-PROMPT, CI-REFACTOR-PROMPT.
- [ ] **macOS Sparkle re-swap detection:** Squirrel auto-update overwrites the patched dylib silently. Add hash-drift detection (LaunchAgent or post-install verifier).
- [ ] **install.sh schema timestamp touch:** mirror Windows' `LastWriteTime = now` to force Squirrel recompile after rsync/cp preserves stale mtimes.
- [ ] **Decision Gate close:** review qualitative signals (founder daily use ✓; ≥1 unsolicited bug report or feature request from a non-founder during Phase 1.5) and explicitly close Phase 1 with "ship-publicly-ready" or "stay-in-dogfood" verdict.

### Out of Scope

<!-- Explicitly deferred — Phase 1.5, Phase 2, or never. -->

- **LLM tone-disambiguation translator plugin** — deferred to Phase 1.5. Dict's 100% TNC freq≥50 coverage is enough surface to test the wedge cleanly without LLM. (Per design doc D4.)
- **iOS / iPadOS / Android installers** — Phase 2. Blocked on TODOS #2 (iOS BT-keyboard interception spike).
- **Code-signing certificate procurement** — pre-public-ship gate. Phase 1 ships unsigned with documented Gatekeeper warning.
- **Apple notarization** — pre-public-ship gate.
- **Windows MSI / WiX bundle** — pre-public-ship gate. Phase 1 ships zip+scripts.
- **`smoodle.app` domain registration** — pre-public-ship gate.
- **Mac App Store / Microsoft Store listings** — pre-public-ship gate.
- **Auto-update infrastructure (Sparkle, Squirrel.Windows)** — Phase 2. Phase 1 manual-download is fine for the dogfood circle.
- **Cross-device dict sync** — Phase 2 or never. Wedge audience is tiny; YAML files in iCloud Drive is the workaround.
- **Stripe / payment integration** — Phase 2 commercial decision; gated on Decision Gate signals.
- **Internationalized installer copy** — Phase 1 ships English-only. Audience is bilingual.
- **fcitx5 path Linux E2E test** — `install-linux-e2e.yml` covers ibus-rime only. Adding fcitx5-rime apt package + dest-dir variant is low-priority (smaller wedge of smaller wedge).
- **Upstream librime PR for peek-sort fix** — TODOS #1, deferred 2026-05-06. Fork absorbs the patch indefinitely. Optional community goodwill, not a Phase 1 gate.
- **Forked-rime distro packages on Linux** (`.deb`, AUR PKGBUILD with patched libRime.so) — option 1 in LANE-C-LINUX.md. Audience too small to justify per-distro packaging maintenance burden.
- **Code generation pipeline rework** — `crs.0dl.me` Anthropic relay is a soft dependency for dict regen but generated TSVs (`generated-tnc{,-full}.tsv`) are committed for offline replay.

## Context

**Three-repo monorepo (within `smoodle-type` org):**
- `smoodle-type/smoodle` — schema YAMLs, installer scripts, tests, docs (this repo).
- `smoodle-type/smoodle-app` — macOS IME app (Squirrel fork, universal binary, v0.1.0).
- `smoodle-type/librime` — librime fork carrying the peek-sort patch as a real commit. Tag `1.16.0-smoodle.1`. CI matrix green.

**Phase 0 closed 2026-05-06** without surfacing a non-founder Thai learner. Wedge narrowed from "Thai language learners (broad segment)" → "founder + diaspora-Thai friends as they surface." Decision Gate signals re-tuned to qualitative (≥1 unsolicited bug report from a non-founder during Phase 1.5; ≥1 named non-founder converts to "uses this daily" voluntarily). Quantitative scaling explicitly deferred.

**Critical caveats** (DO NOT relitigate without strong reason):
- Foundation is **Rime/Squirrel + librime fork**, not a McBopomofo Swift IMK fork.
- librime version pinned at **1.16.0** (matches Squirrel 1.1.2 / Weasel 0.17.4).
- Multi-syllable Thai uses **continuous Latin** (`khobkhun`, not `khob khun`) — Rime's `table_translator` treats space as commit delimiter.
- Algebra rules replace **all** occurrences in one pass (`boost::regex_replace`), not first-match-only.
- Rime weights are **log-frequencies** at compile time — store RAW counts in dict YAML.
- DictEntryIterator first-Peek bug: chunks are pushed in syllable-id order; alphabetically-earlier syllable wins #1 unless patched. macOS+Windows ship the patch via fork; Linux accepts the limitation.

**Existing parallel planning system** in `~/.gstack/projects/smoodle/` (gstack design docs, eng-review test plan). The GSD plan in `.planning/` does NOT replace those; it formalizes the **Phase 1 finish** lane in GSD vocabulary so plan-eng-review and Lane execution can run via GSD agents going forward.

## Constraints

- **Tech stack — pinned:** librime 1.16.0 (matches Squirrel 1.1.2 + Weasel 0.17.4). Rime schema YAML + Lua. Bash + PowerShell installers. Python 3 unittest suite. — Rime/host versions move slowly; avoid version-bump churn during Phase 1.
- **Tech stack — language additions:** None during Phase 1 finish. v0.2 will add C++ librime plugin + llama.cpp; out of scope here.
- **Timeline — solo, ~3 months Phase 1 elapsed already:** Phase 1 was kicked off 2026-05-05; ~3 days of wall-time has produced Lane A/B/C/D shipping. Phase 1 finish targets ≤2 weeks of remaining work for Lane E + telemetry + README/docs cleanup. — Phase 0 close already pushed the timeline budget right; don't over-invest before Decision Gate.
- **Budget — $0 except domain + cert:** Phase 1 cost is zero. Pre-public-ship gate spends ~$200 on Apple Developer Program + Authenticode cert. Self-hosted telemetry runs on user's existing infra. — Wedge audience too small to justify SaaS spend.
- **Compatibility — macOS 14+ Apple Silicon (Phase 1 dogfood):** Intel Macs explicitly broken until universal dylib lands. Win 11 verified; Win 10 not in scope. Ubuntu LTS + Arch (ibus + fcitx5) on Linux. — Founder hardware is Apple Silicon; Intel coverage waits for Intel-Mac dogfood user.
- **Performance — Rime deploy ≤60s on commodity hardware:** First Deploy compiles 1.2 MB / 28239-entry dict to marisa-trie + leveldb. Windows installer raised timeout from 10s → 60s after the dict 5×-expansion. — If users report >60s, split dict into freq tiers or ship pre-compiled `.bin` artifacts.
- **Security — sudo + admin elevation gates:** macOS librime swap + Windows DLL swap require sudo / RunAs. Backup-before-overwrite is mandatory. — Adding SHA256 verification + Authenticode signature checks is in scope; pinning by SHA not tag is in scope.
- **Distribution — GitHub Releases only (Phase 1):** No CDN, no Homebrew tap, no winget submission, no AUR PKGBUILD. — Wedge audience is small enough that GH Releases is fine.
- **License separation — Squirrel/Weasel are GPLv3, smoodle is MIT:** Don't bundle Squirrel/Weasel into installers. User obtains hosts via `brew install --cask squirrel-app` / `winget install Rime.Weasel`. — Bundling breaks the license model.

## Key Decisions

| Decision | Rationale | Outcome |
|----------|-----------|---------|
| **D1 — Linux IM detection via `pgrep`** | Hybrid setups (fcitx5 installed + ibus running, or vice versa) defeat `command -v` detection | ✓ Good — `install-linux.sh` ships, GHA E2E green |
| **D2 — Telemetry: self-hosted umami/openpanel, opt-in, default OFF, install_id_hash only** | No PII risk; quantitative dogfood signal without third-party tracking | — Pending — client not yet implemented |
| **D3 — Auto-deploy: hybrid CLI invocation with 10s timeout + manual fallback** | Auto-deploy hangs indefinitely if host isn't running; timeout + clear manual instructions covers both paths | ✓ Good — fallback path verified across all 3 OS installers |
| **D4 — LLM plugin moved to Phase 1.5** | Dict's 100% TNC freq≥50 coverage is enough surface to test the wedge without LLM tone disambiguation | ✓ Good — Phase 1 unblocked from Phase 2-shaped scope |
| **D5 — Test scope: boil-the-lake (full unit + E2E per OS, schema lint in CI)** | Solo project; regressions surface fast in dogfood; cheap to test, expensive to debug post-ship | — Pending — Lane E E2E for macOS+Windows + schema lint still missing |
| **OQ3+OQ4 — Path A schema + LoneExile (now smoodle-type) librime fork** | Best-practice Rime architecture; future-proof for LLM plugin; dict stays compact; fork absorbs upstream patch indefinitely | ✓ Good — fork CI matrix green; dogfood live |
| **Phase 0 wedge narrowing 2026-05-06** | Phase 0 protocol didn't surface a non-founder Thai learner; founder dogfood + diaspora friends is a valid smaller wedge | ✓ Good — Lane B + C unblocked, scope compressed |
| **Linux: option 3 (accept unpatched system librime, document limitation)** | Forked-rime distro packages = high effort, tiny audience; LD_PRELOAD = brittle/unprofessional; accept = honest | ✓ Good — `install-linux.sh` ships with explicit RANKING LIMITATION block |
| **Vendor `rime.dll` directly in repo (BSD-3)** | gh CLI + 7-Zip bootstrap path hangs in non-interactive SSH sessions | ✓ Good — `vendor/windows/rime.dll` committed, fallback path retired |
| **Three-repo split with smoodle-type org** | Schema/installer concerns separate from app concerns separate from engine concerns; transferable later | ✓ Good — migration completed 2026-05-08 |

## Evolution

This document evolves at phase transitions and milestone boundaries.

**After each phase transition** (via `/gsd-transition`):
1. Requirements invalidated? → Move to Out of Scope with reason
2. Requirements validated? → Move to Validated with phase reference
3. New requirements emerged? → Add to Active
4. Decisions to log? → Add to Key Decisions
5. "What This Is" still accurate? → Update if drifted

**After each milestone** (via `/gsd-complete-milestone`):
1. Full review of all sections
2. Core Value check — still the right priority?
3. Audit Out of Scope — reasons still valid?
4. Update Context with current state

---
*Last updated: 2026-05-08 after initialization (imported from PHASE1-PROMPT.md + RESUME.md + TODOS.md + codebase map)*
