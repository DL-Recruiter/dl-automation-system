# PEV Flows in Simple English

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
  - Candidate authorization email now also attaches `BGV Records > Templates > Instructions For Authorisation Form.pdf` so the candidate has a fixed PDF guide while completing the editable Word form.
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
  - If the lock function returns an empty or malformed response, it retries the lock call once before giving up.
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
  - Day-5 escalation now also requires `Day5Sent != true`, and the flow stamps `Day5Sent = true` after the alert email succeeds so the same candidate record is only escalated once.
  - Day-5 escalation email now uses current candidate item values directly and still sends even if the Teams post step fails.
  - On day 5 unresolved cases, posts Teams escalation to `DLR Recruitment Ops > BGV` and sends internal escalation email to `recruitment@dlresources.com.sg`.
  - Email sends are routed via shared mailbox `recruitment@dlresources.com.sg`.
- Main outcome: Unsigned candidate authorization forms are actively chased and escalated.

### Authorization Template Locking
- The live candidate authorization template is still:
  - `DLR Recruitment Ops > PEV Records > Templates > DLRAuthorizationLetter_Template.docx`
- `BGV_0_CandidateDeclaration` still points to that same live template file; it was not remapped to a different document.
- The template has been reverted back to the browser-editable version.
- The flow-critical controls were preserved:
  - `CandidateName`
  - `Identification Number NRIC`
  - `Identification Number Passport`
  - `Date`
  - `SignedYes`
- Because `SignedYes` is still present, `BGV_1_Detect_Authorization_Signature` can still detect the signed checkbox path it depends on.
- Word for the browser limitation:
  - if the document is protected in Word `forms` mode, users can be blocked from editing in the browser entirely
  - this means a true "some wording locked, rest editable in browser" setup is not reliable for your candidate flow
  - the live template therefore keeps `documentProtection enforcement="0"` so candidates can still open in browser, draw/sign, and tick the checkbox
- Practical outcome:
  - the correct template is still sent
  - browser editing works again
  - checkbox detection in `BGV_1` still works
  - but static wording is not hard-locked in Word for the browser

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
- Guardrail extension now added in the canonical flow:
  - before the employer send action, the flow checks the normalized submitted HR/reference email against the SharePoint list `Approved HR Reference Contacts`
  - found email -> continue send
  - not found or invalid/blank email -> do not send for that employer request
  - the flow posts a Teams action message to `DLR Recruitment Ops > BGV`, stamps request-side guardrail fields, and waits for the next recurrence run
  - after recruiters add the approved contact to the list, the same pending request will pass the lookup automatically on a later recurrence run and then send normally
  - this first implementation uses a Teams channel action message plus automatic retry; it does not yet use a blocking Teams Approvals card
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
  - Base URL: `https://forms.office.com/Pages/ResponsePage.aspx`
    - Candidate name
    - Candidate NRIC mapped into the HR form NRIC field; when NRIC is absent it shows `N/A`
    - Candidate Passport mapped into the HR form Passport field; when NRIC is present it shows `N/A`
    - Request ID
    - Employer name
    - Employer UEN
    - Employer address
    - Company-details accuracy / `Q8` is no longer prefilled to `Yes`; the employer must answer that field manually
    - Employment period
    - Last drawn salary
    - Job title
  - Company stamp Word document link (`rd5d9cb98b1aa47dd8bcd7914cd4bdc87`) pointing to the employer-specific shared Word document.
