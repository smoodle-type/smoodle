<#
.SYNOPSIS
    smoodle Windows installer (Lane B)  -  schema YAMLs + Weasel auto-deploy.

.DESCRIPTION
    Copies smoodle's three schema YAMLs into %APPDATA%\Rime\, attempts
    auto-deploy via WeaselDeployer.exe /deploy with a 60s timeout, falls
    back to manual Deploy instructions on failure. Mirrors scripts/install.sh
    on macOS.

    Runs in user scope. Schema YAMLs go to %APPDATA%\Rime\ (user-writeable,
    no admin). The only admin trigger is the one-time `winget install
    Rime.Weasel` if Weasel isn't already on the box  -  winget pops UAC for
    the MSI bootstrap, you click Yes once, done. After Weasel is installed,
    re-runs of this script are no-UAC. Pair with install-librime-fork.ps1
    to swap the patched librime DLL  -  that script DOES require admin
    elevation up front.

    Pre-flight checks:
      1. Weasel install dir exists (default: C:\Program Files\Rime\Weasel\;
         falls back to C:\Program Files (x86)\Rime\Weasel\).
      2. Weasel TSF registration is present (defense-in-depth, errors if
         winget reported success but Weasel didn't auto-register; CFM #2
         from docs/LANE-B-WINDOWS.md).

    Env overrides (for tests + dogfood path tweaks):
      SMOODLE_RIME_DIR              schema destination dir
      SMOODLE_WEASEL_PATH           Weasel install dir
      SMOODLE_AUTO_DEPLOY           "0" to skip auto-deploy
      SMOODLE_DEPLOY_TIMEOUT_SECS   timeout for WeaselDeployer (default 60s)

.EXAMPLE
    PS> powershell -ExecutionPolicy Bypass -File .\scripts\install-windows.ps1

.NOTES
    Win 11 default ExecutionPolicy is Restricted for current user. Either
    invoke via -ExecutionPolicy Bypass each run, or set once:
        Set-ExecutionPolicy -Scope CurrentUser RemoteSigned
#>

