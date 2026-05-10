<#
.SYNOPSIS
    smoodle: install the patched librime DLL fetched from the
    smoodle-type/librime fork's smoodle-build CI artifact.

.DESCRIPTION
    Lane B parallel of scripts/install-librime-fork.sh on macOS, but
    distribution model is "download pre-built artifact" rather than
    "build from source." Reasons: vcpkg + MSVC bootstrap is hostile
    to embed in an end-user installer, and the smoodle-build CI on
    smoodle-type/librime already produces validated x64 / x86 / clang /
    mingw artifacts on every push. Saves ~3-5 GB of dev tooling on the
    user's machine and ~30 min of build time.

    Steps:
      1. Check vendor/windows/rime.dll in the repo (or share mount for the
         dev loop). If found, use it directly  -  no gh/7-Zip needed.
      2. Fallback: verify gh CLI + 7-Zip available; offer to winget install.
      3. Resolve target run id (latest successful smoodle-build by
         default; SMOODLE_LIBRIME_FORK_RUN_ID overrides).
      4. gh run download the requested variant artifact.
      5. Extract the inner rime-*.7z to locate dist/lib/rime.dll.
      6. Verify admin elevation (writing into Program Files\Rime\Weasel\
         requires it). Bail with a copy-pasteable re-launch line if not.
      7. Back up the existing rime.dll to rime.dll.smoodle-backup
         (only on first run; preserves Weasel's original).
      8. Swap in the patched DLL.

    Env overrides:
      SMOODLE_LIBRIME_FORK_REPO     gh repo  (default: smoodle-type/librime)
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
    build locally, point them at vendor/librime + smoodle-type/librime
    smoodle-build.yml. That's a developer concern, not an installer one.
#>

[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path

# ---------------------------------------------------------------------------
# Config (env or default).
# ---------------------------------------------------------------------------
$ForkRepo     = if ($env:SMOODLE_LIBRIME_FORK_REPO)   { $env:SMOODLE_LIBRIME_FORK_REPO }   else { 'smoodle-type/librime' }
$RunIdOverride = $env:SMOODLE_LIBRIME_FORK_RUN_ID
$Variant       = if ($env:SMOODLE_LIBRIME_VARIANT)    { $env:SMOODLE_LIBRIME_VARIANT }    else { 'msvc-x64' }
$SkipDownload  = ($env:SMOODLE_SKIP_DOWNLOAD -eq '1')
$SkipSwap      = ($env:SMOODLE_SKIP_SWAP -eq '1')
$NonInteractive = ($env:SMOODLE_NONINTERACTIVE -eq '1')
$CacheDir      = if ($env:SMOODLE_DLL_CACHE_DIR) { $env:SMOODLE_DLL_CACHE_DIR } `
                 else { Join-Path $env:LOCALAPPDATA 'smoodle\librime' }

# Plan 03-02: SHA256 verify env surface ----------------------------------------
# SMOODLE_SHA256_SIDECAR  - path to a local .sha256 sidecar (LOWERCASE hex; one
#                            line, optional trailing newline). Default: the
#                            vendored vendor/windows/rime.dll.sha256 (Win primary
#                            sidecar source per D5 - Win install path is vendored-
#                            DLL primary, so sidecar primacy follows install-path
#                            primacy; this REVERSES Phase 2 mac's primary/secondary).
# SMOODLE_SHA256_LIVE_URL - URL to a remote .sha256 sidecar; SECONDARY source
#                            used only on the gh-run-download install path.
#                            Default null until Phase 5 / HARDEN-04 ships
#                            live sidecar emission in smoodle-type/librime
#                            release.yml. Test hook for guaranteed-404.
$Sha256SidecarVendored = if ($env:SMOODLE_SHA256_SIDECAR) {
    $env:SMOODLE_SHA256_SIDECAR
} else {
    $vendoredSidecar = Join-Path $ScriptDir '..\vendor\windows\rime.dll.sha256'
    try { (Resolve-Path $vendoredSidecar -ErrorAction Stop).Path } catch { $null }
}
$Sha256LiveUrl = $env:SMOODLE_SHA256_LIVE_URL

# Weasel install dir  -  same detection logic as install-windows.ps1.
# winget installs to a versioned subdir (e.g. C:\Program Files\Rime\weasel-0.17.4\)
# not the unversioned \Rime\Weasel\ we originally assumed. Probes parent dirs and
# picks the newest weasel-* subdirectory. SMOODLE_WEASEL_PATH env override wins.
$WeaselPath = $env:SMOODLE_WEASEL_PATH
if (-not $WeaselPath) {
    foreach ($parent in @(
        (Join-Path $env:ProgramFiles        'Rime'),
        (Join-Path ${env:ProgramFiles(x86)} 'Rime')
    )) {
        if (-not (Test-Path $parent)) { continue }
        $plain = Join-Path $parent 'Weasel'
        if (Test-Path $plain) { $WeaselPath = $plain; break }
        $versioned = Get-ChildItem $parent -Directory -Filter 'weasel-*' `
                     -ErrorAction SilentlyContinue |
                     Sort-Object Name -Descending | Select-Object -First 1
        if ($versioned) { $WeaselPath = $versioned.FullName; break }
    }
}

