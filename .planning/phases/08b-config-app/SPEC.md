# 08b-config-app — SPEC pointer

Authoritative design: `docs/superpowers/specs/2026-05-26-v0.0.8-installer-ux-design.md`
Authoritative plan: `docs/superpowers/plans/2026-05-26-v0.0.8b-config-app.md`

**Goal:** ship Smoodle Config.app (Tauri 2 + Svelte 5, universal arm64+x86_64)
inside the v0.0.8b DMG, delivered to v0.0.8a/v0.0.8a.1 installs via Sparkle.

**Surface:** three tabs — Words (add/delete user-dict entries), Status
(running check, version, dict counts, telemetry toggle + forget),
Settings (candidate count, schema list, open Rime folder, reset to
defaults). Auto-deploy-on-save toggle (default ON) re-invokes Squirrel
deploy via osascript Apple Event after every mutation.

**Two repos:** schema/installer/config-app sources live in `smoodle/`
(this repo, at `config-app/`). DMG bundling + menubar shim activation
live in sibling `smoodle-app/`. Schema submodule pin advanced to
`v0.0.8b-schema` (content unchanged from v0.0.8a-schema).

See VERIFICATION.md for the 7-criterion gate (8b-C1..C7) and current
status.
