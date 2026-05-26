# Phase 08a DMG + Sparkle — VERIFICATION

**Phase:** 08a (Lane I — installer-UX, DMG + Sparkle)
**Milestone:** v0.0.8-installer-ux
**Pre-registration anchor:** `docs/DECISION-GATE-CRITERIA-v0.0.8.md` commit `8f4439c` (2026-05-26 13:36:24 +0700)
**Started:** 2026-05-26
**Closed:** _(pending — needs 2+ non-founder install events per 8a-C5)_

## 8a-C1 — DMG published to gh releases with EdDSA sig
- [x] **PASS** — 2026-05-26: `gh release view v0.0.8a --repo
  smoodle-type/smoodle-app --json assets` shows
  `Smoodle-v0.0.8a.dmg` (7,310,848 bytes) + `Smoodle-v0.0.8a.dmg.sig`
  (89 bytes). Downloaded both via gh CLI to /tmp; re-ran
  `package/test-dmg.sh` against the downloaded DMG: ALL 6 CHECKS PASS
  including EdDSA sig presence.

## 8a-C2 — appcast.xml on gh-pages contains v0.0.8a entry
- [x] **PASS** — 2026-05-26: fetched
  `https://smoodle-type.github.io/smoodle-app/appcast.xml`; contains
  `<item><title>v0.0.8a</title>` with non-empty
  `sparkle:edSignature="gj1vzDBjOaXcoxuB4EZtA9U5ECSzVE8hjAL8YhaaEoVbhZBHQX+y38P1Kv4Jge6TmQfX47UFWhNaDSyU732vCw=="`
  and the DMG enclosure URL. NOTE: first CI run produced empty sig
  due to a `::add-mask::` GHA bug; sig recovered from the `.sig`
  asset and patched into appcast.xml; release.yml fixed for future
  tags (see smoodle-app commit "ci(release): drop ::add-mask:: on
  EdDSA sig").

## 8a-C3 — Founder smoke-test passed
- [x] **PASS** — 2026-05-26: founder built locally
  (`dist/Smoodle-v0.1.0-12-g1dea6cb-dirty.dmg`), drag-installed to
  `/Library/Input Methods/Smoodle.app`, allowed via Gatekeeper,
  registered "Smoodle" input source, typed `sawadee` → สวัสดี and
  other test words. Menubar shows disabled "Open Smoodle Config…"
  with correct tooltip. Manual "Check for updates..." returns
  "You're up to date" (appcast empty pre-tag-push).

## 8a-C4 — librime patch in shipped binary
- [x] **PASS** — symbol-layout fingerprint check via
  `package/test-dmg.sh` confirms bundled `librime.1.dylib` matches
  `smoodle-type/librime@1.16.0-smoodle.1` (Peek at offset `0x93948`,
  next symbol at `0x1a37d0`; upstream librime has different offsets).
  The original plan's `grep -c sorted_initial_` check was wrong —
  private member vars don't appear in release-stripped symbol tables.
  Real verification is symbol layout + behavioral test (step 5/6 of
  founder smoke above).

## 8a-C5 — ≥2 non-founder recruits install + report typing works
- [ ] PENDING — see `.planning/SOAK-LEDGER-v0.0.7.md` (v0.0.8a install column)

## 8a-C6 — Sparkle synthetic update test green
- [x] **PASS** — 2026-05-26: `bash tests/sparkle-update-test.sh
  dist/Smoodle-*.dmg` exits 0 with "ALL SPARKLE CHECKS PASS"
  (signature verifies against Keychain key, appcast XML well-formed,
  sparkle:version parses).

---

## Build-chain deviation log (informational, not a criterion)

Discovered during Task 13 local build — committed as part of
`smoodle-app` commit "build: fix smoodle-app build chain + bump to
0.0.8a":

1. **macOS BSD sed bug** in `package/add_data_files`: multi-line `a\`
   form errors with "can't read :" on current macOS (Sequoia/Tahoe).
   Patched to use awk equivalent.
2. **Upstream librime override**: `action-install.sh`'s
   `copy-rime-binaries` step overwrites `lib/librime.1.dylib` with
   upstream Rime 1.16.1. Added force `make download-librime`
   afterwards to re-fetch the smoodle release.
3. **SQUIRREL_BUNDLED_RECIPES default**: was unset → plum installed
   all default packages (bopomofo/cangjie/luna-pinyin/…). Default to
   `prelude essay` (the minimum smoodle needs).
4. **test-dmg.sh `sorted_initial_` check**: private member, not a
   symbol. Replaced with Peek-offset symbol-layout fingerprint.

## Known v0.0.8a limitation

`default.custom.yaml` is not in `Squirrel.xcodeproj/project.pbxproj`
→ not bundled in `.app` → DMG installs need a manual one-time step
to wire smoodle as the default schema. Founder smoke worked because
the founder's `~/Library/Rime/default.custom.yaml` was already set
from prior `install.sh` runs. Fresh-machine recruits will need to
either run the legacy `install.sh` once OR hand-create
`~/Library/Rime/default.custom.yaml` with:

```yaml
patch:
  schema_list:
    - schema: thai_phonetic
```

Documented as known issue; v0.0.8b's Config app makes this a
one-click "Set as default Thai input" button. If recruit reports
indicate this is a blocker (≥2 N rows in soak ledger), consider
patching `project.pbxproj` to bundle `default.custom.yaml` before
v0.0.8b ships.

---

*Skeleton created post local-smoke 2026-05-26; recruit + CI rows fill as those land.*
