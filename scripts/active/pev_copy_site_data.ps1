param(
    [string]$SourceSiteUrl = $env:BGV_SOURCE_SPO_SITE_URL,
    [string]$TargetSiteUrl = $env:PEV_TARGET_SPO_SITE_URL,
    [string]$ClientId = $env:PNP_CLIENT_ID,
    [string]$TenantId = $env:PNP_TENANT_ID,
    [switch]$SkipListData,
    [switch]$SkipFiles,
    [string]$OutputPath = ""
)

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
. (Join-Path (Split-Path -Parent (Split-Path -Parent $scriptDir)) "shared\bgv_migration_common.ps1")

if ([string]::IsNullOrWhiteSpace($SourceSiteUrl)) {
    throw "SourceSiteUrl must be provided via parameter or BGV_SOURCE_SPO_SITE_URL."
}
if ([string]::IsNullOrWhiteSpace($TargetSiteUrl)) {
    throw "TargetSiteUrl must be provided via parameter or PEV_TARGET_SPO_SITE_URL."
}

$repoRoot = Get-BgvRepoRoot -CurrentPath $scriptDir
if ([string]::IsNullOrWhiteSpace($OutputPath)) {
    $OutputPath = Join-Path $repoRoot "out\migration\pev_copy_all.json"
}

function Get-PevCopyableFieldNames {
    param(
        [Parameter(Mandatory = $true)]$Connection,
        [Parameter(Mandatory = $true)][string]$ListTitle
    )

    $excluded = Get-BgvExcludedFieldNames | Where-Object { $_ -ne "Title" }
    $names = @("Title")
    foreach ($field in Get-PnPField -List $ListTitle -Connection $Connection) {
        if ($field.InternalName -in $excluded) { continue }
        if ($field.Hidden -or $field.ReadOnlyField) { continue }
        if ($field.InternalName.StartsWith("_")) { continue }
        $names += $field.InternalName
    }
    return @($names | Sort-Object -Unique)
}

function Get-PevItemMapByField {
    param(
        [Parameter(Mandatory = $true)]$Items,
        [Parameter(Mandatory = $true)][string]$FieldName
    )
    $map = @{}
    foreach ($item in $Items) {
        $value = [string]$item[$FieldName]
        if ([string]::IsNullOrWhiteSpace($value)) { continue }
        $map[$value] = $item
    }
    return $map
}

function Convert-PevSourceItemToValues {
    param(
        [Parameter(Mandatory = $true)]$Item,
        [Parameter(Mandatory = $true)][string[]]$FieldNames
    )
    $values = @{}
    foreach ($fieldName in $FieldNames) {
        if (-not $Item.FieldValues.ContainsKey($fieldName)) { continue }
        $value = $Item[$fieldName]
        if ($value -is [Microsoft.SharePoint.Client.FieldLookupValue]) { continue }
        $values[$fieldName] = $value
    }
    return $values
}

function Ensure-PevFolderPath {
    param(
        [Parameter(Mandatory = $true)]$Connection,
        [Parameter(Mandatory = $true)][string]$ServerRelativeFolderPath
    )

    $normalizedPath = $ServerRelativeFolderPath.Replace("\", "/")
    $web = Get-PnPWeb -Connection $Connection -Includes ServerRelativeUrl
    $webRoot = ([string]$web.ServerRelativeUrl).TrimEnd("/")
    $relativePath = $normalizedPath
    if ($relativePath.StartsWith($webRoot + "/")) {
        $relativePath = $relativePath.Substring($webRoot.Length + 1)
    }
    $relativePath = $relativePath.Trim("/")
    if ([string]::IsNullOrWhiteSpace($relativePath)) { return }
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
                if (-not ($_.Exception.Message -match "already exists")) { throw }
            }
        }
        $current = "/" + $nextPath
    }
}

Write-BgvStep "Connect to source and target SharePoint sites"
$sourceConnection = Connect-BgvPnPSite -Url $SourceSiteUrl -ClientId $ClientId -TenantId $TenantId
$targetConnection = Connect-BgvPnPSite -Url $TargetSiteUrl -ClientId $ClientId -TenantId $TenantId
$sourceWeb = Get-PnPWeb -Connection $sourceConnection -Includes ServerRelativeUrl
$targetWeb = Get-PnPWeb -Connection $targetConnection -Includes ServerRelativeUrl
$sourceWebRoot = ([string]$sourceWeb.ServerRelativeUrl).TrimEnd("/")
$targetWebRoot = ([string]$targetWeb.ServerRelativeUrl).TrimEnd("/")

