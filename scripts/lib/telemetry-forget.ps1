# smoodle telemetry forget - PowerShell (TELEM-06)
#
# Usage: powershell -ExecutionPolicy Bypass -File scripts\lib\telemetry-forget.ps1
# Sends DELETE to the forget-api sidecar, then removes local telemetry files.
# Idempotent: running twice exits 0 with "No telemetry data found."

$ErrorActionPreference = 'Stop'

$InstallIdFile = Join-Path $env:USERPROFILE '.smoodle\install_id'
$TelemetryMarker = Join-Path $env:USERPROFILE '.smoodle\telemetry-on'
$ForgetUrl = if ($env:SMOODLE_FORGET_URL) { $env:SMOODLE_FORGET_URL } `
             else { 'http://localhost:8080/api/forget' }

if (-not (Test-Path $InstallIdFile)) {
    Write-Host 'No telemetry data found (no install_id).'
    Write-Host 'If you previously opted in, events may have already been purged.'
    exit 0
}

$InstallIdHash = (Get-Content -Path $InstallIdFile -Encoding ASCII).Trim()

Write-Host 'Deleting telemetry events for this install...'
Write-Host "  install_id_hash: $($InstallIdHash.Substring(0, 16))..."

try {
    $uri = "$ForgetUrl?install_id_hash=$InstallIdHash"
    $response = Invoke-RestMethod -Uri $uri -Method Delete `
        -TimeoutSec 10 -ErrorAction Stop
    $deletedCount = $response.deleted
    Write-Host "  Deleted $deletedCount event(s) from server."
} catch {
    Write-Host "  [WARN] forget API request failed: $($_.Exception.Message)"
    Write-Host '  Events may still have been deleted. Proceeding with local cleanup.'
}

# Remove local telemetry files.
Remove-Item -Path $InstallIdFile -Force -ErrorAction SilentlyContinue
Remove-Item -Path $TelemetryMarker -Force -ErrorAction SilentlyContinue
Write-Host '  Local telemetry files removed.'
Write-Host 'Done.'
