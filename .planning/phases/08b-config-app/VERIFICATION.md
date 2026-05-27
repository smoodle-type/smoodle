# 08b-config-app — VERIFICATION

Living evidence log for the v0.0.8b gate. Update as each criterion
moves PENDING → PASS or PENDING → FAIL.

**Pre-registration anchor:** `docs/DECISION-GATE-CRITERIA-v0.0.8.md`
commit `8f4439c` (2026-05-26 13:36:24 +0700). All v0.0.8b green
surfaces post-date this commit.

---

## Criteria

### 8b-C1 — Config.app in v0.0.8b DMG

Smoodle-v0.0.8b-universal.dmg, when mounted, contains both
`Smoodle.app` and `Smoodle Config.app`. Both are universal
(arm64+x86_64).

- [ ] **PENDING** — set after Task 18 release.yml green AND founder
  smoke confirms drag-install works for both apps.

Evidence (fill on PASS):
- gh release URL:
- Mount output (`hdiutil attach …`):
- lipo -archs on both .app binaries:

---

### 8b-C2 — ≥1 recruit auto-updated via Sparkle from v0.0.8a/a.1 → v0.0.8b

At least one non-founder recruit row in `.planning/SOAK-LEDGER-v0.0.7.md`
has `auto-updated-to-0.0.8b=Y`.

- [ ] **PENDING** — needs Task 20 step 4.

---

### 8b-C3 — Words + deploy round-trip

Founder smoke: add `ลีเอ็กซ์` via Config Words tab → Smoodle deploy
fires automatically (toast time < 10s) → typing `lex` in Notes.app
produces `ลีเอ็กซ์` candidate.

- [ ] **PENDING** — row 2, 3, 4 of `tests/manual/v0.0.8b-e2e.md`.

---

### 8b-C4 — Status accurate

Status tab shows: running=true while Smoodle.app process alive;
running=false within 5s of `pkill -x Smoodle`; version matches
Smoodle.app's CFBundleShortVersionString; dict_counts.base > 4000;
schema_compile_log shows last 5 lines of `~/Library/Rime/build/deploy.log`.

- [ ] **PENDING** — rows 5, 6, 7, 8, 15 of e2e checklist.

---

### 8b-C5 — Settings edits persist

candidate_count change persists to `~/Library/Rime/default.custom.yaml`,
Notes.app surfaces the new count after deploy. Reset to Defaults
restores schema files but preserves user.dict.yaml.

- [ ] **PENDING** — rows 11, 12, 14 of e2e checklist.

---

### 8b-C6 — GUI forget matches CLI forget

Config Status tab "Delete my data" button deletes the same DB rows
as `scripts/lib/telemetry-forget.sh`. Verify by:
1. Toggle telemetry ON → trigger an event via `scripts/lib/telemetry.sh`.
2. Confirm row in umami DB (via dxc.0dl.me SQL).
3. Click GUI forget → confirm row gone (same SQL).
4. Re-trigger event, then run `bash scripts/lib/telemetry-forget.sh`
   → confirm equivalent deletion.

- [ ] **PENDING** — manual + DB cross-check.

---

### 8b-C7 — ≥3 recruits opened Config.app

`Config-opened=Y` count in SOAK-LEDGER ≥ 3.

- [ ] **PENDING** — needs Task 20 step 5.

---

## Pass/fail summary

| ID | Status | Evidence link |
|----|--------|---------------|
| 8b-C1 | PENDING | — |
| 8b-C2 | PENDING | — |
| 8b-C3 | PENDING | — |
| 8b-C4 | PENDING | — |
| 8b-C5 | PENDING | — |
| 8b-C6 | PENDING | — |
| 8b-C7 | PENDING | — |

All PASS → tag `v0.0.8b-closed` in smoodle repo + commit milestone
close. Verdict (`stay-in-dogfood` / `narrow-public` / `kill`)
documented in `.planning/PROJECT.md`.
