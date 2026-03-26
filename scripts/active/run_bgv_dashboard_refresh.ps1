[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$repoRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$logDirectory = Join-Path $repoRoot "out\logs"
$logPath = Join-Path $logDirectory "bgv_dashboard_refresh.log"

if (-not (Test-Path $logDirectory)) {
    New-Item -Path $logDirectory -ItemType Directory -Force | Out-Null
}

$timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
Add-Content -Path $logPath -Value "[$timestamp] Starting dashboard refresh"

Push-Location $repoRoot
try {
    & powershell -NoProfile -ExecutionPolicy Bypass -File ".\scripts\active\build_bgv_dashboard.ps1" -UploadToSharePoint 2>&1 |
        Tee-Object -FilePath $logPath -Append

    $finishTimestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    Add-Content -Path $logPath -Value "[$finishTimestamp] Dashboard refresh completed"
}
finally {
    Pop-Location
}
