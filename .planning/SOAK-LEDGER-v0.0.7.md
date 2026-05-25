# Smoodle v0.0.7 Soak Ledger

**Purpose:** track non-founder dogfood recruits through the install →
opt-in → soak → forget-tested → feedback lifecycle so the gate
verdict has auditable evidence to point at (per
`docs/DECISION-GATE-CRITERIA-v0.0.7.md` W2-C6).

**Soak start:** 2026-05-25 13:00 +0700 (DB pristine, bearer auth landed).

**Anonymization rule:** real names live in the founder's address book.
Use opaque IDs `R1..R5` here. Cross-reference is via `install_id_hash`
prefix (last 8 chars only — full hash is reversible to nothing useful
but keep the surface area small).

**Founder hashes:** none (see `.planning/phases/07-decision-gate-close/FOUNDER-HASH.txt`).
Filter rule: anything not in that file's hash list AFTER soak start is a
non-founder candidate.

---

## Ledger

| ID | Pinged | Channel | OS | Bearer issued | Install attempt | hash (last 8) | install_success | forget-tested | Unsolicited feedback | Notes |
|----|--------|---------|----|---------------|------------------|---------------|------------------|----------------|----------------------|-------|
| R1 | — | — | macOS | — | — | — | — | — | — | — |
| R2 | — | — | macOS | — | — | — | — | — | — | — |
| R3 | — | — | macOS | — | — | — | — | — | — | — |
| R4 | — | — | macOS | — | — | — | — | — | — | — |
| R5 | — | — | macOS | — | — | — | — | — | — | — |

### Column legend

- **Pinged:** ISO date the outreach message was sent.
- **Channel:** Telegram / iMessage / email / Discord / in-person.
- **OS:** target host OS (recruit must self-report — telemetry payload's
  `os` field confirms after install).
- **Bearer issued:** ISO date the bearer token was shared. Token is
  shared once per recruit; same token rotates if leaked. (Currently
  all recruits share the single token in `/tmp/umami-deploy/forget_token.txt`
  on the founder machine — issue per-recruit tokens when N > 3.)
- **Install attempt:** ISO date the recruit ran `bash scripts/install.sh`
  (their report or first telemetry event timestamp).
- **hash (last 8):** last 8 hex chars of the recruit's `install_id_hash`
  (sufficient for joining ledger row to umami DB rows; 32 bits of
  attribution is plenty at N ≤ 5).
- **install_success:** Y if telemetry recorded an `install_success`
  event for the recruit's hash; N if `install_failed`; — if neither
  arrived. Source: umami dashboard "smoodle" website OR raw SQL
  (see `04-telemetry/VERIFICATION.md` filter rule).
- **forget-tested:** Y if recruit ran `bash scripts/lib/telemetry-forget.sh`
  AND the events disappeared from DB. N if recruit declined / failed.
- **Unsolicited feedback:** any text the recruit volunteered — bug,
  praise, confusion. Copy-paste verbatim; do NOT paraphrase.
- **Notes:** anything else — IME they switched FROM, Thai input habits,
  reason they stopped using smoodle (if applicable).

### Gate-close arithmetic

When ≥3 recruits have a final `install_success` value (Y or N):

```
install_success_rate = count(rows with install_success=Y)
                     / count(rows with install_success in {Y,N})
```

Verdict per `docs/DECISION-GATE-CRITERIA-v0.0.7.md`:

- `ship-publicly-ready`: rate ≥ 80%, ≥3 non-founder, ≥2 OSes (so far
  macOS only — promotes to "ship for macOS, defer Windows again" if
  W1 isn't also green by then)
- `stay-in-dogfood`: rate < 80%, OR any P0 unsolicited feedback,
  OR rows all blank (N=0)
- `inconclusive`: 1 ≤ N ≤ 2

---

## Outreach pool (founder's notes — names live here, not in ledger)

> Free-text scratch space for the founder. Fill before pinging so the
> recipient → R-ID mapping is reproducible if needed for follow-up.
> Recipients themselves never see this section.

- R1 → _(name + handle here)_
- R2 → _(name + handle here)_
- R3 → _(name + handle here)_
- R4 → _(name + handle here)_
- R5 → _(name + handle here)_

---

*Ledger opened: 2026-05-25 13:21 +0700 (post bearer-auth landing).*
*Filled by founder as recruits respond.*
