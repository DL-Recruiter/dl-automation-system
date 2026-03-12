Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Write-BgvInfo {
    param([string]$Message)
    Write-Host "[INFO] $Message"
}

function Write-BgvStep {
    param([string]$Message)
    Write-Host ""
    Write-Host "=== $Message ==="
}

function Require-BgvCommand {
    param([string]$Name)
    if (-not (Get-Command $Name -ErrorAction SilentlyContinue)) {
        throw "Required command not found in PATH: $Name"
    }
}

function Invoke-BgvChecked {
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

function Get-BgvRepoRoot {
    param([string]$CurrentPath)

    if ([string]::IsNullOrWhiteSpace($CurrentPath)) {
        $CurrentPath = $PSScriptRoot
    }

    $resolvedPath = Resolve-Path $CurrentPath
    $directory = Get-Item $resolvedPath
    if ($directory.PSIsContainer -eq $false) {
        $directory = $directory.Directory
    }

    while ($directory -and -not (Test-Path (Join-Path $directory.FullName ".git"))) {
        $directory = $directory.Parent
    }

    if (-not $directory) {
        throw "Unable to locate repo root from path: $CurrentPath"
    }

    return $directory.FullName
}

function ConvertTo-BgvHashtable {
    param($Value)

    if ($null -eq $Value) {
        return $null
    }
    if ($Value -is [System.Collections.IDictionary]) {
        $map = @{}
        foreach ($key in $Value.Keys) {
            $map[[string]$key] = ConvertTo-BgvHashtable -Value $Value[$key]
        }
        return $map
    }
    if ($Value -is [System.Collections.IEnumerable] -and -not ($Value -is [string])) {
        $items = @()
        foreach ($item in $Value) {
            $items += ,(ConvertTo-BgvHashtable -Value $item)
        }
        return $items
    }
    if ($Value -is [System.Management.Automation.PSCustomObject]) {
        $map = @{}
        foreach ($property in @($Value.PSObject.Properties)) {
            $map[$property.Name] = ConvertTo-BgvHashtable -Value $property.Value
        }
        return $map
    }
    return $Value
}

function ConvertFrom-BgvJson {
    param([Parameter(Mandatory = $true)]$Text)

    $normalizedText = ""
    if ($null -eq $Text) {
        $normalizedText = ""
    }
    elseif ($Text -is [string]) {
        $normalizedText = $Text
    }
    elseif ($Text -is [System.Collections.IEnumerable]) {
        # CLI output often arrives as string[] lines; normalize to one JSON text block.
        $normalizedText = (@($Text) | ForEach-Object { [string]$_ }) -join [Environment]::NewLine
    }
    else {
        $normalizedText = [string]$Text
    }

    if ([string]::IsNullOrWhiteSpace($normalizedText)) {
        return @{}
    }

    $jsonObject = $normalizedText | ConvertFrom-Json
    return ConvertTo-BgvHashtable -Value $jsonObject
}

function Get-BgvStoreSpecifications {
    return @(
        [ordered]@{ Title = "BGV_Candidates"; Template = 100; KeyField = "CandidateID"; Kind = "List" },
        [ordered]@{ Title = "BGV_Requests"; Template = 100; KeyField = "RequestID"; Kind = "List" },
        [ordered]@{ Title = "BGV_FormData"; Template = 100; KeyField = "RecordKey"; Kind = "List" },
        [ordered]@{ Title = "BGV Records"; Template = 101; KeyField = "FileRef"; Kind = "Library" }
    )
}

function Connect-BgvPnPSite {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Url,
        [string]$ClientId = $env:PNP_CLIENT_ID,
        [string]$TenantId = $env:PNP_TENANT_ID
    )

    if ([string]::IsNullOrWhiteSpace($ClientId)) {
        throw "PNP_CLIENT_ID must be provided via parameter or environment variable."
    }
    if ([string]::IsNullOrWhiteSpace($TenantId)) {
        throw "PNP_TENANT_ID must be provided via parameter or environment variable."
    }

    return Connect-PnPOnline -Url $Url -Interactive -ClientId $ClientId -Tenant $TenantId -ReturnConnection
}

function Get-BgvPnPListOrNull {
    param(
        [Parameter(Mandatory = $true)]
        $Connection,
        [Parameter(Mandatory = $true)]
        [string]$Title
    )

    try {
        return Get-PnPList -Identity $Title -Connection $Connection -Includes Id, Title, BaseTemplate, ItemCount, RootFolder
    }
    catch {
        return $null
    }
}

function ConvertTo-BgvBoolean {
    param($Value)

    if ($null -eq $Value) {
        return $false
    }
    if ($Value -is [bool]) {
        return [bool]$Value
    }

    $normalized = $Value.ToString().Trim().ToLowerInvariant()
    return $normalized -eq "true" -or $normalized -eq "1" -or $normalized -eq "yes"
}

