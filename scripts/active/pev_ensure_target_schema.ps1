param(
    [string]$SourceSiteUrl = $env:BGV_SOURCE_SPO_SITE_URL,
    [string]$TargetSiteUrl = $env:PEV_TARGET_SPO_SITE_URL,
    [string]$ClientId = $env:PNP_CLIENT_ID,
    [string]$TenantId = $env:PNP_TENANT_ID,
    [string]$TemplateSourcePath = "",
    [string]$OutputPath = ""
)

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
. (Join-Path (Split-Path -Parent (Split-Path -Parent $scriptDir)) "shared\bgv_migration_common.ps1")

$repoRoot = Get-BgvRepoRoot -CurrentPath $scriptDir
if ([string]::IsNullOrWhiteSpace($SourceSiteUrl)) {
    throw "SourceSiteUrl must be provided via parameter or BGV_SOURCE_SPO_SITE_URL."
}
if ([string]::IsNullOrWhiteSpace($TargetSiteUrl)) {
    throw "TargetSiteUrl must be provided via parameter or PEV_TARGET_SPO_SITE_URL."
}
if ([string]::IsNullOrWhiteSpace($TemplateSourcePath)) {
    $TemplateSourcePath = Join-Path $repoRoot "AuthorizationLetter_Template.docx"
}
if (-not (Test-Path $TemplateSourcePath)) {
    throw "Template source file not found: $TemplateSourcePath"
}
if ([string]::IsNullOrWhiteSpace($OutputPath)) {
    $OutputPath = Join-Path $repoRoot "out\migration\pev_target_schema.json"
}

$storeMap = @(
    [ordered]@{ SourceTitle = "BGV_Candidates"; TargetTitle = "PEV_Candidates"; Template = 100 },
    [ordered]@{ SourceTitle = "BGV_Requests"; TargetTitle = "PEV_Requests"; Template = 100 },
    [ordered]@{ SourceTitle = "BGV_FormData"; TargetTitle = "PEV_FormData"; Template = 100 },
    [ordered]@{ SourceTitle = "BGV Records"; TargetTitle = "PEV Records"; Template = 101 }
)

function Ensure-PevFolder {
    param(
        [Parameter(Mandatory = $true)]$Connection,
        [Parameter(Mandatory = $true)][string]$ParentFolder,
        [Parameter(Mandatory = $true)][string]$Name
    )

    $targetPath = ($ParentFolder.TrimEnd("/") + "/" + $Name.Trim("/")).Trim("/")
    try {
        Get-PnPFolder -Url $targetPath -Connection $Connection | Out-Null
    }
    catch {
        try {
            Add-PnPFolder -Name $Name -Folder $ParentFolder -Connection $Connection | Out-Null
        }
        catch {
            if (-not ($_.Exception.Message -match "already exists")) {
                throw
            }
        }
    }
}

function Get-PevTargetDocumentsList {
    param([Parameter(Mandatory = $true)]$Connection)

    foreach ($title in @("Documents", "Shared Documents")) {
        $list = Get-BgvPnPListOrNull -Connection $Connection -Title $title
        if ($list) { return $list }
    }

    $fallback = Get-PnPList -Connection $Connection | Where-Object { $_.BaseTemplate -eq 101 -and $_.Title -ne "PEV Records" } | Select-Object -First 1
    if (-not $fallback) {
        throw "Unable to locate a default target documents library."
    }
    return $fallback
}

Write-BgvStep "Connect to source and target SharePoint sites"
$sourceConnection = Connect-BgvPnPSite -Url $SourceSiteUrl -ClientId $ClientId -TenantId $TenantId
$targetConnection = Connect-BgvPnPSite -Url $TargetSiteUrl -ClientId $ClientId -TenantId $TenantId
$targetWeb = Get-PnPWeb -Connection $targetConnection -Includes Id

