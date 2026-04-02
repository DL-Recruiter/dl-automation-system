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
. (Join-Path (Split-Path -Parent (Split-Path -Parent $scriptDir)) "shared\bgv_migration_common.ps1")

if ([string]::IsNullOrWhiteSpace($RepoPath)) {
    $RepoPath = Get-BgvRepoRoot -CurrentPath $scriptDir
}

if ([string]::IsNullOrWhiteSpace($TemplatePath)) {
    $TemplatePath = Join-Path $RepoPath ("flows\power-automate\deployment-settings\{0}.settings.template.json" -f $EnvironmentName)
}

if ([string]::IsNullOrWhiteSpace($OutputDirectory)) {
    $OutputDirectory = Join-Path $RepoPath "out\deployment-settings"
}
if ([string]::IsNullOrWhiteSpace($TargetSchemaPath)) {
    $defaultTargetSchemaPath = Join-Path $RepoPath "out\migration\target_schema.json"
    if (Test-Path $defaultTargetSchemaPath) {
        $TargetSchemaPath = $defaultTargetSchemaPath
    }
}

Require-BgvCommand "pac"

if (-not (Test-Path $TemplatePath)) {
    throw "Template file not found: $TemplatePath"
}

$solutionFolder = Join-Path $RepoPath "flows\power-automate\unpacked"
if (-not (Test-Path (Join-Path $solutionFolder "Other\Solution.xml"))) {
    throw "Solution folder not found or invalid: $solutionFolder"
}

New-Item -ItemType Directory -Force -Path $OutputDirectory | Out-Null

Write-BgvStep "Generate base PAC settings"
$generatedSettingsPath = Join-Path $env:TEMP ("bgv_{0}_pac.settings.json" -f $EnvironmentName)
Invoke-BgvChecked -FilePath "pac" -Arguments @(
    "solution",
    "create-settings",
    "--solution-folder",
    $solutionFolder,
    "--settings-file",
    $generatedSettingsPath
)

$generatedSettings = ConvertFrom-BgvJson (Get-Content -Raw $generatedSettingsPath)
$template = ConvertFrom-BgvJson (Get-Content -Raw $TemplatePath)

