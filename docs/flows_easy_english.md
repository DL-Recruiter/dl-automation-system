# BGV Flows in Simple English

This document describes the current behavior in your canonical flow files under `flows/power-automate/unpacked/Workflows/`.

## Quick End-to-End Story (Current State)
1. Candidate submits the declaration form.
2. The system creates candidate records, authorization files, employer request rows, and normalized `BGV_FormData` rows.
3. Candidate receives a signature email and signs the authorization document.
4. Signature is detected automatically and candidate status is updated.
5. Pending employer requests are sent out with a prefilled HR form link and signed authorization attachment.
6. Employer submits the HR verification form.
7. The response is scored for severity, request records are updated, and alerts are sent if needed.
8. A report summary document is generated per employer response and saved back into the candidate folder.
9. Scheduled reminder flows chase unsigned candidate forms and unanswered employer requests.

## Flow-by-Flow Explanation

### `BGV_0_CandidateDeclaration`
- Trigger: New response in candidate declaration Microsoft Form.
- What it does:
  - Creates `CandidateID`.
  - Creates candidate folder and authorization subfolder in SharePoint.
  - Creates candidate row in `BGV_Candidates`.
  - Generates and saves authorization `.docx` from the target-site template in `DLR Recruitment Ops > BGV Records > Templates > DLRAuthorizationLetter_Template.docx`, then shares it and emails candidate.
  - The authorization link is created as an anonymous edit link so the candidate can open and edit the Word document directly, even outside the organisation.
  - When filling the authorization Word template ID content controls:
    - NRIC control gets the last 5 cleaned alphanumeric characters from the candidate's full NRIC, else `N/A`.
    - Passport control gets `N/A` when NRIC exists; otherwise the last 5 cleaned alphanumeric characters from the candidate's full Passport, else `N/A`.
  - The full submitted NRIC/passport values are still stored in SharePoint lists and `BGV_FormData`; only the authorization document is masked down to the last 5 characters.
  - Authorization template includes a bottom checkbox line `Yes, I authorized` using content-control tag `SignedYes`.
  - Updates candidate status to pending signature.
  - Creates `BGV_Requests` rows for EMP1 always, and EMP2/EMP3 when those employer sections are filled.
  - Before creating each EMP slot row, checks whether that same slot RequestID already exists to avoid duplicate inserts.
  - Creates `BGV_FormData` rows (`EMP1`, optional `EMP2`, optional `EMP3`) with normalized candidate/employer fields and raw Form 1 payload.
  - For `EMP1`, also writes `F1_SendAfterDate` into `BGV_FormData` when the candidate selected the current-employer defer option and provided an employment end date.
  - Writes Form 1 reason-for-leaving per slot into `BGV_FormData.F1_ReasonForLeaving`:
    - EMP1 <- E1 reason key
    - EMP2 <- E2 reason key
    - EMP3 <- E3 reason key
  - Uses Request IDs in format:
    - `REQ-<CandidateID>-EMP1`
    - `REQ-<CandidateID>-EMP2`
    - `REQ-<CandidateID>-EMP3`
  - Sets `SendAfterDate` for EMP1 using the Form 1 defer rule:
    - if Q17 is `Yes`, uses `E1 - Employment Period End Date`
    - otherwise uses `utcNow()`
  - Sets `SendAfterDate` as `utcNow()` for EMP2/EMP3 request rows.
  - Sends candidate email via `Send an email from a shared mailbox (V2)` from `recruitment@dlresources.com.sg`.
  - Candidate authorization email body now uses personalized salutation (`Dear <Candidate Name>`) and explicit signing instructions while preserving dynamic name/link expressions, including a note that a copy of the signed form will be emailed to the candidate later.
- Main outcome: Candidate onboarding data, request tracking, and structured Form 1 data are prepared in one run.

### `BGV_1_Detect_Authorization_Signature`
- Trigger: SharePoint file created or modified.
- Gate checks:
  - File must be under candidate authorization folder path.
  - File name must match `Authorization Form - ... .docx`.
