# Lane B — Windows installer plan

Phase 1 cross-platform parallel lane for shipping the smoodle Thai
phonetic IME to Windows users via [Weasel](https://github.com/rime/weasel),
the official Rime client for Windows.

**Status:** unblocked 2026-05-06 (Phase 0 closed). Test bed running
on th-dc (dockur/windows, 16 GB RAM, Win 11) — see
`infra/lane-b-windows/`. Weasel 0.17.4 host install verified live;
TSF auto-registers (CFM #2 below). Next step: write the two
PowerShell installer scripts (TODO 7 in TODOS.md).

## Install model (mirrors Lane A / macOS)

Three steps, executed by the user once Weasel is on the box:

```powershell
winget install Rime.Weasel                      # one-time host install
.\scripts\install-windows.ps1                   # schema YAMLs (no admin)
.\scripts\install-librime-fork.ps1              # build + DLL swap (admin)
```

Same shape as the macOS path: `install.sh` + `install-librime-fork.sh`.
PowerShell parity, paths flipped to Windows conventions.

## Targets and paths

| | Path |
|---|---|
| Host bundle (winget) | `C:\Program Files (x86)\Rime\Weasel\` |
| Host librime DLL | `C:\Program Files (x86)\Rime\Weasel\rime.dll` |
| Schema YAMLs (per-user) | `%APPDATA%\Rime\` (i.e., `C:\Users\<user>\AppData\Roaming\Rime\`) |
| Auto-deploy CLI | `WeaselDeployer.exe /deploy` |
| Backup convention | `rime.dll.smoodle-backup` (matches macOS `librime.1.dylib.smoodle-backup`) |

Schema YAML targets are **user-writeable** — no UAC for `install-windows.ps1`.

DLL swap target is **system-protected** — requires admin elevation.
PowerShell pattern: `Start-Process -Verb RunAs powershell -ArgumentList "-File install-librime-fork.ps1"`.

## Build chain

`librime` builds on Windows via MSVC + cmake + ninja against vcpkg
dependencies. Upstream's `build.bat` already encodes this; the fork
inherits it.

**Dependencies:**
- Visual Studio 2022 Build Tools (MSVC v143)
- vcpkg with: `boost-algorithm boost-regex leveldb marisa yaml-cpp opencc glog gflags`
- CMake ≥ 3.20
- Ninja

**CI build path** (from `LoneExile/librime/.github/workflows/smoodle-build.yml`):
```yaml
windows-x64:
  runs-on: windows-latest
  continue-on-error: true   # until this lane stabilises
  steps:
    - uses: ilammy/msvc-dev-cmd@v1
    - run: |
        call build.bat thirdparty
        call build.bat release
```

**Local dev path:**
```cmd
:: from vendor/librime/ on the 1.16.0-smoodle.1 tag
build.bat thirdparty
build.bat release
:: artifact at dist\lib\rime.dll
```

## Distribution model

Two options; recommendation depends on Phase 1 timeline:

| | Zip + scripts (Phase 1 dogfood) | MSI (pre-public-ship) |
|---|---|---|
| Effort | ~1 day | ~1 week |
| Tooling | bundle by hand | WiX Toolset |
| User experience | "extract, run two PS1 scripts" | "double-click .msi, accept UAC" |
| Signable | unsigned only | signable (cert procurement is paid prereq) |
| SmartScreen | warning expected | clean once signed |
| Reversible | manual delete | proper uninstall |

**Recommendation:** Zip + scripts for Phase 1. MSI lands alongside
code-signing cert procurement at the pre-public-ship gate (per design doc).

## Critical failure modes (eng review)

### #2 — winget reports Weasel install success, IME doesn't register

**Empirically does NOT reproduce on Win 11 (verified 2026-05-06 on
the th-dc test bed with Weasel 0.17.4).** `winget install
Rime.Weasel` returns 0 and Weasel auto-registers with Windows TSF
during the MSI bootstrapper run — `Chinese (Simplified, Mainland
China) — Weasel` shows in the Win+Space layout switcher immediately,
no manual activation. Likely fixed in Weasel 0.17.x's installer.

The original concern was that older Weasel builds (~0.14, ~0.15)
required a first launch + activation before TSF picked them up, and
some users on legacy Win 10 reportedly still hit this. So:

- **Phase 1 (Win 11 wedge):** skip the retry/activate dance.
- **Defense-in-depth:** after winget completes, do a single
  `Get-WinUserLanguageList` check and error clearly if it fails.
  No retry loop, no manual-fix flow — just a clean failure that
  surfaces the regression if Weasel ever ships an installer that
  silently breaks TSF auto-registration.

```powershell
# Defense-in-depth verify (~5 lines, no retry):
$registered = Get-WinUserLanguageList | ? {
  $_.InputMethodTips -match 'Rime|Weasel'
}
if (-not $registered) {
  Write-Error "Weasel installed but not registered with TSF."
  Write-Host "Open Settings → Time & language → Language → Add → Rime."
  exit 1
}
```

### Auto-deploy CLI hangs (mirrors macOS Critical Failure Mode #3)

`WeaselDeployer.exe /deploy` can hang indefinitely if the host process
isn't running.

**Mitigation:** wrap with `Wait-Process -Timeout 10` or
`Start-Process ... -PassThru | Wait-Process -Timeout 10`.

## Test surface

Three new artifacts, parallels macOS:

- `tests/test_installers.ps1` — shape checks on the two PowerShell
  scripts (syntax via `Get-Command -Syntax`, env-override declarations,
  brew-deps-equivalent vcpkg list, `.smoodle-backup` convention).
- `tests/test_install_e2e_win.ps1` — fresh `windows-latest` runner:
  install Weasel via winget, run schema installer, run librime swap,
  verify candidate window via UI automation.
- Existing `test_dict.py --use-rime-api-console` ports to Windows once
  the fork CI produces a `rime.dll` artifact.

Existing Python `test_installers.py` shape stub already in
`FutureLanes`:
```python
@unittest.skip("Lane B: Windows installer not yet implemented")
def test_windows_weasel_post_install_registration_verified(self):
    ...
```
Convert to a real shape check (matching the macOS `InstallScriptShape`
class) once `install-windows.ps1` lands.

## Worktree parallelization

Single Lane B work splits into 3 parallel worktrees once the librime
fork CI is producing Windows artifacts cleanly:

| Worktree | Scope |
|---|---|
| `lane-b-installers` | `scripts/install-windows.ps1` + `scripts/install-librime-fork.ps1` |
| `lane-b-tests` | `tests/test_installers.ps1` + Python shape tests |
| `lane-b-package` | zip-builder + signing-deferred MSI scaffolding |

All three depend on a green Windows job in `LoneExile/librime`'s
`smoodle-build.yml`.

## Open questions

1. ~~**Windows machine for dogfood verification?**~~ ✓ RESOLVED
   2026-05-06 — dockur/windows on th-dc. See
   `infra/lane-b-windows/README.md`. Web VNC + RDP, persistent
   `windows-storage` volume, accessible from any device.
2. **Signed MSI now or post-validation?** MSI build is doable in week
   1; signing requires a $200/yr Sectigo cert with 1-2 week lead.
   Design doc defers signing to pre-public-ship — recommend the same
   for the cert.
3. **winget vs Chocolatey for Weasel host install?** winget ships
   on Windows 10+ by default; Chocolatey is more developer-focused
   but needs separate install. Default to winget.
4. **TSF registration retry strategy?** If verification (#2 above)
   fails, retry once with explicit
   `LanguageBarOptions::Add('Thai', 'Rime')` PowerShell, or fall back
   to printing manual Settings UI navigation.

## Estimated effort

| Phase | Effort |
|---|---|
| Get Windows CI green (vcpkg + build.bat → working `rime.dll` artifact) | 3-5 days |
| `install-windows.ps1` (schema YAMLs + auto-deploy + verify) | 2-3 days |
| `install-librime-fork.ps1` (clone + build + admin DLL swap) | 2-3 days |
| Test surface (shape + E2E on `windows-latest` runner) | 2-3 days |
| Zip-and-script packaging | 1 day |
| **Total to dogfood-grade ship** | **2-3 weeks** |

Add ~1 week if signed MSI is a Phase 1 requirement (it isn't, per the
design doc).

## NOT in this lane

- iOS / iPad with external BT keyboard (TODO 2 in TODOS.md — Phase 2 spike)
- Microsoft Store listing (Phase 2)
- Auto-update via Squirrel.Windows or Sparkle (Phase 1.5)
- Internationalised installer copy (English only for Phase 1)