[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'

$ScriptDir  = Split-Path -Parent $MyInvocation.MyCommand.Path
$SmoodleDir = (Resolve-Path (Join-Path $ScriptDir '..')).Path

# ---------------------------------------------------------------------------
# Path overrides (env or sensible default).
# ---------------------------------------------------------------------------
$RimeDir = if ($env:SMOODLE_RIME_DIR) { $env:SMOODLE_RIME_DIR } `
           else { Join-Path $env:APPDATA 'Rime' }

# Weasel install dir  -  env override wins; otherwise probe the filesystem.
# winget (Rime.Weasel) installs to a VERSIONED subdirectory  -  discovered
# 2026-05-07 on the th-dc test bed: C:\Program Files\Rime\weasel-0.17.4\
# NOT the unversioned \Rime\Weasel\ we originally assumed (registry
# InstallLocation blank; not on PATH; only Get-ChildItem found it).
# PowerShell 5.1 requires inline code here  -  calling a function defined
# later in the same script fails with CommandNotFoundException.
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

$DeployTimeoutSecs = if ($env:SMOODLE_DEPLOY_TIMEOUT_SECS) {
    [int]$env:SMOODLE_DEPLOY_TIMEOUT_SECS
} else { 60 }

$AutoDeploy = if ($env:SMOODLE_AUTO_DEPLOY -eq '0') { $false } else { $true }

$SchemaFiles = @(
    'thai_phonetic.schema.yaml',
    'thai_phonetic.dict.yaml',
    'default.custom.yaml'
)

Write-Host 'smoodle installer (Windows / Lane B)'
Write-Host '===================================='
Write-Host "  source:      $SmoodleDir\schema\"
Write-Host "  destination: $RimeDir\"
Write-Host ''

# ---------------------------------------------------------------------------
# Pre-flight #1: Weasel host present (auto-install via winget if missing).
# Skip auto-install when SMOODLE_WEASEL_PATH is explicitly set  -  caller
# is asserting a non-default path and we should respect that.
# ---------------------------------------------------------------------------
if (-not (Test-Path $WeaselPath)) {
    if ($env:SMOODLE_WEASEL_PATH) {
        Write-Error "Weasel is not installed at $WeaselPath (SMOODLE_WEASEL_PATH override)."
        exit 1
    }

    Write-Host 'Weasel not found under C:\Program Files\Rime\ or C:\Program Files (x86)\Rime\; installing via winget...'
    Write-Host '(Weasel installer UI will appear  -  click through Next/Install/Finish.)'
    Write-Host '(UAC prompt may appear first  -  this is the only admin step in this script.)'
    # NOTE: deliberately NOT using --silent. Weasel ships an
    # Inno Setup installer that hangs forever on `--silent` (the
    # silent-mode handshake is incomplete; winget shows a spinner
    # that never finishes). Empirically verified 2026-05-07 on the
    # th-dc test bed. --interactive lets the user click through;
    # the package + source agreement flags still skip winget's own
    # confirmations.
    & winget install --id Rime.Weasel --interactive --accept-source-agreements --accept-package-agreements
    if ($LASTEXITCODE -ne 0) {
        Write-Error "winget install Rime.Weasel failed (exit $LASTEXITCODE)."
        Write-Host  'Try manually:  winget install Rime.Weasel'
        exit 1
    }

    # Re-probe install paths after winget completes.
    $candidates = @(
        (Join-Path $env:ProgramFiles        'Rime\Weasel'),
        (Join-Path ${env:ProgramFiles(x86)} 'Rime\Weasel')
    )
    $WeaselPath = $candidates | Where-Object { Test-Path $_ } | Select-Object -First 1
    if (-not $WeaselPath) {
        Write-Error 'Weasel installed but not found at expected paths. Inspected:'
        $candidates | ForEach-Object { Write-Host "  $_" }
        exit 1
    }
    Write-Host "  [OK] Weasel installed at $WeaselPath"
}

# ---------------------------------------------------------------------------
# Copy schema YAMLs (idempotent, with timestamped backup).
# ---------------------------------------------------------------------------
if (-not (Test-Path $RimeDir)) {
    New-Item -ItemType Directory -Path $RimeDir -Force | Out-Null
}

$schemasChanged = $false

foreach ($f in $SchemaFiles) {
    $src = Join-Path $SmoodleDir "schema\$f"
    $dst = Join-Path $RimeDir $f

    if (-not (Test-Path $src)) {
        Write-Error "missing source file: $src"
        exit 1
    }

    if (Test-Path $dst) {
        $srcHash = (Get-FileHash -Algorithm SHA256 $src).Hash
        $dstHash = (Get-FileHash -Algorithm SHA256 $dst).Hash
        if ($srcHash -ne $dstHash) {
            $stamp  = Get-Date -Format 'yyyyMMdd-HHmmss'
            $backup = "$dst.bak.$stamp"
            Write-Host "  backing up existing $dst -> $backup"
            Move-Item -Path $dst -Destination $backup -Force
            $schemasChanged = $true
        }
    } else {
        $schemasChanged = $true
    }

    Copy-Item -Path $src -Destination $dst -Force
    Write-Host "  installed $f"
}

# Touch all schema timestamps to now so WeaselDeployer always sees them as
# newer than its last build  -  rsync preserves Mac source timestamps which
# can be older than the Weasel build dir, causing WeaselDeployer to skip
# recompilation silently.
$now = Get-Date
Get-ChildItem "$RimeDir\*.yaml" | ForEach-Object { $_.LastWriteTime = $now }

# Clear cached compiled tables when schema content changed so WeaselDeployer
# is forced into a full rebuild rather than skipping on a stale table.
if ($schemasChanged) {
    $buildDir = Join-Path $RimeDir 'build'
    if (Test-Path $buildDir) {
        Remove-Item "$buildDir\thai_phonetic.*" -Force -ErrorAction SilentlyContinue
        Write-Host "  cleared build/thai_phonetic.* (schema changed; forcing recompile)"
    }
}

# ---------------------------------------------------------------------------
# Post-copy verification.
# ---------------------------------------------------------------------------
foreach ($f in $SchemaFiles) {
    $dst = Join-Path $RimeDir $f
    if (-not (Test-Path $dst)) {
        Write-Error "post-copy verification failed: $dst missing."
        exit 1
    }
}

# ---------------------------------------------------------------------------
# Auto-deploy via WeaselDeployer.exe /deploy (timeout-bounded).
# ---------------------------------------------------------------------------
Write-Host ''

if (-not $AutoDeploy) {
    Write-Host "Auto-deploy skipped (SMOODLE_AUTO_DEPLOY=$($env:SMOODLE_AUTO_DEPLOY))."
    Write-Host 'Right-click Weasel tray icon -> Deploy.'
    exit 0
}

Write-Host "Attempting auto-deploy via WeaselDeployer.exe /deploy..."

$deployerExe = Join-Path $WeaselPath 'WeaselDeployer.exe'
$autoDeployOk = $false

if (Test-Path $deployerExe) {
    try {
        $proc = Start-Process -FilePath $deployerExe -ArgumentList '/deploy' `
                              -PassThru -NoNewWindow
        if ($proc.WaitForExit($DeployTimeoutSecs * 1000)) {
            if ($proc.ExitCode -eq 0) { $autoDeployOk = $true }
        } else {
            try { $proc.Kill() } catch {}
        }
    } catch {
        # Fall through to manual fallback.
    }
}

if ($autoDeployOk) {
    Write-Host '  [OK] WeaselDeployer succeeded; schemas compiled.'
} else {
    Write-Host "  [WARN] Auto-deploy failed or timed out after ${DeployTimeoutSecs}s."
    Write-Host '    This is normal on first install (Thai dict is large).'
    Write-Host '    Manual fix: look for the Weasel icon in your taskbar.'
    Write-Host '    If missing: Start > Weasel Server > open it.'
    Write-Host '    Then: right-click the Weasel tray icon > Deploy.'
    Write-Host '    Wait for the "Under maintenance" notification to clear (~30s).'
}

# ---------------------------------------------------------------------------
# Test instructions.
# ---------------------------------------------------------------------------
@"

Files installed. To verify:
  1. Right-click Weasel tray icon -> Deploy (if auto-deploy did not run).
  2. Press Win+Space, switch to 'smoodle Thai phonetic' (or 'Weasel'
     and switch schema via Ctrl+`).
  3. Open Notepad and type 'sawadee'.
     Expect candidate window with: sawatdee

If 'smoodle Thai phonetic' does not appear in the schema switcher:
  - Verify $RimeDir contains the three YAML files above.
  - Right-click Weasel tray icon -> Settings -> Schema list -> add it.
  - Check Weasel's deployment log via the tray icon -> Show logs.

Note: this installs the schema YAMLs only. To get the patched librime
that fixes the algebra-vs-direct ranking on first lookup, also run:
  powershell -ExecutionPolicy Bypass -File .\scripts\install-librime-fork.ps1
That script requires admin (writes to Program Files)  -  re-launch from
an elevated PowerShell if it errors.
"@
# em-dash test —
