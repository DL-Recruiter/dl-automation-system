# PEV Approved HR Reference Contact Guardrail

This design adds a recruiter-controlled guardrail before `BGV_4_SendToEmployer_Clean` sends any previous-employment verification email to an employer HR/reference address.

Use this when you want to move the current Excel-based approved-contact list into SharePoint and make the employer-send step pause automatically when a submitted HR/reference email is not yet approved.

Current implementation note:

- the canonical repo flow now includes a first-pass version of this guardrail
- that first pass uses a Teams channel action message plus automatic retry on the next recurrence run after the approved contact is added to the SharePoint list
- a future enhancement can still upgrade this to a true Teams Approvals card with explicit approve/reject outcomes

## Recommended SharePoint List

Create a SharePoint list in the same `DLR Recruitment Ops > PEV Records` area.

- Suggested name: `Approved HR Reference Contacts`
- Why a list instead of Excel:
  - Power Automate `Get items` is more reliable than Excel row lookups
  - easier filtering, auditing, and approval follow-up
  - better concurrency behavior than Excel connectors

### Suggested columns

| Column | Type | Notes |
| --- | --- | --- |
| `Title` | Single line of text | Set to `Company Name - HR Reference Email` or similar. |
| `CompanyName` | Single line of text | Employer/company name. |
| `CompanyAddress` | Multiple lines of text | Declared employer address if known. |
| `TelContact` | Single line of text | Main phone or contact number. |
| `HRReferenceEmail` | Single line of text | Original email as entered for display/audit. |
| `HRReferenceEmailNormalized` | Single line of text | Lowercase trimmed version used for lookup. Index this column. |
| `CompanyUEN` | Single line of text | Optional but useful secondary identifier. |
| `ContactType` | Choice | `General Company HR`, `Personal HR Contact`. |
| `ContactPersonName` | Single line of text | Optional named HR contact. |
| `Notes` | Multiple lines of text | Free-text audit notes. |
| `IsActive` | Yes/No | Recommended default `Yes`. |
| `IsVerified` | Yes/No | Recommended default `Yes` for migrated rows, `No` for newly added rows until recruiter confirms. |
| `SourceSheet` | Choice or single line | `Companys HR email`, `Personal HR email`. |
| `VerifiedOn` | Date and time | Optional. |
| `VerifiedByPerson` | Person or Group | Optional business owner. |

SharePoint system columns already cover:

- `Created`
- `Modified`
- `Created By`
- `Modified By`

### Current request-side tracking columns

The live first-pass implementation now uses these `PEV_Requests` columns:

- `ReferenceGuardrailStatus`
- `ReferenceGuardrailCheckedAt`
- `ReferenceGuardrailNotifiedAt`
- `ReferenceGuardrailLastEmailNormalized`
- `ReferenceGuardrailNotes`

Recommended values for `ReferenceGuardrailStatus`:

- `Email found in approved list`
- `Approval required`
- `Rejected / Needs corrected HR email`

Future enhancement note:

- if the flow is later upgraded to a blocking Teams Approvals pattern, extra values such as `Approved and added to list` or `Approved but still not added` can be added at that time

## Excel Migration Plan

Current source workbook:

- `DLR Recruitment Ops > PEV Records > Previous HR Reference List > HR_Referencing_Emails_updated...`

Current sheets:

1. `Companys HR email`
2. `Personal HR email`

### Recommended migration approach

1. Create the new SharePoint list first.
2. In Excel, clean the source data:
   - remove blank rows
   - ensure the email column contains one email per row
   - standardize company names where possible
3. Add two temporary helper columns in Excel before import:
   - `ContactType`
   - `HRReferenceEmailNormalized`
4. Populate them as:
   - `Companys HR email` sheet -> `ContactType = General Company HR`
   - `Personal HR email` sheet -> `ContactType = Personal HR Contact`
   - `HRReferenceEmailNormalized = LOWER(TRIM(email))`
5. Import both sheets into the same SharePoint list.
6. After import, run one dedupe pass on `HRReferenceEmailNormalized`.
7. Mark migrated good rows:
   - `IsActive = Yes`
   - `IsVerified = Yes`

### Dedupe rule

Primary unique key:

- `HRReferenceEmailNormalized`

Secondary review fields:

- `CompanyName`
- `CompanyUEN`
- `ContactType`

If the same normalized email exists more than once:

- keep one active master row when the entries are equivalent
- merge useful notes or contact-person details
- avoid deleting rows until the recruiter confirms they are duplicates