- Creates or reuses the employer-specific company-stamp Word document and injects its shared edit link into the prefilled Form 2 key.
  - Production note: the live working employer prefill path is `forms.office.com`; a later `forms.cloud.microsoft` variant opened the form but left the first-page values blank, so the flow was reverted to the proven `forms.office.com` base.
  - Uses the matching `BGV_FormData` row as the first source for company name/address/UEN in the employer email body, so EMP1/EMP2/EMP3 show the correct declared company details.
  - Employer email now includes the Request ID and the direct shared request-folder link, and asks HR to upload the company stamp or proof of HR contact into that folder.
  - Employer email subject/body wording is synced to the latest cloud-edited template while preserving the existing dynamic mappings for declared-details, verification-link, and authorization-attachment sections.
  - Employer email wording now also tells the employer to reply to the email or include the `RequestID` in the subject line when they need more information, so mailbox replies can be matched safely.
  - Finds authorization file, attaches it, and emails employer HR.
  - Sends the signed authorization attachment to the candidate email (`BGV_Candidates.CandidateEmail`) for reference only once per candidate, on the `EMP1` request, so candidates with multiple employers do not receive duplicate copies.
  - Candidate reference email wording is intentionally generic: it says employer emails will be sent based on the details the candidate provided, and it does not expose specific employer names or `RequestID` values to the candidate.
  - Email sends are routed via shared mailbox `recruitment@dlresources.com.sg`.
  - Employer email subject now uses the mapped dynamic company field.
  - Employer email wording uses dynamic candidate/company values while preserving the existing declared-details and verification-link sections.
  - Recipient email resolution is guarded:
    - use `BGV_FormData.F1_HREmail` when it is email-formatted
    - else use `BGV_Requests.EmployerHR_Email` when it is email-formatted
    - else fallback to `dlresplmain@dlresources.com.sg` to avoid runtime send failure.
  - Submitted HR/reference email guardrail:
    - flow composes the submitted employer HR/reference email from `BGV_FormData.F1_HREmail`, fallback `BGV_Requests.EmployerHR_Email`
    - flow normalizes that submitted value to lowercase trimmed text
    - flow looks up `Approved HR Reference Contacts.HRReferenceEmailNormalized` through a SharePoint HTTP request by list title
    - if no active approved-contact row matches, flow does not send the employer email in that run
    - instead it posts a Teams message to the BGV channel with candidate/employer/email details and the direct SharePoint list link
    - flow stamps request-side guardrail fields such as `ReferenceGuardrailStatus`, `ReferenceGuardrailCheckedAt`, `ReferenceGuardrailNotifiedAt`, and `ReferenceGuardrailLastEmailNormalized`
    - duplicate Teams guardrail posts are suppressed for the same pending request when the normalized email has not changed since the last notification
  - Updates request row:
    - `VerificationStatus = Email Sent`
    - `HRRequestSentAt = utcNow()`
    - `LinktoEmployers = FinalVerificationLink`
    - `ReferenceGuardrailStatus = Email found in approved list`
    - `ReferenceGuardrailCheckedAt = utcNow()`
    - `ReferenceGuardrailLastEmailNormalized = <normalized submitted HR/reference email>`
- `LinkDue` is a SharePoint calculated column, not a flow-written field and not used by any canonical flow:
    - `Due` when `SendAfterDate` is blank
    - `Due` when `SendAfterDate <= Today`
    - `Not Due` when `SendAfterDate > Today`
- Main outcome: Only signed-authorized candidates are sent to employer HR, with rich prefill context.

### `BGV_5_Response1`
- Trigger: New response in employer HR verification Microsoft Form.
- Matching:
  - Looks up `BGV_Requests` by `startswith(RequestID, <submitted RequestID>)`.
  - Looks up `BGV_FormData` by `RecordItemID` from the matched request row.
- What it does:
  - Initializes scoring variables (`Severity`, `Outcome`, notify flags).
  - Applies risk logic:
    - MAS misconduct not `No / Not Applicable` -> High.
    - Disciplinary issue `Yes` -> High.
    - Employer would not re-employ (`Q26 = No`) -> High.
    - Employment details inaccurate (`Q15 = No`) -> Medium if no higher severity already set.
    - Company details inaccurate (`Q8 = No`) -> Low if no higher severity already set.
    - Other comments (`Q27`) -> Low if no higher severity already set.
    - Contact requested -> action-required notify flag.
  - Writes final result to `BGV_Requests`:
    - `VerificationStatus = Responded`
    - `ResponseReceivedAt`
    - `Severity`, `Outcome`, `PEV Checks`, `Notes`
  - Medium-severity employment-detail discrepancies now also set the Teams notify flag, not just the high-severity branches.
  - Neutral severity is no longer used; low-severity/cleared logic now treats the old neutral path as `Low`.
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
  - `PEV Checks` is set to:
    - `Form Filled and Cleared` when the employer has responded and severity is blank
    - `Adverse PEV Checks - see severity` when the employer has responded and severity is `Low`, `Medium`, or `High`
  - If FormData row exists, updates `BGV_FormData` with Form 2 raw payload + normalized Form 2 result fields, including:
    - The new readable employer-verification columns exist on `PEV_FormData`, but they are not yet being auto-populated by `BGV_5` because the SharePoint action schema still needs a safe refresh in Power Automate.
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
  - This flow now posts to the BGV channel only for cleared employer responses where severity is blank.
  - The BGV channel therefore gets three main post types:
    - day-5 unsigned authorization alerts from `BGV_3`
    - cleared-case posts from `BGV_5`
    - adverse report-summary posts from `BGV_7`
  - Recruiter-facing email details are cleaned before send so escaped newline markers such as `\n` or `\n\n` render as normal line breaks instead of raw text.
  - Recruiter-facing notifications include a direct candidate-folder link for faster follow-up.
  - If severity is blank after employer response, both the recruiter email and the Teams post are treated as cleared-case notifications and say the PEV checks are cleared and TAC form is to be sent.
