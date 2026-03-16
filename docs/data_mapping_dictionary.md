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
| `re5312de7ff5641e38b9fe30752de0721` | EMP1 Employer UEN | `BGV_FormData.F1_EmployerUEN` | `Create_BGV_FormData_Row_E1` |
| `re91050593c81419580fe2e7b6dc58d19` | EMP1 Employer Address | `BGV_FormData.F1_EmployerAddress` | `Create_BGV_FormData_Row_E1` |
| `r98441b417415436c804fd0d540acbf34` | EMP1 Employer Postal Code | `BGV_FormData.F1_EmployerPostalCode` | `Create_BGV_FormData_Row_E1` |
| `r048c10ad09924a4ea7360b2bbe2203d9` | EMP1 Job Title | `BGV_FormData.F1_JobTitle` | `Create_BGV_FormData_Row_E1` |
| `r7266236add10436d83e254a8ec5a2a07` | EMP1 Last Drawn Salary | `BGV_FormData.F1_LastDrawnSalary` | `Create_BGV_FormData_Row_E1` |
| `rf5ce346dbc2e4326b0e23bd037a5a405` | EMP1 Employment Start Date | `BGV_FormData.F1_EmploymentStartDate` | `Create_BGV_FormData_Row_E1` |
| `rad5353936be1480f9ffe08b3fde00739` | EMP1 Employment End Date | `BGV_FormData.F1_EmploymentEndDate` | `Create_BGV_FormData_Row_E1` |
| `r7f64c0a46334405a952868d9921d83bf` | EMP1 HR Contact Name | `BGV_FormData.F1_HRContactName` | `Create_BGV_FormData_Row_E1` |
| `r99f0629822f44e1990ee2e00b3c2b442` | EMP1 HR Email | `BGV_Requests.EmployerHR_Email`; `BGV_FormData.F1_HREmail` | `Create_BGV_Request_Row`; `Create_BGV_FormData_Row_E1` |
| `r627e3c5b0a874aaa90166f6babd66bd1` | EMP1 HR Mobile | `BGV_FormData.F1_HRMobile` | `Create_BGV_FormData_Row_E1` |
| `r1bb545a59a184a8d8a688825a042a314` | EMP2 Employer Name | `BGV_Requests.EmployerName`; `BGV_FormData.F1_EmployerName` | `Create_BGV_Request_Row_E2`; `Create_BGV_FormData_Row_E2` |
| `r6be20fd3c82f4c3d8c406cc3a5b0f6dc` | EMP2 Employer UEN | `BGV_FormData.F1_EmployerUEN` | `Create_BGV_FormData_Row_E2` |
| `r4b95a3f004d54d21903e1b46c2f55b63` | EMP2 Employer Address | `BGV_FormData.F1_EmployerAddress` | `Create_BGV_FormData_Row_E2` |
| `r9e3813d18bc3416e8ddb87cef1ce4de1` | EMP2 Employer Postal Code | `BGV_FormData.F1_EmployerPostalCode` | `Create_BGV_FormData_Row_E2` |
| `r2e71b6400a364fe1aa626eeea6a99f61` | EMP2 Job Title | `BGV_FormData.F1_JobTitle` | `Create_BGV_FormData_Row_E2` |
| `rd7edb8d30e1b49a89cf77ac3eb85b5c5` | EMP2 Last Drawn Salary | `BGV_FormData.F1_LastDrawnSalary` | `Create_BGV_FormData_Row_E2` |
| `ra375ae9073404fc79aa6cd8e6bfb8a65` | EMP2 Employment Start Date | `BGV_FormData.F1_EmploymentStartDate` | `Create_BGV_FormData_Row_E2` |
| `rc503abfcc3014499993291e460a366b1` | EMP2 Employment End Date | `BGV_FormData.F1_EmploymentEndDate` | `Create_BGV_FormData_Row_E2` |
| `r125e48f9283a4dea8d82c8d39fd708d9` | EMP2 HR Contact Name | `BGV_FormData.F1_HRContactName` | `Create_BGV_FormData_Row_E2` |
| `r32be5c779be8409da404c296b3262471` | EMP2 HR Email | `BGV_Requests.EmployerHR_Email`; `BGV_FormData.F1_HREmail` | `Create_BGV_Request_Row_E2`; `Create_BGV_FormData_Row_E2` |
| `r7e52c06848b94899b011881713cae9bf` | EMP2 HR Mobile | `BGV_FormData.F1_HRMobile` | `Create_BGV_FormData_Row_E2` |
| `r3e674ff5973e4d54b9f96952de10cd37` | EMP3 Employer Name | `BGV_Requests.EmployerName`; `BGV_FormData.F1_EmployerName` | `Create_BGV_Request_Row_E3`; `Create_BGV_FormData_Row_E3` |
| `rb8a84461cd104dfa9f323fd518129e52` | EMP3 Employer UEN | `BGV_FormData.F1_EmployerUEN` | `Create_BGV_FormData_Row_E3` |
| `r1404dfb9fc5d4551abe6c3f4808dfa3a` | EMP3 Employer Address | `BGV_FormData.F1_EmployerAddress` | `Create_BGV_FormData_Row_E3` |
| `r2d958068e4064949b7207ee243c9dd12` | EMP3 Employer Postal Code | `BGV_FormData.F1_EmployerPostalCode` | `Create_BGV_FormData_Row_E3` |
| `rd71dd57467e6403cbf9f162ad9863073` | EMP3 Job Title | `BGV_FormData.F1_JobTitle` | `Create_BGV_FormData_Row_E3` |
| `r2c266cfd9f3e4ec6a9308aa6a7575660` | EMP3 Last Drawn Salary | `BGV_FormData.F1_LastDrawnSalary` | `Create_BGV_FormData_Row_E3` |
| `r252a6b495a1548b08c3030617d883ea9` | EMP3 Employment Start Date | `BGV_FormData.F1_EmploymentStartDate` | `Create_BGV_FormData_Row_E3` |
| `rf84549cedfd64afaa85c45865bce1b08` | EMP3 Employment End Date | `BGV_FormData.F1_EmploymentEndDate` | `Create_BGV_FormData_Row_E3` |
| `r036860f157014aaba9446454923fe35a` | EMP3 HR Contact Name | `BGV_FormData.F1_HRContactName` | `Create_BGV_FormData_Row_E3` |
| `r7032b42718eb4a84a88453304c2ee557` | EMP3 HR Email | `BGV_Requests.EmployerHR_Email`; `BGV_FormData.F1_HREmail` | `Create_BGV_Request_Row_E3`; `Create_BGV_FormData_Row_E3` |
| `r86e14f2b43f14fb4b73d037806255613` | EMP3 HR Mobile | `BGV_FormData.F1_HRMobile` | `Create_BGV_FormData_Row_E3` |

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
| `r27b6bdb850dd48339dc05df11d485470` | Candidate identification number (NRIC field) | `BGV_FormData.F1_IDNumberNRIC` -> `BGV_Candidates.IdentificationNumberNRIC` |
| `r425242341d6143c7a29307136debe938` | Candidate Passport | `BGV_FormData.F1_IDNumberPassport` -> `BGV_Candidates.IdentificationNumberPassport` |
| `rd745d133eb7f4611b59ea051f980f97a` | Request ID | `BGV_Requests.RequestID` |
| `rccaf3632669648baaa335c12d4ea40bf` | Declared company name | `BGV_FormData.F1_EmployerName` -> `BGV_Requests.EmployerName` |
| `rcf35c7cc008e472f9d0b84bde67cc1ff` | Declared company UEN | `BGV_FormData.F1_EmployerUEN` |
| `r19aae6e8163d4aaeb8a3f3f2d5329be2` | Declared company address | `BGV_FormData.F1_EmployerAddress` |
| `r0bef44c0d22d493f95a33484875b951e` | Declared employment period | Uses `BGV_FormData.F1_EmploymentStartDate` and `F1_EmploymentEndDate`; emits `start to end` when both exist, else the single available date (`yyyy-MM-dd`) |
| `ra6ab2e26d2d84a92b33148fc4694773a` | Declared last drawn remuneration package | `BGV_FormData.F1_LastDrawnSalary` |
| `r49ca8a655f5e4bcba0e8f75d4475ad77` | Declared last position held | `BGV_FormData.F1_JobTitle` |