## Where This Fits In The Current Flow

Best insertion point:

- inside `BGV_4_SendToEmployer_Clean`
- after the flow has loaded the request row, candidate row, and matching `BGV_FormData`
- before the employer email send action

This works well with the current design because `BGV_0_CandidateDeclaration` already creates one `PEV_Requests` row per employer slot:

- `EMP1`
- `EMP2`
- `EMP3`

That means the current `Apply to each (Requests Loop)` is already the right loop for checking each employer separately.

## Exact Power Automate Actions

Below is the recommended action sequence inside the per-request loop of `BGV_4_SendToEmployer_Clean`.

### 1. Compose the employer number

Action:

- `Compose` -> `Compose_EmployerNumber`

Expression:

```text
last(split(items('Apply_to_each_(Requests_Loop)')?['RequestID'],'-'))
```

This yields `EMP1`, `EMP2`, or `EMP3`.

### 2. Compose the submitted HR/reference email

Action:

- `Compose` -> `Compose_SubmittedHREmail`

Expression:

```text
coalesce(
  first(body('Get_items_(BGV_FormData)')?['value'])?['F1_HREmail'],
  items('Apply_to_each_(Requests_Loop)')?['EmployerHR_Email'],
  ''
)
```

### 3. Normalize the email

Action:

- `Compose` -> `Compose_NormalizedSubmittedHREmail`

Expression:

```text
toLower(trim(string(outputs('Compose_SubmittedHREmail'))))
```

### 4. Optional normalized UEN

Action:

- `Compose` -> `Compose_NormalizedEmployerUEN`

Expression:

```text
toUpper(trim(string(
  coalesce(
    first(body('Get_items_(BGV_FormData)')?['value'])?['F1_EmployerUEN'],
    items('Apply_to_each_(Requests_Loop)')?['EmployerUEN'],
    items('Apply_to_each_(Requests_Loop)')?['Employer_UEN'],
    ''
  )
)))
```

### 5. Guard against blank email

Action:

- `Condition` -> `Condition_HasSubmittedHREmail`

Expression:

```text
not(empty(outputs('Compose_NormalizedSubmittedHREmail')))
```

If `No`:

- update request status to `Rejected / Needs corrected HR email` or a similar blocked status
- notify recruiter
- skip employer send for that request

### 6. Look up the approved-contact list

Live implementation:

- `Send an HTTP request to SharePoint`
- the flow uses the list title plus `HRReferenceEmailNormalized`
- the request limits the result to the first active match

Live URI expression:

```text
@concat(
  '_api/web/lists/GetByTitle(''Approved HR Reference Contacts'')/items?$top=1&$select=Id,Title,HRReferenceEmailNormalized,IsActive&$filter=HRReferenceEmailNormalized eq ''',
  replace(outputs('Compose_NormalizedSubmittedHREmail'),'''',''''''),
  ''' and IsActive eq 1'
)
```

Alternative design:

- a normal SharePoint `Get items` action would also work if the connector behaves reliably in your tenant

Important note:

- the email match should be the primary decision point
- UEN can be used for extra display context or optional warning logic, but not as the main blocker when the approved email already matches

### 6A. Secondary UEN-based centralised email routing

Smallest safe implementation choice:

- reuse `Approved HR Reference Contacts` as the recruiter-maintained UEN routing source
- keep the approved-email guardrail decision on `HRReferenceEmailNormalized`
- add a second lookup by `CompanyUENNormalized` only inside the approved send branch

Recommended list field:

- `CompanyUENNormalized`
  - uppercase trimmed version of `CompanyUEN`
  - indexed in SharePoint

Recommended flow actions:

- `Compose` -> `NormalizedEmployerUEN`
- `Send an HTTP request to SharePoint` -> `Get_Centralised_Employer_Email_By_UEN`
- `Compose` -> `CentralisedEmployerEmailCandidate`
- `Compose` -> `IsCentralisedEmployerEmailValid`
- `Compose` -> `ResolvedEmployerToEmail`
- `Compose` -> `DuplicatePrevention_CentralisedEmailMatchesResolvedTo`
- `Compose` -> `ResolvedEmployerCcEmail`

Routing rules:

- UEN match + valid centralised email + submitted HR email is the same:
  - `To = submitted HR email`
  - `CC = blank`
- UEN match + valid centralised email + submitted HR email is different:
  - `To = submitted HR email`
  - `CC = centralised email`
