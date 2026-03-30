# BGV Dashboard Power Automate Redesign

## Purpose
This document defines the safest path to convert the current recruiter dashboard from a local PowerShell + Excel COM snapshot build into a cloud-refreshable dashboard maintained by Power Automate and Excel Online (Business).

This is a redesign, not a patch. The current builder rebuilds workbook structure from scratch. The target design keeps workbook structure stable and lets Power Automate update table rows only.

## Current Constraints
- The current workbook builder depends on local Excel COM automation.
- A standard cloud Power Automate flow cannot run the current builder.
- Excel Online (Business) works best with named tables, not arbitrary worksheet ranges or layout rebuilds.
- SharePoint file locking is currently the main operational risk with the local rebuild/upload model.

## Target Design Summary
- Keep the workbook in SharePoint.
- Stop rebuilding workbook layout during refresh.
- Use stable Excel tables only.
- Use a new scheduled cloud flow to clear and repopulate dashboard table rows.
- Preserve the existing recruiter-facing layout as closely as possible.
- Remove `Overdue`.
- Preserve current `Status` logic as closely as possible.

## A. Recommended Target Workbook Structure

### Workbook file
- Prototype / comparison workbook:
  - `out/dashboard/BGV Dashboard - Power Automate Prototype.xlsx`
- Intended future SharePoint workbook once approved:
  - `BGV Records/Dashboard/BGV Dashboard.xlsx`

### Sheet design
1. `Summary`
   - Recruiter-facing KPI cards and counts
   - Formula-driven from the main cases table
   - No raw imports written here by Power Automate

2. `Cases`
   - Main recruiter-facing dashboard table
   - One row per employer request slot / `RequestID`
   - Main table name:
     - `tblDashboardCasesPA`

3. `Helper`
   - Static lookup values for status and severity summaries
   - Hidden from normal users after go-live if desired
   - Tables:
     - `tblDashboardStatusLegend`
     - `tblDashboardSeverityLegend`

4. `RefreshLog`
   - Small operational log written by the refresh flow
   - Table:
     - `tblDashboardRefreshLog`

5. `Comparison`
   - Side-by-side explanation of current vs Power Automate-first design
   - Used only for rollout and user review

### Main table columns (`tblDashboardCasesPA`)
- `DashboardKey`
- `Candidate Name`
- `CandidateID`
- `RequestID`
- `Company Name`
- `HR Name`
- `HR Email`
- `HR Mobile Number`
- `Status`
- `Candidate Email Sent At`
- `Candidate Reminder`
- `Employer Email Sent At`
- `Employer Reminder`
- `Completed Status`
- `Employer Response Received At`
- `Employer Email Reply At`
- `Last Activity At`
- `Candidate Folder Link`
- `Severity`
- `Outcome`

### Notes on structure
- `DashboardKey` should be hidden in the visible worksheet after go-live.
- Recommended key value:
  - `CandidateID|RequestID`
- `Overdue` is intentionally removed from the target design.
- Summary formulas should read from `tblDashboardCasesPA` only.
- Power Automate should update only data rows, not sheet layout.

## B. Mapping Plan

### Source lists
- `BGV_Candidates`
- `BGV_Requests`
- `BGV_FormData`

### Row grain
- One dashboard row per request / employer slot
- Primary row source:
  - `BGV_Requests`
- Candidate and form-data fields joined by:
  - `CandidateID`
  - `RequestID`

### SharePoint to dashboard mapping

| Dashboard column | Primary source | Mapping |
| --- | --- | --- |
| `DashboardKey` | Derived | `CandidateID & "|" & RequestID` |
| `Candidate Name` | `BGV_Candidates` / fallback `BGV_FormData` | Candidate full name |
| `CandidateID` | `BGV_Requests` | direct |
| `RequestID` | `BGV_Requests` | direct |
| `Company Name` | `BGV_Requests` / fallback `BGV_FormData` | employer / company name |
| `HR Name` | `BGV_FormData` | Form 1 HR contact name |
| `HR Email` | `BGV_Requests` / fallback `BGV_FormData` | employer email |
| `HR Mobile Number` | `BGV_FormData` | Form 1 HR mobile |
| `Status` | Derived | current dashboard status logic preserved |
| `Candidate Email Sent At` | `BGV_Candidates` | `AuthorizationLinkCreatedAt` (SGT) |
| `Candidate Reminder` | Derived | from `LastAuthReminderAt` |
| `Employer Email Sent At` | `BGV_Requests` | `HRRequestSentAt` (SGT) |
| `Employer Reminder` | Derived | from `Reminder1At`, `Reminder2At`, `Reminder3At` |
| `Completed Status` | Derived | `Yes` when `VerificationStatus = Responded`, else `No` |
| `Employer Response Received At` | `BGV_Requests` | `ResponseReceivedAt` |
| `Employer Email Reply At` | `BGV_Requests` | `EmployerEmailReplyAt` |
| `Last Activity At` | Derived | latest relevant timestamp |
| `Candidate Folder Link` | Derived | `https://dlresourcespl88.sharepoint.com/sites/DLRRecruitmentOps570/BGV%20Records/Candidate%20Files/<CandidateID>/` |
| `Severity` | `BGV_Requests` / fallback `BGV_FormData` | direct |
| `Outcome` | `BGV_Requests` / fallback `BGV_FormData` | direct |

### Status derivation logic
Preserve current logic from `build_bgv_dashboard.ps1`:

