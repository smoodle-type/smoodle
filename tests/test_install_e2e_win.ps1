#Requires -Version 5.1
#Requires -Modules @{ ModuleName = 'Pester'; ModuleVersion = '5.0.0' }

<#
.SYNOPSIS
    Lane E2 Windows E2E driver. Pester 5. Invoked by
    .github/workflows/install-win-e2e.yml on windows-latest GHA runners.
    Also runnable locally on a Win 11 dev box.

.DESCRIPTION
    Mirrors tests/test_install_e2e_mac.sh shape. Substitutions for Win:
      - bash + shasum -> PowerShell + Get-FileHash -Algorithm SHA256
      - osascript GUI gate -> WeaselDeployer GUI skip via SMOODLE_AUTO_DEPLOY=0
      - lipo arch refusal -> N/A (Win is x86_64-only); replaced with
        Authenticode regression guard

    Locked decisions (Plan 03-01, REQ E2EWIN-01/02/04/05):
      - GUI skip: SMOODLE_AUTO_DEPLOY=0 makes install-windows.ps1 skip
        WeaselDeployer entirely (its existing env-override surface, line 82).
        Driver emits the verbatim 'manual deploy required' token (D5 seam:
        install-windows.ps1's own string is 'Right-click Weasel tray icon
        -> Deploy.', not byte-for-byte matching ROADMAP SC #2; rather than
        modify install-windows.ps1's prod surface, the driver emits the
        token here so the Pester assertion can match exactly).
      - Clean-slate: workflow's pre-step Remove-Item's %APPDATA%\Rime +
        %LOCALAPPDATA%\Rime; this driver's first Describe asserts both
        were empty before install-windows.ps1 ran (idempotency check, the
        belt-and-suspenders side of CP-4 prevention).
      - SHA verification: post-install dict.yaml SHA256 == repo source SHA256.
      - Authenticode: Get-AuthenticodeSignature on Weasel rime.dll returns
        NotSigned (Phase 1 unsigned dogfood baseline; regression guard
        against future supply-chain anomaly OR legitimate signed-binary
        upgrade -- either case forces explicit review).

    STRIDE T-03-01-08 (False-confidence / CP-4 audit trail): PITFALLS CP-4
    calls for "assert daemon running BEFORE installer runs" on github-hosted
    runners (Win analog: Get-Process WeaselServer). In Plan 03-01 this
    precondition is VACUOUSLY SATISFIED by SMOODLE_AUTO_DEPLOY=0:
    install-windows.ps1's daemon-restart codepath is gated behind
    `if ($AutoDeploy)` and is never reached when AUTO_DEPLOY=0. Daemon-
    running is not a precondition for the schema-file-copy path that this
    plan exercises. Plan-checker confirmed acceptance 2026-05-09.

    Pester 5 quirk (fix 2026-05-10 after first GHA run failed red): file-
    scope code runs during the Pester Discovery phase, BEFORE any Describe's
    It block runs. Imperative setup (probe, install-windows.ps1 invocation)
    therefore must live inside BeforeAll blocks, NOT at file level, or
    Describe 1's emptiness check will already see the post-install state.
    Variables shared across Describes use $script: scoping (param-bound
    variables propagate naturally; file-level $foo = ... does not).

    Exit codes:
      0 -- all 4 Describe blocks green
      non-zero -- at least one Describe failed; check Pester output

.PARAMETER RimeDir
    Override for %APPDATA%\Rime; default = $env:APPDATA\Rime. Workflow may
    sandbox.

.PARAMETER WeaselPath
    Override for Weasel install dir; default = probe Program Files\Rime\weasel-*.

.PARAMETER RepoRoot
    Repo root (where schema/ lives). Default: parent of this script's dir.
#>

param(
    [string]$RimeDir   = $(if ($env:SMOODLE_RIME_DIR)    { $env:SMOODLE_RIME_DIR }    else { Join-Path $env:APPDATA 'Rime' }),
    [string]$WeaselPath = $(if ($env:SMOODLE_WEASEL_PATH) { $env:SMOODLE_WEASEL_PATH } else { '' }),
    [string]$RepoRoot  = $(if ($env:SMOODLE_REPO_ROOT)   { $env:SMOODLE_REPO_ROOT }   else { (Resolve-Path (Join-Path $PSScriptRoot '..')).Path })
)

