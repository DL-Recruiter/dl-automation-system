<!-- markdownlint-disable MD013 -->

# BGV SharePoint List User Guide

This guide explains the main SharePoint stores used by the BGV
automation in simple language.

Use this file when you want to understand:

- what each list is for
- what the important columns mean
- which flow writes a column
- which flow reads a column

Important scope:

- This guide covers the business columns that the current BGV automation
  reads or writes.
- It does not try to document every default SharePoint system field such
  as `ID`, `Created`, `Modified`, `Author`, or `Editor` unless the
  automation depends on them.
- It is a user guide, not the low-level source-of-truth mapping file.
  For exact current wiring, see `docs/data_mapping_dictionary.md`.

## Quick Summary

| Store | What it is mainly used for |
| --- | --- |
| `BGV_Candidates` | One row per candidate. Tracks identity, authorization link, signature status, and candidate reminder activity. |
| `BGV_Requests` | One row per employer request (`EMP1`, `EMP2`, `EMP3`). Tracks employer outreach, reminder status, and final verification result. |
| `BGV_FormData` | One row per employer slot. Stores the normalized Form 1 and Form 2 values used for prefilling, audit, and troubleshooting. |
| `BGV Records` | Document library that stores candidate folders, authorization files, and related documents. |

## 1) `BGV_Candidates`

What this list is for:

- one row per candidate declaration
- candidate identity and contact details
- signed-authorization tracking
- candidate reminder and escalation support

Typical user questions this list answers:

- Has the candidate signed the authorization form?
- What is the candidate's current status?
- What share link was sent to the candidate?
- When was the last reminder sent?

### 1.1 Core identity columns

| Column | What it is for | Mainly written by | Mainly read by |
| --- | --- | --- | --- |
| `CandidateID` | The main unique ID for the candidate case. It links the candidate row to request rows, FormData rows, and the document-library folder. | `BGV_0_CandidateDeclaration` | `BGV_1`, `BGV_3`, `BGV_4`, other troubleshooting/reporting work |
| `FullName` | Candidate full name from the declaration form. | `BGV_0_CandidateDeclaration` | `BGV_4` for employer-form context, user review |
| `CandidateEmail` | Candidate email address used for authorization email and reference copy of the signed document. | `BGV_0_CandidateDeclaration` | `BGV_4`, user review |
| `IdentificationNumberNRIC` | Candidate NRIC value when provided. | `BGV_0_CandidateDeclaration` | `BGV_4` prefill fallback, user review |
| `IdentificationNumberPassport` | Candidate passport value when provided. | `BGV_0_CandidateDeclaration` | `BGV_4` prefill fallback, user review |

### 1.2 Authorization and reminder columns

| Column | What it is for | Mainly written by | Mainly read by |
| --- | --- | --- | --- |
| `Status` | Human-readable candidate workflow stage, for example pending signature or signed authorization obtained. | `BGV_0`, `BGV_1` | `BGV_2`, `BGV_3`, users |
| `AuthorizationLink` | Share link sent to the candidate so they can open and sign the authorization document. | `BGV_0` | `BGV_3`, users |
| `AuthorizationLinkCreatedAt` | Timestamp of when the authorization-link process was created. Used to decide reminder and escalation timing. | `BGV_0` | `BGV_3`, users |
| `AuthorisationSigned` | Main yes/no field showing whether the candidate's authorization has been confirmed as signed. | `BGV_1` | `BGV_3`, `BGV_4`, users |
| `ConsentTimestamp` | Timestamp of when the signed authorization was detected and recorded. | `BGV_1` | users, audit/review |
| `LastAuthReminderAt` | Timestamp of the last reminder email sent to the candidate. Prevents duplicate same-day reminders. | `BGV_3` | `BGV_3`, users |

Legacy note:

- If you still see `ConsentCaptured` in SharePoint, treat it as a
  legacy field. Current reminder logic is documented as using
  `AuthorisationSigned` instead.

## 2) `BGV_Requests`

What this list is for:

