# Lane C — Linux installer plan

Phase 1 cross-platform parallel lane (stretch goal per design doc) for
shipping the smoodle Thai phonetic IME to Linux desktops via fcitx5-rime
or ibus-rime, the two majority Rime hosts on Linux.

**Status:** unblocked 2026-05-06 (Phase 0 closed). Stretch goal — design
doc explicitly says "defer if month 1.5 slips." Recommendation: scope
narrowly (Ubuntu LTS + Arch only), accept the librime distribution
limitation (option 3 below), document the trade-off cleanly.

## The honest framing

Linux is the hardest platform for smoodle and the smallest expected
audience (Thai learners on physical Latin keyboards on Linux desktops
is statistically near-zero). Don't spend more time here than the wedge
justifies. Two real users from the dogfood circle would unblock real
investment; until then, ship a documented-limitations install that
works on the two most-likely distros.

## Host IMEs — two paths

| | fcitx5-rime | ibus-rime |
|---|---|---|
| Default on | Arch, Manjaro, Fedora KDE, sway/i3 | Ubuntu LTS, Debian, Fedora GNOME |
| Schema dir | `~/.local/share/fcitx5/rime/` | `~/.config/ibus/rime/` |
| Deploy CLI | `fcitx5 -r` (reload) | `ibus-daemon -r` (replace) |
| Install command | `pacman -S fcitx5-rime` (Arch) / `dnf install fcitx5-rime` (Fedora) | `apt install ibus-rime` (Ubuntu/Debian) |
| Process name | `fcitx5` | `ibus-daemon` |

Both run on top of `libRime.so` from the system package manager.

## Detection (Critical Failure Mode #3 from eng review)

Hybrid setups exist — user has fcitx5 installed but is currently
running an ibus session, or vice versa. Detecting by binary presence
(`command -v`) silently picks the wrong one and writes schema YAMLs
to a directory the active IM doesn't read.

**Correct detection** (~30 lines bash):
```bash
detect_running_im() {
  if pgrep -x fcitx5 >/dev/null; then
    echo "fcitx5"
  elif pgrep -x ibus-daemon >/dev/null; then
    echo "ibus"
  else
    return 1   # nothing running — fall back to interactive prompt
  fi
}
```

If neither runs, exit with explicit "no IM is currently running"
error and instructions to start one.

## The librime distribution problem

**This is what makes Linux hard.** On macOS and Windows, the host IME
(Squirrel/Weasel) bundles its own librime which we can dylib-swap.
On Linux, fcitx5-rime and ibus-rime use **system librime** via
apt/pacman — `/usr/lib/x86_64-linux-gnu/libRime.so`. We can't replace
it without messing with the user's system.

Three options, decision required before Lane C build investment:

| Option | UX | Effort | Risk | Phase 1 fit |
|---|---|---|---|---|
| **1. Forked-rime distro packages** | Clean native install | High — `.deb` for Ubuntu, AUR PKGBUILD for Arch, optional Flatpak for universal. Each new librime upstream release means rebuilding all of them. | Per-distro packaging maintenance, ongoing | Bad — wedge audience too small |
| **2. `LD_PRELOAD` shim** | Hostile (env-var dance), AppArmor fights it on Ubuntu | Low | Brittle; breaks on system updates; security profiles reject it | Bad — unprofessional |
| **3. Accept unpatched librime** | Cleanest — schema-only install | None | Algebra-vs-direct ranking sometimes wrong on first lookup (the bug the patch fixes) | **Good for Phase 1** |

### Recommended: option 3

Ship a schema-only Linux installer. Document the limitation explicitly:

> **Linux ranking limitation.** smoodle's algebra rules can produce
> spelling variants that collide with direct dictionary entries. On
> macOS and Windows, smoodle ships a patched librime that ranks these
> correctly. On Linux, smoodle uses the system librime, which has a
> known bug where the alphabetically-earlier syllable wins position #1
> on the first lookup regardless of weight. Workaround: type the input,
> press space (or arrow-down) to commit, retype — second lookup ranks
> correctly. Upstream PR is pending; once merged, this limitation
> disappears.

Revisit option 1 only if:
- A non-trivial Linux dogfood signal materialises (e.g., 3+ users ask)
- OR upstream librime PR is rejected with no fix path
- OR we hit Phase 2 and the rewrite gives us the engine ourselves

