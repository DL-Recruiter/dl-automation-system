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

$approvedReferenceContactListTitle = "Approved HR Reference Contacts"

$requestExtensionFields = @(
    [ordered]@{
        InternalName = "ReferenceGuardrailStatus"
        FieldXml = '<Field Type="Text" DisplayName="Reference Guardrail Status" Name="ReferenceGuardrailStatus" StaticName="ReferenceGuardrailStatus" Group="PEV Custom Columns" />'
    },
    [ordered]@{
        InternalName = "ReferenceGuardrailCheckedAt"
        FieldXml = '<Field Type="DateTime" DisplayName="Reference Guardrail Checked At" Name="ReferenceGuardrailCheckedAt" StaticName="ReferenceGuardrailCheckedAt" Format="DateTime" Group="PEV Custom Columns" />'
    },
    [ordered]@{
        InternalName = "ReferenceGuardrailNotifiedAt"
        FieldXml = '<Field Type="DateTime" DisplayName="Reference Guardrail Notified At" Name="ReferenceGuardrailNotifiedAt" StaticName="ReferenceGuardrailNotifiedAt" Format="DateTime" Group="PEV Custom Columns" />'
    },
    [ordered]@{
        InternalName = "ReferenceGuardrailLastEmailNormalized"
        FieldXml = '<Field Type="Text" DisplayName="Reference Guardrail Last Email Normalized" Name="ReferenceGuardrailLastEmailNormalized" StaticName="ReferenceGuardrailLastEmailNormalized" Group="PEV Custom Columns" />'
    },
    [ordered]@{
        InternalName = "ReferenceGuardrailNotes"
        FieldXml = '<Field Type="Note" DisplayName="Reference Guardrail Notes" Name="ReferenceGuardrailNotes" StaticName="ReferenceGuardrailNotes" NumLines="6" RichText="FALSE" Group="PEV Custom Columns" />'
    }
)

