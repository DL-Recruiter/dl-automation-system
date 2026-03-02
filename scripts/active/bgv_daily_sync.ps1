param(
    [string]$RepoPath = "",
    [string]$SolutionName = "BGV_System",
    [string]$ExportZipPath = "",
    [string]$UnpackFolderPath = "",
    [string]$EnvironmentUrl = "",
    [switch]$SkipPull,
    [switch]$SkipExport,
    [switch]$SkipUnpack,
    [switch]$RunTests,
    [string]$PythonExe = "python"
)

$ErrorActionPreference = "Stop"

function Write-Info {
    param([string]$Message)
    Write-Host "[INFO] $Message"
}

function Write-Step {
    param([string]$Message)
    Write-Host ""
    Write-Host "=== $Message ==="
}

function Require-Command {
    param([string]$Name)
    if (-not (Get-Command $Name -ErrorAction SilentlyContinue)) {
        throw "Required command not found in PATH: $Name"
    }
}

function Invoke-Checked {
    param(
        [Parameter(Mandatory = $true)]
        [string]$FilePath,
        [Parameter(Mandatory = $true)]
        [string[]]$Arguments,
        [string]$WorkingDirectory = ""
    )

    if ($WorkingDirectory) {
        Push-Location $WorkingDirectory
    }
    try {
        & $FilePath @Arguments
        if ($LASTEXITCODE -ne 0) {
            throw "Command failed with exit code ${LASTEXITCODE}: $FilePath $($Arguments -join ' ')"
        }
    }
    finally {
        if ($WorkingDirectory) {
            Pop-Location
        }
    }
}

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$defaultRepo = Split-Path -Parent (Split-Path -Parent $scriptDir)

if ([string]::IsNullOrWhiteSpace($RepoPath)) {
    $RepoPath = $defaultRepo
}
if ([string]::IsNullOrWhiteSpace($ExportZipPath)) {
    $ExportZipPath = Join-Path $RepoPath "artifacts\exports\${SolutionName}_unmanaged.zip"
}
if ([string]::IsNullOrWhiteSpace($UnpackFolderPath)) {
    $UnpackFolderPath = Join-Path $RepoPath "flows\power-automate\unpacked"
}

Write-Step "Preflight checks"
Require-Command "git"
Require-Command "pac"

if (-not (Test-Path (Join-Path $RepoPath ".git"))) {
    throw "RepoPath does not look like a git repository: $RepoPath"
}

New-Item -ItemType Directory -Force -Path (Split-Path -Parent $ExportZipPath) | Out-Null
New-Item -ItemType Directory -Force -Path $UnpackFolderPath | Out-Null

Write-Info "RepoPath: $RepoPath"
Write-Info "SolutionName: $SolutionName"
Write-Info "ExportZipPath: $ExportZipPath"
Write-Info "UnpackFolderPath: $UnpackFolderPath"
if (-not [string]::IsNullOrWhiteSpace($EnvironmentUrl)) {
    Write-Info "EnvironmentUrl override: $EnvironmentUrl"
}

Write-Step "Active PAC identity"
Invoke-Checked -FilePath "pac" -Arguments @("auth", "who")

if (-not $SkipPull) {
    Write-Step "Git pull --ff-only"
    Invoke-Checked -FilePath "git" -Arguments @("-C", $RepoPath, "pull", "--ff-only")
}
else {
    Write-Info "Skipping git pull"
}

$envArgs = @()
if (-not [string]::IsNullOrWhiteSpace($EnvironmentUrl)) {
    $envArgs = @("--environment", $EnvironmentUrl)
}

if (-not $SkipExport) {
    Write-Step "Export solution"
    $exportArgs = @("solution", "export") + $envArgs + @("--name", $SolutionName, "--path", $ExportZipPath, "--managed", "false", "--overwrite")
    Invoke-Checked -FilePath "pac" -Arguments $exportArgs
}
else {
    Write-Info "Skipping solution export"
}

if (-not $SkipUnpack) {
    Write-Step "Unpack solution"
    $unpackArgs = @("solution", "unpack", "--zipfile", $ExportZipPath, "--folder", $UnpackFolderPath, "--packagetype", "Unmanaged", "--allowDelete", "true", "--allowWrite", "true", "--clobber", "true")
    Invoke-Checked -FilePath "pac" -Arguments $unpackArgs
}
else {
    Write-Info "Skipping solution unpack"
}

if ($RunTests) {
    Write-Step "Run tests"
    Require-Command $PythonExe
    Invoke-Checked -FilePath $PythonExe -Arguments @("-m", "pytest", "-q", "tests") -WorkingDirectory $RepoPath
}
else {
    Write-Info "Skipping tests (use -RunTests to enable)"
}

Write-Step "Done"
Write-Info "Daily sync completed successfully."
Write-Info "Next recommended commands:"
Write-Info "  git -C `"$RepoPath`" status --short --branch"
Write-Info "  git -C `"$RepoPath`" diff -- flows/power-automate/unpacked/Workflows/"