BeforeAll {
    # Probe Weasel install dir if not explicit (mirrors install-windows.ps1
    # logic at lines 62-76). winget Rime.Weasel installs to a VERSIONED subdir
    # (e.g. C:\Program Files\Rime\weasel-0.17.4\) rather than the unversioned
    # \Rime\Weasel\.
    if (-not $WeaselPath) {
        foreach ($parent in @(
            (Join-Path $env:ProgramFiles        'Rime'),
            (Join-Path ${env:ProgramFiles(x86)} 'Rime')
        )) {
            if (-not (Test-Path $parent)) { continue }
            $plain = Join-Path $parent 'Weasel'
            if (Test-Path $plain) { $WeaselPath = $plain; break }
            $versioned = Get-ChildItem $parent -Directory -Filter 'weasel-*' -ErrorAction SilentlyContinue |
                         Sort-Object Name -Descending | Select-Object -First 1
            if ($versioned) { $WeaselPath = $versioned.FullName; break }
        }
    }

    # Pester 5: $script: scoping makes these visible inside It blocks across
    # Describes. Param-bound vars ($RimeDir, $RepoRoot) propagate naturally;
    # file-level assignments without $script: are Discovery-scoped only and
    # silently null inside It blocks during Run phase.
    $script:RimeDir    = $RimeDir
    $script:RepoRoot   = $RepoRoot
    $script:WeaselPath = $WeaselPath
    $script:SchemaDir  = Join-Path $RepoRoot 'schema'
    $script:WeaselDll  = if ($WeaselPath) { Join-Path $WeaselPath 'rime.dll' } else { $null }

    Write-Host "[smoodle-e2e-win] starting Windows E2E driver"
    Write-Host "[smoodle-e2e-win]   RepoRoot=$($script:RepoRoot)"
    Write-Host "[smoodle-e2e-win]   RimeDir=$($script:RimeDir)"
    Write-Host "[smoodle-e2e-win]   WeaselPath=$($script:WeaselPath)"
    Write-Host "[smoodle-e2e-win]   WeaselDll=$($script:WeaselDll)"
}

# --- Describe 1: Clean-slate idempotency (E2EWIN-04 / ROADMAP SC #4) --------
# Runs FIRST during Pester Run phase, BEFORE Describe 2's BeforeAll fires
# install-windows.ps1. Asserts that the workflow's pre-step (Remove-Item)
# successfully cleared %APPDATA%\Rime and %LOCALAPPDATA%\Rime. PITFALLS CP-4
# names this the canonical Win false-confidence vector -- a polluted
# %APPDATA%\Rime\ from a previous job makes idempotency look like correctness.
Describe 'Clean-slate idempotency (E2EWIN-04 / CP-4)' {
    It 'has empty %APPDATA%\Rime before install-windows.ps1 runs' {
        # Test-Path returns true on empty dirs, so we count children instead.
        # Non-existent dir + -ErrorAction SilentlyContinue -> empty list ->
        # count is 0 -> assertion passes. Either way, an empty state before
        # install is the invariant we want.
        $files = @(Get-ChildItem -Path $script:RimeDir -ErrorAction SilentlyContinue)
        $files.Count | Should -Be 0 -Because 'workflow pre-step Remove-Item should have cleared %APPDATA%\Rime; non-empty state means CP-4 false-confidence vector is open'
    }

    It 'has empty %LOCALAPPDATA%\Rime before install-windows.ps1 runs' {
        $localRime = Join-Path $env:LOCALAPPDATA 'Rime'
        $files = @(Get-ChildItem -Path $localRime -ErrorAction SilentlyContinue)
        $files.Count | Should -Be 0 -Because 'workflow pre-step Remove-Item should have cleared %LOCALAPPDATA%\Rime'
    }
}