$connectionIdMap = @{}
if ($template.ContainsKey("ConnectionIds")) {
    $connectionIdMap = $template.ConnectionIds
}
$knownConnectionEnvNames = [ordered]@{
    "cr94d_sharedmicrosoftforms_a2caf"    = @("BGV_CONN_MICROSOFTFORMS_ID", "PEV_CONN_MICROSOFTFORMS_ID")
    "cr94d_sharedoffice365_bdd97"         = @("BGV_CONN_OFFICE365_ID", "PEV_CONN_OFFICE365_ID")
    "cr94d_sharedsharepointonline_96d5d"  = @("BGV_CONN_SHAREPOINT_ID", "PEV_CONN_SHAREPOINT_ID")
    "cr94d_sharedteams_4466d"             = @("BGV_CONN_TEAMS_ID", "PEV_CONN_TEAMS_ID")
    "new_sharedwordonlinebusiness_2ff9a"  = @("BGV_CONN_WORDONLINEBUSINESS_ID", "PEV_CONN_WORDONLINEBUSINESS_ID")
}
$tokenValues = @{}
if ($template.ContainsKey("TokenValues")) {
    $tokenValues = $template.TokenValues
}
$knownTokenEnvAliases = [ordered]@{
    "BGV_SPO_SITE_URL"            = @("BGV_SPO_SITE_URL", "PEV_SPO_SITE_URL")
    "BGV_LIST_CANDIDATES_ID"      = @("BGV_LIST_CANDIDATES_ID", "PEV_LIST_CANDIDATES_ID")
    "BGV_LIST_REQUESTS_ID"        = @("BGV_LIST_REQUESTS_ID", "PEV_LIST_REQUESTS_ID")
    "BGV_LIST_FORMDATA_ID"        = @("BGV_LIST_FORMDATA_ID", "PEV_LIST_FORMDATA_ID")
    "BGV_LIBRARY_RECORDS_ID"      = @("BGV_LIBRARY_RECORDS_ID", "PEV_LIBRARY_RECORDS_ID")
    "BGV_AUTH_TEMPLATE_SOURCE"    = @("BGV_AUTH_TEMPLATE_SOURCE", "PEV_AUTH_TEMPLATE_SOURCE")
    "BGV_AUTH_TEMPLATE_DRIVE_ID"  = @("BGV_AUTH_TEMPLATE_DRIVE_ID", "PEV_AUTH_TEMPLATE_DRIVE_ID")
    "BGV_AUTH_TEMPLATE_FILE_ID"   = @("BGV_AUTH_TEMPLATE_FILE_ID", "PEV_AUTH_TEMPLATE_FILE_ID")
    "BGV_FORM1_ID"                = @("BGV_FORM1_ID", "PEV_FORM1_ID")
    "BGV_FORM2_ID"                = @("BGV_FORM2_ID", "PEV_FORM2_ID")
    "BGV_SHARED_MAILBOX_ADDRESS"  = @("BGV_SHARED_MAILBOX_ADDRESS", "PEV_SHARED_MAILBOX_ADDRESS")
    "BGV_INTERNAL_ALERT_TO"       = @("BGV_INTERNAL_ALERT_TO", "PEV_INTERNAL_ALERT_TO")
    "BGV_EMPLOYER_FALLBACK_TO"    = @("BGV_EMPLOYER_FALLBACK_TO", "PEV_EMPLOYER_FALLBACK_TO")
    "BGV_TEAMS_GROUP_ID"          = @("BGV_TEAMS_GROUP_ID", "PEV_TEAMS_GROUP_ID")
    "BGV_TEAMS_CHANNEL_ID"        = @("BGV_TEAMS_CHANNEL_ID", "PEV_TEAMS_CHANNEL_ID")
    "BGV_DOCX_PARSER_URI"         = @("BGV_DOCX_PARSER_URI", "PEV_DOCX_PARSER_URI")
}

if (-not [string]::IsNullOrWhiteSpace($TargetSchemaPath) -and (Test-Path $TargetSchemaPath)) {
    $targetSchema = ConvertFrom-BgvJson (Get-Content -Raw $TargetSchemaPath)
    $storeIdByTitle = @{}
    foreach ($store in @($targetSchema.Stores)) {
        if ($store.ContainsKey("StoreTitle") -and $store.ContainsKey("TargetStoreId")) {
            $storeIdByTitle[[string]$store.StoreTitle] = [string]$store.TargetStoreId
        }
    }

    if ($targetSchema.ContainsKey("TargetSiteUrl")) {
        $tokenValues["BGV_SPO_SITE_URL"] = [string]$targetSchema.TargetSiteUrl
    }
    if ($storeIdByTitle.ContainsKey("BGV_Candidates")) {
        $tokenValues["BGV_LIST_CANDIDATES_ID"] = $storeIdByTitle["BGV_Candidates"]
    }
    if ($storeIdByTitle.ContainsKey("BGV_Requests")) {
        $tokenValues["BGV_LIST_REQUESTS_ID"] = $storeIdByTitle["BGV_Requests"]
    }
    if ($storeIdByTitle.ContainsKey("BGV_FormData")) {
        $tokenValues["BGV_LIST_FORMDATA_ID"] = $storeIdByTitle["BGV_FormData"]
    }
    if ($storeIdByTitle.ContainsKey("BGV Records")) {
        $tokenValues["BGV_LIBRARY_RECORDS_ID"] = $storeIdByTitle["BGV Records"]
    }
    if ($targetSchema.ContainsKey("Template") -and $targetSchema.Template.ContainsKey("GraphMetadata")) {
        $graphMetadata = $targetSchema.Template.GraphMetadata
        if ($graphMetadata.ContainsKey("Source")) {
            $tokenValues["BGV_AUTH_TEMPLATE_SOURCE"] = [string]$graphMetadata.Source
        }
        if ($graphMetadata.ContainsKey("DriveId")) {
            $tokenValues["BGV_AUTH_TEMPLATE_DRIVE_ID"] = [string]$graphMetadata.DriveId
        }
        if ($graphMetadata.ContainsKey("FileId")) {
            $tokenValues["BGV_AUTH_TEMPLATE_FILE_ID"] = [string]$graphMetadata.FileId
        }
    }
}

