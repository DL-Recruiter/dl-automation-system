# BGV Data Mapping and Data Dictionary

This document is the field-level mapping source for the current BGV system implementation.

Last verified from canonical flow files:
- `flows/power-automate/unpacked/Workflows/BGV_0_CandidateDeclaration-8C1238C7-E4F1-F011-8406-002248582037.json`
- `flows/power-automate/unpacked/Workflows/BGV_1_Detect_Authorization_Signature-A35CA9C0-E4F1-F011-8406-002248582037.json`
- `flows/power-automate/unpacked/Workflows/BGV_2_Postsignature-A45CA9C0-E4F1-F011-8406-002248582037.json`
- `flows/power-automate/unpacked/Workflows/BGV_3_AuthReminder_5Days-FF4BF0E3-0916-F111-8341-002248582037.json`
- `flows/power-automate/unpacked/Workflows/BGV_4_SendToEmployer_Clean-FE4BF0E3-0916-F111-8341-002248582037.json`
- `flows/power-automate/unpacked/Workflows/BGV_5_Response1-FD4BF0E3-0916-F111-8341-002248582037.json`
- `flows/power-automate/unpacked/Workflows/BGV_6_HRReminderAndEscalation-FC4BF0E3-0916-F111-8341-002248582037.json`

## 1) Canonical Document To Maintain
Use this file as the canonical field mapping document for this repo.

When mappings change:
1. Update the canonical flow JSON under `flows/power-automate/unpacked/Workflows/`.
2. Update this file in the same change.
3. Update `docs/progress.md`.

## 2) Data Stores and Keys

| Store | Type | Internal ID used by flows | Primary Tracking Keys | Notes |
| --- | --- | --- | --- | --- |
| `BGV_Candidates` | SharePoint List | `7b78dcaf-8744-478b-a40f-633ed7becff3` | `CandidateID` | Candidate-level record, auth lifecycle tracking, authorization link. |
| `BGV_Requests` | SharePoint List | `4acba8e0-46aa-4007-b752-b4aa88fee7f7` | `RequestID`, `CandidateID` | One row per employer slot (`EMP1/EMP2/EMP3`). |
| `BGV_FormData` | SharePoint List | `f5248a99-fdf1-4660-946a-d54e00575a40` | `RecordKey`, `RequestID`, `CandidateID` | Normalized form data store. |
| `BGV Records` | SharePoint Document Library | `d411563f-2b1c-4fa5-90fc-ecc5f50941a1` | Folder path contains `CandidateID` | Candidate files and authorization documents. |

## 2.1) Requested View: BGV_Candidates <-> BGV_Requests <-> MS Forms (HR Verification Form) <-> Flow 4 Outputs

### 2.1.1 Current data flow path (BGV_4 then BGV_5)

1. `BGV_4_SendToEmployer_Clean` reads pending request rows from `BGV_Requests` (`VerificationStatus='Pending'` and `HRRequestSentAt` is null).
2. For each request row, flow reads the linked candidate from `BGV_Candidates` using `CandidateItemID/Id`.
3. Flow builds `FinalVerificationLink` (HR Verification Form prefilled URL) using request/candidate values with `BGV_FormData` as preferred source where available.
4. Flow emails `BGV_Requests.EmployerHR_Email` with the prefilled HR verification link and signed authorization file.
5. Flow updates request row in SharePoint: `HRRequestSentAt=utcNow()`, `VerificationStatus='Sent'`.
6. Later, `BGV_5_Response1` receives the HR form submission and uses prefilling key `rd745...` (RequestID) to find and update the same request row.

### 2.1.2 Field mapping for the requested systems