## Install model

Single script, dispatches on detected IM:

```bash
./scripts/install-linux.sh
# 1. Detect running IM (fcitx5 / ibus / none)
# 2. Verify host package installed (fcitx5-rime / ibus-rime)
# 3. Copy schema YAMLs to the right dir
# 4. Auto-deploy with timeout (`fcitx5 -r` or `ibus-daemon -r`)
# 5. Print test instructions (Ctrl+Space to switch, type sawadee)
```

No sudo needed for the schema-only flow (option 3) — schema YAMLs go
to `~/.local/share/...` or `~/.config/...`, both user-writeable.

## Packaging targets (minimal scope)

| Target | Distro coverage | Effort |
|---|---|---|
| `.deb` package | Ubuntu LTS (24.04, 22.04), Debian, Pop!_OS, Mint | 1-2 days (`dpkg-deb`) |
| AUR PKGBUILD | Arch, Manjaro, EndeavourOS | 1 day |
| **Skip:** Fedora `.rpm`, Flatpak, Snap, Nix | | (defer until anyone asks) |

Both `.deb` and AUR are config-only (option 3): drop schema YAMLs +
the `install-linux.sh` script. No compiled artifacts to ship per-arch.

## Test surface

- `tests/test_installers_linux.sh` — shape checks for `install-linux.sh`
  (bash syntax, env overrides, both detection paths reachable, idempotency).
- `tests/test_install_e2e_linux.sh` — runs on `ubuntu-latest` GitHub
  runner, installs ibus-rime via apt, runs install-linux.sh, verifies
  schema is queryable via `ibus-daemon` (no engine fixture run since
  we're using system librime).
- Existing Python `test_installers.py` already has the stub:
  ```python
  @unittest.skip("Lane C: Linux installer not yet implemented")
  def test_linux_picks_running_im_not_just_installed(self):
      ...
  ```
  Convert to a real shape test once `install-linux.sh` lands.

## Worktree parallelization

Single Lane C worktree is enough — the work doesn't fan out the way
Lane B does. Parallel paths only emerge if we go option 1 (separate
worktree per distro packaging effort).

## Open questions

1. **Locked into option 3 for Phase 1?** Recommend yes. Document the
   limitation. Revisit only if Linux dogfood signal materialises.
2. **Test on Arch + Ubuntu only or also Fedora?** ubuntu-latest CI
   runner is free; Arch in CI is doable via Docker. Recommend
   Ubuntu LTS first, Arch second (via PKGBUILD), Fedora skipped.
3. **GPG-signed `.deb`?** Adds polish for users who care; takes a day.
   Defer to pre-public-ship gate alongside macOS notarization +
   Windows code-signing.
4. **AUR maintainer?** AUR packages benefit from an active maintainer.
   Founder can self-maintain at first (low traffic expected); switch
   to a community maintainer if interest grows.

## Estimated effort

| Phase | Effort |
|---|---|
| `install-linux.sh` (detection + schema copy + auto-deploy + verify) | 2-3 days |
| `.deb` packaging + Ubuntu CI E2E test | 2-3 days |
| AUR PKGBUILD + smoke test | 1 day |
| Documentation of the librime ranking limitation | 0.5 day |
| **Total to dogfood-grade ship (option 3)** | **1-2 weeks** |

Option 1 (full distro packages with patched librime) would add 4-6
weeks for the per-distro packaging work. Not recommended for Phase 1.

## NOT in this lane

- Wayland-specific quirks (smoodle is text-input-method-agnostic;
  Wayland users get the same fcitx5/ibus paths as X11)
- Distro-specific exotica: NixOS, Gentoo, Alpine, Void
- Snap, Flatpak (defer until first request)
- `ibus-rime` 1.6+ migration when it lands (currently targeting 1.4+)
- AppImage (one-binary distribution only really applies if we go option 1)

## When to actually start this lane

Per design doc: "stretch goal — defer if month 1.5 slips." Concretely:
- **Start Lane C** if Lane B (Windows) ships clean and there's calendar
  room before Decision Gate.
- **Defer Lane C** if Lane B is still bumpy at month 1.5 — better to
  ship a polished macOS + Windows than a rough macOS + Windows + Linux.
- **Skip Lane C entirely** if no Linux user surfaces in the dogfood
  circle by Decision Gate. Document the wedge as macOS + Windows only.
