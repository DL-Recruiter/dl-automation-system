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
    $OutputPath = Join-Path $repoRoot "out\migration\setup_sync.json"
}

function Get-BgvPublicViews {
    param(
        [Parameter(Mandatory = $true)]
        [string]$ListTitle,
        [Parameter(Mandatory = $true)]
        $Connection
    )

    return @(Get-PnPView -List $ListTitle -Connection $Connection | Where-Object { -not $_.PersonalView })
}

function Convert-BgvFieldSchemaForTarget {
    param(
        [Parameter(Mandatory = $true)]
        [string]$SchemaXml,
        [Parameter(Mandatory = $true)]
        [string]$TargetListId,
        [Parameter(Mandatory = $true)]
        [hashtable]$ListIdMap,
        [Parameter(Mandatory = $true)]
        [hashtable]$FieldIdMap
    )

    [xml]$xml = $SchemaXml
    $fieldNode = $xml.Field
    if ($null -eq $fieldNode) {
        return $SchemaXml
    }

    if ($fieldNode.Attributes["SourceID"]) {
        $fieldNode.Attributes["SourceID"].Value = "{" + $TargetListId + "}"
    }

    if ($fieldNode.Attributes["List"]) {
        $sourceListId = [string]$fieldNode.Attributes["List"].Value
        $sourceListKey = $sourceListId.Trim("{}").ToLowerInvariant()
        if ($ListIdMap.ContainsKey($sourceListKey)) {
            $fieldNode.Attributes["List"].Value = "{" + [string]$ListIdMap[$sourceListKey] + "}"
        }
    }

    if ($fieldNode.Attributes["FieldRef"]) {
        $sourceFieldId = [string]$fieldNode.Attributes["FieldRef"].Value
        $sourceFieldKey = $sourceFieldId.Trim("{}").ToLowerInvariant()
        if ($FieldIdMap.ContainsKey($sourceFieldKey)) {
            $fieldNode.Attributes["FieldRef"].Value = [string]$FieldIdMap[$sourceFieldKey]
        }
    }

    return $xml.OuterXml
}

Write-BgvStep "Connect to source and target SharePoint sites"
$sourceConnection = Connect-BgvPnPSite -Url $SourceSiteUrl -ClientId $ClientId -TenantId $TenantId
$targetConnection = Connect-BgvPnPSite -Url $TargetSiteUrl -ClientId $ClientId -TenantId $TenantId

$sourceStoreByTitle = @{}
$targetStoreByTitle = @{}
$listIdMap = @{}
foreach ($storeSpec in Get-BgvStoreSpecifications) {
    $sourceStore = Get-PnPList -Identity $storeSpec.Title -Connection $sourceConnection
    $targetStore = Get-PnPList -Identity $storeSpec.Title -Connection $targetConnection
    $sourceStoreByTitle[$storeSpec.Title] = $sourceStore
    $targetStoreByTitle[$storeSpec.Title] = $targetStore
    $listIdMap[[string]$sourceStore.Id.Guid.ToLowerInvariant()] = [string]$targetStore.Id.Guid
}