- UEN match + valid centralised email + submitted HR email is blank/invalid:
  - if existing guarded recipient logic would otherwise fall back to `dlresplmain@dlresources.com.sg`, replace `To` with the centralised email
- No UEN match, blank centralised email, or invalid centralised email:
  - keep existing behavior unchanged

### 7. Check whether the email was found

Action:

- `Condition` -> `Condition_EmailFoundInApprovedList`

Expression:

```text
greater(length(body('Get_items_(Approved_HR_Reference_Contacts)')?['value']),0)
```

If `Yes`:

- update request row:
  - `ReferenceGuardrailStatus = Email found in approved list`
  - `ReferenceGuardrailCheckedAt = utcNow()`
- continue to the existing employer-email send path

If `No`:

- pause this employer branch
- notify the assigned recruiter through a Teams channel action message
- require the recruiter to add the contact to the SharePoint list before the next recurrence run can continue the request
- stamp:
  - `ReferenceGuardrailStatus = Approval required` when the submitted email is present but not approved
  - `ReferenceGuardrailStatus = Needs corrected HR email` when the submitted email is blank or invalid
  - `ReferenceGuardrailNotifiedAt = utcNow()`
  - `ReferenceGuardrailLastEmailNormalized = <normalized submitted email>`

## Teams Notification Design

### Live first-pass action

Use:

- `Post message in a chat or channel`

Recommended settings:

- Post as: Flow bot
- Post in: Channel
- Team: `DLR Recruitment Ops`
- Channel: `BGV`

Why this action:

- visible to the operations/recruitment team in the working channel
- simple and reliable for the current first pass
- pairs well with the retry-on-next-recurrence pattern after the list row is added

Operational behavior:

- the flow does not block inside a waiting approval card
- the pending request stays unsent
- on the next scheduled run, the same request is re-checked automatically against the SharePoint list
- duplicate Teams posts are suppressed when the normalized submitted email has not changed since the last notification

### Future enhancement option

If you later want a blocking recruiter decision inside Teams Approvals, you can upgrade this design to:

- `Start and wait for an approval`

That future pattern is described below only as a design option, not as the current live behavior.

## Approval Message Template

Use HTML in the approval details field:

```html
<p><strong>PEV HR/reference contact verification required</strong></p>
<p>Candidate Name: @{first(body('Get_item')?['value'])?['FullName']}<br>
Candidate ID: @{items('Apply_to_each_(Requests_Loop)')?['CandidateID']}<br>
Employer Number: @{outputs('Compose_EmployerNumber')}<br>
Employer Name: @{coalesce(first(body('Get_items_(BGV_FormData)')?['value'])?['F1_EmployerName'],items('Apply_to_each_(Requests_Loop)')?['EmployerName'],'(Not captured)')}<br>
Submitted HR/reference Email: @{outputs('Compose_NormalizedSubmittedHREmail')}<br>
Company UEN: @{if(empty(outputs('Compose_NormalizedEmployerUEN')),'(Not provided)',outputs('Compose_NormalizedEmployerUEN'))}<br>
Check Result: Email not found in approved list</p>
<p>Approved HR Reference Contacts list:<br>
<a href="https://dlresourcespl88.sharepoint.com/sites/DLRRecruitmentOps570/Lists/Approved%20HR%20Reference%20Contacts/AllItems.aspx">Open SharePoint List</a></p>
<p>Please verify this HR/reference contact. If valid, add the email and relevant details into the SharePoint List. This PEV request will retry automatically on the next scheduled flow run after the approved contact has been added.</p>
```

If you want the recruiter to also see the already-cleared employers in the same candidate run, build a running summary string variable such as `varEmployerGuardrailSummary` and append one line per employer:

- `EMP1 - Found in approved list`
- `EMP2 - Approval required`
- `EMP3 - Found in approved list`

Then include that summary block in the approval details.

## Future Approval Outcome Logic

This section is for a future upgrade only.

The live implementation does not yet use `Start and wait for an approval`, does not store `ReferenceGuardrailApprovalOutcome`, and does not branch on explicit `Approve` / `Reject` results.

### If recruiter approves

1. Run `Get items` again against `Approved HR Reference Contacts`.
2. Use the same normalized-email filter query.
3. Condition:

```text
greater(length(body('Get_items_(Approved_HR_Reference_Contacts)_Recheck')?['value']),0)
```

4. If found on re-check:
   - update request row:
     - `ReferenceGuardrailStatus = Approved and added to list`
     - `ReferenceGuardrailCheckedAt = utcNow()`
   - continue to the existing employer-send actions

