param(
    [ValidateSet("ClosedHistory", "LegacyDrain", "All")]
    [string]$Mode,
    [string]$SourceSiteUrl = $env:BGV_SOURCE_SPO_SITE_URL,
    [string]$TargetSiteUrl = $env:BGV_TARGET_SPO_SITE_URL,
    [string]$ManifestPath = "",
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
    $OutputPath = Join-Path $repoRoot ("out\migration\copy_{0}.json" -f $Mode.ToLowerInvariant())
}

function Get-BgvCopyableFieldNames {
    param(
        [Parameter(Mandatory = $true)]
        $Connection,
        [Parameter(Mandatory = $true)]
        [string]$ListTitle
    )

    $excluded = Get-BgvExcludedFieldNames | Where-Object { $_ -ne "Title" }
    $names = @("Title")
    foreach ($field in Get-PnPField -List $ListTitle -Connection $Connection) {
        if ($field.InternalName -in $excluded) {
            continue
        }
        if ($field.Hidden -or $field.ReadOnlyField) {
            continue
        }
        if ($field.InternalName.StartsWith("_")) {
            continue
        }
        $names += $field.InternalName
    }
    return @($names | Sort-Object -Unique)
}

function Get-BgvItemMapByField {
    param(
        [Parameter(Mandatory = $true)]
        $Items,
        [Parameter(Mandatory = $true)]
        [string]$FieldName
    )

    $map = @{}
    foreach ($item in $Items) {
        $value = [string]$item[$FieldName]
        if ([string]::IsNullOrWhiteSpace($value)) {
            continue
        }
        $map[$value] = $item
    }
    return $map
}

function Convert-BgvSourceItemToValues {
    param(
        [Parameter(Mandatory = $true)]
        $Item,
        [Parameter(Mandatory = $true)]
        [string[]]$FieldNames
    )

    $values = @{}
    foreach ($fieldName in $FieldNames) {
        if (-not $Item.FieldValues.ContainsKey($fieldName)) {
            continue
        }
        $value = $Item[$fieldName]
        if ($value -is [Microsoft.SharePoint.Client.FieldLookupValue]) {
            continue
        }
        $values[$fieldName] = $value
    }
    return $values
}

function Get-BgvLookupFieldTargetListId {
    param($Field)

    if ($null -eq $Field) {
        return ""
    }

    $schemaXml = [string]$Field.SchemaXml
    if ([string]::IsNullOrWhiteSpace($schemaXml)) {
        return ""
    }

    $match = [regex]::Match($schemaXml, 'List="\{?([^"}]+)\}?"')
    if (-not $match.Success) {
        return ""
    }

    return [string]$match.Groups[1].Value
}

