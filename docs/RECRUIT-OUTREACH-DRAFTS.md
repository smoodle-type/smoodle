# Recruit Outreach Drafts — v0.0.7 macOS Soak

Three tones, all for diaspora-Thai friends with macOS machines. Pick one
per recipient. **Before sending: paste the shared bearer token from
`/tmp/umami-deploy/forget_token.txt` into the `<BEARER_TOKEN>`
placeholder.** Each draft also includes the install one-liner.

Goal: get the recipient to (a) install smoodle, (b) type Thai for a
week, (c) optionally `forget` their telemetry, (d) tell you if anything
broke. Don't pitch features — pitch friction relief.

---

## Template A — Telegram / iMessage (casual, ≤6 lines)

> hey! built a thing — type Thai by spelling it in latin (like
> "sawadee" → สวัสดี). want to dogfood it on your mac?
>
> 5-min install:
>
> ```
> git clone https://github.com/smoodle-type/smoodle && cd smoodle
> bash scripts/install.sh
> ```
>
> if anything goes weird, hit me back. one-liner to wipe everything:
> `bash scripts/install.sh --uninstall`. opt-in telemetry is OFF by
> default — flip it on with `SMOODLE_TELEMETRY=1` before install +
> `mkdir -p ~/.smoodle && echo "<BEARER_TOKEN>" > ~/.smoodle/forget_token`
> if you want to be able to delete your data later.

**When to use:** close friend, fast medium, low ceremony.

---

## Template B — Email (formal-ish, with rationale)

> Subject: smoodle dogfood — quick Thai-input ask
>
> Hi <name>,
>
> I built a Thai phonetic input method for macOS — you type `sawadee`
> in Latin and it commits `สวัสดี`. It runs on top of Rime (the same
> engine as Squirrel) so it sits alongside your existing IME, doesn't
> replace anything.
>
> I'm trying to figure out if it's only-works-on-my-machine or actually
> ready for friends. The single most useful thing you could do for me
> is install it, type Thai for ~5 minutes over the next week, and
> message me if anything is weird.
>
> Install (≈5 minutes including librime download):
>
>     git clone https://github.com/smoodle-type/smoodle
>     cd smoodle
>     bash scripts/install.sh
>
> Uninstall (any time):
>
>     bash scripts/install.sh --uninstall
>
> There's an opt-in, no-PII telemetry pipe (4 fields: OS, version,
> success/fail, a random per-install hash) so I can tell whether the
> installer worked. It's OFF by default. If you want to enable it AND
> retain the right to delete your data later:
>
>     mkdir -p ~/.smoodle
>     touch ~/.smoodle/telemetry-on
>     echo "<BEARER_TOKEN>" > ~/.smoodle/forget_token
>     # then re-run the install one-liner
>
>     # ...later, if you change your mind:
>     bash scripts/lib/telemetry-forget.sh
>
> Full privacy detail in the README's "Telemetry & Privacy" section.
>
> Thanks for considering. Even "it crashed at step 2" is enormously
> useful — silence is the only unhelpful answer.
>
> — Apinant

**When to use:** professional contact, someone who'd appreciate context
before installing arbitrary scripts.

---

## Template C — Discord / Slack one-liner

> Hey @<name> — built a Latin-spelling → Thai IME for macOS, dogfooding
> with 5 friends. Wanna be one of them? `git clone
> https://github.com/smoodle-type/smoodle && cd smoodle && bash
> scripts/install.sh` — uninstall is `bash scripts/install.sh
> --uninstall`. DM me if anything blows up. Opt-in telemetry token if
> you want it: `<BEARER_TOKEN>`

**When to use:** loose tie, async channel, copy-paste fast.

---

## What to do AFTER they install

1. **Note their R-ID** in `.planning/SOAK-LEDGER-v0.0.7.md` (R1..R5,
   first available row).
2. **Wait 24–72h** then check umami dashboard at
   `https://telemetry.0dl.me` for new `install_started` /
   `install_success` events. Cross-reference `install_id_hash` last
   8 chars to identify which recruit (they may not be ordered by R-ID).
3. **Fill ledger row** with date, hash-prefix, success Y/N.
4. **At day 7:** ping them. "still working? anything weird?" → log
   verbatim to ledger.
5. **At day 7+:** ask them to test `bash scripts/lib/telemetry-forget.sh`
   if they opted into telemetry. Verify their hash disappears from
   umami (SQL in `04-telemetry/VERIFICATION.md`). Set `forget-tested=Y`.
6. **At day 14 or earlier if 3+ rows are final:** evaluate per the gate
   criteria.

## Token handling

The bearer token in `/tmp/umami-deploy/forget_token.txt` is a single
shared secret for the v0.0.7 soak. If it leaks (recruit posts it
publicly, laptop stolen, etc.):

1. Generate a new token: `openssl rand -hex 32`
2. Update dxc `.env`: `FORGET_BEARER_TOKEN=<new>`
3. Recreate forget-api: `ssh root@dxc.0dl.me 'cd /opt/umami && docker compose up -d --build forget-api'`
4. Message all live recruits with the new token + ask them to overwrite
   `~/.smoodle/forget_token`.

When N grows past 3, switch to per-recruit tokens (one bearer per R-ID)
to localize blast radius. Tracked as future v0.0.7 W2 hardening.

---

*Drafts created: 2026-05-25 13:25 +0700 (post bearer-auth landing).*
*Refine after sending the first one — record what tone actually worked.*