- one row per employer request
- tracks which employer slot is being chased
- tracks whether HR has been contacted
- stores the final verification result and reminder timeline

Typical user questions this list answers:

- Has employer HR been contacted yet?
- Which request belongs to EMP1, EMP2, or EMP3?
- Has the employer replied?
- What severity/result came back from the HR form?

### 2.1 Linking and routing columns

| Column | What it is for | Mainly written by | Mainly read by |
| --- | --- | --- | --- |
| `CandidateID` | Links the request back to the candidate case. | `BGV_0` | `BGV_4`, users |
| `CandidateItemID/Id` | SharePoint lookup back to the related `BGV_Candidates` row. | `BGV_0` | `BGV_4` |
| `RequestID` | Main unique ID for one employer request, such as `REQ-<CandidateID>-EMP1`. | `BGV_0` | `BGV_4`, `BGV_5`, users |
| `EmployerName` | Declared employer/company name for that request slot. | `BGV_0` | `BGV_4`, users |
| `EmployerHR_Email` | Employer HR email used for the verification request when no better slot-specific email is available from `BGV_FormData`. | `BGV_0` | `BGV_4`, users |
| `SendAfterDate` | Scheduling field used when deciding when the request should be sent. | `BGV_0` | request-send logic, users |

### 2.2 Employer outreach and result columns

| Column | What it is for | Mainly written by | Mainly read by |
| --- | --- | --- | --- |
| `VerificationStatus` | Main employer-outreach lifecycle field. Current live values are `Not Sent`, `Email Sent`, `Reminder 1 Sent`, `Reminder 2 Sent`, `Reminder 3 Sent`, and `Responded`. | `BGV_0`, `BGV_4`, `BGV_5`, `BGV_6` | `BGV_4`, `BGV_6`, `BGV_7`, users |
| `Status` | Legacy request-lifecycle field kept for compatibility/history. Current canonical flows no longer depend on it. | legacy | users, reporting |
| `HRRequestSentAt` | Timestamp for when the verification email was sent to employer HR. | `BGV_4` | `BGV_4`, `BGV_6`, users |
| `ResponseReceivedAt` | Timestamp for when the employer HR form response was received and processed. | `BGV_5` | `BGV_6`, users |
| `Reminder1At` | Timestamp of the first employer reminder. | `BGV_6` | `BGV_6`, users |
| `Reminder2At` | Timestamp of the second employer reminder. | `BGV_6` | `BGV_6`, users |
| `Reminder3At` | Timestamp of the later/final employer reminder stage tracked by the automation. | `BGV_6` | `BGV_6`, users |
| `EscalatedAt` | Timestamp for when the case was escalated to recruiters in Teams after repeated non-response. | `BGV_6` | `BGV_6`, users |
| `Severity` | Risk level assigned from the employer HR response. In the current flow this can be `High`, `Medium`, `Low`, or blank when no rule is triggered. | `BGV_5` | users, recruiter notifications |
| `Outcome` | Stores the combined flagged items detected from the employer form response. | `BGV_5` | users, reporting |
| `Notes` | Plain-text explanation built by the flow from the triggered rule(s), then saved into the request row for users and recruiters to review. | `BGV_5` | users, reporting |

### 2.3 How `Severity/Value` is calculated

This field is calculated by `BGV_5_Response1` when the employer submits
the HR verification form.

The flow starts with:

- `Severity` = empty
- `Outcome` = empty

Then it checks the employer response in this priority order:

1. High severity checks

   - If MAS misconduct is anything other than `No / Not Applicable`,
     severity becomes `High`.
   - If disciplinary action is `Yes`, severity becomes `High`.
   - `Outcome` adds `MAS` and/or `Disciplinary`.

2. Medium severity check

   - If the employer says the employment details are inaccurate,
     severity becomes `Medium`.
   - This only happens if severity is not already `High`.
   - `Outcome` adds the selected employment-detail checkbox values from Form 2 `Q16`.

3. Low severity check for inaccurate information

   - If the employer says the company details are inaccurate,
     severity becomes `Low`.
   - This only happens if no higher severity has already been set.
   - `Outcome` adds the selected company-detail checkbox values from Form 2 `Q9`.