Write-BgvStep "Ensure parallel PEV lists and library exist"
$results = @()
foreach ($spec in $storeMap) {
    $sourceList = Get-BgvPnPListOrNull -Connection $sourceConnection -Title $spec.SourceTitle
    if (-not $sourceList) {
        throw "Source store not found: $($spec.SourceTitle)"
    }

    $targetList = Get-BgvPnPListOrNull -Connection $targetConnection -Title $spec.TargetTitle
    if (-not $targetList) {
        $templateName = if ($spec.Template -eq 101) { "DocumentLibrary" } else { "GenericList" }
        New-PnPList -Title $spec.TargetTitle -Template $templateName -Connection $targetConnection | Out-Null
        $targetList = Get-BgvPnPListOrNull -Connection $targetConnection -Title $spec.TargetTitle
    }

    if ([int]$targetList.BaseTemplate -ne [int]$sourceList.BaseTemplate) {
        throw "Target store '$($spec.TargetTitle)' exists with base template $($targetList.BaseTemplate), expected $($sourceList.BaseTemplate)."
    }

    $targetExistingFields = @(Get-PnPField -List $spec.TargetTitle -Connection $targetConnection)
    $targetFieldMap = @{}
    foreach ($field in $targetExistingFields) { $targetFieldMap[$field.InternalName] = $field }

    $lookupTargetIds = @{}
    if ($spec.TargetTitle -eq "PEV_Requests" -or $spec.TargetTitle -eq "PEV_FormData") {
        $candidateTargetList = Get-BgvPnPListOrNull -Connection $targetConnection -Title "PEV_Candidates"
        if ($candidateTargetList) {
            $lookupTargetIds["CandidateItemID"] = $candidateTargetList.Id.Guid
        }
    }
    if ($spec.TargetTitle -eq "PEV_FormData") {
        $requestTargetList = Get-BgvPnPListOrNull -Connection $targetConnection -Title "PEV_Requests"
        if ($requestTargetList) {
            $lookupTargetIds["RecordItemID"] = $requestTargetList.Id.Guid
        }
    }

    $createdFields = New-Object System.Collections.Generic.List[string]
    foreach ($field in Get-BgvProvisionableFields -Connection $sourceConnection -ListTitle $spec.SourceTitle) {
        if ($targetFieldMap.ContainsKey($field.InternalName)) {
            if ([string]$targetFieldMap[$field.InternalName].TypeAsString -ne [string]$field.TypeAsString) {
                throw "Field type mismatch on target store '$($spec.TargetTitle)': $($field.InternalName)"
            }
            continue
        }

        $fieldXml = Get-BgvFieldXmlForTarget -Field $field -LookupTargetIds $lookupTargetIds -TargetWebId $targetWeb.Id.Guid
        Add-PnPFieldFromXml -List $spec.TargetTitle -FieldXml $fieldXml -Connection $targetConnection | Out-Null
        $createdFields.Add($field.InternalName)
    }

    if ($spec.TargetTitle -eq "PEV Records") {
        Ensure-PevFolder -Connection $targetConnection -ParentFolder $targetList.RootFolder.ServerRelativeUrl -Name "Candidate Files"
    }

    $results += [ordered]@{
        SourceStoreTitle = $spec.SourceTitle
        StoreTitle = $spec.TargetTitle
        BaseTemplate = $targetList.BaseTemplate
        CreatedFields = @($createdFields)
        TargetStoreId = $targetList.Id.Guid
    }
}

Write-BgvStep "Ensure parallel PEV template folder and upload template"
$documentsList = Get-PevTargetDocumentsList -Connection $targetConnection
Ensure-PevFolder -Connection $targetConnection -ParentFolder $documentsList.RootFolder.ServerRelativeUrl -Name "PEV Templates"
$uploadedFile = Add-PnPFile -Path $TemplateSourcePath -Folder (Join-Path $documentsList.RootFolder.ServerRelativeUrl "PEV Templates").Replace("\", "/") -Connection $targetConnection
$templateServerRelativePath = [string]$uploadedFile.ServerRelativeUrl
if ([string]::IsNullOrWhiteSpace($templateServerRelativePath)) {
    $templateServerRelativePath = ((Join-Path $documentsList.RootFolder.ServerRelativeUrl "PEV Templates\AuthorizationLetter_Template.docx").Replace("\", "/"))
}

$graphMetadata = Get-BgvTemplateGraphMetadata -SiteUrl $TargetSiteUrl -ServerRelativeFilePath $templateServerRelativePath

$payload = [ordered]@{
    GeneratedAtUtc = (Get-Date).ToUniversalTime().ToString("o")
    SourceSiteUrl = $SourceSiteUrl
    TargetSiteUrl = $TargetSiteUrl
    Stores = $results
    Template = [ordered]@{
        SourcePath = $TemplateSourcePath
        TargetServerRelativePath = $templateServerRelativePath
        GraphMetadata = $graphMetadata
    }
}

Write-BgvJsonFile -Path $OutputPath -Value $payload
Write-BgvInfo "PEV target schema results written to $OutputPath"
