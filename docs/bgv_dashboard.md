# BGV Dashboard

`BGV Dashboard` is a lean Excel workbook for recruiters on the `DLR Recruitment Ops` SharePoint site.

It is designed to live in the `BGV Records` document library and is currently uploaded at:

- `BGV Records/Dashboard/BGV Dashboard.xlsx`

It is built from fresh exports of:

- `BGV_Candidates`
- `BGV_Requests`
- `BGV_FormData`

## What the workbook shows

The workbook now keeps the recruiter view intentionally condensed:

- `Summary` sheet:
  - pivot-style status count table
  - overdue count table
  - completed count table
  - a few top KPI cards
- `Cases` sheet:
  - one condensed recruiter table with the main case details only

## Master Table Fields

The recruiter-facing table is trimmed to the fields recruiters need most:

- `Candidate Name`
- `CandidateID`
- `RequestID`
- `Company Name`
- `HR Name`
- `HR Email`
- `HR Mobile Number`
- `Status`
- `Candidate Reminder`
- `Employer Reminder`
- `Completed Status`
- `Completed Date`
- `Employer Response Received At`
- `Employer Email Reply At`
- `Last Activity At`
- `Severity`
- `Outcome`

## Status Logic

The main recruiter stage is now one single column called `Status`:

- `Candidate Form Received`
- `Authorisation Form Sent`
- `Authorisation Form Received`
- `Authorisation Received - Employer Email Queued`
- `Email Sent to Employer`
- `Employer Reminder 1 Sent`
- `Employer Reminder 2 Sent`
- `Employer Reminder 3 Sent`
- `Employer Form Received`
- `Employer Form Received But Flagged`

This condenses the candidate and employer journey into one recruiter-friendly stage field.

## Reminder Logic

The workbook shows reminders in two simple columns:

- `Candidate Reminder`
  - shows `Not sent` or `1: yyyy-mm-dd hh:mm`
- `Employer Reminder`
  - shows `Not sent` or the latest reminder as `1:`, `2:`, or `3:` plus date and time

## Header Logic Doc

Column-by-column header meaning, summary interpretation, and row-clearing logic are documented in:

- `docs/bgv_dashboard_headers.md`

Implementation details, connectors, push steps, and the important script/code areas are documented in:

- `docs/bgv_dashboard_implementation_guide.md`

## Refresh

The build script exports the live SharePoint lists through the authenticated `m365` CLI and rebuilds the workbook snapshot.

This keeps the workbook stable without needing Power Automate.

To refresh the dashboard snapshot, rerun the build script.

## Build Script

Use the generator script to rebuild or re-upload the workbook:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\active\build_bgv_dashboard.ps1 -UploadToSharePoint
```

The builder also exports the reusable Power Query M logic beside the workbook for reference/documentation:

- `out/dashboard/BGV Dashboard Master Query.m`

This avoids needing Power Automate for the dashboard itself.

## Power Automate-first redesign preview

There is now a separate redesign document and a cloud-refreshable dashboard workbook for the Power Automate-managed version:

- `docs/bgv_dashboard_power_automate_redesign.md`
- `out/dashboard/BGVDashboard_FLow.xlsx`
- SharePoint comparison workbook:
  - `BGV Records/Dashboard/BGVDashboard_FLow.xlsx`

This workbook keeps the Summary/Cases feel close to the current dashboard, removes `Overdue`, and is centered around stable Excel tables so Power Automate can refresh rows without rebuilding workbook structure.

## Live cloud-refresh target

The Power Automate-managed dashboard workbook is now:

- `BGV Records/Dashboard/BGVDashboard_FLow.xlsx`

It is refreshed by:

- `BGV_9_Refresh_Dashboard_Excel`

Schedule:

- `9:00 AM`
- `12:00 PM`
- `3:00 PM`
- `6:00 PM`
- `9:00 PM`

Singapore time.

## Manual Refresh

If you want to refresh the dashboard yourself at any time, run:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\active\run_bgv_dashboard_refresh.ps1
```

This rebuilds the workbook from live SharePoint list data and uploads it back to:

- `BGV Records/Dashboard/BGV Dashboard.xlsx`

## Automatic Refresh Schedule

This repo now includes a helper script to register a local Windows scheduled task for the dashboard refresh.

To register it:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\active\register_bgv_dashboard_refresh_task.ps1
```

The task runs daily at:

- `9:00 AM`
- `12:00 PM`
- `3:00 PM`
- `6:00 PM`
- `9:00 PM`

Important:

- this is a local Windows scheduled task, not a Power Automate cloud flow
- it does not consume Power Automate flow space or runs
- the machine must be on and the interactive user session must be available