| Source system | Source field | MS Forms (HR Verification Form) key | Flow 4 output / downstream |
| --- | --- | --- | --- |
| `BGV_Candidates` | `FullName` | `r4930fc603c0f4cada09832be79f2a76f` | Included in prefilled `FinalVerificationLink` sent by email |
| `BGV_Candidates` | `IdentificationNumberNRIC` | `r27b6bdb850dd48339dc05df11d485470` | Included in prefilled `FinalVerificationLink` sent by email |
| `BGV_Candidates` | `IdentificationNumberPassport` | `r0c342001cdd8463181c36dba2a8933ad` | Included in prefilled `FinalVerificationLink` sent by email |
| `BGV_Requests` | `RequestID` | `rd745d133eb7f4611b59ea051f980f97a` | Included in prefilled `FinalVerificationLink`; later used by `BGV_5` to match the SharePoint request row |
| `BGV_Requests` | `EmployerName` | `rccaf3632669648baaa335c12d4ea40bf` | Included in prefilled `FinalVerificationLink` sent by email |
| `BGV_Requests` | `EmployerHR_Email` | N/A | `BGV_4` email recipient (`Send an email (V2)`) |
| `BGV_Requests` | `HRRequestSentAt` | N/A | Updated by `BGV_4` to `utcNow()` after email send |
| `BGV_Requests` | `VerificationStatus` | N/A | Updated by `BGV_4` from `Pending` to `Sent` |

Notes:
- In `BGV_4`, prefill source order is `BGV_FormData` first, then fallback to `BGV_Candidates`/`BGV_Requests`.
- The HR verification form response mapping is documented in section 7 (`Form 2 -> SharePoint (BGV_5)`).

## 3) Form IDs

| Form | Where Used | Form ID in flow trigger |
| --- | --- | --- |
| `Previous Employment Verification - Candidate Declaration (DL Resources)1` | `BGV_0_CandidateDeclaration` | `cHRZOFNHGkaDf62MFIYLIq9-liquOypMpApm-AyRSqVUNlVFTjhUNjNWOTI4SEsxTVc0V1ZSV1o3Qi4u` |
| `Previous Employee Verification - HR Use Only` | `BGV_5_Response1` | `cHRZOFNHGkaDf62MFIYLIq9-liquOypMpApm-AyRSqVUN1c5NE0wWEI2Nk1OMDlJSkI0N0RXUTRHMS4u` |

## 4) Generated Keys and Relationship Mapping

| Generated/Linked Field | Expression | Target Columns | Flow Action(s) |
| --- | --- | --- | --- |
| `CandidateID` | `@concat('BGV-', formatDateTime(utcNow(),'yyyyMMdd'), '-', substring(guid(),0,5))` | `BGV_Candidates.CandidateID`, `BGV_Requests.CandidateID`, `BGV_FormData.CandidateID`, BGV Records folder path | `BGV_0 / Initialize_varCandidateID` and downstream create actions |
| `RequestID` (EMP1) | `@concat('REQ-', variables('varCandidateID'), '-EMP1')` | `BGV_Requests.RequestID`, `BGV_FormData.RequestID` | `BGV_0 / Create_BGV_Request_Row`, `Create_BGV_FormData_Row_E1` |
| `RequestID` (EMP2) | `@concat('REQ-', variables('varCandidateID'), '-EMP2')` | `BGV_Requests.RequestID`, `BGV_FormData.RequestID` | `BGV_0 / Create_BGV_Request_Row_E2`, `Create_BGV_FormData_Row_E2` |
| `RequestID` (EMP3) | `@concat('REQ-', variables('varCandidateID'), '-EMP3')` | `BGV_Requests.RequestID`, `BGV_FormData.RequestID` | `BGV_0 / Create_BGV_Request_Row_E3`, `Create_BGV_FormData_Row_E3` |
| Candidate row lookup ID | `@outputs('CandidateItemId')` from `Get_Candidate_Row` | `BGV_Requests.CandidateItemID/Id`, `BGV_FormData.CandidateItemID` | `BGV_0` create request/formdata actions |
| Request row item ID | `@outputs('Create_BGV_Request_Row[_E2/_E3]')?['body/ID']` | `BGV_FormData.RecordItemID` | `BGV_0` create FormData actions |
| Request row link back during Form 2 update | `@items('Apply_to_each')?['ID']` | `BGV_FormData.RecordItemID` | `BGV_5 / Update_item_-_BGV_FormData` |

## 5) Field Mapping: Form 1 -> SharePoint (BGV_0)

### 5.1 Candidate-level fields