Note:
- In the current HR Form 2 layout, questions explicitly labeled `(Declared By Candidate)` are the intended prefill targets in `BGV_4`.
- Form 2 `Q11` (`r513ad5ab3a14453286bdb910820985ec`) is no longer a `(Declared By Candidate)` field, so it is intentionally not appended to `BGV_4` `FinalVerificationLink` and remains blank for employer HR unless they fill it manually.
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
| `r513ad5ab3a14453286bdb910820985ec` | Reason for leaving (employer-entered response) | `BGV_FormData.F2_ReasonForLeaving` | direct (coalesce to empty string) |
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
| `r57e4baaeaafc4ffc8b3977149b18f2f2` | Follow-up request check (`'Please contact me for further clarification'`) -> notify teams and append an action-required note |

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
| `BGV_2_Postsignature` | `BGV Records` library | Reads authorization `.docx` files, locks all content controls via `LockAuthorizationControls` function, overwrites file content with locked DOCX, then performs `Stop sharing` on matched files. |
| `BGV_3_AuthReminder_5Days` | `BGV_Candidates` | Reads rows where `Status='Pending Authorization Form Signature'`; uses `AuthorizationLinkCreatedAt`, `AuthorizationLink`; updates `LastAuthReminderAt`. |
| `BGV_4_SendToEmployer_Clean` | `BGV_Requests` | Reads pending requests; reads candidate auth status; updates `HRRequestSentAt=utcNow()`, `VerificationStatus='Sent'`. |
| `BGV_6_HRReminderAndEscalation` | `BGV_Requests` | Reads rows where `Status='Sent'`; uses `ResponseReceivedAt`, `Reminder1At`, `Reminder2At`, `Reminder3At`; updates `Reminder1At`, `Reminder2At`, `Reminder3At`. |