5. If still not found on re-check:
   - do not send the employer email yet
   - update request row:
     - `ReferenceGuardrailStatus = Approved but still not added`
   - send follow-up Teams message or email to recruiter:
     - tell them the approval was received but the email is still missing from `Approved HR Reference Contacts`
   - terminate that employer branch with a blocked status

### If recruiter rejects

Update request row:

- `ReferenceGuardrailStatus = Rejected / Needs corrected HR email`
- `ReferenceGuardrailCheckedAt = utcNow()`

Then:

- do not send the employer verification email
- optionally notify the operations mailbox or candidate owner for correction

## Suggested Condition Layout

Use this branch order inside each request loop:

1. Candidate signed authorization?
2. Request due to send?
3. Submitted email present?
4. Email found in `Approved HR Reference Contacts`?
5. If not found, post Teams channel message and leave the request unsent for the next recurrence run.

Future upgrade path:

1. Candidate signed authorization?
2. Request due to send?
3. Submitted email present?
4. Email found in `Approved HR Reference Contacts`?
5. If not found, approval outcome = Approve or Reject?
6. If Approve, re-check list and only continue if the row now exists.

## Apply To Each Handling For Multiple Employers

You do not need a second candidate-employer splitter if you stay aligned to the current architecture.

Current best pattern:

- `BGV_0` creates one request row per employer
- `BGV_4` already loops through pending request rows
- each request row is one employer branch

So the logic naturally works like this:

- Employer 1 found -> continue immediately
- Employer 2 not found -> send approval and wait
- Employer 3 found -> continue immediately

To make the recruiter message clearer, maintain two string variables during the run:

- `varEmployerGuardrailSummary`
- `varEmployersNeedingApproval`

Append text with `Append to string variable` as each employer is checked.

Example summary content:

```text
EMP1 - ABC Pte Ltd - hr@abc.com - Found in approved list
EMP2 - XYZ Pte Ltd - jane@xyz.com - Approval required
EMP3 - MNO Pte Ltd - careers@mno.com - Found in approved list
```

## Expressions Reference

### Normalize email

```text
toLower(trim(string(<email value>)))
```

### Safe fallback for email source

```text
coalesce(
  first(body('Get_items_(BGV_FormData)')?['value'])?['F1_HREmail'],
  items('Apply_to_each_(Requests_Loop)')?['EmployerHR_Email'],
  ''
)
```

### Email found condition

```text
greater(length(body('Get_items_(Approved_HR_Reference_Contacts)')?['value']),0)
```

### Future approval outcome equals approve

```text
equals(outputs('Start_and_wait_for_an_approval')?['body/outcome'],'Approve')
```

### Future approval outcome equals reject

```text
equals(outputs('Start_and_wait_for_an_approval')?['body/outcome'],'Reject')
```

## Implementation Notes

- Index `HRReferenceEmailNormalized` in SharePoint.
- Keep the list lookup keyed on normalized email, not display email.
- Do not rely on Excel row lookups for this guardrail once the SharePoint list is live.
- Keep the existing employer-send fallback email only for technical safety; the new guardrail should block unapproved real HR/reference emails before the actual send step.
- If you want stricter control, also block sends when the approved-list row is found but `IsVerified = No` or `IsActive = No`.

## Recommended Future Enhancements

- Add a custom list form or Power App for recruiters to add approved contacts consistently.
- Add a duplicate-detection view grouped by `HRReferenceEmailNormalized`.
- Add a monthly review flow to flag inactive or unverified contacts.
- Add optional UEN mismatch warning logic:
  - email found, but UEN differs from current submission
  - allow send, but alert recruiter for review

## 14) Test cases for UEN-based routing

1. UEN match + candidate/submitted HR email different
   - approved email guard passes
   - `ResolvedEmployerToEmail = submitted HR email`
   - `ResolvedEmployerCcEmail = centralised email`

2. UEN match + candidate/submitted HR email same
   - approved email guard passes
   - `ResolvedEmployerToEmail = submitted HR email`
   - `ResolvedEmployerCcEmail = blank`

3. No UEN match
   - approved email guard behavior remains the main gate
   - employer recipient stays on the existing submitted-email or fallback logic

4. Invalid or blank centralised email
   - employer recipient stays on the existing submitted-email or fallback logic

5. Blank or invalid candidate/submitted HR email + UEN match
   - if the current guarded recipient would otherwise be the fallback mailbox and the centralised email is valid, use the centralised email as `To`
   - do not add a duplicate `CC`