| Form 1 response key | Meaning (based on current implementation) | Target column(s) | Flow action(s) |
| --- | --- | --- | --- |
| `rfe96c622120343f294de908deb0e849d` | Candidate full name | `BGV_Candidates.FullName`; `BGV_FormData.F1_CandidateFullName` (EMP1/2/3) | `Create_BGV_Candidates_Row`; `Create_BGV_FormData_Row_E1/E2/E3` |
| `rcd8057cd92b24b5594681a5b39c07e3d` | Candidate email | `BGV_Candidates.CandidateEmail`; `BGV_FormData.F1_CandidateEmail` (EMP1/2/3) | `Create_BGV_Candidates_Row`; `Create_BGV_FormData_Row_E1/E2/E3` |
| `rd2fba2b09afd478ba21df420406c9b49` | NRIC value | `BGV_Candidates.IdentificationNumberNRIC`; `BGV_FormData.F1_IDNumberNRIC` (EMP1/2/3) | `Create_BGV_Candidates_Row`; `Create_BGV_FormData_Row_E1/E2/E3` |
| `rf5b324c022804863a720ef13edeb9d9b` | Passport value | `BGV_Candidates.IdentificationNumberPassport`; `BGV_FormData.F1_IDNumberPassport` (EMP1/2/3) | `Create_BGV_Candidates_Row`; `Create_BGV_FormData_Row_E1/E2/E3` |
| Derived from NRIC empty/not empty | Identification type | `BGV_FormData.F1_IDType/Value` = `NRIC` if NRIC not empty else `Passport` | `Create_BGV_FormData_Row_E1/E2/E3` |

### 5.2 Employer segment fields (EMP1/EMP2/EMP3)

| Form 1 response key | Employer slot | Target column(s) | Flow action(s) |
| --- | --- | --- | --- |
| `rd186af3305c44a399ff007602a528c90` | EMP1 Employer Name | `BGV_Requests.EmployerName`; `BGV_FormData.F1_EmployerName` | `Create_BGV_Request_Row`; `Create_BGV_FormData_Row_E1` |
| `r99f0629822f44e1990ee2e00b3c2b442` | EMP1 HR Email | `BGV_Requests.EmployerHR_Email`; `BGV_FormData.F1_HREmail` | `Create_BGV_Request_Row`; `Create_BGV_FormData_Row_E1` |
| `r1bb545a59a184a8d8a688825a042a314` | EMP2 Employer Name | `BGV_Requests.EmployerName`; `BGV_FormData.F1_EmployerName` | `Create_BGV_Request_Row_E2`; `Create_BGV_FormData_Row_E2` |
| `r32be5c779be8409da404c296b3262471` | EMP2 HR Email | `BGV_Requests.EmployerHR_Email`; `BGV_FormData.F1_HREmail` | `Create_BGV_Request_Row_E2`; `Create_BGV_FormData_Row_E2` |
| `r3e674ff5973e4d54b9f96952de10cd37` | EMP3 Employer Name | `BGV_Requests.EmployerName`; `BGV_FormData.F1_EmployerName` | `Create_BGV_Request_Row_E3`; `Create_BGV_FormData_Row_E3` |
| `r7032b42718eb4a84a88453304c2ee557` | EMP3 HR Email | `BGV_Requests.EmployerHR_Email`; `BGV_FormData.F1_HREmail` | `Create_BGV_Request_Row_E3`; `Create_BGV_FormData_Row_E3` |

### 5.3 Scheduling field

| Form 1 response key | Current usage | Target column | Flow action |
| --- | --- | --- | --- |
| `r0ed00b9df34d4ab6bb34235a2466ea5e` and `r0ed00b9df34d4ab6bb34235a2466ea5e>` | Used in EMP1 `SendAfterDate` logic. If criteria passes, uses candidate-provided value; otherwise falls back to `utcNow()`. | `BGV_Requests.SendAfterDate` | `Create_BGV_Request_Row` |

### 5.4 Common payload snapshots in FormData