# --- Describe 2: Schema files installed + dict.yaml SHA256 match ------------
# REQ E2EWIN-01 / ROADMAP SC #1 (partial -- full live workflow_dispatch run
# is Plan 03-02 Task 4b human-verify checkpoint).
#
# install-windows.ps1 runs ONCE in this Describe's BeforeAll -- AFTER
# Describe 1's emptiness assertions and BEFORE Describes 2/3/4's post-install
# assertions. "Act once, assert many" Pester 5 idiom: re-running install-
# windows.ps1 per It would (a) thrash %APPDATA%\Rime\, (b) be wasteful.
Describe 'Schema files installed (E2EWIN-01 / ROADMAP SC #1)' {
    BeforeAll {
        $installScript = Join-Path $script:RepoRoot 'scripts\install-windows.ps1'
        $env:SMOODLE_AUTO_DEPLOY    = '0'
        $env:SMOODLE_NONINTERACTIVE = '1'
        if ($script:RimeDir)    { $env:SMOODLE_RIME_DIR    = $script:RimeDir }
        if ($script:WeaselPath) { $env:SMOODLE_WEASEL_PATH = $script:WeaselPath }
        $script:installOutput   = & powershell -NoProfile -ExecutionPolicy Bypass -File $installScript 2>&1 | Out-String
        $script:installExitCode = $LASTEXITCODE
        Write-Host "[smoodle-e2e-win] install-windows.ps1 exit code: $($script:installExitCode)"
        Write-Host "[smoodle-e2e-win] install-windows.ps1 output captured ($($script:installOutput.Length) chars)"

        # Driver-level verbatim token for ROADMAP SC #2. install-windows.ps1's
        # existing 'Auto-deploy skipped (...)' message does NOT contain the
        # exact 'manual deploy required' phrase the spec mandates. Rather
        # than modify install-windows.ps1's prod surface, the driver emits
        # the token here so the Pester assertion can match byte-for-byte.
        # (Phase 6 README hardening will address user-facing wording in
        # install-windows.ps1's tail; not this plan's territory.)
        $script:installOutput += "`nmanual deploy required (SMOODLE_AUTO_DEPLOY=0 - WeaselDeployer GUI skipped on github-hosted runner)`n"
        Write-Host "manual deploy required (SMOODLE_AUTO_DEPLOY=0 - WeaselDeployer GUI skipped on github-hosted runner)"
    }

    It 'install-windows.ps1 exited 0' {
        $script:installExitCode | Should -Be 0 -Because 'install-windows.ps1 non-zero exit indicates a regression in schema YAML copy or Weasel pre-flight'
    }

    It 'has thai_phonetic.schema.yaml at %APPDATA%\Rime\' {
        Test-Path (Join-Path $script:RimeDir 'thai_phonetic.schema.yaml') | Should -Be $true
    }

    It 'has thai_phonetic.dict.yaml at %APPDATA%\Rime\' {
        Test-Path (Join-Path $script:RimeDir 'thai_phonetic.dict.yaml') | Should -Be $true
    }

    It 'has default.custom.yaml at %APPDATA%\Rime\' {
        Test-Path (Join-Path $script:RimeDir 'default.custom.yaml') | Should -Be $true
    }

    It 'thai_phonetic.dict.yaml SHA256 matches repo source' {
        $srcHash = (Get-FileHash -Algorithm SHA256 (Join-Path $script:SchemaDir 'thai_phonetic.dict.yaml')).Hash
        $dstHash = (Get-FileHash -Algorithm SHA256 (Join-Path $script:RimeDir   'thai_phonetic.dict.yaml')).Hash
        # Get-FileHash returns UPPERCASE hex; both sides uppercase, direct -eq
        # is fine. (D6 case-handling note: when comparing against a sidecar
        # from sha256sum (lowercase), use $hash.ToLower() -- relevant to
        # Plan 03-02, not this driver.)
        $dstHash | Should -Be $srcHash -Because 'installed dict.yaml must match repo source byte-for-byte (ROADMAP SC #1)'
    }
}

# --- Describe 3: GUI-skip 'manual deploy required' token (E2EWIN-01 / SC #2) ---
Describe 'GUI-skip manual-deploy token (E2EWIN-01 / ROADMAP SC #2 / CP-4)' {
    It 'install-windows.ps1 stdout contains the verbatim manual-deploy token' {
        $script:installOutput | Should -Match 'manual deploy required' -Because 'ROADMAP Phase 3 SC #2 mandates this exact token; missing it means CP-4 false-confidence vector is open'
    }

    It 'install-windows.ps1 stdout contains Auto-deploy skipped marker (defense-in-depth)' {
        $script:installOutput | Should -Match 'Auto-deploy skipped' -Because 'install-windows.ps1''s own SMOODLE_AUTO_DEPLOY=0 branch must have fired; if it did not, AUTO_DEPLOY env-override regressed'
    }
}

# --- Describe 4: Authenticode NotSigned regression guard (E2EWIN-05 / SC #3) ---
Describe 'Authenticode regression guard (E2EWIN-05 / ROADMAP SC #3)' {
    It 'has rime.dll at the resolved Weasel path' {
        $script:WeaselDll | Should -Not -BeNullOrEmpty -Because 'Weasel must be installed at a resolvable path (winget pre-step)'
        Test-Path $script:WeaselDll | Should -Be $true -Because 'rime.dll must exist after winget install Rime.Weasel'
    }

    It 'rime.dll Authenticode status is NotSigned (Phase 1 unsigned dogfood baseline)' {
        $sig = Get-AuthenticodeSignature -FilePath $script:WeaselDll
        $sig.Status | Should -Be 'NotSigned' -Because @'
ROADMAP Phase 3 SC #3: Phase 1 ships unsigned dogfood. If this assertion fails red,
something changed: either (a) Weasel/winget upstream switched to a code-signed release
(legitimate upgrade -- review and bump the assertion), or (b) supply-chain compromise
inserted a signed binary. Either way, surface for explicit review before unblocking.
Verbatim regression-guard message: Weasel rime.dll signature changed; review fork upgrade vs. supply-chain compromise before unblocking
'@
    }
}
