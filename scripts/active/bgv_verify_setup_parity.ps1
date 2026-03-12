param(
    [string]$SourceSiteUrl = $env:BGV_SOURCE_SPO_SITE_URL,
    [string]$TargetSiteUrl = $env:BGV_TARGET_SPO_SITE_URL,
    [string]$ClientId = $env:PNP_CLIENT_ID,
    [string]$TenantId = $env:PNP_TENANT_ID,
    [string]$OutputPath = ""
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
    $OutputPath = Join-Path $repoRoot "out\migration\setup_parity.json"
}

function Get-BgvDefaultViewSnapshot {
    param(
        [Parameter(Mandatory = $true)]
        [string]$ListTitle,
        [Parameter(Mandatory = $true)]
        $Connection
    )

    $defaultView = Get-PnPView -List $ListTitle -Connection $Connection | Where-Object { $_.DefaultView } | Select-Object -First 1
    if (-not $defaultView) {
        return [ordered]@{
            Exists      = $false
            Title       = ""
            FieldNames  = @()
        }
    }

    return [ordered]@{
        Exists      = $true
        Title       = [string]$defaultView.Title
        FieldNames  = @($defaultView.ViewFields)
    }
}

Write-BgvStep "Connect to source and target SharePoint sites"
$sourceConnection = Connect-BgvPnPSite -Url $SourceSiteUrl -ClientId $ClientId -TenantId $TenantId
$targetConnection = Connect-BgvPnPSite -Url $TargetSiteUrl -ClientId $ClientId -TenantId $TenantId

$stores = New-Object System.Collections.Generic.List[object]
$mismatches = New-Object System.Collections.Generic.List[object]

