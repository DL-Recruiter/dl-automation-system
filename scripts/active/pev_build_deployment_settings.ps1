param(
    [ValidateSet("test", "prod")]
    [string]$EnvironmentName = "test",
    [string]$RepoPath = "",
    [string]$TemplatePath = "",
    [string]$OutputDirectory = "",
    [string]$MaterializeTo = "",
    [string]$TargetSchemaPath = ""
)

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$bgvScript = Join-Path $scriptDir "bgv_build_deployment_settings.ps1"

& $bgvScript `
    -EnvironmentName $EnvironmentName `
    -RepoPath $RepoPath `
    -TemplatePath $TemplatePath `
    -OutputDirectory $OutputDirectory `
    -MaterializeTo $MaterializeTo `
    -TargetSchemaPath $TargetSchemaPath
