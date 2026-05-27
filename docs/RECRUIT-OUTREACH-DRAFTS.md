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
> drag-install (latest DMG — grab `Smoodle-v*.dmg`):
> https://github.com/smoodle-type/smoodle-app/releases/latest
>
> open the DMG, drag Smoodle.app onto the "Input Methods" shortcut
> inside it (macOS will ask for your password to authorize the
> /Library/Input Methods install). first launch: right-click → Open
> (Gatekeeper warns it's unsigned — that's expected). then System
> Settings → Keyboard → Input Sources → + → Thai → Smoodle. type
> `sawadee` to test.
>
> if anything weird: System Settings → Keyboard → Input Sources → -
> (remove Smoodle), then `sudo rm -rf "/Library/Input Methods/Smoodle.app"`,
> message me with what happened. opt-in telemetry is OFF by
> default — flip it on by hand-editing `~/.smoodle/telemetry-on` +
> `echo "<BEARER_TOKEN>" > ~/.smoodle/forget_token` if you want to be
> able to delete your data later.

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
> Install (≈2 minutes — drag and click):
>
> 1. Download the DMG (grab `Smoodle-v*.dmg` — the most recent one):
>    https://github.com/smoodle-type/smoodle-app/releases/latest
> 2. Open the DMG. Drag Smoodle.app onto the "Input Methods" folder
>    shortcut shown inside the DMG. macOS will ask for your password
>    — that's authorizing the install into /Library/Input Methods.
> 3. First launch: right-click Smoodle.app → Open → Open. macOS will
>    warn it's unsigned — that's expected for the v0.0.8 dogfood
>    build (Apple notarization comes in v0.1.0).
> 4. System Settings → Keyboard → Input Sources → + → Thai → Smoodle.
> 5. Switch to Smoodle from the menubar input picker. Type `sawadee`.
>
> Uninstall (any time):
>
>     # System Settings → Keyboard → Input Sources → select Smoodle → "−"
>     sudo rm -rf "/Library/Input Methods/Smoodle.app"
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

> Hey @<name> — built a Latin-spelling → Thai IME for macOS,
> dogfooding with 5 friends. Wanna be one of them?
> https://github.com/smoodle-type/smoodle-app/releases/latest (grab `Smoodle-v*.dmg`)
> — open DMG, drag Smoodle.app onto the "Input Methods" shortcut
> inside (macOS prompts for password — installs into /Library/Input
> Methods), right-click → Open (Gatekeeper warning is expected,
> unsigned). Then Settings → Keyboard → Input Sources → + → Thai →
> Smoodle. DM me if anything blows up. Opt-in
> telemetry token if you want it: `<BEARER_TOKEN>`

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

## Template D — v0.0.8b follow-up (Sparkle has delivered Config)

For recruits already on v0.0.8a / v0.0.8a.1 after Sparkle auto-updates
them to v0.0.8b. Send a day or two after the v0.0.8b tag ships so the
24h check has had a chance to fire.

> hey! smoodle update landed — you should've seen a dialog
> "Smoodle 0.0.8b available, install?" If not, click menubar S
> → Check for Updates.
>
> v0.0.8b adds Smoodle Config.app — a settings GUI. The auto-update
> only refreshes the IME itself, NOT the Config app. To get Config:
> grab the fresh DMG, drag Smoodle Config.app to /Applications.
> https://github.com/smoodle-type/smoodle-app/releases/latest
>
> Then click menubar S → "Open Smoodle Config…" — adds your own Thai
> words, see status, change candidate count, opt-in/out telemetry.
> lmk what's broken.

**When to use:** day-2 or day-3 after Sparkle auto-update, by same
medium you used initially (Telegram if Template A, email if B, etc.).

After they reply, fill the v0.0.8b columns in SOAK-LEDGER-v0.0.7.md:
`auto-updated-to-0.0.8b`, `Config-opened`, `Words-added count`,
`Settings-changed`, `forget-tested-via-GUI`.

---

*Drafts created: 2026-05-25 13:25 +0700 (post bearer-auth landing).*
*Template D added: 2026-05-27 (v0.0.8b ship).*
*Refine after sending the first one — record what tone actually worked.*
