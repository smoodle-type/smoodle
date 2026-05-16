# smoodle

Pinyin-style phonetic Thai input method. Type `sawadee`, get `สวัสดี`. Type
`khrap` / `krap` / `kub`, get `ครับ`.

Built as a [Rime](https://rime.im/) schema running inside Squirrel on macOS,
Weasel on Windows, and fcitx5/ibus on Linux.

## Status

**v0.0.6** — schema covers 100% of the Thai National Corpus freq≥50 tail
(14,893 Thai words / 28,239 entries), TNC-frequency-weighted ranking. The
`DictEntryIterator::Peek` first-call-sort fix ships via the
[smoodle-type/librime](https://github.com/smoodle-type/librime) soft-fork at tag
`1.16.0-smoodle.1` until upstream merges.

**Phase 1 (macOS dogfood):** `APPROVED` — verdict `stay-in-dogfood`, recruiting
2-5 diaspora-Thai friends with macOS machines for a formal 7-day soak.

**Scope this release (v0.0.6):**
- ✅ **macOS path is the supported install surface.** Schema lint, macOS E2E,
  release hardening, and macOS docs are all verified green.
- ⚠️ **Windows installer ships in-tree but is not v0.0.6-supported.** Code runs
  on `windows-latest` GHA but `install-windows.ps1` is missing a `--uninstall`
  flag (audit-flagged). Tracked for **v0.0.7-cross-platform**.
- ⚠️ **Telemetry is opt-in and currently routes to a placeholder endpoint.**
  Self-hosted umami deployment + production forget endpoint are tracked for
  **v0.0.7-cross-platform**. Opting in today is a no-op.
- ⚠️ **Linux uses unpatched system librime** — first-lookup ranking may be off
  (documented below).

See [`.planning/v0.0.6-MILESTONE-AUDIT.md`](./.planning/v0.0.6-MILESTONE-AUDIT.md)
and [`.planning/INTEGRATION-CHECK-v0.0.6.md`](./.planning/INTEGRATION-CHECK-v0.0.6.md)
for the audit trail behind this scoping.

## Install

### macOS

```bash
brew install --cask squirrel-app             # one-time host install
bash scripts/install.sh                      # ~/Library/Rime/ schema YAMLs (sudoless)
bash scripts/install-librime-fork.sh         # build patched librime + dylib swap (sudo)

osascript -e 'tell application id "im.rime.inputmethod.Squirrel" to quit'
open -b im.rime.inputmethod.Squirrel
```

Then press `Ctrl+\`` in any text field to open Squirrel's schema switcher
and pick **smoodle Thai phonetic**. Type `sawadee` → expect `สวัสดี`.

### Windows (experimental — v0.0.7 supported)

> **Heads-up:** the Windows installer works end-to-end (verified by
> `install-win-e2e.yml` on `windows-latest`) but `install-windows.ps1` is
> currently missing a `--uninstall` flag and is therefore not declared
> v0.0.6-supported. If you're on macOS, prefer the macOS path. If you're on
> Windows and try this anyway, you can uninstall manually:
> `Remove-Item -Recurse $env:APPDATA\Rime\thai_phonetic.*.yaml,
> $env:APPDATA\Rime\default.custom.yaml, $env:USERPROFILE\.smoodle`.

```powershell
winget install Rime.Weasel                   # one-time host install (UAC required)
powershell -ExecutionPolicy Bypass -File scripts\install-windows.ps1
powershell -ExecutionPolicy Bypass -File scripts\install-librime-fork.ps1  # admin
```

Then press `Win+Space` and switch to **smoodle Thai phonetic** (or **Weasel**
and switch schema via `Ctrl+\``). Type `sawadee` → expect candidate with `สวัสดี`.

### Linux

```bash
# Requires fcitx5 or ibus already running
bash scripts/install-linux.sh
```

Then switch input method to **smoodle Thai phonetic** (`Ctrl+Space` by default
on most Linux desktops). Type `sawadee` → expect `สวัสดี`.

> **Linux ranking limitation:** The Linux install uses the distro's system
> librime, which lacks the `DictEntryIterator::Peek` first-call sort fix.
> On first lookup, alphabetically-earlier syllables may rank above higher-weight
> entries. Type → commit → retype — second lookup ranks correctly. This is fixed
> in the macOS/Windows builds via the [smoodle-type/librime](https://github.com/smoodle-type/librime) fork.

## Troubleshooting

### Smoodle not in input switcher
- Verify the three YAML files exist in your Rime user directory
  (`~/Library/Rime/`, `%APPDATA%\Rime\`, or `~/.local/share/fcitx5/rime/` / `~/.config/ibus/rime/`)
- Click **Deploy** in your IME's menu to recompile schemas

### Ranking degraded after Squirrel auto-update (macOS)
- Squirrel's Sparkle auto-update may have overwritten the patched `librime.1.dylib`
- Run `bash scripts/verify-librime.sh` to check for hash drift
- If drift detected: `bash scripts/install-librime-fork.sh` to re-swap

### Intel Mac: "arm64-only dylib" error
- As of v0.0.6, the patched dylib from the librime fork is arm64-only
- Universal dylib (arm64 + x86_64) is planned for Phase 1.5
- Workaround: build librime from source on your Intel Mac
  (`cd vendor/librime && make release`)

### Windows: Weasel installed but not registered
- Open Settings > Time & Language > Language > Keyboard
- Add **Rime** if not present in the list
- Re-run `install-windows.ps1` to ensure schema files land in `%APPDATA%\Rime\`
- Right-click the Weasel tray icon → Settings → Schema list → add
  **smoodle Thai phonetic** if missing

### Linux: candidate ranks wrong on first lookup
- Known limitation: system librime lacks the `DictEntryIterator::Peek` fix
- Workaround: type the input, commit, retype — second lookup ranks correctly
- This is fixed in the macOS build via the smoodle-type/librime fork

## Uninstall

### macOS
```bash
bash scripts/install.sh --uninstall
```

### Windows
Remove manually:
```powershell
Remove-Item "$env:APPDATA\Rime\thai_phonetic.schema.yaml"
Remove-Item "$env:APPDATA\Rime\thai_phonetic.dict.yaml"
Remove-Item "$env:APPDATA\Rime\default.custom.yaml"
# Optional: remove telemetry data
Remove-Item "$env:USERPROFILE\.smoodle" -Recurse -Force -ErrorAction SilentlyContinue
```

### Linux
```bash
bash scripts/install-linux.sh --uninstall
```

## Test

```bash
# String-match (fast, no librime build needed)
python3 tests/test_dict.py --fixture tests/v01_fixture.yaml

# Engine mode (drives librime via rime_api_console)
bash scripts/init_rime_testdir.sh                                       # one-time
python3 tests/test_dict.py --use-rime-api-console --fixture tests/v01_fixture.yaml

# Installer suite
python3 tests/test_installers.py
```

Engine fixture target: 56/56 PASS (35 direct + 21 algebra-tagged).

## Repo layout

```
smoodle/
├── schema/                          # Rime YAML config: schema, dict, default.custom.yaml
├── scripts/
│   ├── install.sh                   # schema YAMLs → ~/Library/Rime/ (sudoless, --uninstall)
│   ├── install-librime-fork.sh      # build patched librime + dylib swap (sudo)
│   ├── install-windows.ps1          # schema YAMLs → %APPDATA%\Rime\
│   ├── install-librime-fork.ps1     # DLL swap (admin)
│   ├── install-linux.sh             # schema YAMLs → fcitx5/ibus dir (--uninstall)
│   ├── verify-librime.sh            # manual hash-drift checker (macOS)
│   ├── verify-librime.ps1           # manual hash-drift checker (Windows)
│   ├── lib/
│   │   ├── telemetry.sh             # Bash fire-and-forget telemetry POST
│   │   ├── telemetry.ps1            # PowerShell fire-and-forget telemetry POST
│   │   ├── telemetry-forget.sh      # Telemetry data purge CLI
│   │   └── telemetry-forget.ps1     # Telemetry data purge CLI (Windows)
│   └── (dict-build scripts)
├── infra/
│   ├── telemetry/                   # Docker Compose: umami + postgres + caddy
│   └── lane-b-windows/              # dockur/windows test bed VM
├── tests/
│   ├── test_dict.py                 # 56-entry fixture (string-match + engine mode)
│   ├── test_installers.py           # installer shape tests
│   ├── test_telemetry.py            # telemetry payload + privacy tests
│   └── v01_fixture.yaml             # (romanization, expected_thai) assertions
├── docs/
│   ├── RESUME.md                    # long-form architecture context
│   └── RELEASE-CHECKLIST.md         # pre-release validation procedure
├── .github/workflows/               # CI + E2E + release workflows
├── TODOS.md                         # tracked work outside the active milestone
└── vendor/                          # gitignored — librime fork checkout (~2GB after build)
```

## License

[MIT](LICENSE) for smoodle's own code (schema, dict, scripts, tests, docs).

The patched librime distribution at
[smoodle-type/librime](https://github.com/smoodle-type/librime) is BSD-3
(inherited from upstream). Squirrel itself is GPLv3 and is **not
bundled** — installers configure Squirrel rather than redistributing
it; users obtain Squirrel via Homebrew (`brew install --cask
squirrel-app`).
