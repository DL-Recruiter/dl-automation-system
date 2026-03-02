# BGV Flows in Simple English

This document explains your exported Power Automate flows in plain language.

## Quick End-to-End Story
1. Candidate fills your declaration form.
2. System creates candidate records and an authorization document.
3. Candidate receives a link and signs the authorization form.
4. System detects signature and marks authorization as signed.
5. System sends verification requests to employer HR contacts.
6. Employers submit responses through your verification form.
7. System scores/flags responses and notifies your team.
8. Reminder and escalation flows chase missing responses.

## Flow-by-Flow Explanation

### `BGV_0_CandidateDeclaration`
- Trigger: A new Microsoft Form response from the candidate declaration form.
- What it does:
  - Creates a unique Candidate ID.
  - Creates candidate folders in SharePoint.
  - Writes candidate details into SharePoint lists.
  - Generates an authorization letter from a Word template.
  - Saves the authorization `.docx` to SharePoint.
  - Creates a share link and emails candidate to sign.
  - Updates candidate status to pending signature.
  - Creates one or more BGV request rows (EMP1/EMP2/EMP3) for employer checks.
- Main outcome: Candidate and request records are prepared, and signature request is sent.

### `BGV_1_Detect_Authorization_Signature`
- Trigger: A file is created/updated in the candidate files area.
- What it does:
  - Detects authorization `.docx` files in the expected folder pattern.
  - Extracts Candidate ID from filename.
  - Reads file content and sends it to an Azure Function parser.
  - Checks parser output for `signedYes = true`.
  - If signed, updates candidate row with signed status and consent timestamp.
- Main outcome: Candidate status changes to "authorization signed" automatically after signature detection.

### `BGV_2_Postsignature`
- Trigger: Candidate item created/modified in SharePoint.
- Condition: Status becomes `Obtained Authorization Form Signature`.
- What it does:
  - Finds related authorization files.
  - Stops sharing/unshares file(s) after signature is confirmed.
- Main outcome: Signature file access is tightened after successful signing.

### `BGV_3_AuthReminder_5Days`
- Trigger: Daily recurrence.
- What it does:
  - Finds candidates still pending authorization signature.
  - Calculates days since authorization link was created.
  - Sends daily reminder email (day 1 to day 5, with "not reminded today" guard).
  - On day 5, posts Teams escalation and sends internal alert email.
- Main outcome: Candidates are reminded to sign, and unresolved day-5 cases are escalated.

### `BGV_4_SendToEmployer_Clean`
- Trigger: Every 30 minutes.
- What it does:
  - Reads pending BGV request rows where HR request has not been sent.
  - Verifies candidate has signed authorization.
  - Builds employer verification form link (Request ID embedded).
  - Fetches signed authorization file from candidate folder.
  - Emails employer HR with form link + authorization attachment.
  - Marks request as sent with timestamp.
- Main outcome: Employer verification requests are dispatched only after valid authorization.

### `BGV_5_Response1`
- Trigger: Employer submits verification Microsoft Form.
- What it does:
  - Finds matching BGV request row by Request ID.
  - Evaluates responses for risk signals (for example: MAS misconduct, disciplinary items, re-employ answer, data mismatch).
  - Sets severity (`High`/`Medium`/`Low`) and outcome (`Verified` or `Needs Clarification`).
  - Stores response summary/notes in SharePoint and marks request completed.
  - Sends Teams notifications when action/flags exist.
  - Sends high-severity alert email to internal mailbox.
- Main outcome: Employer responses are auto-scored, recorded, and escalated when risky.

### `BGV_6_HRReminderAndEscalation`
- Trigger: Daily recurrence.
- What it does:
  - Finds BGV requests with status `Sent` and no employer response yet.
  - Sends reminder 1, reminder 2, and final reminder at configured time gaps.
  - Writes reminder timestamps (`Reminder1At`, `Reminder2At`, `Reminder3At`).
  - Posts Teams escalation when reminders are ignored.
- Main outcome: Non-responsive employers are followed up systematically and escalated.

## How the Flows Connect
- Candidate side:
  - `BGV_0` -> `BGV_1` -> `BGV_2`
- Employer side:
  - `BGV_0` creates request rows -> `BGV_4` sends HR request -> `BGV_5` processes HR response
- Reminder/escalation side:
  - `BGV_3` handles unsigned candidate authorization.
  - `BGV_6` handles unanswered employer verification requests.

## Notes
- This summary is based on exported JSON logic and action names.
- Some expressions in the flow JSON appear to have minor formatting inconsistencies; behavior in live flow may differ slightly from export text.