- Recruiter-facing response emails are now combined into one mailbox email for every employer response:
  - subject starts with `PEV Response Received`
  - subject always includes `Severity: <value>` and leaves it blank when there is no severity
  - body always includes employer details, request ID, candidate folder link, flagged issues, and the cleaned details/comments block
  - cleared cases still add the TAC follow-up note in that same email instead of using a separate response-vs-severity email split
  - there is no separate high-severity-only recruiter email anymore; high-severity cases also use this same `PEV Response Received` email
- Candidate name in recruiter-facing notifications now resolves safely in this order:
  - `PEV_FormData.F1_CandidateFullName`
  - the request lookup display name
  - `CandidateID` as the final fallback
  - this prevents blank candidate names in the `PEV Response Received` email subject/body and related notifications.
  - Recruiter-facing response emails tell recruiters where to find the later report summary under `BGV_Records > Candidate Files (<CandidateID>)`.
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
  - `PEV Checks`:
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
- Reminder emails now rebuild the same employer `FinalVerificationLink` used by `BGV_4`, including the employer-specific shared request-folder link, so reminders still contain the current Microsoft Form URL even when the legacy `uniquelinktoemployers` SharePoint field is blank.
- Company stamp handling now follows the same fallback pattern as `BGV_4`:
  - if the request-specific company stamp document already exists, the flow shares that file
  - if it does not exist, the flow creates it from the `Company Stamp.docx` template, then shares the newly created file
  - this prevents reminder runs from failing just because one request folder is missing its stamp document
- Reminder 1, Reminder 2, and Final Reminder wording now clearly names the candidate and says that the candidate authorized D L Resources to conduct the background check and provided the employer contact for verification.
- Candidate name in employer reminders now resolves safely in this order:
  - `PEV_FormData.F1_CandidateFullName`
  - the request lookup display name
  - `CandidateID` as the final fallback
  - this prevents blank candidate names in Reminder 1, Reminder 2, Final Reminder, and the recruiter escalation Teams post after Reminder 2.
- Controlled internal-only smoke validation on `2026-04-08` confirmed all three employer reminder emails render correctly when sent to `recruitment@dlresources.com.sg`:
  - Reminder 1 subject: `Reminder: Employment Verification Request`
  - Reminder 2 subject: `2nd Reminder: Employment Verification Request from D L Resources`
  - Final Reminder subject: `Final Reminder: Employment Verification Request`
  - each email included:
    - the correct candidate name
    - wording that the candidate authorized D L Resources to conduct the background check
    - wording that the employer was provided as the verification contact
    - the request-specific prefilled Form 2 link
    - the request-specific shared Word company-stamp document link
  - request-row state transitions also matched the intended logic:
    - Reminder 1 stamped `Reminder1At` and `VerificationStatus = Reminder 1 Sent`
    - Reminder 2 stamped `Reminder2At` and `VerificationStatus = Reminder 2 Sent`
    - Final Reminder stamped `Reminder3At` and `VerificationStatus = Reminder 3 Sent`
- Escalation now stamps `EscalatedAt`, so the same unresolved request is not escalated again on every later run.
- One day after Reminder 2 with no employer response, the recruiter notification now says `PEV Checks Cleared`, includes the candidate-folder link, and tells recruiters TAC form is to be sent.
- When Reminder 3 is sent, the flow also saves an HTML copy of that final reminder email into the same request folder under the candidate folder for audit/reference.
- Adds close-window upload-link expiry for no-response cases:
  - when `Reminder3At` is 5+ days old and `ResponseReceivedAt` is still empty
  - finds request folder `BGV Records/Candidate Files/<CandidateID>/<RequestID>`
  - stops sharing that folder (`UnshareItem`).
- Main outcome: Employer follow-up is systematic, time-based, and auditable.