Write-BgvStep "Load source BGV and target PEV list items"
$sourceCandidates = @(Get-PnPListItem -List "BGV_Candidates" -Connection $sourceConnection -PageSize 5000)
$targetCandidates = @(Get-PnPListItem -List "PEV_Candidates" -Connection $targetConnection -PageSize 5000)
$sourceRequests = @(Get-PnPListItem -List "BGV_Requests" -Connection $sourceConnection -PageSize 5000)
$targetRequests = @(Get-PnPListItem -List "PEV_Requests" -Connection $targetConnection -PageSize 5000)
$sourceFormData = @(Get-PnPListItem -List "BGV_FormData" -Connection $sourceConnection -PageSize 5000)
$targetFormData = @(Get-PnPListItem -List "PEV_FormData" -Connection $targetConnection -PageSize 5000)

$sourceCandidateMap = Get-PevItemMapByField -Items $sourceCandidates -FieldName "CandidateID"
$targetCandidateMap = Get-PevItemMapByField -Items $targetCandidates -FieldName "CandidateID"
$sourceRequestMap = Get-PevItemMapByField -Items $sourceRequests -FieldName "RequestID"
$targetRequestMap = Get-PevItemMapByField -Items $targetRequests -FieldName "RequestID"
$sourceFormDataMap = Get-PevItemMapByField -Items $sourceFormData -FieldName "RecordKey"
$targetFormDataMap = Get-PevItemMapByField -Items $targetFormData -FieldName "RecordKey"

$candidateFieldNames = Get-PevCopyableFieldNames -Connection $sourceConnection -ListTitle "BGV_Candidates"
$requestFieldNames = Get-PevCopyableFieldNames -Connection $sourceConnection -ListTitle "BGV_Requests"
$formDataFieldNames = Get-PevCopyableFieldNames -Connection $sourceConnection -ListTitle "BGV_FormData"

$targetCandidatesList = Get-BgvPnPListOrNull -Connection $targetConnection -Title "PEV_Candidates"
$targetRequestsList = Get-BgvPnPListOrNull -Connection $targetConnection -Title "PEV_Requests"
$targetCandidateListId = if ($targetCandidatesList) { [string]$targetCandidatesList.Id.Guid } else { "" }
$targetRequestListId = if ($targetRequestsList) { [string]$targetRequestsList.Id.Guid } else { "" }

$requestCandidateLookupField = $null
$formDataCandidateLookupField = $null
$formDataRequestLookupField = $null
try { $requestCandidateLookupField = Get-PnPField -List "PEV_Requests" -Identity "CandidateItemID" -Connection $targetConnection -ErrorAction Stop } catch {}
try { $formDataCandidateLookupField = Get-PnPField -List "PEV_FormData" -Identity "CandidateItemID" -Connection $targetConnection -ErrorAction Stop } catch {}
try { $formDataRequestLookupField = Get-PnPField -List "PEV_FormData" -Identity "RecordItemID" -Connection $targetConnection -ErrorAction Stop } catch {}

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

Write-BgvStep "Upsert PEV list rows"
$candidateIdToTargetItemId = @{}
$requestIdToTargetItemId = @{}
$candidateResults = New-Object System.Collections.Generic.List[object]
$requestResults = New-Object System.Collections.Generic.List[object]
$formDataResults = New-Object System.Collections.Generic.List[object]

