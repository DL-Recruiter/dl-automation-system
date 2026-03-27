param(
    [string]$OutputPath = (Join-Path $PSScriptRoot "..\\..\\out\\dashboard\\BGVDashboard_FLow.xlsx")
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Set-HeaderRow {
    param(
        [Parameter(Mandatory = $true)]$Worksheet,
        [Parameter(Mandatory = $true)][string[]]$Headers
    )

    for ($i = 0; $i -lt $Headers.Count; $i++) {
        $Worksheet.Cells.Item(1, $i + 1).Value2 = $Headers[$i]
    }

    $headerRange = $Worksheet.Range($Worksheet.Cells.Item(1, 1), $Worksheet.Cells.Item(1, $Headers.Count))
    $headerRange.Font.Bold = $true
    $headerRange.Interior.Color = 0x365F91
    $headerRange.Font.Color = 0xFFFFFF
}

function Add-Table {
    param(
        [Parameter(Mandatory = $true)]$Worksheet,
        [Parameter(Mandatory = $true)][string]$TableName,
        [Parameter(Mandatory = $true)][int]$RowCount,
        [Parameter(Mandatory = $true)][int]$ColumnCount
    )

    $tableRange = $Worksheet.Range($Worksheet.Cells.Item(1, 1), $Worksheet.Cells.Item($RowCount, $ColumnCount))
    $listObject = $Worksheet.ListObjects.Add(1, $tableRange, $null, 1)
    $listObject.Name = $TableName
    $listObject.TableStyle = "TableStyleMedium2"
    return $listObject
}

$resolvedOutputPath = [System.IO.Path]::GetFullPath($OutputPath)
$outputDirectory = Split-Path -Parent $resolvedOutputPath
if (-not (Test-Path -LiteralPath $outputDirectory)) {
    New-Item -ItemType Directory -Path $outputDirectory -Force | Out-Null
}

if (Test-Path -LiteralPath $resolvedOutputPath) {
    Remove-Item -LiteralPath $resolvedOutputPath -Force
}

$excel = $null
$workbook = $null

try {
    $excel = New-Object -ComObject Excel.Application
    $excel.Visible = $false
    $excel.DisplayAlerts = $false

    $workbook = $excel.Workbooks.Add()

    while ($workbook.Worksheets.Count -lt 4) {
        $null = $workbook.Worksheets.Add()
    }

    $summarySheet = $workbook.Worksheets.Item(1)
    $casesSheet = $workbook.Worksheets.Item(2)
    $helperSheet = $workbook.Worksheets.Item(3)
    $refreshSheet = $workbook.Worksheets.Item(4)

    $summarySheet.Name = "Summary"
    $casesSheet.Name = "Cases"
    $helperSheet.Name = "Helper"
    $refreshSheet.Name = "RefreshLog"

    foreach ($sheet in @($summarySheet, $casesSheet, $helperSheet, $refreshSheet)) {
        $sheet.Cells.Font.Name = "Calibri"
        $sheet.Cells.Font.Size = 11
    }

    $caseHeaders = @(
        "DashboardKey",
        "Candidate Name",
        "CandidateID",
        "RequestID",
        "Company Name",
        "HR Name",
        "HR Email",
        "HR Mobile Number",
        "Status",
        "Candidate Reminder",
        "Employer Reminder",
        "Completed Status",
        "Completed Date",
        "Employer Response Received At",
        "Employer Email Reply At",
        "Last Activity At",
        "Severity",
        "Outcome"
    )

    Set-HeaderRow -Worksheet $casesSheet -Headers $caseHeaders
    Add-Table -Worksheet $casesSheet -TableName "tblDashboardCasesPA" -RowCount 2 -ColumnCount $caseHeaders.Count | Out-Null
    $casesSheet.Columns.Item(1).Hidden = $true
    $casesSheet.Range("A1:R2").EntireColumn.AutoFit() | Out-Null

    $summarySheet.Range("A1").Value2 = "BGV Dashboard Flow"
    $summarySheet.Range("A1").Font.Size = 18
    $summarySheet.Range("A1").Font.Bold = $true
    $summarySheet.Range("A3").Value2 = "This workbook is maintained by the cloud refresh flow and is designed around stable Excel tables."
    $summarySheet.Range("A4").Value2 = "It keeps the recruiter dashboard focused on live request status, reminders, completion, severity, and latest activity."
    $summarySheet.Range("A3:K4").WrapText = $true

    $summarySheet.Range("A6").Value2 = "Total Requests"
    $summarySheet.Range("B6").Value2 = 0
    $summarySheet.Range("D6").Value2 = "Open Cases"
    $summarySheet.Range("E6").Value2 = 0
    $summarySheet.Range("G6").Value2 = "Completed Cases"
    $summarySheet.Range("H6").Formula = "=COUNTIF(tblDashboardCasesPA[Completed Status],""Yes"")"
    $summarySheet.Range("J6").Value2 = "Employer Forms Received"
    $summarySheet.Range("K6").Formula = "=COUNTIF(tblDashboardCasesPA[Status],""Employer Form Received"")"
    $summarySheet.Range("M6").Value2 = "Authorisation Forms Sent"
    $summarySheet.Range("N6").Formula = "=COUNTIF(tblDashboardCasesPA[Status],""Authorisation Form Sent"")"

    foreach ($addr in @("A6:B7", "D6:E7", "G6:H7", "J6:K7", "M6:N7")) {
        $range = $summarySheet.Range($addr)
        $range.Borders.LineStyle = 1
        $range.Interior.Color = 0xD9EAF7
    }

    $summarySheet.Range("A9").Value2 = "Status"
    $summarySheet.Range("B9").Value2 = "Count"
    $summarySheet.Range("D9").Value2 = "Severity"
    $summarySheet.Range("E9").Value2 = "Count"

    $statusLabels = @(
        "Candidate Form Received",
        "Authorisation Form Sent",
        "Authorisation Form Received",
        "Authorisation Received - Employer Email Queued",
        "Email Sent to Employer",
        "Employer Reminder 1 Sent",
        "Employer Reminder 2 Sent",
        "Employer Reminder 3 Sent",
        "Employer Form Received",
        "Employer Form Received But Flagged"
    )

    for ($i = 0; $i -lt $statusLabels.Count; $i++) {
        $row = 10 + $i
        $summarySheet.Cells.Item($row, 1).Value2 = $statusLabels[$i]
        $summarySheet.Cells.Item($row, 2).Formula = "=COUNTIF(tblDashboardCasesPA[Status],A$row)"
    }

    $severityLabels = @("", "Neutral", "Low", "Medium", "High")
    for ($i = 0; $i -lt $severityLabels.Count; $i++) {
        $row = 10 + $i
        $summarySheet.Cells.Item($row, 4).Value2 = $(if ([string]::IsNullOrEmpty($severityLabels[$i])) { "(blank)" } else { $severityLabels[$i] })
        if ([string]::IsNullOrEmpty($severityLabels[$i])) {
            $summarySheet.Cells.Item($row, 5).Formula = "=COUNTBLANK(tblDashboardCasesPA[Severity])"
        }
        else {
            $summarySheet.Cells.Item($row, 5).Formula = "=COUNTIF(tblDashboardCasesPA[Severity],D$row)"
        }
    }

    $summarySheet.Range("A9:B19").Borders.LineStyle = 1
    $summarySheet.Range("D9:E14").Borders.LineStyle = 1

    $summarySheet.Range("G9").Value2 = "Closed Cases Report"
    $summarySheet.Range("G10").Value2 = "Employer Form Received"
    $summarySheet.Range("H10").Value2 = 0
    $summarySheet.Range("G11").Value2 = "Employer Form Received But Flagged"
    $summarySheet.Range("H11").Value2 = 0
    $summarySheet.Range("G12").Value2 = "Employer Reminder 3 Sent"
    $summarySheet.Range("H12").Value2 = 0
    $summarySheet.Range("G13").Value2 = "Cleared Rows (Total)"
    $summarySheet.Range("H13").Value2 = 0
    $summarySheet.Range("G9:H13").Borders.LineStyle = 1

    $summarySheet.Columns("A:N").AutoFit() | Out-Null

    $helperSheet.Range("A1").Value2 = "Status"
    $helperSheet.Range("A1").Font.Bold = $true
    for ($i = 0; $i -lt $statusLabels.Count; $i++) {
        $helperSheet.Cells.Item($i + 2, 1).Value2 = $statusLabels[$i]
    }
    Add-Table -Worksheet $helperSheet -TableName "tblDashboardStatusLegend" -RowCount ($statusLabels.Count + 1) -ColumnCount 1 | Out-Null

    $helperSheet.Range("C1").Value2 = "Severity"
    $helperSheet.Range("C1").Font.Bold = $true
    $helperSeverity = @("(blank)", "Neutral", "Low", "Medium", "High")
    for ($i = 0; $i -lt $helperSeverity.Count; $i++) {
        $helperSheet.Cells.Item($i + 2, 3).Value2 = $helperSeverity[$i]
    }
    $severityRange = $helperSheet.Range($helperSheet.Cells.Item(1, 3), $helperSheet.Cells.Item($helperSeverity.Count + 1, 3))
    $severityTable = $helperSheet.ListObjects.Add(1, $severityRange, $null, 1)
    $severityTable.Name = "tblDashboardSeverityLegend"
    $severityTable.TableStyle = "TableStyleMedium3"

    $refreshHeaders = @(
        "Run At (SGT)",
        "Trigger",
        "Refresh Mode",
        "Rows Written",
        "Total Requests",
        "Active Cases",
        "Cleared Cases",
        "Closed Employer Form Received",
        "Closed Employer Form Received But Flagged",
        "Closed Reminder 3 Sent",
        "Notes"
    )
    Set-HeaderRow -Worksheet $refreshSheet -Headers $refreshHeaders
    $refreshSheet.Cells.Item(2, 1).Value2 = [DateTime]::UtcNow.AddHours(8).ToString("yyyy-MM-dd HH:mm:ss")
    $refreshSheet.Cells.Item(2, 2).Value2 = "Flow-managed dashboard build"
    $refreshSheet.Cells.Item(2, 3).Value2 = "Structure only"
    $refreshSheet.Cells.Item(2, 4).Value2 = 0
    $refreshSheet.Cells.Item(2, 5).Value2 = 0
    $refreshSheet.Cells.Item(2, 6).Value2 = 0
    $refreshSheet.Cells.Item(2, 7).Value2 = 0
    $refreshSheet.Cells.Item(2, 8).Value2 = 0
    $refreshSheet.Cells.Item(2, 9).Value2 = 0
    $refreshSheet.Cells.Item(2, 10).Value2 = 0
    $refreshSheet.Cells.Item(2, 11).Value2 = "Power Automate refreshes this workbook through tblDashboardCasesPA and tblDashboardRefreshLog."
    Add-Table -Worksheet $refreshSheet -TableName "tblDashboardRefreshLog" -RowCount 2 -ColumnCount $refreshHeaders.Count | Out-Null
    $refreshSheet.Columns("A:K").AutoFit() | Out-Null

    $summarySheet.Range("B6").Formula = "=IFERROR(INDEX(tblDashboardRefreshLog[Total Requests],ROWS(tblDashboardRefreshLog[Total Requests])),0)"
    $summarySheet.Range("E6").Formula = "=IFERROR(INDEX(tblDashboardRefreshLog[Active Cases],ROWS(tblDashboardRefreshLog[Active Cases])),0)"
    $summarySheet.Range("H10").Formula = "=IFERROR(INDEX(tblDashboardRefreshLog[Closed Employer Form Received],ROWS(tblDashboardRefreshLog[Closed Employer Form Received])),0)"
    $summarySheet.Range("H11").Formula = "=IFERROR(INDEX(tblDashboardRefreshLog[Closed Employer Form Received But Flagged],ROWS(tblDashboardRefreshLog[Closed Employer Form Received But Flagged])),0)"
    $summarySheet.Range("H12").Formula = "=IFERROR(INDEX(tblDashboardRefreshLog[Closed Reminder 3 Sent],ROWS(tblDashboardRefreshLog[Closed Reminder 3 Sent])),0)"
    $summarySheet.Range("H13").Formula = "=IFERROR(INDEX(tblDashboardRefreshLog[Cleared Cases],ROWS(tblDashboardRefreshLog[Cleared Cases])),0)"

    $summarySheet.Activate() | Out-Null

    $xlOpenXmlWorkbook = 51
    $workbook.SaveAs($resolvedOutputPath, $xlOpenXmlWorkbook)
    Write-Output "Created dashboard-flow workbook: $resolvedOutputPath"
}
finally {
    if ($workbook -ne $null) {
        $workbook.Close($false)
        [void][System.Runtime.InteropServices.Marshal]::ReleaseComObject($workbook)
    }
    if ($excel -ne $null) {
        $excel.Quit()
        [void][System.Runtime.InteropServices.Marshal]::ReleaseComObject($excel)
    }
    [GC]::Collect()
    [GC]::WaitForPendingFinalizers()
}
