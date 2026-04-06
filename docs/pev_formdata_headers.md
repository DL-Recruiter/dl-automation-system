# PEV FormData Headers

This document explains the structured columns used in `PEV_FormData`.

The goal is:
- keep one row per employer slot
- keep short, structured answers directly in the list
- leave long explanation boxes in `Form1RawJson`, `Form2RawJson`, and notes fields unless there is already a dedicated reason/comment column

## Core Row Keys

| Display header | Internal name | Meaning |
| --- | --- | --- |
| `Record Key` | `RecordKey` | Stable row key in the format `{CandidateID}|EMP1/EMP2/EMP3`. |
| `Candidate ID` | `CandidateID` | Candidate case ID shared across candidate, request, form-data, and records. |
| `Request ID` | `RequestID` | Employer-request ID for that slot, for example `REQ-BGV-...-EMP1`. |
| `Employer Slot` | `EmployerSlot` | Which employer row this is: `EMP1`, `EMP2`, or `EMP3`. |
| `Candidate Item ID` | `CandidateItemID` | SharePoint item ID of the linked candidate row. |
| `Request Item ID` | `RecordItemID` | SharePoint item ID of the linked request row. |

## Candidate Form Fields

| Display header | Internal name | Meaning |
| --- | --- | --- |
| `Candidate Full Name` | `F1_CandidateFullName` | Candidate name from Form 1. |
| `Candidate Email` | `F1_CandidateEmail` | Candidate email from Form 1. |
| `ID Type` | `F1_IDType` | `NRIC` or `Passport`, derived from which ID value was filled. |
| `Candidate NRIC` | `F1_IDNumberNRIC` | Candidate NRIC value from Form 1. |
| `Candidate Passport Number` | `F1_IDNumberPassport` | Candidate passport number from Form 1. |
| `Declared Employer Name` | `F1_EmployerName` | Employer/company name declared by the candidate for that slot. |
| `Declared Employer UEN` | `F1_EmployerUEN` | Employer UEN declared by the candidate. |
| `Declared Employer Address` | `F1_EmployerAddress` | Employer address declared by the candidate. |
| `Declared Employer Postal Code` | `F1_EmployerPostalCode` | Employer postal code declared by the candidate. |
| `Declared Employment Start Date` | `F1_EmploymentStartDate` | Candidate-declared employment start date. |
| `Declared Employment End Date` | `F1_EmploymentEndDate` | Candidate-declared employment end date. |
| `Declared Last Position Held` | `F1_JobTitle` | Candidate-declared job title / last position held. |
| `Declared Last Drawn Salary` | `F1_LastDrawnSalary` | Candidate-declared remuneration package / salary. |
| `Declared Reason For Leaving` | `F1_ReasonForLeaving` | Candidate-declared reason for leaving. |
| `Deferred Send Date` | `F1_SendAfterDate` | Stored only when the candidate selected the defer-send option and an end date was provided. |
| `HR Contact Name` | `F1_HRContactName` | HR contact named by the candidate. |
| `HR Email` | `F1_HREmail` | HR email named by the candidate. |
| `HR Mobile Number` | `F1_HRMobile` | HR contact number named by the candidate. |
| `Form 1 Submitted At` | `Form1SubmittedAt` | Timestamp when Form 1 was captured into the row. |
| `Form 1 Raw JSON` | `Form1RawJson` | Full raw Form 1 payload snapshot for troubleshooting. |

## Employer Form Fields

These are the short / structured employer-side values that should live directly in `PEV_FormData`.

| Display header | Internal name | Meaning |
| --- | --- | --- |
| `Employer Verified Company Name` | `Employer_x0020_Verified_x0020_Co` | Company name entered or confirmed by the employer in Form 2. |
| `Employer Verified Company UEN` | `Employer_x0020_Verified_x0020_Co0` | Company UEN entered or confirmed by the employer in Form 2. |
| `Employer Verified Company Address` | `Employer_x0020_Verified_x0020_Co1` | Company address entered or confirmed by the employer in Form 2. |
| `Employer Verified Employment Period` | `Employer_x0020_Verified_x0020_Em` | Employment period entered or confirmed by the employer in Form 2. |
| `Employer Verified Last Drawn Salary` | `Employer_x0020_Verified_x0020_La` | Last drawn remuneration package entered or confirmed by the employer. |
| `Employer Verified Last Position Held` | `Employer_x0020_Verified_x0020_La0` | Last position/job title entered or confirmed by the employer. |
| `Employment Details Accurate` | `F2_InformationAccurate` | Yes/no normalized answer for whether employer says employment information is accurate. |
| `Employment Detail Issues Selected` | `F2_SelectedIssues` | Selected inaccurate employment-detail checkboxes. |
| `Company Details Accurate` | `F2_CompanyDetailsAccurate` | Yes/no normalized answer for whether employer says company details are accurate. |
| `Company Detail Issues Selected` | `F2_CompanyDetailsSelectedIssues` | Selected inaccurate company-detail checkboxes. |
| `Employer Reason For Leaving` | `F2_ReasonForLeaving` | Reason for leaving entered by employer. |
| `MAS Check Answer` | `F2_MASQuestion` | Employer answer to the MAS / regulatory question. |
| `Disciplinary Action Taken` | `F2_DisciplinaryAction` | Yes/no normalized disciplinary-action answer. |
| `Would Re-Employ` | `F2_EmployerWouldReEmploy` | Yes/no normalized re-employment answer. |
| `Reason Not Re-Employing` | `F2_ReEmployReason` | Employer reason when re-employment answer is negative. |
| `Clarification Contact Requested` | `F2_ContactForClarification` | Employer clarification/contact answer captured as structured text. |
| `Other Comments` | `F2_OtherComments` | Employer other-comments field. |
| `Form Completer Name` | `F2_FormCompleterName` | Name of the person who completed Form 2. |
| `Form Completer Job Title` | `F2_FormCompleterJobTitle` | Job title of the person who completed Form 2. |
| `Form Completer Contact Details` | `F2_FormCompleterContactDetails` | Contact details of the form completer. |
| `Company Stamp File Name` | `F2_CompanyStampFileName` | Derived filename from the uploaded company stamp response payload. |
| `Severity` | `F2_Severity` | Final severity copied from response-scoring logic. |
| `Flagged Issues` | `F2_Outcome` | Combined short issue summary copied from response-scoring logic. |
| `Response Notes` | `F2_Notes` | Operational notes/body copied from the response flow. |
| `Employer Email Reply At` | `EmployerEmailReplyAt` | Latest detected reply email timestamp from the shared mailbox. |
| `Form 2 Submitted At` | `Form2SubmittedAt` | Timestamp when Form 2 was captured into the row. |
| `Form 2 Raw JSON` | `Form2RawJson` | Full raw Form 2 payload snapshot for troubleshooting. |

## Long Answers Not Split Into Extra Columns

These stay in raw JSON and/or notes instead of getting their own extra structured columns:

| Form area | Why |
| --- | --- |
| Detailed discrepancy explanations | These are long narrative fields and are better preserved in raw JSON / notes. |
| Long MAS / disciplinary explanation text | These are operational note-style answers, not stable short headers. |
| Free-form abnormality narratives | These are long text and remain better suited to notes/raw JSON. |

## Current Mapping Rule

- Keep short, repeatable, filterable values in dedicated list columns.
- Keep long explanations in `Form1RawJson`, `Form2RawJson`, and notes fields unless there is already a dedicated reason/comment field in use.