### `BGV_7_Generate_Report_Summary`
- Trigger: Recurrence every 10 minutes.
- Selection:
  - Reads the request list broadly and then filters inside the flow for rows where `ResponseReceivedAt` is not empty.
  - Only continues for rows with a non-empty `ResponseReceivedAt` and a `RequestID` ending in an employer slot such as `EMP1`.
- What it does:
  - Reads the live Word template by path:
    - `DLR Recruitment Ops > BGV Records > Templates > ReportSummary_Template.docx`
  - Loads the matching `BGV_FormData` row by exact `RequestID`.
  - Uses the saved raw employer payload from `BGV_FormData.Form2RawJson` and passes it back into the report-summary filler so the report template maps directly to the employer Form 2 question keys.
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
  - The final save path now uses a simple update-then-create fallback:
    - first tries `Update_report_summary_file_v2` against the matched `RS_EmpN.docx`
    - if update fails because the file does not exist yet, it falls back to `Create_report_summary_file_v2`
    - `Compose_Report_Save_Complete_v2` then normalizes the save result before the Teams post branch continues
  - If the report already exists but has never been posted to Teams before, the flow still posts the report link after the update path.
  - Teams report-summary post only sends when both `BGV_Requests.Report Summary Teams Posted At` and `BGV_FormData.Report Summary Teams Posted At` are blank.
  - Teams report-summary post only sends for adverse cases where the highest mapped severity is `Low`, `Medium`, or `High`.
  - Old `Neutral` severity is treated as `Low`, so low/medium/high is now the full adverse ladder.
  - The Teams post includes:
    - highest severity for the request
    - flagged issue summary
    - candidate folder link
    - report summary link
    - details block built from request notes, including MAS-style reasons where present
  - After a successful Teams post, flow stamps both fields with current UTC time so it will not post that same report summary again.
- Main outcome: Each completed employer verification now gets one employer-specific report-summary DOCX generated from the real SharePoint template and stored in the correct candidate folder, with a live-tested save path that updates existing files or creates new ones reliably.

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
- Trigger: Recurrence every 10 minutes in Singapore time.
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
    - `Candidate Folder Link`
    - `Severity`
    - `Outcome`
  - `Candidate Folder Link` now points to `BGV Records/Candidate Files/<CandidateID>/` for each dashboard row.
  - `Completed Status` now also shows `Yes` for reminder/escalation-cleared cases:
    - request `PEV Checks = No response at Reminder 2`
    - `Employer Reminder 3 Sent`
  - `Completed Date` uses the first available completion-style timestamp in this order:
    - `ResponseReceivedAt`
    - `EscalatedAt`
    - `Reminder3At`
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
    - `PEVDashboard_Flow.xlsx`
  - The older local COM-based snapshot workbook:
    - `PEV Dashboard.xlsx`
    remains unchanged unless you choose to cut over later.

## How to Read the Dashboard

### Which workbook to open
- The live Power Automate dashboard workbook is:
  - `BGV Records/Dashboard/PEVDashboard_Flow.xlsx`
- This is the workbook refreshed by `BGV_9`.
- The older workbook (`PEV Dashboard.xlsx`) is the older snapshot-style version and is not the main live-flow workbook.

### What each sheet is for
- `Summary`
  - This is the quick management view.
  - It shows the headline counts and small summary tables.
- `Cases`
  - This is the working list for recruiters.
  - Each row is one employer request, not one whole candidate.
  - If one candidate has 3 employers, that candidate can appear in 3 rows.
- `Helper`
  - This supports formulas and lookups.
  - Recruiters normally do not need to use this sheet directly.
- `RefreshLog`
  - This records when `BGV_9` last refreshed the workbook and what counts were produced in that run.

### How to read the Summary sheet
- `Total Requests`
  - Total dashboard rows included in the current dashboard logic.
  - This is the sum of active rows still shown in the dashboard plus the closed-case counts tracked by the refresh flow.
- `Open Cases`
  - Requests still actively being worked.
  - These are rows that have not yet aged out of the dashboard cleanup logic.
- `Completed Cases`
  - Requests treated as closed by the dashboard logic.
  - This includes:
    - `Employer Form Received`
    - `Employer Form Received But Flagged`
    - `Employer Reminder 3 Sent` cases once they move into the closed/cleared logic
- `Employer Forms Received`
  - Count of cases closed with a normal employer response and no flagged severity issue.
- `Authorisation Forms Received`
  - Count of candidates whose authorization stage is complete enough for the employer stage to proceed.