function Get-BgvExcludedFieldNames {
    return @(
        "_CommentCount",
        "_ComplianceFlags",
        "_ComplianceTag",
        "_ComplianceTagUserId",
        "_ComplianceTagWrittenTime",
        "_DisplayName",
        "_EditMenuTableEnd",
        "_EditMenuTableStart",
        "_HasCopyDestinations",
        "_IsCurrentVersion",
        "_LikeCount",
        "_ModerationComments",
        "_ModerationStatus",
        "_UIVersion",
        "_UIVersionString",
        "AppAuthor",
        "AppEditor",
        "Attachments",
        "Author",
        "CheckoutUser",
        "ComplianceAssetId",
        "ContentType",
        "ContentTypeId",
        "Created",
        "Created_x0020_Date",
        "DocIcon",
        "Editor",
        "FileDirRef",
        "FileLeafRef",
        "FileRef",
        "File_x0020_Type",
        "FolderChildCount",
        "FSObjType",
        "GUID",
        "ID",
        "InstanceID",
        "ItemChildCount",
        "LinkFilename",
        "LinkFilenameNoMenu",
        "LinkTitle",
        "LinkTitleNoMenu",
        "Modified",
        "Order",
        "PermMask",
        "ProgId",
        "ScopeId",
        "SelectFilename",
        "SelectTitle",
        "ServerRedirectedEmbedUri",
        "ServerRedirectedEmbedUrl",
        "SortBehavior",
        "SyncClientId",
        "Title"
    )
}

function Get-BgvProvisionableFields {
    param(
        [Parameter(Mandatory = $true)]
        $Connection,
        [Parameter(Mandatory = $true)]
        [string]$ListTitle
    )

    $excluded = Get-BgvExcludedFieldNames
    return @(Get-PnPField -List $ListTitle -Connection $Connection | Where-Object {
            -not $_.Hidden -and
            -not $_.ReadOnlyField -and
            $_.InternalName -notin $excluded -and
            -not $_.Sealed -and
            -not $_.FromBaseType
        })
}

function Get-BgvFieldSnapshot {
    param($Field)

    return [ordered]@{
        Title         = $Field.Title
        InternalName  = $Field.InternalName
        TypeAsString  = $Field.TypeAsString
        Required      = [bool]$Field.Required
        Hidden        = [bool]$Field.Hidden
        ReadOnlyField = [bool]$Field.ReadOnlyField
    }
}

function Get-BgvListInventory {
    param(
        [Parameter(Mandatory = $true)]
        $Connection,
        [Parameter(Mandatory = $true)]
        [string]$Title
    )

    $list = Get-BgvPnPListOrNull -Connection $Connection -Title $Title
    if (-not $list) {
        return [ordered]@{
            Title      = $Title
            Exists     = $false
            BaseTemplate = $null
            ItemCount  = 0
            Fields     = @()
        }
    }

    $fields = @()
    foreach ($field in Get-PnPField -List $Title -Connection $Connection) {
        $fields += Get-BgvFieldSnapshot -Field $field
    }

    return [ordered]@{
        Title        = $list.Title
        Exists       = $true
        Id           = $list.Id
        BaseTemplate = $list.BaseTemplate
        ItemCount    = $list.ItemCount
        RootFolder   = $list.RootFolder.ServerRelativeUrl
        Fields       = $fields
    }
}

