[CmdletBinding()]
param(
    [string]$TaskName = "DLR BGV Dashboard Refresh"
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$repoRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$runnerPath = Join-Path $repoRoot "scripts\active\run_bgv_dashboard_refresh.ps1"

if (-not (Test-Path $runnerPath)) {
    throw "Dashboard runner script not found at: $runnerPath"
}

$action = New-ScheduledTaskAction `
    -Execute "powershell.exe" `
    -Argument "-NoProfile -ExecutionPolicy Bypass -File `"$runnerPath`""

$triggerTimes = @(
    [datetime]"09:00",
    [datetime]"12:00",
    [datetime]"15:00",
    [datetime]"18:00",
    [datetime]"21:00"
)

$triggers = @(
    foreach ($time in $triggerTimes) {
        New-ScheduledTaskTrigger -Daily -At $time
    }
)

$principal = New-ScheduledTaskPrincipal `
    -UserId "$env:USERDOMAIN\$env:USERNAME" `
    -LogonType Interactive `
    -RunLevel Limited

$settings = New-ScheduledTaskSettingsSet `
    -StartWhenAvailable `
    -AllowStartIfOnBatteries `
    -DontStopIfGoingOnBatteries

$task = New-ScheduledTask `
    -Action $action `
    -Trigger $triggers `
    -Principal $principal `
    -Settings $settings

Register-ScheduledTask -TaskName $TaskName -InputObject $task -Force | Out-Null

Write-Output "Registered scheduled task: $TaskName"
Write-Output "Runs daily at 09:00, 12:00, 15:00, 18:00, 21:00."