- `Closed Cases Report`
  - Breaks the closed rows into the main end states:
    - `Employer Form Received`
    - `Employer Form Received But Flagged`
    - `Employer Reminder 3 Sent`
    - `Cleared Rows (Total)`

### How to read the Cases sheet
- Each row = one `RequestID`
- Read the row left to right:
  - who the candidate is
  - which employer/request this is
  - what stage the case is at
  - when the key emails/reminders happened
  - whether the case is completed
  - whether severity/issues were found

### Meaning of the main dashboard columns
- `Candidate Name`
  - Candidate linked to this employer request.
- `CandidateID`
  - Main candidate tracking ID.
- `RequestID`
  - Employer-request tracking ID for this specific employer slot.
- `Company Name`
  - Employer/company being verified for this row.
- `HR Name`, `HR Email`, `HR Mobile Number`
  - Contact details from the candidate form for that employer.
- `Status`
  - Current stage of the request based on candidate auth, employer send, reminders, and response.
- `Candidate Email Sent At`
  - When the authorization form was first sent to the candidate.
- `Candidate Reminder`
  - Shows the latest authorization reminder stage sent to the candidate.
- `Employer Email Sent At`
  - When the verification request was first emailed to employer HR.
- `Employer Reminder`
  - Shows the latest employer reminder stage sent.
- `Completed Status`
  - `Yes` when the request is treated as completed/closed by dashboard logic.
  - `No` when the request is still active.
- `Completed Date`
  - The main completion-style timestamp shown in the dashboard.
  - Uses first available from:
    - employer response time
    - escalation time
    - reminder 3 time
- `Employer Response Received At`
  - When the employer submitted the Microsoft Form.
- `Employer Email Reply At`
  - When the latest employer email reply was detected in the mailbox.
- `Last Activity At`
  - Latest relevant activity timestamp across sends, reminders, replies, and responses.
- `Candidate Folder Link`
  - Direct SharePoint link to the candidate folder.
- `Severity`
  - Risk level from the employer response:
    - blank
    - `Low`
    - `Medium`
    - `High`
- `Outcome`
  - Flagged issue summary pulled from the employer form logic.

### What each Status means
- `Candidate Form Received`
  - Candidate has submitted the declaration form, but the authorization link has not yet been sent.
- `Authorisation Form Sent`
  - Candidate has received the authorization form and signature is still pending.
- `Authorisation Form Received`
  - Authorization is signed/received and the request is waiting for employer-send conditions.
- `Authorisation Received - Employer Email Queued`
  - Authorization is done, but the employer email is intentionally waiting because of `SendAfterDate`.
- `Email Sent to Employer`
  - Employer verification email has been sent and no reminder has been sent yet.
- `Employer Reminder 1 Sent`
  - First reminder has been sent to employer HR.
- `Employer Reminder 2 Sent`
  - Second reminder has been sent to employer HR.
- `Employer Reminder 3 Sent`
  - Final reminder has been sent to employer HR.
- `Employer Form Received`
  - Employer submitted the form and no flagged severity was recorded.
- `Employer Form Received But Flagged`
  - Employer submitted the form and severity is `Low`, `Medium`, or `High`.

### How severity should be interpreted
- blank
  - no flagged severity logic triggered
- `Low`
  - lower-level issue from the employer response logic
- `Medium`
  - employment-detail discrepancy issue
- `High`
  - more serious flagged issue such as MAS / disciplinary / re-employ problem

### Why rows disappear from the dashboard
- `BGV_9` intentionally removes older rows from the visible dashboard once they are treated as closed.
- A row is skipped from the active dashboard when:
  - `Employer Reminder 3 Sent` and there is still no response for 5 days after `Reminder3At`
  - completed employer-response cases are 5 days past the response/completion timestamp
- Those rows are not “lost”.
- They are simply no longer shown in the active dashboard table because the dashboard is meant to focus on current working cases plus tracked close counts.

### Important practical note
- If you want to investigate a case in detail, use:
  - the `Cases` sheet row
  - the `Candidate Folder Link`
  - the SharePoint lists (`PEV_Candidates`, `PEV_Requests`, `PEV_FormData`)
- The dashboard is the recruiter-facing summary layer, not the full data store.

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
  - `BGV_9` refreshes `PEVDashboard_Flow.xlsx` from live SharePoint list data

## Notes
- This summary is based on the current unpacked canonical flow JSON in the repo.
- If cloud flows are changed in Power Automate but not exported/unpacked yet, cloud behavior may be newer than this file.