4. Contact-request check

   - If the employer selects `Please contact me for further
     clarification`, the flow turns on notification and adds a note.
   - This does not change severity by itself.

5. Other-comments check

   - If only `Q27` other comments is filled and no higher severity rule has set a value yet,
     severity becomes `Neutral`.
   - `Outcome` adds `Other Comments`.

So the practical priority order is:

- `High` overrides everything
- `Medium` overrides `Low`
- `Low` is used only if no higher severity has already been set
- if none of the rules fire, severity stays blank

Where users will see the result:

- `BGV_Requests.Severity`
- `BGV_FormData.F2_Severity/Value`

Where users will see the explanation:

- `BGV_Requests.Notes`
- `BGV_FormData.F2_Notes`

### 2.4 How notes are presented

The flow builds one plain-text note body while it processes the
employer HR response.

That note body can contain one or more labeled blocks such as:

- `[High] ...`
- `[Medium] ...`
- `[Low] ...`
- `[Action Required] ...`

The same note body is then used in three places:

1. saved to `BGV_Requests.Notes`
1. saved to `BGV_FormData.F2_Notes` if a matching FormData row exists
1. reused in internal notification content such as Teams/email details

Example:

```text
[Low] Information provided was not fully accurate.

Selected issues: ...

Explanations:
- Employment Period: ...
- Job Title/Position: ...
- Remuneration Package: ...
- Other abnormalities: ...

[Action Required] Employer requested follow up.
```

Important note:

- `Please contact me for further clarification` does not change
  `Severity` by itself.
- It adds an action-required note and turns on internal notification.

## 3) `BGV_FormData`

What this list is for:

- one row per employer slot (`EMP1`, `EMP2`, `EMP3`)
- stores clean, normalized values from the candidate declaration form
- stores the important values from the employer HR form
- acts as the main prefill source for employer verification links
- preserves raw form payload snapshots for audit and troubleshooting

Typical user questions this list answers:

- What exact candidate/employer values were captured for EMP2?
- Which values were used to prefill the employer HR form?
- What did the employer submit back in Form 2?
- What did the system store after normalization/scoring?

### 3.1 Key and relationship columns

| Column | What it is for | Mainly written by | Mainly read by |
| --- | --- | --- | --- |
| `Title` | Required SharePoint title field. The automation keeps this populated so updates do not fail validation. | `BGV_0`, preserved by `BGV_5` | SharePoint, troubleshooting |
| `RecordKey` | Stable per-slot key, normally `{CandidateID}\|{EMPn}`. Helps identify one slot row cleanly. | `BGV_0` | users, troubleshooting |
| `CandidateID` | Candidate case ID copied here so one FormData row can always be linked back to the candidate. | `BGV_0` | `BGV_4`, `BGV_5`, users |
| `CandidateItemID` | SharePoint lookup/reference to the candidate row. | `BGV_0` | users, troubleshooting |
| `RequestID` | The employer request ID for this slot row. This is the main join key for prefill and response updates. | `BGV_0` | `BGV_4`, `BGV_5`, users |
| `RecordItemID` | Stores the related request-row SharePoint item ID. | `BGV_0`, refreshed by `BGV_5` context | users, troubleshooting |
| `EmployerSlot/Value` | Shows whether this row belongs to `EMP1`, `EMP2`, or `EMP3`. | `BGV_0` | users, troubleshooting |

### 3.2 Candidate declaration columns (`F1_*`)

These fields come from Form 1, the candidate declaration form.

