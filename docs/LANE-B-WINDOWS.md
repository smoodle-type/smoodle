# Lane B — Windows installer plan

Phase 1 cross-platform parallel lane for shipping the smoodle Thai
phonetic IME to Windows users via [Weasel](https://github.com/rime/weasel),
the official Rime client for Windows.

**Status:** unblocked 2026-05-06 (Phase 0 closed). CI matrix kickoff
committed at LoneExile/librime `d0692a4c` — Windows lane is
`continue-on-error: true` until this plan's build chain stabilises.

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

`winget install Rime.Weasel` returns 0, but Weasel doesn't actually
register itself with Windows TSF (Text Services Framework) until first
launch + activation. Without explicit verification, the installer
claims success and the user can't type Thai.

**Mitigation** (~10 lines of PowerShell):
```powershell
# After winget completes:
Start-Process "$env:ProgramFiles(x86)\Rime\Weasel\WeaselServer.exe"
Start-Sleep 2
$registered = Get-WinUserLanguageList | ? {
  $_.InputMethodTips -match 'Rime|Weasel'
}
if (-not $registered) {
  Write-Error "Weasel installed but not registered with TSF."
  Write-Host "Manual fix: Settings → Time & language → Language → Add → Rime"
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

1. **Windows machine for dogfood verification?** CI can build the
   artifacts, but you need a real Windows box (or Parallels VM) to
   verify the installer end-to-end. Without one, Lane B ships
   "CI-green but unverified on metal."
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