$WeaselDll  = Join-Path $WeaselPath 'rime.dll'
$BackupDll  = "$WeaselDll.smoodle-backup"
$ArtifactName = "artifact-Windows-$Variant"

# ---------------------------------------------------------------------------
# Vendored DLL resolution (checked before any gh/7-Zip work).
# Priority: share mount (dev loop) > repo path (git clone) > CI download.
# The DLL ships in vendor/windows/rime.dll; users who git-clone the repo
# get it without any network fetch during install.
# ---------------------------------------------------------------------------
$VendoredDll = $null
if (-not $SkipDownload) {
    $shareDll = '\\host.lan\Data\vendor\windows\rime.dll'
    $repoDll  = Join-Path $ScriptDir '..\vendor\windows\rime.dll'
    # Normalize the repo path without throwing on missing file.
    try { $repoDll = (Resolve-Path $repoDll -ErrorAction Stop).Path } catch { $repoDll = $null }
    if (Test-Path $shareDll) {
        $VendoredDll = $shareDll
    } elseif ($repoDll -and (Test-Path $repoDll)) {
        $VendoredDll = $repoDll
    }
}

Write-Host 'smoodle librime fork installer (Windows)'
Write-Host '========================================'
Write-Host "  fork repo:   $ForkRepo"
Write-Host "  variant:     $Variant"
Write-Host "  Weasel path: $WeaselPath"
Write-Host "  cache dir:   $CacheDir"
if ($VendoredDll) {
    Write-Host "  source dll:  $VendoredDll (vendored)"
} else {
    Write-Host "  source dll:  CI artifact download"
}
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
    # winget doesn't refresh PATH for the current session  -  re-probe known dirs.
    foreach ($p in $ExtraPaths) {
        if (Test-Path $p) { return $p }
    }
    $found = Get-Command $Cmd -ErrorAction SilentlyContinue
    if ($found) { return $found.Source }
    Write-Error "$DisplayName installed but not on PATH and not at known install dirs. Re-open PowerShell and re-run."
    exit 1
}

$SevenZipExe = $null
if (-not $VendoredDll) {
    if (-not $SkipDownload) {
        $null = Ensure-WingetTool 'gh' 'GitHub.cli' 'GitHub CLI'
    }
    $SevenZipExe = Ensure-WingetTool '7z' '7zip.7zip' '7-Zip' @(
        "$env:ProgramFiles\7-Zip\7z.exe",
        "${env:ProgramFiles(x86)}\7-Zip\7z.exe"
    )
    Write-Host "  [OK] 7-Zip at $SevenZipExe"
}

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
# Resolve DLL source: vendored > cached > CI download.
# ---------------------------------------------------------------------------
if (-not (Test-Path $CacheDir)) {
    New-Item -ItemType Directory -Path $CacheDir -Force | Out-Null
}

$DllOut = Join-Path $CacheDir 'rime.dll'

