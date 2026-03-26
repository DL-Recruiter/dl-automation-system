param(
    [string]$OutputPath = (Join-Path $PSScriptRoot "..\\..\\out\\dashboard\\BGV Dashboard - Power Automate Prototype.xlsx")
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

    while ($workbook.Worksheets.Count -lt 5) {
        $null = $workbook.Worksheets.Add()
    }

    $summarySheet = $workbook.Worksheets.Item(1)
    $casesSheet = $workbook.Worksheets.Item(2)
    $helperSheet = $workbook.Worksheets.Item(3)
    $refreshSheet = $workbook.Worksheets.Item(4)
    $comparisonSheet = $workbook.Worksheets.Item(5)

    $summarySheet.Name = "Summary"
    $casesSheet.Name = "Cases"
    $helperSheet.Name = "Helper"
    $refreshSheet.Name = "RefreshLog"
    $comparisonSheet.Name = "Comparison"

    foreach ($sheet in @($summarySheet, $casesSheet, $helperSheet, $refreshSheet, $comparisonSheet)) {
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
        "Employer Response Received At",
        "Employer Email Reply At",
        "Last Activity At",
        "Severity",
        "Outcome"
    )

    Set-HeaderRow -Worksheet $casesSheet -Headers $caseHeaders
    Add-Table -Worksheet $casesSheet -TableName "tblDashboardCasesPA" -RowCount 2 -ColumnCount $caseHeaders.Count | Out-Null
    $casesSheet.Columns.Item(1).Hidden = $true
    $casesSheet.Range("A1:Q2").EntireColumn.AutoFit() | Out-Null

    $summarySheet.Range("A1").Value2 = "BGV Dashboard - Power Automate Prototype"
    $summarySheet.Range("A1").Font.Size = 18
    $summarySheet.Range("A1").Font.Bold = $true
    $summarySheet.Range("A3").Value2 = "This workbook is a prototype for a cloud-refreshable dashboard. Power Automate should update only Excel tables; it should not rebuild workbook structure."
    $summarySheet.Range("A4").Value2 = "Compared with the current dashboard, Overdue is removed and the layout is centered around tblDashboardCasesPA."
    $summarySheet.Range("A3:K4").WrapText = $true

    $summarySheet.Range("A6").Value2 = "Total Requests"
    $summarySheet.Range("B6").Formula = "=COUNTA(tblDashboardCasesPA[RequestID])"
    $summarySheet.Range("D6").Value2 = "Open Cases"
    $summarySheet.Range("E6").Formula = "=COUNTIF(tblDashboardCasesPA[Completed Status],""No"")"
    $summarySheet.Range("G6").Value2 = "Employer Forms Received"
    $summarySheet.Range("H6").Formula = "=COUNTIF(tblDashboardCasesPA[Status],""Employer Form Received"")"
    $summarySheet.Range("J6").Value2 = "Authorisation Forms Sent"
    $summarySheet.Range("K6").Formula = "=COUNTIF(tblDashboardCasesPA[Status],""Authorisation Form Sent"")"

    foreach ($addr in @("A6:B7", "D6:E7", "G6:H7", "J6:K7")) {
        $range = $summarySheet.Range($addr)
        $range.Borders.LineStyle = 1
        $range.Interior.Color = 0xD9EAF7
    }

    $summarySheet.Range("A10").Value2 = "Status"
    $summarySheet.Range("B10").Value2 = "Count"
    $summarySheet.Range("D10").Value2 = "Severity"
    $summarySheet.Range("E10").Value2 = "Count"

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
        "In Progress"
    )

    for ($i = 0; $i -lt $statusLabels.Count; $i++) {
        $row = 11 + $i
        $summarySheet.Cells.Item($row, 1).Value2 = $statusLabels[$i]
        $summarySheet.Cells.Item($row, 2).Formula = "=COUNTIF(tblDashboardCasesPA[Status],A$row)"
    }

    $severityLabels = @("", "Neutral", "Low", "Medium", "High")
    for ($i = 0; $i -lt $severityLabels.Count; $i++) {
        $row = 11 + $i
        $summarySheet.Cells.Item($row, 4).Value2 = $(if ([string]::IsNullOrEmpty($severityLabels[$i])) { "(blank)" } else { $severityLabels[$i] })
        if ([string]::IsNullOrEmpty($severityLabels[$i])) {
            $summarySheet.Cells.Item($row, 5).Formula = "=COUNTBLANK(tblDashboardCasesPA[Severity])"
        }
        else {
            $summarySheet.Cells.Item($row, 5).Formula = "=COUNTIF(tblDashboardCasesPA[Severity],D$row)"
        }
    }

    $summarySheet.Range("A10:B20").Borders.LineStyle = 1
    $summarySheet.Range("D10:E15").Borders.LineStyle = 1
    $summarySheet.Columns("A:K").AutoFit() | Out-Null

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

    $refreshHeaders = @("Run At (UTC)", "Trigger", "Refresh Mode", "Rows Written", "Notes")
    Set-HeaderRow -Worksheet $refreshSheet -Headers $refreshHeaders
    $refreshSheet.Cells.Item(2, 1).Value2 = [DateTime]::UtcNow.ToString("yyyy-MM-dd HH:mm:ss")
    $refreshSheet.Cells.Item(2, 2).Value2 = "Prototype build"
    $refreshSheet.Cells.Item(2, 3).Value2 = "Structure only"
    $refreshSheet.Cells.Item(2, 4).Value2 = 0
    $refreshSheet.Cells.Item(2, 5).Value2 = "Power Automate should overwrite this table on each refresh."
    Add-Table -Worksheet $refreshSheet -TableName "tblDashboardRefreshLog" -RowCount 2 -ColumnCount $refreshHeaders.Count | Out-Null
    $refreshSheet.Columns("A:E").AutoFit() | Out-Null

    $comparisonRows = @(
        @("Refresh engine", "Local PowerShell + Excel COM rebuild", "Power Automate recurrence + Excel Online table refresh"),
        @("Workbook write pattern", "Rebuild workbook structure from scratch", "Keep structure stable and update tables only"),
        @("Operational dependency", "Depends on local PC and scheduled task", "Cloud refresh; not machine-specific"),
        @("Main data sheet", "Cases", "Cases"),
        @("Summary source", "tblBGVCases", "tblDashboardCasesPA"),
        @("Overdue column", "Present", "Removed"),
        @("Unique row key", "Implicit request row", "Explicit hidden DashboardKey"),
        @("Runtime lock risk", "High during overwrite", "Lower; row refresh instead of file rebuild"),
        @("Recommended future flow", "None", "BGV_9_Refresh_Dashboard_Excel")
    )

    $comparisonHeaders = @("Area", "Current Dashboard", "Power Automate Prototype")
    Set-HeaderRow -Worksheet $comparisonSheet -Headers $comparisonHeaders
    for ($r = 0; $r -lt $comparisonRows.Count; $r++) {
        for ($c = 0; $c -lt 3; $c++) {
            $comparisonSheet.Cells.Item($r + 2, $c + 1).Value2 = $comparisonRows[$r][$c]
        }
    }
    Add-Table -Worksheet $comparisonSheet -TableName "tblDashboardComparison" -RowCount ($comparisonRows.Count + 1) -ColumnCount 3 | Out-Null
    $comparisonSheet.Columns("A:C").ColumnWidth = 35
    $comparisonSheet.Range("A1:C10").EntireRow.AutoFit() | Out-Null

    $summarySheet.Activate() | Out-Null

    $xlOpenXmlWorkbook = 51
    $workbook.SaveAs($resolvedOutputPath, $xlOpenXmlWorkbook)
    Write-Output "Created prototype workbook: $resolvedOutputPath"
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
