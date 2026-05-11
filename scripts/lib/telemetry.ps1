# smoodle telemetry client - PowerShell fire-and-forget POST helper (TELEM-03)
#
# Dot-sourced by install-windows.ps1.
# Usage:
#   . "$PSScriptRoot\lib\telemetry.ps1"
#   Invoke-SmoodleTelemetryEvent -EventName "install_started"
#
# Opt-in: $env:SMOODLE_TELEMETRY -eq '1' or $env:USERPROFILE\.smoodle\telemetry-on
# When not opted in, this file is a no-op (zero network traffic).
#
# Hard 3s timeout, no retries, no daemon, never blocks installer.
# ASCII-only (PITFALLS MP-4).

$ErrorActionPreference = 'Stop'

$Script:SmoodleTelemetryUrl = if ($env:SMOODLE_TELEMETRY_URL) {
    $env:SMOODLE_TELEMETRY_URL
} else {
    'https://telemetry.0dl.me/api/send'
}

$Script:SmoodleTelemetryWebsite = 'a1b2c3d4-e5f6-7890-abcd-ef1234567890'
$Script:SmoodleVersion = '0.0.6'

function Test-SmoodleTelemetryOptedIn {
    if ($env:SMOODLE_TELEMETRY -eq '1') {
        return $true
    }
    $markerPath = Join-Path $env:USERPROFILE '.smoodle\telemetry-on'
    if (Test-Path $markerPath) {
        return $true
    }
    return $false
}

function Get-SmoodleInstallIdHash {
    $installIdDir = Join-Path $env:USERPROFILE '.smoodle'
    $installIdFile = Join-Path $installIdDir 'install_id'

    if (-not (Test-Path $installIdFile)) {
        if (-not (Test-Path $installIdDir)) {
            New-Item -ItemType Directory -Path $installIdDir -Force | Out-Null
        }
        # Generate 16 random bytes via crypto RNG, then SHA-256 hash.
        $rng = [System.Security.Cryptography.RandomNumberGenerator]::Create()
        $bytes = New-Object byte[] 16
        $rng.GetBytes($bytes)
        $hex = ($bytes | ForEach-Object { $_.ToString('x2') }) -join ''
        $hashBytes = [System.Security.Cryptography.SHA256]::Create().ComputeHash(
            [System.Text.Encoding]::UTF8.GetBytes($hex))
        $hash = ($hashBytes | ForEach-Object { $_.ToString('x2') }) -join ''
        Set-Content -Path $installIdFile -Value $hash -Encoding ASCII
        return $hash
    }

    return (Get-Content -Path $installIdFile -Encoding ASCII).Trim()
}

function Invoke-SmoodleTelemetryEvent {
    param(
        [Parameter(Mandatory = $true)]
        [string]$EventName,

        [string]$LibrimeShaMatch = 'true'
    )

    # Opt-in gate - fast path, no network if not opted in.
    if (-not (Test-SmoodleTelemetryOptedIn)) {
        return
    }

    # Empty URL means disabled.
    if (-not $Script:SmoodleTelemetryUrl) {
        return
    }

    $installIdHash = Get-SmoodleInstallIdHash

    $payload = @{
        type = 'event'
        payload = @{
            website = $Script:SmoodleTelemetryWebsite
            url     = '/install'
            name    = $EventName
            data    = @{
                install_id_hash = $installIdHash
                os              = 'windows'
                smoodle_version = $Script:SmoodleVersion
                librime_sha_match = $LibrimeShaMatch -eq 'true'
            }
        }
    } | ConvertTo-Json -Depth 4 -Compress

    # Fire-and-forget: Start-Job, 3s timeout, swallow all output.
    Start-Job -ScriptBlock {
        param($url, $body)
        try {
            $null = Invoke-RestMethod -Uri $url -Method Post `
                -Body $body -ContentType 'application/json' `
                -TimeoutSec 3 -ErrorAction SilentlyContinue
        } catch {
            # Silent failure - fire-and-forget.
        }
    } -ArgumentList $Script:SmoodleTelemetryUrl, $payload | Out-Null
}