| Column | What it is for | Mainly written by | Mainly read by |
| --- | --- | --- | --- |
| `F1_CandidateFullName` | Candidate full name stored at the slot-row level. | `BGV_0` | `BGV_4`, users |
| `F1_CandidateEmail` | Candidate email stored at the slot-row level. | `BGV_0` | users |
| `F1_IDNumberNRIC` | Candidate NRIC stored in normalized form. | `BGV_0` | `BGV_4`, users |
| `F1_IDNumberPassport` | Candidate passport stored in normalized form. | `BGV_0` | `BGV_4`, users |
| `F1_IDType/Value` | Normalized identification type used by the row, such as `NRIC` or `Passport`. | `BGV_0` | users, troubleshooting |
| `F1_EmployerName` | Employer/company name declared by the candidate for that slot. | `BGV_0` | `BGV_4`, users |
| `F1_EmployerUEN` | Employer UEN declared by the candidate. | `BGV_0` | `BGV_4`, users |
| `F1_EmployerAddress` | Employer address declared by the candidate. | `BGV_0` | `BGV_4`, users |
| `F1_EmployerPostalCode` | Employer postal code declared by the candidate. | `BGV_0` | users |
| `F1_JobTitle` | Job title declared by the candidate for that employer slot. | `BGV_0` | `BGV_4`, users |
| `F1_LastDrawnSalary` | Last drawn salary declared by the candidate. | `BGV_0` | `BGV_4`, users |
| `F1_EmploymentStartDate` | Employment start date declared by the candidate. | `BGV_0` | `BGV_4`, users |
| `F1_EmploymentEndDate` | Employment end date declared by the candidate. | `BGV_0` | `BGV_4`, users |
| `F1_HRContactName` | HR contact name given by the candidate for that employer slot. | `BGV_0` | users |
| `F1_HREmail` | HR email given by the candidate for that employer slot. Used as the preferred employer recipient when valid. | `BGV_0` | `BGV_4`, users |
| `F1_HRMobile` | HR mobile number given by the candidate for that employer slot. | `BGV_0` | users |
| `F1_ReasonForLeaving` | Candidate's reason for leaving that employer. | `BGV_0` | `BGV_4`, users |
| `Form1RawJson` | Full raw candidate declaration payload kept for audit and troubleshooting. | `BGV_0` | users, troubleshooting |
| `Form1SubmittedAt` | Timestamp of when the Form 1 snapshot was stored. | `BGV_0` | users, troubleshooting |

### 3.3 Employer HR response columns (`F2_*`)

These fields come from Form 2, the employer HR verification form.

| Column | What it is for | Mainly written by | Mainly read by |
| --- | --- | --- | --- |
| `F2_InformationAccurate` | Normalized yes/no answer for whether the employer says the information is accurate. | `BGV_5` | users, troubleshooting |
| `F2_SelectedIssues` | Selected issue list captured from the employer response. | `BGV_5` | users, troubleshooting |
| `F2_EmployerWouldReEmploy` | Normalized yes/no answer for whether the employer would re-employ the candidate. | `BGV_5` | users, troubleshooting |
| `F2_ReEmployReason` | Employer's reason when they would not re-employ the candidate. | `BGV_5` | users, troubleshooting |
| `F2_ReasonForLeaving` | Employer-submitted reason for leaving. This can be compared against the candidate declaration. | `BGV_5` | users, troubleshooting |
| `F2_Severity/Value` | Copy of the final request severity after the same response-scoring logic is applied. | `BGV_5` | users, troubleshooting |
| `F2_Outcome` | Stored copy of the combined flagged-issues summary. | `BGV_5` | users, troubleshooting |
| `F2_Notes` | Copy of the plain-text notes body stored for the same response when a matching FormData row exists. | `BGV_5` | users, troubleshooting |
| `Form2RawJson` | Full raw employer HR response payload kept for audit and troubleshooting. | `BGV_5` | users, troubleshooting |
| `Form2SubmittedAt` | Timestamp of when the Form 2 snapshot was stored. | `BGV_5` | users, troubleshooting |

### 3.4 How common HR form fields are captured

The current design uses three different capture styles:

- `Structured field`: saved into a named SharePoint column such as
  `F2_SelectedIssues`
- `Notes body`: appended into the plain-text notes written to
  `BGV_Requests.Notes` and `BGV_FormData.F2_Notes`
- `Raw JSON only`: preserved only inside `BGV_FormData.Form2RawJson`
  and not surfaced into a dedicated column or note block

