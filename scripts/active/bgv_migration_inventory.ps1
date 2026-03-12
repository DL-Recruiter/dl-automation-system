param(
    [string]$SourceSiteUrl = $env:BGV_SOURCE_SPO_SITE_URL,
    [string]$TargetSiteUrl = $env:BGV_TARGET_SPO_SITE_URL,
    [string]$OutputPath = "",
    [string]$ClientId = $env:PNP_CLIENT_ID,
    [string]$TenantId = $env:PNP_TENANT_ID,
    [string]$TemplateFileName = "AuthorizationLetter_Template.docx"
)

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
. (Join-Path (Split-Path -Parent (Split-Path -Parent $scriptDir)) "shared\bgv_migration_common.ps1")

if ([string]::IsNullOrWhiteSpace($SourceSiteUrl)) {
    throw "SourceSiteUrl must be provided via parameter or BGV_SOURCE_SPO_SITE_URL."
}
if ([string]::IsNullOrWhiteSpace($TargetSiteUrl)) {
    throw "TargetSiteUrl must be provided via parameter or BGV_TARGET_SPO_SITE_URL."
}

$repoRoot = Get-BgvRepoRoot -CurrentPath $scriptDir
if ([string]::IsNullOrWhiteSpace($OutputPath)) {
    $OutputPath = Join-Path $repoRoot "out\migration\inventory.json"
}

function Get-BgvTemplateCandidates {
    param(
        [Parameter(Mandatory = $true)]
        $Connection,
        [Parameter(Mandatory = $true)]
        [string]$FileName
    )

    $matches = @()
    $libraries = @(Get-PnPList -Connection $Connection | Where-Object { $_.BaseTemplate -eq 101 })
    foreach ($library in $libraries) {
        $items = @(Get-PnPListItem -List $library.Title -Connection $Connection -PageSize 2000 -Fields "FileLeafRef", "FileRef", "FSObjType" | Where-Object {
                $_["FSObjType"] -eq 0 -and [string]$_.FieldValues["FileLeafRef"] -eq $FileName
            })
        foreach ($item in $items) {
            $matches += [ordered]@{
                LibraryTitle = $library.Title
                FileName     = [string]$item["FileLeafRef"]
                FileRef      = [string]$item["FileRef"]
            }
        }
    }
    return $matches
}

function Get-BgvSharingSnapshot {
    param([Parameter(Mandatory = $true)][string]$Url)

    Require-BgvCommand "m365"
    $statusOutput = & m365 status
    if ($LASTEXITCODE -ne 0 -or ($statusOutput -match "Logged out")) {
        throw "CLI for Microsoft 365 is not logged in. Run 'm365 login --authType browser' first."
    }

    $siteJson = & m365 spo site get --url $Url --output json
    if ($LASTEXITCODE -ne 0) {
        throw "Unable to fetch site sharing information for $Url"
    }

    $siteInfo = ConvertFrom-BgvJson $siteJson
    $sharingPairs = @()
    foreach ($key in $siteInfo.Keys) {
        if ($key -match "sharing") {
            $sharingPairs += [ordered]@{
                Name  = $key
                Value = [string]$siteInfo[$key]
            }
        }
    }

    $supportsAnonymous = $false
    foreach ($pair in $sharingPairs) {
        if ($pair.Value -match "Guest" -or $pair.Value -match "Anyone" -or $pair.Value -match "anonymous") {
            $supportsAnonymous = $true
            break
        }
    }

    return [ordered]@{
        RawProperties      = $sharingPairs
        SupportsAnonymous  = $supportsAnonymous
    }
}

Write-BgvStep "Connect to source and target SharePoint sites"
$sourceConnection = Connect-BgvPnPSite -Url $SourceSiteUrl -ClientId $ClientId -TenantId $TenantId
$targetConnection = Connect-BgvPnPSite -Url $TargetSiteUrl -ClientId $ClientId -TenantId $TenantId

Write-BgvStep "Collect list and library inventory"
$stores = @()
$targetConflicts = @()
foreach ($spec in Get-BgvStoreSpecifications) {
    $sourceInventory = Get-BgvListInventory -Connection $sourceConnection -Title $spec.Title
    $targetInventory = Get-BgvListInventory -Connection $targetConnection -Title $spec.Title

    $comparison = [ordered]@{
        MissingOnTarget = -not [bool]$targetInventory.Exists
        BaseTemplateMatches = $false
        MissingFieldInternalNames = @()
    }

    if ($sourceInventory.Exists -and $targetInventory.Exists) {
        $comparison.BaseTemplateMatches = [int]$sourceInventory.BaseTemplate -eq [int]$targetInventory.BaseTemplate
        $targetFieldNames = @($targetInventory.Fields | ForEach-Object { $_.InternalName })
        $requiredFieldNames = @("Title", $spec.KeyField)
        foreach ($field in Get-BgvProvisionableFields -Connection $sourceConnection -ListTitle $spec.Title) {
            $requiredFieldNames += $field.InternalName
        }
        $comparison.MissingFieldInternalNames = @($requiredFieldNames | Sort-Object -Unique | Where-Object { $_ -notin $targetFieldNames })
        if (-not $comparison.BaseTemplateMatches -or $comparison.MissingFieldInternalNames.Count -gt 0) {
            $targetConflicts += [ordered]@{
                StoreTitle              = $spec.Title
                BaseTemplateMatches     = $comparison.BaseTemplateMatches
                MissingFieldInternalNames = $comparison.MissingFieldInternalNames
            }
        }
    }

    $stores += [ordered]@{
        Title      = $spec.Title
        Kind       = $spec.Kind
        KeyField   = $spec.KeyField
        Source     = $sourceInventory
        Target     = $targetInventory
        Comparison = $comparison
    }
}

Write-BgvStep "Classify blue case history"
$manifest = Get-BgvCaseManifest -Connection $sourceConnection

Write-BgvStep "Inspect template candidates"
$sourceTemplateMatches = Get-BgvTemplateCandidates -Connection $sourceConnection -FileName $TemplateFileName
$repoTemplatePath = Join-Path $repoRoot $TemplateFileName

Write-BgvStep "Inspect target sharing capability"
$sharingSnapshot = Get-BgvSharingSnapshot -Url $TargetSiteUrl

$payload = [ordered]@{
    GeneratedAtUtc   = (Get-Date).ToUniversalTime().ToString("o")
    SourceSiteUrl    = $SourceSiteUrl
    TargetSiteUrl    = $TargetSiteUrl
    Stores           = $stores
    TargetConflicts  = $targetConflicts
    Manifest         = $manifest
    TemplateMetadata = [ordered]@{
        TemplateFileName      = $TemplateFileName
        SourceTemplateMatches = $sourceTemplateMatches
        RepoTemplatePath      = $(if (Test-Path $repoTemplatePath) { $repoTemplatePath } else { $null })
    }
    TargetSharing    = $sharingSnapshot
}

Write-BgvJsonFile -Path $OutputPath -Value $payload
Write-BgvInfo "Inventory written to $OutputPath"
if ($targetConflicts.Count -gt 0) {
    Write-Warning "Target conflicts detected. Review TargetConflicts in the inventory output before continuing."
}
