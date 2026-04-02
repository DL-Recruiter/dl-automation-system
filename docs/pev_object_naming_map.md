# PEV Object Naming Map

This is the planned technical naming map for the parallel `PEV` cutover.

## SharePoint Stores

| Current | Planned PEV |
| --- | --- |
| `BGV_Candidates` | `PEV_Candidates` |
| `BGV_Requests` | `PEV_Requests` |
| `BGV_FormData` | `PEV_FormData` |
| `BGV Records` | `PEV Records` |

## Flow Display Names

| Current | Planned PEV |
| --- | --- |
| `BGV_0_CandidateDeclaration` | `PEV_0_CandidateDeclaration` |
| `BGV_1_Detect_Authorization_Signature` | `PEV_1_Detect_Authorization_Signature` |
| `BGV_2_Postsignature` | `PEV_2_Postsignature` |
| `BGV_3_AuthReminder_5Days` | `PEV_3_AuthReminder_5Days` |
| `BGV_4_SendToEmployer_Clean` | `PEV_4_SendToEmployer_Clean` |
| `BGV_5_Response1` | `PEV_5_Response1` |
| `BGV_6_HRReminderAndEscalation` | `PEV_6_HRReminderAndEscalation` |
| `BGV_7_Generate_Report_Summary` | `PEV_7_Generate_Report_Summary` |
| `BGV_8_Track_Employer_Email_Replies` | `PEV_8_Track_Employer_Email_Replies` |
| `BGV_9_Refresh_Dashboard_Excel` | `PEV_9_Refresh_Dashboard_Excel` |

## Dashboard / Files

| Current | Planned PEV |
| --- | --- |
| `BGV Dashboard.xlsx` | `PEV Dashboard.xlsx` |
| `BGVDashboard_FLow.xlsx` | `PEVDashboard_Flow.xlsx` |
| `BGV Dashboard Master Query.m` | `PEV Dashboard Master Query.m` |
| `BGV_Report_Summary_Template.docx` | `PEV_Report_Summary_Template.docx` |

## IDs and Prefixes

These should stay unchanged during the first cutover unless there is a separate approved data migration:

- `BGV-...`
- `REQ-BGV-...`

Reason:

- they are already embedded in existing rows, folders, links, reports, and email history
- changing them requires historical data remapping, not just a config cutover

## Recommended Order

1. create parallel `PEV_*` stores
2. copy schema and data
3. deploy parallel `PEV_*` flow package
4. validate end to end
5. switch live operations
6. retire `BGV_*` technical objects later