if (-not $SkipListData) {
    foreach ($candidateId in ($sourceCandidateMap.Keys | Sort-Object)) {
        $sourceItem = $sourceCandidateMap[$candidateId]
        $values = Convert-PevSourceItemToValues -Item $sourceItem -FieldNames $candidateFieldNames
        if ($targetCandidateMap.ContainsKey($candidateId)) {
            $targetItem = $targetCandidateMap[$candidateId]
            Set-PnPListItem -List "PEV_Candidates" -Identity $targetItem.Id -Values $values -Connection $targetConnection | Out-Null
        }
        else {
            $targetItem = Add-PnPListItem -List "PEV_Candidates" -Values $values -Connection $targetConnection
            $targetCandidateMap[$candidateId] = $targetItem
        }
        $candidateIdToTargetItemId[$candidateId] = $targetItem.Id
        $candidateResults.Add([ordered]@{ CandidateID = $candidateId; TargetItemId = $targetItem.Id })
    }

    foreach ($requestId in ($sourceRequestMap.Keys | Sort-Object)) {
        $sourceItem = $sourceRequestMap[$requestId]
        $candidateId = [string]$sourceItem["CandidateID"]
        if ([string]::IsNullOrWhiteSpace($candidateId) -or -not $candidateIdToTargetItemId.ContainsKey($candidateId)) { continue }
        $values = Convert-PevSourceItemToValues -Item $sourceItem -FieldNames $requestFieldNames
        if ($canWriteRequestCandidateLookup) {
            $values["CandidateItemID"] = $candidateIdToTargetItemId[$candidateId]
        }
        if ($targetRequestMap.ContainsKey($requestId)) {
            $targetItem = $targetRequestMap[$requestId]
            Set-PnPListItem -List "PEV_Requests" -Identity $targetItem.Id -Values $values -Connection $targetConnection | Out-Null
        }
        else {
            $targetItem = Add-PnPListItem -List "PEV_Requests" -Values $values -Connection $targetConnection
            $targetRequestMap[$requestId] = $targetItem
        }
        $requestIdToTargetItemId[$requestId] = $targetItem.Id
        $requestResults.Add([ordered]@{ RequestID = $requestId; TargetItemId = $targetItem.Id })
    }

    foreach ($recordKey in ($sourceFormDataMap.Keys | Sort-Object)) {
        $sourceItem = $sourceFormDataMap[$recordKey]
        $candidateId = [string]$sourceItem["CandidateID"]
        $requestId = [string]$sourceItem["RequestID"]
        $values = Convert-PevSourceItemToValues -Item $sourceItem -FieldNames $formDataFieldNames
        if ($values.ContainsKey("CandidateItemID")) {
            if ((-not [string]::IsNullOrWhiteSpace($candidateId)) -and $candidateIdToTargetItemId.ContainsKey($candidateId) -and ($canWriteFormDataCandidateLookup -or $canWriteFormDataCandidateNumber)) {
                $values["CandidateItemID"] = [int]$candidateIdToTargetItemId[$candidateId]
            }
        }
        if ($values.ContainsKey("RecordItemID")) {
            if ((-not [string]::IsNullOrWhiteSpace($requestId)) -and $requestIdToTargetItemId.ContainsKey($requestId) -and ($canWriteFormDataRequestLookup -or $canWriteFormDataRequestNumber)) {
                $values["RecordItemID"] = [int]$requestIdToTargetItemId[$requestId]
            }
        }
        if ($targetFormDataMap.ContainsKey($recordKey)) {
            $targetItem = $targetFormDataMap[$recordKey]
            Set-PnPListItem -List "PEV_FormData" -Identity $targetItem.Id -Values $values -Connection $targetConnection | Out-Null
        }
        else {
            $targetItem = Add-PnPListItem -List "PEV_FormData" -Values $values -Connection $targetConnection
            $targetFormDataMap[$recordKey] = $targetItem
        }
        $formDataResults.Add([ordered]@{ RecordKey = $recordKey; TargetItemId = $targetItem.Id })
    }
}
else {
    Write-BgvInfo "Skipping list data upsert."
}