function Get-BgvCaseManifest {
    param([Parameter(Mandatory = $true)]$Connection)

    $candidateItems = @(Get-PnPListItem -List "BGV_Candidates" -Connection $Connection -PageSize 5000 -Fields "CandidateID", "AuthorisationSigned")
    $requestItems = @(Get-PnPListItem -List "BGV_Requests" -Connection $Connection -PageSize 5000 -Fields "CandidateID", "RequestID", "ResponseReceivedAt")
    $formDataItems = @(Get-PnPListItem -List "BGV_FormData" -Connection $Connection -PageSize 5000 -Fields "CandidateID", "RequestID", "RecordKey")

    $requestsByCandidate = @{}
    foreach ($requestItem in $requestItems) {
        $candidateId = [string]$requestItem["CandidateID"]
        if ([string]::IsNullOrWhiteSpace($candidateId)) {
            continue
        }
        if (-not $requestsByCandidate.ContainsKey($candidateId)) {
            $requestsByCandidate[$candidateId] = @()
        }
        $requestsByCandidate[$candidateId] += $requestItem
    }

    $formDataByCandidate = @{}
    foreach ($recordItem in $formDataItems) {
        $candidateId = [string]$recordItem["CandidateID"]
        if ([string]::IsNullOrWhiteSpace($candidateId)) {
            continue
        }
        if (-not $formDataByCandidate.ContainsKey($candidateId)) {
            $formDataByCandidate[$candidateId] = @()
        }
        $formDataByCandidate[$candidateId] += $recordItem
    }

    $legacyOpenCandidateIds = New-Object System.Collections.Generic.List[string]
    $closedHistoryCandidateIds = New-Object System.Collections.Generic.List[string]
    $legacyOpenRequestIds = New-Object System.Collections.Generic.List[string]
    $closedHistoryRequestIds = New-Object System.Collections.Generic.List[string]
    $legacyOpenRecordKeys = New-Object System.Collections.Generic.List[string]
    $closedHistoryRecordKeys = New-Object System.Collections.Generic.List[string]

    foreach ($candidateItem in $candidateItems) {
        $candidateId = [string]$candidateItem["CandidateID"]
        if ([string]::IsNullOrWhiteSpace($candidateId)) {
            continue
        }

        $candidateSigned = ConvertTo-BgvBoolean $candidateItem["AuthorisationSigned"]
        $candidateRequests = @()
        if ($requestsByCandidate.ContainsKey($candidateId)) {
            $candidateRequests = @($requestsByCandidate[$candidateId])
        }

        $hasOutstandingRequest = $false
        foreach ($requestItem in $candidateRequests) {
            if ([string]::IsNullOrWhiteSpace([string]$requestItem["ResponseReceivedAt"])) {
                $hasOutstandingRequest = $true
                break
            }
        }

        $isLegacyOpen = (-not $candidateSigned) -or $hasOutstandingRequest
        if ($isLegacyOpen) {
            $legacyOpenCandidateIds.Add($candidateId)
        }
        else {
            $closedHistoryCandidateIds.Add($candidateId)
        }

        foreach ($requestItem in $candidateRequests) {
            $requestId = [string]$requestItem["RequestID"]
            if ([string]::IsNullOrWhiteSpace($requestId)) {
                continue
            }
            if ($isLegacyOpen) {
                $legacyOpenRequestIds.Add($requestId)
            }
            else {
                $closedHistoryRequestIds.Add($requestId)
            }
        }

        if ($formDataByCandidate.ContainsKey($candidateId)) {
            foreach ($recordItem in $formDataByCandidate[$candidateId]) {
                $recordKey = [string]$recordItem["RecordKey"]
                if ([string]::IsNullOrWhiteSpace($recordKey)) {
                    continue
                }
                if ($isLegacyOpen) {
                    $legacyOpenRecordKeys.Add($recordKey)
                }
                else {
                    $closedHistoryRecordKeys.Add($recordKey)
                }
            }
        }
    }

    return [ordered]@{
        LegacyOpenCandidateIds  = @($legacyOpenCandidateIds | Sort-Object -Unique)
        ClosedHistoryCandidateIds = @($closedHistoryCandidateIds | Sort-Object -Unique)
        LegacyOpenRequestIds    = @($legacyOpenRequestIds | Sort-Object -Unique)
        ClosedHistoryRequestIds = @($closedHistoryRequestIds | Sort-Object -Unique)
        LegacyOpenRecordKeys    = @($legacyOpenRecordKeys | Sort-Object -Unique)
        ClosedHistoryRecordKeys = @($closedHistoryRecordKeys | Sort-Object -Unique)
    }
}

function Write-BgvJsonFile {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path,
        [Parameter(Mandatory = $true)]
        $Value
    )

    $directory = Split-Path -Parent $Path
    if ($directory) {
        New-Item -ItemType Directory -Force -Path $directory | Out-Null
    }

    $Value | ConvertTo-Json -Depth 12 | Set-Content -Path $Path -Encoding utf8
}

