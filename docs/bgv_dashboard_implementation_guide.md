# PEV Dashboard Implementation Guide

This document explains, in simple terms, how the `PEV Dashboard` workbook is built, what tools/connectors are used, and how it is synced between local, GitHub, and SharePoint.

## What Was Built

The dashboard is an Excel workbook for recruiters.

It has:

- a `Summary` sheet
  - simple pivot-style summary blocks
  - KPI cards
  - status counts
  - overdue counts
  - completed counts
- a `Cases` sheet
  - one condensed recruiter-facing table

The workbook is stored in SharePoint here:

- `BGV Records/Dashboard/PEV Dashboard.xlsx`

## Data Sources Used

The dashboard is built from these SharePoint lists:

- `BGV_Candidates`
- `BGV_Requests`
- `BGV_FormData`

These are the three lists that hold:

- candidate identity and authorization state
- employer verification state
- HR and company details from normalized form data

## Connectors / Tools Used

No Power Automate cloud flow was added for this dashboard.

The dashboard build uses:

### 1. Microsoft 365 CLI (`m365`)

Used to read SharePoint list data and upload the finished workbook.

Important commands used:

```powershell
m365 spo listitem list --webUrl <site> --listTitle <list> --output json
m365 spo file add --webUrl <site> --folder "BGV Records/Dashboard" --path "<local workbook>" --overwrite
```

What this means:

- `listitem list` pulls the live SharePoint rows as JSON
- `file add` uploads the generated workbook back to SharePoint

### 2. Excel COM automation

Used from PowerShell to create and format the workbook.

This is done through:

- `New-Object -ComObject Excel.Application`

What it does:

- opens Excel silently
- creates worksheets
- writes tables and summary ranges
- saves the workbook

### 3. PowerShell

The main builder is a PowerShell script:

- `scripts/active/build_bgv_dashboard.ps1`

This is the real source of truth for the dashboard build process.

## Power Automate-first redesign reference

The repo now also contains a separate redesign package for a cloud-refreshable version of the dashboard:

- design document:
  - `docs/bgv_dashboard_power_automate_redesign.md`
- workbook builder output:
  - `out/dashboard/PEVDashboard_Flow.xlsx`

That workbook is intentionally separate from the original snapshot dashboard so both approaches can be compared side by side in SharePoint.

## New cloud refresh flow

The repo now also includes a cloud refresh flow for the Power Automate-friendly dashboard workbook:

- `BGV_9_Refresh_Dashboard_Excel`

Current target workbook:

- `BGV Records/Dashboard/PEVDashboard_Flow.xlsx`

The older local builder and scheduled task remain available as backup for the original snapshot workbook:

- `BGV Records/Dashboard/PEV Dashboard.xlsx`

### 4. Windows Task Scheduler

Used to automate the local dashboard refresh during working hours.

Helper scripts:

- `scripts/active/run_bgv_dashboard_refresh.ps1`
- `scripts/active/register_bgv_dashboard_refresh_task.ps1`

What they do:

- `run_bgv_dashboard_refresh.ps1`
  - runs the dashboard build with `-UploadToSharePoint`
  - writes refresh output into `out/logs/bgv_dashboard_refresh.log`
- `register_bgv_dashboard_refresh_task.ps1`
  - creates a local scheduled task named `DLR PEV Dashboard Refresh`
  - schedules refreshes at `09:00`, `12:00`, `15:00`, `18:00`, and `21:00`

## Was Power Query Used?

Yes, but with an important detail.

There is reusable Power Query M logic exported here:

- `out/dashboard/PEV Dashboard Master Query.m`

That M logic documents the intended table-combination logic.

However, the final workbook is not relying on a live Power Query refresh inside Excel during the automated build, because Excel COM on this machine was not reliable for:

- silent SharePoint-authenticated refresh
- slicer creation
- some workbook-query hydration flows

So the actual shipped workbook is built like this:

1. `m365` exports live SharePoint rows
2. PowerShell combines and condenses the data
3. Excel COM writes the final workbook snapshot
4. `m365` uploads the workbook to SharePoint

So in simple terms:

- Power Query logic exists and is exported for understanding/reference
- the workbook itself is generated from a fresh scripted snapshot build

## Main Script Flow

The build process in `scripts/active/build_bgv_dashboard.ps1` is roughly:

1. Read SharePoint list data
2. Normalize the fields needed for recruiters
3. Derive the condensed recruiter columns
4. Write raw support sheets
5. Write the recruiter `Cases` table
6. Write the `Summary` sheet
7. Save workbook locally
8. Upload workbook to SharePoint when requested

## Important Script Functions

These are the main parts of the script to understand:

### `Get-ListSnapshot`

Purpose:

