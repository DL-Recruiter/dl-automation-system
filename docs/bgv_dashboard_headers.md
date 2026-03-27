# BGV Dashboard Headers

This document explains the recruiter table and summary logic for:

- `BGV Dashboard.xlsx` (legacy local snapshot workbook)
- `BGVDashboard_FLow.xlsx` (cloud-refreshed flow workbook)

The current operational dashboard is `BGVDashboard_FLow.xlsx`.

## Recruiter Table Headers (`Cases` sheet)

| Header | What recruiters should use it for | Logic / source |
| --- | --- | --- |
| `Candidate Name` | Quick candidate identification. | `BGV_Candidates.FullName` (fallback FormData candidate name) |
| `CandidateID` | Main case identifier for tracking and folder lookup. | `BGV_Requests.CandidateID` |
| `RequestID` | Employer-request identifier for one employer slot. | `BGV_Requests.RequestID` |
| `Company Name` | Employer/company being verified. | `BGV_FormData.F1_EmployerName`, fallback `BGV_Requests.EmployerName` |
| `HR Name` | Employer HR contact person. | `BGV_FormData.F1_HRContactName` |
| `HR Email` | Employer HR email for follow-up. | `BGV_FormData.F1_HREmail`, fallback `BGV_Requests.EmployerHR_Email` |
| `HR Mobile Number` | Employer HR mobile/contact number. | `BGV_FormData.F1_HRMobile` |
| `Status` | Single recruiter-facing case stage across authorization and employer verification. | Derived from candidate authorization state + request verification + severity |
| `Candidate Reminder` | Whether a candidate reminder has been sent and when. | `BGV_Candidates.LastAuthReminderAt` shown in SGT |
| `Employer Reminder` | Latest employer reminder stage and timestamp. | latest of `Reminder1At/2At/3At` shown in SGT |
| `Completed Status` | Whether the employer-side cycle is completed. | `Yes` when status is `Employer Form Received` or `Employer Form Received But Flagged` |
| `Completed Date` | Completion timestamp for employer-side cycle. | `ResponseReceivedAt` shown in SGT when completed, else blank |
| `Employer Response Received At` | Timestamp of completed employer response. | `BGV_Requests.ResponseReceivedAt` shown in SGT |
| `Employer Email Reply At` | Timestamp of latest inbound employer mailbox reply. | `BGV_Requests.EmployerEmailReplyAt` shown in SGT |
| `Last Activity At` | Latest known case activity for sorting and recency checks. | Max of key candidate/request/reminder/response timestamps shown in SGT |
| `Severity` | Reported risk level from employer response. | `BGV_Requests.Severity` |
| `Outcome` | Short result/flag summary from employer response. | `BGV_Requests.Outcome` |

## `Status` Logic

`Status` is the main recruiter stage:

- `Candidate Form Received`
- `Authorisation Form Sent`
- `Authorisation Form Received`
- `Authorisation Received - Employer Email Queued`
- `Email Sent to Employer`
- `Employer Reminder 1 Sent`
- `Employer Reminder 2 Sent`
- `Employer Reminder 3 Sent`
- `Employer Form Received`
- `Employer Form Received But Flagged` (when severity is `Low`, `Medium`, or `High`)

## Row Clearing Logic (`BGVDashboard_FLow`)

Rows are removed from the `Cases` table after 5 days when either condition is met:

- `Employer Reminder 3 Sent` and still no employer response
- completed case (`Employer Form Received` / `Employer Form Received But Flagged`) 5 days after `Completed Date`

## Summary Sheet (How To Read)

Key cards and counts:

- `Total Requests`: total rows in live `BGV_Requests` (includes active + cleared/closed)
- `Open Cases`: currently visible active rows in dashboard logic
- `Completed Cases`: active rows with completed status `Yes`
- `Closed Cases Report`:
  - `Closed Employer Form Received`
  - `Closed Employer Form Received But Flagged`
  - `Closed Reminder 3 Sent`
  - `Cleared Rows (Total)`

This keeps the recruiter view focused on active work while still tracking closed volume.