function Get-BgvTemplateGraphMetadata {
    param(
        [Parameter(Mandatory = $true)]
        [string]$SiteUrl,
        [Parameter(Mandatory = $true)]
        [string]$ServerRelativeFilePath
    )

    $uri = [System.Uri]$SiteUrl
    $siteLookupUrl = "https://graph.microsoft.com/v1.0/sites/{0}:{1}?`$select=id" -f $uri.Host, $uri.AbsolutePath
    $relativePath = $ServerRelativeFilePath.TrimStart("/").Replace("\", "/")
    $candidateRelativePaths = New-Object System.Collections.Generic.List[string]

    function Add-BgvCandidateRelativePath {
        param(
            [Parameter(Mandatory = $true)]
            [string]$Path
        )

        $normalized = $Path.Trim().Trim("/").Replace("\", "/")
        if ([string]::IsNullOrWhiteSpace($normalized)) {
            return
        }
        if (-not $candidateRelativePaths.Contains($normalized)) {
            $candidateRelativePaths.Add($normalized)
        }
    }

    Add-BgvCandidateRelativePath -Path $relativePath

    $siteRelativePrefix = $uri.AbsolutePath.Trim("/")
    if (-not [string]::IsNullOrWhiteSpace($siteRelativePrefix)) {
        if ($relativePath.StartsWith($siteRelativePrefix + "/", [System.StringComparison]::OrdinalIgnoreCase)) {
            Add-BgvCandidateRelativePath -Path $relativePath.Substring($siteRelativePrefix.Length + 1)
        }
    }

    foreach ($libraryMarker in @("/Shared Documents/", "/Documents/")) {
        $markerIndex = $relativePath.IndexOf($libraryMarker, [System.StringComparison]::OrdinalIgnoreCase)
        if ($markerIndex -ge 0) {
            Add-BgvCandidateRelativePath -Path $relativePath.Substring($markerIndex + $libraryMarker.Length)
        }
    }

    $templatesIndex = $relativePath.IndexOf("/BGV Templates/", [System.StringComparison]::OrdinalIgnoreCase)
    if ($templatesIndex -ge 0) {
        Add-BgvCandidateRelativePath -Path $relativePath.Substring($templatesIndex + 1)
    }

    $siteLookup = $null
    $fileLookup = $null
    $siteId = ""
    $invokeGraphGet = $null

    if ((Get-Command Invoke-MgGraphRequest -ErrorAction SilentlyContinue) -and (Get-MgContext)) {
        $siteLookup = Invoke-MgGraphRequest -Method GET -Uri $siteLookupUrl
        $invokeGraphGet = {
            param([string]$RequestUrl)
            Invoke-MgGraphRequest -Method GET -Uri $RequestUrl
        }
    }
    else {
        Require-BgvCommand "m365"
        $token = (& m365 util accesstoken get --resource "https://graph.microsoft.com" --output text).Trim()
        if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace($token)) {
            throw "Unable to acquire Graph token via CLI for Microsoft 365."
        }

        $headers = @{ Authorization = "Bearer $token" }
        $siteLookup = Invoke-RestMethod -Method Get -Uri $siteLookupUrl -Headers $headers
        $invokeGraphGet = {
            param([string]$RequestUrl)
            Invoke-RestMethod -Method Get -Uri $RequestUrl -Headers $headers
        }
    }

    $siteId = [string]$siteLookup.id
    if ([string]::IsNullOrWhiteSpace($siteId)) {
        throw "Unable to resolve Graph site ID for $SiteUrl"
    }

    $lookupError = $null
    foreach ($candidateRelativePath in @($candidateRelativePaths)) {
        $encodedRelativePath = [System.Uri]::EscapeDataString($candidateRelativePath).Replace("%2F", "/")
        $fileLookupUrl = "https://graph.microsoft.com/v1.0/sites/{0}/drive/root:/{1}?`$select=id,parentReference" -f $siteId, $encodedRelativePath
        try {
            $fileLookup = & $invokeGraphGet $fileLookupUrl
            if ($fileLookup -and $fileLookup.id) {
                break
            }
        }
        catch {
            $lookupError = $_
        }
    }

    if (-not $fileLookup -or [string]::IsNullOrWhiteSpace([string]$fileLookup.id)) {
        $candidateText = ($candidateRelativePaths -join ", ")
        $errorMessage = if ($lookupError) { $lookupError.Exception.Message } else { "unknown error" }
        throw "Unable to resolve Graph file metadata for $ServerRelativeFilePath. Candidates: $candidateText. LastError: $errorMessage"
    }

    $driveId = [string]$fileLookup.parentReference.driveId
    $fileId = [string]$fileLookup.id

    if ([string]::IsNullOrWhiteSpace($driveId) -or [string]::IsNullOrWhiteSpace($fileId)) {
        throw "Unable to resolve Graph drive/file IDs for $ServerRelativeFilePath"
    }

    return [ordered]@{
        Source = "sites/$siteId"
        DriveId = $driveId
        FileId = $fileId
    }
}

function Get-BgvFieldXmlForTarget {
    param(
        [Parameter(Mandatory = $true)]
        $Field,
        [hashtable]$LookupTargetIds = @{},
        [string]$TargetWebId = ""
    )

    $fieldXml = [string]$Field.SchemaXml
    if ($Field.TypeAsString -like "Lookup*" -and $LookupTargetIds.ContainsKey($Field.InternalName)) {
        $targetListId = [string]$LookupTargetIds[$Field.InternalName]
        $fieldXml = [regex]::Replace($fieldXml, 'List="\{[^"]+\}"', ('List="{{{0}}}"' -f $targetListId.Trim("{}")))
        if (-not [string]::IsNullOrWhiteSpace($TargetWebId)) {
            $fieldXml = [regex]::Replace($fieldXml, 'WebId="\{[^"]+\}"', ('WebId="{{{0}}}"' -f $TargetWebId.Trim("{}")))
        }
    }
    return $fieldXml
}