- calls `m365 spo listitem list`
- gets live SharePoint list rows
- strips any sign-in prompt text before parsing the JSON

Why it matters:

- this is the bridge between SharePoint and the dashboard build

### `Convert-ToSnapshotRows`

Purpose:

- trims the raw SharePoint JSON into the smaller column sets needed from:
  - candidates
  - requests
  - form data

Why it matters:

- avoids carrying every SharePoint field into Excel

### `Build-MasterRows`

Purpose:

- combines the 3 list snapshots into one recruiter-facing row set
- creates the final condensed columns

This is where the important logic lives for:

- `Status`
- `Candidate Reminder`
- `Employer Reminder`
- `Overdue`
- `Completed Status`
- `Employer Email Reply At`
- company/HR detail selection

`Last Activity At` also now considers:

- `BGV_Requests.EmployerEmailReplyAt`

### `Write-SnapshotTable`

Purpose:

- writes a PowerShell object list into an Excel worksheet as a formatted table

Why it matters:

- this is how the `Cases` table and raw sheets are created

### `Set-Card`

Purpose:

- writes and formats the summary KPI cards on the first sheet

## Important Dashboard Logic

### `Status`

The main recruiter stage is condensed into one column:

- `Candidate Form Received`
- `Authorisation Form Sent`
- `Authorisation Form Received`
- `Authorisation Received - Employer Email Queued`
- `Email Sent to Employer`
- `Employer Reminder 1 Sent`
- `Employer Reminder 2 Sent`
- `Employer Reminder 3 Sent`
- `Employer Form Received`

### `Candidate Reminder`

Simple recruiter format:

- `Not sent`
- `1: yyyy-mm-dd hh:mm`

This comes from:

- `BGV_Candidates.LastAuthReminderAt`

### `Employer Reminder`

Simple recruiter format:

- `Not sent`
- `1: yyyy-mm-dd hh:mm`
- `2: yyyy-mm-dd hh:mm`
- `3: yyyy-mm-dd hh:mm`

This comes from:

- `BGV_Requests.Reminder1At`
- `BGV_Requests.Reminder2At`
- `BGV_Requests.Reminder3At`

### `Employer Email Reply At`

This is the latest inbound employer reply email time detected in the recruitment mailbox.

It comes from:

- `BGV_Requests.EmployerEmailReplyAt`

## How the SharePoint Push Works

When the workbook is ready, this command is used:

```powershell
m365 spo file add --webUrl https://dlresourcespl88.sharepoint.com/sites/DLRRecruitmentOps570 --folder "BGV Records/Dashboard" --path "<local workbook path>" --overwrite
```

That replaces the SharePoint file with the latest local build.

If SharePoint says the file is locked:

- a timestamped copy can be uploaded first
- then the main file can be overwritten once the lock is gone

## How Local, GitHub, and SharePoint Stay Aligned

They represent slightly different parts of the same dashboard work:

### Local repo

Stores:

- the build script
- the dashboard docs
- the local workbook output

### GitHub repo

Stores:

- the build script
- the dashboard docs
- the implementation logic/history

### SharePoint

Stores:

- the actual recruiter workbook that users open

So the sync model is:

1. change script/docs locally
2. build workbook locally
3. upload workbook to SharePoint
4. commit/push script/docs to GitHub

That way:

- local and GitHub match for source/versioned logic
- SharePoint matches the latest generated workbook from that same local source

## Files To Know

Main files for this dashboard work:

- `scripts/active/build_bgv_dashboard.ps1`
- `docs/bgv_dashboard.md`
- `docs/bgv_dashboard_headers.md`
- `docs/bgv_dashboard_implementation_guide.md`
- `docs/progress.md`

Generated local outputs:

- `out/dashboard/BGV Dashboard.xlsx`
- `out/dashboard/BGV Dashboard Master Query.m`

## Simple Rebuild Command

If you want to rebuild the workbook again:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\active\build_bgv_dashboard.ps1
```

If you want to rebuild and then upload:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\active\build_bgv_dashboard.ps1
m365 spo file add --webUrl https://dlresourcespl88.sharepoint.com/sites/DLRRecruitmentOps570 --folder "BGV Records/Dashboard" --path ".\out\dashboard\BGV Dashboard.xlsx" --overwrite
```

## Important Practical Notes

- No Power Automate flow was required for this dashboard.
- The recruiter workbook is intentionally a snapshot-style build, not a live self-refreshing reporting app.
- Standard Excel filters are used on the `Cases` sheet instead of slicers.
- The implementation guide is meant to be readable without needing to know every Excel COM detail.
- If you want an immediate refresh outside the schedule, run:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\active\run_bgv_dashboard_refresh.ps1
```