foreach ($spec in Get-BgvStoreSpecifications) {
    $sourceList = Get-PnPList -Identity $spec.Title -Connection $sourceConnection -Includes ItemCount, BaseTemplate, EnableVersioning, EnableMinorVersions, EnableModeration, EnableAttachments, ForceCheckout, ContentTypesEnabled, HasUniqueRoleAssignments
    $targetList = Get-PnPList -Identity $spec.Title -Connection $targetConnection -Includes ItemCount, BaseTemplate, EnableVersioning, EnableMinorVersions, EnableModeration, EnableAttachments, ForceCheckout, ContentTypesEnabled, HasUniqueRoleAssignments

    $sourceView = Get-BgvDefaultViewSnapshot -ListTitle $spec.Title -Connection $sourceConnection
    $targetView = Get-BgvDefaultViewSnapshot -ListTitle $spec.Title -Connection $targetConnection
    $sourceTitleField = Get-PnPField -List $spec.Title -Identity "Title" -Connection $sourceConnection
    $targetTitleField = Get-PnPField -List $spec.Title -Identity "Title" -Connection $targetConnection

    $defaultViewFieldsMatch = ($sourceView.FieldNames.Count -eq $targetView.FieldNames.Count) -and
        (@($sourceView.FieldNames) -join "|") -eq (@($targetView.FieldNames) -join "|")
    $settingsMatch = ($sourceList.EnableVersioning -eq $targetList.EnableVersioning) -and
        ($sourceList.EnableMinorVersions -eq $targetList.EnableMinorVersions) -and
        ($sourceList.EnableModeration -eq $targetList.EnableModeration) -and
        ($sourceList.EnableAttachments -eq $targetList.EnableAttachments) -and
        ($sourceList.ForceCheckout -eq $targetList.ForceCheckout) -and
        ($sourceList.ContentTypesEnabled -eq $targetList.ContentTypesEnabled) -and
        ([bool]$sourceTitleField.Required -eq [bool]$targetTitleField.Required)
    $permissionModeMatch = ([bool]$sourceList.HasUniqueRoleAssignments -eq [bool]$targetList.HasUniqueRoleAssignments)

    if ($sourceList.ItemCount -ne $targetList.ItemCount) {
        $mismatches.Add([ordered]@{
                StoreTitle = $spec.Title
                Type       = "ItemCount"
                Source     = $sourceList.ItemCount
                Target     = $targetList.ItemCount
            })
    }
    if (-not $defaultViewFieldsMatch) {
        $mismatches.Add([ordered]@{
                StoreTitle = $spec.Title
                Type       = "DefaultViewFields"
                Source     = @($sourceView.FieldNames)
                Target     = @($targetView.FieldNames)
            })
    }
    if (-not $settingsMatch) {
        $mismatches.Add([ordered]@{
                StoreTitle = $spec.Title
                Type       = "ListSettings"
                Source     = [ordered]@{
                    EnableVersioning    = [bool]$sourceList.EnableVersioning
                    EnableMinorVersions = [bool]$sourceList.EnableMinorVersions
                    EnableModeration    = [bool]$sourceList.EnableModeration
                    EnableAttachments   = [bool]$sourceList.EnableAttachments
                    ForceCheckout       = [bool]$sourceList.ForceCheckout
                    ContentTypesEnabled = [bool]$sourceList.ContentTypesEnabled
                    TitleRequired       = [bool]$sourceTitleField.Required
                }
                Target     = [ordered]@{
                    EnableVersioning    = [bool]$targetList.EnableVersioning
                    EnableMinorVersions = [bool]$targetList.EnableMinorVersions
                    EnableModeration    = [bool]$targetList.EnableModeration
                    EnableAttachments   = [bool]$targetList.EnableAttachments
                    ForceCheckout       = [bool]$targetList.ForceCheckout
                    ContentTypesEnabled = [bool]$targetList.ContentTypesEnabled
                    TitleRequired       = [bool]$targetTitleField.Required
                }
            })
    }
    if (-not $permissionModeMatch) {
        $mismatches.Add([ordered]@{
                StoreTitle = $spec.Title
                Type       = "PermissionInheritanceMode"
                Source     = [bool]$sourceList.HasUniqueRoleAssignments
                Target     = [bool]$targetList.HasUniqueRoleAssignments
            })
    }

    $stores.Add([ordered]@{
            StoreTitle               = $spec.Title
            SourceItemCount          = $sourceList.ItemCount
            TargetItemCount          = $targetList.ItemCount
            SourceDefaultViewTitle   = [string]$sourceView.Title
            TargetDefaultViewTitle   = [string]$targetView.Title
            SourceDefaultViewFields  = @($sourceView.FieldNames)
            TargetDefaultViewFields  = @($targetView.FieldNames)
            DefaultViewFieldsMatch   = $defaultViewFieldsMatch
            SettingsMatch            = $settingsMatch
            PermissionModeMatch      = $permissionModeMatch
            SourceUniquePerms        = [bool]$sourceList.HasUniqueRoleAssignments
            TargetUniquePerms        = [bool]$targetList.HasUniqueRoleAssignments
            SourceTitleRequired      = [bool]$sourceTitleField.Required
            TargetTitleRequired      = [bool]$targetTitleField.Required
        })
}

Write-BgvStep "Compare BGV Records file counts"
$sourceFileCount = @(
    Get-PnPListItem -List "BGV Records" -Connection $sourceConnection -PageSize 5000 -Fields "FSObjType" |
    Where-Object { $_["FSObjType"] -eq 0 }
).Count
$targetFileCount = @(
    Get-PnPListItem -List "BGV Records" -Connection $targetConnection -PageSize 5000 -Fields "FSObjType" |
    Where-Object { $_["FSObjType"] -eq 0 }
).Count

if ($sourceFileCount -ne $targetFileCount) {
    $mismatches.Add([ordered]@{
            StoreTitle = "BGV Records"
            Type       = "FileCount"
            Source     = $sourceFileCount
            Target     = $targetFileCount
        })
}

$payload = [ordered]@{
    GeneratedAtUtc = (Get-Date).ToUniversalTime().ToString("o")
    SourceSiteUrl  = $SourceSiteUrl
    TargetSiteUrl  = $TargetSiteUrl
    Summary        = [ordered]@{
        Passed               = ($mismatches.Count -eq 0)
        MismatchCount        = $mismatches.Count
        SourceFileCount      = $sourceFileCount
        TargetFileCount      = $targetFileCount
    }
    Stores         = @($stores.ToArray())
    Mismatches     = @($mismatches.ToArray())
}

Write-BgvJsonFile -Path $OutputPath -Value $payload
Write-BgvInfo "Setup parity results written to $OutputPath"
if ($mismatches.Count -gt 0) {
    Write-Warning ("Setup parity mismatches detected: {0}" -f $mismatches.Count)
}