$results = New-Object System.Collections.Generic.List[object]
foreach ($spec in Get-BgvStoreSpecifications) {
    Write-BgvStep ("Sync setup parity for {0}" -f $spec.Title)
    $sourceList = Get-PnPList -Identity $spec.Title -Connection $sourceConnection -Includes BaseTemplate, EnableVersioning, EnableMinorVersions, EnableModeration, EnableAttachments, ForceCheckout, ContentTypesEnabled, HasUniqueRoleAssignments
    $targetList = Get-PnPList -Identity $spec.Title -Connection $targetConnection -Includes BaseTemplate, EnableVersioning, EnableMinorVersions, EnableModeration, EnableAttachments, ForceCheckout, ContentTypesEnabled, HasUniqueRoleAssignments

    if ([int]$sourceList.BaseTemplate -ne [int]$targetList.BaseTemplate) {
        throw "Base template mismatch for $($spec.Title). Source=$($sourceList.BaseTemplate), Target=$($targetList.BaseTemplate)."
    }

    $sourceViews = Get-BgvPublicViews -ListTitle $spec.Title -Connection $sourceConnection
    $targetViews = Get-BgvPublicViews -ListTitle $spec.Title -Connection $targetConnection
    $requiredViewFields = @(
        $sourceViews |
        ForEach-Object { @($_.ViewFields) } |
        Where-Object { -not [string]::IsNullOrWhiteSpace([string]$_) } |
        Sort-Object -Unique
    )

    $sourceFields = @(Get-PnPField -List $spec.Title -Connection $sourceConnection)
    $targetFields = @(Get-PnPField -List $spec.Title -Connection $targetConnection)
    $sourceFieldByName = @{}
    $targetFieldByName = @{}
    $fieldIdMap = @{}
    foreach ($field in $sourceFields) {
        $sourceFieldByName[[string]$field.InternalName] = $field
    }
    foreach ($field in $targetFields) {
        $targetFieldByName[[string]$field.InternalName] = $field
    }
    foreach ($internalName in $sourceFieldByName.Keys) {
        if ($targetFieldByName.ContainsKey($internalName)) {
            $sourceField = $sourceFieldByName[$internalName]
            $targetField = $targetFieldByName[$internalName]
            $fieldIdMap[[string]$sourceField.Id.Guid.ToLowerInvariant()] = [string]$targetField.Id.Guid
        }
    }

    $createdFields = New-Object System.Collections.Generic.List[string]
    $fieldCreateFailures = New-Object System.Collections.Generic.List[object]
    foreach ($fieldName in $requiredViewFields) {
        if ($targetFieldByName.ContainsKey($fieldName)) {
            continue
        }
        if (-not $sourceFieldByName.ContainsKey($fieldName)) {
            continue
        }

        $sourceField = $sourceFieldByName[$fieldName]
        $sourceSchema = [string]$sourceField.SchemaXml
        if ([string]::IsNullOrWhiteSpace($sourceSchema)) {
            continue
        }

        $targetSchema = Convert-BgvFieldSchemaForTarget `
            -SchemaXml $sourceSchema `
            -TargetListId ([string]$targetStoreByTitle[$spec.Title].Id.Guid) `
            -ListIdMap $listIdMap `
            -FieldIdMap $fieldIdMap

        try {
            Add-PnPFieldFromXml -List $spec.Title -FieldXml $targetSchema -Connection $targetConnection -ErrorAction Stop | Out-Null
            $createdFields.Add([string]$fieldName)
            $targetField = Get-PnPField -List $spec.Title -Identity $fieldName -Connection $targetConnection -ErrorAction Stop
            $targetFieldByName[[string]$targetField.InternalName] = $targetField
            $fieldIdMap[[string]$sourceField.Id.Guid.ToLowerInvariant()] = [string]$targetField.Id.Guid
        }
        catch {
            $fieldCreateFailures.Add([ordered]@{
                    Field = [string]$fieldName
                    Error = [string]$_.Exception.Message
                })
            Write-Warning ("Field sync failed for {0}.{1}: {2}" -f $spec.Title, $fieldName, $_.Exception.Message)
        }
    }

    $settingsMismatches = New-Object System.Collections.Generic.List[string]
    $setParams = @{
        Identity   = $spec.Title
        Connection = $targetConnection
    }

    foreach ($settingName in @("EnableVersioning", "EnableMinorVersions", "EnableModeration", "EnableAttachments", "ForceCheckout", "ContentTypesEnabled")) {
        $sourceValue = [bool]$sourceList.$settingName
        $targetValue = [bool]$targetList.$settingName
        if ($sourceValue -ne $targetValue) {
            $settingsMismatches.Add($settingName)
            switch ($settingName) {
                "ContentTypesEnabled" { $setParams["EnableContentTypes"] = $sourceValue }
                default { $setParams[$settingName] = $sourceValue }
            }
        }
    }

    if ($settingsMismatches.Count -gt 0) {
        Set-PnPList @setParams | Out-Null
        $targetList = Get-PnPList -Identity $spec.Title -Connection $targetConnection -Includes HasUniqueRoleAssignments
    }

    $titleFieldAction = "none"
    $titleFieldError = ""
    try {
        $sourceTitleField = Get-PnPField -List $spec.Title -Identity "Title" -Connection $sourceConnection -ErrorAction Stop
        $targetTitleField = Get-PnPField -List $spec.Title -Identity "Title" -Connection $targetConnection -ErrorAction Stop
        $sourceTitleRequired = [bool]$sourceTitleField.Required
        $targetTitleRequired = [bool]$targetTitleField.Required
        if ($sourceTitleRequired -ne $targetTitleRequired) {
            Set-PnPField -List $spec.Title -Identity "Title" -Values @{ Required = $sourceTitleRequired } -Connection $targetConnection -ErrorAction Stop | Out-Null
            $titleFieldAction = "set-required-$sourceTitleRequired"
        }
    }
    catch {
        $titleFieldAction = "sync-failed"
        $titleFieldError = [string]$_.Exception.Message
        Write-Warning ("Title field parity sync failed for {0}: {1}" -f $spec.Title, $titleFieldError)
    }

    $sourceUnique = [bool]$sourceList.HasUniqueRoleAssignments
    $targetUnique = [bool]$targetList.HasUniqueRoleAssignments
    $permissionAction = "none"
    $permissionError = ""
    if ($sourceUnique -and -not $targetUnique) {
        try {
            Set-PnPList -Identity $spec.Title -BreakRoleInheritance -CopyRoleAssignments -Connection $targetConnection | Out-Null
            $permissionAction = "break-role-inheritance-copy"
        }
        catch {
            $permissionAction = "break-role-inheritance-copy-failed"
            $permissionError = [string]$_.Exception.Message
            Write-Warning ("Permission mode sync failed for {0}: {1}" -f $spec.Title, $permissionError)
        }
    }
    elseif (-not $sourceUnique -and $targetUnique) {
        try {
            Set-PnPList -Identity $spec.Title -ResetRoleInheritance -Connection $targetConnection | Out-Null
            $permissionAction = "reset-role-inheritance"
        }
        catch {
            $permissionAction = "reset-role-inheritance-failed"
            $permissionError = [string]$_.Exception.Message
            Write-Warning ("Permission mode sync failed for {0}: {1}" -f $spec.Title, $permissionError)
        }
    }

    $targetViews = Get-BgvPublicViews -ListTitle $spec.Title -Connection $targetConnection
    $targetFieldNames = @($targetFieldByName.Keys)
    $targetViewByTitle = @{}
    foreach ($view in $targetViews) {
        $targetViewByTitle[[string]$view.Title] = $view
    }

    $updatedViews = New-Object System.Collections.Generic.List[string]
    $createdViews = New-Object System.Collections.Generic.List[string]
    $viewSkippedFields = New-Object System.Collections.Generic.List[object]
    foreach ($sourceView in $sourceViews) {
        $viewTitle = [string]$sourceView.Title
        $sourceFields = @($sourceView.ViewFields)
        if ($sourceFields.Count -eq 0) {
            continue
        }
        $compatibleFields = @($sourceFields | Where-Object { $_ -in $targetFieldNames })
        $skippedFields = @($sourceFields | Where-Object { $_ -notin $targetFieldNames })
        if ($skippedFields.Count -gt 0) {
            $viewSkippedFields.Add([ordered]@{
                    ViewTitle = $viewTitle
                    Fields    = $skippedFields
                })
        }
        if ($compatibleFields.Count -eq 0) {
            continue
        }

        if ($targetViewByTitle.ContainsKey($viewTitle)) {
            $targetView = $targetViewByTitle[$viewTitle]
            Set-PnPView -List $spec.Title -Identity $targetView.Id -Fields $compatibleFields -Connection $targetConnection | Out-Null
            if ([bool]$sourceView.DefaultView -and -not [bool]$targetView.DefaultView) {
                Set-PnPView -List $spec.Title -Identity $targetView.Id -Values @{ DefaultView = $true } -Connection $targetConnection | Out-Null
            }
            $updatedViews.Add($viewTitle)
            continue
        }

        $addParams = @{
            List       = $spec.Title
            Title      = $viewTitle
            Fields     = $compatibleFields
            Connection = $targetConnection
        }
        if (-not [string]::IsNullOrWhiteSpace([string]$sourceView.ViewQuery)) {
            $addParams["Query"] = [string]$sourceView.ViewQuery
        }
        if ([uint32]$sourceView.RowLimit -gt 0) {
            $addParams["RowLimit"] = [uint32]$sourceView.RowLimit
        }
        if ([bool]$sourceView.Paged) {
            $addParams["Paged"] = $true
        }
        if ([bool]$sourceView.DefaultView) {
            $addParams["SetAsDefault"] = $true
        }
        Add-PnPView @addParams | Out-Null
        $createdViews.Add($viewTitle)
    }

    $targetViewsPost = Get-BgvPublicViews -ListTitle $spec.Title -Connection $targetConnection
    $targetViewTitlesPost = @($targetViewsPost | ForEach-Object { [string]$_.Title })
    $sourceViewTitles = @($sourceViews | ForEach-Object { [string]$_.Title })
    $extraTargetViews = @($targetViewTitlesPost | Where-Object { $_ -notin $sourceViewTitles } | Sort-Object -Unique)

    $results.Add([ordered]@{
            StoreTitle          = $spec.Title
            SettingsUpdated     = @($settingsMismatches.ToArray())
            PermissionAction    = $permissionAction
            PermissionError     = $permissionError
            TitleFieldAction    = $titleFieldAction
            TitleFieldError     = $titleFieldError
            FieldsCreated       = @($createdFields.ToArray())
            FieldCreateFailures = @($fieldCreateFailures.ToArray())
            ViewsUpdated        = @($updatedViews.ToArray())
            ViewsCreated        = @($createdViews.ToArray())
            ExtraTargetViews    = $extraTargetViews
            ViewSkippedFields   = @($viewSkippedFields.ToArray())
            SourceUniquePerms   = $sourceUnique
            TargetUniquePerms   = [bool](Get-PnPList -Identity $spec.Title -Connection $targetConnection -Includes HasUniqueRoleAssignments).HasUniqueRoleAssignments
        })
}

$payload = [ordered]@{
    GeneratedAtUtc = (Get-Date).ToUniversalTime().ToString("o")
    SourceSiteUrl  = $SourceSiteUrl
    TargetSiteUrl  = $TargetSiteUrl
    Results        = @($results.ToArray())
}

Write-BgvJsonFile -Path $OutputPath -Value $payload
Write-BgvInfo "Setup sync results written to $OutputPath"