## 9) BGV Records (Document Library) Data Path

| Step | Mapping |
| --- | --- |
| Candidate folder creation | `Candidate Files/{CandidateID}` created by `BGV_0 / Create_Candidate_Folder` |
| Authorization subfolder | `Candidate Files/{CandidateID}/Authorization` created by `BGV_0 / Create_Authorization_Sub_Folder` |
| Authorization document file | `Authorization Form - {CandidateID}.docx` created from Word template |
| Authorization template ID controls | `IdentificationNumberNRIC` content control: candidate NRIC else `N/A`; `IdentificationNumberPassport` content control: `N/A` when NRIC exists, else candidate Passport, else `N/A` |
| Authorization consent checkbox | Template includes bottom text `Yes, I authorized` with checkbox content-control tag `SignedYes` for parser-compatible signed/unchecked detection in `BGV_1` |
| Share link | Document share link written to `BGV_Candidates.AuthorizationLink` |
| Signature lifecycle | `BGV_1` parses signed document; `BGV_2` stops sharing after signature status is set |

## 10) Coverage Note (Current-State Accuracy)

This document lists mappings that are currently implemented in flow JSON.
It does not assume unimplemented mappings for form fields that are not referenced by current actions.

## 11) HR Verification Form (Q1-Q33) Inventory and Wiring Status

This section tracks the current "Previous Employee Verification - HR Use Only" question inventory against canonical flow wiring.