| Source | Target column(s) | Flow action(s) |
| --- | --- | --- |
| Full Form 1 response JSON (`outputs('Get_response_details')?['body']`) | `BGV_FormData.Form1RawJson` | `Create_BGV_FormData_Row_E1/E2/E3` |
| Current timestamp | `BGV_FormData.Form1SubmittedAt` | `Create_BGV_FormData_Row_E1/E2/E3` |
| Slot metadata | `BGV_FormData.EmployerSlot/Value` (`EMP1`/`EMP2`/`EMP3`) | `Create_BGV_FormData_Row_E1/E2/E3` |
| Stable per-slot key | `BGV_FormData.Title`, `BGV_FormData.RecordKey` = `{CandidateID}|{EMPn}` | `Create_BGV_FormData_Row_E1/E2/E3` |

## 6) Field Mapping: SharePoint -> Form 2 Prefill Link (BGV_4)

Flow action: `BGV_4 / FinalVerificationLink`.

| Form 2 prefill query key | Source expression in flow | Source fallback order |
| --- | --- | --- |
| `r4930fc603c0f4cada09832be79f2a76f` | Candidate full name | `BGV_FormData.F1_CandidateFullName` -> `BGV_Candidates.FullName` |
| `r27b6bdb850dd48339dc05df11d485470` | Candidate NRIC | `BGV_FormData.F1_IDNumberNRIC` -> `BGV_Candidates.IdentificationNumberNRIC` |
| `r0c342001cdd8463181c36dba2a8933ad` | Candidate Passport | `BGV_FormData.F1_IDNumberPassport` -> `BGV_Candidates.IdentificationNumberPassport` |
| `rd745d133eb7f4611b59ea051f980f97a` | Request ID | `BGV_Requests.RequestID` |
| `rccaf3632669648baaa335c12d4ea40bf` | Declared company name | `BGV_FormData.F1_EmployerName` -> `BGV_Requests.EmployerName` |

Note:
- Only these five keys are currently prefilled by flow logic.
- All values are URL-encoded with `encodeUriComponent(...)`.

## 7) Field Mapping: Form 2 -> SharePoint (BGV_5)

### 7.1 Request lookup and state update

| Form 2 response key | Usage | Target column(s) | Flow action(s) |
| --- | --- | --- | --- |
| `rd745d133eb7f4611b59ea051f980f97a` | Request lookup key | Lookup filter on `BGV_Requests.RequestID` (`startswith`) and `BGV_FormData.RequestID` (`eq`) | `Get_items`; `Get_items_(BGV_FormData)` |
| Derived runtime values | Scoring output | `BGV_Requests.Severity/Value`, `Outcome/Value`, `Notes`, `Status/Value='Completed'`, `ResponseReceivedAt=utcNow()` | `Update_item_-_of_BGV_Request` |

### 7.2 Form 2 fields persisted into BGV_FormData

| Form 2 response key | Meaning (from flow usage) | Target column | Transform |
| --- | --- | --- | --- |
| `rd745d133eb7f4611b59ea051f980f97a` | Request ID | `BGV_FormData.RequestID` | direct |
| `r9594fab1bfa04c90883b1dffd7f4549e` | Information accurate yes/no | `BGV_FormData.F2_InformationAccurate` | `equals(value,'Yes')` (boolean) |
| `r72b23e4aa192405091846e1279085029` | Selected issues | `BGV_FormData.F2_SelectedIssues` | direct |
| `rafe3ada4157c49fb9e555cd0fb53bd59` | Re-employ yes/no | `BGV_FormData.F2_EmployerWouldReEmploy` | `equals(value,'Yes')` (boolean) |
| `r5f7ebc3390bc4699b160504c65254c3e` | Re-employ reason | `BGV_FormData.F2_ReEmployReason` | direct |
| Derived runtime values | Scoring output | `BGV_FormData.F2_Severity/Value`, `F2_Outcome`, `F2_Notes` | from variables |
| Full Form 2 response JSON | Snapshot | `BGV_FormData.Form2RawJson` | `string(outputs('Get_response_details')?['body'])` |
| Timestamp | Submission timestamp | `BGV_FormData.Form2SubmittedAt` | `utcNow()` |
| Linked record keys | Relational fields | `BGV_FormData.CandidateID`, `RecordItemID` | from matched `BGV_Requests` item |

