[CmdletBinding()]
param(
    [string]$SiteUrl = "https://dlresourcespl88.sharepoint.com/sites/DLRRecruitmentOps570",
    [string]$LibraryFolder = "BGV Records",
    [string]$OutputPath = ".\out\dashboard\BGV Dashboard.xlsx",
    [switch]$UploadToSharePoint
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Get-PropertyValue {
    param(
        [Parameter(Mandatory)]
        $Item,
        [Parameter(Mandatory)]
        [string]$PropertyName
    )

    $property = $Item.PSObject.Properties[$PropertyName]
    if ($null -eq $property) {
        return $null
    }

    $value = $property.Value
    if ($value -is [System.Collections.IDictionary] -and $value.Contains("Url")) {
        return $value["Url"]
    }

    return $value
}

function Get-ListSnapshot {
    param(
        [Parameter(Mandatory)]
        [string]$WebUrl,
        [Parameter(Mandatory)]
        [string]$ListTitle
    )

    $rawOutput = & m365 spo listitem list --webUrl $WebUrl --listTitle $ListTitle --output json
    if (-not $rawOutput) {
        throw "No data returned for SharePoint list '$ListTitle'."
    }

    $rawText = [string]::Join([Environment]::NewLine, $rawOutput)
    $jsonStart = $rawText.IndexOf('[')
    if ($jsonStart -lt 0) {
        $jsonStart = $rawText.IndexOf('{')
    }
    if ($jsonStart -lt 0) {
        throw "Could not find JSON payload in m365 output for list '$ListTitle'."
    }

    $jsonText = $rawText.Substring($jsonStart)
    return ($jsonText | ConvertFrom-Json)
}

function Convert-ToSnapshotRows {
    param(
        [Parameter(Mandatory)]
        [object[]]$Items,
        [Parameter(Mandatory)]
        [ValidateSet("Candidates", "Requests", "FormData")]
        [string]$Type
    )

    switch ($Type) {
        "Candidates" {
            return @(
                foreach ($item in $Items) {
                    [pscustomobject]@{
                        CandidateID                = Get-PropertyValue $item "CandidateID"
                        FullName                   = Get-PropertyValue $item "FullName"
                        CandidateEmail             = Get-PropertyValue $item "CandidateEmail"
                        CandidateStatus            = Get-PropertyValue $item "Status"
                        AuthorisationSigned        = Get-PropertyValue $item "AuthorisationSigned"
                        AuthorizationLinkCreatedAt = Get-PropertyValue $item "AuthorizationLinkCreatedAt"
                        ConsentTimestamp           = Get-PropertyValue $item "ConsentTimestamp"
                        LastAuthReminderAt         = Get-PropertyValue $item "LastAuthReminderAt"
                        CandidateModified          = Get-PropertyValue $item "Modified"
                    }
                }
            )
        }
        "Requests" {
            return @(
                foreach ($item in $Items) {
                    [pscustomobject]@{
                        CandidateID         = Get-PropertyValue $item "CandidateID"
                        RequestID           = Get-PropertyValue $item "RequestID"
                        EmployerName        = Get-PropertyValue $item "EmployerName"
                        EmployerHREmail     = Get-PropertyValue $item "EmployerHR_Email"
                        VerificationStatus  = Get-PropertyValue $item "VerificationStatus"
                        SendAfterDate       = Get-PropertyValue $item "SendAfterDate"
                        HRRequestSentAt     = Get-PropertyValue $item "HRRequestSentAt"
                        ResponseReceivedAt  = Get-PropertyValue $item "ResponseReceivedAt"
                        Reminder1At         = Get-PropertyValue $item "Reminder1At"
                        Reminder2At         = Get-PropertyValue $item "Reminder2At"
                        Reminder3At         = Get-PropertyValue $item "Reminder3At"
                        EscalatedAt         = Get-PropertyValue $item "EscalatedAt"
                        Severity            = Get-PropertyValue $item "Severity"
                        Outcome             = Get-PropertyValue $item "Outcome"
                        BGVChecks           = (Get-PropertyValue $item "BGV_x0020_Checks")
                        RequestModified     = Get-PropertyValue $item "Modified"
                    }
                }
            )
        }
        "FormData" {
            return @(
                foreach ($item in $Items) {
                    [pscustomobject]@{
                        CandidateID      = Get-PropertyValue $item "CandidateID"
                        RequestID        = Get-PropertyValue $item "RequestID"
                        EmployerSlot     = Get-PropertyValue $item "EmployerSlot"
                        F1HRContactName  = Get-PropertyValue $item "F1_HRContactName"
                        F1HREmail        = Get-PropertyValue $item "F1_HREmail"
                        F1HRMobile       = Get-PropertyValue $item "F1_HRMobile"
                        F1EmployerName   = Get-PropertyValue $item "F1_EmployerName"
                        FormDataModified = Get-PropertyValue $item "Modified"
                    }
                }
            )
        }
    }
}

function New-BgvMasterQueryFormula {
    @"
let
    Today = Date.From(DateTime.LocalNow()),
    ToText = (value as any) as nullable text =>
        if value = null then
            null
        else
            try Text.From(value) otherwise null,
    ToLogical = (value as any) as nullable logical =>
        if value = null then
            null
        else if Value.Is(value, type logical) then
            value
        else
            let
                textValue = Text.Upper(Text.Trim(ToText(value)))
            in
                if List.Contains({"TRUE", "YES", "1"}, textValue) then true
                else if List.Contains({"FALSE", "NO", "0"}, textValue) then false
                else null,
    ToDateTime = (value as any) as nullable datetime =>
        if value = null or value = "" then
            null
        else
            try DateTime.From(value) otherwise null,
    ToDate = (value as any) as nullable date =>
        let
            dt = ToDateTime(value)
        in
            if dt = null then
                null
            else
                Date.From(dt),
    DaysOld = (value as any) as nullable number =>
        let
            asDate = ToDate(value)
        in
            if asDate = null then
                null
            else
                Duration.Days(Today - asDate),

    CandidatesRaw = Excel.CurrentWorkbook(){[Name = "tblCandidatesRaw"]}[Content],
    RequestsRaw = Excel.CurrentWorkbook(){[Name = "tblRequestsRaw"]}[Content],
    FormDataRaw = Excel.CurrentWorkbook(){[Name = "tblFormDataRaw"]}[Content],

    Candidates = Table.TransformColumns(
        CandidatesRaw,
        {
            {"CandidateID", each ToText(_), type text},
            {"FullName", each ToText(_), type text},
            {"CandidateEmail", each ToText(_), type text},
            {"CandidateStatus", each ToText(_), type text},
            {"AuthorisationSigned", each ToLogical(_), type logical},
            {"AuthorizationLinkCreatedAt", each ToDateTime(_), type datetime},
            {"ConsentTimestamp", each ToDateTime(_), type datetime},
            {"LastAuthReminderAt", each ToDateTime(_), type datetime},
            {"CandidateModified", each ToDateTime(_), type datetime}
        }
    ),

    Requests = Table.TransformColumns(
        RequestsRaw,
        {
            {"CandidateID", each ToText(_), type text},
            {"RequestID", each ToText(_), type text},
            {"EmployerName", each ToText(_), type text},
            {"EmployerHREmail", each ToText(_), type text},
            {"VerificationStatus", each ToText(_), type text},
            {"SendAfterDate", each ToDate(_), type date},
            {"HRRequestSentAt", each ToDateTime(_), type datetime},
            {"ResponseReceivedAt", each ToDateTime(_), type datetime},
            {"Reminder1At", each ToDateTime(_), type datetime},
            {"Reminder2At", each ToDateTime(_), type datetime},
            {"Reminder3At", each ToDateTime(_), type datetime},
            {"EscalatedAt", each ToDateTime(_), type datetime},
            {"Severity", each ToText(_), type text},
            {"Outcome", each ToText(_), type text},
            {"BGVChecks", each ToText(_), type text},
            {"RequestModified", each ToDateTime(_), type datetime}
        }
    ),

    FormData = Table.TransformColumns(
        FormDataRaw,
        {
            {"CandidateID", each ToText(_), type text},
            {"RequestID", each ToText(_), type text},
            {"EmployerSlot", each ToText(_), type text},
            {"F1HRContactName", each ToText(_), type text},
            {"F1HREmail", each ToText(_), type text},
            {"F1HRMobile", each ToText(_), type text},
            {"F1EmployerName", each ToText(_), type text},
            {"FormDataModified", each ToDateTime(_), type datetime}
        }
    ),

    JoinCandidates = Table.NestedJoin(Requests, {"CandidateID"}, Candidates, {"CandidateID"}, "Candidate", JoinKind.LeftOuter),
    ExpandCandidates = Table.ExpandTableColumn(
        JoinCandidates,
        "Candidate",
        {
            "FullName",
            "CandidateEmail",
            "CandidateStatus",
            "AuthorisationSigned",
            "AuthorizationLinkCreatedAt",
            "ConsentTimestamp",
            "LastAuthReminderAt",
            "CandidateModified"
        },
        {
            "Candidate Name",
            "Candidate Email",
            "Candidate Status",
            "Authorisation Signed",
            "Authorization Link Created At",
            "Authorization Signed At",
            "Last Candidate Reminder At",
            "Candidate Modified At"
        }
    ),

    JoinFormData = Table.NestedJoin(ExpandCandidates, {"RequestID"}, FormData, {"RequestID"}, "FormData", JoinKind.LeftOuter),
    ExpandFormData = Table.ExpandTableColumn(
        JoinFormData,
        "FormData",
        {"EmployerSlot", "F1HRContactName", "F1HREmail", "F1HRMobile", "F1EmployerName", "FormDataModified"},
        {"Employer Slot", "HR Name", "HR Email (FormData)", "HR Mobile Number", "Employer Name (FormData)", "FormData Modified At"}
    ),

    AddEmployerName = Table.AddColumn(
        ExpandFormData,
        "Company Name",
        each if [#"Employer Name (FormData)"] <> null and Text.Trim([#"Employer Name (FormData)"]) <> "" then [#"Employer Name (FormData)"] else [EmployerName],
        type text
    ),

    AddHREmail = Table.AddColumn(
        AddEmployerName,
        "HR Email",
        each if [#"HR Email (FormData)"] <> null and Text.Trim([#"HR Email (FormData)"]) <> "" then [#"HR Email (FormData)"] else [EmployerHREmail],
        type text
    ),

    AddCompleted = Table.AddColumn(
        AddHREmail,
        "Completed Case",
        each [VerificationStatus] = "Responded",
        type logical
    ),

    AddStatus = Table.AddColumn(
        AddCompleted,
        "Status",
        each
            let
                authSigned = [#"Authorisation Signed"] = true,
                status = [VerificationStatus],
                sendAfter = [SendAfterDate],
                sendFuture = sendAfter <> null and sendAfter > Today,
                authLinkCreatedAt = [#"Authorization Link Created At"]
            in
                if authLinkCreatedAt = null then
                    "Candidate Form Received"
                else if not authSigned then
                    "Authorisation Form Sent"
                else if status = "Responded" then
                    "Employer Form Received"
                else if status = "Reminder 3 Sent" then
                    "Employer Reminder 3 Sent"
                else if status = "Reminder 2 Sent" then
                    "Employer Reminder 2 Sent"
                else if status = "Reminder 1 Sent" then
                    "Employer Reminder 1 Sent"
                else if status = "Email Sent" then
                    "Email Sent to Employer"
                else if status = null or Text.Trim(status) = "" or status = "Not Sent" then
                    if sendFuture then
                        "Authorisation Received - Employer Email Queued"
                    else
                        "Authorisation Form Received"
                else
                    "In Progress",
        type text
    ),

    AddCandidateReminder = Table.AddColumn(
        AddStatus,
        "Candidate Reminder",
        each
            if [#"Last Candidate Reminder At"] = null then
                "Not sent"
            else
                "1: " & DateTime.ToText([#"Last Candidate Reminder At"], "yyyy-MM-dd HH:mm"),
        type text
    ),

    AddEmployerReminder = Table.AddColumn(
        AddCandidateReminder,
        "Employer Reminder",
        each
            if [Reminder3At] <> null then
                "3: " & DateTime.ToText([Reminder3At], "yyyy-MM-dd HH:mm")
            else if [Reminder2At] <> null then
                "2: " & DateTime.ToText([Reminder2At], "yyyy-MM-dd HH:mm")
            else if [Reminder1At] <> null then
                "1: " & DateTime.ToText([Reminder1At], "yyyy-MM-dd HH:mm")
            else
                "Not sent",
        type text
    ),

    AddRecruiterId = Table.AddColumn(
        AddEmployerReminder,
        "RecruiterID",
        each "Not tracked in current lists",
        type text
    ),

    AddOverdue = Table.AddColumn(
        AddRecruiterId,
        "Overdue",
        each
            let
                completed = [Completed Case],
                authSigned = [#"Authorisation Signed"] = true,
                authAgeDays = DaysOld([#"Authorization Link Created At"]),
                sendAfter = [SendAfterDate],
                status = [VerificationStatus]
            in
                if completed then
                    "No"
                else if not authSigned and authAgeDays <> null and authAgeDays >= 5 then
                    "Yes"
                else if status = "Not Sent" and sendAfter <> null and sendAfter < Today then
                    "Yes"
                else if List.Contains({"Reminder 2 Sent", "Reminder 3 Sent"}, status) then
                    "Yes"
                else if [EscalatedAt] <> null then
                    "Yes"
                else
                    "No",
        type text
    ),

    AddCompletedStatus = Table.AddColumn(
        AddOverdue,
        "Completed Status",
        each
            if [Completed Case] then
                "Yes"
            else
                "No",
        type text
    ),

    AddLastActivity = Table.AddColumn(
        AddCompletedStatus,
        "Last Activity At",
        each
            let
                values = List.RemoveNulls({[ResponseReceivedAt], [Reminder3At], [Reminder2At], [Reminder1At], [HRRequestSentAt], [#"Authorization Signed At"], [#"Last Candidate Reminder At"], [RequestModified], [#"Candidate Modified At"], [#"FormData Modified At"]})
            in
                if List.IsEmpty(values) then null else List.Max(values),
        type datetime
    ),

    RenameCore = Table.RenameColumns(
        AddLastActivity,
        {
            {"VerificationStatus", "Verification Status"},
            {"SendAfterDate", "Send After Date"},
            {"HRRequestSentAt", "Employer Request Sent At"},
            {"ResponseReceivedAt", "Employer Response Received At"},
            {"Reminder1At", "Reminder 1 At"},
            {"Reminder2At", "Reminder 2 At"},
            {"Reminder3At", "Reminder 3 At"},
            {"EscalatedAt", "Escalated At"},
            {"BGVChecks", "BGV Checks"}
        }
    ),

    Final = Table.ReorderColumns(
        RenameCore,
        {
            "Candidate Name",
            "CandidateID",
            "RecruiterID",
            "RequestID",
            "Company Name",
            "HR Name",
            "HR Email",
            "HR Mobile Number",
            "Status",
            "Candidate Reminder",
            "Employer Reminder",
            "Overdue",
            "Completed Status",
            "Employer Response Received At",
            "Last Activity At",
            "Severity",
            "Outcome"
        },
        MissingField.Ignore
    )
in
    Final
"@
}

function Convert-ToNullableDateTime {
    param($Value)

    if ($null -eq $Value -or $Value -eq "") {
        return $null
    }

    try {
        return [datetime]::Parse($Value)
    }
    catch {
        return $null
    }
}

function Convert-ToNullableDate {
    param($Value)

    $asDateTime = Convert-ToNullableDateTime -Value $Value
    if ($null -eq $asDateTime) {
        return $null
    }

    return $asDateTime.Date
}

function Convert-ToBoolean {
    param($Value)

    if ($Value -is [bool]) {
        return $Value
    }

    $text = [string]$Value
    if ([string]::IsNullOrWhiteSpace($text)) {
        return $false
    }

    return @("true", "yes", "1") -contains $text.Trim().ToLowerInvariant()
}

function Get-LatestDate {
    param([object[]]$Values)

    $dates = @(
        foreach ($value in $Values) {
            $parsed = Convert-ToNullableDateTime -Value $value
            if ($null -ne $parsed) {
                $parsed
            }
        }
    )

    if ($dates.Count -eq 0) {
        return $null
    }

    return ($dates | Sort-Object -Descending | Select-Object -First 1)
}

function Build-MasterRows {
    param(
        [Parameter(Mandatory)]
        [object[]]$Candidates,
        [Parameter(Mandatory)]
        [object[]]$Requests,
        [Parameter(Mandatory)]
        [object[]]$FormData
    )

    $today = (Get-Date).Date
    $candidateById = @{}
    foreach ($candidate in $Candidates) {
        if (-not [string]::IsNullOrWhiteSpace($candidate.CandidateID)) {
            $candidateById[$candidate.CandidateID] = $candidate
        }
    }

    $formDataByRequest = @{}
    foreach ($row in $FormData) {
        if (-not [string]::IsNullOrWhiteSpace($row.RequestID)) {
            $formDataByRequest[$row.RequestID] = $row
        }
    }

    $masterRows = foreach ($request in $Requests) {
        $candidate = $null
        if ($candidateById.ContainsKey($request.CandidateID)) {
            $candidate = $candidateById[$request.CandidateID]
        }

        $form = $null
        if ($formDataByRequest.ContainsKey($request.RequestID)) {
            $form = $formDataByRequest[$request.RequestID]
        }

        $authSigned = if ($null -ne $candidate) { Convert-ToBoolean $candidate.AuthorisationSigned } else { $false }
        $verificationStatus = [string]$request.VerificationStatus
        $sendAfterDate = Convert-ToNullableDate -Value $request.SendAfterDate
        $authLinkCreatedAt = if ($null -ne $candidate) { Convert-ToNullableDateTime -Value $candidate.AuthorizationLinkCreatedAt } else { $null }
        $authSignedAt = if ($null -ne $candidate) { Convert-ToNullableDateTime -Value $candidate.ConsentTimestamp } else { $null }
        $lastCandidateReminderAt = if ($null -ne $candidate) { Convert-ToNullableDateTime -Value $candidate.LastAuthReminderAt } else { $null }
        $requestSentAt = Convert-ToNullableDateTime -Value $request.HRRequestSentAt
        $responseReceivedAt = Convert-ToNullableDateTime -Value $request.ResponseReceivedAt
        $reminder1At = Convert-ToNullableDateTime -Value $request.Reminder1At
        $reminder2At = Convert-ToNullableDateTime -Value $request.Reminder2At
        $reminder3At = Convert-ToNullableDateTime -Value $request.Reminder3At
        $escalatedAt = Convert-ToNullableDateTime -Value $request.EscalatedAt
        $candidateModifiedAt = if ($null -ne $candidate) { Convert-ToNullableDateTime -Value $candidate.CandidateModified } else { $null }
        $requestModifiedAt = Convert-ToNullableDateTime -Value $request.RequestModified
        $formDataModifiedAt = if ($null -ne $form) { Convert-ToNullableDateTime -Value $form.FormDataModified } else { $null }
        $severity = [string]$request.Severity
        $completedCase = $verificationStatus -eq "Responded"
        $sendDateFuture = $null -ne $sendAfterDate -and $sendAfterDate -gt $today
        $authAgeDays = if ($null -ne $authLinkCreatedAt) { [int](New-TimeSpan -Start $authLinkCreatedAt.Date -End $today).TotalDays } else { $null }

        if ($null -eq $authLinkCreatedAt) {
            $currentStage = "Candidate Form Received"
        }
        elseif (-not $authSigned) {
            $currentStage = "Authorisation Form Sent"
        }
        elseif ($verificationStatus -eq "Responded") {
            $currentStage = "Employer Form Received"
        }
        elseif ($verificationStatus -eq "Reminder 3 Sent") {
            $currentStage = "Employer Reminder 3 Sent"
        }
        elseif ($verificationStatus -eq "Reminder 2 Sent") {
            $currentStage = "Employer Reminder 2 Sent"
        }
        elseif ($verificationStatus -eq "Reminder 1 Sent") {
            $currentStage = "Employer Reminder 1 Sent"
        }
        elseif ($verificationStatus -eq "Email Sent") {
            $currentStage = "Email Sent to Employer"
        }
        elseif ([string]::IsNullOrWhiteSpace($verificationStatus) -or $verificationStatus -eq "Not Sent") {
            $currentStage = if ($sendDateFuture) { "Authorisation Received - Employer Email Queued" } else { "Authorisation Form Received" }
        }
        else {
            $currentStage = $verificationStatus
        }

        $candidateReminder = if ($null -eq $lastCandidateReminderAt) {
            "Not sent"
        }
        else {
            "1: {0}" -f $lastCandidateReminderAt.ToString("yyyy-MM-dd HH:mm")
        }

        $employerReminder = if ($null -ne $reminder3At) {
            "3: {0}" -f $reminder3At.ToString("yyyy-MM-dd HH:mm")
        }
        elseif ($null -ne $reminder2At) {
            "2: {0}" -f $reminder2At.ToString("yyyy-MM-dd HH:mm")
        }
        elseif ($null -ne $reminder1At) {
            "1: {0}" -f $reminder1At.ToString("yyyy-MM-dd HH:mm")
        }
        else {
            "Not sent"
        }

        $overdueCase = "No"
        if (-not $completedCase) {
            if (-not $authSigned -and $null -ne $authAgeDays -and $authAgeDays -ge 5) {
                $overdueCase = "Yes"
            }
            elseif ($verificationStatus -eq "Not Sent" -and $null -ne $sendAfterDate -and $sendAfterDate -lt $today) {
                $overdueCase = "Yes"
            }
            elseif (@("Reminder 2 Sent", "Reminder 3 Sent") -contains $verificationStatus) {
                $overdueCase = "Yes"
            }
            elseif ($null -ne $escalatedAt) {
                $overdueCase = "Yes"
            }
        }

        $completedStatus = if ($completedCase) {
            "Yes"
        }
        else {
            "No"
        }

        $lastActivityAt = Get-LatestDate @(
            $responseReceivedAt,
            $reminder3At,
            $reminder2At,
            $reminder1At,
            $requestSentAt,
            $authSignedAt,
            $lastCandidateReminderAt,
            $requestModifiedAt,
            $candidateModifiedAt,
            $formDataModifiedAt
        )

        [pscustomobject]@{
            "Candidate Name"               = if ($null -ne $candidate) { $candidate.FullName } else { $null }
            CandidateID                     = $request.CandidateID
            RecruiterID                     = "Not tracked in current lists"
            RequestID                       = $request.RequestID
            "Company Name"                  = if ($null -ne $form -and -not [string]::IsNullOrWhiteSpace($form.F1EmployerName)) { $form.F1EmployerName } else { $request.EmployerName }
            "HR Name"                       = if ($null -ne $form) { $form.F1HRContactName } else { $null }
            "HR Email"                      = if ($null -ne $form -and -not [string]::IsNullOrWhiteSpace($form.F1HREmail)) { $form.F1HREmail } else { $request.EmployerHREmail }
            "HR Mobile Number"              = if ($null -ne $form) { $form.F1HRMobile } else { $null }
            Status                          = $currentStage
            "Candidate Reminder"            = $candidateReminder
            "Employer Reminder"             = $employerReminder
            Overdue                         = $overdueCase
            "Completed Status"              = $completedStatus
            "Employer Response Received At" = $responseReceivedAt
            "Last Activity At"              = $lastActivityAt
            Severity                        = $severity
            Outcome                         = $request.Outcome
        }
    }

    return @($masterRows | Sort-Object @{ Expression = "Overdue"; Descending = $true }, @{ Expression = "Completed Status"; Descending = $false }, @{ Expression = "Last Activity At"; Descending = $true })
}

function Release-ComObject {
    param($ComObject)

    if ($null -ne $ComObject) {
        try {
            [void][System.Runtime.InteropServices.Marshal]::ReleaseComObject($ComObject)
        }
        catch {
        }
    }
}

function Write-SnapshotTable {
    param(
        [Parameter(Mandatory)]
        $Worksheet,
        [Parameter(Mandatory)]
        [string]$TableName,
        [Parameter(Mandatory)]
        [object[]]$Rows
    )

    $headers = @()
    if ($Rows.Count -gt 0) {
        $headers = $Rows[0].PSObject.Properties.Name
    }
    else {
        throw "Cannot create snapshot table '$TableName' with zero rows."
    }

    for ($col = 0; $col -lt $headers.Count; $col++) {
        $Worksheet.Cells.Item(1, $col + 1).Value2 = $headers[$col]
    }

    for ($rowIndex = 0; $rowIndex -lt $Rows.Count; $rowIndex++) {
        $row = $Rows[$rowIndex]
        for ($col = 0; $col -lt $headers.Count; $col++) {
            $value = $row.($headers[$col])
            if ($null -eq $value) {
                $Worksheet.Cells.Item($rowIndex + 2, $col + 1).Value2 = ""
            }
            elseif ($value -is [bool]) {
                $Worksheet.Cells.Item($rowIndex + 2, $col + 1).Value2 = if ($value) { "TRUE" } else { "FALSE" }
            }
            else {
                $Worksheet.Cells.Item($rowIndex + 2, $col + 1).Value2 = [string]$value
            }
        }
    }

    $usedRange = $Worksheet.Range($Worksheet.Cells.Item(1, 1), $Worksheet.Cells.Item($Rows.Count + 1, $headers.Count))
    $listObject = $Worksheet.ListObjects.Add(1, $usedRange, $null, 1)
    $listObject.Name = $TableName
    $listObject.TableStyle = "TableStyleLight9"
    $Worksheet.Columns.AutoFit() | Out-Null
    return $listObject
}

function Set-Card {
    param(
        [Parameter(Mandatory)]
        $Worksheet,
        [Parameter(Mandatory)]
        [string]$RangeAddress,
        [Parameter(Mandatory)]
        [string]$Title,
        [Parameter(Mandatory)]
        [string]$Formula,
        [Parameter(Mandatory)]
        [int]$FillColor
    )

    $range = $Worksheet.Range($RangeAddress)
    $range.Merge()
    $range.Value2 = "$Title`n"
    $range.Characters(1, $Title.Length).Font.Bold = $true
    $range.Characters(1, $Title.Length).Font.Size = 11
    $range.WrapText = $true
    $range.HorizontalAlignment = -4108
    $range.VerticalAlignment = -4108
    $range.Interior.Color = $FillColor
    $range.Font.Color = 0xFFFFFF

    $valueCell = $Worksheet.Cells.Item($range.Row + 1, $range.Column)
    $valueCell.Formula = $Formula
    $valueCell.Font.Bold = $true
    $valueCell.Font.Size = 24
    $valueCell.Font.Color = 0xFFFFFF
}

$resolvedOutputPath = [System.IO.Path]::GetFullPath((Join-Path (Get-Location) $OutputPath))
$outputDirectory = Split-Path -Parent $resolvedOutputPath
New-Item -ItemType Directory -Path $outputDirectory -Force | Out-Null

$candidateRows = Convert-ToSnapshotRows -Items (Get-ListSnapshot -WebUrl $SiteUrl -ListTitle "BGV_Candidates") -Type "Candidates"
$requestRows = Convert-ToSnapshotRows -Items (Get-ListSnapshot -WebUrl $SiteUrl -ListTitle "BGV_Requests") -Type "Requests"
$formDataRows = Convert-ToSnapshotRows -Items (Get-ListSnapshot -WebUrl $SiteUrl -ListTitle "BGV_FormData") -Type "FormData"
$masterRows = Build-MasterRows -Candidates $candidateRows -Requests $requestRows -FormData $formDataRows
$snapshotTimestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
$queryFormulaPath = Join-Path $outputDirectory "BGV Dashboard Master Query.m"
[System.IO.File]::WriteAllText($queryFormulaPath, (New-BgvMasterQueryFormula))

$excel = $null
$workbook = $null
$dashboardSheet = $null
$casesSheet = $null
$supportSheet = $null
$rawCandidatesSheet = $null
$rawRequestsSheet = $null
$rawFormDataSheet = $null

try {
    $excel = New-Object -ComObject Excel.Application
    $excel.Visible = $false
    $excel.DisplayAlerts = $false
    $excel.ScreenUpdating = $false

    $workbook = $excel.Workbooks.Add()
    while ($workbook.Worksheets.Count -lt 6) {
        [void]$workbook.Worksheets.Add()
    }

    $dashboardSheet = $workbook.Worksheets.Item(1)
    $casesSheet = $workbook.Worksheets.Item(2)
    $supportSheet = $workbook.Worksheets.Item(3)
    $rawCandidatesSheet = $workbook.Worksheets.Item(4)
    $rawRequestsSheet = $workbook.Worksheets.Item(5)
    $rawFormDataSheet = $workbook.Worksheets.Item(6)

    $dashboardSheet.Name = "Summary"
    $casesSheet.Name = "Cases"
    $supportSheet.Name = "Support"
    $rawCandidatesSheet.Name = "RawCandidates"
    $rawRequestsSheet.Name = "RawRequests"
    $rawFormDataSheet.Name = "RawFormData"

    [void](Write-SnapshotTable -Worksheet $rawCandidatesSheet -TableName "tblCandidatesRaw" -Rows $candidateRows)
    [void](Write-SnapshotTable -Worksheet $rawRequestsSheet -TableName "tblRequestsRaw" -Rows $requestRows)
    [void](Write-SnapshotTable -Worksheet $rawFormDataSheet -TableName "tblFormDataRaw" -Rows $formDataRows)
    $casesTable = Write-SnapshotTable -Worksheet $casesSheet -TableName "tblBGVCases" -Rows $masterRows
    $casesTable.TableStyle = "TableStyleMedium2"
    $casesSheet.Columns.AutoFit() | Out-Null

    $supportSheet.Range("A1").Value2 = "Status"
    $supportSheet.Range("B1").Value2 = "Count"
    $stages = @(
        "Candidate Form Received",
        "Authorisation Form Sent",
        "Authorisation Form Received",
        "Authorisation Received - Employer Email Queued",
        "Email Sent to Employer",
        "Employer Reminder 1 Sent",
        "Employer Reminder 2 Sent",
        "Employer Reminder 3 Sent",
        "Employer Form Received"
    )
    for ($i = 0; $i -lt $stages.Count; $i++) {
        $row = $i + 2
        $supportSheet.Cells.Item($row, 1).Value2 = $stages[$i]
        $supportSheet.Cells.Item($row, 2).Formula = "=COUNTIF(tblBGVCases[Status],A$row)"
    }

    $supportSheet.Range("D1").Value2 = "Overdue"
    $supportSheet.Range("E1").Value2 = "Count"
    $waiting = @("Yes", "No")
    for ($i = 0; $i -lt $waiting.Count; $i++) {
        $row = $i + 2
        $supportSheet.Cells.Item($row, 4).Value2 = $waiting[$i]
        $supportSheet.Cells.Item($row, 5).Formula = "=COUNTIF(tblBGVCases[Overdue],D$row)"
    }

    $dashboardSheet.Range("A1:H2").Merge()
    $dashboardSheet.Range("A1").Value2 = "BGV Recruiter Summary"
    $dashboardSheet.Range("A1").Font.Bold = $true
    $dashboardSheet.Range("A1").Font.Size = 24
    $dashboardSheet.Range("A1").HorizontalAlignment = -4131

    $dashboardSheet.Range("A3:H3").Merge()
    $dashboardSheet.Range("A3").Value2 = "Pivot-style recruiter summary built from live SharePoint list exports"
    $dashboardSheet.Range("A3").Font.Size = 11
    $dashboardSheet.Range("A3").Font.Color = 0x666666

    $dashboardSheet.Range("A4:H4").Merge()
    $dashboardSheet.Range("A4").Value2 = "Snapshot time: $snapshotTimestamp"
    $dashboardSheet.Range("A4").Font.Size = 10
    $dashboardSheet.Range("A4").Font.Color = 0x666666

    Set-Card -Worksheet $dashboardSheet -RangeAddress "A6:B7" -Title "Open Cases" -Formula "=COUNTIF(tblBGVCases[Completed Status],""No"")" -FillColor 0x365F91
    Set-Card -Worksheet $dashboardSheet -RangeAddress "C6:D7" -Title "Overdue Cases" -Formula "=COUNTIF(tblBGVCases[Overdue],""Yes"")" -FillColor 0xC0504D
    Set-Card -Worksheet $dashboardSheet -RangeAddress "E6:F7" -Title "Employer Forms Received" -Formula "=COUNTIF(tblBGVCases[Status],""Employer Form Received"")" -FillColor 0x70AD47
    Set-Card -Worksheet $dashboardSheet -RangeAddress "G6:H7" -Title "Authorisation Forms Sent" -Formula "=COUNTIF(tblBGVCases[Status],""Authorisation Form Sent"")" -FillColor 0x5B9BD5

    $dashboardSheet.Range("A10").Value2 = "Status"
    $dashboardSheet.Range("B10").Value2 = "Count"
    $dashboardSheet.Range("A10:B10").Font.Bold = $true
    for ($i = 0; $i -lt $stages.Count; $i++) {
        $sourceRow = $i + 2
        $targetRow = $i + 11
        $dashboardSheet.Cells.Item($targetRow, 1).Value2 = $supportSheet.Cells.Item($sourceRow, 1).Value2
        $dashboardSheet.Cells.Item($targetRow, 2).Formula = "=COUNTIF(tblBGVCases[Status],A$targetRow)"
    }
    $dashboardSheet.Range("A10:B19").Borders.LineStyle = 1
    $dashboardSheet.Range("A10:B10").Interior.Color = 0xD9EAF7
    $dashboardSheet.Range("A10:B19").Columns.AutoFit() | Out-Null

    $dashboardSheet.Range("E10").Value2 = "Overdue"
    $dashboardSheet.Range("F10").Value2 = "Count"
    $dashboardSheet.Range("E10:F10").Font.Bold = $true
    $dashboardSheet.Range("E11").Value2 = "Yes"
    $dashboardSheet.Range("F11").Formula = "=COUNTIF(tblBGVCases[Overdue],""Yes"")"
    $dashboardSheet.Range("E12").Value2 = "No"
    $dashboardSheet.Range("F12").Formula = "=COUNTIF(tblBGVCases[Overdue],""No"")"
    $dashboardSheet.Range("E10:F12").Borders.LineStyle = 1
    $dashboardSheet.Range("E10:F10").Interior.Color = 0xFCE4D6
    $dashboardSheet.Range("E10:F12").Columns.AutoFit() | Out-Null

    $dashboardSheet.Range("G10").Value2 = "Completed"
    $dashboardSheet.Range("H10").Value2 = "Count"
    $dashboardSheet.Range("G10:H10").Font.Bold = $true
    $dashboardSheet.Range("G11").Value2 = "Yes"
    $dashboardSheet.Range("H11").Formula = "=COUNTIF(tblBGVCases[Completed Status],""Yes"")"
    $dashboardSheet.Range("G12").Value2 = "No"
    $dashboardSheet.Range("H12").Formula = "=COUNTIF(tblBGVCases[Completed Status],""No"")"
    $dashboardSheet.Range("G10:H12").Borders.LineStyle = 1
    $dashboardSheet.Range("G10:H10").Interior.Color = 0xE2F0D9
    $dashboardSheet.Range("G10:H12").Columns.AutoFit() | Out-Null

    $dashboardSheet.Range("A22:H22").Merge()
    $dashboardSheet.Range("A22").Value2 = "Use the filter arrows on the Cases sheet to view the condensed recruiter table. This summary sheet is the pivot-style overview of the same table."
    $dashboardSheet.Range("A22").Font.Size = 10
    $dashboardSheet.Range("A22").Font.Color = 0x666666

    $supportSheet.Visible = 0
    $rawCandidatesSheet.Visible = 0
    $rawRequestsSheet.Visible = 0
    $rawFormDataSheet.Visible = 0

    $workbook.SaveAs($resolvedOutputPath, 51)
    $workbook.Close($true)

    if ($UploadToSharePoint) {
        $uploadResult = & m365 spo file add --webUrl $SiteUrl --folder $LibraryFolder --path $resolvedOutputPath --overwrite
        Write-Host $uploadResult
    }

    Write-Host "BGV dashboard workbook created at: $resolvedOutputPath"
    Write-Host "Power Query M logic exported at: $queryFormulaPath"
}
finally {
    if ($null -ne $workbook) { Release-ComObject -ComObject $workbook }
    if ($null -ne $dashboardSheet) { Release-ComObject -ComObject $dashboardSheet }
    if ($null -ne $casesSheet) { Release-ComObject -ComObject $casesSheet }
    if ($null -ne $supportSheet) { Release-ComObject -ComObject $supportSheet }
    if ($null -ne $rawCandidatesSheet) { Release-ComObject -ComObject $rawCandidatesSheet }
    if ($null -ne $rawRequestsSheet) { Release-ComObject -ComObject $rawRequestsSheet }
    if ($null -ne $rawFormDataSheet) { Release-ComObject -ComObject $rawFormDataSheet }
    if ($null -ne $excel) {
        try { $excel.Quit() } catch {}
        Release-ComObject -ComObject $excel
    }
    [GC]::Collect()
    [GC]::WaitForPendingFinalizers()
}