Legend:
- `Prefill`: value is written into `FinalVerificationLink` in `BGV_4`.
- `Read`: value is read from `Get_response_details` in `BGV_5`.
- `Stored`: value is written to SharePoint (`BGV_Requests` and/or `BGV_FormData`) by `BGV_5`.
- `Not wired`: not referenced in canonical flow JSON currently.

| Q# | Form question label | Forms key evidence | Current wiring | SharePoint target / use |
| --- | --- | --- | --- | --- |
| 1 | Candidate Full Name | `r4930fc603c0f4cada09832be79f2a76f` | Prefill | Context for employer; not stored from Form 2 response |
| 2 | Candidate Identification (NRIC) | `r27b6bdb850dd48339dc05df11d485470` | Prefill | Context for employer; not stored from Form 2 response |
| 3 | Candidate Identification (Passport) | `r425242341d6143c7a29307136debe938` | Prefill | Context for employer; not stored from Form 2 response |
| 4 | RequestID (auto-filled) | `rd745d133eb7f4611b59ea051f980f97a` | Prefill + Read + Stored | Request lookup key; stored in `BGV_FormData.RequestID` |
| 5 | Company Name (Declared by Candidate) | `rccaf3632669648baaa335c12d4ea40bf` | Prefill | Context for employer; not stored from Form 2 response |
| 6 | Company UEN (Declared by Candidate) | `rcf35c7cc008e472f9d0b84bde67cc1ff` (from user-provided prefill URL) | Prefill | `BGV_4` uses `BGV_FormData.F1_EmployerUEN` |
| 7 | Information accurate for declared company details | `r2d39255c2449439096683ca0e39241b0` (from user-provided prefill URL) | Key known; not wired in canonical flow JSON | N/A |
| 8 | If company details are not accurate, select inaccurate fields | `rd05170e51ac34fef95f5464cf348bedc` (from user-provided prefill URL) | Key known; not wired in canonical flow JSON | N/A |
| 9 | Explain the company-details discrepancy | `ra03058e9bbfd40d28014b0c669e92434` (from user-provided prefill URL) | Key known; not wired in canonical flow JSON | N/A |
| 10 | Employment Period (Declared By Candidate) | `r0bef44c0d22d493f95a33484875b951e` (from user-provided prefill URL) | Prefill | `BGV_4` writes `start to end` if both dates exist, else uses the single available date |
| 11 | Reason For Leaving | `r513ad5ab3a14453286bdb910820985ec` | Stored only | Employer HR enters this manually in Form 2; it is not a current `(Declared By Candidate)` prefill field, and the submitted response is stored in `BGV_FormData.F2_ReasonForLeaving` |
| 12 | Last Drawn Renumeration Package (Declared By Candidate) | `ra6ab2e26d2d84a92b33148fc4694773a` (from user-provided prefill URL) | Prefill | `BGV_4` uses `BGV_FormData.F1_LastDrawnSalary` |
| 13 | Last Position Held (Declared By Candidate) | `r49ca8a655f5e4bcba0e8f75d4475ad77` (from user-provided prefill URL) | Prefill | `BGV_4` uses `BGV_FormData.F1_JobTitle` |
| 14 | Employment details section field (question text not yet captured in repo) | Not present in current canonical flow JSON | Not wired | N/A |
| 15 | Employment details section field (question text not yet captured in repo) | Not present in current canonical flow JSON | Not wired | N/A |
| 16 | Discrepancy in company details declared by previous employee (if applicable) | Not present in current canonical flow JSON | Not wired | N/A |
| 17 | Discrepancy in employment period declared by previous employee (if applicable) | `r9a95095b3d7d4d9f8bc985025614bd79` | Read | Included in `varNotifyBody`; persisted in `BGV_FormData.F2_Notes` via derived notes |
| 18 | Discrepancy in Job Title/Position held declared by previous employee (if applicable) | `r83027392ccb043e2a637b06ff4b54ac8` | Read | Included in `varNotifyBody`; persisted in `BGV_FormData.F2_Notes` via derived notes |
| 19 | Discrepancy in remuneration package declared by previous employee (if applicable) | `r4061a9d19aae45d9915d2f508a5c3ea9` | Read | Included in `varNotifyBody`; persisted in `BGV_FormData.F2_Notes` via derived notes |
| 20 | Discrepancy in reason for leaving employment declared by candidate (if applicable) | Not present in current canonical flow JSON | Not wired | N/A |
| 21 | Other abnormalities such as unable to verify all information (if any) | `ra15c799c557d42d1bcee1de947c29466` | Read | Included in `varNotifyBody`; persisted in `BGV_FormData.F2_Notes` via derived notes |
| 22 | MAS reporting question | Not present in current canonical flow JSON | Not wired | N/A |
| 23 | Kindly provide details, if candidate has been reported for MAS related incidents | `r7bd26b4a7e94430dbda54f9e8b8212e4` | Read | High-severity rule and notes text |
| 24 | Was any disciplinary action taken against he/she during your employment | `r96d079f9858e40bab89ab0ea4ad23931` | Read | High-severity rule |
| 25 | Kindly provide details, if there were disciplinary actions taken | `r35197d5910d2489db0d5786157b35295` | Read | High-severity notes text |
| 26 | Would you re-employ him/her? | `rafe3ada4157c49fb9e555cd0fb53bd59` | Read + Stored | `BGV_FormData.F2_EmployerWouldReEmploy` (boolean) and medium-severity rule |
| 27 | Reason for not wanting to re-employ him/her | `r5f7ebc3390bc4699b160504c65254c3e` | Read + Stored | `BGV_FormData.F2_ReEmployReason`; notes text |
| 28 | Other comments we should know about | Not present in current canonical flow JSON | Not wired | N/A |
| 29 | Full Name of Person Completing This Form | Not present in current canonical flow JSON | Not wired | N/A |
| 30 | Job Title | Not present in current canonical flow JSON | Not wired | N/A |
| 31 | Contact details for clarification/follow-up | Not present in current canonical flow JSON | Not wired | N/A |
| 32 | HR declaration confirmation | `r57e4baaeaafc4ffc8b3977149b18f2f2` | Read | Triggers follow-up notification when value is "Please contact me for further clarification" |
| 33 | Upload official company stamp for verification | Not present in current canonical flow JSON | Not wired | N/A |