### 7.3 Form 2 fields used for risk logic (may not be directly persisted)

| Form 2 response key | Logic use in BGV_5 |
| --- | --- |
| `r7bd26b4a7e94430dbda54f9e8b8212e4` | MAS misconduct check (`!= 'No / Not Applicable'`) -> High severity path |
| `r96d079f9858e40bab89ab0ea4ad23931` | Disciplinary check (`== 'Yes'`) -> High severity path |
| `r35197d5910d2489db0d5786157b35295` | Details text appended to disciplinary notification body |
| `rafe3ada4157c49fb9e555cd0fb53bd59` | Re-employ check (`== 'No'`) -> Medium severity (unless already High) |
| `r5f7ebc3390bc4699b160504c65254c3e` | Reason text appended to re-employ notification body |
| `r9594fab1bfa04c90883b1dffd7f4549e` | Accuracy check (`== 'No'`) -> Low severity when severity still empty |
| `r72b23e4aa192405091846e1279085029` | Selected issues included in low-severity note text |
| `r9a95095b3d7d4d9f8bc985025614bd79` | Employment period explanation text |
| `r83027392ccb043e2a637b06ff4b54ac8` | Job title explanation text |
| `r4061a9d19aae45d9915d2f508a5c3ea9` | Remuneration explanation text |
| `ra15c799c557d42d1bcee1de947c29466` | Other abnormalities explanation text |
| `r57e4baaeaafc4ffc8b3977149b18f2f2` | Follow-up request check (`'Please contact me for further clarification'`) -> notify teams |

### 7.4 Initial scoring variable defaults

| Variable | Initial value | Flow action |
| --- | --- | --- |
| `varSeverity` | empty string | `Initialize_variable_-_Severity` |
| `varOutcome` | `Verified` | `Initialize_variable_-_Outcome` |
| `varNotifyTeams` | `false` | `Initialize_variable_-_Notify_Teams` |
| `varNotifyBody` | empty string | `Initialize_variable_-_Notify_Body` |

## 8) Other Flow Field Updates (Non-Form Mapping)

| Flow | Data target | Fields updated/read |
| --- | --- | --- |
| `BGV_1_Detect_Authorization_Signature` | `BGV_Candidates` | Reads by `CandidateID`; sets `ConsentTimestamp=utcNow()`, `Status='Obtained Authorization Form Signature'`, `AuthorisationSigned=true`. |
| `BGV_2_Postsignature` | `BGV Records` library | Reads authorization `.docx` files; performs `Stop sharing` operation on matched files. |
| `BGV_3_AuthReminder_5Days` | `BGV_Candidates` | Reads rows where `Status='Pending Authorization Form Signature'`; uses `AuthorizationLinkCreatedAt`, `AuthorizationLink`; updates `LastAuthReminderAt`. |
| `BGV_4_SendToEmployer_Clean` | `BGV_Requests` | Reads pending requests; reads candidate auth status; updates `HRRequestSentAt=utcNow()`, `VerificationStatus='Sent'`. |
| `BGV_6_HRReminderAndEscalation` | `BGV_Requests` | Reads rows where `Status='Sent'`; uses `ResponseReceivedAt`, `Reminder1At`, `Reminder2At`, `Reminder3At`; updates `Reminder1At`, `Reminder2At`, `Reminder3At`. |

## 9) BGV Records (Document Library) Data Path

| Step | Mapping |
| --- | --- |
| Candidate folder creation | `Candidate Files/{CandidateID}` created by `BGV_0 / Create_Candidate_Folder` |
| Authorization subfolder | `Candidate Files/{CandidateID}/Authorization` created by `BGV_0 / Create_Authorization_Sub_Folder` |
| Authorization document file | `Authorization Form - {CandidateID}.docx` created from Word template |
| Share link | Document share link written to `BGV_Candidates.AuthorizationLink` |
| Signature lifecycle | `BGV_1` parses signed document; `BGV_2` stops sharing after signature status is set |

## 10) Coverage Note (Current-State Accuracy)

This document lists mappings that are currently implemented in flow JSON.
It does not assume unimplemented mappings for form fields that are not referenced by current actions.