$copiedFiles = New-Object System.Collections.Generic.List[string]
$failedFiles = New-Object System.Collections.Generic.List[object]
$ensuredFolderCount = 0
if (-not $SkipFiles) {
    Write-BgvStep "Copy BGV Records files into PEV Records"
    $sourceLibraryItems = @(Get-PnPListItem -List "BGV Records" -Connection $sourceConnection -PageSize 5000 -Fields "FileRef", "FileLeafRef", "FSObjType")
    $targetLibraryItems = @(Get-PnPListItem -List "PEV Records" -Connection $targetConnection -PageSize 5000 -Fields "FileRef", "FSObjType")
    $targetFileRefs = @($targetLibraryItems | Where-Object { $_["FSObjType"] -eq 0 } | ForEach-Object { [string]$_["FileRef"] })
    $targetFolderRefs = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
    $null = @($targetLibraryItems | Where-Object { $_["FSObjType"] -eq 1 } | ForEach-Object { $targetFolderRefs.Add([string]$_["FileRef"]) })

    $sourceFoldersToEnsure = @(
        $sourceLibraryItems |
        Where-Object { $_["FSObjType"] -eq 1 -and -not [string]::IsNullOrWhiteSpace([string]$_["FileRef"]) } |
        Sort-Object { ([string]$_["FileRef"]).Length }, { [string]$_["FileRef"] }
    )

    $sourceFilesToCopy = @($sourceLibraryItems | Where-Object { $_["FSObjType"] -eq 0 })
    foreach ($folderItem in $sourceFoldersToEnsure) {
        $sourceFolderRef = [string]$folderItem["FileRef"]
        $targetFolderRef = $sourceFolderRef -replace [regex]::Escape("/BGV Records/"), "/PEV Records/"
        if (-not [string]::IsNullOrWhiteSpace($sourceWebRoot) -and $targetFolderRef.StartsWith($sourceWebRoot + "/")) {
            $targetFolderRef = $targetWebRoot + $targetFolderRef.Substring($sourceWebRoot.Length)
        }
        if ($targetFolderRefs.Contains($targetFolderRef)) { continue }
        Ensure-PevFolderPath -Connection $targetConnection -ServerRelativeFolderPath $targetFolderRef
        $targetFolderRefs.Add($targetFolderRef) | Out-Null
        $ensuredFolderCount++
    }

    $tempDirectory = Join-Path $env:TEMP ("pev_migration_copy_{0}" -f [guid]::NewGuid().Guid)
    New-Item -ItemType Directory -Force -Path $tempDirectory | Out-Null
    try {
        foreach ($fileItem in $sourceFilesToCopy) {
            $sourceFileRef = [string]$fileItem["FileRef"]
            $targetFileRef = $sourceFileRef -replace [regex]::Escape("/BGV Records/"), "/PEV Records/"
            if (-not [string]::IsNullOrWhiteSpace($sourceWebRoot) -and $targetFileRef.StartsWith($sourceWebRoot + "/")) {
                $targetFileRef = $targetWebRoot + $targetFileRef.Substring($sourceWebRoot.Length)
            }
            if ($targetFileRef -in $targetFileRefs) { continue }
            $fileName = [string]$fileItem["FileLeafRef"]
            $relativeFolder = (Split-Path $targetFileRef -Parent).Replace("\", "/")
            if (-not [string]::IsNullOrWhiteSpace($relativeFolder) -and -not $relativeFolder.StartsWith("/")) {
                $relativeFolder = "/" + $relativeFolder.TrimStart("/")
            }
            Ensure-PevFolderPath -Connection $targetConnection -ServerRelativeFolderPath $relativeFolder
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
                    Error = [string]$_.Exception.Message
                })
                Write-Warning ("Skipping file due to copy error: {0} -> {1} | {2}" -f $sourceFileRef, $targetFileRef, $_.Exception.Message)
            }
        }
    }
    finally {
        if (Test-Path $tempDirectory) { Remove-Item -Recurse -Force $tempDirectory }
    }
}
else {
    Write-BgvInfo "Skipping file copy."
}

$payload = [ordered]@{
    GeneratedAtUtc = (Get-Date).ToUniversalTime().ToString("o")
    SourceSiteUrl = $SourceSiteUrl
    TargetSiteUrl = $TargetSiteUrl
    CandidateCount = $candidateResults.Count
    RequestCount = $requestResults.Count
    FormDataCount = $formDataResults.Count
    EnsuredFolderCount = $ensuredFolderCount
    FileCount = $copiedFiles.Count
    FailedFileCount = $failedFiles.Count
    Candidates = @($candidateResults.ToArray())
    Requests = @($requestResults.ToArray())
    FormData = @($formDataResults.ToArray())
    Files = @($copiedFiles.ToArray())
    FailedFiles = @($failedFiles.ToArray())
}

Write-BgvJsonFile -Path $OutputPath -Value $payload
Write-BgvInfo "PEV copy results written to $OutputPath"