Known current direct Form 2 storage fields in `BGV_FormData`:
- `F2_InformationAccurate` <- `r9594fab1bfa04c90883b1dffd7f4549e`
- `F2_SelectedIssues` <- `r72b23e4aa192405091846e1279085029`
- `F2_EmployerWouldReEmploy` <- `rafe3ada4157c49fb9e555cd0fb53bd59`
- `F2_ReEmployReason` <- `r5f7ebc3390bc4699b160504c65254c3e`
- Additional observed keys from latest prefill URL (not wired yet):
  - `r2d39255c2449439096683ca0e39241b0` (`Q7` company-details accuracy yes/no)
  - `rd05170e51ac34fef95f5464cf348bedc` (`Q8` company-details discrepancy multi-select)
  - `ra03058e9bbfd40d28014b0c669e92434` (`Q9` company-details discrepancy explanation)

Important:
- Candidate Declaration source keys above were verified from the live Forms runtime metadata endpoint (`prefetchFormUrl`) on `2026-03-04`.
- HR form key evidence for Q6/Q7/Q8/Q9/Q10/Q11/Q12/Q13 is from the user-provided Microsoft Forms prefilled URL.
- If form questions are edited in Forms designer, `r...` IDs may change and mappings must be re-verified.

## 12) User-Annotated Prefill Mapping (PDF Markup, 2026-03-04)

