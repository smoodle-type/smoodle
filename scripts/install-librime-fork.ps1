<#
.SYNOPSIS
    smoodle: install the patched librime DLL fetched from the
    LoneExile/librime fork's smoodle-build CI artifact.

.DESCRIPTION
    Lane B parallel of scripts/install-librime-fork.sh on macOS, but
    distribution model is "download pre-built artifact" rather than
    "build from source." Reasons: vcpkg + MSVC bootstrap is hostile
    to embed in an end-user installer, and the smoodle-build CI on
    LoneExile/librime already produces validated x64 / x86 / clang /
    mingw artifacts on every push. Saves ~3-5 GB of dev tooling on the
    user's machine and ~30 min of build time.

    Steps:
      1. Verify gh CLI + 7-Zip available; offer to winget install if not.
      2. Resolve target run id (latest successful smoodle-build by
         default; SMOODLE_LIBRIME_FORK_RUN_ID overrides).
      3. gh run download the requested variant artifact.
      4. Extract the inner rime-*.7z to locate dist/lib/rime.dll.
      5. Verify admin elevation (writing into Program Files\Rime\Weasel\
         requires it). Bail with a copy-pasteable re-launch line if not.
      6. Back up the existing rime.dll to rime.dll.smoodle-backup
         (only on first run; preserves Weasel's original).
      7. Swap in the patched DLL.

    Env overrides:
      SMOODLE_LIBRIME_FORK_REPO     gh repo  (default: LoneExile/librime)
      SMOODLE_LIBRIME_FORK_RUN_ID   specific run id (default: latest success)
      SMOODLE_LIBRIME_VARIANT       msvc-x64 / msvc-x86 / clang-x64 / mingw
                                     (default: msvc-x64)
      SMOODLE_WEASEL_PATH           Weasel install dir
      SMOODLE_SKIP_DOWNLOAD         "1" to use a previously-downloaded DLL
      SMOODLE_SKIP_SWAP             "1" to download + extract only, no admin
      SMOODLE_NONINTERACTIVE        "1" to skip confirmation prompt
      SMOODLE_DLL_CACHE_DIR         where to keep extracted DLL
                                     (default: $env:LOCALAPPDATA\smoodle\librime)

.EXAMPLE
    PS> Start-Process powershell -Verb RunAs -ArgumentList `
        '-NoProfile -ExecutionPolicy Bypass -File .\scripts\install-librime-fork.ps1'

.NOTES
    Why not build from source? Phase 1 dogfood ships a known-good
    DLL that already passes upstream's CI matrix. If a user wants to
    build locally, point them at vendor/librime + LoneExile/librime
    smoodle-build.yml. That's a developer concern, not an installer one.
#>

[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'

# ---------------------------------------------------------------------------
# Config (env or default).
# ---------------------------------------------------------------------------
$ForkRepo     = if ($env:SMOODLE_LIBRIME_FORK_REPO)   { $env:SMOODLE_LIBRIME_FORK_REPO }   else { 'LoneExile/librime' }
$RunIdOverride = $env:SMOODLE_LIBRIME_FORK_RUN_ID
$Variant       = if ($env:SMOODLE_LIBRIME_VARIANT)    { $env:SMOODLE_LIBRIME_VARIANT }    else { 'msvc-x64' }
$SkipDownload  = ($env:SMOODLE_SKIP_DOWNLOAD -eq '1')
$SkipSwap      = ($env:SMOODLE_SKIP_SWAP -eq '1')
$NonInteractive = ($env:SMOODLE_NONINTERACTIVE -eq '1')
$CacheDir      = if ($env:SMOODLE_DLL_CACHE_DIR) { $env:SMOODLE_DLL_CACHE_DIR } `
                 else { Join-Path $env:LOCALAPPDATA 'smoodle\librime' }

# Resolve Weasel install dir (same logic as install-windows.ps1).
$WeaselPath = $env:SMOODLE_WEASEL_PATH
if (-not $WeaselPath) {
    $candidates = @(
        (Join-Path $env:ProgramFiles        'Rime\Weasel'),
        (Join-Path ${env:ProgramFiles(x86)} 'Rime\Weasel')
    )
    $WeaselPath = $candidates | Where-Object { Test-Path $_ } | Select-Object -First 1
    if (-not $WeaselPath) { $WeaselPath = $candidates[0] }
}

$WeaselDll  = Join-Path $WeaselPath 'rime.dll'
$BackupDll  = "$WeaselDll.smoodle-backup"
$ArtifactName = "artifact-Windows-$Variant"

Write-Host 'smoodle librime fork installer (Windows)'
Write-Host '========================================'
Write-Host "  fork repo:   $ForkRepo"
Write-Host "  variant:     $Variant"
Write-Host "  Weasel path: $WeaselPath"
Write-Host "  cache dir:   $CacheDir"
Write-Host ''

# ---------------------------------------------------------------------------
# Pre-flight: tooling.
# ---------------------------------------------------------------------------
function Ensure-WingetTool {
    param(
        [string]$Cmd,
        [string]$WingetId,
        [string]$DisplayName,
        [string[]]$ExtraPaths = @()
    )
    $found = Get-Command $Cmd -ErrorAction SilentlyContinue
    if ($found) { return $found.Source }
    foreach ($p in $ExtraPaths) {
        if (Test-Path $p) { return $p }
    }
    Write-Host "$DisplayName ($Cmd) not found; installing via winget..."
    & winget install --id $WingetId --silent --accept-source-agreements --accept-package-agreements
    if ($LASTEXITCODE -ne 0) {
        Write-Error "$DisplayName install via winget failed (exit $LASTEXITCODE)."
        exit 1
    }
    # winget doesn't refresh PATH for the current session — re-probe known dirs.
    foreach ($p in $ExtraPaths) {
        if (Test-Path $p) { return $p }
    }
    $found = Get-Command $Cmd -ErrorAction SilentlyContinue
    if ($found) { return $found.Source }
    Write-Error "$DisplayName installed but not on PATH and not at known install dirs. Re-open PowerShell and re-run."
    exit 1
}

if (-not $SkipDownload) {
    $null = Ensure-WingetTool 'gh' 'GitHub.cli' 'GitHub CLI'
}

$SevenZipExe = Ensure-WingetTool '7z' '7zip.7zip' '7-Zip' @(
    "$env:ProgramFiles\7-Zip\7z.exe",
    "${env:ProgramFiles(x86)}\7-Zip\7z.exe"
)
Write-Host "  [OK] 7-Zip at $SevenZipExe"

# ---------------------------------------------------------------------------
# Pre-flight: admin elevation (only required if we're going to swap).
# ---------------------------------------------------------------------------
$isAdmin = ([Security.Principal.WindowsPrincipal](
    [Security.Principal.WindowsIdentity]::GetCurrent()
)).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

if (-not $SkipSwap -and -not $isAdmin) {
    Write-Error 'Admin elevation required (DLL swap writes into Program Files\Rime\Weasel\).'
    Write-Host  ''
    Write-Host  'Re-launch this script from an elevated PowerShell:'
    Write-Host  "  Start-Process powershell -Verb RunAs -ArgumentList '-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`"'"
    Write-Host  ''
    Write-Host  'Or set SMOODLE_SKIP_SWAP=1 to download + extract the DLL only (no swap, no admin).'
    exit 1
}

# ---------------------------------------------------------------------------
# Pre-flight: Weasel host (only required if swapping).
# ---------------------------------------------------------------------------
if (-not $SkipSwap) {
    if (-not (Test-Path $WeaselPath)) {
        Write-Error "Weasel is not installed at $WeaselPath."
        Write-Host  '    winget install Rime.Weasel'
        exit 1
    }
    if (-not (Test-Path $WeaselDll)) {
        Write-Error "rime.dll not found at $WeaselDll. Is this the right Weasel install dir?"
        exit 1
    }
}

# ---------------------------------------------------------------------------
# Resolve the target CI run.
# ---------------------------------------------------------------------------
$RunId = $RunIdOverride
if (-not $RunId -and -not $SkipDownload) {
    Write-Host "Resolving latest successful smoodle-build run on $ForkRepo..."
    $json = & gh run list -R $ForkRepo --workflow smoodle-build --status success --limit 1 --json databaseId,headSha 2>&1
    if ($LASTEXITCODE -ne 0) {
        Write-Error "gh run list failed: $json"
        exit 1
    }
    $runs = $json | ConvertFrom-Json
    if (-not $runs -or $runs.Count -eq 0) {
        Write-Error 'No successful smoodle-build run found on the fork.'
        exit 1
    }
    $RunId = $runs[0].databaseId
    Write-Host "  -> run $RunId (head $($runs[0].headSha.Substring(0,8)))"
}

# ---------------------------------------------------------------------------
# Download + extract.
# ---------------------------------------------------------------------------
if (-not (Test-Path $CacheDir)) {
    New-Item -ItemType Directory -Path $CacheDir -Force | Out-Null
}

$DllOut = Join-Path $CacheDir 'rime.dll'

if ($SkipDownload) {
    if (-not (Test-Path $DllOut)) {
        Write-Error "SMOODLE_SKIP_DOWNLOAD=1 but $DllOut does not exist. Run once without skip to populate cache."
        exit 1
    }
    Write-Host "  [SKIP] download (using cached $DllOut)"
} else {
    $stagingDir = Join-Path $CacheDir "staging-$RunId"
    if (Test-Path $stagingDir) { Remove-Item -Recurse -Force $stagingDir }
    New-Item -ItemType Directory -Path $stagingDir -Force | Out-Null

    Write-Host "Downloading $ArtifactName from run $RunId..."
    & gh run download $RunId -R $ForkRepo -n $ArtifactName -D $stagingDir
    if ($LASTEXITCODE -ne 0) {
        Write-Error "gh run download failed (exit $LASTEXITCODE). Available artifacts:"
        & gh api "repos/$ForkRepo/actions/runs/$RunId/artifacts" --jq '.artifacts[].name'
        exit 1
    }

    # Inner archive: rime-{ref}-Windows-{variant}.7z (NOT the deps one).
    $innerArchive = Get-ChildItem -Path $stagingDir -Filter "rime-*-Windows-$Variant.7z" |
                    Where-Object { $_.Name -notlike '*deps*' } |
                    Select-Object -First 1
    if (-not $innerArchive) {
        Write-Error "Did not find rime-*-Windows-$Variant.7z in $stagingDir"
        Write-Host  "Contents:"
        Get-ChildItem $stagingDir | ForEach-Object { Write-Host "  $($_.Name)" }
        exit 1
    }

    $extractDir = Join-Path $stagingDir 'extracted'
    Write-Host "Extracting $($innerArchive.Name)..."
    & $SevenZipExe x $innerArchive.FullName "-o$extractDir" -y | Out-Null
    if ($LASTEXITCODE -ne 0) {
        Write-Error "7-Zip extract failed (exit $LASTEXITCODE)."
        exit 1
    }

    # The DLL ships at dist/lib/rime.dll inside the archive.
    $extractedDll = Join-Path $extractDir 'dist\lib\rime.dll'
    if (-not (Test-Path $extractedDll)) {
        # Fall back: search for it.
        $extractedDll = (Get-ChildItem -Path $extractDir -Recurse -Filter 'rime.dll' |
                         Select-Object -First 1).FullName
    }
    if (-not $extractedDll -or -not (Test-Path $extractedDll)) {
        Write-Error "rime.dll not found in extracted artifact under $extractDir"
        exit 1
    }

    Copy-Item -Path $extractedDll -Destination $DllOut -Force
    Remove-Item -Recurse -Force $stagingDir
    $sizeKb = [math]::Round((Get-Item $DllOut).Length / 1KB, 0)
    Write-Host "  [OK] cached $DllOut ($sizeKb KB)"
}

# ---------------------------------------------------------------------------
# Swap.
# ---------------------------------------------------------------------------
if ($SkipSwap) {
    Write-Host ''
    Write-Host 'Skipping DLL swap (SMOODLE_SKIP_SWAP=1).'
    Write-Host "Patched DLL is at: $DllOut"
    Write-Host 'To swap manually (admin PowerShell):'
    Write-Host "  Copy-Item '$DllOut' '$WeaselDll' -Force"
    exit 0
}

Write-Host ''
Write-Host 'Next: copy the patched rime.dll into Weasel''s install dir.'
Write-Host "  source: $DllOut"
Write-Host "  target: $WeaselDll"
if (-not $NonInteractive) {
    $resp = Read-Host 'Proceed? [y/N]'
    if ($resp -notmatch '^(y|yes)$') {
        Write-Host 'Aborted by user. Re-run with SMOODLE_NONINTERACTIVE=1 to skip prompt.'
        exit 0
    }
}

# Backup the original rime.dll if no backup exists yet.
if (-not (Test-Path $BackupDll)) {
    Write-Host "Backing up original $WeaselDll -> $BackupDll..."
    Copy-Item -Path $WeaselDll -Destination $BackupDll -Force
} else {
    Write-Host "Existing backup at $BackupDll — leaving in place."
}

Write-Host 'Copying patched DLL...'
Copy-Item -Path $DllOut -Destination $WeaselDll -Force
$newSizeKb = [math]::Round((Get-Item $WeaselDll).Length / 1KB, 0)
Write-Host "  [OK] Weasel's rime.dll is now $newSizeKb KB."

@"

Done. Restart Weasel to pick up the new DLL:
  Right-click Weasel tray icon -> Quit
  Then re-launch:  & '$WeaselPath\WeaselServer.exe'

Or via PowerShell (admin):
  Stop-Process -Name WeaselServer -Force -ErrorAction SilentlyContinue
  Start-Process '$WeaselPath\WeaselServer.exe'

Verify:
  Type 'sawadee' in Notepad with smoodle Thai phonetic active.
  Expect candidate window with: สวัสดี

Note: a Weasel update via winget upgrade may overwrite this patched
DLL. Re-run this script to reapply. The artifact at $DllOut is
cached, so subsequent runs skip the download (or set
SMOODLE_SKIP_DOWNLOAD=1 explicitly).
"@
