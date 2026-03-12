param(
    [ValidateSet("ClosedHistory", "LegacyDrain", "All")]
    [string]$Mode = "All",
    [string]$SourceSiteUrl = $env:BGV_SOURCE_SPO_SITE_URL,
    [string]$TargetSiteUrl = $env:BGV_TARGET_SPO_SITE_URL,
    [string]$ManifestPath = "",
    [string]$ClientId = $env:PNP_CLIENT_ID,
    [string]$TenantId = $env:PNP_TENANT_ID,
    [string]$PythonExe = "py",
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
    $OutputPath = Join-Path $repoRoot ("out\migration\validate_{0}.json" -f $Mode.ToLowerInvariant())
}

function Get-BgvSampleIds {
    param(
        [string[]]$Values,
        [int]$Count = 10
    )

    if (-not $Values -or $Values.Count -eq 0) {
        return @()
    }

    return @($Values | Sort-Object | Get-Random -Count ([Math]::Min($Values.Count, $Count)))
}

function Get-BgvValidationSelection {
    param(
        [string]$ModeName,
        [string]$ManifestFilePath,
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
    if ($ModeName -eq "LegacyDrain") {
        return [ordered]@{
            CandidateIds = @($manifest.LegacyOpenCandidateIds)
            RequestIds   = @($manifest.LegacyOpenRequestIds)
            RecordKeys   = @($manifest.LegacyOpenRecordKeys)
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
        CandidateIds = @($manifest.ClosedHistoryCandidateIds + $manifest.LegacyOpenCandidateIds | Sort-Object -Unique)
        RequestIds   = @($manifest.ClosedHistoryRequestIds + $manifest.LegacyOpenRequestIds | Sort-Object -Unique)
        RecordKeys   = @($manifest.ClosedHistoryRecordKeys + $manifest.LegacyOpenRecordKeys | Sort-Object -Unique)
    }
}

function Get-BgvComparableFieldNames {
    param(
        [Parameter(Mandatory = $true)]
        $Connection,
        [Parameter(Mandatory = $true)]
        [string]$ListTitle
    )

    $names = @("Title")
    $formDataExcluded = @()
    if ($ListTitle -eq "BGV_FormData") {
        # These are remapped to target-site item IDs during migration and are expected to differ from source.
        $formDataExcluded = @("CandidateItemID", "RecordItemID")
    }
    foreach ($field in Get-PnPField -List $ListTitle -Connection $Connection) {
        if ($field.Hidden -or $field.ReadOnlyField) {
            continue
        }
        if ($field.InternalName -in $formDataExcluded) {
            continue
        }
        if ($field.InternalName -in (Get-BgvExcludedFieldNames | Where-Object { $_ -ne "Title" })) {
            continue
        }
        $names += $field.InternalName
    }
    return @($names | Sort-Object -Unique)
}

function Convert-BgvItemToComparableMap {
    param(
        [Parameter(Mandatory = $true)]
        $Item,
        [Parameter(Mandatory = $true)]
        [string[]]$FieldNames
    )

    $map = [ordered]@{}
    foreach ($fieldName in $FieldNames) {
        if ($Item.FieldValues.ContainsKey($fieldName)) {
            $value = $Item[$fieldName]
            if ($value -is [datetime]) {
                $map[$fieldName] = $value.ToString("o")
            }
            elseif ($value -is [array]) {
                $map[$fieldName] = @($value | ForEach-Object { "$_" })
            }
            else {
                $map[$fieldName] = "$value"
            }
        }
    }
    return $map
}

Write-BgvStep "Connect to source and target SharePoint sites"
$sourceConnection = Connect-BgvPnPSite -Url $SourceSiteUrl -ClientId $ClientId -TenantId $TenantId
$targetConnection = Connect-BgvPnPSite -Url $TargetSiteUrl -ClientId $ClientId -TenantId $TenantId
$selection = Get-BgvValidationSelection -ModeName $Mode -ManifestFilePath $ManifestPath -SourceConnection $sourceConnection

$candidateFields = Get-BgvComparableFieldNames -Connection $sourceConnection -ListTitle "BGV_Candidates"
$requestFields = Get-BgvComparableFieldNames -Connection $sourceConnection -ListTitle "BGV_Requests"
$formDataFields = Get-BgvComparableFieldNames -Connection $sourceConnection -ListTitle "BGV_FormData"

$sourceCandidates = @(Get-PnPListItem -List "BGV_Candidates" -Connection $sourceConnection -PageSize 5000)
$targetCandidates = @(Get-PnPListItem -List "BGV_Candidates" -Connection $targetConnection -PageSize 5000)
$sourceRequests = @(Get-PnPListItem -List "BGV_Requests" -Connection $sourceConnection -PageSize 5000)
$targetRequests = @(Get-PnPListItem -List "BGV_Requests" -Connection $targetConnection -PageSize 5000)
$sourceFormData = @(Get-PnPListItem -List "BGV_FormData" -Connection $sourceConnection -PageSize 5000)
$targetFormData = @(Get-PnPListItem -List "BGV_FormData" -Connection $targetConnection -PageSize 5000)

$sourceCandidateMap = @{}
$targetCandidateMap = @{}
foreach ($item in $sourceCandidates) { $sourceCandidateMap[[string]$item["CandidateID"]] = $item }
foreach ($item in $targetCandidates) { $targetCandidateMap[[string]$item["CandidateID"]] = $item }
$sourceRequestMap = @{}
$targetRequestMap = @{}
foreach ($item in $sourceRequests) { $sourceRequestMap[[string]$item["RequestID"]] = $item }
foreach ($item in $targetRequests) { $targetRequestMap[[string]$item["RequestID"]] = $item }
$sourceFormDataMap = @{}
$targetFormDataMap = @{}
foreach ($item in $sourceFormData) { $sourceFormDataMap[[string]$item["RecordKey"]] = $item }
foreach ($item in $targetFormData) { $targetFormDataMap[[string]$item["RecordKey"]] = $item }

$candidateCountMatch = ($selection.CandidateIds.Count -eq (@($selection.CandidateIds | Where-Object { $targetCandidateMap.ContainsKey($_) }).Count))
$requestCountMatch = ($selection.RequestIds.Count -eq (@($selection.RequestIds | Where-Object { $targetRequestMap.ContainsKey($_) }).Count))
$formDataCountMatch = ($selection.RecordKeys.Count -eq (@($selection.RecordKeys | Where-Object { $targetFormDataMap.ContainsKey($_) }).Count))

$candidateMismatches = @()
foreach ($candidateId in Get-BgvSampleIds -Values $selection.CandidateIds) {
    if (-not $sourceCandidateMap.ContainsKey($candidateId) -or -not $targetCandidateMap.ContainsKey($candidateId)) {
        $candidateMismatches += $candidateId
        continue
    }
    $sourceMap = Convert-BgvItemToComparableMap -Item $sourceCandidateMap[$candidateId] -FieldNames $candidateFields
    $targetMap = Convert-BgvItemToComparableMap -Item $targetCandidateMap[$candidateId] -FieldNames $candidateFields
    if (($sourceMap | ConvertTo-Json -Depth 6) -ne ($targetMap | ConvertTo-Json -Depth 6)) {
        $candidateMismatches += $candidateId
    }
}

$requestMismatches = @()
foreach ($requestId in Get-BgvSampleIds -Values $selection.RequestIds) {
    if (-not $sourceRequestMap.ContainsKey($requestId) -or -not $targetRequestMap.ContainsKey($requestId)) {
        $requestMismatches += $requestId
        continue
    }
    $sourceMap = Convert-BgvItemToComparableMap -Item $sourceRequestMap[$requestId] -FieldNames $requestFields
    $targetMap = Convert-BgvItemToComparableMap -Item $targetRequestMap[$requestId] -FieldNames $requestFields
    if (($sourceMap | ConvertTo-Json -Depth 6) -ne ($targetMap | ConvertTo-Json -Depth 6)) {
        $requestMismatches += $requestId
    }
}

$formDataMismatches = @()
foreach ($recordKey in Get-BgvSampleIds -Values $selection.RecordKeys) {
    if (-not $sourceFormDataMap.ContainsKey($recordKey) -or -not $targetFormDataMap.ContainsKey($recordKey)) {
        $formDataMismatches += $recordKey
        continue
    }
    $sourceMap = Convert-BgvItemToComparableMap -Item $sourceFormDataMap[$recordKey] -FieldNames $formDataFields
    $targetMap = Convert-BgvItemToComparableMap -Item $targetFormDataMap[$recordKey] -FieldNames $formDataFields
    if (($sourceMap | ConvertTo-Json -Depth 6) -ne ($targetMap | ConvertTo-Json -Depth 6)) {
        $formDataMismatches += $recordKey
    }
}

Write-BgvStep "Compare BGV Records file counts"
$sourceFiles = @(Get-PnPListItem -List "BGV Records" -Connection $sourceConnection -PageSize 5000 -Fields "FileRef", "FSObjType" | Where-Object { $_["FSObjType"] -eq 0 })
$targetFiles = @(Get-PnPListItem -List "BGV Records" -Connection $targetConnection -PageSize 5000 -Fields "FileRef", "FSObjType" | Where-Object { $_["FSObjType"] -eq 0 })
if ($Mode -eq "All") {
    $sourceSelectedFiles = $sourceFiles
    $targetSelectedFiles = $targetFiles
}
else {
    $candidatePatterns = @($selection.CandidateIds | ForEach-Object { "/Candidate Files/$_/" })
    $sourceSelectedFiles = @($sourceFiles | Where-Object {
            $ref = [string]$_["FileRef"]
            $candidatePatterns | Where-Object { $ref.Contains($_) }
        })
    $targetSelectedFiles = @($targetFiles | Where-Object {
            $ref = [string]$_["FileRef"]
            $candidatePatterns | Where-Object { $ref.Contains($_) }
        })
}

Write-BgvStep "Run portability guard"
Require-BgvCommand $PythonExe
$portabilityOutput = & $PythonExe "scripts/active/check_bgv_portability.py" --repo-root $repoRoot 2>&1
$portabilityPassed = $LASTEXITCODE -eq 0

$payload = [ordered]@{
    GeneratedAtUtc      = (Get-Date).ToUniversalTime().ToString("o")
    Mode                = $Mode
    SourceSiteUrl       = $SourceSiteUrl
    TargetSiteUrl       = $TargetSiteUrl
    Counts              = [ordered]@{
        CandidateIdsSelected = $selection.CandidateIds.Count
        CandidateRowsPresent = @($selection.CandidateIds | Where-Object { $targetCandidateMap.ContainsKey($_) }).Count
        RequestIdsSelected   = $selection.RequestIds.Count
        RequestRowsPresent   = @($selection.RequestIds | Where-Object { $targetRequestMap.ContainsKey($_) }).Count
        RecordKeysSelected   = $selection.RecordKeys.Count
        RecordRowsPresent    = @($selection.RecordKeys | Where-Object { $targetFormDataMap.ContainsKey($_) }).Count
        SourceFileCount      = $sourceSelectedFiles.Count
        TargetFileCount      = $targetSelectedFiles.Count
    }
    CountChecks          = [ordered]@{
        CandidateCountMatch = $candidateCountMatch
        RequestCountMatch   = $requestCountMatch
        FormDataCountMatch  = $formDataCountMatch
        FileCountMatch      = ($sourceSelectedFiles.Count -eq $targetSelectedFiles.Count)
    }
    SampleMismatches     = [ordered]@{
        CandidateIds = $candidateMismatches
        RequestIds   = $requestMismatches
        RecordKeys   = $formDataMismatches
    }
    PortabilityGuard     = [ordered]@{
        Passed  = $portabilityPassed
        Message = ($portabilityOutput -join [Environment]::NewLine)
    }
}

Write-BgvJsonFile -Path $OutputPath -Value $payload
Write-BgvInfo "Validation results written to $OutputPath"
if (-not $portabilityPassed) {
    throw "Portability guard failed. See $OutputPath for details."
}