- What it does:
  - Extracts `CandidateID` from file name.
  - Loads matching candidate record from the `DLR Recruitment Ops` site `BGV_Candidates` list.
  - Sends file content to Azure Function parser.
  - Parser now scans checkbox content controls across main document, header, footer, glossary, footnote, and endnote parts.
  - Reads parser output directly and does tolerant signature checks.
  - Filters parsed controls by tag/title containing `SignedYes` (and compatibility fallback `CandidateAuthorisation`).
  - Marks signed when a matched `SignedYes` checkbox is actually checked.
  - Uses parser `signedYes = true` only as a fallback for legacy cases where no matching checkbox controls are returned at all.
  - If signed, updates candidate record:
    - `AuthorisationSigned = true`
    - consent/status fields for signed authorization.
  - Immediately stops sharing the current authorization file after signature detection succeeds, so the candidate link expires right away.
- Main outcome: Signed authorization is detected and candidate is marked as signed without manual review.

### `BGV_2_Postsignature`
- Trigger: Candidate item created or modified.
- Condition: candidate status is `Obtained Authorization Form Signature`.
- What it does:
  - Builds the candidate authorization folder path cleanly before listing files.
  - Acts as the post-signature file cleanup/lock pass after the candidate has already been marked signed.
  - Finds related files only inside the candidate's own authorization folder.
  - Reads each authorization `.docx` and sends it to `LockAuthorizationControls` function.
  - Overwrites the same file content with the function-returned locked DOCX (content controls set to non-editable/non-deletable).
  - Stops sharing for those files.
- Main outcome: Signed authorization files are locked against Developer-mode content-control edits and are no longer broadly shared.

