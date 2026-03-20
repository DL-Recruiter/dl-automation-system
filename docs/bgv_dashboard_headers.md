# BGV Dashboard Headers

This document explains the condensed recruiter table in `BGV Dashboard.xlsx`.

The workbook is intentionally lean so recruiters can scan cases quickly.

## Recruiter Table Headers

The main recruiter table is on the `Cases` sheet.

It currently uses these headers:

| Header | What recruiters should use it for | Logic / source |
| --- | --- | --- |
| `Candidate Name` | Quick candidate identification. | `BGV_Candidates.FullName` |
| `CandidateID` | Main case identifier for tracking and folder lookup. | `BGV_Candidates.CandidateID` / linked request rows |
| `RequestID` | Employer-request identifier for one employer slot. | `BGV_Requests.RequestID` |
| `Company Name` | Employer/company being verified. | `BGV_FormData.F1_EmployerName`, fallback `BGV_Requests.EmployerName` |
| `HR Name` | Employer HR contact person. | `BGV_FormData.F1_HRContactName` |
| `HR Email` | Employer HR email for follow-up. | `BGV_FormData.F1_HREmail`, fallback `BGV_Requests.EmployerHR_Email` |
| `HR Mobile Number` | Employer HR mobile/contact number. | `BGV_FormData.F1_HRMobile` |
| `Status` | Single recruiter-facing case stage across authorization and employer verification. | Derived from candidate authorization state plus `BGV_Requests.VerificationStatus` |
| `Candidate Reminder` | Whether a candidate reminder has been sent and when. | `BGV_Candidates.LastAuthReminderAt` |
| `Employer Reminder` | Latest employer reminder stage and timestamp. | Latest of `Reminder1At`, `Reminder2At`, `Reminder3At`, with fallback wording from request status |
| `Overdue` | Quick overdue flag for chasing. | `Yes` when auth is unsigned after 5 days, send date has passed with no employer email, reminder 2/3 has been reached, or the case is escalated |
| `Completed Status` | Whether the employer-side cycle is completed. | `Yes` when `BGV_Requests.VerificationStatus = Responded`; otherwise `No` |
| `Employer Response Received At` | Timestamp of completed employer response. | `BGV_Requests.ResponseReceivedAt` |
| `Last Activity At` | Latest known case activity for sorting and recency checks. | Max of key candidate/request/reminder/response timestamps |
| `Severity` | Reported risk level from employer response. | `BGV_Requests.Severity` |
| `Outcome` | Short result/flag summary from employer response. | `BGV_Requests.Outcome` |

## `Status` Logic

`Status` is the main condensed recruiter stage column.

It maps the case journey like this:

| Status value | When it appears |
| --- | --- |
| `Candidate Form Received` | Candidate declaration exists but the authorization form has not been generated/sent yet |
| `Authorisation Form Sent` | Authorization link exists but candidate signature is not yet confirmed |
| `Authorisation Form Received` | Candidate signature is confirmed and employer email is ready to go now |
| `Authorisation Received - Employer Email Queued` | Candidate signature is confirmed, but the employer email is being held until `SendAfterDate` |
| `Email Sent to Employer` | Employer verification email has been sent and no reminder has gone yet |
| `Employer Reminder 1 Sent` | First employer reminder has been sent |
| `Employer Reminder 2 Sent` | Second employer reminder has been sent |
| `Employer Reminder 3 Sent` | Third employer reminder has been sent |
| `Employer Form Received` | Employer form response has been received and processed |

## Reminder Columns

The workbook keeps reminders simple for recruiters:

- `Candidate Reminder`
  - `Not sent`
  - or `1: yyyy-mm-dd hh:mm`
- `Employer Reminder`
  - `Not sent`
  - `1: yyyy-mm-dd hh:mm`
  - `2: yyyy-mm-dd hh:mm`
  - `3: yyyy-mm-dd hh:mm`

## Summary Sheet

The `Summary` sheet is a pivot-style recruiter overview of the same table.

It includes:

- small KPI cards
- a status count table
- an overdue count table
- a completed count table

This keeps the first sheet easy to read without forcing recruiters into a full Excel PivotTable workflow.
