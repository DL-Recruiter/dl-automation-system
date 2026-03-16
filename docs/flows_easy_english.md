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
8. Scheduled reminder flows chase unsigned candidate forms and unanswered employer requests.

## Flow-by-Flow Explanation

### `BGV_0_CandidateDeclaration`
- Trigger: New response in candidate declaration Microsoft Form.
- What it does:
  - Creates `CandidateID`.
  - Creates candidate folder and authorization subfolder in SharePoint.
  - Creates candidate row in `BGV_Candidates`.
  - Generates and saves authorization `.docx` from the target-site template in `DLR Recruitment Ops > BGV Records > Templates > AuthorizationLetter_Template.docx`, then shares it and emails candidate.
  - The authorization link is created as an anonymous edit link so the candidate can open and edit the Word document directly.
  - When filling the authorization Word template ID content controls:
    - NRIC control gets candidate NRIC, else `N/A`.
    - Passport control gets `N/A` when NRIC exists; otherwise candidate Passport, else `N/A`.
  - Authorization template includes a bottom checkbox line `Yes, I authorized` using content-control tag `SignedYes`.
  - Updates candidate status to pending signature.
  - Creates `BGV_Requests` rows for EMP1 always, and EMP2/EMP3 when those employer sections are filled.
  - Before creating each EMP slot row, checks whether that same slot RequestID already exists to avoid duplicate inserts.
  - Creates `BGV_FormData` rows (`EMP1`, optional `EMP2`, optional `EMP3`) with normalized candidate/employer fields and raw Form 1 payload.
  - Writes Form 1 reason-for-leaving per slot into `BGV_FormData.F1_ReasonForLeaving`:
    - EMP1 <- E1 reason key
    - EMP2 <- E2 reason key
    - EMP3 <- E3 reason key
  - Uses Request IDs in format:
    - `REQ-<CandidateID>-EMP1`
    - `REQ-<CandidateID>-EMP2`
    - `REQ-<CandidateID>-EMP3`
  - Sets `SendAfterDate` as `utcNow()` for EMP1/EMP2/EMP3 request rows (consistent scheduling baseline).
  - Sends candidate email via `Send an email from a shared mailbox (V2)` from `recruitmentops@dlresources.com.sg`.
  - Candidate authorization email body now uses personalized salutation (`Dear <Candidate Name>`) and explicit signing instructions while preserving dynamic name/link expressions.
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
- Trigger: Daily recurrence.
- What it does:
  - Gets candidates with `Status = Pending Authorization Form Signature`.
  - Computes days since authorization link creation.
  - Sends reminder emails between day 1 and day 5, max once per day.
  - Uses `LastAuthReminderAt` consistently to avoid duplicate same-day reminders.
  - Reminder updates only stamp `LastAuthReminderAt`; they do not change candidate status to signed/obtained.
  - Reminder update no longer flips `ConsentCaptured`; it only stamps reminder timestamp fields.`\n  - Outer reminder gate now checks `AuthorisationSigned` instead of `ConsentCaptured` so stale consent flags do not block pending reminders.
  - Day-5 escalation now runs independently of whether a same-day reminder email was sent, so stale `LastAuthReminderAt` values do not suppress escalation.
  - Day-5 escalation email now uses current candidate item values directly and still sends even if the Teams post step fails.
  - On day 5 unresolved cases, posts Teams escalation to `DLR Recruitment Ops > BGV` and sends internal escalation email to `recruitmentops@dlresources.com.sg`.
  - Email sends are routed via shared mailbox `recruitmentops@dlresources.com.sg`.
- Main outcome: Unsigned candidate authorization forms are actively chased and escalated.

### `BGV_4_SendToEmployer_Clean`
- Trigger: Recurrence every 30 minutes.
- Selection:
  - Reads `BGV_Requests` where `VerificationStatus = Pending` and `HRRequestSentAt` is null.
- What it does (per request):
  - Loads candidate row and treats `AuthorisationSigned` as signed when value is boolean/string true.
  - Loads matching `BGV_FormData` row by `RequestID`.
  - Builds prefilled HR verification form URL with:
    - Candidate name
    - Candidate NRIC mapped into the HR form NRIC field
    - Candidate Passport mapped into the HR form Passport field
    - Request ID
    - Employer name
    - Employer UEN
    - Employer address
    - Employment period
    - Last drawn salary
    - Job title
  - Uses the matching `BGV_FormData` row as the first source for company name/address/UEN in the employer email body, so EMP1/EMP2/EMP3 show the correct declared company details.
  - Employer email subject/body wording is synced to the latest cloud-edited template (including the newest HR instruction text), while preserving the existing dynamic mappings for declared-details and verification-link sections.
  - Finds authorization file, attaches it, and emails employer HR.
  - Sends the same signed authorization attachment to the candidate email (`BGV_Candidates.CandidateEmail`) for reference, with a note to open it in Word to view the signed copy.
  - Email sends are routed via shared mailbox `recruitmentops@dlresources.com.sg`.
  - Employer email subject now uses the mapped dynamic company field.
  - Employer email wording uses dynamic candidate/company values while preserving the existing declared-details and verification-link sections.
  - Recipient email resolution is guarded:
    - use `BGV_FormData.F1_HREmail` when it is email-formatted
    - else use `BGV_Requests.EmployerHR_Email` when it is email-formatted
    - else fallback to `dlresplmain@dlresources.com.sg` to avoid runtime send failure.
  - Updates request row:
    - `VerificationStatus = Sent`
    - `HRRequestSentAt = utcNow()`
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
    - Would not re-employ -> at least Medium.
    - Information inaccurate -> Low if no higher severity already set.
    - Contact requested -> action-required notify flag.
  - Writes final result to `BGV_Requests`:
    - `Status = Completed`
    - `ResponseReceivedAt`
    - `Severity`, `Outcome`, `Notes`
  - If FormData row exists, updates `BGV_FormData` with Form 2 raw payload + normalized Form 2 result fields, including `F2_ReasonForLeaving`.
  - Keeps required SharePoint fields (including `Title`) when updating `BGV_FormData`, preventing save/runtime validation errors.
  - Sends Teams alert when notify flag is true.
  - Sends internal high-severity email when severity is `High`, including employer name and employer HR email in the body.
  - Recruiter-facing BGV_5 emails now include `EmployerName` in the email body context.
  - All email notifications in this flow are routed via shared mailbox and addressed to `recruitmentops@dlresources.com.sg`.
  - Teams notification target for this flow is `DLR Recruitment Ops > BGV`:
    - `groupId = 4475a565-7f2b-4df1-91cd-c8e3df8f805a`
    - `channelId = 19:01523cb936ce49fca3e80d2ee293da6a@thread.tacv2`
- Main outcome: Employer response is automatically triaged, stored, and escalated when needed.

### `BGV_6_HRReminderAndEscalation`
- Trigger: Daily recurrence.
- Selection baseline: requests with `VerificationStatus = Sent` and still no response.
- Reminder/escalation timeline:
  - Reminder 1: when HR request is at least 2 days old.
  - Reminder 2: 3+ days after Reminder 1.
  - Escalation post to recruiters: 1+ day after Reminder 2 with no response.
  - Final reminder: when HR request is 11+ days old and `Reminder3At` is empty.
- What it updates:
  - Reminder timestamps (`Reminder1At`, `Reminder2At`, `Reminder3At`)
  - Shared-mailbox reminder emails
  - Teams escalation message for unresolved cases
  - Teams escalation destination:
    - `groupId = 4475a565-7f2b-4df1-91cd-c8e3df8f805a`
    - `channelId = 19:01523cb936ce49fca3e80d2ee293da6a@thread.tacv2`
  - Shared-mailbox sender is `recruitmentops@dlresources.com.sg`.
  - Reminder conditions now use `empty(...)`-safe checks for SharePoint date fields so null/blank timestamps do not block reminder branches unexpectedly.
  - Reminder conditions/messages resolve values from the current request row (`items('Apply_to_each')`) so logic works even when earlier reminder update actions are skipped in that run.
- Main outcome: Employer follow-up is systematic, time-based, and auditable.

## How the Flows Connect
- Candidate signature track:
  - `BGV_0` -> `BGV_1` -> `BGV_2`
- Employer verification track:
  - `BGV_0` creates `BGV_Requests` + `BGV_FormData`
  - `BGV_4` sends prefilled HR request + attachment
  - `BGV_5` processes HR response and updates both lists
- Reminder/escalation track:
  - `BGV_3` for candidate signature delays
  - `BGV_6` for employer response delays

## Notes
- This summary is based on the current unpacked canonical flow JSON in the repo.
- If cloud flows are changed in Power Automate but not exported/unpacked yet, cloud behavior may be newer than this file.