### `BGV_3_AuthReminder_5Days`
- Trigger: Hourly recurrence with Singapore-time slot gating.
- What it does:
  - Gets candidates with `Status = Pending Authorization Form Signature`.
  - Computes days since authorization link creation using Singapore local calendar days.
  - Uses the live candidate item state (`Status` + `AuthorisationSigned`) at send time, so reminder checks happen against the current signed-status update rather than stale earlier values.
  - Schedules reminders at these local Singapore times:
    - same day as authorization send: one reminder at `9:05 PM` only if the authorization link was created before `9:00 PM`
    - local days 2 and 3 after send: two reminders per day at `9:05 AM` and `9:05 PM`
    - local days 4 and 5 after send: one reminder per day at `9:05 AM`
  - Uses `LastAuthReminderAt` consistently to avoid duplicate reminders in the same reminder slot.
  - Reminder updates only stamp `LastAuthReminderAt`; they do not change candidate status to signed/obtained.
  - Reminder update no longer flips `ConsentCaptured`; it only stamps reminder timestamp fields.`\n  - Outer reminder gate now checks `AuthorisationSigned` instead of `ConsentCaptured` so stale consent flags do not block pending reminders.
  - Day-5 escalation now runs independently of whether a same-day reminder email was sent, so stale `LastAuthReminderAt` values do not suppress escalation.
  - Day-5 escalation is limited to the `9:05 AM` slot so the hourly recurrence does not spam repeated alerts.
  - Day-5 escalation email now uses current candidate item values directly and still sends even if the Teams post step fails.
  - On day 5 unresolved cases, posts Teams escalation to `DLR Recruitment Ops > BGV` and sends internal escalation email to `recruitment@dlresources.com.sg`.
  - Email sends are routed via shared mailbox `recruitment@dlresources.com.sg`.
- Main outcome: Unsigned candidate authorization forms are actively chased and escalated.

### `BGV_Candidates` field usage snapshot
- `JobTitle`
  - Not used by the current canonical flows.
- `ConsentCaptured`
  - No longer written by the canonical flows.
  - Treat as a legacy field only if it still exists in older rows/views.
- `ConsentEvidence`
  - Not used by the current canonical flows.
- `IDTypeProvided`
  - Written by `BGV_0` as:
    - `NRIC` when the candidate filled the NRIC field in Form 1
    - otherwise `Passport`
- `AuthorizationLinkExpiredAt`
  - Not used by the current canonical flows.

### `BGV_4_SendToEmployer_Clean`
- Active production flow note:
  - Use `BGV_4_SendToEmployer_Clean`.
  - `BGV_4_SendToEmployer_Clean_v2` is a parked replacement draft and remains off; it is not the live production sender.
- Trigger: Recurrence every 30 minutes.
- Selection:
  - Reads `BGV_Requests` where `VerificationStatus = Not Sent` and `HRRequestSentAt` is null.
- What it does (per request):
  - Loads candidate row by `CandidateID` and treats `AuthorisationSigned` as signed when value is boolean/string true.
  - Loads matching `BGV_FormData` row by `RequestID`.
  - Applies the `SendAfterDate` gate only to EMP1:
    - EMP1 sends only when `SendAfterDate` is today or earlier
    - EMP2 and EMP3 are not blocked by the defer date
  - Builds prefilled HR verification form URL with:
    - Candidate name
    - Candidate NRIC mapped into the HR form NRIC field; when NRIC is absent it shows `N/A`
    - Candidate Passport mapped into the HR form Passport field; when NRIC is present it shows `N/A`
    - Request ID
    - Employer name
    - Employer UEN
    - Employer address
    - Employment period
    - Last drawn salary
    - Job title
    - Company-stamp document link (`rd5d9cb98b1aa47dd8bcd7914cd4bdc87`) pointing to an employer-specific shared Word document.
  - Creates an employer-specific request folder in `BGV Records/Candidate Files/<CandidateID>/<RequestID>`.
  - Creates or reuses `Company Stamp - <RequestID>.docx` inside that request folder from `BGV Records/Templates/Company Stamp.docx`.
  - Creates an anonymous edit sharing link for that employer-specific company-stamp document and injects it into the prefilled Form 2 key for stamp collection.
  - Uses the matching `BGV_FormData` row as the first source for company name/address/UEN in the employer email body, so EMP1/EMP2/EMP3 show the correct declared company details.
  - Employer email now includes the Request ID and the direct shared company-stamp Word-document link, and politely asks HR to place the company stamp into that Word document and save it back using the shared link.
  - Employer email subject/body wording is synced to the latest cloud-edited template while preserving the existing dynamic mappings for declared-details, verification-link, and authorization-attachment sections.
  - Employer email wording now also tells the employer to reply to the email or include the `RequestID` in the subject line when they need more information, so mailbox replies can be matched safely.
  - Finds authorization file, attaches it, and emails employer HR.
  - Sends the signed authorization attachment to the candidate email (`BGV_Candidates.CandidateEmail`) for reference only once per candidate, on the `EMP1` request, so candidates with multiple employers do not receive duplicate copies.
  - Email sends are routed via shared mailbox `recruitment@dlresources.com.sg`.
  - Employer email subject now uses the mapped dynamic company field.
  - Employer email wording uses dynamic candidate/company values while preserving the existing declared-details and verification-link sections.
  - Recipient email resolution is guarded:
    - use `BGV_FormData.F1_HREmail` when it is email-formatted
    - else use `BGV_Requests.EmployerHR_Email` when it is email-formatted
    - else fallback to `dlresplmain@dlresources.com.sg` to avoid runtime send failure.
  - Updates request row:
    - `VerificationStatus = Email Sent`
    - `HRRequestSentAt = utcNow()`
    - `LinktoEmployers = FinalVerificationLink`
  - `LinkDue` is a SharePoint calculated column, not a flow-written field and not used by any canonical flow:
    - `Due` when `SendAfterDate` is blank
    - `Due` when `SendAfterDate <= Today`
    - `Not Due` when `SendAfterDate > Today`
- Main outcome: Only signed-authorized candidates are sent to employer HR, with rich prefill context.

### `BGV_5_Response1`
- Trigger: New response in employer HR verification Microsoft Form.
- Matching:
  - Looks up `BGV_Requests` by `startswith(RequestID, <submitted RequestID>)`.
  - Looks up `BGV_FormData` by exact `RequestID`.
- What it does:
  - Initializes scoring variables (`Severity`, `Outcome`, notify flags).
  - Applies risk logic:
    - MAS misconduct not `No / Not Applicable` -> High.
    - Disciplinary issue `Yes` -> High.
    - Employer would not re-employ (`Q26 = No`) -> High.
    - Employment details inaccurate (`Q15 = No`) -> Medium if no higher severity already set.
    - Company details inaccurate (`Q8 = No`) -> Low if no higher severity already set.
    - Other comments (`Q27`) -> Neutral if no higher severity already set.
    - Contact requested -> action-required notify flag.
  - Writes final result to `BGV_Requests`:
    - `VerificationStatus = Responded`
    - `ResponseReceivedAt`
    - `Severity`, `Outcome`, `BGV Checks`, `Notes`
  - Expires employer upload access when HR has responded:
    - locates `BGV Records/Candidate Files/<CandidateID>/<RequestID>`
    - runs `Stop sharing` (`UnshareItem`) on that request folder.
  - `Outcome` now stores the combined flagged items detected from Form 2:
    - selected company-detail discrepancies from `Q9`
    - selected employment-detail discrepancies from `Q16`
    - `MAS` when the MAS answer is not `No / Not Applicable`
    - `Disciplinary` when disciplinary action is `Yes`
    - `Re-employ` when re-employ is `No`
    - `Other Comments` when `Q27` is filled
  - `BGV Checks` is set to:
    - `Form Filled and Cleared` when the employer has responded and severity is blank or `Neutral`
    - `Adverse BGV Checks - see severity` when the employer has responded and severity is `Low`, `Medium`, or `High`
  - If FormData row exists, updates `BGV_FormData` with Form 2 raw payload + normalized Form 2 result fields, including:
    - `F2_CompanyDetailsAccurate`
    - `F2_CompanyDetailsSelectedIssues`
    - `F2_MASQuestion`
    - `F2_DisciplinaryAction`
    - `F2_ContactForClarification`
    - `F2_OtherComments`
    - `F2_FormCompleterName`
    - `F2_FormCompleterJobTitle`
    - `F2_FormCompleterContactDetails`
    - `F2_CompanyStampFileName`
    - `F2_ReasonForLeaving`
  - `Form2RawJson` stores the full submitted Form 2 payload, not just the normalized subset.
  - For the low-severity inaccurate-information section, the detailed email/details block now only shows the explanation headings for the options that were actually selected.
  - Notes now add one shared line, `Please refer to the report summary for additional comments.`, when any mapped long-comment field is filled.
  - That shared note line is only added once, even when multiple mapped comment fields are filled, including `Q27` other comments.
  - Company-details discrepancy answers are now also copied into notes storage when present:
    - company-details accuracy
    - selected inaccurate company-detail fields
    - company-details explanation
  - Keeps required SharePoint fields (including `Title`) when updating `BGV_FormData`, preventing save/runtime validation errors.
  - Sends Teams alert when notify flag is true.
  - Sends internal high-severity email when severity is `High`, including employer name and employer HR email in the body.
  - Recruiter-facing BGV_5 emails now include `EmployerName` in the email body context and tell recruiters where to find the later report summary under `BGV_Records > Candidate Files (<CandidateID>)`.
  - All email notifications in this flow are routed via shared mailbox and addressed to `recruitment@dlresources.com.sg`.
  - Teams notification target for this flow is `DLR Recruitment Ops > BGV`:
    - `groupId = 4475a565-7f2b-4df1-91cd-c8e3df8f805a`
    - `channelId = 19:01523cb936ce49fca3e80d2ee293da6a@thread.tacv2`
- Main outcome: Employer response is automatically triaged, stored, and escalated when needed.

### `BGV_6_HRReminderAndEscalation`
- Trigger: Every 30 minutes, but reminder processing only runs during Singapore time windows at `9:00 AM` and `5:30 PM`.
- Selection baseline: requests with `HRRequestSentAt` present and `ResponseReceivedAt` still empty.
- Reminder/escalation timeline:
  - Reminder 1: when HR request is at least 2 days old.
  - Reminder 2: 3+ days after Reminder 1.
  - Escalation post to recruiters: 1+ day after Reminder 2 with no response.
  - Final reminder: when HR request is 11+ days old and `Reminder3At` is empty.
- What it updates:
  - Reminder timestamps (`Reminder1At`, `Reminder2At`, `Reminder3At`)
  - `EscalatedAt` when the recruiter escalation post is sent
  - `BGV Checks`:
    - `No response at Reminder 2` one day after reminder 2 has been sent
    - `Form Filled and Cleared` once reminder 3 is sent and there is still no response
  - `VerificationStatus` lifecycle:
    - `Reminder 1 Sent`
    - `Reminder 2 Sent`
    - `Reminder 3 Sent`
  - Shared-mailbox reminder emails
  - Teams escalation message for unresolved cases
  - Teams escalation destination:
    - `groupId = 4475a565-7f2b-4df1-91cd-c8e3df8f805a`
  - `channelId = 19:01523cb936ce49fca3e80d2ee293da6a@thread.tacv2`
  - Shared-mailbox sender is `recruitment@dlresources.com.sg`.
  - Reminder conditions now use `empty(...)`-safe checks for SharePoint date fields so null/blank timestamps do not block reminder branches unexpectedly.
- Reminder conditions/messages resolve values from the current request row (`items('Apply_to_each')`) so logic works even when earlier reminder update actions are skipped in that run.
- Reminder emails now rebuild the same employer `FinalVerificationLink` used by `BGV_4`, including the employer-specific shared company-stamp document link, so reminders still contain the current Microsoft Form URL even when the legacy `uniquelinktoemployers` SharePoint field is blank.
- Escalation now stamps `EscalatedAt`, so the same unresolved request is not escalated again on every later run.
- When Reminder 3 is sent, the flow also saves an HTML copy of that final reminder email into the same request folder under the candidate folder for audit/reference.
- Adds close-window upload-link expiry for no-response cases:
  - when `Reminder3At` is 5+ days old and `ResponseReceivedAt` is still empty
  - finds request folder `BGV Records/Candidate Files/<CandidateID>/<RequestID>`
  - stops sharing that folder (`UnshareItem`).
- Main outcome: Employer follow-up is systematic, time-based, and auditable.

### `BGV_7_Generate_Report_Summary`
- Trigger: Recurrence every 30 minutes.
- Selection:
  - Reads `BGV_Requests` where `VerificationStatus = Responded`.
  - Only continues for rows with a non-empty `ResponseReceivedAt` and a `RequestID` ending in an employer slot such as `EMP1`.
- What it does:
  - Reads the live Word template by path:
    - `DLR Recruitment Ops > BGV Records > Templates > ReportSummary_Template.docx`
  - Loads the matching `BGV_FormData` row by exact `RequestID`.
  - Requires non-empty `Form2RawJson` from `BGV_FormData`.
  - Uses `Form1RawJson` when present, and falls back to normalized `BGV_FormData` Form 1 fields when `Form1RawJson` is blank:
    - `F1_CandidateFullName`
    - `F1_CandidateEmail`
    - `F1_IDNumberNRIC`
    - `F1_IDNumberPassport`
  - Sends the template plus employer raw JSON and Form 1 data to the Azure Function endpoint `FillReportSummaryControls`.
  - For Employment Details discrepancy boxes, the mapper:
    - uses the specific employer discrepancy fields when they are present
    - falls back to the general employer inaccuracy-comments field when a selected discrepancy field is blank
  - The Azure Function fills Word content controls by live template tag, including:
    - Form 1 candidate basics:
      - `Form1.CandidateFullName`
      - `Form1.CandidateEmail`
      - `Form1.IdentificationNumberNRIC`
      - `Form1.IdentificationNumberPassport`
    - Form 2 report summary fields:
      - `Form2.Q4` through `Form2.Q31`
      - `Form2.Q31FileName`
  - Saves one report per employer slot into the candidate folder:
    - `RS_Emp1.docx`
    - `RS_Emp2.docx`
    - `RS_Emp3.docx`
  - Candidate folder path used:
    - `BGV Records/Candidate Files/<CandidateID>/`
  - If the report already exists, updates the file content in place.
  - If the report does not exist yet, creates it and checks one-time post flags before posting to Teams.
  - Teams post (`Report Summary Created`) only sends when both `BGV_Requests.Report Summary Teams Posted At` and `BGV_FormData.Report Summary Teams Posted At` are blank.
  - After a successful Teams post, flow stamps both fields with current UTC time so it will not post that same report summary again.
- Main outcome: Each completed employer verification now gets a report-summary DOCX generated from the real SharePoint template and stored in the correct candidate folder.

### `BGV_8_Track_Employer_Email_Replies`
- Trigger: `When a new email arrives (V3)` on the recruitment mailbox inbox.
- Purpose:
  - Detects employer reply emails and stores the latest reply timestamp in both `BGV_Requests` and `BGV_FormData`.
  - Posts a Teams notification to `DLR Recruitment Ops > BGV` when a unique employer reply is detected and written back successfully.
- Matching logic:
  - Primary match: `RequestID` found anywhere in the email subject.
  - Fallback match: exact sender-email match against `BGV_Requests.EmployerHR_Email`.
  - Only proceeds when there is exactly one safe matching request and exactly one matching `BGV_FormData` row.
  - If the match is missing or ambiguous, the flow skips without changing records.
- Update logic:
  - Writes `EmployerEmailReplyAt` into both lists.
  - If multiple replies are received later, the flow keeps only the most recent detected reply timestamp.
  - After both list updates succeed, posts the reply details:
    - `Request ID`
    - `Candidate ID`
    - `Employer`
    - sender email
    - received timestamp
    - subject

### `BGV_9_Refresh_Dashboard_Excel`
- Trigger: Recurrence five times a day in Singapore time:
  - `9:00 AM`
  - `12:00 PM`
  - `3:00 PM`
  - internal cadence trigger: every 30 minutes
  - execution window gate (SGT): `8:00 AM`, `9:30 AM`, `11:00 AM`, `12:30 PM`, `2:00 PM`, `3:30 PM`, `5:00 PM`, `6:30 PM`, `8:00 PM`, `9:00 PM`
- Purpose:
  - Keeps the Power Automate-friendly dashboard workbook refreshed in SharePoint without depending on the local PC.
  - Writes into:
    - `BGV Records/Dashboard/BGVDashboard_FLow.xlsx`
- What it does:
  - Reads all rows from:
    - `BGV_Candidates`
    - `BGV_Requests`
    - `BGV_FormData`
  - Clears the existing Excel table:
    - `tblDashboardCasesPA`
  - Rebuilds one dashboard row per `RequestID`
  - Uses Singapore time (`SGT`) formatting for dashboard date/time display fields.
  - Applies dashboard row-retention cleanup by skipping rows when:
    - `Reminder 3 Sent` and no response for `>= 5 days` after `Reminder3At`
    - `Completed` cases (`Employer Form Received` / `Employer Form Received But Flagged`) for `>= 5 days` after `ResponseReceivedAt`
  - Writes recruiter-facing dashboard columns:
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
    - `Completed Date`
    - `Employer Response Received At`
    - `Employer Email Reply At`
    - `Last Activity At`
    - `Severity`
    - `Outcome`
  - Appends a run entry into:
    - `tblDashboardRefreshLog`
    - timestamp value is written as `Run At (SGT)`
    - includes summary metrics:
      - `Total Requests`
      - `Active Cases`
      - `Cleared Cases`
      - `Closed Employer Form Received`
      - `Closed Employer Form Received But Flagged`
      - `Closed Reminder 3 Sent`
- Status logic:
  - Preserves the same recruiter-stage logic as the current local dashboard builder:
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
- Important note:
  - This refresh target is the comparison/live-flow workbook:
    - `BGVDashboard_FLow.xlsx`
  - The older local COM-based snapshot workbook:
    - `BGV Dashboard.xlsx`
    remains unchanged unless you choose to cut over later.

## How the Flows Connect
- Candidate signature track:
  - `BGV_0` -> `BGV_1` -> `BGV_2`
- Employer verification track:
  - `BGV_0` creates `BGV_Requests` + `BGV_FormData`
  - `BGV_4` sends prefilled HR request + attachment
  - `BGV_5` processes HR response and updates both lists
  - `BGV_8` tracks later employer reply emails and stamps the latest reply time into both lists
  - `BGV_7` generates the per-employer report summary DOCX from the completed Form 2 response
- Reminder/escalation track:
  - `BGV_3` for candidate signature delays
  - `BGV_6` for employer response delays
- Dashboard refresh track:
  - `BGV_9` refreshes `BGVDashboard_FLow.xlsx` from live SharePoint list data

## Notes
- This summary is based on the current unpacked canonical flow JSON in the repo.
- If cloud flows are changed in Power Automate but not exported/unpacked yet, cloud behavior may be newer than this file.