Source PDFs reviewed:
- `C:\Users\EdwinTeo\Desktop\Previous Employment Verification – Candidate Declaration (DL Resources)1.pdf`
- `C:\Users\EdwinTeo\Desktop\Previous Employee Verification – HR Use Only.pdf`

This section records the color-circled field pairings requested by user for prefill from Candidate Declaration -> HR Use Only form.

| Candidate form question | Candidate key status | HR form question | HR key status | Current implementation status |
| --- | --- | --- | --- | --- |
| Q1 `CandidateFullName` | Known: `rfe96c622120343f294de908deb0e849d` | Q1 `Candidate Full Name` | Known: `r4930fc603c0f4cada09832be79f2a76f` | Implemented in `BGV_4` prefill |
| Q4 `IdentificationNumberNRIC` | Known: `rd2fba2b09afd478ba21df420406c9b49` | Q2 `Candidate Identification (NRIC)` | Known: `r27b6bdb850dd48339dc05df11d485470` | Implemented in `BGV_4` prefill |
| Q5 `IdentificationNumberPassport` | Known: `rf5b324c022804863a720ef13edeb9d9b` | Q3 `Candidate Identification (Passport)` | Known: `r425242341d6143c7a29307136debe938` | Implemented in `BGV_4` prefill |
| Q6 `E1 - Company Name` | Known: `rd186af3305c44a399ff007602a528c90` | Q5 `Company Name (Declared by Candidate)` | Known: `rccaf3632669648baaa335c12d4ea40bf` | Implemented in `BGV_4` prefill |
| Q7 `E1 - Company UEN` | Verified: `re5312de7ff5641e38b9fe30752de0721` (candidate runtime metadata) | Q6 `Company UEN (Declared by Candidate)` | Known from prefill URL: `rcf35c7cc008e472f9d0b84bde67cc1ff` | Implemented in `BGV_4` prefill |
| Q8 `E1 - Company Address` | Verified: `re91050593c81419580fe2e7b6dc58d19` (candidate runtime metadata) | Q7 `Company Address (Declared by Candidate)` | Known from prefill URL: `r19aae6e8163d4aaeb8a3f3f2d5329be2` | Implemented in `BGV_4` prefill |
| Q12 + Q13 `E1 - Employment Period Start/End Date` | Verified: `rf5ce346dbc2e4326b0e23bd037a5a405` + `rad5353936be1480f9ffe08b3fde00739` (candidate runtime metadata) | Q10 `Employment Period (Declared By Candidate)` | Known from prefill URL: `r0bef44c0d22d493f95a33484875b951e` | Implemented in `BGV_4` prefill (`start to end` if both, else single available date) |
| Q11 `E1 - Last Drawn Salary Package` | Verified: `r7266236add10436d83e254a8ec5a2a07` (candidate runtime metadata) | Q12 `Last Drawn Renumeration Package (Declared By Candidate)` | Known from prefill URL: `ra6ab2e26d2d84a92b33148fc4694773a` | Implemented in `BGV_4` prefill |
| Q10 `E1 - Candidate's Job Title` | Verified: `r048c10ad09924a4ea7360b2bbe2203d9` (candidate runtime metadata) | Q13 `Last Position Held (Declared By Candidate)` | Known from prefill URL: `r49ca8a655f5e4bcba0e8f75d4475ad77` | Implemented in `BGV_4` prefill |

Related note:
- HR Q4 `RequestID` remains auto-filled from `BGV_Requests.RequestID` (`rd745d133eb7f4611b59ea051f980f97a`) and is already implemented.
- HR questions explicitly labeled `(Declared By Candidate)` in the current Form 2 PDF are the prefill targets wired into `BGV_4`.
- HR Q11 `Reason For Leaving` (`r513ad5ab3a14453286bdb910820985ec`) is not one of those current prefill fields.
  - Employer HR sees this Form 2 question blank unless they type a response manually.
  - The submitted Form 2 answer is still captured downstream in `BGV_FormData.F2_ReasonForLeaving`.
