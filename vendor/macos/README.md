# vendor/macos/

Stub sidecar SHA-256 hashes for librime artifacts published at
smoodle-type/librime. Phase 2 / Plan 02-02 commits these as a fallback for
`scripts/install-librime-fork.sh`'s SHA verify block when the live
`${RELEASE_URL}.sha256` sidecar is absent (Phase 5 / HARDEN-04 ships the live
sidecar emission in the librime fork's release.yml).

## Files

- `librime.1.dylib.sha256` — SHA-256 of
  `librime-1.16.0-smoodle.1-macOS-universal.dylib` as published on
  smoodle-type/librime releases.

## Bumping

When smoodle-type/librime cuts a new fork tag, recompute this file:

```bash
TAG=1.16.0-smoodle.1   # or the new tag
URL="https://github.com/smoodle-type/librime/releases/download/${TAG}/librime-${TAG}-macOS-universal.dylib"
curl -fsSL "$URL" | shasum -a 256 | awk '{print $1}' > vendor/macos/librime.1.dylib.sha256
```

The file MUST be exactly 64 lowercase hex characters followed by a single
newline (or 64 chars with no trailing newline — the install script's `awk
'{print $1}'` is tolerant of either).

## Phase 5 transition

When Phase 5 / HARDEN-04 lands the live `.sha256` sidecar emission in
smoodle-type/librime's release.yml, this vendored copy becomes a
defense-in-depth fallback (live URL primary, vendored secondary). Tag
rewrites can wipe the live sidecar — CP-2 — so the vendored copy stays
even after the live sidecar exists.