function Ensure-BgvFolderPath {
    param(
        [Parameter(Mandatory = $true)]
        $Connection,
        [Parameter(Mandatory = $true)]
        [string]$ServerRelativeFolderPath
    )

    $normalizedPath = $ServerRelativeFolderPath.Replace("\", "/")
    $web = Get-PnPWeb -Connection $Connection -Includes ServerRelativeUrl
    $webRoot = ([string]$web.ServerRelativeUrl).TrimEnd("/")

    $relativePath = $normalizedPath
    if ($relativePath.StartsWith($webRoot + "/")) {
        $relativePath = $relativePath.Substring($webRoot.Length + 1)
    }
    $relativePath = $relativePath.Trim("/")
    if ([string]::IsNullOrWhiteSpace($relativePath)) {
        return
    }
    $segments = $relativePath.Split("/")

    $current = $webRoot
    for ($index = 0; $index -lt $segments.Count; $index++) {
        $nextPath = ($current.TrimEnd("/") + "/" + $segments[$index]).Trim("/")
        try {
            Get-PnPFolder -Url $nextPath -Connection $Connection | Out-Null
        }
        catch {
            try {
                Add-PnPFolder -Name $segments[$index] -Folder $current -Connection $Connection | Out-Null
            }
            catch {
                if (-not ($_.Exception.Message -match "already exists")) {
                    throw
                }
            }
        }
        $current = "/" + $nextPath
    }
}

function Get-BgvSelectedIds {
    param(
        [Parameter(Mandatory = $true)]
        [string]$ModeName,
        [string]$ManifestFilePath,
        [Parameter(Mandatory = $true)]
        $SourceConnection
    )

    if (-not [string]::IsNullOrWhiteSpace($ManifestFilePath) -and (Test-Path $ManifestFilePath)) {
        $manifestPayload = ConvertFrom-BgvJson (Get-Content -Raw $ManifestFilePath)
        $manifest = if ($manifestPayload.ContainsKey("Manifest")) { $manifestPayload.Manifest } else { $manifestPayload }
    }
    else {
        $manifest = Get-BgvCaseManifest -Connection $SourceConnection
    }

    if ($ModeName -eq "ClosedHistory") {
        return [ordered]@{
            CandidateIds = @($manifest.ClosedHistoryCandidateIds)
            RequestIds   = @($manifest.ClosedHistoryRequestIds)
            RecordKeys   = @($manifest.ClosedHistoryRecordKeys)
        }
    }
    if ($ModeName -eq "All") {
        $allCandidateIds = @(
            Get-PnPListItem -List "BGV_Candidates" -Connection $SourceConnection -PageSize 5000 -Fields "CandidateID" |
            ForEach-Object { [string]$_["CandidateID"] } |
            Where-Object { -not [string]::IsNullOrWhiteSpace($_) } |
            Sort-Object -Unique
        )
        $allRequestIds = @(
            Get-PnPListItem -List "BGV_Requests" -Connection $SourceConnection -PageSize 5000 -Fields "RequestID" |
            ForEach-Object { [string]$_["RequestID"] } |
            Where-Object { -not [string]::IsNullOrWhiteSpace($_) } |
            Sort-Object -Unique
        )
        $allRecordKeys = @(
            Get-PnPListItem -List "BGV_FormData" -Connection $SourceConnection -PageSize 5000 -Fields "RecordKey" |
            ForEach-Object { [string]$_["RecordKey"] } |
            Where-Object { -not [string]::IsNullOrWhiteSpace($_) } |
            Sort-Object -Unique
        )
        return [ordered]@{
            CandidateIds = $allCandidateIds
            RequestIds   = $allRequestIds
            RecordKeys   = $allRecordKeys
        }
    }

    return [ordered]@{
        CandidateIds = @($manifest.LegacyOpenCandidateIds)
        RequestIds   = @($manifest.LegacyOpenRequestIds)
        RecordKeys   = @($manifest.LegacyOpenRecordKeys)
    }
}

Write-BgvStep "Connect to source and target SharePoint sites"
$sourceConnection = Connect-BgvPnPSite -Url $SourceSiteUrl -ClientId $ClientId -TenantId $TenantId
$targetConnection = Connect-BgvPnPSite -Url $TargetSiteUrl -ClientId $ClientId -TenantId $TenantId
$sourceWeb = Get-PnPWeb -Connection $sourceConnection -Includes ServerRelativeUrl
$targetWeb = Get-PnPWeb -Connection $targetConnection -Includes ServerRelativeUrl
$sourceWebRoot = ([string]$sourceWeb.ServerRelativeUrl).TrimEnd("/")
$targetWebRoot = ([string]$targetWeb.ServerRelativeUrl).TrimEnd("/")
$selection = Get-BgvSelectedIds -ModeName $Mode -ManifestFilePath $ManifestPath -SourceConnection $sourceConnection

Write-BgvStep "Load source and target list items"
$sourceCandidates = @(Get-PnPListItem -List "BGV_Candidates" -Connection $sourceConnection -PageSize 5000)
$targetCandidates = @(Get-PnPListItem -List "BGV_Candidates" -Connection $targetConnection -PageSize 5000)
$sourceRequests = @(Get-PnPListItem -List "BGV_Requests" -Connection $sourceConnection -PageSize 5000)
$targetRequests = @(Get-PnPListItem -List "BGV_Requests" -Connection $targetConnection -PageSize 5000)
$sourceFormData = @(Get-PnPListItem -List "BGV_FormData" -Connection $sourceConnection -PageSize 5000)
$targetFormData = @(Get-PnPListItem -List "BGV_FormData" -Connection $targetConnection -PageSize 5000)

$sourceCandidateMap = Get-BgvItemMapByField -Items $sourceCandidates -FieldName "CandidateID"
$targetCandidateMap = Get-BgvItemMapByField -Items $targetCandidates -FieldName "CandidateID"
$sourceRequestMap = Get-BgvItemMapByField -Items $sourceRequests -FieldName "RequestID"
$targetRequestMap = Get-BgvItemMapByField -Items $targetRequests -FieldName "RequestID"
$sourceFormDataMap = Get-BgvItemMapByField -Items $sourceFormData -FieldName "RecordKey"
$targetFormDataMap = Get-BgvItemMapByField -Items $targetFormData -FieldName "RecordKey"

$candidateFieldNames = Get-BgvCopyableFieldNames -Connection $sourceConnection -ListTitle "BGV_Candidates"
$requestFieldNames = Get-BgvCopyableFieldNames -Connection $sourceConnection -ListTitle "BGV_Requests"
$formDataFieldNames = Get-BgvCopyableFieldNames -Connection $sourceConnection -ListTitle "BGV_FormData"

$targetCandidatesList = Get-BgvPnPListOrNull -Connection $targetConnection -Title "BGV_Candidates"
$targetRequestsList = Get-BgvPnPListOrNull -Connection $targetConnection -Title "BGV_Requests"
$targetCandidateListId = if ($targetCandidatesList) { [string]$targetCandidatesList.Id.Guid } else { "" }
$targetRequestListId = if ($targetRequestsList) { [string]$targetRequestsList.Id.Guid } else { "" }

$requestCandidateLookupField = $null
$formDataCandidateLookupField = $null
$formDataRequestLookupField = $null
try { $requestCandidateLookupField = Get-PnPField -List "BGV_Requests" -Identity "CandidateItemID" -Connection $targetConnection -ErrorAction Stop } catch {}
try { $formDataCandidateLookupField = Get-PnPField -List "BGV_FormData" -Identity "CandidateItemID" -Connection $targetConnection -ErrorAction Stop } catch {}
try { $formDataRequestLookupField = Get-PnPField -List "BGV_FormData" -Identity "RecordItemID" -Connection $targetConnection -ErrorAction Stop } catch {}

$requestLookupCandidateId = Get-BgvLookupFieldTargetListId -Field $requestCandidateLookupField
$formDataLookupCandidateId = Get-BgvLookupFieldTargetListId -Field $formDataCandidateLookupField
$formDataLookupRequestId = Get-BgvLookupFieldTargetListId -Field $formDataRequestLookupField
$formDataCandidateType = if ($formDataCandidateLookupField) { [string]$formDataCandidateLookupField.TypeAsString } else { "" }
$formDataRequestType = if ($formDataRequestLookupField) { [string]$formDataRequestLookupField.TypeAsString } else { "" }

$canWriteRequestCandidateLookup = (-not [string]::IsNullOrWhiteSpace($targetCandidateListId)) -and
    (-not [string]::IsNullOrWhiteSpace($requestLookupCandidateId)) -and
    ($requestLookupCandidateId.Trim("{}").ToLowerInvariant() -eq $targetCandidateListId.Trim("{}").ToLowerInvariant())

$canWriteFormDataCandidateLookup = $formDataCandidateType.StartsWith("Lookup") -and
    (-not [string]::IsNullOrWhiteSpace($targetCandidateListId)) -and
    (-not [string]::IsNullOrWhiteSpace($formDataLookupCandidateId)) -and
    ($formDataLookupCandidateId.Trim("{}").ToLowerInvariant() -eq $targetCandidateListId.Trim("{}").ToLowerInvariant())

$canWriteFormDataRequestLookup = $formDataRequestType.StartsWith("Lookup") -and
    (-not [string]::IsNullOrWhiteSpace($targetRequestListId)) -and
    (-not [string]::IsNullOrWhiteSpace($formDataLookupRequestId)) -and
    ($formDataLookupRequestId.Trim("{}").ToLowerInvariant() -eq $targetRequestListId.Trim("{}").ToLowerInvariant())

$canWriteFormDataCandidateNumber = ($formDataCandidateType -eq "Number" -or $formDataCandidateType -eq "Integer")
$canWriteFormDataRequestNumber = ($formDataRequestType -eq "Number" -or $formDataRequestType -eq "Integer")

if (-not $canWriteRequestCandidateLookup) {
    Write-Warning "Skipping BGV_Requests.CandidateItemID remap because lookup target list binding does not match target BGV_Candidates list."
}
if (-not ($canWriteFormDataCandidateLookup -or $canWriteFormDataCandidateNumber)) {
    Write-Warning "Skipping BGV_FormData.CandidateItemID remap because lookup target list binding does not match target BGV_Candidates list."
}
if (-not ($canWriteFormDataRequestLookup -or $canWriteFormDataRequestNumber)) {
    Write-Warning "Skipping BGV_FormData.RecordItemID remap because lookup target list binding does not match target BGV_Requests list."
}

Write-BgvStep "Upsert candidate rows"
$candidateIdToTargetItemId = @{}
$candidateResults = New-Object System.Collections.Generic.List[object]
foreach ($candidateId in $selection.CandidateIds) {
    if (-not $sourceCandidateMap.ContainsKey($candidateId)) {
        continue
    }
    $sourceItem = $sourceCandidateMap[$candidateId]
    $values = Convert-BgvSourceItemToValues -Item $sourceItem -FieldNames $candidateFieldNames
    $targetItem = $null

    if ($targetCandidateMap.ContainsKey($candidateId)) {
        $targetItem = $targetCandidateMap[$candidateId]
        Set-PnPListItem -List "BGV_Candidates" -Identity $targetItem.Id -Values $values -Connection $targetConnection | Out-Null
    }
    else {
        $targetItem = Add-PnPListItem -List "BGV_Candidates" -Values $values -Connection $targetConnection
        $targetCandidateMap[$candidateId] = $targetItem
    }

    $candidateIdToTargetItemId[$candidateId] = $targetItem.Id
    $candidateResults.Add([ordered]@{ CandidateID = $candidateId; TargetItemId = $targetItem.Id })
}

Write-BgvStep "Upsert request rows with lookup remap"
$requestIdToTargetItemId = @{}
$requestResults = New-Object System.Collections.Generic.List[object]
foreach ($requestId in $selection.RequestIds) {
    if (-not $sourceRequestMap.ContainsKey($requestId)) {
        continue
    }
    $sourceItem = $sourceRequestMap[$requestId]
    $candidateId = [string]$sourceItem["CandidateID"]
    if ([string]::IsNullOrWhiteSpace($candidateId) -or -not $candidateIdToTargetItemId.ContainsKey($candidateId)) {
        continue
    }

    $values = Convert-BgvSourceItemToValues -Item $sourceItem -FieldNames $requestFieldNames
    if ($canWriteRequestCandidateLookup) {
        $values["CandidateItemID"] = $candidateIdToTargetItemId[$candidateId]
    }
    $targetItem = $null

    if ($targetRequestMap.ContainsKey($requestId)) {
        $targetItem = $targetRequestMap[$requestId]
        Set-PnPListItem -List "BGV_Requests" -Identity $targetItem.Id -Values $values -Connection $targetConnection | Out-Null
    }
    else {
        $targetItem = Add-PnPListItem -List "BGV_Requests" -Values $values -Connection $targetConnection
        $targetRequestMap[$requestId] = $targetItem
    }

    $requestIdToTargetItemId[$requestId] = $targetItem.Id
    $requestResults.Add([ordered]@{ RequestID = $requestId; TargetItemId = $targetItem.Id })
}

Write-BgvStep "Upsert FormData rows with lookup remap"
$formDataResults = New-Object System.Collections.Generic.List[object]
$skippedFormData = New-Object System.Collections.Generic.List[object]
foreach ($recordKey in $selection.RecordKeys) {
    if (-not $sourceFormDataMap.ContainsKey($recordKey)) {
        continue
    }
    $sourceItem = $sourceFormDataMap[$recordKey]
    $candidateId = [string]$sourceItem["CandidateID"]
    $requestId = [string]$sourceItem["RequestID"]

    $values = Convert-BgvSourceItemToValues -Item $sourceItem -FieldNames $formDataFieldNames
    if ($values.ContainsKey("CandidateItemID")) {
        if ((-not [string]::IsNullOrWhiteSpace($candidateId)) -and
            $candidateIdToTargetItemId.ContainsKey($candidateId) -and
            ($canWriteFormDataCandidateLookup -or $canWriteFormDataCandidateNumber)) {
            $values["CandidateItemID"] = [int]$candidateIdToTargetItemId[$candidateId]
        }
    }
    if ($values.ContainsKey("RecordItemID")) {
        if ((-not [string]::IsNullOrWhiteSpace($requestId)) -and
            $requestIdToTargetItemId.ContainsKey($requestId) -and
            ($canWriteFormDataRequestLookup -or $canWriteFormDataRequestNumber)) {
            $values["RecordItemID"] = [int]$requestIdToTargetItemId[$requestId]
        }
    }

    if ($Mode -ne "All") {
        if ([string]::IsNullOrWhiteSpace($candidateId) -or [string]::IsNullOrWhiteSpace($requestId)) {
            $skippedFormData.Add([ordered]@{
                    RecordKey = $recordKey
                    Reason    = "CandidateID or RequestID is blank"
                })
            continue
        }
        if (-not $candidateIdToTargetItemId.ContainsKey($candidateId) -or -not $requestIdToTargetItemId.ContainsKey($requestId)) {
            $skippedFormData.Add([ordered]@{
                    RecordKey = $recordKey
                    Reason    = "CandidateID or RequestID not selected in mode scope"
                })
            continue
        }
    }

    if ($targetFormDataMap.ContainsKey($recordKey)) {
        $targetItem = $targetFormDataMap[$recordKey]
        Set-PnPListItem -List "BGV_FormData" -Identity $targetItem.Id -Values $values -Connection $targetConnection | Out-Null
    }
    else {
        $targetItem = Add-PnPListItem -List "BGV_FormData" -Values $values -Connection $targetConnection
        $targetFormDataMap[$recordKey] = $targetItem
    }

    $formDataResults.Add([ordered]@{ RecordKey = $recordKey; TargetItemId = $targetItem.Id })
}

Write-BgvStep "Copy BGV Records files"
$sourceLibraryItems = @(Get-PnPListItem -List "BGV Records" -Connection $sourceConnection -PageSize 5000 -Fields "FileRef", "FileLeafRef", "FSObjType")
$targetLibraryItems = @(Get-PnPListItem -List "BGV Records" -Connection $targetConnection -PageSize 5000 -Fields "FileRef", "FSObjType")
$targetFileRefs = @($targetLibraryItems | Where-Object { $_["FSObjType"] -eq 0 } | ForEach-Object { [string]$_["FileRef"] })
$targetFolderRefs = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
$null = @($targetLibraryItems | Where-Object { $_["FSObjType"] -eq 1 } | ForEach-Object { $targetFolderRefs.Add([string]$_["FileRef"]) })
$sourceFilesToCopy = @()
$sourceFoldersToEnsure = @()
$ensuredFolderCount = 0
if ($Mode -eq "All") {
    $sourceFilesToCopy = @($sourceLibraryItems | Where-Object { $_["FSObjType"] -eq 0 })
    $sourceFoldersToEnsure = @(
        $sourceLibraryItems |
        Where-Object {
            $_["FSObjType"] -eq 1 -and
            -not [string]::IsNullOrWhiteSpace([string]$_["FileRef"])
        } |
        Sort-Object { ([string]$_["FileRef"]).Length }, { [string]$_["FileRef"] }
    )
}
else {
    $sourceFilesToCopy = @(
        foreach ($candidateId in $selection.CandidateIds) {
            $sourceLibraryItems | Where-Object {
                $_["FSObjType"] -eq 0 -and [string]$_["FileRef"] -match ([regex]::Escape("/Candidate Files/$candidateId/"))
            }
        }
    )
}

foreach ($folderItem in $sourceFoldersToEnsure) {
    $sourceFolderRef = [string]$folderItem["FileRef"]
    $targetFolderRef = $sourceFolderRef
    if (-not [string]::IsNullOrWhiteSpace($sourceWebRoot) -and $sourceFolderRef.StartsWith($sourceWebRoot + "/")) {
        $targetFolderRef = $targetWebRoot + $sourceFolderRef.Substring($sourceWebRoot.Length)
    }
    if ($targetFolderRefs.Contains($targetFolderRef)) {
        continue
    }

    Ensure-BgvFolderPath -Connection $targetConnection -ServerRelativeFolderPath $targetFolderRef
    $targetFolderRefs.Add($targetFolderRef) | Out-Null
    $ensuredFolderCount++
}

$tempDirectory = Join-Path $env:TEMP ("bgv_migration_copy_{0}" -f [guid]::NewGuid().Guid)
New-Item -ItemType Directory -Force -Path $tempDirectory | Out-Null

$copiedFiles = New-Object System.Collections.Generic.List[string]
$failedFiles = New-Object System.Collections.Generic.List[object]
try {
    foreach ($fileItem in $sourceFilesToCopy) {
        $sourceFileRef = [string]$fileItem["FileRef"]
        $targetFileRef = $sourceFileRef
        if (-not [string]::IsNullOrWhiteSpace($sourceWebRoot) -and $sourceFileRef.StartsWith($sourceWebRoot + "/")) {
            $targetFileRef = $targetWebRoot + $sourceFileRef.Substring($sourceWebRoot.Length)
        }

        if ($targetFileRef -in $targetFileRefs) {
            continue
        }

        $fileName = [string]$fileItem["FileLeafRef"]
        $relativeFolder = (Split-Path $targetFileRef -Parent).Replace("\", "/")
        if (-not [string]::IsNullOrWhiteSpace($relativeFolder) -and -not $relativeFolder.StartsWith("/")) {
            $relativeFolder = "/" + $relativeFolder.TrimStart("/")
        }
        Ensure-BgvFolderPath -Connection $targetConnection -ServerRelativeFolderPath $relativeFolder
        $localFolder = Join-Path $tempDirectory ([guid]::NewGuid().Guid)
        New-Item -ItemType Directory -Force -Path $localFolder | Out-Null
        try {
            Get-PnPFile -Url $sourceFileRef -Path $localFolder -FileName $fileName -AsFile -Force -Connection $sourceConnection | Out-Null
            Add-PnPFile -Path (Join-Path $localFolder $fileName) -Folder $relativeFolder -Connection $targetConnection | Out-Null
            $copiedFiles.Add($targetFileRef)
        }
        catch {
            $failedFiles.Add([ordered]@{
                    SourceFileRef = $sourceFileRef
                    TargetFileRef = $targetFileRef
                    Error         = [string]$_.Exception.Message
                })
            Write-Warning ("Skipping file due to copy error: {0} -> {1} | {2}" -f $sourceFileRef, $targetFileRef, $_.Exception.Message)
        }
    }
}
finally {
    if (Test-Path $tempDirectory) {
        Remove-Item -Recurse -Force $tempDirectory
    }
}

$payload = [ordered]@{
    GeneratedAtUtc = (Get-Date).ToUniversalTime().ToString("o")
    Mode           = $Mode
    SourceSiteUrl  = $SourceSiteUrl
    TargetSiteUrl  = $TargetSiteUrl
    CandidateCount = $candidateResults.Count
    RequestCount   = $requestResults.Count
    FormDataCount  = $formDataResults.Count
    SkippedFormDataCount = $skippedFormData.Count
    SourceFolderSelectionCount = $sourceFoldersToEnsure.Count
    EnsuredFolderCount = $ensuredFolderCount
    SourceFileSelectionCount = $sourceFilesToCopy.Count
    FileCount      = $copiedFiles.Count
    FailedFileCount = $failedFiles.Count
    # Normalize Generic.List payload members to regular arrays before JSON serialization.
    Candidates     = @($candidateResults.ToArray())
    Requests       = @($requestResults.ToArray())
    FormData       = @($formDataResults.ToArray())
    SkippedFormData = @($skippedFormData.ToArray())
    Files          = @($copiedFiles.ToArray())
    FailedFiles    = @($failedFiles.ToArray())
}

Write-BgvJsonFile -Path $OutputPath -Value $payload
Write-BgvInfo "Copy results written to $OutputPath"