1. If no `AuthorizationLinkCreatedAt`
   - `Candidate Form Received`
2. Else if authorization not signed
   - `Authorisation Form Sent`
3. Else if `VerificationStatus = Responded`
   - `Employer Form Received`
4. Else if `VerificationStatus = Reminder 3 Sent`
   - `Employer Reminder 3 Sent`
5. Else if `VerificationStatus = Reminder 2 Sent`
   - `Employer Reminder 2 Sent`
6. Else if `VerificationStatus = Reminder 1 Sent`
   - `Employer Reminder 1 Sent`
7. Else if `VerificationStatus = Email Sent`
   - `Email Sent to Employer`
8. Else if `VerificationStatus` is blank or `Not Sent`
   - if `SendAfterDate > today`
     - `Authorisation Received - Employer Email Queued`
   - else
     - `Authorisation Form Received`
9. Else
   - `In Progress`

### Candidate reminder derivation
- If `LastAuthReminderAt` is blank:
  - `Not sent`
- Else:
  - `1: yyyy-MM-dd HH:mm`

### Employer reminder derivation
- If `Reminder3At` exists:
  - `3: yyyy-MM-dd HH:mm`
- Else if `Reminder2At` exists:
  - `2: yyyy-MM-dd HH:mm`
- Else if `Reminder1At` exists:
  - `1: yyyy-MM-dd HH:mm`
- Else:
  - `Not sent`

### Completed logic
- `Completed Status = Yes` when:
  - `VerificationStatus = Responded`
- Else:
  - `Completed Status = No`

### Last activity logic
Take the latest non-empty value from:
- `EmployerEmailReplyAt`
- `ResponseReceivedAt`
- `Reminder3At`
- `Reminder2At`
- `Reminder1At`
- `HRRequestSentAt`
- `Authorization Signed At`
- `LastAuthReminderAt`
- request modified timestamp
- candidate modified timestamp
- form-data modified timestamp

### Severity logic
Keep the current request-side value:
- `Neutral`
- `Low`
- `Medium`
- `High`
- blank allowed

### Outcome logic
Keep the current request-side `Outcome` value exactly as stored.

## C. Power Automate Design

### Flow name
- Recommended:
  - `BGV_9_Refresh_Dashboard_Excel`

### Trigger
- `Recurrence`

### Schedule
- Every 3 hours between `09:00` and `21:00` Singapore time
- Recommended fixed run times:
  - `09:00`
  - `12:00`
  - `15:00`
  - `18:00`
  - `21:00`

### Core actions
1. Get items from `BGV_Candidates`
2. Get items from `BGV_Requests`
3. Get items from `BGV_FormData`
4. Compose lookup objects keyed by:
   - `CandidateID`
   - `RequestID`
5. Build a master row array using the same status/reminder logic as the current dashboard builder
6. Excel Online (Business):
   - `List rows present in a table` for `tblDashboardCasesPA`
   - delete existing rows
   - add new rows from master row array
7. Excel Online (Business):
   - update `tblDashboardRefreshLog` with:
     - refresh timestamp
     - refresh mode
     - row count

### Duplicate prevention
- Use full-table refresh for `tblDashboardCasesPA`
- Do not append blindly
- `DashboardKey` stays the logical unique key

### Why full refresh is the simplest viable design
- The row count is moderate
- It avoids stale rows for deleted/closed items
- It avoids complicated upsert logic across Excel Online connector limits

### Recommended workbook references
- File:
  - `BGV Records/Dashboard/BGV Dashboard.xlsx`
- Table:
  - `tblDashboardCasesPA`
- Refresh log table:
  - `tblDashboardRefreshLog`

## D. Migration Plan

### Phase 1: comparison and design approval
1. Keep the current dashboard unchanged
2. Create a separate prototype workbook
3. Review layout differences with users

### Phase 2: workbook conversion
1. Create stable workbook structure in SharePoint
2. Remove local raw-sheet rebuild dependency from runtime refresh
3. Keep the old PowerShell builder only as fallback/manual backup

### Phase 3: cloud refresh flow
1. Build `BGV_9_Refresh_Dashboard_Excel`
2. Point it at the new stable workbook tables
3. Test against live SharePoint data

### Phase 4: cutover
1. Freeze old dashboard refresh job
2. Enable cloud refresh flow
3. Monitor row counts and summary counts
4. Retain old builder scripts for rollback/manual backup

### Old local components that become obsolete for runtime
- `scripts/active/run_bgv_dashboard_refresh.ps1`
- `scripts/active/register_bgv_dashboard_refresh_task.ps1`
- scheduled Windows task `DLR BGV Dashboard Refresh`

### What can remain as backup/manual use
- `scripts/active/build_bgv_dashboard.ps1`
- manual refresh runner
- current local workbook artifact generation

## E. Acceptance Criteria
- Dashboard refreshes without the local PC
- Workbook remains in SharePoint
- Dashboard layout remains close to the current Summary/Cases design
- `Overdue` is removed
- Current `Status` logic is preserved as closely as possible
- `Employer Email Reply At` remains visible
- Summary formulas still work
- One dashboard row represents one request / employer slot
- Refresh flow is safe to rerun and does not create duplicates

## Prototype Artifact
- Local comparison workbook:
  - `out/dashboard/BGV Dashboard - Power Automate Prototype.xlsx`

This prototype exists to show the workbook structure needed for a Power Automate-first refresh model before any live dashboard cutover.