foreach ($tokenName in $knownTokenEnvAliases.Keys) {
    foreach ($aliasName in @($knownTokenEnvAliases[$tokenName])) {
        $environmentValue = [Environment]::GetEnvironmentVariable([string]$aliasName)
        if (-not [string]::IsNullOrWhiteSpace($environmentValue)) {
            $tokenValues[$tokenName] = $environmentValue
            break
        }
    }
}

foreach ($connectionRef in $generatedSettings.ConnectionReferences) {
    $logicalName = [string]$connectionRef.LogicalName
    if ($knownConnectionEnvNames.Contains($logicalName)) {
        foreach ($envName in @($knownConnectionEnvNames[$logicalName])) {
            $environmentConnectionId = [Environment]::GetEnvironmentVariable([string]$envName)
            if (-not [string]::IsNullOrWhiteSpace($environmentConnectionId)) {
                $connectionRef.ConnectionId = [string]$environmentConnectionId
                break
            }
        }
        if (-not [string]::IsNullOrWhiteSpace([string]$connectionRef.ConnectionId)) {
            continue
        }
    }
    if ($connectionIdMap.ContainsKey($logicalName)) {
        $connectionRef.ConnectionId = [string]$connectionIdMap[$logicalName]
    }
}

$generatedSettings.EnvironmentVariables = @()
$generatedSettings.CopilotAgents = @()
$pacOutputPath = Join-Path $OutputDirectory ("{0}.pac.settings.json" -f $EnvironmentName)
$generatedSettings | ConvertTo-Json -Depth 8 | Set-Content -Path $pacOutputPath -Encoding utf8

$tokenOutputPath = Join-Path $OutputDirectory ("{0}.token-values.json" -f $EnvironmentName)
$tokenPayload = [ordered]@{
    EnvironmentName = $EnvironmentName
    TokenValues     = $tokenValues
}
$tokenPayload | ConvertTo-Json -Depth 8 | Set-Content -Path $tokenOutputPath -Encoding utf8

Write-BgvInfo "PAC settings written to $pacOutputPath"
Write-BgvInfo "Token values written to $tokenOutputPath"

if (-not [string]::IsNullOrWhiteSpace($MaterializeTo)) {
    Write-BgvStep "Materialize tokenized solution"
    if (Test-Path $MaterializeTo) {
        Remove-Item -Recurse -Force $MaterializeTo
    }
    Copy-Item -Recurse -Force $solutionFolder $MaterializeTo

    $textFiles = Get-ChildItem -Path $MaterializeTo -Recurse -File | Where-Object {
        $_.Extension -in @(".json", ".xml", ".txt", ".md")
    }

    foreach ($file in $textFiles) {
        $content = Get-Content -Raw $file.FullName
        foreach ($tokenName in $tokenValues.Keys) {
            $tokenMarker = "__{0}__" -f $tokenName
            $replacement = [string]$tokenValues[$tokenName]
            $content = $content.Replace($tokenMarker, $replacement)
        }
        [System.IO.File]::WriteAllText(
            $file.FullName,
            $content,
            [System.Text.UTF8Encoding]::new($false)
        )
    }

    Write-BgvInfo "Materialized solution folder written to $MaterializeTo"
}
