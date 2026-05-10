[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'

# Resolve Weasel path (same detection as install-librime-fork.ps1)
$WeaselPath = $env:SMOODLE_WEASEL_PATH
if (-not $WeaselPath) {
    foreach ($parent in @(
        (Join-Path $env:ProgramFiles        'Rime'),
        (Join-Path ${env:ProgramFiles(x86)} 'Rime')
    )) {
        if (-not (Test-Path $parent)) { continue }
        $versioned = Get-ChildItem $parent -Directory -Filter 'weasel-*' `
                     -ErrorAction SilentlyContinue |
                     Sort-Object Name -Descending | Select-Object -First 1
        if ($versioned) { $WeaselPath = $versioned.FullName; break }
    }
}

if (-not $WeaselPath) {
    Write-Error "Weasel not found. Install Rime.Weasel first."
    exit 2
}

$DllPath = Join-Path $WeaselPath 'rime.dll'
if (-not (Test-Path $DllPath)) {
    Write-Error "rime.dll not found at $DllPath"
    exit 2
}

# Sidecar path (vendored, same as install-librime-fork.ps1 uses)
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$SidecarPath = Join-Path $ScriptDir '..\vendor\windows\rime.dll.sha256'
try { $SidecarPath = (Resolve-Path $SidecarPath -ErrorAction Stop).Path } catch {
    Write-Error "SHA256 sidecar not found at $SidecarPath. Run install-librime-fork.ps1 first."
    exit 2
}

$ExpectedSha = ((Get-Content -Raw -Encoding UTF8 $SidecarPath) -split '\s+')[0].Trim().ToLower()
$ActualSha = (Get-FileHash -Algorithm SHA256 -Path $DllPath).Hash.ToLower()

if ($ExpectedSha -ne $ActualSha) {
    Write-Host "WARN: rime.dll drift detected."
    Write-Host "  expected: $ExpectedSha"
    Write-Host "  actual:   $ActualSha"
    Write-Host ""
    Write-Host "A Weasel update may have overwritten the smoodle-patched DLL."
    Write-Host "Re-run to reapply the patch:"
    Write-Host "  .\scripts\install-librime-fork.ps1"
    exit 1
}

Write-Host "OK: rime.dll hash matches expected"
exit 0