$approvedReferenceContactFields = @(
    [ordered]@{
        InternalName = "CompanyName"
        FieldXml = '<Field Type="Text" DisplayName="Company Name" Name="CompanyName" StaticName="CompanyName" Group="PEV Custom Columns" />'
    },
    [ordered]@{
        InternalName = "CompanyAddress"
        FieldXml = '<Field Type="Note" DisplayName="Company Address" Name="CompanyAddress" StaticName="CompanyAddress" NumLines="6" RichText="FALSE" Group="PEV Custom Columns" />'
    },
    [ordered]@{
        InternalName = "TelContact"
        FieldXml = '<Field Type="Text" DisplayName="Tel Contact" Name="TelContact" StaticName="TelContact" Group="PEV Custom Columns" />'
    },
    [ordered]@{
        InternalName = "HRReferenceEmail"
        FieldXml = '<Field Type="Text" DisplayName="HR Reference Email" Name="HRReferenceEmail" StaticName="HRReferenceEmail" Group="PEV Custom Columns" />'
    },
    [ordered]@{
        InternalName = "HRReferenceEmailNormalized"
        FieldXml = '<Field Type="Text" DisplayName="HR Reference Email Normalized" Name="HRReferenceEmailNormalized" StaticName="HRReferenceEmailNormalized" Indexed="TRUE" Group="PEV Custom Columns" />'
    },
    [ordered]@{
        InternalName = "CompanyUEN"
        FieldXml = '<Field Type="Text" DisplayName="Company UEN" Name="CompanyUEN" StaticName="CompanyUEN" Group="PEV Custom Columns" />'
    },
    [ordered]@{
        InternalName = "CompanyUENNormalized"
        FieldXml = '<Field Type="Text" DisplayName="CompanyUENNormalized" Name="CompanyUENNormalized" StaticName="CompanyUENNormalized" Indexed="TRUE" Group="PEV Custom Columns" />'
    },
    [ordered]@{
        InternalName = "ContactType"
        FieldXml = '<Field Type="Choice" DisplayName="Contact Type" Name="ContactType" StaticName="ContactType" FillInChoice="FALSE" Group="PEV Custom Columns"><CHOICES><CHOICE>General Company HR</CHOICE><CHOICE>Personal HR Contact</CHOICE></CHOICES></Field>'
    },
    [ordered]@{
        InternalName = "ContactPersonName"
        FieldXml = '<Field Type="Text" DisplayName="Contact Person Name" Name="ContactPersonName" StaticName="ContactPersonName" Group="PEV Custom Columns" />'
    },
    [ordered]@{
        InternalName = "Notes"
        FieldXml = '<Field Type="Note" DisplayName="Notes" Name="Notes" StaticName="Notes" NumLines="6" RichText="FALSE" Group="PEV Custom Columns" />'
    },
    [ordered]@{
        InternalName = "IsActive"
        FieldXml = '<Field Type="Boolean" DisplayName="Is Active" Name="IsActive" StaticName="IsActive" Group="PEV Custom Columns"><Default>1</Default></Field>'
    },
    [ordered]@{
        InternalName = "IsVerified"
        FieldXml = '<Field Type="Boolean" DisplayName="Is Verified" Name="IsVerified" StaticName="IsVerified" Group="PEV Custom Columns"><Default>1</Default></Field>'
    },
    [ordered]@{
        InternalName = "SourceSheet"
        FieldXml = '<Field Type="Text" DisplayName="Source Sheet" Name="SourceSheet" StaticName="SourceSheet" Group="PEV Custom Columns" />'
    },
    [ordered]@{
        InternalName = "VerifiedOn"
        FieldXml = '<Field Type="DateTime" DisplayName="Verified On" Name="VerifiedOn" StaticName="VerifiedOn" Format="DateTime" Group="PEV Custom Columns" />'
    },
    [ordered]@{
        InternalName = "VerifiedByPerson"
        FieldXml = '<Field Type="User" DisplayName="Verified By Person" Name="VerifiedByPerson" StaticName="VerifiedByPerson" UserSelectionMode="PeopleOnly" Group="PEV Custom Columns" />'
    }
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

function Ensure-PevList {
    param(
        [Parameter(Mandatory = $true)]$Connection,
        [Parameter(Mandatory = $true)][string]$Title,
        [Parameter(Mandatory = $true)][string]$TemplateName
    )

    $list = Get-BgvPnPListOrNull -Connection $Connection -Title $Title
    if (-not $list) {
        New-PnPList -Title $Title -Template $TemplateName -Connection $Connection | Out-Null
        $list = Get-BgvPnPListOrNull -Connection $Connection -Title $Title
    }

    return $list
}

function Ensure-PevCustomFields {
    param(
        [Parameter(Mandatory = $true)]$Connection,
        [Parameter(Mandatory = $true)][string]$ListTitle,
        [Parameter(Mandatory = $true)][object[]]$FieldSpecs
    )

    $existingFields = @(Get-PnPField -List $ListTitle -Connection $Connection)
    $existingMap = @{}
    foreach ($field in $existingFields) {
        $existingMap[$field.InternalName] = $field
    }

    $created = New-Object System.Collections.Generic.List[string]
    foreach ($fieldSpec in $FieldSpecs) {
        if ($existingMap.ContainsKey($fieldSpec.InternalName)) {
            continue
        }

        Add-PnPFieldFromXml -List $ListTitle -FieldXml $fieldSpec.FieldXml -Connection $Connection | Out-Null
        $created.Add([string]$fieldSpec.InternalName)
    }

    return @($created)
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

Write-BgvStep "Ensure PEV request guardrail fields and approved-contact list exist"
$requestGuardrailCreatedFields = Ensure-PevCustomFields -Connection $targetConnection -ListTitle "PEV_Requests" -FieldSpecs $requestExtensionFields
$approvedReferenceContactList = Ensure-PevList -Connection $targetConnection -Title $approvedReferenceContactListTitle -TemplateName "GenericList"
$approvedReferenceContactCreatedFields = Ensure-PevCustomFields -Connection $targetConnection -ListTitle $approvedReferenceContactListTitle -FieldSpecs $approvedReferenceContactFields

$results += [ordered]@{
    SourceStoreTitle = ""
    StoreTitle = "PEV_Requests"
    BaseTemplate = 100
    CreatedFields = @($requestGuardrailCreatedFields)
    TargetStoreId = (Get-BgvPnPListOrNull -Connection $targetConnection -Title "PEV_Requests").Id.Guid
    Notes = "Guardrail extension fields"
}

$results += [ordered]@{
    SourceStoreTitle = ""
    StoreTitle = $approvedReferenceContactListTitle
    BaseTemplate = $approvedReferenceContactList.BaseTemplate
    CreatedFields = @($approvedReferenceContactCreatedFields)
    TargetStoreId = $approvedReferenceContactList.Id.Guid
    Notes = "Custom approved HR/reference contact list"
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
