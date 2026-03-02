param(
    [Parameter(Mandatory = $true)]
    [string]$MainFlowExportPath,

    [Parameter(Mandatory = $true)]
    [string]$FlowRunLogsExporterPath
)

$ErrorActionPreference = 'Stop'

$repoRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$flowsDir = Join-Path $repoRoot 'flows'

if (!(Test-Path $MainFlowExportPath)) {
    throw "Main flow export file not found: $MainFlowExportPath"
}

if (!(Test-Path $FlowRunLogsExporterPath)) {
    throw "FlowRunLogs exporter file not found: $FlowRunLogsExporterPath"
}

if (!(Test-Path $flowsDir)) {
    New-Item -ItemType Directory -Path $flowsDir | Out-Null
}

Copy-Item -Path $MainFlowExportPath -Destination (Join-Path $flowsDir 'main.flow.json') -Force
Copy-Item -Path $FlowRunLogsExporterPath -Destination (Join-Path $flowsDir 'flowrunlogs-exporter.flow.json') -Force

Write-Host 'Flow exports copied successfully:'
Write-Host "- $(Join-Path $flowsDir 'main.flow.json')"
Write-Host "- $(Join-Path $flowsDir 'flowrunlogs-exporter.flow.json')"
