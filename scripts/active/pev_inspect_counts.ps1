param(
    [string]$SiteUrl = "https://dlresourcespl88.sharepoint.com/sites/DLRRecruitmentOps570",
    [string]$ClientId = $env:PNP_CLIENT_ID,
    [string]$TenantId = $env:PNP_TENANT_ID
)

$ErrorActionPreference = "Stop"
Import-Module PnP.PowerShell -ErrorAction Stop
$conn = Connect-PnPOnline -Url $SiteUrl -Interactive -ClientId $ClientId -Tenant $TenantId -ReturnConnection

@(
    "BGV_Candidates",
    "PEV_Candidates",
    "BGV_Requests",
    "PEV_Requests",
    "BGV_FormData",
    "PEV_FormData",
    "BGV Records",
    "PEV Records"
) | ForEach-Object {
    $list = Get-PnPList -Identity $_ -Connection $conn -Includes ItemCount, RootFolder
    [pscustomobject]@{
        Title = $list.Title
        ItemCount = $list.ItemCount
        RootFolder = $list.RootFolder.ServerRelativeUrl
    }
} | ConvertTo-Json -Depth 3