if ($VendoredDll) {
    # Vendored path: no download or extraction needed.
    $DllOut = $VendoredDll
    $sizeKb = [math]::Round((Get-Item $DllOut).Length / 1KB, 0)
    Write-Host "  [OK] using vendored DLL ($sizeKb KB) from $DllOut"
} elseif ($SkipDownload) {
    if (-not (Test-Path $DllOut)) {
        Write-Error "SMOODLE_SKIP_DOWNLOAD=1 but $DllOut does not exist. Run once without skip to populate cache."
        exit 1
    }
    Write-Host "  [SKIP] download (using cached $DllOut)"
} else {
    # CI download fallback (gh + 7-Zip).
    $RunId = $RunIdOverride
    if (-not $RunId) {
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
# Plan 03-02: SHA256 verify (CP-2)
# ---------------------------------------------------------------------------
# Post-DLL-resolution, pre-Copy-Item gate. Sidecar source order (Win-specific,
# REVERSED from Phase 2 mac): vendored PRIMARY, live URL SECONDARY. Reason:
# Win install path's primary is vendored DLL (lines 95-112); sidecar primacy
# follows install-path primacy.
#
# This block runs BEFORE the SKIP_SWAP early-exit so the sandboxed workflow
# step (SMOODLE_SKIP_SWAP=1) still exercises the gate. Failure-before-Copy-Item
# invariant: SHA mismatch exits 1 BEFORE the existing Copy-Item to the resolved
# Weasel install path further below.
#
# NOTE: install-librime-fork.ps1 uses Copy-Item (not Move-Item); the ROADMAP
# wording 'before any Move-Item to Weasel\Frameworks\rime.dll' is a Win-side
# mistake - actual Weasel install path is Program Files\Rime\weasel-X.Y.Z\rime.dll
# per install-windows.ps1's probe logic (NOT Weasel\Frameworks\rime.dll). The
# invariant is: no Copy-Item to the resolved $WeaselDll on the failure path.
$expectedSha = $null
if ($Sha256SidecarVendored -and (Test-Path $Sha256SidecarVendored)) {
    $expectedSha = ((Get-Content -Raw -Encoding UTF8 $Sha256SidecarVendored) -split '\s+')[0].Trim().ToLower()
    Write-Host "  sha source: vendored sidecar at $Sha256SidecarVendored"
} elseif ($Sha256LiveUrl) {
    $tmpSha = New-TemporaryFile
    try {
        Invoke-WebRequest -Uri $Sha256LiveUrl -OutFile $tmpSha -UseBasicParsing -ErrorAction Stop
        $expectedSha = ((Get-Content -Raw -Encoding UTF8 $tmpSha) -split '\s+')[0].Trim().ToLower()
        Write-Host "  sha source: live URL at $Sha256LiveUrl"
    } catch {
        Write-Host "  sha source: live URL fetch failed ($($_.Exception.Message)); no fallback configured"
    } finally {
        Remove-Item -Force -ErrorAction SilentlyContinue $tmpSha 2>$null
    }
}

if (-not $expectedSha) {
    Write-Error "ERROR: no SHA256 sidecar available (vendored absent + no live URL + Phase 5 live emission not yet shipped)"
    Write-Host  "       cannot verify rime.dll integrity; refusing to swap"
    exit 1
}

# Get-FileHash returns UPPERCASE hex; sidecar is LOWERCASE; normalize via .ToLower()
# (D6: symmetric lowering means either source can ship either case without breaking).
$actualSha = (Get-FileHash -Algorithm SHA256 -Path $DllOut).Hash.ToLower()
if ($expectedSha -ne $actualSha) {
    # Log diagnostics BEFORE Write-Error: the script runs with
    # $ErrorActionPreference = 'Stop' so Write-Error is terminating;
    # any Write-Host that follows would be unreachable. Operators (and
    # the unittest) must see expected/actual hashes to triage CP-2
    # supply-chain anomalies vs. corrupted-download anomalies.
    Write-Host  "  expected: $expectedSha"
    Write-Host  "  actual:   $actualSha"
    Write-Host  "  source:   $DllOut"
    Write-Host  "       refusing to swap (CP-2 supply-chain protection)"
    Write-Error "ERROR: SHA256 mismatch on rime.dll"
    exit 1
}
Write-Host "  [OK] SHA256 verify passed ($actualSha)"

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
if (-not $NonInteractive -and -not [System.Console]::IsInputRedirected) {
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
    Write-Host "Existing backup at $BackupDll  -  leaving in place."
}

# Stop WeaselServer (and any lingering WeaselDeployer) so they release the
# DLL file lock before we overwrite. Wait for actual process exit rather
# than using a fixed sleep.
$weaselServerExe = Join-Path $WeaselPath 'WeaselServer.exe'
foreach ($procName in @('WeaselServer', 'WeaselDeployer')) {
    $p = Get-Process -Name $procName -ErrorAction SilentlyContinue
    if ($p) {
        Write-Host "Stopping $procName to release DLL file lock..."
        Stop-Process -Name $procName -Force -ErrorAction SilentlyContinue
        try { $p | Wait-Process -Timeout 10 -ErrorAction SilentlyContinue } catch {}
    }
}
Start-Sleep -Seconds 2

Write-Host 'Copying patched DLL...'
$copyOk = $false
for ($attempt = 1; $attempt -le 5; $attempt++) {
    try {
        Copy-Item -Path $DllOut -Destination $WeaselDll -Force
        $copyOk = $true
        break
    } catch {
        if ($attempt -lt 5) {
            Write-Host "  (attempt $attempt failed; retrying in 2s...)"
            Start-Sleep -Seconds 2
        }
    }
}
if (-not $copyOk) {
    Write-Error "Could not copy rime.dll after 5 attempts. Is another process holding it open?"
    exit 1
}
$newSizeKb = [math]::Round((Get-Item $WeaselDll).Length / 1KB, 0)
Write-Host "  [OK] Weasel's rime.dll is now $newSizeKb KB."

# --- Plan 03-02: Authenticode regression diagnostic (E2EWIN-05 script-level) ---
# Non-blocking warning - swap already happened. Phase 1 baseline = NotSigned.
# If status flips (legitimate librime fork upgrade to signed bins, OR supply-
# chain compromise inserting a signed binary), surface for human review.
# Plan 03-01's Pester driver Describe 4 is the BLOCKING workflow-time check;
# this diagnostic is the install-time post-swap visibility check.
$sig = Get-AuthenticodeSignature -FilePath $WeaselDll
if ($sig.Status -ne 'NotSigned') {
    Write-Warning "Weasel rime.dll signature changed; review fork upgrade vs. supply-chain compromise before unblocking"
    Write-Warning "  expected: NotSigned (Phase 1 unsigned dogfood baseline)"
    Write-Warning "  actual:   $($sig.Status)"
    Write-Warning "  if this is a legitimate librime-fork upgrade to signed binaries, update tests/test_install_librime_fork_win.py + Plan 03-01 Pester Describe 4 baseline."
}

# Restart WeaselServer.
if (Test-Path $weaselServerExe) {
    Write-Host 'Restarting WeaselServer...'
    Start-Process $weaselServerExe
    Write-Host '  [OK] WeaselServer restarted with patched DLL.'
}

@"

Done. Patched DLL installed and WeaselServer restarted.
If the tray icon is missing: Start > Weasel Server > open it.

Or restart manually via PowerShell (admin):
  Stop-Process -Name WeaselServer -Force -ErrorAction SilentlyContinue
  Start-Process '$WeaselPath\WeaselServer.exe'

Verify:
  Type 'sawadee' in Notepad with smoodle Thai phonetic active.
  Expect candidate window with: sawatdee

Note: a Weasel update may overwrite the patched rime.dll silently.
If Thai ranking ever degrades, run:

  .\scripts\verify-librime.ps1

This will check whether the DLL hash still matches the smoodle patch.
If drift is detected, re-run this installer:

  .\scripts\install-librime-fork.ps1

The artifact at $DllOut is cached, so subsequent runs skip the download
(or set SMOODLE_SKIP_DOWNLOAD=1 explicitly).
"@
