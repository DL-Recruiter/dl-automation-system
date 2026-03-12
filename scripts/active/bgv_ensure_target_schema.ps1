param(
    [string]$SourceSiteUrl = $env:BGV_SOURCE_SPO_SITE_URL,
    [string]$TargetSiteUrl = $env:BGV_TARGET_SPO_SITE_URL,
    [string]$ClientId = $env:PNP_CLIENT_ID,
    [string]$TenantId = $env:PNP_TENANT_ID,
    [string]$InventoryPath = "",
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
    throw "TargetSiteUrl must be provided via parameter or BGV_TARGET_SPO_SITE_URL."
}
if ([string]::IsNullOrWhiteSpace($TemplateSourcePath)) {
    $TemplateSourcePath = Join-Path $repoRoot "AuthorizationLetter_Template.docx"
}
if (-not (Test-Path $TemplateSourcePath)) {
    throw "Template source file not found: $TemplateSourcePath"
}
if ([string]::IsNullOrWhiteSpace($OutputPath)) {
    $OutputPath = Join-Path $repoRoot "out\migration\target_schema.json"
}

function Ensure-BgvFolder {
    param(
        [Parameter(Mandatory = $true)]
        $Connection,
        [Parameter(Mandatory = $true)]
        [string]$ParentFolder,
        [Parameter(Mandatory = $true)]
        [string]$Name
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

function Get-TargetDocumentsList {
    param([Parameter(Mandatory = $true)]$Connection)

    foreach ($title in @("Documents", "Shared Documents")) {
        $list = Get-BgvPnPListOrNull -Connection $Connection -Title $title
        if ($list) {
            return $list
        }
    }

    $fallback = Get-PnPList -Connection $Connection | Where-Object { $_.BaseTemplate -eq 101 -and $_.Title -ne "BGV Records" } | Select-Object -First 1
    if (-not $fallback) {
        throw "Unable to locate a default target documents library."
    }
    return $fallback
}

Write-BgvStep "Connect to source and target SharePoint sites"
$sourceConnection = Connect-BgvPnPSite -Url $SourceSiteUrl -ClientId $ClientId -TenantId $TenantId
$targetConnection = Connect-BgvPnPSite -Url $TargetSiteUrl -ClientId $ClientId -TenantId $TenantId
$targetWeb = Get-PnPWeb -Connection $targetConnection -Includes Id

Write-BgvStep "Ensure core lists and library exist"
$results = @()
foreach ($spec in Get-BgvStoreSpecifications) {
    $sourceList = Get-BgvPnPListOrNull -Connection $sourceConnection -Title $spec.Title
    if (-not $sourceList) {
        throw "Source store not found: $($spec.Title)"
    }

    $targetList = Get-BgvPnPListOrNull -Connection $targetConnection -Title $spec.Title
    if (-not $targetList) {
        $templateName = if ($spec.Template -eq 101) { "DocumentLibrary" } else { "GenericList" }
        New-PnPList -Title $spec.Title -Template $templateName -Connection $targetConnection | Out-Null
        $targetList = Get-BgvPnPListOrNull -Connection $targetConnection -Title $spec.Title
    }

    if ([int]$targetList.BaseTemplate -ne [int]$sourceList.BaseTemplate) {
        throw "Target store '$($spec.Title)' exists with base template $($targetList.BaseTemplate), expected $($sourceList.BaseTemplate)."
    }

    $targetExistingFields = @(Get-PnPField -List $spec.Title -Connection $targetConnection)
    $targetFieldMap = @{}
    foreach ($field in $targetExistingFields) {
        $targetFieldMap[$field.InternalName] = $field
    }

    $lookupTargetIds = @{}
    if ($spec.Title -eq "BGV_Requests" -or $spec.Title -eq "BGV_FormData") {
        $candidateTargetList = Get-BgvPnPListOrNull -Connection $targetConnection -Title "BGV_Candidates"
        if ($candidateTargetList) {
            $lookupTargetIds["CandidateItemID"] = $candidateTargetList.Id.Guid
        }
    }

    $createdFields = New-Object System.Collections.Generic.List[string]
    foreach ($field in Get-BgvProvisionableFields -Connection $sourceConnection -ListTitle $spec.Title) {
        if ($targetFieldMap.ContainsKey($field.InternalName)) {
            if ([string]$targetFieldMap[$field.InternalName].TypeAsString -ne [string]$field.TypeAsString) {
                throw "Field type mismatch on target store '$($spec.Title)': $($field.InternalName)"
            }
            continue
        }

        $fieldXml = Get-BgvFieldXmlForTarget -Field $field -LookupTargetIds $lookupTargetIds -TargetWebId $targetWeb.Id.Guid
        Add-PnPFieldFromXml -List $spec.Title -FieldXml $fieldXml -Connection $targetConnection | Out-Null
        $createdFields.Add($field.InternalName)
    }

    if ($spec.Title -eq "BGV Records") {
        Ensure-BgvFolder -Connection $targetConnection -ParentFolder $targetList.RootFolder.ServerRelativeUrl -Name "Candidate Files"
    }

    $results += [ordered]@{
        StoreTitle     = $spec.Title
        BaseTemplate   = $targetList.BaseTemplate
        CreatedFields  = @($createdFields)
        TargetStoreId  = $targetList.Id.Guid
    }
}

Write-BgvStep "Ensure target template folder and upload template"
$documentsList = Get-TargetDocumentsList -Connection $targetConnection
Ensure-BgvFolder -Connection $targetConnection -ParentFolder $documentsList.RootFolder.ServerRelativeUrl -Name "BGV Templates"
$uploadedFile = Add-PnPFile -Path $TemplateSourcePath -Folder (Join-Path $documentsList.RootFolder.ServerRelativeUrl "BGV Templates").Replace("\", "/") -Connection $targetConnection
$templateServerRelativePath = [string]$uploadedFile.ServerRelativeUrl
if ([string]::IsNullOrWhiteSpace($templateServerRelativePath)) {
    $templateServerRelativePath = ((Join-Path $documentsList.RootFolder.ServerRelativeUrl "BGV Templates\AuthorizationLetter_Template.docx").Replace("\", "/"))
}

$graphMetadata = Get-BgvTemplateGraphMetadata -SiteUrl $TargetSiteUrl -ServerRelativeFilePath $templateServerRelativePath

$payload = [ordered]@{
    GeneratedAtUtc = (Get-Date).ToUniversalTime().ToString("o")
    SourceSiteUrl  = $SourceSiteUrl
    TargetSiteUrl  = $TargetSiteUrl
    Stores         = $results
    Template       = [ordered]@{
        SourcePath          = $TemplateSourcePath
        TargetServerRelativePath = $templateServerRelativePath
        GraphMetadata       = $graphMetadata
    }
}

Write-BgvJsonFile -Path $OutputPath -Value $payload
Write-BgvInfo "Target schema results written to $OutputPath"
