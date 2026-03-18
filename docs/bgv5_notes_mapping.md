# BGV_5 Notes Mapping

This document explains, in simple terms, how `BGV_5_Response1` builds the notes text that is written into:

- `BGV_Requests.Notes`
- `BGV_FormData.F2_Notes`

Important:

- `BGV_Requests.Notes` and `BGV_FormData.F2_Notes` now use the same simplified summary logic.
- Both fields now receive the cleaner operational summary version from `varRequestNotesBody`.
- `Form2RawJson` is different. It stores the full raw Form 2 response body, not the summarized notes text below.

## BGV_Requests.Notes

| Source area in Form 2 | When it gets added to notes | What gets written into `BGV_Requests.Notes` |
| --- | --- | --- |
| MAS declaration issue | If the employer indicates a MAS-related issue | The selected MAS choice/detail is written directly into notes |
| Disciplinary issue | If the employer indicates disciplinary findings | The selected disciplinary choice/detail is written directly into notes |
| Re-employ decision | If the employer says they would not re-employ the candidate | The choice is shown. If the reason textbox was filled, notes now say `Re-employ reason filled: Please refer to the report summary for additional comments.` |
| Information inaccurate | If the employer says the submitted information is not accurate | The selected inaccurate items are written directly into notes |
| Employment period explanation | If this explanation is filled and `Employment Period` was selected | Notes now say `Employment period explanation filled: Please refer to the report summary for additional comments.` |
| Job title explanation | If this explanation is filled and the selected issues include `Last Position Held` / `Job Title/Position` | Notes now say `Job title explanation filled: Please refer to the report summary for additional comments.` |
| Remuneration explanation | If this explanation is filled and `Remuneration Package` was selected | Notes now say `Remuneration explanation filled: Please refer to the report summary for additional comments.` |
| Other abnormalities | If this explanation is filled and `Other abnormalities` was selected | Notes now say `Other abnormalities explanation filled: Please refer to the report summary for additional comments.` |
| Contact me for clarification | If the employer asks to be contacted | A notes block saying clarification is requested |
| Company-details accuracy | If company details are marked inaccurate | The selected accuracy answer is written directly into notes |
| Discrepancy in company details | If the employer selected company-detail fields that are inaccurate | The selected discrepant fields are written directly into notes |
| Company-details explanation | If the employer explains the company-details discrepancy | Notes now say `Company details explanation filled: Please refer to the report summary for additional comments.` |

## BGV_FormData.F2_Notes

| Source area in Form 2 | When it gets added to notes | What gets written into `BGV_FormData.F2_Notes` |
| --- | --- | --- |
| MAS declaration issue | If the employer indicates a MAS-related issue | The selected MAS choice/detail is written directly into notes |
| Disciplinary issue | If the employer indicates disciplinary findings | The selected disciplinary choice/detail is written directly into notes |
| Re-employ decision | If the employer says they would not re-employ the candidate | The choice is shown. If the reason textbox was filled, notes now say `Re-employ reason filled: Please refer to the report summary for additional comments.` |
| Information inaccurate | If the employer says the submitted information is not accurate | The selected inaccurate items are written directly into notes |
| Employment period explanation | If this explanation is filled and `Employment Period` was selected | Notes now say `Employment period explanation filled: Please refer to the report summary for additional comments.` |
| Job title explanation | If this explanation is filled and the selected issues include `Last Position Held` / `Job Title/Position` | Notes now say `Job title explanation filled: Please refer to the report summary for additional comments.` |
| Remuneration explanation | If this explanation is filled and `Remuneration Package` was selected | Notes now say `Remuneration explanation filled: Please refer to the report summary for additional comments.` |
| Other abnormalities | If this explanation is filled and `Other abnormalities` was selected | Notes now say `Other abnormalities explanation filled: Please refer to the report summary for additional comments.` |
| Contact me for clarification | If the employer asks to be contacted | A notes block saying clarification is requested |
| Company-details accuracy | If company details are marked inaccurate | The selected accuracy answer is written directly into notes |
| Discrepancy in company details | If the employer selected company-detail fields that are inaccurate | The selected discrepant fields are written directly into notes |
| Company-details explanation | If the employer explains the company-details discrepancy | Notes now say `Company details explanation filled: Please refer to the report summary for additional comments.` |

## Practical Summary

| Field | Current mapping behavior |
| --- | --- |
| `BGV_Requests.Notes` | Receives the cleaner operational summary from `varRequestNotesBody` |
| `BGV_FormData.F2_Notes` | Receives the same cleaner operational summary from `varRequestNotesBody` |
| `BGV_FormData.Form2RawJson` | Stores the full raw Form 2 response body separately |

## Known Gap

`Other comments we should know about` is not currently added into the notes summary unless it is only visible in `Form2RawJson`.

That means:

- it is preserved in `Form2RawJson`
- it is not yet explicitly mapped into `BGV_Requests.Notes`
- it is not yet explicitly mapped into `BGV_FormData.F2_Notes`

If the live Forms key for that question is identified, it can be added into both notes outputs.