Use this table when you need to know whether a Microsoft Forms answer
is easy to report on, only visible in notes, or only recoverable from
the raw response snapshot.

| HR form field or section | How it is currently captured | Where users will find it |
| --- | --- | --- |
| Information accurate? | Structured field | `BGV_FormData.F2_InformationAccurate` |
| If information provided was not accurate: selected issue checkboxes | Structured field and notes body | `BGV_FormData.F2_SelectedIssues`; also repeated inside `Notes` / `F2_Notes` |
| Discrepancy in employment period | Notes body | `BGV_Requests.Notes`; `BGV_FormData.F2_Notes` |
| Discrepancy in job title / position | Notes body | `BGV_Requests.Notes`; `BGV_FormData.F2_Notes` |
| Discrepancy in remuneration package | Notes body | `BGV_Requests.Notes`; `BGV_FormData.F2_Notes` |
| Other abnormalities such as unable to verify all information | Notes body | `BGV_Requests.Notes`; `BGV_FormData.F2_Notes` |
| Discrepancy in company details | Notes body and raw JSON | `BGV_Requests.Notes`; `BGV_FormData.F2_Notes`; `BGV_FormData.Form2RawJson` |
| Company-details inaccurate checkbox section | Notes body and raw JSON | `BGV_Requests.Notes`; `BGV_FormData.F2_Notes`; `BGV_FormData.Form2RawJson` |
| Company-details explanation box | Notes body and raw JSON | `BGV_Requests.Notes`; `BGV_FormData.F2_Notes`; `BGV_FormData.Form2RawJson` |
| MAS incident details | Notes body | `BGV_Requests.Notes`; `BGV_FormData.F2_Notes` |
| Disciplinary-action details | Notes body | `BGV_Requests.Notes`; `BGV_FormData.F2_Notes` |
| Would re-employ? | Structured field | `BGV_FormData.F2_EmployerWouldReEmploy` |
| Reason for not re-employing | Structured field and notes body | `BGV_FormData.F2_ReEmployReason`; may also appear in `Notes` / `F2_Notes` |
| Other comments we should know about | Raw JSON only until live Forms key is identified | `BGV_FormData.Form2RawJson` |
| Please contact me for further clarification | Notes body and notification trigger | `BGV_Requests.Notes`; `BGV_FormData.F2_Notes`; internal notification content |

Important practical points:

- If multiple inaccurate-information checkboxes are selected, the flow
  stores them together as one combined value in `F2_SelectedIssues`.
- The flow does not currently split those selected issues into separate
  SharePoint columns such as one field for Employment Period and one
  field for Last Position Held.
- A field can still exist in `Form2RawJson` even when it is not wired
  into a named SharePoint column or note block.

## 4) `BGV Records` Document Library

This is a SharePoint document library, not a normal list.

Use it when you need the real files rather than the tracking rows.

| Item or path | What it is for | Mainly used by |
| --- | --- | --- |
| `Candidate Files/{CandidateID}` | Main folder for one candidate case. | `BGV_0`, users |
| `Candidate Files/{CandidateID}/Authorization` | Stores authorization documents for that candidate. | `BGV_0`, `BGV_1`, `BGV_2`, users |
| `Authorization Form - {CandidateID}.docx` | The generated authorization document created from the Word template. | `BGV_0`, `BGV_1`, `BGV_2`, users |

## 5) Which Store Should I Check First?

| If you want to know... | Check here first |
| --- | --- |
| Whether the candidate has signed | `BGV_Candidates` |
| What employer request rows exist | `BGV_Requests` |
| What exact candidate/employer values were captured for one slot | `BGV_FormData` |
| What the employer replied in Form 2 | `BGV_FormData` |
| What final severity/flagged issues were assigned | `BGV_Requests` |
| Where the actual signed document is stored | `BGV Records` |

## 6) Related Documents

- `docs/data_mapping_dictionary.md` for exact technical mappings
- `docs/flows_easy_english.md` for a simple end-to-end process story
- `docs/architecture_flows.md` for flow/component wiring
