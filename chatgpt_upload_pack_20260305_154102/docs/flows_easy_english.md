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
  - Generates and saves authorization `.docx`, then shares it and emails candidate.
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
  - Loads matching candidate record.
  - Sends file content to Azure Function parser.
  - Reads parser output directly and does tolerant signature checks.
  - Filters parsed controls by tag/title containing `SignedYes` (and compatibility fallback `CandidateAuthorisation`).
  - Marks signed if parser `signedYes` is true-like or any matched checkbox has `isChecked = true`.
  - If signed, updates candidate record:
    - `AuthorisationSigned = true`
    - consent/status fields for signed authorization.
- Main outcome: Signed authorization is detected and candidate is marked as signed without manual review.

### `BGV_2_Postsignature`
- Trigger: Candidate item created or modified.
- Condition: candidate status is `Obtained Authorization Form Signature`.
- What it does:
  - Finds related `.docx` files in authorization folder.
  - Stops sharing for those files.
- Main outcome: Signed authorization files are no longer broadly shared.

### `BGV_3_AuthReminder_5Days`
- Trigger: Daily recurrence.
- What it does:
  - Gets candidates with `Status = Pending Authorization Form Signature`.
  - Computes days since authorization link creation.
  - Sends reminder emails between day 1 and day 5 (max once per day).
  - On day 5 unresolved cases, posts Teams escalation and sends internal escalation email.
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
    - Candidate name / identification number (`NRIC`, else `Passport`) mapped into the HR form NRIC field
    - Request ID
    - Employer name
    - Employer UEN
    - Employer address
    - Employment period
    - Last drawn salary
    - Job title
  - Uses the matching `BGV_FormData` row as the first source for company name/address/UEN in the employer email body, so EMP1/EMP2/EMP3 show the correct declared company details.
  - Finds authorization file, attaches it, and emails employer HR.
  - Email sends are routed via shared mailbox `recruitmentops@dlresources.com.sg`.
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
  - Sends internal high-severity email when severity is `High`.
  - All email notifications in this flow are routed via shared mailbox and addressed to `recruitmentops@dlresources.com.sg`.
  - Teams notification target for this flow is updated to the new Team/Channel destination.
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

